# Next steps (manual only)

Everything else (clean tree, tests, docs, `mix hex.build`, remote branch, `v1.3` tag, **PR opened**) is already done.

**Open PR:** https://github.com/szTheory/sigra/pull/13  

---

## 1. Merge into `main`

- Wait until **all required checks** are green on the PR.  
- **Merge** the PR (squash or merge — match your team norm).

CLI (after review):

```bash
gh pr merge 13 --merge
# or: gh pr merge 13 --squash
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

In **GitHub → Releases**: create a release from tag **`v1.3`** (or align tags with the Hex version you publish — see **`MAINTAINING.md`**).

Paste the relevant **`CHANGELOG.md`** section into the release notes.

## 4. Sanity check

- https://hex.pm/packages/sigra  
- https://hexdocs.pm/sigra  
