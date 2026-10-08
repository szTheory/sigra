#!/usr/bin/env bash
# Phase 231 (DX-05 / D-20, D-21): the release-lane ci-gate poll loop, extracted from
# release-please.yml's `gate-ci-green` job into a testable CLI.
#
# CONTRACT
# Given a release SHA (or a tag to resolve one from), poll `gh run list` for a ci.yml
# run against that SHA until a run completes with its `ci-gate` job at `success`, or
# `--max-attempts` is exhausted. Self-dispatches ci.yml once, at `--dispatch-after`
# attempts, if no run has appeared yet -- this is the same fallback the inline `run:`
# body always carried, now reachable by a hermetic self-test.
#
# WHY THIS IS NOT INLINE SHELL (D-21)
# The original 58-line `run:` body in release-please.yml could not be reached by any
# test -- which is precisely why nobody noticed its 30-minute ceiling sat below the
# release-lane run it waits on. Extracting it into a script with a CLI converts SC-5
# from "hope the next release goes fine" into a runnable command against a real
# completed run's real `gh run list` / `gh run view` output (see
# scripts/ci/wait-for-ci-gate.test.sh for the hermetic self-test, and this phase's
# SUMMARY for the live invocation receipt).
#
# D-20: --max-attempts defaults to 120 (was 60 inline) -- a 60-minute ceiling at the
# unchanged 30s --wait-seconds -- because a measured push-to-main wall-clock of 28m29s
# (run 30466318240, historical max 42.3m) exceeds the previous 30-minute ceiling, and
# polling costs nothing when green: the loop exits on first success.
#
# NON-VACUITY (fail-closed)
# A run list that stays empty through every attempt is NOT "nothing to wait for, so
# green" -- it is a failure. Every fail-closed path below (empty `gh` output, a
# payload that is not a JSON array, a run list of length 0 after exhausting attempts,
# a non-zero `gh` exit, or exhausting `--max-attempts` outright) exits non-zero.
#
# Security: never echoes GH_TOKEN or any secret; reads only public `gh run list` /
# `gh run view` run metadata. `gh` is invoked bare (resolved via PATH) so the
# self-test can shadow it with a recording stub -- no network call, no GH_TOKEN, in
# scripts/ci/wait-for-ci-gate.test.sh.
set -euo pipefail

SHA="${RELEASE_SHA:-}"
REPO="${REPOSITORY:-szTheory/sigra}"
TAG="${TAG_NAME:-}"
WORKFLOW="ci.yml"
MAX_ATTEMPTS=120
WAIT_SECONDS=30
DISPATCH_AFTER=3
NO_DISPATCH=false
FROM_JSON=""
FORMAT="table"
RUN_URL=""
LAST_RUN_ID=""
LAST_HEAD_SHA=""
EVER_SEEN_RUN=false
ATTEMPT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sha) SHA="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --tag) TAG="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift 2;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2;;
    --dispatch-after) DISPATCH_AFTER="$2"; shift 2;;
    --no-dispatch) NO_DISPATCH=true; shift;;
    --from-json) FROM_JSON="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    -h|--help)
      echo "usage: wait-for-ci-gate.sh --sha <sha> [--repo owner/name] [--tag <tag>] [--workflow ci.yml] [--max-attempts N] [--wait-seconds N] [--dispatch-after N] [--no-dispatch] [--from-json <path>] [--format table|json]"
      exit 0
      ;;
    *)
      echo "wait-for-ci-gate: FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() {
  local message="$*"
  if [[ "$FORMAT" == "json" ]] && command -v jq >/dev/null 2>&1; then
    local attempts="${ATTEMPT:-0}"
    [[ "$attempts" =~ ^[0-9]+$ ]] || attempts=0
    jq -cn --arg sha "$SHA" --arg run_id "$LAST_RUN_ID" --arg run_url "$RUN_URL" \
      --arg head_sha "$LAST_HEAD_SHA" --argjson attempts "$attempts" \
      '{sha:(if $sha == "" then null else $sha end),
        run_id:(if ($run_id | test("^[1-9][0-9]*$")) then ($run_id | tonumber) else null end),
        run_url:(if $run_url == "" then null else $run_url end),
        head_sha:(if $head_sha == "" then null else $head_sha end),
        attempts:$attempts, verdict:"FAIL", gate_verdict:"FAIL", diagnostic:"ci_gate_not_green"}'
  fi
  echo "wait-for-ci-gate: FAIL: ${message}" >&2
  exit 1
}

