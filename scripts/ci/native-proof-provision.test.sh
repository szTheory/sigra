#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT_DIR}/scripts/ci/native-proof-provision.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() {
  local expected="$1"; shift
  local output status
  set +e
  output="$("$@" 2>&1)"; status=$?
  set -e
  [[ $status -ne 0 ]] || fail "expected failure: $*"
  [[ "$output" == *"$expected"* ]] || fail "expected $expected, got: $output"
}

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-native-proof-test.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT
fake_bin="$tmp_root/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
echo "${FAKE_ARCH:-arm64}"
EOF
cat >"$fake_bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *-version*) printf 'Xcode 26.6\nBuild version 17F113\n' ;;
  *-showdestinations*) printf '%s\n' "${FAKE_DESTINATIONS:-platform:iOS,id:DEVICE-ONLY-TEST}" ;;
  *) exit 70 ;;
esac
EOF
cat >"$fake_bin/xcrun" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"devicectl list devices"* ]]; then
  output_path=''
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == '--json-output' ]]; then output_path="$2"; break; fi
    shift
  done
  [[ -n "$output_path" ]] || exit 70
  printf '{"result":{"devices":[{"identifier":"DEVICE-ONLY-TEST","hardwareProperties":{"platform":"iOS","deviceType":"iPhone","marketingName":"Test iPhone"},"deviceProperties":{"osVersionNumber":"18.0"},"connectionProperties":{"pairingState":"%s"}}]}}\n' "${FAKE_CORE_PAIRING:-paired}" >"$output_path"
elif [[ "$*" == *"xctrace list devices"* ]]; then
  printf '%s\n' "${FAKE_XCTRACE:-Test iPhone (18.0) (DEVICE-ONLY-TEST)}"
elif [[ "$*" == *"xcdevice list"* ]]; then
  printf '%s\n' "${FAKE_XCDEVICE:-DEVICE-ONLY-TEST iPhone iOS connected}"
else
  exit 70
fi
EOF
cat >"$fake_bin/security" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_SIGNING:-1) VALID-ONLY-TEST \"Apple Development\" (TEAMONLY01)}"
EOF
chmod +x "$fake_bin"/*

base_env=(env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$tmp_root" \
  SIGRA_IOS_DEVICE_UDID=DEVICE-ONLY-TEST SIGRA_IOS_DEVELOPMENT_TEAM=TEAMONLY01 \
  SIGRA_IOS_RUNNER_LABELS='self-hosted,macOS,ARM64,sigra-ios-physical' \
  SIGRA_NATIVE_PROOF_LOCK_PATH="$tmp_root/native-proof-environment.lock.json")

"${base_env[@]}" "$SCRIPT" --validate-ios
lock="$tmp_root/native-proof-environment.lock.json"
[[ -f "$lock" ]] || fail "iOS lock was not written"
! rg -q 'DEVICE-ONLY-TEST|TEAMONLY01|VALID-ONLY-TEST|Apple Development' "$lock" || fail "lock retained sensitive identity"
rg -q '"ios_runner_class":"self_hosted_attached_device"' "$lock" || fail "missing runner lock"
discovery="$("${base_env[@]}" SIGRA_IOS_DEVICE_UDID='' SIGRA_IOS_DEVELOPMENT_TEAM='' FAKE_XCTRACE='Test iPhone (18.0) (0123456789ABCDEF01234567)' "$SCRIPT" --discover-ios)"
[[ "$discovery" == *'"device_candidates":1'* && "$discovery" != *'0123456789ABCDEF01234567'* && "$discovery" != *'TEAMONLY01'* ]] || fail "discovery was not bounded/redacted"

expect_fail 'NP-IOS-SIMULATOR' "${base_env[@]}" FAKE_XCTRACE='Test iPhone Simulator (18.0) (DEVICE-ONLY-TEST)' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-DEVICE-UNAVAILABLE' "${base_env[@]}" FAKE_XCTRACE='Other iPhone (18.0) (OTHER-DEVICE-ONLY)' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-ARCH' "${base_env[@]}" FAKE_ARCH=x86_64 "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-RUNNER-LABELS' "${base_env[@]}" SIGRA_IOS_RUNNER_LABELS='self-hosted,macOS,ARM64' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-DESTINATION' "${base_env[@]}" FAKE_CORE_PAIRING=unpaired "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-LOCK-REDACTION' "${base_env[@]}" SIGRA_NATIVE_PROOF_LOCK_PATH="$tmp_root/leaky.json" SIGRA_NATIVE_PROOF_TEST_LEAK=DEVICE-ONLY-TEST "$SCRIPT" --validate-ios

echo 'native-proof-provision tests: PASS'
