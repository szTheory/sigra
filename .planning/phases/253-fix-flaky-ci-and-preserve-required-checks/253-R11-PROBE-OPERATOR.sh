#!/usr/bin/env bash
# 253-127 R11 read-only shape-probe operator runner. Jon runs this; no agent runs the live mode.
#
# Usage (from any directory):
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PROBE-OPERATOR.sh --self-check
#       offline only: no GitHub request, no commit; writes the receipt inside .git
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PROBE-OPERATOR.sh
#       the window, one step: commit the allocation alone, pre-clock asserts, CLOCK STARTS,
#       ci-shape-probe.py --run (at most 8 GETs / 600 s), commit the records
#
# Window 253-127-probe-window-1, bound to the request list 253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json
# (sha256 375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301) and to APPROVAL-R11-PROBE.
# GET only: no POST/PUT/PATCH/DELETE, no dispatch, cancel or rerun, no gsd/253-replan ref (r8, r9, r10 included),
# no push, no PR, no merge, nothing on main. No retry and no second window after a STOP.
set -uo pipefail

MODE="${1:-window}"
case "$MODE" in
  --self-check|window) ;;
  *) echo "STOP: unknown mode '$MODE' (use --self-check or no argument)"; exit 2 ;;
esac

# ---------------------------------------------------------------- repository root and environment
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || { echo "STOP: cannot resolve runner directory"; exit 1; }
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)" || { echo "STOP: runner is not inside a git checkout"; exit 1; }
cd "$ROOT" || { echo "STOP: cannot cd to $ROOT"; exit 1; }
BRANCH=phase-244-playwright-measurement
[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" = "$BRANCH" ] || { echo "STOP: HEAD is not on branch $BRANCH"; exit 1; }

export PATH="$HOME/.asdf/installs/nodejs/20.18.1/bin:$PATH"

# The transport obtains the token itself inside the metered window; nothing token-, test- or shim-shaped may leak in.
unset GH_TOKEN GITHUB_TOKEN PYTHONPATH SIGRA_LIVE_POLICY_SHIM
for v in $(env | grep -oE '^SIGRA_CANARY_TEST_[A-Za-z0-9_]*'); do unset "$v"; done
ENV_GREP='^(SIGRA_CANARY_TEST_|SIGRA_LIVE_POLICY_SHIM|PYTHONPATH=)'

P=.planning/phases/253-fix-flaky-ci-and-preserve-required-checks
RQ=$P/253-LOAD-RECOVERY-PROBE-REQUESTS-R11-PROBE.json
A=$P/253-LOAD-RECOVERY-PROBE-ACTION-APPROVAL-R11-PROBE.json
AL=$P/253-LOAD-RECOVERY-PROBE-ALLOCATION-R11-PROBE.json
L=$P/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json
E=$P/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json
B=$P/253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json
PROBE=(--requests "$RQ" --allocation "$AL" --approval "$A" --ledger "$L" --evidence "$E" --bodies "$B")

WINDOW_ID=253-127-probe-window-1
WINDOW_SECONDS=600
MAX_REQUESTS=8
RQ_SHA256=375c5758b1029942883e45a1bdc215dc2d9f87d0bf00d3554d6f85f76b754301
RQ_COMMIT=2f960a01f32e3165c0183f5bd2ca333b1cc6bbe4
CFG_SHA=8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d
APPROVAL_SUBJECT="docs(253-127): record Jon's R11 shape-probe approval"
TRAILER="Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

# Worst-case reservation: 8 requests times the transport's 30-second per-request deadline
# (scripts/ci/ci-hosted-transport.py: "deadline = time.monotonic() + 30"; asserted below).
PER_REQUEST_S=30
RESERVED_S=$(( MAX_REQUESTS * PER_REQUEST_S ))

# Embedded allocation (base64 of the exact bytes) and its sha256.
ALLOC_SHA256=79869fd022112cf8fe7ef4e5a0d994d0c3e31360564842b8f6bdcd0eea24bc99
ALLOC_B64='ewogICJhbGxvY2F0aW9uX2tpbmQiOiAiY2FuYXJ5IiwKICAiYm91bmRfZG9jdW1lbnRzIjogWwogICAgewogICAgICAicGF0aCI6ICIucGxhbm5pbmcvcGhhc2VzLzI1My1maXgtZmxha3ktY2ktYW5kLXByZXNlcnZlLXJlcXVpcmVkLWNoZWNrcy8yNTMtTE9BRC1SRUNPVkVSWS1QUk9CRS1SRVFVRVNUUy1SMTEtUFJPQkUuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiMzc1YzU3NThiMTAyOTk0Mjg4M2U0NWExYmRjMjE1ZGMyZDlmODdkMGJmMDBkMzU1NGQ2Zjg1Zjc2Yjc1NDMwMSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLVBST0JFLUFDVElPTi1BUFBST1ZBTC1SMTEtUFJPQkUuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiNjVmMGUyNjk3YTU5ODEyODc1NjVmOGFjOWM3YmM0M2UyYWM1N2FhMmI3MDQ5NGJmY2ZhNWZkZTdhZjNhMGVjOCIKICAgIH0KICBdLAogICJjYXRlZ29yeV9saW1pdHMiOiB7CiAgICAiY2FuY2VsbGVkX3NoYXBlIjogMywKICAgICJmYWlsdXJlX2xvZ3MiOiAzLAogICAgImpvYl9sb2dfc2hhcGUiOiAxLAogICAgInByZWZsaWdodCI6IDEKICB9LAogICJkb3dubG9hZF9ob3N0cyI6IFsKICAgICJwaXBlbGluZXMuYWN0aW9ucy5naXRodWJ1c2VyY29udGVudC5jb20iLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EwLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E2LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhOC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E5LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTEwLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTExLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTEyLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTEzLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE0LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE1LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE2LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE3LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE4LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTE5LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTIwLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTIxLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTIyLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTIzLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI0LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI1LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI2LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI3LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI4LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTI5LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMwLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMxLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMyLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMzLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM0LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM1LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM2LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM3LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM4LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTM5LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTQwLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicmVzdWx0cy1yZWNlaXZlci5hY3Rpb25zLmdpdGh1YnVzZXJjb250ZW50LmNvbSIKICBdLAogICJtYXhfZWxhcHNlZF9zZWNvbmRzIjogNjAwLAogICJtYXhfaG9wcyI6IDIsCiAgIm1heF9wYWdlcyI6IDIsCiAgIm1heF9yZXF1ZXN0cyI6IDgsCiAgIm1heF9yZXNwb25zZV9ieXRlcyI6IDQxOTQzMDQsCiAgIm1vZGUiOiAibGl2ZSIsCiAgInJlcG9zaXRvcnkiOiAic3pUaGVvcnkvc2lncmEiLAogICJzY2hlbWFfdmVyc2lvbiI6ICJzaWdyYS5waGFzZTI1My5odHRwLWFsbG9jYXRpb24vdjEiLAogICJzb3VyY2Vfc2hhMjU2IjogIjM3NWM1NzU4YjEwMjk5NDI4ODNlNDVhMWJkYzIxNWRjMmQ5Zjg3ZDBiZjAwZDM1NTRkNmY4NWY3NmI3NTQzMDEiLAogICJ3aW5kb3dfaWQiOiAiMjUzLTEyNy1wcm9iZS13aW5kb3ctMSIKfQo='

LIVE_STARTED=0
RECORDS_COMMITTED=0
SCRATCH=""

# ---------------------------------------------------------------- helpers
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
nopyc() { rm -rf scripts/ci/__pycache__; }
rm_locks() { rm -f "$L.lock"; }
die() { echo "STOP: $*"; nopyc; exit 1; }
clean_tree() { test -z "$(git status --porcelain --untracked-files=all | grep -v '^ M .planning/config.json$')"; }
env_clean() { test -z "$(env | grep -E "$ENV_GREP")"; }
utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
decode_alloc() { printf '%s' "$ALLOC_B64" | base64 -D > "$1" 2>/dev/null || printf '%s' "$ALLOC_B64" | base64 -d > "$1"; }

# Commit the real R11 probe records that exist (explicit paths only), once per process.
commit_records() {
  local subject="$1" f files=()
  [ "$RECORDS_COMMITTED" = 1 ] && return 0
  rm_locks; nopyc
  for f in "$L" "$E" "$B"; do
    [ -e "$f" ] && files+=("$f")
  done
  [ ${#files[@]} -gt 0 ] || return 0
  git add -- "${files[@]}" || { echo "STOP: git add of records failed"; return 1; }
  if git diff --cached --quiet -- "${files[@]}"; then return 0; fi
  git commit -q -m "$subject" -m "$TRAILER" -- "${files[@]}" || { echo "STOP: records commit failed"; return 1; }
  RECORDS_COMMITTED=1
  git log --oneline -1
}

on_exit() {
  local rc=$?
  trap - EXIT
  rm_locks; nopyc
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
  if [ "$LIVE_STARTED" = 1 ] && [ "$RECORDS_COMMITTED" != 1 ]; then
    commit_records "docs(253-127): halted R11 shape-probe records (interrupted or exit $rc)"
    if [ "$RECORDS_COMMITTED" = 1 ]; then
      echo "STOP: the probe ended with exit $rc; the real partial records were committed once with a halted subject. Do not retry."
    else
      echo "STOP: the probe ended with exit $rc; no record file existed to commit (or the commit failed: check git status). Do not retry."
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

assert_env() {
  env_clean || die "token/test/shim environment present"
  ( export SIGRA_LIVE_POLICY_SHIM=probe; env | grep -qE "$ENV_GREP" ) || die "env grep positive control failed"
  command -v caffeinate >/dev/null || die "caffeinate not found (needed to keep the Mac awake)"
  grep -q 'deadline = time.monotonic() + 30' scripts/ci/ci-hosted-transport.py \
    || die "transport per-request deadline is not 30 s; the reservation is stale"
  [ "$RESERVED_S" -le "$WINDOW_SECONDS" ] || die "reservation ${RESERVED_S}s exceeds the ${WINDOW_SECONDS}s window; no request made"
}

assert_request_list() {
  [ "$(sha "$RQ")" = "$RQ_SHA256" ] || die "the request list bytes changed"
  git diff --quiet HEAD -- "$RQ" || die "the request list differs from its committed bytes"
  [ "$(git log --diff-filter=A --format=%H -- "$RQ")" = "$RQ_COMMIT" ] || die "the request list was not added by $RQ_COMMIT"
  git diff --quiet "$RQ_COMMIT" HEAD -- scripts/ci/ci-hosted-transport.py scripts/ci/ci-shape-probe.py \
    || die "the transport or driver changed since the request-list commit"
  git diff --quiet HEAD -- scripts/ci/ci-hosted-transport.py scripts/ci/ci-shape-probe.py \
    || die "the transport or driver differs from HEAD in the working tree"
  jq -e --arg w "$WINDOW_ID" '.window_id == $w and .max_requests == 8 and .max_elapsed_seconds == 600' "$RQ" >/dev/null \
    || die "the request list is not window $WINDOW_ID at 8 requests / 600 s"
}

assert_approval_commit() {
  local commits nm
  commits="$(git log --diff-filter=A --format=%H -- "$A")"
  [ -n "$commits" ] || die "APPROVAL-R11-PROBE is not committed"
  [ "$(printf '%s\n' "$commits" | grep -c .)" = 1 ] || die "APPROVAL-R11-PROBE was added by more than one commit"
  nm="$(git show --name-only --format= "$commits")"
  [ "$(printf '%s\n' "$nm" | grep -c .)" = 1 ] && [ "$nm" = "$A" ] || die "the approval commit carries other paths"
  [ "$(git show -s --format=%s "$commits")" = "$APPROVAL_SUBJECT" ] || die "the approval commit subject differs"
  git diff --quiet HEAD -- "$A" || die "the approval differs from its committed bytes"
  jq -e --arg s "$RQ_SHA256" '.schema_version == "sigra.phase253.shape-probe-approval/v1" and .section == "shape_probe" and .section_sha256 == $s and .decision == "approve"' \
    "$A" >/dev/null || die "APPROVAL-R11-PROBE is not an approve decision bound to the request list sha256"
}

assert_embedded_allocation() {
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/253-127-selfcheck.XXXXXX")" || die "mktemp failed"
  decode_alloc "$SCRATCH/allocation.json" || die "embedded allocation does not decode"
  [ "$(sha "$SCRATCH/allocation.json")" = "$ALLOC_SHA256" ] || die "embedded allocation sha256 differs"
  jq -e --arg w "$WINDOW_ID" --arg s "$RQ_SHA256" '.window_id == $w and .source_sha256 == $s and .mode == "live" and .allocation_kind == "canary" and .max_requests == 8 and .max_elapsed_seconds == 600 and (.download_hosts | length) == 43' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation is not bound to the request list / $WINDOW_ID"
  python3 scripts/ci/ci-shape-probe.py --check-only --requests "$RQ" --allocation "$SCRATCH/allocation.json" --approval "$A" \
    || { nopyc; die "embedded allocation failed ci-shape-probe.py --check-only"; }
  rm -rf scripts/ci/__pycache__
  rm -rf "$SCRATCH"; SCRATCH=""
}

assert_offline_contracts() {
  [ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"
}

assert_no_window_records() {
  local f
  for f in "$L" "$L.lock" "$E" "$B"; do test ! -e "$f" || die "$f already exists (request before the clock?)"; done
}

print_live_command() {
  echo "Live command (run only by Jon, through this runner, after the allocation commit):"
  echo "  caffeinate -i -s python3 scripts/ci/ci-shape-probe.py --run ${PROBE[*]}"
}

# ---------------------------------------------------------------- --self-check (offline only)
if [ "$MODE" = --self-check ]; then
  before="$(git status --porcelain --untracked-files=all)"
  assert_env
  assert_request_list
  assert_approval_commit
  assert_embedded_allocation
  assert_offline_contracts
  test ! -e "$AL" || die "$AL already exists"
  assert_no_window_records
  print_live_command
  after="$(git status --porcelain --untracked-files=all)"
  [ "$before" = "$after" ] || die "--self-check changed the working tree"
  line="SELF-CHECK OK head=$(git rev-parse HEAD) runner_sha256=$(sha "$SELF")"
  printf '%s\n' "$line" > "$(git rev-parse --git-dir)/sigra-253-R11-probe-self-check.txt" || die "cannot write the self-check receipt"
  echo "$line"
  exit 0
fi

# ---------------------------------------------------------------- the window (default, one step)
assert_env
assert_request_list
assert_approval_commit
assert_embedded_allocation
assert_offline_contracts
assert_no_window_records

echo "== commit the allocation alone"
if [ -e "$AL" ]; then
  [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "$AL exists with other bytes"
else
  decode_alloc "$AL" || die "cannot write the allocation"
fi
[ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "written allocation sha256 differs"
if ! git log --diff-filter=A --format=%H -- "$AL" | grep -q .; then
  git add -- "$AL" || die "git add allocation failed"
  git commit -q -m "docs(253-127): declare the R11 shape-probe HTTP allocation" \
    -m "Window $WINDOW_ID, live, 8 GET requests / 600 s, bound to the request list ${RQ_SHA256:0:8} and APPROVAL-R11-PROBE (allocation sha256 $ALLOC_SHA256). Committed by Jon's runner after his approval and before any GitHub request." \
    -m "$TRAILER" -- "$AL" || die "allocation commit failed"
fi
ALC="$(git log --diff-filter=A --format=%H -- "$AL")"
[ "$(printf '%s\n' "$ALC" | grep -c .)" = 1 ] || die "the allocation was added by more than one commit"
[ "$(git show --name-only --format= "$ALC" | grep -c .)" = 1 ] || die "the allocation commit carries other paths"
git diff --quiet HEAD -- "$AL" || die "allocation differs from its commit"
git log --oneline -1
clean_tree || die "tree not clean after the allocation commit"

echo "== pre-clock asserts (offline)"
assert_env
assert_request_list
assert_offline_contracts
python3 scripts/ci/ci-shape-probe.py --check-only "${PROBE[@]:0:6}" || { nopyc; die "--check-only refused the committed allocation"; }
rm -rf scripts/ci/__pycache__
assert_no_window_records
clean_tree || die "tree not clean before the clock"

start="$(date +%s)"
echo "CLOCK STARTS $(utc "$start") (window $WINDOW_ID)"
echo "WINDOW DEADLINE $(utc $(( start + WINDOW_SECONDS ))) (now + ${WINDOW_SECONDS} s)"
echo "WINDOW LEFT $WINDOW_SECONDS RESERVED $RESERVED_S ($MAX_REQUESTS requests x ${PER_REQUEST_S} s per-request deadline)"
if [ "$RESERVED_S" -gt "$WINDOW_SECONDS" ]; then
  echo "STOP (insufficient window): reserved ${RESERVED_S}s > ${WINDOW_SECONDS}s; no request made"
  exit 1
fi

LIVE_STARTED=1
caffeinate -i -s python3 scripts/ci/ci-shape-probe.py --run "${PROBE[@]}"; rc=$?
nopyc; rm_locks
if [ $rc -ne 0 ]; then
  commit_records "docs(253-127): halted R11 shape-probe records (probe exit $rc)"
  die "probe exit $rc; the real partial records were committed once with a halted subject. Do not retry."
fi
commit_records "docs(253-127): R11 shape-probe records" || die "records commit failed"
[ "$RECORDS_COMMITTED" = 1 ] || die "no probe records were committed"
clean_tree || die "tree not clean after the records commit"
echo "DONE probe $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
