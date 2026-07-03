# Phase 215: Terminal Ratification - Research

**Researched:** 2026-07-03
**Domain:** Milestone terminal-gate verification / ratification (Elixir/Phoenix auth library); no feature work
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01**: HEALTH-04 is satisfied by cutting a **final v1.43 ship/integration PR from `main`**, pushing it, and letting **GitHub Actions run every required lane** — HEALTH-04 gates on that PR's checks being green. Mirrors the v1.42 ship pattern (PR #63). The **actual merge to origin/main and the milestone archival are deferred** to `/gsd-ship` + `/gsd-complete-milestone` after this phase. Phase 215 proves close-readiness and gets the PR green; it does not itself merge or archive.
- **D-02**: "Green means green" — library and example suites must pass with **zero failures**. The Phase 211-era accepted known/env failures (3 `Sigra.UpgradeIntegrationTest` env-DB failures + `Chimeway.Repo` startup noise) were **resolved / correctly gated by HEALTH-03 in Phase 214**. Any failure outside a legitimately gated/skipped test is a **real regression to escalate**, not a known-failure to accept. Do NOT reintroduce a "green modulo known set" posture.
- **D-03**: HEALTH-01 must **record the exact command + result** used as the trustworthy release signal (canonical full-suite `mix test` against live Postgres, using the CLAUDE.md DB discovery) in a durable location (plan SUMMARY + STATE/close artifacts). "It passed" is not enough — the reproducible command and observed pass/fail counts are the artifact.
- **D-04**: RATIFY-01 reconciliation covers **only the deferred-items-ledger entries pulled into v1.43** (COMPAT-*, DEBT-*, HEALTH-03 resolved in Phases 213/214). Every such entry must read *resolved*. The pending v2/UI/SEED todos (`runtime-auth-prefix-override`, `mix-sigra-migrate-schema-helper`, `white-label-auth-email-theming`, `uat-demo-dx-polish-nits`, `vaultr-authed-rebrand-residuals`, `playwright-parallelization-per-shard-db`) are **explicitly out of scope** and stay deferred — NOT unreconciled milestone debt.
- **D-05**: The 2026-07-02 pending todo `app-css-corruption-guard-blind-spot` (harden the DEBT-05 app.css guard against a mid-block orphan false-negative) is an **accepted low-severity DEBT-05 follow-up**, not new *blocking* debt. RATIFY-01's "no new blocking debt" holds with this item classified and left tracked. The phase must **confirm** this classification, not fix it.
- **D-06**: This phase is **verification/ratification only** — no feature changes, no product behavior edits, no UI redesign. Code fixes are permitted **only** to repair genuine regressions surfaced by the gates (e.g. real installer-template drift caught by the golden/acceptance lane), never to mask an environmental issue.

### Claude's Discretion
- Whether HEALTH-01 (library suite) and HEALTH-02 (example suite) are one plan or two — lean toward the roadmap's natural split given `granularity: fine`.
- Exact PR mechanics for D-01 (branch name, whether to route through `/gsd-ship`, whether to open the PR inside this phase or hand a ready-to-push state to `/gsd-ship`) — planner's discretion, but the phase must reach a state where the required GitHub CI lanes are demonstrably green.
- Whether to also cross-check the required lanes locally (e.g. via nektos/act) as a pre-push confidence pass — optional, non-authoritative; the PR's GitHub Actions run is the HEALTH-04 signal of record.

