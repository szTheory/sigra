**Run completed:** all161cases passed once in27minutes2seconds. The original CI failure was not reproduced. Approval is consumed;do not run again. See [RESULT.md](RESULT.md) and [RESULT.json](RESULT.json). The preparation/approval instructions below are retained history.

# Registration diagnostic ready to run

The failed CI test was `admin-eval-dark` / `board-mg-9/populated`, test161 overall. It timed out waiting for navigation after registration, with no registration request, response or request failure captured. The Mac replay passed all161 cases, so it did not demonstrate a cause or a fix.

This local Docker diagnostic uses the preserved source `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97`, Ubuntu24.04/x64, Node20.20.2, OTP28.5, Elixir1.19.5, Playwright1.59.1, and the exact PostgreSQL image digest recovered from the original log. It retains `localhost:4011`, the original database name, the `/admin/_design` warmup without following its302 redirect, one worker, zero retries and the complete161-test order. A fresh private PostgreSQL container shares loopback with the app; no host ports are published and execution has no external network.

Preparation is verified: the original app compiled, collection matched all161 original rows, PostgreSQL15.19 and app readiness passed in11.4seconds, and both setup containers were removed. No browser tests ran. `CHECKS.json` records the current checks; `proposal.json` binds the runner and images to the proposed execution.

## The remaining decision

Approve **one new local development diagnostic**, at most40minutes including setup/cleanup, stopping at the first failure. This is a separate allowance. Every old acceptance/reproduction limit and stopped result remains unchanged. There is no CI launch, GitHub API request, automatic retry, or Phase253 completion claim.

After that explicit approval, the agent records its exact text and the SHA256 of `proposal.json` in `approval.json`, commits that decision, then executes:

```sh
python3 .planning/execution/253-registration-linux/diagnostic.py --run
```

The command refuses a missing/mismatched approval, changed approved files, or an existing reservation. It never reuses the Mac diagnostic's approval. A failure or timeout keeps its reservation and logs, and removes only its owned containers. Logs and traces are local; any later sharing must use sanitized copies.

Read-only environment and selection check:

```sh
python3 .planning/execution/253-registration-linux/diagnostic.py --preflight
```

## What a result establishes

- The same navigation timeout and missing registration transport fields in the selected test can establish reproduction. It still needs a demonstrated cause, a tested fix and separately scoped repeat checks.
- A different failure is diagnosed as that different failure. The same test failing on a screenshot assertion does not reproduce the registration error.
- All161 passing cases mean `not_reproduced`; they cannot close CIREL-01 or prove the CI flake is absent.

This Mac runs x64 through emulation. [Erlang documents an emulation startup limitation](https://github.com/erlang/otp/issues/10355); the image needs its `+JMsingle true` VM flag. Native CI did not use that flag. The host kernel, scheduling and complete hosted runner image are not recreated, and the original database snapshot/redacted page state remain unavailable. This is a closer diagnostic environment, not an exact recreation of the old VM.

`prepare.py` rebuilds from the original local Git objects and the recorded upstream asset URLs; image IDs and asset hashes are retained. Its preparation failures are development failures only. They never consumed a browser invocation or became replacement results for old stopped plans. No new numbered plan was created.

Phase253 remains incomplete; CIREL-02 stays complete. Phase254 readiness was checked: it has no context, research or plans. It has not been started. After actual253 completion, recheck readiness before `$gsd-discuss-phase 254`.
