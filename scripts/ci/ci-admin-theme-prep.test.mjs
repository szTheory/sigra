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
