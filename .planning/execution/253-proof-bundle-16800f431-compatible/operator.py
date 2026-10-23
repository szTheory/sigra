#!/usr/bin/env python3
"""Default: offline self-check. --run is once-only and requires newly committed approvals."""
import argparse,hashlib,importlib.util,json,os,pathlib,signal,subprocess as sp,sys,tempfile,time
B=pathlib.Path(__file__).resolve().parent; ROOT=B.parents[2];sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
PYTHON=sys.executable

def save(path,value,exclusive=False):
 raw=json.dumps(value,indent=2)+'\n'
 if exclusive:
  with path.open('x') as f:f.write(raw);f.flush();os.fsync(f.fileno())
 else:
  tmp=path.with_suffix(path.suffix+'.next');tmp.write_text(raw);os.replace(tmp,path)
def loadmod(path,name):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def restore_objects(live=False):
 objects=pathlib.Path(tempfile.mkdtemp(prefix='253-proof-live-objects-'))/'objects';objects.mkdir()
 origin=pathlib.Path(g.git('rev-parse','--absolute-git-dir').decode().strip())/'objects'
 if live:
  os.environ.pop('GIT_OBJECT_DIRECTORY',None);os.environ.pop('GIT_ALTERNATE_OBJECT_DIRECTORIES',None)
 else:os.environ.update(GIT_OBJECT_DIRECTORY=str(objects),GIT_ALTERNATE_OBJECT_DIRECTORIES=str(origin))
 os.environ['PYTHONDONTWRITEBYTECODE']='1'
 sp.run(['git','-C',str(ROOT),'index-pack','--stdin'],input=(B/'objects.pack').read_bytes(),check=True,stdout=sp.DEVNULL)
 return objects

def execute(args,state=None,capture=False):
 # Whole-process deadlines stop children as well as the watcher. No detached or duplicate watchers.
 limit=120
 if state and state.get('stage') in ('canary','prs'):
  limit=int(state[state['stage']+'_started_epoch']+3600-time.time());g.require(limit>0,'window expired before command')
 env={k:v for k,v in os.environ.items() if not k.startswith('SIGRA_CANARY_TEST_') and k not in ('PYTHONPATH','SIGRA_LIVE_POLICY_SHIM','GIT_DIR','GIT_WORK_TREE')}
 p=sp.Popen([str(v) for v in args],cwd=ROOT,env=env,stdout=sp.PIPE,stderr=sp.PIPE,start_new_session=True)
 try:
  out,err=p.communicate(timeout=limit)
 except BaseException as failure:
  os.killpg(p.pid,signal.SIGTERM)
  try:out,err=p.communicate(timeout=5)
  except sp.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);out,err=p.communicate()
  if state is not None:
   n=state.get("command_count",0)+1;state["command_count"]=n
   save(B/("command-"+str(n)+".json"),dict(argv=[str(v) for v in args],exit=p.returncode,exception=str(failure),stdout=(out or b"").decode("utf-8","replace"),stderr=(err or b"").decode("utf-8","replace")),True)
  raise
 if state is not None:
  n=state.get('command_count',0)+1;state['command_count']=n
  save(B/('command-'+str(n)+'.json'),dict(argv=[str(v) for v in args],exit=p.returncode,stdout=(out or b'').decode('utf-8','replace'),stderr=(err or b'').decode('utf-8','replace')),True)
 if not capture:
  if out:sys.stdout.buffer.write(out);sys.stdout.flush()
  if err:sys.stderr.buffer.write(err);sys.stderr.flush()
 if p.returncode:raise g.Refusal('command failed with exit '+str(p.returncode)+': '+str(args[0])+' '+str(args[1:3]))
 return out if capture else None

def paths(stage):return B/(stage+'-allocation.json'),B/(stage+'-ledger.json')
def request(stage,category,route,params=None,state=None):
 a,l=paths(stage);n=len(g.read(l).get('transactions',[])) if l.exists() else 0
 rq=B/(stage+'-operator-request-'+str(n+1)+'.json');rc=B/(stage+'-operator-receipt-'+str(n+1)+'.json');body=B/(stage+'-operator-body-'+str(n+1)+'.json')
 d=dict(method='GET',route_id=route,category=category)
 if params:d['params']=params
 save(rq,d,True)
 execute([PYTHON,B/'runtime/ci-hosted-transport.py','--allocation',a,'--ledger',l,'--request',rq,'--output',rc,'--body-output',body],state)
 receipt=g.read(rc); status=receipt['actual_status'];g.require(status in (200,404),'unexpected HTTP '+str(status))
 return status,g.read(body)

