# Current CI baseline

Cutoff: `2026-10-12T21:04:28Z`; collected `2026-10-12T21:06:25Z` from collector checkout `eb4615dc3c2b704b293b2a5d9491b3c8e77a3165` and collector workflow SHA-256 `1c00630d5307f929c7d16577dbc54292005075400a88540c542412b8980528c0`. Immutable source bundle SHA-256: `169e5425870bd4486b0c7c6a07a4fd2c938c363fb7c156ffac27f4220f7426f0`. Replay source identity: `9386403a62d687e9fdc8f9c651c4c28a3a8540377375ae790dd9e32a736f8d80` (PR population hash), `c3dafcf64bf325bf25cc71bd545677e509cb4525497ce52685fb1fea30c73389` (request ledger hash). Status: **complete**. This snapshot is bounded to 100 runs per event and a 30-day window; capped/expired or undetailed records remain unknown.

## Separate populations

- **Pull requests:** 100 selected of 267 API runs; outcomes `{"cancelled": 18, "failure": 13, "success": 69}`; capped=True
- **Main pushes:** 81 selected of 81 API runs; outcomes `{"cancelled": 4, "failure": 19, "success": 58}`; capped=False
- **Nightly schedule:** 30 selected of 30 API runs; outcomes `{"failure": 8, "success": 22}`; capped=False

PR workload classes: full `8` measured / `8` selected; docs-only `0` measured / `0` selected. Missing changed-file detail is unknown, not docs-only.

## Required result and cost

