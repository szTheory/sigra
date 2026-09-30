#!/usr/bin/env node

import { createHash } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const GIT_BIN = "/usr/bin/git";
export const CANDIDATE_COMMAND = "/usr/bin/git -c gc.auto=0 -c maintenance.auto=false fetch --refmap= --no-tags --no-write-fetch-head origin refs/heads/gh-pages";

const PHASE_DIR = ".planning/phases/245-branch-prune-local-and-remote";
const PREFLIGHT_PATH = `${PHASE_DIR}/245-22-PLANNING-PREFLIGHT.json`;
const PLAN21_PATH = `${PHASE_DIR}/245-21-PLAN.md`;
const PRIOR_RECEIPTS = {
  exec_preflight: {
    path: `${PHASE_DIR}/245-21-EXEC-PREFLIGHT.json`,
    sha256: "41d720cc2f26521463d93ad96abd416066c74e177adf8562dab0426c16849062",
  },
  result: {
    path: `${PHASE_DIR}/245-21-RESULT.json`,
    sha256: "700619e0deb178908335dfd32c1b9f9695ab2913c8071524d9a4f3e77b91005a",
  },
};

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function asBuffer(value) {
  if (Buffer.isBuffer(value)) return value;
  return Buffer.from(value ?? "", "utf8");
}

function runGitRaw(args, { cwd, input } = {}) {
  const result = spawnSync(GIT_BIN, args, {
    cwd,
    input,
    encoding: null,
    env: { ...process.env, LC_ALL: "C" },
  });
  return {
    status: Number.isInteger(result.status) ? result.status : 128,
    stdout: asBuffer(result.stdout),
    stderr: asBuffer(result.stderr),
    error: result.error ? String(result.error.message ?? result.error) : null,
  };
}

function checkedGit(repo, args) {
  const result = runGitRaw(["-C", repo, ...args]);
  if (result.status !== 0) {
    throw new Error(`git -C ${repo} ${args.join(" ")} failed (${result.status}): ${result.stderr.toString("utf8")}`);
  }
  return result.stdout.toString("utf8");
}

function gitObjectReadable(repo, oid) {
  return runGitRaw(["-C", repo, "cat-file", "-e", oid]).status === 0;
}

function exactRefOid(repo, ref) {
  const result = runGitRaw(["-C", repo, "rev-parse", "--verify", "--quiet", ref]);
  return result.status === 0 ? result.stdout.toString("utf8").trim() : null;
}

export function parseRefInventory(raw) {
  const bytes = asBuffer(raw);
  const lines = bytes.toString("utf8").split("\n").filter((line) => line.length > 0);
  const rows = lines.map((line) => {
    const [ref, type, oid, peeled_oid = "", peeled_type = "", symref = ""] = line.split("\t");
    return { ref, type, oid, peeled_oid: peeled_oid || null, peeled_type: peeled_type || null, symref: symref || null };
  });
  const counts = new Map();
  for (const row of rows) counts.set(row.ref, (counts.get(row.ref) ?? 0) + 1);
  return {
    rows,
    duplicate_ref_names: [...counts].filter(([, count]) => count > 1).map(([ref]) => ref).sort(),
    malformed_rows: rows.flatMap((row, index) =>
      !row.ref || !row.type || !row.oid || lines[index].split("\t").length !== 6 ? [index + 1] : [],
    ),
  };
}

function captureFetchHead(fetchHeadPath) {
  if (!existsSync(fetchHeadPath)) return { exists: false, sha256: null, bytes_base64: null };
  const bytes = readFileSync(fetchHeadPath);
  return { exists: true, sha256: sha256(bytes), bytes_base64: bytes.toString("base64") };
}

