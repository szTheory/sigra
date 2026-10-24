import copy,json,pathlib,unittest
from discovery_candidate import candidates,validate,Refusal
B=pathlib.Path(__file__).resolve().parent

def response(name):
 s=(B/name).read_text();return json.loads(s[s.index('{'):])

class Discovery(unittest.TestCase):
 def setUp(self):
  self.checks=response('head-checks.http');self.run=response('run-39815188159.http')
  self.identity=dict(run_id=39815188159,repository_id=1207487684,workflow_id=259268962,pr_number=343,head_sha='c8443e2bd9576bb0284d6c78a7212659a5af85fd',head_ref='gsd/253-replan-proof-5e13621e5-candidate',base_sha='09df342a82e03c3d5d40173c912b70e827f7eadc',base_ref='main')
 def test_actual_empty_listing_contradicts_actual_direct_run(self):
  self.assertEqual(response('branch-runs.http')['workflow_runs'],[])
  self.assertEqual(candidates(self.checks,'szTheory/sigra',self.identity['head_sha']),[39815188159])
  self.assertEqual(validate(self.run,**self.identity),39815188159)
  self.assertEqual(self.run['status'],'queued') # Discovery never claims a passing run.
 def test_reject_other_run_source_workflow_event_attempt_or_repository(self):
  for k,v in [('id',1),('head_sha','0'*40),('workflow_id',1),('event','workflow_dispatch'),('run_attempt',2),('head_branch','wrong')]:
   with self.subTest(field=k),self.assertRaises(Refusal):validate(dict(self.run,**{k:v}),**self.identity)
  with self.assertRaises(Refusal):validate(dict(self.run,repository={'id':1}),**self.identity)
 def test_reject_missing_other_or_duplicate_pr(self):
  for prs in [[],[dict(self.run['pull_requests'][0],number=342)],self.run['pull_requests']*2]:
   with self.subTest(prs=prs),self.assertRaises(Refusal):validate(dict(self.run,pull_requests=prs),**self.identity)
 def test_reject_mismatched_pr_base_or_head(self):
  for side in ['head','base']:
   for key,value in [('sha','0'*40),('ref','wrong'),('repo',{'id':1})]:
    r=copy.deepcopy(self.run);r['pull_requests'][0][side][key]=value
    with self.subTest(side=side,key=key),self.assertRaises(Refusal):validate(r,**self.identity)
 def test_untrusted_check_url_app_or_source_is_not_a_hint(self):
  first=self.checks['check_runs'][0]
  for change in [{'head_sha':'0'*40},{'app':{'id':1}},{'details_url':first['details_url'].replace('github.com','evil.example')},{'details_url':first['details_url'].replace('szTheory/sigra','other/repo')}]:
   self.assertEqual(candidates({'total_count':1,'check_runs':[dict(first,**change)]},'szTheory/sigra',self.identity['head_sha']),[])
 def test_truncated_checks_do_not_claim_absence(self):
  with self.assertRaises(Refusal):candidates({'total_count':101,'check_runs':[]},'szTheory/sigra',self.identity['head_sha'])

if __name__=='__main__':unittest.main()
