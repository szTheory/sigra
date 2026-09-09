---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-09-09T14:37:53Z
depth: standard
files_reviewed: 66
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/fast-01-gap-closure-evidence.yml
  - .github/workflows/fast-01-remeasurement-evidence.yml
  - .github/workflows/generated-app-login-runtime-proof.yml
  - .github/workflows/terminal-ratification-evidence.yml
  - .release-please-manifest.json
  - AGENTS.md
  - CHANGELOG.md
  - CONTRIBUTING.md
  - README.md
  - doc/llms.txt
  - guides/introduction/upgrading-to-v1.5.md
  - lib/sigra/audit/forwarders/threadline.ex
  - lib/sigra/config.ex
  - lib/sigra/install/features/core.ex
  - lib/sigra/oauth.ex
  - lib/sigra/oauth/strategies/apple.ex
  - lib/sigra/oauth/strategies/google.ex
  - mix.exs
  - mix.lock
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/login_html.ex
  - priv/templates/sigra.install/core/mfa_settings_live.ex
  - priv/templates/sigra.install/core/session_controller.ex
  - priv/templates/sigra.install/core/token_controller.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - priv/templates/sigra.install/passkeys/config_injection.ex
  - priv/templates/sigra.install/passkeys/router_injection.ex
  - scripts/ci/capture-fast-01-gap-closure.sh
  - scripts/ci/capture-fast-01-gap-closure.test.sh
  - scripts/ci/capture-fast-01-remeasurement.sh
  - scripts/ci/capture-fast-01-remeasurement.test.sh
  - scripts/ci/capture-terminal-ratification-evidence.sh
  - scripts/ci/capture-terminal-ratification-evidence.test.sh
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/ci-run-metrics.test.sh
  - scripts/ci/correlate-terminal-ratification-dispatch.sh
  - scripts/ci/install-smoke.sh
  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  - scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.sh
  - scripts/ci/verify-terminal-ratification-attestation-offline.test.sh
  - scripts/panel/fix-apply.test.mjs
  - scripts/uat/RUNBOOK.md
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/priv/playwright/tests/passkey-login.spec.ts
  - test/fixtures/install_golden/tree/config/config.exs
  - test/fixtures/install_golden/tree/config/dev.exs
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_controller.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_html.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/mfa_settings_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/user_auth.ex
  - test/sigra/audit/forwarders/noop_test.exs
  - test/sigra/config_capabilities_test.exs
  - test/sigra/install/generated_capability_gates_test.exs
  - test/sigra/install/generator_passkeys_foundation_test.exs
  - test/sigra/oauth/assent_oidc_contract_test.exs
  - test/sigra/oauth/oauth_test.exs
  - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
  - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 4
  warning: 4
  info: 0
  total: 8
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-09-09T14:37:53Z
**Depth:** standard
**Files Reviewed:** 66
**Status:** issues_found

## Summary

The source-complete capture repairs the prior review's derived-only evidence defect: the retained subject now includes raw pages and timestamps, all focused tests pass, and all three retained attestation verifiers succeed offline. The final implementation is still not shippable. The source-first verifier contradicts the authoritative instrument for legitimate non-success conclusions, destructive shell utilities trust unvalidated deletion targets, and the new OAuth evidence API crashes for supported non-OIDC/custom strategies. Four additional robustness and test-contract gaps remain.

Findings CR-01, WR-01, WR-02, and WR-03 are directly in the final Plan 16–18 source-complete path. CR-02, CR-03, CR-04, and WR-04 arise from the diff cross-check additions and are called out as historical/scope-noise concerns rather than being silently omitted.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Offline replay rejects valid all-conclusion populations

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:75-86`

**Issue:** The authoritative instrument groups outcomes by the literal conclusion at `ci-run-metrics.sh:146`, so a valid terminal PR population can produce keys such as `cancelled`, `timed_out`, `neutral`, or `skipped`. The offline verifier instead constructs exactly `{success: ..., failure: count(non-success)}`. Any future valid source-complete subject containing a cancelled or timed-out PR run will therefore fail offline even though the collector and instrument deliberately retain it. The metrics self-test already uses all nine terminal conclusion values (`ci-run-metrics.test.sh:372-381`), but no verifier test carries those values through this comparison. This violates the phase's all-conclusion and exact-agreement contract.

**Fix:** Build the oracle outcome map exactly as the instrument does:

```jq
outcomes: (
  $oracle_runs
  | group_by(.conclusion)
  | map({key: .[0].conclusion, value: length})
  | from_entries
)
```

Add a verifier-level fixture containing at least `success`, `failure`, and `cancelled` conclusions and require byte-for-value equality with `instrument_receipt.output.statistics`.

### CR-02: Install smoke can recursively delete an arbitrary caller-selected path

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/install-smoke.sh:20-21,43-46`

**Issue:** `TMP_APP_DIR` is accepted verbatim from the environment and passed to `rm -rf`. A typo such as `TMP_APP_DIR=/Users/jon/projects` destroys unrelated work, and values such as `/` or the repository root are not rejected. This is a direct data-loss risk in a developer-facing verification script. It is a historical/diff-cross-check concern rather than a Plan 16–18 evidence-path change, but it remains executable source in the review union.

**Fix:** Create a private parent with `mktemp -d`, place the generated app beneath it, and clean only that validated child. If the override must remain, resolve it with `realpath`, require it to be below an explicitly allowed temporary parent, reject `/`, the workspace, and empty paths, and only then remove it.

