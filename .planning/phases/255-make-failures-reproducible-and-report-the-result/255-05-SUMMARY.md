---
phase: 255-make-failures-reproducible-and-report-the-result
plan: "05"
subsystem: testing
tags: [playwright, diagnostics, traces, postgres, archive-sanitization]
requires:
  - phase: 255-02
    provides: scoped local browser command recording and invocation identity
  - phase: 255-04
    provides: safe diagnostic bundle staging and verification
provides:
  - Real zero-retry Playwright failure traces with passing trace disposal, including the adminTheme manual context
  - Isolated local browser diagnostics for pre-context failures, startup failures, process signals, and sequential invocations
  - Sanitized, source-bound browser evidence and an inspected safe trace bundle
affects: [255-06, browser-ci, diagnostics]
actuals:
  tokens: 41761
  tasks: 2
  commits: 27
  plan_head_before: 0a327504f53067037329b4bb08f18e64d36f9398
  plan_head_after: ce60c0d50ed32c9d84ead20ffc7ebf08771cae50
tech-stack:
  added: []
  patterns: [invocation-scoped Playwright tracing, allowlisted diagnostic collection, sanitized trace archive staging]
key-files:
  created:
    - scripts/ci/ci-browser-diagnostics.test.mjs
    - scripts/ci/fixtures/playwright-diagnostics.config.ts
    - scripts/ci/fixtures/playwright-diagnostics.spec.ts
    - scripts/ci/fixtures/playwright-admin-theme-diagnostics.spec.ts
  modified:
    - scripts/ci/ci-browser-local.py
    - scripts/ci/ci-diagnostic-bundle.py
    - scripts/ci/ci-diagnostic-bundle.test.py
    - test/example/priv/playwright/fixtures/adminTheme.ts
    - test/example/priv/playwright/lib/reporters/failure-jsonl.mjs
    - test/example/priv/playwright/playwright.config.ts
    - .planning/execution/255-local/BROWSER-DIAGNOSTICS.json
key-decisions:
  - "Enable retain-on-failure and custom-context tracing only for explicitly opted-in diagnostic invocations."
  - "Use a filesystem allowlist rooted at invocation records, command streams, registered traces, and native reports; reject symlinks before opening files."
  - "Keep native-tested source identity 59ed88c separate from the evidence-writer source 7bad04a in the final captured report."
patterns-established:
  - "Manual browser contexts register synthetic-account provenance and retain traces only on failure."
  - "Trace archives are inspected after decompression, redacted, hashed, and verified before inclusion."
requirements-completed: []
coverage:
  - id: D1
    description: "A real first-attempt failure retains readable Playwright and adminTheme traces, while a passing invocation discards its trace."
    verification:
      - kind: e2e
        ref: "scripts/ci/ci-browser-diagnostics.test.mjs --native; BROWSER-DIAGNOSTICS.json source 59ed88c32673635757981770e50c228e92158b15"
        status: pass
    human_judgment: false
  - id: D2
    description: "Local pre-context failures, server startup failure, termination, and sequential runs preserve independent evidence and safe outputs."
    verification:
      - kind: integration
        ref: "scripts/ci/ci-browser-diagnostics.test.mjs --native; 7 native cases, 3 inspected traces"
        status: pass
      - kind: unit
        ref: "python3 -B scripts/ci/ci-diagnostic-bundle.test.py (11 tests)"
        status: pass
    human_judgment: false
duration: 48min
completed: 2026-10-24
status: complete
---

# Phase 255 Plan 05: Make Failures Reproducible and Report the Result Summary

**Real local browser failures now retain useful, source-identified evidence across Playwright-owned and adminTheme contexts, while passing traces and auth data stay out of the safe bundle.**

## Performance

- **Duration:** 48 minutes (from the first task commit through the final evidence normalization)
- **Started:** 2026-10-24 13:32 EDT
- **Completed:** 2026-10-24 14:20 EDT
- **Tasks:** 2/2
- **Files changed:** 28 across task commits, including scoped evidence and TDD records

## Accomplishments

- Added opt-in Playwright failure tracing for retry-zero diagnostics, including explicit trace start/stop handling for the real `adminTheme` manual context. The failing trace ZIPs were opened and checked for useful trace records; the subsequent passing invocation retained no trace.
- Added local native probes for assertion failure, pass-after-failure, Phoenix startup conflict, discovery error, browser launch failure before context creation, actual SIGTERM, and cleanup failure. Independent stdout/stderr/report streams and missing-context or runner-termination reasons are recorded.
- Restricted collection to explicit invocation-owned evidence paths, rejected symlinks, scanned nested ZIP members, and sanitized trace JSON/HAR content. The final verified bundle SHA-256 is `2699db3d619584d798e2e20c86f2eb75f0f875fc6ad5a3792f0c7583b38b2d10`.
- Preserved the actual native run at source `59ed88c32673635757981770e50c228e92158b15`. The final writer source is separately recorded as `7bad04a200ffcecc759cd1d947c141609d96a037`. A focused replay of the captured owner record verified wrapper exit 0, child exit 143, and signal 15 without repeating the browser run.