### Deferred Ideas (OUT OF SCOPE)
- **Actual merge to origin/main + milestone archival** — handled by `/gsd-ship` + `/gsd-complete-milestone` after Phase 215 proves close-readiness (D-01).
- **v2 features** FEAT-01/02/03, **UI** UI-01/02/03, **SEED-005** per-shard-DB Playwright — remain in `.planning/todos/pending/`, explicitly out of v1.43 scope (D-04).
- **app.css corruption-guard hardening** (DEBT-05 follow-up) — accepted low-severity, tracked, not fixed in this phase (D-05).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HEALTH-01 | Full library test suite green against live Postgres, exact command + result recorded as trustworthy release signal | Ground-truthed live this session: `mix test` = **2404 tests, 0 failures, 12 skipped, 3 excluded, 33 doctests, 3 properties** (§Objective 1). Exact command + DB discovery documented. |
| HEALTH-02 | Example app test suite green against live Postgres | Ground-truthed live: `cd test/example && mix test --include example_app` = **323 tests, 0 failures** (§Objective 2). |
| HEALTH-04 | Every required CI check passes green end-to-end on the milestone branch | Required-check ruleset (14941512) enumerated live: 5 required contexts + ci-gate aggregator lanes (§Objective 3). PR-surface mechanics for the 43-commit body documented (§Objective 4). |
| RATIFY-01 | Milestone closes: full suite + CI green, every v1.43-pulled ledger entry reconciled (resolved), no new blocking debt | Ledger reconciliation cross-checked live: all v1.43-pulled items in `resolved/`; 4 v2/UI/SEED + 1 app.css-guard remain correctly deferred (§Objective 5). |
</phase_requirements>

## Summary

Phase 215 is the terminal gate of v1.43 STABILIZE (Phases 213–215). This is a **verification/ratification phase — no feature work**. The research job was to ground-truth the current on-branch state so the planner writes verification plans against reality. **The state is green.**

Live this session, on `main` with the CLAUDE.md DB discovery (`tmp/db.env`, dynamic port 58915; example lane against localhost:5432 to mirror CI): the **library suite passed 2404/2404 with 0 failures** (12 skipped, 3 excluded — all legitimately gated), and the **example suite passed 323/323 with 0 failures**. Every excluded/skipped test was classified and is legitimately gated (upgrade-archive conditional + intentional `:skip` planning-contract stubs), so the D-02 "green means green" bar is fully met **right now** — there is no known-failure residue to accept. The local fast-checks probes that matter (`app-css-corruption-check.sh`, `sigra.fixture.rebless_golden --check`) both pass, and the golden fixture is up-to-date under the pinned phx_new 1.8.8 archive (installed locally, matching CI).

The one open mechanical item is **D-01's PR surface**: local `main` is **43 commits ahead of `origin/main`** — the entire v1.43 body (Phases 213 + 214 + the 215 context commit) has **never run in CI**. HEALTH-04 requires surfacing these commits to GitHub Actions as a PR. There is also **worktree drift to resolve first**: 110 uncommitted `.planning/` deletions (the v1.42 phase 205–212 directories) sit in the worktree — the v1.42 archive commit archived the ROADMAP/REQUIREMENTS but never committed the phase-dir cleanup. The planner must decide how those deletions are handled (commit as cleanup vs. defer to `/gsd-cleanup`) before/as part of the PR.

**Primary recommendation:** Split into the roadmap's natural legs (given `granularity: fine`): (1) library-suite green + release-signal recorded (HEALTH-01), (2) example-suite green (HEALTH-02), (3) ledger/milestone reconciliation + app.css-guard classification (RATIFY-01), and (4) the D-01 PR surface that gets the 5 required GitHub checks green (HEALTH-04). Because the suites are already green on-branch, plans (1)–(3) are re-prove-and-record passes, not fixes. The load-bearing risk is entirely in the PR mechanics (worktree drift + never-CI'd 43-commit body), so plan (4) carries the real work.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Library test-suite green (HEALTH-01) | CI / Local test runner | Database (live Postgres) | ExUnit + SQL Sandbox against `Sigra.Test.PostgresRepo`; the trustworthy release signal is a local `mix test` result mirrored by the CI `Library tests` lane. |
| Example app suite green (HEALTH-02) | CI / Local test runner | Database | Generated-host parity proof; `test/example` ExUnit + ConnTest, mirrors the CI `Example unit smoke` lane. |
| Required CI checks green (HEALTH-04) | CI (GitHub Actions) | GitHub ruleset 14941512 | Authoritative signal is the PR's GitHub Actions run; the required-check set is defined by the branch ruleset, not the workflow file. |
| PR surface for the 43-commit body (D-01) | Git / GitHub (PR) | GSD helpers (`/gsd-pr-branch`, `/gsd-ship`) | Getting local `main` in front of Actions is a git/PR-mechanics problem; the harness blocks admin-merge/force-push/self-perms. |
| Ledger reconciliation (RATIFY-01) | Planning docs (`.planning/todos/`) | Requirements traceability | Pure bookkeeping cross-check; no code tier involved. |

