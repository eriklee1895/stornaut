# Stornaut Logo Concept Prompt Set

Generated with the built-in `imagegen` tool on 2026-08-07. These are raster explorations of possible brand directions; the selected direction must be redrawn as a controlled vector and tested at macOS icon sizes.

## Shared constraints

- Use case: `logo-brand`
- macOS rounded-square app icon concept
- Calm scientific explorer; trustworthy and intelligent
- Deep navy/graphite with restrained indigo and cyan, optional tiny warm accent
- Centered, strong silhouette, generous padding, recognizable at 16px
- Vector-friendly shape language with limited components
- No text, watermark, trash can, broom, excessive sparkle, or photorealism

## A — Storage Orbit

Three compact layered storage slabs crossed by one elegant exploration orbit and locator point. Abstract, direct, and closest to the existing Storage Orbit brand motif.

## B — Submersible

A compact deep-sea exploration probe with one luminous scanning window, descending through abstract storage strata. Concrete expression of Deep Dive.

## C — Explorer Robot

A friendly autonomous investigator with one observant lens, a body made from layered storage plates, and a small probe arm. Expresses the constrained Agent role without depicting deletion.

## D — Data Nautilus

A geometric nautilus shell built from concentric data sectors, with one newly discovered chamber highlighted. Expresses deep structure, memory, and exploration.

## E — Astrolabe

A precision scientific instrument with nested rings, a pointer, and a locator dot aimed at an unknown segment. Expresses evidence, measurement, and navigation.

## F — Investigation Lantern

A compact inspection lantern illuminating one block within several hidden storage layers. Expresses turning unknown space into understood space.

## Second round: hybrid exploration

The second round combines the selected B/D/F themes: deep-sea probe, nautilus structure, and illumination as evidence. Every concept further reduces detail and strengthens the 16px silhouette.

### G — Abyssal Beacon

A compact scientific probe with one luminous lens and a tiny amber beacon, casting a narrow cyan beam through three storage layers and revealing a hidden layer.

### H — Nautilus Probe

A geometric nautilus-shaped autonomous probe with one observation lens and a short beam illuminating a detached storage chamber. Organic structure and Agent investigation become one object.

### I — Beacon Spiral

An abstract layered spiral with a warm evidence light at its center and a cyan path illuminating one outer chamber. No literal vehicle or character.

### J — Surveyor Pod

A restrained object mascot combining a lantern and exploration capsule, hovering above storage strata and highlighting one hidden block.

### K — Deep Core

Three broken storage rings around an unknown center, with a tiny capsule probe entering through one opening and lighting a path into the core.

## Selected direction: H — Nautilus Probe

`H — Nautilus Probe` is the approved brand direction. It combines three ideas without turning the product into a generic cleaner:

- the nautilus spiral represents storage structure, layers, and deep exploration;
- the observation lens and probe body represent a bounded, evidence-driven Agent;
- the short beam and detached chamber represent turning unknown disk usage into an explainable finding.

The logo must not imply that Stornaut deletes automatically. Discovery and understanding come first; cleanup remains an explicit user decision.

### Approved palette: Deep Ocean Evidence

| Token | Hex | Intended use |
| --- | --- | --- |
| Abyss Background | `#07152E` | App icon tile and dark presentation surfaces |
| Deep Indigo | `#3F469A` | Structural shadows and light-mode mark |
| Observatory Indigo | `#6573E6` | Primary brand body and selected states |
| Probe Cyan | `#32D6F4` | Active investigation and newly discovered evidence only |
| Evidence Amber | `#FFB547` | Tiny evidence locator or beacon accent |
| Signal White | `#EAFBFF` | Optical highlights and dark-mode foreground |

Semantic disposition/risk colors are not part of the logo palette. In product UI, cyan must not mean `Ready to Reclaim`, and amber evidence accents must remain visually distinct from warning states.

## Final family studies

These four raster studies define one coherent family; they are not production assets and must not be shipped directly.

### Premium macOS app icon

File: `logo-final-premium-app-icon.png`

A dimensional, native-macOS presentation of the Nautilus Probe on a stable Abyss Background tile. Use this as the rendering and material reference for the 512px and 1024px application icon.

### Light-interface mark

File: `logo-final-light-mark.png`

A flatter mark for light surfaces, using Deep Indigo and Observatory Indigo as the structural colors. Cyan and amber remain small, purposeful signals rather than decoration.

### Dark-interface mark

File: `logo-final-dark-mark.png`

A flatter luminous mark for dark surfaces, using Observatory Indigo, Probe Cyan, and Signal White. Preserve enough contrast without relying on glow.

### Monochrome micro mark

File: `logo-final-mono-micro.png`

The silhouette reference and preferred starting point for the vector master. It must remain recognizable at 16px and work in one color for template images, status surfaces, print, and accessibility contexts.

## Production handoff requirements

- Redraw a single controlled vector master; do not trace raster noise or lighting artifacts.
- Derive app icon, light, dark, and monochrome variants from the same geometry.
- Preserve the shell/probe silhouette, one lens, one short investigation beam, and at most one tiny evidence dot.
- Remove internal details that disappear or create noise at small sizes.
- Test at 16, 20, 24, 32, 64, 128, 256, 512, and 1024px on both light and dark surfaces.
- Provide SVG/PDF vector sources plus an Xcode AppIcon asset catalog.
- Check grayscale, high contrast, reduced transparency, and common color-vision deficiencies.
- Do not add lettering, an `S`, a trash can, a broom, generic sparkles, or permanent warning/risk colors.
