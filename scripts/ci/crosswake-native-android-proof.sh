#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_PROJECT="$ROOT_DIR/test/example/native/android"
LOCK="$ANDROID_PROJECT/toolchain.lock.json"
EVIDENCE_RELATIVE_PATH=".planning/phases/248-crosswake-native-proof/248-ANDROID-EVIDENCE.json"
EVIDENCE_PATH="${SIGRA_ANDROID_EVIDENCE_PATH:-$ROOT_DIR/$EVIDENCE_RELATIVE_PATH}"
SERIAL="${SIGRA_ANDROID_SERIAL:-emulator-5556}"
AVD_NAME="sigra_phase248_android"
PORT="${SIGRA_NATIVE_PROOF_PORT:-4102}"
RUN_ROOT=""
HOST_PID=""
EMULATOR_PID=""
CGROUP_PATH=""
FIREWALL_ACTIVE=0
ACCOUNTS_CREATED=0
PRIMARY_EMAIL=""
PRIMARY_PASSWORD=""
SECONDARY_EMAIL=""
SECONDARY_PASSWORD=""

fail() { printf 'crosswake native Android proof: %s\n' "$*" >&2; exit 2; }
sha256_file() { sha256sum "$1" | awk '{print $1}'; }

redacted_host_diagnostics() {
  [[ -n "$RUN_ROOT" && -f "$RUN_ROOT/host.log" ]] || return 0
  python3 - "$RUN_ROOT/host.log" "$PRIMARY_EMAIL" "$PRIMARY_PASSWORD" "$SECONDARY_EMAIL" "$SECONDARY_PASSWORD" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace")
for private in sys.argv[2:]:
    if private: text=text.replace(private,"[REDACTED]")
allowed=re.compile(r'\[(?:warning|error)\]|\*\* \(|could not|failed|exception|address already|running exampleweb',re.I)
secret=re.compile(r'access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer\s+\S+',re.I)
print("\n".join(secret.sub("[REDACTED]",line) for line in text.splitlines() if allowed.search(line))[-12000:],file=sys.stderr)
PY
}

validate_facts() {
  python3 - "$1" "$2" <<'PY'
import json, pathlib, re, sys
facts=json.loads(pathlib.Path(sys.argv[1]).read_text())
lock=json.loads(pathlib.Path(sys.argv[2]).read_text())
top={"schema_version","toolchain","target","browser","callback","storage","scenarios","transport","process","network","cleanup_status","secret_scan_status","terminal_status"}
if set(facts)!=top or facts.get("schema_version")!=1: raise SystemExit("invalid facts allowlist")
tool=("jdk","cmdline_tools","platform_tools","emulator","sdk_platform","build_tools","system_image","system_image_revision","gradle","agp","kotlin","androidx_browser","test_core","test_runner","espresso","uiautomator")
if set(facts["toolchain"])!=set(tool) or any(facts["toolchain"][k]!=lock[k] for k in tool): raise SystemExit("toolchain mismatch")
target={"platform":"android","avd_device":lock["avd_device"],"api":"36","abi":lock["abi"],"emulated":True}
if facts["target"]!=target: raise SystemExit("target mismatch or retained identity")
browser={"component":lock["browser_package"],"version":lock["browser_version"],"apk_sha256":lock["browser_apk_sha256"],"mode":lock["browser_mode"]}
if facts["browser"]!=browser: raise SystemExit("browser mismatch")
if facts["callback"]!={"transport":"custom_scheme","link_verification":"registered_scheme","callback_binding":"matched"}: raise SystemExit("callback mismatch")
storage={"present","rotated","recovered_after_relaunch","deleted_after_logout","deleted_after_revocation","read_result","access_persisted"}
if set(facts["storage"])!=storage: raise SystemExit("storage allowlist mismatch")
if not all(facts["storage"][k] is True for k in storage-{"read_result","access_persisted"}): raise SystemExit("storage posture incomplete")
if facts["storage"]["read_result"] not in {"not_found","decrypt_failed","key_unavailable"} or facts["storage"]["access_persisted"] is not False: raise SystemExit("storage boundary invalid")
scenarios={"hosted_return","image_verified","audio_verified","strict_lease_edge","offline_use","kill_relaunch","account_switch","server_revocation","replay_accepted","replay_rejected","replay_conflict"}
if set(facts["scenarios"])!=scenarios or not all(v is True for v in facts["scenarios"].values()): raise SystemExit("scenario matrix incomplete")
transport={"wifi_disabled","cellular_disabled","emulator_network_disabled","force_stop","cold_start"}
if set(facts["transport"])!=transport or not all(v is True for v in facts["transport"].values()): raise SystemExit("transport matrix incomplete")
process=facts["process"]
if set(process)!={"before_pid","after_pid","force_stop_observed"} or not isinstance(process["before_pid"],int) or not isinstance(process["after_pid"],int) or process["before_pid"]==process["after_pid"] or process["force_stop_observed"] is not True: raise SystemExit("real process death not proven")
network=facts["network"]
if set(network)!={"cgroup_firewall","proof_host_unreachable","external_sentinel_unreachable","adb_available"} or not all(v is True for v in network.values()): raise SystemExit("full emulator transport-off not proven")
if any(facts[k]!="complete" for k in ("cleanup_status","terminal_status")) or facts["secret_scan_status"]!="clean": raise SystemExit("terminal gates incomplete")
raw=pathlib.Path(sys.argv[1]).read_text()
if re.search(r'access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer\s|(?:user|account|device)[_-]?\d{3,}',raw,re.I): raise SystemExit("secret or stable identity retained")
PY
}

