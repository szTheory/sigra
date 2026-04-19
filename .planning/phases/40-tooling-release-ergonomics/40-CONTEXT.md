# Phase 40: Tooling & release ergonomics — Context

**Gathered:** 2026-04-18  
**Status:** Ready for planning  
**Source:** `REQUIREMENTS.md` (TOOL-01, REL-01), `ROADMAP.md`, `MILESTONES.md`, `PROJECT.md`, Phases 36–39 CONTEXT, parallel maintainer/OSS research (four areas), current repo layout (`mix.exs` @ `0.1.0`, no `MAINTAINING.md`, CI SHA-pin posture from Phase 37)

<domain>

## Phase boundary

Close **TOOL-01** (`gsd-tools audit-open --json` broken or unsupported path) and **REL-01** (maintainer checklist for Hex + GitHub release, optional isolated publish workflow pattern) with **no new product features** — documentation, optional scripts, workflow sample, and honest deprecation/replacement story only.

</domain>

<decisions>

## Implementation decisions

### TOOL-01 — `gsd-tools audit-open --json`

- **D-40-01 — Primary posture:** **Formally deprecate** reliance on `gsd-tools audit-open --json` in **canonical maintainer/contributor paths** (live docs: `CONTRIBUTING.md`, `README.md` if referenced, `scripts/`). Replace with a **repo-owned supported path**: short **manual checklist** plus, only if automation still needs structured output, a **narrow `scripts/` helper** (shell or `mix` task) — **not** a fork of full GSD.
- **D-40-02 — Historical `.planning/`:** **Do not rewrite milestone archives** for aesthetics. **Do** add **supersession notes** where live runbooks still instruct the broken command (e.g. phase 26 templates): one line “deprecated — see `MAINTAINING.md` § Planning audit hygiene” or link to checklist. Prefer **grep-driven** cleanup of **duplicate misleading “run this”** lines in still-active docs.
- **D-40-03 — Upstream:** **Encourage** (issue or PR) a fix in `get-shit-done` / `gsd-tools` for the `ReferenceError`, but **do not block** TOOL-01 closure on an upstream release. After upstream fixes land, docs may add “optional: `gsd-tools` ≥ x.y.z” — still not a contributor gate.
- **D-40-04 — Contributor gate invariant:** **`mix test` / CI must not require Node or global `gsd-tools`** for Sigra contributors. Maintainer-only steps may mention optional tools **below the fold** in `MAINTAINING.md`.
- **D-40-05 — Waiver is not default:** A bare “known broken” waiver **does not** satisfy TOOL-01; a **documented supported path** is mandatory.

### REL-01 — Maintainer docs shape

- **D-40-06 — Canonical home:** Add **`MAINTAINING.md` at repo root** (matches `MILESTONES.md` promise, GitHub-first discoverability). **Do not** fold the full Hex/GitHub release runbook into `CONTRIBUTING.md` (avoids privilege bleed and secret-adjacent noise for drive-by PRs).
- **D-40-07 — Split of concerns:** **`CONTRIBUTING.md`** owns **quality gates** (tests, CI overview, Postgres). **`MAINTAINING.md`** owns **reproducible shipping** (version, changelog, tag, Hex, GitHub Release). Link each way in one sentence at the top of the maintainer doc and a short pointer in CONTRIBUTING.
- **D-40-08 — README:** Add a single line near other meta links: maintainers → `MAINTAINING.md`.
- **D-40-09 — Depth:** Include a **12–20 line minimum ordered checklist** (copy-paste commands) in `MAINTAINING.md` even when longer explanations link to `CONTRIBUTING.md` / `scripts/ci/`. Above the fold: version source of truth, green bar definition, files that must change, post-publish verification.
- **D-40-10 — HexDocs (optional):** If ExDoc `extras` is easy, add `MAINTAINING.md`; if not, **link** from README/HexDocs intro to GitHub-rendered file — do not rely on ExDoc alone.

### REL-01 — Optional Hex publish workflow

