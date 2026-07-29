// Shared parsing helpers for the Phase 230 prohibition guards.
//
// WHY node:test AND NOT ExUnit
// This repo's idiom for asserting on shipped artifacts is `test/sigra/planning/*.exs`
// (File.read! + Regex, no YAML dep). These guards deliberately do NOT use it: GSD's
// `check prohibition-enforcement` producer only accepts `check_kind: node-test` or
// `lint-rule` (see ~/.claude/gsd-core/bin/lib/prohibition-enforcement.cjs), so an ExUnit
// check could never satisfy a `verification: test` prohibition and the phase would
// re-derive `human_needed` on every re-verify. Same discipline, different runtime.
//
// THE SUBJECT INDIRECTION
// `prohibition-enforcement` proves each guard fail-FIRST by re-running it with
// `GSD_PROHIB_SUBJECT` pointed at a known-BAD fixture (must go non-vacuously red) and
// then at a known-CLEAN subject (must go non-vacuously green). Every guard therefore
// reads its primary artifact through `subjectPath()` rather than a hardcoded path.
// Secondary artifacts are always read from their real locations -- a guard has exactly
// one substitutable subject.
//
// NON-VACUITY IS THE POINT
// A guard whose extractor silently matches nothing reports green and protects nothing.
// Every parse below throws rather than returning empty, and every guard asserts a floor
// on what it found. The message convention is borrowed verbatim from
// test/sigra/planning/phase_230_ci_timeouts_test.exs: "the parse broke, this is not a
// pass".

import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

/** Resolve a guard's primary subject, honouring the fail-first injection. */
export function subjectPath(defaultRelPath) {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected && injected.length > 0) return resolve(injected);
  return resolve(REPO_ROOT, defaultRelPath);
}

export function readSubject(defaultRelPath) {
  const p = subjectPath(defaultRelPath);
  if (!existsSync(p)) {
    throw new Error(
      `subject not found at ${p} — a missing subject is a broken run, never an absent violation`,
    );
  }
  return readFileSync(p, 'utf8');
}

export function readRepoFile(relPath) {
  const p = resolve(REPO_ROOT, relPath);
  if (!existsSync(p)) throw new Error(`repo file not found: ${relPath}`);
  return readFileSync(p, 'utf8');
}

/**
 * Split a workflow file into [jobId, blockText] pairs.
 *
 * Ported from phase_230_ci_timeouts_test.exs: take everything after the top-level
 * `jobs:` line, then split on a zero-width lookahead at each 2-space-indented job header
 * so every block STARTS with its own id and the `on:` block's 2-space keys cannot leak in.
 */
export function jobBlocks(workflowText) {
  const parts = workflowText.split(/\njobs:\s*\n/);
  if (parts.length < 2) {
    throw new Error('could not find a top-level `jobs:` line — the parse broke, this is not a pass');
  }
  const afterJobs = parts.slice(1).join('\njobs:\n');
  const blocks = afterJobs
    .split(/(?=^ {2}[A-Za-z0-9_-]+:[ \t]*$)/m)
    .filter((b) => b.trim() !== '');

  const out = [];
  for (const block of blocks) {
    const header = block.split('\n', 1)[0];
    const m = header.match(/^ {2}([A-Za-z0-9_-]+):[ \t]*$/);
    if (m) out.push([m[1], block]);
  }
  if (out.length === 0) {
    throw new Error('job walk found zero job blocks — the parse broke, this is not a pass');
  }
  return out;
}

/**
 * Drop YAML comments so a guard asserts on EFFECTIVE workflow content, not prose.
 *
 * This is load-bearing, not cosmetic. ci.yml documents its docs-only design in comments
 * that necessarily contain the token `docs_only` (e.g. "This is deliberately NOT gated on
 * docs_only"), and MAINTAINING.md-style explanatory comments sit inside job bodies. A
 * naive /docs_only/ match over raw text therefore reds the SHIPPED file — which the
 * clean-fixture half of `prohibition-enforcement` catches immediately.
 *
 * Full-line comments are removed entirely. Trailing comments are removed only when the
 * `#` is preceded by whitespace and is not inside a quoted string, so a `#` appearing in
 * an expression or a quoted value survives.
 */
export function stripYamlComments(text) {
  return text
    .split('\n')
    .map((line) => {
      if (/^\s*#/.test(line)) return '';
      let inSingle = false;
      let inDouble = false;
      for (let i = 0; i < line.length; i += 1) {
        const ch = line[i];
        if (ch === "'" && !inDouble) inSingle = !inSingle;
        else if (ch === '"' && !inSingle) inDouble = !inDouble;
        else if (ch === '#' && !inSingle && !inDouble && i > 0 && /\s/.test(line[i - 1])) {
          return line.slice(0, i);
        }
      }
      return line;
    })
    .join('\n');
}

/**
 * Drop JS/TS comments so a guard asserts on effective code rather than prose.
 *
 * Same lesson as stripYamlComments, learned the same way: admin-design.spec.ts documents
 * that its axe scan "carries no `.include()`", so a naive /\.include\(/ match reds the
 * SHIPPED spec for saying it does the right thing. Well-commented code is the norm here,
 * which makes comment-stripping a correctness requirement for every content assertion.
 */
export function stripJsComments(text) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .map((line) => {
      let inSingle = false;
      let inDouble = false;
      let inTick = false;
      for (let i = 0; i < line.length; i += 1) {
        const ch = line[i];
        if (ch === '\\') { i += 1; continue; }
        if (ch === "'" && !inDouble && !inTick) inSingle = !inSingle;
        else if (ch === '"' && !inSingle && !inTick) inDouble = !inDouble;
        else if (ch === '`' && !inSingle && !inDouble) inTick = !inTick;
        else if (ch === '/' && line[i + 1] === '/' && !inSingle && !inDouble && !inTick) {
          return line.slice(0, i);
        }
      }
      return line;
    })
    .join('\n');
}

