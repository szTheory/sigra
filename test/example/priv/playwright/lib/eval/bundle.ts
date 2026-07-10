/**
 * bundle.ts — write a per-surface×cell evidence bundle keyed on app_git_sha.
 *
 * Given the captured post-hydration outerHTML, PNG, axe JSON, computed-style
 * facts, and probe findings, writes a bundle under:
 *
 *   test/example/priv/playwright/eval/<appGitSha>/<surface>/<theme>-<viewport>-<state>/
 *
 * Files written per cell:
 *   dom.html       — raw outerHTML (as captured from browser)
 *   screenshot.png — PNG buffer
 *   axe.json       — raw axe violations JSON
 *   facts.json     — computed-style + geometry facts (raw floats OK: not hash inputs)
 *   findings.json  — probe findings array
 *   bundle.json    — manifest: app_git_sha, surface, cell, render_sha256, findings summary
 *
 * The entire eval/ tree is gitignored (Plan 01). Upload as a CI artifact.
 *
 * Phase 216-03 Plan, HARNESS-01 requirement (D-04, D-05).
 */

import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { renderSha256 } from './canonicalize.ts';

// Resolve the playwright subproject root (test/example/priv/playwright/)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// lib/eval/ is two levels deep from the playwright root
const PW_ROOT = join(__dirname, '..', '..');

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * Computed-style and geometry facts captured in-browser via page.evaluate.
 * Stored in facts.json as-is (raw floats). NOT hashed — hash inputs live in
 * the canonicalized DOM only (D-06, D-11).
 */
export interface BundleFacts {
  /** Root font size in px (for rem→px normalization) */
  rootFontPx?: number;
  /** --sg-space-N token values in px */
  spaceScale?: number[];
  /** --sg-radius-{xs,sm,md,lg} token values in px */
  radiusScale?: number[];
  /** --sg-control-{xs,sm,md,lg} token values in px */
  controlScale?: number[];
  /** Viewport dimensions at capture time */
  viewport?: { width: number; height: number };
  /** Arbitrary additional facts (probe-specific geometry, etc.) */
  [key: string]: unknown;
}

/**
 * A single probe finding emitted by the in-browser probes.
 * probe_class maps to the probe class string used in finding_id computation.
 */
export interface ProbeFinding {
  /** Probe class (e.g. 'off-token-spacing', 'target-size') */
  probe_class: string;
  /**
   * Structural CSS selector / data-* hook identifying the DOM element.
   * MUST NOT be prose or a line number — must survive copy edits (D-09).
   */
  anchor: string;
  /** Human-readable description of the finding (for developer context only) */
  description: string;
  /** Severity: gate | warn */
  severity: 'gate' | 'warn';
  /** Optional additional evidence fields */
  [key: string]: unknown;
}

/**
 * Options for writeBundle.
 */
export interface WriteBundleOptions {
  /**
   * Git SHA of the app at capture time.
   * If omitted, resolved via `git rev-parse HEAD` at call time.
   */
  appGitSha?: string;
  /** Surface key (e.g. 'users-index-live') */
  surface: string;
  /** Theme: 'light' | 'dark' */
  theme: 'light' | 'dark';
  /** Viewport: 'desktop' | 'mobile' */
  viewport: 'desktop' | 'mobile';
  /** State: 'populated' | 'zero' | 'loading' | 'error' */
  state: 'populated' | 'zero' | 'loading' | 'error';
  /** Post-hydration outerHTML (raw, as captured from browser) */
  outerHTML: string;
  /** PNG screenshot buffer */
  pngBuffer: Buffer;
  /** Raw axe violations result */
  axeJson: object;
  /** Computed-style + geometry facts captured in-browser */
  facts: BundleFacts;
  /** Probe findings for this cell */
  findings: ProbeFinding[];
}

/**
 * Result of writeBundle — the bundle directory path and computed SHA.
 */
export interface WriteBundleResult {
  /** Absolute path to the bundle directory */
  bundleDir: string;
  /** Computed render_sha256 for this cell */
  renderSha: string;
  /** Cell key: <theme>-<viewport>-<state> */
  cell: string;
  /** The appGitSha used (resolved if not passed) */
  appGitSha: string;
}

// ── Implementation ────────────────────────────────────────────────────────────

/**
 * Resolve the current HEAD sha via git.
 * Used as the default appGitSha if none is passed.
 */
function resolveHeadSha(): string {
  try {
    return execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
  } catch {
    throw new Error(
      'bundle.ts: could not resolve git HEAD sha. ' +
        'Pass appGitSha explicitly, or ensure git is available.'
    );
  }
}

/**
 * Write a per-surface×cell evidence bundle to disk.
 *
 * The bundle is written under:
 *   PW_ROOT/eval/<appGitSha>/<surface>/<theme>-<viewport>-<state>/
 *
 * The eval/ tree is gitignored. Upload as a CI artifact.
 *
 * @returns The bundle directory path and computed render_sha256.
 */
export function writeBundle(opts: WriteBundleOptions): WriteBundleResult {
  const appGitSha = (opts.appGitSha ?? resolveHeadSha()).trim();
  const cell = `${opts.theme}-${opts.viewport}-${opts.state}`;

  // Build the bundle directory path
  const bundleDir = join(PW_ROOT, 'eval', appGitSha, opts.surface, cell);

  // Create all parent directories
  mkdirSync(bundleDir, { recursive: true });

  // Compute render_sha256 from the canonicalized DOM (NEVER from raw geometry)
  const renderSha = renderSha256(opts.outerHTML);

  // Write dom.html — raw captured outerHTML
  writeFileSync(join(bundleDir, 'dom.html'), opts.outerHTML, 'utf8');

  // Write screenshot.png
  writeFileSync(join(bundleDir, 'screenshot.png'), opts.pngBuffer);

  // Write axe.json — raw axe violations result
  writeFileSync(join(bundleDir, 'axe.json'), JSON.stringify(opts.axeJson, null, 2), 'utf8');

  // Write facts.json — computed-style + geometry facts (raw floats; NOT hash inputs)
  writeFileSync(join(bundleDir, 'facts.json'), JSON.stringify(opts.facts, null, 2), 'utf8');

  // Write findings.json — probe findings array
  writeFileSync(
    join(bundleDir, 'findings.json'),
    JSON.stringify(opts.findings, null, 2),
    'utf8'
  );

  // Build findings summary counts by severity
  const findingsByGate = opts.findings.filter((f) => f.severity === 'gate').length;
  const findingsByWarn = opts.findings.filter((f) => f.severity === 'warn').length;

  // Write bundle.json — manifest
  const manifest = {
    app_git_sha: appGitSha,
    surface: opts.surface,
    cell,
    render_sha256: renderSha,
    findings_summary: {
      total: opts.findings.length,
      gate: findingsByGate,
      warn: findingsByWarn,
    },
  };
  writeFileSync(join(bundleDir, 'bundle.json'), JSON.stringify(manifest, null, 2), 'utf8');

  return {
    bundleDir,
    renderSha,
    cell,
    appGitSha,
  };
}
