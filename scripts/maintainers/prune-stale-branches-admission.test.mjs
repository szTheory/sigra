import assert from "node:assert/strict";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { inspectMutationCoverage } from "./prune-stale-branches-admission.mjs";

const ROOT = process.cwd();
const ADMISSION = "scripts/maintainers/prune-stale-branches-admission.mjs";
const CURRENT = "scripts/maintainers/prune-stale-branches-current.mjs";
const OPERATOR = "scripts/maintainers/prune-stale-branches.sh";
const PINNED_READINESS_SOURCE = "7257f232a38591b0044f1b929bba1fc2e9fa83da";

function git(repo, ...args) {
  const result = spawnSync("git", ["-C", repo, ...args], { encoding: "utf8" });
  assert.equal(result.status, 0, `git ${args.join(" ")}\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  return result.stdout.trim();
}

function run(command, args, options = {}) {
  return spawnSync(command, args, { cwd: ROOT, encoding: "utf8", ...options });
}

function setupFixture() {
  const temp = mkdtempSync(join(tmpdir(), "sigra-prune-admission-"));
  const repo = join(temp, "repo");
  const bare = join(temp, "origin.git");
  const phase = ".planning/phases/245-branch-prune-local-and-remote";
  const paths = {
    allowlist: `${phase}/245-BRANCH-DELETE-ALLOWLIST.tsv`,
    readiness: `${phase}/245-READINESS.json`,
    snapshot: `${phase}/245-LOCAL-REFS.tsv`,
    origin: `${phase}/245-ORIGIN-REFS.tsv`,
    fixture: `${phase}/github-fixture.json`,
    contract: `${phase}/245-CURRENT-CONTRACT.json`,
    candidates: `${phase}/245-CANDIDATES.json`,
    admission: `${phase}/245-ADMISSION.json`,
    result: `${phase}/245-RESULT.json`,
    postLocal: `${phase}/245-POST-LOCAL-REFS.tsv`,
    summary: `${phase}/245-SUMMARY.md`,
  };
  run("git", ["init", "-q", "--initial-branch=main", repo]);
  git(repo, "config", "user.name", "GSD Admission Fixture");
  git(repo, "config", "user.email", "gsd-admission@example.invalid");
  git(repo, "config", "gc.auto", "0");
  git(repo, "config", "maintenance.auto", "false");
  writeFileSync(join(repo, "root.txt"), "fixture root\n");
  git(repo, "add", "root.txt");
  git(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture root");
  const rootOid = git(repo, "rev-parse", "HEAD");
  git(repo, "branch", "stale/merged", rootOid);
  run("git", ["init", "-q", "--bare", "--initial-branch=main", bare]);
  git(repo, "remote", "add", "origin", bare);
  git(repo, "push", "-q", "origin", "HEAD:refs/heads/main");
  git(repo, "fetch", "-q", "origin");
  git(repo, "remote", "set-head", "origin", "main");
  const fixtureDir = join(repo, phase);
  run("mkdir", ["-p", fixtureDir]);
  writeFileSync(join(repo, paths.allowlist), `side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t${rootOid}\tcommit\tmerged fixture candidate\n`);
  writeFileSync(join(repo, paths.readiness), readFileSync(join(ROOT, phase, "245-READINESS.json")));
  writeFileSync(join(repo, paths.fixture), JSON.stringify({ cliPulls: [], pages: [[]] }));
  const allowlistCommit = git(repo, "rev-parse", "HEAD");
  git(repo, "add", paths.allowlist, paths.readiness, paths.fixture);
  git(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture source inputs");
  const inputCommit = git(repo, "rev-parse", "HEAD");

  const local = run("bash", [OPERATOR, "capture-local", "--repo", repo, "--output", join(repo, paths.snapshot)]);
  assert.equal(local.status, 0, `${local.stdout ?? ""}${local.stderr ?? ""}`);
  const originOid = git(repo, "rev-parse", "refs/remotes/origin/main");
  writeFileSync(join(repo, paths.origin), `refname\toid\ttype\tpeeled_oid\tpeeled_type\tsymref_target\nrefs/heads/main\t${originOid}\tcommit\t-\t-\t-\nrefs/remotes/origin/HEAD\t${originOid}\tcommit\t-\t-\trefs/heads/main\n`);
  writeFileSync(join(repo, paths.contract), "{}\n");
  git(repo, "add", paths.snapshot, paths.origin, paths.contract);
  git(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture inventories");
  const snapshotCommit = git(repo, "rev-parse", "HEAD");

  writeFileSync(join(repo, paths.allowlist), `side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t${rootOid}\tcommit\tcurrent contract fixture candidate\n`);
  writeFileSync(join(repo, paths.candidates), JSON.stringify({ schema_version: 1, rows: [{ ref: "refs/heads/stale/merged", classification: "eligible" }] }, null, 2) + "\n");
  writeFileSync(join(repo, paths.admission), JSON.stringify({
    schema_version: 1,
    status: "prepared",
    production_mutations: 0,
    candidate_path: paths.candidates,
    allowlist_path: paths.allowlist,
    verify_inputs: {
      current_contract: { commit: "self", path: paths.contract },
      local_snapshot: { commit: snapshotCommit, path: paths.snapshot },
      origin_snapshot: { commit: snapshotCommit, path: paths.origin },
      allowlist: { commit: "current_contract", path: paths.allowlist },
      readiness: { commit: inputCommit, path: paths.readiness },
      source_fixture: paths.fixture,
      candidate_ref: "refs/heads/stale/merged",
    },
  }, null, 2) + "\n");

  const current = run("node", [CURRENT, "capture", "--repo", repo, "--output", join(repo, paths.contract), "--source-fixture", paths.fixture,
    "--pin-input", `${inputCommit}:${paths.allowlist}`,
    "--contract-evidence-path", paths.candidates,
    "--contract-evidence-path", paths.allowlist,
    "--contract-evidence-path", paths.admission,
    "--final-blocked-path", paths.result,
    "--final-blocked-path", paths.postLocal,
    "--final-passed-path", paths.result,
    "--final-passed-path", paths.postLocal,
    "--final-passed-path", paths.summary,
    "--result-path", paths.result,
  ]);
  assert.equal(current.status, 0, `${current.stdout ?? ""}${current.stderr ?? ""}`);
  const capturedContract = JSON.parse(readFileSync(join(repo, paths.contract), "utf8"));
  assert.equal(capturedContract.evidence_transition.contract_paths.length, 5);
  git(repo, "add", paths.contract, `${paths.contract}.sha256`, paths.candidates, paths.allowlist, paths.admission);
  git(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture current contract");
  const contractCommit = git(repo, "rev-parse", "HEAD");
  return { temp, repo, paths, inputCommit, allowlistCommit, snapshotCommit, contractCommit, rootOid };
}

function admissionArgs(fixture) {
  return [
    "--repo", fixture.repo,
    "--current-contract-commit", fixture.contractCommit,
    "--current-contract", fixture.paths.contract,
    "--snapshot-commit", fixture.snapshotCommit,
    "--snapshot", fixture.paths.snapshot,
    "--origin-snapshot-commit", fixture.snapshotCommit,
    "--origin-snapshot", fixture.paths.origin,
    "--allowlist-commit", fixture.contractCommit,
    "--allowlist", fixture.paths.allowlist,
    "--readiness-commit", fixture.inputCommit,
    "--readiness", fixture.paths.readiness,
    "--source-fixture", fixture.paths.fixture,
    "--admission", fixture.paths.admission,
    "--candidate-ref", "refs/heads/stale/merged",
  ];
}

function snapshotState(repo) {
  const hooksPath = spawnSync("git", ["-C", repo, "config", "--local", "--get", "core.hooksPath"], { encoding: "utf8" });
  return {
    refs: git(repo, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"),
    worktrees: git(repo, "worktree", "list", "--porcelain"),
    hooksPath: hooksPath.status === 0 ? hooksPath.stdout.trim() : null,
  };
}

test("mutator inventory ignores scanner regex text but rejects an executable rogue mutator", () => {
  const sourceRoot = mkdtempSync(join(tmpdir(), "sigra-prune-coverage-"));
  try {
    mkdirSync(join(sourceRoot, "scripts"), { recursive: true });
    cpSync(join(ROOT, "scripts"), join(sourceRoot, "scripts"), { recursive: true });
    const admissionSource = join(sourceRoot, ADMISSION);
    writeFileSync(admissionSource, `${readFileSync(admissionSource, "utf8")}\nconst scannerPatternFixture = /git\\s+-C\\s+"\\$REPO"\\s+(?:update-ref|push|worktree|branch)/;\n`);
    assert.deepEqual(inspectMutationCoverage(sourceRoot), [], "scanner pattern text must not be treated as an executable Git call");

    const operator = join(sourceRoot, "scripts/maintainers/prune-stale-branches.sh");
    const operatorSource = readFileSync(operator, "utf8");
    writeFileSync(operator, `${operatorSource}\n/usr/bin/git update-ref refs/heads/unpinned HEAD\n`);
    assert.ok(inspectMutationCoverage(sourceRoot).some((finding) => finding.includes("prune-stale-branches.sh") && finding.includes("uncoordinated")),
      "an absolute-path Git mutator must not inherit the operator's wrapper coverage");
    writeFileSync(operator, `${operatorSource}\nenv git update-ref refs/heads/unpinned HEAD\n`);
    assert.ok(inspectMutationCoverage(sourceRoot).some((finding) => finding.includes("prune-stale-branches.sh") && finding.includes("uncoordinated")),
      "a PATH-resolved Git mutator must not inherit the operator's wrapper coverage");

    const rogue = join(sourceRoot, "scripts/maintainers/rogue-mutator.sh");
    writeFileSync(rogue, '#!/usr/bin/env bash\ngit -C "$REPO" update-ref refs/heads/rogue deadbeef\n');
    const findings = inspectMutationCoverage(sourceRoot);
    assert.ok(findings.some((finding) => finding.includes("rogue-mutator.sh") && finding.includes("uncoordinated")), findings.join("\n"));
  } finally {
    rmSync(sourceRoot, { recursive: true, force: true });
  }
});

test("admission blocks missing source-backed D-01 before coordinator install or ref mutation", () => {
  const fixture = setupFixture();
  try {
    const before = snapshotState(fixture.repo);
    const receiptPath = join(fixture.temp, "admission.json");
    const captured = run("node", [ADMISSION, "capture", ...admissionArgs(fixture), "--output", receiptPath]);
    assert.notEqual(captured.status, 0, "missing D-01 source must block production local admission");
    assert.ok(existsSync(receiptPath), "capture must persist a blocked admission receipt before returning its blocker");
    const receipt = JSON.parse(readFileSync(receiptPath, "utf8"));
    assert.equal(receipt.status, "blocked");
    assert.equal(receipt.initial_admission.path, fixture.paths.admission);
    assert.equal(receipt.initial_admission.commit, fixture.contractCommit);
    assert.ok(receipt.blocked_reasons.some((row) => row.code.startsWith(`d01_readiness_source_commit_unavailable:${PINNED_READINESS_SOURCE}`)));
    assert.ok(!receipt.blocked_reasons.some((row) => row.code === "allowlist_not_pinned_by_current_contract"));
    assert.ok(!receipt.blocked_reasons.some((row) => row.code === "initial_admission_not_pinned_by_current_contract"));
    assert.deepEqual(receipt.no_mutation.refs_before, receipt.no_mutation.refs_after);
    assert.deepEqual(receipt.no_mutation.worktrees_before, receipt.no_mutation.worktrees_after);
    assert.deepEqual(receipt.no_mutation.config_before, receipt.no_mutation.config_after);
    assert.equal(receipt.no_mutation.equal, true);

    const verified = run("node", [ADMISSION, "verify", ...admissionArgs(fixture), "--stage", "admission"]);
    assert.notEqual(verified.status, 0);
    assert.match(`${verified.stdout}\n${verified.stderr}`, new RegExp(`d01_readiness_source_commit_unavailable:${PINNED_READINESS_SOURCE}`));
    assert.deepEqual(snapshotState(fixture.repo), before);
    assert.equal(snapshotState(fixture.repo).hooksPath, null);
    assert.equal(git(fixture.repo, "rev-parse", "refs/heads/stale/merged"), fixture.rootOid);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("admission verify hydrates exact pinned inputs from the prepared receipt", () => {
  const fixture = setupFixture();
  try {
    const verified = run("node", [ADMISSION, "verify", "--repo", fixture.repo, "--admission", fixture.paths.admission]);
    assert.notEqual(verified.status, 0, "fixture's unavailable D-01 source must remain a blocker");
    const receipt = JSON.parse(verified.stdout);
    assert.equal(receipt.initial_admission.path, fixture.paths.admission);
    assert.equal(receipt.initial_admission.commit, fixture.contractCommit);
    assert.equal(receipt.current_contract.path, fixture.paths.contract);
    assert.equal(receipt.current_contract.commit, fixture.contractCommit);
    assert.equal(receipt.inputs.local_snapshot.path, fixture.paths.snapshot);
    assert.equal(receipt.inputs.local_snapshot.commit, fixture.snapshotCommit);
    assert.equal(receipt.inputs.origin_snapshot.path, fixture.paths.origin);
    assert.equal(receipt.inputs.origin_snapshot.commit, fixture.snapshotCommit);
    assert.equal(receipt.inputs.allowlist.path, fixture.paths.allowlist);
    assert.equal(receipt.inputs.allowlist.commit, fixture.contractCommit);
    assert.equal(receipt.inputs.readiness.path, fixture.paths.readiness);
    assert.equal(receipt.inputs.readiness.commit, fixture.inputCommit);
    assert.ok(receipt.blocked_reasons.some((row) => row.code.startsWith(`d01_readiness_source_commit_unavailable:${PINNED_READINESS_SOURCE}`)));
    assert.ok(!receipt.blocked_reasons.some((row) => row.code === "initial_admission_verify_inputs_missing"));
    assert.ok(!receipt.blocked_reasons.some((row) => row.code.endsWith("_commit_path_required")));
    assert.equal(receipt.no_mutation.equal, true);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("current local apply checks admission before coordinator setup", () => {
  const fixture = setupFixture();
  try {
    const before = snapshotState(fixture.repo);
    const inputs = admissionArgs(fixture).slice(2);
    const fixtureIndex = inputs.indexOf("--source-fixture");
    inputs.splice(fixtureIndex, 2);
    const applied = run("bash", [OPERATOR, "local", "--repo", fixture.repo, "--apply", ...inputs]);
    assert.notEqual(applied.status, 0);
    assert.match(`${applied.stdout}\n${applied.stderr}`, new RegExp(`d01_readiness_source_commit_unavailable:${PINNED_READINESS_SOURCE}`));
    assert.deepEqual(snapshotState(fixture.repo), before);
    assert.equal(git(fixture.repo, "rev-parse", "refs/heads/stale/merged"), fixture.rootOid);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});
