---
phase: 140-deprecation-hygiene-verification-docs-close
plan: "03"
subsystem: verification
tags: [proof-bundle, deprecation, docs-render, mix-docs, credo, mix-sigra-doctor]
completed: "2026-05-29"

dependency_graph:
  requires:
    - "140-01 (DEPR edits landed)"
    - "140-02 (DOC-01 guide sections landed)"
  provides:
    - "140-VERIFICATION.md (eight-gate proof bundle)"
    - "PROOF-01 satisfied"
    - "DEPR-01/DEPR-02 docs-render proof (Gate 8)"
  affects:
    - ".planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md"

tech_stack:
  added: []
  patterns:
    - "Eight-gate proof bundle with verbatim results (Phase 136 pattern extended)"
    - "Gate 8: docs-render grep assertion against doc/ tree post mix docs"
    - "Rule 1 auto-fix: remove broken ExDoc backtick-linked hidden-function references"

key_files:
  created:
    - ".planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md"
  modified:
    - "lib/sigra/doctor.ex (moduledoc: remove backtick-linked @doc false function references)"
    - "lib/sigra/optional_deps.ex (moduledoc + encryption_active?/1 doc: same fix)"
    - "mix.lock (threadline 0.5.0 -> 0.6.0 via Gate 3 dep restore)"

decisions:
  - "Record pre-existing environment failures (Xcode license, example app encryption stub) verbatim rather than suppressing — anti-overclaim policy per plan instructions"
  - "Rule 1 auto-fix applied to Gate 5 blocker: doctor.ex and optional_deps.ex backtick-linked hidden functions caused mix docs --warnings-as-errors to exit 1"
  - "Gate 7 exit 1 (doctor: example app encryption misconfigured) treated as non-blocking pre-existing finding per plan Task 2 instructions"

metrics:
  duration: "953s (~16 min)"
  completed: "2026-05-29"
  tasks_completed: 2
  files_changed: 3
---

# Phase 140 Plan 03: Proof-Bundle Execution — Summary

**One-liner:** Eight-gate proof bundle executed on Phase 140 HEAD; 140-VERIFICATION.md filed with verbatim results; DEPR-01/DEPR-02 docs-render proof confirmed via Gate 8 grep; Gate 5 doc-reference fix applied as Rule 1 auto-fix.

## What Was Built

140-VERIFICATION.md filed with eight proof gates against Phase 140 HEAD:

- **Gate 2** (audit subtree): 60 tests, 0 failures, exit 0 — PASS
- **Gate 3** (dep-off lane): compile exit 0; threadline absent; mix.lock restored; test findings recorded verbatim
- **Gate 4** (test/example/): 236 tests, 0 failures, exit 0 — PASS
- **Gate 5** (mix docs --warnings-as-errors): exit 0 after Rule 1 fix — PASS
- **Gate 6a** (credo --strict): exit 0; 194C/107W/937R/1225RE/1434D advisory — ADVISORY
- **Gate 6b** (credo --only sigra): exit 0 — PASS
- **Gate 7** (mix sigra.doctor): exit 1 (pre-existing example app encryption stub) — FINDING recorded verbatim
- **Gate 8** (docs-render grep): both "Scheduled for removal in 0.4.0" and "Scheduled for removal in 0.5.0" confirmed in doc/ — PASS

Pre-existing findings recorded verbatim:
- **Gates 1 and 3 (test step)**: 11 failures in install/upgrade integration tests — Xcode license not accepted on this machine causes `argon2_elixir` NIF to fail in tmp apps. Not caused by Phase 140.
- **Gate 7**: `test/example/` passkeys enabled but vault on plaintext stub → doctor exits 1. Not caused by Phase 140.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed broken ExDoc hidden-function backtick references causing Gate 5 to fail**

- **Found during:** Task 1, Gate 5 execution
- **Issue:** `lib/sigra/doctor.ex` `@moduledoc` contained backtick-linked references to three `@doc false` functions: `Sigra.Application.verify_vault!/1`, `Sigra.Application.attach_forwarders/0`, and `Sigra.Audit.Forwarders.oban_running?/1`. `lib/sigra/optional_deps.ex` had two backtick-linked references to `Sigra.Application.verify_vault!/1`. ExDoc auto-resolves `Module.function/arity` inside backticks as doc links; when the target function is `@doc false` (hidden), ExDoc emits a warning and `--warnings-as-errors` converts it to exit 1.
- **Fix:** Replaced backtick-link syntax with plain prose for all six hidden-function references in both files. No behavior change — only `@moduledoc` and `@doc` strings modified.
- **Files modified:** `lib/sigra/doctor.ex`, `lib/sigra/optional_deps.ex`
- **Commit:** `6f60743`

### Pre-existing Findings (not deviations — recorded per anti-overclaim policy)

- **Gates 1 and 3 test failures**: 11 failures, 2 invalid — Xcode license not accepted. Pre-existing machine-state issue. Not a Phase 140 deviation.
- **Gate 7 exit 1**: example app encryption stub. Pre-existing wiring gap. Not a Phase 140 deviation.

## Known Stubs

None. This plan is verification-only; no application code was generated with placeholder data.

## Threat Flags

None. This plan ran existing test suites, an existing Mix task, and an existing doctor command. The Rule 1 fix modified only `@moduledoc`/`@doc` strings — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- FOUND: `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md`
- FOUND: `lib/sigra/doctor.ex`
- FOUND: `lib/sigra/optional_deps.ex`
- FOUND: commit `6f60743` (Task 1 doc-reference fix)
- FOUND: commit `ddb6af0` (Task 2 VERIFICATION.md)
