#!/usr/bin/env bash
# 253-134 R11 PR operator runner. Jon runs this; no agent runs a live mode, commits the PR allocation or opens a PR.
#
# Usage (from any directory):
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PR-OPERATOR.sh --self-check
#       offline only: no GitHub request, no commit; writes the receipt inside .git
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PR-OPERATOR.sh
#       step 1: commit the PR allocation alone, pre-clock asserts, CLOCK STARTS, normal family, verify, commit records
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PR-OPERATOR.sh remaining
#       step 2: window budget gate, docs-only family, verify docs-only and the pair, commit records
#
# Window 253-134-pr-window-1 (production, 120 requests / 3600 s), bound to PR-FREEZE-R11 (sha256 8c82430dfcec56b89c09b791b30f4915dde82e1e49a5f33c976188feade607e3)
# and to FREEZE-R11 (sha256 e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90), docs_and_prs section sha256 f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2.
# Mutations: create-only docs refs gsd/253-replan-docs-base and gsd/253-replan-docs-head, and exactly two draft PRs
# (gsd/253-replan-r11-candidate -> main, gsd/253-replan-docs-head -> gsd/253-replan-docs-base). No merge, no auto-merge,
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
F=$P/253-LOAD-RECOVERY-CANARY-FREEZE-R11.json
A=$P/253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R11.json
FR=$P/253-LOAD-RECOVERY-PR-FREEZE-R11.json
AL=$P/253-LOAD-RECOVERY-PR-ALLOCATION-R11.json
E=$P/253-LOAD-RECOVERY-PR-NORMAL-EVIDENCE-R11.json
D=$P/253-LOAD-RECOVERY-PR-DOCS-EVIDENCE-R11.json
L=$P/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R11.json
R=$P/253-LOAD-RECOVERY-PR-DOCS-PUBLICATION-RECEIPT-R11.json
COMMON=(--freeze "$FR" --allocation "$AL" --requests "$L" --revision-freeze "$F" --action-approval "$A")

WINDOW_ID=253-134-pr-window-1
WINDOW_SECONDS=3600
F_SHA=e6eb4cd07dccf75804202dedafe323adcddceaf45ef71a3c8c4faf0caa129c90
FR_SHA=8c82430dfcec56b89c09b791b30f4915dde82e1e49a5f33c976188feade607e3
SECTION_SHA=f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2
FROZEN_SOURCE=8d648821fac5414774b173f579a847a27a122b73
NORMAL_HEAD=gsd/253-replan-r11-candidate
CFG_SHA=8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d
APPROVAL_SUBJECT="docs(253-134): record Jon's R11 docs_and_prs action approval"
FREEZE_SUBJECT="docs(253-134): R11 PR freeze (offline --prepare)"
TRAILER="Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

# Worst-case reservation for step 2 (confirmed in scripts/ci/ci-pr-proof.sh: TERMINAL_POLLS["docs-only"] = 12 and
# the PR freeze poll.interval_seconds = 60): 12 x 60 s of terminal polls, plus 300 s for docs publication, PR creation,
# discovery, jobs, checks, artifacts and the pair verification.
DOCS_TERMINAL_POLLS=12
POLL_INTERVAL_S=60
OTHER_REQUESTS_S=300
RESERVED_S=$(( DOCS_TERMINAL_POLLS * POLL_INTERVAL_S + OTHER_REQUESTS_S ))

