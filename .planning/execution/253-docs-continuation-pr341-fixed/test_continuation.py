import copy,importlib.util,json,pathlib,sys,unittest,subprocess,tempfile,os
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'));import execution_guard as g
spec=importlib.util.spec_from_file_location('reconcile',B/'verify-continuation.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
class Guards(unittest.TestCase):
 def test_real_saved_normal_passes_corrected_verifier(self):
  result=r.v.verify_pr_family(g.read(g.OLD/'normal-evidence.json'),'normal')
  self.assertTrue(result['accepted_live']);self.assertEqual(result['pr_number'],341)
 def test_compare_boundaries_and_bad_inputs(self):
  for n in [99,100,212,299]:self.assertEqual(len(r.v.compare_file_paths({'files':[{'filename':str(i)} for i in range(n)]})),n)
  for x in [None,{}, {'files':[]},{'files':[{'filename':'x'}]*2},{'files':[{'filename':str(i)} for i in range(300)]}]:
   with self.assertRaises(r.v.VerificationError):r.v.compare_file_paths(x)
 def test_normal_dispatch_and_other_writes_refused(self):
  for req in [dict(family='normal',route_id='run'),dict(family='docs-only',route_id='dispatch'),dict(family='docs-only',route_id='rerun'),dict(family='docs-only',route_id='create_ref',method='PATCH'),dict(family='shared',route_id='pr_create',method='POST'),dict(family='docs-only',route_id='merge',method='PUT'),dict(family='docs-only',category='infrastructure_rerun')]:
   with self.subTest(req=req),self.assertRaises(g.Refusal):g.check_request(req,[])
 def test_only_exact_docs_refs_and_draft_pr_allowed(self):
  for suffix,commit in [('docs-base','98f0e9e6c1214b35c11f7addd1b92a9b1e5f47b7'),('docs-head','879d628feeb0b894af1c0d842830b3002f905440')]:g.check_request(dict(family='docs-only',route_id='create_ref',method='POST',body=dict(ref='refs/heads/gsd/253-replan-proof-a6838a8f9-'+suffix,sha=commit)),[])
  body=dict(head='gsd/253-replan-proof-a6838a8f9-docs-head',base='gsd/253-replan-proof-a6838a8f9-docs-base',draft=True)
  req=dict(family='docs-only',route_id='pr_create',method='POST',body=body);g.check_request(req,[])
  for bad in [dict(body,head='gsd/253-replan-proof-a6838a8f9-candidate'),dict(body,draft=False)]:
   with self.assertRaises(g.Refusal):g.check_request(dict(req,body=bad),[])
  with self.assertRaises(g.Refusal):g.check_request(req,[dict(route_id='pr_create')])
 def test_closed_or_capped_ledgers_cannot_continue(self):
  for rows in [[dict(actual_status=403)],[dict(actual_status=429)],[dict(error='network')],[{}]*120]:
   with self.assertRaises(g.Refusal):g.check_request(dict(family='docs-only',route_id='run'),rows)
 def test_separate_windows_are_explicit_and_missing_evidence_never_passes(self):
  n=dict(accepted_live=True,family='normal',window_id='old',run_id=1);d=dict(accepted_live=True,family='docs-only',window_id='new',run_id=2);e=dict(freeze={'source':'same'})
  result=r.reconcile(n,d,e,e);self.assertFalse(result['ledgers_combined']);self.assertEqual(result['requirements']['CIREL-01'],'partial_not_reproduced')
  for bad in [dict(d,accepted_live=False),dict(d,window_id='old'),dict(d,run_id=1),dict(d,family='normal')]:
   with self.assertRaises(g.Refusal):r.reconcile(n,bad,e,e)
  with self.assertRaises(g.Refusal):r.reconcile(n,d,e,dict(freeze={'source':'different'}))
 def test_actual_shell_startup_reproduces_old_import_failure_and_reaches_new_guard(self):
  old=g.ROOT/'.planning/execution/253-docs-continuation-pr341'
  for bundle in [old,B]:
   with tempfile.TemporaryDirectory(prefix='253-shell-startup-') as tmp:
    t=pathlib.Path(tmp)
    command=['bash',str(bundle/'runtime/ci-pr-proof.sh'),'--family','docs-only','--freeze',str(bundle/'pr-freeze.json'),'--allocation',str(bundle/'allocation-template.json'),'--requests',str(t/'ledger.json'),'--repo-root',str(g.ROOT),'--revision-freeze',str(g.OLD/'canary-freeze.json'),'--action-approval',str(old/'prs-approval.json'),'--evidence',str(t/'evidence.json'),'--docs-publication-receipt',str(t/'publication.json')]
    env={k:v for k,v in os.environ.items() if k!='PYTHONPATH'};env['PYTHONDONTWRITEBYTECODE']='1'
    result=subprocess.run(command,cwd=t,capture_output=True,text=True,env=env,timeout=45)
    self.assertEqual(result.returncode,1,result.stdout+result.stderr)
    self.assertFalse((t/'ledger.json').exists(),'offline startup must never issue an HTTP request')
    self.assertFalse((t/'publication.json').exists())
    if bundle==old:
     self.assertIn("ModuleNotFoundError: No module named 'execution_guard'",result.stderr)
     self.assertFalse((t/'evidence.json').exists())
    else:
     self.assertNotIn('ModuleNotFoundError',result.stdout+result.stderr)
     evidence=json.loads((t/'evidence.json').read_text())
     self.assertEqual(evidence['transport_ledger']['transactions'],[])
     self.assertIn('execution_guard.py',evidence['collection']['stop'])
     self.assertFalse(evidence['collection']['complete'])
if __name__=='__main__':unittest.main(verbosity=2)
