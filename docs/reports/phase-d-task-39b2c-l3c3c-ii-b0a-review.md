# Phase D Task 39B2c-L3c3c-ii-b0a Frame/Capsule Contract Review

> Status: Complete; exact non-product frame/capsule contract implemented,
> reviewed and pushed
>
> Date: 2026-08-19
>
> Implementation commit: `35946583cfb286dd2ac20aab23fe12668f232d83`
>
> Implementation tree: `35883fc2c06be3c48c9e05f6cefeb6de40430dce`
>
> Scope: shared binary primitives, STNH frames/payloads and eight-epoch cohort
> capsule only; no claim/release XPC, App leaf, helper migration, process launch,
> install, sudo, model/auth use, readiness or full verifier

## 1. Decision

L3c3c-ii-b0a is complete. The new package-only
`StornautInvestigationHandoffContract` target has no target dependencies, is not
a product, and is consumed only by `StornautInvestigationTests`. It owns the
single exact binary representation for:

- raw 32-byte SHA-256 and strict lowercase-hex domain conversion;
- checked UTC-microsecond projection;
- the `STNC` ordered tagged transcript;
- the closed eight-scenario numeric map;
- all eleven `STNH` frame kinds, the exact 56-byte header and typed payloads;
- bounded single-frame and incremental stream decoding; and
- the eight-epoch cohort capsule with exact zero-before-hash self-digest.

All declarations are package-scoped and non-`Codable`. The target imports only
Foundation/CryptoKit and contains no XPC connection/listener, Security lookup,
filesystem, process, signal, network, model or cleanup implementation. It is not
linked into any App, helper, Machine driver or other product target.

The next frontier is ii-b0b, which extends this same non-product target with the
claim/evidence/release/released transcripts and Data-only Objective-C selector.
No product target may consume the shared target until the later checkpoint that
owns its adapter and boundary evidence.

## 2. Prompt-to-Artifact Completion Audit

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| One shared non-product target | `Package.swift`; resolved package graph has no product membership | satisfied |
| Foundation/CryptoKit only | exact per-source import allowlist in `scripts/verify-investigation-boundaries` | satisfied |
| Three frozen sources | resolved source graph equals `HandoffBinaryTranscript.swift`, `InvestigationHandoffFrameContract.swift`, `InvestigationCohortCapsuleContract.swift` | satisfied |
| Raw digest wire truth | `InvestigationHandoffSHA256`; 32-byte constructor, strict 64-lowercase-hex adapter and SHA-256 known vector | satisfied |
| Checked UTC microseconds | `InvestigationHandoffUTCMicroseconds`; positive finite checked floor and no authority extension | satisfied |
| Exact STNC encoding | magic, ordered contiguous tags, UInt32 lengths, bounded fields and no trailing bytes | satisfied |
| Closed scenario mapping | numeric `1...8` map in canonical Task 39 order; zero/unknown rejected | satisfied |
| Exact STNH header | golden 56-byte vector covers magic/version/kind/length/sequence/epoch/deadline/sender | satisfied |
| Closed frame semantics | eleven kinds bind sequence, direction, sender EUID and payload bounds | satisfied |
| Typed post-drop identity | UID/GID/groups/audit-token/regain errno evidence with header identity join | satisfied |
| Config/handle identity join | capsule row, CONFIGURATION_ACK and handle investigation UUID/digest comparison | satisfied |
| Bounded streaming | partial/coalesced input, multiple frames and > one-frame input with maximum internal buffer 65,592 bytes | satisfied |
| Eight-epoch capsule | exact order/count/scenario, 17-way UUID uniqueness, configuration bounds/digests and nested transcripts | satisfied |
| Whole-capsule digest | exact outer tag 4 zero substitution over every capsule byte; independent test hash | satisfied |
| Fail-closed package/source boundaries | target dependency/product/source/import/authority allowlists | satisfied |
| App-binary absence assertion | implemented with explicit symbol-scan error handling and frozen by verifier contract | deferred to an applicable App checkpoint; not used as b0a completion evidence |
| No product behavior change | only test target consumes the new target; no Xcode/product target membership | satisfied |
| Product remains unavailable | no availability/readiness/product activation source changed | satisfied |

