/**
 * Shared anchor utilities for the Sigra admin eval harness (Phase 217, Plan 01).
 *
 * Extracted from scripts/ci/evidence-anchor-check.mjs so that downstream guards
 * (panel-forced-floor-check.mjs, etc.) can reuse the same logic without
 * duplicating declarations.
 *
 * Security invariant (T-216-04-INJECT):
 *   - Anchors must be CSS selector syntax — never eval'd or shell-interpolated.
 *   - `isStructuralAnchor` is the gatekeeper; all callers must invoke it before
 *     passing an anchor to cheerio $().
 */

// ---------------------------------------------------------------------------
// Anchor format validation — a valid anchor MUST look like a CSS selector or
// data-* hook, never plain prose or a line number. We reject anchors that:
//   - Are plain prose (natural-language phrase without selector syntax)
//   - Look like a file:line reference (path/to/file.ex:123)
//   - Are empty or whitespace-only
//
// A structural selector must start with one of:
//   - '.' (class selector)      e.g. .sg-btn
//   - '#' (id selector)         e.g. #surface-root
//   - '[' (attribute selector)  e.g. [data-testid="foo"]
//   - ':' (pseudo-class)        e.g. :root
//   - A single valid HTML tag name (e.g. "button", "div") — not multi-word prose
//
// CSS descendant combinator patterns (e.g. "div .sg-btn") are allowed, but
// prose phrases (e.g. "the Save button label") are rejected because:
//   - They start with a word that contains uppercase letters mid-sentence, OR
//   - They match the natural-language pattern (multiple space-separated plain words
//     without any selector-syntax character like '.', '#', '[', ':', '>')
//
// This is a structural check, not a full CSS parse.
// (D-09 + T-216-04-INJECT)
// ---------------------------------------------------------------------------

/**
 * Returns true if the anchor string looks like valid CSS selector syntax.
 * Returns false if it looks like prose or a line-number reference.
 *
 * @param {string} anchor
 * @returns {boolean}
 */
export function isStructuralAnchor(anchor) {
  if (typeof anchor !== 'string' || anchor.trim() === '') return false;
  const a = anchor.trim();

  // Reject source file:line references
  if (/\.(ex|exs|ts|tsx|js|jsx):\d+/.test(a)) return false;

  // Valid structural selectors must start with a selector-syntax character.
  // Allowed starting characters: . # [ : or a single bare HTML tag name.
  const firstChar = a[0];
  if (['.', '#', '[', ':'].includes(firstChar)) return true;

  // Bare HTML tag name — must be a single word matching known tag pattern,
  // optionally followed by CSS combinators and additional selectors.
  // Pattern: starts with a lowercase letter, can have alphanumeric/hyphen,
  // then optionally whitespace-combinator patterns or attribute/class/id suffixes.
  // Reject if the first "word" contains uppercase (likely prose, e.g. "the Save button").
  // After the tag name, a structural selector must be followed ONLY by selector
  // syntax characters — not arbitrary words with uppercase letters (prose).
  // The descendant combinator is a space, but only valid if what follows is a
  // selector token (.class, #id, [attr], :pseudo, tag-name), not uppercase prose.
  if (/^[a-z][a-z0-9-]*([.#\[: >~+*,]|$)/.test(a) && !/^[a-z][a-z0-9-]+\s+[A-Z]/.test(a)) return true;

  // Anything else (prose phrases, line numbers, descriptions) is rejected.
  return false;
}

// ---------------------------------------------------------------------------
// Geometry-only classes (D-09/D-11):
// These probes compute spatial facts (misalignment, below-fold position,
// focus-ring rendering) that require a live layout engine at capture time.
// The anchor-presence check still runs for these — we assert the anchor
// resolves in the DOM — but we do NOT re-check the geometry value here.
//
// Source of truth: the probe_class literals emitted by probes.ts (216-08).
// Real emitter strings: 'misalignment', 'focus-ring', 'below-fold-primary'.
// (The old entry 'below-fold' did not match any emitted class — replaced with
// 'below-fold-primary' so the geometry-note branch is reachable on real bundles.)
// ---------------------------------------------------------------------------
export const GEOMETRY_ONLY_CLASSES = new Set([
  'misalignment',
  'below-fold-primary',
  'focus-ring',
]);
