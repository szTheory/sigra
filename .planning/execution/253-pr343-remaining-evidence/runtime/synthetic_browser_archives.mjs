// Test-only archive producer. Every output is synthetic and cannot serve as live evidence.
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { bodyPolicy } from '../../../../scripts/ci/ci-browser-records.mjs';
const [output, workflowPath] = process.argv.slice(2);
const hashBytes = (bytes) => createHash('sha256').update(bytes).digest('hex');
const workflowHash = hashBytes(readFileSync(workflowPath));
const identity = { run_id: '39815188159', run_attempt: '1', source_sha: 'd6024255ed139f7c19bd44e68c10a85cc9ecca3b',
  event: 'pull_request', workflow_ref: 'szTheory/sigra/.github/workflows/ci.yml@refs/pull/343/merge',
  workflow_sha: 'd6024255ed139f7c19bd44e68c10a85cc9ecca3b', classifier_result: 'success', docs_only: 'false' };
const seams = ['non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase'];
function report(specs, projects) {
  const suites = specs.map((file, index) => ({ title:file, file, specs:[{id:`fixture-${index}`,title:`selected ${index}`,file,
    tests:projects.filter((project) => project !== 'mobile' || !/passkeys-hooks|passkey-login|passkey-options/.test(file)).map((project) => ({
      projectId:project, projectName:project, expectedStatus:'passed', status:'expected',
      results:[{retry:0,status:'passed',duration:1,startTime:'2026-10-13T00:00:00Z'}],
    })) }] }));
  const count = suites.reduce((n, suite) => n + suite.specs[0].tests.length, 0);
  return {config:{projects:projects.map((name) => ({id:name,name}))},suites,errors:[],
    stats:{expected:count,unexpected:0,flaky:0,skipped:0,startTime:'2026-10-13T00:00:00Z',duration:10}};
}
for (const seam of seams) {
  const dir = join(output, `browser-execution-${seam}-39815188159-1`); mkdirSync(dir,{recursive:true});
  const record = {schema_version:'sigra.browser-execution-record/v1',...identity,workflow_file_sha256:workflowHash,seam,selected_steps:[]};
  for (const policy of bodyPolicy(seam, identity.event)) {
    const step = {id:policy.id,outcome:'success',conclusion:'success',reports:[]};
    for (const invocation of policy.invocations) {
      const native = report(invocation.specs, invocation.projects);
      if (seam === 'design_gallery') {
        const setup = report(['admin-design.setup.ts'], invocation.projects.map((project) => project.replace('admin-design-','admin-design-setup-')));
        native.config.projects.push(...setup.config.projects); native.suites.push(...setup.suites); native.stats.expected += setup.stats.expected;
      }
      const selection = structuredClone(native);
      for (const suite of selection.suites) for (const spec of suite.specs) for (const selected of spec.tests) selected.results = [];
      const nativeBytes = Buffer.from(JSON.stringify(native)); const selectionBytes = Buffer.from(JSON.stringify(selection));
      writeFileSync(join(dir, invocation.path), nativeBytes); writeFileSync(join(dir, invocation.selection_path), selectionBytes);
      step.reports.push({path:invocation.path,selection_path:invocation.selection_path,sha256:hashBytes(nativeBytes),selection_sha256:hashBytes(selectionBytes)});
    }
    record.selected_steps.push(step);
  }
  writeFileSync(join(dir,'execution-record.json'),JSON.stringify(record));
}
