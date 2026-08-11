#!/usr/bin/env bash
# Source from bounded proof runners that must attest to the exact repository
# inputs they exercised. The receipt itself is the sole permitted difference.

exact_sha_worktree_fail() {
  printf 'exact SHA worktree: %s\n' "$*" >&2
  return 1
}

exact_sha_worktree_assert_clean() {
  local root="$1"
  local evidence_relative_path="$2"
  local tracked_changes untracked_changes

  [[ -d "${root}" ]] || exact_sha_worktree_fail "repository root is not a directory: ${root}"
  [[ "${evidence_relative_path}" != /* ]] || exact_sha_worktree_fail "evidence path must be repository-relative"
  [[ -n "${evidence_relative_path}" ]] || exact_sha_worktree_fail "evidence path is required"

  if ! tracked_changes="$(git -C "${root}" diff --name-only HEAD -- . ":(exclude)${evidence_relative_path}")"; then
    exact_sha_worktree_fail "could not inspect tracked worktree changes"
  fi

  if [[ -n "${tracked_changes}" ]]; then
    printf 'exact SHA worktree: tracked changes outside receipt path:\n%s\n' "${tracked_changes}" >&2
    return 1
  fi

  if ! untracked_changes="$(git -C "${root}" ls-files --others --exclude-standard -- . ":(exclude)${evidence_relative_path}")"; then
    exact_sha_worktree_fail "could not inspect untracked worktree changes"
  fi

  if [[ -n "${untracked_changes}" ]]; then
    printf 'exact SHA worktree: untracked changes outside receipt path:\n%s\n' "${untracked_changes}" >&2
    return 1
  fi
}

bind_clean_worktree_sha() {
  local root="$1"
  local evidence_relative_path="$2"
  local tested_sha current_sha

  if ! tested_sha="$(git -C "${root}" rev-parse --verify HEAD^{commit})"; then
    exact_sha_worktree_fail "could not resolve HEAD"
  fi

  [[ "${tested_sha}" =~ ^[0-9a-f]{40}$ ]] || exact_sha_worktree_fail "HEAD is not a 40-hex commit SHA"
  exact_sha_worktree_assert_clean "${root}" "${evidence_relative_path}" || return 1

  if ! current_sha="$(git -C "${root}" rev-parse --verify HEAD^{commit})"; then
    exact_sha_worktree_fail "could not re-resolve HEAD"
  fi

  [[ "${current_sha}" == "${tested_sha}" ]] || exact_sha_worktree_fail "HEAD changed while binding proof inputs"
  printf '%s\n' "${tested_sha}"
}

assert_same_clean_worktree_sha() {
  local root="$1"
  local evidence_relative_path="$2"
  local expected_sha="$3"
  local current_sha

  [[ "${expected_sha}" =~ ^[0-9a-f]{40}$ ]] || exact_sha_worktree_fail "expected SHA is not a 40-hex commit SHA"
  exact_sha_worktree_assert_clean "${root}" "${evidence_relative_path}" || return 1

  if ! current_sha="$(git -C "${root}" rev-parse --verify HEAD^{commit})"; then
    exact_sha_worktree_fail "could not resolve HEAD during receipt sealing"
  fi

  [[ "${current_sha}" == "${expected_sha}" ]] || exact_sha_worktree_fail "HEAD changed during proof execution"
}
