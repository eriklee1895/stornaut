import CryptoKit
import Darwin
import Foundation
import Testing

@testable import StornautCodex

@Suite(.serialized)
struct CodexNativeExecutableIdentityTests {
  @Test(
    .enabled(
      if: ProcessInfo.processInfo.environment[
        "STORNAUT_RUN_INSTALLED_CODEX_IDENTITY_DIAGNOSTIC"
      ] == "1",
      "Opt in to the read-only installed Codex native identity diagnostic"
    )
  )
  func installedNativeIdentityDiagnostic() async throws {
    let lease = try await CodexNativeExecutableIdentitySource()
      .resolveInstalled()

    #expect(lease.canonicalURL.lastPathComponent == "codex")
    #expect(lease.sha256.utf8.count == 64)
    #expect(lease.size > 0)
    try lease.revalidate()
  }

  @Test
  func resolvesInstalledNativeAndVerifiesMatchingStage() async throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let nativeBytes = Data("native-codex-binary\n".utf8)
    let installation = try fixture.makeInstallation(nativeBytes: nativeBytes)

    let lease = try CodexNativeExecutableIdentitySource().resolve(
      installation: installation,
      expectedUserID: geteuid()
    )

    #expect(lease.canonicalURL == fixture.nativeURL.standardizedFileURL)
    #expect(lease.sha256 == digest(nativeBytes))
    #expect(lease.device > 0)
    #expect(lease.inode > 0)
    #expect(lease.generation == lease.identity.generation)
    #expect(lease.size == Int64(nativeBytes.count))
    try lease.revalidate()

