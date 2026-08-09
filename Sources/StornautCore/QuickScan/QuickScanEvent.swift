import Foundation

public enum QuickScanStage: String, Codable, Sendable, CaseIterable {
    case indexVolumes
    case mapProjects
    case classifyArtifacts
    case checkActivity
    case finalizeSnapshot
}

public enum QuickScanFact: Sendable, Equatable {
    case volumeBaseline(VolumeBaseline)
    case pathSnapshot(PathSnapshot)
}

public struct QuickScanIssueObservation: Sendable, Equatable {
    public let scopeID: ScanScopeID
    public let relativePath: PersistedPath
    public let issue: ScanIssue
    public let observedAt: Date

    public init(
        scopeID: ScanScopeID,
        relativePath: PersistedPath,
        issue: ScanIssue,
        observedAt: Date
    ) {
        self.scopeID = scopeID
        self.relativePath = relativePath
        self.issue = issue
        self.observedAt = observedAt
    }
}

public struct QuickScanProgress: Sendable, Equatable {
    public let scopeID: ScanScopeID
    public let currentRelativePath: PersistedPath
    public let counters: ScanProgress

    public init(
        scopeID: ScanScopeID,
        currentRelativePath: PersistedPath,
        counters: ScanProgress
    ) {
        self.scopeID = scopeID
        self.currentRelativePath = currentRelativePath
        self.counters = counters
    }
}

public enum QuickScanScopeResult: Sendable, Equatable {
    case completed(ScanScope)
    case unfinished(UnfinishedScanScope)
}

public enum QuickScanEvent: Sendable, Equatable {
    case stageChanged(QuickScanStage)
    case progress(QuickScanProgress)
    case factObserved(QuickScanFact)
    case issueObserved(QuickScanIssueObservation)
    case scopeFinished(QuickScanScopeResult)
    case terminal(ScanSession)
}

public enum QuickScanLifecycleError: Error, Sendable, Equatable {
    case scanAlreadyRunning
    case invalidPersistenceBatchSize
    case invalidEventBufferCapacity
    case eventBufferExceeded(limit: Int)
    case terminalPersistenceFailed
}
