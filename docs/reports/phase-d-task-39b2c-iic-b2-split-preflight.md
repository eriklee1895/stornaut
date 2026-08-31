# Phase D Task 39B2c ii-c-b2 Split Preflight

> Status: frozen / ii-c-b2a1 current / non-admitting
>
> Date: 2026-08-31
>
> Baseline: `d755d664c0c8e25480ae0043bd3719b03dff3c48`
>
> Remaining order: ii-c-b2a1 -> ii-c-b2a2 -> ii-c-b2b -> ii-c-c ->
> L3c3d -> L3c4

## 1. Decision and Split Trigger

The frozen ii-c-b requirement combines two independent trust surfaces: a
durable owner-private raw-evidence tree and a non-privileged controlling-PTY /
FD 3 transport around the fixed coordinator. A complete implementation is now
estimated at fourteen unique non-document paths and 4,800--5,800 changed
non-document lines. The path count reaches the repository ceiling and the line
estimate exceeds the 4,000-line mandatory split threshold. Implementation is
therefore split before code changes.

The bounded checkpoints are:

1. **ii-c-b2a1 -- evidence producer.** Add the package-only typed manifest and
   attempt-event contracts, descriptor-relative durable writer and injected
   behavior tests.
2. **ii-c-b2a2 -- independent evidence verifier.** Add a read-only verifier
   that inventories and parses raw evidence without importing or calling the
   producer, then close source, package, mutation and final-image boundaries.
3. **ii-c-b2b -- PTY/FD 3 transport.** Add the non-product campaign executable,
   isolated C child trampoline, Swift lifecycle state machine, coordinator-
   shaped fixture and physical transport/retirement evidence.

These are implementation checkpoints inside the existing ii-c-b2 scope, not
new roadmap Tasks. Review findings or local repairs do not create further named
Tasks. If a checkpoint exceeds its path or line ceiling, work stops for a new
scope decision rather than silently widening it.

## 2. Dependency and Authority Boundary

`StornautInvestigationMachineCampaignSupport` is package-only. It is not a
SwiftPM product and is not referenced by any Xcode target or scheme. In b2a1
its only direct dependency is `StornautInvestigationHandoffContract`; the test
target is its only reverse dependency. In b2b the final graph is:

```text
StornautInvestigationMachineCampaign (non-product executable target)
└── StornautInvestigationMachineCampaignSupport
    ├── StornautInvestigationHandoffContract
    ├── CInvestigationIdentitySupport
    └── CInvestigationMachineCampaignSupport
```

CampaignSupport must not depend on CoordinatorSupport. CoordinatorSupport
already carries Codex, Core, Investigation, Diagnostic, Gate and Launch
dependencies; importing it would reintroduce that broad graph into the
diagnostic campaign executable and make the verifier non-independent. The
campaign contract instead parses the frozen coordinator receipt wire directly
with `HandoffBinaryTranscript`, and golden cross-tests bind that independent
projection to the canonical producer bytes.

The dedicated C target is introduced only in b2b. It owns the narrow
fork/session/controlling-terminal/descriptor/exec trampoline. It must not be
placed in `CInvestigationIdentitySupport`, because that target is reachable from
the installed driver. No campaign target may depend on Core, Codex, Execution,
Investigation, InvestigationDiagnostic, InvestigationRuntime, Lifecycle,
ProcessSupport, DriverSupport, GateSupport, CoordinatorSupport or InstalledL2.

## 3. ii-c-b2a1 Exact Scope and Budget

