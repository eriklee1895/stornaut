# Capability-First Runtime Final Validation

> Decision: **go** for the capability-first runtime foundation
>
> Date: 2026-08-13
>
> Runtime evidence revision:
> `8b93852d901cc7bd78bf827c21dc4d85ab9d473f`
>
> Production Deep Dive: **implementation not yet available**
>
> Task 29: next eligible deterministic task; not started by R6

## 1. Decision Scope

R1–R6 close the amended ADR 0004 runtime uncertainty for this personal-local
product:

- the required Codex investigation capabilities were observed from the signed
  App/helper diagnostic;
- the complete worker/process tree was contained by the approved outer
  boundary;
- the protocol remains advisory and has no Executor route;
- the App now presents installation, syntax, signed evidence, aggregate gate
  and production feature availability as separate states;
- the first-use data boundary is typed and localized without adding an action
  or persisted acceptance.

The supported decision is **go** for reuse of this runtime foundation by a
future Phase D Deep Dive implementation. It is not admission of a production
Deep Dive workflow, cleanup execution, release distribution, Developer ID,
notarization, FDA/TCC automation or arbitrary local-network access.

No R6 state can start Deep Dive. The current product copy is:

```text
Runtime boundary verified · Deep Dive implementation not yet available
```

## 2. Admitted Evidence Receipt

The product contains a privacy-safe, typed build receipt:

```text
schemaVersion=1
runtimeProfile=capability-first-v1
runtimeRevision=8b93852d901cc7bd78bf827c21dc4d85ab9d473f
reportSchemaVersion=2
reportSHA256=08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193
verifiedAt=2026-08-13T11:09:07Z
provider=openai
model=gpt-5.6-luna
capabilitiesObserved=9
integrityContained=12
outcome=passed
```

The source machine report remained external to the product and was reverified
with `scripts/verify-codex-runtime-gate`. Its SHA-256 matched the receipt. The
receipt contains no App path, auth material, prompt, raw JSONL or private
evidence and creates no authorization, Policy, action, Trash or Executor
object.

`SettingsModel` accepts a passed product projection only when the receipt is
exactly the admitted R5 receipt. A missing or changed receipt is normalized to
`unverified`; it cannot display a green passed-evidence state or a verified
aggregate gate.

## 3. Final Prompt-to-Evidence Matrix

| Approved requirement | Implementation and deterministic evidence | Signed/adversarial evidence | Final result |
| --- | --- | --- | --- |
| Direct read | Closed runtime profile, fixed direct-read command evidence and source-labeled v2 envelope tests | Signed synthetic selected-scope read observed | Passed |
| Shell/unified exec | Closed profile, command event decoding, timeout/output bounds and fixed command observation tests | Signed shell and unified-exec events observed | Passed |
| Live high-context search | Explicit live/high configuration, canonical/raw completion handshake and degradation tests | Signed live-search completion observed | Passed |
| Public command network | Managed-proxy public-network profile and fresh marker contracts | Descendant public HTTPS succeeded through the managed proxy | Passed |
| Browser/direct fetch | Public-fetch marker and strict v2 evidence contracts | Signed browser/direct-fetch evidence observed | Passed |
| Image inspection | Fixed synthetic image token/hash and completed-image event tests | Signed synthetic image observation completed | Passed |
| Skills/subagents | Runtime-owned synthetic skill plus parent/sender-bound subagent result tests | Signed skill marker and delegated subagent completion observed; descendants drained | Passed |
| No executable/domain allowlist | Profile/source audit rejects executable and public-destination allowlists | Multiple public endpoints used through the managed proxy | Passed |
| No per-command approvals | Closed runtime pins unattended approval configuration | Signed diagnostic completed without per-command prompts | Passed |
| Probe optional, not exclusive | Direct-source and `probeBroker` source labels remain distinct in strict v2 | Direct evidence and optional Broker evidence both observed | Passed |
| No user-data writes | Read-only Seatbelt profile and adversarial mutation fixtures across nested descendants | All target/user-data mutation attempts denied | Passed |
| No localhost/private network | Same-investigation managed-proxy exception plus IPv4/IPv6/private/link-local/ULA denial contracts | Direct-public bypass and all private/local canaries denied | Passed |
| No arbitrary Unix socket | Arbitrary Unix sockets disabled in profile and fixed socket-canary tests | Unrelated pre-existing Unix socket denied | Passed |
| No `danger-full-access` | Source/config/static gates reject the mode | No signed report row depended on it | Passed |
| No cleanup authority | Strict advisory v2 schema, module separation and `verify-codex-no-executor-boundary` | Signed report contained no-Executor; R6 Settings has no action route | Passed |
| Swift revalidation authoritative | v2 output cannot encode authority; Core Policy/revalidation tests remain independent | Signed model output was treated only as bounded advisory evidence | Passed |
| No raw secret/JSONL retention | Closed auth projection, bounded report schema and cleanup tests | Runtime Home/auth/JSONL cleanup and zero-residue uninstall observed | Passed |
| Accurate disclosure/status | Five-dimensional model, exact receipt tests, bilingual strings, debug fixtures, AX identifiers and XCUITest | Actual Debug Settings window captured and inspected with Peekaboo | Passed |
| Debug-only diagnostic | Release source/bundle marker audit | `scripts/verify-app-release-boundaries` passed | Passed |

