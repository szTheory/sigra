import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

const ROOT = process.cwd();
const GIT = "/usr/bin/git";
const OPERATOR = join(ROOT, "scripts/maintainers/prune-stale-branches.sh");
const READINESS = join(ROOT, "scripts/maintainers/prune-stale-branches-readiness.mjs");
const RECEIPT = ".planning/phases/245-branch-prune-local-and-remote/245-READINESS.json";
const PHASE_DIR = ".planning/phases/245-branch-prune-local-and-remote";
const SOURCES = [
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

function run(binary, args, options = {}) {
  return spawnSync(binary, args, { encoding: "utf8", ...options });
}

function git(repo, ...args) {
  const result = run(GIT, ["-C", repo, ...args]);
  assert.equal(result.status, 0, `git ${args.join(" ")} failed:\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  return result.stdout.trim();
}

function commit(repo, paths, message) {
  git(repo, "add", "--", ...paths);
  git(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", message);
  return git(repo, "rev-parse", "HEAD");
}

function makeFixture() {
  const temp = mkdtempSync(join(tmpdir(), "sigra-prune-operator-readiness-"));
  const repo = join(temp, "repo");
  const clone = run(GIT, ["clone", "-q", "--shared", ROOT, repo]);
  assert.equal(clone.status, 0, `${clone.stdout ?? ""}${clone.stderr ?? ""}`);
  git(repo, "config", "user.name", "Sigra Operator Fixture");
  git(repo, "config", "user.email", "operator-fixture@example.invalid");
  git(repo, "config", "gc.auto", "0");
  git(repo, "config", "maintenance.auto", "false");
  git(repo, "checkout", "-q", "-b", "fixture-operator-readiness");

  const initial = git(repo, "rev-parse", "HEAD");
  for (const source of SOURCES) {
    const bytes = execFileSync(GIT, ["-C", ROOT, "show", `HEAD:${source}`]);
    const destination = join(repo, source);
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, bytes);
  }
  for (const source of [SOURCES[6], SOURCES[8]]) {
    const file = join(repo, source);
    const before = readFileSync(file, "utf8");
    const after = before.replace(/^(source_commit:\s*)[0-9a-f]{40}\s*$/m, `$1${initial}`);
    assert.notEqual(before, after, `${source} has a source_commit identity`);
    writeFileSync(file, after);
  }
  commit(repo, SOURCES, "fixture: commit Phase 244 readiness sources");

  const capture = run(process.execPath, [READINESS, "capture", "--repo", repo,
    "--schema-version", "2", "--output", RECEIPT], { cwd: repo });
  assert.equal(capture.status, 0, `${capture.stdout ?? ""}${capture.stderr ?? ""}`);
  const receiptFile = join(repo, RECEIPT);
  const receipt = JSON.parse(readFileSync(receiptFile, "utf8"));
  assert.equal(receipt.schema_version, 2);
  assert.equal(receipt.status, "ready", JSON.stringify(receipt.blocked_reasons));
  const receiptCommit = commit(repo, [RECEIPT], "fixture: commit schema-2 readiness receipt");
  return { temp, repo, receiptCommit, receiptFile, receipt };
}

function refs(repo) {
  return git(repo, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)");
}

function directVerify(fixture, artifact = RECEIPT, artifactCommit = fixture.receiptCommit) {
  return run(process.execPath, [READINESS, "verify", "--repo", fixture.repo,
    "--artifact", artifact, "--artifact-commit", artifactCommit], { cwd: ROOT });
}

function publicVerify(fixture, readiness = RECEIPT, readinessCommit = fixture.receiptCommit, flags = []) {
  return run("bash", [OPERATOR, "verify-readiness", "--repo", fixture.repo,
    ...flags, "--readiness-commit", readinessCommit, "--readiness", readiness], { cwd: ROOT });
}

function report(result) {
  try { return JSON.parse(result.stdout); } catch { return null; }
}

test("schema-2 operator read-only", (t) => {
  const fixture = makeFixture();
  try {
    const before = refs(fixture.repo);
    const direct = directVerify(fixture);
    assert.equal(direct.status, 0, `${direct.stdout ?? ""}${direct.stderr ?? ""}`);
    assert.equal(report(direct)?.status, "ready");
    const publicResult = publicVerify(fixture);
    const after = refs(fixture.repo);
    if (process.env.GSD_PLAN26_RECORD_RED === "1") {
      const initialOperator = readFileSync(OPERATOR, "utf8");
      const reasonCodes = [...new Set([...publicResult.stdout, ...publicResult.stderr]
        .join("").match(/readiness_artifact_(?:path_outside_repository|missing_from_commit|missing_from_worktree)/g) ?? [])];
      const evidence = {
        schema_version: 1,
        phase: "245-branch-prune-local-and-remote",
        plan: "245-26",
        test: "schema-2 operator read-only",
        captured_at: new Date().toISOString(),
        state: "red_before_operator_repair",
        fixture: "disposable committed schema-2 receipt with nine source pins",
        direct_helper: { command: `node ${READINESS} verify --repo <fixture> --artifact ${RECEIPT} --artifact-commit ${fixture.receiptCommit}`, exit_code: direct.status, status: report(direct)?.status, reason_codes: report(direct)?.reasons?.map((row) => row.code) ?? [] },
        public_operator: { command: `bash ${OPERATOR} verify-readiness --repo <fixture> --readiness-commit ${fixture.receiptCommit} --readiness ${RECEIPT}`, exit_code: publicResult.status, reason_codes: reasonCodes, stderr: publicResult.stderr.trim() },
        refs_before: before,
        refs_after: after,
        refs_unchanged: before === after,
        production_ref_operations: 0,
        expected_fix_site: initialOperator.includes('--artifact "$file"') ? "verify_readiness passes temporary committed-byte copy" : "verify_readiness helper argument requires inspection",
      };
      writeFileSync(join(ROOT, `${PHASE_DIR}/245-26-RED-EVIDENCE.json`), `${JSON.stringify(evidence, null, 2)}\n`);
    }
    assert.equal(after, before, "read-only verification must preserve all fixture refs");
    assert.equal(publicResult.status, 0, `${publicResult.stdout ?? ""}${publicResult.stderr ?? ""}`);
    assert.match(publicResult.stdout, /PASS: committed D-01 readiness is valid/);
    t.diagnostic(JSON.stringify({ direct_exit: direct.status, public_exit: publicResult.status, refs_unchanged: true }));
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("schema-2 operator rejects one-byte worktree mismatch", () => {
  const fixture = makeFixture();
  try {
    const before = refs(fixture.repo);
    writeFileSync(fixture.receiptFile, `${readFileSync(fixture.receiptFile, "utf8")} `);
    const direct = directVerify(fixture);
    assert.notEqual(direct.status, 0);
    assert.ok(report(direct)?.reasons?.some((reason) => reason.code === "readiness_artifact_worktree_identity_changed"),
      `${direct.stdout ?? ""}${direct.stderr ?? ""}`);
    const publicResult = publicVerify(fixture);
    assert.notEqual(publicResult.status, 0);
    assert.match(publicResult.stderr, /d01_readiness_missing_stale_dirty_or_unresolved/);
    assert.equal(refs(fixture.repo), before, "blocked verification must preserve fixture refs");
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("schema-2 operator preserves readiness evidence aliases", () => {
  const fixture = makeFixture();
  try {
    const result = publicVerify(fixture, RECEIPT, fixture.receiptCommit,
      ["--evidence-commit", fixture.receiptCommit, "--evidence", RECEIPT]);
    assert.equal(result.status, 0, `${result.stdout ?? ""}${result.stderr ?? ""}`);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});
