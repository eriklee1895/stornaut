# Epic 2–4 Task 26 Code Review

> 状态：Passed after confirmed findings were fixed
>
> 日期：2026-08-11
>
> 范围：Task 26 product benchmark/scaling changes、Quick Scan projection、
> persistence/accounting、App terminal metrics、Automation Mode preflight 与
> Phase B gate

## Review Method

The final review examined the uncommitted Task 26 diff against Task 25 in six
connected groups:

1. Surveyor bounded backpressure, cancellation and legal macOS path handling;
2. typed aggregate, SQLite prepared batches, keyset paging and payload limits;
3. streaming owner/hard-link/gap accounting and reference-fixture parity;
4. rule matcher indexing, product classification and terminal/restart
   projection;
5. benchmark report truth, App Scan metrics and Phase B source/bundle scope;
6. Automation Mode status parsing, verifier ordering and authentication
   window/runner lifecycle attribution.

The review used `bits-code-guard` dimensions plus manual Swift concurrency,
domain-invariant and product-safety review. Every confirmed finding received a
failing regression before the implementation fix.

## Confirmed Findings and Fixes

| Finding | Severity | Fix and regression |
| --- | --- | --- |
| bounded display snapshots caused terminal `Measured` bytes to under-report | P1 | consume full `ScanAggregate`; App reducer test covers retained and live terminal paths |
| product benchmark rebuilt typed counts from a non-terminal progress sample | P1 | schema v3 consumes terminal aggregate; synthetic gate fixes exact 804/551/1 counts and 68,167,269 logical bytes |
| terminal disposition footer counted only bounded visible rows | P1 | consume full counts only for the authoritative projection; progressive/failed local facts remain local |
| arbitrary display facts could displace classified candidates from the 100-row terminal/restart page | P1 | candidate-first selection with fallback display fill; large-store and restart tests cover late-path candidates |
| UI full disposition counts included the internal root Unknown owner | P1 | subtract the root classification disposition; footer sum equals candidate count |
| projection accepted impossible aggregate/count/disposition relations | P1 | constructor/decode invariants reject aggregate mismatch, classification over-count and bounded disposition over-count |
| typed count constructors/decoders could overflow or bypass validation | P1 | checked sums plus explicit `init(from:)`; overflow and malformed JSON tests fail closed |
| Automation Mode preflight recognized only lowercase synthetic status even though the Apple tool can emit uppercase `ENABLED` / `DOES NOT REQUIRE` tokens | P1 | normalize status case, reject contradictory mode or authentication-policy output and cover lowercase, uppercase, no-auth, auth-required, contradictory and unknown states in the parser self-test |
| Automation Mode preflight resolved its security-status tool through `PATH` and accepted substring matches, so a shadow executable or appended output could forge readiness | P1 | invoke only `/usr/bin/automationmodetool`, parse exactly two known lines and add a fake-tool marker regression proving a `PATH` shadow is never launched |
| Surveyor and Probe Broker loaded the fixed 1,024-byte Swift `d_name` tuple from variable-length `readdir` storage on every entry, producing a deterministic ASan heap-buffer-overflow | P0 | shared raw-pointer decoder bounds reads by `d_reclen`/`d_namlen`, validates NUL/UTF-8 and covers minimal, 1,023-byte and malformed records under ASan |
| Surveyor treated `readdir == nil` with nonzero `errno` as ordinary EOF, allowing an interrupted directory to look complete | P1 | explicit errno-aware loop maps EIO/malformed records to `directoryReadFailed`; low-level and Quick Scan regressions prove failed/scannerFailure terminal truth |
| the documented single unified verifier did not invoke the Phase B product gate, so one green `scripts/verify` could omit schema-v3 product/cancel and fake-Codex-marker acceptance | P1 | invoke `scripts/verify-phase-b-gate` immediately after the read-only Automation Mode preflight; a source assertion first reproduced the missing ownership and now requires both commands in order |
| four process-lifecycle tests coupled their readiness/result assertions to short wall-clock budgets and failed under the unified pool before exercising the intended semantics | P1 | keep product timeout/cancellation/cleanup assertions, but separate fixture readiness/safety budgets from the tested timeout; 5/5 focused, 50/50 stress and 279/279 full-pool verification passed |
| the verifier required Automation Mode to be enabled before long non-UI gates and scheduled XCUITest last, but standard user-authenticated enablement is tied to an active UI-test request and returned to disabled after the failed run | P1 | keep strict standalone fail-closed behavior; add an exact `--allow-auth-prompt` state used only by `scripts/verify`, then run XCUITest immediately before every other gate; no no-auth policy or mutating system command is used |
| the new bounded-row App test declared 1,000 full classifications but retained the fixture's seven-item full snapshot count, so the closed projection rejected the test before any `ScanModel` assertion | P1 | keep the production invariant and give the fixture a truthful 10,000-item full snapshot count; focused 1/1 and complete App contract 97/97 passed |
| Settings launch helper trusted a transient requested page marker, but SwiftUI scene restoration could replace it with the previous section before the test continued | P1 | always click the current hittable requested sidebar item and wait for its page; both Settings methods passed 3/3 independent-process repetitions |
| an unrelated crashing App window could trigger XCUITest interruption handling and swallow the click that only presents a confirmation dialog | P1 | reacquire the current hittable action and retry the pre-confirmation click once only while the dialog is absent; 5/5 independent-process repetitions passed, including one with the same external Chrome crash warning |

