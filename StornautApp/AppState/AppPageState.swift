import Foundation
import StornautCore

enum AppPagePhase: String, CaseIterable, Sendable {
    case empty
    case loading
    case partial
    case cancelled
    case success
    case limitedPermission
    case stale
    case error
}

enum SafeRecoveryIntent:
    String,
    CaseIterable,
    Sendable,
    Equatable
{
    case retryLatestSnapshot
    case refreshLatestSnapshot
    case reviewPermissions
}

enum AppStateContractError: Error, Sendable, Equatable {
    case invalidPhase
}

struct AppPageState: Sendable, Equatable {
    let phase: AppPagePhase
    let projection: QuickScanProjection?
    let reasonKey: DomainToken?
    let recoveryIntent: SafeRecoveryIntent?
    let refreshedAt: Date?

    init(
        phase: AppPagePhase,
        projection: QuickScanProjection?,
        reasonKey: DomainToken?,
        recoveryIntent: SafeRecoveryIntent?,
        refreshedAt: Date?
    ) throws {
        guard Self.isValid(
            phase: phase,
            projection: projection,
            reasonKey: reasonKey,
            recoveryIntent: recoveryIntent,
            refreshedAt: refreshedAt
        ) else {
            throw AppStateContractError.invalidPhase
        }
        self.phase = phase
        self.projection = projection
        self.reasonKey = reasonKey
        self.recoveryIntent = recoveryIntent
        self.refreshedAt = refreshedAt
    }

    static let empty = try! AppPageState(
        phase: .empty,
        projection: nil,
        reasonKey: nil,
        recoveryIntent: nil,
        refreshedAt: nil
    )

    static func success(
        projection: QuickScanProjection,
        refreshedAt: Date
    ) throws -> AppPageState {
        try AppPageState(
            phase: .success,
            projection: projection,
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: refreshedAt
        )
    }

    private static func isValid(
        phase: AppPagePhase,
        projection: QuickScanProjection?,
        reasonKey: DomainToken?,
        recoveryIntent: SafeRecoveryIntent?,
        refreshedAt: Date?
    ) -> Bool {
        switch phase {
        case .empty:
            projection == nil
                && reasonKey == nil
                && recoveryIntent == nil
                && refreshedAt == nil
        case .loading:
            reasonKey == nil
                && recoveryIntent == nil
                && (projection == nil || refreshedAt != nil)
        case .success:
            projection?.session.terminalState == .completed
                && reasonKey == nil
                && recoveryIntent == nil
                && refreshedAt != nil
        case .partial:
            projection?.session.terminalState == .partial
                && !hasPermissionGap(projection)
                && reasonKey != nil
                && recoveryIntent == .retryLatestSnapshot
                && refreshedAt != nil
        case .cancelled:
            projection?.session.terminalState == .cancelled
                && reasonKey != nil
                && recoveryIntent == .retryLatestSnapshot
                && refreshedAt != nil
        case .limitedPermission:
            projection?.session.terminalState == .partial
                && hasPermissionGap(projection)
                && reasonKey != nil
                && recoveryIntent == .reviewPermissions
                && refreshedAt != nil
        case .stale:
            projection != nil
                && reasonKey != nil
                && recoveryIntent == .refreshLatestSnapshot
                && refreshedAt != nil
        case .error:
            reasonKey != nil
                && recoveryIntent == .retryLatestSnapshot
                && refreshedAt != nil
        }
    }
}

struct AppPageReducer: Sendable {
    func beginRefresh(previous: AppPageState) -> AppPageState {
        try! AppPageState(
            phase: .loading,
            projection: previous.projection,
            reasonKey: nil,
            recoveryIntent: nil,
            refreshedAt: previous.refreshedAt
        )
    }

    func loaded(
        _ projection: QuickScanProjection?,
        previous: AppPageState,
        now: Date
    ) -> AppPageState {
        guard let projection else {
            return .empty
        }
        let phase: AppPagePhase
        let reasonKey: DomainToken?
        let recoveryIntent: SafeRecoveryIntent?
        switch projection.session.terminalState {
        case .completed:
            phase = .success
            reasonKey = nil
            recoveryIntent = nil
        case .partial where hasPermissionGap(projection):
            phase = .limitedPermission
            reasonKey = token("app.state.permission-limited")
            recoveryIntent = .reviewPermissions
        case .partial:
            phase = .partial
            reasonKey = token("app.state.partial")
            recoveryIntent = .retryLatestSnapshot
        case .cancelled:
            phase = .cancelled
            reasonKey = token("app.state.cancelled")
            recoveryIntent = .retryLatestSnapshot
        case .failed:
            phase = .error
            reasonKey = token("app.state.scan-failed")
            recoveryIntent = .retryLatestSnapshot
        }
        return try! AppPageState(
            phase: phase,
            projection: projection,
            reasonKey: reasonKey,
            recoveryIntent: recoveryIntent,
            refreshedAt: now
        )
    }

    func failed(
        reasonKey: DomainToken,
        previous: AppPageState,
        now: Date
    ) -> AppPageState {
        try! AppPageState(
            phase: .error,
            projection: previous.projection,
            reasonKey: reasonKey,
            recoveryIntent: .retryLatestSnapshot,
            refreshedAt: previous.refreshedAt ?? now
        )
    }

    func markStale(
        previous: AppPageState,
        reasonKey: DomainToken,
        now: Date
    ) -> AppPageState {
        guard previous.projection != nil else {
            return previous
        }
        return try! AppPageState(
            phase: .stale,
            projection: previous.projection,
            reasonKey: reasonKey,
            recoveryIntent: .refreshLatestSnapshot,
            refreshedAt: previous.refreshedAt ?? now
        )
    }
}

private func hasPermissionGap(
    _ projection: QuickScanProjection?
) -> Bool {
    guard let projection else {
        return false
    }
    return projection.session.unfinishedScopes.contains {
        $0.reason == .permissionDenied
    } || projection.ledger?.coverageGaps.contains {
        $0.status == .permissionDenied
    } == true
}

private func token(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}
