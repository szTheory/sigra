#!/usr/bin/env bash
# Shared branch/worktree ref-mutation coordinator for all linked worktrees.
set -euo pipefail

SIGRA_COORDINATOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGRA_COORDINATOR_HOOK_SOURCE="${SIGRA_COORDINATOR_SCRIPT_DIR}/repo-mutation-reference-transaction"
SIGRA_COORDINATOR_DIR_NAME="sigra-branch-worktree-coordinator"
SIGRA_COORDINATOR_ERROR=""
SIGRA_COORDINATOR_HELD=0
SIGRA_COORDINATOR_GATE_HELD=0
SIGRA_COORDINATOR_CAPABILITY_GIT_PATH=""
readonly SIGRA_COORDINATOR_GIT_PATH="/usr/bin/git"
readonly SIGRA_COORDINATOR_GIT_SHA256="b8763cf250e607a778bb4603cecb5b90338814d0a3dfcba0d57b1de242f610e9"
readonly SIGRA_COORDINATOR_GIT_VERSION_PREFIX="git version 2.50.1"
SIGRA_COORDINATOR_GIT_PIN_VERIFIED=0

sigra_coordinator_pin_git() {
  [[ "$SIGRA_COORDINATOR_GIT_PIN_VERIFIED" == 1 ]] && return 0
  [[ "$SIGRA_COORDINATOR_GIT_PATH" == "/usr/bin/git" && -x "$SIGRA_COORDINATOR_GIT_PATH" ]] \
    || { sigra_coordinator_set_error 'pinned_git_path_unavailable'; return 1; }
  local resolved_dir version digest
  resolved_dir="$(cd "$(dirname "$SIGRA_COORDINATOR_GIT_PATH")" 2>/dev/null && pwd -P)" \
    || { sigra_coordinator_set_error 'pinned_git_path_unresolvable'; return 1; }
  [[ "${resolved_dir}/$(basename "$SIGRA_COORDINATOR_GIT_PATH")" == "$SIGRA_COORDINATOR_GIT_PATH" ]] \
    || { sigra_coordinator_set_error 'pinned_git_absolute_path_mismatch'; return 1; }
  version="$("$SIGRA_COORDINATOR_GIT_PATH" --version 2>/dev/null)" \
    || { sigra_coordinator_set_error 'pinned_git_version_unavailable'; return 1; }
  [[ "$version" == "$SIGRA_COORDINATOR_GIT_VERSION_PREFIX" || "$version" == "$SIGRA_COORDINATOR_GIT_VERSION_PREFIX "* ]] \
    || { sigra_coordinator_set_error "pinned_git_version_mismatch: ${version}"; return 1; }
  digest="$(/usr/bin/shasum -a 256 "$SIGRA_COORDINATOR_GIT_PATH" 2>/dev/null | awk '{print $1}')" \
    || { sigra_coordinator_set_error 'pinned_git_sha256_unavailable'; return 1; }
  [[ "$digest" == "$SIGRA_COORDINATOR_GIT_SHA256" ]] \
    || { sigra_coordinator_set_error 'pinned_git_sha256_mismatch'; return 1; }
  SIGRA_COORDINATOR_GIT_PIN_VERIFIED=1
}

# Every Git call in the operator/coordinator shell runs through this function;
# it never resolves `git` through the ambient PATH.
git() {
  sigra_coordinator_pin_git || return 126
  "$SIGRA_COORDINATOR_GIT_PATH" "$@"
}

sigra_coordinator_set_error() {
  SIGRA_COORDINATOR_ERROR="$1"
  return 1
}

