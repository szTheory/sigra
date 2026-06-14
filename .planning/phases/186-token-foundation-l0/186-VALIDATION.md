---
phase: 186
slug: token-foundation-l0
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 186 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 186-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (ExUnit)** | ExUnit (built-in Elixir) |
| **Framework (Playwright)** | Playwright (`test/example/priv/playwright`) — admin-design + admin-theme lanes |
| **Config file** | `mix.exs` (ExUnit); `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/install/features/admin_test.exs` |
| **Full suite command** | `mix test` + `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts tests/admin-theme.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` |
| **Estimated runtime** | ExUnit quick ~5–15s; full Playwright lane ~minutes (requires Postgres + booted example server) |

---

## Sampling Rate

- **After every task commit:** `mix test test/sigra/install/features/admin_test.exs` (ExUnit only; fast, no server)
- **After every plan wave:** `mix test` (full ExUnit) + Playwright admin-design lane (3 projects) + admin-theme assertions
- **Before `/gsd:verify-work`:** Full suite green + axe 0 violations in all 3 admin-design projects + `bash scripts/ci/quality-ledger-monotonic.sh` passing + `bash scripts/ci/snapshot-canary-guard.sh` passing
- **Max feedback latency:** ~15s (ExUnit quick loop)

---

## Per-Task Verification Map

> Populated during execution once plan/task IDs exist. Requirement→mechanism map below is the binding contract.

| Req ID | Behavior (truth claim) | Test Type | Automated Command | File Status |
|--------|------------------------|-----------|-------------------|-------------|
| TOKEN-01 | Each token carries rationale + brand-ref in `admin-token-reference.md` | Doc + L0 ledger row | `bash scripts/ci/quality-ledger-monotonic.sh` | ❌ W0: create `guides/reference/admin-token-reference.md` |
| TOKEN-01 | L0 row in quality ledger with bare-integer Tier (`0\|1\|2`) | CI monotonic guard | `bash scripts/ci/quality-ledger-monotonic.sh` | ✅ guard exists; ❌ W0: add L0 row |
| TOKEN-02 | All rendered color pairs pass WCAG AA (light + dark) | axe (wcag2a+wcag2aa) | `npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-dark` | ✅ spec exists |
| TOKEN-02 | Tone-on-soft pairs pass AA (alpha-composited; axe skips) | computed-style `contrastRatio()` | `npx playwright test tests/admin-theme.spec.ts` | ❌ W0: extend `admin-theme.spec.ts` |
| TOKEN-03 | Motion budget documented with emilkowal.ski rationale | Doc review | N/A — recorded in `admin-token-reference.md` + L0 ledger | ❌ W0: motion section in token reference |
| TOKEN-04 | System dark path ≡ explicit-toggle dark path (`--sg-*` set identical) | ExUnit parity assertion (D-11) | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0: add D-11 describe block |
| TOKEN-04 | Auth ember-family values coherent with admin equivalents | ExUnit cross-check / documented | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0: add auth parity check |
| THEME-01 | Admin renders correctly Light/Dark/System (no hardcoded values) | Playwright axe (3 projects) | `npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` | ✅ specs + projects exist |
| THEME-01 | Dark `brand-strong` is `#fdba74` (not light `#9a3412`) | ExUnit assertion on extracted dark block | `mix test test/sigra/install/features/admin_test.exs` | ❌ W0: include in D-11 parity block |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/reference/admin-token-reference.md` — new file; TOKEN-01 rationale + brand-ref + motion (TOKEN-03)
- [ ] L0 row in `guides/reference/admin-quality-ledger.md` — bare-integer tier; TOKEN-01 ledger contract
- [ ] D-11 `describe` block in `test/sigra/install/features/admin_test.exs` — TOKEN-04 System↔explicit-toggle parity + THEME-01 `#fdba74` assertion
- [ ] `contrastRatio()` tone-soft extension in `test/example/priv/playwright/tests/admin-theme.spec.ts` — TOKEN-02 alpha-composited pairs (ok/warn/risk/info on notice + status-pill)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Per-token rationale prose is accurate/sensible | TOKEN-01, TOKEN-03 | Editorial quality of written rationale is not machine-assertable | Doc review of `admin-token-reference.md`; ledger row + monotonic guard prove the row exists at the claimed tier |

*All structural truth claims (parity, AA, ledger tier, theme correctness) have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
