---
phase: 216
slug: harness-foundation-award-gradient
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-03
---

# Phase 216 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright/TS (`admin-eval` project) + bash `scripts/ci/*.sh` guards each with a hermetic `.test.sh`/`.mjs` self-test + ExUnit (existing) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` (add project, do not fork) |
| **Quick run command** | `bash scripts/ci/<guard>.test.sh` (per-guard hermetic self-test) |
| **Full suite command** | `scripts/ci/admin-eval-harness.sh` (render+probe over pilots) + all `scripts/ci/*.test.sh` |
| **Estimated runtime** | ~guards: seconds each; harness render pass: minutes (Playwright, CI-native ubuntu) |

---

## Sampling Rate

- **After every task commit:** Run the touched guard's `.test.sh` (hermetic, sub-second)
- **After every plan wave:** Run the full guard self-test set + the pilot render-probe pass
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** guards < 5s; harness render pass minutes (unavoidable — real browser)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 legitimacy checkpoint | 01 | 1 | HARNESS-01 | T-216-01-SC | Blocking human verify of parse5/cheerio | manual-blocking | `npm view parse5\|cheerio version repository.url` | ❌ | ⬜ |
| 01-T2 deps install | 01 | 1 | HARNESS-01 | T-216-01-SC | Pinned verified deps + lockfile | unit | `npm ls parse5 cheerio … --depth=0` | ❌ | ⬜ |
| 01-T3 gitignore | 01 | 1 | HARNESS-01 | T-216-01-IGN | Bundles never committed | unit | `grep -qxF … .gitignore` | ❌ | ⬜ |
| 01-T4 ci.yml base fix | 01 | 1 | HARNESS-02/RATCHET-02 | T-216-01-BASE | merge-base not tip | integration | `grep merge-base + yaml.safe_load` | ❌ | ⬜ |
| 02-T1 award+render-sha JSON | 02 | 1 | RATCHET-01/02 | T-216-02-BAND | band==min(axes), rendered bool | unit | `node -e` schema check | ❌ | ⬜ |
| 02-T2 settled.tsv + key doc | 02 | 1 | RATCHET-02 | T-216-02-KEY | finding_id key + 217 seam | unit | `head -1 tsv + grep sha256/Phase 217` | ❌ | ⬜ |
| 02-T3 md xref frozen col-4 | 02 | 1 | RATCHET-01 | T-216-02-DECOR | column-4 grammar intact | integration | `quality-ledger-monotonic.sh --base HEAD` | ✅ | ⬜ |
| 03-T1 canonicalize.ts | 03 | 2 | HARNESS-01 | T-216-03-REPRO | SHA reproducible under volatile mutation | unit(tdd) | `canonicalize.test.ts` | ❌ | ⬜ |
| 03-T2 bundle.ts | 03 | 2 | HARNESS-01 | T-216-03-COLLIDE | app_git_sha-keyed bundle | unit | `tsc --noEmit bundle.ts` | ❌ | ⬜ |
| 04-T1 findings-monotonic | 04 | 2 | RATCHET-02 | T-216-04-REGRESS | open-count ↑ = FAIL | unit | `quality-findings-monotonic.test.sh` | ❌ | ⬜ |
| 04-T2 settled-lint | 04 | 2 | RATCHET-02 | T-216-04-WAIVE | sorted/deduped | unit | `settled-findings-lint.test.sh` | ❌ | ⬜ |
| 04-T3 evidence-anchor | 04 | 2 | HARNESS-02 | T-216-04-CITE | anchor absent = reject | unit | `evidence-anchor-check.test.mjs` | ❌ | ⬜ |
| 05-T1 probe-ids module | 05 | 2 | RATCHET-01 | T-216-05-FAKEEV | 9 ids single source | unit | `node -e resolveEvidenceRef` | ❌ | ⬜ |
| 05-T2 award-guard | 05 | 2 | RATCHET-01 | T-216-05-CLIMB/BAND | verify-then-climb | unit | `award-guard.mjs --base HEAD` | ❌ | ⬜ |
| 05-T3 award-guard self-test | 05 | 2 | RATCHET-01 | T-216-05-CLIMB | all 5 D-20 cases | unit | `award-guard.test.mjs` | ❌ | ⬜ |
| 06-T1 probes.ts | 06 | 3 | HARNESS-03 | T-216-06-DRIFT/FALSECLEAN | live :root reads, no toHaveCSS | unit(tdd) | `tsc --noEmit + grep getPropertyValue` | ❌ | ⬜ |
| 06-T2 spec + projects | 06 | 3 | HARNESS-01/03 | T-216-06-FALSECLEAN | seeded-defect flagged + clean pass | integration | `playwright test --list --project=admin-eval` | ❌ | ⬜ |
| 06-T3 stale-render-guard | 06 | 3 | HARNESS-02 | T-216-06-STALE | absence/mismatch/newer = FAIL | unit | `stale-render-guard.test.sh` | ❌ | ⬜ |
| 07-T1 orchestrator | 07 | 4 | HARNESS-01 | T-216-07-JUDGECI | chains 5 guards | unit | `bash -n + grep guards` | ❌ | ⬜ |
| 07-T2 two-pilot climb | 07 | 4 | RATCHET-01 | T-216-07-OPTFLIP/STALECLAIM | ≤A2, band==min, verified_at_sha | integration | `award-guard.mjs --base HEAD + node -e` | ❌ | ⬜ |
| 07-T3 runbook | 07 | 4 | RATIFY-adjacent | — | iteration + sign-off doc | unit | `test -f + grep` | ❌ | ⬜ |
| 07-T4 ci.yml wiring | 07 | 4 | all | T-216-07-JUDGECI | guards in fast_checks, render separate | integration | `yaml.safe_load + grep 5 guards` | ✅ | ⬜ |
| 07-T5 e2e checkpoint | 07 | 4 | all | T-216-07-BUNDLECOMMIT | full local loop green | manual-blocking | booted harness run + self-tests | ❌ | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Every guard/probe ships its own self-test IN THE SAME PLAN that creates it (no separate Wave-0 backfill needed — the plans are self-scaffolding):

