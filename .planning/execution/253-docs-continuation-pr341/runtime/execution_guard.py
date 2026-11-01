"""Fresh docs-only window. Original attempts are read-only inputs, never resumed."""
import hashlib,json,pathlib,subprocess,time
B=pathlib.Path(__file__).resolve().parent.parent
ROOT=B.parents[2]
OLD=ROOT/'.planning/execution/253-proof-bundle-a6838a8f9'
class Refusal(RuntimeError):pass
def require(ok,message):
 if not ok:raise Refusal(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def read(p):return json.loads(pathlib.Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.PIPE)
def committed(path):
 require(git('show','HEAD:'+path.relative_to(ROOT).as_posix())==path.read_bytes(),'approval not committed exactly')
def inventory(commit):
 return {r.split(b'\t',1)[1]:r.split(b'\t',1)[0] for r in git('ls-tree','-rz',commit).split(b'\0') if r and not r.split(b'\t',1)[1].startswith(b'.planning/')}
def verify_bundle():
 bundle=read(B/'bundle.json');require(bundle['schema']=='sigra.phase253.docs-continuation/v1','wrong bundle schema')
 require(bundle['candidate_source_sha']=='a6838a8f9e107a49e11ea47ef34e3171fe15eed0','candidate source changed')
 for rel,digest in bundle['artifacts'].items():
  p=(B/rel).resolve();require(p.is_relative_to(B),'artifact outside bundle');require(sha(p.read_bytes())==digest,'changed artifact: '+rel)
 for rel,digest in bundle['retained_inputs'].items():require(sha((ROOT/rel).read_bytes())==digest,'retained input changed: '+rel)
 require(inventory(bundle['checker_source_sha'])==inventory('HEAD'),'checker source changed')
 require(not git('status','--porcelain=v1','--untracked-files=all','--',':(exclude).planning').strip(),'product working tree dirty')
 require(read(OLD/'run-state.json')['status']=='halted','previous attempt must stay closed')
 return bundle,sha((B/'bundle.json').read_bytes())
def approval():
 bundle,digest=verify_bundle();p=B/'live-approval.json';require(p.exists(),'new docs-only approval missing');committed(p);a=read(p);now=int(time.time())
 require(a.get('schema')=='sigra.phase253.docs-continuation-approval/v1' and a.get('decision')=='approve','wrong approval')
 require(a.get('bundle_sha256')==digest and a.get('scope')=='docs-only','approval scope/hash mismatch')
 start,end=a.get('approved_at_epoch'),a.get('expires_epoch')
 require(type(start)is int and type(end)is int and start<=now<end<=start+86400,'approval expired')
 require(isinstance(a.get('decision_text'),str) and a['decision_text'].strip(),'literal decision missing')
 p=B/'prs-approval.json';require(p.exists(),'new section approval missing');committed(p)
 section=read(p)
 require(section.get('bundle_sha256')==digest and section.get('scope')=='docs-only','old section approval forbidden')
 require(all(section.get(k)==a.get(k) for k in ('decision_text','approved_at_epoch','expires_epoch')),'section decision differs from new approval')
 return bundle,a

def check_request(req,rows):
 require(req.get('family') in ('shared','docs-only'),'normal family is forbidden')
 require(req.get('category') not in ('infrastructure_rerun','infrastructure_retry'),'reruns forbidden')
 route=req.get('route_id');body=req.get('body') or {}
 require(route not in ('dispatch','cancel_run','rerun','rerun_failed_jobs'),'dispatch/cancel/rerun forbidden')
 if req.get('method','GET')!='GET':
  require(req.get('method')=='POST','only create operations are allowed')
  require(route in ('git_create_tree','git_create_commit','create_ref','pr_create'),'write route forbidden')
  require(req.get('family')=='docs-only','writes must be docs-only')
 if route=='create_ref':
  refs={'refs/heads/gsd/253-replan-proof-a6838a8f9-docs-base':'98f0e9e6c1214b35c11f7addd1b92a9b1e5f47b7','refs/heads/gsd/253-replan-proof-a6838a8f9-docs-head':'879d628feeb0b894af1c0d842830b3002f905440'}
  require(body.get('ref') in refs and body.get('sha')==refs.get(body.get('ref')),'only exact unused docs refs and commits allowed')
 if route=='pr_create':
  require(body.get('head')=='gsd/253-replan-proof-a6838a8f9-docs-head' and body.get('base')=='gsd/253-replan-proof-a6838a8f9-docs-base' and body.get('draft')is True,'only exact draft docs PR allowed')
  require(not any(t.get('route_id')=='pr_create' for t in rows),'one draft PR maximum')
 require(not any(t.get('error') or t.get('actual_status') in (403,429) for t in rows),'prior failed/rate-limited request; stop')
 require(len(rows)<120,'new 120-request ceiling reached')

def authorize_request(allocation_path,ledger_path,request_path):
 bundle,a=approval();s=read(B/'run-state.json');now=int(time.time())
 require(s.get('status')=='active' and s.get('stage')=='docs-only','window closed')
 require(s.get('bundle_sha256')==sha((B/'bundle.json').read_bytes()) and s.get('approval_sha256')==sha((B/'live-approval.json').read_bytes()),'window binding changed')
 require(type(s.get('started_epoch'))is int and s['started_epoch']<=now<s['started_epoch']+3600,'window expired')
 ap=pathlib.Path(allocation_path).resolve();lp=pathlib.Path(ledger_path).resolve()
 require(ap==B/'allocation.json' and lp==B/'ledger.json','old/unscoped allocation forbidden')
 allocation=read(ap);require(sha(ap.read_bytes())==s.get('allocation_sha256'),'allocation changed')
 require(allocation==read(B/'allocation-template.json'),'allocation differs from template')
 rows=read(lp).get('transactions',[]) if lp.exists() else []
 if lp.exists():require(not read(lp).get('terminal_stop'),'ledger stopped')
 check_request(read(request_path),rows)
 return True
