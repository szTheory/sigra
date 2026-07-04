/**
 * excerpt.mjs — deterministic anchor-preserving DOM canonicalization (Phase 217, Plan 05).
 *
 * Purpose: Canonicalize a captured DOM for LLM panel consumption while retaining the
 * structural anchors that `evidence-anchor-check.mjs` needs to resolve. This is a
 * variant of the Phase 216 `canonicalize.ts` D-06 rules that is adapted for the judge:
 *
 *   STRIPS (volatile — change every request, blow up render_sha256):
 *     - data-phx-* attributes (all LiveView runtime attrs)
 *     - phx-* attributes
 *     - nonce, integrity attributes
 *     - id attributes that start with "phx-" (LiveView-generated)
 *     - csrf token content (meta[name=csrf-token] content attr)
 *     - ?vsn= / &vsn= query params from href values
 *
 *   RETAINS (structural anchors — must survive so cited anchors round-trip evidence-anchor-check):
 *     - data-testid (primary stable anchor)
 *     - data-sg-* (brand/surface hooks)
 *     - role (ARIA landmark)
 *     - aria-label (ARIA annotation)
 *     - class tokens that begin with sg-* (semantic design-system classes)
 *     - type, name, alt (semantic form/media attrs)
 *
 *   NORMALIZES:
 *     - Text nodes: collapse whitespace runs, cap length to TEXT_CAP chars
 *     - class attr: retain ALL class tokens (sorted) for anchor fidelity — the LLM
 *       needs the full class list to resolve [class*=...] / .sg-* anchors
 *     - href: strip vsn fingerprints
 *
 * Pure function: given the same HTML input, always returns the same output string.
 * No IO, no network, no side effects.
 *
 * Resolves cheerio from the Playwright subproject node_modules using the same
 * `createRequire` pattern as `evidence-anchor-check.mjs` (D-01, D-09).
 *
 * @module excerpt
 */

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PW = path.join(ROOT, 'test', 'example', 'priv', 'playwright');
const _require = createRequire(path.join(PW, 'package.json'));
const { load: cheerioLoad } = _require('cheerio');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Maximum text-node character count after whitespace collapse (prevents prompt bloat). */
const TEXT_CAP = 200;

/**
 * Attribute prefixes to strip entirely (LiveView volatile attrs).
 * Any attr whose name STARTS WITH one of these is dropped.
 */
const VOLATILE_PREFIXES = ['data-phx-', 'phx-'];

/**
 * Exact attr names that are always dropped.
 * - nonce: CSP nonce, per-request
 * - integrity: SRI hash, fingerprint
 * Note: 'id' is handled separately (strip only if starts with 'phx-')
 */
const VOLATILE_EXACT = new Set(['nonce', 'integrity']);

/**
 * Structural attrs to ALWAYS retain (primary anchors for evidence-anchor-check).
 */
const RETAIN_ATTRS = new Set(['data-testid', 'role', 'aria-label', 'type', 'name', 'alt']);

// ---------------------------------------------------------------------------
// Helper: strip ?vsn= and &vsn= from a URL (href value)
// ---------------------------------------------------------------------------

/**
 * Remove vsn fingerprint query params and 32-hex path digest fingerprints from a URL.
 *
 * @param {string} value
 * @returns {string}
 */
