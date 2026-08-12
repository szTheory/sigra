---
phase: 241-close-gap-ops-01-repair-controller-mfa-settings-rendering
reviewed: 2026-08-11T18:49:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - priv/templates/sigra.install/core/settings_controller.ex
  - scripts/ci/passkeys-opt-out-smoke.sh
  - test/sigra/install/generated_rate_limit_contract_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 241: Code Review Report

**Reviewed:** 2026-08-11T18:49:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The controller-mode MFA GET route now renders successfully and the focused contract test passes, but the generated no-LiveView UI is not usable for its advertised MFA lifecycle: all routes linked by that UI deliberately reject the operation. The smoke readiness probe can also hang indefinitely when a generated server accepts a connection but does not return an HTTP response.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Controller-mode MFA settings advertises actions that every handler rejects

**File:** `priv/templates/sigra.install/core/settings_controller.ex:33-38`
**Issue:** The MFA settings HTML rendered by `mfa/2` links/forms to `disable`, `regenerate`, `revoke_trust`, `enroll`, `confirm`, and `complete`, but each route immediately calls `unavailable/1`. Thus a `--no-live` installation can view a status page but cannot enroll MFA, finish an enrollment, regenerate recovery codes, revoke trusted browsers, or disable MFA. This is an incorrect generated account-security flow; in particular, users of a controller-only install cannot turn on MFA at all.
**Fix:** Implement these controller actions with the same authenticated/sudo checks and `Auth` MFA operations as the LiveView flow, preserving transient enrollment/backup-code state safely (for example in the session). If controller mode is intentionally read-only, render a controller-specific template that omits every actionable control and do not generate their routes; that would still leave MFA enrollment unsupported and should be documented as such.

## Warnings

### WR-01: Server readiness check has no per-request deadline

**File:** `scripts/ci/passkeys-opt-out-smoke.sh:448-449`
**Issue:** `curl --retry` retries connection failures, but it has neither `--connect-timeout` nor `--max-time`. If the generated app accepts a TCP connection and then stalls before sending a response, the one `curl` invocation can block indefinitely, so the smoke job never reaches its failure diagnostic or cleanup trap.
**Fix:** Bound each probe request, for example:

```bash
if curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 0 \
    --connect-timeout 2 --max-time 5 "http://127.0.0.1:${port}/" > /dev/null; then
```

---

_Reviewed: 2026-08-11T18:49:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