function captureSnapshot(repo, fetchHeadPath) {
  const refResult = runGitRaw([
    "-C", repo,
    "for-each-ref",
    "--format=%(refname)%09%(objecttype)%09%(objectname)%09%(*objectname)%09%(*objecttype)%09%(symref)",
  ]);
  const headResult = runGitRaw(["-C", repo, "symbolic-ref", "--quiet", "HEAD"]);
  const inventory = parseRefInventory(refResult.stdout);
  return {
    ref_inventory_exit_code: refResult.status,
    ref_inventory_sha256: sha256(refResult.stdout),
    ref_inventory_bytes_base64: refResult.stdout.toString("base64"),
    ref_inventory_rows: inventory.rows,
    duplicate_ref_names: inventory.duplicate_ref_names,
    malformed_ref_rows: inventory.malformed_rows,
    symbolic_head_exit_code: headResult.status,
    symbolic_head_bytes_base64: headResult.stdout.toString("base64"),
    fetch_head: captureFetchHead(fetchHeadPath),
  };
}

function readOriginGhPages(repo) {
  const result = runGitRaw(["-C", repo, "ls-remote", "--heads", "origin", "refs/heads/gh-pages"]);
  if (result.status !== 0) return { exit_code: result.status, oid: null, stderr: result.stderr.toString("utf8") };
  const rows = result.stdout.toString("utf8").trim().split("\n").filter(Boolean);
  if (rows.length !== 1) return { exit_code: result.status, oid: null, rows, stderr: "expected exactly one advertised gh-pages ref" };
  const [oid, ref] = rows[0].split(/\s+/);
  return { exit_code: result.status, oid: ref === "refs/heads/gh-pages" ? oid : null, ref: ref ?? null };
}

function initializeFixture(tempRoot, fetchHeadMode) {
  const origin = join(tempRoot, "origin.git");
  const seed = join(tempRoot, "seed");
  const checkout = join(tempRoot, "checkout");
  let result = runGitRaw(["init", "--quiet", "--bare", "--initial-branch=main", origin]);
  if (result.status !== 0) throw new Error(`git init bare failed: ${result.stderr.toString("utf8")}`);
  result = runGitRaw(["init", "--quiet", "--initial-branch=main", seed]);
  if (result.status !== 0) throw new Error(`git init seed failed: ${result.stderr.toString("utf8")}`);

  checkedGit(seed, ["config", "user.name", "Object Fetch Fixture"]);
  checkedGit(seed, ["config", "user.email", "object-fetch-fixture@example.invalid"]);
  writeFileSync(join(seed, "index.txt"), "fixture baseline\n");
  checkedGit(seed, ["add", "--", "index.txt"]);
  const seedCommit = runGitRaw([
    "-C", seed, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "--quiet", "-m", "fixture baseline",
  ]);
  if (seedCommit.status !== 0) throw new Error(`git commit seed failed: ${seedCommit.stderr.toString("utf8")}`);
  checkedGit(seed, ["branch", "gh-pages"]);
  checkedGit(seed, ["remote", "add", "origin", origin]);
  checkedGit(seed, ["push", "--quiet", "origin", "refs/heads/main", "refs/heads/gh-pages"]);
  const oldOriginOid = checkedGit(seed, ["rev-parse", "refs/heads/gh-pages"]).trim();

  result = runGitRaw(["clone", "--quiet", origin, checkout]);
  if (result.status !== 0) throw new Error(`git clone checkout failed: ${result.stderr.toString("utf8")}`);
  checkedGit(checkout, ["config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"]);
  const oldTrackingOid = exactRefOid(checkout, "refs/remotes/origin/gh-pages");
  if (!oldTrackingOid) throw new Error("fixture checkout has no origin/gh-pages tracking ref");

  const gitFetchHeadPath = checkedGit(checkout, ["rev-parse", "--git-path", "FETCH_HEAD"]).trim();
  const fetchHeadPath = isAbsolute(gitFetchHeadPath) ? gitFetchHeadPath : resolve(checkout, gitFetchHeadPath);
  if (fetchHeadMode === "present") {
    writeFileSync(fetchHeadPath, Buffer.from("fixture FETCH_HEAD sentinel\nsecond sentinel row\n"));
  } else if (fetchHeadMode === "absent") {
    rmSync(fetchHeadPath, { force: true });
  } else {
    throw new Error(`unsupported FETCH_HEAD mode: ${fetchHeadMode}`);
  }

  checkedGit(seed, ["checkout", "--quiet", "gh-pages"]);
  writeFileSync(join(seed, "gh-pages.txt"), "new advertised object\n");
  checkedGit(seed, ["add", "--", "gh-pages.txt"]);
  const nextCommit = runGitRaw([
    "-C", seed, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "--quiet", "-m", "advance gh-pages",
  ]);
  if (nextCommit.status !== 0) throw new Error(`git commit gh-pages failed: ${nextCommit.stderr.toString("utf8")}`);
  checkedGit(seed, ["push", "--quiet", "origin", "refs/heads/gh-pages"]);
  const sourceOid = checkedGit(seed, ["rev-parse", "refs/heads/gh-pages"]).trim();
  return { origin, seed, checkout, fetchHeadPath, oldOriginOid, oldTrackingOid, sourceOid };
}

