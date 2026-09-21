import Foundation
import StornautCore

enum ScanFlowPhase: String, Sendable, Equatable {
    case idle
    case active
    case stopping
    case completed
    case partial
    case cancelled
    case limitedPermission
    case failed
}

enum ScanStageStatus: String, Sendable, Equatable {
    case complete
    case current
    case incomplete
    case unavailable
    case pending
}

struct ScanStageState: Identifiable, Sendable, Equatable {
    let stage: QuickScanStage
    let status: ScanStageStatus

    var id: QuickScanStage { stage }
}

struct ScanFlowState: Sendable, Equatable {
    let phase: ScanFlowPhase
    let stageStates: [ScanStageState]
    let currentStage: QuickScanStage?
    let currentScopeID: ScanScopeID?
    let currentRelativePath: PersistedPath?
    let scopeScanned: Int
    let candidatesFound: Int
    let measuredBytes: ByteCount
    let elapsed: TimeInterval
    let startedAt: Date?
    let rootPath: PersistedPath?
    let stopWasRequested: Bool
    let snapshots: [PathSnapshot]
    let classifications: [Classification]
    let evidence: [EvidenceRecord]
    let ledger: SpaceLedger?
    let projection: QuickScanProjection?
    let productIssues: [QuickScanProductIssue]
    let reasonKey: DomainToken?

    static let idle = ScanFlowState(
        phase: .idle,
        stageStates: pendingStages,
        currentStage: nil,
        currentScopeID: nil,
        currentRelativePath: nil,
        scopeScanned: 0,
        candidatesFound: 0,
        measuredBytes: ByteCount(0)!,
        elapsed: 0,
        startedAt: nil,
        rootPath: nil,
        stopWasRequested: false,
        snapshots: [],
        classifications: [],
        evidence: [],
        ledger: nil,
        projection: nil,
        productIssues: [],
        reasonKey: nil
    )

    static func retained(
        _ projection: QuickScanProjection
    ) -> ScanFlowState {
        ScanFlowState(
            phase: terminalPhase(for: projection),
            stageStates: projection.session.terminalState == .completed
                ? completeStages
                : unavailableStages,
            currentStage: nil,
            currentScopeID: nil,
            currentRelativePath: nil,
            scopeScanned: projection.snapshotCount,
            candidatesFound: projection.candidateCount,
            measuredBytes: measuredBytes(in: projection),
            elapsed: max(
                0,
                projection.session.finishedAt.timeIntervalSince(
                    projection.session.startedAt
                )
            ),
            startedAt: projection.session.startedAt,
            rootPath: projection.session.completedScopes.first?.rootPath
                ?? projection.session.unfinishedScopes.first?.rootPath,
            stopWasRequested:
                projection.session.terminalState == .cancelled,
            snapshots: projection.snapshots,
            classifications: projection.classifications,
            evidence: projection.evidence,
            ledger: projection.ledger,
            projection: projection,
            productIssues: projection.issues,
            reasonKey: nil
        )
    }

    var isActive: Bool {
        phase == .active || phase == .stopping
    }

    fileprivate static let pendingStages = QuickScanStage.allCases.map {
        ScanStageState(stage: $0, status: .pending)
    }

    fileprivate static let completeStages = QuickScanStage.allCases.map {
        ScanStageState(stage: $0, status: .complete)
    }

    fileprivate static let unavailableStages = QuickScanStage.allCases.map {
        ScanStageState(stage: $0, status: .unavailable)
    }

    fileprivate static func terminalPhase(
        for projection: QuickScanProjection
    ) -> ScanFlowPhase {
        switch projection.session.terminalState {
        case .completed:
            .completed
        case .partial where hasPermissionGap(projection):
            .limitedPermission
        case .partial:
            .partial
        case .cancelled:
            .cancelled
        case .failed:
            .failed
        }
    }

    fileprivate static func measuredBytes(
        in projection: QuickScanProjection
    ) -> ByteCount {
        if let allocated = projection.session.aggregate?
            .allocatedFileBytes
        {
            return ByteCount(UInt64(allocated))!
        }
        var total: UInt64 = 0
        var countedHardLinks = Set<ScanHardLinkIdentity>()
        for snapshot in projection.snapshots {
            guard snapshot.kind == .regularFile,
                  let bytes = snapshot.allocatedByteCount
            else {
                continue
            }
            if let identity = snapshot.fileIdentity,
               identity.isHardLinkCandidate
            {
                let hardLink = ScanHardLinkIdentity(
                    device: identity.device,
                    inode: identity.inode
                )
                guard countedHardLinks.insert(hardLink).inserted else {
                    continue
                }
            }
            guard total <= UInt64(Int64.max) - bytes.value else {
                return ByteCount(UInt64(Int64.max))!
            }
            total += bytes.value
        }
        return ByteCount(total)!
    }
}

