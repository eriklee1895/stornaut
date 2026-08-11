import Foundation
import StornautCore
import SwiftUI
import Testing

@testable import StornautApp

/// Page-level contracts for Overview.
///
/// Component snapshots prove a badge lays out. These prove the page composes:
/// metric tiles, the orbit, the ledger and the recovery affordances all share
/// one surface, so a spacing or truncation regression usually shows up here
/// first.
@MainActor
@Suite("Overview snapshots", .serialized)
struct OverviewSnapshotTests {
    private static let pageSize = CGSize(width: 900, height: 620)

    @Test(arguments: SnapshotVariant.diagonal)
    func currentSnapshot(variant: SnapshotVariant) throws {
        let projection = try OverviewTestProjectionFactory.projection()
        let state = try AppPageState.success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )

        try verify(
            OverviewModel(pageState: state),
            named: "overview.current",
            variant: variant
        )
    }

    @Test(arguments: SnapshotVariant.diagonal)
    func limitedPermission(variant: SnapshotVariant) throws {
        let projection = try OverviewTestProjectionFactory.projection(
            slug: "overview-limited",
            terminalState: .partial,
            permissionGap: true
        )
        let state = try AppPageState(
            phase: .limitedPermission,
            projection: projection,
            reasonKey: DomainToken(rawValue: "app.state.permission-limited"),
            recoveryIntent: .reviewPermissions,
            refreshedAt: OverviewTestProjectionFactory.now
        )

        try verify(
            OverviewModel(pageState: state),
            named: "overview.limited-permission",
            variant: variant
        )
    }

    @Test(arguments: SnapshotVariant.diagonal)
    func retainedError(variant: SnapshotVariant) throws {
        let projection = try OverviewTestProjectionFactory.projection()
        let success = try AppPageState.success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
        let state = AppPageReducer().failed(
            reasonKey: DomainToken(rawValue: "app.state.store-unavailable")!,
            previous: success,
            now: OverviewTestProjectionFactory.now
        )

        try verify(
            OverviewModel(pageState: state),
            named: "overview.retained-error",
            variant: variant
        )
    }

    @Test(arguments: SnapshotVariant.diagonal)
    func empty(variant: SnapshotVariant) throws {
        try verify(
            OverviewModel(pageState: .empty),
            named: "overview.empty",
            variant: variant
        )
    }

    private func verify(
        _ model: OverviewModel,
        named name: String,
        variant: SnapshotVariant,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try SnapshotHarness.verify(
            OverviewView(
                model: model,
                openScan: {},
                retryLatestSnapshot: {}
            ),
            named: name,
            size: Self.pageSize,
            variant: variant,
            sourceLocation: sourceLocation
        )
    }
}
