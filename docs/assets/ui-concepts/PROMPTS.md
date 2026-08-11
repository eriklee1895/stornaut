# Stornaut UI Concept Prompt Set

Generated with the `$erik-gpt-image-2` skill using OpenAI `gpt-image-2` on 2026-08-07. These are visual exploration assets, not implementation specifications.

Current selection status: the functional UX, brand rules, all core pages, Settings, and cross-flow resilience states have approved compositions. The UI/UX design baseline is complete for implementation; generated assets remain non-pixel-accurate references.

## Shared direction

- Use case: `ui-mockup`
- High-fidelity native macOS desktop app, landscape 16:10
- Native Observatory: calm scientific explorer, production-ready SwiftUI/AppKit feeling
- Native unified toolbar and sidebar; standard macOS window controls
- Graphite/deep navy or system-light materials with restrained indigo/cyan accents
- Storage Orbit motif: layered storage blocks or rings with a thin exploration orbit
- English UI, legible text, progressive disclosure
- No paywall, marketing banner, chat, terminal, junk language, cartoon astronaut, broom, excessive neon, or watermark
- The canonical sidebar contains only Overview, Scan, Investigations, and History

## Dashboard A — balanced dark

Create a balanced dark Dashboard with three top metrics (`125 GB Free`, `87% Explained`, `23.4 GB Ready to Reclaim`), two Space Ledger bars, Quick Scan and Deep Investigation action cards, and three concise insight cards. Prioritize production feasibility and clear hierarchy.

## Dashboard B — visual dark

Create a more visual and minimal dark Dashboard dominated by an elegant Storage Orbit showing known versus unknown space. Keep the same key metrics and actions with substantially less prose.

## Dashboard C — data-rich light

Create a compact light-mode Dashboard with total/used/free/explained/reclaimable metrics, a tabular Space Ledger, top opportunities, storage-change chart, scan freshness, and compact permission/Codex status.

## Deep Investigation A — balanced dark

Create a dark Deep Investigation screen with four stages (`Prioritize`, `Identify`, `Verify`, `Build Plan`), progress metrics, a restrained Storage Orbit, one current-focus card, three discovery cards, and quiet Pause/Stop/Investigation Details controls. No console or logs.

## Deep Investigation B — visual dark

Create a highly visual dark investigation screen dominated by an orbit-based known/unknown storage map and probe locator. Use very little text, three metrics, a compact stage strip, two finding cards, and a minimal progress footer.

## Deep Investigation C — inspector light

Create a light-mode investigation screen demonstrating progressive disclosure: simple central progress plus an open right-side Investigation Details inspector with What it is, Evidence, Counter-evidence, Recovery, Reveal in Finder, and bytes-read information.

## Review A — balanced dark

Create a precise dark Review Reclaim Plan with four summary metrics, compact grouped outline/table rows for Ready to Reclaim, Review Recommended, and Permanent Actions, and a fixed bottom bar with `Reclaim 18.7 GB`. Ready items are checked; review and permanent items are unchecked.

## Review B — visual dark

Create a more approachable visual dark Review Plan with a segmented Trash/Permanent/Not Selected summary and three expandable group cards. Keep the main reclaim action fixed and prominent without using destructive red.

## Review C — inspector light

Create a data-rich light Review Plan with grouped checkbox table, columns for Item/Last Active/Recovery/Size, and an open evidence inspector for Xcode DerivedData. Show Why, Activity, Recovery, Reveal in Finder, and View Evidence.

## Known generation drift

Some candidates contain extra sidebar destinations or example-item grouping that conflicts with the approved product design. Treat these as image-model drift. The approved UI/UX specification overrides every generated label, navigation item, grouping, and action.

Approved overrides to apply explicitly:

