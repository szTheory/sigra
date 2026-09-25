---
phase: 231
slug: gate-honesty-nightly-revival
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-29
---

# Phase 231 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `231-RESEARCH.md` § Validation Architecture (lines 1057-1119).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (guards)** | `bash` self-tests (`scripts/ci/*.test.sh`) + `node --test` (`scripts/ci/prohibitions/*.test.mjs`, node 20) |
| **Framework (specs)** | `@playwright/test` 1.59.1 |
| **Framework (library)** | ExUnit — *not exercised by this phase* |
| **Config file** | `.github/workflows/ci.yml` (`fast_checks` `:155-354`); `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `bash scripts/ci/<name>.test.sh` (each hermetic, < 5s) |
| **Prohibition suite** | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — the shell glob is load-bearing; a bare directory arg is not valid on node 22 |
| **Full suite command** | the CI run itself — there is no local equivalent for a gate-honesty phase |
| **Estimated runtime** | ~5s per guard self-test; full CI run is the phase gate |

---

## Sampling Rate

- **After every task commit:** the specific `*.test.sh` / `node --test <file>` for the guard touched (each < 5s)
- **After every plan wave:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` plus every `scripts/ci/*.test.sh` the wave touched
- **Before `/gsd-verify-work`:** a full CI run green on the phase PR, then the five observed-run receipts below
- **Max feedback latency:** 5s local (guard self-tests); CI run wall-clock for integration-level proof

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. This table is the requirement→command contract the plans must satisfy.