    let staged = try fixture.makeExecutable(
      at: "staged/bin/codex",
      bytes: nativeBytes
    )
    #expect(chmod(staged.path, 0o500) == 0)
    let stagedIdentity = try lease.verifyStagedExecutable(at: staged)
    #expect(stagedIdentity.canonicalURL == staged.standardizedFileURL)
    #expect(stagedIdentity.sha256 == lease.sha256)
  }

  @Test
  func hashesNativeBinaryRatherThanWrapper() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let nativeBytes = Data("native-payload\n".utf8)
    let installation = try fixture.makeInstallation(
      nativeBytes: nativeBytes,
      wrapperBytes: Data("different-wrapper\n".utf8)
    )

    let lease = try CodexNativeExecutableIdentitySource().resolve(
      installation: installation,
      expectedUserID: geteuid()
    )

    #expect(lease.sha256 == digest(nativeBytes))
    #expect(lease.sha256 != digest(try Data(contentsOf: installation.executableURL)))
  }

  @Test
  func acceptsNormalAppleProvenanceAttribute() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let installation = try fixture.makeInstallation()
    try fixture.setExtendedAttribute(
      name: "com.apple.provenance",
      value: Data([0x01, 0x02, 0x03]),
      at: fixture.nativeURL
    )

    let lease = try CodexNativeExecutableIdentitySource().resolve(
      installation: installation,
      expectedUserID: geteuid()
    )

    try lease.revalidate()
  }

  @Test
  func rejectsUnexpectedExtendedAttribute() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let installation = try fixture.makeInstallation()
    try fixture.setExtendedAttribute(
      name: "user.stornaut-test",
      value: Data("unexpected".utf8),
      at: fixture.nativeURL
    )

    #expect(throws: CodexNativeExecutableIdentityError.self) {
      _ = try CodexNativeExecutableIdentitySource().resolve(
        installation: installation,
        expectedUserID: geteuid()
      )
    }
  }

  @Test
  func rejectsWrongPackageLayoutAndSymlinkedNative() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let wrongWrapper = try fixture.makeExecutable(
      at: "wrong/bin/codex.js",
      bytes: Data("wrapper\n".utf8)
    )
    #expect(throws: CodexNativeExecutableIdentityError.self) {
      _ = try CodexNativeExecutableIdentitySource().resolve(
        installation: CodexInstallation(
          executableURL: wrongWrapper,
          source: .configured
        ),
        expectedUserID: geteuid()
      )
    }

    let installation = try fixture.makeInstallation()
    let original = fixture.root.appending(path: "native-target")
    try FileManager.default.moveItem(at: fixture.nativeURL, to: original)
    try FileManager.default.createSymbolicLink(
      atPath: fixture.nativeURL.path,
      withDestinationPath: original.path
    )
    #expect(throws: CodexNativeExecutableIdentityError.self) {
      _ = try CodexNativeExecutableIdentitySource().resolve(
        installation: installation,
        expectedUserID: geteuid()
      )
    }
  }

  @Test
  func rejectsInvalidExecutableMetadata() throws {
    for mutation in NativeCodexFixture.MetadataMutation.allCases {
      let fixture = try NativeCodexFixture()
      defer { fixture.remove() }
      let installation = try fixture.makeInstallation()
      try fixture.apply(mutation)

      #expect(throws: CodexNativeExecutableIdentityError.self) {
        _ = try CodexNativeExecutableIdentitySource().resolve(
          installation: installation,
          expectedUserID: mutation == .ownerMismatch
            ? geteuid() &+ 1 : geteuid()
        )
      }
    }
  }

  @Test
  func revalidationRejectsNamedReplacementAndMetadataDrift() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let installation = try fixture.makeInstallation()
    let lease = try CodexNativeExecutableIdentitySource().resolve(
      installation: installation,
      expectedUserID: geteuid()
    )

    let replacement = try fixture.makeExecutable(
      at: "replacement-codex",
      bytes: Data("replacement\n".utf8)
    )
    try FileManager.default.removeItem(at: fixture.nativeURL)
    try FileManager.default.moveItem(at: replacement, to: fixture.nativeURL)

    #expect(throws: CodexNativeExecutableIdentityError.self) {
      try lease.revalidate()
    }

    let secondFixture = try NativeCodexFixture()
    defer { secondFixture.remove() }
    let secondInstallation = try secondFixture.makeInstallation()
    let secondLease = try CodexNativeExecutableIdentitySource().resolve(
      installation: secondInstallation,
      expectedUserID: geteuid()
    )
    #expect(chmod(secondFixture.nativeURL.path, 0o700) == 0)
    #expect(throws: CodexNativeExecutableIdentityError.self) {
      try secondLease.revalidate()
    }
  }

  @Test(
    arguments: [
      CodexNativeExecutableObservationPhase.beforeOpen,
      .duringHash,
      .afterHash,
    ]
  )
  func resolutionRejectsReplacementAcrossObservationPhases(
    _ mutationPhase: CodexNativeExecutableObservationPhase
  ) throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let installation = try fixture.makeInstallation()
    let replacement = try fixture.makeExecutable(
      at: "replacement-for-hook",
      bytes: Data("replacement\n".utf8)
    )
    let nativeURL = fixture.nativeURL
    let source = CodexNativeExecutableIdentitySource { phase, _ in
      guard phase == mutationPhase else { return }
      guard FileManager.default.fileExists(atPath: replacement.path) else {
        return
      }
      if FileManager.default.fileExists(atPath: nativeURL.path) {
        try FileManager.default.removeItem(at: nativeURL)
      }
      try FileManager.default.moveItem(
        at: replacement,
        to: nativeURL
      )
    }

    #expect(throws: CodexNativeExecutableIdentityError.self) {
      _ = try source.resolve(
        installation: installation,
        expectedUserID: geteuid()
      )
    }
  }

  @Test
  func stagedVerificationRejectsDigestMismatchAndSymlink() throws {
    let fixture = try NativeCodexFixture()
    defer { fixture.remove() }
    let installation = try fixture.makeInstallation()
    let lease = try CodexNativeExecutableIdentitySource().resolve(
      installation: installation,
      expectedUserID: geteuid()
    )
    let mismatched = try fixture.makeExecutable(
      at: "staged/mismatched",
      bytes: Data("not-the-installed-binary\n".utf8)
    )
    #expect(chmod(mismatched.path, 0o500) == 0)
    #expect(
      throws: CodexNativeExecutableIdentityError.stagedDigestMismatch
    ) {
      try lease.verifyStagedExecutable(at: mismatched)
    }

    let unsealedMatching = try fixture.makeExecutable(
      at: "staged/matching",
      bytes: try Data(contentsOf: fixture.nativeURL)
    )
    #expect(throws: CodexNativeExecutableIdentityError.self) {
      try lease.verifyStagedExecutable(at: unsealedMatching)
    }
    #expect(chmod(unsealedMatching.path, 0o500) == 0)
    let symlink = fixture.root.appending(path: "staged/link")
    try FileManager.default.createSymbolicLink(
      atPath: symlink.path,
      withDestinationPath: unsealedMatching.path
    )
    #expect(throws: CodexNativeExecutableIdentityError.self) {
      try lease.verifyStagedExecutable(at: symlink)
    }
  }
}

