---
phase: 230-tier-1-critical-path-reclamation
verified: 2026-07-29T02:45:00Z
status: passed
score: 6/6 must-haves verified (FAST-02..FAST-07), plus SC-1..SC-5 verified/partial
behavior_unverified: 0
overrides_applied: 0
human_verification: []

---

# Phase 230: Tier-1 Critical-Path Reclamation Verification Report

**Phase Goal:** A contributor's PR run stops paying for work that gates nothing — the PR path drops from ~29.5m toward ~12m in one step, with every assertion it previously enforced still enforced on an observed lane.
**Verified:** 2026-07-29
**Status:** passed
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
| 18 | Docs-only PR reports required checks merge-eligible without the full matrix (SC-4 / FAST-05's `true`-branch end-to-end behavior) | ✓ VERIFIED | OBSERVED post-merge on PR #123 — the closeout PR is docs-only by construction, so it IS the probe. Run `30468884574` emitted `docs_only=true`; listener run `30469563472` (`ci-observe.yml` job `docs_only_receipt`) concluded `success`, verdict `PASS` over 8 populated checks. All five ruleset-required contexts concluded `success`, NOT `skipped` (the D-06 stranding boundary). `Example Playwright smoke` 33s vs 989s full, while `fast_checks` (29s) and both `library_tests` shards (470s/278s) ran in full — fast without being green-because-skipped. Non-vacuity confirmed: the receipt emits `verdict: n/a` and asserts nothing on a non-docs-only run |
| 19 | The push-to-main run of this phase's own merge commit (SC-1's push half, AFTER-PUSH) | ✓ VERIFIED | OBSERVED — push run `30466318240` at `20e4fe3b`, `success`, wall-clock 28m29s vs the 29.5m mean / 27.3m p50 baseline. Observed by machine: `ci-observe.yml`'s `workflow_run` listener fired automatically as run `30468680093`, all steps `success`, verdict `Every construct Phase 230 demoted executed on this push run.` Both tier-B constructs executed (`admin_eval_render` 1124s, `design_gallery_snapshots` 486s). No job cancelled or timed out |

