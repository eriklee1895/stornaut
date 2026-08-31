# Phase D Task 39B2c ii-c-b2b PTY / FD 3 Transport Preflight

> Status: frozen / implementation pending / non-privileged / non-admitting
>
> Date: 2026-08-31
>
> Baseline: `294bdb207e572eead2be43921e603ce7407dcbc5`
>
> Budget: exact 11 non-document paths / at most 3,600 changed lines
>
> Remaining order: ii-c-b2b -> ii-c-c -> L3c3d -> L3c4

## 1. Scope

ii-c-b2b owns only the non-privileged controlling-PTY / FD 3 transport around
a fixed sibling coordinator-shaped fixture. It does not execute the installed
coordinator or Gate, consume authorization, run Codex, use network/XPC, install
anything or make a machine-readiness claim.

The exact non-document path set is:

1. `Package.swift`;
2. `Sources/CInvestigationMachineCampaignSupport/include/CInvestigationMachineCampaignSupport.h` (new);
3. `Sources/CInvestigationMachineCampaignSupport/CInvestigationMachineCampaignSupport.c` (new);
4. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignHarness.swift` (new);
5. `Sources/StornautInvestigationMachineCampaign/main.swift` (new);
6. `Tests/Fixtures/InvestigationMachineCampaignCoordinator/main.swift` (new);
7. `Tests/StornautInvestigationTests/InvestigationMachineCampaignHarnessTests.swift` (new);
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-app-release-boundaries`; and
11. `scripts/verify-contract`.

The twelfth path remains unused contingency. If the exact scope is estimated to
exceed 3,600 changed lines before implementation completes, the only permitted
split is b2b1 transport/injected lifecycle followed by b2b2 physical fixture
and aggregate gates. No further recursive checkpoint naming is permitted.

## 2. Frozen Contract

- One fixed sibling coordinator; no executable-path, argv or environment
  selector. The package executable is DEBUG-only in behavior, takes zero
  arguments and returns fixed unavailable status 78 outside DEBUG.
- One absolute monotonic deadline covers PTY creation, spawn, both drains,
  wait/reap and failure cleanup.
- The C child path is async-signal-safe and immediately performs
  `setsid -> TIOCSCTTY -> tcsetpgrp -> dup2/close -> execve`; no Swift or
  Foundation code runs after fork.
- The parent closes transfer FDs immediately, fairly drains PTY and FD 3,
  accepts exactly one bounded length-prefixed canonical receipt followed by
  EOF, and treats PTY bytes as diagnostics only.
- The outer coordinator PID/start token/SID/PGID is independently observed and
  never equated with the inner Gate PID/PGID/SID carried by the receipt.
- Success requires exact exit 0, receipt binding, EOF, exact wait/reap and zero
  SID/PGID residue. Spawn uncertainty remains owned until bounded cleanup
  proves absence.
- The harness imports neither CoordinatorSupport nor MachineLaunchSupport and
  gains no production, cleanup, auth, model, network, XPC or installed-artifact
  authority. Existing evidence contracts and writer are reused unchanged.

## 3. Tests First and Validation

The RED matrix must cover structural target closure; injected state transitions
and cleanup precedence; strict FD 3 framing; fair interleaved PTY/receipt drain
beyond individual buffer capacity; malformed, short, oversized, trailing and
missing-EOF frames; nonzero/signal exit; stubborn FD descendant; deadline;
outer identity drift; success-after-failure recovery; and exact process, PTY,
FD and temporary residue zero.

Validation order is fixed:

1. structural/source contract;
2. focused injected and physical tests;
3. exactly one clean staged-only serialized `StornautInvestigationTests` run;
4. targeted non-product Debug/Release builds and component/final-image gate;
5. aggregate mutation/replay contract;
6. independent grouped and cross-boundary review.

`scripts/verify --full` remains reserved for L3c4. There is no sudo/root,
install/uninstall, system launchctl, product XPC, real Codex/auth/model/network,
real `armedConsumed` transition or privileged machine campaign in b2b.
