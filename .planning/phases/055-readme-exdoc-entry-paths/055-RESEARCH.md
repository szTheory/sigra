# Phase 55: README & ExDoc entry paths — Technical research

**Status:** Ready for planning  
**Date:** 2026-04-22

## Summary

Phase **55** implements **DOC-01** / **DOC-02** from `.planning/REQUIREMENTS.md` using locked decisions in **`055-CONTEXT.md`**. No new runtime code paths; deliverables are **`README.md`**, optional root **`SECURITY.md`**, new **`docs/ga-evidence.md`**, **`mix.exs`** `docs/0`, and a short **reading map** in **`guides/introduction/getting-started.md`**.

### HexDocs vs GitHub rendering

- **`package/0` `files`** omits `.planning/`. Relative links like `[GA](.planning/v1.4-GA-UAT.md)` **break** when README is viewed from the **Hex** tarball on hexdocs.pm.
- **`mix.exs`** already defines `@source_url "https://github.com/sztheory/sigra"` and `source_ref: "v#{@version}"` (**v0.2.0** today). Evidence outside the shipped bundle should use **`@source_url/blob/v#{@version}/…`** (or the matching release tag) in **README** prose the maintainer resolves at publish time — align with phase **54** link hygiene.

### ExDoc `extras` and `main`

- `docs/0` sets `main: "getting-started"` → default landing remains **`guides/introduction/getting-started.html`** (integrator-first). **Do not** flip `main` to README for this phase (**055-CONTEXT D-08**).
- Packaged **`docs/*.md`** files are under `docs/` and match **`groups_for_extras` `Docs: ~r{^docs/}`**. New hub belongs as **`docs/ga-evidence.md`** (or synonym per D-09 discretion).

### SECURITY.md

- Repo has **no** `SECURITY.md` today (glob + list_dir). **D-14** prefers adding one in this phase: coordinated disclosure, link from README + hub + reading map. GitHub surfaces `SECURITY.md` automatically; it need not duplicate GA matrices.

### README insertion point

- **Security posture (headlines)** table ends ~L162 with the “map, not a spec” sentence. New **Production readiness & GA evidence** (exact title executor choice) section goes **immediately after** that block (**D-01**).

### Verification commands

- **`mix compile --warnings-as-errors`** — unchanged expectation for touched Elixir.
- **`MIX_ENV=dev mix docs --warnings-as-errors`** — mandatory when `mix.exs` `docs/0` or any `extras` markdown changes (**D-17** / roadmap criterion 3).

---

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Broken relative `.planning/` links on HexDocs | Use tag-scoped GitHub URLs per D-05; grep for forbidden patterns |
| Warranty-adjacent README language | Grep forbid list (SOC2, audit-certified, “GA passed” as absolute claim) |
| `mix docs` broken links / missing extras | `mix docs --warnings-as-errors` in verification |
| Duplicating GA matrix into README | CONTEXT D-12 — paragraph + bullets only |

---

## Validation Architecture

> Nyquist / Dimension 8: executable feedback loops for this documentation phase.

### Automated signal paths

1. **Compile gate:** `mix compile --warnings-as-errors` after any `mix.exs` edit.
2. **ExDoc gate:** `MIX_ENV=dev mix docs --warnings-as-errors` — catches broken **extras** links, missing files, and xref issues.
3. **Link hygiene grep (executor):** Fail if README or `docs/ga-evidence.md` contains bare `](.planning/` **without** a documented exception (there should be **none** for GA evidence meant to work from Hex).

### Sampling strategy

- **After each task commit:** Run **`mix compile --warnings-as-errors`** when `mix.exs` touched; otherwise run **compile** if Elixir changed, else skip.
- **After all markdown + mix.exs edits in a wave:** Run **`MIX_ENV=dev mix docs --warnings-as-errors`** once.
- **Before `/gsd-verify-work`:** Both commands green; spot-check GitHub-rendered README preview for anchor sanity (manual).

### Manual-only checks

| Behavior | Why manual |
|----------|------------|
| GitHub **Security** tab matches `SECURITY.md` policy intent | Requires browser / org settings |
| Readable “two-hop” path from HexDocs landing to GA narrative | Visual navigation of generated HTML |

---

## RESEARCH COMPLETE
