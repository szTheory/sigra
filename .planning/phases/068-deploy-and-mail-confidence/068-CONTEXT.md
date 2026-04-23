# Phase 68: Deploy and mail confidence - Context

**Gathered:** 2026-04-23  
**Status:** Ready for planning  
**Source:** `/gsd-discuss-phase 68 --all` with parallel research synthesis (no interactive Q&A).

<domain>

## Phase boundary

Ship **ACF-01** and **ACF-04**: maintainer-facing docs so a **public** Phoenix host configures **HTTPS / reverse proxy / session cookies** predictably, and understands **Oban-backed vs inline Swoosh** before load surprises — with checklist discoverable from maintainer **or** intro paths per roadmap success criteria. No new runtime behavior; docs and cross-links only.

</domain>

<decisions>

## Implementation decisions

### 1. Doc placement (session / HTTPS / proxy)

- **D-01:** **Single canonical how-to** remains `guides/recipes/deployment.md`. Do **not** put the adopter production checklist body in `MAINTAINING.md` (maintainer = ship the library; adopters bounce there for Hex/CI, not first prod).
- **D-02:** Add an **above-the-fold** section at the **top** of `deployment.md` (immediately after the intro paragraph): **`## Production checklist (read first)`** — scannable in under two minutes, before the long env-var tables. Keeps **one URL** for the link mesh (`deployment.html#production-checklist`).
- **D-03:** **Rationale:** Diátaxis fit (how-to in recipes); avoids duplicate truths across README / intro / maintainer; matches Phoenix ecosystem (deployment narrative in guides, not root maintainer file). Optional later split to `production-checklist.md` only if `deployment.md` grows unwieldy — **not** required for phase 68.

### 2. Checklist shape and depth (ACF-01)

- **D-04:** Use a **hybrid**: short **verification table** (columns: **Check** | **Why (one line)** | **Knob / where**) covering public origin, forwarded HTTPS, redirect loops, `Endpoint` `url:` scheme/host/port, `Plug.Session` (`secure`, `SameSite`, domain), LiveView/WebSocket `check_origin` / Origin alignment, staging hosts — **8–12 rows max**.
- **D-05:** Follow with a **triage box** (4 bullets: symptom → likely misconfiguration class: proto vs `url:` vs `check_origin` vs cookie flags).
- **D-06:** **Link out** to Phoenix / Plug hexdocs for mechanics (`Phoenix.Endpoint`, `Plug.Session`, deployment guides); **inline** only Sigra-specific invariants (generated `UserAuth` / cookie_domain warning, sync with `COOKIE_DOMAIN` already documented).
- **D-07:** **Do not** inline full nginx/Fly/k8s configs in the checklist matrix — keep Fly/Gigalixir as **optional subsections** below (already present); matrix stays **terminator-agnostic** with one row naming forwarded proto responsibility.

### 3. Mail semantics — Oban vs inline (ACF-04)

- **D-08:** Document **inline as default / zero-deps onboarding**; **Oban as the recommended production path** for deliverability, retries, backpressure, and observability — align prose with existing **"Strongly prefer Oban in production"** in `deployment.md` without pretending two paths are equal.
- **D-09:** Add a **TL;DR decision tree** (3–5 bullets) directly under the production checklist or at the start of **`## Oban for background jobs`**: dev/test → adapter; tiny single-node conscious tradeoff → inline acceptable; remote SMTP / multi-instance / burst / SLA → Oban; cite **at-least-once** and **double-send on retry** footgun in one sentence + pointer to token/idempotency patterns (no full Oban manual).
- **D-10:** **Install flags:** single table or bullet row in **Installation** + **deployment** cross-link — `mix sigra.install` options that affect mail/oban (exact flags from codebase / `mix help sigra.install` when implementing). **Example app:** canonical pointer is **`test/example/`** (generated host under CI) for “what we ship and test”; say explicitly that it reflects the **recommended** Oban wiring when flags enabled.
- **D-11:** **Do not** duplicate Oban’s full documentation — link `https://hexdocs.pm/oban` for queues, supervision, Oban Web; keep Sigra-specific worker names, queues, and cron snippets as **already in** `deployment.md`.

### 4. Cross-linking and discovery

