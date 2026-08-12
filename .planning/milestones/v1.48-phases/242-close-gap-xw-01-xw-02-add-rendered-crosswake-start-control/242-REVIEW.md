---
phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
reviewed: 2026-08-12T15:32:54Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - test/example/lib/example_web/live/app_live.ex
  - test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts
  - test/example/test/example/accounts/crosswake_continuations_test.exs
  - test/example/test/example_web/live/app_live_test.exs
  - test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 242: Code Review Report

**Reviewed:** 2026-08-12T15:32:54Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the rendered Crosswake start control and its browser, LiveView, continuation, and phase-contract coverage. The form remains a native CSRF-protected POST with no protocol material rendered into the DOM; its authenticated route owns issuance, and the return path consumes the encrypted session-bound verifier before evaluating the continuation. One phase-contract guard fails open when the required hosted-runtime evidence receipt is absent.

The focused Mix command could not start in this workspace because the already-compiled `ExampleWeb.Endpoint` uses a different test port than the runtime configuration. This is an environment compile-artifact mismatch, not a finding in the reviewed files.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Missing hosted-runtime evidence is accepted

**File:** `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs:383-386`
**Issue:** `unless File.exists?(@evidence), do: :ok` only evaluates to `:ok`; it does not return from the enclosing test. The subsequent `if File.exists?(@evidence)` skips every receipt assertion when the file is absent, so the test still returns successfully. A missing required evidence receipt can therefore yield a green phase-contract test and leave the runtime proof unverified.
**Fix:** Require the receipt before decoding it, then perform its assertions unconditionally:

```elixir
assert File.regular?(@evidence), "missing hosted Crosswake runtime evidence: #{@evidence}"

receipt = decode!(@evidence)
release = decode!(@release)
# existing receipt assertions
```

---

_Reviewed: 2026-08-12T15:32:54Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
