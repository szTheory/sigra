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
import { closeSync, existsSync, fsyncSync, lstatSync, openSync, readFileSync, unlinkSync, writeFileSync, writeSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
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
export const DISPOSITION_GAP_R6 = "disposition:CIREL-01:not_reproduced (Jon-approved disposition; target neither reproduced nor fixed)";

// v1-r5 gate on --require-accepted; r6 (plan 253-90) gates on --require-dispositioned, which passes only the
// strict accepted route or Jon's approved not_reproduced disposition route.
// r7 (plan 253-96) and r8 (plan 253-103) are gated the same way as r6.
const DISPOSITIONED_REVISIONS = Object.freeze(new Set(["r6", "r7", "r8"]));
const isDispositioned = (revision) => DISPOSITIONED_REVISIONS.has(revision);

export function completionArgv(revision, completionPath) {
  return [VERIFIER, "--mode", "completion", isDispositioned(revision) ? "--require-dispositioned" : "--require-accepted", "--evidence", completionPath];
}

function acceptedShape(result, exit) {
  return exit === 0 && result !== null && result.status === "accepted"
    && Array.isArray(result.gaps) && result.gaps.length === 0
    && result.phase_verification === "not_started"
    && result.requirements && result.requirements["CIREL-01"] === "accepted" && result.requirements["CIREL-02"] === "accepted"
    && Array.isArray(result.linked) && JSON.stringify([...result.linked].sort()) === JSON.stringify([...COMPLETION_LINK_KEYS].sort());
}

// R6 accepts exactly the disposition route: CIREL-02 accepted, CIREL-01 partial, the single disposition gap, and never "accepted".
function dispositionedShape(result, exit) {
  return exit === 0 && result !== null && result.status === "dispositioned" && result.dispositioned === true
    && Array.isArray(result.gaps) && result.gaps.length === 1 && result.gaps[0] === DISPOSITION_GAP_R6
    && result.phase_verification === "not_started"
    && result.requirements && result.requirements["CIREL-01"] === "partial_not_reproduced" && result.requirements["CIREL-02"] === "accepted"
    && Array.isArray(result.linked) && JSON.stringify([...result.linked].sort()) === JSON.stringify([...COMPLETION_LINK_KEYS].sort());
}

export function evaluateCompletion({ completionPath, verifier = null, revision = "v1" }) {
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
    const run = spawnSync("python3", completionArgv(revision, completionPath),
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
  const accepted = isDispositioned(revision) ? dispositionedShape(result, exit) : acceptedShape(result, exit);
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
// Reconciliation contract: all 35 original identities, six halted records, eighteen mappings
// ---------------------------------------------------------------------------------------------
export const PHASE = "253";
export const PHASE_DIR_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks";
export const CONTRACT_NAME = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT.json";
export const CONTRACT_SCHEMA = "sigra.phase253.load-recovery-reconciliation-contract/v1";
export const BUNDLE_SCHEMA = "sigra.phase253.load-recovery-disposition-bundle/v1";
export const RECORD_SCHEMA = "sigra.phase253.load-recovery-application-record/v1";
export const COMPLETED_IDS = Object.freeze(["01", "03", "04", "05", "06", "11", "15", "18", "19", "20", "26"]);
export const HALTED_IDS = Object.freeze(["02", "07", "09", "12", "16", "27"]);
export const UNSTARTED_IDS = Object.freeze(["08", "10", "13", "14", "17", "21", "22", "23", "24", "25", "28", "29", "30", "31", "32", "33", "34", "35"]);
const PR_LINKS = ["pr_normal", "pr_docs_only"];
const CAUSE_LINKS = ["load_controls", "load_acceptance"];
const ids = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => String(from + i));
const NATIVE_OWNERS = ids(36, 41);
// Responsibility -> proof owners and the completion links that must back it. A mapping never
// says the old task ran; it names the new proof that makes the old work moot.
const RESPONSIBILITY_MAP = Object.freeze({
  "08": { owners: ["42", "46"], links: PR_LINKS },
  "13": { owners: ["42", "46"], links: PR_LINKS },
  "21": { owners: ["42", "46"], links: PR_LINKS },
  "30": { owners: ["42", "46"], links: PR_LINKS },
  "34": { owners: ["42", "46"], links: PR_LINKS },
  "24": { owners: ["46"], links: PR_LINKS },
  "10": { owners: NATIVE_OWNERS, links: CAUSE_LINKS },
  "17": { owners: NATIVE_OWNERS, links: CAUSE_LINKS },
  "28": { owners: NATIVE_OWNERS, links: CAUSE_LINKS },
  "29": { owners: NATIVE_OWNERS, links: CAUSE_LINKS },
  "14": { owners: ["43", "47"], links: COMPLETION_LINK_KEYS },
  "25": { owners: ["43", "47"], links: COMPLETION_LINK_KEYS },
  "31": { owners: ["43", "47"], links: COMPLETION_LINK_KEYS },
  "35": { owners: ["43", "47"], links: COMPLETION_LINK_KEYS },
  "22": { owners: ["44"], links: ["publication"] },
  "32": { owners: ["44"], links: ["publication"] },
  "23": { owners: ["45"], links: ["canary"] },
  "33": { owners: ["45"], links: ["canary"] },
});
const HALTED_PROOF_MAP = Object.freeze({
  "02": NATIVE_OWNERS, "07": ["18", "19", "20", "42", "44", "45"], "09": NATIVE_OWNERS,
  "12": ["18", "19", "20", "42", "44", "45"], "16": NATIVE_OWNERS, "27": NATIVE_OWNERS,
});
const DISPOSITION_FIELDS = Object.freeze({ status: "superseded", execution_performed: false, original_status: "blocked", phase_verification_status: "not_started" });

function parseList(raw) {
  if (typeof raw !== "string") return [];
  return raw.replace(/^\[/, "").replace(/\]$/, "").split(",").map((part) => scalar(part.trim())).filter((part) => part !== "");
}

function objectiveOf(text) {
  const match = /<objective>\s*\n([^\n]+)/.exec(text);
  return match ? match[1].trim() : null;
}

function readOrNull(path) {
  try {
    return readFileSync(path);
  } catch {
    return null;
  }
}

function describeSummary(repoRoot, phaseDir, id, { requireReceipts, frozenReceipts = {} }) {
  const file = join(phaseDir, `253-${id}-SUMMARY.md`);
  const bytes = readFileSync(file);
  const text = bytes.toString("utf8");
  const fm = frontmatter(text);
  const files = keyFiles(text);
  const wanted = [...new Set([...files.created, ...files.modified])].filter((path) => path.startsWith(`${PHASE_DIR_REL}/`)).sort();
  const receipts = [];
  const missing = [];
  for (const path of wanted) {
    const content = readOrNull(join(repoRoot, path));
    if (content === null) missing.push(path);
    else receipts.push({ path, sha256: frozenReceipts[path] ?? sha256(content) });
  }
  if (requireReceipts && missing.length > 0) throw new Error(`halted plan 253-${id} receipts are missing: ${missing.join(", ")}`);
  return { plan: `253-${id}`, summary: { path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`, sha256: sha256(bytes), status: fm.status ?? null }, receipts, ...(missing.length > 0 ? { missing_receipts: missing } : {}) };
}

function buildContractV1({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const read = (name) => readFileSync(join(phaseDir, name));
  const auditText = read("253-LOAD-RECOVERY-SOURCE-SDK-AUDIT.md").toString("utf8");
  const auditHashes = Object.fromEntries([...auditText.matchAll(/^\|(253-\d\d-PLAN\.md)\|([a-f0-9]{64})\|$/gm)].map((m) => [m[1], m[2]]));
  const captureBytes = read("253-LOAD-RECOVERY-PLANNING-CAPTURE.json");
  const capture = JSON.parse(captureBytes.toString("utf8"));
  const closeout = JSON.parse(read("253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json").toString("utf8"));
  const partition = [...COMPLETED_IDS, ...HALTED_IDS, ...UNSTARTED_IDS].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 35).map((n) => n.padStart(2, "0")))) {
    throw new Error("completed, halted and unstarted ids do not partition the 35 original plans");
  }
  const originals = [];
  for (let n = 1; n <= 35; n += 1) {
    const id = String(n).padStart(2, "0");
    const file = `253-${id}-PLAN.md`;
    const bytes = readFileSync(join(phaseDir, file));
    const hash = sha256(bytes);
    if (auditHashes[file] !== hash) throw new Error(`${file} differs from the audit inventory hash`);
    const entry = capture.paths.find((p) => p.path === `${PHASE_DIR_REL}/${file}`);
    if (!entry || entry.sha256 !== hash) throw new Error(`${file} differs from the planning capture`);
    const blob = spawnSync("git", ["-C", repoRoot, "cat-file", "blob", entry.blob], { maxBuffer: 64 * 1024 * 1024 });
    if (blob.status !== 0 || sha256(blob.stdout) !== hash) throw new Error(`${file} capture blob ${entry.blob} does not read back to the recorded bytes`);
    const cls = COMPLETED_IDS.includes(id) ? "completed" : HALTED_IDS.includes(id) ? "halted" : "unstarted_blocked";
    originals.push({ plan: `253-${id}`, class: cls, plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: hash,
      capture: { commit: entry.commit, blob: entry.blob, readback_exact: true } });
  }
  const completed = COMPLETED_IDS.map((id) => {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    return described;
  });
  const halted = HALTED_IDS.map((id) => {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: true });
    if (described.summary.status !== "halted") throw new Error(`halted plan 253-${id} summary status is ${described.summary.status}`);
    return described;
  });
  const responsibilities = UNSTARTED_IDS.map((id) => {
    const mapping = RESPONSIBILITY_MAP[id];
    if (!mapping) throw new Error(`no mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const blockedBy = closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} is not recorded as blocked in the execution closeout`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS.map((id) => [`253-${id}`, HALTED_PROOF_MAP[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `253-${owner.slice(4)}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  return {
    schema: CONTRACT_SCHEMA,
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    sdk: { packageName: SDK_PINS.packageName, version: SDK_PINS.version, files: SDK_PINS.files.map((f) => ({ ...f })) },
    capture: { path: `${PHASE_DIR_REL}/253-LOAD-RECOVERY-PLANNING-CAPTURE.json`, sha256: sha256(captureBytes), capture_head: capture.capture_head, existing_plan_count: capture.existing_plan_count },
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted",
      targets: "only the eighteen previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-47",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R2 revision (plan 253-50): the 253-40 line halted on host sleep, so 253-41 and 253-44..47 can never
// run. R2 is ADDITIVE: it keeps the v1 contract file, the v1 builder and the v1 default untouched, and
// re-points every never-executed responsibility to the new proof owners 253-48..253-56.
// ---------------------------------------------------------------------------------------------
export const REVISIONS = Object.freeze(["v1", "r2", "r3", "r4", "r5", "r6", "r7", "r8"]);
export const CONTRACT_NAME_R2 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R2.json";
export const CONTRACT_SCHEMA_R2 = "sigra.phase253.load-recovery-reconciliation-contract/r2";
export const COMPLETED_IDS_R2 = Object.freeze([...COMPLETED_IDS, "36", "37", "38", "39", "42", "43"].sort());
export const HALTED_IDS_R2 = Object.freeze([...HALTED_IDS, "40"]);
export const NEVER_RAN_IDS_R2 = Object.freeze(["41", "44", "45", "46", "47"]);
export const UNSTARTED_IDS_R2 = Object.freeze([...UNSTARTED_IDS, ...NEVER_RAN_IDS_R2].sort());
export const NEVER_RAN_REASON = "dependency 253-40 halted on host sleep";
const NATIVE_OWNERS_R2 = ["36", "37", "38", "39", "48", "51", "52"];
const COMPLETION_OWNERS_R2 = ["43", "50", "56"];
const RESPONSIBILITY_MAP_R2 = Object.freeze({
  "08": { owners: ["42", "55"], links: PR_LINKS },
  "13": { owners: ["42", "55"], links: PR_LINKS },
  "21": { owners: ["42", "55"], links: PR_LINKS },
  "30": { owners: ["42", "55"], links: PR_LINKS },
  "34": { owners: ["42", "55"], links: PR_LINKS },
  "24": { owners: ["55"], links: PR_LINKS },
  "10": { owners: NATIVE_OWNERS_R2, links: CAUSE_LINKS },
  "17": { owners: NATIVE_OWNERS_R2, links: CAUSE_LINKS },
  "28": { owners: NATIVE_OWNERS_R2, links: CAUSE_LINKS },
  "29": { owners: NATIVE_OWNERS_R2, links: CAUSE_LINKS },
  "14": { owners: COMPLETION_OWNERS_R2, links: COMPLETION_LINK_KEYS },
  "25": { owners: COMPLETION_OWNERS_R2, links: COMPLETION_LINK_KEYS },
  "31": { owners: COMPLETION_OWNERS_R2, links: COMPLETION_LINK_KEYS },
  "35": { owners: COMPLETION_OWNERS_R2, links: COMPLETION_LINK_KEYS },
  "22": { owners: ["53"], links: ["publication"] },
  "32": { owners: ["53"], links: ["publication"] },
  "23": { owners: ["54"], links: ["canary"] },
  "33": { owners: ["54"], links: ["canary"] },
  "41": { owners: ["48", "51", "52"], links: CAUSE_LINKS },
  "44": { owners: ["53"], links: ["publication"] },
  "45": { owners: ["54"], links: ["canary"] },
  "46": { owners: ["55"], links: PR_LINKS },
  "47": { owners: ["50", "56"], links: COMPLETION_LINK_KEYS },
});
const HALTED_PROOF_MAP_R2 = Object.freeze({
  "02": NATIVE_OWNERS_R2, "07": ["18", "19", "20", "42", "53", "54"], "09": NATIVE_OWNERS_R2,
  "12": ["18", "19", "20", "42", "53", "54"], "16": NATIVE_OWNERS_R2, "27": NATIVE_OWNERS_R2,
  "40": ["48", "51"],
});
const PAD = (n) => String(n).padStart(2, "0");
// Plan IDs reach three digits from 253-100 (R8). These helpers build, order and match ids numerically, so
// "253-100" sorts after "253-99" (a plain string sort would put it first).
export const planIdOf = (n) => `${PHASE}-${PAD(n)}`;
export const comparePlanIds = (a, b) => Number(String(a).replace(/^\d+-/, "")) - Number(String(b).replace(/^\d+-/, ""));
export function parsePlanFile(name) {
  const match = /^253-(\d{2,3})-(PLAN|SUMMARY)\.md$/.exec(name);
  return match ? { id: match[1], number: Number(match[1]), kind: match[2] } : null;
}
// Plan 253-43's receipts include THIS helper and its test, which later additive revisions (R3, plan
// 253-61) must edit. The R2 contract is committed and byte-pinned, so the two tooling receipts are held
// at the hashes recorded when R2 was generated instead of tracking the live, legitimately-edited bytes.
const FROZEN_TOOLING_RECEIPTS_R2 = Object.freeze({
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "52cc160d701a8dd15958500b1b3a1d97b84f2d4611b7d664278545d532bae0c0",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "b1c7fc715e5b08811a0b97893ede45e7947bd90da356856515867177401eaa3c",
});

function pinFile(repoRoot, relPath, label) {
  const bytes = readOrNull(join(repoRoot, relPath));
  if (bytes === null) throw new Error(`${label} ${relPath} is missing`);
  return sha256(bytes);
}

function buildContractR2({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const v1 = buildContractV1({ repoRoot });
  const partition = [...COMPLETED_IDS_R2, ...HALTED_IDS_R2, ...UNSTARTED_IDS_R2].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 47).map(PAD))) {
    throw new Error("R2 completed, halted and unstarted ids do not partition the 47 pre-R2 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R2.includes(id) ? "completed" : HALTED_IDS_R2.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...v1.originals];
  for (let n = 36; n <= 47; n += 1) {
    const id = PAD(n);
    const file = `253-${id}-PLAN.md`;
    originals.push({ plan: `253-${id}`, class: classOf(id), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...v1.completed_plans];
  for (const id of ["36", "37", "38", "39", "42", "43"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false, frozenReceipts: FROZEN_TOOLING_RECEIPTS_R2 });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...v1.halted_plans];
  const halted40 = describeSummary(repoRoot, phaseDir, "40", { requireReceipts: true });
  if (halted40.summary.status !== "halted") throw new Error(`halted plan 253-40 summary status is ${halted40.summary.status}`);
  halted.push(halted40);
  const closeout = JSON.parse(readFileSync(join(phaseDir, "253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json"), "utf8"));
  const responsibilities = UNSTARTED_IDS_R2.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R2[id];
    if (!mapping) throw new Error(`no R2 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R2.includes(owner) || UNSTARTED_IDS_R2.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const neverRan = NEVER_RAN_IDS_R2.includes(id);
    const blockedBy = neverRan ? ["253-40"] : closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} has no recorded blocking halt`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
      ...(neverRan ? { never_ran_reason: NEVER_RAN_REASON } : {}),
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R2.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R2[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 56).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = ids(36, 43).filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R2,
    revision: "r2",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME}`, "v1 contract") },
    sdk: v1.sdk,
    capture: v1.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted",
      targets: "only the twenty-three previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-56",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R3 revision (plan 253-61): 253-51 halted on a non-infrastructure native control failure, so 253-52..56
// can never run. R3 is ADDITIVE over v1 and R2 (both files, builders and the v1 default stay untouched)
// and re-points every never-executed responsibility to the R3 proof owners 253-57..253-68.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R3 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R3.json";
export const CONTRACT_SCHEMA_R3 = "sigra.phase253.load-recovery-reconciliation-contract/r3";
export const COMPLETED_IDS_R3 = Object.freeze([...COMPLETED_IDS_R2, "48", "49", "50"].sort());
export const HALTED_IDS_R3 = Object.freeze([...HALTED_IDS_R2, "51"]);
export const NEVER_RAN_IDS_R3 = Object.freeze(["52", "53", "54", "55", "56"]);
export const UNSTARTED_IDS_R3 = Object.freeze([...UNSTARTED_IDS_R2, ...NEVER_RAN_IDS_R3].sort());
export const NEVER_RAN_REASON_R3 = "dependency 253-51 halted on a non-infrastructure native control failure";
const NATIVE_OWNERS_R3 = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "63", "64"];
const COMPLETION_OWNERS_R3 = ["43", "50", "61", "68"];
const RESPONSIBILITY_MAP_R3 = Object.freeze({
  "08": { owners: ["42", "67"], links: PR_LINKS },
  "13": { owners: ["42", "67"], links: PR_LINKS },
  "21": { owners: ["42", "67"], links: PR_LINKS },
  "30": { owners: ["42", "67"], links: PR_LINKS },
  "34": { owners: ["42", "67"], links: PR_LINKS },
  "24": { owners: ["67"], links: PR_LINKS },
  "10": { owners: NATIVE_OWNERS_R3, links: CAUSE_LINKS },
  "17": { owners: NATIVE_OWNERS_R3, links: CAUSE_LINKS },
  "28": { owners: NATIVE_OWNERS_R3, links: CAUSE_LINKS },
  "29": { owners: NATIVE_OWNERS_R3, links: CAUSE_LINKS },
  "14": { owners: COMPLETION_OWNERS_R3, links: COMPLETION_LINK_KEYS },
  "25": { owners: COMPLETION_OWNERS_R3, links: COMPLETION_LINK_KEYS },
  "31": { owners: COMPLETION_OWNERS_R3, links: COMPLETION_LINK_KEYS },
  "35": { owners: COMPLETION_OWNERS_R3, links: COMPLETION_LINK_KEYS },
  "22": { owners: ["65"], links: ["publication"] },
  "32": { owners: ["65"], links: ["publication"] },
  "23": { owners: ["66"], links: ["canary"] },
  "33": { owners: ["66"], links: ["canary"] },
  "41": { owners: ["48", "62", "63", "64"], links: CAUSE_LINKS },
  "44": { owners: ["65"], links: ["publication"] },
  "45": { owners: ["66"], links: ["canary"] },
  "46": { owners: ["67"], links: PR_LINKS },
  "47": { owners: ["50", "61", "68"], links: COMPLETION_LINK_KEYS },
  "52": { owners: ["62", "63", "64"], links: CAUSE_LINKS },
  "53": { owners: ["65"], links: ["publication"] },
  "54": { owners: ["66"], links: ["canary"] },
  "55": { owners: ["67"], links: PR_LINKS },
  "56": { owners: ["61", "68"], links: COMPLETION_LINK_KEYS },
});
const HALTED_PROOF_MAP_R3 = Object.freeze({
  "02": NATIVE_OWNERS_R3, "07": ["18", "19", "20", "42", "65", "66"], "09": NATIVE_OWNERS_R3,
  "12": ["18", "19", "20", "42", "65", "66"], "16": NATIVE_OWNERS_R3, "27": NATIVE_OWNERS_R3,
  "40": ["48", "62", "63"],
  "51": ["57", "58", "59", "60", "62", "63"],
});

function buildContractR3({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r2 = buildContractR2({ repoRoot });
  const partition = [...COMPLETED_IDS_R3, ...HALTED_IDS_R3, ...UNSTARTED_IDS_R3].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 56).map(PAD))) {
    throw new Error("R3 completed, halted and unstarted ids do not partition the 56 pre-R3 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R3.includes(id) ? "completed" : HALTED_IDS_R3.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...r2.originals];
  for (let n = 48; n <= 56; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: `253-${PAD(n)}`, class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...r2.completed_plans];
  for (const id of ["48", "49", "50"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...r2.halted_plans];
  const halted51 = describeSummary(repoRoot, phaseDir, "51", { requireReceipts: true });
  if (halted51.summary.status !== "halted") throw new Error(`halted plan 253-51 summary status is ${halted51.summary.status}`);
  halted.push(halted51);
  const closeout = JSON.parse(readFileSync(join(phaseDir, "253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json"), "utf8"));
  const responsibilities = UNSTARTED_IDS_R3.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R3[id];
    if (!mapping) throw new Error(`no R3 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R3.includes(owner) || UNSTARTED_IDS_R3.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const neverRan40 = NEVER_RAN_IDS_R2.includes(id);
    const neverRan51 = NEVER_RAN_IDS_R3.includes(id);
    const blockedBy = neverRan51 ? ["253-51"] : neverRan40 ? ["253-40"] : closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} has no recorded blocking halt`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
      ...(neverRan40 ? { never_ran_reason: NEVER_RAN_REASON } : {}),
      ...(neverRan51 ? { never_ran_reason: NEVER_RAN_REASON_R3 } : {}),
      successor_revision: "R3",
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R3.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R3[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 68).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = [...ids(36, 43), ...ids(48, 51)].filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R3,
    revision: "r3",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: r2.v1_contract,
    r2_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME_R2}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME_R2}`, "R2 contract") },
    sdk: r2.sdk,
    capture: r2.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted",
      targets: "only the twenty-eight previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-68",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R4 revision (plan 253-71): 253-63 halted on a non-infrastructure runner validator rejection, so
// 253-64..68 can never run. R4 is ADDITIVE over v1, R2 and R3 (all three files, builders and the v1
// default stay untouched) and re-points every never-executed responsibility to the R4 proof owners
// 253-69..253-78.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R4 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R4.json";
export const CONTRACT_SCHEMA_R4 = "sigra.phase253.load-recovery-reconciliation-contract/r4";
export const COMPLETED_IDS_R4 = Object.freeze([...COMPLETED_IDS_R3, "57", "58", "59", "60", "61", "62"].sort());
export const HALTED_IDS_R4 = Object.freeze([...HALTED_IDS_R3, "63"]);
export const NEVER_RAN_IDS_R4 = Object.freeze(["64", "65", "66", "67", "68"]);
export const UNSTARTED_IDS_R4 = Object.freeze([...UNSTARTED_IDS_R3, ...NEVER_RAN_IDS_R4].sort());
export const NEVER_RAN_REASON_R4 = "dependency 253-63 halted on a non-infrastructure runner validator rejection";
const NATIVE_OWNERS_R4 = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "69", "70", "72", "73", "74"];
const COMPLETION_OWNERS_R4 = ["43", "50", "61", "71", "78"];
const RESPONSIBILITY_MAP_R4 = Object.freeze({
  "08": { owners: ["42", "77"], links: PR_LINKS },
  "13": { owners: ["42", "77"], links: PR_LINKS },
  "21": { owners: ["42", "77"], links: PR_LINKS },
  "30": { owners: ["42", "77"], links: PR_LINKS },
  "34": { owners: ["42", "77"], links: PR_LINKS },
  "24": { owners: ["77"], links: PR_LINKS },
  "10": { owners: NATIVE_OWNERS_R4, links: CAUSE_LINKS },
  "17": { owners: NATIVE_OWNERS_R4, links: CAUSE_LINKS },
  "28": { owners: NATIVE_OWNERS_R4, links: CAUSE_LINKS },
  "29": { owners: NATIVE_OWNERS_R4, links: CAUSE_LINKS },
  "14": { owners: COMPLETION_OWNERS_R4, links: COMPLETION_LINK_KEYS },
  "25": { owners: COMPLETION_OWNERS_R4, links: COMPLETION_LINK_KEYS },
  "31": { owners: COMPLETION_OWNERS_R4, links: COMPLETION_LINK_KEYS },
  "35": { owners: COMPLETION_OWNERS_R4, links: COMPLETION_LINK_KEYS },
  "22": { owners: ["75"], links: ["publication"] },
  "32": { owners: ["75"], links: ["publication"] },
  "23": { owners: ["76"], links: ["canary"] },
  "33": { owners: ["76"], links: ["canary"] },
  "41": { owners: ["48", "62", "72", "73", "74"], links: CAUSE_LINKS },
  "44": { owners: ["75"], links: ["publication"] },
  "45": { owners: ["76"], links: ["canary"] },
  "46": { owners: ["77"], links: PR_LINKS },
  "47": { owners: ["50", "61", "71", "78"], links: COMPLETION_LINK_KEYS },
  "52": { owners: ["62", "72", "73", "74"], links: CAUSE_LINKS },
  "53": { owners: ["75"], links: ["publication"] },
  "54": { owners: ["76"], links: ["canary"] },
  "55": { owners: ["77"], links: PR_LINKS },
  "56": { owners: ["71", "78"], links: COMPLETION_LINK_KEYS },
  "64": { owners: ["72", "73", "74"], links: CAUSE_LINKS },
  "65": { owners: ["75"], links: ["publication"] },
  "66": { owners: ["76"], links: ["canary"] },
  "67": { owners: ["77"], links: PR_LINKS },
  "68": { owners: ["71", "78"], links: COMPLETION_LINK_KEYS },
});
const HALTED_PROOF_MAP_R4 = Object.freeze({
  "02": NATIVE_OWNERS_R4, "07": ["18", "19", "20", "42", "75", "76"], "09": NATIVE_OWNERS_R4,
  "12": ["18", "19", "20", "42", "75", "76"], "16": NATIVE_OWNERS_R4, "27": NATIVE_OWNERS_R4,
  "40": ["48", "62", "72", "73"],
  "51": ["57", "58", "59", "60", "62", "69", "70", "72", "73"],
  "63": ["69", "70", "72", "73"],
});
// Plan 253-61's receipts include THIS helper and its test, which R4 (plan 253-71) must edit. The R3
// completion record is held at the bytes recorded in commit 50e6592b96ce8786a7ed463fe1c0ff4d0ce986be, so
// legitimate later edits never drift the committed r4 contract (the same technique plan 253-61 used for R2).
const FROZEN_TOOLING_RECEIPTS_R4 = Object.freeze({
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "236304e686e89015a9f292545925fb9e5e10ca8965d507923e662a1cd3ff039f",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "c91a02f5c951d50e7674ea60a68b4416a1a780f3b8c54079cd657d72db246c38",
});

function buildContractR4({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r3 = buildContractR3({ repoRoot });
  const partition = [...COMPLETED_IDS_R4, ...HALTED_IDS_R4, ...UNSTARTED_IDS_R4].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 68).map(PAD))) {
    throw new Error("R4 completed, halted and unstarted ids do not partition the 68 pre-R4 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R4.includes(id) ? "completed" : HALTED_IDS_R4.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...r3.originals];
  for (let n = 57; n <= 68; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: `253-${PAD(n)}`, class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...r3.completed_plans];
  for (const id of ["57", "58", "59", "60", "61", "62"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false, frozenReceipts: FROZEN_TOOLING_RECEIPTS_R4 });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...r3.halted_plans];
  const halted63 = describeSummary(repoRoot, phaseDir, "63", { requireReceipts: true });
  if (halted63.summary.status !== "halted") throw new Error(`halted plan 253-63 summary status is ${halted63.summary.status}`);
  halted.push(halted63);
  const closeout = JSON.parse(readFileSync(join(phaseDir, "253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json"), "utf8"));
  const responsibilities = UNSTARTED_IDS_R4.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R4[id];
    if (!mapping) throw new Error(`no R4 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R4.includes(owner) || UNSTARTED_IDS_R4.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const neverRan40 = NEVER_RAN_IDS_R2.includes(id);
    const neverRan51 = NEVER_RAN_IDS_R3.includes(id);
    const neverRan63 = NEVER_RAN_IDS_R4.includes(id);
    const blockedBy = neverRan63 ? ["253-63"] : neverRan51 ? ["253-51"] : neverRan40 ? ["253-40"] : closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} has no recorded blocking halt`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
      ...(neverRan40 ? { never_ran_reason: NEVER_RAN_REASON } : {}),
      ...(neverRan51 ? { never_ran_reason: NEVER_RAN_REASON_R3 } : {}),
      ...(neverRan63 ? { never_ran_reason: NEVER_RAN_REASON_R4 } : {}),
      successor_revision: "R4",
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R4.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R4[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 78).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = [...ids(36, 43), ...ids(48, 51), ...ids(57, 63)].filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R4,
    revision: "r4",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: r3.v1_contract,
    r2_contract: r3.r2_contract,
    r3_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME_R3}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME_R3}`, "R3 contract") },
    sdk: r3.sdk,
    capture: r3.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted",
      targets: "only the thirty-three previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-78",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R5 revision (plan 253-81): 253-73 halted on a non-infrastructure runner account-count query defect,
// so 253-74..78 can never run. R5 is ADDITIVE over v1, R2, R3 and R4 (all four files, builders and the
// v1 default stay untouched) and re-points every never-executed responsibility to the R5 proof owners
// 253-79..253-88.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R5 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R5.json";
export const CONTRACT_SCHEMA_R5 = "sigra.phase253.load-recovery-reconciliation-contract/r5";
export const COMPLETED_IDS_R5 = Object.freeze([...COMPLETED_IDS_R4, "69", "70", "71", "72"].sort());
export const HALTED_IDS_R5 = Object.freeze([...HALTED_IDS_R4, "73"]);
export const NEVER_RAN_IDS_R5 = Object.freeze(["74", "75", "76", "77", "78"]);
export const UNSTARTED_IDS_R5 = Object.freeze([...UNSTARTED_IDS_R4, ...NEVER_RAN_IDS_R5].sort());
export const NEVER_RAN_REASON_R5 = "dependency 253-73 halted on a non-infrastructure runner account-count query defect";
const NATIVE_OWNERS_R5 = ["36", "37", "38", "39", "48", "57", "58", "59", "60", "62", "69", "70", "72", "79", "80", "82", "83", "84"];
const COMPLETION_OWNERS_R5 = ["43", "50", "61", "71", "81", "88"];
const RESPONSIBILITY_MAP_R5 = Object.freeze({
  "08": { owners: ["42", "87"], links: PR_LINKS },
  "13": { owners: ["42", "87"], links: PR_LINKS },
  "21": { owners: ["42", "87"], links: PR_LINKS },
  "30": { owners: ["42", "87"], links: PR_LINKS },
  "34": { owners: ["42", "87"], links: PR_LINKS },
  "24": { owners: ["87"], links: PR_LINKS },
  "10": { owners: NATIVE_OWNERS_R5, links: CAUSE_LINKS },
  "17": { owners: NATIVE_OWNERS_R5, links: CAUSE_LINKS },
  "28": { owners: NATIVE_OWNERS_R5, links: CAUSE_LINKS },
  "29": { owners: NATIVE_OWNERS_R5, links: CAUSE_LINKS },
  "14": { owners: COMPLETION_OWNERS_R5, links: COMPLETION_LINK_KEYS },
  "25": { owners: COMPLETION_OWNERS_R5, links: COMPLETION_LINK_KEYS },
  "31": { owners: COMPLETION_OWNERS_R5, links: COMPLETION_LINK_KEYS },
  "35": { owners: COMPLETION_OWNERS_R5, links: COMPLETION_LINK_KEYS },
  "22": { owners: ["85"], links: ["publication"] },
  "32": { owners: ["85"], links: ["publication"] },
  "23": { owners: ["86"], links: ["canary"] },
  "33": { owners: ["86"], links: ["canary"] },
  "41": { owners: ["48", "62", "72", "82", "83", "84"], links: CAUSE_LINKS },
  "44": { owners: ["85"], links: ["publication"] },
  "45": { owners: ["86"], links: ["canary"] },
  "46": { owners: ["87"], links: PR_LINKS },
  "47": { owners: ["50", "61", "71", "81", "88"], links: COMPLETION_LINK_KEYS },
  "52": { owners: ["62", "72", "82", "83", "84"], links: CAUSE_LINKS },
  "53": { owners: ["85"], links: ["publication"] },
  "54": { owners: ["86"], links: ["canary"] },
  "55": { owners: ["87"], links: PR_LINKS },
  "56": { owners: ["71", "81", "88"], links: COMPLETION_LINK_KEYS },
  "64": { owners: ["72", "82", "83", "84"], links: CAUSE_LINKS },
  "65": { owners: ["85"], links: ["publication"] },
  "66": { owners: ["86"], links: ["canary"] },
  "67": { owners: ["87"], links: PR_LINKS },
  "68": { owners: ["71", "81", "88"], links: COMPLETION_LINK_KEYS },
  "74": { owners: ["82", "83", "84"], links: CAUSE_LINKS },
  "75": { owners: ["85"], links: ["publication"] },
  "76": { owners: ["86"], links: ["canary"] },
  "77": { owners: ["87"], links: PR_LINKS },
  "78": { owners: ["81", "88"], links: COMPLETION_LINK_KEYS },
});
const HALTED_PROOF_MAP_R5 = Object.freeze({
  "02": NATIVE_OWNERS_R5, "07": ["18", "19", "20", "42", "85", "86"], "09": NATIVE_OWNERS_R5,
  "12": ["18", "19", "20", "42", "85", "86"], "16": NATIVE_OWNERS_R5, "27": NATIVE_OWNERS_R5,
  "40": ["48", "62", "72", "82", "83"],
  "51": ["57", "58", "59", "60", "62", "69", "70", "72", "79", "80", "82", "83"],
  "63": ["69", "70", "72", "79", "80", "82", "83"],
  "73": ["79", "80", "82", "83"],
});
// Plan 253-71's receipts name THIS helper and its test, which R5 (plan 253-81) must edit. They are held
// at the bytes recorded in commit 65d670c0c, per plan: 253-61 names the same paths at different bytes
// (FROZEN_TOOLING_RECEIPTS_R4), so a single shared map would be wrong for one of them.
const FROZEN_TOOLING_RECEIPTS_R5_PLAN_71 = Object.freeze({
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "1bf7dbdc6ff1a46e51ea53763fbe54596361be45eb78a769e72067ccfccc2048",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "410cb744fcb26a946f12b2e18f382a802bc837e6ae8d9e54f214e79a6a197fc6",
});

function buildContractR5({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r4 = buildContractR4({ repoRoot });
  const partition = [...COMPLETED_IDS_R5, ...HALTED_IDS_R5, ...UNSTARTED_IDS_R5].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 78).map(PAD))) {
    throw new Error("R5 completed, halted and unstarted ids do not partition the 78 pre-R5 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R5.includes(id) ? "completed" : HALTED_IDS_R5.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...r4.originals];
  for (let n = 69; n <= 78; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: `253-${PAD(n)}`, class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...r4.completed_plans];
  for (const id of ["69", "70", "71", "72"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false, frozenReceipts: id === "71" ? FROZEN_TOOLING_RECEIPTS_R5_PLAN_71 : {} });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...r4.halted_plans];
  const halted73 = describeSummary(repoRoot, phaseDir, "73", { requireReceipts: true });
  if (halted73.summary.status !== "halted") throw new Error(`halted plan 253-73 summary status is ${halted73.summary.status}`);
  halted.push(halted73);
  const closeout = JSON.parse(readFileSync(join(phaseDir, "253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json"), "utf8"));
  const responsibilities = UNSTARTED_IDS_R5.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R5[id];
    if (!mapping) throw new Error(`no R5 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R5.includes(owner) || UNSTARTED_IDS_R5.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const neverRan40 = NEVER_RAN_IDS_R2.includes(id);
    const neverRan51 = NEVER_RAN_IDS_R3.includes(id);
    const neverRan63 = NEVER_RAN_IDS_R4.includes(id);
    const neverRan73 = NEVER_RAN_IDS_R5.includes(id);
    const blockedBy = neverRan73 ? ["253-73"] : neverRan63 ? ["253-63"] : neverRan51 ? ["253-51"] : neverRan40 ? ["253-40"] : closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} has no recorded blocking halt`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
      ...(neverRan40 ? { never_ran_reason: NEVER_RAN_REASON } : {}),
      ...(neverRan51 ? { never_ran_reason: NEVER_RAN_REASON_R3 } : {}),
      ...(neverRan63 ? { never_ran_reason: NEVER_RAN_REASON_R4 } : {}),
      ...(neverRan73 ? { never_ran_reason: NEVER_RAN_REASON_R5 } : {}),
      successor_revision: "R5",
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R5.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R5[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 88).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = [...ids(36, 43), ...ids(48, 51), ...ids(57, 63), ...ids(69, 73)].filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R5,
    revision: "r5",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: r4.v1_contract,
    r2_contract: r4.r2_contract,
    r3_contract: r4.r3_contract,
    r4_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME_R4}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME_R4}`, "R4 contract") },
    sdk: r4.sdk,
    capture: r4.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted",
      targets: "only the thirty-eight previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-88",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R6 revision (plan 253-90): 253-84 halted on its insufficient-proof branch (no source-bound historical
// registration cause), so 253-85..88 can never run. Jon approved a not_reproduced target disposition
// (253-89), so completion is gated by --require-dispositioned: CIREL-02 is accepted by the linked
// evidence and CIREL-01 is recorded partial, never accepted. R6 is ADDITIVE over v1-R5 (all five files,
// builders and the v1 default stay untouched) and re-points every never-executed responsibility to the R6
// proof owners 253-89..253-94.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R6 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R6.json";
export const CONTRACT_SCHEMA_R6 = "sigra.phase253.load-recovery-reconciliation-contract/r6";
export const COMPLETED_IDS_R6 = Object.freeze([...COMPLETED_IDS_R5, "79", "80", "81", "82", "83"].sort());
export const HALTED_IDS_R6 = Object.freeze([...HALTED_IDS_R5, "84"]);
export const NEVER_RAN_IDS_R6 = Object.freeze(["85", "86", "87", "88"]);
export const UNSTARTED_IDS_R6 = Object.freeze([...UNSTARTED_IDS_R5, ...NEVER_RAN_IDS_R6].sort());
export const NEVER_RAN_REASON_R6 = "dependency 253-84 halted on its insufficient-proof branch: no source-bound historical registration cause";
// R5 owner -> R6 owners: 84 (halted) becomes the disposition plan 89; 85/86/87 become 91/92/93; 88 (never run) becomes 90 and 94.
const OWNER_REMAP_R6 = Object.freeze({ "84": ["89"], "85": ["91"], "86": ["92"], "87": ["93"], "88": ["90", "94"] });
const remapOwners = (owners) => owners.flatMap((owner) => OWNER_REMAP_R6[owner] ?? [owner]);
const RESPONSIBILITY_MAP_R6 = Object.freeze({
  ...Object.fromEntries(Object.entries(RESPONSIBILITY_MAP_R5).map(([id, row]) => [id, { owners: remapOwners(row.owners), links: row.links }])),
  "85": { owners: ["91"], links: ["publication"] },
  "86": { owners: ["92"], links: ["canary"] },
  "87": { owners: ["93"], links: PR_LINKS },
  "88": { owners: ["90", "94"], links: [...COMPLETION_LINK_KEYS, "load_target_disposition"] },
});
const HALTED_PROOF_MAP_R6 = Object.freeze({
  ...Object.fromEntries(Object.entries(HALTED_PROOF_MAP_R5).map(([id, owners]) => [id, remapOwners(owners)])),
  "84": ["89", "90"],
});
// Plan 253-81's receipts name THIS helper and its test, which R6 (plan 253-90) must edit. They are held
// at the bytes of the 253-81 Task 1 GREEN commit 4bb3f303a, per plan (253-61 and 253-71 hold the same
// paths at different bytes).
const FROZEN_TOOLING_RECEIPTS_R6_PLAN_81 = Object.freeze({
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "9f1ff7f7e1ca455d722a725a3608aa7907c7b36aa4745fe623a1ee807a4b8a83",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "dcae48ec9f39b87f8448363ccfaca01443fc3be33ff7d54939dad09d56030c6f",
});

function buildContractR6({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r5 = buildContractR5({ repoRoot });
  const partition = [...COMPLETED_IDS_R6, ...HALTED_IDS_R6, ...UNSTARTED_IDS_R6].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 88).map(PAD))) {
    throw new Error("R6 completed, halted and unstarted ids do not partition the 88 pre-R6 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R6.includes(id) ? "completed" : HALTED_IDS_R6.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...r5.originals];
  for (let n = 79; n <= 88; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: `253-${PAD(n)}`, class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...r5.completed_plans];
  for (const id of ["79", "80", "81", "82", "83"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false, frozenReceipts: id === "81" ? FROZEN_TOOLING_RECEIPTS_R6_PLAN_81 : {} });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...r5.halted_plans];
  const halted84 = describeSummary(repoRoot, phaseDir, "84", { requireReceipts: true });
  if (halted84.summary.status !== "halted") throw new Error(`halted plan 253-84 summary status is ${halted84.summary.status}`);
  halted.push(halted84);
  const closeout = JSON.parse(readFileSync(join(phaseDir, "253-CONTROL-RECOVERY-EXECUTION-CLOSEOUT.json"), "utf8"));
  const responsibilities = UNSTARTED_IDS_R6.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R6[id];
    if (!mapping) throw new Error(`no R6 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R6.includes(owner) || UNSTARTED_IDS_R6.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    const neverRan40 = NEVER_RAN_IDS_R2.includes(id);
    const neverRan51 = NEVER_RAN_IDS_R3.includes(id);
    const neverRan63 = NEVER_RAN_IDS_R4.includes(id);
    const neverRan73 = NEVER_RAN_IDS_R5.includes(id);
    const neverRan84 = NEVER_RAN_IDS_R6.includes(id);
    const blockedBy = neverRan84 ? ["253-84"] : neverRan73 ? ["253-73"] : neverRan63 ? ["253-63"] : neverRan51 ? ["253-51"] : neverRan40 ? ["253-40"] : closeout.blocked_plans[`253-${id}`];
    if (!Array.isArray(blockedBy) || blockedBy.length === 0) throw new Error(`253-${id} has no recorded blocking halt`);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: blockedBy,
      owners: mapping.owners.map((owner) => `253-${owner}`),
      required_links: [...mapping.links],
      disposition: { ...DISPOSITION_FIELDS },
      ...(neverRan40 ? { never_ran_reason: NEVER_RAN_REASON } : {}),
      ...(neverRan51 ? { never_ran_reason: NEVER_RAN_REASON_R3 } : {}),
      ...(neverRan63 ? { never_ran_reason: NEVER_RAN_REASON_R4 } : {}),
      ...(neverRan73 ? { never_ran_reason: NEVER_RAN_REASON_R5 } : {}),
      ...(neverRan84 ? { never_ran_reason: NEVER_RAN_REASON_R6 } : {}),
      successor_revision: "R6",
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R6.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R6[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 94).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = [...ids(36, 43), ...ids(48, 51), ...ids(57, 63), ...ids(69, 73), ...ids(79, 84), 89].filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R6,
    revision: "r6",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: r5.v1_contract,
    r2_contract: r5.r2_contract,
    r3_contract: r5.r3_contract,
    r4_contract: r5.r4_contract,
    r5_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME_R5}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME_R5}`, "R5 contract") },
    sdk: r5.sdk,
    capture: r5.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned",
      targets: "only the forty-two previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-94",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked", "reporting CIREL-01 as accepted"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R7 revision (plan 253-96): 253-92 halted at publication because the publisher's candidate commit
