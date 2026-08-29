import CryptoKit
import Darwin
import Foundation

@main
struct StornautInvestigationBuildReceiptGenerator {
  static func main() {
    do {
      let options = try GeneratorOptions.parse(CommandLine.arguments)
      let declaredInput = try BuildInput.load(from: options.inputURL)
      try declaredInput.validate()
      let verifiedProvenance = try verifyRepositoryProvenance(
        expectedCommit: options.validationCommit,
        packageRootURL: options.packageRootURL,
        declaredInput: declaredInput,
        inputURL: options.inputURL
      )
      let source = GeneratedSource.render(provenance: verifiedProvenance)
      try writeGeneratedSource(
        source,
        to: options.outputDirectoryURL
      )
    } catch let error as GeneratorError {
      FileHandle.standardError.write(
        Data(
          "stornaut investigation build receipt generation failed: \(error.rawValue)\n".utf8
        )
      )
      Darwin.exit(2)
    } catch {
      FileHandle.standardError.write(
        Data(
          "stornaut investigation build receipt generation failed: invalid-input\n".utf8
        )
      )
      Darwin.exit(2)
    }
  }
}

private enum GeneratorError: String, Error {
  case invalidArguments = "invalid-arguments"
  case invalidInputPath = "invalid-input-path"
  case invalidOutputPath = "invalid-output-path"
  case invalidBuildInput = "invalid-build-input"
  case invalidValidationValue = "invalid-validation-value"
  case repositoryVerificationFailed = "repository-verification-failed"
  case outputFailed = "output-failed"
}

private struct GeneratorOptions {
  let packageRootURL: URL
  let inputURL: URL
  let outputDirectoryURL: URL
  let validationCommit: String?

  static func parse(_ arguments: [String]) throws -> Self {
    guard arguments.count >= 5 else {
      throw GeneratorError.invalidArguments
    }

    var values: [String: String] = [:]
    var index = 1
    while index < arguments.count {
      let flag = arguments[index]
      guard
        flag.hasPrefix("--"),
        index + 1 < arguments.count,
        values[flag] == nil
      else {
        throw GeneratorError.invalidArguments
      }
      values[flag] = arguments[index + 1]
      index += 2
    }

    let acceptedFlags: Set<String> = [
      "--package-root", "--input", "--output-directory",
      "--validation-commit",
    ]
    guard
      Set(values.keys).isSubset(of: acceptedFlags),
      let packageRootPath = values.removeValue(forKey: "--package-root"),
      let inputPath = values.removeValue(forKey: "--input"),
      let outputDirectoryPath = values.removeValue(
        forKey: "--output-directory"
      ),
      !packageRootPath.isEmpty,
      !inputPath.isEmpty,
      !outputDirectoryPath.isEmpty,
      packageRootPath.hasPrefix("/"),
      inputPath.hasPrefix("/"),
      outputDirectoryPath.hasPrefix("/")
    else {
      throw GeneratorError.invalidArguments
    }

    let validationCommit = values.removeValue(forKey: "--validation-commit")
    guard values.isEmpty else {
      throw GeneratorError.invalidArguments
    }

    return Self(
      packageRootURL: URL(
        fileURLWithPath: packageRootPath,
        isDirectory: true
      ).standardizedFileURL,
      inputURL: URL(fileURLWithPath: inputPath).standardizedFileURL,
      outputDirectoryURL: URL(
        fileURLWithPath: outputDirectoryPath,
        isDirectory: true
      ).standardizedFileURL,
      validationCommit: validationCommit
    )
  }
}

private enum ProvenanceField: String, CaseIterable {
  case validationCommit
  case validationTree
  case canonicalManifestSHA256
  case promptSHA256
  case envelopeSchemaSHA256
  case facadeSHA256

}

private enum ProvenanceInput {
  case available([ProvenanceField: String])
  case unavailable
}

private struct RepositoryProvenanceVerifier {
  private static let gitExecutable = "/usr/bin/git"
  private static let expectedBuildInputRelativePath =
    "Sources/StornautInvestigationMachineGateCoordinatorSupport/Resources/"
    + "InvestigationMachineBuildInputs.json"

  let packageRootURL: URL
  let declaredInput: BuildInput
  let inputURL: URL

