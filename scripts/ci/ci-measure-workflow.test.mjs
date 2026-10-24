import test from 'node:test';
import assert from 'node:assert/strict';
import { readRepoFile, jobBlock, stripYamlComments } from './prohibitions/_lib.mjs';

const workflow = stripYamlComments(readRepoFile('.github/workflows/ci.yml'));
const playwrightConfig = readRepoFile('test/example/priv/playwright/playwright.config.ts');
const ids = [
  'library_tests_shard',
  'example_unit_smoke',
  'install_smoke',
  'example_http_smoke',
  'example_playwright_shard',
];
const blocks = Object.fromEntries(ids.map((id) => [id, jobBlock(workflow, id)]));

test('browser records travel through unique artifacts into the mandatory native verdict', () => {
  assert.ok(blocks.example_playwright_shard.includes('ci-browser-records.mjs --record'), 'browser producer must record actual selected outcomes');
  assert.ok(blocks.example_playwright_shard.includes('browser-execution-${{ matrix.seam }}-${{ github.run_id }}-${{ github.run_attempt }}'));
  assert.match(blocks.example_playwright_shard, /if-no-files-found: error/);
  const aggregate = jobBlock(workflow, 'example_playwright_smoke');
  assert.match(aggregate, /^    if: always\(\)$/m);
  assert.ok(aggregate.includes('actions/download-artifact@634f93cb2916e3fdff6788551b99b062d0335ce0'));
  assert.ok(aggregate.includes('ci-browser-records.mjs --verify'));
  assert.ok(aggregate.includes('--native-result "$SHARDS"'));
  assert.match(aggregate, /merge-multiple: false/);
});

function assertCompleteBrowserWiring(source) {
  const shard = jobBlock(source, 'example_playwright_shard');
  const aggregate = jobBlock(source, 'example_playwright_smoke');
  assert.ok(shard && aggregate, 'producer and aggregate must remain present');
  assert.match(shard, /id: browser_execution_record\s+if: always\(\)\s+env:/, 'all producers must record their terminal outcomes');
  assert.match(aggregate, /ci-browser-records\.mjs --verify \\/, 'aggregate must validate the complete set');
  assert.match(aggregate, /pattern: browser-execution-\*-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}/);
  assert.match(aggregate, /merge-multiple: false/);
  for (const path of ['admin-behavior', 'admin-checkpoints', 'design-gallery-pr-behavior',
    'design-gallery-nonpr-snapshots', 'design-gallery-nonpr-behavior', 'non-admin-smoke', 'demo-showcase']) {
    assert.ok(shard.includes(`--list --reporter=json > playwright-report/${path}.selection.json`), `${path} requires pre-execution inventory`);
  }
  assert.ok(shard.includes('CLASSIFIER_RESULT: ${{ needs.changes.result }}'));
  assert.ok(shard.includes('SELECTED_STEPS_JSON: ${{ toJSON(steps) }}'));
  assert.match(shard, /fail-fast: false/);
  assert.ok(aggregate.includes('--native-result "$SHARDS"'));
}

test('all five browser producers supply pre-execution inventory and native terminal outcomes', () => {
  assertCompleteBrowserWiring(workflow);
});

test('missing record, artifact, inventory or native dependency fails source wiring', () => {
  for (const malformed of [workflow.replace('id: browser_execution_record', 'id: missing_record'),
    workflow.replace('pattern: browser-execution-*', 'pattern: missing-records-*'),
    workflow.replace('--native-result "$SHARDS"', '--native-result "success"'),
    workflow.replace('demo-showcase.selection.json', 'missing-selection.json')]) {
    assert.throws(() => assertCompleteBrowserWiring(malformed));
  }
});

