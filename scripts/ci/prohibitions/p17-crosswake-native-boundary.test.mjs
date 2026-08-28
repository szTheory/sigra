import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { extname, join, relative } from 'node:path';

import { readRepoFile, readSubject } from './_lib.mjs';
import { validateNativeReceipt } from '../lib/native-proof-receipt.mjs';

const SUBJECT_ENV = 'GSD_PROHIB_SUBJECT';
const REQUIRED_FACTS = Object.freeze({
  nativeEvidenceMarkerCount: 'number',
  hostOwnsAuthority: 'boolean',
  telemetryAllowlistCount: 'number',
  telemetryRejectsSensitiveFields: 'boolean',
  receiptValidatorMarkerCount: 'number',
  receiptIsFailClosed: 'boolean',
  statusIsPostureOnly: 'boolean',
  embeddedBrowserFree: 'boolean',
  directPasswordFree: 'boolean',
  targetClassOverclaimFree: 'boolean',
});

function count(text, pattern) { return [...text.matchAll(pattern)].length; }

function elixirBlock(text, attribute) {
  const hit = text.match(new RegExp(`${attribute}\\s*\\[([\\s\\S]*?)\\n\\s*\\]`));
  if (!hit) throw new Error(`could not parse ${attribute} — the parse broke, this is not a pass`);
  return hit[1];
}

function parseInjectedFacts() {
  let facts;
  try { facts = JSON.parse(readSubject('test/fixtures/prohibitions/p17-crosswake-native-boundary-clean.json')); }
  catch (error) { throw new Error(`could not parse injected native prohibition facts: ${error.message}`); }
  assert.ok(facts && typeof facts === 'object' && !Array.isArray(facts), 'injected facts must be an object');
  assert.deepEqual(Object.keys(facts).sort(), Object.keys(REQUIRED_FACTS).sort(), 'injected facts must have exactly the required keys');
  for (const [key, type] of Object.entries(REQUIRED_FACTS)) assert.equal(typeof facts[key], type, `injected facts must include ${key} as a ${type}`);
  return facts;
}

function sensitiveKey(key) {
  return /access_token|actor_id|authorization_code|credential_id|device_id|email|id_token|ip|nonce|org_id|passkey_credential_id|pkce_verifier|provider_payload|raw_return_to|refresh_token|return_to|session_ref|subject_ref|user_agent/.test(key);
}

const NATIVE_SOURCE_EXTENSIONS = new Set(['.gradle', '.java', '.json', '.kt', '.kts', '.m', '.mm', '.plist', '.properties', '.swift', '.xml']);

function readNativeSourceTree(root) {
  const files = [];
  const visit = (directory) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) visit(path);
      else if (entry.isFile() && NATIVE_SOURCE_EXTENSIONS.has(extname(entry.name))) files.push(path);
    }
  };
  visit(root);
  const repoOrder = (path) => relative(root, path).split('\\').join('/');
  return files
    .sort((left, right) => repoOrder(left) < repoOrder(right) ? -1 : repoOrder(left) > repoOrder(right) ? 1 : 0)
    .map((path) => readFileSync(path, 'utf8'))
    .join('\n');
}

