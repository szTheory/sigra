#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"

python3 - "$ROOT" "$PHASE_DIR" "$@" <<'PY'
import hashlib, json, os, re, sys
ROOT, PHASE_DIR, *args = sys.argv[1:]
def fail(message): raise SystemExit("verify-library-routing-evidence: FAIL: " + message)
def job(id,name,status,conclusion,skipped=False): return {"id":id,"name":name,"status":status,"conclusion":conclusion,"skipped":skipped}
def artifact(id,name,size,archive,local,disposition): return {"id":id,"name":name,"size_bytes":size,"archive_sha256":archive,"local_payload_sha256":local,"disposition":disposition}
def record(ordinal,pair,id,route,sha,jobs,artifacts,plan,commit,completeness,diagnosis):
 event="pull_request" if route=="pr" else "workflow_dispatch"
 return {"ordinal":ordinal,"pair":pair,"id":id,"url":f"https://github.com/szTheory/sigra/actions/runs/{id}","repository":"szTheory/sigra","route":route,"event":event,"attempt":1,"head_sha":sha,"overall_conclusion":"failure","selected_jobs":jobs,"artifacts":artifacts,"source_plan":plan,"source_summary_commit":commit,"metadata_completeness":completeness,"diagnosis_code":diagnosis,"status":"pair_inadmissible"}