The review also inspected prepared-statement lifecycle, cursor termination,
hard-link identity treatment, cancellation commit points, product partial
truth, fixed Git invocation, Codex marker behavior, App action availability,
dependency/license drift and raw-content persistence.

## Verification

- Phase B focused gate: 279/279 functional/security tests passed; three
  opt-in/environment diagnostics were explicitly skipped.
- Synthetic product/cancel contracts, all boundary scripts and the complete
  67-rule catalog hash passed.
- Address Sanitizer passed the full 279/279 non-performance
  functional/security suite after reproducing and fixing the variable-length
  `dirent` overflow; the three hard matcher performance tests remain owned by
  the ordinary focused/unified gates. Thread
  Sanitizer passed 11/11 directory/concurrency tests.
- Undefined Behavior Sanitizer passed 11/11 raw-pointer/integer/accounting/
  paging/terminal tests.
- Post-fix SwiftPM and Xcode App/Test-host warnings-as-errors builds passed in
  isolated scratch/DerivedData locations.
- Automation Mode parser self-test passes all accepted case variants and
  fail-closed states. The final run observed the supported
  authentication-free status and invoked no mutating Automation Mode command.
- `zsh -n` passes for all three verifier scripts, and the unified verifier now
  owns the Phase B product gate at lines 8–9 rather than relying on a separate
  prior command as a completion proxy.
- Final-source Home product run: 3,107,607 entries in 247.24 seconds,
  73,220,096-byte peak RSS, 20,795,392-byte store, 132 explicit permission
  gaps, zero directory-read failures and absent Codex marker.
- Separate cancellation sample: 1.82 ms response and no final ledger.
- XcodeBuildMCP/Peekaboo actual-window English/`zh-Hans` Light/Dark inspection
  passed without input/mutation tools.
- An isolated UI-only authentication probe executed no test method and was
  classified as host-blocked initialization. Its LocalAuthentication window
  outlived the timed-out runner; no second request was layered over it and the
  probe is not counted as the unified verifier.
- After the user authenticated, the first strengthened unified run entered the
  279-test pool and failed four load-sensitive process tests before any
  Xcode/App test. No failed run was accepted as evidence. The tests were fixed
  through the repository's unit-test workflow without changing production
  process code; the exact five related lifecycle tests passed ten consecutive
  stress rounds and the complete 279-test pool then passed.
- The same run proved the standard authorization was not a durable host toggle:
  after the non-UI failure, `automationmodetool` again reported disabled and no
  authentication window remained. The unified verifier now accepts only the
  exact authentication-required developer state and starts XCUITest
  immediately; default standalone preflight behavior, contradictory/trailing
  rejection and the absolute Apple-tool path remain unchanged.
- A later complete run passed 9/9 XCUITest methods, all seventeen screenshot
  gates, both 279-test SwiftPM pools, all matcher benchmarks and source
  boundaries, then stopped at the Xcode App contract target because the new
  bounded-row test fixture violated `classificationCount <= snapshotCount`.
  The failed run was not accepted. The fixture was corrected without changing
  production contracts; its exact Swift Testing identifier passed 1/1 and the
  full `StornautAppTests` target passed 97/97.
- Complete-suite repetition then exposed Settings scene restoration and an
  external-window interruption that could consume a pre-confirmation click.
  Both received bounded test-harness fixes; the affected methods passed
  repeated independent-process runs.
- The final current-source unified verifier completed in one uninterrupted
  run with exit code `0`: 9/9 XCUITest, 17/17 screenshot contracts, two
  279-test SwiftPM pools, three matcher benchmarks, 97/97 App contracts,
  signed App/bundle/release boundaries, localization, compiler, docs and diff
  hygiene all passed.

## Final Review Decision

After the fixes above, the final review has **no open P0–P2 finding**. The
review does not approve Deep Dive, real destructive Registered Actions,
release/notarization or any permission-boundary expansion.

Local review artifacts are intentionally not committed. A fresh automatic
review after the final lifecycle layout covered 34 code/script files and
approximately 6,110 changed lines in six groups plus a cross-group contract
check. It found no new P0–P2 finding. The generated reports are retained at
`/tmp/stornaut_task26_final_review/report.html` and
`/tmp/stornaut_task26_final_review/report.md`.
