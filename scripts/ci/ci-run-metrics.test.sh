#!/usr/bin/env bash
# Self-test for ci-run-metrics.sh (Phase 230 / D-21 / SC-5).
#
# Hermetic: no real `gh` CLI or network call. A recording stub `gh` is placed first on
# PATH; it logs every invocation's argv and returns a scripted `gh run view --json jobs`
# payload so each case can assert exactly what the script under test computed.
#
# Test cases (mirrors the plan's <behavior> block):
#   A: canned run -> per-job table with name, conclusion, duration in both `Ns` and
#      `NmSSs` form.
#   B: `Admin eval render + probe (evidence only, not a merge gate)` (conclusion
#      "failure", continue-on-error) appears with duration 1053s / 17m33s -- NOT
#      filtered out for a non-"success" conclusion.
#   C: `Upgrade smoke` has a `completedAt` 1s before `startedAt` -> reported duration is
#      `0`, never negative.
#   D: unknown flag -> exit 2, `ci-run-metrics: FAIL: unknown arg: <arg>` on stderr,
#      fail-closed with ZERO recorded `gh` invocations (arg parsing fails before any
#      gh call is made).
#   E: `gh` absent from PATH -> exit non-zero, `ci-run-metrics: FAIL:` on stderr.
#   F: `gh` exits non-zero -> exit non-zero, `ci-run-metrics: FAIL:` on stderr, no
#      partial table on stdout.
#   G: empty job list -> exit non-zero, `ci-run-metrics: FAIL:` on stderr, no partial
#      table on stdout.
#   H: `--format json` emits valid JSON with the same duration/clamp/filter semantics.
#
# No network access and no GH_TOKEN are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-run-metrics.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"

# Canned `gh run view --json jobs --jq '.jobs'` payload: one job with a large real
# duration that concludes "failure" under continue-on-error (b), and one job whose
# completedAt precedes its startedAt by 1s (a), exactly mirroring run 30390832059.
CANNED_JOBS='[
  {"name":"Admin eval render + probe (evidence only, not a merge gate)","conclusion":"failure","startedAt":"2026-07-28T19:11:21Z","completedAt":"2026-07-28T19:28:54Z"},
  {"name":"Upgrade smoke (published source series -> local candidate)","conclusion":"skipped","startedAt":"2026-07-28T19:11:14Z","completedAt":"2026-07-28T19:11:13Z"},
  {"name":"Fast checks (milestone/installer/contracts/snapshot/ledger guards)","conclusion":"success","startedAt":"2026-07-28T19:11:11Z","completedAt":"2026-07-28T19:11:31Z"}
]'

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
# Recording stub for \`gh\` (test-only). Logs argv, returns a scripted response.
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
if [[ "\${1:-}" == "run" && "\${2:-}" == "view" ]]; then
  case "\${GH_STUB_MODE:-ok}" in
    ok)
      echo '${CANNED_JOBS}'
      exit 0
      ;;
    empty)
      echo '[]'
      exit 0
      ;;
    nonzero)
      echo "gh stub: simulated failure" >&2
      exit 1
      ;;
  esac
fi
echo "gh stub: unexpected invocation: \$*" >&2
exit 1
STUB
chmod +x "${STUB_BIN_DIR}/gh"

run_script() {
  # Runs the script with the stub PATH and captures stdout/stderr/exit separately.
  local out err rc
  out="${TMPDIR_ROOT}/stdout"
  err="${TMPDIR_ROOT}/stderr"
  set +e
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" "$@" >"$out" 2>"$err"
  rc=$?
  set -e
  echo "$rc"
}

# ---- Test A/B/C: canned run -> table with clamp + no-filter -------------
echo "Test A/B/C: --jobs <id> emits a per-job table; 1053s/17m33s failure row not filtered; negative duration clamped to 0"
: > "$GH_STUB_LOG"
GH_STUB_MODE="ok"
export GH_STUB_MODE
RC=$(run_script --jobs 30390832059 --repo szTheory/sigra)
export GH_STUB_MODE=""
OUT="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC" -eq 0 ]] \
  && echo "$OUT" | grep -qE 'Admin eval render.*failure.*1053s.*17m33s' \
  && echo "$OUT" | grep -qE 'Upgrade smoke.*skipped[[:space:]]+0s[[:space:]]+0m0s' \
  && ! echo "$OUT" | grep -q -- '-1s'; then
  pass "table row present for failing job at 1053s/17m33s; negative duration clamped to 0s (exit ${RC})"
else
  fail "exit=${RC} output=<${OUT}>"
fi

# ---- Test D: unknown flag -> exit 2, zero gh invocations ----------------
echo "Test D: unknown flag -> exit 2, ci-run-metrics: FAIL: unknown arg, ZERO gh invocations"
: > "$GH_STUB_LOG"
RC=$(run_script --bogus-flag)
ERR="$(cat "${TMPDIR_ROOT}/stderr")"
CALL_COUNT_D=$(wc -l <"$GH_STUB_LOG" | tr -d ' ')

