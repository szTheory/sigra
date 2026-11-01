import base64,copy,hashlib,importlib.util,json,pathlib,sys,unittest
from unittest.mock import patch
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
from collector import collect
from verify import verify,Rejected
D=B.parent/'253-pr343-diagnosis'
def response(name):
    s=(D/name).read_text();return json.loads(s[s.index('{'):])
def fixtures(terminal=False):
    run=response('run-39815188159.http')
    if terminal:run.update(status='completed',conclusion='failure')
    return [response('rate-limit.http'),json.loads((B/'saved-pr.json').read_text()),response('head-checks.http'),run,{'total_count':0,'jobs':[]},{'total_count':0,'artifacts':[]},json.loads((B/'saved-pr.json').read_text())]
def replay(bodies):
    rows=[]
    def call(req):
        g.check_request(req,rows);n=len(rows);body=bodies[n];raw=json.dumps(body).encode()
        row=dict(sequence=n+1,method=req['method'],route_id=req['route_id'],category=req['category'],host='api.github.com',url=urls()[n],state='complete',actual_status=200,error=None,started_monotonic_ns=n*100,ended_monotonic_ns=n*100+50,response_body_base64=base64.b64encode(raw).decode(),response_sha256=hashlib.sha256(raw).hexdigest())
        rows.append(row);return body
    result=collect(call);return result,{'mode':'offline-replay','transactions':rows}
def urls():
    i=g.identity();p='https://api.github.com/repos/szTheory/sigra'
    return ['https://api.github.com/rate_limit',p+'/pulls/343',p+'/commits/'+i['head_sha']+'/check-runs?per_page=100&page=1',p+'/actions/runs/39815188159',p+'/actions/runs/39815188159/attempts/1/jobs?per_page=100&page=1',p+'/actions/runs/39815188159/artifacts?per_page=100&page=1',p+'/pulls/343']
def mutate_body(ledger,n,fn):
    row=ledger['transactions'][n];body=json.loads(base64.b64decode(row['response_body_base64']));fn(body);raw=json.dumps(body).encode();row.update(response_body_base64=base64.b64encode(raw).decode(),response_sha256=hashlib.sha256(raw).hexdigest())
