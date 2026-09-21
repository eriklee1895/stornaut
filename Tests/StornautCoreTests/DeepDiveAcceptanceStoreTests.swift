import Darwin
import Foundation
import Testing
@testable import StornautCore

@Suite("Deep Dive disclosure preference store")
struct DeepDiveAcceptanceStoreTests {
    @Test
    func roundTripsBothDecisionsAndForgetsExactly() async throws {
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: .memory
        )
        let descriptor = DeepDiveDisclosureDescriptor.current
        let accepted = try descriptor.record(
            decision: .accepted,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )
        let declined = try descriptor.record(
            decision: .declined,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_001)
        )

        #expect(try await store.load() == nil)
        try await store.save(accepted)
        #expect(try await store.load() == accepted)
        try await store.save(declined)
        #expect(try await store.load() == declined)
        try await store.forget()
        #expect(try await store.load() == nil)
    }

    @Test
    func rejectsUnknownKeysSchemasAndOversizedPayloads() async throws {
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: .memory
        )
        let valid = try DomainJSON.encode(
            DeepDiveDisclosureDescriptor.current.record(
                decision: .accepted,
                decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
            )
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        object["trustCodex"] = true
        try await store._testReplacePayload(
            JSONSerialization.data(withJSONObject: object)
        )
        await #expect(throws: DeepDiveDisclosureStoreError.invalidPayload) {
            _ = try await store.load()
        }

        object["contentFingerprint"] = String(repeating: "a", count: 64)
        object.removeValue(forKey: "decision")
        try await store._testReplacePayload(
            JSONSerialization.data(withJSONObject: object)
        )
        await #expect(throws: DeepDiveDisclosureStoreError.invalidPayload) {
            _ = try await store.load()
        }

        object.removeValue(forKey: "trustCodex")
        object["schemaVersion"] = 999
        try await store._testReplacePayload(
            JSONSerialization.data(withJSONObject: object)
        )
        await #expect(
            throws: DeepDiveDisclosureStoreError.unsupportedSchema
        ) {
            _ = try await store.load()
        }

        object["schemaVersion"] = 1
        object["contentFingerprint"] = String(repeating: "z", count: 64)
        try await store._testReplacePayload(
            JSONSerialization.data(withJSONObject: object)
        )
        await #expect(throws: DeepDiveDisclosureStoreError.invalidPayload) {
            _ = try await store.load()
        }

        try await store._testReplacePayload(
            Data(
                repeating: 0x41,
                count: DeepDiveDisclosurePreferenceStore.maximumPayloadBytes + 1
            )
        )
        await #expect(
            throws: DeepDiveDisclosureStoreError.payloadTooLarge
        ) {
            _ = try await store.load()
        }
    }

    @Test
    func failedAtomicMutationPreservesLastDurableRecord() async throws {
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: .memory
        )
        let descriptor = DeepDiveDisclosureDescriptor.current
        let accepted = try descriptor.record(
            decision: .accepted,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )
        let declined = try descriptor.record(
            decision: .declined,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_001)
        )
        try await store.save(accepted)
        await store._testFailNextMutation()

        await #expect(throws: DeepDiveDisclosureStoreError.unsafeStorage) {
            try await store.save(declined)
        }
        #expect(try await store.load() == accepted)

        await store._testFailNextMutation()
        await #expect(throws: DeepDiveDisclosureStoreError.unsafeStorage) {
            try await store.forget()
        }
        #expect(try await store.load() == accepted)
    }

    @Test
    func fileStorageIsPrivateDedicatedAndNotEvidenceOrKnowledge() async throws {
        let root = try EvidenceStoreTestSupport.temporaryDirectory(
            "deep-dive-disclosure"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
            root: root
        )
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: configuration
        )
        let record = try DeepDiveDisclosureDescriptor.current.record(
            decision: .accepted,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )

        try await store.save(record)

        #expect(
            configuration.deepDiveDisclosureURL.lastPathComponent
                == "DeepDiveDisclosure.json"
        )
        #expect(
            configuration.deepDiveDisclosureURL
                != configuration.settingsPreferencesURL
        )
        #expect(
            configuration.deepDiveDisclosureURL
                != configuration.evidenceDatabaseURL
        )
        #expect(
            configuration.deepDiveDisclosureURL
                != configuration.localKnowledgeDatabaseURL
        )
        #expect(try fileMode(configuration.deepDiveDisclosureURL) == 0o600)
        #expect(
            try configuration.deepDiveDisclosureURL.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            ).isExcludedFromBackup == true
        )
        #expect(try await store.load() == record)
        try await store.forget()
        #expect(try await store.load() == nil)
    }

    @Test
    func diskLoadRejectsOversizedSparsePayloadBeforeDecoding() async throws {
        let root = try EvidenceStoreTestSupport.temporaryDirectory(
            "deep-dive-disclosure-oversized"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
            root: root
        )
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: configuration
        )
        let descriptor = open(
            configuration.deepDiveDisclosureURL.path,
            O_WRONLY | O_CLOEXEC | O_NOFOLLOW
        )
        #expect(descriptor >= 0)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        #expect(
            ftruncate(
                descriptor,
                off_t(
                    DeepDiveDisclosurePreferenceStore.maximumPayloadBytes + 1
                )
            ) == 0
        )

        await #expect(
            throws: DeepDiveDisclosureStoreError.payloadTooLarge
        ) {
            _ = try await store.load()
        }
    }

    @Test
    func diskLoadRejectsPathReplacementWithNonRegularNode() async throws {
        let root = try EvidenceStoreTestSupport.temporaryDirectory(
            "deep-dive-disclosure-node"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
            root: root
        )
        let store = try DeepDiveDisclosurePreferenceStore(
            configuration: configuration
        )
        try FileManager.default.removeItem(
            at: configuration.deepDiveDisclosureURL
        )
        try FileManager.default.createDirectory(
            at: configuration.deepDiveDisclosureURL,
            withIntermediateDirectories: false
        )

        await #expect(throws: DeepDiveDisclosureStoreError.unsafeStorage) {
            _ = try await store.load()
        }
    }
}

private func fileMode(_ url: URL) throws -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
        throw CocoaError(.fileReadUnknown)
    }
    return information.st_mode & 0o777
}
