#!/usr/bin/env bash
# Self-test for wait-for-ci-gate.sh (Phase 231 / DX-05 / D-20, D-21).
#
# Hermetic: no real `gh` CLI and no network call. A recording stub `gh` is placed
# first on PATH; it dispatches on argv (`run list` / `run view` / `workflow run`) and
# logs every invocation so each case can assert both the exit status/output AND how
# many `gh` round-trips it made -- the same combination of forms used by
# ci-demotion-observer.test.sh (unquoted heredoc, response varies per call) and
# notify-failure-issue.test.sh (argv dispatch).
#
# `run list` responses are driven by a per-invocation counter so a case can script a
# different payload for attempt 1, attempt 2, etc. (multi-poll cases B/C/D/E/J).
# `run view --json jobs ...` and `run view --json url ...` respond from separate
# fixed files per test case (the script under test always resolves the ci-gate
# conclusion, then the run url, as two distinct `gh run view` calls -- ported
# unchanged from the original inline loop).
#
# Test cases (mirrors the plan's <behavior> block, lettered A onward):
#   A: green on the first poll -> exit 0, exactly one `gh run list` call, run URL
#      echoed.
#   B: green after 2 polls -> the loop keeps polling while status != "completed" and
#      exits 0 once `ci-gate` reports success, with exactly 2 `gh run list` calls.
#   C: `ci-gate` never green across all listed runs -> attempts exhaust, exit 1,
#      "Timed out waiting for ci-gate" and the attempt count in the output.
#   D: zero runs listed every attempt -> the dispatch fires exactly once, at the
#      configured --dispatch-after attempt, and never a second time.
#   E: --no-dispatch with zero runs -> zero `gh workflow run` calls, and exhaustion
#      still exits 1 (never "nothing to wait for, so green").
#   F: `gh` returns non-zero -> exit 1, not a silent pass.
#   G: `gh` absent from PATH -> non-zero exit with a message naming `gh`.
#   H: unknown flag -> exit 2 with ZERO `gh` invocations.
#   I: --from-json reaches the same PASS verdict with ZERO `gh` invocations.
#   J: positive control -- --max-attempts 2 --wait-seconds 0 completes in well under
#      5 seconds and makes exactly 2 `gh run list` calls, proving the timing flags are
#      wired (and keeping this file admissible in fast_checks).
#   K: a --from-json payload that is not a JSON array -> exit 1, fail-closed
#      (the non-vacuity / shape-assertion floor named in the script's contract).
#
# No network access and no GH_TOKEN are required or read anywhere in this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/wait-for-ci-gate.sh"
WORKFLOW="${SCRIPT_DIR}/../../.github/workflows/release-please.yml"
TEST_SHA="0123456789abcdef0123456789abcdef01234567"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

if ! grep -qx 'MAX_ATTEMPTS=120' "$SCRIPT" \
   || ! grep -qx 'WAIT_SECONDS=30' "$SCRIPT" \
   || ! grep -q 'timeout-minutes: 75' "$WORKFLOW" \
   || ! grep -q 'wait-for-ci-gate.sh --max-attempts 120' "$WORKFLOW"; then
  echo "FATAL: release gate polling budget changed from 120 attempts / 30 seconds / 75 minutes" >&2
  exit 2
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then rm -rf "$TMPDIR_ROOT"; fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
LIST_COUNTER="${TMPDIR_ROOT}/list-counter"
VIEW_JOBS_PAYLOAD="${TMPDIR_ROOT}/view-jobs.txt"
VIEW_URL_PAYLOAD="${TMPDIR_ROOT}/view-url.txt"
: > "$GH_STUB_LOG"

# Recording, argv-dispatching stub for `gh` (test-only). `run list` responses are
# driven by a per-invocation counter so multi-attempt cases can script a different
# payload per attempt; `run view` responses come from fixed per-case files, selected
# by which --json flavor was requested (jobs vs url) -- both are real, distinct calls
# the script under test makes.
cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
set -euo pipefail
ARGS="\$*"
echo "\$ARGS" >> "${GH_STUB_LOG}"
if [[ -n "\${GH_STUB_FAIL:-}" ]]; then
  echo "gh: simulated failure" >&2
  exit 1
