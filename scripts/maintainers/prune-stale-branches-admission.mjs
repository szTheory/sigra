#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, renameSync, readdirSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SCRIPT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const PHASE_DIR = ".planning/phases/245-branch-prune-local-and-remote";
const GIT_BIN = "/usr/bin/git";
const GIT_VERSION_PREFIX = "git version 2.50.1";
const GIT_SHA256 = "b8763cf250e607a778bb4603cecb5b90338814d0a3dfcba0d57b1de242f610e9";
const OID = /^[0-9a-f]{40}(?:[0-9a-f]{24})?$/;
const TYPES = new Set(["commit", "tree", "blob", "tag"]);
const SHELL_MUTATOR_PATHS = [
  "scripts/maintainers/prune-stale-branches.sh",
  "scripts/maintainers/repo-mutation-coordinator.sh",
  "scripts/maintainers/repo-mutation-reference-transaction",
];
const PINNED_RUNTIME_PATHS = [
  "scripts/maintainers/prune-stale-branches-admission.mjs",
  "scripts/maintainers/prune-stale-branches-current.mjs",
  "scripts/maintainers/prune-stale-branches-readiness.mjs",
  "scripts/maintainers/prune-stale-branches-pr-audit.mjs",
];
const EXECUTABLES = new Set(["spawn", "spawnSync", "execFile", "execFileSync", "execSync", "command"]);

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
  return command(GIT_BIN, ["-C", repo, ...args], options);
}

function sourceFiles(root, directory = "scripts") {
  const base = path.join(root, directory);
  if (!base.startsWith(`${root}${path.sep}`) || !path.isAbsolute(root)) return [];
  let entries;
  try { entries = readdirSync(base, { withFileTypes: true }); } catch { return []; }
  return entries.flatMap((entry) => {
    if (entry.name === "node_modules" || entry.name.startsWith(".")) return [];
    const relative = path.join(directory, entry.name);
    if (entry.isDirectory()) return sourceFiles(root, relative);
    if (!entry.isFile() || /\.test\.[^.]+$/.test(entry.name)) return [];
    if (!/\.(?:sh|bash|mjs|js)$/.test(entry.name) && entry.name !== "repo-mutation-reference-transaction") return [];
    return [relative];
  });
}

function stripShellComment(line) {
  let quote = "";
  let escaped = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (escaped) { escaped = false; continue; }
    if (quote === "'" && char !== "'") continue;
    if (quote === '"' && char !== '"' && char !== "\\") continue;
    if (char === "\\" && quote !== "'") { escaped = true; continue; }
    if ((char === "'" || char === '"') && (!quote || quote === char)) { quote = quote ? "" : char; continue; }
    if (!quote && char === "#") return line.slice(0, index);
  }
  return line;
}

function shellMutatorSites(source) {
  const mutation = /\b(?:update-ref|branch\s+-[dD]|worktree\s+(?:add|move|remove|prune|lock|unlock)|checkout\s+-[bB]|switch\s+-[cC])\b/;
  return source.split(/\r?\n/).flatMap((line, index) => {
    const code = stripShellComment(line);
    return /\bgit\b/.test(code) && mutation.test(code) ? [{ line: index + 1, source: line }] : [];
  });
}