function deriveRepositoryFacts() {
  const bridge = readRepoFile('test/example/lib/example/accounts/crosswake_native_bridge.ex');
  const telemetry = readRepoFile('test/example/deps/crosswake_sigra/lib/crosswake/companions/sigra/telemetry.ex');
  const receiptSource = readRepoFile('scripts/ci/lib/native-proof-receipt.mjs');
  const status = JSON.parse(readRepoFile('test/example/priv/native-fixtures/native-proof-status.json'));
  const metadata = elixirBlock(telemetry, '@metadata_keys');
  const forbidden = elixirBlock(telemetry, '@forbidden_metadata_keys');
  const nativeRoots = ['test/example/native/ios', 'test/example/native/android'].filter(existsSync);
  const nativeSource = nativeRoots.map((root) => readNativeSourceTree(root)).join('\n');
  const nativeSurface = `${bridge}\n${receiptSource}\n${nativeSource}`;

  let statusValid = false;
  try { validateNativeReceipt(status); statusValid = true; } catch { statusValid = false; }
  const statusText = JSON.stringify(status);
  const forbiddenKeys = [...forbidden.matchAll(/:\s*([a-z_]+)/g)].map((match) => match[1]);

  return {
    nativeEvidenceMarkerCount: count(bridge, /@native_evidence_keys/g) + count(bridge, /AuthReturn\.new_native_evidence/g),
    hostOwnsAuthority:
      /CrosswakeSessionAdapter\.evaluate_return/.test(bridge) &&
      /LearningTwin\.replay/.test(bridge) &&
      /terminal status is accepted or derived here/.test(bridge),
    telemetryAllowlistCount: [...metadata.matchAll(/:\s*[a-z_]+/g)].length,
    telemetryRejectsSensitiveFields:
      forbiddenKeys.length >= 12 && forbiddenKeys.every(sensitiveKey) &&
      ![...metadata.matchAll(/:\s*([a-z_]+)/g)].map((match) => match[1]).some(sensitiveKey),
    receiptValidatorMarkerCount:
      count(receiptSource, /exactKeys\(/g) + count(receiptSource, /validateNativeReceipt/g),
    receiptIsFailClosed:
      /TARGET_CLASSES = Object\.freeze\(\['physical_iphone', 'android_emulator'\]\)/.test(receiptSource) &&
      /cleanup_status must be complete/.test(receiptSource) &&
      /secret_scan_status must be clean/.test(receiptSource) &&
      /terminal_status must be complete/.test(receiptSource),
    statusIsPostureOnly:
      statusValid && !/access_token|refresh_token|authorization_code|pkce_verifier|credential|account_id|device_id/i.test(statusText),
    embeddedBrowserFree: !/\bWKWebView\b|\bWebView\b/.test(nativeSurface),
    directPasswordFree: !/direct[_ -]?password|password[_ -]?grant|password[_ -]?login/i.test(nativeSurface),
    targetClassOverclaimFree:
      status.target_class === 'physical_iphone' && status.target_identity.physical === true &&
      status.transport.claim === 'controlled_transport_failure' &&
      /controlled_transport_failure/.test(receiptSource) &&
      !/physical_radio_disabled|radio_disconnection/.test(receiptSource),
  };
}

function facts() { return process.env[SUBJECT_ENV] ? parseInjectedFacts() : deriveRepositoryFacts(); }

const subject = facts();

test('Crosswake native evidence is not authentication or replay authority', () => {
  assert.ok(subject.nativeEvidenceMarkerCount >= 2, `native evidence marker floor was ${subject.nativeEvidenceMarkerCount}; the parse broke, this is not a pass`);
  assert.equal(subject.hostOwnsAuthority, true, 'the host session adapter and learning twin must retain authority');
});

test('retained native evidence is posture-only and telemetry rejects sensitive fields', () => {
  assert.ok(subject.telemetryAllowlistCount >= 18, `telemetry allowlist floor was ${subject.telemetryAllowlistCount}; the parse broke, this is not a pass`);
  assert.equal(subject.telemetryRejectsSensitiveFields, true, 'released telemetry must reject sensitive metadata keys');
  assert.ok(subject.receiptValidatorMarkerCount >= 4, `receipt marker floor was ${subject.receiptValidatorMarkerCount}; the parse broke, this is not a pass`);
  assert.equal(subject.receiptIsFailClosed, true, 'the shared receipt must fail closed before a terminal claim');
  assert.equal(subject.statusIsPostureOnly, true, 'the retained status fixture must contain posture rather than secrets or stable identities');
});

test('native sources forbid embedded/direct password authentication and target-class overclaiming', () => {
  assert.equal(subject.embeddedBrowserFree, true, 'native surface must not embed a browser authentication view');
  assert.equal(subject.directPasswordFree, true, 'native surface must not introduce a direct-password path');
  assert.equal(subject.targetClassOverclaimFree, true, 'iPhone controlled transport evidence must not claim radio disconnection');
});
