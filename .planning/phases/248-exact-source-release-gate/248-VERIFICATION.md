---
phase: 248-exact-source-release-gate
verified: 2026-10-08T23:51:24Z
status: gaps_found
score: 13/18 must-haves verified
covered_files:
  - .github/workflows/ci.yml
  - .github/workflows/hex-publish.yml
  - .github/workflows/release-please.yml
  - .github/workflows/release-pr-automerge.yml
  - .github/workflows/release-run-observer.yml
  - .planning/phases/248-exact-source-release-gate/248-01-PLAN.md
  - .planning/phases/248-exact-source-release-gate/248-01-SUMMARY.md
  - .planning/phases/248-exact-source-release-gate/248-02-PLAN.md
  - .planning/phases/248-exact-source-release-gate/248-02-SUMMARY.md
  - .planning/phases/248-exact-source-release-gate/248-03-PLAN.md
  - .planning/phases/248-exact-source-release-gate/248-03-SUMMARY.md
  - .planning/phases/248-exact-source-release-gate/248-04-PLAN.md
  - .planning/phases/248-exact-source-release-gate/248-04-SUMMARY.md
  - .planning/phases/248-exact-source-release-gate/248-05-PLAN.md
  - .planning/phases/248-exact-source-release-gate/248-05-SUMMARY.md
  - .planning/phases/248-exact-source-release-gate/248-REVIEW-DISPOSITION.md
  - .planning/phases/248-exact-source-release-gate/248-REVIEW-FIX.md
  - .planning/phases/248-exact-source-release-gate/248-REVIEW.md
  - .planning/phases/248-exact-source-release-gate/248-SECURITY.md
  - .planning/phases/248-exact-source-release-gate/248-USER-SETUP.md
  - lib/sigra/install/features/core.ex
  - scripts/ci/release-candidate-preflight.sh
  - scripts/ci/release-candidate-preflight.test.sh
  - scripts/ci/release-environment-preflight.sh
  - scripts/ci/release-environment-preflight.test.sh
  - scripts/ci/release-exact-source.sh
  - scripts/ci/release-exact-source.test.sh
  - scripts/ci/release-observer.sh
  - scripts/ci/release-observer.test.sh
  - scripts/ci/release-receipt.sh
  - scripts/ci/release-receipt.test.sh
  - scripts/ci/wait-for-ci-gate.sh
  - scripts/ci/wait-for-ci-gate.test.sh
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/sigra_auth_components.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/sigra/planning/phase_146_release_validation_test.exs
  - test/sigra/planning/phase_222_release_lane_hardening_test.exs
  - test/sigra/planning/phase_234_action_pinning_contract_test.exs
  - test/sigra/planning/phase_248_release_gate_contract_test.exs
  - test/sigra/planning/phase_248_release_observer_contract_test.exs
covered_digest: "v3:sha256:04e0682c957d17a7ca2f39aec2c580f7504417ee73de719aec3d2c2e8db21246"
behavior_unverified: 2
overrides_applied: 0
decision_coverage:
  honored: 13
  total: 13
  not_honored: []
gaps:
  - truth: "Required release credentials are present only in the intended main-restricted environments, and the live preflight proves their environment-level scope."
    status: failed
    reason: "The environment-level copies of RELEASE_PLEASE_TOKEN and HEX_API_KEY are absent while repository-level copies remain. The workflows reduce secrets.NAME to a boolean and pass it to a helper that checks branch policy but never enumerates environment secret names. Because repository and environment secrets share the secrets context, the repository copies can make that boolean true without proving the required environment copy exists."
    artifacts:
      - path: ".github/workflows/release-please.yml"
        issue: "The release job passes secrets.RELEASE_PLEASE_TOKEN != '' as a scope-blind boolean."
      - path: ".github/workflows/release-pr-automerge.yml"
        issue: "The merge job uses the same scope-blind credential-presence check."
      - path: ".github/workflows/hex-publish.yml"
        issue: "The recovery job passes scope-blind dry-run and publish credential booleans."
      - path: "scripts/ci/release-environment-preflight.sh"
        issue: "The helper validates boolean presence and main-only branch policies, but does not verify environment-level secret names."
    missing:
      - "Add RELEASE_PLEASE_TOKEN to release-automation and HEX_API_KEY to hex-publish from the secure source of truth."
      - "After verifying those environment names, remove their repository-level copies so the intended scope is the only available source."
      - "Make the live preflight validate environment-level secret names or otherwise enforce the documented removal of repository-level copies; a secrets-context boolean alone is insufficient evidence of scope."