## Verification

- Required native gate passed on source `59ed88c32`: 7 cases, 3 real traces, retries 0, workers 1. The resulting report retains selected native identities, trace member hashes, sanitization metadata, negative-case outcomes, and source identity.
- `python3 -B scripts/ci/ci-diagnostic-bundle.test.py`: 11 passed.
- `python3 -B scripts/ci/ci-command-record.test.py`: 4 passed.
- `python3 -B scripts/ci/ci-browser-local.test.py`: 12 passed.
- `PATH=/Users/jon/.asdf/installs/nodejs/20.19.5/bin:$PATH node --test scripts/ci/ci-browser-diagnostics.test.mjs`: 5 passed.
- `PATH=/Users/jon/.asdf/installs/nodejs/20.19.5/bin:$PATH node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs`: 5 passed.
- `node --check scripts/ci/ci-browser-diagnostics.test.mjs`: passed.
- The captured termination row normalization passed with wrapper=0, child=143, signal=15, and native/writer source hashes kept distinct.
- One later redundant native run was canceled after the required gate had passed. Its owned server ports were closed. Its owner record showed no owned process and no recorded cleanup errors; its one `database_created: true` database was found by exact name, dropped, and confirmed absent. The canceled run is not counted as a passing native result.

## Task Commits

The 27 plan commits measured from the recorded plan base are:

1. `fe5a1f464` test pre-test reporter evidence (Task 1 RED)
2. `8e128e7e1` retain scoped Playwright failure traces
3. `29f5f5db3` assert native diagnostic mode (Task 2 RED)
4. `f3f734d3a` add isolated local Playwright probes
5. `626b8965c` require PostgreSQL role fallback (RED)
6. `38438e4c1` restore local role and trace ownership
7. `30c25e618` isolate default and manual trace fixtures (RED)
8. `8e7adb18f` accept the adminTheme trace lifecycle result
9. `0d8fd52ed` reject nested trace secrets (RED)
10. `6deba76e2` inspect retained trace ZIP members
11. `112e3b5fd` require startup and termination probes (RED)
12. `5310fd1e6` assert signal exit normalization (RED)
13. `a2ae3e927` capture startup and termination diagnostics
14. `a423b7d20` orchestrate native browser diagnostics
15. `7565fef5d` verify expected native failure semantics
16. `bc40f77bc` inspect Playwright trace member variants
17. `854ded9f0` require pre-context unavailable reasons (RED)
18. `b013250af` report traces unavailable before context creation
19. `43a4ca74f` require safe usable trace bundles (RED)
20. `408d68446` redact auth data in retained trace bundles
21. `2a3c35743` bind overhead timing to native test duration
22. `cb35681c0` require registered adminTheme traces (RED)
23. `2a1fd9daf` collect only native diagnostic artifacts
24. `59ed88c32` keep safe bundle assertions source-bound; required native gate passed here
25. `7bad04a20` record native signal outcomes directly in the result writer
26. `d0c4785e7` preserve the verified native report and sanitized bundle
27. `ce60c0d50` normalize captured termination evidence from the verified owner record

## TDD Gate Compliance

- Assertion-based RED evidence was committed before the matching GREEN changes. RED commits include `fe5a1f464`, `626b8965c`, `30c25e618`, `0d8fd52ed`, `112e3b5fd`, `5310fd1e6`, `854ded9f0`, `43a4ca74f`, and `cb35681c0`.
- The captured classifier records show executed target assertions failing for the missing reporter `onError` behavior, missing pre-context reason, and unsafe nested `storageState` handling. Their evidence is under `.planning/execution/255-local/tdd-red-reporter-reason/` and `.planning/execution/255-local/tdd-red-trace-cookie-v2/`.
- Corresponding behavior was implemented and the required final fast tests passed. The native gate then passed on the fixed source `59ed88c32`.
- Plan-level TDD mode: false; the plan uses task-level `tdd="true"` gates.

## Files Created/Modified

- `scripts/ci/ci-browser-diagnostics.test.mjs` - runs the native diagnostics matrix, validates actual trace ZIPs, and writes evidence.
- `scripts/ci/fixtures/playwright-diagnostics.config.ts`, `scripts/ci/fixtures/playwright-diagnostics.spec.ts`, and `scripts/ci/fixtures/playwright-admin-theme-diagnostics.spec.ts` - isolated browser probes.
- `scripts/ci/ci-browser-local.py` - owns isolated server/database runs and records signals and cleanup.
- `scripts/ci/ci-diagnostic-bundle.py` and `scripts/ci/ci-diagnostic-bundle.test.py` - allowlisted collection, inspection, redaction, and archive verification.
- `test/example/priv/playwright/fixtures/adminTheme.ts`, `test/example/priv/playwright/lib/reporters/failure-jsonl.mjs`, and `test/example/priv/playwright/playwright.config.ts` - opt-in trace lifecycle and independent reporter events.
- `.planning/execution/255-local/BROWSER-DIAGNOSTICS.json` and `browser-diagnostics-1792865705155/diagnostics.zip` - native result and sanitized verified bundle. Original auth-bearing trace files remain local and untracked.

