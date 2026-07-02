---
created: 2026-06-17T00:00:00.000Z
resolved: 2026-06-26T00:00:00.000Z
status: resolved
closed_by: Phase 203 plan 05 (D-08/D-09) — branding-live cell ratcheted to bare 2 with honest Tier-2 proxy evidence
title: explicitly score the Branding customizer (PAGE-04) in the L3 quality ledger
area: admin-ui
files:
  - guides/reference/admin-quality-ledger.md
  - lib/sigra/admin/live/branding_live.ex
source: 189-VERIFICATION.md (PAGE-04 human item), ROADMAP v1.39 SC #4
resolves_phase: 203
---

## Resolution (2026-06-26, Phase 203 plan 05)

Closed by D-08/D-09. The todo's "no separate L3 row exists" premise is stale — the
`branding-live` row already existed at ledger line 92 (added in Phase 191/192 as part
of the terminal ratification). The row was at Tier 1; this plan ratchets it to Tier 2.

**How resolved:**
- The `branding-live` cell in `guides/reference/admin-quality-ledger.md` was ratcheted
  from bare `1` to bare `2` (D-08 forward ratchet).
- Evidence expanded with honestly-applicable Tier-2 proxies:
  - overlay-axe + 7 APG focus-trap/restore gates: EARNED by the Plan 03 (Phase 203)
    `#restore-defaults-overlay` case in `admin-modal-interaction.spec.ts` (D-06)
  - glossary-clean: glossary_test.exs scopes branding_live
  - motion-tokens, density/rhythm, target-size: documented-as-manual review
  - content-equivalence: N/A — branding workbench is tab nav + panels, not a results table
- The monotonic guard (`quality-ledger-monotonic.sh --base origin/main`) passes: 36 cells
  checked, all forward-only (branding-live counts as a `2`, protected against regression).
- No new ledger row was added — the existing row at line 92 is the explicit scoring.

**Commit:** (see Phase 203 plan 05 task 1 commit)

---

## Why deferred (original, archived below)

## Why deferred

Phase 189 verification (`.planning/phases/189-page-compositions-l3/189-VERIFICATION.md`)
passed 10/10 observable truths. The single human item was a scope-vs-wording call:
ROADMAP v1.39 success-criterion #4 requires the non-archetypal pages "explicitly
scored." The **Audit explorer** got two dedicated L3 ledger rows, but the
**Branding customizer** (`branding_live`) has no separate L3 ledger row — its
bespoke IA criteria are documented in `189-UI-SPEC.md` L241-247 and it received the
ConfirmDialog hook (Plan 01), but the phase's ratified UI-SPEC Ratification Contract
deliberately scoped to 6 rows (branding excluded), and the 8 admin checkpoints also
exclude a branding page.

**Maintainer decision (2026-06-17): accept Phase 189 as complete** — do not override
the approved 6-row contract at phase close. Explicit Branding scoring is deferred to
Phase 191 (microcopy & IA sweep) / Phase 192 (terminal ratification & baseline lock),
which is the milestone-level backstop for SC #4.

## How to apply

In Phase 191 or 192, add an explicit Branding customizer (`branding_live`) row to
`guides/reference/admin-quality-ledger.md`, scored against the L3 page scorecard
(GOV.UK IA, least-surprise, overlay/modal correctness, page-level a11y/responsive),
with executable evidence links — and confirm ROADMAP v1.39 SC #4 ("non-archetypal
pages explicitly scored") is then literally satisfied. Keep the monotonic ledger
guard green.