deferred:
  - truth: "A real successful Sigra 1.6.0 release produces a retrievable receipt tied to the gated source, package, documentation, and CI run."
    addressed_in: "Phase 249"
    evidence: "Phase 249 success criteria 1–2 require the published 1.6.0 source and a committed receipt identifying the exact source, tag, package, documentation, and CI run."
behavior_unverified_items:
  - truth: "The manual dry_run recovery route completes validation and dry-run without reaching publication."
    test: "After credential-scope setup is corrected, dispatch hex-publish from main with dry_run=true and retrieve its result artifact."
    expected: "Validation and the authenticated dry-run complete; the publish step is skipped and the receipt reports dry_run rather than published."
    why_human: "The local test asserts workflow conditions and receipt behavior, but no GitHub Actions run has exercised its expression evaluation or Hex integration."
  - truth: "GitHub retains machine-readable success, failure, and cancellation receipts that maintainers can retrieve."
    test: "After credential-scope setup is corrected, inspect retained artifacts from a successful run, an ordinary failed gate or publish run, and a cancelled Release Please run."
    expected: "Each artifact contains the validated source and run identity, verdict, URLs, attempts, timestamps, and the appropriate failure or cancellation details."
    why_human: "The helper and contract tests pass locally, but the GitHub workflow event triggers, artifact upload, retention, and retrieval have not been exercised against a hosted run."
---

# Phase 248: Exact-Source Release Gate Verification Report

