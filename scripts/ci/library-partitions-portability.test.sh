#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/library-partitions.sh"
ORACLE="$ROOT/test/support/ci/library_test_partitions.exs"
PHASE_DIR="$ROOT/.planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
CALIBRATION="$PHASE_DIR/235.1-PARTITION-CALIBRATION.json"
MANIFEST="$PHASE_DIR/235.1-PARTITION-CALIBRATION-MANIFEST.json"
AUTHORITY_VERIFY="$ROOT/scripts/ci/verify-library-routing-evidence.sh"

fail() { printf 'library-partitions-portability.test: FAIL: %s\n' "$*" >&2; exit 1; }

system_bash=/bin/bash
[[ -x "$system_bash" ]] || fail "/bin/bash is unavailable"
system_major="$($system_bash -c 'printf %s "${BASH_VERSINFO[0]}"')"
if [[ "$(uname -s)" == "Darwin" && "$system_major" != "3" ]]; then
  fail "macOS /bin/bash must exercise Bash 3"
fi

modern_bash=""
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /opt/local/bin/bash; do
  if [[ -x "$candidate" ]] && [[ "$($candidate -c 'printf %s "${BASH_VERSINFO[0]}"')" -ge 5 ]]; then
    modern_bash="$candidate"
    break
  fi
done
if [[ -z "$modern_bash" ]]; then
  candidate="$(command -v bash || true)"
  if [[ -n "$candidate" && -x "$candidate" ]] && [[ "$($candidate -c 'printf %s "${BASH_VERSINFO[0]}"')" -ge 5 ]]; then
    modern_bash="$candidate"
  fi
fi
[[ -n "$modern_bash" ]] || fail "a Bash 5-or-newer test runtime is required"
modern_major="$($modern_bash -c 'printf %s "${BASH_VERSINFO[0]}"')"
[[ "$modern_bash" != "$system_bash" && "$modern_major" != "$system_major" ]] ||
  fail "system and modern Bash runtimes must be distinct"

grep -Fq 'System.cmd("git", ["-C", root, "ls-files", "-z"' "$ORACLE" ||
  fail "ordinary discovery is not NUL-safe git ls-files -z"
grep -Fq 'mix test "${paths[@]}"' "$RUNNER" || fail "partition argv is not quoted"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-library-portability.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

# The fake child records exact argv with NUL terminators. The oracle includes
# spaces and glob metacharacters and writes one absolute timing path so that the
# production normalization path is exercised rather than approximated here.
printf '%s\n' \
  '#!/bin/bash' \
  'set -eu' \
  'if [[ "${1:-}" == "run" ]]; then' \
  '  if [[ "${EMPTY_PARTITION:-}" == "1" ]]; then' \
  '    printf "2\\ttest/z final_test.exs\\n"' \
  '  else' \
  '    printf "1\\ttest/a space_test.exs\\n1\\ttest/literal[abc]*_test.exs\\n2\\ttest/z final_test.exs\\n"' \
  '  fi' \
  '  exit 0' \
  'fi' \
  'if [[ "${1:-}" == "test" ]]; then' \
  '  partition="${MIX_TEST_PARTITION:?}"' \
  '  printf "%s\\0" "$@" >>"${ARGV_LOG:?}"' \
  '  printf "%s\\n" "$partition" >>"${ORDER_LOG:?}"' \
  '  if [[ -n "${CHILD_DELAY_SECONDS:-}" ]]; then sleep "$CHILD_DELAY_SECONDS"; fi' \
  '  case "$partition" in' \
  '    1) files="${TIMING_FILES_JSON:-[\"${REPO_ROOT:?}/test/a space_test.exs\",\"test/literal[abc]*_test.exs\"]}" ;;' \
  '    2) files='"'"'["test/z final_test.exs"]'"'"' ;;' \
  '    *) exit 91 ;;' \
  '  esac' \
  '  jq -n --argjson files "$files" '"'"'{schema_version:1,tests:[$files[]|{file:.,module:"Portable",name:"test argv",time_us:1,outcome:"passed"}],total:($files|length),passed:($files|length),failed:0,skipped:0,excluded:0,invalid:0}'"'"' >"${SIGRA_EXUNIT_TIMING_PATH:?}"' \
  '  if [[ "${FAIL_PARTITION:-}" == "$partition" ]]; then exit "${FAIL_STATUS:-42}"; fi' \
  '  exit 0' \
  'fi' \
  'exit 99' >"$test_root/bin/mix"
