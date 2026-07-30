#!/usr/bin/env bash
# Phase 231 (GATE-03 / D-01, D-03, D-04): the honest-skip verdict.
#
# CONTRACT
# Given github.event_name, the docs-only classifier's output, and the nine
# ci-gate.needs lane results, decide whether every `skipped` lane was
# skipped because it was correctly gated for THIS event, or because its
# gate rotted. A rotted skip FAILS even though ci.yml:1831's own inline
# loop treats every skip as a pass -- closing that gap is the whole point
# of this script.
#
# SINGLE ENUMERATION (D-01)
# This script builds NO second list of legitimate skips: no hard-coded
# allowlist of ids and gates, no re-derivation of docs-only classification,
# no copy of MAINTAINING.md's prose. It reads .github/ci-skip-manifest.tsv,
# whose own header block assigns the enumeration to that file and the
# consequence to this script. The one fixed set here is the nine
# ci-gate.needs LANE IDS (ci.yml:1793-1802) -- that list exists only to
# know which manifest rows are in scope, and it is cross-checked at
# runtime against the workflow's own `needs:` block below, so a `needs:`
# edit that adds or drops a lane cannot silently widen or shrink what this
# script verdicts.
#
# WHAT THIS SCRIPT DOES NOT DO (yet)
# It is not wired into the `ci-gate` job by this plan -- that is plan
# 231-09, which also adds the `force_rot_probe` workflow_dispatch input
# and the live two-run SC-3 proof. This plan ships the logic and its
# hermetic self-test only (D-02).
#
# FAIL-CLOSED DOCTRINE
# Every unknown, empty, or unparseable state is a FAIL, never a pass by
# default: an unrecognized or empty --event, a manifest yielding fewer
# than five ci-gate.needs-intersecting rows, a workflow parse yielding
# zero `needs:` entries, and a fully empty lane-result map each exit
# non-zero before any per-lane verdict runs.
#
# Security: reads only two committed repository files (the manifest, the
# workflow) plus lane-result strings supplied as CLI flags or env vars. No
# network call anywhere, no invocation of the `gh` CLI, no secret. The
# future `ci-gate` step that invokes this script (plan 231-09) must map
# every GitHub context value through `env:`, never inline one into a
# `run:` body (ci.yml:132-135, notify-failure-issue.sh:14-18) -- this
# script's own CLI surface already follows that discipline by accepting
# every value as an explicit flag or env var rather than reading context
# expressions of its own.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MANIFEST="${ROOT}/.github/ci-skip-manifest.tsv"
WORKFLOW="${ROOT}/.github/workflows/ci.yml"
EVENT="${GITHUB_EVENT_NAME:-}"
DOCS_ONLY_RAW="${DOCS_ONLY:-}"
FORMAT="table"
FORCE_ROT_PROBE="${FORCE_ROT_PROBE:-}"
FROM_JSON=""
declare -a LANE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --event) EVENT="$2"; shift 2;;
    --docs-only) DOCS_ONLY_RAW="$2"; shift 2;;
    --lane) LANE_ARGS+=("$2"); shift 2;;
    --from-json) FROM_JSON="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --force-rot-probe) FORCE_ROT_PROBE="true"; shift 1;;
    *) echo "honest-skip-verdict: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "honest-skip-verdict: FAIL: $*" >&2
  exit 1
}

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

[[ -f "$MANIFEST" ]] || fail "manifest not found at ${MANIFEST}"
[[ -f "$WORKFLOW" ]] || fail "workflow not found at ${WORKFLOW}"

# Reject an empty or unrecognized --event rather than defaulting it -- an
# unknown event must never silently take the permissive (non-pull_request,
# empty-allow-set) branch. These four are ci.yml's only triggers (:3-22).
VALID_EVENTS=(pull_request push schedule workflow_dispatch)
EVENT_IS_VALID=false
for candidate in "${VALID_EVENTS[@]}"; do
  [[ "$EVENT" == "$candidate" ]] && EVENT_IS_VALID=true
done
[[ "$EVENT_IS_VALID" == true ]] || fail "unrecognized or empty --event '${EVENT:-<empty>}' (expected one of: ${VALID_EVENTS[*]}); refusing to default -- an unknown event must not silently take the permissive branch"

# ---------------------------------------------------------------------------
# The fixed nine-element ci-gate.needs lane list (ci.yml:1793-1802), written
# once here as the sole hard-coded set this script owns. `changes` supplies
# the docs_only input to the verdict and is deliberately excluded below: it
# is not itself a gated lane, so it need not appear in this list.
# ---------------------------------------------------------------------------
LANES=(
  install_golden_contract
  library_tests
  library_tests_dep_off
  install_smoke
  upgrade_smoke
  example_http_smoke
  example_playwright_smoke
  generated_admin_playwright_smoke
  fast_checks
)
INPUT_PROVIDER_EXCLUSION="changes"

