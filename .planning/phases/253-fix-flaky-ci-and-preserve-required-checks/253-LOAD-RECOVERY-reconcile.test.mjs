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
    // v1 world only: plans 48-56 (R2) did not exist when this fixture was written; the R2 tests use r2Fixture.
    const match = /^253-(\d\d)-(PLAN|SUMMARY)\.md$/.exec(name);
    if (match && Number(match[1]) <= 47) copyFileSync(join(REAL_PHASE_DIR, name), join(dir, name));
  }
  for (let n = 36; n <= 47; n += 1) {
    const summary = join(dir, `253-${n}-SUMMARY.md`);
    // 253-40 now exists as a real halted summary; the v1 world models it as a completed owner.
    if (!existsSync(summary) || n === 40) writeFileSync(summary, COMPLETE);
  }
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", "fixture");
  return { root, dir };
}

function completionFixture(root, { omit = [], name = "completion.json" } = {}) {
  const links = {};
  mkdirSync(join(root, "proofs"), { recursive: true });
  for (const key of LINK_KEYS) {
    if (omit.includes(key)) continue;
    const body = JSON.stringify({ fixture_only: true, key });
    writeFileSync(join(root, "proofs", `${key}.json`), body);
    links[key] = { path: `proofs/${key}.json`, sha256: sha(body) };
  }
  const path = join(root, name);
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
    assert.throws(attempt({ completionPath: completionFixture(root, { omit: ["pr_docs_only"], name: "completion-partial.json" }) }), /pr_docs_only/);
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

// ---------------------------------------------------------------------------------------------
// Plan 50: additive R2 revision (--revision r2) re-pointing the 253-40 line to plans 48-56
// ---------------------------------------------------------------------------------------------
const V1_CONTRACT_SHA = "5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5";
const R2_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R2.json";
const R2_UNSTARTED = [...UNSTARTED, "41", "44", "45", "46", "47"].sort();
const R2_HALTED = [...HALTED_IDS, "40"];
const R2_COMPLETED = [...COMPLETED_IDS, "36", "37", "38", "39", "42", "43"];
const R2_NATIVE = ["36", "37", "38", "39", "48", "51", "52"];
const R2_OWNERS = {
  "08": ["42", "55"], "13": ["42", "55"], "21": ["42", "55"], "30": ["42", "55"], "34": ["42", "55"], "24": ["55"],
  "10": R2_NATIVE, "17": R2_NATIVE, "28": R2_NATIVE, "29": R2_NATIVE,
  "14": ["43", "50", "56"], "25": ["43", "50", "56"], "31": ["43", "50", "56"], "35": ["43", "50", "56"],
  "22": ["53"], "32": ["53"], "23": ["54"], "33": ["54"],
  "41": ["48", "51", "52"], "44": ["53"], "45": ["54"], "46": ["55"], "47": ["50", "56"],
};
const NEVER_RAN = ["41", "44", "45", "46", "47"];
const NEW_PLAN_IDS = ["48", "49", "50", "51", "52", "53", "54", "55", "56"];

// A committed copy of the R2-world phase plan set: every PLAN 01-56 and the SUMMARYs of 01-47 only,
// so the answers do not drift as plans 48-56 later gain their own summaries, nor as the R3 plans
// (57-68) are committed. Never the live phase.
function r2Fixture() {
  return worldFixture({ maxPlan: 56, maxSummary: 47, label: "r2" });
}

function worldFixture({ maxPlan, maxSummary, label }) {
  const root = mkdtempSync(join(tmpdir(), `p253-${label}-`));
  cleanup.push(root);
  const dir = join(root, PHASE_DIR_REL);
  mkdirSync(dir, { recursive: true });
  git(root, "init", "-q");
  git(root, "config", "user.email", "t@example.invalid");
  git(root, "config", "user.name", "fixture");
  writeFileSync(join(root, ".planning", "ROADMAP.md"), `# Roadmap\n### Phase 253: Demo\n**Goal**: x\n**Requirements**: CIREL-01, CIREL-02\n**Plans:** ${maxPlan} plans\n`);
  writeFileSync(join(root, ".planning", "STATE.md"), "---\ngsd_state_version: 1.0\nmilestone: v1\nstatus: executing\n---\n# State\n");
  writeFileSync(join(root, ".planning", "config.json"), '{"mode":"yolo"}\n');
  for (const name of readdirSync(REAL_PHASE_DIR)) {
    const match = /^253-(\d\d)-(PLAN|SUMMARY)\.md$/.exec(name);
    if (!match) continue;
    if (Number(match[1]) > maxPlan) continue;
    if (match[2] === "SUMMARY" && Number(match[1]) > maxSummary) continue;
    copyFileSync(join(REAL_PHASE_DIR, name), join(dir, name));
  }
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", "fixture");
  return { root, dir };
}

describe("R2 reconciliation contract", () => {
  test("the default revision and the committed v1 contract stay byte-identical", () => {
    const committed = readFileSync(join(REAL_PHASE_DIR, reconcile.CONTRACT_NAME), "utf8");
    assert.equal(sha(committed), V1_CONTRACT_SHA);
    assert.equal(reconcile.serializeContract(reconcile.buildContract()), committed);
    assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision: "v1" })), committed);
    assert.throws(() => reconcile.buildContract({ revision: "r9" }), /revision/);
  });

  test("partitions the 47 pre-R2 plans into 17 completed, 7 halted and 23 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r2" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r2");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R2_COMPLETED.slice().sort());
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R2_HALTED);
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R2_UNSTARTED);
    assert.equal(contract.responsibilities.length, 23);
    assert.equal(contract.halted_plans.length, 7);
    assert.equal(contract.originals.length, 47);
    assert.equal(contract.halted_plans.find((p) => p.plan === "253-40").summary.status, "halted");
    for (const id of NEVER_RAN) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-40"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, "dependency 253-40 halted on host sleep");
    }
  });

  test("maps every responsibility to the R2 proof owners and never to 40/41/44-47", () => {
    const contract = reconcile.buildContract({ revision: "r2" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R2_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of ["40", "41", "44", "45", "46", "47"]) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["41"], ["load_controls", "load_acceptance"]);
    assert.deepEqual(links["44"], ["publication"]);
    assert.deepEqual(links["45"], ["canary"]);
    assert.deepEqual(links["46"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["47"], LINK_KEYS);
    assert.deepEqual(contract.halted_proof_map["253-40"], ["253-48", "253-51"]);
    assert.deepEqual(contract.halted_proof_map["253-02"].map((o) => o.slice(4)), R2_NATIVE);
    assert.deepEqual(contract.halted_proof_map["253-07"].map((o) => o.slice(4)), ["18", "19", "20", "42", "53", "54"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R2_HALTED.map((id) => `253-${id}`));
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-56");
  });

  test("pins every PLAN 01-56, the halted 40 summary, the 36-43 summaries, the v1 contract and the SDK", () => {
    const contract = reconcile.buildContract({ revision: "r2" });
    assert.equal(contract.plan_pins.length, 56);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 56 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
  });

  test("CLI --revision r2 --prepare-contract --check-only matches, drifts fail and nothing is created", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-50-contract-"));
    cleanup.push(dir);
    const target = join(dir, R2_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r2" }));
    const absent = spawnSync(process.execPath, [SCRIPT, "--revision", "r2", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.notEqual(absent.status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = spawnSync(process.execPath, [SCRIPT, "--revision", "r2", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    const bad = spawnSync(process.execPath, [SCRIPT, "--revision", "r2", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.notEqual(bad.status, 0);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r9", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.notEqual(unknown.status, 0);
    const v1 = spawnSync(process.execPath, [SCRIPT, "--prepare-contract", "--output", join(REAL_PHASE_DIR, reconcile.CONTRACT_NAME), "--check-only"], { encoding: "utf8" });
    assert.equal(v1.status, 0, v1.stderr);
  });
});

describe("R2 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("253-48, 253-49 and 253-50 are runnable now and the never-run plans stay blocked by 253-40", () => {
    const { root } = r2Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of ["253-48", "253-49", "253-50"]) {
      assert.deepEqual(by[id].blocked_by, [], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.equal(by[id].ready, true, `${id} ready`);
      assert.ok(index.runnable.includes(id), `${id} runnable`);
    }
    for (const id of ["253-41", "253-44", "253-45", "253-46", "253-47"]) {
      assert.deepEqual(by[id].blocked_by, ["253-40"], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.ok(index.incomplete.includes(id));
    }
    assert.equal(by["253-40"].halted, true);
    const contract = reconcile.buildContract({ revision: "r2" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.equal(report.route.outcome, "dispatch_plans");
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R2_UNSTARTED);
  });

  test("after simulated R2 dispositions and new-plan summaries nothing is incomplete and nothing reports blocked", () => {
    const { root, dir } = r2Fixture();
    for (const id of NEW_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r2" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    assert.equal(bundle.entries.length, 23);
    for (const entry of bundle.entries) {
      const id = entry.plan.slice(4);
      for (const owner of R2_OWNERS[id]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
      if (NEVER_RAN.includes(id)) {
        assert.match(entry.content, /never ran because its dependency 253-40 halted on host sleep/);
        assert.match(entry.content, /R2 successor/);
      }
      assert.match(entry.content, /status: superseded/);
      assert.match(entry.content, /execution_performed: false/);
    }
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 23);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    const halted = index.plans.filter((p) => p.halted).map((p) => p.id.slice(4));
    assert.deepEqual(halted, R2_HALTED);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 56);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of NEVER_RAN) {
      const row = rows.find((r) => r.id === `253-${id}`);
      assert.equal(row.summary_status, "superseded");
      assert.equal(row.execution_performed, false);
      assert.equal(row.original_status, "blocked");
    }
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.equal(report.halted_literal, true);
    assert.equal(report.route.outcome, "resume_phase_gates");
  });

  test("a status: blocked summary anywhere, or a rewritten pinned plan, is refused", () => {
    const { root, dir } = r2Fixture();
    for (const id of NEW_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r2" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    writeFileSync(join(dir, "253-51-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-51/);
    writeFileSync(join(dir, "253-51-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-52-PLAN.md"), `${readFileSync(join(dir, "253-52-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), /253-52|differs/);
    assert.equal(existsSync(join(dir, "253-41-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// Plan 61: additive R3 revision (--revision r3) re-pointing 52-56 and the R2 twenty-three to 57-68
// ---------------------------------------------------------------------------------------------
const R2_CONTRACT_NAME_FOR_R3 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R2.json";
const R2_CONTRACT_SHA = "dc29b0963c4b6948bcb5a3b1c2cc058f84ea5b81da7364bafc7509f2448694ed";
const R3_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R3.json";
const R3_NEW_UNSTARTED = ["52", "53", "54", "55", "56"];
const R3_UNSTARTED = [...R2_UNSTARTED, ...R3_NEW_UNSTARTED].sort();
const R3_HALTED = [...R2_HALTED, "51"];
const R3_COMPLETED = [...R2_COMPLETED, "48", "49", "50"];
const R3_NATIVE = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "63", "64"];
const R3_COMPLETION = ["43", "50", "61", "68"];
const R3_OWNERS = {
  "08": ["42", "67"], "13": ["42", "67"], "21": ["42", "67"], "30": ["42", "67"], "34": ["42", "67"], "24": ["67"],
  "10": R3_NATIVE, "17": R3_NATIVE, "28": R3_NATIVE, "29": R3_NATIVE,
  "14": R3_COMPLETION, "25": R3_COMPLETION, "31": R3_COMPLETION, "35": R3_COMPLETION,
  "22": ["65"], "32": ["65"], "23": ["66"], "33": ["66"],
  "41": ["48", "62", "63", "64"], "44": ["65"], "45": ["66"], "46": ["67"], "47": ["50", "61", "68"],
  "52": ["62", "63", "64"], "53": ["65"], "54": ["66"], "55": ["67"], "56": ["61", "68"],
};
const R3_NEVER_RAN_51 = "dependency 253-51 halted on a non-infrastructure native control failure";
const R3_PLAN_IDS = Array.from({ length: 12 }, (_, i) => String(57 + i));

function r3Fixture() {
  return worldFixture({ maxPlan: 68, maxSummary: 51, label: "r3" });
}

describe("R3 reconciliation contract", () => {
  test("v1 and R2 contracts and their default code paths stay byte-identical", () => {
    const v1 = readFileSync(join(REAL_PHASE_DIR, reconcile.CONTRACT_NAME), "utf8");
    const r2 = readFileSync(join(REAL_PHASE_DIR, R2_CONTRACT_NAME_FOR_R3), "utf8");
    assert.equal(sha(v1), V1_CONTRACT_SHA);
    assert.equal(sha(r2), R2_CONTRACT_SHA);
    assert.equal(reconcile.serializeContract(reconcile.buildContract()), v1);
    assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision: "r2" })), r2);
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5"]);
  });

  test("partitions PLANs 01-56 into 20 completed, 8 halted and 28 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r3" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r3");
    assert.equal(contract.revision, "r3");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R3_COMPLETED.slice().sort());
    assert.equal(contract.completed_plans.length, 20);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R3_HALTED);
    assert.equal(contract.halted_plans.length, 8);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(8).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R3_UNSTARTED);
    assert.equal(contract.responsibilities.length, 28);
    assert.equal(contract.originals.length, 56);
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 56 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const id of ["41", "44", "45", "46", "47"]) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-40"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, "dependency 253-40 halted on host sleep");
    }
    for (const id of R3_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-51"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, R3_NEVER_RAN_51);
    }
  });

  test("maps every responsibility to the R3 proof owners and never to 40/41/44-47/51-56", () => {
    const contract = reconcile.buildContract({ revision: "r3" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R3_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of ["40", "41", "44", "45", "46", "47", "51", "52", "53", "54", "55", "56"]) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["52"], ["load_controls", "load_acceptance"]);
    assert.deepEqual(links["53"], ["publication"]);
    assert.deepEqual(links["54"], ["canary"]);
    assert.deepEqual(links["55"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["56"], LINK_KEYS);
    assert.deepEqual(links["47"], LINK_KEYS);
    for (const [id, expected] of Object.entries({ "22": ["publication"], "23": ["canary"], "41": ["load_controls", "load_acceptance"] })) assert.deepEqual(links[id], expected);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R3_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R3_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "65", "66"]);
    assert.deepEqual(contract.halted_proof_map["253-40"], ["253-48", "253-62", "253-63"]);
    assert.deepEqual(contract.halted_proof_map["253-51"], ["253-57", "253-58", "253-59", "253-60", "253-62", "253-63"]);
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-68");
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
    assert.match(contract.application.targets, /twenty-eight/);
  });

  test("pins every PLAN 01-68, the existing 36-43 and 48-51 summaries, the v1 and R2 contracts and the SDK", () => {
    const contract = reconcile.buildContract({ revision: "r3" });
    assert.equal(contract.plan_pins.length, 68);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 68 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
  });

  test("the builder refuses a missing R3 proof-owner plan (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-61-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r3" });
    assert.equal(built.plan_pins.length, 68);
    rmSync(join(root, PHASE_DIR_REL, "253-64-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r3" }), /253-64.*missing|missing/);
  });

  test("CLI --revision r3 --prepare-contract --check-only matches, drifts fail and nothing is created", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-61-contract-"));
    cleanup.push(dir);
    const target = join(dir, R3_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r3" }));
    const absent = spawnSync(process.execPath, [SCRIPT, "--revision", "r3", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.notEqual(absent.status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = spawnSync(process.execPath, [SCRIPT, "--revision", "r3", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    const bad = spawnSync(process.execPath, [SCRIPT, "--revision", "r3", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.notEqual(bad.status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const run = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(run.status, 0, run.stderr);
    }
  });
});

describe("R3 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("253-57, 253-58, 253-59 and 253-61 are runnable now and 52-56 stay blocked by halted 253-51", () => {
    const { root } = r3Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of ["253-57", "253-58", "253-59", "253-61"]) {
      assert.deepEqual(by[id].blocked_by, [], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.equal(by[id].ready, true, `${id} ready`);
      assert.ok(index.runnable.includes(id), `${id} runnable`);
    }
    for (const id of R3_NEW_UNSTARTED.map((n) => `253-${n}`)) {
      assert.deepEqual(by[id].blocked_by, ["253-51"], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.ok(index.incomplete.includes(id));
    }
    assert.equal(by["253-51"].halted, true);
    const contract = reconcile.buildContract({ revision: "r3" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.equal(report.route.outcome, "dispatch_plans");
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R3_UNSTARTED);
  });

  test("after simulated R3 dispositions and 57-68 summaries nothing is incomplete and nothing reports blocked", () => {
    const { root, dir } = r3Fixture();
    for (const id of R3_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r3" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    assert.equal(bundle.entries.length, 28);
    for (const entry of bundle.entries) {
      const id = entry.plan.slice(4);
      for (const owner of R3_OWNERS[id]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
      assert.match(entry.content, /status: superseded/);
      assert.match(entry.content, /execution_performed: false/);
      assert.match(entry.content, /original_status: blocked/);
      if (["41", "44", "45", "46", "47"].includes(id)) assert.match(entry.content, /never ran because its dependency 253-40 halted on host sleep\. Its R3 successor/);
      if (R3_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-51 halted on a non-infrastructure native control failure\. Its R3 successor/);
    }
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 28);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R3_HALTED);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 68);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R3_NEW_UNSTARTED, "41", "47"]) {
      const row = rows.find((r) => r.id === `253-${id}`);
      assert.equal(row.summary_status, "superseded");
      assert.equal(row.execution_performed, false);
      assert.equal(row.original_status, "blocked");
    }
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.equal(report.halted_literal, true);
    assert.equal(report.route.outcome, "resume_phase_gates");
  });

  test("a status: blocked owner summary, or a rewritten pinned plan, is refused", () => {
    const { root, dir } = r3Fixture();
    for (const id of R3_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r3" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    writeFileSync(join(dir, "253-62-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-62/);
    writeFileSync(join(dir, "253-62-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-63-PLAN.md"), `${readFileSync(join(dir, "253-63-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), /253-63|differs/);
    assert.equal(existsSync(join(dir, "253-52-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// Plan 71: additive R4 revision (--revision r4) re-pointing 64-68 and the R3 twenty-eight to 69-78
// ---------------------------------------------------------------------------------------------
const R3_CONTRACT_SHA = "6a50c6fe4b8a439778f0594c532a271dc7d1e1e8900c15d831693127c850333d";
const R4_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R4.json";
const R4_NEW_UNSTARTED = ["64", "65", "66", "67", "68"];
const R4_UNSTARTED = [...R3_UNSTARTED, ...R4_NEW_UNSTARTED].sort();
const R4_HALTED = [...R3_HALTED, "63"];
const R4_COMPLETED = [...R3_COMPLETED, "57", "58", "59", "60", "61", "62"].sort();
const R4_NATIVE = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "69", "70", "72", "73", "74"];
const R4_COMPLETION = ["43", "50", "61", "71", "78"];
const R4_OWNERS = {
  "08": ["42", "77"], "13": ["42", "77"], "21": ["42", "77"], "30": ["42", "77"], "34": ["42", "77"], "24": ["77"],
  "10": R4_NATIVE, "17": R4_NATIVE, "28": R4_NATIVE, "29": R4_NATIVE,
  "14": R4_COMPLETION, "25": R4_COMPLETION, "31": R4_COMPLETION, "35": R4_COMPLETION,
  "22": ["75"], "32": ["75"], "23": ["76"], "33": ["76"],
  "41": ["48", "62", "72", "73", "74"], "44": ["75"], "45": ["76"], "46": ["77"], "47": ["50", "61", "71", "78"],
  "52": ["62", "72", "73", "74"], "53": ["75"], "54": ["76"], "55": ["77"], "56": ["71", "78"],
  "64": ["72", "73", "74"], "65": ["75"], "66": ["76"], "67": ["77"], "68": ["71", "78"],
};
const R4_NEVER_RAN_63 = "dependency 253-63 halted on a non-infrastructure runner validator rejection";
const R4_PLAN_IDS = Array.from({ length: 10 }, (_, i) => String(69 + i));
const FROZEN_TOOLING_R4 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "236304e686e89015a9f292545925fb9e5e10ca8965d507923e662a1cd3ff039f",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "c91a02f5c951d50e7674ea60a68b4416a1a780f3b8c54079cd657d72db246c38",
};

function r4Fixture() {
  return worldFixture({ maxPlan: 78, maxSummary: 63, label: "r4" });
}

describe("R4 reconciliation contract", () => {
  test("v1, R2 and R3 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5"]);
  });

  test("partitions PLANs 01-68 into 26 completed, 9 halted and 33 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r4" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r4");
    assert.equal(contract.revision, "r4");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R4_COMPLETED);
    assert.equal(contract.completed_plans.length, 26);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R4_HALTED);
    assert.equal(contract.halted_plans.length, 9);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(9).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R4_UNSTARTED);
    assert.equal(contract.responsibilities.length, 33);
    assert.equal(contract.originals.length, 68);
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 68 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const id of ["41", "44", "45", "46", "47"]) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-40"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, "dependency 253-40 halted on host sleep");
      assert.equal(row.successor_revision, "R4");
    }
    for (const id of R3_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-51"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, R3_NEVER_RAN_51);
      assert.equal(row.successor_revision, "R4");
    }
    for (const id of R4_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-63"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, R4_NEVER_RAN_63);
      assert.equal(row.successor_revision, "R4");
    }
    const eight = contract.responsibilities.find((r) => r.plan === "253-08");
    assert.equal(eight.successor_revision, "R4");
    assert.equal(eight.never_ran_reason, undefined);
  });

  test("maps every responsibility to the R4 proof owners and never to 40/41/44-47/51-56/63-68", () => {
    const contract = reconcile.buildContract({ revision: "r4" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R4_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of ["40", "41", "44", "45", "46", "47", "51", "52", "53", "54", "55", "56", "63", "64", "65", "66", "67", "68"]) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["64"], ["load_controls", "load_acceptance"]);
    assert.deepEqual(links["65"], ["publication"]);
    assert.deepEqual(links["66"], ["canary"]);
    assert.deepEqual(links["67"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["68"], LINK_KEYS);
    assert.deepEqual(links["56"], LINK_KEYS);
    assert.deepEqual(links["47"], LINK_KEYS);
    for (const [id, expected] of Object.entries({ "22": ["publication"], "23": ["canary"], "41": ["load_controls", "load_acceptance"], "52": ["load_controls", "load_acceptance"] })) assert.deepEqual(links[id], expected);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R4_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R4_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "75", "76"]);
    assert.deepEqual(contract.halted_proof_map["253-40"], ["253-48", "253-62", "253-72", "253-73"]);
    assert.deepEqual(contract.halted_proof_map["253-51"], ["253-57", "253-58", "253-59", "253-60", "253-62", "253-69", "253-70", "253-72", "253-73"]);
    assert.deepEqual(contract.halted_proof_map["253-63"], ["253-69", "253-70", "253-72", "253-73"]);
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-78");
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
    assert.match(contract.application.targets, /thirty-three/);
  });

  test("pins every PLAN 01-78, the existing 36-43, 48-51 and 57-63 summaries, the v1/R2/R3 contracts and the SDK", () => {
    const contract = reconcile.buildContract({ revision: "r4" });
    assert.equal(contract.plan_pins.length, 78);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 78 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51", "57", "58", "59", "60", "61", "62", "63"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
  });

  test("253-61's tooling receipts are frozen at their recorded bytes so later edits never drift r4", () => {
    const contract = reconcile.buildContract({ revision: "r4" });
    const sixtyOne = contract.completed_plans.find((p) => p.plan === "253-61");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R4)) {
      const receipt = sixtyOne.receipts.find((r) => r.path === path);
      assert.ok(receipt, `${path} receipt present`);
      assert.equal(receipt.sha256, hash, `${path} held at its recorded hash`);
    }
    const contractReceipt = sixtyOne.receipts.find((r) => r.path.endsWith(R3_CONTRACT_NAME));
    assert.equal(contractReceipt.sha256, R3_CONTRACT_SHA);
  });

  test("the builder refuses a missing PLAN 69-78 or proof-owner plan (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-71-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r4" });
    assert.equal(built.plan_pins.length, 78);
    rmSync(join(root, PHASE_DIR_REL, "253-75-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r4" }), /253-75/);
  });

  test("CLI --revision r4 --prepare-contract --check-only matches, drifts fail and nothing is created", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-71-contract-"));
    cleanup.push(dir);
    const target = join(dir, R4_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r4" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r4", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R4 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("253-69 and 253-71 are runnable now and 64-68 stay blocked by halted 253-63", () => {
    const { root } = r4Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of ["253-69", "253-71"]) {
      assert.deepEqual(by[id].blocked_by, [], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.equal(by[id].ready, true, `${id} ready`);
      assert.ok(index.runnable.includes(id), `${id} runnable`);
    }
    for (const id of R4_NEW_UNSTARTED.map((n) => `253-${n}`)) {
      assert.deepEqual(by[id].blocked_by, ["253-63"], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.ok(index.incomplete.includes(id));
    }
    assert.equal(by["253-63"].halted, true);
    assert.equal(by["253-51"].halted, true);
    const contract = reconcile.buildContract({ revision: "r4" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.equal(report.route.outcome, "dispatch_plans");
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R4_UNSTARTED);
  });

  test("after simulated R4 dispositions and 69-78 summaries nothing is incomplete and nothing reports blocked", () => {
    const { root, dir } = r4Fixture();
    for (const id of R4_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r4" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    assert.equal(bundle.entries.length, 33);
    for (const entry of bundle.entries) {
      const id = entry.plan.slice(4);
      for (const owner of R4_OWNERS[id]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
      assert.match(entry.content, /status: superseded/);
      assert.match(entry.content, /execution_performed: false/);
      assert.match(entry.content, /original_status: blocked/);
      if (["41", "44", "45", "46", "47"].includes(id)) assert.match(entry.content, /never ran because its dependency 253-40 halted on host sleep\. Its R4 successor/);
      if (R3_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-51 halted on a non-infrastructure native control failure\. Its R4 successor/);
      if (R4_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-63 halted on a non-infrastructure runner validator rejection\. Its R4 successor/);
    }
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 33);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R4_HALTED);
    assert.equal(index.plans.filter((p) => p.halted).length, 9);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 78);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R4_NEW_UNSTARTED, ...R3_NEW_UNSTARTED, "41", "47"]) {
      const row = rows.find((r) => r.id === `253-${id}`);
      assert.equal(row.summary_status, "superseded");
      assert.equal(row.execution_performed, false);
      assert.equal(row.original_status, "blocked");
    }
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.equal(report.halted_literal, true);
    assert.equal(report.route.outcome, "resume_phase_gates");
  });

  test("a status: blocked owner summary, or a rewritten pinned plan, is refused", () => {
    const { root, dir } = r4Fixture();
    for (const id of R4_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r4" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    writeFileSync(join(dir, "253-72-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-72/);
    writeFileSync(join(dir, "253-72-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-73-PLAN.md"), `${readFileSync(join(dir, "253-73-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), /253-73|differs/);
    assert.equal(existsSync(join(dir, "253-64-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// Plan 81: additive R5 revision (--revision r5) re-pointing 74-78 and the R4 thirty-three to 79-88
// ---------------------------------------------------------------------------------------------
const R4_CONTRACT_SHA = "2c3351381844664c887e016e3db16ef67674e1877472865c5616409acf060a7c";
const R5_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R5.json";
const R5_NEW_UNSTARTED = ["74", "75", "76", "77", "78"];
const R5_UNSTARTED = [...R4_UNSTARTED, ...R5_NEW_UNSTARTED].sort();
const R5_HALTED = [...R4_HALTED, "73"];
const R5_COMPLETED = [...R4_COMPLETED, "69", "70", "71", "72"].sort();
const R5_NATIVE = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "69", "70", "72", "79", "80", "82", "83", "84"];
const R5_COMPLETION = ["43", "50", "61", "71", "81", "88"];
const R5_OWNERS = {
  "08": ["42", "87"], "13": ["42", "87"], "21": ["42", "87"], "30": ["42", "87"], "34": ["42", "87"], "24": ["87"],
  "10": R5_NATIVE, "17": R5_NATIVE, "28": R5_NATIVE, "29": R5_NATIVE,
  "14": R5_COMPLETION, "25": R5_COMPLETION, "31": R5_COMPLETION, "35": R5_COMPLETION,
  "22": ["85"], "32": ["85"], "23": ["86"], "33": ["86"],
  "41": ["48", "62", "72", "82", "83", "84"], "44": ["85"], "45": ["86"], "46": ["87"], "47": ["50", "61", "71", "81", "88"],
  "52": ["62", "72", "82", "83", "84"], "53": ["85"], "54": ["86"], "55": ["87"], "56": ["71", "81", "88"],
  "64": ["72", "82", "83", "84"], "65": ["85"], "66": ["86"], "67": ["87"], "68": ["71", "81", "88"],
  "74": ["82", "83", "84"], "75": ["85"], "76": ["86"], "77": ["87"], "78": ["81", "88"],
};
const R5_NEVER_RAN_73 = "dependency 253-73 halted on a non-infrastructure runner account-count query defect";
const R5_PLAN_IDS = Array.from({ length: 10 }, (_, i) => String(79 + i));
const R5_FORBIDDEN_OWNERS = ["02", "07", "09", "12", "16", "27", "40", "41", "44", "45", "46", "47", "51", "52", "53", "54", "55", "56", "63", "64", "65", "66", "67", "68", "73", "74", "75", "76", "77", "78"];
// 253-71's receipts name this helper and its test, which plan 81 edits. They are held at the bytes in
// commit 65d670c0c (per plan, because 253-61 names the same paths at different bytes).
const FROZEN_TOOLING_R5_71 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "1bf7dbdc6ff1a46e51ea53763fbe54596361be45eb78a769e72067ccfccc2048",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "410cb744fcb26a946f12b2e18f382a802bc837e6ae8d9e54f214e79a6a197fc6",
};

function r5Fixture() {
  return worldFixture({ maxPlan: 88, maxSummary: 73, label: "r5" });
}

describe("R5 reconciliation contract", () => {
  test("v1, R2, R3 and R4 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5"]);
  });

  test("partitions PLANs 01-78 into 30 completed, 10 halted and 38 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r5" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r5");
    assert.equal(contract.revision, "r5");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R5_COMPLETED);
    assert.equal(contract.completed_plans.length, 30);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R5_HALTED);
    assert.equal(contract.halted_plans.length, 10);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(10).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R5_UNSTARTED);
    assert.equal(contract.responsibilities.length, 38);
    assert.equal(contract.originals.length, 78);
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 78 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "40": ["41", "44", "45", "46", "47"], "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED };
    const reasons = { "40": "dependency 253-40 halted on host sleep", "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
        assert.equal(row.successor_revision, "R5");
      }
    }
    for (const id of R5_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-73"], `${row.plan} blocked_by`);
      assert.equal(row.never_ran_reason, R5_NEVER_RAN_73);
      assert.equal(row.successor_revision, "R5");
    }
    const eight = contract.responsibilities.find((r) => r.plan === "253-08");
    assert.equal(eight.successor_revision, "R5");
    assert.equal(eight.never_ran_reason, undefined);
  });

  test("maps every responsibility to the R5 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r5" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R5_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R5_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["74"], ["load_controls", "load_acceptance"]);
    assert.deepEqual(links["75"], ["publication"]);
    assert.deepEqual(links["76"], ["canary"]);
    assert.deepEqual(links["77"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["78"], LINK_KEYS);
    for (const id of ["14", "47", "56", "68"]) assert.deepEqual(links[id], LINK_KEYS);
    for (const [id, expected] of Object.entries({ "22": ["publication"], "23": ["canary"], "41": ["load_controls", "load_acceptance"], "64": ["load_controls", "load_acceptance"] })) assert.deepEqual(links[id], expected);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R5_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R5_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "85", "86"]);
    assert.deepEqual(contract.halted_proof_map["253-40"], ["253-48", "253-62", "253-72", "253-82", "253-83"]);
    assert.deepEqual(contract.halted_proof_map["253-51"], ["253-57", "253-58", "253-59", "253-60", "253-62", "253-69", "253-70", "253-72", "253-79", "253-80", "253-82", "253-83"]);
    assert.deepEqual(contract.halted_proof_map["253-63"], ["253-69", "253-70", "253-72", "253-79", "253-80", "253-82", "253-83"]);
    assert.deepEqual(contract.halted_proof_map["253-73"], ["253-79", "253-80", "253-82", "253-83"]);
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-88");
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
    assert.match(contract.application.targets, /thirty-eight/);
  });

  test("pins every PLAN 01-88, the existing 36-43, 48-51, 57-63 and 69-73 summaries, the earlier contracts and the SDK", () => {
    const contract = reconcile.buildContract({ revision: "r5" });
    assert.equal(contract.plan_pins.length, 88);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 88 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51", "57", "58", "59", "60", "61", "62", "63", "69", "70", "71", "72", "73"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
  });

  test("tooling receipts are frozen per plan: 253-61 as R4 holds it, 253-71 at commit 65d670c0c", () => {
    const contract = reconcile.buildContract({ revision: "r5" });
    const sixtyOne = contract.completed_plans.find((p) => p.plan === "253-61");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R4)) assert.equal(sixtyOne.receipts.find((r) => r.path === path).sha256, hash, `61 ${path}`);
    const seventyOne = contract.completed_plans.find((p) => p.plan === "253-71");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R5_71)) assert.equal(seventyOne.receipts.find((r) => r.path === path).sha256, hash, `71 ${path}`);
    assert.equal(seventyOne.receipts.find((r) => r.path.endsWith(R4_CONTRACT_NAME)).sha256, R4_CONTRACT_SHA);
    assert.notEqual(sixtyOne.receipts[0].sha256, seventyOne.receipts[0].sha256, "61 and 71 name the same paths at different bytes");
    const seventyThree = contract.halted_plans.find((p) => p.plan === "253-73");
    assert.equal(seventyThree.receipts.length, 2);
    assert.equal(seventyThree.missing_receipts, undefined);
  });

  test("the builder refuses a missing PLAN 79-88 or an owner that is halted or never executed (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-81-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r5" });
    assert.equal(built.plan_pins.length, 88);
    rmSync(join(root, PHASE_DIR_REL, "253-85-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r5" }), /253-85/);
  });

  test("CLI --revision r5 --prepare-contract --check-only matches, drifts fail and nothing is created", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-81-contract-"));
    cleanup.push(dir);
    const target = join(dir, R5_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r5" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r5", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R5 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("253-79 and 253-81 are runnable now and 74-78 stay blocked by halted 253-73", () => {
    const { root } = r5Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of ["253-79", "253-81"]) {
      assert.deepEqual(by[id].blocked_by, [], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.equal(by[id].ready, true, `${id} ready`);
      assert.ok(index.runnable.includes(id), `${id} runnable`);
    }
    for (const id of R5_NEW_UNSTARTED.map((n) => `253-${n}`)) {
      assert.deepEqual(by[id].blocked_by, ["253-73"], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.ok(index.incomplete.includes(id));
    }
    for (const id of ["253-73", "253-63", "253-51"]) assert.equal(by[id].halted, true, id);
    const contract = reconcile.buildContract({ revision: "r5" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.equal(report.route.outcome, "dispatch_plans");
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R5_UNSTARTED);
  });

  test("after simulated R5 dispositions and 79-88 summaries nothing is incomplete and nothing reports blocked", () => {
    const { root, dir } = r5Fixture();
    for (const id of R5_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r5" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier });
    assert.equal(bundle.entries.length, 38);
    for (const entry of bundle.entries) {
      const id = entry.plan.slice(4);
      for (const owner of R5_OWNERS[id]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
      assert.match(entry.content, /status: superseded/);
      assert.match(entry.content, /execution_performed: false/);
      assert.match(entry.content, /original_status: blocked/);
      if (["41", "44", "45", "46", "47"].includes(id)) assert.match(entry.content, /never ran because its dependency 253-40 halted on host sleep\. Its R5 successor/);
      if (R3_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-51 halted on a non-infrastructure native control failure\. Its R5 successor/);
      if (R4_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-63 halted on a non-infrastructure runner validator rejection\. Its R5 successor/);
      if (R5_NEW_UNSTARTED.includes(id)) assert.match(entry.content, /never ran because its dependency 253-73 halted on a non-infrastructure runner account-count query defect\. Its R5 successor/);
    }
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 38);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R5_HALTED);
    assert.equal(index.plans.filter((p) => p.halted).length, 10);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 88);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R5_NEW_UNSTARTED, ...R4_NEW_UNSTARTED, ...R3_NEW_UNSTARTED, "41", "47"]) {
      const row = rows.find((r) => r.id === `253-${id}`);
      assert.equal(row.summary_status, "superseded");
      assert.equal(row.execution_performed, false);
      assert.equal(row.original_status, "blocked");
    }
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.equal(report.halted_literal, true);
    assert.equal(report.route.outcome, "resume_phase_gates");
  });

  test("a status: blocked owner summary, or a rewritten pinned plan, is refused", () => {
    const { root, dir } = r5Fixture();
    for (const id of R5_PLAN_IDS) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r5" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = completionFixture(root);
    writeFileSync(join(dir, "253-83-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), completionPath: completion, verifier: acceptedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-83/);
    writeFileSync(join(dir, "253-83-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-83-PLAN.md"), `${readFileSync(join(dir, "253-83-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: acceptedVerifier }), /253-83|differs/);
    assert.equal(existsSync(join(dir, "253-74-SUMMARY.md")), false);
  });
});
