#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$ROOT/scripts/ci/.comparison-test-map.json" "$ROOT/scripts/ci/.comparison-test-parity.json" "$ROOT/scripts/ci/.comparison-test-blocked-parity.json"' EXIT
python3 - "$TMP" "$ROOT" <<'PY'
import base64,datetime,hashlib,json,pathlib,sys,zipfile
root=pathlib.Path(sys.argv[1])
project=pathlib.Path(sys.argv[2])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
required=['Library tests','Example unit smoke (ExUnit + ConnTest)','Install smoke (fresh phx.new + sigra.install)','Example HTTP smoke (boot + curl critical routes)','Example Playwright smoke (full lifecycle)']
schedule=[]
coverage_owners={'admin_behavior':43,'admin_checkpoints':3,'design_gallery':42,'non_admin_smoke':16,'demo_showcase':4}
coverage_map_rows=[]
for pair in range(1,21):
    roles=('before','after') if pair%2 else ('after','before')
    schedule.extend({'pair_id':f'pair-{pair:02d}','family_role':role} for role in roles)
reservations=[{'reservation_id':f"r-{slot['pair_id']}-{slot['family_role']}",**slot} for slot in schedule]
def snapshot(name, source_sha, workflow_sha, role, factor):
    base=root/name; raw=base/'raw'; pops=raw/'populations'; pops.mkdir(parents=True)
    requests=[]
    (base/'selection-ledger.json').write_text(json.dumps({'populations':[]},sort_keys=True))
    files={}
    for name2 in ['pull_request','push_main','schedule','manual','release_push']:
        path=pops/(name2+'.json'); path.write_text(json.dumps({'population':name2,'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[],'pages':[]})); files[name2]=digest(path)
    for name2,data in [('rate-limit.json',{}),('effective-rules.json',[]),('branch-protection.json',{'status':'not_configured'}),('rulesets.json',[])]:
        path=raw/name2; path.write_text(json.dumps(data)); files[name2[:-5].replace('-','_')]=digest(path)
    families=[]
    api_runs=[]
    for i in range(1,21):
        run_id=(1000 if role=='before' else 2000)+i
        pair=int(i); base_time=datetime.datetime(2026,10,14,10,0,tzinfo=datetime.timezone.utc)+datetime.timedelta(seconds=pair*60)
        first=schedule[(pair-1)*2]['family_role']; offset=10 if role==first else 20
        created=(base_time+datetime.timedelta(seconds=offset)).isoformat().replace('+00:00','Z')
        pr={'number':331,'head':{'sha':source_sha,'repo':{'id':1207487684}},'base':{'sha':'base-ref','repo':{'id':1207487684}}}
        run={'id':run_id,'event':'pull_request','path':'.github/workflows/ci.yml','head_sha':source_sha,'created_at':created,'updated_at':created,'run_attempt':2,'status':'completed','conclusion':'success','repository':{'id':1207487684,'full_name':'szTheory/sigra'},'pull_requests':[pr]}
        family={'pair_id':f'pair-{i:02d}','family_id':f'{role}-{i:02d}','family_role':role,'run_id':run_id,'created_at':created,'workload':'full','workload_sha':'workload-sha','workflow_sha256':workflow_sha,'runner_class':'ubuntu-22-x64','runner_image':'ubuntu-24-20261012','cache_stratum':'warm','exunit_instrumentation':'exunit-v1','playwright_instrumentation':'playwright-v1','conclusion':'success','required_result_wait_seconds':999,'runner_seconds':1,'attempts':[]}
        families.append(family)
        api_runs.append({**run,'detail_status':'complete','workload':'full','attempt_jobs':{}})
        family_dir=raw/'families'/str(run_id); family_dir.mkdir(parents=True)
        (family_dir/'run.json').write_text(json.dumps(run,sort_keys=True))
        fail_job={'id':run_id*100+99,'run_id':run_id,'run_attempt':1,'head_sha':source_sha,'name':'failed preparation','conclusion':'failure','started_at':created,'completed_at':(base_time+datetime.timedelta(seconds=offset+20)).isoformat().replace('+00:00','Z')}
        attempt1={'jobs':[fail_job]}; path1=family_dir/'jobs-attempt-1.json'; path1.write_text(json.dumps(attempt1,sort_keys=True))
        wait=int((200+i)*factor); completed=base_time+datetime.timedelta(seconds=offset+wait)
        jobs=[]; checks=[]
        for index,context in enumerate(required):
            jid=run_id*100+index+1; ended=completed
            started=ended-datetime.timedelta(seconds=10 if role=='before' else 5)
            jobs.append({'id':jid,'run_id':run_id,'run_attempt':2,'head_sha':source_sha,'name':context,'conclusion':'success','started_at':started.isoformat().replace('+00:00','Z'),'completed_at':ended.isoformat().replace('+00:00','Z')})
            checks.append({'id':jid+1000000,'external_id':str(jid),'name':context,'head_sha':source_sha,'status':'completed','conclusion':'success','started_at':started.isoformat().replace('+00:00','Z'),'completed_at':ended.isoformat().replace('+00:00','Z'),'app':{'slug':'github-actions'},'check_suite':{'id':run_id*10+index}})
        attempt2={'jobs':jobs}; path2=family_dir/'jobs-attempt-2.json'; path2.write_text(json.dumps(attempt2,sort_keys=True))
        checks_path=family_dir/'check-runs.json'; checks_path.write_text(json.dumps({'check_runs':checks},sort_keys=True))
        artifact_dir=family_dir/'artifacts'; artifact_dir.mkdir()
        archive=artifact_dir/'777.zip'
        report_bytes=b'{}'
        with zipfile.ZipFile(archive,'w') as zf: zf.writestr('report.json',report_bytes)
        archive_hash=digest(archive)
        extracted=artifact_dir/'777'; extracted.mkdir(); (extracted/'report.json').write_bytes(report_bytes)
        artifact={'id':777,'name':'playwright-report','expired':False,'digest':'sha256:'+archive_hash,'workflow_run':{'id':run_id,'head_sha':source_sha,'repository_id':1207487684}}
        metadata_path=family_dir/'artifacts-metadata.json'; metadata_path.write_text(json.dumps({'artifacts':[artifact]},sort_keys=True))
        evidence=[{'artifact':artifact,'result':{'status':'accepted','archive_sha256':archive_hash,'members':[{'member':'report.json','sha256':hashlib.sha256(report_bytes).hexdigest()}]}}]
        evidence_path=family_dir/'artifact-evidence.json'; evidence_path.write_text(json.dumps(evidence,sort_keys=True))
        details={'schema_version':'sigra.ci-run-metrics/family-detail-v1','run_id':run_id,'detail_status':'complete','source_run_sha256':digest(family_dir/'run.json'),'attempt_jobs':{'1':{'path':f'raw/families/{run_id}/jobs-attempt-1.json','sha256':digest(path1)},'2':{'path':f'raw/families/{run_id}/jobs-attempt-2.json','sha256':digest(path2)}},'check_runs_sha256':digest(checks_path),'artifact_metadata_sha256':digest(metadata_path),'artifact_evidence':{'path':f'raw/families/{run_id}/artifact-evidence.json','sha256':digest(evidence_path)},'changed_path_pages':[]}
        (family_dir/'manifest.json').write_text(json.dumps(details,sort_keys=True))
        for owner,count in coverage_owners.items():
            native_dir=family_dir/'artifacts'/'coverage'/owner; native_dir.mkdir(parents=True)
            suites=[]; inventory=[]
            for case in range(count):
                title=f'fixture native case {owner} {case:02d}'
                spec_file=f'tests/{owner}-{case:02d}.spec.ts'
                identity=['chromium',spec_file,[spec_file],f'spec-{case}',title]
                test={'projectId':'chromium','projectName':'chromium','expectedStatus':'passed','status':'expected','results':[{'retry':0,'status':'passed','duration':1,'startTime':'2026-10-13T00:00:00Z'}]}
                spec={'id':f'spec-{case}','title':title,'file':spec_file,'tests':[test]}
                suites.append({'title':spec_file,'file':spec_file,'specs':[spec]})
                identity_json=json.dumps(identity,separators=(',',':'))
                inventory.append({'id':identity_json,'project':'chromium','spec':spec_file,'title':title,'owner':owner,'classification':'product'})
                if role=='before' and i==1: coverage_map_rows.append({'before':identity,'after':identity,'owner':owner,'kind':'product'})
            report={'config':{'projects':[{'id':'chromium','name':'chromium'}]},'suites':suites,'errors':[],'stats':{'expected':count,'unexpected':0,'flaky':0,'skipped':0,'startTime':'2026-10-13T00:00:00Z','duration':10}}
            selection=json.loads(json.dumps(report))
            for suite in selection['suites']:
                for spec in suite['specs']:
                    for selected_test in spec['tests']: selected_test['results']=[]
            report_path=native_dir/'native.json'; selection_path=native_dir/'selection.json'
            report_path.write_text(json.dumps(report)); selection_path.write_text(json.dumps(selection))
            descriptor={'schema_version':'sigra.browser-coverage-source/v1','source_sha':source_sha,'workflow_sha256':'c'*64,'configuration_sha256':'d'*64,'lock_sha256':'e'*64,'event':'pull_request','seam':owner,'owner':owner,'project_inventory':['chromium'],'selected_inventory':inventory,'excluded_inventory':[],'skip_policies':[],'reports':[{'path':'native.json','selection_path':'selection.json','sha256':digest(report_path),'selection_sha256':digest(selection_path),'source_sha':source_sha}]}
            (native_dir/'coverage-source.json').write_text(json.dumps(descriptor))
        requests += [f'/repos/szTheory/sigra/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100' for attempt in (1,2)]
    (base/'request-ledger.json').write_text(json.dumps({'requests':requests},sort_keys=True))
    pr_population=pops/'pull_request.json'
    pr_population.write_text(json.dumps({'population':'pull_request','api_total_count':20,'population_capped':False,'population_exhausted':True,'runs':api_runs,'pages':[]},sort_keys=True))
    files['pull_request']=digest(pr_population)
    manifest={'schema_version':'sigra.ci-run-metrics/snapshot-v1','repository':'szTheory/sigra','workflow':'ci.yml','cutoff_utc':'2026-10-12T00:00:00Z','captured_at_utc':'2026-10-12T00:01:00Z','window_start_utc':'2026-09-12T00:00:00Z','status':'complete','request_count':len(requests),'source_sha':source_sha,'workflow_sha256':workflow_sha,'workflow_blob_sha':'blob-'+workflow_sha,'measured_pr_identity':{'application_sha':source_sha,'workflow_revision':source_sha,'workflow_file_sha256':workflow_sha,'workload_revision_sha256':'workload-sha'},'required_contexts':required,'required_rule_provenance':[],'active_rulesets':[],'source_file_sha256':{},'source_sha256':{'request_ledger':digest(base/'request-ledger.json'),'selection_ledger':digest(base/'selection-ledger.json'),**files},'populations':{'pull_request':{'api_total_count':20,'population_capped':False,'population_exhausted':True,'runs':api_runs},'push_main':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'schedule':{'api_total_count':0,'population_capped':False,'population_exhausted':True,'runs':[]},'manual':{'records':[]},'release_push':{'records':[]}},'comparison_families':families,'comparison_collection':{'role':role}}
    (base/'manifest.json').write_text(json.dumps(manifest)); return base,families
before,before_rows=snapshot('before','a'*40,'base-workflow','before',1)
after,after_rows=snapshot('after','b'*40,'candidate-workflow','after',.5)
reservations=[{'reservation_id':f"r-{slot['pair_id']}-{slot['family_role']}",'pair_id':slot['pair_id'],'family_role':slot['family_role'],'run_id':next(f['run_id'] for f in before_rows+after_rows if f['pair_id']==slot['pair_id'] and f['family_role']==slot['family_role']),'created_at':next(f['created_at'] for f in before_rows+after_rows if f['pair_id']==slot['pair_id'] and f['family_role']==slot['family_role'])} for slot in schedule]
registrations=[]; previous='0'*64
for index,reservation in enumerate(reservations):
    import hashlib
    source_sha='a'*40 if reservation['family_role']=='before' else 'b'*40
    api_run={'id':reservation['run_id'],'event':'pull_request','path':'.github/workflows/ci.yml','head_sha':source_sha,'created_at':reservation['created_at'],'status':'in_progress','conclusion':None,'repository':{'id':1207487684,'full_name':'szTheory/sigra'},'pull_requests':[{'number':331,'head':{'sha':source_sha,'repo':{'id':1207487684}},'base':{'sha':'base-ref','repo':{'id':1207487684}}}]}
    api_raw=json.dumps(api_run,sort_keys=True,separators=(',',':')).encode()
    row={'sequence':index,'previous_sha256':previous,**reservation,'head_sha':source_sha,'pull_request_head_sha':source_sha,'pull_request_number':331,'pull_request_base_sha':'base-ref','event':'pull_request','workflow_path':'.github/workflows/ci.yml','api_run_sha256':hashlib.sha256(api_raw).hexdigest(),'api_run_response_b64':base64.b64encode(api_raw).decode()}
    row['record_sha256']=hashlib.sha256(json.dumps(row,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    registrations.append(row); previous=row['record_sha256']
baseline_source=root/'baseline-source-bundle.tar.gz'; baseline_source.write_bytes(b'authenticated baseline bundle')
native_map={'schema_version':'sigra.browser-coverage-map/v1','rows':coverage_map_rows}
native_map_path=project/'scripts/ci/.comparison-test-map.json'
native_map_path.write_text(json.dumps(native_map,sort_keys=True,separators=(',',':')))
parity_path=project/'scripts/ci/.comparison-test-parity.json'
parity={'schema_version':'sigra.browser-parity-receipt/v1','status':'passed','owner_integration_status':'profiled','mapping_sha256':digest(native_map_path),'baseline_source_sha':'a'*40,'candidate_source_sha':'b'*40,'event':'pull_request','owners':[{'owner':owner,'status':'passed'} for owner in sorted({'admin_behavior','admin_checkpoints','design_gallery','non_admin_smoke','demo_showcase'})]}
parity_path.write_text(json.dumps(parity,sort_keys=True,separators=(',',':')))
contract={'status':'ready','pair_count':20,'primary_family_count':40,'family_reservations':reservations,'family_registrations':registrations,'comparison_schedule':schedule,'maximum_pair_start_gap_seconds':1800,'preparation_compatibility':{'baseline_cache_stratum':'warm','candidate_cache_stratum':'warm','runner_image_policy':'same'},'request_budget_ledger_id':'f'*64,'required_contexts':required,'window_duration_hours':48,'baseline_application_sha':'a'*40,'baseline_identity':{'source_bundle_sha256':hashlib.sha256(baseline_source.read_bytes()).hexdigest()},'baseline_workload_revision_sha256':'workload-sha','baseline_workflow_sha256':'base-workflow','candidate_identity':{'application_sha':'b'*40,'workflow_revision':'b'*40,'workload_revision_sha256':'workload-sha','workflow_file_sha256':'candidate-workflow'},'window':{'start_utc':'2026-10-13T10:00:00Z','end_utc':'2026-10-15T10:00:00Z'},'cache_stratum_allocation':[{'stratum_id':'warm','pair_count':20}],'native_coverage_comparison':{'mapping_path':'scripts/ci/.comparison-test-map.json','mapping_sha256':digest(native_map_path)},'instrumentation_overhead':{'exunit':{'status':'measured','value':7},'playwright':{'status':'unmeasured','reason':'not available'}}}
contract['native_coverage_comparison'].update({'parity_receipt_path':'scripts/ci/.comparison-test-parity.json','parity_receipt_sha256':digest(parity_path)})
(root/'registrations.json').write_text(json.dumps({'schema_version':'sigra.ci-comparison-registration/v1','contract_sha256':hashlib.sha256(json.dumps({k:v for k,v in contract.items() if k not in ('family_registrations','registration_ledger_sha256')},sort_keys=True,separators=(',',':')).encode()).hexdigest(),'records':registrations}))
contract.pop('family_registrations')
(root/'contract.json').write_text(json.dumps(contract))
empty={'schema_version':'sigra.ci-comparison-registration/v1','contract_sha256':hashlib.sha256(json.dumps({k:v for k,v in contract.items() if k not in ('family_registrations','registration_ledger_sha256')},sort_keys=True,separators=(',',':')).encode()).hexdigest(),'records':[]}
(root/'empty-registrations.json').write_text(json.dumps(empty))
PY
run_eval() { bash "$ROOT/scripts/ci/ci-run-metrics.sh" --evaluate-comparison --contract "$TMP/contract.json" --registrations "$TMP/registrations.json" --before-bundle "$TMP/before" --after-bundle "$TMP/after" --baseline-source-bundle "$TMP/baseline-source-bundle.tar.gz" --format json; }
run_perf_eval() { bash "$ROOT/scripts/ci/ci-run-metrics.sh" --evaluate-comparison --contract "$TMP/performance-contract.json" --before-bundle "$TMP/before" --after-bundle "$TMP/after" --baseline-source-bundle "$TMP/baseline-source-bundle.tar.gz" --format json; }
mkdir -p "$TMP/no-network-bin"
cat >"$TMP/no-network-bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >>"$GH_CALL_LOG"
printf '[]\n'
GH
chmod +x "$TMP/no-network-bin/gh"
python3 - "$TMP/contract.json" "$TMP/registrations.json" "$TMP/no-parity-contract.json" "$TMP/no-parity-registrations.json" <<'PY'
import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path('scripts/ci').resolve()))
from ci_metrics_security import comparison_contract_sha256
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
contract['native_coverage_comparison'].pop('parity_receipt_sha256')
pathlib.Path(sys.argv[3]).write_text(json.dumps(contract))
registrations=json.loads(pathlib.Path(sys.argv[2]).read_text())
registrations['contract_sha256']=comparison_contract_sha256(contract)
pathlib.Path(sys.argv[4]).write_text(json.dumps(registrations))
blocked=json.loads(pathlib.Path(sys.argv[1]).read_text())
receipt_path=pathlib.Path('scripts/ci/.comparison-test-blocked-parity.json')
receipt=json.loads(pathlib.Path('scripts/ci/.comparison-test-parity.json').read_text())
receipt['owner_integration_status']='blocked'
receipt_path.write_text(json.dumps(receipt,sort_keys=True,separators=(',',':')))
import hashlib
blocked['native_coverage_comparison']['parity_receipt_path']=receipt_path.as_posix()
blocked['native_coverage_comparison']['parity_receipt_sha256']=hashlib.sha256(receipt_path.read_bytes()).hexdigest()
pathlib.Path(sys.argv[1]).parent.joinpath('blocked-parity-contract.json').write_text(json.dumps(blocked))
registrations['contract_sha256']=comparison_contract_sha256(blocked)
pathlib.Path(sys.argv[1]).parent.joinpath('blocked-parity-registrations.json').write_text(json.dumps(registrations))
PY
set +e
GH_CALL_LOG="$TMP/no-parity-gh-calls" PATH="$TMP/no-network-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --collect-comparison --comparison-role before --contract "$TMP/no-parity-contract.json" --registrations "$TMP/no-parity-registrations.json" --request-budget-ledger "$TMP/no-parity-budget.json" --source-bundle "$TMP/no-parity-bundle" >"$TMP/no-parity.out" 2>"$TMP/no-parity.err"
no_parity_rc=$?
set -e
[[ $no_parity_rc -ne 0 ]] && rg -q 'native_coverage_map_missing_or_invalid_collection_blocked' "$TMP/no-parity.err" && [[ ! -s "$TMP/no-parity-gh-calls" ]] && [[ ! -e "$TMP/no-parity-bundle" ]]
set +e
GH_CALL_LOG="$TMP/blocked-parity-gh-calls" PATH="$TMP/no-network-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --collect-comparison --comparison-role before --contract "$TMP/blocked-parity-contract.json" --registrations "$TMP/blocked-parity-registrations.json" --request-budget-ledger "$TMP/blocked-parity-budget.json" --source-bundle "$TMP/blocked-parity-bundle" >"$TMP/blocked-parity.out" 2>"$TMP/blocked-parity.err"
blocked_parity_rc=$?
set -e
[[ $blocked_parity_rc -ne 0 ]] && rg -q 'native_coverage_map_missing_or_invalid_collection_blocked' "$TMP/blocked-parity.err" && [[ ! -s "$TMP/blocked-parity-gh-calls" ]] && [[ ! -e "$TMP/blocked-parity-bundle" ]]
set +e
GH_CALL_LOG="$TMP/gh-calls" PATH="$TMP/no-network-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --collect-comparison --comparison-role before --contract "$TMP/contract.json" --registrations "$TMP/empty-registrations.json" --request-budget-ledger "$TMP/request-budget.json" --source-bundle "$TMP/unregistered" >"$TMP/unregistered.out" 2>"$TMP/unregistered.err"
unregistered_rc=$?
set -e
[[ $unregistered_rc -ne 0 ]] && rg -q 'comparison_role_has_no_registered_runs' "$TMP/unregistered.err" && [[ ! -s "$TMP/gh-calls" ]]
PYTHONPATH="$ROOT/scripts/ci" python3 - "$TMP/contract.json" "$TMP/shared-budget.json" <<'PY'
import json,pathlib,sys
from ci_metrics_security import initialize_comparison_request_budget,comparison_request_budget_reserve
contract=json.loads(pathlib.Path(sys.argv[1]).read_text()); ledger=pathlib.Path(sys.argv[2])
import time
initialize_comparison_request_budget(contract,ledger,now=int(time.time()))
for index in range(599): comparison_request_budget_reserve(contract,ledger,f'/seed/{index}',owner='synthetic',now=int(time.time()))
PY
cat >"$TMP/no-network-bin/gh" <<'GH'
#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then echo 'gh version synthetic'; exit 0; fi
echo "$*" >>"$GH_CALL_LOG"
if [[ "${4:-}" == rate_limit ]]; then echo '{"resources":{"core":{"remaining":5000,"reset":1900000000}}}'; exit 0; fi
exit 99
GH
chmod +x "$TMP/no-network-bin/gh"
set +e
GH_CALL_LOG="$TMP/budget-gh-calls" PATH="$TMP/no-network-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --preflight --contract "$TMP/contract.json" --request-budget-ledger "$TMP/shared-budget.json" --preflight-output "$TMP/preflight.json" >"$TMP/preflight.out"
preflight_rc=$?
set -e
[[ $preflight_rc -eq 2 ]]
jq -e '.status=="blocked" and .request_count==1 and any(.missing_capabilities[]; contains("request_limit_exhausted"))' "$TMP/preflight.json" >/dev/null
[[ "$(wc -l <"$TMP/budget-gh-calls" | tr -d ' ')" == 1 ]]
python3 - "$TMP/shared-budget.json" <<'PY'
import json,pathlib,sys
data=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert sum(row.get('kind')=='request' for row in data['records'])==600
PY
run_eval >"$TMP/pass.json"
jq -e '.status=="pass" and .performance_verdict=="pass" and .metrics.native_parity.status=="passed" and .metrics.native_parity.origin_status=="passed" and (.metrics.native_parity.comparisons|length)==100 and .metrics.pair_count==20 and .metrics.comparable_successful_pairs==20 and .metrics.baseline_median_seconds==210.5 and .metrics.baseline_p95_seconds==219 and .metrics.candidate_median_seconds==105 and .metrics.candidate_p95_seconds==109 and .metrics.baseline_runner_seconds==1400 and .metrics.candidate_runner_seconds==900 and (.metrics.overhead_disclosure.playwright.status=="unmeasured")' "$TMP/pass.json" >/dev/null
cp -R "$TMP/before" "$TMP/before-original"
cp -R "$TMP/after" "$TMP/after-original"
cp "$TMP/contract.json" "$TMP/contract-original.json"
python3 - "$TMP/contract.json" "$TMP/performance-contract.json" <<'PY'
import json,pathlib,sys
data=json.loads(pathlib.Path(sys.argv[1]).read_text()); data['native_coverage_comparison']['mapping_sha256']='0'*64
pathlib.Path(sys.argv[2]).write_text(json.dumps(data))
PY
write_variant() {
  python3 - "$TMP/before" "$TMP/after" "$1" <<'PY'
import datetime,hashlib,json,pathlib,sys
before,after=map(pathlib.Path,sys.argv[1:3]); variant=sys.argv[3]
def read_time(value): return datetime.datetime.fromisoformat(value.replace('Z','+00:00'))
def write_bundle(bundle,role,pair,wait=None,runner_seconds=None):
    run_id=(1000 if role=='before' else 2000)+pair; family=bundle/'raw/families'/str(run_id)
    jobs_path=family/'jobs-attempt-2.json'; check_path=family/'check-runs.json'; manifest_path=family/'manifest.json'
    jobs=json.loads(jobs_path.read_text()); checks=json.loads(check_path.read_text()); manifest=json.loads(manifest_path.read_text())
    created=read_time(json.loads((family/'run.json').read_text())['created_at'])
    for job in jobs['jobs']:
        match=next(check for check in checks['check_runs'] if check['external_id']==str(job['id']))
        if wait is not None:
            end=created+datetime.timedelta(seconds=wait)
            job['completed_at']=end.isoformat().replace('+00:00','Z'); match['completed_at']=job['completed_at']
            start=end-datetime.timedelta(seconds=5 if role=='after' else 10)
            job['started_at']=start.isoformat().replace('+00:00','Z'); match['started_at']=job['started_at']
        duration=runner_seconds
        if duration is not None:
            start=read_time(job['completed_at'])-datetime.timedelta(seconds=duration)
            job['started_at']=start.isoformat().replace('+00:00','Z'); match['started_at']=job['started_at']
    jobs_path.write_text(json.dumps(jobs,sort_keys=True)); check_path.write_text(json.dumps(checks,sort_keys=True))
    manifest['attempt_jobs']['2']['sha256']=hashlib.sha256(jobs_path.read_bytes()).hexdigest()
    manifest['check_runs_sha256']=hashlib.sha256(check_path.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest,sort_keys=True))
if variant=='wait_median_miss':
    for pair in range(1,21): write_bundle(after,'after',pair,wait=200+pair)
elif variant=='p95_miss':
    write_bundle(after,'after',19,wait=300)
    write_bundle(after,'after',20,wait=301)
elif variant=='runner_miss': write_bundle(after,'after',20,runner_seconds=200)
elif variant=='equality':
    write_bundle(before,'before',11,wait=210)
    for pair in range(1,21): write_bundle(after,'after',pair,wait=int((200+pair)*.8))
else: raise SystemExit('unknown performance variant')
PY
}
write_variant wait_median_miss
run_perf_eval >"$TMP/wait-median-miss.json"
jq -e '.status=="insufficient_data" and .performance_verdict=="miss" and .metrics.candidate_median_seconds>.8*.metrics.baseline_median_seconds and .metrics.candidate_p95_seconds<=.metrics.baseline_p95_seconds and .metrics.candidate_runner_seconds<=.metrics.baseline_runner_seconds' "$TMP/wait-median-miss.json" >/dev/null
rm -rf "$TMP/before" "$TMP/after"; cp -R "$TMP/before-original" "$TMP/before"; cp -R "$TMP/after-original" "$TMP/after"
write_variant p95_miss
run_perf_eval >"$TMP/p95-miss.json"
jq -e '.performance_verdict=="miss" and .metrics.candidate_median_seconds<=.8*.metrics.baseline_median_seconds and .metrics.candidate_p95_seconds>.metrics.baseline_p95_seconds and .metrics.candidate_runner_seconds<=.metrics.baseline_runner_seconds' "$TMP/p95-miss.json" >/dev/null
rm -rf "$TMP/before" "$TMP/after"; cp -R "$TMP/before-original" "$TMP/before"; cp -R "$TMP/after-original" "$TMP/after"
write_variant runner_miss
run_perf_eval >"$TMP/runner-miss.json"
jq -e '.performance_verdict=="miss" and .metrics.candidate_median_seconds<=.8*.metrics.baseline_median_seconds and .metrics.candidate_p95_seconds<=.metrics.baseline_p95_seconds and .metrics.candidate_runner_seconds>.metrics.baseline_runner_seconds' "$TMP/runner-miss.json" >/dev/null
rm -rf "$TMP/before" "$TMP/after"; cp -R "$TMP/before-original" "$TMP/before"; cp -R "$TMP/after-original" "$TMP/after"
write_variant equality
run_perf_eval >"$TMP/threshold-equality.json"
jq -e '.performance_verdict=="pass" and .metrics.candidate_median_seconds==.8*.metrics.baseline_median_seconds and .metrics.candidate_p95_seconds<=.metrics.baseline_p95_seconds and .metrics.candidate_runner_seconds<=.metrics.baseline_runner_seconds' "$TMP/threshold-equality.json" >/dev/null
mv "$TMP/contract-original.json" "$TMP/contract.json"
printf 'substituted baseline' >"$TMP/baseline-source-bundle.tar.gz"
run_eval >"$TMP/baseline-bundle-mismatch.json"
jq -e '.status=="insufficient_data" and any(.diagnostics[];.reason=="baseline_source_bundle_hash_mismatch")' "$TMP/baseline-bundle-mismatch.json" >/dev/null
python3 - "$TMP/after/manifest.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d['comparison_families'][0]['run_id']=9999; p.write_text(json.dumps(d))
PY
run_eval >"$TMP/replaced-run.json"
jq -e '.status=="insufficient_data" and any(.diagnostics[];.reason=="comparison_family_api_origin_mismatch")' "$TMP/replaced-run.json" >/dev/null
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
python3 - "$TMP/register-contract.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); sha='a'*40
p.write_text(json.dumps({'status':'ready','baseline_application_sha':sha,'candidate_identity':{'application_sha':sha},'window':{'start_utc':'2026-10-12T10:00:00Z','end_utc':'2026-10-14T10:00:00Z'},'family_reservations':[{'reservation_id':'reserve-1','pair_id':'p1','family_role':'before'}]}))
PY
mkdir -p "$TMP/gh-bin"
cat >"$TMP/gh-bin/gh" <<'GH'
#!/usr/bin/env bash
case "${4:-}" in
  rate_limit) echo '{"resources":{"core":{"remaining":5000,"reset":1900000000}}}';;
  /repos/szTheory/sigra/actions/runs/777) echo '{"id":777,"event":"pull_request","path":".github/workflows/ci.yml","head_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":"2026-10-13T00:00:00Z","status":"queued","conclusion":null,"pull_requests":[{"number":331,"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"base":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}]}';;
  /repos/szTheory/sigra/actions/runs/778) cat "$PRODUCER_FIXTURE_DIR/run.json";;
  /repos/szTheory/sigra/commits/cccccccccccccccccccccccccccccccccccccccc) cat "$PRODUCER_FIXTURE_DIR/commit.json";;
  /repos/szTheory/sigra/git/trees/dddddddddddddddddddddddddddddddddddddddd\?recursive=1) cat "$PRODUCER_FIXTURE_DIR/tree.json";;
  /repos/szTheory/sigra/contents/.github/workflows/ci.yml\?ref=cccccccccccccccccccccccccccccccccccccccc) cat "$PRODUCER_FIXTURE_DIR/workflow-content.json";;
  *) exit 2;;
