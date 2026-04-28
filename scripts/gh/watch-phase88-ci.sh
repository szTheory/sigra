#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/gh/watch-phase88-ci.sh [options]

Poll GitHub Actions for a target commit SHA, wait for the CI workflow to finish,
verify the Phase 87/88 jobs succeeded, then refresh the local evidence READMEs
with the real Actions run URL.

Options:
  --sha <sha>         Target commit SHA. Defaults to current HEAD.
  --repo <owner/repo> GitHub repository. Defaults to gh repo view nameWithOwner.
  --interval <secs>   Poll interval in seconds. Default: 60.
  --once              Check once and exit instead of polling.
  --no-refresh        Do not regenerate evidence after a successful run.
  --help              Show this help.

Behavior:
  - Watches the GitHub Actions workflow named "CI".
  - Requires these jobs to succeed:
      * Install smoke (fresh phx.new + sigra.install)
      * OAuth E2E Playwright (mock issuer)
      * MFA backup-code rotation E2E
  - On success, runs:
      mix sigra.uat.report --phase=oauth-gen
      mix sigra.uat.report --phase=oauth-google
      mix sigra.uat.report --phase=oauth-link
      mix sigra.uat.report --phase=oauth-email-match
      mix sigra.uat.report --phase=mfa-backup-rotation
      mix sigra.uat.report --phase=getting-started
    with SIGRA_CI_RUN_URL pointing at the green run.
EOF
}

TARGET_SHA=""
REPO=""
INTERVAL=60
ONCE=false
REFRESH=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sha)
      TARGET_SHA="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --interval)
      INTERVAL="${2:-}"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    --no-refresh)
      REFRESH=false
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ -z "$TARGET_SHA" ]]; then
  TARGET_SHA="$(git rev-parse HEAD)"
fi

if [[ -z "$REPO" ]]; then
  REPO="$(GH_PAGER=cat gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

TARGET_SHA="$(git rev-parse "$TARGET_SHA")"
SHORT_SHA="${TARGET_SHA:0:7}"
HEAD_SHA="$(git rev-parse HEAD)"

required_jobs=(
  "Install smoke (fresh phx.new + sigra.install)"
  "OAuth E2E Playwright (mock issuer)"
  "MFA backup-code rotation E2E"
)

phases=(
  "oauth-gen"
  "oauth-google"
  "oauth-link"
  "oauth-email-match"
  "mfa-backup-rotation"
  "getting-started"
)

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

refresh_evidence() {
  local run_url="$1"

  if [[ "$HEAD_SHA" != "$TARGET_SHA" ]]; then
    log "Refusing to refresh evidence: HEAD ${HEAD_SHA:0:7} != target $SHORT_SHA"
    log "Push or checkout the target SHA locally, then rerun without --no-refresh if needed."
    return 4
  fi

  log "Refreshing local evidence with SIGRA_CI_RUN_URL=$run_url"

  for phase in "${phases[@]}"; do
    log "mix sigra.uat.report --phase=$phase"
    SIGRA_CI_RUN_URL="$run_url" MIX_ENV=test mix sigra.uat.report --phase="$phase"
  done

  log "Verifying refreshed evidence bundles"
  for phase in "${phases[@]}"; do
    SIGRA_CI_RUN_URL="$run_url" MIX_ENV=test mix sigra.uat.report --phase="$phase" --check
  done
}

while true; do
  log "Checking CI runs for $REPO @ $SHORT_SHA"

  run_json="$(GH_PAGER=cat gh run list \
    --repo "$REPO" \
    --workflow "CI" \
    --commit "$TARGET_SHA" \
    --limit 20 \
    --json databaseId,status,conclusion,url,workflowName,headSha,createdAt 2>/dev/null || true)"

  run_count="$(printf '%s' "$run_json" | jq 'length')"

  if [[ "$run_count" -eq 0 ]]; then
    log "No CI run found yet for $SHORT_SHA"
    if [[ "$ONCE" == true ]]; then
      exit 3
    fi
    sleep "$INTERVAL"
    continue
  fi

  run_id="$(printf '%s' "$run_json" | jq -r '.[0].databaseId')"
  run_status="$(printf '%s' "$run_json" | jq -r '.[0].status')"
  run_conclusion="$(printf '%s' "$run_json" | jq -r '.[0].conclusion // ""')"
  run_url="$(printf '%s' "$run_json" | jq -r '.[0].url')"

  log "Found run $run_id: status=$run_status conclusion=${run_conclusion:-pending} url=$run_url"

  if [[ "$run_status" != "completed" ]]; then
    if [[ "$ONCE" == true ]]; then
      exit 4
    fi
    sleep "$INTERVAL"
    continue
  fi

  if [[ "$run_conclusion" != "success" ]]; then
    log "CI run $run_id completed with conclusion=$run_conclusion"
    exit 5
  fi

  jobs_json="$(GH_PAGER=cat gh run view "$run_id" \
    --repo "$REPO" \
    --json jobs,url,status,conclusion,headSha)"

  missing=()
  failed=()

  for job in "${required_jobs[@]}"; do
    job_status="$(printf '%s' "$jobs_json" | jq -r --arg name "$job" '.jobs[] | select(.name == $name) | .status' | head -1)"
    job_conclusion="$(printf '%s' "$jobs_json" | jq -r --arg name "$job" '.jobs[] | select(.name == $name) | .conclusion' | head -1)"

    if [[ -z "$job_status" ]]; then
      missing+=("$job")
      continue
    fi

    if [[ "$job_status" != "completed" || "$job_conclusion" != "success" ]]; then
      failed+=("$job [$job_status/$job_conclusion]")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log "Run $run_id is missing required jobs:"
    printf '  - %s\n' "${missing[@]}"
    exit 6
  fi

  if [[ "${#failed[@]}" -gt 0 ]]; then
    log "Run $run_id has incomplete or failed required jobs:"
    printf '  - %s\n' "${failed[@]}"
    if [[ "$ONCE" == true ]]; then
      exit 7
    fi
    sleep "$INTERVAL"
    continue
  fi

  log "Required CI jobs succeeded for $SHORT_SHA"

  if [[ "$REFRESH" == true ]]; then
    refresh_evidence "$run_url"
  fi

  log "Watcher complete"
  exit 0
done
