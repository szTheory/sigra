"""Offline contract regressions. Synthetic values are never saved as hosted evidence."""
from unittest import mock
import base64,copy,importlib.util,json,os,pathlib,subprocess,sys,tempfile,time,unittest
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g

def load(path,name):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
class Paired(unittest.TestCase):
 def test_existing_ledgers_or_partial_outputs_reject_before_start(self):
  with tempfile.TemporaryDirectory() as td:
   d=pathlib.Path(td)
   with mock.patch.object(g,'B',d):
    g.require_unused_attempt()
    for name in ['run-state.json','publication-ledger.json','prs-ledger.json','normal-evidence.json','publication-request-1.json','command-1.json']:
     (d/name).write_text('{}')
     with self.subTest(name=name),self.assertRaises(g.Refusal):g.require_unused_attempt()
     (d/name).unlink()
 def test_new_approval_exact_scope_hash_expiry(self):
  a=dict(schema='sigra.phase253.paired-approval/v1',decision='approve',bundle_sha256='a'*64,scope='normal-and-docs-only',approved_at_epoch=100,expires_epoch=200,decision_text='yes')
  g.validate_approval(a,'a'*64,150)
  for key,value in [('schema','sigra.phase253.docs-continuation-approval/v1'),('bundle_sha256','b'*64),('scope','docs-only'),('expires_epoch',149),('decision_text',''),('decision','deny')]:
   with self.subTest(key=key),self.assertRaises(g.Refusal):g.validate_approval(dict(a,**{key:value}),'a'*64,150)
 def test_publication_exact_request_and_no_fixture(self):
  plan=g.read(B/'candidate-requests.json');refs=g.read(B/'objects.json')['refs']
  self.assertEqual(len(refs),3);self.assertEqual([x['request']['body']['ref'] for x in plan if x['request']['route_id']=='create_ref'],[refs[0].join(['refs/heads/',''])])
  rows=[dict(route_id='rate_limit',actual_status=200,response_body_base64=base64.b64encode(json.dumps({'resources':{'core':{'remaining':999}}}).encode()).decode()),dict(route_id='get_ref',actual_status=200,response_body_base64=base64.b64encode(json.dumps({'object':{'sha':g.read(B/'objects.json')['known_parent_sha']}}).encode()).decode())]
  rows += [dict(actual_status=404) for _ in range(3)]
  g.check_request(plan[0]['request'],rows,'publication')
  changed=copy.deepcopy(plan[0]['request']);changed['body']['encoding']='utf-8'
  with self.assertRaises(g.Refusal):g.check_request(changed,rows,'publication')
  rows[2]['actual_status']=200
  with self.assertRaisesRegex(g.Refusal,'already exists'):g.check_request(plan[0]['request'],rows,'publication')
 def test_main_change_and_rate_limit_stop_before_write(self):
  rq=dict(method='GET',route_id='get_ref',category='preflight',params={'branch':g.read(B/'objects.json')['refs'][0]})
  def tx(route,data):return dict(route_id=route,actual_status=200,response_body_base64=base64.b64encode(json.dumps(data).encode()).decode())
  rows=[tx('rate_limit',{'resources':{'core':{'remaining':250}}}),tx('get_ref',{'object':{'sha':'0'*40}})]
  with self.assertRaisesRegex(g.Refusal,'core <=250'):g.check_request(rq,rows,'publication')
  rows[0]=tx('rate_limit',{'resources':{'core':{'remaining':1000}}})
  with self.assertRaisesRegex(g.Refusal,'main changed'):g.check_request(rq,rows,'publication')
 def test_dispatch_rerun_and_error_always_stop(self):
  for req in [dict(route_id='dispatch'),dict(route_id='cancel_run'),dict(category='infrastructure_rerun'),dict(method='PATCH')]:
   with self.subTest(req=req),self.assertRaises(g.Refusal):g.check_request(req,[],'prs')
  for status in [403,429]:
   with self.assertRaises(g.Refusal):g.check_request(dict(method='GET',family='shared'),[dict(actual_status=status)],'prs')
 def test_publication_requests_fit_real_transport(self):
  transport=load(B/'runtime/ci-hosted-transport.py','test_transport');a=g.read(B/'publication-allocation-template.json');a['source_sha256']='a'*64;transport._validate_allocation(a)
  self.assertLessEqual(5+len(g.read(B/'candidate-requests.json')),24)
  for x in g.read(B/'candidate-requests.json'):transport._route(x['request'],a)
 def test_actual_transport_startup_reaches_missing_approval_without_network(self):
  with tempfile.TemporaryDirectory() as td:
   d=pathlib.Path(td);(d/'sitecustomize.py').write_text('import socket\ndef denied(*a,**k): raise RuntimeError("NETWORK_ATTEMPT_FORBIDDEN")\nsocket.socket.connect=denied\nsocket.create_connection=denied\n')
   rq=d/'request.json';rq.write_text(json.dumps(dict(method='GET',route_id='rate_limit',category='preflight')))
   p=subprocess.run([sys.executable,'-B',B/'runtime/ci-hosted-transport.py','--allocation',d/'absent-allocation.json','--ledger',d/'absent-ledger.json','--request',rq,'--output',d/'out.json'],cwd=g.ROOT,env={**os.environ,'PYTHONPATH':str(d)},capture_output=True,text=True)
   self.assertNotEqual(p.returncode,0);self.assertIn('new paired proof approval missing',p.stderr);self.assertNotIn('ModuleNotFoundError',p.stderr);self.assertNotIn('NETWORK_ATTEMPT_FORBIDDEN',p.stderr);self.assertFalse((d/'absent-ledger.json').exists())
 def test_actual_shell_family_startup_rejects_old_approval(self):
  old=g.ROOT/'.planning/execution/253-docs-continuation-pr341-fixed/prs-approval.json'
  p=subprocess.run(['bash',B/'runtime/ci-pr-proof.sh','--family','docs-only','--freeze',B/'pr-freeze-template.json','--allocation',B/'not-allocated.json','--requests',B/'not-ledger.json','--evidence',B/'not-evidence.json','--revision-freeze',B/'actions.json','--action-approval',old],capture_output=True,text=True)
  self.assertNotEqual(p.returncode,0);self.assertIn('approval refused',p.stderr);self.assertIn('section digest',p.stderr);self.assertNotIn('ModuleNotFoundError',p.stderr);self.assertFalse((B/'not-ledger.json').exists())
 def test_operator_cannot_start_without_new_approval(self):
  p=subprocess.run([sys.executable,'-B',B/'run_pair.py','--run'],capture_output=True,text=True)
  self.assertNotEqual(p.returncode,0);self.assertIn('new paired proof approval missing',p.stderr);self.assertFalse((B/'run-state.json').exists())
 def test_independent_consumer_rejects_old_actual_pair(self):
  v=load(B/'verify_pair.py','pair_consumer');old=g.ROOT/'.planning/execution/253-proof-bundle-a6838a8f9'
  normal=g.read(old/'normal-evidence.json');docs=g.read(g.ROOT/'.planning/execution/253-docs-continuation-pr341-fixed/docs-only-evidence.json')
  with self.assertRaises(g.Refusal):v.validate_source(normal,docs,g.read(B/'pr-freeze-template.json'),'a'*64)
 def test_consumer_requires_identical_exact_new_freeze(self):
  v=load(B/'verify_pair.py','consumer_exact');template=g.read(B/'pr-freeze-template.json');fr=copy.deepcopy(template);fr['source']['publication_receipt_sha256']='a'*64;fr['source']['fetched_main_sha']=template['source']['server_parent_sha'];fr['bound_documents']=g.bindings();fr['freeze_sha256']=g.sha(g.canonical(fr))
  v.validate_source({'freeze':fr},{'freeze':copy.deepcopy(fr)},template,'a'*64)
  for key,value in [('source_sha','0'*40),('publication_receipt_sha256','b'*64)]:
   changed=copy.deepcopy(fr);changed.pop('freeze_sha256');changed['source'][key]=value;changed['freeze_sha256']=g.sha(g.canonical(changed))
   with self.subTest(key=key),self.assertRaises(g.Refusal):v.validate_source({'freeze':changed},{'freeze':changed},template,'a'*64)
 def test_draft_creation_is_exact_and_once_per_family(self):
  fr=g.read(B/'pr-freeze-template.json')
  with mock.patch.object(g,'read',return_value=fr):
   for family in ['normal','docs-only']:
    body=dict(title=f'Phase 253 {family} CI proof (draft, do not merge)',head=fr[family]['head_ref'],base=fr[family]['base_ref'],body='Draft proof pull request; never merged.',draft=True)
    req=dict(method='POST',route_id='pr_create',category='pr_create',family=family,body=body)
    g.check_request(req,[],'prs')
    with self.assertRaises(g.Refusal):g.check_request(req,[dict(route_id='pr_create',family=family)],'prs')
    body['draft']=False
    with self.assertRaises(g.Refusal):g.check_request(req,[],'prs')
 def test_paired_action_freeze_has_only_two_prs_and_docs_objects(self):
  pub=load(B/'runtime/ci-git-publication.py','policy_test')
  fr,raw=pub.load_freeze(B/'actions.json')
  self.assertEqual(pub.section_sha256(fr,'docs_and_prs'),fr['outward_actions_sha256']['docs_and_prs'])
  actions=fr['outward_actions']['docs_and_prs']['actions']
  self.assertEqual([a['action'] for a in actions],['publish_docs_objects','pr_create','pr_create'])
  self.assertNotIn('canary',fr['outward_actions'])
  with self.assertRaises(g.Refusal):pub.load_freeze(g.ROOT/'.planning/execution/253-proof-bundle-a6838a8f9/canary-freeze.json')
 def test_independent_consumer_rejects_missing_real_collection(self):
  p=subprocess.run([sys.executable,'-B',B/'verify_pair.py','--write-result'],capture_output=True,text=True)
  self.assertNotEqual(p.returncode,0);self.assertFalse((B/'requirements-result.json').exists())
 def test_publication_consumer_checks_complete_exact_live_response_bytes(self):
  # Unit fixtures in a disposable directory; never run data or requirements evidence.
  v=load(B/'verify_pair.py','publication_consumer_test');transport=load(B/'runtime/ci-hosted-transport.py','publication_transport_test')
  original_bindings=g.bindings();bundle,_=g.verify_bundle()
  with tempfile.TemporaryDirectory() as td:
   d=pathlib.Path(td);(d/'runtime').symlink_to(B/'runtime',target_is_directory=True)
   for name in ['bundle.json','objects.json','candidate-requests.json','publication-allocation-template.json']:(d/name).write_bytes((B/name).read_bytes())
   a=g.read(B/'publication-allocation-template.json');a['source_sha256']=g.sha((d/'bundle.json').read_bytes());a['bound_documents']=original_bindings
   (d/'publication-allocation.json').write_text(json.dumps(a))
   plan=g.read(B/'candidate-requests.json');requests=[dict(method='GET',route_id='rate_limit',category='preflight'),dict(method='GET',route_id='get_ref',category='preflight',params={'branch':'main'})]
   requests += [dict(method='GET',route_id='get_ref',category='preflight',params={'branch':r}) for r in g.read(B/'objects.json')['refs']]
   requests += [x['request'] for x in plan];rows=[]
   for i,rq in enumerate(requests):
    response=({'resources':{'core':{'remaining':1000}}} if i==0 else {'object':{'sha':bundle['parent_sha']}} if i==1 else {} if i<5 else plan[i-5]['expected'])
    raw=json.dumps(response).encode();host,port,body,path=transport._route(rq,a);url='https://'+host+path
    rows.append(dict(sequence=i+1,state='complete',window_id=a['window_id'],source_sha256=a['source_sha256'],method=rq['method'],route_id=rq['route_id'],category=rq['category'],host=host,url=url,url_sha256=g.sha(url.encode()),request_body_sha256=g.sha(body) if body is not None else None,response_body_base64=base64.b64encode(raw).decode(),response_sha256=g.sha(raw),scrubbed_response_bytes=len(raw),actual_status=200 if i<2 else 404 if i<5 else plan[i-5]['expect'],started_monotonic_ns=i*100,ended_monotonic_ns=i*100+1))
   ledger=dict(allocation_sha256=g.sha((d/'publication-allocation.json').read_bytes()),window_id=a['window_id'],source_sha256=a['source_sha256'],transactions=rows)
   def write():
    (d/'publication-ledger.json').write_text(json.dumps(ledger));(d/'publication-receipt.json').write_text(json.dumps(dict(schema='sigra.phase253.paired-candidate-publication/v1',mode='live',candidate_sha=bundle['candidate_sha'],parent_sha=bundle['parent_sha'],ledger_sha256=g.sha((d/'publication-ledger.json').read_bytes()),allocation_sha256=g.sha((d/'publication-allocation.json').read_bytes()),complete=True)))
   write()
   with mock.patch.object(v,'B',d),mock.patch.object(g,'B',d),mock.patch.object(g,'verify_bundle',return_value=(bundle,'unit-fixture')),mock.patch.object(g,'bindings',return_value=original_bindings):
    self.assertEqual(v.verify_publication(),len(rows))
    for field,value in [('response_sha256','0'*64),('request_body_sha256','0'*64),('actual_status',500),('window_id','old-closed-window')]:
     old=rows[-1][field];rows[-1][field]=value;write()
     with self.subTest(field=field),self.assertRaises(g.Refusal):v.verify_publication()
     rows[-1][field]=old
    rows.pop();write()
    with self.assertRaises(g.Refusal):v.verify_publication()
 def test_self_check_uses_real_shell_with_network_disabled(self):
  with tempfile.TemporaryDirectory() as td:
   d=pathlib.Path(td);(d/'sitecustomize.py').write_text('import socket\ndef denied(*a,**k): raise RuntimeError("NETWORK_ATTEMPT_FORBIDDEN")\nsocket.socket.connect=denied\nsocket.create_connection=denied\n')
   p=subprocess.run([sys.executable,'-B',B/'run_pair.py','--self-check'],env={**os.environ,'PYTHONPATH':str(d)},capture_output=True,text=True,timeout=120)
   self.assertEqual(p.returncode,0,p.stderr);self.assertIn('paired_bundle_verified_offline',p.stdout);self.assertNotIn('NETWORK_ATTEMPT_FORBIDDEN',p.stderr)
if __name__=='__main__':unittest.main()
