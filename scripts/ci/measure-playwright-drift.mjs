#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { isDeepStrictEqual } from 'node:util';

const SHA_RE = /^[0-9a-f]{40}$/;

function fail(message) {
  console.error(`measure-playwright-drift: FAIL: ${message}`);
  process.exitCode = 1;
}

function argValue(args, name) {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  return result;
}

function imageCommand(name) {
  const override = process.env[`PHASE244_${name.toUpperCase()}_BIN`];
  return override || name;
}

function assertSafeInventoryPath(value) {
  if (typeof value !== 'string' || value.length === 0 || value.includes('\\')) {
    throw new Error('inventory path must be a non-empty repository-relative POSIX path');
  }
  if (path.posix.isAbsolute(value) || value.split('/').some((part) => part === '..' || part === '.')) {
    throw new Error(`unsafe inventory path: ${value}`);
  }
  if (!/^test\/example\/priv\/playwright\/tests\/[^/]+-snapshots\/[^/]+\.png$/.test(value)) {
    throw new Error(`path is outside the committed Playwright snapshot inventory: ${value}`);
  }
  return value;
}

function gitInventory(sourceSha) {
  if (!SHA_RE.test(sourceSha ?? '')) throw new Error('source SHA must be 40 lowercase hexadecimal characters');
  const result = run('git', ['ls-tree', '-r', '--name-only', sourceSha, '--', 'test/example/priv/playwright/tests']);
  if (result.status !== 0) throw new Error(`git ls-tree failed: ${result.stderr.trim()}`);
  return result.stdout.split(/\r?\n/).filter((entry) => entry && /^test\/example\/priv\/playwright\/tests\/[^/]+-snapshots\/[^/]+\.png$/.test(entry)).map(assertSafeInventoryPath).sort();
}

function samePaths(expected, actual) {
  const left = [...expected].sort();
  const right = [...actual].map(assertSafeInventoryPath).sort();
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function requireRunIdentity(manifest, sourceSha) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new Error('manifest must be a JSON object');
  }
  if (manifest.source_sha !== sourceSha) throw new Error('manifest source_sha does not match the requested source SHA');
  if (!SHA_RE.test(manifest.source_sha ?? '')) throw new Error('manifest source_sha is malformed');
  if (!/^\d+$/.test(String(manifest.run_id ?? ''))) throw new Error('manifest run_id is missing or malformed');
  if (typeof manifest.workflow_name !== 'string' || manifest.workflow_name !== 'Phase 244 Playwright measurement') {
    throw new Error('manifest workflow_name does not identify the Phase 244 measurement workflow');
  }
  if (manifest.event !== 'workflow_dispatch' || typeof manifest.head_branch !== 'string' || !manifest.head_branch.startsWith('phase-244/')) {
    throw new Error('manifest is not bound to an authorized phase-244 workflow_dispatch branch');
  }
  if (manifest.package_versions?.render_a !== '1.59.1' || manifest.package_versions?.render_b !== '1.62.1') {
    throw new Error('manifest package versions must identify the 1.59.1 baseline and 1.62.1 candidate');
  }
  if (!/^\d+$/.test(String(manifest.chromium_revisions?.render_a ?? '')) ||
      !/^\d+$/.test(String(manifest.chromium_revisions?.render_b ?? ''))) {
    throw new Error('manifest Chromium revisions are missing or malformed');
  }
  if (typeof manifest.comparator?.name !== 'string' || typeof manifest.comparator?.version !== 'string' ||
      !manifest.comparator.version.includes('ImageMagick')) {
    throw new Error('manifest comparator identity is missing or malformed');
  }
  if (manifest.schema_version >= 3) {
    for (const side of ['render_a', 'render_b']) {
      const version = side === 'render_a' ? '1.59.1' : '1.62.1';
      const trio = manifest.package_trios?.[side];
      const trioStatus = manifest.package_trio_statuses?.[side];
      if (trioStatus === 'verified' && (!trio || trio['@playwright/test'] !== version || trio.playwright !== version || trio['playwright-core'] !== version)) {
        throw new Error(`${side} package trio does not match ${version}`);
      }
      if (!['verified', 'unverified'].includes(trioStatus) || (trioStatus === 'unverified' && manifest.verdict !== 'inconclusive')) {
        throw new Error(`${side} package trio status is missing or conflicts with the verdict`);
      }
      const browser = manifest.browser_manifests?.[side];
      const browserStatus = manifest.browser_manifest_statuses?.[side];
      if (!browser?.url?.includes(`/v${version}/packages/playwright-core/browsers.json`) ||
          (browserStatus === 'verified' && !/^[0-9a-f]{64}$/.test(browser.sha256 ?? ''))) {
        throw new Error(`${side} tagged browser manifest URL/hash is missing or malformed`);
      }
      if (!['verified', 'unverified'].includes(browserStatus) || (browserStatus === 'unverified' && manifest.verdict !== 'inconclusive')) {
        throw new Error(`${side} browser manifest status is missing or conflicts with the verdict`);
      }
      if (browserStatus === 'verified' && (!/^[0-9a-f]{64}$/.test(browser.sha256 ?? '') || typeof manifest.chromium_versions?.[side] !== 'string' || !manifest.chromium_versions[side])) {
        throw new Error(`${side} Chromium version is missing`);
      }
    }
    if (!manifest.run_url?.includes(`/actions/runs/${manifest.run_id}`) || !manifest.runner?.image || !manifest.artifact_identifier) {
      throw new Error('run URL, runner image, or artifact identifier is missing');
    }
  }
}

