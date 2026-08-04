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

grep -Eq 'untrusted_gh_executable:.*/bin/gh$' "$WORK/stderr"
test ! -s "$WORK/stdout"

# The verifier may only use the trusted absolute sudo path for its Linux
# fallback. A PATH-controlled binary must neither be executed nor make an
# unisolated verification appear successful.
mkdir "$WORK/sudo-bin"
printf '#!/usr/bin/env bash\ntouch "$FAKE_SUDO_CALLED"\nexit 0\n' >"$WORK/sudo-bin/sudo"
chmod +x "$WORK/sudo-bin/sudo"
PATH="$WORK/sudo-bin:$PATH" FAKE_SUDO_CALLED="$WORK/fake-sudo-called" "$VERIFIER" >"$WORK/sudo-stdout" 2>"$WORK/sudo-stderr" || true
test ! -e "$WORK/fake-sudo-called"
echo offline_attestation_runtime_self_test_verified
