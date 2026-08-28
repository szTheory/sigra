#!/usr/bin/env bash
# Validates native-proof prerequisites. This command is deliberately observation-only
# until the final atomic environment-lock publication.
set -euo pipefail
umask 077

readonly RULE_ARGUMENTS='NP-ARGUMENTS'
readonly RULE_ARCH='NP-IOS-ARCH'
readonly RULE_LABELS='NP-IOS-RUNNER-LABELS'
readonly RULE_XCODE='NP-IOS-XCODE'
readonly RULE_TEAM='NP-IOS-DEVELOPMENT-TEAM'
readonly RULE_SIGNING='NP-IOS-SIGNING'
readonly RULE_DEVICE='NP-IOS-DEVICE-UNAVAILABLE'
readonly RULE_SIMULATOR='NP-IOS-SIMULATOR'
readonly RULE_DESTINATION='NP-IOS-DESTINATION'
readonly RULE_REDACTION='NP-IOS-LOCK-REDACTION'
readonly RULE_ANDROID_ARCH='NP-ANDROID-ARCH'
readonly RULE_ANDROID_SDK='NP-ANDROID-SDK'
readonly RULE_ANDROID_JDK='NP-ANDROID-JDK'
readonly RULE_ANDROID_PACKAGE='NP-ANDROID-PACKAGE'
readonly RULE_ANDROID_EMULATOR='NP-ANDROID-EMULATOR'
readonly RULE_ANDROID_BROWSER='NP-ANDROID-BROWSER'
readonly RULE_ANDROID_CAPABILITY='NP-ANDROID-BROWSER-CAPABILITY'
readonly RULE_ANDROID_LOCK='NP-ANDROID-LOCK'
readonly RULE_ANDROID_WRAPPER='NP-ANDROID-WRAPPER'
readonly RULE_ANDROID_GRADLE='NP-ANDROID-GRADLE'
readonly RULE_ANDROID_KVM='NP-ANDROID-KVM'
readonly EXPECTED_LABELS='ARM64,macOS,self-hosted,sigra-ios-physical'
readonly LOCK_PATH_DEFAULT='test/example/native/native-proof-environment.lock.json'
readonly ANDROID_PROJECT_ROOT_DEFAULT='test/example/native/android'
readonly GRADLE_VERSION='8.13'
readonly GRADLE_DISTRIBUTION_SHA256='20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78'
readonly ANDROID_IMAGE='system-images;android-36;google_apis_playstore;x86_64'
readonly ANDROID_IMAGE_DIRECTORY='system-images/android-36/google_apis_playstore/x86_64'
readonly ANDROID_AVD_NAME='sigraNativeProofPixel8'
readonly ANDROID_AVD_SERIAL='emulator-5562'
readonly ANDROID_AVD_PORT='5562'
readonly EMULATOR_ARCHIVE_URL='https://dl.google.com/android/repository/emulator-linux_x64-15917651.zip'
readonly EMULATOR_ARCHIVE_SHA1='1b1f78891abf8ec268264356e1365c25519e8379'
readonly CMDLINE_TOOLS_ARCHIVE_URL='https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip'
readonly CMDLINE_TOOLS_ARCHIVE_SHA1='e025545c62a8e64c7559119566a569fb1dec5f60'

