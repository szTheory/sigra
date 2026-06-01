#!/usr/bin/env bash
# scripts/ci/launch-pack-contract.sh
#
# Phase 149 shift-left: prove the Sigra 1.0 launch pack exists, routes
# through public/AI entry points, preserves post-publish placeholders, and
# does not introduce unsupported launch claims.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ANNOUNCEMENT="${ROOT}/docs/launch/v1.0/announcement.md"
ALTERNATIVES="${ROOT}/docs/launch/v1.0/alternatives.md"
EVIDENCE="${ROOT}/docs/launch/v1.0/evidence.md"
README="${ROOT}/README.md"
CHANGELOG="${ROOT}/CHANGELOG.md"
NEXT_STEPS="${ROOT}/docs/NEXT-STEPS-MANUAL.md"
LLMS="${ROOT}/doc/llms.txt"
ROOT_LLMS="${ROOT}/llms.txt"

echo "==> launch-pack-contract"

require_file() {
  local file="$1"
  test -f "${file}" || {
    echo "FAIL: missing ${file}"
    exit 1
  }
}

require_text() {
  local file="$1"
  local needle="$2"
  grep -Fq "${needle}" "${file}" || {
    echo "FAIL: ${file} missing required text: ${needle}"
    exit 1
  }
}

reject_text() {
  local file="$1"
  local needle="$2"
  if grep -Fiq "${needle}" "${file}"; then
    echo "FAIL: ${file} contains forbidden phrase: ${needle}"
    exit 1
  fi
}

for file in "${ANNOUNCEMENT}" "${ALTERNATIVES}" "${EVIDENCE}" "${README}" "${CHANGELOG}" "${NEXT_STEPS}" "${LLMS}" "${ROOT_LLMS}"; do
  require_file "${file}"
done

for needle in \
  "## Problem framing" \
  "## Why Sigra's hybrid model" \
  "## Explicit non-goals" \
  "## Proof links" \
  "## Who should upgrade now" \
  "## Who should wait"; do
  require_text "${ANNOUNCEMENT}" "${needle}"
done

for needle in \
  "## Comparison axes" \
  "## Ownership boundary table" \
  "## When not to choose Sigra" \
  "phx.gen.auth" \
  "Pow" \
  "Guardian" \
  "Ueberauth" \
  "hosted auth" \
  "Sigra's hybrid model"; do
  require_text "${ALTERNATIVES}" "${needle}"
done

for needle in \
  "## What this bundle covers" \
  "## Evidence table" \
  "## Post-publish placeholders" \
  "## What this does not prove" \
  "POST_PUBLISH_HEX_VISIBILITY_URL" \
  "POST_PUBLISH_HEXDOCS_VERSION_URL" \
  "POST_PUBLISH_GITHUB_RELEASE_URL" \
  "POST_PUBLISH_RELEASE_REF_CI_URLS" \
  "v1.0.0" \
  "main blob URLs"; do
  require_text "${EVIDENCE}" "${needle}"
done

for file in "${README}" "${CHANGELOG}" "${NEXT_STEPS}"; do
  require_text "${file}" "docs/launch/v1.0/announcement.md"
  require_text "${file}" "docs/launch/v1.0/alternatives.md"
  require_text "${file}" "docs/launch/v1.0/evidence.md"
done

for needle in \
  "announcement.html" \
  "alternatives.html" \
  "evidence.html" \
  "changelog.md" \
  "security.md"; do
  require_text "${LLMS}" "${needle}"
done

require_text "${ROOT_LLMS}" "doc/llms.txt"
require_text "${ROOT_LLMS}" "https://hexdocs.pm/sigra/llms.txt"

if grep -Fq "## Pages" "${ROOT_LLMS}"; then
  echo "FAIL: root llms.txt must stay pointer-only and must not define ## Pages"
  exit 1
fi

for file in "${ANNOUNCEMENT}" "${ALTERNATIVES}" "${EVIDENCE}"; do
  reject_text "${file}" "automatic migration guarantee"
  reject_text "${file}" "drop-in replacement"
  reject_text "${file}" "hosted auth replacement"
  reject_text "${file}" "provider certification included"
  reject_text "${file}" "compliance certification included"
  reject_text "${file}" "ecosystem equivalence guarantee"
done

echo "==> launch-pack-contract: OK"