function normalizeCommandResult(result) {
  return {
    status: Number.isInteger(result?.status) ? result.status : 128,
    stdout: asBuffer(result?.stdout),
    stderr: asBuffer(result?.stderr),
    error: result?.error ? String(result.error.message ?? result.error) : null,
  };
}

function equalFetchHead(before, after) {
  if (before.exists !== after.exists) return false;
  if (!before.exists) return true;
  return before.sha256 === after.sha256 && before.bytes_base64 === after.bytes_base64;
}

export function runFixtureCase({ fetchHead = "present", fetcher } = {}) {
  let tempRoot;
  try {
    tempRoot = mkdtempSync(join(tmpdir(), "sigra-object-fetch-isolation-"));
    const fixture = initializeFixture(tempRoot, fetchHead);
    const { checkout, fetchHeadPath, oldOriginOid, oldTrackingOid, sourceOid } = fixture;
    const advertisedBefore = readOriginGhPages(checkout);
    const objectReadableBefore = gitObjectReadable(checkout, sourceOid);
    const before = captureSnapshot(checkout, fetchHeadPath);
    const fetchArgs = [
      "-c", "gc.auto=0",
      "-c", "maintenance.auto=false",
      "fetch", "--refmap=", "--no-tags", "--no-write-fetch-head",
      "origin", "refs/heads/gh-pages",
    ];
    const runFetch = () => runGitRaw(fetchArgs, { cwd: checkout });
    const checkedFixtureGit = (repo, args) => {
      const result = runGitRaw(["-C", repo, ...args]);
      if (result.status !== 0) {
        throw new Error(`git -C ${repo} ${args.join(" ")} failed (${result.status}): ${result.stderr.toString("utf8")}`);
      }
      return result.stdout.toString("utf8").trimEnd();
    };
    let fetchResult;
    try {
      fetchResult = normalizeCommandResult(fetcher
        ? fetcher({
          runFetch,
          runGit: checkedFixtureGit,
          checkout,
          newOid: sourceOid,
          oldTrackingOid,
          oldOriginOid,
          trackingRef: "refs/remotes/origin/gh-pages",
          fetchHeadPath,
          writeFetchHead: (bytes) => writeFileSync(fetchHeadPath, asBuffer(bytes)),
          command: CANDIDATE_COMMAND,
        })
        : runFetch());
    } catch (error) {
      fetchResult = { status: 128, stdout: Buffer.alloc(0), stderr: Buffer.from(String(error)), error: String(error) };
    }

    const objectReadableAfter = gitObjectReadable(checkout, sourceOid);
    const after = captureSnapshot(checkout, fetchHeadPath);
    const advertisedAfter = readOriginGhPages(checkout);
    const trackingOidAfter = exactRefOid(checkout, "refs/remotes/origin/gh-pages");
    const refInventoryEqual = before.ref_inventory_exit_code === 0
      && after.ref_inventory_exit_code === 0
      && before.ref_inventory_bytes_base64 === after.ref_inventory_bytes_base64;
    const symbolicHeadEqual = before.symbolic_head_exit_code === 0
      && after.symbolic_head_exit_code === 0
      && before.symbolic_head_bytes_base64 === after.symbolic_head_bytes_base64;
    const fetchHeadEqual = equalFetchHead(before.fetch_head, after.fetch_head);
    const trackingRefEqual = oldTrackingOid !== null && oldTrackingOid === trackingOidAfter;
    const trackingBaselineEqual = oldTrackingOid !== null && oldTrackingOid === oldOriginOid;
    const originSourceOidUnchanged = advertisedBefore.exit_code === 0
      && advertisedAfter.exit_code === 0
      && advertisedBefore.oid === sourceOid
      && advertisedAfter.oid === sourceOid;

    const failedPredicates = [];
    if (advertisedBefore.oid !== sourceOid || advertisedAfter.oid !== sourceOid) failedPredicates.push("origin_source_oid_changed");
    if (objectReadableBefore) failedPredicates.push("object_was_readable_before_fetch");
    if (fetchResult.status !== 0) failedPredicates.push("fetch_failed");
    if (!objectReadableAfter) failedPredicates.push("object_unreadable_after_fetch");
    if (before.ref_inventory_exit_code !== 0 || after.ref_inventory_exit_code !== 0) failedPredicates.push("ref_inventory_unavailable");
    if ([...before.duplicate_ref_names, ...after.duplicate_ref_names].length > 0) failedPredicates.push("duplicate_ref_name");
    if ([...before.malformed_ref_rows, ...after.malformed_ref_rows].length > 0) failedPredicates.push("malformed_ref_inventory");
    if (!refInventoryEqual) failedPredicates.push("ref_inventory_changed");
    if (!symbolicHeadEqual) failedPredicates.push("symbolic_head_changed");
    if (!fetchHeadEqual) failedPredicates.push("fetch_head_changed");
    if (!trackingRefEqual) failedPredicates.push("tracking_ref_changed");
    if (!trackingBaselineEqual) failedPredicates.push("tracking_ref_did_not_start_at_old_origin_oid");

    return {
      name: fetchHead === "present" ? "fetch_head_present" : "fetch_head_absent",
      status: failedPredicates.length === 0 ? "passed" : "blocked",
      candidate_command: CANDIDATE_COMMAND,
      fetch_exit_code: fetchResult.status,
      fetch_stdout: fetchResult.stdout.toString("utf8"),
      fetch_stderr: fetchResult.stderr.toString("utf8"),
      fetch_error: fetchResult.error,
      source_oid: sourceOid,
      origin_gh_pages_oid_before: advertisedBefore.oid,
      origin_gh_pages_oid_after: advertisedAfter.oid,
      old_origin_gh_pages_oid: oldOriginOid,
      old_tracking_oid: oldTrackingOid,
      tracking_oid_after: trackingOidAfter,
      tracking_baseline_equal: trackingBaselineEqual,
      origin_source_oid_unchanged: originSourceOidUnchanged,
      object_readable_before: objectReadableBefore,
      object_readable_after: objectReadableAfter,
      ref_inventory_equal: refInventoryEqual,
      ref_inventory_before: before,
      ref_inventory_after: after,
      symbolic_head_equal: symbolicHeadEqual,
      symbolic_head_before_base64: before.symbolic_head_bytes_base64,
      symbolic_head_after_base64: after.symbolic_head_bytes_base64,
      fetch_head_equal: fetchHeadEqual,
      fetch_head_before: before.fetch_head,
      fetch_head_after: after.fetch_head,
      tracking_ref_equal: trackingRefEqual,
      failed_predicates: failedPredicates,
    };
  } catch (error) {
    return {
      name: fetchHead === "absent" ? "fetch_head_absent" : "fetch_head_present",
      status: "blocked",
      candidate_command: CANDIDATE_COMMAND,
      fetch_exit_code: null,
      source_oid: null,
      object_readable_before: false,
      object_readable_after: false,
      ref_inventory_equal: false,
      symbolic_head_equal: false,
      fetch_head_equal: false,
      tracking_ref_equal: false,
      failed_predicates: ["fixture_setup_or_capture_failed"],
      diagnostics: [String(error)],
    };
  } finally {
    if (tempRoot) rmSync(tempRoot, { recursive: true, force: true });
  }
}

