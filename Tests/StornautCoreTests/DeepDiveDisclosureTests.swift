import Foundation
import Testing
@testable import StornautCore

@Suite("Deep Dive disclosure semantics")
struct DeepDiveDisclosureTests {
    @Test
    func currentDescriptorHasExactVersionFingerprintAndLocaleParity() {
        let descriptor = DeepDiveDisclosureDescriptor.current

        #expect(descriptor.version.rawValue == "deep-dive-disclosure-v1")
        #expect(
            descriptor.contentFingerprint.rawValue
                == "cb7bcd1de22bfb605370e824d0eb151929153b4a43cd01b9db2162dec15993a8"
        )
        #expect(
            descriptor.dataBoundaryProfileVersion.rawValue
                == "deep-dive-data-boundary-v1"
        )
        #expect(
            descriptor.semanticItems(for: .english)
                == DeepDiveDisclosureSemanticItem.allCases
        )
        #expect(
            descriptor.semanticItems(for: .simplifiedChinese)
                == DeepDiveDisclosureSemanticItem.allCases
        )
        #expect(descriptor.semanticItems(for: .english).count == 9)
    }

    @Test
    func currentRecordStatePreservesAcceptedDeclinedAndNotPresented() throws {
        let descriptor = DeepDiveDisclosureDescriptor.current
        let decidedAt = Date(timeIntervalSince1970: 1_789_700_000)

        #expect(descriptor.state(for: nil) == .notPresented)
        let accepted = try descriptor.record(
            decision: .accepted,
            decidedAt: decidedAt
        )
        let declined = try descriptor.record(
            decision: .declined,
            decidedAt: decidedAt.addingTimeInterval(1)
        )

        #expect(descriptor.state(for: accepted) == .accepted(accepted))
        #expect(descriptor.state(for: declined) == .declined(declined))
        #expect(accepted.decidedAt == decidedAt)
        #expect(declined.decidedAt == decidedAt.addingTimeInterval(1))
    }

    @Test
    func anyMeaningfulSemanticBindingChangeMakesRecordObsolete() throws {
        let current = DeepDiveDisclosureDescriptor.current
        let record = try current.record(
            decision: .accepted,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )
        let oldVersion = try DeepDiveDisclosureDescriptor(
            version: DomainToken(rawValue: "deep-dive-disclosure-v0")!,
            contentFingerprint: current.contentFingerprint,
            dataBoundaryProfileVersion: current.dataBoundaryProfileVersion
        )
        let oldContent = try DeepDiveDisclosureDescriptor(
            version: current.version,
            contentFingerprint: DomainToken(
                rawValue: String(repeating: "a", count: 64)
            )!,
            dataBoundaryProfileVersion: current.dataBoundaryProfileVersion
        )
        let oldProfile = try DeepDiveDisclosureDescriptor(
            version: current.version,
            contentFingerprint: current.contentFingerprint,
            dataBoundaryProfileVersion: DomainToken(
                rawValue: "deep-dive-data-boundary-v0"
            )!
        )

        #expect(oldVersion.state(for: record) == .obsolete(record))
        #expect(oldContent.state(for: record) == .obsolete(record))
        #expect(oldProfile.state(for: record) == .obsolete(record))
        #expect(
            current.contentFingerprint
                == DeepDiveDisclosureDescriptor.current.contentFingerprint
        )
    }

    @Test
    func persistedRecordContainsOnlyBoundedConsentFields() throws {
        let record = try DeepDiveDisclosureDescriptor.current.record(
            decision: .accepted,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )
        let payload = try DomainJSON.encode(record)
        let object = try #require(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "schemaVersion",
            "disclosureVersion",
            "decision",
            "decidedAt",
            "contentFingerprint",
            "dataBoundaryProfileVersion",
        ])
        #expect(object["trust"] == nil)
        #expect(object["bypass"] == nil)
        #expect(object["executionAuthority"] == nil)
        #expect(object["provider"] == nil)
        #expect(object["toolPermissions"] == nil)
    }
}
