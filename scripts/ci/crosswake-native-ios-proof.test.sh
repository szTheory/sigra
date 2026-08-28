#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT_DIR}/scripts/ci/crosswake-native-ios-proof.sh"

fail() { printf 'crosswake-native-ios-proof test: %s\n' "$*" >&2; exit 1; }

expect_failure() {
  local rule="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  [[ $status -ne 0 ]] || fail "expected failure for ${rule}"
  [[ "$output" == *"${rule}"* ]] || fail "missing closed rule ${rule}"
}

[[ -x "$SCRIPT" ]] || fail "physical proof runner is missing or non-executable"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-ios-proof-test.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM
chmod 700 "$tmp_root"
fake_bin="$tmp_root/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_UNAME:-arm64}"
EOF
cat >"$fake_bin/security" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '1) REDACTED "Apple Development" (TEAMONLY01)' '     1 valid identities found'
EOF
cat >"$fake_bin/xcrun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'xctrace list devices'*) printf '%s\n' "${FAKE_XCTRACE:-Test iPhone (26.6.1) (DEVICE-ONLY-TEST)}" ;;
  *'xcdevice list'*)
    printf '%s\n' '[{"identifier":"DEVICE-ONLY-TEST","simulator":false,"platform":"com.apple.platform.iphoneos","name":"Test iPhone","modelName":"iPhone","operatingSystemVersion":"26.6.1 (23G83)","available":true}]'
    ;;
  *'devicectl device uninstall app'*) exit 0 ;;
  *'xcresulttool export attachments'*)
    output=''
    while [[ $# -gt 0 ]]; do
      [[ "$1" == '--output-path' ]] && { output="$2"; break; }
      shift
    done
    mkdir -p "$output"
    cp "${FAKE_REPORT:?}" "$output/sigra-native-proof-live-report.json"
    ;;
  *) exit 70 ;;
esac
EOF
cat >"$fake_bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'-version'*) printf 'Xcode 26.6\nBuild version 17F113\n' ;;
  *'-showdestinations'*) printf '{ platform:iOS, id:DEVICE-ONLY-TEST, name:Test iPhone }\n' ;;
  *'build-for-testing'*)
    products="${SIGRA_IOS_TEST_DERIVED_DATA:?}/Build/Products"
    mkdir -p "$products/Proof-iphoneos/SigraNativeProof.app" "$products/Proof-iphoneos/SigraNativeProofUITests-Runner.app/PlugIns/SigraNativeProofUITests.xctest"
    printf app >"$products/Proof-iphoneos/SigraNativeProof.app/SigraNativeProof"
    printf test >"$products/Proof-iphoneos/SigraNativeProofUITests-Runner.app/PlugIns/SigraNativeProofUITests.xctest/SigraNativeProofUITests"
    printf diagnostics >"$products/build.log"
    /usr/bin/plutil -create xml1 "$products/fixture.xctestrun"
    /usr/bin/plutil -insert SigraNativeProofUITests -json '{"EnvironmentVariables":{}}' "$products/fixture.xctestrun"
    ;;
  *'test-without-building'*) mkdir -p "${SIGRA_IOS_TEST_RESULT_BUNDLE:?}" ;;
  *) exit 70 ;;
esac
EOF
chmod +x "$fake_bin"/*

report="$tmp_root/report.json"
python3 - "$report" <<'PY'
import json, sys
payload = {
  "schema_version": 1,
  "evidence_class": "live_physical_iphone",
  "browser": {"component": "as_web_authentication_session", "mode": "system_external_user_agent"},
  "callback": {"transport": "custom_scheme", "link_verification": "registered_scheme", "callback_binding": "matched"},
  "storage": {"present": True, "rotated": True, "recovered_after_relaunch": True, "deleted_after_logout": True, "deleted_after_revocation": True, "read_result": "not_found", "access_persisted": False},
  "scenarios": {key: True for key in ["hosted_return", "image_verified", "audio_verified", "strict_lease_edge", "offline_use", "kill_relaunch", "account_switch", "server_revocation", "replay_accepted", "replay_rejected", "replay_conflict"]},
  "transport": {"claim": "controlled_transport_failure"},
  "terminal_status": "complete"
}
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n")
PY

tool_bin="$(dirname "$(command -v node)")"
base_env=(env -i PATH="$fake_bin:$tool_bin:/usr/bin:/bin" HOME="$tmp_root" TMPDIR="$tmp_root" \
  SIGRA_IOS_PROOF_TEST_MODE=1 SIGRA_IOS_DEVICE_UDID=DEVICE-ONLY-TEST \
  SIGRA_IOS_DEVELOPMENT_TEAM=TEAMONLY01 SIGRA_IOS_RUNNER_LABELS='self-hosted,macOS,ARM64,sigra-ios-physical' \
  SIGRA_IOS_PROOF_TEST_REPORT="$report" FAKE_REPORT="$report")

expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_XCTRACE='Test iPhone Simulator (26.6.1) (DEVICE-ONLY-TEST)' "$SCRIPT"
expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_XCTRACE='Other iPhone (26.6.1) (OTHER-DEVICE)' "$SCRIPT"
expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_UNAME=x86_64 "$SCRIPT"

receipt="$tmp_root/248-IOS-EVIDENCE.json"
events="$tmp_root/events"
"${base_env[@]}" SIGRA_IOS_EVIDENCE_PATH="$receipt" SIGRA_IOS_PROOF_TEST_EVENTS="$events" "$SCRIPT"

[[ -f "$receipt" ]] || fail 'receipt was not written'
[[ "$(tail -1 "$events")" == 'receipt_written' ]] || fail 'receipt was not the terminal action'
[[ "$(grep -c '^receipt_written$' "$events")" == 1 ]] || fail 'receipt was not written exactly once'
node "$ROOT_DIR/scripts/ci/lib/native-proof-receipt.mjs" --validate "$receipt" --target physical_iphone
! rg -q 'DEVICE-ONLY-TEST|TEAMONLY01|REDACTED' "$receipt" || fail 'receipt retained a stable identity or signing fact'
[[ "$(stat -f %Lp "$receipt" 2>/dev/null || stat -c %a "$receipt")" == 600 ]] || fail 'receipt mode is not private'

printf 'crosswake-native-ios-proof tests: PASS\n'
