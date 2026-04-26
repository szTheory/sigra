# Phase 84: routing-honesty-reconciliation - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>

## Phase Boundary

Phase **84** is a small planning-surface stewardship phase. Its job is to remove stale executable pointers to superseded **`999.1`**, preserve **`999.1`** as archaeology-only, and make future validation or assurance work use newly numbered phases.

No Sigra runtime, library, generator, or host-app code is in scope.

</domain>

<decisions>

## Implementation Decisions

### D-84-01 — `999.1` stays closed

- Treat **`999.1`** as a historical tombstone only.
- Do **not** create **`999.1-*-PLAN.md`** or **`999.1-*-SUMMARY.md`** files.
- Do **not** re-open Nyquist work under the **999.x** namespace.

### D-84-02 — Active routing must point at real executable work

- **`STATE.md`**, **`ROADMAP.md`**, and other maintainer-facing planning summaries must not present **`999.1`** as current, next, or planned work.
- If a follow-up is needed, it must point at **Phase 84** or a later newly numbered phase.

### D-84-03 — Canonical evidence remains where it already shipped

- The canonical supersession pair for **`999.1`** remains:
  - **`.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md`**
  - **`.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md`**
- The canonical executed evidence remains under **Phase 36**.
- Phase 84 may reference those files but must not duplicate their substantive bodies.

### D-84-04 — Future validation work needs a new numbered phase

- Any fresh Nyquist, validation, or assurance pass after **v1.19** must be proposed as a new bounded numbered phase with explicit success criteria and verification gates.
- Avoid vague “re-run 999.1” language in all planning surfaces.

</decisions>

<canonical_refs>

## Canonical References

- `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-CONTEXT.md` — tombstone policy and supersession rationale
- `.planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md` — short superseded pointer
- `.planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md` — canonical executed Nyquist inventory
- `.planning/phases/36-retroactive-nyquist-validation/36-WAIVERS.md` — canonical executed waivers
- `.planning/STATE.md` — session handoff surface that currently misroutes to `999.1`
- `.planning/ROADMAP.md` — active roadmap surface
- `.planning/PROJECT.md` — planning precedence and next-milestone framing
- `.planning/MILESTONES.md` — long-form milestone carry-forward narrative

</canonical_refs>

<specifics>

## Specific Ideas

- Prefer minimal, high-signal edits over broad restructuring.
- Keep terminology consistent: **archaeology-only**, **tombstone**, **newly numbered phase**.
- If automation is proposed later, it should enforce the same policy rather than replace it with another duplicated source of truth.

</specifics>

<deferred>

## Deferred Ideas

- CI or contract test that rejects `STATE.md` pointing at a superseded-only phase.
- Auto-generated “next phase” handoff derived from `ROADMAP.md`.
- Promotion of `999.2` into a real numbered phase if dependency work becomes active again.

</deferred>

---

*Phase: 84-routing-honesty-reconciliation*
*Context gathered: 2026-04-25*
