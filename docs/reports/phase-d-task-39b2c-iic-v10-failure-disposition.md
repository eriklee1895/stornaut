# Phase D Task 39B2c ii-c-c v10 failure disposition

> Status: consumed / non-admitting / non-retryable
>
> Date: 2026-09-07

## Result

The authorized v10 privileged campaign durably recorded `prepared`,
`armedConsumed`, `spawnUncertain`, and `terminal`. It did not produce a
coordinator receipt, diagnostic output, manifest, external seal, uninstall
artifact, or global post-teardown artifact. The fixed App, plist, runtime and
service are absent and no fixed Stornaut process remains. The owner-private Gate
attempt and its exact capsule remain preserved.

The attempt is classified as `consumedCampaignDeadlineExhaustion`. It is
non-admitting and non-retryable. It provides no machine admission, no L3c3d
authenticated model success and no Task 39 readiness claim.

## Root-cause evidence

The durable arm event was recorded at UTC microsecond
`1788786289593855`; `spawnUncertain` was recorded at
`1788787484650045`. The elapsed interval was `1,195,056,190` microseconds,
within five seconds of the then-configured 1,200-second campaign deadline. The
operator attestation was persisted about 17 seconds after the evidence root was
created, so the failure is not attributed to delayed credential entry. No new
AMFI `-423` observation was found, and the corrected driver reached the
post-arm runtime path.

The deterministic budget defect is that eight sequential epochs may consume
`8 * 140 = 1,120` seconds while the enclosing campaign allowed only 1,200
seconds. That left at most 80 seconds for prompt relay, Gate/coordinator
startup, inter-epoch orchestration, evidence publication, retirement, uninstall
and verification. No `04-driver-epochs` artifact exists, so this disposition
does not claim which epoch was active when the enclosing deadline expired.

The replacement source contract raises the machine-only campaign horizon to a
finite 1,400 seconds, derived as eight 140-second epochs plus a fixed 280-second
orchestration and cleanup reserve. Generic runtime validity and each individual
epoch remain bounded by their existing 900-second and 140-second limits.
