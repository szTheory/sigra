/**
 * probes.ts — nine deterministic visual probes for the Sigra admin eval harness.
 *
 * Each probe runs via `page.evaluate` and reads the live `--sg-*` scale from
 * `:root` via `getComputedStyle`. Findings are tagged with the canonical probe
 * id from `scripts/ci/lib/eval-probe-ids.mjs`.
 *
 * Non-negotiables (Phase 216, D-11..D-16):
 *   - Read --sg-* via getPropertyValue — NEVER use the Playwright CSS-value matcher for custom props (#12629)
 *   - Read box LONGHANDS (paddingTop/Right/Bottom/Left, four radius corners), never shorthand
 *   - clamp()/color-mix()/oklab already resolve to concrete values under getComputedStyle
 *   - Focus-ring probe (#7) diffs computed box-shadow, NOT outline
 *   - Target-size (#6) uses @axe-core/playwright with explicit target-size enable
 *   - Card-in-card (#8) lifts admin-design.spec.ts:349-361 verbatim
 *   - Every probe honors data-sg-<probe>-audit-only suppression (D-14)
 *   - Severity tagged per D-15 gate/warn split
 *
 * Gate/warn split (D-15):
 *   HARD GATE: off-token-spacing, ember-reserved-for, off-scale-radius-shadow-control,
 *              target-size, focus-ring, card-in-card
 *   WARN-ONLY: misalignment, size-weight-budget, below-fold-primary
 *
 * Phase 216 Plan 08: board-root scoping (Gap 1 fix).
 *   - Element-scan candidate loops scope to the board root (boardRoot arg).
 *   - Design-token reads (--sg-space-*, --sg-radius-*, --sg-control-*, --sg-color-ember*)
 *     remain global (document.documentElement / :root) — NEVER moved under board root.
 *
 * D-08 (Phase 218): PROBE_IDS is defined locally as a typed const array and a deep-equal
 * self-test (probeIdsDriftCheck) verifies it matches scripts/ci/lib/eval-probe-ids.mjs at
 * runtime. Direct import is not used because Playwright's CJS transform cannot resolve
 * cross-tree .mjs imports (same interop class as the import.meta.url workaround in
 * admin-eval.spec.ts). The drift check catches any divergence between the two definitions.
 */