function shellUsesPinnedGitFunction(line) {
  const code = stripShellComment(line);
  if (/(['"])?\/(?:[^\s/'"]+\/)*git\1?\s/.test(code)) return false;
  if (/(?:^|[;&|()\s])(?:command|env|exec|nohup|sudo)\s+(?:[^\s;&|()]+\s+)*git\s/.test(code)) return false;
  return /(?:^|[;&|()\s])git\s/.test(code);
}

function jsTokens(source) {
  const tokens = [];
  let index = 0;
  let previous = "";
  while (index < source.length) {
    const char = source[index];
    if (/\s/.test(char)) { index += 1; continue; }
    if (char === "/" && source[index + 1] === "/") {
      index = source.indexOf("\n", index + 2);
      if (index < 0) break;
      continue;
    }
    if (char === "/" && source[index + 1] === "*") {
      const end = source.indexOf("*/", index + 2);
      index = end < 0 ? source.length : end + 2;
      continue;
    }
    if (char === "/" && /^(?:=|\(|\[|\{|:|,|;|!|\?|&&|\|\||return|throw)$/.test(previous)) {
      index += 1;
      let escaped = false;
      while (index < source.length) {
        const current = source[index++];
        if (escaped) { escaped = false; continue; }
        if (current === "\\") { escaped = true; continue; }
        if (current === "/") break;
        if (current === "\n") break;
      }
      while (/[a-z]/i.test(source[index] ?? "")) index += 1;
      previous = "<regex>";
      continue;
    }
    if (char === "'" || char === '"' || char === "`") {
      const quote = char;
      let value = "";
      index += 1;
      let escaped = false;
      while (index < source.length) {
        const current = source[index++];
        if (escaped) { value += current; escaped = false; continue; }
        if (current === "\\") { escaped = true; continue; }
        if (current === quote) break;
        value += current;
      }
      tokens.push({ type: quote === "`" ? "template" : "string", value });
      previous = "<literal>";
      continue;
    }
    if (/[A-Za-z_$]/.test(char)) {
      const start = index++;
      while (/[A-Za-z0-9_$]/.test(source[index] ?? "")) index += 1;
      const value = source.slice(start, index);
      tokens.push({ type: "identifier", value });
      previous = value;
      continue;
    }
    tokens.push({ type: "punctuation", value: char });
    previous = char;
    index += 1;
  }
  return tokens;
}

function unpinnedJsGitCalls(source) {
  const tokens = jsTokens(source);
  const calls = [];
  for (let index = 0; index < tokens.length - 2; index += 1) {
    if (tokens[index].type !== "identifier" || !EXECUTABLES.has(tokens[index].value)) continue;
    if (tokens[index + 1].value !== "(" || tokens[index + 2].type !== "string" || tokens[index + 2].value !== "git") continue;
    calls.push(`${tokens[index].value}("git", ...)`);
  }
  return calls;
}

export function inspectMutationCoverage(root) {
  const absoluteRoot = path.resolve(root);
  const files = sourceFiles(absoluteRoot);
  const fileSet = new Set(files);
  const findings = [];
  const coordinatorPath = "scripts/maintainers/repo-mutation-coordinator.sh";
  const operatorPath = "scripts/maintainers/prune-stale-branches.sh";
  const coordinator = fileSet.has(coordinatorPath) ? readFileSync(path.join(absoluteRoot, coordinatorPath), "utf8") : "";
  const operator = fileSet.has(operatorPath) ? readFileSync(path.join(absoluteRoot, operatorPath), "utf8") : "";
  const coordinatorPinned = coordinator.includes('readonly SIGRA_COORDINATOR_GIT_PATH="/usr/bin/git"')
    && coordinator.includes(`readonly SIGRA_COORDINATOR_GIT_SHA256="${GIT_SHA256}"`)
    && coordinator.includes('"$SIGRA_COORDINATOR_GIT_PATH" "$@"')
    && coordinator.includes("sigra_coordinator_pin_git || return 126");
  if (!coordinatorPinned) findings.push(`${coordinatorPath}: pinned_git_wrapper_missing_or_changed`);
  const operatorPinned = operator.includes('source "${SCRIPT_ROOT}/scripts/maintainers/repo-mutation-coordinator.sh"')
    && operator.includes('sigra_coordinator_pin_git || fail')
    && operator.includes('sigra_coordinator_acquire "$REPO"')
    && operator.includes(') acquire_lock ;;');
  if (!operatorPinned) {
    findings.push(`${operatorPath}: shared_pinned_git_wrapper_not_sourced`);
  }
  for (const relativePath of PINNED_RUNTIME_PATHS) {
    if (!fileSet.has(relativePath)) { findings.push(`${relativePath}: runtime_entrypoint_missing`); continue; }
    const source = readFileSync(path.join(absoluteRoot, relativePath), "utf8");
    if (!source.includes(`const GIT_BIN = "${GIT_BIN}";`)) findings.push(`${relativePath}: exact_git_path_pin_missing`);
    for (const call of unpinnedJsGitCalls(source)) findings.push(`${relativePath}: ${call}`);
  }
  for (const relativePath of files) {
    if (!/\.(?:sh|bash)$/.test(relativePath) && relativePath !== "scripts/maintainers/repo-mutation-reference-transaction") continue;
    const source = readFileSync(path.join(absoluteRoot, relativePath), "utf8");
    for (const site of shellMutatorSites(source)) {
      const disposableProbe = relativePath === coordinatorPath && site.source.includes("DISPOSABLE_PROBE_MUTATION");
      const coveredOperatorSite = relativePath === operatorPath && coordinatorPinned && operatorPinned
        && shellUsesPinnedGitFunction(site.source);
      const coveredCoordinatorSite = relativePath === coordinatorPath && coordinatorPinned && disposableProbe;
      if (!coveredOperatorSite && !coveredCoordinatorSite) findings.push(`${relativePath}:${site.line}: uncoordinated Git ref/worktree mutator`);
    }
    if ((relativePath === operatorPath || relativePath === coordinatorPath) && /\bcommand\s+-v\s+git\b/.test(source)) {
      findings.push(`${relativePath}: ambient_git_path_lookup`);
    }
  }
  for (const relativePath of SHELL_MUTATOR_PATHS) {
    if (!fileSet.has(relativePath)) findings.push(`${relativePath}: mutation_entrypoint_missing`);
  }
  return [...new Set(findings)];
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
  const raw = command(GIT_BIN, ["-C", repo, "show", `${commit}:${relativePath}`], { encoding: null });
  const recalculated = command(GIT_BIN, ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw }).trim();
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
  if (options.admission) specs.push(["initial_admission", options.currentContractCommit, options.admission]);
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
    if (command(GIT_BIN, ["check-ref-format", ref]).trim() !== "") fail("allowlist_ref_invalid", ref);
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
    const resolved = spawnSync(GIT_BIN, ["-C", repo, "rev-parse", "--verify", `${source}^{commit}`], { encoding: "utf8" });
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
  const ambientGitPath = resolved.status === 0 ? resolved.stdout.trim() : null;
  let candidate = null;
  let pinnedGitVerified = false;
  try {
    const resolvedPath = realpathSync(GIT_BIN);
    const digest = createHash("sha256").update(readFileSync(GIT_BIN)).digest("hex");
    const version = command(GIT_BIN, ["--version"]).trim();
    pinnedGitVerified = resolvedPath === GIT_BIN && version.startsWith(GIT_VERSION_PREFIX) && digest === GIT_SHA256;
    candidate = { path: GIT_BIN, resolved_path: resolvedPath, version, sha256: digest };
  } catch {
    candidate = null;
  }
  if (!pinnedGitVerified) reasons.push({ code: "pinned_git_identity_unverified" });
  const coverageFindings = inspectMutationCoverage(SCRIPT_ROOT);
  if (coverageFindings.length) reasons.push({ code: "mutator_coverage_failed", findings: coverageFindings });
  return {
    active_git_path: ambientGitPath,
    candidate_git: candidate,
    pinned_git_verified: pinnedGitVerified,
    operator_mutators_pinned: pinnedGitVerified && coverageFindings.length === 0,
    mutator_coverage: { status: coverageFindings.length ? "blocked" : "passed", findings: coverageFindings },
  };
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
  const actual = spawnSync(GIT_BIN, ["-C", repo, "for-each-ref", `--format=%(objectname)%09%(objecttype)`, candidateRef], { encoding: "utf8" });
  if (actual.status !== 0 || actual.stdout.trim() !== `${candidate.oid}\t${candidate.type}`) reasons.push({ code: `candidate_identity_changed:${candidateRef}` });
  if (candidate.type !== "commit") reasons.push({ code: `candidate_not_commit:${candidateRef}` });
  const worktrees = worktreeFingerprint(repo);
  if (worktrees.some((line) => line === `branch ${candidateRef}`)) reasons.push({ code: `candidate_attached_worktree:${candidateRef}` });
  const head = spawnSync(GIT_BIN, ["-C", repo, "symbolic-ref", "-q", "HEAD"], { encoding: "utf8" });
  const target = head.status === 0 ? head.stdout.trim() : null;
  const targetOid = target ? git(repo, ["rev-parse", "--verify", target]).trim() : null;
  if (!target || !target.startsWith("refs/heads/") || !targetOid) reasons.push({ code: "merge_target_not_stable_symbolic_branch" });
  else {
    const ancestor = spawnSync(GIT_BIN, ["-C", repo, "merge-base", "--is-ancestor", candidate.oid, targetOid]);
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
  const allowPin = (contract?.pinned_inputs ?? []).find((row) => row.commit === inputs.allowlist.commit && row.path === inputs.allowlist.path)
    ?? (inputs.allowlist.commit === inputs.current_contract.commit ? contract?.evidence_transition?.precommit_artifacts?.[inputs.allowlist.path] : null);
  if (!allowPin || allowPin.blob !== inputs.allowlist.blob || allowPin.sha256 !== inputs.allowlist.sha256) reasons.push({ code: "allowlist_not_pinned_by_current_contract" });
  if (inputs.initial_admission) {
    const receipt = JSON.parse(inputs.initial_admission.raw.toString("utf8"));
    const receiptPin = contract?.evidence_transition?.precommit_artifacts?.[inputs.initial_admission.path];
    if (!receiptPin || receiptPin.blob !== inputs.initial_admission.blob || receiptPin.sha256 !== inputs.initial_admission.sha256) {
      reasons.push({ code: "initial_admission_not_pinned_by_current_contract" });
    }
    if (receipt?.schema_version !== 1 || receipt?.status !== "prepared" || receipt?.production_mutations !== 0) {
      reasons.push({ code: "initial_admission_receipt_invalid_or_not_read_only" });
    }
  }

  // Readiness is the earliest production gate. In particular, do not contact
  // GitHub or inspect coordinator state after the pinned D-01 source is known
  // to be absent: the operator must fail before any mutation setup begins.
  checkReadiness(root, inputs.readiness, reasons);

  const currentArgs = [path.join(SCRIPT_ROOT, "scripts/maintainers/prune-stale-branches-current.mjs"), "verify", "--repo", root,
    "--contract-commit", inputs.current_contract.commit, "--contract", inputs.current_contract.path,
    "--allowlist-commit", inputs.allowlist.commit, "--allowlist", inputs.allowlist.path,
    "--verify-allowlist",
    "--stage", options.stage === "boundary" ? "boundary" : "before"];
  const missingReadinessSource = reasons.some((row) => row.code.startsWith("d01_readiness_source_commit_unavailable:"));
  let evidenceTransition = null;
  if (!missingReadinessSource) {
    if (options.sourceFixture) currentArgs.push("--source-fixture", safePath(options.sourceFixture));
    const current = spawnSync("node", currentArgs, { cwd: SCRIPT_ROOT, encoding: "utf8" });
    if (current.status !== 0) reasons.push({ code: `current_contract_verification_failed:${(current.stderr || current.stdout).trim().slice(0, 240)}` });
    else if (contract?.evidence_transition) {
      const marker = current.stdout.split(/\r?\n/).find((line) => line.startsWith("EVIDENCE_TRANSITION_JSON="));
      try { evidenceTransition = marker ? JSON.parse(marker.slice("EVIDENCE_TRANSITION_JSON=".length)) : null; } catch { evidenceTransition = null; }
      if (!evidenceTransition || evidenceTransition.contract_commit !== inputs.current_contract.commit) {
        reasons.push({ code: "current_contract_evidence_transition_receipt_missing_or_mismatched" });
      }
    }
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
    evidence_transition: evidenceTransition,
    inputs: Object.fromEntries(Object.entries(inputs).map(([key, row]) => [key, { commit: row.commit, path: row.path, blob: row.blob, sha256: row.sha256 }])),
    initial_admission: inputs.initial_admission ? { commit: inputs.initial_admission.commit, path: inputs.initial_admission.path, blob: inputs.initial_admission.blob, sha256: inputs.initial_admission.sha256 } : null,
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
  if (action === "coverage") {
    if (argv.length !== 2 || argv[0] !== "--repo") fail("usage", "coverage --repo PATH");
    return { action, repo: argv[1] };
  }
  if (!new Set(["capture", "verify"]).has(action)) fail("usage", "<capture|verify> --repo PATH ...");
  const options = { action, stage: "admission" };
  const seen = new Set();
  const names = new Map([
    ["--repo", "repo"], ["--current-contract-commit", "currentContractCommit"], ["--current-contract", "currentContract"],
    ["--snapshot-commit", "snapshotCommit"], ["--snapshot", "snapshot"], ["--origin-snapshot-commit", "originSnapshotCommit"], ["--origin-snapshot", "originSnapshot"],
    ["--allowlist-commit", "allowlistCommit"], ["--allowlist", "allowlist"], ["--readiness-commit", "readinessCommit"], ["--readiness", "readiness"],
    ["--source-fixture", "sourceFixture"], ["--candidate-ref", "candidateRef"], ["--output", "output"], ["--stage", "stage"],
    ["--admission", "admission"],
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
  if (action === "verify" && options.admission && !options.currentContractCommit) {
    const admissionPath = safePath(options.admission);
    let receipt;
    try { receipt = JSON.parse(readFileSync(path.resolve(options.repo, admissionPath), "utf8")); }
    catch { fail("initial_admission_receipt_unreadable", admissionPath); }
    const source = receipt?.verify_inputs;
    if (!source || typeof source !== "object") fail("initial_admission_verify_inputs_missing");
    options.currentContract = options.currentContract ?? safePath(source.current_contract?.path);
    options.currentContractCommit = source.current_contract?.commit === "self"
      ? git(options.repo, ["log", "-1", "--format=%H", "--", options.currentContract]).trim()
      : source.current_contract?.commit;
    options.snapshot = options.snapshot ?? safePath(source.local_snapshot?.path);
    options.snapshotCommit = options.snapshotCommit ?? source.local_snapshot?.commit;
    options.originSnapshot = options.originSnapshot ?? safePath(source.origin_snapshot?.path);
    options.originSnapshotCommit = options.originSnapshotCommit ?? source.origin_snapshot?.commit;
    options.allowlist = options.allowlist ?? safePath(source.allowlist?.path);
    options.allowlistCommit = options.allowlistCommit ?? (source.allowlist?.commit === "current_contract"
      ? options.currentContractCommit : source.allowlist?.commit);
    options.readiness = options.readiness ?? safePath(source.readiness?.path);
    options.readinessCommit = options.readinessCommit ?? source.readiness?.commit;
    options.sourceFixture = options.sourceFixture ?? (source.source_fixture ? safePath(source.source_fixture) : undefined);
    options.candidateRef = options.candidateRef ?? source.candidate_ref;
  }
  return options;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.action === "coverage") {
      const findings = inspectMutationCoverage(options.repo);
      process.stdout.write(`${JSON.stringify({ status: findings.length ? "blocked" : "passed", findings }, null, 2)}\n`);
      if (findings.length) process.exitCode = 2;
    } else {
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
    }
  } catch (error) {
    process.stderr.write(`prune-stale-branches-admission: FAIL: ${error.message}\n`);
    process.exitCode = 2;
  }
}
