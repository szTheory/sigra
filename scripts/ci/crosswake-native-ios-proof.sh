#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT_DIR/test/example/native/ios/SigraNativeProof/SigraNativeProof.xcodeproj"
SCHEME="SigraNativeProof"
UI_TARGET="SigraNativeProofUITests"
EVIDENCE_RELATIVE_PATH=".planning/phases/248-crosswake-native-proof/248-IOS-EVIDENCE.json"
EVIDENCE_PATH="${SIGRA_IOS_EVIDENCE_PATH:-$ROOT_DIR/$EVIDENCE_RELATIVE_PATH}"
TEST_MODE="${SIGRA_IOS_PROOF_TEST_MODE:-0}"
RULE_TARGET="NP-IOS-PHYSICAL-TARGET"
RULE_INPUT="NP-IOS-PROOF-INPUT"
RULE_HOST="NP-IOS-LIVE-HOST"
RULE_BUILD="NP-IOS-BUILD"
RULE_TEST="NP-IOS-TEST"
RULE_REPORT="NP-IOS-REPORT"
RULE_CLEANUP="NP-IOS-CLEANUP"
RULE_SCAN="NP-IOS-SECRET-SCAN"
RUN_ROOT=""
HOST_PID=""
PROOF_EMAIL=""
PROOF_PASSWORD=""
DEVICE_UDID=""
DEVELOPMENT_TEAM=""
ACCOUNT_CREATED=0

fail() { printf 'crosswake native iOS proof: %s\n' "$1" >&2; exit 2; }
event() { [[ -n "${SIGRA_IOS_PROOF_TEST_EVENTS:-}" ]] && printf '%s\n' "$1" >>"$SIGRA_IOS_PROOF_TEST_EVENTS" || true; }

cleanup() {
  local cleanup_status=0
  if [[ -n "$HOST_PID" ]]; then
    kill "$HOST_PID" 2>/dev/null || true
    wait "$HOST_PID" 2>/dev/null || true
  fi
  if [[ "$ACCOUNT_CREATED" == 1 && -n "$PROOF_EMAIL" ]]; then
    (
      cd "$ROOT_DIR/test/example"
      SIGRA_NATIVE_PROOF_EMAIL="$PROOF_EMAIL" MIX_ENV=test mix run --no-compile --no-deps-check -e '
        alias Example.{Accounts, Repo}
        case Accounts.get_user_by_email(System.fetch_env!("SIGRA_NATIVE_PROOF_EMAIL")) do
          nil -> :ok
          user -> Repo.delete!(user)
        end
      ' >/dev/null 2>&1
    ) || cleanup_status=1
  fi
  if [[ -n "$RUN_ROOT" && -d "$RUN_ROOT" ]]; then
    rm -rf "$RUN_ROOT" || cleanup_status=1
  fi
  [[ $cleanup_status -eq 0 ]]
}
trap 'cleanup || true' EXIT HUP INT TERM

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_tree() {
  local root="$1"
  (
    cd "$root"
    find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' file; do
      printf '%s  %s\n' "$(shasum -a 256 "$file" | awk '{print $1}')" "$file"
    done
  ) | shasum -a 256 | awk '{print $1}'
}

run_bounded() {
  local seconds="$1"
  shift
  python3 - "$seconds" "$@" <<'PY'
import subprocess, sys
seconds = int(sys.argv[1])
try:
    raise SystemExit(subprocess.run(sys.argv[2:], check=False, timeout=seconds).returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
}

run_host_setup_step() {
  local label="$1" log_path="$2"
  shift 2
  if run_bounded 1200 "$@" >"$log_path" 2>&1; then return; fi
  printf 'crosswake native iOS proof: host setup failed at %s\n' "$label" >&2
  sed -E 's/((password|token|secret|authorization|code_verifier)[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
    "$log_path" | tail -80 >&2 || true
  fail "$RULE_HOST-$label"
}

redacted_host_runtime_diagnostics() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return
  grep -E '^\[info\] (Running|Access|Sent)|^\[warning\]|^\[error\]|^\*\* \(' \
    "$log_path" | tail -80 >&2 || true
}