chmod +x "$test_root/bin/mix"

mkdir -p "$test_root/clock-bin"
printf '%s\n' \
  '#!/bin/bash' \
  'set -eu' \
  'sequence=${CLOCK_SEQUENCE:?}' \
  'lock=${sequence}.lock' \
  'attempts=0' \
  'until mkdir "$lock" 2>/dev/null; do attempts=$((attempts + 1)); [[ "$attempts" -lt 1000 ]] || exit 72; done' \
  'trap '\''rmdir "$lock" 2>/dev/null || true'\'' EXIT' \
  'value=$(sed -n '\''1p'\'' "$sequence")' \
  '[[ -n "$value" ]] || exit 73' \
  'sed '\''1d'\'' "$sequence" >"${sequence}.next"' \
  'mv "${sequence}.next" "$sequence"' \
  'printf '\''%s\n'\'' "$value"' >"$test_root/clock-bin/python3"
chmod +x "$test_root/clock-bin/python3"
mkdir -p "$test_root/real-clock-bin"
printf '%s\n' '#!/bin/bash' 'exec /usr/bin/python3 "$@"' >"$test_root/real-clock-bin/python3"
chmod +x "$test_root/real-clock-bin/python3"

# Exercise the production runner through a lexical symlink while formatter rows
# identify the same repository by its physical path. Each hostile row is driven
# through normalize_timing_paths in the runner, never through a test duplicate.
physical_repo="$test_root/physical-repo"
alias_repo="$test_root/lexical-repo"
mkdir -p "$physical_repo/scripts/ci"
cp "$RUNNER" "$physical_repo/scripts/ci/library-partitions.sh"
ln -s "$physical_repo" "$alias_repo"
physical_repo="$(cd "$physical_repo" && pwd -P)"

run_alias_path_case() {
  local label="$1" shell="$2" candidate="$3" expected="$4" case_root="$test_root/alias-$1-$5" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  set +e
  PATH="$test_root/bin:$PATH" REPO_ROOT="$physical_repo" TIMING_FILES_JSON="[\"$candidate\"]" \
    ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$alias_repo/scripts/ci/library-partitions.sh" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  if [[ "$expected" == success ]]; then
    [[ "$status" == 0 ]] || fail "$label rejected safe alias path '$candidate' with status $status"
    cp /tmp/sigra-library-1-timings.json "$case_root/timing.json"
    [[ "$(jq -r '.tests[0].file' "$case_root/timing.json")" == "test/safe_test.exs" ]] ||
      fail "$label did not canonicalize safe alias path"
  else
    [[ "$status" != 0 ]] || fail "$label accepted hostile alias path '$candidate'"
    cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
    jq -e '.partitions[0].conclusion == "failure" and .partitions[1].conclusion == "not_run"' \
      "$case_root/receipt.json" >/dev/null || fail "$label published an untruthful hostile receipt"
  fi
}

run_alias_matrix() {
  local label="$1" shell="$2"
  run_alias_path_case "$label physical" "$shell" "$physical_repo/test/safe_test.exs" success physical
  run_alias_path_case "$label relative" "$shell" "test/safe_test.exs" success relative
  run_alias_path_case "$label external" "$shell" "$test_root/external/test/safe_test.exs" failure external
  run_alias_path_case "$label sibling-prefix" "$shell" "${physical_repo}-sibling/test/safe_test.exs" failure sibling
  run_alias_path_case "$label parent" "$shell" "test/../safe_test.exs" failure parent
  run_alias_path_case "$label dot" "$shell" "test/./safe_test.exs" failure dot
  run_alias_path_case "$label double-separator" "$shell" "test//safe_test.exs" failure double
  run_alias_path_case "$label non-test" "$shell" "lib/safe_test.exs" failure nontest
  run_alias_path_case "$label wrong-suffix" "$shell" "test/safe.exs" failure suffix
}

