#!/usr/bin/env node
/**
 * Self-test for scripts/panel/panel-schema.mjs (Phase 217, Plan 01).
 *
 * Tests:
 *   1. findingId(surface, "graphic_design:salience", anchor) returns byte-identical
 *      digest to the 216 formula reproduced inline.
 *   2. findingId for a platform_admin lens:question matches the same inline reference.
 *   3. Anchor canonicalization is applied before hashing (quote-style + whitespace).
 *   4. PANEL_SCHEMA structure obeys the schema-constraint limits.
 */

import { createHash } from 'node:crypto';
import { findingId, PANEL_SCHEMA } from './panel-schema.mjs';

let pass = 0;
let fail = 0;

function ok(label) { console.log(`  PASS: ${label}`); pass++; }
function ko(label) { console.error(`  FAIL: ${label}`); fail++; }

function assert(condition, label) {
  if (condition) ok(label);
  else ko(label);
}

// 216 formula reproduced inline — this is the reference for byte-identity.
// Source: enrichFindingsForBundle in admin-eval.spec.ts
function reference216(surface, klass, anchor) {
  return createHash('sha256')
    .update(surface)
    .update('\0')
    .update(klass)
    .update('\0')
    .update(anchor)
    .digest('hex');
}

// ---------------------------------------------------------------------------
// Test 1: findingId for graphic_design:salience matches 216 formula
// ---------------------------------------------------------------------------
console.log('Test 1: findingId(surface, "graphic_design:salience", anchor) byte-identical to 216 formula');
{
  const surface = 'users-index-live';
  const klass = 'graphic_design:salience';
  const anchor = '[data-testid="admin-users-desktop-results"]';

  const ref = reference216(surface, klass, anchor);
  const got = findingId(surface, klass, anchor);
  assert(got === ref, `findingId matches 216 formula for graphic_design:salience`);
  assert(got.length === 64, 'findingId is 64 hex chars');
  assert(/^[0-9a-f]{64}$/.test(got), 'findingId is lowercase hex only');
}

// ---------------------------------------------------------------------------
// Test 2: findingId for platform_admin:ia_muddy matches 216 formula
// This proves the lens:question string occupies the class slot exactly.
// ---------------------------------------------------------------------------
console.log('Test 2: findingId for platform_admin:ia_muddy matches 216 formula');
{
  const surface = 'admin-dashboard-live';
  const klass = 'platform_admin:ia_muddy';
  const anchor = '.sg-nav-item[data-testid="nav-users"]';

  const ref = reference216(surface, klass, anchor);
  const got = findingId(surface, klass, anchor);
  assert(got === ref, `findingId matches 216 formula for platform_admin:ia_muddy`);
}

// ---------------------------------------------------------------------------
// Test 3: Anchor canonicalization — quote-style and whitespace normalization
// The canonical anchor is used BEFORE hashing (D-08), so single-quoted and
// double-quoted variants of the same selector must produce the same digest.
// ---------------------------------------------------------------------------
console.log('Test 3: anchor canonicalization applied before hashing');
{
  const surface = 'users-index-live';
  const klass = 'graphic_design:composition';

  // Double-quoted variant (canonical form)
  const anchorDouble = '[data-testid="admin-header"]';
  // Single-quoted variant (should be normalized to double-quoted before hashing)
  const anchorSingle = "[data-testid='admin-header']";
  // Extra whitespace variant
  const anchorWhitespace = '  [data-testid="admin-header"]  ';

  const digestDouble = findingId(surface, klass, anchorDouble);
  const digestSingle = findingId(surface, klass, anchorSingle);
  const digestWhitespace = findingId(surface, klass, anchorWhitespace);

  assert(digestDouble === digestSingle, 'single-quoted and double-quoted anchors produce same digest');
  assert(digestDouble === digestWhitespace, 'leading/trailing whitespace stripped before hashing');
  // Verify byte-identity with 216 formula using the canonical form
  const ref = reference216(surface, klass, anchorDouble);
  assert(digestDouble === ref, 'canonical form is byte-identical to 216 formula');
}

