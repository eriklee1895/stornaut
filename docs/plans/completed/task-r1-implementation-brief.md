# R1 Implementation Brief: Current Runtime and macOS Containment Study

> Status: Complete — conditional-go evidence; the later ADR 0013 transport
> decision is now approved for the R2 configuration candidate
>
> Date: 2026-08-11
>
> Baseline: `549ece3282a7909f085c62a1c036f6172397a9e5`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)

## Scope

R1 selected and measured a runtime/containment candidate without modifying
production Swift runtime code.

Deliverables:

- [x] exact installed Codex/npm/vendor identity;
- [x] exact upstream tag/commit/license;
- [x] Codex permission/Seatbelt/network source study;
- [x] Apple App Sandbox/SDK/manpage study;
- [x] checked-in anonymous no-model containment probe;
- [x] filesystem and descendant mutation evidence;
- [x] restricted/open/managed network matrix;
- [x] direct/no-proxy bypass evidence;
- [x] instruction/skill isolation evidence;
- [x] runtime-home write evidence;
- [x] auth/browser limitations;
- [x] ADR 0013;
- [x] review report;
- [x] docs links/diff hygiene.

## Files

Created:

```text
scripts/probe-codex-sandbox-containment
docs/upstream-studies/epic-5-capability-first-runtime.md
docs/adr/0013-capability-first-runtime-containment.md
docs/plans/active/task-r1-implementation-brief.md
docs/reports/capability-first-runtime-r1-review.md
```

Updated:

```text
AGENTS.md
README.md
docs/README.md
docs/agent/coding-agent-handoff.md
docs/adr/README.md
docs/upstream-studies/README.md
docs/reports/README.md
docs/plans/active/README.md
docs/plans/roadmap.md
```

## Experiment Contract

`scripts/probe-codex-sandbox-containment`:

- uses only `/tmp/stornaut-codex-containment.*`;
- uses an empty isolated `CODEX_HOME`;
- does not read `~/.codex`;
- does not call a model;
- does not use auth;
- starts only disposable TCP/private-address and Unix-socket canaries;
- verifies post-state after mutation attempts;
- cleans roots/listeners on success, failure and signal;
- emits bounded verdict lines only.

## Result

### Filesystem

All requested user-data mutation classes and a nested descendant were blocked.
Read remained available.

### Network

- restricted profile: safe but no public command network;
- bare enabled profile: unsafe because arbitrary local/private/Unix access is
  reachable;
- managed proxy profile: public through proxy works; all direct bypass and
  arbitrary local/private/Unix probes fail.

### Other

- named profile can extend `:read-only` and independently enable network;
- isolated Runtime Home can expose a Stornaut skill without loading target
  `AGENTS.md`;
- subagent source/tests inherit and reapply the runtime profile;
- Browser Use is advertised but not standalone CLI behavior;
- `--ephemeral` still requires substantial private Runtime Home writes;
- isolated authenticated home remains unresolved.

## Conditional Gate

R1 outcome:

```text
conditional-go
```

Blocking question:

```text
Allow one same-session, random-port, parent-owned loopback managed-proxy
transport for Codex descendants, while every other localhost/private/link-local
destination and every Unix socket remains blocked?
```

No R2 production implementation starts before that decision.

## Validation Evidence

Final probe:

```text
/tmp/stornaut-r1-containment-probe-final-2.log
SHA-256 2c5625b6f94164cc4c238fcd24a3b53d9104b84a340a0e2a9c0a161fb1c3c857
```

The final review records its SHA-256 and all documentation checks. No model
token, user credential, raw JSONL, private file or real cleanup path is part of
R1 evidence.
