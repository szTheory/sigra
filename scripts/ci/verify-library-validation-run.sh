#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
VALIDATION="${1:-$PHASE_DIR/235.1-VALIDATION-RUN.json}"
PR="${2:-$PHASE_DIR/235.1-PR-EVIDENCE.json}"
SCAFFOLD="${3:-$PHASE_DIR/235.1-SCAFFOLD-EVIDENCE.json}"
"$ROOT/scripts/ci/verify-library-routing-evidence.sh" "$PR" "$SCAFFOLD" >/dev/null
python3 - "$VALIDATION" "$PR" "$SCAFFOLD" <<'PY'
import hashlib,json,re,sys
def fail(m): raise SystemExit("verify-library-validation-run: FAIL: "+m)
def load(path):
 try:
  def unique(pairs):
   out={}
   for k,v in pairs:
    if k in out: fail(f"duplicate key {k!r}")
    out[k]=v
   return out
  return json.load(open(path,encoding="utf-8"),object_pairs_hook=unique)
 except (OSError,json.JSONDecodeError) as e: fail(str(e))
def keys(v,w,l):
 if not isinstance(v,dict) or set(v)!=set(w):fail(l+" exact keys")
def integer(v):return isinstance(v,int) and not isinstance(v,bool)
def digest(v,n):return isinstance(v,str) and re.fullmatch(f"[0-9a-f]{{{n}}}",v) is not None
def forbid(v):
 if isinstance(v,dict):
  for k,x in v.items():
   if k in {"pass","passed","waiver","waived","retry_admitted","verdict"}:fail("forbidden authority")
   forbid(x)
 elif isinstance(v,list):
  for x in v:forbid(x)
v,pr,sc=map(load,sys.argv[1:]);forbid(v)
keys(v,["schema_version","repository","evidence_commit_sha","capture_run_ids","negative_run_ids","negative_runs_sha256","validations","commands"],"validation")
if v["schema_version"]!="sigra.library-routing-validation/v1" or v["repository"]!="szTheory/sigra" or not digest(v["evidence_commit_sha"],40):fail("identity")
capture=[pr["run"]["id"],sc["run"]["id"]]
negative=pr["negative_runs"]
negative_ids=[x["id"] for x in negative]
canonical=(json.dumps(negative,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n").encode()
if sc["negative_runs"]!=negative or v["capture_run_ids"]!=capture or v["negative_run_ids"]!=negative_ids or v["negative_runs_sha256"]!=hashlib.sha256(canonical).hexdigest():fail("history binding")
if not isinstance(v["validations"],list) or len(v["validations"])!=2:fail("two validations")
expected=[("pr","pull_request",["Library tests shard","Library tests"]),("dispatch","workflow_dispatch",["Library install golden (non-PR)"])]
ids=[]
for item,(route,event,names) in zip(v["validations"],expected):
 keys(item,["route","run","selected_jobs"],route)
 if item["route"]!=route:fail("route order")
 run=item["run"];keys(run,["id","url","event","attempt","head_sha","conclusion"],route+" run")
 if not integer(run["id"]) or run["id"]<=0 or run["url"]!=f"https://github.com/szTheory/sigra/actions/runs/{run['id']}" or run["event"]!=event or run["attempt"]!=1 or run["head_sha"]!=v["evidence_commit_sha"] or run["conclusion"] not in {"success","failure"}:fail(route+" provenance")
 ids.append(run["id"])
 if not isinstance(item["selected_jobs"],list) or len(item["selected_jobs"])!=len(names):fail(route+" jobs")
 for job,name in zip(item["selected_jobs"],names):
  keys(job,["id","name","status","conclusion","skipped"],route+" job")
  if not integer(job["id"]) or job["id"]<=0 or job["name"]!=name or job["status"]!="completed" or job["conclusion"]!="success" or job["skipped"] is not False:fail(route+" selected job")
if len(set(ids+capture+negative_ids))!=len(ids)+len(capture)+len(negative_ids):fail("run disjointness")
keys(v["commands"],["rate_limit","watch","summary"],"commands")
rate="gh api rate_limit --jq '.resources.core | {remaining,reset}'";fields="databaseId,event,headSha,conclusion,attempt,url,jobs"
if v["commands"]["rate_limit"]!=[rate,rate]:fail("rate commands")
if v["commands"]["watch"]!=[f"gh run watch {i} --repo szTheory/sigra --compact --interval 60 --exit-status" for i in ids]:fail("watch commands")
if v["commands"]["summary"]!=[f"gh run view {i} --repo szTheory/sigra --json {fields}" for i in ids]:fail("summary commands")
print("verify-library-validation-run: PASS")
PY