def activate(stage,state,freeze):
 a,l=paths(stage);g.require(not a.exists() and not l.exists(),'window already allocated')
 t=g.read(B/'allocation-templates.json')['allocations'][stage]
 if stage=='canary':
  t['source_sha256']=g.sha((B/'canary-freeze.json').read_bytes());t['bound_documents']=[dict(path=str((B/name).relative_to(ROOT)),sha256=g.sha((B/name).read_bytes())) for name in ['bundle.json','canary-freeze.json','publication.json']]
 else:t['source_sha256']=g.sha(freeze.read_bytes());t['bound_documents']=g.read(freeze)['bound_documents']
 save(a,t,True);state.update(stage=stage);state[stage+'_allocation_sha256']=g.sha(a.read_bytes());state[stage+'_started_epoch']=int(time.time());save(B/'run-state.json',state)

def canary_commands():
 live=['--revision-freeze',B/'canary-freeze.json','--action-approval',B/'canary-approval.json','--http-allocation',B/'canary-allocation.json','--requests',B/'canary-ledger.json','--evidence',B/'canary-evidence.json','--publication-receipt',B/'publication-receipt.json']
 return [(['bash',B/'runtime/ci-gate-canary.sh','--publish-only',*live]),([PYTHON,B/'runtime/ci-git-publication.py','--verify-publication',B/'publication-receipt.json','--require-live-origin']),(['bash',B/'runtime/ci-gate-canary.sh','--scenario','full-pass',*live]),([PYTHON,B/'runtime/ci-hosted-gate-verify.py','--mode','canary','--scenario','full-pass','--evidence',B/'canary-evidence.json']),(['bash',B/'runtime/ci-gate-canary.sh','--remaining-scenarios',*live]),([PYTHON,B/'runtime/ci-hosted-gate-verify.py','--mode','canary','--scenario','sources','--evidence',B/'canary-evidence.json']),([PYTHON,B/'runtime/ci-hosted-gate-verify.py','--mode','canary','--scenario','matrix','--evidence',B/'canary-evidence.json'])]

def self_check():
 bundle,digest=g.verify_bundle();restore_objects();pub=loadmod(B/'runtime/ci-git-publication.py','bundle_publisher')
 pub.check_revision_freeze(B/'canary-freeze.json',ROOT)
 execute(['bash',B/'runtime/ci-gate-canary.sh','--check-only','--revision-freeze',B/'canary-freeze.json'])
 for section in ['canary','docs_and_prs']:pub.section_sha256(g.read(B/'canary-freeze.json'),section)
 print(json.dumps(dict(status='offline_bundle_verified',bundle_sha256=digest,source=g.SOURCE,approval_received=(B/'live-approval.json').exists(),network_requests=0)))

