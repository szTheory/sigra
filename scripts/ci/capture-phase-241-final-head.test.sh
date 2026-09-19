#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-phase-241-final-head.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/output"

pass=0
fail=0
check() {
  if "$@"; then pass=$((pass + 1)); else echo "FAIL: $*" >&2; fail=$((fail + 1)); fi
}

if [[ ! -x "$COLLECTOR" ]]; then
  echo "capture-phase-241-final-head.test: FAIL: collector_missing" >&2
  exit 1
fi

git -C "$TMP" init -q repo
git -C "$TMP/repo" config user.email phase-241@example.test
git -C "$TMP/repo" config user.name phase-241-test
printf 'frozen evidence candidate\n' >"$TMP/repo/README"
git -C "$TMP/repo" add README
git -C "$TMP/repo" commit -qm frozen
HEAD_SHA="$(git -C "$TMP/repo" rev-parse HEAD)"

cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
mode="${FAKE_MODE:-success}"
if [[ "$1" == api && "$2" == rate_limit ]]; then
  if [[ "$mode" == low_rate ]]; then echo '{"resources":{"core":{"remaining":250,"reset":1777777777}}}'; else echo '{"resources":{"core":{"remaining":251,"reset":1777777777}}}'; fi
  exit 0
fi
if [[ "$1" == pr && "$2" == comment ]]; then
  printf '%s\n' "$*" >>"$FAKE_COMMENT_LOG"
  exit 0
fi
if [[ "$1" != api ]]; then echo "unexpected gh call: $*" >&2; exit 1; fi
if [[ "$mode" == http_403 || "$mode" == http_429 ]]; then
  code="${mode#http_}"
  echo "HTTP $code rate limit reset 1777777777" >&2
  exit 1