# Extract the ci-gate job's declared `needs:` ids straight from the workflow
# text. Terminates the needs: block at the first line that is not a
# "      - id" entry, and terminates the whole job block at the next
# top-level (2-space-indented) mapping key.
extract_ci_gate_needs() {
  awk '
    /^  ci-gate:[[:space:]]*$/ { in_job=1; next }
    in_job && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { in_job=0 }
    in_job && /^    needs:[[:space:]]*$/ { in_needs=1; next }
    in_job && in_needs {
      if ($0 ~ /^      - [A-Za-z0-9_.-]+[[:space:]]*$/) {
        line=$0
        sub(/^      - /, "", line)
        gsub(/[[:space:]]+$/, "", line)
        print line
        next
      } else {
        in_needs=0
      }
    }
  ' "$WORKFLOW"
}

mapfile -t DECLARED_NEEDS < <(extract_ci_gate_needs)
if [[ "${#DECLARED_NEEDS[@]}" -eq 0 ]]; then
  fail "could not extract any ci-gate needs: entries from ${WORKFLOW} -- the parse broke, this is not a pass"
fi

for need in "${DECLARED_NEEDS[@]}"; do
  [[ "$need" == "$INPUT_PROVIDER_EXCLUSION" ]] && continue
  found=false
  for lane in "${LANES[@]}"; do
    [[ "$lane" == "$need" ]] && { found=true; break; }
  done
  [[ "$found" == true ]] || fail "ci-gate.needs declares '${need}' in ${WORKFLOW}, but this script's fixed lane list does not include it -- a needs: edit added a lane this verdict does not know how to check"
done

for lane in "${LANES[@]}"; do
  found=false
  for need in "${DECLARED_NEEDS[@]}"; do
    [[ "$need" == "$lane" ]] && { found=true; break; }
  done
  [[ "$found" == true ]] || fail "this script's fixed lane list includes '${lane}', but ci-gate.needs in ${WORKFLOW} does not declare it -- a needs: edit dropped a lane from the gate; the verdict's scope must shrink deliberately, not silently"
done

# ---------------------------------------------------------------------------
# Manifest lookup. Returns "1<TAB><gate>" when a row's id matches, so the
# caller can distinguish "row exists with an empty gate cell" from "no row
# at all" -- an empty print alone cannot make that distinction.
# ---------------------------------------------------------------------------
manifest_lookup() {
  local lane="$1"
  awk -F'\t' -v id="$lane" '
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    $1 == "tier" { next }
    $3 == id { print "1\t" $7; exit }
  ' "$MANIFEST"
}

# Non-vacuity (D-04): the manifest must yield at least five rows whose id
# intersects the nine-lane set. Five is the post-231-07/D-06 true count
# (upgrade_smoke, library_tests_dep_off, install_smoke, example_http_smoke,
# example_playwright_smoke) -- it was six before Phase 231 GATE-02 / D-06
# deleted the generated_admin_playwright_smoke row.
MANIFEST_HIT_COUNT=0
for lane in "${LANES[@]}"; do
  row="$(manifest_lookup "$lane")"
  [[ -n "$row" ]] && MANIFEST_HIT_COUNT=$((MANIFEST_HIT_COUNT + 1))
done
if [[ "$MANIFEST_HIT_COUNT" -lt 5 ]]; then
  fail "manifest ${MANIFEST} yielded only ${MANIFEST_HIT_COUNT} row(s) intersecting the nine ci-gate.needs lane ids (expected >= 5: upgrade_smoke, library_tests_dep_off, install_smoke, example_http_smoke, example_playwright_smoke) -- the parse broke, this is not a pass"
fi

# ---------------------------------------------------------------------------
# The rot check (step 3 of the spec): a gate cell that references the PR
# head branch, a literal branch path, or a commit SHA is rotted by
# construction, even for a lane whose skip was otherwise allowed. This is
# the same ROTTED set p10-no-undocumented-demotion.test.mjs enforces at
# lint time (Phase 231 GATE-02/GATE-03) -- the check that would have caught
# GATE-02's own defect.
# ---------------------------------------------------------------------------
is_rotted_gate() {
  local candidate="$1"
  printf '%s' "$candidate" | grep -qE 'github\.head_ref' && return 0
  printf '%s' "$candidate" | grep -qE '\bship/' && return 0
  printf '%s' "$candidate" | grep -qE '\b[0-9a-f]{7,40}\b' && return 0
  return 1
}

