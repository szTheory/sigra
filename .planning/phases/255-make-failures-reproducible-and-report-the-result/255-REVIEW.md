---
phase: 255-make-failures-reproducible-and-report-the-result
reviewed: 2026-10-24T19:50:11Z
depth: standard
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
  critical: 4
  warning: 1
  info: 0
  total: 5
status: issues_found
---

# Phase 255: Code Review Report

**Reviewed:** 2026-10-24T19:50:11Z  
**Depth:** standard  
**Files Reviewed:** 43  
**Status:** issues_found

## Summary

Reviewed the authoritative 43-file Phase 255 source scope, including the seven plan/summary pairs and the phase context, security, and validation notes. The review found four correctness/security blockers involving signal cleanup, signal preservation, concurrent hosted-budget reservations, and trace credential redaction, plus one reporting gap where missing files disappear from the uploaded bundle manifest. I reproduced the trace sanitizer retaining URL userinfo and camel-case token fields with a narrow in-memory probe; broad suites were not run.

## Critical Issues

### CR-01: SIGTERM bypasses owned resource cleanup

**File:** `scripts/ci/ci-browser-local.py:567-589`
**Issue:** `_run_local` handles `KeyboardInterrupt` but installs no SIGTERM handler. If a user, CI cancellation, or parent process sends SIGTERM while the Phoenix server or Playwright command is active, Python exits immediately instead of entering the `finally` block. That leaves the invocation-owned PostgreSQL database and possibly its server process group running. The durable owner record is not enough to recover automatically because the CLI exposes no cleanup command.
**Fix:** Handle SIGTERM by recording signal 15 as the primary outcome and entering the normal `finally` cleanup path, then return the conventional `143` status after cleanup. Add a real-process test that sends SIGTERM to the local runner and verifies both owned resources are cleaned while unrelated resources remain untouched.

### CR-02: SIGKILL child outcome raises before it can be returned

**File:** `scripts/ci/ci-command-record.py:215-219`
**Issue:** When the recorded child is killed by SIGKILL, `Popen.wait()` returns `-9` and `run_to_files` stores `primary_signal == 9`. The recorder then calls `signal.signal(SIGKILL, SIG_DFL)`, which Python rejects with `OSError: [Errno 22] Invalid argument`. The wrapper consequently exits with an exception instead of preserving the child’s signal-compatible status or re-raising the signal. This occurs for commands terminated by a hard timeout or cancellation.
**Fix:** Do not call `signal.signal` for uncatchable signals such as SIGKILL; directly use `os.kill(os.getpid(), sig)` when re-raising, or return `128 + sig` if re-raising cannot be performed. Add a process test for a child that terminates itself with SIGKILL.

### CR-03: Concurrent controller calls can exceed frozen request limits

**File:** `scripts/ci/ci-diagnostics-canary.py:331-368`
**Issue:** `charge_request` performs an unlocked read/check/increment/write of the shared freeze file. Two concurrent controller processes can both read the same remaining allowance, both pass the limit checks, then replace the file with competing updates while both proceed to their HTTP operation. This can undercount requests or invocations and permit more dispatches/pushes than the frozen limits. The atomic file replacement prevents partial JSON but does not make the reservation atomic.
**Fix:** Serialize each reservation with an OS-level lock held across load, limit checks, counter updates, and durable write; release it before the HTTP request. Add a concurrent-process test near a budget boundary and verify only the allowed number of callers can reserve and proceed.

### CR-04: Trace sanitizer leaves credentials in URL userinfo and camel-case fields

**File:** `scripts/ci/ci-diagnostic-bundle.py:148-163`
**Issue:** `redact_url` only examines query parameter names and returns `urlsplit(...).netloc` unchanged, so `https://alice:basic-secret@example.test/path` retains both userinfo credentials. The recursive field matcher also requires separator boundaries around sensitive names; common JSON keys such as `accessToken` and `refreshToken` therefore pass through unchanged. I confirmed both cases with a narrow in-memory call to `redact_trace_value`. Since sanitized trace ZIPs are uploaded, these values can leave the runner in the retained diagnostic bundle.
**Fix:** Strip or redact URL username/password before serialization and recognize sensitive token names case-insensitively across camel-case and separator forms (including access/refresh tokens). Add archive-level tests that stage traces containing URL userinfo and camel-case token fields, then assert the bundle contains neither secret and records each redaction.

## Warnings

### WR-01: Uploaded bundle drops manifest missing-file evidence

**File:** `scripts/ci/ci-diagnostic-bundle.py:340-348`
**Issue:** `write_manifest` records absent requested artifacts in `missing_files`, but `stage_bundle` omits that field when creating `bundle-manifest.json`. After upload, a consumer cannot tell that an expected report, trace, or command stream was unavailable; it sees only the subset of files that existed. This hides useful failure-state evidence even though the invocation manifest had it.
**Fix:** Copy a validated `missing_files` list into the bundle metadata and verify it against the invocation manifest. Add a test where one explicitly requested file is absent and assert the uploaded bundle preserves its path as missing.

---

_Reviewed: 2026-10-24T19:50:11Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
