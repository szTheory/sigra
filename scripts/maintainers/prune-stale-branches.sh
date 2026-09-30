#!/usr/bin/env bash
# Phase 245 one-shot branch-prune operator.
# Report-only by default. Mutations require committed exact-name evidence and --apply.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_ROOT}/scripts/maintainers/repo-mutation-coordinator.sh"
DEFAULT_PHASE_DIR=".planning/phases/245-branch-prune-local-and-remote"
DEFAULT_SNAPSHOT="${DEFAULT_PHASE_DIR}/245-LOCAL-REFS.tsv"
DEFAULT_ORIGIN_SNAPSHOT="${DEFAULT_PHASE_DIR}/245-ORIGIN-REFS.tsv"
DEFAULT_ALLOWLIST="${DEFAULT_PHASE_DIR}/245-BRANCH-DELETE-ALLOWLIST.tsv"
DEFAULT_SAFETY_LIST="${DEFAULT_PHASE_DIR}/245-SAFETY-PUBLISH.tsv"
DEFAULT_READINESS="${DEFAULT_PHASE_DIR}/245-READINESS.json"
DEFAULT_PR_STATE="${DEFAULT_PHASE_DIR}/245-OPEN-PR-STATE.json"
DEFAULT_PREFLIGHT="${DEFAULT_PHASE_DIR}/245-ORIGIN-ACCESS-PREFLIGHT.json"
DEFAULT_ADMISSION="${DEFAULT_PHASE_DIR}/245-19-ADMISSION.json"
SNAPSHOT_HEADER=$'refname\toid\ttype\tpeeled_oid\tpeeled_type\tsymref_target'
ALLOWLIST_HEADER=$'side\tref\toid\ttype\treason'
ORIGIN_LIMIT=1000
GITHUB_REPOSITORY="szTheory/sigra"

PREFLIGHT_STAGE=""
PREFLIGHT_STATUS_FILE=""
fail() {
  if [[ -n "$PREFLIGHT_STATUS_FILE" && -n "$PREFLIGHT_STAGE" ]]; then
    printf '%s\tfailed\n' "$PREFLIGHT_STAGE" >> "$PREFLIGHT_STATUS_FILE"
    PREFLIGHT_STAGE=""
  fi
  printf 'prune-stale-branches: FAIL: %s\n' "$*" >&2
  exit 1
}
usage() {
  cat >&2 <<'USAGE'
usage: prune-stale-branches.sh <capture-local|capture-origin|capture-prs|capture-readiness|verify-readiness|verify-snapshot|verify-allowlist|preflight-origin-access|safety-publish|verify-safety|local|remote|tracking|verify-local|verify-remote|verify-objects|verify-prs> [options]

  capture-local   capture an unfiltered local refs TSV
  capture-origin  capture the live origin refs and symrefs
  capture-prs     capture the complete live open-PR head/base set
  capture-readiness evaluate and record committed Phase 244 D-01 source predicates
  verify-readiness validate the committed D-01 receipt and its pinned sources
  verify-snapshot verify a committed ref snapshot and its object identities
  verify-allowlist validate committed exact-name operation rows
  preflight-origin-access verify read/write access without mutating origin
  safety-publish  publish only committed absent safety refs
  verify-safety   compare required safety ref identities
  local           report or delete exact local branch rows
  remote          report or delete exact origin branch rows
  tracking        delete matching local origin-tracking refs by expected OID
  verify-local    compare local branch names with the committed keep set
  verify-remote   compare live origin branch names with the committed keep set
  verify-objects  prove every direct and peeled snapshot OID remains readable
  verify-prs      verify baseline open PR identities and current exclusions

Options:
  --repo PATH              repository to inspect (defaults to this checkout)
  --output PATH             capture destination for inventories, PR state, or preflight
  --snapshot-commit SHA     immutable commit containing the snapshot TSV
  --snapshot PATH           snapshot path (defaults to the Phase 245 artifact)
  --origin-commit SHA       immutable commit containing the origin inventory
  --origin-snapshot PATH    origin inventory path (defaults to the Phase 245 artifact)
  --allowlist-commit SHA    immutable commit containing operation rows
  --allowlist PATH          operation rows path (defaults to the Phase 245 artifact)
  --safety-commit SHA       immutable commit containing the safety publication list
  --safety-list PATH        safety publication rows (defaults to the Phase 245 artifact)
  --readiness-commit SHA    immutable commit containing the D-01 readiness receipt
  --readiness PATH          readiness path (defaults to 245-READINESS.json)
  --evidence-commit SHA     compatibility alias for --readiness-commit
  --evidence PATH           compatibility alias for --readiness
  --pr-state-commit SHA     immutable commit containing the PR baseline
  --pr-state PATH           PR baseline path (defaults to the Phase 245 artifact)
  --current-contract-commit SHA  immutable commit containing the D-07 current contract
  --current-contract PATH        current contract path within that commit
  --current-contract-fixture PATH disposable GitHub source fixture (read-only verify-prs only)
  --origin-snapshot-commit SHA  immutable commit containing the origin inventory
  --candidate-ref FULL_REF      exact local candidate selected for admission
  --admission PATH               initial admission receipt pinned by the current contract
  --preflight-commit SHA    immutable commit containing an access preflight receipt
  --preflight PATH          preflight receipt path (defaults to the Phase 245 artifact)
  --identity-audit PATH     committed Phase 245 historical PR identity audit
  --integrity-output PATH   fresh verify-prs result destination
  --operation publish|delete exact origin access operation
  --ref FULL_REF            exact ref for preflight-origin-access
  --apply                   mutate the exact local rows (reporting is the default)
USAGE
  exit 2
}

