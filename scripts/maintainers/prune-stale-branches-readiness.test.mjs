import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

const ROOT = process.cwd();
const GIT = "/usr/bin/git";
const SCRIPT = join(ROOT, "scripts/maintainers/prune-stale-branches-readiness.mjs");
const PHASE = ".planning/phases/245-branch-prune-local-and-remote";
const RECEIPT = `${PHASE}/245-23-READINESS.json`;
const SOURCE_PATHS = [
  ".planning/state.json",
  ".planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-VERIFICATION.md",
  ".planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json",
  ".planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-04-SUMMARY.md",
  ".planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-08-SUMMARY.md",
  ".planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md",
  ".planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md",
  ".planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-ESCALATED.log",
  ".planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md",
];
const STATE_PATH = SOURCE_PATHS[0];

function command(binary, args, options = {}) {
  return spawnSync(binary, args, { encoding: "utf8", ...options });
}

function git(repo, ...args) {
  const result = command(GIT, ["-C", repo, ...args]);
  assert.equal(result.status, 0, `git ${args.join(" ")} failed:\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  return result.stdout.trim();
}

function commitFiles(repo, files, message) {
  git(repo, "add", "--", ...files);
  git(repo, "-c", "core.hooksPath=/dev/null", "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", message);
  return git(repo, "rev-parse", "HEAD");
}

function setupFixture() {
  const temp = mkdtempSync(join(tmpdir(), "sigra-readiness-v2-"));
  const repo = join(temp, "repo");
  mkdirSync(repo);
  const init = command(GIT, ["init", "-q", "--initial-branch=main", repo]);
  assert.equal(init.status, 0, `${init.stdout ?? ""}${init.stderr ?? ""}`);
  git(repo, "config", "user.name", "Sigra Readiness Fixture");
  git(repo, "config", "user.email", "readiness-fixture@example.invalid");
  git(repo, "config", "gc.auto", "0");
  git(repo, "config", "maintenance.auto", "false");
  git(repo, "config", "core.hooksPath", "/dev/null");

  for (const sourcePath of SOURCE_PATHS) {
    const bytes = execFileSync(GIT, ["-C", ROOT, "show", `HEAD:${sourcePath}`]);
    const destination = join(repo, sourcePath);
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, bytes);
  }
  const evidenceBase = commitFiles(repo, SOURCE_PATHS, "fixture committed Phase 244 evidence");
  for (const sourcePath of [SOURCE_PATHS[6], SOURCE_PATHS[8]]) {
    const file = join(repo, sourcePath);
    const original = readFileSync(file, "utf8");
    const updated = original.replace(/^(source_commit:\s*)[0-9a-f]{40}\s*$/m, `$1${evidenceBase}`);
    assert.notEqual(updated, original, `${sourcePath} fixture must contain a source_commit field`);
    writeFileSync(file, updated);
  }
  const sourceCommit = commitFiles(repo, [SOURCE_PATHS[6], SOURCE_PATHS[8]], "fixture reconciled dependency source commits");
  return { temp, repo, sourceCommit, receiptPath: join(repo, RECEIPT) };
}

function runCapture(fixture, schemaVersion = 2) {
  const result = command(process.execPath, [SCRIPT, "capture", "--repo", fixture.repo,
    ...(schemaVersion === null ? [] : ["--schema-version", String(schemaVersion)]), "--output", RECEIPT], { cwd: fixture.repo });
  return { result, receipt: existsSync(fixture.receiptPath) ? JSON.parse(readFileSync(fixture.receiptPath, "utf8")) : null };
}

function captureReady(fixture, schemaVersion = 2) {
  const captured = runCapture(fixture, schemaVersion);
  assert.equal(captured.result.status, 0, `${captured.result.stdout ?? ""}${captured.result.stderr ?? ""}`);
  assert.equal(captured.receipt?.status, "ready", `${captured.result.stdout ?? ""}${captured.result.stderr ?? ""}`);
  return captured.receipt;
}

function commitReceipt(fixture, message = "fixture readiness artifact") {
  return commitFiles(fixture.repo, [RECEIPT], message);
}

function runVerify(fixture, artifactCommit) {
  return command(process.execPath, [SCRIPT, "verify", "--repo", fixture.repo,
    "--artifact", RECEIPT, "--artifact-commit", artifactCommit], { cwd: fixture.repo });
}

function report(result) {
  try { return JSON.parse(result.stdout); } catch { return null; }
}

function codes(items = []) {
  return items.map((item) => item.code);
}

function writeState(fixture, update) {
  const stateFile = join(fixture.repo, STATE_PATH);
  const state = JSON.parse(readFileSync(stateFile, "utf8"));
  update(state);
  writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`);
}

function setPhase244Status(state, status) {
  const phase = state.phases.find((row) => row.number === "244");
  assert.ok(phase, "fixture state must contain Phase 244");
  phase.status = status;
}

