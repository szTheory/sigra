import path from 'node:path';
import baseConfig from '../../../test/example/priv/playwright/playwright.config';

const fixtureDirectory = path.resolve(process.cwd(), '../../../../scripts/ci/fixtures');

// Reuse the pinned production config while selecting this isolated probe file.
// It stays outside test/example/priv/playwright/tests and cannot enter product coverage.
export default {
  ...baseConfig,
  testDir: fixtureDirectory,
};
