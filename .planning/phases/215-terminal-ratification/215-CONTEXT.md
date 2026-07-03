# Phase 215: Terminal Ratification - Context

**Gathered:** 2026-07-03
**Status:** Ready for planning
**Source:** Orchestrator-synthesized (no discuss-phase; well-specified ratification phase grounded in the Phase 211 precedent + two locked operator decisions)

<domain>
## Phase Boundary

Phase 215 is the **terminal gate of the v1.43 STABILIZE milestone** (Phases 213–215). Phases 213
(latest-Phoenix COMPAT) and 214 (DEBT & robustness) are complete. This phase does **no feature
work** — it proves the foundation is demonstrably green end-to-end and carries the milestone to a
clean, closeable state.

What this phase delivers:
- HEALTH-01: the full **library** test suite runs green against live Postgres, with the exact
  trustworthy release-signal command + result recorded.
- HEALTH-02: the **example app** test suite runs green against live Postgres.
- HEALTH-04: **every required CI check** passes green end-to-end on the milestone branch (all
  lanes: library tests, dep-off, example Playwright smoke, design gallery, install/golden, fast
  checks, ci-gate).
- RATIFY-01: the milestone closes cleanly — full suite + CI green, every deferred-items-ledger
  entry **pulled into this milestone** reconciled (marked resolved), and no new blocking debt.

Critical state fact: local `main` is ~42 commits ahead of origin/main — the entire v1.43 body of
work (213 + 214) lives only locally and **CI has never run on it**. Establishing HEALTH-04
therefore requires actually surfacing these commits to GitHub Actions (see D-01).

Direct precedent: **Phase 211** was v1.42's "Terminal Ratification" — three verification-only
plans (ledger/idempotency lock, generated-host parity, clean `mix test` classification). Phase
215 shares that DNA, minus the admin design-system ledger (v1.43 is a pure stabilization lane, not
a DS elevation).
</domain>

<decisions>
## Implementation Decisions

### CI verification & milestone-close surface
- **D-01**: HEALTH-04 is satisfied by cutting a **final v1.43 ship/integration PR from `main`**,
  pushing it, and letting **GitHub Actions run every required lane** — HEALTH-04 gates on that
  PR's checks being green. This mirrors the v1.42 ship pattern (PR #63). The **actual merge to
  origin/main and the milestone archival are deferred** to `/gsd-ship` + `/gsd-complete-milestone`
  after this phase — Phase 215 proves close-readiness and gets the PR green, it does not itself
  merge or archive.

### What "green" means (the milestone's whole point)
- **D-02**: "Green means green" — the library and example suites must pass with **zero failures**.
  The Phase 211-era *accepted known/env failures* (the 3 `Sigra.UpgradeIntegrationTest` env-DB
  failures and the `Chimeway.Repo` missing-database startup noise) were **resolved / correctly
  gated by HEALTH-03 in Phase 214** (Chimeway.Repo test config stanza; `:upgrade` tests
  conditionally excluded when the phx_new 1.8.8 archive is absent). Any failure outside a
  legitimately gated/skipped test is a **real regression to escalate**, not a known-failure to
  accept. Do NOT reintroduce a "green modulo known set" posture.

### Recording the trustworthy release signal
- **D-03**: HEALTH-01 must **record the exact command + result** used as the trustworthy release
  signal (the canonical full-suite `mix test` invocation against live Postgres, with the DB
  discovery convention from CLAUDE.md) in a durable location (the plan SUMMARY, and reflected in
  STATE/close artifacts). "It passed" is not enough — the reproducible command and the observed
  pass/fail counts are the artifact.

### Ledger reconciliation scope (RATIFY-01)
- **D-04**: RATIFY-01 reconciliation covers **only the deferred-items-ledger entries pulled into
  v1.43** — the COMPAT-*, DEBT-*, and HEALTH-03 items resolved in Phases 213/214. Every such
  entry must read *resolved*. The pending v2 / UI / SEED todos
  (`runtime-auth-prefix-override`, `mix-sigra-migrate-schema-helper`, `white-label-auth-email-theming`,
  `uat-demo-dx-polish-nits`, `vaultr-authed-rebrand-residuals`, `playwright-parallelization-per-shard-db`)
  are **explicitly out of scope** and stay deferred — they are NOT unreconciled milestone debt.
- **D-05**: The one 2026-07-02 pending todo — `app-css-corruption-guard-blind-spot` (harden the
  DEBT-05 app.css guard against a mid-block orphan false-negative) — is an **accepted low-severity
  DEBT-05 follow-up**, not new *blocking* debt: the live app.css is clean and browser-verified;
  this is a regression-guard hardening gap. RATIFY-01's "no new blocking debt" holds with this
  item classified and left tracked. The phase must **confirm** this classification, not fix it.

### Posture
- **D-06**: This phase is **verification/ratification only** — no feature changes, no product
  behavior edits, no UI redesign. Code fixes are permitted **only** to repair genuine regressions
  surfaced by the gates (e.g. real installer-template drift caught by the golden/acceptance lane),
  never to mask an environmental issue (e.g. a wrong local phx_new archive → install the pin, do
  not edit the fixture).

