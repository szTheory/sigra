#!/usr/bin/env bash
# 239-v3-vocabulary-check.sh — phase artifact, not repository tooling (D-04).
#
# WHAT THIS IS
#
# The V3 bookkeeping definition, runnable. V1 matched a narrow set of plan identifiers and
# certified `priv/templates/` clean at 0 while 8 bookkeeping lines shipped. V2 widened the
# identifier set and measured that 0->8 delta — but V2 is still an IDENTIFIER regex (`D-12`,
# `239-05`, run ids, `UAT`), and `239-VERIFICATION.md`'s SC-1 gap is two sentences of plan
# VOCABULARY (`the plan-checker …`, `… a v1.2 concern.`) that no identifier pattern can match.
# V3 = V2, verbatim and entire, plus a vocabulary alternation class.
#
# THE CRITERION (D-30)
#
# Detection WIDTH and asserted SURFACE are separate. V3 stays maximally wide and is never
# narrowed, tuned, or hand-fitted to whatever the tree happens to contain. What the criterion
# asserts is `hits_outside_allowlist = 0` over a pre-committed tier file list, with the raw
# `hits=` total printed alongside on every single run so the allowlist can never hide a number.
#
# Usage:
#   239-v3-vocabulary-check.sh <tier>
#   239-v3-vocabulary-check.sh --files [<path> ...]
#
#     <tier> is one of:
#       priv-templates   every tracked file under priv/templates
#       example          ONLY the two SC-4 mirrored counterparts (enumerated literally below).
#                        Deliberately not the whole example tree: SC-4 governs the mirror and
#                        nothing else in that tree is inside this phase's contract. The unswept
#                        remainder is a measured, routed number — see the routing todo.
#       golden           every tracked file under test/fixtures/install_golden/tree
#
#     --files takes an explicit list; passing none is the empty-input case and fails closed.
#
#   Env: V3_ALLOWLIST overrides the allowlist path (used only to demonstrate the fail-closed
#        paths live against a deliberately corrupted copy; such copies are never committed).
#
# Exit codes — 1 and 3 are deliberately distinct. If "the instrument cannot answer" shared an
# exit code with "the surface is dirty", a broken script would be indistinguishable from a
# demonstrated RED, which is the exact failure shape this closure exists to repair.
#
#   0  hits_outside_allowlist=0 AND control_defmodule non-zero AND every applicable allowlist
#      entry passed its non-vacuity control AND every allowlist entry is exercised by at least
#      one of the three named tiers.
#   1  hits_outside_allowlist >= 1. THE SURFACE IS DIRTY. Only ever for that reason.
#   2  usage error.
#   3  FAIL-CLOSED — THE INSTRUMENT CANNOT ANSWER. Prints `refusing to report success`. Raised
#      for: an empty file list; control_defmodule = 0; an allowlist entry applicable to this run
#      (its path is in the file list being measured) that no longer covers anything; an allowlist
#      entry exercised by none of the three tiers; or V2 not being a substring of V3.
#
# This script is deliberately NOT wired into any workflow, `mix ci` alias, or
# `scripts/ci/prohibitions/*.test.mjs` glob (Standing Constraint 5, D-04). Phase 239 builds no
# guard; Phase 241's SURF-04 `p18` slot owns turning this spec into durable CI tooling.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "FAIL: not inside a git repository — refusing to report success (fail-closed guard)" >&2
  exit 3
fi
cd "$REPO_ROOT" || exit 3

ALLOWLIST="${V3_ALLOWLIST:-$SELF_DIR/239-v3-allowlist.tsv}"

# --- The definition ---------------------------------------------------------------------------
#
# V2 is copied mechanically out of `239-EVIDENCE.md` § WIDENED-UNION-LEDGER (a), never retyped.
# V3 appends one vocabulary class to it, so "strictly wider than V2" is a substring property that
# the script itself asserts below rather than a claim in prose.

V2='\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]'

V3_VOCAB='\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md'

V3="${V2}|${V3_VOCAB}"

case "$V3" in
  *"$V2"*) : ;;
  *)
    echo "FAIL: V2 is not a substring of V3 — refusing to report success on a definition that is not strictly wider (fail-closed guard)" >&2
    exit 3
    ;;
esac

# --- Tier file lists — FIXED HERE, consumed by plans 239-11, 239-12 and 239-13 -----------------

EXAMPLE_COUNTERPART_1='test/example/lib/example_web/live/invitation_accept_live.ex'
EXAMPLE_COUNTERPART_2='test/example/lib/example_web/live/organization_members_live.ex'

tier_file_list() {
  case "$1" in
    priv-templates) git ls-files priv/templates ;;
    example)        printf '%s\n%s\n' "$EXAMPLE_COUNTERPART_1" "$EXAMPLE_COUNTERPART_2" ;;
    golden)         git ls-files test/fixtures/install_golden/tree ;;
    *)              return 1 ;;
  esac
}

# --- Argument handling -------------------------------------------------------------------------

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <priv-templates|example|golden> | --files [<path> ...]" >&2
  exit 2
fi

TIER="$1"
shift

FILES=()
if [ "$TIER" = "--files" ]; then
  TIER="explicit-file-list"
  for f in "$@"; do FILES+=("$f"); done
