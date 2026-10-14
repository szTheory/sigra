// Phase 253 plan 43: actual installed-SDK contracts for accepted-only historical disposition.
// Every SDK answer below comes from a real `gsd-tools query` subprocess against a temporary
// committed repository; nothing here reads or writes the live Phase 253 tracking files.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

import * as reconcile from "./253-LOAD-RECOVERY-reconcile.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, "..", "..", "..");
const PHASE_DIR_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks";
const REAL_PHASE_DIR = join(REPO, PHASE_DIR_REL);
const SDK_ROOT = "/Users/jon/.codex/gsd-core";
const GSD_TOOLS = join(SDK_ROOT, "bin", "gsd-tools.cjs");
const SCRIPT = join(HERE, "253-LOAD-RECOVERY-reconcile.mjs");
const sha = (value) => createHash("sha256").update(value).digest("hex");
const cleanup = [];
after(() => { for (const dir of cleanup) rmSync(dir, { recursive: true, force: true }); });

function git(root, ...args) {
  const result = spawnSync("git", args, { cwd: root, encoding: "utf8" });
  assert.equal(result.status, 0, `git ${args.join(" ")} failed: ${result.stderr}`);
  return result.stdout;
}

function sdk(root, ...args) {
  const result = spawnSync(process.execPath, [GSD_TOOLS, "query", ...args, "--project-dir", root], { encoding: "utf8" });
  assert.equal(result.status, 0, `gsd-tools query ${args.join(" ")} failed: ${result.stderr}`);
  return JSON.parse(result.stdout);
}

function planText(id, dependsOn) {
  return `---\nphase: 253-demo\nplan: "${id}"\nwave: 1\ndepends_on: ${JSON.stringify(dependsOn)}\nautonomous: true\nrequirements: ["CIREL-01"]\n---\n<objective>\nobjective ${id}\n</objective>\n<tasks>\n<task type="auto"><name>t</name></task>\n</tasks>\n`;
}

// A committed temporary repository in the canonical Phase layout. `plans` maps a two-digit id to
// its depends_on list; `summaries` maps an id to the full SUMMARY text.
function makeRepo({ plans, summaries }) {
  const root = mkdtempSync(join(tmpdir(), "p253-43-"));
  cleanup.push(root);
  const dir = join(root, ".planning", "phases", "253-demo");
  mkdirSync(dir, { recursive: true });
  git(root, "init", "-q");
  git(root, "config", "user.email", "t@example.invalid");
  git(root, "config", "user.name", "fixture");
  writeFileSync(join(root, ".planning", "ROADMAP.md"), "# Roadmap\n### Phase 253: Demo\n**Goal**: x\n**Requirements**: CIREL-01\n**Plans:** 6 plans\n");
  writeFileSync(join(root, ".planning", "STATE.md"), "---\ngsd_state_version: 1.0\nmilestone: v1\nstatus: executing\n---\n# State\n");
  writeFileSync(join(root, ".planning", "config.json"), '{"mode":"yolo"}\n');
  for (const [id, deps] of Object.entries(plans)) writeFileSync(join(dir, `253-${id}-PLAN.md`), planText(id, deps));
  for (const [id, text] of Object.entries(summaries)) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), text);
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", "fixture");
  return { root, dir };
}

const HALTED = "---\nstatus: halted\n---\n# halted\n";
const BLOCKED = "---\nstatus: blocked\n---\n# blocked\n";
const SUPERSEDED = "---\nstatus: superseded\nexecution_performed: false\noriginal_status: blocked\nphase_verification_status: not_started\n---\n# routing disposition\n";
const COMPLETE = "---\nstatus: complete\n---\n# complete\n";

// 01 halted; 02 absent; 03 blocked-status summary; 04 superseded disposition; 05 depends on the disposition.
const PAIRING_PLANS = { "01": [], "02": ["253-01"], "03": ["253-01"], "04": ["253-01"], "05": ["253-04"] };
const PAIRING_SUMMARIES = { "01": HALTED, "03": BLOCKED, "04": SUPERSEDED };