function checkRuntime(expectedRuntime) {
  const runtime = { path: GIT_BIN, version: null, sha256: null };
  const failures = [];
  try {
    lstatSync(GIT_BIN);
    runtime.sha256 = sha256(readFileSync(GIT_BIN));
  } catch (error) {
    failures.push(`runtime_binary_unreadable: ${String(error)}`);
  }
  if (runtime.sha256) {
    const version = runGitRaw(["--version"]);
    runtime.version = version.stdout.toString("utf8").trim();
    if (version.status !== 0) failures.push(`runtime_version_command_failed: ${version.status}`);
  }
  if (expectedRuntime?.path !== GIT_BIN) failures.push("runtime_path_does_not_match_preflight");
  if (expectedRuntime?.version !== runtime.version) failures.push("runtime_version_does_not_match_preflight");
  if (expectedRuntime?.sha256 !== runtime.sha256) failures.push("runtime_sha256_does_not_match_preflight");
  return { runtime, failures };
}

function gitReadOnly(repoRoot, args) {
  return runGitRaw(["-C", repoRoot, ...args]);
}

function checkPinnedSources(repoRoot, records) {
  const failures = [];
  const checked = [];
  if (!Array.isArray(records) || records.length === 0) {
    return { count: 0, passed: 0, failures: ["pinned_source_records_missing"], checked };
  }
  for (const record of records) {
    const row = { path: record.path, commit: record.commit, expected_blob: record.blob, expected_sha256: record.sha256 };
    const commitResult = gitReadOnly(repoRoot, ["cat-file", "-e", `${record.commit}^{commit}`]);
    const blobResult = gitReadOnly(repoRoot, ["rev-parse", "--verify", `${record.commit}:${record.path}`]);
    const contentResult = gitReadOnly(repoRoot, ["show", `${record.commit}:${record.path}`]);
    row.commit_readable = commitResult.status === 0;
    row.observed_blob = blobResult.status === 0 ? blobResult.stdout.toString("utf8").trim() : null;
    row.blob_matches = row.observed_blob === record.blob;
    row.observed_sha256 = contentResult.status === 0 ? sha256(contentResult.stdout) : null;
    row.sha256_matches = row.observed_sha256 === record.sha256;
    row.status = record.status === "ready" && row.commit_readable && row.blob_matches && row.sha256_matches ? "ready" : "blocked";
    if (row.status !== "ready") failures.push(`pinned_source_mismatch:${record.path}`);
    checked.push(row);
  }
  return { count: checked.length, passed: checked.filter((row) => row.status === "ready").length, failures, checked };
}