import type { Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { ProbeFinding } from './bundle.ts';

// ── Probe IDs — local typed const (D-08 single-source: deep-equal drift check below) ─────────
// The canonical source is scripts/ci/lib/eval-probe-ids.mjs. Playwright's CJS transform
// cannot resolve cross-tree .mjs imports (same interop class as the import.meta.url workaround
// documented in admin-eval.spec.ts), so the import is not used directly here. Instead, a
// deep-equal self-test (probeIdsDriftCheck) fails at test-time if the two arrays diverge.

export const PROBE_IDS = Object.freeze([
  'off-token-spacing',
  'misalignment',
  'size-weight-budget',
  'ember-reserved-for',
  'off-scale-radius-shadow-control',
  'target-size',
  'focus-ring',
  'card-in-card',
  'below-fold-primary',
] as const);

/**
 * D-08 drift check: reads the canonical PROBE_IDS from scripts/ci/lib/eval-probe-ids.mjs
 * at runtime and asserts deep equality with the local PROBE_IDS above.
 * Call this once at module load or in a test setup; a mismatch fails loudly.
 *
 * Direct import of eval-probe-ids.mjs is not used because Playwright's CJS transform
 * cannot resolve cross-tree .mjs imports (same interop class as the import.meta.url
 * workaround documented in admin-eval.spec.ts). Instead, this function reads the source
 * text and parses the canonical array, then deep-equals it against PROBE_IDS above.
 */
export function probeIdsDriftCheck(): void {
  // Path: probes.ts is at test/example/priv/playwright/lib/eval/probes.ts
  // eval-probe-ids.mjs is at scripts/ci/lib/eval-probe-ids.mjs
  // From probes.ts: ../../../../../../scripts/ci/lib/eval-probe-ids.mjs
  const probeIdsPath = join(__dirname, '..', '..', '..', '..', '..', '..', 'scripts', 'ci', 'lib', 'eval-probe-ids.mjs');
  let canonicalIds: string[];
  try {
    const src = readFileSync(probeIdsPath, 'utf8');
    // Extract the ordered array from the PROBE_IDS Object.freeze([...]) export
    const match = src.match(/export const PROBE_IDS\s*=\s*Object\.freeze\(\[([\s\S]*?)\]\)/);
    if (!match) throw new Error('Could not parse PROBE_IDS from eval-probe-ids.mjs');
    canonicalIds = match[1]
      .split(',')
      .map((s) => s.trim().replace(/^['"]|['"]$/g, ''))
      .filter((s) => s.length > 0);
  } catch (err) {
    throw new Error(`probeIdsDriftCheck: could not read canonical PROBE_IDS from eval-probe-ids.mjs: ${err}`);
  }

  const localIds = [...PROBE_IDS];
  const same =
    canonicalIds.length === localIds.length &&
    canonicalIds.every((id, i) => id === localIds[i]);

  if (!same) {
    throw new Error(
      `D-08 DRIFT DETECTED: probes.ts PROBE_IDS does not match eval-probe-ids.mjs!\n` +
      `  canonical: ${JSON.stringify(canonicalIds)}\n` +
      `  local:     ${JSON.stringify(localIds)}\n` +
      `Update probes.ts PROBE_IDS to match the canonical source.`,
    );
  }
}

export type ProbeId = (typeof PROBE_IDS)[number];

// ── Helper: rem→px epsilon tolerance ─────────────────────────────────────────

/**
 * Token-scale membership test: is `valuePx` within ±0.5px of any entry in
 * `scalePx` (the resolved pixel values of --sg-{space,radius,control}-* tokens)?
 */
function onScale(valuePx: number, scalePx: number[]): boolean {
  const EPSILON = 0.5;
  return scalePx.some((t) => Math.abs(valuePx - t) <= EPSILON);
}

// ── Probe #1: off-token-spacing ───────────────────────────────────────────────

/**
 * Probe #1 (gate): flags elements whose padding is NOT on the live --sg-space-*
 * scale (±0.5px tolerance). Reads longhands (paddingTop/Right/Bottom/Left).
 * Respects data-sg-off-token-spacing-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): element-scan queries boardRoot subtree.
 * Design-token reads (--sg-space-*) remain global (document.documentElement).
 */
export async function probeOffTokenSpacing(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    measured_px: number[];
    scale_px: number[];
  }> => {
    // Design-token reads remain GLOBAL — never moved under board root.
    const root = document.documentElement;
    const rootFs = parseFloat(getComputedStyle(root).fontSize) || 16;

    // Read live --sg-space-* scale from :root (global)
    const SPACE_STEPS = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12];
    const scalePx: number[] = SPACE_STEPS.map((n) => {
      const raw = getComputedStyle(root).getPropertyValue(`--sg-space-${n}`).trim();
      if (!raw) return NaN;
      if (raw.endsWith('rem')) return parseFloat(raw) * rootFs;
      if (raw.endsWith('px')) return parseFloat(raw);
      return parseFloat(raw);
    }).filter((v) => !isNaN(v));

    const onScale = (px: number) => scalePx.some((t) => Math.abs(px - t) <= 0.5);

    const findings: ReturnType<typeof probeOffTokenSpacing extends (...a: infer _) => infer R ? () => R : never>[] = [];
    const SUPPRESS = 'data-sg-off-token-spacing-audit-only';

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = boardRoot.querySelectorAll('[class*="sg-"]');
    for (const el of Array.from(candidates)) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;

      const cs = getComputedStyle(el);
      const padValues = [
        parseFloat(cs.paddingTop),
        parseFloat(cs.paddingRight),
        parseFloat(cs.paddingBottom),
        parseFloat(cs.paddingLeft),
      ].filter((v) => v > 0);

      const offScale = padValues.filter((v) => !onScale(v));
      if (offScale.length === 0) continue;

      // Build structural anchor
      const testId = el.getAttribute('data-testid');
      const anchor = testId
        ? `[data-testid="${testId}"]`
        : el.className
          ? `.${Array.from(el.classList).join('.')}`
          : el.tagName.toLowerCase();

      findings.push({
        probe_class: 'off-token-spacing',
        anchor,
        description: `padding values [${offScale.join(', ')}]px are not on the --sg-space-* scale`,
        severity: 'gate',
        measured_px: padValues,
        scale_px: scalePx,
      });
    }

    return findings;
  }, boardRoot);
}

// ── Probe #2: misalignment ────────────────────────────────────────────────────

