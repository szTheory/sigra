# Contributing to Sigra

## Developing

- Elixir/OTP versions are pinned in `.tool-versions`; use `asdf` or your preferred version manager.
- Library tests require PostgreSQL (`PGUSER` / `PGPASSWORD` / `PGHOST`); see `CLAUDE.md` for a Docker one-liner.
- The `test/example` app is the generated-host fixture used by installer drift tests and Playwright smoke runs.

## CI overview

- **Library tests** — full `mix test` for the Hex package.
- **Example + install matrix** — compiles the example app and runs installer smoke paths.
- **Milestone verification gate** — `scripts/ci/milestone-verification-gate.sh` ensures completed milestone phases keep a verification report on disk.
- **Installer milestone audit** — `scripts/ci/installer-milestone-audit.sh` (paths-filtered on pull requests) encodes critical installer integration checks (INT-01..INT-03).
- **Playwright** — `example_playwright_smoke` boots `test/example` and runs browser suites; curated admin checkpoint PNGs are collected under `test/example/priv/playwright/artifacts/admin-checkpoints/`.
- **Admin artifact bundle contract** — after a green Playwright admin run, `scripts/ci/admin-artifact-bundle-contract.sh` asserts the curated PNG bundle meets minimum count and file size.

## Reviewing admin Playwright artifacts

1. Open the GitHub Actions run for **Example Playwright smoke (full lifecycle)** (job id `example_playwright_smoke`) or the generated-host variant **`generated_admin_playwright_smoke`** when reviewing installer parity.
2. Download the **`admin-example-report`** artifact (HTML report plus bundled files).
3. In the extracted tree, open `playwright-report/index.html` and confirm the five checkpoint scenarios appear green for **admin-checkpoints-chromium**, **admin-checkpoints-mobile**, and **admin-checkpoints-dark**.
4. Under `artifacts/admin-checkpoints/`, confirm at least **15** non-trivial PNG files (curated reviewer bundle); the CI step `Admin artifact bundle contract` enforces count and a minimum size per file.
5. For template-only changes, confirm the **Installer milestone audit** job ran on your pull request (it skips when no files under `priv/templates/sigra.install/` or `lib/sigra/install/` changed).

## Playwright reports on GitHub Pages (optional)

This repo can host a browsable mirror of the Playwright HTML report (including **videos** on the checkpoint and generated-host lanes when published via the dedicated workflow).

1. Run **Playwright reports (GitHub Pages)** once on **`main`** (Actions → Run workflow, or wait for schedule / path-filtered push). The job pushes `gh-pages`, then calls the GitHub REST API (`scripts/ci/ensure-github-pages-legacy-branch.sh`) to **create or switch** the repo’s Pages source to **legacy build from branch `gh-pages` at `/`**, so you usually **do not** open **Settings → Pages** manually.
2. Project URL: `https://<owner>.github.io/<repository>/` (for example `https://szTheory.github.io/sigra/`). Private repositories may require a paid GitHub plan for Pages.
3. The site root lists each run under `runs/<YYYYMMDD-<run_id>>/` with a link into `playwright-report/index.html`. Older run folders are pruned (seven-day policy in the assemble script).

**If the API step fails with 403** (some orgs restrict `pages:write` on `GITHUB_TOKEN`), set Pages once in **Settings → Pages** → **Deploy from a branch** → **`gh-pages`** / **`/`**, then re-run the workflow.

**If Pages is already set to “GitHub Actions”** (`build_type: workflow`), the ensure script **does not** change it; use Settings or migrate the workflow to `deploy-pages` yourself.
