#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-terminal-ratification-evidence.sh"
WORKFLOW="$ROOT/.github/workflows/terminal-ratification-evidence.yml"

test -x "$COLLECTOR"
test -s "$WORKFLOW"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
RUN_IDS=(30686149095 30720751244 30722291400 30722736494 30723164608 30723565742 30723575804 30723593560 30723596945 30723600313 30723601060 30723605581 30723607878 30723608377 30723615281 30723622708 30729478819 30729487808 30729531710 30729534413 30729540143 30729540659 30734422326)
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
if [[ "$1" == api && "$2" == rate_limit ]]; then echo 251; exit 0; fi
PAGE="$(printf '%s' "$*" | sed -n 's/.*page=\([0-9][0-9]*\).*/\1/p')"
if [[ "$*" == *'workflows/ci.yml/runs?'* ]] && [[ -n "$PAGE" ]]; then
  case "$PAGE" in
  1)
    if [[ "${FAKE_MODE:-ok}" == inverted_run ]]; then
      echo '{"total_count":1,"workflow_runs":[{"id":1,"event":"pull_request","conclusion":"success","created_at":"2026-08-02T03:00:00Z","updated_at":"2026-08-02T02:00:00Z"}]}'
    else
      run_ids=("${RUN_IDS[@]}")
      if [[ "${FAKE_MODE:-ok}" == missing_run ]]; then
        unset 'run_ids[${#run_ids[@]}-1]'
      elif [[ "${FAKE_MODE:-ok}" == unexpected_run ]]; then
        run_ids[${#run_ids[@]}-1]=99999999999
      fi
      printf '{"total_count":%s,"workflow_runs":[' "${#run_ids[@]}"
      for index in "${!run_ids[@]}"; do
        (( index > 0 )) && printf ','
        printf '{"id":%s,"event":"pull_request","conclusion":"success","created_at":"2026-08-02T02:00:00Z","updated_at":"2026-08-02T03:00:00Z"}' "${run_ids[$index]}"
      done
      printf ']}\n'
    fi ;;
  2)
    if [[ "${FAKE_MODE:-ok}" == inverted_run ]]; then
      echo '{"total_count":1,"workflow_runs":[]}'
    else
      if [[ "${FAKE_MODE:-ok}" == missing_run ]]; then echo '{"total_count":22,"workflow_runs":[]}'; else echo '{"total_count":23,"workflow_runs":[]}'; fi
    fi ;;
  *) echo "unexpected run page: $*" >&2; exit 1 ;;
  esac
elif [[ "$*" == *'/jobs?'* ]] && [[ "$PAGE" == 1 ]]; then
  if [[ "${FAKE_MODE:-ok}" == large ]]; then
    payload="$(head -c 140000 /dev/zero | tr '\0' x)"
    printf '{"total_count":1,"jobs":[{"id":7,"name":"%s","conclusion":"success","started_at":"2026-08-02T02:00:00Z","completed_at":"2026-08-02T03:00:00Z"}]}\n' "$payload"
    exit 0
  fi
  if [[ "${FAKE_MODE:-ok}" == non_skipped_inverted ]]; then
    echo '{"total_count":1,"jobs":[{"id":9,"name":"real job","conclusion":"success","started_at":"2026-08-02T03:00:00Z","completed_at":"2026-08-02T02:59:59Z"}]}'
  else
    echo '{"total_count":2,"jobs":[{"id":7,"name":"skipped with inversion","conclusion":"skipped","started_at":"2026-08-02T03:00:00Z","completed_at":"2026-08-02T02:59:59Z"},{"id":8,"name":"skipped without schedule","conclusion":"skipped","started_at":null,"completed_at":null}]}'
  fi
elif [[ "$*" == *'/jobs?'* ]] && [[ "$PAGE" == 2 ]]; then
  if [[ "${FAKE_MODE:-ok}" == non_skipped_inverted || "${FAKE_MODE:-ok}" == large ]]; then echo '{"total_count":1,"jobs":[]}'; else echo '{"total_count":2,"jobs":[]}'; fi
else
  echo "unexpected gh invocation: $*" >&2; exit 1
fi
EOF
chmod +x "$TMP/bin/gh"

FAKE_GH_LOG="$TMP/calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/receipt.json"
jq -e '.workflow_runs == {requested_pages:[1,2], data_page_count:1, terminal_page:2, exhausted:true, total_count:23, pages:.workflow_runs.pages} and ([.workflow_runs.pages[].body.workflow_runs[]] | length) == 23' "$TMP/receipt.json" >/dev/null
grep -q 'workflows/ci.yml/runs.*page=1' "$TMP/calls"
grep -q 'workflows/ci.yml/runs.*page=2' "$TMP/calls"
# Each of the 23 fixed historical runs must retain both its data page and the
# terminal empty page that proves pagination exhaustion.
test "$(grep -c '/jobs?' "$TMP/calls")" -eq 46
test "$(grep -c '/jobs?.*&page=1$' "$TMP/calls")" -eq 23
test "$(grep -c '/jobs?.*&page=2$' "$TMP/calls")" -eq 23
jq -e 'all(.jobs[].pages[0].body.jobs[]; .conclusion == "skipped")' "$TMP/receipt.json" >/dev/null

set +e
FAKE_MODE=inverted_run FAKE_GH_LOG="$TMP/inverted-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/inverted.json" 2>"$TMP/inverted.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'run_chronology_or_identity_invalid' "$TMP/inverted.err"
test ! -e "$TMP/inverted.json"

for mode in missing_run unexpected_run; do
  set +e
  FAKE_MODE="$mode" FAKE_GH_LOG="$TMP/${mode}-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/${mode}.json" 2>"$TMP/${mode}.err"
  RC=$?
  set -e
  test "$RC" -ne 0
  grep -q 'workflow_run_population_mismatch' "$TMP/${mode}.err"
  test ! -e "$TMP/${mode}.json"
  test "$(grep -c '/jobs?' "$TMP/${mode}-calls" || true)" -eq 0
done

set +e
FAKE_MODE=non_skipped_inverted FAKE_GH_LOG="$TMP/job-inverted-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/job-inverted.json" 2>"$TMP/job-inverted.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'job_chronology_or_identity_invalid_run_' "$TMP/job-inverted.err"

FAKE_MODE=large FAKE_GH_LOG="$TMP/large-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/large.json"
jq -e '.jobs | length == 23' "$TMP/large.json" >/dev/null
