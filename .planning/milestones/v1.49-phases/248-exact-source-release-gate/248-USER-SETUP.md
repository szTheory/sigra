# Phase 248: Protected Environment Setup Evidence

**Generated:** 2026-10-10
**Phase:** 248-exact-source-release-gate  
**Status:** Complete

GitHub now has the required secret names in their intended environments, both deployment policies allow only `main`, and the repository has no repository-level secrets. The live preflight passes. Secret values were never read or recorded.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [x] | `RELEASE_PLEASE_TOKEN` | Name confirmed in the protected environment; value not read | `release-automation` |
| [x] | `HEX_API_KEY` | Name confirmed in the protected environment; value not read | `hex-publish` |
| [x] | `HEX_DRY_RUN_API_KEY` | Name confirmed in the protected environment; value not read | `hex-publish` |

## Dashboard Configuration

- [x] Confirm `RELEASE_PLEASE_TOKEN` is present in `release-automation`.
- [x] Confirm `HEX_API_KEY` and `HEX_DRY_RUN_API_KEY` are present in `hex-publish`.
- [x] Confirm the repository-level secret list is empty.

The environments already use a selected-branch deployment policy containing exactly `main`; admin bypass is disabled. `hex-publish` already contains `HEX_DRY_RUN_API_KEY`. Do not replace or expose those values during this setup.

## Verification

Verified by listing secret names only and running:

```bash
gh secret list --repo szTheory/sigra --env release-automation --json name --jq 'map(.name)'
gh secret list --repo szTheory/sigra --env hex-publish --json name --jq 'map(.name)'
```

Observed results included `RELEASE_PLEASE_TOKEN` under `release-automation`, both `HEX_DRY_RUN_API_KEY` and `HEX_API_KEY` under `hex-publish`, no repository-level secrets, and both environments restricted to `main`. The preflight returned `release-environment-preflight: PASS`.

```bash
bash scripts/ci/release-environment-preflight.sh \
  --repository szTheory/sigra \
  --require-release-token true \
  --require-hex-dry-run-key true \
  --require-hex-publish-key true
```

The check is repeatable and safe: it prints environment names and policy results only, never secret values.

---

**Completed:** 2026-10-10. The protected-environment setup is proven; hosted failure/cancellation receipt evidence remains a separate AUTO-02 verification gap.
