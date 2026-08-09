import Darwin
import Foundation

public struct FileIdentity: Codable, Sendable, Equatable {
    public let device: UInt64
    public let inode: UInt64
    public let mode: UInt16
    public let ownerUserID: UInt32
    public let ownerGroupID: UInt32
    public let size: Int64
    public let allocatedBytes: Int64
    public let modificationSeconds: Int64
    public let modificationNanoseconds: Int64

    public init(
        device: UInt64,
        inode: UInt64,
        mode: UInt16,
        ownerUserID: UInt32,
        ownerGroupID: UInt32,
        size: Int64,
        allocatedBytes: Int64,
        modificationSeconds: Int64,
        modificationNanoseconds: Int64
    ) throws {
        guard size >= 0,
              allocatedBytes >= 0,
              modificationNanoseconds >= 0,
              modificationNanoseconds < 1_000_000_000
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.device = device
        self.inode = inode
        self.mode = mode
        self.ownerUserID = ownerUserID
        self.ownerGroupID = ownerGroupID
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

    public var isDirectory: Bool {
        mode_t(mode) & S_IFMT == S_IFDIR
    }

    public static func read(at url: URL) -> FileIdentity? {
        var information = stat()
        guard lstat(url.path, &information) == 0 else {
            return nil
        }
        let blocks = Int64(information.st_blocks)
        let allocated = blocks.multipliedReportingOverflow(by: 512)
        return try? FileIdentity(
            device: unsignedDeviceIdentity(information.st_dev),
            inode: UInt64(information.st_ino),
            mode: UInt16(information.st_mode),
            ownerUserID: information.st_uid,
            ownerGroupID: information.st_gid,
            size: max(0, Int64(information.st_size)),
            allocatedBytes: allocated.overflow
                ? .max
                : max(0, allocated.partialValue),
            modificationSeconds: Int64(information.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(information.st_mtimespec.tv_nsec)
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int64.self, forKey: .size)
        let allocatedBytes = try container.decode(
            Int64.self,
            forKey: .allocatedBytes
        )
        guard size >= 0, allocatedBytes >= 0 else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "File identity byte counts cannot be negative"
                )
            )
        }
        try self.init(
            device: container.decode(UInt64.self, forKey: .device),
            inode: container.decode(UInt64.self, forKey: .inode),
            mode: container.decode(UInt16.self, forKey: .mode),
            ownerUserID: container.decode(UInt32.self, forKey: .ownerUserID),
            ownerGroupID: container.decode(UInt32.self, forKey: .ownerGroupID),
            size: size,
            allocatedBytes: allocatedBytes,
            modificationSeconds: container.decode(
                Int64.self,
                forKey: .modificationSeconds
            ),
            modificationNanoseconds: container.decode(
                Int64.self,
                forKey: .modificationNanoseconds
            )
        )
    }
}

public typealias ActionFileIdentity = FileIdentity