### Claude's Discretion
- Whether HEALTH-01 (library suite) and HEALTH-02 (example suite) are one plan or two — lean
  toward the roadmap's natural split given `granularity: fine`.
- Exact PR mechanics for D-01 (branch name, whether to route through `/gsd-ship`, whether to open
  the PR inside this phase or hand a ready-to-push state to `/gsd-ship`) — planner's discretion,
  but the phase must reach a state where the required GitHub CI lanes are demonstrably green.
- Whether to also cross-check the required lanes locally (e.g. via the nektos/act runner) as a
  pre-push confidence pass — optional, non-authoritative; the PR's GitHub Actions run is the
  HEALTH-04 signal of record.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope & requirements
- `.planning/ROADMAP.md` — v1.43 STABILIZE milestone + Phase 215 goal/success criteria
- `.planning/REQUIREMENTS.md` — HEALTH-01/02/04, RATIFY-01 definitions; v2/UI/SEED out-of-scope list; traceability table
- `.planning/STATE.md` — current phase/plan status

### Direct precedent (structural template)
- `.planning/phases/211-terminal-ratification/211-01-PLAN.md` (git HEAD; deleted from worktree) — ledger/idempotency lock pattern
- `.planning/phases/211-terminal-ratification/211-02-PLAN.md` (git HEAD) — generated-host parity (install-golden + admin-acceptance-smoke)
- `.planning/phases/211-terminal-ratification/211-03-PLAN.md` (git HEAD) — clean `mix test` classification / release-signal discipline
  (retrieve with `git show HEAD:.planning/phases/211-terminal-ratification/211-0N-PLAN.md`)

### Prior-phase closure evidence (v1.43)
- `.planning/phases/214-debt-robustness-clear/214-VERIFICATION.md` — 214 verified 6/6; HEALTH-03 resolution (Chimeway config, :upgrade gating)
- `.planning/phases/214-debt-robustness-clear/214-04-SUMMARY.md` — Chimeway.Repo config + conditional :upgrade skip
- `.planning/phases/213-latest-phoenix-compatibility/` — COMPAT-01/02/03 closure (phx_new 1.8.8 pin flip, golden rebless)

### Test / CI / DB operational contract
- `CLAUDE.md` — local Postgres prereqs (`scripts/db/up.sh` → `tmp/db.env`, localhost:5432 fallback), phx_new 1.8.8 archive pin for install golden, example Playwright boot notes
- `.github/workflows/ci.yml` — the required CI lanes to gate HEALTH-04 on
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host runtime parity smoke
- `scripts/db/up.sh` / `scripts/db/down.sh` — ephemeral test Postgres

### Ledger / debt reconciliation
- `.planning/todos/pending/` — verify only the out-of-scope v2/UI/SEED items + the accepted app.css-guard follow-up remain; nothing v1.43-scoped is stranded here
- `.planning/todos/resolved/` — confirms DEBT/COMPAT items resolved in 213/214
- `.planning/todos/pending/2026-07-02-app-css-corruption-guard-blind-spot.md` — the accepted low-severity DEBT-05 follow-up (D-05)
</canonical_refs>

<specifics>
## Specific Ideas

- Follow the Phase 211 three-legged verification shape, retargeted to v1.43's actual gates:
  (1) library suite green + release signal recorded (HEALTH-01), (2) example suite green
  (HEALTH-02), (3) CI green via the v1.43 PR (HEALTH-04), (4) milestone reconciliation/audit
  (RATIFY-01). Planner may fold (1)+(2) or split per `granularity: fine`.
- The full-suite command must use the CLAUDE.md DB discovery (`source tmp/db.env` or the
  localhost:5432 fallback); `mix test` sets `MIX_ENV=test` itself.
- The install-golden lane requires the **phx_new 1.8.8** archive locally to match the CI pin
  (Phase 213 flipped 1.8.7 → 1.8.8); a mismatched local archive produces spurious byte-diffs.
- HEALTH-04's lane inventory should be taken from `.github/workflows/ci.yml` "required" checks,
  not guessed.
</specifics>

<deferred>
## Deferred Ideas

- **Actual merge to origin/main + milestone archival** — handled by `/gsd-ship` +
  `/gsd-complete-milestone` after Phase 215 proves close-readiness (D-01).
- **v2 features** FEAT-01/02/03, **UI** UI-01/02/03, **SEED-005** per-shard-DB Playwright — remain
  in `.planning/todos/pending/`, explicitly out of v1.43 scope (D-04).
- **app.css corruption-guard hardening** (DEBT-05 follow-up) — accepted low-severity, tracked, not
  fixed in this phase (D-05).
</deferred>

---

*Phase: 215-terminal-ratification*
*Context synthesized: 2026-07-03 by /gsd-plan-phase orchestrator (2 locked operator decisions: PR+GitHub-CI surface, ground-truth research)*
