#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/library-partitions.sh"
ORACLE="$ROOT/test/support/ci/library_test_partitions.exs"
PHASE_DIR="$ROOT/.planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
CALIBRATION="$PHASE_DIR/235.1-PARTITION-CALIBRATION.json"
MANIFEST="$PHASE_DIR/235.1-PARTITION-CALIBRATION-MANIFEST.json"

fail() { printf 'library-partitions-portability.test: FAIL: %s\n' "$*" >&2; exit 1; }
digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# The production runner must remain valid for the system Bash shipped by macOS.
if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "$(/bin/bash -c 'printf %s "${BASH_VERSINFO[0]}"')" == "3" ]] ||
    fail "macOS /bin/bash must exercise Bash 3"
fi
grep -Fq 'System.cmd("git", ["-C", root, "ls-files", "-z"' "$ORACLE" ||
  fail "ordinary discovery is not NUL-safe git ls-files -z"
grep -Fq 'mix test "${paths[@]}"' "$RUNNER" || fail "partition argv is not quoted"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-library-portability.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

# The fake child records every argument with a NUL terminator. Its oracle paths
# deliberately contain shell metacharacters that would expand if quoting drifted.
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
  '  case "$partition" in' \
  '    1) files='"'"'["test/a space_test.exs","test/literal[abc]*_test.exs"]'"'"' ;;' \
  '    2) files='"'"'["test/z final_test.exs"]'"'"' ;;' \
  '    *) exit 91 ;;' \
  '  esac' \
  '  jq -n --argjson files "$files" '"'"'{schema_version:1,tests:[$files[]|{file:.,module:"Portable",name:"test argv",time_us:1,outcome:"passed"}],total:($files|length),passed:($files|length),failed:0,skipped:0,excluded:0,invalid:0}'"'"' >"${SIGRA_EXUNIT_TIMING_PATH:?}"' \
  '  exit 0' \
  'fi' \
  'exit 99' >"$test_root/bin/mix"
chmod +x "$test_root/bin/mix"

argv_log="$test_root/argv.bin"
order_log="$test_root/order.txt"
PATH="$test_root/bin:$PATH" ARGV_LOG="$argv_log" ORDER_LOG="$order_log" /bin/bash "$RUNNER"
if grep -Eq '(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)' "$RUNNER"; then
  fail "runner contains a Bash-4-only manifest reader"
fi

python3 - "$argv_log" "$order_log" /tmp/sigra-library-partitions.json <<'PY'
import hashlib,json,sys
argv_path,order_path,receipt_path=sys.argv[1:]
raw=open(argv_path,"rb").read()
assert raw.endswith(b"\0")
argv=raw[:-1].split(b"\0")
expected=[
 b"test",b"test/a space_test.exs",b"test/literal[abc]*_test.exs",b"--formatter",b"ExUnit.CLIFormatter",b"--formatter",b"Sigra.CI.ExUnitTimingFormatter",
 b"test",b"test/z final_test.exs",b"--formatter",b"ExUnit.CLIFormatter",b"--formatter",b"Sigra.CI.ExUnitTimingFormatter",
]
assert argv==expected, (argv,expected)
assert open(order_path,encoding="utf-8").read()=="1\n2\n"
r=json.load(open(receipt_path,encoding="utf-8"))
assert set(r)=={"schema_version","execution_mode","ordinary_universe","partitions"}
assert r["schema_version"]=="sigra.library-partitions/v1" and r["execution_mode"]=="sequential"
expected_paths=[["test/a space_test.exs","test/literal[abc]*_test.exs"],["test/z final_test.exs"]]
assert r["ordinary_universe"]=={"paths":sorted(sum(expected_paths,[])),"count":3,"missing":[],"stale":[],"duplicate":[],"scaffold_leaks":[]}
assert [p["paths"] for p in r["partitions"]]==expected_paths
assert [p["conclusion"] for p in r["partitions"]]==["success","success"]
assert [p["exit_status"] for p in r["partitions"]]==[0,0]
for p,paths in zip(r["partitions"],expected_paths):
 data=("\n".join(paths)+"\n").encode()
 assert p["manifest_sha256"]==hashlib.sha256(data).hexdigest()
 assert p["duration_ms"]==p["end_ms"]-p["start_ms"] and p["duration_ms"]>0
