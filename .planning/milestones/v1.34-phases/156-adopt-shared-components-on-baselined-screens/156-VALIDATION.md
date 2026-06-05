---
phase: 156
slug: adopt-shared-components-on-baselined-screens
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 156 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `156-RESEARCH.md` § Validation Architecture (all commands verified against the live repo).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`mix test`) + Playwright (`npx playwright test`) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/admin/components_test.exs` (Phase-155 component goldens — must stay green) |
| **Full suite command** | `mix test` (lib unit + integration; needs live Postgres at localhost:5432) |
| **Estimated runtime** | ExUnit goldens ~5s · full ExUnit ~minutes · checkpoint spec ~30–60s |

**Server-dependent gates (require booted example app on port 4000):**
- Checkpoint spec: `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark`
- Parity smoke: `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh` (scaffolds fresh host on port 4017)

---

## Sampling Rate

- **After every screen-migration commit:** Run `mix test test/sigra/admin/` (component goldens + LiveView tests — catches name-collision / shadow defp regressions immediately).
- **After COHR-04 scope-ribbon work on a slug:** Run the checkpoint spec for the affected slug; review HTML report before any re-record.
- **After each intended re-record:** `npx playwright show-report` → confirm diff is the named delta → `--update-snapshots` → commit the 12 `.png` files with the code.
- **Phase gate (before `/gsd:verify-work`):** Full ExUnit + full checkpoint spec (4 slugs re-recorded, `impersonation-banner` byte-green) + `admin-acceptance-smoke.sh` green.
- **Max feedback latency:** ~5s (component goldens) per task commit; never 3 consecutive component-touching tasks without a `mix test test/sigra/admin/` sample.

---

## Per-Task Verification Map

> Task IDs are TBD until plans are written; rows are keyed by requirement and will be refined by `gsd-nyquist-auditor` once PLAN.md tasks exist. Every COHR requirement already has an existing automated gate (no Wave 0 test-infrastructure build needed).

| Req ID | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|--------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| COHR-01 | — | No duplicated private `defp` component defs remain; call sites resolve to `Sigra.Admin.Components` (no shadowing `defp`) | N/A — UI migration, no security path | compile + ExUnit | `mix test test/sigra/admin/components_test.exs` | ✅ | ⬜ pending |
| COHR-02 | — | `UserShowLive` identity header renders via open `sg-page-header` archetype | N/A | Playwright snapshot + axe | checkpoint spec (`user-detail` ×3 — intended re-record) | ✅ | ⬜ pending |
| COHR-03 | — | `<.page_back>` consumes `return_to` on leaf screens only | N/A | Playwright snapshot | checkpoint spec (`user-detail`) | ✅ | ⬜ pending |
| COHR-04 | — | `<.scope_ribbon>` present on every list + leaf screen; scope prose removed from `sg-page-copy` | N/A | Playwright snapshot + axe | checkpoint spec (`global-user-index`, `org-scoped-admin`, `audit-explorer`, `user-detail` ×3 — intended re-records) | ✅ | ⬜ pending |
| COHR-05 | — | Alerts/flashes render through `<.notice>` (`data-tone` atom); no ad-hoc `sg-list-row` alert rows | N/A | ExUnit golden + Playwright byte-green | `mix test test/sigra/admin/components_test.exs` | ✅ | ⬜ pending |
| COHR-06 | — | Empty states render through `<.empty_state>`; structure/spacing consistent | N/A | Playwright snapshot | checkpoint spec | ✅ | ⬜ pending |
| D-08 (CSS) | — | `.sg-list-row` / `.sg-notice` tone rules merged to shared selector inside `@layer sg-components`; zero rendered-byte change | N/A | Playwright byte-green (all 5 slugs tone rendering) | checkpoint spec | ✅ | ⬜ pending |
| D-09 (parity) | — | `admin-generated` parity lane stays green | N/A | smoke script | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Byte-green invariant (Gate 3 / SC-7):** `impersonation-banner` ×3 MUST stay byte-green — it is the canary that proves no unintended pixel drift leaked in. Exactly 4 slugs ×3 projects (`user-detail`, `global-user-index`, `org-scoped-admin`, `audit-explorer`) may re-record, and only after HTML-report review confirms the diff is the named intended delta.

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* The Phase-155 ExUnit component goldens (`test/sigra/admin/components_test.exs`), the Playwright checkpoint spec with axe wired via `assertCheckpointScreenshot` (`withTags(['wcag2a','wcag2aa'])`), and the `admin-generated` parity smoke all already exist. No framework install or new test scaffold is required — this phase samples against gates Phase 155 left green.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Intended visual-delta confirmation before re-record | COHR-02, COHR-04, SC-7 | A snapshot diff cannot self-classify "intended" vs "regression" — a human must confirm the HTML diff shows ONLY the named delta (ribbon addition / boxed-card → open-header) | `npx playwright show-report` after a failing checkpoint run; inspect each failing slug's diff; reject if any unexpected change; only then `--update-snapshots` |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All requirements have an existing automated gate (no Wave 0 build needed)
- [x] Sampling continuity: `mix test test/sigra/admin/` after each component-touching commit
- [x] Wave 0 covers all MISSING references (none missing — all gates pre-exist)
- [x] No watch-mode flags
- [x] Feedback latency < 10s for the per-commit component-golden sample
- [ ] `nyquist_compliant: true` — set by `gsd-nyquist-auditor` after per-task rows are filled against final PLAN.md task IDs

**Approval:** pending