test('keeps one library mix ci owner and preserves required check names', () => {
  const owners = Object.entries(blocks).filter(([, block]) => /^\s+run: (?:MIX_ENV=test )?mix ci\s*$/m.test(block));
  assert.deepEqual(owners.map(([id]) => id), ['library_tests_shard']);
  assert.match(workflow, /^    name: Library tests\s+#?\s*$/m);
  for (const name of [
    'Library tests',
    'Example unit smoke (ExUnit + ConnTest)',
    'Install smoke (fresh phx.new + sigra.install)',
    'Example HTTP smoke (boot + curl critical routes)',
  ]) assert.ok(workflow.includes(name), `missing required check name ${name}`);
  assert.ok(workflow.includes('Example Playwright shard (${{ matrix.seam }})'));
});

test('records seven distinct Playwright reports without changing the five seam selections', () => {
  const invocations = [
    ['admin-behavior.json', 'tests/admin-user-operations.spec.ts', 'matrix.seam == \'admin_behavior\''],
    ['admin-checkpoints.json', 'tests/admin-checkpoints.spec.ts', 'matrix.seam == \'admin_checkpoints\''],
    ['design-gallery-pr-behavior.json', "--grep-invert '@snapshot'", "github.event_name == 'pull_request'"],
    ['design-gallery-nonpr-snapshots.json', "--grep '@snapshot'", "github.event_name != 'pull_request'"],
    ['design-gallery-nonpr-behavior.json', "--grep-invert '@snapshot'", "github.event_name != 'pull_request'"],
    ['non-admin-smoke.json', 'tests/golden-path.spec.ts', 'matrix.seam == \'non_admin_smoke\''],
    ['demo-showcase.json', 'tests/demo-showcase.spec.ts', 'matrix.seam == \'demo_showcase\''],
  ];
  const paths = [];
  for (const [path, selection, condition] of invocations) {
    const at = workflow.indexOf(path);
    assert.notEqual(at, -1, `missing report destination ${path}`);
    paths.push(path);
    const around = workflow.slice(Math.max(0, at - 1800), at + 3500);
    assert.ok(around.includes('SIGRA_PLAYWRIGHT_JSON'), `${path} is not wired to the opt-in reporter`);
    assert.ok(around.includes(selection), `${path} lost its selected test path/grep`);
    assert.ok(around.includes(condition), `${path} lost its event/seam guard`);
    assert.match(around, /--retries=0/);
  }
  assert.equal(new Set(paths).size, 7, 'report destinations must be unique per command');
  for (const seam of ['admin_behavior', 'admin_checkpoints', 'design_gallery', 'non_admin_smoke', 'demo_showcase']) {
    assert.ok(blocks.example_playwright_shard.includes(`- seam: ${seam}`), `missing matrix seam ${seam}`);
  }
  assert.match(playwrightConfig, /workers:\s*1/);
  assert.match(playwrightConfig, /retries:\s*0/);
});

test('uploads separate main and dependency-off timing reports from their producing job', () => {
  assert.match(blocks.library_tests_shard, /SIGRA_EXUNIT_TIMING_JSON: test-results\/ci-exunit-timing-main\.json/);
  assert.match(blocks.library_tests_shard, /SIGRA_EXUNIT_TIMING_INVOCATION: main/);
  assert.match(blocks.library_tests_shard, /SIGRA_EXUNIT_TIMING_THREADLINE_GUARD_JSON: test-results\/ci-exunit-timing-threadline-guard\.json/);
  assert.match(blocks.library_tests_shard, /run: (?:MIX_ENV=test )?mix ci/);
  const prepareTimingDirectory = blocks.library_tests_shard.indexOf('mkdir -p test-results');
  const contributorCi = blocks.library_tests_shard.indexOf('run: mix ci');
  assert.notEqual(prepareTimingDirectory, -1, 'library timing directory is not created');
  assert.ok(prepareTimingDirectory < contributorCi, 'timing directory must exist before mix ci writes ExUnit timing');
  assert.match(blocks.library_tests_shard, /if: always\(\)[\s\S]*?ci-exunit-timing-main\.json[\s\S]*?ci-exunit-timing-threadline-guard\.json/);
  assert.match(blocks.library_tests_shard, /invocation: 'main'[\s\S]*?invocation: 'threadline_guard'/);
  assert.match(blocks.library_tests_shard, /timing_artifact_name: `library-test-timing-\$\{process\.env\.GITHUB_RUN_ID\}-\$\{process\.env\.GITHUB_RUN_ATTEMPT\}`/);
  for (const [id, block] of Object.entries(blocks)) {
    assert.match(block, /ci-measurement-metadata\.json/, `${id} lacks metadata artifact`);
    assert.match(block, /if: always\(\)[\s\S]*?upload-artifact/, `${id} does not retain artifacts on failure`);
    for (const key of [
      'repository', 'run_id', 'run_attempt', 'source_sha', 'event', 'job_name', 'matrix_seam',
      'runner_os', 'runner_arch', 'runner_image', 'configured_versions', 'observed_versions',
      'version_unavailable',
    ]) assert.ok(block.includes(key), `${id} metadata omits ${key}`);
  }
});

test('metadata keeps configured pins separate from command-observed versions and cache results', () => {
  for (const [id, block] of Object.entries(blocks)) {
    assert.ok(block.includes('configured_versions'), `${id} missing configured pins`);
    assert.ok(block.includes('observed_versions'), `${id} missing actual version commands`);
    assert.ok(block.includes('version_unavailable'), `${id} must explain unavailable commands`);
    assert.ok(block.includes('ImageOS') && block.includes('ImageVersion'), `${id} missing runner image values`);
  }
  for (const [id, cache] of [
    ['library_tests_shard', 'deps_cache'],
    ['example_unit_smoke', 'example_unit_deps_cache'],
    ['install_smoke', 'install_smoke_deps_cache'],
    ['example_http_smoke', 'http_smoke_deps_cache'],
  ]) assert.ok(blocks[id].includes(`steps.${cache}.outputs.cache-hit`), `${id} cache output is not retained`);
  assert.ok(blocks.example_playwright_shard.includes('steps.boot.outputs.deps_cache_hit'));
  assert.ok(blocks.example_playwright_shard.includes('steps.boot.outputs.browser_cache_hit'));
  assert.match(blocks.example_playwright_shard, /node_modules\/\.bin\/playwright/);
  assert.match(blocks.example_playwright_shard, /capture\('elixir',\['--version'\]/);
  assert.match(blocks.example_playwright_shard, /capture\('node',\['--version'\]/);
});

test('captures native image identity before setup and rejects changes before artifact publication', () => {
  for (const [id, block] of Object.entries(blocks)) {
    assert.match(block, /runs-on: ubuntu-24\.04/);
    const early = block.indexOf('ci-runner-image.mjs capture --output');
    const setup = block.search(/uses: (?:erlef\/setup-beam|\.\/\.github\/actions\/example-playwright-boot)/);
    assert.ok(early >= 0 && setup > early, `${id} requires an early image record`);
    assert.ok(block.includes('verifyFromSystem(proof)'), `${id} must verify the initial file again`);
    assert.ok(block.includes("if(verification.status!=='verified')process.exitCode=1"));
    assert.ok(block.includes('source_proof:proof,verification'));
  }
});
