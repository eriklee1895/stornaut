import AppKit
import Darwin
import Foundation

public struct RunningApplicationRecord: Sendable, Equatable {
    public let bundleIdentifier: DomainToken
    public let localizedName: DomainLabel?
    public let processIdentifier: Int32

    public init(
        bundleIdentifier: DomainToken,
        localizedName: DomainLabel?,
        processIdentifier: Int32
    ) throws {
        guard processIdentifier > 0 else {
            throw DomainContractError.invalidMeasurement
        }
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.processIdentifier = processIdentifier
    }
}

public struct RunningProcessRecord: Sendable, Equatable {
    public let name: DomainLabel
    public let processIdentifier: Int32

    public init(
        name: DomainLabel,
        processIdentifier: Int32
    ) throws {
        guard processIdentifier > 0 else {
            throw DomainContractError.invalidMeasurement
        }
        self.name = name
        self.processIdentifier = processIdentifier
    }
}

public struct RunningActivitySnapshot: Sendable, Equatable {
    public let applications: [RunningApplicationRecord]
    public let processes: [RunningProcessRecord]
    public let processStatus: ActivityProviderStatus
    public let observedAt: Date

    public init(
        applications: [RunningApplicationRecord],
        processes: [RunningProcessRecord],
        processStatus: ActivityProviderStatus = .available,
        observedAt: Date
    ) {
        self.applications = applications
        self.processes = processes
        self.processStatus = processStatus
        self.observedAt = observedAt
    }
}

public protocol RunningActivitySnapshotting: Sendable {
    func snapshot() async throws -> RunningActivitySnapshot
}

public typealias RunningActivityProviderFailure = ActivityProviderFailure

public actor NativeRunningActivitySource: RunningActivitySnapshotting {
    private static let maximumApplications = 4_096
    private static let maximumProcesses = 16_384

    public init() {}

    public func snapshot() async throws -> RunningActivitySnapshot {
        let runningApplications = NSWorkspace.shared.runningApplications
        guard runningApplications.count <= Self.maximumApplications else {
            throw ActivityProviderFailure.outputLimitExceeded
        }
        let applications: [RunningApplicationRecord] = runningApplications
            .compactMap { application in
            guard application.processIdentifier > 0,
                  let rawIdentifier = application.bundleIdentifier,
                  let bundleIdentifier = DomainToken(rawValue: rawIdentifier)
            else {
                return nil
            }
            return try? RunningApplicationRecord(
                bundleIdentifier: bundleIdentifier,
                localizedName: application.localizedName.flatMap(
                    DomainLabel.init(rawValue:)
                ),
                processIdentifier: application.processIdentifier
            )
            }
        let processSnapshot = nativeProcessSnapshot(
            limit: Self.maximumProcesses
        )
        return RunningActivitySnapshot(
            applications: applications,
            processes: processSnapshot.records,
            processStatus: processSnapshot.status,
            observedAt: Date()
        )
    }
}

public struct RelatedProcessQuery: Sendable, Equatable {
    public let bundleIdentifiers: [DomainToken]
    public let processNames: [DomainLabel]

    public init(
        bundleIdentifiers: [DomainToken],
        processNames: [DomainLabel]
    ) throws {
        guard bundleIdentifiers.count <= 64,
              processNames.count <= 64,
              Set(bundleIdentifiers).count == bundleIdentifiers.count,
              Set(processNames).count == processNames.count,
              !bundleIdentifiers.isEmpty || !processNames.isEmpty
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.bundleIdentifiers = bundleIdentifiers.sorted {
            $0.rawValue < $1.rawValue
        }
        self.processNames = processNames.sorted {
            $0.rawValue < $1.rawValue
        }
    }
}

public struct RunningActivityResult: Sendable, Equatable {
    public let status: ActivityProviderStatus
    public let observation: ActivityObservation
    public let matchedBundleIdentifiers: [DomainToken]
    public let matchedProcessNames: [DomainLabel]
}

public struct RunningActivityContext: Sendable, Equatable {
    let snapshot: RunningActivitySnapshot?
    let failure: ActivityProviderFailure?
    public let observedAt: Date

