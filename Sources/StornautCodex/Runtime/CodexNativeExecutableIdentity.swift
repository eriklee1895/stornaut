import CryptoKit
import Darwin
import Foundation

package enum CodexNativeExecutableIdentityError: Error, Sendable, Equatable {
  case unavailable
  case invalidLayout
  case invalidExecutable(stage: String)
  case identityChanged
  case stagedDigestMismatch
}

package struct CodexNativeExecutableIdentity: Sendable, Equatable {
  package let canonicalURL: URL
  package let sha256: String
  package let device: UInt64
  package let inode: UInt64
  package let generation: UInt32
  package let size: Int64

  fileprivate let node: CodexNativeExecutableNode
  fileprivate let extendedAttributeNames: [String]
}

package final class CodexNativeExecutableIdentityLease: @unchecked Sendable {
  package let identity: CodexNativeExecutableIdentity

  package var canonicalURL: URL { identity.canonicalURL }
  package var sha256: String { identity.sha256 }
  package var device: UInt64 { identity.device }
  package var inode: UInt64 { identity.inode }
  package var generation: UInt32 { identity.generation }
  package var size: Int64 { identity.size }

  private let descriptor: Int32

  fileprivate init(
    identity: CodexNativeExecutableIdentity,
    descriptor: Int32
  ) {
    self.identity = identity
    self.descriptor = descriptor
  }

  deinit {
    _ = Darwin.close(descriptor)
  }

  package func revalidate() throws {
    let held = try CodexNativeExecutableIdentitySystem.descriptorNode(
      descriptor
    )
    let named = try CodexNativeExecutableIdentitySystem.namedNode(
      canonicalURL
    )
    guard
      held == identity.node,
      named == identity.node,
      try !CodexNativeExecutableIdentitySystem.hasExtendedACL(descriptor),
      try CodexNativeExecutableIdentitySystem.extendedAttributeNames(
        descriptor
      ) == identity.extendedAttributeNames
    else {
      throw CodexNativeExecutableIdentityError.identityChanged
    }
  }

  @discardableResult
  package func verifyStagedExecutable(at url: URL) throws
    -> CodexNativeExecutableIdentity
  {
    try revalidate()
    let staged = try CodexNativeExecutableIdentitySystem.openAndHash(
      url: url,
      expectedUserID: identity.node.ownerUserID,
      requiredMode: 0o500,
      observationHook: { _, _ in }
    )
    var stagedDescriptorNeedsClose = true
    defer {
      if stagedDescriptorNeedsClose {
        _ = Darwin.close(staged.descriptor)
      }
    }
    let closeResult = Darwin.close(staged.descriptor)
    let closeError = errno
    stagedDescriptorNeedsClose = false
    guard closeResult == 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "staged-close-\(closeError)"
      )
    }
    guard staged.identity.sha256 == sha256 else {
      throw CodexNativeExecutableIdentityError.stagedDigestMismatch
    }
    try revalidate()
    return staged.identity
  }
}

package struct CodexNativeExecutableIdentitySource {
  package static let maximumExecutableBytes: Int64 = 512 * 1_024 * 1_024

  private let observationHook: @Sendable (CodexNativeExecutableObservationPhase, URL) throws -> Void

  package init() {
    observationHook = { _, _ in }
  }

  init(
    observationHook:
      @escaping @Sendable (
        CodexNativeExecutableObservationPhase,
        URL
      ) throws -> Void
  ) {
    self.observationHook = observationHook
  }

  package func resolveInstalled() async throws
    -> CodexNativeExecutableIdentityLease
  {
    let userID = geteuid()
    guard userID > 0 else {
      throw CodexNativeExecutableIdentityError.unavailable
    }
    let home = try Self.currentHomeDirectory(userID: userID)
    let availability = await CodexLocator().locate(
      configuredURL: nil,
      environment: [
        "HOME": home,
        "PATH":
          "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:"
          + "/usr/sbin:/sbin",
      ]
    )
    guard let installation = availability.installation else {
      throw CodexNativeExecutableIdentityError.unavailable
    }
    return try resolve(
      installation: installation,
      expectedUserID: userID
    )
  }

  func resolve(
    installation: CodexInstallation,
    expectedUserID: uid_t
  ) throws -> CodexNativeExecutableIdentityLease {
    guard expectedUserID > 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "expected-user"
      )
    }
    let nativeURL = try Self.nativeExecutableURL(
      installation: installation
    )
    let opened = try CodexNativeExecutableIdentitySystem.openAndHash(
      url: nativeURL,
      expectedUserID: expectedUserID,
      requiredMode: nil,
      observationHook: observationHook
    )
    return CodexNativeExecutableIdentityLease(
      identity: opened.identity,
      descriptor: opened.descriptor
    )
  }

  private static func nativeExecutableURL(
    installation: CodexInstallation
  ) throws -> URL {
    let executable = installation.executableURL.standardizedFileURL
    let packageRoot =
      executable
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    guard
      executable.isFileURL,
      executable.path.hasPrefix("/"),
      executable.lastPathComponent == "codex.js",
      executable.deletingLastPathComponent().lastPathComponent == "bin",
      packageRoot.lastPathComponent == "codex"
    else {
      throw CodexNativeExecutableIdentityError.invalidLayout
    }
    return packageRoot.appending(
      path:
        "node_modules/@openai/codex-darwin-arm64/vendor/"
        + "aarch64-apple-darwin/bin/codex"
    ).standardizedFileURL
  }

  private static func currentHomeDirectory(userID: uid_t) throws -> String {
    var record = passwd()
    var result: UnsafeMutablePointer<passwd>?
    let configuredSize = sysconf(_SC_GETPW_R_SIZE_MAX)
    let bufferSize = max(16_384, configuredSize > 0 ? Int(configuredSize) : 0)
    var buffer = [CChar](repeating: 0, count: bufferSize)
    let status = getpwuid_r(
      userID,
      &record,
      &buffer,
      buffer.count,
      &result
    )
    guard
      status == 0,
      result != nil,
      let pointer = record.pw_dir
    else {
      throw CodexNativeExecutableIdentityError.unavailable
    }
    let home = String(cString: pointer)
    guard
      home.hasPrefix("/Users/"),
      !home.contains("\n"),
      !home.contains("\r")
    else {
      throw CodexNativeExecutableIdentityError.unavailable
    }
    return home
  }
}

