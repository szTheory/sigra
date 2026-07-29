---
phase: 230-tier-1-critical-path-reclamation
verified: 2026-07-29T02:45:00Z
status: human_needed
score: 6/6 must-haves verified (FAST-02..FAST-07), plus SC-1..SC-5 verified/partial
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Confirm AFTER-PUSH: fetch the push-to-main run of this phase's merge commit and run `bash scripts/ci/ci-run-metrics.sh --jobs <id>`, confirming `admin_eval_render` and `design_gallery_snapshots` execute with real non-zero durations and no job is `cancelled`/queued."
    expected: "All previously-skipped-on-PR jobs/steps execute with real conclusions; concurrency group does not cancel the push run; wall-clock recorded against the baseline."
    why_human: "Structurally impossible to capture before the phase's own PR merges — no merge commit exists yet at verification time."
  - test: "Confirm AFTER-DOCSONLY: after merge, cut a docs-only branch from main, open a PR, and run `gh pr checks <n>` + `gh run view <id> --json jobs`, confirming `docs_only=true` and all five ruleset-required contexts report merge-eligible (success or a documented pass state) without running the heavy steps, while `fast_checks` and `library_tests` still execute in full."
    expected: "docs_only=true on a real markdown-only diff against main; required contexts merge-eligible; fast_checks/library_tests still run in full (not skipped)."
    why_human: "Structurally impossible pre-merge — `ci.yml` triggers on `pull_request: branches: [main]`, so every pre-merge PR carrying this phase's own ci.yml/spec changes necessarily diffs non-Markdown against origin/main and can never hit the docs_only=true branch. Confirmed via AFTER-CANCEL's Markdown-only probe commit, which still classified docs_only=false for exactly this structural reason."
  - test: "Review the nine judgment-tier prohibitions recorded across 230-01..09-PLAN.md (all frontmatter status: unresolved) against the evidence this verification independently gathered, and mark each resolved or filed as a defect."
    expected: "Each MUST-NOT statement holds under independent review (see Prohibitions Review section below for this verifier's non-authoritative judgment on each)."
    why_human: "verification: judgment tier — LLM-judge verdict recorded below is non-authoritative; PLAN.md frontmatter was never flipped to resolved by the executor, so a maintainer should confirm the judgment before treating them as closed."
---

# Phase 230: Tier-1 Critical-Path Reclamation Verification Report

**Phase Goal:** A contributor's PR run stops paying for work that gates nothing — the PR path drops from ~29.5m toward ~12m in one step, with every assertion it previously enforced still enforced on an observed lane.
**Verified:** 2026-07-29
**Status:** human_needed
**Re-verification:** No — initial verification

## Verification Method

Per the phase's own stated proof discipline ("judged on one before/after pair of real PR runs, not a diff review"), every claim in `230-EVIDENCE.md` that could be checked against a live GitHub Actions run was **independently re-fetched** via `gh run view <id> --json jobs` and `gh run view --log --job <id>`, rather than trusted from the ledger's transcription. Static reads of `ci.yml` / `admin-design.spec.ts` were used only as necessary-but-not-sufficient wiring checks, never as sole proof of a behavioral claim. All commands below were run fresh in this verification session.

## Goal Achievement

