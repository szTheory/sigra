"""Whole entry point with saved HTTP bytes, no network and no Git writes."""
import io,json,pathlib,sys,tempfile,unittest
from unittest.mock import patch
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
import run
from test_recovery import fixtures
class Entry(unittest.TestCase):
    def exercise(self,status=200):
        transport=run.load_transport();values=fixtures(True);calls=[]
        with tempfile.TemporaryDirectory() as td:
            d=pathlib.Path(td).resolve()
            for name in ('identity.json','allocation-template.json'):(d/name).write_bytes((B/name).read_bytes())
            class Connection:
                sock=None
                def request(inner,method,path,**kwargs):calls.append(path)
                def getresponse(inner):
                    raw=json.dumps(values[len(calls)-1]).encode()
                    class Response:
                        def __init__(self):self.status=status;self.stream=io.BytesIO(raw)
                        def getheaders(self):return [('Content-Type','application/json')]
                        def read(self,n):return self.stream.read(n)
                    return Response()
                def close(inner):pass
            # Only authorization identity, preservation and connection are injected.
            # Actual activation, per-request authorization, allocation, ledger, verifier and close run.
            with patch.object(g,'B',d),patch.object(run,'B',d),patch.object(g,'approval',return_value='a'*64),patch.object(run,'load_transport',return_value=transport),patch.object(transport,'preservation_preflight',return_value={}),patch.object(transport,'_preserve',return_value=None),patch.object(transport,'_connect',return_value=Connection()),patch.dict('os.environ',{'GH_TOKEN':'offline-test-token'}):
                if status==200:run.run()
                else:
                    with self.assertRaises((g.Refusal,transport.TransportError)):run.run()
                self.assertTrue(g.read(d/'run-state.json')['closed'])
                self.assertEqual(g.read(d/'attempt-result.json')['requests'],7 if status==200 else 1)
                if status==200:self.assertFalse(g.read(d/'result.json')['hosted_accepted'])
                before=len(calls)
                with self.assertRaises(g.Refusal):run.run()
                self.assertEqual(len(calls),before)
    def test_approved_entrypoint_collects_closes_and_refuses_restart(self):self.exercise()
    def test_entrypoint_closes_after_http_429_without_retry(self):self.exercise(429)
if __name__=='__main__':unittest.main()
