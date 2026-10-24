# Phase 254 comparison: insufficient data

The closed comparison contains one failed baseline invocation and one successful candidate invocation. It has **zero successful matched pairs**, so its median and p95 are `null`; the observed costs of 2,046 and 1,589 runner-seconds do not demonstrate a speed improvement. **CISPEED-01 and CISPEED-02 remain open.** The independent remote replay produced the same `insufficient_data` result.

## Measured observations

| Side | Application/workflow source | Run | Outcome | Runner cost | Required-check wait |
| --- | --- | --- | --- | ---: | ---: |
| Baseline | [`fb2d3faa`](https://github.com/szTheory/sigra/commit/fb2d3faa4b25918d14415dd00a51545f0a9c6683) | [40046955449, attempt 2](https://github.com/szTheory/sigra/actions/runs/40046955449/attempts/2) | Failure | 2,046 s | `null` |
| Candidate | [`ebb1d3ef`](https://github.com/szTheory/sigra/commit/ebb1d3ef0207d64f5f22f409032cf6125abab941) | [40047078287, attempt 2](https://github.com/szTheory/sigra/actions/runs/40047078287/attempts/2) | Success | 1,589 s | 261 s |

The baseline failed the `Example Playwright smoke (full lifecycle)` required context while `admin-checkpoints-mobile` was waiting for LiveView readiness. Its captured successful-family metadata is missing, so the evaluator cannot establish a matched before/after pair. The failed baseline's generic identity and missing-family diagnostics do not prove that its source changed. Its captured producer source hash has no corresponding Git commit; the commit, tree and workflow payloads are retained and hash-verified in the receipt.

The fixed method requires **20 successful matched full-PR pairs**. It uses the ordinary median and nearest-rank p95 (`ceil(0.95*n)`, the 19th sorted value for 20 pairs). A 20-pair p95 is a fragile tail estimate and does not guarantee population performance. There are 38 unused invocation reservations, but the frozen contract allows at most 19 more successful pairs; they are not observations, and the fixed experiment was not extended or replaced.

Both retained runs report Linux X64 on `ubuntu24` image `20261012.334.1`. Their captured Playwright jobs report hits for `example_deps` and `browser_binaries`; the library jobs report `library_deps` hits. These are the observed conditions for the two individual invocations. They do not create a successful pair or fill the contract's 20-family warm-cache allocation. The baseline has no required-check wait time; it remains `null`, never zero.

## Keep the sources separate

| Evidence | Identity | What it establishes |
| --- | --- | --- |
| Measured baseline and candidate applications | `fb2d3faa…` and `ebb1d3ef…` | The two original invocations above |
| Repaired analysis | `d5b7300c809ce7cd474e87aa55fda278b3a09cbc` | Recalculation of the unchanged saved observations |
| Closeout expected result | `9e944b90b0f7914246017ac4c834470988eb2673` | Saved evaluator JSON used for exact replay comparison |
| Phase 255 hosted diagnostic workflow | `7aae47281bb3e91bb38fe2387427f27bd0b44327` | Source of the bounded success/failure/cancellation diagnostic canary |
| Local native browser diagnostic test | `59ed88c32673635757981770e50c228e92158b15` | Source tested for local trace and failure capture |
| Local evidence writer | `7bad04a200ffcecc759cd1d947c141609d96a037` | Separate evidence normalization tool |
| Trace-overhead source | `d6ce89a067c75308fb254a637691feadf2061349` | Separate three-pair local overhead observation |

The source IDs above are not interchangeable. The candidate's one successful origin check does not qualify both measured sides or establish native coverage parity.

## Implemented changes and separate reliability evidence

Phase 254 removed duplicate Hex/Rebar setup while retaining the cold dependency fetch, combined example-app Mix preparation, removed duplicate owner login navigation from invitation cases, and added isolated per-test admin-theme auth contexts. Local source-bound setup timings were 24.537 s cold / 4.619 s warm for separate commands and 22.922 s cold / 2.360 s warm for combined preparation. These are development measurements, not hosted CI speed results. The five CI browser owners remained in place.

A controlled development test reproduced a later connection race: a retired WebSocket could close its LongPoll replacement, causing LiveView to reload registration. The repair binds events to the physical connection. Draft [PR 353](https://github.com/szTheory/sigra/pull/353), source `8b3c3d8c75152438bb3259c1226b1044da717b3c`, passed full development CI run [40054033393](https://github.com/szTheory/sigra/actions/runs/40054033393) with all five required contexts and 108 browser cases. It added **zero** acceptance samples. The controlled test explains the downstream race and repair; the original hosted failure's initiating event remains unknown.

The separate Phase 255 trace sample used three pairs, one worker, and zero retries. Tracing-off averaged 519.208 ms; tracing-on averaged 478.235 ms. The observed −40.973 ms difference is noisy and inconclusive. It is not a speed claim and was not subtracted from the original observations.

The bounded diagnostic canary recorded success run `40122912945`, failure run `40123954650`, and cancellation run `40124112173`. It used 37 controller requests, three invocations, one push, zero infrastructure retries, and zero test retries. The cancellation artifact is partial: `final-output.log` and `final-trace.zip` never arrived. These are diagnostic runs, not measurements. Their uploaded artifacts expire **2026-10-31**.

## Independent replay package

The exact 59,461,735-byte archive contains 191 verified input members. It is published at immutable evidence commit `52d2f3611fa195042d52ab0ef9dba64e4d75a2eb` on [`refs/heads/evidence/phase255-replay-6d098e9bee2d28b0d88d`](https://github.com/szTheory/sigra/tree/evidence/phase255-replay-6d098e9bee2d28b0d88d). Its full SHA-256 is `6d098e9bee2d28b0d88dda2c517503467448939b4e48af84bf6e2ffd5255fe23`. The commit's parent contains the publisher helper source `e41aabd0c399b95d22262da2ebd45ae69250f290`; the corrected verification controller is separately identified as `83b62cd55` in [DISTRIBUTION.json](DISTRIBUTION.json).

An unrelated fresh repository fetched the exact remote commit and replayed from the committed package with network executables blocked. All 191 member hashes and unchanged input digests passed; the calculation returned `insufficient_data`, zero pairs, null median/p95, and costs 2,046/1,589. No network command was attempted. The bounded distribution allowance was used once for a create-only push, zero times for a transport retry, twice for retrieval, and zero times for workflow dispatch. The first retrieval fetched exact bytes but its controller looked for the wrapper inside the analysis package; that failed replay was preserved and the one remaining retrieval succeeded. No second push or Plan 06 allowance was used.

To retrieve and replay the archived input from a new temporary checkout:

```sh
REPLAY_DIR="$(mktemp -d)"
git -C "$REPLAY_DIR" init --initial-branch=main
git -C "$REPLAY_DIR" fetch --no-tags https://github.com/szTheory/sigra.git refs/heads/evidence/phase255-replay-6d098e9bee2d28b0d88d
git -C "$REPLAY_DIR" checkout --detach FETCH_HEAD
shasum -a 256 "$REPLAY_DIR/.planning/execution/255-replay/distributed/input-package.tar.gz"
python3 -B "$REPLAY_DIR/scripts/ci/ci-comparison-replay.py" replay --package "$REPLAY_DIR/.planning/execution/255-replay/distributed/input-package.tar.gz" --output "$REPLAY_DIR/replayed-result.json"
```

The hash command must print the SHA-256 above. The replay uses the packaged, pinned calculator and data and blocks network command execution. The checked distribution record is [DISTRIBUTION.json](DISTRIBUTION.json); its automated verification command is `python3 -B scripts/ci/ci-comparison-replay.py verify-distribution --record .planning/execution/255-replay/DISTRIBUTION.json`.

## Maintainer reproduction and artifact handling

Start with [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) for the literal seven-leg `MIX_ENV=test mix ci` command, PostgreSQL setup, exact runtime and browser prerequisites, and focused local browser commands. [`MAINTAINING.md`](../../../MAINTAINING.md) links to this report and explains safe artifact retrieval. Keep raw logs, traces, screenshots, and browser authentication state in a private temporary directory; never commit raw auth-bearing material. The tracked diagnostic bundle is sanitized.

For a failed diagnostic run, download its exact seven-day Actions artifact before expiry, for example:

```sh
umask 077
ARTIFACT_DIR="$(mktemp -d)"
gh run download 40123954650 --repo szTheory/sigra --name sigra-ci-7aae47281bb3e91bb38fe2387427f27bd0b44327-40123954650-1-diagnostic-fixture-failure-phase255-failure-1792868930 --dir "$ARTIFACT_DIR"
```

The failure Playwright command was `node test/example/priv/playwright/node_modules/playwright/cli.js test --config scripts/ci/fixtures/playwright-diagnostics.config.ts --project=chromium --retries=0`; it had no explicit seed, so its recorded seed is `null`. The runner-termination receiver adds `--grep "retains a default-context first failure"` and records SIGTERM (15); it also has no seed. Phoenix startup, discovery-before-context, and browser launch failures do not create a Playwright context or seed. Their exact argv, exits, and trace-unavailable reasons are in [BROWSER-DIAGNOSTICS.json](../255-local/BROWSER-DIAGNOSTICS.json).

The recorded `mix ci` receivers were `mix test --exclude scaffold` (ExUnit seed 259829), the six scaffold test paths (seed 512725), and `bash scripts/ci/sigra-dep-off.sh` (seed 48307); all passed. The argv and seeds are recorded separately because the seeds were generated by ExUnit, not passed as command-line options. For screenshots, treat local macOS output as **compare-only** for behavior review. Ubuntu 24.04 artifacts are authoritative for font and pixel comparisons; do not re-record the committed visual baselines on macOS.

## Status

The original comparison remains closed as `insufficient_data`. `CISPEED-01` and `CISPEED-02` remain open. The report and package replay provide implementation evidence; phase review and final verification are still pending. See the machine-readable [REPORT.json](REPORT.json) and the source results linked above.
