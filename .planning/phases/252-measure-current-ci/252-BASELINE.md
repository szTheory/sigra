# Current CI baseline

Cutoff: `2026-10-12T22:41:22Z`; collected `2026-10-12T22:43:39Z` from collector checkout `4ed2edf5f1c231a3889fbf02b7179f9093df4883` and collector workflow SHA-256 `fb691f11c2df00f77e270b064a031ae5d6d671aacdcb5de7e52a38d349971c3e`. Immutable source bundle SHA-256: `95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30`. Replay source identity: `4768f010d454b10973c0e1b40c2d57f8d30ccdaad287ec33459e841cbed3df74` (PR population hash), `a653759f4f238c7ee3cf9ede26cc6d846fa673216b4b32201c849fbf45800479` (request ledger hash). Status: **complete**. This snapshot is bounded to 100 runs per event and a 30-day window; capped/expired or undetailed records remain unknown.

## Separate populations

- **Pull requests:** 100 selected of 270 API runs; outcomes `{"cancelled": 18, "failure": 14, "success": 68}`; capped=True
- **Main pushes:** 81 selected of 81 API runs; outcomes `{"cancelled": 4, "failure": 19, "success": 58}`; capped=False
- **Nightly schedule:** 30 selected of 30 API runs; outcomes `{"failure": 8, "success": 22}`; capped=False

PR workload classes: full `8` measured / `8` selected; docs-only `0` measured / `0` selected. Missing changed-file detail is unknown, not docs-only.

## Required result and cost

