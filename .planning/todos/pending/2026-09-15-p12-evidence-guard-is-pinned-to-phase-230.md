---
created: 2026-09-15T00:00:00.000Z
status: pending
title: p12 evidence-ledger guard is hardcoded to phase 230 — no standing guard on any other phase
area: tooling
severity: major
source: phase 236 wave-1 boundary check
files:
  - scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:26
---

## Problem

`scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:26` pins its subject to a single
literal path:

```js
const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
```

So `p12` green means "phase 230's ledger is well-formed" and **nothing else**. Every later
phase's `*-EVIDENCE.md` is ungoverned. Phase 236 writes a `BEFORE-FLAKE-RED` slot and plan
236-04 will write an `AFTER-FIX-GREEN` slot into the same file — neither is checked by any
committed guard.

This is the milestone's own thesis turned on the milestone's own tooling: a guard that
passes while verifying nothing about the artifact you believe it covers. It is a *sharper*
instance than the ones v1.48 was scoped around, because `p12` **does** have a non-vacuity
floor (`"the parse broke, this is not a pass"`) — the floor is real, it just guards the
wrong file. A reader who confirms the floor exists still concludes wrongly.

Caught at the phase 236 wave-1 boundary, where running p12/p01/p03/p11 all-green was very
nearly reported as "236's evidence ledger is verified". It is not; the ledger was verified
separately by invoking `parseEvidenceSlots` directly against it.

## Solution

Make the subject phase-relative rather than literal. Options, cheapest first:

1. **Glob all ledgers** — walk `.planning/phases/*/[0-9]*-EVIDENCE.md` and assert the
   grammar on each. Add a non-vacuity floor on the *count* of ledgers discovered (there is
   more than one at HEAD), so an empty walk reds rather than passes.
2. **Frontmatter-driven subject**, matching the `GSD_PROHIB_SUBJECT` / `readSubject()`
   pattern 236-03 uses for `p17` — keeps the path out of the guard body.

Prefer (1): it is the only option that governs ledgers nobody remembered to register.

Check the sibling guards for the same defect before fixing — `p01`, `p03`, `p11` and `p13`
were all written in the same batch and may carry pinned subjects too. Do not assume `p12`
is unique; confirm per file.
