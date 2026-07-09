/**
 * fix-queue-build.test.mjs — self-test for fix-queue-build.mjs (Phase 217, Plan 02).
 *
 * Tests 1-4 per Plan 02 behavior spec:
 *   1. open = built - settled (settled finding_ids excluded from queue)
 *   2. cross-surface systemic collapse (anchor on >=2 surfaces → ONE parent, floated top)
 *   3. auto_eligible is DERIVED from fix_class (component/judgment → never auto_eligible)
 *   4. open_findings in admin-render-sha.json = per-cell built - settled count
 *
 * Test 5 per Plan 218-07 (CR-01 determinism regression):
 *   5. systemic-parent representative finding_id is independent of readdirSync/
 *      seeding order (lowest finding_id of the group, proven via forward + reverse
 *      seeding order producing an identical result)
 *
 * Uses mktemp-hermetic pattern (temp dir, no real eval/ or guide/ files touched).
 */

import { mkdirSync, mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir, platform } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const __dir = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dir, '..', '..');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sha256(input) {
  return createHash('sha256').update(input).digest('hex');
}

/**
 * Compute finding_id byte-identically to the 216/217 formula:
 *   sha256(surface + NUL + class + NUL + anchor)
 */
function findingId(surface, klass, anchor) {
  return createHash('sha256')
    .update(surface + '\0' + klass + '\0' + anchor)
    .digest('hex');
}

let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  PASS: ${label}`);
    passed++;
  } else {
    console.error(`  FAIL: ${label}`);
    failed++;
  }
}

function assertDeepEqual(a, b, label) {
  const aStr = JSON.stringify(a, null, 0);
  const bStr = JSON.stringify(b, null, 0);
  if (aStr === bStr) {
    console.log(`  PASS: ${label}`);
    passed++;
  } else {
    console.error(`  FAIL: ${label}`);
    console.error(`    expected: ${bStr}`);
    console.error(`    got:      ${aStr}`);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// Hermetic fixture builder
// ---------------------------------------------------------------------------

/**
 * Create a hermetic temp workspace with:
 *   eval/<sha>/<surface>/<cell>/findings.json
 *   guides/reference/settled-findings.tsv
 *   guides/reference/admin-render-sha.json  (template)
 *
 * Returns { workDir, evalDir, settledTsv, renderShaJson, runBuilder }
 */
function makeWorkspace({ findings, settled = [], renderShaTemplate = null }) {
  const workDir = mkdtempSync(join(tmpdir(), 'fqbtest-'));
  const sha = 'test0000000000000000000000000000000000000001';
  const evalDir = join(workDir, 'eval', sha);
  const guidesDir = join(workDir, 'guides', 'reference');
  const scriptsDir = join(workDir, 'scripts', 'ci');
  const panelDir = join(workDir, 'scripts', 'panel');

  mkdirSync(guidesDir, { recursive: true });
  mkdirSync(scriptsDir, { recursive: true });
  mkdirSync(panelDir, { recursive: true });

  // Write findings.json bundles
  for (const [surface, cell, items] of findings) {
    const cellDir = join(evalDir, surface, cell);
    mkdirSync(cellDir, { recursive: true });
    const enriched = items.map(f => ({
      ...f,
      class: f.class || f.probe_class,
      surface,
      finding_id: f.finding_id || findingId(surface, f.class || f.probe_class, f.anchor),
    }));
    writeFileSync(join(cellDir, 'findings.json'), JSON.stringify(enriched, null, 2));
    writeFileSync(join(cellDir, 'bundle.json'), JSON.stringify({
      app_git_sha: sha,
      surface,
      cell,
      render_sha256: null,
      findings_summary: { total: enriched.length, gate: 0, warn: enriched.length },
    }, null, 2));
  }

  // Write settled-findings.tsv (header + optional rows)
  const tsvHeader = '# finding_id\tsurface\tclass\tanchor\tdisposition\twaived_by\tnote';
  const tsvRows = settled.map(row => [row.finding_id, row.surface, row.class, row.anchor, row.disposition, row.waived_by || '', row.note || ''].join('\t'));
  writeFileSync(join(guidesDir, 'settled-findings.tsv'), [tsvHeader, ...tsvRows].join('\n') + '\n');

  // Write admin-render-sha.json template
  const defaultRenderSha = {
    schema_version: 1,
    notes: 'test fixture',
    cells: {
      'test-surface-a': {
        'light-desktop-populated': { render_sha256: null, open_findings: 999 },
        'dark-desktop-populated': { render_sha256: null, open_findings: 999 },
      },
    },
  };
  const renderShaContent = renderShaTemplate || defaultRenderSha;
  const renderShaJsonPath = join(guidesDir, 'admin-render-sha.json');
  writeFileSync(renderShaJsonPath, JSON.stringify(renderShaContent, null, 2));

  // Symlink or copy the real panel-schema.mjs for findingId reuse
  // (builder imports findingId from scripts/panel/panel-schema.mjs)
  const realPanelSchema = join(ROOT, 'scripts', 'panel', 'panel-schema.mjs');
  try {
    const content = readFileSync(realPanelSchema, 'utf8');
    writeFileSync(join(panelDir, 'panel-schema.mjs'), content);
  } catch {
    // If real file not found, write a minimal stub
    writeFileSync(join(panelDir, 'panel-schema.mjs'), `
