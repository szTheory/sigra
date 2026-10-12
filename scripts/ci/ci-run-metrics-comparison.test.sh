#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - "$TMP" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def snapshot(name, source_sha, workflow_sha, role, factor):
    base=root/name; raw=base/'raw'; pops=raw/'populations'; pops.mkdir(parents=True)
    for filename,data in [('request-ledger.json',{'requests':[]}),('selection-ledger.json',{'populations':[]})]: (base/filename).write_text(json.dumps(data,sort_keys=True))
    files={}
    for name2 in ['pull_request','push_main','schedule']:
        path=pops/(name2+'.json'); path.write_text(json.dumps({'population':name2,'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[],'pages':[]})); files[name2]=digest(path)
    for name2,data in [('rate-limit.json',{}),('effective-rules.json',[]),('branch-protection.json',{'status':'not_configured'}),('rulesets.json',[])]:
        path=raw/name2; path.write_text(json.dumps(data)); files[name2[:-5].replace('-','_')]=digest(path)
    families=[]
    for i in range(1,21):
        family={'pair_id':f'pair-{i:02d}','family_id':f'{role}-{i:02d}','family_role':role,'workload':'full','workload_sha':'workload-sha','workflow_sha256':workflow_sha,'runner_class':'ubuntu-22-x64','cache_stratum':'warm','exunit_instrumentation':'exunit-v1','playwright_instrumentation':'playwright-v1','conclusion':'success','required_result_wait_seconds':i*factor,'runner_seconds':10,'attempts':[]}
        families.append(family)
    manifest={'schema_version':'sigra.ci-run-metrics/snapshot-v1','repository':'szTheory/sigra','workflow':'ci.yml','cutoff_utc':'2026-10-12T00:00:00Z','captured_at_utc':'2026-10-12T00:01:00Z','window_start_utc':'2026-09-12T00:00:00Z','status':'complete','request_count':0,'source_sha':source_sha,'workflow_sha256':workflow_sha,'workflow_blob_sha':'blob-'+workflow_sha,'required_contexts':[],'required_rule_provenance':[],'active_rulesets':[],'source_file_sha256':{},'source_sha256':{'request_ledger':digest(base/'request-ledger.json'),'selection_ledger':digest(base/'selection-ledger.json'),**files},'populations':{'pull_request':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'push_main':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'schedule':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'manual':{'records':[]},'release_push':{'records':[]}},'comparison_families':families}
    (base/'manifest.json').write_text(json.dumps(manifest)); return base
snapshot('before','base-app','base-workflow','before',1)
snapshot('after','candidate-app','candidate-workflow','after',.5)
contract={'status':'ready','pair_count':20,'primary_family_count':40,'window_duration_hours':48,'baseline_application_sha':'base-app','baseline_workflow_sha256':'base-workflow','candidate_application_sha':'candidate-app','candidate_workflow_sha256':'candidate-workflow','instrumentation_overhead':{'exunit':{'status':'measured','value':7},'playwright':{'status':'unmeasured','reason':'not available'}}}
(root/'contract.json').write_text(json.dumps(contract))
PY
run_eval() { bash "$ROOT/scripts/ci/ci-run-metrics.sh" --evaluate-comparison --contract "$TMP/contract.json" --before-bundle "$TMP/before" --after-bundle "$TMP/after" --format json; }
run_eval >"$TMP/pass.json"
jq -e '.status=="pass" and .metrics.pair_count==20 and .metrics.comparable_successful_pairs==20 and .metrics.baseline_median_seconds==10.5 and .metrics.baseline_p95_seconds==19 and .metrics.candidate_median_seconds==5.25 and .metrics.candidate_p95_seconds==9.5 and .metrics.baseline_runner_seconds==200 and .metrics.candidate_runner_seconds==200 and (.metrics.overhead_disclosure.playwright.status=="unmeasured")' "$TMP/pass.json" >/dev/null
python3 - "$TMP/after/manifest.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d['comparison_families'].pop(); p.write_text(json.dumps(d))
PY
run_eval >"$TMP/insufficient.json"
jq -e '.status=="insufficient_data" and any(.diagnostics[];.reason=="after_family_count")' "$TMP/insufficient.json" >/dev/null
echo "ci-run-metrics-comparison.test: PASS"
