#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$ROOT/scripts/ci/verify-terminal-ratification-attestation-offline.sh"
WORK="$(/usr/bin/mktemp -d /tmp/sigra-terminal-hostile.XXXXXX)"
trap '/bin/rm -rf -- "$WORK"' EXIT
SENTINEL_LOG="$WORK/sentinel.log"
HOSTILE_ROOT="$WORK/attacker-root"
/bin/mkdir "$WORK/bin" "$HOSTILE_ROOT"
for name in bash dirname uname mktemp realpath readlink stat env gh jq mkdir cp rm sandbox-exec unshare sudo true dd; do
  printf '#!/bin/sh\nprintf "%%s\\n" "${0##*/}" >> "$SENTINEL_LOG"\nexit 97\n' >"$WORK/bin/$name"
  /bin/chmod +x "$WORK/bin/$name"
done
PATH="$WORK/bin" TMPDIR="$HOSTILE_ROOT" TMP="$HOSTILE_ROOT" TEMP="$HOSTILE_ROOT" SENTINEL_LOG="$SENTINEL_LOG" \
  "$VERIFIER" >"$WORK/stdout" 2>"$WORK/stderr"
/usr/bin/grep -Fx offline_attestation_verified "$WORK/stdout"
test ! -s "$SENTINEL_LOG"
test -z "$(/usr/bin/find "$HOSTILE_ROOT" -mindepth 1 -print -quit)"