/**
 * Probe #2 (warn): flags elements whose bounding-rect left/top falls at a
 * fractional (sub-pixel) offset from the pixel grid — any offset with a
 * fractional component in the (0.05, 0.95) band, regardless of magnitude.
 * Warn-only per D-15 (signal moves with font metrics).
 * Respects data-sg-misalignment-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): element-scan queries boardRoot subtree.
 */
export async function probeMisalignment(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    offset_px: { x: number; y: number };
  }> => {
    const SUPPRESS = 'data-sg-misalignment-audit-only';
    const findings: ReturnType<typeof probeMisalignment extends (...a: infer _) => infer R ? () => R : never>[] = [];

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = boardRoot.querySelectorAll('[class*="sg-"]');
    for (const el of Array.from(candidates)) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;

      const rect = el.getBoundingClientRect();
      const offsetX = rect.left % 1;
      const offsetY = rect.top % 1;

      // Flag any fractional (sub-pixel) offset in the (0.05, 0.95) band — not a bounded
      // pixel range, just the fractional component of the rect's left/top coordinate.
      const subPixelX = Math.abs(offsetX) > 0.05 && Math.abs(offsetX) < 0.95;
      const subPixelY = Math.abs(offsetY) > 0.05 && Math.abs(offsetY) < 0.95;

      if (!subPixelX && !subPixelY) continue;

      const testId = el.getAttribute('data-testid');
      const anchor = testId
        ? `[data-testid="${testId}"]`
        : el.className
          ? `.${Array.from(el.classList).join('.')}`
          : el.tagName.toLowerCase();

      findings.push({
        probe_class: 'misalignment',
        anchor,
        description: `element has sub-pixel offset: x=${rect.left.toFixed(2)}, y=${rect.top.toFixed(2)}`,
        severity: 'warn',
        offset_px: { x: rect.left, y: rect.top },
      });
    }

    return findings;
  }, boardRoot);
}

// ── Probe #3: size-weight-budget ──────────────────────────────────────────────

/**
 * Probe #3 (warn): flags surfaces with >5 distinct font-sizes or >3 distinct
 * font-weights among sg-* elements. Warn-only per D-15 (judgment-laden).
 * Respects data-sg-size-weight-budget-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): element-scan queries boardRoot subtree.
 */
export async function probeSizeWeightBudget(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    sizes: string[];
    weights: string[];
  }> => {
    const SUPPRESS = 'data-sg-size-weight-budget-audit-only';
    const MAX_SIZES = 5;
    const MAX_WEIGHTS = 3;

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = Array.from(boardRoot.querySelectorAll('[class*="sg-"]')).filter(
      (el) => !el.hasAttribute(SUPPRESS) && !el.closest(`[${SUPPRESS}]`),
    );

    const sizes = new Set<string>();
    const weights = new Set<string>();

    for (const el of candidates) {
      const cs = getComputedStyle(el);
      const fs = cs.fontSize;
      const fw = cs.fontWeight;
      if (fs) sizes.add(fs);
      if (fw) weights.add(fw);
    }

    const findings: ReturnType<typeof probeSizeWeightBudget extends (...a: infer _) => infer R ? () => R : never>[] = [];

    if (sizes.size > MAX_SIZES || weights.size > MAX_WEIGHTS) {
      findings.push({
        probe_class: 'size-weight-budget',
        anchor: '[class*="sg-"]',
        description: `${sizes.size} font sizes, ${weights.size} font weights (budget: ≤${MAX_SIZES} sizes, ≤${MAX_WEIGHTS} weights)`,
        severity: 'warn',
        sizes: Array.from(sizes),
        weights: Array.from(weights),
      });
    }

    return findings;
  }, boardRoot);
}

// ── Probe #4: ember-reserved-for ─────────────────────────────────────────────

/**
 * Probe #4 (gate): flags use of ember accent colors outside the reserved
 * selected/ownership context. Ember is reserved for selection/ownership; any
 * other use is off-brand. Respects data-sg-ember-reserved-for-audit-only.
 *
 * Board-root scoped (Gap 1 fix, 216-08): candidate element-scan queries boardRoot subtree.
 * Reserved-context set query (EMBER_RESERVED_SELECTORS) stays document-wide — it is a
 * containment membership test, not a finding source. Design-token reads (--sg-color-ember*)
 * remain global (document.documentElement / :root).
 */
