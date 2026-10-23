"""Existing PR snapshot. Injected call in replay; real calls use narrowed HTTP transport."""
import pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent/'runtime'))
from discovery import candidates,validate
from execution_guard import identity,requests,require

def check_pr(pr):
    i=identity()
    require(pr.get('number')==i['pr_number'] and pr.get('state')=='open' and pr.get('draft') is True,'existing draft PR identity/state changed')
    for side in ('base','head'):
        value=pr.get(side) or {}
        require(value.get('sha')==i[side+'_sha'] and value.get('ref')==i[side+'_ref'] and (value.get('repo') or {}).get('id')==i['repository_id'],'PR source/base changed')
    require(pr.get('merge_commit_sha')=='d6024255ed139f7c19bd44e68c10a85cc9ecca3b','PR merge identity changed')

def collect(call):
    seq=requests();i=identity()
    rate=call(seq[0]);require(rate['resources']['core']['remaining']>250,'core API budget <=250; wait until reset')
    check_pr(call(seq[1]))
    checks=call(seq[2]);require(candidates(checks,'szTheory/sigra',i['head_sha'])==[i['run_id']],'checks do not identify the pinned run uniquely')
    run=call(seq[3]);validate(run,**i)
    if run.get('status')!='completed':return {'collection':'waiting','run_status':run.get('status'),'conclusion':None,'hosted_accepted':False,'phase_verified':False}
    jobs=call(seq[4]);require(type(jobs.get('total_count'))is int and jobs['total_count']==len(jobs.get('jobs',[])),'job inventory incomplete; no pagination budget')
    for job in jobs['jobs']:
        require(job.get('run_id')==i['run_id'] and job.get('run_attempt')==1 and job.get('head_sha')==i['head_sha'],'job identity changed')
    artifacts=call(seq[5]);require(type(artifacts.get('total_count'))is int and artifacts['total_count']==len(artifacts.get('artifacts',[])),'artifact inventory incomplete; no pagination budget')
    check_pr(call(seq[6]))
    # These metadata do not replace downloaded browser evidence or the docs-only PR.
    return {'collection':'terminal_metadata','run_status':'completed','conclusion':run.get('conclusion'),'hosted_accepted':False,'phase_verified':False}
