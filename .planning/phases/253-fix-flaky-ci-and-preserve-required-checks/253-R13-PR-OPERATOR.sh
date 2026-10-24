#!/usr/bin/env bash
# 253-171 R13 PR runner. Jon explicitly authorized Codex to run this exact scope in conversation (reply: yes).
#
# Usage (from any directory):
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-PR-OPERATOR.sh --self-check
#       offline only: no GitHub request, no commit; writes the receipt inside .git
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-PR-OPERATOR.sh
#       step 1: commit the PR allocation alone, pre-clock asserts, CLOCK STARTS, normal family, verify, commit records
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R13-PR-OPERATOR.sh remaining
#       step 2: window budget gate, docs-only family, verify docs-only and the pair, commit records
#
# Window 253-171-pr-window-1: production, 120 requests / 3600 s; exact hashes below.
# Bound to FREEZE-R13 docs_and_prs; exact digest below.
# Mutations: create-only docs refs gsd/253-replan-docs-base and gsd/253-replan-docs-head, and exactly two draft PRs
# (gsd/253-replan-r13-candidate -> main, gsd/253-replan-docs-head -> gsd/253-replan-docs-base). No merge, no auto-merge,
# no ready-for-review, no push, no force, no ref deletion, no rule change, no tag, no release, no rerun.
# The allocation's download_hosts are ALLOCATION-R10's 42 hosts; results-receiver is deliberately absent (the PR
# families never call run_logs, 253-130).
set -uo pipefail

MODE="${1:-step1}"
case "$MODE" in
  --self-check|step1|remaining) ;;
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
ENV_GREP='^(SIGRA_CANARY_TEST_|SIGRA_LIVE_POLICY_SHIM|PYTHONPATH=|GH_TOKEN=|GITHUB_TOKEN=)'

P=.planning/phases/253-fix-flaky-ci-and-preserve-required-checks
F=$P/253-LOAD-RECOVERY-CANARY-FREEZE-R13.json
A=$P/253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R13.json
FR=$P/253-LOAD-RECOVERY-PR-FREEZE-R13.json
AL=$P/253-LOAD-RECOVERY-PR-ALLOCATION-R13.json
E=$P/253-LOAD-RECOVERY-PR-NORMAL-EVIDENCE-R13.json
D=$P/253-LOAD-RECOVERY-PR-DOCS-EVIDENCE-R13.json
L=$P/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R13.json
R=$P/253-LOAD-RECOVERY-PR-DOCS-PUBLICATION-RECEIPT-R13.json
PF=$P/253-LOAD-RECOVERY-PR-MAIN-PREFLIGHT-R13.json
COMMON=(--freeze "$FR" --allocation "$AL" --requests "$L" --revision-freeze "$F" --action-approval "$A")

WINDOW_ID=253-171-pr-window-1
WINDOW_SECONDS=3600
F_SHA=2a9b2415e4c9545252817ec3b299a66b76247ef4774b087be97faa4e0a578629
FR_SHA=193d65a712de432b0dd453989b2e8caa05828f1fa199c0e419719708ce364ea2
SECTION_SHA=7a059033966da717d7c4b8e635610bf1cca532558bc6a02abbd196880b1c16a9
FROZEN_SOURCE=c17ae6a0b1dbcd4f53362407c1f1d1e1128da519
NORMAL_HEAD=gsd/253-replan-r13-candidate
CFG_SHA=225737694e79b502993ffa4a64a8e437d758711432aca20da8caa18ef3e52f7c
APPROVAL_SUBJECT="docs(253-171): record Jon's R13 docs_and_prs action approval"
FREEZE_SUBJECT="docs(253-171): R13 PR freeze (offline --prepare)"
TRAILER="Executed by Codex under Jon's explicit approval."

# Worst-case reservation for step 2 (confirmed in scripts/ci/ci-pr-proof.sh: TERMINAL_POLLS["docs-only"] = 12 and
# the PR freeze poll.interval_seconds = 60): 12 x 60 s of terminal polls, plus 300 s for docs publication, PR creation,
# discovery, jobs, checks, artifacts and the pair verification.
DOCS_TERMINAL_POLLS=12
POLL_INTERVAL_S=60
OTHER_REQUESTS_S=300
RESERVED_S=$(( DOCS_TERMINAL_POLLS * POLL_INTERVAL_S + OTHER_REQUESTS_S ))

