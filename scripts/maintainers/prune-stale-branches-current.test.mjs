import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { compareCurrent, inspectEvidenceTransition } from "./prune-stale-branches-current.mjs";

const OPERATOR = "scripts/maintainers/prune-stale-branches.sh";
const GIT_BIN = "/usr/bin/git";
const COMMIT = "1".repeat(40);
const ROOT = process.cwd();

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed:\n${result.stderr}`);
  return result.stdout.trim();
}

function fixtureGit(repo, ...args) {
  return run(GIT_BIN, ["-C", repo, ...args]);
}

function makeEvidenceFixture(parentDir, { wrongContractParent = false, extraContractPath = false, trackingRefs = [], admittedLocalRefs = [], safetyRefs = [], safetyTags = [], inheritedEvidencePaths = [] } = {}) {
  const repo = join(parentDir, "repo");
  const contractPath = ".planning/phases/245-19-CURRENT-CONTRACT.json";
  const candidatesPath = ".planning/phases/245-19-CANDIDATES.json";
  const allowlistPath = ".planning/phases/245-19-BRANCH-DELETE-ALLOWLIST.tsv";
  const admissionPath = ".planning/phases/245-19-ADMISSION.json";
  const resultPath = ".planning/phases/245-19-RESULT.json";
  const postPath = ".planning/phases/245-19-POST-LOCAL-REFS.tsv";
  const summaryPath = ".planning/phases/245-19-SUMMARY.md";
  mkdirSync(repo);
  run(GIT_BIN, ["init", "-q", "--initial-branch=main", repo]);
  fixtureGit(repo, "config", "user.name", "Evidence Transition Fixture");
  fixtureGit(repo, "config", "user.email", "evidence-transition@example.invalid");
  writeFileSync(join(repo, "seed.txt"), "seed\n");
  fixtureGit(repo, "add", "seed.txt");
  fixtureGit(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture seed");
  for (const file of inheritedEvidencePaths) {
    mkdirSync(join(repo, file, ".."), { recursive: true });
    const bytes = file === allowlistPath
      ? `side\tref\toid\ttype\treason\nremote\trefs/heads/fixture\t${"1".repeat(40)}\tcommit\tinherited fixture allowlist\n`
      : `inherited fixture evidence: ${file}\n`;
    writeFileSync(join(repo, file), bytes);
    fixtureGit(repo, "add", "--", file);
  }
  if (inheritedEvidencePaths.length) {
    fixtureGit(repo, "-c", "gc.auto=0", "-c", "maintenance.auto=false", "commit", "-q", "-m", "fixture inherited evidence");
  }
  const capturedHeadOid = fixtureGit(repo, "rev-parse", "HEAD");
  for (const ref of [...trackingRefs, ...admittedLocalRefs, ...safetyRefs]) fixtureGit(repo, "update-ref", ref, capturedHeadOid);
  for (const tag of safetyTags) fixtureGit(repo, "tag", "-a", tag, "-m", "fixture safety tag");
  const safetyRows = [
    ...safetyRefs.map((ref) => ({ ref, oid: capturedHeadOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null })),
    ...safetyTags.map((tag) => {
      const [ref, oid, type, peeledOid, peeledType] = fixtureGit(repo, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)", `refs/tags/${tag}`).split("\t");
      return { ref, oid, type, peeled_oid: peeledOid || null, peeled_type: peeledType || null, symref: null };
    }),
  ];
  for (const file of [candidatesPath, allowlistPath, admissionPath, resultPath, postPath, summaryPath]) {
    mkdirSync(join(repo, file, ".."), { recursive: true });
  }
  const evidenceBytes = {
    [candidatesPath]: Buffer.from('{"classification":"fixture"}\n'),
    [allowlistPath]: Buffer.from(trackingRefs.length || admittedLocalRefs.length || safetyRows.length
      ? `side\tref\toid\ttype\treason\n${[
        ...admittedLocalRefs.map((ref) => `local\t${ref}\t${capturedHeadOid}\tcommit\tprior admitted local deletion`),
        ...trackingRefs.map((ref) => `tracking\t${ref}\t${capturedHeadOid}\tcommit\tfixture tracking ref`),
        ...safetyRows.map((row) => `safety-publish\t${row.ref}\t${row.oid}\t${row.type}\tfixture safety publication`),
      ].join("\n")}\n`
      : "side\tref\toid\ttype\treason\nlocal\trefs/heads/fixture\t0000000000000000000000000000000000000000\tcommit\tfixture\n"),
    [admissionPath]: Buffer.from('{"status":"prepared"}\n'),
  };
  for (const file of inheritedEvidencePaths) evidenceBytes[file] = readFileSync(join(repo, file));
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
    local_refs: [
      { ref: "refs/heads/main", oid: capturedHeadOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null },
      ...trackingRefs.map((ref) => ({ ref, oid: capturedHeadOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null })),
      ...admittedLocalRefs.map((ref) => ({ ref, oid: capturedHeadOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null })),
      ...safetyRows,
    ].sort((a, b) => a.ref.localeCompare(b.ref)),
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
  return { repo, contract, contractPath, candidatesPath, allowlistPath, admissionPath, resultPath, postPath, summaryPath, capturedHeadOid,
    contractCommit: fixtureGit(repo, "rev-parse", "HEAD") };
}

test("safety publication result reaches the final after-stage applied-ref ledger", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-safety-publication-result-"));
  try {
    const cases = [
      { ref: "refs/heads/safety-fixture", setup: { safetyRefs: ["refs/heads/safety-fixture"] }, tracking: "refs/remotes/origin/safety-fixture" },
      { ref: "refs/tags/safety-fixture", setup: { safetyTags: ["safety-fixture"] }, tracking: null },
    ];
    for (const [index, scenario] of cases.entries()) {
      const fixtureRoot = join(root, String(index));
      mkdirSync(fixtureRoot);
      const fixture = makeEvidenceFixture(fixtureRoot, scenario.setup);
      const source = fixture.contract.local_refs.find((row) => row.ref === scenario.ref);
      const allowlistRows = [{ side: "safety-publish", ref: scenario.ref, oid: source.oid, type: source.type }];
      if (scenario.tracking) fixtureGit(fixture.repo, "update-ref", scenario.tracking, source.oid);
      commitFinalEvidence(fixture, { mutations: {
        local_ref_deletions: [], tracking_ref_deletions: [], remote_ref_deletions: [],
        safety_ref_publications: [{ ref: scenario.ref, expected_oid: source.oid, type: source.type, readback: "present" }],
      } });
      const final = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", {
        allowlistRows,
        appliedRefs: [scenario.ref],
      });
      assert.deepEqual(final.applied_refs, [scenario.ref]);
      const published = { ...source, symref: null };
      compareCurrent(fixture.contract, {
        repository: fixture.contract.repository,
        open_prs: [],
        local_refs: [...fixture.contract.local_refs, ...(scenario.tracking ? [{
          ref: scenario.tracking, oid: source.oid, type: source.type, peeled_oid: source.peeled_oid,
          peeled_type: source.peeled_type, symref: null,
        }] : [])],
        origin_refs: [published],
      }, fixture.contractCommit, { stage: "after", appliedRefs: [scenario.ref], allowlistRows });
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("safety publication result rejects malformed rows and missing or mismatched origin readback", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-safety-publication-rejections-"));
  try {
    const ref = "refs/heads/safety-fixture";
    const cases = [
      { name: "omitted publication", mutations: {}, appliedRefs: [ref], error: /evidence_transition_result_applied_refs_mismatch/ },
      { name: "empty publication array", mutations: { safety_ref_publications: [] }, appliedRefs: [ref], error: /evidence_transition_result_applied_refs_mismatch/ },
      { name: "wrong allowlist side", allowlistSide: "local", row: { ref, expected_oid: "", type: "commit", readback: "present" }, appliedRefs: [], error: /evidence_transition_result_mutation_side_mismatch/ },
      { name: "wrong OID", row: { ref, expected_oid: "f".repeat(40), type: "commit", readback: "present" }, error: /evidence_transition_result_mutation_oid_mismatch/ },
      { name: "conflicting OID aliases", row: { ref, expected_oid: "source", oid: "f".repeat(40), type: "commit", readback: "present" }, error: /evidence_transition_result_mutation_oid_mismatch/ },
      { name: "wrong type", row: { ref, expected_oid: "source", type: "blob", readback: "present" }, error: /evidence_transition_result_mutation_type_mismatch/ },
      { name: "duplicate publication ref", duplicate: true, row: { ref, expected_oid: "source", type: "commit", readback: "present" }, error: /evidence_transition_result_ref_duplicate/ },
      { name: "non-present readback", row: { ref, expected_oid: "source", type: "commit", readback: "absent" }, error: /evidence_transition_result_mutation_readback_invalid/ },
      { name: "mismatched CLI applied-ref set", row: { ref, expected_oid: "source", type: "commit", readback: "present" }, appliedRefs: [], error: /evidence_transition_result_applied_refs_mismatch/ },
    ];
    for (const [index, scenario] of cases.entries()) {
      const fixtureRoot = join(root, String(index));
      mkdirSync(fixtureRoot);
      const fixture = makeEvidenceFixture(fixtureRoot, { safetyRefs: [ref] });
      const oid = fixture.contract.capture_head_oid;
      const allowlistRows = [{ side: scenario.allowlistSide ?? "safety-publish", ref, oid, type: "commit" }];
      const row = { ...scenario.row, expected_oid: scenario.row?.expected_oid === "source" ? oid : scenario.row?.expected_oid };
      if (row.oid === "f".repeat(40)) row.expected_oid = oid;
      const mutations = {
        local_ref_deletions: [], tracking_ref_deletions: [], remote_ref_deletions: [],
        ...scenario.mutations,
        ...(scenario.mutations ? {} : { safety_ref_publications: [row, ...(scenario.duplicate ? [row] : [])] }),
      };
      commitFinalEvidence(fixture, { mutations });
      assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", {
        allowlistRows,
        appliedRefs: scenario.appliedRefs ?? [ref],
      }), scenario.error, scenario.name);
    }

    const fixtureRoot = join(root, "origin-readback");
    mkdirSync(fixtureRoot);
    const fixture = makeEvidenceFixture(fixtureRoot, { safetyRefs: [ref] });
    const source = fixture.contract.local_refs.find((row) => row.ref === ref);
    const allowlistRows = [{ side: "safety-publish", ref, oid: source.oid, type: source.type }];
    commitFinalEvidence(fixture, { mutations: {
      local_ref_deletions: [], tracking_ref_deletions: [], remote_ref_deletions: [],
      safety_ref_publications: [{ ref, expected_oid: source.oid, type: source.type, readback: "present" }],
    } });
    assert.throws(() => compareCurrent(fixture.contract, {
      repository: fixture.contract.repository,
      open_prs: [],
      local_refs: fixture.contract.local_refs,
      origin_refs: [],
    }, fixture.contractCommit, { stage: "after", appliedRefs: [ref], allowlistRows }), /current_safety_publish_readback_mismatch/);
    assert.throws(() => compareCurrent(fixture.contract, {
      repository: fixture.contract.repository,
      open_prs: [],
      local_refs: fixture.contract.local_refs,
      origin_refs: [{ ...source, oid: "f".repeat(40), symref: null }],
    }, fixture.contractCommit, { stage: "after", appliedRefs: [ref], allowlistRows }), /current_safety_publish_identity_conflict/);
    assert.throws(() => compareCurrent(fixture.contract, {
      repository: fixture.contract.repository,
      open_prs: [],
      local_refs: fixture.contract.local_refs,
      origin_refs: [{ ...source, symref: null }],
    }, fixture.contractCommit, { stage: "after", appliedRefs: [], allowlistRows }), /current_origin_ref_unexpected/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 operation readback permits only cumulative committed tracking removals before a result child", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-operation-readback-"));
  try {
    const refs = ["refs/remotes/origin/one", "refs/remotes/origin/two"];
    const fixture = makeEvidenceFixture(root, { trackingRefs: refs });
    fixtureGit(fixture.repo, "update-ref", "-d", refs[0], fixture.contract.capture_head_oid);
    const result = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "operation", {
      allowlistRows: refs.map((ref) => ({ side: "tracking", ref, oid: fixture.contract.capture_head_oid, type: "commit" })),
      appliedRefs: [refs[0]],
    });
    assert.equal(result.final_evidence_commit, null);
    assert.deepEqual(result.applied_refs, [refs[0]]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 retains the prior local deletion once across two cumulative tracking readbacks and final child", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-cumulative-readback-"));
  try {
    const priorLocal = "refs/heads/prior-admitted";
    const [first, second] = ["refs/remotes/origin/one", "refs/remotes/origin/two"];
    const fixture = makeEvidenceFixture(root, { trackingRefs: [first, second], admittedLocalRefs: [priorLocal] });
    const oid = fixture.contract.capture_head_oid;
    const allowlistRows = [
      { side: "local", ref: priorLocal, oid, type: "commit" },
      { side: "tracking", ref: first, oid, type: "commit" },
      { side: "tracking", ref: second, oid, type: "commit" },
    ];
    fixtureGit(fixture.repo, "update-ref", "-d", priorLocal, oid);
    fixtureGit(fixture.repo, "update-ref", "-d", first, oid);
    const firstReadback = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "operation", {
      allowlistRows,
      appliedRefs: [priorLocal, first],
    });
    assert.deepEqual(firstReadback.applied_refs, [priorLocal, first]);

    fixtureGit(fixture.repo, "update-ref", "-d", second, oid);
    const appliedRefs = [priorLocal, first, second];
    const secondReadback = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "operation", { allowlistRows, appliedRefs });
    assert.deepEqual(secondReadback.applied_refs, appliedRefs);
    assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", { allowlistRows, appliedRefs }), /evidence_transition_final_child_missing/);

    commitFinalEvidence(fixture, { mutations: {
      local_ref_deletions: [{ ref: priorLocal }],
      tracking_ref_deletions: [{ ref: first }, { ref: second }],
      remote_ref_deletions: [],
    } });
    const final = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", { allowlistRows, appliedRefs });
    assert.deepEqual(final.applied_refs, appliedRefs);
    assert.equal(final.final_evidence_commit, fixtureGit(fixture.repo, "rev-parse", "HEAD"));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 rejects unallowlisted missing refs, incomplete cumulative sets, and result mismatches", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-transition-delta-rejections-"));
  try {
    const [allowed, unlisted] = ["refs/remotes/origin/allowed", "refs/remotes/origin/unlisted"];
    const fixture = makeEvidenceFixture(root, { trackingRefs: [allowed, unlisted] });
    const oid = fixture.contract.capture_head_oid;
    const allowlistRows = [{ side: "tracking", ref: allowed, oid, type: "commit" }];
    fixtureGit(fixture.repo, "update-ref", "-d", allowed, oid);
    assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "operation", { allowlistRows, appliedRefs: [] }), /evidence_transition_local_ref_set_changed/);

    fixtureGit(fixture.repo, "update-ref", "-d", unlisted, oid);
    assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "operation", { allowlistRows, appliedRefs: [allowed] }), /evidence_transition_local_ref_set_changed/);

    fixtureGit(fixture.repo, "update-ref", allowed, oid);
    fixtureGit(fixture.repo, "update-ref", unlisted, oid);
    fixtureGit(fixture.repo, "update-ref", "-d", allowed, oid);
    fixtureGit(fixture.repo, "update-ref", "-d", unlisted, oid);
    commitFinalEvidence(fixture);
    assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", { allowlistRows, appliedRefs: [allowed] }), /evidence_transition_result_applied_refs_mismatch/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 final result ref side and OID must match the committed allowlist disposition", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-result-disposition-"));
  try {
    const ref = "refs/remotes/origin/tracking";
    const fixture = makeEvidenceFixture(root, { trackingRefs: [ref] });
    const oid = fixture.contract.capture_head_oid;
    const allowlistRows = [{ side: "tracking", ref, oid, type: "commit" }];
    fixtureGit(fixture.repo, "update-ref", "-d", ref, oid);
    commitFinalEvidence(fixture, { mutations: {
      local_ref_deletions: [{ ref }], tracking_ref_deletions: [], remote_ref_deletions: [],
    } });
    assert.throws(() => inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after", {
      allowlistRows,
      appliedRefs: [ref],
    }), /evidence_transition_result_mutation_side_mismatch/);

    const oidRoot = mkdtempSync(join(root, "oid-") );
    const oidFixture = makeEvidenceFixture(oidRoot, { trackingRefs: [ref] });
    const expectedOid = oidFixture.contract.capture_head_oid;
    fixtureGit(oidFixture.repo, "update-ref", "-d", ref, expectedOid);
    commitFinalEvidence(oidFixture, { mutations: {
      local_ref_deletions: [], tracking_ref_deletions: [{ ref, expected_oid: "f".repeat(40) }], remote_ref_deletions: [],
    } });
    assert.throws(() => inspectEvidenceTransition(oidFixture.repo, oidFixture.contractCommit, oidFixture.contractPath, oidFixture.contract, "after", {
      allowlistRows: [{ side: "tracking", ref, oid: expectedOid, type: "commit" }],
      appliedRefs: [ref],
    }), /evidence_transition_result_mutation_oid_mismatch/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

function commitFinalEvidence(fixture, { extraPath = false, secondCommit = false, wrongParent = false, mutations = {
  local_ref_deletions: [], tracking_ref_deletions: [], remote_ref_deletions: [],
} } = {}) {
  if (wrongParent) {
    writeFileSync(join(fixture.repo, "middle.txt"), "middle\n");
    fixtureGit(fixture.repo, "add", "middle.txt");
    fixtureGit(fixture.repo, "commit", "-q", "-m", "wrong final parent");
  }
  writeFileSync(join(fixture.repo, fixture.resultPath), `${JSON.stringify({ outcome: "blocked", mutations })}\n`);
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
    const legacyResult = JSON.parse(readFileSync(join(fixture.repo, fixture.resultPath), "utf8"));
    assert.equal(Object.hasOwn(legacyResult.mutations, "safety_ref_publications"), false);
    const after = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "after");
    assert.equal(after.final_evidence_commit, fixtureGit(fixture.repo, "rev-parse", "HEAD"));
    assert.deepEqual(after.final_evidence_paths, fixture.contract.evidence_transition.final_child_path_sets.blocked);
    assert.equal(after.final_file_pins.length, 2);
    assert.ok(after.final_file_pins.every((row) => /^[0-9a-f]{40,64}$/.test(row.blob) && /^[0-9a-f]{64}$/.test(row.sha256)));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("D-07 accepts a pinned allowlist inherited unchanged from the captured parent", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-inherited-allowlist-evidence-"));
  try {
    const fixture = makeEvidenceFixture(root, { inheritedEvidencePaths: [
      ".planning/phases/245-19-BRANCH-DELETE-ALLOWLIST.tsv",
    ] });
    const parentBlob = fixtureGit(fixture.repo, "rev-parse", `${fixture.capturedHeadOid}:${fixture.allowlistPath}`);
    const contractBlob = fixtureGit(fixture.repo, "rev-parse", `${fixture.contractCommit}:${fixture.allowlistPath}`);
    assert.equal(contractBlob, parentBlob, "the allowlist blob should be inherited unchanged");

    const before = inspectEvidenceTransition(fixture.repo, fixture.contractCommit, fixture.contractPath, fixture.contract, "before");
    assert.deepEqual(before.contract_paths, fixture.contract.evidence_transition.contract_paths);
    assert.ok(before.contract_paths.includes(fixture.allowlistPath));
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
    { name: "unrelated local ref", setup: (root) => makeEvidenceFixture(root), prepare: (fixture) => fixtureGit(fixture.repo, "branch", "unrelated"), stage: "before", error: /evidence_transition_local_ref_unexpected/ },
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
      headRepository: { nameWithOwner: "szTheory/sigra" },
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

test("origin branch capture does not require remote tip objects to be fetched locally", () => {
  const root = mkdtempSync(join(tmpdir(), "sigra-current-origin-unfetched-"));
  const source = join(root, "source");
  const bare = join(root, "origin.git");
  const repo = join(root, "checkout");
  const phase = ".planning/phases/245-branch-prune-local-and-remote";
  const fixturePath = join(repo, phase, "github-fixture.json");
  const contractPath = join(repo, phase, "current-contract.json");
  try {
    mkdirSync(source);
    run(GIT_BIN, ["init", "-q", "--initial-branch=main", source]);
    fixtureGit(source, "config", "user.name", "Unfetched Origin Fixture");
    fixtureGit(source, "config", "user.email", "unfetched-origin@example.invalid");
    writeFileSync(join(source, "main.txt"), "main\n");
    fixtureGit(source, "add", "main.txt");
    fixtureGit(source, "commit", "-q", "-m", "main root");
    run(GIT_BIN, ["init", "-q", "--bare", "--initial-branch=main", bare]);
    fixtureGit(source, "remote", "add", "origin", bare);
    fixtureGit(source, "push", "-q", "origin", "main:refs/heads/main");

    fixtureGit(source, "checkout", "--orphan", "gh-pages");
    fixtureGit(source, "rm", "-q", "-rf", ".");
    writeFileSync(join(source, "page.txt"), "independent remote page\n");
    fixtureGit(source, "add", "page.txt");
    fixtureGit(source, "commit", "-q", "-m", "independent gh-pages root");
    const ghPagesOid = fixtureGit(source, "rev-parse", "HEAD");
    fixtureGit(source, "push", "-q", "origin", "gh-pages:refs/heads/gh-pages");

    run(GIT_BIN, ["clone", "-q", "--depth=1", "--single-branch", "--branch", "main", `file://${bare}`, repo]);
    const objectMissing = spawnSync(GIT_BIN, ["-C", repo, "cat-file", "-e", `${ghPagesOid}^{commit}`], { encoding: "utf8" });
    assert.notEqual(objectMissing.status, 0, "the fixture checkout must not contain the remote-only branch tip");

    mkdirSync(join(repo, phase), { recursive: true });
    writeFileSync(fixturePath, JSON.stringify({ cliPulls: [], pages: [[]] }));
    const captured = run("node", [
      "scripts/maintainers/prune-stale-branches-current.mjs", "capture",
      "--repo", repo,
      "--output", contractPath,
      "--source-fixture", fixturePath,
    ], { cwd: ROOT });
    assert.match(captured, /captured current PR\/ref contract/);
    const contract = JSON.parse(readFileSync(contractPath, "utf8"));
    assert.deepEqual(
      contract.origin_refs.find((row) => row.ref === "refs/heads/gh-pages"),
      { ref: "refs/heads/gh-pages", oid: ghPagesOid, type: "commit", peeled_oid: null, peeled_type: null, symref: null },
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