# Embedded production allocation (base64 of the exact bytes) and its sha256.
ALLOC_SHA256=811a5d43d8d08f45ec3ec047eaddebcbaabde66972672ed7593384f4ff6ef5c7
ALLOC_B64='ewogICJhbGxvY2F0aW9uX2tpbmQiOiAicHJvZHVjdGlvbiIsCiAgImJvdW5kX2RvY3VtZW50cyI6IFsKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktQlVER0VUUy5tZCIsCiAgICAgICJzaGEyNTYiOiAiODc5NjRmNDIzNDk3NWM2NDk2NzAyM2Y1YWQzNzc4MGM1YmIyOWM4NzFjNzA0YTVkMjY0NGZiM2M4ZmUyZmEwYyIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5naXRodWIvd29ya2Zsb3dzL2NpLnltbCIsCiAgICAgICJzaGEyNTYiOiAiOTc3Mzk1MmI3OGQwMjVjMjczYjA1NmVjZjRjNjU2NDVlNGNhMzQ0ODAzNjQ2Y2YwZDgwMWU1YjdkODlmMmRjNSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogInNjcmlwdHMvY2kvY2ktYnJvd3Nlci1yZWNvcmRzLm1qcyIsCiAgICAgICJzaGEyNTYiOiAiMWFhZGNlM2MxYzM0YmU3MTkzYmMxOTFmZDZlNzMzYzRkN2UzMjlkMTM1Mzg5ZGMyMTQzYjkyM2U3MjBlODkwZSIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLVBSLUFDVElPTi1BUFBST1ZBTC1SMTEuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiYjk4MWY3ODM3MmYxOWRmYWRlNjFmMjU4ODU2NjZkNDRlZTY0NDVhM2EzNzFkNmMwYzkyNTU1OTRmMWI1NTU0ZiIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLUFDQ0VQVEFOQ0UtRVZJREVOQ0UuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiZjk1MzkzZTM5YzJmYzdkMDM5NTU2ZDYyNzQyOWRlNGE2MWFmMzdhN2FhZTY5YjlmNDBhZmJkMGVmNDk4OGZjNyIKICAgIH0sCiAgICB7CiAgICAgICJwYXRoIjogIi5wbGFubmluZy9waGFzZXMvMjUzLWZpeC1mbGFreS1jaS1hbmQtcHJlc2VydmUtcmVxdWlyZWQtY2hlY2tzLzI1My1MT0FELVJFQ09WRVJZLU5BVElWRS1FVklERU5DRS1SNS5qc29uIiwKICAgICAgInNoYTI1NiI6ICIxNGRmNjU3NzhjNmUxYWI5MjRkMGVkNTQzMDkzNzM4M2FmOTVjNDk5YzFmMDA0NjgwMjg5MTBlZGE5ZDlmOWExIgogICAgfSwKICAgIHsKICAgICAgInBhdGgiOiAiLnBsYW5uaW5nL3BoYXNlcy8yNTMtZml4LWZsYWt5LWNpLWFuZC1wcmVzZXJ2ZS1yZXF1aXJlZC1jaGVja3MvMjUzLUxPQUQtUkVDT1ZFUlktVEFSR0VULURJU1BPU0lUSU9OLmpzb24iLAogICAgICAic2hhMjU2IjogIjZhZmNjMWE3N2I2MDRiZWU3NDM4MTk1ZjNiYzcwZTY3MzM2NzUzYWZlMzQ1ZWExNTdjNmM5YzI3NWQ4N2ExNDAiCiAgICB9LAogICAgewogICAgICAicGF0aCI6ICIucGxhbm5pbmcvcGhhc2VzLzI1My1maXgtZmxha3ktY2ktYW5kLXByZXNlcnZlLXJlcXVpcmVkLWNoZWNrcy8yNTMtTE9BRC1SRUNPVkVSWS1UQVJHRVQtRElTUE9TSVRJT04tQVBQUk9WQUwuanNvbiIsCiAgICAgICJzaGEyNTYiOiAiZDdkNTY2NjQxZGEyZDVlMWM3ZDVlOTUxYWRiNmU3ZDUzYzg4ZjJhMzJmZjhkYTRmMzI0YjY0ZGYxMWMyN2IwZSIKICAgIH0KICBdLAogICJjYXRlZ29yeV9saW1pdHMiOiB7CiAgICAiYXJ0aWZhY3RfZG93bmxvYWRzIjogMjAsCiAgICAiYXJ0aWZhY3RfbWV0YWRhdGEiOiA0LAogICAgImF0dGVtcHRfam9icyI6IDQsCiAgICAiZG9jc19wdWJsaWNhdGlvbiI6IDE0LAogICAgImZhaWx1cmVfbG9ncyI6IDIsCiAgICAiaW5mcmFzdHJ1Y3R1cmVfcmVydW4iOiAyMSwKICAgICJuYXRpdmVfY2hlY2tzIjogNCwKICAgICJwcl9jcmVhdGUiOiAyLAogICAgInByX2lkZW50aXR5IjogOCwKICAgICJwcmVfd2F0Y2hfcmF0ZSI6IDIsCiAgICAicHJlZmxpZ2h0IjogOCwKICAgICJydW5fZGlzY292ZXJ5IjogNCwKICAgICJ0ZXJtaW5hbF9wb2xscyI6IDI3CiAgfSwKICAiZG93bmxvYWRfaG9zdHMiOiBbCiAgICAicGlwZWxpbmVzLmFjdGlvbnMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExLmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTIuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhMy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E0LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTUuYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhNi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E3LmJsb2IuY29yZS53aW5kb3dzLm5ldCIsCiAgICAicHJvZHVjdGlvbnJlc3VsdHNzYTguYmxvYi5jb3JlLndpbmRvd3MubmV0IiwKICAgICJwcm9kdWN0aW9ucmVzdWx0c3NhOS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExMC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExMS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExMi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExMy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExNC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExNS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExNi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExNy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExOC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2ExOS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyMC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyMS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyMi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyMy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyNC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyNS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyNi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyNy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyOC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EyOS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzMC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzMS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzMi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzMy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzNC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzNS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzNi5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzNy5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzOC5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2EzOS5ibG9iLmNvcmUud2luZG93cy5uZXQiLAogICAgInByb2R1Y3Rpb25yZXN1bHRzc2E0MC5ibG9iLmNvcmUud2luZG93cy5uZXQiCiAgXSwKICAibWF4X2VsYXBzZWRfc2Vjb25kcyI6IDM2MDAsCiAgIm1heF9ob3BzIjogMiwKICAibWF4X3BhZ2VzIjogMTAsCiAgIm1heF9yZXF1ZXN0cyI6IDEyMCwKICAibWF4X3Jlc3BvbnNlX2J5dGVzIjogNDE5NDMwNCwKICAibW9kZSI6ICJsaXZlIiwKICAicmVwb3NpdG9yeSI6ICJzelRoZW9yeS9zaWdyYSIsCiAgInNjaGVtYV92ZXJzaW9uIjogInNpZ3JhLnBoYXNlMjUzLmh0dHAtYWxsb2NhdGlvbi92MSIsCiAgInNvdXJjZV9zaGEyNTYiOiAiOGM4MjQzMGRmY2VjNTZiODljMDliNzkxYjMwZjQ5MTVkZGU4MmUxZTQ5YTVmMzNjOTc2MTg4ZmVhZGU2MDdlMyIsCiAgIndpbmRvd19pZCI6ICIyNTMtMTM0LXByLXdpbmRvdy0xIgp9Cg=='

