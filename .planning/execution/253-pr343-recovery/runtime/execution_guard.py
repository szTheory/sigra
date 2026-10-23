"""Separate read-only window; never recognizes the closed paired approval."""
import base64, hashlib, json, pathlib, subprocess, time
B=pathlib.Path(__file__).resolve().parent.parent
ROOT=B.parents[2]
class Refusal(ValueError): pass
def require(ok,message):
    if not ok: raise Refusal(message)
def read(p): return json.loads(pathlib.Path(p).read_text())
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*args): return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.PIPE)
def identity(): return read(B/'identity.json')
def requests():
    i=identity()
    def req(route,cat,params=None,query=None):
        d=dict(method='GET',route_id=route,category=cat,family='normal')
        if params is not None:d['params']=params
        if query is not None:d['query']=query
        return d
    return [req('rate_limit','rate'), req('pr_read','pr_identity',{'pull_number':i['pr_number']}),
            req('check_runs','discovery_checks',{'commit_sha':i['head_sha']},{'per_page':100,'page':1}),
            req('run','run_identity',{'run_id':i['run_id']}),
            req('attempt_jobs','attempt_jobs',{'run_id':i['run_id'],'attempt':1},{'per_page':100,'page':1}),
            req('run_artifacts','artifact_metadata',{'run_id':i['run_id']},{'per_page':100,'page':1}),
            req('pr_read','pr_identity',{'pull_number':i['pr_number']})]
def check_request(request,rows):
    require(len(rows)<7 and request==requests()[len(rows)],'request differs from exact GET-only recovery sequence')
    require(all(t.get('state')=='complete' and t.get('actual_status')==200 and not t.get('error') for t in rows),'prior request failed or pending; stop')
    if rows:
        rate=json.loads(base64.b64decode(rows[0]['response_body_base64']))
        require(rate['resources']['core']['remaining']>250,'core API budget <=250; wait until reset')
    if len(rows)>=4:
        run=json.loads(base64.b64decode(rows[3]['response_body_base64']))
        require(run.get('status')=='completed','nonterminal run; no job/artifact reads authorized')
def verify_bundle():
    p=read(B/'proposal.json')
    require(p['schema']=='sigra.phase253.existing-pr-recovery/v1','wrong recovery proposal')
    for rel,digest in p['artifacts'].items():
        path=(B/rel).resolve();require(path.is_relative_to(B),'artifact path escaped bundle')
        require(sha(path.read_bytes())==digest,'recovery artifact changed: '+rel)
    for rel,digest in p['retained_inputs'].items():require(sha((ROOT/rel).read_bytes())==digest,'historical file changed: '+rel)
    source=p['source_sha']
    def inventory(commit):return {r for r in git('ls-tree','-rz',commit).split(b'\0') if r and not r.split(b'\t',1)[1].startswith(b'.planning/')}
    require(inventory('HEAD')==inventory(source),'product source changed')
    require(not git('status','--porcelain=v1','--untracked-files=all','--',':(exclude).planning').strip(),'product worktree dirty')
    return sha((B/'proposal.json').read_bytes())
def approval():
    digest=verify_bundle();p=B/'approval.json';a=read(p)
    require(git('show','HEAD:'+p.relative_to(ROOT).as_posix())==p.read_bytes(),'exact approval must be committed')
    require(a.get('decision')=='approve' and a.get('proposal_sha256')==digest and a.get('scope')=='pr343-read-only-7-gets','wrong recovery approval')
    require(bool(a.get('decision_text','').strip()),'literal approval missing')
    start,end=a.get('approved_at_epoch'),a.get('expires_epoch');now=int(time.time())
    require(type(start)is int and type(end)is int and start<=now<end<=start+86400,'approval expired/invalid')
    return digest

def authorize_request(allocation_path,ledger_path,request_path):
    digest=approval();s=read(B/'run-state.json')
    require(s.get('status')=='active' and s.get('proposal_sha256')==digest,'window closed or changed')
    require(s['started_epoch']<=int(time.time())<s['started_epoch']+600,'recovery window expired')
    require(pathlib.Path(allocation_path).resolve()==B/'allocation.json' and pathlib.Path(ledger_path).resolve()==B/'ledger.json','foreign/closed allocation')
    expected=read(B/'allocation-template.json');expected['source_sha256']=digest
    require(read(allocation_path)==expected,'allocation differs from proposal')
    ledger=read(ledger_path) if pathlib.Path(ledger_path).exists() else {}
    require(not ledger.get('terminal_stop'),'ledger already stopped')
    check_request(read(request_path),ledger.get('transactions',[]))
    return True
