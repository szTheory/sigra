#!/usr/bin/env python3
"""Rebuild fixed-source objects and scoped helper copies offline, without touching the source Git store."""
import datetime,hashlib,importlib.util,json,os,pathlib,re,subprocess as sp,tempfile,difflib
B=pathlib.Path(__file__).resolve().parent
ROOT=B.parents[2]
SOURCE='a6838a8f9e107a49e11ea47ef34e3171fe15eed0'
PARENT='09df342a82e03c3d5d40173c912b70e827f7eadc'
PREFIX='gsd/253-replan-proof-a6838a8f9'
PHASE='.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/'
DATE='2026-10-22T01:13:38Z'
def git(*args,input=None):return sp.check_output(['git','-C',str(ROOT),*args],input=input)
def write(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p,name):
 spec=importlib.util.spec_from_file_location(name,p); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
ROOT_EXPR='next(p for p in Path(__file__).resolve().parents if (p / ".git").exists())'
def adapt(name,raw):
 s=raw.decode(); s=s.replace('gsd/253-replan-r13-candidate',PREFIX+'-candidate').replace('gsd/253-replan-r13-fixture',PREFIX+'-fixture').replace('gsd/253-replan-docs-',PREFIX+'-docs-')
 if name.endswith('.py'):
  s=s.replace('Path(__file__).resolve().parents[2]',ROOT_EXPR)
  for f in ['ci-hosted-transport.py','ci-git-publication.py','ci-hosted-gate-verify.py']:
   s=s.replace('ROOT / "scripts/ci/'+f+'"','Path(__file__).with_name("'+f+'")')
 if name.endswith('.sh'):
  s=s.replace('ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"','ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"')
  for f in ['ci-hosted-transport.py','ci-git-publication.py','ci-hosted-gate-verify.py']:
   s=s.replace('$ROOT/scripts/ci/'+f,'$(dirname "${BASH_SOURCE[0]}")/'+f)
  # Python embedded in the PR collector must use the immutable sibling helpers, not product helpers.
  for f in ['ci-hosted-transport.py','ci-git-publication.py','ci-hosted-gate-verify.py']:
   s=s.replace('ROOT / "scripts/ci/'+f+'"','Path(os.environ["SIGRA_PR_PROOF_RUNTIME"]) / "'+f+'"')
  if name=='ci-pr-proof.sh':s=s.replace('export SIGRA_PR_PROOF_ROOT="$ROOT"','export SIGRA_PR_PROOF_ROOT="$ROOT"\nexport SIGRA_PR_PROOF_RUNTIME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"')
 if name=='ci-gate-canary.sh':s=s.replace('refs/gsd/phase253-12-canary-', 'refs/gsd/253-replan-proof-a6838a8f9-canary-')
 if name=='ci-gate-canary.sh':
  s=s.replace('python3 - "$PUBLICATION_RECEIPT" "$REQUESTS" "$EVIDENCE" <<', 'python3 - "$PUBLICATION_RECEIPT" "$REQUESTS" "$EVIDENCE" "$PUBLISHER" <<')
  s=s.replace('receipt_path, ledger_path, evidence_path = sys.argv[1:]', 'receipt_path, ledger_path, evidence_path = sys.argv[1:4]')
  bridge_anchor='evidence["transport_receipts"] = [receipts[key] for key in sorted(receipts)]'
  bridge_code='\nfrom pathlib import Path\nsys.path.insert(0, str(Path(sys.argv[4]).resolve().parent))\nfrom receipt_bridge import merge_operator_receipts\noperator_receipts = [json.load(open(p)) for p in sorted(Path(evidence_path).parent.glob("canary-operator-receipt-*.json"))]\nevidence = merge_operator_receipts(evidence, ledger, operator_receipts)'
  assert s.count(bridge_anchor)==1
  s=s.replace(bridge_anchor,bridge_anchor+bridge_code)
 if name=='ci-git-publication.py':
  s=re.sub(r'REF_PAIRS = \{.*?\n\}', 'REF_PAIRS = {"proofa6838a8f9": {"candidate": "'+PREFIX+'-candidate", "fixture": "'+PREFIX+'-fixture"}}',s,count=1,flags=re.S)
  s=s.replace('DEFAULT_REF_PAIR = "legacy"','DEFAULT_REF_PAIR = "proofa6838a8f9"')
  # The outer guard requires an exact newly fetched parent before *any* request, without manufacturing a fetch record offline.
  s=s.replace('MAIN_FRESHNESS_PAIRS = ("r12", "r13")','MAIN_FRESHNESS_PAIRS = ()  # exact fresh parent is mandatory in operator/transport guard')
  s=s.replace('PAIR_CANARY_CATEGORIES = {"r13": CANARY_CATEGORIES_R13}','PAIR_CANARY_CATEGORIES = {"proofa6838a8f9": CANARY_CATEGORIES_R13}')
 if name=='ci-pr-proof.sh':
  s=re.sub(r'^NORMAL_HEADS = .*$', 'NORMAL_HEADS = ("'+PREFIX+'-candidate",)',s,flags=re.M)
  s=re.sub(r'^MAIN_RECORD_HEADS = .*$', 'MAIN_RECORD_HEADS = {}  # exact fresh parent guarded before all requests',s,flags=re.M)
 if name=='ci-hosted-gate-verify.py':s=re.sub(r'^PR_NORMAL_HEADS = .*$', 'PR_NORMAL_HEADS = ("'+PREFIX+'-candidate",)',s,flags=re.M)
 if name=='ci-hosted-transport.py':
  s=re.sub(r'^PR_HEAD_REFS = .*$', 'PR_HEAD_REFS = {"'+PREFIX+'-candidate", "'+PREFIX+'-docs-head"}',s,flags=re.M)
  s=s.replace('r"refs/heads/gsd/253-replan-[a-z0-9][a-z0-9-]{0,100}"','r"refs/heads/gsd/253-replan-proof-a6838a8f9-(?:candidate|fixture|docs-base|docs-head)"')
  needle='    allocation, allocation_raw = _json(allocation_path, MAX_ALLOCATION_BYTES)'
  s=s.replace(needle,'    from execution_guard import authorize_request\n    authorize_request(allocation_path, ledger_path, request_path)\n'+needle,1)
 return s.encode()
