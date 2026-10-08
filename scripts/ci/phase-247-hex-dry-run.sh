#!/usr/bin/env bash
set -euo pipefail

readonly REVIEWED_BASE="590eb4ed3323db11dd74326cbee00c9c7973e529"
readonly CANDIDATE="563f411bc2659bb9ac1652d552ce58ffb0c876b1"
readonly PR_NUMBER="224"
readonly ALGORITHM="git-diff-raw-v1"
readonly MANIFEST_PATH=".planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json"
readonly ALLOWED_PATHS=$' .github/workflows/phase-247-hex-dry-run.yml\n scripts/ci/phase-247-hex-dry-run.sh\n scripts/ci/phase-247-hex-dry-run.test.sh\n .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json'

die() { printf 'phase-247-hex-dry-run: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }
valid_sha() { [[ "${1:-}" =~ ^[0-9a-f]{40}$ ]]; }
repo_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }

diff_digest() {
  local repo="$1" base="$2" candidate="$3" output="$4"
  valid_sha "$base" && valid_sha "$candidate" || die 'base and candidate must be full lowercase SHA-1 values'
  git -C "$repo" -c core.quotePath=true diff --binary --full-index --no-ext-diff --no-textconv --no-renames --no-color --diff-algorithm=myers --src-prefix=a/ --dst-prefix=b/ "$base" "$candidate" -- >"$output"
  sha256sum "$output" | awk '{print $1}'
}

manifest_write() {
  local repo="$1" base="$2" candidate="$3" dest="$4" tmp digest bytes
  tmp=$(mktemp)
  digest=$(diff_digest "$repo" "$base" "$candidate" "$tmp")
  bytes=$(wc -c <"$tmp" | tr -d ' ')
  rm -f "$tmp"
  printf '{\n  "schema_version": 1,\n  "reviewed_base_sha": "%s",\n  "candidate_sha": "%s",\n  "diff_algorithm": "%s",\n  "diff_sha256": "%s",\n  "diff_bytes": %s\n}\n' "$base" "$candidate" "$ALGORITHM" "$digest" "$bytes" >"$dest"
}

manifest_check() {
  local file="$1" base candidate algorithm digest bytes keys expected actual computed_digest computed_bytes tmp
  [[ -f "$file" ]] || die "baseline manifest missing: $file"
  keys=$(jq -r 'keys | sort | join(",")' "$file") || die 'baseline manifest is not valid JSON'
  [[ "$keys" == 'candidate_sha,diff_algorithm,diff_bytes,diff_sha256,reviewed_base_sha,schema_version' ]] || die 'baseline manifest has missing or unexpected fields'
  [[ $(jq -r '.schema_version' "$file") == 1 ]] || die 'unsupported baseline schema_version'
  base=$(jq -r '.reviewed_base_sha' "$file")
  candidate=$(jq -r '.candidate_sha' "$file")
  algorithm=$(jq -r '.diff_algorithm' "$file")
  digest=$(jq -r '.diff_sha256' "$file")
  bytes=$(jq -r '.diff_bytes' "$file")
  valid_sha "$base" && valid_sha "$candidate" || die 'baseline contains invalid full SHA'
  [[ "$algorithm" == "$ALGORITHM" ]] || die "unsupported baseline algorithm: $algorithm"
  [[ "$digest" =~ ^[0-9a-f]{64}$ && "$bytes" =~ ^(0|[1-9][0-9]*)$ ]] || die 'baseline digest or byte count is invalid'
  tmp=$(mktemp)
  computed_digest=$(diff_digest "${REPO_DIR:-.}" "$base" "$candidate" "$tmp")
  computed_bytes=$(wc -c <"$tmp" | tr -d ' ')
  rm -f "$tmp"
  [[ "$computed_digest" == "$digest" ]] || die 'candidate diff digest differs from baseline'
  [[ "$computed_bytes" == "$bytes" ]] || die 'candidate diff byte count differs from baseline'
  printf 'baseline verified: base=%s candidate=%s sha256=%s bytes=%s\n' "$base" "$candidate" "$digest" "$bytes"
}

pr_json() {
  gh api "repos/szTheory/sigra/pulls/$PR_NUMBER"
}