  func verify(expectedCommit: String?) throws -> ProvenanceInput {
    guard let expectedCommit else {
      return .unavailable
    }
    guard expectedCommit.isLowercaseHex(count: 40) else {
      throw GeneratorError.invalidValidationValue
    }
    guard
      packageRootURL.isFileURL,
      packageRootURL.path.hasPrefix("/"),
      packageRootURL.standardizedFileURL == packageRootURL,
      inputURL.standardizedFileURL
        == packageRootURL.appendingPathComponent(
          Self.expectedBuildInputRelativePath,
          isDirectory: false
        ).standardizedFileURL
    else {
      throw GeneratorError.repositoryVerificationFailed
    }

    let observedCommit = try gitText([
      "rev-parse", "--verify", "HEAD^{commit}",
    ])
    guard
      observedCommit.isLowercaseHex(count: 40),
      observedCommit == expectedCommit
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    let observedTree = try gitText([
      "rev-parse", "--verify", "\(observedCommit)^{tree}",
    ])
    guard
      observedTree.isLowercaseHex(count: 40)
    else {
      throw GeneratorError.repositoryVerificationFailed
    }

    let rawManifest = try runGit([
      "ls-tree", "-rz", "--full-tree", "--long", observedTree,
    ])
    let manifestEntries = try decodeManifest(rawManifest)
    var manifestBytes = Data(declaredInput.canonicalManifest.domain.utf8)
    manifestBytes.append(0)
    manifestBytes.append(rawManifest)
    let manifestSHA256 = sha256Hex(manifestBytes)

    for entry in manifestEntries {
      let path = try decodeCanonicalPath(entry.pathBytes)
      let fileURL = packageRootURL.appendingPathComponent(
        path,
        isDirectory: false
      )
      let filesystemBytes = try readBoundedRegularFile(
        fileURL,
        maximumByteCount: entry.byteCount,
        expectedExecutable: entry.mode == "100755"
      )
      guard gitBlobObjectID(filesystemBytes) == entry.objectID else {
        throw GeneratorError.repositoryVerificationFailed
      }
    }
    guard
      try gitText([
        "status", "--porcelain=v1", "--untracked-files=all",
      ]).isEmpty
    else {
      throw GeneratorError.repositoryVerificationFailed
    }

    var artifactHashes: [ProvenanceField: String] = [:]
    for (field, path) in [
      (ProvenanceField.promptSHA256, declaredInput.artifacts.promptRelativePath),
      (
        ProvenanceField.envelopeSchemaSHA256,
        declaredInput.artifacts.envelopeSchemaRelativePath
      ),
      (
        ProvenanceField.facadeSHA256,
        declaredInput.artifacts.task38FacadeRelativePath
      ),
    ] {
      let treeBytes = try runGit([
        "cat-file", "blob", "\(observedTree):\(path)",
      ])
      let filesystemBytes = try readBoundedRegularFile(
        packageRootURL.appendingPathComponent(path, isDirectory: false),
        maximumByteCount: treeBytes.count,
        expectedExecutable: false
      )
      guard filesystemBytes == treeBytes else {
        throw GeneratorError.repositoryVerificationFailed
      }
      artifactHashes[field] = sha256Hex(treeBytes)
    }

    guard
      try gitText([
        "rev-parse", "--verify", "HEAD^{commit}",
      ]) == observedCommit,
      try gitText([
        "rev-parse", "--verify", "HEAD^{tree}",
      ]) == observedTree
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    guard
      let promptSHA256 = artifactHashes[.promptSHA256],
      let envelopeSHA256 = artifactHashes[.envelopeSchemaSHA256],
      let facadeSHA256 = artifactHashes[.facadeSHA256]
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    let derived: [ProvenanceField: String] = [
      .validationCommit: observedCommit,
      .validationTree: observedTree,
      .canonicalManifestSHA256: manifestSHA256,
      .promptSHA256: promptSHA256,
      .envelopeSchemaSHA256: envelopeSHA256,
      .facadeSHA256: facadeSHA256,
    ]
    return .available(derived)
  }

  private func gitText(_ arguments: [String]) throws -> String {
    let bytes = try runGit(arguments)
    if bytes.isEmpty {
      return ""
    }
    guard
      let value = String(data: bytes, encoding: .utf8),
      value.hasSuffix("\n"),
      !value.dropLast().contains("\n")
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    return String(value.dropLast())
  }

