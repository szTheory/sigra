#!/usr/bin/env bash
# Self-test for notify-failure-issue.sh (Phase 222 Plan 02 / D-07).
#
# Hermetic: no real `gh` CLI or network call. A recording stub `gh` is placed
# first on PATH; it logs every invocation's argv and returns a scripted
# response so each case can assert exactly what the script under test called.
#
# Test cases (mirrors the plan's <behavior> block):
#   A: no open issue -> `gh issue create` exactly once, never `gh issue comment`.
#   B: existing open issue #123 -> `gh issue comment 123` exactly once, never
#      `gh issue create` (no spam -- one durable issue accumulates occurrences).
#   C: LABEL/TITLE/BODY unset -> non-zero exit, zero `gh` calls at all
#      (fail-closed, no partial call).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/notify-failure-issue.sh"

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

cat >"${STUB_BIN_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
# Recording stub for `gh` (test-only). Logs argv, returns a scripted response.
set -euo pipefail
echo "$*" >> "${GH_STUB_LOG}"
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
if [[ "${1:-}" == "issue" && ( "${2:-}" == "create" || "${2:-}" == "comment" ) ]]; then
  exit 0
fi
echo "gh stub: unexpected invocation: $*" >&2
exit 1
STUB
chmod +x "${STUB_BIN_DIR}/gh"

# ---- Test A: no open issue -> create-once, never comment ---------------
echo "Test A: no open issue -> gh issue create exactly once, never gh issue comment"
: > "$GH_STUB_LOG"

set +e
PATH="${STUB_BIN_DIR}:${PATH}" \
  GH_STUB_LOG="$GH_STUB_LOG" \
  GH_STUB_ISSUE_NUMBER="" \
  LABEL="release-lane-rot" TITLE="Red main" BODY="run url" GH_TOKEN="stub-token" \
  bash "$SCRIPT" >/dev/null 2>&1
EXIT_A=$?
set -e

CREATE_COUNT_A=$(grep -c '^issue create' "$GH_STUB_LOG" || true)
COMMENT_COUNT_A=$(grep -c '^issue comment' "$GH_STUB_LOG" || true)

if [[ "$EXIT_A" -eq 0 && "$CREATE_COUNT_A" -eq 1 && "$COMMENT_COUNT_A" -eq 0 ]]; then
  pass "Test A: created once, never commented (exit ${EXIT_A})"
else
  fail "Test A: exit=${EXIT_A} create_count=${CREATE_COUNT_A} comment_count=${COMMENT_COUNT_A}"
fi

# ---- Test B: existing open issue -> comment-once, never create ---------
echo "Test B: existing open issue #123 -> gh issue comment 123 exactly once, never gh issue create"
: > "$GH_STUB_LOG"

set +e
PATH="${STUB_BIN_DIR}:${PATH}" \
  GH_STUB_LOG="$GH_STUB_LOG" \
  GH_STUB_ISSUE_NUMBER="123" \
  LABEL="release-lane-rot" TITLE="Red main" BODY="run url" GH_TOKEN="stub-token" \
  bash "$SCRIPT" >/dev/null 2>&1
EXIT_B=$?
set -e

CREATE_COUNT_B=$(grep -c '^issue create' "$GH_STUB_LOG" || true)
COMMENT_COUNT_B=$(grep -c '^issue comment 123' "$GH_STUB_LOG" || true)

if [[ "$EXIT_B" -eq 0 && "$COMMENT_COUNT_B" -eq 1 && "$CREATE_COUNT_B" -eq 0 ]]; then
  pass "Test B: commented on #123 once, never created (exit ${EXIT_B})"
else
  fail "Test B: exit=${EXIT_B} create_count=${CREATE_COUNT_B} comment_count=${COMMENT_COUNT_B}"
fi

# ---- Test C: missing required env -> fail-closed, zero gh calls --------
echo "Test C: LABEL/TITLE/BODY unset -> exits non-zero, zero gh calls (fail-closed)"
: > "$GH_STUB_LOG"

set +e
PATH="${STUB_BIN_DIR}:${PATH}" \
  GH_STUB_LOG="$GH_STUB_LOG" \
  GH_TOKEN="stub-token" \
  bash "$SCRIPT" >/dev/null 2>&1
EXIT_C=$?
set -e

CALL_COUNT_C=$(wc -l <"$GH_STUB_LOG" | tr -d ' ')

if [[ "$EXIT_C" -ne 0 && "$CALL_COUNT_C" -eq 0 ]]; then
  pass "Test C: exited non-zero (${EXIT_C}) with zero gh calls (fail-closed, no partial call)"
else
  fail "Test C: exit=${EXIT_C} gh_call_count=${CALL_COUNT_C}"
fi

# ---- Summary -------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "notify-failure-issue.test: FAIL"
  exit 1
fi

echo "notify-failure-issue.test: PASS"
exit 0
