#!/usr/bin/env python3
"""Offline by default. --run requires approval of this exact committed bundle."""
import argparse,base64,importlib.util,json,os,pathlib,signal,subprocess,sys,tempfile,time
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
ROOT=g.ROOT

def save(p,d,exclusive=True):
 if exclusive:
  with p.open('x') as f:json.dump(d,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 else:
  t=p.with_suffix('.next');t.write_text(json.dumps(d,indent=2)+'\n');os.replace(t,p)
def load(p,n):
 s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def execute(cmd,state=None):
 limit=120 if state is None else max(1,int(state[state['stage']+'_started_epoch']+3600-time.time()))
 p=subprocess.Popen(list(map(str,cmd)),cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
 try:out,err=p.communicate(timeout=limit)
 except BaseException:
  os.killpg(p.pid,signal.SIGTERM)
  try:out,err=p.communicate(timeout=5)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);out,err=p.communicate()
  if state:save(B/('command-'+str(state.setdefault('commands',0)+1)+'.json'),dict(argv=list(map(str,cmd)),exit=p.returncode,stdout=out.decode(errors='replace'),stderr=err.decode(errors='replace'),interrupted=True))
  raise
 if state:
  state['commands']=state.get('commands',0)+1
  save(B/('command-'+str(state['commands'])+'.json'),dict(argv=list(map(str,cmd)),exit=p.returncode,stdout=out.decode(errors='replace'),stderr=err.decode(errors='replace')))
 g.require(p.returncode==0,'command failed: '+str(cmd[1])+': '+err.decode(errors='replace')[-1500:])
 return out

def import_pack(directory):
 os.environ.update(GIT_OBJECT_DIRECTORY=str(directory),GIT_ALTERNATE_OBJECT_DIRECTORIES=str(ROOT/'.git/objects'),PYTHONDONTWRITEBYTECODE='1')
 subprocess.run(['git','-C',str(ROOT),'index-pack','--stdin'],input=(B/'objects.pack').read_bytes(),check=True,stdout=subprocess.DEVNULL)

def self_check():
 b,digest=g.verify_bundle()
 execute([sys.executable,'-B',B/'check.py'])
 # This is the real shell entry point, with the real sibling imports. No collector starts.
 with tempfile.TemporaryDirectory(prefix='253-paired-check-') as td:
  t=pathlib.Path(td);objects=t/'objects';objects.mkdir();previous=dict(os.environ)
  try:
   import_pack(objects)
   fr=g.read(B/'pr-freeze-template.json');fr['source']['publication_receipt_sha256']='0'*64;fr['source']['fetched_main_sha']=b['parent_sha'];fr['bound_documents']=g.bindings();fr['freeze_sha256']=g.sha(g.canonical(fr));p=t/'offline-freeze.json';p.write_text(json.dumps(fr))
   execute(['bash',B/'runtime/ci-pr-proof.sh','--check-only','--freeze',p])
   execute(['bash',B/'runtime/ci-pr-proof.sh','--main-preflight','--freeze',p,'--current-main',b['parent_sha'],'--output',t/'main-preflight.json','--repo-root',ROOT])
  finally:os.environ.clear();os.environ.update(previous)
 # Keep the actual old identities. The new runtime is scoped to the new refs.
 execute([sys.executable,'-B',ROOT/'.planning/execution/253-172-pr341-maintenance/offline-verifier/ci-hosted-gate-verify.py','--mode','canary','--scenario','matrix','--evidence',ROOT/'.planning/execution/253-proof-bundle-a6838a8f9/canary-evidence.json'])
 return dict(status='paired_bundle_verified_offline',bundle_sha256=digest,network_requests=0,ci_launches=0,approval_received=(B/'live-approval.json').exists())

def activate(stage,state):
 a=g.read(B/(stage+'-allocation-template.json'));a['source_sha256']=g.sha((B/('bundle.json' if stage=='publication' else 'pr-freeze.json')).read_bytes());a['bound_documents']=g.bindings();save(B/(stage+'-allocation.json'),a)
 state.update(stage=stage);state[stage+'_started_epoch']=int(time.time());state[stage+'_allocation_sha256']=g.sha((B/(stage+'-allocation.json')).read_bytes());save(B/'run-state.json',state,False)

def request(stage,request,state,expected=200):
 l=B/(stage+'-ledger.json');n=len(g.read(l)['transactions']) if l.exists() else 0;prefix=stage+'-request-'+str(n+1)
 rq,rc,body=[B/(prefix+suffix) for suffix in ['.json','-receipt.json','-body.json']];save(rq,request)
 execute([sys.executable,'-B',B/'runtime/ci-hosted-transport.py','--allocation',B/(stage+'-allocation.json'),'--ledger',l,'--request',rq,'--output',rc,'--body-output',body],state)
 receipt=g.read(rc);g.require(receipt['actual_status']==expected,'unexpected HTTP '+str(receipt['actual_status']));return g.read(body)
def subset(expected,actual):
 if isinstance(expected,dict):return isinstance(actual,dict) and all(k in actual and subset(v,actual[k]) for k,v in expected.items())
 if isinstance(expected,list):return isinstance(actual,list) and len(expected)==len(actual) and all(subset(e,a) for e,a in zip(expected,actual))
 return expected==actual

def run():
 for k in os.environ:g.require(not k.startswith('SIGRA_CANARY_TEST_') and k not in ('PYTHONPATH','SIGRA_LIVE_POLICY_SHIM','GIT_DIR','GIT_WORK_TREE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES'),'test/Git environment override forbidden')
 bundle,approval=g.approval();g.require_unused_attempt();self_check()
 state=dict(status='active',stage='publication',bundle_sha256=g.sha((B/'bundle.json').read_bytes()),approval_sha256=g.sha((B/'live-approval.json').read_bytes()),started_epoch=int(time.time()))
 save(B/'run-state.json',state)
 try:
  # The isolated object store remains alive until all collectors finish; no Git fetch or push.
  with tempfile.TemporaryDirectory(prefix='253-paired-live-') as td:
   obj=pathlib.Path(td)/'objects';obj.mkdir();import_pack(obj);activate('publication',state)
   def pre(route,params=None):return {k:v for k,v in dict(method='GET',route_id=route,category='preflight',params=params).items() if v is not None}
   rate=request('publication',pre('rate_limit'),state);g.require(rate['resources']['core']['remaining']>250,'API core <=250; wait for reset')
   main=request('publication',pre('get_ref',{'branch':'main'}),state);g.require(main['object']['sha']==bundle['parent_sha'],'main changed; halt before writes')
   for ref in g.read(B/'objects.json')['refs']:request('publication',pre('get_ref',{'branch':ref}),state,404)
   for item in g.read(B/'candidate-requests.json'):
    actual=request('publication',item['request'],state,item['expect']);g.require(subset(item['expected'],actual),'server object readback differs from frozen candidate')
   ledger=B/'publication-ledger.json'
   save(B/'publication-receipt.json',dict(schema='sigra.phase253.paired-candidate-publication/v1',mode='live',candidate_sha=bundle['candidate_sha'],parent_sha=bundle['parent_sha'],ledger_sha256=g.sha(ledger.read_bytes()),allocation_sha256=g.sha((B/'publication-allocation.json').read_bytes()),complete=True))
   fr=g.read(B/'pr-freeze-template.json');fr['source']['publication_receipt_sha256']=g.sha((B/'publication-receipt.json').read_bytes());fr['source']['fetched_main_sha']=bundle['parent_sha'];fr['bound_documents']=g.bindings();fr['freeze_sha256']=g.sha(g.canonical(fr));save(B/'pr-freeze.json',fr)
   state['publication_closed_epoch']=int(time.time());activate('prs',state)
   for route,params in [('rate_limit',None),('get_ref',{'branch':'main'})]:
    data=request('prs',{k:v for k,v in dict(method='GET',route_id=route,category='preflight',family='shared',params=params).items() if v is not None},state)
    if route=='rate_limit':g.require(data['resources']['core']['remaining']>250,'API core <=250; wait for reset')
    else:g.require(data['object']['sha']==bundle['parent_sha'],'main moved before PRs')
   execute(['bash',B/'runtime/ci-pr-proof.sh','--main-preflight','--freeze',B/'pr-freeze.json','--current-main',bundle['parent_sha'],'--output',B/'main-preflight.json','--repo-root',ROOT],state)
   for family in ['normal','docs-only']:
    cmd=['bash',B/'runtime/ci-pr-proof.sh','--family',family,'--freeze',B/'pr-freeze.json','--allocation',B/'prs-allocation.json','--requests',B/'prs-ledger.json','--repo-root',ROOT,'--revision-freeze',B/'actions.json','--action-approval',B/'prs-approval.json','--evidence',B/(family+'-evidence.json')]
    cmd+=['--main-preflight',B/'main-preflight.json'] if family=='normal' else ['--docs-publication-receipt',B/'docs-publication-receipt.json']
    execute(cmd,state);execute([sys.executable,'-B',B/'runtime/ci-hosted-gate-verify.py','--mode','pr','--family',family,'--evidence',B/(family+'-evidence.json')],state)
   execute([sys.executable,'-B',B/'verify_pair.py','--write-result'],state);state['status']='verified_hosted'
 except BaseException as e:state.update(status='halted',stop=str(e));raise
 finally:
  state.update(stage='closed',completed_epoch=int(time.time()));save(B/'run-state.json',state,False)
  save(B/'attempt-result.json',dict(state=state,reruns=0,artifacts={p.name:g.sha(p.read_bytes()) for p in B.iterdir() if p.is_file() and (p.name.endswith('-ledger.json') or p.name.endswith('-evidence.json') or p.name.endswith('-receipt.json'))}))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');p.add_argument('--self-check',action='store_true');a=p.parse_args()
 try:
  if a.run:run()
  else:print(json.dumps(self_check()))
 except (g.Refusal,OSError,ValueError,KeyError,subprocess.SubprocessError) as e:print('STOP: '+str(e),file=sys.stderr);sys.exit(1)
