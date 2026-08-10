import Foundation

public struct ScanRequest: Sendable {
    public static let defaultMaximumWorkers = 4
    public static let defaultMaximumPendingDirectories = 4_096
    public static let defaultStreamBufferCapacity = 1_024
    public static let defaultLifecycleEventBufferCapacity = 1_024
    public static let defaultPersistenceBatchSize = 64
    public static let maximumWorkersLimit = 64
    public static let maximumPendingDirectoriesLimit = 65_536
    public static let maximumStreamBufferCapacity = 16_384
    public static let maximumLifecycleEventBufferCapacity = 16_384
    public static let maximumPersistenceBatchSize = 100

    public let rootURL: URL
    public let exclusions: [ScanExclusion]
    public let maximumWorkers: Int
    public let maximumPendingDirectories: Int
    public let stayOnRootDevice: Bool
    public let streamBufferCapacity: Int
    public let lifecycleEventBufferCapacity: Int
    public let persistenceBatchSize: Int
    public let sessionID: ScanSessionID
    public let scopeID: ScanScopeID
    let onCompletion: @Sendable () -> Void
    let testHooks: SurveyorTestHooks

    public init(
        rootURL: URL,
        exclusions: [ScanExclusion] = [],
        maximumWorkers: Int = defaultMaximumWorkers,
        maximumPendingDirectories: Int = defaultMaximumPendingDirectories,
        stayOnRootDevice: Bool = true,
        streamBufferCapacity: Int = defaultStreamBufferCapacity,
        lifecycleEventBufferCapacity: Int =
            defaultLifecycleEventBufferCapacity,
        persistenceBatchSize: Int = defaultPersistenceBatchSize,
        sessionID: ScanSessionID = ScanSessionID(),
        scopeID: ScanScopeID = ScanScopeID(),
        onCompletion: @escaping @Sendable () -> Void = {}
    ) {
        self.init(
            rootURL: rootURL,
            exclusions: exclusions,
            maximumWorkers: maximumWorkers,
            maximumPendingDirectories: maximumPendingDirectories,
            stayOnRootDevice: stayOnRootDevice,
            streamBufferCapacity: streamBufferCapacity,
            lifecycleEventBufferCapacity: lifecycleEventBufferCapacity,
            persistenceBatchSize: persistenceBatchSize,
            sessionID: sessionID,
            scopeID: scopeID,
            onCompletion: onCompletion,
            testHooks: SurveyorTestHooks()
        )
    }

    init(
        rootURL: URL,
        exclusions: [ScanExclusion] = [],
        maximumWorkers: Int = defaultMaximumWorkers,
        maximumPendingDirectories: Int = defaultMaximumPendingDirectories,
        stayOnRootDevice: Bool = true,
        streamBufferCapacity: Int = defaultStreamBufferCapacity,
        lifecycleEventBufferCapacity: Int =
            defaultLifecycleEventBufferCapacity,
        persistenceBatchSize: Int = defaultPersistenceBatchSize,
        sessionID: ScanSessionID = ScanSessionID(),
        scopeID: ScanScopeID = ScanScopeID(),
        onCompletion: @escaping @Sendable () -> Void = {},
        testHooks: SurveyorTestHooks
    ) {
        self.rootURL = rootURL
        self.exclusions = exclusions
        self.maximumWorkers = maximumWorkers
        self.maximumPendingDirectories = maximumPendingDirectories
        self.stayOnRootDevice = stayOnRootDevice
        self.streamBufferCapacity = streamBufferCapacity
        self.lifecycleEventBufferCapacity = lifecycleEventBufferCapacity
        self.persistenceBatchSize = persistenceBatchSize
        self.sessionID = sessionID
        self.scopeID = scopeID
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