esac
GH
chmod +x "$TMP/gh-bin/gh"
PATH="$TMP/gh-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --register-comparison-run --contract "$TMP/register-contract.json" --registrations "$TMP/register-ledger.json" --reservation-id reserve-1 --run-id 777 >"$TMP/register-out.json"
jq -e '.status=="registered" and .run_id=="777"' "$TMP/register-out.json" >/dev/null
jq -e '.records as $r | ($r|length)==1 and $r[0].run_id==777 and $r[0].pull_request_number==331 and ($r[0]|has("conclusion")|not) and ($r[0].record_sha256|length)==64' "$TMP/register-ledger.json" >/dev/null
jq -e '.status=="complete" and .request_count==2' "$TMP/register-ledger.json.requests.json" >/dev/null
python3 - "$ROOT" "$TMP/contract.json" "$TMP/attempt-register-contract.json" "$TMP/attempt-register-ledger.json" "$TMP/attempt-request-budget.json" <<'PY'
import json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(sys.argv[1])/'scripts/ci'))
from ci_metrics_security import comparison_contract_sha256,initialize_comparison_request_budget
contract_path,out_path,ledger_path,budget_path=map(pathlib.Path,sys.argv[2:])
contract=json.loads(contract_path.read_text()); contract['sample_identity']='run_id+run_attempt'
contract['instrumentation_identity']={'exunit':'synthetic-exunit-v1','playwright':'synthetic-playwright-v1'}
for i,row in enumerate(contract['family_reservations']):
    row['run_id']=777 if i==0 else 10000+i
    row['run_attempt']=2 if i==0 else 1
