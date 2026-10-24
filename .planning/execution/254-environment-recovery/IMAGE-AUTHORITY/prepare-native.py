#!/usr/bin/env python3
"""Build source-bound comparison inputs from verified preparation artifacts, offline."""
from pathlib import Path
import hashlib,json,sys,subprocess
ROOT=Path(__file__).resolve().parents[4]
SCOPE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/ci'))
from ci_metrics_security import comparison_native_inventories,verify_snapshot_hashes,validate_producer_commit,validate_workflow_source
h=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
c=json.loads((SCOPE/'NATIVE-INVENTORY-CONTRACT.json').read_text())
runs={row[0]:row for row in json.loads((SCOPE/'RUNS.json').read_text())}
for role in sys.argv[1:] or ['before','after']:
 bundle=SCOPE/f'RAW-{role}'; out=SCOPE/f'PREPARATION-NATIVE-{role}'
 if out.exists(): raise SystemExit('native_output_already_exists:'+role)
 if verify_snapshot_hashes(bundle): raise SystemExit('raw_snapshot_hash_failure:'+role)
 origin=json.loads((bundle/'preparation-origin-verification.json').read_text())
 if origin.get('status')!='origin_verified': raise SystemExit('preparation_origin_not_verified:'+role)
 _,rid,attempt,_=runs[role];family=bundle/f'raw/families/{rid}-attempt-{attempt}'
 run=json.loads((family/'run.json').read_text()); detail=json.loads((family/'manifest.json').read_text())
 if run['conclusion']!='success': raise SystemExit('preparation_did_not_pass:'+role)
 expected=c['baseline_application_sha'] if role=='before' else c['candidate_identity']['application_sha']
 if run['head_sha']!=expected: raise SystemExit('preparation_head_mismatch:'+role)
 evidence=json.loads((family/'artifact-evidence.json').read_text())
 metadata=[json.loads(p.read_text()) for p in (family/'artifacts').glob('*/ci-measurement-metadata.json')]
 producers={m['source_sha'] for m in metadata}
 if len(producers)!=1: raise SystemExit('preparation_producer_mismatch:'+role)
 producer=producers.pop();proof=detail['producer_commits'][producer]
 def source_file(key,digest):
  path=(bundle/proof[key]).resolve()
  if not path.is_relative_to(bundle.resolve()) or h(path)!=proof[digest]: raise ValueError('producer_source_hash_invalid')
  return path
 commit=json.loads(source_file('commit_path','commit_sha256').read_text())
 tree=json.loads(source_file('tree_path','tree_sha256').read_text())
 workflow=source_file('workflow_path','workflow_sha256').read_bytes()
 tree_sha=subprocess.check_output(['git','-C',str(ROOT),'rev-parse',expected+'^{tree}'],text=True).strip()
 expected_workflow=hashlib.sha256(subprocess.check_output(['git','-C',str(ROOT),'show',expected+':.github/workflows/ci.yml'])).hexdigest()
 issues=validate_producer_commit(producer,commit,run)+validate_workflow_source(producer,tree,workflow,expected_workflow,tree_sha)
 if issues or commit['commit']['tree']['sha']!=tree_sha: raise SystemExit('preparation_producer_tree_invalid:'+str(issues))
 inventories=comparison_native_inventories(c,role,ROOT)
 out.mkdir()
 for owner,inventory in inventories.items():
  matches=[e for e in evidence if e['artifact']['name']==f'example-playwright-{owner}-{rid}' and e['result']['status']=='accepted']
  if len(matches)!=1: raise SystemExit('native_owner_artifact_missing:'+owner)
  item=matches[0]; descriptor=inventory['descriptor']; old=descriptor['reports'][0]
  reports=list((family/'artifacts'/str(item['artifact']['id'])).rglob(Path(old['path']).name))
  if len(reports)!=1: raise SystemExit('native_owner_report_missing:'+owner)
  directory=out/owner;directory.mkdir()
  (directory/'report.json').write_bytes(reports[0].read_bytes());(directory/'selection.json').write_bytes(inventory['selection'])
  derived={**descriptor,'source_sha':expected,'workflow_sha256':expected_workflow,
   'inventory_source_sha':inventory['inventory_source_sha'],'inventory_workflow_sha256':descriptor['workflow_sha256'],
   'workflow_amendment_authorization_sha256':inventory['workflow_authorization_sha256'],
   'reports':[{**old,'source_sha':expected,'path':'report.json','selection_path':'selection.json',
    'sha256':h(directory/'report.json'),'selection_sha256':h(directory/'selection.json')}]}
  (directory/'coverage-source.json').write_text(json.dumps(derived,indent=2)+'\n')
 report={'status':'native_inputs_ready','role':role,'run_id':rid,'run_attempt':attempt,'application_sha':expected,
  'producer_sha':producer,'tree_sha':tree_sha,'workflow_sha256':expected_workflow,
  'source_checks':'passed','origin_checks':'passed','raw_hash_checks':'passed',
  'current_reports':'actual authenticated preparation artifact bytes','selection_inventories':'retained original inventory; full Playwright tree and explicit workflow amendment checked',
  'owners':{owner:{p.name:h(p) for p in (out/owner).iterdir()} for owner in inventories},
  'metadata':metadata}
 (SCOPE/f'PREPARATION-PROOF-{role}.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({key:report[key] for key in ['status','role','application_sha','producer_sha','source_checks','origin_checks']}))
