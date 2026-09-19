// Shared helpers for the Phase 241 p18 adopter-leakage guards.
//
// This is a faithful JavaScript port of 239-v3-vocabulary-check.sh. Detection
// width (the V3 source below) and the asserted surface stay separate: callers
// compare only hits outside the pair-keyed allowlist, while every run reports
// the raw hit count. Do not tune this expression to a clean tree.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { REPO_ROOT } from './_lib.mjs';

export const BOOKKEEPING_V3_SOURCE = String.raw`\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]|\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md`;

export const BOOKKEEPING_V3_RE = new RegExp(BOOKKEEPING_V3_SOURCE);
export const P18_INSTRUMENT_FAILURE_PREFIX = 'P18 INSTRUMENT FAILURE:';
export const P18_DIRTY_SURFACE_PREFIX = 'P18 DIRTY SURFACE:';

// Ported verbatim from 237-docs-attribute-scan.py. This intentionally is not
// the V3 vocabulary: R1's historical baseline is defined by this narrower
// doc-attribute scanner, while R2 owns V3 comment-line bookkeeping.
export const DOC_RANGE_TOKEN_SOURCE = String.raw`\.planning/|\bPhase \d{1,3}\b|\bphase[-_]\d{1,3}\b|\bD-\d{2}\b|\bSC-\d\b|\bREQ-[A-Z0-9]|\bPitfall \d\b|\bINV-\d|-PLAN\.md|-CONTEXT\.md|-SUMMARY\.md|\btodos/\b`;
export const DOC_RANGE_TOKEN_RE = new RegExp(DOC_RANGE_TOKEN_SOURCE, 'g');
const DOC_RANGE_START_RE = /^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"""/;
const DOC_RANGE_ONELINE_RE = /^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"/;

export class P18InstrumentFailure extends Error {
  constructor(message) {
    super(`${P18_INSTRUMENT_FAILURE_PREFIX} ${message}`);
    this.name = 'P18InstrumentFailure';
  }
}

export class P18DirtySurfaceFailure extends Error {
  constructor(message) {
    super(`${P18_DIRTY_SURFACE_PREFIX} ${message}`);
    this.name = 'P18DirtySurfaceFailure';
  }
}

function trackedFiles(...pathspecs) {
  const stdout = execFileSync('git', ['ls-files', ...pathspecs], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });
  return stdout.split('\n').filter(Boolean);
}

/** The real, tracked tier lists. Subject injection never changes these. */
export function tierFiles(tier) {
  switch (tier) {
    case 'lib':
      return trackedFiles('lib/*.ex', 'lib/*.exs');
    case 'priv-templates':
      return trackedFiles('priv/templates');
    case 'planning-paths':
      return [...tierFiles('lib'), ...tierFiles('priv-templates')];
    default:
      throw new P18InstrumentFailure(`unknown p18 tier ${JSON.stringify(tier)}`);
  }
}

function subjectOverrideFiles() {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (!injected) return null;

  const absolutePath = resolve(injected);
  if (!existsSync(absolutePath)) {
    throw new P18InstrumentFailure(
      `subject not found at ${absolutePath} — a missing subject is a broken run, never an absent violation`,
    );
  }

  const repoRelative = relative(REPO_ROOT, absolutePath);
  return [repoRelative.startsWith('..') ? absolutePath : repoRelative];
}

export function filesForTier(tier) {
  return subjectOverrideFiles() ?? tierFiles(tier);
}

function docRangeFiles(relDir) {
  const injected = subjectOverrideFiles();
  if (injected) return injected;

  const root = resolve(REPO_ROOT, relDir);
  if (!existsSync(root)) {
    throw new P18InstrumentFailure(`doc-range root does not exist: ${relDir}`);
  }

  const ex = [];
  const exs = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const absolutePath = join(dir, entry.name);
      if (entry.isDirectory()) walk(absolutePath);
      else if (entry.isFile() && entry.name.endsWith('.ex')) ex.push(absolutePath);
      else if (entry.isFile() && entry.name.endsWith('.exs')) exs.push(absolutePath);
    }
  };
  walk(root);
  // Python's glob order is every sorted *.ex followed by every sorted *.exs.
  return [...ex.sort(), ...exs.sort()].map((path) => relative(REPO_ROOT, path));
}

/**
 * Faithful synchronous port of 237-docs-attribute-scan.py's state machine.
 * The opening and closing heredoc lines are deliberately counted.
 */
export function docRangeScan(relDir) {
  const files = docRangeFiles(relDir);
  if (files.length === 0) {
    throw new P18InstrumentFailure('doc-range walker found no Elixir files — refusing to report success on no input');
  }

  let totalHits = 0;
  let docRanges = 0;
  const sites = new Set();
  const filesHit = new Set();
  const tokenHits = new Map();

  for (const path of files) {
    const lines = readMeasuredFile(path).split('\n');
    let inBlock = false;
    for (const [offset, line] of lines.entries()) {
      const lineNumber = offset + 1;
      const countMatches = () => {
        for (const match of line.matchAll(DOC_RANGE_TOKEN_RE)) {
          totalHits += 1;
          sites.add(`${path}:${lineNumber}`);
          filesHit.add(path);
          tokenHits.set(match[0], (tokenHits.get(match[0]) ?? 0) + 1);
        }
      };

      if (!inBlock) {
        if (DOC_RANGE_START_RE.test(line)) {
          docRanges += 1;
          inBlock = true;
          countMatches();
          continue;
        }
        if (DOC_RANGE_ONELINE_RE.test(line) && !line.includes('"""')) {
          docRanges += 1;
          countMatches();
        }
        continue;
      }

      if (line.includes('"""')) {
        inBlock = false;
        countMatches();
        continue;
      }
      countMatches();
    }
  }

  return {
    totalHits,
    docRanges,
    distinctSites: sites.size,
    distinctFiles: filesHit.size,
    tokenHits,
  };
}

