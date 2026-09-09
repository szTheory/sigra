#!/usr/bin/env bash
# Fixed receiver for the measured install/scaffold leg. Preparation is caused
# by this child, so it remains inside library-economics.sh's install markers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT

receiver_paths=(
  test/sigra/install/features/passkeys_js_test.exs
  test/sigra/install/generator_passkeys_opt_out_test.exs
  test/sigra/install/golden_diff_test.exs
  test/sigra/install/idempotency_test.exs
  test/sigra/install/vault_promotion_test.exs
  test/upgrade_test.exs
)
readonly receiver_paths

cd "$ROOT"
export SIGRA_INSTALL_GOLDEN_PREPARED=1
exec mix test "${receiver_paths[@]}"
