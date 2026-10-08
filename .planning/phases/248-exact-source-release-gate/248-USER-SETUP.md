# Phase 248: User Setup Required

**Generated:** 2026-10-08  
**Phase:** 248-exact-source-release-gate  
**Status:** Incomplete

The environment branch policies are already configured to allow only `main`, with admin bypass disabled. `HEX_DRY_RUN_API_KEY` is present in `hex-publish`. These two existing secret values cannot be retrieved from GitHub, so add them from the secure source of truth before removing the repository-level copies.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `RELEASE_PLEASE_TOKEN` | Existing value in your secure secret store; GitHub does not reveal saved secret values | GitHub repository Settings → Environments → `release-automation` → Environment secrets |
| [ ] | `HEX_API_KEY` | Existing write-capable value in your secure secret store; GitHub does not reveal saved secret values | GitHub repository Settings → Environments → `hex-publish` → Environment secrets |

## Dashboard Configuration

- [ ] Add `RELEASE_PLEASE_TOKEN` to the `release-automation` environment from the secure source of truth.
- [ ] Add `HEX_API_KEY` to the `hex-publish` environment from the secure source of truth.
- [ ] After both target names are confirmed, remove the corresponding repository-level secret copies. Keep the environment copies.

The environments already use a selected-branch deployment policy containing exactly `main`; admin bypass is disabled. `hex-publish` already contains `HEX_DRY_RUN_API_KEY`. Do not replace or expose those values during this setup.

## Verification

After adding the secrets, verify only their names:

```bash
gh secret list --repo szTheory/sigra --env release-automation --json name --jq 'map(.name)'
gh secret list --repo szTheory/sigra --env hex-publish --json name --jq 'map(.name)'
```

Expected results include `RELEASE_PLEASE_TOKEN` under `release-automation`, and both `HEX_DRY_RUN_API_KEY` and `HEX_API_KEY` under `hex-publish`. The live preflight can then confirm the policies and required secret-name booleans:

```bash
bash scripts/ci/release-environment-preflight.sh \
  --repository szTheory/sigra \
  --require-release-token true \
  --require-hex-dry-run-key true \
  --require-hex-publish-key true
```

Expected result: both environments report `main`, followed by `release-environment-preflight: PASS`.

---

**Once all items complete:** Mark status as "Complete" at top of file.
