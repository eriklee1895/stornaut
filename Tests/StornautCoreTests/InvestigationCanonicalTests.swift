import CryptoKit
import Foundation
import Testing
@testable import StornautCore

@Test
func investigationCanonicalEmptyRecordMatchesNormativeVector() throws {
    let encoded = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.test.empty.v1",
        root: .record([])
    )

    #expect(encoded.count == 61)
    #expect(
        encoded.hexString
            == """
            53544f524e4155542d494e562d43414e4f4e2d310020000000000000001673746f\
            726e6175742e746573742e656d7074792e7631400000000000000000
            """
    )
    #expect(
        SHA256.hash(data: encoded).hexString
            == "724b07f461c7690c1e0614abdbd72081d88622e2aab47183236b6bf8e049dc3b"
    )
    #expect(
        try StornautInvestigationCanonicalV1.decode(
            encoded,
            expectedDomain: "stornaut.test.empty.v1",
            maximumInputBytes: 65_536
        ) == .record([])
    )
}

@Test
func investigationCanonicalPrimitiveVectorIsByteExactAndStrict() throws {
    let root = InvestigationCanonicalValue.record([
        .init(tag: 1, value: .unsigned(0)),
        .init(tag: 2, value: .unsigned(.max)),
        .init(tag: 3, value: .signed(-1)),
        .init(tag: 4, value: .text("é")),
        .init(tag: 5, value: .null),
        .init(tag: 6, value: .text("focused")),
        .init(tag: 7, value: .array([.text("a"), .text("b")])),
        .init(tag: 8, value: .bool(true)),
        .init(tag: 9, value: .text("e\u{301}")),
        .init(tag: 10, value: .bool(false)),
    ])
    let encoded = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.test.primitives.v1",
        root: root
    )

    #expect(encoded.count == 280)
    #expect(
        encoded.hexString
            == """
            53544f524e4155542d494e562d43414e4f4e2d310020000000000000001b73746f\
            726e6175742e746573742e7072696d6974697665732e763140000000000000000a\
            000100000000000000091000000000000000000002000000000000000910ffffff\
            ffffffffff0003000000000000000911ffffffffffffffff000400000000000000\
            0b200000000000000002c3a9000500000000000000010000060000000000000010\
            200000000000000007666f63757365640007000000000000002d30000000000000\
            0002000000000000000a20000000000000000161000000000000000a2000000000\
            000000016200080000000000000001020009000000000000000c20000000000000\
            000365cc81000a000000000000000101
            """
    )
    #expect(
        SHA256.hash(data: encoded).hexString
            == "56a27067b51cef0ebc1236d51200b250987fce1ee74832047fa2063ef0da9075"
    )
    #expect(
        try StornautInvestigationCanonicalV1.decode(
            encoded,
            expectedDomain: "stornaut.test.primitives.v1",
            maximumInputBytes: 65_536
        ) == root
    )

    var trailing = encoded
    trailing.append(0)
    #expect(throws: InvestigationCanonicalError.trailingBytes) {
        _ = try StornautInvestigationCanonicalV1.decode(
            trailing,
            expectedDomain: "stornaut.test.primitives.v1",
            maximumInputBytes: 65_536
        )
    }
    #expect(throws: InvestigationCanonicalError.domainMismatch) {
        _ = try StornautInvestigationCanonicalV1.decode(
            encoded,
            expectedDomain: "stornaut.test.empty.v1",
            maximumInputBytes: 65_536
        )
    }
    #expect(throws: InvestigationCanonicalError.inputTooLarge) {
        _ = try StornautInvestigationCanonicalV1.decode(
            encoded,
            expectedDomain: "stornaut.test.primitives.v1",
            maximumInputBytes: encoded.count - 1
        )
    }
}

@Test
func investigationCanonicalRejectsNonRecordRootAndNonCanonicalRecords() {
    #expect(throws: InvestigationCanonicalError.rootMustBeRecord) {
        _ = try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.test.empty.v1",
            root: .text("not-a-record")
        )
    }
    #expect(throws: InvestigationCanonicalError.nonCanonicalRecord) {
        _ = try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.test.empty.v1",
            root: .record([
                .init(tag: 2, value: .null),
                .init(tag: 1, value: .null),
            ])
        )
    }
    #expect(throws: InvestigationCanonicalError.nonCanonicalRecord) {
        _ = try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.test.empty.v1",
            root: .record([
                .init(tag: 1, value: .null),
                .init(tag: 1, value: .null),
            ])
        )
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
