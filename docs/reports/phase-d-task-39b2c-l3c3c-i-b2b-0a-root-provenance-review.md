# Phase D Task 39B2c-L3c3c-i-b2b-0a Root-Launch Trust-Anchor Audit

> Status: Complete; external staging is NO-GO, installed driver conditionally
> selected for implementation preflight
>
> Date: 2026-08-19
>
> Baseline: `b15bd082a44b3e2895fc7f150e5018ef37d522df`
>
> Scope: repository-external read-only root-launch audit and documentation only;
> no product implementation, install, privileged execution, model call, serial
> regression or full verifier

## 1. Decision

L3c3c-i-b2b-0a is complete as a **root-launch trust-anchor audit**, not as an
admission of the external final7 topology. Two independent reviews of the
current no-cache WIP returned **NO-GO** for every UID-staged external B4 root
path. The earlier `sudo -v` stager is rejected because it creates ambient cached
root authority. The later no-cache stager/driver shape is also rejected: stock
macOS commands do not provide an unskippable root-side verify-and-act gate for
UID-controlled source artifacts without a preinstalled root trust anchor.

The rejected branch did not execute as root:

- B4 root execution count remains `0`;
- the external stager and evidence driver were not executed as root;
- `/private/var/tmp/stornaut-l3c3ci-b4-d1572410` was never created; and
- no root-owned artifact, armed/final receipt, result JSONL, stderr or return-code
  receipt exists.

Therefore i-b2b-0b root-owned external staging and i-b2b-1 external privileged
B4 execution are **superseded before execution**, not pending checkpoints. Their
absence is not a pass or a fail for runtime behavior; it is proof that the
rejected branch consumed no root execution.

The only conditional next candidate is the diagnostic-only
`StornautInvestigationMachineDriver`, whose installer/L2 contract previously
proved the root-owned transition but whose fixed installed App is currently
absent. This is a plan selection, not accepted design or machine evidence. ADR
0018 remains Proposed until one green current-source installed-driver gate.

## 2. Why External Staging Is Rejected

### 2.1 Ambient `sudo -v` authority

The original flow authenticated with `sudo -v` and then relied on a timestamp
ticket for later root commands. That ticket was broader and longer-lived than
the exact diagnostic action. It could authorize an unrelated root command and
could not be bound to one B4 attempt. This branch is rejected.

### 2.2 UID-staged root-owned immutable leaves

The final external WIP improved byte and receipt provenance with held
`O_NOFOLLOW` descriptors, root-owned immutable leaves, fixed paths and a
root-owned evidence driver. Those properties are useful historical design
evidence, but they do not create the missing trust anchor. The administrator
still chooses and launches an executable originating in UID-controlled staging,
and the ordinary command surface cannot make the intended root verification an
unskippable prerequisite to the root action.

Neither `sudo`, shell composition, `mkdir`, `tee`, `chown`, `chmod`, `chflags`,
`mv` nor a sequence of their stock macOS peers atomically establishes both:

1. the exact reviewed bytes and identity were admitted by a root-owned policy;
2. only those admitted bytes can perform the subsequent root action.

A review script can detect drift after the fact, but it cannot turn a
caller-controlled root command line into a non-bypassable verify-and-act gate.
Changing from cached authentication to a no-cache command removes ambient cache
risk; it does not supply the missing root trust anchor. Both independent reviews
therefore returned NO-GO for the current no-cache external WIP.

### 2.3 Historical external artifacts are non-admitting

The rejected final7 artifacts remain outside the repository and retain their
historical hashes so the failed branch is reproducible and cannot be silently
recast as machine evidence:

| Artifact | Historical identity | Current meaning |
| --- | --- | --- |
| B4 source | `e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25` | reviewed external source only |
| B4 executable | `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d` | never root-executed |
| root evidence-driver source | `aa4864ad72a75f43bb29fcc6eb1ab815e79a9e3a5afc90ab6ae1567a7848ddf1` | rejected external trust-anchor attempt |
| root evidence-driver binary | `7c3b907d71504bfa2755ebcd794c7ebf5ba349a5218348fe1bac4fe3d538ff5d` | never root-executed |
| immutable-stager source | `549134cec27a3b24d16b8c2e468fdb4f0632bf98870559674c59f6a400936d5a` | rejected external staging design |
| immutable-stager binary | `43b95e985e1b8529dec669da84590996be8a7b651fb208372f0b7c6e7913600b` | never root-executed |
| strict verifier | `80ca29b8bcc1d1ab2eee80ed9dd5732d444b35bbb7d6fb200e04361057bcf92f` | synthetic/non-admitting evidence only |

The synthetic verifier's structural positive exited `75`, and 25/25
adversarial negatives were rejected. Those results validate portions of the
proposed protocol and failure taxonomy. They do not admit the external launch
path, prove root behavior or create a receipt.

## 3. Conditional Installed-Driver Trust Anchor