function planHashes(dir) {
  return Object.fromEntries(readdirSync(dir).filter((name) => name.endsWith("-PLAN.md")).sort()
    .map((name) => [name, sha(readFileSync(join(dir, name)))]));
}

describe("installed SDK identity", () => {
  test("pins the observed package, version and every consulted source hash", () => {
    const result = reconcile.verifySdkPins();
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.equal(result.packageName, "@opengsd/gsd-core");
    assert.equal(result.version, "1.16.0");
    assert.equal(result.files.length, 7);
    const tampered = { ...reconcile.SDK_PINS, files: reconcile.SDK_PINS.files.map((f, i) => (i === 0 ? { ...f, sha256: "0".repeat(64) } : f)) };
    const bad = reconcile.verifySdkPins(tampered);
    assert.equal(bad.ok, false);
    assert.equal(bad.mismatches.length, 1);
  });
});

describe("summary pairing through the real SDK", () => {
  test("absent, blocked, halted and superseded summaries pair exactly as the installed SDK counts them", () => {
    const { root, dir } = makeRepo({ plans: PAIRING_PLANS, summaries: PAIRING_SUMMARIES });
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    // absent -> unpaired and incomplete
    assert.equal(by["253-02"].has_summary, false);
    // status: blocked is a failure record: unpaired in the index
    assert.equal(by["253-03"].has_summary, false);
    // halted still pairs, stays literally halted
    assert.equal(by["253-01"].has_summary, true);
    assert.equal(by["253-01"].halted, true);
    // superseded disposition pairs, is NOT halted, and keeps the inherited blocked_by literally
    assert.equal(by["253-04"].has_summary, true);
    assert.equal(by["253-04"].halted, false);
    assert.deepEqual(by["253-04"].blocked_by, ["253-01"]);
    // halt propagation is transitive through a superseded disposition
    assert.deepEqual(by["253-05"].blocked_by, ["253-01"]);
    assert.deepEqual(index.incomplete, ["253-02", "253-03", "253-05"]);
    assert.deepEqual(index.runnable, []);
    // the helper reports the same facts and also reads the literal summary status
    const report = reconcile.pairingReport(root, "253");
    const rows = Object.fromEntries(report.map((row) => [row.id, row]));
    assert.equal(rows["253-03"].summary_status, "blocked");
    assert.equal(rows["253-04"].summary_status, "superseded");
    assert.equal(rows["253-04"].execution_performed, false);
    assert.equal(rows["253-04"].original_status, "blocked");
    assert.equal(rows["253-01"].halted, true);
    assert.equal(rows["253-02"].summary_status, null);
    assert.ok(existsSync(dir));
  });

  test("init.execute-phase counts a blocked summary as summarized while phase-plan-index does not", () => {
    const { root } = makeRepo({ plans: PAIRING_PLANS, summaries: PAIRING_SUMMARIES });
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.ok(index.incomplete.includes("253-03"));
    assert.ok(!init.incomplete_plans.includes("253-03-PLAN.md"), "init pairs the blocked summary");
    assert.deepEqual(init.halted_plans, ["253-01-PLAN.md"]);
    const report = reconcile.pairingReport(root, "253");
    assert.equal(report.find((row) => row.id === "253-03").init_disagrees, true);
    assert.equal(report.find((row) => row.id === "253-04").init_disagrees, false);
  });

  test("adding a disposition leaves every original plan and the halted summary byte-identical", () => {
    const { root, dir } = makeRepo({ plans: PAIRING_PLANS, summaries: { "01": HALTED } });
    const plansBefore = planHashes(dir);
    const haltedBefore = sha(readFileSync(join(dir, "253-01-SUMMARY.md")));
    writeFileSync(join(dir, "253-04-SUMMARY.md"), SUPERSEDED);
    assert.deepEqual(planHashes(dir), plansBefore);
    assert.equal(sha(readFileSync(join(dir, "253-01-SUMMARY.md"))), haltedBefore);
    const by = Object.fromEntries(sdk(root, "phase-plan-index", "253").plans.map((p) => [p.id, p]));
    assert.equal(by["253-01"].halted, true);
    assert.equal(by["253-04"].has_summary, true);
    assert.deepEqual(by["253-04"].blocked_by, ["253-01"]);
    assert.equal(git(root, "status", "--short", "--", ".planning/phases/253-demo/253-01-PLAN.md").trim(), "");
  });
});

