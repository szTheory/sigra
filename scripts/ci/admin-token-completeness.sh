#!/usr/bin/env bash
# Phase 207 (L1/L0-ELEVATION): merge-blocking token-completeness guard (D-06).
# Fails CI if the --sg-* token set in sigra_admin.css :root blocks diverges from
# the documented backtick tokens in admin-token-reference.md.
#
# Checks:
#   Diffs the set of --sg-* custom properties defined in :root blocks (both light
#   and dark) against the set of --sg-* tokens documented as backtick literals in
#   admin-token-reference.md. Fails on any divergence (undocumented token OR stale
#   doc row).
#
# Usage:
#   bash scripts/ci/admin-token-completeness.sh
#   bash scripts/ci/admin-token-completeness.sh [<css-file>]
#   bash scripts/ci/admin-token-completeness.sh --css <css-file> --doc <doc-file>
#   bash scripts/ci/admin-token-completeness.sh --help
#
# Defaults:
#   CSS: ROOT/priv/templates/sigra.install/admin/sigra_admin.css
#   DOC: ROOT/guides/reference/admin-token-reference.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSS_FILE="${CSS_FILE:-${ROOT}/priv/templates/sigra.install/admin/sigra_admin.css}"
DOC_FILE="${DOC_FILE:-${ROOT}/guides/reference/admin-token-reference.md}"

usage() {
  cat >&2 <<EOF
Usage: admin-token-completeness.sh [<css-file>]
       admin-token-completeness.sh --css <css-file> [--doc <doc-file>]
       admin-token-completeness.sh --help

Merge-blocking token-completeness guard (D-06). Diffs --sg-* tokens defined in
:root blocks of sigra_admin.css against documented backtick tokens in
admin-token-reference.md. Fails on any divergence:
  - Token defined in :root but not documented (undocumented token)
  - Token documented but not defined in :root (stale doc row)

Both the light :root block and the dark @media :root block are scanned.

Default CSS: ROOT/priv/templates/sigra.install/admin/sigra_admin.css
Default DOC: ROOT/guides/reference/admin-token-reference.md
EOF
  exit 2
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage;;
    --css) CSS_FILE="$2"; shift 2;;
    --doc) DOC_FILE="$2"; shift 2;;
    --*) echo "admin-token-completeness: FAIL: unknown arg: $1" >&2; exit 2;;
    *) CSS_FILE="$1"; shift;;
  esac
done

fail() {
  echo "admin-token-completeness: FAIL: $*" >&2
  exit 1
}

if [[ ! -f "$CSS_FILE" ]]; then
  fail "CSS file not found: ${CSS_FILE}"
fi

if [[ ! -f "$DOC_FILE" ]]; then
  fail "Doc file not found: ${DOC_FILE}"
fi

violations=0

# ------------------------------------------------------------------------------
# SET A: --sg-* tokens defined in :root blocks (both light and dark)
#
# Reuses the proven :root-tracking awk from admin-css-conformance.sh CHECK 2,
# but INVERTS the emit logic: emit=1 when INSIDE a :root block (not outside).
# This collects the token-definition lines from both the light :root (top of
# file) and the dark :root (inside @media (prefers-color-scheme: dark)).
# ------------------------------------------------------------------------------
ROOT_LINES=$(awk '
BEGIN {
  in_root = 0
  root_entry_depth = 0
  brace_depth = 0
}
{
  line = $0
  emit = 0

  if (in_root) {
    # Count braces on this line to track depth
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
    # Emit lines that are still inside :root after brace accounting
    emit = in_root ? 1 : 0
  } else if (line ~ /:root[[:space:]]*\{/) {
    # Entering a :root block — record entry depth, do not emit the opening line
    in_root = 1
    root_entry_depth = brace_depth + 1
    n = split(line, chars, "")
    for (i = 1; i <= n; i++) {
      if (chars[i] == "{") brace_depth++
      if (chars[i] == "}") brace_depth--
    }
    emit = 0
  } else {
    # Outside :root — track braces but do not emit
    n = split(line, chars, "")
    for (i = 1; i <= n; i++) {
      if (chars[i] == "{") brace_depth++
      if (chars[i] == "}") brace_depth--
    }
    emit = 0
  }

  if (emit) print line
}' "$CSS_FILE")

# Extract unique --sg-* token names from the in-root lines
SET_A_FILE="$(mktemp)"
trap 'rm -f "$SET_A_FILE" "$SET_B_FILE" 2>/dev/null || true' EXIT

echo "$ROOT_LINES" \
  | grep -oE '^[[:space:]]*--sg-[a-z0-9-]+[[:space:]]*:' \
  | grep -oE -- '--sg-[a-z0-9-]+' \
  | sort -u > "$SET_A_FILE"

TOKEN_COUNT=$(wc -l < "$SET_A_FILE" | tr -d '[:space:]')

# ------------------------------------------------------------------------------
# SET B: --sg-* tokens documented as backtick literals in the doc file
# ------------------------------------------------------------------------------
SET_B_FILE="$(mktemp)"
grep -oE '`--sg-[a-z0-9-]+`' "$DOC_FILE" | tr -d '`' | sort -u > "$SET_B_FILE"

DOC_COUNT=$(wc -l < "$SET_B_FILE" | tr -d '[:space:]')

# ------------------------------------------------------------------------------
# DIFF: tokens in :root but not documented (undocumented); tokens documented
# but not in :root (stale doc rows).
# ------------------------------------------------------------------------------
UNDOCUMENTED=$(comm -23 "$SET_A_FILE" "$SET_B_FILE")
STALE=$(comm -13 "$SET_A_FILE" "$SET_B_FILE")

if [[ -n "$UNDOCUMENTED" ]]; then
  echo "admin-token-completeness: FAIL: tokens defined in :root but NOT documented:" >&2
  while IFS= read -r token; do
    echo "  ${token}" >&2
  done <<< "$UNDOCUMENTED"
  violations=1
fi

if [[ -n "$STALE" ]]; then
  echo "admin-token-completeness: FAIL: tokens documented but NOT defined in :root (stale doc rows):" >&2
  while IFS= read -r token; do
    echo "  ${token}" >&2
  done <<< "$STALE"
  violations=1
fi

# ------------------------------------------------------------------------------
# Result
# ------------------------------------------------------------------------------
if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "admin-token-completeness: PASS — ${TOKEN_COUNT} tokens, :root == doc"
