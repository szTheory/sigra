import assert from 'node:assert/strict';
import test from 'node:test';
import { jobBlock, readRepoFile, stripYamlComments } from './prohibitions/_lib.mjs';
import { assertPreparationCacheContract, buildPreparationCommands } from './ci-prep-profile.mjs';

const workflowPath = '.github/workflows/ci.yml';
const mixPath = 'mix.exs';
const workflow = stripYamlComments(readRepoFile(workflowPath));
const libraryJob = jobBlock(workflow, 'library_tests_shard');
const mixProject = readRepoFile(mixPath);
const action = readRepoFile('.github/actions/example-playwright-boot/action.yml');
const devConfig = readRepoFile('test/example/config/dev.exs');
const setupBeamPin = 'erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124';

function assertLibrarySetupContract(source, mixSource = mixProject) {
  const job = jobBlock(stripYamlComments(source), 'library_tests_shard');
  assert.ok(job, 'library_tests_shard must remain present');
  assert.equal((job.match(/uses: erlef\/setup-beam@/g) ?? []).length, 1, 'pinned setup-beam must remain exactly once');
  assert.ok(job.includes(setupBeamPin), 'setup-beam must retain the reviewed exact pin');
  assert.doesNotMatch(job, /install-hex:\s*false|install-rebar:\s*false/, 'setup-beam defaults must not be disabled');
  assert.doesNotMatch(job, /(?:^|\n)\s*(?:MIX_HOME|HEX_HOME):/, 'the job must not redirect tool homes after setup');
  assert.doesNotMatch(job, /mix local\.(?:hex|rebar)/, 'the job must not repeat setup-beam installs');
  const fetchIndex = job.indexOf('run: mix deps.get');
  const ciIndex = job.search(/^\s+run: mix ci\s*$/m);
  assert.ok(fetchIndex >= 0 && fetchIndex < ciIndex, 'dependencies must be present before mix ci formats source on a cold cache');
  assert.equal((job.match(/^\s+run: mix ci\s*$/gm) ?? []).length, 1, 'the required library owner must invoke mix ci exactly once');
  assert.match(mixSource, /"deps\.get --check-locked"/, 'mix ci must retain locked dependency verification');
  assert.match(mixSource, /"deps\.unlock --check-unused"/, 'mix ci must retain the unused dependency check');
}

test('library job relies on pinned setup-beam defaults and its sole mix ci dependency owner', () => {
  assertLibrarySetupContract(readRepoFile(workflowPath));
  assert.match(libraryJob, /run: mix ci/);
});

test('mix ci keeps seven ordered legs and records the three native test receivers', () => {
  const expected = [
    'format --check-formatted',
    'deps.get --check-locked',
    'deps.unlock --check-unused',
    'compile --warnings-as-errors',
    'ci-mix-receivers.py leg ordinary -- mix test --exclude scaffold',
    'ci-mix-receivers.py leg scaffold -- mix test test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs test/upgrade_test.exs',
    'ci-mix-receivers.py leg dep-off -- bash scripts/ci/sigra-dep-off.sh',
  ];
  let offset = -1;
  for (const command of expected) {
    const next = mixProject.indexOf(command, offset + 1);
    assert.ok(next > offset, `required ordered mix ci command missing: ${command}`);
    offset = next;
  }
  assert.equal((mixProject.match(/ci-mix-receivers\.py leg ordinary/g) ?? []).length, 1);
  assert.equal((mixProject.match(/ci-mix-receivers\.py leg scaffold/g) ?? []).length, 1);
  assert.equal((mixProject.match(/ci-mix-receivers\.py leg dep-off/g) ?? []).length, 1);
});

test('library setup contract rejects unique source mutations regardless of step label', () => {
  const mutateLibraryJob = (mutator) => workflow.replace(libraryJob, mutator(libraryJob));
  const variants = [
    mutateLibraryJob((job) => job.replace(setupBeamPin, 'erlef/setup-beam@other-pin')),
    mutateLibraryJob((job) => job.replace('      - name: Install phx_new archive', '      - name: unrelated setup label\n        run: mix local.hex --force\n      - name: Install phx_new archive')),
    mutateLibraryJob((job) => job.replace('        run: mix ci', '      env:\n        HEX_HOME: /tmp/hex\n        run: mix ci')),
    mutateLibraryJob((job) => job.replace('        run: mix ci', '        run: mix ci\n      - name: duplicate library owner\n        run: mix ci')),
    mutateLibraryJob((job) => job.replace(/      - name: Fetch library deps\n        run: mix deps.get\n/, '')),
  ];
  variants.forEach((variant, index) => assert.throws(() => assertLibrarySetupContract(variant), `invalid source mutation ${index + 1} must fail`));
  assert.throws(() => assertLibrarySetupContract(workflow, mixProject.replace('"deps.get --check-locked"', '"deps.get"')));
  assert.throws(() => assertLibrarySetupContract(workflow, mixProject.replace('"deps.unlock --check-unused"', '"compile"')));
});

test('preparation comparison preserves cache partitions, dependencies, readiness, and separate server boot', () => {
  assert.doesNotThrow(() => assertPreparationCacheContract(action));
  const plan = buildPreparationCommands(action);
  assert.deepEqual(plan.current, ['mix deps.get', 'mix compile --warnings-as-errors', 'mix ecto.create', 'mix ecto.migrate', 'mix run priv/repo/seeds.exs']);
  assert.equal(plan.combined, 'mix do deps.get + compile --warnings-as-errors + ecto.create + ecto.migrate + run priv/repo/seeds.exs');
  assert.ok(action.indexOf('run priv/repo/seeds.exs') < action.indexOf('- name: Boot example app'));
  assert.doesNotMatch(plan.combined, /mix phx\.server/);
  assert.match(devConfig, /dev_code_reloading\? = System\.get_env\("CI"\) not in \["true", "1"\]/);
  assert.match(devConfig, /code_reloader: dev_code_reloading\?/);
});

test('preparation comparison rejects source mutations that drop cache or cold-path safety', () => {
  const mutations = [
    action.replaceAll('inputs.app-port', 'inputs.default-port'),
    action.replace('restore-keys:', 'fallback-keys:'),
    action.replace('run: npm ci', 'run: npm install'),
    action.replace('ci-playwright-os-deps.py', 'skip-cached-OS-dependencies'),
    action.replace('npx playwright install $BROWSERS', 'echo skip browser binaries'),
    action.replace('run priv/repo/seeds.exs', 'echo skip seeds'),
    action.replace('ecto.migrate', 'echo skip migrations'),
    action.replace('curl -sf "$BASE_URL/"', 'true'),
  ];
  mutations.forEach((mutated, index) => assert.throws(() => assertPreparationCacheContract(mutated), `cache/setup mutation ${index + 1} must fail`));
});
