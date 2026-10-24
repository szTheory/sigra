---
phase: 255-make-failures-reproducible-and-report-the-result
fixed_at: 2026-10-24T20:03:30Z
review_path: .planning/phases/255-make-failures-reproducible-and-report-the-result/255-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 255: Code Review Fix Report

**Fixed at:** 2026-10-24T20:03:30Z  
**Source review:** `.planning/phases/255-make-failures-reproducible-and-report-the-result/255-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: SIGTERM bypasses owned resource cleanup

**Files modified:** `scripts/ci/ci-browser-local.py`, `scripts/ci/ci-browser-local.test.py`  
**Commit:** `593d83438`  
**Applied fix:** SIGTERM now records signal 15, stops the active recorder and its invocation-owned process group, runs the existing database/server cleanup, and returns 143. A real native process test verified owned cleanup and that an unrelated listener and PostgreSQL database stayed intact.

### CR-02: SIGKILL child outcome raises before it can be returned

**Files modified:** `scripts/ci/ci-command-record.py`, `scripts/ci/ci-command-record.test.py`  
**Commit:** `35ffa421a`  
**Applied fix:** The recorder skips `signal.signal` for uncatchable SIGKILL and SIGSTOP, then re-emits the child's signal. The real child SIGKILL regression verifies the caller receives `-9` and the record retains `primary_signal: 9`.

### CR-03: Concurrent controller calls can exceed frozen request limits

**Files modified:** `scripts/ci/ci-diagnostics-canary.py`, `scripts/ci/ci-diagnostics-canary.test.py`  
**Commit:** `2e33f2721`  
**Applied fix:** An OS file lock now covers freeze-file reload, budget checks, counter increments, and durable writes. Rate-response observations use the same lock so an older response write cannot replace a newer reservation. Both concurrent-process regressions passed without any controller request or network operation.

### CR-04: Trace sanitizer leaves credentials in URL userinfo and camel-case fields

**Files modified:** `scripts/ci/ci-diagnostic-bundle.py`, `scripts/ci/ci-diagnostic-bundle.test.py`  
**Commit:** `264c2e368`  
**Applied fix:** URL userinfo is removed and recorded in redaction metadata. Sensitive names are normalized across camel-case and separator forms, including access and refresh token fields in JSON, query strings, and form data. A finished synthetic trace archive verified that records and safe fields remain while each planted credential is absent.

### WR-01: Uploaded bundle drops manifest missing-file evidence

**Files modified:** `scripts/ci/ci-diagnostic-bundle.py`, `scripts/ci/ci-diagnostic-bundle.test.py`  
**Commits:** `264c2e368` (bundle serialization and verification), `27cae3b6f` (tampering and compatibility regressions)  
**Applied fix:** The bundle now carries a validated `missing_files` list and verification compares it with the invocation manifest. Tampered or omitted non-empty metadata fails. Older v1 archives with no missing-file entries and no `missing_files` member remain verifiable as an empty list.

## Verification

The checks ran in the main checkout because `.planning/config.json` sets `workflow.use_worktrees` to `false`. Python bytecode writing was disabled; the existing untracked `scripts/ci/__pycache__/` was preserved.

- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-browser-local.test.py` — passed, 12 tests.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-command-record.test.py` — passed, 5 tests.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-diagnostics-canary.test.py` — passed, 18 tests, including concurrent reservation and rate-response writes.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-diagnostic-bundle.test.py` — passed, 14 tests, including archive redaction, missing-file tampering, and legacy bundle compatibility.
- `PATH="$HOME/.asdf/installs/nodejs/20.19.5/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-browser-local.test.py --native-sigterm` — passed on macOS with Node 20.19.5, Playwright 1.59.1, Elixir 1.19.5, and Erlang/OTP 28. The outer runner returned 143 and recorded signal 15. Its owned database, server group, and active Playwright group were gone; the unrelated database fingerprint and listener were unchanged.

No GitHub request, workflow dispatch, push, remote fetch, or distribution verification was performed. These local code revisions were not hosted-tested and do not replace the historical hosted producer source. Scoped machine-readable results are in `.planning/execution/255-review-fix/RESULT.json`.

---

_Fixed: 2026-10-24T20:03:30Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_

## Follow-up: CR-04 URL fragment credentials

**Updated:** 2026-10-24T20:09:40Z
**Commit:** `871d3c33b`

The focused re-review found that URL fragment credentials were still retained. `redact_url` now applies the same normalized sensitive-key matching to fragment parameters that it applies to query parameters. The finished-archive regression confirms `access_token`, `refreshToken`, and `api-key` values are absent, records all three redactions, and retains safe `state` and `tab` fragment values.

**Verification:** `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-diagnostic-bundle.test.py` — passed, 15 tests. The new finished-archive test failed before the fix with zero redactions, then passed after the fix. Bytecode writing remained disabled.

Machine-readable follow-up evidence: `.planning/execution/255-review-fix/CR-04-FRAGMENT-FOLLOWUP.json`.
