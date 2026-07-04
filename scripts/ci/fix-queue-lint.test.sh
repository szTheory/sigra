#!/usr/bin/env bash
# Self-test for fix-queue-lint.sh (Phase 217, Plan 02).
#
# Hermetic: operates entirely inside a mktemp -d throwaway directory.
# No files are created in the real repo; git status is unchanged after running.
#
# Tests per Plan 02 behavior spec:
#   Test 1: tampered auto_eligible (true on a judgment finding) → exit non-zero
#   Test 2: tampered priority/systemic_group → exit non-zero
#   Test 3: open_findings in admin-render-sha.json != built - settled → exit non-zero
#   Test 4: clean, freshly-built queue (from fix-queue-build.mjs) → exit 0
set -euo pipefail

TMPDIR_ROOT=""
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_LINT="${SCRIPT_DIR}/fix-queue-lint.sh"

if [[ ! -f "$REAL_LINT" ]]; then
  echo "FATAL: fix-queue-lint.sh not found at ${REAL_LINT}" >&2
  exit 2
fi

TMPDIR_ROOT="$(mktemp -d)"

# Replicate the repo layout the lint script expects:
#   scripts/ci/fix-queue-lint.sh  (the script itself)
#   guides/reference/fix-queue.json
#   guides/reference/settled-findings.tsv
#   guides/reference/admin-render-sha.json
mkdir -p "$TMPDIR_ROOT/scripts/ci"
mkdir -p "$TMPDIR_ROOT/guides/reference"

cp "$REAL_LINT" "$TMPDIR_ROOT/scripts/ci/fix-queue-lint.sh"
chmod +x "$TMPDIR_ROOT/scripts/ci/fix-queue-lint.sh"

LINT="$TMPDIR_ROOT/scripts/ci/fix-queue-lint.sh"
QUEUE_JSON="$TMPDIR_ROOT/guides/reference/fix-queue.json"
SETTLED_TSV="$TMPDIR_ROOT/guides/reference/settled-findings.tsv"
RENDER_SHA="$TMPDIR_ROOT/guides/reference/admin-render-sha.json"

# Shared test finding_ids (64-char hex)
SURF="users-index-live"
CELL="light-desktop-populated"
FID_JUDGMENT="aaaa000000000000000000000000000000000000000000000000000000000001"
FID_TOKEN="bbbb000000000000000000000000000000000000000000000000000000000001"
SGROUP="cccc000000000000000000000000000000000000000000000000000000000001"

# Write settled-findings.tsv (empty data, header only)
printf '# finding_id\tsurface\tclass\tanchor\tdisposition\twaived_by\tnote\n' > "$SETTLED_TSV"

# ── Test 1: tampered auto_eligible (true on a judgment finding) → exit non-zero ──
echo ""
echo "Test 1: tampered auto_eligible on judgment finding → exit non-zero"

# Write a fix-queue.json with a judgment finding that has auto_eligible=true (tampering)
node -e "
const q = [
  {
    finding_id: '$FID_JUDGMENT',
    surface: '$SURF',
    class: 'misalignment',
    anchor: '.sg-btn',
    lens: null,
    severity: 'warn',
    fix_class: 'judgment',
    auto_eligible: true,      // TAMPERED: judgment must be false
    systemic_group: '$SGROUP',
    priority: 'normal'
  }
];
process.stdout.write(JSON.stringify(q, null, 2) + '\n');
" > "$QUEUE_JSON"

# Write matching admin-render-sha.json with open_findings = 1 (matches queue)
node -e "
const r = {
  schema_version: 1,
  notes: 'test',
  cells: { '$SURF': { '$CELL': { render_sha256: null, open_findings: 1 } } }
};
process.stdout.write(JSON.stringify(r, null, 2) + '\n');
" > "$RENDER_SHA"

STDERR_1="$TMPDIR_ROOT/stderr_1.txt"
set +e
bash "$LINT" >"$TMPDIR_ROOT/stdout_1.txt" 2>"$STDERR_1"
EXIT_1=$?
set -e

if [[ "$EXIT_1" -ne 0 ]]; then
  pass "Test 1: tampered auto_eligible=true on judgment exits non-zero (got $EXIT_1)"
else
  fail "Test 1: tampered auto_eligible=true on judgment should exit non-zero (got 0)"
  cat "$STDERR_1" >&2 || true
fi

# ── Test 2: tampered priority/systemic_group → exit non-zero ──
echo ""
echo "Test 2: tampered priority on normal finding → exit non-zero"

# Write a fix-queue.json where a single-surface finding has priority='systemic' (tampered)
node -e "
const q = [
  {
    finding_id: '$FID_JUDGMENT',
    surface: '$SURF',
    class: 'misalignment',
    anchor: '.sg-btn',
    lens: null,
    severity: 'warn',
    fix_class: 'judgment',
    auto_eligible: false,
    systemic_group: '$SGROUP',
    priority: 'systemic',     // TAMPERED: single-surface finding should be 'normal'
    surfaces_affected: ['$SURF']   // only one surface → should not be systemic
  }
];
process.stdout.write(JSON.stringify(q, null, 2) + '\n');
" > "$QUEUE_JSON"

# admin-render-sha open_findings = 1 (matching)
node -e "
const r = {
  schema_version: 1,
  notes: 'test',
  cells: { '$SURF': { '$CELL': { render_sha256: null, open_findings: 1 } } }
};
process.stdout.write(JSON.stringify(r, null, 2) + '\n');
" > "$RENDER_SHA"