fi
endpoint="$2"
if [[ "$endpoint" == repos/szTheory/sigra/actions/runs/* && "$endpoint" != *'/jobs?'* ]]; then
  event=pull_request status=completed conclusion=success sha="$FAKE_HEAD_SHA"
  case "$mode" in
    sha_mismatch) sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
    wrong_event) event=push ;;
    incomplete) status=in_progress; conclusion=null ;;
    null_conclusion) conclusion=null ;;
    run_failure) conclusion=failure ;;
  esac
  printf '{"id":123,"html_url":"https://example.test/runs/123","head_sha":"%s","event":"%s","status":"%s","conclusion":%s}\n' "$sha" "$event" "$status" "$( [[ "$conclusion" == null ]] && printf null || printf '\"%s\"' "$conclusion" )"
  exit 0
fi
if [[ "$endpoint" == *'/jobs?'* ]]; then
  page="$(sed -n 's/.*[?&]page=\([0-9][0-9]*\).*/\1/p' <<<"$endpoint")"
  if [[ "$mode" == missing_terminal && "$page" == 2 ]]; then echo 'synthetic missing terminal page' >&2; exit 1; fi
  if [[ "$page" == 1 ]]; then
    owner_step=success fast_step=success
    [[ "$mode" == step_failure ]] && fast_step=failure
    extra=''
    [[ "$mode" == duplicate_job ]] && extra=',{"id":14,"run_id":123,"name":"Library tests","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/14","steps":[{"name":"Require the library suite owner to pass","status":"completed","conclusion":"success"}]}'
    if [[ "$mode" == missing_job ]]; then
      printf '{"total_count":2,"jobs":[{"id":11,"run_id":123,"name":"Library tests shard","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/11","steps":[{"name":"Run contributor CI gate","status":"completed","conclusion":"success"}]},{"id":13,"run_id":123,"name":"Fast checks (milestone/installer/contracts/snapshot/ledger guards)","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/13","steps":[{"name":"Phase 230 prohibition guards","status":"completed","conclusion":"%s"}]}]}\n' "$fast_step"
    else
      total=3; [[ "$mode" == total_disagreement || "$mode" == duplicate_job ]] && total=4
      printf '{"total_count":%s,"jobs":[{"id":11,"run_id":123,"name":"Library tests shard","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/11","steps":[{"name":"Run contributor CI gate","status":"completed","conclusion":"%s"}]},{"id":12,"run_id":123,"name":"Library tests","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/12","steps":[{"name":"Require the library suite owner to pass","status":"completed","conclusion":"success"}]},{"id":13,"run_id":123,"name":"Fast checks (milestone/installer/contracts/snapshot/ledger guards)","status":"completed","conclusion":"success","html_url":"https://example.test/jobs/13","steps":[{"name":"Phase 230 prohibition guards","status":"completed","conclusion":"%s"}]}%s]}\n' "$total" "$owner_step" "$fast_step" "$extra"
    fi
    exit 0
  fi
  [[ "$page" == 2 ]] || { echo "unexpected jobs page" >&2; exit 1; }
  total=3; [[ "$mode" == total_disagreement || "$mode" == duplicate_job ]] && total=4; [[ "$mode" == missing_job ]] && total=2
  printf '{"total_count":%s,"jobs":[]}\n' "$total"
  exit 0
fi
echo "unexpected endpoint: $endpoint" >&2
exit 1
EOF
chmod +x "$TMP/bin/gh"

run_collector() {
  local mode="$1" output="$2" comment="${3:-}"
  FAKE_MODE="$mode" FAKE_HEAD_SHA="$HEAD_SHA" FAKE_GH_LOG="$TMP/$mode.calls" FAKE_COMMENT_LOG="$TMP/$mode.comments" PATH="$TMP/bin:$PATH" \
    git -C "$TMP/repo" --work-tree="$TMP/repo" --git-dir="$TMP/repo/.git" status --porcelain >/dev/null
  (cd "$TMP/repo" && FAKE_MODE="$mode" FAKE_HEAD_SHA="$HEAD_SHA" FAKE_GH_LOG="$TMP/$mode.calls" FAKE_COMMENT_LOG="$TMP/$mode.comments" PATH="$TMP/bin:$PATH" \
    "$COLLECTOR" --run-id 123 --head-sha "$HEAD_SHA" --pr-number 456 --output "$output" $comment)
}

success="$TMP/output/success.json"
run_collector success "$success" --comment
check jq -e --arg sha "$HEAD_SHA" '
  .schema_version == "sigra.phase-241-final-head/1" and .head_sha == $sha and .event == "pull_request" and
  .library_owner.name == "Library tests shard" and .library_owner.step.name == "Run contributor CI gate" and
  .library_owner.step.conclusion == "success" and .library_aggregator.name == "Library tests" and
  .fast_checks.step.name == "Phase 230 prohibition guards" and .fast_checks.step.conclusion == "success"
' "$success"
check grep -q 'pr comment 456' "$TMP/success.calls"
check test "$(grep -c '/jobs?' "$TMP/success.calls")" -eq 2

declare -A tokens=(
  [sha_mismatch]=run_head_sha_mismatch
  [wrong_event]=run_event_not_pull_request
  [incomplete]=run_not_completed
  [null_conclusion]=run_conclusion_not_success
  [run_failure]=run_conclusion_not_success
  [duplicate_job]=required_job_not_unique_Library_tests
  [missing_job]=required_job_missing_Library_tests
  [step_failure]=required_step_not_success_Phase_230_prohibition_guards
  [total_disagreement]=jobs_total_count_disagreement
  [missing_terminal]=jobs_pagination_not_exhausted
  [low_rate]=rate_limit_too_low
  [http_403]=github_rate_limited_http_403
  [http_429]=github_rate_limited_http_429
)
for mode in "${!tokens[@]}"; do
  output="$TMP/output/$mode.json"
  printf 'prior output for %s\n' "$mode" >"$output"
  set +e
  run_collector "$mode" "$output" >"$TMP/$mode.out" 2>"$TMP/$mode.err"
  rc=$?
  set -e
  check test "$rc" -ne 0
  check grep -q "${tokens[$mode]}" "$TMP/$mode.err"
  check grep -q "prior output for $mode" "$output"
  check test ! -s "$TMP/$mode.comments"
done
check test "$(wc -l <"$TMP/low_rate.calls")" -eq 1
check test "$(wc -l <"$TMP/http_403.calls")" -eq 2
check test "$(wc -l <"$TMP/http_429.calls")" -eq 2

echo "pass=$pass fail=$fail"
(( fail == 0 )) || exit 1
echo "capture-phase-241-final-head.test: PASS"
