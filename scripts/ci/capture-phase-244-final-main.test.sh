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
  echo "{\"ref\":\"refs/heads/main\",\"object\":{\"sha\":\"$FAKE_MAIN_SHA\"}}"
elif [[ "$endpoint" == repos/szTheory/sigra/actions/runs/123 ]]; then
  printf '{"id":123,"html_url":"https://github.com/szTheory/sigra/actions/runs/123","head_sha":"%s","head_branch":"main","event":"workflow_dispatch","status":"completed","conclusion":"success","created_at":"2026-09-26T19:05:00Z","path":".github/workflows/ci.yml"}\n' "$FAKE_RUN_SHA"
elif [[ "$endpoint" == *"/jobs?"* ]]; then
  page="$(sed -n 's/.*[?&]page=\([0-9][0-9]*\).*/\1/p' <<<"$endpoint")"
  jobs="$(jq -n '
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
  case "$page" in
    1) jq -c '{total_count:8,jobs:.[0:4]}' <<<"$jobs" ;;
    2) jq -c '{total_count:8,jobs:.[4:8]}' <<<"$jobs" ;;
    3) echo '{"total_count":8,"jobs":[]}' ;;
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
set +e
FAKE_MAIN_SHA="$MAIN_SHA" FAKE_RUN_SHA="$MAIN_SHA" PATH="$TMP/bin:$PATH" \
  "$COLLECTOR" capture --run-id 123 --route phase_244_final_main --not-before 2026-09-26T19:04:12Z --output "$TMP/output/receipt.json" >"$TMP/stdout" 2>"$TMP/stderr"
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo "FAIL: valid exact-main workflow_dispatch should produce a receipt" >&2
  cat "$TMP/stderr" >&2
  exit 1
fi
jq -e --arg sha "$MAIN_SHA" '
  .schema_version == "sigra.phase-244-final-main/1" and
  .main_sha_before == $sha and .main_sha_after == $sha and
  .run.id == 123 and .run.head_sha == $sha and .run.event == "workflow_dispatch" and
  .ci_gate.conclusion == "success" and
  .example_playwright_shards.admin_behavior.step.name == "Run admin behavior browser truth" and
  .example_playwright_shards.admin_checkpoints.step.name == "Run admin checkpoints" and
  .example_playwright_shards.design_gallery.step.name == "Run design gallery behavior and snapshots" and
  .example_playwright_shards.non_admin_smoke.step.name == "Run non-admin example browser smoke" and
  .example_playwright_shards.demo_showcase.step.name == "Run demo showcase" and
  .example_playwright_smoke.step.name == "Aggregate every Playwright shard result" and
  .generated_admin_playwright_smoke.step.name == "Run generated admin acceptance smoke"
' "$TMP/output/receipt.json"
echo "capture-phase-244-final-main.test: PASS (success fixture)"
