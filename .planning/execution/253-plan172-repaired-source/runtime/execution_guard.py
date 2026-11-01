"""One new paired proof; every prior execution remains closed and read-only."""
import base64,hashlib,json,pathlib,subprocess,time
B=pathlib.Path(__file__).resolve().parent.parent
ROOT=B.parents[2]
SOURCE='5e13621e50e646c63e135035080d2e6e46fbc955'
class Refusal(RuntimeError): pass
def require(ok,message):
 if not ok: raise Refusal(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def read(p):return json.loads(pathlib.Path(p).read_text())
def canonical(d):return json.dumps(d,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.PIPE)
def inventory(commit):
 return {r for r in git('ls-tree','-rz',commit).split(b'\0') if r and not r.split(b'\t',1)[1].startswith(b'.planning/')}
def committed(p):require(git('show','HEAD:'+p.relative_to(ROOT).as_posix())==p.read_bytes(),'approval must be committed exactly')
def verify_bundle():
 b=read(B/'bundle.json');require(b['schema']=='sigra.phase253.paired-proof/v1' and b['source_sha']==SOURCE,'wrong paired bundle/source')
 for rel,digest in b['artifacts'].items():
  p=(B/rel).resolve();require(p.is_relative_to(B),'artifact escaped bundle');require(sha(p.read_bytes())==digest,'changed bundle artifact: '+rel)
 for rel,digest in b['retained_inputs'].items():require(sha((ROOT/rel).read_bytes())==digest,'historical input changed: '+rel)
 require(inventory('HEAD')==inventory(SOURCE),'product source changed')
 require(not git('status','--porcelain=v1','--untracked-files=all','--',':(exclude).planning').strip(),'product working tree dirty')
 return b,sha((B/'bundle.json').read_bytes())
def validate_approval(a,digest,now):
 require(a.get('schema')=='sigra.phase253.paired-approval/v1' and a.get('decision')=='approve','new paired approval missing')
 require(a.get('bundle_sha256')==digest and a.get('scope')=='normal-and-docs-only','approval belongs to another bundle/scope')
 start,end=a.get('approved_at_epoch'),a.get('expires_epoch')
 require(type(start)is int and type(end)is int and start<=now<end<=start+86400,'approval expired/invalid')
 require(isinstance(a.get('decision_text'),str) and bool(a['decision_text'].strip()),'literal approval answer missing')
def approval():
 b,digest=verify_bundle();p=B/'live-approval.json';require(p.exists(),'new paired proof approval missing');committed(p);a=read(p);validate_approval(a,digest,int(time.time()))
 p=B/'prs-approval.json';require(p.exists(),'new paired section approval missing');committed(p);s=read(p)
 require(all(s.get(k)==a.get(k) for k in ('bundle_sha256','scope','decision_text','approved_at_epoch','expires_epoch')),'section approval differs from paired approval')
 require(s.get('section')=='docs_and_prs' and s.get('section_sha256')==read(B/'actions.json')['outward_actions_sha256']['docs_and_prs'],'section scope changed')
 return b,a

def check_request(req,rows,stage):
 require(req.get('method','GET') in ('GET','POST'),'only read/create operations allowed')
 require(req.get('category') not in ('infrastructure_rerun','infrastructure_retry'),'reruns forbidden')
 require(req.get('route_id') not in ('dispatch','cancel_run','rerun','rerun_failed_jobs'),'dispatch/cancel/rerun forbidden')
 require(not any(t.get('error') or t.get('actual_status') in (403,429) for t in rows),'previous failure or API rate limit; window stopped')
 for tx in reversed(rows):
  if tx.get('route_id')=='rate_limit' and tx.get('actual_status')==200:
   data=json.loads(base64.b64decode(tx['response_body_base64']));require(data['resources']['core']['remaining']>250,'API core <=250; wait until reset');break
 if stage=='publication':
  require(len(rows)<24,'publication ceiling reached')
  sequence=[dict(method='GET',route_id='rate_limit',category='preflight'),dict(method='GET',route_id='get_ref',category='preflight',params={'branch':'main'})]
  sequence += [dict(method='GET',route_id='get_ref',category='preflight',params={'branch':r}) for r in read(B/'objects.json')['refs']]
  sequence += [r['request'] for r in read(B/'candidate-requests.json')]
  require(len(rows)<len(sequence) and req==sequence[len(rows)],'publication request/order/body differs from frozen commands')
  if len(rows)>=2:
   main=json.loads(base64.b64decode(rows[1]['response_body_base64']));require(main['object']['sha']==read(B/'objects.json')['known_parent_sha'],'main changed; stop before writes')
  if len(rows)>=5:require(all(r['actual_status']==404 for r in rows[2:5]),'proposed ref already exists; create-only publication stopped')
  return
 require(stage=='prs' and len(rows)<120,'PR window invalid/ceiling reached')
 require(req.get('family') in ('shared','normal','docs-only'),'wrong PR family')
 if req.get('method','GET')=='GET':return
 body=req.get('body') or {};route=req.get('route_id');fr=read(B/'pr-freeze.json');f=req.get('family')
 if route=='pr_create':
  require(f in ('normal','docs-only'),'wrong draft PR family')
  require(body==dict(title=f'Phase 253 {f} CI proof (draft, do not merge)',head=fr[f]['head_ref'],base=fr[f]['base_ref'],body='Draft proof pull request; never merged.',draft=True),'draft PR fields differ')
  require(not any(t.get('route_id')=='pr_create' and t.get('family')==f for t in rows),'one draft PR per family maximum')
  return
 require(f=='docs-only' and req.get('category')=='docs_publication','only scoped docs object creation allowed')
 spec=fr['docs-only'];pub=spec['publication'];date=pub['date_utc_second']
 author=dict(name='Sigra Publication Bot',email='sigra-publication@users.noreply.github.com',date=date)
 for position,(commit,parent,tree,base,path,message,ref,mode) in enumerate([
  (spec['base_sha'],pub['candidate_sha'],pub['docs_base_tree'],pub['candidate_tree'],'.github/workflows/ci.yml','Phase 253 docs probe base workflow exception\n',spec['base_ref'],pub['ci_mode']),
  (spec['head_sha'],spec['base_sha'],pub['docs_head_tree'],pub['docs_base_tree'],'guides/reference/phase253-docs-only-proof.md','Phase 253 docs-only probe head\n',spec['head_ref'],pub['docs_mode'])]):
  options={'git_create_tree':dict(base_tree=base,tree=[dict(path=path,mode=mode,type='blob',content=git('show',commit+':'+path).decode())]),'git_create_commit':dict(message=message,tree=tree,parents=[parent],author=author,committer=author),'create_ref':dict(ref='refs/heads/'+ref,sha=commit)}
  if route in options and body==options[route]:
   require(sum(t.get('route_id')==route and t.get('category')=='docs_publication' for t in rows)==position,'docs creation order/maximum changed')
   require(not any(t.get('route_id')==route and t.get('request_body_sha256')==sha(json.dumps(body,separators=(',',':'),ensure_ascii=False).encode()) for t in rows),'duplicate create forbidden');return
 raise Refusal('unapproved object/ref write')

def authorize_request(allocation_path,ledger_path,request_path):
 b,a=approval();s=read(B/'run-state.json');stage=s.get('stage');now=int(time.time())
 require(s.get('status')=='active' and stage in ('publication','prs'),'window is closed')
 require(s.get('bundle_sha256')==sha((B/'bundle.json').read_bytes()) and s.get('approval_sha256')==sha((B/'live-approval.json').read_bytes()),'window approval binding changed')
 require(type(s.get(stage+'_started_epoch'))is int and s[stage+'_started_epoch']<=now<s[stage+'_started_epoch']+3600,'window expired')
 ap,lp=pathlib.Path(allocation_path).resolve(),pathlib.Path(ledger_path).resolve()
 require(ap==B/(stage+'-allocation.json') and lp==B/(stage+'-ledger.json'),'old/unscoped allocation forbidden')
 require(sha(ap.read_bytes())==s.get(stage+'_allocation_sha256'),'allocation changed')
 t=read(B/(stage+'-allocation-template.json'));t['source_sha256']=sha((B/('bundle.json' if stage=='publication' else 'pr-freeze.json')).read_bytes());t['bound_documents']=bindings()
 require(read(ap)==t,'allocation differs from frozen template')
 ledger=read(lp) if lp.exists() else {};require(not ledger.get('terminal_stop'),'ledger already stopped')
 check_request(read(request_path),ledger.get('transactions',[]),stage)
 return True

def require_unused_attempt():
 names=['run-state.json','attempt-result.json','live-result.json','pr-freeze.json','main-preflight.json','publication-allocation.json','publication-ledger.json','publication-receipt.json','prs-allocation.json','prs-ledger.json','normal-evidence.json','docs-only-evidence.json','docs-publication-receipt.json','requirements-result.json']
 require(not any((B/name).exists() for name in names),'attempt already started or existing execution outputs; never restart')
 require(not list(B.glob('publication-request-*.json')) and not list(B.glob('prs-request-*.json')) and not list(B.glob('command-*.json')),'partial attempt files exist; inspect instead of restarting')

def bindings():
 paths=[B/'bundle.json',ROOT/'.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-BUDGETS.md']
 return [dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p.read_bytes())) for p in paths]