| Req | Behavior | Test Type | Automated Command | File Exists |
|-----|----------|-----------|-------------------|-------------|
| GATE-03 | manifest parses to a populated, tiered enumeration; zero rows = broken parse (D-04) | unit (hermetic) | `bash scripts/ci/honest-skip-verdict.test.sh` | ❌ W0 |
| GATE-03 | a rotted skip (gate string references `head_ref`/branch/SHA) fails the verdict | unit (hermetic) | same | ❌ W0 |
| GATE-03 | a correct event-gated skip passes; a correct docs-only skip passes | unit (hermetic) | same | ❌ W0 |
| GATE-03 | manifest `gate` column agrees with `ci.yml`'s actual `if:` | node:test | `node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` | ⚠️ exists, needs new assertion (C-1/C-2) |
| GATE-02 | `generated_admin_playwright_smoke` runs on `pull_request` | node:test | new assertion asserting the job declares **no** `head_ref` condition | ❌ W0 |
| GATE-02 | 320px / 200%-zoom reflow containment | e2e | `npx playwright test tests/admin-generated.spec.ts --project=admin-generated` (via `scripts/ci/admin-acceptance-smoke.sh --test all`) | ✅ `admin-generated.spec.ts:169-176` |
| GATE-04 | `probes.ts` ember check survives SVG `className` (`SVGAnimatedString`) | unit | `SVGAnimatedString`-shaped case in the probe unit tests, or a fresh `admin-eval` bundle containing an SVG surface | ❌ W0 |
| GATE-04 | b1-b6 execute and pass | integration | `bash scripts/ci/admin-eval-harness.sh` (inside `admin_eval_render`) | ✅ harness exists; has never run to completion in CI |
| GATE-04 | `continue-on-error: true` cannot be silently reinstated | node:test | inverted `p05-admin-eval-red-not-abandoned.test.mjs` | ⚠️ exists, must be inverted (C-3) |
| GATE-01 | `playwright-github-pages.yml` seeds before boot (D-17) | node:test or bash | assert the workflow contains a `Run demo seeds` step between DB setup and boot | ❌ W0 |
| GATE-01 | ci-observe schedule leniency is gone (D-19) | node:test | assert `ci-observe.yml` contains no `RUN_EVENT" = "schedule"` early-exit | ❌ W0 |
| DX-05 | polling loop returns 0 inside 120 attempts against a real run | unit (hermetic) + live | `bash scripts/ci/wait-for-ci-gate.test.sh`, then the live invocation (D-21) | ❌ W0 |
| DX-05 | notifier self-heals a missing label; never loses the issue | unit (hermetic) | `bash scripts/ci/notify-failure-issue.test.sh` (extended stub) | ⚠️ exists, stub must be extended |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/ci/honest-skip-verdict.sh` + `.test.sh` — GATE-03
- [ ] `scripts/ci/wait-for-ci-gate.sh` + `.test.sh` — DX-05 / D-21
- [ ] Extend the `gh` stub in `scripts/ci/notify-failure-issue.test.sh` with `label list` / `label create` branches, plus cases D–G — DX-05 / D-22 (**blocks the script change**)
- [ ] Extend `p10-no-undocumented-demotion.test.mjs`: `gate`-column-vs-`ci.yml` assertion; tier-A floor `>= 9` → `>= 8` with a recorded reason — C-2
- [ ] Invert `p05-admin-eval-red-not-abandoned.test.mjs`: assert `continue-on-error` **absent**; drop the `REQUIREMENTS.md`-not-`Complete` assertion — C-3 (**blocks D-11 step 4**)
- [ ] Structural assertion that `playwright-github-pages.yml` seeds before boot — GATE-01 / D-17
- [ ] Structural assertion that `ci-observe.yml` has no schedule-lane leniency — GATE-01 / D-19
- [ ] Instrumentation task for the 320px assertion (report `innerWidth` + the overflowing elements) — GATE-02 / D-09 diagnosis
- [ ] CI-native regeneration + commit of `admin-render-sha.json` / `fix-queue.json` — GATE-04
- [ ] Wire every new `.test.sh` into `fast_checks` near `ci.yml:322`

---

## Success-Criterion Validation (D-25, with the C-4 correction)

| SC | Command | Observable artifact |
|----|---------|---------------------|
| **SC-1** | `gh run view <first-scheduled-run-after-merge> --repo szTheory/sigra --json jobs` | zero jobs with `conclusion` outside `{success, skipped}` — or, under the fallback branch, a filed defect with an owner linked from the run. Trigger: cron `30 4 * * *` (`ci.yml:21`). |
| **SC-2** | `gh run view <phase-PR-run> --repo szTheory/sigra --json jobs -q '.jobs[] \| select(.name=="Generated admin Playwright smoke")'` then `gh run view --repo szTheory/sigra --job <id> --log` | `conclusion: success`, `startedAt != completedAt` (a real duration, **not** `skipped`), and — **restated per C-4** — `Running 9 tests using 1 worker` followed by `8 passed` then `1 passed`, with zero `failed` lines. |
| **SC-3** | `gh workflow run "CI" -f force_rot_probe=false` then `gh workflow run "CI" -f force_rot_probe=true`; `gh run view <id> --json jobs` on each | clean → `ci-gate` `conclusion: success`; rot probe → `ci-gate` `conclusion: failure` **whose log names the specific lane and its gate string**. |
| **SC-4** | `gh run view --repo szTheory/sigra --job <admin_eval_render-job-id> --log \| grep -E 'admin-eval-harness: \((b1\|b2\|b3\|b4\|b5\|b6)\)\|PASS — all phases green'` plus `--json jobs` for the conclusion | six `(bN)` banner lines **and** `admin-eval-harness: PASS — all phases green`, **and** `conclusion: success` on the job. Banners prove reach; conclusion proves pass (D-14). |
| **SC-5** | `bash scripts/ci/wait-for-ci-gate.sh --sha <real-push-to-main-sha> --repo szTheory/sigra --no-dispatch --format json`; plus `gh issue view 118 --repo szTheory/sigra --json comments` | exit 0 with an attempt count well under 120; plus issue #118's 3-comment thread (already captured — D-23 forbids re-staging). |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| First scheduled nightly after merge concludes green | GATE-01 / SC-1 | The cron (`30 4 * * *`) cannot be forced forward; the receipt only exists post-merge | After merge, wait for the next scheduled run and capture `gh run view <id> --json jobs`. Under the fallback branch, file each remaining red as a diagnosed defect with an owner, linked from the run. |
| GitHub Pages source self-heal | GATE-01 / D-18 | Depends on whether `ensure-github-pages-legacy-branch.sh` can finally run after D-17's fix; may require a Settings→Pages change no CI token can make | Observe the first green publisher run. If Pages still builds `main`'s repo root, file as a diagnosed defect with an owner (D-18's explicit scope fence) — do **not** expand into a repo-admin reconfiguration. |

*Everything else in this phase has automated verification or an observed-run receipt.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for guard self-tests
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
