# Phase 253 partial execution and review repairs

Five plans are complete: 01, 03, 04, 05 and 06. Plans 02 and 07 halted without meeting their acceptance criteria. Plan 08 has not run because it depends on both. CIREL-01 and CIREL-02 remain unsatisfied; phase verification and Phase 254 have not started.

The registration attempt ran zero browser invocations. Its single setup retry was consumed by the isolated Phoenix/Mix launch failures, ending with a JOSE include compilation error. No readiness, state-collision or trace control ran. The original freeze and diagnosis remain in `253-REGISTRATION-EVIDENCE.json` and `253-REPRO-FREEZE.json`.

The only hosted canary run, [38347679431](https://github.com/szTheory/sigra/actions/runs/38347679431), failed with `record identity mismatch: source_sha`. GitHub returned seven job records: five successful producers, a failed browser verdict, and a skipped verifier. The original fixture ref, run metadata, jobs response and failed logs remain preserved. No retry or further dispatch occurred. The ledger records 20 accounted requests/reservations and 268 elapsed seconds; its exact HTTP request count is not established. It must not be presented as a complete independent request audit.

| Finding | Local repair | Evidence | Acceptance remaining |
|---|---|---|---|
| Registration verifiers accepted fabricated JSON claims | Both unsupported acceptance modes exit 3; six forged inputs are rejected without mutation | Actual RED `4db305d75`, fix `59c907378`, registration CLI test | Real native browser/control receipt production and validation |
| Docs-only heavy-step skips trusted a failed classifier | Require classifier success in the helper and unit/install/HTTP conditions | RED `5fbf4babb`, fix `4bc7c4249`, five unit-owner tests | Real production docs-only PR proof |
| Fixture attempted to override reserved GitHub variables | Pass synthetic identity explicitly to the record-writer child process; preserve actual dispatch identity separately | RED `a7685bcfb`, fix `b0bed87cf`, five actual fixture-script cases | New bounded hosted proof |
| Native jobs included a skipped auxiliary verifier | Require the auxiliary skip and matching run identity; count executed jobs separately from skipped records | Hosted verifier tests, fixes `b0bed87cf` and `7da6766eb` | Real separate-verifier receipt, including the skipped matrix job |
| Watch failure exited before completion capture | Capture statuses with conditional commands; preserve shell `errexit` | Recovery test uses a failing watch under `set -e` | New hosted terminal-result capture |
| Separate verifier required its own future success | Validate source scenarios in `sources` mode, then validate the completed independent verifier in `matrix` mode | Pending-verifier and final-matrix positive/negative tests | Separate hosted verifier must actually pass |
| Halted evidence could be reused | Reject halted diagnostics before any `gh` command | Mock CLI test confirms no GitHub command or evidence mutation | A newly authorized bounded freeze, not a silent retry |

`253-POSTEXEC-CHECKS.json` retains the current local checks: 62 Node contracts, 48 metrics shell checks and their diagnosis controls, the shell verdict suite and five unit-owner checks, 12 hosted-receipt verifier tests, three recovery tests covering five fixture scenarios, six registration forgery cases, shell syntax and actionlint. The archived baseline returns `status: ready` with no diagnostics. Every Phase 252 path is unchanged. The UI gate reports no frontend changes and no block; schema drift reports no changes; codebase drift is skipped because the structural map is absent.

These tests check the local repairs. They do not turn the failed hosted run into a pass or replace missing real browser and production PR records. Before any new hosted freeze, prove the watcher request reservation and the dispatch input size are sufficient. The old request ledger used an uncounted `gh auth status` check and an unproven failed-log request estimate; the repaired runner uses local token lookup and a direct log-archive request, but the original counts remain uncertain.

Plan 07's untracked Task 2 RED report was overwritten before its bytes had a durable copy. The visible content was reconstructed, but exact recovery is unproven. The later run that deliberately removed existing protections remains a broken-source negative control, not TDD chronology. The original report, deviation and halted task status are not waived. The parent's later recovery regressions ran against the actual broken code before their repair commit; they do not retroactively repair Task 2's missing chronology.

The prior summaries, state and handoff are recoverable at the exact commits recorded in `253-POSTEXEC-PRESERVATION.json`, `253-SUMMARY-SCOPE-PRESERVATION.json` and `253-EXECUTION-RECORD.json`. Canonical task rows fix GSD's scope parsing without changing plan acceptance.

Next command: `$gsd-debug "Phase 253 registration runner setup failure"`. Repair the isolated startup first. Establish fresh bounded proof tasks before new browser/hosted runs; preserve the original failed evidence. Repeating execute-phase alone skips the halted summaries and leaves 253-08 blocked. The execution workflow requires resolving the halt before phase verification.
