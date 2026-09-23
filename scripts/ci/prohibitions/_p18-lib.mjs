// Shared helpers for Phase 241's p18 adoptee-surface prohibitions.
//
// This is a JavaScript port of 239-v3-vocabulary-check.sh. Detection width and
// asserted surface remain separate: callers report raw hits, while only hits
// outside the keyed allowlist are a dirty-surface failure.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { REPO_ROOT } from './_lib.mjs';

// Copied verbatim from 239-v3-vocabulary-check.sh's V3 definition.
export const BOOKKEEPING_REGEX_SOURCE =
  '\\.planning/|[Pp]hase[ -][0-9]+|\\bD-[0-9]{2}\\b|\\bPlan [0-9]{2}\\b|[0-9]{3}-[A-Z0-9-]+\\.md|[0-9]{2}-CONTEXT\\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\\bB[0-9]\\b|\\b[0-9]{3}-[0-9]{2}\\b|\\b[Rr]ound[s]?[ -][0-9]|\\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\\bUAT\\b|\\b[Ww]ave [0-9]|\\b[Pp]lan[- ]checker\\b|\\bthis phase\\b|\\bthe plan\\b|v[0-9]+\\.[0-9]+ concern|\\bgap[- ]closure\\b|\\bre-?bless\\b|\\bROADMAP\\b|SUMMARY\\.md';

export const PLANNING_PATH_REGEX_SOURCE = '\\.planning/';
export const INSTRUMENT_FAILURE_PREFIX = 'INSTRUMENT FAILURE:';
export const DIRTY_SURFACE_PREFIX = 'DIRTY SURFACE:';
const ALLOWLIST_PATH = 'scripts/ci/prohibitions/p18-allowlist.tsv';

export class InstrumentFailure extends Error {
  constructor(message) {
    super(`${INSTRUMENT_FAILURE_PREFIX} ${message}`);
    this.name = 'InstrumentFailure';
  }
}

export class DirtySurfaceFailure extends Error {
  constructor(message) {
    super(`${DIRTY_SURFACE_PREFIX} ${message}`);
    this.name = 'DirtySurfaceFailure';
  }
}

function gitFiles(...paths) {
  const output = execFileSync('git', ['ls-files', '--', ...paths], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });
  return output.split('\n').filter(Boolean);
}

/** The real lists are deliberately independent of GSD_PROHIB_SUBJECT. */
export function realTierFiles(tier) {
  switch (tier) {
    case 'adopter-surface':
      return gitFiles('lib', 'priv/templates');
    case 'priv-templates':
      return gitFiles('priv/templates');
    default:
      throw new InstrumentFailure(`unknown tier ${JSON.stringify(tier)}`);
  }
}

export function allTierFiles() {
  return [...new Set([...realTierFiles('adopter-surface'), ...realTierFiles('priv-templates')])];
}

function repoRelative(path) {
  const rel = relative(REPO_ROOT, resolve(REPO_ROOT, path));
  return rel === '' ? '.' : rel;
}

/** A fixture replaces only the primary surface, never allowlist controls. */
export function filesForTier(tier) {
  if (process.env.GSD_PROHIB_FORCE_EMPTY_FILE_LIST === '1') return [];
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected && injected.length > 0) {
    const absolute = resolve(REPO_ROOT, injected);
    if (!existsSync(absolute)) {
      throw new InstrumentFailure(
        `subject not found at ${absolute} — a missing subject is a broken run, never an absent violation`,
      );
    }
    return [repoRelative(absolute)];
  }
  return realTierFiles(tier);
}

export function loadAllowlist(path = process.env.GSD_P18_ALLOWLIST || ALLOWLIST_PATH) {
  const absolute = resolve(REPO_ROOT, path);
  if (!existsSync(absolute)) {
    throw new InstrumentFailure(`cannot read allowlist: ${path}`);
  }

  const entries = readFileSync(absolute, 'utf8')
    .split('\n')
    .map((line) => line.replace(/\r$/, ''))
    .filter((line) => line !== '' && !line.startsWith('#'))
    .map((line) => {
      const [file, literal, reason] = line.split('\t');
      if (!file || !literal || !reason) {
        throw new InstrumentFailure(`malformed allowlist record: ${line}`);
      }
      return { file, literal, reason };
    });

  if (entries.length === 0) throw new InstrumentFailure('allowlist has no records');
  return entries;
}

