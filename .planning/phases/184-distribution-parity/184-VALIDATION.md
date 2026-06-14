---
phase: 184
slug: distribution-parity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 184 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `184-RESEARCH.md` § Validation Architecture (all signals automated; zero-human verification target).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/sigra/install/features/admin_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 s quick / full suite per CLAUDE.md (live Postgres @ localhost:5432 required) |

> Golden-diff and the styled-host smoke are separately gated:
> - `mix test test/sigra/install/golden_diff_test.exs --only golden` (template↔fixture byte tree)
> - CI `generated_admin_playwright_smoke` (`ci.yml:952`) via `scripts/ci/admin-acceptance-smoke.sh --test all`
> - `scripts/ci/snapshot-canary-guard.sh` (empty-allowlist visual idempotency)

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/install/features/admin_test.exs` (fast, unit-only)
- **After every plan wave:** Run `mix test` (full ExUnit incl. golden-diff)
- **Before `/gsd:verify-work`:** Full suite green + CI Playwright styled-host job green + snapshot canary PASS
- **Max feedback latency:** ~5 seconds (quick), full suite within one run

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 184-01-01 | 01 | 0 | DIST-01 | — | N/A (CSS asset) | unit | `mix test test/sigra/install/features/admin_test.exs` + `grep -c 'var(--vt-' priv/templates/sigra.install/admin/sigra_admin.css` (expect 0) | ❌ W0 (new template + test) | ⬜ pending |
| 184-01-02 | 01 | 0 | DIST-01 (D-03 audit) | — | N/A | unit | `! grep -q 'var(--vt-' priv/templates/sigra.install/admin/sigra_admin.css && ! grep -q 'daisyui\|default\.css' priv/templates/sigra.install/admin/sigra_admin.css` | ❌ W0 | ⬜ pending |
| 184-02-01 | 02 | 1 | DIST-02 | — | N/A | unit | `mix test test/sigra/install/features/admin_test.exs` (files/1 tuple assertion) | ❌ W0 (new assertion) | ⬜ pending |
| 184-02-02 | 02 | 1 | DIST-03 | — | N/A | unit | `mix test test/sigra/install/features/admin_test.exs` (layout `<link>` injection assertion) | ❌ W0 (new assertion) | ⬜ pending |
| 184-03-01 | 03 | 1 | DIST-04 | — | N/A | integration | `mix test test/sigra/install/features/admin_test.exs` (DIST-05 byte-compare proves DIST-04 by implication; example `app.css` has no `@layer sg-*`) | ❌ W0 (new example copy) | ⬜ pending |
| 184-03-02 | 03 | 1 | DIST-05 (template≡example) | — | N/A | unit | `mix test test/sigra/install/features/admin_test.exs` (new `DIST-05 example≡template byte-parity` describe block) | ❌ W0 (new test) | ⬜ pending |
| 184-03-03 | 03 | 1 | DIST-05 (template≡fixture) | — | N/A | integration | `mix test test/sigra/install/golden_diff_test.exs --only golden` | ❌ W0 (new fixture file) | ⬜ pending |
| 184-04-01 | 04 | 2 | DIST-06 | — | N/A | E2E | CI `generated_admin_playwright_smoke` → `scripts/ci/admin-acceptance-smoke.sh --test all` (styled assertion in `admin-generated.spec.ts`) | ❌ W0 (new assertion) | ⬜ pending |
| 184-04-02 | 04 | 2 | DIST-06 (D-11 canary) | — | N/A | E2E | `scripts/ci/snapshot-canary-guard.sh` (empty allowlist stays green) | ✅ existing harness | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Wave numbers above are the validation-map's best estimate; the authoritative wave assignment lives in each PLAN.md frontmatter.

---

## Wave 0 Requirements

New artifacts this phase introduces (all net-new; existing install-test infrastructure already covers the assertion mechanics):

- [ ] `priv/templates/sigra.install/admin/sigra_admin.css` — extracted canonical template (DIST-01)
- [ ] `test/example/priv/static/assets/sigra_admin.css` — byte-guarded example copy (DIST-04)
- [ ] `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — golden fixture copy (DIST-05 template↔fixture)
- [ ] New `describe "DIST-05 example≡template byte-parity"` test in `test/sigra/install/features/admin_test.exs`
- [ ] New `files/1` tuple assertion (DIST-02) in `test/sigra/install/features/admin_test.exs`
- [ ] New `def admin/1` `<link>` injection assertion (DIST-03) in `test/sigra/install/features/admin_test.exs`
- [ ] Styled-host assertion (DIST-06) in `test/example/priv/playwright/tests/admin-generated.spec.ts`

> No framework install needed — ExUnit + Playwright already present. `templates_layout_test.exs` core-file count is **unaffected** (new file lands in `admin/`, not `core/`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|

*None — all phase behaviors have automated verification. DIST-06 styled-host proof uses a computed-style assertion (`getComputedStyle(document.documentElement).getPropertyValue('--sg-color-brand').trim() === '#c2410c'`, per research recommendation) rather than a human eyeball.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < ~5s (quick) / full suite per wave
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
