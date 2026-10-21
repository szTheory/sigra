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
    assert.throws(() => reconcile.buildContract({ revision: "r13" }), /revision/);
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
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
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
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
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
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
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
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
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

// ---------------------------------------------------------------------------------------------
// 253-90: R6 revision (253-84 halted on its insufficient-proof branch, so 85-88 can never run)
// ---------------------------------------------------------------------------------------------
const R5_CONTRACT_SHA = "f92fefe3f028de90112c9693ab5f1d7d769ab4087493f0fedbb39a46f7af1601";
const R6_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R6.json";
const R6_NEW_UNSTARTED = ["85", "86", "87", "88"];
const R6_UNSTARTED = [...R5_UNSTARTED, ...R6_NEW_UNSTARTED].sort();
const R6_HALTED = [...R5_HALTED, "84"];
const R6_COMPLETED = [...R5_COMPLETED, "79", "80", "81", "82", "83"].sort();
const R6_NATIVE = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "69", "70", "72", "79", "80", "82", "83", "89"];
const R6_COMPLETION = ["43", "50", "61", "71", "81", "90", "94"];
const R6_OWNERS = {
  "08": ["42", "93"], "13": ["42", "93"], "21": ["42", "93"], "30": ["42", "93"], "34": ["42", "93"], "24": ["93"],
  "10": R6_NATIVE, "17": R6_NATIVE, "28": R6_NATIVE, "29": R6_NATIVE,
  "14": R6_COMPLETION, "25": R6_COMPLETION, "31": R6_COMPLETION, "35": R6_COMPLETION,
  "22": ["91"], "32": ["91"], "23": ["92"], "33": ["92"],
  "41": ["48", "62", "72", "82", "83", "89"], "44": ["91"], "45": ["92"], "46": ["93"], "47": ["50", "61", "71", "81", "90", "94"],
  "52": ["62", "72", "82", "83", "89"], "53": ["91"], "54": ["92"], "55": ["93"], "56": ["71", "81", "90", "94"],
  "64": ["72", "82", "83", "89"], "65": ["91"], "66": ["92"], "67": ["93"], "68": ["71", "81", "90", "94"],
  "74": ["82", "83", "89"], "75": ["91"], "76": ["92"], "77": ["93"], "78": ["81", "90", "94"],
  "85": ["91"], "86": ["92"], "87": ["93"], "88": ["90", "94"],
};
const R6_NEVER_RAN_84 = "dependency 253-84 halted on its insufficient-proof branch: no source-bound historical registration cause";
const R6_PLAN_IDS = ["89", "90", "91", "92", "93", "94"];
const R6_FORBIDDEN_OWNERS = [...R5_FORBIDDEN_OWNERS, "84", "85", "86", "87", "88"];
const R6_DISPOSITION_GAP = "disposition:CIREL-01:not_reproduced (Jon-approved disposition; target neither reproduced nor fixed)";
// 253-81's receipts name this helper and its test, which plan 90 edits. They are held at the bytes of
// the 253-81 Task 1 GREEN commit 4bb3f303a.
const FROZEN_TOOLING_R6_81 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "9f1ff7f7e1ca455d722a725a3608aa7907c7b36aa4745fe623a1ee807a4b8a83",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "dcae48ec9f39b87f8448363ccfaca01443fc3be33ff7d54939dad09d56030c6f",
};

function r6Fixture() {
  return worldFixture({ maxPlan: 94, maxSummary: 89, label: "r6" });
}

const dispositionedVerifier = () => ({ exit: 0, stderr: "", stdout: JSON.stringify({
  status: "dispositioned", gaps: [R6_DISPOSITION_GAP], linked: [...LINK_KEYS].sort(), phase_verification: "not_started", dispositioned: true,
  requirements: { "CIREL-01": "partial_not_reproduced", "CIREL-02": "accepted" }, limitations: [] }) });

function dispositionCompletionFixture(root) {
  const path = completionFixture(root);
  const evidence = JSON.parse(readFileSync(path, "utf8"));
  for (const key of ["load_target_disposition", "load_target_disposition_approval"]) {
    const body = JSON.stringify({ fixture_only: true, key });
    writeFileSync(join(root, "proofs", `${key}.json`), body);
    evidence.links[key] = { path: `proofs/${key}.json`, sha256: sha(body) };
  }
  writeFileSync(path, JSON.stringify(evidence));
  return path;
}

describe("R6 reconciliation contract", () => {
  test("v1, R2, R3, R4 and R5 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
  });

  test("partitions PLANs 01-88 into 35 completed, 11 halted and 42 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r6" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r6");
    assert.equal(contract.revision, "r6");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R6_COMPLETED);
    assert.equal(contract.completed_plans.length, 35);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R6_HALTED);
    assert.equal(contract.halted_plans.length, 11);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(11).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R6_UNSTARTED);
    assert.equal(contract.responsibilities.length, 42);
    assert.equal(contract.originals.length, 88);
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 88 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "40": ["41", "44", "45", "46", "47"], "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED };
    const reasons = { "40": "dependency 253-40 halted on host sleep", "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
        assert.equal(row.successor_revision, "R6");
      }
    }
    const eight = contract.responsibilities.find((r) => r.plan === "253-08");
    assert.equal(eight.successor_revision, "R6");
    assert.equal(eight.never_ran_reason, undefined);
  });

  test("maps every responsibility to the R6 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r6" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R6_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R6_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["85"], ["publication"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(links["87"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["88"], [...LINK_KEYS, "load_target_disposition"]);
    for (const id of ["14", "47", "56", "68", "78"]) assert.deepEqual(links[id], LINK_KEYS);
    assert.deepEqual(links["74"], ["load_controls", "load_acceptance"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R6_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R6_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "92"]);
    assert.deepEqual(contract.halted_proof_map["253-73"], ["253-79", "253-80", "253-82", "253-83"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-94");
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.match(contract.application.targets, /forty-two/);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
  });

  test("pins every PLAN 01-94, the existing 36-43, 48-51, 57-63, 69-73, 79-84 and 89 summaries, the earlier contracts and the SDK", () => {
    const contract = reconcile.buildContract({ revision: "r6" });
    assert.equal(contract.plan_pins.length, 94);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 94 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51", "57", "58", "59", "60", "61", "62", "63", "69", "70", "71", "72", "73", "79", "80", "81", "82", "83", "84", "89"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
  });

  test("tooling receipts are frozen per plan: 253-61 as R4 holds it, 253-71 as R5 holds it, 253-81 at commit 4bb3f303a", () => {
    const contract = reconcile.buildContract({ revision: "r6" });
    const sixtyOne = contract.completed_plans.find((p) => p.plan === "253-61");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R4)) assert.equal(sixtyOne.receipts.find((r) => r.path === path).sha256, hash, `61 ${path}`);
    const seventyOne = contract.completed_plans.find((p) => p.plan === "253-71");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R5_71)) assert.equal(seventyOne.receipts.find((r) => r.path === path).sha256, hash, `71 ${path}`);
    const eightyOne = contract.completed_plans.find((p) => p.plan === "253-81");
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R6_81)) assert.equal(eightyOne.receipts.find((r) => r.path === path).sha256, hash, `81 ${path}`);
    assert.equal(eightyOne.receipts.find((r) => r.path.endsWith(R5_CONTRACT_NAME)).sha256, R5_CONTRACT_SHA);
    assert.notEqual(eightyOne.receipts.find((r) => r.path.endsWith("reconcile.mjs")).sha256, seventyOne.receipts.find((r) => r.path.endsWith("reconcile.mjs")).sha256);
    const eightyFour = contract.halted_plans.find((p) => p.plan === "253-84");
    assert.equal(eightyFour.receipts.length, 1);
    assert.equal(eightyFour.missing_receipts, undefined);
  });

  test("the builder refuses a missing PLAN 89-94 or an owner that is halted or never executed (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-90-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r6" });
    assert.equal(built.plan_pins.length, 94);
    rmSync(join(root, PHASE_DIR_REL, "253-92-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r6" }), /253-92/);
  });

  test("CLI --revision r6 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r5 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-90-contract-"));
    cleanup.push(dir);
    const target = join(dir, R6_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r6" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r6", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R6 dispositioned completion gating", () => {
  test("r6 calls the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    const argv = reconcile.completionArgv("r6", "/x/completion.json");
    assert.ok(argv.includes("--require-dispositioned"));
    assert.ok(!argv.includes("--require-accepted"));
    assert.deepEqual(argv.slice(argv.indexOf("--mode"), argv.indexOf("--mode") + 2), ["--mode", "completion"]);
    assert.equal(argv[argv.indexOf("--evidence") + 1], "/x/completion.json");
  });

  test("the r6 predicate accepts only the dispositioned shape and the earlier predicate rejects it", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    const r6 = reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r6" });
    assert.equal(r6.accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r5" }).accepted, false);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier }).accepted, false);
    const mutate = (change) => () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); change(body); return { ...out, stdout: JSON.stringify(body) }; };
    for (const [label, change] of [
      ["accepted CIREL-01", (b) => { b.requirements["CIREL-01"] = "accepted"; }],
      ["open CIREL-02", (b) => { b.requirements["CIREL-02"] = "open"; }],
      ["status accepted with the gap", (b) => { b.status = "accepted"; }],
      ["no disposition gap", (b) => { b.gaps = []; }],
      ["extra gap", (b) => { b.gaps.push("missing:canary:x"); }],
      ["not dispositioned flag", (b) => { b.dispositioned = false; }],
      ["short linked list", (b) => { b.linked = b.linked.slice(1); }],
      ["phase verification started", (b) => { b.phase_verification = "passed"; }],
    ]) {
      assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutate(change), revision: "r6" }).accepted, false, label);
    }
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r6" }).accepted, false, "strict accepted shape is not the r6 disposition shape");
  });

  test("the R6 disposition text says CIREL-02 is accepted and CIREL-01 partial, never both accepted", () => {
    const { root } = r6Fixture();
    const contract = reconcile.buildContract({ revision: "r6" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 42);
    const r5Contract = reconcile.buildContract({ revision: "r5" });
    assert.ok(r5Contract.responsibilities.length > 0);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
      assert.match(entry.content, /execution_performed: false/);
    }
    const eightyEight = bundle.entries.find((e) => e.plan === "253-88");
    assert.match(eightyEight.content, /link: load_target_disposition/);
    assert.match(eightyEight.content, /never ran because its dependency 253-84 halted on its insufficient-proof branch/);
    assert.match(eightyEight.content, /Its R6 successor is 253-90, 253-94/);
  });
});

