# Phase D Task 39B2c L3c3c-ii-b5b-i-b2a Review

> Status: complete / non-admitting
> Date: 2026-08-21
> Next frontier: ii-b5b-i-b2b process/service readers and narrow C identity support

## 1. Scope and Result

This checkpoint extracted the fixed installed-L2 artifact and static-signing
reader into the non-product StornautInvestigationInstalledL2 target. It owns
only read-only fixed-path evidence: descriptor/node/hash checks, the closed
launchd manifest, static Security.framework signing evidence and the eight-role
artifact projection. It does not own PID/live-signing, service observation,
claim evidence, repeated-App identity, opaque proof minting or admission.

The required Security.framework linkage made Package.swift a sixth path. The
pre-coding estimate of five paths is corrected to six without changing the
2,200-line ceiling. The implementation is commit
e85b402a170c56df285d58facf630be383cca611, parent
a0ede63d9c25341147efa174e1097b8a23604440, tree
0532f1f53bb4b7f55cd1363b75adc2ae61904167: six paths, 2,057 insertions and four
deletions.

## 2. Implemented Contract

- exact fixed App/helper/driver/plist/runtime/lease paths;
- lstat, O_NOFOLLOW read-only open, fstat, bounded descriptor read, post-read
  fstat and final lstat, with only the initial ENOENT becoming absent;
- exact owner/group/mode/link/type/size and typed SHA-256 checks;
- exact closed launchd manifest with strict Boolean-versus-integer typing;
- strict SecStaticCode validation and identifier, designated-requirement,
  CodeDirectory hash and ad-hoc extraction;
- node checks before and after each path-based signing observation; and
- fail-closed eight-role facts with runtime/lease as the only optional roots.

Security.framework has no public descriptor-bound static-code constructor. The
pre/post node checks are a race-detecting sandwich, not a claim that signing is
atomically descriptor-bound. An A-to-B-to-A exchange requires a concurrent
privileged writer. ADR 0018 excludes malicious/concurrent administrators from
the trusted-local-operator threat model, and the ceremony serializes install,
all observation epochs and final uninstall. No ordinary product path mutates
the fixed App/helper/driver/plist during the observation window.

## 3. Review Repairs

Independent review findings were closed before validation:

1. the scripted filesystem records and asserts descriptor close on every
   post-open success/failure path;
2. the concrete Security reader is exercised against signed /bin/ls and an
   unsigned fixture rather than only recording fakes;
3. the structural gate rejects bare or qualified write-family calls and all
   writable open flags, and binds the sole Darwin.open call to the exact
   read-only flags;
4. focused behavior is SHA-256 sealed and mutation-tested, including removal of
   close, weakening open flags and replacing a signing assertion with a vacuous
   assertion; and
5. historical Package snapshots normalize only the exact later Security-linked
   target before retaining their original SHA checks.

Post-fix grouped review found no unresolved P0-P2. The residual signing ABA
window was reviewed and withdrawn as out of ADR 0018's threat model; it remains
documented above and must not be described as descriptor-bound evidence.

## 4. Verification

- focused artifact reader: 11/11 top-level tests passed;
- affected InstalledL2 regression: 29/29 tests in three suites passed before
  final review fixes; the post-fix focused suite passed again;
- scripts/verify-contract: exit 0, including dependency, blocking bridge,
  descriptor, manifest type, signing requirement, close, safe-open, vacuous-test
  and staged-scope mutations;
- canonical artifact and staged-scope gates: exit 0;
- scope: six paths / 2,061 changed lines at final validation, below 2,200; and
- the checkpoint's single serial run on commit e85b402, tree 0532f1f5..., passed
  1,328 tests in 65 suites in 186.077 seconds (190.44 seconds wall time), with no
  restart or suite rerun.

No scripts/verify --full was run. No App/helper/XPC, install, sudo, root, model,
authentication or network operation was used by this checkpoint. There was no
new real-authenticated Codex App Server online run during the last two
development days. The user's available subscription/App Server is a future
ii-c/L3c4 prerequisite, not evidence for this non-admitting reader.

## 5. Admission Boundary

i-b2a is complete and non-admitting. i-b2b is current, followed by i-b3. i-c
still exclusively owns the projection + claim + repeated-App join, opaque proof
and legacy-owner closure. Task 39 remains incomplete, ADR 0018 remains Proposed,
production Deep Dive remains implementation unavailable, and L3c4 alone owns
machine readiness, final admission and the remaining authoritative full run.