  private func runGit(_ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: Self.gitExecutable)
    process.arguments = ["-c", "core.hooksPath=/dev/null", "-c",
      "core.fsmonitor=false", "-c", "core.untrackedCache=false",
      "-C", packageRootURL.path] + arguments
    process.environment = [
      "GIT_CONFIG_NOSYSTEM": "1",
      "GIT_CONFIG_SYSTEM": "/dev/null",
      "GIT_CONFIG_GLOBAL": "/dev/null",
      "GIT_NO_REPLACE_OBJECTS": "1",
      "GIT_NO_LAZY_FETCH": "1",
      "GIT_OPTIONAL_LOCKS": "0",
      "GIT_TERMINAL_PROMPT": "0",
      "HOME": "/var/empty",
      "LC_ALL": "C",
      "PATH": "/usr/bin:/bin",
      "XDG_CONFIG_HOME": "/var/empty",
    ]
    process.standardInput = FileHandle.nullDevice
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      throw GeneratorError.repositoryVerificationFailed
    }
    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard
      process.terminationReason == .exit,
      process.terminationStatus == 0
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    return outputData
  }

  private struct ManifestEntry {
    let mode: String
    let objectID: String
    let byteCount: Int
    let pathBytes: Data
  }

  private func decodeManifest(_ data: Data) throws -> [ManifestEntry] {
    let records = data.split(separator: 0, omittingEmptySubsequences: false)
    guard records.count > 1, records.last?.isEmpty == true else {
      throw GeneratorError.repositoryVerificationFailed
    }
    var entries: [ManifestEntry] = []
    entries.reserveCapacity(records.count - 1)
    for record in records.dropLast() {
      guard let tab = record.firstIndex(of: 9) else {
        throw GeneratorError.repositoryVerificationFailed
      }
      let header = record[..<tab].split(separator: 32)
      let path = record[record.index(after: tab)...]
      guard
        header.count == 4,
        header[0] == Data("100644".utf8)
          || header[0] == Data("100755".utf8),
        header[1].elementsEqual(Data("blob".utf8)),
        header[2].count == 40,
        header[2].allSatisfy({
          (48...57).contains($0) || (97...102).contains($0)
        }),
        !header[3].isEmpty,
        header[3].allSatisfy({ (48...57).contains($0) }),
        !path.isEmpty,
        let byteCount = Int(
          String(decoding: header[3], as: UTF8.self)
        ),
        byteCount >= 0
      else {
        throw GeneratorError.repositoryVerificationFailed
      }
      entries.append(
        ManifestEntry(
          mode: String(decoding: header[0], as: UTF8.self),
          objectID: String(decoding: header[2], as: UTF8.self),
          byteCount: byteCount,
          pathBytes: Data(path)
        )
      )
    }
    return entries
  }

  private func decodeCanonicalPath(_ data: Data) throws -> String {
    guard
      let path = String(data: data, encoding: .utf8),
      Data(path.utf8) == data,
      path.isCanonicalRelativePath
    else {
      throw GeneratorError.repositoryVerificationFailed
    }
    return path
  }
}

private func verifyRepositoryProvenance(
  expectedCommit: String?,
  packageRootURL: URL,
  declaredInput: BuildInput,
  inputURL: URL
) throws -> ProvenanceInput {
  try RepositoryProvenanceVerifier(
    packageRootURL: packageRootURL,
    declaredInput: declaredInput,
    inputURL: inputURL
  ).verify(expectedCommit: expectedCommit)
}

private func readBoundedRegularFile(
  _ url: URL,
  maximumByteCount: Int,
  expectedExecutable: Bool
) throws -> Data {
  guard maximumByteCount >= 0 else {
    throw GeneratorError.repositoryVerificationFailed
  }
  let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
  guard descriptor >= 0 else {
    throw GeneratorError.repositoryVerificationFailed
  }
  defer { close(descriptor) }
  var information = stat()
  guard
    fstat(descriptor, &information) == 0,
    information.st_mode & S_IFMT == S_IFREG,
    information.st_nlink == 1,
    information.st_size == maximumByteCount,
    information.st_mode & 0o777 == (expectedExecutable ? 0o755 : 0o644)
  else {
    throw GeneratorError.repositoryVerificationFailed
  }
  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
  while true {
    let count = Darwin.read(descriptor, &buffer, buffer.count)
    if count == 0 {
      return data
    }
    if count < 0 {
      if errno == EINTR {
        continue
      }
      throw GeneratorError.repositoryVerificationFailed
    }
    guard data.count + count <= maximumByteCount else {
      throw GeneratorError.repositoryVerificationFailed
    }
    data.append(contentsOf: buffer.prefix(count))
  }
}

