#!/usr/bin/env node
// Phase 253 plan 43: phase-local, accepted-only SDK reconciliation helper.
//
// Purpose: let the root agent route a Phase 253 whose eighteen never-started old plans are blocked
// behind six preserved halts to whole-phase verification, WITHOUT executing, editing or relabelling
// any original plan or failed summary. New superseded routing summaries are possible only after the
// strict completion checker (`ci-hosted-gate-verify.py --mode completion --require-accepted`)
// re-opens every linked proof and accepts it. This module has no write path that bypasses it.
//
// Pure Node built-ins only; never installs or edits the SDK. Every SDK answer is obtained from a
// real `gsd-tools query` subprocess.
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "..", "..", "..");
export const SDK_ROOT = "/Users/jon/.codex/gsd-core";
export const GSD_TOOLS = join(SDK_ROOT, "bin", "gsd-tools.cjs");
export const VERIFIER = join(REPO_ROOT, "scripts", "ci", "ci-hosted-gate-verify.py");
export const COMPLETION_LINK_KEYS = [
  "phase252_replay", "phase252_diagnosis", "load_controls", "load_acceptance",
  "publication", "canary", "pr_normal", "pr_docs_only",
];

export const sha256 = (value) => createHash("sha256").update(value).digest("hex");

// Observed 2026-10-14 against `gsd-tools query runtime-identity`; matches the planning SDK audit.
export const SDK_PINS = Object.freeze({
  packageName: "@opengsd/gsd-core",
  version: "1.16.0",
  files: Object.freeze([
    { path: "bin/gsd-tools.cjs", sha256: "4a2774598f6a1de9b63bbcbe71b4dff795b036fd061a80a3f2ab37a35bd63c3a" },
    { path: "bin/lib/plan-scan.cjs", sha256: "11731a44cf7b1f3d8a7e0fa469425b3b4317598cf9118a97f976243a96f61d8e" },
    { path: "bin/lib/plan-dependency-graph.cjs", sha256: "d0b053bdbe4fad0010b4adb95e2f55af786cb7c1bf3da036ed6302db5f7e5cbc" },
    { path: "bin/lib/phase.cjs", sha256: "5906c52e9c03fabd189a08f4f0f9749b94fb22719124fe2ea528b6fee9d08f6d" },
    { path: "bin/lib/phase-locator.cjs", sha256: "ba9c2ec24dbd5aaab115ce3406224ad75640b0093ab2e484ec2272892fbcf77f" },
    { path: "bin/lib/init.cjs", sha256: "123feeaada39b2ebaa65290b16f15ca76868d7c32564567921d8da3d9667e500" },
    { path: "workflows/execute-phase.md", sha256: "f80f810faa31b363a7859c7caa0556710b7d323b8aaca47b851d498c99aea752" },
  ]),
});

// Literal fragments of the installed execute-phase workflow this module's routing reproduces.
// If any disappears the installed behaviour changed and the reproduction must be re-derived.
export const WORKFLOW_ASSERTIONS = Object.freeze([
  "**Filtering:** Skip plans where `has_summary: true`.",
  "Additionally skip any plan whose `blocked_by` array is non-empty (#2830)",
  "This rule is additive to the `has_summary` skip, not a replacement for it.",
  "If `--gaps-only`: also skip plans whose `gap_closure` is not `true`",
  "**A filter is active** (`--gaps-only`, or `WAVE_FILTER` set)",
  "**No filter is active, and at least one filtered plan was skipped because of a non-empty",
  "**No filter is active, and every filtered plan was filtered by `has_summary` alone**",
  "**`VERIFY_ROUTE == execute-phase`**",
  "All {plan_count} plans are summarized but no VERIFICATION.md exists",
]);

