#!/usr/bin/env node
// Same-run coverage guard. Hosted origin is checked independently in plan 253-07.
import { readFileSync, lstatSync, realpathSync, readdirSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, relative, sep, basename, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeReport } from './ci-playwright-report.mjs';

export const SEAMS = ['non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase'];
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const identityKeys = ['run_id', 'run_attempt', 'source_sha', 'event', 'workflow_ref', 'workflow_sha', 'classifier_result', 'docs_only'];
function requireValue(condition, message) { if (!condition) throw new Error(message); }
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

function confinedDocument(directory, path) {
  requireValue(typeof path === 'string' && path.length > 0 && !path.includes('\\') &&
    !path.split('/').some((part) => part === '..' || part === '' || part === '.'), 'unsafe report path');
  const anchor = realpathSync(directory);
  requireValue(!lstatSync(directory).isSymbolicLink(), 'symlink directory');
  const destination = resolve(anchor, path);
  requireValue(relative(anchor, destination) !== '' && !relative(anchor, destination).startsWith(`..${sep}`) &&
    !relative(anchor, destination).startsWith('/'), 'report path outside seam directory');
  let segment = anchor;
  for (const part of relative(anchor, destination).split(sep)) {
    segment = resolve(segment, part);
    requireValue(!lstatSync(segment).isSymbolicLink(), 'symlink report path');
  }
  const stat = lstatSync(destination);
  requireValue(stat.isFile() && stat.size > 0 && stat.size <= 64 * 1024 * 1024, 'empty or oversized report');
  const bytes = readFileSync(destination);
  return { value: JSON.parse(bytes.toString('utf8')), bytes };
}

function confinedJSON(directory, path) {
  return confinedDocument(directory, path).value;
}

export function bodyPolicy(seam, event, workflow = readFileSync(resolve(root, '.github/workflows/ci.yml'), 'utf8')) {
  requireValue(SEAMS.includes(seam), 'unknown seam');
  const shard = workflow.split('  example_playwright_shard:', 2)[1]?.split('\n  example_playwright_smoke:', 2)[0];
  requireValue(shard, 'browser workflow producer missing');
  const id = seam === 'design_gallery' && event !== 'pull_request' ? 'design_gallery_snapshots' : seam === 'design_gallery' ? 'design_gallery' : seam;
  const body = shard.split(/\n {6}- /).find((part) => new RegExp(`^ {8}id: ${id}\\s*$`, 'm').test(part));
  requireValue(body, `selected body ${id} missing`);
  const invocations = body.split('SIGRA_PLAYWRIGHT_JSON=').slice(1).map((command) => {
    const path = basename(command.split(/\s+/)[0]);
    const specs = [...new Set([...command.matchAll(/tests\/([\w.-]+\.spec\.ts)/g)].map((match) => match[1]))].sort();
    let projects = [...new Set([...command.matchAll(/--project=([\w-]+)/g)].map((match) => match[1]))].sort();
    if (projects.length === 0 && seam === 'non_admin_smoke') projects = ['chromium', 'mobile'];
    requireValue(specs.length > 0 && projects.length > 0 && path.endsWith('.json'), 'selected invocation invalid');
    return { path, selection_path: path.replace(/\.json$/, '.selection.json'), specs, projects };
  });
  requireValue(invocations.length === (id === 'design_gallery_snapshots' ? 2 : 1), 'selected invocation count drift');
  return [{ id, invocations }];
}

function selectionRows(report) {
  requireValue(report && Array.isArray(report.suites) && Array.isArray(report.config?.projects), 'invalid selection shape');
  const projects = new Map(report.config.projects.map((project) => [project.id, project.name]));
  requireValue(projects.size === report.config.projects.length, 'duplicate selection project');
  const selected = [];
  function visit(suites, parent = []) {
    requireValue(Array.isArray(suites), 'invalid selection suites');
    for (const suite of suites) {
      const path = [...parent, suite.title];
      for (const spec of suite.specs ?? []) {
        requireValue(typeof spec.id === 'string' && typeof spec.title === 'string' && typeof spec.file === 'string' &&
          Array.isArray(spec.tests), 'invalid selected spec');
        for (const entry of spec.tests) {
          requireValue(projects.get(entry.projectId) === entry.projectName, 'selected project identity mismatch');
          selected.push({ id: JSON.stringify([entry.projectId, spec.file.replaceAll('\\', '/'), path, spec.id, spec.title]),
            project: entry.projectName, file: spec.file, expected_status: entry.expectedStatus });
        }
      }
      if (suite.suites) visit(suite.suites, path);
    }
  }
  visit(report.suites);
  requireValue(selected.length > 0 && new Set(selected.map((row) => row.id)).size === selected.length, 'empty or duplicate selection');
  return selected;
}