export async function probeEmberReservedFor(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    color_value: string;
  }> => {
    const SUPPRESS = 'data-sg-ember-reserved-for-audit-only';
    const findings: ReturnType<typeof probeEmberReservedFor extends (...a: infer _) => infer R ? () => R : never>[] = [];

    // Reserved ember contexts: selection, ownership, active-indicator.
    // These are the CONTAINER selectors that legitimately hold ember-accented
    // elements. Query stays document-wide — reserved membership is a containment test.
    // NOTE: '.sg-ember' is intentionally NOT in this list — it is the CLASS we look
    // for as a potential misuse, not a reserved-context container. Adding it here
    // would prevent the probe from ever flagging any .sg-ember element (W1 fix, 216-09).
    // '[data-tone="ember"]' is also excluded for the same reason: it is the attribute
    // that marks intentional ember use, so elements carrying it are candidates for
    // the isEmberClass check, not containers that grant exemption.
    const EMBER_RESERVED_SELECTORS = [
      '[data-selected="true"]',
      '[data-owned="true"]',
      '[aria-selected="true"]',
      '[aria-current="true"]',
    ];

    const reservedSet = new Set<Element>();
    for (const sel of EMBER_RESERVED_SELECTORS) {
      document.querySelectorAll(sel).forEach((el) => reservedSet.add(el));
    }

    // Design-token reads remain GLOBAL — never moved under board root.
    // Note: '--sg-color-ember' and '--sg-color-ember-accent' are OPTIONAL custom
    // properties. The probe detects misuse by class name ('.sg-ember') regardless
    // of whether the token is defined (W2 fix, 216-09 — early-return guard was
    // preventing any finding when the token was absent from the computed styles).
    // The color values are retained for context in the finding record only.
    const root = document.documentElement;
    const emberColor = getComputedStyle(root).getPropertyValue('--sg-color-ember').trim();
    const emberAccent = getComputedStyle(root).getPropertyValue('--sg-color-ember-accent').trim();

    // Candidate element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = boardRoot.querySelectorAll('[class*="sg-"]');
    for (const el of Array.from(candidates)) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;
      // Check if this element is in a reserved context
      if (reservedSet.has(el) || Array.from(reservedSet).some((r) => r.contains(el) || el.contains(r))) continue;

      const cs = getComputedStyle(el);
      const color = cs.color;
      const bg = cs.backgroundColor;
      const borderColor = cs.borderColor;

      // Check for ember-like color usage on non-reserved elements.
      // Derived entirely from classList, never className -- className is an
      // SVGAnimatedString (not a plain string) on SVG elements, so calling a
      // string method there throws a TypeError. classList is a DOMTokenList
      // on both HTML and SVG elements, so scanning it is the SVG-safe
      // equivalent.
      const isEmberClass =
        el.classList.contains('sg-ember') ||
        Array.from(el.classList).some((c) => c.includes('ember'));
      if (!isEmberClass) continue;

      const testId = el.getAttribute('data-testid');
      const anchor = testId
        ? `[data-testid="${testId}"]`
        : `.${Array.from(el.classList).join('.')}`;

      findings.push({
        probe_class: 'ember-reserved-for',
        anchor,
        description: `ember accent used outside reserved selected/ownership context`,
        severity: 'gate',
        color_value: color || bg || borderColor,
      });
    }

    return findings;
  }, boardRoot);
}

// ── Probe #5: off-scale-radius-shadow-control ─────────────────────────────────

/**
 * Probe #5 (gate for radius+control, warn for shadow-composite): flags
 * border-radius and control-height values not on the live --sg-radius-N
 * --sg-control-N scale. Shadow-composite is warn-only per D-15.
 * Reads four corner longhands, never shorthand.
 * Respects data-sg-off-scale-radius-shadow-control-audit-only.
 *
 * Board-root scoped (Gap 1 fix, 216-08): element-scan queries boardRoot subtree.
 * Design-token reads (--sg-radius-*, --sg-control-*) remain global (document.documentElement).
 */
