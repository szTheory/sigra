import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import {
  REQUIRED_SCENARIOS,
  TARGET_CLASSES,
  validateNativeReceipt,
  writeNativeReceiptLast,
} from './native-proof-receipt.mjs';

const GIT_SHA = 'a'.repeat(40);
const SHA256 = 'b'.repeat(64);
const IOS_TOOLCHAIN = { xcode_version: '16.0', xcode_build: '16A242d' };
const ANDROID_TOOLCHAIN = {
  jdk: '21.0.4', cmdline_tools: '13.0', platform_tools: '35.0.2', emulator: '35.2.10',
  sdk_platform: 'android-35', build_tools: '35.0.0', system_image: 'google_apis_playstore',
  system_image_revision: '12', gradle: '8.10', agp: '8.7.2', kotlin: '2.0.21',
  androidx_browser: '1.8.0', test_core: '1.6.1', test_runner: '1.6.2', espresso: '3.6.1', uiautomator: '2.3.0',
};

function scenarios() {
  return Object.fromEntries(REQUIRED_SCENARIOS.map((scenario) => [scenario, true]));
}

function receipt(targetClass = 'physical_iphone') {
  const shared = {
    schema_version: 'native-proof-receipt/1', implementation_sha: GIT_SHA, target_class: targetClass,
    callback: { transport: 'custom_scheme', link_verification: 'registered_scheme', callback_binding: 'matched' },
    storage: { present: true, rotated: true, recovered_after_relaunch: true, deleted_after_logout: true, deleted_after_revocation: true, read_result: 'read_ok', access_persisted: false },
    scenarios: scenarios(), cleanup_status: 'complete', secret_scan_status: 'clean', terminal_status: 'complete',
  };
  if (targetClass === 'physical_iphone') return {
    ...shared,
    target_identity: { platform: 'ios', model_class: 'iPhone', os_version: '18.0', physical: true },
    toolchain: IOS_TOOLCHAIN,
    browser: { component: 'ASWebAuthenticationSession', version: '18.0', mode: 'system_external_user_agent' },
    transport: { claim: 'controlled_transport_failure' },
    artifact_hashes: { app_bundle_sha256: SHA256, xctest_bundle_sha256: SHA256, diagnostics_sha256: SHA256 },
  };
  return {
    ...shared,
    target_identity: { platform: 'android', avd_device: 'pixel_8', api: '35', abi: 'x86_64', emulated: true },
    toolchain: ANDROID_TOOLCHAIN,
    browser: { component: 'com.android.chrome', version: '128.0', apk_sha256: SHA256, mode: 'auth_tab' },
    transport: { wifi_disabled: true, cellular_disabled: true, emulator_network_disabled: true, force_stop: true, cold_start: true },
    artifact_hashes: { app_apk_sha256: SHA256, test_apk_sha256: SHA256, diagnostics_sha256: SHA256 },
  };
}

function invalid(mutator) {
  const value = receipt();
  mutator(value);
  assert.throws(() => validateNativeReceipt(value));
}

test('allowlists the two truthful native targets and their exact terminal receipts', () => {
  assert.deepEqual(TARGET_CLASSES, ['physical_iphone', 'android_emulator']);
  assert.equal(validateNativeReceipt(receipt()).target_class, 'physical_iphone');
  assert.equal(validateNativeReceipt(receipt('android_emulator')).target_class, 'android_emulator');
});

test('rejects missing bindings, target substitutions, incomplete proof, unclean terminal state, and unknown keys', () => {
  invalid((value) => { delete value.implementation_sha; });
  invalid((value) => { value.implementation_sha = SHA256; });
  invalid((value) => { value.target_identity.physical = false; });
  invalid((value) => { value.transport.claim = 'physical_radio_disabled'; });
  invalid((value) => { value.scenarios.offline_use = false; });
  invalid((value) => { value.cleanup_status = 'pending'; });
  invalid((value) => { value.secret_scan_status = 'finding'; });
  invalid((value) => { value.artifact_hashes.app_bundle_sha256 = 'not-a-hash'; });
  invalid((value) => { value.storage.extra = true; });
  invalid((value) => { value.target_identity.model_class = 'device-123456'; });
  invalid((value) => { value.callback.callback_binding = 'unmatched'; });
  invalid((value) => { value.terminal_status = 'pending'; });
});

test('rejects Android target mismatches and incomplete all-transport disablement', () => {
  invalid((value) => { Object.assign(value, receipt('android_emulator'), { target_class: 'physical_iphone' }); });
  const android = receipt('android_emulator');
  android.transport.wifi_disabled = false;
  assert.throws(() => validateNativeReceipt(android));
  android.transport.wifi_disabled = true;
  android.browser.apk_sha256 = 'not-a-hash';
  assert.throws(() => validateNativeReceipt(android));
});

test('writes only already-bound, validated terminal receipts', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'native-proof-receipt-'));
  const output = join(dir, 'receipt.json');
  const value = receipt();
  await writeNativeReceiptLast(output, value, GIT_SHA);
  assert.deepEqual(JSON.parse(await readFile(output, 'utf8')), value);

  value.terminal_status = 'pending';
  await assert.rejects(() => writeNativeReceiptLast(join(dir, 'bad.json'), value, GIT_SHA));
  await assert.rejects(() => writeNativeReceiptLast(join(dir, 'wrong-sha.json'), receipt(), 'c'.repeat(40)));
  await assert.rejects(() => writeNativeReceiptLast(join(dir, 'wrong-width.json'), receipt(), SHA256));
});
