import assert from "node:assert/strict";
import { execFileSync, spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
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
  const result = spawnSync(binary, args, { encoding: "utf8", timeout: 120_000, ...options });
  if (result.error || result.signal || result.status === null) {
    throw new Error(`${binary} ${args.join(" ")} did not exit normally: ${result.error?.message ?? result.signal ?? "unknown subprocess failure"}`);
  }
  return result;
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
  const bare = join(temp, "origin.git");
  git(repo, "init", "-q", "--bare", "--initial-branch=main", bare);
  git(repo, "remote", "set-url", "origin", bare);
  git(repo, "push", "-q", "origin", "HEAD:refs/heads/main");
  git(repo, "remote", "set-head", "origin", "main");

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
  return { temp, repo, bare, receiptCommit, receiptFile, receipt };
}

function refs(repo) {
  return git(repo, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)");
}

function originRefs(fixture) {
  return git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)");
}

function assertSnapshotObjectsReadable(fixture) {
  for (const snapshotPath of [fixture.snapshot, fixture.originSnapshot]) {
    const rows = readFileSync(join(fixture.repo, snapshotPath), "utf8").trim().split("\n").slice(1);
    for (const row of rows) {
      const [ref, oid, type, peeledOid, peeledType] = row.split("\t");
      assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${oid}^{${type}}`]).status, 0,
        `${snapshotPath} direct object remains readable for ${ref}`);
      if (peeledOid !== "-") {
        assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${peeledOid}^{${peeledType}}`]).status, 0,
          `${snapshotPath} peeled object remains readable for ${ref}`);
      }
    }
  }
}

