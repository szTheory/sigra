#!/usr/bin/env node
/**
 * Self-test for scripts/ci/lib/anchor.mjs (Phase 217, Plan 01).
 *
 * Tests:
 *   1. isStructuralAnchor returns true for valid CSS selectors.
 *   2. isStructuralAnchor returns false for prose and line-number refs.
 *   3. GEOMETRY_ONLY_CLASSES exposes the same membership set as before extraction.
 *   4. Importing from anchor.mjs yields byte-identical results to pre-extraction logic.
 */

import { isStructuralAnchor, GEOMETRY_ONLY_CLASSES } from './anchor.mjs';

let pass = 0;
let fail = 0;

function ok(label) { console.log(`  PASS: ${label}`); pass++; }
function ko(label) { console.error(`  FAIL: ${label}`); fail++; }

function assert(condition, label) {
  if (condition) ok(label);
  else ko(label);
}

// ---------------------------------------------------------------------------
// Test 1: isStructuralAnchor returns true for valid CSS selectors
// ---------------------------------------------------------------------------
console.log('Test 1: isStructuralAnchor returns true for valid CSS selectors');
{
  assert(isStructuralAnchor('[data-testid="x"]'), '[data-testid="x"] is structural');
  assert(isStructuralAnchor('.sg-card'), '.sg-card is structural');
  assert(isStructuralAnchor('#some-id'), '#some-id is structural');
  assert(isStructuralAnchor('button[aria-label]'), 'button[aria-label] is structural');
  assert(isStructuralAnchor(':root'), ':root is structural');
  assert(isStructuralAnchor('.sg-btn[data-testid="submit-btn"]'), '.sg-btn[data-testid="submit-btn"] is structural');
  assert(isStructuralAnchor('[data-testid="admin-users-desktop-results"] .sg-applied-chip'), 'compound attribute+class is structural');
  assert(isStructuralAnchor('div'), 'bare div tag is structural');
  assert(isStructuralAnchor('button'), 'bare button tag is structural');
  assert(isStructuralAnchor('div .sg-btn'), 'descendant combinator is structural');
}

// ---------------------------------------------------------------------------
// Test 2: isStructuralAnchor returns false for prose and line refs
// ---------------------------------------------------------------------------
console.log('Test 2: isStructuralAnchor returns false for prose and line-number refs');
{
  assert(!isStructuralAnchor('the header looks off'), 'prose phrase is not structural');
  assert(!isStructuralAnchor('the Save button label'), 'prose with the is not structural');
  assert(!isStructuralAnchor(''), 'empty string is not structural');
  assert(!isStructuralAnchor('   '), 'whitespace-only is not structural');
  assert(!isStructuralAnchor(null), 'null is not structural');
  assert(!isStructuralAnchor(123), 'number is not structural');
  assert(!isStructuralAnchor('some/file.ex:123'), 'file:line ref is not structural');
  assert(!isStructuralAnchor('path/to/component.ts:42'), 'ts file:line ref is not structural');
}

// ---------------------------------------------------------------------------
// Test 3: GEOMETRY_ONLY_CLASSES exposes the same membership set
// ---------------------------------------------------------------------------
console.log('Test 3: GEOMETRY_ONLY_CLASSES membership matches pre-extraction set');
{
  assert(GEOMETRY_ONLY_CLASSES instanceof Set, 'GEOMETRY_ONLY_CLASSES is a Set');
  assert(GEOMETRY_ONLY_CLASSES.has('misalignment'), 'misalignment is in GEOMETRY_ONLY_CLASSES');
  assert(GEOMETRY_ONLY_CLASSES.has('below-fold-primary'), 'below-fold-primary is in GEOMETRY_ONLY_CLASSES');
  assert(GEOMETRY_ONLY_CLASSES.has('focus-ring'), 'focus-ring is in GEOMETRY_ONLY_CLASSES');
  // Must NOT include the retired 'below-fold' (was replaced with 'below-fold-primary')
  assert(!GEOMETRY_ONLY_CLASSES.has('below-fold'), 'retired below-fold is NOT in GEOMETRY_ONLY_CLASSES');
  assert(GEOMETRY_ONLY_CLASSES.size === 3, 'GEOMETRY_ONLY_CLASSES has exactly 3 members');
}

// ---------------------------------------------------------------------------
// Test 4: spot-check results match the pre-extraction file-local versions
// (These are the same inputs covered by evidence-anchor-check.test.mjs)
// ---------------------------------------------------------------------------
console.log('Test 4: spot-check results match evidence-anchor-check.test.mjs inputs');
{
  // Test A anchor from evidence-anchor-check.test.mjs
  assert(
    isStructuralAnchor('[data-testid="admin-users-desktop-results"] .sg-applied-chip'),
    'Test A anchor: compound selector resolves as structural'
  );
  // Test C anchor from evidence-anchor-check.test.mjs
  assert(
    !isStructuralAnchor('the Save button label'),
    'Test C anchor: prose rejected as not structural'
  );
  // Test D anchor from evidence-anchor-check.test.mjs
  assert(
    isStructuralAnchor('.sg-btn[data-testid="submit-btn"]'),
    'Test D anchor: attribute selector resolves as structural'
  );
  // Test E anchor from evidence-anchor-check.test.mjs
  assert(
    isStructuralAnchor('.sg-btn--primary'),
    'Test E anchor: BEM modifier class resolves as structural'
  );
  // W1 anchor from evidence-anchor-check.test.mjs
  assert(
    isStructuralAnchor('.sg-absent-element'),
    'W1 anchor: class selector resolves as structural (even if absent from DOM)'
  );
  // GEOMETRY_ONLY_CLASSES membership spot-check (W2)
  assert(
    GEOMETRY_ONLY_CLASSES.has('below-fold-primary'),
    'W2: below-fold-primary is in GEOMETRY_ONLY_CLASSES (real emitter string)'
  );
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('');
console.log('----------------------------------------');
console.log(`Results: ${pass} passed, ${fail} failed`);
console.log('----------------------------------------');

if (fail > 0) {
  console.error('anchor.test: FAIL');
  process.exit(1);
}
console.log('anchor.test: PASS');
process.exit(0);