redacted_xcode_diagnostics() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return
  python3 - "$log_path" "$DEVICE_UDID" "$DEVELOPMENT_TEAM" "$PROOF_EMAIL" "$PROOF_PASSWORD" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
for private in sys.argv[2:]:
    if private:
        text = text.replace(private, "[REDACTED]")
allowed = re.compile(r"(^|: )(error:|warning:)|CodeSign|Provisioning|Signing|BUILD (FAILED|SUCCEEDED)|Testing failed|xcodebuild:", re.I)
secret = re.compile(r"access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer\s", re.I)
lines = []
for line in text.splitlines():
    if not allowed.search(line):
        continue
    line = secret.sub("[REDACTED]", line)
    lines.append(line)
print("\n".join(lines[-120:]), file=sys.stderr)
PY
  event xcode_diagnostics_emitted
}

discover_target_once() {
  TARGET_DIAGNOSTIC="arch"
  [[ "$(uname -m)" == arm64 ]] || return 1
  local device_json="$RUN_ROOT/devices.json"
  TARGET_DIAGNOSTIC="xcdevice"
  xcrun xcdevice list >"$device_json" 2>/dev/null || return 1
  local selected="$RUN_ROOT/selected-target.json"
  TARGET_DIAGNOSTIC="xcdevice-selection"
  python3 - "$device_json" "$selected" "${SIGRA_IOS_DEVICE_UDID:-}" <<'PY' || return 1
import json, re, sys
source, output, requested = sys.argv[1:]
devices = json.load(open(source, encoding="utf-8"))
physical = [d for d in devices if d.get("simulator") is False and d.get("available") is True and d.get("platform") == "com.apple.platform.iphoneos" and "iPhone" in str(d.get("modelName") or d.get("name") or "")]
if requested:
    physical = [d for d in physical if d.get("identifier") == requested]
if len(physical) != 1:
    raise SystemExit(2)
d = physical[0]
identifier = d.get("identifier", "")
version_raw = str(d.get("operatingSystemVersion", ""))
model = d.get("modelName") or d.get("name") or ""
version_match = re.match(r"^([0-9]+(?:\.[0-9]+){1,2})(?:\s+\([^)]+\))?$", version_raw)
if not identifier or not re.fullmatch(r"[0-9A-Za-z-]{16,}", identifier) or not version_match or not re.fullmatch(r"[A-Za-z0-9 ,+_-]{1,80}", model):
    raise SystemExit(2)
version = version_match.group(1)
json.dump({"identifier":identifier,"model_class":model,"os_version":version}, open(output,"w",encoding="utf-8"), separators=(",",":"))
PY
  DEVICE_UDID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identifier"])' "$selected")"
  MODEL_CLASS="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["model_class"])' "$selected")"
  OS_VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["os_version"])' "$selected")"

  local trace="$RUN_ROOT/xctrace.txt"
  TARGET_DIAGNOSTIC="xctrace"
  xcrun xctrace list devices >"$trace" 2>/dev/null || return 1
  TARGET_DIAGNOSTIC="xctrace-selection"
  python3 - "$trace" "$DEVICE_UDID" <<'PY' || return 1
import sys
lines=[line for line in open(sys.argv[1],encoding="utf-8",errors="replace") if sys.argv[2] in line]
if len(lines)!=1 or "Simulator" in lines[0] or "iPhone" not in lines[0]: raise SystemExit(2)
PY
  local destinations="$RUN_ROOT/destinations.txt"
  TARGET_DIAGNOSTIC="xcode-destinations"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations >"$destinations" 2>/dev/null || return 1
  TARGET_DIAGNOSTIC="xcode-destination-selection"
  [[ "$(grep -F "id:$DEVICE_UDID" "$destinations" | grep -v 'platform:iOS Simulator' | wc -l | tr -d ' ')" == 1 ]] || return 1
}

