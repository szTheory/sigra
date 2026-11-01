#!/usr/bin/env bash
# 253-136 R12 main-fetch operator runner. Jon runs this; no agent runs the default mode.
#
# Usage (from any directory):
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R12-MAIN-FETCH-OPERATOR.sh --self-check
#       offline only: no network, no commit; writes the receipt inside .git
#   bash .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R12-MAIN-FETCH-OPERATOR.sh
#       the one approved hosted read: git fetch --no-tags origin main, exactly once; then the record
#       253-LOAD-RECOVERY-MAIN-FETCH-R12.json is computed offline and committed alone by this runner
#
# Bound to 253-LOAD-RECOVERY-MAIN-FETCH-APPROVAL-R12.json (Jon's approval, committed alone).
# The fetch is the only network command in this file. It updates refs/remotes/origin/main and
# FETCH_HEAD in the local .git only: no GitHub API request, no ref created, moved or deleted on
# GitHub, no PR action, no tag. The working tree, HEAD and .planning/config.json do not change.
# No retry after a STOP.
set -uo pipefail

MODE="${1:-fetch}"
case "$MODE" in
  --self-check|fetch) ;;
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
unset GH_TOKEN GITHUB_TOKEN PYTHONPATH SIGRA_LIVE_POLICY_SHIM
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
# Fail instead of waiting on a credential prompt (the repository is public).
export GIT_TERMINAL_PROMPT=0

P=.planning/phases/253-fix-flaky-ci-and-preserve-required-checks
A=$P/253-LOAD-RECOVERY-MAIN-FETCH-APPROVAL-R12.json
C=$P/253-LOAD-RECOVERY-PRESERVATION-R12.sha256
R=$P/253-LOAD-RECOVERY-MAIN-FETCH-R12.json
REL_SELF=$P/253-R12-MAIN-FETCH-OPERATOR.sh

APPROVAL_SUBJECT="docs(253-136): record Jon's R12 main-fetch approval"
RUNNER_SUBJECT="docs(253-136): R12 main-fetch operator runner (Jon runs the fetch)"
RECORD_SUBJECT="docs(253-136): record the R12 main fetch (runner, Jon)"
TRAILER="Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
CFG_SHA=8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d
TRACKING_REF=refs/remotes/origin/main
EXPECTED_FETCH_REFSPEC='+refs/heads/*:refs/remotes/origin/*'

SHA_84EBCEA60=84ebcea60024c9e8caee405d55cad1c76b0e858a
SHA_4FF6C50E4=4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97
SHA_09DF342A=09df342a82e03c3d5d40173c912b70e827f7eadc
R11_CANDIDATE=2b239a98df72b8d47e8c4e03edf193905b3239da

FETCH_STARTED=0
RECORD_COMMITTED=0
FETCH_ERR=""
BEFORE=""

# ---------------------------------------------------------------- the one network command
# This function body is the only network line in the file; FETCH_CMD below is read back from it.
run_fetch() {
  git fetch --no-tags origin main
}
FETCH_CMD="$(declare -f run_fetch | sed -n '3p' | sed -e 's/^[[:space:]]*//' -e 's/;[[:space:]]*$//')"

# ---------------------------------------------------------------- helpers
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
nopyc() { rm -rf scripts/ci/__pycache__; }
die() { echo "STOP: $*"; nopyc; exit 1; }
clean_tree() { test -z "$(git status --porcelain --untracked-files=all | grep -v '^ M .planning/config.json$')"; }
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

approval_commit() { git log --diff-filter=A --format=%H -- "$A"; }

approval_json() {
  jq -n --arg path "$A" --arg sha "$(sha "$A")" --arg commit "$(approval_commit)" \
    '{path: $path, sha256: $sha, commit: $commit}'
}

