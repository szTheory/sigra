# Phase 248: Protected Environment Setup

**Updated:** 2026-10-09
**Status:** Environment secret names and exact-main policies confirmed; hosted workflow verification and repository-secret migration remain pending.

## Confirmed setup

- `release-automation` contains `RELEASE_PLEASE_TOKEN`.
- `hex-publish` contains `HEX_API_KEY` and the existing `HEX_DRY_RUN_API_KEY`.
- Both environments allow only `main`; administrator bypass is disabled.
- The name-only secret queries and `release-environment-preflight.sh` passed. See `248-ENVIRONMENT-SECRETS-RECEIPT.json`. No secret values were read or recorded.

## Remaining migration

Keep the repository-level copies until the protected-environment workflows are deployed and a hosted run proves they use the environment copies. The current GitHub `main` still has the older release workflows, which consume repository-level secrets. Remove the repository-level copies only after the new workflow path is live and its hosted checks pass.

## Local preflight

```bash
bash scripts/ci/release-environment-preflight.sh \
  --repository szTheory/sigra \
  --require-release-token true \
  --require-hex-dry-run-key true \
  --require-hex-publish-key true
```

Expected output: both environments report `main`, followed by `release-environment-preflight: PASS`.
