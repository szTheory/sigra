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

python3 - "$SCRIPT" <<'PY'
import pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
source = source.split("prepare_host() {", 1)[1].split("plist_put() {", 1)[0]
markers = [
    "mix deps.get --check-locked",
    "mix compile --force",
    "mix ecto.create --quiet",
    "mix ecto.migrate --quiet",
    "mix run --no-compile --no-deps-check",
    'curl --fail --silent --show-error --retry 40',
]
positions = [source.find(marker) for marker in markers]
if -1 in positions or positions != sorted(positions):
    raise SystemExit("clean host bootstrap must fetch locked deps, compile, create, migrate, seed, and prove readiness in order")
PY

python3 - "$ROOT_DIR/.github/workflows/terminal-ratification-evidence.yml" <<'PY'
import pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
job = source.split("  phase248_ios_physical:", 1)[1]
markers = [
    "Provision isolated proof database",
    "Validate hermetic physical proof mechanics",
    "Execute live physical-iPhone proof",
    "Upload redacted physical-iPhone receipt",
    "Remove isolated proof database",
]
positions = [job.find(marker) for marker in markers]
if -1 in positions or positions != sorted(positions) or "if: always()" not in job:
    raise SystemExit("physical workflow must provision, prove, upload, and always remove its isolated database in order")
PY

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
case "$1" in
  find-identity) printf '%s\n' '1) REDACTED "Apple Development: Proof User"' '     1 valid identities found' ;;
  cms) cat "$4" ;;
  *) exit 70 ;;
esac
EOF
cat >"$fake_bin/defaults" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == export && "$2" == com.apple.dt.Xcode && -n "$3" ]] || exit 70
/usr/bin/plutil -create xml1 "$3"
/usr/bin/plutil -insert IDEProvisioningTeamByIdentifier -json '{"ACCOUNT":[{"teamID":"TEAMONLY01"}]}' "$3"
EOF
cat >"$fake_bin/xcrun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'xctrace list devices'*) printf '%s\n' "${FAKE_XCTRACE:-Test iPhone (26.6.1) (DEVICE-ONLY-TEST)}" ;;
  *'xcdevice list'*)
    printf '%s\n' '[{"identifier":"DEVICE-ONLY-TEST","simulator":false,"platform":"com.apple.platform.iphoneos","name":"Test iPhone","modelName":"iPhone","operatingSystemVersion":"26.6.1 (23G83)","available":true}]'
    ;;
  *'devicectl device uninstall app'*) exit 0 ;;
  *'xcresulttool get test-results tests'*) cat "${FAKE_XCRESULT_SUMMARY:?}" ;;
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
    if [[ "${FAKE_BUILD_FAIL:-0}" == 1 ]]; then
      printf '%s\n' 'error: No Account for Team "TEAMONLY01" on DEVICE-ONLY-TEST password=ephemeral-not-retained' >&2
      exit 65
    fi
    products="${SIGRA_IOS_TEST_DERIVED_DATA:?}/Build/Products"
    mkdir -p "$products/Proof-iphoneos/SigraNativeProof.app" "$products/Proof-iphoneos/SigraNativeProofUITests-Runner.app/PlugIns/SigraNativeProofUITests.xctest"
    printf app >"$products/Proof-iphoneos/SigraNativeProof.app/SigraNativeProof"
    printf test >"$products/Proof-iphoneos/SigraNativeProofUITests-Runner.app/PlugIns/SigraNativeProofUITests.xctest/SigraNativeProofUITests"
    printf diagnostics >"$products/build.log"
    /usr/bin/plutil -create xml1 "$products/fixture.xctestrun"
    /usr/bin/plutil -insert TestConfigurations -json '[{"TestTargets":[{"TestBundlePath":"__TESTROOT__/SigraNativeProofTests.xctest","EnvironmentVariables":{}},{"TestBundlePath":"__TESTROOT__/SigraNativeProofUITests.xctest","EnvironmentVariables":{}}]}]' "$products/fixture.xctestrun"
    ;;
  *'test-without-building'*)
    mkdir -p "${SIGRA_IOS_TEST_RESULT_BUNDLE:?}"
    if [[ "${FAKE_TEST_FAIL:-0}" == 1 ]]; then
      printf '%s\n' 'Testing failed:' >&2
      exit 65
    fi
    ;;
  *) exit 70 ;;
