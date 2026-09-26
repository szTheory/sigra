#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-phase-244-final-main.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/output"
MAIN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" != api ]]; then echo "unexpected gh call: $*" >&2; exit 1; fi
endpoint="$2"
if [[ "$endpoint" == rate_limit ]]; then
  echo '{"resources":{"core":{"remaining":5000,"reset":1777777777}}}'
elif [[ "$endpoint" == repos/szTheory/sigra/git/ref/heads/main ]]; then
  n=0; [[ -f "$FAKE_COUNTER" ]] && n=$(cat "$FAKE_COUNTER"); n=$((n+1)); echo "$n" >"$FAKE_COUNTER"
  sha="$FAKE_MAIN_SHA"; [[ "$FAKE_CASE" == advance_main && "$n" -gt 1 ]] && sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  echo "{\"ref\":\"refs/heads/main\",\"object\":{\"sha\":\"$sha\"}}"
elif [[ "$endpoint" == repos/szTheory/sigra/actions/runs/123 ]]; then
  printf '{"id":123,"html_url":"https://github.com/szTheory/sigra/actions/runs/123","head_sha":"%s","head_branch":"main","event":"workflow_dispatch","status":"completed","conclusion":"success","created_at":"2026-09-26T19:05:00Z","path":".github/workflows/ci.yml","inputs":{"phase_244_final_main":true,"recapture_branch":"","force_fail_probe":false,"force_rot_probe":false}}\n' "$FAKE_RUN_SHA"
elif [[ "$endpoint" == *"/jobs?"* ]]; then
  page="$(sed -n 's/.*[?&]page=\([0-9][0-9]*\).*/\1/p' <<<"$endpoint")"
  jobs=$(jq -n '
    def job($id; $name; $step):
      {id:$id,run_id:123,name:$name,status:"completed",conclusion:"success",html_url:("https://github.com/szTheory/sigra/actions/runs/123/job/" + ($id|tostring)),steps:(if $step == "" then [] else [{name:$step,number:1,status:"completed",conclusion:"success"}] end)};
    [
      job(101;"ci-gate";""),
      job(102;"Example Playwright shard (admin_behavior)";"Run admin behavior browser truth"),
      job(103;"Example Playwright shard (admin_checkpoints)";"Run admin checkpoints"),
      job(104;"Example Playwright shard (design_gallery)";"Run design gallery behavior and snapshots"),
      job(105;"Example Playwright shard (non_admin_smoke)";"Run non-admin example browser smoke"),
      job(106;"Example Playwright shard (demo_showcase)";"Run demo showcase"),
      job(107;"Example Playwright smoke (full lifecycle)";"Aggregate every Playwright shard result"),
      job(108;"Generated admin Playwright smoke";"Run generated admin acceptance smoke")
    ]')
  case "$FAKE_CASE" in
    missing_shard) jobs=$(jq 'map(select(.id!=102))' <<<"$jobs");;
    duplicate_shard) jobs=$(jq '. + [.[1]]' <<<"$jobs");;
    duplicate_step) jobs=$(jq 'map(if .id==102 then .steps += .steps else . end)' <<<"$jobs");;
    missing_steps) jobs=$(jq 'map(if .id==102 then .steps=null else . end)' <<<"$jobs");;
    total_mismatch) :;;
    skipped_smoke) jobs=$(jq 'map(if .id==107 then .steps[0].status="completed" | .steps[0].conclusion="skipped" else . end)' <<<"$jobs");;
    failed_gate) jobs=$(jq 'map(if .id==101 then .conclusion="failure" else . end)' <<<"$jobs");;
    docs_only) jobs=$(jq 'map(if .id>=102 and .id<=106 then .steps[0].conclusion="skipped" else . end)' <<<"$jobs");;
  esac
  [[ "$FAKE_CASE" == malformed_page ]] && { echo '{bad'; exit 0; }
  case "$page" in
    1) jq -c '{total_count:8,jobs:.[0:4]}' <<<"$jobs" ;;
    2) jq -c --argjson total "$(if [[ "$FAKE_CASE" == duplicate_shard ]]; then echo 9; elif [[ "$FAKE_CASE" == total_mismatch ]]; then echo 10; else echo 8; fi)" '{total_count:$total,jobs:(if $total==9 then .[4:9] else .[4:8] end)}' <<<"$jobs" ;;
    3) echo "{\"total_count\":$(if [[ "$FAKE_CASE" == duplicate_shard ]]; then echo 9; elif [[ "$FAKE_CASE" == total_mismatch ]]; then echo 10; else echo 8; fi),\"jobs\":[]}" ;;
    *) echo "unexpected page: $page" >&2; exit 1 ;;
  esac
else
  echo "unexpected endpoint: $endpoint" >&2
  exit 1
fi
EOF
chmod +x "$TMP/bin/gh"

if [[ ! -x "$COLLECTOR" ]]; then
  echo "FAIL: collector_missing" >&2
  exit 1
fi
run_case(){ local c="$1" runsha="${2:-$MAIN_SHA}"; rm -f "$TMP/output/receipt.json" "$TMP/counter"; set +e; FAKE_CASE="$c" FAKE_COUNTER="$TMP/counter" FAKE_MAIN_SHA="$MAIN_SHA" FAKE_RUN_SHA="$runsha" PATH="$TMP/bin:$PATH" "$COLLECTOR" capture --run-id 123 --route phase_244_final_main --not-before 2026-09-26T19:04:12Z --output "$TMP/output/receipt.json" >"$TMP/stdout" 2>"$TMP/stderr"; result=$?; set -e; echo "$result"; }
[[ "$(run_case success)" == 0 ]] || { cat "$TMP/stderr" >&2; echo 'FAIL: success fixture' >&2; exit 1; }
jq -e --arg sha "$MAIN_SHA" '.schema_version=="sigra.phase-244-final-main/1" and .main_sha_before==$sha and .main_sha_after==$sha and .run.head_sha==$sha and .ci_gate.conclusion=="success" and .example_playwright_shards.design_gallery.step.name=="Run design gallery behavior and snapshots"' "$TMP/output/receipt.json" >/dev/null
"$COLLECTOR" verify --receipt "$TMP/output/receipt.json" --main-sha "$MAIN_SHA" >/dev/null
jq -n --slurpfile r "$TMP/output/receipt.json" '{final_main_consumer_receipt:$r[0]}' >"$TMP/output/evidence.json"
"$COLLECTOR" verify --receipt "$TMP/output/evidence.json" --main-sha "$MAIN_SHA" >/dev/null
for c in missing_shard duplicate_shard duplicate_step missing_steps skipped_smoke failed_gate malformed_page docs_only advance_main total_mismatch; do
  [[ "$(run_case "$c")" != 0 ]] || { echo "FAIL: $c accepted" >&2; exit 1; }
  [[ ! -e "$TMP/output/receipt.json" ]] || { echo "FAIL: $c wrote receipt" >&2; exit 1; }
done
[[ "$(run_case wrong_sha bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)" != 0 ]] || { echo 'FAIL: wrong SHA accepted' >&2; exit 1; }
echo "capture-phase-244-final-main.test: PASS (success + 10 fail-closed fixtures and embedded-receipt verification)"
