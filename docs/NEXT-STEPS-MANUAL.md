# Next steps (manual only)

Everything else (clean tree, tests, docs, `mix hex.build`, remote branch, `v1.3` tag) is already done. You only need to:

## 1. Merge into `main`

Branch **`chore/main-release-sync-2026-04-18`** is pushed and should have an open PR into **`main`** (repo rules block direct pushes to `main`).

- Open the PR: https://github.com/szTheory/sigra/compare/main...chore/main-release-sync-2026-04-18  
- Wait until **all required checks** are green.  
- **Merge** the PR (squash or merge — match your team norm).

CLI alternative after review:

```bash
gh pr merge <PR_NUMBER> --merge
# or: gh pr merge <PR_NUMBER> --squash
```

## 2. Publish Hex (first or next version)

After **`main`** contains the merge at the commit you intend to ship:

1. Confirm **`mix.exs`** `@version` is the version you want on Hex (today: **`0.1.0`** — see **`MAINTAINING.md`** if you need **`0.2.0`** for new public API since last publish).
2. From a clean **`main`** checkout with **`HEX_API_KEY`** set:

   ```bash
   mix hex.publish --yes
   ```

   Or use **Actions → Hex publish (manual)** (`workflow_dispatch`) per **`MAINTAINING.md`**.

## 3. GitHub Release

In **GitHub → Releases**: create a release from tag **`v1.3`** (or from the **Hex** version tag if you tag `v0.1.1` etc. separately — keep tag story aligned with **`MAINTAINING.md`**).

Paste the relevant **`CHANGELOG.md`** section into the release notes.

## 4. Sanity check

- https://hex.pm/packages/sigra  
- https://hexdocs.pm/sigra  

---

If no PR exists yet, create it with:

```bash
gh pr create --base main --head chore/main-release-sync-2026-04-18 \
  --title "chore: sync main — release prep, v1.3 planning close, Hex/docs" \
  --body "Automated release-prep branch. See docs/NEXT-STEPS-MANUAL.md for post-merge steps."
```