function checkPlanningInputs(repoRoot, inputs, supersededPaths = new Set()) {
  const failures = [];
  const checked = [];
  for (const input of Array.isArray(inputs) ? inputs : []) {
    const entry = { path: input.path, expected_sha256: input.sha256, observed_sha256: null, matches: false, accepted_superseded: false };
    try {
      entry.observed_sha256 = sha256(readFileSync(join(repoRoot, input.path)));
      entry.matches = entry.observed_sha256 === input.sha256;
    } catch (error) {
      entry.error = String(error);
    }
    if (!entry.matches && supersededPaths.has(input.path)) {
      entry.accepted_superseded = true;
      entry.reason = "Current Plan 21 wave, Plan 20 and Plan 22 dependencies, and fetch-proof prerequisite were revalidated.";
    } else if (!entry.matches) {
      failures.push(`planning_input_mismatch:${input.path}`);
    }
    checked.push(entry);
  }
  if (!Array.isArray(inputs) || inputs.length === 0) failures.push("planning_input_records_missing");
  return {
    count: checked.length,
    passed: checked.filter((entry) => entry.matches || entry.accepted_superseded).length,
    accepted_superseded: checked.filter((entry) => entry.accepted_superseded).map((entry) => entry.path),
    failures,
    checked,
  };
}