seal_facts() {
  local facts="$1" lock="$2" output="$3" implementation_sha="$4" app_apk="$5" test_apk="$6" diagnostics="$7"
  [[ "${SIGRA_ANDROID_PROOF_FAIL_BEFORE_SEAL:-0}" != 1 ]] || fail "injected terminal failure"
  validate_facts "$facts" "$lock"
  [[ "$implementation_sha" =~ ^[a-f0-9]{40}$ ]] || fail "implementation SHA is not exact"
  local receipt_input="$RUN_ROOT/receipt-input.json"
  python3 - "$facts" "$receipt_input" "$implementation_sha" "$app_apk" "$test_apk" "$diagnostics" <<'PY'
import hashlib,json,pathlib,sys
facts,out,sha,app,test,diag=sys.argv[1:]
d=json.loads(pathlib.Path(facts).read_text())
digest=lambda p: hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
r={"schema_version":"native-proof-receipt/1","implementation_sha":sha,"target_class":"android_emulator","target_identity":d["target"],"toolchain":{k:str(v) for k,v in d["toolchain"].items()},"browser":d["browser"],"callback":d["callback"],"storage":d["storage"],"scenarios":d["scenarios"],"transport":d["transport"],"artifact_hashes":{"app_apk_sha256":digest(app),"test_apk_sha256":digest(test),"diagnostics_sha256":digest(diag)},"cleanup_status":d["cleanup_status"],"secret_scan_status":d["secret_scan_status"],"terminal_status":d["terminal_status"]}
pathlib.Path(out).write_text(json.dumps(r,sort_keys=True,separators=(",",":"))+"\n")
PY
  RECEIPT_INPUT="$receipt_input" EVIDENCE_PATH="$output" IMPLEMENTATION_SHA="$implementation_sha" node --input-type=module -e '
    import {readFile} from "node:fs/promises";
    import {writeNativeReceiptLast} from "./scripts/ci/lib/native-proof-receipt.mjs";
    const receipt=JSON.parse(await readFile(process.env.RECEIPT_INPUT,"utf8"));
    await writeNativeReceiptLast(process.env.EVIDENCE_PATH,receipt,process.env.IMPLEMENTATION_SHA);
  '
}

adb_cmd() { adb -s "$SERIAL" "$@"; }

remove_firewall() {
  if [[ "$FIREWALL_ACTIVE" == 1 ]]; then
    sudo iptables -D OUTPUT -m cgroup --path "${CGROUP_PATH#/sys/fs/cgroup/}" -j REJECT >/dev/null 2>&1 || true
    FIREWALL_ACTIVE=0
  fi
}

