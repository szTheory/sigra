"""Offline boundary regression using retained actual HTTP records, never hosted acceptance."""
import hashlib,json,pathlib,shutil,subprocess,sys,tempfile,unittest
B=pathlib.Path(__file__).resolve().parent
OLD=B.parent/'253-proof-bundle-16800f431'
class CollectorBoundary(unittest.TestCase):
 def run_collector_block(self,missing=False):
  shell=(B/'runtime/ci-gate-canary.sh').read_text()
  marker='import hashlib, json, sys\nreceipt_path, ledger_path, evidence_path = sys.argv[1:4]'
  self.assertEqual(shell.count(marker),1)
  code=marker+shell.split(marker,1)[1].split('\nPY\n',1)[0]
  with tempfile.TemporaryDirectory() as tmp:
   p=pathlib.Path(tmp);e=p/'evidence.json';shutil.copyfile(OLD/'canary-evidence.json',e)
   for i in range(1,5 if missing else 6):shutil.copyfile(OLD/f'canary-operator-receipt-{i}.json',p/f'canary-operator-receipt-{i}.json')
   result=subprocess.run([sys.executable,'-',str(OLD/'publication-receipt.json'),str(OLD/'canary-ledger.json'),str(e),str(B/'runtime/ci-git-publication.py')],input=code,text=True,capture_output=True)
   if missing:
    self.assertNotEqual(result.returncode,0);self.assertIn('incomplete',result.stderr);self.assertFalse((p/'evidence.json.tmp').exists());return
   self.assertEqual(result.returncode,0,result.stderr)
   output=p/'evidence.json.tmp';data=json.loads(output.read_text());self.assertEqual(len(data['transport_receipts']),32)
   verify=subprocess.run([sys.executable,str(B/'runtime/ci-hosted-gate-verify.py'),'--mode','preflight','--evidence',str(output)],capture_output=True,text=True)
   self.assertEqual(verify.returncode,0,verify.stderr);self.assertEqual(json.loads(verify.stdout)['status'],'preflight_verified')
   self.assertEqual(data['status'],'halted')
 def test_generated_collector_joins_original_operator_receipts(self):self.run_collector_block()
 def test_generated_collector_rejects_missing_original_receipt(self):self.run_collector_block(True)
 def test_first_attempt_bytes_remain_exact(self):
  result=json.loads((OLD/'attempt-result.json').read_text())
  for name,digest in result['artifacts'].items():self.assertEqual(hashlib.sha256((OLD/name).read_bytes()).hexdigest(),digest)
if __name__=='__main__':unittest.main(verbosity=2)