The endpoint is the last successful completion of all currently enforced contexts, not workflow close. Pure queue time is unknown; initial per-job queue wait is 22642s summed across 216 job attempts (not a workflow wall time); dependency gaps remain unknown (dependency&#95;edges&#95;not&#95;exposed&#95;by&#95;saved&#95;job&#95;api); required-result wait is 385s. A full source-bound instrumented PR sample is `measured`. Across its retained attempts, runner cost is 2042s; timing producer jobs account for 1358s; ExUnit invocation reports are main: 2683 tests, 1.88119e+07µs; threadline&#95;guard: 65 tests, 129529µs (total 1.89415e+07µs) and Playwright tests total 798348ms. Run [38317383419 attempt 1](https://github.com/szTheory/sigra/actions/runs/38317383419) came from draft PR [#331](https://github.com/szTheory/sigra/pull/331). Application/workflow revision `d4dcc1939bd1f1590f6ca01d55b861e31acc745f`; producer checked-out source revision `cc8cd273bfe8bbbfbab6b33564efdede4d9f0d17`; workflow file SHA-256 `42f2205d651969ca4dd1e7fb14a8d30525c03bb73decbd282069d76a7319dc16`; workload identity SHA-256 `2f4ece52eb21e9a065a61a943036c88632a2b93b33117db6d992b18b93ca06aa`. These are distinct revisions and digests.

Currently enforced required names, with ruleset IDs as provenance:
- `Example HTTP smoke &#40;boot + curl critical routes&#41;` (ruleset IDs: 14941512)
- `Example Playwright smoke &#40;full lifecycle&#41;` (ruleset IDs: 14941512)
- `Example unit smoke &#40;ExUnit + ConnTest&#41;` (ruleset IDs: 14941512)
- `Install smoke &#40;fresh phx.new + sigra.install&#41;` (ruleset IDs: 14941512)
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
- 38141796613:1:114476996331 — 1031s (run 38141796613, attempt 1)
- 38139851334:1:114473663389 — 759s (run 38139851334, attempt 1)

Nightly schedule:
- 38205503164:1:114667998243 — 1664s (run 38205503164, attempt 1)
- 38112385941:1:114390472819 — 1419s (run 38112385941, attempt 1)
- 38112385941:1:114390472860 — 584s (run 38112385941, attempt 1)
- 38205503164:1:114667998349 — 561s (run 38205503164, attempt 1)
- 38112385941:1:114391616260 — 461s (run 38112385941, attempt 1)

### Largest summed runner cost

- 38316396580:1:115033994356 — 447s (run 38316396580, attempt 1)
- 38089602506:1:114323195510 — 444s (run 38089602506, attempt 1)
- 38314896976:1:115029121896 — 436s (run 38314896976, attempt 1)
- 38081366821:1:114298875545 — 409s (run 38081366821, attempt 1)
- 38317383419:1:115037204977 — 367s (run 38317383419, attempt 1)

Main pushes:
- 38143881058:1:114483110245 — 1544s (run 38143881058, attempt 1)
- 38146312411:1:114490322445 — 1329s (run 38146312411, attempt 1)
- 38141796613:1:114476996331 — 1024s (run 38141796613, attempt 1)
- 38139851334:1:114471607886 — 967s (run 38139851334, attempt 1)
- 38143881058:1:114483110193 — 590s (run 38143881058, attempt 1)

Nightly schedule:
- 38205503164:1:114667998243 — 1655s (run 38205503164, attempt 1)
- 38112385941:1:114390472819 — 1413s (run 38112385941, attempt 1)
- 38112385941:1:114390472860 — 578s (run 38112385941, attempt 1)
- 38205503164:1:114667998349 — 553s (run 38205503164, attempt 1)
- 38112385941:1:114390485093 — 437s (run 38112385941, attempt 1)

Wait includes time until the required-result endpoint; runner cost sums actual job execution across attempts. They are different measures. Dependency gaps are unknown (dependency&#95;edges&#95;not&#95;exposed&#95;by&#95;saved&#95;job&#95;api). Step categories: setup `754`, cache restore/download `97`, compile `110`, database `20`, app boot `2151`, tests `794. Cache: `{"Example Playwright shard:admin&#95;behavior": {"browser&#95;binaries": "hit", "example&#95;deps": "hit"}, "Example Playwright shard:admin&#95;checkpoints": {"browser&#95;binaries": "hit", "example&#95;deps": "hit"}, "Example Playwright shard:demo&#95;showcase": {"browser&#95;binaries": "hit", "example&#95;deps": "hit"}, "Example Playwright shard:design&#95;gallery": {"browser&#95;binaries": "hit", "example&#95;deps": "hit"}, "Example Playwright shard:non&#95;admin&#95;smoke": {"browser&#95;binaries": "hit", "example&#95;deps": "hit"}, "Library tests shard": {"library&#95;deps": "hit"}}`. Runner image: `{"arch": "X64", "image&#95;os": "ubuntu24", "image&#95;version": "20261004.327.1", "os": "Linux"}`.

## Tool versions and measurement overhead

Configured pins are not command-observed versions:
- **pull&#95;request:** configured `{"elixir": "1.19.5-otp-28", "node": "20", "playwright": "1.59.1"}`; observed `{"elixir": "Elixir 1.19.5 &#40;compiled with Erlang/OTP 28&#41;", "node": "v20.20.2", "playwright": "Version 1.59.1"}`
- **main:** configured `{"elixir": null, "node": null, "playwright": null}`; observed `{"elixir": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}, "node": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}, "playwright": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}}`
- **nightly:** configured `{"elixir": null, "node": null, "playwright": null}`; observed `{"elixir": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}, "node": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}, "playwright": {"reason": "measurement&#95;artifact&#95;unavailable", "value": null}}`

ExUnit overhead: `{"method": "median of five paired whole-mix-process elapsed-time differences &#40;instrumented minus uninstrumented&#41;", "overhead&#95;us": -60547, "reason": null, "samples": {"paired&#95;delta&#95;us": &#91;-60547, -167789, 398956, -656003, 43158&#93;, "with&#95;timing&#95;us": &#91;2245986, 2426922, 2969988, 1529507, 1676819&#93;, "without&#95;timing&#95;us": &#91;2306533, 2594711, 2571032, 2185510, 1633661&#93;}, "source": ".planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json", "status": "measured"}`. Playwright reporter overhead: `{"overhead&#95;ms": null, "per&#95;seam": {"admin&#95;behavior": {"overhead&#95;ms": null, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured", "unit": "ms"}, "admin&#95;checkpoints": {"overhead&#95;ms": null, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured", "unit": "ms"}, "demo&#95;showcase": {"overhead&#95;ms": null, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured", "unit": "ms"}, "design&#95;gallery": {"overhead&#95;ms": null, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured", "unit": "ms"}, "non&#95;admin&#95;smoke": {"overhead&#95;ms": null, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured", "unit": "ms"}}, "reason": "paired&#95;same&#95;selection&#95;runs&#95;not&#95;recorded", "status": "unmeasured"}`. If either value is unmeasured or null, the report keeps it unknown. Both future comparison conditions must use the same timing instrumentation; no overhead estimate is subtracted from the improvement target.

## Current failures

At most twelve failed families were inspected; no more than three recurring signatures are shown:
- &lt;n&gt;-&lt;n&gt;-&lt;n&gt;T&lt;n&gt;:&lt;n&gt;:&lt;n&gt;.&lt;n&gt;Z Test D: --add round-trip passes &#40;add ID&#95;B first, then ID&#95;A, assert sorted + lint passes&#41; — 2 observations: run 38314896976 attempt 1, run 38316396580 attempt 1

The selected full PR family completed required checks on attempt `1`. Its complete attempt history is:

- Attempt 1: 2042s summed runner time; no failed, timed out or cancelled jobs; 9 skipped jobs.

## Exact source run records

- [pull&#95;request run 37992672660 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/37992672660>) — SHA `4e631d895caa1e02108e05ed9d68069990ca305f`, workload `unknown`
- [pull&#95;request run 37993672153 attempt 1 — cancelled](<https://github.com/szTheory/sigra/actions/runs/37993672153>) — SHA `3dbf08d58359b3f468d838d413b17235b332134e`, workload `unknown`
- [pull&#95;request run 37993871903 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/37993871903>) — SHA `a6f918841cbca39c58df5b23cdbe66bda728b050`, workload `unknown`
- [pull&#95;request run 37993906353 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/37993906353>) — SHA `d29dde4194ea263af44c1ec1a700308374a2b121`, workload `unknown`
- [pull&#95;request run 38003010120 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/38003010120>) — SHA `238eb1d68dd797222a869e5a98676aca4ebef651`, workload `unknown`
- [pull&#95;request run 38003611334 attempt 1 — cancelled](<https://github.com/szTheory/sigra/actions/runs/38003611334>) — SHA `000cf751dc12735ef4bd660ab154219f45d39369`, workload `unknown`
- [pull&#95;request run 38003804068 attempt 1 — failure](<https://github.com/szTheory/sigra/actions/runs/38003804068>) — SHA `048f137e146c684b32ca7f40d4885271cf921a7c`, workload `unknown`
- [pull&#95;request run 38010026366 attempt 1 — failure](<https://github.com/szTheory/sigra/actions/runs/38010026366>) — SHA `8d302b50a631cd6e27a84c0d33bee60baa26e8b5`, workload `unknown`
- [pull&#95;request run 38010038505 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/38010038505>) — SHA `3393cb1b7e5fadba2898532b78bc9d259b6fccf7`, workload `unknown`
- [pull&#95;request run 38010043544 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/38010043544>) — SHA `109fd7cfbf9dcf0559674291d63c9ccd7083f9de`, workload `unknown`
- [pull&#95;request run 38010089224 attempt 1 — success](<https://github.com/szTheory/sigra/actions/runs/38010089224>) — SHA `143f73f03f4b5bd3412d50d00a8f2ffa3ccdd728`, workload `unknown`
- [pull&#95;request run 38052566830 attempt 1 — failure](<https://github.com/szTheory/sigra/actions/runs/38052566830>) — SHA `3ad51aac1f185194fe25159ffad5d8968e50e7b1`, workload `unknown`

## Frozen later comparison

Contract status `ready`; fixed `20 pairs / 40 families`, `48-hour window; dates unset; freeze exact UTC start/end after candidate identity and before the first comparison run. The comparison needs 20 equivalent successful pairs, at least 20% lower median required-result wait, non-increasing nearest-rank p95 and total runner cost. With 20 pairs p95 is the 19th sorted value and is a fragile tail estimate, not a population guarantee. No 40-family comparison is scheduled by this phase.

Known missing inputs: none recorded.

## Reproduce

Run from the repository root:

```sh
bash scripts/ci/ci-run-metrics.sh --replay --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json
bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json
SIGRA_EXUNIT_TIMING_JSON=tmp/ci-exunit-timing-main.json SIGRA_EXUNIT_TIMING_INVOCATION=main PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci
SIGRA_EXAMPLE_URL=http://localhost:4002 SIGRA_PLAYWRIGHT_JSON=artifacts/ci-timing/admin_checkpoints-local.json npm --prefix test/example/priv/playwright test -- tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark --retries=0
```

The browser command requires the example app running on port 4002 with isolated database `sigra_admin_checkpoints` and the Playwright browsers installed as in `.github/actions/example-playwright-boot/action.yml`. Complete contributor setup guidance is planned for Phase 255. The frozen contract is `252-COMPARISON-CONTRACT.json`; unavailable or expired hosted inputs remain unknown and keep baseline validation nonzero.
