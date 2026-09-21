# Phase D Task 39B2b-ii-E2b-i Code Review and Completion Audit

> Status: Complete; layered relocation and App-linkage validation passed
>
> Date: 2026-08-16
>
> Baseline:
> `fa0e80b30709cb6ec6b9696a1bcc58a4c56fd875`
>
> Scope: concrete cleanup-authority relocation and green authorized App
> linkage

## 1. Current Decision

Task 39B2b-ii-E2b-i is complete. Concrete FileManager Trash,
`ActionExecutor`, `TrashMoving` and cleanup-runtime factory authority now live
in `StornautExecution`. `StornautCore` retains only the package-scoped injected
execution contract, typed failure, immutable Trash receipt and authority-free
runtime state machine.

The ordinary App explicitly links `StornautExecution` because its sealed DEBUG
Task 35 diagnostic source still constructs the approved cleanup authority.
Normal production composition remains `writeDisabled`. The separate
Investigation diagnostic target does not link `StornautExecution`.

This checkpoint does not make a final built-artifact admission claim. E2b-ii
must independently strengthen and run the strict Debug/Release/final-Mach-O
authority gate, complete its review and run exactly one clean authoritative
`scripts/verify --full`. Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`.

## 2. Tests-First Boundary

E2b-i began with a source/package authority assertion that failed for the
intended reason:

```text
Missing E2b concrete execution authority:
Sources/StornautExecution/Actions/CleanupExecutionAuthority.swift
```

The implementation then:

- moved `FileManagerTrashAdapter`, `TrashMoving` and `ActionExecutor` into
  `StornautExecution`;
- moved the production and DEBUG diagnostic runtime factories with the
  concrete authority;
- retained only `CleanupActionExecuting` and
  `CleanupActionExecutionFailure` in Core's former executor file;
- retained only the immutable `TrashedItemReceipt` in Core's Trash file;
- kept Core's cleanup runtime as a package-injected state machine plus the
  recovery-only public factory;
- updated behavioral tests to import `StornautExecution` rather than
  duplicating concrete-authority fixtures;
- updated all affected source and Phase C structural contracts;
- explicitly linked only the ordinary App to the execution product.

The package direction remains one-way:

```text
StornautExecution → StornautCore + StornautProcessSupport
```

No Investigation package or Investigation diagnostic product gained a cleanup
execution dependency.

## 3. Scope and Split Audit

The E2b preflight originally found 14 required non-document paths. The red
gate then identified a fifteenth verifier owner,
`scripts/verify-phase-c-trash-diagnostic-contract`, so E2b was split before
implementation:

- E2b-i owns authority relocation, behavioral compatibility and green App
  linkage;
- E2b-ii owns strict final-Mach-O markers, exact Xcode dependency admission,
  final bundle validation and the one full verifier.

E2b-i changes exactly 14 non-document paths, matching but not exceeding the
hard checkpoint limit. The signed diagnostic composition remains stashed and
outside this write set.

## 4. Layered Validation Evidence

The corrected validation funnel was:

```text
red source/package authority gate
→ package seam tests
→ affected cleanup tests
→ Phase C product/source boundaries
→ targeted ordinary and Investigation diagnostic App builds
→ one serialized SwiftPM regression
→ isolated review
```

Final evidence:

| Gate | Result |
| --- | ---: |
| Package execution seam | 3/3 passed |
| Affected cleanup/execution tests | 32/32 passed |
| Phase C product gate | 73/73 passed |
| Cleanup/source/no-Executor boundaries | passed |
| Ordinary Debug App targeted build | passed in 26.3 seconds |
| Investigation diagnostic Debug App targeted build | passed |
| Serialized SwiftPM regression | 898 tests / 37 suites passed in 136.388 seconds |
| Public concrete-authority leak scan | no matches |
| Core concrete-authority scan | no matches |
| Non-document path budget | 14/14 |
| Diff hygiene | passed |

The platform Trash case followed its explicit opt-in contract and was skipped;
E2b-i did not replay the sealed Task 35 mutation.

E2b-i intentionally did not run `scripts/verify --full`. It is the relocation
half of a pre-approved split, and E2b-ii owns the strict built-artifact
acceptance gate. Running full here would repeat roughly 15–16 minutes of
unrelated UI and fixture work before the final-Mach-O verifier itself is
complete.

## 5. Architecture and Authority Review

The isolated review inspected:

- package/public visibility of every moved authority type;
- dependency direction between Core and Execution;
- Core factory and recovery-only surfaces;
- ordinary App versus Investigation diagnostic Xcode linkage;
- source and product verifier ownership;
- behavioral error mapping after removal of the Core compatibility alias;
- the fixed 14-path non-document budget;
- the prohibition on replacing final-Mach-O evidence with source scanning.

No unresolved P0–P2 findings remain.

The review confirmed that:

- Core contains no concrete Trash, Executor or FileManager Trash authority;
- no concrete cleanup-authority type is public;
- the execution implementation is package-scoped;
- only the ordinary App currently links the execution product;
- the Investigation diagnostic target remains execution-free at the Xcode
  dependency layer;
- production App composition remains `writeDisabled`;
- E2b-ii still has a real, non-duplicated acceptance obligation at the built
  artifact layer.

## 6. Validation-Process Correction

E2b-i demonstrates the repository's corrected testing policy:

1. use the cheapest trustworthy structural failure to prove the test is live;
2. compile and run only affected focused suites;
3. run one serialized regression after focused layers are green;
4. build only the products whose linkage changed;
5. finish isolated review before expensive acceptance;
6. reserve `scripts/verify --full` for the enclosing product/security
   checkpoint.

If E2b-ii's binary gate or final full fails, diagnosis must rerun only the
exact failed gate, stage, suite or case. A new clean full may start only after
the defect is fixed and all cheaper affected layers are green.

This prevents the previous pattern in which a 15–16 minute full verifier was
used as a compile, unit-test or bundle-debugging loop.

## 7. Safety Audit

Task 39B2b-ii-E2b-i does not:

- invoke or replay the sealed Task 35 Trash/recovery mutation;
- enable real Trash in normal product composition;
- link cleanup execution into the Investigation diagnostic;
- launch Codex, invoke a model or create a machine readiness report;
- restore or apply the stashed signed diagnostic composition;
- change Codex write, localhost, private-network or Unix-socket authority;
- edit `~/.codex/config.toml`;
- coordinate, block or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- enable normal-product Deep Dive;
- alter release, signing, notarization, FDA/TCC or distribution claims.

## 8. Next Gate

Task 39B2b-ii-E2b-ii is active. It must:

- strengthen the built-artifact authority marker set;
- enforce the exact Xcode execution-product dependency allowlist;
- inspect the Debug/Release ordinary App and Investigation diagnostic
  products for concrete Trash, Executor, Registered Action and process-runner
  authority;
- prove the Investigation diagnostic does not link `StornautExecution`;
- complete independent review with no unresolved P0–P2;
- run exactly one clean authoritative `scripts/verify --full`;
- commit and push independently before the stashed signed composition resumes.

Machine/model execution remains exclusive to 39B2c.