private func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func gitBlobObjectID(_ data: Data) -> String {
  var framed = Data("blob \(data.count)\0".utf8)
  framed.append(data)
  return Insecure.SHA1.hash(data: framed)
    .map { String(format: "%02x", $0) }.joined()
}

private struct BuildInput: Decodable {
  let schemaVersion: Int
  let canonicalManifest: CanonicalManifest
  let artifacts: Artifacts

  struct CanonicalManifest: Decodable {
    let schemaVersion: Int
    let domain: String
    let command: String
    let commandArguments: [String]
    let treeArgument: String
    let digestInput: [String]
    let requiredObjectType: String
    let digestAlgorithm: String
    let digestEncoding: String
  }

  struct Artifacts: Decodable {
    let promptRelativePath: String
    let envelopeSchemaRelativePath: String
    let task38FacadeRelativePath: String
  }

  static func load(from url: URL) throws -> Self {
    guard url.isFileURL, url.path.hasPrefix("/") else {
      throw GeneratorError.invalidInputPath
    }
    let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard descriptor >= 0 else {
      throw GeneratorError.invalidInputPath
    }
    defer { close(descriptor) }
    var information = stat()
    guard
      fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      information.st_nlink == 1,
      information.st_size > 0,
      information.st_size <= 32 * 1_024
    else {
      throw GeneratorError.invalidInputPath
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
      let count = Darwin.read(descriptor, &buffer, buffer.count)
      if count == 0 {
        break
      }
      if count < 0 {
        if errno == EINTR {
          continue
        }
        throw GeneratorError.invalidInputPath
      }
      guard data.count + count <= 32 * 1_024 else {
        throw GeneratorError.invalidInputPath
      }
      data.append(contentsOf: buffer.prefix(count))
    }
    guard
      data.count == information.st_size,
      hasExactJSONShape(data)
    else {
      throw GeneratorError.invalidInputPath
    }
    do {
      return try JSONDecoder().decode(Self.self, from: data)
    } catch {
      throw GeneratorError.invalidBuildInput
    }
  }

  func validate() throws {
    guard
      schemaVersion == 1,
      canonicalManifest.schemaVersion == 1,
      canonicalManifest.domain
        == "stornaut.task39.machine.git-manifest.v1",
      canonicalManifest.command == "/usr/bin/git",
      canonicalManifest.commandArguments == [
        "ls-tree",
        "-rz",
        "--full-tree",
        "--long",
      ],
      canonicalManifest.treeArgument == "validationTree",
      canonicalManifest.digestInput == [
        "domain-utf8",
        "nul",
        "raw-command-stdout",
      ],
      canonicalManifest.requiredObjectType == "blob",
      canonicalManifest.digestAlgorithm == "sha256",
      canonicalManifest.digestEncoding == "lowercase-hex",
      artifacts.promptRelativePath
        == "Sources/StornautInvestigation/Resources/investigation-prompt-v1.txt",
      artifacts.envelopeSchemaRelativePath
        == "Sources/StornautCodex/Schemas/investigation-envelope-v2.schema.json",
      artifacts.task38FacadeRelativePath
        == "Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift",
      [
        artifacts.promptRelativePath,
        artifacts.envelopeSchemaRelativePath,
        artifacts.task38FacadeRelativePath,
      ].allSatisfy(\.isCanonicalRelativePath)
    else {
      throw GeneratorError.invalidBuildInput
    }
  }

  private static func hasExactJSONShape(_ data: Data) -> Bool {
    guard
      let root = try? JSONSerialization.jsonObject(
        with: data,
        options: []
      ) as? [String: Any],
      Set(root.keys) == [
        "schemaVersion",
        "canonicalManifest",
        "artifacts",
      ],
      let manifest = root["canonicalManifest"] as? [String: Any],
      Set(manifest.keys) == [
        "schemaVersion",
        "domain",
        "command",
        "commandArguments",
        "treeArgument",
        "digestInput",
        "requiredObjectType",
        "digestAlgorithm",
        "digestEncoding",
      ],
      let artifacts = root["artifacts"] as? [String: Any],
      Set(artifacts.keys) == [
        "promptRelativePath",
        "envelopeSchemaRelativePath",
        "task38FacadeRelativePath",
      ]
    else {
      return false
    }
    return true
  }
}

