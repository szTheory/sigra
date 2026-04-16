#!/usr/bin/env bash
# scripts/ci/install-matrix-local.sh
#
# Reproduces the GitHub Actions `install_matrix` job (.github/workflows/ci.yml:151)
# locally via nektos/act, for all four matrix legs:
#
#   leg 1: flags=""                               (default)
#   leg 2: flags="--no-passkeys"
#   leg 3: flags="--no-organizations"
#   leg 4: flags="--no-organizations --no-passkeys"
#
# Used to verify Phase 24 Task 24-01-09 (install_matrix D-06.4) without needing
# to push to GitHub and wait for real CI.
#
# Usage:
#     scripts/ci/install-matrix-local.sh                     # run all four legs
#     scripts/ci/install-matrix-local.sh --leg ""            # run only the default leg
#     scripts/ci/install-matrix-local.sh --leg --no-passkeys
#     scripts/ci/install-matrix-local.sh --leg --no-organizations
#     scripts/ci/install-matrix-local.sh --leg "--no-organizations --no-passkeys"
#
# Requirements:
#   - Docker Desktop running
#   - act installed (`brew install act`)
#   - .actrc present in repo root with the pinned catthehacker image
#     (load-bearing — see .actrc header for why)
#   - No other postgres listening on :5432 (act starts its own inside the
#     service container; a host postgres causes port collisions)
#
# Caveats (from memory reference_act_local_ci.md):
#   - First run pulls the pinned ubuntu:act-20.04 image (~2 GB)
#   - Each leg runs a full Phoenix scaffold + sigra.install + compile + migrate
#     + test inside the container; wall time is 5-15 minutes per leg
#   - Do NOT pass --reuse: act leaves stale beam.smp file descriptors that
#     cause ETXTBSY on the next run. The script deliberately omits --reuse.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "${REPO_ROOT}"

LEG_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --leg)
      LEG_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,30p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# ---- preflight --------------------------------------------------------------

preflight_fail() {
  echo "[preflight] $1" >&2
  echo "[preflight] aborting — fix the above and rerun" >&2
  exit 1
}

command -v act >/dev/null 2>&1 || preflight_fail "act is not installed. Install with: brew install act"
command -v docker >/dev/null 2>&1 || preflight_fail "docker is not installed"

if ! docker info >/dev/null 2>&1; then
  preflight_fail "docker daemon is not running"
fi

if [[ ! -f .actrc ]]; then
  preflight_fail ".actrc is missing in repo root"
fi

if ! grep -q 'catthehacker/ubuntu:act-20.04' .actrc; then
  preflight_fail ".actrc does not pin catthehacker/ubuntu:act-20.04 — setup-beam arm64 OTP prebuilds require Ubuntu 20.04 (libssl1.1). See .actrc header."
fi

# Host postgres on :5432 clashes with act's postgres service container.
# Detect before act spins up, so the user sees a clear hint instead of a
# cryptic connection-refused 3 minutes in.
if command -v lsof >/dev/null 2>&1 && lsof -iTCP:5432 -sTCP:LISTEN >/dev/null 2>&1; then
  cat <<'EOF' >&2
[preflight] something is already listening on TCP :5432

If it is docker, stop the offender (common suspect: sigra-uat-postgres):
    docker stop sigra-uat-postgres

If it is a host-installed postgres:
    brew services stop postgresql@14

Then rerun this script. (Act will start its own postgres inside the
install_matrix job's service container.)
EOF
  exit 1
fi

# ---- leg runner -------------------------------------------------------------

# Run one install_matrix leg. act matches matrix entries by substring, so the
# --matrix flag is used to filter to a single leg.
run_leg() {
  local flags_value="$1"
  local label
  if [[ -z "${flags_value}" ]]; then
    label='flags=""'
  else
    label="flags=\"${flags_value}\""
  fi

  echo
  echo "================================================================"
  echo " install_matrix — local reproduction via act"
  echo " leg: ${label}"
  echo "================================================================"

  # Note: `act -j install_matrix --matrix flags:<value>` is how act filters
  # matrix legs. For the empty-string leg, the value after the colon is
  # an empty string; act will still match it against the "" entry in the
  # workflow matrix.
  local matrix_arg="flags:${flags_value}"

  if act -j install_matrix --matrix "${matrix_arg}"; then
    echo "[leg ${label}] PASS"
    return 0
  else
    local rc=$?
    echo "[leg ${label}] FAIL (act exit ${rc})"
    return "${rc}"
  fi
}

# ---- drive ------------------------------------------------------------------

LEGS=()
if [[ -z "${LEG_FILTER}" ]]; then
  LEGS=("" "--no-passkeys" "--no-organizations" "--no-organizations --no-passkeys")
else
  LEGS=("${LEG_FILTER}")
fi

declare -a RESULTS=()
OVERALL_RC=0

for leg in "${LEGS[@]}"; do
  if run_leg "${leg}"; then
    RESULTS+=("PASS  ${leg:-<default>}")
  else
    RESULTS+=("FAIL  ${leg:-<default>}")
    OVERALL_RC=1
  fi
done

echo
echo "================================================================"
echo " install_matrix (act) — summary"
echo "================================================================"
for r in "${RESULTS[@]}"; do
  printf '  %s\n' "${r}"
done
echo

if [[ "${OVERALL_RC}" -eq 0 ]]; then
  echo "install_matrix: all legs green locally. Task 24-01-09 gate satisfied."
else
  echo "install_matrix: one or more legs FAILED. Inspect act output above."
fi

exit "${OVERALL_RC}"