function validateSelection(rows, policy, seam) {
  const files = new Set();
  for (const row of rows) {
    requireValue(row.file === basename(row.file) || row.file === `tests/${basename(row.file)}`, 'unexpected spec path');
    const file = basename(row.file);
    const setup = seam === 'design_gallery' && file === 'admin-design.setup.ts' &&
      policy.projects.some((project) => row.project === project.replace('admin-design-', 'admin-design-setup-'));
    requireValue(setup || policy.specs.includes(file) && policy.projects.includes(row.project), 'wrong selected spec or project');
    requireValue(!(row.project === 'mobile' && /^(passkeys-hooks|passkey-login|passkey-options)\.spec\.ts$/.test(file)), 'CDP-only spec selected in mobile');
    files.add(file);
  }
  for (const file of policy.specs) requireValue(files.has(file), `selected spec absent: ${file}`);
  for (const project of policy.projects) requireValue(rows.some((row) => row.project === project), `selected project absent: ${project}`);
  if (seam === 'design_gallery') for (const project of policy.projects) {
    requireValue(rows.some((row) => basename(row.file) === 'admin-design.setup.ts' &&
      row.project === project.replace('admin-design-', 'admin-design-setup-')), 'design authentication dependency absent');
  }
}

function readCoverageJSON(directory, path) {
  return confinedJSON(directory, path);
}

function coverageIdentity(row) {
  return JSON.stringify([row.project_id, row.spec_file, row.suite_path, row.native_spec_id, row.title]);
}

/** Normalize native report rows without reducing coverage to a count. */
export function normalizedProductRows(report, { seam, invocation }) {
  const normalized = normalizeReport(report, { seam, invocation });
  requireValue(normalized.complete && normalized.tests.length > 0,
    `native report incomplete: ${normalized.incomplete_reasons.join(',')}`);
  const expected = new Map(selectionRows(report).map((row) => [row.id, row.expected_status]));
  const rows = normalized.tests.map((row) => {
    const native = JSON.parse(row.test_id);
    requireValue(row.retry === null || row.retry === 0, `native coverage report contains retries: ${row.test_id}`);
    return {
    id: JSON.stringify(native),
    native_spec_id: native[3],
    project: row.project,
    project_id: row.project_id,
    spec: row.spec_file,
    title_path: row.suite_path,
    title: row.title,
    expected_status: expected.get(row.test_id),
    actual_result: row.result,
    selected: true,
    classification: 'product',
  }; });
  requireValue(new Set(rows.map((row) => row.id)).size === rows.length, 'duplicate native product identity');
  return rows;
}

