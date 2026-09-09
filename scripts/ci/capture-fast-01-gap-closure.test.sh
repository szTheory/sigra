#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; COLLECTOR="$ROOT/scripts/ci/capture-fast-01-gap-closure.sh"
fail() { echo "capture-fast-01-gap-closure.test: FAIL: $*" >&2; exit 1; }
[[ -x "$COLLECTOR" ]] || fail "collector missing or not executable"
grep -Fq 'CUTOFF_SHA="54c33e904155a454255952666711c882afdd06e4"' "$COLLECTOR" || fail "cutoff drifted"
grep -Fq 'cutoff_blob_digest_mismatch' "$COLLECTOR" || fail "cutoff blob validation absent"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; mkdir -p "$TMP/bin"

make_runs() { jq -n --argjson count "$1" --argjson duration "$2" '[range(0;$count)|{id:(900000+.),event:"pull_request",conclusion:(if .%3==0 then "failure" elif .%3==1 then "cancelled" else "success" end),created_at:"2026-08-03T21:37:09Z",updated_at:("2026-08-03T21:"+((37+(($duration+.)/60|floor))|tostring|if length==1 then "0"+. else . end)+":"+(($duration+.)%60|tostring|if length==1 then "0"+. else . end)+"Z"),html_url:("https://example.test/"+(900000+.|tostring))}]' >"$TMP/runs.json"; }
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == api && "$2" == rate_limit ]]; then jq -n --argjson remaining "${FAKE_REMAINING:-500}" '{resources:{core:{remaining:$remaining,reset:"2030-01-01T00:00:00Z"}}}'; exit 0; fi
[[ "${FAKE_HTTP:-}" == 403 || "${FAKE_HTTP:-}" == 429 ]] && exit 1
if [[ "$2" == *"/jobs?"* ]]; then
  page="${2##*page=}"; run_id="${2#*/runs/}"; run_id="${run_id%%/*}"
  if [[ "$page" == 1 ]]; then
    actual_run_id=$((run_id + ${FAKE_JOB_RUN_OFFSET:-0}))
    jq -n --argjson run_id "$actual_run_id" --arg completed "${FAKE_JOB_COMPLETED_AT:-2026-08-03T21:39:00Z}" '{jobs:[{id:($run_id+1000),run_id:$run_id,name:"Library tests",conclusion:"success",started_at:"2026-08-03T21:38:00Z",completed_at:$completed,steps:[{number:1,name:"Run contributor CI gate",status:"completed",conclusion:"success",started_at:"2026-08-03T21:38:01Z",completed_at:$completed}]}]}'
  else
    jq -n '{jobs:[]}'
  fi
  exit 0
fi
page="${2##*page=}"; [[ "$page" =~ ^[0-9]+$ ]] || exit 1
if [[ "$page" == 1 ]]; then
  jq -n --argjson runs "$FAKE_RUNS" '{workflow_runs:$runs}'
elif [[ "$page" == 2 && -n "${FAKE_PAGE_2_RUNS:-}" ]]; then
  jq -n --argjson runs "$FAKE_PAGE_2_RUNS" '{workflow_runs:$runs}'
elif [[ "${FAKE_BAD_PAGE:-}" == 1 ]]; then
  jq -n '{}'
else
  jq -n '{workflow_runs:[]}'
