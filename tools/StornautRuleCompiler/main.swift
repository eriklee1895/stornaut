import Foundation
import RuleCompilerKit

@main
struct StornautRuleCompilerCommand {
    static func main() {
        do {
            let options = try CompilerOptions.parse(CommandLine.arguments)
            let catalog = try Data(contentsOf: options.catalogURL)
            let overlay = try options.overlayURL.map {
                try Data(contentsOf: $0)
            }
            let artifact = try RuleSourceCompiler().compile(
                catalogData: catalog,
                overlayData: overlay
            )
            try writeAtomically(artifact.data, to: options.outputURL)
            let manifest = try JSONEncoder.sorted.encode(artifact.manifest)
            try writeAtomically(manifest, to: options.manifestURL)
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
    let catalogURL: URL
    let overlayURL: URL?
    let outputURL: URL
    let manifestURL: URL

    static func parse(_ arguments: [String]) throws -> Self {
        var catalogURL: URL?
        var overlayURL: URL?
        var outputURL: URL?
        var manifestURL: URL?
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else {
                throw CompilerCommandError.invalidArguments
            }
            index += 1
            let value = arguments[index]
            guard value.hasPrefix("/") else {
                throw CompilerCommandError.invalidArguments
            }
            let url = URL(filePath: value)
            switch flag {
            case "--catalog":
                catalogURL = url
            case "--overlay":
                overlayURL = url
            case "--output":
                outputURL = url
            case "--manifest":
                manifestURL = url
            default:
                throw CompilerCommandError.invalidArguments
            }
            index += 1
        }
        guard let catalogURL, let outputURL, let manifestURL
        else {
            throw CompilerCommandError.invalidArguments
        }
        let sourcePaths = try [
            catalogURL,
            overlayURL,
        ].compactMap { $0 }.map(canonicalExistingPath)
        let destinationPaths = [
            outputURL,
            manifestURL,
        ].map(canonicalDestinationPath)
        guard Set(sourcePaths + destinationPaths).count
                == sourcePaths.count + destinationPaths.count
        else {
            throw CompilerCommandError.invalidArguments
        }
        return Self(
            catalogURL: catalogURL,
            overlayURL: overlayURL,
            outputURL: outputURL,
            manifestURL: manifestURL
        )
    }
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