discover_target() {
  if discover_target_once; then return; fi
  event "target_observation_retry"
  discover_target_once || fail "$RULE_TARGET-$TARGET_DIAGNOSTIC"
}

discover_team() {
  local identities="$RUN_ROOT/signing.txt"
  security find-identity -v -p codesigning >"$identities" 2>/dev/null || fail "$RULE_INPUT"
  grep -q '"Apple Development:' "$identities" || fail "$RULE_INPUT"
  local account_dump="$RUN_ROOT/xcode-accounts.plist" account_teams="$RUN_ROOT/account-teams.txt"
  local decoded_dir="$RUN_ROOT/decoded-profiles" profile_facts="$RUN_ROOT/profile-facts.tsv"
  mkdir -p "$decoded_dir"
  : >"$profile_facts"
  defaults export com.apple.dt.Xcode "$account_dump" >/dev/null 2>&1 || fail "$RULE_INPUT"
  python3 - "$account_dump" "$account_teams" <<'PY' || fail "$RULE_INPUT"
import plistlib, re, sys
root = plistlib.load(open(sys.argv[1], "rb"))
teams = set()
for entries in root.get("IDEProvisioningTeamByIdentifier", {}).values():
    for entry in entries:
        team = str(entry.get("teamID", ""))
        if re.fullmatch(r"[A-Z0-9]{10}", team):
            teams.add(team)
open(sys.argv[2], "w", encoding="utf-8").write("".join(f"{team}\n" for team in sorted(teams)))
PY
  local profile_index=0 decoded
  while IFS= read -r profile; do
    profile_index=$((profile_index + 1))
    decoded="$decoded_dir/$profile_index.plist"
    security cms -D -i "$profile" >"$decoded" 2>/dev/null || continue
    python3 - "$decoded" >>"$profile_facts" <<'PY' || fail "$RULE_INPUT"
import plistlib, re, sys
profile = plistlib.load(open(sys.argv[1], "rb"))
teams = profile.get("TeamIdentifier") or []
app_id = str((profile.get("Entitlements") or {}).get("application-identifier", ""))
for team in teams:
    if re.fullmatch(r"[A-Z0-9]{10}", str(team)) and app_id:
        print(f"{team}\t{app_id}")
PY
  done < <(find "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
    "$HOME/Library/MobileDevice/Provisioning Profiles" -type f -name '*.mobileprovision' -print 2>/dev/null)
  local viable
  viable="$(python3 - "$account_teams" "$profile_facts" <<'PY'
import sys
accounts = {line.strip() for line in open(sys.argv[1], encoding="utf-8") if line.strip()}
coverage = {team: {"app": False, "ui": False} for team in accounts}
for line in open(sys.argv[2], encoding="utf-8"):
    team, app_id = line.rstrip("\n").split("\t", 1)
    if team not in coverage:
        continue
    wildcard = app_id == f"{team}.*"
    coverage[team]["app"] |= wildcard or app_id == f"{team}.com.sigra.example.nativeproof"
    coverage[team]["ui"] |= wildcard or app_id == f"{team}.com.sigra.example.nativeproof.uitests.xctrunner"
for team in sorted(team for team, flags in coverage.items() if all(flags.values())):
    print(team)
PY
)"
  if [[ -n "${SIGRA_IOS_DEVELOPMENT_TEAM:-}" ]]; then
    DEVELOPMENT_TEAM="$SIGRA_IOS_DEVELOPMENT_TEAM"
    grep -Fxq "$DEVELOPMENT_TEAM" <<<"$viable" || fail "$RULE_INPUT"
  else
    [[ "$(wc -l <<<"$viable" | tr -d ' ')" == 1 && -n "$viable" ]] || fail "$RULE_INPUT"
    DEVELOPMENT_TEAM="$viable"
  fi
  [[ "$DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]] || fail "$RULE_INPUT"
}

discover_lan_url() {
  local interface address port
  interface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  [[ -n "$interface" ]] || fail "$RULE_HOST"
  address="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
  [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fail "$RULE_HOST"
  port="${SIGRA_NATIVE_PROOF_PORT:-4104}"
  [[ "$port" =~ ^[0-9]{4,5}$ ]] || fail "$RULE_HOST"
  ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 || fail "$RULE_HOST"
  PROOF_BASE_URL="http://$address:$port"
  PROOF_FAILURE_URL="http://$address:$((port + 1))"
  ! lsof -nP -iTCP:"$((port + 1))" -sTCP:LISTEN >/dev/null 2>&1 || fail "$RULE_HOST"
}

prepare_host() {
  local port="${SIGRA_NATIVE_PROOF_PORT:-4104}"
  PROOF_EMAIL="native-$(openssl rand -hex 12)@example.invalid"
  PROOF_PASSWORD="$(openssl rand -base64 30 | tr -d '\n/=+' | cut -c1-24)Aa1!"
  chmod 700 "$RUN_ROOT"
  (
    cd "$ROOT_DIR/test/example"
    run_host_setup_step locked-deps "$RUN_ROOT/deps.log" \
      env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      mix deps.get --check-locked
    run_host_setup_step compile "$RUN_ROOT/compile.log" \
      env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      mix compile --force
    run_host_setup_step create-db "$RUN_ROOT/create-db.log" \
      env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      mix ecto.create --quiet
    run_host_setup_step migrate "$RUN_ROOT/migrate.log" \
      env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      mix ecto.migrate --quiet
    run_host_setup_step seed "$RUN_ROOT/seed.log" \
      env SIGRA_NATIVE_PROOF_EMAIL="$PROOF_EMAIL" SIGRA_NATIVE_PROOF_PASSWORD="$PROOF_PASSWORD" \
      MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      mix run --no-compile --no-deps-check -e '
        {:ok, _} = Example.Accounts.register_user(%{
          email: System.fetch_env!("SIGRA_NATIVE_PROOF_EMAIL"),
          password: System.fetch_env!("SIGRA_NATIVE_PROOF_PASSWORD")
        })
      '
  ) || fail "$RULE_HOST"
  ACCOUNT_CREATED=1
  (
    cd "$ROOT_DIR/test/example"
    SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$port" PORT="$port" \
      MIX_ENV=test mix phx.server >"$RUN_ROOT/host.log" 2>&1
  ) &
  HOST_PID=$!
  curl --fail --silent --show-error --retry 40 --retry-delay 1 --retry-connrefused \
    "http://127.0.0.1:$port/users/log_in" >/dev/null || {
      redacted_host_runtime_diagnostics "$RUN_ROOT/host.log"
      fail "$RULE_HOST-readiness"
    }
  kill -0 "$HOST_PID" 2>/dev/null || {
    redacted_host_runtime_diagnostics "$RUN_ROOT/host.log"
    fail "$RULE_HOST-process"
  }
}

build_and_test() {
  DERIVED_DATA="$RUN_ROOT/DerivedData"
  RESULT_BUNDLE="$RUN_ROOT/Result.xcresult"
  export SIGRA_IOS_TEST_DERIVED_DATA="$DERIVED_DATA"
  export SIGRA_IOS_TEST_RESULT_BUNDLE="$RESULT_BUNDLE"
  local build_log="$RUN_ROOT/build.log" test_log="$RUN_ROOT/test.log"
  if ! run_bounded 1200 xcodebuild -quiet -project "$PROJECT" -scheme "$SCHEME" -configuration Proof \
    -destination "id=$DEVICE_UDID" -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO \
    -only-testing:"$UI_TARGET/NativeProofUITests/testLivePhysicalIphoneHostJourney" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build-for-testing \
    >"$build_log" 2>&1; then
    redacted_xcode_diagnostics "$build_log"
    fail "$RULE_BUILD"
  fi

  xctestruns=()
  while IFS= read -r candidate; do xctestruns+=("$candidate"); done < <(
    find "$DERIVED_DATA/Build/Products" -maxdepth 1 -type f -name '*.xctestrun' -print
  )
  [[ "${#xctestruns[@]}" == 1 ]] || fail "$RULE_BUILD"
  XCTESTRUN="${xctestruns[0]}"
  python3 "$ROOT_DIR/scripts/ci/lib/xctestrun-env.py" "$XCTESTRUN" "$UI_TARGET.xctest" \
    SIGRA_NATIVE_PROOF_BASE_URL "$PROOF_BASE_URL" \
    SIGRA_NATIVE_PROOF_FAILURE_URL "$PROOF_FAILURE_URL" \
    SIGRA_NATIVE_PROOF_EMAIL "$PROOF_EMAIL" \
    SIGRA_NATIVE_PROOF_PASSWORD "$PROOF_PASSWORD" || fail "$RULE_BUILD"

  if ! run_bounded 1200 xcodebuild -quiet test-without-building -xctestrun "$XCTESTRUN" \
    -destination "id=$DEVICE_UDID" -resultBundlePath "$RESULT_BUNDLE" -parallel-testing-enabled NO \
    -only-testing:"$UI_TARGET/NativeProofUITests/testLivePhysicalIphoneHostJourney" \
    >"$test_log" 2>&1; then
    redacted_xcode_diagnostics "$test_log"
    fail "$RULE_TEST"
  fi
}

extract_report() {
  local attachment_root="$RUN_ROOT/Attachments"
  xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$attachment_root" \
    >/dev/null 2>&1 || fail "$RULE_REPORT"
  reports=()
  while IFS= read -r candidate; do reports+=("$candidate"); done < <(
    find "$attachment_root" -type f -name '*sigra-native-proof-live-report.json*' -print
  )
  if [[ "${#reports[@]}" != 1 ]]; then
    reports=()
    while IFS= read -r candidate; do reports+=("$candidate"); done < <(
      python3 - "$attachment_root" <<'PY'
import json, pathlib, sys
for path in pathlib.Path(sys.argv[1]).rglob("*"):
    if not path.is_file(): continue
    try:
        data=json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        continue
    if data.get("evidence_class")=="live_physical_iphone": print(path)
PY
    )
  fi
  [[ "${#reports[@]}" == 1 ]] || fail "$RULE_REPORT"
  REPORT_PATH="${reports[0]}"
  python3 - "$REPORT_PATH" <<'PY' || exit 2
import json, sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
expected={"schema_version","evidence_class","browser","callback","storage","scenarios","transport","terminal_status"}
if set(d)!=expected or d["schema_version"]!=1 or d["evidence_class"]!="live_physical_iphone" or d["terminal_status"]!="complete": raise SystemExit(2)
if d["browser"]!={"component":"as_web_authentication_session","mode":"system_external_user_agent"}: raise SystemExit(2)
if d["callback"]!={"transport":"custom_scheme","link_verification":"registered_scheme","callback_binding":"matched"}: raise SystemExit(2)
scenarios={"hosted_return","image_verified","audio_verified","strict_lease_edge","offline_use","kill_relaunch","account_switch","server_revocation","replay_accepted","replay_rejected","replay_conflict"}
if set(d["scenarios"])!=scenarios or not all(v is True for v in d["scenarios"].values()): raise SystemExit(2)
s=d["storage"]
if set(s)!={"present","rotated","recovered_after_relaunch","deleted_after_logout","deleted_after_revocation","read_result","access_persisted"}: raise SystemExit(2)
if not all(s[k] is True for k in ["present","rotated","recovered_after_relaunch","deleted_after_logout","deleted_after_revocation"]): raise SystemExit(2)
if s["read_result"]!="not_found" or s["access_persisted"] is not False: raise SystemExit(2)
if d["transport"]!={"claim":"controlled_transport_failure"}: raise SystemExit(2)
PY
}

find_artifacts() {
  apps=()
  tests=()
  while IFS= read -r candidate; do apps+=("$candidate"); done < <(
    find "$DERIVED_DATA/Build/Products" -type d -name 'SigraNativeProof.app' -print
  )
  while IFS= read -r candidate; do tests+=("$candidate"); done < <(
    find "$DERIVED_DATA/Build/Products" -type d -name 'SigraNativeProofUITests.xctest' -print
  )
  [[ "${#apps[@]}" == 1 && "${#tests[@]}" == 1 ]] || fail "$RULE_REPORT"
  APP_SHA="$(sha256_tree "${apps[0]}")"
  TEST_SHA="$(sha256_tree "${tests[0]}")"
  DIAGNOSTICS_SHA="$(sha256_file "$REPORT_PATH")"
}

finish_private_cleanup() {
  local approved_report="$RUN_ROOT/approved-live-report.json"
  cp "$REPORT_PATH" "$approved_report"
  chmod 600 "$approved_report"
  REPORT_PATH="$approved_report"

  rm -rf "$DERIVED_DATA" "$RESULT_BUNDLE" "$RUN_ROOT/Attachments" "$RUN_ROOT/decoded-profiles"
  rm -f "$RUN_ROOT/build.log" "$RUN_ROOT/test.log" "$RUN_ROOT/devices.json" \
    "$RUN_ROOT/selected-target.json" "$RUN_ROOT/xctrace.txt" "$RUN_ROOT/destinations.txt" \
    "$RUN_ROOT/signing.txt" "$RUN_ROOT/xcode-accounts.plist" "$RUN_ROOT/account-teams.txt" \
    "$RUN_ROOT/profile-facts.tsv" "$RUN_ROOT/deps.log" "$RUN_ROOT/compile.log" "$RUN_ROOT/create-db.log" \
    "$RUN_ROOT/migrate.log" "$RUN_ROOT/seed.log" "$RUN_ROOT/host.log"

  if [[ -n "$HOST_PID" ]]; then
    kill "$HOST_PID" 2>/dev/null || true
    wait "$HOST_PID" 2>/dev/null || true
    HOST_PID=""
  fi
  if [[ "$ACCOUNT_CREATED" == 1 ]]; then
    (
      cd "$ROOT_DIR/test/example"
      SIGRA_NATIVE_PROOF_EMAIL="$PROOF_EMAIL" MIX_ENV=test mix run --no-compile --no-deps-check -e '
        alias Example.{Accounts, Repo}
        user = Accounts.get_user_by_email(System.fetch_env!("SIGRA_NATIVE_PROOF_EMAIL"))
        if user, do: Repo.delete!(user)
      ' >/dev/null 2>&1
    ) || fail "$RULE_CLEANUP"
    ACCOUNT_CREATED=0
  fi
}

uninstall_and_scan() {
  if [[ "$TEST_MODE" != 1 ]]; then
    xcrun devicectl device uninstall app --device "$DEVICE_UDID" com.sigra.example.nativeproof \
      >/dev/null 2>&1 || fail "$RULE_CLEANUP"
  fi
  [[ "$REPORT_PATH" != "$EVIDENCE_PATH" ]] || fail "$RULE_REPORT"
  ! grep -aEqi '(access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer[[:space:]])' "$REPORT_PATH" || fail "$RULE_SCAN"
  if [[ -n "$PROOF_EMAIL" ]] && grep -aFq "$PROOF_EMAIL" "$REPORT_PATH"; then fail "$RULE_SCAN"; fi
  if [[ -n "$PROOF_PASSWORD" ]] && grep -aFq "$PROOF_PASSWORD" "$REPORT_PATH"; then fail "$RULE_SCAN"; fi
}

write_receipt_last() {
  local xcode_version xcode_build implementation_sha receipt_input="$RUN_ROOT/receipt-input.json"
  xcode_version="$(xcodebuild -version | sed -n '1s/^Xcode //p')"
  xcode_build="$(xcodebuild -version | sed -n '2s/^Build version //p')"
  if [[ "$TEST_MODE" == 1 ]]; then
    implementation_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  else
    # shellcheck disable=SC1091
    source "$ROOT_DIR/scripts/ci/lib/exact-sha-worktree.sh"
    implementation_sha="$(bind_clean_worktree_sha "$ROOT_DIR" "$EVIDENCE_RELATIVE_PATH")" || fail "$RULE_REPORT"
    assert_same_clean_worktree_sha "$ROOT_DIR" "$EVIDENCE_RELATIVE_PATH" "$implementation_sha" || fail "$RULE_REPORT"
  fi
  python3 - "$REPORT_PATH" "$receipt_input" "$implementation_sha" "$MODEL_CLASS" "$OS_VERSION" \
    "$xcode_version" "$xcode_build" "$APP_SHA" "$TEST_SHA" "$DIAGNOSTICS_SHA" <<'PY'
import json, sys
report_path,out,sha,model,os_version,xcode,xcode_build,app_sha,test_sha,diag_sha=sys.argv[1:]
r=json.load(open(report_path,encoding="utf-8"))
receipt={
 "schema_version":"native-proof-receipt/1","implementation_sha":sha,"target_class":"physical_iphone",
 "target_identity":{"platform":"ios","model_class":model,"os_version":os_version,"physical":True},
 "toolchain":{"xcode_version":xcode,"xcode_build":xcode_build},
 "browser":{"component":r["browser"]["component"],"version":"ios-"+os_version,"mode":r["browser"]["mode"]},
 "callback":r["callback"],"storage":r["storage"],"scenarios":r["scenarios"],"transport":r["transport"],
 "artifact_hashes":{"app_bundle_sha256":app_sha,"xctest_bundle_sha256":test_sha,"diagnostics_sha256":diag_sha},
 "cleanup_status":"complete","secret_scan_status":"clean","terminal_status":"complete"
}
open(out,"w",encoding="utf-8").write(json.dumps(receipt,sort_keys=True,separators=(",",":"))+"\n")
PY
  RECEIPT_INPUT="$receipt_input" EVIDENCE_PATH="$EVIDENCE_PATH" IMPLEMENTATION_SHA="$implementation_sha" \
    node --input-type=module -e '
      import {readFile} from "node:fs/promises";
      import {writeNativeReceiptLast} from "./scripts/ci/lib/native-proof-receipt.mjs";
      const receipt=JSON.parse(await readFile(process.env.RECEIPT_INPUT,"utf8"));
      await writeNativeReceiptLast(process.env.EVIDENCE_PATH,receipt,process.env.IMPLEMENTATION_SHA);
    '
  node "$ROOT_DIR/scripts/ci/lib/native-proof-receipt.mjs" --validate "$EVIDENCE_PATH" --target physical_iphone
  ! grep -aEqi '(access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer[[:space:]])' "$EVIDENCE_PATH" || fail "$RULE_SCAN"
  event receipt_written
}

main() {
  umask 077
  cd "$ROOT_DIR"
  RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-ios-physical.XXXXXX")"
  chmod 700 "$RUN_ROOT"
  if [[ "$TEST_MODE" == 1 ]]; then
    PROOF_BASE_URL="http://127.0.0.1:4104"
    PROOF_FAILURE_URL="http://127.0.0.1:4105"
    PROOF_EMAIL="ephemeral@example.invalid"
    PROOF_PASSWORD="ephemeral-not-retained"
  else
    discover_lan_url
  fi
  discover_target
  discover_team
  event target_validated
  if [[ "$TEST_MODE" != 1 ]]; then prepare_host; fi
  build_and_test
  event tests_complete
  extract_report
  find_artifacts
  finish_private_cleanup
  uninstall_and_scan
  event cleanup_complete
  write_receipt_last
  printf 'crosswake native iOS proof: PASS\n'
}

main "$@"
