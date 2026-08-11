import Darwin

enum DirectoryEntryDecodingError: Error, Equatable {
    case invalidRecord
}

func decodeDirectoryEntryName(
    _ entry: UnsafePointer<dirent>
) throws -> String {
    guard let recordLengthOffset = MemoryLayout<dirent>.offset(
        of: \.d_reclen
    ),
    let nameLengthOffset = MemoryLayout<dirent>.offset(of: \.d_namlen),
    let nameOffset = MemoryLayout<dirent>.offset(of: \.d_name)
    else {
        throw DirectoryEntryDecodingError.invalidRecord
    }

    let rawEntry = UnsafeRawPointer(entry)
    let recordLength = Int(
        rawEntry.load(
            fromByteOffset: recordLengthOffset,
            as: UInt16.self
        )
    )
    let nameLength = Int(
        rawEntry.load(
            fromByteOffset: nameLengthOffset,
            as: UInt16.self
        )
    )
    let nameStorageCapacity = MemoryLayout.size(ofValue: dirent().d_name)

    guard nameLength > 0,
          nameLength < nameStorageCapacity,
          recordLength <= MemoryLayout<dirent>.size,
          nameOffset + nameLength + 1 <= recordLength
    else {
        throw DirectoryEntryDecodingError.invalidRecord
    }

    let nameBytes = UnsafeBufferPointer(
        start: rawEntry
            .advanced(by: nameOffset)
            .assumingMemoryBound(to: UInt8.self),
        count: nameLength
    )
    guard !nameBytes.contains(0),
          rawEntry.load(
              fromByteOffset: nameOffset + nameLength,
              as: UInt8.self
          ) == 0
    else {
        throw DirectoryEntryDecodingError.invalidRecord
    }

    guard let name = String(validating: nameBytes, as: UTF8.self) else {
        throw DirectoryEntryDecodingError.invalidRecord
    }
    return name
}
