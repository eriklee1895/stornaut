# Phase D Task 39B2c-L3c3c Parent-Owned Handoff Study

> Status: external study complete; socketpair candidate retained, external
> root-launch branch rejected, installed-driver implementation pending
>
> Date: 2026-08-19
>
> Baseline: `65804301e4c0abc1c2c6d4c1dac128bfb1af4fed`
>
> Proposed decision: [ADR 0018](../adr/0018-parent-owned-investigation-handoff.md)

## 1. Question and Boundary

L3c3c-i must choose one parent-owned handoff/launcher topology before any
production implementation. The topology must be ready before App launch, carry
no authority through JSON or the filesystem, bind both peers by complete live
identity, keep the App alive until installed-L2 observation, and close
cancellation, crash, replay and deadline paths without residue.

All spike code and raw logs stayed outside the repository under one disposable
`/tmp/stornaut-l3c3ci.*` root. The study installed nothing, registered no Mach
service, invoked no product App/helper/driver, called no model, changed no
Codex configuration and ran neither the serial regression nor the full
verifier. Only this study, the proposed ADR and a privacy-safe review may be
committed.

## 2. Environment and Platform Sources

| Item | Observed |
| --- | --- |
| macOS | 26.5.1, build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, build 17F113 |
| Apple clang | 21.0.0 |
| Interactive user | UID 501, primary GID 20 |
| Kernel credential-group limit | 16 |
| Directory group count | 17 |

The study read the current macOS SDK headers and local man pages for
`socketpair(2)`, `posix_spawn(2)`, Unix peer credentials, Security dynamic/static
code APIs, BSM audit identity and libproc inventory. Context7 did not contain
Apple's Foundation/XPC documentation; its unrelated Swift Foundation and Rust
binding results were not used as evidence. No upstream source was copied.

Relevant platform facts measured or confirmed locally:

- `socketpair(AF_UNIX, SOCK_STREAM)` creates an unnamed, non-persistent duplex
  channel.
- `POSIX_SPAWN_CLOEXEC_DEFAULT` plus explicit file actions can expose exactly
  one fixed child descriptor.
- `LOCAL_PEERTOKEN` records the credentials associated with socket creation or
  connection; it does not rebind when an already-created endpoint is inherited
  across `exec`.
- `task_name_for_pid + TASK_AUDIT_TOKEN` is usable for the same-UID pre-drop
  process, but not as a root-parent mechanism after the child becomes another
  UID.
- `kSecGuestAttributePid`, `proc_pidinfo(PROC_PIDT_SHORTBSDINFO)` and
  `audit_get_pinfo_addr` provide independent post-drop facts without trusting a
  child payload.
- an anonymous `NSXPCListenerEndpoint` may only be encoded by `NSXPCCoder`; an
  ordinary keyed archive cannot turn it into bytes for an inherited raw FD.

## 3. Rejected Candidates

### 3.1 Anonymous XPC endpoint over a raw inherited bootstrap FD

The first candidate created an anonymous listener before spawn and attempted to
archive its endpoint into a bounded frame. Foundation raised:

```text
NSXPCListenerEndpoint encodeWithCoder:
This class may only be encoded by an NSXPCCoder.
```

Using XPC to transfer the endpoint would require another XPC connection and
therefore reintroduce the bootstrap dependency the candidate was meant to
solve. Custom Mach-right transfer would enlarge the implementation and review
surface without a demonstrated need. This candidate is rejected.

Evidence hashes:

```text
source  989f7418dcec5a5412b0558b6ae9ce339ad8f753dc4fc4f99ec83b540b8cb262
binary  498b1b2acde53d17d399134565ad710f2727b9280bac215856c0f39c09bb37f1
report  85c2d04db341723ea1ef089d548c14440f19a52510948ceab6506b58a7b5f553
```

### 3.2 Symmetric peer-token authentication on an inherited socketpair

The raw socketpair candidate initially required each endpoint's
`LOCAL_PEERTOKEN` to name the live peer. The parent created both endpoints
before spawn; after one endpoint was inherited, the parent still observed its
own PID in the peer token rather than the child PID. Ten independent child
launches failed closed before any opaque handle was sent.

```text
expected child PID != observed peer PID
observed peer PID == parent PID
```

Fixed FD inheritance, CLOEXEC-default and process-group isolation do not change
that kernel credential semantic. Symmetric peer-token authentication is
rejected.

Evidence hashes:

```text
source  51d02cb7fafd9d04a5cf5e7db6b1e76baf1ad215870fa53402a6a29604fb2f19
binary  ecec4b52f299e140573fef3eadd23b0504d37779d027def5bc994904153e4674
```

## 4. Conditional Candidate: Asymmetrically Bound Fixed Socketpair

The surviving candidate uses one unnamed duplex socketpair created by the root
parent before launch and mapped to one compile-time fixed App descriptor. Its
identity model is deliberately asymmetric:

