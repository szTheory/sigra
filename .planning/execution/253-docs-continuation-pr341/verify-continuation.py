#!/usr/bin/env python3
"""Independently verify original successes plus the separate fresh docs result.
Never concatenate ledgers or claim that separate windows were one window.
"""
import importlib.util,json,pathlib,sys
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
spec=importlib.util.spec_from_file_location('scoped_verifier',B/'runtime/ci-hosted-gate-verify.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
def reconcile(normal,docs,normal_evidence,docs_evidence):
 g.require(normal.get('accepted_live')is True and docs.get('accepted_live')is True,'both actual PR families must verify')
 g.require(normal.get('family')=='normal' and docs.get('family')=='docs-only','wrong PR families')
 g.require(normal['window_id']!=docs['window_id'] and normal['run_id']!=docs['run_id'],'fresh docs window and run required')
 g.require(normal_evidence['freeze']==docs_evidence['freeze'],'candidate and docs source freeze changed')
 return dict(schema='sigra.phase253.split-window-pr-proof/v1',normal=normal,docs_only=docs,independently_verified=True,ledgers_combined=False,requirements={'CIREL-01':'partial_not_reproduced','CIREL-02':'accepted'},original_selected_failure_reproduced=False,phase_verification_status='not_started')
def verify():
 g.verify_bundle()
 old=g.OLD
 # Run the exact canary matrix checker; it is read-only and has no request path.
 import subprocess
 subprocess.run([sys.executable,'-B',str(B/'runtime/ci-hosted-gate-verify.py'),'--mode','canary','--scenario','matrix','--evidence',str(old/'canary-evidence.json')],check=True,stdout=subprocess.DEVNULL)
 n=g.read(old/'normal-evidence.json');d=g.read(B/'docs-only-evidence.json')
 result=reconcile(v.verify_pr_family(n,'normal'),v.verify_pr_family(d,'docs-only'),n,d)
 result['candidate_source_sha']='a6838a8f9e107a49e11ea47ef34e3171fe15eed0'
 result['inputs']={str(p.relative_to(g.ROOT)):g.sha(p.read_bytes()) for p in [old/'canary-evidence.json',old/'normal-evidence.json',B/'docs-only-evidence.json']}
 with (B/'requirements-result.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(json.dumps(result))
if __name__=='__main__':verify()
