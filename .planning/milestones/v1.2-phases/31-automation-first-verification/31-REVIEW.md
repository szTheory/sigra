---
phase: 31-automation-first-verification
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - .github/workflows/ci.yml
  - scripts/ci/admin-acceptance-smoke.sh
  - scripts/ci/http-smoke.sh
  - test/example/priv/playwright/helpers/adminArtifacts.ts
  - test/example/priv/playwright/helpers/fixtures.ts
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-audit.spec.ts
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - test/example/priv/playwright/tests/admin-user-operations.spec.ts
  - test/example/priv/playwright/tests/impersonation.spec.ts
  - test/example/test/example_web/controllers/admin/audit_export_controller_test.exs
  - test/example/test/example_web/controllers/impersonation_controller_test.exs
  - test/sigra/admin/audit/query_test.exs
  - test/sigra/admin/authorizer_test.exs
  - test/sigra/plug/forbid_during_impersonation_test.exs
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 31: Code Review Report (iteration 3 — clean)

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 16
**Status:** clean (0 Critical / 0 Warning / 0 Info)

## Summary

Phase 31 is green after three review cycles.

- **Iteration 1** — initial review. Found 4 Warnings (WR-01..WR-04) + 6 Info (IN-01..IN-06).
- **Iteration 2** — after WR fix sweep. Verified WR-01..WR-04 resolved; Info items carried forward.
- **Iteration 3** — after Info fix sweep. Every IN-01..IN-06 fix verified by reading current source. Fresh-eyes pass on the 16-file scope (including the new `helpers/fixtures.ts`) found zero new findings and zero regressions.

## Verification of IN-01..IN-06

### IN-01 — RESOLVED

**File:** `scripts/ci/admin-acceptance-smoke.sh:154,206`
`SEED_FILE="${TMP_APP_DIR}/sigra_admin_acceptance_seed.exs"` is computed from the per-run `TMP_APP_DIR`; both the heredoc `cat > "${SEED_FILE}"` and the subsequent `mix run "${SEED_FILE}"` reference the same variable. Concurrent local runs on distinct `TMP_APP_DIR` values no longer collide.

### IN-02 — RESOLVED

- `scripts/ci/admin-acceptance-smoke.sh:31-34` — explicit `# test-only: deterministic Cloak key …` banner above `CLOAK_KEY`.
- `scripts/ci/admin-acceptance-smoke.sh:38-41` — explicit `# test-only: deterministic smoke admin password …` banner above `SIGRA_ADMIN_PASSWORD`, cross-referencing the Playwright fixture.
- `test/example/priv/playwright/helpers/fixtures.ts` (new) — single `export const TEST_PASSWORD`, leading comment block stating test-only rationale and cross-reference to `admin-acceptance-smoke.sh` so drift fails loudly at login.
- All five in-scope specs import `TEST_PASSWORD` and no longer contain the literal `CorrectHorseBatteryStaple123!`.

### IN-03 — RESOLVED

**File:** `scripts/ci/http-smoke.sh:70,102,110,120,135,148`
`EXTRA_CHECKS=0` initialized with a rationale comment; each of the four non-array probes (cookie-jar warmup, cookie-present, cookie reuse GET `/`, unauthenticated `/admin` denial) increments inline. Summary reads `total_checks=$(( ${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + EXTRA_CHECKS ))`. `bash -n` parses clean.

### IN-04 — RESOLVED

**File:** `test/example/test/example_web/controllers/impersonation_controller_test.exs:241,83,114`
`defp impersonation_token_for(user) do` is now arity-1. Call sites on lines 83 and 114 pass only `target`. The `admin` binding remains used at each site for `session_token_for(admin)`, so no dead bindings were introduced.

### IN-05 — RESOLVED

**File:** `test/example/priv/playwright/tests/admin-audit.spec.ts:146-149`
Tautological `expect(scopedCsv).toContain('organization_label')` (header-string assertion) replaced with `expect(scopedCsv).toContain(orgName)` where `orgName` lands in a row body. A preceding 3-line comment documents the header-vs-row distinction.

### IN-06 — RESOLVED

**Files:** `admin-audit.spec.ts:34`, `admin-checkpoints.spec.ts:49`, `admin-user-operations.spec.ts:41`, `impersonation.spec.ts:30`
All four `registerUser` helpers target the registration form by `form:has(input[name="user[password]"])` before `.first()`. A future additional form on `/users/register` would no longer silently retarget.

## Fresh-eyes pass

- **`helpers/fixtures.ts` (new):** single-export module, explicit test-only comment block, no dynamic evaluation. Safe.
- **Cross-reference coupling** between `admin-generated.spec.ts:26` (`adminPassword ?? TEST_PASSWORD`) and `admin-acceptance-smoke.sh:41` (`SIGRA_ADMIN_PASSWORD` default matches the same literal): both sides document the cross-reference; drift would fail loudly at login, not silently. Acceptable.
- **Four near-duplicate `registerUser` helpers** across specs are intentional per `helpers/adminArtifacts.ts:1-19` (Phase 31 direction: no page-object layer). Not a finding.
- **All iter-1 Warning fixes** (`ci.yml:13-14` permissions, `ci.yml:282,285` MATRIX_FLAGS indirection, `ci.yml:428,502,432-435,572-580` log redirects + failure dumps, `ci.yml:592-604,710-722` cp -n + src_count) still in place.
- No Critical or Warning issues found. No security regressions. No new logic errors.

---

_Reviewer: Claude (gsd-code-reviewer) · Iteration 3 · Depth: standard_