function makeTrackingFixture(options = {}) {
  const fixture = makeFixture();
  const bare = fixture.bare;
  const bin = join(fixture.temp, "bin");
  const ssh = join(bin, "fixture-ssh");
  const gh = join(bin, "gh");
  mkdirSync(bin);
  writeFileSync(ssh, `#!/usr/bin/env bash
set -euo pipefail
host_seen=0
request=""
for arg in "$@"; do
  [[ "$arg" == git@github.com ]] && host_seen=1
  [[ "$arg" == *git-upload-pack* || "$arg" == *git-receive-pack* ]] && request="$arg"
done
[[ "$host_seen" == 1 ]] || { echo 'fixture SSH rejected unknown host' >&2; exit 91; }
[[ "$request" =~ ^git-(upload|receive)-pack[[:space:]]+[\\\"\\\']?szTheory/sigra\\.git[\\\"\\\']?$ ]] \\
  || { echo "fixture SSH rejected request: $request" >&2; exit 92; }
if [[ "$request" == git-receive-pack* ]]; then
  exec /usr/bin/git-receive-pack "$PRUNE_FIXTURE_BARE"
fi
exec /usr/bin/git-upload-pack "$PRUNE_FIXTURE_BARE"
`);
  chmodSync(ssh, 0o755);
  writeFileSync(gh, `#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  auth) exit 0 ;;
  pr)
    if [[ -n "\${PRUNE_FIXTURE_RACE_CALL_COUNT:-}" ]]; then
      count=0; [[ ! -f "$PRUNE_FIXTURE_RACE_CALL_COUNT" ]] || count="$(cat "$PRUNE_FIXTURE_RACE_CALL_COUNT")"
      count=$((count + 1)); printf '%s\\n' "$count" > "$PRUNE_FIXTURE_RACE_CALL_COUNT"
      if [[ "$count" == 2 ]]; then
        printf 'ready\\n' > "$PRUNE_FIXTURE_RACE_READY_FIFO"
        IFS= read -r release_signal < "$PRUNE_FIXTURE_RACE_RELEASE_FIFO"
        echo 'fixture rendezvous released as a blocked PR gate' >&2
        exit 73
      fi
    fi
    case "\${PRUNE_FIXTURE_PR_SCENARIO:-normal}" in fail) echo 'fixture PR CLI unavailable' >&2; exit 1 ;; null) printf '%s\\n' null ;; *) cat "$PRUNE_FIXTURE_PR_CLI_JSON" ;; esac ;;
  api) case "$2" in
    rate_limit) printf '%s\\n' '{"resources":{"core":{"remaining":5000}}}' ;;
    user) printf '%s\\n' '{"login":"fixture-operator"}' ;;
    repos/szTheory/sigra) printf '%s\\n' '{"full_name":"szTheory/sigra","permissions":{"push":true}}' ;;
    /repos/szTheory/sigra/pulls*) case "\${PRUNE_FIXTURE_PR_SCENARIO:-normal}" in null) printf '%s\\n' null ;; truncated) cat "$PRUNE_FIXTURE_PR_TRUNCATED_JSON" ;; *) cat "$PRUNE_FIXTURE_PR_API_JSON" ;; esac ;;
    *) echo "unexpected gh api: $2" >&2; exit 2 ;;
  esac ;;
  *) echo "unexpected gh command: $*" >&2; exit 2 ;;
esac
`);
  chmodSync(gh, 0o755);
  git(fixture.repo, "remote", "set-url", "origin", bare);
  git(fixture.repo, "push", "-q", "origin", "HEAD:refs/heads/main");
  git(fixture.repo, "fetch", "-q", "origin");
  git(fixture.repo, "remote", "set-head", "origin", "main");
  git(fixture.repo, "remote", "set-url", "origin", "git@github.com:szTheory/sigra.git");
  const oid = git(fixture.repo, "rev-parse", "HEAD");
  const trackingRef = "refs/remotes/origin/stale/fixture-only";
  git(fixture.repo, "update-ref", trackingRef, oid);

  const snapshot = `${PHASE_DIR}/245-26-FIXTURE-LOCAL-REFS.tsv`;
  const originSnapshot = `${PHASE_DIR}/245-26-FIXTURE-ORIGIN-REFS.tsv`;
  const allowlist = `${PHASE_DIR}/245-26-FIXTURE-ALLOWLIST.tsv`;
  const contract = `${PHASE_DIR}/245-26-FIXTURE-CURRENT-CONTRACT.json`;
  const sourceFixture = join(fixture.temp, "prs.json");
  const cliPrs = (options.contractPRs ?? []).map((pull) => ({ ...pull, headRefOid: pull.headRefOid ?? oid, baseRefOid: pull.baseRefOid ?? oid,
    headRepository: pull.headRepository ?? { nameWithOwner: "szTheory/sigra" } }));
  const apiPrs = options.contractApiPRs ?? cliPrs;
  const liveCliPrs = (options.liveCliPRs ?? cliPrs).map((pull) => ({ ...pull, headRefOid: pull.headRefOid ?? oid, baseRefOid: pull.baseRefOid ?? oid,
    headRepository: pull.headRepository ?? { nameWithOwner: "szTheory/sigra" } }));
  const liveApiPrs = (options.liveApiPRs ?? apiPrs).map((pull) => ({ ...pull, headRefOid: pull.headRefOid ?? oid, baseRefOid: pull.baseRefOid ?? oid }));
  const apiShape = (pulls) => pulls.map((pull) => ({ number: pull.number, state: "OPEN",
    head: { ref: pull.headRefName, sha: pull.headRefOid, repo: { full_name: pull.headRepository?.nameWithOwner ?? pull.headRepository ?? "szTheory/sigra" } },
    base: { ref: pull.baseRefName, sha: pull.baseRefOid, repo: { full_name: pull.baseRepository ?? "szTheory/sigra" } } }));
  const cliJson = join(fixture.temp, "live-cli-prs.json");
  const apiJson = join(fixture.temp, "live-api-prs.json");
  const truncatedJson = join(fixture.temp, "truncated-api-prs.json");
  writeFileSync(sourceFixture, JSON.stringify({ cliPulls: cliPrs, pages: [apiShape(apiPrs)] }));
  writeFileSync(cliJson, JSON.stringify(liveCliPrs));
  writeFileSync(apiJson, JSON.stringify(apiShape(liveApiPrs)));
  writeFileSync(truncatedJson, JSON.stringify(apiShape(Array.from({ length: 100 }, (_, index) => ({
    number: index + 1000, state: "OPEN", headRefName: `fixture/page-${index + 1}`, baseRefName: "main",
    headRefOid: oid, baseRefOid: oid,
  })))));
  const fixtureEnv = { ...process.env, PATH: `${bin}:${dirname(process.execPath)}:/usr/bin:/bin`, GIT_SSH_COMMAND: ssh, GIT_SSH_VARIANT: "ssh", PRUNE_FIXTURE_BARE: bare,
    PRUNE_FIXTURE_PR_CLI_JSON: cliJson, PRUNE_FIXTURE_PR_API_JSON: apiJson, PRUNE_FIXTURE_PR_TRUNCATED_JSON: truncatedJson };
  for (const [command, output] of [["capture-local", snapshot], ["capture-origin", originSnapshot]]) {
    const captured = run("bash", [OPERATOR, command, "--repo", fixture.repo, "--output", join(fixture.repo, output)], { cwd: ROOT, env: fixtureEnv });
    assert.equal(captured.status, 0, `${captured.stdout ?? ""}${captured.stderr ?? ""}`);
  }
  const snapshotCommit = commit(fixture.repo, [snapshot, originSnapshot], "fixture: commit complete ref snapshots");
  writeFileSync(join(fixture.repo, allowlist), `side\tref\toid\ttype\treason\ntracking\t${trackingRef}\t${oid}\tcommit\tdisposable tracking candidate\n`);
  const allowlistCommit = commit(fixture.repo, [allowlist], "fixture: commit exact tracking allowlist");
  const contractCapture = run(process.execPath, [join(ROOT, "scripts/maintainers/prune-stale-branches-current.mjs"),
    "capture", "--repo", fixture.repo, "--output", contract, "--source-fixture", sourceFixture,
    "--pin-input", `${allowlistCommit}:${allowlist}`], { cwd: fixture.repo, env: fixtureEnv });
  assert.equal(contractCapture.status, 0, `${contractCapture.stdout ?? ""}${contractCapture.stderr ?? ""}`);
  const contractCommit = commit(fixture.repo, [contract, `${contract}.sha256`], "fixture: pin current refs and tracking allowlist");
  const installed = run("bash", [join(ROOT, "scripts/maintainers/repo-mutation-coordinator.sh"), "install", "--repo", fixture.repo], { cwd: ROOT });
  assert.equal(installed.status, 0, `${installed.stdout ?? ""}${installed.stderr ?? ""}`);
  return { ...fixture, bare, bin, ssh, env: fixtureEnv, trackingRef, oid, snapshot, originSnapshot, snapshotCommit, allowlist, allowlistCommit,
    contract, contractCommit, sourceFixture, liveCliPRs: cliJson, liveApiPRs: apiJson };
}

function directVerify(fixture, artifact = RECEIPT, artifactCommit = fixture.receiptCommit) {
  return run(process.execPath, [READINESS, "verify", "--repo", fixture.repo,
    "--artifact", artifact, "--artifact-commit", artifactCommit], { cwd: ROOT });
}

