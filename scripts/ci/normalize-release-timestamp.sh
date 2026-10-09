#!/usr/bin/env bash
# Normalize the release-start output from old workflow runs, then validate it.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "normalize-release-timestamp: expected one timestamp" >&2
  exit 2
fi

timestamp="$1"
if [[ ${#timestamp} -ge 2 && ${timestamp:0:1} == '"' && ${timestamp: -1} == '"' ]]; then
  timestamp="${timestamp:1:${#timestamp}-2}"
fi

if [[ ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  echo "normalize-release-timestamp: invalid UTC timestamp" >&2
  exit 1
fi

printf '%s\n' "$timestamp"
