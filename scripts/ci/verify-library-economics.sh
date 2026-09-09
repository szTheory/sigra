#!/usr/bin/env bash
# Independent verifier for the Phase 235.1 raw economics receipt.
set -uo pipefail

RECEIPT_PATH="/tmp/sigra-library-economics.json"
MAX_BYTES=65536

fail() {
  printf 'verify-library-economics: FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$RECEIPT_PATH" && ! -L "$RECEIPT_PATH" ]] \
  || fail "receipt must be a regular non-symlink file at the fixed path"

receipt_size="$(wc -c <"$RECEIPT_PATH" | tr -d ' ')" \
  || fail "could not determine receipt size"
[[ "$receipt_size" =~ ^[0-9]+$ ]] || fail "receipt size is not an integer"
((receipt_size > 0)) || fail "receipt is empty"
((receipt_size <= MAX_BYTES)) || fail "receipt exceeds ${MAX_BYTES}-byte bound"

jq -e . "$RECEIPT_PATH" >/dev/null 2>&1 || fail "receipt is malformed JSON"

duplicate_path="$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join(".")' \
  "$RECEIPT_PATH" | sort | uniq -d | head -n 1)"
[[ -z "$duplicate_path" ]] || fail "receipt contains duplicate evidence key: ${duplicate_path}"

jq -e '
  type == "object" and
  (keys | sort) == (["classes", "install_leg_ran", "schema_version", "timing_receipt_path"] | sort) and
  .schema_version == "sigra.library-economics/v1" and
  .timing_receipt_path == "/tmp/sigra-library-1-timings.json" and
  (.install_leg_ran | type) == "boolean" and .install_leg_ran == true and
  (.classes | type) == "object" and
  (.classes | keys | sort) == (["install_scaffold", "ordinary"] | sort) and
  ([.classes.ordinary, .classes.install_scaffold] | all(
    type == "object" and
    (keys | sort) == (["conclusion", "duration_ms", "end_ms", "exit_status", "start_ms"] | sort) and
    (.start_ms | type) == "number" and (.start_ms | floor) == .start_ms and .start_ms >= 0 and
    (.end_ms | type) == "number" and (.end_ms | floor) == .end_ms and .end_ms > .start_ms and
    (.duration_ms | type) == "number" and (.duration_ms | floor) == .duration_ms and .duration_ms > 0 and
    .duration_ms == (.end_ms - .start_ms) and
    (.conclusion | type) == "string" and .conclusion == "success" and
    (.exit_status | type) == "number" and (.exit_status | floor) == .exit_status and .exit_status == 0
  ))
' "$RECEIPT_PATH" >/dev/null 2>&1 \
  || fail "exact schema, raw integer timing, conclusion, status, or execution predicate failed"

ordinary="$(jq -r '.classes.ordinary.duration_ms' "$RECEIPT_PATH")"
install="$(jq -r '.classes.install_scaffold.duration_ms' "$RECEIPT_PATH")"
if ((ordinary >= install)); then
  maximum="$ordinary"
  minimum="$install"
else
  maximum="$install"
  minimum="$ordinary"
fi

((maximum * 1000 <= minimum * 2000)) \
  || fail "comparability predicate failed: max/min exceeds 2.0"
((install <= ordinary)) \
  || fail "non-dominance predicate failed: install_scaffold exceeds ordinary"

echo "verify-library-economics: PASS"