- **D-40-11 — Include sample workflow:** **Yes** — add `.github/workflows/hex-publish.yml` (name may vary) as **documentation-shaped automation**: **`workflow_dispatch` only** (no `push`/`pull_request` trigger), **never** implies publish on every merge.
- **D-40-12 — Secret isolation:** **`HEX_API_KEY`** appears **only** on the publish job (or publish step), not in `ci.yml`. Reuse **SHA-pinned** `actions/checkout`, `erlef/setup-beam` consistent with Phase 37 policy.
- **D-40-13 — Job contents:** `checkout` → `setup-beam` → `mix deps.get` → **`mix test`** (or documented subset if too slow — prefer full library suite for publish job) → **`mix hex.publish --yes`** with scoped key per [Hex publish docs](https://hex.pm/docs/publish).
- **D-40-14 — Optional hardening:** Document GitHub **Environment** `hex` with required reviewers in `MAINTAINING.md`; implement if low friction.
- **D-40-15 — OIDC:** **Out of scope** — Hex publishing remains API-key based; do not promise OIDC/trusted-publishers until Hex supports it (track upstream separately).
- **D-40-16 — Local vs CI publish:** Checklist presents **local `mix hex.publish`** as the **default mental model**; the workflow is an **optional** execution path for maintainers who want CI-attested publish — both valid; **checklist remains source of truth for when** to release.

### Versioning — next Hex release after v1.3 stack

- **D-40-17 — Rule:** **`0.y.z` patch** for doc-only / internal-only / no new supported `lib/` API. **`0.y` minor bump** when **new supported public `lib/` modules or functions** ship on Hex since the last published version.
- **D-40-18 — Current repo reality:** `Sigra.Audit.Assertions` lives under `lib/sigra/audit/assertions.ex` (Phase 39). If the last Hex publish was **`0.1.0`** without that module, the **next** publish that includes v1.3 work MUST be at least **`0.2.0`** — treat as **additive public surface**, not a “no features” patch release.
- **D-40-19 — Forbidden surprise:** **Do not** jump to **`1.0.0`** in this milestone unless the project explicitly decides to **declare API stability** with coordinated messaging (out of scope for Phase 40 unless promoted).
- **D-40-20 — Atomic release commit:** Same PR/commit series (or tightly documented sequence): **`mix.exs` `@version`**, **`CHANGELOG.md`**, then tag **`v<version>`**, then Hex + GitHub Release — `MAINTAINING.md` encodes this gate explicitly.

### Claude's discretion

- Exact filename for optional audit helper under `scripts/` vs a `Mix.Tasks.Sigra.*` maintainer task (prefer **script** if no need to compile Sigra twice).
- Whether to add `MAINTAINING.md` to ExDoc `extras` in the same PR as the doc or a follow-up.
- Exact copy for supersession banners in historical `.planning/` files (tone: factual, not defensive).

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing Phase 40.**

### Requirements & milestone

- `.planning/REQUIREMENTS.md` — TOOL-01, REL-01 (Phase 40)
- `.planning/ROADMAP.md` — Phase 40 row
- `.planning/MILESTONES.md` — v1.3 section (Hex + GitHub release expectation, `MAINTAINING.md` pointer)
- `.planning/PROJECT.md` — TOOL-01 known limitation, v1.3 framing

### Prior phase context (cohesion)

- `.planning/phases/37-actions-dependency-hygiene/37-CONTEXT.md` — SHA pin format for any new workflow actions
- `.planning/phases/39-audit-trail-completeness/39-CONTEXT.md` — public audit test API decision (semver driver for `0.2.0`)

### Live repo surfaces

- `CONTRIBUTING.md` — contributor vs maintainer split insertion point
- `README.md` — maintainer link insertion point
- `mix.exs` — `@version`, `package/0`, docs config (`:source_ref` if touched)
- `CHANGELOG.md` — release notes discipline
- `.github/workflows/ci.yml` — contrast only; **do not** add `HEX_API_KEY` here

### External (Hex)

- [Hex — Publishing packages / CI](https://hex.pm/docs/publish) — scoped key, `HEX_API_KEY`, `mix hex.publish --yes`
- [HexDocs — `mix hex.publish`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html) — flags, package vs docs-only publish

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- `scripts/ci/*` — patterns for gates, bash contracts; any new maintainer script should match style and non-interactive defaults used elsewhere.
- `.github/workflows/ci.yml` and `.github/workflows/playwright-github-pages.yml` — **SHA-pinned** third-party actions (Phase 37); new `hex-publish.yml` must follow the same pin discipline.

### Established patterns

- **Contributor docs** are GitHub-centric and Postgres/`mix test`-oriented (`CONTRIBUTING.md`); maintainer docs should **not** dilute that story.
- **Library version** is single-sourced in `mix.exs` `@version` (`0.1.0` today).

### Integration points

- **README** badge already points at Hex; release checklist must keep **badge / Hex / tag** alignment.
- **`package/0` files list** in `mix.exs` — maintainer checklist should include a **sanity glance** so templates/priv stay publishable (historical CHANGELOG already notes `priv/` inclusion).

</code_context>

<specifics>

## Specific ideas

- **Research synthesis (2026-04-18):** OSS norm is **repo-owned or standard-tool** paths for release and hygiene — not mandatory global Node CLIs for every contributor (`npm`/Rubygems lesson: pin or replace; avoid silent broken README steps). **Phoenix/Oban/Req** pattern: README links out; **release** communication via CHANGELOG + optional maintainer doc — not privileged steps inside CONTRIBUTING. **Hex** explicitly supports CI publish with **`--yes`**; automation hides warnings — mitigate with **tests in publish job** and **manual dispatch** over merge-triggered publish. **Pre-1.0 semver:** patch for true non-API maintenance; **minor** when new supported `lib/` API ships — aligns “no product features” with honest library semver for `Sigra.Audit.Assertions`.

</specifics>

<deferred>

## Deferred ideas

- **Upstream `gsd-tools` fix** — track in GSD repo; optional follow-up to re-enable JSON for maintainers who already use Node GSD.
- **Hex OIDC / trusted publishers** — revisit when Hex ships a supported path; document “API key today” in `MAINTAINING.md`.
- **`mix hex.publish --dry-run` on every PR** without secrets — possible hardening phase; not required for TOOL-01/REL-01 closure.

### Reviewed todos (not folded)

- None — `gsd-sdk query todo.match-phase` unavailable in this environment.

</deferred>

---

*Phase: 40-tooling-release-ergonomics*  
*Context gathered: 2026-04-18*
