---
status: verifying
trigger: "Phase 253 registration timeout: inspect the original CI failure and Linux replay logs; offline only, no browser or CI run"
created: 2026-10-22
updated: 2026-10-22
goal: find_and_fix_offline
---

## Symptoms

- Expected: the original admin registration test saves its account, submits the login POST and leaves `/users/register`.
- Actual: original CI run38205503164 attempt1, source4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97, test161 (`admin-eval-dark / board-mg-9/populated`) timed out. The original192-test job continued afterward. Both saved161-test Mac and Linux replays passed.
- Error: `page.waitForURL: Timeout 10000ms exceeded.` Registration request,response and request-failure fields were all null. The archive redactor removed the rest of pageState after finalUrl.
- Timeline: original failure2026-10-12; Linux replay2026-10-22 passed all161 cases in1622.2seconds with no retries/skips.
- Reproduction: the original test order is authenticated in253-registration-order-recovery/recovered-order.json. The replay command is consumed and must not be run again. No browser,Example app listener,database,CI or external-network execution is authorized. One network-isolated Linux unit container was used only for the Elixir probe.
- Source of symptoms: the user's current request and already retained original CI/replay records; no new user interview is needed.

## Current Focus

reasoning_checkpoint:
  hypothesis: CI's enabled development reloader can delete Ecto.Queryable between OTP's successful loaded check and export check,raising the same UndefinedFunctionError seen during the original save.
  confirming_evidence:
    - Original save161crashed on exactly Ecto.Queryable.to_query/1 before the user insert/POST;the original CI endpoint enables code_reloader.
    - The controlled test uses the unchanged OTP28.5 handler algorithm with only its module name changed and a debugger scheduling pause. The actual Phoenix1.8.5 reloader then deletes Queryable;the resumed handler raises the identical error and stack head.
    - The control follows the same loader steps without the intervening reload and succeeds. Trace confirms three real reloader deletions and two successful ensure_loaded returns.
  falsification_test: A query failure in the same controlled test without an intervening reload rejects this explanation;the original module error recurring in a CI server with reloading disabled would show another cause remains.
  fix_rationale: CI serves fixed checked-out source and needs no hot reloading. Disabling its reloader removes this protocol-deletion actor while preserving local development reloads and the remaining dev configuration.
  blind_spots: Original CI has no module-lifecycle trace,so this exact historical interleaving remains inferred. The deterministic test enters a renamed copy of OTP's handler directly to avoid debugger-dispatch interference. No new browser run or post-fix CI proof is authorized.
  candidate_causes:
    - configuration/code: enabled development reloader plus the demonstrated loader/reloader interleaving
    - environment: another actor or a missing/corrupt BEAM/code-path problem could also make the original module unavailable
  and_gate: yes — the loader must be in its loaded-check/export-check window while another request runs the protocol purger;reloader enablement alone does not fail.

bug_class: concurrency — loader/reloader race demonstrated under a controlled schedule; original historical interleaving remains untraced
hypothesis: CI's development reloader is an unnecessary module-deletion actor and can cause the original module error when it overlaps OTP's loader checks.
test: the controlled schedule reproduces the exact error with the development configuration and passes with the actual CI configuration after the patch. Three configuration tests pass;CI compilation and compiled endpoint inspection pass.
expecting: implementation,targeted repeats,integration and all22existing control rows have passing proof. Canonical phase verification remains;no new browser-control invocation is needed.
next_action: run $gsd-execute-phase 253 unfiltered for final verification gates. Completed R4/R5 controls reverify;73obsolete unused plans are superseded with exact originals preserved. The installed SDK reports zero incomplete active plans. No new browser or CI permission is granted.

## Evidence

