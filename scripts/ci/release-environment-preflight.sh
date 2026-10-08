#!/usr/bin/env bash
# Fail-closed deployment-policy check for the release credential environments.
set -euo pipefail

REPOSITORY=""
POLICY_DIR=""
RELEASE_TOKEN_PRESENT=""
HEX_DRY_RUN_KEY_PRESENT=""
HEX_PUBLISH_KEY_PRESENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository) REPOSITORY="$2"; shift 2;;
    --policy-dir) POLICY_DIR="$2"; shift 2;;
    --require-release-token) RELEASE_TOKEN_PRESENT="$2"; shift 2;;
    --require-hex-dry-run-key) HEX_DRY_RUN_KEY_PRESENT="$2"; shift 2;;
    --require-hex-publish-key) HEX_PUBLISH_KEY_PRESENT="$2"; shift 2;;
    -h|--help)
      echo "usage: release-environment-preflight.sh --repository owner/name [--policy-dir fixture-dir] [--require-release-token true|false] [--require-hex-dry-run-key true|false] [--require-hex-publish-key true|false]"
      exit 0
      ;;
    *) echo "release-environment-preflight: FAIL: unknown argument: $1" >&2; exit 2;;
  esac
done

fail() { echo "release-environment-preflight: FAIL: $*" >&2; exit 1; }

[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "a valid repository owner/name is required"
if [[ -z "$POLICY_DIR" ]]; then
  command -v gh >/dev/null 2>&1 || fail "gh CLI is required for live environment policy checks"
  gh auth status --hostname github.com >/dev/null 2>&1 || fail "authenticated gh access is required for live environment policy checks"
fi

check_required_secret_name() {
  local label="$1"
  local present="$2"
  case "$present" in
    "") ;;
    true) ;;
    false) fail "required environment secret is missing: ${label}" ;;
    *) fail "required environment secret presence must be a boolean: ${label}" ;;
  esac
}

check_required_secret_name RELEASE_PLEASE_TOKEN "$RELEASE_TOKEN_PRESENT"
check_required_secret_name HEX_DRY_RUN_API_KEY "$HEX_DRY_RUN_KEY_PRESENT"
check_required_secret_name HEX_API_KEY "$HEX_PUBLISH_KEY_PRESENT"

check_environment_policy() {
  local environment="$1"
  local environment_json="$2"
  local policies_json="$3"

  jq -e --arg name "$environment" '
    type == "object"
    and .name == $name
    and .can_admins_bypass == false
    and (.deployment_branch_policy | type == "object")
    and .deployment_branch_policy.protected_branches == false
    and .deployment_branch_policy.custom_branch_policies == true
  ' "$environment_json" >/dev/null 2>&1 || fail "${environment} is missing or does not use a selected custom-branch policy"

  jq -e '
    type == "object"
    and .total_count == 1
    and (.branch_policies | type == "array" and length == 1)
    and .branch_policies[0].type == "branch"
    and .branch_policies[0].name == "main"
  ' "$policies_json" >/dev/null 2>&1 || fail "${environment} must allow exactly the main branch"

  echo "${environment}: main"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

for environment in release-automation hex-publish; do
  environment_json="$WORK_DIR/${environment}-environment.json"
  policies_json="$WORK_DIR/${environment}-policies.json"

  if [[ -n "$POLICY_DIR" ]]; then
    [[ -f "$POLICY_DIR/$environment/environment.json" ]] || fail "${environment} environment response is missing"
    [[ -f "$POLICY_DIR/$environment/branch-policies.json" ]] || fail "${environment} branch-policy response is missing"
    cp "$POLICY_DIR/$environment/environment.json" "$environment_json"
    cp "$POLICY_DIR/$environment/branch-policies.json" "$policies_json"
  else
    if ! gh api "repos/${REPOSITORY}/environments/${environment}" > "$environment_json" 2>/dev/null; then
      fail "could not read ${environment} environment settings"
    fi
    if ! gh api "repos/${REPOSITORY}/environments/${environment}/deployment-branch-policies" \
      > "$policies_json" 2>/dev/null; then
      fail "could not read ${environment} deployment branch policies"
    fi
  fi

  check_environment_policy "$environment" "$environment_json" "$policies_json"
done

echo "release-environment-preflight: PASS"
