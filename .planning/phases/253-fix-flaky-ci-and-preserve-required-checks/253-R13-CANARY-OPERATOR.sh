#!/usr/bin/env bash
# 253-170 R13 hosted canary runner. Jon explicitly authorized Codex execution in conversation.
#
# Usage (from any directory):
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-CANARY-OPERATOR.sh --self-check
#       offline only: no GitHub request, no commit; writes the receipt inside .git
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-CANARY-OPERATOR.sh
#       step 1: commit the allocation alone, pre-clock asserts, CLOCK STARTS, publish-only, full-pass, commit records
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-CANARY-OPERATOR.sh remaining
#       step 2: window budget gate, remaining five scenarios + separate verifier, commit records
#
# Window 253-170-canary-window-1, bound to FREEZE-R13 (sha256 fd1a27cb2c3e40e1f598b51576083ddb2fc89527e5a3933cfa81cd56cf2bf309),
# canary section sha256 e506857812ea12e17e0ccd06e640a3ffd2582b6b90e3d3df6dba395a0456bd29. The docs_and_prs section is not
# run here. No push, no PR, no merge, no ref deletion, no rerun. Refs: create-only gsd/253-replan-r13-candidate and
# gsd/253-replan-r13-fixture; the r8, r9, r10 and r11 refs are never read for reuse, moved or deleted. The allocation adds
# results-receiver.actions.githubusercontent.com, which the transport admits only on run_logs hop 1 (never with the token).
set -uo pipefail

MODE="${1:-step1}"
case "$MODE" in
  --self-check|--guard-probe|step1|remaining) ;;
  *) echo "STOP: unknown mode '$MODE' (use --self-check, no argument, or remaining)"; exit 2 ;;
esac

