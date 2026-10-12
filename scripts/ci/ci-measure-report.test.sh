#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/baseline.json" <<'JSON'
{"status":"complete","cutoff_utc":"2026-10-12T00:00:00Z","captured_at_utc":"2026-10-12T00:01:00Z","source_sha":"abc123","workflow_sha256":"def456","source_sha256":{"pull_request":"prhash","request_ledger":"ledgerhash"},"required_contexts":["Library tests","Example unit smoke (ExUnit + ConnTest)"],"required_rule_provenance":[{"context":"Library tests","ruleset_id":10},{"context":"Example unit smoke (ExUnit + ConnTest)","ruleset_id":11}],"source_runs":[{"event":"pull_request","id":123,"run_attempt":1,"conclusion":"success","html_url":"https://github.com/szTheory/sigra/actions/runs/123","head_sha":"abc123","workload":"full"}],"populations":{"pull_request":{"run_count":1,"api_total_count":5,"population_capped":false,"outcomes":{"success":1}},"push_main":{"run_count":0,"api_total_count":2,"population_capped":false,"outcomes":{}},"schedule":{"run_count":0,"api_total_count":1,"population_capped":false,"outcomes":{}}},"cohorts":{"full":{"n":1,"run_count":1},"docs_only":{"n":0,"run_count":0}},"required_result_wait":{"status":"unknown","seconds":null,"reason":"required contexts missing"},"instrumented_full_pr":{"complete":false,"status":"insufficient_data","diagnostics":["instrumented artifacts expired"],"run_attempts":[{"attempt":1,"runner_seconds":50,"jobs":[{"name":"Example unit smoke (ExUnit + ConnTest)","conclusion":"failure","runner_seconds":23}]},{"attempt":2,"runner_seconds":60,"jobs":[{"name":"Example unit smoke (ExUnit + ConnTest)","conclusion":"success","runner_seconds":54},{"name":"Optional","conclusion":"skipped","runner_seconds":null}]}]},"pure_queue_seconds":null,"ranked_by_wait":{"pull_request":{"rows":[]}},"ranked_by_runner":{"pull_request":{"rows":[]}},"dag_dependency_gaps":{"pull_request":{"status":"unknown","reason":"dependency edges not available"}},"stage_costs":{"pull_request":{}},"cache_outcome":{"library_deps":"unknown"},"runner_image":{"pull_request":{}},"configured_versions":{"pull_request":{"node":"20"}},"observed_versions":{"pull_request":{"node":{"value":null,"reason":"artifact unavailable"}}},"reporter_overhead":{"exunit":{"status":"unknown","overhead_us":null},"playwright":{"status":"unmeasured","overhead_ms":null,"reason":"no producing artifact"}},"failure_signatures":{"status":"unknown","missing_inputs":["redacted failed log unavailable"],"signatures":[]}}
JSON
jq '.instrumented_full_pr.test_costs={exunit_test_duration_us:100000,playwright_test_duration_ms:0,exunit_invocations:[{invocation:"main",tests:10,test_duration_sum_us:60000},{invocation:"threadline_guard",tests:2,test_duration_sum_us:40000}]}' "$TMP/baseline.json" >"$TMP/baseline.updated.json"
mv "$TMP/baseline.updated.json" "$TMP/baseline.json"
cat >"$TMP/contract.json" <<'JSON'
{"status":"blocked","pair_count":20,"primary_family_count":40,"window_duration_hours":48,"instrumentation_overhead":{"exunit":{"status":"unknown"},"playwright":{"status":"unmeasured"}}}
JSON
bash "$ROOT/scripts/ci/ci-measure-report.sh" --baseline "$TMP/baseline.json" --contract "$TMP/contract.json" --output "$TMP/first.md"
bash "$ROOT/scripts/ci/ci-measure-report.sh" --baseline "$TMP/baseline.json" --contract "$TMP/contract.json" --output "$TMP/second.md"
cmp "$TMP/first.md" "$TMP/second.md"
python3 - "$TMP/first.md" <<'PY'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text()
required=['Pull requests:','Main pushes:','Nightly schedule:','unknown (required contexts missing)','configured `','observed `','unmeasured','instrumented artifacts expired','Attempt 1: 50s','Example unit smoke (ExUnit + ConnTest) `failure` (23s)','Attempt 2: 60s','Immutable source bundle SHA-256:','initial per-job queue wait','not a workflow wall time','Main pushes:\n','Nightly schedule:\n','producer checked-out source revision','ExUnit invocation reports are main: 10 tests, 60000µs; threadline_guard: 2 tests, 40000µs','These are distinct revisions and digests','unset; freeze exact UTC start/end','--replay --source-bundle','--verify-baseline --source-bundle','SIGRA_EXUNIT_TIMING_JSON=','SIGRA_EXAMPLE_URL=','ruleset IDs: 10','ruleset IDs: 11','p95 is the 19th sorted value','no more than three recurring signatures','Replay source identity: `prhash`']
missing=[x for x in required if x not in text]
if missing: raise SystemExit('report missing: '+', '.join(missing)+'\n'+next((line for line in text.splitlines() if 'ExUnit invocation reports' in line), 'ExUnit line missing'))
if 'required-result wait is 0s' in text or 'pure queue time is 0s' in text: raise SystemExit('unknown metric was rendered as zero')
PY
python3 - "$TMP/baseline.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text())
d['source_runs'][0]['html_url']='https://github.com.evil.test/szTheory/sigra/actions/runs/123?token=ghp_supersecretvalue1234567890'
d['failure_signatures']={'status':'unknown','missing_inputs':[],'signatures':[{'signature':'<script>alert(1)</script> [x](https://evil.test/?token=leak)','occurrences':1,'references':[{'run_id':123,'attempt':1,'log_reference':'https://github.com/szTheory/sigra/actions/runs/123'}]}]}
p.write_text(json.dumps(d))
PY
bash "$ROOT/scripts/ci/ci-measure-report.sh" --baseline "$TMP/baseline.json" --contract "$TMP/contract.json" --output "$TMP/adversarial.md"
if grep -E 'github\.com\.evil|supersecretvalue|token=leak|<script>|\]\(https://evil' "$TMP/adversarial.md" >/dev/null; then
  echo "report exposed unsafe URL or Markdown payload" >&2
  exit 1
fi
grep -F 'link unavailable' "$TMP/adversarial.md" >/dev/null
echo "ci-measure-report.test: PASS"