async function verifyProvenance(args) {
  const manifestFile = argValue(args, '--manifest');
  const runFile = argValue(args, '--run-json');
  const artifactFile = argValue(args, '--artifact-json');
  const archiveFile = argValue(args, '--artifact-zip');
  const sourceSha = argValue(args, '--source-sha');
  if (!manifestFile || !runFile || !artifactFile || !archiveFile || !sourceSha) {
    throw new Error('verify-provenance requires --manifest, --run-json, --artifact-json, --artifact-zip, and --source-sha');
  }
  const [manifestBytes, runBytes, artifactBytes] = await Promise.all([
    readFile(manifestFile), readFile(runFile, 'utf8'), readFile(artifactFile, 'utf8'),
  ]);
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const runRecord = JSON.parse(runBytes);
  const artifactList = JSON.parse(artifactBytes);
  requireRunIdentity(manifest, sourceSha);
  if (!runRecord || typeof runRecord !== 'object' || Array.isArray(runRecord) ||
      String(runRecord.id) !== String(manifest.run_id) || runRecord.name !== manifest.workflow_name ||
      runRecord.path !== '.github/workflows/phase-244-playwright-measure.yml' || runRecord.event !== 'workflow_dispatch' ||
      !/^phase-244\//.test(runRecord.head_branch ?? '') || runRecord.head_branch !== manifest.head_branch ||
      runRecord.head_sha !== sourceSha || runRecord.head_sha !== manifest.source_sha ||
      runRecord.status !== 'completed' ||
      runRecord.conclusion !== (manifest.verdict === 'zero-drift' ? 'success' : 'failure')) {
    throw new Error('structured workflow run identity does not match the completed measurement manifest');
  }
  if (!artifactList || !Array.isArray(artifactList.artifacts)) throw new Error('artifact API response must contain an artifacts array');
  const matches = artifactList.artifacts.filter((artifact) => artifact?.name === manifest.artifact_identifier && artifact.expired === false);
  if (matches.length !== 1) throw new Error(`artifact API response has ${matches.length} explicitly unexpired exact-name matches; expected exactly one`);
  const artifact = matches[0];
  if (!Number.isSafeInteger(artifact.id) || artifact.id < 1 || String(artifact.workflow_run?.id) !== String(runRecord.id) ||
      artifact.name !== manifest.artifact_identifier || !/^sha256:[0-9a-f]{64}$/.test(artifact.digest ?? '')) {
    throw new Error('artifact API identity, run binding, or SHA-256 digest is missing or mismatched');
  }
  const archiveBytes = await readFile(archiveFile);
  const archiveSha256 = createHash('sha256').update(archiveBytes).digest('hex');
  if (artifact.digest !== `sha256:${archiveSha256}`) throw new Error('downloaded artifact archive digest does not match the artifact API digest');
  const listing = run('unzip', ['-Z1', archiveFile]);
  if (listing.status !== 0) throw new Error(`artifact archive cannot be listed: ${listing.stderr.trim()}`);
  const names = listing.stdout.split(/\r?\n/).filter(Boolean);
  if (names.filter((name) => name === 'measurement.json').length !== 1) {
    throw new Error('artifact archive must contain exactly one root measurement.json');
  }
  const extracted = spawnSync('unzip', ['-p', archiveFile, 'measurement.json'], { maxBuffer: 16 * 1024 * 1024 });
  if (extracted.error || extracted.status !== 0 || !Buffer.isBuffer(extracted.stdout)) {
    throw new Error(`measurement.json could not be extracted from the artifact archive${extracted.error ? `: ${extracted.error.message}` : ''}`);
  }
  if (!extracted.stdout.equals(manifestBytes)) throw new Error('downloaded measurement bytes do not match the supplied manifest bytes exactly');
  const manifestSha256 = createHash('sha256').update(extracted.stdout).digest('hex');
  console.log(JSON.stringify({ valid: true, run_id: runRecord.id, head_sha: runRecord.head_sha, artifact_id: artifact.id,
    artifact_name: artifact.name, artifact_digest: artifact.digest, manifest_sha256: manifestSha256,
    run_identity: { id: runRecord.id, name: runRecord.name, path: runRecord.path, event: runRecord.event,
      head_branch: runRecord.head_branch, head_sha: runRecord.head_sha, status: runRecord.status, conclusion: runRecord.conclusion },
    artifact_record: { id: artifact.id, name: artifact.name, digest: artifact.digest, expired: artifact.expired,
      workflow_run: { id: artifact.workflow_run.id, repository_id: artifact.workflow_run.repository_id,
        head_repository_id: artifact.workflow_run.head_repository_id, head_branch: artifact.workflow_run.head_branch,
        head_sha: artifact.workflow_run.head_sha } } }));
}

function completePages(record, key) {
  if (!record || record.complete !== true || !Array.isArray(record.pages) || record.pages.length === 0 ||
      !Number.isSafeInteger(record.total_count) || record.total_count < 0) {
    throw new Error(`${key} API pages are missing or pagination is incomplete`);
  }
  const items = [];
  for (const page of record.pages) {
    if (!page || !Array.isArray(page[key])) throw new Error(`${key} API page is malformed`);
    items.push(...page[key]);
  }
  if (items.length !== record.total_count) throw new Error(`${key} API pagination total does not match all collected records`);
  return items;
}

function splitWorkflowPathRef(value) {
  if (typeof value !== 'string') return null;
  const separator = value.lastIndexOf('@');
  if (separator <= 0 || separator === value.length - 1) return null;
  return { path: value.slice(0, separator), ref: value.slice(separator + 1) };
}