export function docRangeTotal(relDir) {
  return docRangeScan(relDir).totalHits;
}

export function loadAllowlist(relPath = 'scripts/ci/prohibitions/p18-allowlist.tsv') {
  const absolutePath = resolve(REPO_ROOT, relPath);
  if (!existsSync(absolutePath)) {
    throw new P18InstrumentFailure(`cannot read allowlist: ${relPath}`);
  }

  const entries = readFileSync(absolutePath, 'utf8')
    .split('\n')
    .map((line) => line.replace(/\r$/, ''))
    .filter((line) => line !== '' && !line.startsWith('#'))
    .map((line) => {
      const [path, match, index, anchor, reason] = line.split('\t');
      if (!path || !match || !index || !anchor || !reason || !/^\d+$/.test(index)) {
        throw new P18InstrumentFailure(`malformed allowlist row: ${line}`);
      }
      return { path, match, index: Number(index), anchor, reason };
    });

  if (entries.length === 0) {
    throw new P18InstrumentFailure('allowlist has no records — refusing to report success on an empty allowlist');
  }
  return entries;
}

function readMeasuredFile(path) {
  const absolutePath = resolve(REPO_ROOT, path);
  if (!existsSync(absolutePath)) {
    throw new P18InstrumentFailure(`measured file does not exist: ${path}`);
  }
  return readFileSync(absolutePath, 'utf8');
}

function validateAllowlist(entries, measuredFiles) {
  // The real union is deliberate: it must not collapse to an injected fixture.
  const realUnion = new Set([...tierFiles('lib'), ...tierFiles('priv-templates')]);
  const measuredSet = new Set(measuredFiles);

  for (const entry of entries) {
    if (!realUnion.has(entry.path)) {
      throw new P18InstrumentFailure(
        `allowlist entry ${entry.path} is exercised by none of the real lib/ and priv/templates tiers`,
      );
    }
    if (measuredSet.has(entry.path)) {
      const covered = readMeasuredFile(entry.path)
        .split('\n')
        .some((line) => line.includes(entry.anchor) && bookkeepingMatches(line).some(
          (hit) => hit.match === entry.match && hit.index === entry.index,
        ));
      if (!covered) {
        throw new P18InstrumentFailure(
          `vacuous allowlist entry: ${entry.path} :: ${entry.match}@${entry.index} :: ${entry.anchor}`,
        );
      }
    }
  }
}

/** Return every bookkeeping token on a line, not merely whether the line matched. */
export function bookkeepingMatches(line, pattern = BOOKKEEPING_V3_RE) {
  const flags = pattern.flags.includes('g') ? pattern.flags : `${pattern.flags}g`;
  return [...line.matchAll(new RegExp(pattern.source, flags))].map((match) => ({
    match: match[0],
    index: match.index,
  }));
}

export function allowlistedBookkeepingHit(path, text, hit, allowlist) {
  return allowlist.some(
    (entry) => entry.path === path
      && entry.match === hit.match
      && entry.index === hit.index
      && text.includes(entry.anchor),
  );
}

export function scanBookkeeping(tier, options = {}) {
  const files = options.files ?? filesForTier(tier);
  if (files.length === 0) {
    throw new P18InstrumentFailure('empty file list — refusing to report success on no input');
  }

  const allowlist = loadAllowlist(options.allowlistPath);
  validateAllowlist(allowlist, files);
  const detection = options.pattern ?? BOOKKEEPING_V3_RE;

  const hits = [];
  let controlDefmodule = 0;
  for (const path of files) {
    const text = readMeasuredFile(path);
    for (const [offset, line] of text.split('\n').entries()) {
      if (/defmodule/.test(line)) controlDefmodule += 1;
      for (const match of bookkeepingMatches(line, detection)) {
        const allowlisted = allowlistedBookkeepingHit(path, line, match, allowlist);
        hits.push({ path, line: offset + 1, text: line, ...match, allowlisted });
      }
    }
  }

  if (controlDefmodule === 0) {
    throw new P18InstrumentFailure(
      'control_defmodule=0 — refusing to report success on a surface where the paired positive control is dead',
    );
  }

  const allowlisted = hits.filter((hit) => hit.allowlisted).length;
  return {
    tier,
    filesMeasured: files.length,
    controlDefmodule,
    rawHits: hits.length,
    allowlisted,
    outsideAllowlist: hits.length - allowlisted,
    hits,
  };
}

export function measurementReport(result) {
  return [
    `tier=${result.tier}`,
    `hits=${result.rawHits}`,
    `allowlisted=${result.allowlisted}`,
    `hits_outside_allowlist=${result.outsideAllowlist}`,
    `control_defmodule=${result.controlDefmodule}`,
    `files_measured=${result.filesMeasured}`,
    ...result.hits
      .filter((hit) => !hit.allowlisted)
      .map((hit) => `${hit.path}:${hit.line}: ${hit.text}`),
  ].join('\n');
}

export function assertCleanSurface(result, description) {
  if (result.outsideAllowlist > 0) {
    const first = result.hits.find((hit) => !hit.allowlisted);
    throw new P18DirtySurfaceFailure(
      `${description}: ${first.path}:${first.line} ${first.text}`,
    );
  }
}

function invokedDirectly() {
  return process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
}

if (invokedDirectly()) {
  try {
    const result = scanBookkeeping(process.argv[2] ?? 'priv-templates');
    console.log(measurementReport(result));
    assertCleanSurface(result, 'bookkeeping vocabulary hit outside allowlist');
  } catch (error) {
    console.error(error.message);
    process.exitCode = error instanceof P18InstrumentFailure ? 3 : 1;
  }
}