export function jobBlock(workflowText, jobId) {
  const hit = jobBlocks(workflowText).find(([id]) => id === jobId);
  return hit ? hit[1] : null;
}

/**
 * Normalize a GitHub Actions expression so the two syntaxes that BOTH appear in this
 * repo's ci.yml compare equal: bare (`if: github.event_name != 'pull_request'`) and
 * wrapped (`if: ${{ !cancelled() && github.event_name != 'pull_request' }}`). A guard
 * that keys on one form silently drops the other -- and the one it would drop is the
 * tier-B STEP, the single most important entry in the skip manifest.
 */
export function normalizeExpr(expr) {
  return String(expr)
    .replace(/\$\{\{/g, ' ')
    .replace(/\}\}/g, ' ')
    .replace(/["']/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/** Parse .github/ci-skip-manifest.tsv into row objects. Throws rather than returning []. */
export function parseSkipManifest(text) {
  const rows = [];
  let sawHeader = false;
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\r$/, '');
    if (line.trim() === '' || line.startsWith('#')) continue;
    const cells = line.split('\t');
    if (!sawHeader) {
      if (cells[0] === 'tier') { sawHeader = true; continue; }
      continue;
    }
    if (cells.length < 8) {
      throw new Error(`skip-manifest row has ${cells.length} columns, expected 8: ${line}`);
    }
    const [tier, kind, id, parentJobId, displayName, gateLevel, gate, observer] = cells;
    rows.push({ tier, kind, id, parentJobId, displayName, gateLevel, gate, observer });
  }
  if (!sawHeader) {
    throw new Error('skip-manifest has no `tier` header row — the parse broke, this is not a pass');
  }
  if (rows.length === 0) {
    throw new Error('skip-manifest parsed to zero rows — the parse broke, this is not a pass');
  }
  return rows;
}

/** The five ruleset-14941512-required context names, byte-identical to ci.yml `name:`. */
export const REQUIRED_CONTEXTS = Object.freeze([
  'Library tests',
  'Example unit smoke (ExUnit + ConnTest)',
  'Install smoke (fresh phx.new + sigra.install)',
  'Example HTTP smoke (boot + curl critical routes)',
  'Example Playwright smoke (full lifecycle)',
]);

/** Job ids that must never be gated on docs_only, and must not depend on `changes`. */
export const NEVER_DOCS_GATED = Object.freeze([
  'fast_checks',
  'library_tests',
  'library_tests_shard',
]);

/**
 * Parse an observed-run evidence ledger into slot objects.
 *
 * A "slot" is a `## NAME` section whose NAME is BEFORE-something or AFTER-something — the
 * ledger's unit of observation. Analysis sections (`## Per-Requirement Summary`, etc.) are
 * not slots and carry no Status line.
 *
 * Deliberately GENERIC across every phase's `-EVIDENCE.md` under `.planning/phases`: this
 * is a FORMAT contract, so Phases 231-235 inherit it. No phase-230 hardcoding, and no
 * opt-in marker — an opt-in is an opt-out, and opt-outs rot.
 */
export const SLOT_HEADING_RE = /^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/;

export function parseEvidenceSlots(text) {
  const lines = text.split('\n');
  const slots = [];
  let current = null;
  for (const line of lines) {
    const h = line.match(SLOT_HEADING_RE);
    if (h) {
      if (current) slots.push(current);
      current = { name: h[1], body: [] };
      continue;
    }
    if (/^##\s+/.test(line)) {
      if (current) slots.push(current);
      current = null;
      continue;
    }
    if (current) current.body.push(line);
  }
  if (current) slots.push(current);

  for (const s of slots) {
    s.text = s.body.join('\n');
    const st = s.text.match(/^Status:\s*(.+)$/m);
    s.statusRaw = st ? st[1].trim() : null;
    s.captured = Boolean(s.statusRaw && s.statusRaw.startsWith('captured'));
    s.pending = Boolean(s.statusRaw && s.statusRaw.startsWith('pending'));
    s.runIds = [...s.text.matchAll(/\b(\d{8,12})\b/g)].map((m) => m[1]);
    s.statusRunIds = s.statusRaw
      ? [...s.statusRaw.matchAll(/\b(\d{8,12})\b/g)].map((m) => m[1])
      : [];
    s.fenced = [...s.text.matchAll(/```[\s\S]*?```/g)].map((m) => m[0]);
  }
  if (slots.length === 0) {
    throw new Error(
      'evidence ledger parsed to zero BEFORE-*/AFTER-* slots — the parse broke, this is not a pass',
    );
  }
  return slots;
}

/** Extract a job's `needs:` entries (inline `[a, b]` or block-list form). */
export function jobNeeds(blockText) {
  const inline = blockText.match(/^ {4}needs:[ \t]*\[([^\]]*)\]/m);
  if (inline) {
    return inline[1].split(',').map((s) => s.trim()).filter(Boolean);
  }
  const blockForm = blockText.match(/^ {4}needs:[ \t]*\n((?: {6}- .*\n)+)/m);
  if (blockForm) {
    return blockForm[1]
      .split('\n')
      .map((l) => l.replace(/^ {6}- /, '').trim())
      .filter(Boolean);
  }
  return [];
}

/** All `if:` expression texts declared at JOB level (4-space indent) within a block. */
export function jobLevelIfs(blockText) {
  return [...blockText.matchAll(/^ {4}if:[ \t]*(.+)$/gm)].map((m) => normalizeExpr(m[1]));
}
