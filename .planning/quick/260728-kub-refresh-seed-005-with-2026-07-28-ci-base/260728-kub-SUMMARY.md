---
phase: quick-260728-kub
plan: 01
subsystem: planning
tags: [ci, seed, todo, documentation]
requires: []
provides:
  - SEED-005 2026-07-28 re-measurement addendum
  - admin_eval_render unread-red defect todo
  - generated-host-parity skipped-passes-gate defect todo
affects:
  - .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
  - .planning/todos/pending/
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md
    - .planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
  modified:
    - .planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md
decisions:
  - "SEED-005's next reader is told to execute the already-derived 2026-06-20 audit backlog, not re-run the playbook."
  - "Refined one cited line reference (ci.yml:2179 -> 2177-2179) so the 'admin-eval uses chromium' comment claim points at the line that actually carries the comment."
metrics:
  duration: ~9m
  completed: 2026-07-28
status: complete
---

# Quick Task 260728-kub: Refresh SEED-005 with the 2026-07-28 CI Baseline Summary

Recorded in-repo that the CI/CD performance audit was **already executed** on 2026-06-20 and its
prioritized Phase 198→203 plan was **orphaned** by v1.41 reusing phase numbers 199-204 — plus
filed the two CI defect todos the same fan-out investigation surfaced.

## What Was Done

### Task 1 — SEED-005 addendum (commit `fb9c73f7`)

Spliced `## Addendum 2026-07-28 — re-measured; the audit's plan was orphaned, not executed` into
`.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` using **Edit** against the unique
four-line anchor, landing it after the CORRECTION blockquote and before the `---` that precedes
the verbatim playbook.

All seven required elements are present: the orphaned-audit headline, the still-accurate
verification, the 40-run baseline table, the `example_playwright_smoke` critical-path
decomposition, the newly-found waste, the locked 2026-07-28 decisions, and the `<12m` target with
proposed phases 230-235.

**`git diff --numstat` reported `74  0`** — 74 insertions, **zero deletions**. The verbatim
playbook, Jon's framing prompt, and the scope guardrails are byte-identical.

### Task 2 — admin_eval_render todo (commit `274521b1`)

`.planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md`.
Records ~17m per PR for an artifact nothing reads, both root causes (WebKit `iPhone 13` preset vs
chromium-only install; `SVGAnimatedString` in the probe), and — the silent part — that harness
phases a2 and b1-b6 **have never executed in CI**, with `stale-render-guard.sh` isolated as the
sole guard not covered elsewhere.

### Task 3 — generated-host-parity todo (commit `cb8f9031`)

`.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md`.
Records the stale `ship/v1.42-ci-gate-remediation` `head_ref` clause, `ci-gate`'s skipped-is-pass
semantics, the 7-of-9-lanes blast radius, and that `ci-gate` is itself not a required context.

## Citation Verification

Every line reference in the plan was checked against the current tree before being written. **All
were accurate**; one was refined for precision:

| Citation | Status |
|----------|--------|
| `admin-design.spec.ts:250-255` | Exact — `test.beforeEach` → `registerUser()`, no `storageState` |
| `mix.exs:143` | Exact — `ci:` alias, confirmed missing format + deps-lock checks |
| `release-please.yml:88` | Exact — `googleapis/release-please-action@v5`, tag-pinned not SHA-pinned |
| `.github/dependabot.yml` | Exact — single `github-actions` ecosystem |
| `ci.yml:2102-2237` | Exact — `admin_eval_render` job bounds, no `if:` gate, `continue-on-error: true` at 2110 |
| `ci.yml:1464-1473` | Exact — `ci-gate.needs`, 9 lanes, `admin_eval_render` absent |
| `ci.yml:1501-1505` | Exact — `!= "success" && != "skipped"` skipped-is-pass check |
| `ci.yml:1338` | Exact — `generated_admin_playwright_smoke`, stale `head_ref` clause at 1341 |
| `ci.yml:2179` | **Refined to `2177-2179`** — see below |

**The one refinement.** The plan cited `ci.yml:2179` as the line "whose own comment asserts
'admin-eval uses chromium'". Line 2179 is the `run: npx playwright install --with-deps chromium`
command; the misleading text is on the step **name** two lines up at 2177. The todo cites
`ci.yml:2177-2179` so both halves of the claim — the comment and the chromium-only install — are
covered by the reference. The substance of the finding is unchanged.

Two factual claims were additionally corroborated rather than taken on trust:

- **No `concurrency:` block in `ci.yml`** — confirmed absent.
- **`upgrade_smoke` also skips on PRs** — confirmed, `ci.yml:643` carries
  `if: github.event_name != 'pull_request'`, so the "7 of its 9 lanes" figure holds.
- **`stale-render-guard.sh` runs nowhere else** — confirmed. `fast_checks` runs only the guard's
  *unit self-test* (`stale-render-guard.test.sh`, `ci.yml:147-149`); the sole real invocation is
  `admin-eval-harness.sh:94`, downstream of the abort.

## Deviations from Plan

**1. [Rule 3 - Blocking] Worktree branch-namespace assertion relaxed to the deny-list**

- **Found during:** Task 1, pre-commit
- **Issue:** The executor's worktree HEAD assertion requires the branch to match
  `worktree-agent-*`. This run is an operator-directed **sequential** run on the pre-existing
  worktree `.claude/worktrees/v1.46-login-email-label`, checked out on
  `ci-efficiency-milestone-scope` @ `018229e5` — exactly the branch the orchestrator named as the
  commit target. The namespace allow-list would have produced a false-positive halt.
- **Fix:** Enforced the safety-critical **deny-list** (`main`/`master`/`develop`/`trunk`/
  `release/*` + detached HEAD) before every commit, and skipped the `worktree-agent-*` allow-list.
  No protected ref was touched; no `git update-ref` was used.
- **Files modified:** none

**2. [Precision] `ci.yml:2179` → `ci.yml:2177-2179`** — documented in Citation Verification above.

No other deviations. No architectural changes. No package installs.

## Constraint Compliance

- `git status --porcelain -- .github scripts mix.exs test lib priv` → **empty**. No workflow,
  script, spec, `mix.exs`, or source file was modified.
- Not pushed, no PR, no tag: `git status -sb` → `## ci-efficiency-milestone-scope...origin/main [ahead 3]`.
- No `git clean`, `git stash`, `git reset --hard`, or blanket restore was run at any point.
- `ROADMAP.md` and `STATE.md` untouched, per the orchestrator's instruction.
- Docs artifacts (this SUMMARY, the PLAN) left uncommitted for the orchestrator.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `fb9c73f7` | `docs(quick-260728-kub): add 2026-07-28 re-measurement addendum to SEED-005` |
| 2 | `274521b1` | `docs(quick-260728-kub): file admin_eval_render unread-red CI todo` |
| 3 | `cb8f9031` | `docs(quick-260728-kub): file generated-host-parity skipped-passes-gate CI todo` |

## Known Stubs

None.

## Self-Check: PASSED

- `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` — FOUND, modified, 0 deletions
- `.planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md` — FOUND
- `.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` — FOUND
- Commits `fb9c73f7`, `274521b1`, `cb8f9031` — all FOUND in `git log`
- Addendum order check — `ORDER OK` (CORRECTION 198 < addendum 207 < playbook 283)
- Both todos — `FRONTMATTER OK`, all content greps ≥ 1
