import CryptoKit
import Foundation

public struct ActivityKey:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable,
    Comparable
{
    public let rawValue: String

    public static let gitClean = ActivityKey(
        unchecked: "activity.git.clean"
    )
    public static let gitUpstreamSynchronized = ActivityKey(
        unchecked: "activity.git.upstream-synced"
    )
    public static let processInactive = ActivityKey(
        unchecked: "activity.process.inactive"
    )

    public init?(rawValue: String) {
        guard Self.allowedValues.contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard Self.allowedValues.contains(rawValue) else {
            throw DomainContractError.invalidToken
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            validating: decoder.singleValueContainer().decode(String.self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    private static let allowedValues: Set<String> = [
        gitClean.rawValue,
        gitUpstreamSynchronized.rawValue,
        processInactive.rawValue,
    ]
}

public enum ActivityEvidenceState:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case satisfied
    case contradicted
    case unavailable
}

public enum ActivityEvidenceSource:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case git
    case runningApplication
    case runningProcess
}

public enum ActivityObservationOrigin:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case external
    case stornaut
}

public enum ActivityTimestampSource:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case filesystemModification
    case gitLastCommit
    case spotlightLastUsed
}

public enum ActivityProviderFailure:
    String,
    Error,
    Codable,
    Sendable,
    CaseIterable
{
    case invalidInput
    case launchFailed
    case timedOut
    case permissionDenied
    case nonzeroExit
    case outputTruncated
    case outputLimitExceeded
    case malformedOutput
}

public enum ActivityProviderStatus: Sendable, Equatable {
    case available
    case unavailable(ActivityProviderFailure)
}

public struct ActivityObservation: Codable, Sendable, Equatable {
    public let key: ActivityKey
    public let state: ActivityEvidenceState
    public let source: ActivityEvidenceSource
    public let origin: ActivityObservationOrigin
    public let observedAt: Date
    public let reason: DomainToken

    public init(
        key: ActivityKey,
        state: ActivityEvidenceState,
        source: ActivityEvidenceSource,
        origin: ActivityObservationOrigin,
        observedAt: Date,
        reason: DomainToken
    ) throws {
        guard isValidActivityDate(observedAt),
              Self.source(source, supports: key)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.key = key
        self.state = state
        self.source = source
        self.origin = origin
        self.observedAt = observedAt
        self.reason = reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            key: container.decode(ActivityKey.self, forKey: .key),
            state: container.decode(
                ActivityEvidenceState.self,
                forKey: .state
            ),
            source: container.decode(
                ActivityEvidenceSource.self,
                forKey: .source
            ),
            origin: container.decode(
                ActivityObservationOrigin.self,
                forKey: .origin
            ),
            observedAt: container.decode(Date.self, forKey: .observedAt),
            reason: container.decode(DomainToken.self, forKey: .reason)
        )
    }

    private static func source(
        _ source: ActivityEvidenceSource,
        supports key: ActivityKey
    ) -> Bool {
        switch key {
        case .gitClean, .gitUpstreamSynchronized:
            source == .git
        case .processInactive:
            source == .runningApplication || source == .runningProcess
        default:
            false
        }
    }
}

public struct ActivityTimestampObservation:
    Codable,
    Sendable,
    Equatable
{
    public let source: ActivityTimestampSource
    public let origin: ActivityObservationOrigin
    public let observedAt: Date

    public init(
        source: ActivityTimestampSource,
        origin: ActivityObservationOrigin,
        observedAt: Date
    ) throws {
        guard isValidActivityDate(observedAt) else {
            throw DomainContractError.invalidMeasurement
        }
        self.source = source
        self.origin = origin
        self.observedAt = observedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            source: container.decode(
                ActivityTimestampSource.self,
                forKey: .source
            ),
            origin: container.decode(
                ActivityObservationOrigin.self,
                forKey: .origin
            ),
            observedAt: container.decode(Date.self, forKey: .observedAt)
        )
    }
}

public struct ActivityReductionInput: Sendable, Equatable {
    public let baseDisposition: ReclaimDisposition
    public let baseRisk: RiskLevel
    public let requiredKeys: [ActivityKey]
    public let observations: [ActivityObservation]
    public let timestamps: [ActivityTimestampObservation]
    public let recentActivityCutoff: Date
    let recentActivityCutoffIsValid: Bool

    public init(
        baseDisposition: ReclaimDisposition,
        baseRisk: RiskLevel,
        requiredKeys: [ActivityKey],
        observations: [ActivityObservation],
        timestamps: [ActivityTimestampObservation],
        recentActivityCutoff: Date
    ) {
        self.baseDisposition = baseDisposition
        self.baseRisk = baseRisk
        self.requiredKeys = Array(Set(requiredKeys)).sorted()
        self.observations = observations
        self.timestamps = timestamps
        self.recentActivityCutoff = recentActivityCutoff
        recentActivityCutoffIsValid = isValidActivityDate(
            recentActivityCutoff
        )
    }
}

public struct ActivityReductionResult: Sendable, Equatable {
    public let disposition: ReclaimDisposition
    public let risk: RiskLevel
    public let missingKeys: [ActivityKey]
    public let observations: [ActivityObservation]
    public let timestamps: [ActivityTimestampObservation]
    public let activityFingerprint: DomainToken

    public init(
        disposition: ReclaimDisposition,
        risk: RiskLevel,
        missingKeys: [ActivityKey],
        observations: [ActivityObservation],
        timestamps: [ActivityTimestampObservation],
        activityFingerprint: DomainToken
    ) {
        self.disposition = disposition
        self.risk = risk
        self.missingKeys = missingKeys
        self.observations = observations
        self.timestamps = timestamps
        self.activityFingerprint = activityFingerprint
    }
}

func activityFingerprint(
    observations: [ActivityObservation],
    timestamps: [ActivityTimestampObservation]
) -> DomainToken {
    let observationLines = observations.map {
        [
            $0.key.rawValue,
            $0.state.rawValue,
            $0.source.rawValue,
            $0.origin.rawValue,
            $0.reason.rawValue,
        ].joined(separator: "|")
    }
    let timestampLines = timestamps
        .filter { $0.origin == .external }
        .map {
        [
            $0.source.rawValue,
            $0.origin.rawValue,
            activityMilliseconds($0.observedAt),
        ].joined(separator: "|")
    }
    let payload = (observationLines + timestampLines)
        .sorted()
        .joined(separator: "\n")
    let hash = SHA256.hash(data: Data(payload.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
    return DomainToken(
        rawValue: "activity.\(hash)"
    )!
}

func isValidActivityDate(_ date: Date) -> Bool {
    let value = date.timeIntervalSince1970 * 1_000
    return value.isFinite
        && value > Double(Int64.min)
        && value < Double(Int64.max)
}

func safeActivityObservationDate(_ date: Date) -> Date {
    isValidActivityDate(date)
        ? date
        : Date(timeIntervalSince1970: 0)
}

private func activityMilliseconds(_ date: Date) -> String {
    String(Int64(
        (date.timeIntervalSince1970 * 1_000).rounded(.towardZero)
    ))
}