sigra_coordinator_resolve() {
  local requested_repo="$1" common_dir
  [[ -n "$requested_repo" ]] || sigra_coordinator_set_error 'repository_path_required' || return 1
  sigra_coordinator_pin_git || return 1
  SIGRA_COORDINATOR_REPO="$(git -C "$requested_repo" rev-parse --show-toplevel 2>/dev/null)" \
    || sigra_coordinator_set_error "not_a_git_repository: ${requested_repo}" || return 1
  common_dir="$(git -C "$SIGRA_COORDINATOR_REPO" rev-parse --git-common-dir 2>/dev/null)" \
    || sigra_coordinator_set_error 'git_common_directory_unavailable' || return 1
  if [[ "$common_dir" != /* ]]; then common_dir="${SIGRA_COORDINATOR_REPO}/${common_dir}"; fi
  SIGRA_COORDINATOR_COMMON_DIR="$(cd "$common_dir" 2>/dev/null && pwd -P)" \
    || sigra_coordinator_set_error 'git_common_directory_unresolvable' || return 1
  SIGRA_COORDINATOR_ROOT="${SIGRA_COORDINATOR_COMMON_DIR}/${SIGRA_COORDINATOR_DIR_NAME}"
  SIGRA_COORDINATOR_LOCK_DIR="${SIGRA_COORDINATOR_ROOT}/lock"
  SIGRA_COORDINATOR_GATE_DIR="${SIGRA_COORDINATOR_ROOT}/gate"
  SIGRA_COORDINATOR_TRANSACTIONS_DIR="${SIGRA_COORDINATOR_ROOT}/transactions"
  SIGRA_COORDINATOR_HOOKS_DIR="${SIGRA_COORDINATOR_ROOT}/hooks"
  SIGRA_COORDINATOR_HOOKS_MANIFEST="${SIGRA_COORDINATOR_ROOT}/hooks.manifest.tsv"
}

sigra_coordinator_probe_symbolic_head_impl() (
  set -euo pipefail
  local hook_source="$1" probe_dir main peer common_dir coordinator_root hooks_dir lock_dir token before after output git_path
  sigra_coordinator_pin_git || { printf 'PROBE_FAILED: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; exit 2; }
  git_path="$SIGRA_COORDINATOR_GIT_PATH"
  [[ -f "$hook_source" && -x "$hook_source" ]] || { printf 'PROBE_FAILED: coordinator_hook_source_missing_or_not_executable\n' >&2; exit 2; }
  probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/sigra-coordinator-capability.XXXXXX")" \
    || { printf 'PROBE_FAILED: capability_fixture_create_failed\n' >&2; exit 2; }
  probe_cleanup_dir="$probe_dir"
  trap 'rm -rf "$probe_cleanup_dir"' EXIT
  main="${probe_dir}/main"
  peer="${probe_dir}/peer"
  git init -q --initial-branch=main "$main" || { printf 'PROBE_FAILED: fixture_repo_init_failed\n' >&2; exit 2; }
  git -C "$main" config user.name 'Sigra Coordinator Capability Probe'
  git -C "$main" config user.email 'sigra-coordinator-probe@example.invalid'
  git -C "$main" config gc.auto 0
  git -C "$main" config maintenance.auto false
  printf 'symbolic HEAD capability probe\n' > "${main}/probe.txt"
  git -C "$main" add probe.txt
  git -C "$main" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: symbolic HEAD capability probe'
  git -C "$main" worktree add -q -b probe-peer "$peer" main # DISPOSABLE_PROBE_MUTATION
  common_dir="$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)" \
    || { printf 'PROBE_FAILED: fixture_common_directory_unavailable\n' >&2; exit 2; }
  coordinator_root="${common_dir}/${SIGRA_COORDINATOR_DIR_NAME}"
  hooks_dir="${coordinator_root}/hooks"
  lock_dir="${coordinator_root}/lock"
  mkdir -p "${hooks_dir}" "${coordinator_root}/transactions" "$lock_dir"
  cp "$hook_source" "${hooks_dir}/reference-transaction"
  chmod 755 "${hooks_dir}/reference-transaction"
  git -C "$main" config --local core.hooksPath "$hooks_dir"
  token='0123456789abcdef0123456789abcdef0123456789abcdef'
  jq -n --arg token "$token" --arg pid "$$" --arg host capability-probe \
    '{schema_version:1,token:$token,pid:$pid,host:$host,operation:"symbolic-head-capability-probe",repo:"fixture",common_dir:"fixture",created_at:"probe"}' \
    > "${lock_dir}/owner.json" || { printf 'PROBE_FAILED: fixture_owner_record_write_failed\n' >&2; exit 2; }
  before="$(git -C "$peer" symbolic-ref -q HEAD)" \
    || { printf 'PROBE_FAILED: fixture_linked_head_read_failed\n' >&2; exit 2; }
  output="${probe_dir}/symbolic-head.out"
  if env -u SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN "$git_path" -C "$peer" symbolic-ref HEAD refs/heads/main >"$output" 2>&1; then
    after="$(git -C "$peer" symbolic-ref -q HEAD 2>/dev/null || true)"
    if [[ "$after" != "$before" ]]; then
      printf 'UNSUPPORTED: coordinator_symbolic_head_hook_unsupported git=%s version=%s\n' \
        "$git_path" "$(git --version 2>/dev/null || printf unknown)" >&2
      exit 1
    fi
    printf 'PROBE_FAILED: symbolic_head_command_succeeded_without_changing_target\n' >&2
    exit 2
  fi
  after="$(git -C "$peer" symbolic-ref -q HEAD 2>/dev/null || true)"
  if [[ "$after" == "$before" ]] \
    && grep -Fq 'branch_or_worktree_ref_change_during_coordinator_window' "$output"; then
    printf 'SUPPORTED: coordinator symbolic HEAD hook enforced git=%s version=%s\n' \
      "$git_path" "$(git --version 2>/dev/null || printf unknown)"
    exit 0
  fi
  printf 'PROBE_FAILED: symbolic_head_rejection_not_proven before=%s after=%s output=%s\n' \
    "$before" "$after" "$(tr '\n' ' ' < "$output")" >&2
  exit 2
)

sigra_coordinator_probe_symbolic_head() {
  local git_path probe_output
  sigra_coordinator_pin_git || return 1
  git_path="$SIGRA_COORDINATOR_GIT_PATH"
  if [[ "$SIGRA_COORDINATOR_CAPABILITY_GIT_PATH" == "$git_path" ]]; then return 0; fi
  if probe_output="$(sigra_coordinator_probe_symbolic_head_impl "$SIGRA_COORDINATOR_HOOK_SOURCE" 2>&1)"; then
    SIGRA_COORDINATOR_CAPABILITY_GIT_PATH="$git_path"
    printf '%s\n' "$probe_output"
    return 0
  fi
  if [[ "$probe_output" == *'coordinator_symbolic_head_hook_unsupported'* ]]; then
    sigra_coordinator_set_error 'coordinator_symbolic_head_hook_unsupported'
  else
    sigra_coordinator_set_error "coordinator_symbolic_head_probe_failed: ${probe_output//$'\n'/ }"
  fi
  return 1
}

sigra_coordinator_gate_enter() {
  if ! mkdir "$SIGRA_COORDINATOR_GATE_DIR" 2>/dev/null; then
    sigra_coordinator_set_error 'coordinator_admission_gate_busy_or_stale'
    return 1
  fi
  SIGRA_COORDINATOR_GATE_HELD=1
  if ! printf '%s\n' "$$" > "${SIGRA_COORDINATOR_GATE_DIR}/pid"; then
    rmdir "$SIGRA_COORDINATOR_GATE_DIR" 2>/dev/null || true
    SIGRA_COORDINATOR_GATE_HELD=0
    sigra_coordinator_set_error 'coordinator_gate_owner_write_failed'
    return 1
  fi
}

sigra_coordinator_gate_leave() {
  [[ "$SIGRA_COORDINATOR_GATE_HELD" == 1 ]] || return 0
  rm -f "${SIGRA_COORDINATOR_GATE_DIR}/pid" || {
    sigra_coordinator_set_error 'coordinator_gate_owner_remove_failed'
    return 1
  }
  rmdir "$SIGRA_COORDINATOR_GATE_DIR" 2>/dev/null || {
    sigra_coordinator_set_error 'coordinator_gate_release_failed'
    return 1
  }
  SIGRA_COORDINATOR_GATE_HELD=0
}

sigra_coordinator_transaction_count() {
  local path count=0
  for path in "${SIGRA_COORDINATOR_TRANSACTIONS_DIR}"/txn-*; do
    [[ -d "$path" ]] || continue
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

sigra_coordinator_verify() {
  local requested_repo="$1" effective_hooks worktree_path common_dir worktree_record hook_path hook_name hook_target expected_target
  sigra_coordinator_resolve "$requested_repo" || return 1
  sigra_coordinator_probe_symbolic_head || return 1
  [[ -d "$SIGRA_COORDINATOR_ROOT" && -d "$SIGRA_COORDINATOR_TRANSACTIONS_DIR" ]] \
    || sigra_coordinator_set_error 'coordinator_not_installed' || return 1
  [[ -f "$SIGRA_COORDINATOR_HOOK_SOURCE" && -x "$SIGRA_COORDINATOR_HOOK_SOURCE" ]] \
    || sigra_coordinator_set_error 'coordinator_hook_source_missing_or_not_executable' || return 1
  effective_hooks="$(git -C "$SIGRA_COORDINATOR_REPO" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" \
    || sigra_coordinator_set_error 'effective_hooks_path_unavailable' || return 1
  [[ "$effective_hooks" == "$SIGRA_COORDINATOR_HOOKS_DIR" ]] \
    || sigra_coordinator_set_error "coordinator_hooks_path_mismatch: expected=${SIGRA_COORDINATOR_HOOKS_DIR} actual=${effective_hooks}" || return 1
  [[ -f "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" \
    && -x "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" ]] \
    || sigra_coordinator_set_error 'coordinator_reference_hook_missing_or_not_executable' || return 1
  cmp -s "$SIGRA_COORDINATOR_HOOK_SOURCE" "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" \
    || sigra_coordinator_set_error 'coordinator_reference_hook_source_mismatch' || return 1
  [[ -s "$SIGRA_COORDINATOR_HOOKS_MANIFEST" ]] \
    || sigra_coordinator_set_error 'coordinator_hooks_manifest_missing' || return 1
  while IFS=$'\t' read -r hook_name hook_target; do
    [[ -n "$hook_name" && -n "$hook_target" ]] \
      || sigra_coordinator_set_error 'coordinator_hooks_manifest_malformed' || return 1
    if [[ "$hook_name" == reference-transaction ]]; then
      hook_path="${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"
      if [[ "$hook_target" == - ]]; then
        [[ ! -e "$hook_path" && ! -L "$hook_path" ]] \
          || sigra_coordinator_set_error 'unexpected_previous_reference_transaction_hook' || return 1
      else
        [[ -L "$hook_path" && -x "$hook_path" ]] \
          || sigra_coordinator_set_error 'previous_reference_transaction_hook_missing_or_not_executable' || return 1
        expected_target="$(readlink "$hook_path" 2>/dev/null)" \
          || sigra_coordinator_set_error 'previous_reference_transaction_hook_unreadable' || return 1
        [[ "$expected_target" == "$hook_target" ]] \
          || sigra_coordinator_set_error 'previous_reference_transaction_hook_target_mismatch' || return 1
      fi
    else
      hook_path="${SIGRA_COORDINATOR_HOOKS_DIR}/${hook_name}"
      [[ -L "$hook_path" && -x "$hook_path" ]] \
        || sigra_coordinator_set_error "preserved_hook_missing_or_not_executable: ${hook_name}" || return 1
      expected_target="$(readlink "$hook_path" 2>/dev/null)" \
        || sigra_coordinator_set_error "preserved_hook_unreadable: ${hook_name}" || return 1
      [[ "$expected_target" == "$hook_target" ]] \
        || sigra_coordinator_set_error "preserved_hook_target_mismatch: ${hook_name}" || return 1
    fi
  done < "$SIGRA_COORDINATOR_HOOKS_MANIFEST"
  for hook_path in "${SIGRA_COORDINATOR_HOOKS_DIR}"/*; do
    [[ -e "$hook_path" || -L "$hook_path" ]] || continue
    hook_name="${hook_path##*/}"
    [[ "$hook_name" == reference-transaction ]] && continue
    awk -F '\t' -v name="$hook_name" '$1 == name { found=1 } END { exit !found }' "$SIGRA_COORDINATOR_HOOKS_MANIFEST" \
      || sigra_coordinator_set_error "unexpected_installed_hook: ${hook_name}" || return 1
  done

  while IFS= read -r -d '' worktree_record; do
    [[ "$worktree_record" == worktree\ * ]] || continue
    worktree_path="${worktree_record#worktree }"
    [[ -d "$worktree_path" ]] || sigra_coordinator_set_error "registered_worktree_unavailable: ${worktree_path}" || return 1
    common_dir="$(git -C "$worktree_path" rev-parse --git-common-dir 2>/dev/null)" \
      || sigra_coordinator_set_error "registered_worktree_git_unavailable: ${worktree_path}" || return 1
    if [[ "$common_dir" != /* ]]; then common_dir="${worktree_path}/${common_dir}"; fi
    common_dir="$(cd "$common_dir" 2>/dev/null && pwd -P)" \
      || sigra_coordinator_set_error "registered_worktree_common_dir_unavailable: ${worktree_path}" || return 1
    [[ "$common_dir" == "$SIGRA_COORDINATOR_COMMON_DIR" ]] \
      || sigra_coordinator_set_error "registered_worktree_common_dir_mismatch: ${worktree_path}" || return 1
    effective_hooks="$(git -C "$worktree_path" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" \
      || sigra_coordinator_set_error "registered_worktree_hooks_unavailable: ${worktree_path}" || return 1
    [[ "$effective_hooks" == "$SIGRA_COORDINATOR_HOOKS_DIR" ]] \
      || sigra_coordinator_set_error "registered_worktree_hooks_mismatch: ${worktree_path}" || return 1
  done < <(git -C "$SIGRA_COORDINATOR_REPO" worktree list --porcelain -z 2>/dev/null) \
    || { sigra_coordinator_set_error 'worktree_registry_unavailable'; return 1; }
}

sigra_coordinator_install() {
  local requested_repo="$1" old_hooks next_hooks hook hook_name token previous_reference_hook manifest_tmp
  local worktree_record worktree_path worktree_hooks worktree_config_enabled
  sigra_coordinator_resolve "$requested_repo" || return 1
  [[ -f "$SIGRA_COORDINATOR_HOOK_SOURCE" && -x "$SIGRA_COORDINATOR_HOOK_SOURCE" ]] \
    || sigra_coordinator_set_error 'coordinator_hook_source_missing_or_not_executable' || return 1
  sigra_coordinator_probe_symbolic_head || return 1
  mkdir -p "$SIGRA_COORDINATOR_TRANSACTIONS_DIR" || sigra_coordinator_set_error 'coordinator_state_directory_create_failed' || return 1
  if [[ -d "$SIGRA_COORDINATOR_LOCK_DIR" || -d "$SIGRA_COORDINATOR_GATE_DIR" ]] \
    || [[ "$(sigra_coordinator_transaction_count)" != 0 ]]; then
    sigra_coordinator_set_error 'cannot_install_while_coordinator_or_ref_transaction_is_active'
    return 1
  fi
  old_hooks="$(git -C "$SIGRA_COORDINATOR_REPO" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" \
    || sigra_coordinator_set_error 'existing_hooks_path_unavailable' || return 1
  if [[ "$old_hooks" == "$SIGRA_COORDINATOR_HOOKS_DIR" ]]; then
    if sigra_coordinator_verify "$SIGRA_COORDINATOR_REPO"; then
      printf 'PASS: shared branch/worktree coordinator is installed and verified.\n'
      return 0
    fi
    if [[ -d "$SIGRA_COORDINATOR_LOCK_DIR" || -d "$SIGRA_COORDINATOR_GATE_DIR" ]] \
      || [[ "$(sigra_coordinator_transaction_count)" != 0 ]]; then
      return 1
    fi
    cmp -s "$SIGRA_COORDINATOR_HOOK_SOURCE" "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" \
      || cp "$SIGRA_COORDINATOR_HOOK_SOURCE" "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" \
      || { sigra_coordinator_set_error 'coordinator_hook_refresh_failed'; return 1; }
    chmod 755 "${SIGRA_COORDINATOR_HOOKS_DIR}/reference-transaction" \
      || { sigra_coordinator_set_error 'coordinator_hook_mode_update_failed'; return 1; }
    sigra_coordinator_verify "$SIGRA_COORDINATOR_REPO" || return 1
    printf 'PASS: shared branch/worktree coordinator hook refreshed and verified.\n'
    return 0
  fi
  worktree_config_enabled="$(git -C "$SIGRA_COORDINATOR_REPO" config --bool --get extensions.worktreeConfig 2>/dev/null || true)"
  while IFS= read -r -d '' worktree_record; do
    [[ "$worktree_record" == worktree\ * ]] || continue
    worktree_path="${worktree_record#worktree }"
    [[ -d "$worktree_path" ]] \
      || { sigra_coordinator_set_error "registered_worktree_unavailable: ${worktree_path}"; return 1; }
    worktree_hooks="$(git -C "$worktree_path" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" \
      || { sigra_coordinator_set_error "registered_worktree_hooks_unavailable: ${worktree_path}"; return 1; }
    [[ "$worktree_hooks" == "$old_hooks" ]] \
      || { sigra_coordinator_set_error "worktree_specific_hooks_path_prevents_install: ${worktree_path}"; return 1; }
    if [[ "$worktree_config_enabled" == true ]] \
      && git -C "$worktree_path" config --worktree --get-all core.hooksPath >/dev/null 2>&1; then
      sigra_coordinator_set_error "worktree_specific_hooks_path_prevents_install: ${worktree_path}"
      return 1
    fi
  done < <(git -C "$SIGRA_COORDINATOR_REPO" worktree list --porcelain -z 2>/dev/null) \
    || { sigra_coordinator_set_error 'worktree_registry_unavailable'; return 1; }
  [[ ! -e "$SIGRA_COORDINATOR_HOOKS_DIR" ]] \
    || sigra_coordinator_set_error 'partial_coordinator_install_requires_manual_reconciliation' || return 1
  [[ ! -e "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction" \
    && ! -L "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction" \
    && ! -e "$SIGRA_COORDINATOR_HOOKS_MANIFEST" ]] \
    || sigra_coordinator_set_error 'partial_coordinator_hook_chain_requires_manual_reconciliation' || return 1

  mkdir -p "$SIGRA_COORDINATOR_ROOT" || sigra_coordinator_set_error 'coordinator_root_create_failed' || return 1
  next_hooks="${SIGRA_COORDINATOR_ROOT}/hooks.next.$$"
  manifest_tmp="${SIGRA_COORDINATOR_ROOT}/hooks.manifest.tsv.tmp.$$"
  mkdir "$next_hooks" || sigra_coordinator_set_error 'coordinator_staging_hooks_create_failed' || return 1
  : > "$manifest_tmp" || { rm -rf "$next_hooks"; sigra_coordinator_set_error 'coordinator_hooks_manifest_create_failed'; return 1; }
  previous_reference_hook="-"
  for hook in "${old_hooks}"/*; do
    [[ -f "$hook" && -x "$hook" ]] || continue
    hook_name="${hook##*/}"
    if [[ "$hook_name" == reference-transaction ]]; then
      [[ "$hook" != *$'\t'* && "$hook" != *$'\n'* ]] \
        || { rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'prior_reference_hook_path_unsafe'; return 1; }
      ln -s "$hook" "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction" \
        || { rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'prior_reference_hook_chain_failed'; return 1; }
      previous_reference_hook="$hook"
    else
      ln -s "$hook" "${next_hooks}/${hook_name}" \
        || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error "existing_hook_chain_failed: ${hook_name}"; return 1; }
      [[ "$hook_name" != *$'\t'* && "$hook_name" != *$'\n'* && "$hook" != *$'\t'* && "$hook" != *$'\n'* ]] \
        || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'existing_hook_path_unsafe'; return 1; }
      printf '%s\t%s\n' "$hook_name" "$hook" >> "$manifest_tmp" \
        || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'coordinator_hooks_manifest_write_failed'; return 1; }
    fi
  done
  printf 'reference-transaction\t%s\n' "$previous_reference_hook" >> "$manifest_tmp" \
    || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'coordinator_hooks_manifest_write_failed'; return 1; }
  cp "$SIGRA_COORDINATOR_HOOK_SOURCE" "${next_hooks}/reference-transaction" \
    || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'coordinator_hook_copy_failed'; return 1; }
  chmod 755 "${next_hooks}/reference-transaction" \
    || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'coordinator_hook_mode_set_failed'; return 1; }
  mv "$manifest_tmp" "$SIGRA_COORDINATOR_HOOKS_MANIFEST" \
    || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; rm -f "$manifest_tmp"; sigra_coordinator_set_error 'coordinator_hooks_manifest_publish_failed'; return 1; }
  mv "$next_hooks" "$SIGRA_COORDINATOR_HOOKS_DIR" \
    || { rm -f "${SIGRA_COORDINATOR_ROOT}/previous-reference-transaction"; rm -rf "$next_hooks"; sigra_coordinator_set_error 'coordinator_hook_install_rename_failed'; return 1; }
  if ! git -C "$SIGRA_COORDINATOR_REPO" config --local core.hooksPath "$SIGRA_COORDINATOR_HOOKS_DIR"; then
    sigra_coordinator_set_error 'coordinator_hooks_path_config_failed'
    return 1
  fi
  sigra_coordinator_verify "$SIGRA_COORDINATOR_REPO" || return 1
  printf 'PASS: shared branch/worktree coordinator installed and verified for registered worktrees.\n'
}

