# Phase D Task 39B2c ii-c-c v14 preserved-v13 prerequisite review

> Status: implementation complete / non-admitting / fresh authorization required
>
> Date: 2026-09-12
>
> Pre-repair launch seal: `e717b586cb430d1866249ddb13ac2d04e81e6519`

## Result

The v14 pre-arm inspection found that the production coordinator still selected
an empty stale-recovery preservation set while the Application Support Gate held
the exact consumed v13 attempt and capsule. Launching that source would have
removed v13 before durable arm and would have violated the authorization's
historical-evidence boundary. No campaign executable was launched, no campaign
or attempt UUID was generated, no launch claim was created, and no root action
occurred. The v14 authorization therefore remains unconsumed but cannot apply to
the repaired source.

The prerequisite adds one closed production profile that preserves only the
fixed v13 capsule. It does not accept a caller-provided list, environment value,
CLI argument or wire field. Existing stale-recovery ordering remains unchanged:
all candidates are classified and all preserved contracts are validated before
any unrelated stale entry can be removed.

The final Gate observation now uses strict global-post-teardown schema v4. It
binds the persistent Application Support base and owner lock together with the
exact v13 attempt/capsule identity and bytes. Schema 1-3 retain their historical
decode meaning; schema 3 is no longer sufficient for a new admission.

## Fixed v13 contract

- attempt UUID: `a77c4d21-9bba-46f6-b694-3d1d1e55209d`;
- whole projected input SHA-256:
  `c484b8c14a5e70a4ee4364584013f864af30738c52494ebb727ac4fb326dfdc0`;
- capsule byte count: `28,997`;
- capsule SHA-256:
  `1567a7fc8f13da51b69c134bb79ac132d383ae30496bb5ae86674ac3fa9f8a17`.

## Validation

- schema-v4 contract, exact v13 constant and production-profile focused tests
  passed;
- eight preserved-tree physical mutations fail closed without changing their
  fixture tree;
- a synthetic complete cohort is admitted only with schema v4 and the exact
  live Application Support Gate; before/after Gate snapshots are identical;
- schema-v3 complete corpus is decoded but remains non-admitting;
- ordinary Evidence + Boundary coverage passed 168 tests, the physical fixture
  suite passed 3 tests, and the owner-only capsule suite passed 40 tests;
- the fixture-only empty-Gate profile was compiled and linked from source in a
  temporary module; ordinary package and product builds cannot see that profile;
- the ii-c aggregate source/mutation contract and failure/status contract
  passed;
- Debug/Release campaign, persistent-Gate and suspended-sudo component gates
  passed;
- both independent post-fix reviewers reported no unresolved P0-P2;
- the final clean serialized SwiftPM regression passed 1,974 tests in 100
  suites with zero failures in 221.601 seconds (224.95 seconds wall time).

An earlier serial invocation encountered five `EEXIST` failures because an
overlapping read-only review had left the one fixed synthetic failure-disposition
fixture directory in the account temporary root. The directory was confirmed
owner-only, unreferenced by any process and limited to that synthetic fixture,
then moved to an isolated quarantine. All five exact failed tests passed before
the clean serialized regression above. No product or campaign evidence was
removed or rewritten.

This checkpoint does not authorize or execute another campaign, does not invoke
sudo, and does not unlock L3c3d, L3c4, Task 40 or production Deep Dive. A new
explicit user authorization bound to the pushed repair commit is required.
