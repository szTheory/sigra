import assert from "node:assert/strict";
import { execFileSync, spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

const ROOT = process.cwd();
const GIT = "/usr/bin/git";
const OPERATOR = join(ROOT, "scripts/maintainers/prune-stale-branches.sh");
const READINESS = join(ROOT, "scripts/maintainers/prune-stale-branches-readiness.mjs");
const RECEIPT = ".planning/phases/245-branch-prune-local-and-remote/245-READINESS.json";
const PHASE_DIR = ".planning/phases/245-branch-prune-local-and-remote";
const PLAN45_RESULT = join(ROOT, PHASE_DIR, "245-45-RESULT.json");
const DIAGNOSTIC = join(ROOT, PHASE_DIR, "245-46-DIAGNOSTIC.json");
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
  if (options.omitCiTrackingRef) git(fixture.repo, "update-ref", "-d", "refs/remotes/origin/ci/phase-235-16-source-complete");
  const bare = fixture.bare;
  const bin = join(fixture.temp, "bin");
  const ssh = join(bin, "fixture-ssh");
  const gh = join(bin, "gh");
  mkdirSync(bin);
  writeFileSync(ssh, `#!/usr/bin/env bash
set -euo pipefail
started_ns="$(node -p 'process.hrtime.bigint().toString()')"
stage=git_transport_ls_remote
[[ "$*" == *git-receive-pack* ]] && stage=git_transport_receive_pack
rows="$(/usr/bin/git --git-dir="$PRUNE_FIXTURE_BARE" for-each-ref --format='%(refname)' | wc -l | tr -d ' ')"
trace_exit() {
  local status=$?
  if [[ -n "\${PRUNE_FIXTURE_TRACE_FILE:-}" ]]; then
    node -e 'const fs=require("node:fs"); const [path,stage,endpoint,start,end,status,rows,delay]=process.argv.slice(1); fs.appendFileSync(path, JSON.stringify({stage,endpoint,started_ns:start,ended_ns:end,elapsed_ms:Number(end-start)/1e6,status:Number(status),row_count:Number(rows),injected_latency_ms:Number(delay)})+"\\n")' \\
      "$PRUNE_FIXTURE_TRACE_FILE" "$stage" "$*" "$started_ns" "$(node -p 'process.hrtime.bigint().toString()')" "$status" "$rows" "\${PRUNE_FIXTURE_DELAY_MS:-0}"
  fi
}
trap trace_exit EXIT
host_seen=0
request=""
for arg in "$@"; do
  [[ "$arg" == git@github.com ]] && host_seen=1
  [[ "$arg" == *git-upload-pack* || "$arg" == *git-receive-pack* ]] && request="$arg"
done
[[ "$host_seen" == 1 ]] || { echo 'fixture SSH rejected unknown host' >&2; exit 91; }
[[ "$request" =~ ^git-(upload|receive)-pack[[:space:]]+[\\\"\\\']?szTheory/sigra\\.git[\\\"\\\']?$ ]] \\
  || { echo "fixture SSH rejected request: $request" >&2; exit 92; }
if [[ "\${PRUNE_FIXTURE_HOLD_SSH:-0}" == 1 ]]; then
  printf '%s\\n' "$$" > "$PRUNE_FIXTURE_HOLD_MARKER"
  sleep 30 &
  wait "$!"
fi
if [[ "\${PRUNE_FIXTURE_DELAY_MS:-0}" != 0 ]]; then sleep "0.$(printf '%03d' "$PRUNE_FIXTURE_DELAY_MS")"; fi
if [[ "$request" == git-receive-pack* ]]; then
  /usr/bin/git-receive-pack "$PRUNE_FIXTURE_BARE"
  exit $?
fi
/usr/bin/git-upload-pack "$PRUNE_FIXTURE_BARE"
exit $?
`);
  chmodSync(ssh, 0o755);
  writeFileSync(gh, `#!/usr/bin/env bash
set -euo pipefail
started_ns="$(node -p 'process.hrtime.bigint().toString()')"
endpoint="$*"
stage=github_cli
[[ "$endpoint" == api* ]] && stage=github_rest_paging
rows=0
[[ "$endpoint" == pr* || "$endpoint" == *'/pulls?'* ]] && rows="\${PRUNE_FIXTURE_PR_COUNT:-0}"
trace_exit() {
  local status=$?
  if [[ -n "\${PRUNE_FIXTURE_TRACE_FILE:-}" ]]; then
    node -e 'const fs=require("node:fs"); const [path,stage,endpoint,start,end,status,rows,delay]=process.argv.slice(1); fs.appendFileSync(path, JSON.stringify({stage,endpoint,started_ns:start,ended_ns:end,elapsed_ms:Number(end-start)/1e6,status:Number(status),row_count:Number(rows),injected_latency_ms:Number(delay)})+"\\n")' \\
      "$PRUNE_FIXTURE_TRACE_FILE" "$stage" "$endpoint" "$started_ns" "$(node -p 'process.hrtime.bigint().toString()')" "$status" "$rows" "\${PRUNE_FIXTURE_DELAY_MS:-0}"
  fi
}
trap trace_exit EXIT
if [[ "\${PRUNE_FIXTURE_HOLD_GH_PAGE:-0}" == 1 && "$endpoint" == *'/pulls?'* ]]; then
  rows=0
  printf '%s\\n' "$$" > "$PRUNE_FIXTURE_HOLD_MARKER"
  sleep 30 &
  wait "$!"
fi
if [[ "\${PRUNE_FIXTURE_DELAY_MS:-0}" != 0 ]]; then sleep "0.$(printf '%03d' "$PRUNE_FIXTURE_DELAY_MS")"; fi
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
  if (options.productionScale) {
    let localCount = refs(fixture.repo).split("\n").filter(Boolean).length;
    for (let index = 1; localCount < 106; index += 1) {
      git(fixture.repo, "update-ref", `refs/heads/fixture-scale/local-${String(index).padStart(3, "0")}`, oid);
      localCount += 1;
    }
    let originCount = git(bare, "for-each-ref", "--format=%(refname)").split("\n").filter(Boolean).length;
    for (let index = 1; originCount < 360; index += 1) {
      git(bare, "update-ref", `refs/heads/fixture-scale/origin-${String(index).padStart(3, "0")}`, oid);
      originCount += 1;
    }
    git(fixture.repo, "fetch", "-q", "origin", "+refs/heads/*:refs/remotes/origin/*");
    const pulls = [];
    for (let index = 1; index <= 14; index += 1) {
      const number = 9000 + index;
      git(fixture.repo, "-c", "user.name=Fixture PR", "-c", "user.email=fixture-pr@example.invalid", "commit", "--allow-empty", "-q", "-m", `fixture PR ${number}`);
      const headOid = git(fixture.repo, "rev-parse", "HEAD");
      const headRefName = `fixture-scale/pr-${number}`;
      git(fixture.repo, "update-ref", `refs/heads/${headRefName}`, headOid);
      pulls.push({ number, state: "OPEN", headRefName, baseRefName: "main", headRefOid: headOid,
        baseRefOid: oid, headRepository: { nameWithOwner: "szTheory/sigra" } });
    }
    options.contractPRs = pulls;
    options.liveCliPRs = pulls;
    options.liveApiPRs = pulls;
    fixture.scale = { local_ref_count: localCount + pulls.length, origin_ref_count: originCount, open_pr_count: pulls.length };
  }

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
    PRUNE_FIXTURE_PR_CLI_JSON: cliJson, PRUNE_FIXTURE_PR_API_JSON: apiJson, PRUNE_FIXTURE_PR_TRUNCATED_JSON: truncatedJson,
    PRUNE_FIXTURE_PR_COUNT: String(options.contractPRs?.length ?? 0) };
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

function plan45TrackingArgs(fixture) {
  return [OPERATOR, "tracking", "--repo", fixture.repo, "--apply",
    "--snapshot-commit", fixture.snapshotCommit, "--snapshot", fixture.snapshot,
    "--readiness-commit", fixture.receiptCommit, "--readiness", RECEIPT,
    "--current-contract-commit", fixture.contractCommit, "--current-contract", fixture.contract,
    "--allowlist-commit", fixture.allowlistCommit, "--allowlist", fixture.allowlist];
}

function processGroupSnapshot(pgid) {
  const result = spawnSync("/bin/ps", ["-axo", "pid=,ppid=,pgid=,command="], { encoding: "utf8" });
  if (result.status !== 0) return [];
  return result.stdout.split("\n").map((line) => line.trim()).filter((line) => {
    const columns = line.split(/\s+/, 4);
    return columns[2] === String(pgid);
  });
}

async function waitForPath(path, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (!existsSync(path) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert.ok(existsSync(path), `bounded fixture child did not reach hold point: ${path}`);
}

function startBoundedTrackingApply(fixture, { silenceMs = 10_000, totalMs = 20_000, xtrace = true } = {}) {
  const argv = plan45TrackingArgs(fixture);
  const trace = [];
  const child = spawn("bash", [...(xtrace ? ["-x"] : []), ...argv], {
    cwd: ROOT,
    env: { ...fixture.env, PS4: "+${SECONDS}s pid=$$ line=${LINENO}: " },
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "";
  let stderr = "";
  let lastOutputAt = new Date().toISOString();
  let interruptedAt = null;
  let activeGroup = [];
  let escalationSignal = null;
  const append = (kind, chunk) => {
    const text = chunk.toString("utf8");
    lastOutputAt = new Date().toISOString();
    trace.push({ at: lastOutputAt, stream: kind, text });
    if (kind === "stdout") stdout += text;
    else stderr += text;
  };
  child.stdout.on("data", (chunk) => append("stdout", chunk));
  child.stderr.on("data", (chunk) => append("stderr", chunk));
  const startedAt = new Date().toISOString();
  const close = new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (status, signal) => resolve({ status, signal }));
  });
  const ended = new Promise((resolve) => {
    let closed = false;
    let silenceTimer;
    const totalTimer = setTimeout(() => interrupt("total_runtime_limit"), totalMs);
    function clear() {
      closed = true;
      clearTimeout(silenceTimer);
      clearTimeout(totalTimer);
    }
    function interrupt(reason) {
      if (closed || interruptedAt) return;
      interruptedAt = { at: new Date().toISOString(), reason, signal: "SIGINT" };
      activeGroup = processGroupSnapshot(child.pid);
      try { process.kill(-child.pid, "SIGINT"); } catch {}
      const escalate = setTimeout(() => {
        if (closed) return;
        escalationSignal = "SIGTERM";
        try { process.kill(-child.pid, "SIGTERM"); } catch {}
      }, 1500);
      close.then((result) => {
        clearTimeout(escalate);
        clear();
        resolve(result);
      }, (error) => {
        clearTimeout(escalate);
        clear();
        reject(error);
      });
    }
    function armSilence() {
      clearTimeout(silenceTimer);
      silenceTimer = setTimeout(() => interrupt("silence_limit"), silenceMs);
    }
    child.stdout.on("data", armSilence);
    child.stderr.on("data", armSilence);
    close.then((result) => { if (!interruptedAt) { clear(); resolve(result); } }, (error) => { clear(); reject(error); });
    armSilence();
  });
  return { child, argv, trace, close: ended, startedAt, lastOutputAt: () => lastOutputAt,
    interruptedAt: () => interruptedAt, activeGroup: () => activeGroup, escalationSignal: () => escalationSignal,
    xtrace: () => "",
    output: () => ({ stdout, stderr }) };
}

function sanitizeXtrace(text) {
  return text.split("\n").filter(Boolean).map((line) => line
    .replace(/((?:token|secret|password|authorization)[^= ]*=)[^ \t]+/gi, "$1[REDACTED]")
    .replace(/\btoken ([^ ;]+)/gi, "token [REDACTED]")
    .replace(/\b[0-9a-f]{40,64}\b/gi, "[REDACTED_HEX]")
    .replace(/(?:\\[0-9a-f]){40,64}/gi, "[REDACTED_ESCAPED_HEX]"));
}

function separateXtrace(text) {
  const lines = text.split(/\r?\n/);
  const xtrace = lines.filter((line) => /^\+{1,}\d+s pid=\d+ line=\d+: /.test(line));
  const output = lines.filter((line) => !/^\+{1,}\d+s pid=\d+ line=\d+: /.test(line));
  return { xtrace: sanitizeXtrace(xtrace.join("\n")), output: output.join("\n").trim() };
}

function xtraceCommands(lines) {
  return lines.filter((line) => /^\+/.test(line)).map((line) => line.slice(1));
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

test("production-scale tracking source latency", async () => {
  const productionRefsBefore = refs(ROOT);
  const plan45Digest = createHash("sha256").update(readFileSync(PLAN45_RESULT)).digest("hex");
  const scenarios = [];
  const runScenario = async ({ name, delayMs = 0, holdGitHubPage = false, fixture: existingFixture = null, cleanup = true }) => {
    const fixture = existingFixture ?? makeTrackingFixture({ productionScale: true });
    const commonDir = git(fixture.repo, "rev-parse", "--git-common-dir");
    const resolvedCommonDir = commonDir.startsWith("/") ? commonDir : join(fixture.repo, commonDir);
    assert.ok(resolvedCommonDir.startsWith(fixture.temp), "production-cardinality fixture common directory stays disposable");
    assert.ok(!resolvedCommonDir.startsWith(join(ROOT, ".git")), "fixture never shares the production Git common directory");
    const tracePath = join(fixture.temp, "external-source-spans.jsonl");
    writeFileSync(tracePath, "");
    fixture.env.PRUNE_FIXTURE_TRACE_FILE = tracePath;
    fixture.env.PRUNE_FIXTURE_DELAY_MS = String(delayMs);
    const holdMarker = join(fixture.temp, "held-source.pid");
    if (holdGitHubPage) {
      fixture.env.PRUNE_FIXTURE_HOLD_GH_PAGE = "1";
      fixture.env.PRUNE_FIXTURE_HOLD_MARKER = holdMarker;
    }
    const localBefore = refs(fixture.repo);
    const originBefore = originRefs(fixture);
    const prs = JSON.parse(readFileSync(fixture.liveCliPRs, "utf8"));
    assert.ok(localBefore.split("\n").filter(Boolean).length >= 106, "synthetic local ref cardinality meets the observed source count");
    assert.ok(originBefore.split("\n").filter(Boolean).length >= 360, "synthetic origin ref cardinality meets the observed source count");
    assert.equal(prs.length, 14, "fixture contains the observed open PR cardinality");
    assert.equal(new Set(prs.map((pull) => pull.number)).size, 14, "PR numbers are unique");
    assert.equal(new Set(prs.map((pull) => pull.headRefName)).size, 14, "PR head names are unique");
    assert.equal(new Set(prs.map((pull) => pull.headRefOid)).size, 14, "PR head OIDs are unique");
    let result;
    let output;
    let interrupt = null;
    if (holdGitHubPage) {
      const running = startBoundedTrackingApply(fixture, { silenceMs: 1500, totalMs: 10_000, xtrace: false });
      await waitForPath(holdMarker);
      result = await running.close;
      output = running.output();
      interrupt = running.interruptedAt();
      assert.equal(running.escalationSignal(), null, "held external source exits after the single watchdog interrupt");
    } else {
      const running = startBoundedTrackingApply(fixture, { silenceMs: 90_000, totalMs: 180_000, xtrace: false });
      result = await running.close;
      output = running.output();
    }
    const localAfter = refs(fixture.repo);
    const originAfter = originRefs(fixture);
    const spans = readFileSync(tracePath, "utf8").split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
    assert.ok(spans.length > 0, `${name} records external-source spans`);
    assert.ok(spans.every((span) => span.started_ns && span.ended_ns && Number.isFinite(span.elapsed_ms)
      && Number.isInteger(span.status) && Number.isInteger(span.row_count)), `${name} spans include monotonic timing, status, and row count`);
    assert.ok(spans.some((span) => span.stage === "github_rest_paging"), `${name} records REST pagination calls`);
    if (!holdGitHubPage) {
      assert.ok(spans.some((span) => span.stage === "github_rest_paging" && span.endpoint.includes("page=1") && span.row_count === 14),
        `${name} records the complete single-page inventory of 14 open PRs`);
      assert.ok(spans.some((span) => span.stage === "github_cli"), `${name} records GitHub CLI calls`);
      assert.ok(spans.some((span) => span.stage === "git_transport_ls_remote"), `${name} records Git transport source calls`);
    }
    if (holdGitHubPage) {
      assert.ok(spans.some((span) => span.stage === "github_cli"), `${name} records CLI inventory before the held REST call`);
      assert.ok(spans.some((span) => span.stage === "github_rest_paging" && span.status !== 0 && span.row_count === 0),
        `${name} identifies the interrupted REST page without claiming returned rows`);
    }
    if (delayMs) assert.ok(spans.every((span) => span.injected_latency_ms === delayMs), "controlled delay is disclosed on every source span");
    if (holdGitHubPage) {
      assert.ok(interrupt, "held external source reaches watchdog");
      assert.equal(interrupt.reason, "silence_limit");
      assert.equal(interrupt.signal, "SIGINT");
      assert.notEqual(result.status, 0, "held external source fails closed");
      assert.equal(localAfter, localBefore, "held source leaves fixture local refs exact");
      assert.equal(originAfter, originBefore, "held source leaves fixture origin refs exact");
    } else {
      assert.equal(result.status, 0, `${name} public tracking apply succeeds: ${output.stdout}${output.stderr}`);
      assert.ok(output.stdout.includes(`deleted tracking ref ${fixture.trackingRef}`), `${name} deletes the exact admitted fixture ref`);
      const expectedLocal = localBefore.split("\n").filter((row) => !row.startsWith(`${fixture.trackingRef}\t`)).join("\n");
      assert.equal(localAfter, expectedLocal, `${name} changes only the admitted fixture ref`);
      assert.equal(originAfter, originBefore, `${name} preserves every origin ref`);
      assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${fixture.oid}^{commit}`]).status, 0,
        `${name} keeps the deleted target object readable`);
    }
    const report = {
      name,
      source_counts: {
        local_ref_count: localBefore.split("\n").filter(Boolean).length,
        origin_ref_count: originBefore.split("\n").filter(Boolean).length,
        open_pr_count: prs.length,
      },
      delay_ms: delayMs,
      watchdog_ms: holdGitHubPage ? { silence: 1500, total: 10_000 } : { silence: 90_000, total: 180_000 },
      outcome: { status: result.status, signal: result.signal, interrupted: interrupt, target_after: localAfter.includes(`${fixture.trackingRef}\t`) ? "exact_present" : "absent" },
      local_refs_exact_except_target: holdGitHubPage ? localAfter === localBefore
        : localAfter === localBefore.split("\n").filter((row) => !row.startsWith(`${fixture.trackingRef}\t`)).join("\n"),
      origin_refs_unchanged: originAfter === originBefore,
      external_source_spans: spans,
      elapsed_source_ms: spans.reduce((sum, span) => sum + span.elapsed_ms, 0),
    };
    if (cleanup) rmSync(fixture.temp, { recursive: true, force: true });
    scenarios.push(report);
  };

  const heldFixture = makeTrackingFixture({ productionScale: true });
  await runScenario({ name: "held_github_rest_page", holdGitHubPage: true, fixture: heldFixture, cleanup: false });
  delete heldFixture.env.PRUNE_FIXTURE_HOLD_GH_PAGE;
  delete heldFixture.env.PRUNE_FIXTURE_HOLD_MARKER;
  await runScenario({ name: "zero_latency", fixture: heldFixture });
  await runScenario({ name: "injected_35ms_per_source_call", delayMs: 35 });
  assert.equal(refs(ROOT), productionRefsBefore, "production ref inventory is unchanged across every fixture run");
  assert.equal(createHash("sha256").update(readFileSync(PLAN45_RESULT)).digest("hex"), plan45Digest,
    "Plan 45 result bytes are unchanged");
  const spans = scenarios.flatMap((scenario) => scenario.external_source_spans.map((span) => ({ scenario: scenario.name, ...span })));
  const latency = scenarios.find((scenario) => scenario.name === "injected_35ms_per_source_call");
  const diagnostic = {
    schema_version: 1,
    phase: "245-branch-prune-local-and-remote",
    plan: 46,
    status: "blocked_unlocalized",
    captured_at_utc: new Date().toISOString(),
    operation: "public tracking --apply in disposable production-cardinality fixtures",
    command: { executable: "node", argv: ["--test", "--test-name-pattern=production-scale tracking source latency", "scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs"] },
    fixture: {
      local_ref_count: scenarios[0].source_counts.local_ref_count,
      origin_ref_count: scenarios[0].source_counts.origin_ref_count,
      open_pr_count: scenarios[0].source_counts.open_pr_count,
      identities: "synthetic and unique; 14 distinct PR numbers, head refs, and head commit OIDs",
      scenarios: scenarios.map(({ external_source_spans: _spans, ...scenario }) => scenario),
    },
    external_source_spans: spans,
    latency_summary: {
      injected_per_call_ms: 35,
      delayed_source_call_count: latency.external_source_spans.length,
      delayed_source_elapsed_ms: latency.elapsed_source_ms,
      stages: [...new Set(latency.external_source_spans.map((span) => span.stage))].sort(),
      interpretation: "Synthetic external-source delay is measured but cannot be linked causally to Plan 44, which recorded no production stage spans.",
    },
    cause: { kind: "synthetic_latency_only", stage: "fixture_external_sources", bounded_ms: latency.elapsed_source_ms },
    regression: { red_observed: false, green_observed: false, passed: false, reason: "No deterministic operator defect was reproduced; no repair was attempted." },
    production_ref_operations: 0,
    production_refs_unchanged: true,
    plan45_result_sha256: plan45Digest,
    plan45_result_bytes_unchanged: true,
    repo_04_status: "open",
    live_admission_permitted: false,
    blockers: ["fixture_latency_not_linked_to_plan44_production_stage", "no_reproduced_operator_defect"],
    next_missing_signal: "A production-stage trace for Plan 44 is required to identify whether REST paging, Git transport, local validation, or coordinator work caused its 600713 ms silence.",
  };
  writeFileSync(DIAGNOSTIC, `${JSON.stringify(diagnostic, null, 2)}\n`);
});