fi
EOF
chmod +x "$TMP/bin/gh"
run_readiness() { local n="$1"; make_runs "$n" 719; PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/readiness-$n.json"; jq -e --argjson n "$n" '.authority=="readiness_only" and .eligible_pr_run_count==$n and .status==(if $n<10 then "insufficient_population" else "ready" end) and (if $n<10 then .statistics==null and .verdict==null else (.statistics|type)=="object" and (.verdict=="pass" or .verdict=="miss") end)' "$TMP/readiness-$n.json" >/dev/null || fail "readiness n=$n"; }
for n in 0 1 9 10 11; do run_readiness "$n"; done
make_runs 10 719
for bad in '--endpoint 2026-08-03T22:00:00Z' 'extra'; do if PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/bad.json" $bad >/dev/null 2>&1; then fail "local endpoint override accepted"; fi; done
for remaining in 250 249; do if PATH="$TMP/bin:$PATH" FAKE_REMAINING="$remaining" FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/rate.json" >/dev/null 2>&1; then fail "rate threshold accepted"; fi; done
for http in 403 429; do if PATH="$TMP/bin:$PATH" FAKE_HTTP="$http" FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/http.json" >/dev/null 2>&1; then fail "HTTP $http accepted"; fi; done
jq '.[0].id=30828457128' "$TMP/runs.json" >"$TMP/overlap.json"; if PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/overlap.json")" "$COLLECTOR" --readiness "$TMP/overlap-out.json" >/dev/null 2>&1; then fail "old receipt id accepted"; fi
jq '.[1].id=.[0].id' "$TMP/runs.json" >"$TMP/duplicate.json"; if PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/duplicate.json")" "$COLLECTOR" --readiness "$TMP/duplicate-out.json" >/dev/null 2>&1; then fail "duplicate id accepted"; fi
if PATH="$TMP/bin:$PATH" FAKE_BAD_PAGE=1 FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --readiness "$TMP/malformed-page.json" >/dev/null 2>&1; then fail "malformed pagination page accepted"; fi
for duration in 719 720 721; do make_runs 10 "$((duration + 4))"; PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/runs.json")" "$COLLECTOR" --protected-output "$TMP/protected-$duration.json" --endpoint 2026-08-03T22:00:00Z; jq -e --arg expected "$(if ((duration==719)); then echo pass; else echo miss; fi)" --argjson duration "$duration" '
  .schema_version=="sigra.fast-01-source-complete-remeasurement/1" and
  .status=="measured" and .verdict==$expected and .statistics.p50_seconds==$duration and
  .statistics.ordering=="{wall_seconds, run_id}" and
  .source_collection.requested_pages==[1,2] and .source_collection.terminal_page==2 and
  .source_collection.pages[0].returned_count==10 and .source_collection.pages[1].returned_count==0 and
  (.instrument_receipt.command|contains("scripts/ci/ci-run-metrics.sh")) and
  .instrument_receipt.output.runs==.runs and
  (if $expected=="miss" then (.binding_poles.median.exhausted and .binding_poles.maximum.exhausted) else .binding_poles==null end)
' "$TMP/protected-$duration.json" >/dev/null || fail "strict comparator/source receipt $duration"; done
make_runs 10 719
jq '.[0].updated_at="2026-08-03T22:00:01Z"' "$TMP/runs.json" >"$TMP/completed-after-endpoint.json"
PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/completed-after-endpoint.json")" "$COLLECTOR" --protected-output "$TMP/protected-completed-after-endpoint.json" --endpoint 2026-08-03T22:00:00Z
jq -e '.status=="measured" and .eligible_pr_run_count==10 and ([.runs[] | select(.run_id==900000) | .wall_seconds] == [1372])' "$TMP/protected-completed-after-endpoint.json" >/dev/null || fail "terminal run completed after fixed endpoint rejected"
make_runs 10 719
jq '. + [(. [0] | .id=910000 | .conclusion=null)]' "$TMP/runs.json" >"$TMP/with-in-progress-pr.json"
PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/with-in-progress-pr.json")" "$COLLECTOR" --protected-output "$TMP/protected-terminal-only.json" --endpoint 2026-08-03T22:00:00Z
jq -e '.status=="measured" and .eligible_pr_run_count==10 and ([.runs[] | select(.run_id==910000)] | length == 0)' "$TMP/protected-terminal-only.json" >/dev/null || fail "in-progress pull request was included in terminal population"

make_runs 5 719; FIRST_PAGE="$(<"$TMP/runs.json")"; make_runs 5 724; SECOND_PAGE="$(jq 'map(.id += 100)' "$TMP/runs.json")"
PATH="$TMP/bin:$PATH" FAKE_RUNS="$FIRST_PAGE" FAKE_PAGE_2_RUNS="$SECOND_PAGE" "$COLLECTOR" --protected-output "$TMP/multi-page.json" --endpoint 2026-08-03T22:00:00Z
jq -e '.source_collection.requested_pages==[1,2,3] and .source_collection.pages[2]=={page:3,returned_count:0,runs:[]} and .eligible_pr_run_count==10' "$TMP/multi-page.json" >/dev/null || fail "multi-page source collection"

make_runs 10 724
if env PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/runs.json")" FAKE_JOB_RUN_OFFSET=1 "$COLLECTOR" --protected-output "$TMP/pole-wrong-run.json" --endpoint 2026-08-03T22:00:00Z >/dev/null 2>&1; then fail "binding pole wrong run accepted"; fi
if env PATH="$TMP/bin:$PATH" FAKE_RUNS="$(<"$TMP/runs.json")" FAKE_JOB_COMPLETED_AT=2026-08-03T21:37:59Z "$COLLECTOR" --protected-output "$TMP/pole-chronology.json" --endpoint 2026-08-03T22:00:00Z >/dev/null 2>&1; then fail "binding pole chronology accepted"; fi
echo "capture-fast-01-gap-closure.test: PASS"
