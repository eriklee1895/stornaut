# Phase D Task 39B2c ii-c-b2a2 Independent Verifier Completion Audit

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-08-31
>
> Implementation: `294bdb207e572eead2be43921e603ce7407dcbc5`
>
> Baseline: `cf1cbed8beff60cdd606bf7025fcef8a2768ff99`
>
> Accepted tree: `dbbffbbae4a1ed51504e664cec7a43ff1e8cbe5d`
>
> Next frontier: ii-c-b2b non-privileged PTY / FD 3 transport

## 1. Result

ii-c-b2a2 is complete and remains non-privileged and non-admitting. It adds an
independent read-only verifier that consumes an exact evidence root plus an
external seal without importing, building or calling CampaignSupport or
CoordinatorSupport. A manifest alone is never admission.

The verifier independently parses and canonically re-encodes every STNC
manifest, entry, attempt-summary, event and coordinator-receipt frame; binds
attempt, source, build and signed-runtime identities; recomputes every digest,
event chain and accounting total; and rejects unknown schema, malformed frames,
missing or extra nodes, aliases, traversal, metadata drift and noncanonical
JSON. Canonical JSON is checked with the same system Foundation serializer used
by the Swift producer, while Python remains an isolated standard-library
consumer for schema validation.

All evidence and seal paths are opened component-by-component from `/` with
no-follow/beneath/unique semantics and exact directory-entry spelling. Every
ancestor, root, phase, manifest, artifact and seal descriptor is registered
with a vnode change queue before validation or reading and stays held until the
final identity, bytes, inventory and path-spelling pass. A single nonblocking
zero-event drain is the verification linearization point; any observed write,
extend, attribute, link, rename, delete or revoke change fails closed.

## 2. Exact Scope and Budget

Relative to the frozen b2a1 closure, the accepted implementation changes
exactly six non-document paths and 1,999 lines, below the 2,000-line ceiling:

| Path | Added | Deleted |
| --- | ---: | ---: |
| `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` | 269 | 3 |
| `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` | 59 | 2 |
| `scripts/verify-app-release-boundaries` | 301 | 14 |
| `scripts/verify-contract` | 223 | 89 |
| `scripts/verify-investigation-boundaries` | 276 | 1 |
| `scripts/verify-investigation-runtime-machine-report` | 760 | 0 |

No SwiftPM product, Xcode target/scheme reference, installer role, production
dependency, process spawn, PTY, sudo/root operation, model, network, XPC or
cleanup authority entered this checkpoint.

## 3. Review Findings and Closure

Independent exact-tree reviews found and closed the following concrete issues
inside this checkpoint:

- Python and Foundation JSON serialization were not byte-equivalent; the
  verifier now delegates canonical round-trip bytes to system Foundation and
  retains independent Python schema/type validation.
- `realpath` normalized traversal and parent-symlink aliases; paths now require
  canonical absolute spelling and descriptor-relative no-follow traversal.
- case-insensitive APFS aliases and post-open case-only renames were accepted;
  exact directory-entry spelling is checked both initially and finally.
- sequential file checks lacked a whole-tree linearization point; all
  descriptors now remain held and vnode watches are drained exactly once after
  final whole-tree revalidation.
- a descriptor could leak if observation failed immediately after `open`; each
  descriptor is now registered for cleanup before the first fallible check.
- caller-controlled `PATH`, marker-only Swift assertions and the final Mach-O
  scanner each allowed structural gates to become vacuous; fixed system tools,
  exact assertion forms, region hashes, call-count checks and dedicated
  mutations close those paths.

The final verifier/security and cross-boundary reviews are bound to the accepted
tree and contain no unresolved P0-P2. Shared-ancestor vnode writes can produce a
conservative false rejection under unrelated concurrent filesystem activity;
that is an explicit fail-closed behavior, not an admission bypass.

## 4. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| `swift test --no-parallel --filter InvestigationMachineCampaignEvidenceTests` | 38/38 tests passed |
| `swift test --no-parallel --filter InvestigationMachineTargetBoundaryTests` | 51/51 tests passed |
| `scripts/verify-contract --iic-b2a2-contract-only` | source, producer/verifier, assertion, path, vnode and scope mutations passed |
| `scripts/verify-contract --iic-b1-root-owned-gate-contract-only` | historical immutable b1 replay passed |
| `scripts/verify-app-release-boundaries --iic-b2a2-component-boundary-only` | package positive control plus final-image negative controls passed |
| APFS vnode probe | write, pwrite, truncate, rename, unlink, link, chmod, xattr and mmap/msync produced events |
| exact scope | 6 paths / 1,999 changed lines; no unstaged or untracked path |
| final immutable review | no unresolved P0-P2 |

The retained zero-finding reports are
`/tmp/stornaut_b2a2_review_294bdb2/report.html` (SHA-256
`4ec42acb85b6c190f743e1b15cb5f2b71169823e96c0add5fc6fc76f0f36815b`)
and `/tmp/stornaut_b2a2_review_294bdb2/report.md` (SHA-256
`b5906aca8d66a28f5365a196f54a93bfc9dbccef19ace22384ca8b4021170740`).
The optional repository custom-review endpoint had no configured workflow; the
required grouped and post-fix general reviews completed.

## 5. Non-Claims and Next Step

b2a2 did not consume the b2 aggregate serial, the privileged no-model campaign,
the authenticated real-Codex run or the authoritative full verifier. It does
not accept ADR 0018, make a machine-readiness claim or enable production Deep
Dive.

The live frontier is now:

```text
ii-c-b2b -> ii-c-c -> L3c3d -> L3c4
```

ii-c-b2b owns the non-privileged controlling-PTY / FD 3 harness and the one
clean staged-only Investigation serial reserved for the b2 aggregate.