- Original archive SHA256:95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30.
- Original failed-job.log SHA256:9eb5c33dd861f310f06d3ab5f559c14d05952d09d6203faf668ad478b76c3a0c;34986 lines,including192 `HANDLE EVENT "save"` entries.
- Linux result: `.planning/execution/253-registration-linux/RESULT.json`; native report161passes,0skips/retries; original test161passed. A green replay does not prove a fix.
- Initial Git capture was clean at855897c1c. Historical files and spent allowances remain unchanged.
- The sole GenServer termination follows save161 at original log lines29588–29608. It raises `UndefinedFunctionError` for `Ecto.Queryable.to_query/1`,before any user insert. The stack passes through email uniqueness validation and RegistrationLive.handle_event/3.
- Save160 and162 each have one user insert and one login POST;save161 has neither. The failed generated address encodes dark registration sequence33 and a creation time05:15:36.572UTC,between native test160 ending05:15:36.536 and test161 failing05:15:48.233. This links the crash independently of ordinal counting.
- Locked Phoenix1.8.5 CodeReloader.Server calls purge_modules(consolidation_path) when protocol consolidation is enabled,including after a no-op compile. purge_module runs :code.purge then :code.delete. The original development endpoint enables code_reloader; LiveView save-event handling does not use the HTTP reloader lock.
- Read-only `analyze.py` authenticated both original and Linux logs and checked all registration flows. Original:191successful inserts/POSTs and one crash at161. Linux:161successful inserts/POSTs,including161,and no Queryable exception. See `phase253-registration-timeout/evidence.json`.
- `purge_probe.exs`:2000control calls and40000concurrent query calls passed;all5processes exited normally. `loaded_purge_probe.exs`:2000control calls and400000concurrent schema query calls passed with5000reload/purge cycles;all5processes exited normally. These are local module experiments,not browser runs or CI acceptance. Both actual logs and source scripts are retained.
- Original application logs were flushed later by the failure-dump step. Their05:19:23prefix is the dump time,not a reliable time for the crash itself. The generated address embeds05:15:36.572UTC,inside the native test161 interval.
- Continuation result: `phase253-registration-timeout/CONTINUATION-RESULT.json`,retained at b6a607da3. The actual reloader's ordinary reload/rebuild paths passed on Mac and Linux with module deletions traced. That motivated a controlled schedule instead of further blind replay.
- The debugger pauses a renamed but otherwise unchanged OTP28.5 error handler at line88,after ensure_loaded succeeds. A real Phoenix reload deletes Queryable before the export check. The resumed handler emits the original exact exception and stack head;the no-intervening-reload control passes. Direct handler entry is a stated model limitation,not an original CI replay.
- Product fix a87664733 disables code reloading for CI=true/1. Development reloads and the rest of the development configuration are preserved. Three regression tests pass;the example app compiles with warnings treated as errors;its CI-compiled endpoint contains no reloader calls/live-reload socket and still contains the LiveView socket.
- Ten scoped unit attempt records retain both successful experiments and fixture/debugger setup failures;none substitutes for CI/browser acceptance. One isolated Linux unit container ran with network=none and was removed. No app listener,database,browser or CI ran. Old approvals and nine expired post-fix slots stay closed.

## Eliminated

- A missed submit click or browser required-field validation as the immediate cause:the original server received save161 with the generated account and then raised the recorded exception.
- A failed login response as the immediate cause:the crash occurred before the user insert and before any login POST.
- The board screenshot/rendering as the immediate cause:registration failed before the test could capture that board.
- A permanently absent Ecto dependency/API:the same server successfully registered160and162,and the locked Ecto3.13.5 exports to_query/1. The observed failure was transient.
- Reloader overlap is now demonstrated as a sufficient component-level cause under a controlled schedule. The original job did not trace module lifecycle,so other original loader causes remain possible.

## Resolution

root_cause: confirmed immediate failure — RegistrationLive.save crashed in email uniqueness validation because Ecto.Queryable.to_query/1 was unavailable;the account was not inserted and trigger_submit was never set.
upstream_cause: a real loader/reloader interleaving produces the exact error;its occurrence in the historical CI run remains inferred because that job lacks module lifecycle tracing.
fix: a87664733 — CI example servers disable hot code reloading;local development retains it. No retry,timeout,required-check or test-selection change.
verification: controlled component failure/control;configuration regression seeds101/202/303;compilation/endpoint inspection;nine fresh targeted passes;108passing integration tests across five fresh groups. Readiness/isolation/trace browser controls and canonical phase verification remain.
files_changed: test/example/config/dev.exs;test/sigra/planning/phase_253_ci_static_runtime_test.exs;scoped debug and handoff records.
phase_status: CIREL-01 and Phase253 remain incomplete;CIREL-02 unchanged.

## Prepared post-fix runtime check