function expectBlockedCapture(fixture, expectedCode) {
  const captured = runCapture(fixture);
  assert.equal(captured.result.status, 0, `${captured.result.stdout ?? ""}${captured.result.stderr ?? ""}`);
  assert.equal(captured.receipt?.schema_version, 2);
  assert.equal(captured.receipt?.status, "blocked");
  assert.ok(codes(captured.receipt?.blocked_reasons).includes(expectedCode),
    `expected ${expectedCode}; got ${codes(captured.receipt?.blocked_reasons).join(", ")}`);
  return captured.receipt;
}

function testWithFixture(name, fn) {
  test(name, () => {
    const fixture = setupFixture();
    try { fn(fixture); } finally { rmSync(fixture.temp, { recursive: true, force: true }); }
  });
}

testWithFixture("schema 2 accepts route-only metadata drift and records all three exact route identities", (fixture) => {
  writeState(fixture, (state) => { state.route_metadata_note = "allowed metadata drift"; });
  const receipt = captureReady(fixture);
  assert.equal(receipt.source_commit, fixture.sourceCommit);
  assert.equal(receipt.sources.length, 9);
  assert.deepEqual(new Set(receipt.sources.map((row) => row.path)), new Set(SOURCE_PATHS));
  assert.equal(Object.keys(receipt.checks).length, 36, "all existing D-01 checks must remain present");
  const route = receipt.state_route;
  assert.equal(route.source.phase244_status, "complete");
  assert.equal(route.capture_observations.head.phase244_status, "complete");
  assert.equal(route.capture_observations.index.phase244_status, "complete");
  assert.equal(route.capture_observations.worktree.phase244_status, "complete");
  assert.notEqual(route.capture_observations.worktree.blob_oid, route.capture_observations.head.blob_oid);

  const artifactCommit = commitReceipt(fixture);
  const verified = runVerify(fixture, artifactCommit);
  assert.equal(verified.status, 0, `${verified.stdout ?? ""}${verified.stderr ?? ""}`);
  assert.equal(report(verified)?.status, "ready");
  assert.deepEqual(report(verified)?.reasons, []);
});

testWithFixture("schema 1 keeps its strict state route identity rule", (fixture) => {
  const receipt = captureReady(fixture, null);
  assert.equal(receipt.schema_version, 1);
  const artifactCommit = commitReceipt(fixture);
  writeState(fixture, (state) => { state.route_metadata_note = "schema 1 must reject drift"; });
  const verified = runVerify(fixture, artifactCommit);
  assert.notEqual(verified.status, 0, `${verified.stdout ?? ""}${verified.stderr ?? ""}`);
  const reasons = codes(report(verified)?.reasons);
  assert.ok(reasons.some((code) => code.startsWith("source_") && code.includes("dirty")),
    `schema 1 must reject route drift using its strict identity check; got ${JSON.stringify(report(verified))}`);
});

testWithFixture("schema 2 blocks a missing immutable source path", (fixture) => {
  const sourcePath = SOURCE_PATHS[1];
  rmSync(join(fixture.repo, sourcePath));
  const receipt = expectBlockedCapture(fixture, `immutable_source_worktree_missing:${sourcePath}`);
  assert.equal(receipt.checks.phase_244_verification_passed.passed, true, "the committed predicate remains independently evaluated");
});

for (const [location, mutate] of [
  ["head", (fixture) => {
    writeState(fixture, (state) => setPhase244Status(state, "in_progress"));
    commitFiles(fixture.repo, [STATE_PATH], "fixture contradictory HEAD route");
  }],
  ["index", (fixture) => {
    const changed = JSON.parse(readFileSync(join(fixture.repo, STATE_PATH), "utf8"));
    setPhase244Status(changed, "in_progress");
    const bytes = Buffer.from(`${JSON.stringify(changed, null, 2)}\n`);
    const blob = command(GIT, ["-C", fixture.repo, "hash-object", "-w", "--stdin"], { input: bytes }).stdout.trim();
    git(fixture.repo, "update-index", "--add", "--cacheinfo", `100644,${blob},${STATE_PATH}`);
  }],
  ["worktree", (fixture) => writeState(fixture, (state) => setPhase244Status(state, "in_progress"))],
]) {
  testWithFixture(`schema 2 blocks Phase 244 status contradiction in ${location}`, (fixture) => {
    mutate(fixture);
    expectBlockedCapture(fixture, `state_route_phase244_not_complete:${location}`);
  });
}

testWithFixture("schema 2 blocks an unparseable current route with a named predicate", (fixture) => {
  writeFileSync(join(fixture.repo, STATE_PATH), "{ invalid json\n");
  expectBlockedCapture(fixture, "state_route_json_invalid:worktree");
});

testWithFixture("schema 2 blocks a missing route observation instead of accepting the remaining complete copies", (fixture) => {
  git(fixture.repo, "update-index", "--force-remove", STATE_PATH);
  expectBlockedCapture(fixture, "state_route_observation_missing:index");
});