- **D-12:** **Hub + thin repeat:** five inbound **one-sentence + one-link** pointers to the same anchor `guides/recipes/deployment.md#production-checklist` (or equivalent ExDoc fragment):
  1. `README.md` — short “Before production” strip in topic map area.
  2. `guides/introduction/getting-started.md` — **end** of doc (after happy path), not top banner.
  3. `guides/introduction/first-hour.md` — reading map or post-checklist handoff.
  4. `guides/introduction/installation.md` — near mailer / “prod differs from dev”.
  5. `MAINTAINING.md` — single breadcrumb: releases do not validate host TLS/mail; adopters complete deployment checklist in guides (no duplicated table).
- **D-13:** **ExDoc discoverability:** H2 title uses words adopters search (**production**, **checklist**, **HTTPS**, **session**, **mail**). Reading-map banners stay **navigational** — no second copy of the env table.

### Coherence note

Placement (hub in `deployment.md`), shape (matrix + triage), mail (Oban-recommended decision tree + flags + example), and links (five thin on-ramps) are **one system**: one procedural truth, many discoverability paths, zero parallel spec copies.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and scope

- `.planning/REQUIREMENTS.md` — **ACF-01**, **ACF-04**
- `.planning/ROADMAP.md` — Phase 68 goals and success criteria
- `.planning/v1.10-ADOPTER-SCOPE.md` — assumed production bundle (sessions, HTTPS, proxy, mail)

### Existing docs to extend (not replace)

- `guides/recipes/deployment.md` — canonical hub; env, cookies, Oban, platforms
- `guides/introduction/getting-started.md` — tutorial; footer link only
- `guides/introduction/first-hour.md` — intermediate path precursor
- `guides/introduction/installation.md` — install / mailer context
- `README.md` — topic map
- `MAINTAINING.md` — maintainer audience; single adopters pointer only

### Example / install truth

- `test/example/` — CI-backed generated host (pointer for “install output we test”)
- `lib/sigra/install/` — install flags and Oban/mail injection behavior (verify exact CLI strings during implementation)

### External (link, do not fork)

- `https://hexdocs.pm/phoenix/deployment.html` — Phoenix deployment
- `https://hexdocs.pm/phoenix/Phoenix.Endpoint.html` — `url:`, `check_origin`
- `https://hexdocs.pm/plug/Plug.Session.html` — session cookie options
- `https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html` — cookie attribute grounding
- `https://hexdocs.pm/oban` — Oban installation and operations

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- `guides/recipes/deployment.md` — env table, Sigra cookie note, Phoenix session snippet, Oban config block, Fly/Gigalixir secrets — extend, do not rewrite from scratch.
- `guides/introduction/getting-started.md` — reading map pattern at top; mirror **light** pointer at bottom for prod handoff.
- `test/example/` — reference app for ACF-04 “example pointers.”

### Established patterns

- Diátaxis-style split already implicit: intro tutorials vs `guides/recipes/deployment.md` how-to.
- Maintainer vs adopter split: `MAINTAINING.md` is release/CI/Nyquist, not host runbooks.

### Integration points

- `mix.exs` ExDoc `extras` — ensure new heading/anchor is linkable; ordering secondary to explicit cross-links.
- Phase **69** will add intermediate narrative and optional-feature index — phase 68 links must **not** steal ACF-02/03 scope.

</code_context>

<specifics>

## Specific ideas

- Subagent research consensus: **distributed discovery, centralized truth** beats hub-only or seven duplicated truths; **matrix-first** checklist for multi-platform readers; **Oban-first for production** messaging with honest inline default; cross-framework footguns = scheme/host/`check_origin`/forwarded proto/cookie attribute drift.

</specifics>

<deferred>

## Deferred ideas

- Dedicated standalone `guides/recipes/production-checklist.md` — defer unless `deployment.md` exceeds comfortable scan length after phase 68 edits.
- Full mail-focused guide (`email-delivery.md`) — defer unless Oban/mail sections become too large in one file; phase 69 dogfood doc may absorb narrative overlap — revisit during plan if needed.

**Out of scope:** ACF-02, ACF-03 (phase 69); ACF-05, ACF-06 (phase 70); new auth primitives.

</deferred>

---

*Phase: 68-deploy-and-mail-confidence*  
*Context gathered: 2026-04-23*
