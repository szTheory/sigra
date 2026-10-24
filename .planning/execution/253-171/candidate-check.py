from pathlib import Path
import importlib.util,json,unittest

def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
transport=load('frozen','scripts/ci/ci-hosted-transport.py');candidate=load('candidate',Path(__file__).with_name('json-candidate.py'))
class CandidateChecks(unittest.TestCase):
 def scrub(self,v,secrets=[]):
  _,b=candidate.scrub_json_receipt(transport,[],json.dumps(v).encode(),secrets,[])
  return json.loads(b),b
 def test_patch_escaped_quotes(self):
  v,b=self.scrub({'files':[{'patch':'+ b"url=https://example.invalid/x?access_token=fake-value"\n+ next line'}]})
  self.assertEqual(v,{'files':[{'patch':'+ b"url=https://example.invalid/x?[REDACTED]"\n+ next line'}]});self.assertNotIn(b'fake-value',b)
 def test_credentials_and_known_secrets(self):
  v,b=self.scrub({'password':'fake-password','nested':{'token':'fake-token'},'text':'known-dummy-value'},['known-dummy-value'])
  self.assertEqual(v,{'password':'[REDACTED]','nested':{'token':'[REDACTED]'},'text':'[REDACTED]'})
 def test_types_keys_and_nonsecret_text(self):
  value={'files':[{'patch':'quote " / slash \\ / newline\n / unicode ✓','changes':7}],'ok':True,'nil':None}
  self.assertEqual(self.scrub(value)[0],value)
 def test_sensitive_header_validation_unchanged(self):
  with self.assertRaises(transport.TransportError):candidate.scrub_json_receipt(transport,[('Location','https://bad.invalid/x#fragment')],b'{}',[],[])
if __name__=='__main__':unittest.main()
