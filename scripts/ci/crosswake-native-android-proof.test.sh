#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="${ROOT_DIR}/scripts/ci/crosswake-native-android-proof.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-android-proof-test.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT

fail() {
  printf 'android proof runner test: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local label="$1"
  shift
  if "$@" >"${TMP_ROOT}/${label}.out" 2>"${TMP_ROOT}/${label}.err"; then
    fail "${label} unexpectedly passed"
  fi
}

LOCK="${ROOT_DIR}/test/example/native/android/toolchain.lock.json"
FACTS="${TMP_ROOT}/facts.json"

python3 - "${LOCK}" "${FACTS}" <<'PY'
import json, pathlib, sys
lock = json.loads(pathlib.Path(sys.argv[1]).read_text())
facts = {
    "schema_version": 1,
    "toolchain": {key: lock[key] for key in (
        "jdk", "cmdline_tools", "platform_tools", "emulator", "sdk_platform",
        "build_tools", "system_image", "system_image_revision", "gradle", "agp",
        "kotlin", "androidx_browser", "test_core", "test_runner", "espresso", "uiautomator")},
    "target": {"platform": "android", "avd_device": lock["avd_device"], "api": "36", "abi": lock["abi"], "emulated": True},
    "browser": {"component": lock["browser_package"], "version": lock["browser_version"], "apk_sha256": lock["browser_apk_sha256"], "mode": lock["browser_mode"]},
    "callback": {"transport": "custom_scheme", "link_verification": "registered_scheme", "callback_binding": "matched"},
    "storage": {"present": True, "rotated": True, "recovered_after_relaunch": True, "deleted_after_logout": True, "deleted_after_revocation": True, "read_result": "key_unavailable", "access_persisted": False},
    "scenarios": {key: True for key in ("hosted_return", "image_verified", "audio_verified", "strict_lease_edge", "offline_use", "kill_relaunch", "account_switch", "server_revocation", "replay_accepted", "replay_rejected", "replay_conflict")},
    "transport": {"wifi_disabled": True, "cellular_disabled": True, "emulator_network_disabled": True, "force_stop": True, "cold_start": True},
    "process": {"before_pid": 101, "after_pid": 202, "force_stop_observed": True},
    "network": {"cgroup_firewall": True, "proof_host_unreachable": True, "external_sentinel_unreachable": True, "adb_available": True},
    "cleanup_status": "complete",
    "secret_scan_status": "clean",
    "terminal_status": "complete",
}
pathlib.Path(sys.argv[2]).write_text(json.dumps(facts, sort_keys=True) + "\n")
PY

bash "${RUNNER}" --validate-facts "${FACTS}" "${LOCK}"

mutate_and_reject() {
  local label="$1" mutation="$2"
  local bad="${TMP_ROOT}/${label}.json"
  python3 - "${FACTS}" "${bad}" "${mutation}" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
exec(sys.argv[3], {"data": data})
pathlib.Path(sys.argv[2]).write_text(json.dumps(data) + "\n")
PY
  expect_failure "${label}" bash "${RUNNER}" --validate-facts "${bad}" "${LOCK}"
}

mutate_and_reject version_mismatch 'data["toolchain"]["emulator"] = "mutable"'
mutate_and_reject residual_transport 'data["network"]["proof_host_unreachable"] = False'
mutate_and_reject activity_only_restart 'data["process"]["after_pid"] = data["process"]["before_pid"]'
mutate_and_reject missing_scenario 'del data["scenarios"]["offline_use"]'
mutate_and_reject storage_omission 'del data["storage"]["deleted_after_revocation"]'
mutate_and_reject identity_injection 'data["target"]["device_id"] = "device_12345"'
mutate_and_reject secret_injection 'data["access_token"] = "Bearer retained-secret"'

test ! -e "${TMP_ROOT}/early-receipt.json" || fail "receipt existed before sealing"
expect_failure early_receipt env SIGRA_ANDROID_PROOF_FAIL_BEFORE_SEAL=1 \
  bash "${RUNNER}" --seal-facts "${FACTS}" "${LOCK}" "${TMP_ROOT}/early-receipt.json" \
  0123456789abcdef0123456789abcdef01234567 "${FACTS}" "${FACTS}" "${FACTS}"
test ! -e "${TMP_ROOT}/early-receipt.json" || fail "receipt was written before the terminal gate"