### CR-03: Offline verifiers recursively delete an unvalidated `mktemp` result

**Classification:** BLOCKER

**Files:**

- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:32-45`
- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh:28-30,82-90`
- `/Users/jon/projects/sigra/scripts/ci/verify-terminal-ratification-attestation-offline.sh:19-21,56-64`

**Issue:** Each verifier resolves `mktemp` from caller-controlled `PATH`, does not whitelist the resolved executable or validate its returned directory, and later recursively removes that value. If a broken or shadowed `mktemp` prints an existing broad directory and exits successfully, the subsequent `mkdir`/copy failure still triggers the EXIT trap and deletes that directory. The scripts explicitly whitelist `gh` and `jq`, so leaving the destructive-path producer untrusted is inconsistent with their own threat boundary. The source-complete verifier also omits the sudo-aware cleanup used by the other two, so its Linux sudo fallback can leave root-owned temporary data or fail cleanup.

**Fix:** Use a fixed trusted `mktemp` path per supported platform, verify the created directory is non-empty, newly created, owned by the current process/user, and under the OS temp root, then guard cleanup with the same validation. Preserve the sudo-aware cleanup branch in all three scripts.

### CR-04: `provider_evidence: true` crashes for supported non-OIDC and custom providers

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/lib/sigra/oauth.ex:157-168,239-251`

**Issue:** The public five-argument callback accepts any provider atom, but unconditionally invokes `strategy_module.callback/4`. Only the new Apple and Google wrappers implement that arity. GitHub, Facebook, Generic OIDC, and custom strategies resolve successfully and then raise `UndefinedFunctionError` instead of returning the documented `{:error, %OAuthError{}}`. This was reproduced with a valid custom strategy: `authorize_url(..., provider_evidence: true)` succeeded, then `handle_callback(..., provider_evidence: true)` raised `function Sigra.OAuth.Strategies.Generic.callback/4 is undefined or private`. This is historical/diff-cross-check scope, but it is a regression in the new v1.5 API.

**Fix:** Either reject evidence mode during authorization for providers whose wrapper does not advertise evidence support, or add a capability callback/behaviour and return a typed `OAuthError` before invoking the strategy. If generic OIDC is intended to work, implement evidence extraction in `Strategies.Generic` only for OIDC strategies and test Google, Apple, GitHub, Facebook, generic OIDC, and a custom non-OIDC strategy.

## Warnings

### WR-01: The promised stdin source-page seam is not implemented

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/ci-run-metrics.sh:97-104`

**Issue:** Plan 235-16 requires a file/stdin source-page input seam, but `--source-pages -` fails `[[ -s "$SOURCE_PAGES" ]]` because `-` is treated as a filename. Production currently uses a temporary file, so the retained result is unaffected, but the declared interface is incomplete and prevents pipeline use without filesystem staging.

**Fix:** Treat `-` specially by copying stdin into a validated temporary file (or have each jq invocation read a single captured stdin document), then run the same shape and semantic checks. Add a test that pipes the existing multi-page fixture through stdin.

### WR-02: Miss-pole replay does not independently validate job identities or complete field semantics

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:90-99`

**Issue:** The miss branch checks page continuity and run linkage, but never checks `job_id` type/uniqueness, pole role/resource/query, job/step conclusion presence, or the declared field types. Duplicate jobs or malformed identities can therefore pass the independent replay as long as timestamps and `run_id` compare. The producer has stronger checks, but the phase explicitly requires an independent source-first verifier rather than relying only on producer correctness. The retained result happened to be a pass, so this unexecuted miss branch remains latent.

**Fix:** Validate the exact pole schema, role and endpoint, unique numeric job IDs, non-empty terminal job/step conclusions, ordered unique integer step numbers, and all declared string timestamps before linkage/chronology checks. Add offline-verifier tests for duplicate job ID, wrong role/resource, missing conclusion, and malformed step fields.

### WR-03: The ExUnit “independent replay” can pass forged mean and outcome statistics

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs:424-447`

**Issue:** `validate_subject/1` checks n, p50, max, selected poles, and derived rows, but never recomputes or compares `mean_seconds`, `statistics.outcomes`, the full instrument output, or instrument status/threshold/window fields. The test titled “retained source pages independently reproduce the authoritative wall result” therefore stays green if mean or outcome counts are forged. That weak coverage allowed CR-01's incompatible conclusion aggregation to survive.

**Fix:** Recompute the full statistics object from raw source rows, require exact equality with both top-level statistics and the complete instrument receipt, and add mutations for mean, every conclusion count, instrument n/status/window/threshold, and an additional terminal conclusion key.

### WR-04: Value-taking metrics flags terminate with raw unbound-variable errors

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/ci-run-metrics.sh:63-76`

**Issue:** Every value-taking option reads `$2` without first checking that an argument remains. With `set -u`, calls such as `ci-run-metrics.sh --source-pages` abort with a shell `unbound variable` diagnostic instead of the tool's stable fail-closed error contract. This is a historical robustness issue in the shared metrics tool.

**Fix:** Add a `require_value` helper before each shift, or parse with `getopts`/a loop that explicitly rejects missing values, and cover each value-taking flag with one table-driven negative test.

---

_Reviewed: 2026-09-09T14:37:53Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