cleanup() {
  local ok=0
  remove_firewall
  if [[ -n "$HOST_PID" ]]; then kill "$HOST_PID" >/dev/null 2>&1 || true; wait "$HOST_PID" 2>/dev/null || true; HOST_PID=""; fi
  if [[ -n "$EMULATOR_PID" ]]; then adb_cmd emu kill >/dev/null 2>&1 || true; wait "$EMULATOR_PID" 2>/dev/null || true; EMULATOR_PID=""; fi
  adb -s "$SERIAL" emu kill >/dev/null 2>&1 || true
  avdmanager delete avd -n "$AVD_NAME" >/dev/null 2>&1 || true
  if [[ -n "$CGROUP_PATH" && -d "$CGROUP_PATH" ]]; then sudo rmdir "$CGROUP_PATH" >/dev/null 2>&1 || ok=1; fi
  if [[ "$ACCOUNTS_CREATED" == 1 ]]; then
    (cd "$ROOT_DIR/test/example" && SIGRA_PROOF_EMAIL_1="$PRIMARY_EMAIL" SIGRA_PROOF_EMAIL_2="$SECONDARY_EMAIL" MIX_ENV=test mix run --no-compile --no-deps-check -e '
      alias Example.{Accounts,Repo}; for email <- [System.fetch_env!("SIGRA_PROOF_EMAIL_1"),System.fetch_env!("SIGRA_PROOF_EMAIL_2")], user=Accounts.get_user_by_email(email), user != nil, do: Repo.delete!(user)
    ' >/dev/null 2>&1) || ok=1
    ACCOUNTS_CREATED=0
  fi
  [[ -z "$RUN_ROOT" || ! -d "$RUN_ROOT" ]] || rm -rf "$RUN_ROOT" || ok=1
  return "$ok"
}

bounded_wait_boot() {
  timeout 180 adb -s "$SERIAL" wait-for-device >/dev/null || fail "emulator did not attach"
  local deadline=$((SECONDS + 240)) stable=0 value paths
  while (( SECONDS < deadline )); do
    value="$(adb_cmd shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    paths="$(adb_cmd shell pm path com.android.chrome 2>/dev/null | sed -n 's/^package://p')"
    if [[ "$value" == 1 && -n "$paths" ]]; then stable=$((stable+1)); else stable=0; fi
    [[ "$stable" -ge 3 ]] && return 0
    read -r -t 2 _ </dev/null || true
  done
  fail "bounded emulator/browser readiness expired"
}

capture_browser_manifest() {
  local manifest="$RUN_ROOT/chrome-apks.manifest" index=0 remote base local_apk
  : >"$manifest"
  while IFS= read -r remote; do
    [[ -n "$remote" ]] || continue
    base="${remote##*/}"; [[ "$base" =~ ^[A-Za-z0-9._-]+\.apk$ ]] || fail "invalid Chrome split name"
    local_apk="$RUN_ROOT/chrome-$index.apk"
    adb_cmd pull "$remote" "$local_apk" >/dev/null
    [[ -s "$local_apk" && "$(head -c2 "$local_apk")" == PK ]] || fail "incomplete Chrome APK pull"
    printf '%s\t%s\n' "$base" "$(sha256_file "$local_apk")" >>"$manifest"
    index=$((index+1))
  done < <(adb_cmd shell pm path com.android.chrome | sed -n 's/^package://p' | tr -d '\r' | LC_ALL=C sort)
  [[ "$index" -gt 0 ]] || fail "Chrome APK set missing"
  BROWSER_SHA="$(sha256_file "$manifest")"
  BROWSER_VERSION="$(adb_cmd shell dumpsys package com.android.chrome | sed -n 's/^[[:space:]]*versionName=//p' | head -1 | tr -d '\r')"
  python3 - "$LOCK" "$BROWSER_VERSION" "$BROWSER_SHA" <<'PY'
import json,sys
l=json.load(open(sys.argv[1]));
if sys.argv[2]!=l["browser_version"] or sys.argv[3]!=l["browser_apk_sha256"] or l["browser_mode"]!="custom_tab_fallback": raise SystemExit("locked Chrome manifest mismatch")
PY
  rm -f "$RUN_ROOT"/chrome-*.apk
}

prepare_host() {
  PRIMARY_EMAIL="native-a-$(openssl rand -hex 10)@example.invalid"
  SECONDARY_EMAIL="native-b-$(openssl rand -hex 10)@example.invalid"
  PRIMARY_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)Aa1!"
  SECONDARY_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)Bb2!"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then printf '::add-mask::%s\n' "$PRIMARY_EMAIL" "$SECONDARY_EMAIL" "$PRIMARY_PASSWORD" "$SECONDARY_PASSWORD"; fi
  (
    cd "$ROOT_DIR/test/example"
    env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" \
      mix deps.get --check-locked >"$RUN_ROOT/deps.log" 2>&1
    env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" \
      mix compile --force >"$RUN_ROOT/compile.log" 2>&1
    env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" \
      mix ecto.create --quiet >"$RUN_ROOT/db.log" 2>&1
    env MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" \
      mix ecto.migrate --quiet >>"$RUN_ROOT/db.log" 2>&1
    SIGRA_PROOF_EMAIL_1="$PRIMARY_EMAIL" SIGRA_PROOF_EMAIL_2="$SECONDARY_EMAIL" SIGRA_PROOF_PASSWORD_1="$PRIMARY_PASSWORD" SIGRA_PROOF_PASSWORD_2="$SECONDARY_PASSWORD" \
      MIX_ENV=test SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" mix run --no-compile --no-deps-check -e '
      alias Example.{Accounts,Repo}; alias Ecto.Changeset
      for {email,password} <- [{System.fetch_env!("SIGRA_PROOF_EMAIL_1"),System.fetch_env!("SIGRA_PROOF_PASSWORD_1")},{System.fetch_env!("SIGRA_PROOF_EMAIL_2"),System.fetch_env!("SIGRA_PROOF_PASSWORD_2")}] do
        {:ok,user}=Accounts.register_user(%{email: email,password: password})
        Repo.update!(Changeset.change(user,confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)))
      end
    ' >"$RUN_ROOT/seed.log" 2>&1
  ) || fail "proof host setup failed"
  ACCOUNTS_CREATED=1
  (cd "$ROOT_DIR/test/example" && SIGRA_NATIVE_PROOF_HOST=1 SIGRA_NATIVE_PROOF_PORT="$PORT" PORT="$PORT" MIX_ENV=test mix phx.server >"$RUN_ROOT/host.log" 2>&1) &
  HOST_PID=$!
  local deadline=$((SECONDS+90))
  while (( SECONDS < deadline )); do
    if ! kill -0 "$HOST_PID" >/dev/null 2>&1; then redacted_host_diagnostics; fail "proof host exited before readiness"; fi
    if curl --fail --silent --connect-timeout 2 "http://127.0.0.1:$PORT/users/log_in" >/dev/null; then return 0; fi
    read -r -t 1 _ </dev/null || true
  done
  redacted_host_diagnostics
  fail "proof host readiness failed"
}

