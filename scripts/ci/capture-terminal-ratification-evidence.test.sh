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
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
if [[ "$1" == api && "$2" == rate_limit ]]; then echo 251; exit 0; fi
PAGE="$(printf '%s' "$*" | sed -n 's/.*page=\([0-9][0-9]*\).*/\1/p')"
if [[ "$*" == *'workflows/ci.yml/runs?'* ]] && [[ -n "$PAGE" ]]; then
  case "$PAGE" in
  1)
    if [[ "${FAKE_MODE:-ok}" == inverted_run ]]; then
      echo '{"total_count":1,"workflow_runs":[{"id":1,"event":"pull_request","conclusion":"success","created_at":"2026-08-02T03:00:00Z","updated_at":"2026-08-02T02:00:00Z"}]}'
    else
      echo '{"total_count":2,"workflow_runs":[{"id":1,"event":"pull_request","conclusion":"success","created_at":"2026-08-02T02:00:00Z","updated_at":"2026-08-02T03:00:00Z"},{"id":2,"event":"workflow_dispatch","conclusion":"failure","created_at":"2026-08-02T03:01:00Z","updated_at":"2026-08-02T03:02:00Z"}]}'
    fi ;;
  2) echo '{"total_count":2,"workflow_runs":[]}' ;;
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
  if [[ "${FAKE_MODE:-ok}" == non_skipped_inverted ]]; then echo '{"total_count":1,"jobs":[]}'; else echo '{"total_count":2,"jobs":[]}'; fi
else
  echo "unexpected gh invocation: $*" >&2; exit 1
fi
EOF
chmod +x "$TMP/bin/gh"

FAKE_GH_LOG="$TMP/calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/receipt.json"
jq -e '.workflow_runs == {requested_pages:[1,2], data_page_count:1, terminal_page:2, exhausted:true, total_count:2, pages:.workflow_runs.pages} and ([.workflow_runs.pages[].body.workflow_runs[] | select(.event == "workflow_dispatch")] | length) == 1' "$TMP/receipt.json" >/dev/null
grep -q 'workflows/ci.yml/runs.*page=1' "$TMP/calls"
grep -q 'workflows/ci.yml/runs.*page=2' "$TMP/calls"
test "$(grep -c '/jobs?' "$TMP/calls")" -eq 23
jq -e 'all(.jobs[].pages[0].body.jobs[]; .conclusion == "skipped")' "$TMP/receipt.json" >/dev/null

set +e
FAKE_MODE=inverted_run FAKE_GH_LOG="$TMP/inverted-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/inverted.json" 2>"$TMP/inverted.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'run_chronology_or_identity_invalid' "$TMP/inverted.err"
test ! -e "$TMP/inverted.json"

set +e
FAKE_MODE=non_skipped_inverted FAKE_GH_LOG="$TMP/job-inverted-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/job-inverted.json" 2>"$TMP/job-inverted.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'job_chronology_or_identity_invalid_run_' "$TMP/job-inverted.err"

FAKE_MODE=large FAKE_GH_LOG="$TMP/large-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/large.json"
jq -e '.jobs | length == 23' "$TMP/large.json" >/dev/null
