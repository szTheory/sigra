---
phase: 31-automation-first-verification
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - .github/workflows/ci.yml
  - scripts/ci/admin-acceptance-smoke.sh
  - scripts/ci/http-smoke.sh
  - test/example/priv/playwright/helpers/adminArtifacts.ts
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
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 31: Code Review Report

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

Phase 31 wires the automation-first verification seams: GitHub Actions CI, two shell smoke scripts, Playwright admin specs + checkpoint partitioning, and several direct-path ExUnit suites. Overall the work is careful — scripts use `set -euo pipefail`, the Playwright project partitioning is well-thought-out, test files have clear comments mapping to plan decisions, and negative-case coverage is strong (e.g. malformed cursor, out-of-scope org, unauthenticated export).

The issues found are non-blocking: a missing default-least-privilege `permissions` block in the workflow, a `${{ matrix.flags }}` expansion pattern that is safe today but is the same pattern GitHub documents as the common injection vector, a few naming-overwrite risks in the artifact collection glob, hardcoded test-only secrets that should carry a "test-only" comment to prevent future copy-paste into real envs, and a handful of style/test-isolation observations. No critical security, correctness, or data-loss issues were identified in the changes under review.

## Warnings

### WR-01: GitHub Actions workflow has no `permissions:` block (default GITHUB_TOKEN is broadly scoped)

**File:** `.github/workflows/ci.yml:1-9`
**Issue:** The workflow declares no `permissions:` at the top level nor per-job. GITHUB_TOKEN therefore falls back to the repository's default, which in many repos is `contents: write` (legacy default) or even broader. This CI run only needs to read the repo and upload artifacts — it does not push, release, or write issues/PRs. Least-privilege CI tokens are an OWASP-aligned best practice and block a category of supply-chain-style abuse where a compromised action (or `mix archive.install`) could mutate the repo.

**Fix:**
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  ...
```
If any single job needs more (none appear to), override in that job only.

### WR-02: `${{ matrix.flags }}` interpolated directly into a `run:` shell command

**File:** `.github/workflows/ci.yml:269`
**Issue:** `run: mix sigra.install Accounts User users ${{ matrix.flags }} --yes` expands a workflow expression into a `run:` block. The matrix values are currently controlled by the repo itself (so this is not exploitable by a PR author today), but this is the exact pattern GitHub's "Security hardening for GitHub Actions" doc flags as the common injection vector — it's trivially easy for a future maintainer to add a matrix value sourced from `github.event.*` or a comment and inherit command-injection. Safer to pipe the value through an `env:` step-level variable, which is NOT shell-expanded by GitHub at template time.

**Fix:**
```yaml
- name: Run sigra.install with matrix flags
  working-directory: tmp_app
  env:
    MIX_ENV: test
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
    MATRIX_FLAGS: ${{ matrix.flags }}
  run: |
    # shellcheck disable=SC2086 -- flags are an intentional space-separated list
    mix sigra.install Accounts User users $MATRIX_FLAGS --yes
```
The env-var-indirection pattern prevents the interpolation from ever landing inside the shell string literally.

### WR-03: `find -exec cp` into a flat directory silently overwrites on basename collisions

**File:** `.github/workflows/ci.yml:555-557` and `.github/workflows/ci.yml:664-666`
**Issue:** `find test-results -type f -name 'admin-*.png' -exec cp {} artifacts/admin-checkpoints/ \;` flattens every matching PNG from nested `test-results/<project>/<test>/` directories into one output directory. `adminArtifactName` embeds the project slug, so distinct lanes produce distinct basenames, but: (a) Playwright may also write its own `test-failed-*.png` or retry screenshots that happen to match `admin-*.png` if a test name starts with "admin", and (b) if two tests within the same project ever share a logical name (a real risk if `captureAdminCheckpoint` is called twice with the same `name` in one test), the second `cp` silently overwrites the first. The reviewer artifact contract in `adminArtifacts.ts` says "a stable artifact name of the form `admin-<slug>-<project>-<slug>.png` that does not vary run-to-run" — a silent overwrite would make reviewers believe the earlier checkpoint succeeded identically to the later one.

**Fix:** either `cp -n` (no-clobber, surface conflicts as cp warnings) and `grep` the step log for "not overwriting", or preserve directory structure with `rsync -a --include '*/' --include 'admin-*.png' --exclude '*' test-results/ artifacts/admin-checkpoints/`. Simplest:
```bash
find test-results -type f -name 'admin-*.png' -exec cp -n {} artifacts/admin-checkpoints/ \;
```
and add a `find ... -name 'admin-*.png' | wc -l` sanity line so the expected count is visible in the step log.

### WR-04: `example_playwright_smoke` backgrounds the example app with no log capture

**File:** `.github/workflows/ci.yml:466-474`
**Issue:** `run: mix phx.server &` backgrounds the server without redirecting stdout/stderr to a file. If boot fails or the server crashes mid-run, the output is interleaved with later step output (making it hard to read) and cannot be `cat`ed in a diagnostic step. `install_matrix` gets this right at line 291 (`> /tmp/install-matrix-server.log 2>&1`) and `admin-acceptance-smoke.sh:207` gets it right (`> "${SERVER_LOG}"`), so the pattern is already in the repo — this step just missed it.

**Fix:**
```yaml
- name: Boot example app in background
  working-directory: test/example
  env:
    MIX_ENV: dev
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
    PHX_SERVER: "true"
  run: mix phx.server > /tmp/example-playwright-server.log 2>&1 &
