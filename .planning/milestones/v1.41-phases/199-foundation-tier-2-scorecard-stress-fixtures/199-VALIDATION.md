---
phase: 199
slug: foundation-tier-2-scorecard-stress-fixtures
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-25
---

# Phase 199 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 199-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Frameworks** | ExUnit (seed fixtures), bash (CI guards), Playwright `@playwright/test` (content-equivalence / snapshots) |
| **Config files** | `test/example/priv/playwright/playwright.config.ts`; `.github/workflows/ci.yml` |
| **Quick run (seeds)** | `MIX_ENV=test mix test test/example/test/example/demo/seeds_test.exs` (from `test/example`) |
| **Quick run (guard)** | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` |
| **Quick run (guard self-test)** | NEW — bash test exercising the guard binary against a synthetic 2→1 ledger delta |
| **Recapture gate** | `bash scripts/ci/snapshot-recapture-gate.sh <slug>...` (dry-run: `RECAPTURE_DRYRUN=1`) |
| **Estimated runtime** | seeds ~15s · guard <2s · design Playwright lane ~minutes |

---

## Sampling Rate

- **After every task commit:** the relevant quick command (seeds ExUnit, guard self-test, or `RECAPTURE_DRYRUN=1`).
- **After every plan wave:** full `seeds_test.exs` + `seeds_script_test.exs` + monotonic guard vs `origin/main`.
- **Before phase gate:** design-lane Playwright green (content-equivalence un-skipped) + recapture gate all-green + both allowlists empty + monotonic guard green vs `origin/main`.
- **Max feedback latency:** <20s for the ExUnit/guard inner loop.

---

## Per-Task Verification Map

| Requirement | Behavior | Test Type | Automated Command / Location | File Exists |
|-------------|----------|-----------|------------------------------|-------------|
| LEDGER-01 | Tier-2 proxies defined in scorecard + ledger; `[012]` column-4 shape preserved | docs + parse-smoke | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` still PASS (proves `awk -F'\|'` parse intact) | ✅ guard exists |
| LEDGER-02 | Guard fails on a Tier-2 decrease (2→1) | shell self-test | NEW `scripts/ci/` bash test (synthetic git repo, asserts non-zero exit) | ❌ Wave 0 |
| LEDGER-02 | Guard stays merge-blocking vs `origin/main` | CI wiring check | `ci.yml:109-110` unchanged (D-07) | ✅ wired |
| FIXT-01 | ≥25 self-tied events on first-listed user → MG-5/6 pagination renders | Playwright | un-skip `admin-design.spec.ts:328` + run design lane | ⚠️ skipped → un-skip |
| FIXT-01 | Admin persona ≥25 self-tied events | ExUnit | raise `seeds_test.exs` audit-liveness assert (`~:285-310`) from `>=15` to `>=25` for admin | ⚠️ exists, raise threshold |
| FIXT-02 | Bulk cohort + idempotent upserts; no duplicate on re-run | ExUnit | extend `seeds_test.exs` SEED-01 idempotency (`~:96-109`) to assert bulk count stable across two `run/0` | ✅ pattern exists |
| FIXT-02 | Seeds refuse to run in `MIX_ENV=test` (raise guard) | ExUnit subprocess | `seeds_script_test.exs:14` unchanged — bulk inserts under same guard | ✅ contract exists |
| FIXT-02 | `demo_users == length(Personas.all())` still holds with bulk cohort excluded | ExUnit | `seeds_test.exs:107,126` must stay green (resolve Pitfall 3 first) | ✅ must stay green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **NEW guard self-test (2→1)** — builds a throwaway `$TMPDIR` git repo with a Tier-2→Tier-1 ledger delta, asserts the guard exits non-zero. Covers LEDGER-02 / D-05. Recommended placement: a bash test in `scripts/ci/` wired as a merge-blocking CI step alongside the existing guard invocation (the guard reads git state via `git show ${BASE}:${LEDGER}`, so a sibling bash test is the lowest-friction, most faithful exercise — ExUnit would mean shelling out and fabricating git state).
- [ ] **Raise `seeds_test.exs` admin audit-liveness threshold** to `>=25` and add a bulk-cohort idempotency assertion. Covers FIXT-01 / FIXT-02.
- [ ] **Resolve Pitfall 3** (bulk-user email domain vs the `demo_users` count assertion) before extending seeds.
- [ ] **Empirical blast-radius run** of both Playwright lanes to enumerate which (if any) PNGs actually move (Research Finding 2/3 — recapture scope may be smaller than D-12 assumes).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| motion-token conformance / no `transition: all` | LEDGER-01 | No current automated gate (D-02 documented-as-manual) | Reviewer greps for `transition: all`; documented-as-manual in the scorecard Tier-2 add-on block |
| density/whitespace rhythm | LEDGER-01 | No current gate (D-02) | Documented-as-manual proxy in scorecard |
| target-size minimum | LEDGER-01 | No current gate (D-02) | Documented-as-manual proxy in scorecard |
| Ledger prose internal consistency (D-06) | LEDGER-02 | Doc reconciliation, not machine-checkable | Reviewer confirms no stale "Tier 2 not declared" language remains |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (guard self-test, seed-threshold raise, blast-radius enumeration)
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s (inner loop)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