function verifyCoverageSource(directory) {
  requireValue(!lstatSync(directory).isSymbolicLink(), 'symlink coverage source directory');
  const descriptor = readCoverageJSON(directory, 'coverage-source.json');
  requireValue(descriptor?.schema_version === 'sigra.browser-coverage-source/v1', 'coverage source schema mismatch');
  requireValue(/^[0-9a-f]{40}$/.test(descriptor.source_sha ?? ''), 'coverage source revision missing');
  for (const key of ['workflow_sha256', 'configuration_sha256', 'lock_sha256'])
    requireValue(/^[0-9a-f]{64}$/.test(descriptor[key] ?? ''), `coverage source digest missing: ${key}`);
  requireValue(SEAMS.includes(descriptor.seam) && descriptor.owner === descriptor.seam, 'coverage source owner mismatch');
  requireValue(['pull_request', 'push', 'schedule', 'workflow_dispatch'].includes(descriptor.event), 'coverage source event invalid');
  requireValue(Array.isArray(descriptor.project_inventory) && descriptor.project_inventory.length > 0 &&
    new Set(descriptor.project_inventory).size === descriptor.project_inventory.length, 'coverage project inventory invalid');
  requireValue(Array.isArray(descriptor.selected_inventory) && descriptor.selected_inventory.length > 0,
    'coverage selected inventory missing');
  requireValue(Array.isArray(descriptor.excluded_inventory) && descriptor.excluded_inventory.every((row) =>
    row && Array.isArray(row.identity) && row.identity.length === 5 && typeof row.owner === 'string' && typeof row.reason === 'string'),
  'coverage excluded inventory invalid');
  requireValue(Array.isArray(descriptor.reports) && descriptor.reports.length > 0, 'coverage native report references missing');
  const nativeRows = [];
  for (const ref of descriptor.reports) {
    requireValue(typeof ref.path === 'string' && typeof ref.selection_path === 'string', 'coverage native report reference invalid');
    requireValue(ref.source_sha === descriptor.source_sha, 'coverage report source origin mismatch');
    const reportDoc = confinedDocument(directory, ref.path);
    const selectionDoc = confinedDocument(directory, ref.selection_path);
    const report = reportDoc.value;
    const selection = selectionDoc.value;
    for (const [path, key, bytes] of [[ref.path, 'sha256', reportDoc.bytes], [ref.selection_path, 'selection_sha256', selectionDoc.bytes]])
      requireValue(/^[0-9a-f]{64}$/.test(ref[key] ?? '') && digest(bytes) === ref[key], `coverage report digest mismatch: ${path}`);
    const selected = selectionRows(selection);
    const actual = normalizedProductRows(report, { seam: descriptor.seam, invocation: ref.path });
    requireValue(actual.length > 0 && selected.length > 0, 'empty coverage selection or native result');
    const selectedPairs = new Set(selected.map((row) => row.id));
    const actualPairs = new Set(actual.map((row) => row.id));
    requireValue(selectedPairs.size === selected.length && actualPairs.size === actual.length, 'duplicate selection or native coverage identity');
    requireValue(JSON.stringify([...selectedPairs].sort()) === JSON.stringify([...actualPairs].sort()),
      'native report product identities differ from source selection');
    requireValue(selected.every((row) => descriptor.project_inventory.includes(row.project)), 'selected project absent from pinned project inventory');
    nativeRows.push(...actual);
  }
  const inventory = descriptor.selected_inventory;
  requireValue(inventory.every((row) => row && typeof row.id === 'string' && typeof row.owner === 'string' &&
    ['product', 'setup', 'intentional_skip'].includes(row.classification)), 'selected coverage inventory malformed');
  requireValue(Array.isArray(descriptor.skip_policies), 'source-bound intentional skip policies missing');
  const policies = new Map();
  for (const policy of descriptor.skip_policies) {
    requireValue(policy && typeof policy.id === 'string' && typeof policy.owner === 'string' &&
      typeof policy.selector === 'string' && policy.selector.length > 0 && Array.isArray(policy.identities) &&
      policy.identities.length > 0, 'intentional skip policy malformed');
    const expectedDigest = policy.source_path === '.github/workflows/ci.yml' ? descriptor.workflow_sha256
      : policy.source_path === 'test/example/priv/playwright/playwright.config.ts' ? descriptor.configuration_sha256 : null;
    requireValue(expectedDigest && policy.source_sha256 === expectedDigest, 'intentional skip policy source origin mismatch');
    requireValue(!policies.has(policy.id), 'duplicate intentional skip policy identity');
    policies.set(policy.id, policy);
  }
  requireValue(new Set(inventory.map((row) => row.id)).size === inventory.length, 'duplicate pinned selection inventory identity');
  const inventoryById = new Map(inventory.map((row) => [row.id, row]));
  const rows = nativeRows.map((row) => {
    const match = inventoryById.get(row.id);
    requireValue(match && match.owner === descriptor.owner, `native product row missing from pinned inventory: ${row.id}`);
    if (match.classification === 'intentional_skip') {
      const policy = policies.get(match.policy_id);
      requireValue(policy && policy.owner === match.owner && policy.identities.includes(row.id),
        `intentional skip has no source-bound identity policy: ${row.id}`);
      requireValue(row.expected_status === 'skipped' && row.actual_result === 'skipped', `intentional skip policy changed: ${row.id}`);
    }
    return { ...row, owner: match.owner, classification: match.classification };
  });
  requireValue(rows.length === inventory.length, 'pinned selection inventory and native reports differ');
  return { descriptor, rows, productRows: rows.filter((row) => row.classification !== 'setup'),
    setupRows: rows.filter((row) => row.classification === 'setup') };
}

