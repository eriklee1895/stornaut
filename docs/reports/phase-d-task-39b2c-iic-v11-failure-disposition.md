# Phase D Task 39B2c ii-c-c v11 failure disposition

> Status: consumed / non-admitting / non-retryable
>
> Date: 2026-09-08
>
> Frozen source: 8a286ea41d73b0874c6775cc6f79736f972782fe
>
> Campaign: 4ae73d0f-88c7-4cb9-a5e4-9eae2482c99b
>
> Attempt: 18a85048-5e1c-40c5-99e4-3785185070d3

## Result

The newly authorized campaign durably recorded prepared, armedConsumed,
spawnUncertain and terminal. The operator interaction was observed after the
exact fixed driver prompt, and no credential bytes were retained. The campaign
produced no epoch evidence, coordinator receipt, diagnostic output, manifest or
external seal. An external launcher recorded exit status 70, but no retained
campaign artifact independently binds that value, so it is not a checked
disposition field or an input to the classification.

The attempt is consumed, non-admitting and non-retryable. A second
authorization cannot retry this attempt.

The checked disposition classification is
`consumedPostArmFailureUnclassified`. It is deliberately narrower than a
sudo, credential, Gate protocol or transport diagnosis because the legacy
event payload did not retain those discriminators.
The root-cause observation records this limitation as
`legacyGenericPostArmFailureProjection`.

## Evidence-bounded classification

The durable arm event was recorded at UTC microsecond 1788835011400828;
spawnUncertain followed at 1788835027659532, 16.258704 seconds later, and
terminal followed at 1788835027662832. The fixed App, plist and service are
absent and no fixed runtime process remains. The fresh Gate attempt and its
exact 28,997-byte capsule remain preserved.

The accepted source used the legacy generic post-arm reason
campaign-incomplete. It did not persist the harness primary failure, exact wait
classification, receipt EOF, terminal EOF or cleanup issue set. This evidence
therefore cannot distinguish an authentication rejection, sudo exit, signal,
Gate receipt failure, protocol rejection or transport closure. It must not
claim that the administrator password was correct or incorrect.

## Follow-up repair

The successor source replaces the generic reason with a closed, bounded
projection of harness primary failure, exact wait, receipt/terminal EOF and a
cleanup bitmask. The existing event wire remains unchanged, historical schema
v1 events remain readable, and new spawnUncertain events use schema v2. No
terminal bytes, credential bytes or credential-entry timing enter evidence.

This repair is non-admitting. A future campaign requires a new explicit user
authorization, a fresh campaign UUID, a fresh attempt UUID and a fresh evidence
root. L3c3d, L3c4, Task 39 readiness and production Deep Dive remain blocked.
