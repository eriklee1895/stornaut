# Phase D Task 39B2c L3c3c-ii-b5b-ii Preflight

- Status: ii-b5b-ii-a/ii-b complete/non-admitting; ii-b5b-ii-c current
- Date: 2026-08-22
- Baseline: `06269bca03a5a7b2ca2319b8e029f3cecf7cc6de`
- Admission: non-admitting

## 1. Decision

The fresh post-i-c2 audit rejects implementing the fixed Darwin epoch runtime
as one checkpoint. The credible implementation reaches 14–16 non-document
paths and approximately 5,500–7,500 added lines once the physical runtime,
Darwin identity support, tests and mutation gates are counted. That exceeds the
repository limit of fourteen paths or roughly 4,000 added lines.

The work is therefore split before coding:

1. **ii-b5b-ii-a — fixed FD-0 capsule intake and internal epoch selection**:
   at most seven non-document paths and 2,000 changed lines. The implementation
   review found that the existing installed-driver reader had the same
   `acl_get_entry` return-value defect and that its source-seal verifier was an
   atomic dependency of the new source. The checkpoint therefore includes the
   existing Darwin reader/test and `scripts/verify-contract`, rather than
   leaving either ACL path or verifier replay knowingly inconsistent.
2. **ii-b5b-ii-b — independent Darwin App identity observation**:
   initially at most eight non-document paths and about 2,800 added lines. A
   post-implementation verifier review required the existing Xcode final-Mach-O
   gate as a ninth atomic path because the new Security/process imports change
   both SwiftPM and Xcode binary projections. The reviewed ceiling is therefore
   exactly nine non-document paths while the 2,800-line ceiling remains
   unchanged; the scope gate pins both limits. This checkpoint is complete and
   non-admitting; completion evidence is recorded in the
   [ii-b review](phase-d-task-39b2c-l3c3c-ii-b5b-ii-b-review.md).
3. **ii-b5b-ii-c — fixed FD-7 spawn and bounded duplex session**:
   at most eight non-document paths and about 3,600 added lines. Its exact
   seven-path candidate, typed startup uncertainty and injected ii-d retirement
   boundary are frozen in the
   [ii-c preflight](phase-d-task-39b2c-l3c3c-ii-b5b-ii-c-preflight.md).
4. **ii-b5b-ii-d — exact owned-PGID retirement and aggregate physical proof**:
   at most six non-document paths and about 2,600 added lines.

Any subcheckpoint that approaches its own ceiling must split again before
coding. Package, C-support and Xcode changes are charged separately unless a
pre-implementation trace proves they are unnecessary.

## 2. Aggregate Duties

The four checkpoints provide only the concrete physical implementation behind
the existing single-epoch abstractions:

- bounded FD-0 capsule reading from offset zero through exact EOF, with stable
  descriptor identity, UID/mode/type/link-count, ACL/xattr and size checks;
- strict eight-epoch decode and internal fixed epoch selection, never a caller-
  selected ordinal;
- one `AF_UNIX`/`SOCK_STREAM` socketpair, collision-safe descriptor relocation
  and exactly one child mapping to FD 7;
- fixed installed diagnostic App executable, one-element argv, frozen
  environment and `POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT`;
- strict bounded STNP/STNH I/O, exact deadline behavior, peer write EOF and
  post-drop identity observations;
- independent App identity binding across PID/version, ASID, PPID/PGID, all UID
  and GID fields, supplementary groups, audit token, fixed path, executable hash
  and static/live signing identity; and
- exact owned-PGID inventory, bounded TERM/KILL, waitable-leader handling,
  descendants-empty proof and leader reap last.

## 3. Non-Duties

ii-b5b-ii does not wire the implementation into the native production entry,
launch/install the signed App/helper, invoke sudo/root or real XPC, read auth,
call a model, access a network, author the outer capsule/launcher, accept ADR
0018, emit readiness, or run `scripts/verify --full`. It does not reuse the
generic `ProcessTreeTerminator`, add arbitrary path/argv/environment/signal
inputs, or claim containment of descendants that create a new audit session.

Codex remains a non-root user process. This fixed runtime supplies an App
session to the already implemented typed composer; it does not grant model code
privileged authority.

## 4. Tests-First and Validation

ii-b5b-ii-a completed in
`ea9d2a237ab8e8d1b900f603f54233c94c86ecc0`. Its focused matrix covers wrong
offset, read/write descriptor mode, owner, mode, type, link count,
device/inode/file flags, ACL/xattrs, oversize, short read, trailing growth,
descriptor or offset drift, malformed/non-canonical capsule and
caller-selected ordinal. The exact seven non-document paths are the new intake
source/test, the existing Darwin installed reader and its focused test, the
shared target-boundary test, and the two structural verifier scripts. The
checkpoint passed its one staged-only 1,353-test serial and focused, affected,
structural, Debug/Release projection and independent-review gates without a
full verifier or production runtime invocation. See the
[completion audit](phase-d-task-39b2c-l3c3c-ii-b5b-ii-a-review.md).

Later subcheckpoints add injected syscall matrices plus bounded same-UID child
integration for identity, socket/FD inheritance, EOF and PGID/reap ordering.
Each follows structural → focused → affected → one staged-only serial →
applicable targeted build → independent review. No full verifier belongs to
these non-admitting checkpoints.

## 5. Remaining Order

```text
ii-b5b-ii-c -> ii-b5b-ii-d
-> ii-b5b-iii -> ii-c0 -> ii-c -> L3c3d -> L3c4
```

ii-b5b-iii owns native production/artifact composition. ii-c0 owns the
non-privileged launcher/TTY/capsule evidence. ii-c alone owns the one no-model
privileged installed-driver attempt and potential ADR 0018 acceptance. L3c3d
owns the first current-source authenticated Codex success, and L3c4 alone owns
machine readiness and the remaining authoritative full verifier.
