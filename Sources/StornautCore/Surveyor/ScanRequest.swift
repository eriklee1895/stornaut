import Foundation

public struct ScanRequest: Sendable {
    public static let defaultMaximumWorkers = 4
    public static let defaultMaximumPendingDirectories = 4_096
    public static let defaultStreamBufferCapacity = 1_024

    public let rootURL: URL
    public let maximumWorkers: Int
    public let maximumPendingDirectories: Int
    public let stayOnRootDevice: Bool
    public let streamBufferCapacity: Int
    let onCompletion: @Sendable () -> Void
    let testHooks: SurveyorTestHooks

    public init(
        rootURL: URL,
        maximumWorkers: Int = defaultMaximumWorkers,
        maximumPendingDirectories: Int = defaultMaximumPendingDirectories,
        stayOnRootDevice: Bool = true,
        streamBufferCapacity: Int = defaultStreamBufferCapacity,
        onCompletion: @escaping @Sendable () -> Void = {}
    ) {
        self.init(
            rootURL: rootURL,
            maximumWorkers: maximumWorkers,
            maximumPendingDirectories: maximumPendingDirectories,
            stayOnRootDevice: stayOnRootDevice,
            streamBufferCapacity: streamBufferCapacity,
            onCompletion: onCompletion,
            testHooks: SurveyorTestHooks()
        )
    }

    init(
        rootURL: URL,
        maximumWorkers: Int = defaultMaximumWorkers,
        maximumPendingDirectories: Int = defaultMaximumPendingDirectories,
        stayOnRootDevice: Bool = true,
        streamBufferCapacity: Int = defaultStreamBufferCapacity,
        onCompletion: @escaping @Sendable () -> Void = {},
        testHooks: SurveyorTestHooks
    ) {
        self.rootURL = rootURL
        self.maximumWorkers = maximumWorkers
        self.maximumPendingDirectories = maximumPendingDirectories
        self.stayOnRootDevice = stayOnRootDevice
        self.streamBufferCapacity = streamBufferCapacity
        self.onCompletion = onCompletion
        self.testHooks = testHooks
    }
}

struct SurveyorTestHooks: Sendable {
    let isMountBoundary: @Sendable (URL) -> Bool
    let issueBeforeDirectoryRead: @Sendable (URL) -> ScanIssue?
    let workerDidStart: @Sendable () -> Void
    let workerDidFinish: @Sendable () -> Void
    let queueDepthDidChange: @Sendable (Int) -> Void
    let beforeDirectoryRead: @Sendable (URL) -> Void

    init(
        isMountBoundary: @escaping @Sendable (URL) -> Bool = { _ in false },
        issueBeforeDirectoryRead: @escaping @Sendable (URL) -> ScanIssue? = {
            _ in nil
        },
        workerDidStart: @escaping @Sendable () -> Void = {},
        workerDidFinish: @escaping @Sendable () -> Void = {},
        queueDepthDidChange: @escaping @Sendable (Int) -> Void = { _ in },
        beforeDirectoryRead: @escaping @Sendable (URL) -> Void = { _ in }
    ) {
        self.isMountBoundary = isMountBoundary
        self.issueBeforeDirectoryRead = issueBeforeDirectoryRead
        self.workerDidStart = workerDidStart
        self.workerDidFinish = workerDidFinish
        self.queueDepthDidChange = queueDepthDidChange
        self.beforeDirectoryRead = beforeDirectoryRead
    }
}
