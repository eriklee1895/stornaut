import Foundation
import RuleCompilerKit

@main
struct StornautRuleCompilerCommand {
    static func main() {
        do {
            let options = try CompilerOptions.parse(CommandLine.arguments)
            let catalogs = try options.catalogURLs.map {
                try Data(contentsOf: $0)
            }
            let overlay = try options.overlayURL.map {
                try Data(contentsOf: $0)
            }
            let promotion = try options.promotionURL.map {
                try Data(contentsOf: $0)
            }
            let compiler = RuleSourceCompiler()
            let artifact: CompiledRuleArtifact
            if catalogs.count == 1, options.catalogVersion == nil {
                artifact = try compiler.compile(
                    catalogData: catalogs[0],
                    overlayData: overlay,
                    promotionData: promotion
                )
            } else {
                guard let catalogVersion = options.catalogVersion else {
                    throw CompilerCommandError.invalidArguments
                }
                artifact = try compiler.compile(
                    catalogSources: catalogs,
                    catalogVersion: catalogVersion,
                    overlayData: overlay,
                    promotionData: promotion
                )
            }
            let coverageOutput: (data: Data, url: URL)?
            if let coverageURL = options.coverageURL,
               let coverageManifestURL = options.coverageManifestURL
            {
                let coverage = try Data(contentsOf: coverageURL)
                let coverageManifest = try RuleCoverageCompiler().compile(
                    coverageData: coverage,
                    catalog: artifact.catalog
                )
                coverageOutput = (
                    try JSONEncoder.sorted.encode(coverageManifest),
                    coverageManifestURL
                )
            } else {
                coverageOutput = nil
            }
            let executionProfileOutput: (
                data: Data,
                manifest: Data,
                dataURL: URL,
                manifestURL: URL
            )?
            if let profileURL = options.executionProfileURL,
               let outputURL = options.executionProfileOutputURL,
               let manifestURL = options.executionProfileManifestURL
            {
                let profileArtifact = try ExecutionProfileCompiler().compile(
                    profileData: Data(contentsOf: profileURL),
                    ruleCatalog: artifact.catalog
                )
                executionProfileOutput = (
                    profileArtifact.data,
                    try JSONEncoder.sorted.encode(profileArtifact.manifest),
                    outputURL,
                    manifestURL
                )
            } else {
                executionProfileOutput = nil
            }
            try writeAtomically(artifact.data, to: options.outputURL)
            let manifest = try JSONEncoder.sorted.encode(artifact.manifest)
            try writeAtomically(manifest, to: options.manifestURL)
            if let coverageOutput {
                try writeAtomically(
                    coverageOutput.data,
                    to: coverageOutput.url
                )
            }
            if let executionProfileOutput {
                try writeAtomically(
                    executionProfileOutput.data,
                    to: executionProfileOutput.dataURL
                )
                try writeAtomically(
                    executionProfileOutput.manifest,
                    to: executionProfileOutput.manifestURL
                )
            }
            FileHandle.standardOutput.write(
                Data("\(artifact.sha256)\n".utf8)
            )
        } catch {
            FileHandle.standardError.write(
                Data("stornaut-rule-compiler failed: \(error)\n".utf8)
            )
            Foundation.exit(2)
        }
    }
}

private struct CompilerOptions {
    let catalogURLs: [URL]
    let catalogVersion: String?
    let overlayURL: URL?
    let promotionURL: URL?
    let coverageURL: URL?
    let executionProfileURL: URL?
    let outputURL: URL
    let manifestURL: URL
    let coverageManifestURL: URL?
    let executionProfileOutputURL: URL?
    let executionProfileManifestURL: URL?

