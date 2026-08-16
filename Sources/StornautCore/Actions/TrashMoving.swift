import Foundation

public struct TrashedItemReceipt: Codable, Sendable, Equatable {
    public let originalURL: URL
    public let originalIdentity: ActionFileIdentity
    public let resultingTrashURL: URL?
    public let movedAt: Date
    public let logicalBytesMoved: Int64
    public let allocatedBytesMoved: Int64

    public init(
        originalURL: URL,
        originalIdentity: ActionFileIdentity,
        resultingTrashURL: URL?,
        movedAt: Date,
        logicalBytesMoved: Int64,
        allocatedBytesMoved: Int64
    ) {
        self.originalURL = originalURL
        self.originalIdentity = originalIdentity
        self.resultingTrashURL = resultingTrashURL
        self.movedAt = movedAt
        self.logicalBytesMoved = logicalBytesMoved
        self.allocatedBytesMoved = allocatedBytesMoved
    }
}