// readback compared a newline-terminated message with GitHub's stripped message, so 253-93 and 253-94 can
// never run. R7 is ADDITIVE over v1-R6 (all six files, builders and the v1 default stay untouched). It
// re-points every never-executed responsibility, including 93 and 94, to the R7 proof owners 253-95..253-99
// and is gated by --require-dispositioned exactly as R6 is.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R7 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R7.json";
export const CONTRACT_SCHEMA_R7 = "sigra.phase253.load-recovery-reconciliation-contract/r7";
export const COMPLETED_IDS_R7 = Object.freeze([...COMPLETED_IDS_R6, "89", "90", "91"].sort());
export const HALTED_IDS_R7 = Object.freeze([...HALTED_IDS_R6, "92"]);
export const NEVER_RAN_IDS_R7 = Object.freeze(["93", "94"]);
export const UNSTARTED_IDS_R7 = Object.freeze([...UNSTARTED_IDS_R6, ...NEVER_RAN_IDS_R7].sort());
export const NEVER_RAN_REASON_R7 = "dependency 253-92 halted at publication: the publisher's candidate commit readback compared a newline-terminated message with GitHub's stripped message";
// R6 owner -> R7 owners: 91 stays and gains 95 (which re-derived the freeze); halted 92 becomes 97; never-run 93 becomes 98;
// never-run 94 becomes 96 and 99.
const OWNER_REMAP_R7 = Object.freeze({ "91": ["91", "95"], "92": ["97"], "93": ["98"], "94": ["96", "99"] });
const remapOwnersR7 = (owners) => owners.flatMap((owner) => OWNER_REMAP_R7[owner] ?? [owner]);
const RESPONSIBILITY_MAP_R7 = Object.freeze({
  ...Object.fromEntries(Object.entries(RESPONSIBILITY_MAP_R6).map(([id, row]) => [id, { owners: remapOwnersR7(row.owners), links: row.links }])),
  "93": { owners: ["98"], links: PR_LINKS },
  "94": { owners: ["96", "99"], links: [...COMPLETION_LINK_KEYS, "load_target_disposition"] },
});
const HALTED_PROOF_MAP_R7 = Object.freeze({
  ...Object.fromEntries(Object.entries(HALTED_PROOF_MAP_R6).map(([id, owners]) => [id, remapOwnersR7(owners)])),
  "92": ["95", "97"],
});

