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
    source_sha='base-app' if reservation['family_role']=='before' else 'candidate-app'
    row={'sequence':index,'previous_sha256':previous,**reservation,'head_sha':source_sha,'pull_request_head_sha':source_sha,'api_run_sha256':'f'*64}
    row['record_sha256']=hashlib.sha256(json.dumps(row,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    registrations.append(row); previous=row['record_sha256']
contract={'status':'ready','pair_count':20,'primary_family_count':40,'family_reservations':reservations,'family_registrations':registrations,'window_duration_hours':48,'baseline_application_sha':'base-app','baseline_workload_revision_sha256':'workload-sha','baseline_workflow_sha256':'base-workflow','candidate_identity':{'application_sha':'candidate-app','workflow_revision':'candidate-app','workload_revision_sha256':'workload-sha','workflow_file_sha256':'candidate-workflow'},'window':{'start_utc':'2026-10-13T10:00:00Z','end_utc':'2026-10-15T10:00:00Z'},'cache_stratum_allocation':[{'stratum_id':'warm','pair_count':20}],'instrumentation_overhead':{'exunit':{'status':'measured','value':7},'playwright':{'status':'unmeasured','reason':'not available'}}}
(root/'registrations.json').write_text(json.dumps({'schema_version':'sigra.ci-comparison-registration/v1','contract_sha256':hashlib.sha256(json.dumps({k:v for k,v in contract.items() if k not in ('family_registrations','registration_ledger_sha256')},sort_keys=True,separators=(',',':')).encode()).hexdigest(),'records':registrations}))
contract.pop('family_registrations')
(root/'contract.json').write_text(json.dumps(contract))
PY
run_eval() { bash "$ROOT/scripts/ci/ci-run-metrics.sh" --evaluate-comparison --contract "$TMP/contract.json" --registrations "$TMP/registrations.json" --before-bundle "$TMP/before" --after-bundle "$TMP/after" --format json; }
run_eval >"$TMP/pass.json"
jq -e '.status=="pass" and .metrics.pair_count==20 and .metrics.comparable_successful_pairs==20 and .metrics.baseline_median_seconds==10.5 and .metrics.baseline_p95_seconds==19 and .metrics.candidate_median_seconds==5.25 and .metrics.candidate_p95_seconds==9.5 and .metrics.baseline_runner_seconds==200 and .metrics.candidate_runner_seconds==200 and (.metrics.overhead_disclosure.playwright.status=="unmeasured")' "$TMP/pass.json" >/dev/null
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
