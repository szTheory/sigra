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

## Remaining work

Implementation and local checks are complete for this candidate. Fresh source-pinned post-fix browser/CI results are still missing, so CIREL-01 and Phase 253 remain incomplete. Required-gate implementation is unchanged; CIREL-02 remains complete.

Prepare and verify the exact validation bundle offline before requesting a separately scoped new runtime decision. No existing allowance authorizes those runs. Phase 254 has no context, research or plans and has not started; recheck readiness after actual Phase 253 completion.

```text
$gsd-debug continue phase253-registration-timeout
```