fi
if [[ "\${1:-}" == "run" && "\${2:-}" == "list" ]]; then
  n=0
  [[ -f "${LIST_COUNTER}" ]] && n="\$(cat "${LIST_COUNTER}")"
  n=\$((n + 1))
  echo "\$n" > "${LIST_COUNTER}"
  f="${TMPDIR_ROOT}/list-\${n}.json"
  [[ -f "\$f" ]] || f="${TMPDIR_ROOT}/list-last.json"
  cat "\$f"
  exit 0
fi
if [[ "\${1:-}" == "run" && "\${2:-}" == "view" ]]; then
  if [[ "\$ARGS" == *"--json jobs"* ]]; then
    cat "${VIEW_JOBS_PAYLOAD}"
  elif [[ "\$ARGS" == *"--json url"* ]]; then
    cat "${VIEW_URL_PAYLOAD}"
  else
    echo "gh stub: unexpected run view invocation: \$ARGS" >&2
    exit 1
  fi
  exit 0
fi
if [[ "\${1:-}" == "workflow" && "\${2:-}" == "run" ]]; then
  exit 0
fi
echo "gh stub: unexpected invocation: \$ARGS" >&2
exit 1
STUB
chmod +x "${STUB_BIN_DIR}/gh"

# NOTE: `grep -c .` PRINTS 0 and EXITS 1 on no match, so `|| echo 0` would emit a
# second zero and break every later arithmetic comparison. Swallow the exit status
# instead of appending a fallback line.
gh_call_count() { local n; n="$(grep -c . "$GH_STUB_LOG" 2>/dev/null || true)"; echo "${n:-0}"; }
list_call_count() { local n; n="$(grep -c '^run list' "$GH_STUB_LOG" 2>/dev/null || true)"; echo "${n:-0}"; }
dispatch_call_count() { local n; n="$(grep -c '^workflow run' "$GH_STUB_LOG" 2>/dev/null || true)"; echo "${n:-0}"; }

reset_fixtures() {
  rm -f "${TMPDIR_ROOT}"/list-*.json "$LIST_COUNTER" "$VIEW_JOBS_PAYLOAD" "$VIEW_URL_PAYLOAD"
  : > "$GH_STUB_LOG"
}

run_gate() {
  set +e
  OUT="$(PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" "$@" 2>&1)"
  RC=$?
  set -e
}

run_gate_capture() {
  set +e
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" "$@" >"${TMPDIR_ROOT}/gate.stdout" 2>"${TMPDIR_ROOT}/gate.stderr"
  RC=$?
  set -e
  JSON_OUT="$(cat "${TMPDIR_ROOT}/gate.stdout")"
  GATE_ERR="$(cat "${TMPDIR_ROOT}/gate.stderr")"
}

# ---- A: green on first poll -> exit 0, exactly one `gh run list` call ------------
echo "Test A: green on first poll -> exit 0, one gh run list call, run URL echoed"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":111,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"success","url":"https://github.com/szTheory/sigra/actions/runs/111","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
printf 'success' > "$VIEW_JOBS_PAYLOAD"
printf 'https://github.com/szTheory/sigra/actions/runs/111' > "$VIEW_URL_PAYLOAD"
run_gate --sha "$TEST_SHA" --repo test/repo --workflow ci.yml --max-attempts 5 --wait-seconds 0 --no-dispatch
if [[ "$RC" -eq 0 ]] && grep -q "https://github.com/szTheory/sigra/actions/runs/111" <<<"$OUT" \
   && [[ "$(list_call_count)" -eq 1 ]] \
   && grep -q -- '--json databaseId,headSha,status,conclusion,url,createdAt,updatedAt' "$GH_STUB_LOG"; then
  pass "A: exit 0, run URL echoed, exactly 1 gh run list call"
else
  fail "A: rc=${RC}, list calls=$(list_call_count), output: ${OUT}"
fi

# ---- B: green after 2 polls -> keeps polling while status != completed -----------
echo "Test B: green after 2 polls -> exit 0, exactly 2 gh run list calls"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-1.json" <<'JSON'
[{"databaseId":222,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"in_progress","conclusion":null,"url":"https://github.com/szTheory/sigra/actions/runs/222","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:01:00Z"}]
JSON
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":222,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"success","url":"https://github.com/szTheory/sigra/actions/runs/222","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
printf 'success' > "$VIEW_JOBS_PAYLOAD"
printf 'https://github.com/szTheory/sigra/actions/runs/222' > "$VIEW_URL_PAYLOAD"
run_gate --sha "$TEST_SHA" --repo test/repo --max-attempts 5 --wait-seconds 0 --no-dispatch
if [[ "$RC" -eq 0 ]] && grep -q "still running" <<<"$OUT" \
   && grep -q "runs/222" <<<"$OUT" && [[ "$(list_call_count)" -eq 2 ]]; then
  pass "B: exit 0 after polling past an incomplete run, exactly 2 gh run list calls"