# ---------------------------------------------------------------- repository root and environment
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || { echo "STOP: cannot resolve runner directory"; exit 1; }
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)" || { echo "STOP: runner is not inside a git checkout"; exit 1; }
cd "$ROOT" || { echo "STOP: cannot cd to $ROOT"; exit 1; }
BRANCH=phase-244-playwright-measurement
[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" = "$BRANCH" ] || { echo "STOP: HEAD is not on branch $BRANCH"; exit 1; }

export PATH="$HOME/.asdf/installs/nodejs/20.18.1/bin:$PATH"
N="$HOME/.asdf/installs/nodejs/20.18.1/bin/node"

unset GH_TOKEN GITHUB_TOKEN PYTHONPATH SIGRA_LIVE_POLICY_SHIM
for v in $(env | grep -oE '^SIGRA_CANARY_TEST_[A-Za-z0-9_]*'); do unset "$v"; done
ENV_GREP='^(SIGRA_CANARY_TEST_|SIGRA_LIVE_POLICY_SHIM|PYTHONPATH=)'

P=.planning/phases/253-fix-flaky-ci-and-preserve-required-checks
F=$P/253-LOAD-RECOVERY-CANARY-FREEZE-R13.json
A=$P/253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R13.json
AL=$P/253-LOAD-RECOVERY-CANARY-ALLOCATION-R13.json
E=$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13.json
L=$P/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R13.json
R=$P/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R13.json
PREFLIGHT=(
  "$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13-PREFLIGHT-rate.json"
  "$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13-PREFLIGHT-effective-rules.json"
  "$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13-PREFLIGHT-registered-workflow.json"
  "$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13-PREFLIGHT-legacy-protection.json"
  "$P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13-PREFLIGHT-check-runs.json"
)
LIVE=(--revision-freeze "$F" --action-approval "$A" --http-allocation "$AL" --requests "$L" --evidence "$E" --publication-receipt "$R")

WINDOW_ID=253-170-canary-window-1
WINDOW_SECONDS=3600
FREEZE_SHA=2a9b2415e4c9545252817ec3b299a66b76247ef4774b087be97faa4e0a578629
FROZEN_SOURCE=c17ae6a0b1dbcd4f53362407c1f1d1e1128da519
CFG_SHA=225737694e79b502993ffa4a64a8e437d758711432aca20da8caa18ef3e52f7c
APPROVAL_SUBJECT="docs(253-170): record Jon's R13 canary action approval"
TRAILER="Co-Authored-By: Codex <noreply@openai.com>"

# Worst-case reservation for step 2 (confirmed in scripts/ci/ci-gate-canary.sh: DISCOVERY_WAIT=20 after every dispatch,
# and the "reserved four-minute window" per watched run): six watched runs (five scenarios + the verifier) times
# (20 + 240) s, plus 300 s for jobs, artifact, log, cancel and verifier-dispatch requests.
DISCOVERY_WAIT_S=20
WATCH_RESERVE_S=240
WATCHED_RUNS=6
OTHER_REQUESTS_S=300
RESERVED_S=$(( WATCHED_RUNS * (DISCOVERY_WAIT_S + WATCH_RESERVE_S) + OTHER_REQUESTS_S ))

# Embedded allocation (base64 of the exact bytes) and its sha256.
ALLOC_SHA256=7f78c451eef4f8d1c42abf9e01d18258fa7faf4345fa7f91806be80cc9848de8
ALLOC_B64='ewogICJhbGxvY2F0aW9uX2tpbmQiOiAiY2FuYXJ5IiwKICAiYm91bmRfZG9jdW1lbnRzIjogWwogICAgewogICAgICAicGF0aCI6ICIucGxhbm5pbmcvcGhhc2VzLzI1My1maXgtZmxha3ktY2ktYW5kLXByZXNlcnZlLXJlcXVpcmVkLWNoZWNrcy8yNTMtTE9BRC1SRUNPVkVSWS1DQU5BUlktRlJFRVpFLVIxMy5qc29uIiwKICAgICAgInNoYTI1NiI6ICIyYTliMjQxNWU0Yzk1NDUyNTI4MTdlYzNiMjk5YTY2Yjc2MjQ3ZWY0Nzc0YjA4N2JlOTdmYWE0ZTBhNTc4NjI5IgogICAgfSwKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktQ0FOQVJZLVBVQkxJQ0FUSU9OLVIxMy5qc29uIiwKICAgICAgInNoYTI1NiI6ICIxMzlkOTMzYWI5MzUxYjE4MjdhOGM2OWZiZDQ5YmQ0NGZkMTdkNDFlNWU0OGYyMmEyMDljZjYzYTMxNjQwZjgzIgogICAgfSwKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktQ0FOQVJZLVdPUktGTE9XLnltbCIsCiAgICAgICJzaGEyNTYiOiAiM2MzMWNiNzJjMzE2OGM0ZTg2YTFlYTUyOWYxNmJmZGQ0MGI0NDA1NTUxNDU5Y2EyN2I5Yjk4OWNiNzYyZGY3YiIKICAgIH0KICBdLAogICJjYXRlZ29yeV9saW1pdHMiOiB7CiAgICAiYXJ0aWZhY3RfZG93bmxvYWRzIjogMTIsCiAgICAiYXJ0aWZhY3RfbWV0YWRhdGEiOiA3LAogICAgImF0dGVtcHRfam9icyI6IDcsCiAgICAiY2FuY2VsbGF0aW9uIjogMSwKICAgICJkaXNwYXRjaCI6IDcsCiAgICAiZmFpbHVyZV9sb2dzIjogNiwKICAgICJpbmZyYXN0cnVjdHVyZV9yZXRyeSI6IDUsCiAgICAicHJlX3dhdGNoX3JhdGUiOiA3LAogICAgInByZWZsaWdodCI6IDE2LAogICAgInB1YmxpY2F0aW9uIjogMjQsCiAgICAicnVuX2Rpc2NvdmVyeSI6IDcsCiAgICAidGVybWluYWxfcG9sbHMiOiAxOAogIH0sCiAgImRvd25sb2FkX2hvc3RzIjogWwogICAgInBpcGVsaW5lcy5hY3Rpb25zLmdpdGh1YnVzZXJjb250ZW50LmNvbSIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E1LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E4LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNDAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJyZXN1bHRzLXJlY2VpdmVyLmFjdGlvbnMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIgogIF0sCiAgIm1heF9lbGFwc2VkX3NlY29uZHMiOiAzNjAwLAogICJtYXhfaG9wcyI6IDIsCiAgIm1heF9wYWdlcyI6IDEyLAogICJtYXhfcmVxdWVzdHMiOiAxMTcsCiAgIm1heF9yZXNwb25zZV9ieXRlcyI6IDQxOTQzMDQsCiAgIm1vZGUiOiAibGl2ZSIsCiAgInJlcG9zaXRvcnkiOiAic3pUaGVvcnkvc2lncmEiLAogICJzY2hlbWFfdmVyc2lvbiI6ICJzaWdyYS5waGFzZTI1My5odHRwLWFsbG9jYXRpb24vdjEiLAogICJzb3VyY2Vfc2hhMjU2IjogIjJhOWIyNDE1ZTRjOTU0NTI1MjgxN2VjM2IyOTlhNjZiNzYyNDdlZjQ3NzRiMDg3YmU5N2ZhYTRlMGE1Nzg2MjkiLAogICJ3aW5kb3dfaWQiOiAiMjUzLTE3MC1jYW5hcnktd2luZG93LTEiCn0K'

LIVE_STARTED=0
RECORDS_COMMITTED=0
STEP="$MODE"
SCRATCH=""

# ---------------------------------------------------------------- helpers
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
nopyc() { rm -rf scripts/ci/__pycache__; }
rm_locks() { rm -f "$L.lock" "$E.lock" "$R.lock"; }
die() { echo "STOP: $*"; nopyc; exit 1; }
clean_tree() { test -z "$(git status --porcelain --untracked-files=all)"; }
env_clean() { test -z "$(env | grep -E "$ENV_GREP")"; }
utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

# Commit the real R13 records that exist (explicit paths only), once per process.
commit_records() {
  local subject="$1" f files=()
  [ "$RECORDS_COMMITTED" = 1 ] && return 0
  rm_locks; nopyc
  for f in "$E" "$L" "$R" "${PREFLIGHT[@]}"; do
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
    commit_records "docs(253-170): halted R13 canary records ($STEP interrupted or exit $rc)"
    if [ "$RECORDS_COMMITTED" = 1 ]; then
      echo "STOP: $STEP ended with exit $rc; the real partial records were committed once with a halted subject. Do not retry."
    else
      echo "STOP: $STEP ended with exit $rc; no record file existed to commit (or the commit failed: check git status). Do not retry."
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
  grep -qx 'DISCOVERY_WAIT=20' scripts/ci/ci-gate-canary.sh || die "driver DISCOVERY_WAIT is not 20 s; reservation is stale"
  grep -q 'reserved four-minute window' scripts/ci/ci-gate-canary.sh || die "driver watch reservation text changed; reservation is stale"
}

assert_approval_commit() {
  local commits nm
  commits="$(git log --diff-filter=A --format=%H -- "$A")"
  [ -n "$commits" ] || die "APPROVAL-R13 is not committed"
  [ "$(printf '%s\n' "$commits" | grep -c .)" = 1 ] || die "APPROVAL-R13 was added by more than one commit"
  nm="$(git show --name-only --format= "$commits")"
  [ "$(printf '%s\n' "$nm" | grep -c .)" = 1 ] && [ "$nm" = "$A" ] || die "the approval commit carries other paths"
  [ "$(git show -s --format=%s "$commits")" = "$APPROVAL_SUBJECT" ] || die "the approval commit subject differs"
  python3 scripts/ci/ci-git-publication.py --check-approval --action-approval "$A" --freeze "$F" --section canary >/dev/null \
    || { nopyc; die "--check-approval refused APPROVAL-R13 for FREEZE-R13 canary"; }
  nopyc
}

assert_embedded_allocation() {
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/253-170-selfcheck.XXXXXX")" || die "mktemp failed"
  printf '%s' "$ALLOC_B64" | base64 -D > "$SCRATCH/allocation.json" 2>/dev/null \
    || printf '%s' "$ALLOC_B64" | base64 -d > "$SCRATCH/allocation.json" || die "embedded allocation does not decode"
  [ "$(sha "$SCRATCH/allocation.json")" = "$ALLOC_SHA256" ] || die "embedded allocation sha256 differs"
  jq -e --arg w "$WINDOW_ID" --arg s "$FREEZE_SHA" '.window_id == $w and .source_sha256 == $s and .mode == "live" and .allocation_kind == "canary" and .max_requests == 117 and .max_elapsed_seconds == 3600' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation is not bound to FREEZE-R13 / $WINDOW_ID"
  jq -e '(.download_hosts | length) == 43 and ([.download_hosts[] | select(. == "results-receiver.actions.githubusercontent.com")] | length) == 1 and .download_hosts[-1] == "results-receiver.actions.githubusercontent.com"' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation does not list results-receiver exactly once among 43 hosts"
  jq -e --slurpfile fr "$F" '.category_limits == $fr[0].categories.canary and ([.category_limits[]] | add) == 117' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation category_limits differ from FREEZE-R13 categories.canary"
  jq -n '{method:"GET",route_id:"rate_limit"}' > "$SCRATCH/request.json"
  python3 scripts/ci/ci-hosted-transport.py --check-only --allocation "$SCRATCH/allocation.json" \
    --ledger "$SCRATCH/no-ledger.json" --request "$SCRATCH/request.json" --output /dev/null \
    || { nopyc; die "embedded allocation failed transport --check-only"; }
  nopyc
  test ! -e "$SCRATCH/no-ledger.json" || die "transport --check-only created a ledger"
  rm -rf "$SCRATCH"; SCRATCH=""
}

assert_offline_contracts() {
  [ "$(sha "$F")" = "$FREEZE_SHA" ] || die "FREEZE-R13 bytes changed"
  bash scripts/ci/ci-gate-canary.sh --check-only --revision-freeze "$F" >/dev/null || { nopyc; die "check-only on FREEZE-R13"; }
  nopyc
  python3 scripts/ci/ci-git-publication.py --validate-frozen-source "$FROZEN_SOURCE" \
    | jq -e --arg c "$FROZEN_SOURCE" '.frozen_source == $c' >/dev/null || { nopyc; die "frozen source does not match"; }
  nopyc
  "$N" scripts/ci/ci-registration-recovery.mjs --verify-load-acceptance $P/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json --require-target-disposition >/dev/null \
    || die "disposition predicate"
  [ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"
}

assert_no_window_records() {
  local f
  for f in "$E" "$L" "$R" "$L.lock" "${PREFLIGHT[@]}"; do test ! -e "$f" || die "$f already exists (request before clock?)"; done
}

print_live_commands() {
  echo "Live commands (run only by Jon, step 1 then remaining):"
  echo "  caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --publish-only ${LIVE[*]}"
  echo "  python3 scripts/ci/ci-git-publication.py --verify-publication $R --require-live-origin"
  echo "  caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --scenario full-pass ${LIVE[*]}"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario full-pass --evidence $E"
  echo "  caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --remaining-scenarios ${LIVE[*]}"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario sources --evidence $E"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario matrix --evidence $E"
}

window_start() {
  jq -r '(.budget.started_epoch // .action_approval.window_wall_start_epoch // empty) | tostring' "$E" 2>/dev/null
}


growth_guard() {
  "$N" - "$P" "${1:-0}" <<'NODE'
const fs=require('fs'); const [p,off]=process.argv.slice(2);if(!/^(0|[1-9][0-9]?)$/.test(off)||Number(off)>60)process.exit(2);
const l=JSON.parse(fs.readFileSync(p+'/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R12.json'));const tx=l.transactions.find(x=>x.sequence===21);if(!tx)throw Error('missing sequence 21');
const body=JSON.parse(Buffer.from(tx.response_body_base64,'base64'));const headers=tx.scrubbed_headers;const date=Object.entries(headers).find(([k])=>k.toLowerCase()==='date')[1];
const elapsed=Date.now()+Number(off)*86400000-Date.parse(date);const count=body.total_count+55*Math.max(0,Math.ceil(elapsed/86400000));const pages=Math.ceil(count/100);const f=JSON.parse(fs.readFileSync(p+'/253-LOAD-RECOVERY-CANARY-FREEZE-R13.json'));const budget=Math.min(10,f.categories.canary.preflight-6);
console.log('projected check_runs pages '+pages+' budget '+budget);if(pages>budget){console.log('STOP: projected check_runs pages exceed the preflight budget');process.exit(1);}
NODE
}
if [ "$MODE" = --guard-probe ]; then growth_guard "${2:-invalid}"; exit $?; fi

# ---------------------------------------------------------------- --self-check (offline only)
if [ "$MODE" = --self-check ]; then
  growth_guard 0 || die "growth guard"
  probe="$(growth_guard 20 2>&1)"; probe_rc=$?
  [ "$probe_rc" = 1 ] && [[ "$probe" == *"STOP: projected check_runs pages exceed the preflight budget"* ]] || die "growth guard negative control"
  before="$(git status --porcelain --untracked-files=all)"
  assert_env
  assert_approval_commit
  assert_embedded_allocation
  assert_offline_contracts
  test ! -e "$AL" || die "$AL already exists"
  assert_no_window_records
  print_live_commands
  after="$(git status --porcelain --untracked-files=all)"
  [ "$before" = "$after" ] || die "--self-check changed the working tree"
  line="SELF-CHECK OK head=$(git rev-parse HEAD) runner_sha256=$(sha "$SELF")"
  printf '%s\n' "$line" > "$(git rev-parse --git-dir)/sigra-253-R13-canary-self-check.txt" || die "cannot write the self-check receipt"
  echo "$line"
  exit 0
fi

# ---------------------------------------------------------------- step 1 (default)
if [ "$MODE" = step1 ]; then
  growth_guard 0 || exit $?
  assert_env
  assert_approval_commit
  assert_embedded_allocation
  assert_offline_contracts
  assert_no_window_records

  echo "== commit the allocation alone"
  if [ -e "$AL" ]; then
    [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "$AL exists with other bytes"
  else
    printf '%s' "$ALLOC_B64" | base64 -D > "$AL" 2>/dev/null || printf '%s' "$ALLOC_B64" | base64 -d > "$AL" || die "cannot write allocation"
  fi
  [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "written allocation sha256 differs"
  if ! git log --diff-filter=A --format=%H -- "$AL" | grep -q .; then
    git add -- "$AL" || die "git add allocation failed"
    git commit -q -m "docs(253-170): declare the R13 live canary HTTP allocation" \
      -m "Window $WINDOW_ID, live canary, 117 requests / 3600 s, bound to FREEZE-R13 ${FREEZE_SHA:0:8} (allocation sha256 $ALLOC_SHA256). Committed after Jon's approval and before any GitHub request." \
      -m "$TRAILER" -- "$AL" || die "allocation commit failed"
  fi
  ALC="$(git log --diff-filter=A --format=%H -- "$AL")"
  [ "$(git show --name-only --format= "$ALC" | grep -c .)" = 1 ] || die "the allocation commit carries other paths"
  git diff --quiet HEAD -- "$AL" || die "allocation differs from its commit"
  git log --oneline -1
  clean_tree || die "tree not clean after the allocation commit"

  echo "== pre-clock asserts (offline)"
  assert_env
  assert_offline_contracts
  python3 scripts/ci/ci-git-publication.py --check-approval --action-approval "$A" --freeze "$F" --section canary >/dev/null \
    || { nopyc; die "approval check"; }
  nopyc
  assert_no_window_records
  clean_tree || die "tree not clean before the clock"

  echo "CLOCK STARTS $(date -u +%Y-%m-%dT%H:%M:%SZ) (publish-only)"
  STEP=publish-only; LIVE_STARTED=1
  caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --publish-only "${LIVE[@]}"; rc=$?
  nopyc; rm_locks
  if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (publish-only exit $rc)"; die "publish-only exit $rc"; fi
  STEP=verify-publication
  python3 scripts/ci/ci-git-publication.py --verify-publication "$R" --require-live-origin; rc=$?
  nopyc
  if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (verify-publication exit $rc)"; die "verify-publication exit $rc"; fi

  echo "== full-pass $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  STEP=full-pass
  caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --scenario full-pass "${LIVE[@]}"; rc=$?
  nopyc; rm_locks
  if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (full-pass exit $rc)"; die "full-pass exit $rc"; fi
  STEP=verify-full-pass
  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario full-pass --evidence "$E"; rc=$?
  nopyc
  if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (verify-full-pass exit $rc)"; die "verify-full-pass exit $rc"; fi

  STEP=commit-step1
  commit_records "docs(253-170): R13 full-pass evidence, ledger and publication receipt" || die "evidence commit"
  [ "$RECORDS_COMMITTED" = 1 ] || die "no step-1 records were committed"
  clean_tree || die "tree not clean after the step-1 commit"
  started="$(window_start)"
  [[ "$started" =~ ^[0-9]+$ ]] || die "evidence has no window start"
  echo "WINDOW DEADLINE $(utc $(( started + WINDOW_SECONDS ))) (window started $(utc "$started"); the whole window must finish before the deadline)"
  echo "DONE step 1 $(date -u +%Y-%m-%dT%H:%M:%SZ). Now run promptly: bash $P/253-R13-CANARY-OPERATOR.sh remaining"
  exit 0
fi

# ---------------------------------------------------------------- step 2 (remaining)
assert_env
for f in "$AL" "$E" "$L" "$R"; do
  git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || die "$f is not committed; run step 1 first"
  git diff --quiet HEAD -- "$f" || die "$f differs from its committed bytes"
done
clean_tree || die "tree not clean before remaining"
[ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "committed allocation bytes differ from the embedded allocation"
[ "$(jq -r '.status // ""' "$E")" != halted ] || die "step-1 evidence is halted; nothing more may run"
python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario full-pass --evidence "$E" >/dev/null || { nopyc; die "step-1 evidence does not pass full-pass verification"; }
nopyc
python3 scripts/ci/ci-git-publication.py --check-approval --action-approval "$A" --freeze "$F" --section canary >/dev/null \
  || { nopyc; die "approval check"; }
nopyc
[ "$(sha "$F")" = "$FREEZE_SHA" ] || die "FREEZE-R13 bytes changed"
[ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"

started="$(window_start)"
[[ "$started" =~ ^[0-9]+$ ]] || die "evidence has no window start"
now="$(date +%s)"
left=$(( started + WINDOW_SECONDS - now ))
echo "WINDOW LEFT $left RESERVED $RESERVED_S (deadline $(utc $(( started + WINDOW_SECONDS ))))"
if [ "$left" -lt "$RESERVED_S" ]; then
  echo "STOP (insufficient window for the remaining scenarios): left ${left}s < reserved ${RESERVED_S}s; no request made, no commit"
  exit 1
fi

echo "== remaining scenarios + separate verifier $(date -u +%Y-%m-%dT%H:%M:%SZ)"
STEP=remaining-scenarios; LIVE_STARTED=1
caffeinate -i -s bash scripts/ci/ci-gate-canary.sh --remaining-scenarios "${LIVE[@]}"; rc=$?
nopyc; rm_locks
if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (remaining-scenarios exit $rc)"; die "remaining-scenarios exit $rc"; fi
STEP=verify-sources
python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario sources --evidence "$E"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (verify-sources exit $rc)"; die "verify-sources exit $rc"; fi
STEP=verify-matrix
python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario matrix --evidence "$E"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-170): halted R13 canary records (verify-matrix exit $rc)"; die "verify-matrix exit $rc"; fi

STEP=commit-step2
commit_records "docs(253-170): R13 canary sources, verifier and sealed accounting" || die "evidence commit"
[ "$RECORDS_COMMITTED" = 1 ] || die "no step-2 records were committed"
clean_tree || die "tree not clean after the step-2 commit"
echo "DONE step 2 $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
