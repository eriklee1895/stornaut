# Phase D Task 39B2c iii-b2b-1b Zero-Argument Entry Preflight

> Status: historical scope/trust preflight; implementation split into
> iii-b2b-1b-i and iii-b2b-1b-ii; both complete / non-admitting
>
> Date: 2026-08-26
>
> Baseline: `9dfabc0ee666d3667cb6bb42cc888d3ac676d125`
>
> Production/focused implementation:
> `6b2608258d59787bca592012086a2377d647473e` (tree
> `462d40bfc36954ec60c533e946bbd0019470aa88`)
>
> Verifier/Mach-O implementation:
> `1c8ab1d5c06f87f7d2af548228835adcd43a1ae9` (tree
> `d7b6c05fdb90f0db693e8f506e45eae5b98a45f9`)
>
> Immutable verifier seal: `a314b855f9e5d15d3bf7789d95533369b7cb1349`
> (tree `aac9d81a7275e964999ebe1d0d9d057bd8db34a4`)
>
> Scope: source, test and verifier inspection only. No driver execution, App or
> helper launch, XPC, install, root/sudo, model/auth/network use, serialized
> regression or authoritative full verifier was used for this preflight.

## 1. Decision

The original preflight allowed iii-b2b-1b to remain one bounded checkpoint,
but implementation reached its 2,800-line split condition. It was therefore
closed as two independently reviewed checkpoints rather than allowing the
original review surface to grow:

- `iii-b2b-1b-i` owns production and focused tests: exact 5 paths / 2,434
  changed lines, implementation commit
  `6b2608258d59787bca592012086a2377d647473e`, tree
  `462d40bfc36954ec60c533e946bbd0019470aa88`; and
- `iii-b2b-1b-ii` owns verifier and final Mach-O admission: exact 4 paths /
  971 changed lines, implementation commit
  `1c8ab1d5c06f87f7d2af548228835adcd43a1ae9`, tree
  `d7b6c05fdb90f0db693e8f506e45eae5b98a45f9`, followed by immutable verifier
  seal `a314b855f9e5d15d3bf7789d95533369b7cb1349`, tree
  `aac9d81a7275e964999ebe1d0d9d057bd8db34a4`.

The DriverSupport target already contained every heavy component required by
the final non-admitting driver join:

- fixed FD-0 projected-cohort intake;
- one-shot eight-epoch cohort execution;
- production Darwin outer/inner execution factory;
- concrete outer ownership and terminal observers; and
- the complete inner-role validator and `runInner()` path.

The remaining work is limited to one zero-argument entry owner: root/argc and
role selection, outer standard-descriptor admission, exact composition of the
existing components, a canonical completion artifact and bounded FD-1 output.
The local Swift package automatically includes a new source in the existing
target; the Xcode driver links that package product. `Package.swift`, the Xcode
project and the executable `main.swift` therefore remain unchanged.

The preflight's stop rule was exercised: `iii-b2b-1b-i` closed the
role/cohort/artifact production behavior and focused regression, while
`iii-b2b-1b-ii` independently closed verifier and final-Mach-O coverage. The
split did not widen the runtime contract or admit machine readiness.

## 2. Frozen Runtime Flow

The only public executable facade remains:

```text
InvestigationMachineDriverSupport.run()
```

Its fixed flow is:

```text
four-axis root identity + argc == 1
-> inspect fixed FD 8/9 role only
   -> both present: existing InvestigationMachineDarwinInnerRoleValidator
      and InvestigationMachineDarwinOuterInnerComposition.runInner()
   -> both absent with EBADF: outer standard-descriptor admission
      -> current installed-driver observation
      -> InvestigationMachineFixedCapsuleIntake.read() on FD 0
      -> InvestigationMachineEightEpochCohort.run() with the production
         InvestigationMachineDarwinOuterInnerExecutionFactory
      -> canonical non-admitting completion artifact
      -> final stdout/stderr identity revalidation
      -> bounded exact write to FD 1
   -> mixed presence or any non-EBADF lookup failure: reject
```

Role selection occurs before FD-0 consumption. No argument text, environment
selector, caller-selected path, descriptor, PID, endpoint, executable, signal
or cleanup action is accepted. The inner branch reuses the existing complete
validator; it does not duplicate or weaken FD 0/1/2/7/8/9, PID/PPID/PGID,
root, TTY, socket or pipe checks.

