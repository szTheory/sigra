#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFileSync, renameSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const GIT_BIN = "/usr/bin/git";

export const PINNED_BASELINE = Object.freeze({
  commit: "9c0a6b818d2d58858b5db274cc1cf0a9803f69f5",
  state_path: ".planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json",
  evidence_path: ".planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.json",
  state_blob: "913e4d0ab10cfa3b4fb42bd4d347d47f5832dc85",
  evidence_blob: "eb9f3fa848e41578bd6f6d03d375f66207bbc8e9",
});

const MAIN_OID = "5a00b90d2314bc93f27aec4090b5928018743d1b";
const EXPECTED_KEYS = Object.freeze([
  { number: 219, base_ref: "main", base_sha: "f06137b2ac0e9b2094aa1250e3c036b41e997651" },
  ...Array.from({ length: 10 }, (_, index) => ({
    number: 266 + index,
    base_ref: "main",
    base_sha: "fed35a4a3725d217486f45a571421dbbf5721765",
  })),
]);
const PER_PAGE = 100;
const SOURCE_NAMES = ["inventory", "detail", "base_api", "base_ls_remote", "head_api", "head_ls_remote"];

const now = () => new Date().toISOString();
const stable = (value) => JSON.stringify(sortObject(value));
function sortObject(value) {
  if (Array.isArray(value)) return value.map(sortObject);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, sortObject(value[key])]));
}