private final class NativeCodexFixture {
  enum MetadataMutation: CaseIterable {
    case nonExecutable
    case hardLink
    case empty
    case ownerMismatch
    case directory
    case oversized
    case flags
    case fifo
  }

  let root: URL
  let packageRoot: URL
  let nativeURL: URL

  init() throws {
    root = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: ".build", directoryHint: .isDirectory)
      .appending(
        path: "StornautCodexNativeIdentityTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )
    packageRoot = root.appending(
      path: "lib/node_modules/@openai/codex",
      directoryHint: .isDirectory
    )
    nativeURL = packageRoot.appending(
      path:
        "node_modules/@openai/codex-darwin-arm64/vendor/"
        + "aarch64-apple-darwin/bin/codex"
    )
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }

  func makeInstallation(
    nativeBytes: Data = Data("native\n".utf8),
    wrapperBytes: Data = Data("#!/usr/bin/env node\n".utf8)
  ) throws -> CodexInstallation {
    let wrapper = try makeExecutable(
      at: "lib/node_modules/@openai/codex/bin/codex.js",
      bytes: wrapperBytes
    )
    _ = try makeExecutable(
      at:
        "lib/node_modules/@openai/codex/node_modules/@openai/"
        + "codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex",
      bytes: nativeBytes
    )
    return CodexInstallation(executableURL: wrapper, source: .configured)
  }

  func makeExecutable(at relativePath: String, bytes: Data) throws -> URL {
    let url = root.appending(path: relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try bytes.write(to: url)
    #expect(chmod(url.path, 0o755) == 0)
    return url
  }

  func setExtendedAttribute(name: String, value: Data, at url: URL) throws {
    let result = value.withUnsafeBytes { bytes in
      setxattr(
        url.path,
        name,
        bytes.baseAddress,
        bytes.count,
        0,
        0
      )
    }
    guard result == 0 else { throw POSIXError(.init(rawValue: errno)!) }
  }

  func apply(_ mutation: MetadataMutation) throws {
    switch mutation {
    case .nonExecutable:
      #expect(chmod(nativeURL.path, 0o644) == 0)
    case .hardLink:
      #expect(link(nativeURL.path, root.appending(path: "hardlink").path) == 0)
    case .empty:
      try Data().write(to: nativeURL)
      #expect(chmod(nativeURL.path, 0o755) == 0)
    case .ownerMismatch:
      break
    case .directory:
      try FileManager.default.removeItem(at: nativeURL)
      try FileManager.default.createDirectory(
        at: nativeURL,
        withIntermediateDirectories: false
      )
    case .oversized:
      let descriptor = open(nativeURL.path, O_WRONLY | O_CLOEXEC)
      guard descriptor >= 0 else {
        throw POSIXError(.init(rawValue: errno)!)
      }
      defer { close(descriptor) }
      #expect(
        ftruncate(
          descriptor,
          CodexNativeExecutableIdentitySource.maximumExecutableBytes
            + 1
        ) == 0
      )
    case .flags:
      #expect(chflags(nativeURL.path, UInt32(UF_NODUMP)) == 0)
    case .fifo:
      try FileManager.default.removeItem(at: nativeURL)
      #expect(mkfifo(nativeURL.path, 0o700) == 0)
    }
  }
}

private func digest(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
