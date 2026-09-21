# Epic 1 Trash and Registered Actions Upstream Study

> 状态：Accepted as the study gate for Epic 1 Task 7
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：Policy Gate、MoveToTrash、Registered Action lifecycle、platform probes

## 1. Executive Conclusion

Task 7 should implement one write seam with two and only two action shapes:

- `MoveToTrash(PathAction)`;
- `RunRegisteredAction(RegisteredActionRequest)`.

The Policy Gate must bind approval to canonical path identity and the registry
definition. The Executor must revalidate immediately before execution and never
accept executable/argument strings from Agent output.

Production Trash uses `FileManager.trashItem`. It must retain the resulting
Trash URL when supplied, verify that the original path no longer names the
approved identity, and report measured bytes as *moved to Trash*, never as free
space released. Trash failure has no permanent-delete fallback.

Epic 1 registers no real destructive tool. The only registered action is a
test fixture with a fixed executable and an enum-controlled mode. It proves
preflight, dry-run, timeout, execution, postflight and partial failure without
expanding the product write boundary.

## 2. Current Apple Contract

Execution-time Xcode 26.6 / macOS SDK 26.5 declares:

```text
trashItemAtURL:resultingItemURL:error:
```

The SDK header states:

- success means the item was moved to a Trash;
- the operation may rename the item to avoid collisions;
- the resulting URL is returned by reference;
- failure means the item was not moved and returns an error;
- Trash membership can be checked with the FileManager directory relationship
  API.

Swift exposes:

```swift
FileManager.trashItem(
    at: URL,
    resultingItemURL: AutoreleasingUnsafeMutablePointer<NSURL?>?
) throws
```

This API contract is stronger than hard-coding `~/.Trash`, especially for
name collisions and volume-specific Trash. Stornaut still performs a
postcondition check because platform/TCC/live-path changes must not become
phantom success.

Context7 did not index the Apple `trashItem` page directly; the accepted API
evidence is therefore Xcode's current Foundation SDK header plus the compiled
Swift signature. A web search for the Apple page returned no indexed result.

## 3. Upstream Snapshots

