import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const OPERATOR = "scripts/maintainers/prune-stale-branches.sh";
const COMMIT = "1".repeat(40);

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed:\n${result.stderr}`);
  return result.stdout.trim();
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