P10="f631355d3e1831451cbf1f19ff1009e841229d91"; P12="cbf12238ed608fe471c1cb47fe5e327e919692d8"; P14="8d463e5a80d8f2a1bb2cdeebeb2d65347b19ccf2"
NEGATIVE_RUNS=[
 record(1,1,34466384009,"pr","f1d52a771b92b7f5f6cf6b3e8a840271f4b7ebc7",[],[],"plan10",P10,"summary_partial","format_before_partition_artifacts"),
 record(2,1,34466384470,"dispatch","f1d52a771b92b7f5f6cf6b3e8a840271f4b7ebc7",[],[artifact(10147739265,"library-install-golden-34466384470-1",None,"8212c2042dab29f18675afde498930362caa2c1f0c0c6fdf0f0f83f22dd1ced0",None,None)],"plan10",P10,"summary_partial","telemetry_poller_compile_failure"),
 record(3,2,34467186749,"pr","52bcf2b1b684d8cde46d0165f39d080d5be1b081",[],[artifact(10148082053,"library-partitions-34467186749-1",None,"8d728d228140c8e89a530b9ecf34583befd3586f6af6daaaab282338e0ead756",None,None),artifact(10148082894,"library-partition-1-timings-34467186749-1",None,"76191abcaa2d108d1283e19698b058018de5dc8cd8fac04bfc4dae8c6f7f837c",None,None),artifact(10148083798,"library-install-diagnostics-34467186749-1",None,"58228627b4e22f31f8066bf74164458b973164ab60568f6dd76b9ac6b86db70a",None,None)],"plan10",P10,"summary_partial","static_topology_failure"),
 record(4,2,34467189602,"dispatch","52bcf2b1b684d8cde46d0165f39d080d5be1b081",[],[artifact(10148071824,"library-install-golden-34467189602-1",None,"f366d7daf785cda252e5d5007c884cd3758b11a6513a8a886f6d7960e7dd525b",None,None)],"plan10",P10,"summary_partial","rebar_dag_enoent"),
 record(5,3,34468109536,"pr","cdba0b3908a639e069d59c115c23ad23a51deb67",[job(102841396162,"Library tests shard",None,"failure"),job(102842190884,"Library tests",None,"failure"),job(102843452149,"ci-gate",None,"failure")],[artifact(10148462165,"library-partitions-34468109536-1",None,"9b36eaa3bfddf4d9bd4e2e13e01c9570bfa0fa0605d2f09cc9eec2995308396",None,"Aggregate failure receipt only"),artifact(10148463067,"library-partition-2-timings-34468109536-1",None,"1752be6e4780449eaaf3b227780249cf30739463fd7f84b39deca49f7b0bb7ad",None,"Incomplete without partition 1")],"plan10",P10,"summary_partial","partition_1_receipt_absent"),
 record(6,3,34468110161,"dispatch","cdba0b3908a639e069d59c115c23ad23a51deb67",[job(102841373842,"Library install golden (non-PR)",None,"failure")],[artifact(10148436658,"library-install-golden-34468110161-1",None,"01cc78f7f15ff1a77bdfb7bec81ec64000e517218bbcbd8db9720b00d44c6d8a",None,"Failure receipt only; diagnostics absent")],"plan10",P10,"summary_partial","rebar_dag_enoent"),
 record(7,4,34493873867,"pr","a2d1840dfe17640184bebbe2bba786a53fdbf39b",[job(102927300896,"Library tests shard","completed","failure"),job(102928285406,"Library tests","completed","failure")],[artifact(10159034802,"library-partitions-34493873867-1",None,"c10db4699e9309b36e39764e4e712218eaa489f10ae8f674b6369d97687f2e13","49c170d06024652bc36abeb437794872f9d0a796ffc0b821fca63ffe0d3dec6c","Failure diagnosis only"),artifact(10159035434,"library-partition-2-timings-34493873867-1",None,"a023a17ab934160c82a479c5ac92ab4c852670fbe31df86999d49e8ef2ad0325","a25f7748ead0605bbaeddf3008ceb08809b88a558efbe99d5d8e75c3dc2b0c33","Incomplete without partition 1")],"plan12",P12,"summary_partial","partition_1_receipt_absent"),
 record(8,4,34493911924,"dispatch","a2d1840dfe17640184bebbe2bba786a53fdbf39b",[job(102927413441,"Library install golden (non-PR)","completed","failure")],[artifact(10159055568,"library-install-golden-34493911924-1",None,"e6a3f8b8d30aff3f30da8cb04646541a7d286b8fb6a86518b408e3a73b6e8056","48473ddc0e5d984eb8b5ddad6ef128eddd4d7c90a3ccea2f4b166aedd3fbbc93","Failure receipt only"),artifact(10159056428,"library-install-diagnostics-34493911924-1",None,"c1233c20c9ead0b1c6dfff5469eea04f37686b8c41c0cddac023df93be08fafb","5005431e3d345f630b787b99746bd8c210dbc179a533d6f2f9dbd753374e7151","Failure diagnosis only")],"plan12",P12,"summary_partial","golden_stdout_and_missing_rg"),
 record(9,5,34520992740,"pr","47f9578fc97edc63603953d446e79fac884326c3",[job(103018210710,"Library tests shard","completed","failure"),job(103019075175,"Library tests","completed","failure"),job(103020316305,"ci-gate","completed","failure")],[artifact(10169719106,"library-partitions-34520992740-1",3629,"7f664951b775ac66ba54a8b62cb4e56beae2630be44b197c74da40ce50ea0658",None,"Pair-inadmissible diagnostic only"),artifact(10169719887,"library-partition-1-timings-34520992740-1",32672,"f438e31b3a76d33a6c1e869d5f0219189a7de8d71cb1f42a8e495bf796ac530b",None,"Pair-inadmissible diagnostic only"),artifact(10169720713,"library-partition-2-timings-34520992740-1",53079,"8c33c79cc3b43648f18ceaf67ac50776a6d6d9cd9de62b5c16145eb2ca61c85b",None,"Pair-inadmissible diagnostic only")],"plan14",P14,"summary_complete","immutable_workflow_byte_drift"),
 record(10,5,34520986751,"dispatch","47f9578fc97edc63603953d446e79fac884326c3",[job(103018160561,"Library install golden (non-PR)","completed","success")],[artifact(10169749166,"library-install-golden-34520986751-1",467,"ffc0cdac67ac1158ccdf44e2e620f0e6b695df92d48e594896d9c7dc9fd286e9",None,"Pair-inadmissible diagnostic only"),artifact(10169750133,"library-install-diagnostics-34520986751-1",559,"46c4bd113239d2fff141bc94fb5ac860f419013f2a5cc8b132932d3ba69b921b",None,"Pair-inadmissible diagnostic only")],"plan14",P14,"summary_complete","unrelated_manual_ref_guards")]
