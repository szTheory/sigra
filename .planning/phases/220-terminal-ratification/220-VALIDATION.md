---
phase: 220
slug: terminal-ratification
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-09
validated: 2026-07-10
---

# Phase 220 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash/node CI self-tests (`*.test.sh`, `*.test.mjs`) + GitHub Actions required checks |
| **Config file** | `.github/workflows/ci.yml` |
| **Quick run command** | `bash scripts/ci/quality-ledger-monotonic.test.sh && node scripts/ci/award-guard.test.mjs` |
| **Full suite command** | Live CI run on the PR (5 required checks under ruleset 14941512) |
| **Estimated runtime** | self-tests ~seconds; live CI ~17–30 min PR wall-clock |

---

## Sampling Rate

- **After every task commit:** Run the relevant guard self-test locally where reproducible
- **After every plan wave:** Confirm guard exit codes against the resolved merge-base
- **Before `/gsd-verify-work`:** All five required checks green on the PR
- **Max feedback latency:** self-tests seconds; full CI signal ~30 min

---

## Per-Task Verification Map

> Filled by the planner (`must_haves`) and executor. The load-bearing validation signals for this ship phase:

| SC | Requirement | Secure/Correct Behavior | Test Type | Command / Signal |
|----|-------------|-------------------------|-----------|------------------|
| SC-1 | RATIFY-01 | `quality-ledger-monotonic.sh` exits 0 vs real merge-base (36 cells compared) AND would exit non-zero on any sub-score decrease; self-tests green in same job | CI live-guard | guard exit 0 + `quality-ledger-monotonic.test.sh` + `award-guard.test.mjs` green in the `fast_checks` job |
| SC-2 | RATIFY-01 | Runbook orients a zero-context agent (run loop, human sign-off locus, dossier map) | doc-assertion | `guides/reference/admin-eval-runbook.md` contains the three additive freshness notes (D-04) |
| SC-3 | RATIFY-01 | Quarantine PR: required `Example Playwright smoke` GREEN (fresh amd64 render == fresh baseline), non-required `fast_checks` red-as-expected on canary-modify; terminal PR sees zero PNG diff | CI live-check | `git diff --name-status origin/main...HEAD -- '*.png'` == exactly 3 `impersonation-banner` M pre-quarantine; 0 post-merge |
| SC-4 | RATIFY-01 | `fast_checks` bundle-free checkout exits 0 without cheerio (lazy-require after no-bundles guard); gate stays armed where bundles exist | CI live-check | `fast_checks` green on a bundle-free PR checkout; `evidence-anchor-check.mjs` still flips on a broken cite where `admin_eval_render` bundles exist |

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — both ratchet guards, their self-tests, `snapshot-canary-guard.sh`, and `evidence-anchor-check.mjs` are already built and wired (216/219). No net-new test scaffolding.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Quarantine-PR scope check | RATIFY-01 | The one-time non-required `fast_checks` red on the canary rebirth needs a human D-05-style scope confirmation on the trivial 3-file diff (guard is never-allowlistable by design) | Review the quarantine PR diff is *only* the 3 `impersonation-banner` PNGs; confirm required `Example Playwright smoke` is green before merge |
| Terminal-PR human sign-off | RATIFY-01 | Milestone-ship gate; the actual merge is deferred to `/gsd-ship` | Confirm 5/5 required checks green on the rebased terminal PR before flipping ROADMAP status |

---

## Validation Sign-Off

- [x] SC-1…SC-4 each mapped to an observable CI/self-test signal (above)
- [x] Live-guard proof runs against the real merge-base (not a doc assertion — closes 216 SC-5 trap) — `fast_checks` green on terminal PR #73 at committed HEAD `993f7db4`
- [x] cheerio fix proven in CI (not locally — PI-2 step-ordering artifact) — `fast_checks` green on PR #73
- [x] LLM panel absent from every required-check job (SC-4 invariant) — `panel-ci-isolation.test.sh` PASS + zero-match `ci.yml` grep
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** signed off 2026-07-10 — terminal PR #73 merged to `main` (`c0595e09`) with all 5 required checks + `fast_checks` + `ci-gate` green at committed HEAD; quarantine PR #72 scope-checked (exactly 3 `impersonation-banner` PNGs, required Example Playwright smoke green). Milestone GitHub side shipped; Hex publish for v1.2.0/v1.3.0 deferred as tracked debt (pre-existing upgrade-smoke `<.button type>` failure — see `.planning/todos/pending/2026-07-10-upgrade-smoke-button-type-hex-publish.md`).
