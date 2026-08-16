#if DEBUG && STORNAUT_INVESTIGATION_DIAGNOSTIC
import Darwin
import Foundation
import StornautInvestigationDiagnostic
import SwiftUI

typealias InvestigationRuntimeDiagnosticLeaf =
    StornautInvestigationDiagnostic
    .InvestigationRuntimeDiagnosticAppLeaf
typealias InvestigationRuntimeDiagnosticContractError =
    StornautInvestigationDiagnostic
    .InvestigationRuntimeDiagnosticAppLeafError

struct InvestigationRuntimeDiagnosticLaunchRequest:
    Sendable,
    Equatable
{
    static let argumentPrefix =
        "--stornaut-investigation-runtime-config="

    let configURL: URL

    init?(arguments: [String]) {
        let matching = arguments.filter {
            $0 == String(Self.argumentPrefix.dropLast())
                || $0.hasPrefix(Self.argumentPrefix)
        }
        guard
            arguments.count == 2,
            matching.count == 1,
            matching[0].hasPrefix(Self.argumentPrefix)
        else {
            return nil
        }
        let rawPath = String(
            matching[0].dropFirst(Self.argumentPrefix.count)
        )
        guard rawPath.hasPrefix("/") else {
            return nil
        }
        configURL = URL(filePath: rawPath).standardizedFileURL
    }

    static func containsActivation(arguments: [String]) -> Bool {
        arguments.contains {
            $0 == String(argumentPrefix.dropLast())
                || $0.hasPrefix(argumentPrefix)
        }
    }
}

enum InvestigationRuntimeDiagnosticActivation:
    Sendable,
    Equatable
{
    case notRequested
    case invalid
    case request(InvestigationRuntimeDiagnosticLaunchRequest)

    static func select(arguments: [String]) -> Self {
        if let request = InvestigationRuntimeDiagnosticLaunchRequest(
            arguments: arguments
        ) {
            return .request(request)
        }
        if InvestigationRuntimeDiagnosticLaunchRequest.containsActivation(
            arguments: arguments
        ) {
            return .invalid
        }
        return .notRequested
    }
}

