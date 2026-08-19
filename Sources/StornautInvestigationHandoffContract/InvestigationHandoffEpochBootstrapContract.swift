import Foundation

package struct InvestigationHandoffEpochBootstrap:
    Sendable,
    Equatable
{
    package static let magic: UInt32 = 0x5354_4e50
    package static let version: UInt16 = 1
    package static let byteCount = 32

    package let epochUUID: UUID
    package let epochDeadlineNanoseconds: UInt64

    package init(
        epochUUID: UUID,
        epochDeadlineNanoseconds: UInt64
    ) throws {
        guard
            handoffUUIDIsNonzero(epochUUID),
            epochDeadlineNanoseconds > 0
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.epochUUID = epochUUID
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
    }

    package func encoded() -> Data {
        var data = Data()
        data.reserveCapacity(Self.byteCount)
        data.append(handoffData(Self.magic))
        data.append(handoffData(Self.version))
        data.append(handoffData(UInt16(Self.byteCount)))
        data.append(handoffData(epochUUID))
        data.append(handoffData(epochDeadlineNanoseconds))
        precondition(data.count == Self.byteCount)
        return data
    }

    package static func decode(_ data: Data) throws -> Self {
        guard data.count == Self.byteCount else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        var cursor = HandoffBinaryCursor(data: data)
        guard
            try cursor.readUInt32() == Self.magic,
            try cursor.readUInt16() == Self.version,
            try cursor.readUInt16() == UInt16(Self.byteCount)
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let epochUUID = try handoffUUID(cursor.read(count: 16))
        let deadline = try cursor.readUInt64()
        guard cursor.isAtEnd else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return try Self(
            epochUUID: epochUUID,
            epochDeadlineNanoseconds: deadline
        )
    }
}