fail() { printf '%s\n' "$1" >&2; exit 1; }
sha256() { /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'; }

canonical_labels() {
  printf '%s' "$1" | /usr/bin/tr ',' '\n' | /usr/bin/sed '/^$/d' | /usr/bin/sort -u | /usr/bin/paste -sd, -
}

discover_single_udid() {
  local run_root json_path discovered raw candidates count
  # CoreDevice exposes a supported script interface only through --json-output.
  # Keep the raw response in a mode-0700 run root and unlink it before returning.
  run_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-native-proof-device.XXXXXX")"
  chmod 700 "$run_root"
  json_path="$run_root/devices.json"
  if xcrun devicectl list devices --timeout 15 --json-output "$json_path" >/dev/null 2>&1; then
    discovered="$(/usr/bin/python3 - "$json_path" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1], encoding="utf-8"))["result"]["devices"]
eligible = [d for d in devices if str(d.get("hardwareProperties", {}).get("platform", "")).lower() == "ios" and "simulator" not in str(d.get("hardwareProperties", {}).get("deviceType", "")).lower()]
if len(eligible) == 1:
    value = eligible[0].get("hardwareProperties", {}).get("udid") or eligible[0].get("identifier")
    if isinstance(value, str) and value:
        print(value)
PY
)"
  fi
  [[ ! -f "$json_path" ]] || /bin/unlink "$json_path"
  rmdir "$run_root"
  if [[ -n "$discovered" ]]; then
    printf '%s\n' "$discovered"
    return 0
  fi
  raw="$(xcrun xctrace list devices 2>/dev/null || true)"
  candidates="$(printf '%s\n' "$raw" | /usr/bin/awk '
    !/[Ss]imulator/ && !/[Uu]navailable/ {
      value = $0
      sub(/^.*\(/, "", value)
      sub(/\)[[:space:]]*$/, "", value)
      if (value ~ /^[A-Fa-f0-9-]+$/ && length(value) >= 20) print value
    }
  ' || true)"
  count="$(printf '%s\n' "$candidates" | /usr/bin/sed '/^$/d' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
  [[ "$count" == 1 ]] || return 1
  printf '%s\n' "$candidates"
}

discover_single_team() {
  local candidates count
  candidates="$(security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -Eo '\([A-Z0-9]{10}\)' | /usr/bin/tr -d '()' | /usr/bin/sort -u || true)"
  count="$(printf '%s\n' "$candidates" | /usr/bin/sed '/^$/d' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
  [[ "$count" == 1 ]] || return 1
  printf '%s\n' "$candidates"
}

selected_physical_device_metadata() {
  local udid="$1" run_root json_path metadata
  run_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-native-proof-device.XXXXXX")"
  chmod 700 "$run_root"
  json_path="$run_root/devices.json"
  xcrun devicectl list devices --timeout 15 --json-output "$json_path" >/dev/null 2>&1 || {
    rmdir "$run_root"
    return 1
  }
  metadata="$(/usr/bin/python3 - "$json_path" "$udid" <<'PY'
import json, re, sys

path, selected_udid = sys.argv[1:]
devices = json.load(open(path, encoding="utf-8")).get("result", {}).get("devices", [])
eligible = []
selected = None
for device in devices:
    hardware = device.get("hardwareProperties", {})
    platform = str(hardware.get("platform", "")).lower()
    device_type = str(hardware.get("deviceType", "")).lower()
    if platform == "ios" and "simulator" not in device_type:
        eligible.append(device)
        identifier = str(hardware.get("udid") or device.get("identifier") or "")
        if identifier == selected_udid:
            selected = device

if len(eligible) != 1 or selected is None:
    raise SystemExit(1)

connection = selected.get("connectionProperties", {})
if str(connection.get("pairingState", "")).lower() != "paired":
    raise SystemExit(1)

properties = selected.get("deviceProperties", {})
model = str(selected.get("hardwareProperties", {}).get("marketingName", ""))
os_version = str(properties.get("osVersionNumber", ""))
if not model or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", os_version):
    raise SystemExit(1)
print(f"{model}\t{os_version}")
PY
)" || true
  [[ ! -f "$json_path" ]] || /bin/unlink "$json_path"
  rmdir "$run_root"
  [[ -n "$metadata" ]] || return 1
  printf '%s\n' "$metadata"
}

