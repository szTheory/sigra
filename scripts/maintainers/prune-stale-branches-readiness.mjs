#!/usr/bin/env node

import fs from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';

const SOURCE_PATHS = [
  '.planning/state.json',
  '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-VERIFICATION.md',
  '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json',
  '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-04-SUMMARY.md',
  '.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-08-SUMMARY.md',
  '.planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md',
  '.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md',
  '.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-ESCALATED.log',
  '.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md',
];

const EVIDENCE_PATH = SOURCE_PATHS[2];
const SUMMARY_04_PATH = SOURCE_PATHS[3];
const SUMMARY_08_PATH = SOURCE_PATHS[4];
const GZB_SUMMARY_PATH = SOURCE_PATHS[6];
const GZB_LOG_PATH = SOURCE_PATHS[7];
const DZU_SUMMARY_PATH = SOURCE_PATHS[8];
const STATE_ROUTE_PATH = SOURCE_PATHS[0];
const IMMUTABLE_SOURCE_PATHS = SOURCE_PATHS.slice(1);
const GIT_BIN = "/usr/bin/git";

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function runGit(repo, args, { allowMissing = false } = {}) {
  const result = spawnSync(GIT_BIN, ['-C', repo, ...args], { encoding: 'utf8' });
  if (result.status !== 0 && !allowMissing) {
    throw new Error(`git ${args.join(' ')} failed: ${(result.stderr || result.stdout || '').trim()}`);
  }
  return result.status === 0 ? result.stdout.trim() : null;
}

