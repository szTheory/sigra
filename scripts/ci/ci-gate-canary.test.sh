#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/ci-gate-canary.sh"
FIXTURE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml"
FREEZE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json"

help_output="$(bash "$SCRIPT" --help)"
[[ "$help_output" == *"full-pass"* && "$help_output" == *"cancelled"* ]]
bash "$SCRIPT" --check-only --recovery-freeze "$FREEZE"
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
trap 'rm -rf "$tmp_dir"' EXIT
jq '.identity.candidate_helper_commit="1111111111111111111111111111111111111111"' "$FREEZE" > "$tmp_dir/wrong-sha.json"
jq '.identity.fixture_ref="refs/heads/gsd/253-gate-canary-fixture-20261013T044113Z-67104"' "$FREEZE" > "$tmp_dir/old-ref.json"
jq '.bounds.max_requests=121' "$FREEZE" > "$tmp_dir/over-budget.json"
for freeze in "$tmp_dir/wrong-sha.json" "$tmp_dir/old-ref.json" "$tmp_dir/over-budget.json"; do
  if bash "$SCRIPT" --check-only --recovery-freeze "$freeze" >/dev/null 2>&1; then
    echo "freeze mutation unexpectedly accepted: $freeze" >&2
    exit 1
  fi
done

echo 'ci-gate-canary tests passed'
