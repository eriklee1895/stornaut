# ADR 0013: Capability-First Codex Runtime Containment

> Status: Proposed conditional-go — explicit dedicated loopback proxy decision
> required before R2
>
> Date: 2026-08-11
>
> Decision owners: Stornaut maintainers
>
> Study:
> [Epic 5 Capability-First Runtime](../upstream-studies/epic-5-capability-first-runtime.md)
>
> Governing boundary:
> [ADR 0004](0004-codex-file-read-isolation.md)

## Context

ADR 0004 allows Codex to use direct read, shell/unified exec, live search,
browser/direct fetch, image, skills, subagents and public internet. It retains:

- no user-data writes by Codex or descendants;
- no arbitrary localhost/private/link-local network;
- no arbitrary Unix socket;
- no Trash, Registered Action, Policy bypass or Executor route;
- no `danger-full-access`;
- no executable/public-domain allowlist or per-command approval.

The existing Stornaut runtime disables most approved capabilities. R1 evaluated
installed Codex `0.147.0` and current macOS before changing production code.

## Evidence

### Filesystem

Codex named permission profiles separate filesystem and network policy. A
profile extending `:read-only` allowed reads but blocked create, append,
truncate, rename, unlink, mkdir, chmod, xattr, timestamp, hardlink, symlink,
symlink-assisted write and descendant write. Post-state was unchanged.

### Network

Three real Seatbelt profiles produced:

| Profile | Public | Loopback/private | Unix socket | Direct bypass |
| --- | --- | --- | --- | --- |
| Restricted | blocked | blocked | blocked | blocked |
| Bare enabled | allowed | allowed | allowed | allowed |
| Managed proxy | allowed via proxy | blocked | blocked | blocked |

Managed proxy is the only observed candidate that satisfies public egress and
arbitrary local-target denial. It requires a child connection to one
parent-owned random loopback proxy port.

### Runtime home

`--ephemeral` still initializes SQLite, runtime wrappers, system skills and
plugin state. Codex needs one private writable runtime home even when target
data is read-only.

### Instructions and auth

An isolated home plus `project_doc_max_bytes=0` excluded user/target
`AGENTS.md`, while an isolated synthetic skill remained discoverable.
`--ignore-user-config` does not relocate auth: authentication still comes from
the selected `CODEX_HOME`. Safe auth projection is unresolved.

### Browser

Browser feature declarations are stable, but the actual Browser Use connector
is supplied by a desktop/App integration rather than proved by CLI feature
output. Browser containment remains an R5 gate.

## Decision

### Accepted design facts

1. Use a named permission profile, not the old fixed `sandbox_mode` disable
   profile.
2. The filesystem base extends `:read-only`.
3. Codex and descendants may write only an owner-only Stornaut ephemeral
   runtime home outside every user/investigation root.
4. Public command network must use Codex managed proxy containment; bare
   network-enabled Seatbelt is rejected.
5. Managed proxy has:
   - full public destination coverage;
   - `allow_local_binding = false`;
   - no Unix-socket allow entries;
   - no credential broker;
   - no MITM hooks;
   - no user service credentials.
6. Direct/no-proxy network must remain blocked by Seatbelt.
7. Isolated runtime home and project-doc zero limit remain mandatory.
8. Subagents must inherit the same permission profile.
9. Browser is not promoted from advertised to observed until signed-App
   evidence.
10. Swift remains the only path to Policy/Executor.

### Pending decision

R2 is blocked until the user explicitly approves or rejects this exact
exception:

> Codex descendants may connect only to a managed proxy listener that is
> created by the same Stornaut/Codex investigation session on a random
> loopback port. Every other loopback/private/link-local destination and every
> Unix socket remains blocked.

This exception does not authorize:

- arbitrary localhost investigation;
- user-selected proxy endpoints;
- fixed well-known ports;
- local model/service access;
- private-network access;
- Unix sockets;
- browser CDP endpoints;
- remote writes.

## Rejected Alternatives

- `danger-full-access`;
- bare network-enabled Seatbelt;
- public-domain allowlist;
- executable allowlist;
- per-command approval;
- prompt-only or wrapper-only write denial;
- loading the user's full Codex home;
- copying/symlinking auth without a bounded R3 design;
- enabling App Sandbox for the whole product without FDA/full-disk evidence;
- declaring Browser Use supported from feature flags alone.

## Consequences

Positive:

- direct read and normal Agent tools remain possible;
- filesystem write denial is inherited by descendants;
- public destination domains remain unrestricted;
- private resolved addresses and direct bypass are blocked;
- Unix sockets stay unavailable;
- the proxy creates a single inspectable enforcement choke point;
- no new third-party dependency is introduced.

Costs:

- `network_proxy` is experimental in `0.147.0`;
- generated Seatbelt profiles rely on deprecated `sandbox-exec`;
- one dedicated loopback connection is technically necessary;
- Codex needs private runtime writes;
- auth projection requires a security design;
- Browser Use may require a different local transport and may still fail;
- every Codex/macOS upgrade invalidates behavioral evidence.

## Residual Risks

1. DNS rebinding and redirect/CNAME behavior require R3 adversarial tests.
2. The proxy port must be unforgeably bound to the current session.
3. Proxy environment stripping and direct sockets must stay blocked.
4. Proxy crash/fallback must fail closed.
5. Auth refresh must not mutate the original user auth store.
6. Private Runtime Home cleanup must survive cancellation/crash.
7. Skills and subagents must not introduce broader writable roots.
8. Browser connector topology is unresolved.
9. Deprecated Seatbelt API availability must be probed at runtime.
10. Signed-App FDA/TCC inheritance remains unproved for the new profile.

## Validation

Current R1 evidence:

```text
scripts/probe-codex-sandbox-containment
/tmp/stornaut-r1-containment-probe-v2.log
```

R2 may start only after the pending decision. R3 must then add:

- typed profile generation tests;
- full filesystem mutation matrix;
- proxy-port identity and bypass tests;
- IPv4/IPv6/private/link-local/rebinding/redirect tests;
- descendant and cancellation stress;
- runtime-home/auth lifecycle tests;
- signed-App evidence.

ADR 0013 remains Proposed until the pending exception is decided and R3
behavioral evidence passes.
