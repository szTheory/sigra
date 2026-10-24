---
phase: make-failures-reproducible-and-report-the-result
plan: "02"
subsystem: testing
tags: [python, subprocess, zipfile, ci-diagnostics]
requires:
  - phase: 255-01
    provides: execution preflight and replay prerequisites for Phase 255
provides:
  - Native command recorder that preserves independent streams, exit codes, and signals across cleanup failures
  - Invocation-bound diagnostic staging and final ZIP verification
affects: [255-03, 255-04, 255-05, 255-06, 255-07]
actuals:
  tokens: 11341
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 798de3931e39e6b4a9aa02b7831c2fd35a4cfe36
plan_head_after: bb97e10fdcfe4cd49253555f27e1813472f90a94
tech-stack:
  added: []
  patterns: [standard-library subprocess capture, explicit diagnostic manifests, verified ZIP members]
key-files:
  created:
    - scripts/ci/ci-command-record.py
    - scripts/ci/ci-command-record.test.py
    - scripts/ci/ci-diagnostic-bundle.py
    - scripts/ci/ci-diagnostic-bundle.test.py
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-02-01-RED.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-02-02-RED.json
  modified: []
key-decisions:
  - "Capture child stdout and stderr as separate binary files and keep the child exit or signal independent from cleanup status."
  - "Stage only manifest-listed files; sanitize bounded logs, withhold authentication paths and sentinels, and bind final members back to source bytes."
patterns-established:
  - "Render reproduction with shlex.join and an explicit cwd prefix; never evaluate recorded argv or output."
  - "Require synthetic-account provenance before retaining traces and record when a trace is unavailable."
requirements-completed: [CIDX-02]
coverage:
  - id: D1
    description: Native command failures retain their original outcome, streams, identity, and shell-safe reproduction.
    requirement: CIDX-02
    verification:
      - kind: unit
        ref: scripts/ci/ci-command-record.test.py#CommandRecordTest
        status: pass
    human_judgment: false
  - id: D2
    description: Diagnostic ZIPs contain only invocation-listed, source-bound files and reject auth state, sentinels, duplicate members, and path escapes.
    requirement: CIDX-02
    verification:
      - kind: unit
        ref: scripts/ci/ci-diagnostic-bundle.test.py#DiagnosticBundleTest
        status: pass
      - kind: unit
        ref: scripts/ci/ci-metrics-security.test.py#SecurityContractsTest
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-10-24
status: complete
---

# Phase 255 Plan 02: Native Failure Diagnostics Summary

**A standard-library recorder preserves the original command failure and a verified ZIP stager keeps diagnostic artifacts bound to the current invocation.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-10-24T16:17:00Z
- **Completed:** 2026-10-24T16:24:05Z
- **Tasks:** 2
- **Files modified:** 6 (four scripts/tests and two RED evidence records)

## Accomplishments

- Added a recorder that retains exact argv, cwd, source/ref and dirty state, observed tool versions, allowlisted non-secret configuration, optional detected seed, and shell-safe reproduction. It writes stdout and stderr independently and returns the child's exit code or re-emits its signal even when cleanup fails.
- Added explicit diagnostic staging and verification. Every member is allowlisted by an invocation manifest, hashed, checked against its source bytes, and tied to source, run, attempt, job, seam, and invocation identities.
- Added adversarial checks for auth state, planted sentinels, stale files, missing promised files, duplicate ZIP members, altered payloads, absolute paths, and escaping symlinks. Traces require registered synthetic-account provenance; missing traces retain a concrete reason.

## Task Commits

1. **Task 1: Execute one native failure and retain its original outcome and reproduction**
   - `e6cb2cf3d` — test(255-02): add failing native command recorder test
   - `d246c1fc9` — feat(255-02): preserve native command failures and reproduction
2. **Task 2: Stage only invocation-owned diagnostics and verify the finished bundle**
   - `c96f1c15e` — test(255-02): add failing diagnostic bundle tests
   - `bb97e10fd` — feat(255-02): stage and verify invocation diagnostics

**Plan metadata:** `docs(255-02): complete native failure diagnostics plan` (this summary commit)

## TDD Gate Compliance

- **Task 1 RED:** `255-02-01-RED.json`; classifier returned `RED_EVIDENCE_OK` for the named test. The assertion expected caller status 42 and observed 2 because the recorder was absent. The planned failure was observed without import, syntax, fixture, or discovery faults. RED commit: `e6cb2cf3d`.
- **Task 1 GREEN:** The recorder implementation made the real exit, signal, stream, metadata, and argv quoting tests pass. GREEN commit: `d246c1fc9`.
- **Task 2 RED:** `255-02-02-RED.json`; classifier returned `RED_EVIDENCE_OK` for the named test. The stage-success assertion expected 0 and observed 2 because the stager was absent. The planned failure was observed without import, syntax, fixture, or discovery faults. RED commit: `c96f1c15e`.
- **Task 2 GREEN:** The stager and verifier passed all archive safety and source-binding tests. GREEN commit: `bb97e10fd`.

## Verification

- `python3 -B scripts/ci/ci-diagnostic-bundle.test.py` — passed, 7 tests.
- `python3 -B scripts/ci/ci-command-record.test.py` — passed, 4 tests.
- `python3 -B scripts/ci/ci-metrics-security.test.py` — passed, 23 tests.
- `git diff --check` — passed.

## Files Created/Modified

- `scripts/ci/ci-command-record.py` — native process recorder and metadata capture.
- `scripts/ci/ci-command-record.test.py` — real exit, signal, cleanup, stream, and quoting checks.
- `scripts/ci/ci-diagnostic-bundle.py` — allowlisted ZIP stage and verify CLI.
- `scripts/ci/ci-diagnostic-bundle.test.py` — finished-archive security tests.
- `255-02-01-RED.json`, `255-02-02-RED.json` — unchanged real unittest reports and semantic RED assessments.

## Decisions Made

- Command argv is retained as a JSON array; reproduction text is display-only and rendered with `shlex.join` after an explicit cwd prefix.
- Only selected non-secret environment keys enter the record. The recorder does not dump the full environment or infer a seed when the command does not provide one.
- The archive contains sanitized bounded log text, while the original command stream bytes remain in the protected invocation directory. Verification checks archive members against the invocation manifest and source bytes, not only against hashes copied into the archive.
- Trace metadata states that traces can contain authentication requests and DOM content. Synthetic-account provenance and sentinel checks are required; excluding `.auth` alone is not treated as proof that a trace is safe.

## Deviations from Plan

None - plan executed as written. The test for archived command output accounts for the existing sanitizer removing the terminal newline, and separately confirms that the original invocation stream retains it.

## Issues Encountered

- The first scoped Git write was denied by the workspace permission boundary. The same commit was then completed through the already-authorized Git-write path with hooks enabled.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 is implemented and locally verified. Plan 03 can build on the recorder and archive CLI. Phase 255 and the full CIDX-02 requirement remain open until the later planned integrations and phase verification complete. No hosted CI was run in this plan.

## Self-Check: PASSED

- All four assigned script/test files and both RED evidence records exist.
- The four task commits are present on the current branch and descend from the recorded plan base.
- All three required verification commands passed with 34 total tests.
- The recorded plan head and commit count were measured from the persisted plan ledger.

---
*Phase: make-failures-reproducible-and-report-the-result*
*Completed: 2026-10-24*
