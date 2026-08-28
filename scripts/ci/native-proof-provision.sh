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
readonly EXPECTED_LABELS='ARM64,macOS,self-hosted,sigra-ios-physical'
readonly LOCK_PATH_DEFAULT='test/example/native/native-proof-environment.lock.json'

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

case "${1:-}" in
  --validate-ios) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; validate_ios ;;
  --discover-ios) [[ $# == 1 ]] || fail "$RULE_ARGUMENTS"; discover_ios ;;
  *) fail "$RULE_ARGUMENTS" ;;
esac
