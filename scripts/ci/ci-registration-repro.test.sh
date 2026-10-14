#!/usr/bin/env bash
# Hermetic registration-runner entrypoint contracts (Phase 253, D-11).
#
# Runs in an ordinary clean candidate tree: no .planning records, no active GSD refs, no
# database, application server, browser or network. Native-looking evidence comes only from
# the labeled synthetic committed-tree fixture; recording stubs for every native command
# (mix, npm, playwright, psql, ...) reject and log any invocation, and the checks below fail
# if a single one was made.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/ci/ci-registration-repro.sh"
FIXTURE="$ROOT/scripts/ci/fixtures/registration-native-tree.mjs"

test -f "$FIXTURE" || { echo 'registration native-tree fixture is missing' >&2; exit 1; }

# Freeze contract: asserted on the synthetic committed tree, not on an active phase freeze.
node - "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const { spawnSync } = require('node:child_process');
(async () => {
  const { createRegistrationNativeTreeFixture, SELECTED_TITLE, SYNTHETIC_LABEL } = await import(pathToFileURL(process.argv[2]).href);
  const fixture = createRegistrationNativeTreeFixture({ label: 'shell-freeze' });
  try {
    const freeze = fixture.readFreeze();
    assert.equal(freeze.status, 'frozen_before_results');
    assert.equal(freeze.provenance.synthetic_native_fixture, SYNTHETIC_LABEL);
    const head = fixture.git(['rev-parse', 'HEAD']);
    assert.equal(spawnSync('git', ['-C', fixture.root, 'merge-base', '--is-ancestor', freeze.source.checkout_head, head]).status, 0);
    for (const [file, blob] of Object.entries(freeze.source.blobs)) {
      assert.equal(fixture.git(['rev-parse', `${freeze.source.checkout_head}:${file}`]), blob, `frozen blob for ${file}`);
    }
    assert.deepEqual(freeze.ledger.slots.map((slot) => slot.project), ['admin-eval', 'admin-eval-mobile']);
    for (const slot of freeze.ledger.slots) {
      assert.equal(slot.title, SELECTED_TITLE);
      assert.ok(slot.argv.includes(`--grep=${SELECTED_TITLE}`));
      assert.ok(slot.argv.includes('--retries=0'));
      assert.ok(slot.argv.includes('--workers=1'));
      assert.equal(slot.max_duration_ms, 120000);
    }
    assert.equal(freeze.ledger.d19.each_max_duration_ms, 120000);
    assert.equal(freeze.ledger.max_new_browser_launches, 18);
    assert.equal(freeze.ledger.max_charged_duration_ms, 58 * 60 * 1000);
    console.log('registration synthetic freeze: PASS');
  } finally { fixture.cleanup(); }
})().catch((error) => { console.error(error); process.exit(1); });
NODE

test -x "$RUNNER" || { echo 'registration runner is missing or not executable' >&2; exit 1; }
for mode in --run-frozen --diagnose-setup --verify-controls --verify-acceptance --verify-saved-native; do
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

# The shell entrypoint, driven from a temporary committed root with recording stubs for
# every native command: a labeled synthetic receipt verifies, corrupted ones do not, a run
# in a clean candidate is refused, and no setup/browser/database command is ever invoked.
node - "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
(async () => {
  const { createRegistrationNativeTreeFixture, SYNTHETIC_LABEL } = await import(pathToFileURL(process.argv[2]).href);
  const fixture = createRegistrationNativeTreeFixture({ label: 'shell-entry' });
  try {
    const verified = fixture.verify();
    assert.equal(verified.status, 0, `${verified.stdout}\n${verified.stderr}`);
    assert.match(verified.stdout, /2\/2 plan15 diagnostics; 2 launches; 32000 ms charged/);
    assert.ok(verified.stdout.includes(SYNTHETIC_LABEL), 'synthetic receipts must be labeled in verifier output');

    const accepted = fixture.verifySavedNative();
    assert.equal(accepted.status, 3, 'synthetic evidence must never satisfy the accepted-only audit');
    assert.match(accepted.stderr, /synthetic native fixture/i);

    for (const mutate of [
      (item) => { item.limits.browser_launches += 1; },
      (item) => { item.limits.used_slots = []; },
      (item) => { item.attempts[0].files.playwright_report = null; }
    ]) {
      const forged = createRegistrationNativeTreeFixture({ label: 'shell-forged' });
      try {
        forged.rewriteEvidence(mutate);
        const rejected = forged.verify();
        assert.equal(rejected.status, 3, `${rejected.stdout}\n${rejected.stderr}`);
        assert.doesNotMatch(rejected.stderr, /ENOENT|preserved config/);
        assert.deepEqual(forged.stubCalls(), []);
      } finally { forged.cleanup(); }
    }

    const output = path.join(fixture.base, 'run-output.json');
    const refused = fixture.run(['--run-revision', fixture.freezePath, '--slot', 'R-DIAG-DESKTOP', '--output', output]);
    assert.equal(refused.status, 3, `${refused.stdout}\n${refused.stderr}`);
    assert.equal(fs.existsSync(output), false);

    assert.deepEqual(fixture.stubCalls(), [], 'no setup, browser or database command may run');
    assert.equal(fixture.git(['status', '--porcelain']), '', 'the committed candidate stays clean');
    console.log('registration hermetic entrypoint contracts: PASS');
  } finally { fixture.cleanup(); }
})().catch((error) => { console.error(error); process.exit(1); });
NODE
