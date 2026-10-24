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
  const fetchIndex = job.search(/(?:run:\s+mix deps\.get|--invocation deps-get -- mix deps\.get)\s*$/m);
  const ciInvocation = /^\s+(?:run: mix ci|--invocation library-ci -- mix ci)\s*$/gm;
  const ciIndex = job.search(ciInvocation);
  assert.ok(fetchIndex >= 0 && fetchIndex < ciIndex, 'dependencies must be present before mix ci formats source on a cold cache');
  assert.equal((job.match(ciInvocation) ?? []).length, 1, 'the required library owner must invoke mix ci exactly once');
  assert.match(mixSource, /"deps\.get --check-locked"/, 'mix ci must retain locked dependency verification');
  assert.match(mixSource, /"deps\.unlock --check-unused"/, 'mix ci must retain the unused dependency check');
}

test('library job relies on pinned setup-beam defaults and its sole mix ci dependency owner', () => {
  assertLibrarySetupContract(readRepoFile(workflowPath));
  assert.match(libraryJob, /(?:run: mix ci|--invocation library-ci -- mix ci)/);
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
    mutateLibraryJob((job) => job.replace('--invocation library-ci -- mix ci', 'HEX_HOME: /tmp/hex\n          --invocation library-ci -- mix ci')),
    mutateLibraryJob((job) => job.replace('--invocation library-ci -- mix ci', '--invocation library-ci -- mix ci\n          --invocation library-ci -- mix ci')),
    mutateLibraryJob((job) => job.replace(/^          --invocation deps-get -- mix deps\.get\n/m, '')),
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

test('preparation parser accepts only the frozen sequential control treatment', () => {
  const combined = 'mix do deps.get + compile --warnings-as-errors + ecto.create + ecto.migrate + run priv/repo/seeds.exs';
  const sequential = "bash -c 'mix deps.get && mix compile --warnings-as-errors && mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs'";
  const controlAction = action.replaceAll(combined, sequential);
  assert.doesNotThrow(() => assertPreparationCacheContract(controlAction));
  const plan = buildPreparationCommands(controlAction);
  assert.equal(plan.combined, combined);
  assert.deepEqual(plan.selected, [sequential]);

  for (const mutation of [
    controlAction.replace('mix deps.get && mix compile', 'mix compile && mix deps.get'),
    controlAction.replace('mix ecto.migrate && mix run', 'mix run && mix ecto.migrate'),
    controlAction.replace(sequential, 'bash -c \'mix deps.get && mix compile --warnings-as-errors && mix ecto.create && mix ecto.migrate && mix test\''),
    controlAction.replace(sequential, 'echo skip preparation'),
  ]) assert.throws(() => buildPreparationCommands(mutation));
});

test('preparation comparison rejects source mutations that drop cache or cold-path safety', () => {
  const mutations = [
    action.replaceAll('inputs.app-port', 'inputs.default-port'),
    action.replace('restore-keys:', 'fallback-keys:'),
    action.replaceAll('npm ci', 'npm install'),
    action.replaceAll('ci-playwright-os-deps.py', 'skip-cached-OS-dependencies'),
    action.replaceAll('npx playwright install $BROWSERS', 'echo skip browser binaries'),
    action.replace('run priv/repo/seeds.exs', 'echo skip seeds'),
    action.replace('ecto.migrate', 'echo skip migrations'),
    action.replace('curl -sf "$BASE_URL/"', 'true'),
  ];
  mutations.forEach((mutated, index) => assert.throws(() => assertPreparationCacheContract(mutated), `cache/setup mutation ${index + 1} must fail`));
});
