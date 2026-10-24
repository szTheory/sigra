# Registration fix: prepared local Linux validation

The candidate is product commit `a876647338095b6d280608cb75bcf886ab1da953`: example CI servers disable hot code reloading. Local development retains it. The original server crashed before inserting the user because `Ecto.Queryable.to_query/1` was unavailable. The controlled loader/reloader test produces the same error; the original job did not trace that schedule.

## What is ready

The candidate source and its browser dependencies were rebuilt offline in Linux x64. `preparation.json` pins the resulting image; `source-manifest.json` records the exported Git source and every included file hash. All tracked paths except `.planning` were exported from the candidate commit. The harness receives the actual commit object for `git rev-parse HEAD`; this is source snapshot metadata, not a complete checkout/history. Runtime verification checks the source manifest rather than claiming `git status` is clean.

The original image supplies the cached compiler, browser binaries and Hex dependencies. The example's `mix.lock` and `mix.exs` are unchanged from that image's source; the example lockfile controls dependency resolution for its path dependency on Sigra. Candidate browser packages differ: all 51 package tarballs were checked against lockfile integrity hashes and installed with `npm ci --offline --ignore-scripts`. No package was downloaded. Sigra and Example were recompiled. The compiled endpoint has no hot-reloader calls/socket and retains LiveView. Configuration tests pass with seeds 101, 202 and 303 in separate Elixir processes.

Native `--list` collection selects exactly one test in each project: `render bundle: board-mg-9/populated`, exercising the current registration helper through the normal `beforeEach`. The collection reporter's skipped counts describe list-only records; no browser executed. Fifteen protocol tests use fake Docker/native-result fixtures. The real unapproved runtime command also refuses before allocating anything.

The first build stopped because Docker's builder attempted to write its activity file outside the workspace. `stopped-build-1/` retains that script/log. Using an owned temporary builder directory resolved it. Build contexts and inspection/unit containers were removed. No Example listener, database, browser or CI started during preparation.

## Proposed new scope — not approved or executed

`proposal.json` freezes nine sequential invocations: three each for `admin-eval`, `admin-eval-mobile`, and `admin-eval-dark`. Every invocation gets a new PostgreSQL 15.19 container, new seeded database, new Example server/container and browser context. The projects and title are unchanged; zero retries, one worker, first failure stops, failure traces retained. The overall limit is 1,200 seconds including cleanup, with no CI launch or GitHub request. Each app shares only its own database container's private network; there are no published ports, image pulls or external network access.

This is a new proposed allowance. None of the nine expired historical slots or the consumed original-source replay approval is reused. The user's current instruction is offline only; no runtime approval has been recorded. After an explicit decision approving this exact proposal, record its SHA256, source and user decision in `approval.json`, commit that approval, then run once:

```sh
python3 .planning/execution/253-registration-postfix/validate.py --run
```

The runner verifies every sealed input, requires a matching approval, exclusively creates and fsyncs `reservation.json` before allocation, and refuses a second invocation. It keeps all results and attempts cleanup of both owned containers after success, failure or interruption. Do not delete a reservation to retry. A deterministic failure is diagnosed locally without making a new numbered plan or renewing this scope.

Read-only preflight:

```sh
python3 .planning/execution/253-registration-postfix/validate.py --preflight
```

## What success would establish

Nine fresh targeted executions on this candidate, with exact native results and no server module error. This does not establish absence of flakiness or replay the historical 161-test sequence. It runs under x64 emulation on an ARM Mac, including the documented `ERL_AFLAGS=+JMsingle true` workaround. The hosted kernel/scheduling and original database snapshot are not recreated.

Normal integration selections and a separate review of all CIREL-01 criteria still remain after targeted passes. CIREL-02 is already complete and is not reopened. Phase 253 stays incomplete until those checks and phase verification are complete. No hosted CI approval is requested by this proposal.

Next GSD command, after the scoped approval: `$gsd-debug continue phase253-registration-timeout`. It should execute this prepared bundle, not prepare another one or run an empty gap scan. Phase 254 is pending without context/research/plans; after actual Phase 253 completion, recheck readiness and use `$gsd-discuss-phase 254`.
