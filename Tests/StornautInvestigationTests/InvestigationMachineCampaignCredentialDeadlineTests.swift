import Foundation
import Testing

@Suite("Investigation machine campaign credential deadline", .serialized)
struct InvestigationMachineCampaignCredentialDeadlineTests {
    @Test
    func controllingTTYReadIsBoundedRestoresEchoAndNeverEchoesCredential() throws {
        let fixture = try CredentialDeadlineFixture.make()
        defer { fixture.remove() }

        let timeout = try fixture.run(
            mode: "timeout", deadlineNanoseconds: 100_000_000
        )
        #expect(timeout.contains(
            "status=1 error=60 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: timeout))

        let expired = try fixture.run(
            mode: "expired", deadlineNanoseconds: 100_000_000
        )
        #expect(expired.contains(
            "status=1 error=60 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: expired))

        let credential = "fixture-secret"
        let success = try fixture.run(
            mode: "success", deadlineNanoseconds: 3_000_000_000,
            credential: credential
        )
        #expect(success.contains(
            "status=0 error=0 length=14 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: success))
        #expect(!success.contains(credential))

        let maximumCredential = String(repeating: "m", count: 1_023)
        let maximum = try fixture.run(
            mode: "success", deadlineNanoseconds: 3_000_000_000,
            credential: maximumCredential
        )
        #expect(maximum.contains(
            "status=0 error=0 length=1023 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: maximum))
        #expect(!maximum.contains(maximumCredential))

        let empty = try fixture.run(
            mode: "empty", deadlineNanoseconds: 3_000_000_000,
            credential: "unused"
        )
        #expect(empty.contains(
            "status=2 error=22 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: empty))

        let interrupted = try fixture.run(
            mode: "interrupt", deadlineNanoseconds: 3_000_000_000
        )
        #expect(interrupted.contains(
            "status=2 error=5 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: interrupted))

        let overflowCredential = String(repeating: "x", count: 1_024)
        let overflow = try fixture.run(
            mode: "overflow", deadlineNanoseconds: 200_000_000,
            credential: overflowCredential
        )
        #expect(overflow.contains(
            "status=1 error=60 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
        ), Comment(rawValue: overflow))
        #expect(!overflow.contains(overflowCredential))

        for mode in ["reap-signal", "reap-clock", "reap-wait"] {
            let failed = try fixture.run(
                mode: mode, deadlineNanoseconds: 100_000_000
            )
            #expect(failed.contains(
                "status=2 error=5 length=0 beforeEcho=1 afterEcho=1 zeroed=1 childResidue=0"
            ), Comment(rawValue: failed))
        }
    }
}

private struct CredentialDeadlineFixture {
    let root: URL
    let executable: URL

    static func make() throws -> Self {
        let repository = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-credential-deadline-" + UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let executable = root.appending(path: "credential-fixture")
        let source = repository.appending(
            path: "Tests/Fixtures/InvestigationMachineCampaignCredential/main.c"
        )
        let support = repository.appending(
            path: "Sources/CInvestigationMachineCampaignSupport/"
                + "CInvestigationMachineCampaignSupport.c"
        )
        let include = repository.appending(
            path: "Sources/CInvestigationMachineCampaignSupport/include"
        )
        let compiler = Process(), diagnostics = Pipe()
        compiler.executableURL = URL(filePath: "/usr/bin/xcrun")
        compiler.arguments = [
            "clang", "-std=c11", "-Wall", "-Wextra", "-Werror",
            "-DSTORNAUT_INVESTIGATION_CAMPAIGN_TESTING=1",
            "-I", include.path, source.path, support.path, "-o", executable.path,
        ]
        compiler.standardInput = FileHandle.nullDevice
        compiler.standardOutput = diagnostics
        compiler.standardError = diagnostics
        try compiler.run()
        let output = diagnostics.fileHandleForReading.readDataToEndOfFile()
        compiler.waitUntilExit()
        guard compiler.terminationStatus == 0 else {
            throw CredentialDeadlineFixtureError.compile(
                String(decoding: output, as: UTF8.self)
            )
        }
        return .init(root: root, executable: executable)
    }

    func run(
        mode: String, deadlineNanoseconds: UInt64,
        credential: String? = nil
    ) throws -> String {
        let process = Process(), output = Pipe()
        process.executableURL = executable
        process.arguments = [mode, String(deadlineNanoseconds)]
            + (credential.map { [$0] } ?? [])
        process.environment = [
            "HOME": "/var/empty", "PATH": "/usr/bin:/bin",
            "LANG": "C", "LC_ALL": "C",
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CredentialDeadlineFixtureError.execution(
                process.terminationStatus, String(decoding: data, as: UTF8.self)
            )
        }
        return String(decoding: data, as: UTF8.self)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private enum CredentialDeadlineFixtureError: Error {
    case compile(String)
    case execution(Int32, String)
}
