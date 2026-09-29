#!/usr/bin/env node
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const REPOSITORY = "szTheory/sigra";
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
  return command("git", ["-C", repo, ...args], undefined, label);
}

function validBranch(name, label) {
  if (typeof name !== "string" || !name || name.startsWith("-") || name.includes("\n")) fail(`${label}_invalid`);
  const result = spawnSync("git", ["check-ref-format", "--branch", name], { encoding: "utf8" });
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
  const result = spawnSync("git", ["-C", repo, "cat-file", "-t", oid], { encoding: "utf8" });
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
    const type = objectType(repo, oid, ref);
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
  command("git", ["-C", repo, "cat-file", "-e", `${commit}^{commit}`], undefined, `${label}_commit_unreadable`);
  const blob = command("git", ["-C", repo, "rev-parse", `${commit}:${path}`], undefined, `${label}_path_missing`).trim();
  const result = spawnSync("git", ["-C", repo, "show", `${commit}:${path}`], { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (result.status !== 0) fail(`${label}_bytes_unreadable`);
  const raw = result.stdout;
  const hash = spawnSync("git", ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw, encoding: "utf8" });
  if (hash.status !== 0 || hash.stdout.trim() !== blob) fail(`${label}_git_blob_mismatch`);
  return { raw, blob, sha256: createHash("sha256").update(raw).digest("hex") };
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
  for (const row of options.allowlistRows ?? []) {
    const ref = row.ref;
    if (row.side === "local" || row.side === "tracking") {
      const expected = expectedLocal.get(ref);
      if (!expected || expected.oid !== row.oid || expected.type !== row.type) fail(`current_allowlist_local_identity_mismatch:${ref}`);
      if (!actualLocal.has(ref)) expectedLocal.delete(ref);
    } else if (row.side === "remote") {
      const expected = expectedOrigin.get(ref);
      if (!expected || expected.oid !== row.oid || expected.type !== row.type) fail(`current_allowlist_origin_identity_mismatch:${ref}`);
      if (!actualOrigin.has(ref)) expectedOrigin.delete(ref);
    } else if (row.side === "safety-publish") {
      const local = expectedLocal.get(ref);
      const current = actualOrigin.get(ref);
      if (!local || local.oid !== row.oid || local.type !== row.type) fail(`current_safety_publish_source_mismatch:${ref}`);
      if (current && (current.oid !== row.oid || current.type !== row.type || current.peeled_oid !== local.peeled_oid || current.peeled_type !== local.peeled_type)) fail(`current_safety_publish_identity_conflict:${ref}`);
    }
  }
  for (const [ref, expected] of expectedOrigin) {
    const current = actualOrigin.get(ref);
    if (!current && options.stage === "after" && options.operationSide === "remote" && ref === options.operationRef) continue;
    if (!current || canonical(expected) !== canonical(current)) fail(`current_origin_ref_identity_changed:${ref}`);
  }
  for (const [ref, current] of actualOrigin) {
    if (expectedOrigin.has(ref)) continue;
    const safetyRow = (options.allowlistRows ?? []).find((row) => row.side === "safety-publish" && row.ref === ref);
    const localSafety = expectedLocal.get(ref);
    if (safetyRow && localSafety && current.oid === safetyRow.oid && current.type === safetyRow.type && current.peeled_oid === localSafety.peeled_oid && current.peeled_type === localSafety.peeled_type) continue;
    fail(`current_origin_ref_unexpected:${ref}`);
  }
  if (expectedLocal.size !== actualLocal.size) fail("current_local_ref_set_changed");
  for (const [ref, expected] of expectedLocal) {
    const current = actualLocal.get(ref);
    if (!current) fail(`current_local_ref_missing:${ref}`);
    if (canonical(expected) === canonical(current)) continue;
    if (ref === contract.capture_head_ref && current.oid === contractCommit && current.type === "commit" && expected.type === "commit" && current.peeled_oid === expected.peeled_oid && current.peeled_type === expected.peeled_type && current.symref === expected.symref) continue;
    fail(`current_local_ref_identity_changed:${ref}`);
  }
  for (const ref of actualLocal.keys()) if (!expectedLocal.has(ref)) fail(`current_local_ref_unexpected:${ref}`);
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
    const check = spawnSync("git", ["check-ref-format", ref], { encoding: "utf8" });
    if (check.status !== 0) fail(`current_allowlist_ref_invalid:${ref}`);
    seen.add(`${side}\0${ref}`);
    rows.push({ side, ref, oid, type, reason });
  }
  if (!rows.length) fail("current_allowlist_empty");
  return rows;
}

function verifyAllowlist(repo, contract, allowlistCommit, allowlistPath) {
  if (!allowlistCommit || !allowlistPath) fail("current_allowlist_commit_path_required");
  const input = readPinnedFile(repo, allowlistCommit, allowlistPath, "current_allowlist");
  const pin = (contract.pinned_inputs ?? []).find((entry) => entry.commit === allowlistCommit && entry.path === allowlistPath);
  if (!pin || pin.blob !== input.blob || pin.sha256 !== input.sha256) fail("current_allowlist_not_pinned_by_contract");
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
    if (["refs/heads/ci/phase-235-16-source-complete", "refs/heads/safety/local-main-before-release-cleanup-20260831", "refs/tags/archive/local-main-pre-235-recovery"].includes(protectedRef)) fail(`current_allowlist_contains_safety_ref:${row.ref}`);
    const source = row.side === "remote" ? origin.get(row.ref) : local.get(row.ref);
    if (!source || source.oid !== row.oid || source.type !== row.type) fail(`current_allowlist_ref_identity_mismatch:${row.ref}`);
  }
  return { rows, blob: input.blob, sha256: input.sha256 };
}

