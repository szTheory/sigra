#!/usr/bin/env bash
# Fail-closed selector for the single protected evidence workflow dispatch.
set -euo pipefail

fail() { printf '%s\n' "correlate-terminal-ratification-dispatch: FAIL: $1" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing_${1}"; }
need jq

select_run() {
  local before="$1" after="$2" workflow_id="$3" head_sha="$4" not_before="$5" output="$6"
  jq -e 'type == "object" and (.total_count|type == "number") and .total_count <= 100 and (.workflow_runs|type == "array")' "$before" >/dev/null || fail "pre_projection_invalid"
  jq -e 'type == "object" and (.total_count|type == "number") and .total_count <= 100 and (.workflow_runs|type == "array")' "$after" >/dev/null || fail "post_projection_invalid"

  local candidates count
  candidates="$(jq -cn --slurpfile pre "$before" --slurpfile post "$after" --argjson workflow_id "$workflow_id" --arg sha "$head_sha" --arg boundary "$not_before" '
    ([ $pre[0].workflow_runs[].id ] | unique) as $pre_ids
    | [ $post[0].workflow_runs[]
        | select((.id as $id | $pre_ids | index($id) | not))
        # The before projection is only a set of historical IDs. Its rows may
        # legitimately predate the protected SHA; every identity predicate is
        # deliberately applied only to the newly added candidate.
        | select(.workflow_id == $workflow_id and .event == "workflow_dispatch" and .head_branch == "main" and .head_sha == $sha)
        | select((.created_at|type) == "string" and .created_at >= $boundary)
        | select((.id|type) == "number" and (.html_url|type) == "string" and (.html_url|length) > 0)
        | {id, html_url, workflow_id, event, head_branch, head_sha, created_at}
      ]
  ')"
  count="$(jq 'length' <<<"$candidates")"
  [[ "$count" == 1 ]] || fail "candidate_count_${count}"
  jq -e --arg boundary "$not_before" '.[0] + {dispatch_not_before: $boundary}' <<<"$candidates" >"$output" || fail "record_write_failed"
}

self_test() {
  local tmp before after out rc
  tmp="$(mktemp -d)"; trap "rm -rf '$tmp'" EXIT
  before="$tmp/before.json"; after="$tmp/after.json"; out="$tmp/out.json"
  printf '%s\n' '{"total_count":0,"workflow_runs":[]}' >"$before"
  printf '%s\n' '{"total_count":1,"workflow_runs":[{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"}]}' >"$after"
  select_run "$before" "$after" 7 abc 2026-08-03T00:00:00Z "$out"
  jq -e '.id == 42 and .html_url == "https://example.test/42" and .head_branch == "main"' "$out" >/dev/null
  # Historical rows exist solely to define the before-set. A prior SHA must
  # not disqualify the unique new protected candidate.
  printf '%s\n' '{"total_count":1,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"}]}' >"$before"
  printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"}]}' >"$after"
  select_run "$before" "$after" 7 abc 2026-08-03T00:00:00Z "$out"
  jq -e '.id == 42 and .head_sha == "abc"' "$out" >/dev/null
  for mode in zero multiple stale wrong_workflow wrong_event wrong_ref wrong_sha; do
    case "$mode" in
      zero) printf '%s\n' '{"total_count":0,"workflow_runs":[]}' >"$after" ;;
      multiple) printf '%s\n' '{"total_count":3,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"},{"id":43,"html_url":"https://example.test/43","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:01Z"}]}' >"$after" ;;
      stale) printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-02T23:59:59Z"}]}' >"$after" ;;
      wrong_workflow) printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":8,"event":"workflow_dispatch","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"}]}' >"$after" ;;
      wrong_event) printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"push","head_branch":"main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"}]}' >"$after" ;;
      wrong_ref) printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"not-main","head_sha":"abc","created_at":"2026-08-03T00:00:00Z"}]}' >"$after" ;;
      wrong_sha) printf '%s\n' '{"total_count":2,"workflow_runs":[{"id":41,"html_url":"https://example.test/41","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"old","created_at":"2026-08-02T00:00:00Z"},{"id":42,"html_url":"https://example.test/42","workflow_id":7,"event":"workflow_dispatch","head_branch":"main","head_sha":"nope","created_at":"2026-08-03T00:00:00Z"}]}' >"$after" ;;
    esac
    set +e; bash "$0" --pre "$before" --post "$after" --workflow-id 7 --head-sha abc --not-before 2026-08-03T00:00:00Z --output "$out" >/dev/null 2>"$tmp/$mode.err"; rc=$?; set -e
    [[ "$rc" -ne 0 ]] || fail "self_test_${mode}_accepted"
    case "$mode" in zero|stale|wrong_workflow|wrong_event|wrong_ref|wrong_sha) expected='candidate_count_0' ;; multiple) expected='candidate_count_2' ;; esac
    grep -qx "correlate-terminal-ratification-dispatch: FAIL: $expected" "$tmp/$mode.err" || fail "self_test_${mode}_diagnostic"
  done
}

if [[ "${1:-}" == "--self-test" ]]; then self_test; exit 0; fi
[[ "$#" == 12 && "$1" == "--pre" && "$3" == "--post" && "$5" == "--workflow-id" && "$7" == "--head-sha" && "$9" == "--not-before" && "${11}" == "--output" ]] || fail "usage"
select_run "$2" "$4" "$6" "$8" "${10}" "${12}"
