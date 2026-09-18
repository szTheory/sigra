#!/usr/bin/env bash
# Self-test for ensure-github-pages-legacy-branch.sh (Phase 240 Plan 01 / GREEN-05 / SC-3).
#
# Hermetic: no real `gh` CLI and no network call. A recording stub `gh` is placed
# first on PATH per invocation (never exported globally); it appends every
# invocation's argv to $FAKE_GH_LOG and then emits a scripted HTTP envelope
# selected by $FAKE_MODE, so each case can assert both the script's exit code
# and exactly which calls it did (and did not) make.
#
# The stub reproduces all four observable channels of real `gh` 2.95.0, each
# live-probed and recorded in 240-RESEARCH.md §4:
#   (1) exit 1 on ANY HTTP failure (rc cannot discriminate 403/404/500),
#   (2) the status line as stdout line 1, wire version literally `HTTP/2.0`,
#   (3) the JSON error body on stdout after a blank line, no trailing newline,
#   (4) `gh: <message> (HTTP <code>)` on stderr.
#
# Test cases (mirror the plan's <behavior> blocks), by FAKE_MODE:
#   A: get_200_already_gh_pages (default `ok`) -- GET 200, source gh-pages / ->
#      exit 0, "already gh-pages /", and NO PUT and NO POST against /pages
#      (the /pages/builds trigger is allowed).
#   B: get_404 -- GET 404 -> exactly one POST create against /pages, exit 0.
#   C: get_403 -- GET 403 (all four channels) -> exit 1, body echoed to stderr,
#      and ZERO POST-create calls. This is the D-15 any-error->create guard.
#   D: get_500 -- GET 500 whose body contains the bare digits 403 -> exit 1.
#      This is the D-17 unanchored-grep false-positive guard.
#   E: build_type_workflow -- GET 200, build_type=workflow -> exit 0,
#      "not changing", no PUT.
#   F: no_token -- GH_TOKEN and GITHUB_TOKEN unset -> exit 0, skip message,
#      and ZERO gh calls logged (D-22 early exit preserved).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ensure-github-pages-legacy-branch.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMP=""
# shellcheck disable=SC2329
cleanup() { [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT
TMP="$(mktemp -d)"
mkdir -p "$TMP/bin"

cat >"$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Recording fake `gh` (test-only). Logs argv, then emits a scripted HTTP
# envelope byte-shaped like real gh 2.95.0 (240-RESEARCH.md §4).
set -uo pipefail
printf '%s\n' "$*" >>"${FAKE_GH_LOG}"

args="$*"
mode="${FAKE_MODE:-ok}"

emit_403() {
  # All four channels of a real 403, verbatim per D-21 / RESEARCH §5.
  printf 'HTTP/2.0 403 Forbidden\r\n'
  printf 'Content-Type: application/json; charset=utf-8\r\n'
  printf '\r\n'
  printf '{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/pages/pages#update-information-about-a-apiname-pages-site","status":"403"}'
  echo 'gh: Resource not accessible by integration (HTTP 403)' >&2
  exit 1
}

emit_200_body() {
  printf 'HTTP/2.0 200 OK\r\n'
  printf 'Content-Type: application/json; charset=utf-8\r\n'
  printf '\r\n'
  printf '%s' "$1"
  exit 0
}

# --- /pages/builds: always a no-op success (the D-22 tolerated swallow) ------
case "$args" in
  *"/pages/builds"*) exit 0 ;;
esac

# --- PUT /pages -------------------------------------------------------------
case "$args" in
  *"--method PUT"*)
    case "$mode" in
      put_403) emit_403 ;;
      put_422)
        printf 'HTTP/2.0 422 Unprocessable Entity\r\n'
        printf 'Content-Type: application/json; charset=utf-8\r\n'
        printf '\r\n'
        printf '{"message":"Invalid request.","documentation_url":"https://docs.github.com/rest","status":"422"}'
        echo 'gh: Invalid request. (HTTP 422)' >&2
        exit 1
        ;;
      put_500)
        printf 'HTTP/2.0 500 Internal Server Error\r\n'
        printf 'Content-Type: application/json; charset=utf-8\r\n'
        printf '\r\n'
        printf '{"message":"Server Error","documentation_url":"https://docs.github.com/rest","status":"500"}'
        echo 'gh: Server Error (HTTP 500)' >&2
        exit 1
        ;;
      *)
        # put_204: success is 204 No Content with an EMPTY body -- the status
        # line is the only signal (D-18).
        printf 'HTTP/2.0 204 No Content\r\n'
        printf 'X-GitHub-Request-Id: FEED:BEEF:0403:0404\r\n'
        printf '\r\n'
        exit 0
        ;;
    esac
    ;;
esac

# --- POST /pages (create) ---------------------------------------------------
case "$args" in
  *"--method POST"*) exit 0 ;;
esac

# --- GET /pages -------------------------------------------------------------
case "$mode" in
  get_404)
    printf 'HTTP/2.0 404 Not Found\r\n'
    printf 'Content-Type: application/json; charset=utf-8\r\n'
    printf '\r\n'
    printf '{"message":"Not Found","documentation_url":"https://docs.github.com/rest/pages/pages#get-a-apiname-pages-site","status":"404"}'
    echo 'gh: Not Found (HTTP 404)' >&2
    exit 1
    ;;
  get_403) emit_403 ;;
  get_500)
    # The body deliberately carries the bare digits 403 (in a request id and a
    # retry hint) so the D-17 unanchored-grep false positive is exercised.
    printf 'HTTP/2.0 500 Internal Server Error\r\n'
    printf 'Content-Type: application/json; charset=utf-8\r\n'
    printf 'X-GitHub-Request-Id: DEAD:0403:BEEF\r\n'
    printf '\r\n'
    printf '{"message":"Server Error (ref 403); Resource not accessible by integration was not the cause","documentation_url":"https://docs.github.com/rest","status":"500"}'
    echo 'gh: Server Error (HTTP 500)' >&2
    exit 1
    ;;
  build_type_workflow)
    emit_200_body '{"status":"built","build_type":"workflow","source":{"branch":"main","path":"/"}}'
    ;;
  put_204|put_403|put_422|put_500)
    # Reach the PUT: the configured source is main, not gh-pages.
    emit_200_body '{"status":"built","build_type":"legacy","source":{"branch":"main","path":"/"}}'
    ;;
  *)
    emit_200_body '{"status":"built","build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}'
    ;;
