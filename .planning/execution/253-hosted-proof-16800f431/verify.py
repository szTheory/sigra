#!/usr/bin/env python3
"""Read-only offline checks of this proposal and its preservation promises."""
import hashlib,json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[3]
here=pathlib.Path(__file__).resolve().parent
load=lambda p:json.loads(p.read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(root),*args])
d=load(here/'proposal.json'); m=load(here/'publication-proposal.json')
assert d['status']=='proposal_only_execution_bundle_required'
assert d['approval']['received'] is False and d['approval']['allocation_created'] is False
assert d['source_sha']==git('rev-parse','16800f431').decode().strip()==m['source_sha']
assert sha((here/'publication-proposal.json').read_bytes())==d['publication_manifest_sha256']
assert d['source_reassembly']['candidate_tree']==m['candidate_tree_sha']
repair=root/'.planning/execution/253-pr338-repair'
r=load(repair/'repair.json'); old=load(repair/'assembled-candidate.json')
assert m['candidate_tree_sha']==old['candidate_tree']
for path,digest in r['artifacts'].items():assert sha((root/path).read_bytes())==digest,path
for p in d['preservation']['shared']:
 b=git('show',p['commit']+':'+p['path']);assert sha(b)==p['sha256'] and len(b)==p['bytes'],p['path']
def inventory(commit):
 result={}
 for record in git('ls-tree','-rz','--full-tree',commit).split(b'\0'):
  if not record:continue
  meta,path=record.split(b'\t',1)
  if not path.startswith(b'.planning/'):result[path]=meta
 return result
assert inventory(d['source_sha'])==inventory('HEAD')
inputs=load(root/'scripts/ci/ci-candidate-inputs.json')['inputs'];assert len(inputs)==6
for path,digest in inputs.items():assert sha(git('show',d['source_sha']+':'+path))==digest
pr=load(root/'.planning/execution/253-171.json');canary=load(root/'.planning/execution/253-170.json')
assert pr['status']=='halted' and pr['requests']==19 and pr['caps']['requests']==120
assert canary['budget']['request_count']==85
for path,digest in canary['sha256'].items():assert sha((root/path).read_bytes())==digest,path
for path,digest in pr['sha256'].items():assert sha((root/path).read_bytes())==digest,path
assert all(v==0 for v in d['current_task'].values())
for w in d['proposed_windows']:
 assert sum(w['category_ceilings'].values())==w['requests']
 assert w['seconds']==3600 and w['reruns']==0
assert [w['requests'] for w in d['proposed_windows']]==[117,120]
p=m['projection'];assert p['projected_total_requests']==19<=p['max_requests']==24
assert p['largest_tree_body_bytes']==2092801<=p['max_tree_body_bytes']==2097152
assert p['complete_product_delta_dropped'] is False
assert len(d['refs'])==4 and len({v['ref'] for v in d['refs']})==4
assert all(v['operation']=='create_only' and v['ref'].startswith('refs/heads/gsd/253-proof-16800f431-') for v in d['refs'])
assert d['phase_verification_status']=='not_started' and d['execution_gaps']
allowed={v['path'] for v in d['preservation']['shared']}
changed=set(git('diff','--name-only',d['entry_commit'],'--').decode().splitlines())
# New task artifacts can also be tracked once the proposal commit is made.
assert all(p in allowed or p.startswith('.planning/execution/253-hosted-proof-16800f431/') or p.startswith('.planning/quick/261021-lhg-') for p in changed),changed
for path in ['.planning/state.json','.planning/HANDOFF.json','.planning/execution/253-CONTINUATION.json']:
 s=load(root/path)
 if 'phase253_hosted_proof_proposal' in s or s.get('hosted_proof_proposal'):
  assert s['next_command']==d['next_command']
  if 'next' in s:assert s['next']['command']==d['next_command']
print('PASS: pinned source and tested candidate tree; 6 immutable inputs; repair artifacts; historical PR338/170 records; all caps; fresh refs; unchanged historical paths; no approval or allocation.')