describe("unfiltered execute-phase routing reproduced against the installed workflow", () => {
  test("blocked-and-unsummarized work is a stuck phase, never verification", () => {
    const { root, dir } = makeRepo({ plans: { "01": [], "02": ["253-01"] }, summaries: { "01": HALTED } });
    const index = sdk(root, "phase-plan-index", "253");
    const verification = sdk(root, "verification", "status", dir);
    const route = reconcile.routeExecutePhase(index, verification, {});
    assert.equal(route.outcome, "phase_stuck");
    assert.deepEqual(route.blocked_plans, ["253-02"]);
    assert.deepEqual(route.skipped.filter((s) => s.reason === "has_summary").map((s) => s.id), ["253-01"]);
  });

  test("has_summary-first filtering reaches the phase gates once every old responsibility is summarized", () => {
    const { root, dir } = makeRepo({
      plans: { "01": [], "02": ["253-01"], "03": ["253-02"] },
      summaries: { "01": HALTED, "02": SUPERSEDED, "03": SUPERSEDED },
    });
    const index = sdk(root, "phase-plan-index", "253");
    const verification = sdk(root, "verification", "status", dir);
    assert.equal(verification.route, "execute-phase");
    assert.deepEqual(index.incomplete, []);
    // inherited blocked_by survives on summarized history
    assert.deepEqual(Object.fromEntries(index.plans.map((p) => [p.id, p.blocked_by])),
      { "253-01": [], "253-02": ["253-01"], "253-03": ["253-01"] });
    const route = reconcile.routeExecutePhase(index, verification, {});
    assert.equal(route.outcome, "resume_phase_gates");
    assert.equal(route.next_command, "$gsd-execute-phase 253");
    assert.deepEqual(route.blocked_plans, []);
    assert.ok(route.skipped.every((s) => s.reason === "has_summary"));
    // the literal-reading ambiguity is surfaced rather than hidden
    assert.deepEqual(route.inherited_blocked_on_summarized, ["253-02", "253-03"]);
  });

  test("a filtered run never jumps to verification", () => {
    const { root, dir } = makeRepo({ plans: { "01": [] }, summaries: { "01": COMPLETE } });
    const index = sdk(root, "phase-plan-index", "253");
    const verification = sdk(root, "verification", "status", dir);
    assert.equal(reconcile.routeExecutePhase(index, verification, { gapsOnly: true }).outcome, "no_matching_incomplete_plans");
    assert.equal(reconcile.routeExecutePhase(index, verification, { waveFilter: 1 }).outcome, "no_matching_incomplete_plans");
  });

  test("the installed workflow still carries the pinned filtering order and phase-gate route", () => {
    const text = readFileSync(join(SDK_ROOT, "workflows", "execute-phase.md"), "utf8");
    assert.ok(reconcile.WORKFLOW_ASSERTIONS.length >= 6);
    for (const phrase of reconcile.WORKFLOW_ASSERTIONS) assert.ok(text.includes(phrase), `workflow lost: ${phrase}`);
    const filterAt = text.indexOf("**Filtering:** Skip plans where `has_summary: true`.");
    const blockedAt = text.indexOf("Additionally skip any plan whose `blocked_by` array is non-empty");
    assert.ok(filterAt > 0 && blockedAt > filterAt, "has_summary skip must come before the blocked_by skip");
  });
});

