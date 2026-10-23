The original failed-job log was found inside the preserved Phase252 archive. The previous current-state claim that the order log was absent was incorrect. `extract.py` checks the archive hash, the family log receipt, the run receipt and source before recovering all192 native test rows. Original acceptance records and the `not_reproduced` decision remain unchanged.

The selected failure was test161 overall and test33 in `admin-eval-dark`: `board-mg-9/populated`. The log records one worker and Node20.20.2. Its three captured registration request/response/failure fields are null. This does not prove an account collision or another cause. The original database snapshot and redacted page-state fields remain unavailable.

The isolated checkout is the original source4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97. The example application's lockfile matches the current cached Elixir dependencies; its original app compiled successfully in a separate build directory. Root library dependency versions must not be used in place of the example app's versions. JavaScript packages were installed using the original npm lockfile into the isolated checkout, with a separate temporary npm cache. Every installed version matches that lockfile. Collection with Node20.20.2 and Playwright1.59.1 confirms exactly the33-test dark-project prefix. `--list` did not execute tests.

`replay.mjs` prepares one separately approved development diagnostic: one browser invocation, at most33 tests,600 seconds including cleanup, zero retries, first failure stops. It creates a fresh owned PostgreSQL cluster/database and app on unused loopback ports58624/39453, captures command logs using the existing process-tree watchdog and redactor, and retains first-failure traces. An exclusive reservation prevents a second invocation. It cannot restore any expired acceptance slot, close CIREL-01 or turn a passing diagnostic into acceptance evidence. It has no GitHub/CI actions.

This is the exact same-project prefix. It omits128 earlier desktop/mobile tests, uses fresh database state and runs on macOS arm64 rather than the original Ubuntu Linux x64. A failure in setup or an earlier test is retained and stops the command; it is not the selected historical failure. A green run remains `not_reproduced`.

Preview (no browser, database or application launch):

```sh
node .planning/execution/253-registration-order-recovery/replay.mjs
```

Historical initial command (already used; its reservation remains closed):

```sh
node .planning/execution/253-registration-order-recovery/replay.mjs --run --approved-new-diagnostic
```

Offline verification:

```sh
python3 .planning/execution/253-registration-order-recovery/test_recovery.py
```

Preparation result:9 recovery tests pass; original application compile exit0; collection exit0; zero browser launches during preparation and zero GitHub requests. A default npm install initially stopped at the unwritable global cache; the isolated-cache install succeeded. Both were preparation, with no browser or database. The former dependency-cache mismatch was resolved before collection. Tool/package downloads occurred; this was not a network-free task.

Current native result: `native-result-review.json`.33/33 tests passed; zero retries/skips; one browser invocation. The original deadline was20:33:36.246UTC and cleanup finished20:29:32.326UTC,356080ms after the approved start. No GitHub/CI actions. The SQL_ASCII setup failure remains preserved at b543a41f8. Explicit `--encoding=UTF8` and app readiness passed in the separate development `--setup-check`; `--continue-approved-diagnostic` then used the still-unused browser invocation without resetting the original deadline. The approved native scope is now complete; the exclusive browser reservation prevents another use. Both old acceptance ledgers and all9 expired slots are unchanged. The earlier stopped command and its approval receipt remain historical records; no stopped result was changed to a pass.

No registration cause was demonstrated. The33-test result covers only the dark-project prefix.128 earlier desktop/mobile cases remain a distinct, untested order dependency; original DB state and redacted page-state fields remain unavailable.

Next GSD command: `$gsd-execute-phase 253 --gaps-only`, after separate approval of the prepared full161-test preceding sequence. No further native invocation is currently authorized. No new numbered plan. Phase253 verification remains incomplete. Phase254 readiness was checked directly: pending, no context, research or plans. Its forward route after actual253 completion is `$gsd-discuss-phase 254`; it has not been started.

The next diagnostic is fully prepared in `full-prefix-replay.mjs` and `full-prefix-proposal.json`. `full-prefix-list.json` matches all161 original native rows in exact project/test order; this is collection only. The proposed new limit is one invocation,1200 seconds including setup/cleanup, zero retries, first-failure stop and no GitHub/CI. It requires a separate `full-prefix-approval.json` bound to the proposal hash before any allocation. Fourteen recovery checks pass, including absent/mismatched approval refusals in isolated copies. Preview: `node .planning/execution/253-registration-order-recovery/full-prefix-replay.mjs`. After that separate approval the agent runs `node .planning/execution/253-registration-order-recovery/full-prefix-replay.mjs --run --approved-new-diagnostic` once. The completed33-test approval cannot authorize it.

Full-prefix result: `full-prefix-result-review.json` (commit3626e9abb):161/161 passed in original order with zero retries/skips;553256ms including setup and cleanup. That approval is complete and cannot be reused. Actual selected CI PostgreSQL was15.19; local is14.17. The original registration cause remains unknown. `requirement-review/result.json` independently verifies CIREL-02 from real normal/docs PR evidence and six hosted fixture outcomes; its requirement checkbox is now complete. Automated `253-UAT.md` has5 passes and1 blocked criterion. Phase253 is incomplete. No further native invocation is authorized; continue offline CI-environment diagnosis with `$gsd-execute-phase 253 --gaps-only`.
