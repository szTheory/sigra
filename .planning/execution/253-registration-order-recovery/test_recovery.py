"""Read-only recovery checks. No application/database/browser is started."""
import importlib.util,json,pathlib,subprocess,tarfile,unittest,tempfile,shutil
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('order_extractor',HERE/'extract.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class RecoveryTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  with tarfile.open(module.ARCHIVE,'r:gz') as t:cls.log=t.extractfile(f'./raw/families/{module.RUN}/failed-job.log').read().decode()
 def test_authenticate_and_recover_original(self):
  self.assertEqual(module.extract(),json.loads((HERE/'recovered-order.json').read_text()))
 def test_missing_row_rejected(self):
  row=next(x for x in self.log.splitlines() if module.PATTERN.match(x));self.assertRaisesRegex(ValueError,'incomplete',module.parse_order,self.log.replace(row,'',1))
 def test_duplicate_row_rejected(self):
  row=next(x for x in self.log.splitlines() if module.PATTERN.match(x));self.assertRaisesRegex(ValueError,'duplicated',module.parse_order,self.log+'\n'+row)
 def test_wrong_project_rejected(self):
  self.assertRaisesRegex(ValueError,'project ordering',module.parse_order,self.log.replace('[admin-eval-dark]','[admin-eval]',1))
 def test_failure_must_be_selected_target(self):
  row=next(x for x in self.log.splitlines() if module.PATTERN.match(x) and '✘' in x)
  self.assertRaisesRegex(ValueError,'failure identity',module.parse_order,self.log.replace(row,row.replace('board-mg-9/populated','board-mg-8/populated'),1))
 def test_collected_selection_matches_historical_project_prefix(self):
  report=json.loads((HERE/'selection-list.stdout').read_text());actual=[]
  def walk(s):
   for p in s.get('specs',[]):actual.append(p['title'])
   for child in s.get('suites',[]):walk(child)
  walk(report);expected=json.loads((HERE/'recovered-order.json').read_text())['dark_project_prefix']
  self.assertEqual(actual,[r['title'].split(' › ')[-1] for r in expected]);self.assertEqual(len(actual),33)
  self.assertEqual(report['stats']['expected'],0) # --list never means passed tests
 def test_preview_has_no_launch(self):
  proc=subprocess.run(['node',str(HERE/'replay.mjs')],capture_output=True,text=True)
  self.assertEqual(proc.returncode,0,proc.stderr);self.assertEqual(json.loads(proc.stdout)['mode'],'preview')
 def test_run_without_new_approval_stops_before_reservation(self):
  marker=HERE/'diagnostic-reservation.json';before=marker.read_bytes() if marker.exists() else None
  proc=subprocess.run(['node',str(HERE/'replay.mjs'),'--run'],capture_output=True,text=True)
  self.assertNotEqual(proc.returncode,0);self.assertIn('new explicit diagnostic approval is required',proc.stderr)
  self.assertEqual(marker.read_bytes() if marker.exists() else None,before)
 def test_unknown_argument_rejected(self):
  proc=subprocess.run(['node',str(HERE/'replay.mjs'),'--repeat'],capture_output=True,text=True)
  self.assertNotEqual(proc.returncode,0);self.assertIn('unknown argument',proc.stderr)
 def test_real_utf8_setup_and_app_ready(self):
  r=json.loads((HERE/'setup-check-output/result.json').read_text())
  self.assertEqual(r['outcome'],'setup_and_app_readiness_verified');self.assertEqual(r['browser_invocations'],0)
  init=next(x for x in r['steps'] if x['name']=='initdb');self.assertIn('--encoding=UTF8',init['args'])
  self.assertEqual(next(x for x in r['steps'] if x['name']=='setup')['exit_code'],0)
  self.assertTrue(all(x['descendants_reaped'] for x in r['steps']))
 def test_native_replay_completed_exactly_once_per_case(self):
  report=json.loads((HERE/'browser-output/browser.log').read_text());rows=[]
  def walk(s):
   for spec in s.get('specs',[]):
    for t in spec.get('tests',[]):rows.append((spec['title'],t))
   for child in s.get('suites',[]):walk(child)
  walk(report);expected=json.loads((HERE/'recovered-order.json').read_text())['dark_project_prefix']
  self.assertEqual([x[0] for x in rows],[x['title'].split(' › ')[-1] for x in expected])
  for _,t in rows:
   self.assertEqual(t['projectName'],'admin-eval-dark');self.assertEqual(t['status'],'expected')
   self.assertEqual([(r['status'],r['retry']) for r in t['results']],[('passed',0)])
  self.assertEqual(report['stats']['expected'],33)
  for key in ['unexpected','skipped','flaky']:self.assertEqual(report['stats'][key],0)
  log=(HERE/'browser-output/app.log').read_text();self.assertEqual(log.count('POST /users/log_in'),33)
 def test_full_global_order_is_collected_without_execution(self):
  report=json.loads((HERE/'full-prefix-list.json').read_text());rows=[]
  def walk(s):
   for spec in s.get('specs',[]):
    for t in spec.get('tests',[]):rows.append((spec['title'],t['projectName']))
   for child in s.get('suites',[]):walk(child)
  walk(report);expected=json.loads((HERE/'recovered-order.json').read_text())['native_rows'][:161]
  self.assertEqual(rows,[(r['title'].split(' › ')[-1],r['project']) for r in expected]);self.assertEqual(report['stats']['expected'],0)
 def test_full_prefix_requires_separate_approval(self):
  with tempfile.TemporaryDirectory(prefix='sigra-prefix-guard-') as tmp:
   d=pathlib.Path(tmp)
   for name in ['full-prefix-replay.mjs','full-prefix-proposal.json']:shutil.copyfile(HERE/name,d/name)
   proc=subprocess.run(['node',str(d/'full-prefix-replay.mjs'),'--run','--approved-new-diagnostic'],capture_output=True,text=True)
   self.assertNotEqual(proc.returncode,0);self.assertIn('completed33-test approval does not authorize',proc.stderr)
   self.assertFalse((d/'full-prefix-reservation.json').exists())
 def test_full_prefix_rejects_wrong_approval_identity(self):
  with tempfile.TemporaryDirectory(prefix='sigra-prefix-guard-') as tmp:
   d=pathlib.Path(tmp)
   for name in ['full-prefix-replay.mjs','full-prefix-proposal.json']:shutil.copyfile(HERE/name,d/name)
   (d/'full-prefix-approval.json').write_text(json.dumps({'decision':'approved','proposal_sha256':'0'*64}))
   proc=subprocess.run(['node',str(d/'full-prefix-replay.mjs'),'--run','--approved-new-diagnostic'],capture_output=True,text=True)
   self.assertNotEqual(proc.returncode,0);self.assertIn('approval does not match this proposal',proc.stderr)
   self.assertFalse((d/'full-prefix-reservation.json').exists())
if __name__=='__main__':unittest.main(verbosity=2)
