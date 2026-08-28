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
before_lock="$(shasum -a 256 "$lock" | awk '{print $1}')"
env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$tmp_root" SIGRA_NATIVE_PROOF_LOCK_PATH="$lock" "$SCRIPT" --validate-ios-lock
[[ "$before_lock" == "$(shasum -a 256 "$lock" | awk '{print $1}')" ]] || fail "iOS lock validator mutated lock"
python3 - "$lock" <<'PY'
import json, sys
p=sys.argv[1]; d=json.load(open(p)); d['raw_udid']='DEVICE-ONLY-TEST'; json.dump(d, open(p,'w'))
PY
expect_fail 'NP-IOS-LOCK-REDACTION' env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$tmp_root" SIGRA_NATIVE_PROOF_LOCK_PATH="$lock" "$SCRIPT" --validate-ios-lock
"${base_env[@]}" "$SCRIPT" --validate-ios
python3 - "$lock" <<'PY'
import json, sys
p=sys.argv[1]; d=json.load(open(p)); d['ios_os_version']='bad'; json.dump(d, open(p,'w'))
PY
expect_fail 'NP-IOS-LOCK-REDACTION' env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$tmp_root" SIGRA_NATIVE_PROOF_LOCK_PATH="$lock" "$SCRIPT" --validate-ios-lock
"${base_env[@]}" "$SCRIPT" --validate-ios
discovery="$("${base_env[@]}" SIGRA_IOS_DEVICE_UDID='' SIGRA_IOS_DEVELOPMENT_TEAM='' FAKE_XCTRACE='Test iPhone (18.0) (0123456789ABCDEF01234567)' "$SCRIPT" --discover-ios)"
[[ "$discovery" == *'"device_candidates":1'* && "$discovery" != *'0123456789ABCDEF01234567'* && "$discovery" != *'TEAMONLY01'* ]] || fail "discovery was not bounded/redacted"

expect_fail 'NP-IOS-SIMULATOR' "${base_env[@]}" FAKE_XCTRACE='Test iPhone Simulator (18.0) (DEVICE-ONLY-TEST)' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-DEVICE-UNAVAILABLE' "${base_env[@]}" FAKE_XCTRACE='Other iPhone (18.0) (OTHER-DEVICE-ONLY)' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-ARCH' "${base_env[@]}" FAKE_ARCH=x86_64 "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-RUNNER-LABELS' "${base_env[@]}" SIGRA_IOS_RUNNER_LABELS='self-hosted,macOS,ARM64' "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-DESTINATION' "${base_env[@]}" FAKE_CORE_PAIRING=unpaired "$SCRIPT" --validate-ios
expect_fail 'NP-IOS-LOCK-REDACTION' "${base_env[@]}" SIGRA_NATIVE_PROOF_LOCK_PATH="$tmp_root/leaky.json" SIGRA_NATIVE_PROOF_TEST_LEAK=DEVICE-ONLY-TEST "$SCRIPT" --validate-ios

android_root="$tmp_root/android"
mkdir -p "$android_root/gradle/wrapper"
printf '#!/usr/bin/env sh\nexit 0\n' >"$android_root/gradlew"
chmod 0755 "$android_root/gradlew"
printf '@echo off\r\n' >"$android_root/gradlew.bat"
printf 'generated-wrapper-test-bytes\n' >"$android_root/gradle/wrapper/gradle-wrapper.jar"
chmod 0644 "$android_root/gradlew.bat" "$android_root/gradle/wrapper/gradle-wrapper.jar"
wrapper_sha="$(shasum -a 256 "$android_root/gradle/wrapper/gradle-wrapper.jar" | awk '{print $1}')"
printf '%s\n' \
  'distributionBase=GRADLE_USER_HOME' \
  'distributionPath=wrapper/dists' \
  'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' \
  'zipStoreBase=GRADLE_USER_HOME' \
  'zipStorePath=wrapper/dists' \
  'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' \
  >"$android_root/gradle/wrapper/gradle-wrapper.properties"
chmod 0644 "$android_root/gradle/wrapper/gradle-wrapper.properties"
python3 - "$android_root/toolchain.lock.json" "$wrapper_sha" <<'PY'
import json, sys
path, wrapper_sha = sys.argv[1:]
data = {"schema_version": 1, "jdk": "17", "cmdline_tools": "23.0", "platform_tools": "37.0.1", "emulator": "37.1.11", "sdk_platform": "android-36", "build_tools": "35.0.0", "system_image": "system-images;android-36;google_apis_playstore;x86_64", "system_image_revision": 7, "abi": "x86_64", "avd_device": "pixel_8", "browser_package": "com.android.chrome", "browser_version": "137.0.7151.80", "browser_apk_sha256": "a" * 64, "browser_mode": "custom_tab_fallback", "gradle": "8.13", "gradle_distribution_sha256": "20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78", "gradle_wrapper_jar_sha256": wrapper_sha, "agp": "8.13.2", "kotlin": "2.2.10", "androidx_browser": "1.9.0", "test_core": "1.7.0", "test_runner": "1.7.0", "espresso": "3.7.0", "uiautomator": "2.4.0", "complete": True}
with open(path, "w", encoding="utf-8") as handle: json.dump(data, handle, sort_keys=True, separators=(",", ":")); handle.write("\n")
PY
env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$android_root/gradle/wrapper/gradle-wrapper.properties" "$tmp_root/properties.valid"
printf '# distributionUrl=https\\://services.gradle.org/distributions/gradle-8.13-bin.zip\n' >"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"