check_live_pr() {
  local expected_base="$1" pr head base state
  pr=$(pr_json) || die 'unable to query PR #224'
  head=$(jq -r '.head.sha' <<<"$pr")
  base=$(jq -r '.base.sha' <<<"$pr")
  state=$(jq -r '.state' <<<"$pr")
  [[ "$head" == "$CANDIDATE" ]] || die 'PR #224 head is not the fixed candidate SHA'
  # GitHub keeps the PR's observed base SHA at the last synchronization point.
  # The evidence-only main advance does not update PR #224 (and must not touch
  # its fixed candidate head), so accept either the original reviewed base or
  # the current live main while rejecting any unrelated base movement.
  [[ "$base" == "$REVIEWED_BASE" || "$base" == "$expected_base" ]] || die 'PR #224 base is neither the reviewed base nor current live main'
  [[ "$state" == open ]] || die 'PR #224 is not open'
}

live_main() {
  gh api repos/szTheory/sigra/branches/main --jq '.commit.sha'
}

capture_baseline() {
  local dest="${2:-$MANIFEST_PATH}" main
  need gh; need git; need jq; need sha256sum
  [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]] || die 'read-only GitHub token unavailable'
  main=$(live_main) || die 'unable to query live main'
  [[ "$main" == "$REVIEWED_BASE" ]] || die 'live main advanced; capture is permitted only before the evidence merge'
  check_live_pr "$REVIEWED_BASE"
  manifest_write "${REPO_DIR:-.}" "$REVIEWED_BASE" "$CANDIDATE" "$dest"
  printf 'captured baseline: %s\n' "$dest"
}

