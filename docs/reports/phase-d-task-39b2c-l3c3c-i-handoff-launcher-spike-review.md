# Phase D Task 39B2c-L3c3c-i Handoff/Launcher Spike Final Review

> Status: Complete; socketpair/lifecycle candidate retained, external root
> launch rejected, installed-driver implementation pending
>
> Date: 2026-08-19
>
> Baseline: `b15bd082a44b3e2895fc7f150e5018ef37d522df`
>
> Scope: repository-external transport/launcher evidence and documentation only;
> no product implementation, install, privileged execution, model, readiness,
> serial regression or full verifier

## 1. Outcome

L3c3c-i is complete as a study and root-launch audit. It does not accept ADR
0018 or prove privileged behavior.

The study retained the asymmetrically identity-bound unnamed socketpair, strict
protocol, root-to-UID algorithm and exact lifecycle supervision for product
implementation. B3-v8 passed two 19/19 unprivileged matrices and a forced-drain
negative. B4 passed strict compile, non-root and forced-cleanup/static review.
The separate i-b2a review reproduced its unsigned and signed semantic
projections. Those are useful algorithm/protocol facts.

The i-b2b-0a audit then rejected every UID-staged external root-launch variant.
The old `sudo -v` stager creates ambient authority. Separate no-cache stock root
commands cannot make verification an unskippable predicate for execution. Two
independent reviews returned NO-GO. Consequently:

- i-b2b-0b external staging is superseded before execution;
- i-b2b-1 external privileged execution is superseded before execution;
- B4 root execution count remains zero;
- no external root-owned artifact, attempt, result or receipt exists; and
- the external B4/stager/evidence-driver branch must never be root-executed.

The only conditional next candidate is the root-owned installed diagnostic
Machine driver after authority-closed runtime extraction and exact
current-source install/L2 admission. ADR 0018 remains Proposed.

## 2. Prompt-to-Artifact Checklist

| Requirement | Evidence | Result |
| --- | --- | --- |
| parent owns channel before App launch | B3/B4 socketpair before fixed spawn | retained for implementation |
| fixed App/UID only | compile-time launch shape and UID 501 | implemented/reviewed externally; no privileged claim |
| one-shot bounded protocol | nonce/sequence/deadline/EOF/trailing gate | two B3-v8 19/19 runs |
| no JSON/file/helper-reply handle | in-memory binary frame | proved structurally |
| complete two-stage identity | audit/process/path/SHA/signing/DR/CDHash | B3 live, B4 static only |
| cancellation/crash/replay/deadline | exact scenario matrix | B3-v8 green |
| bounded exact cleanup | WNOWAIT/member drain/final SIGKILL/reap-last | B3-v8 and forced negative green |
| B4 reproducibility | normalized unsigned and signed projections | i-b2a complete, historical/non-admitting |
| external root trust anchor | `sudo -v` and no-cache variants | **rejected** |
| external staging and run | fixed `/private/var/tmp` branch | **superseded before execution** |
| current-source root trust anchor | exact installed diagnostic driver | conditionally selected; currently absent |
| accepted ADR | ADR 0018 | **Proposed** |
| product implementation | ii-a/ii-b/ii-c | not implemented |

## 3. Review-Driven Corrections

The external study fixed or rejected these concrete mistakes before product
implementation:

1. inherited `LOCAL_PEERTOKEN` was incorrectly assumed to rebind;
2. ordinary keyed archiving cannot transfer anonymous XPC endpoints;
3. dynamic signing metadata lacked live strict validation;
4. cleanup could miss descendants after leader exit;
5. fixed-FD collision could close the mapped descriptor;
6. double clock sampling could underflow into an infinite poll;
7. terminal trailing bytes were accepted;
8. leader reap could precede exact group cleanup;
9. cancellation/final-exit paths could block forever;
10. parent-crash evidence omitted a same-PGID descendant;
11. cross-UID post-drop admission incorrectly retried task-port access;
12. failed cleanup could discard exact retained identity;
13. `sudo -v` created a reusable ambient timestamp;
14. UID-authored receipts could fabricate semantic success;
15. predictable external staging admitted symlink/path cleanup races; and
16. separate `sudo -kN` commands still provided no root-owned atomic
    verify-and-act predicate.

The final external algorithm uses asymmetric kernel identity, live+static
signing, one monotonic deadline, strict EOF and WNOWAIT/exact-member
drain/reap-last. The product trust anchor changes to the installed driver; it
does not revive the rejected external stager.

## 4. Historical Evidence

```text
B3 source       1bf45400ed991b8aa63a2c6fdfdc9b64b631fc3a790fd376bf24d360a8caab2d
B3 binary       1fea1d8cd16ccefb6d88aa206d46022eebe7f2c27d0e840df6a73892d33349d7
B3 run 1        29d3931cbd908fa0806350b8abc59808d54859b770d6c03c8c37cbb2a45b22eb
B3 run 2        3e06b8c0a8dfb3f34beffd77d9ba100d52f84a3716b522829a0b6fe76c7641ab
B3 forced drain 2f32e04b0a0593f3b9d2b69bd0abb91813ea693d816ab0cda184a62e1e697fbd
B4 source       e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25
B4 binary       d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d
B4 non-root     fd09e37772edaab4ce2ea78fae768b5520cf7755614d5903b9bf8bac777f25d6
B4 forced drain f42d0885d64181f06742f37a09062384f6ffaeea1860c1f76799d88567c4147f
```

The historical B4 hash is not a future execution artifact. Its root execution
count is zero. The i-b2a review remains the authoritative explanation of the
193-byte post-SuperBlob padding difference. The root-launch audit retains the
final7 driver/stager/verifier hashes and explains why those artifacts are
non-admitting.

## 5. Revised Implementation Order

The strict order is:

```text
L3c3c-i complete study/root-launch NO-GO
-> L3c3c-ii-a authority-closed live DriverSupport
-> L3c3c-ii-b fixed installed-driver/App handoff composition
-> L3c3c-ii-c exactly one no-model outer installed-driver gate
-> L3c3d one real-model pending candidate
-> L3c4 final admission and authoritative full
```

The exact path, command, path/line ceilings and validation funnel are frozen in
the
[installed-driver preflight](phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).

ii-c must first build/install the exact current-source diagnostic topology and
repeat static installed-artifact/service-bootstrap admission. It then performs
the exact `sudo -kNnv` non-executing probe, requires the fixed manual prompt and
starts one outer root-owned driver with zero driver arguments. Full installed-L2
follows each App launch before transition/`EXIT`. ii-c must uninstall and prove
zero residue. A started failed outer invocation is not retried to repair an
implementation. No model call occurs in ii-a, ii-b or ii-c.

## 6. Safety and Non-Claims

- Production Deep Dive remains unavailable.
- Real Trash remains closed.
- `~/.codex/config.toml` was not modified.
- No model/auth/capability evidence was consumed.
- No external root artifact or product driver was executed.
- ADR 0018 remains Proposed until a green ii-c machine gate.
- L3c4 alone owns readiness and the remaining full verifier.
- Task 39 remains incomplete.
