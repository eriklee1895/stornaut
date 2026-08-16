# Phase D Task 39B2b-ii-E2a Code Review and Completion Audit

> Status: Complete; approved package-only validation substitution passed
>
> Date: 2026-08-16
>
> Baseline:
> `23cb9fbe1494f3fe0dd6bd82bb82c99a5d13fb2f`
>
> Scope: package-scoped cleanup execution seam and historical Task 35 source
> snapshot correction

## 1. Current Decision

Task 39B2b-ii-E2a is complete. `StornautCore` now exposes only the minimum
package-scoped injected cleanup coordination, policy and accounting contracts
that the sibling `StornautExecution` target will need during E2b.

This checkpoint moves no concrete Trash, FileManager or Executor authority. It
does not change an App or Xcode target, alter a final Mach-O, invoke Trash,
launch Codex, call a model, compose the signed Investigation diagnostic or
make a readiness claim.

Task 39 remains incomplete. E2b must move the concrete authority out of the
Core dependency closure, explicitly link only authorized products and pass the
strict final-binary/Release gates plus one authoritative full verifier.
Production Deep Dive remains `.implementationUnavailable`.

## 2. Tests-First Boundary

The cross-target package seam test was added before the visibility change. Its
initial compile failed for the intended reason: the sibling
`StornautExecutionTests` target could not access the internal cleanup
coordinator and injected contracts.

The final seam:

- adds a dedicated `StornautExecutionTests` target;
- makes the injected Store, action-execution, volume-sampling and per-item
  policy-collection protocols package-scoped;
- makes the coordinator, request, authorization issuer and required context
  data package-scoped;
- introduces the package-scoped `CleanupActionExecutionFailure` contract so
  the coordinator does not depend on the concrete Trash implementation's
  error type;
- retains `TrashMovingError` as an internal compatibility alias;
- keeps `ActionExecutor`, `TrashMoving`, `TrashAdapting` and
  `FileManagerTrashAdapter` internal to Core until E2b moves them;
- rejects public API leakage and concrete-authority package leakage in the
  structural verifier.

The package graph remains:

```text
StornautCore → CSQLiteSupport + StornautProcessSupport
StornautExecution → StornautCore + StornautProcessSupport
```

No Investigation or diagnostic target gained an execution dependency.

## 3. Scope and Cost Audit

E2a changes 12 non-document source, test, workflow and script paths. It adds
approximately 192 non-document lines and deletes 53. It remains below the hard
split gate of 14 non-document paths or approximately 4,000 added
non-document lines.

The change is intentionally separate from E2b. Combining package visibility,
concrete authority migration, App/Xcode linkage and final Mach-O inspection
would recreate the oversized review and validation surface that caused earlier
Task 39 iterations to progress slowly.

## 4. Focused and Headless Evidence

The approved validation funnel was:

```text
red cross-target compile gate
→ focused package seam tests
→ focused cleanup regression
→ source/receipt/contract boundaries
→ one scripts/verify --headless
→ targeted Debug App build
→ isolated post-implementation review
```

Final evidence:

| Gate | Result |
| --- | ---: |
| Package seam tests | 3/3 passed |
| Focused cleanup suite | 47/47 passed in about 4 seconds |
| Cleanup execution/policy boundaries | passed |
| Task 35 receipt historical binding | passed |
| Verifier contract | passed |
| Documentation links and diff hygiene | passed |
| `scripts/verify --headless` | 8/8 stages passed |
| Serialized SwiftPM regression inside headless | 893 tests / 37 suites passed |
| Targeted Debug App build | passed in 48.6 seconds |

The headless stage durations were:

| Stage | Seconds |
| --- | ---: |
| source boundaries | 4.900 |
| localization contract | 0.082 |
| verifier contract | 4.026 |
| docs and diff | 0.406 |
| serialized SwiftPM tests | 89.481 |
| rule compiler | 18.464 |
| App contract tests | 42.066 |
| Phase C product tests | 11.292 |
| **Total timed stages** | **170.717** |

The headless run owns E2a's only serialized SwiftPM regression; no redundant
standalone serial run was performed before or after it.

E2a intentionally did not run XCUITest or `scripts/verify --full`. It changes
neither UI nor final product authority, and the approved brief records
headless plus a targeted App build as the risk-equivalent substitution. E2b
still owns the strict final Mach-O, Debug/Release bundle, Xcode linkage and
single clean full acceptance gate.