- the child validates the creation-time root parent using `LOCAL_PEERTOKEN`,
  exact executable SHA-256, signing identifier, designated-requirement SHA-256
  and CodeDirectory hash;
- the parent owns the exact PID returned by `posix_spawn`, freezes the root child
  audit token before credential drop, and after drop verifies BSD process
  identity, audit-session identity, PID-based live signing, fixed-path static
  signing and executable SHA independently;
- the post-drop child audit token is wire evidence only. Its PID, PID version,
  EUID and ASID must equal the independently observed facts and pre-drop
  baseline before the first business frame is admitted.

The strict duplex state machine is:

```text
parent creates channel
-> child validates root parent
-> PRE_DROP_READY
-> parent freezes pre-drop identity
-> DROP_RELEASE
-> initgroups -> setgid -> setuid
-> DROP_EVIDENCE
-> parent joins post-drop kernel/signing evidence
-> HELLO -> HANDLE -> ACK -> RELEASE -> ALIVE
-> strict child-write EOF, with no trailing byte
-> parent identity recheck -> EXIT
-> bounded group drain -> reap-last
```

The B3/B4 `HANDLE` in this measured spike was a parent-to-child dummy opaque
payload. It proves framing, duplex identity and lifecycle behavior only. The
later product split preflight owns business direction: the real helper-minted
retirement handle travels App-to-driver after the App retires its lifecycle
session; it never travels parent-to-App. The later pre-business
`CONFIGURATION/ACK` exchange is likewise outside this historical spike.

Every frame binds magic, version, message kind, monotonic sequence, random
nonce, one shared monotonic deadline, claimed PID/PID-version/EUID/ASID and a
hard payload limit. The claims do not establish identity; they must match the
already-frozen kernel identity. The first terminal observation permanently
consumes the epoch.

## 5. Unprivileged B3-v8 Evidence

The same-UID B3-v8 spike proves the transport, strict protocol, complete
bidirectional identity shape and lifecycle algorithms without claiming the
root-to-UID transition. Two final runs each contained all 19 scenarios:

- happy path and clean terminal EOF;
- terminal trailing-byte rejection;
- fixed-FD collision with descriptors 3-6 preoccupied;
- early exit and exit after handle receipt;
- stale PID-version claim;
- timeout, replay, concurrent duplicate frame, malformed and oversized frame;
- exec descendant FD leakage;
- child crash;
- leader exit with a live same-PGID descendant;
- cancellation and cancellation hang;
- post-final-exit hang; and
- parent crash with child, descendant and exact PGID disappearance.

All ordinary terminal rows proved channel close, process-group empty, waitable-
only reap and no retained residue. A compile-time-only negative forced the first
drain attempt to fail; the final exact SIGKILL fallback still produced
`reaped=true`, `processGroupClean=true`, `residueRetained=false` and zero
retained PID/PGID. The formal binary contains no forced-test CLI entry.

```text
source       1bf45400ed991b8aa63a2c6fdfdc9b64b631fc3a790fd376bf24d360a8caab2d
binary       1fea1d8cd16ccefb6d88aa206d46022eebe7f2c27d0e840df6a73892d33349d7
run 1        29d3931cbd908fa0806350b8abc59808d54859b770d6c03c8c37cbb2a45b22eb
run 2        3e06b8c0a8dfb3f34beffd77d9ba100d52f84a3716b522829a0b6fe76c7641ab
forced drain 2f32e04b0a0593f3b9d2b69bd0abb91813ea693d816ab0cda184a62e1e697fbd
```

Independent iterative review found and closed deadline underflow, post-reap
PGID reuse, descendant leakage, fixed-FD collision, terminal trailing bytes,
unbounded final wait and exact-identity loss after failed cleanup. The final
B3-v8 review has no unresolved P0-P2.

## 6. Security API Negative Evidence

An independent public-API probe bound a running subject by exact audit token.
Baseline dynamic strict validation succeeded. A deliberately mismatched signing
requirement failed with `-67050`. After the on-disk path was atomically replaced
by an invalid regular file, dynamic validation of the running vnode still
succeeded while independent static-path validation failed with `-67062`.

The platform result is:

```text
platform_preserved_running_vnode_plus_requirement_negative
```

Therefore L3c3c-ii must never treat live-code validity as a path-integrity
substitute. It must keep the full path/SHA plus live and independent static
signing comparison at every trust transition. The subject was terminated and
reaped by exact PID. Result SHA-256:
`d58750f16c97b364ece59bedf1d0aa03706f7645984129c8ffd5df058c09f6c9`.

## 7. B4 Root-to-UID Candidate and Root-Launch Audit

B4 adds a compile-time-fixed UID 501, a root gate before any launch, closed
path/argv/environment, the two-stage identity protocol, kernel-bounded
supplementary groups, irreversible credential reduction and the B3-v8 lifecycle
state machine. On this host the directory service returns 17 groups and the
kernel limit is 16; expected credentials therefore use the accepted R3 rule:
the first 16 directory groups, then an exact sorted comparison with
`getgroups(2)`. The child also proves `setuid(0)`, `seteuid(0)` and `setgid(0)`
all fail with `EPERM`.

