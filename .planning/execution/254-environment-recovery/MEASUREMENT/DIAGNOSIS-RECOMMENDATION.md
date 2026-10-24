# Fixed comparison: terminal insufficient data

Pair 01 spent two measured invocations. The [baseline run 40046955449, attempt 2](https://github.com/szTheory/sigra/actions/runs/40046955449/attempts/2) failed in `Run admin checkpoints` (job `120734314423`). The [candidate run 40047078287, attempt 2](https://github.com/szTheory/sigra/actions/runs/40047078287/attempts/2) succeeded. The required browser aggregate and terminal gate correctly failed on the baseline. The cause of the checkpoint test failure needs its actual failed-step diagnostics; a collector error is not an infrastructure diagnosis.

The frozen contract requires 20 successful comparable pairs and prohibits replacement samples. The remaining 19 pairs could yield at most 19 successful pairs. Do not spend the other 38 invocations merely to reach an inevitable `insufficient_data` result. Keep their unused status, the original window, source identities, failed sample and both spent invocations unchanged. This is a completed unsuccessful measurement outcome, not permission to restart the experiment.

`sampling.retry_policy` mentions one diagnosed infrastructure retry, but the frozen execution contract reserves exact attempts 2–21 and caps mutations at 40. Attempt 3 is already pair 02. The trigger guard also requires the previous attempt to have succeeded. There is no unused encoded retry slot: silently shifting reservations, inserting a retry, reusing preparation runs, reducing the target count or opening another window would change this experiment after observing its failure.

## What the saved bytes establish

- `EVENTS.jsonl` and `PROGRESS.json` record both reservations, literal conclusions and the stop after preservation.
- `requests/pair-01/CAPTURE-before.json` binds the baseline capture to `refs/evidence/phase254-measurement-pair-01-before-attempt-2` at `1c1cc0f786e52cacddb8e69a07a5855c0b74045c`.
- `requests/pair-01/CAPTURE-after.json` binds the candidate capture to `refs/evidence/phase254-measurement-pair-01-after-attempt-2` at `5df0b52e9773364de9fa1aa8a37b831133c56600`.
- The baseline checkpoint metadata records exact cache hits, successful OS-package installation, verified native image proof and observed runtime/browser versions. It does not demonstrate an infrastructure failure.
- `requests/pair-01/before.collect.log.stderr` records the collector's metadata-origin rejection. Materialization stopped, so its snapshot has no `comparison_families` field. This omission does not mean the failed invocation or its runner costs are absent from the retained raw files.

Offline replay of the retained run/jobs/checks, with raw hash checks passing on both captures, establishes:

| Observation | Baseline attempt 2 | Candidate attempt 2 |
|---|---:|---:|
| Literal conclusion | failure | success |
| All actual job runner-seconds | 2046 | 1589 |
| Unknown job costs | none | none |
| Successful required-result wait | unavailable | 261 seconds |

The baseline never obtained its successful required browser result. Its wait must stay `null`, not zero or a substituted successful duration. These two costs are observations, not a demonstrated speed/cost improvement across the required sample.

## Minimal offline recovery of the result

No HTTP request, rerun, contract amendment or capture overwrite is needed to recover both known runner costs. The existing pure helper `derive_comparison_family_costs` already accepts failed runs and derives costs from the hash-bound run, every saved job and native checks. Run from the repository root; this prints fresh JSON without editing the captures:

```bash
PYTHONPATH=scripts/ci python3 - <<'PY'
import json
from pathlib import Path
from ci_metrics_security import derive_comparison_family_costs, verify_snapshot_hashes
m = Path('.planning/execution/254-environment-recovery/MEASUREMENT')
contract = json.loads((m / 'CONTRACT.json').read_text())
attempts = []
for role, run_id in [('before', 40046955449), ('after', 40047078287)]:
    bundle = m / 'requests/pair-01' / ('raw-' + role)
    assert verify_snapshot_hashes(bundle) == []
    facts = derive_comparison_family_costs(
        bundle, run_id, contract['required_contexts'], run_attempt=2)
    expected = (contract['baseline_application_sha'] if role == 'before'
                else contract['candidate_identity']['application_sha'])
    assert facts['status'] == 'complete' and facts['head_sha'] == expected
    attempts.append({'role': role, 'capture': str(bundle), **facts})
print(json.dumps({'status': 'insufficient_data', 'measured_invocations': 2,
                  'successful_comparable_pairs': 0,
                  'unspent_measured_invocations': 38, 'attempts': attempts}, indent=2))
PY
```

The existing `--evaluate-comparison` command can also replay the retained partial snapshots literally, but cannot include the baseline's cost as a comparison family while its family row is absent. Do not rely on its missing-family subtotal as the complete cost inventory. There is currently no separate offline CLI flag for the materialization block embedded inside `collect_comparison`.

If the collector owner repairs failed-family materialization, the smallest safe change is to separate authenticated identity from successful outcome: retain a truthful failed-family row and known costs while keeping missing required-result wait/native coverage unknown. Apply it to a **new derived output**, with the original raw capture/ref/hash still referenced; never modify `raw-before`. Mandatory native/source checks and the actual `failure` conclusion must continue to prevent a successful comparable pair. Such an offline parser repair cannot rescue the 20-pair result and must not trigger another CI invocation.

## Next useful work

Diagnose and, where appropriate, fix the checkpoint failure with a targeted reproduction and meaningful local tests. A collector/report fix is ordinary maintenance. Changing frozen baseline application, test or workflow bytes is a source amendment and cannot be presented as an unchanged continuation of this cohort. Keep CISPEED-01/02 unaccepted and report this fixed experiment as `insufficient_data`, with the candidate's actual green run and all observed costs preserved separately. Do not add another numbered repair plan or silently renew an acceptance allowance.

## Completed local repair

The reporting repairs are committed at `d5b7300c8`. The evaluator now handles a null family input and separately derives all observed registration costs from hash-verified raw files, including failed and unpaired runs. `EVALUATION-COSTS.json` supersedes the earlier crashing/zero-subtotal outputs and still reports `insufficient_data` with2046 baseline and1589 candidate runner-seconds. No family was invented.

The browser failure has a causal local reproduction: retiring the primary WebSocket delivered a stale close event against its LongPoll replacement, triggered LiveView reload and aborted XHR. Guarding physical connection callbacks, clearing old heartbeat state and restarting channel joins fixes the reproduced path. The production backport (`e2ab83edb`) also respects reconnect/disconnect inside channel-error callbacks. The exact served production bundle passed forced fallback in WebKit/Chromium and five normal mobile contexts; seven deterministic Node regressions exercise the shipped class. See `LOCAL-REGISTRATION/PRODUCTION-VERIFICATION.json`.

[Phoenix PR6867](https://github.com/phoenixframework/phoenix/pull/6867) independently documents these lifecycle races. The retained hosted run lacks a trace showing what originally delayed its primary response; local reproduction proves the downstream failure path and fix, not that missing initiating event. Neither frozen measurement branch was amended. A separate single development CI verification is recorded under `.planning/execution/254-transport-development-check`; it cannot become a measurement sample.
