import Foundation
import Testing
@testable import StornautCore

@Test(arguments: [
    ".ssh",
    ".gnupg",
    ".aws",
    ".kube",
    ".azure",
    ".config/gcloud",
    ".config/gh",
    ".config/op",
    ".config/1Password",
    ".config/Bitwarden",
    ".docker",
    "Library/Keychains",
    "Library/Mail",
    "Library/Messages",
    "Library/Photos/Libraries.photoslibrary",
    "Library/Safari",
    "Library/Application Support/1Password",
    "Library/Application Support/Bitwarden",
    "Library/Application Support/LastPass",
    "Library/Application Support/Google/Chrome",
    "Library/Application Support/Microsoft Edge",
    "Library/Application Support/BraveSoftware/Brave-Browser",
    "Library/Application Support/Arc/User Data",
    "Library/Application Support/Firefox/Profiles",
    "Pictures/Photos Library.photoslibrary",
])
func sensitivePathDenylistRejectsProtectedDirectories(_ relativePath: String) {
    let homeURL = URL(filePath: "/Users/example", directoryHint: .isDirectory)
    let denylist = SensitivePathDenylist(homeDirectoryURL: homeURL)

    #expect(
        denylist.evaluate(homeURL.appending(path: relativePath))
            == .denied(.sensitiveDirectory)
    )
}

@Test(arguments: [
    ".env",
    ".env.local",
    ".env.production",
    "service.env",
    ".netrc",
    ".npmrc",
    ".pypirc",
    ".vault-token",
    ".git-credentials",
    "credentials",
    "credentials.json",
    "credentials.tfrc.json",
    "application_default_credentials.json",
    "service-account.json",
    "secret.json",
    "secrets.json",
    "id_rsa",
    "id_ed25519",
    "private.key",
    "certificate.pem",
    "identity.p12",
])
func sensitivePathDenylistRejectsEnvironmentSecretFiles(_ filename: String) {
    let homeURL = URL(filePath: "/Users/example", directoryHint: .isDirectory)
    let denylist = SensitivePathDenylist(homeDirectoryURL: homeURL)

    #expect(
        denylist.evaluate(
            homeURL.appending(path: "Projects/app/\(filename)")
        ) == .denied(.secretFile)
    )
}

@Test
func sensitivePathDenylistUsesComponentAndUnicodeAwareComparisons() {
    let homeURL = URL(filePath: "/Users/example", directoryHint: .isDirectory)
    let denylist = SensitivePathDenylist(homeDirectoryURL: homeURL)

    #expect(
        denylist.evaluate(
            homeURL.appending(path: "Projects/.ssh-backup/README.md")
        ) == .allowed
    )
    #expect(
        denylist.evaluate(
            homeURL.appending(path: "Library/MAİL/message.emlx")
        ) == .denied(.sensitiveDirectory)
    )
}

@Test
func sensitivePathDenylistHasNoRuntimeOverride() {
    let publicInitializers = SensitivePathDenylist.publicConfigurationKeys

    #expect(publicInitializers.isEmpty)
}

@Test
func sensitivePathDenylistRejectsSecretsOutsideHomeWithoutPrefixConfusion() {
    let homeURL = URL(filePath: "/Users/example", directoryHint: .isDirectory)
    let denylist = SensitivePathDenylist(homeDirectoryURL: homeURL)

    #expect(
        denylist.evaluate(
            URL(filePath: "/Volumes/Work/project/.ssh/id_ed25519")
        ) == .denied(.sensitiveDirectory)
    )
    #expect(
        denylist.evaluate(
            URL(filePath: "/Volumes/Work/project/.env")
        ) == .denied(.secretFile)
    )
    #expect(
        denylist.evaluate(
            URL(filePath: "/Users/example-other/Library/Mail/message")
        ) == .allowed
    )
}