function trackingApply(fixture, appliedRefs = []) {
  return run("bash", [OPERATOR, "tracking", "--repo", fixture.repo, "--apply",
    "--snapshot-commit", fixture.snapshotCommit, "--snapshot", fixture.snapshot,
    "--origin-snapshot-commit", fixture.originSnapshotCommit ?? fixture.snapshotCommit, "--origin-snapshot", fixture.originSnapshot,
    "--allowlist-commit", fixture.allowlistCommit, "--allowlist", fixture.allowlist,
    "--readiness-commit", fixture.receiptCommit, "--readiness", RECEIPT,
    "--current-contract-commit", fixture.contractCommit, "--current-contract", fixture.contract,
    ...appliedRefs.flatMap((ref) => ["--applied-ref", ref])], {
    cwd: ROOT,
    env: fixture.env,
  });
}

function remoteApply(fixture, preflightCommit, appliedRefs = []) {
  return run("bash", [OPERATOR, "remote", "--repo", fixture.repo, "--apply",
    "--snapshot-commit", fixture.snapshotCommit, "--snapshot", fixture.snapshot,
    "--origin-commit", fixture.originSnapshotCommit ?? fixture.snapshotCommit,
    "--origin-snapshot-commit", fixture.originSnapshotCommit ?? fixture.snapshotCommit, "--origin-snapshot", fixture.originSnapshot,
    "--allowlist-commit", fixture.allowlistCommit, "--allowlist", fixture.allowlist,
    "--safety-commit", fixture.allowlistCommit, "--safety-list", fixture.allowlist,
    "--readiness-commit", fixture.receiptCommit, "--readiness", RECEIPT,
    "--current-contract-commit", fixture.contractCommit, "--current-contract", fixture.contract,
    "--preflight-commit", preflightCommit, "--preflight", fixture.preflight,
    ...appliedRefs.flatMap((ref) => ["--applied-ref", ref])], {
    cwd: ROOT,
    env: fixture.env,
  });
}

function safetyPublishApply(fixture, preflightCommit, appliedRefs = []) {
  return run("bash", [OPERATOR, "safety-publish", "--repo", fixture.repo, "--apply",
    "--snapshot-commit", fixture.snapshotCommit, "--snapshot", fixture.snapshot,
    "--origin-commit", fixture.originSnapshotCommit ?? fixture.snapshotCommit,
    "--origin-snapshot", fixture.originSnapshot,
    "--allowlist-commit", fixture.allowlistCommit, "--allowlist", fixture.allowlist,
    "--safety-commit", fixture.allowlistCommit, "--safety-list", fixture.allowlist,
    "--readiness-commit", fixture.receiptCommit, "--readiness", RECEIPT,
    "--current-contract-commit", fixture.contractCommit, "--current-contract", fixture.contract,
    "--preflight-commit", preflightCommit, "--preflight", fixture.publishPreflight,
    "--operation", "publish", "--ref", fixture.safetyPublicationRef,
    ...appliedRefs.flatMap((ref) => ["--applied-ref", ref])], {
    cwd: ROOT,
    env: fixture.env,
  });
}

function startTrackingApply(fixture) {
  const child = spawn("bash", [OPERATOR, "tracking", "--repo", fixture.repo, "--apply",
    "--snapshot-commit", fixture.snapshotCommit, "--snapshot", fixture.snapshot,
    "--origin-snapshot-commit", fixture.snapshotCommit, "--origin-snapshot", fixture.originSnapshot,
    "--allowlist-commit", fixture.allowlistCommit, "--allowlist", fixture.allowlist,
    "--readiness-commit", fixture.receiptCommit, "--readiness", RECEIPT,
    "--current-contract-commit", fixture.contractCommit, "--current-contract", fixture.contract], {
    cwd: ROOT,
    env: fixture.env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "";
  let stderr = "";
  child.stdout.setEncoding("utf8").on("data", (chunk) => { stdout += chunk; });
  child.stderr.setEncoding("utf8").on("data", (chunk) => { stderr += chunk; });
  const closed = new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (status, signal) => resolve({ status, signal, stdout, stderr }));
  });
  return { child, closed };
}

function readFifo(fifo, timeoutMs = 30_000) {
  const reader = spawn("bash", ["-c", "IFS= read -r value < \"$1\"; printf '%s\\n' \"$value\"", "_", fifo], {
    cwd: ROOT,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "";
  let stderr = "";
  reader.stdout.setEncoding("utf8").on("data", (chunk) => { stdout += chunk; });
  reader.stderr.setEncoding("utf8").on("data", (chunk) => { stderr += chunk; });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reader.kill("SIGTERM"), timeoutMs);
    reader.once("error", (error) => { clearTimeout(timer); reject(error); });
    reader.once("close", (status, signal) => {
      clearTimeout(timer);
      if (status === 0) resolve(stdout.trim());
      else reject(new Error(`fixture FIFO reader exited status=${status} signal=${signal}: ${stderr}`));
    });
  });
}

function publicVerify(fixture, readiness = RECEIPT, readinessCommit = fixture.receiptCommit, flags = []) {
  return run("bash", [OPERATOR, "verify-readiness", "--repo", fixture.repo,
    ...flags, "--readiness-commit", readinessCommit, "--readiness", readiness], { cwd: ROOT });
}

function mutateCommittedReceipt(fixture, mutate, message) {
  const receipt = JSON.parse(readFileSync(fixture.receiptFile, "utf8"));
  mutate(receipt);
  writeFileSync(fixture.receiptFile, `${JSON.stringify(receipt, null, 2)}\n`);
  fixture.receiptCommit = commit(fixture.repo, [RECEIPT], message);
}