# Embedded production allocation (base64 of the exact bytes) and its sha256.
ALLOC_SHA256=c6d96c7bdea185e26cfd898fbed106e26c95ae1693e611e4fb2618d471dfde5e
ALLOC_B64='ewogICJhbGxvY2F0aW9uX2tpbmQiOiAicHJvZHVjdGlvbiIsCiAgImJvdW5kX2RvY3VtZW50cyI6IFsKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktQlVER0VUUy5tZCIsCiAgICAgICJzaGEyNTYiOiAiODc5NjRmNDIzNDk3NWM2NDk2NzAyM2Y1YWQzNzc4MGM1YmIyOWM4NzFjNzA0YTVkMjY0NGZiM2M4ZmUyZmEwYyIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5naXRodWIvd29ya2Zsb3dzL2NpLnltbCIsCiAgICAgICJzaGEyNTYiOiAiOTc3Mzk1MmI3OGQwMjVjMjczYjA1NmVjZjRjNjU2NDVlNGNhMzQ0ODAzNjQ2Y2YwZDgwMWU1YjdkODlmMmRjNSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogInNjcmlwdHMvY2kvY2ktYnJvd3Nlci1yZWNvcmRzLm1qcyIsCiAgICAgICJzaGEyNTYiOiAiMWFhZGNlM2MxYzM0YmU3MTkzYmMxOTFmZDZlNzMzYzRkN2UzMjlkMTM1Mzg5ZGMyMTQzYjkyM2U3MjBlODkwZSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLVBSLUFDVElPTi1BUFBST1ZBTC1SMTMuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiNGMyZmU1YWE2NGFhMDdmNjg5ZmVmNjAyYTRiNjU2MTIxZTdkNmVjNTRlOWM3MTIwYWZmNjIwNjVlNTc1ODAxMyIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLUFDQ0VQVEFOQ0UtRVZJREVOQ0UuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiZjk1MzkzZTM5YzJmYzdkMDM5NTU2ZDYyNzQyOWRlNGE2MWFmMzdhN2FhZTY5YjlmNDBhZmJkMGVmNDk4OGZjNyIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLU5BVElWRS1FVklERU5DRS1SNS5qc29uIiwKICAgICAgInNoYTI1NiI6ICIxNGRmNjU3NzhjNmUxYWI5MjRkMGVkNTQzMDkzNzM4M2FmOTVjNDk5YzFmMDA0NjgwMjg5MTBlZGE5ZDlmOWExIgogICAgfSwKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktVEFSR0VULURJU1BPU0lUSU9OLmpzb24iLAogICAgICAic2hhMjU2IjogIjZhZmNjMWE3N2I2MDRiZWU3NDM4MTk1ZjNiYzcwZTY3MzM2NzUzYWZlMzQ1ZWExNTdjNmM5YzI3NWQ4N2ExNDAiCiAgICB9LAogICAgewogICAgICAicGF0aCI6ICIucGxhbm5pbmcvcGhhc2VzLzI1My1maXgtZmxha3ktY2ktYW5kLXByZXNlcnZlLXJlcXVpcmVkLWNoZWNrcy8yNTMtTE9BRC1SRUNPVkVSWS1UQVJHRVQtRElTUE9TSVRJT04tQVBQUk9WQUwuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiZDdkNTY2NjQxZGEyZDVlMWM3ZDVlOTUxYWRiNmU3ZDUzYzg4ZjJhMzJmZjhkYTRmMzI0YjY0ZGYxMWMyN2IwZSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLU1BSU4tRkVUQ0gtUjEyLmpzb24iLAogICAgICAic2hhMjU2IjogIjM1ZmQxNTQzYTg3ZDdhYmZlNTA5NDliMWQxYjYxNmMzYWZkMThmODY4ZTczODJkZTg3MTAyODY4MTUxNWI5MGUiCiAgICB9CiAgXSwKICAiY2F0ZWdvcnlfbGltaXRzIjogewogICAgImFydGlmYWN0X2Rvd25sb2FkcyI6IDIwLAogICAgImFydGlmYWN0X21ldGFkYXRhIjogNCwKICAgICJhdHRlbXB0X2pvYnMiOiA0LAogICAgImRvY3NfcHVibGljYXRpb24iOiAxNCwKICAgICJmYWlsdXJlX2xvZ3MiOiAyLAogICAgImluZnJhc3RydWN0dXJlX3JlcnVuIjogMjEsCiAgICAibmF0aXZlX2NoZWNrcyI6IDQsCiAgICAicHJfY3JlYXRlIjogMiwKICAgICJwcl9pZGVudGl0eSI6IDgsCiAgICAicHJlX3dhdGNoX3JhdGUiOiAyLAogICAgInByZWZsaWdodCI6IDgsCiAgICAicnVuX2Rpc2NvdmVyeSI6IDQsCiAgICAidGVybWluYWxfcG9sbHMiOiAyNwogIH0sCiAgImRvd25sb2FkX2hvc3RzIjogWwogICAgInBpcGVsaW5lcy5hY3Rpb25zLmdpdGh1YnVzZXJjb250ZW50LmNvbSIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E1LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E4LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMTkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMjkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzAuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzEuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzMuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzQuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzYuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzcuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMzkuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNDAuYmxvYi5jb3JlLndpbmRvd3MubmV0IgogIF0sCiAgIm1heF9lbGFwc2VkX3NlY29uZHMiOiAzNjAwLAogICJtYXhfaG9wcyI6IDIsCiAgIm1heF9wYWdlcyI6IDEwLAogICJtYXhfcmVxdWVzdHMiOiAxMjAsCiAgIm1heF9yZXNwb25zZV9ieXRlcyI6IDQxOTQzMDQsCiAgIm1vZGUiOiAibGl2ZSIsCiAgInJlcG9zaXRvcnkiOiAic3pUaGVvcnkvc2lncmEiLAogICJzY2hlbWFfdmVyc2lvbiI6ICJzaWdyYS5waGFzZTI1My5odHRwLWFsbG9jYXRpb24vdjEiLAogICJzb3VyY2Vfc2hhMjU2IjogIjE5M2Q2NWE3MTJkZTQzMmIwZGQ0NTM5ODliMmU4Y2FhMDU4MjhmMWZhMTk5YzBlNDE5NzE5NzA4Y2UzNjRlYTIiLAogICJ3aW5kb3dfaWQiOiAiMjUzLTE3MS1wci13aW5kb3ctMSIKfQo='