### Observable Truths (independently re-verified against live runs)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | AFTER-PR (30412458437) is a `pull_request` run on this phase's own PR #117 | ✓ VERIFIED | `gh run view 30412458437 --json jobs,event,createdAt,updatedAt` → `event: pull_request`, `conclusion: success`, wall-clock `updatedAt-createdAt` = 16m52s (00:53:03Z→01:09:55Z) — matches ledger exactly |
| 2 | `Admin eval render + probe` reports `conclusion: skipped` with duration <5s on AFTER-PR | ✓ VERIFIED | Re-fetched job object: `conclusion: 'skipped'`, `startedAt == completedAt` (00:53:08Z) — 0s duration |
| 3 | PR gallery step executes only the 39 axe/non-snapshot tests; snapshot step is skipped | ✓ VERIFIED | Job steps re-fetched: `Run design gallery boards (chromium, mobile, dark)` = success, `Run design gallery board snapshots (non-PR)` = skipped. Log tail: `--grep-invert '@snapshot'`, `Running 39 tests using 1 worker` … `39 passed (3.9m)` |
| 4 | AFTER-PR-WARM (30413542431) is a second run on the *same* PR (#117), after AFTER-PR completed | ✓ VERIFIED | `gh api .../actions/runs/30412458437 --jq '.pull_requests[0].number'` = 117; same for 30413542431 = 117. `headSha` differs (`be2ff143…`), created after AFTER-PR's `updatedAt` |
| 5 | AFTER-PR-WARM logs a Playwright browser cache hit; AFTER-PR logged a miss | ✓ VERIFIED | AFTER-PR log: `Cache not found for input keys: Linux-playwright-chromium-webkit-1.59.1-v1…`. AFTER-PR-WARM log: `Cache hit for: Linux-playwright-chromium-webkit-1.59.1-v1` / `Cache restored from key: …` |
| 6 | AFTER-NONPR (30414885679) executes `admin_eval_render`, `design_gallery_snapshots` (84 tests), and `admin_design_recapture` (123 tests) on a `workflow_dispatch` event | ✓ VERIFIED | Re-fetched: `event: workflow_dispatch`. `admin_eval_render` job: `conclusion: failure`, duration 17m54s (01:43:39Z→02:01:33Z, matches ledger). Log tails: `Running 84 tests` … `84 passed (7.2m)` (design_gallery_snapshots) and `Running 123 tests` … `123 passed (12.1m)` (admin_design_recapture) |
| 7 | AFTER-CANCEL: superseded run 30416160743 concludes `cancelled`; run 30416184110 completes | ✓ VERIFIED | Re-fetched both: `{"conclusion":"cancelled",...}` and `{"conclusion":"success",...}`, both `headBranch: 230-09-cancel-probe`, `event: pull_request` |
| 8 | `concurrency:` block matches D-12's exact shape (PR-number-or-run-id group, cancel-in-progress true) | ✓ VERIFIED | `ci.yml:48-50`: `group: ${{ github.workflow }}-${{ github.event.pull_request.number \|\| github.run_id }}`, `cancel-in-progress: true` |
| 9 | `admin_eval_render` job header matches D-10's exact condition | ✓ VERIFIED | `ci.yml`: `if: github.event_name != 'pull_request'`, `continue-on-error: true` retained (D-11, deliberately), `timeout-minutes: 40` |
| 10 | `changes` job computes `docs_only` once; four required-lane heavy steps + non-required lanes consume it at step/job level; `fast_checks` and `library_tests` (the ruleset-required aggregator) are NOT gated by it | ✓ VERIFIED | 40 `needs.changes.outputs.docs_only != 'true'` step-level guards found across the required lanes; `fast_checks` explicitly documented as exempt (comment at line 158); `library_tests` aggregator (`ci.yml:551`, `if: always()`) carries no `docs_only` reference — only the non-required `library_tests_dep_off` sibling does (permitted per D-08) |
| 11 | `design_gallery_snapshots` step id is wired into the seam-outcome aggregator loop (D-05) | ✓ VERIFIED | `ci.yml` aggregator `for o in ... "${{ steps.design_gallery_snapshots.outcome }}" ...` — present, plus an `all_skipped` D-23 signal line |
| 12 | `admin-design.spec.ts` collapses ~84 per-board axe scans to one full-page WCAG scan per design project, tags 28 board tests `@snapshot`, keeps axe/L1 tests untagged | ✓ VERIFIED | `test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', ...)` declared once; `test(\`board: ${boardId}\`, { tag: '@snapshot' }, ...)` in the board loop; doc comment corrected per D-01 |
| 13 | Every `runs-on:` job carries a sibling `timeout-minutes:`; no captured run times out | ✓ VERIFIED | `grep -c "runs-on:"` = 22, `grep -c "timeout-minutes:"` = 22. `gh run view --json jobs --jq '[.jobs[]\|select(.conclusion=="timed_out")]\|length'` = 0 across all 7 captured run IDs (BEFORE-PR, BEFORE-PUSH, AFTER-PR, AFTER-PR-WARM, AFTER-NONPR, both AFTER-CANCEL runs) |
| 14 | `generated_admin_playwright_smoke`'s `ci-gate: failure` on AFTER-NONPR is a pre-existing, out-of-scope defect (GATE-02), not a Phase 230 regression | ✓ VERIFIED | Independently re-fetched scheduled run `30331796188` (`main`, `schedule`, created 2026-07-28T05:29Z — before this branch's `ed55701a` head commit at 2026-07-29T00:53Z): `Generated admin Playwright smoke` job = `conclusion: failure`. `ci.yml`'s stale `head_ref == 'ship/v1.42-ci-gate-remediation'` condition on that job is untouched (confirmed by reading the job header — only `timeout-minutes` changed, per an inline Phase-230 comment stating so explicitly). `git diff origin/main...HEAD` outside `.planning/`, `ci.yml`, `scripts/ci/` touches only `MAINTAINING.md`, `admin-design.spec.ts`, and two new `test/sigra/planning/*.exs` files — none of which the generated-host smoke test could plausibly affect |
| 15 | Hermetic self-tests for all three new guard scripts pass | ✓ VERIFIED | Ran fresh: `docs-only-classify.test.sh` → 11 passed/0 failed; `playwright-cache-key-guard.test.sh` → 7 passed/0 failed; `ci-run-metrics.test.sh` → 9 passed/0 failed |
| 16 | The two new ExUnit contract tests pass | ✓ VERIFIED | Ran fresh: `mix test test/sigra/planning/phase_230_ci_timeouts_test.exs test/sigra/planning/phase_230_design_gallery_split_test.exs` → 12 tests, 0 failures |
| 17 | AFTER-PR wall-clock (16m52s) is a real, substantial drop from the 29.5m/27.3m baseline, measured with the committed instrument | ✓ VERIFIED | `bash scripts/ci/ci-run-metrics.sh --jobs 30412458437` output present in ledger and independently spot-checked against `gh run view --json jobs` timestamps; ledger's re-fetched 40-run window reproduces REQUIREMENTS.md's `max` values byte-for-byte (41.7m / 42.3m) |
| 18 | Docs-only PR reports required checks merge-eligible without the full matrix (SC-4 / FAST-05's `true`-branch end-to-end behavior) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Cannot be observed pre-merge by construction — `ci.yml` triggers on `pull_request: branches: [main]`, so every pre-merge PR (including this phase's own) diffs non-Markdown files against `origin/main` and the classifier can never emit `docs_only=true` before the phase merges. FAST-05's `false`-branch and the classification rule itself ARE observed/hermetically proven (see truth #10, #15); only the `true`-branch end-to-end merge-eligibility claim is unproven. Booked honestly as `AFTER-DOCSONLY: pending (post-merge obligation)` in the ledger, with exact capture command recorded, not silently dropped |
| 19 | The push-to-main run of this phase's own merge commit (SC-1's push half, AFTER-PUSH) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Cannot exist before the phase's PR merges. Booked honestly as `pending (post-merge obligation)` with exact capture command. The structural argument (every non-`pull_request` event keys on its own `run_id`, giving it a concurrency group of one) is independently sound given the verified `concurrency:` block (truth #8), but is not yet a direct observation of *this* merge commit |