The diagnostic-only driver is conditionally selected because its existing
installer/L2 contracts already prove how the built artifact must transition to
a root-owned installed node and join complete static identity evidence. It is
currently absent and must be rebuilt, installed and re-admitted in ii-c. Its
exact fixed executable path is:

```text
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

The candidate ceremony first requires this non-executing policy probe to return
nonzero:

```text
/usr/bin/sudo -kNnv
```

It then invokes exactly:

```text
/usr/bin/sudo -kN -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application\ Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

This command is a candidate for the one machine-only gate, not an instruction to
run it now. With a command, `-k` makes that invocation ignore the applicable
cached credentials and not update them; `-N` independently states the no-update
intent. It does not claim to erase unrelated timestamp records or prove a
prompt occurred. The trusted operator must observe and record the exact fixed
prompt; otherwise the result is non-admitting. No cache-creating `sudo -v` step
is allowed. The driver receives zero arguments. The invocation
supplies no environment override, config, executable, path, UID, endpoint,
signal, action or cleanup input; the driver must not consume any of those as a
behavioral input.

Before it may create a socketpair or launch the fixed diagnostic App, the driver
must self-observe the installed trust anchor. At minimum that observation must
join:

- real/effective root identity;
- the exact fixed installed path above;
- installer-proved no-ACL plus L2 root-owned regular-node, owner/group, mode,
  link and size constraints;
- actual executable SHA-256 through a held descriptor;
- signing identifier
  `com.eriklee.stornaut.investigation.machine-driver`;
- designated-requirement bytes and CodeDirectory hash; and
- the fixed Machine-claim service identity already carried by the L2 binding.

Because current L2 node metadata has no ACL field, ii-a must also observe ACL
absence directly and ii-c must join that observation with the installer's ACL
proof; full installed-L2 is not credited with ACL detection.

The zero-argument driver cannot embed an expected full-file SHA without a
circular build, and no root-owned binding sidecar currently exists. Trust before
its first instruction comes from exact root-owned install plus static installed-
artifact/service-bootstrap admission. ii-c must compare the driver's pre/post
observed identity to that frozen static binding independently; full installed-L2
follows App launch before transition/`EXIT`. Failure at any observable join is terminal and
occurs before App launch. No caller-selected
fallback or external staged executable is allowed. The driver remains
diagnostic-only and must acquire no Cleanup, Policy, Trash, Executor or
Registered Action authority.

## 4. Revised L3c3c Split

The rejected external branch is closed. Product implementation is now split to
keep each checkpoint below the repository's review ceiling:

1. **L3c3c-ii-a — authority-closed live driver runtime extraction and final-
   Mach-O gate.** Add only root self-observation, fixed socketpair/launch/lifecycle
   authority and typed non-Codable outcomes to the diagnostic driver runtime.
   Prove the final driver contains no Cleanup/Policy/Trash/Executor/Registered
   Action surface. No install, sudo, App launch or model call.
2. **L3c3c-ii-b — fixed installed-driver launch and transition composition.**
   Compose the exact installed driver, prelaunch socketpair, fixed diagnostic App
   handoff, root-to-UID transition, installed-L2 observation and bounded
   retirement. Use fakes or non-privileged composition evidence only; no sudo or
   model call.
3. **L3c3c-ii-c — exactly one no-model current-source outer driver gate.**
   Build/install the exact current-source diagnostic topology, invoke only the
   fixed installed driver with the exact no-cache command above, require driver
   observation to match the frozen installer/L2 binding and the complete
   closed scenario-epoch failure/cleanup matrix, then uninstall and
   prove zero residue. No retry repairs an implementation defect.
4. **L3c3d — real-model pending candidate.** Only after ii-c is green may one
   real authenticated model attempt produce a non-readiness candidate.
5. **L3c4 — sealed final admission and full.** L3c4 alone may make the Task 39
   readiness decision and consume the remaining authoritative full verifier.

The corresponding implementation path/cost ceiling is frozen in the
[installed-driver preflight](phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).

## 5. Validation and Non-Claims

| Requirement | Current status |
| --- | --- |
| old `sudo -v` stager | **rejected** |
| all UID-staged external B4 root paths | **NO-GO** |
| two independent reviews of current no-cache WIP | **NO-GO** |
| i-b2b-0a root-launch trust-anchor audit | **complete** |
| i-b2b-0b external immutable staging | **superseded before execution** |
| i-b2b-1 external privileged B4 run | **superseded before execution** |
| B4 root execution / root artifact / receipt | **0 / absent / absent** |
| installed diagnostic driver | **conditionally selected; not yet implemented as the live trust anchor** |
| ADR 0018 | **Proposed** |
| product Deep Dive | **unavailable** |
| Task 39 readiness | **not claimed** |
| remaining authoritative full verifier | **unconsumed; reserved for L3c4** |

No machine behavior, accepted design, production availability or readiness is
claimed by this documentation audit.