LIVE_STARTED=0
FETCH_STARTED=0
RECORDS_COMMITTED=0
STEP="$MODE"
SCRATCH=""

# ---------------------------------------------------------------- helpers
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
nopyc() { rm -rf scripts/ci/__pycache__; }
rm_locks() { rm -f "$L.lock" "$E.lock" "$D.lock" "$R.lock"; }
die() { echo "STOP: $*"; nopyc; exit 1; }
clean_tree() { test -z "$(git status --porcelain --untracked-files=all)"; }
env_clean() { test -z "$(env | grep -E "$ENV_GREP")"; }
utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
decode_alloc() { printf '%s' "$ALLOC_B64" | base64 -D > "$1" 2>/dev/null || printf '%s' "$ALLOC_B64" | base64 -d > "$1"; }

# Commit the real R13 PR records that exist (explicit paths only), once per process.
commit_records() {
  local subject="$1" f files=()
  [ "$RECORDS_COMMITTED" = 1 ] && return 0
  rm_locks; nopyc
  for f in "$PF" "$E" "$D" "$L" "$R"; do
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
    commit_records "docs(253-171): halted R13 PR records ($STEP interrupted or exit $rc)"
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
  grep -qF 'TERMINAL_POLLS = {"normal": 15, "docs-only": 12}' scripts/ci/ci-pr-proof.sh \
    || die "ci-pr-proof.sh TERMINAL_POLLS changed; the step-2 reservation is stale"
  jq -e --argjson i "$POLL_INTERVAL_S" '.poll.interval_seconds == $i' "$FR" >/dev/null \
    || die "PR freeze poll interval is not ${POLL_INTERVAL_S} s; the step-2 reservation is stale"
}