LIVE_STARTED=0
RECORDS_COMMITTED=0
STEP="$MODE"
SCRATCH=""

# ---------------------------------------------------------------- helpers
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
nopyc() { rm -rf scripts/ci/__pycache__; }
rm_locks() { rm -f "$L.lock" "$E.lock" "$D.lock" "$R.lock"; }
die() { echo "STOP: $*"; nopyc; exit 1; }
clean_tree() { test -z "$(git status --porcelain --untracked-files=all | grep -v '^ M .planning/config.json$')"; }
env_clean() { test -z "$(env | grep -E "$ENV_GREP")"; }
utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
decode_alloc() { printf '%s' "$ALLOC_B64" | base64 -D > "$1" 2>/dev/null || printf '%s' "$ALLOC_B64" | base64 -d > "$1"; }

# Commit the real R11 PR records that exist (explicit paths only), once per process.
commit_records() {
  local subject="$1" f files=()
  [ "$RECORDS_COMMITTED" = 1 ] && return 0
  rm_locks; nopyc
  for f in "$E" "$D" "$L" "$R"; do
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
    commit_records "docs(253-134): halted R11 PR records ($STEP interrupted or exit $rc)"
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
    || { nopyc; die "--check-approval refused PR-APPROVAL-R11 for FREEZE-R11 docs_and_prs"; }
  nopyc
}

assert_freeze() {
  [ "$(sha "$F")" = "$F_SHA" ] || die "FREEZE-R11 bytes changed"
  [ "$(sha "$FR")" = "$FR_SHA" ] || die "PR-FREEZE-R11 bytes changed"
  jq -e --arg h "$NORMAL_HEAD" '.normal.head_ref == $h and .normal.base_ref == "main"
      and .["docs-only"].head_ref == "gsd/253-replan-docs-head" and .["docs-only"].base_ref == "gsd/253-replan-docs-base"' \
    "$FR" >/dev/null || die "PR freeze head/base pairs differ from the approved pairs"
  jq -e --arg h "refs/heads/$NORMAL_HEAD" '.identity.candidate_ref == $h' "$F" >/dev/null \
    || die "FREEZE-R11 identity.candidate_ref is not the normal head"
  grep -q '253-LOAD-RECOVERY-TARGET-DISPOSITION.json' "$FR" || die "PR freeze does not bind the target disposition"
}

