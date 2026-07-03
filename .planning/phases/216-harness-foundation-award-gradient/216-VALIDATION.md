---
phase: 216
slug: harness-foundation-award-gradient
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| {planner fills} | | | HARNESS-01/02/03, RATCHET-01/02 | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `admin-eval` Playwright project registered in `playwright.config.ts` (inherit determinism config)
- [ ] Hermetic `.test.sh`/`.mjs` self-test harnesses for each new `scripts/ci/` guard (clone `quality-ledger-monotonic.test.sh` idiom)
- [ ] `.gitignore` entries for `test/example/priv/playwright/eval/` + `playwright-report/` (gap: currently unignored)

*Planner: enumerate against final task breakdown.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| {planner fills, if any — target zero-human per project preference} | | | |

*Target: all phase behaviors have automated verification (deterministic harness is the whole point).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (guards)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
