/**
 * Shared panel schema and finding_id helper (Phase 217, Plan 01).
 *
 * Exports:
 *   findingId(surface, klass, anchor) — byte-identical to the 216 formula in
 *     enrichFindingsForBundle (admin-eval.spec.ts), with `class = "lens:question"`
 *     per D-07 (e.g. "graphic_design:salience", "platform_admin:ia_muddy").
 *     Applies D-08 anchor canonicalization (quote-style/whitespace) before hashing.
 *
 *   PANEL_SCHEMA — the output_config.format JSON schema for LLM structured outputs
 *     (D-03/D-06). 12-cell grid (4 lenses × 3 questions); each cell is EITHER a
 *     verdict-!= keep finding with structural anchor + refutation, OR a keep with a
 *     non-empty none_searched_for literal. additionalProperties:false everywhere.
 *     No minimum/maximum/minLength/maxLength/multipleOf (D-03 schema-constraint limits).
 */

import { createHash } from 'node:crypto';

// ---------------------------------------------------------------------------
// Anchor canonicalization (D-08):
// Normalize quote-style (single → double) and trim whitespace before hashing
// so that semantically identical anchors produce the same finding_id regardless
// of formatting differences introduced by different LLM samples.
// ---------------------------------------------------------------------------

/**
 * Canonicalize an anchor string before hashing:
 *   1. Trim leading/trailing whitespace.
 *   2. Normalize attribute selector quotes to double-quoted form
 *      (e.g. [attr='val'] → [attr="val"]).
 *
 * @param {string} anchor
 * @returns {string}
 */
function canonicalizeAnchor(anchor) {
  if (typeof anchor !== 'string') return anchor;
  // Trim whitespace
  let a = anchor.trim();
  // Normalize single-quoted attribute values to double-quoted
  // Pattern: [attr='value'] → [attr="value"]
  // Use a replace that handles the common CSS attribute selector form.
  a = a.replace(/\[([^\]]*?)='([^']*)'\]/g, '[$1="$2"]');
  return a;
}

// ---------------------------------------------------------------------------
// findingId — byte-identical to the 216 enrichFindingsForBundle formula
// (admin-eval.spec.ts) with D-07 class = "lens:question" convention.
// ---------------------------------------------------------------------------

/**
 * Compute a deterministic finding_id for a panel finding.
 *
 * Uses the same NUL-delimited sha256 formula as Phase 216's enrichFindingsForBundle
 * so panel finding_ids, settled-findings.tsv waivers, and the fix queue share
 * the same key space (D-07/AUTOFIX-01).
 *
 * `klass` is the "lens:question" string (e.g. "graphic_design:salience",
 * "platform_admin:ia_muddy") — it occupies the `class` slot in the hash.
 *
 * D-08: anchor is canonicalized (quote-style + whitespace) before hashing.
 *
 * @param {string} surface - the bundle surface string (e.g. "users-index-live")
 * @param {string} klass   - "lens:question" string (e.g. "graphic_design:salience")
 * @param {string} anchor  - structural CSS selector (canonicalized before hashing)
 * @returns {string} 64-character lowercase hex SHA-256 digest
 */
export function findingId(surface, klass, anchor) {
  const canonAnchor = canonicalizeAnchor(anchor);
  return createHash('sha256')
    .update(surface)
    .update('\0')
    .update(klass)
    .update('\0')
    .update(canonAnchor)
    .digest('hex');
}

// ---------------------------------------------------------------------------
// PANEL_SCHEMA — output_config.format JSON schema (D-03/D-06)
//
// 4 lenses × 3 questions = 12 cells.
// Lenses:
//   1. platform_admin      — questions: earning_its_place, ia_muddy, redundant_coherent_surprising
//   2. support_investigator — questions: earning_its_place, ia_muddy, redundant_coherent_surprising
//   3. org_admin           — questions: earning_its_place, ia_muddy, redundant_coherent_surprising
//   4. graphic_design      — questions: salience, emphasis_ember, composition
//
// Each cell is EITHER:
//   (a) verdict != "keep": must carry structural `anchor` + `refutation` (finding)
//   (b) verdict == "keep": must carry non-empty `none_searched_for` literal
//       (e.g. "NONE — searched for: <what>")
//
// Schema constraints (D-03):
//   - `enum` for all string fields with bounded values (verdict, band, schema_version)
//   - `additionalProperties: false` on every object
//   - NO minimum/maximum/minLength/maxLength/multipleOf
//   - No recursion
// ---------------------------------------------------------------------------

// Shared cell schema: anyOf[finding, keep]
const CELL_SCHEMA = {
  type: 'object',
  anyOf: [
    // (a) Non-keep finding: verdict is "tighten" or "kill", structural anchor + refutation required
    {
      type: 'object',
      properties: {
        verdict: { type: 'string', enum: ['tighten', 'kill'] },
        anchor: { type: 'string' },
        refutation: { type: 'string' },
        observation: { type: 'string' },
        evidence_cell: { type: 'string', enum: ['light', 'dark', 'both'] },
        schema_version: { type: 'string', enum: ['217-01'] },
      },
      required: ['verdict', 'anchor', 'refutation'],
      additionalProperties: false,
    },
    // (b) Keep: verdict is "keep", none_searched_for must be non-empty
    {
      type: 'object',
      properties: {
        verdict: { type: 'string', enum: ['keep'] },
        none_searched_for: { type: 'string' },
        schema_version: { type: 'string', enum: ['217-01'] },
      },
      required: ['verdict', 'none_searched_for'],
      additionalProperties: false,
    },
  ],
};

// Persona lens block (3 questions: earning_its_place, ia_muddy, redundant_coherent_surprising)
const PERSONA_LENS_SCHEMA = {
  type: 'object',
  properties: {
    earning_its_place: CELL_SCHEMA,
    ia_muddy: CELL_SCHEMA,
    redundant_coherent_surprising: CELL_SCHEMA,
  },
  required: ['earning_its_place', 'ia_muddy', 'redundant_coherent_surprising'],
  additionalProperties: false,
};

// Graphic design lens block (3 questions: salience, emphasis_ember, composition)
const GRAPHIC_DESIGN_LENS_SCHEMA = {
  type: 'object',
  properties: {
    salience: CELL_SCHEMA,
    emphasis_ember: CELL_SCHEMA,
    composition: CELL_SCHEMA,
  },
  required: ['salience', 'emphasis_ember', 'composition'],
  additionalProperties: false,
};

/**
 * The output_config.format JSON schema for the LLM panel structured output.
 * 12 cells (4 lenses × 3 questions). Passed directly as the schema value in
 * the Anthropic SDK output_config.format option.
 *
 * Obeys D-03 schema-constraint limits:
 *   - enum strings for bounded values
 *   - additionalProperties: false on all objects
 *   - NO minimum/maximum/minLength/maxLength/multipleOf
 */
export const PANEL_SCHEMA = {
  type: 'object',
  properties: {
    platform_admin: PERSONA_LENS_SCHEMA,
    support_investigator: PERSONA_LENS_SCHEMA,
    org_admin: PERSONA_LENS_SCHEMA,
    graphic_design: GRAPHIC_DESIGN_LENS_SCHEMA,
  },
  required: ['platform_admin', 'support_investigator', 'org_admin', 'graphic_design'],
  additionalProperties: false,
};
