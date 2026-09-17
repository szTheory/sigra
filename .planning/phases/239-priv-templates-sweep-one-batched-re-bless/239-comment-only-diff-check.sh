#!/usr/bin/env bash
# 239-comment-only-diff-check.sh — phase artifact, not repository tooling (D-04).
#
# SC-3, as written in the ROADMAP ("the re-bless diff contains only comment lines"), is
# structurally wrong at HEAD: only 80 of the 158 token-bearing lines under `priv/templates/` are
# `#`/`//`/`/*` comments — 57 are `@moduledoc`/`@doc` heredoc prose, 4 are single-line `@doc "…"`
# strings, and 17 are EEx-escaped HEEx tags. A syntactic `^[+-]\s*#` classifier would flag 78
# legitimate lines as stop-the-line events. This script replaces that syntactic test with an
# expected-removed-set containment check (239-RESEARCH.md §5.1 option 1): every removed line in
# the re-bless diff must appear, verbatim (path + trimmed text), in a frozen pre-sweep expected
# set (239-golden-expected.txt) — 139 union-token lines plus exactly 2 anchored merge-site
# neighbour lines, no blanket radius. That is strictly more precise than a comment-syntax rule and
# sidesteps the definitional argument entirely.
#
# Usage:
#   239-comment-only-diff-check.sh <diff-file>|- <expected-set-file>
#     <diff-file>          a unified diff, or `-` to read the diff from stdin
#     <expected-set-file>  239-golden-expected.txt (or an equivalent frozen expected set)
#
# Exit 0: every removed line's (path, trimmed text) pair is in the expected set, every changed
#         path is a known expected-set path, and no hunk is add-only. Prints, on stdout,
#         `changed_lines=<N>`, `removed_lines=<N>`, `files=<N>`, `nonconforming=<N>` (0) plus the
#         three sub-counters, so a vacuous pass is mechanically impossible to mistake for a real
#         pass.
# Exit 1: a containment violation (nonconforming > 0), OR a non-vacuity floor was not cleared
#         (removed_lines below the expected set's T: record count, or files below 30), OR the
#         input was empty/unreadable. Fails CLOSED on empty input (both the `-` stdin channel and
#         a zero-length file argument) because "no findings" must never be produced by "no input".
# Exit 2: usage error (wrong argument count — anything other than exactly two positional args).
#
# This script is deliberately NOT wired into any workflow, `mix ci` alias, or
# `scripts/ci/prohibitions/*.test.mjs` glob (Standing Constraint 5, D-04). Phase 239 builds no
# guard; Phase 241's `p18` slot owns turning a spec like this into durable CI tooling. This is an
# in-plan phase artifact, committed so the RED/GREEN demonstration in the SUMMARY is reproducible
# rather than a claim in prose.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <diff-file>|- <expected-set-file>" >&2
  exit 2
fi

diff_arg="$1"
expected_file="$2"

if [ "$diff_arg" = "-" ]; then
  content="$(cat)"
else
  if [ ! -r "$diff_arg" ]; then
    echo "FAIL: cannot read input file: $diff_arg" >&2
    exit 1
  fi
  content="$(cat "$diff_arg")"
fi

if [ -z "$content" ]; then
  echo "FAIL: empty diff input — refusing to report success on no input (fail-closed guard)" >&2
  exit 1
fi

if [ ! -r "$expected_file" ]; then
  echo "FAIL: cannot read expected-set file: $expected_file" >&2
  exit 1
fi

# --- Load the expected set --------------------------------------------------------------------
#
# Records are `T:path:line:text` (union-token line) or `N:path:line:text` (anchored merge-site
# neighbour). The leading `#` comment line (the generating command) and blank lines are skipped.
# The containment check below pairs on (path, trimmed text) only — never on line number, because
# the EEx header offsets template line numbers by 2 relative to the golden tree (RESEARCH §5.5).

expected_body="$(grep -vE '^#' "$expected_file" | sed '/^$/d' || true)"

if [ -z "$expected_body" ]; then
  echo "FAIL: expected-set file has no T:/N: records — refusing to report success on an empty expected set (fail-closed guard)" >&2
  exit 1
fi

# expected_lookup: one line per record, "path<TAB>trimmed-text" — used for containment lookup.
expected_lookup="$(printf '%s\n' "$expected_body" | awk -F: '{
  path=$2;
  # Reconstruct the text field: everything after the third colon-separated field.
  n = split($0, parts, ":");
  text = parts[4];
  for (i = 5; i <= n; i++) { text = text ":" parts[i]; }
  gsub(/^[ \t]+|[ \t]+$/, "", text);
  print path "\t" text;
}')"

expected_paths="$(printf '%s\n' "$expected_body" | cut -d: -f2 | sort -u)"

expected_t_count="$(printf '%s\n' "$expected_body" | grep -c '^T:' || true)"
if [ -z "$expected_t_count" ]; then
  expected_t_count=0
fi

# --- Diff parsing ----------------------------------------------------------------------------

# Removed lines only, excluding the diff's own file-header lines (`--- a/path`).
removed="$(printf '%s\n' "$content" | grep -E '^-' | grep -vE '^--- ' || true)"

removed_lines=0
if [ -n "$removed" ]; then
  removed_lines="$(printf '%s\n' "$removed" | grep -c '.' || true)"