enum CodexNativeExecutableObservationPhase: Sendable, Equatable {
  case beforeOpen
  case duringHash
  case afterHash
}

private struct CodexNativeExecutableNode: Sendable, Equatable {
  let device: UInt64
  let inode: UInt64
  let generation: UInt32
  let isRegularFile: Bool
  let ownerUserID: uid_t
  let ownerGroupID: gid_t
  let mode: mode_t
  let linkCount: UInt64
  let size: Int64
  let flags: UInt32
  let modificationSeconds: Int64
  let modificationNanoseconds: Int64
  let statusChangeSeconds: Int64
  let statusChangeNanoseconds: Int64

  init(_ value: stat) {
    device = UInt64(value.st_dev)
    inode = UInt64(value.st_ino)
    generation = value.st_gen
    isRegularFile = value.st_mode & S_IFMT == S_IFREG
    ownerUserID = value.st_uid
    ownerGroupID = value.st_gid
    mode = value.st_mode & 0o7777
    linkCount = UInt64(value.st_nlink)
    size = value.st_size
    flags = value.st_flags
    modificationSeconds = Int64(value.st_mtimespec.tv_sec)
    modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
    statusChangeSeconds = Int64(value.st_ctimespec.tv_sec)
    statusChangeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
  }
}

private enum CodexNativeExecutableIdentitySystem {
  private static let allowedExtendedAttributeNames = [
    "com.apple.provenance"
  ]
  private static let maximumExtendedAttributeListBytes = 4 * 1_024

  struct OpenedIdentity {
    let descriptor: Int32
    let identity: CodexNativeExecutableIdentity
  }

