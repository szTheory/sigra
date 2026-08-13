---
phase: 246-hosted-and-direct-login-ceremonies
plan: 13
subsystem: generated-host authentication evidence
tags: [phoenix, app-sessions, fetch-app-session, pkce, mfa, ci]
requires:
  - phase: 246-12
    provides: generated hosted and direct MFA ceremonies
provides:
  - Generated hosted and direct credentials authenticated through FetchAppSession
  - HTTP replay rejection with one-family persistence assertions
  - Receipt-last v2 evidence with source SHA-256 bindings and CI validation
affects: [APP-02, APP-03, generated-host CI]
tech-stack:
  added: []
  patterns: [temporary protected proof route, causal receipt-last evidence, CI-side receipt verification]
key-files:
  created: []
  modified:
    - scripts/ci/generated-app-login-runtime-proof.sh
    - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
    - .github/workflows/generated-app-login-runtime-proof.yml
key-decisions:
  - "Disposable proof hosts inject FetchAppSession only into a temporary protected route and return bounded facts."
  - "The v2 receipt is atomically published only after both real ceremonies, replays, and protected-route checks complete."
requirements-completed: [APP-02, APP-03]
coverage:
  - id: D1
    description: Fresh generated hosted and direct credentials authenticate through FetchAppSession and remain valid after HTTP replay rejection.
    requirement: APP-02
    verification:
      - kind: e2e
        ref: bash scripts/ci/generated-app-login-runtime-proof.sh --all
        status: pass
      - kind: integration
        ref: test/sigra/planning/phase_246_generated_app_login_runtime_test.exs#fresh-host proof authenticates generated credentials and rejects replays over HTTP
        status: pass
    human_judgment: false
  - id: D2
    description: Receipt v2 records only executed transitions and exact source bindings before CI retains the artifact.
    requirement: APP-03
    verification:
      - kind: integration
        ref: test/sigra/planning/phase_246_generated_app_login_runtime_test.exs#runtime receipt is versioned causal source-bound and parsed before upload
        status: pass
      - kind: e2e
        ref: GENERATED_APP_LOGIN_RUNTIME_PROOF_ARTIFACT_DIR=<tmp> bash scripts/ci/generated-app-login-runtime-proof.sh --all
        status: pass
    human_judgment: false
metrics:
  duration: 18m
  completed: 2026-08-13
  tasks: 2
  files: 3
status: complete
---

# Phase 246 Plan 13: Generated Runtime Credential Evidence Summary

**Fresh generated hosted and direct ceremonies now prove FetchAppSession authentication, HTTP replay rejection, and a receipt-last CI artifact bound to exact source hashes.**

## Accomplishments

- Added a temporary generated-host protected route using `Sigra.Plug.FetchAppSession`; it returns only Scope identity and bounded app-session facts.
- Verified both issued credentials against that route, replayed both one-time HTTP inputs, confirmed original credentials remain valid, and asserted exactly one family per ceremony.
- Replaced the v1 prose receipt with a causally-set v2 receipt and CI parser that rejects missing, malformed, false, stale-schema, or SHA-mismatched evidence before upload.

## Task Commits

1. **Task 1: Authenticate both generated credentials and reject both replays** — `157fcbf9` (feat)
2. **Task 2: Make the structured receipt and CI claims causally exact** — `2a85c47f` (feat)

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/plug/fetch_app_session_test.exs --trace` — PASS (7 tests).
- `bash scripts/ci/generated-app-login-runtime-proof.sh --all` — PASS; two disposable hosts completed their real ceremonies, protected-route authentication, and replay checks.
- `GENERATED_APP_LOGIN_RUNTIME_PROOF_ARTIFACT_DIR=<tmp> bash scripts/ci/generated-app-login-runtime-proof.sh --all` plus an independent JSON/SHA parser — PASS.
- `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace`, `bash -n scripts/ci/generated-app-login-runtime-proof.sh`, and `git diff --check` — PASS.

## Decisions Made

- The proof route is injected only into disposable hosts, preserving shipped generated router contracts while exercising the real FetchAppSession plug.
- Receipt status fields are hard-coded only after their corresponding assertion functions complete, then atomically renamed as the final successful write.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. The temporary route is confined to disposable proof hosts and exposes only bounded trusted facts.

## Self-Check: PASSED

- Confirmed all three modified plan files exist.
- Confirmed task commits `157fcbf9` and `2a85c47f` exist in git history.
