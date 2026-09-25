---
created: 2026-09-16T00:00:00.000Z
status: pending
title: The Phase 241 p18 ratchet baseline scans `lib/` only, but published `guides/` extras render on HexDocs too
area: planning
severity: minor
source: phase 237 verification (advisory)
files:
  - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RATCHET-BASELINE.md
  - .planning/ROADMAP.md
---

## Problem

Phase 237's goal sentence promises "HexDocs pages that carry no internal planning bookkeeping."
The residual the phase deliberately did not sweep (~337 hits / 254 sites / 69 files, D-01) is
baselined in `237-RATCHET-BASELINE.md` and handed to Phase 241's `p18` monotonic-decrease
ratchet.

That baseline scans `lib/` only. Phase 237's verification re-observed that **9 published
`guides/` extras still carry `.planning/` references** — and `guides/` extras render on HexDocs
exactly as `lib/` module pages do. So the ratchet, as scoped, cannot ever drive the goal
sentence to true for the whole rendered surface.

Mitigating: most of those 9 are live absolute GitHub blob URLs, so they resolve and are not rot
— unlike the dead relative links Phase 237 removed. The gap is one of scope and measurement,
not of currently-broken links.

## Suggested fix

Decide, before Phase 241 executes, whether the `p18` ratchet's scope should be `lib/` (as
currently specified at `.planning/ROADMAP.md:192`) or `lib/` + `guides/`. If the latter,
re-baseline over both so the ratchet's starting number covers the full rendered surface —
raising a baseline later to accommodate newly-in-scope hits defeats a monotonic-decrease ratchet.
