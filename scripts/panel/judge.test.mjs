#!/usr/bin/env node
/**
 * judge.test.mjs — hermetic call-counter test for judge.mjs (Phase 217, Plan 05).
 *
 * IMPORTANT: This test uses an injected SDK test-double (call-counter).
 * It makes ZERO real Anthropic API calls. ANTHROPIC_API_KEY is NEVER needed.
 *
 * Tests:
 *   Test 1 (SC-2 zero-calls): Running the judge on a cell whose render_sha256 already has
 *     a matching-provenance entry in admin-panel-verdicts.json makes callCount === 0.
 *   Test 2 (quorum): A finding_id appearing in 2 of 3 samples is admitted;
 *     one appearing in only 1 of 3 is dropped.
 *   Test 3 (reconciliation): Admitted finding severity = worst-verdict (kill > tighten > keep)
 *     across winning samples; description = first winning sample.
 *   Test 4 (provenance miss): A matching render_sha256 but drifted provenance (rubric/prompt_sha)
 *     forces re-evaluation (cache miss).
 *   Test 5 (parallel write): Panel findings are written to panel-findings.json only;
 *     findings.json is never touched.
 *
 * RED phase: all tests fail (judge.mjs does not exist yet).
 */

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';

const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');

// Import the module under test
let judgeModule;
try {
  judgeModule = await import('./judge.mjs');
} catch (err) {
  console.error('FAIL: judge.mjs not found or has errors:', err.message);
  process.exit(1);
}

const {
  runJudge,
  admitFindings,
  reconcileFindings,
  checkProvenanceMatch,
} = judgeModule;

let pass = 0;
let fail = 0;

function test(name, fn) {
  try {
    const result = fn();
    if (result && typeof result.then === 'function') {
      return result.then(() => {
        console.log(`  PASS: ${name}`);
        pass++;
      }).catch((err) => {
        console.error(`  FAIL: ${name}: ${err.message}`);
        fail++;
      });
    }
    console.log(`  PASS: ${name}`);
    pass++;
  } catch (err) {
    console.error(`  FAIL: ${name}: ${err.message}`);
    fail++;
  }
  return Promise.resolve();
}

// ---------------------------------------------------------------------------
// Helper: create a temp directory for test isolation
// ---------------------------------------------------------------------------
function makeTmpDir() {
  return mkdtempSync(path.join(tmpdir(), 'judge-test-'));
}

// ---------------------------------------------------------------------------
// Helper: compute finding_id using the same formula as panel-schema.mjs
// ---------------------------------------------------------------------------
function computeFindingId(surface, klass, anchor) {
  const canon = anchor.trim().replace(/\[([^\]]*?)='([^']*)'\]/g, '[$1="$2"]');
  return createHash('sha256')
    .update(surface)
    .update('\0')
    .update(klass)
    .update('\0')
    .update(canon)
    .digest('hex');
}

// ---------------------------------------------------------------------------
// Helper: make a fake verdicts cache entry (with provenance)
// ---------------------------------------------------------------------------
function makeCacheEntry(renderSha256, provenance = {}) {
  return {
    schema_version: '217-05',
    render_sha256: renderSha256,
    admitted_findings: [],
    per_lens_disposition: { platform_admin: 'clean', support_investigator: 'clean', org_admin: 'clean', graphic_design: 'clean' },
    surface_disposition: 'clean',
    sample_key_sets: [[], [], []],
    provenance: {
      model: 'claude-opus-4-8',
      k: 3,
      quorum: 2,
      rubric_version: '1.0',
      prompt_sha: 'abc123def456',
      ...provenance,
    },
  };
}

// ---------------------------------------------------------------------------
// Test 1 (SC-2 zero-calls): cache hit makes callCount === 0
// ---------------------------------------------------------------------------
console.log('\nTest 1: SC-2 — zero API calls on cache hit');

const tests = [];