esac
STUB
chmod +x "$TMP/bin/gh"

# run_case <mode> -- runs the script under the stub, recording exit code,
# stdout, stderr and the gh call log per mode. Never aborts on failure.
RC=0
run_case() {
  local mode="$1"
  : >"$TMP/$mode.calls"
  set +e
  FAKE_MODE="$mode" FAKE_GH_LOG="$TMP/$mode.calls" PATH="$TMP/bin:$PATH" \
    GITHUB_REPOSITORY=owner/name GH_TOKEN=stub \
    bash "$SCRIPT" >"$TMP/$mode.out" 2>"$TMP/$mode.err"
  RC=$?
  set -e
}

# Count calls against repos/owner/name/pages carrying <method>, excluding the
# /pages/builds trigger.
count_pages_calls() {
  grep -c -- "repos/owner/name/pages --method $2" "$TMP/$1.calls" || true
}

# ---- Case A: get_200_already_gh_pages (default happy path) ----------------
run_case get_200_already_gh_pages
if [[ "$RC" -eq 0 ]] \
  && grep -q 'already gh-pages /' "$TMP/get_200_already_gh_pages.out" \
  && [[ "$(count_pages_calls get_200_already_gh_pages PUT)" -eq 0 ]] \
  && [[ "$(count_pages_calls get_200_already_gh_pages POST)" -eq 0 ]]; then
  pass "Case A: GET 200 already gh-pages / -> exit 0, no PUT, no POST-create"
else
  fail "Case A: exit=${RC} out=$(cat "$TMP/get_200_already_gh_pages.out") calls=$(cat "$TMP/get_200_already_gh_pages.calls")"
fi

# ---- Case B: get_404 -> exactly one POST create ---------------------------
run_case get_404
if [[ "$RC" -eq 0 ]] && [[ "$(count_pages_calls get_404 POST)" -eq 1 ]]; then
  pass "Case B: GET 404 -> exactly one POST create, exit 0"
else
  fail "Case B: exit=${RC} post_count=$(count_pages_calls get_404 POST) calls=$(cat "$TMP/get_404.calls")"
fi

# ---- Case C: get_403 -> loud exit 1, zero POST-create (D-15 guard) --------
run_case get_403
if [[ "$RC" -eq 1 ]] \
  && grep -q 'refusing to guess' "$TMP/get_403.err" \
  && grep -q 'Resource not accessible by integration' "$TMP/get_403.err" \
  && [[ "$(count_pages_calls get_403 POST)" -eq 0 ]]; then
  pass "Case C: GET 403 -> exit 1, body on stderr, zero POST-create"
else
  fail "Case C: exit=${RC} err=$(cat "$TMP/get_403.err") post_count=$(count_pages_calls get_403 POST)"
fi

# ---- Case D: get_500 with 403 in the body -> exit 1 (D-17 guard) ----------
run_case get_500
if [[ "$RC" -eq 1 ]] && grep -q "GET /pages returned '500'" "$TMP/get_500.err"; then
  pass "Case D: GET 500 whose body contains '403' -> exit 1 (no false positive)"
else
  fail "Case D: exit=${RC} err=$(cat "$TMP/get_500.err")"
fi

# ---- Case E: build_type_workflow -> exit 0, no PUT ------------------------
run_case build_type_workflow
if [[ "$RC" -eq 0 ]] \
  && grep -q 'not changing' "$TMP/build_type_workflow.out" \
  && [[ "$(count_pages_calls build_type_workflow PUT)" -eq 0 ]]; then
  pass "Case E: build_type=workflow -> exit 0, not changing, no PUT"
else
  fail "Case E: exit=${RC} out=$(cat "$TMP/build_type_workflow.out")"
fi

# ---- Case F: no_token -> exit 0, zero gh calls ----------------------------
: >"$TMP/no_token.calls"
set +e
env -u GH_TOKEN -u GITHUB_TOKEN \
  FAKE_MODE=no_token FAKE_GH_LOG="$TMP/no_token.calls" PATH="$TMP/bin:$PATH" \
  GITHUB_REPOSITORY=owner/name \
  bash "$SCRIPT" >"$TMP/no_token.out" 2>"$TMP/no_token.err"
RC=$?
set -e
if [[ "$RC" -eq 0 ]] \
  && grep -q 'no GH_TOKEN/GITHUB_TOKEN; skip.' "$TMP/no_token.out" \
  && [[ ! -s "$TMP/no_token.calls" ]]; then
  pass "Case F: no token -> exit 0, skip message, zero gh calls"
else
  fail "Case F: exit=${RC} out=$(cat "$TMP/no_token.out") calls=$(cat "$TMP/no_token.calls")"
fi

# ---- Summary -------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "ensure-github-pages-legacy-branch.test: FAIL"
  exit 1
fi

echo "ensure-github-pages-legacy-branch.test: PASS"
exit 0
