#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/ci-gate-canary.sh"
FIXTURE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-CANARY-WORKFLOW.yml"

help_output="$(bash "$SCRIPT" --help)"
[[ "$help_output" == *"full-pass"* && "$help_output" == *"cancelled"* ]]
bash "$SCRIPT" --check-only

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

echo 'ci-gate-canary tests passed'
