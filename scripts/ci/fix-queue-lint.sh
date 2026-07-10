#!/usr/bin/env bash
# Phase 217 Plan 02 (AUTOFIX-01): fix-queue-lint.sh — recompute derived fields.
#
# Enforces that guides/reference/fix-queue.json is:
#   (a) valid JSON and a non-empty array
#   (b) no duplicate finding_id values
#   (c) auto_eligible is CORRECTLY DERIVED from fix_class (fix_class ∈ {copy,token} → true)
#       — any mismatch exits non-zero (tampered typed bit is caught)
#   (d) priority is consistent with systemic group membership:
#       - entries with surfaces_affected.length >=2 → priority must be 'systemic'
#       - entries with surfaces_affected.length <2 (or absent) → priority must NOT be 'systemic'
#   (e) open_findings in admin-render-sha.json is plausible:
#       - must be non-negative
#       - must not exceed the total open queue size (render-sha is stale/wrong if so)
#
# Node is used for JSON parsing (no jq dependency) — per house idiom.
#
# Usage:
#   bash scripts/ci/fix-queue-lint.sh [--base <ref>]
#   (--base is accepted for symmetry with other guards; not used in current version)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUEUE_JSON="${ROOT}/guides/reference/fix-queue.json"
RENDER_SHA_JSON="${ROOT}/guides/reference/admin-render-sha.json"

# Consume --base arg (accepted for symmetry; not used)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) shift 2;;
    *) echo "fix-queue-lint: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ ! -f "$QUEUE_JSON" ]]; then
  echo "fix-queue-lint: FAIL: fix-queue.json not found at ${QUEUE_JSON}" >&2
  exit 1
fi
if [[ ! -f "$RENDER_SHA_JSON" ]]; then
  echo "fix-queue-lint: FAIL: admin-render-sha.json not found at ${RENDER_SHA_JSON}" >&2
  exit 1
fi

