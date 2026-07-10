/**
 * Single source of truth for the nine canonical visual probe ids used by the
 * Sigra admin eval harness (Phase 216, D-12 "never duplicate constant tables").
 *
 * These ids are shared between:
 *   - scripts/ci/award-guard.mjs   (evidence_ref resolution, Plan 05)
 *   - tests/admin-eval.spec.ts / probes.ts (Plan 06 — proof IDs live here, not duplicated)
 *
 * The id strings are intentionally lowercase-kebab so they are safe as JSON
 * keys, file-system path components, and CSS selector fragments.
 *
 * Gate/warn split (CONTEXT D-15):
 *   HARD GATE: off-token-spacing, ember-reserved-for, off-scale-radius-shadow-control,
 *              target-size, focus-ring, card-in-card
 *   WARN-ONLY: misalignment, size-weight-budget, below-fold-primary
 */

// Ordered list — first six are hard-gate probes; last three are warn-only.
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
]);

// Fast lookup set derived from the array (O(1) membership test).
const PROBE_ID_SET = new Set(PROBE_IDS);

/**
 * Resolve an evidence_ref string to a boolean indicating whether it
 * identifies a known, verifiable piece of evidence.
 *
 * Accepted forms:
 *   probe:<one-of-the-nine>    — exact match against the canonical probe id list
 *   test:<anything>            — prefix-validated; the exact test registry is
 *                                populated by Plan 06 (probes.ts / admin-eval.spec.ts)
 *   conformance:<anything>     — prefix-validated; the exact conformance-script
 *                                selector registry is populated by Plan 07
 *
 * Rejected:
 *   probe:<unknown-id>         — unknown probe ids fail (ensures no drift)
 *   prose strings              — anything without a recognised prefix fails
 *   empty string               — fails
 *
 * @param {string} ref
 * @returns {boolean}
 */
export function resolveEvidenceRef(ref) {
  if (typeof ref !== 'string' || ref.length === 0) return false;

  if (ref.startsWith('probe:')) {
    const id = ref.slice('probe:'.length);
    return PROBE_ID_SET.has(id);
  }

  if (ref.startsWith('test:')) {
    // Plan 06 populates the exact registry; prefix-only validation for now.
    const id = ref.slice('test:'.length);
    return id.length > 0;
  }

  if (ref.startsWith('conformance:')) {
    // Plan 07 populates the exact registry; prefix-only validation for now.
    const id = ref.slice('conformance:'.length);
    return id.length > 0;
  }

  return false;
}