else
  fail "B: rc=${RC}, list calls=$(list_call_count), output: ${OUT}"
fi

# ---- C: ci-gate never green -> exhaust, exit 1, names the attempt count ----------
echo "Test C: ci-gate never green across all listed runs -> exit 1, attempt count named"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":333,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"failure","url":"https://github.com/szTheory/sigra/actions/runs/333","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
printf 'failure' > "$VIEW_JOBS_PAYLOAD"
printf 'https://github.com/szTheory/sigra/actions/runs/333' > "$VIEW_URL_PAYLOAD"
run_gate --sha "$TEST_SHA" --repo test/repo --max-attempts 3 --wait-seconds 0 --no-dispatch
if [[ "$RC" -eq 1 ]] && grep -q "Timed out waiting for ci-gate" <<<"$OUT" \
   && grep -q "3 attempts" <<<"$OUT" && [[ "$(list_call_count)" -eq 3 ]]; then
  pass "C: exit 1, 'Timed out waiting for ci-gate' and the attempt count in the output"
else
  fail "C: rc=${RC}, list calls=$(list_call_count), output: ${OUT}"
fi

# ---- D: zero runs listed -> dispatch fires exactly once, at --dispatch-after -----
echo "Test D: zero runs every attempt -> dispatch fires exactly once at --dispatch-after"
reset_fixtures
printf '[]' > "${TMPDIR_ROOT}/list-last.json"
run_gate --sha "$TEST_SHA" --repo test/repo --tag v1.2.3 --max-attempts 5 --wait-seconds 0 --dispatch-after 3
if [[ "$RC" -eq 1 ]] && [[ "$(dispatch_call_count)" -eq 1 ]] \
   && grep -q "Dispatched ci.yml on tag v1.2.3" <<<"$OUT"; then
  pass "D: exactly 1 dispatch call, fired at attempt 3, never a second time"
else
  fail "D: rc=${RC}, dispatch calls=$(dispatch_call_count), output: ${OUT}"
fi

# ---- E: --no-dispatch with zero runs -> zero dispatch calls, exhaustion exit 1 ---
echo "Test E: --no-dispatch with zero runs -> zero gh workflow run calls, exit 1"
reset_fixtures
printf '[]' > "${TMPDIR_ROOT}/list-last.json"
run_gate --sha "$TEST_SHA" --repo test/repo --tag v1.2.3 --max-attempts 3 --wait-seconds 0 --dispatch-after 2 --no-dispatch
if [[ "$RC" -eq 1 ]] && [[ "$(dispatch_call_count)" -eq 0 ]] \
   && grep -q "the parse broke, this is not a pass" <<<"$OUT"; then
  pass "E: zero dispatch calls, exhaustion never reads as 'nothing to wait for, so green'"
else
  fail "E: rc=${RC}, dispatch calls=$(dispatch_call_count), output: ${OUT}"
fi

# ---- F: gh returns non-zero -> exit 1, not a silent pass -------------------------
echo "Test F: gh returns non-zero -> exit 1"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":444,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"success","url":"https://x/444","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
set +e
OUT_F="$(GH_STUB_FAIL=1 PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --sha "$TEST_SHA" --repo test/repo --max-attempts 2 --wait-seconds 0 --no-dispatch 2>&1)"
RC_F=$?
set -e
if [[ "$RC_F" -eq 1 ]]; then
  pass "F: exit 1 when gh fails, not a silent pass"
else
  fail "F: rc=${RC_F}, output: ${OUT_F}"
fi

