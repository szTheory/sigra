---
phase: 185
slug: audit-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 185 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 185-RESEARCH.md "## Validation Architecture". This phase builds
> *instruments*; each instrument must be proven to FUNCTION, not merely exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`mix test`) + Playwright (`npx playwright test`) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/installer/design_gallery_isolation_test.exs` |
| **Full suite command** | `mix test && (cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts)` |
| **Estimated runtime** | ~15s quick (no Postgres) · ~3-5 min full (3 Playwright projects + axe) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/installer/design_gallery_isolation_test.exs` (instant, no Postgres, guards D-04 isolation)
- **After every plan wave:** Run full `mix test` + design gallery Playwright run across `admin-design-{chromium,mobile,dark}`
- **Before `/gsd:verify-work`:** Full suite green + `scripts/ci/snapshot-canary-guard.sh` design invocation + `scripts/ci/quality-ledger-monotonic.sh` both pass
- **Max feedback latency:** ~15s (quick) / ~300s (full)

---

## Per-Requirement Verification Map

| Req ID | Behavior proven | Test Type | Automated Command | File Exists |
|--------|-----------------|-----------|-------------------|-------------|
| INFRA-01 | Gallery route renders under real admin shell with all boards | Playwright smoke | `npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` | ❌ W0 |
| INFRA-01 | Gallery compiles out in `MIX_ENV=test`/prod (dev_routes gate) | mix compile assertion | `MIX_ENV=test mix compile --no-deps-check` + assert `/admin/_design` absent | ❌ W0 |
| INFRA-01 | D-04: no `*design*` artifact in `priv/templates/sigra.install/` | ExUnit | `mix test test/sigra/installer/design_gallery_isolation_test.exs` | ❌ W0 |
| INFRA-02 | Element-scoped composite board PNG per component/group across 3 projects | Playwright visual | `npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark}` | ❌ W0 |
| INFRA-02 | 0 axe WCAG2A+AA violations per board | Playwright axe | same spec run (`assertNoAxeViolations` inside each board capture) | ❌ W0 |
| INFRA-03 | `snapshot-allowlist-design` exists, steady-state empty | Bash | `grep -v '^#' .../snapshot-allowlist-design | grep -q . && exit 1 || exit 0` | ❌ W0 |
| INFRA-03 | Canary guard recognizes `-admin-design-*` slugs; fails on canary change | Bash fixture test | `SNAP_DIR=<fixture> bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist snapshot-allowlist-design --canary <canary-board>` | ❌ W0 |
| INFRA-04 | Ledger exists; every tier cell is a 0/1/2 integer | Bash awk parse | parse `guides/reference/admin-quality-ledger.md` tier column → all `^[012]$` | ❌ W0 |
| INFRA-04 | All initial tiers = 1 (Ratified baseline floor) | Bash awk parse | tier column all `== 1` on first commit | ❌ W0 |
| INFRA-05 | Monotonic guard exits 0 on identical ledger (no-op auto-green) | Bash synthetic fixture | temp branch w/ identical ledger → `bash scripts/ci/quality-ledger-monotonic.sh --base <branch>` exits 0 | ❌ W0 |
| INFRA-05 | Monotonic guard exits 1 on any tier decrease | Bash synthetic fixture | base tier=2, working-tree tier=1 → guard exits 1 | ❌ W0 |
| INFRA-05 | `quality_ledger_monotonic` registered in `ci-gate` `needs:` | grep | `grep quality_ledger_monotonic .github/workflows/ci.yml` | ❌ W0 |
| INFRA-06 | Rubric exists with D1–D11 + per-level add-ons | grep/awk | `grep -c 'D[0-9]' guides/reference/admin-fractal-scorecard.md` ≥ 11 | ❌ W0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Files that must exist (at least as test/skeleton structure) before implementation tasks run:

- [ ] `test/sigra/installer/design_gallery_isolation_test.exs` — D-04 ExUnit contract guard (filesystem glob over `priv/templates/sigra.install/`)
- [ ] `test/example/priv/playwright/tests/admin-design.spec.ts` — board-snapshot + axe spec skeleton
- [ ] `test/example/priv/playwright/snapshot-allowlist-design` — empty allowlist (comments-only)
- [ ] `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard script
- [ ] `guides/reference/admin-quality-ledger.md` — ledger with initial tier=1 rows
- [ ] `guides/reference/admin-fractal-scorecard.md` — rubric content

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual fidelity of board PNGs (are they human-meaningful?) | INFRA-02 | First-time baseline capture has no prior reference; correctness of *what* is rendered is a judgment call | Reviewer eyeballs the captured `<board>-admin-design-*.png` baselines once; subsequent runs are fully automated diff |

*All other phase behaviors have automated verification (Playwright, ExUnit, bash fixtures, grep).*

---

## Validation Sign-Off

- [ ] All requirements have an `<automated>` verify or Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (6 net-new instrument files)
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s (full) / < 15s (quick)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