else
  if ! tier_file_list "$TIER" >/dev/null 2>&1; then
    echo "usage: $0 <priv-templates|example|golden> | --files [<path> ...]" >&2
    exit 2
  fi
  while IFS= read -r f; do
    [ -n "$f" ] && FILES+=("$f")
  done < <(tier_file_list "$TIER")
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "tier=${TIER}"
  echo "FAIL: empty file list — refusing to report success on no input (fail-closed guard)" >&2
  exit 3
fi

# --- Allowlist ----------------------------------------------------------------------------------
#
# TSV: path <TAB> literal <TAB> reason. Matching is keyed on (path, literal) — never on a line
# number, never on a path alone — so an entry cannot silently start covering something new when
# lines shift, and cannot blanket a whole file.

if [ ! -r "$ALLOWLIST" ]; then
  echo "FAIL: cannot read allowlist: $ALLOWLIST — refusing to report success (fail-closed guard)" >&2
  exit 3
fi

AL_PATHS=()
AL_LITERALS=()
while IFS=$'\t' read -r a_path a_literal a_reason; do
  case "$a_path" in ''|'#'*) continue ;; esac
  [ -z "$a_literal" ] && continue
  AL_PATHS+=("$a_path")
  AL_LITERALS+=("$a_literal")
done < "$ALLOWLIST"

if [ "${#AL_PATHS[@]}" -eq 0 ]; then
  echo "FAIL: allowlist has no records — refusing to report success on an empty allowlist (fail-closed guard)" >&2
  exit 3
fi

# --- Union check: no allowlist entry may escape its control everywhere -------------------------
#
# The non-vacuity control below is scoped to the entries a given run actually exercises (an entry
# whose path is not in this tier's file list is simply not exercised here, and that is not a
# vacuity failure). That scoping opens exactly one hole: an entry whose path appears in NO tier
# would be checked nowhere. This check, computed once over the union of the three named tier file
# lists and independent of which tier is being measured, closes it.

UNION="$( { tier_file_list priv-templates; tier_file_list example; tier_file_list golden; } 2>/dev/null )"

i=0
while [ "$i" -lt "${#AL_PATHS[@]}" ]; do
  if ! printf '%s\n' "$UNION" | grep -qxF -- "${AL_PATHS[$i]}"; then
    echo "FAIL: allowlist entry '${AL_PATHS[$i]}' is exercised by none of the three named tiers — refusing to report success on an allowlist entry that escapes its own control (fail-closed guard)" >&2
    exit 3
  fi
  i=$((i + 1))
done

# --- Per-entry non-vacuity control, scoped to the entries this run exercises --------------------

FILE_LIST_TEXT="$(printf '%s\n' "${FILES[@]}")"

i=0
while [ "$i" -lt "${#AL_PATHS[@]}" ]; do
  a_path="${AL_PATHS[$i]}"
  a_literal="${AL_LITERALS[$i]}"
  if printf '%s\n' "$FILE_LIST_TEXT" | grep -qxF -- "$a_path"; then
    covered="$( { grep -F -- "$a_literal" "$a_path" 2>/dev/null || true; } | { grep -cE "$V3" || true; } )"
    if [ "${covered:-0}" -eq 0 ]; then
      echo "FAIL: refusing to report success on a vacuous allowlist entry: ${a_path} :: ${a_literal}" >&2
      exit 3
    fi
  fi
  i=$((i + 1))
done

# --- Measure -----------------------------------------------------------------------------------
#
# Brace group + `|| true` around every counting grep: a zero-match grep is a measurement, not a
# fatal status (SAFETY RULESET 3).

HITS_RAW="$( { grep -HnE "$V3" "${FILES[@]}" 2>/dev/null || true; } )"

hits=0
[ -n "$HITS_RAW" ] && hits="$( printf '%s\n' "$HITS_RAW" | grep -c '.' )"

control_defmodule="$( { grep -hE 'defmodule' "${FILES[@]}" 2>/dev/null || true; } | { grep -c '.' || true; } )"

allowlisted=0
HIT_RECORDS=""
if [ -n "$HITS_RAW" ]; then
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    h_path="${hit%%:*}"
    rest="${hit#*:}"
    h_line="${rest%%:*}"
    h_text="${rest#*:}"
    marked=""
    i=0
    while [ "$i" -lt "${#AL_PATHS[@]}" ]; do
      if [ "$h_path" = "${AL_PATHS[$i]}" ]; then
        case "$h_text" in
          *"${AL_LITERALS[$i]}"*) marked=" [ALLOWLISTED]" ;;
        esac
      fi
      i=$((i + 1))
    done
    [ -n "$marked" ] && allowlisted=$((allowlisted + 1))
    HIT_RECORDS="${HIT_RECORDS}${h_path}:${h_line}:${marked} ${h_text}
"
  done <<< "$HITS_RAW"
fi

hits_outside_allowlist=$((hits - allowlisted))

echo "tier=${TIER}"
echo "hits=${hits}"
echo "allowlisted=${allowlisted}"
echo "hits_outside_allowlist=${hits_outside_allowlist}"
echo "control_defmodule=${control_defmodule}"
echo "files_measured=${#FILES[@]}"
if [ -n "$HIT_RECORDS" ]; then
  printf '%s' "$HIT_RECORDS"
fi

if [ "${control_defmodule:-0}" -eq 0 ]; then
  echo "FAIL: control_defmodule=0 — refusing to report success on a surface where the paired positive control is dead (fail-closed guard)" >&2
  exit 3
fi

if [ "$hits_outside_allowlist" -ge 1 ]; then
  exit 1
fi

exit 0