# ---- G: gh absent from PATH -> non-zero exit naming gh ---------------------------
# Resolve bash's own absolute path FIRST -- `PATH="$EMPTY_BIN" bash ...` would fail to
# locate "bash" itself (the assignment-prefix PATH applies to the command lookup too),
# which is a shell-resolution artifact of this test harness, not a real signal.
echo "Test G: gh absent from PATH -> non-zero exit, message names gh"
EMPTY_BIN="${TMPDIR_ROOT}/emptybin"; mkdir -p "$EMPTY_BIN"
BASH_BIN="$(command -v bash)"
set +e
OUT_G="$(PATH="$EMPTY_BIN" "$BASH_BIN" "$SCRIPT" --sha "$TEST_SHA" --repo test/repo --max-attempts 2 --wait-seconds 0 --no-dispatch 2>&1)"
RC_G=$?
set -e
if [[ "$RC_G" -ne 0 ]] && grep -qi "gh CLI not found on PATH" <<<"$OUT_G"; then
  pass "G: non-zero exit, message names gh"
else
  fail "G: rc=${RC_G}, output: ${OUT_G}"
fi

# ---- H: unknown flag -> exit 2, zero gh invocations ------------------------------
echo "Test H: unknown flag -> exit 2, zero gh invocations"
reset_fixtures
run_gate --bogus
if [[ "$RC" -eq 2 ]] && [[ "$(gh_call_count)" -eq 0 ]]; then
  pass "H: exit 2 before any gh round-trip"
else
  fail "H: rc=${RC}, gh calls=$(gh_call_count), output: ${OUT}"
fi

