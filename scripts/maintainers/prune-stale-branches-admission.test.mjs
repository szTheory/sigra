import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

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

  const current = run("node", [CURRENT, "capture", "--repo", repo, "--output", join(repo, paths.contract), "--source-fixture", paths.fixture, "--pin-input", `${inputCommit}:${paths.allowlist}`]);
  assert.equal(current.status, 0, `${current.stdout ?? ""}${current.stderr ?? ""}`);
  git(repo, "add", paths.contract, `${paths.contract}.sha256`);
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
    "--allowlist-commit", fixture.inputCommit,
    "--allowlist", fixture.paths.allowlist,
    "--readiness-commit", fixture.inputCommit,
    "--readiness", fixture.paths.readiness,
    "--source-fixture", fixture.paths.fixture,
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
    assert.ok(receipt.blocked_reasons.some((row) => row.code === `d01_readiness_source_commit_unavailable:${PINNED_READINESS_SOURCE}`));
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
