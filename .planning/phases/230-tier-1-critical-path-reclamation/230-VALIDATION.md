---
phase: 230
slug: tier-1-critical-path-reclamation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-28
---

# Phase 230 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `230-RESEARCH.md` § Validation Architecture (lines 899–976).

**Binding constraint:** every success criterion in this phase is a claim about **what a run did**,
not about what a file says. `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` records the precedent
failure — *"code-level reads that never executed the specs"*. Static reads are acceptable only as
**necessary-but-not-sufficient** pre-checks.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (library)** | ExUnit (Elixir ~> 1.18) |
| **Framework (browser)** | `@playwright/test` **1.59.1** (lockfile-pinned) |
| **Framework (guards)** | bash + node hermetic self-tests under `scripts/ci/`, executed by `fast_checks` |
| **Config file** | `test/test_helper.exs` · `test/example/priv/playwright/playwright.config.ts` · `.github/workflows/ci.yml` (`fast_checks`) |
| **Quick run command** | `mix test test/sigra/planning/` |
| **Guard self-test command** | `bash scripts/ci/ci-run-metrics.test.sh` (new — Wave 0) |
| **Full suite command** | `mix test` (requires Postgres per CLAUDE.md) |
| **Estimated runtime** | ~10s quick · ~8m full |

---

## Sampling Rate

- **After every task commit:** `mix test test/sigra/planning/` + the new guard self-tests (seconds)
- **After every plan wave:** every `scripts/ci/*.test.sh` / `*.test.mjs` the wave touched
- **Before `/gsd-verify-work`:** the six observed-run slots below, all captured with run IDs
- **Max feedback latency:** ~30 seconds for the static/unit layer

---

## The Observed-Run Evidence Contract (the phase's real gate)

The phase is judged on **one before/after pair of real runs**. A claim without a run ID is not evidence.

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| **BEFORE-PR** | PR run `30390832059` (2026-07-28, pre-change) | `gh run view 30390832059 --json jobs` | ✅ captured |
| **BEFORE-PUSH** | Push run `30389700235` (2026-07-28, pre-change) | `gh run view 30389700235 --json jobs` | ✅ captured |
| **AFTER-PR** | The phase's own PR, final commit | `scripts/ci/ci-run-metrics.sh --jobs <id>` | ⬜ pending |
| **AFTER-PUSH** | The push-to-`main` run of the merge commit | `scripts/ci/ci-run-metrics.sh --jobs <id>` | ⬜ pending |
| **AFTER-DOCSONLY** | A throwaway docs-only PR (touch one `.md`) | `gh pr checks <n>` + `gh run view <id> --json jobs` | ⬜ pending |
| **AFTER-CANCEL** | Double-push probe on the phase branch | `gh run list --branch <b> --json conclusion` | ⬜ pending |

**Anti-pattern to reject at review:** any verification step whose command is `grep`, `cat`, or `Read`
against `ci.yml` / `admin-design.spec.ts` as the *sole* proof of a success criterion.

---

