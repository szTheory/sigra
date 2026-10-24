import importlib.util,json,pathlib,sys,tempfile,unittest
HERE=pathlib.Path(__file__).resolve().parent
ORIGINAL=HERE.parent/'253-proof-bundle-16800f431-compatible'
sys.path.insert(0,str(ORIGINAL/'runtime'))
s=importlib.util.spec_from_file_location('fixed_operator',HERE/'operator-fixed.py')
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
if __name__=='__main__':unittest.main()