run_alias_matrix system "$system_bash"
run_alias_matrix modern "$modern_bash"

run_nonempty() {
  local label="$1" shell="$2" case_root="$test_root/$1-nonempty" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  set +e
  PATH="$test_root/bin:$PATH" REPO_ROOT="$ROOT" ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  if [[ "$status" != 0 ]]; then
    if grep -Fq 'paths: unbound variable' "$case_root/stderr"; then
      fail "$label production loader hit paths: unbound variable"
    fi
    sed -n '1,20p' "$case_root/stderr" >&2
    fail "$label production loader failed with status $status"
  fi
  cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
  cp /tmp/sigra-library-1-timings.json "$case_root/timing-1.json"
  cp /tmp/sigra-library-2-timings.json "$case_root/timing-2.json"
}

run_empty() {
  local label="$1" shell="$2" case_root="$test_root/$1-empty" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  set +e
  PATH="$test_root/bin:$PATH" REPO_ROOT="$ROOT" ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" EMPTY_PARTITION=1 \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  [[ "$status" != 0 ]] || fail "$label accepted an empty partition"
  [[ "$(cat "$case_root/stderr")" == 'library-partitions: FAIL: partition 1 is empty' ]] ||
    fail "$label empty-partition diagnostic differed"
  ! grep -Eqi 'unbound variable|nounset' "$case_root/stderr" ||
    fail "$label empty partition triggered a nounset diagnostic"
  [[ ! -s "$case_root/argv.bin" && ! -s "$case_root/order.txt" ]] ||
    fail "$label empty partition reached a child test process"
  cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
}

run_controlled_clock() {
  local label="$1" shell="$2" case_root="$test_root/$1-controlled" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  printf '%s\n' 1700000000000 1700000000125 1700000001000 1700000001225 >"$case_root/clock.sequence"
  set +e
  PATH="$test_root/clock-bin:$test_root/bin:$PATH" CLOCK_SEQUENCE="$case_root/clock.sequence" \
    REPO_ROOT="$ROOT" ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  if [[ "$status" != 0 ]]; then
    sed -n '1,20p' "$case_root/stderr" >&2
    fail "$label controlled-clock runner failed with status $status"
  fi
  cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
  [[ ! -s "$case_root/clock.sequence" ]] || fail "$label controlled clock did not consume exactly four values"
}

run_real_clock() {
  local label="$1" shell="$2" case_root="$test_root/$1-real-clock" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  set +e
  PATH="$test_root/real-clock-bin:$test_root/bin:$PATH" CHILD_DELAY_SECONDS=0.08 REPO_ROOT="$ROOT" \
    ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  [[ "$status" == 0 ]] || fail "$label real-clock runner failed with status $status"
  cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
}

run_bad_clock() {
  local label="$1" shell="$2" kind="$3" values="$4" case_root="$test_root/$1-$3-clock" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  printf '%s' "$values" >"$case_root/clock.sequence"
  set +e
  PATH="$test_root/clock-bin:$test_root/bin:$PATH" CLOCK_SEQUENCE="$case_root/clock.sequence" \
    REPO_ROOT="$ROOT" ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  [[ "$status" != 0 ]] || fail "$label accepted $kind controlled clock"
}

run_child_failure() {
  local label="$1" shell="$2" case_root="$test_root/$1-child-failure" status
  mkdir -p "$case_root"
  : >"$case_root/argv.bin"
  : >"$case_root/order.txt"
  set +e
  PATH="$test_root/bin:$PATH" FAIL_PARTITION=1 FAIL_STATUS=42 REPO_ROOT="$ROOT" \
    ARGV_LOG="$case_root/argv.bin" ORDER_LOG="$case_root/order.txt" \
    "$shell" "$RUNNER" >"$case_root/stdout" 2>"$case_root/stderr"
  status=$?
  set -e
  [[ "$status" == 42 ]] || fail "$label did not propagate first-child status 42 (got $status)"
  cp /tmp/sigra-library-partitions.json "$case_root/receipt.json"
}

