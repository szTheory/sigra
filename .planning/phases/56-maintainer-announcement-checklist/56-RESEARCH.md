# Phase 56 — Technical research

**Question:** What do we need to know to plan **MAINT-01** (first public announcement checklist in `MAINTAINING.md`) well?

## RESEARCH COMPLETE

### Repo facts (verified)

- **`mix.exs`**: `@version "0.2.0"`, `source_ref: "v#{@version}"` — tag-scoped evidence URLs for out-of-tarball paths should use **`https://github.com/sztheory/sigra/blob/v0.2.0/`** (matches phase **55** README policy).
- **`MAINTAINING.md`**: Already covers installer golden (`mix ci.install_golden`), **`install_golden_contract`** job, Nyquist table with tag links, Release automation, Manual release checklist. Insertion anchor per **56-CONTEXT D-01**: new **`## First public launch (announcement checklist)`** after **`## Release automation (default)`** block (ends ~changelog conventional-commits bullet) and before **`## Manual release checklist (emergency or pre-automation)`**.
- **`.github/workflows/ci.yml`**: Job id `install_golden_contract`, human check name **`Install golden + idempotency contract (subprocess harness)`** — must remain copy/pasteable into announcement “Ship” rows (already in MAINTAINING branch-protection section).
- **HexDocs boundary**: `MAINTAINING.md` is an ExDoc extra — relative links to `.planning/` **do not ship** in the Hex package; use tag GitHub URLs for `.planning/*` evidence (locked in **56-CONTEXT D-05–D-08**).

### Maintainer-runbook patterns (synthesis)

- **K8s-style roster**: Durable **roles** in the doc + **per-run roster** in a tracking issue (or single table) — avoids stale `@handles` in committed markdown (**56-CONTEXT D-09–D-10**).
- **Ship vs announce split**: Release mechanics stay in existing sections; announcement checklist covers **attention, evidence honesty, support bandwidth** — reduces duplication (**D-03, D-12–D-14**).
- **Waiver honesty**: Optional comms rows must not imply human GA rows re-ran; point to **`v1.4-GA-UAT.md`** Executed/Waived + **`docs/uat-ci-coverage.md`** (**D-15**).

### Planning risks

- **Wrong insertion point** → breaks reading order (default ship → announcement → break-glass).
- **Bare `](.planning/` links** → 404 on hexdocs.pm (**high** integrity issue).
- **`main` blob URLs for evidence** → non-reproducible proof under stress (**D-07**).

---

## Validation Architecture

This phase is **documentation-only** (no application code). Nyquist-style feedback uses **deterministic doc gates** instead of a separate test framework.

| Dimension | Approach |
|-----------|----------|
| **Quick signal** | `mix compile --warnings-as-errors` after edits (sanity). |
| **Doc truth** | `mix docs --warnings-as-errors` — `MAINTAINING.md` is an extra; catches broken refs ExDoc can resolve. |
| **Policy gates** | `grep` invariants: no bare `](.planning/` in `MAINTAINING.md`; required section heading exists; tag prefix `https://github.com/sztheory/sigra/blob/v0.2.0/` present for each mandated `.planning/` evidence path. |
| **Manual** | Maintainer read-through: Ship rows read as **links** into existing subsections, not duplicate release steps. |

**Sampling:** Run **`mix docs --warnings-as-errors`** after the final `MAINTAINING.md` edit (per plan wave). Before verify-work: full doc command green.

**Wave 0:** Not applicable — existing Mix/ExDoc infrastructure covers the phase.
