"""Real request_one pipeline, injected connection only: no network or Git mutation."""
import importlib.util,io,json,pathlib,sys,tempfile,unittest
from unittest.mock import patch
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
from test_recovery import fixtures
from collector import collect
from verify import verify

def transport():
    s=importlib.util.spec_from_file_location('transport_pipeline',B/'runtime/ci-hosted-transport.py');t=importlib.util.module_from_spec(s);s.loader.exec_module(t);return t
class Pipeline(unittest.TestCase):
    def exercise(self,status=200,core=4000):
        t=transport();values=fixtures(True);calls=[]
        with tempfile.TemporaryDirectory() as td:
            d=pathlib.Path(td);ap=d/'allocation.json';lp=d/'ledger.json'
            allocation=g.read(B/'allocation-template.json');allocation['source_sha256']='a'*64;ap.write_text(json.dumps(allocation))
            def authorize(a,l,r):g.check_request(g.read(r),g.read(l)['transactions'] if l.exists() else []);return True
            class Connection:
                sock=None
                def request(inner,method,path,body=None,headers=None):
                    # The real transport must persist pending/debited state before HTTP.
                    rows=g.read(lp)['transactions'];self.assertEqual(rows[-1]['state'],'pending')
                    self.assertEqual(len(rows),len(calls)+1);self.assertEqual(method,'GET');self.assertIsNone(body);calls.append(path)
                def getresponse(inner):
                    raw=json.dumps(values[len(calls)-1]).encode()
                    class Response:
                        def __init__(self):self.status=status;self.stream=io.BytesIO(raw)
                        def getheaders(self):return [('Content-Type','application/json'),('X-RateLimit-Resource','core'),('X-RateLimit-Remaining',str(core)),('X-RateLimit-Reset','1792689483')]
                        def read(self,n):return self.stream.read(n)
                    return Response()
                def close(inner):pass
            with patch.object(g,'authorize_request',side_effect=authorize),patch.object(t,'_preserve',return_value=None),patch.object(t,'_connect',return_value=Connection()),patch.dict('os.environ',{'GH_TOKEN':'offline-test-token'}):
                def call(req):
                    n=len(calls);rq=d/f'rq{n}.json';rq.write_text(json.dumps(req));receipt,_,raw,_=t.request_one(ap,lp,rq,d/f'rc{n}.json')
                    if receipt['actual_status']!=200 or receipt.get('terminal_stop'):raise g.Refusal('HTTP stop')
                    return json.loads(raw)
                if status==200 and core>250:
                    collect(call);ledger=g.read(lp);ledger['mode']='offline-replay';self.assertEqual(verify(ledger)['requests'],7)
                    with self.assertRaises(g.Refusal):call(g.requests()[0])
                    self.assertEqual(len(calls),7)
                else:
                    with self.assertRaises((g.Refusal,t.TransportError)):collect(call)
                    self.assertEqual(len(calls),1)
                    with self.assertRaises((g.Refusal,t.TransportError)):call(g.requests()[1])
                    self.assertEqual(len(calls),1)
    def test_actual_pipeline_predebits_seven_gets_and_refuses_eighth(self):self.exercise()
    def test_actual_pipeline_403_429_and_core_stop_do_not_retry(self):
        for status,core in [(403,4000),(429,4000),(200,250)]:
            with self.subTest(status=status,core=core):self.exercise(status,core)
if __name__=='__main__':unittest.main()
