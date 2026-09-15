---
phase: 232
slug: playwright-economics-authenticate-once-then-shard
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-31
revised: 2026-07-31
---

# Phase 232 — Validation Strategy

> Per-phase validation contract synchronized to plans 232-01 through 232-07. Structural checks provide fast feedback; ordered GitHub-hosted observations are blocking evidence gates, not substitutes for local contracts.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit planning contracts, Playwright 1.59.1, and observed GitHub Actions runs |
| **Config files** | `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |
| **Quick run command** | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` |
| **Full structural command** | `mix test test/sigra/planning/` |
| **Playwright inventory command** | `cd test/example/priv/playwright && npx playwright test --list --retries=0` |
| **Estimated runtime** | Quick structural feedback under 30 seconds; GitHub observations depend on runner availability |

## Sampling Rate

- **After every code-producing task:** run the focused Phase 232 ExUnit contract.
- **After every implementation wave:** run `mix test test/sigra/planning/`; when Playwright config or commands change, also run the retry-zero Playwright inventory command for the affected projects.
- **At Waves 2 and 6:** stop at the blocking observation checkpoint. Execution cannot sample a later topology until the required real-run evidence is supplied and passes.
- **Before `$gsd-verify-work`:** the focused/planning suites must be green and all four ordered evidence slots must be captured in `232-EVIDENCE.md`.
- **Max local feedback latency:** 30 seconds for the focused contract. Long GitHub observations are explicitly isolated as manual evidence gates.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat / ASVS | Sampling mode | Automated command or evidence command | Manual/evidence gate | Wave 0 dependency | Status |
|---------|------|------|-------------|---------------|---------------|---------------------------------------|----------------------|-------------------|--------|
| 232-01-01 | 01 | 1 | PW-01 | T-232-01/02/03; V2/V3/V4 | RED→GREEN structural + Playwright inventory | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && cd test/example/priv/playwright && npx playwright test --list --project=admin-design-chromium --retries=0` | Initialize `BEFORE-PW-01` from run `30390832059`; preserve command/output and counts | **Creates first:** structural test and evidence ledger | ⬜ pending |
| 232-01-02 | 01 | 1 | PW-01 | T-232-01/02/03; V2/V3/V4 | RED→GREEN expansion + three-project inventory | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && cd test/example/priv/playwright && npx playwright test --list --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --retries=0` | Compare all three project/list counts to the BEFORE receipt | Uses artifacts created by 232-01-01 | ⬜ pending |
| 232-02-01 | 02 | 2 | PW-01 | T-232-04; V2/V3/V4 | blocking observed-CI checkpoint | `gh run view <after-pw01-run-id> --json databaseId,event,headSha,conclusion,jobs` | Require successful retry-zero, count-identical PW-01-only run on pre-shard topology; record BEFORE and AFTER IDs | Evidence ledger exists from 232-01-01 | ⬜ pending |
| 232-03-01 | 03 | 3 | PW-01 | T-232-05; V2/V3/V4 | structural + observed receipt capture | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && bash scripts/ci/ci-run-metrics.sh --jobs <before-run-id> && bash scripts/ci/ci-run-metrics.sh --jobs <after-pw01-run-id>` | Seal `AFTER-PW-01`; stop on count, retry, or topology discrepancy | Structural test and ledger already exist | ⬜ pending |
| 232-04-01 | 04 | 4 | PW-03 | T-232-06/07; V2/V3/V4 | RED structural consumer contract | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | Contract must literally enumerate `example_playwright_smoke`, `admin_design_recapture`, `admin_checkpoint_recapture`, and `admin_eval_render` | Extends structural test created in 232-01-01, after PW-01 receipt is sealed | ⬜ pending |
| 232-04-02 | 04 | 4 | PW-03 | T-232-06/07; V2/V3/V4 | GREEN structural + planning regression | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && mix test test/sigra/planning/` | One shared action owns the prelude; all four consumers use it and preserve gates/services/commands | Failing consumer contract from 232-04-01 | ⬜ pending |
| 232-05-01 | 05 | 5 | PW-02, PW-03 | T-232-08/09/10; V2/V3/V4 | RED structural shard contract | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | Contract must literally enumerate five rows: `admin_behavior`, `admin_checkpoints`, `design_gallery`, `non_admin_smoke`, `demo_showcase` | Extends structural test after shared action exists | ⬜ pending |
| 232-05-02 | 05 | 5 | PW-02, PW-03 | T-232-08/09/10; V2/V3/V4 | GREEN structural + planning + complete inventory | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && mix test test/sigra/planning/ && cd test/example/priv/playwright && npx playwright test --list --retries=0` | Preserve event-specific design snapshot routing; exact-name aggregator must fail closed over every shard result | Failing shard contract from 232-05-01 | ⬜ pending |
| 232-06-01 | 06 | 6 | PW-02, PW-03 | T-232-11; V2/V3/V4 | blocking observed PR/non-PR checkpoint | `gh run view <after-shard-pr-run-id> --json databaseId,event,headSha,conclusion,jobs && gh pr checks <pr-number> && gh run view <after-shard-nonpr-run-id> --json databaseId,event,headSha,conclusion,jobs` | Require overlapping successful retry-zero shards, exact required context, and successful execution of all four shared-boot consumers across qualifying runs | Plans 04-05 structural contracts green | ⬜ pending |
| 232-07-01 | 07 | 7 | PW-01, PW-02, PW-03 | T-232-12/13; V2/V3/V4 | final structural + observed evidence seal | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && mix test test/sigra/planning/ && gh pr checks <pr-number>` | Capture `AFTER-SHARD-PR` and `AFTER-SHARD-NONPR`; map each requirement to structural and observed evidence separately | All prior evidence IDs and summaries available | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements and Creation Order