describe("accepted-only predicate", () => {
  function runCli(args) {
    return spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
  }

  test("open completion evidence produces a nonzero exit and zero disposition bytes", () => {
    const { root, dir } = makeRepo({ plans: PAIRING_PLANS, summaries: { "01": HALTED } });
    const completion = join(root, "completion.json");
    writeFileSync(completion, JSON.stringify({ schema_version: "sigra.phase253.completion-evidence/v1", repository: "szTheory/sigra", links: {} }));
    const bundle = join(root, "bundle.json");
    const before = readdirSync(dir).sort();
    const result = runCli(["--prepare-dispositions", "--completion", completion, "--bundle", bundle, "--record", join(root, "record.json"), "--root", root]);
    assert.notEqual(result.status, 0, result.stdout);
    assert.equal(existsSync(bundle), false);
    assert.deepEqual(readdirSync(dir).sort(), before);
  });

  test("a forged embedded acceptance claim with unopenable links produces zero disposition bytes", () => {
    const { root, dir } = makeRepo({ plans: PAIRING_PLANS, summaries: { "01": HALTED } });
    const completion = join(root, "completion.json");
    const links = Object.fromEntries(["phase252_replay", "phase252_diagnosis", "load_controls", "load_acceptance", "publication", "canary", "pr_normal", "pr_docs_only"]
      .map((key) => [key, { path: `missing/${key}.json`, sha256: "a".repeat(64) }]));
    writeFileSync(completion, JSON.stringify({ schema_version: "sigra.phase253.completion-evidence/v1", repository: "szTheory/sigra", accepted: true, status: "accepted", links }));
    const bundle = join(root, "bundle.json");
    const before = readdirSync(dir).sort();
    const result = runCli(["--prepare-dispositions", "--completion", completion, "--bundle", bundle, "--record", join(root, "record.json"), "--root", root]);
    assert.notEqual(result.status, 0);
    assert.equal(existsSync(bundle), false);
    assert.deepEqual(readdirSync(dir).sort(), before);
    assert.equal(git(root, "status", "--short").trim(), "?? completion.json");
  });

  test("evaluateCompletion rejects when the real strict checker is not accepted", () => {
    const { root } = makeRepo({ plans: { "01": [] }, summaries: {} });
    const completion = join(root, "completion.json");
    writeFileSync(completion, JSON.stringify({ schema_version: "sigra.phase253.completion-evidence/v1", repository: "szTheory/sigra", links: {} }));
    const result = reconcile.evaluateCompletion({ completionPath: completion });
    assert.equal(result.accepted, false);
    assert.equal(result.verifier_kind, "real");
    assert.match(result.detail, /accepted-only completion failed|missing:/);
  });
});

// ---------------------------------------------------------------------------------------------
// Task 2: all-35 identities, eighteen responsibility mappings, accepted-only bundle/application
// ---------------------------------------------------------------------------------------------
const LINK_KEYS = ["phase252_replay", "phase252_diagnosis", "load_controls", "load_acceptance", "publication", "canary", "pr_normal", "pr_docs_only"];
const UNSTARTED = ["08", "10", "13", "14", "17", "21", "22", "23", "24", "25", "28", "29", "30", "31", "32", "33", "34", "35"];
const HALTED_IDS = ["02", "07", "09", "12", "16", "27"];
const COMPLETED_IDS = ["01", "03", "04", "05", "06", "11", "15", "18", "19", "20", "26"];
const EXPECTED_OWNERS = {
  "08": ["42", "46"], "13": ["42", "46"], "21": ["42", "46"], "30": ["42", "46"], "34": ["42", "46"], "24": ["46"],
  "10": ["36", "37", "38", "39", "40", "41"], "17": ["36", "37", "38", "39", "40", "41"],
  "28": ["36", "37", "38", "39", "40", "41"], "29": ["36", "37", "38", "39", "40", "41"],
  "14": ["43", "47"], "25": ["43", "47"], "31": ["43", "47"], "35": ["43", "47"],
  "22": ["44"], "32": ["44"], "23": ["45"], "33": ["45"],
};

