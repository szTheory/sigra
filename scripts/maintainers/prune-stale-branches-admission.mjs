#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, renameSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SCRIPT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const PHASE_DIR = ".planning/phases/245-branch-prune-local-and-remote";
const OID = /^[0-9a-f]{40}(?:[0-9a-f]{24})?$/;
const TYPES = new Set(["commit", "tree", "blob", "tag"]);
const MUTATOR_PATHS = [
  "scripts/maintainers/prune-stale-branches.sh",
  "scripts/maintainers/repo-mutation-coordinator.sh",
  "scripts/maintainers/repo-mutation-reference-transaction",
];

function fail(code, detail = "") {
  throw new Error(detail ? `${code}:${detail}` : code);
}

function command(program, args, { cwd, input, encoding = "utf8", maxBuffer = 32 * 1024 * 1024 } = {}) {
  const result = spawnSync(program, args, { cwd, input, encoding, maxBuffer });
  if (result.error || result.status !== 0) {
    const message = (result.stderr || result.stdout || result.error?.message || "").toString().trim();
    fail("command_failed", `${program} ${args.join(" ")}: ${message}`);
  }
  return result.stdout;
}

function git(repo, args, options = {}) {
  return command("git", ["-C", repo, ...args], options);
}

function safePath(value) {
  if (typeof value !== "string" || !value || value.startsWith("/") || value.includes("..") || value.includes("\n") || value.includes(":")) {
    fail("input_path_invalid", value ?? "");
  }
  return value;
}

function readPinned(repo, commit, relativePath, label) {
  safePath(relativePath);
  if (!OID.test(commit ?? "")) fail(`${label}_commit_invalid`);
  try { git(repo, ["cat-file", "-e", `${commit}^{commit}`]); } catch { fail(`${label}_commit_unavailable`, commit); }
  let blob;
  try { blob = git(repo, ["rev-parse", `${commit}:${relativePath}`]).trim(); } catch { fail(`${label}_path_unavailable`, relativePath); }
  const raw = command("git", ["-C", repo, "show", `${commit}:${relativePath}`], { encoding: null });
  const recalculated = command("git", ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw }).trim();
  if (blob !== recalculated) fail(`${label}_blob_mismatch`, relativePath);
  return { raw, blob, sha256: createHash("sha256").update(raw).digest("hex") };
}

function refsFingerprint(repo) {
  return git(repo, ["for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)%09%(symref)"])
    .trimEnd().split(/\r?\n/).filter(Boolean).sort();
}

function worktreeFingerprint(repo) {
  const rows = git(repo, ["worktree", "list", "--porcelain"]).trimEnd();
  return rows ? rows.split(/\r?\n/).filter(Boolean) : [];
}

function configFingerprint(repo) {
  let bytes;
  try { bytes = git(repo, ["config", "--local", "--list", "--null"], { encoding: null }); }
  catch { bytes = Buffer.alloc(0); }
  return createHash("sha256").update(bytes).digest("hex");
}

function committedInputSet(options) {
  const specs = [
    ["current_contract", options.currentContractCommit, options.currentContract],
    ["local_snapshot", options.snapshotCommit, options.snapshot],
    ["origin_snapshot", options.originSnapshotCommit, options.originSnapshot],
    ["allowlist", options.allowlistCommit, options.allowlist],
    ["readiness", options.readinessCommit, options.readiness],
  ];
  const inputs = {};
  for (const [name, commit, file] of specs) {
    if (!commit || !file) fail(`${name}_commit_path_required`);
    inputs[name] = { commit, path: safePath(file), ...readPinned(options.repo, commit, file, name) };
  }
  return inputs;
}

function parseAllowlist(bytes) {
  const lines = bytes.toString("utf8").replace(/\r/g, "").trimEnd().split("\n");
  if (lines.length < 2 || lines[0] !== "side\tref\toid\ttype\treason") fail("allowlist_header_invalid");
  const rows = [];
  const seen = new Set();
  for (const line of lines.slice(1)) {
    const [side, ref, oid, type, reason, ...extra] = line.split("\t");
    if (extra.length || !["local", "remote", "tracking", "safety-publish"].includes(side) || !ref?.startsWith("refs/") || !OID.test(oid ?? "") || !TYPES.has(type) || !reason?.trim()) fail("allowlist_row_invalid");
    if (seen.has(`${side}\0${ref}`)) fail("allowlist_duplicate_row", ref);
    if (command("git", ["check-ref-format", ref]).trim() !== "") fail("allowlist_ref_invalid", ref);
    seen.add(`${side}\0${ref}`);
    rows.push({ side, ref, oid, type, reason });
  }
  if (!rows.length) fail("allowlist_empty");
  return rows;
}