export async function probeOffScaleRadiusShadowControl(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    measured_px: number[];
    scale_px: number[];
  }> => {
    // Design-token reads remain GLOBAL — never moved under board root.
    const root = document.documentElement;
    const rootFs = parseFloat(getComputedStyle(root).fontSize) || 16;
    const SUPPRESS = 'data-sg-off-scale-radius-shadow-control-audit-only';

    const remToPx = (raw: string) => {
      if (raw.endsWith('rem')) return parseFloat(raw) * rootFs;
      if (raw.endsWith('px')) return parseFloat(raw);
      return parseFloat(raw);
    };

    // Read live --sg-radius-* scale (longhands by name, not shorthand) — GLOBAL
    const RADIUS_KEYS = ['xs', 'sm', 'md', 'lg'];
    const radiusScale: number[] = RADIUS_KEYS.map((k) => {
      const raw = getComputedStyle(root).getPropertyValue(`--sg-radius-${k}`).trim();
      return raw ? remToPx(raw) : NaN;
    }).filter((v) => !isNaN(v));
    // Add full (999px) to scale
    radiusScale.push(999);

    // Read live --sg-control-* scale — GLOBAL
    const CONTROL_KEYS = ['xs', 'sm', 'md', 'lg'];
    const controlScale: number[] = CONTROL_KEYS.map((k) => {
      const raw = getComputedStyle(root).getPropertyValue(`--sg-control-${k}`).trim();
      return raw ? remToPx(raw) : NaN;
    }).filter((v) => !isNaN(v));

    const onScale = (px: number, scale: number[]) =>
      scale.some((t) => Math.abs(px - t) <= 0.5);

    const findings: ReturnType<typeof probeOffScaleRadiusShadowControl extends (...a: infer _) => infer R ? () => R : never>[] = [];

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = boardRoot.querySelectorAll('[class*="sg-"]');
    for (const el of Array.from(candidates)) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;

      const cs = getComputedStyle(el);

      // Read border-radius LONGHANDS (four corners), never shorthand
      const corners = [
        parseFloat(cs.borderTopLeftRadius),
        parseFloat(cs.borderTopRightRadius),
        parseFloat(cs.borderBottomRightRadius),
        parseFloat(cs.borderBottomLeftRadius),
      ].filter((v) => v > 0);

      const offRadius = corners.filter((v) => !onScale(v, radiusScale));
      if (offRadius.length > 0) {
        const testId = el.getAttribute('data-testid');
        const anchor = testId
          ? `[data-testid="${testId}"]`
          : `.${Array.from(el.classList).join('.')}`;

        findings.push({
          probe_class: 'off-scale-radius-shadow-control',
          anchor,
          description: `border-radius corners [${offRadius.join(', ')}]px are not on --sg-radius-* scale`,
          severity: 'gate',
          measured_px: corners,
          scale_px: radiusScale,
        });
      }

      // Check control height (min-height or height for sg-btn, sg-input, etc.)
      //
      // 231-05 (D-08 reconciliation): `sg-applied-chip__remove` is deliberately NOT listed.
      // It was added here in Phase 216 (43b2a808) but that branch never actually executed
      // until 231-04 fixed the SVG `className` crash that aborted every prior render — so it
      // was an untested assumption, not a ratified tightening. When it finally ran (run
      // 30504235540, job 90750408342) it produced 8 gate failures that directly contradict
      // admin-quality-ledger.md:65, which ratifies the chip remove control at ~22x22 CSS px as
      // "reviewed - near-threshold, D-08 precedent for dense admin inline chip remove". The
      // --sg-control-* scale starts at 28px, so the ledger decision and this gate can never
      // both hold. The scale is a *form control* rhythm rule; a dense inline chip affordance is
      // not a form control, which is also why `sg-notice__link` (~21px inline action, likewise
      // ledger-"reviewed") is absent from this list.
      //
      // Target size remains guarded and is NOT dropped: board-applied_chip runs
      // assertNoAxeViolations across wcag2a/2aa/21a/21aa/22aa (2.5.8 target size) with 0
      // violations. Do not re-add this class here without first reconciling D-08 in the ledger;
      // if the dense-admin precedent is ever revisited, resize the CSS to a --sg-control-* step
      // instead of reinstating a gate the design system explicitly excepts.
      const isControl =
        el.classList.contains('sg-btn') ||
        el.classList.contains('sg-input') ||
        el.classList.contains('sg-select');

      if (isControl) {
        // IN-01: minHeight resolves to "0px" (truthy string) for controls sized purely via
        // `height`, so `cs.minHeight || cs.height` never falls through to height — numeric-guard
        // the fallback instead so those controls are not silently skipped by this gate.
        const mh = parseFloat(cs.minHeight);
        const h = mh > 0 ? mh : parseFloat(cs.height);
        if (h > 0 && !onScale(h, controlScale)) {
          const testId = el.getAttribute('data-testid');
          const anchor = testId
            ? `[data-testid="${testId}"]`
            : `.${Array.from(el.classList).join('.')}`;

          findings.push({
            probe_class: 'off-scale-radius-shadow-control',
            anchor,
            description: `control height ${h}px is not on --sg-control-* scale`,
            severity: 'gate',
            measured_px: [h],
            scale_px: controlScale,
          });
        }
      }

      // Shadow-composite: WARN-only
      const shadow = cs.boxShadow;
      if (shadow && shadow !== 'none') {
        // Flag composite shadows (multiple layers) as warn
        const layers = shadow.split(/,(?![^(]*\))/g);
        if (layers.length > 2) {
          const testId = el.getAttribute('data-testid');
          const anchor = testId
            ? `[data-testid="${testId}"]`
            : `.${Array.from(el.classList).join('.')}`;

          findings.push({
            probe_class: 'off-scale-radius-shadow-control',
            anchor,
            description: `composite box-shadow with ${layers.length} layers (may indicate off-system composition)`,
            severity: 'warn',
            measured_px: [],
            scale_px: [],
          });
        }
      }
    }

    return findings;
  }, boardRoot);
}

