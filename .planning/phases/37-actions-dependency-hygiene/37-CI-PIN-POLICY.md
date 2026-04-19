# Phase 37 — CI pin policy

## CI-02 evidence

CI-02 evidence: https://github.com/szTheory/sigra/actions/runs/24449861846

> **Replace after push:** This URL is the latest **success** conclusion on workflow **CI** for branch `main` at the time of Phase 37 execution (2026-04-17). It does **not** yet include the Phase 37 SHA triad on `main`. After you push the Plan 01 workflow commits and GitHub reports a **success** `CI` run for that commit (PR head or merge), edit the line above to that run’s `https://github.com/szTheory/sigra/actions/runs/<id>` URL so CI-02 matches merged reality.

## CI-03 intentional pins

### `erlef/setup-beam`

- **Pin:** `erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93` (# v1.24.0)
- **Reason:** Not part of the **999.2** first-party `actions/checkout` + `actions/setup-node` + `actions/upload-artifact` triad scoped in Plan 01; separate ecosystem (Erlang/Elixir/OTP matrix).
- **Revisit trigger:** Next Dependabot PR for `erlef/setup-beam`, or quarterly supply-chain review.

### `actions/cache`

- **Pin:** `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830` (# v4.3.0)
- **Reason:** Explicitly out of scope for Plan 01 (only the three first-party actions above); bump would need coordinated cache key / path review across jobs.
- **Revisit trigger:** Next Dependabot PR for `actions/cache`, or when cache restore failures spike.

### `peaceiris/actions-gh-pages`

- **Pin:** `peaceiris/actions-gh-pages@4f9cc6602d3f66b9c108549d475ec49e8ef4d45e` (# v4.0.0) in `.github/workflows/playwright-github-pages.yml`
- **Reason:** Third-party deploy action, not an `actions/*` first-party bump in the 999.2 triad; pages deploy semantics differ from artifact upload.
- **Revisit trigger:** Next Dependabot PR for `peaceiris/actions-gh-pages`, or before changing GitHub Pages publishing strategy.

## Adopted pins (reference)

Example lines after Plan 01 (matches `.github/workflows/` on branch):

- `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2`
- `uses: actions/setup-node@2028fbc5c25fe9cf00d9f06a71cc4710d4507903  # v6.0.0`
- `uses: actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f  # v6.0.0`