tests.push(test('cache hit (matching provenance) makes callCount === 0', async () => {
  // Build a verdicts cache with a pre-existing entry for this render_sha256
  const renderSha256 = 'a'.repeat(64);
  const verdictEntry = makeCacheEntry(renderSha256, {
    rubric_version: '1.0',
    prompt_sha: 'abc123def456',
  });

  let callCount = 0;

  // Inject a test-double SDK that counts calls
  const sdkDouble = {
    messages: {
      create: async (_params) => {
        callCount++;
        return {
          content: [{ type: 'text', text: '{}' }],
        };
      },
    },
  };

  const result = await runJudge({
    surface: 'users-index-live',
    cell: 'light-desktop-populated',
    renderSha256,
    verdictEntry,
    excerptDom: '<div data-testid="test"/>',
    factsJson: '{}',
    sdkClient: sdkDouble,
    currentProvenance: {
      model: 'claude-opus-4-8',
      k: 3,
      quorum: 2,
      rubric_version: '1.0',
      prompt_sha: 'abc123def456',
    },
  });

  assert.strictEqual(callCount, 0, `Expected 0 API calls on cache hit, got ${callCount}`);
  assert.ok(result.from_cache === true, 'Result should be from cache');
}));

// ---------------------------------------------------------------------------
// Test 2 (quorum): >=2 of 3 samples admits; 1 of 3 drops
// ---------------------------------------------------------------------------
console.log('\nTest 2: quorum — >=2/3 admits, 1/3 drops');

tests.push(test('finding_id in 2/3 samples is admitted', () => {
  const surface = 'users-index-live';
  const fid1 = computeFindingId(surface, 'platform_admin:earning_its_place', '[data-testid="user-row"]');
  const fid2 = computeFindingId(surface, 'platform_admin:ia_muddy', '[data-testid="search-box"]');
  // fid3 appears in only 1 sample — should be dropped
  const fid3 = computeFindingId(surface, 'support_investigator:ia_muddy', '[data-testid="orphan"]');

  // 3 samples: fid1 in samples 0+1, fid2 in samples 1+2, fid3 only in sample 2
  const sampleKeySets = [
    new Set([fid1]),
    new Set([fid1, fid2]),
    new Set([fid2, fid3]),
  ];

  const admitted = admitFindings(sampleKeySets, { quorum: 2 });

  assert.ok(admitted.has(fid1), 'fid1 (2/3 samples) should be admitted');
  assert.ok(admitted.has(fid2), 'fid2 (2/3 samples) should be admitted');
  assert.ok(!admitted.has(fid3), 'fid3 (1/3 samples) should be dropped');
}));

tests.push(test('finding_id in exactly 0 of 3 samples is dropped', () => {
  const surface = 'users-index-live';
  const fid = computeFindingId(surface, 'platform_admin:earning_its_place', '[data-testid="ghost"]');

  const sampleKeySets = [new Set(), new Set(), new Set()];
  const admitted = admitFindings(sampleKeySets, { quorum: 2 });

  assert.ok(!admitted.has(fid), 'fid (0/3 samples) should be dropped');
}));

tests.push(test('finding_id in all 3 samples is admitted', () => {
  const surface = 'users-index-live';
  const fid = computeFindingId(surface, 'platform_admin:earning_its_place', '[data-testid="confirm"]');

  const sampleKeySets = [new Set([fid]), new Set([fid]), new Set([fid])];
  const admitted = admitFindings(sampleKeySets, { quorum: 2 });

  assert.ok(admitted.has(fid), 'fid (3/3 samples) should be admitted');
}));

// ---------------------------------------------------------------------------
// Test 3 (reconciliation): severity=worst-verdict, description=first winning sample
// ---------------------------------------------------------------------------
console.log('\nTest 3: reconciliation — worst-verdict + first winning description');