// ── Probe #6: target-size ─────────────────────────────────────────────────────

/**
 * Probe #6 (gate for <24×24, warn for <44×44 advisory): uses @axe-core/playwright
 * with target-size explicitly enabled (off by default — Pitfall 1 from D-14).
 * Respects data-sg-target-size-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): AxeBuilder uses .include(boardRoot) when
 * a board root is provided, so axe evaluates only the board subtree.
 */
export async function probeTargetSize(
  page: Page,
  boardRoot?: string,
): Promise<ProbeFinding[]> {
  // axe target-size is disabled by default and MUST be explicitly enabled
  const axeBuilder = new AxeBuilder({ page })
    .options({ rules: { 'target-size': { enabled: true } } });

  // Board-scope: constrain axe analysis to the board subtree (Gap 1 fix).
  if (boardRoot) {
    axeBuilder.include(boardRoot);
  }

  const results = await axeBuilder.analyze();

  const targetSizeViolations = results.violations.filter(
    (v) => v.id === 'target-size',
  );

  const findings: ProbeFinding[] = [];

  for (const violation of targetSizeViolations) {
    for (const node of violation.nodes) {
      // Check suppression attribute
      const suppress = await page.evaluate((selector: string) => {
        const el = document.querySelector(selector);
        if (!el) return false;
        return (
          el.hasAttribute('data-sg-target-size-audit-only') ||
          !!el.closest('[data-sg-target-size-audit-only]')
        );
      }, node.target[0] as string).catch(() => false);

      if (suppress) continue;

      findings.push({
        probe_class: 'target-size',
        anchor: node.target[0] as string,
        description: violation.description,
        severity: 'gate', // <24×24 hard gate; the 44×44 advisory is warn (D-15)
      });
    }
  }

  return findings;
}

// ── Probe #7: focus-ring ──────────────────────────────────────────────────────

/**
 * Probe #7 (gate): calls .focus() on interactive controls and PASSES if either
 * computed box-shadow OR outline changes. Diffs box-shadow specifically because
 * sigra_admin.css authors focus as box-shadow: var(--sg-focus-ring) — an
 * outline-only check would false-positive on every .sg-btn/chip/metric-link.
 * Respects data-sg-focus-ring-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): interactive-element scan queries boardRoot subtree.
 */