Candidate image and source manifest are pinned in `.planning/execution/253-registration-postfix/preparation.json`. Fifteen runner tests pass;three configuration tests pass with each fixed seed101/202/303 in separate Linux processes. Native list-only collection selects the original failing board once per project. The real unapproved command refuses before reservation/allocation. No app,database,browser or CI started;new runtime scope remains unapproved. Checks:.planning/execution/253-registration-postfix/CHECKS.json;bundle commit:b63fb33e665d1a48c7dbcb124a21a09043cb4722. After approval,continue the same debug session to execute the prepared nine-run bundle. Normal integration/phase verification remain afterward.

## Approved post-fix runtime result

The user approved proposal f879adda9ecfe4e0b5860daf25bb6bb49d908165a5e34fc86db8a6b592fc5b06 with “yes i approve”. Approval61d24b90e and reservation2473ecfa7 preceded the one approved execution. All9fresh invocations passed:3desktop/3mobile/3dark;zero retries/skips;226.5seconds including cleanup. Each server log shows one save,one account insert and one login POST,with no original module error. All18containers were removed;zero CI/GitHub requests. Actual evidence:eb2e23a14cc079a6539d8c037810e543e97c4658;result:`.planning/execution/253-registration-postfix/RESULT.json`. Authentication values were redacted before committing logs;native browser reports and flow counts are unchanged. The allowance is consumed. CIREL-01 still needs normal integration/remaining-control review and whole-phase verification;CIREL-02 unchanged. Next:offline integration evidence review/preparation in this same session.

## Offline integration preparation

Offline integration preparation is complete:108 tests frozen across the five current PR browser groups on product a87664733. Thirteen runner tests and43 existing unit contracts pass;three configuration tests pass with each seed101/202/303. No browser,app,database,CI or GitHub request ran. New proposal requires an explicit decision:five fresh local Linux groups,once each,zero retries,first-failure stop,3600seconds total including cleanup and1800seconds per group. Prior nine-run approval is consumed. Readiness/isolation/trace browser controls and canonical phase verification remain after integration;CIREL-02 stays complete. Proposal SHA256:221abdc46ee99e5dfe7cf71b989aa810bd4c6f0774b2085a32185a958b9f7889. Review:`.planning/execution/253-registration-integration/README.md`;checks:`CHECKS.json` in that directory. Original Plan16 and control-recovery browser receipts remain halted;their slots are not reopened. Prior exact session bytes:6a0b66f014e4b51ff6d3ca6cf43de8459d0a1ca5;read-back:`.planning/execution/253-registration-integration/prior-state.json`.

## Approved integration result

Approved integration scope is complete:108/108 passed across five fresh local Linux groups on product a87664733;zero retries/skips;640.7seconds including cleanup;all10containers removed;no original Ecto.Queryable error,CI launch or GitHub request. Approval55324020c and reservation26ed7517c are consumed. The fix,targeted repeats and ordinary browser integration are complete. CIREL-01 still needs readiness/isolation/trace browser-control proof and canonical phase verification;CIREL-02 stays complete. Next:review stopped controls and prepare the smallest remaining browser-control check offline. No extra runtime action is authorized and no new decision is needed for that preparation. Actual evidence:b42a8ad89816a8f81c21d067fa8c66a0ddc26c34;independent result:`.planning/execution/253-registration-integration/RESULT.json`. Native reports are unchanged;server logs omit authentication values with before/after hashes. All27 native path attachments are present. Prior exact session:68b032d42152c22e22e8cb6edac482c9099ab904;read-back:`.planning/execution/253-registration-integration/CLOSEOUT-STATE.json`.

## Completed controls recovered; final verification unblocked

The previous handoff was wrong about missing controls. Plan83 completed the R4/R5 chain; the current read-only verifier and independent audit reopen all22native rows, nine intended failure traces and three0-to-1fresh account receipts. Current control/test/authentication source and locks are unchanged. No new runtime check is needed. See `.planning/execution/253-final-review/README.md` and `controls.json`.

The73never-executed recovery recipes are now explicitly superseded; original bytes remain at de9bccb356087b11cebade820c612b5cd5c1b5ca and are read back in `prior-state.json`. All failed attempts and limits remain unchanged. The actual installed SDK now reports110active summarized records,zero incomplete plans and a missing verification report. Next command:$gsd-execute-phase 253(unfiltered). The fix and scoped checks are complete;CIREL-01/Phase253 are still pending canonical review.