No requirement is accepted from a proxy signal alone. Golden-byte unit tests
cover encoding behavior; package graph/source gates cover ownership and
authority; Debug/Release target builds cover both configurations; the serial
regression covers repository interaction.

## 3. Scope, Tests First and Review

The implementation changes exactly nine non-document paths with 2,363 additions
and three deletions, below the frozen nine-path / 2,400-line ceiling.

The mandatory unit-test workflow completed all seven steps:

1. prepared an isolated test context;
2. identified Swift 6.3 / SwiftPM / Swift Testing conventions;
3. froze three targets for binary primitives, STNH frames and the capsule;
4. found no pre-existing implementation defect because the target did not exist;
5. generated the initial suite and observed the expected compile RED,
   `no such module 'StornautInvestigationHandoffContract'`;
6. skipped coverage because no CI coverage gate or flux execution applied and
   the source did not yet exist; and
7. flushed the test report before production implementation began.

The initial 18 tests grew to 19 when local review found that a coalesced input
larger than one frame could otherwise tempt the stream decoder to exceed its
bounded buffer. A second local review bound all audit-token UID/GID axes, not
only EUID/PID/ASID/PID-version.

Independent implementation review checked the exact staged nine-path diff and
reported no unresolved P0-P2. It specifically verified STNC/STNH strictness,
capsule self-hash/17-way uniqueness, package graph closure and that the deferred
App symbol assertion fails closed on scan error. The assertion itself is not
treated as executed evidence in this checkpoint.

## 4. Validation

| Gate | Result |
| --- | --- |
| tests-first missing module | expected compile RED |
| exact transport contract suite | 19/19 passed |
| exact package/source boundary test | 1/1 passed |
| complete Investigation target | 246 tests in 21 suites passed |
| Debug target build | passed through XcodeBuildMCP SwiftPM build |
| Release target build | passed with `swift build -c release --target StornautInvestigationHandoffContract` |
| verifier self-contract | passed independently |
| Investigation structural verifier | passed independently, including existing Debug/Release Machine driver gates |
| clean staged-only serial regression | 1,107 tests in 53 suites passed |
| serial test / stage time | 80.619 / 141.494 seconds |
| accepted implementation tree | `35883fc2c06be3c48c9e05f6cefeb6de40430dce` |
| final independent staged review | no unresolved P0-P2 |

The clean staged-only serial ran exactly once from generated validation commit
`383a14789334cfe3e6b1b9a248f00484069bf617`. Its tree exactly matched the main
index before and after the run. The isolated validation worktree was removed.
There was no restart, failed-stage retry or second serial execution. Maximum
benchmarks remained skipped. The verifier explicitly reported that this was a
diagnostic single step, not authoritative headless verification.

One earlier multi-command diagnostic printed a verifier-contract failure and then
returned the later boundary command's exit zero. That aggregate exit was rejected
as evidence. `scripts/verify-contract` was rerun independently, exposed the new
demangled-symbol gate accounting mismatch, and passed only after the App absence
gate adopted the existing explicit `symbol_scan_status == 2` fail-closed contract
and source seals were updated.

`scripts/verify-app-release-boundaries` itself was not run: b0a is explicitly a
non-product checkpoint and the approved gate excludes App/XCUITest. Its added
App-symbol absence assertion is frozen by `verify-contract` and becomes executable
evidence at an applicable later App checkpoint. The current resolved package graph
directly proves no product target consumes the module.

Neither authoritative headless verification nor `scripts/verify --full` ran. The
remaining full verifier is reserved exclusively for L3c4.

## 5. Safety Boundary and Next Gate

No App/helper/driver was launched through the new contract, no topology was
installed, no launchd state changed, no sudo/auth/model operation occurred and no
user data was mutated. `~/.codex/config.toml` was not modified. ADR 0018 remains
Proposed, Task 39 remains incomplete, production Deep Dive remains unavailable
and real App Trash remains closed.

ii-b0b is next. It may add only the preflight-approved claim/evidence/release wire
values and Data-only XPC selector to the same non-product target. Lifecycle/helper/
Machine/DriverSupport migrations, connections, timers and live identity sourcing
remain outside b0b. ii-c alone owns the no-model privileged machine gate; L3c4
alone owns readiness and Task 39's remaining full verifier.