```
Add a corresponding `if: failure()` step that `cat`s the log so CI failure investigation does not require pulling the retained-video artifact first. Same applies to `example_http_smoke` at line 408.

## Info

### IN-01: `admin-acceptance-smoke.sh` writes the seed file to a fixed path under `/tmp`

**File:** `scripts/ci/admin-acceptance-smoke.sh:148`
**Issue:** `cat > /tmp/sigra_admin_acceptance_seed.exs <<'EOF'` uses a fixed path. Two concurrent runs of the script on the same host (local dev with two shells, or a self-hosted runner with parallelism) will clobber each other's seed file. `TMP_APP_DIR` is already parameterized — the seed file should live inside it for locality.

**Fix:**
```bash
SEED_FILE="${TMP_APP_DIR}/sigra_admin_acceptance_seed.exs"
cat > "${SEED_FILE}" <<'EOF'
...
EOF

mix run "${SEED_FILE}"
```

### IN-02: Hardcoded test-only credentials should carry an explicit "test-only" marker

**File:** `scripts/ci/admin-acceptance-smoke.sh:31,33-35` and each Playwright spec (e.g. `admin-audit.spec.ts:79`, `admin-user-operations.spec.ts:72`, `impersonation.spec.ts:70`, etc.)
**Issue:** `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=`, `SIGRA_ADMIN_PASSWORD=CorrectHorseBatteryStaple123!`, and `const password = 'CorrectHorseBatteryStaple123!'` are all fine as deterministic smoke values. They will, however, show up verbatim in secret-scanners and cause noise on security dashboards. Adding an inline `# test-only: generated ephemeral smoke; NEVER reuse in any non-test environment` comment next to each makes the intent explicit and pre-answers the scanner ticket. The Playwright specs reuse the same literal five times — a shared `TEST_PASSWORD` constant in a helper module would also eliminate the copy/paste.

**Fix (script):**
```bash
# test-only: deterministic Cloak key for ephemeral smoke DB, never shipped.
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"
```
**Fix (specs):** add `test/example/priv/playwright/helpers/fixtures.ts` exporting `export const TEST_PASSWORD = 'CorrectHorseBatteryStaple123!';` with a "test-only" comment and import it in each spec.

### IN-03: `http-smoke.sh` uses a magic `+ 4` in its pass-summary math

**File:** `scripts/ci/http-smoke.sh:138`
**Issue:** `total_checks=$(( ${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + 4 ))` encodes "4 extra checks" (cookie warmup, cookie present, cookie reuse, admin denial) as a literal `4`. If anyone adds or removes a non-array check without updating the literal, the summary line reports the wrong count and there's no compile-time error to catch it. A tracked counter is a five-line change.

**Fix:**
```bash
EXTRA_CHECKS=0
EXTRA_CHECKS=$((EXTRA_CHECKS + 1))
total_checks=$(( ${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + EXTRA_CHECKS ))
```

### IN-04: `impersonation_token_for/2` accepts but ignores its `_admin` argument

**File:** `test/example/test/example_web/controllers/impersonation_controller_test.exs:241-260`
**Issue:** The helper signature `defp impersonation_token_for(user, _admin)` takes an admin arg but never uses it. Every caller passes the admin (e.g. line 114). If the helper ever needs to embed the impersonator id into the session record (as the real impersonation flow does), the call sites won't need updating, but today the argument is purely decorative and can mislead a reader into thinking it is persisted.

**Fix:** either drop the parameter and rename the helper if it is truly impersonator-agnostic, or actually persist the relationship (e.g. set `impersonator_user_id: admin.id` if the schema supports it) so the helper matches the real flow it is standing in for.

### IN-05: CSV test at `admin-audit.spec.ts` asserts on the `organization_label` column header rather than row content

**File:** `test/example/priv/playwright/tests/admin-audit.spec.ts:143-145`
**Issue:** After the scoped CSV download, the test asserts `expect(scopedCsv).toContain('organization_label')`. `organization_label` is a header name that is present in every non-empty CSV exported by this endpoint (per the fixed v1 columns in `audit_export_controller_test.exs:9-23`). The assertion passes even if the body contains no data rows for the subject user. The adjacent two assertions (`session.create` and `targetEmail`) already prove row content — the `organization_label` assertion either needs tightening to actual org label content ("Audit Org …") or it can be dropped as a tautology.

**Fix:**
```ts
expect(scopedCsv).toContain(orgName);
```
(or delete the line — the ExUnit CSV contract at `audit_export_controller_test.exs:72-82` already pins the schema).

### IN-06: Playwright specs use `page.locator('form').first()` where a stable id would be safer

**File:** `test/example/priv/playwright/tests/admin-audit.spec.ts:33`, `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:48`, `test/example/priv/playwright/tests/impersonation.spec.ts:29`, `test/example/priv/playwright/tests/admin-user-operations.spec.ts:40`
**Issue:** The registration helper uses `page.locator('form').first().evaluate(...)` to submit the form. If the registration page ever grows a preceding form (a search bar, a newsletter signup, a CSRF-only hidden form), `.first()` silently targets the wrong one and the test flakes in a way that looks like "nothing happens on click." The non-admin flows use `#login_form` as an id anchor (e.g. `admin-generated.spec.ts:40-42`) — the register flow has no equivalent id on the template today.

**Fix:**
```ts
await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
  (form as HTMLFormElement).requestSubmit();
});
```
This keeps the test resilient to new forms appearing on the page.