Exactly four non-document paths and at most 3,000 changed non-document lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` (new);
3. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineRawEvidenceWriter.swift` (new); and
4. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` (new).

Post-RED API expansion showed that keeping a narrow target while independently
matching the existing 23-field coordinator receipt wire requires more contract
code and less writer/test code than the initial allocation. Before production
validation, the category ceilings are therefore rebalanced to: Package manifest
40 lines, contracts 850 lines, writer 1,100 lines and tests 1,000 lines. The
3,000-line total ceiling is unchanged and stricter than the sum of category
ceilings. A fifth non-document path, line 3,001, independent verifier,
process spawn, PTY, sudo, installed-artifact path or product dependency stops
b2a1 for re-preflight.

### 3.1 Contract

The contract freezes:

- exactly six ordered phases: preflight, install, authorization, driver/epochs,
  uninstall and verifier;
- closed artifact roles and role-to-phase mapping;
- lowercase ASCII relative paths with no empty, absolute, dot, dot-dot, NUL,
  backslash, repeated-separator, trailing-separator or reserved component;
- canonical manifest entries containing relative path, phase, role, encoding,
  byte count and SHA-256, strictly sorted by UTF-8 path bytes;
- an exact manifest schema/domain, bounded entry/file/total sizes and a content
  root derived from canonical manifest bytes without a recursive self-entry;
- protocol receipts retained as opaque canonical binary bytes rather than
  decoded/re-encoded JSON; and
- immutable attempt-event files with sequence, attempt UUID, event kind,
  previous-event SHA-256, observed time and payload SHA-256.

Legal event histories are only:

```text
prepared -> cancelledBeforeArm
prepared -> armedConsumed -> spawnObserved|spawnUncertain -> terminal
```

The dry-run mode admitted by b2a1 may emit `prepared` and
`cancelledBeforeArm`; it cannot emit `armedConsumed`, a spawn event, readiness
or any admitting verdict. Mutable convenience markers are never admission
input.

### 3.2 Writer

The writer receives a held, prevalidated parent descriptor and an attempt UUID.
It exclusively creates one fresh root, the six fixed phase directories and
immutable artifacts with descriptor-relative operations. Directories are 0700;
regular files are 0600 and single-link. All nodes must remain on the parent
device, owned by the current effective UID/GID, free of flags and extended ACL,
and limited to the explicit xattr policy. Symlinks are never followed.

Each artifact follows exclusive temporary creation, bounded EINTR-safe write,
held/named identity validation, file fsync, exclusive rename, parent-directory
fsync, no-follow reopen, bounded pread/hash/EOF verification and final metadata
stability. Finalization writes the manifest last, synchronizes all six phase
directories and the root, inventories the tree and returns only a typed seal.
Any create/write/read/sync/rename/close or identity uncertainty permanently
poisons that writer instance; there is no overwrite, retry, repair, unlink or
stale-recovery authority in this checkpoint.

## 4. ii-c-b2a1 Tests First

The new serialized Swift Testing suite must cover:

- canonical six-phase order, closed roles, role/phase binding and path grammar;
- deterministic manifest bytes/content root independent of caller entry order;
- duplicate path/role, missing role, unknown/extra field, ordering, byte-count,
  digest, size and attempt-binding rejection;
- legal and illegal event transitions, sequence gaps, broken previous hashes,
  cancellation terminality and irreversible post-arm state;
- dry-run inability to produce `armedConsumed`, spawn or admission claims;
- exclusive 0700 root/phase creation and 0600 immutable artifact publication;
- symlink, hardlink, owner/group/mode/flags/ACL/xattr, device, held/named and
  post-read identity drift;
- existing nodes, short/zero/oversized writes, bounded EINTR, trailing bytes,
  fsync/rename/close failures and terminal writer poisoning; and
- manifest-last publication, complete inventory and no accepted output after
  any uncertainty.

b2a1 uses injected system operations for exhaustive failure ordering plus
non-privileged temporary-directory positive checks. It executes no root/sudo,
installed binary, XPC, model, auth, network, campaign or authoritative full.
It ends after focused tests, targeted package build and independent source/test
review. It does not consume the aggregate serial reserved for b2b.

## 5. ii-c-b2a2 Exact Scope and Budget

Starting from the pushed b2a1 implementation/tree, b2a2 may change exactly:

1. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
3. `scripts/verify-investigation-runtime-machine-report` (new);
4. `scripts/verify-investigation-boundaries`;
5. `scripts/verify-app-release-boundaries`; and
6. `scripts/verify-contract`.

The ceiling is six non-document paths and 2,000 changed non-document lines.
The independent verifier uses Python standard-library parsing over held
descriptors and does not import, build or call CampaignSupport or
CoordinatorSupport. It independently inventories the complete tree, parses and
re-encodes STNC manifest/event bytes, validates coordinator-receipt framing and
self-hash against a fixed golden corpus, recomputes every artifact digest and
event chain, and rejects extras, missing nodes, aliases, traversal and metadata
drift. Repeated verification is byte-for-byte stable and read-only.

The structural closure proves no new SwiftPM product, exact direct/reverse
dependencies, product-root unreachability, zero Xcode project/scheme references,
the unchanged three-role installer table, no public/open API and absence of all
campaign namespaces/domains from ordinary App, diagnostic App, helper, driver,
Gate and coordinator final images. Producer and verifier mutation controls must
show that changing either side alone cannot make a malformed tree pass both.

## 6. ii-c-b2b Scope and Acceptance

b2b is separately capped at twelve non-document paths and 3,600 changed lines.
It may add the isolated C target/header, Swift harness, non-product executable,
fixed coordinator-shaped fixture and tests, then extend the aggregate gates.
The precise path list is frozen again from the pushed b2a2 tree before code.

The harness owns one fixed sibling coordinator, no path/argv/environment
selector, a single absolute deadline, a parent-created PTY and receipt pipe,
child `setsid -> TIOCSCTTY -> tcsetpgrp -> dup2/close -> execve`, immediate
parent transfer-FD closure, fair concurrent PTY/FD 3 drain, strict framed
receipt admission, exact wait/reap, stable PID/start-token identity, SID/PGID
zero residue and one-shot failure cleanup. The coordinator receipt's PID/PGID/
SID describe the inner Gate and therefore are not falsely equated with the
outer coordinator identity; the outer join uses independently observed
coordinator topology, exact exit, EOF and retirement facts plus receipt-level
attempt/source bindings.

The final b2 aggregate runs focused tests, the independent raw-evidence corpus,
source/contract/component gates, one clean staged-only serialized
`StornautInvestigationTests` regression, targeted non-product Debug/Release
builds and independent grouped/cross-boundary review. It does not run
`scripts/verify --full`.

## 7. Non-Claims and Exit Order

All b2 checkpoints are non-privileged and non-admitting. They must not execute
sudo, install/uninstall, system launchctl, an installed App/driver/Gate/
coordinator, product XPC, real Codex, auth/model/network, a real
`armedConsumed` transition or the unique machine campaign. They do not accept
ADR 0018 or enable production Deep Dive.

Only after b2a1, b2a2 and b2b have individually passed their scope, tests,
artifacts and independent reviews may ii-c-c freeze and execute the one
privileged no-model campaign. L3c3d retains the authenticated real Codex run;
L3c4 retains readiness, final receipt/seal and the only remaining authoritative
full verifier.

## 8. Prompt-to-Artifact Checklist

| Requirement | Concrete artifact/evidence | Owner/status |
| --- | --- | --- |
| Record mandatory split before code | this preflight, baseline and ceilings | frozen |
| Narrow package-only evidence target | Package manifest and graph tests | b2a1 |
| Typed manifest/event contract | Campaign Evidence Contract | b2a1 |
| Durable descriptor-relative producer | Raw Evidence Writer | b2a1 |
| Independent from-zero verifier | machine-report verifier | b2a2 |
| Producer/verifier mutation independence | evidence tests and contract gate | b2a2 |
| No product/final-image reachability | target-boundary and App-release gates | b2a2/b2b |
| Controlling PTY and exact FD 3 | C trampoline + Campaign Harness | b2b |
| Concurrent drain and strict receipt framing | harness tests and physical fixture | b2b |
| Exact wait/reap and zero SID/PGID residue | harness result and physical tests | b2b |
| One non-root aggregate serial | clean staged-only Investigation suite | b2b only |
| Privileged no-model machine evidence | installed campaign and checked receipt | ii-c-c, pending |
| Real Codex success | authenticated current-source run | L3c3d, pending |
| Final readiness/full | sealed admission and one full verifier | L3c4, pending |