function checkReadiness(repo, input, reasons) {
  let receipt;
  try { receipt = JSON.parse(input.raw.toString("utf8")); } catch { fail("readiness_json_invalid"); }
  if (receipt?.status !== "ready") reasons.push({ code: "d01_readiness_not_ready" });
  const source = receipt?.source_commit;
  if (!OID.test(source ?? "")) reasons.push({ code: "d01_readiness_source_commit_invalid" });
  else {
    const resolved = spawnSync("git", ["-C", repo, "rev-parse", "--verify", `${source}^{commit}`], { encoding: "utf8" });
    if (resolved.status !== 0 || resolved.stdout.trim() !== source) {
      reasons.push({ code: `d01_readiness_source_commit_unavailable:${source}` });
    } else {
      const verified = spawnSync("node", [path.join(SCRIPT_ROOT, "scripts/maintainers/prune-stale-branches-readiness.mjs"), "verify", "--repo", repo, "--artifact", input.path, "--artifact-commit", input.commit], { encoding: "utf8" });
      if (verified.status !== 0) reasons.push({ code: `d01_readiness_source_verification_failed:${(verified.stderr || verified.stdout).trim().slice(0, 240)}` });
    }
  }
}

function checkRuntime(reasons) {
  const resolved = spawnSync("sh", ["-lc", "command -v git"], { encoding: "utf8" });
  const gitPath = resolved.status === 0 ? resolved.stdout.trim() : null;
  let candidate = null;
  try {
    const candidatePath = "/usr/bin/git";
    const digest = createHash("sha256").update(readFileSync(candidatePath)).digest("hex");
    const version = command(candidatePath, ["--version"]).trim();
    candidate = { path: candidatePath, version, sha256: digest };
  } catch {
    candidate = null;
  }
  const source = readFileSync(path.join(SCRIPT_ROOT, MUTATOR_PATHS[0]), "utf8");
  const hasAmbientMutators = /(^|[;&|()\s])git\s+-C\s+"\$REPO"\s+(?:update-ref|push|worktree|branch)\b/m.test(source);
  if (!gitPath || hasAmbientMutators) reasons.push({ code: `unproved_git_mutator_runtime:${MUTATOR_PATHS[0]}` });
  return { active_git_path: gitPath, candidate_git: candidate, operator_mutators_pinned: !hasAmbientMutators };
}

function checkCoordinator(repo, stage, reasons) {
  if (stage === "admission") return { stage, installed: false, checked: false };
  const verify = spawnSync("bash", [path.join(SCRIPT_ROOT, "scripts/maintainers/repo-mutation-coordinator.sh"), "verify", "--repo", repo], { encoding: "utf8" });
  const held = process.env.SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN && process.env.SIGRA_COORDINATOR_HELD === "1";
  if (verify.status !== 0 || !held) reasons.push({ code: `coordinator_not_proven_under_lock:${(verify.stderr || verify.stdout).trim().slice(0, 240)}` });
  return { stage, installed: verify.status === 0, held: Boolean(held) };
}

function checkCandidate(repo, rows, candidateRef, reasons) {
  if (!candidateRef) fail("candidate_ref_required");
  const candidate = rows.find((row) => row.side === "local" && row.ref === candidateRef);
  if (!candidate) {
    reasons.push({ code: `candidate_not_in_exact_allowlist:${candidateRef}` });
    return null;
  }
  const actual = spawnSync("git", ["-C", repo, "for-each-ref", `--format=%(objectname)%09%(objecttype)`, candidateRef], { encoding: "utf8" });
  if (actual.status !== 0 || actual.stdout.trim() !== `${candidate.oid}\t${candidate.type}`) reasons.push({ code: `candidate_identity_changed:${candidateRef}` });
  if (candidate.type !== "commit") reasons.push({ code: `candidate_not_commit:${candidateRef}` });
  const worktrees = worktreeFingerprint(repo);
  if (worktrees.some((line) => line === `branch ${candidateRef}`)) reasons.push({ code: `candidate_attached_worktree:${candidateRef}` });
  const head = spawnSync("git", ["-C", repo, "symbolic-ref", "-q", "HEAD"], { encoding: "utf8" });
  const target = head.status === 0 ? head.stdout.trim() : null;
  const targetOid = target ? git(repo, ["rev-parse", "--verify", target]).trim() : null;
  if (!target || !target.startsWith("refs/heads/") || !targetOid) reasons.push({ code: "merge_target_not_stable_symbolic_branch" });
  else {
    const ancestor = spawnSync("git", ["-C", repo, "merge-base", "--is-ancestor", candidate.oid, targetOid]);
    if (ancestor.status !== 0) reasons.push({ code: `candidate_not_merged_into_stable_target:${candidateRef}` });
  }
  return candidate;
}