**Phase Goal:** Maintainers can prove the existing release lane evaluated the exact source that it will publish and can diagnose every result.
**Verified:** 2026-10-08T23:51:24Z
**Status:** gaps_found
**Re-verification:** No — initial verification; no prior Phase 248 VERIFICATION.md existed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Before package work, the release tag, Release Please SHA, and checked-out HEAD agree; the required green CI run uses that SHA; package checks stay on that tag. | ✓ VERIFIED | `release-exact-source.sh` resolves and compares all three full SHAs; its annotated-tag and mismatch fixture passes. `wait-for-ci-gate.test.sh` rejects mismatched run heads and requires a successful `ci-gate`. The release workflow checks out the tag, asserts identity before Beam/dependency/test/docs/package/dry-run/publish steps, and the Phase 248 workflow contract test passes. |
| 2 | The required CI gate preserves its bounded poll budget and job ceiling. | ✓ VERIFIED | `wait-for-ci-gate.sh` defaults to 120 attempts at 30 seconds; `release-please.yml` sets `timeout-minutes: 75` and passes `--max-attempts 120`. The poller’s 15 fixtures pass, including timeout, no-run, failed-run, dispatch, and JSON identity cases. |
| 3 | Only one valid Release Please PR is selected after a successful exact-head `ci-gate` run. | ✓ VERIFIED | `release-candidate-preflight.sh` checks push event, branch, queried run identity, SHA, successful job, and one open PR whose full head SHA matches; the 26-case fixture suite passes. |
| 4 | Candidate content validation rejects stranded Unreleased notes, duplicate versioned entries, and omitted source-backed adopter summaries. | ✓ VERIFIED | The same 26-case candidate suite passes negative fixtures for each condition and accepts the valid versioned candidate ledger. |
| 5 | The trusted merge path re-reads state and requests a squash merge with an exact-head precondition. | ✓ VERIFIED | `release-pr-automerge.yml` re-queries the CI run and candidate after initial validation and uses `gh pr merge --match-head-commit "$PR_HEAD_SHA"`; the workflow contract and candidate fixtures pass. |
| 6 | Release/recovery permissions are scoped and distinct evaluations cannot cancel one another. | ✓ VERIFIED | The workflows declare read-minimal global permissions, job-specific grants, run/attempt-specific concurrency groups, and `cancel-in-progress: false`; ExUnit workflow contracts and `actionlint` pass. |
| 7 | The release evaluation has the required Hex credential available only to the final publish step. | ✗ FAILED | The write key is referenced only in the publish step, but the live `hex-publish` environment secret list contains only `HEX_DRY_RUN_API_KEY`; `HEX_API_KEY` exists only at repository scope. The required credential is therefore not available from its intended environment. |
| 8 | Environment policies make release credentials inaccessible to non-main workflow definitions. | ✗ FAILED | Live environment policy checks pass for exactly `main` with admin bypass disabled. However, the required credentials remain repository-level secrets rather than protected environment secrets. GitHub documents that repository secrets are available to workflows and that environment-level values override same-named values only when present; the current repository copies do not inherit the environments’ branch restriction. [Secrets reference](https://docs.github.com/en/actions/reference/security/secrets), [deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments). |
| 9 | The live preflight proves both exact-main policies and presence of the required secret names in those environments before privileged transitions. | ✗ FAILED | `release-environment-preflight.sh` checks only booleans supplied by `secrets.NAME != ''` plus branch policies; it never lists each environment’s secret names. Live name-only results were `release-automation: []`, `hex-publish: [HEX_DRY_RUN_API_KEY]`, and repository secrets include `RELEASE_PLEASE_TOKEN` and `HEX_API_KEY`. Thus the scope-blind booleans do not prove the required environment copies. This is the open high-severity T-248-11 / CR-02. |
| 10 | The dry-run uses the read-only Hex key and the write-capable key is mapped only to final publication. | ✓ VERIFIED | `release-please.yml` and `hex-publish.yml` bind `HEX_DRY_RUN_API_KEY` only to dry-run steps and `HEX_API_KEY` only to publish steps; ExUnit tests assert the separation. The missing environment copy is tracked separately in truths 7–9. |
| 11 | Manual `dry_run` recovery completes validation and dry-run without publishing. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Workflow conditions distinguish dry-run from publication, and contract tests assert the route and receipt outcomes. No hosted Actions run has exercised the conditional transition or authenticated Hex call; see `behavior_unverified_items`. |
| 12 | Manual Release Please dispatch can perform release work only from the default branch. | ✓ VERIFIED | `release-please.yml` restricts the privileged job to `refs/heads/main`; workflow contract tests verify the restriction. |
| 13 | Manual Hex recovery executes trusted main-branch workflow code while binding source inputs to the requested release tag/SHA. | ✓ VERIFIED | `hex-publish.yml` checks out trusted code from `main`, passes dispatch inputs through quoted environment variables, and verifies requested ref provenance against the version tag; workflow contract tests pass. |
| 14 | Maintainers can retrieve machine-readable terminal receipts for success, failure, and cancellation with source, run, gate/publish, URL, verdict, attempt, and timestamp identity. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `release-receipt.sh` validates and atomically writes the canonical receipt; its 15 fixtures cover success, failure, dry-run, cancellation, identity rejection, idempotent retry, and notification failure. Both workflows wire 90-day artifact upload, and the observer has a separate cancellation upload. Hosted trigger execution, artifact retention, and retrieval have not yet been observed. Phase 249 covers the successful release receipt path; failure and cancellation event/artifact behavior still need hosted evidence. |
| 15 | Successful and ordinary failed gate/publish outcomes retain a terminal receipt before supplementary notification. | ✓ VERIFIED | The primary receipt job uses `if: always()`, depends on gate/publish jobs, and precedes the notifier; the release workflow ExUnit contract asserts that ordering and the upload action. |
| 16 | Receipt retries are idempotent and cannot turn missing or malformed source/gate data into success. | ✓ VERIFIED | The receipt writer enforces full source identity, validates verdict/stage consistency, rejects malformed data, preserves earlier stages, and refuses identity changes; 15 helper fixtures pass. |
| 17 | The cancellation observer accepts only a correlated, authoritative Release Please cancellation on main and writes linked cancellation evidence. | ✓ VERIFIED | The helper re-queries source run/workflow and compares repository, workflow ID/name/path, run ID, event, branch, SHA, and cancellation state before using the shared receipt writer. Its 22 source/event fixtures pass. The hosted workflow trigger and artifact upload remain in truth 14. |
| 18 | Cross-workflow release-source, candidate, permissions, credentials, concurrency, timeout, and receipt contracts are deterministic. | ✓ VERIFIED | The 13 Phase 248 ExUnit contract tests, hermetic shell suites, and `actionlint` pass for the four changed release workflows. |

**Score:** 13/18 truths verified (2 present, behavior-unverified; 3 failed).

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | Actual successful Sigra 1.6.0 publication and committed source-linked release receipt. | Phase 249 | Roadmap success criteria 1–2 explicitly require Hex publication from the gated source and a committed receipt identifying that exact source, tag, package, docs, and CI run. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/release-exact-source.sh` and fixture | Full tag/source/HEAD SHA assertion | ✓ VERIFIED | Substantive full-object-ID comparison; both pass and fail paths are exercised. |
| `scripts/ci/wait-for-ci-gate.sh` and fixture | Exact-SHA successful `ci-gate` poller | ✓ VERIFIED | Validates returned run metadata and exact head SHA; 15 fixture cases pass. |
| `scripts/ci/release-candidate-preflight.sh` and fixture | Exact candidate and content validator | ✓ VERIFIED | Validates run/PR identity and candidate changelog/ledger; 26 fixture cases pass. |
| `scripts/ci/release-environment-preflight.sh` and fixture | Environment policy and credential preflight | ✗ PARTIAL | Exact-main branch-policy checks pass and missing booleans fail closed, but the helper cannot prove environment-level secret names. |
| `scripts/ci/release-receipt.sh` and fixture | Validated atomic receipt writer | ✓ VERIFIED | Real JSON validation, atomic replacement, identity pinning, and failure/retry cases are exercised by 15 tests. |
| `scripts/ci/release-observer.sh` and fixture | Trusted cancellation correlation | ✓ VERIFIED | Authoritative source identity checks and cancellation receipt creation are exercised by 22 tests. |
| Release workflow YAML and ExUnit contracts | Wire gates, credential scopes, receipts, and notifications | ✓ VERIFIED | Artifacts exist, are substantive, and required links pass GSD’s artifact/key-link checks; local workflow contracts and `actionlint` pass. |

**Artifacts:** 21/21 plan-declared artifacts pass GSD existence/substance checks. The environment helper is present and wired, but its secret-scope behavior has the functional limitation recorded above.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `release-please.yml` | `release-exact-source.sh` | Immediately after tag checkout, before package setup | ✓ WIRED | GSD verifier found the source pattern; release workflow contract passes. |
| `release-please.yml` | `wait-for-ci-gate.sh` | Gate job passes release SHA and retains structured result | ✓ WIRED | GSD verifier found the source pattern; poller tests cover exact SHA and run identity. |
| `ci.yml` | `release-pr-automerge.yml` | Exact Release Please branch push → completed `workflow_run` | ✓ WIRED | Branch trigger and `ci-gate` exist; candidate fixtures cover push-run association. |
| `release-pr-automerge.yml` | `release-candidate-preflight.sh` | Data-only preflight, fresh reread, exact-head merge | ✓ WIRED | GSD verifier found the source pattern; the helper and workflow test cover identity and merge guard. |
| Release workflows | `release-environment-preflight.sh` | Job-scoped permissions, environment policy and secret checks | ⚠️ PARTIAL | Call sites are wired, but they pass scope-blind booleans and cannot establish environment-level secret membership. |
| Release workflows | `release-receipt.sh` | Aggregated job outputs → validated JSON → artifact upload | ✓ WIRED | GSD verifier found receipt links; ExUnit checks upload-before-notify ordering. Hosted artifact retrieval remains unobserved. |
| `release-run-observer.yml` | `release-observer.sh` | Main-branch cancellation event → authoritative source re-query | ✓ WIRED | Default-branch helper invocation and event fixture tests are present. |
| `release-observer.sh` | `release-receipt.sh` | Validated cancellation input through shared schema | ✓ WIRED | GSD verifier found the source pattern; 22 observer cases pass. |

**Wiring:** 11/11 plan-declared key links passed the GSD checker. The partial row is a substantive security-scope limitation that pattern matching alone does not encode.

### Data-Flow Trace

| Artifact | Data | Source | Produces Real Data | Status |
|----------|------|--------|-------------------|--------|
| Exact-source gate | Release SHA, tag-resolved SHA, checkout HEAD | Release Please output plus `git rev-parse` | Yes | ✓ FLOWING; helper compares the actual checked-out repository identities. |
| Required CI gate | Run ID, URL, head SHA, attempts, timestamps, verdict | GitHub `gh run list` / `gh run view` output and runner timestamps | Yes | ✓ FLOWING; strict JSON tests reject empty, malformed, or mismatched run data. |
| Release candidate gate | Current PR head, CI run and `ci-gate`, changelog, readiness ledger | GitHub API/CLI responses and source-bound ledger data | Yes | ✓ FLOWING; workflow fetches current records and helper validates them as data. |
| Terminal receipt | Source, job outcomes, run identities, timestamps, verdicts | GitHub workflow outputs and event contexts | Yes when hosted | ⚠️ WIRED; helper validates local fixtures, but no hosted receipt artifact was retrieved. |
| Cancellation receipt | Source run and workflow identities, manifest version, tag resolution | Authoritative GitHub API responses at source SHA | Yes when hosted | ⚠️ WIRED; helper tests pass, but no hosted cancellation event was observed. |

No application database or user-rendered dynamic data is part of this infrastructure phase.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Tag/source/checkout identity and poller exact-SHA results | `bash scripts/ci/release-exact-source.test.sh`; `bash scripts/ci/wait-for-ci-gate.test.sh` | Exact-source fixtures pass; poller 15/15 pass, including timeout, empty results, mismatched SHA, and truthful failure identity. | ✓ PASS |
| Exact-head candidate and release content gate | `bash scripts/ci/release-candidate-preflight.test.sh` | 26/26 pass, including stale/multiple candidates, failed gate, duplicate/unreleased notes, and omitted adopter summaries. | ✓ PASS |
| Terminal receipt schema and retries | `bash scripts/ci/release-receipt.test.sh` | 15/15 pass across success, ordinary failure, dry-run, cancellation, malformed identity, idempotence, and notification-failure cases. | ✓ PASS |
| Cancellation source-run correlation | `bash scripts/ci/release-observer.test.sh` | 22/22 pass across supported events, invalid identities, tag mismatch, and duplicate delivery. | ✓ PASS |
| Environment branch policy and missing-key failure | `bash scripts/ci/release-environment-preflight.test.sh` | 9/9 pass, including exact-main and missing-secret fail-closed fixtures. | ✓ PASS |
| Workflow contracts and syntax | `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs`; `actionlint` on the four release workflows | 13 ExUnit tests pass; `actionlint` exits 0. | ✓ PASS |
| Live target environment policies | `bash scripts/ci/release-environment-preflight.sh --repository szTheory/sigra` | `release-automation: main`, `hex-publish: main`, exit 0. | ✓ PASS |
| Live secret names only | `gh secret list` for repository and each environment | Repository: `HEX_API_KEY`, `RELEASE_PLEASE_TOKEN`; `release-automation`: `[]`; `hex-publish`: `[HEX_DRY_RUN_API_KEY]`. No values read. | ✗ BLOCKER |

The orchestrator’s earlier full-suite run reported 2,655 tests with two Phase 235 nested `sandbox-exec` failures; those exact two tests passed on an elevated rerun (2/2). The remaining suite passed in the original run. This does not replace the focused Phase 248 checks above.

### Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probes were found; the phase’s runnable checks are the hermetic shell and ExUnit suites listed above.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|--------|---------|----------|-----------------|---------|
| `scripts/ci/release-exact-source.test.sh`, `scripts/ci/wait-for-ci-gate.test.sh` | AUTO-01 | Yes | 0 | No | Behavioral/value | PASS |
| `scripts/ci/release-candidate-preflight.test.sh` | AUTO-01 | Yes | 0 | No | Behavioral/value | PASS |
| `scripts/ci/release-environment-preflight.test.sh` | AUTO-01 | Yes | 0 | No | Behavioral/value; scope-location limitation remains | PARTIAL |
| `scripts/ci/release-receipt.test.sh`, `scripts/ci/release-observer.test.sh` | AUTO-02 | Yes | 0 | No | Behavioral/value | PASS |
| Phase 248 ExUnit workflow contracts | AUTO-01, AUTO-02 | Yes | 0 | No | Structural/value | PASS for declared source contracts; hosted Actions transitions remain unexercised. |

**Disabled tests on requirements:** 0. **Circular expected-value generators:** 0. **Insufficient assertions:** none found in the local helpers; workflow-engine and hosted artifact behavior is explicitly routed as behavior-unverified.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| AUTO-01 | Plans 01–03, 05 | Exact source/gate, safe candidate merge, main-only credentials, scoped permissions, non-cancelling evaluation | BLOCKED | Exact-source, gate, candidate, permission, and concurrency code/tests pass. The open environment credential-scope blocker prevents this requirement from being complete. `.planning/REQUIREMENTS.md` currently labels it Complete; that status is inconsistent with this verification. |
| AUTO-02 | Plans 04–05 | Machine-readable success/failure/cancellation receipts | PARTIAL — live evidence deferred | Receipt and observer helpers, schemas, failure paths, and upload wiring pass local tests. A hosted terminal artifact has not been retrieved; successful 1.6.0 proof is assigned to Phase 249. |

**Requirement coverage:** 0 fully satisfied, 1 blocked, 1 partially implemented with hosted evidence outstanding.

### Decision Coverage

All 13 trackable decisions in `248-CONTEXT.md` are honored by the shipped artifacts; the GSD decision-coverage check reports 13/13, none outstanding. This gate is advisory and does not alter status.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/sigra/install/features/core.ex:73`; generated auth fixture lines 140, 143 | `placeholder` | ℹ️ Info | Intentional deterministic timestamp fallback and brand-mark asset fallback described by nearby implementation comments; neither is a release-workflow stub. |

No unreferenced TBD/FIXME/XXX debt markers, TODO/HACK comments, or empty release implementations were found. The temporary-file template `XXXXXX` in the receipt writer is `mktemp` entropy, not a placeholder. No phase-specific source stub was found.

### Runtime Checks to Complete After the Credential Gap

1. Dispatch a safe manual Hex `dry_run` from `main`; confirm the workflow validates the source, completes the dry-run, skips the publish step, and retains a `dry_run` receipt.
2. Retrieve hosted success, ordinary failure, and cancellation artifacts; compare source/run identities, verdicts, URLs, attempts, timestamps, and stage diagnostics with their source runs.

These checks are not counted as verified. The cancellation and failure artifact cases are not silently deferred; Phase 249 covers the successful Sigra 1.6.0 publication/receipt path only.

### Gaps Summary

The exact-source spine, exact-head candidate merge, receipt writer, and cancellation correlation are substantive, wired, and covered by passing hermetic tests. All five plan artifact lists and all 11 plan key links pass the GSD checks. The high/blocking gap is the live credential boundary: both environment policies allow exactly `main`, but the required release token and Hex write key remain at repository scope and are absent from the intended environments. The workflow presence booleans cannot prove which scope supplied each value, so they can report a credential as present without establishing the required environment protection. Keep the Phase 248 security finding open until the environment copies and repository-level removal are confirmed and the scope check is made auditable.

The working report is `gaps_found`; implementation is substantially present, but Phase 248 verification is not complete. Successful publication evidence is explicitly routed to Phase 249. The two hosted state transitions above remain behavior-unverified until automated hosted evidence is captured.

---

_Verified: 2026-10-08T23:51:24Z_
_Verifier: the agent (gsd-verifier)_

### Post-setup evidence update (2026-10-09)

The initial verification above recorded the live state on 2026-10-08. The maintainer has since added the replacement credentials to the protected environments. Name-only queries now show `RELEASE_PLEASE_TOKEN` under `release-automation`, and `HEX_API_KEY` plus `HEX_DRY_RUN_API_KEY` under `hex-publish`. Both environments remain restricted to `main` with administrator bypass disabled, and the live environment-policy preflight passes. See `248-ENVIRONMENT-SECRETS-RECEIPT.json`; no values were read or recorded.

The Phase 248 workflow implementation is not yet deployed on GitHub `main`, and the repository-level secret copies remain because the current `main` workflows still consume them. Therefore this update resolves the missing-environment-setup prerequisite, but it does not close the credential-boundary truth or change the original verification score. Keep the repository-level copies until the protected workflows are deployed and hosted checks prove the environment path; then remove those copies and re-run the phase verifier.