    init(
        snapshot: RunningActivitySnapshot?,
        failure: ActivityProviderFailure?,
        observedAt: Date
    ) {
        self.snapshot = snapshot
        self.failure = failure
        self.observedAt = observedAt
    }
}

public struct RunningActivityProvider: Sendable {
    private let source: any RunningActivitySnapshotting

    public init(source: any RunningActivitySnapshotting) {
        self.source = source
    }

    public init() {
        source = NativeRunningActivitySource()
    }

    public func collect(
        query: RelatedProcessQuery,
        observedAt: Date
    ) async -> RunningActivityResult {
        let context = await capture(observedAt: observedAt)
        return evaluate(query: query, context: context)
    }

    public func capture(
        observedAt: Date
    ) async -> RunningActivityContext {
        let fallbackDate = safeActivityObservationDate(observedAt)
        do {
            let snapshot = try await source.snapshot()
            guard snapshot.applications.count <= 4_096,
                  snapshot.processes.count <= 16_384,
                  isValidActivityDate(snapshot.observedAt)
            else {
                throw ActivityProviderFailure.outputLimitExceeded
            }
            return RunningActivityContext(
                snapshot: snapshot,
                failure: nil,
                observedAt: snapshot.observedAt
            )
        } catch {
            let failure = error as? ActivityProviderFailure
                ?? .launchFailed
            return RunningActivityContext(
                snapshot: nil,
                failure: failure,
                observedAt: fallbackDate
            )
        }
    }

    public func evaluate(
        query: RelatedProcessQuery,
        context: RunningActivityContext
    ) -> RunningActivityResult {
        guard let snapshot = context.snapshot else {
            return unavailableRunningActivityResult(
                failure: context.failure ?? .launchFailed,
                source: query.processNames.isEmpty
                    ? .runningApplication
                    : .runningProcess,
                observedAt: context.observedAt
            )
        }
        let requestedBundles = Set(query.bundleIdentifiers)
        let requestedProcesses = Set(query.processNames)
        let matchedBundles = Array(Set(snapshot.applications.compactMap {
            requestedBundles.contains($0.bundleIdentifier)
                ? $0.bundleIdentifier
                : nil
        })).sorted { $0.rawValue < $1.rawValue }
        let matchedProcesses = Array(Set(snapshot.processes.compactMap {
            requestedProcesses.contains($0.name) ? $0.name : nil
        })).sorted { $0.rawValue < $1.rawValue }
        return activityResult(
            snapshot: snapshot,
            matchedBundles: matchedBundles,
            matchedProcesses: matchedProcesses,
            hasProcessSubjects: !query.processNames.isEmpty
        )
    }

    public func evaluate(
        subjects: ExecutionProcessSubjects,
        context: RunningActivityContext
    ) -> RunningActivityResult {
        guard let snapshot = context.snapshot else {
            return unavailableRunningActivityResult(
                failure: context.failure ?? .launchFailed,
                source: .runningProcess,
                observedAt: context.observedAt
            )
        }
        let requestedBundles = Set(subjects.bundleIdentifiers)
        let matchedBundles = Array(Set(snapshot.applications.compactMap {
            requestedBundles.contains($0.bundleIdentifier)
                ? $0.bundleIdentifier
                : nil
        })).sorted { $0.rawValue < $1.rawValue }
        let matchedProcesses = Array(Set(snapshot.processes.compactMap {
            subjects.matches(processName: $0.name.rawValue)
                ? $0.name
                : nil
        })).sorted { $0.rawValue < $1.rawValue }
        return activityResult(
            snapshot: snapshot,
            matchedBundles: matchedBundles,
            matchedProcesses: matchedProcesses,
            hasProcessSubjects: true
        )
    }

