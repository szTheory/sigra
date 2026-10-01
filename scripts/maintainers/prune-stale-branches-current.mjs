#!/usr/bin/env node
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFileSync, realpathSync, renameSync, writeFileSync } from "node:fs";
import path, { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPOSITORY = "szTheory/sigra";
const GIT_BIN = "/usr/bin/git";
const OID = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;

function fail(reason) {
  throw new Error(reason);
}

function command(bin, args, cwd, label) {
  const result = spawnSync(bin, args, { cwd, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  if (result.status !== 0) fail(`${label}:${String(result.stderr || result.error?.message || "command_failed").trim()}`);
  return result.stdout;
}

function git(repo, args, label = "git_failed") {
  return command(GIT_BIN, ["-C", repo, ...args], undefined, label);
}

function validBranch(name, label) {
  if (typeof name !== "string" || !name || name.startsWith("-") || name.includes("\n")) fail(`${label}_invalid`);
  const result = spawnSync(GIT_BIN, ["check-ref-format", "--branch", name], { encoding: "utf8" });
  if (result.status !== 0) fail(`${label}_invalid`);
  return name;
}

function normalizePrApi(row) {
  return {
    number: Number(row?.number),
    state: typeof row?.state === "string" ? row.state.toUpperCase() : "",
    headRefName: row?.head?.ref ?? "",
    baseRefName: row?.base?.ref ?? "",
    headRefOid: row?.head?.sha ?? "",
    baseRefOid: row?.base?.sha ?? "",
    headRepository: row?.head?.repo?.full_name ?? null,
    baseRepository: row?.base?.repo?.full_name ?? null,
  };
}

function normalizePrCli(row) {
  return {
    number: Number(row?.number),
    state: typeof row?.state === "string" ? row.state.toUpperCase() : "",
    headRefName: row?.headRefName ?? "",
    baseRefName: row?.baseRefName ?? "",
    headRefOid: row?.headRefOid ?? "",
    baseRefOid: row?.baseRefOid ?? "",
    headRepository: null,
    baseRepository: null,
  };
}

function validatePull(pull, source) {
  if (!Number.isSafeInteger(pull.number) || pull.number < 1) fail(`${source}_pr_number_invalid`);
  if (pull.state !== "OPEN") fail(`${source}_pr_not_open:${pull.number}`);
  validBranch(pull.headRefName, `${source}_pr_head_name:${pull.number}`);
  validBranch(pull.baseRefName, `${source}_pr_base_name:${pull.number}`);
  if (!OID.test(pull.headRefOid)) fail(`${source}_pr_head_oid_invalid:${pull.number}`);
  if (!OID.test(pull.baseRefOid)) fail(`${source}_pr_base_oid_invalid:${pull.number}`);
}

function assertUniquePulls(pulls, source) {
  const seen = new Set();
  for (const row of pulls) {
    validatePull(row, source);
    if (seen.has(row.number)) fail(`${source}_duplicate_pr_number:${row.number}`);
    seen.add(row.number);
  }
}

function cliInventoryFromFixture(fixture) {
  if (!Array.isArray(fixture?.cliPulls)) fail("fixture_cli_pr_list_missing");
  return fixture.cliPulls.map(normalizePrCli);
}

function paginatedInventoryFromFixture(fixture) {
  if (!Array.isArray(fixture?.pages) || fixture.pages.length === 0) fail("fixture_pr_pages_missing");
  const pages = [];
  const pulls = [];
  for (const [index, page] of fixture.pages.entries()) {
    if (!Array.isArray(page) || page.length > 100) fail(`pr_page_invalid:${index + 1}`);
    pages.push({ page: index + 1, item_count: page.length, has_next: page.length === 100, source: "fixture" });
    pulls.push(...page.map(normalizePrApi));
    if (page.length < 100 && index !== fixture.pages.length - 1) fail(`pr_page_after_final:${index + 1}`);
  }
  const final = fixture.pages.at(-1);
  if (final.length === 100) fail("pr_pagination_final_page_missing");
  return { pulls, pages };
}

function gh(args, label) {
  return command("gh", args, undefined, label);
}

function loadPrInventory(fixturePath) {
  let cliPulls;
  let inventory;
  if (fixturePath) {
    let fixture;
    try { fixture = JSON.parse(readFileSync(fixturePath, "utf8")); } catch (error) { fail(`fixture_json_invalid:${error.message}`); }
    cliPulls = cliInventoryFromFixture(fixture);
    inventory = paginatedInventoryFromFixture(fixture);
  } else {
    const rate = JSON.parse(gh(["api", "rate_limit"], "github_rate_limit_unavailable"));
    const remaining = Number(rate?.resources?.core?.remaining);
    if (!Number.isSafeInteger(remaining) || remaining <= 250) fail("github_core_rate_budget_at_or_below_250");
    cliPulls = JSON.parse(gh(["pr", "list", "--repo", REPOSITORY, "--state", "open", "--limit", "1000", "--json", "number,state,headRefName,baseRefName,headRefOid,baseRefOid"], "gh_pr_list_failed"))
      .map(normalizePrCli);
    const pages = [];
    const pulls = [];
    let complete = false;
    for (let page = 1; page <= 100; page += 1) {
      const rows = JSON.parse(gh(["api", `/repos/${REPOSITORY}/pulls?state=open&per_page=100&page=${page}`], `github_pr_page_failed:${page}`));
      if (!Array.isArray(rows) || rows.length > 100) fail(`github_pr_page_invalid:${page}`);
      pages.push({ page, item_count: rows.length, has_next: rows.length === 100, source: "github-api" });
      pulls.push(...rows.map(normalizePrApi));
      if (rows.length < 100) { complete = true; break; }
    }
    if (!complete) fail("github_pr_pagination_incomplete");
    inventory = { pulls, pages };
  }
  if (!Array.isArray(cliPulls)) fail("cli_pr_list_invalid");
  assertUniquePulls(cliPulls, "cli");
  assertUniquePulls(inventory.pulls, "api");
  const cliNames = cliPulls.map((pull) => `${pull.number}\0${pull.headRefName}\0${pull.baseRefName}`).sort();
  const apiNames = inventory.pulls.map((pull) => `${pull.number}\0${pull.headRefName}\0${pull.baseRefName}`).sort();
  if (JSON.stringify(cliNames) !== JSON.stringify(apiNames)) fail("pr_cli_api_number_head_base_set_mismatch");
  return { pulls: inventory.pulls, pages: inventory.pages, cli_count: cliPulls.length, complete: true };
}

function parseLocalRefs(repo) {
  const format = "%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)%09%(symref)";
  const output = git(repo, ["for-each-ref", `--format=${format}`], "local_ref_enumeration_failed");
  const rows = output.trimEnd().split(/\r?\n/).filter(Boolean).map((line) => {
    const [ref, oid, type, peeledOid = "", peeledType = "", symref = ""] = line.split("\t");
    if (!ref?.startsWith("refs/") || !OID.test(oid) || !type) fail("local_ref_row_malformed");
    if ((peeledOid === "") !== (peeledType === "")) fail(`local_peeled_identity_incomplete:${ref}`);
    if (peeledOid && !OID.test(peeledOid)) fail(`local_peeled_oid_invalid:${ref}`);
    return { ref, oid, type, peeled_oid: peeledOid || null, peeled_type: peeledType || null, symref: symref || null };
  });
  if (!rows.length) fail("local_ref_set_empty");
  assertUniqueRefs(rows, "local");
  return rows.sort(compareRef);
}

function objectType(repo, oid, ref) {
  const result = spawnSync(GIT_BIN, ["-C", repo, "cat-file", "-t", oid], { encoding: "utf8" });
  if (result.status !== 0) fail(`origin_object_unreadable:${ref}:${oid}`);
  return result.stdout.trim();
}

function parseOriginRefs(repo) {
  const output = git(repo, ["ls-remote", "--symref", "origin"], "origin_ref_query_failed");
  const rows = output.trimEnd().split(/\r?\n/).filter(Boolean);
  if (!rows.length) fail("origin_ref_set_empty");
  let defaultRef = null;
  let headOid = null;
  const direct = new Map();
  const peeled = new Map();
  for (const line of rows) {
    const [left, name] = line.split("\t");
    if (!name || line.split("\t").length !== 2) fail("origin_ref_row_malformed");
    if (left.startsWith("ref: ") && name === "HEAD") {
      if (defaultRef) fail("origin_default_symref_duplicate");
      defaultRef = left.slice(5);
      if (!defaultRef.startsWith("refs/heads/")) fail("origin_default_symref_invalid");
      continue;
    }
    if (!OID.test(left)) fail(`origin_ref_oid_invalid:${name}`);
    if (name === "HEAD") { if (headOid) fail("origin_head_oid_duplicate"); headOid = left; continue; }
    const peel = name.endsWith("^{}");
    const ref = peel ? name.slice(0, -3) : name;
    if (!ref.startsWith("refs/") || (peel ? peeled : direct).has(ref)) fail(`origin_ref_duplicate_or_invalid:${ref}`);
    (peel ? peeled : direct).set(ref, left);
  }
  if (!defaultRef || !headOid || !direct.size) fail("origin_default_identity_incomplete_or_empty");
  const result = [];
  for (const [ref, oid] of direct) {
    // GitHub branch refs point to commits, but the checkout may not have
    // fetched every live origin branch tip. The OID comes directly from
    // ls-remote; requiring cat-file here would make a complete remote
    // inventory depend on the local fetch configuration.
    const type = ref.startsWith("refs/heads/") ? "commit" : objectType(repo, oid, ref);
    const peeledOid = peeled.get(ref) ?? null;
    if ((type === "tag") !== Boolean(peeledOid)) fail(`origin_peeled_identity_mismatch:${ref}`);
    const peeledType = peeledOid ? objectType(repo, peeledOid, ref) : null;
    result.push({ ref, oid, type, peeled_oid: peeledOid, peeled_type: peeledType, symref: null });
  }
  const defaultIdentity = result.find((row) => row.ref === defaultRef);
  if (!defaultIdentity || defaultIdentity.oid !== headOid) fail("origin_default_head_oid_mismatch");
  result.push({ ref: "refs/remotes/origin/HEAD", oid: headOid, type: defaultIdentity.type, peeled_oid: null, peeled_type: null, symref: defaultRef });
  assertUniqueRefs(result, "origin");
  return result.sort(compareRef);
}

function compareRef(a, b) { return a.ref.localeCompare(b.ref); }
function assertUniqueRefs(rows, side) {
  const refs = new Set();
  for (const row of rows) {
    if (refs.has(row.ref)) fail(`${side}_duplicate_ref:${row.ref}`);
    refs.add(row.ref);
  }
}

function collect(repo, fixturePath) {
  const root = git(repo, ["rev-parse", "--show-toplevel"], "repository_invalid").trim();
  const headRef = git(root, ["symbolic-ref", "-q", "HEAD"], "current_head_not_symbolic").trim();
  const headOid = git(root, ["rev-parse", "--verify", "HEAD"], "current_head_oid_missing").trim();
  if (!headRef.startsWith("refs/heads/") || !OID.test(headOid)) fail("current_head_identity_invalid");
  const origin = parseOriginRefs(root);
  const resolvedFixture = fixturePath ? resolve(root, fixturePath) : "";
  const prInventory = loadPrInventory(resolvedFixture);
  return {
    repository: REPOSITORY,
    checkout_root: root,
    captured_at: new Date().toISOString(),
    capture_head_ref: headRef,
    capture_head_oid: headOid,
    local_refs: parseLocalRefs(root),
    origin_refs: origin,
    open_prs: prInventory.pulls,
    pr_pages: prInventory.pages,
    cli_open_pr_count: prInventory.cli_count,
  };
}

function canonical(value) { return JSON.stringify(value); }

function readPinnedFile(repo, commit, path, label = "input") {
  if (!OID.test(commit ?? "")) fail(`${label}_commit_invalid`);
  if (typeof path !== "string" || !path || path.startsWith("/") || path.includes("..") || path.includes("\n") || path.includes(":")) fail(`${label}_path_invalid`);
  command(GIT_BIN, ["-C", repo, "cat-file", "-e", `${commit}^{commit}`], undefined, `${label}_commit_unreadable`);
  const blob = command(GIT_BIN, ["-C", repo, "rev-parse", `${commit}:${path}`], undefined, `${label}_path_missing`).trim();
  const result = spawnSync(GIT_BIN, ["-C", repo, "show", `${commit}:${path}`], { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (result.status !== 0) fail(`${label}_bytes_unreadable`);
  const raw = result.stdout;
  const hash = spawnSync(GIT_BIN, ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw, encoding: "utf8" });
  if (hash.status !== 0 || hash.stdout.trim() !== blob) fail(`${label}_git_blob_mismatch`);
  return { raw, blob, sha256: createHash("sha256").update(raw).digest("hex") };
}

function safeEvidencePath(value, label) {
  if (typeof value !== "string" || !value || value.startsWith("/") || value.includes("..") || value.includes("\n") || value.includes(":")) {
    fail(`${label}_path_invalid:${value ?? ""}`);
  }
  return value;
}

function changedPaths(repo, parent, commit, label) {
  const output = git(repo, ["diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", "-z", parent, commit], `${label}_diff_failed`);
  return output.split("\0").filter(Boolean).sort();
}

function commitParents(repo, commit, label) {
  const row = git(repo, ["rev-list", "--parents", "-n", "1", commit], `${label}_commit_unreadable`).trim().split(/\s+/);
  if (row[0] !== commit) fail(`${label}_commit_identity_invalid`);
  return row.slice(1);
}

function commitFilePin(repo, commit, filePath, label) {
  const relativePath = safeEvidencePath(filePath, label);
  const blob = git(repo, ["rev-parse", `${commit}:${relativePath}`], `${label}_blob_missing`).trim();
  const result = spawnSync(GIT_BIN, ["-C", repo, "show", `${commit}:${relativePath}`], { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (result.status !== 0) fail(`${label}_bytes_missing`);
  return { path: relativePath, blob, sha256: createHash("sha256").update(result.stdout).digest("hex"), raw: result.stdout };
}

function exactPathSet(actual, expected, label) {
  const left = [...actual].sort();
  const right = [...expected].sort();
  if (new Set(right).size !== right.length || canonical(left) !== canonical(right)) fail(`${label}_path_set_mismatch`);
}

function safetyTrackingRef(row) {
  return row?.side === "safety-publish" && row.ref.startsWith("refs/heads/")
    ? `refs/remotes/origin/${row.ref.slice("refs/heads/".length)}` : null;
}

function verifyLocalEvidenceRef(repo, contract, activeRef, allowedHeadOid, allowedMissingRefs = [], allowlistRows = [], appliedRefs = []) {
  if (!Array.isArray(contract.local_refs)) fail("evidence_transition_local_snapshot_missing");
  const expected = new Map(contract.local_refs.map((row) => [row.ref, row]));
  const actual = new Map(parseLocalRefs(repo).map((row) => [row.ref, row]));
  const missingRefs = [...expected.keys()].filter((ref) => !actual.has(ref)).sort();
  if (canonical(missingRefs) !== canonical([...allowedMissingRefs].sort())) fail("evidence_transition_local_ref_set_changed");
  for (const [ref, row] of expected) {
    const current = actual.get(ref);
    if (!current) continue;
    if (canonical(row) === canonical(current)) continue;
    if (ref === activeRef && current.oid === allowedHeadOid && current.type === "commit"
      && row.type === "commit" && current.peeled_oid === row.peeled_oid
      && current.peeled_type === row.peeled_type && current.symref === row.symref) continue;
    fail(`evidence_transition_unrelated_local_ref_changed:${ref}`);
  }
  for (const ref of actual.keys()) {
    if (expected.has(ref)) continue;
    const publishRow = allowlistRows.find((row) => appliedRefs.includes(row.ref) && safetyTrackingRef(row) === ref);
    const localSafety = publishRow && expected.get(publishRow.ref);
    const current = actual.get(ref);
    if (!publishRow || !localSafety || current.oid !== publishRow.oid || current.type !== publishRow.type
      || current.peeled_oid !== localSafety.peeled_oid || current.peeled_type !== localSafety.peeled_type || current.symref !== null) {
      fail(`evidence_transition_local_ref_unexpected:${ref}`);
    }
  }
}

function normalizeAppliedRefs(allowlistRows, appliedRefs) {
  if (!Array.isArray(allowlistRows) || !Array.isArray(appliedRefs)) fail("evidence_transition_operation_inputs_missing");
  const applied = appliedRefs.map((ref) => safeEvidencePath(ref, "evidence_transition_applied_ref")).sort();
  if (new Set(applied).size !== applied.length) fail("evidence_transition_applied_ref_duplicate");
  const rows = new Map(allowlistRows.filter((row) => ["local", "tracking", "remote", "safety-publish"].includes(row.side)).map((row) => [row.ref, row]));
  if (rows.size !== allowlistRows.filter((row) => ["local", "tracking", "remote", "safety-publish"].includes(row.side)).length) fail("evidence_transition_allowlist_duplicate_ref");
  for (const ref of applied) {
    const row = rows.get(ref);
    if (!row || !OID.test(row.oid ?? "") || !["local", "tracking", "remote", "safety-publish"].includes(row.side)) fail(`evidence_transition_applied_ref_not_allowlisted:${ref}`);
  }
  return { applied, rows };
}

function resultAppliedRefs(result, allowlistByRef) {
  const mutations = result?.mutations;
  if (!mutations || typeof mutations !== "object" || Array.isArray(mutations)) fail("evidence_transition_result_mutations_missing");
  const refs = [];
  const expectedSide = {
    local_ref_deletions: "local",
    tracking_ref_deletions: "tracking",
    remote_ref_deletions: "remote",
  };
  for (const key of Object.keys(expectedSide)) {
    if (!Array.isArray(mutations[key])) fail(`evidence_transition_result_mutations_invalid:${key}`);
    for (const item of mutations[key]) {
      if (typeof item?.ref !== "string") fail(`evidence_transition_result_mutation_ref_missing:${key}`);
      const ref = safeEvidencePath(item.ref, "evidence_transition_result_ref");
      const admitted = allowlistByRef.get(ref);
      if (!admitted || admitted.side !== expectedSide[key]) fail(`evidence_transition_result_mutation_side_mismatch:${key}:${ref}`);
      const expectedOid = item.expected_oid ?? item.oid;
      if (expectedOid !== undefined && expectedOid !== admitted.oid) fail(`evidence_transition_result_mutation_oid_mismatch:${ref}`);
      refs.push(ref);
    }
  }
  refs.sort();
  if (new Set(refs).size !== refs.length) fail("evidence_transition_result_ref_duplicate");
  return refs;
}

export function inspectEvidenceTransition(repo, contractCommit, contractPath, contract, stage = "before", options = {}) {
  const transition = contract?.evidence_transition;
  if (!transition || !new Set(["before", "boundary", "operation", "after"]).has(stage)) fail("evidence_transition_contract_missing_or_invalid");
  const activeRef = safeEvidencePath(transition.active_ref, "evidence_transition_active_ref");
  const capturedOid = transition.captured_head_oid;
  if (!OID.test(capturedOid ?? "") || activeRef !== contract.capture_head_ref || capturedOid !== contract.capture_head_oid) {
    fail("evidence_transition_capture_identity_mismatch");
  }
  const relativeContract = safeEvidencePath(contractPath, "evidence_transition_contract");
  if (relativeContract !== transition.contract_path) fail("evidence_transition_contract_path_mismatch");
  const contractPaths = transition.contract_paths;
  if (!Array.isArray(contractPaths) || !contractPaths.includes(relativeContract) || !contractPaths.includes(`${relativeContract}.sha256`)) {
    fail("evidence_transition_contract_path_set_invalid");
  }
  const normalizedContractPaths = contractPaths.map((file) => safeEvidencePath(file, "evidence_transition_contract"));
  const contractParent = commitParents(repo, contractCommit, "evidence_transition_contract");
  if (contractParent.length !== 1 || contractParent[0] !== capturedOid) fail("evidence_transition_contract_parent_mismatch");
  exactPathSet(changedPaths(repo, capturedOid, contractCommit, "evidence_transition_contract"), normalizedContractPaths, "evidence_transition_contract");
  if (git(repo, ["log", "-1", "--format=%H", "--", relativeContract]).trim() !== contractCommit) {
    fail("evidence_transition_contract_commit_not_latest_for_path");
  }
  const contractPin = commitFilePin(repo, contractCommit, relativeContract, "evidence_transition_contract");
  const sidecar = commitFilePin(repo, contractCommit, `${relativeContract}.sha256`, "evidence_transition_contract_sha256");
  if (sidecar.raw.toString("utf8").trim() !== contractPin.sha256) fail("evidence_transition_contract_sha256_mismatch");

  const artifactPaths = normalizedContractPaths.filter((file) => file !== relativeContract && file !== `${relativeContract}.sha256`).sort();
  const declaredArtifacts = transition.precommit_artifacts;
  if (!declaredArtifacts || typeof declaredArtifacts !== "object" || Array.isArray(declaredArtifacts)) fail("evidence_transition_precommit_artifacts_missing");
  exactPathSet(Object.keys(declaredArtifacts), artifactPaths, "evidence_transition_precommit_artifacts");
  const contractPins = [contractPin, sidecar];
  for (const file of artifactPaths) {
    const actual = commitFilePin(repo, contractCommit, file, "evidence_transition_precommit_artifact");
    const expected = declaredArtifacts[file];
    if (!expected || expected.blob !== actual.blob || expected.sha256 !== actual.sha256) fail(`evidence_transition_precommit_artifact_mismatch:${file}`);
    contractPins.push(actual);
  }

  const actualHeadRef = git(repo, ["symbolic-ref", "-q", "HEAD"], "evidence_transition_head_ref_unavailable").trim();
  const actualHeadOid = git(repo, ["rev-parse", "--verify", "HEAD"], "evidence_transition_head_oid_unavailable").trim();
  if (actualHeadRef !== activeRef) fail("evidence_transition_active_ref_changed");
  let applied = [];
  let appliedRows = new Map();
  let parsedResult = null;
  if (["boundary", "operation"].includes(stage) || stage === "after" && options.appliedRefs !== undefined) {
    ({ applied, rows: appliedRows } = normalizeAppliedRefs(options.allowlistRows, options.appliedRefs));
  }
  let acceptedHeadOid = contractCommit;
  let finalCommit = null;
  let finalPaths = [];
  let finalPins = [];
  if (actualHeadOid !== contractCommit) {
    if (stage !== "after") fail("evidence_transition_advanced_before_final_child");
    const finalParent = commitParents(repo, actualHeadOid, "evidence_transition_final");
    if (finalParent.length !== 1 || finalParent[0] !== contractCommit) fail("evidence_transition_final_parent_mismatch");
    const pathSets = transition.final_child_path_sets;
    const resultPath = safeEvidencePath(transition.result_path, "evidence_transition_result");
    if (!pathSets || !Array.isArray(pathSets.blocked) || !Array.isArray(pathSets.passed)
      || !pathSets.blocked.includes(resultPath) || !pathSets.passed.includes(resultPath)) fail("evidence_transition_final_path_sets_invalid");
    const result = commitFilePin(repo, actualHeadOid, resultPath, "evidence_transition_result");
    try { parsedResult = JSON.parse(result.raw.toString("utf8")); } catch { fail("evidence_transition_result_json_invalid"); }
    const outcome = parsedResult?.outcome;
    if (!new Set(["blocked", "passed"]).has(outcome)) fail("evidence_transition_result_outcome_invalid");
    const expectedFinalPaths = pathSets[outcome].map((file) => safeEvidencePath(file, "evidence_transition_final")).sort();
    exactPathSet(changedPaths(repo, contractCommit, actualHeadOid, "evidence_transition_final"), expectedFinalPaths, "evidence_transition_final");
    const directChildren = git(repo, ["rev-list", "--all", "--parents"], "evidence_transition_child_inventory_failed")
      .trim().split(/\r?\n/).filter(Boolean).flatMap((line) => {
        const [oid, ...parents] = line.split(/\s+/);
        return parents.includes(contractCommit) ? [oid] : [];
      });
    if (directChildren.length !== 1 || directChildren[0] !== actualHeadOid) fail("evidence_transition_multiple_or_foreign_final_children");
    if (git(repo, ["log", "-1", "--format=%H", "--", resultPath]).trim() !== actualHeadOid) fail("evidence_transition_final_commit_not_latest_for_result");
    finalCommit = actualHeadOid;
    finalPaths = expectedFinalPaths;
    finalPins = finalPaths.map((file) => commitFilePin(repo, finalCommit, file, "evidence_transition_final_artifact"));
    acceptedHeadOid = finalCommit;
  } else if (stage === "after") {
    fail("evidence_transition_final_child_missing");
  } else if (actualHeadOid !== contractCommit) {
    fail("evidence_transition_advanced_before_final_child");
  }
  const localMissing = [];
  if (["boundary", "operation", "after"].includes(stage)) {
    const expectedLocal = new Map(contract.local_refs.map((row) => [row.ref, row]));
    const currentLocal = new Map(parseLocalRefs(repo).map((row) => [row.ref, row]));
    for (const ref of applied) {
      const row = appliedRows.get(ref);
      const expected = expectedLocal.get(ref);
      if (["local", "tracking"].includes(row.side)) {
        if (!expected || expected.oid !== row.oid || expected.type !== row.type) fail(`evidence_transition_allowlist_local_identity_mismatch:${ref}`);
        if (currentLocal.has(ref)) fail(`evidence_transition_applied_ref_still_present:${ref}`);
        localMissing.push(ref);
      } else if (row.side === "remote" && currentLocal.has(ref)) {
        fail(`evidence_transition_remote_ref_local_presence_changed:${ref}`);
      }
    }
    if (stage === "after") {
      const declared = resultAppliedRefs(parsedResult, appliedRows);
      if (canonical(declared) !== canonical(applied)) fail("evidence_transition_result_applied_refs_mismatch");
    }
  }
  verifyLocalEvidenceRef(repo, contract, activeRef, acceptedHeadOid, localMissing, options.allowlistRows ?? [], applied);
  return {
    contract_commit: contractCommit,
    contract_parent: contractParent[0],
    contract_paths: normalizedContractPaths.sort(),
    contract_file_pins: contractPins.map(({ path: file, blob, sha256 }) => ({ path: file, blob, sha256 })),
    final_evidence_commit: finalCommit,
    final_evidence_paths: finalPaths,
    final_file_pins: finalPins.map(({ path: file, blob, sha256 }) => ({ path: file, blob, sha256 })),
    active_ref: activeRef,
    applied_refs: applied,
    captured_head_oid: capturedOid,
    verified_head_oid: acceptedHeadOid,
  };
}

function compareCurrent(contract, actual, contractCommit, options) {
  if (contract.repository !== actual.repository) fail("current_repository_identity_changed");
  const expectedPrs = contract.open_prs;
  const actualPrs = actual.open_prs;
  if (!Array.isArray(expectedPrs) || !Array.isArray(actualPrs)) fail("current_pr_inventory_missing");
  const expectedByNumber = new Map(expectedPrs.map((pull) => [pull.number, pull]));
  const actualByNumber = new Map(actualPrs.map((pull) => [pull.number, pull]));
  if (expectedByNumber.size !== actualByNumber.size) fail("current_open_pr_set_changed");
  for (const [number, expected] of expectedByNumber) {
    const current = actualByNumber.get(number);
    if (!current) fail(`current_pr_missing_or_closed:${number}`);
    if (current.headRefName !== expected.headRefName) fail(`current_pr_head_name_changed:${number}`);
    if (current.baseRefName !== expected.baseRefName) fail(`current_pr_base_name_changed:${number}`);
    if (current.headRefOid !== expected.headRefOid) fail(`current_pr_head_oid_changed:${number}`);
    // GitHub's base SHA is an observation only; the exact live origin identity below is authoritative.
  }
  for (const pull of actualPrs) {
    validBranch(pull.headRefName, `current_pr_head_name:${pull.number}`);
    validBranch(pull.baseRefName, `current_pr_base_name:${pull.number}`);
  }
  if (!Array.isArray(contract.local_refs) || !Array.isArray(contract.origin_refs)) fail("current_ref_snapshot_missing");
  const expectedLocal = new Map(contract.local_refs.map((row) => [row.ref, row]));
  const actualLocal = new Map(actual.local_refs.map((row) => [row.ref, row]));
  const expectedOrigin = new Map(contract.origin_refs.map((row) => [row.ref, row]));
  const actualOrigin = new Map(actual.origin_refs.map((row) => [row.ref, row]));
  const appliedRefs = new Set(options.appliedRefs ?? []);
  for (const row of options.allowlistRows ?? []) {
    const ref = row.ref;
    if (row.side === "local" || row.side === "tracking") {
      const expected = expectedLocal.get(ref);
      if (!expected || expected.oid !== row.oid || expected.type !== row.type) fail(`current_allowlist_local_identity_mismatch:${ref}`);
      if (!actualLocal.has(ref)) expectedLocal.delete(ref);
    } else if (row.side === "remote") {
      const expected = expectedOrigin.get(ref);
      if (!expected || expected.oid !== row.oid || expected.type !== row.type) fail(`current_allowlist_origin_identity_mismatch:${ref}`);
      if (!actualOrigin.has(ref) && appliedRefs.has(ref)) expectedOrigin.delete(ref);
    } else if (row.side === "safety-publish") {
      const local = expectedLocal.get(ref);
      const current = actualOrigin.get(ref);
      if (!local || local.oid !== row.oid || local.type !== row.type) fail(`current_safety_publish_source_mismatch:${ref}`);
      if (current && (current.oid !== row.oid || current.type !== row.type || current.peeled_oid !== local.peeled_oid || current.peeled_type !== local.peeled_type)) fail(`current_safety_publish_identity_conflict:${ref}`);
    }
  }
  for (const [ref, expected] of expectedOrigin) {
    const current = actualOrigin.get(ref);
    if (!current && appliedRefs.has(ref) && (options.allowlistRows ?? []).some((row) => row.side === "remote" && row.ref === ref && row.oid === expected.oid && row.type === expected.type)) {
      expectedOrigin.delete(ref);
      continue;
    }
    if (!current && ["operation", "after"].includes(options.stage)
      && options.operationSide === "remote" && ref === options.operationRef) continue;
    if (!current || canonical(expected) !== canonical(current)) fail(`current_origin_ref_identity_changed:${ref}`);
  }
  for (const [ref, current] of actualOrigin) {
    if (expectedOrigin.has(ref)) continue;
    const safetyRow = (options.allowlistRows ?? []).find((row) => row.side === "safety-publish" && row.ref === ref);
    const localSafety = expectedLocal.get(ref);
    if (safetyRow && localSafety && current.oid === safetyRow.oid && current.type === safetyRow.type && current.peeled_oid === localSafety.peeled_oid && current.peeled_type === localSafety.peeled_type) continue;
    fail(`current_origin_ref_unexpected:${ref}`);
  }
  const safetyTrackingRows = (options.allowlistRows ?? []).filter((row) => appliedRefs.has(row.ref) && row.side === "safety-publish");
  const allowedSafetyTracking = new Set(safetyTrackingRows.map(safetyTrackingRef).filter(Boolean));
  const presentSafetyTrackingCount = [...allowedSafetyTracking].filter((ref) => actualLocal.has(ref)).length;
  if (actualLocal.size !== expectedLocal.size + presentSafetyTrackingCount) fail("current_local_ref_set_changed");
  for (const [ref, expected] of expectedLocal) {
    const current = actualLocal.get(ref);
    if (!current) fail(`current_local_ref_missing:${ref}`);
    if (canonical(expected) === canonical(current)) continue;
    const allowedActiveOid = options.allowedActiveOid ?? contractCommit;
    if (ref === contract.capture_head_ref && current.oid === allowedActiveOid && current.type === "commit" && expected.type === "commit" && current.peeled_oid === expected.peeled_oid && current.peeled_type === expected.peeled_type && current.symref === expected.symref) continue;
    fail(`current_local_ref_identity_changed:${ref}`);
  }
  for (const ref of actualLocal.keys()) {
    if (expectedLocal.has(ref)) continue;
    const row = safetyTrackingRows.find((candidate) => safetyTrackingRef(candidate) === ref);
    const source = row && expectedLocal.get(row.ref);
    const current = actualLocal.get(ref);
    if (!row || !source || current.oid !== row.oid || current.type !== row.type
      || current.peeled_oid !== source.peeled_oid || current.peeled_type !== source.peeled_type || current.symref !== null) {
      fail(`current_local_ref_unexpected:${ref}`);
    }
  }
  for (const ref of actualOrigin.keys()) {
    if (expectedOrigin.has(ref)) continue;
    const safetyRow = (options.allowlistRows ?? []).find((row) => row.side === "safety-publish" && row.ref === ref);
    const localSafety = expectedLocal.get(ref);
    if (!safetyRow || !localSafety || actualOrigin.get(ref).oid !== safetyRow.oid || actualOrigin.get(ref).type !== safetyRow.type) fail(`current_origin_ref_unexpected:${ref}`);
  }
}

function parseAllowlist(raw) {
  const lines = raw.toString("utf8").replace(/\r/g, "").trimEnd().split("\n");
  if (lines.length < 2 || lines[0] !== "side\tref\toid\ttype\treason") fail("current_allowlist_header_or_rows_invalid");
  const rows = [];
  const seen = new Set();
  for (const line of lines.slice(1)) {
    const [side, ref, oid, type, reason, ...extra] = line.split("\t");
    if (extra.length || !["local", "remote", "tracking", "safety-publish"].includes(side) || !OID.test(oid ?? "") || !["commit", "tree", "blob", "tag"].includes(type) || !reason?.trim()) fail("current_allowlist_row_invalid");
    if (!ref?.startsWith("refs/") || seen.has(`${side}\0${ref}`)) fail(`current_allowlist_duplicate_or_invalid_ref:${ref}`);
    const check = spawnSync(GIT_BIN, ["check-ref-format", ref], { encoding: "utf8" });
    if (check.status !== 0) fail(`current_allowlist_ref_invalid:${ref}`);
    seen.add(`${side}\0${ref}`);
    rows.push({ side, ref, oid, type, reason });
  }
  if (!rows.length) fail("current_allowlist_empty");
  return rows;
}

function verifyAllowlist(repo, contract, allowlistCommit, allowlistPath, contractCommit) {
  if (!allowlistCommit || !allowlistPath) fail("current_allowlist_commit_path_required");
  const input = readPinnedFile(repo, allowlistCommit, allowlistPath, "current_allowlist");
  const pin = (contract.pinned_inputs ?? []).find((entry) => entry.commit === allowlistCommit && entry.path === allowlistPath);
  const selfPin = allowlistCommit === contractCommit ? contract.evidence_transition?.precommit_artifacts?.[allowlistPath] : null;
  const expected = pin ?? selfPin;
  if (!expected || expected.blob !== input.blob || expected.sha256 !== input.sha256) fail("current_allowlist_not_pinned_by_contract");
  const rows = parseAllowlist(input.raw);
  const local = new Map(contract.local_refs.map((row) => [row.ref, row]));
  const origin = new Map(contract.origin_refs.map((row) => [row.ref, row]));
  const protectedNames = new Set();
  for (const pull of contract.open_prs) {
    protectedNames.add(pull.headRefName);
    protectedNames.add(pull.baseRefName);
  }
  for (const row of rows) {
    if (row.side === "safety-publish") {
      if (!row.ref.startsWith("refs/heads/") && !row.ref.startsWith("refs/tags/")) fail(`current_safety_publish_ref_invalid:${row.ref}`);
      const localRow = local.get(row.ref);
      if (!localRow || localRow.oid !== row.oid || localRow.type !== row.type) fail(`current_safety_publish_source_mismatch:${row.ref}`);
      const published = origin.get(row.ref);
      if (published && (published.oid !== row.oid || published.type !== row.type || published.peeled_oid !== localRow.peeled_oid || published.peeled_type !== localRow.peeled_type)) fail(`current_safety_publish_target_conflict:${row.ref}`);
      continue;
    }
    if (row.side === "tracking" && !row.ref.startsWith("refs/remotes/origin/")) fail(`current_tracking_ref_invalid:${row.ref}`);
    if (row.side !== "tracking" && !row.ref.startsWith("refs/heads/")) fail(`current_branch_ref_invalid:${row.ref}`);
    const branch = row.side === "tracking" ? row.ref.slice("refs/remotes/origin/".length) : row.ref.slice("refs/heads/".length);
    if (protectedNames.has(branch)) fail(`current_allowlist_overlaps_pr_head_or_base:${row.ref}`);
    const defaultRef = contract.origin_refs.find((entry) => entry.ref === "refs/remotes/origin/HEAD")?.symref;
    const protectedRef = `refs/heads/${branch}`;
    if (protectedRef === defaultRef) fail(`current_allowlist_contains_origin_default:${row.ref}`);
    if (["refs/heads/ci/phase-235-16-source-complete", "refs/tags/archive/local-main-pre-235-recovery"].includes(protectedRef)
      || /^refs\/heads\/safety\/local-main-before-release-cleanup-/.test(protectedRef)) fail(`current_allowlist_contains_safety_ref:${row.ref}`);
    const source = row.side === "remote" ? origin.get(row.ref) : local.get(row.ref);
    if (!source || source.oid !== row.oid || source.type !== row.type) fail(`current_allowlist_ref_identity_mismatch:${row.ref}`);
  }
  return { rows, blob: input.blob, sha256: input.sha256 };
}

function committedBytes(repo, commit, path) {
  if (!OID.test(commit ?? "")) fail("current_contract_commit_invalid");
  if (typeof path !== "string" || !path || path.startsWith("/") || path.includes("..") || path.includes("\n") || path.includes(":")) fail("current_contract_path_invalid");
  command(GIT_BIN, ["-C", repo, "cat-file", "-e", `${commit}^{commit}`], undefined, "current_contract_commit_unreadable");
  const blob = command(GIT_BIN, ["-C", repo, "rev-parse", `${commit}:${path}`], undefined, "current_contract_path_missing").trim();
  if (!OID.test(blob)) fail("current_contract_blob_oid_invalid");
  const bytes = spawnSync(GIT_BIN, ["-C", repo, "show", `${commit}:${path}`], { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (bytes.status !== 0) fail("current_contract_committed_bytes_unreadable");
  const raw = bytes.stdout;
  const rehashedBlob = spawnSync(GIT_BIN, ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw, encoding: "utf8" });
  if (rehashedBlob.status !== 0 || rehashedBlob.stdout.trim() !== blob) fail("current_contract_git_blob_mismatch");
  const sha256 = createHash("sha256").update(raw).digest("hex");
  const sidecar = command(GIT_BIN, ["-C", repo, "show", `${commit}:${path}.sha256`], undefined, "current_contract_sha256_record_missing").trim();
  if (!/^[0-9a-f]{64}$/.test(sidecar)) fail("current_contract_sha256_record_invalid");
  if (sidecar !== sha256) fail("current_contract_sha256_mismatch");
  return { raw, blob, sha256 };
}

function capture(repo, output, fixturePath, pinSpecs, transitionOptions = {}) {
  if (!output) fail("current_contract_output_required");
  const payload = collect(repo, fixturePath);
  const pinnedInputs = pinSpecs.map((spec, index) => {
    const separator = spec.indexOf(":");
    if (separator < 0) fail(`pinned_input_spec_invalid:${index + 1}`);
    const commit = spec.slice(0, separator);
    const path = spec.slice(separator + 1);
    const input = readPinnedFile(payload.checkout_root, commit, path, `pinned_input_${index + 1}`);
    return { commit, path, blob: input.blob, sha256: input.sha256 };
  });
  const requestedDestination = resolve(output);
  const destination = path.join(realpathSync(path.dirname(requestedDestination)), path.basename(requestedDestination));
  if (!destination.startsWith(`${payload.checkout_root}${path.sep}`)) fail(`evidence_transition_contract_outside_checkout:${payload.checkout_root}:${destination}`);
  const relativeContractPath = path.relative(payload.checkout_root, destination).split(path.sep).join("/");
  const contractPath = safeEvidencePath(relativeContractPath, "evidence_transition_contract");
  let evidenceTransition;
  const evidencePaths = transitionOptions.evidencePaths ?? [];
  const blockedPaths = transitionOptions.blockedPaths ?? [];
  const passedPaths = transitionOptions.passedPaths ?? [];
  if (evidencePaths.length || blockedPaths.length || passedPaths.length || transitionOptions.resultPath) {
    if (!evidencePaths.length || !blockedPaths.length || !passedPaths.length || !transitionOptions.resultPath) fail("evidence_transition_capture_paths_incomplete");
    const normalizedEvidencePaths = evidencePaths.map((file) => safeEvidencePath(file, "evidence_transition_precommit"));
    const normalizedBlockedPaths = blockedPaths.map((file) => safeEvidencePath(file, "evidence_transition_blocked"));
    const normalizedPassedPaths = passedPaths.map((file) => safeEvidencePath(file, "evidence_transition_passed"));
    const resultPath = safeEvidencePath(transitionOptions.resultPath, "evidence_transition_result");
    const precommitArtifacts = {};
    for (const file of normalizedEvidencePaths) {
      if (file === contractPath || file === `${contractPath}.sha256`) fail("evidence_transition_artifact_overlaps_contract");
      const absolute = resolve(payload.checkout_root, file);
      if (!absolute.startsWith(`${payload.checkout_root}${path.sep}`)) fail("evidence_transition_artifact_outside_checkout");
      const raw = readFileSync(absolute);
      const blob = spawnSync(GIT_BIN, ["-C", payload.checkout_root, "hash-object", "--stdin", "-t", "blob"], { input: raw, encoding: "utf8" });
      if (blob.status !== 0) fail(`evidence_transition_artifact_hash_failed:${file}`);
      precommitArtifacts[file] = { blob: blob.stdout.trim(), sha256: createHash("sha256").update(raw).digest("hex") };
    }
    evidenceTransition = {
      active_ref: payload.capture_head_ref,
      captured_head_oid: payload.capture_head_oid,
      contract_path: contractPath,
      contract_paths: [...new Set([contractPath, `${contractPath}.sha256`, ...normalizedEvidencePaths])].sort(),
      precommit_artifacts: precommitArtifacts,
      final_child_path_sets: { blocked: [...new Set(normalizedBlockedPaths)].sort(), passed: [...new Set(normalizedPassedPaths)].sort() },
      result_path: resultPath,
    };
  }
  const contract = { schema_version: 1, ...payload, pinned_inputs: pinnedInputs, ...(evidenceTransition ? { evidence_transition: evidenceTransition } : {}) };
  const bytes = `${JSON.stringify(contract, null, 2)}\n`;
  const temp = `${destination}.tmp-${process.pid}`;
  writeFileSync(temp, bytes, { mode: 0o600, flag: "wx" });
  renameSync(temp, destination);
  const digestPath = `${destination}.sha256`;
  const digestTemp = `${digestPath}.tmp-${process.pid}`;
  writeFileSync(digestTemp, `${createHash("sha256").update(bytes).digest("hex")}\n`, { mode: 0o600, flag: "wx" });
  renameSync(digestTemp, digestPath);
  process.stdout.write(`captured current PR/ref contract: ${payload.open_prs.length} PRs, ${payload.local_refs.length} local refs, ${payload.origin_refs.length} origin refs\n`);
}

function verify(repo, commit, path, stage, fixturePath, options) {
  if (!new Set(["before", "boundary", "operation", "after"]).has(stage)) fail("current_contract_stage_invalid");
  const pinned = committedBytes(repo, commit, path);
  const contract = JSON.parse(pinned.raw.toString("utf8"));
  if (contract?.schema_version !== 1) fail("current_contract_schema_invalid");
  for (const input of contract.pinned_inputs ?? []) {
    const actualPin = readPinnedFile(repo, input.commit, input.path, "current_pinned_input");
    if (input.blob !== actualPin.blob || input.sha256 !== actualPin.sha256) fail(`current_pinned_input_identity_changed:${input.path}`);
  }
  let allowlist;
  if (options.allowlistCommit || options.allowlistPath) {
    allowlist = verifyAllowlist(repo, contract, options.allowlistCommit, options.allowlistPath, commit);
  }
  let operationRow = null;
  if (options.operationSide || options.operationRef || options.operationKind) {
    if (!allowlist || !options.operationSide || !options.operationRef || !options.operationKind) fail("current_operation_allowlist_input_required");
    operationRow = allowlist.rows.find((row) => row.side === options.operationSide && row.ref === options.operationRef);
    if (!operationRow) fail(`current_operation_not_allowlisted:${options.operationSide}:${options.operationRef}`);
    if ((options.operationSide === "safety-publish" && options.operationKind !== "publish") || (options.operationSide !== "safety-publish" && options.operationKind !== "delete")) fail("current_operation_kind_side_mismatch");
  }
  if (options.verifyAllowlist && !allowlist) fail("current_allowlist_commit_path_required");
  const transition = contract.evidence_transition
    ? inspectEvidenceTransition(repo, commit, path, contract, stage, {
      allowlistRows: allowlist?.rows,
      appliedRefs: options.appliedRefs ?? [],
    })
    : null;
  const actual = collect(repo, fixturePath);
  const compareOptions = { stage, operationSide: options.operationSide, operationRef: options.operationRef };
  if (transition) compareOptions.allowedActiveOid = transition.verified_head_oid;
  if (transition) compareOptions.appliedRefs = transition.applied_refs;
  compareOptions.allowlistRows = allowlist?.rows ?? [];
  compareCurrent(contract, actual, commit, compareOptions);
  if (["operation", "after"].includes(stage) && options.operationSide === "safety-publish") {
    const localSafety = contract.local_refs.find((row) => row.ref === options.operationRef);
    const originSafety = actual.origin_refs.find((row) => row.ref === options.operationRef);
    if (!localSafety || !originSafety || canonical({ ...originSafety, symref: null }) !== canonical(localSafety)) fail(`current_safety_publish_readback_mismatch:${options.operationRef}`);
  }
  if (["operation", "after"].includes(stage) && ["local", "remote", "tracking"].includes(options.operationSide) && operationRow) {
    const refs = options.operationSide === "remote" ? actual.origin_refs : actual.local_refs;
    if (refs.some((row) => row.ref === options.operationRef)) fail(`current_operation_readback_still_present:${options.operationRef}`);
  }
  process.stdout.write(`PASS: current PR/ref contract verified at ${stage}; blob=${pinned.blob}; sha256=${pinned.sha256}\n`);
  if (transition) process.stdout.write(`EVIDENCE_TRANSITION_JSON=${JSON.stringify(transition)}\n`);
}

function parseArgs(args) {
  const result = { command: args[0], repo: process.cwd(), stage: "before", pinInputs: [], evidencePaths: [], blockedPaths: [], passedPaths: [], appliedRefs: [] };
  for (let index = 1; index < args.length; ) {
    const key = args[index++];
    if (key === "--apply") fail("current_contract_is_read_only");
    if (key === "--verify-allowlist") { result.verifyAllowlist = true; continue; }
    if (!args[index]) fail(`argument_value_missing:${key}`);
    const value = args[index++];
    if (key === "--repo") result.repo = value;
    else if (key === "--output") result.output = value;
    else if (key === "--contract-commit") result.commit = value;
    else if (key === "--contract") result.path = value;
    else if (key === "--stage") result.stage = value;
    else if (key === "--source-fixture") result.fixturePath = value;
    else if (key === "--pin-input") result.pinInputs.push(value);
    else if (key === "--contract-evidence-path") result.evidencePaths.push(value);
    else if (key === "--final-blocked-path") result.blockedPaths.push(value);
    else if (key === "--final-passed-path") result.passedPaths.push(value);
    else if (key === "--result-path") result.resultPath = value;
    else if (key === "--allowlist-commit") result.allowlistCommit = value;
    else if (key === "--allowlist") result.allowlistPath = value;
    else if (key === "--operation-side") result.operationSide = value;
    else if (key === "--operation-ref") result.operationRef = value;
    else if (key === "--operation-kind") result.operationKind = value;
    else if (key === "--applied-ref") result.appliedRefs.push(value);
    else fail(`unknown_argument:${key}`);
  }
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = parseArgs(process.argv.slice(2));
    if (args.command === "capture") capture(args.repo, args.output, args.fixturePath, args.pinInputs, args);
    else if (args.command === "verify") verify(args.repo, args.commit, args.path, args.stage, args.fixturePath, args);
    else fail("usage: prune-stale-branches-current.mjs <capture|verify> [--repo PATH] [--output PATH] [--contract-commit SHA --contract PATH --stage before|boundary|after]");
  } catch (error) {
    process.stderr.write(`prune-stale-branches-current: FAIL: ${error.message}\n`);
    process.exitCode = 1;
  }
}
