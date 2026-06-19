---
phase: 193
slug: baseline-observability-one-line-wins
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-19
---

# Phase 193 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Phase 193's verification model is "CI measures itself" (zero-human-UAT): the
> deliverables are a committed baseline artifact, additive CI observability steps,
> one `needs:` edge removal, and one de-flaked Playwright assertion.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library, ~274 `*_test.exs`) + Playwright (`test/example/priv/playwright`) |
| **Config file** | `mix.exs` (ExUnit) / `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example/priv/playwright && npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --retries=0` (FLAKE-01) |
| **Full suite command** | `mix test` (library) ; the CI `example_playwright_smoke` lane (CRIT-01 / FLAKE-01 in-CI) |
| **Estimated runtime** | ~30–90s for the targeted Playwright spec; full library `mix test` minutes |

---

## Sampling Rate

- **After every task commit:** For FLAKE-01, run the quick command above **with `--retries=0`** — it must pass with retries OFF. For YAML/artifact tasks, run `actionlint`/`yamllint` or a `gh workflow` dry parse where available.
- **After every plan wave:** Confirm `ci.yml` still parses and required-check names (`ci-gate` + its `needs:` children) are unchanged.
- **Before `/gsd-verify-work`:** One full CI run post-merge must show (a) wall-clock dropped toward `library_tests` time, (b) run summary surfaces versions/cache/timing, (c) demo-showcase green with no retry, (d) baseline artifact committed.
- **Max feedback latency:** < 90 seconds for the targeted spec; CI timing facts confirmed via `gh run view --json jobs`.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| BASE-01 | baseline | 1 | BASE-01 | — | N/A | artifact check | `test -f .planning/phases/193-*/193-BASELINE.md && grep -qi "critical path" .planning/phases/193-*/193-BASELINE.md` | ❌ W0 (artifact is the deliverable) | ⬜ pending |
| BASE-02 | baseline | 1 | BASE-02 | — | N/A | artifact check | `grep -Eq "slowest|schedulers_online" .planning/phases/193-*/193-BASELINE.md` | ❌ W0 | ⬜ pending |
| BASE-03 | observability | 2 | BASE-03 | T-CI-config | Echo only resolved versions/step-outputs; no untrusted `github.event.*` interpolation | source assertion | `grep -q "GITHUB_STEP_SUMMARY" .github/workflows/ci.yml` | ❌ W0 (new CI steps) | ⬜ pending |
| CRIT-01 | observability | 2 | CRIT-01 | T-CI-config | Lane stays in `ci-gate.needs` (still required) | CI timing | next CI run: `example_playwright_smoke` start ≈ `release_ref_guard` end (not after `library_tests`); `gh run view --json jobs` | ✅ measured | ⬜ pending |
| FLAKE-01 | deflake | 1 | FLAKE-01 | — | N/A | Playwright | `cd test/example/priv/playwright && npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --retries=0` (repeated) | ✅ demo-showcase.spec.ts:885-887 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` — the BASE-01/BASE-02 deliverable artifact (does not exist yet).
- [ ] `$GITHUB_STEP_SUMMARY` summary steps + `id:` on `actions/cache` steps in `ci.yml` (BASE-03 — none exist today).
- [ ] Move `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` → `completed/` once FLAKE-01 is done.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Run-summary rendering on the GitHub Actions UI | BASE-03 | The rendered summary panel is only visible on github.com after a real run; the source assertion (`grep GITHUB_STEP_SUMMARY`) proves the step exists, not how it renders | After merge, open the latest CI run → confirm a "Summary" panel shows resolved Elixir/OTP versions, cache hit/miss, and slowest-tests |

*All other phase behaviors have automated verification (artifact checks, source greps, `gh run view --json`, retries=0 Playwright).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