## 5. Validation-Process Correction

The repository guidance now treats `scripts/verify --full` as a final
acceptance gate rather than a debugging loop:

1. fail first at the cheapest trustworthy structural or contract layer;
2. run only affected focused suites;
3. run one serialized regression, without duplicating the run already owned
   by headless;
4. run only the applicable App, binary or host-state gate;
5. complete review and rerun only affected failures;
6. start one uninterrupted full verifier only for the enclosing product or
   security checkpoint.

E2a's 170.717-second headless run is approximately 82 percent shorter than
E1's 954.459 seconds of timed full-verifier stages. Including the 48.6-second
targeted App build, E2a's broad executable gates totaled approximately
219.317 seconds, about 77 percent less than that previous full run. More
importantly, this checkpoint avoided approximately 542 seconds of unrelated
XCUITest and approximately 149 seconds of Debug/Release fixture work without
weakening the enclosing E2b acceptance gate.

If a future focused, headless, binary or full stage fails, only the exact
failed stage, suite or case is rerun during diagnosis. A new final full starts
only after the defect is fixed and all cheaper affected gates are green.

## 6. Task 35 Historical Receipt Correction

The immutable Task 35 signed Trash receipt remains unchanged. Its source hashes
are historical evidence, not a requirement that all future cleanup source
remain byte-identical.

E2a adds a checked sidecar that fixes the receipt's last rolled-forward source
snapshot to:

```text
commit:
23cb9fbe1494f3fe0dd6bd82bb82c99a5d13fb2f

receipt SHA-256:
23dd2c3f8df8739c55ebe1873f4a72923051f5c359a81c968fa6d08c6efc2383
```

The receipt verifier now:

- requires the exact checked sidecar;
- verifies the immutable receipt digest;
- requires the snapshot commit to exist and be an ancestor of current HEAD;
- verifies every recorded source hash against the exact Git blob at that
  commit;
- continues to verify the original receipt artifact/outcome contracts;
- leaves current-source admission to the live Phase C structural and product
  gates.

CI checkout now uses full history so the historical blob verifier cannot be
silently bypassed by a shallow clone. This does not claim that the E1 build or
any later build performed the already-consumed Task 35 mutation.

## 7. Isolated Review

The post-implementation review separately inspected:

- package/public visibility and concrete-authority leakage;
- the package dependency direction;
- coordinator error typing and compatibility behavior;
- Task 35 receipt immutability and ancestor/blob semantics;
- CI history availability;
- source/test/script path budget;
- the approved full-verifier substitution.

No unresolved P0–P2 findings remain.

The review confirmed that:

- E2a exposes injection contracts, not concrete cleanup authority;
- no public cleanup execution API was added;
- no Investigation or diagnostic product links `StornautExecution`;
- no App/UI, Xcode target or final-binary behavior changed;
- receipt verification is stronger and historically honest;
- E2b, not E2a, remains responsible for final-binary proof and authoritative
  full acceptance.

## 8. Safety Audit

Task 39B2b-ii-E2a does not:

- invoke or replay the sealed Task 35 Trash/recovery mutation;
- move `ActionExecutor`, `TrashMoving` or FileManager Trash authority;
- link cleanup authority into Investigation or diagnostic products;
- launch Codex, invoke a model or assemble a machine report;
- change Codex write, localhost, private-network or Unix-socket authority;
- edit `~/.codex/config.toml`;
- coordinate, block or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- enable normal-product Deep Dive;
- alter release, signing, notarization, FDA/TCC or distribution claims.

## 9. Next Gate

Task 39B2b-ii-E2b is active. It must use tests-first structural and final-binary
coverage to:

- move concrete FileManager Trash, `ActionExecutor` and runtime composition
  out of the Core dependency closure;
- link concrete execution only from explicitly authorized ordinary App paths;
- keep the Investigation diagnostic free of Cleanup, Trash, Registered Action
  and process-execution authority;
- pass focused tests, Release/final-Mach-O inspection, independent review and
  exactly one clean authoritative `scripts/verify --full`;
- commit and push independently before the stashed signed composition resumes.

Machine/model execution remains exclusive to 39B2c.