def run():
 bundle,approval=g.approval()
 for key in os.environ:g.require(not key.startswith('SIGRA_CANARY_TEST_') and key not in ('PYTHONPATH','SIGRA_LIVE_POLICY_SHIM','GIT_DIR','GIT_WORK_TREE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES'),'test or Git environment override present')
 for section in ['canary','docs_and_prs']:
  p=B/('canary-approval.json' if section=='canary' else 'prs-approval.json');g.committed(p)
  pub=loadmod(B/'runtime/ci-git-publication.py','approval_publisher');pub.check_section_approval(p,g.read(B/'canary-freeze.json'),section,ROOT)
 g.require(not (B/'run-state.json').exists(),'attempt already started; never resume a closed window')
 state=dict(schema='sigra.phase253.proof-run/v1',status='active',stage='pre_fetch',source_sha=g.SOURCE,bundle_sha256=g.sha((B/'bundle.json').read_bytes()),approval_sha256=g.sha((B/'live-approval.json').read_bytes()),expected_parent=bundle['parent_sha'],started_epoch=int(time.time()))
 save(B/'run-state.json',state,True)
 try:
  restore_objects(live=True)
  # Exactly one Git fetch, only after approval; network operation is retained separately from measured REST windows.
  execute(['git','fetch','--no-tags','origin','main'],state)
  fetched=g.git('rev-parse','refs/remotes/origin/main').decode().strip();g.require(fetched==bundle['parent_sha'],'main changed; stop before publication')
  pub=loadmod(B/'runtime/ci-git-publication.py','live_publisher');merge=pub.merge_preflight(ROOT,g.read(B/'canary-freeze.json')['identity']['candidate_helper_commit'],fetched);g.require(merge['clean'],'candidate merge conflict')
  state['parent_verified']=fetched;state['merge_preflight']=merge;save(B/'run-state.json',state)
  activate('canary',state,B/'canary-freeze.json')
  status,rate=request('canary','preflight','rate_limit',state=state);g.require(status==200 and rate['resources']['core']['remaining']>250,'API core budget <=250; wait for reset')
  for ref in bundle['refs']:
   status,_=request('canary','preflight','get_ref',dict(branch=ref.removeprefix('refs/heads/')),state);g.require(status==404,'proposed ref already exists; never overwrite')
  for command in canary_commands():execute(command,state)
  state['canary_verified']=True;save(B/'run-state.json',state)
  # PR freeze derives from the *actual* newly verified live publication receipt, never a fixture receipt.
  fr=B/'pr-freeze.json';g.require(not fr.exists(),'PR freeze already exists')
  execute(['bash',B/'runtime/ci-pr-proof.sh','--prepare','--publication',B/'publication-receipt.json','--manifest',B/'publication.json','--output',fr,'--repo-root',ROOT,'--poll-interval','60','--require-live-origin','--bound-document',B/'bundle.json'])
  activate('prs',state,fr)
  status,rate=request('prs','preflight','rate_limit',state=state);g.require(status==200 and rate['resources']['core']['remaining']>250,'API core budget <=250; wait for reset')
  status,current=request('prs','preflight','get_ref',dict(branch='main'),state);g.require(status==200 and current['object']['sha']==fetched,'main moved before PR proof')
  common=['--freeze',fr,'--allocation',B/'prs-allocation.json','--requests',B/'prs-ledger.json','--repo-root',ROOT,'--revision-freeze',B/'canary-freeze.json','--action-approval',B/'prs-approval.json']
  for family in ['normal','docs-only']:
   evidence=B/(family+'-evidence.json');extra=['--docs-publication-receipt',B/'docs-publication-receipt.json'] if family=='docs-only' else []
   execute(['bash',B/'runtime/ci-pr-proof.sh','--family',family,*common,'--evidence',evidence,*extra],state)
   execute([PYTHON,B/'runtime/ci-hosted-gate-verify.py','--mode','pr','--family',family,'--evidence',evidence],state)
  execute([PYTHON,B/'runtime/ci-hosted-gate-verify.py','--mode','pr','--family','both','--evidence',B/'normal-evidence.json','--docs-evidence',B/'docs-only-evidence.json'],state)
  state.update(status='verified_hosted',stage='closed',completed_epoch=int(time.time()))
 except BaseException as e:
  state.update(status='halted',stage='closed',stop=str(e),completed_epoch=int(time.time()));raise
 finally:
  save(B/'run-state.json',state)
  # Durable diagnostics bind every retained attempt file, even if publication or collection stopped early.
  actual={p.name:g.sha(p.read_bytes()) for p in B.iterdir() if p.is_file() and (p.name.endswith('-ledger.json') or p.name.endswith('-evidence.json') or p.name.endswith('-allocation.json') or p.name.endswith('-receipt.json'))}
  save(B/'attempt-result.json',dict(state=state,artifacts=actual,historical_windows_changed=False,reruns=0))

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--self-check',action='store_true');parser.add_argument('--run',action='store_true');args=parser.parse_args()
 try:
  if args.run:run()
  else:self_check()
 except (g.Refusal,OSError,ValueError,KeyError,sp.CalledProcessError,sp.TimeoutExpired) as e:print('STOP: '+str(e),file=sys.stderr);sys.exit(1)
