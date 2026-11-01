"""Offline closeout of approved, separate windows; never joins or reopens their ledgers."""
import base64,copy,hashlib,json,pathlib,re,subprocess,sys,types,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
B=ROOT/'.planning/execution/253-pr343-remaining-evidence'
OLD=ROOT/'.planning/execution/253-pr343-recovery'
def read(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def need(ok,message):
 if not ok:raise ValueError(message)
def module(path,name):
 m=types.ModuleType(name);m.__file__=str(path);exec(compile(path.read_bytes(),str(path),'exec'),m.__dict__);return m
sys.path.insert(0,str(B/'runtime'))
v=module(B/'runtime/ci-hosted-gate-verify.py','independent_docs_verifier')
freeze=read(B/'pr-freeze.json');docs=read(B/'docs-only-evidence.json');captured={}
docs_result=v.verify_pr_family(docs,'docs-only',captured)
need(docs_result['accepted_live'] is True,'docs evidence is synthetic or rejected')
need(docs['freeze']==freeze,'docs/normal source freezes differ')
publication=ROOT/'.planning/execution/253-plan172-persistent-ledger/publication-receipt.json'
need(digest(publication)==freeze['source']['publication_receipt_sha256'],'candidate publication receipt changed')
snapshot=read(OLD/'ledger.json');snapshot['mode']='live'
sv=module(OLD/'verify.py','independent_normal_snapshot');normal_snapshot=sv.verify(snapshot)
need(normal_snapshot==read(OLD/'result.json') and normal_snapshot['conclusion']=='success','normal snapshot changed or unsuccessful')
rows=snapshot['transactions'];body=lambda tx:json.loads(base64.b64decode(tx['response_body_base64'],validate=True))
normal_pr=body(rows[6]);need(normal_pr['head']['sha']==freeze['normal']['head_sha'] and normal_pr['base']['sha']==freeze['source']['fetched_main_sha'],'normal source differs from exact shared freeze')
jobs=body(rows[4])['jobs'];checks=body(rows[2])['check_runs']
def check_normal(jobs,checks):
 names=(*v.REQUIRED_NAMES,v.CLASSIFIER_JOB,*[f'Example Playwright shard ({s})' for s in v.SEAMS],'ci-gate')
 for name in names:
  owners=[j for j in jobs if j['name']==name];need(len(owners)==1 and owners[0]['status']=='completed' and owners[0]['conclusion']=='success','normal job missing or unsuccessful: '+name)
 shards=[j for j in jobs if j['name'].startswith('Library tests shard')];need(shards and all(j['conclusion']=='success' for j in shards),'normal library owner missing/unsuccessful')
 for name in (*v.REQUIRED_NAMES,'ci-gate'):
  native=[c for c in checks if c['name']==name];owner=next(j for j in jobs if j['name']==name)
  need(len(native)==1,'native required check missing or duplicated: '+name);c=native[0]
  need(c['head_sha']==freeze['normal']['head_sha'] and c['status']=='completed' and c['conclusion']=='success' and c['app']['id']==15368,'native check source/status/app changed: '+name)
  need(c['details_url']==f"https://github.com/szTheory/sigra/actions/runs/39815188159/job/{owner['id']}",'native check is from another run/job')
check_normal(jobs,checks)
# Negative development copies never overwrite original evidence.
for kind in ('missing-job','skipped-check','wrong-source'):
 js,cs=copy.deepcopy(jobs),copy.deepcopy(checks);name=v.REQUIRED_NAMES[0]
 if kind=='missing-job':js=[j for j in js if j['name']!=name]
 else:
  c=next(c for c in cs if c['name']==name);c['conclusion' if kind=='skipped-check' else 'head_sha']='skipped' if kind=='skipped-check' else '0'*40
 try:check_normal(js,cs)
 except ValueError:pass
 else:raise AssertionError('negative development copy accepted: '+kind)
workflow=(B/'normal-workflow.yml').read_bytes();v.verify_docs_workflow_relation(workflow,captured['workflow_bytes'])
need(v.git_blob_sha(workflow)==freeze['normal']['workflow_blob'],'normal workflow source changed')
producers={}
proposal=read(B/'proposal.json');runner=module(B/'run.py','closed_collection_helpers')
for spec in proposal['browser_artifacts']:
 path=B/f"artifact-{spec['id']}.zip";raw=path.read_bytes();need('sha256:'+hashlib.sha256(raw).hexdigest()==spec['digest'] and len(raw)==spec['size_in_bytes'],'normal ZIP digest/size changed')
 producers[spec['name']]=v.validate_producer_zip(raw)
normal=proposal['existing_normal_pr'];identity={'run_id':str(normal['run_id']),'run_attempt':'1','source_sha':normal['tested_merge_sha'],'event':'pull_request','workflow_ref':'szTheory/sigra/.github/workflows/ci.yml@refs/pull/343/merge','workflow_sha':normal['tested_merge_sha'],'classifier_result':'success','docs_only':'false'}
policy=v._run_browser_policy(workflow,producers,identity);need(policy['status']=='passed','normal browser records rejected')
# Project the measured rules and normal checks for the check-name policy only.
# The source windows stay separate; this view is not saved as a new HTTP ledger.
projection=dict(docs,transport_ledger={'transactions':docs['transport_ledger']['transactions']+[rows[2]]})
allocation,_=v.verify_pr_transport(docs)
view=v._view_for_checks(projection,'normal',allocation,normal_pr['head']['sha'],rows[2]);v.hydrate_effective_checks(view);v.verify_effective_checks(view)
state=read(B/'run-state.json');need(state['closed'] and state['status']=='collected-and-independently-verified','approved collection did not close successfully')
ledger=read(B/'ledger.json');need(not ledger['terminal_stop'] and len(ledger['transactions'])==56,'closed ledger changed')
need(digest(B/'ledger.json')==read(B/'attempt-result.json')['ledger_sha256'],'closed ledger digest changed')
inputs=[OLD/'ledger.json',OLD/'result.json',B/'ledger.json',B/'docs-only-evidence.json',B/'proposal.json',B/'approval.json',B/'manifest.json',publication,B/'normal-workflow.yml',B/'runtime/ci-hosted-gate-verify.py',pathlib.Path(__file__).resolve()]
print(json.dumps(dict(schema='sigra.phase253.approved-components-closeout/v1',status='approved_collection_verified',normal_pr=343,normal_run_id=39815188159,normal_attempt=1,normal_browser_groups=5,normal_required_checks='five required checks and ci-gate succeeded; linked to actual attempt jobs',docs=docs_result,requests_this_continuation=56,request_limit=70,seconds=state['closed_epoch']-state['started_epoch'],docs_prs_created=1,ci_runs_created=1,negative_development_checks=3,ledger_windows_kept_separate=True,original_pair_single_ledger_verifier_not_claimed=True,original_registration_failure_reproduced=False,CIREL_01='partial_not_reproduced',CIREL_02='hosted_components_verified_pending_phase_verification',phase_verified=False,inputs={str(p.relative_to(ROOT)):digest(p) for p in inputs}),indent=2))