run_instrumentation() {
  local method="$1" output="$RUN_ROOT/instrumentation-$method.txt"
  adb_cmd shell am instrument -w -r -e class "dev.sigra.proof.LiveNativeProofInstrumentedTest#$method" dev.sigra.proof.test/androidx.test.runner.AndroidJUnitRunner >"$output" 2>&1 || {
    sed -E 's/(password|token|Bearer)[^[:space:]]*/[REDACTED]/Ig' "$output" | tail -80 >&2
    fail "instrumentation phase failed: $method"
  }
  grep -Eq '^OK \([1-9][0-9]* test' "$output" || fail "instrumentation result missing: $method"
}

install_private_credentials() {
  local json="$RUN_ROOT/credentials.json"
  python3 - "$json" "$PRIMARY_EMAIL" "$PRIMARY_PASSWORD" "$SECONDARY_EMAIL" "$SECONDARY_PASSWORD" <<'PY'
import json,pathlib,sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"primary":{"email":sys.argv[2],"password":sys.argv[3]},"secondary":{"email":sys.argv[4],"password":sys.argv[5]}}))
PY
  chmod 600 "$json"
  adb_cmd shell run-as dev.sigra.proof sh -c 'umask 077; cat > files/proof-credentials.json' <"$json"
  rm -f "$json"
}

apply_emulator_firewall() {
  [[ -f /sys/fs/cgroup/cgroup.controllers ]] || fail "cgroup v2 unavailable"
  CGROUP_PATH="/sys/fs/cgroup/sigra-phase248-${GITHUB_RUN_ID:-local}-$$"
  sudo mkdir "$CGROUP_PATH"
  printf '%s\n' "$EMULATOR_PID" | sudo tee "$CGROUP_PATH/cgroup.procs" >/dev/null
  sudo iptables -I OUTPUT -m cgroup --path "${CGROUP_PATH#/sys/fs/cgroup/}" -j REJECT
  FIREWALL_ACTIVE=1
  adb_cmd shell svc wifi disable
  adb_cmd shell svc data disable
  adb_cmd shell settings get global wifi_on | grep -Fxq 0 || fail "Wi-Fi remained enabled"
  if adb_cmd shell toybox nc -w 3 10.0.2.2 "$PORT" </dev/null >/dev/null 2>&1; then fail "proof host remained reachable"; fi
  if adb_cmd shell toybox nc -w 3 1.1.1.1 443 </dev/null >/dev/null 2>&1; then fail "external sentinel remained reachable"; fi
  adb_cmd shell getprop ro.build.version.sdk | grep -Fxq 36 || fail "ADB orchestration unavailable offline"
}

