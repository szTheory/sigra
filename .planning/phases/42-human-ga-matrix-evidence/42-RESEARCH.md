# Phase 42 — Technical research

**Phase:** 42 — Human GA matrix & evidence  
**Question:** What do we need to know to PLAN this phase well?

## Executive summary

Phase 42 is **artifact and process work**: publish `.planning/v1.4-GA-UAT.md` as the single canonical matrix for v1.4 GA posture (GA-02..GA-05 plus a **pointer** row for GA-01), stand up `.planning/uat-evidence/v1.4/` mirroring v1.3 patterns, and **surgically** update `docs/uat-ci-coverage.md` / `CHANGELOG.md` only when the machine–human boundary or public pointers change. Almost no application code ships here; verification is **grep + link integrity + optional mix compile** if any script or example touch occurs.

## Source alignment

| Source | Implication |
|--------|-------------|
| `.planning/REQUIREMENTS.md` SEED-001 | GA-02..05 are **human-residual** with CI substitutes documented in `docs/uat-ci-coverage.md`. |
| `42-CONTEXT.md` D-42-01..05 | Single matrix file; v1.4 evidence tree; extended columns `CI_substitute`, `Surface`; GA-04 clean-machine protocol; edit coverage doc when **merge-blocking CI** changes. |
| `.planning/v1.3-HUMAN-UAT.md` | Copy **table shape** and honesty posture (Executed / machine closure narrative); v1.4 rows map to **GA-xx** IDs not legacy SEED row numbers in public prose. |
| `.planning/uat-evidence/v1.3.0/INDEX.md` | Hub pattern for deep links; optional `v1.4/INDEX.md` only if navigation friction appears. |
| Phase 41 | GA-01 proof lives in tests + CI; matrix **links** only — no re-execution in 42. |

## File inventory (planned deltas)

| Path | Role |
|------|------|
| `.planning/v1.4-GA-UAT.md` | **New** — canonical matrix (authoritative). |
| `.planning/uat-evidence/v1.4/INDEX.md` | **New** (optional but recommended) — hub linking GA-* folders. |
| `.planning/uat-evidence/v1.4/GA-02/` … | **New** — `README.md` / `steps.md` / `waiver.md` scaffolds per D-42-02. |
| `docs/uat-ci-coverage.md` | **Update** — add v1.4 / GA-02..05 traceability rows or header cross-link if policy shifts; drift pass job names vs `ci.yml`. |
| `CHANGELOG.md` | **Update** — one-line pointer to human GA matrix (per D-42-01 public boundary). |
| `guides/introduction/getting-started.md` | **Read-only** unless GA-04 reveals doc defects (out of scope unless executor files a follow-up). |

## Risk and honesty (planning constraints)

- **Checkbox theater:** Plans must **not** mark human rows Executed without dated evidence paths; use **Waived** / **Blocked** with owner + compensation per D-38-02..04.
- **False machine closure:** Do not imply HTML structure tests **replace** MUA rendering for GA-02; matrix must separate **CI_substitute** from human residual.
- **PII / secrets:** Evidence templates reference D-38-P04 redaction; no raw tokens in committed transcripts.

## Tooling / commands (verification spine)

- `mix compile --warnings-as-errors` — baseline if any `.ex` / `.exs` touched (unlikely).
- Grep-based acceptance for new docs (headers, required column names, `GA-0` row markers).
- Optional: `scripts/ci/getting-started-contract.sh` unchanged unless GA-04 doc edits require string updates (then same script must stay green).

## Dependencies on other phases

- **41:** GA-01 closure — plans cite `backup_code_rotation_test.exs`, `example_unit_smoke`, Playwright shell as evidence targets.
- **43–45:** Audit conversion assumes GA-05 is **closed** before claiming v1.4 GA complete — plans should leave matrix in **actionable** state (rows exist; status may stay Pending until humans run).

## Open questions (resolved in CONTEXT)

Cooling window 30–90 days for GA-04: **PLAN.md picks one concrete value** (e.g. 60 days) in runbook text. Folder naming `GA-xx/`: **use GA-xx** for consistency with requirements.

---

## Validation Architecture

**Nyquist dimension 8 — feedback during execution**

This phase is documentation-first. Automated feedback is **structural** (files exist, tables parse, links resolve, CI script unchanged) rather than unit-test expansion.

| Dimension | Strategy |
|-----------|----------|
| **1–3** | Each plan task includes grep-verifiable acceptance strings and read_first paths. |
| **4–5** | Wave 1 completes matrix skeleton before wave 2 fills evidence folders (link targets stable). |
| **6–7** | `mix compile` only if Elixir sources change; otherwise skip with explicit N/A in verify blocks. |
| **8** | After each wave: run quick grep bundle + optional getting-started contract if `getting-started.md` edited. |

**Sampling policy**

- After **every** task: grep criteria from `<acceptance_criteria>`.
- After **wave 2**: confirm every `Evidence_link` in matrix either points to existing `.planning/uat-evidence/v1.4/...` path or `N/A` with rationale in Notes.
- Before handoff to execution: `mix compile --warnings-as-errors` from repo root if any code path touched.

**Manual-only (expected)**

- Actual Gmail/Outlook/Apple Mail runs (GA-02), live Google OAuth (GA-03), witnessed getting-started (GA-04) — **outside** automated CI; matrix records outcomes after humans execute separate runbooks.

---

## RESEARCH COMPLETE

Findings are sufficient for `gsd-planner` to emit 2–3 waves of PLAN.md files with concrete paths, waiver discipline, and threat_model rows focused on **integrity of GA records** (repudiation/tampering of status fields) rather than product auth bugs.