The outer entry owns only the missing fixed-descriptor checks. It must require
FD 0/1/2 to be distinct stable nodes, FD 1 and FD 2 to be writable, FD 7/8/9
to be absent, and stderr's TTY/foreground-PGID observation to be valid and
unchanged across the cohort. The existing capsule intake remains the sole owner
of FD-0 regular-file, UID 501, mode `0600`, link-count, offset, ACL/xattr,
bounded read, EOF and metadata validation.

## 3. Completion Artifact

Add one package-only, non-`Codable`, `Sendable` and `Equatable` completion
artifact in the new entry source. It uses `HandoffBinaryTranscript` with fixed
domain `stornaut.task39.machine.driver-completion`, maximum 512 bytes and five
business fields in this order:

1. outer attempt UUID, exactly 16 bytes;
2. whole capsule SHA-256, exactly 32 bytes;
3. whole projected input SHA-256, exactly 32 bytes;
4. completed epoch count, exactly 4-byte big-endian and exactly `8`;
5. completion SHA-256, exactly 32 bytes.

The digest uses zero-before-hash: encode the first four fields plus a 32-byte
zero digest, hash the complete transcript and encode again with that digest.
Decode reconstructs the value from the first four fields, compares the digest
and requires byte-identical canonical re-encoding. Zero UUID/digest, wrong
domain/version/tag/order/length/count, truncation, trailing bytes and payloads
over 512 bytes fail closed. DriverSupport defines local fixed-width UUID and
big-endian helpers because the HandoffContract module's convenience functions
are internal rather than package-visible.

The artifact is emitted only after `InvestigationMachineEightEpochCohort.run()`
returns, which already proves eight sealed epochs, final continuity destruction
and exact ninth-read exhaustion. It contains no helper identity, retirement
handle, continuity token, terminal proof, machine report or readiness value.
FD 1 receives only these canonical bytes, with no JSON, newline or diagnostic
text. The inner branch writes no stdout artifact.

The writer retries `EINTR` and bounded short writes, treats zero or any other
error as transport failure, and never closes or redirects FD 1/2. Cancellation
is checked before output commitment; once the bounded exact write starts, a
successful complete artifact remains success rather than being reclassified by
a late cancellation.

## 4. Exit Status Contract

| Status | Meaning |
| --- | --- |
| `0` | inner completed its fixed protocol, or outer completed eight epochs and committed one canonical artifact |
| `77` | any real/effective UID/GID axis is non-root |
| `78` | reserved legacy `handoffUnavailable`; never success |
| `79` | installed-driver observation unavailable or mismatched |
| `80` | invalid invocation, role, descriptor or projected input |
| `81` | protocol or final-artifact transport failure |
| `82` | containment/terminal uncertainty or any otherwise unclassified failure |
| `83` | cancellation only after containment is known safe |

Containment uncertainty dominates cancellation. Unknown errors map to `82`, not
to protocol failure or success.

## 5. Exact Non-Document Scope and Cost

