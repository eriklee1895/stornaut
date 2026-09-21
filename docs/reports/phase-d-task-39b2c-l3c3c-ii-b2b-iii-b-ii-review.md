# Phase D Task 39B2c-L3c3c-ii-b2b-iii-b-ii Physical Adapter Review

> Status: Complete; library-owned checked physical clock, cancellable relative
> scheduler, fixed exactly-once terminal action, helper fixed composition,
> executable source/mutation/final-Mach-O gates, one staged-only serial and
> independent post-fix review passed; non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `a494c4f09f7c55467036abe8c129a292d3957f48`
>
> Validated tree: `0ba6cbe5a6e7a2507b02bf1c1a697742929ca319`
>
> Staged validation commit: `6297d4fd4868aa309110bb60db50cfd42e418824`
>
> Scope: executable physical-adapter closure only; no fixed Machine client,
> App/helper launch, real XPC, install, privilege, model/auth, readiness or
> authoritative full verifier

## 1. Outcome

L3c3c-ii-b2b-iii-b-ii is complete. The checked Darwin clock, relative
`ContinuousClock` scheduler and fixed terminal action now live inside the
`StornautInvestigationMachineClaimServer` package rather than as untestable
helper-private implementations. The helper calls one public convenience
initializer with its exact shared `LifecycleMachineRetirementEscrow`; it cannot
select a task factory, action, exit status or delay.

The physical clock performs checked `mach_continuous_time` timebase conversion
and a finite, positive, conservative-floor wall-time conversion. The scheduler
computes the exact positive relative duration, rejects values outside `Int64`,
suppresses cancel-before-fire and duplicate callbacks, cancels a late task when
callback-before-return wins, and lets the effect executor re-observe time at the
callback boundary. The terminal mapping is exactly once: post-reply success maps
to immediate status `0`; every failure reason maps to status `71` after exactly
100 milliseconds.

The previous helper-local clock, scheduled handle, scheduler and terminal types
were removed. Final artifacts prove the complete server/effect/physical symbol
set is present only in each Debug/Release lifecycle helper and absent from every
ordinary, diagnostic, Release-shell and Machine-driver main image in the frozen
matrix. Completion closes iii-b and ii-b2b.

## 2. Scope, Cost and Artifact Identity

The implementation changed exactly the nine approved non-document paths and
1,571 added-or-deleted lines (1,295 additions, 276 deletions), below the frozen
2,200-line ceiling. `Package.swift`, HandoffContract, Xcode project/schemes,
App/runtime/DriverSupport/native-driver sources and every new file remained
frozen.

The implementation commit is the direct child of
`520bd1006bc2d9ae4aed6da129184aa664300b82`. Its tree
`0ba6cbe5a6e7a2507b02bf1c1a697742929ca319` exactly matches the sole valid
staged validation commit `6297d4fd4868aa309110bb60db50cfd42e418824`; both
commits have the same parent. The implementation commit is pushed to
`origin/main`.

Verifier source identity at that tree is sealed as follows:

