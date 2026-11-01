"""Real Git preservation regressions; all HTTP responses are isolated unit fixtures."""
import contextlib,hashlib,importlib.util,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest
from unittest import mock
B=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(B/'runtime'))
import execution_guard as g

def load(path,name):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

@contextlib.contextmanager
def repo():
 with tempfile.TemporaryDirectory() as td:
  root=pathlib.Path(td)/'repo';root.mkdir();subprocess.run(['git','init','-q',root],check=True)
  objects=pathlib.Path(td)/'temporary-objects';objects.mkdir();previous=pathlib.Path.cwd()
  with mock.patch.dict(os.environ,{'GIT_OBJECT_DIRECTORY':str(objects),'GIT_ALTERNATE_OBJECT_DIRECTORIES':str(root/'.git/objects')},clear=False):
   try:os.chdir(root);yield root,objects
   finally:os.chdir(previous)

class Preservation(unittest.TestCase):
 def test_original_writer_loses_blob_after_temporary_store_cleanup(self):
  old=load(g.ROOT/'.planning/execution/253-plan172-repaired-source/runtime/ci-hosted-transport.py','original_preserve')
  with repo() as (root,objects):
   p=root/'ledger.json';p.write_text('{"original":true}\n');saved=old._preserve(p);shutil.rmtree(objects)
   result=old.subprocess.run(['git','show',saved['ref']],env={k:v for k,v in os.environ.items() if k not in ('GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES')},capture_output=True)
   self.assertNotEqual(result.returncode,0)
 def test_repeated_actual_ledger_writes_survive_temporary_store_cleanup(self):
  t=load(B/'runtime/ci-hosted-transport.py','fixed_preserve')
  with repo() as (root,objects):
   path=root/'ledger.json';saved=[]
   for i in range(3):
    raw=(json.dumps({'transactions':list(range(i+1))})+'\n').encode();path.write_bytes(raw)
    result=t._preserve(path);saved.append((result,raw));self.assertEqual(result['sha256'],hashlib.sha256(raw).hexdigest())
   shutil.rmtree(objects)
   for result,raw in saved:self.assertEqual(t._persistent_git('show',result['ref']).stdout,raw)
 def test_denied_ref_write_stops_preflight_and_leaves_probe(self):
  t=load(B/'runtime/ci-hosted-transport.py','denied_preserve')
  with repo() as (root,objects):
   real=t._persistent_git
   def denied(*args):
    if args[0]=='update-ref':return subprocess.CompletedProcess(args,1,b'',b'permission denied')
    return real(*args)
   with mock.patch.object(t,'_persistent_git',side_effect=denied),self.assertRaisesRegex(t.TransportError,'permanent recovery ref'):
    t.preservation_preflight(root)
   self.assertEqual(len(list(root.glob('preservation-probe-*.json'))),1)
 def test_actual_preflight_survives_cleanup_and_removes_only_probe(self):
  t=load(B/'runtime/ci-hosted-transport.py','probe_preserve')
  with repo() as (root,objects):
   keep=root/'keep.json';keep.write_text('keep');saved=t.preservation_preflight(root);shutil.rmtree(objects)
   self.assertEqual(t._persistent_git('show',saved['ref']).returncode,0);self.assertFalse(list(root.glob('preservation-probe-*.json')));self.assertEqual(keep.read_text(),'keep')
 def test_operator_preservation_failure_precedes_allocation_and_request(self):
  op=load(B/'run_pair.py','ordering_preserve')
  with mock.patch.object(g,'approval',return_value=({},{})),mock.patch.object(g,'require_unused_attempt'),mock.patch.object(op,'self_check'),mock.patch.object(op,'preservation_preflight',side_effect=g.Refusal('probe denied')),mock.patch.object(op,'save') as save,mock.patch.object(op,'request') as request:
   with self.assertRaisesRegex(g.Refusal,'probe denied'):op.run()
   save.assert_not_called();request.assert_not_called()
 def test_actual_request_one_second_append_retains_first_request(self):
  t=load(B/'runtime/ci-hosted-transport.py','request_preserve')
  class Response:
   status=200;reason='OK'
   def getheaders(self):return [('content-type','application/json')]
   def read(self,limit=None):
    if getattr(self,'read_once',False):return b''
    self.read_once=True;return b'{"unit_fixture":true}'
  class Connection:
   sock=None
   def request(self,*a,**k):pass
   def getresponse(self):return Response()
   def close(self):pass
  with repo() as (root,objects),mock.patch.dict(os.environ,{'GH_TOKEN':'unit-fixture'}):
   allocation=g.read(B/'publication-allocation-template.json');allocation['source_sha256']='a'*64;allocation['bound_documents']=[]
   a=root/'allocation.json';a.write_text(json.dumps(allocation));q=root/'request.json';q.write_text(json.dumps(dict(method='GET',route_id='rate_limit',category='preflight')));ledger=root/'ledger.json'
   with mock.patch.object(g,'authorize_request',return_value=True),mock.patch.object(t,'_connect',return_value=Connection()):
    t.request_one(a,ledger,q,root/'receipt1.json');first=ledger.read_bytes();t.request_one(a,ledger,q,root/'receipt2.json')
   data=json.loads(ledger.read_text());self.assertEqual(len(data['transactions']),2);saved=data['preserved_revisions'][0]
   shutil.rmtree(objects);self.assertEqual(t._persistent_git('show',saved['ref']).stdout,first)
if __name__=='__main__':unittest.main()