# ---- I: --from-json -> same PASS verdict, ZERO gh invocations --------------------
echo "Test I: --from-json reaches the same verdict with zero gh invocations"
reset_fixtures
FROM_JSON_FILE="${TMPDIR_ROOT}/from.json"
cat > "$FROM_JSON_FILE" <<'JSON'
[{"databaseId":555,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"success","ci_gate_conclusion":"success","url":"https://github.com/szTheory/sigra/actions/runs/555","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
run_gate --sha "$TEST_SHA" --repo test/repo --from-json "$FROM_JSON_FILE" --no-dispatch --format json
if [[ "$RC" -eq 0 ]] && [[ "$(gh_call_count)" -eq 0 ]] \
   && jq -e --arg sha "$TEST_SHA" '.verdict == "PASS" and .gate_verdict == "PASS" and .sha == $sha and .head_sha == $sha and .run_id == 555 and .run_url == "https://github.com/szTheory/sigra/actions/runs/555" and .created_at == "2026-07-29T00:00:00Z" and .updated_at == "2026-07-29T00:05:00Z" and .attempts == 1' >/dev/null 2>&1 <<<"$OUT"; then
  pass "I: --from-json emitted a valid PASS verdict with zero gh calls"
else
  fail "I: rc=${RC}, gh calls=$(gh_call_count), output: ${OUT}"
fi

# ---- J: positive control -- flags wired, completes fast --------------------------
echo "Test J: --max-attempts 2 --wait-seconds 0 completes in well under 5s, 2 list calls"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":666,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"failure","url":"https://x/666","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
printf 'failure' > "$VIEW_JOBS_PAYLOAD"
printf 'https://x/666' > "$VIEW_URL_PAYLOAD"
START_S="$SECONDS"
run_gate --sha "$TEST_SHA" --repo test/repo --max-attempts 2 --wait-seconds 0 --no-dispatch
ELAPSED=$((SECONDS - START_S))
if [[ "$RC" -eq 1 ]] && [[ "$(list_call_count)" -eq 2 ]] && [[ "$ELAPSED" -lt 5 ]]; then
  pass "J: exactly 2 gh run list calls (max-attempts respected), elapsed ${ELAPSED}s < 5s"
else
  fail "J: rc=${RC}, list calls=$(list_call_count), elapsed=${ELAPSED}s, output: ${OUT}"
fi

# ---- K: --from-json payload that is not a JSON array -> exit 1 -------------------
echo "Test K: --from-json payload that is not a JSON array -> exit 1, fail-closed"
reset_fixtures
NOT_AN_ARRAY_FILE="${TMPDIR_ROOT}/not-array.json"
printf '{"databaseId":777}' > "$NOT_AN_ARRAY_FILE"
run_gate --sha "$TEST_SHA" --repo test/repo --from-json "$NOT_AN_ARRAY_FILE" --no-dispatch
if [[ "$RC" -eq 1 ]] && grep -q "the parse broke, this is not a pass" <<<"$OUT" \
   && [[ "$(gh_call_count)" -eq 0 ]]; then
  pass "K: exit 1, fail-closed on a non-array --from-json payload, zero gh calls"
else
  fail "K: rc=${RC}, gh calls=$(gh_call_count), output: ${OUT}"
fi

# ---- L: a run filtered by commit but reporting another headSha is rejected --------
echo "Test L: mismatched headSha is rejected before inspecting ci-gate"
reset_fixtures
MISMATCH_FILE="${TMPDIR_ROOT}/mismatched-head.json"
cat > "$MISMATCH_FILE" <<'JSON'
[{"databaseId":888,"headSha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","status":"completed","conclusion":"success","ci_gate_conclusion":"success","url":"https://github.com/szTheory/sigra/actions/runs/888","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
run_gate --sha "$TEST_SHA" --repo test/repo --from-json "$MISMATCH_FILE" --no-dispatch
if [[ "$RC" -eq 1 ]] && grep -q "headSha that differs" <<<"$OUT" && [[ "$(gh_call_count)" -eq 0 ]]; then
  pass "L: mismatched headSha fails closed before any ci-gate inspection"
else
  fail "L: rc=${RC}, gh calls=$(gh_call_count), output: ${OUT}"
fi

# ---- M: required identity/timestamp metadata cannot be absent ---------------------
echo "Test M: missing headSha or timestamps are rejected"
reset_fixtures
MISSING_METADATA_FILE="${TMPDIR_ROOT}/missing-metadata.json"
printf '[{"databaseId":889,"status":"completed","ci_gate_conclusion":"success","url":"https://x/889","createdAt":"2026-07-29T00:00:00Z"}]' > "$MISSING_METADATA_FILE"
run_gate --sha "$TEST_SHA" --repo test/repo --from-json "$MISSING_METADATA_FILE" --no-dispatch
if [[ "$RC" -eq 1 ]] && grep -q "missing metadata" <<<"$OUT" && [[ "$(gh_call_count)" -eq 0 ]]; then
  pass "M: missing run identity/timestamp metadata fails closed"
else
  fail "M: rc=${RC}, gh calls=$(gh_call_count), output: ${OUT}"
fi

# ---- N: failed poll reports the actual observed CI run identity ------------------
echo "Test N: JSON failure output identifies the observed CI run, not the release run"
reset_fixtures
cat > "${TMPDIR_ROOT}/list-last.json" <<'JSON'
[{"databaseId":990,"headSha":"0123456789abcdef0123456789abcdef01234567","status":"completed","conclusion":"failure","url":"https://github.com/szTheory/sigra/actions/runs/990","createdAt":"2026-07-29T00:00:00Z","updatedAt":"2026-07-29T00:05:00Z"}]
JSON
printf 'failure' > "$VIEW_JOBS_PAYLOAD"
printf 'https://github.com/szTheory/sigra/actions/runs/990' > "$VIEW_URL_PAYLOAD"
run_gate_capture --sha "$TEST_SHA" --repo test/repo --max-attempts 1 --wait-seconds 0 --no-dispatch --format json
if [[ "$RC" -eq 1 ]] \
   && jq -e --arg sha "$TEST_SHA" '.sha == $sha and .run_id == 990 and .run_url == "https://github.com/szTheory/sigra/actions/runs/990" and .head_sha == $sha and .attempts == 1 and .verdict == "FAIL" and .gate_verdict == "FAIL"' >/dev/null 2>&1 <<<"$JSON_OUT"; then
  pass "N: failure JSON preserves the real CI run identity and release SHA"
else
  fail "N: rc=${RC}, JSON=${JSON_OUT}, stderr=${GATE_ERR}"
fi

# ---- O: failure before observing a CI run represents identity as unavailable ------
echo "Test O: no observed CI run is represented with null identity fields"
reset_fixtures
printf '[]' > "${TMPDIR_ROOT}/list-last.json"
run_gate_capture --sha "$TEST_SHA" --repo test/repo --max-attempts 1 --wait-seconds 0 --no-dispatch --format json
if [[ "$RC" -eq 1 ]] \
   && jq -e --arg sha "$TEST_SHA" '.sha == $sha and .run_id == null and .run_url == null and .head_sha == null and .attempts == 1 and .verdict == "FAIL"' >/dev/null 2>&1 <<<"$JSON_OUT"; then
  pass "O: failure JSON does not invent a run identity when none was observed"
else
  fail "O: rc=${RC}, JSON=${JSON_OUT}, stderr=${GATE_ERR}"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "wait-for-ci-gate.test: FAIL"
  exit 1
fi
echo "wait-for-ci-gate.test: PASS"