- Historical asset headings may say `Dashboard` or `Deep Investigation`; the product destinations/actions are `Overview` and `Deep Dive`, with Deep Dive sessions under `Investigations`.
- The top-level sidebar is exactly `Overview`, `Scan`, `Investigations`, and `History`; Settings, Review, and Cleanup Result are not sidebar destinations.
- Do not implement `Reclaim N GB` as a combined primary action. Ordinary selected items use `Move N Items to Trash`; Registered Actions are separate, and permanent ones require an explicit irreversible confirmation.
- Keep selected item count, estimated processed bytes, bytes moved to Trash, expected permanent release, and observed free-space change as distinct values.
- Use `Ready to Reclaim`, `Review Recommended`, `Protected`, and `Unknown`; do not expose the historical `safe/caution/no` labels.
- The approved Agent mark is Nautilus Probe. Use it only for the current Deep Dive target and evidence progress, not as decoration on known-rule results.

## Overview round 2 — controlled composition draw

This round fixes the theme, content, navigation, action hierarchy, and Agent visibility. Only layout and information density vary. See [round notes and prompts](OVERVIEW-ROUND-2.md).

- `overview-round2-a-orbit-ledger-dark.png` — A / Orbit Ledger: visual orbit plus readable two-axis ledger; recommended balance.
- `overview-round2-b-constellation-dark.png` — B / Constellation: historical exploration asset. Its star/constellation metaphor is rejected; retain only direct labels and functional Probe placement.
- `overview-round2-c-native-console-dark.png` — C / Native Console: compact professional instrument workspace; highest information efficiency.

Selection result, approved 2026-08-08: use A as the dominant hierarchy, add B's direct orbit labels and functional Probe, and reserve C's dense table language for Scan Results and Review.

- `overview-canonical-dark.png` — approved-direction dark reference.
- `overview-canonical-light.png` — theme-paired light reference with identical hierarchy.

Derive Deep Dive and Review from this grammar. Do not combine unrelated candidates page by page.

## Deep Dive round 2 — canonical-grammar draw

All three candidates inherit the canonical Overview sidebar, surfaces, typography, orbit language, palette, and Agent visibility rules. See [round notes](DEEP-DIVE-ROUND-2.md).

- `deep-round2-a-probe-focus-dark.png` — A / Probe Focus: strongest active-observatory feeling; orbit and live findings share attention.
- `deep-round2-b-guided-journey-dark.png` — B / Guided Journey: process-first and easiest to understand; recommended default.
- `deep-round2-c-evidence-inspector-dark.png` — C / Evidence Inspector: optional audit state with the right-side Inspector open, not the default screen.

Generation invariants: title is `Deep Dive`; stages are `Prioritize`, `Identify`, `Verify`, `Build Plan`; no chat, console, raw logs, chain-of-thought, or cleanup action; the Probe marks only the current target; `Discovered by Codex` marks only a new evidence-backed finding.

Selection result, approved 2026-08-08: B is the default page, C is the optional Inspector state, and A contributes Probe trajectory/current-target emphasis. Circular charts remain functional storage visualizations; no constellation or star-map styling.

## Review round 2 — safety-gate draw

All candidates inherit the canonical Stornaut sidebar, dark surfaces, type, spacing, and semantic colors. See [round notes](REVIEW-ROUND-2.md).

- `review-round2-a-decision-table-dark.png` — A / Decision Table: native grouped outline/table, maximum comparison efficiency; recommended default.
- `review-round2-b-decision-cards-dark.png` — B / Decision Cards: more explanatory expandable groups, lower density.
- `review-round2-c-evidence-inspector-dark.png` — C / Evidence Inspector: A with an unselected Review Recommended row focused and the optional audit Inspector open.

Generation invariants: only Ready to Reclaim is selected by default; Review Recommended and Registered Actions are unchecked; Protected and Unknown are disabled; Registered Actions never share the Trash CTA; the primary action is `Move N Items to Trash`, not `Reclaim N GB`; values for selected items, estimated Trash bytes, and Registered Actions remain distinct.

Selection result, approved 2026-08-08: A is the default Review page, C is the optional read-only Evidence Inspector state, and B contributes only the one-line explanations in group headers. B's card layout, merged groups, and incorrect sidebar selection are not adopted.

- `review-canonical-dark.png` — approved-direction dark default Review reference.
- `review-canonical-light.png` — theme-paired light default Review reference with identical hierarchy and safety state.
- `review-round2-c-evidence-inspector-dark.png` — approved Inspector-state reference; the focused Review Recommended row remains unchecked and the Inspector contains no execution action.

## Quick Scan progress — five-candidate internal draw