generator="$tmp_root/generator"; finalized="$tmp_root/finalized"
mkdir -p "$generator/gradle/wrapper"
printf '#!/bin/sh\n' >"$generator/gradlew"; printf '@echo off\r\n' >"$generator/gradlew.bat"
printf 'wrapper-jar-bytes\n' >"$generator/gradle/wrapper/gradle-wrapper.jar"
printf '%s\n' 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' >"$generator/gradle/wrapper/gradle-wrapper.properties"
printf 'rootProject.name="private"\n' >"$generator/settings.gradle"
( umask 077; source "$SCRIPT"; finalize_gradle_wrapper "$generator" "$finalized" )
expected_files=$'gradle/wrapper/gradle-wrapper.jar\ngradle/wrapper/gradle-wrapper.properties\ngradlew\ngradlew.bat'
[[ "$(find "$finalized" -type f -print | sed "s#^$finalized/##" | LC_ALL=C sort)" == "$expected_files" ]] || fail 'finalize leaked scaffold files'
python3 - "$finalized" <<'PY' || fail 'finalize modes incorrect'
import pathlib, stat, sys
root = pathlib.Path(sys.argv[1])
raise SystemExit(0 if [(root / p).stat().st_mode & 0o777 for p in ('gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar', 'gradle/wrapper/gradle-wrapper.properties')] == [0o755, 0o644, 0o644, 0o644] else 1)
PY
[[ "$(shasum -a 256 "$generator/gradle/wrapper/gradle-wrapper.jar" | awk '{print $1}')" == "$(shasum -a 256 "$finalized/gradle/wrapper/gradle-wrapper.jar" | awk '{print $1}')" ]] || fail 'finalize changed jar bytes'
[[ "$(grep -Fc 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' "$finalized/gradle/wrapper/gradle-wrapper.properties")" == 1 ]] || fail 'finalize checksum pin incorrect'
printf 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.13-bin.zip\n' >>"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"
printf 'distributionSha256Sum=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' >>"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"
printf 'distributionUrl :https\\://malicious.invalid/gradle.zip\n' >>"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"
printf 'distributionUrl =https\\://malicious.invalid/gradle.zip\n' >>"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"
printf 'distribution\\Url=https\\://malicious.invalid/gradle.zip\n' >>"$android_root/gradle/wrapper/gradle-wrapper.properties"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
cp "$tmp_root/properties.valid" "$android_root/gradle/wrapper/gradle-wrapper.properties"
python3 - "$android_root/toolchain.lock.json" <<'PY'
import json, sys
path = sys.argv[1]; data = json.load(open(path, encoding="utf-8")); data["unexpected_stable_identifier"] = "nope"; json.dump(data, open(path, "w", encoding="utf-8"))
PY
expect_fail 'NP-ANDROID-LOCK' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
python3 - "$android_root/toolchain.lock.json" <<'PY'
import json, sys
path = sys.argv[1]; data = json.load(open(path, encoding="utf-8")); del data["unexpected_stable_identifier"]; json.dump(data, open(path, "w", encoding="utf-8"))
PY
python3 - "$android_root/toolchain.lock.json" <<'PY'
import json, sys
path = sys.argv[1]; data = json.load(open(path, encoding="utf-8")); data["browser_mode"] = "unknown"; json.dump(data, open(path, "w", encoding="utf-8"))
PY
expect_fail 'NP-ANDROID-LOCK' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock
python3 - "$android_root/toolchain.lock.json" "$wrapper_sha" <<'PY'
import json, sys
path, wrapper_sha = sys.argv[1:]; data = json.load(open(path, encoding="utf-8")); data["browser_mode"] = "auth_tab"; data["gradle_wrapper_jar_sha256"] = wrapper_sha; json.dump(data, open(path, "w", encoding="utf-8"))
PY
printf 'tampered\n' >>"$android_root/gradle/wrapper/gradle-wrapper.jar"
expect_fail 'NP-ANDROID-WRAPPER' env SIGRA_ANDROID_PROJECT_ROOT="$android_root" "$SCRIPT" --validate-android-lock

artifact="$tmp_root/android-proof.tar"
chmod 600 "$android_root/toolchain.lock.json"
python3 - "$artifact" "$android_root" <<'PY'
import hashlib, pathlib, tarfile, io, sys
archive, root = map(pathlib.Path, sys.argv[1:])
files = ["toolchain.lock.json", "gradlew", "gradlew.bat", "gradle/wrapper/gradle-wrapper.jar", "gradle/wrapper/gradle-wrapper.properties"]
# Use a fresh, untampered wrapper payload to exercise archive validation.
(root / "gradle/wrapper/gradle-wrapper.jar").write_bytes(b"artifact-wrapper\n")
payload = {name: (root / name).read_bytes() for name in files}
sha = "".join(f"{hashlib.sha256(payload[name]).hexdigest()}  {name}\n" for name in sorted(files))
modes = "".join(f"{(root / name).stat().st_mode & 0o777:o} {name}\n" for name in sorted(files))
with tarfile.open(archive, "w") as out:
    for name, content in {**payload, "provisioned-files.sha256": sha.encode(), "provisioned-files.mode": modes.encode()}.items():
        entry = tarfile.TarInfo(name); entry.size = len(content); entry.mode = (root / name).stat().st_mode & 0o777 if name in payload else 0o644
        out.addfile(entry, io.BytesIO(content))
PY
python3 "$ROOT_DIR/scripts/ci/verify-native-proof-android-artifact.py" "$artifact" "$tmp_root/extracted"
[[ -x "$tmp_root/extracted/gradlew" ]] || fail "artifact validator lost gradlew executable mode"
python3 - "$artifact" <<'PY'
import tarfile, sys
archive = sys.argv[1]
with tarfile.open(archive, "a") as out:
    entry = tarfile.TarInfo("extra.txt"); entry.size = 1; out.addfile(entry, __import__("io").BytesIO(b"x"))
PY
expect_fail 'NP-ANDROID-ARTIFACT' python3 "$ROOT_DIR/scripts/ci/verify-native-proof-android-artifact.py" "$artifact" "$tmp_root/rejected"

cat >"$fake_bin/adb" <<'EOF'
#!/usr/bin/env bash
args="$*"
if [[ "$args" == *'pm path com.android.chrome'* ]]; then printf '%s\n' 'package:/mutable/session/base.apk' 'package:/mutable/session/split_config.en.apk';
elif [[ "$args" == *'pm list packages -s com.android.chrome'* ]]; then echo 'package:com.android.chrome';
elif [[ "$args" == *'dumpsys package com.android.chrome'* ]]; then echo '  versionName=137.0.7151.80';
elif [[ "$args" == *'query-services'*'AuthTab'* ]]; then printf '%s\n' "${FAKE_AUTH_TAB:-No service found}";
elif [[ "$args" == *'query-services'* ]]; then printf '%s\n' "${FAKE_CUSTOM_TABS:-com.android.chrome/.CustomTabsService}";
elif [[ "$args" == *' pull '* ]]; then target="${@: -1}"; printf 'PK%s' "${target##*/}" >"$target";
else exit 70; fi
EOF
chmod +x "$fake_bin/adb"
mkdir -p "$tmp_root/browser" "$tmp_root/browser-auth" "$tmp_root/browser-invalid" "$tmp_root/browser-metadata"
browser="$({ export PATH="$fake_bin:/usr/bin:/bin" FAKE_AUTH_TAB='No services found'; source "$SCRIPT"; capture_android_browser "$tmp_root/browser"; })"
[[ "$browser" == *$'\tcustom_tab_fallback' ]] || fail "custom tabs fallback was not recorded"
auth_browser="$({ export PATH="$fake_bin:/usr/bin:/bin" FAKE_AUTH_TAB='com.android.chrome/.AuthTabService'; source "$SCRIPT"; capture_android_browser "$tmp_root/browser-auth"; })"
[[ "$auth_browser" == *$'\tauth_tab' ]] || fail "Auth Tab capability was not recorded"
expect_fail 'NP-ANDROID-BROWSER-CAPABILITY' env PATH="$fake_bin:/usr/bin:/bin" FAKE_AUTH_TAB='malicious.example/.Service' bash -c 'source "$1"; capture_android_browser "$2"' bash "$SCRIPT" "$tmp_root/browser-invalid"
expect_fail 'NP-ANDROID-BROWSER-CAPABILITY' env PATH="$fake_bin:/usr/bin:/bin" FAKE_AUTH_TAB='priority=0' bash -c 'source "$1"; capture_android_browser "$2"' bash "$SCRIPT" "$tmp_root/browser-metadata"

echo 'native-proof-provision tests: PASS'
