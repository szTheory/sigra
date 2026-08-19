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
| 247-01-01 | 01 | 1 | TWIN-01 | T-247-01 | Authenticated lesson uses only the HttpOnly cookie session; bootstrap and worker protocols expose no app credential. | controller + LiveView | `cd test/example && mix test test/example_web/controllers/learning_twin_controller_test.exs test/example_web/live/learning_twin_live_test.exs` | ❌ W0 | ⬜ pending |
| 247-01-02 | 01 | 1 | OFF-01 | T-247-02 | Only exact-size, matching-SHA-256 media with an awaited cache write receives a partitioned ready marker. | Chromium integration | `cd test/example/priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "media integrity"` | ❌ W0 | ⬜ pending |
| 247-02-01 | 02 | 2 | OFF-02 | Missing, expired, or changed account partitions cannot activate prior lesson state, receipts, or replay. | context + Chromium integration | `cd test/example && mix test test/example/learning_twin && cd priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "lease|partition|logout|account switch"` | ❌ W0 | ⬜ pending |
| 247-02-02 | 02 | 2 | OFF-02 | Backend reauthorization records one durable accepted, rejected, or conflict outcome and duplicate/concurrent retries return it without reapplying. | Ecto concurrency + controller + Chromium | `cd test/example && mix test test/example/learning_twin test/example_web/controllers/learning_twin_controller_test.exs && cd priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --grep "replay"` | ❌ W0 | ⬜ pending |

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