main_live() {
  umask 077
  cd "$ROOT_DIR"
  [[ -n "${ANDROID_SDK_ROOT:-}" && -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]] || fail "ANDROID_SDK_ROOT does not contain the locked platform tools"
  local cmdline_bin cmdline_version source_revision
  cmdline_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["cmdline_tools"])' "$LOCK")"
  [[ "$cmdline_version" =~ ^[0-9]+\.[0-9]+$ ]] || fail "locked command-line tools version is invalid"
  cmdline_bin="$ANDROID_SDK_ROOT/cmdline-tools/$cmdline_version/bin"
  [[ -x "$cmdline_bin/avdmanager" && -x "$cmdline_bin/sdkmanager" ]] || fail "locked command-line tools bin is missing"
  source_revision="$(sed -n 's/^Pkg\.Revision[[:space:]]*=[[:space:]]*//p' "$ANDROID_SDK_ROOT/cmdline-tools/$cmdline_version/source.properties" 2>/dev/null)"
  [[ "$source_revision" == "$cmdline_version" ]] || fail "command-line tools package provenance mismatch"
  export PATH="$cmdline_bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
  bash scripts/ci/native-proof-provision.sh --validate-android-lock
  RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-android-live.XXXXXX")"; chmod 700 "$RUN_ROOT"
  trap 'cleanup || true' EXIT HUP INT TERM
  # shellcheck disable=SC1091
  source "$ROOT_DIR/scripts/ci/lib/exact-sha-worktree.sh"
  IMPLEMENTATION_SHA="$(bind_clean_worktree_sha "$ROOT_DIR" "$EVIDENCE_RELATIVE_PATH")" || fail "worktree is not exact-source clean"
  prepare_host
  avdmanager delete avd -n "$AVD_NAME" >/dev/null 2>&1 || true
  printf 'no\n' | avdmanager create avd -n "$AVD_NAME" -k "system-images;android-36;google_apis_playstore;x86_64" -d pixel_8 --force >/dev/null
  emulator @"$AVD_NAME" -port 5556 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot -wipe-data >"$RUN_ROOT/emulator.log" 2>&1 &
  EMULATOR_PID=$!
  bounded_wait_boot
  capture_browser_manifest
  (cd "$ANDROID_PROJECT" && ./gradlew --no-daemon --console=plain -PsigraNativeProofHostBaseUrl="http://10.0.2.2:$PORT" assembleDebug assembleDebugAndroidTest)
  APP_APK="$ANDROID_PROJECT/app/build/outputs/apk/debug/app-debug.apk"
  TEST_APK="$ANDROID_PROJECT/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
  adb_cmd install -r "$APP_APK" >/dev/null; adb_cmd install -r "$TEST_APK" >/dev/null
  install_private_credentials
  run_instrumentation hostedOnlinePhase
  BEFORE_PID="$(adb_cmd shell pidof dev.sigra.proof | tr -d '\r' | awk '{print $1}')"; [[ "$BEFORE_PID" =~ ^[0-9]+$ ]] || fail "pre-stop process missing"
  apply_emulator_firewall
  run_instrumentation offlinePhase
  remove_firewall
  adb_cmd shell svc wifi enable; adb_cmd shell svc data enable
  adb_cmd shell am force-stop dev.sigra.proof
  [[ -z "$(adb_cmd shell pidof dev.sigra.proof | tr -d '\r')" ]] || fail "force-stop did not terminate process"
  adb_cmd shell monkey -p dev.sigra.proof -c android.intent.category.LAUNCHER 1 >/dev/null
  local deadline=$((SECONDS+30)); AFTER_PID=""
  while (( SECONDS < deadline )); do AFTER_PID="$(adb_cmd shell pidof dev.sigra.proof | tr -d '\r' | awk '{print $1}')"; [[ "$AFTER_PID" =~ ^[0-9]+$ ]] && break; read -r -t 1 _ </dev/null || true; done
  [[ "$AFTER_PID" =~ ^[0-9]+$ && "$AFTER_PID" != "$BEFORE_PID" ]] || fail "cold-start PID evidence invalid"
  run_instrumentation relaunchPhase
  adb_cmd shell pm clear com.android.chrome >/dev/null
  run_instrumentation accountReplayAndRevocationPhase
  REPORT="$RUN_ROOT/report.json"
  adb_cmd shell run-as dev.sigra.proof cat files/proof-live-report.json >"$REPORT"
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$REPORT"
  ! grep -aEqi '(access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer[[:space:]])' "$REPORT" || fail "secret retained in Android report"
  DIAGNOSTICS="$RUN_ROOT/diagnostics.txt"
  printf 'instrumentation_tests=4\nbrowser_manifest_sha256=%s\noffline_boundary=cgroup_v2_iptables\n' "$BROWSER_SHA" >"$DIAGNOSTICS"
  FACTS="$RUN_ROOT/facts.json"
  python3 - "$LOCK" "$REPORT" "$FACTS" "$BEFORE_PID" "$AFTER_PID" <<'PY'
