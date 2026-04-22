# Phase 53: Package & Hex metadata — Context

**Gathered:** 2026-04-21  
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship **PUB-01**: **`mix.exs`** Hex-facing metadata (especially `:description`, `package/0` **links**, and **maintainer-facing accuracy**) matches **shipped** Sigra through **v1.0–v1.4** — no dead links, no optional stacks presented as always-on, copy safe for a **public announcement** without restating waived GA matrix language in tarball metadata.

**Out of scope for this phase (other REQ / phases):** Full README rewrite (**DOC-01** → 55), changelog milestone anchors (**PUB-02** → 54), **`MAINTAINING.md`** announcement checklist (**MAINT-01** → 56). This phase may **note** companion edits elsewhere but must not expand into those deliverables.

**Requirements traceability (locked text):** `.planning/REQUIREMENTS.md` — **PUB-01**.

</domain>

<decisions>
## Implementation Decisions

### Hex `:description` (tone, depth, GA posture)

- **D-01 (tone):** Use **integrator-first, precision over slogan** — closer to **Ecto / Oban / Comeonin / wax_** than Phoenix’s marketing line or Swoosh’s dense adapter list. Lead with **what it is** (auth for Phoenix/Ecto, **library + Mix generators**), then **where it applies** (Phoenix **1.8+** / Ecto-first), then **capability categories** aligned to shipped code — **mechanism and scope**, not “enterprise-grade / audit-certified” claims in Hex metadata.
- **D-02 (length & shape):** Treat Hex `description` as a **short paragraph** (Hex spec / publish guidance: sentence to few sentences — not a second README). Structure: (1) core positioning, (2) **honest optional** sentence — integrations exist **only when the host app adds the matching deps**, (3) **single pointer** to hexdocs/README for defaults, optional matrix, and threat-model nuance.
- **D-03 (GA / audit language):** **Do not** put waived/executed GA matrix or `.planning/` evidence language in the Hex description. **Transparency** for outsiders belongs in **public** docs/README (phase **55**) with correct framing — not in tarball `description` where it is quoted out of context.
- **D-04 (anti-patterns):** Avoid fear marketing, implied warranties (“SOC2-ready”, “pen-tested”), competitor callouts unless we accept them **permanently** in metadata, and **any** wording that reads like optional features are default-on.

### `package[:links]` map

- **D-05 (baseline):** Keep **`GitHub`** as canonical source entry (already idiomatic).
- **D-06 (Changelog URL strategy):** **Short term:** `Changelog` may remain **GitHub `blob/main/CHANGELOG.md`** (matches Oban/Swoosh/Plug pattern; low maintenance). **Preferred long term:** migrate `Changelog` to **`https://hexdocs.pm/sigra/changelog.html`** once ExDoc publishes a first-class changelog page per release — matches Phoenix/Ecto/Req/Finch/Joken pattern and reduces “unreleased headings on main” confusion for upgraders. **Rule:** one canonical changelog URL in `links`, not both.
- **D-07 (optional keys):** **`Documentation` → hexdocs** — optional redundancy (Hex UI already surfaces docs); add only if we want an explicit stable landing. **`Issues`** — add only if triage volume warrants a deep link; **not** required by ecosystem norms. **`Sponsor`** — add if sponsorship is active. Use consistent key spelling **`GitHub`** (not `Github`).
- **D-08 (forbidden links):** **No** `.planning/`, internal GA waiver paths, or “evidence dump” URLs in Hex `links`. If something must be public, promote a **purpose-written** doc (e.g. `SECURITY.md`, guides) — not planning archaeology.

### Optional vs core dependencies (how Hex copy reflects reality)

- **D-09 (contract sentence):** Include an explicit **opt-in contract** in the description, e.g. families **supported only when** the host adds the corresponding Hex deps (OAuth/social, mail, Oban workers, rate limiting, bcrypt migration path, JWT helpers, QR/TOTP helpers as applicable). Prefer **integration families** over vendor laundry lists in the Hex string; details live in docs.
- **D-10 (alignment with code):** Metadata must match **`optional: true` in `deps/0`** and compile/runtime guards (`Code.ensure_loaded?`, clear raises, `no_warn_undefined`) — the Hex blurb is the **same contract** the code enforces; no “batteries included” drift (lessons: Swoosh density risk, Ueberauth’s split-package clarity, Assent’s minimal Hex line + xref/docs structure).
- **D-11 (depth outside Hex):** A fuller **table** of feature → dep → notes belongs in **docs/README** (see **55** / installation guides) — not duplicated as a wall in `description`. Phase **53** locks the **Hex sentence-level** honesty; deeper DX is still coordinated with doc phases.