// Plan 253-90's receipts name THIS helper and its test, which R7 (plan 253-96) must edit. They are held at the
// bytes of the last 253-90 commit that touched each file (6eb2fbbad), read with git rather than invented.
const FROZEN_TOOLING_RECEIPTS_R7_PLAN_90 = Object.freeze({
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.mjs`]: "1f2f600eb383215400ddae459c23ae22602f36defe97db5f3b25ba86962769e3",
  [`${PHASE_DIR_REL}/253-LOAD-RECOVERY-reconcile.test.mjs`]: "bf652d4e7ceb3919aeda75438841bdabe8ae424bdf2ba72eb5c865a057af385a",
});

function buildContractR7({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r6 = buildContractR6({ repoRoot });
  const partition = [...COMPLETED_IDS_R7, ...HALTED_IDS_R7, ...UNSTARTED_IDS_R7].sort();
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 94).map(PAD))) {
    throw new Error("R7 completed, halted and unstarted ids do not partition the 94 pre-R7 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R7.includes(id) ? "completed" : HALTED_IDS_R7.includes(id) ? "halted" : "unstarted_blocked");
  const originals = [...r6.originals];
  for (let n = 89; n <= 94; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: `253-${PAD(n)}`, class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const byNumber = (a, b) => a.plan.localeCompare(b.plan);
  const completed = [...r6.completed_plans];
  for (const id of ["89", "90", "91"]) {
    const described = describeSummary(repoRoot, phaseDir, id, { requireReceipts: false, frozenReceipts: id === "90" ? FROZEN_TOOLING_RECEIPTS_R7_PLAN_90 : {} });
    if (described.summary.status === "halted" || described.summary.status === "blocked") throw new Error(`completed plan 253-${id} has status ${described.summary.status}`);
    completed.push(described);
  }
  completed.sort(byNumber);
  const halted = [...r6.halted_plans];
  const halted92 = describeSummary(repoRoot, phaseDir, "92", { requireReceipts: true });
  if (halted92.summary.status !== "halted") throw new Error(`halted plan 253-92 summary status is ${halted92.summary.status}`);
  halted.push(halted92);
  const r6Rows = Object.fromEntries(r6.responsibilities.map((row) => [row.plan.slice(4), row]));
  const responsibilities = UNSTARTED_IDS_R7.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R7[id];
    if (!mapping) throw new Error(`no R7 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R7.includes(owner) || UNSTARTED_IDS_R7.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const common = { owners: mapping.owners.map((owner) => `253-${owner}`), required_links: [...mapping.links], successor_revision: "R7" };
    if (r6Rows[id]) return { ...r6Rows[id], ...common };
    if (!NEVER_RAN_IDS_R7.includes(id)) throw new Error(`253-${id} is neither an R6 responsibility nor a never-ran R7 plan`);
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: ["253-92"],
      owners: common.owners,
      required_links: common.required_links,
      disposition: { ...DISPOSITION_FIELDS },
      never_ran_reason: NEVER_RAN_REASON_R7,
      successor_revision: "R7",
    };
  });
  const haltedProof = Object.fromEntries(HALTED_IDS_R7.map((id) => [`253-${id}`, HALTED_PROOF_MAP_R7[id].map((owner) => `253-${owner}`)]));
  for (const owners of Object.values(haltedProof)) {
    for (const owner of owners) if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`halted proof owner ${owner} is missing`);
  }
  const planPins = ids(1, 99).map((n) => {
    const file = `253-${PAD(n)}-PLAN.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") };
  });
  const summaryPins = [...ids(36, 43), ...ids(48, 51), ...ids(57, 63), ...ids(69, 73), ...ids(79, 84), ...ids(89, 92), 95].filter((n) => existsSync(join(phaseDir, `253-${PAD(n)}-SUMMARY.md`))).map((n) => {
    const file = `253-${PAD(n)}-SUMMARY.md`;
    return { plan: `253-${PAD(n)}`, path: `${PHASE_DIR_REL}/${file}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "summary") };
  });
  return {
    schema: CONTRACT_SCHEMA_R7,
    revision: "r7",
    phase: PHASE,
    phase_dir: PHASE_DIR_REL,
    v1_contract: r6.v1_contract,
    r2_contract: r6.r2_contract,
    r3_contract: r6.r3_contract,
    r4_contract: r6.r4_contract,
    r5_contract: r6.r5_contract,
    r6_contract: { path: `${PHASE_DIR_REL}/${CONTRACT_NAME_R6}`, sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${CONTRACT_NAME_R6}`, "R6 contract") },
    sdk: r6.sdk,
    capture: r6.capture,
    plan_pins: planPins,
    summary_pins: summaryPins,
    originals,
    completed_plans: completed,
    halted_plans: halted,
    halted_proof_map: haltedProof,
    responsibilities,
    application: {
      root_only: true,
      write_ahead: true,
      accepted_only_predicate: "scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned",
      targets: "only the forty-four previously nonexistent SUMMARY paths; existing files are never overwritten",
      bundle_requires_final_summary_of: "253-99",
      then_run: "$gsd-execute-phase 253 (unfiltered; security, review, Nyquist, regression and goal verification)",
      never: ["filtered completion", "phase.complete before whole-phase verification", "editing an original plan", "editing a halted summary", "claiming an old task ran", "writing status: blocked", "reporting CIREL-01 as accepted"],
    },
  };
}

// ---------------------------------------------------------------------------------------------
// R8 revision (plan 253-103): 253-97 halted at the full-pass preflight because the canary driver passed the
// whole regex match plus a literal [1] suffix as the check_runs commit_sha route parameter, so 253-98 and
// 253-99 can never run. R8 is ADDITIVE over v1-R7 (all seven files, builders and the v1 default stay
// untouched). It re-points every never-executed responsibility, including 98 and 99, to the R8 proof owners
// 253-100..253-106 and is gated by --require-dispositioned exactly as R6 and R7 are.
// ---------------------------------------------------------------------------------------------
export const CONTRACT_NAME_R8 = "253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R8.json";
export const CONTRACT_SCHEMA_R8 = "sigra.phase253.load-recovery-reconciliation-contract/r8";
export const COMPLETED_IDS_R8 = Object.freeze([...COMPLETED_IDS_R7, "95", "96"].sort());
export const HALTED_IDS_R8 = Object.freeze([...HALTED_IDS_R7, "97"]);
export const NEVER_RAN_IDS_R8 = Object.freeze(["98", "99"]);
export const UNSTARTED_IDS_R8 = Object.freeze([...UNSTARTED_IDS_R7, ...NEVER_RAN_IDS_R8].sort());
export const NEVER_RAN_REASON_R8 = "dependency 253-97 halted at the full-pass preflight: the canary driver passed the whole regex match plus a literal [1] suffix as the check_runs commit_sha route parameter, which the transport refused";
// R7 owner -> R8 owners: 95 stays and gains 102 (which re-derived the freeze); 96 stays and gains 103 (this
// contract); halted 97 becomes 104; never-run 98 becomes 105; never-run 99 becomes 103 and 106. Duplicates
// produced by the remap are dropped, keeping first-seen order.
export const OWNER_REMAP_R8 = Object.freeze({ "95": ["95", "102"], "96": ["96", "103"], "97": ["104"], "98": ["105"], "99": ["103", "106"] });
const remapOwnersR8 = (owners) => [...new Set(owners.flatMap((owner) => OWNER_REMAP_R8[owner] ?? [owner]))];
const RESPONSIBILITY_MAP_R8 = Object.freeze({
  ...Object.fromEntries(Object.entries(RESPONSIBILITY_MAP_R7).map(([id, row]) => [id, { owners: remapOwnersR8(row.owners), links: row.links }])),
  "98": { owners: ["105"], links: PR_LINKS },
  "99": { owners: ["103", "106"], links: [...COMPLETION_LINK_KEYS, "load_target_disposition"] },
});

function buildContractR8({ repoRoot = REPO_ROOT } = {}) {
  const phaseDir = join(repoRoot, PHASE_DIR_REL);
  const r7 = buildContractR7({ repoRoot });
  const partition = [...COMPLETED_IDS_R8, ...HALTED_IDS_R8, ...UNSTARTED_IDS_R8].sort(comparePlanIds);
  if (JSON.stringify(partition) !== JSON.stringify(ids(1, 99).map(PAD))) {
    throw new Error("R8 completed, halted and unstarted ids do not partition the 99 pre-R8 plans");
  }
  const classOf = (id) => (COMPLETED_IDS_R8.includes(id) ? "completed" : HALTED_IDS_R8.includes(id) ? "halted" : "unstarted_blocked");
  const originals = r7.originals.map((original) => ({ ...original }));
  for (let n = 95; n <= 99; n += 1) {
    const file = `253-${PAD(n)}-PLAN.md`;
    originals.push({ plan: planIdOf(n), class: classOf(PAD(n)), plan_path: `${PHASE_DIR_REL}/${file}`, plan_sha256: pinFile(repoRoot, `${PHASE_DIR_REL}/${file}`, "plan") });
  }
  for (const original of originals) original.class = classOf(original.plan.slice(4));
  const r7Rows = Object.fromEntries(r7.responsibilities.map((row) => [row.plan.slice(4), row]));
  const responsibilities = UNSTARTED_IDS_R8.map((id) => {
    const mapping = RESPONSIBILITY_MAP_R8[id];
    if (!mapping) throw new Error(`no R8 mapping for 253-${id}`);
    for (const owner of mapping.owners) {
      if (!existsSync(join(phaseDir, `253-${owner}-PLAN.md`))) throw new Error(`proof owner plan 253-${owner} is missing`);
      if (HALTED_IDS_R8.includes(owner) || UNSTARTED_IDS_R8.includes(owner)) throw new Error(`proof owner 253-${owner} is a halted or never-executed plan`);
    }
    const common = { owners: mapping.owners.map((owner) => `253-${owner}`), required_links: [...mapping.links], successor_revision: "R8" };
    if (r7Rows[id]) return { ...r7Rows[id], ...common };
    if (!NEVER_RAN_IDS_R8.includes(id)) throw new Error(`253-${id} is neither an R7 responsibility nor a never-ran R8 plan`);
    const text = readFileSync(join(phaseDir, `253-${id}-PLAN.md`), "utf8");
    const fm = frontmatter(text);
    return {
      plan: `253-${id}`,
      disposition_path: `${PHASE_DIR_REL}/253-${id}-SUMMARY.md`,
      original_plan_sha256: originals.find((o) => o.plan === `253-${id}`).plan_sha256,
      objective: objectiveOf(text),
      requirements: parseList(fm.requirements),
      depends_on: parseList(fm.depends_on),
      blocked_by: ["253-97"],
      owners: common.owners,
      required_links: common.required_links,
      disposition: { ...DISPOSITION_FIELDS },
      never_ran_reason: NEVER_RAN_REASON_R8,
      successor_revision: "R8",
    };
  });
  return {
    ...r7,
    schema: CONTRACT_SCHEMA_R8,
    revision: "r8",
    originals,
    responsibilities,
  };
}

export function buildContract({ repoRoot = REPO_ROOT, revision = "v1" } = {}) {
  if (revision === "v1") return buildContractV1({ repoRoot });
  if (revision === "r2") return buildContractR2({ repoRoot });
  if (revision === "r3") return buildContractR3({ repoRoot });
  if (revision === "r4") return buildContractR4({ repoRoot });
  if (revision === "r5") return buildContractR5({ repoRoot });
  if (revision === "r6") return buildContractR6({ repoRoot });
  if (revision === "r7") return buildContractR7({ repoRoot });
  if (revision === "r8") return buildContractR8({ repoRoot });
  throw new Error(`unknown revision ${revision}; expected one of ${REVISIONS.join(", ")}`);
}

export function contractPathFor(revision = "v1") {
  if (!REVISIONS.includes(revision)) throw new Error(`unknown revision ${revision}; expected one of ${REVISIONS.join(", ")}`);
  return join(HERE, revision === "r8" ? CONTRACT_NAME_R8 : revision === "r7" ? CONTRACT_NAME_R7 : revision === "r6" ? CONTRACT_NAME_R6 : revision === "r5" ? CONTRACT_NAME_R5 : revision === "r4" ? CONTRACT_NAME_R4 : revision === "r3" ? CONTRACT_NAME_R3 : revision === "r2" ? CONTRACT_NAME_R2 : CONTRACT_NAME);
}

export function serializeContract(contract) {
  return `${JSON.stringify(contract, null, 2)}\n`;
}

export function loadContract(path = join(HERE, CONTRACT_NAME)) {
  const text = readFileSync(path, "utf8");
  return { contract: JSON.parse(text), text, sha256: sha256(text) };
}

// ---------------------------------------------------------------------------------------------
// Disposition rendering, preflight and the accepted-only bundle
// ---------------------------------------------------------------------------------------------
function relativeOrGiven(root, path) {
  const abs = resolve(path);
  const base = resolve(root);
  return abs === base || abs.startsWith(`${base}/`) ? abs.slice(base.length + 1) : path;
}

export function renderDisposition({ responsibility, completion, links, verifier, contractSha256, revision = "v1" }) {
  const dispositioned = isDispositioned(revision);
  const lines = [
    "---",
    "phase: 253-fix-flaky-ci-and-preserve-required-checks",
    `plan: "${responsibility.plan.slice(4)}"`,
    "subsystem: ci-reliability",
    dispositioned ? "tags: [historical-disposition, load-recovery, dispositioned]" : "tags: [historical-disposition, load-recovery, accepted-only]",
    `status: ${DISPOSITION_FIELDS.status}`,
    `execution_performed: ${DISPOSITION_FIELDS.execution_performed}`,
    `original_status: ${DISPOSITION_FIELDS.original_status}`,
    `phase_verification_status: ${DISPOSITION_FIELDS.phase_verification_status}`,
    `superseded_by: [${responsibility.owners.map((o) => `"${o}"`).join(", ")}]`,
    `original_plan_sha256: ${responsibility.original_plan_sha256}`,
    `original_blocked_by: [${responsibility.blocked_by.map((o) => `"${o}"`).join(", ")}]`,
    dispositioned ? "dispositioned_by:" : "accepted_by:",
    `  contract_sha256: ${contractSha256}`,
    `  completion_path: ${completion.path}`,
    `  completion_sha256: ${completion.sha256}`,
    `  verifier_kind: ${verifier.kind}`,
    `  verifier_sha256: ${verifier.sha256 ?? "null"}`,
    "  links:",
    ...links.flatMap((link) => [`    - link: ${link.link}`, `      path: ${link.path}`, `      sha256: ${link.sha256}`]),
    `requirements: [${responsibility.requirements.map((r) => `"${r}"`).join(", ")}]`,
    "requirements-completed: []",
    "coverage: []",
    "---",
    "",
    `# Phase 253 Plan ${responsibility.plan.slice(4)}: historical routing disposition`,
    "",
    `**Original objective (not executed): ${responsibility.objective}**`,
    "",
    "## What this record is",
    "",
    `This is a routing record only. The original plan ${responsibility.plan} did not run: no task was executed,`,
    "no commit was made for it, and the original PLAN file is byte-identical to the preserved copy",
    `(\`${responsibility.original_plan_sha256}\`). It was blocked behind halted ${responsibility.blocked_by.join(", ")}, and those halted`,
    "summaries are unchanged and still literally `halted`.",
    "",
    "## Why it is now superseded",
    "",
    ...(dispositioned
      ? [
        `The work it described is covered by the newer proof owned by ${responsibility.owners.join(", ")}. Dispositioned`,
        "completion re-opened every linked proof listed in `dispositioned_by`. `execution_performed: false` is the honest",
        "statement: this file makes no claim that the old tasks ran, and `requirements-completed` is empty on purpose.",
        "CIREL-02 is accepted by the linked completion evidence.",
        "CIREL-01 is recorded partial under Jon's not_reproduced disposition (the selected flake was neither reproduced nor",
        "fixed); it is not accepted, by this plan or by that evidence.",
        "",
      ]
      : [
        `The work it described is covered by the newer proof owned by ${responsibility.owners.join(", ")}. Strict accepted-only`,
        "completion re-opened every linked proof listed in `accepted_by` and accepted it. `execution_performed: false`",
        "is the honest statement: this file makes no claim that the old tasks ran, and `requirements-completed` is empty",
        "on purpose. CIREL-01 and CIREL-02 are accepted by the linked completion evidence, not by this plan.",
        "",
      ]),
    ...(responsibility.never_ran_reason
      ? [`This plan never ran because its ${responsibility.never_ran_reason}. Its ${responsibility.successor_revision ?? "R2"} successor is ${responsibility.owners.join(", ")}.`, ""]
      : []),
    "## Remaining",
    "",
    "Whole-phase verification is `not_started`. The next step is the unfiltered `$gsd-execute-phase 253`",
    "(security, code review, Nyquist, regression and goal verification). Inherited `blocked_by` entries remain on",
    "this summarized history by design.",
    "",
  ];
  return `${lines.join("\n")}`;
}

