# Phase D Task 39B2c-L3c3c-i-b2a Reproducibility Contract Review

> Status: Complete; three-layer signed-projection reproducibility contract frozen
>
> Date: 2026-08-19
>
> Baseline: `0eb73a7f2f632100e2b9ff4f7fd122c3a8a0e07d`
>
> Scope: documentation and repository-external read-only reproducibility
> evidence only; no privileged run, product/source/test/script change, install,
> model, serial regression or full verifier

## 1. Outcome

L3c3c-i-b2 is split into two explicit gates:

- **i-b2a — signed-projection reproducibility contract: complete.** A fresh
  `-O2` / `FIXED_TARGET_UID=501` rebuild independently reproduces the reviewed
  executable's normalized unsigned projections and signed semantic projection.
- **i-b2b — one privileged B4 root-to-UID run: not executed.** The only allowed
  execution artifact remains the exact reviewed full-file SHA-256
  `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d`.

Independent preflight correctly returned **NO-GO** under the former literal
“fresh rebuild must reproduce the whole signed-file SHA” wording. The measured
difference is codesign padding after the declared SuperBlob, not source, object,
CodeDirectory, parsed signature blob or behavior. This amendment
fixes the gate definition; it is not evidence of a code difference and does not
weaken the exact identity required for the actual run.

ADR 0018 remains Proposed. L3c3c-i remains incomplete, L3c3c-ii remains blocked,
Task 39 remains incomplete, production Deep Dive remains unavailable and the
final authoritative full verifier remains unconsumed.

## 2. Cause of the Literal Whole-File Mismatch

The reviewed and freshly signed files have the same fixed signing identifier,
strict-valid signatures and CodeDirectory. `LC_CODE_SIGNATURE` declares
`dataoff=56928` and `datasize=18384`. Its SuperBlob has magic `0xfade0cc0`,
declared length `376` and declared end offset `57304`. The two files are byte-
identical through that declared end, with prefix SHA-256
`9afc1e08796096a98795afc8a85ee334283cf8ebbf657995f79264ffbd484aac`.

Exactly 193 bytes differ, beginning at zero-based offset `57304`; every
difference is after the declared SuperBlob end. The reviewed file carries 193
nonzero padding bytes there, while fresh `codesign` writes zeros. Those bytes lie
inside file-backed `__LINKEDIT` and the allocated `LC_CODE_SIGNATURE` range, but
outside the CodeDirectory and every blob reachable within the SuperBlob's
declared length. Requiring an independent signer to reproduce those padding
bytes would require circularly copying the reviewed artifact rather than
reproducing the signed program. That is forbidden.

## 3. Amended Three-Layer Gate

All three layers are mandatory and fail closed. A projection hash never replaces
the exact full-file execution hash.

### Layer 1 — Exact execution-artifact identity

The sole i-b2b input is the already reviewed formal B4 executable with full-file
SHA-256
`d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d`,
derived from source SHA-256
`e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25`.
The privileged driver must verify and record the full SHA immediately before and
after execution, and the result JSONL, stderr and return-code receipt must bind
that exact value. A rebuilt file, even one that passes Layers 2 and 3, may not be
substituted for the run artifact.

### Layer 2 — Independently reproducible normalized unsigned projections

Starting only from the exact reviewed source, rebuild with `-O2` and
`FIXED_TARGET_UID=501`. The fresh object must hash to
`bd8e2b055d008569df27ef804a4d2476f4bfa07379cc7a5c7743f61999d17e16`.
Use the final normalizer whose source SHA-256 is
`d83a517faeb6fe1f3c5d73fa8054b2464499edb92720c646356559afd7517056`
and binary SHA-256 is
`65cf14251be13fb54682b541458c7f185c0c2ffd170573b56bcc50b2f86a03ce`.

Two complete-Mach-O comparisons must then agree without importing reviewed
signature or padding bytes; the second comparison restores only the explicitly
reviewed `LC_UUID` value:

1. after ad-hoc signing, stripping the signature and zeroing **only** `LC_UUID`,
   rebuilt and reviewed projections both hash to
   `acc2fdcc8ae72a2a8af2bb5f7dfb52fbdc52e8066ef6bb69b9eb1fa0d70183b7`;