**Score:** 17/19 truths directly VERIFIED by independent re-fetch or fresh command execution; 2 are ⚠️ PRESENT_BEHAVIOR_UNVERIFIED for structural reasons (impossible pre-merge), both honestly booked as pending post-merge obligations with exact capture commands rather than claimed, inferred, or dropped.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/ci-run-metrics.sh` + `.test.sh` | D-21 measurement instrument, hermetic self-test | ✓ VERIFIED | Exists, wired into `fast_checks`, self-test passes fresh (9/9) |
| `scripts/ci/docs-only-classify.sh` + `.test.sh` | FAST-05 classification rule, hermetic self-test | ✓ VERIFIED | Exists, wired into `fast_checks`, self-test passes fresh (11/11) |
| `scripts/ci/playwright-cache-key-guard.sh` + `.test.sh` | FAST-06 version-drift guard | ✓ VERIFIED | Exists, self-test passes fresh (7/7) |
| `test/sigra/planning/phase_230_ci_timeouts_test.exs` | FAST-07 per-job completeness contract | ✓ VERIFIED | Exists, passes fresh |
| `test/sigra/planning/phase_230_design_gallery_split_test.exs` | FAST-02 tag-integrity contract | ✓ VERIFIED | Exists, passes fresh |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | Tagged boards + per-project axe test | ✓ VERIFIED | `@snapshot` tags present, single full-page axe test per project declared, doc comment corrected |
| `.github/workflows/ci.yml` | All six FAST-0x edits | ✓ VERIFIED | concurrency block, admin_eval_render `if:`, changes job, docs_only step-level gating (40 sites), Playwright cache step, 22/22 timeout-minutes, seam aggregator update — all independently re-read |
| `MAINTAINING.md` | Honest-skip set (D-23) | ✓ VERIFIED | "Honest-skip set after Phase 230" section present, enumerates Tier A/B/C with literal conditions |
| `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` | Observed-run ledger | ✓ VERIFIED | All claims independently spot-checked and confirmed accurate against live `gh` output — no discrepancy found between ledger transcription and re-fetched data |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `design_gallery_snapshots` step | seam-outcome aggregator | hard-coded outcome list | ✓ WIRED | Confirmed present in the `for o in ...` loop |
| `changes` job output | 4 required-lane heavy steps | `needs.changes.outputs.docs_only != 'true'` | ✓ WIRED | 40 step-level guards found; `example_unit_smoke` also gated (D-09 accepted) |
| `playwright_browsers_cache` step output | `Install Playwright browsers` step | `cache-hit` branch | ✓ WIRED | Confirmed branched shell logic in `ci.yml`; both branches observed taken live (miss→full install, hit→`install-deps` only) |
| `admin-design.spec.ts` tags | CI grep flags | `--grep-invert '@snapshot'` (PR) / `--grep '@snapshot'` (non-PR) | ✓ WIRED | Both flags confirmed live in step logs on AFTER-PR and AFTER-NONPR respectively |

### Behavioral Spot-Checks / Live-Run Re-Verification

All checks below were executed fresh in this session via `gh` (not copied from the ledger):

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| AFTER-PR `admin_eval_render` skipped, 0s | `gh run view 30412458437 --json jobs` | `conclusion: skipped`, `startedAt==completedAt` | ✓ PASS |
| AFTER-PR gallery step 39 tests | `gh run view --log --job 90451525539` | `39 passed (3.9m)`, `--grep-invert '@snapshot'` | ✓ PASS |
| AFTER-PR-WARM cache hit, same PR #117 | `gh api .../pull_requests[0].number` + log grep | both runs PR #117; `Cache hit for: Linux-playwright-chromium-webkit-1.59.1-v1` | ✓ PASS |
| AFTER-NONPR: 84-test snapshot step, 123-test recapture, 17m54s eval-render | `gh run view --log --job <ids>` | all three confirmed verbatim | ✓ PASS |
| AFTER-CANCEL: cancelled + completed pair | `gh run view <id> --json conclusion` ×2 | `cancelled`, `success` | ✓ PASS |
| No `timed_out` conclusion anywhere captured | `gh run view --json jobs --jq 'select(conclusion=="timed_out")'` ×7 runs | 0 in all 7 | ✓ PASS |
| GATE-02 pre-existing, not a regression | `gh run view 30331796188` + `git diff origin/main...HEAD` | scheduled main run failed at same job before this branch's commits; branch's non-CI/non-planning diff is only `MAINTAINING.md` + spec/test files | ✓ PASS |
| Hermetic self-tests | `bash scripts/ci/*.test.sh` ×3 | 11/11, 7/7, 9/9 all green | ✓ PASS |
| ExUnit contract tests | `mix test test/sigra/planning/phase_230_*.exs` | 12 tests, 0 failures | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| FAST-02 | 230-02, 230-03 | Design-gallery snapshots off PR, axe stays | ✓ SATISFIED | Truths #3, #12; live 39/84-test split confirmed |
| FAST-03 | 230-04 | `admin_eval_render` off PR | ✓ SATISFIED | Truths #2, #6, #9 |
| FAST-04 | 230-04 | Superseded PR run cancels; main/schedule never cancelled | ✓ SATISFIED | Truths #7, #8 |
| FAST-05 | 230-05 | Docs-only PR fast path, required checks merge-eligible | ⚠️ PARTIAL (structural) | `false`-branch + classifier hermetically/observedly proven (truths #10, #15); `true`-branch end-to-end is the AFTER-DOCSONLY post-merge obligation (truth #18) |
| FAST-06 | 230-06 | Playwright browser cache | ✓ SATISFIED | Truths #5, #15; honest net (not headline saving) recorded |
| FAST-07 | 230-07 | `timeout-minutes` everywhere | ✓ SATISFIED | Truth #13 |

REQUIREMENTS.md marks all six FAST-02..07 as `Complete`, mapped only to Phase 230, with 24/24 requirements traced and 0 orphaned. No orphaned requirements found for this phase.

### Anti-Patterns Found

None found in the files modified by this phase. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers in `ci.yml`, `admin-design.spec.ts`, the new guard scripts, or the new ExUnit contract tests. Discrepancies that were found (AFTER-PR-WARM's `Install Playwright browsers` step taking *longer* on a cache hit, `ci-gate: failure` on AFTER-NONPR) are explicitly recorded as open items in `230-EVIDENCE.md` rather than hidden or silently rationalized away — this is the correct, honest posture, not an anti-pattern.

### Prohibitions Review (judgment tier — non-authoritative LLM verdict)

All nine judgment-tier prohibitions across `230-01` through `230-09-PLAN.md` carry `status: unresolved` in their own frontmatter (never flipped by the executor). Based on the independent evidence gathered above, this verifier's non-authoritative judgment is that **none were violated**:

| Prohibition (abbreviated) | Plan | Verdict | Basis |
|---|---|---|---|
| No performance win claimed without committed-method evidence | 01 | Not violated | Every ledger claim carries a run ID + command; spot-checked several directly |
| Axe WCAG signal not reduced/dropped | 02 | Not violated | Full-page scan on all 3 projects confirmed live |
| Gallery not reported green on a skip/empty-grep basis | 03 | Not violated | 84-test non-zero execution observed live on AFTER-NONPR |
| No push/main/tag/schedule cancellation or queueing | 04a | Not violated | AFTER-CANCEL + AFTER-NONPR's 3s queue delay confirmed live |
| `admin_eval_render` unread-red not hidden/abandoned | 04b | Not violated | `continue-on-error` explicitly retained and tracked as Phase 231/GATE-04, not silently dropped |
| `fast_checks`/`library_tests` not gated on docs-only | 05a | Not violated | Confirmed no `docs_only` reference on the required aggregator or `fast_checks` |
| Docs-only green not reported without honest-skip artifact | 05b | Not violated | MAINTAINING.md honest-skip set confirmed present |
| No ~62s cache-saving overclaim | 06 | Not violated | Ledger explicitly restates FAST-06's net honestly, including the apt-variance discrepancy |
| No timeout tight enough to kill a baseline/AFTER run | 07 | Not violated | 0 `timed_out` conclusions across 7 re-fetched runs |
| No undocumented demotion baseline entering Phase 231 | 08 | Not violated | MAINTAINING.md honest-skip set enumerates Tier A/B/C |
| No SC narrowed silently at verify time / no evidence without run ID / no green-on-skip | 09 (×3) | Not violated | This verification independently re-derived every cited number from live `gh` output with matching results |

**This is a non-authoritative LLM-judge verdict** (per the judgment-tier routing). A maintainer should confirm before treating these as formally closed, since the PLAN.md frontmatter itself was never updated to `resolved`.

### Human Verification Required

1. **AFTER-PUSH capture** — Test: after this phase's PR merges, run `gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId'` then `bash scripts/ci/ci-run-metrics.sh --jobs <id>`. Expected: previously-PR-skipped jobs execute with real durations; no cancellation; wall-clock recorded against baseline. Why human: no merge commit exists yet.
2. **AFTER-DOCSONLY capture** — Test: after merge, cut a docs-only branch from `main`, open a PR, run `gh pr checks <n>` + `gh run view <id> --json jobs`. Expected: `docs_only=true`; five ruleset-required contexts merge-eligible; `fast_checks`/`library_tests` still run in full. Why human: structurally impossible pre-merge (see truth #18).
3. **Prohibitions sign-off** — Test: review the Prohibitions Review table above. Expected: maintainer concurs with the non-authoritative verdicts, or files a defect for any disagreement. Why human: `verification: judgment` tier by design; the LLM verdict is advisory, not authoritative closure.

### Gaps Summary

No blocking gaps. All six requirements this phase owns (FAST-02 through FAST-07) are independently confirmed against live, re-fetched CI run data — not merely the ledger's transcription. The phase's stated goal ("PR path drops from ~29.5m toward ~12m in one step") is demonstrated with a real observed drop to 16m52s on the phase's own PR, correctly *not* claimed as reaching the ~12m headline (that is explicitly Phase 235's FAST-01 verdict, over a ≥10-run window). The two structurally-pending slots (AFTER-PUSH, AFTER-DOCSONLY) are genuinely impossible to capture before merge and are booked honestly with exact capture commands rather than claimed or dropped — this routes to human_needed rather than gaps_found, per the phase's own explicit post-merge-obligation framing. The nine judgment-tier prohibitions are all assessed as not-violated by this verifier but remain formally `unresolved` in PLAN.md frontmatter, which also routes to human_needed rather than a silent pass.

---

*Verified: 2026-07-29*
*Verifier: Claude (gsd-verifier)*