Wave 0 is fulfilled inside the leading tracer before later tasks consume its artifacts:

1. **232-01-01 first creates** `test/sigra/planning/phase_232_playwright_economics_test.exs` with the chromium RED contract, then turns it GREEN. Tasks 232-01-02, 232-04-01, and 232-05-01 expand this same non-vacuous test only after it exists.
2. **232-01-01 first creates** `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` and captures `BEFORE-PW-01`. Plans 232-02/03 cannot proceed without that ledger; plans 232-06/07 append later ordered slots.
3. No production implementation task relies on a missing test scaffold. The only placeholders in commands are real GitHub run/PR IDs supplied at the explicit blocking checkpoints.
4. Set `wave_0_complete: true` only after 232-01-01 commits both files and its focused command passes.

## Evidence Gate Contract

| Gate | Opens after | Required proof | Blocks |
|------|-------------|----------------|--------|
| BEFORE-PW-01 | 232-01-01 | Baseline run `30390832059` (or justified same-topology replacement), exact commands, design duration and coverage counts | PW-01 comparison |
| AFTER-PW-01 | 232-02-01 | Successful PR run containing PW-01 only, pre-shard topology, `--retries=0`, identical assertion/snapshot/project counts | Every PW-02/PW-03 topology edit |
| AFTER-SHARD-PR | 232-06-01 | All five seams represented; at least two non-zero successful shard intervals overlap; exact terminal context succeeds in `gh pr checks` | Final PW-02 disposition |
| AFTER-SHARD-NONPR | 232-06-01 | Event-gated snapshots/recaptures/eval execute as applicable; all four example-app-booting Playwright consumers show successful shared-action boot/readiness | Final PW-03 disposition |

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Test instructions |
|----------|-------------|------------|-------------------|
| PW-01 has an attributable receipt before topology changes | PW-01 | Requires two ordered GitHub-hosted observations | Use `gh run view --json jobs` and `scripts/ci/ci-run-metrics.sh --jobs` for BEFORE/AFTER; require identical counts and retry-zero output. |
| Isolated shards truly overlap and pass without masks | PW-02 | Workflow structure cannot prove scheduler overlap or runtime isolation | Inspect start/completion timestamps, commands, conclusions, and ownership fields for all five matrix seams. |
| Required branch-protection context resolves | PW-02 | Only a real PR checks view proves ruleset compatibility | Record `gh pr checks <pr-number>` with successful `Example Playwright smoke (full lifecycle)`. |
| Every shared-boot consumer still boots | PW-03 | Three consumers are non-PR/event-gated | On qualifying runs enumerate `example_playwright_smoke`, `admin_design_recapture`, `admin_checkpoint_recapture`, and `admin_eval_render`; record non-skipped readiness/startup success where each event gate applies. |

## Validation Sign-Off

- [x] All ten planned tasks have an `<automated>` verification command or explicit GitHub evidence command.
- [x] Every task is represented with its real plan, wave, and requirement mapping.
- [x] Sampling continuity has no three-task gap without automated feedback.
- [x] Wave 0 creation order is explicit and precedes every consumer.
- [x] No watch-mode flags or sleeps are used in validation commands.
- [x] Structural feedback target is under 30 seconds; long observations are blocking evidence gates.
- [x] ASVS L1 with high-severity blocking is sampled through V2/V3/V4 mappings in every plan threat model.

**Approval:** ready for execution, with Wave 0 completed by task 232-01-01.
