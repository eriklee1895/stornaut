import Foundation
import Testing
@testable import StornautCore

@Test
func trashMovingReturnsIdentityDestinationAndMovedBytesWithoutFreeSpaceClaim() async throws {
    let fixture = try TrashFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "cache.bin")
    try Data(repeating: 0x41, count: 8_192).write(to: targetURL)
    let adapter = FakeTrashAdapter(destinationRoot: fixture.trashURL)
    let identity = try #require(ActionFileIdentity.read(at: targetURL))

    let receipt = try await TrashMoving(adapter: adapter)
        .trashItem(at: targetURL, expectedIdentity: identity)

    #expect(receipt.originalURL == targetURL)
    #expect(receipt.originalIdentity == identity)
    #expect(
        receipt.resultingTrashURL?.deletingLastPathComponent().path
            == fixture.trashURL.path
    )
    #expect(receipt.logicalBytesMoved == identity.size)
    #expect(receipt.allocatedBytesMoved == identity.allocatedBytes)
    #expect(!FileManager.default.fileExists(atPath: targetURL.path))
    #expect(try #require(receipt.resultingTrashURL).checkResourceIsReachable())
    let encoded = String(
        decoding: try JSONEncoder().encode(receipt),
        as: UTF8.self
    )
    #expect(!encoded.lowercased().contains("freed"))
}

@Test
func trashMovingPreservesBothCollidingItemsUsingAdapterDestination() async throws {
    let fixture = try TrashFixture()
    defer { fixture.remove() }
    let firstURL = fixture.rootURL.appending(path: "first/cache")
    let secondURL = fixture.rootURL.appending(path: "second/cache")
    try fixture.write(Data("one".utf8), to: firstURL)
    try fixture.write(Data("two".utf8), to: secondURL)
    let adapter = FakeTrashAdapter(destinationRoot: fixture.trashURL)
    let mover = TrashMoving(adapter: adapter)

    let first = try await mover.trashItem(
        at: firstURL,
        expectedIdentity: try #require(ActionFileIdentity.read(at: firstURL))
    )
    let second = try await mover.trashItem(
        at: secondURL,
        expectedIdentity: try #require(ActionFileIdentity.read(at: secondURL))
    )

    #expect(first.resultingTrashURL != second.resultingTrashURL)
    #expect(try #require(first.resultingTrashURL).lastPathComponent == "cache")
    #expect(try #require(second.resultingTrashURL).lastPathComponent == "cache-1")
}

@Test
func trashMovingFailureLeavesOriginalAndNeverCallsPermanentDelete() async throws {
    let fixture = try TrashFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "protected")
    try fixture.write(Data("keep".utf8), to: targetURL)
    let adapter = FakeTrashAdapter(
        destinationRoot: fixture.trashURL,
        failure: .permissionDenied
    )
    let mover = TrashMoving(adapter: adapter)

    await #expect(throws: TrashMovingError.permissionDenied) {
        _ = try await mover.trashItem(
            at: targetURL,
            expectedIdentity: try #require(
                ActionFileIdentity.read(at: targetURL)
            )
        )
    }

    #expect(FileManager.default.fileExists(atPath: targetURL.path))
}

@Test
func trashMovingRejectsMissingCancellationAndIdentityReplacementBeforeAdapter() async throws {
    let fixture = try TrashFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "target")
    let replacementURL = fixture.rootURL.appending(path: "replacement")
    try fixture.write(Data("target".utf8), to: targetURL)
    try fixture.write(Data("replacement".utf8), to: replacementURL)
    let original = try #require(ActionFileIdentity.read(at: targetURL))
    let adapter = FakeTrashAdapter(destinationRoot: fixture.trashURL)
    let mover = TrashMoving(adapter: adapter)

    await #expect(throws: TrashMovingError.missingItem) {
        _ = try await mover.trashItem(
            at: fixture.rootURL.appending(path: "missing"),
            expectedIdentity: original
        )
    }

    let task = Task {
        try await mover.trashItem(
            at: targetURL,
            expectedIdentity: original
        )
    }
    task.cancel()
    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }
    #expect(adapter.callCount == 0)

    try FileManager.default.removeItem(at: targetURL)
    try FileManager.default.moveItem(at: replacementURL, to: targetURL)
    await #expect(throws: TrashMovingError.identityChanged) {
        _ = try await mover.trashItem(
            at: targetURL,
            expectedIdentity: original
        )
    }
    #expect(adapter.callCount == 0)
}

@Test
func trashMovingFailsClosedWhenAdapterReturnsButOriginalIdentityRemains() async throws {
    let fixture = try TrashFixture()
    defer { fixture.remove() }
    let targetURL = fixture.rootURL.appending(path: "target")
    try fixture.write(Data("target".utf8), to: targetURL)
    let identity = try #require(ActionFileIdentity.read(at: targetURL))
    let adapter = FakeTrashAdapter(
        destinationRoot: fixture.trashURL,
        leaveOriginalInPlace: true
    )

    await #expect(throws: TrashMovingError.postconditionFailed) {
        _ = try await TrashMoving(adapter: adapter).trashItem(
            at: targetURL,
            expectedIdentity: identity
        )
    }
    #expect(FileManager.default.fileExists(atPath: targetURL.path))
}

private final class FakeTrashAdapter: TrashAdapting, @unchecked Sendable {
    enum Failure {
        case permissionDenied
    }

    private let lock = NSLock()
    private let destinationRoot: URL
    private let failure: Failure?
    private let leaveOriginalInPlace: Bool
    private var storedCallCount = 0

    init(
        destinationRoot: URL,
        failure: Failure? = nil,
        leaveOriginalInPlace: Bool = false
    ) {
        self.destinationRoot = destinationRoot
        self.failure = failure
        self.leaveOriginalInPlace = leaveOriginalInPlace
    }

    var callCount: Int {
        lock.withLock { storedCallCount }
    }

    func trashItem(at url: URL) throws -> URL? {
        lock.withLock { storedCallCount += 1 }
        if failure == .permissionDenied {
            throw TrashAdapterError.permissionDenied
        }
        var destination = destinationRoot.appending(path: url.lastPathComponent)
        var suffix = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = destinationRoot.appending(
                path: "\(url.lastPathComponent)-\(suffix)"
            )
            suffix += 1
        }
        if leaveOriginalInPlace {
            try FileManager.default.copyItem(at: url, to: destination)
        } else {
            try FileManager.default.moveItem(at: url, to: destination)
        }
        return destination
    }
}

private struct TrashFixture {
    let parentURL: URL
    let rootURL: URL
    let trashURL: URL

    init() throws {
        parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-trash-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "root")
        trashURL = parentURL.appending(path: "trash")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: trashURL,
            withIntermediateDirectories: true
        )
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}