See [round notes](QUICK-SCAN-ROUND-1.md).

- `quick-scan-round1-a-stage-rail-dark.png` — strongest process explanation.
- `quick-scan-round1-b-growing-ledger-dark.png` — strongest measured/unmeasured visualization.
- `quick-scan-round1-c-native-operations-dark.png` — highest observability and density.
- `quick-scan-round1-d-focus-discoveries-dark.png` — lowest-text visual candidate; rejected semantic drift.
- `quick-scan-round1-e-results-taking-shape-dark.png` — strongest progress-to-results continuity.

Internal selection result, approved 2026-08-08: E is the dominant layout and A contributes the compact five-stage rail. Quick Scan contains no Codex/Agent representation and no cleanup action.

- `quick-scan-canonical-dark.png` — approved dark reference.
- `quick-scan-canonical-light.png` — theme-paired light reference.

## Scan Results — five-candidate internal draw

See [round notes](SCAN-RESULTS-ROUND-1.md).

- `scan-results-round1-a-lifecycle-outline-dark.png` — grouped lifecycle outline; recommended default.
- `scan-results-round1-b-opportunity-first-dark.png` — opportunity cards above a flat table.
- `scan-results-round1-c-category-navigator-dark.png` — category browser with a secondary navigator.
- `scan-results-round1-d-evidence-inspector-dark.png` — optional read-only Inspector state.
- `scan-results-round1-e-ledger-results-dark.png` — two-axis summary ledger plus dense table.

Internal selection result, approved 2026-08-08: A is the default Results page, D is the on-demand Inspector, and E's ledger is allowed only as a collapsed summary. Results have no checkboxes or cleanup controls; selection starts in Review.

- `scan-results-canonical-dark.png` — approved dark default Results reference.
- `scan-results-canonical-light.png` — theme-paired light default Results reference.
- `scan-results-round1-d-evidence-inspector-dark.png` — approved Inspector behavior reference subject to the documented badge/color corrections.

## Onboarding and permissions — five-candidate internal draw

See [round notes](ONBOARDING-ROUND-1.md).

- `onboarding-round1-a-guided-focus-dark.png` — one decision per page with a persistent three-step rail; approved base.
- `onboarding-round1-b-setup-checklist-dark.png` — useful future Settings status pattern, rejected for first launch.
- `onboarding-round1-c-coverage-compare-dark.png` — strongest Full/Limited transparency; compressed into the approved step 2.
- `onboarding-round1-d-contextual-preview-dark.png` — educational coverage example, reserved for help/details.
- `onboarding-round1-e-native-sheet-dark.png` — compact sheet, rejected as the three-step setup structure.

Internal selection result, approved 2026-08-08: A is the dominant structure and C contributes the compact Limited Access consequence strip. Codex installation and Deep Dive safety verification remain separate states; failed verification pauses Deep Dive without affecting Quick Scan.

- `onboarding-welcome-canonical-dark.png` / `onboarding-welcome-canonical-light.png` — step 1 theme pair.
- `onboarding-full-disk-access-canonical-dark.png` / `onboarding-full-disk-access-canonical-light.png` — step 2 theme pair.
- `onboarding-connect-codex-canonical-dark.png` / `onboarding-connect-codex-canonical-light.png` — step 3 theme pair.

## Cleanup Result — five-candidate internal draw

See [round notes](CLEANUP-RESULT-ROUND-1.md).

- `cleanup-result-round1-a-accounting-ledger-dark.png` — strongest explicit accounting separation; adopted as the numeric contract.
- `cleanup-result-round1-b-reversible-first-dark.png` — clearest recoverability-first hierarchy; approved default base.
- `cleanup-result-round1-c-plan-vs-actual-dark.png` — adopted for collapsed `Accounting Details`.
- `cleanup-result-round1-d-manifest-timeline-dark.png` — adopted for the separate Manifest audit view.
- `cleanup-result-round1-e-partial-outcome-dark.png` — approved partial/failure-state reference.

Internal selection result, approved 2026-08-08: B is the default composition, A defines accounting boundaries, and E defines adaptive partial results. C and D are progressive-disclosure states rather than default-page layouts.

