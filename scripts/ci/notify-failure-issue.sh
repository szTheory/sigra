#!/usr/bin/env bash
# Shared idempotent tracking-issue notifier (D-07) for release-lane failures.
#
# Reads LABEL, TITLE, BODY from the environment (all required; fail-closed
# otherwise) and requires GH_TOKEN (issues: write). Finds the single open
# Issue carrying LABEL; if found, appends BODY as a comment on it (idempotent
# -- one durable issue accumulates occurrences, no spam); otherwise creates a
# new Issue with LABEL/TITLE/BODY.
#
# Two consumers (Phase 222 Plan 02, D-02/D-06.3):
#   - ci.yml `notify_release_lane_rot`            -- HARD-01: red ci-gate on main
#   - release-please.yml `notify-release-failure` -- HARD-02: publish/gate failure
#
# Security: never echoes GH_TOKEN or any secret. GitHub context strings
# (branch/actor/ref/run id/etc.) must reach this script only via the calling
# workflow step's `env:` mapping -- never inlined into a `run:` shell
# expression -- so a crafted context string cannot inject shell or workflow
# commands.
set -euo pipefail

: "${LABEL:?LABEL is required (e.g. release-lane-rot)}"
: "${TITLE:?TITLE is required}"
: "${BODY:?BODY is required}"
: "${GH_TOKEN:?GH_TOKEN is required (issues: write)}"

existing="$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number' || true)"

if [[ -n "$existing" ]]; then
  echo "notify-failure-issue: found open issue #${existing} for label '${LABEL}'; appending occurrence comment"
  gh issue comment "$existing" --body "$BODY"
else
  echo "notify-failure-issue: no open issue for label '${LABEL}'; creating"
  gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY"
fi