discover_ios() {
  local udid team xcode
  udid="$(discover_single_udid || true)"
  team="$(discover_single_team || true)"
  [[ -n "$udid" ]] || fail "$RULE_DEVICE"
  [[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "$RULE_TEAM"
  xcode="$(xcodebuild -version 2>/dev/null || true)"
  [[ "$xcode" == *'Xcode 26.6'* && "$xcode" == *'Build version 17F113'* ]] || fail "$RULE_XCODE"
  # This is intentionally bounded: it proves only uniqueness/readiness and never
  # emits a UDID, signing identity, team, device model, or keychain material.
  printf '%s\n' '{"schema_version":1,"device_candidates":1,"development_team_candidates":1,"xcode_version":"26.6","xcode_build":"17F113","complete":true}'
}

validate_ios() {
  local udid="${SIGRA_IOS_DEVICE_UDID:-}" team="${SIGRA_IOS_DEVELOPMENT_TEAM:-}"
  local labels xcode device_line metadata model os binding lock_path lock_dir tmp_lock
  [[ "$(uname -m)" == arm64 ]] || fail "$RULE_ARCH"
  labels="$(canonical_labels "${SIGRA_IOS_RUNNER_LABELS:-}")"
  [[ "$labels" == "$EXPECTED_LABELS" ]] || fail "$RULE_LABELS"
  xcode="$(xcodebuild -version 2>/dev/null || true)"
  [[ "$xcode" == *'Xcode 26.6'* && "$xcode" == *'Build version 17F113'* ]] || fail "$RULE_XCODE"
  [[ -n "$udid" ]] || udid="$(discover_single_udid || true)"
  [[ -n "$team" ]] || team="$(discover_single_team || true)"
  [[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "$RULE_TEAM"
  security find-identity -v -p codesigning >/dev/null 2>&1 || fail "$RULE_SIGNING"
  device_line="$(xcrun xctrace list devices 2>/dev/null | /usr/bin/grep -F "($udid)" | /usr/bin/head -n 1 || true)"
  [[ -n "$device_line" ]] || fail "$RULE_DEVICE"
  [[ "$device_line" != *Simulator* && "$device_line" != *simulator* && "$device_line" != *unavailable* ]] || fail "$RULE_SIMULATOR"
  metadata="$(selected_physical_device_metadata "$udid" || true)"
  [[ -n "$metadata" ]] || fail "$RULE_DESTINATION"
  model="${metadata%%$'\t'*}"
  os="${metadata#*$'\t'}"
  model="$(printf '%s' "$model" | /usr/bin/sed -E 's/[0-9]+/N/g' | /usr/bin/tr -cd '[:alnum:] _-' | /usr/bin/sed 's/^ *//;s/ *$//' | /usr/bin/cut -c1-80)"
  [[ -n "$model" ]] || fail "$RULE_DEVICE"
  [[ "$os" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || fail "$RULE_DEVICE"
  binding="$(printf '%s\0%s\0%s' "$udid" "$team" "${GITHUB_RUN_ID:-local}" | sha256)"
  lock_path="${SIGRA_NATIVE_PROOF_LOCK_PATH:-$LOCK_PATH_DEFAULT}"
  lock_dir="$(dirname "$lock_path")"
  mkdir -p "$lock_dir"; chmod 700 "$lock_dir"
  tmp_lock="$(mktemp "$lock_dir/.native-proof-lock.XXXXXX")"
  trap 'rm -f "${tmp_lock:-}"' RETURN
  /usr/bin/python3 - "$tmp_lock" "$model" "$os" "$binding" <<'PY'
import json, os, sys
path, model, os_version, binding = sys.argv[1:]
data = {"schema_version": 1, "ios_runner_class": "self_hosted_attached_device", "ios_runner_labels": ["self-hosted", "macOS", "ARM64", "sigra-ios-physical"], "runner_arch": "arm64", "xcode_version": "26.6", "xcode_build": "17F113", "ios_device_class": model, "ios_os_version": os_version, "ios_device_binding_digest": binding, "ios_callback": "sigra-native-proof://auth/callback", "android_callback": "sigra-native-proof://auth/android", "callback_transport": "custom_scheme", "complete": True}
with open(path, "w", encoding="utf-8") as f: json.dump(data, f, sort_keys=True, separators=(",", ":")); f.write("\n")
os.chmod(path, 0o600)
PY
  # Test-only poison permits a hermetic assertion that redaction failures block
  # publication; production callers never set it.
  [[ -z "${SIGRA_NATIVE_PROOF_TEST_LEAK:-}" ]] || fail "$RULE_REDACTION"
  if /usr/bin/grep -Fq "$udid" "$tmp_lock" || /usr/bin/grep -Fq "$team" "$tmp_lock" || /usr/bin/grep -Eq 'Apple Development|VALID-ONLY-TEST' "$tmp_lock"; then fail "$RULE_REDACTION"; fi
  mv -f "$tmp_lock" "$lock_path"
  trap - RETURN
}

android_project_root() { printf '%s\n' "${SIGRA_ANDROID_PROJECT_ROOT:-$ANDROID_PROJECT_ROOT_DEFAULT}"; }
android_lock_path() { printf '%s/toolchain.lock.json\n' "$(android_project_root)"; }
android_sha256_file() { sha256 <"$1"; }

require_linux_x86_64() {
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "$RULE_ANDROID_ARCH"
}

require_jdk_17() {
  local version
  version="$(java -version 2>&1 | /usr/bin/head -n 1 || true)"
  [[ "$version" == *'17.'* || "$version" == *'"17"'* ]] || fail "$RULE_ANDROID_JDK"
}

sdkmanager_is_transient_failure() {
  /usr/bin/grep -Eqi 'timeout|timed out|connection reset|temporar|429|5[0-9]{2}|unknown archive|zipfile|download.*fail|ssl.*reset' "$1"
}

install_android_packages() {
  local sdkmanager="$1" sdk="$2" output attempt=1
  local -a packages=(
    'platform-tools' 'emulator' 'platforms;android-36'
    'build-tools;35.0.0' "$ANDROID_IMAGE"
  )
  # Licenses are accepted only for the explicit stable packages below; no mutable
  # channel alias is requested by this runner.
  set +o pipefail
  yes | "$sdkmanager" --sdk_root="$sdk" --licenses >/dev/null
  set -o pipefail
  while :; do
    output="$(mktemp "${SIGRA_ANDROID_RUN_ROOT}/sdkmanager.XXXXXX")"
    if "$sdkmanager" --sdk_root="$sdk" --install "${packages[@]}" >"$output" 2>&1; then
      rm -f "$output"
      return 0
    fi
    if [[ "$attempt" == 1 ]] && sdkmanager_is_transient_failure "$output"; then
      rm -f "$output"
      attempt=2
      continue
    fi
    sed -n '1,120p' "$output" >&2
    rm -f "$output"
    fail "$RULE_ANDROID_PACKAGE"
  done
}

install_exact_cmdline_tools() {
  local sdk="$1" archive="$SIGRA_ANDROID_RUN_ROOT/cmdline-tools-23.0.zip" unpack="$SIGRA_ANDROID_RUN_ROOT/cmdline-tools-unpack"
  curl --fail --location --retry 2 --retry-all-errors "$CMDLINE_TOOLS_ARCHIVE_URL" -o "$archive" || fail "$RULE_ANDROID_PACKAGE"
  [[ "$(sha1sum "$archive" | awk '{print $1}')" == "$CMDLINE_TOOLS_ARCHIVE_SHA1" ]] || fail "$RULE_ANDROID_PACKAGE"
  unzip -q "$archive" -d "$unpack" || fail "$RULE_ANDROID_PACKAGE"
  [[ -d "$unpack/cmdline-tools" ]] || fail "$RULE_ANDROID_PACKAGE"
  mkdir -p "$sdk/cmdline-tools"
  [[ ! -e "$sdk/cmdline-tools/23.0" ]] || mv "$sdk/cmdline-tools/23.0" "$SIGRA_ANDROID_RUN_ROOT/sdk-cmdline-tools-replaced"
  mv "$unpack/cmdline-tools" "$sdk/cmdline-tools/23.0"
}

install_exact_emulator() {
  local sdk="$1" archive="$SIGRA_ANDROID_RUN_ROOT/emulator-37.1.11.zip" unpack="$SIGRA_ANDROID_RUN_ROOT/emulator-unpack"
  curl --fail --location --retry 2 --retry-all-errors "$EMULATOR_ARCHIVE_URL" -o "$archive" || fail "$RULE_ANDROID_PACKAGE"
  [[ "$(sha1sum "$archive" | awk '{print $1}')" == "$EMULATOR_ARCHIVE_SHA1" ]] || fail "$RULE_ANDROID_PACKAGE"
  unzip -q "$archive" -d "$unpack" || fail "$RULE_ANDROID_PACKAGE"
  [[ -d "$unpack/emulator" ]] || fail "$RULE_ANDROID_PACKAGE"
  [[ ! -e "$sdk/emulator" ]] || mv "$sdk/emulator" "$SIGRA_ANDROID_RUN_ROOT/sdk-emulator-replaced"
  mv "$unpack/emulator" "$sdk/emulator"
}

require_sdk_property() {
  local path="$1" expected="$2"
  if [[ ! -f "$path" ]] || ! /usr/bin/grep -Fxq "Pkg.Revision=$expected" "$path"; then
    printf 'Android package revision mismatch: path=%s expected=%s actual=%s\n' "$path" "$expected" "$(sed -n 's/^Pkg.Revision=//p' "$path" 2>/dev/null | head -n 1)" >&2
    fail "$RULE_ANDROID_PACKAGE"
  fi
}

validate_android_sdk() {
  local sdk="$1"
  require_sdk_property "$sdk/cmdline-tools/23.0/source.properties" '23.0'
  require_sdk_property "$sdk/platform-tools/source.properties" '37.0.1'
  require_sdk_property "$sdk/emulator/source.properties" '37.1.11'
  [[ -d "$sdk/platforms/android-36" && -d "$sdk/build-tools/35.0.0" ]] || fail "$RULE_ANDROID_PACKAGE"
  require_sdk_property "$sdk/$ANDROID_IMAGE_DIRECTORY/source.properties" '7'
}

cleanup_android() {
  local status=$? attempts=10 log="${SIGRA_ANDROID_RUN_ROOT:-}/emulator.log"
  if [[ -n "${SIGRA_ANDROID_EMULATOR_PID:-}" ]] && kill -0 "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1; then
    adb -s "$ANDROID_AVD_SERIAL" emu kill >/dev/null 2>&1 || true
    while (( attempts > 0 )) && kill -0 "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1; do sleep 1; attempts=$((attempts - 1)); done
    if kill -0 "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1; then
      kill -TERM "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1 || true
      sleep 1
      kill -0 "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1 && kill -KILL "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1 || true
    fi
    wait "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1 || true
    [[ "$status" == 0 || ! -f "$log" ]] || tail -n 120 "$log" >&2 || true
  fi
  if [[ -n "${SIGRA_ANDROID_AVD_HOME:-}" && -x "${SIGRA_ANDROID_AVDMANAGER:-}" ]]; then
    "$SIGRA_ANDROID_AVDMANAGER" delete avd -n "$ANDROID_AVD_NAME" >/dev/null 2>&1 || true
  fi
  [[ -z "${SIGRA_ANDROID_RUN_ROOT:-}" ]] || rm -rf "$SIGRA_ANDROID_RUN_ROOT"
  exit "$status"
}

normalize_android_component() {
  local value
  value="$(tr -d '\r' | sed '/^$/d' | tail -n 1)"
  case "$value" in 'No service found'|'No activity found'|'No matching activity found'|'null') return 0 ;; esac
  [[ "$value" == com.android.chrome/* ]] || return 1
  printf '%s\n' "$value"
}

wait_for_android_boot() {
  local attempts=90 value=''
  while (( attempts > 0 )); do
    kill -0 "$SIGRA_ANDROID_EMULATOR_PID" >/dev/null 2>&1 || fail "$RULE_ANDROID_EMULATOR"
    if ! adb devices | grep -Fxq "$ANDROID_AVD_SERIAL	device"; then sleep 2; attempts=$((attempts - 1)); continue; fi
    value="$(adb -s "$ANDROID_AVD_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    [[ "$value" == 1 ]] && return 0
    sleep 2
    attempts=$((attempts - 1))
  done
  fail "$RULE_ANDROID_EMULATOR"
}

capture_android_browser() {
  local root="$1" package_paths version apk_sha custom_tabs auth_tab index=0 manifest package_path basename
  package_paths="$(adb -s "$ANDROID_AVD_SERIAL" shell pm path com.android.chrome 2>/dev/null | sed -n 's/^package://p' | tr -d '\r' | LC_ALL=C sort)"
  [[ -n "$package_paths" ]] || fail "$RULE_ANDROID_BROWSER"
  version="$(adb -s "$ANDROID_AVD_SERIAL" shell dumpsys package com.android.chrome 2>/dev/null | sed -n 's/^[[:space:]]*versionName=//p' | /usr/bin/head -n 1 | tr -d '\r')"
  [[ -n "$version" ]] || fail "$RULE_ANDROID_BROWSER"
  manifest="$root/chrome-apks.manifest"
  while IFS= read -r package_path; do
    [[ -n "$package_path" ]] || continue
    adb -s "$ANDROID_AVD_SERIAL" pull "$package_path" "$root/chrome-${index}.apk" >/dev/null || fail "$RULE_ANDROID_BROWSER"
    basename="${package_path##*/}"
    [[ "$basename" =~ ^[A-Za-z0-9._-]+\.apk$ ]] || fail "$RULE_ANDROID_BROWSER"
    # Device installation directories are mutable; retain only stable split names
    # and content hashes. Do not de-duplicate: split multiplicity is evidence.
    printf '%s\t%s\n' "$basename" "$(android_sha256_file "$root/chrome-${index}.apk")" >>"$manifest"
    index=$((index + 1))
  done <<<"$package_paths"
  [[ "$index" -gt 0 ]] || fail "$RULE_ANDROID_BROWSER"
  # browser_apk_sha256 is the SHA-256 of this canonical sorted path/hash
  # manifest, covering every base and split APK without changing the lock schema.
  apk_sha="$(android_sha256_file "$manifest")"
  [[ "$apk_sha" =~ ^[a-f0-9]{64}$ ]] || fail "$RULE_ANDROID_BROWSER"
  auth_tab="$(adb -s "$ANDROID_AVD_SERIAL" shell cmd package resolve-service --brief -a android.support.customtabs.action.CustomTabsService -c androidx.browser.auth.category.AuthTab -p com.android.chrome 2>/dev/null | normalize_android_component)" || fail "$RULE_ANDROID_CAPABILITY"
  custom_tabs="$(adb -s "$ANDROID_AVD_SERIAL" shell cmd package resolve-service --brief -a android.support.customtabs.action.CustomTabsService -p com.android.chrome 2>/dev/null | normalize_android_component)" || fail "$RULE_ANDROID_CAPABILITY"
  if [[ -n "$auth_tab" ]]; then printf '%s\t%s\tauth_tab\n' "$version" "$apk_sha"; return; fi
  [[ "$custom_tabs" == com.android.chrome/* ]] || fail "$RULE_ANDROID_CAPABILITY"
  printf '%s\t%s\tcustom_tab_fallback\n' "$version" "$apk_sha"
}

write_android_lock() {
  local lock="$1" browser_version="$2" browser_sha="$3" browser_mode="$4" wrapper_sha="$5" tmp
  mkdir -p "$(dirname "$lock")"
  tmp="$(mktemp "$(dirname "$lock")/.toolchain.lock.XXXXXX")"
  trap 'rm -f "${tmp:-}"' RETURN
  python3 - "$tmp" "$browser_version" "$browser_sha" "$browser_mode" "$wrapper_sha" <<'PY'
import json, os, sys
path, browser_version, browser_sha, browser_mode, wrapper_sha = sys.argv[1:]
data = {"schema_version": 1, "jdk": "17", "cmdline_tools": "23.0", "platform_tools": "37.0.1", "emulator": "37.1.11", "sdk_platform": "android-36", "build_tools": "35.0.0", "system_image": "system-images;android-36;google_apis_playstore;x86_64", "system_image_revision": 7, "abi": "x86_64", "avd_device": "pixel_8", "browser_package": "com.android.chrome", "browser_version": browser_version, "browser_apk_sha256": browser_sha, "browser_mode": browser_mode, "gradle": "8.13", "gradle_distribution_sha256": "20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78", "gradle_wrapper_jar_sha256": wrapper_sha, "agp": "8.13.2", "kotlin": "2.2.10", "androidx_browser": "1.9.0", "test_core": "1.7.0", "test_runner": "1.7.0", "espresso": "3.7.0", "uiautomator": "2.4.0", "complete": True}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, sort_keys=True, separators=(",", ":")); handle.write("\n")
os.chmod(path, 0o600)
PY
  mv -f "$tmp" "$lock"
  trap - RETURN
}

validate_android_lock() {
  local project lock jar properties actual_jar
  project="$(android_project_root)"; lock="$(android_lock_path)"
  jar="$project/gradle/wrapper/gradle-wrapper.jar"; properties="$project/gradle/wrapper/gradle-wrapper.properties"
  [[ -f "$lock" && -f "$jar" && -f "$properties" && -x "$project/gradlew" && -f "$project/gradlew.bat" ]] || fail "$RULE_ANDROID_LOCK"
  python3 - "$lock" "$GRADLE_DISTRIBUTION_SHA256" <<'PY' || fail "$RULE_ANDROID_LOCK"
import json, re, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
required = {"schema_version": 1, "jdk": "17", "cmdline_tools": "23.0", "platform_tools": "37.0.1", "emulator": "37.1.11", "sdk_platform": "android-36", "build_tools": "35.0.0", "system_image": "system-images;android-36;google_apis_playstore;x86_64", "system_image_revision": 7, "abi": "x86_64", "avd_device": "pixel_8", "browser_package": "com.android.chrome", "gradle": "8.13", "gradle_distribution_sha256": sys.argv[2], "agp": "8.13.2", "kotlin": "2.2.10", "androidx_browser": "1.9.0", "test_core": "1.7.0", "test_runner": "1.7.0", "espresso": "3.7.0", "uiautomator": "2.4.0", "complete": True}
dynamic = {"browser_version", "browser_apk_sha256", "browser_mode", "gradle_wrapper_jar_sha256"}
if set(data) != set(required) | dynamic: raise SystemExit(1)
if type(data["schema_version"]) is not int or type(data["system_image_revision"]) is not int or type(data["complete"]) is not bool: raise SystemExit(1)
if any(data[k] != v for k, v in required.items()): raise SystemExit(1)
if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,4}", data["browser_version"]): raise SystemExit(1)
if not re.fullmatch(r"[a-f0-9]{64}", data["browser_apk_sha256"]): raise SystemExit(1)
if data["browser_mode"] not in {"auth_tab", "custom_tab_fallback"}: raise SystemExit(1)
if not re.fullmatch(r"[a-f0-9]{64}", data["gradle_wrapper_jar_sha256"]): raise SystemExit(1)
PY
  actual_jar="$(android_sha256_file "$jar")"
  python3 - "$lock" "$actual_jar" <<'PY' || fail "$RULE_ANDROID_WRAPPER"
import json, sys
raise SystemExit(0 if json.load(open(sys.argv[1], encoding="utf-8"))["gradle_wrapper_jar_sha256"] == sys.argv[2] else 1)
PY
  /usr/bin/grep -Fq "distributionUrl=https\\://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" "$properties" && /usr/bin/grep -Fq "distributionSha256Sum=$GRADLE_DISTRIBUTION_SHA256" "$properties" || fail "$RULE_ANDROID_WRAPPER"
}

generate_gradle_wrapper() {
  local project root archive unpack
  project="$1"; root="$2"; archive="$root/gradle-${GRADLE_VERSION}-bin.zip"; unpack="$root/gradle"
  mkdir -p "$project"
  curl --fail --location --retry 2 --retry-all-errors "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o "$archive" || fail "$RULE_ANDROID_GRADLE"
  [[ "$(android_sha256_file "$archive")" == "$GRADLE_DISTRIBUTION_SHA256" ]] || fail "$RULE_ANDROID_GRADLE"
  unzip -q "$archive" -d "$unpack" || fail "$RULE_ANDROID_GRADLE"
  "$unpack/gradle-${GRADLE_VERSION}/bin/gradle" -p "$project" wrapper --gradle-version "$GRADLE_VERSION" --distribution-type bin --no-daemon --console=plain >/dev/null || fail "$RULE_ANDROID_GRADLE"
  python3 - "$project/gradle/wrapper/gradle-wrapper.properties" "$GRADLE_DISTRIBUTION_SHA256" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); text = p.read_text(encoding="utf-8")
text = "\n".join(line for line in text.splitlines() if not line.startswith("distributionSha256Sum=")) + "\n"
p.write_text(text + "distributionSha256Sum=" + sys.argv[2] + "\n", encoding="utf-8")
PY
  chmod 0755 "$project/gradlew"
  chmod 0644 "$project/gradlew.bat" "$project/gradle/wrapper/gradle-wrapper.jar" "$project/gradle/wrapper/gradle-wrapper.properties"
}

validate_android() {
  local sdk sdkmanager avdmanager emulator project browser version sha mode wrapper_sha
  require_linux_x86_64; require_jdk_17
  [[ -r /dev/kvm && -w /dev/kvm ]] || fail "$RULE_ANDROID_KVM"
  sdk="${ANDROID_SDK_ROOT:-}"; [[ -n "$sdk" && -d "$sdk" && -w "$sdk" ]] || fail "$RULE_ANDROID_SDK"
  sdkmanager="${SIGRA_ANDROID_SDKMANAGER:-$sdk/cmdline-tools/latest/bin/sdkmanager}"
  [[ -x "$sdkmanager" ]] || fail "$RULE_ANDROID_SDK"
  export SIGRA_ANDROID_RUN_ROOT="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/sigra-native-proof-android.XXXXXX")"
  chmod 700 "$SIGRA_ANDROID_RUN_ROOT"; export ANDROID_AVD_HOME="$SIGRA_ANDROID_RUN_ROOT/avd" ANDROID_EMULATOR_HOME="$SIGRA_ANDROID_RUN_ROOT/emulator" SIGRA_ANDROID_AVD_HOME="$SIGRA_ANDROID_RUN_ROOT/avd"
  export PATH="$sdk/cmdline-tools/23.0/bin:$sdk/platform-tools:$sdk/emulator:$PATH"
  avdmanager="$sdk/cmdline-tools/23.0/bin/avdmanager"; emulator="$sdk/emulator/emulator"; export SIGRA_ANDROID_AVDMANAGER="$avdmanager"
  trap cleanup_android EXIT
  install_android_packages "$sdkmanager" "$sdk"; install_exact_cmdline_tools "$sdk"
  [[ -x "$avdmanager" && -x "$emulator" ]] || fail "$RULE_ANDROID_SDK"
  # avdmanager requires the SDK-manager package registry entry. Create the AVD
  # while that registration exists, then replace the executable directory with
  # the checked 37.1.11 archive before validation or boot.
  set +o pipefail
  yes no | "$avdmanager" create avd -n "$ANDROID_AVD_NAME" -k "$ANDROID_IMAGE" -d pixel_8 --force >/dev/null
  set -o pipefail
  install_exact_emulator "$sdk"; validate_android_sdk "$sdk"
  "$emulator" @"$ANDROID_AVD_NAME" -accel on -port "$ANDROID_AVD_PORT" -no-window -no-boot-anim -no-audio -gpu swiftshader_indirect -no-snapshot-load -no-snapshot-save -wipe-data >"$SIGRA_ANDROID_RUN_ROOT/emulator.log" 2>&1 &
  SIGRA_ANDROID_EMULATOR_PID=$!; wait_for_android_boot
  browser="$(capture_android_browser "$SIGRA_ANDROID_RUN_ROOT")"; version="${browser%%$'\t'*}"; browser="${browser#*$'\t'}"; sha="${browser%%$'\t'*}"; mode="${browser#*$'\t'}"
  project="$(android_project_root)"; generate_gradle_wrapper "$project" "$SIGRA_ANDROID_RUN_ROOT"; wrapper_sha="$(android_sha256_file "$project/gradle/wrapper/gradle-wrapper.jar")"
  write_android_lock "$(android_lock_path)" "$version" "$sha" "$mode" "$wrapper_sha"
  validate_android_lock
  (cd "$project" && ./gradlew --no-daemon --console=plain --version >/dev/null) || fail "$RULE_ANDROID_GRADLE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --validate-ios) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; validate_ios ;;
    --discover-ios) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; discover_ios ;;
    --validate-android) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; validate_android ;;
    --validate-android-lock) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; validate_android_lock ;;
    *) fail "$RULE_ARGUMENTS" ;;
  esac
fi