sigra_coordinator_acquire() {
  local requested_repo="$1" operation="$2" token owner_tmp lease_count
  [[ "$operation" =~ ^[A-Za-z0-9._-]+$ ]] \
    || sigra_coordinator_set_error 'coordinator_operation_label_invalid' || return 1
  sigra_coordinator_verify "$requested_repo" || return 1
  sigra_coordinator_gate_enter || return 1
  if [[ -d "$SIGRA_COORDINATOR_LOCK_DIR" ]]; then
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_busy_or_stale_lock_present'
    return 1
  fi
  lease_count="$(sigra_coordinator_transaction_count)"
  if [[ "$lease_count" != 0 ]]; then
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error "coordinator_ref_transactions_in_flight: ${lease_count}"
    return 1
  fi
  if ! mkdir "$SIGRA_COORDINATOR_LOCK_DIR" 2>/dev/null; then
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_lock_create_failed'
    return 1
  fi
  token="$(od -An -N24 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  if [[ ! "$token" =~ ^[0-9a-f]{48}$ ]]; then
    rmdir "$SIGRA_COORDINATOR_LOCK_DIR" 2>/dev/null || true
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_random_token_unavailable'
    return 1
  fi
  owner_tmp="${SIGRA_COORDINATOR_LOCK_DIR}/owner.json.tmp.$$"
  if ! jq -n \
    --arg token "$token" \
    --arg pid "$$" \
    --arg host "$(hostname 2>/dev/null || printf unknown)" \
    --arg operation "$operation" \
    --arg repo "$SIGRA_COORDINATOR_REPO" \
    --arg common_dir "$SIGRA_COORDINATOR_COMMON_DIR" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{schema_version:1,token:$token,pid:$pid,host:$host,operation:$operation,repo:$repo,common_dir:$common_dir,created_at:$created_at}' \
    > "$owner_tmp"; then
    rm -f "$owner_tmp"
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_owner_record_write_failed'
    return 1
  fi
  if ! mv "$owner_tmp" "${SIGRA_COORDINATOR_LOCK_DIR}/owner.json"; then
    rm -f "$owner_tmp"
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_owner_record_publish_failed'
    return 1
  fi
  if ! sigra_coordinator_gate_leave; then return 1; fi
  SIGRA_COORDINATOR_TOKEN="$token"
  SIGRA_COORDINATOR_OWNER_PID="$$"
  SIGRA_COORDINATOR_HELD=1
  export SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN="$token"
  export SIGRA_BRANCH_WORKTREE_COORDINATOR_ROOT="$SIGRA_COORDINATOR_ROOT"
}

