"""Approval, source, immutable-bundle and once-only window guards for this execution only."""
import hashlib,json,pathlib,subprocess,time
B=pathlib.Path(__file__).resolve().parent.parent
ROOT=B.parents[2]
SOURCE='16800f4319cdd0e2554938071d4ebc48caa969ac'
PREFIX='gsd/253-replan-proof-16800f431'
class Refusal(RuntimeError):pass
def require(ok,message):
 if not ok:raise Refusal(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def read(p):return json.loads(pathlib.Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.PIPE)
def inventory(commit):
 return {row.split(b'\t',1)[1]:row.split(b'\t',1)[0] for row in git('ls-tree','-rz',commit).split(b'\0') if row and not row.split(b'\t',1)[1].startswith(b'.planning/')}
def verify_bundle():
 raw=(B/'bundle.json').read_bytes();bundle=json.loads(raw)
 require(bundle['schema']=='sigra.phase253.execution-bundle/v1','bundle schema mismatch')
 require(bundle['source_sha']==SOURCE,'source mismatch')
 for rel,digest in bundle['artifacts'].items():
  path=(B/rel).resolve();require(path.is_relative_to(B.resolve()),'artifact escaped bundle')
  require(sha(path.read_bytes())==digest,'bundle artifact changed: '+rel)
 plan=bundle.get('execution_plan')
 if plan:require(sha((ROOT/plan['path']).read_bytes())==plan['sha256'],'current execution plan changed')
 require(subprocess.run(['git','-C',str(ROOT),'merge-base','--is-ancestor',SOURCE,'HEAD'],capture_output=True).returncode==0,'source is not an ancestor')
 require(inventory(SOURCE)==inventory('HEAD'),'product source changed')
 dirty=git('status','--porcelain=v1','--untracked-files=all','--',':(exclude).planning')
 require(not dirty.strip(),'product working tree is dirty')
 return bundle,sha(raw)
def validate_approval(record,digest,now):
 require(record.get('schema')=='sigra.phase253.proof-bundle-approval/v1','old or unknown approval schema')
 require(record.get('decision')=='approve','explicit approval missing')
 require(record.get('source_sha')==SOURCE and record.get('bundle_sha256')==digest,'approval source/bundle mismatch')
 require(record.get('sections')==['canary','docs_and_prs'],'both action sections must be explicitly approved')
 start,end=record.get('approved_at_epoch'),record.get('expires_epoch')
 require(type(start) is int and type(end) is int and start<=now<end<=start+86400,'approval expired or invalid')
 require(isinstance(record.get('decision_text'),str) and bool(record['decision_text'].strip()),'original user decision text missing')
def committed(path):
 path=pathlib.Path(path).resolve();require(path.is_relative_to(ROOT),'approval outside repository')
 rel=path.relative_to(ROOT).as_posix()
 try:raw=git('show','HEAD:'+rel)
 except subprocess.CalledProcessError as e:raise Refusal('approval is not committed in HEAD') from e
 require(raw==path.read_bytes(),'approval bytes differ from committed HEAD')
def approval():
 bundle,digest=verify_bundle();p=B/'live-approval.json';require(p.is_file(),'new hosted approval has not been recorded')
 committed(p);record=read(p);validate_approval(record,digest,int(time.time()));return bundle,record

def validate_window(state,allocation,stage,now):
 require(state.get('status')=='active' and state.get('stage')==stage,'window is closed or wrong stage')
 require(state.get('source_sha')==SOURCE,'window source mismatch')
 require(allocation.get('window_id')=='253-replan-proof-16800f431-'+stage+'-1','old or wrong allocation window')
 require(allocation.get('mode')=='live','test/fixture allocation cannot launch hosted proof')
 require(allocation.get('max_requests')==({'canary':117,'prs':120}[stage]),'request ceiling changed')
 require(allocation.get('max_elapsed_seconds')==3600,'time ceiling changed')
 started=state.get(stage+'_started_epoch')
 require(type(started) is int and started>0 and started<=now<started+3600,'window expired or not started')
 require(state.get('parent_verified')==state.get('expected_parent') and state.get('expected_parent')=='09df342a82e03c3d5d40173c912b70e827f7eadc','fresh parent not verified')

def authorize_request(allocation_path,ledger_path,request_path):
 bundle,auth=approval();state=read(B/'run-state.json');stage=state.get('stage');require(stage in ('canary','prs'),'window stage missing')
 allocation_path=pathlib.Path(allocation_path).resolve();ledger_path=pathlib.Path(ledger_path).resolve()
 require(allocation_path==B/(stage+'-allocation.json') and ledger_path==B/(stage+'-ledger.json'),'old or unscoped allocation/ledger path')
 a=read(allocation_path);validate_window(state,a,stage,int(time.time()))
 require(state.get('bundle_sha256')==sha((B/'bundle.json').read_bytes()),'window bundle mismatch')
 require(state.get('approval_sha256')==sha((B/'live-approval.json').read_bytes()),'window approval mismatch')
 require(state.get(stage+'_allocation_sha256')==sha(allocation_path.read_bytes()),'active allocation changed')
 req=read(request_path)
 require(req.get('category') not in ('infrastructure_retry','infrastructure_rerun'),'reruns are disabled')
 if ledger_path.exists():
  ledger=read(ledger_path);require(not ledger.get('terminal_stop'),'ledger has stopped')
  require(not any(t.get('error') for t in ledger.get('transactions',[])),'a prior transport request failed')
  require(not any(t.get('actual_status') in (403,429) for t in ledger.get('transactions',[])),'rate-limit refusal: wait for reported reset, do not retry this closed run')
 return True