/** Compare source-bound native product identities, outcomes and ownership mapping. */
export function compareProductCoverage(beforeDirectory, afterDirectory, mappingPath) {
  const before = verifyCoverageSource(beforeDirectory);
  const after = verifyCoverageSource(afterDirectory);
  requireValue(before.descriptor.event === after.descriptor.event, 'coverage comparison event changed');
  const excluded = (source) => source.descriptor.excluded_inventory.map((row) => JSON.stringify(row)).sort();
  requireValue(JSON.stringify(excluded(before)) === JSON.stringify(excluded(after)), 'excluded workload identity or reason changed');
  const mapping = JSON.parse(readFileSync(mappingPath, 'utf8'));
  requireValue(mapping?.schema_version === 'sigra.browser-coverage-map/v1' && Array.isArray(mapping.rows), 'coverage mapping schema invalid');
  const products = mapping.rows.filter((row) => row.kind === 'product');
  const setup = mapping.rows.filter((row) => row.kind === 'setup');
  requireValue(products.length + setup.length === mapping.rows.length, 'unmapped or unsupported coverage classification');
  const mappedBefore = products.map((row) => JSON.stringify(row.before));
  const mappedAfter = products.map((row) => JSON.stringify(row.after));
  requireValue(new Set(mappedBefore).size === mappedBefore.length && new Set(mappedAfter).size === mappedAfter.length,
    'duplicate product ownership mapping');
  const beforeByIdentity = new Map(before.rows.map((row) => [row.id, row]));
  const afterByIdentity = new Map(after.rows.map((row) => [row.id, row]));
  requireValue(beforeByIdentity.size === before.rows.length && afterByIdentity.size === after.rows.length, 'duplicate source product identity');
  const differences = [];
  for (const row of products) {
    requireValue(Array.isArray(row.before) && row.before.length === 5 && Array.isArray(row.after) && row.after.length === 5 &&
      typeof row.owner === 'string', 'product mapping row malformed');
    const left = beforeByIdentity.get(JSON.stringify(row.before));
    const right = afterByIdentity.get(JSON.stringify(row.after));
    if (!left || !right) { differences.push({ before: row.before, after: row.after, reason: !left ? 'before_missing' : 'after_missing' }); continue; }
    if (left.classification !== right.classification || left.expected_status !== right.expected_status || left.actual_result !== right.actual_result)
      differences.push({ before: row.before, after: row.after, reason: 'status_or_classification_changed',
        before_status: left.actual_result, after_status: right.actual_result,
        before_classification: left.classification, after_classification: right.classification });
    if (left.owner !== row.owner || right.owner !== row.owner)
      differences.push({ before: row.before, after: row.after, reason: 'owner_mismatch', owner: row.owner });
  }
  const mappedBeforeSet = new Set(mapping.rows.map((row) => JSON.stringify(row.before)));
  const mappedAfterSet = new Set(mapping.rows.map((row) => JSON.stringify(row.after)));
  for (const row of before.rows) if (!mappedBeforeSet.has(row.id)) differences.push({ identity: row.id, reason: 'before_unmapped' });
  for (const row of after.rows) if (!mappedAfterSet.has(row.id)) differences.push({ identity: row.id, reason: 'after_unmapped' });
  requireValue(differences.length === 0, `product coverage differs: ${JSON.stringify(differences)}`);
  requireValue(before.setupRows.length === setup.length && after.setupRows.length === setup.length,
    'setup/dependency rows are not mapped separately from product coverage');
  return { status: 'passed', before_rows: before.productRows.length, after_rows: after.productRows.length,
    before_setup_rows: before.setupRows.length, after_setup_rows: after.setupRows.length,
    before_source: before.descriptor.source_sha, after_source: after.descriptor.source_sha, differences };
}

function validateIdentity(identity) {
  requireValue(identity && /^[1-9][0-9]*$/.test(identity.run_id) && /^[1-9][0-9]*$/.test(identity.run_attempt), 'invalid run identity');
  requireValue(/^[0-9a-f]{40}$/.test(identity.source_sha) && /^[0-9a-f]{40}$/.test(identity.workflow_sha), 'invalid source identity');
  requireValue(['pull_request', 'push', 'schedule', 'workflow_dispatch'].includes(identity.event), 'invalid event');
  requireValue(typeof identity.workflow_ref === 'string' && identity.workflow_ref.startsWith('szTheory/sigra/.github/workflows/ci.yml@'), 'invalid workflow identity');
  for (const key of identityKeys) requireValue(typeof identity[key] === 'string', `identity missing: ${key}`);
}

