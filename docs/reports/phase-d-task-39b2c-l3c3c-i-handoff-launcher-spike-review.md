# Phase D Task 39B2c-L3c3c-i Handoff/Launcher Spike Conditional Review

> Status: Conditional; i-a/i-b1/i-b2a complete, privileged i-b2b not executed
>
> Date: 2026-08-19
>
> Baseline: `65804301e4c0abc1c2c6d4c1dac128bfb1af4fed`
>
> Scope: repository-external transport/launcher evidence and Proposed ADR only;
> no product implementation, install, model, readiness or full verifier

## 1. Outcome

L3c3c-i is not complete. The external study selected one conditional candidate
and closed its unprivileged transport/lifecycle design, root-to-UID code design,
non-root gate, cleanup negative and static reviews. The separate
[i-b2a reproducibility contract](phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
is also complete. The one mandatory administrator-authorized i-b2b B4 run did
not execute, so
[ADR 0018](../adr/0018-parent-owned-investigation-handoff.md) remains Proposed
and L3c3c-ii cannot start.

This is a truthful checkpoint rather than a readiness proxy. There was no
repository product-code change, no serial/full run, no install or launchd
mutation, no product App/helper/driver execution and no model call.

## 2. Prompt-to-Artifact Checklist

| Requirement | Evidence | Result |
| --- | --- | --- |
| parent owns channel before launch | B3/B4 socketpair constructed before `posix_spawn` | proved in external spike |
| fixed App/UID only | B4 compile-time UID 501, fixed self path, minimal env, no caller launch inputs | implemented/reviewed; privileged observation pending |
| one-shot, bounded, non-persistent | unnamed socketpair, strict state/nonce/sequence/deadline, EOF/trailing gate | two B3-v8 19/19 runs |
| no JSON/filesystem/helper-reply handle | binary in-memory frame only | proved structurally in spike |
| complete peer identity | audit/process/path/SHA/signing/DR/CDHash, two-stage root-to-UID join | B3 live; B4 implemented/reviewed, privileged pending |
| reproducible B4 projections | exact execution SHA plus normalized unsigned and signed semantic projections | i-b2a complete |
| cancellation, App crash, driver crash, replay, deadline | exact scenarios plus hang and forced-drain negatives | B3-v8 green |
| zero residue | WNOWAIT/exact member/final SIGKILL/reap-last/retained identity | B3-v8 and forced negative green |
| App remains alive through installed-L2 | `ALIVE -> strict EOF -> parent check -> EXIT` barrier | transport proved; product composition deferred |
| exact root-to-UID machine behavior | exact `d157…` B4 formal binary | **i-b2b not executed** |
| accepted ADR before product code | ADR 0018 | **Proposed, not Accepted** |

## 3. Scope and Cost

All executable spike work stayed outside the repository. This checkpoint changes
documentation only and adds zero non-document source/test/script paths. It does
not consume a serial regression or authoritative verifier checkpoint.

The external spike was split during investigation into:

- **i-a** — candidate comparison, transport/identity/protocol/lifecycle matrix;
- **i-b1** — root-to-UID candidate implementation, non-root gate, forced-cleanup
  negative and static review; and
- **i-b2a** — exact execution-artifact and signed-projection reproducibility
  contract, complete; and
- **i-b2b** — one privileged root-to-UID machine run, still pending.

The split prevented a system authorization gap from being hidden inside a large
production implementation checkpoint.

## 4. Review Findings and Fixes

Iterative independent review found and closed the following deterministic
problems before the final B3/B4 candidates were frozen:

1. inherited `LOCAL_PEERTOKEN` was incorrectly assumed to rebind to the child;
2. ordinary keyed archiving could not transfer anonymous XPC endpoints;
3. dynamic code metadata was read without live strict validation;
4. cleanup could skip same-PGID descendants after leader exit;
5. fixed FD collision could close the newly mapped child descriptor;
6. a double clock sample could underflow into an infinite `poll`;
7. terminal trailing bytes were accepted;
8. leader reap could occur before exact PGID cleanup;
9. cancellation and final-exit hangs could reach blocking waits;
10. parent crash evidence omitted a same-PGID descendant;
11. cross-UID post-drop admission incorrectly retried task-port access;
12. `cancel_hang` was unreachable; and
13. failed cleanup could discard an unreaped exact PID/PGID.

Final code uses asymmetric kernel identity, live+static signing, one monotonic
sample, strict terminal EOF, WNOWAIT/exact-member drain/reap-last, bounded final
SIGKILL and retained identity on unresolved residue. B3-v8 and the formal B4
candidate received independent post-fix reviews with no unresolved P0-P2.

## 5. Evidence Summary

### B3-v8

```text
source       1bf45400ed991b8aa63a2c6fdfdc9b64b631fc3a790fd376bf24d360a8caab2d
binary       1fea1d8cd16ccefb6d88aa206d46022eebe7f2c27d0e840df6a73892d33349d7
run 1        29d3931cbd908fa0806350b8abc59808d54859b770d6c03c8c37cbb2a45b22eb
run 2        3e06b8c0a8dfb3f34beffd77d9ba100d52f84a3716b522829a0b6fe76c7641ab
forced drain 2f32e04b0a0593f3b9d2b69bd0abb91813ea693d816ab0cda184a62e1e697fbd
```

Each final run contains 19 contained scenarios, complete bidirectional identity
evidence and no retained residue.

### Live Security behavior

```text
baseline dynamic strict       0
mismatched requirement       -67050
post-rename dynamic strict    0
replacement static strict    -67062
result SHA-256 d58750f16c97b364ece59bedf1d0aa03706f7645984129c8ffd5df058c09f6c9
```

### B4 i-b1

```text
source          e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25
formal binary   d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d
non-root result fd09e37772edaab4ce2ea78fae768b5520cf7755614d5903b9bf8bac777f25d6
forced drain    f42d0885d64181f06742f37a09062384f6ffaeea1860c1f76799d88567c4147f
```

The formal product candidate does not contain the compile-time forced-cleanup
entry or an environment test seam. Two fresh static reviews found no unresolved
P0-P2.

### B4 i-b2a

The [reproducibility contract review](phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
records the fresh `-O2` / fixed-UID object, two matching normalized unsigned
complete-Mach-O projections, matching fixed-identifier CodeDirectory and the
bounded 193-byte post-SuperBlob padding difference. It prohibits copying that
padding and preserves `d157…` as the exact whole-file identity for execution.

## 6. Privileged Gate Status

Two standard macOS administrator prompts were initiated for the same formal
binary. Neither prompt completed, no B4 result/stdout/stderr/return-code file was
created and the binary never opened in a process. Both pending prompts were
cancelled. A read-only follow-up confirmed repository cleanliness and no change
to Stornaut install/plist paths.

Therefore i-b2b is **not run**, not failed and not passed. The next step is
exactly one authorized disposable invocation of the `d157…` B4 artifact, with
that full SHA checked before/after and bound into source/binary/output evidence,
followed by exact PID/PGID residue checks and independent review. No production
handoff code may be written first.

## 7. Safety and Admission

- Production Deep Dive remains unavailable.
- Real Trash remains closed.
- `~/.codex/config.toml` was not modified.
- No model/auth/capability evidence was consumed.
- `scripts/verify --full` remains reserved for L3c4.
- L3c3c-ii remains blocked on i-b2b plus acceptance of ADR 0018.
- Task 39 remains incomplete.
