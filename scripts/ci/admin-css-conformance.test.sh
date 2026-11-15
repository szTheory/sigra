#!/usr/bin/env bash
# Self-test for admin-css-conformance.sh: proves the guard exits non-zero on
# forbidden patterns and exits 0 on a clean file.
#
# Hermetic: uses mktemp CSS files, no real-repo side effects.
# No files are created or modified in the real repo; git status of the real
# repo is unchanged after this script runs.
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

# Locate the real guard script (relative to this test script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_GUARD="${SCRIPT_DIR}/admin-css-conformance.sh"

if [[ ! -f "$REAL_GUARD" ]]; then
  echo "FATAL: guard script not found at ${REAL_GUARD}" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Create hermetic temp directory for CSS fixtures.
# The guard accepts a file path argument, so no throwaway git repo is needed.
# --------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"

# --------------------------------------------------------------------------
# CSS Fixtures
# --------------------------------------------------------------------------

# CLEAN_CSS: valid CSS with :root tokens using hex, and a rule using var().
# No transition: all. No hex outside :root.
CLEAN_CSS="${TMPDIR_ROOT}/clean.css"
cat > "$CLEAN_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
  --sg-color-y: #ffffff;
  --sg-color-z: #c2410c;
}

.foo {
  color: var(--sg-color-x);
  background: var(--sg-color-y);
  transition: color 0.2s ease;
}

.bar {
  color: var(--sg-color-z);
}
CSS

# TRANSITION_ALL_CSS: same as clean but adds a transition: all outside :root.
TRANSITION_ALL_CSS="${TMPDIR_ROOT}/transition-all.css"
cat > "$TRANSITION_ALL_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
}

.foo {
  color: var(--sg-color-x);
  transition: all 0.2s ease;
}
CSS

# RAW_HEX_CSS: same as clean but adds a raw hex color outside :root.
# Mirrors the real gap at sigra_admin.css line 506 (.sg-btn--danger.is-armed color: #fff).
RAW_HEX_CSS="${TMPDIR_ROOT}/raw-hex.css"
cat > "$RAW_HEX_CSS" <<'CSS'
:root {
  --sg-color-x: #abc;
}

.foo {
  color: #fff;
}
CSS

# DARK_ROOT_CSS: CSS with two :root blocks (light + @media dark), both with
# hex-only token definitions. Outside both :root blocks, only var() is used.
# Guard must exit 0 (all hex is inside :root protection).
DARK_ROOT_CSS="${TMPDIR_ROOT}/dark-root.css"
cat > "$DARK_ROOT_CSS" <<'CSS'
:root {
  --sg-color-ink: #151515;
  --sg-color-brand: #c2410c;
}

@media (prefers-color-scheme: dark) {
  :root {
    --sg-color-ink: #f4f1eb;
    --sg-color-brand: #fdba74;
  }
}

.sg-text {
  color: var(--sg-color-ink);
}

.sg-brand {
  color: var(--sg-color-brand);
}
CSS

# --------------------------------------------------------------------------
# Test A: Clean CSS exits 0
# --------------------------------------------------------------------------
echo "Test A: clean CSS exits 0"

STDERR_A="${TMPDIR_ROOT}/stderr_a.txt"
set +e
bash "$REAL_GUARD" "$CLEAN_CSS" >"${TMPDIR_ROOT}/stdout_a.txt" 2>"$STDERR_A"
EXIT_A=$?
set -e

if [[ "$EXIT_A" -eq 0 ]]; then
  pass "Guard exits 0 on clean CSS"
else
  fail "Guard exited non-zero ($EXIT_A) on clean CSS; stderr: $(cat "$STDERR_A")"
fi

if grep -q "PASS" "${TMPDIR_ROOT}/stdout_a.txt" 2>/dev/null; then
  pass "Guard emits PASS on clean CSS"
else
  fail "Guard did not emit PASS on clean CSS; stdout: $(cat "${TMPDIR_ROOT}/stdout_a.txt")"
fi

# --------------------------------------------------------------------------
# Test B: transition:all injection exits non-zero + stderr mentions the violation
# --------------------------------------------------------------------------
echo "Test B: transition:all injection exits non-zero"

