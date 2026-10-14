// Phase 253 plan 43: actual installed-SDK contracts for accepted-only historical disposition.
// Every SDK answer below comes from a real `gsd-tools query` subprocess against a temporary
// committed repository; nothing here reads or writes the live Phase 253 tracking files.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

import * as reconcile from "./253-LOAD-RECOVERY-reconcile.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
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
