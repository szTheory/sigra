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
  warning: 0
  info: 6
  total: 6
status: issues_found
---

# Phase 31: Code Review Report (iter 2)

**Reviewed:** 2026-04-16
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found (Info only — no blocking issues)

## Summary

Re-review of Phase 31 after the WR-01..WR-04 auto-fix pass
(commits 66e0c94, 13622fe, 5c07176, 8d9a6b0). All four warnings from
iteration 1 are **verified resolved** in the current tree, and no
regressions were introduced by the fix commits.

The fresh-eyes pass did not find any new bugs, security issues, or
code-quality concerns beyond what iteration 1 already identified. The
six Info items (IN-01..IN-06) remain present and are carried forward
verbatim — none rise to Warning severity.

## Warnings Resolved (verification)

### WR-01 — RESOLVED

**File:** `.github/workflows/ci.yml:13-14`
**Fix applied:** Top-level `permissions:` block with `contents: read`
is present immediately after the `on:` trigger, with a clear comment
documenting that any job needing additional scopes must override at
the job level. Matches the recommended fix exactly. No regressions
observed — no job currently writes to the repo, releases, or mutates
issues/PRs, so the least-privilege default does not break anything.

### WR-02 — RESOLVED

**File:** `.github/workflows/ci.yml:269-285`
**Fix applied:** The `mix sigra.install` step now pipes
`matrix.flags` through a step-level `env.MATRIX_FLAGS` variable and
the `run:` command references `$MATRIX_FLAGS` instead of the
`${{ matrix.flags }}` template expression. A `# shellcheck disable=SC2086`
comment explicitly documents that word-splitting on the env var is
intentional for flags like `"--no-organizations --no-passkeys"`.
Empty-string flags (`""`) still expand correctly to no argument.

Non-issue follow-on: the env-var indirection protects against the
template-parse-time injection vector (which is the documented attack
pattern). Runtime shell word-splitting on `$MATRIX_FLAGS` is still
desired; any future change that sources matrix flags from untrusted
input would need additional hardening (quoting, or passing as a
JSON-serialized arg list), but that is not in scope here.

### WR-03 — RESOLVED

**Files:** `.github/workflows/ci.yml:603` and `.github/workflows/ci.yml:719`
**Fix applied:** Both `find ... -exec cp` invocations use `cp -n`
(no-clobber). In addition, a visible `src_count=$(find ... | wc -l)`
log line is emitted immediately before the copy, paired with the
existing `ls -la artifacts/admin-checkpoints/` after the copy, so
reviewers can eyeball the expected-vs-collected delta from the step
log. The guard `if compgen -G "test-results/**/admin-*.png"` is
preserved so the step is a no-op when no checkpoints were produced.

### WR-04 — RESOLVED

**Files:** `.github/workflows/ci.yml:428`, `.github/workflows/ci.yml:431-435`,
`.github/workflows/ci.yml:502`, `.github/workflows/ci.yml:572-580`
**Fix applied:** Both backgrounded `mix phx.server` invocations
(example_http_smoke and example_playwright_smoke) now redirect stdout
and stderr to a unique log file under `/tmp/`, and each job has a
matching `if: failure()` step that `cat`s the log. The two log paths
(`/tmp/example-http-server.log` and `/tmp/example-playwright-server.log`)
do not collide with each other or with `install_matrix`'s log at
`/tmp/install-matrix-server.log`.

Step ordering on failure is correct: the failure dump step runs
before `if: always()` artifact collection, so log output appears
earlier in the job log than artifact-upload noise. No regressions.

## Info (carried forward from iteration 1)

The following Info items remain present and unchanged from iteration 1.
None rise to Warning severity. Reference the full rationale and fix
suggestions in `31-REVIEW.iter1.md`.

### IN-01: Fixed `/tmp` path for admin-acceptance seed file

**File:** `scripts/ci/admin-acceptance-smoke.sh:148`
Still writes to the fixed path `/tmp/sigra_admin_acceptance_seed.exs`.
Concurrent local runs on the same host would clobber each other.
Low impact on CI (fresh runners). See iter1 for fix.

### IN-02: Test-only credentials lack "test-only" markers

**Files:** `scripts/ci/admin-acceptance-smoke.sh:31,33-35`;
`test/example/priv/playwright/tests/admin-audit.spec.ts:79`;
`test/example/priv/playwright/tests/admin-user-operations.spec.ts:72,127`;
`test/example/priv/playwright/tests/impersonation.spec.ts:70,91`;
`test/example/priv/playwright/tests/admin-checkpoints.spec.ts:115`;
`test/example/priv/playwright/tests/admin-generated.spec.ts:26`
Hardcoded deterministic test credentials (the Cloak key and the
`CorrectHorseBatteryStaple123!` password) still lack explicit
"test-only" comments and are still duplicated across specs rather
than centralized in a shared fixtures helper. See iter1 for fix.

### IN-03: Magic `+ 4` in http-smoke.sh pass-summary math

**File:** `scripts/ci/http-smoke.sh:138`
`total_checks=$(( ${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + 4 ))`
still encodes the 4 non-array checks (cookie warmup, cookie present,
cookie reuse, admin denial) as a magic literal. See iter1 for fix.

### IN-04: `impersonation_token_for/2` accepts-but-ignores its `_admin` arg

**File:** `test/example/test/example_web/controllers/impersonation_controller_test.exs:241`
The helper signature still takes an `_admin` arg that is never used.
Every caller passes it. Either drop the parameter or actually persist
the relationship. See iter1 for fix.

### IN-05: CSV assertion on header name `organization_label` is tautological

**File:** `test/example/priv/playwright/tests/admin-audit.spec.ts:145`
`expect(scopedCsv).toContain('organization_label')` still passes even
on an empty CSV body because `organization_label` is in the fixed v1
header. Tighten to assert the actual org label, or delete the line.
See iter1 for fix.

### IN-06: Playwright specs use `page.locator('form').first()` instead of a stable id

**Files:** `test/example/priv/playwright/tests/admin-audit.spec.ts:33`;
`test/example/priv/playwright/tests/admin-checkpoints.spec.ts:48`;
`test/example/priv/playwright/tests/admin-user-operations.spec.ts:40`;
`test/example/priv/playwright/tests/impersonation.spec.ts:29`
The registration helper still targets the first form on the page.
Any future form added to `/users/register` (search bar, newsletter
signup, hidden CSRF-only form) would silently retarget. See iter1
for fix.

---

_Reviewed: 2026-04-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 2 (post-fix verification of WR-01..WR-04; IN-01..IN-06 carried forward)_
