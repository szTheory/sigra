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
    for name2 in ['pull_request','push_main','schedule','manual','release_push']:
        path=pops/(name2+'.json'); path.write_text(json.dumps({'population':name2,'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[],'pages':[]})); files[name2]=digest(path)
    for name2,data in [('rate-limit.json',{}),('effective-rules.json',[]),('branch-protection.json',{'status':'not_configured'}),('rulesets.json',[])]:
        path=raw/name2; path.write_text(json.dumps(data)); files[name2[:-5].replace('-','_')]=digest(path)
    families=[]
    api_runs=[]
    for i in range(1,21):
        run_id=(1000 if role=='before' else 2000)+i
        created='2026-10-14T10:00:00Z'
        family={'pair_id':f'pair-{i:02d}','family_id':f'{role}-{i:02d}','family_role':role,'run_id':run_id,'created_at':created,'workload':'full','workload_sha':'workload-sha','workflow_sha256':workflow_sha,'runner_class':'ubuntu-22-x64','runner_image':'ubuntu-24-20261012','cache_stratum':'warm','exunit_instrumentation':'exunit-v1','playwright_instrumentation':'playwright-v1','conclusion':'success','required_result_wait_seconds':i*factor,'runner_seconds':10,'attempts':[]}
        families.append(family)
        api_runs.append({'id':run_id,'event':'pull_request','head_sha':source_sha,'created_at':created,'detail_status':'complete'})
    manifest={'schema_version':'sigra.ci-run-metrics/snapshot-v1','repository':'szTheory/sigra','workflow':'ci.yml','cutoff_utc':'2026-10-12T00:00:00Z','captured_at_utc':'2026-10-12T00:01:00Z','window_start_utc':'2026-09-12T00:00:00Z','status':'complete','request_count':0,'source_sha':source_sha,'workflow_sha256':workflow_sha,'workflow_blob_sha':'blob-'+workflow_sha,'measured_pr_identity':{'application_sha':source_sha,'workflow_revision':source_sha,'workflow_file_sha256':workflow_sha,'workload_revision_sha256':'workload-sha'},'required_contexts':[],'required_rule_provenance':[],'active_rulesets':[],'source_file_sha256':{},'source_sha256':{'request_ledger':digest(base/'request-ledger.json'),'selection_ledger':digest(base/'selection-ledger.json'),**files},'populations':{'pull_request':{'api_total_count':20,'population_capped':False,'population_exhausted':True,'runs':api_runs},'push_main':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'schedule':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'manual':{'records':[]},'release_push':{'records':[]}},'comparison_families':families}
    (base/'manifest.json').write_text(json.dumps(manifest)); return base,families
before,before_rows=snapshot('before','base-app','base-workflow','before',1)
after,after_rows=snapshot('after','candidate-app','candidate-workflow','after',.5)
reservations=[]
for family in before_rows+after_rows:
    reservations.append({'reservation_id':'r-'+str(family['run_id']),'pair_id':family['pair_id'],'family_role':family['family_role'],'run_id':family['run_id'],'created_at':family['created_at']})
registrations=[]; previous='0'*64
for index,reservation in enumerate(reservations):
    import hashlib
    row={'sequence':index,'previous_sha256':previous,**reservation}
    row['record_sha256']=hashlib.sha256(json.dumps(row,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    registrations.append(row); previous=row['record_sha256']
contract={'status':'ready','pair_count':20,'primary_family_count':40,'family_reservations':reservations,'family_registrations':registrations,'window_duration_hours':48,'baseline_application_sha':'base-app','baseline_workload_revision_sha256':'workload-sha','baseline_workflow_sha256':'base-workflow','candidate_identity':{'application_sha':'candidate-app','workflow_revision':'candidate-app','workload_revision_sha256':'workload-sha','workflow_file_sha256':'candidate-workflow'},'window':{'start_utc':'2026-10-13T10:00:00Z','end_utc':'2026-10-15T10:00:00Z'},'cache_stratum_allocation':[{'stratum_id':'warm','pair_count':20}],'instrumentation_overhead':{'exunit':{'status':'measured','value':7},'playwright':{'status':'unmeasured','reason':'not available'}}}
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
python3 - "$TMP/contract.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d['cache_stratum_allocation'][0]['pair_count']=21; p.write_text(json.dumps(d))
PY
run_eval >"$TMP/cache-allocation-mismatch.json"
jq -e '.status=="insufficient_data" and any(.diagnostics[];.reason=="cache_stratum_allocation_mismatch")' "$TMP/cache-allocation-mismatch.json" >/dev/null
echo "ci-run-metrics-comparison.test: PASS"