| Source | commit/version | license | Files read |
| --- | --- | --- | --- |
| [PureMac](https://github.com/momenbasel/PureMac) | `e586b50bb30f68d0afff173e7d8389a50020095e` | MIT | `AppState.swift`, `CleaningEngine.swift`, `FileProtection.swift`, FDA code, license |
| [ClearDisk](https://github.com/bysiber/cleardisk) | tag `v1.9.0`, commit `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `DiskMonitor.swift`, license |
| [devklean](https://github.com/smurftyy/devklean) | `ce61a18343d67dc67d6e75bcab980a9954097a59` | MIT | deletion safety/trash/integrity, dry-run/deletion/safety tests, license |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | `7724df7111bff82ae243301cf701992ef05ecf19` | Apache-2.0 + Commons Clause | `UndoManager.swift`, `UndoHistoryManager.swift`, helper/trash call sites, license |
| Apple Foundation | macOS 26.5 SDK in Xcode 26.6 | Apple SDK terms | `NSFileManager.h` Trash contract, compiled Swift signature |

### Source fingerprints

| File | SHA-256 |
| --- | --- |
| PureMac `AppState.swift` | `79c08df2f97a29bd2410c2d72afbb8695d4e0a6fe1ac60f9d9664450d4841d2d` |
| PureMac `CleaningEngine.swift` | `c9a42eb1dcbb6d91b8613a6f31e99d7ffdf065feb5474cf7cfb23ee0bce9e762` |
| PureMac `FileProtection.swift` | `a0ed22c1f9571c99dd3cb5828914e8e0128f9417e4f77f57091b3a513027c544` |
| ClearDisk `DiskMonitor.swift` | `4e0d766d3f6be1989e7d71efe2104461823c767fcb80735c10f08b18788cc7fb` |
| devklean `safety.py` | `54f2729d5cb489de3bf271836fa4f46c49e1b06d939b96c4f63ac8340976c782` |
| devklean `trash.py` | `063d688336c4884e0a1b7674157bfcb97847b11cb32a410a6aae49440213f28f` |
| devklean `integrity.py` | `9f06af223ab3fdea06fcebebaeb070af0b40921ac275ec68f6c4fda7d986f722` |
| Pearcleaner `UndoManager.swift` | `3d547170004dc73a3e511578b9ceff2fc86a0724cd1defee5830cdc4ce0a1ed0` |
| Pearcleaner `UndoHistoryManager.swift` | `7dbaec6cf920f50807704be84f5e3701f1d2d5e0a9ff3ee93ffa14239d8fcb1c` |

No upstream code is copied into Stornaut.

## 4. Findings

### 4.1 PureMac

PureMac's App-owned `FileManager.trashItem` call is a useful TCC lesson: the
process performing the filesystem operation owns the permission decision.
It captures `resultingItemURL`, distinguishes missing/permission/admin cases,
and has separate FDA coordination.

Its lower-level cleaning path resolves a URL, validates it, resolves again just
before delete and aborts on change. It also checks SIP/immutable BSD flags and
`com.apple.rootless`.

Useful behavior:

- App process owns Trash;
- preflight and immediate revalidation are separate;
- permission, missing and protected failures are distinct;
- a returned Trash URL matters.

Rejected:

- admin permanent deletion fallback;
- emptying Trash;
- broad real cache commands;
- treating missing as removed without an expected-identity contract.

### 4.2 ClearDisk

ClearDisk calls `trashItem` and then checks whether the original path still
exists, specifically to avoid reporting phantom savings after TCC/volume edge
cases. It does not fall back to permanent deletion. Project history is written
only when Trash succeeds.

Useful behavior:

- postcondition check;
- failed Trash reappears on rescan;
- history only after success.

Stornaut improves this by binding preflight to device/inode/type/size/mtime,
preserving resulting Trash URL, and not describing Trash bytes as recovered
free space.

### 4.3 devklean

devklean centralizes root/home/mount/protected/symlink safety and structurally
returns from dry-run before any Trash call. Its incident-driven compression
tests establish a useful ordering:

```text
create archive → verify archive → Trash archive → remove original
```

Failure before the verified Trash copy leaves the original untouched; failure
afterwards is a distinct partial outcome.

Task 7 does not implement compression, but adopts:

- one safety gate;
- structural dry-run;
- per-action failure without cascading guesses;
- explicit partial outcomes;
- OS-independent fake Trash tests.

Unlike devklean, Stornaut has no symlink opt-out and no direct delete after
Trash in the ordinary path.

### 4.4 Pearcleaner

Pearcleaner maintains custom Trash bundle folders and persistent original↔Trash
path pairs to support Undo. It demonstrates why collision-safe destination
paths and stale history cleanup matter.

Its implementation also builds shell command strings, uses privileged helpers
and has direct-shell fallbacks. Those are explicit negative references for
Stornaut:

- no arbitrary command string;
- no `sh -c`;
- no helper escalation in this Spike;
- no custom Trash implementation when Foundation provides one;
- no claim that a retained path pair guarantees future undo after Trash is
  emptied or changed.

Because Pearcleaner is Apache-2.0 plus Commons Clause, Stornaut treats it as
source-available design observation only and copies nothing.

## 5. Task 7 Implementation Brief

### Domain types

`CleanupAction`:

```text
moveToTrash(PathAction)
runRegisteredAction(RegisteredActionRequest)
```

`PathAction` carries target URL, expected `ActionFileIdentity`, expected bytes
and preflight observation timestamp. It does not carry a shell command.

`RegisteredActionRequest` carries only a registered ID and enum mode. Agent
text is never accepted as executable or arguments.

### Policy Gate

Reject:

- `/`, HOME, volume/mount roots and immutable denylist paths;
- symlinks;
- missing/inaccessible paths;
- active paths;
- device/inode/type/size/mtime drift;
- unregistered action IDs;
- any arguments not produced by the registered definition.

Preflight returns an opaque token containing the approved action and identity.
Execution revalidates from this token. A path swapped between preflight and
execution fails closed.

### Trash

`TrashMoving` depends on an injectable `TrashAdapting` protocol.

Production adapter:

- invokes `FileManager.trashItem`;
- captures the resulting URL;
- returns no permanent-delete path.

Receipt:

- original URL and identity;
- resulting Trash URL when supplied;
- observed timestamp;
- logical/allocated bytes moved;
- does not contain `freedBytes`.

### Registered action

The test-only registry definition fixes:

- one executable URL under `Tests/Fixtures/Actions`;
- an enum mode mapped to a fixed argument array;
- timeout and output limits;
- dry-run support;
- postflight measurement.

No Homebrew, uv, pnpm, Docker or other real destructive action is registered.

### Lifecycle

```text
preflight → optional dry-run → execute → postflight
```

- cancellation before execution performs no write;
- execution consumes only a valid preflight token;
- postflight distinguishes success, partial failure and failure;
- timeout terminates the fixture process;
- one action failure does not synthesize success or run unplanned actions.

## 6. Platform Probe Plan

Use uniquely named disposable temporary fixtures only:

- same-volume real `FileManager.trashItem`;
- collision by trashing two same-named fixtures from different parents;
- permission denial using a controlled adapter/fixture where the current
  process cannot safely manufacture alternate TCC state;
- cancellation before invocation;
- a moderately large disposable directory to observe that Foundation Trash is
  a synchronous call with no mid-call cancellation contract;
- mounted disposable volume only if one is already safely available; otherwise
  record unmeasured.

The CLI/test process proves Foundation behavior only. Packaged-App FDA/TCC and
entitlements remain residual unless repeated through the Task 5 signed App
harness. No TCC permission is granted/reset/automated.

## 7. License and Provenance

- PureMac, ClearDisk and devklean are MIT behavior/test references; no code or
  dependency is reused.
- Pearcleaner is source-available under Apache-2.0 + Commons Clause; no code is
  copied.
- Apple Foundation is a platform API, not a new package dependency.
- No third-party package or shipped notice is added.

## 8. Expected Improvement

Task 7 combines the strongest observed behavior:

- Foundation's native collision-aware Trash;
- PureMac's revalidation/protection lessons;
- ClearDisk's postcondition and no-fallback rule;
- devklean's structural dry-run and partial-failure semantics;
- Pearcleaner's destination/undo caveats;
- Stornaut's immutable Policy Gate and registry-only executable surface.