describe("R6 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("85-88 stay blocked by halted 253-84; the installed SDK also inherits that block onto 89-94 through 253-89's depends_on", () => {
    const { root } = r6Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    // Measured against the installed SDK 1.16.0: 253-89 depends on halted 253-84, and blocked_by propagates through it
    // (even though 89 has its own SUMMARY), so 90-94 report blocked_by [253-84] and are never `runnable`. They must be
    // dispatched explicitly; once summarized they stop being incomplete (see the post-disposition test).
    for (const id of R6_PLAN_IDS.slice(1).map((n) => `253-${n}`)) {
      assert.deepEqual(by[id].blocked_by, ["253-84"], `${id} inherits the 253-84 block`);
      assert.equal(by[id].has_summary, false, id);
      assert.equal(by[id].ready, false, id);
    }
    assert.deepEqual(by["253-89"].blocked_by, ["253-84"]);
    assert.equal(by["253-89"].has_summary, true);
    assert.deepEqual(index.runnable, []);
    for (const id of R6_NEW_UNSTARTED.map((n) => `253-${n}`)) {
      assert.deepEqual(by[id].blocked_by, ["253-84"], `${id} blocked_by`);
      assert.equal(by[id].has_summary, false);
      assert.ok(index.incomplete.includes(id));
    }
    for (const id of ["253-84", "253-73", "253-63", "253-51"]) assert.equal(by[id].halted, true, id);
    const contract = reconcile.buildContract({ revision: "r6" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.equal(report.route.outcome, "phase_stuck");
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R6_UNSTARTED);
  });

  test("after simulated R6 dispositions and 90-94 summaries nothing is incomplete and nothing reports blocked", () => {
    const { root, dir } = r6Fixture();
    for (const id of ["90", "91", "92", "93", "94"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r6" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 42);
    for (const entry of bundle.entries) for (const owner of R6_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 42);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R6_HALTED);
    assert.equal(index.plans.filter((p) => p.halted).length, 11);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 94);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R6_NEW_UNSTARTED, ...R5_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r6Fixture();
    for (const id of ["90", "91", "92", "93", "94"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r6" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-93-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-93/);
    writeFileSync(join(dir, "253-93-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-92-PLAN.md"), `${readFileSync(join(dir, "253-92-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-92|differs/);
    assert.equal(existsSync(join(dir, "253-85-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-96: R7 revision (253-92 halted at publication on the publisher's commit-message readback, so
// 253-93 and 253-94 can never run). Task 1: partition, dispositioned gating and CLI.
// ---------------------------------------------------------------------------------------------
const R6_CONTRACT_SHA = "4e7c33fe072e344f9b0c2f39065af50e99f7208c7c50afff788df564f3078f63";
const R7_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R7.json";
const R7_NEW_UNSTARTED = ["93", "94"];
const R7_UNSTARTED = [...R6_UNSTARTED, ...R7_NEW_UNSTARTED].sort();
const R7_HALTED = [...R6_HALTED, "92"];
const R7_COMPLETED = [...R6_COMPLETED, "89", "90", "91"].sort();
const R7_NEVER_RAN_92 = "dependency 253-92 halted at publication: the publisher's candidate commit readback compared a newline-terminated message with GitHub's stripped message";
const R7_FORBIDDEN_OWNERS = [...R6_FORBIDDEN_OWNERS, "92", "93", "94"];

describe("R7 revision skeleton: partition, dispositioned gating and CLI", () => {
  test("R7 sets partition PLANs 01-94 into 38 completed, 12 halted and 44 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R7], R7_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R7], R7_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R7], R7_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R7], R7_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R7.length, 38);
    assert.equal(reconcile.HALTED_IDS_R7.length, 12);
    assert.equal(reconcile.UNSTARTED_IDS_R7.length, 44);
    const all = [...reconcile.COMPLETED_IDS_R7, ...reconcile.HALTED_IDS_R7, ...reconcile.UNSTARTED_IDS_R7].sort();
    assert.deepEqual(all, Array.from({ length: 94 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(reconcile.NEVER_RAN_REASON_R7, R7_NEVER_RAN_92);
    assert.equal(reconcile.CONTRACT_NAME_R7, R7_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R7, "sigra.phase253.load-recovery-reconciliation-contract/r7");
  });

  test("r6 and r7 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r7 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r7" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r7" }).accepted, false);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r5" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r7" }).accepted, false);
  });

  test("CLI --revision r7 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-96-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R7_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r7", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r7");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R7);
    assert.equal(contract.responsibilities.length, 44);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("93 and 94 are never-ran rows blocked by halted 253-92; every row carries the R7 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r7" });
    for (const id of R7_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-92"], id);
      assert.equal(row.never_ran_reason, R7_NEVER_RAN_92, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R7_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R7", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-96 Task 2: R7 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R7_REMAP = { "91": ["91", "95"], "92": ["97"], "93": ["98"], "94": ["96", "99"] };
const remapR7 = (owners) => owners.flatMap((owner) => R7_REMAP[owner] ?? [owner]);
const R7_OWNERS = {
  ...Object.fromEntries(Object.entries(R6_OWNERS).map(([id, owners]) => [id, remapR7(owners)])),
  "93": ["98"],
  "94": ["96", "99"],
};
const R7_NATIVE = R6_NATIVE;
const R7_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "99"];
const R7_PLAN_IDS = ["95", "96", "97", "98", "99"];
// 253-90's receipts name this helper and its test, which plan 96 edits. They are held at the bytes of the
// last 253-90 commit that touched each file (6eb2fbbad), read with git, never invented.
const FROZEN_TOOLING_R7_90 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "1f2f600eb383215400ddae459c23ae22602f36defe97db5f3b25ba86962769e3",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "bf652d4e7ceb3919aeda75438841bdabe8ae424bdf2ba72eb5c865a057af385a",
};

function r7Fixture() {
  return worldFixture({ maxPlan: 99, maxSummary: 95, label: "r7" });
}

describe("R7 reconciliation contract", () => {
  test("v1, R2-R6 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
  });

  test("partitions PLANs 01-94 into 38 completed, 12 halted and 44 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r7" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r7");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R7_COMPLETED);
    assert.equal(contract.completed_plans.length, 38);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R7_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(12).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R7_UNSTARTED);
    assert.equal(contract.responsibilities.length, 44);
    assert.equal(contract.originals.length, 94);
    assert.deepEqual(contract.originals.map((o) => o.class).filter((c) => c === "halted").length, 12);
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 94 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "40": ["41", "44", "45", "46", "47"], "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED };
    const reasons = { "40": "dependency 253-40 halted on host sleep", "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
        assert.equal(row.successor_revision, "R7");
      }
    }
  });

  test("maps every responsibility to the R7 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r7" });
    assert.deepEqual(Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))])), R7_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R7_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners["10"], R7_NATIVE);
    assert.deepEqual(owners["14"], R7_COMPLETION);
    assert.deepEqual(owners["85"], ["91", "95"]);
    assert.deepEqual(owners["86"], ["97"]);
    assert.deepEqual(owners["87"], ["98"]);
    assert.deepEqual(owners["88"], ["90", "96", "99"]);
    assert.deepEqual(owners["93"], ["98"]);
    assert.deepEqual(owners["94"], ["96", "99"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["93"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["94"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["88"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R7_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R7_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "97"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-97"]);
    for (const owners of Object.values(contract.halted_proof_map)) for (const owner of owners) assert.ok(!R7_FORBIDDEN_OWNERS.includes(owner.slice(4)), `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
  });

  test("pins every PLAN 01-99, the existing summaries through 92 and 95, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r7" });
    assert.equal(contract.revision, "r7");
    assert.equal(contract.plan_pins.length, 99);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan.slice(4)), Array.from({ length: 99 }, (_, i) => String(i + 1).padStart(2, "0")));
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51", "57", "58", "59", "60", "61", "62", "63", "69", "70", "71", "72", "73", "79", "80", "81", "82", "83", "84", "89", "90", "91", "92", "95"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.deepEqual(contract.r6_contract, { path: `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`, sha256: R6_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-99");
    assert.equal(contract.application.targets, "only the forty-four previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
    assert.ok(contract.application.never.includes("writing status: blocked"));
  });

  test("tooling receipts are frozen per plan: 253-61, 71 and 81 as earlier revisions hold them, 253-90 at its last commit", () => {
    const contract = reconcile.buildContract({ revision: "r7" });
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R4)) assert.equal(receipt("253-61", path), hash, `61 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R5_71)) assert.equal(receipt("253-71", path), hash, `71 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R6_81)) assert.equal(receipt("253-81", path), hash, `81 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R7_90)) {
      assert.equal(receipt("253-90", path), hash, `90 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `6eb2fbbad:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `90 ${path} equals the blob at commit 6eb2fbbad`);
    }
    assert.equal(receipt("253-90", `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`), R6_CONTRACT_SHA);
    const ninetyTwo = contract.halted_plans.find((p) => p.plan === "253-92");
    assert.equal(ninetyTwo.receipts.length, 5);
    assert.equal(ninetyTwo.missing_receipts, undefined);
    assert.equal(ninetyTwo.summary.status, "halted");
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 95-99 or an owner that is halted or never executed (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-96-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r7" });
    assert.equal(built.plan_pins.length, 99);
    rmSync(join(root, PHASE_DIR_REL, "253-97-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r7" }), /253-97/);
  });

  test("CLI --revision r7 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r6 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-96-contract-"));
    cleanup.push(dir);
    const target = join(dir, R7_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r7" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r7", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R7 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R7 successors", () => {
    const { root } = r7Fixture();
    const contract = reconcile.buildContract({ revision: "r7" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 44);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /status: superseded/);
      assert.match(entry.content, /execution_performed: false/);
      assert.match(entry.content, /original_status: blocked/);
      assert.match(entry.content, /phase_verification_status: not_started/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
    }
    const ninetyThree = bundle.entries.find((e) => e.plan === "253-93");
    assert.match(ninetyThree.content, /never ran because its dependency 253-92 halted at publication/);
    assert.match(ninetyThree.content, /Its R7 successor is 253-98\./);
    const ninetyFour = bundle.entries.find((e) => e.plan === "253-94");
    assert.match(ninetyFour.content, /Its R7 successor is 253-96, 253-99\./);
    assert.match(ninetyFour.content, /link: load_target_disposition/);
  });
});

describe("R7 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("93 and 94 stay incomplete and blocked behind halted 253-92; 253-96 is the next explicitly dispatchable plan", () => {
    const { root } = r7Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of ["253-93", "253-94"]) {
      assert.ok(index.incomplete.includes(id), `${id} incomplete`);
      assert.equal(by[id].has_summary, false, id);
      assert.ok(by[id].blocked_by.includes("253-92"), `${id} blocked behind 253-92`);
    }
    assert.equal(by["253-92"].halted, true);
    assert.equal(by["253-95"].has_summary, true);
    assert.equal(by["253-96"].has_summary, false);
    // Measured against the installed SDK 1.16.0 (as for R6): blocked_by propagates through depends_on even past
    // summarized plans, so 95-99 inherit [253-84, 253-92] and `runnable` is empty. 253-96 is still the next plan with
    // no summary whose own dependencies (95 and 90) are summarized; it is dispatched explicitly, not by `runnable`.
    for (const id of ["253-96", "253-97", "253-98", "253-99"]) {
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-84", "253-92"], `${id} inherits both blocks`);
      assert.equal(by[id].halted, false, id);
    }
    assert.deepEqual(index.runnable, []);
    assert.equal(by["253-96"].has_summary, false);
    const contract = reconcile.buildContract({ revision: "r7" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R7_UNSTARTED);
  });

  test("after simulated R7 dispositions and 96-99 summaries nothing is incomplete, twelve plans are halted and nothing reports blocked", () => {
    const { root, dir } = r7Fixture();
    for (const id of ["96", "97", "98", "99"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r7" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 44);
    for (const entry of bundle.entries) for (const owner of R7_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 44);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R7_HALTED);
    assert.equal(index.plans.filter((p) => p.halted).length, 12);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 99);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R7_NEW_UNSTARTED, ...R6_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r7Fixture();
    for (const id of ["96", "97", "98", "99"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r7" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-98-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-98/);
    writeFileSync(join(dir, "253-98-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-97-PLAN.md"), `${readFileSync(join(dir, "253-97-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-97|differs/);
    assert.equal(existsSync(join(dir, "253-93-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-103: R8 revision (253-97 halted at the full-pass preflight on the canary driver's unbraced
// route capture, so 253-98 and 253-99 can never run). Task 1: partition, dispositioned gating, CLI
// and three-digit plan IDs.
// ---------------------------------------------------------------------------------------------
const R7_CONTRACT_SHA = "8b077547940cf3ef953aaf5c539366e8cf506215a3502357f982ce45f2389df7";
const R8_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R8.json";
const R8_NEW_UNSTARTED = ["98", "99"];
const R8_UNSTARTED = [...R7_UNSTARTED, ...R8_NEW_UNSTARTED].sort();
const R8_HALTED = [...R7_HALTED, "97"];
const R8_COMPLETED = [...R7_COMPLETED, "95", "96"].sort();
const R8_NEVER_RAN_97 = "dependency 253-97 halted at the full-pass preflight: the canary driver passed the whole regex match plus a literal [1] suffix as the check_runs commit_sha route parameter, which the transport refused";
const R8_FORBIDDEN_OWNERS = [...R7_FORBIDDEN_OWNERS, "97", "98", "99"];

describe("R8 revision skeleton: partition, dispositioned gating, CLI and three-digit plan IDs", () => {
  test("R8 sets partition PLANs 01-99 into 40 completed, 13 halted and 46 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R8], R8_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R8], R8_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R8], R8_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R8], R8_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R8.length, 40);
    assert.equal(reconcile.HALTED_IDS_R8.length, 13);
    assert.equal(reconcile.UNSTARTED_IDS_R8.length, 46);
    const all = [...reconcile.COMPLETED_IDS_R8, ...reconcile.HALTED_IDS_R8, ...reconcile.UNSTARTED_IDS_R8].sort();
    assert.deepEqual(all, Array.from({ length: 99 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(reconcile.NEVER_RAN_REASON_R8, R8_NEVER_RAN_97);
    assert.equal(reconcile.CONTRACT_NAME_R8, R8_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R8, "sigra.phase253.load-recovery-reconciliation-contract/r8");
    assert.equal(reconcile.contractPathFor("r8"), join(HERE, R8_CONTRACT_NAME));
    assert.equal(reconcile.contractPathFor("r7"), join(HERE, R7_CONTRACT_NAME));
  });

  test("r6, r7 and r8 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7", "r8"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r8 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r8" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r8" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r8" }).accepted, false);
  });

  test("three-digit plan IDs build, sort and match: 253-99, 253-100 and 253-106", () => {
    assert.equal(reconcile.planIdOf(99), "253-99");
    assert.equal(reconcile.planIdOf(100), "253-100");
    assert.equal(reconcile.planIdOf(106), "253-106");
    assert.equal(reconcile.planIdOf(7), "253-07");
    assert.deepEqual(["253-106", "253-100", "253-99", "253-07"].sort(reconcile.comparePlanIds), ["253-07", "253-99", "253-100", "253-106"]);
    assert.deepEqual([{ plan: "253-100" }, { plan: "253-99" }].sort((a, b) => reconcile.comparePlanIds(a.plan, b.plan)).map((p) => p.plan), ["253-99", "253-100"]);
    assert.deepEqual(reconcile.parsePlanFile("253-99-PLAN.md"), { id: "99", number: 99, kind: "PLAN" });
    assert.deepEqual(reconcile.parsePlanFile("253-100-SUMMARY.md"), { id: "100", number: 100, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-106-PLAN.md"), { id: "106", number: 106, kind: "PLAN" });
    assert.equal(reconcile.parsePlanFile("253-1060-PLAN.md"), null);
    assert.equal(reconcile.parsePlanFile("253-LOAD-RECOVERY-reconcile.mjs"), null);
  });

  test("CLI --revision r8 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-103-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R8_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r8", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r8");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R8);
    assert.equal(contract.responsibilities.length, 46);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("98 and 99 are never-ran rows blocked by halted 253-97; earlier rows keep their reasons; every row carries the R8 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r8" });
    for (const id of R8_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-97"], id);
      assert.equal(row.never_ran_reason, R8_NEVER_RAN_97, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R8_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R8", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-93").never_ran_reason, R7_NEVER_RAN_92);
    assert.deepEqual(contract.responsibilities.find((r) => r.plan === "253-94").blocked_by, ["253-92"]);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-103 Task 2: R8 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R8_REMAP = { "95": ["95", "102"], "96": ["96", "103"], "97": ["104"], "98": ["105"], "99": ["103", "106"] };
const remapR8 = (owners) => [...new Set(owners.flatMap((owner) => R8_REMAP[owner] ?? [owner]))];
const R8_OWNERS = {
  ...Object.fromEntries(Object.entries(R7_OWNERS).map(([id, owners]) => [id, remapR8(owners)])),
  "98": ["105"],
  "99": ["103", "106"],
};
const R8_NATIVE = R7_NATIVE;
const R8_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "103", "106"];
const R8_PLAN_IDS = ["100", "101", "102", "103", "104", "105", "106"];
// 253-96's receipts name this helper and its test, which plan 103 edits. They are held at the bytes of the
// last 253-96 commit that touched each file (a6ccee580), read with git, never invented.
const FROZEN_TOOLING_R8_96 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "6f64c8811e6a56460eb67cc4c55226cbc7d8db9bf9979374514311e9d8710911",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "dec1661dda1fc31693e8e31b218dbed24f5f6a3f0823dc2409bab89a5b27b1d0",
};
const R7_SUMMARY_PIN_IDS = ["36", "37", "38", "39", "40", "42", "43", "48", "49", "50", "51", "57", "58", "59", "60", "61", "62", "63", "69", "70", "71", "72", "73", "79", "80", "81", "82", "83", "84", "89", "90", "91", "92", "95"];

// The R8 world has three-digit plan ids (253-100..106), which worldFixture's two-digit match skips by design
// (so r2-r7 fixtures cannot drift). This copy uses the helper's own three-digit matcher.
function r8Fixture({ maxPlan = 106, maxSummary = 102 } = {}) {
  const root = mkdtempSync(join(tmpdir(), "p253-r8-"));
  cleanup.push(root);
  const dir = join(root, PHASE_DIR_REL);
  mkdirSync(dir, { recursive: true });
  git(root, "init", "-q");
  git(root, "config", "user.email", "t@example.invalid");
  git(root, "config", "user.name", "fixture");
  writeFileSync(join(root, ".planning", "ROADMAP.md"), `# Roadmap\n### Phase 253: Demo\n**Goal**: x\n**Requirements**: CIREL-01, CIREL-02\n**Plans:** ${maxPlan} plans\n`);
  writeFileSync(join(root, ".planning", "STATE.md"), "---\ngsd_state_version: 1.0\nmilestone: v1\nstatus: executing\n---\n# State\n");
  writeFileSync(join(root, ".planning", "config.json"), '{"mode":"yolo"}\n');
  let copiedPlans = 0;
  for (const name of readdirSync(REAL_PHASE_DIR)) {
    const parsed = reconcile.parsePlanFile(name);
    if (!parsed) continue;
    if (parsed.number > maxPlan) continue;
    if (parsed.kind === "SUMMARY" && parsed.number > maxSummary) continue;
    copyFileSync(join(REAL_PHASE_DIR, name), join(dir, name));
    if (parsed.kind === "PLAN") copiedPlans += 1;
  }
  assert.equal(copiedPlans, maxPlan, "every PLAN 01..maxPlan copied, including three-digit ids");
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", "fixture");
  return { root, dir };
}

describe("R8 reconciliation contract", () => {
  test("v1 and R2-R7 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"], [R7_CONTRACT_NAME, R7_CONTRACT_SHA, "r7"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
  });

  test("partitions PLANs 01-99 into 40 completed, 13 halted and 46 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r8" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r8");
    assert.equal(contract.revision, "r8");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R8_COMPLETED);
    assert.equal(contract.completed_plans.length, 40);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R8_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(13).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R8_UNSTARTED);
    assert.equal(contract.responsibilities.length, 46);
    assert.equal(contract.originals.length, 99);
    assert.equal(contract.originals.filter((o) => o.class === "halted").length, 13);
    assert.equal(contract.originals.find((o) => o.plan === "253-97").class, "halted");
    assert.equal(contract.originals.find((o) => o.plan === "253-96").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-99").class, "unstarted_blocked");
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort();
    assert.deepEqual(all, Array.from({ length: 99 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "40": ["41", "44", "45", "46", "47"], "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED, "97": R8_NEW_UNSTARTED };
    const reasons = { "40": "dependency 253-40 halted on host sleep", "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92, "97": R8_NEVER_RAN_97 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
        assert.equal(row.successor_revision, "R8");
      }
    }
  });

  test("maps every responsibility to the R8 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r8" });
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners, R8_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R8_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    for (const row of Object.values(owners)) assert.equal(new Set(row).size, row.length, "no duplicate owners after the remap");
    assert.deepEqual(owners["10"], R8_NATIVE);
    assert.deepEqual(owners["14"], R8_COMPLETION);
    assert.deepEqual(owners["08"], ["42", "105"]);
    assert.deepEqual(owners["22"], ["91", "95", "102"]);
    assert.deepEqual(owners["85"], ["91", "95", "102"]);
    assert.deepEqual(owners["86"], ["104"]);
    assert.deepEqual(owners["87"], ["105"]);
    assert.deepEqual(owners["88"], ["90", "96", "103", "106"]);
    assert.deepEqual(owners["93"], ["105"]);
    assert.deepEqual(owners["94"], ["96", "103", "106"]);
    assert.deepEqual(owners["98"], ["105"]);
    assert.deepEqual(owners["99"], ["103", "106"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["98"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["99"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["94"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R8_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R8_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "102", "104"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-102", "253-104"]);
    assert.deepEqual(contract.halted_proof_map["253-97"], ["253-100", "253-101", "253-102", "253-104"]);
    for (const list of Object.values(contract.halted_proof_map)) for (const owner of list) assert.ok(!R8_FORBIDDEN_OWNERS.includes(owner.slice(4)), `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
  });

  test("pins every PLAN 01-106 in numeric order, the existing summaries, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r8" });
    assert.equal(contract.plan_pins.length, 106);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan), Array.from({ length: 106 }, (_, i) => reconcile.planIdOf(i + 1)));
    assert.deepEqual(contract.plan_pins.slice(-7).map((p) => p.plan.slice(4)), R8_PLAN_IDS);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), [...R7_SUMMARY_PIN_IDS, "96", "97", "100", "101", "102"]);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.deepEqual(contract.r6_contract, { path: `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`, sha256: R6_CONTRACT_SHA });
    assert.deepEqual(contract.r7_contract, { path: `${PHASE_DIR_REL}/${R7_CONTRACT_NAME}`, sha256: R7_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    const r7 = reconcile.buildContract({ revision: "r7" });
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-106");
    assert.equal(contract.application.targets, "only the forty-six previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.equal(contract.application.then_run, r7.application.then_run);
    assert.deepEqual(contract.application.never, r7.application.never);
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
  });

  test("tooling receipts are frozen per plan: 253-61, 71, 81 and 90 as R7 holds them, 253-96 at its last commit", () => {
    const contract = reconcile.buildContract({ revision: "r8" });
    const r7 = reconcile.buildContract({ revision: "r7" });
    for (const plan of r7.completed_plans) assert.deepEqual(contract.completed_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R7 holds it`);
    for (const plan of r7.halted_plans) assert.deepEqual(contract.halted_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R7 holds it`);
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R7_90)) assert.equal(receipt("253-90", path), hash, `90 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R6_81)) assert.equal(receipt("253-81", path), hash, `81 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R8_96)) {
      assert.equal(receipt("253-96", path), hash, `96 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `a6ccee580:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `96 ${path} equals the blob at commit a6ccee580`);
      const log = spawnSync("git", ["-C", REPO, "log", "-1", "--format=%h", "--grep=(253-96)", "--", path], { encoding: "utf8" });
      assert.equal(log.stdout.trim().slice(0, 9), "a6ccee580", `a6ccee580 is the last 253-96 commit touching ${path}`);
      assert.notEqual(sha(readFileSync(join(REPO, path))), hash, `${path} has since been edited by plan 103 (the freeze is load-bearing)`);
    }
    assert.equal(receipt("253-96", `${PHASE_DIR_REL}/${R7_CONTRACT_NAME}`), R7_CONTRACT_SHA);
    const ninetySeven = contract.halted_plans.find((p) => p.plan === "253-97");
    assert.equal(ninetySeven.receipts.length, 5);
    assert.equal(ninetySeven.missing_receipts, undefined);
    assert.equal(ninetySeven.summary.status, "halted");
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 100-106 (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-103-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r8" });
    assert.equal(built.plan_pins.length, 106);
    rmSync(join(root, PHASE_DIR_REL, "253-104-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r8" }), /253-104/);
    git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-104-PLAN.md`);
    assert.equal(reconcile.buildContract({ repoRoot: root, revision: "r8" }).plan_pins.length, 106);
    rmSync(join(root, PHASE_DIR_REL, "253-106-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r8" }), /253-106/);
  });

  test("CLI --revision r8 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r7 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-103-contract-"));
    cleanup.push(dir);
    const target = join(dir, R8_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r8" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r8", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME], ["r7", R7_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R8 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R8 successors", () => {
    const { root } = r8Fixture();
    const contract = reconcile.buildContract({ revision: "r8" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 46);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /\nstatus: superseded\n/);
      assert.match(entry.content, /\nexecution_performed: false\n/);
      assert.match(entry.content, /\noriginal_status: blocked\n/);
      assert.match(entry.content, /\nphase_verification_status: not_started\n/);
      assert.doesNotMatch(entry.content, /\nstatus: blocked\n/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
    }
    const ninetyEight = bundle.entries.find((e) => e.plan === "253-98");
    assert.match(ninetyEight.content, /never ran because its dependency 253-97 halted at the full-pass preflight/);
    assert.match(ninetyEight.content, /Its R8 successor is 253-105\./);
    assert.match(ninetyEight.content, /original_blocked_by: \["253-97"\]/);
    const ninetyNine = bundle.entries.find((e) => e.plan === "253-99");
    assert.match(ninetyNine.content, /Its R8 successor is 253-103, 253-106\./);
    assert.match(ninetyNine.content, /link: load_target_disposition/);
    const ninetyThree = bundle.entries.find((e) => e.plan === "253-93");
    assert.match(ninetyThree.content, /never ran because its dependency 253-92 halted at publication/);
    assert.match(ninetyThree.content, /Its R8 successor is 253-105\./);
  });
});

describe("R8 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("98 and 99 stay incomplete and blocked behind halted 253-97; 253-103 is the next explicitly dispatched plan", () => {
    const { root } = r8Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of R8_PLAN_IDS) assert.ok(by[`253-${id}`], `the SDK lists three-digit plan 253-${id}`);
    assert.equal(index.plans.length, 106);
    // Measured against the installed SDK 1.16.0: phase-plan-index derives `wave` from depends_on rather than
    // echoing the frontmatter (253-100 declares wave 18; with the same dependencies as 253-97 it reports 97's wave).
    assert.equal(typeof by["253-100"].wave, "number");
    assert.equal(by["253-100"].wave, by["253-97"].wave);
    assert.equal(by["253-101"].wave, by["253-100"].wave + 1);
    assert.deepEqual(by["253-100"].depends_on, ["253-95", "253-96"]);
    assert.deepEqual(by["253-106"].depends_on, ["253-105", "253-103"]);
    for (const id of ["253-98", "253-99"]) {
      assert.ok(index.incomplete.includes(id), `${id} incomplete`);
      assert.equal(by[id].has_summary, false, id);
      assert.ok(by[id].blocked_by.includes("253-97"), `${id} blocked behind 253-97`);
    }
    assert.equal(by["253-97"].halted, true);
    for (const id of ["253-95", "253-96", "253-100", "253-101", "253-102"]) assert.equal(by[id].has_summary, true, id);
    assert.equal(by["253-103"].has_summary, false);
    assert.equal(by["253-103"].halted, false);
    for (const id of ["253-104", "253-105", "253-106"]) assert.equal(by[id].has_summary, false, id);
    // As for R6 and R7, blocked_by propagates through depends_on even past summarized plans, so 103-106 inherit
    // [253-84, 253-92] (not 253-97, which none of them depends on) and `runnable` is empty. 253-103 is the next
    // plan with no summary whose own dependencies (102 and 96) are summarized; it is dispatched explicitly.
    for (const id of ["253-103", "253-104", "253-105", "253-106"]) {
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-84", "253-92"], `${id} inherits the 84 and 92 blocks only`);
      assert.equal(by[id].halted, false, id);
    }
    assert.deepEqual(index.runnable, []);
    const contract = reconcile.buildContract({ revision: "r8" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R8_UNSTARTED);
    assert.deepEqual([...report.any_unsummarized].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R8_UNSTARTED, "103", "104", "105", "106"]);
  });

  test("after simulated R8 dispositions and 103-106 summaries nothing is incomplete, thirteen plans are halted and nothing reports blocked", () => {
    const { root, dir } = r8Fixture();
    for (const id of ["103", "104", "105", "106"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r8" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 46);
    for (const entry of bundle.entries) for (const owner of R8_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 46);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)), R8_HALTED);
    assert.equal(index.plans.filter((p) => p.halted).length, 13);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 106);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R8_NEW_UNSTARTED, ...R7_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r8Fixture();
    for (const id of ["103", "104", "105", "106"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r8" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-105-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-105/);
    assert.equal(existsSync(join(dir, "253-98-SUMMARY.md")), false);
    writeFileSync(join(dir, "253-105-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-104-PLAN.md"), `${readFileSync(join(dir, "253-104-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-104|differs/);
    assert.equal(existsSync(join(dir, "253-98-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-112: R9 revision (253-104 halted at the full-pass artifact download because the frozen transport
// refused the approved 302 redirect to the trusted artifact host, so 253-105 and 253-106 can never run).
// Task 1: partition, dispositioned gating, CLI and three-digit plan IDs.
// ---------------------------------------------------------------------------------------------
const byNumber9 = (a, b) => Number(a) - Number(b);
const R8_CONTRACT_SHA = "a23aba456917fd295463f92304e595e16c405f628f0327681036efd1b9552c7b";
const R9_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R9.json";
const R9_NEW_UNSTARTED = ["105", "106"];
const R9_UNSTARTED = [...R8_UNSTARTED, ...R9_NEW_UNSTARTED].sort(byNumber9);
const R9_HALTED = [...R8_HALTED, "104"];
const R9_COMPLETED = [...R8_COMPLETED, "100", "101", "102", "103"].sort(byNumber9);
const R9_NEVER_RAN_104 = "dependency 253-104 halted during the full-pass artifact download: the frozen transport refused the approved 302 redirect to the trusted artifact host productionresultssa17.blob.core.windows.net (origin_rejected: live transport is restricted to api.github.com)";
const R9_FORBIDDEN_OWNERS = [...R8_FORBIDDEN_OWNERS, "104", "105", "106"];

describe("R9 revision skeleton: partition, dispositioned gating, CLI and three-digit plan IDs", () => {
  test("R9 sets partition PLANs 01-106 into 44 completed, 14 halted and 48 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"]);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R9], R9_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R9], R9_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R9], R9_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R9], R9_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R9.length, 44);
    assert.equal(reconcile.HALTED_IDS_R9.length, 14);
    assert.equal(reconcile.UNSTARTED_IDS_R9.length, 48);
    const all = [...reconcile.COMPLETED_IDS_R9, ...reconcile.HALTED_IDS_R9, ...reconcile.UNSTARTED_IDS_R9].sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 106 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(reconcile.NEVER_RAN_REASON_R9, R9_NEVER_RAN_104);
    assert.equal(reconcile.CONTRACT_NAME_R9, R9_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R9, "sigra.phase253.load-recovery-reconciliation-contract/r9");
    assert.equal(reconcile.contractPathFor("r9"), join(HERE, R9_CONTRACT_NAME));
    assert.equal(reconcile.contractPathFor("r8"), join(HERE, R8_CONTRACT_NAME));
    assert.throws(() => reconcile.contractPathFor("r13"), /unknown revision r13/);
  });

  test("r6, r7, r8 and r9 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7", "r8", "r9"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r9 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r9" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r9" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r9" }).accepted, false);
  });

  test("three-digit plan IDs build, sort and match: 253-99, 253-106, 253-107 and 253-115", () => {
    assert.equal(reconcile.planIdOf(107), "253-107");
    assert.equal(reconcile.planIdOf(115), "253-115");
    assert.deepEqual(["253-115", "253-107", "253-106", "253-99"].sort(reconcile.comparePlanIds), ["253-99", "253-106", "253-107", "253-115"]);
    assert.deepEqual(["115", "107", "106", "99"].sort(reconcile.comparePlanIds), ["99", "106", "107", "115"]);
    assert.deepEqual(reconcile.parsePlanFile("253-107-PLAN.md"), { id: "107", number: 107, kind: "PLAN" });
    assert.deepEqual(reconcile.parsePlanFile("253-115-SUMMARY.md"), { id: "115", number: 115, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-99-PLAN.md"), { id: "99", number: 99, kind: "PLAN" });
    assert.equal(reconcile.parsePlanFile("253-1150-PLAN.md"), null);
    assert.deepEqual([...reconcile.R9_PLAN_IDS], ["107", "108", "109", "110", "111", "112", "113", "114", "115"]);
  });

  test("CLI --revision r9 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-112-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R9_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r9", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r9");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R9);
    assert.equal(contract.responsibilities.length, 48);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("105 and 106 are never-ran rows blocked by halted 253-104; earlier rows keep their reasons; every row carries the R9 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r9" });
    for (const id of R9_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-104"], id);
      assert.equal(row.never_ran_reason, R9_NEVER_RAN_104, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R9_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R9", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-98").never_ran_reason, R8_NEVER_RAN_97);
    assert.deepEqual(contract.responsibilities.find((r) => r.plan === "253-99").blocked_by, ["253-97"]);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-93").never_ran_reason, R7_NEVER_RAN_92);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-112 Task 2: R9 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R9_REMAP = { "102": ["102", "111"], "103": ["103", "112"], "104": ["113"], "105": ["114"], "106": ["112", "115"] };
const remapR9 = (owners) => [...new Set(owners.flatMap((owner) => R9_REMAP[owner] ?? [owner]))];
const R9_OWNERS = {
  ...Object.fromEntries(Object.entries(R8_OWNERS).map(([id, owners]) => [id, remapR9(owners)])),
  "105": ["114"],
  "106": ["112", "115"],
};
const R9_NATIVE = R8_NATIVE;
const R9_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "103", "112", "115"];
const R9_PLAN_IDS_T = ["107", "108", "109", "110", "111", "112", "113", "114", "115"];
// 253-103's receipts name this helper and its test, which plan 112 edits. They are held at the bytes of the
// last 253-103 commit that touched each file (6a898e019), read with git, never invented.
const FROZEN_TOOLING_R9_103 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "80da1a200d6c5a4da23768713c6baa757ca1fd71414f1219b18e871ab6a29aa8",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "afac0fe9a385a79e7cf3c0b913e0ede794e4b2f5131f7ec2bc81d24044439b17",
};
const R8_SUMMARY_PIN_IDS = [...R7_SUMMARY_PIN_IDS, "96", "97", "100", "101", "102"];
const R9_SUMMARY_PIN_IDS = [...R8_SUMMARY_PIN_IDS, "103", "104", "107", "108", "109", "110", "111"];
// The R9 world: PLANs 01-115 and the real SUMMARYs through 111, built by the unchanged r8Fixture.
const r9Fixture = () => r8Fixture({ maxPlan: 115, maxSummary: 111 });

describe("R9 reconciliation contract", () => {
  test("v1 and R2-R8 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"], [R7_CONTRACT_NAME, R7_CONTRACT_SHA, "r7"], [R8_CONTRACT_NAME, R8_CONTRACT_SHA, "r8"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
  });

  test("partitions PLANs 01-106 into 44 completed, 14 halted and 48 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r9" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r9");
    assert.equal(contract.revision, "r9");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R9_COMPLETED);
    assert.equal(contract.completed_plans.length, 44);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R9_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(14).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R9_UNSTARTED);
    assert.equal(contract.responsibilities.length, 48);
    assert.equal(contract.originals.length, 106);
    assert.equal(contract.originals.filter((o) => o.class === "halted").length, 14);
    assert.equal(contract.originals.find((o) => o.plan === "253-104").class, "halted");
    assert.equal(contract.originals.find((o) => o.plan === "253-103").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-106").class, "unstarted_blocked");
    assert.deepEqual(contract.originals.map((o) => o.plan), Array.from({ length: 106 }, (_, i) => reconcile.planIdOf(i + 1)));
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 106 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED, "97": R8_NEW_UNSTARTED, "104": R9_NEW_UNSTARTED };
    const reasons = { "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92, "97": R8_NEVER_RAN_97, "104": R9_NEVER_RAN_104 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
      }
    }
  });

  test("maps every responsibility to the R9 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r9" });
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners, R9_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R9_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    for (const row of Object.values(owners)) assert.equal(new Set(row).size, row.length, "no duplicate owners after the remap");
    assert.deepEqual(owners["10"], R9_NATIVE);
    assert.deepEqual(owners["14"], R9_COMPLETION);
    assert.deepEqual(owners["08"], ["42", "114"]);
    assert.deepEqual(owners["22"], ["91", "95", "102", "111"]);
    assert.deepEqual(owners["86"], ["113"]);
    assert.deepEqual(owners["93"], ["114"]);
    assert.deepEqual(owners["94"], ["96", "103", "112", "115"]);
    assert.deepEqual(owners["98"], ["114"]);
    assert.deepEqual(owners["99"], ["103", "112", "115"]);
    assert.deepEqual(owners["105"], ["114"]);
    assert.deepEqual(owners["106"], ["112", "115"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["105"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["106"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["99"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R9_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R9_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "102", "111", "113"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-102", "253-111", "253-113"]);
    assert.deepEqual(contract.halted_proof_map["253-97"], ["253-100", "253-101", "253-102", "253-111", "253-113"]);
    assert.deepEqual(contract.halted_proof_map["253-104"], ["253-107", "253-108", "253-110", "253-111", "253-113"]);
    for (const list of Object.values(contract.halted_proof_map)) for (const owner of list) assert.ok(!R9_FORBIDDEN_OWNERS.includes(owner.slice(4)), `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
  });

  test("pins every PLAN 01-115 in numeric order, the existing summaries, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r9" });
    assert.equal(contract.plan_pins.length, 115);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan), Array.from({ length: 115 }, (_, i) => reconcile.planIdOf(i + 1)));
    assert.deepEqual(contract.plan_pins.slice(-9).map((p) => p.plan.slice(4)), R9_PLAN_IDS_T);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.equal(R8_SUMMARY_PIN_IDS.length, 39);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), R9_SUMMARY_PIN_IDS);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.deepEqual(contract.r6_contract, { path: `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`, sha256: R6_CONTRACT_SHA });
    assert.deepEqual(contract.r7_contract, { path: `${PHASE_DIR_REL}/${R7_CONTRACT_NAME}`, sha256: R7_CONTRACT_SHA });
    assert.deepEqual(contract.r8_contract, { path: `${PHASE_DIR_REL}/${R8_CONTRACT_NAME}`, sha256: R8_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    const r8 = reconcile.buildContract({ revision: "r8" });
    assert.deepEqual(contract.sdk, r8.sdk);
    assert.deepEqual(contract.capture, r8.capture);
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-115");
    assert.equal(contract.application.targets, "only the forty-eight previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.equal(contract.application.then_run, r8.application.then_run);
    assert.deepEqual(contract.application.never, r8.application.never);
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
  });

  test("tooling receipts are frozen per plan: every R8 record as R8 holds it, 253-103 at its last commit, 253-104 with its ten records", () => {
    const contract = reconcile.buildContract({ revision: "r9" });
    const r8 = reconcile.buildContract({ revision: "r8" });
    for (const plan of r8.completed_plans) assert.deepEqual(contract.completed_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R8 holds it`);
    for (const plan of r8.halted_plans) assert.deepEqual(contract.halted_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R8 holds it`);
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R8_96)) assert.equal(receipt("253-96", path), hash, `96 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R9_103)) {
      assert.equal(receipt("253-103", path), hash, `103 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `6a898e019:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `103 ${path} equals the blob at commit 6a898e019`);
      const log = spawnSync("git", ["-C", REPO, "log", "-1", "--format=%h", "--grep=(253-103)", "--", path], { encoding: "utf8" });
      assert.equal(log.stdout.trim().slice(0, 9), "6a898e019", `6a898e019 is the last 253-103 commit touching ${path}`);
      assert.notEqual(sha(readFileSync(join(REPO, path))), hash, `${path} has since been edited by plan 112 (the freeze is load-bearing)`);
    }
    assert.equal(receipt("253-103", `${PHASE_DIR_REL}/${R8_CONTRACT_NAME}`), R8_CONTRACT_SHA);
    const oneOhFour = contract.halted_plans.find((p) => p.plan === "253-104");
    assert.equal(oneOhFour.receipts.length, 10);
    assert.equal(oneOhFour.missing_receipts, undefined);
    assert.equal(oneOhFour.summary.status, "halted");
    for (const r of oneOhFour.receipts) assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
    for (const id of ["100", "101", "102"]) assert.ok(contract.completed_plans.find((p) => p.plan === `253-${id}`), id);
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 107-115 (positive control: the same clone builds)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-112-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r9" });
    assert.equal(built.plan_pins.length, 115);
    rmSync(join(root, PHASE_DIR_REL, "253-113-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r9" }), /253-113/);
    git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-113-PLAN.md`);
    assert.equal(reconcile.buildContract({ repoRoot: root, revision: "r9" }).plan_pins.length, 115);
    rmSync(join(root, PHASE_DIR_REL, "253-115-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r9" }), /253-115/);
    git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-115-PLAN.md`);
    rmSync(join(root, PHASE_DIR_REL, "253-109-PLAN.md"));
    assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r9" }), /253-109/);
  });

  test("CLI --revision r9 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r8 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-112-contract-"));
    cleanup.push(dir);
    const target = join(dir, R9_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r9" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r9", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME], ["r7", R7_CONTRACT_NAME], ["r8", R8_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R9 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R9 successors", () => {
    const { root } = r9Fixture();
    const contract = reconcile.buildContract({ revision: "r9" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 48);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /\nstatus: superseded\n/);
      assert.match(entry.content, /\nexecution_performed: false\n/);
      assert.match(entry.content, /\noriginal_status: blocked\n/);
      assert.match(entry.content, /\nphase_verification_status: not_started\n/);
      assert.doesNotMatch(entry.content, /\nstatus: blocked\n/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
    }
    const oneOhFive = bundle.entries.find((e) => e.plan === "253-105");
    assert.match(oneOhFive.content, /never ran because its dependency 253-104 halted during the full-pass artifact download/);
    assert.match(oneOhFive.content, /Its R9 successor is 253-114\./);
    assert.match(oneOhFive.content, /original_blocked_by: \["253-104"\]/);
    const oneOhSix = bundle.entries.find((e) => e.plan === "253-106");
    assert.match(oneOhSix.content, /Its R9 successor is 253-112, 253-115\./);
    assert.match(oneOhSix.content, /link: load_target_disposition/);
    const ninetyEight = bundle.entries.find((e) => e.plan === "253-98");
    assert.match(ninetyEight.content, /never ran because its dependency 253-97 halted at the full-pass preflight/);
    assert.match(ninetyEight.content, /Its R9 successor is 253-114\./);
  });
});

describe("R9 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("105 and 106 stay incomplete and blocked behind halted 253-104; 253-112 is the next explicitly dispatched plan", () => {
    const { root } = r9Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of R9_PLAN_IDS_T) assert.ok(by[`253-${id}`], `the SDK lists three-digit plan 253-${id}`);
    assert.equal(index.plans.length, 115);
    for (const id of ["253-105", "253-106"]) {
      assert.ok(index.incomplete.includes(id), `${id} incomplete`);
      assert.equal(by[id].has_summary, false, id);
      assert.ok(by[id].blocked_by.includes("253-104"), `${id} blocked behind 253-104`);
      assert.equal(by[id].halted, false, id);
    }
    assert.equal(by["253-104"].halted, true);
    for (const id of ["100", "101", "102", "103", "107", "108", "109", "110", "111"]) assert.equal(by[`253-${id}`].has_summary, true, id);
    // Measured against the installed SDK 1.16.0: wave is derived from depends_on, blocked_by propagates through
    // depends_on past summarized plans, so 112-115 inherit [253-84, 253-92] (not 253-104, which none of them
    // depends on) and `runnable` is empty. 253-112 is the next plan with no summary whose own dependency (111)
    // is summarized; it is dispatched explicitly.
    assert.deepEqual(by["253-112"].depends_on, ["253-111"]);
    assert.equal(by["253-113"].wave, by["253-112"].wave + 1);
    for (const id of ["253-112", "253-113", "253-114", "253-115"]) {
      assert.equal(by[id].has_summary, false, id);
      assert.equal(by[id].halted, false, id);
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-84", "253-92"], `${id} inherits the 84 and 92 blocks only`);
    }
    assert.deepEqual(index.runnable, []);
    const contract = reconcile.buildContract({ revision: "r9" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R9_UNSTARTED);
    assert.deepEqual([...report.any_unsummarized].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R9_UNSTARTED, "112", "113", "114", "115"]);
  });

  test("after simulated R9 dispositions and 112-115 summaries nothing is incomplete, fourteen plans are halted and nothing reports blocked", () => {
    const { root, dir } = r9Fixture();
    for (const id of ["112", "113", "114", "115"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r9" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 48);
    for (const entry of bundle.entries) for (const owner of R9_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 48);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)).sort(byNumber9), [...R9_HALTED].sort(byNumber9));
    assert.equal(index.plans.filter((p) => p.halted).length, 14);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 115);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R9_NEW_UNSTARTED, ...R8_NEW_UNSTARTED, ...R7_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r9Fixture();
    for (const id of ["112", "113", "114", "115"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r9" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-114-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-114/);
    assert.equal(existsSync(join(dir, "253-105-SUMMARY.md")), false);
    writeFileSync(join(dir, "253-114-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-113-PLAN.md"), `${readFileSync(join(dir, "253-113-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-113|differs/);
    assert.equal(existsSync(join(dir, "253-105-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-121: R10 revision (253-113 halted at the full-pass verifier because the frozen verifier required
// run.name to equal the bare workflow name while GitHub returns the workflow run-name, so 253-114 and
// 253-115 can never run).
// Task 1: partition, dispositioned gating, numeric revision order, CLI and plan IDs up to 253-124.
// ---------------------------------------------------------------------------------------------
const R9_CONTRACT_SHA = "857b23970613e5a0bf73fee613fcb0f9b523074d4c6d375bb23311a59aecd207";
const R10_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R10.json";
const R10_NEW_UNSTARTED = ["114", "115"];
const R10_UNSTARTED = [...R9_UNSTARTED, ...R10_NEW_UNSTARTED].sort(byNumber9);
const R10_HALTED = [...R9_HALTED, "113"];
const R10_COMPLETED = [...R9_COMPLETED, "107", "108", "109", "110", "111", "112"].sort(byNumber9);
const R10_NEVER_RAN_113 = "dependency 253-113 halted at the full-pass verifier: the frozen ci-hosted-gate-verify.py required the run name to equal the bare workflow name 'Phase 253 Gate Canary', but GitHub returned the workflow run-name 'Phase 253 Gate Canary / full-pass / 38906314106-1' (run workflow identity mismatch)";
const R10_FORBIDDEN_OWNERS = [...R9_FORBIDDEN_OWNERS, "113", "114", "115"];
const R10_REVISIONS = ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"];

describe("R10 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs", () => {
  test("R10 sets partition PLANs 01-115 into 50 completed, 15 halted and 50 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], R10_REVISIONS);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R10], R10_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R10], R10_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R10], R10_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R10], R10_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R10.length, 50);
    assert.equal(reconcile.HALTED_IDS_R10.length, 15);
    assert.equal(reconcile.UNSTARTED_IDS_R10.length, 50);
    const all = [...reconcile.COMPLETED_IDS_R10, ...reconcile.HALTED_IDS_R10, ...reconcile.UNSTARTED_IDS_R10].sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 115 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(new Set(all).size, 115, "no id is in two classes");
    assert.equal(reconcile.NEVER_RAN_REASON_R10, R10_NEVER_RAN_113);
    assert.equal(reconcile.CONTRACT_NAME_R10, R10_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R10, "sigra.phase253.load-recovery-reconciliation-contract/r10");
    assert.equal(reconcile.contractPathFor("r10"), join(HERE, R10_CONTRACT_NAME));
    assert.equal(reconcile.contractPathFor("r9"), join(HERE, R9_CONTRACT_NAME));
    assert.throws(() => reconcile.contractPathFor("r13"), /unknown revision r13/);
    assert.throws(() => reconcile.buildContract({ revision: "r13" }), /unknown revision r13/);
  });

  test("revisions are ordered numerically everywhere: r10 follows r9 and never sorts before r2", () => {
    assert.deepEqual([...reconcile.REVISIONS], R10_REVISIONS);
    assert.equal(reconcile.REVISIONS.indexOf("r10"), reconcile.REVISIONS.indexOf("r9") + 1);
    assert.ok(reconcile.REVISIONS.indexOf("r10") > reconcile.REVISIONS.indexOf("r2"));
    // Positive control: a plain string sort WOULD put r10 before r2, so the list must never be sorted.
    assert.ok([...R10_REVISIONS].sort().indexOf("r10") < [...R10_REVISIONS].sort().indexOf("r2"));
    const source = readFileSync(SCRIPT, "utf8");
    assert.doesNotMatch(source, /REVISIONS\]?\)?\.sort\(/, "the helper never sorts the revision list");
    assert.doesNotMatch(source, /REVISIONS\.(toSorted|reverse)\(/);
    const refused = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", "/nonexistent/x.json", "--check-only"], { encoding: "utf8" });
    assert.equal(refused.status, 2);
    assert.match(refused.stderr, /expected one of v1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12\n/);
    const keys = Object.keys(reconcile.buildContract({ revision: "r10" })).filter((key) => /_contract$/.test(key));
    assert.deepEqual(keys, ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract"]);
  });

  test("r6-r10 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7", "r8", "r9", "r10"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r10 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r10" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r10" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r10" }).accepted, false);
  });

  test("plan IDs build, sort and match: 253-99, 253-113, 253-116 and 253-124", () => {
    assert.equal(reconcile.planIdOf(116), "253-116");
    assert.equal(reconcile.planIdOf(124), "253-124");
    assert.deepEqual(["253-124", "253-116", "253-113", "253-99"].sort(reconcile.comparePlanIds), ["253-99", "253-113", "253-116", "253-124"]);
    assert.deepEqual(["124", "116", "113", "99"].sort(reconcile.comparePlanIds), ["99", "113", "116", "124"]);
    assert.deepEqual(reconcile.parsePlanFile("253-116-PLAN.md"), { id: "116", number: 116, kind: "PLAN" });
    assert.deepEqual(reconcile.parsePlanFile("253-124-SUMMARY.md"), { id: "124", number: 124, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-113-SUMMARY.md"), { id: "113", number: 113, kind: "SUMMARY" });
    assert.equal(reconcile.parsePlanFile("253-1240-PLAN.md"), null);
    assert.deepEqual([...reconcile.R10_PLAN_IDS], ["116", "117", "118", "119", "120", "121", "122", "123", "124"]);
  });

  test("CLI --revision r10 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-121-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R10_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r10", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r10");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R10);
    assert.equal(contract.responsibilities.length, 50);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("114 and 115 are never-ran rows blocked by halted 253-113; earlier rows keep their reasons; every row carries the R10 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r10" });
    for (const id of R10_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-113"], id);
      assert.equal(row.never_ran_reason, R10_NEVER_RAN_113, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R10_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R10", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-105").never_ran_reason, R9_NEVER_RAN_104);
    assert.deepEqual(contract.responsibilities.find((r) => r.plan === "253-106").blocked_by, ["253-104"]);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-98").never_ran_reason, R8_NEVER_RAN_97);
    for (const row of contract.responsibilities) for (const owner of row.owners) assert.ok(!R10_FORBIDDEN_OWNERS.includes(owner.slice(4)), `${row.plan} owner ${owner}`);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-121 Task 2: R10 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R10_REMAP = { "111": ["111", "120"], "112": ["112", "121"], "113": ["122"], "114": ["123"], "115": ["121", "124"] };
const remapR10 = (owners) => [...new Set(owners.flatMap((owner) => R10_REMAP[owner] ?? [owner]))];
const R10_OWNERS = {
  ...Object.fromEntries(Object.entries(R9_OWNERS).map(([id, owners]) => [id, remapR10(owners)])),
  "114": ["123"],
  "115": ["121", "124"],
};
const R10_NATIVE = R9_NATIVE;
const R10_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "103", "112", "121", "124"];
const R10_PLAN_IDS_T = ["116", "117", "118", "119", "120", "121", "122", "123", "124"];
// 253-112's receipts name this helper and its test, which plan 121 edits. They are held at the bytes of the
// last 253-112 commit that touched each file (17f3db955), read with git, never invented.
const FROZEN_TOOLING_R10_112 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "7653cf4b4e1b68b71526d004c428e2e7320453d7761764bb127f1200281a54f5",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "a166f6c40c91fa9958d35c06f8fdf6e8a6cdbf9d336f246aaf206eda92b8e833",
};
const R10_SUMMARY_PIN_IDS = [...R9_SUMMARY_PIN_IDS, "112", "113", "116", "117", "118", "119", "120"];
// The R10 world: PLANs 01-124 and the real SUMMARYs through 120, built by the unchanged r8Fixture.
const r10Fixture = () => r8Fixture({ maxPlan: 124, maxSummary: 120 });
const preservationR10 = () => Object.fromEntries(readFileSync(join(REAL_PHASE_DIR, "253-LOAD-RECOVERY-PRESERVATION-R10.sha256"), "utf8")
  .split("\n").filter(Boolean).map((line) => { const [hash, path] = line.split(/\s+/); return [path, hash]; }));

describe("R10 reconciliation contract", () => {
  test("v1 and R2-R9 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"], [R7_CONTRACT_NAME, R7_CONTRACT_SHA, "r7"], [R8_CONTRACT_NAME, R8_CONTRACT_SHA, "r8"], [R9_CONTRACT_NAME, R9_CONTRACT_SHA, "r9"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
  });

  test("partitions PLANs 01-115 into 50 completed, 15 halted and 50 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r10" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r10");
    assert.equal(contract.revision, "r10");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R10_COMPLETED);
    assert.equal(contract.completed_plans.length, 50);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R10_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(15).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R10_UNSTARTED);
    assert.equal(contract.responsibilities.length, 50);
    assert.equal(contract.originals.length, 115);
    assert.equal(contract.originals.filter((o) => o.class === "halted").length, 15);
    assert.equal(contract.originals.find((o) => o.plan === "253-113").class, "halted");
    assert.equal(contract.originals.find((o) => o.plan === "253-112").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-107").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-115").class, "unstarted_blocked");
    assert.deepEqual(contract.originals.map((o) => o.plan), Array.from({ length: 115 }, (_, i) => reconcile.planIdOf(i + 1)));
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 115 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED, "97": R8_NEW_UNSTARTED, "104": R9_NEW_UNSTARTED, "113": R10_NEW_UNSTARTED };
    const reasons = { "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92, "97": R8_NEVER_RAN_97, "104": R9_NEVER_RAN_104, "113": R10_NEVER_RAN_113 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
      }
    }
  });

  test("maps every responsibility to the R10 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r10" });
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners, R10_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R10_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    for (const row of Object.values(owners)) assert.equal(new Set(row).size, row.length, "no duplicate owners after the remap");
    assert.deepEqual(owners["10"], R10_NATIVE);
    assert.deepEqual(owners["14"], R10_COMPLETION);
    assert.deepEqual(owners["08"], ["42", "123"]);
    assert.deepEqual(owners["22"], ["91", "95", "102", "111", "120"]);
    assert.deepEqual(owners["86"], ["122"]);
    assert.deepEqual(owners["93"], ["123"]);
    assert.deepEqual(owners["94"], ["96", "103", "112", "121", "124"]);
    assert.deepEqual(owners["98"], ["123"]);
    assert.deepEqual(owners["99"], ["103", "112", "121", "124"]);
    assert.deepEqual(owners["105"], ["123"]);
    assert.deepEqual(owners["106"], ["112", "121", "124"]);
    assert.deepEqual(owners["114"], ["123"]);
    assert.deepEqual(owners["115"], ["121", "124"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["114"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["115"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["106"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R10_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R10_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "102", "111", "120", "122"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-102", "253-111", "253-120", "253-122"]);
    assert.deepEqual(contract.halted_proof_map["253-97"], ["253-100", "253-101", "253-102", "253-111", "253-120", "253-122"]);
    assert.deepEqual(contract.halted_proof_map["253-104"], ["253-107", "253-108", "253-110", "253-111", "253-120", "253-122"]);
    assert.deepEqual(contract.halted_proof_map["253-113"], ["253-116", "253-117", "253-118", "253-119", "253-120", "253-122"]);
    for (const list of Object.values(contract.halted_proof_map)) for (const owner of list) assert.ok(!R10_FORBIDDEN_OWNERS.includes(owner.slice(4)), `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
  });

  test("pins every PLAN 01-124 in numeric order, the existing summaries, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r10" });
    assert.equal(contract.plan_pins.length, 124);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan), Array.from({ length: 124 }, (_, i) => reconcile.planIdOf(i + 1)));
    assert.deepEqual(contract.plan_pins.slice(-9).map((p) => p.plan.slice(4)), R10_PLAN_IDS_T);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.equal(R9_SUMMARY_PIN_IDS.length, 46);
    assert.equal(R10_SUMMARY_PIN_IDS.length, 53);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), R10_SUMMARY_PIN_IDS);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.deepEqual(contract.r6_contract, { path: `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`, sha256: R6_CONTRACT_SHA });
    assert.deepEqual(contract.r7_contract, { path: `${PHASE_DIR_REL}/${R7_CONTRACT_NAME}`, sha256: R7_CONTRACT_SHA });
    assert.deepEqual(contract.r8_contract, { path: `${PHASE_DIR_REL}/${R8_CONTRACT_NAME}`, sha256: R8_CONTRACT_SHA });
    assert.deepEqual(contract.r9_contract, { path: `${PHASE_DIR_REL}/${R9_CONTRACT_NAME}`, sha256: R9_CONTRACT_SHA });
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    const r9 = reconcile.buildContract({ revision: "r9" });
    assert.deepEqual(contract.sdk, r9.sdk);
    assert.deepEqual(contract.capture, r9.capture);
    assert.equal(contract.application.root_only, true);
    assert.equal(contract.application.write_ahead, true);
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-124");
    assert.equal(contract.application.targets, "only the fifty previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.equal(contract.application.then_run, r9.application.then_run);
    assert.deepEqual(contract.application.never, r9.application.never);
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
  });

  test("tooling receipts are frozen per plan: every R9 record as R9 holds it, 253-112 at its last commit, 253-113 with its ten records", () => {
    const contract = reconcile.buildContract({ revision: "r10" });
    const r9 = reconcile.buildContract({ revision: "r9" });
    for (const plan of r9.completed_plans) assert.deepEqual(contract.completed_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R9 holds it`);
    for (const plan of r9.halted_plans) assert.deepEqual(contract.halted_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R9 holds it`);
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R8_96)) assert.equal(receipt("253-96", path), hash, `96 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R9_103)) assert.equal(receipt("253-103", path), hash, `103 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R10_112)) {
      assert.equal(receipt("253-112", path), hash, `112 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `17f3db955:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `112 ${path} equals the blob at commit 17f3db955`);
      const log = spawnSync("git", ["-C", REPO, "log", "-1", "--format=%h", "--grep=(253-112)", "--", path], { encoding: "utf8" });
      assert.equal(log.stdout.trim().slice(0, 9), "17f3db955", `17f3db955 is the last 253-112 commit touching ${path}`);
      assert.notEqual(sha(readFileSync(join(REPO, path))), hash, `${path} has since been edited by plan 121 (the freeze is load-bearing)`);
    }
    assert.equal(receipt("253-112", `${PHASE_DIR_REL}/${R9_CONTRACT_NAME}`), R9_CONTRACT_SHA);
    assert.equal(contract.completed_plans.find((p) => p.plan === "253-112").receipts.length, 3);
    const preserved = preservationR10();
    const oneThirteen = contract.halted_plans.find((p) => p.plan === "253-113");
    assert.equal(oneThirteen.receipts.length, 10);
    assert.equal(oneThirteen.missing_receipts, undefined);
    assert.equal(oneThirteen.summary.status, "halted");
    assert.equal(oneThirteen.summary.sha256, preserved[`${PHASE_DIR_REL}/253-113-SUMMARY.md`]);
    for (const r of oneThirteen.receipts) {
      assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
      assert.equal(r.sha256, preserved[r.path], `${r.path} is at its PRESERVATION-R10 bytes`);
    }
    for (const id of ["107", "108", "109", "110", "111"]) {
      const plan = contract.completed_plans.find((p) => p.plan === `253-${id}`);
      assert.ok(plan, id);
      for (const r of plan.receipts) assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
    }
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 116-124 and a halted or never-executed owner (positive controls: the same clone builds, a live owner passes)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-121-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r10" });
    assert.equal(built.plan_pins.length, 124);
    for (const id of ["122", "124", "118"]) {
      rmSync(join(root, PHASE_DIR_REL, `253-${id}-PLAN.md`));
      assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r10" }), new RegExp(`253-${id}`));
      git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-${id}-PLAN.md`);
      assert.equal(reconcile.buildContract({ repoRoot: root, revision: "r10" }).plan_pins.length, 124);
    }
    const phaseDir = join(root, PHASE_DIR_REL);
    for (const owner of ["121", "124", "120", "253-122"]) assert.doesNotThrow(() => reconcile.assertProofOwnerR10(phaseDir, owner), owner);
    for (const owner of ["113", "114", "115", "104", "105", "92", "253-113"]) assert.throws(() => reconcile.assertProofOwnerR10(phaseDir, owner), /halted or never-executed/, owner);
    rmSync(join(phaseDir, "253-123-PLAN.md"));
    assert.throws(() => reconcile.assertProofOwnerR10(phaseDir, "123"), /253-123 is missing/);
  });

  test("CLI --revision r10 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r9 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-121-contract-"));
    cleanup.push(dir);
    const target = join(dir, R10_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r10" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r10", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME], ["r7", R7_CONTRACT_NAME], ["r8", R8_CONTRACT_NAME], ["r9", R9_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R10 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R10 successors", () => {
    const { root } = r10Fixture();
    const contract = reconcile.buildContract({ revision: "r10" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 50);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /\nstatus: superseded\n/);
      assert.match(entry.content, /\nexecution_performed: false\n/);
      assert.match(entry.content, /\noriginal_status: blocked\n/);
      assert.match(entry.content, /\nphase_verification_status: not_started\n/);
      assert.doesNotMatch(entry.content, /\nstatus: blocked\n/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
    }
    const oneFourteen = bundle.entries.find((e) => e.plan === "253-114");
    assert.match(oneFourteen.content, /never ran because its dependency 253-113 halted at the full-pass verifier/);
    assert.match(oneFourteen.content, /run workflow identity mismatch/);
    assert.match(oneFourteen.content, /Its R10 successor is 253-123\./);
    assert.match(oneFourteen.content, /original_blocked_by: \["253-113"\]/);
    const oneFifteen = bundle.entries.find((e) => e.plan === "253-115");
    assert.match(oneFifteen.content, /Its R10 successor is 253-121, 253-124\./);
    assert.match(oneFifteen.content, /link: load_target_disposition/);
    const oneOhFive = bundle.entries.find((e) => e.plan === "253-105");
    assert.match(oneOhFive.content, /never ran because its dependency 253-104 halted during the full-pass artifact download/);
    assert.match(oneOhFive.content, /Its R10 successor is 253-123\./);
  });
});

