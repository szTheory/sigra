# Next steps (manual only)

Use this when something **cannot** be driven by GitHub Actions (credentials outside GitHub, one-off maintainer tasks).

Canonical release procedure: `docs/release-runbook-v1-0.md` (gate matrix, release-ref evidence, dry-run/package inspection, publish/recovery, and first-14-day hotfix policy).

**Default Hex + GitHub releases:** see **`MAINTAINING.md` → Release automation** plus `docs/release-runbook-v1-0.md`. On `main`, [Release Please](https://github.com/googleapis/release-please) opens a **Release PR** from conventional commits; **merging that PR** creates the **GitHub Release + `v*` tag** and runs **`publish-hex`** with **`HEX_API_KEY`**. Primary recovery: **Actions → Hex publish (manual recovery)**.

---

## 1. Merge work into `main`

- Wait until **required checks** are green on the PR, then merge (squash or merge — team norm).

```bash
gh pr merge <N> --merge
```

## 2. Ship a Hex version (if not using Release Please)

After **`main`** has the commit you intend to ship:

1. Confirm **`mix.exs`** `@version` and **`MAINTAINING.md`** semver notes.
2. Follow runbook release-ref checks first (tag/version/manifest/source_ref, package inspection, dry-run) in `docs/release-runbook-v1-0.md`.
3. **`HEX_API_KEY`** in **Settings → Secrets → Actions**, then either:
   - merge the **Release PR** from Release Please (preferred), or
   - **Actions → Hex publish (manual recovery)** with tag/SHA + version string, or
   - local trusted-machine publish fallback only: `mix hex.publish --yes`

## 3. GitHub Release

Release Please creates the release when the Release PR merges. For a hand-cut release, use **GitHub → Releases** from the **`v<version>`** tag and paste the matching **`CHANGELOG.md`** section.

## 4. Sanity check

- https://hex.pm/packages/sigra  
- https://hexdocs.pm/sigra  
