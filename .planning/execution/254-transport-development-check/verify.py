from pathlib import Path
import json,sys,hashlib
sys.path.insert(0,'scripts/ci')
from ci_metrics_security import verify_snapshot_hashes,validate_producer_commit,validate_workflow_source
p=Path(__file__).resolve().parent;b=p/'RAW-after';c=json.loads((p/'CONTRACT.json').read_text());source=json.loads((p/'SOURCE.json').read_text())
errors=verify_snapshot_hashes(b);assert errors==[],errors
f=b/'raw/families/40054033393-attempt-1';run=json.loads((f/'run.json').read_text());assert run['head_sha']==source['application_sha'] and run['run_attempt']==1 and run['conclusion']=='success'
origin=json.loads((b/'preparation-origin-verification.json').read_text());assert origin['status']=='origin_verified'
jobs=json.loads((f/'jobs-attempt-1.json').read_text())['jobs'];byname={x['name']:x for x in jobs};assert byname['ci-gate']['conclusion']=='success'
fast=next(x for x in jobs if x['name'].startswith('Fast checks ('));assert fast['conclusion']=='success'
required={name:byname[name]['conclusion'] for name in c['required_contexts']};assert set(required.values())=={'success'},required
step=next(x for x in fast['steps'] if x['name']=='Phoenix transport handoff regression');assert step['conclusion']=='success'
detail=json.loads((f/'manifest.json').read_text());metadata=[json.loads(x.read_text()) for x in (f/'artifacts').glob('*/ci-measurement-metadata.json')];producers={x['source_sha'] for x in metadata};assert len(producers)==1
producer=producers.pop();reference=detail['producer_commits'][producer];read=lambda key:b/reference[key]
commit=json.loads(read('commit_path').read_text());tree=json.loads(read('tree_path').read_text());workflow=read('workflow_path').read_bytes()
issues=validate_producer_commit(producer,commit,run)+validate_workflow_source(producer,tree,workflow,source['files']['.github/workflows/ci.yml'],source['tree_sha']);assert issues==[],issues;assert commit['commit']['tree']['sha']==source['tree_sha']
proof={'status':'passed','purpose':c['purpose'],'run_id':run['id'],'run_attempt':1,'conclusion':'success','source_sha':run['head_sha'],'producer_sha':producer,'tree_sha':source['tree_sha'],'workflow_sha256':hashlib.sha256(workflow).hexdigest(),'raw_hash_errors':errors,'origin_status':origin['status'],'required_contexts':required,'ci_gate':'success','fast_checks':'success','phoenix_connection_regression':'success','capture_preservation':str(p.relative_to(Path.cwd())/'PRESERVATION-after.json')}
output=p/'VERIFICATION.json'
if output.exists():assert json.loads(output.read_text())==proof
else:output.write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(proof,sort_keys=True))
