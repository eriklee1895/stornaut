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
            let compiler = RuleSourceCompiler()
            let artifact: CompiledRuleArtifact
            if catalogs.count == 1, options.catalogVersion == nil {
                artifact = try compiler.compile(
                    catalogData: catalogs[0],
                    overlayData: overlay
                )
            } else {
                guard let catalogVersion = options.catalogVersion else {
                    throw CompilerCommandError.invalidArguments
                }
                artifact = try compiler.compile(
                    catalogSources: catalogs,
                    catalogVersion: catalogVersion,
                    overlayData: overlay
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
            try writeAtomically(artifact.data, to: options.outputURL)
            let manifest = try JSONEncoder.sorted.encode(artifact.manifest)
            try writeAtomically(manifest, to: options.manifestURL)
            if let coverageOutput {
                try writeAtomically(
                    coverageOutput.data,
                    to: coverageOutput.url
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
    let coverageURL: URL?
    let outputURL: URL
    let manifestURL: URL
    let coverageManifestURL: URL?

    static func parse(_ arguments: [String]) throws -> Self {
        var catalogURLs: [URL] = []
        var catalogVersion: String?
        var overlayURL: URL?
        var coverageURL: URL?
        var outputURL: URL?
        var manifestURL: URL?
        var coverageManifestURL: URL?
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
            case "--coverage":
                guard coverageURL == nil else {
                    throw CompilerCommandError.invalidArguments
                }
                coverageURL = try absoluteURL(value)
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
            default:
                throw CompilerCommandError.invalidArguments
            }
            index += 1
        }
        guard !catalogURLs.isEmpty,
              catalogURLs.count <= RuleSourceCompiler.maximumSourceCount,
              catalogURLs.count == 1 || catalogVersion != nil,
              (coverageURL == nil) == (coverageManifestURL == nil),
              let outputURL,
              let manifestURL
        else {
            throw CompilerCommandError.invalidArguments
        }
        let sourcePaths = try [
            overlayURL,
            coverageURL,
        ].compactMap { $0 }.map(canonicalExistingPath)
            + catalogURLs.map(canonicalExistingPath)
        let destinationPaths = [
            outputURL,
            manifestURL,
            coverageManifestURL,
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
            coverageURL: coverageURL,
            outputURL: outputURL,
            manifestURL: manifestURL,
            coverageManifestURL: coverageManifestURL
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
