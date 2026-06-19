#!/usr/bin/env bash
# Shared naming/derivation helpers for the Sigra UAT scripts.
#
# Sourced by scripts/uat/up.sh AND scripts/uat/down.sh so the Compose project
# name and Traefik hostnames are derived identically — if up and down disagreed,
# teardown would miss the stack it brought up.
#
# Requires REPO_ROOT to be set by the sourcing script.

# Lowercase, collapse non-[a-z0-9_-] to '-', trim, cap length.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-56
}

# First 8 hex chars of the checkout path hash — disambiguates worktrees/sibling
# checkouts that share a branch name.
repo_path_hash() {
  local hash
  hash="$(printf '%s' "${REPO_ROOT}" | shasum 2>/dev/null | awk '{print substr($1,1,8)}')"
  if [[ -z "${hash}" ]]; then
    hash="$(printf '%s' "${REPO_ROOT}" | cksum | awk '{print $1}')"
  fi
  printf '%s' "${hash}"
}

current_branch() {
  git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'local'
}

# The repo's default branch: origin/HEAD if known, else main/master if they
# exist locally, else "main". (origin/HEAD is frequently unset on local clones,
# so a bare `|| main` fallback isn't enough — an empty pipe still "succeeds".)
default_branch() {
  local db
  db="$(git -C "${REPO_ROOT}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  if [[ -z "${db}" ]]; then
    if git -C "${REPO_ROOT}" show-ref --verify --quiet refs/heads/main; then
      db="main"
    elif git -C "${REPO_ROOT}" show-ref --verify --quiet refs/heads/master; then
      db="master"
    else
      db="main"
    fi
  fi
  printf '%s' "${db}"
}

is_default_branch() {
  [[ "$(current_branch)" == "$(default_branch)" ]]
}

# Compose project name: sigra-uat-<user>-<branch>-<pathhash>. Unique per
# user/branch/checkout so multiple stacks never share containers/networks/volumes.
default_project_name() {
  local branch user slug
  branch="$(current_branch)"
  user="${USER:-$(id -un 2>/dev/null || printf 'dev')}"
  slug="$(slugify "sigra-uat-${user}-${branch}-$(repo_path_hash)")"
  printf '%s' "${slug:-sigra-uat-local}"
}

# Per-checkout Traefik host: sigra-<branchslug>-<hash6>.localhost. Unique by
# construction (the hash6 disambiguates same-branch worktrees and sibling libs),
# so two stacks never claim the same Host() rule (Traefik would silently
# round-robin between them). Always a single valid DNS label.
default_proxy_host() {
  local branchslug hash6 label
  branchslug="$(slugify "$(current_branch)")"
  hash6="$(repo_path_hash | cut -c1-6)"
  label="sigra-${branchslug}-${hash6}"
  # Collapse to one DNS-safe label (no dots), dedupe hyphens, cap ~40 chars, and
  # fall back to the hash alone if the branch slug was empty/invalid.
  label="$(printf '%s' "${label}" | tr '.' '-' | sed -E 's/-+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')"
  if [[ -z "${label}" || "${label}" == "sigra-" ]]; then
    label="sigra-${hash6}"
  fi
  printf '%s.localhost' "${label}"
}

# Friendly stable alias for the primary checkout.
alias_proxy_host() {
  printf 'sigra.localhost'
}