check_hex_release_absent() {
  local status attempt
  for attempt in 1 2; do
    status=$(curl -sS -o /dev/null -w '%{http_code}' https://hex.pm/api/packages/sigra/releases/1.6.0) || status=000
    if [[ "$status" == 404 ]]; then
      printf '404\n'
      return 0
    fi
    if [[ "$attempt" == 1 && ( "$status" == 000 || "$status" =~ ^5[0-9][0-9]$ ) ]]; then
      continue
    fi
    die "Hex release endpoint must report absence (HTTP $status)"
  done
  die 'Hex release endpoint transient retry exhausted'
}

verify_baseline() {
  local file="${2:-$MANIFEST_PATH}" main base merge_base paths expected evidence_pr evidence_head blob_id actual_blob
  need gh; need git; need jq; need sha256sum
  main=$(live_main) || die 'unable to query live main'
  check_live_pr "$main"
  manifest_check "$file"
  base=$(jq -r '.reviewed_base_sha' "$file")
  [[ "$base" == "$REVIEWED_BASE" ]] || die 'baseline reviewed base differs from the selected reviewed base'
  [[ $(jq -r '.candidate_sha' "$file") == "$CANDIDATE" ]] || die 'baseline candidate differs from the fixed candidate'
  git -C "${REPO_DIR:-.}" merge-base --is-ancestor "$base" "$main" || die 'live main is not a descendant of reviewed base'
  merge_base=$(git -C "${REPO_DIR:-.}" merge-base "$main" "$CANDIDATE")
  [[ "$merge_base" == "$base" ]] || die 'live main and candidate no longer share the reviewed base'
  paths=$(git -C "${REPO_DIR:-.}" diff --name-only "$base" "$main" | sort)
  expected=$(printf '%s\n' .github/workflows/phase-247-hex-dry-run.yml scripts/ci/phase-247-hex-dry-run.sh scripts/ci/phase-247-hex-dry-run.test.sh "$MANIFEST_PATH" | sort)
  [[ "$paths" == "$expected" ]] || die 'live main advance contains paths outside the four approved evidence files'
  [[ -z "$(git -C "${REPO_DIR:-.}" status --porcelain --untracked-files=all)" ]] || die 'trusted checkout is not clean'
  evidence_pr=${EVIDENCE_PR_NUMBER:-}
  evidence_head=${EVIDENCE_PR_HEAD_SHA:-}
  blob_id=${EVIDENCE_MANIFEST_BLOB_ID:-}
  if [[ -n "$evidence_pr" || -n "$evidence_head" || -n "$blob_id" ]]; then
    [[ "$evidence_pr" =~ ^[0-9]+$ ]] && valid_sha "$evidence_head" && [[ "$blob_id" =~ ^[0-9a-f]{40}$ ]] || die 'evidence PR provenance inputs are malformed'
    actual_blob=$(git -C "${REPO_DIR:-.}" rev-parse "$evidence_head:$MANIFEST_PATH") || die 'manifest absent at evidence PR head'
    [[ "$actual_blob" == "$blob_id" ]] || die 'evidence PR head manifest blob differs from supplied blob ID'
    actual_blob=$(git -C "${REPO_DIR:-.}" rev-parse "$main:$MANIFEST_PATH") || die 'manifest absent on live main'
    [[ "$actual_blob" == "$blob_id" ]] || die 'live main manifest blob differs from evidence PR blob ID'
    local pr
    pr=$(gh api "repos/szTheory/sigra/pulls/$evidence_pr") || die 'unable to query evidence PR'
    [[ $(jq -r '.merged' <<<"$pr") == true ]] || die 'evidence PR is not merged'
    merge_base=$(jq -r '.merge_commit_sha' <<<"$pr")
    valid_sha "$merge_base" || die 'evidence PR merge SHA is invalid'
    git -C "${REPO_DIR:-.}" merge-base --is-ancestor "$merge_base" "$main" || die 'evidence PR merge commit is not an ancestor of live main'
    [[ $(jq -r '.head.sha' <<<"$pr") == "$evidence_head" ]] || die 'evidence PR head differs from supplied pre-merge SHA'
  fi
  printf 'verified evidence-only main advance: main=%s base=%s candidate=%s\n' "$main" "$base" "$CANDIDATE"
}

write_receipt() {
  local output="$2" trusted="${3:-.}" candidate_dir="${4:-../candidate}" manifest_file run_id run_attempt run_url workflow_ref live_base before after verdict requested evidence_pr evidence_head merge_sha blob digest bytes computed_digest computed_bytes status pr
  need gh; need git; need jq; need curl; need sha256sum
  requested="${CANDIDATE_SHA:-}"
  [[ "$requested" == "$CANDIDATE" ]] || die 'requested source is not the fixed candidate SHA'
  [[ "${GITHUB_REF:-}" == refs/heads/main ]] || die 'workflow ref is not refs/heads/main'
  [[ $(git -C "$trusted" rev-parse HEAD) == "${GITHUB_SHA:-}" ]] || die 'trusted checkout HEAD differs from workflow SHA'
  [[ $(git -C "$candidate_dir" rev-parse HEAD) == "$CANDIDATE" ]] || die 'candidate checkout HEAD differs from fixed SHA'
  [[ -z "$(git -C "$trusted" status --porcelain --untracked-files=all)" ]] || die 'trusted checkout is not clean'
  [[ -z "$(git -C "$candidate_dir" status --porcelain --untracked-files=all)" ]] || die 'candidate checkout is not clean'
  run_id="${GITHUB_RUN_ID:-}"; run_attempt="${GITHUB_RUN_ATTEMPT:-}"; workflow_ref="${GITHUB_WORKFLOW_REF:-}"
  [[ "$run_id" =~ ^[0-9]+$ && "$run_attempt" =~ ^[0-9]+$ && "$workflow_ref" == szTheory/sigra/.github/workflows/phase-247-hex-dry-run.yml@refs/heads/main ]] || die 'workflow run identity is incomplete or untrusted'
  [[ "${GITHUB_RUN_STARTED_AT:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || die 'workflow run start timestamp is missing or malformed'
  run_url="https://github.com/szTheory/sigra/actions/runs/$run_id"
  evidence_pr="${EVIDENCE_PR_NUMBER:-}"; evidence_head="${EVIDENCE_PR_HEAD_SHA:-}"; blob="${EVIDENCE_MANIFEST_BLOB_ID:-}"
  manifest_file="$trusted/$MANIFEST_PATH"
  verify_baseline verify "$manifest_file"
  pr=$(gh api "repos/szTheory/sigra/pulls/$evidence_pr") || die 'unable to query evidence PR for receipt'
  merge_sha=$(jq -r '.merge_commit_sha' <<<"$pr")
  live_base=$(live_main)
  check_live_pr "$live_base"
  digest=$(jq -r '.diff_sha256' "$manifest_file"); bytes=$(jq -r '.diff_bytes' "$manifest_file")
  local tmp
  tmp=$(mktemp); computed_digest=$(diff_digest "$candidate_dir" "$REVIEWED_BASE" "$CANDIDATE" "$tmp"); computed_bytes=$(wc -c <"$tmp" | tr -d ' '); rm -f "$tmp"
  [[ "$computed_digest" == "$digest" && "$computed_bytes" == "$bytes" ]] || die 'candidate checkout does not match committed baseline'
  before="${HEX_RELEASE_BEFORE_STATUS:-000}"
  status="${DRY_RUN_OUTCOME:-failure}"
  after=$(curl -sS -o /dev/null -w '%{http_code}' https://hex.pm/api/packages/sigra/releases/1.6.0) || after=000
  [[ "$status" == success && "${DRY_RUN_KEY_PRESENT:-false}" == true && "$before" == 404 && "$after" == 404 ]] && verdict=passed || verdict=failed
  jq -n --arg repo szTheory/sigra --arg workflow .github/workflows/phase-247-hex-dry-run.yml --arg workflow_ref "$workflow_ref" --arg run_id "$run_id" --arg run_attempt "$run_attempt" --arg run_url "$run_url" --arg requested_sha "$requested" --arg checked_out_sha "$CANDIDATE" --arg reviewed_base "$REVIEWED_BASE" --arg live_base "$live_base" --arg evidence_pr "$evidence_pr" --arg evidence_head "$evidence_head" --arg merge_sha "$merge_sha" --arg manifest_blob "$blob" --arg manifest_path "$MANIFEST_PATH" --arg algorithm "$ALGORITHM" --arg digest "$digest" --arg computed_digest "$computed_digest" --arg diff_bytes "$bytes" --arg computed_bytes "$computed_bytes" --arg command 'mix hex.publish --dry-run --yes' --arg dry_run_outcome "$status" --arg key_name HEX_DRY_RUN_API_KEY --arg release_url https://hex.pm/api/packages/sigra/releases/1.6.0 --arg before "$before" --arg after "$after" --arg key_present "${DRY_RUN_KEY_PRESENT:-false}" --arg started_at "$GITHUB_RUN_STARTED_AT" --arg verdict "$verdict" --arg finished_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{schema_version:1,repository:$repo,workflow:$workflow,workflow_ref:$workflow_ref,run_id:$run_id,run_attempt:($run_attempt|tonumber),run_url:$run_url,requested_sha:$requested_sha,checked_out_sha:$checked_out_sha,reviewed_base_sha:$reviewed_base,live_base_sha:$live_base,evidence_pr_number:($evidence_pr|tonumber),evidence_pr_head_sha:$evidence_head,evidence_merge_sha:$merge_sha,manifest_blob_id:$manifest_blob,baseline_manifest_path:$manifest_path,diff_algorithm:$algorithm,diff_sha256:$digest,diff_bytes:($diff_bytes|tonumber),recomputed_diff_sha256:$computed_digest,recomputed_diff_bytes:($computed_bytes|tonumber),command:$command,dry_run_outcome:$dry_run_outcome,credential_name:$key_name,credential_present:($key_present == "true"),hex_release_url:$release_url,hex_release_before_http_status:($before|tonumber),hex_release_after_http_status:($after|tonumber),started_at:$started_at,finished_at:$finished_at,verdict:$verdict}' >"$output"
  [[ "$verdict" == passed ]] || die 'Hex dry-run step did not succeed'
}

main() {
  case "${1:-}" in
    capture-baseline) capture_baseline "$@" ;;
    verify-baseline) verify_baseline "$@" ;;
    check-release) check_hex_release_absent ;;
    write-receipt) write_receipt "$@" ;;
    *) die 'usage: phase-247-hex-dry-run.sh {capture-baseline [path]|verify-baseline [path]|write-receipt <path> [trusted-dir] [candidate-dir]}' ;;
  esac
}

main "$@"