esac
EOF
chmod +x "$fake_bin"/*

profile_dir="$tmp_root/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profile_dir"
for pair in \
  "app.mobileprovision:TEAMONLY01.com.sigra.example.nativeproof" \
  "ui.mobileprovision:TEAMONLY01.com.sigra.example.nativeproof.uitests.xctrunner"; do
  name="${pair%%:*}"
  app_id="${pair#*:}"
  /usr/bin/plutil -create xml1 "$profile_dir/$name"
  /usr/bin/plutil -insert TeamIdentifier -json '["TEAMONLY01"]' "$profile_dir/$name"
  /usr/bin/plutil -insert Entitlements -json "{\"application-identifier\":\"$app_id\"}" "$profile_dir/$name"
done

injector="$ROOT_DIR/scripts/ci/lib/xctestrun-env.py"
for shape in current legacy; do
  fixture="$tmp_root/$shape.xctestrun"
  if [[ "$shape" == current ]]; then
    /usr/bin/plutil -create xml1 "$fixture"
    /usr/bin/plutil -insert TestConfigurations -json '[{"TestTargets":[{"TestBundlePath":"__TESTROOT__/OtherTests.xctest","EnvironmentVariables":{"UNCHANGED":"yes"}},{"TestBundlePath":"__TESTROOT__/SigraNativeProofUITests.xctest","EnvironmentVariables":{}}]}]' "$fixture"
  else
    /usr/bin/plutil -create xml1 "$fixture"
    /usr/bin/plutil -insert SigraNativeProofUITests -json '{"TestBundlePath":"__TESTROOT__/SigraNativeProofUITests.xctest","EnvironmentVariables":{}}' "$fixture"
  fi
  python3 "$injector" "$fixture" SigraNativeProofUITests.xctest PROOF_KEY proof-value
  python3 - "$fixture" "$shape" <<'PY'
import plistlib, sys
root = plistlib.load(open(sys.argv[1], "rb"))
if sys.argv[2] == "current":
    targets = root["TestConfigurations"][0]["TestTargets"]
    assert targets[0]["EnvironmentVariables"] == {"UNCHANGED": "yes"}
    environment = targets[1]["EnvironmentVariables"]
else:
    environment = root["SigraNativeProofUITests"]["EnvironmentVariables"]
assert environment == {"PROOF_KEY": "proof-value"}
PY
done

report="$tmp_root/report.json"
xcresult_summary="$tmp_root/xcresult-tests.json"
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

python3 - "$xcresult_summary" <<'PY'
import json, sys
payload = {"testNodes": [{
  "nodeType": "Test Case", "name": "testLivePhysicalIphoneHostJourney", "result": "Failed",
  "children": [{
    "nodeType": "Failure Message",
    "name": "approval button was not found for native@example.invalid",
    "details": "device DEVICE-ONLY-TEST team TEAMONLY01 password=ephemeral-not-retained access_token=top-secret-token-value"
  }]
}]}
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps(payload))
PY

tool_bin="$(dirname "$(command -v node)")"
base_env=(env -i PATH="$fake_bin:$tool_bin:/usr/bin:/bin" HOME="$tmp_root" TMPDIR="$tmp_root" \
  SIGRA_IOS_PROOF_TEST_MODE=1 SIGRA_IOS_DEVICE_UDID=DEVICE-ONLY-TEST \
  SIGRA_IOS_DEVELOPMENT_TEAM=TEAMONLY01 SIGRA_IOS_RUNNER_LABELS='self-hosted,macOS,ARM64,sigra-ios-physical' \
  SIGRA_IOS_PROOF_TEST_REPORT="$report" FAKE_REPORT="$report" FAKE_XCRESULT_SUMMARY="$xcresult_summary")

expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_XCTRACE='Test iPhone Simulator (26.6.1) (DEVICE-ONLY-TEST)' "$SCRIPT"
expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_XCTRACE='Other iPhone (26.6.1) (OTHER-DEVICE)' "$SCRIPT"
expect_failure 'NP-IOS-PHYSICAL-TARGET' "${base_env[@]}" FAKE_UNAME=x86_64 "$SCRIPT"

build_events="$tmp_root/build-events"
set +e
build_output="$("${base_env[@]}" FAKE_BUILD_FAIL=1 SIGRA_IOS_PROOF_TEST_EVENTS="$build_events" "$SCRIPT" 2>&1)"
build_status=$?
set -e
[[ $build_status -ne 0 && "$build_output" == *'NP-IOS-BUILD'* ]] || fail 'expected a closed build failure'
[[ "$build_output" == *'[REDACTED]'* ]] || fail 'build diagnostics were not retained in redacted form'
for private in DEVICE-ONLY-TEST TEAMONLY01 ephemeral-not-retained ephemeral@example.invalid; do
  [[ "$build_output" != *"$private"* ]] || fail "build diagnostics retained private value: $private"
done
[[ "$(tail -1 "$build_events")" == 'xcode_diagnostics_emitted' ]] || fail 'redacted build diagnostics were not emitted'
[[ -z "$(find "$tmp_root" -maxdepth 1 -type d -name 'sigra-ios-physical.*' -print -quit)" ]] || \
  fail 'failed build left its private run directory behind'

test_events="$tmp_root/test-events"
set +e
test_output="$("${base_env[@]}" FAKE_TEST_FAIL=1 SIGRA_IOS_PROOF_TEST_EVENTS="$test_events" "$SCRIPT" 2>&1)"
test_status=$?
set -e
[[ $test_status -ne 0 && "$test_output" == *'NP-IOS-TEST'* ]] || fail 'expected a closed physical test failure'
[[ "$test_output" == *'approval button was not found'* ]] || fail 'structured xcresult failure was not retained'
for private in DEVICE-ONLY-TEST TEAMONLY01 ephemeral-not-retained ephemeral@example.invalid top-secret-token-value; do
  [[ "$test_output" != *"$private"* ]] || fail "xcresult diagnostics retained private value: $private"
done
[[ "$(tail -1 "$test_events")" == 'xcresult_diagnostics_emitted' ]] || fail 'structured xcresult diagnostics were not emitted'
[[ -z "$(find "$tmp_root" -maxdepth 1 -type d -name 'sigra-ios-physical.*' -print -quit)" ]] || \
  fail 'failed physical test left its private result bundle behind'

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
