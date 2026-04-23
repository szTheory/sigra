# Phase 69: Intermediate path + optional features - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning  
**Source:** `/gsd-discuss-phase 69` — user requested **all** gray areas; five parallel research subagents (ecosystem + Diátaxis + DX); single synthesized decision set (no interactive Q&A menu).

<domain>

## Phase boundary

Ship **ACF-02** and **ACF-03**: maintainer-facing **documentation only** — (1) one **intermediate dogfood** narrative (install → confirm → session login → sensitive flow) that states assumed generator defaults, links **`.planning/v1.10-ADOPTER-SCOPE.md`**, and does **not** fork production checklist tables from phase 68. (2) one **canonical generator / CLI options index** summarizing `mix sigra.install` switches (`--no-admin`, `--no-organizations`, `--no-passkeys`, LiveView, API/JWT, `binary_id`, etc.), linked from **`getting-started`** and **`first-hour`** per roadmap success criteria. No new runtime behavior.

</domain>

<decisions>

## Implementation decisions (cohesive system)

### A. Intermediate path — doc home & shape (ACF-02)

- **D-01:** Add a **new Introduction extra**: `guides/introduction/intermediate-production-path.md` (title TBD in implementation — must read as “after first hour / toward solo prod”, not a second `first-hour`). **Job:** numbered **narrative spine + sequencing + “when to read what”** only — not a second deployment checklist.
- **D-02:** **Do not** substantially inflate `first-hour.md` beyond its **~one hour / green loop** contract; **do not** merge prod tables into it. **Do** add this new page to the **reading map** in `first-hour.md` as an explicit step **after** checklist green and **before** public host (alongside existing deployment anchor).
- **D-03:** **Do not** duplicate env/cookie/Oban tables from `guides/recipes/deployment.md`. The intermediate doc **deep-links** to anchors (`#production-checklist-read-first`, flow guides, installation) and may restate **decision criteria** in prose (“when you need `COOKIE_DOMAIN`”) — never full matrices.
- **D-04:** Structure: **one-screen ordered path** (local confidence → mail semantics pointer → deployment checklist → optional OAuth/MFA depth via existing flow docs) so solo adopters get **least surprise** and **progressive disclosure** without a linear mega-page that forks truth.

### B. Assumed `mix sigra.install` presentation (ACF-02 + ACF-03)

- **D-05:** **Hybrid (SSOT in code + intent in prose):** Dogfood narrative shows the **minimal real invocation** with all three arguments — `mix sigra.install Accounts User users` (plus `--yes` only when teaching CI/scripts). **Do not** spell out every positive default flag in the primary command line (avoids noise and “false requiredness”).
- **D-06:** Immediately follow with one **short “v1.10 default bundle”** prose block: LiveView on, `binary_id` on, organizations on, admin on, passkeys on — aligned with **`@default_opts`** in `lib/mix/tasks/sigra.install.ex` and **`.planning/v1.10-ADOPTER-SCOPE.md`**. Link to **`mix help sigra.install`** / HexDocs **`Mix.Tasks.Sigra.Install`** for exhaustive switches.
- **D-07:** **`@moduledoc` on `Mix.Tasks.Sigra.Install` is normative:** every `@switches` entry (including **organizations** / `--no-organizations`) must appear in Options with correct semantics — eliminates trust gap where code/help omits doc or vice versa. Implementation phase: verify and fix any gap before publishing the guide matrix.
- **D-08:** **Security-shrinking flags** (`--no-passkeys`, `--no-admin`, etc.): primary dogfood path **must not** normalize them in the hero command. Document them in the **generator options index** + optional “slimmer / alternate installs” subsection — same pattern as Laravel security options not living in the default Breeze command line.

### C. Optional-feature index — placement & format (ACF-03)

- **D-09:** **New dedicated extra:** `guides/reference/generator-options.md` as the **single canonical URL** for the full flag matrix (ACF-03 “one index”). Above the fold: compact **table** — Flag | Default | One-line effect | “See also” (flow/recipe doc). Below: short **prose clusters** for API/JWT, `binary_id`, organizations, passkeys, admin, LiveView — each linking to existing guides (`api-authentication.md`, `deployment.md`, `mfa.md`, etc.).
- **D-10:** **Footer contract:** “If this page disagrees with `mix help sigra.install`, treat **help** as authoritative and fix the guide.” Reinforces single technical truth while keeping human-oriented matrix in HexDocs.
- **D-11:** **`installation.md`:** Prefer **thin bridge** (one paragraph + prominent link to `generator-options.html`) over repeating the full matrix once the reference page exists — limits four-way drift (README / installation / deployment / moduledoc). If a **small cheat table** (5–8 rows) remains in installation for readers who never open Reference, it must be labeled as a subset pointing to the canonical index.
- **D-12:** **`mix.exs`:** Register the new extra; add an ExDoc **`Reference`** (or **CLI & generators**) `groups_for_extras` regex for `guides/reference/` so the index is not buried as “another intro file.” Order: Introduction tutorials first, **Reference** next, then Flows/Recipes as today.

### D. Cross-links from `getting-started` + `first-hour` (ACF-03 success criteria)

