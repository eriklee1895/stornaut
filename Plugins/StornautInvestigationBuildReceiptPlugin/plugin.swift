import Darwin
import Foundation
import PackagePlugin

@main
struct StornautInvestigationBuildReceiptPlugin: BuildToolPlugin {
  private static let targetIdentifier =
    "StornautInvestigationMachineGateCoordinatorSupport"
  private static let generatedDirectoryName = "GeneratedBuildProvenance"

  private static let validationEnvironment: [(name: String, flag: String)] = [
    ("STORNAUT_VALIDATION_COMMIT", "--validation-commit")
  ]

  func createBuildCommands(
    context: PluginContext,
    target: any Target
  ) async throws -> [Command] {
    guard target.name == Self.targetIdentifier else {
      throw BuildReceiptPluginError.unexpectedTarget
    }

    let generator = try context.tool(
      named: "StornautInvestigationBuildReceiptGenerator"
    ).url
    let declaredInput = target.directoryURL
      .appending(path: "Resources")
      .appending(path: "InvestigationMachineBuildInputs.json")
    let validationCommit = Self.environmentValue(
      named: "STORNAUT_VALIDATION_COMMIT"
    )
    let cacheKey = validationCommit.map(Self.safeCacheKey) ?? "unavailable"
    let outputDirectory = context.pluginWorkDirectoryURL
      .appending(path: Self.generatedDirectoryName)
      .appending(path: cacheKey)
    let output = outputDirectory.appending(
      path: "InvestigationMachineGeneratedBuildProvenance.swift"
    )
    var arguments = [
      "--package-root", context.package.directoryURL.path,
      "--input", declaredInput.path,
      "--output-directory", outputDirectory.path,
    ]
    for item in Self.validationEnvironment {
      if let value = validationCommit {
        arguments.append(contentsOf: [item.flag, value])
      }
    }

    return [
      .buildCommand(
        displayName: "Generate Stornaut investigation build provenance",
        executable: generator,
        arguments: arguments,
        inputFiles: [declaredInput],
        outputFiles: [output]
      )
    ]
  }

  /// Read only the sealed validation commit named above. In particular,
  /// do not copy the ambient process environment into the generator command.
  private static func environmentValue(named name: String) -> String? {
    guard let value = getenv(name) else {
      return nil
    }
    return String(cString: value)
  }

  private static func safeCacheKey(_ value: String) -> String {
    value.utf8.count == 40 && value.utf8.allSatisfy {
      (48...57).contains($0) || (97...102).contains($0)
    } ? value : "invalid"
  }
}

private enum BuildReceiptPluginError: Error {
  case unexpectedTarget
}
