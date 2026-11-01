#!/usr/bin/env python3
"""Offline only: pinned candidate and generated checker must consume the exact proposed namespace."""
import base64,copy,gzip,hashlib,importlib.util,json,os,pathlib,subprocess,tempfile,textwrap,unittest
B=pathlib.Path(__file__).resolve().parent;R=B.parents[2];OLD=R/'.planning/execution/253-proof-bundle-16800f431-next'
def load(path,name):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
class NamespaceBoundary(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  operator=load(B/'operator.py','namespace_operator');operator.restore_objects()
  cls.tmp=tempfile.TemporaryDirectory();d=pathlib.Path(cls.tmp.name);m=json.loads((B/'publication.json').read_text());cls.candidate=m['candidate_helper_commit']
  for name in ['ci-hosted-gate-verify.py','ci-hosted-transport.py']:
   (d/name).write_bytes(subprocess.check_output(['git','show',cls.candidate+':scripts/ci/'+name],cwd=R))
  cls.checkers=[load(d/'ci-hosted-gate-verify.py','pinned_candidate_checker'),load(B/'runtime/ci-hosted-gate-verify.py','generated_bundle_checker')]
  cls.fixtures=load(R/'scripts/ci/ci-hosted-gate-verify.test.py','synthetic_scenario_builders')
  cls.ref=json.loads((B/'canary-freeze.json').read_text())['identity']['fixture_ref']
  cls.hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OLD.iterdir() if p.is_file()}
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def fixture(self,scenario,index=0):
  d=self.fixtures.scenario_fixture(scenario,901+index)
  before=d['expected']['fixture_ref'];after=self.ref
  # Explicit synthetic data; never write altered retained hosted evidence.
  return json.loads(json.dumps(d).replace(before,after).replace(before.removeprefix('refs/heads/'),after.removeprefix('refs/heads/')))
 def test_actual_command_failure_is_reproduced_without_changing_records(self):
  r=subprocess.run(['python3',str(OLD/'runtime/ci-hosted-gate-verify.py'),'--mode','canary','--scenario','full-pass','--evidence',str(OLD/'canary-evidence.json')],capture_output=True,text=True)
  self.assertEqual(r.returncode,1);self.assertIn('fixture ref is outside the scoped namespace',r.stderr)
 def test_all_six_cases_reach_artifact_and_job_checks_in_both_checkers(self):
  for v in self.checkers:
   for i,name in enumerate(v.SCENARIOS):
    with self.subTest(checker=v.__name__,scenario=name):
     d=self.fixture(name,i);result=v.verify_scenario(d,name,d);self.assertIn(result['status'],['verified','verified_non_green'])
 def test_all_six_source_matrix_in_both_checkers(self):
  for v in self.checkers:
   d=self.fixture('full-pass');d['scenarios']={name:self.fixture(name,i) for i,name in enumerate(v.SCENARIOS)};d['budget']['actual_jobs']=45
   result,count=v.verify_sources(d);self.assertEqual(len(result),6);self.assertGreater(count,0)
 def test_actual_hosted_verifier_step_consumes_compatible_matrix(self):
  v=self.checkers[0];d=self.fixture('full-pass');d['scenarios']={name:self.fixture(name,i) for i,name in enumerate(v.SCENARIOS)};d['budget']['actual_jobs']=45
  workflow=subprocess.check_output(['git','show',json.loads((B/'publication.json').read_text())['fixture_workflow_commit']+':.github/workflows/ci.yml'],cwd=R,text=True)
  step=workflow.split('- name: Verify retained source matrix independently',1)[1]
  code=textwrap.dedent(step.split("python3 - <<'PY' > /tmp/253-verifier-result.json\n",1)[1].split('          PY',1)[0])
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);runtime=root/'scripts/ci';runtime.mkdir(parents=True)
   for name in ['ci-hosted-gate-verify.py','ci-hosted-transport.py']:(runtime/name).write_bytes(subprocess.check_output(['git','show',self.candidate+':scripts/ci/'+name],cwd=R))
   payload=base64.b64encode(gzip.compress(json.dumps(d).encode())).decode()
   result=subprocess.run(['python3','-'],input=code,text=True,capture_output=True,cwd=root,env={**os.environ,'MATRIX_EVIDENCE':payload,'PYTHONDONTWRITEBYTECODE':'1'})
   self.assertEqual(result.returncode,0,result.stderr);output=json.loads(result.stdout);self.assertEqual(output['status'],'sources_verified');self.assertEqual(len(output['scenarios']),6)
 def test_wrong_namespace_rejected_in_both_checkers(self):
  for v in self.checkers:
   for ref in ['refs/heads/main','refs/heads/gsd/253-proof-16800f431-next-fixture','refs/heads/gsd/253-replan']:
    d=self.fixture('full-pass');d['expected']['fixture_ref']=ref
    with self.subTest(checker=v.__name__,ref=ref),self.assertRaises(v.VerificationError):v.verify_scenario(d,'full-pass',d)
 def test_cross_ref_commit_and_artifact_are_rejected(self):
  for v in self.checkers:
   for field in ['head_branch','head_sha','artifact']:
    d=self.fixture('full-pass')
    if field=='artifact':d['retained_artifact']['archive_sha256']='0'*64
    else:d['run'][field]='gsd/253-replan-other' if field=='head_branch' else '0'*40
    with self.subTest(checker=v.__name__,field=field),self.assertRaises(v.VerificationError):v.verify_scenario(d,'full-pass',d)
 def test_no_original_attempt_or_closed_window_changed(self):
  self.assertEqual(self.hashes,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OLD.iterdir() if p.is_file()})
  s=json.loads((OLD/'run-state.json').read_text());self.assertEqual((s['status'],s['stage']),('halted','closed'));self.assertFalse((B/'run-state.json').exists())
if __name__=='__main__':unittest.main()
