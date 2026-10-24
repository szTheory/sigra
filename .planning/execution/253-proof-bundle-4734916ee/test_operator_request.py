import importlib.util,json,pathlib,sys,tempfile,unittest
HERE=pathlib.Path(__file__).resolve().parent
ORIGINAL=HERE
sys.path.insert(0,str(ORIGINAL/'runtime'))
s=importlib.util.spec_from_file_location('fixed_operator',HERE/'operator.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class RequestTests(unittest.TestCase):
 def check_stage(self,stage,route,params=None):
  with tempfile.TemporaryDirectory() as tmp:
   oldB,oldExecute=m.B,m.execute;m.B=pathlib.Path(tmp)
   observed={}
   def capture(args,state):
    observed.update(json.loads(pathlib.Path(args[args.index('--request')+1]).read_text()))
    pathlib.Path(args[args.index('--output')+1]).write_text(json.dumps({'actual_status':200}))
    pathlib.Path(args[args.index('--body-output')+1]).write_text('{}')
   m.execute=capture
   try:m.request(stage,'preflight',route,params)
   finally:m.B,m.execute=oldB,oldExecute
   return observed
 def test_prs_rate_is_shared(self):self.assertEqual(self.check_stage('prs','rate_limit')['family'],'shared')
 def test_prs_main_is_shared(self):
  req=self.check_stage('prs','get_ref',{'branch':'main'});self.assertEqual(req['family'],'shared');self.assertEqual(req['params'],{'branch':'main'})
 def test_canary_unchanged(self):self.assertNotIn('family',self.check_stage('canary','rate_limit'))

class StartupTests(unittest.TestCase):
 def test_generated_run_reaches_both_typed_pr_preflights_before_collector(self):
  # Stub only external effects in a disposable directory. Real run(), activate(),
  # request() and once-only run-state writes execute; no real approval is created.
  from unittest.mock import patch
  import types
  original=m.B
  with tempfile.TemporaryDirectory(prefix='synthetic-pr-startup-') as tmp:
   root=pathlib.Path(tmp)
   for name in ['allocation-templates.json','canary-freeze.json','bundle.json','publication.json']:(root/name).write_bytes((original/name).read_bytes())
   (root/'live-approval.json').write_text('{}')
   manifest=json.loads((original/'publication.json').read_text());requests=[]
   class StopAfterStartup(Exception):pass
   def fake_execute(args,state=None,capture=False):
    args=[str(a) for a in args]
    if '--request' in args:
     req=json.loads(pathlib.Path(args[args.index('--request')+1]).read_text());requests.append(req)
     pathlib.Path(args[args.index('--output')+1]).write_text(json.dumps({'actual_status':404 if req['route_id']=='get_ref' and req.get('params',{}).get('branch')!='main' else 200}))
     body={'resources':{'core':{'remaining':1000}}} if req['route_id']=='rate_limit' else {'object':{'sha':manifest['server_parent_sha']}}
     pathlib.Path(args[args.index('--body-output')+1]).write_text(json.dumps(body))
     ledger=pathlib.Path(args[args.index('--ledger')+1]);transactions=json.loads(ledger.read_text())['transactions'] if ledger.exists() else [];transactions.append(req);ledger.write_text(json.dumps({'transactions':transactions}))
    elif '--prepare' in args:pathlib.Path(args[args.index('--output')+1]).write_text('{"bound_documents":[]}')
    elif '--family' in args:
     self.assertEqual(args[args.index('--family')+1],'normal');raise StopAfterStartup()
   pub=types.SimpleNamespace(check_section_approval=lambda *a:None,merge_preflight=lambda *a:{'clean':True})
   with patch.object(m,'B',root),patch.object(m,'ROOT',root),patch.object(m,'execute',side_effect=fake_execute),patch.object(m,'restore_objects'),patch.object(m,'loadmod',return_value=pub),patch.object(m.g,'approval',return_value=(json.loads((original/'bundle.json').read_text()),{})),patch.object(m.g,'committed'),patch.object(m.g,'git',return_value=manifest['server_parent_sha'].encode()):
    with self.assertRaises(StopAfterStartup):m.run()
   prs=requests[-2:];self.assertEqual([r['route_id'] for r in prs],['rate_limit','get_ref']);self.assertEqual([r['family'] for r in prs],['shared','shared']);self.assertEqual(prs[1]['params'],{'branch':'main'})
   state=json.loads((root/'run-state.json').read_text());self.assertEqual((state['status'],state['stage']),('halted','closed'));self.assertTrue(state['canary_verified']);self.assertFalse((original/'run-state.json').exists())

if __name__=='__main__':unittest.main(verbosity=2)
