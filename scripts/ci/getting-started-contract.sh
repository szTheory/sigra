#!/usr/bin/env bash
# scripts/ci/getting-started-contract.sh
#
# SEED-8 shift-left (mechanical): internal markdown links in getting-started
# resolve; documented mix commands appear in fenced blocks.
#
# Run from repo root:
#   bash scripts/ci/getting-started-contract.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${ROOT}/guides/introduction/getting-started.md"

echo "==> getting-started-contract: ${DOC}"

test -f "${DOC}" || {
  echo "FAIL: missing ${DOC}"
  exit 1
}

# Internal .md / .html links (relative only) must point at existing files under guides/.
while IFS= read -r raw; do
  target="${raw%%#*}"
  [[ -z "${target}" ]] && continue
  # Skip external URLs
  [[ "${target}" =~ ^https?:// ]] && continue
  # Skip mailto / bare anchors
  [[ "${target}" =~ ^mailto: ]] && continue
  # Strip optional angle / title junk
  stripped="${target%%#*}"
  path="${ROOT}/guides/introduction/${stripped}"
  if [[ -f "${path}" ]]; then
    continue
  fi
  # ExDoc publishes .md as .html; accept sibling .md when only .html is linked.
  if [[ "${path}" == *.html ]] && [[ -f "${path%.html}.md" ]]; then
    continue
  fi
  # Cross-folder guides (e.g. registration.html -> flows/registration.md).
  if [[ "${stripped}" == *.html ]]; then
    bn="$(basename "${stripped}" .html)"
    if [[ -n "$(find "${ROOT}/guides" -type f -name "${bn}.md" 2>/dev/null | head -1)" ]]; then
      continue
    fi
  fi
  echo "FAIL: broken relative link in getting-started: ${raw} -> ${path}"
  exit 1
done < <(grep -oE '\]\([^)]+\)' "${DOC}" | sed 's/^](//;s/)$//' | grep -E '\.(md|html)' || true)

# Required commands from SEED-8 / install walkthrough must still be documented.
for needle in "mix phx.server" "mix sigra.install" "mix ecto.migrate"; do
  grep -Fq "${needle}" "${DOC}" || {
    echo "FAIL: getting-started.md missing documented command: ${needle}"
    exit 1
  }
done

echo "==> getting-started-contract: OK"
