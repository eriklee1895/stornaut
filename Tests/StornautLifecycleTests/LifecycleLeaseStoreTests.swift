import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle lease store")
struct LifecycleLeaseStoreTests {
    @Test
    func currentBootSessionIdentityMatchesKernelUUID() throws {
        let bootSessionID = try currentLifecycleBootSessionID()

        #expect(bootSessionID.rawValue.uuidString.count == 36)
        #expect(
            LifecycleLeaseRecoveryPlanner(
                currentBootSessionID: bootSessionID
            ).currentBootSessionID == bootSessionID
        )
    }

    @Test
    func writesAndReadsVersionedLeaseAtDerivedPath() throws {
        let fixture = try LeaseStoreFixture()
        defer { fixture.remove() }
        let investigationID = LifecycleInvestigationID(
            rawValue: UUID(
                uuidString: "11111111-2222-3333-4444-555555555555"
            )!
        )
        let lease = try LifecycleInvestigationLease(
            investigationID: investigationID,
            bootSessionID: fixture.bootSessionID,
            auditSessionID: 44_001,
            userID: 501
        )

        let url = try fixture.store.create(lease)
        let recovered = try fixture.store.readAll()

        #expect(
            url.lastPathComponent
                == "11111111-2222-3333-4444-555555555555.lease"
        )
        #expect(lifecycleLeaseMode(url) == 0o600)
        #expect(recovered == [lease])
        #expect(try fixture.store.remove(investigationID) == url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func createIsExclusiveAndCallerCannotChooseLeasePath() throws {
        let fixture = try LeaseStoreFixture()
        defer { fixture.remove() }
        let lease = try LifecycleInvestigationLease(
            investigationID: LifecycleInvestigationID(),
            bootSessionID: fixture.bootSessionID,
            auditSessionID: 44_001,
            userID: 501
        )

        _ = try fixture.store.create(lease)

        #expect(throws: LifecycleLeaseStoreError.alreadyExists) {
            _ = try fixture.store.create(lease)
        }
        #expect(!String(describing: LifecycleInvestigationLease.self)
            .localizedCaseInsensitiveContains("path"))
    }

    @Test
    func readAllRejectsSymlinkWrongModeMalformedAndUnknownFiles() throws {
        let fixture = try LeaseStoreFixture()
        defer { fixture.remove() }

        let valid = try LifecycleInvestigationLease(
            investigationID: LifecycleInvestigationID(),
            bootSessionID: fixture.bootSessionID,
            auditSessionID: 44_001,
            userID: 501
        )
        let validURL = try fixture.store.create(valid)
        chmod(validURL.path, 0o644)
        #expect(throws: LifecycleLeaseStoreError.invalidMode) {
            _ = try fixture.store.readAll()
        }
        chmod(validURL.path, 0o600)
        try fixture.store.remove(valid.investigationID)

        let malformed = fixture.root.appending(path: "\(UUID()).lease")
        try Data("{invalid".utf8).write(to: malformed)
        chmod(malformed.path, 0o600)
        #expect(throws: LifecycleLeaseStoreError.invalidLease) {
            _ = try fixture.store.readAll()
        }
        try FileManager.default.removeItem(at: malformed)

        let target = fixture.root.appending(path: "target")
        try Data("target".utf8).write(to: target)
        chmod(target.path, 0o600)
        let link = fixture.root.appending(path: "\(UUID()).lease")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: target
        )
        #expect(throws: LifecycleLeaseStoreError.invalidFile) {
            _ = try fixture.store.readAll()
        }
        try FileManager.default.removeItem(at: link)

        let linked = try LifecycleInvestigationLease(
            investigationID: LifecycleInvestigationID(),
            bootSessionID: fixture.bootSessionID,
            auditSessionID: 44_002,
            userID: 501
        )
        let linkedURL = try fixture.store.create(linked)
        let hardlinkURL = fixture.root.appending(path: "lease-hardlink")
        guard Darwin.link(linkedURL.path, hardlinkURL.path) == 0 else {
            throw LeaseStoreFixtureError.hardlinkFailed
        }
        #expect(throws: LifecycleLeaseStoreError.invalidFile) {
            _ = try fixture.store.readAll()
        }
        try FileManager.default.removeItem(at: hardlinkURL)
        try fixture.store.remove(linked.investigationID)

        try Data("unexpected".utf8).write(
            to: fixture.root.appending(path: "caller-selected-path")
        )
        #expect(throws: LifecycleLeaseStoreError.unknownEntry) {
            _ = try fixture.store.readAll()
        }
    }

    @Test
    func leaseDecoderRejectsUnknownFieldsInvalidVersionAndUnsafeIdentity() {
        for object: [String: Any] in [
            [
                "protocolVersion": 2,
                "investigationID": UUID().uuidString,
                "bootSessionID": UUID().uuidString,
                "auditSessionID": 44_001,
                "userID": 501,
            ],
            [
                "protocolVersion": 1,
                "investigationID": UUID().uuidString,
                "bootSessionID": UUID().uuidString,
                "auditSessionID": 0,
                "userID": 501,
            ],
            [
                "protocolVersion": 1,
                "investigationID": UUID().uuidString,
                "bootSessionID": UUID().uuidString,
                "auditSessionID": 44_001,
                "userID": 0,
            ],
            [
                "protocolVersion": 1,
                "investigationID": UUID().uuidString,
                "bootSessionID": UUID().uuidString,
                "auditSessionID": 44_001,
                "userID": 501,
                "pid": 123,
            ],
        ] {
            let data = try! JSONSerialization.data(withJSONObject: object)
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(
                    LifecycleInvestigationLease.self,
                    from: data
                )
            }
        }
    }

    @Test
    func recoveryDrainsOnlyLeasesFromTheCurrentBoot() throws {
        let currentBoot = LifecycleBootSessionID(
            rawValue: UUID(
                uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )!
        )
        let oldBoot = LifecycleBootSessionID(rawValue: UUID())
        let planner = LifecycleLeaseRecoveryPlanner(
            currentBootSessionID: currentBoot
        )
        let currentLease = try LifecycleInvestigationLease(
            investigationID: LifecycleInvestigationID(),
            bootSessionID: currentBoot,
            auditSessionID: 44_001,
            userID: 501
        )
        let staleLease = try LifecycleInvestigationLease(
            investigationID: LifecycleInvestigationID(),
            bootSessionID: oldBoot,
            auditSessionID: 44_001,
            userID: 501
        )

        #expect(
            planner.decision(for: currentLease)
                == .drain(auditSessionID: 44_001, userID: 501)
        )
        #expect(planner.decision(for: staleLease) == .retireAfterReboot)
    }

    @Test
    func initializerRejectsUnsafeIdentity() {
        #expect(throws: LifecycleLeaseStoreError.invalidLease) {
            _ = try LifecycleInvestigationLease(
                investigationID: LifecycleInvestigationID(),
                bootSessionID: LifecycleBootSessionID(rawValue: UUID()),
                auditSessionID: 0,
                userID: 501
            )
        }
    }
}

private enum LeaseStoreFixtureError: Error {
    case hardlinkFailed
}

private struct LeaseStoreFixture {
    let root: URL
    let store: LifecycleLeaseStore
    let bootSessionID = LifecycleBootSessionID(
        rawValue: UUID(
            uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        )!
    )

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-lease-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        store = try LifecycleLeaseStore(
            rootURL: root,
            requiredOwnerUserID: geteuid()
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func lifecycleLeaseMode(_ url: URL) -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return 0 }
    return information.st_mode & 0o777
}
