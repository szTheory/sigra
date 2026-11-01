#!/usr/bin/env python3
"""Rebuild fixed-source objects and scoped helper copies offline, without touching the source Git store."""
import datetime,hashlib,importlib.util,json,os,pathlib,re,subprocess as sp,tempfile,difflib
B=pathlib.Path(__file__).resolve().parent
ROOT=B.parents[2]
SOURCE='5e13621e50e646c63e135035080d2e6e46fbc955'
PARENT='09df342a82e03c3d5d40173c912b70e827f7eadc'
PREFIX='gsd/253-replan-proof-5e13621e5'
PHASE='.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/'
DATE='2026-10-22T04:00:00Z'
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
 if name=='ci-gate-canary.sh':s=s.replace('refs/gsd/phase253-12-canary-', 'refs/gsd/253-replan-proof-5e13621e5-canary-')
 if name=='ci-gate-canary.sh':
  s=s.replace('python3 - "$PUBLICATION_RECEIPT" "$REQUESTS" "$EVIDENCE" <<', 'python3 - "$PUBLICATION_RECEIPT" "$REQUESTS" "$EVIDENCE" "$PUBLISHER" <<')
  s=s.replace('receipt_path, ledger_path, evidence_path = sys.argv[1:]', 'receipt_path, ledger_path, evidence_path = sys.argv[1:4]')
  bridge_anchor='evidence["transport_receipts"] = [receipts[key] for key in sorted(receipts)]'
  bridge_code='\nfrom pathlib import Path\nsys.path.insert(0, str(Path(sys.argv[4]).resolve().parent))\nfrom receipt_bridge import merge_operator_receipts\noperator_receipts = [json.load(open(p)) for p in sorted(Path(evidence_path).parent.glob("canary-operator-receipt-*.json"))]\nevidence = merge_operator_receipts(evidence, ledger, operator_receipts)'
  assert s.count(bridge_anchor)==1
  s=s.replace(bridge_anchor,bridge_anchor+bridge_code)
 if name=='ci-git-publication.py':
  s=re.sub(r'REF_PAIRS = \{.*?\n\}', 'REF_PAIRS = {"proof5e13621e5": {"candidate": "'+PREFIX+'-candidate", "fixture": "'+PREFIX+'-fixture"}}',s,count=1,flags=re.S)
  s=s.replace('DEFAULT_REF_PAIR = "legacy"','DEFAULT_REF_PAIR = "proof5e13621e5"')
  # The outer guard requires an exact newly fetched parent before *any* request, without manufacturing a fetch record offline.
  s=s.replace('MAIN_FRESHNESS_PAIRS = ("r12", "r13")','MAIN_FRESHNESS_PAIRS = ()  # exact fresh parent is mandatory in operator/transport guard')
  s=s.replace('PAIR_CANARY_CATEGORIES = {"r13": CANARY_CATEGORIES_R13}','PAIR_CANARY_CATEGORIES = {"proof5e13621e5": CANARY_CATEGORIES_R13}')
 if name=='ci-pr-proof.sh':
  s=re.sub(r'^NORMAL_HEADS = .*$', 'NORMAL_HEADS = ("'+PREFIX+'-candidate",)',s,flags=re.M)
  s=re.sub(r'^MAIN_RECORD_HEADS = .*$', 'MAIN_RECORD_HEADS = {}  # exact fresh parent guarded before all requests',s,flags=re.M)
 if name=='ci-hosted-gate-verify.py':s=re.sub(r'^PR_NORMAL_HEADS = .*$', 'PR_NORMAL_HEADS = ("'+PREFIX+'-candidate",)',s,flags=re.M)
 if name=='ci-hosted-transport.py':
  s=re.sub(r'^PR_HEAD_REFS = .*$', 'PR_HEAD_REFS = {"'+PREFIX+'-candidate", "'+PREFIX+'-docs-head"}',s,flags=re.M)
  s=s.replace('r"refs/heads/gsd/253-replan-[a-z0-9][a-z0-9-]{0,100}"','r"refs/heads/gsd/253-replan-proof-5e13621e5-(?:candidate|fixture|docs-base|docs-head)"')
  needle='    allocation, allocation_raw = _json(allocation_path, MAX_ALLOCATION_BYTES)'
  s=s.replace(needle,'    from execution_guard import authorize_request\n    authorize_request(allocation_path, ledger_path, request_path)\n'+needle,1)
 return s.encode()
def main():
 if (B/'publication.json').exists():raise SystemExit('STOP: offline objects already prepared; inspect instead of replacing')
 with tempfile.TemporaryDirectory(prefix='253-offline-objects-') as temporary:
  store=pathlib.Path(temporary)/'objects';store.mkdir()
  original=str((ROOT/git('rev-parse','--git-path','objects').decode().strip()).resolve())
  previous={k:os.environ.get(k) for k in ['GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES']}
  os.environ.update(GIT_OBJECT_DIRECTORY=str(store),GIT_ALTERNATE_OBJECT_DIRECTORIES=original)
  try:
   raw=git('show',SOURCE+':scripts/ci/ci-git-publication.py')
   publisher=pathlib.Path(temporary)/'ci-git-publication.py';publisher.write_bytes(adapt('ci-git-publication.py',raw).replace(ROOT_EXPR.encode(), ('Path('+repr(str(ROOT))+')').encode()))
   pub=load(publisher,'offline_publisher')
   proposed=pub.source_variants(ROOT,SOURCE,PARENT,DATE,fixture_file=PHASE+'253-LOAD-RECOVERY-CANARY-WORKFLOW.yml',workflow_path='.github/workflows/ci.yml',allow_planning_descendant=True)
   public={k:v for k,v in proposed.items() if not k.startswith('_')};pub.validate_manifest(public)
   assert public['status']=='ready-local-proposal',public['blockers']
   assert public['product_tree_parity']['same_paths_modes_blobs']
   commits=[public[k] for k in ['candidate_helper_commit','docs_base_commit','docs_head_commit']]
   ids=git('rev-list','--objects','--no-object-names',*commits,'--not',SOURCE,PARENT)
   pack=git('pack-objects','--stdout',input=ids)
   (B/'objects.pack').write_bytes(pack)
   ci=git('show',public['docs_base_commit']+':.github/workflows/ci.yml')
   (B/'docs-workflow.yml').write_bytes(ci)
   # Independently check actual Git objects, rather than trusting manifest flags.
   expected={'.github/workflows/ci.yml'}
   assert set(git('diff','--name-only',commits[0],commits[1]).decode().splitlines())==expected
   assert git('diff','--name-only',commits[1],commits[2]).decode().splitlines()==[pub.DOCS_PATH]
   write(B/'publication.json',public)
   write(B/'objects.json',dict(source_sha=SOURCE,known_parent_sha=PARENT,parent_freshness='not_checked_offline',commits=commits,pack_sha256=sha(pack),objects=len(ids.splitlines()),refs=[PREFIX+'-candidate',PREFIX+'-docs-base',PREFIX+'-docs-head'],refs_published=False,fixture_generated_by_existing_publisher_but_not_packed_or_scheduled=True))
  finally:
   for key,value in previous.items():
    if value is None:os.environ.pop(key,None)
    else:os.environ[key]=value
 print('Prepared exact repaired-source normal/docs objects offline; zero network calls')
if __name__=='__main__':main()