function workflowRefMatches(actual, expected) {
  if (typeof actual !== 'string' || typeof expected !== 'string') return false;
  if (actual === expected) return true;
  const normalize = (value) => value.replace(/^refs\/(?:heads|tags)\//, '');
  return normalize(actual) === normalize(expected);
}

function requiredWorkflowRunMatches(runRecord, required) {
  if (runRecord?.repository?.id !== required.repository_id) return false;
  const runPathRef = splitWorkflowPathRef(runRecord.path);
  if (!runPathRef || runPathRef.path !== required.path || !workflowRefMatches(runPathRef.ref, required.ref)) return false;
  // A run's head_sha identifies the checked commit, not the workflow file revision. Do not infer
  // the required workflow SHA from it; missing definition-SHA evidence leaves this run unverified.
  return runRecord.workflow_sha === required.sha;
}

function requiredPolicy(input) {
  if (!input.rules || input.rules.complete !== true || !Array.isArray(input.rules.rules)) {
    throw new Error('active branch rules response is missing, malformed, or incompletely paginated');
  }
  let protectionError = null;
  const protection = input.protection?.status === 200 ? input.protection.response : null;
  if (input.protection?.status !== 200) protectionError = 'classic required-status-check protection response is missing or inaccessible';
  if (protection && (typeof protection !== 'object' || Array.isArray(protection) ||
      !Array.isArray(protection.contexts) || !Array.isArray(protection.checks))) {
    protectionError = 'classic required-status-check protection response is malformed';
  }
  const checks = [];
  const workflows = [];
  const addCheck = (entry, source) => {
    if (!entry || typeof entry.context !== 'string' || entry.context.length === 0) throw new Error(`${source} required check context is missing`);
    const integrationId = entry.integration_id ?? entry.app_id ?? null;
    if (integrationId !== null && (!Number.isSafeInteger(integrationId) || integrationId < 0)) throw new Error(`${source} required check integration ID is malformed`);
    const existing = checks.find((item) => item.context === entry.context && item.integration_id === integrationId);
    if (existing) existing.sources.push(source);
    else checks.push({ context: entry.context, integration_id: integrationId, sources: [source] });
  };
  for (const context of protection?.contexts ?? []) addCheck({ context }, 'classic');
  for (const check of protection?.checks ?? []) addCheck({ context: check?.context, app_id: check?.app_id }, 'classic');
  for (const rule of input.rules.rules) {
    if (!rule || typeof rule.type !== 'string') throw new Error('active branch rule entry is malformed');
    if (rule.type === 'required_status_checks') {
      const entries = rule.parameters?.required_status_checks;
      if (!Array.isArray(entries)) throw new Error('active required-status-check rule is malformed');
      for (const entry of entries) addCheck(entry, 'ruleset');
    } else if (rule.type === 'workflows') {
      const entries = rule.parameters?.workflows;
      if (!Array.isArray(entries)) throw new Error('active required-workflow rule is malformed');
      for (const entry of entries) {
        if (!entry || typeof entry.path !== 'string' || !entry.path.startsWith('.github/workflows/') ||
            typeof entry.ref !== 'string' || !entry.ref || !Number.isSafeInteger(entry.repository_id) ||
            !SHA_RE.test(entry.sha ?? '')) throw new Error('active required-workflow identity is malformed');
        if (entry.repository_id !== input.repository_id) throw new Error('required workflow belongs to another repository and cannot be verified by this collection');
        const key = `${entry.repository_id}:${entry.path}:${entry.ref}:${entry.sha}`;
        if (!workflows.some((item) => item.key === key)) workflows.push({ key, ...entry });
      }
    }
  }
  if (checks.length === 0 && workflows.length === 0) throw new Error('merged active required-check and required-workflow policy is empty or unknown');
  return { status_checks: checks, workflows, error: protectionError };
}

function evaluateEligibility(input) {
  const measurement = input?.measurement;
  const provenance = input?.provenance;
  if (!measurement || typeof measurement !== 'object' || !provenance || typeof provenance !== 'object') {
    throw new Error('measurement and verified provenance records are required');
  }
  let policy;
  let policyError = null;
  try {
    policy = requiredPolicy(input);
    policyError = policy.error;
  } catch (error) {
    policyError = error.message;
    policy = { status_checks: [], workflows: [], error: null };
  }
  const checkRuns = completePages(input.check_runs, 'check_runs');
  const statuses = completePages(input.statuses, 'statuses');
  const workflowRuns = completePages(input.workflow_runs, 'workflow_runs');
  const sourceSha = measurement.source_sha;
  let exactManifestValid = false;
  if (typeof input.measurement_raw_base64 === 'string' && input.measurement_raw_base64) {
    const rawManifest = Buffer.from(input.measurement_raw_base64, 'base64');
    exactManifestValid = rawManifest.toString('base64') === input.measurement_raw_base64 &&
      createHash('sha256').update(rawManifest).digest('hex') === provenance.manifest_sha256;
    if (exactManifestValid) {
      try {
        exactManifestValid = JSON.stringify(JSON.parse(rawManifest.toString('utf8'))) === JSON.stringify(measurement);
      } catch {
        exactManifestValid = false;
      }
    }
  }
  const checks = policy.status_checks.map((required) => {
    const candidates = [
      ...checkRuns.filter((item) => item?.name === required.context),
      ...statuses.filter((item) => item?.context === required.context),
    ];
    const passing = candidates.length === 1 &&
      (required.integration_id === null || candidates[0]?.app?.id === required.integration_id) &&
      (candidates[0].head_sha ?? candidates[0].sha) === sourceSha &&
      (candidates[0].status === 'completed' && candidates[0].conclusion === 'success' || candidates[0].state === 'success');
    return { ...required, matching_results: candidates.length, success: passing,
      result_shas: candidates.map((item) => item.head_sha ?? item.sha ?? null) };
  });
  const requiredWorkflows = policy.workflows.map((required) => {
    const candidates = workflowRuns.filter((runRecord) => runRecord?.head_sha === sourceSha &&
      runRecord?.repository?.id === required.repository_id &&
      (() => {
        const pathRef = splitWorkflowPathRef(runRecord.path);
        return pathRef?.path === required.path && workflowRefMatches(pathRef.ref, required.ref);
      })());
    const exactIdentityRuns = candidates.filter((runRecord) => requiredWorkflowRunMatches(runRecord, required));
    const identityVerified = candidates.length === 1 && exactIdentityRuns.length === 1;
    const success = identityVerified && exactIdentityRuns[0].status === 'completed' && exactIdentityRuns[0].conclusion === 'success';
    return { repository_id: required.repository_id, path: required.path, ref: required.ref, sha: required.sha,
      candidate_runs: candidates.length, matching_runs: exactIdentityRuns.length, identity_verified: identityVerified,
      success, run_ids: exactIdentityRuns.map((runRecord) => runRecord.id),
      workflow_shas: exactIdentityRuns.map((runRecord) => runRecord.workflow_sha),
      unverified_run_ids: identityVerified ? [] : candidates.map((runRecord) => runRecord.id) };
  });
  const pr = input.pr;
  const main = input.main;
  const headRefSha = input.head_ref?.object?.sha ?? null;
  const reasons = [];
  if (policyError) reasons.push(`required-check policy is untrusted: ${policyError}`);
  if (measurement.verdict !== 'zero-drift') reasons.push('measurement verdict is not zero-drift');
  const runIdentity = provenance.run_identity;
  const artifactRecord = provenance.artifact_record;
  if (!exactManifestValid || !SHA_RE.test(sourceSha ?? '') || !SHA_RE.test(provenance.head_sha ?? '') || provenance.head_sha !== sourceSha ||
      String(provenance.run_id) !== String(measurement.run_id) || !/^[0-9a-f]{64}$/.test(provenance.manifest_sha256 ?? '') ||
      !Number.isSafeInteger(provenance.artifact_id) || provenance.artifact_id < 1 ||
      provenance.artifact_name !== measurement.artifact_identifier ||
      !/^sha256:[0-9a-f]{64}$/.test(provenance.artifact_digest ?? '') ||
      !runIdentity || String(runIdentity.id) !== String(measurement.run_id) || runIdentity.head_sha !== sourceSha ||
      runIdentity.status !== 'completed' || runIdentity.conclusion !== (measurement.verdict === 'zero-drift' ? 'success' : 'failure') ||
      !artifactRecord || artifactRecord.id !== provenance.artifact_id || artifactRecord.name !== measurement.artifact_identifier ||
      artifactRecord.digest !== provenance.artifact_digest || artifactRecord.expired !== false ||
      String(artifactRecord.workflow_run?.id) !== String(measurement.run_id) || artifactRecord.workflow_run?.head_sha !== sourceSha ||
      artifactRecord.workflow_run?.head_branch !== measurement.head_branch ||
      runIdentity.name !== measurement.workflow_name || runIdentity.path !== '.github/workflows/phase-244-playwright-measure.yml' ||
      runIdentity.event !== 'workflow_dispatch' || runIdentity.head_branch !== measurement.head_branch)
    reasons.push('measurement provenance is incomplete or mismatched');
  if (!pr || pr.number !== 213 || pr.state !== 'open') reasons.push('authorized PR #213 is not open');
  if (pr?.head?.sha !== sourceSha || !SHA_RE.test(pr?.head?.sha ?? '')) reasons.push('PR head does not match the measured source SHA');
  if (!headRefSha || headRefSha !== pr?.head?.sha) reasons.push('live PR head ref is absent or mismatched');
  if (pr?.base?.ref !== 'main' || main?.name !== 'main' || !SHA_RE.test(main?.sha ?? '') || pr?.base?.sha !== main.sha) reasons.push('PR base does not match the freshly fetched main SHA');
  if (pr?.mergeable !== true || pr?.mergeable_state !== 'clean') reasons.push('PR mergeability is not explicitly clean');
  if (checks.some((entry) => !entry.success)) reasons.push('one or more required status checks lack exactly one successful exact-head result');
  if (requiredWorkflows.some((entry) => !entry.identity_verified)) reasons.push('one or more required workflows lack a verifiable repository/path/ref/SHA execution identity');
  if (requiredWorkflows.some((entry) => entry.identity_verified && !entry.success)) reasons.push('one or more required workflows lack exactly one successful exact-head run');
  return {
    policy,
    policy_error: policyError,
    results: { status_checks: checks, workflows: requiredWorkflows },
    merge_eligible: reasons.length === 0,
    reasons,
    inputs: {
      measurement_run_id: measurement.run_id,
      measured_source_sha: sourceSha,
      manifest_sha256: provenance.manifest_sha256,
      pr_number: pr?.number ?? null,
      pr_state: pr?.state ?? null,
      pr_head_sha: pr?.head?.sha ?? null,
      live_head_ref_sha: headRefSha,
      pr_base_sha: pr?.base?.sha ?? null,
      main_sha: main?.sha ?? null,
      mergeable: pr?.mergeable ?? null,
      mergeable_state: pr?.mergeable_state ?? null,
    },
  };
}

async function evaluateEligibilityCommand(args) {
  const inputFile = argValue(args, '--authorization-json');
  if (!inputFile) throw new Error('evaluate-eligibility requires --authorization-json');
  const result = evaluateEligibility(JSON.parse(await readFile(inputFile, 'utf8')));
  console.log(JSON.stringify({ valid: true, merge_eligible: result.merge_eligible, reasons: result.reasons, policy_error: result.policy_error,
    policy: result.policy, results: result.results, inputs: result.inputs }));
}

async function verifyEligibilityCommand(args) {
  const inputFile = argValue(args, '--authorization-json');
  if (!inputFile) throw new Error('verify-eligibility requires --authorization-json');
  const record = JSON.parse(await readFile(inputFile, 'utf8'));
  const evaluation = evaluateEligibility(record);
  if (!isDeepStrictEqual(record.decision_eligibility, evaluation)) {
    throw new Error('recorded decision_eligibility does not match the API-bound eligibility inputs');
  }
  console.log(JSON.stringify({ valid: true, merge_eligible: evaluation.merge_eligible, reasons: evaluation.reasons,
    manifest_sha256: evaluation.inputs.manifest_sha256 }));
}

async function githubGet(pathname, optional404 = false) {
  const token = process.env.GH_TOKEN;
  if (!token) throw new Error('GH_TOKEN is required for GitHub API collection');
  const response = await fetch(`https://api.github.com${pathname}`, {
    method: 'GET',
    headers: { Accept: 'application/vnd.github+json', Authorization: `Bearer ${token}`, 'X-GitHub-Api-Version': '2022-11-28' },
  });
  if ((response.status === 403 || response.status === 429)) {
    throw new Error(`GitHub API returned HTTP ${response.status}; hard stop without retry`);
  }
  if (response.status === 404 && optional404) return { status: 404, data: null };
  if (!response.ok) throw new Error(`GitHub API GET ${pathname} returned HTTP ${response.status}`);
  try {
    return { status: response.status, data: await response.json() };
  } catch {
    throw new Error(`GitHub API GET ${pathname} returned malformed JSON`);
  }
}

async function collectPages(urlForPage, key) {
  const pages = [];
  let totalCount = null;
  for (let page = 1; page <= 1000; page += 1) {
    const { data } = await githubGet(urlForPage(page));
    if (!data || !Array.isArray(data[key]) || !Number.isSafeInteger(data.total_count)) {
      throw new Error(`${key} paginated API response is malformed`);
    }
    if (key === 'check_runs' && data.incomplete_results === true) throw new Error('check-runs API reported incomplete results');
    if (totalCount === null) totalCount = data.total_count;
    if (data.total_count !== totalCount) throw new Error(`${key} pagination total changed while collecting`);
    pages.push({ [key]: data[key] });
    if (data[key].length < 100) {
      const actualCount = pages.reduce((sum, item) => sum + item[key].length, 0);
      if (actualCount !== totalCount) throw new Error(`${key} pagination stopped before its reported total`);
      return { complete: true, total_count: totalCount, pages };
    }
  }
  throw new Error(`${key} pagination exceeded the 1000-page safety limit`);
}

async function collectRules() {
  const rules = [];
  for (let page = 1; page <= 1000; page += 1) {
    const { data } = await githubGet(`/repos/szTheory/sigra/rules/branches/main?per_page=100&page=${page}`);
    if (!Array.isArray(data)) throw new Error('active branch rules API response is malformed');
    rules.push(...data);
    if (data.length < 100) return { complete: true, rules, pages: page };
  }
  throw new Error('active branch rules pagination exceeded the 1000-page safety limit');
}

async function collectAuthorization(args) {
  const measurementFile = argValue(args, '--manifest');
  const provenanceFile = argValue(args, '--provenance-json');
  const sourceSha = argValue(args, '--source-sha');
  const outputFile = argValue(args, '--output');
  if (!measurementFile || !provenanceFile || !sourceSha || !outputFile) {
    throw new Error('collect-authorization requires --manifest, --provenance-json, --source-sha, and --output');
  }
  const [measurementBytes, provenanceText] = await Promise.all([
    readFile(measurementFile), readFile(provenanceFile, 'utf8'),
  ]);
  const measurement = JSON.parse(measurementBytes.toString('utf8'));
  const provenance = JSON.parse(provenanceText);
  if (measurement.source_sha !== sourceSha || provenance.head_sha !== sourceSha) throw new Error('measurement, provenance, and requested source SHA differ');
  const prReply = await githubGet('/repos/szTheory/sigra/pulls/213');
  const mainReply = await githubGet('/repos/szTheory/sigra/branches/main');
  const repositoryReply = await githubGet('/repos/szTheory/sigra');
  const pr = prReply.data;
  const main = { name: mainReply.data.name, sha: mainReply.data.commit?.sha };
  if (typeof pr?.head?.ref !== 'string' || !pr.head.ref || !main.sha) throw new Error('PR head ref or fresh main branch SHA is missing');
  const headPath = pr.head.ref.split('/').map(encodeURIComponent).join('/');
  const headReply = await githubGet(`/repos/szTheory/sigra/git/ref/heads/${headPath}`, true);
  const rules = await collectRules();
  const protectionReply = await githubGet('/repos/szTheory/sigra/branches/main/protection/required_status_checks', true);
  const checkRuns = await collectPages((page) => `/repos/szTheory/sigra/commits/${sourceSha}/check-runs?per_page=100&page=${page}`, 'check_runs');
  const statuses = await collectPages((page) => `/repos/szTheory/sigra/commits/${sourceSha}/status?per_page=100&page=${page}`, 'statuses');
  const workflowRuns = await collectPages((page) => `/repos/szTheory/sigra/actions/runs?head_sha=${sourceSha}&per_page=100&page=${page}`, 'workflow_runs');
  const record = {
    measurement,
    measurement_raw_base64: measurementBytes.toString('base64'),
    provenance,
    pr,
    main,
    head_ref: headReply.data,
    head_ref_status: headReply.status,
    rules,
    protection: { status: protectionReply.status, response: protectionReply.data },
    check_runs: checkRuns,
    statuses,
    workflow_runs: workflowRuns,
    repository_id: repositoryReply.data.id,
    collected_at: new Date().toISOString(),
  };
  const evaluation = evaluateEligibility(record);
  record.decision_eligibility = evaluation;
  await writeFile(outputFile, `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
  console.log(JSON.stringify({ valid: true, merge_eligible: evaluation.merge_eligible, reasons: evaluation.reasons,
    inputs: evaluation.inputs, status_check_count: evaluation.policy.status_checks.length,
    required_workflow_count: evaluation.policy.workflows.length }));
}

async function verifyManifest(args) {
  const file = argValue(args, '--manifest');
  const sourceSha = argValue(args, '--source-sha');
  if (!file || !sourceSha) throw new Error('verify requires --manifest and --source-sha');
  const parsed = JSON.parse(await readFile(file, 'utf8'));
  const manifest = parsed.measurement ?? parsed;
  if (parsed.measurement) {
    const eligibility = parsed.decision_eligibility;
    if (!eligibility || eligibility.verdict !== manifest.verdict || typeof eligibility.merge_eligible !== 'boolean') {
      throw new Error('phase evidence decision_eligibility conflicts with its measurement verdict');
    }
    if (parsed.authorization) {
      const derived = evaluateEligibility(parsed.authorization);
      const authorizationMatches = isDeepStrictEqual(parsed.authorization.decision_eligibility, derived) &&
        eligibility.merge_eligible === derived.merge_eligible &&
        parsed.authorization.measurement.source_sha === manifest.source_sha &&
        String(parsed.authorization.measurement.run_id) === String(manifest.run_id) &&
        parsed.authorization.measurement.verdict === manifest.verdict;
      if (!authorizationMatches) {
        throw new Error('phase evidence authorization record does not match its measured result');
      }
    } else if (eligibility.merge_eligible) {
      throw new Error('merge eligibility requires an offline-verifiable API authorization record');
    }
  }
  requireRunIdentity(manifest, sourceSha);
  const inventoryOnly = args.includes('--inventory-only');
  const validateOutcome = args.includes('--validate-recorded-outcome');
  const outcomes = new Set(['zero-drift', 'drift', 'inconclusive']);
  if (validateOutcome && !outcomes.has(manifest.verdict)) throw new Error(`manifest recorded outcome is invalid: ${manifest.verdict ?? 'missing'}`);
  if (!inventoryOnly && !validateOutcome && manifest.verdict !== 'zero-drift') throw new Error(`manifest verdict is ${manifest.verdict ?? 'missing'}`);
  const expected = gitInventory(sourceSha);
  const expectCountArg = argValue(args, '--expect-count');
  const expectCount = expectCountArg === undefined && (inventoryOnly || validateOutcome)
    ? expected.length
    : Number(expectCountArg);
  if (!Number.isInteger(expectCount) || expectCount < 1) throw new Error('--expect-count must be a positive integer');
  if (!Array.isArray(manifest.results) || manifest.results.length !== expectCount) {
    throw new Error(`manifest must contain exactly ${expectCount} result(s)`);
  }
  if (!Array.isArray(manifest.inventory) || !samePaths(manifest.inventory, manifest.results.map((entry) => entry.path))) {
    throw new Error('manifest inventory and result paths do not match exactly');
  }
  if (manifest.schema_version >= 2) {
    const inventoryHash = createHash('sha256').update(`${manifest.inventory.join('\n')}\n`).digest('hex');
    if (manifest.inventory_count !== manifest.inventory.length || manifest.inventory_sha256 !== inventoryHash) {
      throw new Error('manifest inventory count/hash does not match its path list');
    }
  }
  if ((inventoryOnly || validateOutcome) && manifest.scope !== 'full') throw new Error('recorded decision evidence must cover the full inventory');
  if ((inventoryOnly || validateOutcome) && !samePaths(expected, manifest.inventory)) {
    throw new Error(`manifest path set differs from the ${expected.length}-path inventory at ${sourceSha}`);
  }
  if (!manifest.inventory.every((entry) => expected.includes(assertSafeInventoryPath(entry)))) {
    throw new Error('manifest includes a path outside the tracked inventory at the requested source SHA');
  }
  for (const entry of manifest.results) {
    assertSafeInventoryPath(entry.path);
    const dimensionValid = manifest.schema_version >= 2
      ? Number.isInteger(entry.width_a) && entry.width_a > 0 && Number.isInteger(entry.height_a) && entry.height_a > 0 &&
        Number.isInteger(entry.width_b) && entry.width_b > 0 && Number.isInteger(entry.height_b) && entry.height_b > 0
      : Number.isInteger(entry.width) && entry.width > 0 && Number.isInteger(entry.height) && entry.height > 0;
    if (!dimensionValid && entry.result !== 'missing' && entry.result !== 'inconclusive') {
      throw new Error(`invalid dimensions for ${entry.path}`);
    }
    const hasMeasuredPixels = Number.isSafeInteger(entry.changed_pixels) && entry.changed_pixels >= 0;
    const nonPixelResult = ['missing', 'inconclusive', 'dimension-mismatch'].includes(entry.result);
    if (!hasMeasuredPixels && !nonPixelResult) throw new Error(`pixel result is missing for ${entry.path}`);
    const widthA = entry.width_a ?? entry.width;
    const widthB = entry.width_b ?? entry.width;
    const heightA = entry.height_a ?? entry.height;
    const heightB = entry.height_b ?? entry.height;
    if (manifest.verdict === 'zero-drift' && (!hasMeasuredPixels || entry.changed_pixels !== 0 || (entry.result && entry.result !== 'equal') || widthA !== widthB || heightA !== heightB)) {

      throw new Error(`comparison is not exact zero drift for ${entry.path}`);
    }
    if (!entry.render_a || !entry.render_b || !entry.diff) throw new Error(`render/diff artifact path missing for ${entry.path}`);
  }
  if (inventoryOnly && (
    !samePaths(expected, manifest.rendered_paths?.render_a ?? []) ||
    !samePaths(expected, manifest.rendered_paths?.render_b ?? [])
  )) {
    throw new Error('one or both rendered path sets differ from the complete tracked inventory');
  }
  if (validateOutcome) {
    for (const side of ['render_a', 'render_b']) {
      const actual = manifest.rendered_paths?.[side];
      if (!Array.isArray(actual)) throw new Error(`rendered path set is missing for ${side}`);
      actual.forEach(assertSafeInventoryPath);
      const missing = expected.filter((entry) => !actual.includes(entry));
      const extra = actual.filter((entry) => !expected.includes(entry));
      if (!samePaths(missing, manifest.missing_paths?.[side] ?? []) || !samePaths(extra, manifest.extra_paths?.[side] ?? [])) {
        throw new Error(`${side} missing/extra diagnostics do not match its rendered path set`);
      }
    }
  }
  if (manifest.schema_version >= 2 && manifest.verdict === 'zero-drift' && (
    manifest.total_changed_pixels !== 0 || manifest.missing_paths?.render_a?.length || manifest.missing_paths?.render_b?.length ||
    manifest.extra_paths?.render_a?.length || manifest.extra_paths?.render_b?.length
  )) {
    throw new Error('zero-drift verdict has changed pixels or inventory differences');
  }
  if (validateOutcome) {
    const driftObserved = manifest.results.some((entry) => entry.result === 'drift' || entry.result === 'dimension-mismatch' || entry.changed_pixels > 0);
    const uncertaintyObserved = manifest.results.some((entry) => ['missing', 'inconclusive'].includes(entry.result)) ||
      manifest.diagnostics?.length > 0 || manifest.missing_paths?.render_a?.length > 0 || manifest.missing_paths?.render_b?.length > 0 ||
      manifest.extra_paths?.render_a?.length > 0 || manifest.extra_paths?.render_b?.length > 0 ||
      Object.values(manifest.package_trio_statuses ?? {}).some((status) => status !== 'verified') ||
      Object.values(manifest.browser_manifest_statuses ?? {}).some((status) => status !== 'verified');
    if (manifest.verdict === 'drift' && !driftObserved) throw new Error('drift verdict has no changed-pixel or dimension evidence');
    if (manifest.verdict === 'inconclusive' && !uncertaintyObserved) throw new Error('inconclusive verdict has no diagnostic or incomplete result evidence');
    if (manifest.verdict === 'zero-drift' && (driftObserved || uncertaintyObserved)) throw new Error('zero-drift verdict conflicts with its result data');
  }
  console.log(JSON.stringify({ valid: true, source_sha: sourceSha, run_id: manifest.run_id, paths: manifest.inventory.length,
    verdict: manifest.verdict, merge_eligible: parsed.decision_eligibility?.merge_eligible === true }));
}

function strictAeOutput(stderr) {
  // ImageMagick 6 emits `AE (normalized AE)`, e.g. `1 (0.25)`; the
  // integer is the only decision metric and the optional ratio is syntax-checked.
  const match = stderr.match(/^\s*(\d+)(?:\s+\(((?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\))?\s*\r?\n?$/);
  if (!match) throw new Error(`ImageMagick AE output is unavailable or malformed: ${JSON.stringify(stderr.trim())}`);
  if (match[2] !== undefined && Number(match[2]) > 1) throw new Error('ImageMagick normalized AE metric is outside [0,1]');
  const count = Number(match[1]);
  if (!Number.isSafeInteger(count)) throw new Error('ImageMagick AE count is outside the safe integer range');
  return count;
}

function compare(args) {
  const [left, right, diff] = args;
  if (!left || !right || !diff || args.length !== 3) throw new Error('compare requires <render-a.png> <render-b.png> <diff.png>');
  const identify = imageCommand('identify');
  const dimensionsA = run(identify, ['-format', '%w %h', left]);
  const dimensionsB = run(identify, ['-format', '%w %h', right]);
  if (dimensionsA.status !== 0 || dimensionsB.status !== 0) {
    throw new Error(`ImageMagick identify failed (A=${dimensionsA.status}, B=${dimensionsB.status})`);
  }
  const parseDimensions = (value) => {
    const match = value.trim().match(/^(\d+)\s+(\d+)$/);
    if (!match) throw new Error(`ImageMagick returned malformed dimensions: ${JSON.stringify(value)}`);
    return { width: Number(match[1]), height: Number(match[2]) };
  };
  const sizeA = parseDimensions(dimensionsA.stdout);
  const sizeB = parseDimensions(dimensionsB.stdout);
  if (sizeA.width !== sizeB.width || sizeA.height !== sizeB.height) {
    throw new Error(`image dimensions differ: ${sizeA.width}x${sizeA.height} != ${sizeB.width}x${sizeB.height}`);
  }
  const result = run(imageCommand('compare'), ['-metric', 'AE', '-fuzz', '0%', left, right, diff]);
  if (result.status !== 0 && result.status !== 1) {
    throw new Error(`ImageMagick compare failed (exit ${result.status}): ${result.stderr.trim()}`);
  }
  if (result.stdout.trim()) throw new Error(`unexpected ImageMagick compare stdout: ${JSON.stringify(result.stdout)}`);
  const changedPixels = strictAeOutput(result.stderr);
  console.log(JSON.stringify({ changed_pixels: changedPixels, diff }));
  if (changedPixels !== 0) process.exitCode = 1;
}

async function buildManifest(args) {
  const sourceSha = argValue(args, '--source-sha');
  const runId = argValue(args, '--run-id');
  const branch = argValue(args, '--branch');
  const scope = argValue(args, '--scope');
  const inventoryFile = argValue(args, '--inventory-file');
  const renderA = argValue(args, '--render-a');
  const renderB = argValue(args, '--render-b');
  const artifactDir = argValue(args, '--artifact-dir');
  const revisionA = argValue(args, '--chromium-revision-a');
  const revisionB = argValue(args, '--chromium-revision-b');
  const packageA = argValue(args, '--package-a');
  const packageB = argValue(args, '--package-b');
  const packageTrioA = JSON.parse(argValue(args, '--package-trio-a') ?? '{}');
  const packageTrioB = JSON.parse(argValue(args, '--package-trio-b') ?? '{}');
  const packageTrioStatusA = argValue(args, '--package-trio-status-a') ?? 'unverified';
  const packageTrioStatusB = argValue(args, '--package-trio-status-b') ?? 'unverified';
  const browserVersionA = argValue(args, '--chromium-version-a');
  const browserVersionB = argValue(args, '--chromium-version-b');
  const browserManifestUrlA = argValue(args, '--browser-manifest-url-a');
  const browserManifestUrlB = argValue(args, '--browser-manifest-url-b');
  const browserManifestShaA = argValue(args, '--browser-manifest-sha-a');
  const browserManifestShaB = argValue(args, '--browser-manifest-sha-b');
  const browserManifestStatusA = argValue(args, '--browser-manifest-status-a') ?? 'unverified';
  const browserManifestStatusB = argValue(args, '--browser-manifest-status-b') ?? 'unverified';
  const runnerImage = argValue(args, '--runner-image');
  const artifactIdentifier = argValue(args, '--artifact-identifier');
  const runUrl = argValue(args, '--run-url');
  const comparatorVersionFile = argValue(args, '--comparator-version-file');
  const captureStatusA = argValue(args, '--capture-status-a') ?? '0';
  const captureStatusB = argValue(args, '--capture-status-b') ?? '0';
  const output = argValue(args, '--output');
  if (!sourceSha || !runId || !branch || !scope || !inventoryFile || !renderA || !renderB || !artifactDir || !output) {
    throw new Error('build-manifest is missing required arguments');
  }
  if (!SHA_RE.test(sourceSha) || !/^\d+$/.test(runId) || !branch.startsWith('phase-244/')) {
    throw new Error('build-manifest has invalid run identity');
  }
  if (!['tracer', 'full'].includes(scope)) throw new Error('scope must be tracer or full');
  const fullInventory = gitInventory(sourceSha);
  const suppliedInventory = JSON.parse(await readFile(inventoryFile, 'utf8'));
  if (suppliedInventory.source_sha !== sourceSha || !samePaths(fullInventory, suppliedInventory.paths ?? [])) {
    throw new Error('inventory input does not match git ls-tree at the requested source SHA');
  }
  const selected = scope === 'tracer'
    ? fullInventory.filter((entry) => entry.endsWith('-admin-checkpoints-chromium.png')).slice(0, 1)
    : fullInventory;
  if (selected.length === 0) throw new Error('the measured source SHA has no eligible tracked PNGs');

  const diagnostics = [];
  const missingPaths = new Set();
  for (const relativePath of selected) {
    const sourceA = path.join(renderA, relativePath);
    const sourceB = path.join(renderB, relativePath);
    const aStat = run('test', ['-f', sourceA]);
    const bStat = run('test', ['-f', sourceB]);
    if (aStat.status !== 0 || bStat.status !== 0) {
      diagnostics.push(`required screenshot was not rendered in both roots: ${relativePath}`);
      missingPaths.add(relativePath);
    }
  }
  let actualA = [];
  let actualB = [];
  if (scope === 'full') {
    actualA = await listPngs(renderA);
    actualB = await listPngs(renderB);
    if (!samePaths(fullInventory, actualA)) diagnostics.push('render-a path set differs from the tracked PNG inventory');
    if (!samePaths(fullInventory, actualB)) diagnostics.push('render-b path set differs from the tracked PNG inventory');
  } else {
    actualA = selected.filter((entry) => !missingPaths.has(entry));
    actualB = [...actualA];
  }
  const inventoryMismatch = scope === 'full' &&
    (!samePaths(fullInventory, actualA) || !samePaths(fullInventory, actualB));

  await mkdir(path.join(artifactDir, 'render-a'), { recursive: true });
  await mkdir(path.join(artifactDir, 'render-b'), { recursive: true });
  await mkdir(path.join(artifactDir, 'diffs'), { recursive: true });
  const results = [];
  for (const relativePath of selected) {
    const renderAFile = path.posix.join('render-a', relativePath);
    const renderBFile = path.posix.join('render-b', relativePath);
    const diffFile = path.posix.join('diffs', relativePath.replace(/\.png$/, '.diff.png'));
    const absoluteA = path.join(artifactDir, renderAFile);
    const absoluteB = path.join(artifactDir, renderBFile);
    const absoluteDiff = path.join(artifactDir, diffFile);
    if (missingPaths.has(relativePath)) {
      results.push({ path: relativePath, width_a: null, height_a: null, width_b: null, height_b: null, changed_pixels: null, result: 'missing', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    if (inventoryMismatch) {
      results.push({ path: relativePath, width_a: null, height_a: null, width_b: null, height_b: null, changed_pixels: null, result: 'inconclusive', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    await mkdir(path.dirname(absoluteA), { recursive: true });
    await mkdir(path.dirname(absoluteB), { recursive: true });
    await mkdir(path.dirname(absoluteDiff), { recursive: true });
    try {
      await copyFile(path.join(renderA, relativePath), absoluteA);
      await copyFile(path.join(renderB, relativePath), absoluteB);
    } catch (error) {
      diagnostics.push(`could not copy render artifact for ${relativePath}: ${error.message}`);
      results.push({ path: relativePath, width_a: null, height_a: null, width_b: null, height_b: null, changed_pixels: null, result: 'inconclusive', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    const dimensionsA = run(imageCommand('identify'), ['-format', '%w %h', absoluteA]);
    const dimensionsB = run(imageCommand('identify'), ['-format', '%w %h', absoluteB]);
    if (dimensionsA.status !== 0 || dimensionsB.status !== 0) {
      diagnostics.push(`could not read PNG dimensions for ${relativePath}: A=${dimensionsA.stderr.trim()} B=${dimensionsB.stderr.trim()}`);
      continue;
    }
    const dimensionPattern = /^(\d+)\s+(\d+)$/;
    const parsedA = dimensionsA.stdout.trim().match(dimensionPattern);
    const parsedB = dimensionsB.stdout.trim().match(dimensionPattern);
    if (!parsedA || !parsedB || parsedA.slice(1).some((value) => Number(value) < 1) || parsedB.slice(1).some((value) => Number(value) < 1)) {
      diagnostics.push(`malformed ImageMagick dimensions for ${relativePath}: A=${JSON.stringify(dimensionsA.stdout)} B=${JSON.stringify(dimensionsB.stdout)}`);
      continue;
    }
    const [widthA, heightA] = parsedA.slice(1).map(Number);
    const [widthB, heightB] = parsedB.slice(1).map(Number);
    if (widthA !== widthB || heightA !== heightB) {
      diagnostics.push(`render dimensions differ for ${relativePath}: ${widthA}x${heightA} != ${widthB}x${heightB}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'dimension-mismatch', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    const compareResult = run(imageCommand('compare'), ['-metric', 'AE', '-fuzz', '0%', absoluteA, absoluteB, absoluteDiff]);
    if (compareResult.status !== 0 && compareResult.status !== 1) {
      diagnostics.push(`ImageMagick compare failed for ${relativePath} (exit ${compareResult.status}): ${compareResult.stderr.trim()}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    if (compareResult.stdout.trim()) {
      diagnostics.push(`unexpected ImageMagick compare stdout for ${relativePath}: ${JSON.stringify(compareResult.stdout)}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stdout: compareResult.stdout, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    let changedPixels;
    try {
      changedPixels = strictAeOutput(compareResult.stderr);
    } catch (error) {
      diagnostics.push(`${relativePath}: ${error.message}; raw stderr=${JSON.stringify(compareResult.stderr)}`);
      results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: null, result: 'inconclusive', comparator_exit: compareResult.status, comparator_stderr: compareResult.stderr, render_a: renderAFile, render_b: renderBFile, diff: diffFile });
      continue;
    }
    results.push({ path: relativePath, width_a: widthA, height_a: heightA, width_b: widthB, height_b: heightB, changed_pixels: changedPixels, result: changedPixels === 0 ? 'equal' : 'drift', render_a: renderAFile, render_b: renderBFile, diff: diffFile });
  }
  const comparatorVersion = comparatorVersionFile ? (await readFile(comparatorVersionFile, 'utf8')).trim() : 'unknown';
  const expectedPackageVersion = argValue(args, '--expected-imagemagick-package');
  if (!expectedPackageVersion || !comparatorVersion.includes(`imagemagick=${expectedPackageVersion}`)) {
    throw new Error(`ImageMagick package identity mismatch: expected imagemagick=${expectedPackageVersion ?? 'unset'}`);
  }
  const expectedSet = scope === 'full' ? fullInventory : selected;
  const missingA = expectedSet.filter((entry) => !actualA.includes(entry));
  const missingB = expectedSet.filter((entry) => !actualB.includes(entry));
  const extraA = actualA.filter((entry) => !expectedSet.includes(entry));
  const extraB = actualB.filter((entry) => !expectedSet.includes(entry));
  const inventoryHash = createHash('sha256').update(`${selected.join('\n')}\n`).digest('hex');
  const provenanceIncomplete = [packageTrioStatusA, packageTrioStatusB, browserManifestStatusA, browserManifestStatusB].some((status) => status !== 'verified');
  const manifest = {
    schema_version: 3,
    workflow_name: 'Phase 244 Playwright measurement',
    event: 'workflow_dispatch',
    head_branch: branch,
    source_sha: sourceSha,
    run_id: runId,
    run_url: runUrl ?? '',
    runner: { image: runnerImage ?? 'unknown', os: process.env.RUNNER_OS ?? 'unknown' },
    artifact_identifier: artifactIdentifier ?? '',
    scope,
    inventory: selected,
    inventory_count: selected.length,
    inventory_sha256: inventoryHash,
    missing_paths: { render_a: missingA, render_b: missingB },
    extra_paths: { render_a: extraA, render_b: extraB },
    rendered_paths: { render_a: actualA, render_b: actualB },
    package_versions: { render_a: packageA ?? 'unknown', render_b: packageB ?? 'unknown' },
    package_trios: { render_a: packageTrioA, render_b: packageTrioB },
    package_trio_statuses: { render_a: packageTrioStatusA, render_b: packageTrioStatusB },
    chromium_revisions: { render_a: revisionA ?? 'unknown', render_b: revisionB ?? 'unknown' },
    chromium_versions: { render_a: browserVersionA ?? 'unknown', render_b: browserVersionB ?? 'unknown' },
    browser_manifests: {
      render_a: { url: browserManifestUrlA ?? '', sha256: browserManifestShaA ?? '' },
      render_b: { url: browserManifestUrlB ?? '', sha256: browserManifestShaB ?? '' },
    },
    browser_manifest_statuses: { render_a: browserManifestStatusA, render_b: browserManifestStatusB },
    comparator: { name: 'ImageMagick compare -metric AE -fuzz 0%', package: `imagemagick=${expectedPackageVersion}`, version: comparatorVersion },
    results,
    total_changed_pixels: results.reduce((sum, entry) => sum + (Number.isSafeInteger(entry.changed_pixels) ? entry.changed_pixels : 0), 0),
    diagnostics: [
      ...(captureStatusA === '0' ? [] : [`render-a capture exited ${captureStatusA}`]),
      ...(captureStatusB === '0' ? [] : [`render-b capture exited ${captureStatusB}`]),
      ...(packageTrioStatusA === 'verified' ? [] : ['render-a installed package trio is unverified']),
      ...(packageTrioStatusB === 'verified' ? [] : ['render-b installed package trio is unverified']),
      ...(browserManifestStatusA === 'verified' ? [] : ['render-a tagged browser manifest is unverified']),
      ...(browserManifestStatusB === 'verified' ? [] : ['render-b tagged browser manifest is unverified']),
      ...diagnostics,
    ],
    verdict: !provenanceIncomplete && results.some((entry) => entry.result === 'drift' || entry.result === 'dimension-mismatch' || entry.changed_pixels > 0)
      ? 'drift'
      : provenanceIncomplete || captureStatusA !== '0' || captureStatusB !== '0' || diagnostics.length > 0 || results.some((entry) => entry.result !== 'equal') || missingA.length > 0 || missingB.length > 0 || extraA.length > 0 || extraB.length > 0
        ? 'inconclusive' : 'zero-drift',
  };
  await writeFile(output, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  if (manifest.verdict !== 'zero-drift') throw new Error(`measurement verdict is ${manifest.verdict}; see manifest and diff artifacts`);
  console.log(JSON.stringify({ valid: true, source_sha: sourceSha, run_id: runId, paths: results.length, verdict: manifest.verdict }));
}

async function listPngs(root) {
  const snapshotRoot = path.join(root, 'test/example/priv/playwright/tests');
  const result = run('find', [snapshotRoot, '-type', 'f', '-path', '*-snapshots/*.png', '-print']);
  if (result.status !== 0) throw new Error(`could not list rendered PNGs under ${root}`);
  return result.stdout.split(/\r?\n/).filter(Boolean).map((file) => path.relative(root, file).split(path.sep).join('/')).map(assertSafeInventoryPath).sort();
}

async function main() {
  const [, , command, ...args] = process.argv;
  if (command === 'verify-provenance') return await verifyProvenance(args);
  if (command === 'evaluate-eligibility') return await evaluateEligibilityCommand(args);
  if (command === 'verify-eligibility') return await verifyEligibilityCommand(args);
  if (command === 'collect-authorization') return await collectAuthorization(args);
  if (command === 'verify') return await verifyManifest(args);
  if (command === 'compare') return compare(args);
  if (command === 'build-manifest') return await buildManifest(args);
  if (command === 'inventory') {
    const sourceSha = argValue(args, '--source-sha');
    if (!sourceSha) throw new Error('inventory requires --source-sha');
    console.log(JSON.stringify({ source_sha: sourceSha, paths: gitInventory(sourceSha) }, null, 2));
    return;
  }
  throw new Error('usage: measure-playwright-drift.mjs inventory|compare|verify ...');
}

main().catch((error) => fail(error.message));
