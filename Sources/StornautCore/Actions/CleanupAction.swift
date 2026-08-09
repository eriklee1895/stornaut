import Darwin
import Foundation

public struct ActionFileIdentity: Codable, Sendable, Equatable {
    public let device: UInt64
    public let inode: UInt64
    public let mode: UInt16
    public let size: Int64
    public let allocatedBytes: Int64
    public let modificationSeconds: Int64
    public let modificationNanoseconds: Int64

    public init(
        device: UInt64,
        inode: UInt64,
        mode: UInt16,
        size: Int64,
        allocatedBytes: Int64,
        modificationSeconds: Int64,
        modificationNanoseconds: Int64
    ) {
        self.device = device
        self.inode = inode
        self.mode = mode
        self.size = size
        self.allocatedBytes = allocatedBytes
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
    }

    public var isSymbolicLink: Bool {
        mode_t(mode) & S_IFMT == S_IFLNK
    }

    public var isRegularFile: Bool {
        mode_t(mode) & S_IFMT == S_IFREG
    }

    public static func read(at url: URL) -> ActionFileIdentity? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            return nil
        }
        let blocks = Int64(info.st_blocks)
        let allocatedBytes = blocks.multipliedReportingOverflow(by: 512)
        return ActionFileIdentity(
            device: UInt64(bitPattern: Int64(info.st_dev)),
            inode: UInt64(info.st_ino),
            mode: UInt16(info.st_mode),
            size: Int64(info.st_size),
            allocatedBytes: allocatedBytes.overflow
                ? .max
                : allocatedBytes.partialValue,
            modificationSeconds: Int64(info.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(info.st_mtimespec.tv_nsec)
        )
    }
}

public struct PathAction: Codable, Sendable, Equatable {
    public let targetURL: URL
    public let expectedIdentity: ActionFileIdentity

    public init(
        targetURL: URL,
        expectedIdentity: ActionFileIdentity
    ) {
        self.targetURL = targetURL
        self.expectedIdentity = expectedIdentity
    }
}

public enum RegisteredActionMode: String, Codable, Sendable, CaseIterable {
    case success
    case dryRun
    case timeout
    case partialFailure
}

public struct RegisteredActionRequest: Codable, Sendable, Equatable {
    public let id: String
    public let mode: RegisteredActionMode

    public init(id: String, mode: RegisteredActionMode) {
        self.id = id
        self.mode = mode
    }
}

public enum CleanupAction: Codable, Sendable, Equatable {
    case moveToTrash(PathAction)
    case runRegisteredAction(RegisteredActionRequest)
}
