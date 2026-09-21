import Darwin

protocol InvestigationMachineInstalledDriverSystem: Sendable {
    func installedManifestIdentity() throws
        -> InvestigationMachineInstalledManifestIdentity
    func processExecutablePath() throws -> String
    func hasTrustedAncestorChain() throws -> Bool
    func pathNode() throws
        -> InvestigationMachineInstalledDriverNodeIdentity
    func openExecutable() throws -> Int32
    func descriptorNode(
        _ descriptor: Int32
    ) throws -> InvestigationMachineInstalledDriverNodeIdentity
    func hasExtendedACL(_ descriptor: Int32) throws -> Bool
    func hasUnexpectedExtendedAttributes(_ descriptor: Int32) throws -> Bool
    func sha256(_ descriptor: Int32, size: Int64) throws -> String
    func staticSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    func liveSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    func close(_ descriptor: Int32) -> Bool
}

struct InvestigationMachineInstalledDriverSystemSource:
    InvestigationMachineInstalledDriverObservationSource,
    Sendable
{
    private let system: any InvestigationMachineInstalledDriverSystem

    init(system: any InvestigationMachineInstalledDriverSystem) {
        self.system = system
    }

    func readCandidate() throws
        -> InvestigationMachineInstalledDriverCandidate
    {
        do {
            let manifest = try system.installedManifestIdentity()
            let executablePath = try system.processExecutablePath()
            let hasTrustedAncestorChain =
                try system.hasTrustedAncestorChain()
            let initialNode = try system.pathNode()
            let descriptor = try system.openExecutable()
            let outcome: Result<
                InvestigationMachineInstalledDriverCandidate,
                any Error
            >
            do {
                let descriptorNode = try system.descriptorNode(descriptor)
                guard InvestigationMachineInstalledDriverObserver
                    .hasValidExecutableSize(descriptorNode.size)
                else {
                    throw InvestigationMachineInstalledDriverObservationError
                        .invalidObservation
                }
                let hasExtendedACL = try system.hasExtendedACL(descriptor)
                let hasUnexpectedExtendedAttributes =
                    try system.hasUnexpectedExtendedAttributes(descriptor)
                let executableSHA256 = try system.sha256(
                    descriptor,
                    size: descriptorNode.size
                )
                let staticSigning = try system.staticSigning()
                let liveSigning = try system.liveSigning()
                let finalHasExtendedACL =
                    try system.hasExtendedACL(descriptor)
                let finalHasUnexpectedExtendedAttributes =
                    try system.hasUnexpectedExtendedAttributes(descriptor)
                let finalManifest = try system.installedManifestIdentity()
                let finalHasTrustedAncestorChain =
                    try system.hasTrustedAncestorChain()
                let finalExecutablePath =
                    try system.processExecutablePath()
                let finalDescriptorNode =
                    try system.descriptorNode(descriptor)
                let finalNode = try system.pathNode()
                outcome = .success(
                    InvestigationMachineInstalledDriverCandidate(
                        executablePath: executablePath,
                        finalExecutablePath: finalExecutablePath,
                        hasTrustedAncestorChain: hasTrustedAncestorChain,
                        finalHasTrustedAncestorChain:
                            finalHasTrustedAncestorChain,
                        initialNode: initialNode,
                        descriptorNode: descriptorNode,
                        finalDescriptorNode: finalDescriptorNode,
                        finalNode: finalNode,
                        hasExtendedACL: hasExtendedACL,
                        finalHasExtendedACL: finalHasExtendedACL,
                        hasUnexpectedExtendedAttributes:
                            hasUnexpectedExtendedAttributes,
                        finalHasUnexpectedExtendedAttributes:
                            finalHasUnexpectedExtendedAttributes,
                        executableSHA256: executableSHA256,
                        staticSigning: staticSigning,
                        liveSigning: liveSigning,
                        manifest: manifest,
                        finalManifest: finalManifest
                    )
                )
            } catch {
                outcome = .failure(error)
            }
            guard system.close(descriptor) else {
                throw InvestigationMachineInstalledDriverObservationError
                    .sourceUnavailable
            }
            switch outcome {
            case let .success(candidate):
                return candidate
            case .failure:
                throw InvestigationMachineInstalledDriverObservationError
                    .sourceUnavailable
            }
        } catch {
            throw InvestigationMachineInstalledDriverObservationError
                .sourceUnavailable
        }
    }
}