- [ ] `.gitignore` entries for `eval/` + `playwright-report/` + `test-results/` — Plan 01 Task 3 (gap: currently unignored)
- [ ] `admin-render-sha.json` skeleton + `settled-findings.tsv` header + `admin-award-ledger.json` seed — Plan 02 (stable diff targets before guards run)
- [ ] `canonicalize.test.ts` determinism self-test — Plan 03 Task 1
- [ ] `quality-findings-monotonic.test.sh` — Plan 04 Task 1
- [ ] `settled-findings-lint.test.sh` — Plan 04 Task 2
- [ ] `evidence-anchor-check.test.mjs` — Plan 04 Task 3
- [ ] `award-guard.test.mjs` (5 D-20 cases) — Plan 05 Task 3
- [ ] `admin-eval` + `-mobile` + `-dark` Playwright projects (add, not fork) — Plan 06 Task 2
- [ ] per-probe seeded-defect + clean-cell fixtures in `admin-eval.spec.ts` — Plan 06 Task 2
- [ ] `stale-render-guard.test.sh` — Plan 06 Task 3

*Enumerated against the final 7-plan breakdown.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| parse5 + cheerio package legitimacy | HARNESS-01 | Supply-chain trust decision (npm install) cannot be auto-approved — security gate policy | Plan 01 Task 1: review `npm view` output vs expected repos |
| End-to-end pilot loop green + correct climb | all | The render pass needs a booted example app; a one-time human sanity check of the full loop + no-eval-files-staged before phase close | Plan 07 Task 5 checkpoint steps |

*These two are the ONLY human gates. Both are security/trust checkpoints, not routine verification — every functional behavior has an automated `<automated>` verify. The deterministic harness is the whole point.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (guards)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready (7-plan breakdown; 2 human security/trust gates, all other behaviors automated)