gate_mentions_honest_signal() {
  local candidate="$1"
  printf '%s' "$candidate" | grep -qE 'github\.event_name|docs_only'
}

# ---------------------------------------------------------------------------
# Build ALLOWED_SKIPS for this event, per D-03. On any event other than
# pull_request the set is EMPTY: the `changes` job emits `docs_only=false`
# unconditionally on every non-pull_request event (ci.yml:138-141), so no
# tier-C skip is reachable there.
# ---------------------------------------------------------------------------
declare -a ALLOWED=()
DOCS_ONLY_NORMALIZED="false"
if [[ "$EVENT" == "pull_request" ]]; then
  ALLOWED+=("upgrade_smoke")
  if [[ "$DOCS_ONLY_RAW" == "true" ]]; then
    DOCS_ONLY_NORMALIZED="true"
    ALLOWED+=("library_tests_dep_off")
  fi
fi

declare -a NOTES=()
NOTES+=("example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the verdict.")
if [[ "$EVENT" == "pull_request" && -z "$DOCS_ONLY_RAW" ]]; then
  NOTES+=("--docs-only (or DOCS_ONLY) was empty on a pull_request event -- the docs_only input never arrived. Treated as false.")
fi

# ---------------------------------------------------------------------------
# Payload acquisition: --lane <id>=<result> flags and/or --from-json, which
# reads the identical id-to-result map as a JSON object so the hermetic
# self-test needs no environment gymnastics.
# ---------------------------------------------------------------------------
declare -a ALL_LANE_ENTRIES=("${LANE_ARGS[@]}")
if [[ -n "$FROM_JSON" ]]; then
  [[ -f "$FROM_JSON" ]] || fail "--from-json payload not found at ${FROM_JSON}"
  jq -e 'type == "object"' "$FROM_JSON" >/dev/null 2>&1 \
    || fail "--from-json payload at ${FROM_JSON} is not a JSON object mapping lane id to result"
  while IFS= read -r line; do
    ALL_LANE_ENTRIES+=("$line")
  done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$FROM_JSON")
fi