if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  fail "unknown --format: ${FORMAT} (expected table|json)"
fi

command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"

# SHA resolution fallback: runs ONLY when --sha (and RELEASE_SHA) are absent, because
# D-21's live receipt passes a plain push-to-main SHA with no tag.
if [[ -z "$SHA" ]]; then
  [[ -n "$TAG" ]] || fail "no --sha given (env: RELEASE_SHA) and no --tag to resolve one from (env: TAG_NAME)"
  SHA="$(gh api "repos/${REPO}/commits/${TAG}" --jq '.sha')" || fail "gh api commit lookup failed for tag ${TAG}"
  [[ -n "$SHA" ]] || fail "gh api commit lookup returned an empty sha for tag ${TAG}"
fi

DISPATCHED=false

while (( ATTEMPT <= MAX_ATTEMPTS )); do
  if [[ -n "$FROM_JSON" ]]; then
    [[ -f "$FROM_JSON" ]] || fail "--from-json payload not found at ${FROM_JSON}"
    RUNS_JSON="$(cat "$FROM_JSON")"
  else
    RUNS_JSON="$(gh run list \
      --repo "$REPO" \
      --workflow "$WORKFLOW" \
      --commit "$SHA" \
      --limit 20 \
      --json databaseId,headSha,status,conclusion,url,createdAt,updatedAt)" || fail "gh run list failed (attempt ${ATTEMPT}/${MAX_ATTEMPTS})"
  fi

  [[ -n "$RUNS_JSON" ]] || fail "gh run list returned empty output -- the parse broke, this is not a pass"
  echo "$RUNS_JSON" | jq -e 'type == "array"' >/dev/null 2>&1 \
    || fail "run list payload is not a JSON array -- the parse broke, this is not a pass"

  RUN_COUNT="$(echo "$RUNS_JSON" | jq 'length')"
  if (( RUN_COUNT > 0 )); then
    echo "$RUNS_JSON" | jq -e --arg sha "$SHA" '
      all(.[]; (.headSha | type == "string" and length > 0)
        and .headSha == $sha
        and (.databaseId | type == "number")
        and (.status | type == "string" and length > 0)
        and (.conclusion == null or (.conclusion | type == "string"))
        and (.url | type == "string" and length > 0)
        and (.createdAt | type == "string" and length > 0)
        and (.updatedAt | type == "string" and length > 0))
    ' >/dev/null 2>&1 || fail "run list contains missing metadata or a headSha that differs from requested release SHA ${SHA}"
    EVER_SEEN_RUN=true
    LAST_RUN_METADATA="$(echo "$RUNS_JSON" | jq -c 'sort_by(.createdAt) | reverse | .[0]')"
    LAST_RUN_ID="$(jq -r '.databaseId | tostring' <<<"$LAST_RUN_METADATA")"
    RUN_URL="$(jq -r '.url' <<<"$LAST_RUN_METADATA")"
    LAST_HEAD_SHA="$(jq -r '.headSha' <<<"$LAST_RUN_METADATA")"
  fi

  if (( RUN_COUNT == 0 )); then
    echo "No ${WORKFLOW} run yet for ${SHA} (${ATTEMPT}/${MAX_ATTEMPTS})." >&2
    if (( ATTEMPT == DISPATCH_AFTER )) && [[ "$DISPATCHED" == false ]] && [[ "$NO_DISPATCH" == false ]]; then
      [[ -n "$TAG" ]] || fail "cannot dispatch ${WORKFLOW}: no --tag given (env: TAG_NAME)"
      gh workflow run "$WORKFLOW" --ref "$TAG" --repo "$REPO" || fail "gh workflow run dispatch failed"
      DISPATCHED=true
      echo "Dispatched ${WORKFLOW} on tag ${TAG} for release SHA ${SHA}." >&2
    fi
  else
    INCOMPLETE="$(echo "$RUNS_JSON" | jq -r '[.[] | select(.status != "completed")] | length')"

    if (( INCOMPLETE > 0 )); then
      echo "${WORKFLOW} still running for ${SHA} (${ATTEMPT}/${MAX_ATTEMPTS}): ${RUN_URL}" >&2
    else
      FOUND_GREEN=false
      for RUN_ID in $(echo "$RUNS_JSON" | jq -r 'sort_by(.createdAt) | reverse | .[].databaseId'); do
        if [[ -n "$FROM_JSON" ]]; then
          # Hermetic mode: the --from-json array carries a ci_gate_conclusion field per
          # run entry so the self-test needs no second `gh run view` round-trip either.
          CI_GATE="$(echo "$RUNS_JSON" | jq -r --argjson id "$RUN_ID" '.[] | select(.databaseId == $id) | .ci_gate_conclusion // ""')"
        else
          CI_GATE="$(gh run view "$RUN_ID" \
            --repo "$REPO" \
            --json jobs \
            --jq '.jobs[] | select(.name == "ci-gate") | .conclusion' 2>/dev/null || true)"
        fi

        if [[ "$CI_GATE" == "success" ]]; then
          if [[ -n "$FROM_JSON" ]]; then
            FOUND_URL="$(echo "$RUNS_JSON" | jq -r --argjson id "$RUN_ID" '.[] | select(.databaseId == $id) | .url')"
          else
            FOUND_URL="$(gh run view "$RUN_ID" --repo "$REPO" --json url --jq '.url')" \
              || fail "gh run view failed to resolve url for run ${RUN_ID}"
          fi
          FOUND_GREEN=true
          break
        fi
      done

      if [[ "$FOUND_GREEN" == true ]]; then
        RUN_METADATA="$(echo "$RUNS_JSON" | jq -c --argjson id "$RUN_ID" '.[] | select(.databaseId == $id)')"
        FOUND_HEAD_SHA="$(jq -r '.headSha' <<<"$RUN_METADATA")"
        FOUND_CREATED_AT="$(jq -r '.createdAt' <<<"$RUN_METADATA")"
        FOUND_UPDATED_AT="$(jq -r '.updatedAt' <<<"$RUN_METADATA")"
        case "$FORMAT" in
          json)
            jq -cn --arg sha "$SHA" --arg run_url "$FOUND_URL" --argjson attempts "$ATTEMPT" \
              --argjson run_id "$RUN_ID" --arg head_sha "$FOUND_HEAD_SHA" \
              --arg created_at "$FOUND_CREATED_AT" --arg updated_at "$FOUND_UPDATED_AT" \
              '{sha: $sha, run_url: $run_url, attempts: $attempts, verdict: "PASS", run_id: $run_id, head_sha: $head_sha, created_at: $created_at, updated_at: $updated_at, gate_verdict: "PASS"}'
            ;;
          table)
            echo "ci-gate succeeded on release SHA ${SHA} after ${ATTEMPT} attempt(s): ${FOUND_URL}"
            ;;
        esac
        exit 0
      fi

      echo "No successful ci-gate yet for ${SHA} (${ATTEMPT}/${MAX_ATTEMPTS}); waiting for a fresh run." >&2
    fi
  fi

  (( ATTEMPT == MAX_ATTEMPTS )) && break
  sleep "$WAIT_SECONDS"
  ATTEMPT=$((ATTEMPT + 1))
done

if [[ "$EVER_SEEN_RUN" == false ]]; then
  fail "no ${WORKFLOW} run ever appeared for ${SHA} through ${MAX_ATTEMPTS} attempts -- a run list of length 0 is not \"nothing to wait for, so green\" -- the parse broke, this is not a pass"
fi

fail "Timed out waiting for ci-gate on SHA ${SHA} after ${MAX_ATTEMPTS} attempts. Last run: ${RUN_URL:-none}"