function evaluate(options) {
  const repo = path.resolve(options.repo);
  const root = git(repo, ["rev-parse", "--show-toplevel"]).trim();
  const before = { refs: refsFingerprint(root), worktrees: worktreeFingerprint(root), config: configFingerprint(root) };
  const reasons = [];
  const inputs = committedInputSet({ ...options, repo: root });
  const contract = JSON.parse(inputs.current_contract.raw.toString("utf8"));
  if (contract?.schema_version !== 1) reasons.push({ code: "current_contract_schema_invalid" });
  const allowRows = parseAllowlist(inputs.allowlist.raw);
  const allowPin = (contract?.pinned_inputs ?? []).find((row) => row.commit === inputs.allowlist.commit && row.path === inputs.allowlist.path);
  if (!allowPin || allowPin.blob !== inputs.allowlist.blob || allowPin.sha256 !== inputs.allowlist.sha256) reasons.push({ code: "allowlist_not_pinned_by_current_contract" });

  // Readiness is the earliest production gate. In particular, do not contact
  // GitHub or inspect coordinator state after the pinned D-01 source is known
  // to be absent: the operator must fail before any mutation setup begins.
  checkReadiness(root, inputs.readiness, reasons);

  const currentArgs = [path.join(SCRIPT_ROOT, "scripts/maintainers/prune-stale-branches-current.mjs"), "verify", "--repo", root,
    "--contract-commit", inputs.current_contract.commit, "--contract", inputs.current_contract.path,
    "--allowlist-commit", inputs.allowlist.commit, "--allowlist", inputs.allowlist.path,
    "--stage", options.stage === "boundary" ? "boundary" : "before"];
  const missingReadinessSource = reasons.some((row) => row.code.startsWith("d01_readiness_source_commit_unavailable:"));
  if (!missingReadinessSource) {
    if (options.sourceFixture) currentArgs.push("--source-fixture", safePath(options.sourceFixture));
    const current = spawnSync("node", currentArgs, { cwd: SCRIPT_ROOT, encoding: "utf8" });
    if (current.status !== 0) reasons.push({ code: `current_contract_verification_failed:${(current.stderr || current.stdout).trim().slice(0, 240)}` });
  }

  const runtime = checkRuntime(reasons);
  checkCandidate(root, allowRows, options.candidateRef, reasons);
  const coordinator = checkCoordinator(root, options.stage, reasons);
  const after = { refs: refsFingerprint(root), worktrees: worktreeFingerprint(root), config: configFingerprint(root) };
  const equal = JSON.stringify(before) === JSON.stringify(after);
  if (!equal) reasons.push({ code: "admission_preflight_changed_repository_state" });
  return {
    schema_version: 1,
    repository_root: root,
    captured_at: new Date().toISOString(),
    stage: options.stage,
    status: reasons.length ? "blocked" : "admitted",
    current_contract: { commit: inputs.current_contract.commit, path: inputs.current_contract.path, blob: inputs.current_contract.blob, sha256: inputs.current_contract.sha256 },
    inputs: Object.fromEntries(Object.entries(inputs).map(([key, row]) => [key, { commit: row.commit, path: row.path, blob: row.blob, sha256: row.sha256 }])),
    candidate_ref: options.candidateRef,
    candidate: allowRows.find((row) => row.side === "local" && row.ref === options.candidateRef) ?? null,
    runtime,
    coordinator,
    blocked_reasons: reasons,
    no_mutation: { refs_before: before.refs, refs_after: after.refs, worktrees_before: before.worktrees, worktrees_after: after.worktrees, config_before: before.config, config_after: after.config, equal },
  };
}

function parseArgs(argv) {
  const action = argv.shift();
  if (!new Set(["capture", "verify"]).has(action)) fail("usage", "<capture|verify> --repo PATH ...");
  const options = { action, stage: "admission" };
  const seen = new Set();
  const names = new Map([
    ["--repo", "repo"], ["--current-contract-commit", "currentContractCommit"], ["--current-contract", "currentContract"],
    ["--snapshot-commit", "snapshotCommit"], ["--snapshot", "snapshot"], ["--origin-snapshot-commit", "originSnapshotCommit"], ["--origin-snapshot", "originSnapshot"],
    ["--allowlist-commit", "allowlistCommit"], ["--allowlist", "allowlist"], ["--readiness-commit", "readinessCommit"], ["--readiness", "readiness"],
    ["--source-fixture", "sourceFixture"], ["--candidate-ref", "candidateRef"], ["--output", "output"], ["--stage", "stage"],
  ]);
  while (argv.length) {
    const key = argv.shift();
    const name = names.get(key);
    if (!name || !argv.length) fail("argument_invalid_or_missing_value", key);
    if (seen.has(name)) fail("argument_duplicate", key);
    seen.add(name);
    options[name] = argv.shift();
  }
  if (!options.repo) fail("repo_required");
  if (action === "capture" && !options.output) fail("output_required");
  if (action === "verify" && !new Set(["admission", "boundary", "after"]).has(options.stage)) fail("stage_invalid");
  return options;
}

try {
  const options = parseArgs(process.argv.slice(2));
  const receipt = evaluate(options);
  const bytes = `${JSON.stringify(receipt, null, 2)}\n`;
  if (options.action === "capture") {
    const output = path.resolve(options.output);
    const temp = `${output}.tmp-${process.pid}`;
    writeFileSync(temp, bytes, { flag: "wx", mode: 0o600 });
    renameSync(temp, output);
  }
  process.stdout.write(bytes);
  if (receipt.status !== "admitted") process.exitCode = 2;
} catch (error) {
  process.stderr.write(`prune-stale-branches-admission: FAIL: ${error.message}\n`);
  process.exitCode = 2;
}
