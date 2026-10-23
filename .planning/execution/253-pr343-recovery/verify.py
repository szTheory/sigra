"""Independent raw-ledger verifier. A metadata snapshot never completes hosted acceptance."""
import base64,hashlib,json,pathlib
B=pathlib.Path(__file__).resolve().parent
class Rejected(ValueError):pass
def need(ok,message):
    if not ok:raise Rejected(message)
def verify(ledger):
    i=json.loads((B/'identity.json').read_text());rows=ledger.get('transactions',[])
    need(ledger.get('mode') in ('live','offline-replay'),'missing evidence mode')
    need(len(rows) in (4,7),'not a complete bounded snapshot')
    paths=['/rate_limit',f"/repos/szTheory/sigra/pulls/{i['pr_number']}",f"/repos/szTheory/sigra/commits/{i['head_sha']}/check-runs?per_page=100&page=1",f"/repos/szTheory/sigra/actions/runs/{i['run_id']}",f"/repos/szTheory/sigra/actions/runs/{i['run_id']}/attempts/1/jobs?per_page=100&page=1",f"/repos/szTheory/sigra/actions/runs/{i['run_id']}/artifacts?per_page=100&page=1",f"/repos/szTheory/sigra/pulls/{i['pr_number']}"]
    routes=['rate_limit','pr_read','check_runs','run','attempt_jobs','run_artifacts','pr_read']
    cats=['rate','pr_identity','discovery_checks','run_identity','attempt_jobs','artifact_metadata','pr_identity']
    bodies=[]
    for n,row in enumerate(rows):
        need(row.get('sequence')==n+1 and row.get('route_id')==routes[n] and row.get('category')==cats[n],'route/category/sequence mismatch')
        need(row.get('method')=='GET' and row.get('host')=='api.github.com' and row.get('url')=='https://api.github.com'+paths[n],'unapproved HTTP request')
        need(row.get('state')=='complete' and row.get('actual_status')==200 and not row.get('error'),'failed or pending request')
        need(type(row.get('started_monotonic_ns'))is int and type(row.get('ended_monotonic_ns'))is int and row['started_monotonic_ns']<=row['ended_monotonic_ns'],'missing actual clocks')
        if n:need(rows[n-1]['ended_monotonic_ns']<=row['started_monotonic_ns'],'overlapping requests')
        raw=base64.b64decode(row['response_body_base64'],validate=True)
        need(hashlib.sha256(raw).hexdigest()==row.get('response_sha256'),'response hash mismatch')
        bodies.append(json.loads(raw))
    need(rows[-1]['ended_monotonic_ns']-rows[0]['started_monotonic_ns']<=600*10**9,'elapsed limit exceeded')
    need(bodies[0]['resources']['core']['remaining']>250,'core API budget stop')
    for pr in [bodies[1]]+([bodies[6]] if len(rows)==7 else []):
        need(pr.get('number')==343 and pr.get('state')=='open' and pr.get('draft') is True and pr.get('merge_commit_sha')=='d6024255ed139f7c19bd44e68c10a85cc9ecca3b','PR identity changed')
        for side in ('head','base'):
            v=pr.get(side) or {};need(v.get('sha')==i[side+'_sha'] and v.get('ref')==i[side+'_ref'] and (v.get('repo') or {}).get('id')==i['repository_id'],'PR source mismatch')
    checks=bodies[2];need(checks.get('total_count')==len(checks.get('check_runs',[])),'incomplete checks')
    hints=set()
    import re
    for c in checks['check_runs']:
        m=re.fullmatch(r'https://github\.com/szTheory/sigra/actions/runs/([1-9][0-9]*)/job/[1-9][0-9]*',c.get('details_url') or '')
        if c.get('head_sha')==i['head_sha'] and (c.get('app') or {}).get('id')==15368 and m:hints.add(int(m[1]))
    need(hints=={i['run_id']},'run hints ambiguous/missing')
    run=bodies[3]
    for k,v in dict(id=i['run_id'],workflow_id=i['workflow_id'],head_sha=i['head_sha'],head_branch=i['head_ref'],run_attempt=1,event='pull_request').items():need(run.get(k)==v,'run identity mismatch: '+k)
    need((run.get('repository') or {}).get('id')==i['repository_id'],'foreign run repository')
    prs=[p for p in run.get('pull_requests',[]) if p.get('number')==343];need(len(prs)==1,'run does not identify exact PR once')
    for side in ('head','base'):
        v=prs[0].get(side) or {};need(v.get('sha')==i[side+'_sha'] and v.get('ref')==i[side+'_ref'] and (v.get('repo') or {}).get('id')==i['repository_id'],'run PR identity changed')
    terminal=run.get('status')=='completed';need((len(rows)==7)==terminal,'terminal collection incomplete or premature')
    if terminal:
        for body,key in [(bodies[4],'jobs'),(bodies[5],'artifacts')]:need(type(body.get('total_count'))is int and body['total_count']==len(body.get(key,[])),'inventory truncated')
        for job in bodies[4]['jobs']:need(job.get('run_id')==i['run_id'] and job.get('run_attempt')==1 and job.get('head_sha')==i['head_sha'],'job identity changed')
    return dict(schema='sigra.phase253.existing-pr-snapshot/v1',mode=ledger['mode'],requests=len(rows),run_id=i['run_id'],run_status=run.get('status'),conclusion=run.get('conclusion') if terminal else None,hosted_accepted=False,phase_verified=False)
if __name__=='__main__':
    import sys
    print(json.dumps(verify(json.loads(pathlib.Path(sys.argv[1]).read_text())),indent=2))
