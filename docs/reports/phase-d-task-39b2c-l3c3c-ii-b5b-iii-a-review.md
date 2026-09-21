# Phase D Task 39B2c L3c3c-ii-b5b-iii-a Per-Epoch Continuity Review

> Status: complete / non-admitting
>
> Date: 2026-08-23
>
> Implementation commit: `4538e52a4ceafded60df302903aec1877e66bc40`
>
> Parent: `5933bd0590d5e1c9ab696445fa4475d180e5143e`
>
> Tree: `2eeb307cfb2cf67a1b169e0a510c92ea2dc9dbb2`
>
> Next frontier: ii-b5b-iii-b1 injected eight-epoch cohort

## 1. Result

iii-a closes the typed per-epoch completion and helper-continuity contract
without starting the Darwin outer/inner process topology. The existing
single-epoch composer now accepts the exact predecessor helper identity,
suspends after installed-L2/repeated-App evidence and before release, and
returns only a package-closed local-completion or transferred-ownership value.
Only an injected external containment prover may turn that value into the next
opaque continuity.

The pushed implementation changes exactly ten non-document paths against the
frozen parent: 3,030 additions and 117 deletions, or 3,147 changed lines. This
is within the ten-path / 3,200-line ceiling. It adds no target, package
dependency, public or `Codable` schema, process launcher, file writer, network
surface, cleanup authority, readiness claim or product admission.

## 2. Implemented Contract

- A genesis continuity exists only for ordinal zero. Continuity, predecessor,
  outer completion join and single-epoch composition are each one-shot across
  replay and concurrent callers.
- Every predecessor binds the outer attempt, whole projected input, unchanged
  capsule, ordinal and epoch UUID. Its prior helper identity is passed unchanged
  into the existing fixed claim client. Missing, unexpected or same-helper
  continuity fails closed.
- The post-L2 ownership suspension occurs before helper release, App `EXIT`,
  abort or retirement. Once ownership transfers, local cleanup authority stays
  closed; an uncertain transfer cannot race a competing local cleanup path.
- A local completion binds the complete ownership candidate, claim release,
  retirement and matching initial/final installed-driver observations. It is not
  itself containment evidence.
- The external containment proof binds the complete selection, predecessor,
  helper, completion digest, nonzero terminal-proof digest and the fixed normal
  or parent-crash mode. Foreign or mismatched evidence cannot mint continuity.
- The successor transcript commits in one exact order to outer attempt, capsule,
  projected input, ordinal, epoch UUID, full helper identity, predecessor digest,
  completion digest, terminal proof and containment mode.
- External containment uncertainty and foreign containment evidence are
  classified before caller cancellation. Cancellation is reported only after
  the detached external proof resolves and never upgrades a failed containment
  result.

Accepted source seals include:

- helper continuity: `b4d48da904ff8868fa78da1175bb6507c26213fa83655e81d8b1de38e3c0ab80`;
- single epoch: `4fa50622581f13850324fc0d4a5137af500d250ca3bea5587a26a789a5e6dfd8`;
- single-epoch composition: `2b32c2b4635cda55ab3abaa7097cd2a062f30fca05e603ab682ddcd9b366af14`;
- continuity focused tests: `1b2d1e792b3aaea094ff0c737adc23b700c0a62cfc3edc7a23cc9188ff8b3844`;
- single-epoch focused tests: `8c2b3e45a6a377d9ab13c418cdcd8b33501560cf3930b90bbe225d2b4f0bb2be`;
- installed-L2 join tests: `375a2265dcf42d9ea124f08945844203140542c7bf17362b964902d100524e58`;
- Investigation boundary verifier: `7291b46f6c44bb5d72605982f93bb0f512e2d253ded7ccfea1a58e5f86162be2`;
- contract verifier: `6a51209befa199d821440938c5634a4a244287d80ab5d4ba9ae8ba6339a379e2`
  (normalized self-seal `504aae9db3f74bffde23d7d7111e773231fadd6525408f82d522f9f7d0f7b31b`); and
- App release boundary verifier: `9536402fba6da94f4980704dcb81026ea4373dd91eaffede67d949717616801d`.

## 3. Tests-First and Validation

The final focused selection passed 40 top-level tests in three suites: 17
continuity tests, 17 single-epoch tests and 6 installed-L2 join tests. It covers
genesis and successor binding, same-helper rejection, local/outer ownership,
replay and concurrency, external-failure priority, zero/foreign terminal proof,
projection drift and every single-epoch cancellation seam.

The affected `StornautInvestigationTests` selection passed 559 tests in 41
suites. The final immutable staged tree then passed 1,446 tests in 74 suites
with zero failures. Test execution took 125.849 seconds and the complete clean
serial step, including build, took 181 seconds. The temporary validation commit
`02bc428012ceb78e44a0b7edcac7115f60d2c551` and pushed implementation commit
share exact tree `2eeb307cfb2cf67a1b169e0a510c92ea2dc9dbb2`.

| Gate | Result |
| --- | --- |
| exact ten-path / 3,147-line staged scope and modes | passed |
| focused continuity/single-epoch/installed-L2 selection | 40 tests / 3 suites passed |
| affected Investigation selection | 559 tests / 41 suites passed |
| `scripts/verify-contract` | passed, including source seals and semantic/scope mutations |
| `scripts/verify-investigation-boundaries` | passed, including Debug/Release Machine Driver projections |
| `scripts/verify-app-release-boundaries` | passed, including Release App fixture boundary |
| clean same-tree staged-only serial regression | 1,446 tests / 74 suites passed |
| independent semantic and verifier post-fix reviews | no unresolved P0-P2 findings |

The first attempted clean serial stopped during compilation because a new
parameterized test used an invalid Swift `if` expression. The exact test was
fixed and passed before the final tree was frozen. The first affected run then
exposed one stale boundary-test marker; the exact case was repaired and the
full affected selection passed. Neither failure reached product runtime.

## 4. Review Closure

Independent review found and closed four material false-success windows:

1. Caller cancellation could outrank an already-resolved external containment
   failure. The join now evaluates external uncertainty or foreign proof first.
2. Successor continuity did not have an exact full-field transcript gate. The
   complete ordered transcript and a dedicated terminal-proof mutation now pin
   every field.
3. A focused-coverage gate accepted comment-only test names. Real test parsing
   and explicit comment-only/assertion mutations closed that initial bypass.
4. A second review demonstrated a more general `#expect(1 == 1)` plus marker
   string bypass. The final contract no longer infers semantics from names or
   strings: it seals all three complete focused test sources and includes a
   syntax-valid vacuous-marker negative control.

The final semantic and verifier reviews report no unresolved P0-P2 findings.

## 5. Non-Claims and Next Step

This checkpoint did not read FD 0, run eight epochs, self-spawn the driver,
launch the installed App/helper, invoke real XPC, install or mutate root state,
read Codex authentication, call a model, access the network or run
`scripts/verify --full`. It makes no claim about the physical outer/inner
adapter, privileged execution, authenticated success, machine readiness or
product availability.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. The next checkpoint is ii-b5b-iii-b1,
which owns only the injected eight-epoch cohort state machine. iii-b2a, iii-b2b,
ii-c0b, ii-c, L3c3d and L3c4 retain their separately frozen responsibilities.
