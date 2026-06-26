---
phase: 203
slug: consistency-propagation
status: draft
nyquist_compliant: false
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
| _populated by planner_ | — | — | PROP-01 / PROP-02 | — | — | — | — | — | ⬜ pending |

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (none expected — net-new D-06 test is a first-class task)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (ExUnit; Playwright/recapture lanes out-of-band by design)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending — Per-Task Verification Map to be populated from plan `<automated>` blocks after planning.