struct ScanFlowReducer: Sendable {
    func started(
        previous: ScanFlowState,
        at date: Date,
        rootPath: PersistedPath? = nil
    ) -> ScanFlowState {
        guard !previous.isActive else {
            return previous
        }
        return ScanFlowState(
            phase: .active,
            stageStates: ScanFlowState.pendingStages,
            currentStage: nil,
            currentScopeID: nil,
            currentRelativePath: nil,
            scopeScanned: 0,
            candidatesFound: 0,
            measuredBytes: ByteCount(0)!,
            elapsed: 0,
            startedAt: date,
            rootPath: rootPath ?? previous.rootPath,
            stopWasRequested: false,
            snapshots: [],
            classifications: [],
            evidence: [],
            ledger: nil,
            projection: previous.projection,
            productIssues: [],
            reasonKey: nil
        )
    }

    func stopRequested(state: ScanFlowState) -> ScanFlowState {
        guard state.phase == .active else {
            return state
        }
        return replacing(
            state,
            phase: .stopping,
            stopWasRequested: true
        )
    }

    func configuredRoot(
        state: ScanFlowState,
        rootPath: PersistedPath
    ) -> ScanFlowState {
        guard state.isActive else {
            return state
        }
        return replacing(state, rootPath: rootPath)
    }

    func elapsed(
        state: ScanFlowState,
        at date: Date
    ) -> ScanFlowState {
        guard state.isActive, let startedAt = state.startedAt else {
            return state
        }
        return replacing(
            state,
            elapsed: max(0, date.timeIntervalSince(startedAt))
        )
    }

    func failed(
        state: ScanFlowState,
        reasonKey: DomainToken
    ) -> ScanFlowState {
        let base: ScanFlowState
        if state.scopeScanned == 0,
           state.snapshots.isEmpty,
           state.classifications.isEmpty,
           let projection = state.projection
        {
            base = .retained(projection)
        } else {
            base = state
        }
        return replacing(
            base,
            phase: .failed,
            stageStates: incompleteCurrentStage(base.stageStates),
            currentStage: .some(nil),
            reasonKey: reasonKey
        )
    }

    func reduce(
        _ event: QuickScanProductEvent,
        state: ScanFlowState
    ) -> ScanFlowState {
        guard state.isActive else {
            return state
        }
        switch event {
        case let .stageChanged(stage):
            return stageChanged(stage, state: state)
        case let .progress(progress):
            return progressChanged(progress, state: state)
        case .issueObserved:
            return state
        case let .classifiedSnapshotObserved(snapshot, classification):
            let snapshots = replacingByID(
                state.snapshots,
                with: snapshot,
                id: \.id
            )
            let classifications = replacingByID(
                state.classifications,
                with: classification,
                id: \.id
            )
            return replacing(
                state,
                candidatesFound: candidateCount(
                    classifications: classifications,
                    snapshots: snapshots
                ),
                snapshots: snapshots,
                classifications: classifications
            )
        case let .evidenceObserved(record):
            return replacing(
                state,
                evidence: replacingByID(
                    state.evidence,
                    with: record,
                    id: \.id
                )
            )
        case let .productIssueObserved(issue):
            let issues = (
                state.productIssues + [issue]
            ).reduce(into: [QuickScanProductIssue]()) { result, candidate in
                guard !result.contains(candidate) else {
                    return
                }
                result.append(candidate)
            }
            return replacing(state, productIssues: issues)
        case let .ledgerUpdated(ledger):
            return replacing(state, ledger: ledger)
        case let .terminal(projection):
            return terminal(projection, state: state)
        }
    }

    private func stageChanged(
        _ stage: QuickScanStage,
        state: ScanFlowState
    ) -> ScanFlowState {
        let stages = QuickScanStage.allCases
        guard let nextIndex = stages.firstIndex(of: stage) else {
            return state
        }
        let currentIndex = state.currentStage.flatMap {
            stages.firstIndex(of: $0)
        }
        let expectedIndex = currentIndex.map { $0 + 1 } ?? 0
        guard nextIndex == expectedIndex else {
            return state
        }
        return replacing(
            state,
            stageStates: stages.enumerated().map { index, item in
                ScanStageState(
                    stage: item,
                    status: index < nextIndex
                        ? .complete
                        : index == nextIndex ? .current : .pending
                )
            },
            currentStage: stage
        )
    }

