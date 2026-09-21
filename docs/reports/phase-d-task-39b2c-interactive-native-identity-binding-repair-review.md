# Phase D Task 39B2c Interactive-Native Identity Binding Repair Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-30
>
> Implementation: `531f79f5a86a9b7cdf8a061bf4677508ea257190`
>
> Implementation tree: `00a8434df1921e1318c1ac985161d9294b66848c`
>
> Implementation parent and staged-scope baseline:
> `07ef385a5792d8932fdf3490051e8448a3d7d8e6`
>
> Verifier consumer seal: `26e785ac2146ca96553ce1d4de870fcd4437fa22`
>
> Next frontier: ii-c -> L3c3d -> L3c4

## 1. Result

The interactive-native identity binding repair is complete and remains
non-admitting. The helper-owned interactive path now carries the signed native
Codex SHA-256 through the strict Lifecycle request, resolves and retains the
fixed native Mach-O lease, launches that image suspended, validates the loaded
vnode before resume, returns a worker-observed digest, and preserves the
accepted digest through retirement evidence. The npm wrapper is package-layout
discovery input only and is not executed by this path.

Cancellation and `SIGCONT` are lock-linearized. Every post-spawn failure owns
group termination, exact reap, descriptor closure and workspace cleanup. A
successful retirement additionally requires an empty process group and
post-reap lease revalidation. Failed starts do not promote digest evidence.

## 2. Exact Scope and Diff

The implementation changed exactly fourteen non-document paths: seven
production paths, six test paths and
`scripts/verify-investigation-boundaries`. Its exact Git numstat is:

| Category | Changed lines | Ceiling |
| --- | ---: | ---: |
| Production | 886 | 900 |
| Tests | 1,049 | 1,100 |
| Verifier | 454 | 500 |
| Total | 2,389 | 2,400 |

The Git diff contains 2,234 insertions and 155 deletions. No package target,
signed-binding schema, App Server JSON-RPC method, Objective-C XPC selector,
mutable identity sidecar or cleanup authority was added.

The aggregate verifier intentionally remained outside that exact fourteen-path
implementation. Its subordinate source digest and normalized self-seal were
updated in the separate one-path consumer checkpoint `26e785a` (four changed
lines).

## 3. Contract Closure

- Lifecycle request v3 requires `codexExecutableSHA256` only for start.
- Lifecycle response v5 carries the actual worker-observed digest only for a
  successful started response.
- Broker and App transport independently reject expected/observed mismatch.
- Both diagnostic composition paths source the expected digest only from the
  strict-decoded signed runtime binding.
- The dedicated contained-session launcher uses
  `POSIX_SPAWN_START_SUSPENDED`, exact `waitpid` stop observation, lowest mapped
  image vnode validation, pre-resume lease revalidation and an atomic
  cancel/resume gate.
- Successful owner retirement requires exact reap, group absence, post-reap
  lease validation and cleanup completion.
- Seven production files are whole-file sealed; critical resolver, launch,
  comparison, cleanup and retirement bodies also have controlled mutations.

The repair does not bind or claim runtime identity for
`codex-code-mode-host`, `rg` or `zsh`; that non-claim remains explicit.

## 4. Validation and Review Evidence

| Evidence | Result |
| --- | --- |
| Focused Codex/Lifecycle/Investigation selection | 98 tests in 6 suites passed |
| Supplemental exact cancellation/failed-start cases | 3 of 3 passed |
| One staged-only serialized SwiftPM regression | 1,756 tests in 93 suites passed in 157.279 seconds |
| Debug Xcode App build | passed |
| Release Xcode App build | passed |
| Interactive-native source and staged-scope gates | passed |
| Bare Investigation boundary | exit 0 |
| ii-c0b-iv composition/self-seal contract | exit 0, including subordinate and self-seal negative controls |
| ii-c0b-iv App component boundary | exit 0 |
| Final bare App Release aggregate after verifier-infrastructure closure | exit 0; `Release App fixture boundary verification passed.` |
| Independent runtime/wire and verifier reviews | no unresolved P0-P2 |

The first aggregate attempt correctly failed on the stale subordinate SHA.
After the isolated consumer update, the aggregate exposed two pre-existing
successor-verification defects. They were diagnosed at their exact failing
stages and closed independently; no product test or full verifier was used as a
debug loop.

## 5. Non-Claims

This checkpoint ran no root or sudo command, installed App/helper/driver
campaign, real product XPC, Codex authentication/model/network operation or
`scripts/verify --full`. It does not accept ADR 0018, establish machine
readiness or enable production Deep Dive. Task 39 remains incomplete until
ii-c, L3c3d and L3c4 complete.
