# Contributing to Sigra

## Developing

- Elixir/OTP versions are pinned in `.tool-versions`; use `asdf` or your preferred version manager.
- Library tests require PostgreSQL (`PGUSER` / `PGPASSWORD` / `PGHOST`); see `CLAUDE.md` for a Docker one-liner.
- The `test/example` app is the generated-host fixture used by installer drift tests and Playwright smoke runs.

**Releases:** Hex + GitHub releases are automated via **Release Please** on `main` (see [`MAINTAINING.md`](MAINTAINING.md)). Use **conventional commits** (`feat:`, `fix:`, …) so the Release PR gets the right semver bump; routine `mix test` and CI do not require Node.js or external planning audit tooling.

## Reproducing the PR gate locally (mix ci)

Run `mix ci` to reproduce the locally-faithful portion of the PR-fast required gate without leaving your terminal. It chains exactly four legs in the same order as CI:

1. `compile --warnings-as-errors` — library compiles with zero warnings.
2. `test` — full library test suite.
3. `ci.install_golden` — install golden diff + idempotency contract (`test/sigra/install/`).
4. `sigra.dep_off` — dep-off guard: unlocks `:threadline`, re-compiles without it (`--warnings-as-errors`), then runs the tagged `--only threadline_guard` subset.

If `mix ci` is red, your PR will be red. If `mix ci` is green, the locally-faithful portion of the gate is green (CI-only lanes may still fail; see below).

### Prerequisites

**Live Postgres** — every test leg except the planning contract-lock tests requires a live PostgreSQL instance. See `CLAUDE.md` ("Local development prerequisites") for full instructions. Quick path:

```
scripts/db/up.sh        # boots ephemeral Dockerized test PG, writes tmp/db.env
source tmp/db.env       # exports SIGRA_TEST_PG_* into the current shell
```

Without `direnv`, you must `source tmp/db.env` in every new shell before running `mix test` or `mix ci`. If you run a local Postgres on port 5432, the fallback defaults apply automatically.

**phx_new 1.8.8 archive** — the `ci.install_golden` leg generates a Phoenix app via `phx_new` and diffs it against a committed fixture. A different local archive version produces spurious byte-diffs and a red gate. Install the pinned version:

```
mix archive.install --force hex phx_new 1.8.8
```

The fixture is reblessed against 1.8.8 — use this version locally to keep your gate in sync with CI.

### CI-only lanes (intentionally excluded from mix ci)

The following gates run in CI but are excluded from `mix ci` because they either require Ubuntu font metrics or heavy infrastructure that cannot be reproduced faithfully on a local macOS machine:

- **Ubuntu-baselined Playwright visual snapshots** (`admin-checkpoints-*`, `admin-design-*`): pixel baselines are captured on Ubuntu with specific system fonts. Local macOS runs produce sub-pixel font-metric diffs that diverge from the stored PNGs even when the UI is correct. Do **not** re-record baselines locally. Instead, download the `admin-example-report` artifact from the GitHub Actions run and open `playwright-report/index.html` in your browser.
- **Heavy scaffold smokes** — the install smoke and HTTP smoke run the full `phx.new + sigra.install` scaffolding against a live dev server. They are excluded from the default `mix ci` run because they take several minutes and require Docker. You can run them manually:
  - `scripts/ci/install-smoke.sh` — scaffolds a new host app and boots it.
  - boot the example app + `scripts/ci/http-smoke.sh` — hits live HTTP endpoints.

### Optional local hygiene (not in the PR gate)

These are useful for code quality but are deliberately **not** part of `mix ci` because they are not required checks in the PR gate. Running them locally may produce reds that CI does not enforce:

- `mix format --check-formatted`
- `mix credo --strict`
- `mix dialyzer`

### Known non-regression mix test failures (v1.40)

The following failures appear on a stock v1.40 checkout and are **not regressions** — do not investigate them as new failures:

- **golden_diff_test.exs** — red if your local phx_new archive differs from 1.8.8 (install 1.8.8 to fix).
- **UpgradeIntegrationTest** (3 tests) — require a specific database and environment configuration not present in a default dev setup.

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