- `scripts/verify-investigation-boundaries`: `1c4e2993bc12ee287490dbf7ca30351fbc619192229e767ed854a54d2f00978a`;
- `scripts/verify-app-release-boundaries`: `6e74384710c8768c01593db0943e855e8b8dad59ceaef72a3d51a95087be742c`; and
- normalized `scripts/verify-contract`: `de15307d5413f1d1df605db8787906d699ae162af4e84d3981df1f3eb25f3ea4`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| checked continuous conversion | injected timebase tests cover fractional floor, zero values and multiplication/result overflow; default Darwin observation executes | satisfied |
| checked wall conversion | finite/positive/exact-`Int64` tests cover fractional floor, zero, negative, infinity, NaN and overflow | satisfied |
| exact relative deadline | injected scheduler records exact subtraction and rejects due/past and over-`Int64` durations | satisfied |
| cancel before fire | manual task test proves no callback and exactly one task cancellation | satisfied |
| cancel across physical deadline | default `ContinuousClock` task is cancelled, the test waits beyond its 100 ms due time and observes no callback | satisfied |
| callback before task return | synchronous task factory drives callback-before-install; late handle cancels exactly once and effect slots converge to zero | satisfied |
| fresh callback observation | physical scheduler plus effect executor observes once for schedule and once at callback | satisfied |
| terminal once and fixed mapping | all thirteen reasons map to exactly one fixed action; source parser and mutation freeze status/delay | satisfied |
| narrow terminal authority | parser allowlists the one private property, method and complete call sequence; extra `system` mutation rejects | satisfied |
| helper fixed composition | source gate and executable mutation bind the helper call to the same escrow and no selectable physical inputs | satisfied |
| no duplicate helper implementation | helper source tests/gates reject all physical type and Darwin clock markers | satisfied |
| helper-only final artifacts | Debug/Release helper positives plus per-image five-symbol negatives and exact two-selector surface | satisfied |
| exact scope and cost | executable historical iii-b-i seal plus current nine-path/2,200-line gate; observed 9 / 1,571 | satisfied |
| no authority or admission expansion | no fixed client, App/helper launch, real XPC, install/privilege/model/auth/readiness/full | satisfied |
| one valid serial and independent review | exact validated tree passed once; post-fix review has no unresolved P0-P2 | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| exact final-tree focused gate | 51 tests in 3 suites passed |
| development affected regression | 504 tests in 42 suites passed before the final verifier-only review fixes; production source was unchanged afterward |
| focused production coverage | adapter + effects: 146 functions / 1,204 lines; 95.21% / 92.28%; effects alone 96.39% / 94.13% |
| `scripts/verify-contract` | exit 0; physical clock/scheduler/terminal, helper composition, terminal authority, five-symbol negatives and dual-scope mutations passed |
| `scripts/verify-investigation-boundaries` | exit 0; package/source/authority, historical iii-b-i identity and current scope gates passed |
| exact final-tree `scripts/verify-app-release-boundaries` | exit 0; Debug/Release helper positives and per-non-helper five-symbol negatives passed |
| sole valid staged-only serial | 1,223 tests in 58 suites passed |
| serial timing | 112.825 seconds test time; 172.09 seconds wrapper real time |
| serial identity | validation `6297d4f...`, implementation `a494c4f...`, identical tree `0ba6cbe...` |
| independent review | five P1 verifier/test reliability findings repaired; final post-fix review found no unresolved P0-P2 |
| diff hygiene | exact approved paths, no unstaged/untracked drift, `git diff --check` passed |

The first wrapper invocation omitted `--staged --`, exited `64` during argument
parsing and did not create a validation commit or start SwiftPM; it was not a
valid serial attempt. The sole valid serial ran once and passed without retry or
restart.

That valid command used raw `swift test --no-parallel` instead of the standard
five-test skip expression. Consequently all five normally isolated maximum
benchmarks ran in the serial, including the 256 MiB source and 100,000-row
candidate benchmarks; all passed, but they added roughly 32 seconds and violated
the repository's ordinary-serial cost-routing convention. No serial was rerun to
hide the deviation. Future checkpoints must use the standard skip expression;
maximum benchmarks remain owned by the final full verifier.

No authoritative full verifier ran. No test, report or artifact gate in this
checkpoint substitutes for ii-c's privileged machine gate or L3c4's readiness
admission.

## 5. Independent Review and Repairs

Independent grouped and post-fix review found five P1 evidence-reliability
defects, all fixed before the staged tree was sealed:

1. non-helper Mach-O negatives scanned only the server class, not the new
   physical/effect types; the gate now scans an exact five-symbol array per
   image, and executable mutations cover both array and `$marker` argument drift;
2. the terminal authority exception used an incomplete blacklist; it now
   allowlists the exact property, method and complete call sequence;
3. the source gate proved the convenience initializer definition but not the
   helper call site; it now binds the exact same escrow composition and mutates
   it independently;
4. the default scheduler cancellation test waited only 20 ms before a one-second
   deadline; it now waits 150 ms past a deterministic 100 ms physical deadline;
5. the Mach-O parser proved loop presence but not that each iteration scanned
   `$marker`; the canonical parser and mutation now bind the exact argument.

The final review has no unresolved P0-P2.

## 6. Non-Admission and Next Gate

This checkpoint is non-admitting. It did not launch the App/helper, invoke real
XPC, create a fixed Machine client, install or execute a privileged artifact,
call a model, consume authorization, prove installed-L2/runtime residue or make
a readiness claim.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b3 concrete App drop/no-auth retirement
adapter.