// A committed temporary repository holding the real original plans and summaries. Plans 36-47
// that have no real summary yet get a FIXTURE-ONLY complete summary; nothing here touches the live phase.
function realisticFixture() {
  const root = mkdtempSync(join(tmpdir(), "p253-43-real-"));
  cleanup.push(root);
  const dir = join(root, PHASE_DIR_REL);
  mkdirSync(dir, { recursive: true });
  git(root, "init", "-q");
  git(root, "config", "user.email", "t@example.invalid");
  git(root, "config", "user.name", "fixture");
  writeFileSync(join(root, ".planning", "ROADMAP.md"), "# Roadmap\n### Phase 253: Demo\n**Goal**: x\n**Requirements**: CIREL-01, CIREL-02\n**Plans:** 47 plans\n");
  writeFileSync(join(root, ".planning", "STATE.md"), "---\ngsd_state_version: 1.0\nmilestone: v1\nstatus: executing\n---\n# State\n");
  writeFileSync(join(root, ".planning", "config.json"), '{"mode":"yolo"}\n');
  for (const name of readdirSync(REAL_PHASE_DIR)) {
    if (/^253-\d\d-(PLAN|SUMMARY)\.md$/.test(name)) copyFileSync(join(REAL_PHASE_DIR, name), join(dir, name));
  }
  for (let n = 36; n <= 47; n += 1) {
    const summary = join(dir, `253-${n}-SUMMARY.md`);
    if (!existsSync(summary)) writeFileSync(summary, COMPLETE);
  }
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", "fixture");
  return { root, dir };
}

function completionFixture(root, { omit = [] } = {}) {
  const links = {};
  mkdirSync(join(root, "proofs"), { recursive: true });
  for (const key of LINK_KEYS) {
    if (omit.includes(key)) continue;
    const body = JSON.stringify({ fixture_only: true, key });
    writeFileSync(join(root, "proofs", `${key}.json`), body);
    links[key] = { path: `proofs/${key}.json`, sha256: sha(body) };
  }
  const path = join(root, "completion.json");
  writeFileSync(path, JSON.stringify({ schema_version: "sigra.phase253.completion-evidence/v1", repository: "szTheory/sigra", links }));
  return path;
}

const acceptedVerifier = () => ({ exit: 0, stderr: "", stdout: JSON.stringify({
  status: "accepted", gaps: [], linked: [...LINK_KEYS].sort(), phase_verification: "not_started",
  requirements: { "CIREL-01": "accepted", "CIREL-02": "accepted" }, limitations: [] }) });
const openVerifier = () => ({ exit: 1, stdout: "", stderr: "hosted-gate-verify: FAIL: accepted-only completion failed: missing:pr_normal" });

function loadRealContract() {
  return reconcile.loadContract(join(REAL_PHASE_DIR, reconcile.CONTRACT_NAME));
}