class Recovery(unittest.TestCase):
    def test_actual_empty_listing_recovered_without_workflow_query_or_pr_create(self):
        self.assertEqual(response('branch-runs.http')['workflow_runs'],[])
        result,ledger=replay(fixtures());self.assertEqual(result['collection'],'waiting')
        checked=verify(ledger);self.assertEqual(checked['requests'],4);self.assertFalse(checked['hosted_accepted'])
    def test_terminal_failure_is_not_relabelled_success(self):
        result,ledger=replay(fixtures(True));self.assertEqual(result['conclusion'],'failure')
        self.assertEqual(verify(ledger)['requests'],7);self.assertFalse(verify(ledger)['hosted_accepted'])
    def test_terminal_success_still_requires_browser_and_docs_evidence(self):
        values=fixtures(True);values[3]['conclusion']='success';result,ledger=replay(values)
        self.assertFalse(result['hosted_accepted']);self.assertFalse(verify(ledger)['phase_verified'])
    def test_guard_rejects_post_and_extra_keys_and_wrong_sequence(self):
        for req in [dict(g.requests()[0],method='POST'),dict(g.requests()[0],body={}),g.requests()[1],dict(g.requests()[0],category='preflight')]:
            with self.subTest(request=req),self.assertRaises(g.Refusal):g.check_request(req,[])
        for route in ['pr_create','create_ref','dispatch','cancel_run','rerun']:
            with self.subTest(route=route),self.assertRaises(g.Refusal):g.check_request(dict(g.requests()[0],route_id=route),[])
    def test_closed_or_pending_rows_never_retried(self):
        _,ledger=replay(fixtures())
        for change in [{'state':'pending'},{'actual_status':403},{'actual_status':429},{'error':{'code':'timeout'}}]:
            rows=copy.deepcopy(ledger['transactions'][:1]);rows[0].update(change)
            with self.subTest(change=change),self.assertRaises(g.Refusal):g.check_request(g.requests()[1],rows)
    def test_low_core_stops_after_rate_read(self):
        values=fixtures();values[0]['resources']['core']['remaining']=250
        with self.assertRaises(g.Refusal):replay(values)
    def test_pr_changed_before_or_after_run_rejected(self):
        for n in [1,6]:
            for side in ['head','base']:
                values=fixtures(True);values[n][side]['sha']='0'*40
                with self.subTest(n=n,side=side),self.assertRaises(g.Refusal):replay(values)
    def test_wrong_run_or_rerun_rejected(self):
        for key,val in [('id',1),('run_attempt',2),('event','workflow_dispatch'),('workflow_id',1),('head_sha','0'*40)]:
            values=fixtures();values[3][key]=val
            with self.subTest(key=key),self.assertRaises(ValueError):replay(values)
    def test_incomplete_inventories_rejected(self):
        for n in [2,4,5]:
            values=fixtures(True);values[n]['total_count']=999
            with self.subTest(n=n),self.assertRaises(ValueError):replay(values)
    def test_unrelated_job_rejected(self):
        values=fixtures(True);values[4]={'total_count':1,'jobs':[{'run_id':1,'run_attempt':1,'head_sha':g.identity()['head_sha']}]}
        with self.assertRaises(ValueError):replay(values)
    def test_verifier_rejects_tampered_request_clock_category_hash_and_source(self):
        _,ledger=replay(fixtures(True))
        for field,value in [('method','POST'),('url','https://evil.example'),('category','pr_create'),('state','pending'),('actual_status',403),('response_sha256','0'*64),('started_monotonic_ns',-1),('sequence',99)]:
            changed=copy.deepcopy(ledger);changed['transactions'][3][field]=value
            with self.subTest(field=field),self.assertRaises(Rejected):verify(changed)
        for n,fn in [(3,lambda b:b.update(run_attempt=2)),(1,lambda b:b['head'].update(sha='0'*40)),(2,lambda b:b.update(total_count=999)),(6,lambda b:b.update(draft=False))]:
            changed=copy.deepcopy(ledger);mutate_body(changed,n,fn)
            with self.subTest(n=n),self.assertRaises(Rejected):verify(changed)
    def test_verifier_rejects_truncated_extended_and_premature_ledgers(self):
        _,ledger=replay(fixtures(True))
        for rows in [ledger['transactions'][:-1],ledger['transactions']*2,ledger['transactions'][:4]]:
            with self.assertRaises(Rejected):verify(dict(ledger,transactions=rows))
    def test_seven_request_ceiling(self):
        _,ledger=replay(fixtures(True))
        with self.assertRaises(g.Refusal):g.check_request(g.requests()[0],ledger['transactions'])
    def test_transport_allocation_and_exact_get_paths(self):
        s=importlib.util.spec_from_file_location('transport_test',B/'runtime/ci-hosted-transport.py');t=importlib.util.module_from_spec(s);s.loader.exec_module(t)
        allocation=g.read(B/'allocation-template.json');allocation['source_sha256']='a'*64;t._validate_allocation(allocation)
        for n,req in enumerate(g.requests()):
            host,port,body,path=t._route(req,allocation);self.assertEqual('https://'+host+path,urls()[n]);self.assertIsNone(body)
        for route in ['pr_create','create_ref','dispatch','cancel_run','run_logs','artifact_zip']:
            with self.subTest(route=route),self.assertRaises(t.TransportError):t._route(dict(method='POST',route_id=route),allocation)
        for changed in [dict(allocation,max_requests=120),dict(allocation,category_limits={'pr_create':7})]:
            with self.assertRaises(t.TransportError):t._validate_allocation(changed)
    def test_live_start_requires_new_approval_without_network(self):
        import run
        with patch.object(g,'approval',side_effect=g.Refusal('missing new exact approval')),patch.object(run,'load_transport') as transport:
            with self.assertRaises(g.Refusal):run.run()
            transport.assert_not_called()
if __name__=='__main__':unittest.main()
