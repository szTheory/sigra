#!/usr/bin/env bash
# Self-test for docs-only-receipt.sh (Phase 230 / AFTER-DOCSONLY closure).
#
# Hermetic: no real `gh` and no network. A recording stub `gh` is placed first on PATH and
# branches on argv -- `--log` returns a scripted `changes` job log, everything else returns
# a scripted `gh run view --json jobs,event,databaseId` payload -- so the log-reading path
# (how docs_only is established) is exercised, not bypassed.
#
# Test cases:
#   A: the changes job log says docs_only=false -> verdict n/a, exit 0. A run that did not
#      meet the condition has not falsified a conditional claim.
#   B: docs_only=true with every lane green -> exit 0, all five required contexts plus
#      fast_checks and both shards reported PASS.
#   C: docs_only=true and a required context concluded `skipped` -> exit 1. This is the
#      D-06 stranding case: a job-level docs_only gate makes the context skipped, and under
#      ruleset 14941512 the PR is no longer merge-eligible.
#   D: docs_only=true and a required context is ABSENT from the run -> exit 1. A context
#      that is never created leaves the PR pending forever -- worse than a red.
#   E: docs_only=true and fast_checks ran 0s -> exit 1. It must execute in full; its guards
#      read exactly the .planning/** paths a docs-only PR changes.
#   F: docs_only=true and no `Library tests shard *` job ran -> exit 1.
#   G: the run has no `Detect docs-only change` job -> exit 1, refusing to infer.
#   H: the changes job log carries no `docs_only=` line -> exit 1, refusing to infer.
#      (Both G and H fail CLOSED: an unestablishable classification is never "false".)
#   I: unknown flag -> exit 2 with ZERO gh invocations.
#   J: --from-json + --docs-only -> ZERO gh invocations, valid JSON verdict.
#
# No network access and no GH_TOKEN are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/docs-only-receipt.sh"
[[ -f "$SCRIPT" ]] || { echo "FATAL: script not found at ${SCRIPT}" >&2; exit 2; }

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() { [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"; mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
PAYLOAD_FILE="${TMPDIR_ROOT}/payload.json"
CHANGES_LOG_FILE="${TMPDIR_ROOT}/changes.log"
: > "$GH_STUB_LOG"

mk_job() { # name status conclusion started completed
  jq -n --arg n "$1" --arg s "$2" --arg c "$3" --arg a "$4" --arg b "$5" \
    '{name:$n,status:$s,conclusion:$c,startedAt:$a,completedAt:$b,databaseId:1}'
}

BASE_PAYLOAD="$(jq -n --argjson jobs "$(jq -s '.' <<<"$(
  mk_job "Detect docs-only change" completed success 2026-07-30T00:00:00Z 2026-07-30T00:00:36Z
  mk_job "Library tests" completed success 2026-07-30T00:01:00Z 2026-07-30T00:01:04Z
  mk_job "Library tests shard 1" completed success 2026-07-30T00:00:40Z 2026-07-30T00:08:40Z
  mk_job "Library tests shard 2" completed success 2026-07-30T00:00:40Z 2026-07-30T00:05:57Z
  mk_job "Example unit smoke (ExUnit + ConnTest)" completed success 2026-07-30T00:00:40Z 2026-07-30T00:01:31Z
  mk_job "Install smoke (fresh phx.new + sigra.install)" completed success 2026-07-30T00:00:40Z 2026-07-30T00:02:26Z
  mk_job "Example HTTP smoke (boot + curl critical routes)" completed success 2026-07-30T00:00:40Z 2026-07-30T00:01:47Z
  mk_job "Example Playwright smoke (full lifecycle)" completed success 2026-07-30T00:00:40Z 2026-07-30T00:02:00Z
  mk_job "Fast checks (milestone/installer/contracts/snapshot/ledger guards)" completed success 2026-07-30T00:00:10Z 2026-07-30T00:00:36Z
)")" '{databaseId: 40000000001, event: "pull_request", jobs: $jobs}')"

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
for a in "\$@"; do
  if [[ "\$a" == "--log" ]]; then cat "${CHANGES_LOG_FILE}"; exit 0; fi
done
cat "${PAYLOAD_FILE}"
STUB
chmod +x "${STUB_BIN_DIR}/gh"

# $1 = payload, $2 = changes-job log text, rest = extra argv
run_receipt() {
  local payload="$1" logtext="$2"; shift 2
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  printf '%s' "$logtext" > "$CHANGES_LOG_FILE"
  : > "$GH_STUB_LOG"
  set +e
  RECEIPT_OUT="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 "$@" 2>&1)"
  RECEIPT_RC=$?
  set -e
}
gh_call_count() { local n; n="$(grep -c . "$GH_STUB_LOG" 2>/dev/null || true)"; echo "${n:-0}"; }

DOCS_FALSE_LOG='2026-07-30T00:00:36Z changes  docs_only=false'
DOCS_TRUE_LOG='2026-07-30T00:00:36Z changes  docs_only=true'

# ---- A ----
echo "Test A: docs_only=false in the changes log -> n/a, exit 0"
run_receipt "$BASE_PAYLOAD" "$DOCS_FALSE_LOG"
if [[ "$RECEIPT_RC" -eq 0 ]] && grep -q "nothing to assert" <<<"$RECEIPT_OUT"; then
  pass "A: a non-docs-only run reports n/a rather than failing"
else fail "A: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- B ----
echo "Test B: docs_only=true, all lanes green -> exit 0"
run_receipt "$BASE_PAYLOAD" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 0 ]] && grep -q "all five required contexts merge-eligible" <<<"$RECEIPT_OUT" \
   && grep -q "Library tests shard 1" <<<"$RECEIPT_OUT"; then
  pass "B: five required contexts + fast_checks + both shards all PASS"