import json,pathlib,sys
lock=json.loads(pathlib.Path(sys.argv[1]).read_text()); r=json.loads(pathlib.Path(sys.argv[2]).read_text())
need=["hosted_return","image_verified","audio_verified","strict_lease_edge","offline_use","kill_relaunch","account_switch","server_revocation","replay_accepted","replay_rejected","replay_conflict"]
facts={"schema_version":1,"toolchain":{k:lock[k] for k in ("jdk","cmdline_tools","platform_tools","emulator","sdk_platform","build_tools","system_image","system_image_revision","gradle","agp","kotlin","androidx_browser","test_core","test_runner","espresso","uiautomator")},"target":{"platform":"android","avd_device":lock["avd_device"],"api":"36","abi":lock["abi"],"emulated":True},"browser":{"component":lock["browser_package"],"version":lock["browser_version"],"apk_sha256":lock["browser_apk_sha256"],"mode":lock["browser_mode"]},"callback":{"transport":"custom_scheme","link_verification":"registered_scheme","callback_binding":"matched"},"storage":{"present":r["storage_present"],"rotated":r["storage_rotated"],"recovered_after_relaunch":r["storage_recovered"],"deleted_after_logout":r["storage_deleted_logout"],"deleted_after_revocation":r["storage_deleted_revocation"],"read_result":r["storage_read_result"],"access_persisted":r["access_persisted"]},"scenarios":{k:r[k] for k in need},"transport":{"wifi_disabled":True,"cellular_disabled":True,"emulator_network_disabled":True,"force_stop":True,"cold_start":True},"process":{"before_pid":int(sys.argv[4]),"after_pid":int(sys.argv[5]),"force_stop_observed":True},"network":{"cgroup_firewall":True,"proof_host_unreachable":True,"external_sentinel_unreachable":True,"adb_available":True},"cleanup_status":"complete","secret_scan_status":"clean","terminal_status":"complete"}
pathlib.Path(sys.argv[3]).write_text(json.dumps(facts,sort_keys=True,separators=(",",":"))+"\n")
PY
  local seal_root
  seal_root="$(mktemp -d "${TMPDIR:-/tmp}/sigra-android-seal.XXXXXX")"; chmod 700 "$seal_root"
  cp "$FACTS" "$seal_root/facts.json"
  cp "$APP_APK" "$seal_root/app.apk"
  cp "$TEST_APK" "$seal_root/test.apk"
  cp "$DIAGNOSTICS" "$seal_root/diagnostics.txt"
  cleanup || fail "private cleanup incomplete"
  RUN_ROOT="$seal_root"
  assert_same_clean_worktree_sha "$ROOT_DIR" "$EVIDENCE_RELATIVE_PATH" "$IMPLEMENTATION_SHA" || fail "source changed during proof"
  seal_facts "$RUN_ROOT/facts.json" "$LOCK" "$EVIDENCE_PATH" "$IMPLEMENTATION_SHA" "$RUN_ROOT/app.apk" "$RUN_ROOT/test.apk" "$RUN_ROOT/diagnostics.txt"
  node "$ROOT_DIR/scripts/ci/lib/native-proof-receipt.mjs" --validate "$EVIDENCE_PATH" --target android_emulator
  ! grep -aEqi '(access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer[[:space:]])' "$EVIDENCE_PATH" || fail "secret retained in receipt"
  printf 'crosswake native Android proof: PASS\n'
}

case "${1:-}" in
  --validate-facts) [[ $# == 3 ]] || fail "usage: --validate-facts FACTS LOCK"; validate_facts "$2" "$3" ;;
  --seal-facts)
    [[ $# == 8 ]] || fail "usage: --seal-facts FACTS LOCK OUTPUT SHA APP TEST DIAGNOSTICS"
    RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-android-seal.XXXXXX")"; trap 'rm -rf "$RUN_ROOT"' EXIT
    seal_facts "$2" "$3" "$4" "$5" "$6" "$7" "$8"
    ;;
  "") main_live ;;
  *) fail "unknown argument" ;;
esac
