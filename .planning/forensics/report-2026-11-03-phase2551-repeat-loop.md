# Phase 255.1 repeat-loop forensic report

## Symptom

The next route still said to execute Plan09 generation07 even though that exact preparation had already run and stopped. The phase plan had no matching Plan09 summary, and the active handoff still recorded `invocation_attempted: false`, zero requests, and zero spend.

## Evidence trail

1. `.planning/HANDOFF.json` and `.planning/state.json`, `active_execution`: both route to `$gsd-execute-phase 255.1 --wave 2` and mark generation07 unattempted with all counts zero. These values disagree with the captured execution artifacts.
2. The matching phase summary, `255.1-09-SUMMARY.md`, did not exist. OpenGSD therefore had no terminal Plan09 record to keep Wave2 from dispatching it again.
3. Generation07 `PREP-LEDGER.json` records 14 readiness requests and 55 control-stage requests (69 total), with zero mutations. `preparation/EXECUTION.json` records `finite_driver_collector_failed:exit_1`, no acquisitions, zero samples, and `blocked`. The candidate was not dispatched.
4. `preparation/preparation-acquisitions/phase2551-prep-c291e6b1ce2075cc89859c44-control-existing/request-budget.json` records the 55 collector requests. It contains no HTTP status or response bodies, so it cannot identify which child request or validation caused the failure.
5. `scripts/ci/ci_repaired_driver.py:175-181` captures the collector's stdout and stderr, then discards both when the command exits nonzero. The persisted diagnostic is only the exit code. This removed the most useful evidence for the next diagnosis.
6. `scripts/ci/ci-repaired-comparison.py:7618-7628` rejects any predecessor ledger with a collector request. But the same module's exact stopped-generation validator accepts the specific generation05 case of 14 readiness GETs plus one successful control `/rate_limit` GET (`:8468-8486`), and Plan09 generation07 history binds that exact generation05 ledger. `verify-prepared` consequently recorded `preparation_history_revalidation_failed:fresh_preparation_history_prior_ledger_spend_invalid` after the 69 generation07 requests had already been spent.
7. The one actual `verify-prepared` call completed under its 15-minute timeout and recorded `PREP-VERIFY.json` as `blocked` / `blocked` / `blocked`; it reports the invalid predecessor spend, incomplete control and candidate receipts, and missing candidate mutation intent. It created no samples.
8. `preparation/OUTER-PROCESS.json` was initially absent because the local wrapper raised a path-format `ValueError` after the preparation subprocess returned. It has now been reconstructed from the exact stdout, stderr, execution result, and filesystem timestamps; the receipt labels its timing and exit-code basis as reconstructed.
9. A process listing was denied by the host, so no independent `ps` confirmation was available. The controller's final execution JSON and stdout were written, and the wrapper's error occurred after subprocess return; there is no artifact indicating that the controller was interrupted mid-run.

## Root causes

There are three separate defects in the route and execution chain:

- **Stale route state:** the dispatcher-facing state files were not updated after the one-use command ran. Since GSD decides whether a plan is terminal from its matching summary, handoff flags alone could not stop redispatch.
- **Conflicting predecessor rules:** generation history generation accepts and records the exact one-GET generation05 stop, while actual preparation verification rejects every predecessor with any collector request. That makes the approved continuation internally inconsistent.
- **Lost collector error:** the transport throws away the child diagnostic on every nonzero exit. The actual reason for generation07's collector exit remains unknown; the surviving artifacts do not support guessing it.

The wrapper's path-format error is a separate receipt-writing bug. It did not cause the collector failure or repeat route, but it made the failure harder to audit.

## Fix

1. Mark generation07 as attempted and halted with its actual 69-request spend, create the matching halted Plan09 summary, and refresh both OpenGSD readiness views and every active route copy. Do not rerun generation07.
2. Before any later hosted collection, correct and test the predecessor validator against the exact generation05 one-GET ledger, and make the child collector's sanitized error survive in the driver result. Use offline fixtures for both checks.
3. Fix the outer-process wrapper to resolve relative paths before calling `relative_to`, and test its receipt generation locally.
4. Keep CISPEED-01/02 open. No new proposal, approval authority, retry, or performance claim follows from these repairs.

## Confidence

**High** that stale route state plus the missing summary could dispatch the same Plan09 again; both are directly visible in the current handoff and phase directory. **High** that the predecessor validator is inconsistent for the exact generation05 history; the source predicates conflict and generation07's actual verifier reported that error. **High** that the collector's precise exit cause is unknown because its stdout/stderr were discarded and the retained request ledger lacks response bodies/statuses.

## Next action

Complete local route reconciliation and the focused source fixes. Re-read `phase-plan-index.ready_plans` and `init.execute-phase` after recording the halt. The next command must not be another Wave2 execution while the collector cause and existing no-retry limits remain unresolved.