export async function probeFocusRing(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate(async (boardRootSel: string | undefined): Promise<Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    before_shadow: string;
    after_shadow: string;
  }>> => {
    const SUPPRESS = 'data-sg-focus-ring-audit-only';
    const findings: Array<{
      probe_class: string;
      anchor: string;
      description: string;
      severity: 'gate' | 'warn';
      before_shadow: string;
      after_shadow: string;
    }> = [];

    // Interactive elements that must have visible focus
    const interactiveSelectors = [
      'a[href]',
      'button:not([disabled])',
      'input:not([disabled]):not([type="hidden"])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
      '[role="button"]:not([disabled])',
      '[role="link"]',
    ].join(',');

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = Array.from(boardRoot.querySelectorAll(interactiveSelectors));

    for (const el of candidates) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;
      if (!(el instanceof HTMLElement)) continue;

      const before = getComputedStyle(el);
      const beforeShadow = before.boxShadow;
      const beforeOutline = before.outline;

      el.focus({ preventScroll: true });

      // Re-read after focus
      const after = getComputedStyle(el);
      const afterShadow = after.boxShadow;
      const afterOutline = after.outline;

      el.blur();

      const shadowChanged = beforeShadow !== afterShadow;
      const outlineChanged = beforeOutline !== afterOutline;

      // PASS if either changed — focus style is present
      if (shadowChanged || outlineChanged) continue;

      const testId = el.getAttribute('data-testid');
      const id = el.id;
      const anchor = testId
        ? `[data-testid="${testId}"]`
        : id
          ? `#${id}`
          : `.${Array.from(el.classList).join('.')}` || el.tagName.toLowerCase();

      findings.push({
        probe_class: 'focus-ring',
        anchor,
        description: `no visible focus indicator (box-shadow and outline both unchanged on :focus)`,
        severity: 'gate',
        before_shadow: beforeShadow,
        after_shadow: afterShadow,
      });
    }

    return findings;
  }, boardRoot);
}

// ── Probe #8: card-in-card ────────────────────────────────────────────────────

/**
 * Probe #8 (gate): detects .sg-card .sg-card nesting (excluding .sg-skeleton).
 * Lifted VERBATIM from admin-design.spec.ts:349-361 (D-14).
 * Honors data-sg-card-nesting-audit-only suppression on board containers.
 * Respects data-sg-card-in-card-audit-only suppression on individual elements.
 */
export async function probeCardInCard(
  page: Page,
  boardSelector = '.sg-card',
): Promise<ProbeFinding[]> {
  const nestedCards = await page.locator(boardSelector).evaluateAll(
    (boards: Element[]) =>
      boards.flatMap((board) => {
        if (board.hasAttribute('data-sg-card-nesting-audit-only')) return [];
        if (board.hasAttribute('data-sg-card-in-card-audit-only')) return [];
        const nested = board.querySelectorAll('.sg-card .sg-card:not(.sg-skeleton)');
        return Array.from(nested)
          .filter(
            (el) =>
              !el.hasAttribute('data-sg-card-nesting-audit-only') &&
              !el.hasAttribute('data-sg-card-in-card-audit-only') &&
              !el.closest('[data-sg-card-nesting-audit-only]') &&
              !el.closest('[data-sg-card-in-card-audit-only]'),
          )
          .map((element) => ({
            boardClass: board.getAttribute('class') ?? '',
            boardTestId: board.getAttribute('data-testid') ?? '',
            className: element.getAttribute('class') ?? '',
            testId: element.getAttribute('data-testid') ?? '',
          }));
      }),
  );

  return nestedCards.map(({ boardClass, boardTestId, className, testId }) => ({
    probe_class: 'card-in-card',
    anchor: testId
      ? `[data-testid="${testId}"]`
      : boardTestId
        ? `[data-testid="${boardTestId}"] .sg-card .sg-card`
        : `.${className.split(' ').join('.')}`,
    description: `nested .sg-card inside .sg-card (not .sg-skeleton) — violates card-in-card constraint`,
    severity: 'gate' as const,
  }));
}

// ── Probe #9: below-fold-primary ──────────────────────────────────────────────

/**
 * Probe #9 (warn): flags primary action buttons that are below the fold
 * (documentElement.clientHeight). Warn-only per D-15 — salience judgment
 * routes to the Phase-217 panel. Uses fold line via documentElement.clientHeight.
 * Respects data-sg-below-fold-primary-audit-only suppression.
 *
 * Board-root scoped (Gap 1 fix, 216-08): primary-selector candidate scan queries boardRoot.
 * Note: the fold is a viewport/page-level property (documentElement.clientHeight) — it stays
 * global. Gallery boards are isolated gallery components, so below-fold is semantically N/A
 * for isolated gallery-board surfaces (warn-only, D-15). This probe typically emits no
 * findings for gallery boards; that is correct and no cross-board anchor is emitted.
 */
