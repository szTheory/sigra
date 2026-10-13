#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/ci-gate-canary.sh"
FIXTURE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml"
FREEZE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json"

help_output="$(bash "$SCRIPT" --help)"
[[ "$help_output" == *"full-pass"* && "$help_output" == *"cancelled"* ]]
test_freeze="$(mktemp /tmp/253-canary-test-freeze.XXXXXX.json)"
trap 'rm -f "$test_freeze"; rm -rf "$tmp_dir"' EXIT
jq --arg runner "$(shasum -a 256 "$ROOT/scripts/ci/ci-gate-canary.sh" | awk '{print $1}')" \
   --arg shell_test "$(shasum -a 256 "$ROOT/scripts/ci/ci-gate-canary.test.sh" | awk '{print $1}')" \
   --arg verifier "$(shasum -a 256 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" | awk '{print $1}')" \
   --arg python_test "$(shasum -a 256 "$ROOT/scripts/ci/ci-hosted-gate-verify.test.py" | awk '{print $1}')" \
  '.source_sha256["scripts/ci/ci-gate-canary.sh"]=$runner | .source_sha256["scripts/ci/ci-gate-canary.test.sh"]=$shell_test | .source_sha256["scripts/ci/ci-hosted-gate-verify.py"]=$verifier | .source_sha256["scripts/ci/ci-hosted-gate-verify.test.py"]=$python_test' "$FREEZE" > "$test_freeze"
bash "$SCRIPT" --check-only --recovery-freeze "$test_freeze"
! rg -q 'gh run watch|WATCH_RESERVATION|watch_request_reservation' "$SCRIPT"
rg -q 'POLL_INTERVAL=60' "$SCRIPT"
rg -q -- '--max-redirs 0' "$SCRIPT"
rg -q 'transport_ledger' "$SCRIPT"

fixture_name="$(rg -c '^name: Phase 253 Gate Canary$' "$FIXTURE")"
[[ "$fixture_name" == 1 ]]
python3 - "$FIXTURE" <<'PY'
import sys
import yaml
with open(sys.argv[1], encoding='utf-8') as source:
    workflow = yaml.safe_load(source)
triggers = workflow.get('on', workflow.get(True))
if not isinstance(triggers, dict) or list(triggers) != ['workflow_dispatch']:
    raise SystemExit('fixture must have only workflow_dispatch trigger')
PY

tmp_dir="$(mktemp -d /tmp/253-canary-freeze-test.XXXXXX)"
jq '.identity.candidate_helper_commit="1111111111111111111111111111111111111111"' "$FREEZE" > "$tmp_dir/wrong-sha.json"
jq '.identity.fixture_ref="refs/heads/gsd/253-gate-canary-fixture-20261013T044113Z-67104"' "$FREEZE" > "$tmp_dir/old-ref.json"
jq '.bounds.max_requests=121' "$FREEZE" > "$tmp_dir/over-budget.json"
for freeze in "$tmp_dir/wrong-sha.json" "$tmp_dir/old-ref.json" "$tmp_dir/over-budget.json"; do
  if bash "$SCRIPT" --check-only --recovery-freeze "$freeze" >/dev/null 2>&1; then
    echo "freeze mutation unexpectedly accepted: $freeze" >&2
    exit 1
  fi
done
# Exercise the real startup path with a sealed frozen candidate, no new evidence,
# and the old Phase 253-07 preflight files/ref already present. The fake gh only
# serves fresh, bounded preflight GETs; --preflight-only must stop before any
# local/remote fixture-ref mutation or workflow dispatch.
repo_dir="$tmp_dir/repo"
git clone --quiet --shared "$ROOT" "$repo_dir"
mkdir -p "$repo_dir/scripts/ci" "$repo_dir/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks" "$tmp_dir/bin"
for file in scripts/ci/ci-gate-canary.sh scripts/ci/ci-gate-canary.test.sh scripts/ci/ci-hosted-gate-verify.py scripts/ci/ci-browser-records.mjs scripts/ci/honest-skip-verdict.sh; do
  mkdir -p "$repo_dir/$(dirname "$file")"
  cp "$ROOT/$file" "$repo_dir/$file"
done
git -C "$ROOT" show HEAD:scripts/ci/ci-gate-canary.sh > "$repo_dir/scripts/ci/ci-gate-canary.sh"
cp -R "$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/." "$repo_dir/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
phase_dir="$repo_dir/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
jq -n '{schema_version:"sigra.hosted-gate-canary/v1",budget:{request_count:0},transport_ledger:{transactions:[]},diagnostics:[]}' > "$phase_dir/253-TEST-EVIDENCE.json"
if bash "$repo_dir/scripts/ci/ci-gate-canary.sh" --scenario invalid \
  --recovery-freeze "$phase_dir/253-RECOVERY-CANARY-FREEZE.json" \
  --evidence "$phase_dir/253-TEST-EVIDENCE.json" >/dev/null 2>&1; then
  echo 'invalid scenario unexpectedly passed' >&2
  exit 1