run_nonempty system "$system_bash"
run_empty system "$system_bash"
run_controlled_clock system "$system_bash"
run_real_clock system "$system_bash"
run_bad_clock system "$system_bash" malformed $'not-an-integer\n'
run_bad_clock system "$system_bash" regressing $'1700000000100\n1700000000000\n'
run_bad_clock system "$system_bash" exhausted $'1700000000000\n'
run_child_failure system "$system_bash"
run_nonempty modern "$modern_bash"
run_empty modern "$modern_bash"
run_controlled_clock modern "$modern_bash"
run_real_clock modern "$modern_bash"
run_bad_clock modern "$modern_bash" malformed $'not-an-integer\n'
run_bad_clock modern "$modern_bash" regressing $'1700000000100\n1700000000000\n'
run_bad_clock modern "$modern_bash" exhausted $'1700000000000\n'
run_child_failure modern "$modern_bash"

python3 - "$ROOT" "$test_root" <<'PY'
import hashlib,json,os,sys
root,test_root=sys.argv[1:]
expected_argv=[
 b"test",b"test/a space_test.exs",b"test/literal[abc]*_test.exs",b"--formatter",b"ExUnit.CLIFormatter",b"--formatter",b"Sigra.CI.ExUnitTimingFormatter",
 b"test",b"test/z final_test.exs",b"--formatter",b"ExUnit.CLIFormatter",b"--formatter",b"Sigra.CI.ExUnitTimingFormatter",
]
expected_paths=[["test/a space_test.exs","test/literal[abc]*_test.exs"],["test/z final_test.exs"]]
semantic=[]
for label in ("system","modern"):
 case=os.path.join(test_root,label+"-nonempty")
 raw=open(os.path.join(case,"argv.bin"),"rb").read()
 assert raw.endswith(b"\0") and raw[:-1].split(b"\0")==expected_argv
 assert open(os.path.join(case,"order.txt"),encoding="utf-8").read()=="1\n2\n"
 r=json.load(open(os.path.join(case,"receipt.json"),encoding="utf-8"))
 assert set(r)=={"schema_version","execution_mode","ordinary_universe","partitions"}
 assert r["schema_version"]=="sigra.library-partitions/v1" and r["execution_mode"]=="sequential"
 assert r["ordinary_universe"]=={"paths":sorted(sum(expected_paths,[])),"count":3,"missing":[],"stale":[],"duplicate":[],"scaffold_leaks":[]}
 assert [p["paths"] for p in r["partitions"]]==expected_paths
 assert [p["conclusion"] for p in r["partitions"]]==["success","success"]
 assert [p["exit_status"] for p in r["partitions"]]==[0,0]
 for p,paths in zip(r["partitions"],expected_paths):
  assert p["manifest_sha256"]==hashlib.sha256(("\n".join(paths)+"\n").encode()).hexdigest()
  assert p["duration_ms"]==p["end_ms"]-p["start_ms"] and p["duration_ms"]>0
  timing=json.load(open(os.path.join(case,"timing-%s.json"%p["id"]),encoding="utf-8"))
  assert all(row["file"].startswith("test/") for row in timing["tests"])
 semantic.append((r["ordinary_universe"],[{k:p[k] for k in ("id","paths","manifest_sha256","timing_receipt_path","conclusion","exit_status")} for p in r["partitions"]]))
assert semantic[0]==semantic[1]
for label in ("system","modern"):
 r=json.load(open(os.path.join(test_root,label+"-empty","receipt.json"),encoding="utf-8"))
 assert r["ordinary_universe"]["paths"]==["test/z final_test.exs"]
 assert [p["conclusion"] for p in r["partitions"]]==["failure","not_run"]
 assert [p["exit_status"] for p in r["partitions"]]==[1,0]