function readGitText(repo, commit, sourcePath) {
  const result = spawnSync(GIT_BIN, ['-C', repo, 'show', `${commit}:${sourcePath}`], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (result.status !== 0) return null;
  return result.stdout;
}

function readGitBytes(repo, objectSpec) {
  const result = spawnSync(GIT_BIN, ['-C', repo, 'show', objectSpec], { encoding: null, maxBuffer: 32 * 1024 *  1024 });
  return result.status === 0 ? result.stdout : null;
}

function readIndexBytes(repo, sourcePath) {
  return readGitBytes(repo, `:${sourcePath}`);
}

function blobForBytes(repo, sourcePath, bytes) {
  if (!bytes) return null;
  // Keep exact bytes and Git's path-aware hashing without relying on pipe EOF
  // delivery from a synchronous subprocess. This file is only hash input;
  // the committed readiness artifact retains its repository-relative identity.
  const inputDir = fs.mkdtempSync(path.join(tmpdir(), 'sigra-readiness-hash-'));
  let inputFd;
  try {
    const inputPath = path.join(inputDir, 'bytes');
    fs.writeFileSync(inputPath, bytes, { flag: 'wx', mode: 0o600 });
    inputFd = fs.openSync(inputPath, 'r');
    const result = spawnSync(GIT_BIN, ['-C', repo, 'hash-object', '--stdin', '--path', sourcePath], {
      stdio: [inputFd, 'pipe', 'pipe'], encoding: 'utf8',
    });
    return result.status === 0 ? result.stdout.trim() : null;
  } finally {
    try {
      if (inputFd !== undefined) fs.closeSync(inputFd);
    } finally {
      fs.rmSync(inputDir, { recursive: true, force: true });
    }
  }
}

function inspectPhase244Route(bytes) {
  if (!bytes) return { blob_oid: null, sha256: null, phase244_status: null, parse_error: 'missing' };
  let state;
  try {
    state = JSON.parse(bytes.toString('utf8'));
  } catch {
    return { blob_oid: null, sha256: sha256(bytes), phase244_status: null, parse_error: 'json_invalid' };
  }
  const phase244 = state?.phases?.find((phase) => phase?.number === '244');
  return { blob_oid: null, sha256: sha256(bytes), phase244_status: phase244?.status ?? null, parse_error: null };
}

function observeRouteLocation(repo, location) {
  let bytes = null;
  let blobOid = null;
  if (location === 'head') {
    const head = currentSourceCommit(repo);
    blobOid = runGit(repo, ['rev-parse', '--verify', `${head}:${STATE_ROUTE_PATH}`], { allowMissing: true });
    if (blobOid) bytes = readGitBytes(repo, `${head}:${STATE_ROUTE_PATH}`);
  } else if (location === 'index') {
    blobOid = runGit(repo, ['rev-parse', '--verify', `:${STATE_ROUTE_PATH}`], { allowMissing: true });
    if (blobOid) bytes = readIndexBytes(repo, STATE_ROUTE_PATH);
  } else if (location === 'worktree') {
    const file = path.join(repo, STATE_ROUTE_PATH);
    if (fs.existsSync(file)) {
      bytes = fs.readFileSync(file);
      blobOid = blobForBytes(repo, STATE_ROUTE_PATH, bytes);
    }
  } else {
    throw new Error(`Unknown state-route location: ${location}`);
  }
  const parsed = inspectPhase244Route(bytes);
  return { blob_oid: blobOid, sha256: parsed.sha256, phase244_status: parsed.phase244_status, parse_error: parsed.parse_error };
}

function observeStateRoute(repo) {
  return Object.fromEntries(['head', 'index', 'worktree'].map((location) => [location, observeRouteLocation(repo, location)]));
}

function parseFrontmatter(text) {
  if (typeof text !== 'string' || !text.startsWith('---\n')) return null;
  const end = text.indexOf('\n---', 4);
  if (end < 0) return null;
  return text.slice(4, end);
}

function frontmatterScalar(text, key) {
  const frontmatter = parseFrontmatter(text);
  if (frontmatter === null) return null;
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.*?)\\s*$`, 'm'));
  return match ? match[1].replace(/^['"]|['"]$/g, '') : null;
}

function recordCheck(checks, reasons, name, sourcePath, passed, actual, message) {
  checks[name] = { passed, actual };
  if (!passed) reasons.push({ code: name, source: sourcePath, message });
}

function loadCommittedSources(repo, commit) {
  const contents = new Map();
  const sources = [];
  const reasons = [];

  for (const sourcePath of SOURCE_PATHS) {
    const blobOid = runGit(repo, ['rev-parse', '--verify', `${commit}:${sourcePath}`], { allowMissing: true });
    const indexOid = runGit(repo, ['rev-parse', '--verify', `:${sourcePath}`], { allowMissing: true });
    const worktreePath = path.join(repo, sourcePath);
    let worktreeOid = null;
    if (fs.existsSync(worktreePath)) {
      worktreeOid = runGit(repo, ['hash-object', worktreePath], { allowMissing: true });
    }

    const sourceReasons = [];
    if (!blobOid) sourceReasons.push('source_missing_from_committed_tree');
    if (blobOid && indexOid !== blobOid) sourceReasons.push('source_index_differs_from_committed_blob');
    if (blobOid && worktreeOid !== blobOid) sourceReasons.push('source_worktree_differs_from_committed_blob');

    const entry = {
      path: sourcePath,
      commit,
      blob_oid: blobOid,
      index_blob_oid: indexOid,
      worktree_blob_oid: worktreeOid,
      blocked_reasons: sourceReasons,
    };
    sources.push(entry);
    for (const code of sourceReasons) {
      reasons.push({ code, source: sourcePath, message: `${sourcePath} is missing, uncommitted, or dirty (${code}).` });
    }
    if (blobOid) contents.set(sourcePath, readGitText(repo, commit, sourcePath));
  }

  return { sources, contents, reasons };
}

function evaluateSources(repo, commit, contents, sources, initialReasons = []) {
  const reasons = [...initialReasons];
  const checks = {};
  const text = (sourcePath) => contents.get(sourcePath) ?? null;
  const json = (sourcePath) => {
    try {
      const value = JSON.parse(text(sourcePath));
      return value && typeof value === 'object' ? value : null;
    } catch {
      return null;
    }
  };

  const state = json(SOURCE_PATHS[0]);
  const phase244 = state?.phases?.find((phase) => phase?.number === '244');
  recordCheck(checks, reasons, 'phase_244_complete', SOURCE_PATHS[0], phase244?.status === 'complete', phase244?.status ?? null,
    'The committed state must mark Phase 244 complete.');

  const verification = text(SOURCE_PATHS[1]);
  const verificationStatus = frontmatterScalar(verification, 'status');
  const gaps = verification?.match(/^\s+gaps_remaining:\s*(.*?)\s*$/m)?.[1]?.trim() ?? null;
  const behaviorUnverified = frontmatterScalar(verification, 'behavior_unverified');
  recordCheck(checks, reasons, 'phase_244_verification_passed', SOURCE_PATHS[1], verificationStatus === 'passed', verificationStatus,
    'The committed Phase 244 verification status must be passed.');
  recordCheck(checks, reasons, 'phase_244_gaps_empty', SOURCE_PATHS[1], gaps === '[]', gaps,
    'The committed Phase 244 verification must have no remaining gaps.');
  recordCheck(checks, reasons, 'phase_244_behavior_verified', SOURCE_PATHS[1], behaviorUnverified === '0', behaviorUnverified,
    'The committed Phase 244 verification must have zero behavior-unverified items.');

  const evidence = json(EVIDENCE_PATH);
  const receipt = evidence?.final_main_consumer_receipt;
  const run = receipt?.run;
  const runId = run?.id;
  const headSha = run?.head_sha;
  recordCheck(checks, reasons, 'phase_244_final_main_head_stable', EVIDENCE_PATH,
    Boolean(headSha && receipt?.main_sha_before === headSha && receipt?.main_sha_after === headSha),
    { head_sha: headSha ?? null, main_sha_before: receipt?.main_sha_before ?? null, main_sha_after: receipt?.main_sha_after ?? null },
    'The final-main run SHA must equal both before and after main SHAs.');
  recordCheck(checks, reasons, 'phase_244_final_main_run_success', EVIDENCE_PATH,
    Boolean(runId && run?.status === 'completed' && run?.conclusion === 'success'),
    { id: runId ?? null, status: run?.status ?? null, conclusion: run?.conclusion ?? null },
    'The final-main CI run must be completed successfully.');

  const expectedShardKeys = ['admin_behavior', 'admin_checkpoints', 'demo_showcase', 'design_gallery', 'non_admin_smoke'];
  const consumers = [
    ['ci_gate', receipt?.ci_gate, 'ci-gate'],
    ['example_playwright_smoke', receipt?.example_playwright_smoke, 'Example Playwright smoke (full lifecycle)'],
    ['generated_admin_playwright_smoke', receipt?.generated_admin_playwright_smoke, 'Generated admin Playwright smoke'],
  ];
  const shardMap = receipt?.example_playwright_shards;
  const shardKeys = shardMap && typeof shardMap === 'object' ? Object.keys(shardMap).sort() : [];
  const shardKeysValid = JSON.stringify(shardKeys) === JSON.stringify(expectedShardKeys);
  recordCheck(checks, reasons, 'phase_244_shard_set_exact', EVIDENCE_PATH, shardKeysValid, shardKeys,
    'The final-main receipt must contain exactly the five required Playwright shards.');
  for (const [name, row, exactName] of consumers) {
    recordCheck(checks, reasons, `phase_244_${name}_identity`, EVIDENCE_PATH,
      Boolean(row && row.name === exactName && String(row.run_id) === String(runId) && row.status === 'completed' && row.conclusion === 'success'),
      row ? { name: row.name, run_id: row.run_id, status: row.status, conclusion: row.conclusion } : null,
      `The final-main consumer ${name} must match the successful run identity.`);
  }
  if (shardMap && typeof shardMap === 'object') {
    for (const key of expectedShardKeys) {
      const row = shardMap[key];
      const expectedName = `Example Playwright shard (${key})`;
      const identityOk = Boolean(row && row.name === expectedName && String(row.run_id) === String(runId) && row.status === 'completed' && row.conclusion === 'success');
      const stepOk = Boolean(row?.step && row.step.status === 'completed' && row.step.conclusion === 'success');
      recordCheck(checks, reasons, `phase_244_shard_${key}_identity`, EVIDENCE_PATH, identityOk,
        row ? { name: row.name, run_id: row.run_id, status: row.status, conclusion: row.conclusion } : null,
        `The final-main shard ${key} must match the successful run identity.`);
      recordCheck(checks, reasons, `phase_244_shard_${key}_step`, EVIDENCE_PATH, stepOk,
        row?.step ? { status: row.step.status, conclusion: row.step.conclusion } : null,
        `The final-main shard ${key} must record a completed successful consumer step.`);
    }
  }
  for (const [name, row] of consumers.slice(1)) {
    const stepOk = Boolean(row?.step && row.step.status === 'completed' && row.step.conclusion === 'success');
    recordCheck(checks, reasons, `phase_244_${name}_step`, EVIDENCE_PATH, stepOk,
      row?.step ? { status: row.step.status, conclusion: row.step.conclusion } : null,
      `The final-main consumer ${name} must record a completed successful consumer step.`);
  }

  const summary08 = text(SUMMARY_08_PATH) ?? '';
  const summaryRunId = summary08.match(/run\s+`?(\d{8,})`?/i)?.[1] ?? null;
  const summaryHeadSha = summary08.match(/validated against SHA\s+`?([0-9a-f]{40})`?/i)?.[1]?.toLowerCase() ?? null;
  const summaryRunSuccess = new RegExp(`run\\s+\`?${String(runId ?? '').replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}\`?[\\s\\S]{0,100}success`, 'i').test(summary08);
  recordCheck(checks, reasons, 'phase_244_final_main_summary_run_id', SUMMARY_08_PATH,
    Boolean(runId && summaryRunId === String(runId)), summaryRunId, 'The final-main summary must state the evidence run ID.');
  recordCheck(checks, reasons, 'phase_244_final_main_summary_head', SUMMARY_08_PATH,
    Boolean(headSha && summaryHeadSha === headSha), summaryHeadSha, 'The final-main summary must state the evidence head SHA.');
  recordCheck(checks, reasons, 'phase_244_final_main_summary_success', SUMMARY_08_PATH,
    Boolean(runId && summaryRunSuccess), summaryRunSuccess, 'The final-main summary must record that the evidence run succeeded.');

  const prDisposition = evidence?.pr_disposition;
  const decision = prDisposition?.decision_inputs;
  const prFacts = {
    kind: prDisposition?.kind ?? null,
    reason_code: prDisposition?.reason_code ?? null,
    pr_number: decision?.pr_number ?? null,
    state: decision?.pr_state ?? null,
    merged_at: decision?.merged_at ?? null,
    head_ref_exists: decision?.head_ref_exists ?? null,
  };
  const prOk = prDisposition?.kind === 'deferred' &&
    prDisposition?.reason_code === 'deferred_missing_live_candidate_with_measured_drift' &&
    decision?.pr_number === 213 && decision?.pr_state === 'CLOSED' && decision?.merged_at === null && decision?.head_ref_exists === false;
  recordCheck(checks, reasons, 'phase_244_pr_213_deferred', EVIDENCE_PATH, prOk, prFacts,
    'Phase 244 must record PR #213 as closed, unmerged, missing its head, and deferred for measured drift.');
  const summary04 = text(SUMMARY_04_PATH) ?? '';
  recordCheck(checks, reasons, 'phase_244_pr_213_summary_agrees', SUMMARY_04_PATH,
    summary04.includes('deferred_missing_live_candidate_with_measured_drift') && /PR #213 remains closed and unmerged/.test(summary04),
    { reason_code_present: summary04.includes('deferred_missing_live_candidate_with_measured_drift'), closed_unmerged_present: /PR #213 remains closed and unmerged/.test(summary04) },
    'Phase 244 Plan 04 summary must record the same deferred PR #213 disposition.');

  const todo = text(SOURCE_PATHS[5]);
  recordCheck(checks, reasons, 'phase_242_todo_resolved', SOURCE_PATHS[5], frontmatterScalar(todo, 'status') === 'resolved', frontmatterScalar(todo, 'status'),
    'The linked Phase 242 blocker todo must be resolved.');

  const gzbSummary = text(GZB_SUMMARY_PATH);
  const gzbSourceCommit = frontmatterScalar(gzbSummary, 'source_commit');
  const gzbLog = text(GZB_LOG_PATH) ?? '';
  const gzbLogExists = Boolean(gzbLog.trim());
  const gzbCommitFull = gzbSourceCommit ? runGit(repo, ['rev-parse', '--verify', `${gzbSourceCommit}^{commit}`], { allowMissing: true }) : null;
  const gzbCommitAncestor = Boolean(gzbCommitFull && runGit(repo, ['merge-base', '--is-ancestor', gzbCommitFull, commit], { allowMissing: true }) === '');
  const gzbComplete = frontmatterScalar(gzbSummary, 'status') === 'complete';
  const gateCommand = 'MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci';
  const gzbCommandRecorded = (gzbSummary ?? '').includes(gateCommand);
  const gzbRetryPassed = /Escalated environment gate:\s*exit\s+0/.test(gzbSummary ?? '');
  const gzbLogLinked = (gzbSummary ?? '').includes('MIX-CI-ESCALATED.log');
  recordCheck(checks, reasons, 'quick_gzb_complete', GZB_SUMMARY_PATH, gzbComplete, frontmatterScalar(gzbSummary, 'status'), 'The linked 260926-gzb summary must be complete.');
  recordCheck(checks, reasons, 'quick_gzb_source_commit_ancestor', GZB_SUMMARY_PATH, gzbCommitAncestor,
    { recorded: gzbSourceCommit, resolved: gzbCommitFull, ancestor: gzbCommitAncestor }, 'The linked 260926-gzb source commit must resolve and be an ancestor of the coherent source commit.');
  recordCheck(checks, reasons, 'quick_gzb_exact_gate_command', GZB_SUMMARY_PATH, gzbCommandRecorded, gzbCommandRecorded,
    'The linked 260926-gzb summary must state the exact full mix ci command.');
  recordCheck(checks, reasons, 'quick_gzb_retry_exit_zero', GZB_SUMMARY_PATH, gzbRetryPassed, gzbRetryPassed,
    'The linked 260926-gzb summary must record a successful retry with exit 0.');
  recordCheck(checks, reasons, 'quick_gzb_log_linked', GZB_SUMMARY_PATH, gzbLogLinked, gzbLogLinked,
    'The linked 260926-gzb summary must link its retained full output log.');
  recordCheck(checks, reasons, 'quick_gzb_log_complete', GZB_LOG_PATH,
    gzbLogExists && gzbLog.includes('2614 tests, 0 failures') && gzbLog.includes('65 tests, 0 failures'),
    { non_empty: gzbLogExists, main_suite: gzbLog.includes('2614 tests, 0 failures'), ci_suite: gzbLog.includes('65 tests, 0 failures') },
    'The retained 260926-gzb log must be non-empty and contain both successful test-suite sentinels.');

  const dzuSummary = text(DZU_SUMMARY_PATH);
  const dzuSourceCommit = frontmatterScalar(dzuSummary, 'source_commit');
  const dzuCommitFull = dzuSourceCommit ? runGit(repo, ['rev-parse', '--verify', `${dzuSourceCommit}^{commit}`], { allowMissing: true }) : null;
  const dzuCommitAncestor = Boolean(dzuCommitFull && runGit(repo, ['merge-base', '--is-ancestor', dzuCommitFull, commit], { allowMissing: true }) === '');
  recordCheck(checks, reasons, 'quick_dzu_complete', DZU_SUMMARY_PATH, frontmatterScalar(dzuSummary, 'status') === 'complete', frontmatterScalar(dzuSummary, 'status'),
    'The linked 260926-dzu summary must be complete.');
  recordCheck(checks, reasons, 'quick_dzu_source_commit_ancestor', DZU_SUMMARY_PATH, dzuCommitAncestor,
    { recorded: dzuSourceCommit, resolved: dzuCommitFull, ancestor: dzuCommitAncestor }, 'The linked 260926-dzu source commit must resolve and be an ancestor of the coherent source commit.');

  return {
    receipt: {
      schema_version: 1,
      status: reasons.length === 0 ? 'ready' : 'blocked',
      source_commit: commit,
      sources,
      checks,
      blocked_reasons: reasons,
    },
    reasons,
  };
}

