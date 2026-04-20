# Maintaining Sigra

This document is for **maintainers** who cut Hex releases and GitHub releases. **Drive-by contributors** should start with [`CONTRIBUTING.md`](CONTRIBUTING.md) for tests, CI expectations, and review norms.

## GitHub Actions repository settings (runbook)

These are **repository** (or org) settings on GitHub, not files in this repo. A maintainer with **admin** access must apply them once so **Release Please** can open and update release PRs using the default `GITHUB_TOKEN`.

**Where:** [Repository → Settings → Actions → General](https://github.com/szTheory/sigra/settings/actions) (replace `szTheory/sigra` if you forked).

### Workflow permissions (required for Release Please)

Under **Workflow permissions**:

1. Select **Read and write permissions** so workflows can push release branches and update files as needed.
2. Enable **Allow GitHub Actions to create and approve pull requests**. Without this, Release Please fails with: *GitHub Actions is not permitted to create or approve pull requests* — even when `.github/workflows/release-please.yml` sets `permissions: pull-requests: write`.

The workflow already requests `contents: write`, `issues: write`, and `pull-requests: write` in YAML; the UI above must allow PR creation for that to take effect.

### Which actions may run

Pick the **least privilege** your org policy allows while still running third-party actions (`googleapis/release-please-action`, `actions/*`, `erlef/setup-beam`, etc.):

- **Allow all actions and reusable workflows** — simplest default for this repo.
- **Allow szTheory, and select non-szTheory…** — fine if org policy requires an allowlist; ensure every external action you use is permitted.

**Allow szTheory actions only** is only viable if every action is defined inside the `szTheory` org (usually not true here).

### Fork pull request workflows

Unrelated to Release Please on `main`. A common balance is **Require approval for first-time contributors**; stricter orgs use **Require approval for all external contributors**.

### Artifact, log, and cache retention

Retention controls cost and history only; **no impact** on Release Please or Hex publish mechanics.

### Verify Release Please after changing settings

From a machine with `gh` authenticated to this repo:

```bash
gh workflow run "Release Please" --ref main
gh run list --workflow "Release Please" --limit 1
gh run watch "$(gh run list --workflow 'Release Please' --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```

**Success signals**

- The **Release Please** job finishes **without** the error: *GitHub Actions is not permitted to create or approve pull requests*.
- A pull request may appear titled like a Release Please release (inspect open PRs targeting `main`; Release Please often uses a working branch such as `release-please--branches--main`).

**If it still fails with that permission error**, the repository (or **organization**) Actions policy still blocks PR creation by `GITHUB_TOKEN` — re-check the two **Workflow permissions** bullets above and any **organization-level** Actions overrides.

### If the org forbids “Actions may create PRs”

Do **not** enable **Allow GitHub Actions to create and approve pull requests**. Instead add a fine-grained **PAT** as the **`RELEASE_PLEASE_TOKEN`** secret (contents + pull-requests write, and any scopes Release Please needs for your branch rules). The workflow uses `token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}` — see **Release automation** below.

## Release automation (default)

Sigra follows the same pattern as sibling libraries (**Release Please** + **Hex on merge**):

1. **Conventional commits on `main`** — Release Please reads history and opens/updates a **Release PR** that bumps `mix.exs` / `CHANGELOG.md` (see [release-please](https://github.com/googleapis/release-please) and config in `release-please-config.json`).
2. **Merge the Release PR** when you are ready to ship. On merge, **`.github/workflows/release-please.yml`** creates the **GitHub Release** and **`v<version>` tag**, then runs **Postgres-backed `mix test`**, **`mix hex.publish --yes`** with **`HEX_API_KEY`**, and polls **hex.pm** until the new version is visible.
3. **Secrets** — configure **`HEX_API_KEY`** under **GitHub → Settings → Secrets and variables → Actions**. If you cannot enable **Allow GitHub Actions to create and approve pull requests** (org policy), add a fine-grained PAT as **`RELEASE_PLEASE_TOKEN`** with `contents` + `pull-requests` write (and scopes required by your branch rules); the workflow uses `RELEASE_PLEASE_TOKEN` when set, otherwise `github.token`. If the UI *is* enabled but you still see token errors, check org-level Actions policies overriding the repo.
4. **Released version anchor** — `.release-please-manifest.json` records the last shipped version for Release Please. After an exceptional manual publish, bump that file in the same commit as `mix.exs` so automation stays aligned.
5. **Changelog shape** — Release Please’s `elixir` release type expects to own `CHANGELOG.md` entries for automated releases. The first Release PR may normalize headings; resolve merge conflicts in favor of a single coherent history, then keep using **conventional commits** on `main`.

**Recovery / one-off publish:** **Actions → Hex publish (manual recovery)** — supply the **tag or SHA** and the **expected `@version`** string; it runs the same compile + test + dry-run + publish path without Release Please.

## Manual release checklist (emergency or pre-automation)

Use only when not using the Release PR flow. Adjust version strings to match `mix.exs`.

1. Confirm `mix.exs` `@version` matches the release you intend to ship.
2. Update `CHANGELOG.md` with everything notable since the last tag.
3. Run the library test suite against Postgres (same bar as CI):

   ```bash
   PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
   ```

4. Ensure `git status` is clean (or only contains intentional release files).
5. Commit the version bump and changelog if they are not already on the release branch.
6. Create an annotated or lightweight tag after the version bump lands:

   ```bash
   git tag v0.2.0
   ```

   (Replace `0.2.0` with the actual `@version`.)

7. Push the tag (and branch, if applicable):

   ```bash
   git push origin main
   git push origin v0.2.0
   ```

8. Publish to Hex from a trusted machine with `HEX_API_KEY` configured, or run **Actions → Hex publish (manual recovery)**. Non-interactive automation should use `mix hex.publish --yes` as documented in [Hex publish](https://hex.pm/docs/publish).

9. Open **GitHub → Releases** if you still need a release entry not created by Release Please.
10. Verify the [Hex version badge](https://hex.pm/packages/sigra) reflects the new version and that [HexDocs](https://hexdocs.pm/sigra) `source_ref` matches the tag you published (`mix.exs` `docs/0` uses `source_ref: "v#{@version}"`).
11. After publish, smoke-check a fresh `mix deps.get` consumer app or the example app pinned to the new requirement range.

## Semver for Sigra (pre-1.0)

Hex and Mix treat `0.x` minors as potentially breaking. Use **`0.y.z` patches** only for doc-only fixes, internal-only changes, or releases that do **not** add new **supported public** `lib/` API since the last published version.

Use a **`0.y` minor bump** when you ship **new supported public** modules or functions on Hex since the last publish. In particular: if the last Hex publish was **`0.1.0`** without `Sigra.Audit.Assertions`, a release that includes that module (or any comparable new supported public `lib/` surface) must be at least **`0.2.0`**. Do **not** jump to **`1.0.0`** unless the project explicitly decides to declare API stability with coordinated messaging.

Atomic release hygiene: keep **`mix.exs` `@version`**, **`CHANGELOG.md`**, the **`v<version>`** tag, Hex publish, and the GitHub Release aligned in one tight commit series (or a documented sequence), not scattered across unrelated merges.

## Planning hygiene (without gsd-tools JSON)

Reliance on **`gsd-tools audit-open --json`** is **deprecated** for this repository. The upstream helper has been unreliable; Sigra maintainers should use **grep-driven** checks over `.planning/phases/` instead.

Examples you can run from the repo root:

```bash
# Phase directories missing a *-VERIFICATION.md artifact
find .planning/phases -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  compgen -G "$dir"/*-VERIFICATION.md >/dev/null || echo "missing VERIFICATION: $dir"
done
```

```bash
# PLAN files that explicitly opt out of Nyquist compliance (spot-check)
rg -l '^nyquist_compliant: false' .planning/phases --glob '*-PLAN.md' || true
```

Optional helper (bash only, no Node): `scripts/maintainers/planning-audit-hygiene.sh`.

For full release mechanics and secret handling, see [Hex publish](https://hex.pm/docs/publish).

## Optional GitHub Environment for Hex

For extra guardrails, configure a GitHub **Environment** (e.g. **`hex`**) with **required reviewers** and attach it to the **`publish-hex`** job in **`.github/workflows/release-please.yml`** and/or **`hex-publish.yml`** so publish steps need an explicit approval. This is optional; the default workflow uses repository secrets only.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/release-please.yml` | push to **`main`**, `workflow_dispatch` | Release PR + tag + GitHub Release + **Hex publish** when a release is created |
| `.github/workflows/hex-publish.yml` | **`workflow_dispatch`** only | **Manual recovery** publish from a chosen tag/SHA + version string |

Configure **`HEX_API_KEY`** (and optionally **`RELEASE_PLEASE_TOKEN`**) under **Settings → Secrets and variables → Actions**. Never add those secrets to `ci.yml` or unrelated jobs.
