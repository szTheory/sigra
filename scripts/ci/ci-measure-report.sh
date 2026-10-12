#!/usr/bin/env bash
set -euo pipefail

BASELINE="" CONTRACT="" OUTPUT=""
while (($#)); do
  case "$1" in
    --baseline) BASELINE="$2"; shift 2;;
    --contract) CONTRACT="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    *) echo "ci-measure-report: unknown argument: $1" >&2; exit 2;;
  esac
done
[[ -s "$BASELINE" && -s "$CONTRACT" && -n "$OUTPUT" ]] || { echo "ci-measure-report: baseline, contract and output are required" >&2; exit 2; }
PYTHONPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" python3 - "$BASELINE" "$CONTRACT" "$OUTPUT" <<'PY'
import html, json, pathlib, re, sys
from ci_metrics_security import safe_markdown_url
baseline=json.loads(pathlib.Path(sys.argv[1]).read_text())
contract=json.loads(pathlib.Path(sys.argv[2]).read_text())
output=pathlib.Path(sys.argv[3])
identity=baseline.get('measured_pr_identity') or {}
def safe_text(value):
    text=str(value if value is not None else 'unknown')
    text=re.sub(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", '[REDACTED TOKEN]', text)
    text=re.sub(r"(?i)\bBearer\s+[^\s,;]+", 'Bearer [REDACTED]', text)
    text=re.sub(r'https?://[^\s<>\]\[()]+', '[URL REDACTED]', text)
    return html.escape(text, quote=False).replace('|', '&#124;').replace('\\', '&#92;').replace('\n', ' ')
def safe_link(value, label):
    url=safe_markdown_url(value)
    return f"[{safe_text(label)}](<{url}>)" if url else f"{safe_text(label)} (link unavailable)"
def sanitize_structure(value, key=''):
    if isinstance(value, dict):
        return {k:sanitize_structure(v,k) for k,v in value.items()}
    if isinstance(value, list):
        return [sanitize_structure(v,key) for v in value]
    if isinstance(value, str):
        if key in ('html_url','source_url','log_reference'):
            return safe_markdown_url(value)
        if key == 'pull_request' and value.startswith('https://'):
            return safe_markdown_url(value)
        return safe_text(value)
    return value
baseline=sanitize_structure(baseline)
contract=sanitize_structure(contract)
identity=baseline.get('measured_pr_identity') or {}
bundle_hash=baseline.get('source_bundle_sha256','unknown')
full=baseline.get('instrumented_full_pr') or {}
def show(value, unit=''):
    if value is None: return 'unknown'
    if isinstance(value, dict):
        if value.get('status') in ('unknown','insufficient_data','unmeasured'): return 'unknown ('+str(value.get('reason') or value.get('status'))+')'
        value=value.get('seconds',value.get('total_seconds',value.get('total')))
        if value is None: return 'unknown'
    return f"{value:g}{unit}"
exunit_invocations=full.get('test_costs',{}).get('exunit_invocations',[])
exunit_invocation_text='; '.join(f"{x.get('invocation','unknown')}: {x.get('tests','unknown')} tests, {show(x.get('test_duration_sum_us'),'µs')}" for x in exunit_invocations) or 'invocation reports unavailable'
def section_rank(data):
    rows=data.get('rows') or []
    return '\n'.join(f"- {row.get('identity','unknown')} — {show(row.get('seconds'),'s')} (run {row.get('run_id','unknown')}, attempt {row.get('attempt','unknown')})" for row in rows[:5]) or '- unknown (no complete source timestamps)'
def population(name, label):
    p=baseline.get('populations',{}).get(name,{})
    return f"- **{safe_text(label)}:** {safe_text(p.get('run_count',0))} selected of {safe_text(p.get('api_total_count','unknown'))} API runs; outcomes `{safe_text(json.dumps(p.get('outcomes',{}),sort_keys=True))}`; capped={safe_text(p.get('population_capped','unknown'))}"
required='\n'.join(f"- `{c}` (ruleset IDs: {', '.join(str(x.get('ruleset_id')) for x in baseline.get('required_rule_provenance',[]) if x.get('context')==c) or 'unknown'})" for c in baseline.get('required_contexts',[])) or '- unknown (effective enforcement snapshot missing)'
def run_line(r):
    label=f"{r.get('event')} run {r.get('id')} attempt {r.get('run_attempt','unknown')} — {r.get('conclusion','unknown')}"
    return f"- {safe_link(r.get('html_url'),label)} — SHA `{safe_text(r.get('head_sha','unknown'))}`, workload `{safe_text(r.get('workload','unknown'))}`"
runs='\n'.join(run_line(r) for r in baseline.get('source_runs',[])[:12]) or '- unknown (no source run records in replay)'
events=['pull_request','main','nightly']
rank_wait=baseline.get('ranked_by_wait',{}); rank_runner=baseline.get('ranked_by_runner',{})
queue_pr=baseline.get('initial_wait',{}).get('pull_request',{})
over=baseline.get('reporter_overhead',{})
exunit=over.get('exunit',{})
pw=over.get('playwright',{})
versions=baseline.get('observed_versions',{})
configured=baseline.get('configured_versions',{})
def versions_text():
    lines=[]
    for event in events:
        actual=versions.get(event,{})
        pins=configured.get(event,{})
        lines.append(f"- **{event}:** configured `{json.dumps(pins,sort_keys=True)}`; observed `{json.dumps(actual,sort_keys=True)}`")
    return '\n'.join(lines)
missing=[]
if baseline.get('instrumented_full_pr',{}).get('complete') is not True:
    missing.extend(baseline.get('instrumented_full_pr',{}).get('diagnostics') or ['complete instrumented full PR sample unavailable'])
if baseline.get('required_result_wait',{}).get('status')!='measured': missing.append(baseline.get('required_result_wait',{}).get('reason','required result endpoint unavailable'))
failures=baseline.get('failure_signatures',{})
if failures.get('signatures'):
    failure_text='\n'.join(f"- {safe_text(x.get('signature'))} — {safe_text(x.get('occurrences'))} observations: " + ', '.join(safe_link(r.get('log_reference'), f"run {r.get('run_id')} attempt {r.get('attempt')}") for r in x.get('references',[])) for x in failures['signatures'][:3])
else:
    failure_text=f"- {safe_text(failures.get('status','unknown'))}: {', '.join(safe_text(x) for x in failures.get('missing_inputs',[])[:3]) or 'no recurring signature was identified in the bounded sample'}"
attempts=baseline.get('instrumented_full_pr',{}).get('run_attempts') or []
attempt_lines=[]
for attempt in attempts:
    failed=[j for j in attempt.get('jobs',[]) if j.get('conclusion') in ('failure','timed_out','cancelled')]
    skipped=sum(1 for j in attempt.get('jobs',[]) if j.get('conclusion')=='skipped')
    detail=', '.join(f"{j.get('name')} `{j.get('conclusion')}` ({show(j.get('runner_seconds'),'s')})" for j in failed) if failed else 'no failed, timed out or cancelled jobs'
    attempt_lines.append(f"- Attempt {attempt.get('attempt','unknown')}: {show(attempt.get('runner_seconds'),'s')} summed runner time; {detail}; {skipped} skipped jobs.")
attempt_text='\n'.join(attempt_lines) or '- unknown (attempt job records were not retained)'
window=contract.get('window') or {}
window_dates=f"`{window.get('start_utc')}` to `{window.get('end_utc')}`" if window.get('start_utc') and window.get('end_utc') else 'unset; freeze exact UTC start/end after candidate identity and before the first comparison run'
text=f'''# Current CI baseline

Cutoff: `{baseline.get('cutoff_utc','unknown')}`; collected `{baseline.get('captured_at_utc','unknown')}` from collector checkout `{baseline.get('source_sha','unknown')}` and collector workflow SHA-256 `{baseline.get('workflow_sha256','unknown')}`. Immutable source bundle SHA-256: `{bundle_hash}`. Replay source identity: `{baseline.get('source_sha256',{}).get('pull_request','unknown')}` (PR population hash), `{baseline.get('source_sha256',{}).get('request_ledger','unknown')}` (request ledger hash). Status: **{baseline.get('status','unknown')}**. This snapshot is bounded to 100 runs per event and a 30-day window; capped/expired or undetailed records remain unknown.

## Separate populations

{population('pull_request','Pull requests')}
{population('push_main','Main pushes')}
{population('schedule','Nightly schedule')}

PR workload classes: full `{baseline.get('cohorts',{}).get('full',{}).get('n',0)}` measured / `{baseline.get('cohorts',{}).get('full',{}).get('run_count',0)}` selected; docs-only `{baseline.get('cohorts',{}).get('docs_only',{}).get('n',0)}` measured / `{baseline.get('cohorts',{}).get('docs_only',{}).get('run_count',0)}` selected. Missing changed-file detail is unknown, not docs-only.

## Required result and cost

The endpoint is the last successful completion of all currently enforced contexts, not workflow close. Pure queue time is {show(baseline.get('pure_queue_seconds'),'s')}; initial per-job queue wait is {show(queue_pr.get('total_seconds'),'s')} summed across {queue_pr.get('n','unknown')} job attempts (not a workflow wall time); dependency gaps remain {show(baseline.get('dag_dependency_gaps',{}).get('pull_request'))}; required-result wait is {show(baseline.get('required_result_wait'), 's')}. A full source-bound instrumented PR sample is `{full.get('status','unknown')}`. Across its retained attempts, runner cost is {show(full.get('job_cost_seconds'),'s')}; timing producer jobs account for {show(full.get('instrumentation_producer_job_seconds'),'s')}; ExUnit invocation reports are {exunit_invocation_text} (total {show(full.get('test_costs',{}).get('exunit_test_duration_us'),'µs')}) and Playwright tests total {show(full.get('test_costs',{}).get('playwright_test_duration_ms'),'ms')}. Run [{identity.get('producing_run_id','unknown')} attempt {identity.get('run_attempt','unknown')}]({identity.get('source_url') or 'https://github.com/szTheory/sigra/actions'}) came from draft PR [#{identity.get('pull_request_number','unknown')}]({identity.get('pull_request') or 'https://github.com/szTheory/sigra/pulls'}). Application/workflow revision `{identity.get('application_sha','unknown')}`; producer checked-out source revision `{identity.get('producer_source_sha','unknown')}`; workflow file SHA-256 `{identity.get('workflow_file_sha256','unknown')}`; workload identity SHA-256 `{identity.get('workload_revision_sha256','unknown')}`. These are distinct revisions and digests.

Currently enforced required names, with ruleset IDs as provenance:
{required}

### Longest observed wait

{section_rank(rank_wait.get('pull_request',{}))}

Main pushes:
{section_rank(rank_wait.get('main',{}))}

Nightly schedule:
{section_rank(rank_wait.get('nightly',{}))}

### Largest summed runner cost

{section_rank(rank_runner.get('pull_request',{}))}

Main pushes:
{section_rank(rank_runner.get('main',{}))}

Nightly schedule:
{section_rank(rank_runner.get('nightly',{}))}

Wait includes time until the required-result endpoint; runner cost sums actual job execution across attempts. They are different measures. Dependency gaps are {show(baseline.get('dag_dependency_gaps',{}).get('pull_request',{}))}. Step categories: setup `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('setup'))}`, cache restore/download `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('cache_restore_download'))}`, compile `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('compile'))}`, database `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('database_startup'))}`, app boot `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('app_boot'))}`, tests `{show(baseline.get('stage_costs',{}).get('pull_request',{}).get('test_execution'))}. Cache: `{json.dumps(baseline.get('cache_outcome',{}),sort_keys=True)}`. Runner image: `{json.dumps(baseline.get('runner_image',{}).get('pull_request',{}),sort_keys=True)}`.

## Tool versions and measurement overhead

Configured pins are not command-observed versions:
{versions_text()}

ExUnit overhead: `{json.dumps(exunit,sort_keys=True)}`. Playwright reporter overhead: `{json.dumps(pw,sort_keys=True)}`. If either value is unmeasured or null, the report keeps it unknown. Both future comparison conditions must use the same timing instrumentation; no overhead estimate is subtracted from the improvement target.

## Current failures

At most twelve failed families were inspected; no more than three recurring signatures are shown:
{failure_text}

The selected full PR family completed required checks on attempt `{baseline.get('instrumented_full_pr',{}).get('attempt','unknown')}`. Its complete attempt history is:

{attempt_text}

## Exact source run records

{runs}

## Frozen later comparison

Contract status `{contract.get('status','unknown')}`; fixed `{contract.get('pair_count','unknown')} pairs / {contract.get('primary_family_count','unknown')} families`, `{contract.get('window_duration_hours','unknown')}-hour window; dates {window_dates}. The comparison needs 20 equivalent successful pairs, at least 20% lower median required-result wait, non-increasing nearest-rank p95 and total runner cost. With 20 pairs p95 is the 19th sorted value and is a fragile tail estimate, not a population guarantee. No 40-family comparison is scheduled by this phase.

Known missing inputs: {', '.join(missing) if missing else 'none recorded'}.

## Reproduce

Run from the repository root:

```sh
bash scripts/ci/ci-run-metrics.sh --replay --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --format json
bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json
SIGRA_EXUNIT_TIMING_JSON=tmp/ci-exunit-timing-main.json SIGRA_EXUNIT_TIMING_INVOCATION=main PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci
SIGRA_EXAMPLE_URL=http://localhost:4002 SIGRA_PLAYWRIGHT_JSON=artifacts/ci-timing/admin_checkpoints-local.json npm --prefix test/example/priv/playwright test -- tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark --retries=0
```

The browser command requires the example app running on port 4002 with isolated database `sigra_admin_checkpoints` and the Playwright browsers installed as in `.github/actions/example-playwright-boot/action.yml`. Complete contributor setup guidance is planned for Phase 255. The frozen contract is `252-COMPARISON-CONTRACT.json`; unavailable or expired hosted inputs remain unknown and keep baseline validation nonzero.
'''
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(text)
PY