STDERR_B="${TMPDIR_ROOT}/stderr_b.txt"
set +e
bash "$REAL_GUARD" "$TRANSITION_ALL_CSS" >"${TMPDIR_ROOT}/stdout_b.txt" 2>"$STDERR_B"
EXIT_B=$?
set -e

if [[ "$EXIT_B" -ne 0 ]]; then
  pass "Guard exits non-zero ($EXIT_B) on transition:all injection"
else
  fail "Guard exited 0 (should have been non-zero) on transition:all injection"
fi

if grep -q "transition: all" "$STDERR_B" 2>/dev/null; then
  pass "Guard stderr contains 'transition: all' on transition:all injection"
else
  fail "Guard stderr does not contain 'transition: all'; actual stderr: $(cat "$STDERR_B")"
fi

# --------------------------------------------------------------------------
# Test C: raw hex outside :root exits non-zero
# --------------------------------------------------------------------------
echo "Test C: raw hex outside :root exits non-zero"

STDERR_C="${TMPDIR_ROOT}/stderr_c.txt"
STDOUT_C="${TMPDIR_ROOT}/stdout_c.txt"
set +e
bash "$REAL_GUARD" "$RAW_HEX_CSS" >"$STDOUT_C" 2>"$STDERR_C"
EXIT_C=$?
set -e

if [[ "$EXIT_C" -ne 0 ]]; then
  pass "Guard exits non-zero ($EXIT_C) on raw hex outside :root"
else
  fail "Guard exited 0 (should have been non-zero) on raw hex outside :root"
fi

# Hex violation indication should appear in stderr or stdout
COMBINED_C="$(cat "$STDERR_C" "$STDOUT_C" 2>/dev/null)"
if echo "$COMBINED_C" | grep -qE '#[0-9a-fA-F]{3,8}|raw hex|FAIL'; then
  pass "Guard output contains hex violation indication on raw hex outside :root"
else
  fail "Guard output has no hex violation indication; stderr: $(cat "$STDERR_C"); stdout: $(cat "$STDOUT_C")"
fi

# --------------------------------------------------------------------------
# Test D: dual :root (light + dark media) exits 0 (all hex inside :root)
# --------------------------------------------------------------------------
echo "Test D: dual :root blocks (light + dark @media) exits 0"

STDERR_D="${TMPDIR_ROOT}/stderr_d.txt"
set +e
bash "$REAL_GUARD" "$DARK_ROOT_CSS" >"${TMPDIR_ROOT}/stdout_d.txt" 2>"$STDERR_D"
EXIT_D=$?
set -e

if [[ "$EXIT_D" -eq 0 ]]; then
  pass "Guard exits 0 on CSS with dual :root blocks (all hex inside :root)"
else
  fail "Guard exits non-zero ($EXIT_D) on dual :root CSS; stderr: $(cat "$STDERR_D"); stdout: $(cat "${TMPDIR_ROOT}/stdout_d.txt")"
fi

# --------------------------------------------------------------------------
# Test E: --css flag routes to the given file (clean file exits 0)
# --------------------------------------------------------------------------
echo "Test E: --css flag routes to a given file"

STDERR_E="${TMPDIR_ROOT}/stderr_e.txt"
set +e
bash "$REAL_GUARD" --css "$CLEAN_CSS" >"${TMPDIR_ROOT}/stdout_e.txt" 2>"$STDERR_E"
EXIT_E=$?
set -e

if [[ "$EXIT_E" -eq 0 ]]; then
  pass "--css flag routes to given clean file and exits 0"
else
  fail "--css flag test failed (exit $EXIT_E); stderr: $(cat "$STDERR_E")"
fi

# --------------------------------------------------------------------------
# Test F: positional argument overrides the default target
# --------------------------------------------------------------------------
echo "Test F: positional argument overrides the default target (transition:all file)"

STDERR_F="${TMPDIR_ROOT}/stderr_f.txt"
set +e
bash "$REAL_GUARD" "$TRANSITION_ALL_CSS" >"${TMPDIR_ROOT}/stdout_f.txt" 2>"$STDERR_F"
EXIT_F=$?
set -e

if [[ "$EXIT_F" -ne 0 ]]; then
  pass "Positional arg routes to given violation file and exits non-zero ($EXIT_F)"
else
  fail "Positional arg test failed — expected non-zero but got 0; stdout: $(cat "${TMPDIR_ROOT}/stdout_f.txt")"
