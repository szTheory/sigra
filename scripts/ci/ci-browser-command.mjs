#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const playwrightDirectory = resolve(root, 'test/example/priv/playwright');
const adminBehaviorSpecs = [
  'tests/admin-user-operations.spec.ts',
  'tests/impersonation.spec.ts',
  'tests/admin-audit.spec.ts',
  'tests/admin-theme.spec.ts',
  'tests/admin-coherence-sweep.spec.ts',
  'tests/admin-modal-interaction.spec.ts',
  'tests/admin-flow-platform-admin.spec.ts',
  'tests/admin-flow-support-investigator.spec.ts',
  'tests/admin-flow-org-admin.spec.ts',
];
const nonAdminSpecs = [
  'tests/golden-path.spec.ts',
  'tests/ga-uat-shift-left.spec.ts',
  'tests/passkeys-hooks.spec.ts',
  'tests/organizations.spec.ts',
  'tests/passkey-login.spec.ts',
  'tests/passkey-options.spec.ts',
];
const designProjects = ['admin-design-chromium', 'admin-design-mobile', 'admin-design-dark'];

function invocation(specs, projects, reportPath, filters = {}) {
  return {
    specs,
    projects,
    projectArgs: filters.projectArgs ?? projects,
    grep: filters.grep ?? null,
    grepInvert: filters.grepInvert ?? null,
    retries: 0,
    selectionPath: reportPath.replace(/\.json$/, '.selection.json'),
    reportPath,
  };
}

/** The exact browser spec/project/report selections owned by the five CI seams. */
export function browserInvocations(seam, event) {
  if (!['pull_request', 'push', 'schedule', 'workflow_dispatch'].includes(event)) {
    throw new Error(`unsupported browser event: ${event}`);
  }
  switch (seam) {
    case 'admin_behavior':
      return [{ id: seam, invocations: [invocation(adminBehaviorSpecs, ['chromium'], 'admin-behavior.json')] }];
    case 'admin_checkpoints':
      return [{ id: seam, invocations: [invocation(['tests/admin-checkpoints.spec.ts'], [
        'admin-checkpoints-chromium', 'admin-checkpoints-mobile', 'admin-checkpoints-dark',
      ], 'admin-checkpoints.json')] }];
    case 'design_gallery':
      if (event === 'pull_request') {
        return [{ id: 'design_gallery', invocations: [invocation(['tests/admin-design.spec.ts'], designProjects,
          'design-gallery-pr-behavior.json', { grepInvert: '@snapshot' })] }];
      }
      return [{ id: 'design_gallery_snapshots', invocations: [
        invocation(['tests/admin-design.spec.ts'], designProjects, 'design-gallery-nonpr-snapshots.json', { grep: '@snapshot' }),
        invocation(['tests/admin-design.spec.ts'], designProjects, 'design-gallery-nonpr-behavior.json', { grepInvert: '@snapshot' }),
      ] }];
    case 'non_admin_smoke':
      return [{ id: seam, invocations: [invocation(nonAdminSpecs, ['chromium', 'mobile'], 'non-admin-smoke.json', {
        // The source CI invocation omits project flags and relies on config.testMatch/testIgnore.
        projectArgs: [],
      })] }];
    case 'demo_showcase':
      return [{ id: seam, invocations: [invocation(['tests/demo-showcase.spec.ts'], ['demo-showcase-chromium'],
        'demo-showcase.json')] }];
    default:
      throw new Error(`unknown browser seam: ${seam}`);
  }
}

function argsFor(entry, mode, outputRoot, grep) {
  const outputPath = resolve(outputRoot, mode === 'list' ? entry.selectionPath : entry.reportPath);
  const args = [...entry.specs];
  for (const project of entry.projectArgs) args.push(`--project=${project}`);
  if (entry.grep) args.push('--grep', entry.grep);
  if (entry.grepInvert) args.push('--grep-invert', entry.grepInvert);
  if (grep) {
    if (entry.grep) args.splice(args.indexOf(entry.grep), 1, `(?=${entry.grep})(?=${grep})`);
    else args.push('--grep', grep);
  }
  args.push('--retries=0');
  if (mode === 'list') args.push('--list', '--reporter=json');
  return { args, outputPath };
}