Strict compilation and the non-root pre-spawn rejection passed. A compile-time-
only forced-drain build exercised the final SIGKILL fallback and left no retained
identity. Two independent static reviews over the formal candidate found no
unresolved P0-P2.

```text
source          e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25
formal binary   d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d
non-root result fd09e37772edaab4ce2ea78fae768b5520cf7755614d5903b9bf8bac777f25d6
forced drain    f42d0885d64181f06742f37a09062384f6ffaeea1860c1f76799d88567c4147f
```

The privileged machine run did **not** execute. B4 root execution count is zero
and no root attempt receipt exists. The Terminal authentication request was
cancelled before staging; this is neither a staging pass nor failure. No
result/stdout/stderr/return-code artifact was created and the repository stayed
clean.

The later i-b2b-0a audit initially tried to close provenance with a root-owned
stager and evidence driver. That branch is now complete with a NO-GO decision:

- `sudo -v` creates ambient cached root authority broader than one diagnostic
  action;
- replacing it with separate `sudo -kN` stock commands removes cache reuse but
  does not make root hash/signature verification an unskippable prerequisite to
  a later root command;
- macOS exposes no public `fexecve`/`execveat` path that would atomically execute
  a held verified descriptor; and
- a sudoers digest rule could supply a root-owned predicate, but installing
  persistent system policy is outside this prerequisite and would still need to
  override broad administrator fallback policy.

Two independent reviews rejected the current no-cache WIP. Therefore i-b2b-0b
external staging and i-b2b-1 external privileged execution are **superseded
before execution**, not pending gates. The B4 source, binary, driver and verifier
hashes remain historical, non-admitting evidence for the transport, transition
and failure taxonomy. They must never be root-executed.

The audit conditionally selects the exact root-owned installed diagnostic driver
as the only remaining trust-anchor candidate. This is a plan selection, not an
accepted design or machine result.

## 8. Historical Three-Layer Reproducibility Evidence

Independent preflight returned NO-GO under the former literal requirement that
a fresh `codesign` reproduce the entire reviewed signed-file SHA. The measured
drift is exactly 193 bytes of padding after the declared SuperBlob, inside the
file-backed `__LINKEDIT` / allocated `LC_CODE_SIGNATURE` range but outside all
parsed signature blobs and CodeDirectory coverage. It is not a source, object or
parsed-signature difference. The amended gate has three mandatory layers:

1. **Exact historical artifact:** the reviewed formal binary has full SHA-256
   `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d`.
   It was never root-executed and cannot become the installed-driver run input.
2. **Normalized unsigned projections:** a fresh `-O2` /
   `FIXED_TARGET_UID=501` build from source SHA-256
   `e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25`
   must reproduce the reviewed object and both complete-Mach-O normalized
   unsigned projections. Normalization may strip the signature and, in the
   stated comparison, zero only `LC_UUID`; it may not copy reviewed padding.
3. **Signed semantic projection:** fresh and reviewed artifacts must have the
   same fixed identifier, strict-valid signature, CodeDirectory and complete
   bytes through the declared SuperBlob end. The only permitted whole-file
   drift is the exact measured offset/value relation for the post-SuperBlob
   padding; any parsed-blob, CodeDirectory, other-offset or additional difference
   fails closed.

Exact hashes, offsets, projection procedure and checklist remain frozen in the
[i-b2a reproducibility contract review](../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md).
i-b2a is complete only as historical reproducibility evidence. It cannot admit
the rejected external branch or substitute for current-source installed-driver
identity. See the
[root-launch trust-anchor audit](../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md).

## 9. Revised Installed-Driver Gate

The current-source product route is split before implementation:

1. **L3c3c-ii-a** extracts an authority-closed live runtime into the existing
   zero-dependency DriverSupport graph and repeats Debug/Release final-Mach-O
   authority gates.
2. **L3c3c-ii-b** composes the fixed installed driver, socketpair, fixed App,
   root-to-UID transition, opaque handle, installed-L2 barrier and exact
   retirement using only non-privileged/fake validation.
3. **L3c3c-ii-c** builds and installs the exact current-source diagnostic
   topology and repeats static installed-artifact/service-bootstrap admission.
   It then requires nonzero `sudo -kNnv`, the fixed manual prompt and exactly one
   no-model outer invocation of the fixed root-owned driver with zero driver
   arguments. Full installed-L2 follows each App launch before transition/`EXIT`;
   ii-c must uninstall and prove zero residue.

The exact path, invocation, path/line ceilings and validation funnel are frozen
in the
[installed-driver preflight](../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).
Only a green ii-c gate may move ADR 0018 from Proposed to Accepted. L3c3d then
owns one real-model pending candidate; L3c4 alone owns readiness and the
remaining authoritative full verifier.