test("tracking operator bounded fixture diagnosis", async () => {
  const productionRefsBefore = refs(ROOT);
  const fixture = makeTrackingFixture();
  let heldFixture;
  try {
    const commonDir = git(fixture.repo, "rev-parse", "--git-common-dir");
    const resolvedCommonDir = commonDir.startsWith("/") ? commonDir : join(fixture.repo, commonDir);
    assert.ok(resolvedCommonDir.startsWith(fixture.temp), "fixture common directory must stay disposable");
    assert.ok(!resolvedCommonDir.startsWith(join(ROOT, ".git")), "fixture must never share production Git common-dir");

    const localBefore = refs(fixture.repo);
    const originBefore = originRefs(fixture);
    const prsBefore = readFileSync(fixture.liveCliPRs, "utf8");
    const normal = startBoundedTrackingApply(fixture);
    const normalResult = await normal.close;
    const normalCompletedAt = new Date().toISOString();
    const normalOutput = normal.output();
    const normalLocalAfter = refs(fixture.repo);
    const normalOriginAfter = originRefs(fixture);
    assert.equal(normalResult.status, 0, `${normalOutput.stdout}${normalOutput.stderr}`);
    assert.ok(normalOutput.stdout.includes(`deleted tracking ref ${fixture.trackingRef}`),
      "public tracking command must report exact fixture deletion");
    const localExpected = localBefore.split("\n").filter((row) => !row.startsWith(`${fixture.trackingRef}\t`)).join("\n");
    assert.equal(normalLocalAfter, localExpected, "successful public pass changes only the admitted fixture tracking ref");
    assert.equal(normalOriginAfter, originBefore, "successful public pass leaves origin identities unchanged");
    assert.equal(readFileSync(fixture.liveCliPRs, "utf8"), prsBefore, "fixture open-PR identities remain unchanged");
    assert.equal(run(GIT, ["-C", fixture.repo, "cat-file", "-e", `${fixture.oid}^{commit}`]).status, 0,
      "the deleted tracking target commit remains readable");
    assertSnapshotObjectsReadable(fixture);

    heldFixture = makeTrackingFixture();
    const holdMarker = join(heldFixture.temp, "held-child.pid");
    heldFixture.env.PRUNE_FIXTURE_HOLD_SSH = "1";
    heldFixture.env.PRUNE_FIXTURE_HOLD_MARKER = holdMarker;
    const heldLocalBefore = refs(heldFixture.repo);
    const heldOriginBefore = originRefs(heldFixture);
    const heldPrsBefore = readFileSync(heldFixture.liveCliPRs, "utf8");
    const held = startBoundedTrackingApply(heldFixture, { silenceMs: 1500, totalMs: 10_000 });
    await waitForPath(holdMarker);
    const heldResult = await held.close;
    const heldOutput = held.output();
    const heldLocalAfter = refs(heldFixture.repo);
    const heldOriginAfter = originRefs(heldFixture);
    const interrupt = held.interruptedAt();
    assert.ok(interrupt, "held fixture child must trip watchdog");
    assert.equal(interrupt.reason, "silence_limit");
    assert.equal(interrupt.signal, "SIGINT");
    assert.equal(held.escalationSignal(), null, "the single watchdog interrupt should stop the fixture group");
    assert.notEqual(heldResult.status, 0, "held fixture apply must terminate as interrupted");
    assert.equal(heldLocalAfter, heldLocalBefore, "interrupted pass must preserve all fixture local refs");
    assert.equal(heldOriginAfter, heldOriginBefore, "interrupted pass must preserve all fixture origin refs");
    assert.equal(readFileSync(heldFixture.liveCliPRs, "utf8"), heldPrsBefore,
      "interrupted pass must preserve the fixture open-PR inventory");
    const coordinatorRoot = join(heldFixture.repo, git(heldFixture.repo, "rev-parse", "--git-common-dir"),
      "sigra-branch-worktree-coordinator");
    assert.equal(existsSync(join(coordinatorRoot, "lock")), false, "interrupted operator releases the fixture coordinator");
    assert.equal(refs(ROOT), productionRefsBefore, "diagnosis leaves production local refs unchanged");

    const normalStdout = separateXtrace(normalOutput.stdout);
    const normalStderr = separateXtrace(normalOutput.stderr);
    const heldStdout = separateXtrace(heldOutput.stdout);
    const heldStderr = separateXtrace(heldOutput.stderr);
    const normalXtrace = [...normalStdout.xtrace, ...normalStderr.xtrace];
    const heldXtrace = [...heldStdout.xtrace, ...heldStderr.xtrace];
    const normalCommands = xtraceCommands(normalXtrace);
    const heldCommands = xtraceCommands(heldXtrace);
    const summarizeEvents = (events) => events.map(({ at, stream, text }) => ({ at, stream, bytes: Buffer.byteLength(text) }));
    const fixtureResult = {
      schema_version: 1,
      phase: "245-branch-prune-local-and-remote",
      plan: 45,
      outcome: "blocked",
      captured_at: new Date().toISOString(),
      operation_attempted: false,
      operator: { attempt_count: 0 },
      production_ref_operations: 0,
      pull_request_mutations: 0,
      repo_04_status: "open",
      historical_audits: { pr_11_rows: "unresolved", cleanup_30_rows: "unresolved" },
      mutations: { local_ref_deletions: [], tracking_ref_deletions: [], remote_ref_deletions: [], safety_ref_publications: [] },
      failed_predicates: ["fixture diagnosis did not reproduce or localize a deterministic defect; live admission prohibited"],
      diagnostic: {
        production_repo_mutations: 0,
        plan44_observed: {
          duration_ms: 600713,
          signal: "SIGINT",
          wrapper_exit_code: 1,
          stdout: "",
          stderr: "",
          readback: {
            state: "exact_present",
            ref: "refs/remotes/origin/v1.37-auth-branding-admin-polish",
            oid: "b9cbb7a7b442f0d04b985c01c30a4a4db24a1d1f",
            type: "commit",
          },
        },
        repro_inputs: {
          operator: "public tracking --apply entry point",
          repo: "disposable fixture with local bare origin, fake GitHub CLI, committed snapshots/readiness/current contract and shared coordinator",
          argv: normal.argv,
          watchdog_ms: { silence: 1500, total: 10000 },
          production_repo_mutations: 0,
        },
        fixture: {
          repo: fixture.repo,
          git_common_dir: resolvedCommonDir,
          target_ref: fixture.trackingRef,
          target_before: { oid: fixture.oid, type: "commit" },
          target_after: "absent",
          target_object_readable: true,
          local_ref_count_before: localBefore.split("\n").filter(Boolean).length,
          origin_ref_count_before: originBefore.split("\n").filter(Boolean).length,
          normal_exit: { status: normalResult.status, signal: normalResult.signal, stdout: normalStdout.output, stderr: normalStderr.output },
          normal_refs_exact_except_target: normalLocalAfter === localExpected,
          origin_refs_unchanged: normalOriginAfter === originBefore,
          open_prs_unchanged: readFileSync(fixture.liveCliPRs, "utf8") === prsBefore,
          held_target_after: heldLocalAfter.includes(`${heldFixture.trackingRef}\t${heldFixture.oid}\tcommit`) ? "exact_present" : "unknown",
          held_local_refs_unchanged: heldLocalAfter === heldLocalBefore,
          held_origin_refs_unchanged: heldOriginAfter === heldOriginBefore,
        },
        trace: {
          deterministic_defect_proven: false,
          last_stage: "public tracking apply completed successfully in normal fixture; held-child run stopped at fixture SSH child",
          normal: {
            started_at: normal.startedAt,
            completed_at: normalCompletedAt,
            duration_ms: Date.parse(normalCompletedAt) - Date.parse(normal.startedAt),
            last_output_at: normal.lastOutputAt(),
            last_completed_command: normalCommands.at(-1) ?? "none",
            command_count: normalCommands.length,
            xtrace: normalXtrace,
            output_events: summarizeEvents(normal.trace),
            stdout: normalStdout.output,
            stderr: normalStderr.output,
          },
          held: {
            started_at: held.startedAt,
            interrupted_at: interrupt.at,
            reason: interrupt.reason,
            last_output_at: held.lastOutputAt(),
            last_completed_command: heldCommands.at(-1) ?? "none",
            active_process_group: [
              { pid: held.child.pid, pgid: held.child.pid, command: "bash detached process group running public tracking operator" },
              { pid: Number(readFileSync(holdMarker, "utf8").trim()), pgid: held.child.pid, command: "fixture-ssh exec sleep 30" },
            ],
            held_child_pid: Number(readFileSync(holdMarker, "utf8").trim()),
            exit: { status: heldResult.status, signal: heldResult.signal, escalation_signal: held.escalationSignal() },
            command_count: heldCommands.length,
            xtrace: heldXtrace,
            output_events: summarizeEvents(held.trace),
            stdout: heldStdout.output,
            stderr: heldStderr.output,
            coordinator_lock_released: !existsSync(join(coordinatorRoot, "lock")),
          },
        },
        watchdog: { single_interrupt_no_relaunch: true, interrupt_count: 1, launch_count: 1, escalation_signal: null },
        deterministic_defect_proven: false,
        regression: { red_observed: false, green_observed: false },
        live_apply_permitted: false,
        next_machine_actionable_diagnostic: "If a later authorized diagnostic needs the production-scale input, add disposable load fixtures and trace external-source latency; this run proves the current fixture path and bounded interruption but no code defect.",
      },
    };
    const resultPath = join(ROOT, PHASE_DIR, "245-45-RESULT.json");
    writeFileSync(resultPath, `${JSON.stringify(fixtureResult, null, 2)}\n`);
    assert.equal(refs(ROOT), productionRefsBefore, "diagnostic result creation must not mutate production refs");
  } finally {
    rmSync(fixture.temp, { recursive: true, force: true });
    if (heldFixture) rmSync(heldFixture.temp, { recursive: true, force: true });
  }
});

