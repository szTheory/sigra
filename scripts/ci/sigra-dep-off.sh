#!/usr/bin/env bash
# Run the threadline-off guard without leaving contributor dependency state changed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCKFILE="${ROOT}/mix.lock"
SNAPSHOT_DIR=""

fail() {
  echo "sigra-dep-off: FAIL: $*" >&2
  exit 1
}

[[ -f "${LOCKFILE}" ]] || fail "missing mix.lock at ${LOCKFILE}"
SNAPSHOT_DIR="$(mktemp -d)"
cp -p "${LOCKFILE}" "${SNAPSHOT_DIR}/mix.lock"

restore() {
  local restore_status=0
  local restore_path="${SNAPSHOT_DIR}/mix.lock.restore"

  cp -p "${SNAPSHOT_DIR}/mix.lock" "${restore_path}" || restore_status=1
  mv -f "${restore_path}" "${LOCKFILE}" || restore_status=1

  # Each bare `mix` command starts a fresh Mix VM, so no mutated dependency cache
  # survives from the deliberately destructive guard commands above.
  (
    cd "${ROOT}"
    MIX_ENV=test mix deps.get --check-locked
  ) || restore_status=1
  (
    cd "${ROOT}"
    MIX_ENV=test mix compile threadline
  ) || restore_status=1

  rm -rf "${SNAPSHOT_DIR}" || restore_status=1
  SNAPSHOT_DIR=""
  return "${restore_status}"
}

finish() {
  local guard_status=$?
  local cleanup_status=0

  trap - EXIT INT TERM
  restore || cleanup_status=$?

  if ((cleanup_status != 0)); then
    echo "sigra-dep-off: FAIL: dependency cleanup failed" >&2
    exit 1
  fi

  exit "${guard_status}"
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "${ROOT}"
mix deps.unlock threadline || exit $?
mix deps.clean threadline --build || exit $?
mix compile --warnings-as-errors --no-deps-check || exit $?
mix test --only threadline_guard --no-deps-check