sigra_coordinator_release() {
  local recorded_token recorded_pid
  [[ "$SIGRA_COORDINATOR_HELD" == 1 ]] || return 0
  sigra_coordinator_gate_enter || return 1
  [[ -s "${SIGRA_COORDINATOR_LOCK_DIR}/owner.json" ]] || {
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_owner_record_missing_on_release'
    return 1
  }
  recorded_token="$(jq -r '.token // empty' "${SIGRA_COORDINATOR_LOCK_DIR}/owner.json" 2>/dev/null)" \
    || { sigra_coordinator_gate_leave || true; sigra_coordinator_set_error 'coordinator_owner_record_invalid_on_release'; return 1; }
  recorded_pid="$(jq -r '.pid // empty' "${SIGRA_COORDINATOR_LOCK_DIR}/owner.json" 2>/dev/null)" \
    || { sigra_coordinator_gate_leave || true; sigra_coordinator_set_error 'coordinator_owner_record_invalid_on_release'; return 1; }
  [[ "$recorded_token" == "${SIGRA_COORDINATOR_TOKEN:-}" && "$recorded_pid" == "$$" ]] || {
    sigra_coordinator_gate_leave || true
    sigra_coordinator_set_error 'coordinator_release_owner_mismatch'
    return 1
  }
  rm -f "${SIGRA_COORDINATOR_LOCK_DIR}/owner.json" \
    || { sigra_coordinator_gate_leave || true; sigra_coordinator_set_error 'coordinator_owner_record_remove_failed'; return 1; }
  rmdir "$SIGRA_COORDINATOR_LOCK_DIR" 2>/dev/null \
    || { sigra_coordinator_gate_leave || true; sigra_coordinator_set_error 'coordinator_lock_release_failed'; return 1; }
  if ! sigra_coordinator_gate_leave; then return 1; fi
  SIGRA_COORDINATOR_HELD=0
  unset SIGRA_BRANCH_WORKTREE_COORDINATOR_TOKEN SIGRA_BRANCH_WORKTREE_COORDINATOR_ROOT
  SIGRA_COORDINATOR_TOKEN=""
  SIGRA_COORDINATOR_OWNER_PID=""
}

