import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, basename, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

export const TARGET_CLASSES = Object.freeze(['physical_iphone', 'android_emulator']);
export const REQUIRED_SCENARIOS = Object.freeze([
  'hosted_return', 'image_verified', 'audio_verified', 'strict_lease_edge', 'offline_use',
  'kill_relaunch', 'account_switch', 'server_revocation', 'replay_accepted', 'replay_rejected',
  'replay_conflict',
]);

const TOP_LEVEL_KEYS = Object.freeze([
  'schema_version', 'implementation_sha', 'target_class', 'target_identity', 'toolchain', 'browser',
  'callback', 'storage', 'scenarios', 'transport', 'artifact_hashes', 'cleanup_status',
  'secret_scan_status', 'terminal_status',
]);
const CALLBACK_KEYS = Object.freeze(['transport', 'link_verification', 'callback_binding']);
const STORAGE_KEYS = Object.freeze([
  'present', 'rotated', 'recovered_after_relaunch', 'deleted_after_logout', 'deleted_after_revocation',
  'read_result', 'access_persisted',
]);
const IOS = Object.freeze({
  target: ['platform', 'model_class', 'os_version', 'physical'],
  toolchain: ['xcode_version', 'xcode_build'],
  browser: ['component', 'version', 'mode'],
  transport: ['claim'],
  hashes: ['app_bundle_sha256', 'xctest_bundle_sha256', 'diagnostics_sha256'],
});
const ANDROID = Object.freeze({
  target: ['platform', 'avd_device', 'api', 'abi', 'emulated'],
  toolchain: ['jdk', 'cmdline_tools', 'platform_tools', 'emulator', 'sdk_platform', 'build_tools', 'system_image', 'system_image_revision', 'gradle', 'agp', 'kotlin', 'androidx_browser', 'test_core', 'test_runner', 'espresso', 'uiautomator'],
  browser: ['component', 'version', 'apk_sha256', 'mode'],
  transport: ['wifi_disabled', 'cellular_disabled', 'emulator_network_disabled', 'force_stop', 'cold_start'],
  hashes: ['app_apk_sha256', 'test_apk_sha256', 'diagnostics_sha256'],
});
const SHA256 = /^[a-f0-9]{64}$/;
const GIT_COMMIT_SHA = /^[a-f0-9]{40}$/;
const SECRET_OR_ID = /(?:access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|pkce|password|bearer\s|\b(?:user|account|device|actor)[_-]?\d{3,}\b)/i;

function fail(message) { throw new TypeError(`invalid native proof receipt: ${message}`); }

