# Phase 37 — Research: Actions & dependency hygiene

**Question:** What do we need to know to PLAN landing **999.2** / CI-01–CI-03 safely?

## Current inventory (2026-04-17)

| Action | Current pin | Appears in |
|--------|-------------|------------|
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` (# v4.3.1) | `ci.yml` ×12, `playwright-github-pages.yml` ×1 |
| `actions/setup-node` | `0a44ba7841725637a19e28fa30b79a866c81b0a6` (# v4.0.4) | `ci.yml` ×2, `playwright-github-pages.yml` ×1 |
| `actions/upload-artifact` | `b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882` (# v4.4.3) | `ci.yml` ×8 |

Other pinned actions in scope for **later** Dependabot cycles (not mandatory in 37 unless an open PR exists): `erlef/setup-beam`, `actions/cache`, `peaceiris/actions-gh-pages`.

## Target majors (tag → commit SHA via GitHub API)

Resolved with `GET /repos/{owner}/{repo}/git/refs/tags/{tag}`:

| Action | Tag | Commit SHA |
|--------|-----|------------|
| `actions/checkout` | `v6.0.2` | `de0fac2e4500dabe0009e67214ff5f5447ce83dd` |
| `actions/setup-node` | `v6.0.0` | `2028fbc5c25fe9cf00d9f06a71cc4710d4507903` |
| `actions/upload-artifact` | `v6.0.0` | `b7c566a772e6b6bfb58ed0dc250532a479d7789f` |

**Runner note (checkout v6):** Upstream documents a minimum GitHub-hosted runner version for some credential paths; hosted `ubuntu-latest` is expected to satisfy this for Sigra.

## `actions/upload-artifact` v4 → v6

Read [actions/upload-artifact releases](https://github.com/actions/upload-artifact/releases) for v5 and v6 breaking changes. This repo uses multiple steps with the same artifact `name` guarded by **mutually exclusive** `if:` conditions (main vs non-main); confirm that pattern still matches v6 semantics (artifact overwrite vs merge).

## Dependabot

`.github/dependabot.yml` already has `package-ecosystem: github-actions` on `/`. Open Dependabot PRs (if any) should be **triaged first** (CI-01): merge, supersede by this manual bump PR, or close with rationale.

## Validation Architecture

**Primary signal:** GitHub Actions workflow **CI** on the branch / `main` after merge — all jobs that are not intentionally skipped must succeed. This phase does not introduce new ExUnit coverage; it changes workflow YAML only.

**Local shift-left (optional, cheap):**

- `bash scripts/ci/milestone-verification-gate.sh` — still passes (no change to verification phases list).
- `yamllint` / `actionlint` — **not** currently wired; do not add new tooling in this phase unless CI already uses it.

**Nyquist / sampling:** After each logical task (workflow file fully updated), re-run at least the milestone gate locally; after merge, treat a green **CI** run on `main` as the full-suite proof for CI-02.

**Manual-only:** Confirming GitHub.com “all checks passed” on the merge commit for the PR that lands the bumps (human or `gh pr checks` in CI-02 plan).

## RESEARCH COMPLETE