2. after restoring the reviewed UUID, signing with the fixed identifier and
   stripping the signature, rebuilt and reviewed projections both hash to
   `5d88c6ce43839ae0899e39858eb692afbb883e83b22825e706d0f86311f9cf25`.

Only `LC_UUID` and the signature region may be normalized as stated. Any other
difference fails the gate.

### Layer 3 — Independently reproducible signed semantic projection

Fresh and reviewed signatures must both pass strict `codesign` validation, use
the fixed identifier and have CodeDirectory full SHA-256
`38cc1b5258cba2c71768b3aa7348758110c97cf8b02926cd0692710272b48169`
and CDHash `38cc1b5258cba2c71768b3aa7348758110c97cf8`. The complete files must
match through the parsed SuperBlob end with prefix SHA-256
`9afc1e08796096a98795afc8a85ee334283cf8ebbf657995f79264ffbd484aac`.

The only permitted full-file drift is the observed set of exactly 193 positions
within inclusive offsets `57304...57497`, all after the declared SuperBlob end.
Offset `57491` is the sole equal position in that 194-byte span (zero on both
sides); at every other position the reviewed byte is nonzero and its fresh
`codesign` counterpart is zero. Any changed
parsed blob, CodeDirectory byte, byte at another offset, count/value relation or
additional difference fails closed. Copying the reviewed padding into the fresh artifact is
explicitly prohibited.

## 4. Evidence Checklist

| Evidence | Required value | Result |
| --- | --- | --- |
| reviewed source SHA-256 | `e683480689d72118d494270b72ded3a8baa448ba5026d5cf63780990ca64bb25` | matched |
| exact execution full SHA-256 | `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d` | frozen; run not executed |
| final normalizer source / binary | `d83a517faeb6fe1f3c5d73fa8054b2464499edb92720c646356559afd7517056` / `65cf14251be13fb54682b541458c7f185c0c2ffd170573b56bcc50b2f86a03ce` | matched |
| fresh object SHA-256 | `bd8e2b055d008569df27ef804a4d2476f4bfa07379cc7a5c7743f61999d17e16` | matched |
| zero-UUID unsigned projection | `acc2fdcc8ae72a2a8af2bb5f7dfb52fbdc52e8066ef6bb69b9eb1fa0d70183b7` | rebuilt = reviewed |
| reviewed-UUID unsigned projection | `5d88c6ce43839ae0899e39858eb692afbb883e83b22825e706d0f86311f9cf25` | rebuilt = reviewed |
| CodeDirectory full SHA / CDHash | `38cc1b5258cba2c71768b3aa7348758110c97cf8b02926cd0692710272b48169` / `38cc1b5258cba2c71768b3aa7348758110c97cf8` | fresh = reviewed |
| signing identity / validity | fixed identifier; strict `codesign` valid | matched |
| parsed signed prefix | end `57304`; SHA-256 `9afc1e08796096a98795afc8a85ee334283cf8ebbf657995f79264ffbd484aac` | byte-identical |
| residual full-file delta | exactly 193 bytes, all post-SuperBlob padding | bounded and explained |
| circular padding copy | forbidden | not used |
| privileged result JSONL / err / rc | must be absent before i-b2b | absent |

The source/object/normalizer and both projection comparisons are complete. The
old literal whole-file rebuild check is superseded only by this stricter layered
contract; Layer 1 continues to require the exact reviewed whole file for the
actual run.

## 5. Safety and Next Gate

This checkpoint changed documentation only and performed no privileged, product,
install, model, serial or full action. It does not accept ADR 0018 or authorize
product handoff implementation.

The next gate is **i-b2b**: exactly one explicitly authorized disposable B4
root-to-UID invocation of the Layer-1 artifact. Before launch, after process
exit and in the privacy-safe result, the driver must bind full SHA-256 `d157…`;
it must then prove the previously specified scenario matrix, exact UID/groups,
irreversible drop, strict EOF, bounded cleanup and zero exact PID/PGID residue.
There is no retry to repair an implementation and no substitution by a rebuilt
projection. Only a green i-b2b review may support accepting ADR 0018 and
unblocking L3c3c-ii.