describe("R10 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("114 and 115 stay incomplete and blocked behind halted 253-113; 253-121 is the next explicitly dispatched plan", () => {
    const { root } = r10Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of R10_PLAN_IDS_T) assert.ok(by[`253-${id}`], `the SDK lists plan 253-${id}`);
    assert.equal(index.plans.length, 124);
    for (const id of ["253-114", "253-115"]) {
      assert.ok(index.incomplete.includes(id), `${id} incomplete`);
      assert.equal(by[id].has_summary, false, id);
      assert.ok(by[id].blocked_by.includes("253-113"), `${id} blocked behind 253-113`);
      assert.equal(by[id].halted, false, id);
    }
    assert.equal(by["253-113"].halted, true);
    for (const id of ["107", "108", "109", "110", "111", "112", "116", "117", "118", "119", "120"]) assert.equal(by[`253-${id}`].has_summary, true, id);
    // Measured against the installed SDK 1.16.0: blocked_by propagates through depends_on past summarized
    // plans, so 121-124 inherit [253-84, 253-92] (not 253-113, which none of them depends on) and `runnable`
    // is empty. 253-121 is the next plan with no summary whose own dependency (120) is summarized; it is
    // dispatched explicitly.
    assert.deepEqual(by["253-121"].depends_on, ["253-120"]);
    assert.equal(by["253-122"].wave, by["253-121"].wave + 1);
    for (const id of ["253-121", "253-122", "253-123", "253-124"]) {
      assert.equal(by[id].has_summary, false, id);
      assert.equal(by[id].halted, false, id);
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-84", "253-92"], `${id} inherits the 84 and 92 blocks only`);
    }
    assert.deepEqual(index.runnable, []);
    const contract = reconcile.buildContract({ revision: "r10" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R10_UNSTARTED);
    assert.deepEqual([...report.any_unsummarized].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R10_UNSTARTED, "121", "122", "123", "124"]);
  });

  test("after simulated R10 dispositions and 121-124 summaries nothing is incomplete, fifteen plans are halted and nothing reports blocked", () => {
    const { root, dir } = r10Fixture();
    for (const id of ["121", "122", "123", "124"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r10" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 50);
    for (const entry of bundle.entries) for (const owner of R10_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 50);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)).sort(byNumber9), [...R10_HALTED].sort(byNumber9));
    assert.equal(index.plans.filter((p) => p.halted).length, 15);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 124);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R10_NEW_UNSTARTED, ...R9_NEW_UNSTARTED, ...R8_NEW_UNSTARTED, ...R7_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r10Fixture();
    for (const id of ["121", "122", "123", "124"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r10" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-123-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-123/);
    assert.equal(existsSync(join(dir, "253-114-SUMMARY.md")), false);
    writeFileSync(join(dir, "253-123-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-122-PLAN.md"), `${readFileSync(join(dir, "253-122-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-122|differs/);
    assert.equal(existsSync(join(dir, "253-114-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-132: R11 revision (253-122 halted at the first failure scenario because GitHub redirected the
// actual-failure run's logs to results-receiver.actions.githubusercontent.com, outside the then-frozen trusted
// download policy, so 253-123 and 253-124 can never run).
// Task 1: partition, dispositioned gating, numeric revision order, CLI and plan IDs up to 253-135.
// ---------------------------------------------------------------------------------------------
const R10_CONTRACT_SHA = "ac05a22cc27f9e2718b3c93e94133c2c3c71d3a5fe8d9c059ff1bb8117b0509f";
const R11_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R11.json";
const R11_NEW_UNSTARTED = ["123", "124"];
const R11_UNSTARTED = [...R10_UNSTARTED, ...R11_NEW_UNSTARTED].sort(byNumber9);
const R11_HALTED = [...R10_HALTED, "122"];
const R11_COMPLETED = [...R10_COMPLETED, "116", "117", "118", "119", "120", "121"].sort(byNumber9);
const R11_NEVER_RAN_122 = "dependency 253-122 halted at the first failure scenario: GitHub redirected the actual-failure run's logs (run 38963239851) to results-receiver.actions.githubusercontent.com, which the then-frozen ci-hosted-transport.py trusted download policy refused before its socket (redirect_rejected)";
const R11_FORBIDDEN_OWNERS = [...R10_FORBIDDEN_OWNERS, "122", "123", "124"];
const R11_REVISIONS = ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"];

describe("R11 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs", () => {
  test("R11 sets partition PLANs 01-124 into 56 completed, 16 halted and 52 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], R11_REVISIONS);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R11], R11_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R11], R11_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R11], R11_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R11], R11_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R11.length, 56);
    assert.equal(reconcile.HALTED_IDS_R11.length, 16);
    assert.equal(reconcile.UNSTARTED_IDS_R11.length, 52);
    const all = [...reconcile.COMPLETED_IDS_R11, ...reconcile.HALTED_IDS_R11, ...reconcile.UNSTARTED_IDS_R11].sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 124 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(new Set(all).size, 124, "no id is in two classes");
    assert.deepEqual(R11_HALTED, ["02", "07", "09", "12", "16", "27", "40", "51", "63", "73", "84", "92", "97", "104", "113", "122"]);
    assert.equal(reconcile.NEVER_RAN_REASON_R11, R11_NEVER_RAN_122);
    assert.equal(reconcile.CONTRACT_NAME_R11, R11_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R11, "sigra.phase253.load-recovery-reconciliation-contract/r11");
    assert.equal(reconcile.contractPathFor("r11"), join(HERE, R11_CONTRACT_NAME));
    assert.equal(reconcile.contractPathFor("r10"), join(HERE, R10_CONTRACT_NAME));
    assert.throws(() => reconcile.contractPathFor("r13"), /unknown revision r13/);
    assert.throws(() => reconcile.buildContract({ revision: "r13" }), /unknown revision r13/);
  });

  test("revisions are ordered numerically everywhere: r10 and r11 follow r9 and never sort before r2", () => {
    assert.deepEqual([...reconcile.REVISIONS], R11_REVISIONS);
    assert.equal(reconcile.REVISIONS.indexOf("r11"), reconcile.REVISIONS.indexOf("r10") + 1);
    assert.equal(reconcile.REVISIONS.indexOf("r11"), reconcile.REVISIONS.indexOf("r10") + 1);
    assert.equal(reconcile.REVISIONS.indexOf("r10"), reconcile.REVISIONS.indexOf("r9") + 1);
    for (const late of ["r10", "r11"]) assert.ok(reconcile.REVISIONS.indexOf(late) > reconcile.REVISIONS.indexOf("r2"), late);
    // Positive control: a plain string sort WOULD put r10 and r11 before r2, so the list must never be sorted.
    const stringSorted = [...R11_REVISIONS].sort();
    assert.ok(stringSorted.indexOf("r10") < stringSorted.indexOf("r2"));
    assert.ok(stringSorted.indexOf("r11") < stringSorted.indexOf("r2"));
    const source = readFileSync(SCRIPT, "utf8");
    assert.doesNotMatch(source, /REVISIONS\]?\)?\.sort\(/, "the helper never sorts the revision list");
    assert.doesNotMatch(source, /REVISIONS\.(toSorted|reverse)\(/);
    assert.doesNotMatch(source, /DISPOSITIONED_REVISIONS\]?\)?\.sort\(/);
    const refused = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", "/nonexistent/x.json", "--check-only"], { encoding: "utf8" });
    assert.equal(refused.status, 2);
    assert.match(refused.stderr, /expected one of v1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12\n/);
    const keys = Object.keys(reconcile.buildContract({ revision: "r11" })).filter((key) => /_contract$/.test(key));
    assert.deepEqual(keys, ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract", "r10_contract"]);
  });

  test("r6-r11 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7", "r8", "r9", "r10", "r11"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r11 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r11" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r11" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r11" }).accepted, false);
  });

  test("plan IDs build, sort and match: 253-99, 253-122, 253-125 and 253-135", () => {
    assert.equal(reconcile.planIdOf(125), "253-125");
    assert.equal(reconcile.planIdOf(135), "253-135");
    assert.deepEqual(["253-135", "253-125", "253-122", "253-99"].sort(reconcile.comparePlanIds), ["253-99", "253-122", "253-125", "253-135"]);
    assert.deepEqual(["135", "125", "122", "99"].sort(reconcile.comparePlanIds), ["99", "122", "125", "135"]);
    assert.deepEqual(reconcile.parsePlanFile("253-125-PLAN.md"), { id: "125", number: 125, kind: "PLAN" });
    assert.deepEqual(reconcile.parsePlanFile("253-135-SUMMARY.md"), { id: "135", number: 135, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-122-SUMMARY.md"), { id: "122", number: 122, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-99-PLAN.md"), { id: "99", number: 99, kind: "PLAN" });
    assert.equal(reconcile.parsePlanFile("253-1350-PLAN.md"), null);
    assert.deepEqual([...reconcile.R11_PLAN_IDS], ["125", "126", "127", "128", "129", "130", "131", "132", "133", "134", "135"]);
  });

  test("CLI --revision r11 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-132-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R11_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r11", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r11");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R11);
    assert.equal(contract.responsibilities.length, 52);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("123 and 124 are never-ran rows blocked by halted 253-122; earlier rows keep their reasons; every row carries the R11 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r11" });
    for (const id of R11_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-122"], id);
      assert.equal(row.never_ran_reason, R11_NEVER_RAN_122, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R11_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R11", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-114").never_ran_reason, R10_NEVER_RAN_113);
    assert.deepEqual(contract.responsibilities.find((r) => r.plan === "253-115").blocked_by, ["253-113"]);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-105").never_ran_reason, R9_NEVER_RAN_104);
    for (const row of contract.responsibilities) for (const owner of row.owners) assert.ok(!R11_FORBIDDEN_OWNERS.includes(owner.slice(4)), `${row.plan} owner ${owner}`);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-132 Task 2: R11 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R11_REMAP = { "120": ["120", "131"], "121": ["121", "132"], "122": ["133"], "123": ["134"], "124": ["132", "135"] };
const remapR11 = (owners) => [...new Set(owners.flatMap((owner) => R11_REMAP[owner] ?? [owner]))];
const R11_OWNERS = {
  ...Object.fromEntries(Object.entries(R10_OWNERS).map(([id, owners]) => [id, remapR11(owners)])),
  "123": ["134"],
  "124": ["132", "135"],
};
const R11_NATIVE = R10_NATIVE;
const R11_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "103", "112", "121", "132", "135"];
const R11_PLAN_IDS_T = ["125", "126", "127", "128", "129", "130", "131", "132", "133", "134", "135"];
// 253-121's receipts name this helper and its test, which plan 132 edits. They are held at the bytes of the
// last 253-121 commit that touched each file (3d73201b6), read with git, never invented.
const FROZEN_TOOLING_R11_121_COMMIT = "3d73201b6efbfcdb57d12acc005644e0e125ad60";
const FROZEN_TOOLING_R11_121 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "583f84ffb3c45e7319a09b89349e0f979a504d345dca6fb5917cda4f8d5239ed",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "2b79a502b4faa73062e02802e04da90030fe2f0910bb4a88437b7d8be48b7c1a",
};
const R11_SUMMARY_PIN_IDS = [...R10_SUMMARY_PIN_IDS, "121", "122", "125", "126", "127", "128", "129", "130", "131"];
// The R11 world: PLANs 01-135 and the real SUMMARYs through 131, built by the unchanged r8Fixture.
const r11Fixture = () => r8Fixture({ maxPlan: 135, maxSummary: 131 });
const preservationR11 = () => Object.fromEntries(readFileSync(join(REAL_PHASE_DIR, "253-LOAD-RECOVERY-PRESERVATION-R11.sha256"), "utf8")
  .split("\n").filter(Boolean).map((line) => { const [hash, path] = line.split(/\s+/); return [path, hash]; }));

describe("R11 reconciliation contract", () => {
  test("v1 and R2-R10 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"], [R7_CONTRACT_NAME, R7_CONTRACT_SHA, "r7"], [R8_CONTRACT_NAME, R8_CONTRACT_SHA, "r8"], [R9_CONTRACT_NAME, R9_CONTRACT_SHA, "r9"], [R10_CONTRACT_NAME, R10_CONTRACT_SHA, "r10"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
    const preserved = preservationR11();
    assert.equal(preserved[`${PHASE_DIR_REL}/${R10_CONTRACT_NAME}`], R10_CONTRACT_SHA, "PRESERVATION-R11 holds the R10 contract");
  });

  test("partitions PLANs 01-124 into 56 completed, 16 halted and 52 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r11" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r11");
    assert.equal(contract.revision, "r11");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R11_COMPLETED);
    assert.equal(contract.completed_plans.length, 56);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R11_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(16).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R11_UNSTARTED);
    assert.equal(contract.responsibilities.length, 52);
    assert.equal(contract.originals.length, 124);
    assert.equal(contract.originals.filter((o) => o.class === "halted").length, 16);
    assert.equal(contract.originals.find((o) => o.plan === "253-122").class, "halted");
    assert.equal(contract.originals.find((o) => o.plan === "253-121").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-116").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-124").class, "unstarted_blocked");
    assert.deepEqual(contract.originals.map((o) => o.plan), Array.from({ length: 124 }, (_, i) => reconcile.planIdOf(i + 1)));
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 124 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED, "97": R8_NEW_UNSTARTED, "104": R9_NEW_UNSTARTED, "113": R10_NEW_UNSTARTED, "122": R11_NEW_UNSTARTED };
    const reasons = { "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92, "97": R8_NEVER_RAN_97, "104": R9_NEVER_RAN_104, "113": R10_NEVER_RAN_113, "122": R11_NEVER_RAN_122 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
      }
    }
  });

  test("maps every responsibility to the R11 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r11" });
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners, R11_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R11_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    for (const row of Object.values(owners)) assert.equal(new Set(row).size, row.length, "no duplicate owners after the remap");
    assert.deepEqual(owners["10"], R11_NATIVE);
    assert.deepEqual(owners["14"], R11_COMPLETION);
    assert.deepEqual(owners["08"], ["42", "134"]);
    assert.deepEqual(owners["22"], ["91", "95", "102", "111", "120", "131"]);
    assert.deepEqual(owners["86"], ["133"]);
    assert.deepEqual(owners["93"], ["134"]);
    assert.deepEqual(owners["94"], ["96", "103", "112", "121", "132", "135"]);
    assert.deepEqual(owners["99"], ["103", "112", "121", "132", "135"]);
    assert.deepEqual(owners["106"], ["112", "121", "132", "135"]);
    assert.deepEqual(owners["114"], ["134"]);
    assert.deepEqual(owners["115"], ["121", "132", "135"]);
    assert.deepEqual(owners["123"], ["134"]);
    assert.deepEqual(owners["124"], ["132", "135"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["123"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["124"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["115"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R11_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R11_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "102", "111", "120", "131", "133"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-102", "253-111", "253-120", "253-131", "253-133"]);
    assert.deepEqual(contract.halted_proof_map["253-104"], ["253-107", "253-108", "253-110", "253-111", "253-120", "253-131", "253-133"]);
    assert.deepEqual(contract.halted_proof_map["253-113"], ["253-116", "253-117", "253-118", "253-119", "253-120", "253-131", "253-133"]);
    assert.deepEqual(contract.halted_proof_map["253-122"], ["253-125", "253-126", "253-127", "253-128", "253-129", "253-130", "253-131", "253-133"]);
    for (const list of Object.values(contract.halted_proof_map)) for (const owner of list) assert.ok(!R11_FORBIDDEN_OWNERS.includes(owner.slice(4)), `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
    // The -R11-PROBE records are real-shape fixture evidence only, never a completion link.
    const serialized = reconcile.serializeContract(contract);
    const linkKeys = new Set(contract.responsibilities.flatMap((r) => r.required_links));
    for (const key of linkKeys) assert.doesNotMatch(key, /PROBE/i, key);
    for (const row of contract.responsibilities) assert.doesNotMatch(JSON.stringify(row), /-R11-PROBE/, row.plan);
    assert.doesNotMatch(JSON.stringify(contract.application), /PROBE/i);
    assert.doesNotMatch(JSON.stringify(contract.completed_plans), /-R11-PROBE/);
    assert.doesNotMatch(JSON.stringify(contract.halted_proof_map), /PROBE/i);
    // ...and the contract names them, pinned, as fixtures only.
    const fixtures = contract.fixture_only_records;
    assert.match(fixtures.note, /253-127 probe window/);
    assert.match(fixtures.note, /real-shape fixture evidence only/);
    assert.match(fixtures.note, /never a completion link or acceptance evidence/);
    assert.deepEqual(fixtures.records.map((r) => r.path.split("/").pop()), ["ACTION-APPROVAL", "ALLOCATION", "BODIES", "EVIDENCE", "HTTP-LEDGER", "REQUESTS"].map((kind) => `253-LOAD-RECOVERY-PROBE-${kind}-R11-PROBE.json`));
    for (const r of fixtures.records) assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
    assert.ok(serialized.includes("fixture_only_records"));
  });

  test("pins every PLAN 01-135 in numeric order, the existing summaries, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r11" });
    assert.equal(contract.plan_pins.length, 135);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan), Array.from({ length: 135 }, (_, i) => reconcile.planIdOf(i + 1)));
    assert.deepEqual(contract.plan_pins.slice(-11).map((p) => p.plan.slice(4)), R11_PLAN_IDS_T);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.equal(R10_SUMMARY_PIN_IDS.length, 53);
    assert.equal(R11_SUMMARY_PIN_IDS.length, 62);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), R11_SUMMARY_PIN_IDS);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    const preserved = preservationR11();
    for (const pin of contract.summary_pins) if (preserved[pin.path]) assert.equal(pin.sha256, preserved[pin.path], `${pin.path} equals PRESERVATION-R11`);
    assert.deepEqual(contract.v1_contract, { path: `${PHASE_DIR_REL}/${reconcile.CONTRACT_NAME}`, sha256: V1_CONTRACT_SHA });
    assert.deepEqual(contract.r2_contract, { path: `${PHASE_DIR_REL}/${R2_CONTRACT_NAME_FOR_R3}`, sha256: R2_CONTRACT_SHA });
    assert.deepEqual(contract.r3_contract, { path: `${PHASE_DIR_REL}/${R3_CONTRACT_NAME}`, sha256: R3_CONTRACT_SHA });
    assert.deepEqual(contract.r4_contract, { path: `${PHASE_DIR_REL}/${R4_CONTRACT_NAME}`, sha256: R4_CONTRACT_SHA });
    assert.deepEqual(contract.r5_contract, { path: `${PHASE_DIR_REL}/${R5_CONTRACT_NAME}`, sha256: R5_CONTRACT_SHA });
    assert.deepEqual(contract.r6_contract, { path: `${PHASE_DIR_REL}/${R6_CONTRACT_NAME}`, sha256: R6_CONTRACT_SHA });
    assert.deepEqual(contract.r7_contract, { path: `${PHASE_DIR_REL}/${R7_CONTRACT_NAME}`, sha256: R7_CONTRACT_SHA });
    assert.deepEqual(contract.r8_contract, { path: `${PHASE_DIR_REL}/${R8_CONTRACT_NAME}`, sha256: R8_CONTRACT_SHA });
    assert.deepEqual(contract.r9_contract, { path: `${PHASE_DIR_REL}/${R9_CONTRACT_NAME}`, sha256: R9_CONTRACT_SHA });
    assert.deepEqual(contract.r10_contract, { path: `${PHASE_DIR_REL}/${R10_CONTRACT_NAME}`, sha256: R10_CONTRACT_SHA });
    assert.deepEqual(Object.keys(contract).filter((key) => /_contract$/.test(key)), ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract", "r10_contract"]);
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    const r10 = reconcile.buildContract({ revision: "r10" });
    assert.deepEqual(contract.sdk, r10.sdk);
    assert.deepEqual(contract.capture, r10.capture);
    assert.equal(contract.application.root_only, true);
    assert.equal(contract.application.write_ahead, true);
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-135");
    assert.equal(contract.application.targets, "only the fifty-two previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.equal(contract.application.then_run, r10.application.then_run);
    assert.deepEqual(contract.application.never, r10.application.never);
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
  });

  test("tooling receipts are frozen per plan: every R10 record as R10 holds it, 253-121 at its last commit, 253-122 with its eleven records", () => {
    const contract = reconcile.buildContract({ revision: "r11" });
    const r10 = reconcile.buildContract({ revision: "r10" });
    for (const plan of r10.completed_plans) assert.deepEqual(contract.completed_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R10 holds it`);
    for (const plan of r10.halted_plans) assert.deepEqual(contract.halted_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R10 holds it`);
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R8_96)) assert.equal(receipt("253-96", path), hash, `96 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R9_103)) assert.equal(receipt("253-103", path), hash, `103 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R10_112)) assert.equal(receipt("253-112", path), hash, `112 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R11_121)) {
      assert.equal(receipt("253-121", path), hash, `121 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `${FROZEN_TOOLING_R11_121_COMMIT}:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `121 ${path} equals the blob at commit 3d73201b6`);
      const log = spawnSync("git", ["-C", REPO, "log", "-1", "--format=%H", "--grep=(253-121)", "--", path], { encoding: "utf8" });
      assert.equal(log.stdout.trim(), FROZEN_TOOLING_R11_121_COMMIT, `3d73201b6 is the last 253-121 commit touching ${path}`);
      assert.notEqual(sha(readFileSync(join(REPO, path))), hash, `${path} has since been edited by plan 132 (the freeze is load-bearing)`);
    }
    assert.equal(receipt("253-121", `${PHASE_DIR_REL}/${R10_CONTRACT_NAME}`), R10_CONTRACT_SHA);
    assert.equal(contract.completed_plans.find((p) => p.plan === "253-121").receipts.length, 3);
    const preserved = preservationR11();
    const oneTwentyTwo = contract.halted_plans.find((p) => p.plan === "253-122");
    assert.equal(oneTwentyTwo.receipts.length, 11);
    assert.equal(oneTwentyTwo.missing_receipts, undefined);
    assert.equal(oneTwentyTwo.summary.status, "halted");
    assert.equal(oneTwentyTwo.summary.sha256, preserved[`${PHASE_DIR_REL}/253-122-SUMMARY.md`]);
    assert.ok(oneTwentyTwo.receipts.some((r) => r.path === `${PHASE_DIR_REL}/253-R10-CANARY-OPERATOR.sh`), "the R10 runner is a 253-122 receipt");
    for (const r of oneTwentyTwo.receipts) {
      assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
      assert.equal(r.sha256, preserved[r.path], `${r.path} is at its PRESERVATION-R11 bytes`);
    }
    for (const id of ["116", "117", "118", "119", "120"]) {
      const plan = contract.completed_plans.find((p) => p.plan === `253-${id}`);
      assert.ok(plan, id);
      for (const r of plan.receipts) assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
    }
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 125-135 and a halted or never-executed owner (positive controls: the same clone builds, a live owner passes)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-132-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r11" });
    assert.equal(built.plan_pins.length, 135);
    for (const id of ["133", "135", "128"]) {
      rmSync(join(root, PHASE_DIR_REL, `253-${id}-PLAN.md`));
      assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r11" }), new RegExp(`253-${id}`));
      git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-${id}-PLAN.md`);
      assert.equal(reconcile.buildContract({ repoRoot: root, revision: "r11" }).plan_pins.length, 135);
    }
    const phaseDir = join(root, PHASE_DIR_REL);
    for (const owner of ["132", "135", "131", "133", "120", "121", "253-134"]) assert.doesNotThrow(() => reconcile.assertProofOwnerR11(phaseDir, owner), owner);
    for (const owner of ["122", "123", "124", "113", "114", "115", "104", "92", "253-122"]) assert.throws(() => reconcile.assertProofOwnerR11(phaseDir, owner), /halted or never-executed/, owner);
    rmSync(join(phaseDir, "253-134-PLAN.md"));
    assert.throws(() => reconcile.assertProofOwnerR11(phaseDir, "134"), /253-134 is missing/);
  });

  test("CLI --revision r11 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r10 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-132-contract-"));
    cleanup.push(dir);
    const target = join(dir, R11_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r11" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r11", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME], ["r7", R7_CONTRACT_NAME], ["r8", R8_CONTRACT_NAME], ["r9", R9_CONTRACT_NAME], ["r10", R10_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R11 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R11 successors", () => {
    const { root } = r11Fixture();
    const contract = reconcile.buildContract({ revision: "r11" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 52);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /\nstatus: superseded\n/);
      assert.match(entry.content, /\nexecution_performed: false\n/);
      assert.match(entry.content, /\noriginal_status: blocked\n/);
      assert.match(entry.content, /\nphase_verification_status: not_started\n/);
      assert.doesNotMatch(entry.content, /\nstatus: blocked\n/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
      assert.doesNotMatch(entry.content, /-R11-PROBE/);
    }
    const oneTwentyThree = bundle.entries.find((e) => e.plan === "253-123");
    assert.match(oneTwentyThree.content, /never ran because its dependency 253-122 halted at the first failure scenario/);
    assert.match(oneTwentyThree.content, /results-receiver\.actions\.githubusercontent\.com/);
    assert.match(oneTwentyThree.content, /redirect_rejected/);
    assert.match(oneTwentyThree.content, /Its R11 successor is 253-134\./);
    assert.match(oneTwentyThree.content, /original_blocked_by: \["253-122"\]/);
    const oneTwentyFour = bundle.entries.find((e) => e.plan === "253-124");
    assert.match(oneTwentyFour.content, /Its R11 successor is 253-132, 253-135\./);
    assert.match(oneTwentyFour.content, /link: load_target_disposition/);
    const oneFourteen = bundle.entries.find((e) => e.plan === "253-114");
    assert.match(oneFourteen.content, /never ran because its dependency 253-113 halted at the full-pass verifier/);
    assert.match(oneFourteen.content, /Its R11 successor is 253-134\./);
  });
});