fi

# --------------------------------------------------------------------------
# Tests H-K (Phase 260, BGEN-04/05): explicit-theme token blocks and the
# portable raw-px check. Each case writes its own fixture and calls run_guard,
# which wraps the same set +e / capture $? / set -e idiom as the tests above.
# --------------------------------------------------------------------------

# run_guard <css-file>: run the real guard; sets GUARD_EXIT, GUARD_STDOUT, GUARD_STDERR.
run_guard() {
  local css="$1"
  set +e
  bash "$REAL_GUARD" "$css" >"${TMPDIR_ROOT}/guard_stdout.txt" 2>"${TMPDIR_ROOT}/guard_stderr.txt"
  GUARD_EXIT=$?
  set -e
  GUARD_STDOUT="$(cat "${TMPDIR_ROOT}/guard_stdout.txt")"
  GUARD_STDERR="$(cat "${TMPDIR_ROOT}/guard_stderr.txt")"
}

# violation_count: number of "  NR:line" violation rows the last run printed on stderr.
violation_count() {
  { grep -cE '^  [0-9]+:' "${TMPDIR_ROOT}/guard_stderr.txt" || true; }
}

# --------------------------------------------------------------------------
# Test H: explicit-theme token blocks holding hex custom properties exit 0
# --------------------------------------------------------------------------
echo "Test H: explicit-theme token blocks (hex in --sg-* and color-scheme only) exit 0"

EXPLICIT_THEME_CSS="${TMPDIR_ROOT}/explicit-theme.css"
cat > "$EXPLICIT_THEME_CSS" <<'CSS'
:root {
  --sg-color-ink: #151515;
  --sg-color-panel: #ffffff;
}

.sg-admin-shell[data-theme="light"],
html[data-sg-admin-theme="light"] .sg-admin-shell {
  --sg-color-ink: #151515;
  --sg-color-panel: #ffffff;
  --sg-color-line: rgba(21, 21, 21, 0.1);
  --sg-space-1: 4px;
  --sg-elev-2:
    0 0 0 1px rgba(21, 21, 21, 0.1), 0 3px 10px -8px rgba(21, 21, 21, 0.35),
    0 18px 44px -30px rgba(21, 21, 21, 0.45);
  /* light twin */
  --sg-color-brand-solid: #9a3412; /* trailing note */
  color-scheme: light;
}

html[data-sg-admin-theme="dark"] .sg-admin-shell, .sg-admin-shell[data-theme="dark"] {
  --sg-color-ink: #f4f1eb;
  --sg-color-panel: #1f1d1a;
  color-scheme: dark;
}

@media (prefers-color-scheme: dark) {
  html:not([data-sg-admin-theme]) .sg-admin-shell:not([data-theme]) {
    color-scheme: dark;
  }
}

.sg-text {
  color: var(--sg-color-ink);
}
CSS

run_guard "$EXPLICIT_THEME_CSS"
if [[ "$GUARD_EXIT" -eq 0 ]]; then
  pass "Guard exits 0 on explicit-theme token blocks (multi-line and one-line selector lists)"
else
  fail "Guard exited non-zero ($GUARD_EXIT) on explicit-theme token blocks; stderr: ${GUARD_STDERR}"
fi

# --------------------------------------------------------------------------
# Test I: raw hex in a normal rule beside an explicit-theme block still fails
# (planted control: the protected scope must not leak past its closing brace)
# --------------------------------------------------------------------------
echo "Test I: raw hex in a normal rule next to an explicit-theme block exits non-zero"

LEAK_CSS="${TMPDIR_ROOT}/explicit-then-normal.css"
cat > "$LEAK_CSS" <<'CSS'
.sg-admin-shell[data-theme="light"],
html[data-sg-admin-theme="light"] .sg-admin-shell {
  --sg-color-ink: #151515;
  color-scheme: light;
}

.foo {
  color: #fff;
}
CSS

run_guard "$LEAK_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on raw hex in a rule placed after an explicit-theme block"
else
  fail "Guard exited 0 (should have been non-zero) on raw hex beside an explicit-theme block"
fi

if grep -qF 'raw hex' "${TMPDIR_ROOT}/guard_stderr.txt" && grep -qF 'color: #fff' "${TMPDIR_ROOT}/guard_stderr.txt" \
  && [[ "$(violation_count)" -eq 1 ]]; then
  pass "Guard stderr names the raw hex violation and flags only the normal rule (1 row)"