function resolveLinkPath(base, path) {
  return isAbsolute(path) ? path : join(base, path);
}

function preflight({ root, contract, requireOwnerSummaries }) {
  const phaseDir = join(root, contract.phase_dir);
  for (const original of contract.originals) {
    const bytes = readOrNull(join(root, original.plan_path));
    if (bytes === null || sha256(bytes) !== original.plan_sha256) throw new Error(`original plan ${original.plan_path} differs from the contract`);
  }
  for (const halted of contract.halted_plans) {
    const bytes = readOrNull(join(root, halted.summary.path));
    if (bytes === null || sha256(bytes) !== halted.summary.sha256) throw new Error(`halted summary ${halted.summary.path} differs from the contract`);
  }
  for (const pin of contract.plan_pins ?? []) {
    const bytes = readOrNull(join(root, pin.path));
    if (bytes === null || sha256(bytes) !== pin.sha256) throw new Error(`pinned plan ${pin.plan} (${pin.path}) differs from the contract`);
  }
  for (const pin of contract.summary_pins ?? []) {
    const bytes = readOrNull(join(root, pin.path));
    if (bytes === null || sha256(bytes) !== pin.sha256) throw new Error(`pinned summary ${pin.plan} (${pin.path}) differs from the contract`);
  }
  const owners = [...new Set(contract.responsibilities.flatMap((r) => r.owners))].sort();
  for (const owner of owners) {
    if (!existsSync(join(phaseDir, `${owner}-PLAN.md`))) throw new Error(`proof owner plan ${owner} is missing`);
    if (requireOwnerSummaries) {
      const summary = readOrNull(join(phaseDir, `${owner}-SUMMARY.md`));
      if (summary === null) throw new Error(`proof owner ${owner} has no SUMMARY`);
      const status = frontmatter(summary.toString("utf8")).status;
      if (status === "halted" || status === "blocked") throw new Error(`proof owner ${owner} summary status is ${status}`);
    }
  }
  for (const responsibility of contract.responsibilities) {
    if (lstatOrNull(join(root, responsibility.disposition_path)) !== null) throw new Error(`${responsibility.disposition_path} already exists; existing summaries are never overwritten`);
  }
}

