import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "STORNAUT_RUN_PLATFORM_TRASH_DIAGNOSTIC"
        ] == "1",
        "Opt in to moving and restoring uniquely named disposable fixtures"
    )
)
func platformTrashLifecycleDiagnostic() async throws {
    let rootURL = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-platform-trash-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let restoreURL = rootURL.appending(
        path: "restored",
        directoryHint: .isDirectory
    )
    var trashedURLs: [URL] = []
    defer {
        for (index, trashedURL) in trashedURLs.enumerated() {
            guard FileManager.default.fileExists(atPath: trashedURL.path) else {
                continue
            }
            let destination = restoreURL.appending(
                path: "deferred-\(index)"
            )
            try? FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.moveItem(
                at: trashedURL,
                to: destination
            )
        }
        try? FileManager.default.removeItem(at: rootURL)
    }
    try FileManager.default.createDirectory(
        at: restoreURL,
        withIntermediateDirectories: true
    )

    let ordinaryURL = rootURL.appending(path: "ordinary.bin")
    try Data(repeating: 0x53, count: 4_096).write(to: ordinaryURL)
    let ordinaryIdentity = try #require(
        ActionFileIdentity.read(at: ordinaryURL)
    )
    let ordinaryReceipt = try await TrashMoving().trashItem(
        at: ordinaryURL,
        expectedIdentity: ordinaryIdentity
    )
    let ordinaryTrashURL = try #require(ordinaryReceipt.resultingTrashURL)
    trashedURLs.append(ordinaryTrashURL)
    #expect(!FileManager.default.fileExists(atPath: ordinaryURL.path))
    #expect(ActionFileIdentity.read(at: ordinaryTrashURL) == ordinaryIdentity)

    let firstCollisionURL = rootURL.appending(path: "first/same-name")
    let secondCollisionURL = rootURL.appending(path: "second/same-name")
    try writePlatformTrashFixture("first", to: firstCollisionURL)
    try writePlatformTrashFixture("second", to: secondCollisionURL)
    let firstCollisionReceipt = try await TrashMoving().trashItem(
        at: firstCollisionURL,
        expectedIdentity: try #require(
            ActionFileIdentity.read(at: firstCollisionURL)
        )
    )
    let secondCollisionReceipt = try await TrashMoving().trashItem(
        at: secondCollisionURL,
        expectedIdentity: try #require(
            ActionFileIdentity.read(at: secondCollisionURL)
        )
    )
    let firstTrashURL = try #require(
        firstCollisionReceipt.resultingTrashURL
    )
    let secondTrashURL = try #require(
        secondCollisionReceipt.resultingTrashURL
    )
    trashedURLs.append(contentsOf: [firstTrashURL, secondTrashURL])
    #expect(firstTrashURL != secondTrashURL)

    let largeURL = rootURL.appending(
        path: "large-directory",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: largeURL,
        withIntermediateDirectories: true
    )
    for index in 0..<2_000 {
        try Data("fixture-\(index)".utf8).write(
            to: largeURL.appending(path: "file-\(index)")
        )
    }
    let callState = PlatformTrashCallState()
    let largeTask = Task.detached {
        callState.markStarted()
        let resultingURL = try FileManagerTrashAdapter().trashItem(
            at: largeURL
        )
        return (resultingURL, Task.isCancelled)
    }
    while !callState.started {
        await Task.yield()
    }
    largeTask.cancel()
    let (largeTrashURL, observedCancellation) = try await largeTask.value
    let confirmedLargeTrashURL = try #require(largeTrashURL)
    trashedURLs.append(confirmedLargeTrashURL)
    #expect(observedCancellation)
    #expect(!FileManager.default.fileExists(atPath: largeURL.path))

    let deniedParentURL = rootURL.appending(
        path: "permission-denied",
        directoryHint: .isDirectory
    )
    let deniedURL = deniedParentURL.appending(path: "keep")
    try writePlatformTrashFixture("keep", to: deniedURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o555],
        ofItemAtPath: deniedParentURL.path
    )
    var permissionDenied = false
    do {
        let destination = try FileManagerTrashAdapter().trashItem(
            at: deniedURL
        )
        if let destination {
            trashedURLs.append(destination)
        }
    } catch {
        permissionDenied = true
    }
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: deniedParentURL.path
    )

    var mountedVolumeResult = "not-requested"
    if let mountedRootPath = ProcessInfo.processInfo.environment[
        "STORNAUT_TRASH_PROBE_VOLUME_ROOT"
    ] {
        let mountedRootURL = URL(
            filePath: mountedRootPath,
            directoryHint: .isDirectory
        )
        let mountedURL = mountedRootURL.appending(
            path: "stornaut-mounted-trash-\(UUID().uuidString)"
        )
        try writePlatformTrashFixture("mounted", to: mountedURL)
        let receipt = try await TrashMoving().trashItem(
            at: mountedURL,
            expectedIdentity: try #require(
                ActionFileIdentity.read(at: mountedURL)
            )
        )
        let destination = try #require(receipt.resultingTrashURL)
        trashedURLs.append(destination)
        mountedVolumeResult = destination.path
    }

    print("Platform Trash process: swift-test CLI")
    print("Same-volume destination returned: true")
    print(
        "Collision names: "
            + "\(firstTrashURL.lastPathComponent),"
            + "\(secondTrashURL.lastPathComponent)"
    )
    print(
        "Cancellation observed only after synchronous call: "
            + "\(observedCancellation)"
    )
    print("Permission denial observed: \(permissionDenied)")
    print(
        "Mounted-volume destination: "
            + anonymizedPlatformTrashDestination(mountedVolumeResult)
    )
}

private func writePlatformTrashFixture(
    _ value: String,
    to url: URL
) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(value.utf8).write(to: url)
}

private func anonymizedPlatformTrashDestination(_ path: String) -> String {
    guard path != "not-requested" else {
        return path
    }
    return path.contains(".Trashes") ? "volume-trash" : "other-trash"
}

private final class PlatformTrashCallState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedStarted = false

    var started: Bool {
        lock.withLock { storedStarted }
    }

    func markStarted() {
        lock.withLock {
            storedStarted = true
        }
    }
}
