# Plan 35-06 Summary

**Objective:** Admin artifact bundle contract + reviewer documentation (SC6).

**Delivered:**
- `scripts/ci/admin-artifact-bundle-contract.sh` — requires ≥15 PNGs under the artifact root, each ≥5000 bytes (override via env).
- CI step in `example_playwright_smoke` after curated screenshot collection: runs the contract on `test/example/priv/playwright/artifacts/admin-checkpoints` when the job succeeds.
- Repo-root `CONTRIBUTING.md` with developing, CI overview, and admin Playwright artifact review bullets (`admin-example-report`, `generated_admin_playwright_smoke`, 15 PNG contract).

**Verify:** `bash scripts/ci/admin-artifact-bundle-contract.sh test/example/priv/playwright/artifacts/admin-checkpoints` (after a green admin checkpoint Playwright run)