function stripVsn(value) {
  // Remove ?vsn=... or &vsn=... segments
  let stripped = value.replace(/[?&]vsn=[^&"'\s]*/g, '');
  // Clean up orphaned separators left behind. IN-03: the single-pass chain below
  // is order-dependent and can leave a dangling separator for multi-vsn or
  // interleaved query strings, so collapse runs and then force-strip any trailing
  // separator as a final guarantee that the canonical form is minimal.
  stripped = stripped
    .replace(/&&+/g, '&') // collapse runs of &
    .replace(/\?&/, '?')  // ? immediately followed by & → ?
    .replace(/[?&]$/, ''); // strip any trailing ? or &
  // Remove 32-hex path digest fingerprints (e.g. app-abcdef1234567890abcdef1234567890.css → app-.css)
  stripped = stripped.replace(/-[0-9a-f]{32}(\.\w+)/gi, '$1');
  return stripped;
}

// ---------------------------------------------------------------------------
// Helper: filter and canonicalize a cheerio element's attributes
// ---------------------------------------------------------------------------

/**
 * Filter the attribute map of a cheerio element to keep only structural anchors
 * and non-volatile attrs, stripping volatile ones.
 *
 * Returns a plain object {name: value} of retained attrs, sorted by name.
 *
 * @param {Object} attribs - cheerio element.attribs map
 * @returns {Array<{name: string, value: string}>} sorted retained attrs
 */
function filterAttrs(attribs) {
  const out = [];

  for (const [name, value] of Object.entries(attribs)) {
    // Drop volatile prefixes (data-phx-*, phx-*)
    if (VOLATILE_PREFIXES.some((p) => name.startsWith(p))) continue;

    // Drop volatile exact names (nonce, integrity)
    if (VOLATILE_EXACT.has(name)) continue;

    // 'id' attr: drop if it starts with 'phx-' (LiveView-generated IDs)
    if (name === 'id') {
      if (value.startsWith('phx-')) continue;
      // Keep non-phx ids (stable ids from heex templates)
      out.push({ name, value });
      continue;
    }

    // href: retain but strip vsn fingerprints
    if (name === 'href') {
      out.push({ name, value: stripVsn(value) });
      continue;
    }

    // 'content' on meta[name=csrf-token]: drop the token value
    // (the calling context checks for csrf-token before calling, but we guard here too)
    // We handle this by stripping the content attr entirely for csrf meta tags
    // — handled at element level below in excerptHtml

    // class attr: retain ALL class tokens (sorted for determinism).
    // IN-02: we intentionally do NOT filter to sg-*/semantic tokens — the DOM
    // consumer (LLM) needs the complete class list to resolve anchors like
    // [class*=...] and .sg-*. Sorting keeps the excerpt byte-stable.
    if (name === 'class') {
      const tokens = value.split(/\s+/).filter(Boolean);
      const sorted = tokens.sort().join(' ');
      if (sorted) {
        out.push({ name, value: sorted });
      }
      continue;
    }

    // data-sg-* attributes: always retain (structural brand/surface hooks)
    if (name.startsWith('data-sg-')) {
      out.push({ name, value });
      continue;
    }

    // Structurally retained attrs
    if (RETAIN_ATTRS.has(name)) {
      out.push({ name, value });
      continue;
    }

    // All other attrs are dropped (allowlist semantics for structural anchoring)
  }

  // Sort by name for determinism
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// ---------------------------------------------------------------------------
// Serialization helpers
// ---------------------------------------------------------------------------

/**
 * Serialize a cheerio element tree to a canonical string.
 * Uses depth-first recursion.
 *
 * @param {Object} $el - cheerio element
 * @param {Function} $ - cheerio instance
 * @returns {string}
 */
function serializeEl($, el) {
  if (el.type === 'text') {
    // Collapse whitespace and cap length
    const t = (el.data || '').replace(/\s+/g, ' ').trim();
    if (!t) return '';
    return t.length > TEXT_CAP ? t.slice(0, TEXT_CAP) + '…' : t;
  }

  if (el.type === 'comment') return '';

  if (el.type === 'tag') {
    const tagName = el.name || '';

    // Skip script and style elements entirely (no prompt value, can be large)
    if (tagName === 'script' || tagName === 'style') return '';

    // Skip meta[name=csrf-token] entirely (strips the token)
    if (tagName === 'meta') {
      const metaName = (el.attribs || {}).name || '';
      if (metaName === 'csrf-token') return '';
    }

    const attrs = filterAttrs(el.attribs || {});
    const attrStr = attrs.map((a) => `${a.name}="${a.value}"`).join(' ');

    // Recurse into children
    const children = (el.children || []).map((child) => serializeEl($, child)).join('');

    // Void elements (self-closing in HTML5)
    const voidTags = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
      'link', 'meta', 'param', 'source', 'track', 'wbr']);
    if (voidTags.has(tagName)) {
      return `<${tagName}${attrStr ? ' ' + attrStr : ''}>`;
    }

    return `<${tagName}${attrStr ? ' ' + attrStr : ''}>${children}</${tagName}>`;
  }

  // Document or fragment root: recurse into children
  if (el.children) {
    return el.children.map((child) => serializeEl($, child)).join('');
  }

  return '';
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Canonicalize a DOM HTML string for LLM panel consumption.
 *
 * Strips all volatile per-request attributes (data-phx-*, nonce, id^=phx-, csrf,
 * ?vsn=) while retaining the structural anchors that `evidence-anchor-check.mjs`
 * needs to resolve (data-testid, data-sg-*, role, aria-label, sg-* classes).
 *
 * Text nodes are length-capped to prevent prompt bloat. The function is pure:
 * given the same HTML input, it always returns the same output string.
 *
 * @param {string} html - Raw DOM HTML (full page outerHTML or fragment)
 * @returns {string} Canonicalized HTML excerpt suitable for LLM panel input
 */
export function excerptHtml(html) {
  if (!html || typeof html !== 'string') return '';

  const $ = cheerioLoad(html, { xmlMode: false });

  // Serialize from the root(s) of the parsed document
  const root = $.root();
  const children = root[0] ? root[0].children || [] : [];
  return children.map((child) => serializeEl($, child)).join('');
}