    static func parse(_ arguments: [String]) throws -> Self {
        var catalogURLs: [URL] = []
        var catalogVersion: String?
        var overlayURL: URL?
        var promotionURL: URL?
        var coverageURL: URL?
        var executionProfileURL: URL?
        var outputURL: URL?
        var manifestURL: URL?
        var coverageManifestURL: URL?
        var executionProfileOutputURL: URL?
        var executionProfileManifestURL: URL?
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else {
                throw CompilerCommandError.invalidArguments
            }
            index += 1
            let value = arguments[index]
            switch flag {
            case "--catalog":
                catalogURLs.append(try absoluteURL(value))
            case "--catalog-version":
                guard catalogVersion == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                catalogVersion = value
            case "--overlay":
                guard overlayURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                overlayURL = try absoluteURL(value)
            case "--promotion":
                guard promotionURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                promotionURL = try absoluteURL(value)
            case "--coverage":
                guard coverageURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                coverageURL = try absoluteURL(value)
            case "--execution-profile":
                guard executionProfileURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                executionProfileURL = try absoluteURL(value)
            case "--output":
                guard outputURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                outputURL = try absoluteURL(value)
            case "--manifest":
                guard manifestURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                manifestURL = try absoluteURL(value)
            case "--coverage-manifest":
                guard coverageManifestURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                coverageManifestURL = try absoluteURL(value)
            case "--execution-profile-output":
                guard executionProfileOutputURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                executionProfileOutputURL = try absoluteURL(value)
            case "--execution-profile-manifest":
                guard executionProfileManifestURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                executionProfileManifestURL = try absoluteURL(value)
            default:
                throw CompilerCommandError.invalidArguments
            }
            index += 1
        }
        guard !catalogURLs.isEmpty,
              catalogURLs.count <= RuleSourceCompiler.maximumSourceCount,
              catalogURLs.count == 1 || catalogVersion != nil,
              (coverageURL == nil) == (coverageManifestURL == nil),
              (executionProfileURL == nil)
                == (executionProfileOutputURL == nil),
              (executionProfileURL == nil)
                == (executionProfileManifestURL == nil),
              promotionURL == nil || catalogVersion != nil,
              let outputURL,
              let manifestURL
        else {
            throw CompilerCommandError.invalidArguments
        }
        let sourcePaths = try [
            overlayURL,
            promotionURL,
            coverageURL,
            executionProfileURL,
        ].compactMap { $0 }.map(canonicalExistingPath)
            + catalogURLs.map(canonicalExistingPath)
        let destinationPaths = [
            outputURL,
            manifestURL,
            coverageManifestURL,
            executionProfileOutputURL,
            executionProfileManifestURL,
        ].compactMap { $0 }.map(canonicalDestinationPath)
        guard Set(sourcePaths + destinationPaths).count
                == sourcePaths.count + destinationPaths.count
        else {
            throw CompilerCommandError.invalidArguments
        }
        return Self(
            catalogURLs: catalogURLs,
            catalogVersion: catalogVersion,
            overlayURL: overlayURL,
            promotionURL: promotionURL,
            coverageURL: coverageURL,
            executionProfileURL: executionProfileURL,
            outputURL: outputURL,
            manifestURL: manifestURL,
            coverageManifestURL: coverageManifestURL,
            executionProfileOutputURL: executionProfileOutputURL,
            executionProfileManifestURL: executionProfileManifestURL
        )
    }
}

private func absoluteURL(_ value: String) throws -> URL {
    guard value.hasPrefix("/") else {
        throw CompilerCommandError.invalidArguments
    }
    return URL(filePath: value)
}

private func writeAtomically(_ data: Data, to url: URL) throws {
    let parent = url.deletingLastPathComponent()
    var information = stat()
    guard lstat(parent.path, &information) == 0,
          information.st_mode & S_IFMT == S_IFDIR
    else {
        throw CompilerCommandError.invalidOutputDirectory
    }
    var destination = stat()
    if lstat(url.path, &destination) == 0 {
        guard destination.st_mode & S_IFMT == S_IFREG,
              destination.st_uid == geteuid()
        else {
            throw CompilerCommandError.unsafeOutput
        }
    } else if errno != ENOENT {
        throw CompilerCommandError.unsafeOutput
    }
    try data.write(to: url, options: .atomic)
    guard chmod(url.path, 0o600) == 0 else {
        throw CompilerCommandError.unsafeOutput
    }
}

private func canonicalExistingPath(_ url: URL) throws -> String {
    guard let pointer = realpath(url.path, nil) else {
        throw CompilerCommandError.invalidArguments
    }
    defer { free(pointer) }
    return String(cString: pointer)
}

private func canonicalDestinationPath(_ url: URL) -> String {
    var information = stat()
    if lstat(url.path, &information) == 0 {
        return (try? canonicalExistingPath(url))
            ?? url.standardizedFileURL.path
    }
    let parent = url.deletingLastPathComponent()
    if let pointer = realpath(parent.path, nil) {
        defer { free(pointer) }
        return URL(filePath: String(cString: pointer))
            .appending(path: url.lastPathComponent)
            .path
    }
    return url.standardizedFileURL.path
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private enum CompilerCommandError: Error {
    case invalidArguments
    case invalidOutputDirectory
    case unsafeOutput
}
