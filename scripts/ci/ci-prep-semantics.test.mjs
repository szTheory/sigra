import assert from 'node:assert/strict';
import test from 'node:test';
import { jobBlock, readRepoFile, stripYamlComments } from './prohibitions/_lib.mjs';

const workflowPath = '.github/workflows/ci.yml';
const mixPath = 'mix.exs';
const workflow = stripYamlComments(readRepoFile(workflowPath));
const libraryJob = jobBlock(workflow, 'library_tests_shard');
const mixProject = readRepoFile(mixPath);
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