// ---------------------------------------------------------------------------------------------
// Real SDK access
// ---------------------------------------------------------------------------------------------
export function sdkQuery(root, args) {
  const argv = [GSD_TOOLS, "query", ...args];
  if (root) argv.push("--project-dir", root);
  const result = spawnSync(process.execPath, argv, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (result.status !== 0) {
    throw new Error(`gsd-tools query ${args.join(" ")} failed (exit ${result.status}): ${(result.stderr || "").slice(0, 400)}`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch (error) {
    throw new Error(`gsd-tools query ${args.join(" ")} returned non-JSON stdout: ${error.message}`);
  }
}

export function verifySdkPins(pins = SDK_PINS, sdkRoot = SDK_ROOT) {
  const identity = sdkQuery(null, ["runtime-identity"]);
  const files = pins.files.map((pin) => {
    let actual = null;
    try {
      actual = sha256(readFileSync(join(sdkRoot, pin.path)));
    } catch {
      actual = null;
    }
    return { path: pin.path, sha256: pin.sha256, actual, match: actual === pin.sha256 };
  });
  const mismatches = files.filter((file) => !file.match).map((file) => file.path);
  if (identity.packageName !== pins.packageName) mismatches.push("packageName");
  if (identity.version !== pins.version) mismatches.push("version");
  return { ok: mismatches.length === 0, packageName: identity.packageName, version: identity.version, files, mismatches };
}

// ---------------------------------------------------------------------------------------------
// Minimal frontmatter readers (top-level scalars and the nested key-files lists only)
// ---------------------------------------------------------------------------------------------
function scalar(raw) {
  let value = raw.replace(/\s+#.*$/, "").trim();
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
  if (value === "true") return true;
  if (value === "false") return false;
  return value;
}

function frontmatterLines(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  return match ? match[1].split(/\r?\n/) : [];
}

export function frontmatter(text) {
  const out = {};
  for (const line of frontmatterLines(text)) {
    const key = /^([A-Za-z0-9_-]+):[ \t]*(.*)$/.exec(line);
    if (key) out[key[1]] = scalar(key[2]);
  }
  return out;
}

// key-files: {created, modified} path lists, read literally from the SUMMARY frontmatter.
export function keyFiles(text) {
  const out = { created: [], modified: [] };
  let inKeyFiles = false;
  let section = null;
  for (const line of frontmatterLines(text)) {
    if (/^key-files:\s*$/.test(line)) { inKeyFiles = true; section = null; continue; }
    if (!inKeyFiles) continue;
    if (/^\S/.test(line)) break;
    const header = /^\s+(created|modified):\s*(\[\])?\s*$/.exec(line);
    if (header) { section = header[1]; continue; }
    const item = /^\s+-\s+(.+?)\s*$/.exec(line);
    if (item && section) out[section].push(scalar(item[1]));
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Pairing facts exactly as the installed SDK reports them, plus the literal SUMMARY status
// ---------------------------------------------------------------------------------------------
export function pairingReport(root, phase) {
  const index = sdkQuery(root, ["phase-plan-index", String(phase)]);
  const init = sdkQuery(root, ["init.execute-phase", String(phase)]);
  const incompleteByInit = new Set((init.incomplete_plans || []).map((file) => file.replace(/-PLAN\.md$/, "")));
  return index.plans.map((plan) => {
    let text = null;
    try {
      text = readFileSync(join(init.phase_dir, `${plan.id}-SUMMARY.md`), "utf8");
    } catch {
      text = null;
    }
    const fm = text === null ? {} : frontmatter(text);
    return {
      id: plan.id,
      has_summary: plan.has_summary,
      halted: plan.halted,
      blocked_by: plan.blocked_by,
      summary_status: text === null ? null : (fm.status ?? null),
      execution_performed: text === null ? null : (fm.execution_performed ?? null),
      original_status: text === null ? null : (fm.original_status ?? null),
      init_incomplete: incompleteByInit.has(plan.id),
      init_disagrees: incompleteByInit.has(plan.id) === plan.has_summary,
    };
  });
}

// ---------------------------------------------------------------------------------------------
// Installed execute-phase routing, reproduced (has_summary-first filtering, then the ordered
// "all filtered" conditions). The workflow is prose; this is its deterministic reading, and
// WORKFLOW_ASSERTIONS pins the prose it reads.
// ---------------------------------------------------------------------------------------------
export function routeExecutePhase(index, verification, { gapsOnly = false, waveFilter = null } = {}) {
  if (gapsOnly && index.plans.some((plan) => !("gap_closure" in plan))) {
    throw new Error("--gaps-only cannot read gap_closure from phase-plan-index — refusing to report an empty selection");
  }
  const skipped = [];
  const dispatch = [];
  for (const plan of index.plans) {
    let reason = null;
    if (plan.has_summary === true) reason = "has_summary";
    else if (Array.isArray(plan.blocked_by) && plan.blocked_by.length > 0) reason = "blocked_by";
    else if (plan.ready === false) reason = "not_ready";
    else if (gapsOnly && plan.gap_closure !== true) reason = "not_gap_closure";
    else if (waveFilter !== null && plan.wave !== waveFilter) reason = "wave_filter";
    if (reason) skipped.push({ id: plan.id, reason });
    else dispatch.push(plan.id);
  }
  const blockedPlans = skipped.filter((s) => s.reason === "blocked_by").map((s) => s.id);
  const notReady = skipped.filter((s) => s.reason === "not_ready").map((s) => s.id);
  const inheritedBlockedOnSummarized = index.plans
    .filter((plan) => plan.has_summary === true && Array.isArray(plan.blocked_by) && plan.blocked_by.length > 0)
    .map((plan) => plan.id).sort();
  const base = { skipped, blocked_plans: blockedPlans, inherited_blocked_on_summarized: inheritedBlockedOnSummarized, dispatch };
  const filterActive = gapsOnly === true || waveFilter !== null;
  if (dispatch.length > 0) return { ...base, outcome: "dispatch_plans" };
  if (filterActive) return { ...base, outcome: "no_matching_incomplete_plans" };
  if (blockedPlans.length > 0) return { ...base, outcome: "phase_stuck" };
  if (notReady.length > 0) return { ...base, outcome: "phase_waiting_on_incomplete_predecessors" };
  if (verification && verification.route === "execute-phase") {
    return { ...base, outcome: "resume_phase_gates", verify_status: verification.status, next_command: `$gsd-execute-phase ${index.phase}` };
  }
  if (verification && verification.status === "passed") return { ...base, outcome: "no_matching_incomplete_plans", verify_status: "passed" };
  return { ...base, outcome: "present_verification_next_action", verify_status: verification ? verification.status : null,
    next_action: verification ? verification.next_action : null, next_command: verification ? verification.next_command : null };
}

// ---------------------------------------------------------------------------------------------
// Accepted-only predicate: the implemented strict completion checker, run as a subprocess.
// `verifier` may be injected ONLY by in-process fixture tests; the CLI never passes one.
// ---------------------------------------------------------------------------------------------
export function evaluateCompletion({ completionPath, verifier = null }) {
  let completionSha = null;
  try {
    completionSha = sha256(readFileSync(completionPath));
  } catch (error) {
    return { accepted: false, verifier_kind: verifier ? "injected-fixture" : "real", exit_code: null, detail: `completion evidence unreadable: ${error.message}`, completion_sha256: null, result: null };
  }
  let exit;
  let stdout;
  let stderr;
  if (verifier) {
    ({ exit, stdout, stderr } = verifier({ completionPath }));
  } else {
    const run = spawnSync("python3", [VERIFIER, "--mode", "completion", "--require-accepted", "--evidence", completionPath],
      { cwd: REPO_ROOT, encoding: "utf8", timeout: 600000, maxBuffer: 64 * 1024 * 1024 });
    exit = run.status;
    stdout = run.stdout || "";
    stderr = run.stderr || "";
  }
  let result = null;
  try {
    result = JSON.parse(stdout);
  } catch {
    result = null;
  }
  const accepted = exit === 0 && result !== null && result.status === "accepted"
    && Array.isArray(result.gaps) && result.gaps.length === 0
    && result.phase_verification === "not_started"
    && result.requirements && result.requirements["CIREL-01"] === "accepted" && result.requirements["CIREL-02"] === "accepted"
    && Array.isArray(result.linked) && JSON.stringify([...result.linked].sort()) === JSON.stringify([...COMPLETION_LINK_KEYS].sort());
  return {
    accepted,
    verifier_kind: verifier ? "injected-fixture" : "real",
    exit_code: exit,
    detail: (stderr || stdout || "").slice(0, 400),
    completion_sha256: completionSha,
    verifier_sha256: verifier ? null : sha256(readFileSync(VERIFIER)),
    result,
  };
}

// ---------------------------------------------------------------------------------------------
// Task 2 RED skeleton: contract, bundle and application exports exist but answer nothing.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT.json";
export function buildContract() { return null; }
export function serializeContract() { return null; }
export function loadContract() { return null; }
export function renderDisposition() { return null; }
export function prepareDispositions() { return null; }
export function applyBundle() { return null; }
export function checkIndex() { return null; }

// ---------------------------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------------------------
function parseArgs(argv) {
  const flags = new Set(["--prepare-contract", "--check-only", "--dry-run", "--prepare-dispositions", "--apply-bundle"]);
  const valued = new Set(["--output", "--completion", "--bundle", "--record", "--root", "--check-index"]);
  const out = { flags: new Set(), values: {} };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (flags.has(arg)) out.flags.add(arg);
    else if (valued.has(arg)) {
      if (i + 1 >= argv.length) throw new Error(`${arg} requires a value`);
      out.values[arg] = argv[(i += 1)];
    } else throw new Error(`unknown argument: ${arg}`);
  }
  return out;
}

export function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`reconcile: ${error.message}\n`);
    return 2;
  }
  if (args.flags.has("--prepare-dispositions")) {
    const completion = args.values["--completion"];
    if (!completion) {
      process.stderr.write("reconcile: --prepare-dispositions requires --completion\n");
      return 2;
    }
    const verdict = evaluateCompletion({ completionPath: completion });
    if (!verdict.accepted) {
      process.stderr.write(`reconcile: accepted-only completion not satisfied; no disposition bytes generated: ${verdict.detail}\n`);
      return 1;
    }
    process.stderr.write("reconcile: contract-backed bundle preparation is not available in this build\n");
    return 3;
  }
  process.stderr.write("reconcile: no supported command given\n");
  return 2;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exit(main(process.argv.slice(2)));
}