def canonical(value): return (json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n").encode()
def sha(value): return hashlib.sha256(value).hexdigest()
# Plan 18's preflight authority is retained only as immutable negative history.
# Nothing traverses this structure when admitting current repository bytes.
HISTORICAL_NEGATIVE_AUTHORITY={
 ".github/workflows/ci.yml":"ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682",
 "test/support/ci/library_test_partitions.exs":"91646f072512d32e603b850ac44caa14825543b67188c5221eea6ccaf7738c97",
 "test/support/ci/library_test_partitions_test.exs":"3550a8bd2fa9f408c8477928f1e82eac5d418d6d50865d74d4173493bbc75ae5",
 ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json":"975612d7f3cbfda75fb6857791ebfd9bcadd852451b86a6b917871b3ba092eeb",
}
# This ordered, closed structure is the sole current --preflight authority.
CURRENT_ACTIVE_AUTHORITY=(
 (".github/workflows/ci.yml","ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682",None),
 ("test/support/ci/library_test_partitions.exs","9384fce2c84de95681d1e1ef08c7efec5bf993c2bd0abf9837c169f2fdefb103",None),
 ("test/support/ci/library_test_partitions_test.exs","61feccce1cd7fef696e55fcbb270c2cc80f0f8f1f29a4c3136b5a29caeecf92a",None),
 ("scripts/ci/library-partitions.sh","deae1229e1bfabea6924d2512db1293026d6904497c2ac804f0478afc04471dd",None),
 ("scripts/ci/verify-library-partitions.sh","449d239630013c0f25837763c1dfe494442f32ad8d8fe6c4275d4890b5219a54",None),
 (".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json","a217328185ccc2bb96e2925b8d2b5c897217bf5fd10057f95b53852426c96239",2987511),
 (".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION-MANIFEST.json","51d1531208c596d65014e136a3651080f130781b1cd706ce0d5955b752e00fa4",623),
)
if args and args[0]=="--print-negative-runs": sys.stdout.buffer.write(canonical(NEGATIVE_RUNS)); raise SystemExit
if args and args[0]=="--negative-runs-sha256": print(sha(canonical(NEGATIVE_RUNS))); raise SystemExit
if args and args[0]=="--print-active-authority":
 sys.stdout.buffer.write(canonical([{"path":path,"sha256":expected,"size_bytes":size} for path,expected,size in CURRENT_ACTIVE_AUTHORITY])); raise SystemExit
if args and args[0]=="--preflight":
 root=os.path.realpath(args[1] if len(args)>1 else ROOT)
 for path,expected,size in CURRENT_ACTIVE_AUTHORITY:
  full=os.path.realpath(os.path.join(root,path))
  if os.path.commonpath((root,full))!=root or full==root: fail("preflight path containment")
  try: data=open(full,"rb").read()
  except OSError as error: fail(f"immutable read {path}: {error}")
  if size is not None and len(data)!=size: fail(f"immutable byte size: {path}")
  if sha(data)!=expected: fail(f"immutable drift: {path}")
 print("verify-library-routing-evidence: PREFLIGHT PASS"); raise SystemExit
def load(path):
 try:
  def unique(pairs):
   out={}
   for key,value in pairs:
    if key in out: fail(f"duplicate key {key!r} in {path}")
    out[key]=value
   return out
  with open(path,encoding="utf-8") as handle: return json.load(handle,object_pairs_hook=unique)
 except (OSError,json.JSONDecodeError) as error: fail(f"could not read {path}: {error}")
def keys(value,expected,label):
 if not isinstance(value,dict) or set(value)!=set(expected): fail(f"{label} exact keys")
def integer(v): return isinstance(v,int) and not isinstance(v,bool)
def digest(v,n): return isinstance(v,str) and re.fullmatch(f"[0-9a-f]{{{n}}}",v) is not None
def forbid(value):
 if isinstance(value,dict):
  for key,item in value.items():
   if key in {"pass","passed","waived","waiver","retry_admitted","install_not_dominant","comparable","verdict"}: fail(f"forbidden authority key: {key}")
   forbid(item)
 elif isinstance(value,list):
  for item in value: forbid(item)
PR=args[0] if args else os.path.join(PHASE_DIR,"235.1-PR-EVIDENCE.json"); SC=args[1] if len(args)>1 else os.path.join(PHASE_DIR,"235.1-SCAFFOLD-EVIDENCE.json")
pr,sc=load(PR),load(SC); forbid(pr); forbid(sc)
keys(pr,["schema_version","repository","pr","run","owner","aggregate","artifacts","partitions","protected_invariants","commands","supersession","negative_runs"],"PR")
if pr["schema_version"]!="sigra.library-partitions-evidence/v1" or pr["repository"]!="szTheory/sigra": fail("PR identity")
keys(pr["pr"],["number"],"PR number")
if pr["pr"]["number"]!=234: fail("PR number")
keys(pr["run"],["id","url","event","attempt","head_sha","conclusion"],"PR run"); run=pr["run"]
if not integer(run["id"]) or run["id"]<=0 or run["event"]!="pull_request" or run["attempt"]!=1 or run["conclusion"]!="success" or not digest(run["head_sha"],40): fail("PR run provenance")
if run["url"]!=f"https://github.com/szTheory/sigra/actions/runs/{run['id']}": fail("PR URL")
for label,name in [("owner","Library tests shard"),("aggregate","Library tests")]:
 value=pr[label]; keys(value,["id","name","status","conclusion","skipped"],f"PR {label}")
 if not integer(value["id"]) or value["id"]<=0 or value["name"]!=name or value["status"]!="completed" or value["conclusion"]!="success" or value["skipped"] is not False: fail(f"PR {label} state")
if pr["owner"]["id"]==pr["aggregate"]["id"]: fail("PR job uniqueness")
expected_pr=[(f"library-partitions-{run['id']}-1","sigra-library-partitions.json"),(f"library-partition-1-timings-{run['id']}-1","sigra-library-1-timings.json"),(f"library-partition-2-timings-{run['id']}-1","sigra-library-2-timings.json")]
if not isinstance(pr["artifacts"],list) or len(pr["artifacts"])!=3: fail("PR artifacts")
for value,(name,file) in zip(pr["artifacts"],expected_pr):
 keys(value,["id","name","file","sha256"],"PR artifact")
 if not integer(value["id"]) or value["id"]<=0 or value["name"]!=name or value["file"]!=file or not digest(value["sha256"],64): fail("PR artifact identity")
parts=pr["partitions"]; keys(parts,["execution_mode","ordinary_universe_count","manifest_counts","test_counts","durations_ms","conclusions","exit_statuses"],"partitions")
if parts["execution_mode"]!="sequential" or not integer(parts["ordinary_universe_count"]): fail("partition identity")
for key in ["manifest_counts","test_counts","durations_ms"]:
 if not isinstance(parts[key],list) or len(parts[key])!=2 or not all(integer(v) and v>0 for v in parts[key]): fail(f"partition {key}")
# Admission arithmetic remains: max * 1000 <= min * 2000.
if sum(parts["manifest_counts"])!=parts["ordinary_universe_count"] or max(parts["durations_ms"])*1000>min(parts["durations_ms"])*2000 or parts["conclusions"]!=["success","success"] or parts["exit_statuses"]!=[0,0]: fail("partition admission")
protected={"library_tests_aggregate_sha256":"04308ef8fb56acc65c5730630e1fd3e926da6804068db07f6f15636c2a0890cb","sole_pr_owner":"MIX_ENV=test mix ci","fast_01_verifier":"source_complete_offline_attestation_verified","gate_05_verifier":"offline_attestation_verified"}
if pr["protected_invariants"]!=protected: fail("PR protected invariants")
rate="gh api rate_limit --jq '.resources.core | {remaining,reset}'"; fields="databaseId,event,headSha,conclusion,attempt,url,jobs"
expected={"rate_limit":rate,"watch":f"gh run watch {run['id']} --repo szTheory/sigra --compact --interval 60 --exit-status","summary":f"gh run view {run['id']} --repo szTheory/sigra --json {fields}","artifacts":[f"gh run download {run['id']} --repo szTheory/sigra --name {name}" for name,_ in expected_pr]}
if pr["commands"]!=expected: fail("PR commands")
if pr["supersession"]!={"plan04_status":"empirically superseded (failed evidence retained)","forbidden_predicates":["install_not_dominant","ordinary-vs-scaffold comparable"]}: fail("PR supersession")
keys(sc,["schema_version","repository","run","job","artifacts","receivers","diagnostics","protected_invariants","commands","supersession","negative_runs"],"scaffold")
if sc["schema_version"]!="sigra.library-install-golden-evidence/v1" or sc["repository"]!="szTheory/sigra": fail("scaffold identity")
keys(sc["run"],["id","url","event","attempt","head_sha","conclusion"],"scaffold run"); srun=sc["run"]
if not integer(srun["id"]) or srun["id"]<=0 or srun["event"]!="workflow_dispatch" or srun["attempt"]!=1 or srun["conclusion"] not in {"success","failure"} or not digest(srun["head_sha"],40): fail("scaffold provenance")
if srun["url"]!=f"https://github.com/szTheory/sigra/actions/runs/{srun['id']}": fail("scaffold URL")
keys(sc["job"],["id","name","status","conclusion","skipped"],"scaffold job")
if not integer(sc["job"]["id"]) or sc["job"]["id"]<=0 or sc["job"]["name"]!="Library install golden (non-PR)" or sc["job"]["status"]!="completed" or sc["job"]["conclusion"]!="success" or sc["job"]["skipped"] is not False: fail("scaffold job state")
expected_sc=[(f"library-install-golden-{srun['id']}-1","sigra-library-install-golden.json"),(f"library-install-diagnostics-{srun['id']}-1","sigra-install-golden-diagnostics.json")]
if not isinstance(sc["artifacts"],list) or len(sc["artifacts"])!=2: fail("scaffold artifacts")
for value,(name,file) in zip(sc["artifacts"],expected_sc):
 keys(value,["id","name","file","sha256"],"scaffold artifact")
 if not integer(value["id"]) or value["id"]<=0 or value["name"]!=name or value["file"]!=file or not digest(value["sha256"],64): fail("scaffold artifact identity")
paths=["test/sigra/install/features/passkeys_js_test.exs","test/sigra/install/generator_passkeys_opt_out_test.exs","test/sigra/install/golden_diff_test.exs","test/sigra/install/idempotency_test.exs","test/sigra/install/vault_promotion_test.exs","test/upgrade_test.exs"]
keys(sc["receivers"],["paths","count","duration_ms","exit_status","conclusion","prepared_fixture","worker_ceiling"],"receivers"); rec=sc["receivers"]
if rec["paths"]!=paths or rec["count"]!=6 or not integer(rec["duration_ms"]) or rec["duration_ms"]<=0 or rec["exit_status"]!=0 or rec["conclusion"]!="success" or rec["prepared_fixture"] is not True or rec["worker_ceiling"]!=2: fail("receiver facts")
if sc["diagnostics"]!={"schema_version":"sigra.install-fixture-diagnostics/v1","variant_count":6,"worker_count":2,"failed_paths":[],"raw_install_duration_ms":rec["duration_ms"]}: fail("diagnostics")
if sc["protected_invariants"]!={"non_pr_events":["schedule","workflow_dispatch"],"pr_execution":False,"hard_signal":True}: fail("scaffold protected")
expected={"rate_limit":rate,"watch":f"gh run watch {srun['id']} --repo szTheory/sigra --compact --interval 60 --exit-status","summary":f"gh run view {srun['id']} --repo szTheory/sigra --json {fields}","artifacts":[f"gh run download {srun['id']} --repo szTheory/sigra --name {name}" for name,_ in expected_sc]}
if sc["commands"]!=expected: fail("scaffold commands")
history={"failed_run_id":34435818106,"ordinary_duration_ms":28671,"install_duration_ms":79614,"safe_optimization_commits":["1fa788fc","488f4fa1"],"bounded_clean_local_range_ms":[56000,78000],"final_hard_stop_ms":57389,"status":"failed evidence retained"}
if sc["supersession"]!=history: fail("scaffold supersession")
if pr["negative_runs"]!=NEGATIVE_RUNS or sc["negative_runs"]!=NEGATIVE_RUNS: fail("canonical negative runs")
if canonical(pr["negative_runs"])!=canonical(sc["negative_runs"]): fail("negative run byte identity")
negative_ids={value["id"] for value in NEGATIVE_RUNS}
if run["id"] in negative_ids or srun["id"] in negative_ids or run["id"]==srun["id"]: fail("fresh run disjointness")
if run["head_sha"]!=srun["head_sha"]: fail("capture SHA equality")
print("verify-library-routing-evidence: PASS")
PY