function currentSourceCommit(repo) {
  const commit = runGit(repo, ['rev-parse', '--verify', 'HEAD^{commit}']);
  if (!/^[0-9a-f]{40}$/.test(commit)) throw new Error('HEAD did not resolve to a full commit OID.');
  return commit;
}

function captureSchema1(repo, output) {
  const commit = currentSourceCommit(repo);
  const loaded = loadCommittedSources(repo, commit);
  const evaluated = evaluateSources(repo, commit, loaded.contents, loaded.sources, loaded.reasons);
  const outputPath = path.resolve(repo, output);
  const relative = path.relative(repo, outputPath);
  if (!relative || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) throw new Error('Readiness output must be a file inside the repository.');
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify({ ...evaluated.receipt, captured_at: new Date().toISOString() }, null, 2)}\n`);
  console.log(JSON.stringify({ status: evaluated.receipt.status, source_commit: commit, output: relative, blocked_reasons: evaluated.reasons }, null, 2));
}

function captureSchema2(repo, output) {
  const commit = currentSourceCommit(repo);
  const contents = new Map();
  const sources = [];
  const reasons = [];
  for (const sourcePath of SOURCE_PATHS) {
    const blobOid = runGit(repo, ['rev-parse', '--verify', `${commit}:${sourcePath}`], { allowMissing: true });
    const bytes = blobOid ? readGitBytes(repo, `${commit}:${sourcePath}`) : null;
    const sourceReasons = [];
    if (!blobOid || !bytes) {
      const code = `source_missing_from_committed_tree:${sourcePath}`;
      sourceReasons.push(code);
      reasons.push({ code, source: sourcePath, message: `${sourcePath} is unavailable in the coherent source commit.` });
    }
    const sourceSha = bytes ? sha256(bytes) : null;
    sources.push({ path: sourcePath, commit, blob_oid: blobOid, sha256: sourceSha, blocked_reasons: sourceReasons });
    if (bytes) contents.set(sourcePath, bytes.toString('utf8'));

    if (!IMMUTABLE_SOURCE_PATHS.includes(sourcePath) || !blobOid || !bytes) continue;
    const locations = {
      head: {
        blob_oid: runGit(repo, ['rev-parse', '--verify', `HEAD:${sourcePath}`], { allowMissing: true }),
        bytes: readGitBytes(repo, `HEAD:${sourcePath}`),
      },
      index: {
        blob_oid: runGit(repo, ['rev-parse', '--verify', `:${sourcePath}`], { allowMissing: true }),
        bytes: readIndexBytes(repo, sourcePath),
      },
      worktree: (() => {
        const file = path.join(repo, sourcePath);
        const currentBytes = fs.existsSync(file) ? fs.readFileSync(file) : null;
        return { blob_oid: currentBytes ? blobForBytes(repo, sourcePath, currentBytes) : null, bytes: currentBytes };
      })(),
    };
    for (const [location, current] of Object.entries(locations)) {
      if (!current.blob_oid || !current.bytes) {
        const code = `immutable_source_${location}_missing:${sourcePath}`;
        reasons.push({ code, source: sourcePath, message: `${sourcePath} is missing from ${location}.` });
      } else if (current.blob_oid !== blobOid || sha256(current.bytes) !== sourceSha) {
        const code = `immutable_source_${location}_identity_changed:${sourcePath}`;
        reasons.push({ code, source: sourcePath, message: `${sourcePath} differs from its coherent source identity in ${location}.` });
      }
    }
  }

  const evaluated = evaluateSources(repo, commit, contents, sources, []);
  reasons.push(...evaluated.reasons);
  const routeSourceBytes = readGitBytes(repo, `${commit}:${STATE_ROUTE_PATH}`);
  const sourceRoute = inspectPhase244Route(routeSourceBytes);
  sourceRoute.commit = commit;
  sourceRoute.blob_oid = sources.find((source) => source.path === STATE_ROUTE_PATH)?.blob_oid ?? null;
  if (!routeSourceBytes || sourceRoute.parse_error) {
    const code = 'state_route_source_unparseable';
    reasons.push({ code, source: STATE_ROUTE_PATH, message: 'The coherent committed state route is missing or unparseable.' });
  } else if (sourceRoute.phase244_status !== 'complete') {
    const code = 'state_route_phase244_not_complete:source';
    reasons.push({ code, source: STATE_ROUTE_PATH, message: 'The coherent committed state route must mark Phase 244 complete.' });
  }

  const captureObservations = observeStateRoute(repo);
  for (const [location, observation] of Object.entries(captureObservations)) {
    if (!observation.blob_oid || !observation.sha256 || observation.parse_error === 'missing') {
      const code = `state_route_observation_missing:${location}`;
      reasons.push({ code, source: STATE_ROUTE_PATH, message: `The ${location} state route observation is missing.` });
    } else if (observation.parse_error) {
      const code = `state_route_json_invalid:${location}`;
      reasons.push({ code, source: STATE_ROUTE_PATH, message: `The ${location} state route is not valid JSON.` });
    } else if (observation.phase244_status !== 'complete') {
      const code = `state_route_phase244_not_complete:${location}`;
      reasons.push({ code, source: STATE_ROUTE_PATH, message: `Phase 244 is not complete in the ${location} state route.` });
    }
  }

  const receipt = {
    schema_version: 2,
    status: reasons.length === 0 ? 'ready' : 'blocked',
    source_commit: commit,
    sources,
    checks: evaluated.receipt.checks,
    blocked_reasons: reasons,
    state_route: { source: sourceRoute, capture_observations: captureObservations },
    captured_at: new Date().toISOString(),
  };
  const outputPath = path.resolve(repo, output);
  const relative = path.relative(repo, outputPath);
  if (!relative || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) throw new Error('Readiness output must be a file inside the repository.');
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(receipt, null, 2)}\n`);
  console.log(JSON.stringify({ status: receipt.status, source_commit: commit, output: relative, blocked_reasons: reasons }, null, 2));
}

