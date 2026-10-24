# Connection repair verified; speed comparison remains unproven

The example browser client could let a retired WebSocket close its LongPoll replacement. LiveView then reloaded registration and aborted the new request. A controlled test reproduced that sequence. The backport binds events to their physical connection, clears retired heartbeat state, restarts channel joins and respects callbacks that connect or disconnect. Seven deterministic tests exercise the shipped Socket itself and run in Fast checks. No dependency, timeout or selector changed.

The exact production bytes passed forced fallback in WebKit and Chromium in about four seconds, plus five normal mobile navigations. The selected141 local tests and workflow lint passed. Draft [PR353](https://github.com/szTheory/sigra/pull/353), source8b3c3d8c, passed [full CI40054033393](https://github.com/szTheory/sigra/actions/runs/40054033393): all five required checks, terminal gate, new regression and108 executed browser cases. Source tree, workflow, producer origin and raw hashes were independently checked. This separate development run used65 API HTTP requests, one invocation andzero retries; its budget is closed. Local diagnostic resources are stopped.

The collector now distinguishes a failed job from invalid origin and retains failed/unpaired costs even when no successful family can be materialized. Null family inputs return insufficient_data instead of crashing. Twelve protocol tests, three focused attempt tests and the comparison suite passed.

The original measurement remains **insufficient_data**. Its first baseline attempt failed; the candidate passed. Both are retained with2046/1589 runner-seconds. Two invocations are spent,38 unused, and no successful pair exists. No replacement or window extension occurred. With only19 possible future successful pairs, the fixed20-pair experiment cannot pass. CISPEED-01/02 and whole-phase verification remain unaccepted; the repair's green CI is not a speed result.

The original CI trace did not show what delayed its primary response. The controlled reproduction proves the downstream connection race and repair, without claiming that missing initiating event. [Phoenix PR6867](https://github.com/phoenixframework/phoenix/pull/6867) independently describes this race class.

Next command: `$gsd-discuss-phase 255`. Its readiness reports Pending, no context/research/plans and no prerequisite blocker. Reproducibility and truthful reporting can proceed while the speed requirements stay open. Do not create another numbered repair plan or restart the closed cohort. A future benchmark needs its own explicit method and allowance.

Records: RESULT.json, VERIFICATION.json, BROWSER-REPORTS.json, FORWARD-ROUTE.json and FINAL-RECOVERY.json in this directory. Original outcome: ../254-environment-recovery/MEASUREMENT/RESULT.json. Commits: e2ab83edb (browser repair), d5b7300c8 (collector), with earlier history preserved.
