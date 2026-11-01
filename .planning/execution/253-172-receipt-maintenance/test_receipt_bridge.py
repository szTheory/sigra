import copy, importlib.util, json, pathlib, subprocess, sys, tempfile, unittest
from receipt_bridge import merge_operator_receipts
HERE = pathlib.Path(__file__).resolve().parent
B = HERE.parent / '253-proof-bundle-16800f431'
def read(name): return json.loads((B/name).read_text())
class ReceiptBridgeTest(unittest.TestCase):
    def setUp(self):
        self.evidence=read('canary-evidence.json');self.ledger=read('canary-ledger.json')
        self.receipts=[read(f'canary-operator-receipt-{i}.json') for i in range(1,6)]
    def verify(self, evidence):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'diagnostic.json';p.write_text(json.dumps(evidence))
            return subprocess.run([sys.executable,str(B/'runtime/ci-hosted-gate-verify.py'),'--mode','preflight','--evidence',str(p)],capture_output=True,text=True)
    def test_actual_unchanged_command_reproduces_failure(self):
        result=self.verify(self.evidence)
        self.assertEqual(result.returncode,1);self.assertIn('retained response receipts are incomplete',result.stderr)
    def test_actual_32_request_boundary_passes_unchanged_checker(self):
        before=copy.deepcopy(self.evidence)
        fixed=merge_operator_receipts(self.evidence,self.ledger,self.receipts)
        self.assertEqual(self.evidence,before)
        self.assertEqual(len(fixed['transport_receipts']),32)
        self.assertEqual(fixed['status'],'halted')  # This is local diagnosis, never a revived attempt.
        result=self.verify(fixed);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'],'preflight_verified')
    def test_missing_original_receipt_stays_rejected(self):
        with self.assertRaisesRegex(ValueError,'incomplete'):merge_operator_receipts(self.evidence,self.ledger,self.receipts[:-1])
    def test_substitutions_stay_rejected(self):
        for field,value in [('window_id','closed-old-window'),('source_sha256','0'*64),('allocation_sha256','0'*64),('actual_status',201),('response_body_base64','e30=')]:
            with self.subTest(field=field):
                receipts=copy.deepcopy(self.receipts);receipts[0][field]=value
                with self.assertRaises(ValueError):merge_operator_receipts(self.evidence,self.ledger,receipts)
    def test_duplicate_and_unmeasured_receipts_stay_rejected(self):
        other=copy.deepcopy(self.receipts[0]);other['sequence']=999
        with self.assertRaisesRegex(ValueError,'no measured'):merge_operator_receipts(self.evidence,self.ledger,[*self.receipts,other])
        other=copy.deepcopy(self.receipts[0]);other['extra']='different'
        with self.assertRaisesRegex(ValueError,'conflicting'):merge_operator_receipts(self.evidence,self.ledger,[*self.receipts,other])
    def test_original_raw_attempt_files_unchanged(self):
        import hashlib
        result=read('attempt-result.json')
        for name,digest in result['artifacts'].items():self.assertEqual(hashlib.sha256((B/name).read_bytes()).hexdigest(),digest)
if __name__=='__main__':unittest.main(verbosity=2)