## Per-Requirement Verification Map

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| FAST-02 | Board tests carry `@snapshot`; axe tests do not; `assertBoardScreenshot` no longer calls axe | unit (static) | `mix test test/sigra/planning/` | ❌ W0 | ⬜ pending |
| FAST-02 | PR gallery step executes **39** tests; non-PR snapshot step executes **84** | observed run | `gh run view <pr_id> --json jobs` + step log tail | ✅ contract | ⬜ pending |
| FAST-02 | `admin_design_recapture` still executes **120** tests (Pitfall 1 regression guard) | observed run | `gh run view <push_id> --json jobs` → recapture step log | ✅ contract | ⬜ pending |
| FAST-03 | `admin_eval_render` skipped on PR, executes on push | observed run | `gh run view <id> --json jobs --jq 'select(.name\|startswith("Admin eval render"))'` | ✅ contract | ⬜ pending |
| FAST-04 | Superseded PR run concludes `cancelled`; push/schedule do not | observed run | double-push probe + `gh run list --branch <b> --json conclusion` | ✅ contract | ⬜ pending |
| FAST-05 | Docs-only PR: five required contexts report a merge-eligible state | observed run | `gh pr checks <n>` on a throwaway docs-only PR | ✅ contract | ⬜ pending |
| FAST-05 | `fast_checks` and `library_tests` still execute **in full** on a docs-only PR | observed run | same run's job durations (~27s and ~8m, not ~0s) | ✅ contract | ⬜ pending |
| FAST-06 | PR run logs a Playwright browser **cache hit** | observed run | `$GITHUB_STEP_SUMMARY` + install-step duration | ✅ contract | ⬜ pending |
| FAST-06 | Cache key version tracks the lockfile | unit (guard) | `bash scripts/ci/playwright-cache-key-guard.test.sh` | ❌ W0 | ⬜ pending |
| FAST-07 | Every job in `ci.yml` declares `timeout-minutes` | unit (static) | new assertion in `test/sigra/planning/` | ❌ W0 | ⬜ pending |
| SC-5 / D-21 | Measurement script reproduces the baseline table shape; clamps negatives; explicit p50 | unit (hermetic) | `bash scripts/ci/ci-run-metrics.test.sh` | ❌ W0 | ⬜ pending |
| all | `ci.yml` contract tests still pass after the edits | unit (regression) | `mix test test/sigra/planning/` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Per-task IDs are bound at execution time; the planner maps each task to a row above via its
> `<acceptance_criteria>`.

---

## Wave 0 Requirements

- [ ] `scripts/ci/ci-run-metrics.sh` + `scripts/ci/ci-run-metrics.test.sh` — D-21 measurement script, wired into `fast_checks`
- [ ] `scripts/ci/playwright-cache-key-guard.sh` + `.test.sh` — FAST-06 version-drift guard (RESEARCH Pitfall 6)
- [ ] A `timeout-minutes` completeness assertion — every `runs-on:` in `ci.yml` has a sibling `timeout-minutes:` (FAST-07). Precedent: `test/sigra/planning/phase_153_infra_stability_contract_test.exs`
- [ ] A `@snapshot` tag-integrity assertion — all 28 board tests tagged; the 12 non-board and 3 axe tests untagged (FAST-02), guarding against a future test landing untagged on the PR critical path
- [ ] The D-23 honest-skip artifact — the enumerated set of jobs/steps that legitimately skip on a PR event after this phase, as the documented baseline Phase 231's GATE-03 inherits

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

*All phase behaviors have automated verification.* The six observed-run slots are **automated
commands** (`gh run view` / `gh pr checks` / `scripts/ci/ci-run-metrics.sh`) whose precondition is a
real CI run — they require no human judgment, only that the run exists. This preserves the
zero-human-UAT posture: the operator triggers runs, the evidence is machine-read.

**Known observability limit (RESEARCH Open Question 4):** a green `schedule` observation may be
unobtainable in this phase — the nightly is 0-pass/9-fail and that is GATE-01's problem in Phase 231.
SC-3's schedule half is therefore proven by a `workflow_dispatch` proxy **plus** the structural
`run_id`-group argument (D-12), stated explicitly rather than claimed as an observed nightly.

---

## Restated Success Criterion (SC-2)

RESEARCH finding 2 established that SC-2 as worded in ROADMAP.md is literally unsatisfiable: a job
whose `if:` evaluates false is **still present** in `gh run view --json jobs` with
`conclusion: "skipped"` and ~0s duration (verified on PR run `30390832059`, six such jobs).

**Operative restatement — verify against this, not the ROADMAP wording:**
> `admin_eval_render` appears in a PR run's job list with `conclusion == "skipped"` and
> `duration < 5s`, and appears on a non-PR run with `conclusion == "success"` and a
> real duration — with its ~17m no longer charged to any PR.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (5 items above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for the static/unit layer
- [ ] All six observed-run slots captured with verbatim run IDs
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