function verifySchema1(repo, artifact, artifactCommit) {
  const receipt = JSON.parse(fs.readFileSync(artifact, 'utf8'));
  const reasons = [];
  const add = (code, source, message) => reasons.push({ code, source, message });

  if (receipt?.schema_version !== 1) add('readiness_schema_invalid', null, 'The committed readiness receipt must use schema version 1.');
  if (receipt?.status !== 'ready') add('readiness_not_ready', null, 'The committed readiness receipt is blocked or malformed.');
  if (!/^[0-9a-f]{40}$/.test(receipt?.source_commit ?? '')) add('source_commit_invalid', null, 'The receipt must pin one full 40-character source commit.');

  let sourceCommit = null;
  if (/^[0-9a-f]{40}$/.test(receipt?.source_commit ?? '')) {
    sourceCommit = runGit(repo, ['rev-parse', '--verify', `${receipt.source_commit}^{commit}`], { allowMissing: true });
    if (sourceCommit !== receipt.source_commit) add('source_commit_missing', null, 'The pinned coherent source commit is unavailable.');
    if (sourceCommit && runGit(repo, ['merge-base', '--is-ancestor', sourceCommit, artifactCommit], { allowMissing: true }) !== '') {
      add('source_commit_not_ancestor_of_readiness', null, 'The coherent source commit is not an ancestor of the committed readiness artifact.');
    }
    const head = currentSourceCommit(repo);
    if (sourceCommit && runGit(repo, ['merge-base', '--is-ancestor', sourceCommit, head], { allowMissing: true }) !== '') {
      add('source_commit_not_ancestor_of_head', null, 'The coherent source commit is not an ancestor of the current repository HEAD.');
    }
  }

  const byPath = new Map((Array.isArray(receipt?.sources) ? receipt.sources : []).map((source) => [source?.path, source]));
  const pathSetExact = byPath.size === SOURCE_PATHS.length && SOURCE_PATHS.every((sourcePath) => byPath.has(sourcePath));
  if (!pathSetExact) add('source_set_incomplete', null, 'The receipt must identify every required Phase 244 source exactly once.');

  const contents = new Map();
  const sources = [];
  for (const sourcePath of SOURCE_PATHS) {
    const entry = byPath.get(sourcePath);
    const sourceReasons = [];
    if (!entry) {
      add('source_receipt_entry_missing', sourcePath, `The receipt has no identity for ${sourcePath}.`);
      continue;
    }
    if (entry.commit !== receipt.source_commit) sourceReasons.push('source_commit_mismatch');
    const pinnedBlob = sourceCommit ? runGit(repo, ['rev-parse', '--verify', `${sourceCommit}:${sourcePath}`], { allowMissing: true }) : null;
    const artifactBlob = runGit(repo, ['rev-parse', '--verify', `${artifactCommit}:${sourcePath}`], { allowMissing: true });
    const headBlob = runGit(repo, ['rev-parse', '--verify', `HEAD:${sourcePath}`], { allowMissing: true });
    const indexBlob = runGit(repo, ['rev-parse', '--verify', `:${sourcePath}`], { allowMissing: true });
    const worktreePath = path.join(repo, sourcePath);
    const worktreeBlob = fs.existsSync(worktreePath) ? runGit(repo, ['hash-object', worktreePath], { allowMissing: true }) : null;
    if (!pinnedBlob) sourceReasons.push('source_missing_from_pinned_commit');
    if (entry.blob_oid !== pinnedBlob) sourceReasons.push('source_blob_identity_mismatch');
    if (artifactBlob !== pinnedBlob || headBlob !== pinnedBlob) sourceReasons.push('source_stale_since_coherent_commit');
    if (indexBlob !== pinnedBlob) sourceReasons.push('source_index_dirty');
    if (worktreeBlob !== pinnedBlob) sourceReasons.push('source_worktree_dirty');
    if (!Array.isArray(entry.blocked_reasons) || entry.blocked_reasons.length !== 0) sourceReasons.push('source_was_blocked_at_capture');
    if (sourceReasons.length) {
      for (const code of sourceReasons) add(code, sourcePath, `${sourcePath} failed its committed identity check (${code}).`);
    }
    sources.push({ ...entry, current_head_blob_oid: headBlob, current_index_blob_oid: indexBlob, current_worktree_blob_oid: worktreeBlob, verification_blocked_reasons: sourceReasons });
    if (pinnedBlob) contents.set(sourcePath, readGitText(repo, sourceCommit, sourcePath));
  }

  if (sourceCommit) {
    const recalculated = evaluateSources(repo, sourceCommit, contents, sources, []).receipt;
    if (recalculated.status !== 'ready') add('source_predicates_no_longer_pass', null, 'The current committed Phase 244 sources do not satisfy every D-01 predicate.');
    if (JSON.stringify(recalculated.checks) !== JSON.stringify(receipt.checks)) add('readiness_predicates_contradict_sources', null, 'Recorded parsed predicates differ from the pinned committed Phase 244 sources.');
  }

  const output = { valid: reasons.length === 0, status: reasons.length === 0 ? 'ready' : 'blocked', reasons };
  console.log(JSON.stringify(output, null, 2));
  if (reasons.length) process.exitCode = 1;
}