function checkPriorReceipts(repoRoot) {
  const result = {};
  const failures = [];
  for (const [name, expected] of Object.entries(PRIOR_RECEIPTS)) {
    let observed = null;
    try {
      observed = sha256(readFileSync(join(repoRoot, expected.path)));
    } catch (error) {
      failures.push(`prior_receipt_unreadable:${name}`);
    }
    result[name] = {
      path: expected.path,
      expected_sha256: expected.sha256,
      observed_sha256: observed,
      matches: observed === expected.sha256,
    };
    if (observed !== expected.sha256) failures.push(`prior_receipt_digest_mismatch:${name}`);
  }
  return { receipts: result, failures };
}

function checkPlan21Dependency(repoRoot) {
  try {
    const plan = readFileSync(join(repoRoot, PLAN21_PATH), "utf8");
    const wave = /^wave:\s*16\s*$/m.test(plan);
    const depends = /^depends_on:\s*\[\s*245-20\s*,\s*245-22\s*\]\s*$/m.test(plan);
    const consumesProof = plan.includes("245-22-FETCH-PROOF.json");
    return {
      wave_16: wave,
      depends_on_245_20_and_245_22: depends,
      requires_fetch_proof: consumesProof,
      passed: wave && depends && consumesProof,
      failures: [
        ...(!wave ? ["plan21_wave_is_not_16"] : []),
        ...(!depends ? ["plan21_dependency_on_245_22_missing"] : []),
        ...(!consumesProof ? ["plan21_fetch_proof_input_missing"] : []),
      ],
    };
  } catch (error) {
    return { wave_16: false, depends_on_245_20_and_245_22: false, requires_fetch_proof: false, passed: false, failures: [`plan21_unreadable:${String(error)}`] };
  }
}

