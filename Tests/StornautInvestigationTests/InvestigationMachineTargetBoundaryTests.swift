import Foundation
import Testing

@Suite("Task 39 trusted machine target boundary")
struct InvestigationMachineTargetBoundaryTests {
    @Test
    func concreteEntryRemainsPackageClosedNoAuthAndScopeBounded() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let boundaries = try String(
            contentsOf: root.appending(
                path: "scripts/verify-investigation-boundaries"),
            encoding: .utf8
        )
        let release = try String(
            contentsOf: root.appending(
                path: "scripts/verify-app-release-boundaries"),
            encoding: .utf8
        )
        let contract = try String(
            contentsOf: root.appending(path: "scripts/verify-contract"),
            encoding: .utf8
        )
        for marker in [
            "--iib3c-concrete-entry-contract-only",
            "--iib3c-staged-scope-contract-only",
            "ii-b3c concrete authority widened",
            "ii-b3c staged checkpoint paths drifted",
            "ii-b3c staged checkpoint budget drifted",
        ] {
            #expect(boundaries.contains(marker))
        }
        for marker in [
            "b3c_concrete_markers=(",
            "b3c_closed_images=(",
            "ii-b3c concrete entry missing from diagnostic Debug image",
            "ii-b3c concrete entry leaked into a closed image",
        ] {
            #expect(release.contains(marker))
        }
        for marker in [
            "b3c-public", "b3c-auth", "b3c-business-io",
            "b3c-digest", "b3c-peer-binding", "b3c-store",
            "for fixture in extra-path over-budget deleted-path",
            "b3c-$fixture.index",
        ] {
            #expect(contract.contains(marker))
        }
    }

    @Test
    func startRetireSeamRemainsPackageClosedAndUnreachable() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let transport = try String(
            contentsOf: root.appending(path:
                "Sources/StornautInvestigationRuntime/InvestigationLifecycleAppServerTransport.swift"),
            encoding: .utf8
        )
        let boundaries = try String(
            contentsOf: root.appending(
                path: "scripts/verify-investigation-boundaries"),
            encoding: .utf8
        )
        let release = try String(
            contentsOf: root.appending(
                path: "scripts/verify-app-release-boundaries"),
            encoding: .utf8
        )
        let contract = try String(
            contentsOf: root.appending(path: "scripts/verify-contract"),
            encoding: .utf8
        )
        #expect(transport.contains(
            "package func startAndRetireWithEvidence() async throws"))
        #expect(!transport.contains(
            "public func startAndRetireWithEvidence() async throws"))
        for marker in [
            "--iib3b-start-retire-contract-only",
            "--iib3b-staged-scope-contract-only",
            "start-retire seam gained prohibited surface",
            "ii-b3b staged checkpoint paths drifted",
            "ii-b3b staged checkpoint budget drifted",
        ] {
            #expect(boundaries.contains(marker))
        }
        for marker in [
            "start_retire_seam_forbidden_markers=(",
            "start_retire_seam_closed_images=(",
            "Start-retire seam leaked into a closed image",
        ] {
            #expect(release.contains(marker))
        }
        for marker in [
            "start-retire-public", "start-retire-write",
            "start-retire-caller-cleanup",
            "start-retire-forwarding",
            "start-retire-comment-brace",
            "start-retire-alias",
            "start-retire-backtick",
            "for fixture in extra-path over-budget deleted-path",
            "start-retire-$fixture.index",
        ] {
            #expect(contract.contains(marker))
        }
    }

    @Test
    func appPeerAdmissionReturnsOnlyPackageScopedStableObservation() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(
                path: "Sources/StornautLifecycle/LifecycleAppAuthorization.swift"
            ),
            encoding: .utf8
        )
        let boundaries = try String(
            contentsOf: root.appending(
                path: "scripts/verify-investigation-boundaries"
            ),
            encoding: .utf8
        )
        for marker in [
            "package struct LifecycleMachineDriverPeerAdmissionEvidence",
            "package func authorizeAndObserveStableEvidence(",
            "authorizeAndObserveStableEvidence(identity) != nil",
            "This is current-peer evidence, not installer-authenticated provenance.",
            "signingEvidence: staticEvidence",
            "--app-peer-admission-contract-only",
        ] {
            #expect(source.contains(marker) || boundaries.contains(marker))
        }
        #expect(!source.contains(
            "public struct LifecycleMachineDriverPeerAdmissionEvidence"
        ))
        #expect(!source.contains("expectedExecutableSHA256"))
    }

    @Test
    func liveClaimServerLinksOnlyTheHelperAndFreezesTheArtifactMatrix() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: root.appending(
                path: "Stornaut.xcodeproj/project.pbxproj"
            ),
            encoding: .utf8
        )
        #expect(
            project.components(
                separatedBy: "productName = StornautInvestigationMachineClaimServer;"
            ).count == 2
        )
        #expect(
            project.components(
                separatedBy: "StornautInvestigationMachineClaimServer in Frameworks"
            ).count == 3
        )
        let helperStart = try #require(
            project.range(
                of: "A00000000000000000000004 /* StornautLifecycleHelper */ = {"
            )
        )
        let helperSuffix = project[helperStart.lowerBound...]
        let helperEnd = try #require(
            helperSuffix.range(of: "\n\t\t};")
        )
        let helper = String(helperSuffix[..<helperEnd.upperBound])
        #expect(helper.contains("StornautInvestigationMachineClaimServer"))
        #expect(
            project.components(
                separatedBy: "/* StornautInvestigationMachineClaimServer */"
            ).count == 4
        )

        let release = try String(
            contentsOf: root.appending(
                path: "scripts/verify-app-release-boundaries"
            ),
            encoding: .utf8
        )
        let boundaries = try String(
            contentsOf: root.appending(
                path: "scripts/verify-investigation-boundaries"
            ),
            encoding: .utf8
        )
        let contract = try String(
            contentsOf: root.appending(path: "scripts/verify-contract"),
            encoding: .utf8
        )
        for marker in [
            "helper claim-server Mach-O positive drifted",
            "non-helper claim-server Mach-O leakage",
            "claim-server two-selector surface drifted",
        ] {
            #expect(release.contains(marker))
        }
        for marker in [
            "live claim server helper-only linkage drifted",
            "StornautInvestigationMachineClaimServer in Frameworks",
            "live claim server public extension drifted",
            "iii-b-ii checkpoint paths drifted",
            "iii-b-ii checkpoint budget drifted",
            "live claim server physical clock drifted",
            "live claim server physical scheduler drifted",
            "live claim server physical terminal drifted",
            "claim server physical terminal authority drifted",
            "live claim server helper physical composition drifted",
            "live claim server helper retained physical adapter",
        ] {
            #expect(boundaries.contains(marker))
        }
        for marker in [
            "helper-claim-server-linkage",
            "helper-claim-server-positive",
            "non-helper-claim-server-leak",
            "live-claim-server-public-extension",
            "live-claim-server-admission-order",
            "live-claim-server-physical-clock",
            "live-claim-server-physical-scheduler",
            "live-claim-server-physical-terminal",
            "live-claim-server-helper-composition",
            "claim-server-terminal-authority",
        ] {
            #expect(contract.contains(marker))
        }
        for marker in [
            "claim_server_module_symbols=(",
            "for marker in \"${claim_server_module_symbols[@]}\"",
        ] {
            #expect(release.contains(marker))
        }
    }

    @Test
    func machineClaimServerOwnsStrictTypedStateTranslationOnly() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let adapter = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerAdapter.swift"
            ),
            encoding: .utf8
        )
        let effects = try String(
            contentsOf: root.appending(
                path: "Sources/StornautInvestigationMachineClaimServer/InvestigationMachineClaimServerEffects.swift"
            ),
            encoding: .utf8
        )
        let deadlineState = try String(
            contentsOf: root.appending(
                path: "Sources/StornautLifecycle/LifecycleMachineRetirementEscrowDeadlineState.swift"
            ),
            encoding: .utf8
        )

        #expect(adapter.contains(
            "package final class InvestigationMachineClaimServerAdapter:"
        ))
        #expect(adapter.contains(
            "transfer: LifecycleMachineRetirementReservationTransfer"
        ))
        #expect(!adapter.contains(
            "InvestigationMachineClaimServerReservationSeed"
        ))
        #expect(adapter.contains(
            "LifecycleInteractiveWorkerRetirementObservation"
        ))
        #expect(adapter.contains(
            "LifecycleInvestigationResidueObservation"
        ))
        #expect(adapter.contains("transfer.ownerRetirementObservation"))
        #expect(adapter.contains("transfer.residueObservation"))
        #expect(adapter.contains(
            "transfer.validBeforeUTCMicroseconds"
        ))
        #expect(!adapter.contains(
            "transfer.validBefore.timeIntervalSince1970"
        ))
        #expect(!adapter.contains(
            "LifecycleMachineRetirementReservationTransfer("
        ))
        #expect(!adapter.contains(
            "expectedReleaseChallenge: release.releaseChallenge"
        ))
        #expect(adapter.contains("state.commitClaimResponse("))
        #expect(adapter.contains("state.commitReleaseResponse("))
        #expect(adapter.contains("private let evidenceLock = NSLock()"))
        #expect(effects.contains("callbackFinished"))
        for marker in [
            "InvestigationMachineClaimServerPhysicalClock",
            "InvestigationMachineClaimServerPhysicalScheduler",
            "InvestigationMachineClaimServerPhysicalTerminal",
            "DarwinInvestigationMachineClaimServerPhysicalClockSource",
            "ContinuousInvestigationMachineClaimServerTaskFactory",
            "DarwinInvestigationMachineClaimServerPhysicalTerminalAction",
        ] {
            #expect(effects.contains(marker))
        }
        let armTransition = try #require(
            effects.range(of: "let armed = state.armSucceeded(ticket)")
        )
        let handleInstall = try #require(
            effects.range(of: "perform(slot.install(handle), ticket: ticket)")
        )
        #expect(armTransition.lowerBound < handleInstall.lowerBound)
        #expect(deadlineState.contains(
            "package func rejectOperationObservation("
        ))
    }

    @Test
    func handoffContractTargetRemainsAuthorityFreeAndNonProduct() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(
            contentsOf: root.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let marker = ".target(\n            name: \"StornautInvestigationHandoffContract\""
        let start = try #require(package.range(of: marker))
        let suffix = package[start.lowerBound...]
        let end = try #require(suffix.range(of: "\n        ),"))
        let target = String(suffix[..<end.upperBound])
        #expect(target.contains("dependencies: []"))
        #expect(
            package.components(
                separatedBy: "\"StornautInvestigationHandoffContract\""
            ).count == 6
        )

        let sourceRoot = root.appending(path: "Sources/StornautInvestigationHandoffContract")
        let names = try Set(FileManager.default.contentsOfDirectory(atPath: sourceRoot.path))
        #expect(names == [
            "HandoffBinaryTranscript.swift",
            "InvestigationCohortCapsuleContract.swift",
            "InvestigationHandoffEpochBootstrapContract.swift",
            "InvestigationHandoffFrameContract.swift",
            "InvestigationInstalledL2ProjectionContract.swift",
            "InvestigationMachineClaimContract.swift",
        ])
        for name in names {
            let source = try String(
                contentsOf: sourceRoot.appending(path: name),
                encoding: .utf8
            )
            if name == "InvestigationMachineClaimContract.swift" {
                #expect(
                    source.components(separatedBy: "public " ).count == 2
                )
                #expect(source.contains(
                    "public protocol InvestigationMachineClaimXPCWire"
                ))
                #expect(source.contains(
                    "@objc(StornautInvestigationMachineClaimXPCWire)"
                ))
            } else {
                #expect(!source.contains("public "))
            }
            for forbidden in [
                    "NSXPCConnection", "NSXPCListener", "Timer(",
                    "DispatchSource", "DispatchQueue", "RunLoop",
                    "Task.sleep", "Task.detached", "ContinuousClock",
                    "SuspendingClock", "Date()", "Date.now",
                    "CFAbsoluteTimeGetCurrent",
                    "ProcessInfo.processInfo.systemUptime",
                    "mach_continuous_time", "mach_wait_until",
                    "nanosleep(", "usleep(", "sleep(",
                    "clock_gettime", "gettimeofday", "mach_absolute_time",
                    "FileHandle", "InputStream", "OutputStream",
                    "FileWrapper", "NSData", "Data(contentsOf:",
                    "String(contentsOf:", ".write(to:",
                    "Darwin.open", "Darwin.read", "pread(",
                    "stat(", "lstat(", "fstat(", "readlink(",
                    "opendir(", "readdir(", "closedir(",
                    "NSLock", "actor ", "class ", "static var ",
                    "import Security",
            ] {
                #expect(!source.contains(forbidden))
            }
            for forbidden in ["Codable", "NSXPC", "Process(", "FileManager", "URLSession", "posix_spawn", "Darwin.write", "O_WRONLY", "import Stornaut"] {
                #expect(!source.contains(forbidden))
            }
        }
    }

    private func l3c3biiSource(
        _ path: String,
        repositoryRoot: URL
    ) throws -> String {
        try String(
            contentsOf: repositoryRoot.appending(path: path),
            encoding: .utf8
        )
    }

    private func l3c3biiFunction(
        _ name: String,
        in source: String
    ) throws -> String {
        let starts = [
            "\(name)() {",
            "function \(name)() {",
        ].compactMap { source.range(of: $0) }
        let start = try #require(
            starts.min(by: { $0.lowerBound < $1.lowerBound })
        )
        let suffix = source[start.lowerBound...]
        let end = try #require(suffix.range(of: "\n}\n"))
        return String(suffix[..<end.upperBound])
    }

    private func l3c3biiCaseArm(
        _ label: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: "\n    \(label))"))
        let suffix = source[start.lowerBound...]
        let end = try #require(suffix.range(of: ";;"))
        return String(suffix[..<end.upperBound])
    }

    private func l3c3biiFunction(
        containing marker: String,
        in source: String
    ) throws -> String {
        let markerRange = try #require(source.range(of: marker))
        let expression = try NSRegularExpression(
            pattern:
                #"(?m)^(?:function[ \t]+)?[A-Za-z_][A-Za-z0-9_]*\(\)[ \t]+\{"#
        )
        let prefixRange = NSRange(
            source.startIndex..<markerRange.lowerBound,
            in: source
        )
        let match = try #require(
            expression.matches(in: source, range: prefixRange).last
        )
        let start = try #require(Range(match.range, in: source))
        let suffix = source[start.lowerBound...]
        let end = try #require(suffix.range(of: "\n}\n"))
        return String(suffix[..<end.upperBound])
    }

    private func l3c3biiFlattened(_ source: String) -> String {
        source
            .replacingOccurrences(of: "\\\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func l3c3biiRequireOrder(
        _ markers: [String],
        in source: String
    ) throws {
        var cursor = source.startIndex
        for marker in markers {
            let range = try #require(
                source.range(of: marker, range: cursor..<source.endIndex)
            )
            cursor = range.upperBound
        }
    }

    @Test
    func driverRuntimeRemainsAuthorityClosedForNativePackaging() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageSource = try String(
            contentsOf: repositoryRoot.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let supportURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachineDriverSupport/"
                + "InvestigationMachineDriverSupport.swift"
        )
        let supportRoot = supportURL.deletingLastPathComponent()
        let supportSourceNames = try Set(
            FileManager.default.contentsOfDirectory(
                atPath: supportRoot.path
            ).filter { $0.hasSuffix(".swift") }
        )
        #expect(supportSourceNames == [
            "DarwinInvestigationMachineInstalledDriverSystem.swift",
            "InvestigationMachineClaimClient.swift",
            "InvestigationMachineDriverSupport.swift",
            "InvestigationMachineInstalledDriverObservation.swift",
            "InvestigationMachineInstalledDriverSystemSource.swift",
            "InvestigationMachineSingleEpoch.swift",
        ])
        #expect(FileManager.default.fileExists(atPath: supportURL.path))
        let supportSource = try String(
            contentsOf: supportURL,
            encoding: .utf8
        )
        for marker in [
            "import Darwin",
            "public enum InvestigationMachineDriverSupport",
            "package static let rootAuthorityRequiredExitStatus: Int32 = 77",
            "package static let handoffUnavailableExitStatus: Int32 = 78",
            "public static func run() async -> Int32",
            "static func status(effectiveUserID: uid_t) -> Int32",
        ] {
            #expect(supportSource.contains(marker))
        }
        for forbidden in [
            "StornautCore",
            "StornautInvestigation",
            "StornautLifecycle",
            "StornautExecution",
            "Cleanup",
            "Policy",
            "RegisteredAction",
            "Process(",
            "posix_spawn",
            "CommandLine.arguments",
            "ProcessInfo.processInfo.environment",
            "NSXPC",
            "URLSession",
            "readLine(",
            "FileManager.default.",
            "FileHandle(forWritingTo:",
            "O_WRONLY",
            "O_RDWR",
            "O_CREAT",
            "Darwin.write(",
            "unlink(",
            "rename(",
            "mkdir(",
            "chmod(",
            "chown(",
            "socket",
            "connect",
            "send(",
            "recv(",
            "kill(",
        ] {
            #expect(!supportSource.contains(forbidden))
        }
        #expect(!supportSource.contains("package static func status"))
        #expect(!supportSource.contains("public static func status"))
        #expect(
            supportSource.components(separatedBy: "public static " ).count
                == 2
        )

        let supportTargetStart = try #require(packageSource.range(
            of: ".target(\n            name: \"StornautInvestigationMachineDriverSupport\""
        ))
        let supportTargetSuffix = packageSource[
            supportTargetStart.lowerBound...
        ]
        let supportTargetEnd = try #require(
            supportTargetSuffix.range(of: "\n        ),")
        )
        let supportTarget = String(
            supportTargetSuffix[..<supportTargetEnd.upperBound]
        )
        #expect(supportTarget.contains("dependencies: ["))
        #expect(supportTarget.contains(
            "\"StornautInvestigationHandoffContract\""
        ))
        #expect(supportTarget.contains(
            ".linkedFramework(\"Security\")"
        ))

        let expectedImports: [String: Set<String>] = [
            "DarwinInvestigationMachineInstalledDriverSystem.swift": [
                "import CryptoKit",
                "import Darwin",
                "import Foundation",
                "import Security",
            ],
            "InvestigationMachineDriverSupport.swift": ["import Darwin"],
            "InvestigationMachineClaimClient.swift": [
                "import CryptoKit",
                "import Darwin",
                "import Foundation",
                "import Security",
                "import StornautInvestigationHandoffContract",
            ],
            "InvestigationMachineInstalledDriverObservation.swift": [
                "import Darwin",
            ],
            "InvestigationMachineInstalledDriverSystemSource.swift": [
                "import Darwin",
            ],
            "InvestigationMachineSingleEpoch.swift": [
                "import Foundation",
                "import StornautInvestigationHandoffContract",
            ],
        ]
        for sourceName in supportSourceNames {
            let source = try String(
                contentsOf: supportRoot.appending(path: sourceName),
                encoding: .utf8
            )
            let imports = Set(
                source.split(separator: "\n").map(String.init).filter {
                    $0.hasPrefix("import ")
                }
            )
            let expectedSourceImports = try #require(
                expectedImports[sourceName]
            )
            #expect(imports == expectedSourceImports)
            for forbidden in [
                "import StornautCore",
                "import StornautExecution",
                "import StornautInvestigation",
                "import StornautLifecycle",
                "Cleanup",
                "Policy",
                "Trash",
                "Executor",
                "RegisteredAction",
                "FileManager.default",
                "FileHandle",
                "O_WRONLY",
                "O_RDWR",
                "O_CREAT",
                "O_TRUNC",
                "O_APPEND",
                "Darwin.write",
                "pwrite",
                "unlink(",
                "rename(",
                "mkdir(",
                "chmod(",
                "chown(",
                "chflags(",
                "setxattr",
                "removexattr",
                "acl_set",
                "Process(",
                "OutputStream(",
                "posix_spawn",
                "setuid(",
                "seteuid(",
                "setreuid(",
                "setresuid(",
                "setgid(",
                "setegid(",
                "setregid(",
                "setresgid(",
                "initgroups(",
                "setgroups(",
                "setlogin(",
                "pthread_setugid_np(",
                "setsid(",
                "setpgid(",
                "daemon(",
                "chdir(",
                "fchdir(",
                "chroot(",
                "umask(",
                "nice(",
                "setpriority(",
                "setrlimit(",
                "fork(",
                "vfork(",
                "execv",
                "execl",
                "system(",
                "popen(",
                "dlopen(",
                "dlsym(",
                "syscall(",
                "fcntl(",
                "ioctl(",
                "mmap(",
                "msync(",
                "openat(",
                "creat(",
                "mkstemp(",
                "mkdtemp(",
                "unlinkat(",
                "renameat(",
                "mkdirat(",
                "ftruncate(",
                "fchmod(",
                "fchown(",
                "fchflags(",
                "lchflags(",
                "linkat(",
                "symlinkat(",
                "utime(",
                "utimes(",
                "futimes(",
                "setattrlist(",
                "fsetattrlist(",
                "copyfile(",
                "fcopyfile(",
                "clonefile(",
                "socketpair",
                "bind(",
                "listen(",
                "accept(",
                "accept4(",
                "getaddrinfo(",
                "CFStream",
                "InputStream(",
                "NWConnection",
                "WebSocket",
                "URLSession",
                "kill(",
                "killpg(",
                "pthread_kill(",
                "raise(",
                "CommandLine.arguments",
                "ProcessInfo.processInfo.environment",
                "readLine(",
                "signedInvestigationRuntimeReady",
            ] {
                let semanticException = (sourceName == "InvestigationMachineClaimClient.swift" && ["connect(", "import StornautInvestigation"].contains(forbidden))
                    || (sourceName == "InvestigationMachineSingleEpoch.swift" && ["send(", "import StornautInvestigation"].contains(forbidden))
                if !semanticException {
                    #expect(!source.contains(forbidden))
                }
            }
            if sourceName != "InvestigationMachineClaimClient.swift" {
                #expect(!source.contains("NSXPC"))
            } else {
                #expect(source.contains("NSXPCConnection"))
                #expect(source.contains("setCodeSigningRequirement"))
                #expect(!source.split(separator: "\n").contains(
                    "import StornautInvestigation"
                ))
                #expect(!source.contains("kill("))
            }
            if sourceName
                == "DarwinInvestigationMachineInstalledDriverSystem.swift"
            {
                let openCalls = source.matches(
                    of: /\b(?:Darwin\.)?open\s*\(/
                )
                #expect(openCalls.count == 2)
                for path in ["Self.path", "Self.manifestPath"] {
                    #expect(source.contains(
                        "let descriptor = open(\n"
                            + "            \(path),\n"
                            + "            O_RDONLY | O_CLOEXEC | "
                            + "O_NOFOLLOW_ANY | O_UNIQUE | O_NONBLOCK\n"
                            + "        )"
                    ))
                }
                let allowedSecuritySymbols: Set<String> = [
                    "SecCSFlags",
                    "SecCode",
                    "SecCodeCheckValidity",
                    "SecCodeCopySelf",
                    "SecCodeCopySigningInformation",
                    "SecCodeCopyStaticCode",
                    "SecRequirement",
                    "SecRequirementCopyData",
                    "SecRequirementGetTypeID",
                    "SecStaticCode",
                    "SecStaticCodeCheckValidity",
                    "SecStaticCodeCreateWithPath",
                    "kSecCSRequirementInformation",
                    "kSecCSSigningInformation",
                    "kSecCSStrictValidate",
                    "kSecCodeInfoDesignatedRequirement",
                    "kSecCodeInfoFlags",
                    "kSecCodeInfoIdentifier",
                    "kSecCodeInfoUnique",
                ]
                let observedSecuritySymbols = Set(
                    source.matches(
                        of: /\b(?:(?:Sec|kSec)[A-Z]|Authorization|CSSM)[A-Za-z0-9_]*\b/
                    )
                        .map { String($0.output) }
                )
                #expect(observedSecuritySymbols == allowedSecuritySymbols)
            } else {
                #expect(source.matches(
                    of: /\b(?:Darwin\.)?open\s*\(/
                ).isEmpty)
            }
        }

        let driverTargetStart = try #require(packageSource.range(
            of: ".executableTarget(\n            name: \"StornautInvestigationMachineDriver\""
        ))
        let driverTargetSuffix = packageSource[driverTargetStart.lowerBound...]
        let driverTargetEnd = try #require(
            driverTargetSuffix.range(of: "\n        ),")
        )
        let driverTarget = String(
            driverTargetSuffix[..<driverTargetEnd.upperBound]
        )
        #expect(driverTarget.contains(
            "\"StornautInvestigationMachineDriverSupport\""
        ))
        #expect(!driverTarget.contains("\"StornautInvestigationMachine\""))

    }

    @Test
    func iiB4VerifierPinsDriverSupportMarkersWithoutReplacingHistoricalGate()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let boundaries = try String(
            contentsOf: repositoryRoot.appending(
                path: "scripts/verify-investigation-boundaries"
            ),
            encoding: .utf8
        )
        for marker in [
            "--iib4-driver-support-contract-only <package-manifest> <client-source>",
            "--iib4-staged-scope-contract-only [baseline]",
            "ii-b4 driver support source contains comment camouflage",
            "ii-b4 driver support package dependency drifted",
            "ii-b4 fixed helper service drifted",
            "ii-b4 static/dynamic audit-token binding drifted",
            "ii-b4 delayed invalidation drifted",
            "ii-b4 helper absence handling drifted",
            "ii-b4 outcomeUnknown priority drifted",
            "ii-b4 broad lifecycle machine-claim client remains",
            "ii-b4 driver support regained prohibited authority",
            "ii-b4 checkpoint paths drifted",
            "ii-b4 checkpoint budget drifted",
            "ii-b4 staged checkpoint deleted a required path",
        ] {
            #expect(boundaries.contains(marker))
        }
    }

    @Test
    func iiB5A0VerifierPinsClaimAbortWithoutReplacingIIB4Gate() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let boundaries = try String(
            contentsOf: repositoryRoot.appending(
                path: "scripts/verify-investigation-boundaries"
            ), encoding: .utf8
        )
        let contract = try String(
            contentsOf: repositoryRoot.appending(path: "scripts/verify-contract"),
            encoding: .utf8
        )
        for marker in [
            "--iib5a0-claim-abort-contract-only <client-source>",
            "--iib5a0-staged-scope-contract-only [baseline]",
            "ii-b5a0 canonical client source drifted",
            "ii-b5a0 dependency surface drifted",
            "ii-b5a0 regained physical authority",
            "ii-b5a0 checkpoint paths drifted", "ii-b5a0 checkpoint budget drifted",
            "ii-b5a0 staged checkpoint deleted a required path",
        ] {
            #expect(boundaries.contains(marker))
        }
        for marker in [
            "alias-release", "alias-connect", "string-invalidation",
            "for fixture in extra-path over-budget deleted-path",
            "--iib4-staged-scope-contract-only \"$iib4_parent\"",
        ] {
            #expect(contract.contains(marker))
        }
        #expect(boundaries.contains(
            "--iib4-driver-support-contract-only <package-manifest> <client-source>"
        ))
        #expect(boundaries.contains("(( changed <= 800 ))"))
    }

    @Test func iiB5AVerifierPinsTypedComposerWithoutProductionReachability() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = try ["scripts/verify-investigation-boundaries", "scripts/verify-contract"].map {
            try String(contentsOf: root.appending(path: $0), encoding: .utf8)
        }
        for marker in [
            "--iib5a-single-epoch-contract-only <composer-source> <focused-test-source>", "--iib5a-staged-scope-contract-only [baseline]",
            "label = \"composer\" if path == composer_path else \"focused test\"", "ii-b5a canonical {label} source drifted", "ii-b5a checkpoint paths drifted",
            "ii-b5a checkpoint budget drifted",
        ] { #expect(sources[0].contains(marker)) }
        for marker in [
            "iib5a0_commit=953d149", "iib5a_commit=43a2c83", "sender-resample", "post-await-cancel",
        ] { #expect(sources[1].contains(marker)) }
    }

    @Test func iiB5BIAProjectionVerifierPinsPureBinaryAndTemporalContract() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = try ["scripts/verify-investigation-boundaries", "scripts/verify-contract"].map {
            try String(contentsOf: root.appending(path: $0), encoding: .utf8)
        }
        for marker in [
            "--iib5bia-projection-contract-only <contract-source> <focused-test-source>",
            "--iib5bia-staged-scope-contract-only [baseline]",
            "ii-b5b-i-a canonical {label} source drifted", "ii-b5b-i-a checkpoint budget drifted",
        ] { #expect(sources[0].contains(marker)) }
        for marker in [
            "codable:'ii-b5b-i-a", "projection-epoch:'ii-b5b-i-a",
            "claim-projection:'ii-b5b-i-a", "cross-clock:'ii-b5b-i-a",
            "digest-bypass:'ii-b5b-i-a",
        ] {
            #expect(sources[1].contains(marker))
        }
    }

    @Test
    func nativeMachineDriverPackagingIsDiagnosticOnly() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Stornaut.xcodeproj/project.pbxproj"
            ),
            encoding: .utf8
        )
        let diagnosticScheme = try String(
            contentsOf: repositoryRoot.appending(
                path: "Stornaut.xcodeproj/xcshareddata/xcschemes/"
                    + "StornautInvestigationDiagnosticApp.xcscheme"
            ),
            encoding: .utf8
        )
        let ordinaryScheme = try String(
            contentsOf: repositoryRoot.appending(
                path: "Stornaut.xcodeproj/xcshareddata/xcschemes/"
                    + "Stornaut.xcscheme"
            ),
            encoding: .utf8
        )

        func objectBlock(
            id: String,
            comment: String,
            in source: String
        ) throws -> String {
            let marker = "\(id) /* \(comment) */ = {"
            let start = try #require(source.range(of: marker))
            let suffix = source[start.lowerBound...]
            let end = try #require(suffix.range(of: "\n\t\t};"))
            return String(suffix[..<end.upperBound])
        }

        func objectLine(
            containing marker: String,
            in source: String
        ) throws -> String {
            let range = try #require(source.range(of: marker))
            return String(source[source.lineRange(for: range)])
        }

        #expect(
            projectSource.components(
                separatedBy: "isa = PBXNativeTarget;"
            ).count == 9
        )
        #expect(
            projectSource.components(
                separatedBy:
                    "name = StornautInvestigationMachineDriverNative;"
            ).count == 2
        )
        #expect(
            projectSource.components(
                separatedBy:
                    "name = StornautInvestigationDiagnosticReleaseShell;"
            ).count == 2
        )
        let driverTarget = try objectBlock(
            id: "A00000000000000000000007",
            comment: "StornautInvestigationMachineDriverNative",
            in: projectSource
        )
        for marker in [
            "productName = StornautInvestigationMachineDriver;",
            "productType = \"com.apple.product-type.tool\";",
            "StornautInvestigationMachineDriverSupport",
            "B00000000000000000000026 /* Sources */",
            "B00000000000000000000027 /* Frameworks */",
        ] {
            #expect(driverTarget.contains(marker))
        }
        for forbidden in [
            "StornautInvestigationMachine ",
            "StornautCore",
            "StornautCodex",
            "StornautLifecycle",
            "StornautInvestigationRuntime",
            "StornautInvestigationDiagnostic",
            "StornautExecution",
            "fileSystemSynchronizedGroups",
        ] {
            #expect(!driverTarget.contains(forbidden))
        }

        let releaseShellTarget = try objectBlock(
            id: "A00000000000000000000008",
            comment: "StornautInvestigationDiagnosticReleaseShell",
            in: projectSource
        )
        for marker in [
            "B00000000000000000000029 /* Sources */",
            "B00000000000000000000028 /* Frameworks */",
            "B00000000000000000000035 /* Resources */",
            "dependencies = (\n\t\t\t);",
            "packageProductDependencies = (\n\t\t\t);",
            "productName = StornautInvestigationDiagnosticReleaseShell;",
        ] {
            #expect(releaseShellTarget.contains(marker))
        }
        for forbidden in [
            "PBXTargetDependency",
            "Copy Investigation",
            "StornautInvestigationDiagnostic in Frameworks",
            "StornautInvestigationMachineDriver",
            "StornautLifecycleHelper",
        ] {
            #expect(!releaseShellTarget.contains(forbidden))
        }
        let releaseShellSources = try objectBlock(
            id: "B00000000000000000000029",
            comment: "Sources",
            in: projectSource
        )
        #expect(releaseShellSources.contains(
            "B0000000000000000000001E "
                + "/* InvestigationRuntimeDiagnosticHarness.swift in Sources */"
        ))
        #expect(
            releaseShellSources.components(
                separatedBy: " in Sources */"
            ).count == 2
        )
        for (id, comment) in [
            ("B00000000000000000000028", "Frameworks"),
            ("B00000000000000000000035", "Resources"),
        ] {
            let phase = try objectBlock(
                id: id,
                comment: comment,
                in: projectSource
            )
            #expect(phase.contains("files = (\n\t\t\t);"))
        }
        #expect(
            projectSource.components(
                separatedBy:
                    "fileRef = D00000000000000000000009 "
                        + "/* InvestigationRuntimeDiagnosticHarness.swift */;"
            ).count == 3
        )
        let diagnosticConfigurationList = try objectBlock(
            id: "A00000000000000000000025",
            comment:
                "Build configuration list for PBXNativeTarget "
                    + "\"StornautInvestigationDiagnosticApp\"",
            in: projectSource
        )
        #expect(diagnosticConfigurationList.contains(
            "A00000000000000000000150 /* Debug */"
        ))
        #expect(!diagnosticConfigurationList.contains(
            "A00000000000000000000151 /* Release */"
        ))
        let releaseShellConfigurationList = try objectBlock(
            id: "A00000000000000000000028",
            comment:
                "Build configuration list for PBXNativeTarget "
                    + "\"StornautInvestigationDiagnosticReleaseShell\"",
            in: projectSource
        )
        #expect(releaseShellConfigurationList.contains(
            "A00000000000000000000151 /* Release */"
        ))
        #expect(!releaseShellConfigurationList.contains(
            "A00000000000000000000150 /* Debug */"
        ))

        let driverSources = try objectBlock(
            id: "B00000000000000000000026",
            comment: "Sources",
            in: projectSource
        )
        #expect(driverSources.contains(
            "B0000000000000000000001B /* main.swift in Sources */"
        ))
        #expect(driverSources.components(separatedBy: " in Sources */").count == 2)

        let driverFrameworks = try objectBlock(
            id: "B00000000000000000000027",
            comment: "Frameworks",
            in: projectSource
        )
        #expect(driverFrameworks.contains(
            "B0000000000000000000001C "
                + "/* StornautInvestigationMachineDriverSupport in Frameworks */"
        ))
        #expect(
            driverFrameworks.components(separatedBy: " in Frameworks */").count
                == 2
        )

        let driverCopy = try objectBlock(
            id: "B00000000000000000000042",
            comment: "Copy Investigation Driver",
            in: projectSource
        )
        for marker in [
            "B0000000000000000000001D "
                + "/* StornautInvestigationMachineDriver in Copy Investigation Driver */",
            "name = \"Copy Investigation Driver\";",
            "dstPath = Contents/MacOS;",
        ] {
            #expect(driverCopy.contains(marker))
        }
        #expect(
            driverCopy.components(
                separatedBy: " in Copy Investigation Driver */"
            ).count == 2
        )
        let driverCopyBuildFile = try objectLine(
            containing:
                "B0000000000000000000001D "
                    + "/* StornautInvestigationMachineDriver in Copy Investigation Driver */ =",
            in: projectSource
        )
        #expect(driverCopyBuildFile.contains(
            "settings = {ATTRIBUTES = (CodeSignOnCopy, ); };"
        ))

        let driverConfigurationList = try objectBlock(
            id: "A00000000000000000000027",
            comment:
                "Build configuration list for PBXNativeTarget "
                    + "\"StornautInvestigationMachineDriverNative\"",
            in: projectSource
        )
        for (id, name) in [
            ("A00000000000000000000170", "Debug"),
            ("A00000000000000000000171", "Release"),
        ] {
            #expect(driverConfigurationList.contains("\(id) /* \(name) */"))
            let configuration = try objectBlock(
                id: id,
                comment: name,
                in: projectSource
            )
            for marker in [
                "PRODUCT_BUNDLE_IDENTIFIER = "
                    + "com.eriklee.stornaut.investigation.machine-driver;",
                "CODE_SIGN_IDENTITY = \"-\";",
                "CODE_SIGN_STYLE = Manual;",
                "CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;",
                "ARCHS = arm64;",
                #"OTHER_SWIFT_FLAGS = "$(inherited) -parse-as-library";"#,
                "SKIP_INSTALL = YES;",
            ] {
                #expect(configuration.contains(marker))
            }
            #expect(!configuration.contains("CODE_SIGN_ENTITLEMENTS"))
        }
        #expect(
            projectSource.components(
                separatedBy: "name = \"Copy Investigation Driver\";"
            ).count == 2
        )
        #expect(
            projectSource.components(
                separatedBy: "isa = PBXCopyFilesBuildPhase;"
            ).count == 4
        )
        #expect(
            diagnosticScheme.components(
                separatedBy:
                    "BlueprintName = \""
                        + "StornautInvestigationMachineDriverNative\""
            ).count == 2
        )
        #expect(diagnosticScheme.contains(
            "BuildableName = \"StornautInvestigationMachineDriver\""
        ))
        #expect(!ordinaryScheme.contains(
            "StornautInvestigationMachineDriver"
        ))
    }

    @Test
    func l3c3aAddsOnlyStrictDriverBindingWithoutAdvancingTopology()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        func source(_ path: String) throws -> String {
            try String(
                contentsOf: repositoryRoot.appending(path: path),
                encoding: .utf8
            )
        }

        func block(
            _ text: String,
            from startMarker: String,
            until endMarker: String
        ) throws -> String {
            let start = try #require(text.range(of: startMarker))
            let suffix = text[start.lowerBound...]
            let end = try #require(suffix.range(of: endMarker))
            return String(suffix[..<end.lowerBound])
        }

        func requireSchema(
            _ version: Int,
            declaration: String,
            in text: String,
            until endMarker: String
        ) throws {
            let declarationSource = try block(
                text,
                from: "public struct \(declaration):",
                until: endMarker
            )
            #expect(declarationSource.contains(
                "public static let schemaVersion = \(version)"
            ))
        }

        let signedContract = try source(
            "Sources/StornautInvestigation/"
                + "SignedInvestigationRuntimeContract.swift"
        )
        let machineContract = try source(
            "Sources/StornautInvestigationMachine/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )
        let appLeaf = try source(
            "Sources/StornautInvestigationDiagnostic/"
                + "InvestigationRuntimeDiagnosticAppLeaf.swift"
        )
        let composition = try source(
            "Sources/StornautInvestigationDiagnostic/"
                + "InvestigationRuntimeDiagnosticComposition.swift"
        )
        let lifecycleRegistration = try source(
            "Sources/StornautLifecycle/"
                + "LifecycleServiceRegistration.swift"
        )
        let xcodeProject = try source(
            "Stornaut.xcodeproj/project.pbxproj"
        )

        let driverBinding = try block(
            signedContract,
            from:
                "public struct "
                + "SignedInvestigationRuntimeMachineDriverBinding:",
            until: "public struct SignedInvestigationRuntimeBinding:"
        )
        for marker in [
            "public static let schemaVersion = 1",
            "strictSignedRuntimeContainer(",
            #"keys: Set(CodingKeys.allCases.map(\.rawValue))"#,
            "public let executableSHA256: String",
            "public let signingIdentifier: String",
            "public let designatedRequirementSHA256: String",
            "public let codeDirectoryHash: String",
            "public let machineClaimServiceIdentifier: String",
            "lowercaseHex(codeDirectoryHash, count: 40)",
            "lowercaseHex(codeDirectoryHash, count: 64)",
            "case schemaVersion",
            "case executableSHA256",
            "case signingIdentifier",
            "case designatedRequirementSHA256",
            "case codeDirectoryHash",
            "case machineClaimServiceIdentifier",
            "lowercaseHex(codeDirectoryHash, count: 40)",
            "lowercaseHex(codeDirectoryHash, count: 64)",
        ] {
            #expect(driverBinding.contains(marker))
        }
        #expect(
            driverBinding.components(separatedBy: "        case " ).count
                == 7
        )

        let runtimeBinding = try block(
            signedContract,
            from: "public struct SignedInvestigationRuntimeBinding:",
            until:
                "public struct "
                + "SignedInvestigationRuntimeDiagnosticConfiguration:"
        )
        for marker in [
            "public static let schemaVersion = 2",
            "public let machineDriver:",
            "SignedInvestigationRuntimeMachineDriverBinding",
            "case machineDriver",
            "machineDriver: try container.decode(",
        ] {
            #expect(runtimeBinding.contains(marker))
        }
        #expect(!runtimeBinding.contains(
            "machineDriver:\n"
                + "        SignedInvestigationRuntimeMachineDriverBinding?"
        ))
        #expect(!runtimeBinding.contains(
            "machineDriver: container.decodeIfPresent"
        ))

        try requireSchema(
            3,
            declaration: "SignedInvestigationRuntimeDiagnosticConfiguration",
            in: signedContract,
            until: "public enum SignedInvestigationRuntimeDenialKind:"
        )
        try requireSchema(
            4,
            declaration: "SignedInvestigationCapabilityEvidenceReceipt",
            in: signedContract,
            until: "public struct SignedInvestigationRuntimeReport:"
        )
        try requireSchema(
            4,
            declaration: "SignedInvestigationRuntimeReport",
            in: signedContract,
            until: "public struct SignedInvestigationRuntimeAdmissionReceipt:"
        )
        for (declaration, version, nextDeclaration) in [
            (
                "SignedInvestigationRuntimeMachineCaseEvidence",
                3,
                "SignedInvestigationRuntimeFailureMatrix"
            ),
            (
                "SignedInvestigationRuntimeFailureMatrix",
                3,
                "SignedInvestigationRuntimeMachineReport"
            ),
            (
                "SignedInvestigationRuntimeMachineReport",
                3,
                "SignedInvestigationRuntimeLifecycleResidueRecord"
            ),
            (
                "SignedInvestigationRuntimeLifecycleResidueRecord",
                2,
                "SignedInvestigationRuntimeMachineEvidenceBundle"
            ),
        ] {
            try requireSchema(
                version,
                declaration: declaration,
                in: machineContract,
                until: "public struct \(nextDeclaration):"
            )
        }
        let evidenceBundle = try block(
            machineContract,
            from:
                "public struct "
                + "SignedInvestigationRuntimeMachineEvidenceBundle:",
            until:
                "private struct "
                + "CompletedMachineConfiguration: Decodable"
        )
        #expect(evidenceBundle.contains(
            "public static let schemaVersion = 7"
        ))

        let leafConfiguration = try block(
            appLeaf,
            from: "private struct Configuration: Decodable",
            until: "private enum Scenario:"
        )
        let leafBinding = try block(
            appLeaf,
            from: "private struct Binding: Decodable",
            until: "private struct MachineDriverBinding: Decodable"
        )
        let leafDriverBinding = try block(
            appLeaf,
            from: "private struct MachineDriverBinding: Decodable",
            until: "private struct DynamicCodingKey:"
        )
        #expect(leafConfiguration.contains("schemaVersion == 3"))
        #expect(leafBinding.contains("schemaVersion == 2"))
        #expect(leafBinding.contains("case machineDriver"))
        #expect(leafDriverBinding.contains("schemaVersion == 1"))
        for marker in [
            "strictContainer(",
            #"keys: Set(CodingKeys.allCases.map(\.rawValue))"#,
            "case schemaVersion",
            "case executableSHA256",
            "case signingIdentifier",
            "case designatedRequirementSHA256",
            "case codeDirectoryHash",
            "case machineClaimServiceIdentifier",
        ] {
            #expect(leafDriverBinding.contains(marker))
        }
        #expect(
            leafDriverBinding.components(
                separatedBy: "        case "
            ).count == 7
        )

        let observation = try block(
            composition,
            from:
                "package struct "
                + "InvestigationRuntimeDiagnosticBindingObservation:",
            until:
                "private actor "
                + "InvestigationRuntimeDiagnosticTransportOwner:"
        )
        for marker in [
            "LifecycleBundleSigningIdentityReader()",
            "contract.machineDriverExecutableURL",
            "Contents/MacOS/",
            "StornautInvestigationMachineDriver",
            "machineDriverEvidence.executableSHA256",
            "machineDriverEvidence.identity.signingIdentifier",
            "machineDriverDesignatedRequirementSHA256",
            "machineDriverCodeDirectoryHash",
            "machineClaimServiceIdentifier",
            "binding.machineDriver",
        ] {
            #expect(observation.contains(marker))
        }

        let signingIdentifier =
            "com.eriklee.stornaut.investigation.machine-driver"
        let claimServiceIdentifier =
            "com.eriklee.stornaut.lifecycle.machine-claim"
        for text in [driverBinding, leafDriverBinding, lifecycleRegistration] {
            #expect(text.contains(signingIdentifier))
            #expect(text.contains(claimServiceIdentifier))
        }

        let l3c3aSources = [driverBinding, leafDriverBinding, observation]
        for text in l3c3aSources {
            for forbidden in [
                "StornautExecution",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "MoveToTrash",
                "posix_spawn",
                "Process(",
                "CommandLine",
                "ProcessInfo.processInfo.environment",
                "NSXPCListener",
                "NSXPCConnection",
                "LifecycleMachineRetirementHandle",
                "Launcher",
                "launcher",
                "signedInvestigationRuntimeReady",
                "signedRuntimeReady",
                "Readiness",
                "readiness",
                "arguments:",
                "environment:",
                "fileDescriptor:",
            ] {
                #expect(!text.contains(forbidden))
            }
        }

        #expect(xcodeProject.contains(
            "StornautInvestigationMachineDriverNative"
        ))
        #expect(xcodeProject.contains(
            "com.eriklee.stornaut.investigation.machine-driver"
        ))
    }

    @Test
    func trustedMachineImplementationLivesOnlyInTheNonProductTarget()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageSource = try String(
            contentsOf: repositoryRoot.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let releaseBoundary = try String(
            contentsOf: repositoryRoot.appending(
                path: "scripts/verify-app-release-boundaries"
            ),
            encoding: .utf8
        )
        let driverLoopStart = try #require(releaseBoundary.range(
            of: "for app_without_machine_driver in \\\n"
        ))
        let driverLoopSuffix = releaseBoundary[driverLoopStart.lowerBound...]
        let driverLoopEnd = try #require(
            driverLoopSuffix.range(of: "\ndone")
        )
        let driverLoop = String(
            driverLoopSuffix[..<driverLoopEnd.upperBound]
        )
        for appVariable in [
            "\"$debug_app\"",
            "\"$release_app\"",
        ] {
            #expect(
                driverLoop.components(separatedBy: appVariable).count
                    == 2
            )
        }
        #expect(!driverLoop.contains("\"$diagnostic_debug_app\""))
        let exactDriverPath =
            "$app_without_machine_driver/Contents/MacOS/StornautInvestigationMachineDriver"
        #expect(
            driverLoop.components(separatedBy: exactDriverPath).count
                == 3
        )
        #expect(driverLoop.contains("test ! -e"))
        #expect(driverLoop.contains("test ! -L"))
        for marker in [
            "diagnostic_machine_driver=",
            "machine_driver_product=",
            "machine_driver_max_bytes=$((16 * 1024 * 1024))",
            "/usr/bin/lipo -archs",
            "/usr/bin/codesign --verify --strict",
            "Identifier=com.eriklee.stornaut.investigation.machine-driver",
            "designated => cdhash H",
            "machine_driver_product_sha256",
            "diagnostic_machine_driver_sha256",
            "machine_driver_product_cdhash",
            "diagnostic_machine_driver_cdhash",
            "machine_driver_authority_forbidden_markers",
            "signedInvestigationRuntimeReady",
            "signedRuntimeReady",
        ] {
            #expect(releaseBoundary.contains(marker))
        }

        let verifierContract = try String(
            contentsOf: repositoryRoot.appending(
                path: "scripts/verify-contract"
            ),
            encoding: .utf8
        )
        for marker in [
            "validate_machine_driver_packaging_contract",
            "validate_built_app",
            "validate_installed_artifacts",
            "validate_machine_driver_artifact",
            "validate_machine_driver_identity",
            "validate_machine_driver_fixtures",
            "validate-machine-driver",
        ] {
            #expect(verifierContract.contains(marker))
        }

        let investigationSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigation/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )
        let machineSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "SignedInvestigationRuntimeMachineContract.swift"
        )

        #expect(!FileManager.default.fileExists(
            atPath: investigationSource.path
        ))
        #expect(FileManager.default.fileExists(atPath: machineSource.path))

        let targetStart = try #require(packageSource.range(
            of: ".target(\n            name: \"StornautInvestigationMachine\""
        ))
        let targetSuffix = packageSource[targetStart.lowerBound...]
        let targetEnd = try #require(targetSuffix.range(of: "\n        ),"))
        let targetSource = String(targetSuffix[..<targetEnd.upperBound])
        for dependency in [
            "\"StornautCodex\"",
            "\"StornautCore\"",
            "\"StornautInvestigation\"",
            "\"StornautInvestigationRuntime\"",
            "\"StornautLifecycle\"",
        ] {
            #expect(targetSource.contains(dependency))
        }
        for forbidden in [
            "StornautExecution",
            "StornautInvestigationDiagnostic",
        ] {
            #expect(!targetSource.contains(forbidden))
        }

        #expect(!packageSource.contains(
            ".library(\n            name: \"StornautInvestigationMachine\""
        ))
        #expect(!packageSource.contains(
            ".executable(\n            name: \"StornautInvestigationMachine\""
        ))
        let driverTargetStart = try #require(packageSource.range(
            of: ".executableTarget(\n            name: \"StornautInvestigationMachineDriver\""
        ))
        let driverTargetSuffix = packageSource[
            driverTargetStart.lowerBound...
        ]
        let driverTargetEnd = try #require(
            driverTargetSuffix.range(of: "\n        ),")
        )
        let driverTargetSource = String(
            driverTargetSuffix[..<driverTargetEnd.upperBound]
        )
        #expect(driverTargetSource.contains(
            "dependencies: [\n                "
                + "\"StornautInvestigationMachineDriverSupport\",\n"
                + "            ]"
        ))
        #expect(driverTargetSource.contains(
            "path: \"Tools/StornautInvestigationMachineDriver\""
        ))
        for forbidden in [
            "StornautLifecycle",
            "StornautInvestigationRuntime",
            "StornautInvestigationDiagnostic",
            "StornautExecution",
            "StornautCore",
            "StornautCodex",
        ] {
            #expect(!driverTargetSource.contains(forbidden))
        }
        #expect(!packageSource.contains(
            ".executable(\n            name: \"StornautInvestigationMachineDriver\""
        ))

        let driverHostURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineDriverHost.swift"
        )
        let driverMainURL = repositoryRoot.appending(
            path: "Tools/StornautInvestigationMachineDriver/main.swift"
        )
        let scenarioRunnerURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationFixedScenarioRunner.swift"
        )
        let scenarioDriverURL = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineScenarioDriver.swift"
        )
        #expect(FileManager.default.fileExists(atPath: driverHostURL.path))
        #expect(FileManager.default.fileExists(atPath: driverMainURL.path))
        #expect(FileManager.default.fileExists(atPath: scenarioRunnerURL.path))
        #expect(FileManager.default.fileExists(atPath: scenarioDriverURL.path))
        let driverHost = try String(
            contentsOf: driverHostURL,
            encoding: .utf8
        )
        let driverMain = try String(
            contentsOf: driverMainURL,
            encoding: .utf8
        )
        let scenarioRunner = try String(
            contentsOf: scenarioRunnerURL,
            encoding: .utf8
        )
        let scenarioDriver = try String(
            contentsOf: scenarioDriverURL,
            encoding: .utf8
        )
        for marker in [
            "package enum InvestigationMachineDriverEntryPoint",
            "package static func run() async -> Int32",
            "actor InvestigationMachineDriverHost",
            "struct StrictMachineRetirementClaimSource",
            "InvestigationMachineRetirementClaimStore()",
            "InvestigationLifecycleTopologyCollectionRequest(",
        ] {
            #expect(driverHost.contains(marker))
        }
        #expect(!driverHost.contains("LifecycleMachineClaimXPCClient()"))
        #expect(!driverHost.contains("InstalledMachineRetirementHelperSigningVerifier"))
        #expect(driverHost.contains("case implementationUnavailable"))
        #expect(driverHost.contains("throw InvestigationMachineDriverHostError.implementationUnavailable"))
        #expect(
            driverHost.components(separatedBy: "package " ).count == 3
        )
        for internalDeclaration in [
            "protocol InvestigationMachineRetirementHandleHandoff",
            "protocol InvestigationMachineRetirementClaiming",
            "struct InvestigationMachineTopologyAuthority",
            "actor InvestigationMachineDriverHost",
        ] {
            #expect(driverHost.contains(internalDeclaration))
            #expect(!driverHost.contains("public \(internalDeclaration)"))
            #expect(!driverHost.contains("package \(internalDeclaration)"))
        }
        #expect(driverMain.contains(
            "import StornautInvestigationMachineDriverSupport"
        ))
        #expect(driverMain.contains(
            "await InvestigationMachineDriverSupport.run()"
        ))
        #expect(!driverMain.contains("CommandLine"))
        #expect(!driverMain.contains("ProcessInfo"))
        for source in [driverHost, driverMain] {
            for forbidden in [
                "StornautExecution",
                "StornautInvestigationDiagnostic",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "signedInvestigationRuntimeReady",
                "JSONEncoder",
                "JSONDecoder",
                "PropertyListEncoder",
                "PropertyListDecoder",
                "NSXPCConnection",
                "URLSession",
                "posix_spawn",
                "removeItem",
                "moveItem",
                "copyItem",
                "CommandLine.arguments",
                "ProcessInfo.processInfo.environment",
                "readLine(",
                "kill(",
            ] {
                #expect(!source.contains(forbidden))
            }
        }
        for marker in [
            "actor InvestigationFixedScenarioRunner",
            "typealias Operation = @Sendable () async throws",
            "InvestigationFixedScenarioObservation",
            "InvestigationFixedScenarioTrace",
        ] {
            #expect(scenarioRunner.contains(marker))
        }
        for marker in [
            "actor InvestigationMachineScenarioDriver",
            "struct InvestigationMachineScenarioAttempt",
            "struct InvestigationMachineSyntheticSuccessEvidence",
            "async throws -> SignedInvestigationRuntimeFailureMatrix",
            "let authority = try await attempt.host.run()",
            "try await attempt.runner.consumeObservation()",
        ] {
            #expect(scenarioDriver.contains(marker))
        }
        let scenarioSources = scenarioRunner + "\n" + scenarioDriver
        let accessDeclaration = try NSRegularExpression(
            pattern: #"(?m)^\s*(?:(?:@[A-Za-z_][A-Za-z0-9_.]*(?:\([^)]*\))?|final|indirect|nonisolated|override|required|static|class|mutating|nonmutating|convenience|distributed)\s+)*(?:public|package)(?:\(set\))?\s+"#
        )
        #expect(accessDeclaration.firstMatch(
            in: scenarioSources,
            range: NSRange(
                scenarioSources.startIndex...,
                in: scenarioSources
            )
        ) == nil)
        for source in [scenarioRunner, scenarioDriver] {
            for forbidden in [
                "import StornautExecution",
                "import StornautInvestigationDiagnostic",
                "import StornautCodex",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "FileManagerTrashAdapter",
                "CleanupExecutionRuntime",
                "CleanupExecutionCoordinator",
                "CleanupActionExecuting",
                "CleanupAuthorizationController",
                "ExecutionAuthorization",
                "ActionPolicyGate",
                "CleanupPolicyGate",
                "MoveToTrash",
                "ProposedCleanupAction",
                "CleanupAction",
                "SignedInvestigationCapabilityEvidenceReceipt",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "SignedInvestigationRuntimeMachineReport",
                "signedInvestigationRuntimeReady",
                "signedRuntimeReady",
                "readiness",
                "Readiness",
                "Codable",
                "JSONEncoder",
                "JSONDecoder",
                "PropertyListEncoder",
                "PropertyListDecoder",
                "FileManager.default",
                "NSXPCConnection",
                "URLSession",
                "NWConnection",
                "WebSocket",
                "CFStream",
                "socket",
                "connect",
                "send",
                "recv",
                "posix_spawn",
                "removeItem",
                "moveItem",
                "copyItem",
                "createDirectory",
                "createFile",
                "CommandLine.arguments",
                "ProcessInfo.processInfo.environment",
                "readLine(",
                "kill(",
            ] {
                #expect(!source.contains(forbidden))
            }
        }

        let machineText = try String(
            contentsOf: machineSource,
            encoding: .utf8
        )
        let collectorSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachine/"
                    + "InvestigationLifecycleTopologyCollector.swift"
            ),
            encoding: .utf8
        )
        let serviceSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachine/"
                    + "FixedLifecycleServiceProbe.swift"
            ),
            encoding: .utf8
        )
        let claimSource = repositoryRoot.appending(
            path: "Sources/StornautInvestigationMachine/"
                + "InvestigationMachineRetirementClaim.swift"
        )
        #expect(FileManager.default.fileExists(atPath: claimSource.path))
        let claimText = try String(
            contentsOf: claimSource,
            encoding: .utf8
        )
        for marker in [
            "protocol InvestigationMachineRetirementClaimSource",
            "struct InvestigationMachineRetirementClaim",
            "actor InvestigationMachineRetirementClaimStore",
        ] {
            #expect(claimText.contains(marker))
            #expect(!claimText.contains("public \(marker)"))
            #expect(!claimText.contains("package \(marker)"))
        }
        for forbidden in [
            "Codable",
            "JSONDecoder",
            "JSONEncoder",
            "PropertyListDecoder",
            "PropertyListEncoder",
            "NSXPCConnection",
            "LifecycleSupervisorXPCWire",
            "LifecycleInteractiveSessionXPCWire",
        ] {
            #expect(!claimText.contains(forbidden))
        }
        let xpcSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautLifecycle/LifecycleSupervisorXPC.swift"
            ),
            encoding: .utf8
        )
        #expect(!xpcSource.contains("LifecycleMachineRetirementClaimRequest"))
        #expect(!xpcSource.contains("LifecycleMachineRetirementClaimResponse"))
        #expect(!xpcSource.contains("LifecycleMachineClaimXPCWire"))
        let helperSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "StornautLifecycleHelper/main.swift"
            ),
            encoding: .utf8
        )
        #expect(!helperSource.contains(
            "@objc private protocol LifecycleMachineClaimXPCWire"
        ))
        #expect(helperSource.contains(
            "import StornautInvestigationHandoffContract"
        ))
        #expect(helperSource.contains(
            "with: InvestigationMachineClaimXPCWire.self"
        ))
        for method in [
            "func attestHelper(",
            "func handle(",
            "func handleInteractive(",
        ] {
            #expect(
                xpcSource.components(separatedBy: method).count == 2
            )
        }
        #expect(
            helperSource.components(
                separatedBy: "func claimMachineRetirement("
            ).count == 1
        )
        #expect(
            helperSource.components(
                separatedBy: "func releaseMachineRetirement("
            ).count == 1
        )
        let exportedMethodCount = xpcSource
            .components(separatedBy: "@objc public protocol")
            .dropFirst()
            .map { protocolSource in
                protocolSource
                    .prefix { $0 != "}" }
                    .components(separatedBy: "func " )
                    .count - 1
            }
            .reduce(0, +)
        #expect(exportedMethodCount == 3)
        let escrowSource = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautLifecycle/"
                    + "LifecycleMachineRetirementEscrow.swift"
            ),
            encoding: .utf8
        )
        #expect(
            escrowSource.contains(
                "machineDriverIdentity: LifecycleProcessIdentity"
            )
        )
        #expect(
            escrowSource.contains(
                "admission: any LifecycleMachineDriverClaimAdmitting"
            )
        )
        #expect(!escrowSource.contains("public func claim(\n        _ request: LifecycleMachineRetirementClaimRequest,\n        authorized: Bool"))
        #expect(!escrowSource.contains("package func claim(\n        _ request: LifecycleMachineRetirementClaimRequest,\n        authorized: Bool"))
        #expect(escrowSource.contains("let tokenSHA256: Data"))
        let entryStart = try #require(
            escrowSource.range(of: "fileprivate struct Entry {")
        )
        let entrySuffix = escrowSource[entryStart.lowerBound...]
        let entryEnd = try #require(entrySuffix.range(of: "\n    }"))
        let entrySource = String(entrySuffix[..<entryEnd.upperBound])
        #expect(!entrySource.contains("LifecycleMachineRetirementHandle"))
        for trustedDeclaration in [
            "protocol SignedInvestigationRuntimeSealedCohortAuthority",
            "struct SignedInvestigationRuntimeMachineAssembler",
            "struct SignedInvestigationRuntimeMachineVerifier",
        ] {
            #expect(machineText.contains(trustedDeclaration))
            #expect(!machineText.contains("public \(trustedDeclaration)"))
            #expect(!machineText.contains("package \(trustedDeclaration)"))
        }
        for forbidden in [
            "import StornautExecution",
            "import StornautLifecycle",
            "ActionExecutor",
            "TrashMoving",
            "FileManagerTrashAdapter",
            "signedInvestigationRuntimeReady",
        ] {
            #expect(!machineText.contains(forbidden))
        }
        for source in [collectorSource, serviceSource] {
            for forbidden in [
                "StornautExecution",
                "StornautInvestigationDiagnostic",
                "ActionExecutor",
                "TrashMoving",
                "RegisteredAction",
                "SignedInvestigationRuntimeMachineAssembler",
                "SignedInvestigationRuntimeMachineVerifier",
                "signedInvestigationRuntimeReady",
                "Codable",
                "JSONEncoder",
                "JSONDecoder",
                "bootout",
                "bootstrap system",
                "FileManager.default.remove",
            ] {
                #expect(!source.contains(forbidden))
            }
        }
    }

    @Test
    func l3c3biiInstallerValidatesOneDriverIdentityAcrossAllPhases()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let installer = try l3c3biiSource(
            "scripts/stornaut-r5-local-lifecycle",
            repositoryRoot: repositoryRoot
        )
        let exactMetadata = l3c3biiFlattened(try l3c3biiFunction(
            "exact_file_metadata",
            in: installer
        ))
        let identity = l3c3biiFlattened(try l3c3biiFunction(
            "validate_machine_driver_identity",
            in: installer
        ))
        let artifact = l3c3biiFlattened(try l3c3biiFunction(
            "validate_machine_driver_artifact",
            in: installer
        ))
        let built = l3c3biiFlattened(try l3c3biiFunction(
            "validate_built_app",
            in: installer
        ))
        let installed = l3c3biiFlattened(try l3c3biiFunction(
            "validate_installed_artifacts",
            in: installer
        ))
        let bundlePermissions = l3c3biiFlattened(try l3c3biiFunction(
            "validate_bundle_permissions",
            in: installer
        ))
        let install = l3c3biiFlattened(try l3c3biiFunction(
            "install",
            in: installer
        ))

        for marker in [
            "/usr/bin/codesign -d --verbose=4",
            "Identifier=",
            "CDHash=",
            "/usr/bin/codesign -d -r-",
            "designated => cdhash H",
            "/usr/bin/shasum -a 256",
            "com.eriklee.stornaut.investigation.machine-driver",
            "$machine_claim_service",
        ] {
            #expect(identity.contains(marker))
        }
        for marker in [
            "exact_file_metadata",
            "/usr/bin/stat -f '%z'",
            "/usr/bin/lipo -archs",
            "/usr/bin/codesign --verify --strict",
            "validate_machine_driver_identity",
        ] {
            #expect(artifact.contains(marker))
        }
        #expect(artifact.components(
            separatedBy: "/usr/bin/stat -f '%d:%i'"
        ).count >= 3)
        for source in [exactMetadata, bundlePermissions] {
            #expect(source.contains("/bin/ls -lde"))
            #expect(source.contains("acl_listing"))
            #expect(source.contains("!= *$'\\n'*"))
        }
        #expect(install.contains("/bin/chmod -RN \"$staging_app\""))

        for (slice, root) in [
            (built, "built_app"),
            (install, "staging_app"),
            (installed, "installed_app"),
        ] {
            let path =
                "$\(root)/Contents/MacOS/"
                + "StornautInvestigationMachineDriver"
            #expect(!slice.contains("[[ ! -e \"\(path)\""))
            #expect(!slice.contains("! -L \"\(path)\""))
            #expect(slice.contains(
                "validate_machine_driver_artifact \"\(path)\""
            ))
        }

        #expect(install.contains("built_machine_driver_identity="))
        #expect(install.components(
            separatedBy: "$built_machine_driver_identity"
        ).count >= 3)
        #expect(install.contains(
            "validate_machine_driver_artifact \"$staging_app/Contents/"
                + "MacOS/StornautInvestigationMachineDriver\""
        ))
        #expect(install.contains(
            "validate_installed_artifacts \"$built_machine_driver_identity\""
        ))
        try l3c3biiRequireOrder(
            [
                "built_machine_driver_identity=",
                "validate_built_app",
                "/usr/bin/ditto --noqtn",
                "/bin/chmod -RN \"$staging_app\"",
                "validate_bundle_permissions \"$staging_app\"",
                "validate_machine_driver_artifact \"$staging_app/Contents/",
                "/bin/mv -n \"$staging_app\" \"$installed_app\"",
                "validate_installed_artifacts \"$built_machine_driver_identity\"",
                "/bin/launchctl bootstrap system \"$installed_plist\"",
                "validate_installed_state",
                "lifecycle.local.install=complete",
            ],
            in: install
        )
    }

    @Test
    func l3c3biiValidationOnlyActionIsTokenBoundPathConfinedAndReadOnly()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let installer = try l3c3biiSource(
            "scripts/stornaut-r5-local-lifecycle",
            repositoryRoot: repositoryRoot
        )
        let token =
            "I authorize one bounded disposable read-only Stornaut "
            + "L3c3b-ii Machine driver validation."
        let firstFunction = try #require(installer.range(
            of: "\nexact_file_metadata() {"
        ))
        let preamble = String(installer[..<firstFunction.lowerBound])
        #expect(preamble.contains(
            "machine_driver_validation_token=\"\(token)\""
        ))

        let actionCaseStart = try #require(installer.range(
            of: "case \"$action\" in"
        ))
        let actionCaseSuffix = installer[actionCaseStart.lowerBound...]
        let actionCaseEnd = try #require(actionCaseSuffix.range(
            of: "\nesac"
        ))
        let actionCase = String(
            actionCaseSuffix[..<actionCaseEnd.upperBound]
        )
        for unchanged in [
            "status) status ;;",
            "install) install ;;",
            "uninstall) uninstall ;;",
        ] {
            #expect(actionCase.contains(unchanged))
        }

        let arm = l3c3biiFlattened(try l3c3biiCaseArm(
            "validate-machine-driver",
            in: installer
        ))
        #expect(arm.contains("[[ $# == 6 ]]") || arm.contains("(( $# == 6 ))"))
        #expect(arm.contains(
            "validate_machine_driver_fixtures \"$2\" \"$3\" "
                + "\"$4\" \"$5\" \"$6\""
        ))

        let exactMetadata = try l3c3biiFunction(
            "exact_file_metadata",
            in: installer
        )
        let identity = try l3c3biiFunction(
            "validate_machine_driver_identity",
            in: installer
        )
        let artifact = try l3c3biiFunction(
            "validate_machine_driver_artifact",
            in: installer
        )
        let fixtures = l3c3biiFlattened(try l3c3biiFunction(
            "validate_machine_driver_fixtures",
            in: installer
        ))
        #expect(fixtures.contains(
            "[[ \"$token\" == \"$machine_driver_validation_token\" ]]"
        ))
        for path in [
            "temporary_root",
            "built_app",
            "staging_app",
            "installed_app",
        ] {
            #expect(fixtures.contains("[[ \"$\(path)\" == /* ]]"))
            #expect(fixtures.contains(
                "canonical_\(path)=$(/bin/realpath \"$\(path)\")"
            ))
        }
        for app in ["built_app", "staging_app", "installed_app"] {
            #expect(fixtures.contains(
                "[[ \"$canonical_\(app)\" == "
                    + "\"$canonical_temporary_root/\"* ]]"
            ))
        }
        for pair in [
            ("built_app", "staging_app"),
            ("built_app", "installed_app"),
            ("staging_app", "installed_app"),
        ] {
            #expect(fixtures.contains(
                "[[ \"$canonical_\(pair.0)\" != "
                    + "\"$canonical_\(pair.1)\" ]]"
            ))
        }
        #expect(fixtures.components(
            separatedBy: "validate_machine_driver_artifact"
        ).count == 4)
        #expect(fixtures.contains("built_machine_driver_identity"))

        let validationOnlySource =
            exactMetadata + identity + artifact + fixtures + arm
        for forbidden in [
            "launchctl",
            "mkdir",
            "chown",
            "chmod",
            "ditto",
            "/bin/mv",
            "/bin/rm",
            "/usr/bin/install",
            "/Library/",
            "/private/var/",
            "posix_spawn",
            "exec ",
            "eval ",
            "xargs",
        ] {
            #expect(!validationOnlySource.contains(forbidden))
        }
        let directDriverExecution = try NSRegularExpression(
            pattern:
                #"(?m)^[ \t]*"?\$(?:\{)?(?:driver|machine_driver)(?:\})?"?[ \t]*(?:$|[;&|])"#
        )
        #expect(directDriverExecution.firstMatch(
            in: validationOnlySource,
            range: NSRange(
                validationOnlySource.startIndex...,
                in: validationOnlySource
            )
        ) == nil)
    }

    @Test
    func l3c3biiReleaseAndContractGatesFreezeDisposableValidation()
        throws
    {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let release = try l3c3biiSource(
            "scripts/verify-app-release-boundaries",
            repositoryRoot: repositoryRoot
        )
        let verifier = try l3c3biiSource(
            "scripts/verify-contract",
            repositoryRoot: repositoryRoot
        )
        let token =
            "I authorize one bounded disposable read-only Stornaut "
            + "L3c3b-ii Machine driver validation."
        let matrix = try l3c3biiFunction(
            containing: "validate-machine-driver",
            in: release
        )
        let matrixLowercase = matrix.lowercased()
        #expect(matrix.contains(token))
        #expect(matrix.contains("mktemp -d"))
        #expect(matrix.contains("trap"))
        #expect(matrix.components(
            separatedBy: "validate-machine-driver"
        ).count >= 6)
        for marker in [
            "positive",
            "wrong-token",
            "outside-root",
            "duplicate-app",
            "identity-mismatch",
            "acl-mismatch",
        ] {
            #expect(matrixLowercase.contains(marker))
        }
        for marker in [
            "temporary_root",
            "built_app",
            "staging_app",
            "installed_app",
        ] {
            #expect(matrix.contains(marker))
        }
        for forbidden in [
            " launchctl",
            " install ;;",
            " uninstall ;;",
            " stornaut-r5-local-lifecycle install",
            " stornaut-r5-local-lifecycle uninstall",
        ] {
            #expect(!matrix.contains(forbidden))
        }

        let contract = try l3c3biiFunction(
            "validate_machine_driver_packaging_contract",
            in: verifier
        )
        let contractLowercase = contract.lowercased()
        for marker in [
            "validate_machine_driver_identity",
            "validate_machine_driver_artifact",
            "validate_machine_driver_fixtures",
            "validate-machine-driver",
            "exact_metadata = function_body",
            "validation_only = exact_metadata + identity",
            "validation-only mutation negative control",
            "expected_installer_sha256 =",
            "installer_sha256 =",
            "whole-installer generic mutation negative control",
            "/usr/bin/touch",
            "extended ACL",
            "/bin/chmod -RN",
            "acl-mismatch",
            token,
            "canonical_temporary_root",
            "canonical_built_app",
            "canonical_staging_app",
            "canonical_installed_app",
            "$canonical_temporary_root/",
            "/bin/realpath",
            "launchctl",
            "mkdir",
            "chown",
            "chmod",
            "ditto",
            "/bin/mv",
            "/bin/rm",
            "/Library/",
            "/private/var/",
        ] {
            #expect(contract.contains(marker))
        }
        #expect(contractLowercase.contains("path confinement"))
        #expect(contractLowercase.contains("live action"))
        #expect(!contract.contains("reject_before("))
        #expect(!contract.contains(
            "installer admitted the Machine driver before L3c3b-ii"
        ))
    }
}
