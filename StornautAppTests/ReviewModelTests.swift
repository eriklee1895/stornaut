import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func reviewModelKeepsFiveGroupsIndependentAndSelectionSemantic() throws {
    let fixture = try ReviewAppFixture()
    var snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    snapshot = snapshot.focusing(fixture.reviewRow.classificationID)
    let model = ReviewModel(
        state: .ready(snapshot),
        pageProjection: nil
    )

    #expect(model.groups.map(\.kind) == ReviewGroupKind.allCases)
    #expect(model.groups[0].rows.map(\.classificationID) == [
        fixture.readyRow.classificationID,
    ])
    #expect(model.groups[1].rows.map(\.classificationID) == [
        fixture.reviewRow.classificationID,
        fixture.noProfileRow.classificationID,
    ])
    #expect(model.groups[2].rows.map(\.classificationID) == [
        fixture.protectedRow.classificationID,
    ])
    #expect(model.groups[3].rows.map(\.classificationID) == [
        fixture.unknownRow.classificationID,
    ])
    #expect(model.groups[4].rows.isEmpty)

    let ready = try #require(
        model.rows.first {
            $0.classificationID == fixture.readyRow.classificationID
        }
    )
    let review = try #require(
        model.rows.first {
            $0.classificationID == fixture.reviewRow.classificationID
        }
    )
    let noProfile = try #require(
        model.rows.first {
            $0.classificationID == fixture.noProfileRow.classificationID
        }
    )
    let protected = try #require(
        model.rows.first {
            $0.classificationID
                == fixture.protectedRow.classificationID
        }
    )

    #expect(ready.isSelected)
    #expect(ready.isSelectionEnabled)
    #expect(!review.isSelected)
    #expect(review.isFocused)
    #expect(review.isSelectionEnabled)
    #expect(!noProfile.isSelectionEnabled)
    #expect(noProfile.disabledReasonKey
        == "review.disabled.noExecutionProfile")
    #expect(!protected.isSelectionEnabled)
    #expect(protected.disabledReasonKey == "review.disabled.protected")
}

@Test
func reviewModelKeepsTrashAndPermanentAccountingSeparate() throws {
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    )
    let model = ReviewModel(
        state: .ready(snapshot),
        pageProjection: nil
    )

    #expect(model.summary.selectedCount == 1)
    #expect(
        model.summary.estimatedTrashBytes
            == fixture.readyItem.allocatedBytes
    )
    #expect(model.summary.permanentReleaseBytes == ByteCount(0))
    #expect(model.summary.selectedRegisteredActionCount == 0)
    #expect(model.primaryAction == .preflight)
    #expect(model.primaryActionTitleKey
        == "review.action.moveItemsToTrash")
}

@Test
func reviewModelDisablesSelectionOutsideReadyPhase() throws {
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .debugFake
    )
    let model = ReviewModel(
        state: .preflighting(snapshot),
        pageProjection: nil
    )

    #expect(model.rows.allSatisfy { !$0.isSelectionEnabled })
}

@Test
func reviewInspectorIsReadOnlyAndFocusDoesNotImplySelection() throws {
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    ).focusing(fixture.reviewRow.classificationID)
    let model = ReviewModel(
        state: .ready(snapshot),
        pageProjection: nil
    )
    let inspector = try #require(model.inspector)

    #expect(inspector.classificationID
        == fixture.reviewRow.classificationID)
    #expect(!inspector.isSelected)
    #expect(inspector.availableActions == [.close])
    #expect(!inspector.hasExecutionAction)
    #expect(inspector.reasonKeys == fixture.reviewRow.reasonKeys)
}

@Test
func reviewConfirmationAndStaleModelsExposeOnlyApprovedActions() throws {
    let fixture = try ReviewAppFixture()
    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    )
    let selection = try #require(snapshot.reviewSelection)
    let evaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let confirmation = try #require(evaluation.allowed?.confirmation)
    let confirmationModel = try ReviewConfirmationModel(
        snapshot: snapshot,
        confirmation: confirmation
    )

    #expect(confirmationModel.itemCount == snapshot.selectedCount)
    #expect(confirmationModel.action == .moveToTrash)
    #expect(
        confirmationModel.estimatedTrashBytes
            == snapshot.selectedAllocatedBytes
    )
    #expect(confirmationModel.permanentReleaseBytes == ByteCount(0))
    #expect(confirmationModel.availableActions == [.cancel])
    #expect(!confirmationModel.canConfirmExecution)

    let blocked = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .active
    )
    let stale = try #require(blocked.blocked?.stale)
    let staleModel = ReviewStaleModel(
        snapshot: snapshot,
        stale: stale
    )
    #expect(staleModel.availableActions == [
        .refreshAffectedItems,
        .cancel,
    ])
    #expect(!staleModel.hasProceedAnyway)
}

@Test
func reviewLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))

    for language in ["en", "zh-Hans"] {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))
        for key in ReviewLocalizationKeys.all {
            #expect(
                localized.localizedString(
                    forKey: key,
                    value: nil,
                    table: nil
                ) != key
            )
        }
    }
}

private enum ReviewLocalizationKeys {
    static let all = [
        "review.title",
        "review.subtitle",
        "review.group.ready",
        "review.group.ready.help",
        "review.group.review",
        "review.group.review.help",
        "review.group.protected",
        "review.group.protected.help",
        "review.group.unknown",
        "review.group.unknown.help",
        "review.group.registeredActions",
        "review.group.registeredActions.help",
        "review.column.item",
        "review.column.lastActive",
        "review.column.recovery",
        "review.column.action",
        "review.column.size",
        "review.action.moveItemsToTrash",
        "review.action.backToResults",
        "review.action.refreshAffected",
        "review.action.cancel",
        "review.action.stopAfterCurrent",
        "review.inspector.title",
        "review.inspector.missing.activity.process.inactive",
        "review.inspector.missing.activity.git.clean",
        "review.inspector.missing.activity.git.upstream-synced",
        "review.inspector.missing.unknown",
        "review.inspector.supporting.activity.process.inactive",
        "review.inspector.supporting.activity.process.related-running",
        "review.inspector.supporting.activity.git.clean",
        "review.inspector.supporting.activity.git.changed",
        "review.inspector.supporting.activity.git.upstream-synced",
        "review.inspector.supporting.activity.git.upstream-not-synced",
        "review.inspector.supporting.activity.provider-failure",
        "review.inspector.supporting.unknown",
        "review.confirmation.title",
        "review.stale.title",
        "review.execution.writeDisabled",
        "review.scan-again.corrupt-truth",
        "review.scan-again.catalog-changed",
        "review.scan-again.incomplete-scan",
        "review.scan-again.evidence-expired",
        "review.scan-again.root-changed",
        "review.scan-again.count-mismatch",
        "review.scan-again.duplicate-truth",
        "review.unavailable.cancelled",
        "review.unavailable.persisted-truth",
        "review.unavailable.root",
        "review.unavailable.no-snapshot",
        "review.unavailable.service",
        "review.unavailable.selection-conflict",
        "review.unavailable.invalid-projection",
        "review.unavailable.invalid-confirmation",
        "review.unavailable.preflight",
        "review.unavailable.fixture-not-selected",
        "review.current.pending",
        "review.current.scan-evidence-incomplete",
        "review.current.evidence-blocked",
    ]
}