tests.push(test('severity = worst verdict (kill > tighten > keep)', () => {
  const surface = 'users-index-live';
  const fid = computeFindingId(surface, 'platform_admin:earning_its_place', '[data-testid="stat-strip"]');

  // Sample 0: tighten, Sample 1: kill, Sample 2: not present
  const samples = [
    {
      findingId: fid,
      verdict: 'tighten',
      anchor: '[data-testid="stat-strip"]',
      refutation: 'First sample: verbosity issue',
    },
    {
      findingId: fid,
      verdict: 'kill',
      anchor: '[data-testid="stat-strip"]',
      refutation: 'Second sample: actively harmful',
    },
  ];

  const admitted = new Set([fid]);
  const { severity, description } = reconcileFindings(fid, samples, admitted);

  assert.strictEqual(severity, 'kill', 'Severity should be worst verdict (kill)');
  assert.ok(description.includes('First sample'), 'Description should be from first winning sample');
}));

tests.push(test('severity tighten when no kill present', () => {
  const surface = 'users-index-live';
  const fid = computeFindingId(surface, 'org_admin:redundant_coherent_surprising', '[data-testid="scope-ribbon"]');

  const samples = [
    { findingId: fid, verdict: 'tighten', anchor: '[data-testid="scope-ribbon"]', refutation: 'First tighten' },
    { findingId: fid, verdict: 'tighten', anchor: '[data-testid="scope-ribbon"]', refutation: 'Second tighten' },
  ];

  const admitted = new Set([fid]);
  const { severity } = reconcileFindings(fid, samples, admitted);
  assert.strictEqual(severity, 'tighten', 'Severity should be tighten when no kill');
}));

// ---------------------------------------------------------------------------
// Test 4 (provenance miss): rubric/prompt_sha drift forces re-eval
// ---------------------------------------------------------------------------
console.log('\nTest 4: provenance miss — cache miss on rubric/prompt_sha drift');

tests.push(test('drifted rubric_version forces cache miss (provenance mismatch)', () => {
  const renderSha256 = 'b'.repeat(64);
  const cachedProvenance = {
    model: 'claude-opus-4-8',
    k: 3,
    quorum: 2,
    rubric_version: '1.0',
    prompt_sha: 'abc123',
  };
  const currentProvenance = {
    ...cachedProvenance,
    rubric_version: '2.0', // drifted!
  };

  const isMatch = checkProvenanceMatch(cachedProvenance, currentProvenance);
  assert.ok(!isMatch, 'Drifted rubric_version should cause provenance mismatch (cache miss)');
}));

tests.push(test('drifted prompt_sha forces cache miss', () => {
  const cachedProvenance = {
    model: 'claude-opus-4-8',
    k: 3,
    quorum: 2,
    rubric_version: '1.0',
    prompt_sha: 'abc123',
  };
  const currentProvenance = {
    ...cachedProvenance,
    prompt_sha: 'xyz789', // drifted!
  };

  const isMatch = checkProvenanceMatch(cachedProvenance, currentProvenance);
  assert.ok(!isMatch, 'Drifted prompt_sha should cause provenance mismatch (cache miss)');
}));

tests.push(test('matching provenance returns true (cache hit)', () => {
  const prov = {
    model: 'claude-opus-4-8',
    k: 3,
    quorum: 2,
    rubric_version: '1.0',
    prompt_sha: 'abc123',
  };

  const isMatch = checkProvenanceMatch(prov, { ...prov });
  assert.ok(isMatch, 'Identical provenance should return true (cache hit)');
}));

tests.push(test('drifted model forces cache miss', () => {
  const cachedProvenance = { model: 'claude-opus-4-8', k: 3, quorum: 2, rubric_version: '1.0', prompt_sha: 'x' };
  const currentProvenance = { ...cachedProvenance, model: 'claude-opus-4-5' };

  const isMatch = checkProvenanceMatch(cachedProvenance, currentProvenance);
  assert.ok(!isMatch, 'Drifted model should cause provenance mismatch');
}));

// ---------------------------------------------------------------------------
// Test 5 (parallel write): panel findings go to panel-findings.json, NEVER findings.json
// ---------------------------------------------------------------------------
console.log('\nTest 5: parallel write — panel-findings.json only, never findings.json');

