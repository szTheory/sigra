import { defineConfig } from '@playwright/test';
import productionConfig from './playwright.config';

// Phase 253 plan 39: scoped per-project selection for the four remaining native
// registration-control windows. Everything the production config decides (device and
// theme presets, `use`, workers, fullyParallel, retries, timeouts, expect, reporters,
// test directory and output directory) is inherited unchanged; this file only
// narrows the three admin-eval projects and gives EACH project its own title filter.
//
// The CLI must never pass --grep, because a CLI grep would replace these per-project
// filters. The stage flag is opt-in and mandatory here: the controls it enables are
// declared by tests/admin-eval.spec.ts only for the matching stage, so an unset or
// unknown stage fails closed instead of silently running an empty or wrong inventory.

const SPEC_PROJECTS = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark'] as const;

const FIRST_TITLES = [
  'registration waits for explicitly released LiveView readiness',
  'registration stops when LiveView readiness is never released',
  'registration fails when the readiness wait is deliberately broken',
  'registration detects a deliberate same-account collision',
  'registration retains the first forced assertion failure trace',
];
const SECOND_TITLES = [
  'registration starts from a fresh database and context',
  'registration discards trace after a passing control',
];
const ORIGINAL_BOARD_TITLE = 'render bundle: board-mg-9/populated';

const stage = process.env.SIGRA_REGISTRATION_CONTROL_STAGE;
if (stage !== 'first' && stage !== 'second') {
  throw new Error(
    `playwright.registration-recovery.config.ts requires SIGRA_REGISTRATION_CONTROL_STAGE=first|second (got ${stage ?? 'unset'})`,
  );
}

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
const exactTitles = (titles: string[]) => new RegExp(`(${titles.map(escapeRegExp).join('|')})`);

function titlesFor(projectName: string): string[] {
  if (stage === 'second') return SECOND_TITLES;
  // The original board rows are part of the single first command, in dark only.
  return projectName === 'admin-eval-dark' ? [ORIGINAL_BOARD_TITLE, ...FIRST_TITLES] : FIRST_TITLES;
}

const projects = productionConfig.projects ?? [];
const selected = SPEC_PROJECTS.map((name) => {
  const project = projects.find((candidate) => candidate.name === name);
  if (!project) throw new Error(`production config no longer defines the ${name} project`);
  return { ...project, grep: exactTitles(titlesFor(name)) };
});

export default defineConfig({
  ...productionConfig,
  projects: selected,
});