private enum GeneratedSource {
  private static let receiptDomain =
    "stornaut.task39.machine.build-provenance.v1"
  private static let coordinatorTarget =
    "StornautInvestigationMachineGateCoordinatorSupport"
  private static let coordinatorProduct =
    "StornautInvestigationMachineGateCoordinator"

  static func render(provenance: ProvenanceInput) -> String {
    let availability: String
    let values: [ProvenanceField: String?]
    switch provenance {
    case .available(let available):
      availability = ".available"
      values = Dictionary(
        uniqueKeysWithValues: ProvenanceField.allCases.map {
          ($0, available[$0])
        }
      )
    case .unavailable:
      availability = ".unavailable(.validationSnapshotEnvironmentUnavailable)"
      values = Dictionary(
        uniqueKeysWithValues: ProvenanceField.allCases.map {
          ($0, nil)
        }
      )
    }

    return """
      // Generated by StornautInvestigationBuildReceiptGenerator.
      // This file is deterministic and contains no runtime discovery code.

      package enum InvestigationMachineGeneratedBuildProvenance {
          package enum Unavailability: String, Sendable, Equatable {
              case validationSnapshotEnvironmentUnavailable
              case validationSnapshotEnvironmentIncomplete
          }

          package enum Availability: Sendable, Equatable {
              case available
              case unavailable(Unavailability)
          }

          package static let schemaVersion: Int = 1
          package static let domain: String = \(literal(receiptDomain))
          package static let availability: Availability = \(availability)

          package static let validationCommit: String? = \(literal(values[.validationCommit] ?? nil))
          package static let validationTree: String? = \(literal(values[.validationTree] ?? nil))
          package static let canonicalManifestSHA256: String? = \(literal(values[.canonicalManifestSHA256] ?? nil))
          package static let promptSHA256: String? = \(literal(values[.promptSHA256] ?? nil))
          package static let envelopeSchemaSHA256: String? = \(literal(values[.envelopeSchemaSHA256] ?? nil))
          package static let facadeSHA256: String? = \(literal(values[.facadeSHA256] ?? nil))
      package static let coordinatorTargetIdentifier: String = \(literal(coordinatorTarget))
      package static let coordinatorProductIdentifier: String = \(literal(coordinatorProduct))

      #if DEBUG
          package static let buildConfiguration: String = "debug"
      #else
          package static let buildConfiguration: String = "release"
      #endif
      }
      """ + "\n"
  }

  private static func literal(_ value: String) -> String {
    "\"\(value)\""
  }

  private static func literal(_ value: String?) -> String {
    guard let value else {
      return "nil"
    }
    return literal(value)
  }

}

private func writeGeneratedSource(
  _ source: String,
  to outputDirectory: URL
) throws {
  guard
    outputDirectory.isFileURL,
    outputDirectory.path.hasPrefix("/")
  else {
    throw GeneratorError.invalidOutputPath
  }
  do {
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let attributes = try FileManager.default.attributesOfItem(
      atPath: outputDirectory.path
    )
    guard attributes[.type] as? FileAttributeType == .typeDirectory else {
      throw GeneratorError.invalidOutputPath
    }
    let output = outputDirectory.appendingPathComponent(
      "InvestigationMachineGeneratedBuildProvenance.swift",
      isDirectory: false
    )
    try Data(source.utf8).write(to: output, options: .atomic)
  } catch let error as GeneratorError {
    throw error
  } catch {
    throw GeneratorError.outputFailed
  }
}

extension String {
  fileprivate func isLowercaseHex(count expectedCount: Int) -> Bool {
    count == expectedCount
      && utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }

  fileprivate var isCanonicalRelativePath: Bool {
    guard
      !isEmpty,
      !hasPrefix("/"),
      !hasSuffix("/"),
      !contains("\0"),
      !contains("\\")
    else {
      return false
    }
    return split(separator: "/", omittingEmptySubsequences: false)
      .allSatisfy { component in
        !component.isEmpty && component != "." && component != ".."
      }
  }
}