function countMatches(text, source) {
  const regex = new RegExp(source, 'g');
  let count = 0;
  while (regex.exec(text)) count += 1;
  return count;
}

function validateAllowlist(entries) {
  const union = new Set(allTierFiles());
  // The privileged allowlist belongs to the wide V3 vocabulary, regardless of
  // which narrower hard-fail class a caller is measuring.
  const vocabulary = new RegExp(BOOKKEEPING_REGEX_SOURCE);

  for (const entry of entries) {
    if (!union.has(entry.file)) {
      throw new InstrumentFailure(
        `allowlist entry ${entry.file} is exercised by none of p18's tier file lists`,
      );
    }
    const absolute = resolve(REPO_ROOT, entry.file);
    if (!existsSync(absolute)) {
      throw new InstrumentFailure(`allowlist entry file is missing: ${entry.file}`);
    }
    const text = readFileSync(absolute, 'utf8');
    if (!text.includes(entry.literal) || !vocabulary.test(text)) {
      throw new InstrumentFailure(
        `vacuous allowlist entry: ${entry.file} :: ${entry.literal}`,
      );
    }
  }
}

function lineHits(file, source) {
  const text = readFileSync(resolve(REPO_ROOT, file), 'utf8');
  const lines = text.split('\n');
  const regex = new RegExp(source);
  return lines.flatMap((text, index) => (regex.test(text) ? [{ file, line: index + 1, text }] : []));
}

function formatHit(hit) {
  return `${hit.file}:${hit.line}: ${hit.text}`;
}

export function scanP18({ tier, vocabularySource }) {
  const files = filesForTier(tier);
  if (files.length === 0) {
    throw new InstrumentFailure(`empty file list for ${tier} — refusing to report success on no input`);
  }

  // These controls always use tracked production lists, even during fixture runs.
  const allowlist = loadAllowlist();
  validateAllowlist(allowlist);

  const controlDefmodule = files.reduce(
    (total, file) => total + countMatches(readFileSync(resolve(REPO_ROOT, file), 'utf8'), '\\bdefmodule\\b'),
    0,
  );
  if (controlDefmodule === 0) {
    throw new InstrumentFailure(
      `control_defmodule=0 for ${tier} — refusing to report success on a dead positive control`,
    );
  }

  const hits = files.flatMap((file) => lineHits(file, vocabularySource));
  const allowlistedHits = hits.filter((hit) =>
    allowlist.some((entry) => entry.file === hit.file && hit.text.includes(entry.literal)),
  );
  const outsideAllowlist = hits.filter((hit) => !allowlistedHits.includes(hit));

  return {
    tier,
    filesMeasured: files.length,
    controlDefmodule,
    rawHits: hits.length,
    allowlisted: allowlistedHits.length,
    hitsOutsideAllowlist: outsideAllowlist.length,
    outsideAllowlist,
  };
}

export function reportScan(result) {
  console.log(`tier=${result.tier}`);
  console.log(`hits=${result.rawHits}`);
  console.log(`allowlisted=${result.allowlisted}`);
  console.log(`hits_outside_allowlist=${result.hitsOutsideAllowlist}`);
  console.log(`control_defmodule=${result.controlDefmodule}`);
  console.log(`files_measured=${result.filesMeasured}`);
  for (const hit of result.outsideAllowlist) console.log(formatHit(hit));
}

export function assertClean(result, className) {
  if (result.hitsOutsideAllowlist > 0) {
    throw new DirtySurfaceFailure(
      `${className} found ${result.hitsOutsideAllowlist} hit(s) outside the allowlist:\n` +
        result.outsideAllowlist.map(formatHit).join('\n'),
    );
  }
}

