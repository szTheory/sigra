/**
 * canonicalize.ts — parse5 allowlist tree-walk → render_sha256
 *
 * Converts post-hydration outerHTML into a reproducible sha256 by:
 *  - Stripping ALL volatile per-request attrs (data-phx-*, phx-*, nonce, integrity, id)
 *  - Allowlist-keeping only semantic attrs: type, name, role, aria-label, alt, data-testid
 *  - Keeping href (with ?vsn= and 32-hex digest fingerprints stripped)
 *  - Keeping class (tokens sorted)
 *  - Sorting all remaining attrs by name
 *  - Normalizing text: collapsing whitespace runs, dropping whitespace-only nodes
 *  - Walking the tree in depth-first order (preserving tag structure)
 *
 * Design: allowlist-not-denylist (a denylist rots on every LiveView release — D-06).
 * Geometry facts must NOT enter renderSha256. Store them in bundle.facts only.
 *
 * Phase 216-03 Plan, HARNESS-01 requirement.
 */

import { parseFragment } from 'parse5';
import { createHash } from 'node:crypto';

// ── Allowlist and volatile sets ───────────────────────────────────────────────

/**
 * Semantic attrs we keep (allowlist).
 * href is kept separately (needs fingerprint-stripping).
 * class is kept separately (needs token-sorting).
 */
const KEEP_ATTRS = new Set(['type', 'name', 'role', 'aria-label', 'alt', 'data-testid']);

/**
 * Volatile attr prefixes — all LiveView / Phoenix runtime attrs.
 * Any attr whose name STARTS WITH one of these is dropped entirely.
 */
const VOLATILE_PREFIXES: string[] = ['data-phx-', 'phx-'];

/**
 * Volatile attrs by exact name — dropped entirely.
 * Per D-06: drop `id` (LiveView generates phx-* ids that leak per-render).
 * Exception: `id` is kept if the same element also has a `data-testid`.
 * But because we process attrs individually (without element context) we
 * apply the simplest safe rule: always drop `id`.
 * If an element needs stable identity for selector anchoring, use data-testid.
 */
const VOLATILE_EXACT = new Set(['nonce', 'integrity', 'id']);

// ── Fingerprint stripping helpers ─────────────────────────────────────────────

/**
 * Strips ?vsn= and &vsn= query params from a URL value.
 * Also strips 32-hex-char digest fingerprints from path segments.
 *
 * Examples:
 *   /app.js?vsn=abc123de           → /app.js
 *   /app.js?foo=1&vsn=abc&bar=2    → /app.js?foo=1&bar=2
 *   /app-abcdef1234567890abcdef1234567890.js → /app-.js
 */
function stripVsn(value: string): string {
  // Remove ?vsn=... (to end of string or next &)
  let stripped = value.replace(/[?&]vsn=[^&"'\s]*/g, (match) => {
    // If the match starts with ?, replace it with ? only if there are remaining params
    // Otherwise remove the ? too
    return match.startsWith('?') ? '' : '';
  });
  // Clean up orphaned ? or & at the end or double &&
  stripped = stripped.replace(/\?$/, '').replace(/&&/g, '&').replace(/\?&/, '?');
  // Remove 32-hex-char digest fingerprints from path components
  // e.g. app-abcdef1234567890abcdef1234567890.js → app-.js
  stripped = stripped.replace(/-[0-9a-f]{32}(\.\w+)/gi, '$1');
  return stripped;
}

// ── Attribute canonicalization ────────────────────────────────────────────────

interface Attr {
  name: string;
  value: string;
}

/**
 * Canonicalize the attribute list for a single element:
 *  1. Drop volatile-prefix attrs (data-phx-*, phx-*)
 *  2. Drop volatile-exact attrs (nonce, integrity, id)
 *  3. Strip fingerprints from href
 *  4. Sort class tokens
 *  5. Keep only allowlisted attrs (plus href and class)
 *  6. Sort the remaining attrs by name
 */
function canonAttrs(attrs: Attr[]): Attr[] {
  const out: Attr[] = [];
  for (const { name, value } of attrs) {
    // Drop volatile prefixes
    if (VOLATILE_PREFIXES.some((p) => name.startsWith(p))) continue;
    // Drop volatile exact
    if (VOLATILE_EXACT.has(name)) continue;
    // href: keep but strip fingerprints
    if (name === 'href') {
      out.push({ name, value: stripVsn(value) });
      continue;
    }
    // class: keep but sort tokens
    if (name === 'class') {
      const sorted = value
        .split(/\s+/)
        .filter(Boolean)
        .sort()
        .join(' ');
      out.push({ name, value: sorted });
      continue;
    }
    // Keep allowlisted attrs
    if (KEEP_ATTRS.has(name)) {
      out.push({ name, value });
    }
    // All other attrs are silently dropped (allowlist semantics)
  }
  // Sort attrs by name for determinism
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// ── Tree walker ───────────────────────────────────────────────────────────────

// parse5 node shape (minimal, sufficient for our use)
interface TextNode {
  nodeName: '#text';
  value: string;
}

interface ElementNode {
  nodeName: string;
  tagName: string;
  attrs: Attr[];
  childNodes: ParseNode[];
}

interface FragmentNode {
  nodeName: '#document-fragment';
  childNodes: ParseNode[];
}

type ParseNode = TextNode | ElementNode | FragmentNode | { nodeName: string; childNodes?: ParseNode[] };

/**
 * Depth-first tree walk that produces a deterministic canonical string.
 *
 * - Text nodes: collapse whitespace runs, drop if whitespace-only
 * - Element nodes: serialize as `<tagName attr=value>children`
 * - Fragment / other nodes: recurse into childNodes
 */
function walk(node: ParseNode): string {
  // Text node
  if (node.nodeName === '#text') {
    const textNode = node as TextNode;
    const t = (textNode.value ?? '').replace(/\s+/g, ' ').trim();
    return t ? `#${t}` : '';
  }

  // Element node
  if ('tagName' in node) {
    const el = node as ElementNode;
    const canonicalized = canonAttrs(el.attrs ?? []);
    const attrStr = canonicalized.map((a) => `${a.name}=${a.value}`).join(' ');
    const kids = (el.childNodes ?? []).map(walk).join('');
    return `<${el.tagName}${attrStr ? ' ' + attrStr : ''}>${kids}`;
  }

  // Fragment or other container — recurse into children
  const container = node as { childNodes?: ParseNode[] };
  return (container.childNodes ?? []).map(walk).join('');
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Compute a reproducible sha256 over the canonicalized DOM.
 *
 * Given a post-hydration outerHTML string, strips all volatile per-request
 * attributes, sorts remaining attrs + class tokens, normalizes whitespace,
 * and returns a 64-char lowercase hex sha256 of the canonical form.
 *
 * Geometry facts must NOT be passed into this function. Store them in
 * bundle.facts (see bundle.ts) for probe consumption.
 *
 * @param outerHTML - Post-hydration HTML string (full page or fragment)
 * @returns 64-char lowercase hex sha256
 */
export function renderSha256(outerHTML: string): string {
  const doc = parseFragment(outerHTML) as ParseNode;
  const canon = walk(doc);
  return createHash('sha256').update(canon).digest('hex');
}