function report(result) {
  try { return JSON.parse(result.stdout); } catch { return null; }
}

test("schema-2 operator read-only", (t) => {
  const fixture = makeFixture();
  try {
    const before = refs(fixture.repo);
    const originBefore = originRefs(fixture);
    const direct = directVerify(fixture);
    assert.equal(direct.status, 0, `${direct.stdout ?? ""}${direct.stderr ?? ""}`);
    assert.equal(report(direct)?.status, "ready");
    const publicResult = publicVerify(fixture);
    const after = refs(fixture.repo);
    const originAfter = originRefs(fixture);
    if (process.env.GSD_PLAN26_RECORD_RED === "1") {
      const evidencePath = join(ROOT, `${PHASE_DIR}/245-26-RED-EVIDENCE.json`);
      const initialOperator = readFileSync(OPERATOR, "utf8");
      const reasonCodes = [...new Set([...publicResult.stdout, ...publicResult.stderr]
        .join("").match(/readiness_artifact_(?:path_outside_repository|missing_from_commit|missing_from_worktree)/g) ?? [])];
      assert.equal(direct.status, 0, "RED evidence requires the direct helper to pass");
      assert.equal(report(direct)?.status, "ready", "RED evidence requires a ready direct receipt");
      assert.equal(publicResult.status, 1, "RED evidence requires the original public failure");
      assert.deepEqual(reasonCodes.sort(), [
        "readiness_artifact_missing_from_commit",
        "readiness_artifact_missing_from_worktree",
        "readiness_artifact_path_outside_repository",
      ].sort(), "RED evidence requires all three original artifact-path rejection codes");
      assert.equal(before, after, "RED evidence requires complete unchanged fixture refs");
      assert.equal(originBefore, originAfter, "RED evidence requires unchanged disposable-origin refs");
      assert.equal(existsSync(evidencePath), false, "refusing to overwrite durable original RED evidence");
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
      writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
    }
    assert.equal(after, before, "read-only verification must preserve all fixture refs");
    assert.equal(originAfter, originBefore, "read-only verification must preserve all disposable-origin refs");
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
    const originBefore = originRefs(fixture);
    writeFileSync(fixture.receiptFile, `${readFileSync(fixture.receiptFile, "utf8")} `);
    const direct = directVerify(fixture);
    assert.notEqual(direct.status, 0);
    assert.ok(report(direct)?.reasons?.some((reason) => reason.code === "readiness_artifact_worktree_identity_changed"),
      `${direct.stdout ?? ""}${direct.stderr ?? ""}`);
    const publicResult = publicVerify(fixture);
    assert.notEqual(publicResult.status, 0);
    assert.match(publicResult.stderr, /d01_readiness_missing_stale_dirty_or_unresolved/);
    assert.equal(refs(fixture.repo), before, "blocked verification must preserve fixture refs");
    assert.equal(originRefs(fixture), originBefore, "blocked verification must preserve disposable-origin refs");
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

for (const [name, prepare, expectedCode] of [
  ["missing receipt", (fixture) => ({ path: `${RECEIPT}.missing`, commit: fixture.receiptCommit }), "readiness_not_in_committed_revision"],
  ["uncommitted receipt", (fixture) => {
    const path = `${PHASE_DIR}/245-26-UNCOMMITTED-RECEIPT.json`;
    writeFileSync(join(fixture.repo, path), readFileSync(fixture.receiptFile));
    return { path, commit: fixture.receiptCommit };
  }, "readiness_not_in_committed_revision"],
  ["outside-repository receipt", (fixture) => ({ path: "../outside/receipt.json", commit: fixture.receiptCommit }), "unsafe_repository_path"],
  ["null receipt", (fixture) => {
    writeFileSync(fixture.receiptFile, "null\n");
    fixture.receiptCommit = commit(fixture.repo, [RECEIPT], "fixture null readiness receipt");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "readiness_schema_invalid"],
  ["invalid schema", (fixture) => {
    mutateCommittedReceipt(fixture, (receipt) => { receipt.schema_version = 99; }, "fixture invalid readiness schema");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "readiness_schema_invalid"],
  ["zero source records", (fixture) => {
    mutateCommittedReceipt(fixture, (receipt) => { receipt.sources = []; }, "fixture empty readiness sources");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "source_set_size_invalid"],
  ["invalid source commit", (fixture) => {
    mutateCommittedReceipt(fixture, (receipt) => { receipt.source_commit = "f".repeat(40); }, "fixture missing source commit");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "source_commit_missing"],
  ["invalid source blob", (fixture) => {
    mutateCommittedReceipt(fixture, (receipt) => { receipt.sources[1].blob_oid = "f".repeat(40); }, "fixture invalid source blob");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, `source_blob_identity_mismatch:${SOURCES[1]}`],
  ["invalid source hash", (fixture) => {
    mutateCommittedReceipt(fixture, (receipt) => { receipt.sources[1].sha256 = "f".repeat(64); }, "fixture invalid source hash");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, `source_sha256_identity_mismatch:${SOURCES[1]}`],
  ["dirty immutable source", (fixture) => {
    const file = join(fixture.repo, SOURCES[1]);
    writeFileSync(file, `${readFileSync(file, "utf8")}\npost-capture mutation\n`);
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, `immutable_source_worktree_identity_changed:${SOURCES[1]}`],
  ["contradictory HEAD route", (fixture) => {
    const stateFile = join(fixture.repo, SOURCES[0]);
    const state = JSON.parse(readFileSync(stateFile, "utf8"));
    state.phases.find((phase) => phase.number === "244").status = "in_progress";
    writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`);
    commit(fixture.repo, [SOURCES[0]], "fixture contradictory readiness HEAD route");
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "state_route_phase244_not_complete:head"],
  ["contradictory index route", (fixture) => {
    const stateFile = join(fixture.repo, SOURCES[0]);
    const state = JSON.parse(readFileSync(stateFile, "utf8"));
    state.phases.find((phase) => phase.number === "244").status = "in_progress";
    const bytes = Buffer.from(`${JSON.stringify(state, null, 2)}\n`);
    const blob = run(GIT, ["-C", fixture.repo, "hash-object", "-w", "--stdin"], { input: bytes }).stdout.trim();
    git(fixture.repo, "update-index", "--add", "--cacheinfo", `100644,${blob},${SOURCES[0]}`);
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "state_route_phase244_not_complete:index"],
  ["contradictory worktree route", (fixture) => {
    const stateFile = join(fixture.repo, SOURCES[0]);
    const state = JSON.parse(readFileSync(stateFile, "utf8"));
    state.phases.find((phase) => phase.number === "244").status = "in_progress";
    writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`);
    return { path: RECEIPT, commit: fixture.receiptCommit };
  }, "state_route_phase244_not_complete:worktree"],
]) {
  test(`public readiness negative matrix: ${name}`, () => {
    const fixture = makeFixture();
    try {
      const input = prepare(fixture);
      const before = refs(fixture.repo);
      const originBefore = originRefs(fixture);
      const result = publicVerify(fixture, input.path, input.commit);
      const combined = `${result.stdout ?? ""}${result.stderr ?? ""}`;
      assert.notEqual(result.status, 0, `${name} unexpectedly passed public verification`);
      assert.ok(combined.includes(expectedCode), `${name} lacked named signal ${expectedCode}:\n${combined}`);
      assert.equal(refs(fixture.repo), before, `${name} rejection changed fixture refs`);
      assert.equal(originRefs(fixture), originBefore, `${name} rejection changed disposable-origin refs`);
    } finally {
      rmSync(fixture.temp, { recursive: true, force: true });
    }
  });
}

test("schema-2 operator preserves readiness evidence aliases", () => {
  const fixture = makeFixture();
  try {
    const result = run("bash", [OPERATOR, "verify-readiness", "--repo", fixture.repo,
      "--evidence-commit", fixture.receiptCommit, "--evidence", RECEIPT], { cwd: ROOT });
    assert.equal(result.status, 0, `${result.stdout ?? ""}${result.stderr ?? ""}`);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("schema-2 tracking apply removes one admitted fixture ref under the shared coordinator", () => {
  const fixture = makeTrackingFixture();
  try {
    const beforeLocal = refs(fixture.repo);
    const beforeOrigin = git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)");
    assert.ok(beforeLocal.includes(`${fixture.trackingRef}\t${fixture.oid}\tcommit`));
    const commonDir = git(fixture.repo, "rev-parse", "--git-common-dir");
    const coordinatorRoot = join(fixture.repo, commonDir, "sigra-branch-worktree-coordinator");
    const manifest = join(coordinatorRoot, "hooks.manifest.tsv");
    const manifestBytes = readFileSync(manifest);
    rmSync(manifest);
    const missingCoordinator = trackingApply(fixture);
    assert.notEqual(missingCoordinator.status, 0);
    assert.match(`${missingCoordinator.stdout ?? ""}${missingCoordinator.stderr ?? ""}`, /coordinator_hooks_manifest_missing/);
    assert.equal(refs(fixture.repo), beforeLocal, "missing coordinator gate must preserve all local refs");
    assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
      "missing coordinator gate must preserve all origin refs");
    writeFileSync(manifest, manifestBytes);

    const coordinatorLock = join(coordinatorRoot, "lock");
    mkdirSync(coordinatorLock);
    const busyCoordinator = trackingApply(fixture);
    assert.notEqual(busyCoordinator.status, 0);
    assert.match(`${busyCoordinator.stdout ?? ""}${busyCoordinator.stderr ?? ""}`, /coordinator_busy_or_stale_lock_present/);
    assert.equal(refs(fixture.repo), beforeLocal, "busy coordinator gate must preserve all local refs");
    assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
      "busy coordinator gate must preserve all origin refs");
    rmSync(coordinatorLock, { recursive: true, force: true });

    for (const scenario of ["fail", "null", "truncated"]) {
      fixture.env.PRUNE_FIXTURE_PR_SCENARIO = scenario;
      const blocked = trackingApply(fixture);
      assert.notEqual(blocked.status, 0, `${scenario} PR inventory unexpectedly passed`);
      assert.match(`${blocked.stdout ?? ""}${blocked.stderr ?? ""}`, /current_pr_ref_contract_blocked|current_open_pr_set_changed|github_pr_pagination_incomplete/,
        `${scenario} PR inventory needs a named public rejection`);
      assert.equal(refs(fixture.repo), beforeLocal, `${scenario} PR inventory changed local refs`);
      assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
        `${scenario} PR inventory changed origin refs`);
    }
    delete fixture.env.PRUNE_FIXTURE_PR_SCENARIO;

    const movedOid = git(fixture.repo, "rev-parse", "HEAD^");
    git(fixture.repo, "update-ref", fixture.trackingRef, movedOid, fixture.oid);
    const movedLocal = refs(fixture.repo);
    const movedResult = trackingApply(fixture);
    assert.notEqual(movedResult.status, 0, `${movedResult.stdout ?? ""}${movedResult.stderr ?? ""}`);
    assert.match(`${movedResult.stdout ?? ""}${movedResult.stderr ?? ""}`, /evidence_transition_|current_contract|current_local_ref_identity_changed|tracking_ref_/,
      "a moved expected OID must have a named rejection signal");
    assert.equal(refs(fixture.repo), movedLocal, "moved expected-OID rejection must preserve the full local ref inventory");
    assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
      "moved expected-OID rejection must preserve the disposable origin inventory");
    git(fixture.repo, "update-ref", fixture.trackingRef, fixture.oid, movedOid);
    const result = trackingApply(fixture);
    assert.equal(result.status, 0, `${result.stdout ?? ""}${result.stderr ?? ""}`);
    assert.match(result.stdout, new RegExp(`deleted tracking ref ${fixture.trackingRef.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
    const afterLocal = refs(fixture.repo);
    const expectedLocal = beforeLocal.split("\n").filter((row) => !row.startsWith(`${fixture.trackingRef}\t`)).join("\n");
    assert.equal(afterLocal, expectedLocal, "only the admitted tracking ref may disappear");
    assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
      "fixture origin identities must remain unchanged");
    assertSnapshotObjectsReadable(fixture);
    assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${fixture.oid}^{commit}`]).status, 0,
      "the deleted tracking target object remains readable");
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("current-contract cumulative passes carry a tracking deletion into a guarded origin deletion", () => {
  const fixture = makeTrackingFixture({ contractPRs: [{ number: 283, state: "OPEN", headRefName: "fixture-pr-head", baseRefName: "main" }] });
  const remoteRef = "refs/heads/stale/fixture-origin-only";
  const safetyList = `${PHASE_DIR}/245-26-FIXTURE-SAFETY.tsv`;
  const preflight = `${PHASE_DIR}/245-26-FIXTURE-PREFLIGHT.json`;
  const publishPreflight = `${PHASE_DIR}/245-26-FIXTURE-PUBLISH-PREFLIGHT.json`;
  fixture.safetyList = safetyList;
  fixture.preflight = preflight;
  fixture.publishPreflight = publishPreflight;
  try {
    git(fixture.repo, "push", "-q", fixture.bare, `${fixture.oid}:${remoteRef}`);
    const safetyRefs = git(fixture.repo, "for-each-ref", "--format=%(refname)",
      "refs/heads/ci/phase-235-16-source-complete", "refs/heads/safety/local-main-before-release-cleanup-20260831",
      "refs/tags/archive/local-main-pre-235-recovery").split("\n").filter(Boolean);
    for (const ref of safetyRefs) git(fixture.repo, "push", "-q", fixture.bare, `${ref}:${ref}`);
    const safetySourceRef = "refs/heads/safety/local-main-before-release-cleanup-fixture";
    fixture.safetyPublicationRef = safetySourceRef;
    git(fixture.repo, "update-ref", safetySourceRef, fixture.oid);
    git(fixture.repo, "remote", "set-url", "origin", "git@github.com:szTheory/sigra.git");
    const localCapture = run("bash", [OPERATOR, "capture-local", "--repo", fixture.repo,
      "--output", join(fixture.repo, fixture.snapshot)], { cwd: ROOT, env: fixture.env });
    assert.equal(localCapture.status, 0, `${localCapture.stdout ?? ""}${localCapture.stderr ?? ""}`);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), originRefs(fixture));

    const originCapture = run("bash", [OPERATOR, "capture-origin", "--repo", fixture.repo,
      "--output", join(fixture.repo, fixture.originSnapshot)], { cwd: ROOT, env: fixture.env });
    assert.equal(originCapture.status, 0, `${originCapture.stdout ?? ""}${originCapture.stderr ?? ""}`);
    writeFileSync(join(fixture.repo, safetyList), "side\tref\toid\ttype\treason\n");
    const allowlistBytes = `${readFileSync(join(fixture.repo, fixture.allowlist), "utf8")}remote\t${remoteRef}\t${fixture.oid}\tcommit\tdisposable origin candidate\nsafety-publish\t${safetySourceRef}\t${fixture.oid}\tcommit\tdisposable exact safety publication\n`;
    writeFileSync(join(fixture.repo, fixture.allowlist), allowlistBytes);
    const preflightResult = run("bash", [OPERATOR, "preflight-origin-access", "--repo", fixture.repo,
      "--operation", "delete", "--ref", remoteRef, "--output", join(fixture.repo, preflight)], {
      cwd: ROOT, env: fixture.env,
    });
    assert.equal(preflightResult.status, 0, `${preflightResult.stdout ?? ""}${preflightResult.stderr ?? ""}`);
    const publishPreflightResult = run("bash", [OPERATOR, "preflight-origin-access", "--repo", fixture.repo,
      "--operation", "publish", "--ref", safetySourceRef, "--output", join(fixture.repo, publishPreflight)], {
      cwd: ROOT, env: fixture.env,
    });
    assert.equal(publishPreflightResult.status, 0, `${publishPreflightResult.stdout ?? ""}${publishPreflightResult.stderr ?? ""}`);

    const contractCapture = run(process.execPath, [join(ROOT, "scripts/maintainers/prune-stale-branches-current.mjs"),
      "capture", "--repo", fixture.repo, "--output", fixture.contract, "--source-fixture", fixture.sourceFixture,
      "--contract-evidence-path", fixture.snapshot, "--contract-evidence-path", fixture.allowlist,
      "--contract-evidence-path", fixture.originSnapshot,
      "--contract-evidence-path", safetyList, "--contract-evidence-path", preflight,
      "--contract-evidence-path", publishPreflight,
      "--final-blocked-path", `${PHASE_DIR}/245-26-FIXTURE-RESULT.json`,
      "--final-passed-path", `${PHASE_DIR}/245-26-FIXTURE-POST-STATE.json`,
      "--final-passed-path", `${PHASE_DIR}/245-26-FIXTURE-RESULT.json`,
      "--final-passed-path", `${PHASE_DIR}/245-26-FIXTURE-SUMMARY.md`,
      "--result-path", `${PHASE_DIR}/245-26-FIXTURE-RESULT.json`], { cwd: fixture.repo, env: fixture.env });
    assert.equal(contractCapture.status, 0, `${contractCapture.stdout ?? ""}${contractCapture.stderr ?? ""}`);
    const contractPaths = [fixture.snapshot, fixture.allowlist, fixture.originSnapshot, safetyList, preflight, publishPreflight, fixture.contract, `${fixture.contract}.sha256`];
    fixture.contractCommit = commit(fixture.repo, contractPaths, "fixture: commit cumulative current contract and evidence");
    fixture.allowlistCommit = fixture.contractCommit;
    fixture.originSnapshotCommit = fixture.contractCommit;
    fixture.snapshotCommit = fixture.contractCommit;
    fixture.safetyList = fixture.allowlist;
    const preflightCommit = fixture.contractCommit;

    const localBefore = refs(fixture.repo);
    const originBefore = originRefs(fixture);
    assert.ok(localBefore.includes(`${fixture.trackingRef}\t${fixture.oid}\tcommit`));
    assert.ok(originBefore.includes(`${remoteRef}\t${fixture.oid}\tcommit`));
    const published = safetyPublishApply(fixture, preflightCommit);
    assert.equal(published.status, 0, `${published.stdout ?? ""}${published.stderr ?? ""}`);
    assert.ok(originRefs(fixture).includes(`${safetySourceRef}\t${fixture.oid}\tcommit`), "only the absent safety ref publishes at its exact identity");

    const firstPass = trackingApply(fixture, [safetySourceRef]);
    assert.equal(firstPass.status, 0, `${firstPass.stdout ?? ""}${firstPass.stderr ?? ""}`);
    assert.ok(!refs(fixture.repo).includes(`${fixture.trackingRef}\t`), `first pass removes only the exact tracking row: ${firstPass.stdout}\n${firstPass.stderr}\n${refs(fixture.repo)}`);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), "first pass leaves origin unchanged");

    const cliBytes = readFileSync(fixture.liveCliPRs, "utf8");
    const apiBytes = readFileSync(fixture.liveApiPRs, "utf8");
    const changedBaseOid = "a".repeat(fixture.oid.length);
    const changedCli = JSON.parse(cliBytes);
    changedCli[0].baseRefOid = changedBaseOid;
    const changedApiOid = JSON.parse(apiBytes);
    changedApiOid[0].base.sha = changedBaseOid;
    writeFileSync(fixture.liveCliPRs, JSON.stringify(changedCli));
    writeFileSync(fixture.liveApiPRs, JSON.stringify(changedApiOid));
    const blockedChangedBase = remoteApply(fixture, preflightCommit, [safetySourceRef, fixture.trackingRef]);
    assert.notEqual(blockedChangedBase.status, 0, "a changed PR base OID blocks the next operation boundary");
    assert.match(`${blockedChangedBase.stdout ?? ""}${blockedChangedBase.stderr ?? ""}`, /current_pr_base_oid_changed:283/);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), "changed PR base OID cannot authorize origin deletion");
    writeFileSync(fixture.liveCliPRs, cliBytes);
    writeFileSync(fixture.liveApiPRs, apiBytes);

    const changedApiRepository = JSON.parse(apiBytes);
    changedApiRepository[0].base.repo.full_name = "szTheory/other";
    writeFileSync(fixture.liveApiPRs, JSON.stringify(changedApiRepository));
    const blockedChangedRepository = remoteApply(fixture, preflightCommit, [safetySourceRef, fixture.trackingRef]);
    assert.notEqual(blockedChangedRepository.status, 0, "a changed PR base repository blocks the next operation boundary");
    assert.match(`${blockedChangedRepository.stdout ?? ""}${blockedChangedRepository.stderr ?? ""}`, /current_pr_base_repository_changed:283/);
    writeFileSync(fixture.liveCliPRs, cliBytes);
    writeFileSync(fixture.liveApiPRs, apiBytes);

    const blockedInvented = remoteApply(fixture, preflightCommit, [safetySourceRef, "refs/heads/not-admitted"]);
    assert.notEqual(blockedInvented.status, 0, "invented cumulative identity must be rejected");
    assert.match(`${blockedInvented.stdout ?? ""}${blockedInvented.stderr ?? ""}`, /evidence_transition_applied_ref_not_allowlisted/);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), "invalid cumulative input cannot mutate origin");

    const secondPass = remoteApply(fixture, preflightCommit, [safetySourceRef, fixture.trackingRef]);
    assert.equal(secondPass.status, 0, `${secondPass.stdout ?? ""}${secondPass.stderr ?? ""}`);
    assert.ok(!originRefs(fixture).includes(`${remoteRef}\t`), "second pass removes the exact expected-OID origin row");
    assertSnapshotObjectsReadable(fixture);
    assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${fixture.oid}^{commit}`]).status, 0,
      "the object remains readable after both exact fixture operations");
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

test("tracking apply serializes a concurrent local tracking-ref update and blocks on the following PR gate", async () => {
  const fixture = makeTrackingFixture();
  const readyFifo = join(fixture.temp, "tracking-race-ready.fifo");
  const releaseFifo = join(fixture.temp, "tracking-race-release.fifo");
  const callCount = join(fixture.temp, "tracking-race-gh-count");
  execFileSync("mkfifo", [readyFifo]);
  execFileSync("mkfifo", [releaseFifo]);
  fixture.env.PRUNE_FIXTURE_RACE_READY_FIFO = readyFifo;
  fixture.env.PRUNE_FIXTURE_RACE_RELEASE_FIFO = releaseFifo;
  fixture.env.PRUNE_FIXTURE_RACE_CALL_COUNT = callCount;
  let running;
  let released = false;
  let rendezvousReached = false;
  try {
    const beforeLocal = refs(fixture.repo);
    const beforeOrigin = originRefs(fixture);
    const rendezvous = readFifo(readyFifo);
    running = startTrackingApply(fixture);
    assert.equal(await rendezvous, "ready");
    rendezvousReached = true;
    const commonDir = git(fixture.repo, "rev-parse", "--git-common-dir");
    const lock = join(fixture.repo, commonDir, "sigra-branch-worktree-coordinator", "lock");
    assert.ok(existsSync(lock), "PR rendezvous must happen while the public operator holds the coordinator lock");

    const movedOid = git(fixture.repo, "rev-parse", "HEAD^");
    const unownedEnv = { ...process.env };
    delete unownedEnv.SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN;
    delete unownedEnv.SIGRA_BRANCH_WORKTREE_COORDINATOR_ROOT;
    delete unownedEnv.SIGRA_COORDINATOR_HELD;
    const competingUpdate = run(GIT, ["-C", fixture.repo, "update-ref", "--no-deref", fixture.trackingRef, movedOid, fixture.oid], { env: unownedEnv });
    assert.notEqual(competingUpdate.status, 0, "an unowned concurrent tracking-ref update must be rejected");
    assert.match(`${competingUpdate.stdout ?? ""}${competingUpdate.stderr ?? ""}`, /branch_or_worktree_ref_change_during_coordinator_window/);
    assert.equal(refs(fixture.repo), beforeLocal, "the competing update must preserve the complete local ref inventory");
    assert.equal(originRefs(fixture), beforeOrigin, "the competing update must preserve the complete bare-origin inventory");

    writeFileSync(releaseFifo, "continue\n");
    released = true;
    const apply = await running.closed;
    assert.notEqual(apply.status, 0, `${apply.stdout}${apply.stderr}`);
    assert.match(`${apply.stdout}${apply.stderr}`, /current_pr_ref_contract_blocked:boundary:tracking:refs\/remotes\/origin\/stale\/fixture-only/);
    assert.match(`${apply.stdout}${apply.stderr}`, /gh_pr_list_failed/);
    assert.equal(refs(fixture.repo), beforeLocal, "the interrupted operation boundary must not delete the admitted tracking ref");
    assert.equal(originRefs(fixture), beforeOrigin, "the blocked operation must preserve the complete bare-origin inventory");
    assertSnapshotObjectsReadable(fixture);
  } finally {
    if (!released && rendezvousReached && running && running.child.exitCode === null) {
      try { writeFileSync(releaseFifo, "continue\n"); } catch { /* cleanup path after an assertion failure */ }
    }
    if (running && running.child.exitCode === null) {
      running.child.kill("SIGTERM");
      await running.closed.catch(() => undefined);
    }
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});

for (const protectedSide of ["head", "base"]) {
  test(`tracking apply blocks a protected PR ${protectedSide} without changing fixture refs`, () => {
    const fixture = makeTrackingFixture({
      contractPRs: [{ number: 17, state: "OPEN",
        headRefName: protectedSide === "head" ? "stale/fixture-only" : "feature/safe",
        baseRefName: protectedSide === "base" ? "stale/fixture-only" : "main" }],
    });
    try {
      const beforeLocal = refs(fixture.repo);
      const beforeOrigin = git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)");
      const result = trackingApply(fixture);
      assert.notEqual(result.status, 0);
      assert.match(`${result.stdout ?? ""}${result.stderr ?? ""}`, /current_allowlist_overlaps_pr_head_or_base/);
      assert.equal(refs(fixture.repo), beforeLocal, "protected PR gate must preserve all local refs");
      assert.equal(git(fixture.bare, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)"), beforeOrigin,
        "protected PR gate must preserve all origin refs");
    } finally {
      rmSync(fixture.temp, { recursive: true, force: true });
    }
  });
}

test("tracking apply treats complete PR row order as an unordered identity set", () => {
  const prRows = [
    { number: 31, state: "OPEN", headRefName: "feature/first", baseRefName: "main" },
    { number: 32, state: "OPEN", headRefName: "feature/second", baseRefName: "main" },
  ];
  const fixture = makeTrackingFixture({ contractPRs: prRows, liveCliPRs: [...prRows].reverse(), liveApiPRs: [...prRows].reverse() });
  try {
    const before = refs(fixture.repo);
    const beforeOrigin = originRefs(fixture);
    const result = trackingApply(fixture);
    assert.equal(result.status, 0, `${result.stdout ?? ""}${result.stderr ?? ""}`);
    const expected = before.split("\n").filter((row) => !row.startsWith(`${fixture.trackingRef}\t`)).join("\n");
    assert.equal(refs(fixture.repo), expected, "row permutation must preserve exact admitted mutation semantics");
    assert.equal(originRefs(fixture), beforeOrigin, "row permutation must leave disposable origin unchanged");
    assertSnapshotObjectsReadable(fixture);
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
  }
});
