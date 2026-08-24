# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a1-v Verifier Preflight

> Status: tests-first implementation complete; a1-vR Release closure inserted
>
> Date: 2026-08-24
>
> Baseline: `72d506de45deccb0cc0d6337b04a8f0e7ad751eb`
>
> Scope: complete the a1 transport foundation with one package-only inner-role
> validator, exact source/authority/Mach-O gates and an immutable implementation
> seal. No App/helper/XPC launch, installation, sudo/root operation, protocol
> admission, continuity, public entry, Codex/model/network use or full verifier.

## 1. Reason for the split

The a1-i source/test slice reached 2,588 added non-document lines in its three
frozen paths, leaving no honest room under the 2,600-line hard cap for the
production inner-role validator and three independent verifier surfaces. a1-v
therefore starts from the immutable a1-i commit rather than enlarging that
review surface.

## 2. Target and defect

`scope_type` is `non_diff`; `diff_context` is `null`. The sole business target
is `InvestigationMachineDarwinInnerRoleValidator.validate()` in the existing
`InvestigationMachineDarwinOuterInnerSession.swift` source. Its focused test is
added to the existing serialized outer-inner session suite.

```json
{
  "BUG_MAP": [
    {
      "defect_type": "Security",
      "scenario": "[defect-probing] inner 在读取任何请求前必须拒绝错误或别名的 FD0/1/2/7/8/9、非 root 身份和非 leader PGID",
      "description": "a1-i 已创建正确 spawn file actions，但 production child 入口尚无独立 role/provenance validator，未来入口可能消费继承漂移后的 descriptor",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift",
      "target_func": "InvestigationMachineDarwinInnerRoleValidator.validate",
      "bug_range": "absent at baseline 72d506d",
      "evidence": "physical C fixture proves the kernel spawn shape, but no package Swift API rejects FD0/1/7 open, FD8 non-stream/non-duplex, FD9 non-write-only, missing FD2, PID/PGID/root drift or stderr identity drift before protocol consumption",
      "expect_outcome": "correct outcome: one package-only validator returns a non-Codable observation only for argc 1, exact root driver identity, FD0/1/7 closed, FD2 stable, FD8 stream+duplex and FD9 write-only with no aliases; current wrong outcome: no such gate exists; verification: a parameterized injected mutation matrix initially fails to compile and then rejects every axis before any I/O",
      "severity": "P1"
    }
  ]
}
```

## 3. Exact scope and budget

The original maximum was six non-document paths and 2,400 changed
non-document lines. The first Release artifact gate then proved that wrapping
only the outer-inner session implementation in `#if DEBUG` removed its spawn,
socket and write authority but left the otherwise-unreferenced driver-child
observer in the Release Mach-O. Allowing that dormant observer in Release would
weaken the frozen artifact gate. Before changing the observer, a1-v is therefore
explicitly split with a narrow **a1-vR Release closure**. The aggregate ceiling
is seven non-document paths and remains 2,400 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerSessionTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`;
5. `scripts/verify-investigation-boundaries`; and
6. `scripts/verify-app-release-boundaries`; and
7. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinDriverChildObservation.swift`.

The a1-vR addition compiles the complete observer only under `#if DEBUG`,
matching the session source that is its sole production consumer. Tests retain
white-box access in Debug. Release must contain neither observer/validator
symbols nor their newly introduced spawn/socket/write imports. No Package/Xcode
graph change or new target is necessary.

No new source/test file, Package/Xcode graph, existing App-session/identity/
retirement/protocol source, public driver entry or product source may change.
Any eighth non-document path or more than 2,400 changed lines requires another
split before editing.

## 4. Inner-role contract

- `argc == 1`; current PID and PPID exceed one; complete driver-child identity
  is root, `PID == PGID`, and matches current PID/PPID.
- FD 0, 1 and 7 are absent with exact `EBADF`; FD 2, 8 and 9 are pairwise
  distinct and open; no other FD in `0...9` is open.
- FD 8 is a connected `AF_UNIX` `SOCK_STREAM` and `O_RDWR`; FD 9 is an
  `S_IFIFO` `O_WRONLY` pipe; FD 2 is writable. FD 2/8/9 have `FD_CLOEXEC`
  cleared in the child and their underlying `(device, inode, type)` identities
  are pairwise distinct.
- FD 2 is sampled before and after all fixed-FD/identity checks and remains the
  same node, access mode and TTY/foreground-process-group observation.
- The returned observation is package-only, non-`Codable` and contains no
  reusable descriptor, path, command, signal or admission authority.
- Every unavailable or contradictory read fails before any control/result I/O.

## 5. Verifier closure

- `InvestigationMachineTargetBoundaryTests` pins the exact two new a1 source
  names/imports and allows Darwin authority only in the outer-inner session
  source. It keeps every other DriverSupport source closed.
- `verify-investigation-boundaries` pins the exact inner-role fields/check order,
  fixed path/argv/env/spawn flags, FD 2/8/9 mappings, `>=10` relocation,
  `F_SETNOSIGPIPE`, bounded framing, child identity and one-shot retirement.
- `verify-app-release-boundaries` adds the corresponding source-only exception
  and keeps App/helper/ordinary-product surfaces negative.
- `verify-contract` supplies exact semantic mutations, seven-path/2,400-line scope
  enforcement, same-path substitutions and a replay of a1-i commit `72d506d`,
  parent `9551c3d` and tree `f5b2ddaf731289866b956efbeaa2b817add3ecdd`.
- Debug package/diagnostic driver artifacts are positive controls for the new
  dormant authority; Release/public-entry-reachable artifacts must keep it dead
  stripped until iii-b2b.

## 6. Validation and non-claims

Run focused inner-role/transport tests, adjacent 59-test Darwin selection, the
affected Investigation selection, all three boundary gates, Debug/Release
Machine Driver builds, one staged-only serialized SwiftPM regression and
independent implementation/verifier review. Do not run the authoritative full.

a1-v remains package-only and non-admitting. It does not launch the installed
App/helper/XPC, exercise root identity in the ordinary test process, drive the
supervisor protocol, create terminal evidence, install, authenticate, call a
model/network, accept ADR 0018 or claim readiness. a1 is complete only after
this closure and its immutable seal; a2 then owns App/protocol/lifecycle
composition.