- **D-13:** **Role split (not layout parity):** `first-hour.md` **owns** the above-the-fold **spine** (reading map + checklist + tight optional pointers). `getting-started.md` stays **narrative-first**; keep at most the existing **“Faster path”** row early — **no second above-fold strip** for intermediate / generator index (avoids competing CTAs and tutorial abandonment).
- **D-14:** **Coverage parity:** Both **`getting-started`** and **`first-hour`** MUST link once to **`generator-options.md`** (same stable relative URL) — in `first-hour`: reading map and/or post-checklist handoff; in `getting-started`: extend **“What’s next”** / end-of-tutorial expansion (alongside phase-68-style production closure at end).
- **D-15:** **Intermediate production path** link: **reading map** in `first-hour` + **end section** in `getting-started` (same philosophy as D-13/D-14). Avoid duplicating the same paragraph in three places — one sentence + link pattern.

### E. Sensitive flow exemplar (ACF-02)

- **D-16:** **Canonical exemplar:** **MFA (TOTP) enrollment** end-to-end (post-confirmation, logged-in), including **backup codes surfaced and acknowledged**, clock/window caveat in short prose, and **prerequisite** (“have an authenticator app before continuing”). Aligns with **`.planning/v1.10-ADOPTER-SCOPE.md`** (TOTP + backup codes in default bundle) and differentiates Sigra from generic **phx.gen.auth**-style tutorials that stop at password reset.
- **D-17:** **Sidebar (not second hero):** **Password change** as a **short** subsection teaching **session semantics** — especially **invalidating other sessions** / why it matters with DB sessions + HTTPS/cookies — with pointer to existing flow docs. Not a full parallel walkthrough.
- **D-18:** **Explicit anti-patterns to avoid in copy:** MFA enrollment without backup-code emphasis; password change without session revocation narrative; implying email is always synchronous in prod without pointing at mail/DNS checklist elsewhere.

### Coherence note

**Three layers, one truth:** (1) **`mix help` / `@moduledoc`** = exhaustive CLI. (2) **`generator-options.md`** = scannable index + implications. (3) **`intermediate-production-path.md`** = ordered story + links only. **`deployment.md`** remains the **only** home for prod checklist tables. **`first-hour`** = time box; **`getting-started`** = depth; neither absorbs the other's job.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope

- `.planning/REQUIREMENTS.md` — **ACF-02**, **ACF-03**
- `.planning/ROADMAP.md` — Phase 69 goals and success criteria
- `.planning/v1.10-ADOPTER-SCOPE.md` — assumed bundle for narrative defaults
- `.planning/phases/068-deploy-and-mail-confidence/068-CONTEXT.md` — phase 68 placement decisions (do not steal ACF-02/03)

### Code and install truth

- `lib/mix/tasks/sigra.install.ex` — `@switches`, `@default_opts`, arity, `@moduledoc` (must stay aligned)
- `lib/sigra/install/features/*.ex` — feature-level `--no-*` behavior
- `test/example/` — CI-backed example host for “what we test” pointers when useful

### Docs to create or extend

- `guides/introduction/intermediate-production-path.md` — **new** (narrative spine)
- `guides/reference/generator-options.md` — **new** (canonical flag index)
- `guides/introduction/first-hour.md` — reading map + handoff links
- `guides/introduction/getting-started.md` — end-of-doc “What’s next” links
- `guides/introduction/installation.md` — thin bridge to generator index
- `mix.exs` — `extras` + `groups_for_extras` for new files

### Ecosystem patterns (research only — no fork)

- Diátaxis: tutorial vs how-to vs explanation separation
- Phoenix deployment guide separation from intro tutorials (`https://hexdocs.pm/phoenix/deployment.html`)

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- `guides/introduction/getting-started.md` — tutorial spine; reading map; end-of-doc expansion pattern from phase 68.
- `guides/introduction/first-hour.md` — checklist + reading map + optional OAuth/MFA pointers.
- `guides/recipes/deployment.md` — canonical prod tables; link target only.
- `lib/mix/tasks/sigra.install.ex` — defaults and switches for matrix + prose.

### Established patterns

- Diátaxis-style split already used: intro vs recipes vs flows.
- Phase 68: production pointer at **end** of getting-started; hub in deployment.

### Integration points

- `mix.exs` ExDoc `extras` / `groups_for_extras` — register new guides and Reference group.
- Cross-links among intro guides must stay **thin** (sentence + link) to avoid drift.

</code_context>

<specifics>

## Specific ideas (from research synthesis)

- **Pow / Ueberauth lesson:** avoid split-brain and stale matrices — one canonical index URL + moduledoc truth.
- **phx.gen.auth lesson:** narrow generator doc scope is fine; Sigra’s differentiator is **MFA + optional features** in the intermediate story — lead with TOTP enrollment, not a second password-reset tutorial.
- **NextAuth / Laravel lesson:** opinionated happy path + separate reference for knobs; version pressure via upgrade guides (already in repo), not blog scatter.
- **npm / Cargo lesson:** one obvious index + machine-adjacent help + short recipes.

</specifics>

<deferred>

## Deferred ideas

- Renaming files (`solo-production-path` vs `intermediate-production-path`) — executor may adjust title/slug for ExDoc nav clarity; semantic contract in D-01–D-04 is fixed.
- CI assertion that `@moduledoc` mentions every switch — nice follow-up if not already covered by install-golden; not required to satisfy ACF-02/03 textually.

**Reviewed todos:** None (`todo.match-phase` returned empty).

</deferred>

---

*Phase: 069-intermediate-path-optional-features*  
*Context gathered: 2026-04-23*