### Maintainers, versioning, announcement-safe coupling

- **D-12 (`:maintainers`):** Hex spec marks **`maintainers` deprecated**. **Prefer omitting** `:maintainers` from `package/0` unless we want legacy display parity — **never** treat it as governance. **Authoritative humans:** `SECURITY.md`, `MAINTAINING.md`, `CONTRIBUTING.md`, **Hex org / multiple `mix hex.owner`** for continuity.
- **D-13 (roadmap “v1.4” vs `@version`):** **Disambiguate in prose everywhere we touch public metadata:** “**Hex `M.M.P`**” vs “**milestone / phase** labels” — never use **`v`-prefixed** milestone names that look like semver unless they equal a **real git tag + `mix` version**. README/changelog posts must not show `{:sigra, "~> 1.4"}` until **1.4.x** exists on Hex.
- **D-14 (release coupling — policy, not automatic bump in this phase):** **Phase 53** delivers **correct metadata text** in-repo. **Bumping `@version`** is a **release event** (follow Hex **0.x** guidance: material / breaking-ish → **minor** on `0.x`). When we **do** publish: **`@version` = CHANGELOG section = `vVERSION` git tag** exists and matches the published SHA; **`source_ref: "v#{@version}"`** must resolve (no 404 “View Source” on hexdocs). If this phase lands **without** a Hex publish, **no version bump is required** for PUB-01 satisfaction — but any **announcement** that implies a new Hex release must ship with that checklist.

### Coherent package story (cross-cutting)

- **D-15 (single editorial system):** Hex `description`, `package[:links]`, and the **first screen** of README/docs must **not contradict** each other — one story: true core, honest optionals, pointers for depth.

### Claude's Discretion

- **None for this context** — research converged on a single coherent package; executor may choose **exact prose** inside the constraints above and run it past maintainer for PUB-01 sign-off.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **PUB-01** (authoritative acceptance text for this phase).
- `.planning/ROADMAP.md` — Phase **53** row (goal + success criteria).
- `.planning/PROJECT.md` — v1.5 milestone intent (public narrative vs shipped reality).

### Implementation surface

- `mix.exs` — `@version`, `description` / `package/0`, `docs/0` (`source_ref`, extras).

### External norms (verify if citing in commits/docs)

- https://hex.pm/docs/publish — Hex publish expectations.
- https://github.com/hexpm/specifications/blob/master/package_metadata.md — tarball metadata spec (`description`, deprecated `maintainers`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- `mix.exs` — `package/0` (`licenses`, `links`, `files`), `deps/0` optional grouping, `elixirc_options` `:no_warn_undefined` documenting optional stacks; `docs/0` with rich `extras` / groups.

### Established patterns

- Optional integrations compiled or guarded behind `Code.ensure_loaded?`; OAuth strategies raise actionable **add Assent** messages — metadata should match that contract.

### Integration points

- Hex.pm package page reads **`mix.exs`** project fields + `package/0`; ExDoc `source_ref` ties published docs “View Source” to git tags matching `@version`.

</code_context>

<specifics>
## Specific Ideas

- Subagent research compared live patterns on Hex for **Phoenix, Ecto, Oban, Swoosh, Assent, Comeonin, wax_**, and cross-ecosystem **npm / Rubygems / Go** norms for security-sensitive libraries: prefer **scope statements** over **assurance marketing**; avoid optional-feature drift in one-line summaries.
- **Long-term polish:** HexDocs-hosted changelog link once `changelog.html` is part of the published doc bundle (cohesive with **54** changelog work — order tasks so link target exists before switching `links`).

</specifics>

<deferred>
## Deferred Ideas

- **Full optional-deps matrix page** and README “GA posture” paragraph — **DOC-01 / DOC-02**, phase **55**.
- **CHANGELOG milestone anchors** — **PUB-02**, phase **54**.
- **Maintainer announcement checklist** — **MAINT-01**, phase **56**.
- **Explicit `mix hex.publish` + version bump + tag** — execute only when maintainers cut a release; phase **53** defines the metadata rules.

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned no matches.

</deferred>

---

*Phase: 53-package-hex-metadata*  
*Context gathered: 2026-04-21*