sigra_coordinator_status() {
  local requested_repo="$1" lock_state transaction_count
  sigra_coordinator_verify "$requested_repo" || return 1
  lock_state=free
  [[ ! -d "$SIGRA_COORDINATOR_LOCK_DIR" ]] || lock_state=held
  transaction_count="$(sigra_coordinator_transaction_count)"
  printf 'coordinator=verified\ncommon_dir=%s\nlock=%s\ntransaction_leases=%s\n' \
    "$SIGRA_COORDINATOR_COMMON_DIR" "$lock_state" "$transaction_count"
}

sigra_coordinator_main() {
  local command_name="$1" requested_repo="" operation=""
  shift
  local -a command=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) [[ $# -ge 2 ]] || { sigra_coordinator_set_error 'repo_argument_missing'; break; }; requested_repo="$2"; shift 2 ;;
      --operation) [[ $# -ge 2 ]] || { sigra_coordinator_set_error 'operation_argument_missing'; break; }; operation="$2"; shift 2 ;;
      --) shift; command=("$@"); break ;;
      *) sigra_coordinator_set_error "unknown_argument: $1"; break ;;
    esac
  done
  if [[ -n "$SIGRA_COORDINATOR_ERROR" ]]; then printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 2; fi
  case "$command_name" in
    install)
      sigra_coordinator_install "$requested_repo" || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      ;;
    verify)
      sigra_coordinator_verify "$requested_repo" || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      printf 'PASS: shared branch/worktree coordinator hook and worktree paths verified.\n'
      ;;
    status)
      sigra_coordinator_status "$requested_repo" || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      ;;
    run)
      [[ -n "$operation" ]] || { printf 'repo-mutation-coordinator: FAIL: operation_label_required\n' >&2; return 2; }
      [[ ${#command[@]} -gt 0 ]] || { printf 'repo-mutation-coordinator: FAIL: command_required\n' >&2; return 2; }
      sigra_coordinator_pin_git || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      [[ "${command[0]}" != git ]] || command[0]="$SIGRA_COORDINATOR_GIT_PATH"
      sigra_coordinator_acquire "$requested_repo" "$operation" || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      trap 'sigra_coordinator_release || printf "repo-mutation-coordinator: FAIL: %s\\n" "$SIGRA_COORDINATOR_ERROR" >&2' EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      set +e
      PATH="/usr/bin:/bin${PATH:+:$PATH}" "${command[@]}"
      local command_status=$?
      set -e
      sigra_coordinator_release || { printf 'repo-mutation-coordinator: FAIL: %s\n' "$SIGRA_COORDINATOR_ERROR" >&2; return 1; }
      trap - EXIT INT TERM
      return "$command_status"
      ;;
    *) printf 'usage: repo-mutation-coordinator.sh <install|verify|status|run> --repo PATH [--operation LABEL -- COMMAND... ]\n' >&2; return 2 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ $# -gt 0 ]] || { printf 'usage: repo-mutation-coordinator.sh <install|verify|status|run> --repo PATH [--operation LABEL -- COMMAND... ]\n' >&2; exit 2; }
  command_name="$1"; shift
  sigra_coordinator_main "$command_name" "$@"
fi
