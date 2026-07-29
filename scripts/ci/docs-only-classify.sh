#!/usr/bin/env bash
# Phase 230 (FAST-05 / D-07): docs-only change classifier.
#
# Contract: reads a newline-separated list of paths on stdin and writes
# exactly one line to stdout: `docs_only=true` or `docs_only=false`. No
# network, no `git`, no `gh` -- the caller is responsible for producing the
# path list (e.g. `git diff --name-only <base>...HEAD`); this script never
# invokes either itself.
#
# A path counts as documentation when it ends in `.md` or begins with
# `.planning/`. If ANY path on stdin is neither, the answer is `false`;
# otherwise -- including empty stdin -- it is `true`. The unmatched
# direction is deliberately the fail-safe one: `false` runs the full CI
# matrix, so a misclassified path never silently removes coverage.
#
# Two consumers (Phase 230 Plan 05):
#   - ci.yml `changes` job's `detect` step -- the rule executed in CI is
#     byte-identical to the rule below.
#   - scripts/ci/docs-only-classify.test.sh -- the hermetic self-test wired
#     into `fast_checks` on every PR and push. This is this requirement's
#     ONLY in-phase evidence: `ci.yml` triggers on
#     `pull_request: branches: [main]`, so any pre-merge pull request's
#     base-to-HEAD diff necessarily carries this phase's own non-Markdown
#     commits (this file included) and can never classify docs_only=true.
#     The end-to-end `true` observation is a post-merge obligation
#     (AFTER-DOCSONLY, 230-EVIDENCE.md).
#
# Usage:
#   git diff --name-only <base>...HEAD | bash scripts/ci/docs-only-classify.sh
#
# Exit codes:
#   0 -- always, on a successful classification (docs_only=true or =false)
#   2 -- unknown argument
set -euo pipefail

for arg in "$@"; do
  echo "docs-only-classify: FAIL: unknown arg: ${arg}" >&2
  exit 2
done

docs_only=true

# Read directly from the script's own stdin (no internal pipe), so this
# loop runs in the current shell and `docs_only` persists after it exits.
# `|| [ -n "$path" ]` picks up a final line with no trailing newline.
while IFS= read -r path || [ -n "$path" ]; do
  [ -z "${path}" ] && continue
  case "${path}" in
    *.md | .planning/*) ;;
    *) docs_only=false ;;
  esac
done

echo "docs_only=${docs_only}"