export function verifySeam(directory, identity, seam, nativeResult) {
  validateIdentity(identity);
  requireValue(nativeResult === 'success', 'native producer result is not success');
  const record = confinedJSON(directory, 'execution-record.json');
  requireValue(record.schema_version === 'sigra.browser-execution-record/v1' && record.seam === seam, 'record schema or seam mismatch');
  requireValue(record.workflow_file_sha256 === digest(readFileSync(resolve(root, '.github/workflows/ci.yml'))), 'record workflow file mismatch');
  for (const key of identityKeys) requireValue(record[key] === identity[key], `record identity mismatch: ${key}`);
  const expected = bodyPolicy(seam, identity.event);
  requireValue(Array.isArray(record.selected_steps) && record.selected_steps.length === expected.length, 'selected step count mismatch');
  const docsOnly = identity.event === 'pull_request' && identity.classifier_result === 'success' && identity.docs_only === 'true';
  for (const [index, policy] of expected.entries()) {
    const step = record.selected_steps[index];
    requireValue(step.id === policy.id, 'selected step identity mismatch');
    requireValue(step.outcome === (docsOnly ? 'skipped' : 'success') && step.conclusion === step.outcome, 'selected native step did not succeed or legitimately skip');
    requireValue(Array.isArray(step.reports), 'reports are not an array');
    if (docsOnly) { requireValue(step.reports.length === 0, 'docs-only body has unexpected reports'); continue; }
    requireValue(step.reports.length === policy.invocations.length, 'native report count mismatch');
    for (const [position, invocation] of policy.invocations.entries()) {
      const reference = step.reports[position];
      requireValue(reference.path === invocation.path && reference.selection_path === invocation.selection_path, 'native report selection path mismatch');
      const report = confinedJSON(directory, reference.path);
      const selection = confinedJSON(directory, reference.selection_path);
      for (const [path, hash] of [[reference.path, reference.sha256], [reference.selection_path, reference.selection_sha256]]) {
        requireValue(typeof hash === 'string' && /^[0-9a-f]{64}$/.test(hash) && digest(readFileSync(resolve(directory, path))) === hash, 'native report hash mismatch');
      }
      const wanted = selectionRows(selection);
      validateSelection(wanted, invocation, seam);
      const normalized = normalizeReport(report, { seam, invocation: reference.path });
      requireValue(normalized.complete && normalized.tests.length > 0, `native report incomplete: ${normalized.incomplete_reasons.join(',')}`);
      requireValue(normalized.tests.some((row) => row.result === 'passed') && normalized.tests.every((row) =>
        (row.retry === 0 && row.result === 'passed') || (row.retry === null && row.result === 'skipped')), 'native tests failed or retried');
      const actual = normalized.tests.map((row) => row.test_id).sort();
      requireValue(JSON.stringify(actual) === JSON.stringify(wanted.map((row) => row.id).sort()), 'native selected test set mismatch');
      const expectation = (rows) => rows.map((row) => [row.id, row.expected_status]).sort((a, b) => a[0].localeCompare(b[0]));
      requireValue(JSON.stringify(expectation(selectionRows(report))) === JSON.stringify(expectation(wanted)), 'native expected status changed after selection');
    }
  }
  return { status: 'passed', seam, docs_only: docsOnly };
}

export function verifyDirectory(directory, identity, nativeResult) {
  validateIdentity(identity);
  requireValue(nativeResult === 'success', 'native matrix result is not success');
  requireValue(!lstatSync(directory).isSymbolicLink(), 'symlink aggregate directory');
  const names = readdirSync(directory, { withFileTypes: true }).filter((entry) => entry.isDirectory() || entry.isSymbolicLink()).map((entry) => entry.name).sort();
  const expected = SEAMS.map((seam) => `browser-execution-${seam}-${identity.run_id}-${identity.run_attempt}`).sort();
  requireValue(JSON.stringify(names) === JSON.stringify(expected), 'missing duplicate unknown or wrong-identity producer directory');
  const seams = SEAMS.map((seam) => verifySeam(resolve(directory, `browser-execution-${seam}-${identity.run_id}-${identity.run_attempt}`), identity, seam, nativeResult));
  return { status: 'passed', seams };
}