fi
jq -e '.status=="halted" and (.diagnostics|length)==1' "$phase_dir/253-TEST-EVIDENCE.json" >/dev/null
rm -f "$phase_dir/253-TEST-EVIDENCE.json"
jq --arg runner "$(shasum -a 256 "$repo_dir/scripts/ci/ci-gate-canary.sh" | awk '{print $1}')" \
   --arg shell_test "$(shasum -a 256 "$repo_dir/scripts/ci/ci-gate-canary.test.sh" | awk '{print $1}')" \
   --arg verifier "$(shasum -a 256 "$repo_dir/scripts/ci/ci-hosted-gate-verify.py" | awk '{print $1}')" \
   --arg python_test "$(shasum -a 256 "$repo_dir/scripts/ci/ci-hosted-gate-verify.test.py" | awk '{print $1}')" \
  '.source_sha256["scripts/ci/ci-gate-canary.sh"]=$runner | .source_sha256["scripts/ci/ci-gate-canary.test.sh"]=$shell_test | .source_sha256["scripts/ci/ci-hosted-gate-verify.py"]=$verifier | .source_sha256["scripts/ci/ci-hosted-gate-verify.test.py"]=$python_test' \
  "$test_freeze" > "$phase_dir/253-RECOVERY-CANARY-FREEZE.json"
printf 'historical-rate-bytes\n' > "$phase_dir/253-CANARY-PREFLIGHT-rate.json"
printf 'historical-rules-bytes\n' > "$phase_dir/253-CANARY-PREFLIGHT-effective-rules.json"
printf 'historical-workflow-bytes\n' > "$phase_dir/253-CANARY-PREFLIGHT-registered-workflow.json"
git -C "$repo_dir" update-ref refs/gsd/phase253-07-canary-preflight \
  "$(git -C "$repo_dir" hash-object -w "$phase_dir/253-CANARY-PREFLIGHT-effective-rules.json")"
old_ref_before="$(git -C "$repo_dir" rev-parse refs/gsd/phase253-07-canary-preflight)"
for pair in "rate:253-CANARY-PREFLIGHT-rate.json" "rules:253-CANARY-PREFLIGHT-effective-rules.json" "workflow:253-CANARY-PREFLIGHT-registered-workflow.json"; do
  IFS=: read -r key name <<< "$pair"
  shasum -a 256 "$phase_dir/$name" > "$tmp_dir/old-$key.sha"
done
cat > "$tmp_dir/bin/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == auth && "${2:-}" == token ]]; then printf 'mock-token-that-must-not-be-recorded'; exit 0; fi
[[ "${1:-}" == api ]] || exit 2
case "${2:-}" in
  rate_limit)
    jq -n '{resources:{core:{limit:5000,remaining:4999,reset:1791867469}}}'
    ;;
  'repos/szTheory/sigra/rulesets?includes_parents=true')
    cat "$MOCK_RULES"
    ;;
  repos/szTheory/sigra/actions/workflows/259268962)
    cat "$MOCK_WORKFLOW"
    ;;
  *) echo "unexpected mocked GitHub request: $*" >&2; exit 2 ;;
esac
MOCK_GH
chmod +x "$tmp_dir/bin/gh"
MOCK_RULES="$tmp_dir/fresh-rules.json"
MOCK_WORKFLOW="$tmp_dir/fresh-workflow.json"
cp /tmp/sigra-253-effective-rules.json "$MOCK_RULES"
cp /tmp/sigra-253-registered-workflow.json "$MOCK_WORKFLOW"
PATH="$tmp_dir/bin:$PATH" MOCK_RULES="$MOCK_RULES" MOCK_WORKFLOW="$MOCK_WORKFLOW" \
  bash "$repo_dir/scripts/ci/ci-gate-canary.sh" --preflight-only \
  --recovery-freeze "$phase_dir/253-RECOVERY-CANARY-FREEZE.json" \
  --evidence "$phase_dir/253-RECOVERY-CANARY-EVIDENCE.json" \
  --requests "$phase_dir/253-RECOVERY-CANARY-REQUESTS.json"
for pair in "rate:253-CANARY-PREFLIGHT-rate.json" "rules:253-CANARY-PREFLIGHT-effective-rules.json" "workflow:253-CANARY-PREFLIGHT-registered-workflow.json"; do
  IFS=: read -r key name <<< "$pair"
  shasum -a 256 -c "$tmp_dir/old-$key.sha" >/dev/null
done
[[ "$(git -C "$repo_dir" rev-parse refs/gsd/phase253-07-canary-preflight)" == "$old_ref_before" ]]
[[ "$(jq -r '.budget.request_count' "$phase_dir/253-RECOVERY-CANARY-EVIDENCE.json")" == 3 ]]
[[ "$(jq -r '.transactions | length' "$phase_dir/253-RECOVERY-CANARY-REQUESTS.json")" == 3 ]]
[[ "$(jq -r '[.transactions[].status] | all(. == 200)' "$phase_dir/253-RECOVERY-CANARY-REQUESTS.json")" == true ]]
[[ -f "$phase_dir/253-RECOVERY-CANARY-PREFLIGHT-rate.json" ]]
[[ -f "$phase_dir/253-RECOVERY-CANARY-PREFLIGHT-effective-rules.json" ]]
[[ -f "$phase_dir/253-RECOVERY-CANARY-PREFLIGHT-registered-workflow.json" ]]
[[ ! -e "$phase_dir/253-RECOVERY-CANARY-RUNS.json" ]]
[[ ! -e "$phase_dir/253-RECOVERY-CANARY-TRANSPORT.json" ]]
[[ -z "$(git -C "$repo_dir" status --porcelain -- .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json)" ]]

echo 'ci-gate-canary tests passed'