export function deriveExpectedMismatchKeys(openPrState, evidence) {
  const classification = evidence?.wave3_classification;
  const defaultRef = classification?.default_ref;
  const defaultOid = classification?.default_oid;
  if (!Array.isArray(openPrState?.pull_requests) || typeof defaultRef !== "string" || !/^[0-9a-f]{40}$/i.test(defaultOid ?? "")) return [];
  const defaultBranch = defaultRef.replace(/^refs\/heads\//, "");
  return openPrState.pull_requests
    .filter((pr) => pr?.baseRefName === defaultBranch && /^[0-9a-f]{40}$/i.test(pr?.baseRefOid ?? "") && pr.baseRefOid.toLowerCase() !== defaultOid.toLowerCase())
    .map((pr) => ({ number: Number(pr.number), base_ref: pr.baseRefName, base_sha: pr.baseRefOid.toLowerCase() }))
    .sort((a, b) => a.number - b.number);
}

const equalIdentity = (left, right) => stable(left) === stable(right);
const isTimestamp = (value) => typeof value === "string" && Number.isFinite(Date.parse(value));
const sha = (value) => typeof value === "string" && /^[0-9a-f]{40}$/i.test(value);
const nonEmpty = (value) => typeof value === "string" && value.length > 0;

export function evaluateHistoricalRow(row, inventoryComplete) {
  const reasons = [];
  if (!inventoryComplete) reasons.push("open_pr_enumeration_incomplete");
  if (!row || typeof row !== "object") return { disposition: "unresolved", reasons: ["historical_row_missing"] };
  if (!row.current_inventory || !row.current_pr) reasons.push("current_pr_identity_missing");
  else {
    if (Number(row.current_pr.number) !== Number(row.key?.number)) reasons.push("pr_detail_number_disagrees_with_historical_key");
    if (row.current_pr.state !== "OPEN") reasons.push("current_pr_not_open");
    if (!equalIdentity(row.current_inventory, row.current_pr)) reasons.push("open_pr_inventory_disagrees_with_pr_detail");
    for (const side of ["base", "head"]) {
      const identity = row.current_pr[side];
      if (!identity || !nonEmpty(identity.repository) || !nonEmpty(identity.ref) || !sha(identity.sha)) reasons.push(`current_${side}_identity_incomplete`);
      const exact = row.exact_refs?.[side];
      const api = exact?.api;
      const remote = exact?.ls_remote;
      if (!api || api.status !== "ok" || !equalIdentity(
        { repository: api.repository, branch: api.branch, ref: api.ref, sha: api.sha },
        { repository: identity?.repository, branch: identity?.ref, ref: identity?.ref ? `refs/heads/${identity.ref}` : null, sha: identity?.sha },
      )) reasons.push(`current_${side}_github_ref_disagrees_with_pr`);
      const expectedFullRef = identity?.ref ? `refs/heads/${identity.ref}` : null;
      if (!remote || remote.status !== "ok" || remote.repository !== identity?.repository || remote.ref !== expectedFullRef || remote.sha !== identity?.sha) {
        reasons.push(`current_${side}_ls_remote_disagrees_with_pr`);
      }
    }
  }
  for (const name of SOURCE_NAMES) {
    const source = row.provenance?.[name];
    if (!source || !nonEmpty(source.endpoint) || !isTimestamp(source.requested_at) || !isTimestamp(source.completed_at)) {
      reasons.push(`${name}_provenance_missing`);
    } else if (source.status !== "ok") {
      reasons.push(`${name}_provenance_unavailable`);
    }
  }
  return { disposition: reasons.length === 0 ? "resolved" : "unresolved", reasons: [...new Set(reasons)].sort() };
}

export function validateAudit(audit) {
  const errors = [];
  if (audit?.schema_version !== 1) errors.push("unsupported_audit_schema");
  if (!nonEmpty(audit?.audit_id)) errors.push("audit_id_missing");
  if (audit?.baseline?.commit !== PINNED_BASELINE.commit) errors.push("baseline_commit_not_pinned");
  if (audit?.baseline?.state_blob !== PINNED_BASELINE.state_blob) errors.push("baseline_state_blob_not_pinned");
  if (audit?.baseline?.evidence_blob !== PINNED_BASELINE.evidence_blob) errors.push("baseline_evidence_blob_not_pinned");
  if (audit?.baseline?.default_ref !== "refs/heads/main" || audit?.baseline?.default_sha !== MAIN_OID) errors.push("baseline_default_ref_identity_not_pinned");
  if (stable(audit?.baseline?.historical_mismatch_keys) !== stable(EXPECTED_KEYS)) errors.push("historical_mismatch_keys_not_exact");
  const rows = audit?.rows;
  if (!Array.isArray(rows) || rows.length !== EXPECTED_KEYS.length) errors.push("historical_row_count_mismatch");
  const rowKeys = Array.isArray(rows) ? rows.map((row) => Number(row?.key?.number)) : [];
  if (new Set(rowKeys).size !== rowKeys.length) errors.push("duplicate_historical_row_key");
  const expectedNumbers = EXPECTED_KEYS.map((item) => item.number);
  if (stable([...rowKeys].sort((a, b) => a - b)) !== stable(expectedNumbers)) errors.push("missing_or_unexpected_historical_row_key");
  const inventory = audit?.full_open_pr_inventory;
  if (!inventory || typeof inventory.complete !== "boolean" || !Array.isArray(inventory.pages) || !Array.isArray(inventory.items)) {
    errors.push("full_open_pr_inventory_provenance_missing");
  } else {
    if (inventory.items.some((item) => !Number.isInteger(item?.number))) errors.push("inventory_row_number_missing");
    if (new Set(inventory.items.map((item) => item.number)).size !== inventory.items.length) errors.push("duplicate_open_pr_inventory_number");
    if (inventory.pages.length === 0) errors.push("inventory_page_provenance_missing");
    const pageNumbers = [];
    for (const page of inventory.pages) {
      if (!nonEmpty(page?.endpoint) || !isTimestamp(page?.requested_at) || !isTimestamp(page?.completed_at) || !Number.isInteger(page?.page) || !Number.isInteger(page?.item_count)) {
        errors.push("inventory_page_provenance_incomplete");
      }
      if (page?.status === "ok") {
        if (!Array.isArray(page.numbers) || page.numbers.length !== page.item_count || typeof page.has_next !== "boolean") errors.push("inventory_page_membership_provenance_incomplete");
        else pageNumbers.push(...page.numbers);
      }
    }
    if (inventory.complete) {
      if (inventory.pages.at(-1)?.has_next !== false || inventory.pages.some((page, index) => page?.status !== "ok" || (index < inventory.pages.length - 1 && page.has_next !== true))) errors.push("inventory_pagination_completion_not_proven");
      if (stable(pageNumbers.sort((a, b) => a - b)) !== stable(inventory.items.map((item) => item.number).sort((a, b) => a - b))) errors.push("inventory_page_membership_does_not_match_rows");
    }
  }
  let resolvedCount = 0;
  for (const row of Array.isArray(rows) ? rows : []) {
    const expected = EXPECTED_KEYS.find((item) => item.number === Number(row?.key?.number));
    if (!expected || row?.key?.base_ref !== expected.base_ref || row?.key?.base_sha !== expected.base_sha) errors.push(`historical_key_value_mismatch:${row?.key?.number ?? "unknown"}`);
    if (row?.historical_source?.commit !== PINNED_BASELINE.commit || row?.historical_source?.state_blob !== PINNED_BASELINE.state_blob || row?.historical_source?.evidence_blob !== PINNED_BASELINE.evidence_blob) {
      errors.push(`historical_source_provenance_mismatch:${row?.key?.number ?? "unknown"}`);
    }
    const evaluation = evaluateHistoricalRow(row, inventory?.complete === true);
    if (row?.disposition !== evaluation.disposition) errors.push(`row_disposition_not_corroborated:${row?.key?.number ?? "unknown"}`);
    if (row?.disposition === "resolved") resolvedCount += 1;
    if (row?.disposition === "unresolved" && (!Array.isArray(row?.unresolved_reasons) || row.unresolved_reasons.length === 0)) errors.push(`unresolved_row_lacks_specific_reason:${row?.key?.number ?? "unknown"}`);
    if (row?.disposition === "unresolved" && stable([...row.unresolved_reasons].sort()) !== stable(evaluation.reasons)) errors.push(`unresolved_row_reason_mismatch:${row?.key?.number ?? "unknown"}`);
  }
  return { valid: errors.length === 0, errors: [...new Set(errors)].sort(), resolved_count: resolvedCount, unresolved_count: EXPECTED_KEYS.length - resolvedCount };
}

function sourceRecord(endpoint, status, extra = {}, requestedAt = now()) {
  return { endpoint, requested_at: requestedAt, completed_at: now(), status, ...extra };
}

function identityFromPull(pull) {
  return {
    number: Number(pull?.number),
    state: typeof pull?.state === "string" ? pull.state.toUpperCase() : null,
    base: {
      repository: pull?.base?.repo?.full_name ?? null,
      ref: pull?.base?.ref ?? null,
      sha: pull?.base?.sha ?? null,
    },
    head: {
      repository: pull?.head?.repo?.full_name ?? null,
      ref: pull?.head?.ref ?? null,
      sha: pull?.head?.sha ?? null,
    },
  };
}

function ghJson(endpoint) {
  const requestedAt = now();
  const result = spawnSync("gh", ["api", endpoint], { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  const completedAt = now();
  if (result.status === 0) {
    try {
      return { ok: true, value: JSON.parse(result.stdout), provenance: { endpoint, requested_at: requestedAt, completed_at: completedAt, status: "ok", response_status: 200 } };
    } catch (error) {
      return { ok: false, value: null, provenance: { endpoint, requested_at: requestedAt, completed_at: completedAt, status: "invalid_json", response_status: null, error: error.message } };
    }
  }
  return { ok: false, value: null, provenance: { endpoint, requested_at: requestedAt, completed_at: completedAt, status: "error", response_status: Number.isInteger(result.status) ? result.status : null, error: String(result.stderr || result.error?.message || "gh api failed").trim().slice(0, 400) } };
}

function normalizeInventoryPageRow(pull) {
  return identityFromPull(pull);
}

function collectOpenInventory() {
  const pages = [];
  const items = [];
  let complete = false;
  for (let page = 1; page <= 100; page += 1) {
    const endpoint = `repos/szTheory/sigra/pulls?state=open&per_page=${PER_PAGE}&page=${page}`;
    const response = ghJson(endpoint);
    const provenance = { page, endpoint, requested_at: response.provenance.requested_at, completed_at: response.provenance.completed_at, status: response.provenance.status, response_status: response.provenance.response_status, item_count: Array.isArray(response.value) ? response.value.length : 0, numbers: [], has_next: null };
    if (!response.ok || !Array.isArray(response.value) || response.value.length > PER_PAGE) {
      if (response.ok) provenance.status = "invalid_page";
      provenance.error = response.provenance.error ?? "open_pr_page_not_an_array_or_exceeded_page_size";
      pages.push(provenance);
      break;
    }
    const pageRows = response.value.map(normalizeInventoryPageRow);
    items.push(...pageRows);
    provenance.numbers = pageRows.map((item) => item.number);
    provenance.has_next = pageRows.length === PER_PAGE;
    pages.push(provenance);
    if (!provenance.has_next) {
      complete = true;
      break;
    }
  }
  if (!complete && pages.length === 100 && pages[99]?.has_next === true) {
    pages.push({ page: 101, endpoint: "pagination-limit", requested_at: now(), completed_at: now(), status: "page_limit", response_status: null, item_count: 0, has_next: null, error: "open_pr_inventory_exceeded_100_pages" });
  }
  return { complete, pages, items };
}

function exactRemoteUrl(repository) {
  return `https://github.com/${repository}.git`;
}

function exactRefEndpoint(repository, branch) {
  return `repos/${repository}/git/ref/heads/${encodeURIComponent(branch)}`;
}

function collectExactRef(repository, branch) {
  const apiEndpoint = exactRefEndpoint(repository, branch);
  const apiResponse = ghJson(apiEndpoint);
  const apiSha = apiResponse.ok ? apiResponse.value?.object?.sha ?? null : null;
  const observedApiRef = apiResponse.ok ? apiResponse.value?.ref ?? null : null;
  const api = {
    status: apiResponse.ok && sha(apiSha) && observedApiRef === `refs/heads/${branch}` ? "ok" : apiResponse.ok ? "invalid_response" : apiResponse.provenance.status,
    repository,
    branch,
    ref: observedApiRef,
    sha: sha(apiSha) ? apiSha.toLowerCase() : null,
    endpoint: apiEndpoint,
  };
  const fullRef = `refs/heads/${branch}`;
  const remoteUrl = exactRemoteUrl(repository);
  const requestedAt = now();
  const result = spawnSync(GIT_BIN, ["ls-remote", "--heads", remoteUrl, fullRef], { encoding: "utf8", maxBuffer: 2 * 1024 * 1024 });
  const completedAt = now();
  let found = null;
  if (result.status === 0) {
    for (const line of String(result.stdout).trim().split(/\r?\n/)) {
      const match = line.match(/^([0-9a-f]{40})\s+(.+)$/i);
      if (match && match[2] === fullRef) found = match[1].toLowerCase();
    }
  }
  const remote = {
    status: result.status === 0 && sha(found) ? "ok" : result.status === 0 ? "missing" : "error",
    repository,
    ref: found ? fullRef : null,
    sha: found,
    endpoint: `git ls-remote ${remoteUrl} ${fullRef}`,
  };
  return {
    api,
    ls_remote: remote,
    provenance: {
      api: apiResponse.provenance,
      ls_remote: { endpoint: remote.endpoint, requested_at: requestedAt, completed_at: completedAt, status: remote.status, exit_code: result.status, remote_url: remoteUrl, requested_ref: fullRef, error: result.status === 0 ? null : String(result.stderr || result.error?.message || "git ls-remote failed").trim().slice(0, 400) },
    },
  };
}

function detailFor(number) {
  const endpoint = `repos/szTheory/sigra/pulls/${number}`;
  const response = ghJson(endpoint);
  return { ok: response.ok, identity: response.ok ? identityFromPull(response.value) : null, provenance: response.provenance };
}

function inventoryFor(inventory, number) {
  return inventory.items.find((item) => item.number === number) ?? null;
}

function collectHistoricalRows(keys, inventory) {
  return keys.map((key) => {
    const listed = inventoryFor(inventory, key.number);
    const detail = detailFor(key.number);
    const current = detail.identity;
    const baseRepository = current?.base?.repository ?? listed?.base?.repository;
    const baseRef = current?.base?.ref ?? listed?.base?.ref;
    const headRepository = current?.head?.repository ?? listed?.head?.repository;
    const headRef = current?.head?.ref ?? listed?.head?.ref;
    const baseRefObservation = baseRepository && baseRef ? collectExactRef(baseRepository, baseRef) : null;
    const headRefObservation = headRepository && headRef ? collectExactRef(headRepository, headRef) : null;
    const pageIndex = inventory.pages.find((page) => Array.isArray(page.numbers) && page.numbers.includes(key.number));
    const row = {
      key,
      historical_source: { commit: PINNED_BASELINE.commit, state_blob: PINNED_BASELINE.state_blob, evidence_blob: PINNED_BASELINE.evidence_blob },
      current_inventory: listed,
      current_pr: current,
      exact_refs: {
        base: baseRefObservation ? { api: baseRefObservation.api, ls_remote: baseRefObservation.ls_remote } : null,
        head: headRefObservation ? { api: headRefObservation.api, ls_remote: headRefObservation.ls_remote } : null,
      },
      provenance: {
        inventory: pageIndex ? { ...pageIndex, page_complete: inventory.complete } : { endpoint: "open-pr-inventory", requested_at: now(), completed_at: now(), status: inventory.complete ? "row_not_found" : "enumeration_incomplete", page: null, page_complete: inventory.complete },
        detail: detail.provenance,
        base_api: baseRefObservation?.provenance.api ?? { endpoint: baseRepository && baseRef ? exactRefEndpoint(baseRepository, baseRef) : "exact-base-ref-unavailable", requested_at: now(), completed_at: now(), status: "unavailable" },
        base_ls_remote: baseRefObservation?.provenance.ls_remote ?? { endpoint: "git ls-remote unavailable: base repository/ref missing", requested_at: now(), completed_at: now(), status: "unavailable" },
        head_api: headRefObservation?.provenance.api ?? { endpoint: headRepository && headRef ? exactRefEndpoint(headRepository, headRef) : "exact-head-ref-unavailable", requested_at: now(), completed_at: now(), status: "unavailable" },
        head_ls_remote: headRefObservation?.provenance.ls_remote ?? { endpoint: "git ls-remote unavailable: head repository/ref missing", requested_at: now(), completed_at: now(), status: "unavailable" },
      },
      ancestry: { historical_sha_readable: null, historical_sha_is_ancestor: null, note: "Ancestry is not used to resolve a historical identity mismatch." },
    };
    const evaluation = evaluateHistoricalRow(row, inventory.complete);
    row.disposition = evaluation.disposition;
    row.unresolved_reasons = evaluation.reasons;
    return row;
  });
}

function runGit(repo, args) {
  return execFileSync(GIT_BIN, ["-C", repo, ...args], { encoding: "utf8" }).trim();
}

function readPinnedInputs(repo, commit, baselinePath = PINNED_BASELINE.state_path) {
  if (commit !== PINNED_BASELINE.commit || baselinePath !== PINNED_BASELINE.state_path) throw new Error("pinned_historical_source_commit_or_path_mismatch");
  const stateTree = runGit(repo, ["ls-tree", commit, PINNED_BASELINE.state_path]);
  const evidenceTree = runGit(repo, ["ls-tree", commit, PINNED_BASELINE.evidence_path]);
  const stateBlob = stateTree.split(/\s+/)[2];
  const evidenceBlob = evidenceTree.split(/\s+/)[2];
  if (stateBlob !== PINNED_BASELINE.state_blob || evidenceBlob !== PINNED_BASELINE.evidence_blob) throw new Error("pinned_historical_source_blob_mismatch");
  const state = JSON.parse(runGit(repo, ["show", `${commit}:${PINNED_BASELINE.state_path}`]));
  const evidence = JSON.parse(runGit(repo, ["show", `${commit}:${PINNED_BASELINE.evidence_path}`]));
  const keys = deriveExpectedMismatchKeys(state, evidence);
  if (stable(keys) !== stable(EXPECTED_KEYS)) throw new Error("immutable_source_does_not_derive_the_pinned_11_keys");
  return { state, evidence, keys, source: { commit, state_blob: stateBlob, evidence_blob: evidenceBlob, default_ref: evidence.wave3_classification.default_ref, default_sha: evidence.wave3_classification.default_oid } };
}

function captureLive(repo, baselineCommit, baselinePath) {
  const inputs = readPinnedInputs(repo, baselineCommit, baselinePath);
  const inventory = collectOpenInventory();
  const rows = collectHistoricalRows(inputs.keys, inventory);
  return {
    schema_version: 1,
    audit_id: randomUUID(),
    captured_at: now(),
    repository: "szTheory/sigra",
    baseline: { ...inputs.source, historical_mismatch_keys: inputs.keys },
    full_open_pr_inventory: inventory,
    rows,
  };
}

function localBlobIdentity(repo, auditPath) {
  const rel = relative(repo, resolve(repo, auditPath));
  if (!rel || rel.startsWith("../") || isAbsolute(rel)) throw new Error("audit_path_outside_repository");
  const commit = runGit(repo, ["log", "-1", "--format=%H", "--", rel]);
  if (!commit) throw new Error("audit_not_committed");
  const treeLine = runGit(repo, ["ls-tree", commit, rel]);
  const blob = treeLine.split(/\s+/)[2];
  const fileBlob = runGit(repo, ["hash-object", resolve(repo, auditPath)]);
  if (!blob || blob !== fileBlob) throw new Error("committed_audit_blob_does_not_match_working_file");
  return { path: rel, commit, blob };
}

function compareIdentity(left, right) {
  return equalIdentity(left, right);
}

function baselineIdentity(row) {
  return {
    number: Number(row.number),
    state: String(row.state ?? "").toUpperCase(),
    base: { ref: row.baseRefName, sha: String(row.baseRefOid ?? "").toLowerCase() },
    head: { ref: row.headRefName, sha: String(row.headRefOid ?? "").toLowerCase() },
  };
}

function baselineFieldsMatch(current, expected, allowHistoricalBaseMismatch) {
  if (!current || !expected || current.number !== expected.number || current.state !== expected.state) return false;
  if (current.base?.ref !== expected.base.ref || current.head?.ref !== expected.head.ref || current.head?.sha !== expected.head.sha) return false;
  return allowHistoricalBaseMismatch || current.base?.sha === expected.base.sha;
}

function collectNonExceptionBaseRef(identity) {
  if (!identity?.base?.repository || !identity?.base?.ref) return { identity, status: "unavailable", reasons: ["current_base_repository_or_ref_missing"] };
  const exact = collectExactRef(identity.base.repository, identity.base.ref);
  const reasons = [];
  if (exact.api.status !== "ok" || exact.api.ref !== `refs/heads/${identity.base.ref}` || exact.api.sha !== identity.base.sha) reasons.push("github_base_ref_disagrees_with_current_pr");
  if (exact.ls_remote.status !== "ok" || exact.ls_remote.sha !== identity.base.sha) reasons.push("ls_remote_base_ref_disagrees_with_current_pr");
  return { identity, exact_refs: { api: exact.api, ls_remote: exact.ls_remote }, provenance: exact.provenance, status: reasons.length ? "unresolved" : "resolved", reasons };
}

function verifyLive(repo, auditPath, baselineFile, baselineCommit, baselinePath, commandText) {
  const audit = JSON.parse(readFileSync(auditPath, "utf8"));
  const auditCheck = validateAudit(audit);
  const auditIdentity = localBlobIdentity(repo, auditPath);
  const baseline = JSON.parse(readFileSync(baselineFile, "utf8"));
  const inputs = readPinnedInputs(repo, baselineCommit, baselinePath);
  const inventory = collectOpenInventory();
  const freshRows = collectHistoricalRows(inputs.keys, inventory);
  const reasons = [];
  if (!auditCheck.valid) reasons.push(...auditCheck.errors.map((reason) => `committed_audit_invalid:${reason}`));
  if (!inventory.complete) reasons.push("fresh_open_pr_enumeration_incomplete");
  if (audit.full_open_pr_inventory?.complete !== true) reasons.push("committed_audit_open_pr_enumeration_incomplete");
  if (!compareIdentity(inventory.items, audit.full_open_pr_inventory?.items)) reasons.push("current_open_pr_inventory_drifted_from_committed_audit");
  const baselineRows = Array.isArray(baseline?.pull_requests) ? baseline.pull_requests : [];
  const baselineNumbers = baselineRows.map((row) => Number(row.number));
  if (new Set(baselineNumbers).size !== baselineNumbers.length) reasons.push("baseline_pr_inventory_has_duplicate_number");
  if (stable([...baselineNumbers].sort((a, b) => a - b)) !== stable(inventory.items.map((row) => row.number).sort((a, b) => a - b))) reasons.push("current_open_pr_number_set_changed_from_baseline");
  for (const freshRow of freshRows) {
    const oldRow = audit.rows.find((row) => row.key.number === freshRow.key.number);
    if (!oldRow) {
      reasons.push(`committed_audit_row_missing:${freshRow.key.number}`);
      continue;
    }
    if (oldRow.disposition !== "resolved") reasons.push(`committed_audit_row_unresolved:${freshRow.key.number}:${oldRow.unresolved_reasons.join(",")}`);
    if (freshRow.disposition !== "resolved") reasons.push(`fresh_pr_identity_unresolved:${freshRow.key.number}:${freshRow.unresolved_reasons.join(",")}`);
    for (const field of ["current_inventory", "current_pr", "exact_refs"]) {
      if (!equalIdentity(freshRow[field], oldRow[field])) reasons.push(`fresh_${field}_drifted:${freshRow.key.number}`);
    }
  }
  const exceptionNumbers = new Set(inputs.keys.map((item) => item.number));
  const nonExceptionBaseRefs = [];
  const inventoryByNumber = new Map(inventory.items.map((item) => [item.number, item]));
  for (const oldBaselineRow of baselineRows) {
    const number = Number(oldBaselineRow.number);
    const current = inventoryByNumber.get(number);
    if (!current) {
      reasons.push(`baseline_pr_missing_or_closed:${number}`);
      continue;
    }
    const expected = baselineIdentity(oldBaselineRow);
    if (exceptionNumbers.has(number)) {
      if (!baselineFieldsMatch(current, expected, true)) reasons.push(`historical_exception_current_identity_drifted:${number}`);
    } else {
      if (!baselineFieldsMatch(current, expected, false)) reasons.push(`baseline_pr_identity_changed:${number}`);
      const exact = collectNonExceptionBaseRef(current);
      nonExceptionBaseRefs.push(exact);
      if (exact.status !== "resolved") reasons.push(...exact.reasons.map((reason) => `${reason}:${number}`));
      if (current.base.sha !== expected.base.sha) reasons.push(`pr_base_oid_mismatch:${number}`);
    }
  }
  const rows = freshRows.map((row) => ({ key: row.key, disposition: row.disposition, current_inventory: row.current_inventory, current_pr: row.current_pr, exact_refs: row.exact_refs, provenance: row.provenance, unresolved_reasons: row.unresolved_reasons }));
  const integrity = {
    schema_version: 1,
    integrity_id: randomUUID(),
    created_at: now(),
    repository: "szTheory/sigra",
    outcome: reasons.length === 0 ? "passed" : "blocked",
    audit: { audit_id: audit.audit_id, source_commit: auditIdentity.commit, source_blob: auditIdentity.blob, path: auditIdentity.path },
    baseline: { commit: inputs.source.commit, state_blob: inputs.source.state_blob, evidence_blob: inputs.source.evidence_blob, default_ref: inputs.source.default_ref, default_sha: inputs.source.default_sha },
    verify_prs: { command: commandText, exit_status: null },
    fresh_open_pr_inventory: inventory,
    checked_historical_rows: rows,
    checked_non_exception_base_refs: nonExceptionBaseRefs,
    reasons: [...new Set(reasons)].sort(),
  };
  return integrity;
}

function atomicWrite(path, value) {
  const destination = resolve(path);
  mkdirSync(dirname(destination), { recursive: true });
  const temporary = `${destination}.${process.pid}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o644 });
  renameSync(temporary, destination);
}

export function validateFinal(audit, integrity) {
  const auditResult = validateAudit(audit);
  const errors = [...auditResult.errors];
  if (integrity?.schema_version !== 1) errors.push("unsupported_integrity_schema");
  if (integrity?.audit?.audit_id !== audit?.audit_id) errors.push("integrity_audit_id_mismatch");
  if (integrity?.baseline?.commit !== PINNED_BASELINE.commit || integrity?.baseline?.state_blob !== PINNED_BASELINE.state_blob || integrity?.baseline?.evidence_blob !== PINNED_BASELINE.evidence_blob) errors.push("integrity_baseline_identity_mismatch");
  if (!nonEmpty(integrity?.audit?.source_commit) || !sha(integrity?.audit?.source_blob)) errors.push("integrity_audit_commit_or_blob_missing");
  if (!nonEmpty(integrity?.verify_prs?.command) || !Number.isInteger(integrity?.verify_prs?.exit_status)) errors.push("integrity_verify_prs_command_or_exit_status_missing");
  if (!/\bverify-prs\b/.test(integrity?.verify_prs?.command ?? "") || !/--identity-audit\s+/.test(integrity?.verify_prs?.command ?? "") || !/--integrity-output\s+/.test(integrity?.verify_prs?.command ?? "")) errors.push("integrity_command_does_not_pin_audit_and_output");
  if (!Array.isArray(integrity?.checked_historical_rows) || integrity.checked_historical_rows.length !== EXPECTED_KEYS.length) errors.push("integrity_historical_row_count_mismatch");
  if (!Array.isArray(integrity?.reasons)) errors.push("integrity_reason_list_missing");
  const checkedRows = Array.isArray(integrity?.checked_historical_rows) ? integrity.checked_historical_rows : [];
  const checkedNumbers = checkedRows.map((row) => Number(row?.key?.number));
  if (new Set(checkedNumbers).size !== checkedNumbers.length || stable([...checkedNumbers].sort((a, b) => a - b)) !== stable(EXPECTED_KEYS.map((item) => item.number))) errors.push("integrity_historical_key_set_mismatch");
  for (const checked of checkedRows) {
    const audited = audit?.rows?.find((row) => Number(row.key.number) === Number(checked?.key?.number));
    if (!audited || checked.disposition !== audited.disposition) errors.push(`integrity_row_disposition_mismatch:${checked?.key?.number ?? "unknown"}`);
    if (checked.disposition === "unresolved" && (!Array.isArray(checked.unresolved_reasons) || checked.unresolved_reasons.length === 0)) errors.push(`integrity_unresolved_row_lacks_reason:${checked?.key?.number ?? "unknown"}`);
  }
  if (integrity?.outcome === "passed") {
    if (integrity.verify_prs.exit_status !== 0) errors.push("passed_integrity_has_nonzero_verify_prs_exit");
    if (integrity.reasons.length !== 0) errors.push("passed_integrity_has_block_reasons");
    if (auditResult.resolved_count !== EXPECTED_KEYS.length) errors.push("passed_integrity_has_unresolved_audit_row");
    if (integrity.fresh_open_pr_inventory?.complete !== true) errors.push("passed_integrity_inventory_incomplete");
  } else if (integrity?.outcome === "blocked") {
    if (integrity.verify_prs.exit_status === 0) errors.push("blocked_integrity_has_zero_verify_prs_exit");
    if (integrity.reasons.length === 0) errors.push("blocked_integrity_lacks_specific_reason");
  } else errors.push("integrity_outcome_invalid");
  return { valid: errors.length === 0, errors: [...new Set(errors)].sort() };
}

function parseArgs(argv) {
  const [mode, ...tokens] = argv;
  const options = {};
  for (let i = 0; i < tokens.length; i += 1) {
    const key = tokens[i];
    if (!key.startsWith("--") || i + 1 >= tokens.length) throw new Error(`invalid_argument:${key}`);
    options[key.slice(2)] = tokens[++i];
  }
  return { mode, options };
}

function printResult(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function main() {
  const { mode, options } = parseArgs(process.argv.slice(2));
  const repo = resolve(options.repo ?? process.cwd());
  if (mode === "capture-live") {
    const audit = captureLive(repo, options["baseline-commit"], options["baseline-path"] ?? PINNED_BASELINE.state_path);
    const result = validateAudit(audit);
    if (!result.valid) throw new Error(`captured_audit_failed_validation:${result.errors.join(",")}`);
    atomicWrite(options.output, audit);
    printResult({ audit_id: audit.audit_id, rows: audit.rows.length, resolved: result.resolved_count, unresolved: result.unresolved_count, output: options.output });
    return 0;
  }
  if (mode === "validate") {
    const audit = JSON.parse(readFileSync(options.audit, "utf8"));
    const result = validateAudit(audit);
    if (!result.valid) {
      printResult(result);
      return 1;
    }
    printResult(result);
    return 0;
  }
  if (mode === "verify-live") {
    const commandText = options["verify-command"] ?? "bash scripts/maintainers/prune-stale-branches.sh verify-prs";
    let integrity;
    try {
      integrity = verifyLive(repo, options.audit, options["baseline-file"], options["baseline-commit"], options["baseline-path"] ?? PINNED_BASELINE.state_path, commandText);
    } catch (error) {
      integrity = {
        schema_version: 1,
        integrity_id: randomUUID(),
        created_at: now(),
        repository: "szTheory/sigra",
        outcome: "blocked",
        audit: { audit_id: null, source_commit: null, source_blob: null, path: options.audit ?? null },
        baseline: { commit: options["baseline-commit"] ?? null, state_blob: null, evidence_blob: null },
        verify_prs: { command: commandText, exit_status: null },
        fresh_open_pr_inventory: { complete: false, pages: [], items: [] },
        checked_historical_rows: [],
        checked_non_exception_base_refs: [],
        reasons: [`verification_capture_failed:${String(error.message ?? error)}`],
      };
    }
    atomicWrite(options["integrity-output"], integrity);
    printResult({ integrity_id: integrity.integrity_id, outcome: integrity.outcome, reasons: integrity.reasons });
    return integrity.outcome === "passed" ? 0 : 1;
  }
  if (mode === "record-exit") {
    const path = options["integrity-output"];
    const integrity = JSON.parse(readFileSync(path, "utf8"));
    const exitStatus = Number(options["exit-status"]);
    if (!Number.isInteger(exitStatus)) throw new Error("verify_prs_exit_status_invalid");
    integrity.verify_prs.command = options.command;
    integrity.verify_prs.exit_status = exitStatus;
    if (exitStatus !== 0 && integrity.outcome !== "blocked") {
      integrity.outcome = "blocked";
      integrity.reasons.push(`verify_prs_command_exited_${exitStatus}`);
      integrity.reasons = [...new Set(integrity.reasons)].sort();
    }
    atomicWrite(path, integrity);
    printResult({ integrity_id: integrity.integrity_id, outcome: integrity.outcome, exit_status: exitStatus });
    return 0;
  }
  if (mode === "validate-final") {
    const audit = JSON.parse(readFileSync(options.audit, "utf8"));
    const integrity = JSON.parse(readFileSync(options.integrity, "utf8"));
    const result = validateFinal(audit, integrity);
    let auditIdentity = null;
    let integrityIdentity = null;
    try {
      auditIdentity = localBlobIdentity(repo, options.audit);
      integrityIdentity = localBlobIdentity(repo, options.integrity);
      if (integrity.audit?.source_commit !== auditIdentity.commit || integrity.audit?.source_blob !== auditIdentity.blob) result.errors.push("integrity_audit_commit_or_blob_does_not_match_committed_audit");
    } catch (error) {
      result.errors.push(`audit_or_integrity_artifact_not_committed:${String(error.message ?? error)}`);
    }
    if (result.valid && options.summary && options.verification) {
      const summary = readFileSync(options.summary, "utf8");
      const verification = readFileSync(options.verification, "utf8");
      for (const [label, body] of [["summary", summary], ["verification", verification]]) {
        if (!body.includes(audit.audit_id)) result.errors.push(`${label}_missing_pr_identity_audit_id`);
        if (!body.includes(integrity.integrity_id)) result.errors.push(`${label}_missing_pr_integrity_id`);
      }
      result.valid = result.errors.length === 0;
    }
    result.audit_identity = auditIdentity;
    result.integrity_identity = integrityIdentity;
    result.valid = result.errors.length === 0;
    printResult(result);
    return result.valid ? 0 : 1;
  }
  throw new Error(`unknown_mode:${mode}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    process.exitCode = main();
  } catch (error) {
    process.stderr.write(`prune-stale-branches-pr-audit: ${error.message}\n`);
    process.exitCode = 1;
  }
}
