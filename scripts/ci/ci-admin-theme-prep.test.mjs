import assert from 'node:assert/strict';
import fs from 'node:fs';
import { test } from 'node:test';

const fixturePath = new URL('../../test/example/priv/playwright/fixtures/adminTheme.ts', import.meta.url);

test('admin theme fixture defines an invocation-scoped storage identity and isolated consumer contexts', () => {
  const source = fs.existsSync(fixturePath) ? fs.readFileSync(fixturePath, 'utf8') : '';

  assert.match(source, /createAdminThemeStoragePath/);
  assert.match(source, /mode:\s*0o600/);
  assert.match(source, /openSync\(storagePath,\s*['"]wx['"],\s*0o600\)/);
  assert.match(source, /scope:\s*['"]worker['"]/);
  assert.match(source, /storageState:\s*adminThemeAuth\.storagePath/);
  assert.match(source, /finally/);
});

test('admin theme fixture setup uses anonymous registration and deletes auth bytes after the invocation', () => {
  const source = fs.existsSync(fixturePath) ? fs.readFileSync(fixturePath, 'utf8') : '';

  assert.match(source, /browser\.newContext\(\{\s*storageState:\s*undefined/);
  assert.match(source, /users\/register/);
  assert.match(source, /storageState\(\{\s*path:/);
  assert.match(source, /rmSync\(.*storagePath/s);
  assert.doesNotMatch(source, /catch\s*\([^)]*\)\s*\{\s*\/\/\s*ignore/s);
});

test('browser runner drops only a database it created when a browser invocation fails', () => {
  const runnerPath = new URL('./ci-admin-theme-check.mjs', import.meta.url);
  const source = fs.readFileSync(runnerPath, 'utf8');

  assert.match(source, /if \(dbName && dbOwned && cleanupContext\)/);
  assert.match(source, /dropdb', \['--if-exists', dbName\]/);
  assert.match(source, /database-drop-after-failure/);
});

test('eligible admin theme cases are opt-in while the real lockout case stays anonymous', () => {
  const spec = fs.readFileSync(new URL('../../test/example/priv/playwright/tests/admin-theme.spec.ts', import.meta.url), 'utf8');
  const optedIn = spec.match(/adminThemeTest\(/g) ?? [];
  assert.equal(optedIn.length, 18);
  assert.match(spec, /test\("overview notice action link is visibly actionable"/);
  assert.match(spec, /await lockUserByFailedLogins\(page, targetEmail\)/);
  assert.match(spec, /await logInAsPlatformAdmin\(page\)/);
});

test('default Chromium and mobile projects do not inherit shared authenticated storage', () => {
  const config = fs.readFileSync(new URL('../../test/example/priv/playwright/playwright.config.ts', import.meta.url), 'utf8');
  const chromium = config.match(/name: ["']chromium["'][\s\S]*?(?=name: ["']mobile["'])/)?.[0] ?? '';
  const mobile = config.match(/name: ["']mobile["'][\s\S]*?(?=name: ["']admin-checkpoints-chromium["'])/)?.[0] ?? '';
  assert.ok(chromium);
  assert.ok(mobile);
  assert.doesNotMatch(chromium, /storageState/);
  assert.doesNotMatch(mobile, /storageState/);
});

test('bounded checker exposes focused, full-file, state-control, and all modes', () => {
  const source = fs.readFileSync(new URL('./ci-admin-theme-check.mjs', import.meta.url), 'utf8');
  for (const mode of ['tracer', 'individual', 'file', 'state-controls', 'all']) assert.match(source, new RegExp(`'${mode}'`));
  assert.match(source, /--workers=1/);
  assert.match(source, /--retries=0/);
  assert.match(source, /context_creation_count/);
  assert.match(source, /auth-artifact-exclusion/);
});

test('branding state is restored through the supported UI after each mutating case', () => {
  const spec = fs.readFileSync(new URL('../../test/example/priv/playwright/tests/admin-theme.spec.ts', import.meta.url), 'utf8');
  assert.match(spec, /async function restoreBrandingDefaults\(page: Page\)/);
  assert.match(spec, /adminThemeTest\.afterEach\(async \(\{ page \}, testInfo\)/);
  assert.match(spec, /testInfo\.title\.startsWith\("auth branding"\)/);
  assert.match(spec, /getByRole\("button", \{ name: "Restore defaults" \}\)/);
  assert.match(spec, /Source: Config defaults/);
});