    private func activityResult(
        snapshot: RunningActivitySnapshot,
        matchedBundles: [DomainToken],
        matchedProcesses: [DomainLabel],
        hasProcessSubjects: Bool
    ) -> RunningActivityResult {
        let active = !matchedBundles.isEmpty || !matchedProcesses.isEmpty
        if !active,
           hasProcessSubjects,
           snapshot.processStatus != .available
        {
            return unavailableRunningActivityResult(
                failure: snapshot.processStatus.failure
                    ?? .permissionDenied,
                source: .runningProcess,
                observedAt: snapshot.observedAt
            )
        }
        let source: ActivityEvidenceSource = hasProcessSubjects
            ? .runningProcess
            : .runningApplication
        return RunningActivityResult(
            status: .available,
            observation: try! ActivityObservation(
                key: .processInactive,
                state: active ? .contradicted : .satisfied,
                source: source,
                origin: .external,
                observedAt: snapshot.observedAt,
                reason: DomainToken(
                    rawValue: active
                        ? "activity.process.related-running"
                        : "activity.process.inactive"
                )!
            ),
            matchedBundleIdentifiers: matchedBundles,
            matchedProcessNames: matchedProcesses
        )
    }
}

private struct NativeProcessSnapshot {
    let records: [RunningProcessRecord]
    let status: ActivityProviderStatus
}

private func nativeProcessSnapshot(
    limit: Int
) -> NativeProcessSnapshot {
    let requiredBytes = proc_listpids(
        UInt32(PROC_UID_ONLY),
        UInt32(getuid()),
        nil,
        0
    )
    guard requiredBytes >= 0 else {
        return NativeProcessSnapshot(
            records: [],
            status: .unavailable(.permissionDenied)
        )
    }
    let stride = MemoryLayout<pid_t>.stride
    let requiredCount = Int(requiredBytes) / stride
    guard requiredCount <= limit else {
        return NativeProcessSnapshot(
            records: [],
            status: .unavailable(.outputLimitExceeded)
        )
    }
    let capacity = min(limit, max(1, requiredCount + 256))
    var identifiers = [pid_t](
        repeating: 0,
        count: capacity
    )
    let bytes = identifiers.count * MemoryLayout<pid_t>.stride
    let result = identifiers.withUnsafeMutableBytes { buffer in
        proc_listpids(
            UInt32(PROC_UID_ONLY),
            UInt32(getuid()),
            buffer.baseAddress,
            Int32(bytes)
        )
    }
    guard result >= 0 else {
        return NativeProcessSnapshot(
            records: [],
            status: .unavailable(.permissionDenied)
        )
    }
    guard Int(result) < bytes else {
        return NativeProcessSnapshot(
            records: [],
            status: .unavailable(.outputLimitExceeded)
        )
    }

    var records: [RunningProcessRecord] = []
    let resultCount = min(Int(result) / stride, identifiers.count)
    records.reserveCapacity(resultCount)
    var incomplete = false
    for identifier in identifiers.prefix(resultCount) where identifier > 0 {
        var name = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(
            identifier,
            &name,
            UInt32(name.count)
        )
        guard length > 0 else {
            if kill(identifier, 0) == 0 || errno == EPERM {
                incomplete = true
            }
            continue
        }
        let value = String(
            decoding: name.prefix(Int(length)).map(UInt8.init(bitPattern:)),
            as: UTF8.self
        )
        guard let label = DomainLabel(rawValue: value),
              let record = try? RunningProcessRecord(
                  name: label,
                  processIdentifier: identifier
              )
        else {
            incomplete = true
            continue
        }
        records.append(record)
    }
    return NativeProcessSnapshot(
        records: records,
        status: incomplete
            ? .unavailable(.permissionDenied)
            : .available
    )
}

private func unavailableRunningActivityResult(
    failure: ActivityProviderFailure,
    source: ActivityEvidenceSource,
    observedAt: Date
) -> RunningActivityResult {
    let evidenceDate = safeActivityObservationDate(observedAt)
    return RunningActivityResult(
        status: .unavailable(failure),
        observation: try! ActivityObservation(
            key: .processInactive,
            state: .unavailable,
            source: source,
            origin: .external,
            observedAt: evidenceDate,
            reason: DomainToken(
                rawValue: "activity.process.\(failure.rawValue)"
            )!
        ),
        matchedBundleIdentifiers: [],
        matchedProcessNames: []
    )
}

private extension ActivityProviderStatus {
    var failure: ActivityProviderFailure? {
        guard case let .unavailable(failure) = self else {
            return nil
        }
        return failure
    }
}