# Commit the record (explicit path only), once per process.
commit_record() {
  local subject="$1"
  [ "$RECORD_COMMITTED" = 1 ] && return 0
  [ -e "$R" ] || { echo "STOP: no record file to commit"; return 1; }
  git add -- "$R" || { echo "STOP: git add of the record failed"; return 1; }
  git commit -q -m "$subject" -m "$TRAILER" -- "$R" || { echo "STOP: record commit failed"; return 1; }
  RECORD_COMMITTED=1
  git log --oneline -1
}

write_interrupted_record() {
  local rc="$1"
  jq -n --arg cmd "$FETCH_CMD" --arg url "$(git remote get-url origin 2>/dev/null)" \
    --argjson approval "$(approval_json)" --arg before "$BEFORE" --argjson rc "$rc" \
    --arg at "$(now_utc)" \
    '{schema_version: "sigra.phase253.main-fetch/r12", status: "interrupted", command: $cmd,
      remote_url: $url, approval: $approval, before_origin_main: $before, exit_code: $rc,
      origin_main_now: null, recorded_at_utc: $at}' > "$R"
  local now
  now="$(git rev-parse --verify --quiet "$TRACKING_REF")" || now=""
  if [ -n "$now" ]; then
    jq --arg n "$now" '.origin_main_now = $n' "$R" > "$R.tmp" && mv "$R.tmp" "$R"
  fi
}