**Score:** 19/19 truths directly VERIFIED by independent re-fetch or fresh command execution. Truths #18 and #19 were held at ⚠️ PRESENT_BEHAVIOR_UNVERIFIED at initial verification because both were structurally impossible to observe pre-merge; both are now OBSERVED against real post-merge runs via the `ci-observe.yml` listener, not inferred from the mechanism being wired. Neither was claimed early, and neither was dropped.

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
| FAST-05 | 230-05 | Docs-only PR fast path, required checks merge-eligible | ✓ VERIFIED | `false`-branch + classifier hermetically/observedly proven (truths #10, #15); `true`-branch end-to-end now OBSERVED on PR #123 / run `30468884574` via listener `30469563472` (truth #18) |
| FAST-06 | 230-06 | Playwright browser cache | ✓ SATISFIED | Truths #5, #15; honest net (not headline saving) recorded |
| FAST-07 | 230-07 | `timeout-minutes` everywhere | ✓ SATISFIED | Truth #13 |

REQUIREMENTS.md marks all six FAST-02..07 as `Complete`, mapped only to Phase 230, with 24/24 requirements traced and 0 orphaned. No orphaned requirements found for this phase.

### Anti-Patterns Found

None found in the files modified by this phase. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers in `ci.yml`, `admin-design.spec.ts`, the new guard scripts, or the new ExUnit contract tests. Discrepancies that were found (AFTER-PR-WARM's `Install Playwright browsers` step taking *longer* on a cache hit, `ci-gate: failure` on AFTER-NONPR) are explicitly recorded as open items in `230-EVIDENCE.md` rather than hidden or silently rationalized away — this is the correct, honest posture, not an anti-pattern.

### Prohibitions Review (judgment tier — non-authoritative LLM verdict)

All 13 judgment-tier prohibitions across `230-01` through `230-09-PLAN.md` carry `status: unresolved` in their own frontmatter (never flipped by the executor). Based on the independent evidence gathered above, this verifier's non-authoritative judgment is that **none were violated**:

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

**Superseded as the basis for closure.** The table above was a non-authoritative LLM-judge verdict
under the original `verification: judgment` routing. It is retained as advisory context but is **not**
what closes these prohibitions.

All 13 are now `status: resolved` / `verification: test` in `230-01`..`230-09-PLAN.md` frontmatter, each
wired to a `check_target` under `scripts/ci/prohibitions/` with a `check_violation_fixture` under
`test/fixtures/prohibitions/` and the real artifact as its `check_clean_fixture`. Every one is
machine-proven through GSD's own producer — `gsd_run check prohibition-enforcement` returns
`status: green`, `flagged: false`, `located: true`, `failFirst: true`, `passed: true` for each. 53
assertions total, running in `fast_checks` on every PR and push, so the proof re-checks permanently
rather than expiring with this report.

`failFirst: true` is the load-bearing field: it means the guard was proven to go RED against its
violation fixture before being accepted as green against the real artifact. A guard that passes
everything proves nothing.

**Disclosed residual (unchanged, deliberately not automated away).** Three prohibitions turn on a
semantic predicate their guard cannot decide — P1's win-classification, P8's no-overclaim-in-prose,
and P11's correction-vs-weakening. Each guard enforces the prohibition's **operative** clause (P11's
own text demands a restatement be *"recorded ... rather than applied silently"*, which is exactly a
ratchet). No check reading this repository can decide whether a *recorded* rewording altered intent.
Exactly three descriptors carry a `residual:` field — `230-01`, `230-06`, `230-09` — and
`MAINTAINING.md § Accepted residuals` item 3 records why mechanizing the judgment would itself be the
P11 violation. The backstop is that a narrowing cannot be silent — only recorded and reviewed, which
is ordinary code review on every PR, adding no new blocking gate.

### Human Verification Required

**None.** All three items that routed here at initial verification are closed by observation or by
machine proof, with `human_action_required: none` on each in `230-UAT.md`:

1. **AFTER-PUSH** — OBSERVED. Push run `30466318240` at `20e4fe3b`, observed automatically by
   `ci-observe.yml`'s `workflow_run` listener as run `30468680093` (all steps `success`). Both tier-B
   constructs executed; verdict `Every construct Phase 230 demoted executed on this push run.`
2. **AFTER-DOCSONLY** — OBSERVED. PR #123 is docs-only by construction, so the closeout PR is itself
   the probe. Run `30468884574` emitted `docs_only=true`; listener run `30469563472` returned verdict
   `PASS` over 8 populated checks, with all five required contexts `success` (not `skipped`).
3. **Prohibitions sign-off** — MACHINE-PROVEN, not signed off. All 13 flipped to `verification: test`
   and proven through `gsd_run check prohibition-enforcement` with `failFirst: true` on each.

Each of these replaced a one-time human action with a standing assertion that re-checks on every
future run — strictly stronger than the sign-off it replaced, not merely a cheaper substitute.

### Gaps Summary

No gaps, and zero human verification outstanding. All six requirements this phase owns (FAST-02 through FAST-07) are independently confirmed against live, re-fetched CI run data — not merely the ledger's transcription. The phase's stated goal ("PR path drops from ~29.5m toward ~12m in one step") is demonstrated with a real observed drop to 16m52s on the phase's own PR, correctly *not* claimed as reaching the ~12m headline (that is explicitly Phase 235's FAST-01 verdict, over a ≥10-run window). The two structurally-pending slots (AFTER-PUSH, AFTER-DOCSONLY) were genuinely impossible to capture before merge and were booked honestly with exact capture commands rather than claimed or dropped. Both are now OBSERVED against real post-merge runs through the `ci-observe.yml` listener, and the 13 prohibitions are machine-proven rather than signed off — so this report moves from `human_needed` to `passed` on evidence, not on assertion.

One finding came out of the observation itself and is recorded rather than smoothed over: the demotion receipt's FIRST live firing (listener `30463975230`) concluded red on a wiring bug in its own render step — it fed the observer's output back into `--from-json`, which consumes a run payload. Its observe and verdict steps both passed, so the assertion was correct and only its rendering was mis-wired. Fixed in PR #121 and pinned by two regression cases, with the static one proven non-vacuous against the pre-fix file. Booked as Discrepancy #5 in `230-EVIDENCE.md`; the AFTER-PUSH slot cites the post-fix run, not the run whose receipt job was red.

Separately, `main` was briefly red at `16622ade` on `Generated admin Playwright smoke` (`admin-generated.spec.ts:176`, a 320px reflow overflow assertion). It passed at `20e4fe3b` with no related change, so it was transient — but it failed on both the attempt and the retry, a worse flake profile than a single blip. It is NOT a Phase 230 regression: `16622ade` touched no installer template, not that spec, not `admin-acceptance-smoke.sh`, and not that job's `ci.yml` block. Flagged here for a follow-on rather than absorbed into this phase.

---

*Verified: 2026-07-29*
*Verifier: Claude (gsd-verifier)*