describe("reconciliation contract", () => {
  test("identifies all 35 originals by plan hash, capture blob and audit inventory", () => {
    const contract = reconcile.buildContract();
    assert.equal(contract.originals.length, 35);
    const audit = readFileSync(join(REAL_PHASE_DIR, "253-LOAD-RECOVERY-SOURCE-SDK-AUDIT.md"), "utf8");
    const capture = JSON.parse(readFileSync(join(REAL_PHASE_DIR, "253-LOAD-RECOVERY-PLANNING-CAPTURE.json"), "utf8"));
    for (const original of contract.originals) {
      const file = `${original.plan}-PLAN.md`;
      assert.equal(original.plan_sha256, sha(readFileSync(join(REAL_PHASE_DIR, file))), file);
      assert.ok(audit.includes(`|${file}|${original.plan_sha256}|`), `${file} missing from audit inventory`);
      const entry = capture.paths.find((p) => p.path === `${PHASE_DIR_REL}/${file}`);
      assert.equal(entry.sha256, original.plan_sha256);
      assert.equal(original.capture.blob, entry.blob);
      assert.equal(original.capture.readback_exact, true);
    }
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), COMPLETED_IDS);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), HALTED_IDS);
    for (const halted of contract.halted_plans) {
      assert.equal(halted.summary.status, "halted");
      assert.ok(halted.receipts.length > 0, `${halted.plan} receipts`);
      for (const receipt of halted.receipts) assert.equal(receipt.sha256, sha(readFileSync(join(REPO, receipt.path))));
    }
    for (const completed of contract.completed_plans) assert.notEqual(completed.summary.status, "halted");
  });

  test("maps exactly the eighteen unstarted responsibilities and the halted proof owners", () => {
    const contract = reconcile.buildContract();
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), UNSTARTED);
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), EXPECTED_OWNERS);
    const twentyFour = contract.responsibilities.find((r) => r.plan === "253-24");
    assert.deepEqual(twentyFour.owners, ["253-46"]);
    assert.deepEqual(contract.halted_proof_map["253-02"].map((o) => o.slice(4)), ["36", "37", "38", "39", "40", "41"]);
    assert.deepEqual(contract.halted_proof_map["253-07"].map((o) => o.slice(4)), ["18", "19", "20", "42", "44", "45"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), HALTED_IDS.map((id) => `253-${id}`));
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.ok(responsibility.required_links.length > 0);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
      assert.ok(responsibility.blocked_by.every((id) => HALTED_IDS.includes(id.slice(4))), `${responsibility.plan} blocked by a non-halted plan`);
    }
  });

  test("the committed contract equals the regenerated bytes and --check-only never writes", () => {
    const committed = join(REAL_PHASE_DIR, reconcile.CONTRACT_NAME);
    const ok = spawnSync(process.execPath, [SCRIPT, "--prepare-contract", "--output", committed, "--check-only"], { encoding: "utf8" });
    assert.equal(ok.status, 0, ok.stderr);
    assert.equal(readFileSync(committed, "utf8"), reconcile.serializeContract(reconcile.buildContract()));
    const dir = mkdtempSync(join(tmpdir(), "p253-43-contract-"));
    cleanup.push(dir);
    const drifted = join(dir, "contract.json");
    writeFileSync(drifted, `${readFileSync(committed, "utf8")} `);
    const bad = spawnSync(process.execPath, [SCRIPT, "--prepare-contract", "--output", drifted, "--check-only"], { encoding: "utf8" });
    assert.notEqual(bad.status, 0);
    assert.equal(readFileSync(drifted, "utf8"), `${readFileSync(committed, "utf8")} `);
    const missing = join(dir, "absent.json");
    const none = spawnSync(process.execPath, [SCRIPT, "--prepare-contract", "--output", missing, "--check-only"], { encoding: "utf8" });
    assert.notEqual(none.status, 0);
    assert.equal(existsSync(missing), false);
  });
});