# One commit adds the file, that commit carries only that path, and its subject is the stated one.
assert_single_commit() {
  local path="$1" subject="$2" commits nm
  commits="$(git log --diff-filter=A --format=%H -- "$path")"
  [ -n "$commits" ] || die "$path is not committed"
  [ "$(printf '%s\n' "$commits" | grep -c .)" = 1 ] || die "$path was added by more than one commit"
  nm="$(git show --name-only --format= "$commits")"
  [ "$(printf '%s\n' "$nm" | grep -c .)" = 1 ] && [ "$nm" = "$path" ] || die "the commit adding $path carries other paths"
  [ "$(git show -s --format=%s "$commits")" = "$subject" ] || die "the commit adding $path has another subject"
  git diff --quiet HEAD -- "$path" || die "$path differs from its committed bytes"
}

assert_approval() {
  assert_single_commit "$A" "$APPROVAL_SUBJECT"
  assert_single_commit "$FR" "$FREEZE_SUBJECT"
  git merge-base --is-ancestor "$(git log --diff-filter=A --format=%H -- "$A")" "$(git log --diff-filter=A --format=%H -- "$FR")" \
    || die "the PR freeze was committed before the approval"
  python3 scripts/ci/ci-git-publication.py --check-approval --action-approval "$A" --freeze "$F" --section docs_and_prs \
    | jq -e --arg s "$SECTION_SHA" '.section_sha256 == $s' >/dev/null \
    || { nopyc; die "--check-approval refused PR-APPROVAL-R13 for FREEZE-R13 docs_and_prs"; }
  nopyc
}

assert_freeze() {
  [ "$(sha "$F")" = "$F_SHA" ] || die "FREEZE-R13 bytes changed"
  [ "$(sha "$FR")" = "$FR_SHA" ] || die "PR-FREEZE-R13 bytes changed"
  jq -e --arg h "$NORMAL_HEAD" '.normal.head_ref == $h and .normal.base_ref == "main"
      and .["docs-only"].head_ref == "gsd/253-replan-docs-head" and .["docs-only"].base_ref == "gsd/253-replan-docs-base"' \
    "$FR" >/dev/null || die "PR freeze head/base pairs differ from the approved pairs"
  jq -e --arg h "refs/heads/$NORMAL_HEAD" '.identity.candidate_ref == $h' "$F" >/dev/null \
    || die "FREEZE-R13 identity.candidate_ref is not the normal head"
  grep -q '253-LOAD-RECOVERY-TARGET-DISPOSITION.json' "$FR" || die "PR freeze does not bind the target disposition"
}

assert_embedded_allocation() {
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/253-171-selfcheck.XXXXXX")" || die "mktemp failed"
  decode_alloc "$SCRATCH/allocation.json" || die "embedded allocation does not decode"
  [ "$(sha "$SCRATCH/allocation.json")" = "$ALLOC_SHA256" ] || die "embedded allocation sha256 differs"
  jq -e --arg w "$WINDOW_ID" --arg s "$FR_SHA" '.window_id == $w and .source_sha256 == $s and .mode == "live"
      and .allocation_kind == "production" and .max_requests == 120 and .max_elapsed_seconds == 3600' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation is not bound to PR-FREEZE-R13 / $WINDOW_ID"
  jq -e '(.download_hosts | length) == 42 and ([.download_hosts[] | select(. == "results-receiver.actions.githubusercontent.com")] | length) == 0' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation download_hosts are not the 42 hosts without results-receiver"
  jq -e --slurpfile fr "$FR" '.bound_documents == $fr[0].bound_documents and ([.category_limits[]] | add) == 120' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation bound_documents or category sum differ"
  bash scripts/ci/ci-pr-proof.sh --check-only --freeze "$FR" --allocation "$SCRATCH/allocation.json" \
    | jq -e '.allocation_valid == true and .network_requests == 0' >/dev/null \
    || { nopyc; die "embedded allocation failed ci-pr-proof.sh --check-only"; }
  nopyc
  rm -rf "$SCRATCH"; SCRATCH=""
}

