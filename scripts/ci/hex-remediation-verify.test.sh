#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT/scripts/ci/hex-remediation-verify.sh"
INCOMPLETE="$ROOT/test/fixtures/prohibitions/p22-hex-evidence-incomplete.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

output="$(cd "$TMP_DIR" && bash "$VERIFY" validate "$INCOMPLETE" receipt.json 2>&1)" && status=0 || status=$?
if [[ "$status" -eq 0 ]]; then
  fail "incomplete evidence must never validate"
fi

[[ "$output" == *"missing required evidence slot"* ]] ||
  fail "incomplete evidence should fail with a required-slot diagnostic, got: $output"

echo "PASS: incomplete evidence is rejected with an attributable required-slot diagnostic"

FAKE_BIN="$TMP_DIR/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    *) url="$1"; shift ;;
  esac
done
case "${FAKE_CURL_MODE:-ok}:$url" in
  empty:*) : > "$output" ;;
  invalid:*) printf '\377' > "$output" ;;
  absent:*api/packages*) printf '%s\n' '{"name":"sigra","latest_version":"1.20.0","latest_stable_version":"1.20.0","retirements":[],"releases":[{"version":"1.5.1","has_docs":true}]}' > "$output" ;;
  phantom:*hexdocs*) printf '%s\n' '<a href="/sigra/1.20.0/readme.html">phantom</a>' > "$output" ;;
  ambiguous:*hexdocs*) printf '%s\n' '<html>no release route</html>' > "$output" ;;
  *:*)
    if [[ "$url" == *hexdocs* ]]; then
      printf '%s\n' '<a href="/sigra/1.5.1/readme.html">current</a>' > "$output"
    else
      printf '%s\n' '{"name":"sigra","latest_version":"1.20.0","latest_stable_version":"1.20.0","retirements":[{"version":"1.20.0","reason":"invalid"}],"releases":[{"version":"1.20.0","has_docs":true},{"version":"1.5.1","has_docs":true}]}' > "$output"
    fi
    ;;
esac
EOF
cat > "$FAKE_BIN/mix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" = deps.get ]] || exit 64
printf '%s\n' "$HEX_HOME" >> "${FAKE_MIX_HOME_LOG:?}"
if grep -q '"~> 1.0"' mix.exs; then
  selected="${FAKE_BROAD_VERSION:-1.20.0}"
  [[ "${FAKE_BROAD_WARNING:-true}" = true ]] && echo 'warning: sigra 1.20.0 has been retired'
else
  selected="${FAKE_SAFE_VERSION:-1.5.1}"
fi
printf '{"sigra": {:"hex", :sigra, "%s", "checksum", [], "hexpm", "checksum"}}\n' "$selected" > mix.lock
EOF
chmod +x "$FAKE_BIN/curl" "$FAKE_BIN/mix"

run() {
  (cd "$TMP_DIR" && PATH="$FAKE_BIN:$PATH" FAKE_MIX_HOME_LOG="$TMP_DIR/mix-homes" "$@")
}

EVIDENCE_DIR="$TMP_DIR/evidence"
mkdir -p "$EVIDENCE_DIR"
for slot in before after_retire after_docs_revert; do
  run bash "$VERIFY" capture "$slot" "evidence/$slot.json"
done
run bash "$VERIFY" classify-root evidence/hexdocs_root.json
run bash "$VERIFY" resolver broad evidence/resolver_broad.json
run bash "$VERIFY" resolver safe evidence/resolver_safe.json
run bash "$VERIFY" validate evidence evidence/receipt.json
jq -e '
  .schema == "sigra.phase-242-hex-remediation/1" and
  .before.slot == "before" and
  .after_retire.slot == "after_retire" and
  .after_docs_revert.slot == "after_docs_revert" and
  .hexdocs_root.classification == "current_1_5" and
  .resolver_broad.selected_version == "1.20.0" and
  .resolver_broad.retirement_warning == true and
  (.resolver_safe.selected_version | test("^1\\.5\\.")) and
  .resolver_safe.fresh_home == true
' "$EVIDENCE_DIR/receipt.json" >/dev/null || fail "happy path receipt is incomplete or incorrect"
test "$(sort -u "$TMP_DIR/mix-homes" | wc -l | tr -d ' ')" = 2 || fail "resolver cases must use separate HEX_HOME values"

expect_failure() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label unexpectedly succeeded"
  fi
}

expect_failure "empty package response" env FAKE_CURL_MODE=empty bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' capture before evidence/empty.json"
expect_failure "invalid package encoding" env FAKE_CURL_MODE=invalid bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' capture before evidence/invalid.json"
expect_failure "absent target release" env FAKE_CURL_MODE=absent bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' capture before evidence/absent.json"
expect_failure "phantom root classification" env FAKE_CURL_MODE=phantom bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' classify-root evidence/phantom.json"
expect_failure "ambiguous root classification" env FAKE_CURL_MODE=ambiguous bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' classify-root evidence/ambiguous.json"
expect_failure "broad resolver without retirement warning" env FAKE_BROAD_WARNING=false FAKE_MIX_HOME_LOG="$TMP_DIR/mix-homes" bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' resolver broad evidence/broad-no-warning.json"
expect_failure "safe resolver outside 1.5.x" env FAKE_SAFE_VERSION=1.20.0 FAKE_MIX_HOME_LOG="$TMP_DIR/mix-homes" bash -c "cd '$TMP_DIR' && PATH='$FAKE_BIN':\$PATH '$VERIFY' resolver safe evidence/safe-outside.json"
cp "$EVIDENCE_DIR/receipt.json" "$TMP_DIR/credential.json"
jq '.request_material = "Bearer hex_secret_value"' "$TMP_DIR/credential.json" > "$TMP_DIR/credential-next.json"
mv "$TMP_DIR/credential-next.json" "$TMP_DIR/credential.json"
expect_failure "credential-shaped evidence" bash -c "cd '$TMP_DIR' && '$VERIFY' validate '$TMP_DIR/credential.json' evidence/credential.json"

echo "PASS: hermetic remediation verifier coverage"
