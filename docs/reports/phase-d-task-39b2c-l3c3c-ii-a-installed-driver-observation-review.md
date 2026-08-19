# Phase D Task 39B2c-L3c3c-ii-a Installed Driver Observation Review

> Status: Complete; authority-closed installed-driver and manifest observation
> implemented, reviewed and pushed
>
> Date: 2026-08-19
>
> Implementation commit: 4c8fd0c8ff2030c8c72a6db518698283f061b9d6
>
> Implementation tree: 8f5b03da28c647cb4b1570d4b37e8d78ac02d735
>
> Scope: self-observation only; no handoff, socketpair, spawn, credential drop,
> install, sudo, App/driver launch, model call, readiness or full verifier

## 1. Decision

L3c3c-ii-a is complete. The fixed diagnostic Machine driver now fails closed
unless real/effective UID and GID are root, the invocation has no arguments,
the running executable resolves to the fixed installed path, and one held file
descriptor proves the exact root-owned regular node, mode 0755, single-link
bounded size, ACL/xattr policy, complete SHA-256 and stable pre/post metadata.
Strict static and live Security.framework identities must agree on identifier,
designated-requirement digest, CodeDirectory hash and ad-hoc status.

The same observation independently reads the fixed root-owned LaunchDaemon
manifest through a held descriptor. It binds mode 0644, single-link bounded
metadata, no ACL/xattrs, raw SHA-256, an exact ten-key XML property list, fixed
Label and Program, and exactly the primary and Machine-claim service entries.
The typed result is explicitly manifest-declared identity; it does not claim
that launchd has registered or activated the service. Live service/bootstrap
equality remains an ii-c Machine-gate responsibility.

Successful self-observation still returns the nonzero handoff-unavailable
status. ii-a adds no transport or launch authority and cannot enable Deep Dive.

## 2. Prompt-to-Artifact Completion Audit

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| Real/effective root identity | InvestigationMachineInstalledDriverObserver.observe; four-axis parameterized tests | satisfied |
| Zero driver arguments | CommandLine.argc equals one; invalid-invocation test | satisfied |
| Exact installed executable path | proc_pidpath; fixed path constant; initial/final equality | satisfied |
| Root-owned immutable path chain | root through Contents/MacOS; directory type, root owner, no group/other write, ACL rejection, protection-only SF_NOUNLINK allowance | satisfied |
| Stable executable node | lstat plus O_NOFOLLOW_ANY/O_UNIQUE and held-FD fstat; full metadata equality before and after all final trust queries | satisfied |
| Bounded content identity | size admitted before read; streaming pread; EOF-at-size; SHA-256 | satisfied |
| ACL/xattr policy | held-FD ACL queries; only system com.apple.provenance executable xattr allowed; manifest allows none; repeated final checks | satisfied |
| Static/live signing | strict Security validation and exact identifier/DR/CDHash/ad-hoc equality | satisfied |
| Machine-claim identity | fixed plist held-FD metadata/hash plus strict complete property-list parsing and double-read equality | satisfied as manifest-declared identity; no live-service claim |
| Close/error semantics | exactly one close after every post-open path; close failure rejects observation | satisfied |
| Typed, non-serializable evidence | non-Codable candidate/observation/manifest types | satisfied |
| No write/network/process/readiness authority | zero package dependencies, Security-only linker setting, exact source seals, two exact read-only opens, complete Debug/Release projections and diagnostic bundle allowlist | satisfied |
| Product remains unavailable | success remains exit 78; no normal-product activation path | satisfied |

The audit found no requirement represented only by a proxy signal. Source tests,
structural gates and final-Mach-O projections each cover a different boundary;
none alone is treated as completion proof.

## 3. Scope and Review Findings

The implementation changes exactly ten non-document paths and adds 2,853 lines,
within the frozen ten-path / 3,000-line ceiling. Independent review found and
closed these issues before completion:

1. system SF_NOUNLINK on root and /Library was incorrectly rejected;
2. Xcode's com.apple.provenance xattr made the real installed path impossible;
3. the 16 MiB limit was checked only after hashing;
4. root identity tests did not independently cover all four UID/GID axes;
5. source/final-Mach-O authority denylists admitted bypasses and lacked mutation
   controls;
6. Machine-claim identity was projected from a constant rather than observed
   from the installed manifest; and
7. final ACL/xattr/path queries were not closed by a final metadata recheck.

The post-fix design uses exact four-file source SHA seals, exact bound read-only
open expressions, unconditional Debug and Release builds, complete sorted
undefined/load/owned symbol projections, forbidden-added/required-removed/
Security-added mutation controls, and a five-Mach-O diagnostic bundle allowlist.
Fresh independent Darwin and verifier reviews reported no unresolved P0-P2.
The empty final finding-set SHA-256 is
37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570.

## 4. Validation

| Gate | Result |
| --- | --- |
| DriverSupport focused | 20 test entries; 34 identity-drift cases; 13 post-open failure cases passed |
| trusted Machine target boundary | 7/7 passed |
| Machine driver host affected suite | 11/11 passed |
| Investigation structural boundary | passed |
| Debug/Release final-Mach-O exact admission | passed; complete projections and three mutation controls |
| diagnostic App Debug targeted build | passed |
| ordinary/diagnostic App Release boundary | passed; exact five-Mach-O bundle and disposable matrix |
| verifier self-contract | passed |
| independent post-fix review | no unresolved P0-P2 |

The checkpoint's one staged-only serial ran from validation commit
35680f43d4f85e95c89da3ea21dfe7258f046c57, whose tree
a6981957a993ffbb3be830b2bb0cd8e65c06e947 exactly matches all ten ii-a
implementation paths. It ran 1,087 tests in 52 suites: 1,086 passed and one
unrelated cleanup-volume timeline test failed because its live Date value crossed
the fixed fixture plan's seven-day expiry at 2026-08-19 10:00 local time. The
serial stage took 127.138 seconds and was not restarted or repeated.

The failure was split into the independent prerequisite commit
4a0a8cb50ace719f81166dc19bbfcab10a388de2, which binds the test clock to the
fixture epoch without changing its backward-domain-time assertion. The exact
failed case then passed, and two independent reviews found no unresolved P0-P2.
This report deliberately does not describe the original serial as green.

Neither authoritative headless verification nor scripts/verify --full ran.
The remaining full verifier is still reserved exclusively for L3c4.

## 5. Safety Boundary and Next Gate

No App, helper or fixed installed/root driver was launched. The binary gate ran
only temporary Debug/Release driver builds as the non-root caller and observed
the required exit 77. No installed state, launchd service, external B4 path,
credential, model or user data was mutated. The external B4 root execution count
remains zero. The global Codex config was not modified.

The next frontier is L3c3c-ii-b fixed installed-driver/App handoff composition.
It may add only the preflight-approved fixed transport/process/credential-drop
primitives and non-privileged tests. ii-c alone owns the one no-model privileged
installed-driver gate and may accept ADR 0018 only after a green result. L3c4
alone owns readiness and Task 39's final full verifier. Task 39 remains incomplete
and production Deep Dive remains unavailable.
