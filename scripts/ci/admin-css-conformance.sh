#!/usr/bin/env bash
# Phase 206/207 (L1-COMPONENT-ELEVATION / L1/L0-ELEVATION): merge-blocking CSS
# conformance guard. Fails CI if sigra_admin.css contains forbidden patterns.
#
# Checks:
#   (a) No `transition: all` shorthand anywhere in the file.
#   (b) No raw hex color literals outside :root token-definition blocks.
#   (c) No raw px values in token-eligible property contexts (D-07, Phase 207).
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
  (c) raw px values in token-eligible property contexts outside :root (use var(--sg-*) tokens)
      Token-eligible: font-size, gap, padding, margin, width, height and variants.
      Explicitly skipped: box-shadow, border, border-radius, transform, @media,
      negative values, and the visually-hidden clip pattern.

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
# CHECK 3: No raw px values in token-eligible property contexts (D-07)
# Token-eligible properties are those whose values should use --sg-space-* or
# --sg-text-* tokens: font-size, gap, row-gap, column-gap, padding, margin,
# width, height, and their -top/-right/-bottom/-left/-inline/-block variants.
#
# Explicitly SKIPPED (not flagged — these are legitimate CSS idioms that must
# remain raw px):
#   - box-shadow, border, border-*, outline, border-radius, transform, @media
#   - visually-hidden clip pattern: negative margin (-1px) and 1px/0px
#     width/height/padding in blocks containing clip: or overflow: hidden
#   - Negative values (e.g. margin: -1px) — never a design-token candidate
#
# Strategy: strip :root blocks (reuse CHECK 2 awk), then filter to only the
# token-eligible property declarations, skip negatives, skip clip-pattern lines,
# and grep for bare Npx values that are NOT inside var().
# ------------------------------------------------------------------------------
echo "admin-css-conformance: CHECK 3 — no raw px in token-eligible contexts in ${CSS_FILE}"

PX_MATCHES=$(awk '
BEGIN {
  in_root = 0
  root_entry_depth = 0
  brace_depth = 0
}
{
  line = $0
  emit = 1

  if (in_root) {
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
    emit = 0
  } else {
    if (line ~ /:root[[:space:]]*\{/) {
      in_root = 1
      root_entry_depth = brace_depth + 1
      n = split(line, chars, "")
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      emit = 0
    } else {
      n = split(line, chars, "")
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      emit = 1
    }
  }

  if (emit) print NR ":" line
}' "$CSS_FILE" \
  | grep -E '^\d+:[[:space:]]*(font-size|(row-gap|column-gap|gap)|(padding|padding-top|padding-right|padding-bottom|padding-left|padding-inline|padding-block|padding-inline-start|padding-inline-end|padding-block-start|padding-block-end)|(margin|margin-top|margin-right|margin-bottom|margin-left|margin-inline|margin-block)|(width|height|min-width|min-height|max-width|max-height|inline-size|block-size))[[:space:]]*:' \
  | grep -E '[0-9]+px' \
  | grep -v 'var(--' \
  | grep -vE ':[[:space:]]*-[0-9]' \
  | grep -vE 'clip[[:space:]]*:|overflow[[:space:]]*:[[:space:]]*hidden' \
  | grep -vE ':[[:space:]]*(0px|1px)[[:space:]]*;?[[:space:]]*$' \
  || true)

if [[ -n "$PX_MATCHES" ]]; then
  echo "admin-css-conformance: FAIL: raw px in token-eligible context found:" >&2
  while IFS= read -r line; do
    echo "  $line" >&2
  done <<< "$PX_MATCHES"
  violations=1
else
  echo "admin-css-conformance: CHECK 3 PASS — no raw px in token-eligible contexts found"
fi

# ------------------------------------------------------------------------------
# Result
# ------------------------------------------------------------------------------
if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "admin-css-conformance: PASS — ${CSS_FILE}"