else
  fail "Guard stderr does not isolate the .foo violation; rows: $(violation_count); stderr: ${GUARD_STDERR}"
fi

# Scope must not widen to selectors that merely share a prefix or sit in a mixed
# list: brand-mark rules start with html[data-sg-admin-theme=...] too.
echo "Test I2: look-alike selectors never enter the protected scope"

BRAND_MARK_CSS="${TMPDIR_ROOT}/brand-mark-hex.css"
cat > "$BRAND_MARK_CSS" <<'CSS'
html[data-sg-admin-theme="dark"] .sg-brand-mark__image--light {
  color: #fff;
}
CSS
run_guard "$BRAND_MARK_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on hex in a brand-mark rule sharing the html[data-sg-admin-theme] prefix"
else
  fail "Guard exited 0 on hex in a brand-mark rule (scope leaked through the shared selector prefix)"
fi

OTHER_BLOCK_CSS="${TMPDIR_ROOT}/other-selector-tokens.css"
cat > "$OTHER_BLOCK_CSS" <<'CSS'
.sg-brand-mark[data-theme="dark"] {
  --sg-color-ink: #f4f1eb;
}
CSS
run_guard "$OTHER_BLOCK_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on a --sg-* hex block whose selector is not an explicit-theme selector"
else
  fail "Guard exited 0 on a token block with a non-explicit-theme selector"
fi

MIXED_LIST_CSS="${TMPDIR_ROOT}/mixed-selector-list.css"
cat > "$MIXED_LIST_CSS" <<'CSS'
.sg-admin-shell[data-theme="dark"],
.sg-other {
  --sg-color-ink: #f4f1eb;
}
CSS
run_guard "$MIXED_LIST_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) when only part of the selector list is an explicit-theme selector"
else
  fail "Guard exited 0 on a mixed selector list (one explicit-theme selector plus an unrelated one)"
fi

THEME_SWITCH_CSS="${TMPDIR_ROOT}/theme-switch-hex.css"
cat > "$THEME_SWITCH_CSS" <<'CSS'
html[data-sg-admin-theme-preference="light"]
  .sg-theme-switch__button[data-theme-value="light"],
html[data-sg-admin-theme-preference="dark"]
  .sg-theme-switch__button[data-theme-value="dark"] {
  background: #fdba74;
  color: #151515;
}
CSS
run_guard "$THEME_SWITCH_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on raw hex in the theme-switch active rule"
else
  fail "Guard exited 0 on raw hex in the theme-switch active rule"
fi

# --------------------------------------------------------------------------
# Test J: a non-token declaration inside an explicit-theme block is still checked
# --------------------------------------------------------------------------
echo "Test J: explicit-theme block with a non-token declaration holding hex exits non-zero"

NON_TOKEN_CSS="${TMPDIR_ROOT}/explicit-non-token.css"
cat > "$NON_TOKEN_CSS" <<'CSS'
.sg-admin-shell[data-theme="dark"],
html[data-sg-admin-theme="dark"] .sg-admin-shell {
  --sg-color-ink: #f4f1eb;
  background: #1f1d1a;
  color-scheme: dark;
}
CSS

run_guard "$NON_TOKEN_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on a hex colour in a non-token declaration inside an explicit-theme block"
else
  fail "Guard exited 0 (should have been non-zero) on a non-token hex declaration inside an explicit-theme block"
fi

if grep -qF 'background: #1f1d1a' "${TMPDIR_ROOT}/guard_stderr.txt" && [[ "$(violation_count)" -eq 1 ]]; then
  pass "Guard flags only the non-token declaration (the --sg-* line stays exempt)"
else
  fail "Guard did not isolate the non-token declaration; rows: $(violation_count); stderr: ${GUARD_STDERR}"
fi

# A second declaration smuggled onto a token line must not hide behind it.
SMUGGLE_CSS="${TMPDIR_ROOT}/explicit-smuggle.css"
cat > "$SMUGGLE_CSS" <<'CSS'
.sg-admin-shell[data-theme="dark"],
html[data-sg-admin-theme="dark"] .sg-admin-shell {
  --sg-color-ink: #f4f1eb; background: #1f1d1a;
  color-scheme: dark;
}
CSS
run_guard "$SMUGGLE_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) when a non-token declaration shares a line with a --sg-* declaration"
else
  fail "Guard exited 0 on a non-token hex declaration smuggled after a --sg-* declaration"
