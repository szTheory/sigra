---
phase: 255-make-failures-reproducible-and-report-the-result
reviewed: 2026-10-24T20:08:45Z
depth: standard
re_reviewed: 2026-10-24T20:08:45Z
re_review_source_commit: dfe8369ee53a57f498df178e4ca823f84d562e1a
original_review_commit: 6bebfda76
files_reviewed: 43
files_reviewed_list:
  - .github/actions/ci-diagnostic-upload/action.yml
  - .github/actions/example-playwright-boot/action.yml
  - .github/workflows/ci.yml
  - CONTRIBUTING.md
  - MAINTAINING.md
  - mix.exs
  - scripts/ci/ci-browser-command.mjs
  - scripts/ci/ci-browser-command.test.mjs
  - scripts/ci/ci-browser-diagnostics.test.mjs
  - scripts/ci/ci-browser-local.py
  - scripts/ci/ci-browser-local.test.py
  - scripts/ci/ci-browser-records.mjs
  - scripts/ci/ci-command-record.py
  - scripts/ci/ci-command-record.test.py
  - scripts/ci/ci-comparison-replay.py
  - scripts/ci/ci-comparison-replay.test.py
  - scripts/ci/ci-comparison-report.test.py
  - scripts/ci/ci-diagnostic-bundle.py
  - scripts/ci/ci-diagnostic-bundle.test.py
  - scripts/ci/ci-diagnostics-canary.py
  - scripts/ci/ci-diagnostics-canary.test.py
  - scripts/ci/ci-hosted-gate-verify.py
  - scripts/ci/ci-measure-workflow.test.mjs
  - scripts/ci/ci-mix-receivers.py
  - scripts/ci/ci-mix-receivers.test.py
  - scripts/ci/ci-playwright-report.test.mjs
  - scripts/ci/ci-prep-profile.mjs
  - scripts/ci/ci-prep-profile.test.mjs
  - scripts/ci/ci-prep-semantics.test.mjs
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/fixtures/playwright-admin-theme-diagnostics.spec.ts
  - scripts/ci/fixtures/playwright-diagnostics.config.ts
  - scripts/ci/fixtures/playwright-diagnostics.spec.ts
  - scripts/ci/sigra-dep-off.sh
  - scripts/ci/test-sigra-dep-off.sh
  - test/example/priv/playwright/fixtures/adminTheme.ts
  - test/example/priv/playwright/lib/reporters/failure-jsonl.mjs
  - test/example/priv/playwright/playwright.config.ts
  - test/sigra/planning/ci_timing_formatter_test.exs
  - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/support/ci_timing_formatter.ex
  - test/test_helper.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 255: Code Review Report

**Reviewed:** 2026-10-24T20:08:45Z  
**Depth:** standard  
**Files Reviewed:** 43  
**Status:** issues_found

## Summary

This is a focused re-review of the five findings in the original report at commit `6bebfda76`. Fix commits through `dfe8369ee` resolve CR-01, CR-02, CR-03, and WR-01. CR-04's original userinfo and camel-case leaks are fixed, but URL fragments still retain credential values: a trace URL containing `#access_token=fragment-secret` is emitted unchanged. Four focused suites passed: 12 browser-local tests, 5 command-recorder tests, 18 canary tests, and 14 bundle tests. The native SIGTERM result was checked in `.planning/execution/255-review-fix/RESULT.json`; no native or hosted run was repeated.

## Critical Issues

### CR-04: URL fragment credentials remain in retained traces

**File:** `scripts/ci/ci-diagnostic-bundle.py:177-194`
**Issue:** The fix now strips URL userinfo and redacts sensitive query keys, but `redact_url` returns `parts.fragment` unchanged. A browser trace containing an OAuth implicit-flow or callback URL such as `https://example.test/callback#access_token=fragment-secret&state=ok` therefore retains the access token in the uploaded trace. I confirmed this with a narrow in-memory call: the sanitized URL and redaction list were unchanged/empty. This is a residual of original CR-04, whose userinfo and camel-case cases are resolved.
**Fix:** Parse fragment parameters with the same sensitive-name policy as query parameters, redact their values, and preserve non-sensitive fragment values. Add an archive-level regression that verifies a fragment `access_token` is absent after staging while an unrelated `state` remains.

## Resolved Original Findings

- **CR-01 — resolved** in `593d83438`: SIGTERM is recorded, active command groups are stopped, and owned server/database cleanup runs. The focused browser-local suite passed (12 tests); the fix result records the native ownership-preservation probe as passed.
- **CR-02 — resolved** in `35ffa421a`: SIGKILL/SIGSTOP are no longer passed to `signal.signal`; a child SIGKILL regression confirms `-9` at the caller and signal 9 in the record. The focused command-recorder suite passed (5 tests).
- **CR-03 — resolved** in `2e33f2721`: a file lock covers budget read/check/update and rate-response writes. Concurrent reservation and response-write regressions passed in the focused canary suite (18 tests).
- **WR-01 — resolved** in `264c2e368` and `27cae3b6f`: bundle metadata carries `missing_files`, verification binds it to the source manifest, tampering is rejected, and empty legacy v1 metadata remains compatible. The focused bundle suite passed (14 tests).

The original CR-01 through CR-04 and WR-01 descriptions and fixes remain recorded in the original report commit `6bebfda76`; the dispositions above refer to those exact IDs.

---

_Re-reviewed: 2026-10-24T20:08:45Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