PY

: >"$argv_log"
: >"$order_log"
set +e
PATH="$test_root/bin:$PATH" ARGV_LOG="$argv_log" ORDER_LOG="$order_log" EMPTY_PARTITION=1 \
  /bin/bash "$RUNNER" >"$test_root/empty.stdout" 2>"$test_root/empty.stderr"
empty_status=$?
set -e
[[ "$empty_status" != 0 ]] || fail "empty partition was accepted"
grep -Fq 'partition 1 is empty' "$test_root/empty.stderr" || fail "empty partition diagnostic missing"
[[ ! -s "$argv_log" ]] || fail "empty manifest reached a child test process"

# Replay the production oracle without running ExUnit and compare its complete
# assignment and source binding to the immutable Plan 22 calibration.
PATH="${PATH#"$test_root/bin:"}" ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-28.4.1}" MIX_ENV=test \
  mix run --no-compile --no-start -r "$ORACLE" -e \
  'p=Sigra.CI.LibraryTestPartitions.build_partitions!(); for id <- [1,2] do x=p[id]; IO.puts("META\\t#{id}\\t#{length(x.paths)}\\t#{x.total_us}\\t#{Sigra.CI.LibraryTestPartitions.manifest_sha256(x.paths)}"); Enum.each(x.paths,&IO.puts("PATH\\t#{id}\\t#{&1}")) end' \
  >"$test_root/oracle.tsv"

python3 - "$ROOT" "$test_root/oracle.tsv" "$CALIBRATION" "$MANIFEST" <<'PY'
import hashlib,json,os,sys
root,oracle_path,calibration_path,manifest_path=sys.argv[1:]
lines=open(oracle_path,encoding="utf-8").read().splitlines()
meta={}; paths={1:[],2:[]}
for line in lines:
 kind,pid,*rest=line.split("\t")
 pid=int(pid)
 if kind=="META": meta[pid]=(int(rest[0]),int(rest[1]),rest[2])
 elif kind=="PATH": paths[pid].append(rest[0])
 else: raise AssertionError(line)
assert meta=={
 1:(111,22878707,"8e5c31efc1ca73ca05939c70b423e579d86944ecfc49b693fb93d6e2c356aabc"),
 2:(114,22878706,"1740e9fee3f3670d64ad8a843dda90935797b7204640e83e979cb18d212e044a"),
}
assert all(values==sorted(values) for values in paths.values())
all_paths=sorted(paths[1]+paths[2])
assert len(all_paths)==225 and len(set(all_paths))==225 and not set(paths[1])&set(paths[2])
cal_bytes=open(calibration_path,"rb").read(); manifest_bytes=open(manifest_path,"rb").read()
assert hashlib.sha256(cal_bytes).hexdigest()=="f54316873b2e66cb39277e063accf1168736eb9d3f74ee6c61183a845244e99b"
assert hashlib.sha256(manifest_bytes).hexdigest()=="1168cda99d40277253a0eb4a1c2e7ce3debdb3f92d77f3ca88c304690539e424"
cal=json.loads(cal_bytes); manifest=json.loads(manifest_bytes)
assert cal["ordinary_universe"]["count"]==225
assert cal["ordinary_universe"]["paths"]==all_paths
assert hashlib.sha256(("\0".join(all_paths)+"\0").encode()).hexdigest()==cal["ordinary_universe"]["nul_manifest_sha256"]=="78a70051f7aa55f91de5849327b86dca7915028b15d263230efb5c217b1907f7"
source=cal["ordinary_universe"]["source_files"]
canonical=(json.dumps(source,sort_keys=True,separators=(",",":"))+"\n").encode()
assert hashlib.sha256(canonical).hexdigest()==manifest["ordinary_source_index_sha256"]=="f4ffd881ff99ce65bc1bfef576188de24ed99064f0e7132306d0831fe8dc4485"
assert [row["path"] for row in source]==all_paths
for row in source:
 data=open(os.path.join(root,row["path"]),"rb").read()
 assert len(data)==row["byte_count"] and hashlib.sha256(data).hexdigest()==row["sha256"]
PY

printf 'library-partitions-portability.test: PASS (bash %s)\n' "${BASH_VERSION}"
