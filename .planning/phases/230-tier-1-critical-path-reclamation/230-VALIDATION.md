---
phase: 230
slug: tier-1-critical-path-reclamation
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| **Guard self-test command** | `bash scripts/ci/ci-run-metrics.test.sh` · `bash scripts/ci/playwright-cache-key-guard.test.sh` · `bash scripts/ci/docs-only-classify.test.sh` (all wired into `fast_checks`) |
| **Full suite command** | `mix test` (requires Postgres per CLAUDE.md) |
| **Validated runtime** | ~3s targeted guards + Phase-230 contracts (2026-08-04); full suite remains environment-dependent |

---

## Sampling Rate

- **After every task commit:** `mix test test/sigra/planning/` + the new guard self-tests (seconds)
- **After every plan wave:** every `scripts/ci/*.test.sh` / `*.test.mjs` the wave touched
- **Before `/gsd-verify-work`:** the eight observed-run slots below, all captured with run IDs
- **Max feedback latency:** ~30 seconds for the static/unit layer

---

## The Observed-Run Evidence Contract (the phase's real gate)

The phase is judged on **one before/after pair of real runs**. A claim without a run ID is not evidence.

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| **BEFORE-PR** | PR run `30390832059` (2026-07-28, pre-change) | `gh run view 30390832059 --json jobs` | ✅ captured |
| **BEFORE-PUSH** | Push run `30389700235` (2026-07-28, pre-change) | `gh run view 30389700235 --json jobs` | ✅ captured |
| **AFTER-PR** | The phase's own PR, final commit — the **miss** half of FAST-06's pair | `scripts/ci/ci-run-metrics.sh --jobs 30412458437` | ✅ captured |
| **AFTER-PR-WARM** | A second run on the **same** PR, pushed only after AFTER-PR completed and its Playwright job concluded success — the **hit** half of FAST-06's pair | `scripts/ci/ci-run-metrics.sh --jobs 30413542431` | ✅ captured |
| **AFTER-NONPR** | `workflow_dispatch` on the phase branch — the demoted `admin_eval_render` and the event-gated snapshot step observed *executing* inside the phase window | `scripts/ci/ci-run-metrics.sh --jobs 30414885679` | ✅ captured |
| **AFTER-PUSH** | The push-to-`main` run of the merge commit | `scripts/ci/ci-run-metrics.sh --jobs 30466318240` | ✅ captured |
| **AFTER-DOCSONLY** | A docs-only PR cut from `main` after the merge | `gh pr checks 123` + `gh run view 30468884574 --json jobs` | ✅ captured |
| **AFTER-CANCEL** | Double-push probe on a throwaway PR branch cut from the phase branch | `gh run list --branch 230-09-cancel-probe --json conclusion` | ✅ captured |

**Two slots were post-merge obligations during planning.** They were subsequently captured after
the phase merged; the explanation remains so the timing constraint and the provenance of the
AFTER-PUSH and AFTER-DOCSONLY evidence are explicit:

- **AFTER-PUSH** needs a merge commit that does not exist until the phase merges.
- **AFTER-DOCSONLY** needs a pull request whose base-to-HEAD diff is Markdown-only, and no pre-merge
  pull request can be one. `ci.yml` triggers on `pull_request: branches: [main]`, so every pull
  request that runs the workflow diffs against `origin/main`; and any pull request carrying the
  `changes` job at all also carries this phase's `.github/workflows/ci.yml`, `scripts/ci/*.sh`,
  `test/example/priv/playwright/tests/admin-design.spec.ts` and `test/sigra/planning/*.exs` in that
  same diff, so the classifier emits `false`. Re-cutting from `main` does not help: such a branch runs
  the *pre-change* workflow, in which the fast path does not exist. FAST-05's in-phase evidence is
  therefore the hermetic `scripts/ci/docs-only-classify.test.sh` (both directions of the rule, plus
  the empty-input and crafted-path cases) plus the observed `docs_only=false` on AFTER-PR and on the
  AFTER-CANCEL probe — the latter is a Markdown-only commit that still classifies `false`, which is
  the impossibility observed rather than argued. The `true` branch is confirmed after merge.

**Why eight slots and not six.** Two were added during planning, each because a criterion was
otherwise unprovable inside the original phase window:

- **AFTER-NONPR** — the demotions (FAST-02, FAST-03) must be observed *executing* somewhere, not just
  absent from the PR. Waiting for AFTER-PUSH would push that observation past the phase.
- **AFTER-PR-WARM** — a brand-new cache key can only *miss* on the run that introduces it, so no
  single slot can log FAST-06's hit. A run superseded by `cancel-in-progress` is killed before
  `actions/cache`'s post-step and saves nothing; AFTER-DOCSONLY is post-merge and gates the Playwright
  lane off entirely; and AFTER-NONPR / AFTER-PUSH read `refs/heads/…` cache scopes that cannot see what a
  `pull_request` run saved under `refs/pull/<n>/merge`. Two runs on one pull request share a scope,
  and that pairing is the only one available. FAST-06 is therefore verified as an observed
  **miss-then-hit pair**, which is falsifiable in both directions.

**Evidence classes.** The per-requirement summary table plan 09 writes into `230-EVIDENCE.md` tags
every row `observed`, `proxy-observed`, `hermetic-unit` or `structural-argument`, so a
`workflow_dispatch` standing in for the nightly (SC-3), a committed self-test standing in for an
unobtainable run (FAST-05's classification rule), and the `github.run_id`-group argument (SC-1's
push-to-main half, pending AFTER-PUSH) are never skimmed as direct observations.

**Anti-pattern to reject at review:** any verification step whose command is `grep`, `cat`, or `Read`
against `ci.yml` / `admin-design.spec.ts` as the *sole* proof of a success criterion.

---

## Per-Requirement Verification Map

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| FAST-02 | Board tests carry `@snapshot`; axe tests do not; `assertBoardScreenshot` no longer calls axe | unit (static) | `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs` | ✅ | ✅ green |
| FAST-02 | PR gallery step executes **39** tests; non-PR snapshot step executes **84** | observed run | AFTER-PR `30412458437` + AFTER-NONPR `30414885679` | ✅ ledger | ✅ captured |
| FAST-02 | `admin_design_recapture` still executes **123** tests (Pitfall 1 regression guard — see correction below) | observed run | AFTER-NONPR `30414885679` | ✅ ledger | ✅ captured |
| FAST-03 | `admin_eval_render` skipped on PR, executes on push | observed run | AFTER-PR `30412458437` + AFTER-NONPR `30414885679` | ✅ ledger | ✅ captured |
| FAST-04 | Superseded PR run concludes `cancelled`; push/schedule do not | observed run | AFTER-CANCEL `30416160743` / `30416184110` | ✅ ledger | ✅ captured |
| FAST-05 | The classification rule in both directions: docs-only list → `true`; any non-docs path → `false`; empty list → `true`; crafted paths → `false` | unit (hermetic) | `bash scripts/ci/docs-only-classify.test.sh` | ✅ | ✅ green |
| FAST-05 | The classifier is wired and emits on a real run: a mixed diff yields `docs_only=false` and the full matrix executes | observed run | AFTER-PR + AFTER-CANCEL ledger entries | ✅ ledger | ✅ captured |
| FAST-05 | Docs-only PR: five required contexts merge-eligible; required fast and library checks still execute in full | observed run | AFTER-DOCSONLY `30468884574` | ✅ ledger | ✅ captured |
| FAST-05 | No required context can go pending on a docs-only PR, because all gating is at job/step level and no trigger-level path filter exists | structural (parse) | Phase-230 contract tests + AFTER-DOCSONLY evidence | ✅ | ✅ covered |
| FAST-06 | A **miss-then-hit pair** on one PR: AFTER-PR logs `cache-hit: false`, AFTER-PR-WARM logs `cache-hit: true` | observed run (×2) | AFTER-PR `30412458437` + AFTER-PR-WARM `30413542431` | ✅ ledger | ✅ captured |
| FAST-06 | Cache key version tracks the lockfile | unit (guard) | `bash scripts/ci/playwright-cache-key-guard.test.sh` | ✅ | ✅ green |
| FAST-07 | Every job in `ci.yml` declares `timeout-minutes` | unit (static) | `mix test test/sigra/planning/phase_230_ci_timeouts_test.exs` | ✅ | ✅ green |
| SC-5 / D-21 | Measurement script reproduces the baseline table shape; clamps negatives; explicit p50 | unit (hermetic) | `bash scripts/ci/ci-run-metrics.test.sh` | ✅ | ✅ green |
| all | `ci.yml` contract tests still pass after the edits | unit (regression) | Phase-230 targeted contract suite + `actionlint -shellcheck= .github/workflows/ci.yml` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green (current automated check) · ✅ captured (named CI-run evidence) · ✅ covered (structural check plus observed evidence) · ❌ red · ⚠️ flaky*

