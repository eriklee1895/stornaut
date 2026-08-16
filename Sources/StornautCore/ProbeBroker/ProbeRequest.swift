import Foundation

public struct ProbeRequest: Codable, Sendable, Equatable {
    public static let maximumSnippetBytes = 16 * 1_024
    public static let maximumChildLimit = 256

    public let capability: ProbeCapability
    public let targetURL: URL
    public let limit: Int?
    public let byteLimit: Int?

    public init(
        capability: ProbeCapability,
        targetURL: URL,
        limit: Int? = nil,
        byteLimit: Int? = nil
    ) {
        self.capability = capability
        self.targetURL = targetURL
        self.limit = limit
        self.byteLimit = byteLimit
    }
}

public struct ProbeBudgetLimits: Codable, Sendable, Equatable {
    public let maximumCallCount: Int
    public let maximumReadBytes: Int
    public let maximumOutputBytes: Int

    public init(
        maximumCallCount: Int,
        maximumReadBytes: Int,
        maximumOutputBytes: Int
    ) {
        self.maximumCallCount = maximumCallCount
        self.maximumReadBytes = maximumReadBytes
        self.maximumOutputBytes = maximumOutputBytes
    }

    public static let generousForTesting = ProbeBudgetLimits(
        maximumCallCount: 1_000,
        maximumReadBytes: 64 * 1_024 * 1_024,
        maximumOutputBytes: 64 * 1_024 * 1_024
    )
}

public struct ProbeBudgetUsage: Sendable, Equatable {
    public let callCount: Int
    public let readBytes: Int
    public let outputBytes: Int

    public init(
        callCount: Int,
        readBytes: Int,
        outputBytes: Int
    ) {
        self.callCount = callCount
        self.readBytes = readBytes
        self.outputBytes = outputBytes
    }
}

public actor ProbeSessionBudget {
    private let limits: ProbeBudgetLimits
    private var callCount = 0
    private var readBytes = 0
    private var outputBytes = 0

    public init(limits: ProbeBudgetLimits) {
        self.limits = limits
    }

    public var usage: ProbeBudgetUsage {
        ProbeBudgetUsage(
            callCount: callCount,
            readBytes: readBytes,
            outputBytes: outputBytes
        )
    }

    func reserveCall() -> Bool {
        guard callCount < limits.maximumCallCount else {
            return false
        }
        callCount += 1
        return true
    }

    func reserveReadBytes(_ count: Int) -> Bool {
        guard count >= 0,
              count <= limits.maximumReadBytes - readBytes
        else {
            return false
        }
        readBytes += count
        return true
    }

    func reserveOutputBytes(_ count: Int) -> Bool {
        guard count >= 0,
              count <= limits.maximumOutputBytes - outputBytes
        else {
            return false
        }
        outputBytes += count
        return true
    }
}

public enum ProbeAuditTarget: String, Codable, Sendable, Equatable {
    case redacted
}

public enum ProbeAuditOutcome: String, Codable, Sendable, Equatable {
    case success
    case denied
    case failed
    case cancelled
    case timedOut
}

public struct ProbeAuditRecord: Codable, Sendable, Equatable {
    public let capability: ProbeCapability
    public let target: ProbeAuditTarget
    public let outcome: ProbeAuditOutcome
    public let readBytes: Int
    public let outputBytes: Int

    public init(
        capability: ProbeCapability,
        target: ProbeAuditTarget = .redacted,
        outcome: ProbeAuditOutcome,
        readBytes: Int,
        outputBytes: Int
    ) {
        self.capability = capability
        self.target = target
        self.outcome = outcome
        self.readBytes = readBytes
        self.outputBytes = outputBytes
    }
}

public actor ProbeAuditRecorder {
    private var storedRecords: [ProbeAuditRecord] = []

    public init() {}

    public var records: [ProbeAuditRecord] {
        storedRecords
    }

    func append(_ record: ProbeAuditRecord) {
        storedRecords.append(record)
    }
}

public struct ProbeContext: Sendable {
    public let allowedRoots: [URL]
    public let maximumReadLevel: ProbeReadLevel
    public let perCallTimeout: Duration
    public let perCallOutputByteLimit: Int
    public let session: ProbeSessionBudget
    public let auditRecorder: ProbeAuditRecorder

    public init(
        allowedRoots: [URL],
        maximumReadLevel: ProbeReadLevel,
        perCallTimeout: Duration,
        perCallOutputByteLimit: Int,
        session: ProbeSessionBudget,
        auditRecorder: ProbeAuditRecorder
    ) {
        self.allowedRoots = allowedRoots
        self.maximumReadLevel = maximumReadLevel
        self.perCallTimeout = perCallTimeout
        self.perCallOutputByteLimit = perCallOutputByteLimit
        self.session = session
        self.auditRecorder = auditRecorder
    }
}

public struct DiskSnapshot: Codable, Sendable, Equatable {
    public let totalBytes: Int64
    public let availableBytes: Int64
}

public struct DirectorySummary: Codable, Sendable, Equatable {
    public let entryCount: Int
    public let logicalBytes: Int64
    public let allocatedBytes: Int64
}

public struct LargestChild: Codable, Sendable, Equatable {
    public let name: String
    public let logicalBytes: Int64
    public let isDirectory: Bool
}

public struct LargestChildren: Codable, Sendable, Equatable {
    public let children: [LargestChild]
}

public struct SafeTextSnippet: Codable, Sendable, Equatable {
    public let text: String
    public let byteCount: Int
    public let truncated: Bool
}

public enum ProbePayload: Codable, Sendable, Equatable {
    case diskSnapshot(DiskSnapshot)
    case directorySummary(DirectorySummary)
    case largestChildren(LargestChildren)
    case safeTextSnippet(SafeTextSnippet)
}

public struct ProbeResponse: Codable, Sendable, Equatable {
    public let payload: ProbePayload
    public let readBytes: Int
}

public enum ProbeFailure: String, Codable, Error, Sendable, Equatable {
    case capabilityNotAllowed
    case invalidRequest
    case pathDenied
    case pathUnknown
    case readLevelDenied
    case fileTypeNotAllowed
    case binaryContent
    case sessionCallBudgetExceeded
    case sessionReadBudgetExceeded
    case sessionOutputBudgetExceeded
    case outputByteLimitExceeded
    case fileIdentityChanged
    case accessFailed
    case timedOut
    case cancelled
}

public enum ProbeResult: Codable, Sendable, Equatable {
    case success(ProbeResponse)
    case failure(ProbeFailure)
}
