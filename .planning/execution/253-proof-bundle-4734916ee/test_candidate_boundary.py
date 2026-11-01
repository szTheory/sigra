"""Export and execute the exact proposed product candidate, retaining its parent planning layout."""
import hashlib,json,os,pathlib,subprocess,sys,tempfile,unittest
B=pathlib.Path(__file__).resolve().parent;R=B.parents[2]
import importlib.util
spec=importlib.util.spec_from_file_location('candidate_boundary_operator',B/'operator.py');op=importlib.util.module_from_spec(spec);spec.loader.exec_module(op)
class CandidateBoundary(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  op.restore_objects();cls.tmp=tempfile.TemporaryDirectory(prefix='253-repaired-candidate-');cls.root=pathlib.Path(cls.tmp.name)
  cls.manifest=json.loads((B/'publication.json').read_text());candidate=cls.manifest['candidate_helper_commit']
  data=subprocess.check_output(['git','archive',candidate],cwd=R)
  subprocess.run(['tar','-x','-C',str(cls.root)],input=data,check=True)
  subprocess.run(['git','init','--quiet',str(cls.root)],check=True)
  subprocess.run(['git','add','.'],cwd=cls.root,check=True)
  (cls.root/'test/example/priv/playwright/node_modules').symlink_to(R/'test/example/priv/playwright/node_modules',target_is_directory=True)
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def run_node(self,args,env=None):
  return subprocess.run(['node',*args],cwd=self.root,text=True,capture_output=True,env={**os.environ,**(env or {})})
 def test_candidate_keeps_old_parent_ledger_and_uses_exact_source_fixture(self):
  path='.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md'
  parent=subprocess.check_output(['git','show',self.manifest['server_parent_sha']+':'+path],cwd=R)
  self.assertEqual((self.root/path).read_bytes(),parent)
  fixture='test/fixtures/prohibitions/retained-236-evidence.md'
  self.assertEqual((self.root/fixture).read_bytes(),subprocess.check_output(['git','show',op.g.SOURCE+':'+fixture],cwd=R))
  self.assertTrue(self.manifest['product_tree_parity']['same_paths_modes_blobs'])
 def test_all_candidate_prohibition_checks(self):
  files=sorted(str(p.relative_to(self.root)) for p in (self.root/'scripts/ci/prohibitions').glob('*.test.mjs'))
  result=self.run_node(['--test','--test-reporter=tap',*files]);self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('# pass 118',result.stdout)
 def test_candidate_rejects_known_bad_historical_claim(self):
  result=self.run_node(['--test','--test-reporter=tap','scripts/ci/prohibitions/p12-run-id-provenance.test.mjs'],{'GSD_PROHIB_SUBJECT':'test/fixtures/prohibitions/p12-phase236-claim-without-run-id.md'})
  self.assertNotEqual(result.returncode,0);self.assertIn('# fail 2',result.stdout)
 def test_actual_candidate_html_reporter_and_record_checks(self):
  result=self.run_node(['--test','--test-reporter=tap','scripts/ci/ci-browser-report-retention.test.mjs','scripts/ci/ci-browser-records.test.mjs','scripts/ci/ci-playwright-report.test.mjs'])
  self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('# pass 35',result.stdout)
if __name__=='__main__':unittest.main(verbosity=2)