function writeJsonAtomically(targetPath, value) {
  mkdirSync(dirname(targetPath), { recursive: true });
  const tempPath = join(dirname(targetPath), `.${basename(targetPath)}.${process.pid}.tmp`);
  writeFileSync(tempPath, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  renameSync(tempPath, targetPath);
}

export function buildFetchProof({ repoRoot = process.cwd(), outputPath } = {}) {
  const resolvedRoot = resolve(repoRoot);
  const resolvedOutput = resolve(outputPath ?? join(resolvedRoot, `${PHASE_DIR}/245-22-FETCH-PROOF.json`));
  const failures = [];
  const proof = {
    schema_version: 1,
    phase: "245-branch-prune-local-and-remote",
    plan: "22",
    created_at: new Date().toISOString(),
    status: "blocked",
    candidate_command: CANDIDATE_COMMAND,
    production_ref_operations: 0,
    no_production_ref_operations: true,
    prior_receipts: {},
    preflight: { path: PREFLIGHT_PATH, status: "unreadable", pinned_sources: { count: 0, passed: 0 }, planning_inputs: { count: 0, passed: 0 } },
    dependency: {},
    runtime: { path: GIT_BIN, version: null, sha256: null },
    cases: [],
    historical_audits: { pr_11_rows: "unresolved", cleanup_30_rows: "unresolved" },
    failed_predicates: failures,
  };

  let preflight;
  try {
    preflight = JSON.parse(readFileSync(join(resolvedRoot, PREFLIGHT_PATH), "utf8"));
  } catch (error) {
    failures.push(`planning_preflight_unreadable:${String(error)}`);
  }

  const runtimeCheck = checkRuntime(preflight?.runtime);
  proof.runtime = runtimeCheck.runtime;
  failures.push(...runtimeCheck.failures);

  proof.dependency = checkPlan21Dependency(resolvedRoot);
  failures.push(...proof.dependency.failures);

  if (preflight) {
    proof.preflight.status = preflight.status ?? "missing_status";
    proof.preflight.purpose = preflight.purpose ?? null;
    proof.preflight.pinned_sources = checkPinnedSources(resolvedRoot, preflight.pinned_sources?.records);
    const supersededInputs = proof.dependency.passed ? new Set([PLAN21_PATH]) : new Set();
    proof.preflight.planning_inputs = checkPlanningInputs(resolvedRoot, preflight.inputs, supersededInputs);
    proof.preflight.checks = preflight.checks ?? {};
    if (preflight.status !== "ready") failures.push("planning_preflight_not_ready");
    if (preflight.pinned_sources?.count !== proof.preflight.pinned_sources.count) failures.push("pinned_source_count_mismatch");
    if (proof.preflight.pinned_sources.failures.length) failures.push(...proof.preflight.pinned_sources.failures);
    if (proof.preflight.planning_inputs.failures.length) failures.push(...proof.preflight.planning_inputs.failures);
    const falseChecks = Object.entries(preflight.checks ?? {}).filter(([, passed]) => passed !== true).map(([name]) => name);
    if (falseChecks.length) failures.push(...falseChecks.map((name) => `planning_preflight_check_not_true:${name}`));
  }

  const priorCheck = checkPriorReceipts(resolvedRoot);
  proof.prior_receipts = {
    exec_preflight_sha256: priorCheck.receipts.exec_preflight?.observed_sha256,
    result_sha256: priorCheck.receipts.result?.observed_sha256,
    preserved: priorCheck.failures.length === 0,
    details: priorCheck.receipts,
  };
  failures.push(...priorCheck.failures);

  // Do not invoke any fixture Git command unless the binary exactly matches the ready preflight.
  const runtimePinned = runtimeCheck.failures.length === 0;
  if (runtimePinned) {
    proof.cases = [
      runFixtureCase({ fetchHead: "present" }),
      runFixtureCase({ fetchHead: "absent" }),
    ];
    for (const result of proof.cases) {
      for (const predicate of result.failed_predicates) failures.push(`${result.name}:${predicate}`);
    }
  }

  // The historical receipts are immutable inputs; detect any change during the fixture run.
  const priorCheckAfter = checkPriorReceipts(resolvedRoot);
  if (priorCheckAfter.failures.length) failures.push(...priorCheckAfter.failures.map((failure) => `after_fixture:${failure}`));
  if (priorCheckAfter.receipts.exec_preflight?.observed_sha256 !== proof.prior_receipts.exec_preflight_sha256
    || priorCheckAfter.receipts.result?.observed_sha256 !== proof.prior_receipts.result_sha256) {
    failures.push("prior_receipts_changed_during_fixture");
  }

  proof.failed_predicates = [...new Set(failures)];
  proof.status = proof.failed_predicates.length === 0
    && proof.cases.length === 2
    && proof.cases.every((result) => result.status === "passed")
    ? "passed"
    : "blocked";
  writeJsonAtomically(resolvedOutput, proof);
  return { proof, output: resolvedOutput };
}

function parseCliArgs(argv) {
  const result = { repoRoot: process.cwd(), outputPath: null };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--output" && argv[index + 1]) {
      result.outputPath = argv[++index];
    } else if (argv[index] === "--repo" && argv[index + 1]) {
      result.repoRoot = argv[++index];
    } else {
      throw new Error(`unknown or incomplete argument: ${argv[index]}`);
    }
  }
  if (!result.outputPath) throw new Error("usage: node verify-object-fetch-isolation.mjs --output <proof.json> [--repo <root>]");
  return result;
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : null;
if (invokedPath === fileURLToPath(import.meta.url)) {
  try {
    const { proof, output } = buildFetchProof(parseCliArgs(process.argv.slice(2)));
    process.stdout.write(`${JSON.stringify({ status: proof.status, output, cases: proof.cases.length, failed_predicates: proof.failed_predicates }, null, 2)}\n`);
    if (proof.status !== "passed") process.exitCode = 1;
  } catch (error) {
    process.stderr.write(`${String(error)}\n`);
    process.exitCode = 2;
  }
}
