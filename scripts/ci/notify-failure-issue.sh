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
#
# Label self-heal (Phase 231 D-22): before creating a NEW issue, check
# whether LABEL exists and create it if not. GitHub's permissions reference
# says the `issues: write` scope both callers already declare covers
# `gh label list` and `gh label create` -- but community discussion #13565
# has a contested 2022-to-2025 history on exactly that question, and the
# disagreement is not resolvable without a live write. So the self-heal is
# fail-SOFT: a denied `gh label create` logs a warning and the issue is
# opened anyway (falling back to an unlabelled `gh issue create` as a last
# resort). The issue is the signal; the label is only how it is found again.
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

  # Self-heal a missing label before creating the issue. Capture `gh label
  # list` into a variable first, then test it -- piping `gh` straight into
  # `grep -q` under `set -euo pipefail` risks SIGPIPE-ing the upstream `gh`
  # when grep closes the pipe early on its first match.
  existing_labels="$(gh label list --limit 200 --json name --jq '.[].name' || true)"
  if ! printf '%s\n' "$existing_labels" | grep -qxF "$LABEL"; then
    echo "notify-failure-issue: label '${LABEL}' absent; creating"
    gh label create "$LABEL" \
      --description "Auto-created by notify-failure-issue.sh (Phase 231 D-22)" \
      --color b60205 \
      || echo "notify-failure-issue: WARNING: could not create label '${LABEL}' (continuing; the issue is the signal)"
  fi

  # Tolerate a still-missing/uncreatable label: retry once without --label
  # so a denied label create never costs us the tracking issue itself.
  gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY" \
    || gh issue create --title "$TITLE" --body "$BODY"
fi
