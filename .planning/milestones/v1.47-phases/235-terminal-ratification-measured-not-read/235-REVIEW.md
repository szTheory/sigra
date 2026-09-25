---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-09-09T15:48:34Z
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
  critical: 3
  warning: 4
  info: 0
  total: 7
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-09-09T15:48:34Z
**Depth:** standard
**Files Reviewed:** 66
**Status:** issues_found

## Summary

Plan 19 fixes the literal-terminal-conclusion defect: the verifier now derives the outcome map with the same `group_by(.conclusion)` operation as the authoritative instrument, and its fixture exercises `success`, `failure`, and `cancelled`. The branch is still not shippable. Three blockers remain in the conservative full scope: two destructive shell paths can delete caller-selected or unvalidated directories, and the public OAuth evidence callback crashes for supported providers without a four-argument wrapper. Four robustness gaps remain, including one in Plan 19's shared validator: it is not equivalent to the source-pages instrument and accepts malformed/forged instrument metadata.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Install smoke can recursively delete an arbitrary caller-selected path

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/install-smoke.sh:20-21,43-46`

**Issue:** `TMP_APP_DIR` is accepted verbatim from the environment and passed to `rm -rf`. A typo such as `TMP_APP_DIR=/Users/jon/projects` destroys unrelated work, and `/`, the repository root, or another broad directory is not rejected. This is a direct data-loss risk in a developer-facing verification script.

**Fix:** Create a private parent with a trusted `mktemp -d`, place the generated app beneath it, and clean only that validated child. If the override must remain, resolve it, require it to be a non-root descendant of an explicit temporary parent, reject the workspace and empty/broad paths, and only then remove it.

### CR-02: Offline verifiers recursively delete an unvalidated `mktemp` result

**Classification:** BLOCKER

**Files:**

- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:95-113`
- `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh:21-30,82-90`
- `/Users/jon/projects/sigra/scripts/ci/verify-terminal-ratification-attestation-offline.sh:15-21,56-64`

**Issue:** Each verifier resolves `mktemp` from caller-controlled `PATH`, does not whitelist the resolved executable or validate its returned directory, and later recursively removes that value. A broken or shadowed `mktemp` can print an existing broad directory and exit successfully; any later failure triggers the EXIT trap and deletes it. The scripts whitelist `gh` and `jq`, making this omission inconsistent with their executable trust boundary. The source-complete verifier also lacks the sudo-aware cleanup used by the other two.

**Fix:** Resolve `mktemp` only from an approved absolute path, validate that the result is a newly created, non-empty directory beneath the OS temporary root and is not a broad path, and repeat the guard in cleanup before `rm -rf`. Use the same sudo-aware cleanup in all three verifiers.

### CR-03: `provider_evidence: true` crashes for supported non-OIDC and custom providers

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/lib/sigra/oauth.ex:157-168,239-251`

**Issue:** The public evidence callback accepts any configured provider atom and unconditionally invokes `strategy_module.callback/4`. Only Apple and Google implement that arity. GitHub, Facebook, Generic, and custom strategies resolve successfully and then raise `UndefinedFunctionError`, contradicting the documented `{:error, %OAuthError{}}` contract. Authorization already accepts evidence mode for a custom provider (`oauth_test.exs:226`), so callers can enter a flow guaranteed to crash at callback.

**Fix:** Advertise evidence support explicitly in the strategy behaviour and reject unsupported providers with a typed `OAuthError` before authorization/callback, or implement safe evidence extraction for every supported strategy. Test GitHub, Facebook, generic OIDC, and a custom non-OIDC callback.

## Warnings

### WR-01: Plan 19's shared validator is weaker than the authoritative instrument

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:26-58`

**Issue:** Literal outcomes are now correct, but the extracted validator does not enforce the `ci-run-metrics.sh` input/output contract. It accepts source rows with required `url` fields removed and accepts forged `instrument_receipt.output.schema_version`, `threshold_seconds`, and `diagnostics`. Reproduction: deleting every URL, setting the schema to `"forged"`, threshold to `999999`, and diagnostics to `["forged"]` still prints `source_complete_semantic_fixture_verified`. Thus the fixture path is not an equivalent test of the authenticated path's authoritative instrument.

**Fix:** Validate the complete source-row shape and exact instrument envelope (`schema_version`, mode, event, since/until, threshold, diagnostics), or derive the complete expected instrument object and compare it atomically. Add mutation tests for missing URLs and every envelope field.

### WR-02: Miss-pole replay omits identity and field validation

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh:59-68`

**Issue:** The miss branch checks page continuity and run linkage but not `job_id` type/uniqueness, pole role/resource/query, job/step conclusion presence, or declared field types. Duplicate or malformed jobs can pass if timestamps and `run_id` compare. This is latent because the retained result is a pass.

**Fix:** Validate the exact pole schema, role and endpoint, unique numeric job IDs, non-empty terminal job/step conclusions, ordered unique integer step numbers, and timestamp types. Add negative fixtures for duplicate IDs, wrong role/resource, missing conclusions, and malformed steps.

### WR-03: The promised stdin source-page seam is not implemented

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/ci-run-metrics.sh:97-104`

**Issue:** The phase contract describes a file/stdin source-page seam, but `--source-pages -` fails the `-s` file check because `-` is treated as a filename. Production uses a temporary file, but the declared interface is incomplete.

**Fix:** Treat `-` specially by capturing stdin once into a validated temporary file, then run the same checks. Add a test piping the existing multi-page fixture through stdin.

### WR-04: Value-taking metrics flags emit raw unbound-variable errors

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/ci-run-metrics.sh:63-76`

**Issue:** Every value-taking option reads `$2` without checking that an argument remains. With `set -u`, `ci-run-metrics.sh --source-pages` aborts with a shell `unbound variable` message rather than the stable fail-closed diagnostic contract.

**Fix:** Add a `require_value` helper before each assignment/shift, or use an argument parser that rejects missing values. Cover each value-taking flag with a table-driven negative test.

---

_Reviewed: 2026-09-09T15:48:34Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