if [[ "$RC" -eq 2 ]] \
  && echo "$ERR" | grep -q 'ci-run-metrics: FAIL: unknown arg: --bogus-flag' \
  && [[ "$CALL_COUNT_D" -eq 0 ]]; then
  pass "exit 2, correct message, zero gh calls (fail-closed before any gh invocation)"
else
  fail "exit=${RC} stderr=<${ERR}> gh_call_count=${CALL_COUNT_D}"
fi

# ---- Test E: gh absent from PATH -> non-zero exit, FAIL message ---------
echo "Test E: gh absent from PATH -> non-zero exit, ci-run-metrics: FAIL: message"
EMPTY_PATH_DIR="${TMPDIR_ROOT}/empty-bin"
mkdir -p "$EMPTY_PATH_DIR"
set +e
PATH="${EMPTY_PATH_DIR}:/usr/bin:/bin" bash "$SCRIPT" --jobs 1 >"${TMPDIR_ROOT}/stdout" 2>"${TMPDIR_ROOT}/stderr"
RC_E=$?
set -e
ERR_E="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_E="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_E" -ne 0 ]] && echo "$ERR_E" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_E" ]]; then
  pass "exit non-zero (${RC_E}), FAIL message, no partial stdout"
else
  fail "exit=${RC_E} stderr=<${ERR_E}> stdout=<${OUT_E}>"
fi

# ---- Test F: gh exits non-zero -> non-zero exit, no partial output ------
echo "Test F: gh exits non-zero -> non-zero exit, ci-run-metrics: FAIL: message, no partial table"
: > "$GH_STUB_LOG"
GH_STUB_MODE="nonzero"
export GH_STUB_MODE
RC_F=$(run_script --jobs 30390832059)
export GH_STUB_MODE=""
ERR_F="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_F="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_F" -ne 0 ]] && echo "$ERR_F" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_F" ]]; then
  pass "exit non-zero (${RC_F}) on gh failure, no partial table emitted"
else
  fail "exit=${RC_F} stderr=<${ERR_F}> stdout=<${OUT_F}>"
fi

# ---- Test G: empty job list -> non-zero exit, no partial output ---------
echo "Test G: empty job list -> non-zero exit, ci-run-metrics: FAIL: message, no partial table"
: > "$GH_STUB_LOG"
GH_STUB_MODE="empty"
export GH_STUB_MODE
RC_G=$(run_script --jobs 30390832059)
export GH_STUB_MODE=""
ERR_G="$(cat "${TMPDIR_ROOT}/stderr")"
OUT_G="$(cat "${TMPDIR_ROOT}/stdout")"

if [[ "$RC_G" -ne 0 ]] && echo "$ERR_G" | grep -q 'ci-run-metrics: FAIL:' && [[ -z "$OUT_G" ]]; then
  pass "exit non-zero (${RC_G}) on empty job list, no partial table emitted"
else
  fail "exit=${RC_G} stderr=<${ERR_G}> stdout=<${OUT_G}>"
fi

# ---- Test H: --format json emits valid JSON with same semantics ---------
echo "Test H: --format json emits valid JSON; failure-conclusion job present; negative duration clamped"
: > "$GH_STUB_LOG"
GH_STUB_MODE="ok"
export GH_STUB_MODE
RC_H=$(run_script --jobs 30390832059 --format json)
export GH_STUB_MODE=""
OUT_H="$(cat "${TMPDIR_ROOT}/stdout")"

JSON_OK=0
if echo "$OUT_H" | python3 -c "
import json, sys
data = json.load(sys.stdin)
jobs = {j['name']: j for j in data}
admin = jobs.get('Admin eval render + probe (evidence only, not a merge gate)')
upgrade = jobs.get('Upgrade smoke (published source series -> local candidate)')
assert admin is not None, 'admin eval render job missing'
assert admin['conclusion'] == 'failure', admin
assert admin['duration_seconds'] == 1053, admin
assert upgrade is not None, 'upgrade smoke job missing'
assert upgrade['duration_seconds'] == 0, upgrade
" 2>"${TMPDIR_ROOT}/json-check-err"; then
  JSON_OK=1
fi

if [[ "$RC_H" -eq 0 && "$JSON_OK" -eq 1 ]]; then
  pass "--format json valid, duration/clamp/no-filter semantics match table mode"
else
  fail "exit=${RC_H} json_check=<$(cat "${TMPDIR_ROOT}/json-check-err" 2>/dev/null)> output=<${OUT_H}>"
fi

# ---- Summary -------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "ci-run-metrics.test: FAIL"
  exit 1
fi

echo "ci-run-metrics.test: PASS"
exit 0