@main
struct StornautInvestigationDiagnosticApp: App {
    init() {
        guard
            ProcessInfo.processInfo.environment[
                "XCTestConfigurationFilePath"
            ] == nil
        else {
            return
        }
        Task {
            Darwin.exit(
                await InvestigationRuntimeDiagnosticHarness.run(
                    arguments: CommandLine.arguments
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}

enum InvestigationRuntimeDiagnosticHarness {
    static func run(
        arguments: [String],
        now: Date = Date(),
        compositionPrepare:
            @escaping @Sendable (Data, Date) async throws -> UUID = {
                data,
                now in
                let composition =
                    try InvestigationRuntimeDiagnosticComposition
                        .prepare(
                            configurationData: data,
                            now: now
                        )
                guard composition.hasRuntimeFacade else {
                    throw InvestigationRuntimeDiagnosticCompositionError
                        .compositionUnavailable
                }
                let nonce = composition.nonce
                guard
                    await composition.retirePreparedComposition()
                        == .retiredWithoutStarting
                else {
                    throw InvestigationRuntimeDiagnosticCompositionError
                        .compositionUnavailable
                }
                return nonce
            }
    ) async -> Int32 {
        switch InvestigationRuntimeDiagnosticActivation.select(
            arguments: arguments
        ) {
        case .notRequested, .invalid:
            return 64
        case let .request(request):
            let receipt = await prepare(
                request: request,
                now: now,
                compositionPrepare: compositionPrepare
            )
            guard
                InvestigationRuntimeDiagnosticReceiptWriter.write(
                    receipt: receipt,
                    configURL: request.configURL
                ) == .written
            else {
                return 73
            }
            return receipt.isPrepared ? 0 : 65
        }
    }

    private static func prepare(
        request: InvestigationRuntimeDiagnosticLaunchRequest,
        now: Date,
        compositionPrepare:
            @Sendable (Data, Date) async throws -> UUID
    ) async -> InvestigationRuntimeDiagnosticPreflightReceipt {
        do {
            let data = try loadConfiguration(request.configURL)
            let leaf = try InvestigationRuntimeDiagnosticLeaf.prepare(
                configurationData: data,
                now: now
            )
            let nonce = try await compositionPrepare(data, now)
            guard nonce == leaf.nonce else {
                throw InvestigationRuntimeDiagnosticCompositionError
                    .bindingMismatch
            }
            return .prepared(
                nonce: nonce,
                startedAt: now
            )
        } catch {
            return .blocked(
                reasonKey:
                    "investigation.runtime.debug.invalid-composition",
                startedAt: now
            )
        }
    }

    static func loadConfiguration(
        _ url: URL
    ) throws -> Data {
        guard url.lastPathComponent == "config.json" else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        let descriptor = open(
            url.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        defer { close(descriptor) }
        var information = stat()
        guard
            fstat(descriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_mode & 0o777 == 0o600,
            information.st_uid == geteuid(),
            information.st_nlink == 1,
            information.st_size > 0,
            information.st_size <= 64 * 1_024
        else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        guard
            let data = readConfiguration(
                descriptor: descriptor,
                byteCount: Int(information.st_size)
            ),
            !data.isEmpty
        else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        let decoded = try InvestigationRuntimeDiagnosticLeaf.prepare(
            configurationData: data,
            now: Date()
        )
        guard
            URL(filePath: decoded.diagnosticRootPath)
                .appending(path: "config.json")
                .standardizedFileURL == url.standardizedFileURL
        else {
            throw InvestigationRuntimeDiagnosticContractError
                .invalidConfiguration
        }
        return data
    }

    private static func readConfiguration(
        descriptor: Int32,
        byteCount: Int
    ) -> Data? {
        var data = Data(count: byteCount)
        let completed = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }
            var offset = 0
            while offset < byteCount {
                let count = Darwin.read(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    byteCount - offset
                )
                if count > 0 {
                    offset += count
                    continue
                }
                if count < 0, errno == EINTR {
                    continue
                }
                return false
            }
            return true
        }
        guard completed else {
            return nil
        }
        return data
    }
}

enum InvestigationRuntimeDiagnosticReceiptWriteOutcome:
    Sendable,
    Equatable
{
    case written
    case alreadyExists
    case failed
}

enum InvestigationRuntimeDiagnosticReceiptWriter {
    private static let preflightReceiptName =
        "investigation-runtime-preflight.json"

    static func write(
        receipt: InvestigationRuntimeDiagnosticPreflightReceipt,
        configURL: URL,
        operations:
            InvestigationRuntimeDiagnosticReceiptOperations = .system
    ) -> InvestigationRuntimeDiagnosticReceiptWriteOutcome {
        let url = configURL.deletingLastPathComponent().appending(
            path: preflightReceiptName
        )
        guard
            url.deletingLastPathComponent()
                == configURL.deletingLastPathComponent(),
            let data = try? JSONEncoder.investigationRuntime.encode(
                receipt
            )
        else {
            return .failed
        }
        let descriptor = operations.openExclusive(url.path)
        guard descriptor >= 0 else {
            return operations.errorCode() == EEXIST
                ? .alreadyExists
                : .failed
        }
        let completed = writeAll(
            data,
            descriptor: descriptor,
            operation: operations.write,
            errorCode: operations.errorCode
        )
        let synchronized =
            completed && operations.synchronize(descriptor)
        let closed = operations.close(descriptor)
        guard synchronized, closed else {
            operations.unlink(url.path)
            return .failed
        }
        return .written
    }

    static func writeAll(
        _ data: Data,
        descriptor: Int32,
        operation: (
            Int32,
            UnsafeRawPointer,
            Int
        ) -> Int,
        errorCode: () -> Int32 = { errno }
    ) -> Bool {
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return data.isEmpty
            }
            var offset = 0
            while offset < bytes.count {
                let count = operation(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if count > 0, count <= bytes.count - offset {
                    offset += count
                    continue
                }
                if count < 0, errorCode() == EINTR {
                    continue
                }
                return false
            }
            return true
        }
    }

}

struct InvestigationRuntimeDiagnosticReceiptOperations {
    let openExclusive: (String) -> Int32
    let write: (Int32, UnsafeRawPointer, Int) -> Int
    let synchronize: (Int32) -> Bool
    let close: (Int32) -> Bool
    let unlink: (String) -> Void
    let errorCode: () -> Int32

    static var system: Self {
        Self(
            openExclusive: { path in
                Darwin.open(
                    path,
                    O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                    0o600
                )
            },
            write: { descriptor, pointer, count in
                Darwin.write(descriptor, pointer, count)
            },
            synchronize: { descriptor in
                while true {
                    if fsync(descriptor) == 0 {
                        return true
                    }
                    if errno != EINTR {
                        return false
                    }
                }
            },
            close: { descriptor in
                Darwin.close(descriptor) == 0
            },
            unlink: { path in
                _ = Darwin.unlink(path)
            },
            errorCode: { errno }
        )
    }
}

struct InvestigationRuntimeDiagnosticPreflightReceipt:
    Codable,
    Sendable
{
    let schemaVersion: Int
    let outcome: String
    let nonce: UUID?
    let reasonKey: String?
    let startedAt: Date
    let completedAt: Date

    var isPrepared: Bool {
        outcome == "investigationRuntimeDebugCompositionPrepared"
    }

    static func prepared(
        nonce: UUID,
        startedAt: Date,
        completedAt: Date = Date()
    ) -> Self {
        Self(
            schemaVersion: 1,
            outcome: "investigationRuntimeDebugCompositionPrepared",
            nonce: nonce,
            reasonKey: nil,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    static func blocked(
        reasonKey: String,
        startedAt: Date,
        completedAt: Date = Date()
    ) -> Self {
        Self(
            schemaVersion: 1,
            outcome: "investigationRuntimeDebugCompositionBlocked",
            nonce: nil,
            reasonKey: reasonKey,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

private extension JSONEncoder {
    static var investigationRuntime: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
#endif
