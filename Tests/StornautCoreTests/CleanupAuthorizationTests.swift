import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupAuthorizationAdmitsExactlyOnceWithinDeadline() async throws {
    let fixture = try CleanupAuthorizationTestFixture()
    let clock = AuthorizationTestClock(fixture.now)
    let controller = CleanupAuthorizationController(now: clock.now)
    let authorization = try await controller.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )

    clock.set(fixture.now.addingTimeInterval(30))
    let admission = try await controller.admit(
        authorization,
        confirmation: fixture.confirmation,
        workflow: .available
    )

    #expect(admission.planID == fixture.plan.id)
    #expect(admission.selectionGeneration == fixture.selection.generation)
    #expect(admission.orderedItemIDs == fixture.plan.items.map(\.id))
    #expect(admission.decisionFingerprint
        == fixture.confirmation.decisionFingerprint)
    #expect(admission.rootURL == fixture.collectedContext.rootURL)
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await controller.admit(
            authorization,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }
}

@Test
func cleanupAuthorizationConsumesExpiredAndMismatchedAttempts() async throws {
    let fixture = try CleanupAuthorizationTestFixture()
    let expiredClock = AuthorizationTestClock(fixture.now)
    let expiredController = CleanupAuthorizationController(
        now: expiredClock.now
    )
    let expired = try await expiredController.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )

    expiredClock.set(fixture.now.addingTimeInterval(30.001))
    await #expect(throws: CleanupAuthorizationError.expired) {
        _ = try await expiredController.admit(
            expired,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await expiredController.admit(
            expired,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }

    let mismatchController = CleanupAuthorizationController(
        now: AuthorizationTestClock(fixture.now).now
    )
    let mismatched = try await mismatchController.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )
    let wrongConfirmation = fixture.confirmation.with(
        selectionGeneration: fixture.selection.generation + 1
    )
    await #expect(throws: CleanupAuthorizationError.confirmationMismatch) {
        _ = try await mismatchController.admit(
            mismatched,
            confirmation: wrongConfirmation,
            workflow: .available
        )
    }
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await mismatchController.admit(
            mismatched,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }
}

@Test
func cleanupAuthorizationConsumesWorkflowConflictAndSupportsInvalidation()
    async throws
{
    let fixture = try CleanupAuthorizationTestFixture()
    let conflictController = CleanupAuthorizationController(
        now: AuthorizationTestClock(fixture.now).now
    )
    let conflicted = try await conflictController.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )

    await #expect(throws: CleanupAuthorizationError.workflowConflict) {
        _ = try await conflictController.admit(
            conflicted,
            confirmation: fixture.confirmation,
            workflow: CleanupWorkflowAvailabilitySnapshot(
                rootLeaseAvailable: true,
                activeConflicts: [.settingsMutation]
            )
        )
    }
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await conflictController.admit(
            conflicted,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }

    let invalidationController = CleanupAuthorizationController(
        now: AuthorizationTestClock(fixture.now).now
    )
    let invalidated = try await invalidationController.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )
    await invalidationController.invalidateAll()
    await #expect(throws: CleanupAuthorizationError.invalidated) {
        _ = try await invalidationController.admit(
            invalidated,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }
}

@Test
func cleanupAuthorizationConcurrentAdmissionHasOneWinner() async throws {
    let fixture = try CleanupAuthorizationTestFixture()
    let controller = CleanupAuthorizationController(
        now: AuthorizationTestClock(fixture.now).now
    )
    let authorization = try await controller.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )

    let outcomes = await withTaskGroup(
        of: Bool.self,
        returning: [Bool].self
    ) { group in
        for _ in 0..<16 {
            group.addTask {
                do {
                    _ = try await controller.admit(
                        authorization,
                        confirmation: fixture.confirmation,
                        workflow: .available
                    )
                    return true
                } catch {
                    return false
                }
            }
        }
        var values: [Bool] = []
        for await value in group {
            values.append(value)
        }
        return values
    }

    #expect(outcomes.filter { $0 }.count == 1)
}

@Test
func cleanupAuthorizationDoesNotMintParallelCapabilitiesForOneConfirmation()
    async throws
{
    let fixture = try CleanupAuthorizationTestFixture()
    let clock = AuthorizationTestClock(fixture.now)
    let controller = CleanupAuthorizationController(now: clock.now)
    let first = try await controller.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )
    clock.set(fixture.now.addingTimeInterval(1))
    let second = try await controller.issue(
        evaluation: fixture.evaluation,
        confirmation: fixture.confirmation,
        collectedContext: fixture.collectedContext
    )

    _ = try await controller.admit(
        first,
        confirmation: fixture.confirmation,
        workflow: .available
    )
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await controller.admit(
            second,
            confirmation: fixture.confirmation,
            workflow: .available
        )
    }
    await #expect(throws: CleanupAuthorizationError.alreadyConsumed) {
        _ = try await controller.issue(
            evaluation: fixture.evaluation,
            confirmation: fixture.confirmation,
            collectedContext: fixture.collectedContext
        )
    }
}

