#!/usr/bin/env bash
# Phase 216 (HARNESS-FOUNDATION): settled-findings.tsv integrity lint (D-22).
#
# Enforces that guides/reference/settled-findings.tsv is:
#   (a) sorted by finding_id (column 1) — lexicographic ascending
#   (b) free of duplicate finding_id values
#   (c) every data row has exactly 7 tab-separated columns
#
# An empty data set (header-only file) PASSES trivially.
#
# --add mode: appends a new row and re-sorts the file in place.
# Humans must never hand-edit ordering — use --add instead (D-22).
#
# Usage (lint mode):
#   scripts/ci/settled-findings-lint.sh [--base <ref>]
#
# Usage (add mode):
#   scripts/ci/settled-findings-lint.sh --add <finding_id> \
#       --surface <surface> --class <class> --anchor <anchor> \
#       --disposition <waived|resolved> [--waived-by <who>] [--note <text>]
#
# finding_id format: sha256(surface NUL class NUL anchor) — 64 lowercase hex chars.
# The --add mode accepts a pre-computed finding_id.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TSV="${ROOT}/guides/reference/settled-findings.tsv"

fail() {
  echo "settled-findings-lint: FAIL: $*" >&2
  exit 1
}

# --------------------------------------------------------------------------
# --add mode
# --------------------------------------------------------------------------
if [[ "${1:-}" == "--add" ]]; then
  shift
  # Parse --add arguments.
  FINDING_ID=""
  SURFACE=""
  CLASS=""
  ANCHOR=""
  DISPOSITION=""
  WAIVED_BY=""
  NOTE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --surface)      SURFACE="$2";      shift 2;;
      --class)        CLASS="$2";        shift 2;;
      --anchor)       ANCHOR="$2";       shift 2;;
      --disposition)  DISPOSITION="$2";  shift 2;;
      --waived-by)    WAIVED_BY="$2";    shift 2;;
      --note)         NOTE="$2";         shift 2;;
      --*)
        echo "settled-findings-lint: FAIL: unknown --add arg: $1" >&2; exit 2;;
      *)
        if [[ -z "$FINDING_ID" ]]; then
          FINDING_ID="$1"; shift
        else
          echo "settled-findings-lint: FAIL: unexpected positional arg: $1" >&2; exit 2
        fi
        ;;
    esac
  done

  # Validate required fields.
  [[ -z "$FINDING_ID" ]]   && fail "--add requires a finding_id as the first positional argument"
  [[ -z "$SURFACE" ]]      && fail "--add requires --surface"
  [[ -z "$CLASS" ]]        && fail "--add requires --class"
  [[ -z "$ANCHOR" ]]       && fail "--add requires --anchor"
  [[ -z "$DISPOSITION" ]]  && fail "--add requires --disposition"
  [[ "$DISPOSITION" != "waived" && "$DISPOSITION" != "resolved" ]] && \
    fail "--disposition must be 'waived' or 'resolved', got: $DISPOSITION"

  # Validate finding_id format: exactly 64 lowercase hex chars.
  if ! [[ "$FINDING_ID" =~ ^[0-9a-f]{64}$ ]]; then
    fail "finding_id must be 64 lowercase hex chars (sha256), got: $FINDING_ID"
  fi

  # Build the new TSV row (7 columns, tab-separated).
  NEW_ROW="${FINDING_ID}	${SURFACE}	${CLASS}	${ANCHOR}	${DISPOSITION}	${WAIVED_BY}	${NOTE}"

  # Check for duplicate finding_id before appending.
  if grep -v '^#' "$TSV" | cut -f1 | grep -qxF "$FINDING_ID" 2>/dev/null; then
    fail "finding_id already exists in settled-findings.tsv: $FINDING_ID"
  fi

  # Append the new row and re-sort the file in place (preserving the header).
  HEADER=$(grep '^#' "$TSV")
  DATA=$(grep -v '^#' "$TSV" || true)

  # Build sorted data including the new row.
  SORTED_DATA=$(
    {
      [[ -n "$DATA" ]] && echo "$DATA"
      echo "$NEW_ROW"
    } | sort -t$'\t' -k1,1
  )

  {
    echo "$HEADER"
    echo "$SORTED_DATA"
  } > "$TSV"

  echo "settled-findings-lint: added and sorted: $FINDING_ID"
  exit 0
fi

# --------------------------------------------------------------------------
# Lint mode (default)
# --------------------------------------------------------------------------

# Consume --base arg (accepted for symmetry with other guards; not used in lint).
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) shift 2;;
    *) echo "settled-findings-lint: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ ! -f "$TSV" ]]; then
  fail "settled-findings.tsv not found at ${TSV}"
fi

# Extract data rows (skip # comment/header lines).
DATA=$(grep -v '^#' "$TSV" || true)

# An empty data set passes trivially.
if [[ -z "$DATA" ]]; then
  echo "settled-findings-lint: PASS (no data rows — trivially valid)"
  exit 0
fi

# Check (c): every row must have exactly 7 tab-separated columns.
violations=0
row_num=0
while IFS= read -r line; do
  row_num=$((row_num + 1))
  col_count=$(echo "$line" | awk -F'\t' '{print NF}')
  if [[ "$col_count" -ne 7 ]]; then
    echo "settled-findings-lint: FAIL: row $row_num has $col_count columns (expected 7): $line" >&2
    violations=1
  fi
done <<< "$DATA"

if [[ "$violations" -ne 0 ]]; then exit 1; fi

# Extract finding_ids (column 1).
FINDING_IDS=$(echo "$DATA" | cut -f1)

# Check (a): data rows must be sorted by finding_id (lexicographic ascending).
SORTED_IDS=$(echo "$FINDING_IDS" | sort)
if [[ "$FINDING_IDS" != "$SORTED_IDS" ]]; then
  echo "settled-findings-lint: FAIL: rows are not sorted by finding_id (column 1)" >&2
  echo "settled-findings-lint: FAIL: run: scripts/ci/settled-findings-lint.sh --add to add new entries" >&2
  exit 1
fi

# Check (b): no duplicate finding_id values.
DEDUPED_IDS=$(echo "$FINDING_IDS" | sort -u)
if [[ "$FINDING_IDS" != "$DEDUPED_IDS" ]]; then
  # Find and report the duplicates.
  DUPES=$(echo "$FINDING_IDS" | sort | uniq -d)
  echo "settled-findings-lint: FAIL: duplicate finding_id values found:" >&2
  echo "$DUPES" | while read -r d; do
    echo "  $d" >&2
  done
  exit 1
fi

ROW_COUNT=$(echo "$DATA" | wc -l | tr -d ' ')
echo "settled-findings-lint: PASS (${ROW_COUNT} rows validated — sorted, deduplicated, 7-column)"