No row is closed by syntax, configuration or model success alone. The signed
App/helper report remains the capability and containment evidence class; R6
only projects its admitted privacy-safe status.

## 4. ADR 0004 Residual-Risk Closure

| ADR 0004 residual risk | Implementation | Deterministic tests/gates | Signed or adversarial evidence | Remaining limitation |
| --- | --- | --- | --- | --- |
| 1. Effective write denial for Codex and every descendant | Outer read-only Seatbelt, private Runtime Home and audit-session lifecycle | Mutation matrix, descendant probes, runtime profile and lifecycle suites | Signed target/user-data writes denied across worker descendants | Confidentiality is not provided by write denial |
| 2. No route to Trash, Registered Actions, Policy bypass or Executor | Advisory-only v2 protocol; `StornautCodex` has no direct/transitive Core Executor dependency | Strict schema tests and `scripts/verify-codex-no-executor-boundary` | Signed machine integrity includes no-Executor | Future Phase D integration must preserve this seam |
| 3. Timeout, cancellation, output and process cleanup stay bounded | Closed budgets, one-shot XPC reply, audit-session drainer and lease recovery | Process, output, cancellation, crash and lifecycle suites | Signed normal/cancel/recovery cleanup contained; zero residue after uninstall | Distribution lifecycle is not evaluated |
| 4. Live search is truly live/high-context without a destination allowlist | Explicit live/high search configuration and canonical/raw handshake | Search configuration, completion and degradation tests | Signed live-search event completed against public internet | External provider outages remain an external state |
| 5. Public command/browser access works while local/private/Unix access stays denied | Parent-owned random-loopback managed proxy is the sole transport exception | Public marker plus IPv4/IPv6/private/link-local/ULA/Unix denial matrix | Public access succeeded; direct bypass and local/private/socket canaries denied | Same-session proxy remains trusted runtime infrastructure |
| 6. Candidate output stays untrusted and Swift revalidates before action | Strict v2 evidence/proposal types contain no executable authority | Identity binding, schema confusion, Policy and revalidation suites | Signed output was accepted only as advisory envelope evidence | Production Candidate Planner/Review workflow is not implemented |
| 7. Malformed, injected, stale, active, protected or out-of-scope candidates fail closed | Closed decoder, canonical path policy, protected catalog and Policy Gate | Prompt injection, forgery, stale/activity/protected/out-of-scope tests | Anti-forgery markers and identity-bound signed evidence observed | Product Deep Dive candidate admission still requires Phase D |
| 8. UI/privacy disclosure states the real confidentiality trade-off | Typed five-item bilingual aggregate disclosure; no action or persisted acceptance | Localization, model, XCUITest, static boundary and actual-window AX checks | Actual Settings showed boundary status and non-actionable disclosure | Full first-use flow is intentionally deferred |
| 9. Raw JSONL or uncontrolled content is not retained | Bounded in-memory parser, closed reports, Runtime Home cleanup | JSONL/report/privacy, auth projection and crash-lifecycle tests | Signed cleanup and post-uninstall zero residue observed | Approved Evidence Store lifecycle remains seven days for bounded evidence |