on_exit() {
  local rc=$?
  trap - EXIT
  nopyc
  [ -n "$FETCH_ERR" ] && rm -f "$FETCH_ERR"
  if [ "$FETCH_STARTED" = 1 ] && [ "$RECORD_COMMITTED" != 1 ]; then
    [ -e "$R" ] || write_interrupted_record "$rc"
    commit_record "docs(253-136): halted R12 main fetch record (interrupted or exit $rc)"
    if [ "$RECORD_COMMITTED" = 1 ]; then
      echo "STOP: the runner ended with exit $rc after the fetch started; the record was committed once with a halted subject. Do not retry."
    else
      echo "STOP: the runner ended with exit $rc after the fetch started and the record could not be committed (check git status). Do not retry."
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ---------------------------------------------------------------- offline assertions
assert_tools() {
  command -v jq >/dev/null || die "jq not found"
  local mt_help
  mt_help="$(git merge-tree -h 2>&1 || true)"
  printf '%s\n' "$mt_help" | grep -q -- '--write-tree' || die "git merge-tree --write-tree is not available (needs git 2.38+)"
}

assert_fetch_command() {
  local approved
  [ "$FETCH_CMD" = "git $(printf '%s' fetch) --no-tags origin main" ] || die "the runner's network line is not the approved command (read back: '$FETCH_CMD')"
  approved="$(jq -r '.authorizes[0]' "$A" | sed -e 's/ (once.*$//')"
  [ "$FETCH_CMD" = "$approved" ] || die "the runner's network line differs from the approval's authorized command"
}

assert_approval_commit() {
  local commits nm
  commits="$(approval_commit)"
  [ -n "$commits" ] || die "the approval is not committed"
  [ "$(printf '%s\n' "$commits" | grep -c .)" = 1 ] || die "the approval was added by more than one commit"
  nm="$(git show --name-only --format= "$commits")"
  [ "$(printf '%s\n' "$nm" | grep -c .)" = 1 ] && [ "$nm" = "$A" ] || die "the approval commit carries other paths"
  [ "$(git show -s --format=%s "$commits")" = "$APPROVAL_SUBJECT" ] || die "the approval commit subject differs"
  git diff --quiet HEAD -- "$A" || die "the approval differs from its committed bytes"
  jq -e --arg b "$SHA_4FF6C50E4" '.schema_version == "sigra.phase253.read-approval/v1" and .section == "main_fetch" and .decision == "approve" and (.authorizes | length) == 1 and .before_origin_main == $b' \
    "$A" >/dev/null || die "the approval is not an approve main_fetch read approval with one authorized command"
  [ "$(jq -r '.remote_url' "$A")" = "$(git remote get-url origin)" ] || die "the approval's remote_url differs from git remote get-url origin"
}

assert_remote_config() {
  local refspecs
  refspecs="$(git config --get-all remote.origin.fetch)"
  [ "$refspecs" = "$EXPECTED_FETCH_REFSPEC" ] || die "remote.origin.fetch is not exactly $EXPECTED_FETCH_REFSPEC"
  [ "$(git config --bool --get remote.origin.mirror || echo false)" = false ] || die "remote.origin.mirror is set"
  for k in fetch.prune remote.origin.prune fetch.pruneTags remote.origin.pruneTags; do
    [ "$(git config --bool --get "$k" || echo false)" = false ] || die "$k is true (the fetch could delete local refs)"
  done
  test ! -e .gitmodules || die ".gitmodules exists (the fetch could recurse into submodules)"
}

assert_local_state() {
  [ "$(git rev-parse --verify --quiet "$TRACKING_REF")" = "$SHA_4FF6C50E4" ] \
    || die "$TRACKING_REF is not $SHA_4FF6C50E4 (someone already fetched; no fetch made)"
  local s
  for s in "$SHA_84EBCEA60" "$SHA_4FF6C50E4" "$R11_CANDIDATE"; do
    git cat-file -e "$s^{commit}" 2>/dev/null || die "commit $s is missing locally"
  done
  # Offline reproduction of the 253-134 diagnosis, with its positive control.
  git merge-tree --write-tree --name-only --no-messages "$R11_CANDIDATE" "$SHA_4FF6C50E4" >/dev/null 2>&1
  [ $? -eq 1 ] || die "the R11 candidate no longer conflicts with $SHA_4FF6C50E4 offline"
  git merge-tree --write-tree --name-only --no-messages "$R11_CANDIDATE" "$SHA_84EBCEA60" >/dev/null 2>&1 \
    || die "positive control failed: the R11 candidate does not merge cleanly with $SHA_84EBCEA60"
}

assert_offline() {
  assert_tools
  assert_fetch_command
  assert_approval_commit
  assert_remote_config
  shasum -a 256 -c --quiet "$C" || die "the R12 preservation checklist does not check clean"
  test ! -e "$R" || die "$R already exists"
  test ! -e "$R.tmp" || die "$R.tmp already exists"
  [ "$(sha .planning/config.json)" = "$CFG_SHA" ] || die "config.json changed"
  assert_local_state
  if [ "$MODE" = --self-check ] && ! git log --diff-filter=A --format=%H -- "$REL_SELF" | grep -q .; then
    # Before the runner commit, the only extra path allowed is this runner itself, untracked.
    test -z "$(git status --porcelain --untracked-files=all | grep -v '^ M .planning/config.json$' | grep -vxF "?? $REL_SELF")" \
      || die "the tree is not clean (only .planning/config.json and the uncommitted runner may differ)"
  else
    clean_tree || die "the tree is not clean (only .planning/config.json may differ)"
  fi
}

# ---------------------------------------------------------------- --self-check (offline only)
if [ "$MODE" = --self-check ]; then
  before_status="$(git status --porcelain --untracked-files=all)"
  assert_offline
  after_status="$(git status --porcelain --untracked-files=all)"
  [ "$before_status" = "$after_status" ] || die "--self-check changed the working tree"
  line="SELF-CHECK OK head=$(git rev-parse HEAD) runner_sha256=$(sha "$SELF")"
  printf '%s\n' "$line" > "$(git rev-parse --git-dir)/sigra-253-R12-main-fetch-self-check.txt" || die "cannot write the self-check receipt"
  echo "$line"
  exit 0
fi

# ---------------------------------------------------------------- default mode: the one fetch
assert_offline
RUNNER_COMMIT="$(git log --diff-filter=A --format=%H -- "$REL_SELF")"
[ -n "$RUNNER_COMMIT" ] || die "this runner is not committed"
[ "$(git show -s --format=%s "$RUNNER_COMMIT")" = "$RUNNER_SUBJECT" ] || die "the runner commit subject differs"
git diff --quiet HEAD -- "$REL_SELF" || die "this runner differs from its committed bytes"

BEFORE="$(git rev-parse "$TRACKING_REF")"
HEAD_BEFORE="$(git rev-parse HEAD)"
REFS_BEFORE="$(git for-each-ref --format='%(refname) %(objectname)')"
FETCH_ERR="$(mktemp "${TMPDIR:-/tmp}/253-136-fetch-err.XXXXXX")" || die "mktemp failed"

echo "FETCH STARTS $(now_utc)"
FETCH_STARTED=1
run_fetch 2>"$FETCH_ERR"; fetch_rc=$?
cat "$FETCH_ERR" >&2
FETCHED_AT="$(now_utc)"
URL="$(git remote get-url origin)"

if [ "$fetch_rc" -ne 0 ]; then
  jq -n --arg cmd "$FETCH_CMD" --arg url "$URL" --argjson approval "$(approval_json)" \
    --arg before "$BEFORE" --argjson rc "$fetch_rc" --arg at "$FETCHED_AT" \
    --arg err "$(tail -n 20 "$FETCH_ERR")" \
    '{schema_version: "sigra.phase253.main-fetch/r12", status: "failed", command: $cmd, remote_url: $url,
      approval: $approval, before_origin_main: $before, exit_code: $rc, stderr_tail: ($err | split("\n")),
      fetched_at_utc: $at}' > "$R" || die "cannot write the failed record"
  commit_record "$RECORD_SUBJECT" || die "the failed record could not be committed"
  clean_tree || echo "STOP: the tree is not clean after the record commit"
  echo "STOP: the fetch exited $fetch_rc; the failed record was committed. Do not retry."
  exit 1