export function preserveNativeDiagnosticReport(nativeReportPath, reportPath) {
  if (nativeReportPath && !existsSync(reportPath) && existsSync(nativeReportPath)) {
    if (lstatSync(nativeReportPath).isSymbolicLink()) throw new Error('native Playwright report is a symlink');
    copyFileSync(nativeReportPath, reportPath, 0x1);
  }
  if (!existsSync(reportPath) || lstatSync(reportPath).isSymbolicLink() || !readFileSync(reportPath, 'utf8')) {
    throw new Error(`missing Playwright report: ${reportPath}`);
  }
}

function run(mode, seam, event, outputRoot, grep) {
  if (!['list', 'run'].includes(mode)) throw new Error('usage: ci-browser-command.mjs list|run --seam NAME --event EVENT --output-root DIR [--grep PATTERN]');
  if (!outputRoot) throw new Error('--output-root is required');
  const absoluteRoot = isAbsolute(outputRoot) ? outputRoot : resolve(process.cwd(), outputRoot);
  mkdirSync(absoluteRoot, { recursive: true });
  for (const policy of browserInvocations(seam, event)) {
    for (const entry of policy.invocations) {
      const { args, outputPath } = argsFor(entry, mode, absoluteRoot, grep);
      mkdirSync(dirname(outputPath), { recursive: true });
      const env = { ...process.env };
      if (mode === 'run') {
        env.SIGRA_PLAYWRIGHT_JSON = outputPath;
        if (existsSync(outputPath)) {
          if (lstatSync(outputPath).isSymbolicLink()) throw new Error('Playwright report target is a symlink');
          unlinkSync(outputPath);
        }
        if (env.SIGRA_CI_DIAGNOSTICS === '1' && env.SIGRA_CI_DIAGNOSTICS_ROOT) {
          const nativeReportPath = resolve(env.SIGRA_CI_DIAGNOSTICS_ROOT, 'native-report.json');
          if (existsSync(nativeReportPath)) {
            if (lstatSync(nativeReportPath).isSymbolicLink()) throw new Error('native Playwright report is a symlink');
            unlinkSync(nativeReportPath);
          }
        }
      }
      const child = spawnSync(resolve(playwrightDirectory, 'node_modules/.bin/playwright'), ['test', ...args], {
        cwd: playwrightDirectory,
        env,
        encoding: 'utf8',
        maxBuffer: 64 * 1024 * 1024,
      });
      if (child.error) throw child.error;
      if (mode === 'list') {
        if (child.status !== 0) {
          process.stderr.write(child.stderr ?? '');
          process.stdout.write(child.stdout ?? '');
          return child.status ?? 1;
        }
        try {
          const selection = JSON.parse(child.stdout);
          if (!Array.isArray(selection.suites) || selection.suites.length === 0 ||
              !Array.isArray(selection.config?.projects) || selection.config.projects.length === 0) {
            throw new Error('Playwright returned an empty selection');
          }
        } catch (error) {
          throw new Error(`invalid Playwright selection for ${entry.reportPath}: ${error.message}`);
        }
        writeFileSync(outputPath, child.stdout);
      } else {
        if (child.stdout) process.stdout.write(child.stdout);
        if (child.stderr) process.stderr.write(child.stderr);
        if (child.status !== 0) return child.status ?? 1;
        const nativeReportPath = env.SIGRA_CI_DIAGNOSTICS === '1' && env.SIGRA_CI_DIAGNOSTICS_ROOT
          ? resolve(env.SIGRA_CI_DIAGNOSTICS_ROOT, 'native-report.json') : null;
        preserveNativeDiagnosticReport(nativeReportPath, outputPath);
      }
    }
  }
  return 0;
}

function parse(argv) {
  const [mode, ...rest] = argv;
  const options = {};
  while (rest.length) {
    const key = rest.shift();
    if (!key.startsWith('--') || !rest.length) throw new Error(`invalid argument: ${key}`);
    options[key.slice(2)] = rest.shift();
  }
  for (const required of ['seam', 'event', 'output-root']) {
    if (!options[required]) throw new Error(`--${required} is required`);
  }
  return { mode, options };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const { mode, options } = parse(process.argv.slice(2));
    process.exitCode = run(mode, options.seam, options.event, options['output-root'], options.grep ?? null);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