test("current-contract cumulative passes carry a tracking deletion into a guarded origin deletion", () => {
  const fixture = makeTrackingFixture({ omitCiTrackingRef: true,
    contractPRs: [{ number: 283, state: "OPEN", headRefName: "fixture-pr-head", baseRefName: "main" }] });
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
    for (const ref of safetyRefs) {
      if (ref !== "refs/heads/ci/phase-235-16-source-complete") git(fixture.repo, "push", "-q", fixture.bare, `${ref}:${ref}`);
    }
    const safetySourceRef = "refs/heads/safety/local-main-before-release-cleanup-fixture";
    const ciSafetySourceRef = "refs/heads/ci/phase-235-16-source-complete";
    fixture.safetyPublicationRef = safetySourceRef;
    git(fixture.repo, "update-ref", safetySourceRef, fixture.oid);
    git(fixture.repo, "update-ref", ciSafetySourceRef, fixture.oid);
    git(fixture.repo, "remote", "set-url", "origin", "git@github.com:szTheory/sigra.git");
    const localCapture = run("bash", [OPERATOR, "capture-local", "--repo", fixture.repo,
      "--output", join(fixture.repo, fixture.snapshot)], { cwd: ROOT, env: fixture.env });
    assert.equal(localCapture.status, 0, `${localCapture.stdout ?? ""}${localCapture.stderr ?? ""}`);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), originRefs(fixture));

    const originCapture = run("bash", [OPERATOR, "capture-origin", "--repo", fixture.repo,
      "--output", join(fixture.repo, fixture.originSnapshot)], { cwd: ROOT, env: fixture.env });
    assert.equal(originCapture.status, 0, `${originCapture.stdout ?? ""}${originCapture.stderr ?? ""}`);
    writeFileSync(join(fixture.repo, safetyList), "side\tref\toid\ttype\treason\n");
    const allowlistBytes = `${readFileSync(join(fixture.repo, fixture.allowlist), "utf8")}remote\t${remoteRef}\t${fixture.oid}\tcommit\tdisposable origin candidate\nsafety-publish\t${safetySourceRef}\t${fixture.oid}\tcommit\tdisposable exact safety publication\nsafety-publish\t${ciSafetySourceRef}\t${fixture.oid}\tcommit\tdisposable exact D-04 ci safety publication\n`;
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
    assert.ok(originRefs(fixture).includes(`${ciSafetySourceRef}\t${fixture.oid}\tcommit`), "the D-04 ci safety ref publishes at its exact identity");

    const firstPass = trackingApply(fixture, [safetySourceRef, ciSafetySourceRef]);
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
    const blockedChangedBase = remoteApply(fixture, preflightCommit, [safetySourceRef, ciSafetySourceRef, fixture.trackingRef]);
    assert.notEqual(blockedChangedBase.status, 0, "a changed PR base OID blocks the next operation boundary");
    assert.match(`${blockedChangedBase.stdout ?? ""}${blockedChangedBase.stderr ?? ""}`, /current_pr_base_oid_changed:283/);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), "changed PR base OID cannot authorize origin deletion");
    writeFileSync(fixture.liveCliPRs, cliBytes);
    writeFileSync(fixture.liveApiPRs, apiBytes);

    const changedApiRepository = JSON.parse(apiBytes);
    changedApiRepository[0].base.repo.full_name = "szTheory/other";
    writeFileSync(fixture.liveApiPRs, JSON.stringify(changedApiRepository));
    const blockedChangedRepository = remoteApply(fixture, preflightCommit, [safetySourceRef, ciSafetySourceRef, fixture.trackingRef]);
    assert.notEqual(blockedChangedRepository.status, 0, "a changed PR base repository blocks the next operation boundary");
    assert.match(`${blockedChangedRepository.stdout ?? ""}${blockedChangedRepository.stderr ?? ""}`, /current_pr_base_repository_changed:283/);
    writeFileSync(fixture.liveCliPRs, cliBytes);
    writeFileSync(fixture.liveApiPRs, apiBytes);

    const blockedInvented = remoteApply(fixture, preflightCommit, [safetySourceRef, ciSafetySourceRef, "refs/heads/not-admitted"]);
    assert.notEqual(blockedInvented.status, 0, "invented cumulative identity must be rejected");
    assert.match(`${blockedInvented.stdout ?? ""}${blockedInvented.stderr ?? ""}`, /evidence_transition_applied_ref_not_allowlisted/);
    assert.ok(originRefs(fixture).includes(`${remoteRef}\t${fixture.oid}\tcommit`), "invalid cumulative input cannot mutate origin");

    const secondPass = remoteApply(fixture, preflightCommit, [safetySourceRef, ciSafetySourceRef, fixture.trackingRef]);
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
