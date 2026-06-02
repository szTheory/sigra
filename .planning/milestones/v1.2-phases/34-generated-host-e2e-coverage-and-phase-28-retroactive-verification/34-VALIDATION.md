---
phase: 34
slug: generated-host-e2e-coverage-and-phase-28-retroactive-verification
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-17
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash smoke + Playwright (TypeScript) + ExUnit (unchanged regression guard) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --list` |
| **Full suite command** | `GITHUB_WORKSPACE=$(pwd) PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost scripts/ci/admin-acceptance-smoke.sh --test all` |
| **Estimated runtime** | ~3–8 minutes (cold `mix phx.new` + compile + Playwright) |

---

## Sampling Rate

- **After every task commit:** Run quick list command above; for smoke edits run `bash -n scripts/ci/admin-acceptance-smoke.sh`
- **After every plan wave:** Run full `admin-acceptance-smoke.sh --test all` when Postgres is available
- **Before `/gsd-verify-work`:** Full smoke command exits 0
- **Max feedback latency:** ~8 minutes for wave gates (CI-bound)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-01-01 | 01 | 1 | VFY-01 | T-34-01 | Impersonation and export flows never run as anonymous success on privileged surfaces | smoke + Playwright | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test impersonation-controller` | ✅ | ⬜ pending |
| 34-01-02 | 01 | 1 | VFY-01 | T-34-02 | Global users index and CSV export respect authenticated platform-admin session | smoke + Playwright | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test audit-export` | ✅ | ⬜ pending |
| 34-01-03 | 01 | 1 | VFY-01 | T-34-03 | `all` target preserves bash parity probes before Playwright | smoke | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` | ✅ | ⬜ pending |
| 34-01-04 | 01 | 1 | VFY-01 | — | CI job has bounded wall-clock | config | `rg -n "generated_admin_playwright_smoke|timeout-minutes|admin-acceptance-smoke" .github/workflows/ci.yml` | ✅ | ⬜ pending |
| 34-02-01 | 02 | 2 | VFY-01 | — | Phase 28 verification artifact matches skeleton contract | doc | `test -f .planning/phases/28-user-operations-surface/28-VERIFICATION.md && rg -n "Observable Truths|human_verification" .planning/phases/28-user-operations-surface/28-VERIFICATION.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing `scripts/ci/admin-acceptance-smoke.sh` scaffold + `admin-generated.spec.ts` — Wave 0 from Phase 31/32
- [x] Playwright npm deps under `test/example/priv/playwright/`

*No new framework install — extends existing harness.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full smoke on laptop without Docker Postgres | VFY-01 | Host env may lack Postgres on `localhost:5432` | Start `postgres:16` per `CLAUDE.md` then run `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or documented manual fallback
- [ ] Sampling continuity: implementation plan tasks all tied to smoke/Playwright
- [ ] Wave 0 covers harness presence
- [ ] No watch-mode flags in commands
- [ ] `nyquist_compliant: true` set in frontmatter after plans execute

**Approval:** pending