assert_offline_contracts() {
  python3 scripts/ci/ci-git-publication.py --validate-frozen-source "$FROZEN_SOURCE" \
    | jq -e --arg c "$FROZEN_SOURCE" '.frozen_source == $c and .planning_only_movement == true' >/dev/null \
    || { nopyc; die "frozen product source does not match"; }
  nopyc
  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario matrix --evidence $P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R13.json >/dev/null \
    || { nopyc; die "the R13 canary matrix does not verify"; }
  nopyc
  "$N" scripts/ci/ci-registration-recovery.mjs --verify-load-acceptance $P/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json --require-target-disposition >/dev/null \
    || die "disposition predicate"
  [ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"
}

assert_no_window_records() {
  local f
  for f in "$E" "$D" "$L" "$R" "$L.lock"; do test ! -e "$f" || die "$f already exists (request before clock?)"; done
}

print_live_commands() {
  echo "Live commands (Codex explicitly authorized by Jon, step 1 then remaining):"
  echo "  caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family normal ${COMMON[*]} --evidence $E"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family normal --evidence $E"
  echo "  caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family docs-only ${COMMON[*]} --evidence $D"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family docs-only --evidence $D"
  echo "  python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family both --evidence $E --docs-evidence $D"
}

window_start() {
  jq -r '(.budget.started_epoch // .action_approval.window_wall_start_epoch // empty) | tostring' "$E" 2>/dev/null
}

# ---------------------------------------------------------------- --self-check (offline only)
if [ "$MODE" = --self-check ]; then
  before="$(git status --porcelain --untracked-files=all)"
  assert_env
  assert_approval
  assert_freeze
  assert_embedded_allocation
  assert_offline_contracts
  test ! -e "$AL" || die "$AL already exists"
  assert_no_window_records
  test ! -e "$PF" || die "preflight already exists"
  print_live_commands
  after="$(git status --porcelain --untracked-files=all)"
  [ "$before" = "$after" ] || die "--self-check changed the working tree"
  line="SELF-CHECK OK head=$(git rev-parse HEAD) runner_sha256=$(sha "$SELF")"
  printf '%s\n' "$line" > "$(git rev-parse --git-dir)/sigra-253-R13-pr-self-check.txt" || die "cannot write the self-check receipt"
  echo "$line"
  exit 0
fi

# ---------------------------------------------------------------- step 1 (default): normal family
if [ "$MODE" = step1 ]; then
  assert_env
  assert_approval
  assert_freeze
  assert_embedded_allocation
  assert_offline_contracts
  assert_no_window_records
  clean_tree || die "tree not clean before the allocation commit"

  test ! -e "$PF" || die "preflight already exists; do not fetch again"
  test ! -e "$AL" || die "allocation already exists"
  echo "STEP 0 FETCH $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  FETCH_STARTED=1
  FETCH_CMD=(git fetch --no-tags origin main)
  "${FETCH_CMD[@]}" || die "step-0 fetch failed; do not retry"
  CUR="$(git rev-parse refs/remotes/origin/main)"
  [ "$CUR" = "$(git rev-parse 'FETCH_HEAD^{commit}')" ] || die "fetched main identity mismatch"
  bash scripts/ci/ci-pr-proof.sh --main-preflight --freeze "$FR" --current-main "$CUR" --output "$PF"; pre_rc=$?
  nopyc
  test -f "$PF" || die "preflight returned no record"
  git add -- "$PF" && git commit -q -m "docs(253-171): R13 PR step-0 main preflight (runner, Jon)" -m "$TRAILER" -- "$PF" || die "preflight commit failed"
  git log --oneline -1
  [ "$pre_rc" = 0 ] || die "main conflicted or rewritten; no API request made, no allocation committed"

  echo "== commit the PR allocation alone"
  if [ -e "$AL" ]; then
    [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "$AL exists with other bytes"
  else
    decode_alloc "$AL" || die "cannot write allocation"
  fi
  [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "written allocation sha256 differs"
  if ! git log --diff-filter=A --format=%H -- "$AL" | grep -q .; then
    git add -- "$AL" || die "git add allocation failed"
    git commit -q -m "docs(253-171): declare the R13 PR production allocation" \
      -m "Window $WINDOW_ID, live production, 120 requests / 3600 s, bound to PR-FREEZE-R13 ${FR_SHA:0:8} (allocation sha256 $ALLOC_SHA256); download_hosts without results-receiver. Committed after Jon's approval and before any GitHub request." \
      -m "$TRAILER" -- "$AL" || die "allocation commit failed"
  fi
  ALC="$(git log --diff-filter=A --format=%H -- "$AL")"
  [ "$(git show --name-only --format= "$ALC" | grep -c .)" = 1 ] || die "the allocation commit carries other paths"
  git diff --quiet HEAD -- "$AL" || die "allocation differs from its commit"
  git log --oneline -1
  clean_tree || die "tree not clean after the allocation commit"

  echo "== pre-clock asserts (offline)"
  assert_env
  assert_approval
  assert_freeze
  bash scripts/ci/ci-pr-proof.sh --check-only --freeze "$FR" --allocation "$AL" >/dev/null || { nopyc; die "check-only on the committed allocation"; }
  nopyc
  assert_no_window_records
  clean_tree || die "tree not clean before the clock"

  echo "CLOCK STARTS $(date -u +%Y-%m-%dT%H:%M:%SZ) (normal family)"
  STEP=normal-family; LIVE_STARTED=1
  caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family normal "${COMMON[@]}" --main-preflight "$PF" --evidence "$E"; rc=$?
  nopyc; rm_locks
  if [ $rc -ne 0 ]; then commit_records "docs(253-171): halted R13 PR records (normal family exit $rc)"; die "normal family exit $rc"; fi
  STEP=verify-normal
  python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family normal --evidence "$E"; rc=$?
  nopyc
  if [ $rc -ne 0 ]; then commit_records "docs(253-171): halted R13 PR records (verify-normal exit $rc)"; die "verify-normal exit $rc"; fi

  STEP=commit-step1
  commit_records "docs(253-171): R13 normal PR family evidence" || die "evidence commit"
  [ "$RECORDS_COMMITTED" = 1 ] || die "no step-1 records were committed"
  clean_tree || die "tree not clean after the step-1 commit"
  started="$(window_start)"
  [[ "$started" =~ ^[0-9]+$ ]] || die "normal evidence has no window start"
  echo "WINDOW DEADLINE $(utc $(( started + WINDOW_SECONDS ))) (window started $(utc "$started"); both families must finish before the deadline)"
  echo "DONE step 1 $(date -u +%Y-%m-%dT%H:%M:%SZ). Now run promptly: bash $P/253-R13-PR-OPERATOR.sh remaining"
  exit 0
fi

# ---------------------------------------------------------------- step 2 (remaining): docs-only family and pair
assert_env
for f in "$AL" "$E" "$L"; do
  git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || die "$f is not committed; run step 1 first"
  git diff --quiet HEAD -- "$f" || die "$f differs from its committed bytes"
done
test ! -e "$D" || die "$D already exists; nothing more may run"
clean_tree || die "tree not clean before remaining"
[ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "committed allocation bytes differ from the embedded allocation"
python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family normal --evidence "$E" >/dev/null || { nopyc; die "step-1 normal evidence does not verify"; }
nopyc
assert_approval
assert_freeze
[ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"

started="$(window_start)"
[[ "$started" =~ ^[0-9]+$ ]] || die "normal evidence has no window start"
now="$(date +%s)"
left=$(( started + WINDOW_SECONDS - now ))
echo "WINDOW LEFT $left RESERVED $RESERVED_S (deadline $(utc $(( started + WINDOW_SECONDS ))))"
if [ "$left" -lt "$RESERVED_S" ]; then
  echo "STOP (insufficient window for the docs-only family): left ${left}s < reserved ${RESERVED_S}s; no request made, no commit"
  exit 1
fi

echo "== docs-only family $(date -u +%Y-%m-%dT%H:%M:%SZ)"
STEP=docs-only-family; LIVE_STARTED=1
caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family docs-only "${COMMON[@]}" --docs-publication-receipt "$R" --evidence "$D"; rc=$?
nopyc; rm_locks
if [ $rc -ne 0 ]; then commit_records "docs(253-171): halted R13 PR records (docs-only family exit $rc)"; die "docs-only family exit $rc"; fi
STEP=verify-docs-only
python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family docs-only --evidence "$D"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-171): halted R13 PR records (verify-docs-only exit $rc)"; die "verify-docs-only exit $rc"; fi
STEP=verify-pair
python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family both --evidence "$E" --docs-evidence "$D"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-171): halted R13 PR records (verify-pair exit $rc)"; die "verify-pair exit $rc"; fi

STEP=commit-step2
commit_records "docs(253-171): R13 docs-only PR family and pair" || die "evidence commit"
[ "$RECORDS_COMMITTED" = 1 ] || die "no step-2 records were committed"
clean_tree || die "tree not clean after the step-2 commit"
echo "DONE step 2 $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