function verifySchema2(repo, artifact, artifactCommit, receipt) {
  const reasons = [];
  const add = (code, source, message, extra = {}) => reasons.push({ code, source, message, ...extra });
  const absoluteArtifact = path.isAbsolute(artifact) ? path.resolve(artifact) : path.resolve(repo, artifact);
  const relativeArtifact = path.relative(repo, absoluteArtifact).split(path.sep).join('/');
  if (!relativeArtifact || relativeArtifact === '..' || relativeArtifact.startsWith('../') || path.isAbsolute(relativeArtifact)) {
    add('readiness_artifact_path_outside_repository', null, 'The readiness artifact path must be inside the repository.');
  }

  let resolvedArtifactCommit = null;
  if (!/^[0-9a-f]{40}$/.test(artifactCommit ?? '')) {
    add('readiness_artifact_commit_invalid', null, 'The readiness artifact commit must be a full commit OID.');
  } else {
    resolvedArtifactCommit = runGit(repo, ['rev-parse', '--verify', `${artifactCommit}^{commit}`], { allowMissing: true });
    if (resolvedArtifactCommit !== artifactCommit) add('readiness_artifact_commit_missing', null, 'The readiness artifact commit is unavailable.');
  }

  const committedArtifactBytes = resolvedArtifactCommit && relativeArtifact && !relativeArtifact.startsWith('../')
    ? readGitBytes(repo, `${resolvedArtifactCommit}:${relativeArtifact}`) : null;
  const artifactBlob = resolvedArtifactCommit && relativeArtifact && !relativeArtifact.startsWith('../')
    ? runGit(repo, ['rev-parse', '--verify', `${resolvedArtifactCommit}:${relativeArtifact}`], { allowMissing: true }) : null;
  let committedReceipt = receipt;
  if (!committedArtifactBytes || !artifactBlob) {
    add('readiness_artifact_missing_from_commit', relativeArtifact || null, 'The readiness artifact is missing from its declared commit.');
  } else {
    try { committedReceipt = JSON.parse(committedArtifactBytes.toString('utf8')); }
    catch { committedReceipt = null; add('readiness_json_invalid', relativeArtifact, 'The committed readiness artifact is not valid JSON.'); }
  }
  const worktreeArtifactBytes = relativeArtifact && !relativeArtifact.startsWith('../') && fs.existsSync(absoluteArtifact)
    ? fs.readFileSync(absoluteArtifact) : null;
  const worktreeArtifactBlob = worktreeArtifactBytes ? blobForBytes(repo, relativeArtifact, worktreeArtifactBytes) : null;
  if (!worktreeArtifactBytes) add('readiness_artifact_missing_from_worktree', relativeArtifact || null, 'The readiness artifact is missing from the worktree.');
  else if (worktreeArtifactBlob !== artifactBlob || sha256(worktreeArtifactBytes) !== sha256(committedArtifactBytes ?? Buffer.alloc(0))) {
    add('readiness_artifact_worktree_identity_changed', relativeArtifact, 'The worktree readiness artifact differs from its committed identity.');
  }

  if (committedReceipt?.schema_version !== 2) add('readiness_schema_invalid', relativeArtifact || null, 'The committed readiness receipt must use schema version 2.');
  if (committedReceipt?.status !== 'ready') add('readiness_not_ready', relativeArtifact || null, 'The committed readiness receipt is blocked or malformed.');
  if (!/^[0-9a-f]{40}$/.test(committedReceipt?.source_commit ?? '')) add('source_commit_invalid', null, 'The receipt must pin one full 40-character source commit.');

  let sourceCommit = null;
  if (/^[0-9a-f]{40}$/.test(committedReceipt?.source_commit ?? '')) {
    sourceCommit = runGit(repo, ['rev-parse', '--verify', `${committedReceipt.source_commit}^{commit}`], { allowMissing: true });
    if (sourceCommit !== committedReceipt.source_commit) add('source_commit_missing', null, 'The pinned coherent source commit is unavailable.');
    if (sourceCommit && resolvedArtifactCommit && runGit(repo, ['merge-base', '--is-ancestor', sourceCommit, resolvedArtifactCommit], { allowMissing: true }) !== '') {
      add('source_commit_not_ancestor_of_readiness', null, 'The coherent source commit is not an ancestor of the committed readiness artifact.');
    }
    const head = currentSourceCommit(repo);
    if (sourceCommit && runGit(repo, ['merge-base', '--is-ancestor', sourceCommit, head], { allowMissing: true }) !== '') {
      add('source_commit_not_ancestor_of_head', null, 'The coherent source commit is not an ancestor of the current repository HEAD.');
    }
  }

  const sourceRows = Array.isArray(committedReceipt?.sources) ? committedReceipt.sources : [];
  if (!Array.isArray(committedReceipt?.sources)) add('source_set_invalid', null, 'The receipt source list must be an array.');
  if (sourceRows.length !== SOURCE_PATHS.length) add('source_set_size_invalid', null, 'The receipt must contain exactly nine source records.');
  const pathCounts = new Map();
  for (const row of sourceRows) {
    if (typeof row?.path !== 'string') {
      add('source_path_invalid', null, 'Every source record must have a path.');
      continue;
    }
    pathCounts.set(row.path, (pathCounts.get(row.path) ?? 0) + 1);
    if (!SOURCE_PATHS.includes(row.path)) add(`source_path_unexpected:${row.path}`, row.path, `Unexpected readiness source path: ${row.path}.`);
  }
  for (const [sourcePath, count] of pathCounts) {
    if (count > 1) add('source_set_duplicate_path', sourcePath, `${sourcePath} appears more than once in the readiness receipt.`);
  }
  for (const sourcePath of SOURCE_PATHS) {
    if (!pathCounts.has(sourcePath)) add(`source_path_missing:${sourcePath}`, sourcePath, `The receipt has no source record for ${sourcePath}.`);
  }

  const byPath = new Map(sourceRows.filter((row) => typeof row?.path === 'string').map((row) => [row.path, row]));
  const contents = new Map();
  const recalculationSources = [];
  for (const sourcePath of SOURCE_PATHS) {
    const entry = byPath.get(sourcePath);
    if (!entry) continue;
    const sourceReasons = [];
    if (entry.commit !== committedReceipt?.source_commit) {
      const code = `source_commit_mismatch:${sourcePath}`;
      sourceReasons.push(code);
      add(code, sourcePath, `${sourcePath} is not pinned to the coherent source commit.`);
    }
    const pinnedBlob = sourceCommit ? runGit(repo, ['rev-parse', '--verify', `${sourceCommit}:${sourcePath}`], { allowMissing: true }) : null;
    const pinnedBytes = sourceCommit && pinnedBlob ? readGitBytes(repo, `${sourceCommit}:${sourcePath}`) : null;
    const pinnedSha = pinnedBytes ? sha256(pinnedBytes) : null;
    if (!pinnedBlob || !pinnedBytes) {
      const code = `source_missing_from_pinned_commit:${sourcePath}`;
      sourceReasons.push(code);
      add(code, sourcePath, `${sourcePath} is unavailable in the coherent source commit.`);
    }
    if (entry.blob_oid !== pinnedBlob) {
      const code = `source_blob_identity_mismatch:${sourcePath}`;
      sourceReasons.push(code);
      add(code, sourcePath, `${sourcePath} blob OID differs from the coherent source commit.`);
    }
    if (entry.sha256 !== pinnedSha) {
      const code = `source_sha256_identity_mismatch:${sourcePath}`;
      sourceReasons.push(code);
      add(code, sourcePath, `${sourcePath} SHA-256 differs from the coherent source commit.`);
    }
    if (!Array.isArray(entry.blocked_reasons) || entry.blocked_reasons.length !== 0) {
      const code = `source_was_blocked_at_capture:${sourcePath}`;
      sourceReasons.push(code);
      add(code, sourcePath, `${sourcePath} was blocked when the readiness receipt was captured.`);
    }

    if (pinnedBytes) contents.set(sourcePath, pinnedBytes.toString('utf8'));
    if (sourcePath === STATE_ROUTE_PATH || !pinnedBlob || !pinnedBytes) {
      recalculationSources.push({ ...entry, verification_blocked_reasons: sourceReasons });
      continue;
    }

    const actualLocations = {
      artifact: {
        blob_oid: resolvedArtifactCommit ? runGit(repo, ['rev-parse', '--verify', `${resolvedArtifactCommit}:${sourcePath}`], { allowMissing: true }) : null,
        bytes: resolvedArtifactCommit ? readGitBytes(repo, `${resolvedArtifactCommit}:${sourcePath}`) : null,
      },
      head: {
        blob_oid: runGit(repo, ['rev-parse', '--verify', `HEAD:${sourcePath}`], { allowMissing: true }),
        bytes: readGitBytes(repo, `HEAD:${sourcePath}`),
      },
      index: {
        blob_oid: runGit(repo, ['rev-parse', '--verify', `:${sourcePath}`], { allowMissing: true }),
        bytes: readIndexBytes(repo, sourcePath),
      },
      worktree: (() => {
        const file = path.join(repo, sourcePath);
        const bytes = fs.existsSync(file) ? fs.readFileSync(file) : null;
        return { blob_oid: bytes ? blobForBytes(repo, sourcePath, bytes) : null, bytes };
      })(),
    };
    for (const [location, current] of Object.entries(actualLocations)) {
      if (!current.blob_oid || !current.bytes) {
        const code = `immutable_source_${location}_missing:${sourcePath}`;
        sourceReasons.push(code);
        add(code, sourcePath, `${sourcePath} is missing from ${location}.`);
      } else if (current.blob_oid !== pinnedBlob || sha256(current.bytes) !== pinnedSha) {
        const code = `immutable_source_${location}_identity_changed:${sourcePath}`;
        sourceReasons.push(code);
        add(code, sourcePath, `${sourcePath} differs from its pinned immutable identity in ${location}.`);
      }
    }
    recalculationSources.push({ ...entry, verification_blocked_reasons: sourceReasons });
  }

  if (sourceCommit) {
    const recalculated = evaluateSources(repo, sourceCommit, contents, recalculationSources, []).receipt;
    if (recalculated.status !== 'ready') add('source_predicates_no_longer_pass', null, 'The committed Phase 244 sources do not satisfy every D-01 predicate.');
    if (JSON.stringify(recalculated.checks) !== JSON.stringify(committedReceipt?.checks)) {
      add('readiness_predicates_contradict_sources', null, 'Recorded parsed predicates differ from the pinned committed Phase 244 sources.');
    }
  }

  const pinnedStateBlob = sourceCommit ? runGit(repo, ['rev-parse', '--verify', `${sourceCommit}:${STATE_ROUTE_PATH}`], { allowMissing: true }) : null;
  const pinnedStateBytes = sourceCommit && pinnedStateBlob ? readGitBytes(repo, `${sourceCommit}:${STATE_ROUTE_PATH}`) : null;
  const pinnedStateRoute = inspectPhase244Route(pinnedStateBytes);
  pinnedStateRoute.blob_oid = pinnedStateBlob;
  pinnedStateRoute.commit = sourceCommit;
  if (!pinnedStateBytes || pinnedStateRoute.parse_error || pinnedStateRoute.phase244_status !== 'complete') {
    add('state_route_source_not_complete', STATE_ROUTE_PATH, 'The committed source state must be parseable and mark Phase 244 complete.');
  }
  const recordedSourceRoute = committedReceipt?.state_route?.source;
  if (!recordedSourceRoute || recordedSourceRoute.commit !== sourceCommit || recordedSourceRoute.blob_oid !== pinnedStateBlob || recordedSourceRoute.sha256 !== pinnedStateRoute.sha256 || recordedSourceRoute.phase244_status !== pinnedStateRoute.phase244_status || recordedSourceRoute.parse_error !== pinnedStateRoute.parse_error) {
    add('state_route_source_identity_mismatch', STATE_ROUTE_PATH, 'The recorded committed state-route identity differs from its source commit.');
  }

  const capturedObservations = committedReceipt?.state_route?.capture_observations;
  if (!capturedObservations || typeof capturedObservations !== 'object') {
    add('state_route_capture_observations_missing', STATE_ROUTE_PATH, 'The receipt must preserve exact HEAD, index and worktree route observations from capture.');
  }
  for (const location of ['head', 'index', 'worktree']) {
    const captured = capturedObservations?.[location];
    if (!captured || !/^[0-9a-f]{40}$/.test(captured.blob_oid ?? '') || !/^[0-9a-f]{64}$/.test(captured.sha256 ?? '')) {
      add(`state_route_capture_observation_missing:${location}`, STATE_ROUTE_PATH, `The captured ${location} route identity is missing or malformed.`);
      continue;
    }
    if (captured.parse_error || captured.phase244_status !== 'complete') {
      add(`state_route_capture_phase244_not_complete:${location}`, STATE_ROUTE_PATH, `The captured ${location} route did not prove Phase 244 complete.`);
    }
    if (location === 'head' && (captured.blob_oid !== pinnedStateBlob || captured.sha256 !== pinnedStateRoute.sha256)) {
      add('state_route_capture_head_source_mismatch', STATE_ROUTE_PATH, 'The captured HEAD state route must match the coherent source commit.');
    }
  }

  const currentObservations = observeStateRoute(repo);
  const changedSinceCapture = {};
  for (const [location, current] of Object.entries(currentObservations)) {
    const captured = capturedObservations?.[location];
    changedSinceCapture[location] = !captured || current.blob_oid !== captured.blob_oid || current.sha256 !== captured.sha256;
    if (!current.blob_oid || !current.sha256 || current.parse_error === 'missing') {
      add(`state_route_observation_missing:${location}`, STATE_ROUTE_PATH, `The current ${location} state route observation is missing.`);
    } else if (current.parse_error) {
      add(`state_route_json_invalid:${location}`, STATE_ROUTE_PATH, `The current ${location} state route is not valid JSON.`);
    } else if (current.phase244_status !== 'complete') {
      add(`state_route_phase244_not_complete:${location}`, STATE_ROUTE_PATH, `Phase 244 is not complete in the current ${location} state route.`);
    }
  }

  const output = {
    valid: reasons.length === 0,
    status: reasons.length === 0 ? 'ready' : 'blocked',
    source_commit: sourceCommit,
    artifact: { commit: resolvedArtifactCommit, path: relativeArtifact, blob_oid: artifactBlob, sha256: committedArtifactBytes ? sha256(committedArtifactBytes) : null },
    state_route: {
      source: pinnedStateRoute,
      capture_observations: capturedObservations ?? null,
      current_observations: currentObservations,
      changed_since_capture: changedSinceCapture,
    },
    reasons,
  };
  console.log(JSON.stringify(output, null, 2));
  if (reasons.length) process.exitCode = 1;
}

