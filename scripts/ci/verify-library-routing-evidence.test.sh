#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT/scripts/ci/verify-library-routing-evidence.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
"$VERIFY" --print-negative-runs >"$TMP/negative.json"
python3 - "$VERIFY" "$TMP" <<'PY'
import copy,json,os,subprocess,sys
verify,tmp=sys.argv[1:]
negative=json.load(open(os.path.join(tmp,"negative.json")))
assert len(negative)==10 and [r["id"] for r in negative]==[34466384009,34466384470,34467186749,34467189602,34468109536,34468110161,34493873867,34493911924,34520992740,34520986751]
sha="c"*40; rate="gh api rate_limit --jq '.resources.core | {remaining,reset}'"; fields="databaseId,event,headSha,conclusion,attempt,url,jobs"
prid=4005; scid=4006
pr={"schema_version":"sigra.library-partitions-evidence/v1","repository":"szTheory/sigra","pr":{"number":234},"run":{"id":prid,"url":f"https://github.com/szTheory/sigra/actions/runs/{prid}","event":"pull_request","attempt":1,"head_sha":sha,"conclusion":"success"},"owner":{"id":501,"name":"Library tests shard","status":"completed","conclusion":"success","skipped":False},"aggregate":{"id":502,"name":"Library tests","status":"completed","conclusion":"success","skipped":False},"artifacts":[{"id":601,"name":f"library-partitions-{prid}-1","file":"sigra-library-partitions.json","sha256":"1"*64},{"id":602,"name":f"library-partition-1-timings-{prid}-1","file":"sigra-library-1-timings.json","sha256":"2"*64},{"id":603,"name":f"library-partition-2-timings-{prid}-1","file":"sigra-library-2-timings.json","sha256":"3"*64}],"partitions":{"execution_mode":"sequential","ordinary_universe_count":20,"manifest_counts":[10,10],"test_counts":[40,42],"durations_ms":[12000,18000],"conclusions":["success","success"],"exit_statuses":[0,0]},"protected_invariants":{"library_tests_aggregate_sha256":"04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb","sole_pr_owner":"MIX_ENV=test mix ci","fast_01_verifier":"source_complete_offline_attestation_verified","gate_05_verifier":"offline_attestation_verified"},"commands":{"rate_limit":rate,"watch":f"gh run watch {prid} --repo szTheory/sigra --compact --interval 60 --exit-status","summary":f"gh run view {prid} --repo szTheory/sigra --json {fields}","artifacts":[f"gh run download {prid} --repo szTheory/sigra --name library-partitions-{prid}-1",f"gh run download {prid} --repo szTheory/sigra --name library-partition-1-timings-{prid}-1",f"gh run download {prid} --repo szTheory/sigra --name library-partition-2-timings-{prid}-1"]},"supersession":{"plan04_status":"empirically superseded (failed evidence retained)","forbidden_predicates":["install_not_dominant","ordinary-vs-scaffold comparable"]},"negative_runs":negative}
paths=["test/sigra/install/features/passkeys_js_test.exs","test/sigra/install/generator_passkeys_opt_out_test.exs","test/sigra/install/golden_diff_test.exs","test/sigra/install/idempotency_test.exs","test/sigra/install/vault_promotion_test.exs","test/upgrade_test.exs"]
sc={"schema_version":"sigra.library-install-golden-evidence/v1","repository":"szTheory/sigra","run":{"id":scid,"url":f"https://github.com/szTheory/sigra/actions/runs/{scid}","event":"workflow_dispatch","attempt":1,"head_sha":sha,"conclusion":"failure"},"job":{"id":503,"name":"Library install golden (non-PR)","status":"completed","conclusion":"success","skipped":False},"artifacts":[{"id":604,"name":f"library-install-golden-{scid}-1","file":"sigra-library-install-golden.json","sha256":"4"*64},{"id":605,"name":f"library-install-diagnostics-{scid}-1","file":"sigra-install-golden-diagnostics.json","sha256":"5"*64}],"receivers":{"paths":paths,"count":6,"duration_ms":57389,"exit_status":0,"conclusion":"success","prepared_fixture":True,"worker_ceiling":2},"diagnostics":{"schema_version":"sigra.install-fixture-diagnostics/v1","variant_count":6,"worker_count":2,"failed_paths":[],"raw_install_duration_ms":57389},"protected_invariants":{"non_pr_events":["schedule","workflow_dispatch"],"pr_execution":False,"hard_signal":True},"commands":{"rate_limit":rate,"watch":f"gh run watch {scid} --repo szTheory/sigra --compact --interval 60 --exit-status","summary":f"gh run view {scid} --repo szTheory/sigra --json {fields}","artifacts":[f"gh run download {scid} --repo szTheory/sigra --name library-install-golden-{scid}-1",f"gh run download {scid} --repo szTheory/sigra --name library-install-diagnostics-{scid}-1"]},"supersession":{"failed_run_id":34435818106,"ordinary_duration_ms":28671,"install_duration_ms":79614,"safe_optimization_commits":["1fa788fc","488f4fa1"],"bounded_clean_local_range_ms":[56000,78000],"final_hard_stop_ms":57389,"status":"failed evidence retained"},"negative_runs":negative}
def write(obj,path):
 with open(path,"w") as f: json.dump(obj,f,separators=(",",":"),sort_keys=True)