safe_repo_path() {
  local value="$1"
  [[ -n "$value" && "$value" != /* && "$value" != *$'\n'* && "$value" != *:* ]] \
    || fail "unsafe_repository_path: $value"
  [[ "/$value/" != *"/../"* && "/$value/" != *"//"* ]] \
    || fail "unsafe_repository_path: $value"
}

[[ $# -gt 0 ]] || usage
COMMAND="$1"; shift
REPO="$SCRIPT_ROOT"
OUTPUT=""
SNAPSHOT_COMMIT=""
SNAPSHOT_PATH="$DEFAULT_SNAPSHOT"
ORIGIN_COMMIT=""
ORIGIN_PATH="$DEFAULT_ORIGIN_SNAPSHOT"
ALLOWLIST_COMMIT=""
ALLOWLIST_PATH="$DEFAULT_ALLOWLIST"
SAFETY_COMMIT=""
SAFETY_PATH="$DEFAULT_SAFETY_LIST"
READINESS_COMMIT=""
READINESS_PATH="$DEFAULT_READINESS"
PR_STATE_COMMIT=""
PR_STATE_PATH="$DEFAULT_PR_STATE"
IDENTITY_AUDIT=""
INTEGRITY_OUTPUT=""
CURRENT_CONTRACT_COMMIT=""
CURRENT_CONTRACT_PATH=""
CURRENT_CONTRACT_FIXTURE=""
ORIGIN_SNAPSHOT_COMMIT=""
CANDIDATE_REF=""
ADMISSION_PATH="$DEFAULT_ADMISSION"
PREFLIGHT_COMMIT=""
PREFLIGHT_PATH="$DEFAULT_PREFLIGHT"
OPERATION=""
REF=""
APPLY=0

while (($#)); do
  case "$1" in
    --repo) (($# >= 2)) || fail 'repo_flag_missing_value'; REPO="$2"; shift 2 ;;
    --output) (($# >= 2)) || fail 'output_flag_missing_value'; OUTPUT="$2"; shift 2 ;;
    --snapshot-commit) (($# >= 2)) || fail 'snapshot_commit_flag_missing_value'; SNAPSHOT_COMMIT="$2"; shift 2 ;;
    --snapshot) (($# >= 2)) || fail 'snapshot_flag_missing_value'; SNAPSHOT_PATH="$2"; shift 2 ;;
    --origin-commit) (($# >= 2)) || fail 'origin_commit_flag_missing_value'; ORIGIN_COMMIT="$2"; shift 2 ;;
    --origin-snapshot) (($# >= 2)) || fail 'origin_snapshot_flag_missing_value'; ORIGIN_PATH="$2"; shift 2 ;;
    --allowlist-commit) (($# >= 2)) || fail 'allowlist_commit_flag_missing_value'; ALLOWLIST_COMMIT="$2"; shift 2 ;;
    --allowlist) (($# >= 2)) || fail 'allowlist_flag_missing_value'; ALLOWLIST_PATH="$2"; shift 2 ;;
    --safety-commit) (($# >= 2)) || fail 'safety_commit_flag_missing_value'; SAFETY_COMMIT="$2"; shift 2 ;;
    --safety-list) (($# >= 2)) || fail 'safety_list_flag_missing_value'; SAFETY_PATH="$2"; shift 2 ;;
    --readiness-commit) (($# >= 2)) || fail 'readiness_commit_flag_missing_value'; READINESS_COMMIT="$2"; shift 2 ;;
    --readiness) (($# >= 2)) || fail 'readiness_flag_missing_value'; READINESS_PATH="$2"; shift 2 ;;
    --evidence-commit) (($# >= 2)) || fail 'evidence_commit_flag_missing_value'; READINESS_COMMIT="$2"; shift 2 ;;
    --evidence) (($# >= 2)) || fail 'evidence_flag_missing_value'; READINESS_PATH="$2"; shift 2 ;;
    --pr-state-commit) (($# >= 2)) || fail 'pr_state_commit_flag_missing_value'; PR_STATE_COMMIT="$2"; shift 2 ;;
    --pr-state) (($# >= 2)) || fail 'pr_state_flag_missing_value'; PR_STATE_PATH="$2"; shift 2 ;;
    --identity-audit) (($# >= 2)) || fail 'identity_audit_flag_missing_value'; IDENTITY_AUDIT="$2"; shift 2 ;;
    --integrity-output) (($# >= 2)) || fail 'integrity_output_flag_missing_value'; INTEGRITY_OUTPUT="$2"; shift 2 ;;
    --current-contract-commit) (($# >= 2)) || fail 'current_contract_commit_flag_missing_value'; CURRENT_CONTRACT_COMMIT="$2"; shift 2 ;;
    --current-contract) (($# >= 2)) || fail 'current_contract_flag_missing_value'; CURRENT_CONTRACT_PATH="$2"; shift 2 ;;
    --current-contract-fixture) (($# >= 2)) || fail 'current_contract_fixture_flag_missing_value'; CURRENT_CONTRACT_FIXTURE="$2"; shift 2 ;;
    --origin-snapshot-commit) (($# >= 2)) || fail 'origin_snapshot_commit_flag_missing_value'; ORIGIN_SNAPSHOT_COMMIT="$2"; shift 2 ;;
    --candidate-ref) (($# >= 2)) || fail 'candidate_ref_flag_missing_value'; CANDIDATE_REF="$2"; shift 2 ;;
    --admission) (($# >= 2)) || fail 'admission_flag_missing_value'; ADMISSION_PATH="$2"; shift 2 ;;
    --preflight-commit) (($# >= 2)) || fail 'preflight_commit_flag_missing_value'; PREFLIGHT_COMMIT="$2"; shift 2 ;;
    --preflight) (($# >= 2)) || fail 'preflight_flag_missing_value'; PREFLIGHT_PATH="$2"; shift 2 ;;
    --operation) (($# >= 2)) || fail 'operation_flag_missing_value'; OPERATION="$2"; shift 2 ;;
    --ref) (($# >= 2)) || fail 'ref_flag_missing_value'; REF="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage ;;
    *) fail "unknown_argument: $1" ;;
  esac
done

CURRENT_CONTRACT_MODE=0
if [[ -n "$CURRENT_CONTRACT_COMMIT" || -n "$CURRENT_CONTRACT_PATH" ]]; then
  CURRENT_CONTRACT_MODE=1
  [[ -n "$CURRENT_CONTRACT_COMMIT" ]] || fail 'current_contract_commit_required'
  [[ -n "$CURRENT_CONTRACT_PATH" ]] || fail 'current_contract_path_required'
  safe_repo_path "$CURRENT_CONTRACT_PATH"
  case "$COMMAND" in
    verify-prs|verify-allowlist|local|remote|tracking|safety-publish) ;;
    *) fail "current_contract_not_supported_for_${COMMAND}" ;;
  esac
  if [[ -n "$CURRENT_CONTRACT_FIXTURE" ]]; then
    (( APPLY == 0 )) || fail 'current_contract_fixture_forbidden_for_apply'
    [[ "$COMMAND" == verify-prs || "$COMMAND" == verify-allowlist ]] || fail 'current_contract_fixture_read_only_verify_only'
    safe_repo_path "$CURRENT_CONTRACT_FIXTURE"
  fi
elif [[ -n "$CURRENT_CONTRACT_FIXTURE" ]]; then
  fail 'current_contract_fixture_requires_current_contract'
fi
if (( CURRENT_CONTRACT_MODE )) && [[ -n "$PR_STATE_COMMIT" || -n "$IDENTITY_AUDIT" || -n "$INTEGRITY_OUTPUT" ]]; then
  fail 'current_contract_historical_flags_mixed'
fi
if (( CURRENT_CONTRACT_MODE && APPLY )) && [[ "$COMMAND" == local ]]; then
  [[ -n "$SNAPSHOT_COMMIT" && -n "$ORIGIN_SNAPSHOT_COMMIT" && -n "$ALLOWLIST_COMMIT" \
    && -n "$READINESS_COMMIT" && -n "$CANDIDATE_REF" && -n "$ADMISSION_PATH" ]] || fail 'local_admission_committed_inputs_required'
  safe_repo_path "$SNAPSHOT_PATH"
  safe_repo_path "$ORIGIN_PATH"
  safe_repo_path "$ALLOWLIST_PATH"
  safe_repo_path "$READINESS_PATH"
  safe_repo_path "$ADMISSION_PATH"
fi

sigra_coordinator_pin_git || fail "git_runtime_unpinned: ${SIGRA_COORDINATOR_ERROR:-unknown}"
command -v awk >/dev/null 2>&1 || fail 'awk_not_on_path'
command -v jq >/dev/null 2>&1 || fail 'jq_not_on_path'
git -C "$REPO" rev-parse --show-toplevel >/dev/null 2>&1 || fail "not_a_git_repository: $REPO"
REPO="$(git -C "$REPO" rev-parse --show-toplevel)"

valid_oid() { [[ "$1" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; }
valid_type() { [[ "$1" == commit || "$1" == tree || "$1" == blob || "$1" == tag ]]; }

require_commit() {
  local commit="$1" label="$2"
  valid_oid "$commit" || fail "${label}_commit_invalid_oid"
  git -C "$REPO" cat-file -e "${commit}^{commit}" 2>/dev/null \
    || fail "${label}_commit_unreadable: $commit"
}

read_committed_file() {
  local commit="$1" path="$2" destination="$3" label="$4"
  safe_repo_path "$path"
  require_commit "$commit" "$label"
  git -C "$REPO" show "${commit}:${path}" > "$destination" 2>/dev/null \
    || fail "${label}_not_in_committed_revision: ${commit}:${path}"
}

verify_current_contract() {
  local stage="$1" side="${2:-}" ref="${3:-}" operation="${4:-}"
  local allowlist_commit="$ALLOWLIST_COMMIT" allowlist_path="$ALLOWLIST_PATH"
  (( CURRENT_CONTRACT_MODE )) || return 0
  if [[ "$COMMAND" == safety-publish ]]; then
    allowlist_commit="${SAFETY_COMMIT:-$ALLOWLIST_COMMIT}"
    allowlist_path="$SAFETY_PATH"
  fi
  local args=(verify --repo "$REPO" --contract-commit "$CURRENT_CONTRACT_COMMIT" \
    --contract "$CURRENT_CONTRACT_PATH" --stage "$stage")
  if [[ -n "$allowlist_commit" || "$allowlist_path" != "$DEFAULT_ALLOWLIST" ]]; then
    [[ -n "$allowlist_commit" ]] || fail 'current_allowlist_commit_required'
    args+=(--allowlist-commit "$allowlist_commit" --allowlist "$allowlist_path")
  elif [[ "$COMMAND" != verify-prs ]]; then
    fail 'current_allowlist_commit_path_required'
  fi
  if [[ -n "$side" || -n "$ref" || -n "$operation" ]]; then
    [[ -n "$side" && -n "$ref" && -n "$operation" ]] || fail 'current_operation_identity_incomplete'
    args+=(--operation-side "$side" --operation-ref "$ref" --operation-kind "$operation")
  fi
  if [[ -n "$CURRENT_CONTRACT_FIXTURE" ]]; then args+=(--source-fixture "$CURRENT_CONTRACT_FIXTURE"); fi
  node "$SCRIPT_ROOT/scripts/maintainers/prune-stale-branches-current.mjs" "${args[@]}" \
    || fail "current_pr_ref_contract_blocked:${stage}:${side:-none}:${ref:-none}"
}

verify_local_admission() {
  local stage="$1" candidate="${2:-$CANDIDATE_REF}" output status=0 first_reason
  local args=(verify --repo "$REPO" --stage "$stage"
    --current-contract-commit "$CURRENT_CONTRACT_COMMIT" --current-contract "$CURRENT_CONTRACT_PATH"
    --snapshot-commit "$SNAPSHOT_COMMIT" --snapshot "$SNAPSHOT_PATH"
    --origin-snapshot-commit "$ORIGIN_SNAPSHOT_COMMIT" --origin-snapshot "$ORIGIN_PATH"
    --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH"
    --readiness-commit "$READINESS_COMMIT" --readiness "$READINESS_PATH"
    --admission "$ADMISSION_PATH"
    --candidate-ref "$candidate")
  [[ -z "$CURRENT_CONTRACT_FIXTURE" ]] || args+=(--source-fixture "$CURRENT_CONTRACT_FIXTURE")
  output="$(node "$SCRIPT_ROOT/scripts/maintainers/prune-stale-branches-admission.mjs" "${args[@]}" 2>&1)" || status=$?
  if (( status != 0 )); then
    first_reason="$(jq -r '.blocked_reasons[0].code // empty' <<< "$output" 2>/dev/null || true)"
    [[ -n "$first_reason" ]] || first_reason="$(sed -n 's/^prune-stale-branches-admission: FAIL: //p' <<< "$output" | head -1)"
    fail "local_admission_blocked:${first_reason:-unknown}"
  fi
}

validate_snapshot_file() {
  local file="$1" verify_objects="${2:-yes}"
  [[ -s "$file" ]] || fail 'snapshot_empty_or_missing'
  local header
  IFS= read -r header < "$file" || fail 'snapshot_header_missing'
  [[ "$header" == "$SNAPSHOT_HEADER" ]] || fail 'snapshot_header_wrong'
  awk -F '\t' 'NR > 1 && NF != 6 { exit 1 } END { if (NR < 2) exit 1 }' "$file" \
    || fail 'snapshot_malformed_or_zero_rows'

  awk -F '\t' 'NR > 1 { if (seen[$1]++) exit 1 }' "$file" || fail 'snapshot_duplicate_ref'
  local line ref oid type peeled_oid peeled_type symref_target actual_type
  while IFS= read -r line; do
    [[ -n "$line" ]] || fail 'snapshot_blank_row'
    IFS=$'\t' read -r ref oid type peeled_oid peeled_type symref_target <<< "$line"
    if [[ "$ref" != refs/* ]] || ! git check-ref-format "$ref" >/dev/null 2>&1; then
      fail "snapshot_ref_invalid: $ref"
    fi
    valid_oid "$oid" || fail "snapshot_oid_invalid: $ref"
    valid_type "$type" || fail "snapshot_type_invalid: $ref:$type"
    if [[ "$peeled_oid" == '-' && "$peeled_type" != '-' ]] || [[ "$peeled_oid" != '-' && "$peeled_type" == '-' ]]; then
      fail "snapshot_peeled_identity_incomplete: $ref"
    fi
    if [[ "$peeled_oid" != '-' ]]; then
      valid_oid "$peeled_oid" || fail "snapshot_peeled_oid_invalid: $ref"
      valid_type "$peeled_type" || fail "snapshot_peeled_type_invalid: $ref:$peeled_type"
    fi
    if [[ "$symref_target" != '-' ]]; then
      if [[ "$symref_target" != refs/* ]] || ! git check-ref-format "$symref_target" >/dev/null 2>&1; then
        fail "snapshot_symref_target_invalid: $ref"
      fi
    fi
    if [[ "$verify_objects" == yes ]]; then
      git -C "$REPO" cat-file -e "${oid}^{object}" 2>/dev/null \
        || fail "snapshot_object_missing: $ref:$oid"
      actual_type="$(git -C "$REPO" cat-file -t "$oid" 2>/dev/null)" \
        || fail "snapshot_object_type_unreadable: $ref:$oid"
      [[ "$actual_type" == "$type" ]] || fail "snapshot_object_type_mismatch: $ref expected=$type actual=$actual_type"
      if [[ "$peeled_oid" != '-' ]]; then
        git -C "$REPO" cat-file -e "${peeled_oid}^{object}" 2>/dev/null \
          || fail "snapshot_peeled_object_missing: $ref:$peeled_oid"
        actual_type="$(git -C "$REPO" cat-file -t "$peeled_oid" 2>/dev/null)" \
          || fail "snapshot_peeled_object_type_unreadable: $ref:$peeled_oid"
        [[ "$actual_type" == "$peeled_type" ]] \
          || fail "snapshot_peeled_object_type_mismatch: $ref expected=$peeled_type actual=$actual_type"
      fi
    fi
  done < <(tail -n +2 "$file")
  printf '%s\n' "$(($(wc -l < "$file") - 1))"
}

validate_allowlist_file() {
  local file="$1" required_side="${2:-any}"
  [[ -s "$file" ]] || fail 'allowlist_empty_or_missing'
  local header
  IFS= read -r header < "$file" || fail 'allowlist_header_missing'
  [[ "$header" == "$ALLOWLIST_HEADER" ]] || fail 'allowlist_header_wrong'
  awk -F '\t' -v empty_ok="$required_side" 'NR > 1 && NF != 5 { exit 1 } END { if (NR < 2 && empty_ok != "safety-publish") exit 1 }' "$file" \
    || fail 'allowlist_malformed_or_zero_rows'

  awk -F '\t' 'NR > 1 { key=$1 "\t" $2; if (seen[key]++) exit 1 }' "$file" || fail 'allowlist_duplicate_ref'
  local line side ref oid type reason
  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || fail 'allowlist_blank_row'
    IFS=$'\t' read -r side ref oid type reason <<< "$line"
    [[ "$side" == local || "$side" == remote || "$side" == tracking || "$side" == safety-publish ]] \
      || fail "allowlist_side_invalid: $side"
    [[ "$required_side" == any || "$side" == "$required_side" ]] || continue
    local ref_namespace_valid=0
    case "$side" in
      local|remote) [[ "$ref" == refs/heads/* ]] && ref_namespace_valid=1 ;;
      tracking)
        [[ "$ref" == refs/remotes/origin/* ]] && ref_namespace_valid=1
        [[ "$ref" != refs/remotes/origin/HEAD ]] || fail 'tracking_origin_head_alias_not_allowed'
        ;;
      safety-publish) [[ "$ref" == refs/heads/* || "$ref" == refs/tags/* ]] && ref_namespace_valid=1 ;;
    esac
    if (( ! ref_namespace_valid )) || ! git check-ref-format "$ref" >/dev/null 2>&1; then
      fail "allowlist_ref_invalid: $ref"
    fi
    valid_oid "$oid" || fail "allowlist_oid_invalid: $ref"
    valid_type "$type" || fail "allowlist_type_invalid: $ref:$type"
    [[ -n "$reason" && "$reason" != *$'\r'* ]] || fail "allowlist_reason_empty_or_invalid: $ref"
    count=$((count + 1))
  done < <(tail -n +2 "$file")
  [[ "$count" -gt 0 || "$required_side" == safety-publish ]] || fail "allowlist_no_${required_side}_rows"
  printf '%s\n' "$count"
}

verify_readiness() {
  local commit="${READINESS_COMMIT:-$ALLOWLIST_COMMIT}" file="$1" out
  [[ -n "$commit" ]] || fail 'readiness_commit_required'
  safe_repo_path "$READINESS_PATH"
  read_committed_file "$commit" "$READINESS_PATH" "$file" readiness
  if ! out="$(node "$SCRIPT_ROOT/scripts/maintainers/prune-stale-branches-readiness.mjs" verify \
    --repo "$REPO" --artifact "$file" --artifact-commit "$commit" 2>&1)"; then
    printf '%s\n' "$out" >&2
    fail 'd01_readiness_missing_stale_dirty_or_unresolved'
  fi
}

capture_readiness() {
  safe_repo_path "$READINESS_PATH"
  node "$SCRIPT_ROOT/scripts/maintainers/prune-stale-branches-readiness.mjs" capture \
    --repo "$REPO" --output "$READINESS_PATH"
}

load_snapshot() {
  [[ -n "$SNAPSHOT_COMMIT" ]] || fail 'snapshot_commit_required'
  safe_repo_path "$SNAPSHOT_PATH"
  read_committed_file "$SNAPSHOT_COMMIT" "$SNAPSHOT_PATH" "$TMP_DIR/snapshot.tsv" snapshot
  SNAPSHOT_ROWS="$(validate_snapshot_file "$TMP_DIR/snapshot.tsv" yes)"
}

load_allowlist() {
  [[ -n "$ALLOWLIST_COMMIT" ]] || fail 'allowlist_commit_required'
  safe_repo_path "$ALLOWLIST_PATH"
  read_committed_file "$ALLOWLIST_COMMIT" "$ALLOWLIST_PATH" "$TMP_DIR/allowlist.tsv" allowlist
}

load_safety_list() {
  local commit="${SAFETY_COMMIT:-$SNAPSHOT_COMMIT}"
  [[ -n "$commit" ]] || fail 'safety_list_commit_required'
  safe_repo_path "$SAFETY_PATH"
  read_committed_file "$commit" "$SAFETY_PATH" "$TMP_DIR/safety-list.tsv" safety_list
}

snapshot_identity_for_ref() {
  awk -F '\t' -v wanted="$1" 'NR > 1 && $1 == wanted { print $2 "\t" $3; found=1; exit } END { if (!found) exit 1 }' "$TMP_DIR/snapshot.tsv"
}

normalize_branch_ref() {
  case "$1" in
    refs/heads/*) printf '%s\n' "$1" ;;
    refs/remotes/origin/*) printf 'refs/heads/%s\n' "${1#refs/remotes/origin/}" ;;
    *) return 1 ;;
  esac
}

captured_default_branch() {
  local target
  target="$(awk -F '\t' 'NR > 1 && $1 == "refs/remotes/origin/HEAD" { print $6; found=1 } END { if (!found) exit 1 }' "$TMP_DIR/snapshot.tsv")" \
    || fail 'snapshot_origin_default_symref_missing'
  [[ -n "$target" && "$target" != '-' ]] || fail 'snapshot_origin_default_symref_missing'
  normalize_branch_ref "$target" || fail "snapshot_origin_default_symref_malformed: $target"
}

live_default_branch() {
  local output="$TMP_DIR/live-default-head.txt" line target='' head_oid='' rows=0 symrefs=0 heads=0
  git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false ls-remote --symref origin HEAD > "$output" 2>/dev/null \
    || fail 'live_origin_default_query_failed'
  while IFS= read -r line; do
    rows=$((rows + 1))
    if [[ "$line" == ref:*$'\t'HEAD ]]; then
      symrefs=$((symrefs + 1))
      target="${line#ref: }"
      target="${target%$'\t'HEAD}"
    elif [[ "$line" == *$'\t'HEAD ]]; then
      heads=$((heads + 1))
      head_oid="${line%%$'\t'*}"
    else
      fail 'live_origin_default_query_malformed'
    fi
  done < "$output"
  [[ "$rows" -eq 2 && "$symrefs" -eq 1 && "$heads" -eq 1 ]] || fail 'live_origin_default_query_ambiguous_or_absent'
  [[ "$target" == refs/heads/* ]] || fail 'live_origin_default_target_invalid'
  git check-ref-format "$target" >/dev/null 2>&1 || fail 'live_origin_default_target_invalid'
  valid_oid "$head_oid" || fail 'live_origin_default_oid_invalid'
  printf '%s\n' "$target"
}

assert_deletion_ref_protected() {
  local ref="$1" normalized="$1" captured live
  [[ "$ref" == refs/remotes/origin/* ]] && normalized="refs/heads/${ref#refs/remotes/origin/}"
  if (( CURRENT_CONTRACT_MODE == 0 )); then
    captured="$(captured_default_branch)"
    [[ "$normalized" != "$captured" ]] || fail "protected_snapshot_default_branch: $normalized"
  fi
  is_safety_ref "$normalized" && fail "protected_safety_ref: $normalized"
  live="$(live_default_branch)"
  [[ "$normalized" != "$live" ]] || fail "protected_live_default_branch: $normalized"
}

current_branches_file() {
  local file="$1"
  git -C "$REPO" for-each-ref --format='%(refname)%09%(objectname)%09%(objecttype)' refs/heads/ > "$file" \
    || fail 'local_branch_enumeration_failed'
  [[ -s "$file" ]] || fail 'local_branch_enumeration_empty'
  awk -F '\t' 'NF != 3 || $1 !~ /^refs\/heads\// { exit 1 } END { if (NR < 1) exit 1 }' "$file" \
    || fail 'local_branch_enumeration_malformed'
}

current_local_refs_file() {
  local file="$1" raw="$TMP_DIR/current-all-refs.raw" validation="$TMP_DIR/current-all-refs.validation.tsv"
  git -C "$REPO" for-each-ref \
    --format='%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)%09%(symref)' refs/ > "$raw" \
    || fail 'local_ref_enumeration_failed'
  [[ -s "$raw" ]] || fail 'local_ref_enumeration_empty'
  awk -F '\t' 'BEGIN { OFS="\t" } { if (NF < 6) $6=""; for (i=1; i<=6; i++) if ($i == "") $i="-"; print $1,$2,$3,$4,$5,$6 }' "$raw" > "$file"
  printf '%s\n' "$SNAPSHOT_HEADER" > "$validation"
  cat "$file" >> "$validation"
  validate_snapshot_file "$validation" yes >/dev/null
}

worktree_has_branch() {
  local wanted="$1"
  git -C "$REPO" worktree list --porcelain | awk -v wanted="$wanted" '$1 == "branch" && $2 == wanted { found=1 } END { exit !found }'
}

preflight_local_rows() {
  local file="$1" side ref oid type reason current_line current_oid current_type merge_target merge_oid worktrees
  local found=0
  current_branches_file "$TMP_DIR/current-branches.tsv"
  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == local ]] || continue
    found=$((found + 1))
    current_line="$(awk -F '\t' -v wanted="$ref" '$1 == wanted { print $2 "\t" $3; exit }' "$TMP_DIR/current-branches.tsv")"
    if [[ -z "$current_line" ]]; then
      printf 'absent\t%s\n' "$ref" >> "$TMP_DIR/operation.tsv"
      continue
    fi
    IFS=$'\t' read -r current_oid current_type <<< "$current_line"
    [[ "$current_oid" == "$oid" && "$current_type" == "$type" ]] \
      || fail "local_ref_identity_conflict: $ref expected=${oid}/${type} actual=${current_oid}/${current_type}"
    worktree_has_branch "$ref" && fail "local_ref_checked_out_in_worktree: $ref"
    merge_target="$(git -C "$REPO" symbolic-ref -q HEAD 2>/dev/null)" || fail 'local_merge_target_symbolic_ref_missing'
    [[ "$merge_target" == refs/heads/* ]] || fail 'local_merge_target_ref_invalid'
    merge_oid="$(git -C "$REPO" rev-parse --verify HEAD 2>/dev/null)" || fail 'local_merge_target_oid_missing'
    git -C "$REPO" merge-base --is-ancestor "$oid" "$merge_oid" 2>/dev/null \
      || fail "local_ref_unmerged: $ref"
    worktrees="$(git -C "$REPO" worktree list --porcelain | awk '$1 == "branch" { print $2 }' | sort | tr '\n' ',')"
    printf 'present\t%s\t%s\t%s\t%s\n' "$ref" "$merge_target" "$merge_oid" "$worktrees" >> "$TMP_DIR/operation.tsv"
  done < <(tail -n +2 "$file")
  [[ "$found" -gt 0 ]] || fail 'allowlist_no_local_rows'
}

run_local_pass() {
  local count side ref oid type reason current_state deleted=0 absent=0 would=0 out
  load_snapshot
  load_allowlist
  load_safety_list
  validate_allowlist_file "$TMP_DIR/safety-list.tsv" safety-publish >/dev/null
  count="$(validate_allowlist_file "$TMP_DIR/allowlist.tsv" local)"
  : > "$TMP_DIR/operation.tsv"
  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == local ]] || continue
    local snapshot_identity
    snapshot_identity="$(snapshot_identity_for_ref "$ref")" || fail "allowlist_ref_not_in_snapshot: $ref"
    [[ "$snapshot_identity" == "$oid"$'\t'"$type" ]] \
      || fail "allowlist_snapshot_identity_mismatch: $ref"
  done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
  preflight_local_rows "$TMP_DIR/allowlist.tsv"

  if (( APPLY )); then
    local readiness_commit="${READINESS_COMMIT:-$ALLOWLIST_COMMIT}"
    [[ -n "$readiness_commit" ]] || fail 'd01_readiness_commit_required'
    verify_readiness "$TMP_DIR/readiness.json"
    if (( CURRENT_CONTRACT_MODE == 0 )); then
      [[ -n "$PR_STATE_COMMIT" ]] || fail 'pr_state_commit_required'
      load_pr_state
      assert_pr_baseline_unchanged
      while IFS=$'\t' read -r side ref _oid _type _reason; do
        [[ "$side" == local ]] || continue
        assert_pr_ref_unprotected "$ref"
      done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
    fi
  else
    printf 'prune-stale-branches: REPORTING ONLY — no ref will be touched (pass --apply to mutate)\n'
  fi
  printf 'prune-stale-branches: pass=local apply=%s rows=%s snapshot_commit=%s allowlist_commit=%s\n' \
    "$APPLY" "$count" "$SNAPSHOT_COMMIT" "$ALLOWLIST_COMMIT"

  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == local ]] || continue
    current_state="$(awk -F '\t' -v wanted="$ref" '$2 == wanted { print $1; exit }' "$TMP_DIR/operation.tsv")"
    if [[ "$current_state" == absent ]]; then
      printf 'absent  local ref %s (already absent; no mutation)\n' "$ref"
      absent=$((absent + 1))
      continue
    fi
    if (( ! APPLY )); then
      printf 'would delete local ref %s (%s)\n' "$ref" "$reason"
      would=$((would + 1))
      continue
    fi
    local preflight_row expected_target expected_target_oid expected_worktrees observed_worktrees
    preflight_row="$(awk -F '\t' -v wanted="$ref" '$1 == "present" && $2 == wanted { print $3 "\t" $4 "\t" $5; exit }' "$TMP_DIR/operation.tsv")"
    IFS=$'\t' read -r expected_target expected_target_oid expected_worktrees <<< "$preflight_row"
    [[ "$(git -C "$REPO" rev-parse --verify "$ref" 2>/dev/null || true)" == "$oid" ]] \
      || fail "local_ref_identity_changed_before_delete: $ref"
    [[ "$(git -C "$REPO" symbolic-ref -q HEAD 2>/dev/null || true)" == "$expected_target" \
      && "$(git -C "$REPO" rev-parse --verify HEAD 2>/dev/null || true)" == "$expected_target_oid" ]] \
      || fail "local_merge_target_changed_before_delete: $ref"
    git -C "$REPO" merge-base --is-ancestor "$oid" "$expected_target_oid" 2>/dev/null \
      || fail "local_ref_no_longer_merged: $ref"
    observed_worktrees="$(git -C "$REPO" worktree list --porcelain | awk '$1 == "branch" { print $2 }' | sort | tr '\n' ',')"
    [[ "$observed_worktrees" == "$expected_worktrees" ]] || fail "local_worktree_set_changed_before_delete: $ref"
    verify_current_contract boundary local "$ref" delete
    if (( CURRENT_CONTRACT_MODE )); then verify_local_admission boundary "$ref"; fi
    assert_deletion_ref_protected "$ref"
    [[ "${SIGRA_COORDINATOR_HELD:-0}" == 1 && -n "${SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN:-}" ]] \
      || fail 'shared_coordinator_lock_not_held_at_local_delete'
    if ! git -C "$REPO" update-ref --no-deref -d "$ref" "$oid" \
      2>"$TMP_DIR/local-delete.stderr" </dev/null; then
      fail "local_expected_oid_delete_failed: $ref"
    fi
    verify_current_contract after local "$ref" delete
    printf 'deleted local ref %s (%s)\n' "$ref" "$reason"
    deleted=$((deleted + 1))
  done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
  printf 'prune-stale-branches: local pass done — deleted=%s absent=%s would_delete=%s\n' "$deleted" "$absent" "$would"
}

verify_local_set() {
  local ref oid type peeled_oid peeled_type symref expected_file="$TMP_DIR/expected-local-refs.tsv" actual_file="$TMP_DIR/actual-local-refs.tsv"
  load_snapshot
  load_allowlist
  load_safety_list
  validate_allowlist_file "$TMP_DIR/allowlist.tsv" any >/dev/null
  : > "$expected_file"
  current_local_refs_file "$TMP_DIR/current-all-refs.tsv"
  local current_branch current_identity current_branch_oid is_deleted is_tracking tracking_state tracking_ref
  current_branch="$(git -C "$REPO" symbolic-ref -q HEAD 2>/dev/null || true)"
  while IFS=$'\t' read -r ref oid type peeled_oid peeled_type symref; do
    is_deleted="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == "local" && $2 == wanted { print "yes"; exit }' "$TMP_DIR/allowlist.tsv")"
    [[ "$is_deleted" == yes ]] && continue
    is_tracking="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == "tracking" && $2 == wanted { print "yes"; exit }' "$TMP_DIR/allowlist.tsv")"
    if [[ "$is_tracking" == yes ]]; then
      tracking_state="$(awk -F '\t' -v wanted="$ref" '$1 == wanted { print $2; exit }' "$TMP_DIR/current-all-refs.tsv")"
      [[ -n "$tracking_state" ]] || continue
    fi
    if [[ "$ref" == "$current_branch" ]]; then
      current_identity="$(awk -F '\t' -v wanted="$ref" '$1 == wanted { print $0; exit }' "$TMP_DIR/current-all-refs.tsv")"
      [[ -n "$current_identity" ]] || fail "current_branch_ref_missing: $ref"
      current_branch_oid="$(cut -f2 <<< "$current_identity")"
      git -C "$REPO" merge-base --is-ancestor "$SNAPSHOT_COMMIT" "$current_branch_oid" 2>/dev/null \
        || fail "current_branch_not_descendant_of_snapshot_commit: $ref"
      printf '%s\n' "$current_identity" >> "$expected_file"
    else
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ref" "$oid" "$type" "$peeled_oid" "$peeled_type" "$symref" >> "$expected_file"
    fi
  done < <(tail -n +2 "$TMP_DIR/snapshot.tsv")
  while IFS=$'\t' read -r side ref oid type _reason; do
    [[ "$side" == safety-publish && "$ref" == refs/heads/* ]] || continue
    tracking_ref="refs/remotes/origin/${ref#refs/heads/}"
    if ! awk -F '\t' -v wanted="$tracking_ref" 'NR > 1 && $1 == wanted { found=1 } END { exit !found }' "$TMP_DIR/snapshot.tsv"; then
      current_identity="$(awk -F '\t' -v wanted="$tracking_ref" '$1 == wanted { print $0; exit }' "$TMP_DIR/current-all-refs.tsv")"
      if [[ -n "$current_identity" ]]; then
        tracking_state="$(cut -f2-3 <<< "$current_identity")"
        [[ "$tracking_state" == "$oid"$'\t'"$type" ]] || fail "published_safety_tracking_identity_mismatch: $tracking_ref"
        printf '%s\n' "$current_identity" >> "$expected_file"
      fi
    fi
  done < <(tail -n +2 "$TMP_DIR/safety-list.tsv")
  sort "$expected_file" -o "$expected_file"
  sort "$TMP_DIR/current-all-refs.tsv" > "$actual_file"
  diff -u "$expected_file" "$actual_file" || fail 'local_ref_set_mismatch'
  printf 'PASS: complete local ref names, types, direct IDs, peeled IDs, symrefs, and allowlisted deletions match the committed keep set.\n'
}

capture_local() {
  (( APPLY == 0 )) || fail 'apply_not_valid_for_capture_local'
  [[ -n "$OUTPUT" ]] || fail 'capture_output_required'
  local destination="$OUTPUT" temp raw
  if [[ "$destination" != /* ]]; then destination="$PWD/$destination"; fi
  mkdir -p "$(dirname "$destination")"
  temp="${destination}.tmp.$$"
  raw="${destination}.raw.$$"
  trap 'rm -f "$temp" "$raw"' EXIT
  printf '%s\n' "$SNAPSHOT_HEADER" > "$temp"
  git -C "$REPO" for-each-ref \
    --format='%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)%09%(symref)' refs/ > "$raw" \
    || fail 'local_ref_enumeration_failed'
  awk -F '\t' 'BEGIN { OFS="\t" } { if (NF < 6) $6=""; for (i=1; i<=6; i++) if ($i == "") $i="-"; print $1,$2,$3,$4,$5,$6 }' "$raw" >> "$temp"
  validate_snapshot_file "$temp" yes >/dev/null
  mv "$temp" "$destination"
  rm -f "$raw"
  trap - EXIT
  printf 'captured local refs: %s rows at %s\n' "$(($(wc -l < "$destination") - 1))" "$destination"
}

# The remote-facing commands below deliberately use full refs and hide command
# output that can contain credential-bearing URLs. Only safe status fields are
# written to receipts.
cleanup() {
  if [[ "${SIGRA_COORDINATOR_HELD:-0}" == 1 ]]; then
    sigra_coordinator_release || printf 'prune-stale-branches: FAIL: coordinator_release_failed: %s\n' \
      "${SIGRA_COORDINATOR_ERROR:-unknown}"
  fi
  [[ -z "${TMP_DIR:-}" ]] || rm -rf "$TMP_DIR"
}

acquire_lock() {
  sigra_coordinator_acquire "$REPO" "prune-${COMMAND}" \
    || fail "shared_coordinator_unavailable: ${SIGRA_COORDINATOR_ERROR:-unknown}"
}

atomic_output() {
  local source="$1" destination="$2" temp
  [[ -n "$destination" ]] || fail 'capture_output_required'
  [[ "$destination" != /* ]] && destination="$PWD/$destination"
  mkdir -p "$(dirname "$destination")"
  temp="${destination}.tmp.$$"
  cp "$source" "$temp" || fail 'receipt_write_failed'
  mv "$temp" "$destination" || fail 'receipt_publish_failed'
}

origin_url_identity() {
  local url="$1" host owner repository
  if [[ "$url" =~ ^https://([^/]+)/([^/]+)/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    owner="${BASH_REMATCH[2]}"
    repository="${BASH_REMATCH[3]}"
  elif [[ "$url" =~ ^ssh://git@([^/:]+)/([^/]+)/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    owner="${BASH_REMATCH[2]}"
    repository="${BASH_REMATCH[3]}"
  elif [[ "$url" =~ ^git@([^:]+):([^/]+)/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    owner="${BASH_REMATCH[2]}"
    repository="${BASH_REMATCH[3]}"
  else
    fail 'origin_repository_identity_mismatch'
  fi

  [[ "$host" == github.com && "$owner" == szTheory \
    && ( "$repository" == sigra || "$repository" == sigra.git ) ]] \
    || fail 'origin_repository_identity_mismatch'
  printf '%s\n' 'github.com/szTheory/sigra'
}

origin_url_safe() {
  local fetch_urls push_urls fetch_url push_url fetch_identity push_identity
  local fetch_count=0 push_count=0
  local -a fetch_destinations push_destinations
  fetch_urls="$(git -C "$REPO" remote get-url --all origin 2>/dev/null)" \
    || fail 'origin_missing'
  push_urls="$(git -C "$REPO" remote get-url --push --all origin 2>/dev/null)" \
    || fail 'origin_push_destination_unverifiable'
  while IFS= read -r fetch_url; do
    fetch_destinations[$fetch_count]="$fetch_url"
    fetch_count=$((fetch_count + 1))
  done <<< "$fetch_urls"
  while IFS= read -r push_url; do
    push_destinations[$push_count]="$push_url"
    push_count=$((push_count + 1))
  done <<< "$push_urls"
  ((fetch_count == 1)) || fail 'origin_fetch_destination_ambiguous'
  ((push_count == 1)) || fail 'origin_push_destination_ambiguous'
  fetch_url="${fetch_destinations[0]}"
  push_url="${push_destinations[0]}"
  [[ -n "$fetch_url" && -n "$push_url" ]] || fail 'origin_destination_unverifiable'
  fetch_identity="$(origin_url_identity "$fetch_url")"
  push_identity="$(origin_url_identity "$push_url")"
  [[ "$fetch_identity" == "$push_identity" ]] \
    || fail 'origin_push_destination_identity_mismatch'
  printf '%s\n' "$fetch_identity"
}

pr_json_valid() {
  local file="$1"
  jq -e --argjson limit "$ORIGIN_LIMIT" '
    type == "array" and length < $limit and
    (. as $rows | ($rows | map(.number) | unique | length) == ($rows | length)) and
    all(.[]; (.number | type == "number" and . > 0) and
      .state == "OPEN" and
      (.headRefName | type == "string" and length > 0) and
      (.baseRefName | type == "string" and length > 0) and
      (.headRefOid | type == "string" and test("^([0-9a-f]{40}|[0-9a-f]{64})$")) and
      (.baseRefOid | type == "string" and test("^([0-9a-f]{40}|[0-9a-f]{64})$")))
  ' "$file" >/dev/null 2>&1
}

capture_prs_to() {
  local destination="$1" raw="$TMP_DIR/pr-list.json" actor stamp temp="$TMP_DIR/pr-capture.json"
  command -v gh >/dev/null 2>&1 || fail 'gh_not_on_path'
  gh auth status --hostname github.com >/dev/null 2>&1 || fail 'gh_authentication_failed'
  actor="$(gh api user --jq .login 2>/dev/null)" || fail 'gh_account_identity_unavailable'
  [[ -n "$actor" && "$actor" != *$'\n'* ]] || fail 'gh_account_identity_invalid'
  if ! gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit "$ORIGIN_LIMIT" \
    --json number,state,headRefName,baseRefName,headRefOid,baseRefOid > "$raw" 2>/dev/null; then
    fail 'live_pr_query_failed_or_rate_limited'
  fi
  pr_json_valid "$raw" || fail 'live_pr_result_incomplete_or_malformed'
  stamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  jq -n --arg repository "$GITHUB_REPOSITORY" --arg actor "$actor" \
    --arg captured_at "$stamp" --argjson limit "$ORIGIN_LIMIT" \
    --slurpfile prs "$raw" \
    '{schema_version:1,repository:$repository,actor:$actor,limit:$limit,captured_at:$captured_at,pull_requests:$prs[0]}' \
    > "$temp" || fail 'pr_capture_encode_failed'
  atomic_output "$temp" "$destination"
}

load_pr_state() {
  [[ -n "$PR_STATE_COMMIT" ]] || fail 'pr_state_commit_required'
  safe_repo_path "$PR_STATE_PATH"
  read_committed_file "$PR_STATE_COMMIT" "$PR_STATE_PATH" "$TMP_DIR/pr-baseline.json" pr_state
  jq -e '.schema_version == 1 and .repository == "szTheory/sigra" and (.captured_at | type == "string") and (.pull_requests | type == "array") and (.limit == 1000)' \
    "$TMP_DIR/pr-baseline.json" >/dev/null 2>&1 || fail 'pr_state_baseline_invalid'
  pr_json_valid <(jq '.pull_requests' "$TMP_DIR/pr-baseline.json") || fail 'pr_state_baseline_incomplete'
}

assert_pr_baseline_unchanged() {
  local current="$TMP_DIR/current-prs.json" baseline="$TMP_DIR/pr-baseline.json" baseline_row number current_row
  [[ -s "$baseline" ]] || load_pr_state
  capture_prs_to "$current"
  while IFS= read -r baseline_row; do
    number="$(jq -r '.number' <<< "$baseline_row")"
    current_row="$(jq -c --argjson n "$number" '.pull_requests[] | select(.number == $n)' "$current")"
    [[ -n "$current_row" ]] || fail "baseline_pr_missing_or_closed: #$number"
    [[ "$(jq -cS . <<< "$baseline_row")" == "$(jq -cS . <<< "$current_row")" ]] \
      || fail "baseline_pr_identity_changed: #$number"
  done < <(jq -c '.pull_requests[]' "$baseline")
}

assert_pr_ref_unprotected() {
  local candidate="$1" current="$TMP_DIR/current-prs.json" branch=${1#refs/heads/}
  [[ -s "$current" ]] || capture_prs_to "$current"
  jq -e --arg ref "$branch" 'all(.pull_requests[]; .headRefName != $ref and .baseRefName != $ref)' "$current" \
    >/dev/null 2>&1 || fail "live_pr_head_or_base_protects_ref: $candidate"
}

capture_prs() {
  (( APPLY == 0 )) || fail 'apply_not_valid_for_capture_prs'
  capture_prs_to "${OUTPUT:-}"
  printf 'captured complete open PR state for %s\n' "$GITHUB_REPOSITORY"
}

origin_listing() {
  local output="$1"
  if ! git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false ls-remote --symref origin > "$output" 2>/dev/null; then
    if ! git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false ls-remote --symref origin > "$output" 2>/dev/null; then
      fail 'origin_ref_read_failed_after_retry'
    fi
  fi
  [[ -s "$output" ]] || fail 'origin_ref_read_empty'
}

capture_origin() {
  (( APPLY == 0 )) || fail 'apply_not_valid_for_capture_origin'
  [[ -n "$OUTPUT" ]] || fail 'capture_output_required'
  capture_origin_to_file "$TMP_DIR/origin-capture.tsv"
  atomic_output "$TMP_DIR/origin-capture.tsv" "$OUTPUT"
  printf 'captured origin refs: %s rows at %s\n' "$(($(wc -l < "$TMP_DIR/origin-capture.tsv") - 1))" "$OUTPUT"
}

validate_exact_operation_ref() {
  local operation="$1" ref="$2"
  [[ "$operation" == publish || "$operation" == delete ]] || fail 'operation_invalid'
  [[ "$ref" == refs/heads/* || ( "$operation" == publish && "$ref" == refs/tags/* ) ]] \
    || fail 'operation_ref_namespace_invalid'
  git check-ref-format "$ref" >/dev/null 2>&1 || fail 'operation_ref_invalid'
}

current_origin_identity() {
  local wanted="$1" listing="$TMP_DIR/live-origin.tsv"
  capture_origin_to_file "$listing"
  awk -F '\t' -v wanted="$wanted" 'NR > 1 && $1 == wanted { print $2 "\t" $3; found=1; exit } END { if (!found) exit 1 }' "$listing"
}

capture_origin_to_file() {
  local destination="$1" listing="$TMP_DIR/origin.raw" reread="$TMP_DIR/origin.reread" temp="$TMP_DIR/origin.tsv" oid ref type peeled_oid peeled_type origin_head_target='' origin_head_oid=''
  origin_url_safe >/dev/null
  origin_listing "$listing"
  printf '%s\n' "$SNAPSHOT_HEADER" > "$temp"
  while IFS=$'\t' read -r oid ref; do
    if [[ "$ref" == HEAD && "$oid" == 'ref: refs/'* ]]; then
      origin_head_target="${oid#ref: }"
      continue
    fi
    if [[ "$ref" == HEAD ]]; then
      valid_oid "$oid" || fail 'origin_head_oid_invalid'
      origin_head_oid="$oid"
      continue
    fi
    [[ "$ref" == refs/* && "$ref" != *'^{}' ]] || continue
    valid_oid "$oid" || fail "origin_oid_invalid: $ref"
    git check-ref-format "$ref" >/dev/null 2>&1 || fail "origin_ref_invalid: $ref"
    type="$(git -C "$REPO" cat-file -t "$oid" 2>/dev/null || true)"
    if [[ -z "$type" ]]; then
      git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false fetch --no-tags origin "$ref" \
        >/dev/null 2>&1 || fail "origin_exact_fetch_failed: $ref"
      type="$(git -C "$REPO" cat-file -t "$oid" 2>/dev/null || true)"
      [[ -n "$type" ]] || fail "origin_ref_changed_or_object_missing_after_fetch: $ref"
    fi
    valid_type "$type" || fail "origin_object_type_invalid: $ref"
    peeled_oid='-'; peeled_type='-'
    if [[ "$type" == tag ]]; then
      peeled_oid="$(git -C "$REPO" rev-parse "${oid}^{}" 2>/dev/null)" || fail "origin_tag_unpeelable: $ref"
      peeled_type="$(git -C "$REPO" cat-file -t "$peeled_oid" 2>/dev/null)" || fail "origin_tag_target_missing: $ref"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t-\n' "$ref" "$oid" "$type" "$peeled_oid" "$peeled_type" >> "$temp"
  done < "$listing"
  if [[ -n "$origin_head_target" || -n "$origin_head_oid" ]]; then
    [[ -n "$origin_head_target" && -n "$origin_head_oid" ]] || fail 'origin_head_symref_incomplete'
    local target_identity target_type
    target_identity="$(awk -F '\t' -v wanted="$origin_head_target" 'NR > 1 && $1 == wanted { print $2; exit }' "$temp")"
    target_type="$(awk -F '\t' -v wanted="$origin_head_target" 'NR > 1 && $1 == wanted { print $3; exit }' "$temp")"
    [[ "$target_identity" == "$origin_head_oid" && -n "$target_type" ]] || fail 'origin_head_target_identity_mismatch'
    printf 'refs/remotes/origin/HEAD\t%s\t%s\t-\t-\t%s\n' \
      "$origin_head_oid" "$target_type" "$origin_head_target" >> "$temp"
  fi
  validate_snapshot_file "$temp" yes >/dev/null
  origin_listing "$reread"
  sort "$listing" > "$TMP_DIR/origin.listing.sorted"
  sort "$reread" > "$TMP_DIR/origin.reread.sorted"
  diff -u "$TMP_DIR/origin.listing.sorted" "$TMP_DIR/origin.reread.sorted" \
    || fail 'origin_refs_changed_during_capture'
  cp "$temp" "$destination"
}

find_allowlist_row() {
  local file="$1" side="$2" ref="$3"
  awk -F '\t' -v side="$side" -v ref="$ref" 'NR > 1 && $1 == side && $2 == ref { print $3 "\t" $4 "\t" $5; found=1; exit } END { if (!found) exit 1 }' "$file"
}

preflight_check() {
  local operation="$1" ref="$2" identity actor repo_json raw="$TMP_DIR/pr-preflight.json" push_refspec
  if [[ -z "$PREFLIGHT_STATUS_FILE" ]]; then
    PREFLIGHT_STATUS_FILE="$TMP_DIR/internal-preflight-status.tsv"
    : > "$PREFLIGHT_STATUS_FILE"
  fi
  PREFLIGHT_STAGE=origin_identity
  validate_exact_operation_ref "$operation" "$ref"
  identity="$(origin_url_safe)"
  printf 'origin_identity\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  command -v gh >/dev/null 2>&1 || fail 'gh_not_on_path'
  PREFLIGHT_STAGE=gh_auth
  gh auth status --hostname github.com >/dev/null 2>&1 || fail 'gh_authentication_failed'
  printf 'gh_auth\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=account_identity
  actor="$(gh api user --jq .login 2>/dev/null)" || fail 'gh_account_identity_unavailable'
  [[ -n "$actor" && "$actor" != *$'\n'* ]] || fail 'gh_account_identity_invalid'
  printf 'account_identity\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=complete_pr_read
  if ! gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit "$ORIGIN_LIMIT" \
    --json number,state,headRefName,baseRefName,headRefOid,baseRefOid > "$raw" 2>/dev/null; then
    fail 'live_pr_query_failed_or_rate_limited'
  fi
  printf 'complete_pr_read\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=pr_completeness
  pr_json_valid "$raw" || fail 'live_pr_result_incomplete_or_malformed'
  printf 'pr_completeness\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=pr_exclusion
  jq -n --arg repository "$GITHUB_REPOSITORY" --arg actor "$actor" \
    --arg captured_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --argjson limit "$ORIGIN_LIMIT" \
    --slurpfile prs "$raw" \
    '{schema_version:1,repository:$repository,actor:$actor,limit:$limit,captured_at:$captured_at,pull_requests:$prs[0]}' \
    > "$TMP_DIR/preflight-prs.json"
  jq -e --arg ref "${ref#refs/heads/}" 'all(.pull_requests[]; .headRefName != $ref and .baseRefName != $ref)' \
    "$TMP_DIR/preflight-prs.json" >/dev/null 2>&1 || fail "live_pr_head_or_base_protects_ref: $ref"
  printf 'pr_exclusion\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"

  PREFLIGHT_STAGE=origin_read
  origin_listing "$TMP_DIR/preflight-origin.txt"
  if [[ "$operation" == publish ]]; then
    if awk -F '\t' -v wanted="$ref" '$2 == wanted { found=1 } END { exit !found }' "$TMP_DIR/preflight-origin.txt"; then
      fail 'publish_target_ref_already_exists'
    fi
  else
    awk -F '\t' -v wanted="$ref" '$2 == wanted { found=1 } END { exit !found }' "$TMP_DIR/preflight-origin.txt" \
      || fail 'delete_target_ref_absent'
  fi
  printf 'origin_read\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=push_permission
  repo_json="$(gh api "repos/${GITHUB_REPOSITORY}" 2>/dev/null)" || fail 'repository_permissions_unavailable'
  jq -e --arg repo "$GITHUB_REPOSITORY" '.full_name == $repo and .permissions.push == true' \
    <<< "$repo_json" >/dev/null 2>&1 || fail 'repository_push_permission_not_confirmed'
  printf 'push_permission\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  if [[ "$operation" == publish ]]; then
    git -C "$REPO" show-ref --verify --quiet "$ref" || fail 'publish_source_ref_absent'
    push_refspec="${ref}:${ref}"
  else
    push_refspec=":${ref}"
  fi
  PREFLIGHT_STAGE=exact_ref_push_dry_run
  git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false push --dry-run origin "$push_refspec" \
    >/dev/null 2>&1 || fail 'exact_ref_push_dry_run_failed'
  printf 'exact_ref_push_dry_run\tpassed\n' >> "$PREFLIGHT_STATUS_FILE"
  PREFLIGHT_STAGE=""
  printf '%s\t%s\t%s\t%s\n' "$identity" "$actor" "$(jq '.pull_requests | length' "$TMP_DIR/preflight-prs.json")" "$push_refspec"
}

write_preflight_receipt() {
  local operation="$1" ref="$2" destination="$3" result="$4" detail="$5" identity="unknown" actor="unknown" count=0 push_refspec="unknown" temp="$TMP_DIR/preflight-receipt.json"
  if [[ -s "$TMP_DIR/preflight-safe.tsv" ]]; then
    IFS=$'\t' read -r identity actor count push_refspec < "$TMP_DIR/preflight-safe.tsv"
  fi
  jq -n --arg repository "$GITHUB_REPOSITORY" --arg origin "$identity" --arg actor "$actor" \
    --arg operation "$operation" --arg ref "$ref" --arg result "$result" \
    --arg detail "$detail" --arg captured_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --argjson pr_count "$count" --arg push_refspec "$push_refspec" \
    '{schema_version:1,repository:$repository,origin_identity:$origin,actor:$actor,operation:$operation,ref:$ref,result:$result,detail:$detail,pr_count:$pr_count,push_refspec:$push_refspec,captured_at:$captured_at,checks:[]}' \
    > "$temp"
  if [[ -s "$PREFLIGHT_STATUS_FILE" ]]; then
    jq --slurpfile checks <(jq -Rn '[inputs | split("\t") | {check:.[0],status:.[1]}]' "$PREFLIGHT_STATUS_FILE") \
      '.checks = $checks[0]' "$temp" > "${temp}.with-checks" && mv "${temp}.with-checks" "$temp"
  fi
  atomic_output "$temp" "$destination"
}

preflight_origin_access() {
  (( APPLY == 0 )) || fail 'apply_not_valid_for_preflight'
  [[ -n "$OUTPUT" ]] || OUTPUT="$PREFLIGHT_PATH"
  validate_exact_operation_ref "$OPERATION" "$REF"
  PREFLIGHT_STATUS_FILE="$TMP_DIR/preflight-status.tsv"
  : > "$PREFLIGHT_STATUS_FILE"
  local detail='passed'
  if ( preflight_check "$OPERATION" "$REF" > "$TMP_DIR/preflight-safe.tsv" 2>/dev/null ); then
    write_preflight_receipt "$OPERATION" "$REF" "$OUTPUT" passed "$detail"
    printf 'PASS: non-mutating origin access preflight passed for %s %s.\n' "$OPERATION" "$REF"
  else
    write_preflight_receipt "$OPERATION" "$REF" "$OUTPUT" failed 'access_or_safety_check_failed'
    fail 'origin_access_preflight_failed; safe diagnostic receipt written'
  fi
}

load_preflight_receipt() {
  local operation="$1" ref="$2"
  [[ -n "$PREFLIGHT_COMMIT" ]] || fail 'preflight_commit_required'
  safe_repo_path "$PREFLIGHT_PATH"
  read_committed_file "$PREFLIGHT_COMMIT" "$PREFLIGHT_PATH" "$TMP_DIR/preflight.json" preflight
  jq -e --arg op "$operation" --arg ref "$ref" \
    '.schema_version == 1 and .repository == "szTheory/sigra" and .result == "passed" and .operation == $op and .ref == $ref and ((now - (.captured_at | fromdateiso8601)) >= 0 and (now - (.captured_at | fromdateiso8601)) < 900)' \
    "$TMP_DIR/preflight.json" >/dev/null 2>&1 || fail 'committed_preflight_missing_or_mismatched'
}

verify_required_readiness() {
  local commit="${READINESS_COMMIT:-$ALLOWLIST_COMMIT}"
  [[ -n "$commit" ]] || fail 'd01_readiness_commit_required'
  verify_readiness "$TMP_DIR/readiness.json"
}

assert_snapshot_allowlist_identity() {
  local side="$1" ref="$2" oid="$3" type="$4" inv="$TMP_DIR/snapshot.tsv" actual symref_target
  if [[ "$side" == remote || "$side" == safety-publish ]]; then
    if [[ "$side" == remote ]]; then
      [[ -n "$ORIGIN_COMMIT" ]] || fail 'origin_commit_required'
      safe_repo_path "$ORIGIN_PATH"
      read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$TMP_DIR/origin-snapshot.tsv" origin
      validate_snapshot_file "$TMP_DIR/origin-snapshot.tsv" yes >/dev/null
      inv="$TMP_DIR/origin-snapshot.tsv"
    else
      load_snapshot
      inv="$TMP_DIR/snapshot.tsv"
    fi
  else
    load_snapshot
    inv="$TMP_DIR/snapshot.tsv"
  fi
  actual="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3; exit }' "$inv")"
  if [[ "$side" == safety-publish && -z "$actual" ]]; then
    actual="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3; exit }' "$TMP_DIR/snapshot.tsv")"
    [[ -n "$actual" ]] || fail "safety_source_ref_absent: $ref"
    [[ "$actual" == "$oid"$'\t'"$type" ]] || fail "safety_source_identity_mismatch: $ref"
    return
  fi
  [[ "$actual" == "$oid"$'\t'"$type" ]] || fail "allowlist_snapshot_identity_mismatch: $side:$ref"
  if [[ "$side" == tracking ]]; then
    [[ "$ref" != refs/remotes/origin/HEAD ]] || fail 'tracking_origin_head_alias_not_allowed'
    symref_target="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $6; exit }' "$inv")"
    [[ -n "$symref_target" && "$symref_target" == '-' ]] \
      || fail "tracking_ref_snapshot_is_symbolic: $ref"
  fi
}

run_safety_publish() {
  local count side ref oid type reason live current_oid current_type out first=1 tracking_ref tracking_oid
  verify_required_readiness
  origin_url_safe >/dev/null
  load_snapshot
  load_safety_list
  count="$(validate_allowlist_file "$TMP_DIR/safety-list.tsv" safety-publish)"
  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == safety-publish ]] || continue
    case "$ref" in
      refs/tags/archive/local-main-pre-235-recovery|refs/heads/safety/local-main-before-release-cleanup-20260831) ;;
      *) fail "safety_publish_destination_not_approved: $ref" ;;
    esac
    case "$ref:$type" in
      refs/heads/*:commit|refs/tags/*:commit) ;;
      *) fail "safety_publish_ref_kind_invalid: $ref/$type" ;;
    esac
    assert_snapshot_allowlist_identity safety-publish "$ref" "$oid" "$type"
    if [[ "$ref" == refs/heads/* ]]; then
      tracking_ref="refs/remotes/origin/${ref#refs/heads/}"
      tracking_oid="$(git -C "$REPO" rev-parse --verify "$tracking_ref" 2>/dev/null || true)"
      [[ -z "$tracking_oid" || "$tracking_oid" == "$oid" ]] \
        || fail "safety_tracking_ref_identity_conflict: $tracking_ref"
    fi
    live="$(current_origin_identity "$ref" 2>/dev/null || true)"
    if [[ -n "$live" ]]; then
      [[ "$live" == "$oid"$'\t'"$type" ]] || fail "safety_ref_identity_conflict: $ref"
      printf 'already present with expected identity: %s\n' "$ref"
      continue
    fi
    if (( ! APPLY )); then
      printf 'would publish absent safety ref %s (%s)\n' "$ref" "$reason"
      continue
    fi
    if (( first )); then
      load_preflight_receipt publish "$ref"
      first=0
    fi
    if (( CURRENT_CONTRACT_MODE )); then
      verify_current_contract boundary safety-publish "$ref" publish
    else
      assert_pr_baseline_unchanged
    fi
    preflight_check publish "$ref" >/dev/null 2>&1 || fail "fresh_publish_preflight_failed: $ref"
    if (( CURRENT_CONTRACT_MODE )); then verify_current_contract boundary safety-publish "$ref" publish; else assert_pr_baseline_unchanged; fi
    live="$(current_origin_identity "$ref" 2>/dev/null || true)"
    [[ -z "$live" ]] || fail "safety_ref_appeared_before_publish: $ref"
    if ! out="$(git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false \
      push --force-with-lease="${ref}:" origin "${ref}:${ref}" 2>&1 </dev/null)"; then
      local observed_identity
      observed_identity="$(current_origin_identity "$ref" 2>/dev/null || printf absent)"
      fail "safety_publish_lease_rejected: ${ref} expected=absent observed=${observed_identity}: ${out}"
    fi
    live="$(current_origin_identity "$ref")" || fail "safety_publish_readback_missing: $ref"
    [[ "$live" == "$oid"$'\t'"$type" ]] || fail "safety_publish_readback_mismatch: $ref"
    verify_current_contract after safety-publish "$ref" publish
    printf 'published absent safety ref: %s (%s)\n' "$ref" "$reason"
  done < <(tail -n +2 "$TMP_DIR/safety-list.tsv")
  printf 'PASS: safety publication pass processed %s committed exact ref rows.\n' "$count"
}

run_remote_pass() {
  local count side ref oid type reason live branch_name out current_oid current_type first=1
  verify_required_readiness
  origin_url_safe >/dev/null
  if (( CURRENT_CONTRACT_MODE == 0 )); then load_pr_state; fi
  load_allowlist
  load_snapshot
  count="$(validate_allowlist_file "$TMP_DIR/allowlist.tsv" remote)"
  if (( CURRENT_CONTRACT_MODE == 0 )); then assert_pr_baseline_unchanged; fi
  verify_safety
  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == remote ]] || continue
    assert_snapshot_allowlist_identity remote "$ref" "$oid" "$type"
    if (( CURRENT_CONTRACT_MODE == 0 )); then assert_pr_ref_unprotected "$ref"; fi
    live="$(current_origin_identity "$ref" 2>/dev/null || true)"
    [[ -n "$live" ]] || { printf 'already absent: %s\n' "$ref"; continue; }
    IFS=$'\t' read -r current_oid current_type <<< "$live"
    [[ "$current_oid" == "$oid" && "$current_type" == "$type" ]] \
      || fail "remote_ref_identity_conflict: $ref"
    (( APPLY )) || { printf 'would delete origin ref %s (%s)\n' "$ref" "$reason"; continue; }
    if (( first )); then
      load_preflight_receipt delete "$ref"
      first=0
    fi
    preflight_check delete "$ref" >/dev/null 2>&1 || fail "fresh_delete_preflight_failed: $ref"
    verify_current_contract boundary remote "$ref" delete
    if (( CURRENT_CONTRACT_MODE == 0 )); then assert_pr_baseline_unchanged; fi
    verify_safety
    live="$(current_origin_identity "$ref")" || fail "remote_ref_disappeared_before_delete: $ref"
    [[ "$live" == "$oid"$'\t'"$type" ]] || fail "remote_ref_changed_before_delete: $ref"
    assert_deletion_ref_protected "$ref"
    branch_name="${ref#refs/heads/}"
    if ! out="$(git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false \
      push --force-with-lease="${ref}:${oid}" origin ":${ref}" 2>&1 </dev/null)"; then
      local observed_identity
      observed_identity="$(current_origin_identity "$ref" 2>/dev/null || printf absent)"
      fail "remote_delete_lease_rejected: ${ref} expected=${oid}/${type} observed=${observed_identity}: ${out}"
    fi
    verify_current_contract after remote "$ref" delete
    if current_origin_identity "$ref" >/dev/null 2>&1; then fail "remote_delete_readback_still_present: $ref"; fi
    printf 'deleted origin ref %s (%s)\n' "$ref" "$reason"
  done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
  printf 'PASS: origin deletion pass processed %s committed exact ref rows.\n' "$count"
}

run_tracking_pass() {
  local count side ref oid type reason remote_ref live local_oid out symref_target
  verify_required_readiness
  if (( CURRENT_CONTRACT_MODE == 0 )); then load_pr_state; fi
  load_allowlist
  load_snapshot
  count="$(validate_allowlist_file "$TMP_DIR/allowlist.tsv" tracking)"
  if (( CURRENT_CONTRACT_MODE == 0 )); then assert_pr_baseline_unchanged; fi
  capture_origin_to_file "$TMP_DIR/live-origin.tsv"
  while IFS=$'\t' read -r side ref oid type reason; do
    [[ "$side" == tracking ]] || continue
    assert_snapshot_allowlist_identity tracking "$ref" "$oid" "$type"
    remote_ref="refs/heads/${ref#refs/remotes/origin/}"
    if awk -F '\t' -v wanted="$remote_ref" 'NR > 1 && $1 == wanted { found=1 } END { exit !found }' "$TMP_DIR/live-origin.tsv"; then
      fail "tracking_ref_remote_still_present: $remote_ref"
    fi
    local_oid="$(git -C "$REPO" rev-parse --verify "$ref" 2>/dev/null || true)"
    if [[ -z "$local_oid" ]]; then
      printf 'already absent after remote deletion: %s\n' "$ref"
      continue
    fi
    [[ "$local_oid" == "$oid" ]] || fail "tracking_ref_identity_conflict: $ref"
    (( APPLY )) || { printf 'would delete tracking ref %s\n' "$ref"; continue; }
    symref_target="$(git -C "$REPO" symbolic-ref -q "$ref" 2>/dev/null || true)"
    [[ -z "$symref_target" ]] || fail "tracking_ref_is_symbolic: $ref"
    # Recheck remote absence and the local ref kind immediately before mutation.
    capture_origin_to_file "$TMP_DIR/live-origin.tsv"
    if awk -F '\t' -v wanted="$remote_ref" 'NR > 1 && $1 == wanted { found=1 } END { exit !found }' "$TMP_DIR/live-origin.tsv"; then
      fail "tracking_ref_remote_still_present: $remote_ref"
    fi
    symref_target="$(git -C "$REPO" symbolic-ref -q "$ref" 2>/dev/null || true)"
    [[ -z "$symref_target" ]] || fail "tracking_ref_became_symbolic: $ref"
    verify_current_contract boundary tracking "$ref" delete
    assert_deletion_ref_protected "$ref"
    if ! out="$(git -C "$REPO" update-ref --no-deref -d "$ref" "$oid" 2>&1 </dev/null)"; then
      fail "tracking_ref_delete_failed: $ref"
    fi
    verify_current_contract after tracking "$ref" delete
    printf 'deleted tracking ref %s with no-deref expected-old-OID guard\n' "$ref"
  done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
  printf 'PASS: exact tracking-ref pass processed %s committed rows.\n' "$count"
}

verify_allowlist() {
  local count side ref oid type reason origin_file="$TMP_DIR/origin-snapshot.tsv" default_ref protected_ref
  (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_allowlist'
  if (( CURRENT_CONTRACT_MODE )); then
    verify_current_contract before
    printf 'PASS: current committed allowlist matches pinned PR heads/bases and exact ref identities.\n'
    return 0
  fi
  load_snapshot
  load_allowlist
  load_safety_list
  count="$(validate_allowlist_file "$TMP_DIR/allowlist.tsv" any)"
  read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$origin_file" origin
  validate_snapshot_file "$origin_file" yes >/dev/null
  load_pr_state
  assert_pr_baseline_unchanged
  verify_safety
  default_ref="$(awk -F '\t' 'NR > 1 && $1 == "refs/remotes/origin/HEAD" { print $6; exit }' "$origin_file")"
  [[ -n "$default_ref" && "$default_ref" != '-' ]] || fail 'origin_default_branch_symref_missing'
  local deletion_count=0
  while IFS=$'\t' read -r side ref oid type reason; do
    case "$side" in
      local) assert_snapshot_allowlist_identity local "$ref" "$oid" "$type"; deletion_count=$((deletion_count + 1)) ;;
      remote) assert_snapshot_allowlist_identity remote "$ref" "$oid" "$type"; deletion_count=$((deletion_count + 1)) ;;
      tracking)
        assert_snapshot_allowlist_identity tracking "$ref" "$oid" "$type"
        deletion_count=$((deletion_count + 1)) ;;
    esac
    if [[ "$side" == local || "$side" == remote || "$side" == tracking ]]; then
      local branch="${ref#refs/heads/}"
      protected_ref="$ref"
      if [[ "$side" == tracking ]]; then
        branch="${ref#refs/remotes/origin/}"
        protected_ref="refs/heads/${branch}"
      fi
      [[ "$protected_ref" != "$default_ref" ]] || fail "allowlist_includes_origin_default_branch: $protected_ref"
      is_safety_ref "$protected_ref" && fail "allowlist_includes_safety_ref: $protected_ref"
      jq -e --arg branch "$branch" 'all(.pull_requests[]; .headRefName != $branch and .baseRefName != $branch)' \
        "$TMP_DIR/pr-baseline.json" >/dev/null 2>&1 || fail "allowlist_overlaps_pr_baseline: $ref"
    fi
  done < <(tail -n +2 "$TMP_DIR/allowlist.tsv")
  [[ "$deletion_count" -gt 0 ]] || fail 'allowlist_has_no_deletion_candidates'
  printf 'PASS: %s committed exact allowlist rows bind to local/origin inventories and avoid baseline PR names.\n' "$count"
}

is_safety_ref() {
  case "$1" in
    refs/heads/ci/phase-235-16-source-complete|refs/heads/safety/local-main-before-release-cleanup-*|refs/tags/archive/local-main-pre-235-recovery) return 0 ;;
    *) return 1 ;;
  esac
}

verify_safety() {
  local ref oid type peeled_oid peeled_type local_current origin_current expected published_identity
  load_snapshot
  [[ -n "$ORIGIN_COMMIT" ]] || fail 'origin_commit_required'
  safe_repo_path "$ORIGIN_PATH"
  read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$TMP_DIR/origin-snapshot.tsv" origin
  validate_snapshot_file "$TMP_DIR/origin-snapshot.tsv" yes >/dev/null
  load_safety_list
  capture_origin_to_file "$TMP_DIR/live-origin.tsv"
  local count=0
  while IFS=$'\t' read -r ref oid type peeled_oid peeled_type _symref; do
    is_safety_ref "$ref" || continue
    local_current="$(git -C "$REPO" for-each-ref --format='%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)' "$ref" | awk -F '\t' 'BEGIN { OFS="\t" } { for (i=3; i<=4; i++) if ($i == "") $i="-"; print $1,$2,$3,$4 }')"
    [[ "$local_current" == "$oid"$'\t'"$type"$'\t'"$peeled_oid"$'\t'"$peeled_type" ]] \
      || fail "local_safety_identity_changed: $ref"
    origin_current="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3 "\t" $4 "\t" $5; exit }' "$TMP_DIR/live-origin.tsv")"
    expected="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3 "\t" $4 "\t" $5; exit }' "$TMP_DIR/origin-snapshot.tsv")"
    if [[ -z "$expected" ]]; then
      published_identity="$(find_allowlist_row "$TMP_DIR/safety-list.tsv" safety-publish "$ref" 2>/dev/null || true)"
      [[ -n "$published_identity" ]] || fail "new_safety_ref_missing_committed_publish_row: $ref"
      [[ "$published_identity" == "$oid"$'\t'"$type"$'\t'* ]] || fail "safety_publish_identity_mismatch: $ref"
      expected="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3 "\t" $4 "\t" $5; exit }' "$TMP_DIR/snapshot.tsv")"
      [[ -n "$expected" ]] || continue
    fi
    if [[ "$ref" != refs/heads/ci/phase-235-16-source-complete ]]; then
      [[ "$expected" == "$oid"$'\t'"$type"$'\t'* ]] \
        || fail "same_name_safety_ref_oid_conflict: $ref"
    fi
    if [[ -n "$origin_current" ]]; then
      [[ "$origin_current" == "$expected" ]] || fail "origin_safety_identity_changed: $ref"
    else
      fail "origin_safety_ref_missing: $ref"
    fi
    count=$((count + 1))
  done < <(tail -n +2 "$TMP_DIR/snapshot.tsv")
  while IFS=$'\t' read -r ref oid type peeled_oid peeled_type _symref; do
    is_safety_ref "$ref" || continue
    if awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { found=1 } END { exit !found }' "$TMP_DIR/snapshot.tsv"; then
      continue
    fi
    origin_current="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $2 "\t" $3 "\t" $4 "\t" $5; exit }' "$TMP_DIR/live-origin.tsv")"
    [[ "$origin_current" == "$oid"$'\t'"$type"$'\t'"$peeled_oid"$'\t'"$peeled_type" ]] \
      || fail "origin_only_safety_identity_changed: $ref"
    count=$((count + 1))
  done < <(tail -n +2 "$TMP_DIR/origin-snapshot.tsv")
  [[ "$count" -gt 0 ]] || fail 'safety_ref_set_empty'
  printf 'PASS: %s required safety refs retain their exact local and origin identity, including namespace/type.\n' "$count"
}

verify_remote_set() {
  local ref oid type peeled_oid peeled_type symref deleted row expected="$TMP_DIR/expected-origin-refs.tsv" actual_file="$TMP_DIR/actual-origin-refs.tsv"
  load_snapshot
  [[ -n "$ORIGIN_COMMIT" ]] || fail 'origin_commit_required'
  safe_repo_path "$ORIGIN_PATH"
  read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$TMP_DIR/origin-snapshot.tsv" origin
  validate_snapshot_file "$TMP_DIR/origin-snapshot.tsv" yes >/dev/null
  load_allowlist
  load_safety_list
  validate_allowlist_file "$TMP_DIR/allowlist.tsv" any >/dev/null
  : > "$expected"
  while IFS=$'\t' read -r ref oid type peeled_oid peeled_type _symref; do
    deleted="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == "remote" && $2 == wanted { print "yes"; exit }' "$TMP_DIR/allowlist.tsv")"
    [[ "$deleted" == yes ]] || printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ref" "$oid" "$type" "$peeled_oid" "$peeled_type" "${_symref:--}" >> "$expected"
  done < <(tail -n +2 "$TMP_DIR/origin-snapshot.tsv")
  while IFS=$'\t' read -r side ref oid type _reason; do
    [[ "$side" == safety-publish ]] || continue
    if ! awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { found=1 } END { exit !found }' "$TMP_DIR/origin-snapshot.tsv"; then
      row="$(awk -F '\t' -v wanted="$ref" 'NR > 1 && $1 == wanted { print $0; exit }' "$TMP_DIR/snapshot.tsv")"
      [[ -n "$row" ]] || fail "safety_publish_source_missing_from_snapshot: $ref"
      printf '%s\n' "$row" >> "$expected"
    fi
  done < <(tail -n +2 "$TMP_DIR/safety-list.tsv")
  capture_origin_to_file "$TMP_DIR/live-origin.tsv"
  tail -n +2 "$TMP_DIR/live-origin.tsv" | sort > "$actual_file"
  sort "$expected" -o "$expected"
  diff -u "$expected" "$actual_file" || fail 'origin_branch_set_or_identity_mismatch'
  printf 'PASS: complete origin ref names, types, direct IDs, peeled IDs, and symrefs match the committed keep set.\n'
}

verify_prs() {
  local current="$TMP_DIR/current-prs.json" row number branch base_oid actual
  (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_prs'
  if [[ -n "$CURRENT_CONTRACT_COMMIT" || -n "$CURRENT_CONTRACT_PATH" ]]; then
    [[ -n "$CURRENT_CONTRACT_COMMIT" ]] || fail 'current_contract_commit_required'
    [[ -n "$CURRENT_CONTRACT_PATH" ]] || fail 'current_contract_path_required'
    [[ -z "$PR_STATE_COMMIT" && -z "$IDENTITY_AUDIT" && -z "$INTEGRITY_OUTPUT" ]] \
      || fail 'current_contract_historical_flags_mixed'
    safe_repo_path "$CURRENT_CONTRACT_PATH"
    local current_args=(verify --repo "$REPO" --contract-commit "$CURRENT_CONTRACT_COMMIT" --contract "$CURRENT_CONTRACT_PATH" --stage before)
    if [[ -n "$CURRENT_CONTRACT_FIXTURE" ]]; then
      safe_repo_path "$CURRENT_CONTRACT_FIXTURE"
      current_args+=(--source-fixture "$CURRENT_CONTRACT_FIXTURE")
    fi
    node "$SCRIPT_ROOT/scripts/maintainers/prune-stale-branches-current.mjs" "${current_args[@]}" \
      || fail 'current_pr_ref_contract_blocked'
    return 0
  fi
  [[ -z "$CURRENT_CONTRACT_FIXTURE" ]] || fail 'current_contract_fixture_requires_current_contract'
  load_pr_state
  if [[ -n "$IDENTITY_AUDIT" || -n "$INTEGRITY_OUTPUT" ]]; then
    [[ -n "$IDENTITY_AUDIT" && -n "$INTEGRITY_OUTPUT" ]] || fail 'identity_audit_and_integrity_output_required_together'
    safe_repo_path "$IDENTITY_AUDIT"
    safe_repo_path "$INTEGRITY_OUTPUT"
    command -v node >/dev/null 2>&1 || fail 'node_not_on_path_for_pr_identity_audit'
    local verify_command verify_status=0
    verify_command="bash scripts/maintainers/prune-stale-branches.sh verify-prs --pr-state-commit ${PR_STATE_COMMIT} --identity-audit ${IDENTITY_AUDIT} --integrity-output ${INTEGRITY_OUTPUT}"
    node "${SCRIPT_ROOT}/scripts/maintainers/prune-stale-branches-pr-audit.mjs" verify-live \
      --repo "$REPO" --audit "$IDENTITY_AUDIT" --baseline-file "$TMP_DIR/pr-baseline.json" \
      --baseline-commit "$PR_STATE_COMMIT" --baseline-path "$PR_STATE_PATH" \
      --integrity-output "$INTEGRITY_OUTPUT" --verify-command "$verify_command" \
      || verify_status=$?
    node "${SCRIPT_ROOT}/scripts/maintainers/prune-stale-branches-pr-audit.mjs" record-exit \
      --integrity-output "$INTEGRITY_OUTPUT" --exit-status "$verify_status" --command "$verify_command" \
      >/dev/null || fail 'integrity_exit_status_record_failed'
    (( verify_status == 0 )) || fail "current_pr_identity_integrity_blocked: ${INTEGRITY_OUTPUT}"
    printf 'PASS: the committed audit corroborates all 11 historical base mismatches and current open-PR identities.\n'
    return 0
  fi
  capture_prs_to "$current"
  while IFS= read -r row; do
    number="$(jq -r '.number' <<< "$row")"
    local live_row
    live_row="$(jq -c --argjson n "$number" '.pull_requests[] | select(.number == $n)' "$current")"
    [[ -n "$live_row" ]] || fail "baseline_pr_missing_or_closed: #$number"
    [[ "$(jq -cS . <<< "$row")" == "$(jq -cS . <<< "$live_row")" ]] \
      || fail "baseline_pr_identity_changed: #$number"
    branch="$(jq -r '.baseRefName' <<< "$row")"
    base_oid="$(jq -r '.baseRefOid' <<< "$row")"
    actual="$(git -C "$REPO" ls-remote --heads origin "refs/heads/${branch}" 2>/dev/null | awk 'NR==1 {print $1}')"
    [[ "$actual" == "$base_oid" ]] || fail "pr_base_oid_mismatch: #$number"
  done < <(jq -c '.pull_requests[]' "$TMP_DIR/pr-baseline.json")
  printf 'PASS: all %s baseline PRs remain open with their recorded head/base identities and live origin bases.\n' \
    "$(jq '.pull_requests | length' "$TMP_DIR/pr-baseline.json")"
}

TMP_DIR="$(mktemp -d)"
trap cleanup EXIT
if (( CURRENT_CONTRACT_MODE && APPLY )) && [[ "$COMMAND" == local ]]; then
  verify_local_admission admission
fi
if (( CURRENT_CONTRACT_MODE )) && [[ "$COMMAND" != verify-prs && "$COMMAND" != verify-allowlist ]]; then
  verify_current_contract before
fi
if (( APPLY )); then
  case "$COMMAND" in
    local|remote|tracking|safety-publish) acquire_lock ;;
    *) fail "apply_not_valid_for_${COMMAND}" ;;
  esac
fi
case "$COMMAND" in
  capture-local) capture_local ;;
  capture-origin) capture_origin ;;
  capture-prs) capture_prs ;;
  capture-readiness) capture_readiness ;;
  verify-readiness)
    READINESS_COMMIT="${READINESS_COMMIT:-$(git -C "$REPO" rev-parse --verify HEAD)}"
    verify_readiness "$TMP_DIR/readiness.json"
    printf 'PASS: committed D-01 readiness is valid at %s.\n' "$READINESS_COMMIT"
    ;;
  verify-snapshot)
    (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_snapshot'
    load_snapshot
    verify_readiness "$TMP_DIR/readiness.json"
    load_safety_list
    validate_allowlist_file "$TMP_DIR/safety-list.tsv" safety-publish >/dev/null
    if [[ -n "$ORIGIN_COMMIT" ]]; then
      safe_repo_path "$ORIGIN_PATH"
      read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$TMP_DIR/origin-snapshot.tsv" origin
      ORIGIN_ROWS="$(validate_snapshot_file "$TMP_DIR/origin-snapshot.tsv" yes)"
      printf 'PASS: committed local/origin snapshots %s/%s contain %s/%s refs; all direct and peeled objects and D-01 readiness are valid.\n' \
        "$SNAPSHOT_COMMIT" "$ORIGIN_COMMIT" "$SNAPSHOT_ROWS" "$ORIGIN_ROWS"
    else
      printf 'PASS: committed snapshot %s contains %s refs; all direct and peeled objects and D-01 readiness are valid.\n' "$SNAPSHOT_COMMIT" "$SNAPSHOT_ROWS"
    fi
    ;;
  verify-allowlist) verify_allowlist ;;
  preflight-origin-access) preflight_origin_access ;;
  safety-publish) run_safety_publish ;;
  verify-safety)
    (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_safety'
    verify_safety
    ;;
  local) run_local_pass ;;
  remote) run_remote_pass ;;
  tracking) run_tracking_pass ;;
  verify-local)
    (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_local'
    verify_local_set
    ;;
  verify-remote)
    (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_remote'
    verify_remote_set
    ;;
  verify-prs) verify_prs ;;
  verify-objects)
    (( APPLY == 0 )) || fail 'apply_not_valid_for_verify_objects'
    load_snapshot
    if [[ -n "$ORIGIN_COMMIT" ]]; then
      safe_repo_path "$ORIGIN_PATH"
      read_committed_file "$ORIGIN_COMMIT" "$ORIGIN_PATH" "$TMP_DIR/origin-snapshot.tsv" origin
      ORIGIN_ROWS="$(validate_snapshot_file "$TMP_DIR/origin-snapshot.tsv" yes)"
      printf 'PASS: all direct and peeled local and origin snapshot objects remain readable (local=%s origin=%s).\n' "$SNAPSHOT_ROWS" "$ORIGIN_ROWS"
    else
      printf 'PASS: all direct and peeled objects from committed snapshot %s remain readable (%s refs).\n' "$SNAPSHOT_COMMIT" "$SNAPSHOT_ROWS"
    fi
    ;;
  *) usage ;;
esac
