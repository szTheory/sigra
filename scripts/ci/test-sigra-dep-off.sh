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

  mkdir -p "${fixture}/scripts/ci" "${fixture}/bin" "${fixture}/_build/test/lib/threadline"
  cp "${SCRIPT}" "${fixture}/scripts/ci/sigra-dep-off.sh"
  chmod +x "${fixture}/scripts/ci/sigra-dep-off.sh"
  printf '{:threadline, {:hex, :threadline, "1.0.0", "locked", [], [], "hexpm", "checksum"}}\n' > "${fixture}/mix.lock"
  printf 'original-build\n' > "${fixture}/_build/test/lib/threadline/.built"

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
    [[ "${SIGRA_DEP_OFF_FORCE_FAILURE:-0}" != "1" ]] || exit 42
    ;;
  "test --only threadline_guard --no-deps-check")
    ;;
  "deps.get --check-locked")
    ;;
  "compile threadline")
    mkdir -p _build/test/lib/threadline
    printf 'restored-build\n' > _build/test/lib/threadline/.built
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
  local fixture lock_before lock_after status

  fixture="$(setup_fixture "${name}")"
  lock_before="$(shasum -a 256 "${fixture}/mix.lock" | awk '{print $1}')"

  set +e
  (
    cd "${fixture}"
    PATH="${fixture}/bin:${PATH}" SIGRA_DEP_OFF_FORCE_FAILURE="${force_failure}" \
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
}

run_case success 0 0
run_case injected_failure 42 1

echo "Results: ${PASS} passed, ${FAIL} failed"
((FAIL == 0))
