# Phase D Task 39B2c L3c3c-ii-b5b-ii-a Review

- Status: complete / non-admitting
- Date: 2026-08-22
- Implementation commit: `ea9d2a237ab8e8d1b900f603f54233c94c86ecc0`
- Parent: `ddbc4a0be3ea059c7de239b85ef60c40c09affbb`
- Tree: `25de5d72310009b1a572ca3e5a40595ad40ff827`
- Next frontier: ii-b5b-ii-b independent Darwin App identity observation

## 1. Result

ii-b5b-ii-a completes the fixed FD-0 capsule intake and internal one-shot
epoch selection required by the fixed Darwin runtime. The package-scoped
reader accepts only the inherited standard-input descriptor, proves its
read-only descriptor and file provenance before and after reading, consumes
the exact bounded bytes through EOF, performs the canonical capsule decode and
returns an actor-owned eight-epoch cursor. Callers cannot provide a path, file
descriptor, scenario or ordinal, and aliases cannot replay an already consumed
epoch.

The checkpoint contains exactly seven non-document paths and 1,975 changed
non-document lines against its frozen parent, within the seven-path / 2,000-line
ceiling. The same commit updates the preflight narrative, for eight total paths
and 1,992 total changed lines.

## 2. Implemented Contract

- The only input is `STDIN_FILENO`; no path open, caller-selected descriptor,
  ordinal or scenario enters the package surface.
- The descriptor must start at offset zero, accept and retain `FD_CLOEXEC`,
  remain `O_RDONLY`, reference one regular `0600` file owned by UID 501, have
  one link, no file flags, no extended ACL and no extended attributes, and stay
  byte-for-byte stable across the read.
- Reads are bounded to 16 KiB chunks and the canonical capsule maximum. Short
  reads, trailing growth, offset drift, metadata drift and non-EOF completion
  fail closed. `EINTR` is the only retryable read result.
- Canonical decoding supplies exactly the frozen eight epochs. The actor owns
  the cursor and verifies ordinal/scenario order before each one-shot selection.
- The existing installed-driver reader now uses the correct Darwin
  `acl_get_entry` success convention as well, so both physical readers reject a
  real extended ACL rather than treating it as absent.

The accepted production source SHA-256 values are:

- fixed capsule intake: `9f3a33cd0f5792e28d2c5c69b28250463509883114196fa4530141ea048c799d`;
- installed-driver Darwin source: `67a6e9edca7084fc754216bd28410cff9db155760511d6665dd870513d05b1b0`.

The focused capsule-test SHA-256 is
`5524411c895237fbd28983e91d8eb6b5a57c03881b175556b908e9b9fa7d0f87`.

## 3. Tests-First and Validation

- The initial focused RED proved the fixed intake and selector were absent.
- The final capsule suite passed six top-level tests, including 26 parameterized
  descriptor/provenance/read mutations and a real extended-ACL positive case.
- The existing DriverSupport suite passed 21 top-level tests, including the new
  real installed-driver extended-ACL regression.
- The affected Investigation target passed 471 tests in 37 suites.
- The sole staged-only serialized regression passed 1,353 tests in 70 suites in
  92.826 seconds; the five explicit maximum benchmarks were skipped as planned.
  It was not restarted or repeated.
- `scripts/verify-investigation-boundaries` passed, including exact staged
  scope/content replay and Debug/Release Machine Driver Mach-O projection.
- `scripts/verify-contract` passed, including verifier self-seal, boundary seal,
  the fixed parent/path/budget contract and semantic/scope mutation negatives.
- The exact target-boundary regression passed.
- Coverage was not rerun: the user did not request a coverage result, no CI
  threshold applies to this checkpoint and the affected regressions were green.

`scripts/verify --full` was deliberately not run. This is a bounded,
non-admitting implementation checkpoint; the remaining authoritative full is
reserved for L3c4.

## 4. Review Closure

Implementation review exposed two concrete fail-open risks and both were fixed
tests-first: the intake initially lacked an `F_GETFL` / `O_ACCMODE` read-only
check, and both the new reader and existing installed-driver reader initially
interpreted `acl_get_entry` success as `1` instead of Darwin's `0`. Real-file
ACL tests now protect both paths.

Verifier review also closed worktree/index mixing, an unverified staged
`verify-contract`, a path-budget mismatch and incomplete anti-bypass coverage.
The final gates reconstruct the staged tree through a temporary index, compare
all seven allowed paths byte-for-byte, pin normalized verifier and boundary
seals and reject mutations to the capsule source, installed reader and tests,
boundary test and contract verifier. Final independent review reported no
unresolved P0-P2 findings.

## 5. Non-Claims and Next Step

This checkpoint did not run as root, install or launch a signed App/helper,
invoke real XPC, read Codex authentication, access a network or call a model. It
does not prove the Darwin App identity observer, FD-7 session, PGID retirement,
production composition or machine readiness. ADR 0018 remains Proposed, Task
39 remains incomplete and production Deep Dive remains
`.implementationUnavailable`.

The next checkpoint is ii-b5b-ii-b independent Darwin App identity
observation, followed by ii-b5b-ii-c fixed FD-7 session, ii-b5b-ii-d exact
owned-PGID retirement, ii-b5b-iii production/artifact composition, ii-c0, the
single no-model privileged ii-c gate, L3c3d authenticated success and L3c4
final admission.
