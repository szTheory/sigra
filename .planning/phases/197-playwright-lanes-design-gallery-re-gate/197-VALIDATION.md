---
phase: 197
slug: playwright-lanes-design-gallery-re-gate
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-20
---

# Phase 197 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a CI/test-infra phase: the artifacts under change are `.github/workflows/ci.yml`,
> Playwright specs, the example's served CSS + a woff2 asset, and a seed/SEED doc. There is no
> new application logic — every task's `<automated>` verify is a static-assertion guard
> (grep / `yaml.safe_load` / file-magic / outcome-id presence) that runs in well under 60s and
> needs no booted app. The end-to-end behavior (lane goes green, gallery hard-gates) is proven
> by the live `example_playwright_smoke` lane in CI, not by a local unit suite.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright `@playwright/test` (vendored) + bash/grep CI assertions + Python `yaml.safe_load` workflow lint + ExUnit ci.yml-slicing contract tests |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` (`workers:1, fullyParallel:false`); `.github/workflows/ci.yml` (lane under change) |
| **Quick run command** | Per-task `<automated>` verify (grep / file-magic / YAML-lint) — each <5s, no booted app. e.g. `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` |
| **Full suite command** | `cd test/example/priv/playwright && CI=true npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` (needs example booted on :4000) + the full `example_playwright_smoke` lane in CI |
| **Estimated runtime** | Per-task guards ~<5s each; full Playwright design lane ~minutes (CI-bound, serial `workers:1`) |

---

## Sampling Rate

- **After every task commit:** Run that task's `<automated>` verify (the grep/YAML/file-magic guard).
- **After every plan wave:** Re-run `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` (Waves 1-3 all touch ci.yml) + the per-plan greps.
- **Before `/gsd-verify-work`:** The `example_playwright_smoke` lane must be green in CI with the gallery hard-gating (no `continue-on-error`), and `mix test test/sigra/install/phase_58_oauth_oa01_ci_contract_test.exs` (if present) green.
- **Max feedback latency:** ~5s for static guards; the true cross-lane signal is CI-bound (the lane itself).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 197-01-01 | 01 | 1 | PW-02 | — | No fixed sleep masks readiness; explicit poll only | static-grep | `cd test/example/priv/playwright && grep -c 'waitForTimeout' tests/organizations.spec.ts \| grep -qx 0 && grep -q 'expect' tests/organizations.spec.ts && echo PASS` | ✅ | ⬜ pending |
| 197-01-02 | 01 | 1 | PW-02 | — | No fixed sleep anywhere in tests/ | static-grep | `cd test/example/priv/playwright && grep -rc 'waitForTimeout' tests/ \| grep -v ':0$' \| grep -qv . && echo PASS-NO-SLEEPS-REMAIN` | ✅ | ⬜ pending |
| 197-02-01 | 02 | 1 | PW-01 | T-197-03 | Each seam runs after a prior failure (no early-abort mask) | static-grep | `grep -cE 'if: \$\{\{ !cancelled\(\) \}\}' .github/workflows/ci.yml \| awk '$1>=5{print "PASS"; exit} {exit 1}'` | ✅ | ⬜ pending |
| 197-02-02 | 02 | 1 | PW-01 | T-197-03 / T-197-04 | Aggregator re-fails job on any seam failure (no silent green) | static-grep | `grep -q 'Aggregate Playwright step outcomes' .github/workflows/ci.yml && grep -q "steps.admin_checkpoints.outcome == 'success'" .github/workflows/ci.yml && grep -Eq 'steps\.demo_showcase\.outcome' .github/workflows/ci.yml && echo PASS` | ✅ | ⬜ pending |
| 197-03-01 | 03 | 1 | PW-03 | T-197-07 | Brand woff2 is in-repo provenance (no CDN fetch) | file-magic | `test -f test/example/priv/static/assets/fonts/space-grotesk-var.woff2 && head -c4 test/example/priv/static/assets/fonts/space-grotesk-var.woff2 \| grep -q 'wOF2' && echo PASS` | ❌ W0 (created by task) | ⬜ pending |
| 197-03-02 | 03 | 1 | PW-03 | — | Served `--font-sans` routes to brand font OS-independently | static-grep | `grep -q "space-grotesk-var.woff2" test/example/priv/static/assets/css/app.css && grep -q "font-family: 'Space Grotesk'" test/example/priv/static/assets/css/app.css && grep -q -- "--font-sans" test/example/priv/static/assets/css/app.css && echo PASS` | ✅ | ⬜ pending |
| 197-03-03 | 03 | 1 | PW-03 | T-197-06 | Capture waits for font + fails loudly if face absent | static-grep | `grep -q 'fonts.ready' test/example/priv/playwright/tests/admin-design.spec.ts && grep -q "fonts.check('16px \"Space Grotesk\"')" test/example/priv/playwright/tests/admin-design.spec.ts && echo PASS` | ✅ | ⬜ pending |
| 197-03-04 | 03 | 1 | PW-03 | T-197-08 | No spurious-pass `test.fail()`; skip-with-reason default | static-grep | `grep -q 'test.fail()' test/example/priv/playwright/tests/admin-design.spec.ts && exit 1 \|\| echo PASS` | ✅ | ⬜ pending |
| 197-04-01 | 04 | 2 | PW-03 | T-197-09 | Recapture write-perm scoped to job, non-PR-gated | grep+yaml | `grep -q 'admin_design_recapture' .github/workflows/ci.yml && grep -q 'contents: write' .github/workflows/ci.yml && grep -q -- '--update-snapshots' .github/workflows/ci.yml && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo PASS` | ✅ | ⬜ pending |
| 197-04-02 | 04 | 2 | PW-03 | T-197-10 / T-197-11 | Reviewable PR commit; canary re-baselined as `added`, allowlist stays empty | grep+yaml | `grep -q 'snapshot-canary-guard.sh' .github/workflows/ci.yml && grep -Eq 'skip ci\|gh pr create\|ci/recapture' .github/workflows/ci.yml && grep -vc '^#' test/example/priv/playwright/snapshot-allowlist-design \| grep -qx 0 && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo PASS` | ✅ | ⬜ pending |
| 197-04-03 | 04 | 2 | PW-03 | — | Cross-lane drift compared-and-reported; shift → tracked todo (bounded scope, no unscoped recapture) | yaml-lint | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo PASS` | ✅ | ⬜ pending |
| 197-05-01 | 05 | 3 | PW-03 | — | Gallery hard-gates again (no `continue-on-error` on design step) | grep+yaml | `! grep -n 'continue-on-error' .github/workflows/ci.yml \| grep -qi 'design\|gallery'; grep -A40 'Run design gallery boards' .github/workflows/ci.yml \| grep -q 'design_gallery' && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo PASS` | ✅ | ⬜ pending |
| 197-05-02 | 05 | 3 | PW-03 | — | SEED-006 false-premise corrected (operator truth) | static-grep | `grep -qi 'system' .planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md && grep -qi 'correct' .planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*"File Exists" column: ✅ = the asserted file already exists in the tree; ❌ W0 = the file is created by the task itself (197-03-01 generates the woff2 — its absence pre-task is expected, not a missing test fixture).*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. This is a CI/test-infra phase with no new
test framework: every task verifies via static assertion against the file it edits (grep / file-magic /
`yaml.safe_load`), and the behavioral end-to-end signal is the existing `example_playwright_smoke`
Playwright lane + the existing ExUnit ci.yml-slicing contract tests (`phase_58_*`). No Wave-0 test
scaffold needs creating. (197-03-01's woff2 is a build artifact the task produces, not a missing test
stub — its `<automated>` verify asserts the artifact it just generated.)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The lane actually surfaces all 5 seam failures in one run, and the aggregator re-reds the job | PW-01 | Requires a real GitHub Actions run (multi-step outcome interplay can't be unit-asserted from the YAML alone) | Push a branch with an intentionally-failing early seam; confirm later seams still ran and the "Aggregate Playwright step outcomes" step turned the job red |
| Recaptured admin-design baselines render identically in ubuntu CI vs local after the font lands | PW-03 | Recapture job is non-PR-gated and commits PNGs; full proof is a `workflow_dispatch`/scheduled run producing the `ci/recapture-*` PR | Trigger the recapture job; review the opened PR's PNG diff; confirm the design lane is green on the recapture branch |
| The re-gated gallery hard-gates green on the PR path | PW-03 | Needs a PR-event CI run with the recaptured baselines merged | After recapture PR merges, open a no-op PR; confirm `Run design gallery boards` runs without `continue-on-error` and the lane is green |

*These are inherent to a CI-lane phase: the static guards prove the YAML/spec/CSS edits are correct;
only a live Actions run proves the multi-job/multi-seam runtime behavior. This is the deliberate
zero-local-human-UAT posture — verification is shifted into CI, not onto a human reviewer.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (all 13 tasks have inline `<automated>` guards)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has one)
- [x] Wave 0 covers all MISSING references (none — existing infra + per-task static guards)
- [x] No watch-mode flags (all guards are one-shot grep/file-magic/YAML-lint)
- [x] Feedback latency < 5s for static guards (CI-bound for the live lane signal)
- [x] `nyquist_compliant: true` set in frontmatter

**Coverage rationale:** Nyquist compliance here is satisfied by each task's inline `<automated>` verify
plus the RESEARCH §Validation Architecture map and the live `example_playwright_smoke` lane. There is no
new application code path that needs a dedicated unit; the static guards sample every edit, and the
behavioral signal is the CI lane itself (see Manual-Only Verifications for what is necessarily CI-bound).

**Approval:** approved 2026-06-20
