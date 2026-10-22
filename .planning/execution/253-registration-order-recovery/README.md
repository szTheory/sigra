The original failed-job log was found inside the preserved Phase252 archive. The previous current-state claim that the order log was absent was incorrect. `extract.py` checks the archive hash, the family log receipt, the run receipt and source before recovering all192 native test rows. Original acceptance records and the `not_reproduced` decision remain unchanged.

The selected failure was test161 overall and test33 in `admin-eval-dark`: `board-mg-9/populated`. The log records one worker and Node20.20.2. Its three captured registration request/response/failure fields are null. This does not prove an account collision or another cause. The original database snapshot and redacted page-state fields remain unavailable.

The isolated checkout is the original source4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97. The example application's lockfile matches the current cached Elixir dependencies; its original app compiled successfully in a separate build directory. Root library dependency versions must not be used in place of the example app's versions. JavaScript packages were installed using the original npm lockfile into the isolated checkout, with a separate temporary npm cache. Every installed version matches that lockfile. Collection with Node20.20.2 and Playwright1.59.1 confirms exactly the33-test dark-project prefix. `--list` did not execute tests.

`replay.mjs` prepares one separately approved development diagnostic: one browser invocation, at most33 tests,600 seconds including cleanup, zero retries, first failure stops. It creates a fresh owned PostgreSQL cluster/database and app on unused loopback ports58624/39453, captures command logs using the existing process-tree watchdog and redactor, and retains first-failure traces. An exclusive reservation prevents a second invocation. It cannot restore any expired acceptance slot, close CIREL-01 or turn a passing diagnostic into acceptance evidence. It has no GitHub/CI actions.

This is the exact same-project prefix. It omits128 earlier desktop/mobile tests, uses fresh database state and runs on macOS arm64 rather than the original Ubuntu Linux x64. A failure in setup or an earlier test is retained and stops the command; it is not the selected historical failure. A green run remains `not_reproduced`.

Preview (no browser, database or application launch):

```sh
node .planning/execution/253-registration-order-recovery/replay.mjs
```

After explicit approval of the new diagnostic limit, the agent runs once:

```sh
node .planning/execution/253-registration-order-recovery/replay.mjs --run --approved-new-diagnostic
```

Offline verification:

```sh
python3 .planning/execution/253-registration-order-recovery/test_recovery.py
```

Current result:9 recovery tests pass; original application compile exit0; collection exit0; zero browser launches and zero GitHub requests. A default npm install initially stopped at the unwritable global cache; the isolated-cache install succeeded. Both were preparation, with no browser or database. The former dependency-cache mismatch was resolved before collection. Tool/package downloads occurred; this was not a network-free task.

Next GSD command: `$gsd-execute-phase 253 --gaps-only`, to continue this recovery after the scoped diagnostic decision. No new numbered plan. Phase253 verification remains incomplete. Phase254 readiness was checked directly: pending, no context, research or plans. Its forward route after actual253 completion is `$gsd-discuss-phase 254`; it has not been started.
