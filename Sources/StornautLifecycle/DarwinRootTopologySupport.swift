import Darwin
import Foundation

struct LifecycleRootTopologySystemCallError:
    Error,
    Sendable,
    Equatable
{
    let errno: Int32

    init(errno: Int32) {
        self.errno = errno
    }
}

protocol LifecycleRootTopologyFileSystem: Sendable {
    func metadata(
        at url: URL
    ) -> Result<Void, LifecycleRootTopologySystemCallError>
}

struct DarwinRootTopologyFileSystem:
    LifecycleRootTopologyFileSystem,
    Sendable
{
    func metadata(
        at url: URL
    ) -> Result<Void, LifecycleRootTopologySystemCallError> {
        guard rootTopologyAbsoluteFileURL(url) else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: EINVAL)
            )
        }
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            return .failure(
                LifecycleRootTopologySystemCallError(errno: Darwin.errno)
            )
        }
        return .success(())
    }
}

struct DarwinRootTopologyArtifactAbsenceReader:
    LifecycleRootTopologyArtifactAbsenceReading,
    Sendable
{
    private let fileSystem: any LifecycleRootTopologyFileSystem

    init(
        fileSystem: any LifecycleRootTopologyFileSystem
            = DarwinRootTopologyFileSystem()
    ) {
        self.fileSystem = fileSystem
    }

    func observeAbsence(
        _ role: LifecycleRootTopologyArtifactRole,
        contract: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation {
        switch fileSystem.metadata(at: url(for: role, contract: contract)) {
        case .success:
            return .present
        case .failure(let error) where error.errno == ENOENT:
            return .absent
        case .failure:
            return .unavailable(
                reasonKey: "runtime.topology.lstat-unavailable"
            )
        }
    }

    private func url(
        for role: LifecycleRootTopologyArtifactRole,
        contract: LifecycleLocalInstallationContract
    ) -> URL {
        switch role {
        case .installedRoot:
            return contract.installedRootURL
        case .installedApp:
            return contract.installedAppURL
        case .appExecutable:
            return contract.appExecutableURL
        case .helperExecutable:
            return contract.helperExecutableURL
        case .machineDriverExecutable:
            return contract.machineDriverExecutableURL
        case .launchDaemonPlist:
            return contract.launchDaemonPlistURL
        case .runtimeRoot:
            return contract.runtimeRootURL
        case .leaseRoot:
            return contract.leaseRootURL
        }
    }
}

protocol LifecycleRootTopologyProcessIdentityReading: Sendable {
    func processIdentity(
        for processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError>
}

struct DarwinRootTopologyProcessIdentityReader:
    LifecycleRootTopologyProcessIdentityReading,
    Sendable
{
    private let inventory: DarwinLifecycleInventory

    init(inventory: DarwinLifecycleInventory = .init()) {
        self.inventory = inventory
    }

    func processIdentity(
        for processID: pid_t
    ) -> Result<LifecycleProcessIdentity, DarwinLifecycleSupportError> {
        do {
            return .success(try inventory.identity(for: processID))
        } catch let error as DarwinLifecycleSupportError {
            return .failure(error)
        } catch {
            return .failure(.invalidIdentity)
        }
    }
}

struct DarwinRootTopologyProcessAbsenceReader:
    LifecycleRootTopologyProcessAbsenceReading,
    Sendable
{
    private let identityReader:
        any LifecycleRootTopologyProcessIdentityReading

    init(
        identityReader: any LifecycleRootTopologyProcessIdentityReading
            = DarwinRootTopologyProcessIdentityReader()
    ) {
        self.identityReader = identityReader
    }

    func observeAbsence(
        of expectedIdentity: LifecycleProcessIdentity
    ) -> LifecycleRootTopologyProcessObservation {
        guard expectedIdentity.processID > 1 else {
            return .unresolved(
                reasonKey: "runtime.topology.invalid-process-id"
            )
        }
        switch identityReader.processIdentity(
            for: expectedIdentity.processID
        ) {
        case .failure(.identityUnavailable(let code)) where code == ESRCH:
            return .absent
        case .success(let identity)
        where identity.processID != expectedIdentity.processID:
            return .unresolved(
                reasonKey: "runtime.topology.process-identity-mismatch"
            )
        case .success(let identity) where identity == expectedIdentity:
            return .sameIdentityAlive
        case .success:
            return .identityReused
        case .failure:
            return .unresolved(
                reasonKey: "runtime.topology.process-identity-unavailable"
            )
        }
    }
}

private func rootTopologyAbsoluteFileURL(_ url: URL) -> Bool {
    url.isFileURL
        && url.path.hasPrefix("/")
        && !url.path.isEmpty
}