assert_embedded_allocation() {
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/253-134-selfcheck.XXXXXX")" || die "mktemp failed"
  decode_alloc "$SCRATCH/allocation.json" || die "embedded allocation does not decode"
  [ "$(sha "$SCRATCH/allocation.json")" = "$ALLOC_SHA256" ] || die "embedded allocation sha256 differs"
  jq -e --arg w "$WINDOW_ID" --arg s "$FR_SHA" '.window_id == $w and .source_sha256 == $s and .mode == "live"
      and .allocation_kind == "production" and .max_requests == 120 and .max_elapsed_seconds == 3600' \
    "$SCRATCH/allocation.json" >/dev/null || die "embedded allocation is not bound to PR-FREEZE-R11 / $WINDOW_ID"
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
  python3 scripts/ci/ci-hosted-gate-verify.py --mode canary --scenario matrix --evidence $P/253-LOAD-RECOVERY-CANARY-EVIDENCE-R11.json >/dev/null \
    || { nopyc; die "the R11 canary matrix does not verify"; }
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
  echo "Live commands (run only by Jon, step 1 then remaining):"
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
  print_live_commands
  after="$(git status --porcelain --untracked-files=all)"
  [ "$before" = "$after" ] || die "--self-check changed the working tree"
  line="SELF-CHECK OK head=$(git rev-parse HEAD) runner_sha256=$(sha "$SELF")"
  printf '%s\n' "$line" > "$(git rev-parse --git-dir)/sigra-253-R11-pr-self-check.txt" || die "cannot write the self-check receipt"
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

  echo "== commit the PR allocation alone"
  if [ -e "$AL" ]; then
    [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "$AL exists with other bytes"
  else
    decode_alloc "$AL" || die "cannot write allocation"
  fi
  [ "$(sha "$AL")" = "$ALLOC_SHA256" ] || die "written allocation sha256 differs"
  if ! git log --diff-filter=A --format=%H -- "$AL" | grep -q .; then
    git add -- "$AL" || die "git add allocation failed"
    git commit -q -m "docs(253-134): declare the R11 PR production allocation" \
      -m "Window $WINDOW_ID, live production, 120 requests / 3600 s, bound to PR-FREEZE-R11 ${FR_SHA:0:8} (allocation sha256 $ALLOC_SHA256); download_hosts without results-receiver. Committed after Jon's approval and before any GitHub request." \
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
  caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family normal "${COMMON[@]}" --evidence "$E"; rc=$?
  nopyc; rm_locks
  if [ $rc -ne 0 ]; then commit_records "docs(253-134): halted R11 PR records (normal family exit $rc)"; die "normal family exit $rc"; fi
  STEP=verify-normal
  python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family normal --evidence "$E"; rc=$?
  nopyc
  if [ $rc -ne 0 ]; then commit_records "docs(253-134): halted R11 PR records (verify-normal exit $rc)"; die "verify-normal exit $rc"; fi

  STEP=commit-step1
  commit_records "docs(253-134): R11 normal PR family evidence" || die "evidence commit"
  [ "$RECORDS_COMMITTED" = 1 ] || die "no step-1 records were committed"
  clean_tree || die "tree not clean after the step-1 commit"
  started="$(window_start)"
  [[ "$started" =~ ^[0-9]+$ ]] || die "normal evidence has no window start"
  echo "WINDOW DEADLINE $(utc $(( started + WINDOW_SECONDS ))) (window started $(utc "$started"); both families must finish before the deadline)"
  echo "DONE step 1 $(date -u +%Y-%m-%dT%H:%M:%SZ). Now run promptly: bash $P/253-R11-PR-OPERATOR.sh remaining"
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
caffeinate -i -s bash scripts/ci/ci-pr-proof.sh --family docs-only "${COMMON[@]}" --evidence "$D"; rc=$?
nopyc; rm_locks
if [ $rc -ne 0 ]; then commit_records "docs(253-134): halted R11 PR records (docs-only family exit $rc)"; die "docs-only family exit $rc"; fi
STEP=verify-docs-only
python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family docs-only --evidence "$D"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-134): halted R11 PR records (verify-docs-only exit $rc)"; die "verify-docs-only exit $rc"; fi
STEP=verify-pair
python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --family both --evidence "$E" --docs-evidence "$D"; rc=$?
nopyc
if [ $rc -ne 0 ]; then commit_records "docs(253-134): halted R11 PR records (verify-pair exit $rc)"; die "verify-pair exit $rc"; fi

STEP=commit-step2
commit_records "docs(253-134): R11 docs-only PR family and pair" || die "evidence commit"
[ "$RECORDS_COMMITTED" = 1 ] || die "no step-2 records were committed"
clean_tree || die "tree not clean after the step-2 commit"
echo "DONE step 2 $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
