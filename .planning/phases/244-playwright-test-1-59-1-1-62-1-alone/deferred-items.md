## Deferred Items

- The existing `undici@7.28.0` transitive dependency is reported vulnerable by the registry audit (high severity; fix available). It was already present in the pre-plan lockfile and is outside the isolated Playwright-only version update.
  status: open
  **Found during:** Plan 244-02 candidate install
  **Evidence:** `npm audit --json` in the candidate reports GHSA-4cwx-7wf7-3272 and additional advisories; lockfile baseline also resolves `undici@7.28.0`.