## Standard Stack

This is a verification phase — it installs **no new packages**. The "stack" is the existing test/CI toolchain, ground-truthed live this session.

### Core (verified present this session)
| Tool | Version | Purpose | Verified |
|------|---------|---------|----------|
| Elixir | 1.19.5 (OTP 28) | Test runner / compile | `elixir --version` [VERIFIED: this session] |
| Erlang/OTP | 28.5 | Runtime | `.tool-versions` [VERIFIED] |
| phx_new archive | 1.8.8 | Install-golden + upgrade scaffolding | `mix archive` shows `phx_new-1.8.8` [VERIFIED] — matches the Phase 213 CI pin flip (1.8.7 → 1.8.8) |
| PostgreSQL (test) | ephemeral, dynamic port | Live DB for library suite | `tmp/db.env` → `127.0.0.1:58915`; `pg_isready localhost:5432` also accepting [VERIFIED] |
| ExUnit + SQL Sandbox | (Elixir stdlib / ecto_sql) | Test isolation | `Sigra.Test.PostgresRepo` sandbox `:manual` mode in `test_helper.exs` [VERIFIED] |

### Supporting (CI-only lanes)
| Tool | Purpose | When |
|------|---------|------|
| Playwright (chromium/webkit) | Example + admin browser truth, design gallery | CI `example_playwright_smoke` lane (darwin-hostile design baselines) |
| nektos/act | Optional local CI dry-run | Claude's Discretion D-01 pre-push confidence pass (non-authoritative) |

**Installation:** None. No `mix deps` change; no new archive. The only environmental prerequisite is the **phx_new 1.8.8 archive** (already installed locally) and a **live Postgres** (already available).

## Package Legitimacy Audit

Not applicable — this phase installs **no external packages** (pure verification/ratification, D-06). No SLOP/SUS surface.

## Architecture Patterns

### Verification Flow Diagram

```
                    Phase 215 Terminal Ratification
                              │
        ┌─────────────────────┼─────────────────────┬──────────────────────┐
        ▼                     ▼                     ▼                      ▼
  HEALTH-01              HEALTH-02             RATIFY-01               HEALTH-04
  library suite         example suite         ledger reconcile        CI green (PR)
        │                     │                     │                      │
  source tmp/db.env     cd test/example       cross-check             ┌────┴─────┐
  mix test              PG*=localhost:5432    .planning/todos/        │ worktree │
        │               mix test              resolved/ vs pending/   │  drift   │
        ▼               --include example_app       │                 │ (110 del)│
  2404 pass 0 fail            │                     ▼                 └────┬─────┘
  12 skip 3 excl        323 pass 0 fail       v1.43-pulled = resolved      ▼
        │                     │               v2/UI/SEED = deferred    /gsd-pr-branch
        └─────────┬───────────┘               app.css-guard = classified    or
                  ▼                                  │                  /gsd-ship
      record exact cmd+counts                        ▼                       │
      (D-03 release signal)                   "no new blocking debt"    push → GitHub
                  │                                  │                  Actions runs
                  └──────────────┬───────────────────┘                  5 required + gate
                                 ▼                                            │
                        milestone close-ready                                 ▼
                        (merge + archive DEFERRED to                    green checks =
                         /gsd-ship + /gsd-complete-milestone)           HEALTH-04 signal
```

Data-flow note: the **authoritative HEALTH-04 signal** is the GitHub Actions run on the PR (right branch), not any local run. Local runs (left/center branches) are the HEALTH-01/02 release signals and an optional pre-push confidence pass.

