#!/usr/bin/env bash
# Phase 214 (DEBT-05 / D-17): merge-blocking CSS corruption guard for app.css.
# Fails CI if app.css contains orphaned value fragments inside the :root block.
#
# Background: the sg-* -> sigra_admin.css split (reference_example_css_split)
# left behind orphaned CSS value bodies in test/example's :root block — bare
# multi-line shadow, transition, and focus-ring values with no property name.
# The CSS parser may silently drop adjacent rules when it encounters these
# malformed statements. This guard prevents the corruption from returning.
#
# Checks (inside :root {} blocks only):
#   (a) Bare numeric value lines: lines starting with optional whitespace then
#       a digit (e.g. "  0 0 0 1px rgba(..." with no property name)
#   (b) Bare transition value fragments: "  color var(--sg-..." with no property
#   (c) Bare focus-ring value fragments: "  color-mix(in oklab, var(--sg-..."
#       with no property name
#
# Explicitly NOT flagged (legitimate uses that must survive):
#   - var(--sg-*) references inside .vt-* selector rules (thousands of them)
#   - --sg-* custom property declarations (only in sigra_admin.css, not app.css)
#   - Multi-line values that follow a "property:" declaration on the prior line
#
# Usage:
#   bash scripts/ci/app-css-corruption-check.sh
#   bash scripts/ci/app-css-corruption-check.sh test/example/priv/static/assets/css/app.css
#
# Exit codes:
#   0 — no orphaned corruption found
#   1 — orphaned value fragments detected; lines printed to stderr
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSS_FILE="${1:-${ROOT}/test/example/priv/static/assets/css/app.css}"

if [ ! -f "$CSS_FILE" ]; then
  echo "ERROR: CSS file not found: $CSS_FILE" >&2
  exit 2
fi

# Use awk to scan only inside :root { ... } blocks and detect orphaned fragments.
#
# Strategy:
#   - Track brace depth starting from a ":root {" line.
#   - At depth 1 (directly inside :root, not nested), flag lines that are bare
#     CSS values (no property name — not "--prop:" and not "@media" etc.).
#   - Bare value signatures:
#       (a) Line starts with whitespace then a digit (shadow/numeric value fragment)
#       (b) Line starts with whitespace then "color var(--sg-" (transition fragment)
#       (c) Line starts with whitespace then "color-mix(in oklab, var(--sg-" (focus-ring)
#
# Multi-line property continuation lines (e.g. the value part of "--vt-shadow:")
# do start with a digit too, but they follow a "--prop:" declaration. To avoid
# false positives, track whether the previous non-blank line ended with ":"
# (a property declaration), or contained a CSS property name (has "--" or "word:").
# The simpler and more reliable approach: require the PREVIOUS non-blank line
# inside :root to have been a full property declaration (contains ":") OR to be
# a multi-line continuation of a declaration. If the line before the numeric is
# a proper declaration line (ends in "rgba(..." or similar), that is continuation.
#
# Revised approach: flag lines that look like orphaned values ONLY when the
# preceding context line (last non-blank, non-comment line) did NOT end with
# a property name colon pattern. We track "last_prop_line" inside :root.

FOUND=$(awk '
BEGIN {
  depth = 0
  in_root = 0
  last_was_prop = 0
  found = 0
}

# Track brace depth globally
{
  # Count opening braces on this line
  line = $0
  n = split(line, chars, "")
  open_count = 0
  close_count = 0
  for (i = 1; i <= n; i++) {
    if (chars[i] == "{") open_count++
    if (chars[i] == "}") close_count++
  }
}

# Detect :root { line (starts a root block at depth 0 -> 1)
/^:root[[:space:]]*\{/ {
  in_root = 1
  depth = 1
  last_was_prop = 0
  next
}

# While inside a :root block
in_root {
  # Update depth tracking
  depth = depth + open_count - close_count

  # Leaving the root block
  if (depth <= 0) {
    in_root = 0
    depth = 0
    next
  }

  # Only check at depth 1 (directly inside :root, not inside a nested block)
  if (depth != 1) {
    # Inside a media query nested :root or other nested block — skip
    last_was_prop = 0
    next
  }

  # Skip blank lines and comment-only lines
  if (/^[[:space:]]*$/ || /^[[:space:]]*\/\*/ || /^[[:space:]]*\*/) {
    next
  }

  # A proper CSS custom property declaration: starts with --  followed by name:
  # Phase 221 Plan 02 (SHIP-03 / D-09): a complete single-line declaration
  # (ends in ";") is NOT an opener — reset last_was_prop so the next line is
  # evaluated fresh instead of being absorbed as a continuation.
  if (/^[[:space:]]*--[a-zA-Z]/) {
    if (/;[[:space:]]*$/) {
      last_was_prop = 0
    } else {
      last_was_prop = 1
    }
    next
  }

  # A proper standard declaration: starts with a word then colon (like color-scheme: light)
  if (/^[[:space:]]*[a-zA-Z][a-zA-Z-]*[[:space:]]*:/) {
    if (/;[[:space:]]*$/) {
      last_was_prop = 0
    } else {
      last_was_prop = 1
    }
    next
  }

  # A continuation line: if last was a property declaration, this is the value body
  # Continuation lines end with ";" only on the last line of a multi-line value,
  # or with "," for intermediate lines. Allow them only when last_was_prop=1.
  if (last_was_prop) {
    # This is a legitimate multi-line value continuation — allow it
    # Check if this line ends the declaration (has ";") — next line resets
    if (/;[[:space:]]*$/) {
      last_was_prop = 0
    }
    # else it is still continuing; last_was_prop stays 1
    next
  }

  # At this point: in :root, depth 1, not a comment, not a proper declaration,
  # and last_was_prop=0 (no preceding property declaration). Flag if it looks
  # like a bare value fragment.

  # Pattern (a): starts with optional whitespace then a digit (bare numeric value)
  if (/^[[:space:]]+[0-9]/) {
    print "ORPHAN (bare numeric value): " NR ": " $0
    found = 1
    next
  }

  # Pattern (b): bare transition value starting with "color var(--sg-"
  if (/^[[:space:]]+color var\(--sg-/) {
    print "ORPHAN (bare transition fragment): " NR ": " $0
    found = 1
    next
  }

  # Pattern (c): bare focus-ring value "color-mix(in oklab, var(--sg-"
  if (/^[[:space:]]+color-mix\(in oklab, var\(--sg-/) {
    print "ORPHAN (bare focus-ring fragment): " NR ": " $0
    found = 1
    next
  }

  # Other unrecognized line inside :root at depth 1 — treat as property or ignore
  # (do not flag — conservative approach to avoid false positives)
  last_was_prop = 0
}

END {
  exit found
}
' "$CSS_FILE" 2>&1)

if [ -n "$FOUND" ]; then
  echo "FAIL: Orphaned value fragments detected in :root block of $CSS_FILE" >&2
  echo "$FOUND" >&2
  echo "" >&2
  echo "These are bare CSS values with no property name — a sign of the sg-* split corruption." >&2
  echo "Delete the orphaned lines from the :root block. Do NOT reconstruct --sg-* tokens here;" >&2
  echo "they belong in sigra_admin.css." >&2
  exit 1
fi

echo "OK: no orphaned value fragments in :root block of $CSS_FILE"