tests.push(test('runJudge writes panel-findings.json and does NOT touch findings.json', async () => {
  const tmpDir = makeTmpDir();
  try {
    const renderSha256 = 'c'.repeat(64);
    let callCount = 0;

    // Build a trivial fake LLM response that matches PANEL_SCHEMA structure
    const fakeLLMResponse = {
      platform_admin: {
        earning_its_place: { verdict: 'keep', none_searched_for: 'NONE — searched for: verbosity' },
        ia_muddy: { verdict: 'keep', none_searched_for: 'NONE — searched for: hierarchy breaks' },
        redundant_coherent_surprising: { verdict: 'keep', none_searched_for: 'NONE — searched for: redundancy' },
      },
      support_investigator: {
        earning_its_place: { verdict: 'keep', none_searched_for: 'NONE — searched for: verbosity' },
        ia_muddy: { verdict: 'keep', none_searched_for: 'NONE — searched for: hierarchy breaks' },
        redundant_coherent_surprising: { verdict: 'keep', none_searched_for: 'NONE — searched for: redundancy' },
      },
      org_admin: {
        earning_its_place: { verdict: 'keep', none_searched_for: 'NONE — searched for: verbosity' },
        ia_muddy: { verdict: 'keep', none_searched_for: 'NONE — searched for: hierarchy breaks' },
        redundant_coherent_surprising: { verdict: 'keep', none_searched_for: 'NONE — searched for: redundancy' },
      },
      graphic_design: {
        salience: { verdict: 'keep', none_searched_for: 'NONE — searched for: salience issues' },
        emphasis_ember: { verdict: 'keep', none_searched_for: 'NONE — searched for: ember drift' },
        composition: { verdict: 'keep', none_searched_for: 'NONE — searched for: composition breaks' },
      },
    };

    const sdkDouble = {
      messages: {
        create: async (_params) => {
          callCount++;
          return {
            content: [{ type: 'text', text: JSON.stringify(fakeLLMResponse) }],
          };
        },
      },
    };

    // Create the existing findings.json in the temp dir (to verify it is NOT modified)
    const findingsPath = path.join(tmpDir, 'findings.json');
    const panelFindingsPath = path.join(tmpDir, 'panel-findings.json');
    const originalFindings = [{ finding_id: 'existing-finding', anchor: '[data-testid="foo"]' }];
    writeFileSync(findingsPath, JSON.stringify(originalFindings));

    await runJudge({
      surface: 'users-index-live',
      cell: 'light-desktop-populated',
      renderSha256,
      verdictEntry: null, // no cache entry → force evaluation
      excerptDom: '<div data-testid="main"/>',
      factsJson: '{}',
      sdkClient: sdkDouble,
      outputDir: tmpDir, // write panel-findings.json here
      currentProvenance: {
        model: 'claude-opus-4-8',
        k: 3,
        quorum: 2,
        rubric_version: '1.0',
        prompt_sha: 'abc123',
      },
    });

    // findings.json must be untouched
    const findingsAfter = JSON.parse(readFileSync(findingsPath, 'utf8'));
    assert.deepStrictEqual(findingsAfter, originalFindings, 'findings.json must NOT be modified');

    // panel-findings.json must exist
    assert.ok(existsSync(panelFindingsPath), 'panel-findings.json must be created');
    const panelFindings = JSON.parse(readFileSync(panelFindingsPath, 'utf8'));
    assert.ok(Array.isArray(panelFindings), 'panel-findings.json must be an array');

    // The API was called (3 times for k=3) since there was no cache entry
    assert.strictEqual(callCount, 3, `Expected 3 API calls for k=3, got ${callCount}`);
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}));

// ---------------------------------------------------------------------------
// Run all tests and report
// ---------------------------------------------------------------------------
await Promise.all(tests);

console.log(`\njudge.test.mjs: ${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
