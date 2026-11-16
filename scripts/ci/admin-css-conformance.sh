#!/usr/bin/env bash
# Phase 206/207 (L1-COMPONENT-ELEVATION / L1/L0-ELEVATION): merge-blocking CSS
# conformance guard. Fails CI if sigra_admin.css contains forbidden patterns.
#
# Checks:
#   (a) No `transition: all` shorthand anywhere in the file.
#   (b) No raw hex color literals outside token-definition scopes.
#   (c) No raw px values in token-eligible property contexts (D-07, Phase 207).
#
# Token-definition scopes (the only places a raw colour may live):
#   - :root { ... } blocks
#   - explicit-theme token blocks (Phase 260, BGEN-04/05): a rule whose selector
#     is exactly `html[data-sg-admin-theme="light|dark"] .sg-admin-shell` or
#     `.sg-admin-shell[data-theme="light|dark"]`. Inside such a block only
#     `--sg-*` declarations and `color-scheme` are exempt; any other line is
#     still checked, so a hex colour in a normal declaration there still fails.
#
# Usage:
#   bash scripts/ci/admin-css-conformance.sh [<css-file>]
#   bash scripts/ci/admin-css-conformance.sh [--css <css-file>]
#   bash scripts/ci/admin-css-conformance.sh --help
#
# The guard defaults to ROOT/priv/templates/sigra.install/admin/sigra_admin.css.
# Pass a positional argument or --css <path> to override for use in other phases.
#
# Portability: runs on BSD (darwin) and GNU (ubuntu CI) userlands. The awk program
# is POSIX-only (no gawk extensions, no regex intervals, so it also runs on mawk)
# and the grep filters use POSIX classes, never backslash shorthands.
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
  (b) raw hex color literals outside token-definition scopes (use var() references)
      Token-definition scopes: :root blocks, and the explicit-theme token blocks
      (html[data-sg-admin-theme="light|dark"] .sg-admin-shell and
      .sg-admin-shell[data-theme="light|dark"]) where only --sg-* declarations
      and color-scheme are exempt.
  (c) raw px values in token-eligible property contexts outside those scopes
      (use var(--sg-*) tokens)
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
# strip_protected_scopes: print "NR:line" for every line of the CSS file that is
# NOT inside a protected token-definition scope. CHECK 2 (hex) and CHECK 3 (px)
# both read this output, so the two checks cannot drift apart.
#
# Scope 1, :root { ... }: every line inside is suppressed. Handles nested :root
# blocks (e.g. @media { :root { ... } }): the scope ends when the brace depth
# returns to the level at which :root was entered.
#
# Scope 2, an explicit-theme token block (see the header): entered only when the
# whole selector list (a selector may start on the previous line after a comma)
# is made of the four exact explicit-theme selectors and the `{` ends its line.
# Brand-mark and theme-switch rules also begin with html[data-sg-admin-theme=...]
# but target other classes, so they never match. Inside the scope a line is
# suppressed only when it is blank, a comment, a closing brace, or exactly one
# `--sg-*` / `color-scheme` declaration (or a continuation line of one). Every
# other line is emitted, so raw hex in any other declaration still fails.
# ------------------------------------------------------------------------------
strip_protected_scopes() {
  awk '
  function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
  }

  # 1 when every comma-separated selector in `list` is one of the four exact
  # explicit-theme selectors (whitespace-normalised), else 0.
  function theme_selectors_ok(list,    parts, m, k, p, ok) {
    m = split(list, parts, ",")
    ok = 0
    for (k = 1; k <= m; k++) {
      p = trim(parts[k])
      gsub(/[[:space:]]+/, " ", p)
      if (p == SEL_LIGHT_HTML || p == SEL_DARK_HTML || p == SEL_LIGHT_SHELL || p == SEL_DARK_SHELL) {
        ok = 1
      } else {
        return 0
      }
    }
    return ok
  }

  # For a line inside an explicit-theme block: 1 = still subject to the hex/px
  # checks, 0 = a legitimate token line. Tracks multi-line declarations and
  # multi-line comments through the in_decl / in_comment globals.
  function theme_line_emits(l,    t, a, b, c, opens, closes) {
    t = trim(l)

    if (in_comment) {
      b = index(t, "*/")
      if (b == 0) return 0
      in_comment = 0
      return (trim(substr(t, b + 2)) == "") ? 0 : 1
    }

    a = index(t, "/*")
    if (a > 0) {
      b = index(t, "*/")
      c = t
      opens = gsub(/\/\*/, "", c)
      c = t
      closes = gsub(/\*\//, "", c)
      if (opens == 1 && closes == 0 && a == 1) {
        in_comment = 1
        return 0
      }
      if (opens == 1 && closes == 1 && a < b && substr(t, length(t) - 1) == "*/") {
        t = trim(substr(t, 1, a - 1))
      } else {
        return 1
      }
    }

    if (in_decl) {
      if (t ~ /^[^;]*;$/) {
        in_decl = 0
        return 0
      }
      if (t ~ /^[^;]*$/) return 0
      in_decl = 0
      return 1
    }

    if (t == "") return 0
    if (t == "}") return 0
    if (t ~ /^(--sg-[A-Za-z0-9_-]+|color-scheme)[[:space:]]*:[^;{}]*;$/) return 0
    if (t ~ /^(--sg-[A-Za-z0-9_-]+|color-scheme)[[:space:]]*:[^;{}]*$/) {
      in_decl = 1
      return 0
    }
    return 1
  }

  BEGIN {
    scope = 0
    entry_depth = 0
    brace_depth = 0
    sel = ""
    in_decl = 0
    in_comment = 0
    q = "\""
    SEL_LIGHT_HTML = "html[data-sg-admin-theme=" q "light" q "] .sg-admin-shell"
    SEL_DARK_HTML = "html[data-sg-admin-theme=" q "dark" q "] .sg-admin-shell"
    SEL_LIGHT_SHELL = ".sg-admin-shell[data-theme=" q "light" q "]"
    SEL_DARK_SHELL = ".sg-admin-shell[data-theme=" q "dark" q "]"
  }
  {
    line = $0
    emit = 1
    n = split(line, chars, "")

    if (scope != 0) {
      if (scope == 2) {
        emit = theme_line_emits(line)
      } else {
        emit = 0
      }
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") {
          brace_depth--
          if (brace_depth < entry_depth) {
            scope = 0
            break
          }
        }
      }
    } else if (line ~ /:root[[:space:]]*\{/) {
      scope = 1
      entry_depth = brace_depth + 1
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      sel = ""
      # The :root { line itself is the boundary, not content.
      emit = 0
    } else {
      enter_theme = 0
      p = index(line, "{")
      if (p > 0) {
        if (substr(line, p + 1) ~ /^[[:space:]]*$/ && theme_selectors_ok(sel " " substr(line, 1, p - 1))) {
          enter_theme = 1
        }
        sel = ""
      } else {
        t = trim(line)
        if (t ~ /,$/) {
          sel = sel " " t
        } else {
          sel = ""
        }
      }
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace_depth++
        if (chars[i] == "}") brace_depth--
      }
      if (enter_theme) {
        scope = 2
        entry_depth = brace_depth
        in_decl = 0
        in_comment = 0
        # The selector { line itself is the boundary, not content.
        emit = 0
      }
    }

    if (emit) print NR ":" line
  }
  ' "$CSS_FILE"
}

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
# CHECK 2: No raw hex color literals outside token-definition scopes
# All hex color values must live inside :root { ... } blocks or explicit-theme
# token blocks (where they define design tokens). Elsewhere, use var(--sg-*)
# references instead. See strip_protected_scopes for the scope rules.
# ------------------------------------------------------------------------------
echo "admin-css-conformance: CHECK 2 — no raw hex outside :root blocks in ${CSS_FILE}"

NON_ROOT_LINES=$(strip_protected_scopes)

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
# Strategy: strip the protected scopes (same awk as CHECK 2), then filter to only
# the token-eligible property declarations, skip negatives, skip clip-pattern
# lines, and grep for bare Npx values that are NOT inside var().
# ------------------------------------------------------------------------------
echo "admin-css-conformance: CHECK 3 — no raw px in token-eligible contexts in ${CSS_FILE}"

PX_MATCHES=$(strip_protected_scopes \
  | grep -E '^[0-9]+:[[:space:]]*(font-size|(row-gap|column-gap|gap)|(padding|padding-top|padding-right|padding-bottom|padding-left|padding-inline|padding-block|padding-inline-start|padding-inline-end|padding-block-start|padding-block-end)|(margin|margin-top|margin-right|margin-bottom|margin-left|margin-inline|margin-block)|(width|height|min-width|min-height|max-width|max-height|inline-size|block-size))[[:space:]]*:' \
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