function lstatOrNull(path) {
  try {
    return lstatSync(path);
  } catch {
    return null;
  }
}

export function prepareDispositions({ root = REPO_ROOT, contract, contractSha256, completionPath, verifier = null }) {
  const revision = contract.revision ?? "v1";
  const verdict = evaluateCompletion({ completionPath, verifier, revision });
  if (!verdict.accepted) throw new Error(`${isDispositioned(revision) ? "dispositioned" : "accepted-only"} completion not satisfied; no disposition bytes generated: ${verdict.detail}`);
  const evidence = JSON.parse(readFileSync(completionPath, "utf8"));
  const base = verifier ? root : REPO_ROOT;
  const completion = { path: relativeOrGiven(root, completionPath), sha256: verdict.completion_sha256 };
  const verifierInfo = { kind: verdict.verifier_kind, sha256: verdict.verifier_sha256 };
  const linkFor = (key, plan) => {
    const link = evidence.links && evidence.links[key];
    if (!link || typeof link.path !== "string" || !/^[a-f0-9]{64}$/.test(link.sha256 || "")) {
      throw new Error(`${plan} requires completion link ${key}, which the completion evidence does not carry`);
    }
    const bytes = readOrNull(resolveLinkPath(base, link.path));
    if (bytes === null || sha256(bytes) !== link.sha256) throw new Error(`${plan} link ${key} cannot be re-opened with its recorded hash`);
    return { link: key, path: link.path, sha256: link.sha256 };
  };
  const staged = contract.responsibilities.map((responsibility) => ({
    responsibility,
    links: responsibility.required_links.map((key) => linkFor(key, responsibility.plan)),
  }));
  preflight({ root, contract, requireOwnerSummaries: false });
  const entries = staged.map(({ responsibility, links }) => {
    const content = renderDisposition({ responsibility, completion, links, verifier: verifierInfo, contractSha256, revision });
    return { plan: responsibility.plan, path: responsibility.disposition_path, sha256: sha256(content), bytes: Buffer.byteLength(content), content };
  });
  return { schema: BUNDLE_SCHEMA, phase: PHASE, contract_sha256: contractSha256, completion, verifier: verifierInfo, entries };
}

