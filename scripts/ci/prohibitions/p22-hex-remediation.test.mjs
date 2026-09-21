// Subject: .github/workflows/hex-remediate-phantom.yml (via GSD_PROHIB_SUBJECT).
// This is deliberately independent of the Phase 234 publisher inventory: remediation is not a publisher.
import assert from 'node:assert/strict';
import test from 'node:test';
import { readRepoFile, readSubject, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT = '.github/workflows/hex-remediate-phantom.yml';
const REQUIRED_SLOTS = ['before', 'after_retire', 'after_docs_revert', 'hexdocs_root', 'resolver_broad', 'resolver_safe'];
const MUTATIONS = ['Retire sigra 1.20.0 after observed state', 'Revert only sigra 1.20.0 docs after observed state'];

function stepBlocks(job) {
  return job.split(/(?=^ {6}- name: )/m).filter((block) => /^ {6}- name: /m.test(block));
}

function violations(raw) {
  const workflow = stripYamlComments(raw);
  const job = jobBlock(workflow, 'remediate');
  const errors = [];
  const need = (ok, message) => { if (!ok) errors.push(message); };
  need(Boolean(job), 'remediate job parse broke');
  if (!job) return errors;
  const steps = stepBlocks(job);
  const actionRefs = [...raw.matchAll(/^\s*(?:-\s+)?uses: ([^\s]+)\s+# (v\d+\.\d+\.\d+)$/gm)];
  const mutationSteps = steps.filter((step) => MUTATIONS.some((name) => step.includes(`name: ${name}`)));
  const secretRefs = [...workflow.matchAll(/secrets\.HEX_API_KEY/g)];
  const message = 'Retired: use the supported ~> 1.5.0 requirement instead.';

  need(/on:\n\s+workflow_dispatch:\s*\n\s*\npermissions:/.test(workflow), 'workflow dispatch must have no inputs mapping');
  need(/permissions:\n\s+contents: read\s*\n/.test(workflow), 'contents permission must be read only');
  need(/concurrency:\n\s+group: hex-remediate-phantom-sigra-1-20-0\n\s+cancel-in-progress: false/.test(workflow), 'concurrency must be fixed and non-cancelling');
  need(steps.length >= 10, 'step parse must locate the remediation sequence');
  need(actionRefs.length >= 3 && actionRefs.every(([, action, version]) => /@[0-9a-f]{40}$/.test(action) && /^v\d+\.\d+\.\d+$/.test(version)), 'actions must use immutable annotated SHA pins');
  need(mutationSteps.length === 2, 'exactly two mutation steps are required');
  need(secretRefs.length === 2 && mutationSteps.every((step) => step.includes('secrets.HEX_API_KEY')) && steps.filter((step) => !mutationSteps.includes(step)).every((step) => !step.includes('HEX_API_KEY')), 'HEX_API_KEY must be scoped only to the two mutation step bodies');
  need(!/set\s+-[A-Za-z]*x/.test(workflow), 'shell tracing is forbidden in remediation workflow');
  need(workflow.includes(`mix hex.retire sigra 1.20.0 invalid --message '${message}'`) && /^[\x20-\x7E]{1,140}$/.test(message), 'retire command must have exact fixed ASCII target, reason, and bounded message');
  need(workflow.includes('mix hex.publish docs --revert 1.20.0') && !/mix\s+hex\.publish\s+--revert\b/.test(workflow), 'only the docs revert command class is allowed');
  need(workflow.indexOf('AFTER_RETIRE public package observation') > workflow.indexOf('Retire sigra 1.20.0 after observed state') && workflow.indexOf('Revert only sigra 1.20.0 docs after observed state') > workflow.indexOf('AFTER_RETIRE public package observation'), 'retirement must precede docs revert with a causal observation');
  need(/elif mix hex\.retire[\s\S]*?else[\s\S]*?capture after_retire/.test(workflow) && /if mix hex\.publish docs --revert 1\.20\.0; then[\s\S]*?else[\s\S]*?classify-root/.test(workflow), 'each mutation must read after error instead of blindly retrying');
  for (const slot of REQUIRED_SLOTS) need(workflow.includes(`public-remediation-evidence/${slot}.json`), `missing evidence slot ${slot}`);
  need(workflow.includes('public-remediation-evidence/receipt.json') && workflow.includes('path: public-remediation-evidence'), 'artifact must contain only the public evidence path');
  need(!/(contents:\s*write|git push|gh api\s+--method)/.test(workflow), 'repository write behavior is forbidden');
  return errors;
}

test('non-vacuity floor: remediation workflow has dispatch, job, steps, pins, mutations, and all evidence slots', () => {
  const workflow = stripYamlComments(readSubject(SUBJECT));
  assert.match(workflow, /workflow_dispatch:/);
  assert.ok(jobBlock(workflow, 'remediate'));
  assert.ok(stepBlocks(jobBlock(workflow, 'remediate')).length >= 10);
  assert.ok((workflow.match(/uses:/g) ?? []).length >= 3);
  assert.ok((workflow.match(/public-remediation-evidence\//g) ?? []).length >= REQUIRED_SLOTS.length);
});

test('production remediation workflow stays fixed, least-privilege, observed, and evidence-safe', () => {
  assert.deepEqual(violations(readSubject(SUBJECT)), []);
});

test('broadened fixture reports fixed target, no-input, permission, and concurrency drift', () => {
  const errors = violations(readRepoFile('test/fixtures/prohibitions/p22-hex-remediation-broadened.yml'));
  for (const expected of ['workflow dispatch must have no inputs mapping', 'contents permission must be read only', 'concurrency must be fixed and non-cancelling', 'retire command must have exact fixed ASCII target, reason, and bounded message']) assert.ok(errors.includes(expected), `missing diagnostic: ${expected}`);
});

test('unsafe-secret fixture reports secret scope, tracing, and docs-only revert drift', () => {
  const errors = violations(readRepoFile('test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml'));
  for (const expected of ['HEX_API_KEY must be scoped only to the two mutation step bodies', 'shell tracing is forbidden in remediation workflow', 'only the docs revert command class is allowed']) assert.ok(errors.includes(expected), `missing diagnostic: ${expected}`);
});