for label in ("system","modern"):
 r=json.load(open(os.path.join(test_root,label+"-controlled","receipt.json"),encoding="utf-8"))
 assert [(p["start_ms"],p["end_ms"],p["duration_ms"]) for p in r["partitions"]]==[(1700000000000,1700000000125,125),(1700000001000,1700000001225,225)]
 assert [p["conclusion"] for p in r["partitions"]]==["success","success"]
 assert [p["exit_status"] for p in r["partitions"]]==[0,0]
 r=json.load(open(os.path.join(test_root,label+"-real-clock","receipt.json"),encoding="utf-8"))
 for p in r["partitions"]:
  assert p["end_ms"]>p["start_ms"]
  assert p["duration_ms"]==p["end_ms"]-p["start_ms"]
  assert 60<=p["duration_ms"]<5000
 r=json.load(open(os.path.join(test_root,label+"-child-failure","receipt.json"),encoding="utf-8"))
 assert [p["conclusion"] for p in r["partitions"]]==["failure","not_run"]
 assert [p["exit_status"] for p in r["partitions"]]==[42,0]
 assert open(os.path.join(test_root,label+"-child-failure","order.txt"),encoding="utf-8").read()=="1\n"
PY

if grep -Eq '(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)' "$RUNNER"; then
  fail "runner contains a Bash-4-only manifest reader"
fi

PATH="${PATH#"$test_root/bin:"}" ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-28.4.1}" MIX_ENV=test \
  mix run --no-compile --no-start -r "$ORACLE" -e \
  'p=Sigra.CI.LibraryTestPartitions.build_partitions!(); for id <- [1,2] do x=p[id]; IO.puts("META\t#{id}\t#{length(x.paths)}\t#{x.total_us}\t#{Sigra.CI.LibraryTestPartitions.manifest_sha256(x.paths)}"); Enum.each(x.paths,&IO.puts("PATH\t#{id}\t#{&1}")) end' \
  >"$test_root/oracle.tsv"

"$AUTHORITY_VERIFY" --print-active-authority >"$test_root/active-authority.json"

python3 - "$ROOT" "$test_root/oracle.tsv" "$CALIBRATION" "$MANIFEST" "$test_root/active-authority.json" <<'PY'
import copy,hashlib,json,os,sys
root,oracle_path,calibration_path,manifest_path,authority_path=sys.argv[1:]
calibration_relative=os.path.relpath(calibration_path,root)
manifest_relative=os.path.relpath(manifest_path,root)
portability_relative="scripts/ci/library-partitions-portability.test.sh"

def sha(data): return hashlib.sha256(data).hexdigest()
def canonical(value): return (json.dumps(value,sort_keys=True,separators=(",",":"))+"\n").encode()
def newline_manifest(values): return sha(("\n".join(values)+"\n").encode())

def check(meta,paths,cal,manifest,cal_bytes,manifest_bytes,authority):
 assert set(meta)==set(paths)=={1,2}
 assert all(paths[pid] and paths[pid]==sorted(paths[pid]) for pid in (1,2))
 assert not set(paths[1])&set(paths[2])
 universe=cal["ordinary_universe"]
 all_paths=sorted(paths[1]+paths[2])
 assert len(all_paths)==len(set(all_paths))==universe["count"]
 assert all_paths==universe["paths"]
 source=universe["source_files"]
 assert [row["path"] for row in source]==all_paths
 assert sha(("\0".join(all_paths)+"\0").encode())==universe["nul_manifest_sha256"]
 costs={row["path"]:row["time_us"] for row in cal["derived_costs"]}
 assert len(costs)==len(cal["derived_costs"]) and set(costs)==set(all_paths)
 for pid in (1,2):
  count,total,digest=meta[pid]
  assert count==len(paths[pid])
  assert total==sum(costs[path] for path in paths[pid])
  assert digest==newline_manifest(paths[pid])
 source_digest=sha(canonical(source))
 assert source_digest==manifest["ordinary_source_index_sha256"]
 for row in source:
  data=open(os.path.join(root,row["path"]),"rb").read()
  assert len(data)==row["byte_count"] and sha(data)==row["sha256"]
 binding=manifest["calibration"]
 assert binding["path"]==calibration_relative
 assert binding["byte_count"]==len(cal_bytes) and binding["sha256"]==sha(cal_bytes)
 entries=[entry for entry in authority if entry["path"] in (calibration_relative,manifest_relative)]
 assert len(entries)==2 and len({entry["path"] for entry in entries})==2
 by_path={entry["path"]:entry for entry in entries}
 assert portability_relative not in {entry["path"] for entry in authority}
 assert by_path[calibration_relative]=={"path":calibration_relative,"sha256":sha(cal_bytes),"size_bytes":len(cal_bytes)}
 assert by_path[manifest_relative]=={"path":manifest_relative,"sha256":sha(manifest_bytes),"size_bytes":len(manifest_bytes)}
 assert by_path[calibration_relative]["sha256"]==binding["sha256"]
 assert by_path[calibration_relative]["size_bytes"]==binding["byte_count"]