// ---------------------------------------------------------------------------------------------
// Root-only write-ahead application
// ---------------------------------------------------------------------------------------------
function dirtySnapshot(root) {
  const run = spawnSync("git", ["-C", root, "status", "--porcelain"], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (run.status !== 0) throw new Error(`git status failed: ${run.stderr}`);
  return run.stdout.split("\n").filter(Boolean).map((line) => {
    const path = line.slice(3).replace(/^"|"$/g, "");
    const bytes = readOrNull(join(root, path));
    return { status: line.slice(0, 2), path, sha256: bytes === null ? null : sha256(bytes) };
  });
}

function writeDurably(path, content, { exclusive }) {
  const fd = openSync(path, exclusive ? "wx" : "w", 0o644);
  try {
    writeSync(fd, content);
    fsyncSync(fd);
  } finally {
    closeSync(fd);
  }
}

export function applyBundle({ root = REPO_ROOT, contract, contractSha256, bundle, completionPath, verifier = null, allowFixture = false, recordPath, hooks = {} }) {
  if (!recordPath) throw new Error("applyBundle requires a recordPath for the write-ahead journal");
  if (bundle.verifier.kind !== "real" && !allowFixture) throw new Error("a fixture bundle cannot be applied without the explicit fixture flag");
  const expected = prepareDispositions({ root, contract, contractSha256, completionPath, verifier });
  const same = expected.completion.sha256 === bundle.completion.sha256 && expected.entries.length === bundle.entries.length
    && expected.entries.every((entry, i) => entry.path === bundle.entries[i].path && entry.sha256 === bundle.entries[i].sha256
      && entry.content === bundle.entries[i].content && sha256(bundle.entries[i].content) === bundle.entries[i].sha256);
  if (!same) throw new Error("bundle bytes differ from the re-derived accepted-only bundle");
  preflight({ root, contract, requireOwnerSummaries: true });
  const head = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" }).stdout.trim() || null;
  const dirtyBefore = dirtySnapshot(root);
  const record = {
    schema: RECORD_SCHEMA, phase: PHASE, contract_sha256: contractSha256, completion: expected.completion, verifier: expected.verifier,
    head, write_ahead_recorded_before_write: true,
    entries: expected.entries.map((e) => ({ plan: e.plan, path: e.path, sha256: e.sha256, prior_state: "absent" })),
    dirty_before: dirtyBefore, applied: false, rolled_back: false,
  };
  writeDurably(recordPath, `${JSON.stringify(record, null, 2)}\n`, { exclusive: false });
  const created = [];
  try {
    for (const entry of expected.entries) {
      const target = join(root, entry.path);
      writeDurably(target, entry.content, { exclusive: true });
      created.push(target);
      if (readFileSync(target, "utf8") !== entry.content) throw new Error(`readback differs for ${entry.path}`);
      if (hooks.afterWrite) hooks.afterWrite(entry);
    }
    const dirtyAfter = dirtySnapshot(root);
    for (const before of dirtyBefore) {
      const after = dirtyAfter.find((d) => d.path === before.path);
      if (!after || after.status !== before.status || after.sha256 !== before.sha256) throw new Error(`pre-existing tracking changed: ${before.path}`);
    }
    for (const original of contract.originals) {
      if (sha256(readFileSync(join(root, original.plan_path))) !== original.plan_sha256) throw new Error(`original plan changed: ${original.plan_path}`);
    }
    for (const halted of contract.halted_plans) {
      if (sha256(readFileSync(join(root, halted.summary.path))) !== halted.summary.sha256) throw new Error(`halted summary changed: ${halted.summary.path}`);
    }
    const done = { ...record, applied: true, entries: record.entries.map((e) => ({ ...e, readback_exact: true })), dirty_after_unchanged: true };
    writeDurably(recordPath, `${JSON.stringify(done, null, 2)}\n`, { exclusive: false });
    return done;
  } catch (error) {
    for (const file of created.reverse()) {
      try {
        unlinkSync(file);
      } catch {
        // best effort: only files this run created are ever removed
      }
    }
    const failed = { ...record, applied: false, rolled_back: true, error: String(error.message) };
    writeDurably(recordPath, `${JSON.stringify(failed, null, 2)}\n`, { exclusive: false });
    throw error;
  }
}

// ---------------------------------------------------------------------------------------------
// Real-SDK index check after application
// ---------------------------------------------------------------------------------------------
export function checkIndex({ root = REPO_ROOT, contract, phase = PHASE }) {
  const pins = verifySdkPins();
  const index = sdkQuery(root, ["phase-plan-index", String(phase)]);
  const init = sdkQuery(root, ["init.execute-phase", String(phase)]);
  const verification = sdkQuery(root, ["verification", "status", init.phase_dir]);
  const byId = Object.fromEntries(index.plans.map((plan) => [plan.id, plan]));
  const oldUnsummarized = contract.responsibilities.map((r) => r.plan).filter((id) => index.incomplete.includes(id));
  const haltedLiteral = contract.halted_plans.every((halted) => {
    const bytes = readOrNull(join(root, halted.summary.path));
    return byId[halted.plan] && byId[halted.plan].halted === true && bytes !== null && sha256(bytes) === halted.summary.sha256;
  });
  const originalsIntact = contract.originals.every((original) => {
    const bytes = readOrNull(join(root, original.plan_path));
    return bytes !== null && sha256(bytes) === original.plan_sha256;
  });
  const dispositionsInvalid = contract.responsibilities.filter((responsibility) => {
    const bytes = readOrNull(join(root, responsibility.disposition_path));
    if (bytes === null) return false;
    const fm = frontmatter(bytes.toString("utf8"));
    return !(fm.status === "superseded" && fm.execution_performed === false && fm.original_status === "blocked" && fm.phase_verification_status === "not_started");
  }).map((r) => r.plan);
  const route = routeExecutePhase(index, verification, {});
  const ok = pins.ok && oldUnsummarized.length === 0 && index.incomplete.length === 0 && haltedLiteral && originalsIntact
    && dispositionsInvalid.length === 0 && route.outcome === "resume_phase_gates";
  return {
    ok, sdk_ok: pins.ok, sdk_mismatches: pins.mismatches, old_unsummarized: oldUnsummarized, any_unsummarized: index.incomplete,
    halted_literal: haltedLiteral, originals_intact: originalsIntact, dispositions_invalid: dispositionsInvalid,
    verification_status: verification.status, route,
  };
}

// ---------------------------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------------------------
function parseArgs(argv) {
  const flags = new Set(["--prepare-contract", "--check-only", "--dry-run", "--prepare-dispositions", "--apply-bundle"]);
  const valued = new Set(["--output", "--completion", "--bundle", "--record", "--root", "--check-index", "--revision"]);
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

function writeJson(path, value, { exclusive = false } = {}) {
  writeDurably(path, `${JSON.stringify(value, null, 2)}\n`, { exclusive });
}

export function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`reconcile: ${error.message}\n`);
    return 2;
  }
  const root = resolve(args.values["--root"] ?? REPO_ROOT);
  const revision = args.values["--revision"] ?? "v1";
  if (!REVISIONS.includes(revision)) {
    process.stderr.write(`reconcile: unknown revision ${revision}; expected one of ${REVISIONS.join(", ")}\n`);
    return 2;
  }
  const contractPath = contractPathFor(revision);
  const need = (flag) => {
    if (!args.values[flag]) throw Object.assign(new Error(`${flag} is required`), { usage: true });
    return args.values[flag];
  };
  try {
    if (args.flags.has("--prepare-contract")) {
      const output = need("--output");
      const text = serializeContract(buildContract({ repoRoot: root, revision }));
      if (args.flags.has("--check-only")) {
        const existing = readOrNull(output);
        if (existing === null) throw new Error(`${output} does not exist; --check-only never creates it`);
        if (existing.toString("utf8") !== text) throw new Error(`${output} differs from the regenerated contract`);
        process.stdout.write(`contract ${output} matches (sha256 ${sha256(text)})\n`);
        return 0;
      }
      writeFileSync(output, text);
      process.stdout.write(`contract written ${output} (sha256 ${sha256(text)})\n`);
      return 0;
    }
    if (args.values["--check-index"]) {
      const { contract } = loadContract(contractPath);
      const report = checkIndex({ root, contract, phase: args.values["--check-index"] });
      if (args.values["--record"]) writeJson(args.values["--record"], { schema: "sigra.phase253.load-recovery-index-check/v1", phase: args.values["--check-index"], ...report });
      process.stdout.write(`${JSON.stringify({ ok: report.ok, route: report.route.outcome, old_unsummarized: report.old_unsummarized.length, any_unsummarized: report.any_unsummarized.length })}\n`);
      return report.ok ? 0 : 1;
    }
    if (args.flags.has("--dry-run")) {
      const completion = need("--completion");
      const record = need("--record");
      const { contract } = loadContract(contractPath);
      const verdict = evaluateCompletion({ completionPath: completion, revision: contract.revision ?? "v1" });
      let preflightError = null;
      if (verdict.accepted) {
        try {
          preflight({ root, contract, requireOwnerSummaries: false });
        } catch (error) {
          preflightError = error.message;
        }
      }
      writeJson(record, {
        schema: "sigra.phase253.load-recovery-dry-run/v1", mode: "dry-run", accepted: verdict.accepted, verifier_kind: verdict.verifier_kind,
        completion_sha256: verdict.completion_sha256, detail: verdict.detail, preflight_error: preflightError,
        would_create: verdict.accepted && !preflightError ? contract.responsibilities.map((r) => r.disposition_path) : [],
        disposition_bytes_generated: false,
      });
      return verdict.accepted && !preflightError ? 0 : 1;
    }
    if (args.flags.has("--prepare-dispositions")) {
      const completion = need("--completion");
      const bundlePath = need("--bundle");
      const record = need("--record");
      const { contract, sha256: contractSha256 } = loadContract(contractPath);
      const bundle = prepareDispositions({ root, contract, contractSha256, completionPath: completion });
      writeJson(bundlePath, bundle, { exclusive: true });
      writeJson(record, { schema: "sigra.phase253.load-recovery-bundle-record/v1", bundle_path: bundlePath, bundle_sha256: sha256(readFileSync(bundlePath)),
        completion: bundle.completion, verifier: bundle.verifier, entries: bundle.entries.map((e) => ({ plan: e.plan, path: e.path, sha256: e.sha256 })), applied: false });
      return 0;
    }
    if (args.flags.has("--apply-bundle")) {
      const completion = need("--completion");
      const bundlePath = need("--bundle");
      const record = need("--record");
      const { contract, sha256: contractSha256 } = loadContract(contractPath);
      const bundle = JSON.parse(readFileSync(bundlePath, "utf8"));
      const result = applyBundle({ root, contract, contractSha256, bundle, completionPath: completion, recordPath: record });
      process.stdout.write(`${JSON.stringify({ applied: result.applied, entries: result.entries.length })}\n`);
      return 0;
    }
  } catch (error) {
    process.stderr.write(`reconcile: ${error.message}\n`);
    return error.usage ? 2 : 1;
  }
  process.stderr.write("reconcile: no supported command given\n");
  return 2;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exit(main(process.argv.slice(2)));
}