out_path.write_text(json.dumps(contract,sort_keys=True))
ledger_path.write_text(json.dumps({'schema_version':'sigra.ci-comparison-registration/v1','contract_sha256':comparison_contract_sha256(contract),'records':[]}))
initialize_comparison_request_budget(contract,budget_path)
PY
cat >"$TMP/attempt-gh-bin-gh" <<'GH'
#!/usr/bin/env bash
case "${4:-}" in
  rate_limit) echo '{"resources":{"core":{"remaining":5000,"reset":1900000000}}}';;
  /repos/szTheory/sigra/actions/runs/777/attempts/2) echo '{"id":777,"run_attempt":2,"run_started_at":"2026-10-13T10:00:00Z","event":"pull_request","path":".github/workflows/ci.yml","head_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":"2026-10-12T08:00:00Z","status":"queued","conclusion":null,"pull_requests":[{"number":331,"head":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"base":{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}]}';;
  *) exit 2;;
esac
GH
chmod +x "$TMP/attempt-gh-bin-gh"
mkdir -p "$TMP/attempt-gh-bin"; cp "$TMP/attempt-gh-bin-gh" "$TMP/attempt-gh-bin/gh"
PATH="$TMP/attempt-gh-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --register-comparison-run --contract "$TMP/attempt-register-contract.json" --registrations "$TMP/attempt-register-ledger.json" --request-budget-ledger "$TMP/attempt-request-budget.json" --reservation-id r-pair-01-before --run-id 777 >"$TMP/attempt-register.out"
jq -e '.status=="registered" and .run_id=="777"' "$TMP/attempt-register.out" >/dev/null
jq -e '.records|length==1 and .[0].run_attempt==2 and .[0].attempt_origin_at=="2026-10-13T10:00:00Z" and .[0].created_at=="2026-10-12T08:00:00Z" and .[0].sample_id=="777-attempt-2"' "$TMP/attempt-register-ledger.json" >/dev/null
jq -e 'any(.records[];.endpoint=="/repos/szTheory/sigra/actions/runs/777/attempts/2")' "$TMP/attempt-request-budget.json" >/dev/null
mkdir -p "$TMP/producer-fixture"
python3 - "$TMP/producer-fixture" <<'PY'
import base64,hashlib,json,pathlib,sys
p=pathlib.Path(sys.argv[1]); a='a'*40; b='b'*40; c='c'*40; d='d'*40; content=b'name: fixture\n'
blob=hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
(p/'run.json').write_text(json.dumps({'id':778,'event':'pull_request','path':'.github/workflows/ci.yml','head_sha':a,'created_at':'2026-10-13T00:00:00Z','pull_requests':[{'number':331,'head':{'sha':a},'base':{'sha':b}}]}))
(p/'commit.json').write_text(json.dumps({'sha':c,'parents':[{'sha':a},{'sha':b}],'commit':{'tree':{'sha':d}}}))
(p/'tree.json').write_text(json.dumps({'sha':d,'tree':[{'path':'.github/workflows/ci.yml','type':'blob','sha':blob}]}))
(p/'workflow-content.json').write_text(json.dumps({'encoding':'base64','content':base64.b64encode(content).decode()}))
PY
PRODUCER_FIXTURE_DIR="$TMP/producer-fixture" PATH="$TMP/gh-bin:$PATH" bash "$ROOT/scripts/ci/ci-run-metrics.sh" --collect-producer-source --source-bundle "$TMP/producer-source" --producer-source-sha cccccccccccccccccccccccccccccccccccccccc --run-id 778 >"$TMP/producer-source.out"
jq -e '.validated==true and .producer_source_sha=="cccccccccccccccccccccccccccccccccccccccc" and .pull_request_number==331 and (.raw_sha256|has("raw/ci.yml"))' "$TMP/producer-source/manifest.json" >/dev/null
jq -e '.status=="complete" and .request_count==5' "$TMP/producer-source/request-ledger.json" >/dev/null
echo "ci-run-metrics-comparison.test: PASS"