fi

# CHECK 3 shares the scope rule: raw px in a non-token declaration is still caught.
PX_IN_THEME_CSS="${TMPDIR_ROOT}/explicit-px.css"
cat > "$PX_IN_THEME_CSS" <<'CSS'
.sg-admin-shell[data-theme="dark"],
html[data-sg-admin-theme="dark"] .sg-admin-shell {
  --sg-space-1: 4px;
  padding: 13px;
  color-scheme: dark;
}
CSS
run_guard "$PX_IN_THEME_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]] && grep -qF 'raw px' "${TMPDIR_ROOT}/guard_stderr.txt" \
  && grep -qF 'padding: 13px' "${TMPDIR_ROOT}/guard_stderr.txt" && [[ "$(violation_count)" -eq 1 ]]; then
  pass "Guard flags raw px in a non-token declaration inside an explicit-theme block (the --sg-space-1 token stays exempt)"
else
  fail "Guard did not isolate raw px inside an explicit-theme block (exit ${GUARD_EXIT}); stderr: ${GUARD_STDERR}"
fi

# --------------------------------------------------------------------------
# Test K: raw px in a token-eligible property outside any scope exits non-zero.
# The px line filter used a backslash-d shorthand that GNU grep -E does not
# support, so on the ubuntu CI runner CHECK 3 could never fire. This case is
# only meaningful when also run under a GNU userland (see the SUMMARY).
# --------------------------------------------------------------------------
echo "Test K: raw px outside any token scope exits non-zero (and the allowlist still passes)"

RAW_PX_CSS="${TMPDIR_ROOT}/raw-px.css"
cat > "$RAW_PX_CSS" <<'CSS'
:root {
  --sg-space-3: 12px;
}

.foo {
  padding: 13px;
}
CSS

run_guard "$RAW_PX_CSS"
if [[ "$GUARD_EXIT" -ne 0 ]]; then
  pass "Guard exits non-zero ($GUARD_EXIT) on raw px in a token-eligible property"
else
  fail "Guard exited 0 (should have been non-zero) on 'padding: 13px' outside any token scope"
fi

if grep -qF 'raw px' "${TMPDIR_ROOT}/guard_stderr.txt" && grep -qF 'padding: 13px' "${TMPDIR_ROOT}/guard_stderr.txt" \
  && [[ "$(violation_count)" -eq 1 ]]; then
  pass "Guard stderr names the raw px violation (1 row)"
else
  fail "Guard stderr does not name the raw px violation; stderr: ${GUARD_STDERR}"
fi

PX_ALLOWLIST_CSS="${TMPDIR_ROOT}/px-allowlist.css"
cat > "$PX_ALLOWLIST_CSS" <<'CSS'
.foo {
  border-width: 1px;
  padding: 0px;
  width: 1px;
  height: 1px;
  margin: -1px;
  padding-left: var(--sg-space-3);
}
CSS

run_guard "$PX_ALLOWLIST_CSS"
if [[ "$GUARD_EXIT" -eq 0 ]]; then
  pass "Guard still exits 0 on a 1px border-width, 0px/1px values and a negative margin (allowlist unchanged)"
else
  fail "Guard exited non-zero ($GUARD_EXIT) on allowlisted px values; stderr: ${GUARD_STDERR}"
fi

# --------------------------------------------------------------------------
# Verify no real-repo side effects (only scripts/ci/ should differ)
# --------------------------------------------------------------------------
echo "Test G: no real-repo side effects (git status shows no unintended changes)"

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
set +e
DIRTY_FILES=$(git -C "$REPO_ROOT" status --short 2>/dev/null | grep -v '^\?\?' | grep -v "scripts/ci/" | grep -v ".planning/" || true)
set -e

if [[ -z "$DIRTY_FILES" ]]; then
  pass "No real-repo side effects outside scripts/ci/"
else
  fail "Unexpected dirty files in real repo: ${DIRTY_FILES}"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "admin-css-conformance.test: FAIL"
  exit 1
fi

echo "admin-css-conformance.test: PASS"
exit 0