function verify(repo, artifact, artifactCommit) {
  const artifactPath = path.isAbsolute(artifact) ? artifact : path.resolve(repo, artifact);
  let workingReceipt;
  try { workingReceipt = JSON.parse(fs.readFileSync(artifactPath, 'utf8')); }
  catch {
    console.log(JSON.stringify({ valid: false, status: 'blocked', reasons: [{ code: 'readiness_json_invalid', source: artifact, message: 'The readiness artifact is missing or not valid JSON.' }] }, null, 2));
    process.exitCode = 1;
    return;
  }
  const relativeArtifact = path.relative(repo, artifactPath).split(path.sep).join('/');
  const committedBytes = /^[0-9a-f]{40}$/.test(artifactCommit ?? '') && relativeArtifact && !relativeArtifact.startsWith('../')
    ? readGitBytes(repo, `${artifactCommit}:${relativeArtifact}`) : null;
  let committedReceipt = null;
  if (committedBytes) {
    try { committedReceipt = JSON.parse(committedBytes.toString('utf8')); } catch { committedReceipt = null; }
  }
  if (committedReceipt?.schema_version === 1 && workingReceipt?.schema_version === 1) {
    verifySchema1(repo, artifactPath, artifactCommit);
  } else {
    // Schema 2 verifies the committed artifact and its worktree bytes together.
    // Dispatching from the committed receipt prevents a worktree edit from
    // downgrading a schema-2 artifact into the legacy schema-1 verifier.
    verifySchema2(repo, artifactPath, artifactCommit, committedReceipt ?? workingReceipt);
  }
}

