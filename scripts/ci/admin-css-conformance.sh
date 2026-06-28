#!/usr/bin/env bash
# Phase 206 (L1-COMPONENT-ELEVATION): merge-blocking CSS conformance guard.
# Fails CI if sigra_admin.css contains forbidden patterns.
#
# Checks:
#   (a) No `transition: all` shorthand anywhere in the file.
#   (b) No raw hex color literals outside :root token-definition blocks.
#
# Usage:
#   bash scripts/ci/admin-css-conformance.sh [<css-file>]
#   bash scripts/ci/admin-css-conformance.sh [--css <css-file>]
#   bash scripts/ci/admin-css-conformance.sh --help
#
# The guard defaults to ROOT/priv/templates/sigra.install/admin/sigra_admin.css.
# Pass a positional argument or --css <path> to override for use in other phases.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSS_FILE="${CSS_FILE:-${ROOT}/priv/templates/sigra.install/admin/sigra_admin.css}"

usage() {
  cat >&2 <<EOF
Usage: admin-css-conformance.sh [<css-file>]
       admin-css-conformance.sh --css <css-file>
       admin-css-conformance.sh --help

Merge-blocking CSS conformance guard. Fails if sigra_admin.css contains:
  (a) transition: all shorthand (use specific transition properties instead)
  (b) raw hex color literals outside :root token-definition blocks (use var() references)

Default target: ROOT/priv/templates/sigra.install/admin/sigra_admin.css
EOF
  exit 2
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage;;
    --css) CSS_FILE="$2"; shift 2;;
    --*) echo "admin-css-conformance: FAIL: unknown arg: $1" >&2; exit 2;;
    *) CSS_FILE="$1"; shift;;
  esac
done

fail() {
  echo "admin-css-conformance: FAIL: $*" >&2
  exit 1
}

if [[ ! -f "$CSS_FILE" ]]; then
  fail "CSS file not found: ${CSS_FILE}"
fi

violations=0

# ------------------------------------------------------------------------------
# CHECK 1: No `transition: all` shorthand
# The property `transition: all` shorthand triggers all CSS properties on every
# state change — a motion anti-pattern that bypasses prefers-reduced-motion
# scoping of individual properties. Use specific transition properties instead.
# ------------------------------------------------------------------------------
echo "admin-css-conformance: CHECK 1 — no 'transition: all' in ${CSS_FILE}"

TRANSITION_MATCHES=$(grep -n "transition: all" "$CSS_FILE" || true)
if [[ -n "$TRANSITION_MATCHES" ]]; then
  echo "admin-css-conformance: FAIL: 'transition: all' found:" >&2
  while IFS= read -r line; do
    echo "  $line" >&2
  done <<< "$TRANSITION_MATCHES"
  violations=1
else
  echo "admin-css-conformance: CHECK 1 PASS — no 'transition: all' found"
fi

# ------------------------------------------------------------------------------
# CHECK 2: No raw hex color literals outside :root token-definition blocks
# All hex color values must live inside :root { ... } blocks (where they define
# design tokens). Outside :root, use var(--sg-*) references instead.
#
# Strategy: use awk to track :root block depth, emit lines NOT inside any :root
# block, then grep those lines for hex color literals.
#
# Handles nested :root blocks correctly (e.g. @media { :root { ... } }).
# The awk exits each :root protection scope when the brace depth returns to
# the level at which :root was entered.
# ------------------------------------------------------------------------------
echo "admin-css-conformance: CHECK 2 — no raw hex outside :root blocks in ${CSS_FILE}"

NON_ROOT_LINES=$(awk '
BEGIN {
  in_root = 0
  root_entry_depth = 0
  brace_depth = 0
}
{
  # Track brace depth for the entire line before deciding emit/suppress
  line = $0
  emit = 1

  if (in_root) {
    # Count braces on this line
    n = split(line, chars, "")
    for (i = 1; i <= n; i++) {
      if (chars[i] == "{") brace_depth++
      if (chars[i] == "}") {
        brace_depth--
        if (brace_depth < root_entry_depth) {
          in_root = 0
          break
        }
      }
    }
    # Lines inside :root are suppressed (not emitted for hex check)
    emit = (in_root ? 0 : 0)
    # Note: if we just exited :root on this line, the closing } itself is not
    # a hex-literal risk; suppress it to avoid false positives.
    emit = 0
  } else {
    # Check if this line starts a :root block
    if (line ~ /:root[[:space:]]*\{/) {
      in_root = 1
      root_entry_depth = brace_depth + 1
      # Count braces on this line to advance depth
      n = split(line, chars, "")
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      # Suppress this :root { line itself (it is the boundary, not content)
      emit = 0
    } else {
      # Count braces on non-root lines to track depth
      n = split(line, chars, "")
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      emit = 1
    }
  }

  if (emit) print NR ":" line
}
' "$CSS_FILE")

HEX_MATCHES=$(echo "$NON_ROOT_LINES" | grep -E '#[0-9a-fA-F]{3,8}\b' || true)

if [[ -n "$HEX_MATCHES" ]]; then
  echo "admin-css-conformance: FAIL: raw hex color outside :root found:" >&2
  while IFS= read -r line; do
    echo "  $line" >&2
  done <<< "$HEX_MATCHES"
  violations=1
else
  echo "admin-css-conformance: CHECK 2 PASS — no raw hex outside :root found"
fi

# ------------------------------------------------------------------------------
# Result
# ------------------------------------------------------------------------------
if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "admin-css-conformance: PASS — ${CSS_FILE}"
