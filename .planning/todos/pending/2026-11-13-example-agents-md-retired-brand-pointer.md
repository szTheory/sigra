---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Example app AGENTS.md still says "Rail Accent brand assets" (outside the BPOL-06 approval)
area: docs
severity: minor
source: Phase 259 BPOL-06
files:
  - test/example/AGENTS.md
---

`test/example/AGENTS.md` line 7 tells agents to keep "Rail Accent brand assets" intact when working on Sigra admin UI from that directory. It names no `brandbook/` path, so it is not the identical retired-pointer defect that the owner approval of 2026-11-13 covers (pointers to the new `brand/` book in the root instruction files and the two admin guides). It was therefore not edited by Phase 259.

The wording still reads as if the retired Rail Accent source is the brand reference. An agent working under `test/example/` may follow it rather than the v1.51 brand book in `brand/`.

Ask the owner to either extend the BPOL-06 approval to this file, or fix it in a later phase of the brand adoption milestone, with the same wording intent as the root `AGENTS.md` bullet: point at the brand book in `brand/`, keep the `--sg-*` token names, and say token values move to the book in a later phase.
