# CI registration failure: candidate fix implemented

Commit `a87664733` disables hot code reloading for the example server when `CI=true` or `CI=1`. Local development retains hot reloading. The remaining development configuration, including development routes and the LiveView socket, stays available. No retry, timeout, test selection or required-gate logic changed.

## Original failure

The original CI server crashed during registration 161 with `Ecto.Queryable.to_query/1` unavailable. It failed in email uniqueness validation before inserting an account or enabling the login POST. That explains the browser navigation timeout. The original account's dark-project sequence and timestamp independently match the failing test. The authenticated original-log analysis remains in `evidence.json`.

## Demonstrated mechanism

The real Phoenix reloader purges consolidated protocols. OTP's error handler first ensures a module is loaded, then checks its exports. A reload between those steps can delete the module before the export check.

The controlled test pauses at that exact point in OTP 28.5's source. Only the source module name is changed for debugger isolation; its algorithm is unchanged. The actual Phoenix 1.8.5 reloader then deletes Ecto.Queryable. Resuming produces the exact original exception and stack head. The control without that intervening reload passes.

The final test reads the real development configuration: development mode reproduces the scheduled error; the patched CI setting passes. This proves a component failure mechanism and checks the candidate fix. The original job did not record module lifecycle, so its exact historical interleaving remains inferred. The test enters a renamed OTP handler directly; it is not an original-job or full-browser reproduction.

Ordinary traced reload/rebuild probes passed on both Mac and Linux. Their successful automatic reloads explain why uninstrumented bulk query runs did not reliably exercise the narrow schedule. Failed fixture/debugger setup attempts remain separately retained and are not counted as reproductions.

## Local checks

- Three configuration regression tests pass. The baseline produced two assertion failures before the patch.
- The example app compiled with warnings treated as errors, without starting the server or database.
- The compiled CI endpoint has no reloader calls or live-reload socket and retains its LiveView socket.
- The controlled failure/control is bound to the actual patched configuration hash.

Raw scripts, outcomes and hashes are in `CONTINUATION-RESULT.json`, committed at `b6a607da3`. One isolated Linux unit container used `--network=none` and was removed. No browser, CI workflow or GitHub request ran. All earlier approvals and expired post-fix slots remain closed.

## Fresh post-fix browser results

All nine approved fresh Linux invocations passed on product `a87664733`: three desktop, three mobile and three dark. Every run had its own PostgreSQL15.19 instance, seeded database, Example server and browser context. Zero retries/skips;226.5seconds including cleanup. Each server log records one registration save, one user insert and one login POST. The original module error did not recur. All18containers were removed. No CI or GitHub request ran.

Independent native/server review: `.planning/execution/253-registration-postfix/RESULT.json`. Actual evidence commit: `eb2e23a14cc079a6539d8c037810e543e97c4658`. Authentication values were redacted before logs were committed; native browser reports and registration-flow counts remain unchanged. Approval61d24b90e and reservation2473ecfa7 are consumed; no additional runtime scope exists.

## Integration results

All108tests passed across the five existing PR browser groups on product a87664733:43admin behavior,3checkpoints,42design gallery including setup,16non-admin smoke,4demo showcase. Zero retries/skips;640.7seconds including setup/cleanup;all10distinct containers removed. Every group used a fresh PostgreSQL15.19 instance and seeded app. The original module error did not recur. No CI launch or GitHub request.

Independent result:`.planning/execution/253-registration-integration/RESULT.json`;actual evidence:b42a8ad89816a8f81c21d067fa8c66a0ddc26c34. Approval55324020c and reservation26ed7517c are consumed. Native reports are unchanged after server-log redaction;all27 referenced path attachments are retained.

## Completed browser controls

The later R4/R5 chain completed all22native control rows. The previous handoff incorrectly relied on the earlier Plan16/recovery halts. Fresh independent checks verify13positive rows,9intended failed rows with traces,and3fresh database receipts showing account counts0before/1after registration. Passing second-window controls retained no traces. The tested registration spec,helpers,authentication/schema and locks are unchanged. No new browser run is needed.

Evidence:`.planning/execution/253-final-review/controls.json`;the existing `--verify-load-recovery ...R5.json --stage complete` command passes. All earlier failures and spent allowances remain unchanged.

## Remaining work

Only normal whole-phase verification remains. All73unused duplicate recovery recipes were explicitly superseded with their exact originals preserved;no completion SUMMARY was invented. The installed SDK reports110active summarized records and zero incomplete plans. CIREL-01 is not yet marked complete;CIREL-02 remains complete. No new browser,CI or GitHub scope exists.

Use the unfiltered command below;`--gaps-only` exits before final verification. Phase254 remains pending without context/research/plans.

```text
$gsd-execute-phase 253
```