// ---------------------------------------------------------------------------
// Test 4: PANEL_SCHEMA shape obeys the schema-constraint limits
// Per D-03/D-06: additionalProperties:false on every object,
// NO minimum/maximum/minLength/maxLength/multipleOf, no recursion.
// The 12-cell grid: 4 lenses x 3 questions.
// ---------------------------------------------------------------------------
console.log('Test 4: PANEL_SCHEMA obeys schema-constraint limits');
{
  assert(typeof PANEL_SCHEMA === 'object' && PANEL_SCHEMA !== null, 'PANEL_SCHEMA is an object');
  assert(PANEL_SCHEMA.type === 'object', 'PANEL_SCHEMA top level is an object type');
  assert(PANEL_SCHEMA.additionalProperties === false, 'PANEL_SCHEMA has additionalProperties:false');

  // Check for forbidden constraint keywords (D-03)
  function forbiddenConstraints(schema, path = 'PANEL_SCHEMA') {
    const forbidden = ['minimum', 'maximum', 'minLength', 'maxLength', 'multipleOf'];
    for (const key of forbidden) {
      if (Object.prototype.hasOwnProperty.call(schema, key)) {
        ko(`${path} must not have ${key} (D-03 schema-constraint limit)`);
      }
    }
    // Recurse into properties and items
    if (schema.properties) {
      for (const [propName, propSchema] of Object.entries(schema.properties)) {
        forbiddenConstraints(propSchema, `${path}.properties.${propName}`);
      }
    }
    if (schema.items) {
      forbiddenConstraints(schema.items, `${path}.items`);
    }
    if (schema.anyOf) {
      schema.anyOf.forEach((s, i) => forbiddenConstraints(s, `${path}.anyOf[${i}]`));
    }
    if (schema.oneOf) {
      schema.oneOf.forEach((s, i) => forbiddenConstraints(s, `${path}.oneOf[${i}]`));
    }
  }

  let forbiddenFound = false;
  const originalKo = ko;
  // Track forbidden constraint violations
  const violations = [];
  function checkForbidden(schema, path = 'PANEL_SCHEMA') {
    const forbidden = ['minimum', 'maximum', 'minLength', 'maxLength', 'multipleOf'];
    for (const key of forbidden) {
      if (Object.prototype.hasOwnProperty.call(schema, key)) {
        violations.push(`${path}.${key}`);
      }
    }
    if (schema.properties) {
      for (const [propName, propSchema] of Object.entries(schema.properties)) {
        checkForbidden(propSchema, `${path}.properties.${propName}`);
      }
    }
    if (schema.items) {
      checkForbidden(schema.items, `${path}.items`);
    }
    if (schema.anyOf) {
      schema.anyOf.forEach((s, i) => checkForbidden(s, `${path}.anyOf[${i}]`));
    }
    if (schema.oneOf) {
      schema.oneOf.forEach((s, i) => checkForbidden(s, `${path}.oneOf[${i}]`));
    }
  }
  checkForbidden(PANEL_SCHEMA);
  assert(violations.length === 0, `PANEL_SCHEMA has no minimum/maximum/minLength/maxLength/multipleOf constraints (found: ${violations.join(', ') || 'none'})`);

  // Check for verdict enum presence on findings
  function hasVerdictEnum(schema, path = '') {
    if (schema.properties && schema.properties.verdict) {
      return Array.isArray(schema.properties.verdict.enum);
    }
    if (schema.anyOf) {
      return schema.anyOf.some((s, i) => hasVerdictEnum(s, `${path}.anyOf[${i}]`));
    }
    if (schema.oneOf) {
      return schema.oneOf.some((s, i) => hasVerdictEnum(s, `${path}.oneOf[${i}]`));
    }
    if (schema.properties) {
      for (const propSchema of Object.values(schema.properties)) {
        if (hasVerdictEnum(propSchema)) return true;
      }
    }
    return false;
  }
  assert(hasVerdictEnum(PANEL_SCHEMA), 'PANEL_SCHEMA contains a verdict enum (keep|tighten|kill)');
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('');
console.log('----------------------------------------');
console.log(`Results: ${pass} passed, ${fail} failed`);
console.log('----------------------------------------');

if (fail > 0) {
  console.error('panel-schema.test: FAIL');
  process.exit(1);
}
console.log('panel-schema.test: PASS');
process.exit(0);
