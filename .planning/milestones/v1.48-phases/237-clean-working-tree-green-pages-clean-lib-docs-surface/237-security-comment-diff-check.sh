#!/usr/bin/env bash
# 237-security-comment-diff-check.sh — phase artifact, not repository tooling (D-04).
#
# Replaces SC-5's unfireable literal-marker check (`# SECURITY:`, which occurs zero times in
# this repository — see 237-RESEARCH.md §F.1) with a regex-class check that is DEMONSTRATED to
# fire. It reports, and exits non-zero on, any REMOVED line in a unified diff that mentions the
# rationale class (`security|CSRF|enumeration|timing|scope|impersonation`, case-insensitive) but
# carries no bookkeeping token (a decision id, a success-criterion id, a phase mention, or a
# planning-directory path). Lines carrying BOTH are tolerated by design — they are the rewrite
# case, reviewed rather than blocked (see 237-CONTEXT.md D-04 / 237-04-PLAN.md).
#
# Usage:
#   237-security-comment-diff-check.sh <path-to-unified-diff-file>
#   237-security-comment-diff-check.sh -            # read the diff from stdin
#
# Exit 0: no rationale line was removed without its meaning being preserved. Prints, on its own
#         line, `examined_removed_lines=<N>` so a pass that examined nothing is mechanically
#         impossible to mistake for a real pass.
# Exit 1: either a bare rationale line was removed, or the input was empty/unreadable. The check
#         fails CLOSED on empty input (both the `-` stdin channel and a zero-length file argument)
#         because "no findings" must never be produced by "no input".
# Exit 2: usage error (wrong argument count).
#
# This script is deliberately NOT wired into any workflow or prohibitions glob — the durable
# bookkeeping ratchet is Phase 241's `p18` slot. This is an in-plan phase artifact, committed so
# the RED/GREEN demonstration in the SUMMARY is reproducible rather than a claim in prose.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <diff-file>|-" >&2
  exit 2
fi

input_arg="$1"

if [ "$input_arg" = "-" ]; then
  content="$(cat)"
else
  if [ ! -r "$input_arg" ]; then
    echo "FAIL: cannot read input file: $input_arg" >&2
    exit 1
  fi
  content="$(cat "$input_arg")"
fi

if [ -z "$content" ]; then
  echo "FAIL: empty diff input — refusing to report success on no input (fail-closed guard)" >&2
  exit 1
fi

# Removed lines only, excluding the diff's own file-header lines (`--- a/path`). `+++ b/path`
# headers never match `^-` so they need no separate exclusion.
removed="$(printf '%s\n' "$content" | grep -E '^-' | grep -vE '^--- ' || true)"

examined=0
if [ -n "$removed" ]; then
  examined="$(printf '%s\n' "$removed" | grep -c '.' || true)"
fi

# Keep only removed lines that mention the rationale class.
class_hits="$(printf '%s\n' "$removed" | grep -iE '\b(security|CSRF|enumeration|timing|scope|impersonation)\b' || true)"

# Discard lines that ALSO carry a bookkeeping token — the tolerated rewrite case.
survivors="$(printf '%s\n' "$class_hits" | grep -vE '\b(D-[0-9]{2}|SC-[0-9]+|Phase [0-9]{1,3})\b|\.planning/' | sed '/^$/d' || true)"

if [ -n "$survivors" ]; then
  echo "FAIL: removed line(s) carry security/design rationale with no bookkeeping token:" >&2
  printf '%s\n' "$survivors" >&2
  exit 1
fi

echo "examined_removed_lines=${examined}"
exit 0
