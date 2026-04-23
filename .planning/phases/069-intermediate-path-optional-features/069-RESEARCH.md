# Phase 69 — Technical research

**Question:** What do we need to know to plan **intermediate dogfood path** + **generator options index** documentation?

## RESEARCH COMPLETE

### 1. `@moduledoc` vs `@switches` gap (D-07)

`lib/mix/tasks/sigra.install.ex` defines `organizations: :boolean` in `@switches` and defaults `organizations: true` in `@default_opts`, but the **Options** section of `@moduledoc` (lines ~16–25) does **not** document `--organizations` / `--no-organizations`. **Fix is mandatory** before claiming the generator index matches CLI truth.

### 2. ExDoc extras and Hex tarball

`mix.exs` `package/0` `files` lists `lib priv docs …` — **root `guides/`** are referenced only via `docs/0` `extras`. Hex publish behavior: confirm `guides/` ship with the package used for docs (existing phases already ship intro guides). **New files** must be added to `extras` in `docs/0` and placed on disk under `guides/introduction/` and `guides/reference/` as in CONTEXT.

### 3. Linking `.planning/v1.10-ADOPTER-SCOPE.md`

That path is **not** in the default Hex `files` list. For **HexDocs** readers, use **`@source_url` GitHub blob** (e.g. `https://github.com/sztheory/sigra/blob/main/.planning/v1.10-ADOPTER-SCOPE.md`) so the link resolves without expanding the Hex package. ROADMAP success text names the **repo-relative** path — include that string visibly in prose so search/grep and GitHub readers satisfy the criterion.

### 4. Anchor patterns (phase 68)

`guides/recipes/deployment.md` uses stable heading anchors (`#production-checklist-read-first`). New guides should use **single, kebab-safe H1/H2** titles so ExDoc anchors are predictable; cross-links from `first-hour` / `getting-started` / `installation` use **`.html`** sibling paths consistent with existing guides.

### 5. `installation.md` flag table

Current **subset** table omits organizations. Per **D-11**: add a **prominent** link to `generator-options.html` (canonical matrix) and either add **`--organizations` / `--no-organizations`** row or replace wide table with **labeled subset** + pointer — avoid four-way drift with the new reference page.

### 6. Sensitive-flow exemplar (D-16–D-18)

Reuse vocabulary and routes from **`guides/flows/mfa.html`** (TOTP, backup codes). Do **not** duplicate full `deployment.md` tables; deep-link to `#production-checklist-read-first` and mail TL;DR anchor.

---

## Validation Architecture

**Dimension 8 (Nyquist):** Documentation-only phase — no new runtime auth surface.

| Dimension | Sampling strategy |
|-----------|---------------------|
| Build / docs | `MIX_ENV=dev mix docs --warnings-as-errors` after every task that touches `mix.exs` or `guides/**/*.md` |
| Regression | `mix ci.install_golden` if `sigra.install` `@moduledoc` changes (golden/help alignment) |
| Manual | Spot-check generated `doc/` for new extras navigation under **Reference** group |

**Feedback latency target:** &lt; 120s for docs task; full golden only on install task.

---

## Sources read

- `.planning/phases/069-intermediate-path-optional-features/069-CONTEXT.md`
- `lib/mix/tasks/sigra.install.ex`
- `mix.exs` (`docs/0`)
- `guides/introduction/{installation,first-hour,getting-started}.md`
- `.planning/v1.10-ADOPTER-SCOPE.md`
