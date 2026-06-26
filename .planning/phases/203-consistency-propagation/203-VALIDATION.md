---
phase: 203
slug: consistency-propagation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-26
---

# Phase 203 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Per-Task Verification Map is populated from each plan's `<automated>` verify
> block after planning (per RESEARCH.md `## Validation Architecture`).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Playwright (admin browser specs) |
| **Config file** | `mix.exs` (ExUnit) / `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/admin/` |
| **Full suite command** | `mix test` + admin Playwright projects (chromium/dark/mobile) |
| **Estimated runtime** | ~varies (ExUnit fast; Playwright capture/interaction lanes longer) |

---

## Sampling Rate

- **After every task commit:** Run `mix test {touched admin test files}` (or `mix compile --warnings-as-errors` for markup-only tasks)
- **After every plan wave:** Run `mix test test/sigra/admin/` + affected Playwright specs
- **Before `/gsd-verify-work`:** Full suite + admin browser specs green; recapture idempotency proven; monotonic guard green against `origin/main`; CSS triple-copy md5 parity
- **Max feedback latency:** ExUnit < ~60s; browser capture/interaction lanes run out-of-band by design

---

## Per-Task Verification Map

> Populated by the planner from each plan's `<automated>` verify block. Required gates this phase exercises (per RESEARCH.md `## Validation Architecture`):
> - D-06 branding `#restore-defaults-overlay` modal-interaction Playwright spec (7 APG gates + axe-while-open) — the **single net-new test** and a **hard prerequisite** for the D-08 branding overlay-axe/APG ledger evidence.
> - Snapshot recapture idempotency via `scripts/ci/snapshot-recapture-gate.sh` for `global-overview` + `org-overview` slugs (NOT MG-7 — its markup carries only a role pill); canaries byte-stable; allowlists left empty for Phase 204's terminal reset.
> - Quality-ledger monotonic guard (`scripts/ci/quality-ledger-monotonic.sh --base origin/main`) — bare single `^[012]$` column-4 integer parse; 1→2 ratchet verified forward-only.
> - CSS triple-copy golden-diff lockstep — three byte-identical `sg-*` copies (shared md5), install golden-diff gate (184→185 regression class).
> - glossary-clean proxy (`test/sigra/admin/glossary_test.exs`) — confirmed to scope all three target pages.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 203-01-01 | 01 | 1 | PROP-01 | T-203-01-T | HEEx auto-escape; pure pill deletion, no raw/1 | compile+grep | `mix compile --warnings-as-errors && grep -c 'data-tone=ok>Confirmed' organization_live.ex` (expect 0) | ✅ | ⬜ pending |
| 203-01-02 | 01 | 1 | PROP-01 | — | demote coverage KPI; no unused-binding warning | compile+grep | `mix compile --warnings-as-errors && grep -c overview-metric-auth-coverage index_live.ex` (expect 0) | ✅ | ⬜ pending |
| 203-01-03 | 01 | 1 | PROP-01 | — | glossary-clean; zero new CSS (D-12 untripped) | unit+md5 | `mix test test/sigra/admin/glossary_test.exs && md5 (three sigra_admin.css) sort -u` (expect 1 hash) | ✅ | ⬜ pending |
| 203-02-01 | 02 | 1 | PROP-01 | T-203-02 | promoted components attr/slot; no raw/1 | compile+grep | `mix compile --warnings-as-errors` + privates_remaining=0 / public_added=3 | ✅ | ⬜ pending |
| 203-02-02 | 02 | 1 | PROP-01 | T-203-02-CSS | CSS triple-copy byte parity; golden-diff | golden+md5 | `md5 (three css) sort -u` (1 hash) + `mix test test/sigra/install/golden_diff_test.exs` (phx_new 1.8.7) | ✅ | ⬜ pending |
| 203-03-01 | 03 | 1 | PROP-01 | T-203-03-a11y | 7 APG focus-trap/restore + axe-while-open; branding selectors | e2e | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test admin-modal-interaction.spec.ts --project=chromium` | ⚠️ Wave 0 — add branding case | ⬜ pending |
| 203-04-01 | 04 | 2 | PROP-02 | T-203-04-doc | Workbench archetype documented forward; glossary-clean | grep+unit | `grep -c 'Branding/Workbench Archetype' admin-design-contract.md && mix test test/sigra/admin/glossary_test.exs` | ✅ | ⬜ pending |
| 203-04-02 | 04 | 2 | PROP-02 | — | additive UI-principles/Overview touch-up; glossary-clean | unit | `mix test test/sigra/admin/glossary_test.exs && git diff --stat (two docs)` | ✅ | ⬜ pending |
| 203-05-01 | 05 | 2 | PROP-01 | T-203-05-R/T | bare-2 ratchet; honest N/A proxies; PAGE-04 fold; monotonic guard | guard | `git fetch origin main; bash scripts/ci/quality-ledger-monotonic.sh --base origin/main && grep three cells` | ✅ | ⬜ pending |
| 203-05-02 | 05 | 2 | PROP-01 | T-203-05-canary | idempotent recapture; MG/canary byte-stable; allowlists empty | gate | `RECAPTURE_DRYRUN=1 bash scripts/ci/snapshot-recapture-gate.sh global-overview org-overview && bash -n scripts/ci/snapshot-recapture-gate.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements (ExUnit admin LiveView/glossary tests + Playwright admin specs already exist). **Net-new:** the D-06 branding `#restore-defaults-overlay` modal-interaction spec extending `admin-modal-interaction.spec.ts` (interaction-only, no screenshots) — a first-class task, not Wave-0 scaffolding.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tier-2 motion-tokens / density-rhythm / target-size ≥24px proxies | PROP-01 | Documented-as-manual Tier-2 Add-on proxies (admin-fractal-scorecard.md:135-167) | Cite as manual proxy evidence in the three ratcheted ledger cells per D-08 |

*Remaining behaviors have automated verification (ExUnit + Playwright modal-interaction + glossary + golden-diff + recapture idempotency + monotonic guard).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (all 10 tasks carry an automated command; the single net-new D-06 test is a first-class task in Plan 03)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has one)
- [x] Wave 0 covers all MISSING references (only the D-06 branding modal case is net-new; it is a first-class task, not scaffolding)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (ExUnit compile/unit/grep tasks; Playwright/recapture lanes out-of-band by design)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — Per-Task Verification Map populated from plan `<automated>` blocks; every task has an automated verify.