The endpoint is the last successful completion of all currently enforced contexts, not workflow close. Pure queue time is unknown; initial per-job queue wait is 25742s summed across 258 job attempts (not a workflow wall time); dependency gaps remain unknown (dependency_edges_not_exposed_by_saved_job_api); required-result wait is 594s. A full source-bound instrumented PR sample is `measured`. Across its retained attempts, runner cost is 4325s; timing producer jobs account for 1470s; test durations sum to ExUnit 188522µs and Playwright 881789ms. Run [38307191464 attempt 2](https://github.com/szTheory/sigra/actions/runs/38307191464) came from draft PR [#331](https://github.com/szTheory/sigra/pull/331). Application/workflow revision `0e15a5713da5aeeec5a81110970011d76486eae1`; producer checked-out source revision `dc94d895317a91e164aa29d47135710641008814`; workflow file SHA-256 `d5dcdb22303ed7426fc3d597fa47b5c9401fa80f7a5501fdc472ac01642049f6`; workload identity SHA-256 `682515c962a366c31e8c6acada380d58294976d8282ca2d7b081d26c530191db`. These are distinct revisions and digests.

Currently enforced required names, with ruleset IDs as provenance:
- `Example HTTP smoke (boot + curl critical routes)` (ruleset IDs: 14941512)
- `Example Playwright smoke (full lifecycle)` (ruleset IDs: 14941512)
- `Example unit smoke (ExUnit + ConnTest)` (ruleset IDs: 14941512)
- `Install smoke (fresh phx.new + sigra.install)` (ruleset IDs: 14941512)
- `Library tests` (ruleset IDs: 14941512)

### Longest observed wait

- 38081366821:1:114300685100 — 613s (run 38081366821, attempt 1)
- 38081366821:1:114300669988 — 605s (run 38081366821, attempt 1)
- 38089602506:1:114325004429 — 605s (run 38089602506, attempt 1)
- 38081366821:1:114298875545 — 601s (run 38081366821, attempt 1)
- 38089602506:1:114324988426 — 598s (run 38089602506, attempt 1)

Main pushes:
- 38143881058:1:114483110245 — 1552s (run 38143881058, attempt 1)
- 38146312411:1:114490322445 — 1336s (run 38146312411, attempt 1)
- 38139851334:1:114471607886 — 1155s (run 38139851334, attempt 1)
- 38061391571:1:114240219936 — 1040s (run 38061391571, attempt 1)
- 38141796613:1:114476996331 — 1031s (run 38141796613, attempt 1)

Nightly schedule:
- 38205503164:1:114667998243 — 1664s (run 38205503164, attempt 1)
- 38112385941:1:114390472819 — 1419s (run 38112385941, attempt 1)
- 38112385941:1:114390472860 — 584s (run 38112385941, attempt 1)
- 38205503164:1:114667998349 — 561s (run 38205503164, attempt 1)
- 38112385941:1:114391616260 — 461s (run 38112385941, attempt 1)

### Largest summed runner cost

- 38089602506:1:114323195510 — 444s (run 38089602506, attempt 1)
- 38302698541:1:114989273905 — 444s (run 38302698541, attempt 1)
- 38307191464:1:115004034871 — 443s (run 38307191464, attempt 1)
- 38307191464:2:115007134621 — 443s (run 38307191464, attempt 2)
- 38081366821:1:114298875545 — 409s (run 38081366821, attempt 1)

Main pushes:
- 38143881058:1:114483110245 — 1544s (run 38143881058, attempt 1)
- 38146312411:1:114490322445 — 1329s (run 38146312411, attempt 1)
- 38061391571:1:114240219936 — 1034s (run 38061391571, attempt 1)
- 38141796613:1:114476996331 — 1024s (run 38141796613, attempt 1)
- 38139851334:1:114471607886 — 967s (run 38139851334, attempt 1)

Nightly schedule:
- 38205503164:1:114667998243 — 1655s (run 38205503164, attempt 1)
- 38112385941:1:114390472819 — 1413s (run 38112385941, attempt 1)
- 38112385941:1:114390472860 — 578s (run 38112385941, attempt 1)
- 38205503164:1:114667998349 — 553s (run 38205503164, attempt 1)
- 38112385941:1:114390485093 — 437s (run 38112385941, attempt 1)

Wait includes time until the required-result endpoint; runner cost sums actual job execution across attempts. They are different measures. Dependency gaps are unknown (dependency_edges_not_exposed_by_saved_job_api). Step categories: setup `939`, cache restore/download `125`, compile `135`, database `23`, app boot `2849`, tests `942. Cache: `{"Example Playwright shard:admin_behavior": {"browser_binaries": "hit", "example_deps": "hit"}, "Example Playwright shard:admin_checkpoints": {"browser_binaries": "hit", "example_deps": "hit"}, "Example Playwright shard:demo_showcase": {"browser_binaries": "hit", "example_deps": "hit"}, "Example Playwright shard:design_gallery": {"browser_binaries": "hit", "example_deps": "hit"}, "Example Playwright shard:non_admin_smoke": {"browser_binaries": "hit", "example_deps": "hit"}, "Library tests shard": {"library_deps": "hit"}}`. Runner image: `{"arch": "X64", "image_os": "ubuntu24", "image_version": "20261004.327.1", "os": "Linux"}`.

## Tool versions and measurement overhead

Configured pins are not command-observed versions:
- **pull_request:** configured `{"elixir": "1.19.5-otp-28", "node": "20", "playwright": "1.59.1"}`; observed `{"elixir": "Elixir 1.19.5 (compiled with Erlang/OTP 28)", "node": "v20.20.2", "playwright": "Version 1.59.1"}`
- **main:** configured `{"elixir": null, "node": null, "playwright": null}`; observed `{"elixir": {"reason": "measurement_artifact_unavailable", "value": null}, "node": {"reason": "measurement_artifact_unavailable", "value": null}, "playwright": {"reason": "measurement_artifact_unavailable", "value": null}}`
- **nightly:** configured `{"elixir": null, "node": null, "playwright": null}`; observed `{"elixir": {"reason": "measurement_artifact_unavailable", "value": null}, "node": {"reason": "measurement_artifact_unavailable", "value": null}, "playwright": {"reason": "measurement_artifact_unavailable", "value": null}}`

ExUnit overhead: `{"method": "median of five paired whole-mix-process elapsed-time differences (instrumented minus uninstrumented)", "overhead_us": -60547, "reason": null, "samples": {"paired_delta_us": [-60547, -167789, 398956, -656003, 43158], "with_timing_us": [2245986, 2426922, 2969988, 1529507, 1676819], "without_timing_us": [2306533, 2594711, 2571032, 2185510, 1633661]}, "source": ".planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json", "status": "measured"}`. Playwright reporter overhead: `{"overhead_ms": null, "per_seam": {"admin_behavior": {"overhead_ms": null, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured", "unit": "ms"}, "admin_checkpoints": {"overhead_ms": null, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured", "unit": "ms"}, "demo_showcase": {"overhead_ms": null, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured", "unit": "ms"}, "design_gallery": {"overhead_ms": null, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured", "unit": "ms"}, "non_admin_smoke": {"overhead_ms": null, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured", "unit": "ms"}}, "reason": "paired_same_selection_runs_not_recorded", "status": "unmeasured"}`. If either value is unmeasured or null, the report keeps it unknown. Both future comparison conditions must use the same timing instrumentation; no overhead estimate is subtracted from the improvement target.

## Current failures

At most twelve failed families were inspected; no more than three recurring signatures are shown:
- no_current_flake_identified: no recurring signature was identified in the bounded sample

The selected full PR family completed required checks on attempt `2`. Its complete attempt history is:

- Attempt 1: 2147s summed runner time; Example unit smoke (ExUnit + ConnTest) `failure` (23s); 9 skipped jobs.
- Attempt 2: 2178s summed runner time; no failed, timed out or cancelled jobs; 9 skipped jobs.

## Exact source run records

- [pull_request run 37881652491 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/37881652491) — SHA `b96db5711239ad5c3779ef4c34664fc9581491fa`, workload `unknown`
- [pull_request run 37882312229 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/37882312229) — SHA `a05b38f91c89aa61e254a14040aaf081f1a19122`, workload `unknown`
- [pull_request run 37991965472 attempt 2 — failure](https://github.com/szTheory/sigra/actions/runs/37991965472) — SHA `10246c8dbcc2acd3c49432844e84a34ae0bd01c1`, workload `unknown`
- [pull_request run 37992672660 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/37992672660) — SHA `4e631d895caa1e02108e05ed9d68069990ca305f`, workload `unknown`
- [pull_request run 37993672153 attempt 1 — cancelled](https://github.com/szTheory/sigra/actions/runs/37993672153) — SHA `3dbf08d58359b3f468d838d413b17235b332134e`, workload `unknown`
- [pull_request run 37993871903 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/37993871903) — SHA `a6f918841cbca39c58df5b23cdbe66bda728b050`, workload `unknown`
- [pull_request run 37993906353 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/37993906353) — SHA `d29dde4194ea263af44c1ec1a700308374a2b121`, workload `unknown`
- [pull_request run 38003010120 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/38003010120) — SHA `238eb1d68dd797222a869e5a98676aca4ebef651`, workload `unknown`
- [pull_request run 38003611334 attempt 1 — cancelled](https://github.com/szTheory/sigra/actions/runs/38003611334) — SHA `000cf751dc12735ef4bd660ab154219f45d39369`, workload `unknown`
- [pull_request run 38003804068 attempt 1 — failure](https://github.com/szTheory/sigra/actions/runs/38003804068) — SHA `048f137e146c684b32ca7f40d4885271cf921a7c`, workload `unknown`
- [pull_request run 38010026366 attempt 1 — failure](https://github.com/szTheory/sigra/actions/runs/38010026366) — SHA `8d302b50a631cd6e27a84c0d33bee60baa26e8b5`, workload `unknown`
- [pull_request run 38010038505 attempt 1 — success](https://github.com/szTheory/sigra/actions/runs/38010038505) — SHA `3393cb1b7e5fadba2898532b78bc9d259b6fccf7`, workload `unknown`

## Frozen later comparison

Contract status `ready`; fixed `20 pairs / 40 families`, `48-hour window; dates unset; freeze exact UTC start/end after candidate identity and before the first comparison run. The comparison needs 20 equivalent successful pairs, at least 20% lower median required-result wait, non-increasing nearest-rank p95 and total runner cost. With 20 pairs p95 is the 19th sorted value and is a fragile tail estimate, not a population guarantee. No 40-family comparison is scheduled by this phase.

Known missing inputs: none recorded.

## Reproduce

Run from the repository root:

```sh
bash scripts/ci/ci-run-metrics.sh --replay --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json
bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json
SIGRA_EXUNIT_TIMING_JSON=tmp/ci-exunit-timing.json PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci
SIGRA_EXAMPLE_URL=http://localhost:4002 SIGRA_PLAYWRIGHT_JSON=artifacts/ci-timing/admin_checkpoints-local.json npm --prefix test/example/priv/playwright test -- tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark --retries=0
```

The browser command requires the example app running on port 4002 with isolated database `sigra_admin_checkpoints` and the Playwright browsers installed as in `.github/actions/example-playwright-boot/action.yml`. Complete contributor setup guidance is planned for Phase 255. The frozen contract is `252-COMPARISON-CONTRACT.json`; unavailable or expired hosted inputs remain unknown and keep baseline validation nonzero.