  static func openAndHash(
    url: URL,
    expectedUserID: uid_t,
    requiredMode: mode_t?,
    observationHook:
      @Sendable (
        CodexNativeExecutableObservationPhase,
        URL
      ) throws -> Void
  ) throws -> OpenedIdentity {
    guard
      url.isFileURL,
      url.path.hasPrefix("/"),
      url.path == url.standardizedFileURL.path
    else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "canonical-url"
      )
    }
    let initialNamed = try namedNode(url)
    try observationHook(.beforeOpen, url)
    let descriptor = open(
      url.path,
      O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY | O_UNIQUE | O_NONBLOCK
    )
    guard descriptor >= 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "open-\(errno)"
      )
    }
    var keepDescriptor = false
    defer {
      if !keepDescriptor {
        _ = Darwin.close(descriptor)
      }
    }
    let initialHeld = try descriptorNode(descriptor)
    guard initialHeld == initialNamed else {
      throw CodexNativeExecutableIdentityError.identityChanged
    }
    guard
      valid(initialHeld, expectedUserID: expectedUserID),
      requiredMode == nil || initialHeld.mode == requiredMode
    else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "metadata"
      )
    }
    guard try !hasExtendedACL(descriptor) else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "acl"
      )
    }
    let initialAttributes = try extendedAttributeNames(descriptor)
    guard
      initialAttributes.allSatisfy(
        allowedExtendedAttributeNames.contains
      )
    else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "xattr"
      )
    }
    let sha256 = try sha256(
      descriptor,
      size: initialHeld.size,
      url: url,
      observationHook: observationHook
    )
    try observationHook(.afterHash, url)
    let finalHeld = try descriptorNode(descriptor)
    let finalNamed = try namedNode(url)
    guard
      finalHeld == initialHeld,
      finalNamed == initialNamed,
      try !hasExtendedACL(descriptor),
      try extendedAttributeNames(descriptor) == initialAttributes
    else {
      throw CodexNativeExecutableIdentityError.identityChanged
    }
    keepDescriptor = true
    return OpenedIdentity(
      descriptor: descriptor,
      identity: CodexNativeExecutableIdentity(
        canonicalURL: url,
        sha256: sha256,
        device: initialHeld.device,
        inode: initialHeld.inode,
        generation: initialHeld.generation,
        size: initialHeld.size,
        node: initialHeld,
        extendedAttributeNames: initialAttributes
      )
    )
  }

  static func namedNode(_ url: URL) throws -> CodexNativeExecutableNode {
    var value = stat()
    guard lstat(url.path, &value) == 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "named-stat"
      )
    }
    return CodexNativeExecutableNode(value)
  }

  static func descriptorNode(_ descriptor: Int32) throws
    -> CodexNativeExecutableNode
  {
    var value = stat()
    guard fstat(descriptor, &value) == 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "descriptor-stat"
      )
    }
    return CodexNativeExecutableNode(value)
  }

  static func hasExtendedACL(_ descriptor: Int32) throws -> Bool {
    Darwin.errno = 0
    guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
      if Darwin.errno == ENOENT { return false }
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "acl-read"
      )
    }
    defer { acl_free(UnsafeMutableRawPointer(acl)) }
    var entry: acl_entry_t?
    let result = acl_get_entry(
      acl,
      Int32(ACL_FIRST_ENTRY.rawValue),
      &entry
    )
    guard result >= 0 else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "acl-entry"
      )
    }
    return result == 0
  }

  static func extendedAttributeNames(_ descriptor: Int32) throws -> [String] {
    let capacity = flistxattr(descriptor, nil, 0, 0)
    guard
      capacity >= 0,
      capacity <= maximumExtendedAttributeListBytes
    else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "xattr-size"
      )
    }
    guard capacity > 0 else { return [] }
    var buffer = [UInt8](repeating: 0, count: capacity)
    let count = buffer.withUnsafeMutableBytes { bytes in
      flistxattr(
        descriptor,
        bytes.baseAddress?.assumingMemoryBound(to: CChar.self),
        bytes.count,
        0
      )
    }
    guard count == capacity else {
      throw CodexNativeExecutableIdentityError.invalidExecutable(
        stage: "xattr-read"
      )
    }
    var names: [String] = []
    var start = buffer.startIndex
    while start < count {
      guard
        let terminator = buffer[start..<count].firstIndex(of: 0),
        terminator > start,
        let name = String(
          bytes: buffer[start..<terminator],
          encoding: .utf8
        ),
        name.utf8.count == terminator - start
      else {
        throw CodexNativeExecutableIdentityError.invalidExecutable(
          stage: "xattr-name"
        )
      }
      names.append(name)
      start = buffer.index(after: terminator)
    }
    return names.sorted()
  }

  private static func valid(
    _ node: CodexNativeExecutableNode,
    expectedUserID: uid_t
  ) -> Bool {
    node.device > 0
      && node.inode > 0
      && node.isRegularFile
      && node.ownerUserID == expectedUserID
      && node.mode & 0o100 != 0
      && node.mode & 0o022 == 0
      && node.linkCount == 1
      && node.size > 0
      && node.size
        <= CodexNativeExecutableIdentitySource.maximumExecutableBytes
      && node.flags == 0
  }

  private static func sha256(
    _ descriptor: Int32,
    size: Int64,
    url: URL,
    observationHook:
      @Sendable (
        CodexNativeExecutableObservationPhase,
        URL
      ) throws -> Void
  ) throws -> String {
    var hash = SHA256()
    var offset: Int64 = 0
    var invokedHook = false
    var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
    while offset < size {
      let requested = min(Int64(buffer.count), size - offset)
      let count = buffer.withUnsafeMutableBytes { bytes in
        pread(
          descriptor,
          bytes.baseAddress,
          Int(requested),
          off_t(offset)
        )
      }
      if count < 0, Darwin.errno == EINTR { continue }
      guard count > 0, count <= requested else {
        throw CodexNativeExecutableIdentityError.identityChanged
      }
      hash.update(data: Data(buffer.prefix(count)))
      offset += Int64(count)
      if !invokedHook {
        invokedHook = true
        try observationHook(.duringHash, url)
      }
    }
    let trailing = buffer.withUnsafeMutableBytes { bytes in
      pread(descriptor, bytes.baseAddress, 1, off_t(size))
    }
    guard trailing == 0 else {
      throw CodexNativeExecutableIdentityError.identityChanged
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