- `cleanup-result-canonical-dark.png` — approved dark successful-result reference.
- `cleanup-result-canonical-light.png` — theme-paired light successful-result reference with identical hierarchy and accounting semantics.

## History — five-candidate internal draw

See [round notes](HISTORY-ROUND-1.md).

- `history-round1-a-unified-timeline-dark.png` — strongest chronology and retention language; grouping adopted.
- `history-round1-b-audit-ledger-dark.png` — expert audit table; retained as a possible dense/table substate, not default.
- `history-round1-c-change-story-dark.png` — approved optional `Storage Trend` direction with explicit non-causality caption.
- `history-round1-d-session-cards-dark.png` — approachable but too low-density; rejected as desktop default.
- `history-round1-e-master-detail-dark.png` — strongest native macOS audit workspace; approved default base after TTL corrections.

Internal selection result, approved 2026-08-08: E is the default master-detail structure, A contributes date grouping, and C defines the optional trend state. v1 has fixed default retention plus immediate deletion, not `Adjust Retention`.

- `history-canonical-dark.png` — approved dark default History reference.
- `history-canonical-light.png` — theme-paired light default History reference with identical selection, retention, accounting, and action semantics.

## Settings — five-candidate internal draw

See [round notes](SETTINGS-ROUND-1.md).

- `settings-round1-a-sidebar-privacy-dark.png` — native six-section sidebar and fixed Privacy & Data policy rows; approved shell.
- `settings-round1-b-toolbar-permissions-dark.png` — classic toolbar-tabs exploration; retained as Permissions content reference, not the shell.
- `settings-round1-c-status-summary-general-dark.png` — compact General + Setup Status; adopted after fixture/control corrections.
- `settings-round1-d-single-scroll-dark.png` — single-scroll form; rejected because it compresses unrelated preference and safety concepts.
- `settings-round1-e-local-knowledge-dark.png` — structured knowledge management; adopted after conservative example corrections.

Internal selection result, approved 2026-08-08: A is the Settings shell, C contributes General's status summary, and E defines Local Knowledge management. Editable preferences, runtime status/repair, and immutable safety policy remain visually distinct.

- `settings-general-canonical-dark.png` / `settings-general-canonical-light.png` — General, appearance/language, setup status, and explicit on-demand behavior.
- `settings-codex-deep-dive-canonical-dark.png` / `settings-codex-deep-dive-canonical-light.png` — independent Codex installation and Deep Dive safety states plus default budget presets.
- `settings-local-knowledge-canonical-dark.png` / `settings-local-knowledge-canonical-light.png` — structured confirmed facts, provenance, review, and forgetting.

## Resilience states — cross-flow draw

See [round notes and behavior matrix](RESILIENCE-STATES-ROUND-1.md).

- `resilience-limited-coverage-canonical-dark.png` / `resilience-limited-coverage-canonical-light.png` — measured Quick Scan results remain useful while inaccessible scope is explicitly unmeasurable.
- `resilience-deep-dive-safety-blocked-canonical-dark.png` / `resilience-deep-dive-safety-blocked-canonical-light.png` — Deep Dive remains paused when full investigation capabilities are unavailable or write/no-Executor isolation fails; Quick Scan remains available and no write bypass exists.
- `resilience-stale-plan-canonical-dark.png` / `resilience-stale-plan-canonical-light.png` — execution preflight blocks a changed plan and requires affected items to be refreshed.
- `resilience-partial-investigation-canonical-dark.png` / `resilience-partial-investigation-canonical-light.png` — verified partial evidence is preserved when the budget ends; unresolved targets remain Unknown.
- `resilience-history-expired-canonical-dark.png` / `resilience-history-expired-canonical-light.png` — expired linked evidence does not erase the minimum Cleanup Manifest; corrupt history is isolated by row.
- `resilience-deep-dive-safety-blocked-draft-dark.png` — rejected audit draft because stale success metrics contradicted a not-started investigation.

Selection result, approved 2026-08-08: use one page-preserving recovery grammar across all flows—preserve valid results, label the affected scope, offer only safe recovery, and disclose technical detail on demand. Red is reserved for concrete failures; limited, stale, and budget states use neutral/amber semantics.