fi

# ---------------------------------------------------------------- offline facts about the fetched main
ANOMALIES=()
AFTER="$(git rev-parse "$TRACKING_REF")"
FH="$(git rev-parse --verify --quiet 'FETCH_HEAD^{commit}')" || FH=""
[ "$AFTER" = "$FH" ] || ANOMALIES+=("refs/remotes/origin/main ($AFTER) differs from FETCH_HEAD ($FH)")
AFTER_TYPE="$(git cat-file -t "$AFTER")"
[ "$AFTER_TYPE" = commit ] || ANOMALIES+=("the fetched object is a $AFTER_TYPE, not a commit")
[ "$(git rev-parse HEAD)" = "$HEAD_BEFORE" ] || ANOMALIES+=("HEAD moved during the fetch")
[ "$(sha .planning/config.json)" = "$CFG_SHA" ] || ANOMALIES+=("config.json changed during the fetch")

COMMITTER_TIME="$(git show -s --format=%cI "$AFTER")"
SUBJECT="$(git show -s --format=%s "$AFTER")"

anc() { if git merge-base --is-ancestor "$1" "$AFTER" 2>/dev/null; then echo true; else echo false; fi; }
ANC_84="$(anc "$SHA_84EBCEA60")"
ANC_4F="$(anc "$SHA_4FF6C50E4")"
ANC_09="$(anc "$SHA_09DF342A")"

COMMITS_TOTAL="$(git rev-list --count "$SHA_4FF6C50E4..$AFTER")"
COMMITS_JSON="$(git log --format='%H%x09%cI%x09%s' -n 100 "$SHA_4FF6C50E4..$AFTER" \
  | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {sha: .[0], committer_time: .[1], subject: (.[2:] | join("\t"))})')"
PLANNING_JSON="$(git diff --name-only "$SHA_84EBCEA60" "$AFTER" -- .planning | jq -R -s 'split("\n") | map(select(length > 0))')"

MT_OUT="$(git merge-tree --write-tree --name-only --no-messages "$R11_CANDIDATE" "$AFTER" 2>/dev/null)"; MT_RC=$?
if [ "$MT_RC" -le 1 ]; then
  MT_CONFLICTS="$(printf '%s\n' "$MT_OUT" | sed 1d | sed '/^$/d' | sort -u | jq -R -s 'split("\n") | map(select(length > 0))')"
else
  MT_CONFLICTS='[]'
  ANOMALIES+=("git merge-tree of the R11 candidate against the fetched main errored (exit $MT_RC)")
