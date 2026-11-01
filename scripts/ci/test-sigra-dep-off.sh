#!/usr/bin/env bash
# Hermetic regression coverage for the destructive boundary in sigra-dep-off.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/sigra-dep-off.sh"
TMP_ROOT=""
PASS=0
FAIL=0

cleanup() {
  [[ -z "${TMP_ROOT}" || ! -d "${TMP_ROOT}" ]] || rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

[[ -f "${SCRIPT}" ]] || { echo "FAIL: dep-off harness missing at ${SCRIPT}" >&2; exit 1; }

TMP_ROOT="$(mktemp -d)"

setup_fixture() {
  local name="$1"
  local fixture="${TMP_ROOT}/${name}"

  mkdir -p \
    "${fixture}/scripts/ci" \
    "${fixture}/bin" \
    "${fixture}/_build/test/lib/threadline" \
    "${fixture}/_build/test/lib/sigra/ebin"
  cp "${SCRIPT}" "${fixture}/scripts/ci/sigra-dep-off.sh"
  chmod +x "${fixture}/scripts/ci/sigra-dep-off.sh"
  printf '{:threadline, {:hex, :threadline, "1.0.0", "locked", [], [], "hexpm", "checksum"}}\n' > "${fixture}/mix.lock"
  printf 'original-build\n' > "${fixture}/_build/test/lib/threadline/.built"
  printf 'forwarder-present\n' > "${fixture}/_build/test/lib/sigra/ebin/threadline-forwarder.beam"
  mkdir -p "${fixture}/test-results"
  printf 'main-report\n' > "${fixture}/test-results/ci-exunit-timing-main.json"

  cat > "${fixture}/bin/mix" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "deps.unlock threadline")
    printf 'mutated-by-dep-off\n' > mix.lock
    ;;
  "deps.clean threadline --build")
    rm -rf _build/test/lib/threadline
    ;;
  "compile --warnings-as-errors --no-deps-check")
    rm -f _build/test/lib/sigra/ebin/threadline-forwarder.beam
    [[ "${SIGRA_DEP_OFF_FORCE_FAILURE:-0}" != "1" ]] || exit 42
    ;;
  "test --only threadline_guard --no-deps-check")
    [[ "${SIGRA_EXUNIT_TIMING_INVOCATION:-}" == "threadline_guard" ]] || {
      printf 'threadline-guard-report\n' > "${SIGRA_EXUNIT_TIMING_JSON:-missing-report-path}"
      echo "dependency-off test did not receive its invocation identity" >&2
      exit 98
    }
    [[ "${SIGRA_EXUNIT_TIMING_JSON:-}" == "${PWD}/test-results/ci-exunit-timing-threadline-guard.json" ]] || {
      printf 'threadline-guard-report\n' > "${SIGRA_EXUNIT_TIMING_JSON:-missing-report-path}"
      echo "dependency-off test did not receive its own report path" >&2
      exit 97
    }
    printf 'threadline-guard-report\n' > "${SIGRA_EXUNIT_TIMING_JSON}"
    if [[ "${SIGRA_DEP_OFF_INTERRUPT:-0}" == "1" ]]; then
      kill -INT "$PPID"
      sleep 0.1
    fi
    [[ "${SIGRA_DEP_OFF_FORCE_TEST_FAILURE:-0}" != "1" ]] || exit 24
    ;;
  "deps.get --check-locked")
    [[ "${SIGRA_DEP_OFF_FORCE_RESTORE_FAILURE:-0}" != "1" ]] || exit 31
    ;;
  "compile --force --warnings-as-errors")
    mkdir -p _build/test/lib/threadline
    printf 'restored-build\n' > _build/test/lib/threadline/.built
    printf 'forwarder-present\n' > _build/test/lib/sigra/ebin/threadline-forwarder.beam
    ;;
  *)
    echo "unexpected mix invocation: $*" >&2
    exit 99
    ;;
esac
STUB
  chmod +x "${fixture}/bin/mix"
  printf '%s\n' "${fixture}"
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local force_failure="$3"
  local force_test_failure="${4:-0}"
  local force_restore_failure="${5:-0}"
  local interrupt="${6:-0}"
  local fixture lock_before lock_after status restored_forwarder

  fixture="$(setup_fixture "${name}")"
  lock_before="$(shasum -a 256 "${fixture}/mix.lock" | awk '{print $1}')"

  set +e
  (
    cd "${fixture}"
    PATH="${fixture}/bin:${PATH}" SIGRA_DEP_OFF_FORCE_FAILURE="${force_failure}" SIGRA_DEP_OFF_FORCE_TEST_FAILURE="${force_test_failure}" \
      SIGRA_DEP_OFF_FORCE_RESTORE_FAILURE="${force_restore_failure}" SIGRA_DEP_OFF_INTERRUPT="${interrupt}" \
      SIGRA_EXUNIT_TIMING_JSON="${fixture}/test-results/ci-exunit-timing-main.json" \
      SIGRA_EXUNIT_TIMING_INVOCATION="main" \
      bash scripts/ci/sigra-dep-off.sh
  )
  status=$?
  set -e

  lock_after="$(shasum -a 256 "${fixture}/mix.lock" | awk '{print $1}')"

  [[ "${status}" -eq "${expected_status}" ]] \
    && pass "${name}: exit status ${expected_status} is preserved" \
    || fail "${name}: exit status ${status}, expected ${expected_status}"
  [[ "${lock_before}" == "${lock_after}" ]] \
    && pass "${name}: mix.lock bytes restored" \
    || fail "${name}: mix.lock hash changed (${lock_before} -> ${lock_after})"
  [[ -f "${fixture}/_build/test/lib/threadline/.built" ]] \
    && pass "${name}: threadline build marker restored" \
    || fail "${name}: threadline build marker missing after cleanup"
  restored_forwarder="$(cat "${fixture}/_build/test/lib/sigra/ebin/threadline-forwarder.beam" 2>/dev/null || true)"
  [[ "${restored_forwarder}" == "forwarder-present" ]] \
    && pass "${name}: conditionally compiled Sigra forwarder restored" \
    || fail "${name}: conditionally compiled Sigra forwarder missing after cleanup"
  if [[ "${name}" == "success" || "${name}" == "child_failure" ]]; then
    [[ "$(cat "${fixture}/test-results/ci-exunit-timing-main.json")" == "main-report" ]] \
      && pass "${name}: child invocation preserves main report bytes" \
      || fail "${name}: child invocation overwrote the main report"
    [[ "$(cat "${fixture}/test-results/ci-exunit-timing-threadline-guard.json")" == "threadline-guard-report" ]] \
      && pass "${name}: child invocation writes a separate report" \
      || fail "${name}: child report is missing"
  fi
}

case "${1:-}" in
  "--case")
    case "${2:-}" in
      failure_plus_cleanup) run_case failure_plus_cleanup 24 0 1 1 ;;
      *) echo "FAIL: unknown case ${2:-}" >&2; exit 2 ;;
    esac
    ;;
  "")
    run_case success 0 0
    run_case injected_compile_failure 42 1
    run_case child_failure 24 0 1
    run_case failure_plus_cleanup 24 0 1 1
    run_case successful_guard_restore_failure 1 0 0 1
    run_case interrupt 130 0 0 0 1
    ;;
  *) echo "usage: $0 [--case failure_plus_cleanup]" >&2; exit 2 ;;
esac

echo "Results: ${PASS} passed, ${FAIL} failed"
((FAIL == 0))