function object(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${label} must be an object`);
  return value;
}

function exactKeys(value, keys, label) {
  object(value, label);
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    fail(`${label} must contain exactly ${expected.join(', ')}`);
  }
}

function string(value, label) {
  if (typeof value !== 'string' || value.length === 0) fail(`${label} must be a non-empty string`);
  if (SECRET_OR_ID.test(value)) fail(`${label} contains a secret or stable identity-shaped value`);
}

function sha(value, label) {
  if (typeof value !== 'string' || !SHA256.test(value)) fail(`${label} must be a lowercase SHA-256`);
}

function gitCommitSha(value, label) {
  if (typeof value !== 'string' || !GIT_COMMIT_SHA.test(value)) fail(`${label} must be a lowercase 40-hex Git commit SHA`);
}

function boolean(value, label, expected = undefined) {
  if (typeof value !== 'boolean' || (expected !== undefined && value !== expected)) fail(`${label} has an invalid boolean value`);
}

function allTrue(value, keys, label) {
  exactKeys(value, keys, label);
  for (const key of keys) boolean(value[key], `${label}.${key}`, true);
}

function validateShared(receipt) {
  exactKeys(receipt, TOP_LEVEL_KEYS, 'receipt');
  if (receipt.schema_version !== 'native-proof-receipt/1') fail('schema_version must be native-proof-receipt/1');
  gitCommitSha(receipt.implementation_sha, 'implementation_sha');
  if (!TARGET_CLASSES.includes(receipt.target_class)) fail('target_class is not allowlisted');
  exactKeys(receipt.callback, CALLBACK_KEYS, 'callback');
  if (receipt.callback.transport !== 'custom_scheme' || receipt.callback.link_verification !== 'registered_scheme' || receipt.callback.callback_binding !== 'matched') fail('callback is not exactly verified');
  exactKeys(receipt.storage, STORAGE_KEYS, 'storage');
  for (const key of ['present', 'rotated', 'recovered_after_relaunch', 'deleted_after_logout', 'deleted_after_revocation']) boolean(receipt.storage[key], `storage.${key}`);
  boolean(receipt.storage.access_persisted, 'storage.access_persisted', false);
  if (!['read_ok', 'not_found', 'decrypt_failed', 'key_unavailable'].includes(receipt.storage.read_result)) fail('storage.read_result is not allowlisted');
  allTrue(receipt.scenarios, REQUIRED_SCENARIOS, 'scenarios');
  if (receipt.cleanup_status !== 'complete') fail('cleanup_status must be complete');
  if (receipt.secret_scan_status !== 'clean') fail('secret_scan_status must be clean');
  if (receipt.terminal_status !== 'complete') fail('terminal_status must be complete');
}

function validateIos(receipt) {
  exactKeys(receipt.target_identity, IOS.target, 'target_identity');
  if (receipt.target_identity.platform !== 'ios' || receipt.target_identity.physical !== true) fail('iOS receipt must identify a physical iPhone');
  string(receipt.target_identity.model_class, 'target_identity.model_class');
  string(receipt.target_identity.os_version, 'target_identity.os_version');
  exactKeys(receipt.toolchain, IOS.toolchain, 'toolchain');
  for (const key of IOS.toolchain) string(receipt.toolchain[key], `toolchain.${key}`);
  exactKeys(receipt.browser, IOS.browser, 'browser');
  for (const key of IOS.browser) string(receipt.browser[key], `browser.${key}`);
  exactKeys(receipt.transport, IOS.transport, 'transport');
  if (receipt.transport.claim !== 'controlled_transport_failure') fail('iOS transport must be controlled_transport_failure');
  exactKeys(receipt.artifact_hashes, IOS.hashes, 'artifact_hashes');
  for (const key of IOS.hashes) sha(receipt.artifact_hashes[key], `artifact_hashes.${key}`);
}

function validateAndroid(receipt) {
  exactKeys(receipt.target_identity, ANDROID.target, 'target_identity');
  if (receipt.target_identity.platform !== 'android' || receipt.target_identity.emulated !== true) fail('Android receipt must identify an emulator');
  for (const key of ['avd_device', 'api', 'abi']) string(receipt.target_identity[key], `target_identity.${key}`);
  exactKeys(receipt.toolchain, ANDROID.toolchain, 'toolchain');
  for (const key of ANDROID.toolchain) string(receipt.toolchain[key], `toolchain.${key}`);
  exactKeys(receipt.browser, ANDROID.browser, 'browser');
  for (const key of ['component', 'version', 'mode']) string(receipt.browser[key], `browser.${key}`);
  sha(receipt.browser.apk_sha256, 'browser.apk_sha256');
  allTrue(receipt.transport, ANDROID.transport, 'transport');
  exactKeys(receipt.artifact_hashes, ANDROID.hashes, 'artifact_hashes');
  for (const key of ANDROID.hashes) sha(receipt.artifact_hashes[key], `artifact_hashes.${key}`);
}

/** Validate and return a deeply JSON-safe native proof receipt. */
export function validateNativeReceipt(receipt) {
  validateShared(receipt);
  if (receipt.target_class === 'physical_iphone') validateIos(receipt);
  else validateAndroid(receipt);
  return receipt;
}

/** Atomically publish a receipt only after the caller's immutable source SHA is bound and validation succeeds. */
export async function writeNativeReceiptLast(outputPath, receipt, implementationSha) {
  gitCommitSha(implementationSha, 'bound implementation_sha');
  if (receipt?.implementation_sha !== implementationSha) fail('receipt implementation_sha does not match bound source SHA');
  const valid = validateNativeReceipt(receipt);
  const output = resolve(outputPath);
  await mkdir(dirname(output), { recursive: true });
  const temporary = resolve(dirname(output), `.${basename(output)}.${randomUUID()}.tmp`);
  try {
    await writeFile(temporary, `${JSON.stringify(valid, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
    await rename(temporary, output);
  } catch (error) {
    throw new Error(`could not atomically publish native proof receipt: ${error.message}`, { cause: error });
  }
}