describe("R11 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("123 and 124 stay incomplete and blocked behind halted 253-122; 253-132 is the next explicitly dispatched plan", () => {
    const { root } = r11Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of R11_PLAN_IDS_T) assert.ok(by[`253-${id}`], `the SDK lists plan 253-${id}`);
    assert.equal(index.plans.length, 135);
    for (const id of ["253-123", "253-124"]) {
      assert.ok(index.incomplete.includes(id), `${id} incomplete`);
      assert.equal(by[id].has_summary, false, id);
      assert.ok(by[id].blocked_by.includes("253-122"), `${id} blocked behind 253-122`);
      assert.equal(by[id].halted, false, id);
    }
    assert.equal(by["253-122"].halted, true);
    assert.equal(by["253-122"].has_summary, true);
    for (const id of ["116", "117", "118", "119", "120", "121", "125", "126", "127", "128", "129", "130", "131"]) assert.equal(by[`253-${id}`].has_summary, true, id);
    // Measured against the installed SDK 1.16.0: blocked_by propagates through depends_on past summarized
    // plans. 125 depends on halted 122, so 125-135 inherit [253-122, 253-84, 253-92] and `runnable` is empty.
    // 253-132 is the next plan with no summary whose own dependency (131) is summarized; it is dispatched
    // explicitly.
    assert.deepEqual(by["253-132"].depends_on, ["253-131"]);
    assert.equal(by["253-133"].wave, by["253-132"].wave + 1);
    for (const id of ["253-132", "253-133", "253-134", "253-135"]) {
      assert.equal(by[id].has_summary, false, id);
      assert.equal(by[id].halted, false, id);
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-122", "253-84", "253-92"], `${id} inherits the 122, 84 and 92 blocks`);
    }
    assert.deepEqual(index.runnable, []);
    assert.deepEqual([...index.incomplete].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R11_UNSTARTED, "132", "133", "134", "135"]);
    const contract = reconcile.buildContract({ revision: "r11" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R11_UNSTARTED);
    assert.deepEqual([...report.any_unsummarized].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R11_UNSTARTED, "132", "133", "134", "135"]);
  });

  test("after simulated R11 dispositions and 132-135 summaries nothing is incomplete, sixteen plans are halted and nothing reports blocked", () => {
    const { root, dir } = r11Fixture();
    for (const id of ["132", "133", "134", "135"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r11" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 52);
    for (const entry of bundle.entries) for (const owner of R11_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 52);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)).sort(byNumber9), [...R11_HALTED].sort(byNumber9));
    assert.equal(index.plans.filter((p) => p.halted).length, 16);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 135);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R11_NEW_UNSTARTED, ...R10_NEW_UNSTARTED, ...R9_NEW_UNSTARTED, ...R8_NEW_UNSTARTED, ...R7_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r11Fixture();
    for (const id of ["132", "133", "134", "135"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r11" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-134-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-134/);
    assert.equal(existsSync(join(dir, "253-123-SUMMARY.md")), false);
    writeFileSync(join(dir, "253-134-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-133-PLAN.md"), `${readFileSync(join(dir, "253-133-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-133|differs/);
    assert.equal(existsSync(join(dir, "253-123-SUMMARY.md")), false);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-142: R12 revision (253-134 halted in the normal family: draft PR #337 got no pull_request run because
// its frozen candidate 2b239a98 sat on the stale server parent 84ebcea60 and conflicted with current main, so
// 253-135 can never run).
// Task 1: partition, dispositioned gating, numeric revision order, CLI and plan IDs up to 253-145.
// ---------------------------------------------------------------------------------------------
const R11_CONTRACT_SHA = "921c3500f99299f2f84478a047c3c5dbf53d9d31064bd9d0ce80a4cd32f1c84c";
const R12_CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R12.json";
const R12_NEW_UNSTARTED = ["135"];
const R12_UNSTARTED = [...R11_UNSTARTED, ...R12_NEW_UNSTARTED].sort(byNumber9);
const R12_HALTED = [...R11_HALTED, "134"];
const R12_COMPLETED = [...R11_COMPLETED, "125", "126", "127", "128", "129", "130", "131", "132", "133"].sort(byNumber9);
const R12_NEVER_RAN_134 = "dependency 253-134 halted: normal draft PR #337 got no pull_request run; its frozen candidate 2b239a98 sat on the stale server parent 84ebcea60 and conflicted with current main, and GitHub creates no pull_request run for a conflicting PR";
const R12_FORBIDDEN_OWNERS = [...R11_FORBIDDEN_OWNERS, "134", "135"];
const R12_REVISIONS = ["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"];

describe("R12 revision skeleton: partition, dispositioned gating, numeric revision order, CLI and plan IDs", () => {
  test("R12 sets partition PLANs 01-135 into 65 completed, 17 halted and 53 never-executed", () => {
    assert.deepEqual([...reconcile.REVISIONS], R12_REVISIONS);
    assert.deepEqual([...reconcile.COMPLETED_IDS_R12], R12_COMPLETED);
    assert.deepEqual([...reconcile.HALTED_IDS_R12], R12_HALTED);
    assert.deepEqual([...reconcile.NEVER_RAN_IDS_R12], R12_NEW_UNSTARTED);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R12], R12_UNSTARTED);
    assert.equal(reconcile.COMPLETED_IDS_R12.length, 65);
    assert.equal(reconcile.HALTED_IDS_R12.length, 17);
    assert.equal(reconcile.UNSTARTED_IDS_R12.length, 53);
    const all = [...reconcile.COMPLETED_IDS_R12, ...reconcile.HALTED_IDS_R12, ...reconcile.UNSTARTED_IDS_R12].sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 135 }, (_, i) => String(i + 1).padStart(2, "0")));
    assert.equal(new Set(all).size, 135, "no id is in two classes");
    assert.deepEqual(R12_HALTED, ["02", "07", "09", "12", "16", "27", "40", "51", "63", "73", "84", "92", "97", "104", "113", "122", "134"]);
    assert.equal(reconcile.NEVER_RAN_REASON_R12, R12_NEVER_RAN_134);
    assert.equal(reconcile.CONTRACT_NAME_R12, R12_CONTRACT_NAME);
    assert.equal(reconcile.CONTRACT_SCHEMA_R12, "sigra.phase253.load-recovery-reconciliation-contract/r12");
    assert.equal(reconcile.contractPathFor("r12"), join(HERE, R12_CONTRACT_NAME));
    assert.equal(reconcile.contractPathFor("r11"), join(HERE, R11_CONTRACT_NAME));
    assert.throws(() => reconcile.contractPathFor("r13"), /unknown revision r13/);
    assert.throws(() => reconcile.buildContract({ revision: "r13" }), /unknown revision r13/);
  });

  test("revisions are ordered numerically everywhere: r10, r11 and r12 follow r9 and never sort before r2", () => {
    assert.deepEqual([...reconcile.REVISIONS], R12_REVISIONS);
    assert.equal(reconcile.REVISIONS.indexOf("r12"), reconcile.REVISIONS.length - 1);
    assert.equal(reconcile.REVISIONS.indexOf("r12"), reconcile.REVISIONS.indexOf("r11") + 1);
    assert.equal(reconcile.REVISIONS.indexOf("r11"), reconcile.REVISIONS.indexOf("r10") + 1);
    assert.equal(reconcile.REVISIONS.indexOf("r10"), reconcile.REVISIONS.indexOf("r9") + 1);
    for (const late of ["r10", "r11", "r12"]) assert.ok(reconcile.REVISIONS.indexOf(late) > reconcile.REVISIONS.indexOf("r2"), late);
    // Positive control: a plain string sort WOULD put r10, r11 and r12 before r2, so the list must never be sorted.
    const stringSorted = [...R12_REVISIONS].sort();
    for (const late of ["r10", "r11", "r12"]) assert.ok(stringSorted.indexOf(late) < stringSorted.indexOf("r2"), late);
    const source = readFileSync(SCRIPT, "utf8");
    assert.doesNotMatch(source, /REVISIONS\]?\)?\.sort\(/, "the helper never sorts the revision list");
    assert.doesNotMatch(source, /REVISIONS\.(toSorted|reverse)\(/);
    assert.doesNotMatch(source, /DISPOSITIONED_REVISIONS\]?\)?\.sort\(/);
    const refused = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", "/nonexistent/x.json", "--check-only"], { encoding: "utf8" });
    assert.equal(refused.status, 2);
    assert.match(refused.stderr, /expected one of v1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12\n/);
    const keys = Object.keys(reconcile.buildContract({ revision: "r12" })).filter((key) => /_contract$/.test(key));
    assert.deepEqual(keys, ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract", "r10_contract", "r11_contract"]);
  });

  test("r6-r12 call the verifier with --require-dispositioned; v1-r5 keep --require-accepted", () => {
    for (const revision of ["v1", "r2", "r3", "r4", "r5"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-accepted"), revision);
      assert.ok(!argv.includes("--require-dispositioned"), revision);
    }
    for (const revision of ["r6", "r7", "r8", "r9", "r10", "r11", "r12"]) {
      const argv = reconcile.completionArgv(revision, "/x/completion.json");
      assert.ok(argv.includes("--require-dispositioned"), revision);
      assert.ok(!argv.includes("--require-accepted"), revision);
    }
  });

  test("the r12 predicate accepts only the dispositioned shape", () => {
    const { root } = r6Fixture();
    const completion = dispositionCompletionFixture(root);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: dispositionedVerifier, revision: "r12" }).accepted, true);
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: acceptedVerifier, revision: "r12" }).accepted, false);
    const mutated = () => { const out = dispositionedVerifier(); const body = JSON.parse(out.stdout); body.requirements["CIREL-01"] = "accepted"; return { ...out, stdout: JSON.stringify(body) }; };
    assert.equal(reconcile.evaluateCompletion({ completionPath: completion, verifier: mutated, revision: "r12" }).accepted, false);
  });

  test("plan IDs build, sort and match: 253-99, 253-134, 253-136 and 253-145", () => {
    assert.equal(reconcile.planIdOf(136), "253-136");
    assert.equal(reconcile.planIdOf(145), "253-145");
    assert.deepEqual(["253-145", "253-136", "253-134", "253-99"].sort(reconcile.comparePlanIds), ["253-99", "253-134", "253-136", "253-145"]);
    assert.deepEqual(["145", "136", "134", "99"].sort(reconcile.comparePlanIds), ["99", "134", "136", "145"]);
    assert.deepEqual(reconcile.parsePlanFile("253-136-PLAN.md"), { id: "136", number: 136, kind: "PLAN" });
    assert.deepEqual(reconcile.parsePlanFile("253-145-SUMMARY.md"), { id: "145", number: 145, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-134-SUMMARY.md"), { id: "134", number: 134, kind: "SUMMARY" });
    assert.deepEqual(reconcile.parsePlanFile("253-99-PLAN.md"), { id: "99", number: 99, kind: "PLAN" });
    assert.equal(reconcile.parsePlanFile("253-1450-PLAN.md"), null);
    assert.deepEqual([...reconcile.R12_PLAN_IDS], ["136", "137", "138", "139", "140", "141", "142", "143", "144", "145"]);
  });

  test("CLI --revision r12 --prepare-contract writes, --check-only matches on a copy, an unknown revision is refused", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-142-skeleton-"));
    cleanup.push(dir);
    const target = join(dir, R12_CONTRACT_NAME);
    const run = (...args) => spawnSync(process.execPath, [SCRIPT, "--revision", "r12", "--prepare-contract", "--output", target, ...args], { encoding: "utf8" });
    assert.notEqual(run("--check-only").status, 0);
    assert.equal(existsSync(target), false);
    const written = run();
    assert.equal(written.status, 0, written.stderr);
    const ok = run("--check-only");
    assert.equal(ok.status, 0, ok.stderr);
    const contract = JSON.parse(readFileSync(target, "utf8"));
    assert.equal(contract.revision, "r12");
    assert.equal(contract.schema, reconcile.CONTRACT_SCHEMA_R12);
    assert.equal(contract.responsibilities.length, 53);
    const unknown = spawnSync(process.execPath, [SCRIPT, "--revision", "r13", "--prepare-contract", "--output", target, "--check-only"], { encoding: "utf8" });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /unknown revision r13/);
  });

  test("135 is a never-ran row blocked by halted 253-134; earlier rows keep their reasons; every row carries the R12 successor revision", () => {
    const contract = reconcile.buildContract({ revision: "r12" });
    for (const id of R12_NEW_UNSTARTED) {
      const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
      assert.deepEqual(row.blocked_by, ["253-134"], id);
      assert.equal(row.never_ran_reason, R12_NEVER_RAN_134, id);
    }
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R12_UNSTARTED);
    for (const row of contract.responsibilities) assert.equal(row.successor_revision, "R12", row.plan);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-08").never_ran_reason, undefined);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-123").never_ran_reason, R11_NEVER_RAN_122);
    assert.deepEqual(contract.responsibilities.find((r) => r.plan === "253-124").blocked_by, ["253-122"]);
    assert.equal(contract.responsibilities.find((r) => r.plan === "253-114").never_ran_reason, R10_NEVER_RAN_113);
    for (const row of contract.responsibilities) for (const owner of row.owners) assert.ok(!R12_FORBIDDEN_OWNERS.includes(owner.slice(4)), `${row.plan} owner ${owner}`);
  });
});

// ---------------------------------------------------------------------------------------------
// 253-142 Task 2: R12 mapping, frozen receipts, pins, rendering and the real-SDK pairing proof
// ---------------------------------------------------------------------------------------------
const R12_REMAP = { "131": ["131", "141"], "132": ["132", "142"], "133": ["143"], "134": ["144"], "135": ["142", "145"] };
const remapR12 = (owners) => [...new Set(owners.flatMap((owner) => R12_REMAP[owner] ?? [owner]))];
const R12_OWNERS = {
  ...Object.fromEntries(Object.entries(R11_OWNERS).map(([id, owners]) => [id, remapR12(owners)])),
  "135": ["142", "145"],
};
const R12_NATIVE = R11_NATIVE;
const R12_COMPLETION = ["43", "50", "61", "71", "81", "90", "96", "103", "112", "121", "132", "142", "145"];
const R12_PLAN_IDS_T = ["136", "137", "138", "139", "140", "141", "142", "143", "144", "145"];
// 253-132's receipts name this helper and its test, which plan 142 edits. They are held at the bytes of the
// last 253-132 commit that touched each file (e5ce3d578), read with git, never invented.
const FROZEN_TOOLING_R12_132_COMMIT = "e5ce3d5780c30036f55651a5ee59a4fabd8047fd";
const FROZEN_TOOLING_R12_132 = {
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "b932d5392ec1a03909b22bd336f9064f9a5af2dc264bbae5c82dbccc40b74a62",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "e17c86b61b638c9792437f46530791cb498559968b004fde0e5b9eef29d28acc",
};
const R12_SUMMARY_PIN_IDS = [...R11_SUMMARY_PIN_IDS, "132", "133", "134", "136", "137", "138", "139", "140", "141"];
// The 253-133 R11 canary records: they proved R11 candidate 2b239a98 only.
const R12_R11_CANARY_RECORDS = [
  "253-LOAD-RECOVERY-CANARY-ACTION-APPROVAL-R11.json", "253-LOAD-RECOVERY-CANARY-ALLOCATION-R11.json", "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-check-runs.json",
  "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-effective-rules.json", "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-legacy-protection.json",
  "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-rate.json", "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11-PREFLIGHT-registered-workflow.json",
  "253-LOAD-RECOVERY-CANARY-EVIDENCE-R11.json", "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R11.json", "253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R11.json", "253-R11-CANARY-OPERATOR.sh",
];
const R12_R11_CANARY_PATTERN = /CANARY-[A-Z-]*R11|R11-CANARY-OPERATOR/;
// The R12 world: PLANs 01-145 and the real SUMMARYs through 141, built by the unchanged r8Fixture.
const r12Fixture = () => r8Fixture({ maxPlan: 145, maxSummary: 141 });
const preservationR12 = () => Object.fromEntries(readFileSync(join(REAL_PHASE_DIR, "253-LOAD-RECOVERY-PRESERVATION-R12.sha256"), "utf8")
  .split("\n").filter(Boolean).map((line) => { const [hash, path] = line.split(/\s+/); return [path, hash]; }));

describe("R12 reconciliation contract", () => {
  test("v1 and R2-R11 contracts and their default code paths stay byte-identical", () => {
    for (const [name, expected, revision] of [[reconcile.CONTRACT_NAME, V1_CONTRACT_SHA, "v1"], [R2_CONTRACT_NAME_FOR_R3, R2_CONTRACT_SHA, "r2"], [R3_CONTRACT_NAME, R3_CONTRACT_SHA, "r3"], [R4_CONTRACT_NAME, R4_CONTRACT_SHA, "r4"], [R5_CONTRACT_NAME, R5_CONTRACT_SHA, "r5"], [R6_CONTRACT_NAME, R6_CONTRACT_SHA, "r6"], [R7_CONTRACT_NAME, R7_CONTRACT_SHA, "r7"], [R8_CONTRACT_NAME, R8_CONTRACT_SHA, "r8"], [R9_CONTRACT_NAME, R9_CONTRACT_SHA, "r9"], [R10_CONTRACT_NAME, R10_CONTRACT_SHA, "r10"], [R11_CONTRACT_NAME, R11_CONTRACT_SHA, "r11"]]) {
      const text = readFileSync(join(REAL_PHASE_DIR, name), "utf8");
      assert.equal(sha(text), expected, name);
      assert.equal(reconcile.serializeContract(reconcile.buildContract({ revision })), text, `${revision} regenerates byte-identically`);
    }
    const preserved = preservationR12();
    assert.equal(preserved[`${PHASE_DIR_REL}/${R11_CONTRACT_NAME}`], R11_CONTRACT_SHA, "PRESERVATION-R12 holds the R11 contract");
  });

  test("partitions PLANs 01-135 into 65 completed, 17 halted and 53 never-executed", () => {
    const contract = reconcile.buildContract({ revision: "r12" });
    assert.equal(contract.schema, "sigra.phase253.load-recovery-reconciliation-contract/r12");
    assert.equal(contract.revision, "r12");
    assert.deepEqual(contract.completed_plans.map((p) => p.plan.slice(4)), R12_COMPLETED);
    assert.equal(contract.completed_plans.length, 65);
    assert.deepEqual(contract.halted_plans.map((p) => p.plan.slice(4)), R12_HALTED);
    assert.deepEqual(contract.halted_plans.map((p) => p.summary.status), Array(17).fill("halted"));
    assert.deepEqual(contract.responsibilities.map((r) => r.plan.slice(4)), R12_UNSTARTED);
    assert.equal(contract.responsibilities.length, 53);
    assert.equal(contract.originals.length, 135);
    assert.equal(contract.originals.filter((o) => o.class === "halted").length, 17);
    assert.equal(contract.originals.find((o) => o.plan === "253-134").class, "halted");
    assert.equal(contract.originals.find((o) => o.plan === "253-133").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-125").class, "completed");
    assert.equal(contract.originals.find((o) => o.plan === "253-135").class, "unstarted_blocked");
    assert.deepEqual(contract.originals.map((o) => o.plan), Array.from({ length: 135 }, (_, i) => reconcile.planIdOf(i + 1)));
    const all = [...contract.completed_plans, ...contract.halted_plans, ...contract.responsibilities].map((p) => p.plan.slice(4)).sort(byNumber9);
    assert.deepEqual(all, Array.from({ length: 135 }, (_, i) => String(i + 1).padStart(2, "0")));
    const blocked = { "51": R3_NEW_UNSTARTED, "63": R4_NEW_UNSTARTED, "73": R5_NEW_UNSTARTED, "84": R6_NEW_UNSTARTED, "92": R7_NEW_UNSTARTED, "97": R8_NEW_UNSTARTED, "104": R9_NEW_UNSTARTED, "113": R10_NEW_UNSTARTED, "122": R11_NEW_UNSTARTED, "134": R12_NEW_UNSTARTED };
    const reasons = { "51": R3_NEVER_RAN_51, "63": R4_NEVER_RAN_63, "73": R5_NEVER_RAN_73, "84": R6_NEVER_RAN_84, "92": R7_NEVER_RAN_92, "97": R8_NEVER_RAN_97, "104": R9_NEVER_RAN_104, "113": R10_NEVER_RAN_113, "122": R11_NEVER_RAN_122, "134": R12_NEVER_RAN_134 };
    for (const [halted, list] of Object.entries(blocked)) {
      for (const id of list) {
        const row = contract.responsibilities.find((r) => r.plan === `253-${id}`);
        assert.deepEqual(row.blocked_by, [`253-${halted}`], `${row.plan} blocked_by`);
        assert.equal(row.never_ran_reason, reasons[halted]);
      }
    }
  });

  test("maps every responsibility to the R12 proof owners and never to a halted or never-executed plan", () => {
    const contract = reconcile.buildContract({ revision: "r12" });
    const owners = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.owners.map((o) => o.slice(4))]));
    assert.deepEqual(owners, R12_OWNERS);
    const used = new Set(contract.responsibilities.flatMap((r) => r.owners.map((o) => o.slice(4))));
    for (const forbidden of R12_FORBIDDEN_OWNERS) assert.ok(!used.has(forbidden), `owner ${forbidden} must not be used`);
    for (const owner of used) assert.ok(existsSync(join(REAL_PHASE_DIR, `253-${owner}-PLAN.md`)), `owner ${owner} plan exists`);
    for (const row of Object.values(owners)) assert.equal(new Set(row).size, row.length, "no duplicate owners after the remap");
    for (const row of Object.values(owners)) for (const id of ["133", "134", "135"]) assert.ok(!row.includes(id), `no R12 owner is ${id}`);
    assert.deepEqual(owners["10"], R12_NATIVE);
    assert.deepEqual(owners["14"], R12_COMPLETION);
    assert.deepEqual(owners["08"], ["42", "144"]);
    assert.deepEqual(owners["22"], ["91", "95", "102", "111", "120", "131", "141"]);
    assert.deepEqual(owners["86"], ["143"]);
    assert.deepEqual(owners["93"], ["144"]);
    assert.deepEqual(owners["94"], ["96", "103", "112", "121", "132", "142", "145"]);
    assert.deepEqual(owners["106"], ["112", "121", "132", "142", "145"]);
    assert.deepEqual(owners["115"], ["121", "132", "142", "145"]);
    assert.deepEqual(owners["123"], ["144"]);
    assert.deepEqual(owners["124"], ["132", "142", "145"]);
    assert.deepEqual(owners["135"], ["142", "145"]);
    const links = Object.fromEntries(contract.responsibilities.map((r) => [r.plan.slice(4), r.required_links]));
    assert.deepEqual(links["135"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["124"], [...LINK_KEYS, "load_target_disposition"]);
    assert.deepEqual(links["123"], ["pr_normal", "pr_docs_only"]);
    assert.deepEqual(links["86"], ["canary"]);
    assert.deepEqual(Object.keys(contract.halted_proof_map), R12_HALTED.map((id) => `253-${id}`));
    for (const id of ["02", "09", "16", "27"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), R12_NATIVE);
    for (const id of ["07", "12"]) assert.deepEqual(contract.halted_proof_map[`253-${id}`].map((o) => o.slice(4)), ["18", "19", "20", "42", "91", "95", "102", "111", "120", "131", "141", "143"]);
    assert.deepEqual(contract.halted_proof_map["253-84"], ["253-89", "253-90"]);
    assert.deepEqual(contract.halted_proof_map["253-92"], ["253-95", "253-102", "253-111", "253-120", "253-131", "253-141", "253-143"]);
    assert.deepEqual(contract.halted_proof_map["253-104"], ["253-107", "253-108", "253-110", "253-111", "253-120", "253-131", "253-141", "253-143"]);
    assert.deepEqual(contract.halted_proof_map["253-113"], ["253-116", "253-117", "253-118", "253-119", "253-120", "253-131", "253-141", "253-143"]);
    assert.deepEqual(contract.halted_proof_map["253-122"], ["253-125", "253-126", "253-127", "253-128", "253-129", "253-130", "253-131", "253-141", "253-143"]);
    assert.deepEqual(contract.halted_proof_map["253-134"], ["253-136", "253-137", "253-138", "253-139", "253-140", "253-141", "253-143", "253-144"]);
    for (const list of Object.values(contract.halted_proof_map)) for (const owner of list) assert.ok(!R12_FORBIDDEN_OWNERS.includes(owner.slice(4)) && owner !== "253-133", `halted proof owner ${owner}`);
    for (const responsibility of contract.responsibilities) {
      assert.equal(responsibility.disposition_path, `${PHASE_DIR_REL}/${responsibility.plan}-SUMMARY.md`);
      assert.deepEqual(responsibility.disposition, { status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });
    }
    // The R11 canary records are superseded evidence for the R11 candidate only, never an R12 completion link.
    const linkKeys = new Set(contract.responsibilities.flatMap((r) => r.required_links));
    for (const key of linkKeys) assert.doesNotMatch(key, R12_R11_CANARY_PATTERN, key);
    for (const row of contract.responsibilities) assert.doesNotMatch(JSON.stringify(row), R12_R11_CANARY_PATTERN, row.plan);
    assert.doesNotMatch(JSON.stringify(contract.application), R12_R11_CANARY_PATTERN);
    assert.doesNotMatch(JSON.stringify(contract.halted_proof_map), R12_R11_CANARY_PATTERN);
    const superseded = contract.superseded_evidence_records;
    assert.match(superseded.note, /253-133 R11 canary records/);
    assert.match(superseded.note, /R11 candidate 2b239a98 only/);
    assert.match(superseded.note, /never an R12 completion link or acceptance evidence/);
    assert.deepEqual(superseded.records.map((r) => r.path.split("/").pop()), R12_R11_CANARY_RECORDS);
    const preserved = preservationR12();
    for (const r of superseded.records) {
      assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
      assert.equal(r.sha256, preserved[r.path], `${r.path} is at its PRESERVATION-R12 bytes`);
    }
    // The R11 fixture-only probe records stay fixture-only.
    assert.deepEqual(contract.fixture_only_records, reconcile.buildContract({ revision: "r11" }).fixture_only_records);
    for (const row of contract.responsibilities) assert.doesNotMatch(JSON.stringify(row), /-R11-PROBE/, row.plan);
  });

  test("pins every PLAN 01-145 in numeric order, the existing summaries, the earlier contracts, the SDK and the application block", () => {
    const contract = reconcile.buildContract({ revision: "r12" });
    assert.equal(contract.plan_pins.length, 145);
    assert.deepEqual(contract.plan_pins.map((p) => p.plan), Array.from({ length: 145 }, (_, i) => reconcile.planIdOf(i + 1)));
    assert.deepEqual(contract.plan_pins.slice(-10).map((p) => p.plan.slice(4)), R12_PLAN_IDS_T);
    for (const pin of contract.plan_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    assert.equal(R11_SUMMARY_PIN_IDS.length, 62);
    assert.equal(R12_SUMMARY_PIN_IDS.length, 71);
    assert.deepEqual(contract.summary_pins.map((p) => p.plan.slice(4)), R12_SUMMARY_PIN_IDS);
    for (const pin of contract.summary_pins) assert.equal(pin.sha256, sha(readFileSync(join(REPO, pin.path))), pin.path);
    const preserved = preservationR12();
    for (const pin of contract.summary_pins) if (preserved[pin.path]) assert.equal(pin.sha256, preserved[pin.path], `${pin.path} equals PRESERVATION-R12`);
    const r11 = reconcile.buildContract({ revision: "r11" });
    for (const key of ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract", "r10_contract"]) assert.deepEqual(contract[key], r11[key], key);
    assert.deepEqual(contract.r10_contract, { path: `${PHASE_DIR_REL}/${R10_CONTRACT_NAME}`, sha256: R10_CONTRACT_SHA });
    assert.deepEqual(contract.r11_contract, { path: `${PHASE_DIR_REL}/${R11_CONTRACT_NAME}`, sha256: R11_CONTRACT_SHA });
    assert.deepEqual(Object.keys(contract).filter((key) => /_contract$/.test(key)), ["v1_contract", "r2_contract", "r3_contract", "r4_contract", "r5_contract", "r6_contract", "r7_contract", "r8_contract", "r9_contract", "r10_contract", "r11_contract"]);
    assert.equal(contract.sdk.version, "1.16.0");
    assert.equal(contract.sdk.files.length, 7);
    assert.deepEqual(contract.sdk, r11.sdk);
    assert.deepEqual(contract.capture, r11.capture);
    assert.equal(contract.application.root_only, true);
    assert.equal(contract.application.write_ahead, true);
    assert.equal(contract.application.accepted_only_predicate, "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned");
    assert.equal(contract.application.bundle_requires_final_summary_of, "253-145");
    assert.equal(contract.application.targets, "only the fifty-three previously nonexistent SUMMARY paths; existing files are never overwritten");
    assert.equal(contract.application.then_run, r11.application.then_run);
    assert.deepEqual(contract.application.never, r11.application.never);
    assert.ok(contract.application.never.includes("reporting CIREL-01 as accepted"));
  });

  test("tooling receipts are frozen per plan: every R11 record as R11 holds it, 253-132 at its last commit, 253-133 and 253-134 at PRESERVATION-R12 bytes", () => {
    const contract = reconcile.buildContract({ revision: "r12" });
    const r11 = reconcile.buildContract({ revision: "r11" });
    for (const plan of r11.completed_plans) assert.deepEqual(contract.completed_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R11 holds it`);
    for (const plan of r11.halted_plans) assert.deepEqual(contract.halted_plans.find((p) => p.plan === plan.plan), plan, `${plan.plan} held as R11 holds it`);
    const receipt = (plan, path) => contract.completed_plans.find((p) => p.plan === plan).receipts.find((r) => r.path === path).sha256;
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R8_96)) assert.equal(receipt("253-96", path), hash, `96 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R9_103)) assert.equal(receipt("253-103", path), hash, `103 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R10_112)) assert.equal(receipt("253-112", path), hash, `112 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R11_121)) assert.equal(receipt("253-121", path), hash, `121 ${path}`);
    for (const [path, hash] of Object.entries(FROZEN_TOOLING_R12_132)) {
      assert.equal(receipt("253-132", path), hash, `132 ${path}`);
      const atCommit = spawnSync("git", ["-C", REPO, "show", `${FROZEN_TOOLING_R12_132_COMMIT}:${path}`], { maxBuffer: 64 * 1024 * 1024 });
      assert.equal(atCommit.status, 0);
      assert.equal(sha(atCommit.stdout), hash, `132 ${path} equals the blob at commit e5ce3d578`);
      const log = spawnSync("git", ["-C", REPO, "log", "-1", "--format=%H", "--grep=(253-132)", "--", path], { encoding: "utf8" });
      assert.equal(log.stdout.trim(), FROZEN_TOOLING_R12_132_COMMIT, `e5ce3d578 is the last 253-132 commit touching ${path}`);
      assert.notEqual(sha(readFileSync(join(REPO, path))), hash, `${path} has since been edited by plan 142 (the freeze is load-bearing)`);
    }
    assert.equal(receipt("253-132", `${PHASE_DIR_REL}/${R11_CONTRACT_NAME}`), R11_CONTRACT_SHA);
    assert.equal(contract.completed_plans.find((p) => p.plan === "253-132").receipts.length, 3);
    const preserved = preservationR12();
    const oneThirtyThree = contract.completed_plans.find((p) => p.plan === "253-133");
    assert.equal(oneThirtyThree.summary.status, "complete");
    assert.equal(oneThirtyThree.summary.sha256, preserved[`${PHASE_DIR_REL}/253-133-SUMMARY.md`]);
    for (const name of R12_R11_CANARY_RECORDS) {
      const r = oneThirtyThree.receipts.find((x) => x.path === `${PHASE_DIR_REL}/${name}`);
      assert.ok(r, name);
      assert.equal(r.sha256, preserved[r.path], `${r.path} is at its PRESERVATION-R12 bytes`);
    }
    const oneThirtyFour = contract.halted_plans.find((p) => p.plan === "253-134");
    assert.equal(oneThirtyFour.receipts.length, 6);
    assert.equal(oneThirtyFour.missing_receipts, undefined);
    assert.equal(oneThirtyFour.summary.status, "halted");
    assert.equal(oneThirtyFour.summary.sha256, preserved[`${PHASE_DIR_REL}/253-134-SUMMARY.md`]);
    assert.deepEqual(oneThirtyFour.receipts.map((r) => r.path.split("/").pop()).sort(), ["253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R11.json", "253-LOAD-RECOVERY-PR-ALLOCATION-R11.json", "253-LOAD-RECOVERY-PR-FREEZE-R11.json", "253-LOAD-RECOVERY-PR-HTTP-LEDGER-R11.json", "253-LOAD-RECOVERY-PR-NORMAL-EVIDENCE-R11.json", "253-R11-PR-OPERATOR.sh"]);
    for (const r of oneThirtyFour.receipts) {
      assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
      assert.equal(r.sha256, preserved[r.path], `${r.path} is at its PRESERVATION-R12 bytes`);
    }
    for (const id of ["125", "126", "127", "128", "129", "130", "131"]) {
      const plan = contract.completed_plans.find((p) => p.plan === `253-${id}`);
      assert.ok(plan, id);
      for (const r of plan.receipts) assert.equal(r.sha256, sha(readFileSync(join(REPO, r.path))), r.path);
    }
    assert.ok(contract.completed_plans.every((p) => p.summary.status !== "halted" && p.summary.status !== "blocked"));
  });

  test("the builder refuses a missing PLAN 136-145 and a halted or never-executed owner (positive controls: the same clone builds, a live owner passes)", () => {
    const root = mkdtempSync(join(tmpdir(), "p253-142-clone-"));
    cleanup.push(root);
    git(REPO, "clone", "-q", "--no-checkout", "--shared", REPO, root);
    git(root, "checkout", "-q", "HEAD", "--", PHASE_DIR_REL);
    const built = reconcile.buildContract({ repoRoot: root, revision: "r12" });
    assert.equal(built.plan_pins.length, 145);
    for (const id of ["143", "145", "138"]) {
      rmSync(join(root, PHASE_DIR_REL, `253-${id}-PLAN.md`));
      assert.throws(() => reconcile.buildContract({ repoRoot: root, revision: "r12" }), new RegExp(`253-${id}`));
      git(root, "checkout", "-q", "HEAD", "--", `${PHASE_DIR_REL}/253-${id}-PLAN.md`);
      assert.equal(reconcile.buildContract({ repoRoot: root, revision: "r12" }).plan_pins.length, 145);
    }
    const phaseDir = join(root, PHASE_DIR_REL);
    for (const owner of ["141", "142", "143", "145", "131", "132", "136", "253-144"]) assert.doesNotThrow(() => reconcile.assertProofOwnerR12(phaseDir, owner), owner);
    for (const owner of ["134", "135", "122", "123", "124", "113", "104", "92", "253-134"]) assert.throws(() => reconcile.assertProofOwnerR12(phaseDir, owner), /halted or never-executed/, owner);
    rmSync(join(phaseDir, "253-144-PLAN.md"));
    assert.throws(() => reconcile.assertProofOwnerR12(phaseDir, "144"), /253-144 is missing/);
  });

  test("CLI --revision r12 --prepare-contract --check-only matches, drifts fail, nothing is created, and v1-r11 still check", () => {
    const dir = mkdtempSync(join(tmpdir(), "p253-142-contract-"));
    cleanup.push(dir);
    const target = join(dir, R12_CONTRACT_NAME);
    const text = reconcile.serializeContract(reconcile.buildContract({ revision: "r12" }));
    const run = (extra = []) => spawnSync(process.execPath, [SCRIPT, "--revision", "r12", "--prepare-contract", "--output", target, "--check-only", ...extra], { encoding: "utf8" });
    assert.notEqual(run().status, 0);
    assert.equal(existsSync(target), false);
    writeFileSync(target, text);
    const ok = run();
    assert.equal(ok.status, 0, ok.stderr);
    writeFileSync(target, `${text} `);
    assert.notEqual(run().status, 0);
    for (const [rev, name] of [[null, reconcile.CONTRACT_NAME], ["r2", R2_CONTRACT_NAME_FOR_R3], ["r3", R3_CONTRACT_NAME], ["r4", R4_CONTRACT_NAME], ["r5", R5_CONTRACT_NAME], ["r6", R6_CONTRACT_NAME], ["r7", R7_CONTRACT_NAME], ["r8", R8_CONTRACT_NAME], ["r9", R9_CONTRACT_NAME], ["r10", R10_CONTRACT_NAME], ["r11", R11_CONTRACT_NAME]]) {
      const args = [...(rev ? ["--revision", rev] : []), "--prepare-contract", "--output", join(REAL_PHASE_DIR, name), "--check-only"];
      const check = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
      assert.equal(check.status, 0, check.stderr);
    }
  });
});

describe("R12 disposition text", () => {
  test("says CIREL-02 is accepted and CIREL-01 partial, never both accepted, and names the R12 successors", () => {
    const { root } = r12Fixture();
    const contract = reconcile.buildContract({ revision: "r12" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 53);
    for (const entry of bundle.entries) {
      assert.match(entry.content, /tags: \[historical-disposition, load-recovery, dispositioned\]/);
      assert.match(entry.content, /\nstatus: superseded\n/);
      assert.match(entry.content, /\nexecution_performed: false\n/);
      assert.match(entry.content, /\noriginal_status: blocked\n/);
      assert.match(entry.content, /\nphase_verification_status: not_started\n/);
      assert.doesNotMatch(entry.content, /\nstatus: blocked\n/);
      assert.match(entry.content, /requirements-completed: \[\]/);
      assert.match(entry.content, /CIREL-02 is accepted by the linked completion evidence/);
      assert.match(entry.content, /CIREL-01 is recorded partial under Jon's not_reproduced disposition/);
      assert.doesNotMatch(entry.content, /CIREL-01 and CIREL-02 are accepted by the linked completion evidence/);
      assert.doesNotMatch(entry.content, /CIREL-01 (is|was) accepted/);
      assert.doesNotMatch(entry.content, /-R11-PROBE/);
      assert.doesNotMatch(entry.content, R12_R11_CANARY_PATTERN);
    }
    const oneThirtyFive = bundle.entries.find((e) => e.plan === "253-135");
    assert.match(oneThirtyFive.content, /never ran because its dependency 253-134 halted: normal draft PR #337 got no pull_request run/);
    assert.match(oneThirtyFive.content, /stale server parent 84ebcea60/);
    assert.match(oneThirtyFive.content, /Its R12 successor is 253-142, 253-145\./);
    assert.match(oneThirtyFive.content, /original_blocked_by: \["253-134"\]/);
    assert.match(oneThirtyFive.content, /link: load_target_disposition/);
    const oneTwentyThree = bundle.entries.find((e) => e.plan === "253-123");
    assert.match(oneTwentyThree.content, /never ran because its dependency 253-122 halted at the first failure scenario/);
    assert.match(oneTwentyThree.content, /Its R12 successor is 253-144\./);
    const oneTwentyFour = bundle.entries.find((e) => e.plan === "253-124");
    assert.match(oneTwentyFour.content, /Its R12 successor is 253-132, 253-142, 253-145\./);
  });
});

describe("R12 pairing through the real installed SDK on a copy of the current plan set", () => {
  test("135 stays incomplete and blocked behind halted 253-134; 253-142 is the next explicitly dispatched plan", () => {
    const { root } = r12Fixture();
    const index = sdk(root, "phase-plan-index", "253");
    const by = Object.fromEntries(index.plans.map((p) => [p.id, p]));
    for (const id of R12_PLAN_IDS_T) assert.ok(by[`253-${id}`], `the SDK lists plan 253-${id}`);
    assert.equal(index.plans.length, 145);
    assert.ok(index.incomplete.includes("253-135"), "253-135 incomplete");
    assert.equal(by["253-135"].has_summary, false);
    assert.ok(by["253-135"].blocked_by.includes("253-134"), "253-135 blocked behind 253-134");
    assert.equal(by["253-135"].halted, false);
    assert.equal(by["253-134"].halted, true);
    assert.equal(by["253-134"].has_summary, true);
    for (const id of ["125", "126", "127", "128", "129", "130", "131", "132", "133", "136", "137", "138", "139", "140", "141"]) assert.equal(by[`253-${id}`].has_summary, true, id);
    assert.deepEqual(by["253-142"].depends_on, ["253-141"]);
    assert.equal(by["253-142"].has_summary, false);
    assert.equal(by["253-142"].halted, false);
    // Measured against the installed SDK 1.16.0: blocked_by propagates through depends_on past summarized
    // plans. 136 depends on halted 134, so 136-145 inherit [253-134, 253-122, 253-84, 253-92] and `runnable` is
    // empty. 253-142 is the next plan with no summary whose own dependency (141) is summarized; it is dispatched
    // explicitly.
    assert.equal(by["253-143"].wave, by["253-142"].wave + 1);
    for (const id of ["253-142", "253-143", "253-144", "253-145"]) {
      assert.equal(by[id].has_summary, false, id);
      assert.equal(by[id].halted, false, id);
      assert.deepEqual([...by[id].blocked_by].sort(), ["253-122", "253-134", "253-84", "253-92"], `${id} inherits the 134, 122, 84 and 92 blocks`);
    }
    assert.deepEqual(index.runnable, []);
    assert.deepEqual([...index.incomplete].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R12_UNSTARTED, "142", "143", "144", "145"]);
    const contract = reconcile.buildContract({ revision: "r12" });
    const report = reconcile.checkIndex({ root, contract });
    assert.equal(report.ok, false);
    assert.deepEqual(report.old_unsummarized.map((id) => id.slice(4)), R12_UNSTARTED);
    assert.deepEqual([...report.any_unsummarized].sort(reconcile.comparePlanIds).map((id) => id.slice(4)), [...R12_UNSTARTED, "142", "143", "144", "145"]);
  });

  test("after simulated R12 dispositions and 142-145 summaries nothing is incomplete, seventeen plans are halted and nothing reports blocked", () => {
    const { root, dir } = r12Fixture();
    for (const id of ["142", "143", "144", "145"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r12" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    const bundle = reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier });
    assert.equal(bundle.entries.length, 53);
    for (const entry of bundle.entries) for (const owner of R12_OWNERS[entry.plan.slice(4)]) assert.ok(entry.content.includes(`253-${owner}`), `${entry.plan} names owner ${owner}`);
    const originalsBefore = planHashes(dir);
    const record = reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle, completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "apply-record.json") });
    assert.equal(record.applied, true);
    assert.equal(record.entries.length, 53);
    assert.deepEqual(planHashes(dir), originalsBefore);
    const index = sdk(root, "phase-plan-index", "253");
    const init = sdk(root, "init.execute-phase", "253");
    assert.deepEqual(index.incomplete, []);
    assert.deepEqual(init.incomplete_plans, []);
    assert.deepEqual(index.plans.filter((p) => p.halted).map((p) => p.id.slice(4)).sort(byNumber9), [...R12_HALTED].sort(byNumber9));
    assert.equal(index.plans.filter((p) => p.halted).length, 17);
    const rows = reconcile.pairingReport(root, "253");
    assert.equal(rows.length, 145);
    assert.ok(rows.every((row) => row.summary_status !== "blocked"), "no summary reports status: blocked");
    assert.ok(rows.every((row) => row.init_disagrees === false), "init.execute-phase agrees with phase-plan-index");
    for (const id of [...R12_NEW_UNSTARTED, ...R11_NEW_UNSTARTED, ...R10_NEW_UNSTARTED, ...R9_NEW_UNSTARTED, "41", "47"]) {
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
    const { root, dir } = r12Fixture();
    for (const id of ["142", "143", "144", "145"]) writeFileSync(join(dir, `253-${id}-SUMMARY.md`), COMPLETE);
    const contract = reconcile.buildContract({ revision: "r12" });
    const contractSha = sha(reconcile.serializeContract(contract));
    const completion = dispositionCompletionFixture(root);
    writeFileSync(join(dir, "253-144-SUMMARY.md"), BLOCKED);
    assert.throws(() => reconcile.applyBundle({ root, contract, contractSha256: contractSha, bundle: reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), completionPath: completion, verifier: dispositionedVerifier, allowFixture: true, recordPath: join(root, "r.json") }), /253-144/);
    assert.equal(existsSync(join(dir, "253-135-SUMMARY.md")), false);
    writeFileSync(join(dir, "253-144-SUMMARY.md"), COMPLETE);
    writeFileSync(join(dir, "253-143-PLAN.md"), `${readFileSync(join(dir, "253-143-PLAN.md"), "utf8")}\n`);
    assert.throws(() => reconcile.prepareDispositions({ root, contract, contractSha256: contractSha, completionPath: completion, verifier: dispositionedVerifier }), /253-143|differs/);
    assert.equal(existsSync(join(dir, "253-135-SUMMARY.md")), false);
  });
});

// R13 tests derive expected sets from the preserved R12 contract and the explicit current plan.
const R13_EXPECTED_HALTS = ['02','07','09','12','16','27','40','51','63','73','84','92','97','104','113','122','134','143','146','155','167','173','174','175','178','181','182','183'];
const R13_NEW_TARGETS = ['144','145','147','148','149','150','151','152','153','154','156','157','158','159','160','161','162','163','176','177'];
const R13_EXPECTED_TARGETS = [...JSON.parse(readFileSync(join(REAL_PHASE_DIR,'253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R12.json'),'utf8')).responsibilities.map((r)=>r.plan.slice(4)),...R13_NEW_TARGETS].sort(byNumber9);
const r13Fixture = () => r8Fixture({maxPlan:183,maxSummary:183});

describe('R13 revision and contract',()=>{
  test('R13 partitions the exact historical plans and uses dispositioned gating',()=>{
    assert.equal(reconcile.CONTRACT_SCHEMA_R13,'sigra.phase253.load-recovery-reconciliation-contract/r13');
    assert.deepEqual([...reconcile.HALTED_IDS_R13].sort(byNumber9),R13_EXPECTED_HALTS);
    assert.deepEqual([...reconcile.UNSTARTED_IDS_R13],R13_EXPECTED_TARGETS);
    const all=[...reconcile.COMPLETED_IDS_R13,...reconcile.HALTED_IDS_R13,...reconcile.UNSTARTED_IDS_R13].sort(byNumber9);
    const expected=[...Array.from({length:167},(_,i)=>String(i+1).padStart(2,'0')),'173','174','175','176','177','178','181','182','183'];
    assert.deepEqual(all,expected);assert.equal(new Set(all).size,176);
    assert.equal(reconcile.COMPLETED_IDS_R13.length,75);
    assert.ok(reconcile.completionArgv('r13','x').includes('--require-dispositioned'));
    for(const r of ['v1','r2','r3','r4','r5'])assert.ok(reconcile.completionArgv(r,'x').includes('--require-accepted'));
    assert.equal(reconcile.REVISIONS.at(-1),'r13');assert.throws(()=>reconcile.contractPathFor('r14'),/unknown revision/);
  });
  test('R13 real contract pins183 plans,73 targets and28 literal halts',()=>{
    const c=reconcile.buildContract({revision:'r13'});
    assert.equal(c.plan_pins.length,183);assert.equal(c.responsibilities.length,73);assert.equal(c.halted_plans.length,28);
    assert.deepEqual(c.responsibilities.map((r)=>r.plan.slice(4)),R13_EXPECTED_TARGETS);
    assert.deepEqual(c.halted_plans.map((r)=>r.plan.slice(4)),R13_EXPECTED_HALTS);
    assert.ok(c.halted_plans.every((r)=>r.summary.status==='halted'));
    assert.equal(c.application.bundle_requires_final_summary_of,'253-172');
    assert.equal(c.application.accepted_only_predicate,'scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned');
    const forbidden=new Set([...R13_EXPECTED_HALTS,...R13_EXPECTED_TARGETS].map((id)=>'253-'+id));
    for(const row of c.responsibilities)for(const owner of row.owners)assert.ok(!forbidden.has(owner),owner);
    for(const owners of Object.values(c.halted_proof_map))for(const owner of owners)assert.ok(!forbidden.has(owner),owner);
    for(const [id,owners] of Object.entries({'149':['253-179'],'158':['253-179'],'176':['253-179'],'177':['253-180']}))assert.deepEqual(c.responsibilities.find((r)=>r.plan==='253-'+id).owners,owners);
    for(const id of ['174','175','178','181','182','183'])assert.deepEqual(c.halted_proof_map['253-'+id],['253-179','253-180']);
    assert.equal(c.recovery_proof.hosted_completion_links,false);assert.equal(c.recovery_proof.attempt_count,1);
    assert.equal(c.r12_contract.sha256,'d36a2ab07ff2e716d777bc784432b12ab6c01cef987c81e170fd852dcdefc45c');
    for(const [id,paths] of Object.entries(c.historical_receipt_origins))for(const [path,pin] of Object.entries(paths))assert.equal(sha(Buffer.from(git(reconcile.REPO_ROOT,'show',pin.commit+':'+path))),pin.sha256,`${id}:${path}`);
  });
  test('R13 current CLI builds on a temporary output and historical contracts remain unchanged',()=>{
    const {root}=r13Fixture();const output=join(root,'r13.json');
    const args=[SCRIPT,'--revision','r13','--prepare-contract','--output',output];
    const produced=spawnSync(process.execPath,args,{encoding:'utf8'});assert.equal(produced.status,0,produced.stderr);
    const checked=spawnSync(process.execPath,[...args,'--check-only'],{encoding:'utf8'});assert.equal(checked.status,0,checked.stderr);
    for(const r of ['v1',...Array.from({length:11},(_,i)=>'r'+(i+2))]){
      const name=r==='v1'?reconcile.CONTRACT_NAME:`253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-${r.toUpperCase()}.json`;
      assert.equal(reconcile.serializeContract(reconcile.buildContract({revision:r})),readFileSync(join(REAL_PHASE_DIR,name),'utf8'),r);
    }
  });
  test('R13 SDK simulation preserves all actual halts and returns no incomplete plans',()=>{
    const {root,dir}=r13Fixture();const c=reconcile.buildContract({revision:'r13'}),hash=sha(reconcile.serializeContract(c));
    const initial=sdk(root,'phase-plan-index','253');assert.equal(initial.plans.length,183);assert.equal(initial.plans.find((r)=>r.id==='253-169').has_summary,false);
    assert.equal(initial.plans.find((r)=>r.id==='253-179').has_summary,true);assert.equal(initial.plans.find((r)=>r.id==='253-174').halted,true);
    const preserved=Object.fromEntries(readdirSync(dir).filter((f)=>f.endsWith('-SUMMARY.md')).map((f)=>[f,sha(readFileSync(join(dir,f)))]));
    for(const id of ['169','170','171','172'])writeFileSync(join(dir,`253-${id}-SUMMARY.md`),COMPLETE);
    const completion=dispositionCompletionFixture(root);
    const bundle=reconcile.prepareDispositions({root,contract:c,contractSha256:hash,completionPath:completion,verifier:dispositionedVerifier});assert.equal(bundle.entries.length,73);
    const record=reconcile.applyBundle({root,contract:c,contractSha256:hash,bundle,completionPath:completion,verifier:dispositionedVerifier,allowFixture:true,recordPath:join(root,'applied.json')});assert.equal(record.applied,true);
    const index=sdk(root,'phase-plan-index','253'),init=sdk(root,'init.execute-phase','253');
    assert.deepEqual(index.incomplete,[]);assert.deepEqual(init.incomplete_plans,[]);
    assert.deepEqual(index.plans.filter((r)=>r.halted).map((r)=>r.id.slice(4)).sort(byNumber9),R13_EXPECTED_HALTS);
    for(const [name,hash]of Object.entries(preserved))assert.equal(sha(readFileSync(join(dir,name))),hash,name);
    assert.equal(reconcile.checkIndex({root,contract:c}).route.outcome,'resume_phase_gates');
  });
  test('R13 negative controls preserve original plans and reject halted owners and edited pins',()=>{
    const {root,dir}=r13Fixture(),c=reconcile.buildContract({revision:'r13'}),hash=sha(reconcile.serializeContract(c));
    for(const id of ['169','170','171','172'])writeFileSync(join(dir,`253-${id}-SUMMARY.md`),COMPLETE);
    const completion=dispositionCompletionFixture(root);
    const prepare=()=>reconcile.prepareDispositions({root,contract:c,contractSha256:hash,completionPath:completion,verifier:dispositionedVerifier});
    assert.equal(prepare().entries.length,73);
    for(const name of ['253-167-SUMMARY.md','253-170-PLAN.md','253-161-PLAN.md','253-173-PLAN.md','253-174-PLAN.md']){
      const path=join(dir,name),original=readFileSync(path);writeFileSync(path,Buffer.concat([original,Buffer.from('\n')]));
      try{assert.throws(prepare,/differs/);}finally{writeFileSync(path,original);}
    }
    assert.throws(()=>reconcile.assertProofOwnerR13(dir,'167'),/halted or never-executed/);
    for(const id of ['167','173','174'])assert.ok(!prepare().entries.some((e)=>e.plan==='253-'+id));
    writeFileSync(join(dir,'253-170-SUMMARY.md'),BLOCKED);assert.throws(prepare,/253-170/);writeFileSync(join(dir,'253-170-SUMMARY.md'),COMPLETE);
    assert.equal(prepare().entries.length,73);
  });
});

describe('R13 original recovery input controls',()=>{
  test('R13 refuses a missing or changed179 receipt and changed167 historical proof',async()=>{
    const {symlinkSync}=await import('node:fs');
    const root=mkdtempSync(join(tmpdir(),'p253-r13-proof-'));cleanup.push(root);const dir=join(root,PHASE_DIR_REL);mkdirSync(dir,{recursive:true});
    symlinkSync(join(reconcile.REPO_ROOT,'.git'),join(root,'.git'));
    for(const name of readdirSync(REAL_PHASE_DIR))symlinkSync(join(REAL_PHASE_DIR,name),join(dir,name));
    const build=()=>reconcile.buildContract({revision:'r13',repoRoot:root});
    assert.equal(build().responsibilities.length,73);
    const name='253-179-RECOVERY-RECEIPT.json',path=join(dir,name);unlinkSync(path);
    try{assert.throws(build,/ENOENT|receipt/);writeFileSync(path,'{}');assert.throws(build,/receipt/);}finally{if(existsSync(path))unlinkSync(path);symlinkSync(join(REAL_PHASE_DIR,name),path);}
    assert.equal(build().responsibilities.length,73);
    const receipt=JSON.parse(readFileSync(join(REAL_PHASE_DIR,name),'utf8'));
    const target=Object.keys(receipt.historical_sha256).find((p)=>p.includes('/253-167-')&&!p.endsWith('PLAN.md')&&!p.endsWith('SUMMARY.md'));
    assert.ok(target,'original167 proof path exists');const copy=join(root,target),bytes=readFileSync(copy);unlinkSync(copy);writeFileSync(copy,Buffer.concat([bytes,Buffer.from('\n')]));
    try{assert.throws(build,/historical recovery input/);}finally{unlinkSync(copy);symlinkSync(join(reconcile.REPO_ROOT,target),copy);}
    assert.equal(build().responsibilities.length,73);
  });
});
