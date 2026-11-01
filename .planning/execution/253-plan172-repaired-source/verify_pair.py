#!/usr/bin/env python3
"""Additive offline consumer: actual new PR pair plus unchanged old gate inputs."""
import argparse,base64,importlib.util,json,pathlib,subprocess,sys
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g

def module(path,name):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def validate_source(normal,docs,template,receipt_digest):
 g.require(normal['freeze']==docs['freeze'],'normal/docs freezes differ')
 actual=json.loads(json.dumps(normal['freeze']));stated=actual.pop('freeze_sha256',None)
 g.require(stated==g.sha(g.canonical(actual)),'PR freeze digest changed')
 expected=json.loads(json.dumps(template));expected['source']['publication_receipt_sha256']=receipt_digest;expected['source']['fetched_main_sha']=template['source']['server_parent_sha'];expected['bound_documents']=g.bindings()
 g.require(actual==expected,'actual PR freeze differs from exact repaired-source template')
 g.require(actual['source']['source_sha']==g.SOURCE,'historical PR cannot stand in for repaired source')

def verify_publication():
 b,_=g.verify_bundle();ap=B/'publication-allocation.json';lp=B/'publication-ledger.json';a=g.read(ap);ledger=g.read(lp);receipt=g.read(B/'publication-receipt.json')
 verifier=module(B/'runtime/ci-hosted-gate-verify.py','publication_checker')
 verifier.transport_module()._validate_allocation(a)
 expected=g.read(B/'publication-allocation-template.json');expected['source_sha256']=g.sha((B/'bundle.json').read_bytes());expected['bound_documents']=g.bindings()
 g.require(a==expected and a['mode']=='live','publication allocation changed or synthetic')
 g.require(ledger['allocation_sha256']==g.sha(ap.read_bytes()) and ledger['window_id']==a['window_id'] and ledger['source_sha256']==a['source_sha256'],'publication ledger identity changed')
 g.require(not ledger.get('terminal_stop'),'publication ledger stopped')
 rows=ledger['transactions'];plan=g.read(B/'candidate-requests.json');g.require(len(rows)==5+len(plan),'publication requests incomplete/extra')
 for i,tx in enumerate(rows):
  g.require(tx.get('sequence')==i+1 and tx.get('state')=='complete' and not tx.get('error'),'publication transaction missing/failed')
  g.require(tx.get('window_id')==a['window_id'] and tx.get('source_sha256')==a['source_sha256'],'publication transaction escaped allocation')
  verifier.verify_live_transaction_host(tx)
  raw=base64.b64decode(tx['response_body_base64'],validate=True);g.require(g.sha(raw)==tx['response_sha256'] and len(raw)==tx['scrubbed_response_bytes'],'publication response bytes changed')
  g.require(g.sha(tx['url'].encode())==tx['url_sha256'],'publication URL changed')
  if i<2:req=dict(method='GET',route_id='rate_limit' if i==0 else 'get_ref',category='preflight');req.update({} if i==0 else {'params':{'branch':'main'}});status=200
  elif i<5:req=dict(method='GET',route_id='get_ref',category='preflight',params={'branch':g.read(B/'objects.json')['refs'][i-2]});status=404
  else:req=plan[i-5]['request'];status=plan[i-5]['expect']
  g.check_request(req,rows[:i],'publication')
  g.require(tx['method']==req['method'] and tx['route_id']==req['route_id'] and tx['category']==req['category'] and tx['actual_status']==status,'publication route/method/status changed')
  transport=verifier.transport_module();host,port,body,path=transport._route(req,a)
  g.require(tx['url']=='https://'+host+path and tx.get('request_body_sha256')==(g.sha(body) if body is not None else None),'publication request differs from frozen body/route')
  if i>=5:
   expected=plan[i-5]['expected'];actual=json.loads(raw)
   for key,val in expected.items():
    if key=='parents':g.require([p['sha'] for p in actual[key]]==[p['sha'] for p in val],'candidate parents differ')
    elif isinstance(val,dict):g.require(all(actual.get(key,{}).get(k)==v for k,v in val.items()),'candidate readback differs')
    else:g.require(actual.get(key)==val,'candidate object differs')
  g.require(type(tx.get('started_monotonic_ns'))is int and type(tx.get('ended_monotonic_ns'))is int and tx['ended_monotonic_ns']>=tx['started_monotonic_ns'],'publication clock missing')
 g.require((rows[-1]['ended_monotonic_ns']-rows[0]['started_monotonic_ns'])/1e9<=3600,'publication exceeded clock')
 g.require(receipt==dict(schema='sigra.phase253.paired-candidate-publication/v1',mode='live',candidate_sha=b['candidate_sha'],parent_sha=b['parent_sha'],ledger_sha256=g.sha(lp.read_bytes()),allocation_sha256=g.sha(ap.read_bytes()),complete=True),'publication receipt differs from actual ledger')
 return len(rows)

def main(write=False):
 g.verify_bundle();requests=verify_publication()
 # Re-run byte/AST comparisons from the source commits; do not trust a saved pass flag.
 subprocess.run([sys.executable,'-B',B/'check.py'],check=True,stdout=subprocess.DEVNULL)
 normal,docs=[g.read(B/(f+'-evidence.json')) for f in ['normal','docs-only']]
 validate_source(normal,docs,g.read(B/'pr-freeze-template.json'),g.sha((B/'publication-receipt.json').read_bytes()))
 checker=module(B/'runtime/ci-hosted-gate-verify.py','paired_result_checker');pair=checker.verify_pr_pair(normal,docs)
 g.require(pair['accepted_live']is True,'synthetic pair cannot satisfy hosted evidence')
 old=g.ROOT/'.planning/execution/253-proof-bundle-a6838a8f9/canary-evidence.json'
 subprocess.run([sys.executable,'-B',g.ROOT/'.planning/execution/253-172-pr341-maintenance/offline-verifier/ci-hosted-gate-verify.py','--mode','canary','--scenario','matrix','--evidence',old],check=True,stdout=subprocess.DEVNULL)
 result=dict(schema='sigra.phase253.repaired-pair-result/v1',CIREL_01='partial_not_reproduced',CIREL_02='accepted_live',source_sha=g.SOURCE,normal=pair['normal'],docs_only=pair['docs-only'],publication_requests=requests,pr_requests=pair['requests'],retained_canary_evidence=str(old.relative_to(g.ROOT)),retained_canary_sha256=g.sha(old.read_bytes()),retained_canary_source='a6838a8f9e107a49e11ea47ef34e3171fe15eed0',phase_verified=False)
 if write:
  g.approval();s=g.read(B/'run-state.json');g.require(s.get('status')=='active' and s.get('stage')=='prs','only active completed collection may record requirements')
  with (B/'requirements-result.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(json.dumps(result,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--write-result',action='store_true');a=p.parse_args()
 try:main(a.write_result)
 except (g.Refusal,OSError,ValueError,KeyError,subprocess.SubprocessError) as e:print('STOP: '+str(e),file=sys.stderr);sys.exit(1)
