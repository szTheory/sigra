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

function confinedJSON(directory, path) {
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
  return JSON.parse(readFileSync(destination, 'utf8'));
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
    if (argv[index] === '--verify' || argv[index] === '--record') {
      requireValue(args[argv[index]] === undefined, 'duplicate CLI argument');
      args[argv[index]] = true; continue;
    }
    requireValue(['--verify-seam', '--directory', '--identity', '--native-result', '--seam', '--reports-directory'].includes(argv[index]) && argv[index + 1], 'unknown or missing CLI argument');
    requireValue(args[argv[index]] === undefined, 'duplicate CLI argument');
    args[argv[index]] = argv[++index];
  }
  requireValue([args['--verify'], args['--verify-seam'], args['--record']].filter(Boolean).length === 1, 'select one CLI mode');
  if (args['--record']) return recordProducer(args['--directory'], args['--reports-directory'], args['--seam']);
  const identity = JSON.parse(readFileSync(args['--identity'], 'utf8'));
  if (args['--verify']) return verifyDirectory(args['--directory'], identity, args['--native-result']);
  return verifySeam(args['--directory'], identity, args['--verify-seam'], args['--native-result']);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.stdout.write(`${JSON.stringify(main(process.argv.slice(2)))}\n`); }
  catch (error) { process.stderr.write(`browser-execution: FAIL: ${error.message}\n`); process.exitCode = 1; }
}
