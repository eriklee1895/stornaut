# Phase D Task 39B2c L3c3c-ii-b5b-i-b2b-a Review

> Status: complete / non-admitting
> Date: 2026-08-21
> Next frontier: i-b2b-b fixed service reader

## 1. Scope and Result

i-b2b-a extracted a signal-free process-identity C target and the installed-L2
App/helper/current-driver process reader. Implementation commit
94958088fe271139c9ebb4cd1e2df2c0830d2f72 has parent
fbda613614dcb1e31ac0bd399b2909f455c8d835 and tree
c1a0fadba536b41e9a9e3c453b0b9929f013c915. The checkpoint changed exactly
eight non-document paths with 1,232 insertions and 14 deletions, below its
1,900-line ceiling.

## 2. Authority Boundary

CInvestigationIdentitySupport exports one POD identity and one
identity-for-PID function. It uses task_name_for_pid, TASK_AUDIT_TOKEN and a
bounded proc_pidinfo fallback only to distinguish vanished from inaccessible
processes. Its source/header and compiled object export/import gates reject
proc_signal_with_audittoken, kill, signal, wait, spawn, fork, exec, write,
socket and other process-control surfaces.

StornautInvestigationInstalledL2 depends only on the HandoffContract and the new
C identity target, with Security.framework. It still does not depend on
StornautLifecycle, CLifecycleSupport, Machine, DriverSupport, Core, Runtime or
Execution.

## 3. Process Evidence

The role-specific App/helper reader accepts only complete typed identities and
derives fixed executable paths internally. Its sequence is:

identity 1 -> fixed path 1 -> audit-token live signing -> fixed path 2 -> identity 2

Only initial ESRCH becomes absent. Mid-observation failures remain unavailable,
and complete identity drift becomes identity reuse. Live signing validates
dynamic and derived static code strictly and retains identifier,
designated-requirement SHA-256, raw CodeDirectory hash and ad-hoc state. The
current-driver entry accepts no caller PID and admits signing only for the
injected current process when the kernel identity is root.

The paired reads are race-detecting, not an atomic kernel snapshot. A
privileged A-to-B-to-A actor remains outside ADR 0018's serialized
trusted-local-operator threat model and must not be described as race-free.

## 4. Verification

- focused process reader: 8/8 top-level tests passed, including a concrete
  current-process C identity/path/Security smoke without launching a process;
- affected InstalledL2 regression: 38/38 tests in four suites passed;
- source, Package, C header/source and compiled-object authority gates passed;
- scripts/verify-contract passed C-signal, dropped identity/path reread,
  audit-token, flags, vacuous-test and staged-scope mutations;
- historical i-b1/i-b2a/live-claim Package evidence remains exact through
  precise later-target normalization;
- production/C independent review found no P0-P2;
- verifier review found one P1: a finite object-import denylist could miss an
  unlisted authority. The gate now requires the complete exact undefined-symbol
  set, and a retained ptrace mutation plus the existing signal mutation prove
  the object negative. Post-fix review found no P0-P2; and
- the checkpoint's only serial run passed 1,337 tests in 66 suites in 121.220
  seconds, with 127.12 seconds wall time and no restart or suite rerun.

The serial belongs to implementation commit 9495808 and tree c1a0fadb. The
later post-fix commit strengthens verifier-only evidence; it does not change the
Package graph, C/Swift production source or focused tests, and the serial was
not rerun.

No scripts/verify --full, App/helper/XPC, install, sudo/root, model/auth or
network operation ran in this checkpoint. Real authenticated Codex App Server
testing remains a later ii-c/L3c4 responsibility.

## 5. Non-Admission

i-b2b-a is complete and non-admitting. i-b2b-b now owns the fixed,
non-activating service reader; i-b3 still owns composition and i-c still owns
the DriverSupport join, opaque proof and legacy-owner closure. Task 39 remains
incomplete, ADR 0018 remains Proposed, production Deep Dive remains unavailable
and L3c4 alone owns readiness, final admission and the remaining full verifier.