function capture(repo, output, schemaVersion = 1) {
  if (schemaVersion === 1) captureSchema1(repo, output);
  else if (schemaVersion === 2) captureSchema2(repo, output);
  else throw new Error('--schema-version must be 1 or 2.');
}

function parseArgs(argv) {
  const [mode, ...rest] = argv;
  const options = {};
  for (let i = 0; i < rest.length; i += 1) {
    const token = rest[i];
    if (token === '--repo' || token === '--output' || token === '--artifact' || token === '--artifact-commit' || token === '--schema-version') {
      options[token.slice(2)] = rest[++i];
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }
  if (!options.repo) throw new Error('--repo is required.');
  return { mode, options };
}

try {
  const { mode, options } = parseArgs(process.argv.slice(2));
  if (mode === 'capture') capture(path.resolve(options.repo), options.output ?? '.planning/phases/245-branch-prune-local-and-remote/245-READINESS.json', options['schema-version'] === undefined ? 1 : Number(options['schema-version']));
  else if (mode === 'verify') {
    if (!options.artifact || !options['artifact-commit']) throw new Error('--artifact and --artifact-commit are required.');
    verify(path.resolve(options.repo), options.artifact, options['artifact-commit']);
  } else {
    throw new Error('Expected mode: capture or verify.');
  }
} catch (error) {
  console.error(`prune-stale-branches-readiness: ${error.message}`);
  process.exitCode = 2;
}