const DOC_RANGE_REGEX_SOURCE = String.raw`(\.planning/|\bPhase \d{1,3}\b|\bphase[-_]\d{1,3}\b|\bD-\d{2}\b|\bSC-\d\b|\bREQ-[A-Z0-9]|\bPitfall \d\b|\bINV-\d|-PLAN\.md|-CONTEXT\.md|-SUMMARY\.md|\btodos/\b)`;
const DOC_RANGE_START = /^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"""/;
const DOC_RANGE_ONELINE = /^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"/;

function docRangeFiles(relDir) {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected) {
    const absolute = resolve(REPO_ROOT, injected);
    if (!existsSync(absolute)) {
      throw new InstrumentFailure(`subject not found at ${absolute} — missing subject is a broken run`);
    }
    return [repoRelative(absolute)];
  }
  return gitFiles(relDir).filter((file) => /\.exs?$/.test(file));
}

/** Port of the Phase 237 Python doc-attribute state machine. */
export function docRangeMeasurement(relDir = 'lib', tokenSource = DOC_RANGE_REGEX_SOURCE) {
  const files = docRangeFiles(relDir);
  if (files.length === 0) throw new InstrumentFailure(`empty doc-range file list for ${relDir}`);
  const tokenRegex = new RegExp(tokenSource, 'g');
  let total = 0;
  let ranges = 0;
  const hits = [];

  const countLine = (line, file, lineNumber) => {
    const found = [...line.matchAll(tokenRegex)];
    total += found.length;
    for (const match of found) hits.push(`${file}:${lineNumber}: ${match[0]}`);
  };

  for (const file of files) {
    const lines = readFileSync(resolve(REPO_ROOT, file), 'utf8').split('\n');
    let inBlock = false;
    for (const [index, line] of lines.entries()) {
      if (!inBlock) {
        if (DOC_RANGE_START.test(line)) {
          ranges += 1;
          inBlock = true;
          countLine(line, file, index + 1);
          continue;
        }
        if (DOC_RANGE_ONELINE.test(line) && !line.includes('"""')) {
          ranges += 1;
          countLine(line, file, index + 1);
          continue;
        }
      } else if (line.includes('"""')) {
        inBlock = false;
        countLine(line, file, index + 1);
        continue;
      } else {
        countLine(line, file, index + 1);
      }
      tokenRegex.lastIndex = 0;
    }
  }
  return { total, ranges, filesMeasured: files.length, hits };
}

export function docRangeTotal(relDir = 'lib') {
  return docRangeMeasurement(relDir).total;
}

const PACKAGED_DOC_FILES = ['docs', 'README.md', 'CHANGELOG.md'];
export function packagedPlanningPathOccurrences() {
  const files = gitFiles(...PACKAGED_DOC_FILES);
  if (files.length === 0) throw new InstrumentFailure('empty packaged-doc file list');
  return files.reduce((sum, file) => {
    const matches = readFileSync(resolve(REPO_ROOT, file), 'utf8').match(/\.planning\//g) || [];
    return sum + matches.length;
  }, 0);
}

export function libraryCommentBookkeepingLines() {
  const files = gitFiles('lib').filter((file) => /\.exs?$/.test(file));
  if (files.length === 0) throw new InstrumentFailure('empty lib comment file list');
  const vocabulary = new RegExp(BOOKKEEPING_REGEX_SOURCE);
  let total = 0;
  for (const file of files) {
    for (const line of readFileSync(resolve(REPO_ROOT, file), 'utf8').split('\n')) {
      if (/^\s*#/.test(line) && vocabulary.test(line)) total += 1;
    }
  }
  return total;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [tier = 'adopter-surface', vocabularySource = BOOKKEEPING_REGEX_SOURCE] = process.argv.slice(2);
  try {
    const result = scanP18({ tier, vocabularySource });
    reportScan(result);
    assertClean(result, 'p18 direct invocation');
  } catch (error) {
    console.error(error.message);
    process.exitCode = error instanceof InstrumentFailure ? 3 : 1;
  }
}