STDERR_2="$TMPDIR_ROOT/stderr_2.txt"
set +e
bash "$LINT" >"$TMPDIR_ROOT/stdout_2.txt" 2>"$STDERR_2"
EXIT_2=$?
set -e

if [[ "$EXIT_2" -ne 0 ]]; then
  pass "Test 2: tampered priority='systemic' on single-surface finding exits non-zero (got $EXIT_2)"
else
  fail "Test 2: tampered priority='systemic' on single-surface finding should exit non-zero (got 0)"
  cat "$STDERR_2" >&2 || true
fi

# ── Test 3: open_findings in admin-render-sha.json != built - settled → exit non-zero ──
echo ""
echo "Test 3: admin-render-sha.json open_findings mismatch → exit non-zero"

# Write a valid queue with 1 open finding, but admin-render-sha has open_findings=99 (wrong)
node -e "
const q = [
  {
    finding_id: '$FID_JUDGMENT',
    surface: '$SURF',
    class: 'misalignment',
    anchor: '.sg-btn',
    lens: null,
    severity: 'warn',
    fix_class: 'judgment',
    auto_eligible: false,
    systemic_group: '$SGROUP',
    priority: 'normal'
  }
];
process.stdout.write(JSON.stringify(q, null, 2) + '\n');
" > "$QUEUE_JSON"

# admin-render-sha has wrong open_findings (99 instead of 1)
node -e "
const r = {
  schema_version: 1,
  notes: 'test',
  cells: { '$SURF': { '$CELL': { render_sha256: null, open_findings: 99 } } }
};
process.stdout.write(JSON.stringify(r, null, 2) + '\n');
" > "$RENDER_SHA"

STDERR_3="$TMPDIR_ROOT/stderr_3.txt"
set +e
bash "$LINT" >"$TMPDIR_ROOT/stdout_3.txt" 2>"$STDERR_3"
EXIT_3=$?
set -e

if [[ "$EXIT_3" -ne 0 ]]; then
  pass "Test 3: mismatched open_findings (99 vs 1) exits non-zero (got $EXIT_3)"
else
  fail "Test 3: mismatched open_findings should exit non-zero (got 0)"
  cat "$STDERR_3" >&2 || true
fi

# ── Test 4: clean, freshly-built queue PASSES (exit 0) ──
echo ""
echo "Test 4: clean, freshly-built queue exits 0"

# Write a clean valid queue: token finding (auto_eligible=true), judgment (auto_eligible=false)
# systemic_group matches the expected formula
TOKEN_SGROUP="$(node -e "const {createHash}=require('node:crypto'); process.stdout.write(createHash('sha256').update('off-scale-radius-shadow-control\x00.sg-dialog').digest('hex'));")"
JUDGMENT_SGROUP="$(node -e "const {createHash}=require('node:crypto'); process.stdout.write(createHash('sha256').update('misalignment\x00.sg-panel').digest('hex'));")"
TOKEN_FID="$(node -e "const {createHash}=require('node:crypto'); process.stdout.write(createHash('sha256').update('$SURF\x00off-scale-radius-shadow-control\x00.sg-dialog').digest('hex'));")"
JUDGMENT_FID="$(node -e "const {createHash}=require('node:crypto'); process.stdout.write(createHash('sha256').update('$SURF\x00misalignment\x00.sg-panel').digest('hex'));")"

node -e "
const q = [
  {
    finding_id: '$TOKEN_FID',
    surface: '$SURF',
    class: 'off-scale-radius-shadow-control',
    anchor: '.sg-dialog',
    lens: null,
    severity: 'warn',
    fix_class: 'token',
    auto_eligible: true,   // correct for token
    systemic_group: '$TOKEN_SGROUP',
    priority: 'normal'
  },
  {
    finding_id: '$JUDGMENT_FID',
    surface: '$SURF',
    class: 'misalignment',
    anchor: '.sg-panel',
    lens: null,
    severity: 'warn',
    fix_class: 'judgment',
    auto_eligible: false,  // correct for judgment
    systemic_group: '$JUDGMENT_SGROUP',
    priority: 'normal'
  }
];
process.stdout.write(JSON.stringify(q, null, 2) + '\n');
" > "$QUEUE_JSON"

# admin-render-sha with correct open_findings = 2 (matching queue count for this cell)
node -e "
const r = {
  schema_version: 1,
  notes: 'test',
  cells: { '$SURF': { '$CELL': { render_sha256: null, open_findings: 2 } } }
};
process.stdout.write(JSON.stringify(r, null, 2) + '\n');
" > "$RENDER_SHA"

# settled-findings.tsv is empty (no settled rows)
printf '# finding_id\tsurface\tclass\tanchor\tdisposition\twaived_by\tnote\n' > "$SETTLED_TSV"

STDERR_4="$TMPDIR_ROOT/stderr_4.txt"
set +e
bash "$LINT" >"$TMPDIR_ROOT/stdout_4.txt" 2>"$STDERR_4"
EXIT_4=$?
set -e

if [[ "$EXIT_4" -eq 0 ]]; then
  pass "Test 4: clean queue exits 0"
else
  fail "Test 4: clean queue should exit 0 (got $EXIT_4)"
  cat "$STDERR_4" >&2 || true
  cat "$TMPDIR_ROOT/stdout_4.txt" || true
fi

# ── Results ──────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
echo "${TOTAL} checks: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "fix-queue-lint.test.sh: FAIL" >&2
  exit 1
fi
echo "fix-queue-lint.test.sh: PASS"