fi

changed_lines=0
changed_raw="$(printf '%s\n' "$content" | grep -E '^[+-]' | grep -vE '^(--- |\+\+\+ )' || true)"
if [ -n "$changed_raw" ]; then
  changed_lines="$(printf '%s\n' "$changed_raw" | grep -c '.' || true)"
fi

# All `+++ b/<path>` targets touched by this diff, `b/` prefix stripped.
touched_paths="$(printf '%s\n' "$content" | grep -E '^\+\+\+ b/' | sed -E 's#^\+\+\+ b/##' | sort -u || true)"

files=0
if [ -n "$touched_paths" ]; then
  files="$(printf '%s\n' "$touched_paths" | grep -c '.' || true)"
fi

# --- Non-vacuity floors (both derived from quantities known exactly before the sweep runs) -----
#
# 1. removed_lines must be >= the number of T: records in the expected-set file. Every one of the
#    139 golden token lines must change and every changed line appears as a `^-` removal, so this
#    is an exact lower bound on removals. We do NOT floor on changed_lines: a correct diff is
#    ~139 removals plus only ~30 rewrite additions, so a `changed_lines >= 200`-style gate would
#    fail on the success path.
# 2. files must be >= 30 (expected 35).

floor_removed="$expected_t_count"
floor_files=30

echo "changed_lines=${changed_lines}"
echo "removed_lines=${removed_lines}"
echo "files=${files}"

if [ "$removed_lines" -lt "$floor_removed" ]; then
  echo "FAIL: removed_lines=${removed_lines} is below the required floor of ${floor_removed} (the number of T: records in the expected set) — refusing to report success on an incomplete diff (fail-closed guard)" >&2
  echo "nonconforming=" >&2
  exit 1
fi

if [ "$files" -lt "$floor_files" ]; then
  echo "FAIL: files=${files} is below the required floor of ${floor_files} — refusing to report success on an incomplete diff (fail-closed guard)" >&2
  echo "nonconforming=" >&2
  exit 1
fi

# --- Containment body: three independent violation classes -------------------------------------

# Class 1: nonconforming_removed — removed lines whose (path, trimmed text) pair is not in the
# expected set. Walk each hunk, tracking the current file from `+++ b/` headers, so each removed
# line is paired with the correct path.
nonconforming_removed_lines="$(printf '%s\n' "$content" | awk -v lookup_file=<(printf '%s\n' "$expected_lookup") '
  BEGIN {
    while ((getline line < lookup_file) > 0) {
      split(line, kv, "\t");
      known[kv[1] "\t" kv[2]] = 1;
    }
  }
  /^\+\+\+ b\// { path = $0; sub(/^\+\+\+ b\//, "", path); next }
  /^--- / { next }
  /^-/ {
    text = substr($0, 2);
    gsub(/^[ \t]+|[ \t]+$/, "", text);
    key = path "\t" text;
    if (!(key in known)) {
      print path ":" $0;
    }
  }
')"

nonconforming_removed=0
if [ -n "$nonconforming_removed_lines" ]; then
  nonconforming_removed="$(printf '%s\n' "$nonconforming_removed_lines" | grep -c '.' || true)"
fi

# Class 2: nonconforming_files — touched paths not present among the expected-set paths.
nonconforming_files_lines=""
if [ -n "$touched_paths" ]; then
  nonconforming_files_lines="$(comm -23 <(printf '%s\n' "$touched_paths") <(printf '%s\n' "$expected_paths") || true)"
fi

nonconforming_files=0
if [ -n "$nonconforming_files_lines" ]; then
  nonconforming_files="$(printf '%s\n' "$nonconforming_files_lines" | grep -c '.' || true)"
fi

# Class 3: nonconforming_addonly_hunks — hunks (`^@@`) containing at least one `+` line and zero
# `-` lines. This is the pure-addition drift path a removals-only containment check would miss.
nonconforming_addonly_hunks="$(printf '%s\n' "$content" | awk '
  function flush() {
    if (in_hunk && plus > 0 && minus == 0) { count++; }
  }
  /^@@/ { flush(); in_hunk = 1; plus = 0; minus = 0; next }
  in_hunk && /^\+/ && !/^\+\+\+ / { plus++; next }
  in_hunk && /^-/ && !/^--- / { minus++; next }
  END { flush(); print count+0; }
')"

nonconforming=$((nonconforming_removed + nonconforming_files + nonconforming_addonly_hunks))

echo "nonconforming=${nonconforming}"
echo "nonconforming_removed=${nonconforming_removed}"
echo "nonconforming_files=${nonconforming_files}"
echo "nonconforming_addonly_hunks=${nonconforming_addonly_hunks}"
echo "removed_lines_floor=${floor_removed}"

if [ "$nonconforming" -gt 0 ]; then
  echo "FAIL: ${nonconforming} nonconforming line(s)/path(s)/hunk(s) found:" >&2
  if [ -n "$nonconforming_removed_lines" ]; then
    printf '%s\n' "$nonconforming_removed_lines" >&2
  fi
  if [ -n "$nonconforming_files_lines" ]; then
    printf 'unexpected path: %s\n' "$nonconforming_files_lines" >&2
  fi
  exit 1
fi

exit 0