The original unsplit preflight allowed at most these eight paths to change:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` (new)
3. `Tests/StornautInvestigationTests/InvestigationMachineDriverSupportTests.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineZeroArgumentEntryTests.swift` (new)
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
6. `scripts/verify-contract`
7. `scripts/verify-investigation-boundaries`
8. `scripts/verify-app-release-boundaries`

The original target range was 2,150–2,600 changed lines with a hard ceiling of
2,800. The implementation correctly split instead of exceeding that single
checkpoint budget: 1b-i closed at exact 5 paths / 2,434 changed lines and
1b-ii closed at exact 4 paths / 971 changed lines.
`Package.swift`, `Stornaut.xcodeproj`, `tools/StornautInvestigationMachineDriver/
main.swift`, capsule/cohort/session/composition/observer sources and the
HandoffContract target are explicitly excluded.

## 6. Tests-First Matrix

### Entry and role selection

- each non-root UID/GID axis returns `77` before descriptor or input access;
- `argc != 1` returns `80` before FD-0 access;
- both FD 8/9 absent by `EBADF` selects outer; both present selects inner;
- mixed presence, non-`EBADF` lookup errors, wrong direction or alias reject;
- inner calls `runInner()` exactly once and never observes the installed driver,
  reads FD 0, runs the outer cohort or writes FD 1; outer never calls inner.

### Outer descriptors and ordering

- fixed FD 0/1/2/7/8/9 shape, direction, CLOEXEC and node non-aliasing;
- valid stderr TTY/foreground PGID and stable pre/post FD 1/2 observations;
- all descriptor failure precedes FD-0 consumption; and
- exact success order is authority/argc, role, installed observation, intake,
  cohort, artifact encode, final descriptor revalidation, stdout commit.

### Cohort, artifact and writer

- the production closure directly constructs the fixed intake, cohort and
  Darwin execution factory;
- summary UUID/digests/count project exactly into canonical artifact bytes;
- count other than eight, zero values and every transcript mutation fail;
- cohort/factory/exhaustion/cancellation failures commit zero output;
- `EINTR` and short writes complete exactly, while zero/other errno fail; and
- containment uncertainty dominates cancellation in status mapping.

### Binary and authority boundary

- SwiftPM and Xcode Debug/Release drivers contain the entry, artifact, intake,
  cohort, Darwin factory/observer and inner-role symbols;
- ordinary Debug/Release App, diagnostic main/dylib, lifecycle helper and
  dependency-free Release shell remain negative controls; and
- public widening, `Codable`/JSON, argv/environment/path/descriptor selectors,
  cleanup/Executor/network/readiness authority are rejected.

## 7. Validation Funnel and Non-Claims

```text
source/scope/behavior RED
-> exact entry/artifact focused tests
-> adjacent intake/cohort/outer-inner/observer suites
-> target-boundary test
-> dedicated source/scope/mutation gates
-> scripts/verify-contract
-> scripts/verify-investigation-boundaries
-> scripts/verify-app-release-boundaries
-> exact SwiftPM/Xcode Debug and Release projections
-> one clean staged-only serialized SwiftPM regression
-> independent production/test/verifier/cross-boundary review
-> implementation commit/push
-> separate verifier-only immutable seal
```

The completed outcome follows that split funnel:

- 1b-i passed 1,550 tests across 81 suites. Independent review found four P1
  issues; all four were fixed tests-first, and the post-fix review left no
  unresolved P0–P2.
- 1b-ii passed `scripts/verify-contract` and the App/Release boundary gate with
  exit 0. Its independent review left no unresolved P0–P2.
- The verifier-only immutable seal is commit
  `a314b855f9e5d15d3bf7789d95533369b7cb1349` with tree
  `aac9d81a7275e964999ebe1d0d9d057bd8db34a4`.
- The detailed completion evidence is indexed by the
  [iii-b2b-1b review](phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-review.md).

This checkpoint does not run `scripts/verify --full`, install or launch the
fixed App/helper, invoke real XPC, use root/sudo, call Codex/App Server, read
subscription auth, access the network, accept ADR 0018, produce machine
readiness or enable Deep Dive. It used no root/App/XPC/model/network execution.
Task 39 remains incomplete and iii-b2b-1b is complete/non-admitting. The current
frontier is `ii-c0b`; the strict remaining order is
`ii-c0b -> ii-c -> L3c3d -> L3c4`. Only L3c4 owns the final authoritative full
verifier.

## 8. Prompt-to-Artifact Checklist

| Requirement | Completion evidence | State |
| --- | --- | --- |
| zero-argument fixed role selection | 1b-i production/focused implementation and focused regression | complete |
| reuse existing trusted graph | 1b-i source gate pins intake/cohort/factory/runInner calls | complete |
| canonical non-admitting artifact | 1b-i golden bytes, mutation matrix and self-digest tests | complete |
| bounded exact stdout | 1b-i short-write/EINTR/zero/error tests | complete |
| fixed error precedence | 1b-i exhaustive injected error/status matrix | complete |
| Debug/Release reachability, product absence | 1b-ii exact final-Mach-O controls plus immutable seal | complete |
| scope/cost discipline | split at original 2,800-line ceiling; 5-path/2,434-line and 4-path/971-line checkpoints | complete |
| no premature admission | no full/root/App/XPC/model/network/readiness execution | complete / non-admitting |