for (const [name, sourcePath, mutate, expectedCode] of [
  ["verification", SOURCE_PATHS[1], (text) => text.replace(/^(status:\s*)passed\s*$/m, "$1gaps_found"), "phase_244_verification_passed"],
  ["CI evidence", SOURCE_PATHS[2], (text) => {
    const evidence = JSON.parse(text);
    evidence.final_main_consumer_receipt.run.conclusion = "failure";
    return `${JSON.stringify(evidence, null, 2)}\n`;
  }, "phase_244_final_main_run_success"],
  ["summary", SOURCE_PATHS[4], (text) => text.replace("36266022766", "99999999999"), "phase_244_final_main_summary_run_id"],
  ["dependency", SOURCE_PATHS[8], (text) => text.replace(/^(status:\s*)complete\s*$/m, "$1blocked"), "quick_dzu_complete"],
]) {
  testWithFixture(`schema 2 re-evaluates changed ${name} facts from committed bytes`, (fixture) => {
    const sourceFile = join(fixture.repo, sourcePath);
    const original = readFileSync(sourceFile, "utf8");
    const updated = mutate(original);
    assert.notEqual(updated, original, `fixture must alter the ${name} predicate input`);
    writeFileSync(sourceFile, updated);
    commitFiles(fixture.repo, [sourcePath], `fixture changed ${name} facts`);
    const receipt = expectBlockedCapture(fixture, expectedCode);
    assert.equal(receipt.source_commit, git(fixture.repo, "rev-parse", "HEAD"));
  });
}

for (const [field, mutate, expectedCode] of [
  ["commit", (receipt) => { receipt.sources[1].commit = "f".repeat(40); }, `source_commit_mismatch:${SOURCE_PATHS[1]}`],
  ["path", (receipt) => { receipt.sources[1].path = "unexpected/path"; }, "source_path_unexpected:unexpected/path"],
  ["blob", (receipt) => { receipt.sources[1].blob_oid = "f".repeat(40); }, `source_blob_identity_mismatch:${SOURCE_PATHS[1]}`],
  ["SHA-256", (receipt) => { receipt.sources[1].sha256 = "f".repeat(64); }, `source_sha256_identity_mismatch:${SOURCE_PATHS[1]}`],
]) {
  testWithFixture(`schema 2 verifies each recorded source ${field} identity`, (fixture) => {
    const receipt = captureReady(fixture);
    mutate(receipt);
    writeFileSync(fixture.receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
    const artifactCommit = commitReceipt(fixture, `fixture tampered ${field} identity`);
    const verified = runVerify(fixture, artifactCommit);
    assert.notEqual(verified.status, 0, `${verified.stdout ?? ""}${verified.stderr ?? ""}`);
    assert.ok(codes(report(verified)?.reasons).includes(expectedCode),
      `expected ${expectedCode}; got ${codes(report(verified)?.reasons).join(", ")}`);
  });
}

testWithFixture("schema 2 rejects duplicate source records", (fixture) => {
  const receipt = captureReady(fixture);
  receipt.sources.push({ ...receipt.sources[0] });
  writeFileSync(fixture.receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
  const artifactCommit = commitReceipt(fixture, "fixture duplicate source record");
  const verified = runVerify(fixture, artifactCommit);
  assert.notEqual(verified.status, 0);
  assert.ok(codes(report(verified)?.reasons).includes("source_set_duplicate_path"));
});

testWithFixture("schema 2 rejects an invalid receipt schema", (fixture) => {
  const receipt = captureReady(fixture);
  receipt.schema_version = 99;
  writeFileSync(fixture.receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
  const artifactCommit = commitReceipt(fixture, "fixture invalid receipt schema");
  const verified = runVerify(fixture, artifactCommit);
  assert.notEqual(verified.status, 0);
  assert.ok(codes(report(verified)?.reasons).includes("readiness_schema_invalid"));
});

testWithFixture("schema 2 blocks a changed immutable worktree blob after capture", (fixture) => {
  captureReady(fixture);
  const artifactCommit = commitReceipt(fixture);
  const sourcePath = SOURCE_PATHS[1];
  const file = join(fixture.repo, sourcePath);
  writeFileSync(file, `${readFileSync(file, "utf8")}\npost-capture change\n`);
  const verified = runVerify(fixture, artifactCommit);
  assert.notEqual(verified.status, 0);
  assert.ok(codes(report(verified)?.reasons).includes(`immutable_source_worktree_identity_changed:${sourcePath}`));
});

testWithFixture("schema 2 cannot be downgraded by changing only the worktree receipt schema", (fixture) => {
  const receipt = captureReady(fixture);
  const artifactCommit = commitReceipt(fixture);
  receipt.schema_version = 1;
  writeFileSync(fixture.receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
  const verified = runVerify(fixture, artifactCommit);
  assert.notEqual(verified.status, 0);
  assert.ok(codes(report(verified)?.reasons).includes("readiness_artifact_worktree_identity_changed"));
});