grep -Fq 'adb_cmd shell am force-stop' "${RUNNER}" || fail "runner must own force-stop"
grep -Fq 'cgroup' "${RUNNER}" || fail "runner must use a process-scoped network boundary"
grep -Fq 'proof_host_unreachable' "${RUNNER}" || fail "runner must attest proof-host unreachability"
grep -Fq -- '--prepare-android-runtime' "${ROOT_DIR}/scripts/ci/native-proof-provision.sh" || fail "runtime provisioning must not boot a duplicate browser"
grep -Fq 'export ANDROID_HOME="$ANDROID_SDK_ROOT"' "${RUNNER}" || fail "runner must prevent hosted SDK root drift"
grep -Fq 'export ADB_VENDOR_KEYS="$key_root"' "${RUNNER}" || fail "runner must authorize ADB from a private ephemeral key"
grep -Fq 'unexpected command failure: stage=$CURRENT_STAGE' "${RUNNER}" || fail "runner must retain secret-safe stage diagnostics"
grep -Fq "pm path com.android.chrome 2>/dev/null | sed -n 's/^package://p' || true" "${RUNNER}" || fail "boot readiness probes must tolerate transient package-manager status"
grep -Fq 'run-as dev.sigra.proof mkdir -p files' "${RUNNER}" || fail "credential injection must initialize app-private storage"
grep -Fq 'run-as dev.sigra.proof tee files/proof-credentials.json' "${RUNNER}" || fail "credential injection must not depend on nested shell quoting"
! grep -Eq 'local method=.*output=.*\$method' "${RUNNER}" || fail "instrumentation output must not expand an unbound local"
grep -Fq 'for attempt in 1 2' "${RUNNER}" || fail "device-side APK hashing must retry exactly once"
grep -Fq 'toybox sha256sum "$remote"' "${RUNNER}" || fail "browser identity must hash exact installed APK bytes on-device"
grep -Fq '[[ "$apk_sha" =~ ^[a-f0-9]{64}$ ]]' "${RUNNER}" || fail "browser APK hashes must be exact SHA-256 values"
grep -Fq 'INSTRUMENTATION_STATUS_CODE: 0' "${RUNNER}" || fail "instrumentation must use machine-native success protocol"
grep -Fq 'INSTRUMENTATION_CODE: -1' "${RUNNER}" || fail "instrumentation must require a terminal result"
grep -Fq '<package android:name="com.android.chrome" />' "${ROOT_DIR}/test/example/native/android/app/src/main/AndroidManifest.xml" || fail "locked Chrome must be visible to PackageManager"
grep -Fq 'waitForHostedLoginFields()' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "hosted login must use bounded onboarding automation"
grep -Fq 'hostedField("user_email", "Email")' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "hosted login must use the stable email hook"
grep -Fq 'hostedField("user_password", "Password")' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "hosted login must use the stable password hook"
grep -Fq 'setCompressedLayoutHierarchy(false)' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "hosted login must retain the Chrome HTML accessibility subtree"
grep -Fq 'ProofAccessibilityService' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/AndroidManifest.xml" || fail "the test APK must activate Chrome renderer accessibility"
grep -Fq 'enabled_accessibility_services' "${RUNNER}" || fail "the runner must enable and clean the test-only accessibility service"
grep -Fq 'clickResource("login_submit")' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "hosted login must use the stable submit hook"
grep -Fq 'id="login_submit"' "${ROOT_DIR}/test/example/lib/example_web/controllers/session_html.ex" || fail "host login must expose the stable submit hook"
grep -Fq 'id="app-login-approve"' "${ROOT_DIR}/test/example/lib/example_web/controllers/app_login_html/approve.html.heex" || fail "host approval must expose the stable browser hook"
grep -Fq 'Use without an account|Accept & continue|No thanks' "${ROOT_DIR}/test/example/native/android/app/src/androidTest/java/dev/sigra/proof/LiveNativeProofInstrumentedTest.kt" || fail "Chrome onboarding actions must be exact and bounded"
grep -Fq 'endpoint_ip = {127, 0, 0, 1}' "${ROOT_DIR}/test/example/config/test.exs" || fail "proof-only test endpoint must remain loopback-confined"
grep -Fq 'proof host listener is not loopback-confined' "${RUNNER}" || fail "host readiness must prove a loopback-only listener"
grep -Fq 'reverse --no-rebind "tcp:$PORT" "tcp:$PORT"' "${RUNNER}" || fail "online host access must use a deterministic ADB reverse"
grep -Fq 'reverse --list | grep -Eq "tcp:$PORT[[:space:]]+tcp:$PORT"' "${RUNNER}" || fail "online host access must verify the reverse registration"
grep -Fq 'reverse --remove "tcp:$PORT"' "${RUNNER}" || fail "offline proof must remove the ADB reverse before transport isolation"
grep -Fq 'sigraNativeProofHostBaseUrl="http://localhost:$PORT"' "${RUNNER}" || fail "the proof app must use the reversed localhost endpoint"
if grep -Eq '(^|[^[:alnum:]_])sleep[[:space:]]+[0-9]' "${RUNNER}"; then
  fail "fixed sleeps are prohibited"
fi

printf 'android proof runner hermetic contracts: pass\n'
