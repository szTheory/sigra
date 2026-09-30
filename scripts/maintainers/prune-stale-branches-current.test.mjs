import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { inspectEvidenceTransition } from "./prune-stale-branches-current.mjs";

const OPERATOR = "scripts/maintainers/prune-stale-branches.sh";
const GIT_BIN = "/usr/bin/git";
const COMMIT = "1".repeat(40);

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed:\n${result.stderr}`);
  return result.stdout.trim();
}

function fixtureGit(repo, ...args) {
  return run(GIT_BIN, ["-C", repo, ...args]);
}

function makeEvidenceFixture(parentDir, { wrongContractParent = false, extraContractPath = false } = {}) {
  const repo = join(parentDir, "repo");
  mkdirSync(repo);
  run(GIT_BIN, ["init", "-q", "--initial-branch=main", repo]);
  fixtureGit(repo, "config", "user.name", "Evidence Transition Fixture");
  fixtureGit(repo, "config", "user.email", "evidence-transition@example.invalid");
  writeFileSync(join(repo, "seed.txt"), "seed\n");
  fixtureGit(repo, "add", "seed.txt");
  fixtureGit(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture seed");
  const capturedHeadOid = fixtureGit(repo, "rev-parse", "HEAD");
  const contractPath = ".planning/phases/245-19-CURRENT-CONTRACT.json";
  const candidatesPath = ".planning/phases/245-19-CANDIDATES.json";
  const allowlistPath = ".planning/phases/245-19-BRANCH-DELETE-ALLOWLIST.tsv";
  const admissionPath = ".planning/phases/245-19-ADMISSION.json";
  const resultPath = ".planning/phases/245-19-RESULT.json";
  const postPath = ".planning/phases/245-19-POST-LOCAL-REFS.tsv";
  const summaryPath = ".planning/phases/245-19-SUMMARY.md";
  for (const file of [candidatesPath, allowlistPath, admissionPath, resultPath, postPath, summaryPath]) {
    mkdirSync(join(repo, file, ".."), { recursive: true });
  }
  const evidenceBytes = {
    [candidatesPath]: Buffer.from('{"classification":"fixture"}\n'),
    [allowlistPath]: Buffer.from("side\tref\toid\ttype\treason\nlocal\trefs/heads/fixture\t0000000000000000000000000000000000000000\tcommit\tfixture\n"),
    [admissionPath]: Buffer.from('{"status":"prepared"}\n'),
  };
  const precommitArtifacts = {};
  for (const [file, raw] of Object.entries(evidenceBytes)) {
    writeFileSync(join(repo, file), raw);
    precommitArtifacts[file] = {
      blob: run(GIT_BIN, ["-C", repo, "hash-object", "--stdin", "-t", "blob"], { input: raw }),
      sha256: createHash("sha256").update(raw).digest("hex"),
    };
  }
  const contract = {
    schema_version: 1,
    repository: "szTheory/sigra",
    checkout_root: repo,
    capture_head_ref: "refs/heads/main",
    capture_head_oid: capturedHeadOid,
    local_refs: [{ ref: "refs/heads/main", oid: capturedHeadOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null }],
    origin_refs: [],
    open_prs: [],
    evidence_transition: {
      active_ref: "refs/heads/main",
      captured_head_oid: capturedHeadOid,
      contract_path: contractPath,
      contract_paths: [contractPath, `${contractPath}.sha256`, ...Object.keys(evidenceBytes)].sort(),
      precommit_artifacts: precommitArtifacts,
      final_child_path_sets: {
        blocked: [resultPath, postPath].sort(),
        passed: [resultPath, postPath, summaryPath].sort(),
      },
      result_path: resultPath,
    },
  };
  if (wrongContractParent) {
    writeFileSync(join(repo, "intruder.txt"), "unexpected parent\n");
    fixtureGit(repo, "add", "intruder.txt");
    fixtureGit(repo, "commit", "-q", "-m", "unexpected parent");
  }
  writeFileSync(join(repo, contractPath), `${JSON.stringify(contract, null, 2)}\n`);
  const contractBytes = readFileSync(join(repo, contractPath));
  writeFileSync(join(repo, `${contractPath}.sha256`), `${createHash("sha256").update(contractBytes).digest("hex")}\n`);
  const commitPaths = [...contract.evidence_transition.contract_paths];
  if (extraContractPath) {
    writeFileSync(join(repo, "unexpected.txt"), "extra path\n");
    commitPaths.push("unexpected.txt");
  }
  fixtureGit(repo, "add", "--", ...commitPaths);
  fixtureGit(repo, "commit", "-q", "-m", "fixture contract commit");
  return { repo, contract, contractPath, candidatesPath, allowlistPath, admissionPath, resultPath, postPath, summaryPath,
    contractCommit: fixtureGit(repo, "rev-parse", "HEAD") };
}

function commitFinalEvidence(fixture, { extraPath = false, secondCommit = false, wrongParent = false } = {}) {
  if (wrongParent) {
    writeFileSync(join(fixture.repo, "middle.txt"), "middle\n");
    fixtureGit(fixture.repo, "add", "middle.txt");
    fixtureGit(fixture.repo, "commit", "-q", "-m", "wrong final parent");
  }
  writeFileSync(join(fixture.repo, fixture.resultPath), '{"outcome":"blocked"}\n');
  writeFileSync(join(fixture.repo, fixture.postPath), "post-state\n");
  const finalPaths = [fixture.resultPath, fixture.postPath];
  if (extraPath) {
    writeFileSync(join(fixture.repo, "extra-final.txt"), "extra\n");
    finalPaths.push("extra-final.txt");
  }
  fixtureGit(fixture.repo, "add", "--", ...finalPaths);
  fixtureGit(fixture.repo, "commit", "-q", "-m", "fixture blocked result");
  if (secondCommit) {
    writeFileSync(join(fixture.repo, "second.txt"), "second\n");
    fixtureGit(fixture.repo, "add", "second.txt");
    fixtureGit(fixture.repo, "commit", "-q", "-m", "unexpected second result child");
  }
}

test("verify-prs recognizes explicit current-contract mode and rejects a missing pair member", () => {
  const result = spawnSync("bash", [
    OPERATOR,
    "verify-prs",
    "--current-contract-commit",
    COMMIT,
  ], { encoding: "utf8" });

  assert.notEqual(result.status, 0, "a current contract commit without its path must block");
  assert.match(`${result.stdout}\n${result.stderr}`, /current_contract_(?:path|pair)_required/i);
});

test("local apply validates the current-contract pair before attempting a mutation", () => {
  const result = spawnSync("bash", [
    OPERATOR,
    "local",
    "--apply",
    "--current-contract",
    ".planning/current-contract.json",
  ], { encoding: "utf8" });

  assert.notEqual(result.status, 0, "a path without its immutable source commit must block");
  assert.match(`${result.stdout}\n${result.stderr}`, /current_contract_commit_required/i);
});

test("D-07 accepts only the exact contract commit and one declared direct-child receipt", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-evidence-transition-"));
  try {
    const fixture = makeEvidenceFixture(root);
    const before = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "before");
    assert.equal(before.contract_parent, fixture.contract.capture_head_oid);
    assert.deepEqual(before.contract_paths, fixture.contract.evidence_transition.contract_paths);
    assert.equal(before.final_evidence_commit, null);

    commitFinalEvidence(fixture);
    const after = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after");
    assert.equal(after.final_evidence_commit, fixtureGit(fixture.repo, "rev-parse", "HEAD"));
    assert.deepEqual(after.final_evidence_paths, fixture.contract.evidence_transition.final_child_path_sets.blocked);
    assert.equal(after.final_file_pins.length, 2);
    assert.ok(after.final_file_pins.every((row) => /^[0-9a-f]{40,64}$/.test(row.blob) && /^[0-9a-f]{64}$/.test(row.sha256)));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 rejects wrong contract parents, extra contract paths, wrong final parents, extra final paths, second commits, and unrelated refs", () => {
  const cases = [
    { name: "wrong contract parent", setup: (root) => makeEvidenceFixture(root, { wrongContractParent: true }), stage: "before", error: /evidence_transition_contract_parent_mismatch/ },
    { name: "extra contract path", setup: (root) => makeEvidenceFixture(root, { extraContractPath: true }), stage: "before", error: /evidence_transition_contract_path_set_mismatch/ },
    { name: "wrong final parent", setup: (root) => makeEvidenceFixture(root), prepare: (fixture) => commitFinalEvidence(fixture, { wrongParent: true }), stage: "after", error: /evidence_transition_final_parent_mismatch/ },
    { name: "extra final path", setup: (root) => makeEvidenceFixture(root), prepare: (fixture) => commitFinalEvidence(fixture, { extraPath: true }), stage: "after", error: /evidence_transition_final_path_set_mismatch/ },
    { name: "second final commit", setup: (root) => makeEvidenceFixture(root), prepare: (fixture) => commitFinalEvidence(fixture, { secondCommit: true }), stage: "after", error: /evidence_transition_final_parent_mismatch/ },
    { name: "unrelated local ref", setup: (root) => makeEvidenceFixture(root), prepare: (fixture) => fixtureGit(fixture.repo, "branch", "unrelated"), stage: "before", error: /evidence_transition_local_ref_set_changed/ },
  ];
  for (const scenario of cases) {
    const root = mkdtempSync(join(tmpdir(), "sigra-evidence-rejection-"));
    try {
      const fixture = scenario.setup(root);
      scenario.prepare?.(fixture);
      assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, scenario.stage), scenario.error, scenario.name);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});

test("captured current PR/ref contract verifies from committed bytes through the shell selector", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-current-contract-"));
  try {
    const bare = join(root, "origin.git");
    const repo = join(root, "repo");
    mkdirSync(repo);
    run("git", ["init", "--bare", bare]);
    run("git", ["init", repo]);
    run("git", ["-C", repo, "config", "user.name", "Contract Fixture"]);
    run("git", ["-C", repo, "config", "user.email", "fixture@example.invalid"]);
    run("git", ["-C", repo, "branch", "-M", "main"]);
    writeFileSync(join(repo, "README.md"), "fixture\n");
    run("git", ["-C", repo, "add", "README.md"]);
    run("git", ["-C", repo, "commit", "-m", "fixture main"]);
    run("git", ["-C", repo, "remote", "add", "origin", bare]);
    run("git", ["-C", repo, "push", "-u", "origin", "main"]);
    const mainOid = run("git", ["-C", repo, "rev-parse", "refs/heads/main"]);
    run("git", ["-C", repo, "switch", "-c", "feature/current-contract"]);
    writeFileSync(join(repo, "feature.txt"), "feature\n");
    run("git", ["-C", repo, "add", "feature.txt"]);
    run("git", ["-C", repo, "commit", "-m", "fixture feature"]);
    run("git", ["-C", repo, "push", "-u", "origin", "feature/current-contract"]);
    const headOid = run("git", ["-C", repo, "rev-parse", "refs/heads/feature/current-contract"]);
    run("git", ["-C", repo, "switch", "main"]);
    run("git", ["-C", repo, "branch", "stale/merged", mainOid]);
    mkdirSync(join(repo, ".planning"));
    const allowlistPath = ".planning/fixture-allowlist.tsv";
    writeFileSync(join(repo, allowlistPath), `side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t${mainOid}\tcommit\tmerged fixture branch\n`);
    run("git", ["-C", repo, "add", allowlistPath]);
    run("git", ["-C", repo, "commit", "-m", "pin exact fixture allowlist"]);
    const allowlistCommit = run("git", ["-C", repo, "rev-parse", "HEAD"]);

    const prCli = [{
      number: 7,
      state: "OPEN",
      headRefName: "feature/current-contract",
      baseRefName: "main",
      headRefOid: headOid,
      baseRefOid: mainOid,
    }];
    const sourceFixture = join(repo, "fixture-github.json");
    writeFileSync(sourceFixture, JSON.stringify({
      cliPulls: prCli,
      pages: [[{
        number: 7,
        state: "open",
        head: { ref: "feature/current-contract", sha: headOid, repo: { full_name: "szTheory/sigra" } },
        base: { ref: "main", sha: mainOid, repo: { full_name: "szTheory/sigra" } },
      }]],
    }));

    const contractPath = ".planning/current-contract.json";
    const capture = run("node", [
      "scripts/maintainers/prune-stale-branches-current.mjs",
      "capture",
      "--repo", repo,
      "--output", join(repo, contractPath),
      "--source-fixture", sourceFixture,
      "--pin-input", `${allowlistCommit}:${allowlistPath}`,
    ], { env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    assert.match(capture, /captured/i);
    assert.ok(JSON.parse(readFileSync(join(repo, contractPath), "utf8")).open_prs.length === 1);
    run("git", ["-C", repo, "add", contractPath, `${contractPath}.sha256`]);
    run("git", ["-C", repo, "commit", "-m", "pin current contract"]);
    const contractCommit = run("git", ["-C", repo, "rev-parse", "HEAD"]);

    const verification = spawnSync("bash", [
      OPERATOR,
      "verify-prs",
      "--repo", repo,
      "--current-contract-commit", contractCommit,
      "--current-contract", contractPath,
      "--current-contract-fixture", "fixture-github.json",
    ], { encoding: "utf8", env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    assert.equal(verification.status, 0, verification.stderr);
    assert.match(verification.stdout, /current.*contract.*verified/i);
    const allowlistVerification = spawnSync("bash", [
      OPERATOR,
      "verify-allowlist",
      "--repo", repo,
      "--current-contract-commit", contractCommit,
      "--current-contract", contractPath,
      "--allowlist-commit", allowlistCommit,
      "--allowlist", allowlistPath,
      "--current-contract-fixture", "fixture-github.json",
    ], { encoding: "utf8", env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    assert.equal(allowlistVerification.status, 0, allowlistVerification.stderr);
    assert.match(allowlistVerification.stdout, /current committed allowlist matches/i);

    const boundary = spawnSync("node", [
      "scripts/maintainers/prune-stale-branches-current.mjs", "verify",
      "--repo", repo,
      "--contract-commit", contractCommit,
      "--contract", contractPath,
      "--source-fixture", sourceFixture,
      "--stage", "boundary",
      "--allowlist-commit", allowlistCommit,
      "--allowlist", allowlistPath,
      "--operation-side", "local",
      "--operation-ref", "refs/heads/stale/merged",
      "--operation-kind", "delete",
    ], { encoding: "utf8", env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    assert.equal(boundary.status, 0, boundary.stderr);
    run("git", ["-C", repo, "update-ref", "--no-deref", "-d", "refs/heads/stale/merged", mainOid]);
    const afterDelete = spawnSync("node", [
      "scripts/maintainers/prune-stale-branches-current.mjs", "verify",
      "--repo", repo,
      "--contract-commit", contractCommit,
      "--contract", contractPath,
      "--source-fixture", sourceFixture,
      "--stage", "after",
      "--allowlist-commit", allowlistCommit,
      "--allowlist", allowlistPath,
      "--operation-side", "local",
      "--operation-ref", "refs/heads/stale/merged",
      "--operation-kind", "delete",
    ], { encoding: "utf8", env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    assert.equal(afterDelete.status, 0, afterDelete.stderr);
    run("git", ["-C", repo, "update-ref", "refs/heads/stale/merged", mainOid]);

    const verifyLive = (commit = contractCommit, path = contractPath) => spawnSync("bash", [
      OPERATOR,
      "verify-prs",
      "--repo", repo,
      "--current-contract-commit", commit,
      "--current-contract", path,
      "--current-contract-fixture", "fixture-github.json",
    ], { encoding: "utf8", env: { ...process.env, SIGRA_CURRENT_GITHUB_FIXTURE: sourceFixture } });
    const fixture = JSON.parse(readFileSync(sourceFixture, "utf8"));

    fixture.pages[0][0].base.sha = "f".repeat(40);
    writeFileSync(sourceFixture, JSON.stringify(fixture));
    const staleApiBase = verifyLive();
    assert.equal(staleApiBase.status, 0, staleApiBase.stderr);
    assert.match(staleApiBase.stdout, /verified/i, "the live origin base OID remains authoritative over a stale API base SHA");
    fixture.pages[0][0].base.sha = mainOid;

    fixture.cliPulls[0].headRefName = "renamed/head";
    fixture.pages[0][0].head.ref = "renamed/head";
    writeFileSync(sourceFixture, JSON.stringify(fixture));
    const renamedHead = verifyLive();
    assert.notEqual(renamedHead.status, 0);
    assert.match(renamedHead.stderr, /current_pr_head_name_changed:7/);
    fixture.cliPulls[0].headRefName = "feature/current-contract";
    fixture.pages[0][0].head.ref = "feature/current-contract";

    fixture.cliPulls[0].baseRefName = "changed/base";
    fixture.pages[0][0].base.ref = "changed/base";
    writeFileSync(sourceFixture, JSON.stringify(fixture));
    const renamedBase = verifyLive();
    assert.notEqual(renamedBase.status, 0);
    assert.match(renamedBase.stderr, /current_pr_base_name_changed:7/);
    fixture.cliPulls[0].baseRefName = "main";
    fixture.pages[0][0].base.ref = "main";

    fixture.cliPulls.push({ ...fixture.cliPulls[0], number: 8 });
    fixture.pages[0].push({ ...fixture.pages[0][0], number: 8 });
    writeFileSync(sourceFixture, JSON.stringify(fixture));
    const addedPr = verifyLive();
    assert.notEqual(addedPr.status, 0);
    assert.match(addedPr.stderr, /current_open_pr_set_changed/);
    fixture.cliPulls.pop();
    fixture.pages[0].pop();

    fixture.pages = [];
    writeFileSync(sourceFixture, JSON.stringify(fixture));
    const missingPage = verifyLive();
    assert.notEqual(missingPage.status, 0);
    assert.match(missingPage.stderr, /fixture_pr_pages_missing/);
    fixture.pages = [[{
      number: 7,
      state: "open",
      head: { ref: "feature/current-contract", sha: headOid, repo: { full_name: "szTheory/sigra" } },
      base: { ref: "main", sha: mainOid, repo: { full_name: "szTheory/sigra" } },
    }]];
    writeFileSync(sourceFixture, JSON.stringify(fixture));

    const wrongPath = verifyLive(contractCommit, ".planning/missing.json");
    assert.notEqual(wrongPath.status, 0);
    assert.match(wrongPath.stderr, /current_contract_path_missing/);

    run("git", ["--git-dir", bare, "update-ref", "refs/heads/main", headOid]);
    const movedOrigin = verifyLive();
    assert.notEqual(movedOrigin.status, 0);
    assert.match(movedOrigin.stderr, /current_origin_ref_identity_changed/);

    writeFileSync(join(repo, `${contractPath}.sha256`), `${"0".repeat(64)}\n`);
    run("git", ["-C", repo, "add", `${contractPath}.sha256`]);
    run("git", ["-C", repo, "commit", "-m", "corrupt current contract digest"]);
    const digestCommit = run("git", ["-C", repo, "rev-parse", "HEAD"]);
    const badDigest = verifyLive(digestCommit);
    assert.notEqual(badDigest.status, 0);
    assert.match(badDigest.stderr, /current_contract_sha256_mismatch/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
