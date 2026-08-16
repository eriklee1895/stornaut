import Foundation

protocol TrashAdapting: Sendable {
    func trashItem(at url: URL) throws -> URL?
}

enum TrashAdapterError: Error, Sendable, Equatable {
    case permissionDenied
    case operationFailed(String)
}

struct FileManagerTrashAdapter: TrashAdapting {
    init() {}

    func trashItem(at url: URL) throws -> URL? {
        var resultingURL: NSURL?
        do {
            try FileManager.default.trashItem(
                at: url,
                resultingItemURL: &resultingURL
            )
            return resultingURL as URL?
        } catch let error as CocoaError
            where error.code == .fileReadNoPermission
                || error.code == .fileWriteNoPermission
        {
            throw TrashAdapterError.permissionDenied
        } catch {
            throw TrashAdapterError.operationFailed(
                String(describing: error)
            )
        }
    }
}

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

typealias TrashMovingError = CleanupActionExecutionFailure

struct TrashMoving: Sendable {
    private let adapter: any TrashAdapting

    init(adapter: any TrashAdapting) {
        self.adapter = adapter
    }

    func trashItem(
        at url: URL,
        expectedIdentity: ActionFileIdentity
    ) async throws -> TrashedItemReceipt {
        try Task.checkCancellation()
        guard let observedIdentity = ActionFileIdentity.read(at: url) else {
            throw TrashMovingError.missingItem
        }
        guard observedIdentity == expectedIdentity else {
            throw TrashMovingError.identityChanged
        }
        try Task.checkCancellation()

        let resultingURL: URL?
        do {
            resultingURL = try adapter.trashItem(at: url)
        } catch TrashAdapterError.permissionDenied {
            throw TrashMovingError.permissionDenied
        } catch let TrashAdapterError.operationFailed(reason) {
            throw TrashMovingError.operationFailed(reason)
        } catch {
            throw TrashMovingError.operationFailed(
                String(describing: error)
            )
        }

        if ActionFileIdentity.read(at: url) == expectedIdentity {
            throw TrashMovingError.postconditionFailed
        }
        if let resultingURL,
           ActionFileIdentity.read(at: resultingURL) != expectedIdentity
        {
            throw TrashMovingError.postconditionFailed
        }

        return TrashedItemReceipt(
            originalURL: url,
            originalIdentity: expectedIdentity,
            resultingTrashURL: resultingURL,
            movedAt: Date(),
            logicalBytesMoved: expectedIdentity.size,
            allocatedBytesMoved: expectedIdentity.allocatedBytes
        )
    }
}
