# Phase D Task 39B2c ii-c-b2a1 Evidence Producer Completion Audit

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-08-31
>
> Implementation chain: `27a0c4561c298552f1fbfb805562f5e2a5185604` +
> `e3555ec08dcc390b96805753718ef96986bbbe18`
>
> Baseline: `09623fb2c4f8b12a7da4733fa2b068d9a6e534f6`
>
> Accepted tree: `f38783f170c1cf948ad53a8351a9c4d0109973fb`
>
> Next frontier: ii-c-b2a2 independent read-only evidence verifier

## 1. Result

ii-c-b2a1 is complete and remains non-privileged and non-admitting. It adds a
package-only `StornautInvestigationMachineCampaignSupport` target with no
SwiftPM product and no Xcode target or scheme reference. Its sole direct
dependency is `StornautInvestigationHandoffContract`;
`StornautInvestigationTests` is its sole reverse dependency. Both production
source files are DEBUG-only and expose no public or open API.

The evidence contract now freezes the six ordered phases, closed artifact
roles, canonical path/encoding/cardinality rules, bounded manifest and event
wires, coordinator-receipt framing, complete attempt identity and a typed
attempt summary. A cancelled-before-arm history cannot coexist with post-arm
artifacts; a consumed attempt must bind the complete four-event terminal chain
and its final digest.

The writer creates only one owner-private descriptor-relative evidence tree.
It uses exclusive temporary files, bounded writes, file and directory fsync,
exclusive rename, held/named identity validation, no-follow reopen, exact read
back and manifest-last finalization. Any uncertainty poisons the writer. It has
no unlink, stale-recovery, process, network, XPC, auth, cleanup or execution
authority.

## 2. Exact Scope and Budget

Relative to the frozen `09623fb` baseline, the completed non-document scope is
exactly four paths and 3,749 added lines, below the independent 3,800-line
ceiling:

| Path category | Changed lines | Ceiling |
| --- | ---: | ---: |
| `Package.swift` | 7 | 40 |
| evidence contract | 1,035 | 1,050 |
| raw-evidence writer | 1,257 | 1,300 |
| focused evidence tests | 1,450 | 1,450 |

No fifth non-document path, product dependency, independent verifier, PTY,
process-spawn, privileged action or installed-artifact path entered b2a1.

## 3. Review Findings and Closure

The first exact-tree review found two defects on candidate `7a14eb8` / tree
`56d89567`: a P1 final-tree reopen path could accept and close a parent/root/
phase descriptor alias, and a P2 final-tree observation failure could be
misclassified as `inventory`.

Tests-first closure added three test entries with eight final parameterized
scenarios. Before the production fix, the first six scenarios compiled and
failed exactly at the two findings while all 28 pre-existing tests passed. The
writer now centralizes opened-descriptor admission across pending publication
and both final-tree reopen paths, rejects reserved and every held alias without
closing non-owned descriptors, and preserves close failure as the highest
priority. Every final directory/file observation is wrapped with its exact
`validateDirectory` or `validateFinal` stage.

The corrected implementation is commit `e3555ec` / tree `f38783f`. Two
independent post-fix reviews were bound to that exact tree: writer/finding
closure and aggregate package/boundary sanity. Both produced empty JSONL
results and found no unresolved P0-P2.

## 4. Prompt-to-Artifact Checklist

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| Exact package-only target | `Package.swift`; dependency/reverse-dependency review | pass |
| Closed manifest/path/role/cardinality contract | `InvestigationMachineCampaignEvidenceContract.swift`; canonical and mutation tests | pass |
| Attempt mode/outcome/event-chain binding | typed attempt summary in manifest and returned seal; transition tests | pass |
| Coordinator receipt parity | 23-field producer-byte cross-test, frame/EOF/self-hash mutations | pass |
| Owner-private durable writer | descriptor-relative writer and real temporary-tree test | pass |
| Manifest-last and no false seal | post-manifest sync, substitution and post-read drift tests | pass |
| FD ownership and cleanup precedence | reserved/parent/root/phase/cross-phase alias tests | pass |
| Exact observation failure stages | initialization and final directory/root/file fault matrices | pass |
| No product authority or public surface | package/Xcode/source aggregate review | pass |
| Independent from-zero verifier | reserved for ii-c-b2a2 | pending by design |
| PTY/FD 3 transport and aggregate serial | reserved for ii-c-b2b | pending by design |
| Privileged no-model campaign | reserved for ii-c-c | not consumed |
| Real Codex and final full verifier | reserved for L3c3d/L3c4 | not run |

## 5. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| `/usr/bin/swift test --no-parallel --filter InvestigationMachineCampaignEvidenceTests` | 31/31 tests in one serialized suite passed after the final repair |
| `swift build --configuration release --target StornautInvestigationMachineCampaignSupport` | exit 0 on the accepted tree |
| `git diff --check` and frozen scope accounting | exit 0; exactly 4 non-document paths / 3,749 lines |
| initial grouped review | two confirmed findings, both reproduced tests-first |
| exact-tree post-fix writer review | empty JSONL; no unresolved P0-P2 |
| exact-tree aggregate boundary review | empty JSONL; no unresolved P0-P2 |

The retained final code-review reports are
`/tmp/stornaut_iicb2a1_final_91b893c/report.html` (SHA-256
`ad8516e22b1178f61878cc148e756765911435791557d7117e2d437ad7d7f99b`) and
`/tmp/stornaut_iicb2a1_final_91b893c/report.md` (SHA-256
`a80f9a27cf68cd41d05eed9255a03e20175f88dd63db353f0fad47685b621c57`).
The optional repository custom-review endpoint failed local certificate
verification; the required general grouped and post-fix reviews completed.

## 6. Non-Claims and Next Step

b2a1 ran no sudo/root operation, install/uninstall, system launchctl, installed
App/driver/Gate/coordinator, product XPC, real Codex, auth/model/network or
machine campaign. It intentionally ran neither the b2 aggregate serial nor
`scripts/verify --full`; b2b and L3c4 retain those respective gates.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains unavailable. The current frontier is:

```text
ii-c-b2a2 -> ii-c-b2b -> ii-c-c -> L3c3d -> L3c4
```