The direct-read confidentiality, prompt-injection, remote-content,
third-party-processing and licensing exposures are accepted product trade-offs
for personal use. They are disclosed; they are not misrepresented as being
Broker-redacted.

## 5. Product Status and UI Evidence

Settings now separates:

1. Codex installation;
2. required syntax;
3. last signed runtime evidence;
4. aggregate runtime gate;
5. production Deep Dive availability.

The gate is fail-closed:

- missing Codex, unsupported syntax, stale evidence and failed evidence are
  blocked;
- check failure, unverified syntax and unverified/mismatched evidence remain
  unverified;
- only installed + supported + exact passed receipt is verified;
- `deepDiveCanStart` is always false.

R6 added deterministic debug fixtures for passed, missing, unsupported, stale,
failed and unverified states. English and `zh-Hans` XCUITests assert the
separate AX rows and absence of Start Deep Dive, Trust Codex or Accept actions.

The actual Dark Settings window was launched from the Debug `.app`, navigated
by XCUITest and captured read-only by Peekaboo:

```text
ignored screenshot: .derivedData/peekaboo/r6-final-codex-settings-dark.png
dimensions: 1800 × 1296
SHA-256: 5848f9fc8ba12b72a09973c4f09dd1acdb05c8a9863f5cd4e12a2c062160bad4
```

OCR and AX inspection showed the three runtime rows, the exact verified copy,
the no-action product-availability message and the First-Use Data Boundary in
the default viewport without overlap. Peekaboo ScreenCaptureKit analysis
timed out separately; the read-only CG window capture and AX inspection
succeeded. The tool timeout is not classified as a product failure.

## 6. Verification Summary

The admitted R6 source passed:

```text
StornautAppTests: 120 passed
StornautCodexTests: 227 passed, 8 explicit opt-in diagnostics skipped
serial swift test --no-parallel: 537 passed
focused Settings XCUITest:
  canonical Dark/Light Settings passed
  English runtime variants passed
  zh-Hans runtime status passed
scripts/verify-settings-boundaries: passed
scripts/verify-app-release-boundaries: passed
scripts/verify-codex-runtime-gate <R5 report>: passed
scripts/verify --headless: passed
scripts/check-doc-links: passed
git diff --check: passed
```

One combined UI run lost Settings focus to System Settings after its first
variant. The same unchanged variant test passed when rerun alone, matching the
documented environmental-interference policy.

Independent review covered all 36 final tracked and untracked R6 files
(about 1,391 changed lines). Two confirmed P1 findings were fixed:

1. a mismatched/missing receipt could leave the evidence row labeled Passed
   while the aggregate gate was unverified;
2. a failed fixture could carry the admitted passed receipt and create a
   contradictory evidence object.

The fixes normalize unadmitted passed evidence to `unverified` and close
product evidence construction to admitted/stale/failed/unverified factories.
Post-fix review found **0 unresolved P0, 0 P1 and 0 P2**.

Review artifacts:

```text
/tmp/stornaut_r6_review/report.html
/tmp/stornaut_r6_review/report.md
report.html SHA-256:
  81c81a6bbedf50a554326eddc800ba5979b50294b8b11c3e7e890a8a4440921d
report.md SHA-256:
  7471fb812f75efa5548588c39dbeae162689b6e3f31663dd1e7546ed8bd68e76
```

## 7. Final Admission

The capability-first runtime foundation is **go**:

- every required capability row is observed;
- every required containment/integrity row is contained;
- the advisory/Swift-authority boundary remains intact;
- the App accurately distinguishes runtime evidence from product
  implementation availability;
- no unresolved P0–P2 finding remains.

The following remain unavailable or out of scope:

- production Deep Dive orchestration and UI;
- first-use acceptance persistence;
- cleanup execution from Codex output;
- Developer ID, notarization and distribution;
- FDA/TCC product-flow admission;
- arbitrary local/private network or Unix-socket access.

R6 closes the runtime evidence interlock. Task 29 is the next eligible
deterministic Phase C task, but R6 does not start it.