function committedBytes(repo, commit, path) {
  if (!OID.test(commit ?? "")) fail("current_contract_commit_invalid");
  if (typeof path !== "string" || !path || path.startsWith("/") || path.includes("..") || path.includes("\n") || path.includes(":")) fail("current_contract_path_invalid");
  command("git", ["-C", repo, "cat-file", "-e", `${commit}^{commit}`], undefined, "current_contract_commit_unreadable");
  const blob = command("git", ["-C", repo, "rev-parse", `${commit}:${path}`], undefined, "current_contract_path_missing").trim();
  if (!OID.test(blob)) fail("current_contract_blob_oid_invalid");
  const bytes = spawnSync("git", ["-C", repo, "show", `${commit}:${path}`], { encoding: null, maxBuffer: 32 * 1024 * 1024 });
  if (bytes.status !== 0) fail("current_contract_committed_bytes_unreadable");
  const raw = bytes.stdout;
  const rehashedBlob = spawnSync("git", ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw, encoding: "utf8" });
  if (rehashedBlob.status !== 0 || rehashedBlob.stdout.trim() !== blob) fail("current_contract_git_blob_mismatch");
  const sha256 = createHash("sha256").update(raw).digest("hex");
  const sidecar = command("git", ["-C", repo, "show", `${commit}:${path}.sha256`], undefined, "current_contract_sha256_record_missing").trim();
  if (!/^[0-9a-f]{64}$/.test(sidecar)) fail("current_contract_sha256_record_invalid");
  if (sidecar !== sha256) fail("current_contract_sha256_mismatch");
  return { raw, blob, sha256 };
}

function capture(repo, output, fixturePath, pinSpecs) {
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
  const bytes = `${JSON.stringify({ schema_version: 1, ...payload, pinned_inputs: pinnedInputs }, null, 2)}\n`;
  const destination = resolve(output);
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
  if (!new Set(["before", "boundary", "after"]).has(stage)) fail("current_contract_stage_invalid");
  const pinned = committedBytes(repo, commit, path);
  const contract = JSON.parse(pinned.raw.toString("utf8"));
  if (contract?.schema_version !== 1) fail("current_contract_schema_invalid");
  for (const input of contract.pinned_inputs ?? []) {
    const actualPin = readPinnedFile(repo, input.commit, input.path, "current_pinned_input");
    if (input.blob !== actualPin.blob || input.sha256 !== actualPin.sha256) fail(`current_pinned_input_identity_changed:${input.path}`);
  }
  let allowlist;
  if (options.allowlistCommit || options.allowlistPath) {
    allowlist = verifyAllowlist(repo, contract, options.allowlistCommit, options.allowlistPath);
  }
  let operationRow = null;
  if (options.operationSide || options.operationRef || options.operationKind) {
    if (!allowlist || !options.operationSide || !options.operationRef || !options.operationKind) fail("current_operation_allowlist_input_required");
    operationRow = allowlist.rows.find((row) => row.side === options.operationSide && row.ref === options.operationRef);
    if (!operationRow) fail(`current_operation_not_allowlisted:${options.operationSide}:${options.operationRef}`);
    if ((options.operationSide === "safety-publish" && options.operationKind !== "publish") || (options.operationSide !== "safety-publish" && options.operationKind !== "delete")) fail("current_operation_kind_side_mismatch");
  }
  if (options.verifyAllowlist && !allowlist) fail("current_allowlist_commit_path_required");
  const actual = collect(repo, fixturePath);
  const compareOptions = { stage, operationSide: options.operationSide, operationRef: options.operationRef };
  compareOptions.allowlistRows = allowlist?.rows ?? [];
  compareCurrent(contract, actual, commit, compareOptions);
  if (stage === "after" && options.operationSide === "safety-publish") {
    const localSafety = contract.local_refs.find((row) => row.ref === options.operationRef);
    const originSafety = actual.origin_refs.find((row) => row.ref === options.operationRef);
    if (!localSafety || !originSafety || canonical({ ...originSafety, symref: null }) !== canonical(localSafety)) fail(`current_safety_publish_readback_mismatch:${options.operationRef}`);
  }
  if (stage === "after" && ["local", "remote", "tracking"].includes(options.operationSide) && operationRow) {
    const refs = options.operationSide === "remote" ? actual.origin_refs : actual.local_refs;
    if (refs.some((row) => row.ref === options.operationRef)) fail(`current_operation_readback_still_present:${options.operationRef}`);
  }
  process.stdout.write(`PASS: current PR/ref contract verified at ${stage}; blob=${pinned.blob}; sha256=${pinned.sha256}\n`);
}

function parseArgs(args) {
  const result = { command: args[0], repo: process.cwd(), stage: "before", pinInputs: [] };
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
    else if (key === "--allowlist-commit") result.allowlistCommit = value;
    else if (key === "--allowlist") result.allowlistPath = value;
    else if (key === "--operation-side") result.operationSide = value;
    else if (key === "--operation-ref") result.operationRef = value;
    else if (key === "--operation-kind") result.operationKind = value;
    else fail(`unknown_argument:${key}`);
  }
  return result;
}

try {
  const args = parseArgs(process.argv.slice(2));
  if (args.command === "capture") capture(args.repo, args.output, args.fixturePath, args.pinInputs);
  else if (args.command === "verify") verify(args.repo, args.commit, args.path, args.stage, args.fixturePath, args);
  else fail("usage: prune-stale-branches-current.mjs <capture|verify> [--repo PATH] [--output PATH] [--contract-commit SHA --contract PATH --stage before|boundary|after]");
} catch (error) {
  process.stderr.write(`prune-stale-branches-current: FAIL: ${error.message}\n`);
  process.exitCode = 1;
}
