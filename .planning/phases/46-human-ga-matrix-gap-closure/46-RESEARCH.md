# Phase 46 — Research: Human GA matrix gap closure

**Gathered:** 2026-04-21  
**Status:** Ready for planning  
**Question answered:** What do we need to know to plan GA-02..GA-05 closure well?

## Executive summary

Phase **46** closes **GA-02..GA-05** per [`.planning/milestones/v1.4-MILESTONE-AUDIT.md`](../../milestones/v1.4-MILESTONE-AUDIT.md) (archived at v1.4 ship): each row in [`.planning/v1.4-GA-UAT.md`](../../v1.4-GA-UAT.md) must reach **Executed**, **Waived**, or **Blocked** with a durable **Evidence_link** under [`.planning/uat-evidence/v1.4/`](../../uat-evidence/v1.4/) (or documented equivalent), and archived [v1.4 requirements](../../milestones/v1.4-REQUIREMENTS.md) / [`.planning/ROADMAP.md`](../../ROADMAP.md) must match that truth.

**Already in place (Phase 42):**

- Canonical matrix file with correct columns and **Pending** rows for GA-02..GA-05.
- Per-GA folders: `GA-02` … `GA-04`, `GA-05`, `GA-01-pointer` with `README.md`, `steps.md` / `waiver.md` templates ([INDEX.md](../../uat-evidence/v1.4/INDEX.md)).

**Gap:** Matrix rows are still **Pending**; `steps.md` record tables are empty; **Hex package** / **Git SHA** placeholders in the matrix header are unfilled; REQUIREMENTS checkboxes for GA-02..GA-05 remain unchecked.

## Canonical references (planner must honor)

| Artifact | Role |
|----------|------|
| `.planning/v1.4-GA-UAT.md` | Single canonical GA table (**D-38-08** / **D-42-01**) |
| `docs/uat-ci-coverage.md` | Machine baseline / SEED ↔ CI map — not duplicated in GA-05 notes |
| `.planning/uat-evidence/v1.4/*` | Human runbooks, steps, waivers (**D-38-01**) |
| `.planning/milestones/v1.4-REQUIREMENTS.md` (archived) | GA-02..GA-05 definitions and phase mapping at v1.4 close |
| `.planning/ROADMAP.md` | Phase 46 goal and success criteria |
| `.planning/phases/42-human-ga-matrix-evidence/*` | Prior phase patterns for matrix + evidence layout |
| `.planning/milestones/v1.4-MILESTONE-AUDIT.md` (archived) | Declared gaps for GA-02..GA-05 (historical snapshot) |

## GA-by-GA closure mechanics

### GA-02 (Email visual QA)

- **Executed path:** Complete `GA-02/steps.md` checklist (Gmail, Outlook, Apple Mail or documented substitutes per **D-42-02**); fill record table with **Date**, **Owner**, **Outcome**, build ref.
- **Waived path:** Fill `GA-02/waiver.md` table with reason, compensating controls, residual risk, expiry_or_next_trigger, owner, date — must not claim triple-client verification from screenshots alone.
- **CI baseline:** `EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`, `example_unit_smoke` (names in matrix **CI_substitute** column).

### GA-03 (Live Google OAuth)

- **Executed path:** `GA-03/steps.md` — live Google on dedicated test client; **no secrets in repo** (env var names only, **D-38-P04**).
- **Waived path:** `GA-03/waiver.md` with formal rationale and compensating evidence (e.g. mock contract emphasis + explicit deferral owner).

### GA-04 (Clean-machine getting-started)

- **Executed / SUCCESS WITH DEVIATION / BLOCKED:** Protocol in `GA-04/README.md` — reviewer bar (60-day non-core merge rule), witness rules, outcomes set.
- **Async variant:** Only if `GA-04/waiver.md` async section conditions met (**D-42-03**).

### GA-05 (Consolidation)

- Matrix row GA-05 moves to **Executed** when GA-02..GA-04 (and GA-01 pointer consistency) are truthfully reflected and **REQUIREMENTS** / **ROADMAP** no longer imply “scaffold only” while rows say **Pending**.
- **Hex package / Git SHA:** Fill at release tag per **D-38-P01** / **D-42-01**, or use current `HEAD` + published Hex version with explicit note in **Notes** if pre-tag.

## Risks and guardrails

| Risk | Mitigation |
|------|------------|
| **False Executed** | Every status change ties to a concrete path under `uat-evidence` or matrix **Notes** citing waiver doc |
| **Secret leakage** | Grep discipline: no `client_secret`, bearer tokens, magic-link secrets in evidence |
| **ROADMAP drift** | Phase 46 row must not show completion checkmark until matrix + REQUIREMENTS align |

## Validation Architecture

This phase is **evidence- and documentation-first**; automated tests prove **machine baselines** only, not human MUAs.

**Nyquist-aligned strategy:**

1. **Wave 0 / baseline (before editing matrix):** Run targeted CI-aligned tests so “same SHA” narratives are honest:
   - **Example HTML (from `test/example/` app):** `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` (root `mix.exs` excludes `test/example/` from library `mix test`).
   - **OAuth contract (library root):** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_test.exs` (module **`Sigra.OAuthTest`**)
2. **After each GA plan:** Grep-verifiable updates: matrix row **Status** ∈ {Executed, Waived, Blocked}; **Evidence_link** non-empty relative path; **Date** / **Owner** populated for non-Pending states.
3. **Before phase sign-off:** `REQUIREMENTS.md` GA-02..GA-05 lines show `[x]` only when matrix says **Executed** or **Waived** (not **Blocked** without explicit milestone decision).
4. **Sampling:** Manual-only dimensions (MUA, live Google, clean-machine) cannot be automated — capture in `steps.md` / waiver; plans use **acceptance_criteria** that verify **files** and **strings**, not subjective “looks good.”

**Feedback latency:** Doc edits are fast; human runs are unbounded — plans mark `autonomous: false` where human gate is mandatory.

---

## RESEARCH COMPLETE
