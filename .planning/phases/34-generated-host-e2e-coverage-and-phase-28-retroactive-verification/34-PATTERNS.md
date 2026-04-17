# Phase 34 — Pattern Map

Analogs for executor `read_first` alignment.

## Playwright: generated host

| New behavior | Closest analog | Notes |
|--------------|----------------|-------|
| Platform-admin session + navigation | `test/example/priv/playwright/tests/admin-generated.spec.ts` — `logIn`, viewport blocks | Reuse env-driven emails/passwords |
| Sudo + impersonation start | `test/example/priv/playwright/tests/impersonation.spec.ts` — `confirmSudo`, `openUserDetail`, `waitForLiveViewReady` | Generated host uses same auth routes; target user must exist in **smoke seed** |
| Audit CSV export | `test/example/priv/playwright/tests/admin-audit.spec.ts` — response headers + body substring | Prefer global `/admin/audit/export.csv` after login |

## Bash smoke

| Extension | Closest analog | Notes |
|-----------|----------------|-------|
| `case "${TEST_TARGET}"` branches | `admin-acceptance-smoke.sh` lines 319–333 (`chrome`, `errors`) | Add `audit-export`, `impersonation-controller`; keep `all` as superset |
| Parity probes before Playwright | `GEN_PARITY_FAIL` / `gen_expect_non_5xx` block | New `--test` values must **not** skip this block |

## Verification doc

| Target | Closest analog |
|--------|----------------|
| `28-VERIFICATION.md` | `.planning/phases/30-audit-exploration-and-export/30-VERIFICATION.md`, `.planning/phases/32-generated-installer-admin-surface-parity/32-VERIFICATION.md` |
| Spot-check commands | `.planning/phases/28-user-operations-surface/28-VALIDATION.md` |

## CI

| Change | Closest analog |
|--------|----------------|
| Job timeout / retries env | `.github/workflows/ci.yml` — `generated_admin_playwright_smoke` job block (~655+) | Add `timeout-minutes`; optional `env: PLAYWRIGHT_RETRIES: 1` |
