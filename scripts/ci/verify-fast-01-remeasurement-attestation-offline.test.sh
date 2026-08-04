#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$ROOT/scripts/ci/verify-fast-01-remeasurement-attestation-offline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/mktemp-bin"
printf '#!/usr/bin/env bash\ntouch "$FAKE_MKTEMP_CALLED"\nexit 99\n' >"$WORK/mktemp-bin/mktemp"
chmod +x "$WORK/mktemp-bin/mktemp"

# A fake mktemp on PATH must not be reached before the verifier either enters
# its trusted setup or fails closed for its retained evidence/environment.
PATH="$WORK/mktemp-bin:$PATH" FAKE_MKTEMP_CALLED="$WORK/fake-mktemp-called" "$VERIFIER" >"$WORK/stdout" 2>"$WORK/stderr" || true
test ! -e "$WORK/fake-mktemp-called"
echo offline_fast_01_attestation_runtime_self_test_verified