### Pattern 1: Phase-211 three-legged ratification, retargeted to v1.43
**What:** Phase 211 (v1.42's terminal ratification) used three verification-only plans — ledger/idempotency lock, generated-host parity, clean `mix test` classification. Phase 215 shares that DNA **minus** the admin design-system ledger (v1.43 is a pure stabilization lane, not a DS elevation).
**When to use:** Terminal milestone gate with no feature work.
**Mapping (retargeted):**
- 211-01 (ledger/idempotency lock, all-`2` monotonic guard) → **RATIFY-01** here becomes a *deferred-items-ledger* reconciliation (todos), NOT a DS quality-ledger — there is no `admin-quality-ledger.md` cell-flip in v1.43.
- 211-03 (clean `mix test` classification / release-signal discipline) → **HEALTH-01 + HEALTH-02** here, but with the D-02 twist: the 211-era accepted known/env set is **resolved**, so the classification must show **zero** residual failures, not "green modulo known set."
- 211-02 (generated-host parity via install-golden + admin-acceptance-smoke) → subsumed into **HEALTH-04** (those lanes are part of the required-check surface).
**Source:** `git show HEAD:.planning/phases/211-terminal-ratification/211-0{1,3}-PLAN.md` [VERIFIED: git HEAD this session]

### Pattern 2: Record-the-signal discipline (D-03)
**What:** The release signal is the *reproducible command + observed counts*, not "it passed." Phase 211-03's must-haves recorded the exact `mix test` verdict; Phase 214's VERIFICATION recorded "2404 tests, 0 failures, 12 skipped."
**When to use:** HEALTH-01 SUMMARY and the milestone-close STATE artifact.
**Example (the canonical invocation, verified live):**
```bash
# Source: this session — the trustworthy release-signal command
cd /Users/jon/projects/sigra
source tmp/db.env 2>/dev/null   # dynamic ephemeral PG port; falls back to localhost:5432 if absent
mix test                        # mix sets MIX_ENV=test itself
# => 33 doctests, 3 properties, 2404 tests, 0 failures, 12 skipped (3 excluded)
```

### Anti-Patterns to Avoid
- **Reintroducing a "green modulo known set" posture (D-02).** The 3 UpgradeIntegrationTest env-DB failures and Chimeway.Repo noise are resolved/gated. Any failure now is a real regression. Do not carry an accepted-failures list.
- **"Fixing" the golden fixture instead of installing the pin (D-06).** A byte-diff in `golden_diff_test` from a wrong local phx_new archive is an environment issue → install phx_new 1.8.8, never edit the committed fixture.
- **Treating a local `act`/`mix test` pass as the HEALTH-04 signal.** HEALTH-04's signal of record is the PR's GitHub Actions run (D-01). Local is confidence-only.
- **Merging/archiving inside this phase (D-01).** Phase 215 proves close-readiness and gets the PR green; `/gsd-ship` + `/gsd-complete-milestone` do the merge + archive.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Getting the 43-commit body in front of CI | A hand-crafted `git push` + manual `gh pr create` with ad-hoc base/head | `/gsd-pr-branch` (filters `.planning/` commits for a clean review PR) or `/gsd-ship` | GSD helpers exist and encode the harness constraints (no admin-merge/force-push/self-perms); the v1.42 ship (PR #63) used this path. |
| Enumerating "required" CI checks | Reading `.github/workflows/ci.yml` job names and guessing | `gh api repos/szTheory/sigra/rulesets/14941512` | The required-check set lives in the **branch ruleset**, not the workflow; the workflow has ~20 jobs but only 5 are *required* (§Objective 3). |
| Reconciling the ledger | Re-triaging every todo from scratch | Cross-check `.planning/todos/resolved/` vs `pending/` against the D-04 scope list | The v1.43-pulled items are already in `resolved/`; RATIFY-01 is a confirm-and-record pass. |
| Classifying excluded/skipped tests | Assuming they're failures | The `test_helper.exs` conditional-exclude + `@moduletag :skip`/`:upgrade` tags | Every exclusion is a documented gate (§Objective 1 classification). |

**Key insight:** This phase's real work is git/PR mechanics + bookkeeping, not code. The suites are already green; the danger is (a) never-CI'd commits surfacing a lane failure GitHub hasn't seen, and (b) the uncommitted worktree drift confusing the PR.

## Runtime State Inventory

> This phase is a verification pass, not a rename/refactor. Included because the PR surface (D-01) has real git-state landmines that behave like "runtime state a grep won't find."

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verification phase, no schema/data mutation. | None. |
| Live service config | **GitHub branch ruleset 14941512** (required checks + `pull_request` + `deletion` + `non_fast_forward` rules; `strict_required_status_checks_policy: True`). This config lives in GitHub, not git. | Planner must target the PR at these 5 required contexts; `strict` means the PR branch must be up-to-date with `origin/main` base. |
| OS-registered state | None. | None. |
| Secrets/env vars | Test DB discovery via `tmp/db.env` (`SIGRA_TEST_PG_*` + `PG*`), dynamic port 58915; falls back to localhost:5432. `CLOAK_KEY` dummy used by install/smoke CI lanes. | None — read-only; no rename. |
| Build artifacts / uncommitted worktree state | **110 uncommitted `.planning/` worktree deletions** (v1.42 phase 205–212 dirs) — still present in `HEAD`; the v1.42 archive commit (`a97a6672`) archived ROADMAP/REQUIREMENTS but never committed the phase-dir cleanup. Also open PRs: **#66 release-please `chore(main): release 1.2.0`**, dependabot #61/#57. | Planner must decide: commit the deletions as milestone cleanup, `git restore` them, or defer to `/gsd-cleanup`. A clean PR should not carry 110 stray deletions unintentionally. |

**The canonical question for this phase:** After the suites prove green locally, *what git/GitHub state stands between `main` and a green required-check set on a PR?* Answer: (1) 43 never-CI'd commits, (2) 110 uncommitted `.planning/` deletions, (3) a `strict` ruleset requiring the branch be current with base.

## Common Pitfalls

### Pitfall 1: The never-CI'd 43-commit body surfaces a lane failure locally-invisible
**What goes wrong:** All suites pass locally, but a CI-only lane (Playwright design gallery, generated-admin acceptance smoke, dep-off) fails on the PR because it has never run on this body.
**Why it happens:** Local `mix test` covers the library + example ExUnit suites, not the browser/Playwright/generated-host lanes. Design baselines are **CI-native (ubuntu)** and darwin-hostile — a local capture injects spurious px diffs (per project convention: `admin_design_recapture` job owns board-* PNGs, never darwin).
**How to avoid:** Push early to get the full lane matrix running; optionally pre-run the fast lanes locally (`app-css-corruption-check.sh`, `rebless_golden --check` — both pass this session) and via `act` for the container-parity lanes. Do NOT recapture design baselines locally to "fix" a gallery diff (D-06 — that would mask, and darwin-capture is wrong).
**Warning signs:** A `example_playwright_smoke` or `generated_admin_playwright_smoke` red on the PR with a snapshot diff.

### Pitfall 2: The `strict_required_status_checks_policy: True` blocks a stale PR branch
**What goes wrong:** The PR sits with "required checks expected" or "branch out of date" even though checks passed.
**Why it happens:** The ruleset requires the PR branch to be up-to-date with `origin/main` base. If `origin/main` moves (e.g. dependabot #61/#57 or release-please #66 merges), the branch goes stale.
**How to avoid:** Keep the PR branch current with base; `/gsd-ship` handles this. Do not attempt admin-merge to bypass (harness blocks it).
**Warning signs:** GitHub shows "This branch is out-of-date with the base branch."

### Pitfall 3: Wrong local phx_new archive → spurious golden byte-diff
**What goes wrong:** `golden_diff_test` / `rebless_golden --check` fails locally with a `config/config.exs root_tag_attribute` byte-diff.
**Why it happens:** Phase 213 flipped the pin 1.8.7 → 1.8.8; a mismatched local archive regenerates different bytes.
**How to avoid:** `mix archive.install --force hex phx_new 1.8.8` (already installed this session; `--check` passes). If a diff appears, fix the archive, never the fixture (D-06).
**Warning signs:** `check_exit` non-zero from `mix sigra.fixture.rebless_golden --check`.

### Pitfall 4: The 110 `.planning/` deletions leak into the PR
**What goes wrong:** The clean ship PR accidentally deletes 110 v1.42 phase-dir files (18,981 line deletions), muddying review and risking a `deletion`-rule interaction.
**Why it happens:** They're uncommitted in the worktree; a naive `git add -A` sweeps them in.
**How to avoid:** Decide their disposition explicitly (commit as cleanup / restore / defer). `/gsd-pr-branch` filters `.planning/` commits, which helps, but these are *uncommitted deletions* — handle them before branching.
**Warning signs:** `git status` shows `D .planning/phases/205…212/*`.

## Code Examples

### Objective 1 — library release signal (verified live)
```bash
# Source: this session, on main, tmp/db.env loaded (port 58915)
cd /Users/jon/projects/sigra && source tmp/db.env 2>/dev/null && mix test
# => Finished in 212.0 seconds (2.8s async, 209.1s sync)
# => 33 doctests, 3 properties, 2404 tests, 0 failures, 12 skipped (3 excluded)
```

### Objective 2 — example suite (verified live, CI-parity env)
```bash
# Source: this session — mirrors CI example_unit_smoke lane exactly
cd /Users/jon/projects/sigra/test/example
export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost   # CI uses localhost:5432
MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate
mix test --include example_app
# => Finished in 2.8 seconds  →  323 tests, 0 failures
# NB: [error] "Jetstream #907 structural defense" log lines are the TESTED deny-path
#     firing (accept_invitation on invalid/already_accepted branch) — the test passes.
```

### Objective 3 — required-check enumeration (verified live)
```bash
# Source: this session — the AUTHORITATIVE required set (not the workflow job list)
gh api repos/szTheory/sigra/rulesets/14941512 \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print(c['context']) for r in d['rules'] if r['type']=='required_status_checks' for c in r['parameters']['required_status_checks']]"
```

### Objective — local fast-lane pre-push confidence (verified passing)
```bash
bash scripts/ci/app-css-corruption-check.sh          # => exit 0 (fast_checks lane)
source tmp/db.env; MIX_ENV=test mix sigra.fixture.rebless_golden --check   # => "fixture is up-to-date"
```

## State of the Art

| Old (Phase 211 / v1.42) | Current (Phase 215 / v1.43) | When Changed | Impact |
|--------------------------|------------------------------|--------------|--------|
| "Green modulo accepted known set" (3 upgrade env-DB + Chimeway noise tolerated) | **Zero failures required**; known set resolved/gated by HEALTH-03 | Phase 214 (HEALTH-03) | D-02: no accepted-failures list; any failure escalates. |
| DS quality-ledger cell-flip lock (all-`2` monotonic guard) as the ratification ledger | **Deferred-items todo ledger** reconciliation (no DS ledger in v1.43) | v1.43 milestone scope | RATIFY-01 is a todo cross-check, not a `admin-quality-ledger.md` flip. |
| phx_new **1.8.7** archive pin | phx_new **1.8.8** archive pin (all 11 CI references + CLAUDE.md) | Phase 213 (COMPAT-03) | Local dev must have 1.8.8 (installed this session). |
| Merge inside terminal phase (PR #63 merged in Phase 212) | **Merge/archive deferred** to `/gsd-ship` + `/gsd-complete-milestone` | D-01 | Phase 215 gets the PR green only. |

**Deprecated/outdated:**
- The Phase 211-era `Sigra.UpgradeIntegrationTest` "3 env-DB failures" acceptance — **superseded** by the `test_helper.exs` conditional `:upgrade` exclusion (runs in CI, cleanly skipped locally when archive absent). Do not reference it as a known-failure.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 43 never-CI'd commits will pass all required CI lanes when pushed (local suites green + local fast-lanes green is a strong but incomplete predictor — Playwright/generated-host/dep-off lanes have not run on this exact body). | Objective 3/4, Pitfall 1 | A CI-only lane could red on the PR; that would be a genuine regression to fix under D-06, not an environment excuse. **This is the phase's primary residual risk** and why plan (4) carries the real work. |
| A2 | The 110 `.planning/` worktree deletions are intended v1.42 cleanup (the archive commit's un-committed tail), not accidental loss. | Runtime State Inventory | If they should be preserved, committing the deletions would be wrong; planner must confirm disposition, not assume. |
| A3 | `/gsd-pr-branch` / `/gsd-ship` remain the sanctioned PR path and the harness still blocks admin-merge/force-push/self-perms (per v1.42 lessons). | Don't Hand-Roll, Objective 4 | If harness rules changed, PR mechanics differ; verify at execution time. |

**Note:** A1 is the only material risk. A2/A3 are procedural confirmations.

## Open Questions

1. **Disposition of the 110 uncommitted `.planning/` deletions before the PR.**
   - What we know: They are the v1.42 phase 205–212 dirs, present in HEAD, deleted in worktree; the archive commit `a97a6672` archived ROADMAP/REQUIREMENTS but not these.
   - What's unclear: Commit as milestone cleanup now, `git restore` them, or defer to `/gsd-cleanup` / `/gsd-complete-milestone`.
   - Recommendation: Keep the ship PR clean — either commit them as an explicit `chore: cleanup v1.42 phase dirs` (if `/gsd-cleanup` is the sanctioned owner, defer) or restore them so the PR carries only v1.43 code/doc commits. Planner decides; flag for the user if it touches archival policy.

2. **Do the CI-only lanes (Playwright, generated-host, dep-off) pass on this body?** (A1)
   - What we know: Library + example ExUnit suites green; `app-css-corruption-check.sh` + `rebless_golden --check` green.
   - What's unclear: The browser/generated-host/dep-off lanes have not run on these 43 commits.
   - Recommendation: Push early; optionally pre-run via `act` (Claude's Discretion). Treat any red as a real regression (D-06).

3. **Interaction with open PRs (#66 release-please, #61/#57 dependabot) and the `strict` ruleset.**
   - What we know: `strict_required_status_checks_policy: True`; #66 is `chore(main): release 1.2.0`.
   - What's unclear: Whether release-please/dependabot will move `origin/main` under the ship PR and force a re-sync.
   - Recommendation: Coordinate ordering at `/gsd-ship` time; keep the PR branch current with base.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/OTP | Both suites | ✓ | 1.19.5 / OTP 28.5 | — |
| phx_new archive | install-golden, upgrade, golden fixture | ✓ | 1.8.8 | Install `mix archive.install --force hex phx_new 1.8.8` (never edit fixture) |
| Live Postgres | Library + example suites | ✓ | ephemeral (port 58915) + localhost:5432 | `scripts/db/up.sh` boots ephemeral PG → `tmp/db.env` |
| `gh` CLI (authed) | PR surface (D-01) | ✓ | authed as `szTheory` | — |
| GitHub Actions | HEALTH-04 signal of record | ✓ (remote) | — | none — this IS the authoritative signal |
| Playwright browsers | CI browser lanes | CI-only | — | Run on GitHub Actions (darwin-hostile locally) |
| nektos/act | Optional local CI dry-run | (per prior memory, available on this Mac) | — | Skip — non-authoritative confidence pass only |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None blocking — all present.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 / OTP 28.5) + StreamData (properties) + Mox |
| Config file | `test/test_helper.exs` (conditional `:upgrade` exclude; `Sigra.Test.PostgresRepo` sandbox `:manual`); example: `test/example/test/test_helper.exs` |
| Quick run command | `source tmp/db.env 2>/dev/null; mix test <path>` (single file/line for a targeted re-prove) |
| Full suite command (library) | `source tmp/db.env 2>/dev/null; mix test` |
| Full suite command (example) | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test --include example_app` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HEALTH-01 | Library suite green against live Postgres | full-suite | `source tmp/db.env; mix test` → 2404/0-fail | ✅ (exists; green live) |
| HEALTH-02 | Example suite green against live Postgres | full-suite | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test --include example_app` → 323/0-fail | ✅ (exists; green live) |
| HEALTH-04 | Required CI checks green on PR | CI (remote) | PR → GitHub Actions; `gh pr checks <n>` | ✅ (workflow + ruleset exist) |
| RATIFY-01 | v1.43-pulled ledger resolved; no new blocking debt | doc-audit | `ls .planning/todos/resolved/ .planning/todos/pending/` cross-check | ✅ (todos exist) |

### Sampling Rate
- **Per task commit:** targeted `mix test <file>` for any re-prove; `bash scripts/ci/app-css-corruption-check.sh` for the fast-checks lane.
- **Per wave/plan merge:** full library `mix test` + example `mix test --include example_app`.
- **Phase gate:** full library + example suites green locally (release signal recorded per D-03) **and** the D-01 PR's required GitHub checks green (HEALTH-04 signal of record) before `/gsd-ship`.

### Wave 0 Gaps
- None — existing test infrastructure covers all phase requirements. Both suites are green on-branch this session; no new tests are authored (D-06 forbids adding tests to "improve" the suite). The only "gap" is operational: the never-CI'd body must actually run on GitHub Actions (HEALTH-04).

## Security Domain

> `security_enforcement` is not disabled in config. This is a **verification-only** phase (D-06) that adds no code, no new endpoints, no crypto, no input surface. No new threat surface is introduced.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (no auth code changed) | n/a — existing Sigra controls unchanged |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a (the phase-214 IDOR guard on `delete_session/3` is already merged + tested; not re-touched here) |
| V5 Input Validation | no | n/a — no new input surface |
| V6 Cryptography | no | n/a — no crypto changes |

### Known Threat Patterns for this phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Merging never-reviewed/never-CI'd code | Tampering / Repudiation | The D-01 PR + required-check ruleset (14941512) forces CI + PR review before merge; harness blocks admin-merge/self-perms. |
| Baseline-masking a real visual/behavioral regression | Tampering | D-06 forbids "fixing" a gate by editing fixtures/baselines; design baselines are CI-native. |

**Verdict:** No security work required. The relevant control is process-level: the required-check ruleset ensures the v1.43 body is CI-verified and PR-reviewed before it can merge.

## Sources

### Primary (HIGH confidence — verified live this session)
- `mix test` (library) → 2404 tests, 0 failures, 12 skipped, 3 excluded [VERIFIED: this session]
- `cd test/example && mix test --include example_app` → 323 tests, 0 failures [VERIFIED: this session]
- `gh api repos/szTheory/sigra/rulesets/14941512` → 5 required contexts + pull_request/deletion/non_fast_forward rules, strict policy [VERIFIED: this session]
- `git rev-list --count origin/main..main` → 43; `git log origin/main..main` → Phases 213/214 + 215 context [VERIFIED]
- `git status` → 110 uncommitted `.planning/` deletions (v1.42 phase 205–212 dirs) [VERIFIED]
- `bash scripts/ci/app-css-corruption-check.sh` → exit 0 [VERIFIED]
- `mix sigra.fixture.rebless_golden --check` → "fixture is up-to-date" [VERIFIED]
- `mix archive` → phx_new-1.8.8 present [VERIFIED]
- `.github/workflows/ci.yml` (full read) — ci-gate aggregator needs 9 lanes; required-check subset is the 5 ruleset contexts [VERIFIED]
- `.planning/phases/214-debt-robustness-clear/214-VERIFICATION.md` — 6/6 verified; HEALTH-03 resolution (Chimeway config, conditional :upgrade skip); orchestrator run "2404 tests, 0 failures, 12 skipped" [VERIFIED]
- `git show HEAD:.planning/phases/211-terminal-ratification/211-0{1,3}-PLAN.md` — structural precedent [VERIFIED]

### Secondary (MEDIUM confidence)
- `.planning/todos/resolved/` vs `pending/` cross-check — v1.43-pulled items resolved; 6 deferred pending [VERIFIED bookkeeping]
- `gh pr list` → open PRs #66 (release-please 1.2.0), #61/#57 (dependabot) [VERIFIED]

### Tertiary (LOW confidence)
- A1 prediction that never-CI'd CI-only lanes will pass — inferred from green local suites + green local fast-lanes; not directly verifiable without pushing. [ASSUMED]

## Metadata

**Confidence breakdown:**
- HEALTH-01 (library green): HIGH — ran live, 0 failures, all exclusions classified.
- HEALTH-02 (example green): HIGH — ran live, 0 failures.
- HEALTH-04 (CI required set): HIGH on the required-check enumeration (ruleset API); MEDIUM on whether the body passes on the PR (A1, unrunnable locally for browser/generated-host lanes).
- RATIFY-01 (ledger): HIGH — direct todo cross-check.
- PR mechanics / worktree drift: HIGH on the facts (43 commits, 110 deletions, strict ruleset); the *disposition* of the deletions is an Open Question for the planner.

**Research date:** 2026-07-03
**Valid until:** ~2026-07-10 (fast-moving: `origin/main` can shift via #66/#61/#57; re-confirm counts + ahead-by before pushing).
