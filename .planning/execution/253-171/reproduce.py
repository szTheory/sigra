"""Offline reproduction against the unchanged frozen transport. No network."""
from pathlib import Path
import importlib.util,json,unittest,hashlib,base64
from unittest.mock import patch
root=Path.cwd();src=root/'scripts/ci/ci-hosted-transport.py'
spec=importlib.util.spec_from_file_location('frozen_transport',src);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class JsonReceiptRegression(unittest.TestCase):
 def test_positive_plain_query_url(self):
  raw=json.dumps({'url':'https://example.invalid/x?access_token=fake-value'}).encode()
  _,out=m.scrub_receipt([],raw,[],[])
  self.assertEqual(json.loads(out),{'url':'https://example.invalid/x?[REDACTED]'})
 def test_compare_patch_with_escaped_quote_must_remain_json(self):
  # Public fake text inside a compare API patch, not a real credential.
  raw=json.dumps({'files':[{'patch':'+ b"url=https://example.invalid/x?access_token=fake-value"\n+ next line'}]}).encode()
  json.loads(raw) # positive control: valid input
  _,out=m.scrub_receipt([],raw,[],[])
  self.assertNotIn(b'fake-value',out)
  json.loads(out) # fails at the escaped closing quote, like actual seq 19
 def test_real_saved_compare_response_is_corrupted(self):
  p=root/'.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R13.json'
  ledger=json.loads(p.read_text());row=ledger['transactions'][-1]
  self.assertEqual((row['sequence'],row['route_id'],row['actual_status']),(19,'compare',200))
  raw=base64.b64decode(row['response_body_base64'])
  self.assertEqual(hashlib.sha256(raw).hexdigest(),row['response_sha256'])
  with self.assertRaises(json.JSONDecodeError) as e:json.loads(raw)
  self.assertEqual(e.exception.pos,595495)
if __name__=='__main__':
 with patch.object(m,'_connect',side_effect=AssertionError('network forbidden')):
  unittest.main()
