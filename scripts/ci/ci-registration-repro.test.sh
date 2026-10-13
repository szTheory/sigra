#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/ci-registration-repro.sh"
FREEZE="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPRO-FREEZE.json"

node - "$FREEZE" <<'NODE'
const fs = require('node:fs');
const freeze = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const assert = require('node:assert/strict');
assert.equal(freeze.status, 'frozen_before_results');
assert.equal(freeze.source.checkout_head, 'de53d1c80f4a67b73a5e5078959c2c88ad75abe8');
assert.equal(freeze.source.historical_helper_blob, '6540493e78121f134867445dffc7010afcd85815');
assert.equal(freeze.source.current_helper_blob, freeze.source.historical_helper_blob);
assert.deepEqual(freeze.selection.projects, ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']);
assert.equal(freeze.selection.grep, 'render bundle: board-mg-9/populated');
assert.equal(freeze.selection.retries, 0);
assert.equal(freeze.selection.preceding_order_selection, false);
assert.equal(freeze.budgets.invocations_per_signature, 10);
assert.equal(freeze.budgets.minutes_per_signature, 20);
assert.equal(freeze.budgets.minutes_total, 60);
console.log('registration freeze: PASS');
NODE

test -x "$RUNNER" || { echo 'registration runner is missing or not executable' >&2; exit 1; }
for mode in --run-frozen --verify-controls --verify-acceptance; do
  "$RUNNER" "$mode" --help >/dev/null
done
echo 'registration runner modes: PASS'