def check(a,b,want=True):
 p=os.path.join(tmp,"pr.json"); s=os.path.join(tmp,"sc.json"); write(a,p); write(b,s)
 ok=subprocess.run([verify,p,s],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
 if ok!=want: raise AssertionError("unexpected verifier result")
check(pr,sc)
# Every scalar/null, array membership/order, and nested key in the canonical ledger is an admission pole.
def bad_scalar(value):
 if value is None:return "invented"
 if isinstance(value,bool):return not value
 if isinstance(value,int):return value+1
 return value+"-mutated"
def walk(value,path=()):
 if isinstance(value,dict):
  for key in list(value):
   yield ("delete",path+(key,))
   yield from walk(value[key],path+(key,))
 elif isinstance(value,list):
  if value:
   yield ("delete",path+(0,))
   if len(value)>1:yield ("reverse",path)
   for i,item in enumerate(value):yield from walk(item,path+(i,))
 else:yield ("scalar",path)
def mutate(root,kind,path):
 out=copy.deepcopy(root); parent=out
 for p in path[:-1]:parent=parent[p]
 if kind=="scalar":parent[path[-1]]=bad_scalar(parent[path[-1]])
 elif kind=="delete":
  target=path[-1]; parent.pop(target) if isinstance(parent,list) else parent.pop(target)
 else:
  parent=out
  for p in path:parent=parent[p]
  parent.reverse()
 return out
for kind,path in walk(negative):
 mutant=mutate(negative,kind,path); a=copy.deepcopy(pr); a["negative_runs"]=mutant; check(a,sc,False)
for transform in [lambda x:x[:-1],lambda x:list(reversed(x)),lambda x:x+[copy.deepcopy(x[-1])]]:
 a=copy.deepcopy(pr); a["negative_runs"]=transform(a["negative_runs"]); check(a,sc,False)
mutations=[("pr",lambda x:x["run"].update(attempt=2)),("pr",lambda x:x["run"].update(id=34520992740)),("pr",lambda x:x["partitions"].update(durations_ms=[1000,2001])),("pr",lambda x:x.update(waiver=True)),("sc",lambda x:x["run"].update(head_sha="d"*40)),("sc",lambda x:x["job"].update(conclusion="failure")),("sc",lambda x:x["run"].update(id=34520986751)),("sc",lambda x:x.update(pass_=True))]
for which,fn in mutations:
 a,b=copy.deepcopy(pr),copy.deepcopy(sc); fn(a if which=="pr" else b); check(a,b,False)
print("verify-library-routing-evidence.test: PASS")
PY
# Current admission authority is a closed seven-path set.  Each pin must fail
# independently, while Plan 18 literals remain inert historical context.
python3 - "$ROOT" "$VERIFY" "$TMP/authority" <<'PY'
import hashlib,json,os,shutil,subprocess,sys
root,verify,tmp=sys.argv[1:]
expected=[
 (".github/workflows/ci.yml","ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682",None),
 ("test/support/ci/library_test_partitions.exs","9384fce2c84de95681d1e1ef08c7efec5bf993c2bd0abf9837c169f2fdefb103",None),
 ("test/support/ci/library_test_partitions_test.exs","61feccce1cd7fef696e55fcbb270c2cc80f0f8f1f29a4c3136b5a29caeecf92a",None),
 ("scripts/ci/library-partitions.sh","deae1229e1bfabea6924d2512db1293026d6904497c2ac804f0478afc04471dd",None),
 ("scripts/ci/verify-library-partitions.sh","449d239630013c0f25837763c1dfe494442f32ad8d8fe6c4275d4890b5219a54",None),
 (".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json","a217328185ccc2bb96e2925b8d2b5c897217bf5fd10057f95b53852426c96239",2987511),
 (".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION-MANIFEST.json","51d1531208c596d65014e136a3651080f130781b1cd706ce0d5955b752e00fa4",623),
]
authority=json.loads(subprocess.check_output([verify,"--print-active-authority"]))
assert [(v["path"],v["sha256"],v["size_bytes"]) for v in authority]==expected
for path,_,_ in expected:
 src=os.path.join(root,path); dst=os.path.join(tmp,path)
 os.makedirs(os.path.dirname(dst),exist_ok=True); shutil.copy2(src,dst)
copied_verify=os.path.join(tmp,"scripts/ci/verify-library-routing-evidence.sh")
os.makedirs(os.path.dirname(copied_verify),exist_ok=True); shutil.copy2(verify,copied_verify)
def preflight(want):
 ok=subprocess.run([copied_verify,"--preflight",tmp],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
 assert ok==want
preflight(True)
for path,_,_ in expected:
 target=os.path.join(tmp,path); pristine=open(target,"rb").read()
 open(target,"wb").write(pristine+b"X")
 preflight(False)
 open(target,"wb").write(pristine)
 preflight(True)
source=open(copied_verify,encoding="utf-8").read()
assert "HISTORICAL_NEGATIVE_AUTHORITY" in source and "CURRENT_ACTIVE_AUTHORITY" in source
historical="91646f072512d32e603b850ac44caa14825543b67188c5221eea6ccaf7738c97"
assert source.count(historical)==1
open(copied_verify,"w",encoding="utf-8").write(source.replace(historical,"f"*64))
preflight(True)
old=subprocess.check_output(["git","-C",root,"show","627428df5a20dc0479163b9993a49dccf5e6f92e:test/support/ci/library_test_partitions.exs"])
assert hashlib.sha256(old).hexdigest()==historical
open(os.path.join(tmp,"test/support/ci/library_test_partitions.exs"),"wb").write(old)
preflight(False)
print("verify-library-routing-evidence.active-authority.test: PASS")
PY
# Candidate preflight rejects the exact one-line-short Plan 14 workflow and accepts authority.
"$VERIFY" --preflight "$ROOT" >/dev/null
MUT="$TMP/candidate"
mkdir -p "$MUT"
cp -R "$ROOT/.github" "$ROOT/test" "$ROOT/scripts" "$ROOT/.planning" "$MUT/"
python3 - "$MUT/.github/workflows/ci.yml" <<'PY'
import sys
p=sys.argv[1]; b=open(p,"rb").read(); i=b.find(b"\n\n"); assert i>=0; open(p,"wb").write(b[:i]+b[i+1:])
PY
if "$VERIFY" --preflight "$MUT" >/dev/null 2>&1; then echo "one-blank-line drift accepted" >&2; exit 1; fi
git -C "$ROOT" show 47f9578fc97edc63603953d446e79fac884326c3:.github/workflows/ci.yml >"$MUT/.github/workflows/ci.yml"
test "$(shasum -a 256 "$MUT/.github/workflows/ci.yml" | awk '{print $1}')" = "cf46fc226daec325db1d3191c61158f9da55edb24b2f5cddac60bcb429aeb3f1"
if "$VERIFY" --preflight "$MUT" >/dev/null 2>&1; then echo "known Plan 14 workflow drift accepted" >&2; exit 1; fi
printf 'verify-library-routing-evidence.test: PASS\n'
