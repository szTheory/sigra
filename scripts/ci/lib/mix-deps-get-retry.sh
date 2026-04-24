#!/usr/bin/env bash
# scripts/ci/lib/mix-deps-get-retry.sh
#
# Source from other bash scripts in scripts/ci/:
#   _ci_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=scripts/ci/lib/mix-deps-get-retry.sh
#   source "${_ci_here}/lib/mix-deps-get-retry.sh"
#
# Default `mix phx.new` apps depend on heroicons via `github:`; `mix deps.get`
# runs shallow git fetch which can fail with transient GitHub HTTP 5xx
# (observed on CI: "RPC failed; HTTP 500"). Bounded retries absorb that
# without weakening compile/test gates.

mix_deps_get_with_retry() {
  local max="${MIX_DEPS_GET_RETRIES:-5}"
  local attempt=1
  local delay="${MIX_DEPS_GET_RETRY_SLEEP:-4}"

  while ((attempt <= max)); do
    if mix deps.get; then
      return 0
    fi
    if ((attempt == max)); then
      echo "FAIL: mix deps.get failed after ${max} attempt(s)" >&2
      return 1
    fi
    echo "==> mix_deps_get_with_retry: attempt ${attempt}/${max} failed, sleeping ${delay}s..." >&2
    sleep "${delay}"
    attempt=$((attempt + 1))
    delay=$((delay + 4))
  done
}
