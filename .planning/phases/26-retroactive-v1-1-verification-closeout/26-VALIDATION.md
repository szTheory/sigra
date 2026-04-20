---
phase: 26
slug: retroactive-v1-1-verification-closeout
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-16
---

# Phase 26 - Validation Strategy

> Per-phase validation contract for the verification-closeout work.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Focused ExUnit suites, Playwright smoke where already shipped, shell artifact checks |
| **Config file** | `config/test.exs`, `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | Focused per-task command bundles below |
| **Full suite command** | Not required for closeout; rely on focused current-evidence slices tied to the missing requirements |
| **Estimated runtime** | 30-180 seconds per command bundle, plus any local example-app/browser startup time |

---

## Sampling Rate

- **After each verification-report task:** Run that task's focused command bundle and cite the exact commands in the report.
- **Before updating the milestone audit:** Confirm all four new `VERIFICATION.md` files exist and cover their requirement IDs explicitly.
- **Before ending Phase 26:** Re-scan `.planning/REQUIREMENTS.md` and `.planning/v1.1-MILESTONE-AUDIT.md` for stale partial-gap text.
- **Max feedback latency:** 180 seconds for each focused evidence bundle; longer browser setup is acceptable only when Phase 23 smoke requires a live example app.

---

## Per-Task Verification Map

| Task | Requirements | Secure Behavior | Test Type | Automated Command | Status |
|------|--------------|-----------------|-----------|-------------------|--------|
| 26-01-01 | ORG-02, ORG-UPGRADE-01, ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03 | Upgrade/install evidence for Phase 18 is re-run and archived in a standalone verification report | focused ExUnit + artifact write | `bash -lc 'set -euo pipefail; export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test; mix test test/upgrade_test.exs test/sigra/upgrade/backfill_test.exs test/sigra/install/features/organizations_test.exs test/mix/tasks/sigra.install_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1'` | ⬜ pending |
| 26-01-02a | PK-01, PK-03, PK-04, PK-05, PK-07, PK-08 | Phase 19 passkey data-layer requirements are re-verified against current tests before writing `19-VERIFICATION.md` | focused ExUnit | `bash -lc 'set -euo pipefail; export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test; mix test test/sigra/passkeys_test.exs test/sigra/passkeys/registration_test.exs test/sigra/passkeys/authentication_test.exs test/sigra/passkeys/sign_count_policy_test.exs test/sigra/passkeys/user_passkey_test.exs test/sigra/passkeys/migration_test.exs test/sigra/passkeys/cose_serialization_test.exs test/sigra/passkeys/wax_roundtrip_test.exs --max-failures 1'` | ⬜ pending |
| 26-01-02b | PK-02 | Phase 22 passkey opt-out and omission behavior is re-verified against current generator/install tests | focused ExUnit | `bash -lc 'set -euo pipefail; export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test; mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs --max-failures 1'` | ⬜ pending |
| 26-01-02c | DX-01, DX-02, DX-03, DX-04, DX-05, DX-06, DX-07, DX-08, DX-09 | Phase 23 docs/helper/browser evidence is re-verified, with local execution and CI/workflow inspection separated clearly in the report | ExUnit + static checks + optional Playwright rerun | `bash -lc 'set -euo pipefail; export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test; mix test test/sigra/testing_test.exs test/sigra/testing/assert_audit_logged_test.exs test/sigra/guides_dx02_test.exs test/upgrade_test.exs --max-failures 1; mix docs --warnings-as-errors; rg -n "playwright|install_matrix|passkey-login\\.spec\\.ts|passkey-options\\.spec\\.ts|organizations\\.spec\\.ts" .github/workflows/ci.yml test/example/priv/playwright/tests'` | ⬜ pending |
| 26-01-03 | All Phase 26 requirements | Requirement ledger and milestone audit reflect the new verification truth, with stale audit gaps removed | shell artifact checks | `bash -lc 'set -euo pipefail; test -f .planning/phases/18-backfill-organizations-generator-wiring/18-VERIFICATION.md; test -f .planning/phases/19-passkey-schema-contexts/19-VERIFICATION.md; test -f .planning/phases/22-passkeys-generator-wiring/22-VERIFICATION.md; test -f .planning/phases/23-docs-ci-smoke-upgrade-guide/23-VERIFICATION.md; rg -n "^- \\[x\\] \\*\\*(ORG-02|ORG-UPGRADE-01|ORG-UPGRADE-02|ORG-UPGRADE-03|PK-01|PK-02|PK-03|PK-04|PK-05|PK-07|PK-08|GEN-03|DX-01|DX-02|DX-03|DX-04|DX-05|DX-06|DX-07|DX-08|DX-09)\\*\\*:" .planning/REQUIREMENTS.md | wc -l | grep -qx "21"'` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 23 browser smoke still represents the intended org + passkey journeys without over-expanding scope | DX-07 | Human review is needed to keep the browser suite focused on the release-gate paths rather than drifting into a broad permutation matrix | Review the final `23-VERIFICATION.md` evidence list and confirm it cites only the shipped organizations/passkeys browser journeys |
| Milestone audit prose matches the new state rather than merely updating counts | All | The numerical update is automatable; the final narrative still needs human judgment | Read `.planning/v1.1-MILESTONE-AUDIT.md` after refresh and confirm the recommendation matches the actual remaining blockers, if any |

---

## Validation Sign-Off

- [x] All planned work has an automated verification target
- [x] Sampling continuity is defined across report generation and final audit refresh
- [x] No watch-mode flags
- [x] Feedback latency target documented
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready for execution
