---
phase: 106
slug: replay-verification-closeout
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 106 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `106-CONTEXT.md` and `106-RESEARCH.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, example-host ExUnit, shell artifact-integrity checks, Playwright escalation lane |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `test/example/mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color` |
| **Full suite command** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color && cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color && cd /Users/jon/projects/sigra && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json` |
| **Estimated runtime** | ~30-60 seconds quick loop, ~90-180 seconds focused full phase gate |

---

## Sampling Rate

- **After every task commit:** Run the quick run command after edits to `104-VERIFICATION.md` or active truth files.
- **After every plan wave:** Run the full suite command plus artifact-integrity checks.
- **Before `$gsd-verify-work`:** Full suite must be green; if freshness gate fails, run the Playwright escalation lane.
- **Max feedback latency:** ~180 seconds for the bounded full phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 106-01-01 | 01 | 1 | WH-05 | T-106-01 / T-106-02 | `104-VERIFICATION.md` separates historical replay proof from fresh current-head confirmation and cites concrete executable evidence | integration | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color && cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color && cd /Users/jon/projects/sigra && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json` | ✅ extend | ⬜ pending |
| 106-01-02 | 01 | 1 | WH-05 | T-106-03 | Artifact integrity checks prove the replay proof bundle still contains required lineage, receiver-verification, and screenshot references before closeout is attested | artifact integrity | `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/failed-source-row.png && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/source-delivery-detail.png && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/replay-delivery-detail.png && rg -n '\"source_delivery_id\"|\"replay_delivery_id\"|\"root_delivery_id\"|\"receiver_verification\"|\"screenshots\"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json && rg -n 'source delivery id|replay delivery id|root delivery id|receiver verification|Artifacts:' .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md` | ✅ extend | ⬜ pending |
| 106-02-01 | 02 | 2 | WH-05 | T-106-04 | Active truth files reconcile only the authoritative present-tense WH-05 story and do not imply WH-06 is complete | integration | `rg -n 'WH-05|104-VERIFICATION|Phase 104|Phase 106|verified|Pending|partial|complete' .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.23-MILESTONE-AUDIT.md` | ✅ extend | ⬜ pending |
| 106-02-02 | 02 | 2 | WH-05 | T-106-04 | If replay-relevant drift or artifact failure is detected, the plan escalates to the canonical Playwright rerun instead of silently attesting stale proof | browser/integration | `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 SIGRA_EXAMPLE_URL=http://localhost:4000 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The final wording in `104-VERIFICATION.md` and the reconciled truth files clearly states “implemented in Phase 104, authoritatively verified/closed out in Phase 106” without accidentally implying `WH-06` or all of `v1.23` is complete | WH-05 | This is primarily an editorial truthfulness check across multiple planning files | Read `104-VERIFICATION.md`, `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `v1.23-MILESTONE-AUDIT.md`; confirm the wording is coherent, bounded to WH-05, and does not broaden into archive cleanup or milestone-wide completion claims. |

---

## Validation Sign-Off

- [x] All tasks have runnable automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] No standalone Wave 0 scaffold remains
- [x] No watch-mode flags
- [x] Feedback latency < 180s for the bounded full phase gate
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
