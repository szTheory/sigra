# Phase 36: Retroactive Nyquist validation — Context

**Gathered:** 2026-04-17  
**Status:** Ready for execution  
**Source:** Roadmap v1.3 + `.planning/REQUIREMENTS.md` (VAL-01–VAL-03)

## Phase boundary

Close **999.1** documentation debt: every historical phase directory either has an acceptable `*-VALIDATION.md`, an explicit **waiver** row tied to superseding verification, or a **new** validation file where one was missing. No library feature work.

## Implementation decisions

- **Inventory first (VAL-01):** A single machine-regenerable `36-INVENTORY.md` is the source of truth for “what was wrong before Phase 36.”
- **Missing files (VAL-02a):** Author minimal but real `*-VALIDATION.md` for dirs that had **no** validation file (not empty waivers-only stubs without frontmatter).
- **Draft backlog (VAL-02b):** Phases that still have `nyquist_compliant: false` or `status: draft` after inventory may be **waived in bulk** via `36-WAIVERS.md` with owner, date, and pointer to **v1.2 milestone audit** and/or the phase’s own `*-VERIFICATION.md` / shipped code — instead of rewriting 15+ full Nyquist tables in one pass.
- **Traceability (VAL-03):** Update `.planning/REQUIREMENTS.md` under the VAL section with links to `36-INVENTORY.md` and `36-WAIVERS.md` when closing.

## Canonical references

- `.planning/ROADMAP.md` — v1.3 phase table (Phase 36)
- `.planning/REQUIREMENTS.md` — VAL-01–VAL-03
- `.planning/milestones/v1.2-MILESTONE-AUDIT.md` — superseding verification for admin-era phases
- `.planning/phases/31-automation-first-verification/31-VALIDATION.md` — example of a strong Elixir-era validation contract

## Deferred

- Rewriting every waived phase’s `*-VALIDATION.md` into full Nyquist tables — optional hardening for a later maintenance slice if policy changes.