import { createHash } from 'node:crypto';
export function findingId(surface, klass, anchor) {
  return createHash('sha256').update(surface+'\\0'+klass+'\\0'+anchor).digest('hex');
}
`);
  }

  /**
   * Run fix-queue-build.mjs in the temp workspace.
   * Returns { exitCode, stdout, stderr, fixQueue, renderSha }.
   */
  function runBuilder(extraEnv = {}) {
    const builderPath = join(ROOT, 'scripts', 'ci', 'fix-queue-build.mjs');
    // FQ_EVAL_DIR must point to the top-level eval dir (containing <sha>/<surface>/<cell>)
    // evalDir is workDir/eval/sha, so go up one level to get workDir/eval
    const evalTopDir = join(workDir, 'eval');
    const result = spawnSync(process.execPath, [builderPath], {
      cwd: workDir,
      env: {
        ...process.env,
        FQ_EVAL_DIR: evalTopDir,
        FQ_SETTLED_TSV: join(guidesDir, 'settled-findings.tsv'),
        FQ_RENDER_SHA_JSON: renderShaJsonPath,
        FQ_QUEUE_JSON: join(guidesDir, 'fix-queue.json'),
        ...extraEnv,
      },
      encoding: 'utf8',
    });

    let fixQueue = null;
    let renderSha = null;
    const queuePath = join(guidesDir, 'fix-queue.json');
    try { fixQueue = JSON.parse(readFileSync(queuePath, 'utf8')); } catch { /* not written */ }
    try { renderSha = JSON.parse(readFileSync(renderShaJsonPath, 'utf8')); } catch { /* not written */ }

    return {
      exitCode: result.status ?? 1,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
      fixQueue,
      renderSha,
    };
  }

  function cleanup() {
    try { rmSync(workDir, { recursive: true, force: true }); } catch { /* ignore */ }
  }

  return { workDir, evalDir, guidesDir, renderShaJsonPath, runBuilder, cleanup };
}

// ---------------------------------------------------------------------------
// Test 1: open = built - settled
// ---------------------------------------------------------------------------
console.log('\nTest 1: open = built − settled (settled finding_ids excluded from queue)');
{
  const surf = 'surf-a';
  const cell = 'light-desktop-populated';

  // 3 findings total; 1 will be settled
  const f1 = { probe_class: 'misalignment', class: 'misalignment', anchor: '.sg-btn', severity: 'warn' };
  const f2 = { probe_class: 'misalignment', class: 'misalignment', anchor: '.sg-card', severity: 'warn' };
  const f3 = { probe_class: 'focus-ring', class: 'focus-ring', anchor: '.sg-link', severity: 'warn' };

  const id1 = findingId(surf, 'misalignment', '.sg-btn');
  const id3 = findingId(surf, 'focus-ring', '.sg-link');

  const renderShaTemplate = {
    schema_version: 1, notes: 'test', cells: {
      'test-surface-a': { 'light-desktop-populated': { render_sha256: null, open_findings: 999 } },
    },
  };

  const { runBuilder, cleanup } = makeWorkspace({
    findings: [[surf, cell, [f1, f2, f3]]],
    settled: [{ finding_id: findingId(surf, 'misalignment', '.sg-card'), surface: surf, class: 'misalignment', anchor: '.sg-card', disposition: 'waived' }],
    renderShaTemplate,
  });

  const { exitCode, fixQueue } = runBuilder();
  assert(exitCode === 0, 'builder exits 0');
  assert(fixQueue !== null, 'fix-queue.json was written');

  if (fixQueue) {
    const queueIds = fixQueue.map(e => e.finding_id);
    assert(queueIds.includes(id1), 'non-settled finding .sg-btn is in queue');
    assert(queueIds.includes(id3), 'non-settled finding .sg-link is in queue');
    // settled finding (.sg-card) must NOT be in queue
    const settledId = findingId(surf, 'misalignment', '.sg-card');
    assert(!queueIds.includes(settledId), 'settled finding .sg-card is excluded from queue');
    assert(fixQueue.length === 2, `queue has 2 entries (got ${fixQueue.length})`);
  }
  cleanup();
}

// ---------------------------------------------------------------------------
// Test 2: systemic collapse — anchor on >=2 surfaces → ONE parent, floated top
// ---------------------------------------------------------------------------
console.log('\nTest 2: systemic collapse — cross-surface anchor → single high-priority parent at top');
{
  const cell = 'light-desktop-populated';
  const anchor = '.sg-focus-ring';
  const klass = 'focus-ring';

  // Same anchor on TWO different surfaces
  const surf1 = 'surf-x';
  const surf2 = 'surf-y';
  // Plus a different finding only on surf1
  const singleAnchor = '.sg-unique';

  const renderShaTemplate = {
    schema_version: 1, notes: 'test', cells: {
      'test-surface-a': { 'light-desktop-populated': { render_sha256: null, open_findings: 999 } },
    },
  };

  const { runBuilder, cleanup } = makeWorkspace({
    findings: [
      [surf1, cell, [
        { probe_class: klass, class: klass, anchor, severity: 'warn' },
        { probe_class: 'misalignment', class: 'misalignment', anchor: singleAnchor, severity: 'warn' },
      ]],
      [surf2, cell, [
        { probe_class: klass, class: klass, anchor, severity: 'warn' },
      ]],
    ],
    renderShaTemplate,
  });

  const { exitCode, fixQueue } = runBuilder();
  assert(exitCode === 0, 'builder exits 0');

  if (fixQueue) {
    // The cross-surface anchor (`.sg-focus-ring`) should appear as ONE systemic parent
    const systemicEntries = fixQueue.filter(e => e.systemic_group && e.priority === 'systemic');
    assert(systemicEntries.length >= 1, 'at least one systemic parent entry exists');

    // Systemic parent(s) must be at the TOP of the queue
    const firstEntry = fixQueue[0];
    assert(firstEntry && firstEntry.priority === 'systemic', 'first entry is systemic (floated top)');

    // There should NOT be 2 separate entries for the same anchor across surfaces
    // (the systemic parent collapses them)
    const crossAnchorEntries = fixQueue.filter(e => e.anchor === anchor);
    // The cross-surface anchor should have exactly 1 systemic parent entry
    const systemicForAnchor = crossAnchorEntries.filter(e => e.priority === 'systemic');
    assert(systemicForAnchor.length === 1, `exactly 1 systemic parent for cross-surface anchor (got ${systemicForAnchor.length})`);

    // Single-surface anchor should NOT be systemic
    const singleSurfEntries = fixQueue.filter(e => e.anchor === singleAnchor);
    assert(singleSurfEntries.length >= 1, 'single-surface anchor is in queue');
    const systemicSingle = singleSurfEntries.filter(e => e.priority === 'systemic');
    assert(systemicSingle.length === 0, 'single-surface anchor is NOT systemic');
  }
  cleanup();
}

// ---------------------------------------------------------------------------
// Test 3: auto_eligible is DERIVED from fix_class (component/judgment → never auto_eligible)
// ---------------------------------------------------------------------------
console.log('\nTest 3: auto_eligible derived from fix_class — component/judgment are never auto_eligible');
{
  const cell = 'light-desktop-populated';
  const surf = 'surf-b';

  // off-scale-radius-shadow-control → token → auto_eligible
  // misalignment → judgment (complex) → NOT auto_eligible
  // focus-ring → component → NOT auto_eligible
  // [class*="sg-"] → class-chain anchor → judgment → NOT auto_eligible

  const renderShaTemplate = {
    schema_version: 1, notes: 'test', cells: {
      'test-surface-a': { 'light-desktop-populated': { render_sha256: null, open_findings: 999 } },
    },
  };

  const { runBuilder, cleanup } = makeWorkspace({
    findings: [
      [surf, cell, [
        { probe_class: 'off-scale-radius-shadow-control', class: 'off-scale-radius-shadow-control', anchor: '.sg-dialog', severity: 'warn' },
        { probe_class: 'misalignment', class: 'misalignment', anchor: '.sg-panel', severity: 'warn' },
        { probe_class: 'focus-ring', class: 'focus-ring', anchor: '.sg-link', severity: 'warn' },
        // class-chain-anchored — must be judgment regardless
        { probe_class: 'misalignment', class: 'misalignment', anchor: '[class*="sg-btn"]', severity: 'warn' },
      ]],
    ],
    renderShaTemplate,
  });

  const { exitCode, fixQueue } = runBuilder();
  assert(exitCode === 0, 'builder exits 0');

  if (fixQueue) {
    const byAnchor = Object.fromEntries(fixQueue.map(e => [e.anchor, e]));

    // off-scale → token → auto_eligible
    if (byAnchor['.sg-dialog']) {
      assert(byAnchor['.sg-dialog'].fix_class === 'token', '.sg-dialog fix_class is token');
      assert(byAnchor['.sg-dialog'].auto_eligible === true, '.sg-dialog is auto_eligible (token)');
    }

    // misalignment → judgment → NOT auto_eligible
    if (byAnchor['.sg-panel']) {
      assert(byAnchor['.sg-panel'].fix_class === 'judgment' || byAnchor['.sg-panel'].fix_class === 'component',
        '.sg-panel fix_class is judgment or component (not auto)');
      assert(byAnchor['.sg-panel'].auto_eligible === false, '.sg-panel is NOT auto_eligible');
    }

    // focus-ring → component → NOT auto_eligible
    if (byAnchor['.sg-link']) {
      assert(['component', 'judgment'].includes(byAnchor['.sg-link'].fix_class),
        '.sg-link fix_class is component or judgment');
      assert(byAnchor['.sg-link'].auto_eligible === false, '.sg-link is NOT auto_eligible');
    }

    // class-chain-anchored finding → always judgment, never auto_eligible
    const classChainEntry = fixQueue.find(e => e.anchor === '[class*="sg-btn"]');
    if (classChainEntry) {
      assert(classChainEntry.fix_class === 'judgment', 'class-chain anchor is forced to judgment');
      assert(classChainEntry.auto_eligible === false, 'class-chain anchor is NOT auto_eligible');
    }
  }
  cleanup();
}

// ---------------------------------------------------------------------------
// Test 4: open_findings in admin-render-sha.json = per-cell built - settled count
// ---------------------------------------------------------------------------
console.log('\nTest 4: open_findings written to admin-render-sha.json = per-cell built − settled');
{
  const cell = 'light-desktop-populated';

  // 4 findings across 2 board surfaces (same cell)
  // 1 will be settled → open_findings for light-desktop-populated = 3
  const surfA = 'board-mg-5-populated';
  const surfB = 'board-mg-9-populated';

  const findA1 = { probe_class: 'misalignment', class: 'misalignment', anchor: '.sg-a1', severity: 'warn' };
  const findA2 = { probe_class: 'misalignment', class: 'misalignment', anchor: '.sg-a2', severity: 'warn' };
  const findB1 = { probe_class: 'focus-ring', class: 'focus-ring', anchor: '.sg-b1', severity: 'warn' };
  const findB2 = { probe_class: 'focus-ring', class: 'focus-ring', anchor: '.sg-b2', severity: 'warn' };

  const settledId = findingId(surfA, 'misalignment', '.sg-a2');

  // admin-render-sha.json with two admin surfaces, one cell each
  const renderShaTemplate = {
    schema_version: 1,
    notes: 'test',
    cells: {
      'users-index-live': {
        'light-desktop-populated': { render_sha256: null, open_findings: 999 },
      },
      'user-show-live': {
        'light-desktop-populated': { render_sha256: null, open_findings: 999 },
      },
    },
  };

  const { runBuilder, cleanup } = makeWorkspace({
    findings: [
      [surfA, cell, [findA1, findA2]],
      [surfB, cell, [findB1, findB2]],
    ],
    settled: [
      { finding_id: settledId, surface: surfA, class: 'misalignment', anchor: '.sg-a2', disposition: 'waived' },
    ],
    renderShaTemplate,
  });

  const { exitCode, renderSha, fixQueue } = runBuilder();
  assert(exitCode === 0, 'builder exits 0');
  assert(renderSha !== null, 'admin-render-sha.json was updated');

  if (renderSha && fixQueue) {
    // 4 total unique finding_ids across both surfaces for light-desktop-populated, minus 1 settled = 3
    const expectedOpen = 3;

    // Check that admin-render-sha.json has updated open_findings for the cell
    // The builder should update ALL cells in admin-render-sha.json that match the cell key
    const allCells = [];
    for (const surface of Object.keys(renderSha.cells || {})) {
      for (const cellKey of Object.keys(renderSha.cells[surface] || {})) {
        if (cellKey === 'light-desktop-populated') {
          allCells.push({ surface, cellKey, value: renderSha.cells[surface][cellKey].open_findings });
        }
      }
    }

    assert(allCells.length > 0, 'at least one light-desktop-populated cell found in admin-render-sha.json');
    for (const { surface, cellKey, value } of allCells) {
      assert(value === expectedOpen,
        `admin-render-sha.json ${surface}/${cellKey} open_findings = ${expectedOpen} (got ${value})`);
    }

    // Fix queue should have exactly 3 open entries (1 settled excluded)
    assert(fixQueue.length === 3, `fix-queue.json has 3 entries (got ${fixQueue.length})`);

    // The settled finding should NOT be in the queue
    const settledInQueue = fixQueue.find(e => e.finding_id === settledId);
    assert(!settledInQueue, 'settled finding is excluded from fix-queue.json');
  }
  cleanup();
}

// ---------------------------------------------------------------------------
// Test 5: CR-01 determinism regression — systemic rep is independent of
// filesystem/readdir order (directory-name order diverges from finding_id order)
// ---------------------------------------------------------------------------
console.log('\nTest 5: CR-01 determinism — systemic parent finding_id is order-independent');
{
  const cell = 'light-desktop-populated';
  const anchor = '.sg-systemic-det';
  const klass = 'focus-ring';

  // 3 surfaces sharing the same (class, anchor) → one systemic group.
  // Surface names are chosen so that readdirSync order (alphabetical surface
  // dir names 'surf-alpha' < 'surf-bravo' < 'surf-charlie') is DIFFERENT from
  // finding_id order (finding_id = sha256(surface, class, anchor) — effectively
  // random relative to surface name). This proves the rep pick does not depend
  // on which surface directory happens to sort/list first.
  const surfaces = ['surf-alpha', 'surf-bravo', 'surf-charlie'];
  const ids = surfaces.map(s => findingId(s, klass, anchor));
  // Sanity: confirm the finding_id order does NOT match the surface-name order
  // (otherwise this test would not actually exercise the order-independence fix).
  const sortedBySurfaceName = [...surfaces];
  const sortedByFindingId = [...surfaces].sort((a, b) =>
    findingId(a, klass, anchor).localeCompare(findingId(b, klass, anchor)));
  assert(JSON.stringify(sortedBySurfaceName) !== JSON.stringify(sortedByFindingId),
    'fixture sanity: surface-name order differs from finding_id order');

  const expectedRepId = [...ids].sort((a, b) => a.localeCompare(b))[0];

  const renderShaTemplate = {
    schema_version: 1, notes: 'test', cells: {
      'test-surface-a': { 'light-desktop-populated': { render_sha256: null, open_findings: 999 } },
    },
  };

  // Run A: surfaces created/seeded in forward alphabetical order
  const wsA = makeWorkspace({
    findings: surfaces.map(s => [s, cell, [{ probe_class: klass, class: klass, anchor, severity: 'warn' }]]),
    renderShaTemplate,
  });
  const { exitCode: exitA, fixQueue: fixQueueA } = wsA.runBuilder();
  assert(exitA === 0, 'run A builder exits 0');
  const systemicA = fixQueueA ? fixQueueA.find(e => e.anchor === anchor && e.priority === 'systemic') : null;
  assert(!!systemicA, 'run A produced a systemic parent for the shared anchor');
  assert(systemicA && systemicA.finding_id === expectedRepId,
    `run A systemic parent finding_id is the lowest of the group (expected ${expectedRepId}, got ${systemicA && systemicA.finding_id})`);
  wsA.cleanup();

  // Run B: same surfaces, seeded in REVERSE order (so readdirSync would encounter
  // them in the opposite sequence if directory creation order leaked through)
  const wsB = makeWorkspace({
    findings: [...surfaces].reverse().map(s => [s, cell, [{ probe_class: klass, class: klass, anchor, severity: 'warn' }]]),
    renderShaTemplate,
  });
  const { exitCode: exitB, fixQueue: fixQueueB } = wsB.runBuilder();
  assert(exitB === 0, 'run B builder exits 0');
  const systemicB = fixQueueB ? fixQueueB.find(e => e.anchor === anchor && e.priority === 'systemic') : null;
  assert(!!systemicB, 'run B produced a systemic parent for the shared anchor');
  assert(systemicB && systemicB.finding_id === expectedRepId,
    `run B systemic parent finding_id is the lowest of the group (expected ${expectedRepId}, got ${systemicB && systemicB.finding_id})`);
  wsB.cleanup();

  // The two runs (opposite seeding orders) MUST agree on the same rep finding_id.
  assert(systemicA && systemicB && systemicA.finding_id === systemicB.finding_id,
    'systemic parent finding_id is IDENTICAL across forward and reverse seeding order');
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
console.log(`\n${passed + failed} checks: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.error('fix-queue-build.test.mjs: FAIL');
  process.exit(1);
}
console.log('fix-queue-build.test.mjs: PASS');
