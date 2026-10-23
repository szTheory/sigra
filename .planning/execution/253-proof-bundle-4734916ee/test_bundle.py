#!/usr/bin/env python3
"""Offline integration and negative controls; no live permission is created."""
import copy,importlib.util,json,pathlib,subprocess,sys,tempfile,time,unittest
from unittest.mock import patch
B=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(B/'runtime'))
import execution_guard as g
spec=importlib.util.spec_from_file_location('bundle_operator',B/'operator.py');op=importlib.util.module_from_spec(spec);spec.loader.exec_module(op)
def module(name):return op.loadmod(B/'runtime'/name,name.replace('.','_'))
class BundleTests(unittest.TestCase):
 def auth(self):return dict(schema='sigra.phase253.proof-bundle-approval/v1',decision='approve',source_sha=g.SOURCE,bundle_sha256='a'*64,sections=['canary','docs_and_prs'],approved_at_epoch=1000,expires_epoch=2000,decision_text='synthetic test only')
 def window(self,stage='canary'):
  return dict(status='active',stage=stage,source_sha=g.SOURCE,expected_parent='09df342a82e03c3d5d40173c912b70e827f7eadc',parent_verified='09df342a82e03c3d5d40173c912b70e827f7eadc',**{stage+'_started_epoch':1000})
 def alloc(self,stage='canary'):return dict(mode='live',window_id='gsd/253-replan-proof-4734916ee-'+stage+'-1',max_requests=117 if stage=='canary' else 120,max_elapsed_seconds=3600)
 def test_approval_accepts_only_exact_current_bundle(self):g.validate_approval(self.auth(),'a'*64,1500)
 def test_old_approval_rejected(self):
  old=g.read(g.ROOT/'.planning/execution/253-PR-APPROVAL-REQUEST.json')
  with self.assertRaises(g.Refusal):g.validate_approval(old,'a'*64,1500)
 def test_approval_mutations(self):
  changes=[('decision','pending'),('source_sha','0'*40),('bundle_sha256','b'*64),('sections',['canary']),('expires_epoch',1400),('approved_at_epoch',1600),('expires_epoch',90000),('decision_text','')]
  for k,v in changes:
   with self.subTest(k=k,v=v),self.assertRaises(g.Refusal):
    a=self.auth();a[k]=v;g.validate_approval(a,'a'*64,1500)
 def test_window_accepts_both_exact_limits(self):
  for stage in ['canary','prs']:g.validate_window(self.window(stage),self.alloc(stage),stage,1500)
 def test_old_allocation_rejected(self):
  p=next((g.ROOT/'.planning/phases').glob('253-*/253-LOAD-RECOVERY-CANARY-ALLOCATION-R13.json'))
  with self.assertRaises(g.Refusal):g.validate_window(self.window(),g.read(p),'canary',1500)
 def test_closed_and_expired_windows_rejected(self):
  for change in [dict(status='halted'),dict(stage='closed'),dict(canary_started_epoch=0),dict(parent_verified='0'*40),dict(source_sha='0'*40)]:
   with self.subTest(change=change),self.assertRaises(g.Refusal):
    s=self.window();s.update(change);g.validate_window(s,self.alloc(),'canary',4000 if 'canary_started_epoch' in change else 1500)
 def test_increased_caps_or_test_origin_rejected(self):
  for k,v in [('max_requests',118),('max_elapsed_seconds',3601),('window_id','253-170-canary-window-1'),('mode','hermetic-test')]:
   with self.subTest(k=k),self.assertRaises(g.Refusal):
    a=self.alloc();a[k]=v;g.validate_window(self.window(),a,'canary',1500)
 def test_inactive_template_is_not_an_allocation(self):
  t=module('ci-hosted-transport.py')
  for a in g.read(B/'allocation-templates.json')['allocations'].values():
   with self.assertRaises(t.TransportError):t._validate_allocation(a)
 def test_transport_accepts_only_four_fresh_ref_creations(self):
  t=module('ci-hosted-transport.py')
  a=self.alloc();a['allocation_kind']='canary'
  for suffix in ['candidate','fixture','docs-base','docs-head']:
   t._route(dict(method='POST',route_id='create_ref',body=dict(ref='refs/heads/'+g.PREFIX+'-'+suffix,sha='a'*40)),a)
  for ref in ['refs/heads/gsd/253-replan-r13-candidate','refs/heads/gsd/253-replan-proof-4734916ee-other','refs/heads/main']:
   with self.subTest(ref=ref),self.assertRaises(t.TransportError):t._route(dict(method='POST',route_id='create_ref',body=dict(ref=ref,sha='a'*40)),a)
 def test_pr_verifier_ref_pairs(self):
  v=module('ci-hosted-gate-verify.py');v.require_pr_refs('normal',g.PREFIX+'-candidate','main');v.require_pr_refs('docs-only',g.PREFIX+'-docs-head',g.PREFIX+'-docs-base')
  for family,head,base in [('normal','gsd/253-replan-r13-candidate','main'),('docs-only',g.PREFIX+'-docs-head','gsd/253-replan-docs-base')]:
   with self.assertRaises(v.VerificationError):v.require_pr_refs(family,head,base)
 def test_publisher_rejects_old_or_mixed_pair(self):
  p=module('ci-git-publication.py')
  self.assertEqual(p.ref_pair_name('refs/heads/'+g.PREFIX+'-candidate','refs/heads/'+g.PREFIX+'-fixture'),'proof4734916ee')
  with self.assertRaises(p.PublicationError):p.ref_pair_name('refs/heads/gsd/253-replan-r13-candidate','refs/heads/gsd/253-replan-r13-fixture')
 def test_every_request_stops_before_connection_without_approval(self):
  t=module('ci-hosted-transport.py')
  with tempfile.TemporaryDirectory() as tmp:
   d=pathlib.Path(tmp);a=d/'allocation.json';q=d/'request.json';a.write_text(json.dumps(self.alloc()));q.write_text(json.dumps(dict(method='GET',route_id='rate_limit')))
   with patch.object(t,'_connect',side_effect=AssertionError('network reached')) as connect:
    with self.assertRaises(g.Refusal):t.request_one(a,d/'ledger.json',q,d/'receipt.json')
    connect.assert_not_called();self.assertFalse((d/'ledger.json').exists())
 def test_live_operator_refuses_without_writing_attempt(self):
  result=subprocess.run([sys.executable,str(B/'operator.py'),'--run'],capture_output=True,text=True)
  self.assertEqual(result.returncode,1);self.assertIn('new hosted approval has not been recorded',result.stderr);self.assertFalse((B/'run-state.json').exists())
 def test_workflow_and_docs_trigger_are_registered_and_scoped(self):
  m=g.read(B/'publication.json');self.assertEqual(m['workflow_path'],'.github/workflows/ci.yml')
  self.assertEqual(g.git('rev-parse',m['fixture_workflow_commit']+':.github/workflows/ci.yml').decode().strip(),m['fixture_workflow_blob'])
  ci=g.git('show',m['docs_base_commit']+':.github/workflows/ci.yml').decode();self.assertIn('branches: [main, '+g.PREFIX+'-docs-*]',ci);self.assertNotIn('gsd/253-replan-docs-*',ci)
 def test_helpers_rebuild_from_pinned_source_exactly(self):
  prep=op.loadmod(B/'prepare.py','prepare_bundle')
  for name,record in g.read(B/'helper-origins.json').items():
   raw=g.git('show',g.SOURCE+':'+record['source_path']);self.assertEqual(prep.adapt(name,raw),(B/'runtime'/name).read_bytes(),name)
 def test_canary_order_ends_in_independent_verifier(self):
  commands=op.canary_commands();self.assertIn('--publish-only',commands[0]);self.assertIn('--require-live-origin',commands[1]);self.assertIn('--remaining-scenarios',commands[4]);self.assertEqual(commands[-1][-3:-1],['matrix','--evidence'])
 def test_source_and_bundle_mutations_rejected(self):
  original=g.inventory
  with patch.object(g,'inventory',side_effect=lambda c:original(c) if c==g.SOURCE else {b'changed':b'100644 blob bad'}):
   with self.assertRaisesRegex(g.Refusal,'product source changed'):g.verify_bundle()
  original_sha=g.sha
  with patch.object(g,'sha',side_effect=lambda raw:'0'*64 if raw==(B/'publication.json').read_bytes() else original_sha(raw)):
   with self.assertRaisesRegex(g.Refusal,'artifact changed'):g.verify_bundle()
 def test_pipeline_timeout_kills_process_group(self):
  # A deterministic zero-time budget must refuse before even starting a child.
  with patch.object(op.sp,'Popen') as child,self.assertRaises(g.Refusal):op.execute(['must-not-start'],dict(stage='canary',canary_started_epoch=0))
  child.assert_not_called()
 def test_uncommitted_approval_is_rejected(self):
  with tempfile.TemporaryDirectory(prefix='synthetic-uncommitted-',dir=B) as tmp:
   p=pathlib.Path(tmp)/'synthetic.json';p.write_text('{}')
   with self.assertRaisesRegex(g.Refusal,'not committed'):g.committed(p)
 def test_pending_plan_prior_bytes_are_recoverable(self):
  r=g.read(B/'plan172-prior.json');raw=g.git('show',r['commit']+':'+r['path']);self.assertEqual(g.sha(raw),r['sha256']);self.assertEqual(len(raw),r['bytes']);self.assertEqual((g.ROOT/r['path']).read_bytes(),(B/'plan172-current.md').read_bytes())
 def test_all_old_history_paths_still_match_entry(self):
  b,_=g.verify_bundle();changed=g.git('diff','--name-only',b['entry_commit'],'--','.planning/phases',':(exclude).planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-172-PLAN.md','.planning/execution/253-170.json','.planning/execution/253-171.json','.planning/execution/253-hosted-proof-16800f431').strip();self.assertEqual(changed,b'')
 def test_request_guard_rejects_closed_expired_changed_allocation_and_rate_limit(self):
  with tempfile.TemporaryDirectory(prefix='synthetic-window-') as tmp:
   b=pathlib.Path(tmp).resolve();a=b/'canary-allocation.json';l=b/'canary-ledger.json';q=b/'request.json'
   (b/'bundle.json').write_text('{}');(b/'live-approval.json').write_text('{}');q.write_text('{"method":"GET","route_id":"rate_limit","category":"preflight"}')
   allocation=self.alloc();a.write_text(json.dumps(allocation));state=self.window();state.update(bundle_sha256=g.sha(b'{}'),approval_sha256=g.sha(b'{}'),canary_allocation_sha256=g.sha(a.read_bytes()))
   (b/'run-state.json').write_text(json.dumps(state))
   with patch.object(g,'B',b),patch.object(g,'approval',return_value=({},{})),patch.object(g.time,'time',return_value=1500):
    self.assertTrue(g.authorize_request(a,l,q))
    for change in [dict(status='halted'),dict(canary_started_epoch=0),dict(bundle_sha256='0'*64),dict(canary_allocation_sha256='0'*64)]:
     with self.subTest(change=change),self.assertRaises(g.Refusal):
      s=dict(state);s.update(change);(b/'run-state.json').write_text(json.dumps(s));g.authorize_request(a,l,q)
    (b/'run-state.json').write_text(json.dumps(state))
    for code in [403,429]:
     l.write_text(json.dumps(dict(transactions=[dict(actual_status=code)])))
     with self.subTest(code=code),self.assertRaises(g.Refusal):g.authorize_request(a,l,q)
    l.unlink();q.write_text('{"category":"infrastructure_retry"}')
    with self.assertRaises(g.Refusal):g.authorize_request(a,l,q)
 def test_actual_pr_prepare_with_explicit_synthetic_receipt_and_live_rejection(self):
  # A minimal local-fixture receipt exercises the actual subprocess prepare/check modes.
  # The production --require-live-origin gate must reject these same bytes.
  m=g.read(B/'publication.json')
  with tempfile.TemporaryDirectory(prefix='synthetic-pr-prepare-') as tmp:
   d=pathlib.Path(tmp);ledger=d/'ledger.json';ledger.write_text('{"transactions":[]}');receipt=d/'fixture-receipt.json'
   r=dict(schema_version='sigra.phase253.git-publication-receipt/v1',status='published-local-fixture',production_publish_performed=False,origin=dict(kind='synthetic_fixture_only'),source_sha=g.SOURCE,server_parent_sha=m['server_parent_sha'],candidate_sha=m['candidate_helper_commit'],candidate_tree_sha=m['candidate_tree_sha'],fixture_sha=m['fixture_workflow_commit'],fixture_tree_sha=m['fixture_tree_sha'],candidate_workflow_blob=g.git('rev-parse',m['candidate_helper_commit']+':.github/workflows/ci.yml').decode().strip(),fixture_workflow_blob=m['fixture_workflow_blob'],candidate_ref='refs/heads/'+g.PREFIX+'-candidate',fixture_ref='refs/heads/'+g.PREFIX+'-fixture',ledger_path=str(ledger),ledger_sha256=g.sha(ledger.read_bytes()),request_count=0,manifest_sha256=g.sha((B/'publication.json').read_bytes()))
   rows=[dict(kind='parent-preflight',sha=r['server_parent_sha'])]
   for variant in ['candidate','fixture']:
    rows.extend([dict(kind='tree',variant=variant,sha=r[variant+'_tree_sha']),dict(kind='commit',variant=variant,sha=r[variant+'_sha']),dict(kind='workflow-blob',variant=variant,sha=r[variant+'_workflow_blob']),dict(kind='ref',variant=variant,sha=r[variant+'_sha'],ref=r[variant+'_ref'])])
   r['server_object_receipts']=rows;receipt.write_text(json.dumps(r));fr=d/'fixture-freeze.json'
   args=['bash',str(B/'runtime/ci-pr-proof.sh'),'--prepare','--publication',str(receipt),'--manifest',str(B/'publication.json'),'--output',str(fr),'--repo-root',str(g.ROOT),'--poll-interval','60','--bound-document',str(B/'bundle.json')]
   failed=subprocess.run([*args,'--require-live-origin'],capture_output=True,text=True);self.assertNotEqual(failed.returncode,0);self.assertIn('local-fixture origin is rejected',failed.stderr);self.assertFalse(fr.exists())
   prepared=subprocess.run(args,capture_output=True,text=True);self.assertEqual(prepared.returncode,0,prepared.stderr)
   checked=subprocess.run(['bash',str(B/'runtime/ci-pr-proof.sh'),'--check-only','--freeze',str(fr)],capture_output=True,text=True);self.assertEqual(checked.returncode,0,checked.stderr)
   record=json.loads(fr.read_text());self.assertEqual(record['normal']['head_ref'],g.PREFIX+'-candidate');self.assertEqual(record['docs-only']['base_ref'],g.PREFIX+'-docs-base');self.assertEqual(record['docs-only']['base_local_diff_paths'],['.github/workflows/ci.yml'])

if __name__=='__main__':
 # All imported object reads resolve through a temporary pack store, not mutable source objects.
 op.restore_objects();unittest.main(verbosity=2)
