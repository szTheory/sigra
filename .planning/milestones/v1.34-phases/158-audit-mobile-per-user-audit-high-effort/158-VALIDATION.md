---
phase: 158
slug: audit-mobile-per-user-audit-high-effort
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
---

# Phase 158 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 158-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + `render_component` HEEx goldens + Playwright (`admin-checkpoints.spec.ts`) + axe-core |
| **Config file** | `mix.exs` (test); `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/admin/components_test.exs` (component goldens) |
| **Full suite command** | `mix test` (requires live Postgres at localhost:5432, postgres/postgres) |
| **Playwright checkpoint command** | `cd test/example && npx playwright test admin-checkpoints` (3 projects: chromium / mobile / dark) |
| **Estimated runtime** | ExUnit ~60s; Playwright checkpoint lane ~2–4 min |

---

## Sampling Rate

- **After every task commit:** Run the relevant `render_component` golden test for the touched component/LiveView
- **After every plan wave:** Run `mix test` (full ExUnit) + the Playwright checkpoint lane for affected slugs
- **Before `/gsd:verify-work`:** Full `mix test` green + `admin-checkpoints` green across all 3 projects with axe green
- **Max feedback latency:** ~60s for golden layer; Playwright is the slower confirming layer

---

## Per-Task Verification Map

> Populated by gsd-planner against the final task breakdown. Each task maps to its
> golden/Playwright/axe signal per the RESEARCH Validation Architecture.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | AUDX-01/02/03 | — | N/A (read-only audit surfaces) | golden / e2e | `mix test` + `npx playwright test admin-checkpoints` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No new framework install — ExUnit, Playwright, and axe harness already exist.
- [ ] Confirm `render_component` golden test file for `Sigra.Admin.Components` exists (planner: locate via RESEARCH) so the new `audit_row/1` gets a structural/byte golden before Playwright.

*Existing infrastructure covers all phase requirements — no Wave 0 framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Deliberate baseline re-record review | GATE-01 | Each `audit-explorer` ×3 (and any `user-detail`/`user-audit`) re-record must be reviewed against the Playwright HTML report before committing — an intended delta, not a blanket reset | Open the HTML report, confirm each diff is the named delta (mobile cards / above-fold chip row / impersonation `data-tone=info`), then `--update-snapshots` only the reviewed slugs |

*All functional behaviors have automated verification (golden + Playwright + axe). The only manual gate is human review of intended visual deltas before snapshot commit.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (golden layer)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
