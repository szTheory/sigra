---
phase: 160
slug: regression-hardening-baseline-ratification
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-05
---

# Phase 160 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Reconstructed retroactively (State B) by `/gsd-validate-phase` on 2026-06-05.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library) + Playwright (visual/parity) + axe (WCAG) |
| **Config file** | `mix.exs` / `test/test_helper.exs`; Playwright under `test/example/priv/playwright/` |
| **Quick run command** | `mix test test/sigra/admin/` |
| **Full suite command** | `mix test` (library); `cd test/example && mix test` (host) |
| **Estimated runtime** | ~10s (admin ExUnit subset); Playwright gates ~30s |

Library ExUnit needs a live Postgres at `localhost:5432` (`postgres`/`postgres`).
Pure-function tests (`test/sigra/admin_test.exs`) need no DB. Visual gates run via
`scripts/ci/snapshot-recapture-gate.sh` (compare-mode) and
`scripts/ci/admin-acceptance-smoke.sh` (generated-host parity).

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/admin/`
- **After every plan wave:** Run `mix test` + the relevant Playwright lane
- **Before `/gsd:verify-work`:** Full suite + compare-mode snapshot gate must be green
- **Max feedback latency:** ~10s (ExUnit subset)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 160-01-01 | 01 | 1 | GATE-01 | T-160-02 | Dark brand-strong passes WCAG-AA (no brand-soft/strong AA violation) | visual/axe | `scripts/ci/snapshot-recapture-gate.sh` (axe embedded in `admin-checkpoints.spec.ts`) | ✅ | ✅ green |
| 160-01-02 | 01 | 1 | GATE-01 | T-160-01 | `needs_review` deep-link returns locked ∪ deleted union (global) | unit (DB) | `mix test test/sigra/admin/users_query_test.exs` (line 332) | ✅ | ✅ green |
| 160-01-02 | 01 | 1 | GATE-01 | T-160-01 | `needs_review` filter stays org-scoped — no cross-org leak (WR-01) | unit (DB) | `mix test test/sigra/admin/users_query_test.exs` (line 405) | ✅ | ✅ green |
| 160-01-02 | 01 | 1 | GATE-01 | — | `Sigra.Admin.needs_review/1` sums locked+deleted, defaults missing keys to 0 (single source of truth) | unit (pure) | `mix test test/sigra/admin_test.exs` | ✅ **W0** | ✅ green |
| 160-01-02 | 01 | 1 | GATE-01 | T-160-01 | `needs_review=true` deep-link reaches both locked AND deleted users on generated host | integration | `cd test/example && mix test test/example_web/live/admin_user_filters_live_test.exs` | ✅ **W0** | ✅ green |
| 160-01-03 | 01 | 1 | GATE-01 | T-160-03 | `notice/1` wraps slot in `div.sg-text-sm` (not `<p>`); `format_date/1` has `%NaiveDateTime{}` head | byte-golden | `mix test test/sigra/admin/components_test.exs` | ✅ | ✅ green |
| 160-02-01 | 02 | 1 | GATE-02 | — | Admin-generated installer-parity lane green; no template drift | integration | `scripts/ci/admin-acceptance-smoke.sh` (`admin-generated.spec.ts`, 6 tests) | ✅ | ✅ green |
| 160-03-01 | 03 | 1 | GATE-01 | — | 7 dark checkpoints re-recorded; canary byte-green; axe 0 violations | visual/axe | `scripts/ci/snapshot-recapture-gate.sh` | ✅ | ✅ green |
| 160-04-01 | 04 | 1 | GATE-01/02 | — | Ratification: 3-project compare-mode exit 0, 0 unintended re-records | visual | `scripts/ci/snapshot-recapture-gate.sh` (compare-mode) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Retroactive Nyquist fill (2026-06-05) — two automated gaps closed:

- [x] `test/sigra/admin_test.exs` — direct unit coverage for `Sigra.Admin.needs_review/1` (5 sampling points: both keys, locked-only, deleted-only, neither, empty map). New file.
- [x] `test/example/test/example_web/live/admin_user_filters_live_test.exs` — added two assertions proving the `needs_review=true` union deep-link reaches both the locked and deleted fixtures on the generated host. Modified.

All other phase requirements were covered by pre-existing infrastructure
(`users_query_test.exs`, `components_test.exs`, Playwright checkpoint/parity lanes, axe).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `chip_label("needs_review")` → "Needs review" filter chip label | GATE-01 | Private `defp` in `users_index_live.ex`; only reachable via full LiveView render. Cosmetic label; the underlying OR-filter behavior is fully covered by `users_query_test.exs` + the host integration assertion. Accepted at user direction. | Apply `?needs_review=true` on `/admin/users`; confirm the active-filter chip reads "Needs review". Visually exercised by `admin-checkpoints.spec.ts`. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (2 gaps filled)
- [x] No watch-mode flags
- [x] Feedback latency < 10s (ExUnit subset)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-05

---

## Validation Audit 2026-06-05

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved (automated) | 2 |
| Accepted manual-only | 1 |
| Escalated | 0 |

Gap 7 (`Sigra.Admin.needs_review/1` unit test) and Gap 8 (generated-host
`needs_review=true` deep-link assertion) filled green by gsd-nyquist-auditor.
Gap 9 (cosmetic `chip_label` private fn) accepted manual-only at user direction.
No implementation files modified.