    private func progressChanged(
        _ progress: QuickScanProgress,
        state: ScanFlowState
    ) -> ScanFlowState {
        let measured = ByteCount(
            exactly: progress.counters.allocatedFileBytes
        ) ?? state.measuredBytes
        return replacing(
            state,
            currentScopeID: progress.scopeID,
            currentRelativePath: progress.currentRelativePath,
            scopeScanned: max(
                state.scopeScanned,
                progress.counters.completedEntries
            ),
            measuredBytes: max(state.measuredBytes, measured)
        )
    }

    private func terminal(
        _ projection: QuickScanProjection,
        state: ScanFlowState
    ) -> ScanFlowState {
        let phase = ScanFlowState.terminalPhase(for: projection)
        return replacing(
            state,
            phase: phase,
            stageStates: phase == .completed
                ? ScanFlowState.completeStages
                : incompleteCurrentStage(state.stageStates),
            currentStage: .some(nil),
            scopeScanned: max(
                state.scopeScanned,
                projection.snapshotCount
            ),
            candidatesFound: projection.candidateCount,
            measuredBytes: ScanFlowState.measuredBytes(in: projection),
            snapshots: projection.snapshots,
            classifications: projection.classifications,
            evidence: projection.evidence,
            ledger: projection.ledger,
            projection: projection,
            productIssues: projection.issues,
            reasonKey: nil
        )
    }

    private func replacing(
        _ state: ScanFlowState,
        phase: ScanFlowPhase? = nil,
        stageStates: [ScanStageState]? = nil,
        currentStage: QuickScanStage?? = nil,
        currentScopeID: ScanScopeID?? = nil,
        currentRelativePath: PersistedPath?? = nil,
        scopeScanned: Int? = nil,
        candidatesFound: Int? = nil,
        measuredBytes: ByteCount? = nil,
        elapsed: TimeInterval? = nil,
        rootPath: PersistedPath?? = nil,
        stopWasRequested: Bool? = nil,
        snapshots: [PathSnapshot]? = nil,
        classifications: [Classification]? = nil,
        evidence: [EvidenceRecord]? = nil,
        ledger: SpaceLedger?? = nil,
        projection: QuickScanProjection?? = nil,
        productIssues: [QuickScanProductIssue]? = nil,
        reasonKey: DomainToken?? = nil
    ) -> ScanFlowState {
        ScanFlowState(
            phase: phase ?? state.phase,
            stageStates: stageStates ?? state.stageStates,
            currentStage: currentStage ?? state.currentStage,
            currentScopeID: currentScopeID ?? state.currentScopeID,
            currentRelativePath:
                currentRelativePath ?? state.currentRelativePath,
            scopeScanned: scopeScanned ?? state.scopeScanned,
            candidatesFound: candidatesFound ?? state.candidatesFound,
            measuredBytes: measuredBytes ?? state.measuredBytes,
            elapsed: elapsed ?? state.elapsed,
            startedAt: state.startedAt,
            rootPath: rootPath ?? state.rootPath,
            stopWasRequested:
                stopWasRequested ?? state.stopWasRequested,
            snapshots: snapshots ?? state.snapshots,
            classifications: classifications ?? state.classifications,
            evidence: evidence ?? state.evidence,
            ledger: ledger ?? state.ledger,
            projection: projection ?? state.projection,
            productIssues: productIssues ?? state.productIssues,
            reasonKey: reasonKey ?? state.reasonKey
        )
    }
}

private struct ScanHardLinkIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

private extension FileIdentity {
    var isHardLinkCandidate: Bool {
        isRegularFile
    }
}

private func incompleteCurrentStage(
    _ stages: [ScanStageState]
) -> [ScanStageState] {
    stages.map {
        ScanStageState(
            stage: $0.stage,
            status: $0.status == .current ? .incomplete : $0.status
        )
    }
}

private func replacingByID<Element, ID: Equatable>(
    _ elements: [Element],
    with element: Element,
    id: KeyPath<Element, ID>
) -> [Element] {
    var result = elements
    let elementID = element[keyPath: id]
    if let index = result.firstIndex(
        where: { $0[keyPath: id] == elementID }
    ) {
        result[index] = element
    } else {
        result.append(element)
    }
    return result
}

private func candidateCount(
    classifications: [Classification],
    snapshots: [PathSnapshot]
) -> Int {
    let visibleSnapshotIDs = Set(
        snapshots.compactMap {
            $0.relativePath == "." ? nil : $0.id
        }
    )
    return Set(
        classifications.compactMap {
            visibleSnapshotIDs.contains($0.snapshotID)
                ? $0.snapshotID
                : nil
        }
    ).count
}

private func hasPermissionGap(
    _ projection: QuickScanProjection
) -> Bool {
    projection.session.unfinishedScopes.contains {
        $0.reason == .permissionDenied
    } || projection.ledger?.coverageGaps.contains {
        $0.status == .permissionDenied
    } == true
}
