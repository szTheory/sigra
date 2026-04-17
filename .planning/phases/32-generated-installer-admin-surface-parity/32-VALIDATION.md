---
phase: 32
slug: generated-installer-admin-surface-parity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (mix test) + bash smoke (scripts/ci/admin-acceptance-smoke.sh) |
| **Config file** | test/test_helper.exs, scripts/ci/admin-acceptance-smoke.sh |
| **Quick run command** | `mix test test/sigra/install/features/admin_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~15s (unit) / ~90s (full suite) / ~120s (admin-acceptance-smoke.sh) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/install/features/admin_test.exs`
- **After every plan wave:** Run `mix test` (unit) + `scripts/ci/admin-acceptance-smoke.sh` (integration)
- **Before `/gsd-verify-work`:** Full suite green + admin-acceptance-smoke.sh exits 0
- **Max feedback latency:** 15 seconds (unit) / 120 seconds (smoke)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-01-01 | 01 | 1 | USER-01/02/03/04 | — | UsersIndexLive + UserShowLive mounted in global + org live_session blocks | unit | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0 | ⬜ pending |
| 32-01-02 | 01 | 1 | IMPR-01/03/05 | T-IMPR-ESCALATION | impersonation_controller.ex template exists + is emitted by Admin.files/1 | unit | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0 | ⬜ pending |
| 32-01-03 | 01 | 1 | AUD-04 | — | audit_export_controller.ex listed in Admin.files/1 (not orphaned) | unit | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0 | ⬜ pending |
| 32-01-04 | 01 | 1 | USER-01, IMPR-01, AUD-04 | — | generator test asserts all three emissions + fails on regression | unit | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0 | ⬜ pending |
| 32-02-01 | 02 | 2 | USER-01, IMPR-01, AUD-04 | — | admin-acceptance-smoke.sh probes /admin/users (200) + impersonation POST (302/403 ≠ 500) + audit export | integration | `scripts/ci/admin-acceptance-smoke.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/install/features/admin_test.exs` — extend with new `describe` blocks asserting UsersIndexLive + UserShowLive live mounts in both live_session blocks (Plan 01 Task 2) AND asserting Admin.files/1 includes audit_export_controller + impersonation_controller templates (Plan 01 Task 1). Per PATTERNS.md line 18: no standalone `router_injection_test.exs` — convention is to extend `admin_test.exs`.
- [ ] Existing fixtures: `test/example/` (reference host), `test/sigra/install/` helpers — no new framework install required

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Generated host impersonation UI end-to-end | IMPR-03 (full actor/target flow) | Requires interactive browser + staged admin + staged target user; covered by Phase 34 UAT, not Phase 32 | Deferred to Phase 34 — Phase 32 only asserts controller reachability (no 500) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (admin_test.exs extensions for Phase 32 router-mount + template-emission tests)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
