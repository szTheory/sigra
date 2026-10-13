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
for mode in --run-frozen --diagnose-setup --verify-controls --verify-acceptance; do
  "$RUNNER" "$mode" --help >/dev/null
done
echo 'registration runner modes: PASS'

node --test "$ROOT/scripts/ci/ci-registration-setup-diagnostic.test.mjs"

node - "$RUNNER" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const output = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-253-setup-entry-')), 'terminal.json');
try {
  fs.writeFileSync(output, '{"status":"terminal"}\n');
  const original = fs.readFileSync(output);
  const result = spawnSync(process.argv[2], ['--diagnose-setup', '--output', output], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.deepEqual(fs.readFileSync(output), original);
  console.log('setup-only runner preserves terminal evidence: PASS');
} finally {
  fs.rmSync(path.dirname(output), { recursive: true, force: true });
}
NODE

# Exercise the real verifier entrypoints, rather than their help output. Until
# native browser/control receipts exist, self-reported fields cannot pass.
node - "$RUNNER" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const runner = process.argv[2];
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sigra-registration-verifier-'));
try {
  for (const status of ['fixed', 'not_reproduced', 'diagnosis_incomplete']) {
    const evidence = {
      schema_version: 'sigra.phase253.registration-evidence/v1', status,
      projects: Array.from({ length: 3 }, () => ({ originalOutcome: 'failed' })),
      controls: {
        readiness: { delayed: { observed: true }, missing: { observedFailure: true }, brokenWait: { observedFailure: true } },
        stateCollision: { observedFailure: true },
        trace: { firstFailure: { assertionPresent: true }, passing: { artifactAbsent: true } }
      },
      fix: { freshRepeats: [true, true, true] },
      requirements: { 'CIREL-01': 'unsatisfied' }
    };
    const input = path.join(directory, `${status}.json`);
    fs.writeFileSync(input, JSON.stringify(evidence));
    const original = fs.readFileSync(input);
    for (const mode of ['--verify-controls', '--verify-acceptance']) {
      const result = spawnSync(runner, [mode, input], { encoding: 'utf8' });
      assert.equal(result.status, 3, `${mode} must reject self-reported ${status}: ${result.stdout} ${result.stderr}`);
      assert.match(result.stderr, /native browser and control receipts.*not implemented/);
      assert.deepEqual(fs.readFileSync(input), original, 'verifying must preserve evidence');
    }
  }
  console.log('registration verifiers reject forged claims: PASS (6 cases)');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
NODE