> Per-task IDs are bound at execution time; the planner maps each task to a row above via its
> `<acceptance_criteria>`.

---

## Wave 0 Requirements

- [x] `scripts/ci/ci-run-metrics.sh` + `scripts/ci/ci-run-metrics.test.sh` — D-21 measurement script, wired into `fast_checks`
- [x] `scripts/ci/playwright-cache-key-guard.sh` + `.test.sh` — FAST-06 version-drift guard (RESEARCH Pitfall 6)
- [x] `scripts/ci/docs-only-classify.sh` + `.test.sh` — FAST-05 classifier, wired into `fast_checks`; its post-merge docs-only branch is captured in AFTER-DOCSONLY
- [x] A `timeout-minutes` completeness assertion — every `runs-on:` in `ci.yml` has a sibling `timeout-minutes:`
- [x] A `@snapshot` tag-integrity assertion — board tests tagged and behavior/accessibility tests untagged
- [x] The D-23 honest-skip artifact — documented in `MAINTAINING.md` and verified by plan 08

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

*All phase behaviors have automated verification.* The eight observed-run slots are **automated
commands** (`gh run view` / `gh pr checks` / `scripts/ci/ci-run-metrics.sh`) whose precondition is a
real CI run — they require no human judgment, only that the run exists. This preserves the
zero-human-UAT posture: the operator triggers runs, the evidence is machine-read.

**Known observability limit (RESEARCH Open Question 4):** a green `schedule` observation may be
unobtainable in this phase — the nightly is 0-pass/9-fail and that is GATE-01's problem in Phase 231.
SC-3's schedule half is therefore proven by a `workflow_dispatch` proxy **plus** the structural
`run_id`-group argument (D-12), stated explicitly rather than claimed as an observed nightly.

---

## Correction — recapture executed-test count (120 → 123)

`230-RESEARCH.md` records **120** as the expected `admin_design_recapture` executed-test count, and
this file originally carried that figure. **120 is the *pre*-change inventory.** Plan `230-02` adds
one full-page WCAG test declaration, which executes once per design project (41 × 3 = **123**).

**Operative value: 123.** Asserting 120 after the change would produce a false red. Plans `230-03`
and `230-09` carry 123 with the arithmetic inline. RESEARCH.md's 120 is superseded by this note.

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

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all formerly missing references
- [x] No watch-mode flags
- [x] Feedback latency < 30s for the static/unit layer
- [x] All eight observed-run slots captured with verbatim run IDs
- [x] AFTER-DOCSONLY records the required `docs_only=true` observation; the pre-merge impossibility note above remains historical context
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated validation complete (2026-08-04)

## Validation Audit 2026-08-04

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Current verification: `ci-run-metrics.test.sh` (9 passed), `docs-only-classify.test.sh`
(11 passed), `playwright-cache-key-guard.test.sh` (8 passed), the two Phase-230 ExUnit contract
files (12 tests, 0 failures), and `actionlint -shellcheck= .github/workflows/ci.yml` all passed.

## Validation Audit 2026-08-04 (Phase 236 canonical reconciliation)

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Canonical validator re-audit completed from Phase 236: the retained deterministic Phase-230
coverage passed (`ci-run-metrics.test.sh` 9/0, `docs-only-classify.test.sh` 11/0,
`playwright-cache-key-guard.test.sh` 8/0, two Phase-230 ExUnit contracts 12/0, and
`actionlint -shellcheck= .github/workflows/ci.yml`). Existing observed-run evidence was retained;
no GitHub evidence was queried or recaptured. The Phase 236 immutable-evidence contract also passed
(3 tests, 0 failures).