lines=open(oracle_path,encoding="utf-8").read().splitlines()
meta={}; paths={1:[],2:[]}
for line in lines:
 kind,pid,*rest=line.split("\t"); pid=int(pid)
 if kind=="META":
  assert pid not in meta and len(rest)==3
  meta[pid]=(int(rest[0]),int(rest[1]),rest[2])
 elif kind=="PATH":
  assert len(rest)==1
  paths.setdefault(pid,[]).append(rest[0])
 else: raise AssertionError(line)
cal_bytes=open(calibration_path,"rb").read()
manifest_bytes=open(manifest_path,"rb").read()
cal=json.loads(cal_bytes); manifest=json.loads(manifest_bytes)
authority=json.load(open(authority_path,encoding="utf-8"))

pristine=(meta,paths,cal,manifest,cal_bytes,manifest_bytes,authority)
check(*pristine)
def rejects(label,mutate):
 values=list(copy.deepcopy(pristine))
 mutate(values)
 try: check(*values)
 except (AssertionError,KeyError,TypeError,ValueError): pass
 else: raise AssertionError("accepted "+label)
 check(*pristine)

rejects("reported count",lambda v:v[0].__setitem__(1,(v[0][1][0]+1,*v[0][1][1:])))
rejects("reported total",lambda v:v[0].__setitem__(1,(v[0][1][0],v[0][1][1]+1,v[0][1][2])))
rejects("partition manifest",lambda v:v[0].__setitem__(1,(*v[0][1][:2],"0"*64)))
rejects("dropped membership",lambda v:v[1][1].pop())
rejects("duplicated membership",lambda v:v[1][1].append(v[1][1][-1]))
def swap_membership(values):
 values[1][1][0],values[1][2][0]=values[1][2][0],values[1][1][0]
 values[1][1].sort(); values[1][2].sort()
rejects("swapped membership",swap_membership)
rejects("calibration artifact bytes",lambda v:v.__setitem__(4,v[4]+b"X"))
rejects("calibration binding digest",lambda v:v[3]["calibration"].__setitem__("sha256","0"*64))
rejects("calibration binding size",lambda v:v[3]["calibration"].__setitem__("byte_count",v[3]["calibration"]["byte_count"]+1))
def mutate_active(values,path,key,value):
 next(entry for entry in values[6] if entry["path"]==path)[key]=value
rejects("active calibration digest",lambda v:mutate_active(v,calibration_relative,"sha256","0"*64))
rejects("active calibration size",lambda v:mutate_active(v,calibration_relative,"size_bytes",len(v[4])+1))
rejects("active manifest digest",lambda v:mutate_active(v,manifest_relative,"sha256","0"*64))
rejects("active manifest size",lambda v:mutate_active(v,manifest_relative,"size_bytes",len(v[5])+1))
PY

printf 'library-partitions-portability.test: PASS (system bash %s; modern bash %s)\n' "$system_major" "$modern_major"
