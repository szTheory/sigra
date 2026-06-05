---
phase: 159
slug: cross-journey-coherence-sweep-seed-enrichment
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 159 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Playwright (e2e) |
| **Config file** | `test/example/test/test_helper.exs`; Playwright config under `test/example/priv/playwright/` |
| **Quick run command** | `mix test test/example/test/example/demo/seeds_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30–60 seconds (seeds suite); full suite longer |

Playwright:
- Quick: `npx playwright test admin-coherence-sweep.spec.ts --project=admin-checkpoints-chromium`
- Full: `npx playwright test`

---

## Sampling Rate

- **After every task commit:** Run `mix test test/example/test/example/demo/seeds_test.exs`
- **After every plan wave:** Run `mix test` (full ExUnit suite) + the seeds suite
- **Before `/gsd:verify-work`:** Full ExUnit suite green AND Playwright `admin-coherence-sweep.spec.ts` green
- **Max feedback latency:** ~60 seconds (seeds quick run)

---

## Per-Task Verification Map

| Req | Behavior | Wave | Test Type | Automated Command | File Exists |
|-----|----------|------|-----------|-------------------|-------------|
| FIXT-01 | Expired Acme invitation row exists after `Seeds.run/0`; org overview renders "Expired" risk pill | 1 | unit | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-02 | Deletion-scheduled Acme member exists; org roster emits "Deletion scheduled" pill (**requires code: `shape_member_row/1` + roster template clause**) | 1 | unit + e2e | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-03 | Passkey-only persona exists (`totp: false, passkey: true`); "Passkeys" pill renders on users index | 1 | unit | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-04 | New reserved-prefix audit action strings present in `@audit_actions` / `@persona_audit_events`; second OAuth provider row | 1 | unit | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — extend `audit liveness` block |
| FIXT-05 | `Seeds.run/0` twice on fresh DB → identical `snapshot_counts`; `MIX_ENV=test` guard holds | 1 | unit | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — idempotency test auto-covers via dynamic `length(Personas.all())` |
| GATE-03 | Keyboard-only pass: filter-chip toggle / ⌘K filtering / row updates have no animation; enters ease-out; destructive flat | 2 | e2e | `npx playwright test admin-coherence-sweep.spec.ts` | ❌ W0 |
| crit-4 | Empty-state spacing, notice/flash unification, focus/hover parity, back-nav round-trips, `<.scope_ribbon>` presence across all 6 admin screens | 2 | e2e | `npx playwright test admin-coherence-sweep.spec.ts` | ❌ W0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` — coherence filmstrip across all 6 screens + GATE-03 keyboard-only motion pass (sibling spec reusing `admin-checkpoints` helpers; behavior assertions, no new `toHaveScreenshot()` baselines)
- [ ] New `seeds_test.exs` assertions: expired-invitation count, passkey-only persona passkey count, deletion-scheduled Acme member presence, new audit action strings
- [ ] Re-pin existing count assertions in lockstep: persona count (`seeds_test.exs:100,119`), audit liveness (`:241` `>=15`, `:270` `alice_tied >= 3`)

*ExUnit + Playwright infrastructure already exists; Wave 0 is new test files/assertions, not framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overview "needs-review" count vs deep-link semantics not visibly broken by the new deletion-scheduled member | crit-4 (flagged) | Deliberate count-vs-deep-link semantics decision is out of phase scope (`admin-overview-needs-review-count-link-mismatch`); only confirm it does not *look* broken, then file a tracked follow-on | During the coherence sweep, view `/admin` with the enriched seed; confirm the needs-review card renders sanely; do not guess-fix the link target |

*All in-scope FIXT/GATE behaviors have automated verification; the single manual item is a regression watch on an explicitly-deferred bug.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (coherence-sweep spec + new seed assertions)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (seeds quick run)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
