---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Residual retired brandbook/ pointers in two reference guides and the panel lens module
area: docs
severity: minor
source: Phase 259 BPOL-06
files:
  - guides/reference/admin-graphic-design-lens.md
  - guides/reference/admin-fractal-scorecard.md
  - scripts/panel/lenses.mjs
---

Three files still cite the retired `brandbook/` source and no roadmap phase owns them:

- `guides/reference/admin-graphic-design-lens.md` cites `brandbook/brand-book.md` and `brandbook/tokens.css` in several places.
- `guides/reference/admin-fractal-scorecard.md` names `brandbook/tokens.css` in its D1 row.
- `scripts/panel/lenses.mjs` cites `brandbook/brand-book.md` in three lens strings.

They were not edited by Phase 259. They are outside the BPOL-06 approval, which covers `CLAUDE.md`, `AGENTS.md` and the two admin guides (`admin-ui-principles.md` and `admin-design-contract.md`) only. `scripts/panel/lenses.mjs` is also under the phase's zero-bytes rule for `scripts/` and `.github/`.

They stay deferred. Ask the owner to assign them to a phase of the brand adoption milestone, or to extend the approval, so that the lens guide, the scorecard and the panel lenses stop citing the retired book.

This todo carries no `resolves_phase` key on purpose: no roadmap phase owns these pointers, which is the reason it exists.