function recordProducer(output, reportsDirectory, seam) {
  const identity = { run_id: process.env.GITHUB_RUN_ID, run_attempt: process.env.GITHUB_RUN_ATTEMPT,
    source_sha: process.env.GITHUB_SHA, event: process.env.GITHUB_EVENT_NAME,
    workflow_ref: process.env.GITHUB_WORKFLOW_REF, workflow_sha: process.env.GITHUB_WORKFLOW_SHA,
    classifier_result: process.env.CLASSIFIER_RESULT ?? '', docs_only: process.env.DOCS_ONLY ?? '' };
  validateIdentity(identity);
  const steps = JSON.parse(process.env.SELECTED_STEPS_JSON ?? '{}');
  const record = { schema_version: 'sigra.browser-execution-record/v1', ...identity, seam,
    workflow_file_sha256: digest(readFileSync(resolve(root, '.github/workflows/ci.yml'))), selected_steps: [], missing_details: [] };
  mkdirSync(output, { recursive: true });
  requireValue(!lstatSync(output).isSymbolicLink(), 'symlink record output');
  const docsOnly = identity.event === 'pull_request' && identity.classifier_result === 'success' && identity.docs_only === 'true';
  for (const policy of bodyPolicy(seam, identity.event)) {
    const observed = steps[policy.id] ?? {};
    const step = { id: policy.id, outcome: observed.outcome ?? null, conclusion: observed.conclusion ?? null, reports: [] };
    if (!docsOnly) for (const invocation of policy.invocations) {
      const reference = { path: invocation.path, selection_path: invocation.selection_path };
      for (const path of [invocation.path, invocation.selection_path]) {
        try {
          confinedJSON(reportsDirectory, path);
          const bytes = readFileSync(resolve(reportsDirectory, path));
          requireValue(!existsSync(resolve(output, path)) || !lstatSync(resolve(output, path)).isSymbolicLink(), 'symlink record report output');
          writeFileSync(resolve(output, path), bytes, { mode: 0o600 });
          reference[path === invocation.path ? 'sha256' : 'selection_sha256'] = digest(bytes);
        } catch { record.missing_details.push(`report_missing_or_invalid:${path}`); }
      }
      step.reports.push(reference);
    }
    record.selected_steps.push(step);
  }
  requireValue(!existsSync(resolve(output, 'execution-record.json')) || !lstatSync(resolve(output, 'execution-record.json')).isSymbolicLink(), 'symlink record output file');
  writeFileSync(resolve(output, 'execution-record.json'), `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
  return { status: 'recorded', seam, missing_details: record.missing_details };
}

function main(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === '--verify' || argv[index] === '--record' || argv[index] === '--compare-coverage') {
      requireValue(args[argv[index]] === undefined, 'duplicate CLI argument');
      args[argv[index]] = true; continue;
    }
    requireValue(['--verify-seam', '--directory', '--identity', '--native-result', '--seam', '--reports-directory',
      '--before-directory', '--after-directory', '--mapping'].includes(argv[index]) && argv[index + 1], 'unknown or missing CLI argument');
    requireValue(args[argv[index]] === undefined, 'duplicate CLI argument');
    args[argv[index]] = argv[++index];
  }
  requireValue([args['--verify'], args['--verify-seam'], args['--record'], args['--compare-coverage']].filter(Boolean).length === 1, 'select one CLI mode');
  if (args['--compare-coverage']) {
    requireValue(args['--before-directory'] && args['--after-directory'] && args['--mapping'], 'coverage comparison requires before, after and mapping inputs');
    return compareProductCoverage(args['--before-directory'], args['--after-directory'], args['--mapping']);
  }
  if (args['--record']) return recordProducer(args['--directory'], args['--reports-directory'], args['--seam']);
  const identity = JSON.parse(readFileSync(args['--identity'], 'utf8'));
  if (args['--verify']) return verifyDirectory(args['--directory'], identity, args['--native-result']);
  return verifySeam(args['--directory'], identity, args['--verify-seam'], args['--native-result']);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.stdout.write(`${JSON.stringify(main(process.argv.slice(2)))}\n`); }
  catch (error) { process.stderr.write(`browser-execution: FAIL: ${error.message}\n`); process.exitCode = 1; }
}