else fail "B: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- C ----
echo "Test C: a required context concluded skipped -> exit 1 (D-06 stranding)"
P_C="$(jq '(.jobs[] | select(.name == "Example unit smoke (ExUnit + ConnTest)")).conclusion = "skipped"' <<<"$BASE_PAYLOAD")"
run_receipt "$P_C" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "not merge-eligible" <<<"$RECEIPT_OUT"; then
  pass "C: exit 1 when a required context is skipped"
else fail "C: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- D ----
echo "Test D: a required context absent from the run -> exit 1"
P_D="$(jq '[.jobs[] | select(.name != "Install smoke (fresh phx.new + sigra.install)")] as $j | .jobs = $j' <<<"$BASE_PAYLOAD")"
run_receipt "$P_D" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "pending forever" <<<"$RECEIPT_OUT"; then
  pass "D: exit 1, and the reason names the never-created-context hazard"
else fail "D: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- E ----
echo "Test E: fast_checks ran 0s -> exit 1 (gated off)"
P_E="$(jq '(.jobs[] | select(.name | startswith("Fast checks"))).completedAt = "2026-07-30T00:00:10Z"' <<<"$BASE_PAYLOAD")"
run_receipt "$P_E" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "must execute in full" <<<"$RECEIPT_OUT"; then
  pass "E: exit 1 when a must-run-in-full lane contributes no time"
else fail "E: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- F ----
echo "Test F: no library test shard ran -> exit 1"
P_F="$(jq '[.jobs[] | select(.name | startswith("Library tests shard") | not)] as $j | .jobs = $j' <<<"$BASE_PAYLOAD")"
run_receipt "$P_F" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "no library test shard ran" <<<"$RECEIPT_OUT"; then
  pass "F: exit 1 when the sharded suite was gated off"
else fail "F: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- G ----
echo "Test G: no 'Detect docs-only change' job -> exit 1 (refuse to infer)"
P_G="$(jq '[.jobs[] | select(.name != "Detect docs-only change")] as $j | .jobs = $j' <<<"$BASE_PAYLOAD")"
run_receipt "$P_G" "$DOCS_TRUE_LOG"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "cannot establish the classification honestly" <<<"$RECEIPT_OUT"; then
  pass "G: fail-closed when the classifying job is absent"
else fail "G: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- H ----
echo "Test H: changes log has no docs_only= line -> exit 1 (refuse to infer)"
run_receipt "$BASE_PAYLOAD" "some unrelated log output with no classification in it"
if [[ "$RECEIPT_RC" -eq 1 ]] && grep -q "refusing to infer" <<<"$RECEIPT_OUT"; then
  pass "H: an unestablishable classification is never silently 'false'"
else fail "H: rc=${RECEIPT_RC}, out: ${RECEIPT_OUT}"; fi

# ---- I ----
echo "Test I: unknown flag -> exit 2, zero gh invocations"
: > "$GH_STUB_LOG"
set +e
PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --bogus >/dev/null 2>&1
RC_I=$?
set -e
CALLS_I="$(gh_call_count)"
if [[ "$RC_I" -eq 2 && "$CALLS_I" -eq 0 ]]; then
  pass "I: exit 2 before any gh round-trip (${CALLS_I} calls)"
else fail "I: rc=${RC_I}, gh calls=${CALLS_I}"; fi

# ---- J ----
echo "Test J: --from-json + --docs-only -> zero gh calls, valid JSON verdict"
FROM_FILE="${TMPDIR_ROOT}/from.json"
printf '%s' "$BASE_PAYLOAD" > "$FROM_FILE"
: > "$GH_STUB_LOG"
set +e
OUT_J="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --from-json "$FROM_FILE" --docs-only true --format json 2>&1)"
RC_J=$?
set -e
CALLS_J="$(gh_call_count)"
if [[ "$RC_J" -eq 0 && "$CALLS_J" -eq 0 ]] \
   && jq -e '.verdict == "PASS" and .docs_only == true and (.checks | length) >= 8' >/dev/null 2>&1 <<<"$OUT_J"; then
  pass "J: offline mode made ${CALLS_J} gh calls and emitted a valid PASS verdict"
else fail "J: rc=${RC_J}, gh calls=${CALLS_J}, out: ${OUT_J}"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then echo "docs-only-receipt.test: FAIL"; exit 1; fi
echo "docs-only-receipt.test: PASS"
