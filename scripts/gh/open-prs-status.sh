#!/usr/bin/env bash
# Summarize open PRs + required check pass/fail for szTheory/sigra (shift-left triage).
# Requires: gh CLI, `gh auth status` OK
set -euo pipefail

REPO="${SIGRA_GH_REPO:-szTheory/sigra}"

echo "==> ${REPO} — open pull requests"
gh pr list --repo "$REPO" --state open \
  --json number,title,headRefName,mergeStateStatus,url \
  --template '{{range .}}{{.number}}	{{.mergeStateStatus}}	{{.headRefName}}	{{.title}}
{{.url}}
{{end}}' | while IFS= read -r line; do
  echo "$line"
done

echo ""
for n in $(gh pr list --repo "$REPO" --state open --json number -q '.[].number'); do
  echo "---------- PR #${n} ----------"
  if gh pr checks "$n" --repo "$REPO" 2>&1; then
    echo "(all reported checks passed)"
  else
    echo "(one or more checks failed or pending — see table above)"
  fi
  echo ""
done