def main():
 if (B/'bundle.json').exists():raise SystemExit('STOP: bundle already sealed; regenerate only in a new reviewed directory')
 if git('diff','--name-only',SOURCE,'HEAD','--',':(exclude).planning').strip():raise SystemExit('STOP: product source changed')
 runtime=B/'runtime';patches=[]; sources={}
 names=['ci-git-publication.py','ci-hosted-transport.py','ci-hosted-gate-verify.py','ci-gate-canary.sh','ci-pr-proof.sh','ci-browser-records.mjs','ci-playwright-report.mjs','ci-registration-recovery.mjs']
 for name in names:
  path='scripts/ci/'+name;raw=git('show',SOURCE+':'+path);new=adapt(name,raw);(runtime/name).write_bytes(new);sources[name]=dict(source_path=path,source_blob=git('rev-parse',SOURCE+':'+path).decode().strip(),source_sha256=sha(raw),runtime_sha256=sha(new))
  if new!=raw:patches.extend(difflib.unified_diff(raw.decode().splitlines(True),new.decode().splitlines(True),fromfile=path+'@'+SOURCE,tofile='runtime/'+name))
 (B/'adapter.diff').write_text(''.join(patches));write(B/'helper-origins.json',sources)
 # New objects are written only to a disposable store, with read-only access to existing objects.
 store=pathlib.Path(tempfile.mkdtemp(prefix='253-proof-objects-'))/'objects';store.mkdir();original=git('rev-parse','--git-path','objects').decode().strip();original=str((ROOT/original).resolve())
 os.environ.update(GIT_OBJECT_DIRECTORY=str(store),GIT_ALTERNATE_OBJECT_DIRECTORIES=original,PYTHONDONTWRITEBYTECODE='1')
 pub=load(runtime/'ci-git-publication.py','scoped_publisher')
 proposal=pub.source_variants(ROOT,SOURCE,PARENT,DATE,fixture_file=PHASE+'253-LOAD-RECOVERY-CANARY-WORKFLOW.yml',workflow_path='.github/workflows/ci.yml',allow_planning_descendant=True)
 public={k:v for k,v in proposal.items() if not k.startswith('_')};pub.validate_manifest(public)
 if public['status']!='ready-local-proposal':raise SystemExit('STOP: publication exceeds unchanged limits: '+repr(public['blockers']))
 assert public['product_tree_parity']['same_paths_modes_blobs']
 assert public['source_sha']==SOURCE
 write(B/'publication.json',public)
 identities={k:public[k] for k in ['candidate_helper_commit','candidate_tree_sha','fixture_workflow_commit','fixture_workflow_blob','fixture_tree_sha','server_parent_sha','docs_base_commit','docs_head_commit']}
 identities.update(candidate_ref='refs/heads/'+PREFIX+'-candidate',fixture_ref='refs/heads/'+PREFIX+'-fixture',workflow_path='.github/workflows/ci.yml',old_failed_run_id='38347679431',old_failed_epoch=1791909792,old_failed_halt_seconds=34,old_known_commands=3)
 oldfreeze=json.loads((ROOT/(PHASE+'253-LOAD-RECOVERY-CANARY-FREEZE-R13.json')).read_text())
 actions,digests=pub.build_outward_actions(identities)
 freeze=dict(schema_version=pub.FREEZE_SCHEMA,plan='253-171',source=dict(commit=SOURCE,product_tree_sha=public['product_tree_parity']['source_product_tree'],product_files=public['product_tree_parity']['source_product_files']),identity=identities,helper_blobs={path:git('rev-parse',SOURCE+':'+path).decode().strip() for path in pub.HELPER_PATHS},bound_documents=dict(publication_manifest=pub.doc_binding(ROOT,str((B/'publication.json').relative_to(ROOT))),fixture_workflow=pub.doc_binding(ROOT,public['fixture_file']['path'])),native_target=oldfreeze['native_target'],outward_actions=actions,outward_actions_sha256=digests,**pub.static_freeze_sections('proofa6838a8f9'))
 write(B/'canary-freeze.json',freeze);pub.check_revision_freeze(B/'canary-freeze.json',ROOT)
 commits=[public[k] for k in ['candidate_helper_commit','fixture_workflow_commit','docs_base_commit','docs_head_commit']]
 ids=git('rev-list','--objects','--no-object-names',*commits,'--not',SOURCE,PARENT)
 pack=git('pack-objects','--stdout',input=ids);(B/'objects.pack').write_bytes(pack)
 write(B/'object-recipe.json',dict(source=SOURCE,parent=PARENT,date=DATE,workflow_path='.github/workflows/ci.yml',fixture_file=public['fixture_file'],commits=commits,object_count=len(ids.splitlines()),pack_sha256=sha(pack),candidate_product_tree_matches_new_source=True,corrections=['Fixture installed at registered ci.yml, not the old unregistered workflow path','Docs base trigger permits only main and the new scoped docs branches; source candidate includes the committed PR339 repairs']))
 # Inactive templates are *not* allocations and cannot be handed to transport without explicit activation.
 templates={}
 for kind,oldfile in [('canary','253-LOAD-RECOVERY-CANARY-ALLOCATION-R13.json'),('prs','253-LOAD-RECOVERY-PR-ALLOCATION-R13.json')]:
  a=json.loads((ROOT/(PHASE+oldfile)).read_text());a['window_id']='gsd/253-replan-proof-a6838a8f9-'+kind+'-1';a['source_sha256']='ACTIVATE_ONLY_AFTER_APPROVAL';a['bound_documents']=[]
  templates[kind]=a
 write(B/'allocation-templates.json',dict(status='inactive_templates_only',allocations=templates))
 for key in ['GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES']:os.environ.pop(key,None)
 print(json.dumps(dict(status='prepared_offline',candidate=public['candidate_helper_commit'],fixture=public['fixture_workflow_commit'],docs_head=public['docs_head_commit'],projection=public['projection'],objects=len(ids.splitlines())),indent=2))
if __name__=='__main__':main()
