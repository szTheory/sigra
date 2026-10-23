"""Offline by default; --run needs a fresh exact, committed approval."""
import argparse,importlib.util,json,os,pathlib,subprocess,sys,time
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
from collector import collect
from verify import verify

def save(path,value,exclusive=True):
    raw=(json.dumps(value,indent=2)+'\n').encode()
    if exclusive:
        with path.open('xb') as f:f.write(raw);f.flush();os.fsync(f.fileno())
    else:
        p=path.with_suffix('.next');p.write_bytes(raw);os.replace(p,path)
def load_transport():
    s=importlib.util.spec_from_file_location('recovery_transport',B/'runtime/ci-hosted-transport.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def run():
    for key in os.environ:g.require(not key.startswith('SIGRA_CANARY_TEST_') and key not in ('PYTHONPATH','SIGRA_LIVE_POLICY_SHIM','GIT_DIR','GIT_WORK_TREE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES'),'environment override forbidden')
    digest=g.approval()
    g.require(not any((B/name).exists() for name in ['run-state.json','allocation.json','ledger.json','result.json','attempt-result.json']),'once-only recovery already started; never restart')
    g.require(not list(B.glob('request-*.json')),'partial attempt files exist; inspect instead of restarting')
    transport=load_transport();transport.preservation_preflight(B)
    state=dict(status='active',started_epoch=int(time.time()),proposal_sha256=digest)
    save(B/'run-state.json',state)
    try:
        allocation=g.read(B/'allocation-template.json');allocation['source_sha256']=digest;save(B/'allocation.json',allocation)
        def call(req):
            lp=B/'ledger.json';n=len(g.read(lp)['transactions']) if lp.exists() else 0
            rq=B/f'request-{n+1}.json';rc=B/f'request-{n+1}-receipt.json';bp=B/f'request-{n+1}-body.json';save(rq,req)
            receipt,_,raw,_=transport.request_one(B/'allocation.json',lp,rq,rc,bp)
            g.require(receipt['actual_status']==200 and not receipt.get('error'),'HTTP failed; stop without retry')
            return json.loads(raw)
        result=collect(call)
        ledger=g.read(B/'ledger.json');ledger['mode']='live';checked=verify(ledger)
        g.require(checked['run_status']==result['run_status'] and checked['conclusion']==result['conclusion'],'collector/verifier disagreement')
        save(B/'result.json',checked);state['status']='snapshot_collected'
    except BaseException as error:
        state.update(status='halted',stop=type(error).__name__+': '+str(error));raise
    finally:
        state['preserved_active_state']=transport._preserve(B/'run-state.json')
        state['closed_epoch']=int(time.time());state['closed']=True;save(B/'run-state.json',state,False)
        save(B/'attempt-result.json',dict(state=state,requests=len(g.read(B/'ledger.json')['transactions']) if (B/'ledger.json').exists() else 0,ci_launches=0,artifacts={p.name:g.sha(p.read_bytes()) for p in B.iterdir() if p.name in ('ledger.json','result.json','allocation.json')}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');a=p.parse_args()
    try:
        if a.run:run()
        else:print(json.dumps(dict(proposal_sha256=g.verify_bundle(),network_requests=0,ci_launches=0,approval_pending=True)))
    except (g.Refusal,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:print('STOP: '+str(error),file=sys.stderr);sys.exit(1)