export async function probeBelowFoldPrimary(page: Page, boardRoot?: string): Promise<ProbeFinding[]> {
  return page.evaluate((boardRootSel: string | undefined): Array<{
    probe_class: string;
    anchor: string;
    description: string;
    severity: 'gate' | 'warn';
    top_px: number;
    fold_px: number;
  }> => {
    const SUPPRESS = 'data-sg-below-fold-primary-audit-only';
    // Fold read stays GLOBAL — viewport property, not board property.
    const foldPx = document.documentElement.clientHeight;
    const findings: ReturnType<typeof probeBelowFoldPrimary extends (...a: infer _) => infer R ? () => R : never>[] = [];

    // Primary action selectors in the sg-* design system
    const primarySelectors = [
      '.sg-btn--primary',
      'button[type="submit"]:not([data-secondary])',
      '[role="button"][data-primary]',
    ].join(',');

    // Element-scan is board-root scoped (Gap 1 fix).
    const boardRoot = boardRootSel ? document.querySelector(boardRootSel) : document;
    if (!boardRoot) return [];
    const candidates = boardRoot.querySelectorAll(primarySelectors);
    for (const el of Array.from(candidates)) {
      if (el.hasAttribute(SUPPRESS) || el.closest(`[${SUPPRESS}]`)) continue;

      const rect = el.getBoundingClientRect();
      if (rect.top > foldPx) {
        const testId = el.getAttribute('data-testid');
        const id = el.id;
        const anchor = testId
          ? `[data-testid="${testId}"]`
          : id
            ? `#${id}`
            : `.${Array.from(el.classList).join('.')}`;

        findings.push({
          probe_class: 'below-fold-primary',
          anchor,
          description: `primary action at top=${rect.top.toFixed(0)}px is below fold at ${foldPx}px`,
          severity: 'warn',
          top_px: rect.top,
          fold_px: foldPx,
        });
      }
    }

    return findings;
  }, boardRoot);
}

// ── Run all probes ────────────────────────────────────────────────────────────

export interface ProbeRunOptions {
  /** Selector for the board/scope to restrict card-in-card probe and all element-scan probes */
  boardSelector?: string;
  /** CSS selector for the board container element — all element-scan probes scope to this subtree.
   *  e.g. '#board-mg-5'. When provided, boardSelector defaults to root for probe #8. */
  root?: string;
}

/**
 * Run all nine probes on the current page and return the combined findings.
 * The `isGateProject` flag controls whether gate-tier findings from the
 * mobile/dark projects are promoted to gate severity (D-15: gate in chromium
 * DPR1 only; warn in mobile/dark runs).
 *
 * Pass `root: '#board-mg-5'` to scope all element-scan probes to the board subtree
 * (Gap 1 fix, 216-08). Design-token reads remain global regardless of `root`.
 */
export async function runAllProbes(
  page: Page,
  options: { isGateProject?: boolean; boardSelector?: string; root?: string } = {},
): Promise<ProbeFinding[]> {
  const { isGateProject = true, root } = options;
  // boardSelector for probe #8: default to root when provided, else fall back to '.sg-card'
  const boardRoot = root ?? undefined;
  const boardSelector = options.boardSelector ?? root ?? '.sg-card';

  const [
    spacingFindings,
    misalignmentFindings,
    sizeWeightFindings,
    emberFindings,
    radiusFindings,
    targetSizeFindings,
    focusFindings,
    cardFindings,
    belowFoldFindings,
  ] = await Promise.all([
    probeOffTokenSpacing(page, boardRoot),
    probeMisalignment(page, boardRoot),
    probeSizeWeightBudget(page, boardRoot),
    probeEmberReservedFor(page, boardRoot),
    probeOffScaleRadiusShadowControl(page, boardRoot),
    probeTargetSize(page, boardRoot),
    probeFocusRing(page, boardRoot),
    probeCardInCard(page, boardSelector),
    probeBelowFoldPrimary(page, boardRoot),
  ]);

  const allFindings = [
    ...spacingFindings,
    ...misalignmentFindings,
    ...sizeWeightFindings,
    ...emberFindings,
    ...radiusFindings,
    ...targetSizeFindings,
    ...focusFindings,
    ...cardFindings,
    ...belowFoldFindings,
  ] as ProbeFinding[];

  // In non-gate projects (mobile/dark), demote gate findings to warn (D-15)
  if (!isGateProject) {
    return allFindings.map((f) => ({ ...f, severity: 'warn' as const }));
  }

  return allFindings;
}