## Decisions Made

- Trace capture stays opt-in and scoped to affected diagnostic invocations; ordinary consumers retain their default behavior.
- The collector uses explicit evidence paths and rejects symlinks rather than walking the entire invocation directory.
- The native-tested source identity remains the one that actually ran. The later result-writer source is identified separately; captured process outcomes were normalized from the native owner record.
- Passing trace overhead mode is implemented but was not run here; Plan 06 owns its final-source measurement and hosted canary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored the documented PostgreSQL role fallback**
- **Found during:** Task 2
- **Issue:** The local runner preflight and child environment failed when `PGUSER` was unset, despite the documented local-user default.
- **Fix:** Added a `getpass.getuser()` fallback consistently to both paths and a focused regression test. Preserved the original failed preflight as evidence.
- **Files modified:** `scripts/ci/ci-browser-local.py`, `scripts/ci/ci-browser-local.test.py`
- **Verification:** `python3 -B scripts/ci/ci-browser-local.test.py` (12 passed) and successful native run.
- **Committed in:** `38438e4c1`

**2. [Rule 1 - Bug] Corrected trace inspection and sanitization for real Playwright archives**
- **Found during:** Tasks 1 and 2
- **Issue:** Real traces include auth-related cookie, HAR, body, and query data and multiple Playwright archive member layouts. A broad `storageState` match withheld a usable trace; count-only checks also could not prove useful content.
- **Fix:** Inspect decompressed archive members, redact sensitive values while retaining trace records, record original/sanitized hashes and removed fields, and reject planted sentinels, auth paths, and unsafe members.
- **Files modified:** `scripts/ci/ci-diagnostic-bundle.py`, `scripts/ci/ci-diagnostic-bundle.test.py`, `scripts/ci/ci-browser-diagnostics.test.mjs`
- **Verification:** 11 bundle tests passed; actual native traces and final bundle inspected and verified.
- **Committed in:** `bc40f77bc`, `408d68446`

**3. [Rule 1 - Bug] Restricted native collection to owned evidence paths**
- **Found during:** Task 2
- **Issue:** Recursive scanning encountered symlinks in the invocation-owned compiled build tree and risked including unrelated files.
- **Fix:** Collect only registered reports, streams, owner records, and trace paths; reject regular-file, directory, and dangling symlinks without opening them.
- **Files modified:** `scripts/ci/ci-browser-diagnostics.test.mjs`
- **Verification:** Focused collector test passed and captured-output end-to-end replay passed before the required native gate.
- **Committed in:** `2a1fd9daf`

**4. [Rule 1 - Bug] Preserved wrapper and child signal outcomes independently**
- **Found during:** Task 2
- **Issue:** Python subprocess return code `-15` was not the documented shell-compatible child exit `143`; the wrapper's own success exit `0` is a separate outcome.
- **Fix:** Preserve wrapper=0, child=143, signal=15 in explicit fields and normalize the captured evidence row using the recorded owner data.
- **Files modified:** `scripts/ci/ci-browser-local.py`, `scripts/ci/ci-browser-local.test.py`, `.planning/execution/255-local/BROWSER-DIAGNOSTICS.json`
- **Verification:** Focused signal regression and captured result normalization passed; the browser behavior itself had already passed at source `59ed88c32`.
- **Committed in:** `5310fd1e6`, `7bad04a20`, `ce60c0d50`

**Total deviations:** 4 auto-fixed issues. **Impact:** All address reproducibility, archive safety, or truthful process outcome recording within this plan's scope.

## Issues Encountered

- A first captured-output replay exposed duplicate native report rows and stale-output assertions. These were corrected and the full collector-to-result replay passed before the required native run.
- A later redundant browser attempt was canceled because it repeated already-passing behavior for an evidence-only writer change. Its owned database was removed after exact owner-record identification; it is excluded from the passing results above.
- `git diff --check` reports two trailing-whitespace lines in the intentionally preserved raw TDD RED TAP report. No source or final JSON whitespace errors were reported.

## User Setup Required

None. No external service configuration was added.

## Next Phase Readiness

Plan 05 implementation and its required local native verification are complete. Plan 06 still owns the hosted canary, final-source overhead measurement, and any final-source acceptance that consumes hosted artifacts. CIDX-02 remains unresolved until that evidence is collected; this summary does not claim the overall Phase 255 requirement is complete.

---
*Phase: 255-make-failures-reproducible-and-report-the-result*
*Completed: 2026-10-24*

## Self-Check: PASSED

- Summary file exists at the plan output path.
- First and final task commits (`fe5a1f464`, `ce60c0d50`) are ancestors of HEAD.
- The persisted plan ledger measures 27 task/evidence commits before the summary commit.

## Final review follow-up

After the independent review repairs, the native seven-case browser gate passed again and verified three retained sanitized traces. See `.planning/execution/255-verification/BROWSER-DIAGNOSTICS-AFTER-REVIEW.json` and `BROWSER-CAPTURE.json`. Original auth-bearing files remain local under `.gsd/temp/phase255-final/`; the shared ZIP has a verified matching digest.
