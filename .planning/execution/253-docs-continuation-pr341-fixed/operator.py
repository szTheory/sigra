#!/usr/bin/env python3
"""Default offline check; --run is a new, once-only docs window after approval."""
import argparse,importlib.util,json,os,pathlib,signal,subprocess,sys,time
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
ROOT=g.ROOT;OLD=g.OLD

def save(path,value):
 with path.open('x') as f:json.dump(value,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
def update(path,value):
 p=path.with_suffix('.next');p.write_text(json.dumps(value,indent=2)+'\n');os.replace(p,path)
def verify_inputs():
 bundle,digest=g.verify_bundle()
 spec=importlib.util.spec_from_file_location('docs_publisher',B/'runtime/ci-git-publication.py');publisher=importlib.util.module_from_spec(spec);spec.loader.exec_module(publisher)
 publisher.check_revision_freeze(OLD/'canary-freeze.json',ROOT)
 for mode,args in [('canary',['--scenario','matrix','--evidence',OLD/'canary-evidence.json']),('pr',['--family','normal','--evidence',OLD/'normal-evidence.json'])]:
  subprocess.run([sys.executable,'-B',str(B/'runtime/ci-hosted-gate-verify.py'),'--mode',mode,*map(str,args)],check=True,stdout=subprocess.DEVNULL,cwd=ROOT)
 subprocess.run([sys.executable,'-B',str(B/'test_continuation.py'),'Guards.test_actual_shell_startup_reproduces_old_import_failure_and_reaches_new_guard'],check=True)
 return bundle,digest

def run():
 for key in os.environ:g.require(not key.startswith('SIGRA_CANARY_TEST_') and key not in ('PYTHONPATH','SIGRA_LIVE_POLICY_SHIM','GIT_DIR','GIT_WORK_TREE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES'),'test or Git environment override present')
 bundle,a=g.approval();verify_inputs();g.require(not (B/'run-state.json').exists(),'attempt already started; never restart')
 s=dict(status='active',stage='docs-only',started_epoch=int(time.time()),bundle_sha256=g.sha((B/'bundle.json').read_bytes()),approval_sha256=g.sha((B/'live-approval.json').read_bytes()))
 save(B/'run-state.json',s)
 try:
  save(B/'allocation.json',g.read(B/'allocation-template.json'));s['allocation_sha256']=g.sha((B/'allocation.json').read_bytes());update(B/'run-state.json',s)
  # A fresh rate read is charged before collection. No fetch, publication or CI dispatch.
  save(B/'rate-request.json',dict(method='GET',route_id='rate_limit',category='preflight',family='shared'))
  commands=[
   [sys.executable,'-B',B/'runtime/ci-hosted-transport.py','--allocation',B/'allocation.json','--ledger',B/'ledger.json','--request',B/'rate-request.json','--output',B/'rate-receipt.json','--body-output',B/'rate-body.json'],
   ['bash',B/'runtime/ci-pr-proof.sh','--family','docs-only','--freeze',B/'pr-freeze.json','--allocation',B/'allocation.json','--requests',B/'ledger.json','--repo-root',ROOT,'--revision-freeze',OLD/'canary-freeze.json','--action-approval',B/'prs-approval.json','--evidence',B/'docs-only-evidence.json','--docs-publication-receipt',B/'docs-publication-receipt.json'],
   [sys.executable,'-B',B/'runtime/ci-hosted-gate-verify.py','--mode','pr','--family','docs-only','--evidence',B/'docs-only-evidence.json'],
   [sys.executable,'-B',B/'verify-continuation.py']]
  for i,cmd in enumerate(commands,1):
   limit=int(s['started_epoch']+3600-time.time());g.require(limit>0,'window expired')
   p=subprocess.Popen(list(map(str,cmd)),cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
   try:out,err=p.communicate(timeout=limit)
   except BaseException:
    os.killpg(p.pid,signal.SIGTERM)
    try:out,err=p.communicate(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);out,err=p.communicate()
    save(B/f'command-{i}.json',dict(argv=list(map(str,cmd)),exit=p.returncode,stdout=out.decode(errors='replace'),stderr=err.decode(errors='replace'),timed_out=True));raise
   save(B/f'command-{i}.json',dict(argv=list(map(str,cmd)),exit=p.returncode,stdout=out.decode(errors='replace'),stderr=err.decode(errors='replace')))
   g.require(p.returncode==0,f'command {i} failed; inspect saved output')
   if i==1:g.require(g.read(B/'rate-body.json')['resources']['core']['remaining']>250,'API budget <=250; stop until reset')
  s['status']='verified_hosted'
 except BaseException as e:s.update(status='halted',stop=str(e));raise
 finally:
  s.update(stage='closed',completed_epoch=int(time.time()));update(B/'run-state.json',s)
  save(B/'attempt-result.json',dict(state=s,artifacts={p.name:g.sha(p.read_bytes()) for p in B.iterdir() if p.is_file() and p.name in ('ledger.json','allocation.json','docs-only-evidence.json','docs-publication-receipt.json')},reruns=0))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');p.add_argument('--self-check',action='store_true');args=p.parse_args()
 try:
  if args.run:run()
  else:
   bundle,digest=verify_inputs();print(json.dumps(dict(status='offline_docs_continuation_verified',bundle_sha256=digest,network_requests=0,approval_received=(B/'live-approval.json').exists())))
 except (g.Refusal,ValueError,OSError,subprocess.CalledProcessError) as e:print('STOP: '+str(e),file=sys.stderr);sys.exit(1)