describe("accepted-only disposition bundle", () => {
  test("generates exactly eighteen superseded summaries that never claim execution", () => {
    const { root } = realisticFixture();
    const { contract, sha256: contractSha } = loadRealContract();
    const completion = completionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    assert.equal(bundle.verifier.kind, "injected-fixture");
    assert.deepEqual(bundle.entries.map((e) => e.plan.slice(4)), UNSTARTED);
    for (const entry of bundle.entries) {
      const fm = reconcile.frontmatter(entry.content);
      assert.equal(fm.status, "superseded");
      assert.equal(fm.execution_performed, false);
      assert.equal(fm.original_status, "blocked");
      assert.equal(fm.phase_verification_status, "not_started");
      assert.equal(entry.sha256, sha(entry.content));
      assert.equal(entry.path, `${PHASE_DIR_REL}/${entry.plan}-SUMMARY.md`);
      assert.match(entry.content, /did not run/i);
      assert.match(entry.content, /accepted_by:/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      const owners = EXPECTED_OWNERS[entry.plan.slice(4)];
      for (const owner of owners) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} missing owner ${owner}`);
    }
    // PR responsibilities cite exactly the two PR proofs by recorded hash
    const pr = bundle.entries.find((e) => e.plan === "253-08").content;
    assert.ok(pr.includes(`sha256: ${sha(JSON.stringify({ fixture_only: true, key: "pr_normal" }))}`));
    assert.ok(!pr.includes("proofs/canary.json"));
  });

  test("refuses to generate any bytes without real acceptance or complete linked proof", () => {
    const { root, dir } = realisticFixture();
    const { contract, sha256: contractSha } = loadRealContract();
    const completion = completionFixture(root);
    const attempt = (overrides) => () => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier, ...overrides });
    assert.throws(attempt({ verifier: openVerifier }), /accepted-only/);
    assert.throws(attempt({ completionPath: completionFixture(root, { omit: ["pr_docs_only"] }) }), /pr_docs_only/);
    writeFileSync(join(dir, "253-08-SUMMARY.md"), COMPLETE);
    assert.throws(attempt({}), /already exists/);
    rmSync(join(dir, "253-08-SUMMARY.md"));
    writeFileSync(join(dir, "253-10-PLAN.md"), `${readFileSync(join(dir, "253-10-PLAN.md"), "utf8")}\n`);
    assert.throws(attempt({}), /original plan/);
  });

  test("a missing proof-owner plan stops preparation", () => {
    const { root, dir } = realisticFixture();
    const { contract, sha256: contractSha } = loadRealContract();
    rmSync(join(dir, "253-46-PLAN.md"));
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completionFixture(root), verifier: acceptedVerifier }), /253-46/);
  });
});

describe("root-only write-ahead application", () => {
  function prepared() {
    const fx = realisticFixture();
    const { contract, sha256: contractSha } = loadRealContract();
    const completion = completionFixture(fx.root);
    const bundle = reconcile.prepareDispositions({ root: fx.root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    return { ...fx, contract, contractSha, completion, bundle, record: join(fx.root, "apply-record.json") };
  }
  const apply = (p, extra = {}) => reconcile.applyBundle({ root: p.root, contract: p.contract, contractSha256: p.contractSha, bundle: p.bundle, completionPath: p.completion, verifier: acceptedVerifier, allowFixture: true, recordPath: p.record, ...extra });

  test("before application the real SDK index leaves the old responsibilities unsummarized and stuck", () => {
    const p = prepared();
    const report = reconcile.checkIndex({ root: p.root, contract: p.contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), UNSTARTED);
    assert.equal(report.route.outcome, "phase_stuck");
  });

  test("applies exact bytes to nonexistent paths, leaves history and dirty tracking untouched, and reaches the phase gates", () => {
    const p = prepared();
    writeFileSync(join(p.root, ".planning", "config.json"), '{"mode":"yolo","operator":"edit"}\n');
    const dirtyBefore = sha(readFileSync(join(p.root, ".planning", "config.json")));
    const originalsBefore = planHashes(p.dir);
    const haltedBefore = Object.fromEntries(HALTED_IDS.map((id) => [id, sha(readFileSync(join(p.dir, `253-${id}-SUMMARY.md`)))]));
    const record = apply(p);
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 18);
    const journal = JSON.parse(readFileSync(p.record, "utf8"));
    assert.equal(journal.applied, true);
    assert.equal(journal.write_ahead_recorded_before_write, true);
    for (const entry of p.bundle.entries) {
      assert.equal(readFileSync(join(p.root, entry.path), "utf8"), entry.content);
    }
    assert.deepEqual(planHashes(p.dir), originalsBefore);
    for (const id of HALTED_IDS) assert.equal(sha(readFileSync(join(p.dir, `253-${id}-SUMMARY.md`))), haltedBefore[id]);
    assert.equal(sha(readFileSync(join(p.root, ".planning", "config.json"))), dirtyBefore);
    assert.match(git(p.root, "status", "--short"), / M \.planning\/config\.json/);
    const report = reconcile.checkIndex({ root: p.root, contract: p.contract });
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.deepEqual(report.old_unsummarized, []);
    assert.deepEqual(report.any_unsummarized, []);
    assert.equal(report.halted_literal, true);
    assert.equal(report.route.outcome, "resume_phase_gates");
    assert.equal(report.route.next_command, "$gsd-execute-phase 253");
    const by = Object.fromEntries(sdk(p.root, "phase-plan-index", "253").plans.map((plan) => [plan.id, plan]));
    for (const id of HALTED_IDS) assert.equal(by[`253-${id}`].halted, true);
    assert.deepEqual(by["253-08"].blocked_by, ["253-02", "253-07"]);
    assert.equal(by["253-08"].has_summary, true);
    assert.equal(by["253-08"].halted, false);
  });

  test("a second application, a tampered bundle or a fixture bundle without the fixture flag writes nothing", () => {
    const p = prepared();
    const before = readdirSync(p.dir).sort();
    const tampered = { ...p.bundle, entries: p.bundle.entries.map((e, i) => (i === 3 ? { ...e, content: `${e.content}extra\n`, sha256: sha(`${e.content}extra\n`) } : e)) };
    assert.throws(() => apply(p, { bundle: tampered }), /bundle/);
    assert.throws(() => apply(p, { allowFixture: false }), /fixture/);
    assert.deepEqual(readdirSync(p.dir).sort(), before);
    apply(p);
    assert.throws(() => apply(p), /already exists/);
  });

  test("a mid-application failure removes only this run's files and records the rollback", () => {
    const p = prepared();
    const before = readdirSync(p.dir).sort();
    let writes = 0;
    assert.throws(() => apply(p, { hooks: { afterWrite: () => { writes += 1; if (writes === 5) throw new Error("injected failure"); } } }), /injected failure/);
    assert.deepEqual(readdirSync(p.dir).sort(), before);
    const journal = JSON.parse(readFileSync(p.record, "utf8"));
    assert.equal(journal.applied, false);
    assert.equal(journal.rolled_back, true);
    assert.equal(journal.write_ahead_recorded_before_write, true);
  });

  test("an owner plan without a completion summary blocks application", () => {
    const p = prepared();
    rmSync(join(p.dir, "253-47-SUMMARY.md"));
    const before = readdirSync(p.dir).sort();
    assert.throws(() => apply(p), /253-47/);
    assert.deepEqual(readdirSync(p.dir).sort(), before);
  });

  test("--check-index and --dry-run report through the CLI without writing disposition bytes", () => {
    const p = prepared();
    const recordPath = join(p.root, "index-record.json");
    const stuck = spawnSync(process.execPath, [SCRIPT, "--check-index", "253", "--record", recordPath, "--root", p.root], { encoding: "utf8" });
    assert.equal(stuck.status, 1, stuck.stderr);
    assert.equal(JSON.parse(readFileSync(recordPath, "utf8")).ok, false);
    const open = join(p.root, "open.json");
    writeFileSync(open, JSON.stringify({ schema_version: "sigra.phase253.completion-evidence/v1", repository: "szTheory/sigra", links: {} }));
    const dryRecord = join(p.root, "dry-record.json");
    const dry = spawnSync(process.execPath, [SCRIPT, "--dry-run", "--completion", open, "--record", dryRecord, "--root", p.root], { encoding: "utf8" });
    assert.notEqual(dry.status, 0);
    const parsed = JSON.parse(readFileSync(dryRecord, "utf8"));
    assert.equal(parsed.accepted, false);
    assert.equal(parsed.disposition_bytes_generated, false);
    assert.equal(existsSync(join(p.dir, "253-08-SUMMARY.md")), false);
    apply(p);
    const done = spawnSync(process.execPath, [SCRIPT, "--check-index", "253", "--record", recordPath, "--root", p.root], { encoding: "utf8" });
    assert.equal(done.status, 0, done.stderr);
    assert.equal(JSON.parse(readFileSync(recordPath, "utf8")).ok, true);
  });
});