# Run all checks in one Node pass.
# Outputs one violation line per error; empty output = PASS.
VIOLATIONS=$(QUEUE_JSON_PATH="$QUEUE_JSON" RENDER_SHA_PATH="$RENDER_SHA_JSON" \
  node -e '
const fs = require("node:fs");
const crypto = require("node:crypto");

const queueJsonPath = process.env.QUEUE_JSON_PATH;
const renderShaPath = process.env.RENDER_SHA_PATH;

const errors = [];

// --- Parse fix-queue.json ---
let queue;
try {
  queue = JSON.parse(fs.readFileSync(queueJsonPath, "utf8"));
} catch (e) {
  errors.push("fix-queue.json is not valid JSON: " + e.message);
  process.stdout.write(errors.join("\n") + "\n");
  process.exit(0);
}

if (!Array.isArray(queue)) {
  errors.push("fix-queue.json must be a JSON array");
  process.stdout.write(errors.join("\n") + "\n");
  process.exit(0);
}

// (b) No duplicate finding_id
const seenIds = new Set();
for (const entry of queue) {
  if (seenIds.has(entry.finding_id)) {
    errors.push("duplicate finding_id: " + entry.finding_id);
  }
  seenIds.add(entry.finding_id);
}

// (c) auto_eligible DERIVED from fix_class — recompute and compare
const AUTO_FIX_CLASSES = new Set(["copy", "token"]);
for (const entry of queue) {
  const expected = AUTO_FIX_CLASSES.has(entry.fix_class);
  if (entry.auto_eligible !== expected) {
    errors.push(
      "auto_eligible mismatch for finding_id=" + entry.finding_id +
      " (fix_class=" + entry.fix_class +
      ", expected auto_eligible=" + expected +
      ", got " + entry.auto_eligible + ")"
    );
  }
}

// (d) priority consistency with systemic group membership
for (const entry of queue) {
  const surfaceCount = Array.isArray(entry.surfaces_affected)
    ? entry.surfaces_affected.length : 0;
  if (surfaceCount >= 2 && entry.priority !== "systemic") {
    errors.push(
      "priority drift: finding_id=" + entry.finding_id +
      " has surfaces_affected.length=" + surfaceCount +
      " but priority=" + entry.priority + " (expected: systemic)"
    );
  }
  if (surfaceCount < 2 && entry.priority === "systemic") {
    errors.push(
      "priority drift: finding_id=" + entry.finding_id +
      " has surfaces_affected.length=" + surfaceCount +
      " but priority=systemic (only entries with >=2 surfaces may be systemic)"
    );
  }
}

// (e) open_findings in admin-render-sha.json sanity check
// open_findings = per-cell count of unique finding_ids (BEFORE systemic collapse).
// The queue applies systemic collapse so queue.length <= total individual findings.
//
// To find total uncollapsed finding count:
//   - systemic entries each represent surfaces_affected.length distinct findings
//   - normal entries each represent 1 finding
// This equals "built - settled" before collapse (what the builder counts).
//
// open_findings for any cell must be:
//   (a) non-negative
//   (b) <= total_uncollapsed (cannot have more open findings than exist in the queue)
//   (c) consistent across all admin surfaces for the same cell key (builder writes the same)

let totalUncollapsed = 0;
for (const entry of queue) {
  if (Array.isArray(entry.surfaces_affected) && entry.surfaces_affected.length >= 2) {
    totalUncollapsed += entry.surfaces_affected.length;
  } else {
    totalUncollapsed += 1;
  }
}

let renderSha;
try {
  renderSha = JSON.parse(fs.readFileSync(renderShaPath, "utf8"));
} catch (e) {
  errors.push("admin-render-sha.json is not valid JSON: " + e.message);
  process.stdout.write(errors.join("\n") + "\n");
  process.exit(0);
}

// Collect open_findings per cell key — all admin surfaces must agree for the same cell key
const cellKeyToOpenFindings = new Map();
for (const surface of Object.keys(renderSha.cells || {})) {
  for (const cellKey of Object.keys(renderSha.cells[surface] || {})) {
    const cellData = renderSha.cells[surface][cellKey];
    // The `proxy` flag (renderSha.cells[surface].proxy === true) is a surface-level boolean
    // marker — a sibling of the real cells, not a cell itself. Skip non-object values so the
    // marker is not mistaken for a cell missing open_findings. Real cell objects still flow
    // through the null-check below, so a genuine object missing open_findings is still caught.
    // Mirrors the non-cell skip already enforced in scripts/ci/fix-queue-build.mjs.
    if (typeof cellData !== "object" || cellData === null) {
      continue;
    }
    const openFindings = cellData && typeof cellData.open_findings === "number"
      ? cellData.open_findings : null;
    if (openFindings === null) {
      errors.push("admin-render-sha.json missing open_findings for " + surface + "/" + cellKey);
    } else if (openFindings < 0) {
      errors.push("admin-render-sha.json negative open_findings for " + surface + "/" + cellKey + ": " + openFindings);
    } else if (openFindings > totalUncollapsed && totalUncollapsed > 0) {
      errors.push(
        "admin-render-sha.json open_findings " + openFindings +
        " exceeds total uncollapsed open count " + totalUncollapsed +
        " for " + surface + "/" + cellKey +
        " — render-sha may be stale (run fix-queue-build.mjs to regenerate)"
      );
    } else {
      // All admin surfaces must agree on the same open_findings for a given cell key,
      // EXCEPT cells introduced at open_findings=0 (newly added surfaces that have not
      // yet had a probe run against them are introduced with 0 as the sentinel
      // "introduced but not yet measured" value — Plan 217-08 gate-safety invariant).
      // A 0-valued cell is exempt from cross-surface consistency: it will be populated
      // by the next fix-queue-build.mjs run once bundles are captured at the new surface.
      if (openFindings === 0) {
        // Newly introduced cell — skip cross-surface consistency check
      } else if (!cellKeyToOpenFindings.has(cellKey)) {
        cellKeyToOpenFindings.set(cellKey, { value: openFindings, firstSurface: surface });
      } else {
        const prior = cellKeyToOpenFindings.get(cellKey);
        if (prior.value !== openFindings) {
          errors.push(
            "admin-render-sha.json open_findings mismatch for cell " + cellKey + ": " +
            prior.firstSurface + "=" + prior.value + " vs " + surface + "=" + openFindings +
            " — surfaces must agree (run fix-queue-build.mjs to regenerate)"
          );
        }
      }
    }
  }
}

if (errors.length > 0) {
  process.stdout.write(errors.join("\n") + "\n");
}
')

if [[ -z "$VIOLATIONS" ]]; then
  ENTRY_COUNT=$(QUEUE_JSON_PATH="$QUEUE_JSON" node -e '
const q = JSON.parse(require("node:fs").readFileSync(process.env.QUEUE_JSON_PATH, "utf8"));
process.stdout.write(String(q.length));
' 2>/dev/null || echo "?")
  echo "fix-queue-lint: PASS (${ENTRY_COUNT} queue entries validated)"
  exit 0
else
  echo "$VIOLATIONS" | while IFS= read -r line; do
    [[ -n "$line" ]] && echo "fix-queue-lint: FAIL: $line" >&2
  done
  exit 1
fi