fi
git merge-tree --write-tree --name-only --no-messages "$R11_CANDIDATE" "$SHA_84EBCEA60" >/dev/null 2>&1; CTL_RC=$?

REFS_AFTER="$(git for-each-ref --format='%(refname) %(objectname)')"
REFS_CHANGED="$(diff <(printf '%s\n' "$REFS_BEFORE") <(printf '%s\n' "$REFS_AFTER") | sed -n 's/^[<>] \([^ ]*\) .*$/\1/p' | sort -u \
  | jq -R -s 'split("\n") | map(select(length > 0))')"
OTHER_REFS="$(printf '%s' "$REFS_CHANGED" | jq -r --arg t "$TRACKING_REF" 'map(select(. != $t)) | join(", ")')"
[ -z "$OTHER_REFS" ] || ANOMALIES+=("local refs other than $TRACKING_REF changed: $OTHER_REFS")
ANOMALIES_JSON="$(if [ ${#ANOMALIES[@]} -gt 0 ]; then printf '%s\n' "${ANOMALIES[@]}"; fi | jq -R -s 'split("\n") | map(select(length > 0))')"

jq -n \
  --arg cmd "$FETCH_CMD" --arg url "$URL" --argjson approval "$(approval_json)" \
  --arg before "$BEFORE" --arg after "$AFTER" --arg fh "$FH" --arg at "$FETCHED_AT" \
  --arg ctime "$COMMITTER_TIME" --arg subj "$SUBJECT" \
  --arg s84 "$SHA_84EBCEA60" --arg s4f "$SHA_4FF6C50E4" --arg s09 "$SHA_09DF342A" \
  --argjson a84 "$ANC_84" --argjson a4f "$ANC_4F" --argjson a09 "$ANC_09" \
  --argjson ctotal "$COMMITS_TOTAL" --argjson commits "$COMMITS_JSON" --argjson planning "$PLANNING_JSON" \
  --arg cand "$R11_CANDIDATE" --argjson mtrc "$MT_RC" --argjson mtc "$MT_CONFLICTS" --argjson ctlrc "$CTL_RC" \
  --argjson refs "$REFS_CHANGED" --argjson anomalies "$ANOMALIES_JSON" \
  '{schema_version: "sigra.phase253.main-fetch/r12",
    status: "fetched",
    command: $cmd,
    remote_url: $url,
    approval: $approval,
    before_origin_main: $before,
    fetched_main_sha: $after,
    fetch_head_sha: $fh,
    fetched_at_utc: $at,
    fetched_commit_committer_time: $ctime,
    fetched_commit_subject: $subj,
    ancestry: {($s84): $a84, ($s4f): $a4f, ($s09): $a09},
    commits_since_4ff6c50e4: {total: $ctotal, listed: ($commits | length), truncated: ($ctotal > ($commits | length)), commits: $commits},
    planning_paths_changed_since_84ebcea60: $planning,
    r11_candidate_merge_tree: {head: $cand, against: $after, exit: $mtrc, conflicts: $mtc},
    control_merge_tree: {head: $cand, base: $s84, exit: $ctlrc},
    local_refs_changed: $refs,
    anomalies: $anomalies}' > "$R" || die "cannot write the record"

commit_record "$RECORD_SUBJECT" || die "the record commit failed"
RC_COMMIT="$(git log --diff-filter=A --format=%H -- "$R")"
[ "$(git show --name-only --format= "$RC_COMMIT" | grep -c .)" = 1 ] || die "the record commit carries other paths"
clean_tree || die "the tree is not clean after the record commit"

echo "FETCHED main $AFTER ($COMMITTER_TIME) $SUBJECT"
if [ ${#ANOMALIES[@]} -gt 0 ]; then
  printf 'ANOMALY: %s\n' "${ANOMALIES[@]}"
  echo "STOP: the record was committed with anomalies listed above. Do not retry."
  exit 1
fi
echo "DONE $AFTER"
exit 0