lane_result_for() {
  local id="$1" result="" entry
  for entry in "${ALL_LANE_ENTRIES[@]}"; do
    if [[ "${entry%%=*}" == "$id" ]]; then
      result="${entry#*=}"
    fi
  done
  printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# The rot-probe seam. When active, force example_playwright_smoke -- a real
# ci-gate.needs lane never in the allow-set on any event -- to a skipped
# result carried by a synthetic branch-keyed gate string, so the verdict
# reds by construction and names that lane in its output. A total no-op
# when the flag is absent: no banner, no injected row, no verdict change.
# ---------------------------------------------------------------------------
PROBE_ACTIVE=false
[[ "$FORCE_ROT_PROBE" == "true" ]] && PROBE_ACTIVE=true
PROBE_LANE="example_playwright_smoke"
PROBE_GATE="github.head_ref == 'ship/rot-probe-synthetic'"
if [[ "$PROBE_ACTIVE" == true ]]; then
  echo "*** ROT PROBE ACTIVE (--force-rot-probe): forcing ${PROBE_LANE} to a skipped result carrying a synthetic rotted gate, self-test purposes only -- this run does not reflect real CI ***" >&2
  ALL_LANE_ENTRIES+=("${PROBE_LANE}=skipped")
fi

# Anti-vacuity, second form (step 4): at least one lane must carry a
# non-empty result. A fully empty result map is a broken needs: wiring or a
# renamed job -- it is never read as "nothing to check, so pass".
ANY_NONEMPTY_RESULT=false
for lane in "${LANES[@]}"; do
  [[ -n "$(lane_result_for "$lane")" ]] && ANY_NONEMPTY_RESULT=true
done
[[ "$ANY_NONEMPTY_RESULT" == true ]] || fail "every lane result is empty -- a fully empty result map is a broken needs: wiring or a renamed job and is never read as nothing-to-check-so-pass"

# ---------------------------------------------------------------------------
# Per-lane verdict (steps 2 and 3 of the spec).
# ---------------------------------------------------------------------------
VERDICTS_JSON="[]"
VERDICT_OVERALL="PASS"
declare -a FAIL_LINES=()

for lane in "${LANES[@]}"; do
  result="$(lane_result_for "$lane")"

  if [[ "$PROBE_ACTIVE" == true && "$lane" == "$PROBE_LANE" ]]; then
    manifest_row_exists=true
    manifest_gate="$PROBE_GATE"
  else
    row="$(manifest_lookup "$lane")"
    if [[ -n "$row" ]]; then
      manifest_row_exists=true
      manifest_gate="${row#*$'\t'}"
    else
      manifest_row_exists=false
      manifest_gate=""
    fi
  fi

  is_allowed=false
  for a in "${ALLOWED[@]}"; do
    [[ "$a" == "$lane" ]] && is_allowed=true
  done

  verdict=""
  reason=""

  if [[ "$result" == "skipped" ]]; then
    if [[ "$is_allowed" == false ]]; then
      verdict="FAIL"
      if [[ "$manifest_row_exists" == true ]]; then
        reason="lane '${lane}' skipped on event '${EVENT}', which is not in the legitimate-skip set for this event; manifest gate: \"${manifest_gate}\""
      else
        reason="lane '${lane}' skipped on event '${EVENT}', which is not in the legitimate-skip set for this event; no manifest row exists for it (a release_ref_guard-style cascade is a real coverage loss, not a special case)"
      fi
    elif [[ -z "$manifest_gate" ]]; then
      verdict="FAIL"
      reason="lane '${lane}' skipped and is in the allow-set for event '${EVENT}', but its manifest gate cell is empty or missing -- a legitimate skip must be backed by a real, inspectable gate"
    elif is_rotted_gate "$manifest_gate"; then
      verdict="FAIL"
      reason="lane '${lane}' skipped and was allowed to for event '${EVENT}', but its manifest gate \"${manifest_gate}\" is rotted (references a branch head, a branch path, or a literal commit SHA) -- a branch-keyed gate is empty on every non-pull_request event and stale the moment the branch merges"
    elif ! gate_mentions_honest_signal "$manifest_gate"; then
      verdict="FAIL"
      reason="lane '${lane}' skipped and was allowed to for event '${EVENT}', but its manifest gate \"${manifest_gate}\" mentions neither github.event_name nor docs_only -- cannot verify the skip is legitimately event- or diff-gated"
    else
      verdict="PASS"
      reason="skipped, legitimately gated for event '${EVENT}' (manifest gate: \"${manifest_gate}\")"
    fi
  elif [[ "$result" == "success" ]]; then
    verdict="PASS"
    reason="executed (success)"
  else
    verdict="FAIL"
    reason="result is '${result:-<empty>}', neither success nor skipped -- preserving ci.yml:1831's existing behaviour inside this script"
  fi

  [[ "$verdict" == "PASS" ]] || VERDICT_OVERALL="FAIL"
  [[ "$verdict" == "FAIL" ]] && FAIL_LINES+=("  FAIL ${lane}: ${reason}")

  VERDICTS_JSON="$(echo "$VERDICTS_JSON" | jq \
    --arg id "$lane" --arg result "$result" --arg verdict "$verdict" \
    --arg reason "$reason" --arg gate "$manifest_gate" \
    '. + [{id: $id, result: $result, verdict: $verdict, reason: $reason, manifest_gate: $gate}]')"
done

ALLOWED_JSON="$(printf '%s\n' "${ALLOWED[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')"
NOTES_JSON="$(printf '%s\n' "${NOTES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')"

case "$FORMAT" in
  json)
    jq -n \
      --arg event "$EVENT" --arg docs_only "$DOCS_ONLY_NORMALIZED" \
      --argjson allowed_skips "$ALLOWED_JSON" --argjson lanes "$VERDICTS_JSON" \
      --argjson notes "$NOTES_JSON" --arg verdict "$VERDICT_OVERALL" \
      '{event: $event, docs_only: $docs_only, allowed_skips: $allowed_skips,
        lanes: $lanes, notes: $notes, verdict: $verdict}'
    ;;
  table)
    printf 'Honest-skip verdict -- event: %s, docs_only: %s\n\n' "$EVENT" "$DOCS_ONLY_NORMALIZED"
    {
      printf 'lane\tresult\tverdict\n'
      echo "$VERDICTS_JSON" | jq -r '.[] | "\(.id)\t\(.result // "-")\t\(.verdict)"'
    } | column -t -s $'\t'
    echo
    for line in "${FAIL_LINES[@]}"; do
      echo "$line"
    done
    for note in "${NOTES[@]}"; do
      echo "  NOTE: ${note}"
    done
    if [[ "$VERDICT_OVERALL" == "PASS" ]]; then
      echo "  every skip (if any) on this lane set is legitimately gated for this event, and no allowed gate is rotted."
    fi
    ;;
esac

EXIT_CODE=0
[[ "$VERDICT_OVERALL" == "PASS" ]] || EXIT_CODE=1
exit "$EXIT_CODE"
