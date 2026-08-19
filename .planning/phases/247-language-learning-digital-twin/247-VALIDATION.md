---
phase: 247
slug: language-learning-digital-twin
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-18
---

# Phase 247 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit/Phoenix LiveViewTest plus `@playwright/test` 1.59.1 Chromium |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example && mix test test/example/learning_twin test/example_web/controllers/learning_twin_controller_test.exs test/example_web/live/learning_twin_live_test.exs` |
| **Full suite command** | `cd test/example && mix test && cd priv/playwright && npm test -- --project=chromium` |
| **Estimated runtime** | ~600 seconds |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit file or `npm test -- twin-offline.spec.ts --project=chromium` scenario named by that task.
- **After every plan wave:** Run `cd test/example && mix test && cd priv/playwright && npm test -- twin-offline.spec.ts --project=chromium`.
- **Before `$gsd-verify-work`:** The full suite command must be green and committed machine-readable browser evidence must exist.
- **Max feedback latency:** 600 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 247-01-01 | 01 | 1 | TWIN-01, OFF-01, OFF-02 | T-247-01..05 | Production tracer crosses cookie/current-Scope auth, manifest verification, marker-last storage, valid offline use, and one durable accepted replay. | Ecto + Phoenix + Chromium | `cd test/example && mix ecto.migrate && cd priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "tracer"` | ❌ W0 | ⬜ pending |
| 247-02-01 | 02 | 2 | OFF-01 | T-247-06..09 | Short, same-size corrupt, interrupted, deterministic cache-write-failure, and orphan-cache paths create no ready marker. | Chromium integration | `cd test/example/priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "media integrity"` | ❌ W0 | ⬜ pending |
| 247-03-01 | 03 | 2 | OFF-02 | T-247-10..11 | Configured/default TTL and one-microsecond-before/at/after expiry plus foreign/missing/changed partitions fail at the exact boundary. | Ecto context | `cd test/example && mix test test/example/learning_twin/learning_twin_test.exs --trace` | ❌ W0 | ⬜ pending |
| 247-03-02 | 03 | 2 | TWIN-01, OFF-02 | T-247-12..13 | Bootstrap/LiveView derive current account only and replace denied state without leaking prior-account content or credentials. | controller + LiveView | `cd test/example && mix test test/example_web/controllers/learning_twin_controller_test.exs test/example_web/live/learning_twin_live_test.exs --trace` | ❌ W0 | ⬜ pending |
| 247-04-01 | 04 | 3 | OFF-02 | T-247-15..16 | Accepted/rejected/conflict receipts are transactional, rollback-safe, and duplicate/concurrent stable. | Ecto concurrency | `cd test/example && mix test test/example/learning_twin/learning_twin_test.exs --trace` | ❌ W0 | ⬜ pending |
| 247-04-02 | 04 | 3 | OFF-02 | T-247-14, T-247-17..18 | Replay transport requires cookie/current-Scope/CSRF, rejects owner/input smuggling, and redacts responses. | controller | `cd test/example && mix test test/example_web/controllers/learning_twin_controller_test.exs --trace` | ❌ W0 | ⬜ pending |
| 247-05-01 | 05 | 3 | TWIN-01, OFF-02 | T-247-19..23 | Valid offline form, exact expiry, logout, account switch, theme, and 320px behavior are partition-safe and accessible. | Chromium integration | `cd test/example/priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "lease|partition|logout|account switch|practice form|theme"` | ❌ W0 | ⬜ pending |
| 247-06-01 | 06 | 4 | OFF-02 | T-247-24..26 | Accepted/rejected/conflict and duplicate responses reconcile one accessible chronological receipt row. | Chromium integration | `cd test/example/priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "replay|receipt|accepted|rejected|conflict"` | ❌ W0 | ⬜ pending |
| 247-06-02 | 06 | 4 | TWIN-01, OFF-01, OFF-02 | T-247-27..29 | Full ExUnit/Chromium matrix and all UI backstops publish exact-source credential-free evidence last. | phase proof | `scripts/ci/phase-247-language-twin-proof.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/test/example/learning_twin/*_test.exs` — lease, authorization, partition, transaction/idempotency, conflict, and rejection coverage.
- [ ] `test/example/test/example_web/controllers/learning_twin_controller_test.exs` — authenticated bootstrap/replay/CSRF and server-derived owner coverage.
- [ ] `test/example/test/example_web/live/learning_twin_live_test.exs` — authenticated markup, accessibility, and state-contract coverage.
- [ ] `test/example/priv/playwright/tests/twin-offline.spec.ts` — deterministic worker, Cache Storage, IndexedDB, offline, corruption, lease, account switch, and replay coverage.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Chromium quota forcing may supplement, but never replace, the deterministic injected cache-write-failure case.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 600s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
