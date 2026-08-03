#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER="$ROOT/scripts/ci/verify-terminal-ratification-attestation-offline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/bin"
printf '#!/usr/bin/env bash\nprintf '\''[]\\n'\''\n' >"$WORK/bin/gh"
chmod +x "$WORK/bin/gh"

if PATH="$WORK/bin:$PATH" "$VERIFIER" >"$WORK/stdout" 2>"$WORK/stderr"; then
  echo "shadowed_gh_unexpectedly_accepted" >&2
  exit 1
fi

grep -q "untrusted_gh_executable:$WORK/bin/gh" "$WORK/stderr"
test ! -s "$WORK/stdout"
echo offline_attestation_runtime_self_test_verified