private final class AuthorizationTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.withLock { value }
    }

    func set(_ value: Date) {
        lock.withLock {
            self.value = value
        }
    }
}

@Test
func cleanupAuthorizationCannotBeEncodedOrReconstructedFromPolicyDecisions()
    throws
{
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = root.appending(
        path: "Sources/StornautCore/Policy/CleanupAuthorization.swift"
    )
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(!source.contains("ExecutionAuthorization: Codable"))
    #expect(!source.contains("ExecutionAuthorization: Equatable"))
    #expect(!source.contains("public init("))
    #expect(!source.contains("PolicyDecision) -> ExecutionAuthorization"))
}

private struct CleanupAuthorizationTestFixture {
    let now = Date(timeIntervalSince1970: 1_786_640_000)
    let plan: CleanupPlan
    let selection: ReviewSelection
    let evaluation: CleanupPolicyEvaluation
    let confirmation: CleanupConfirmation
    let collectedContext: CleanupPolicyCollectedContext

    init() throws {
        let rootIdentity = try CleanupAuthorizationTestFixture.identity(
            inode: 1,
            size: 4_096,
            allocatedBytes: 8_192
        )
        let item = try CleanupAuthorizationTestFixture.item()
        plan = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-authorization")!,
            scanSessionID: ScanSessionID(rawValue: "scan-authorization")!,
            scanScopeID: ScanScopeID(rawValue: "scope-authorization")!,
            primaryRootIdentity: rootIdentity,
            catalogVersion: DomainToken(
                rawValue: "builtin-runtime-tool-residue-v2"
            )!,
            executionProfileVersion: DomainToken(
                rawValue: "safe-execution-v1"
            )!,
            planFingerprint: DomainToken(
                rawValue: "authorization.plan.fingerprint"
            )!,
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            items: [item]
        )
        selection = try ReviewSelection(
            plan: plan,
            generation: 11,
            items: [
                ReviewSelectionItem(
                    itemID: item.id,
                    origin: .defaultReady
                ),
            ],
            dispositions: [item.id: .readyToReclaim]
        )
        let itemContext = try CleanupPolicyItemContext(
            itemID: item.id,
            snapshotID: item.snapshotID,
            classificationID: item.classificationID,
            ruleID: item.ruleID!,
            executionProfileID: item.executionProfileID!,
            proposedAction: item.proposedAction,
            persistedDisposition: .readyToReclaim,
            currentDisposition: .readyToReclaim,
            expectedRelativePath: item.expectedRelativePath!,
            currentRelativePath: item.expectedRelativePath!,
            expectedIdentity: item.expectedIdentity!,
            currentIdentity: item.expectedIdentity!,
            evidenceFingerprint: item.evidenceFingerprint!,
            currentEvidenceFingerprint: item.evidenceFingerprint!,
            activityFingerprint: item.activityFingerprint!,
            currentActivityFingerprint: item.activityFingerprint!,
            pathFacts: .allowed,
            evidenceFacts: .current,
            activityFacts: .inactive
        )
        let context = try CleanupPolicyContext(
            capturedAt: now,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: plan.planFingerprint!,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            rootIdentity: rootIdentity,
            catalogVersion: plan.catalogVersion!,
            executionProfileVersion: plan.executionProfileVersion!,
            workflow: .available,
            items: [itemContext]
        )
        evaluation = try CleanupPolicyGate().evaluate(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: now
        )
        confirmation = try #require(evaluation.allowed?.confirmation)
        collectedContext = CleanupPolicyCollectedContext(
            policyContext: context,
            rootURL: URL(filePath: "/tmp/stornaut-authorization-root"),
            rootAccess: .direct
        )
    }

    private static func item() throws -> CleanupPlanItem {
        let identity = try identity(
            inode: 10,
            size: 10,
            allocatedBytes: 16
        )
        return try CleanupPlanItem(
            id: CleanupPlanItemID(rawValue: "plan-item-authorization")!,
            snapshotID: SnapshotID(rawValue: "snapshot-authorization")!,
            classificationID: ClassificationID(
                rawValue: "classification-authorization"
            )!,
            ruleID: DomainToken(rawValue: "cache-npm-content")!,
            executionProfileID: DomainToken(
                rawValue: "phase-c.npm-cacache-v1"
            )!,
            proposedAction: .moveToTrash,
            expectedRelativePath: PersistedPath(
                rawValue: ".npm/_cacache"
            )!,
            expectedIdentity: identity,
            logicalBytes: ByteCount(10)!,
            allocatedBytes: ByteCount(16)!,
            evidenceFingerprint: DomainToken(
                rawValue: "authorization.evidence.fingerprint"
            )!,
            activityFingerprint: DomainToken(
                rawValue: "authorization.activity.fingerprint"
            )!
        )
    }

    private static func identity(
        inode: UInt64,
        size: Int64,
        allocatedBytes: Int64
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 100,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o700),
            ownerUserID: 501,
            ownerGroupID: 20,
            linkCount: 1,
            size: size,
            allocatedBytes: allocatedBytes,
            modificationSeconds: 1_786_639_900,
            modificationNanoseconds: 123
        )
    }
}
