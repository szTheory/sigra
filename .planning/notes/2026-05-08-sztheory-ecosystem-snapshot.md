---
date: "2026-05-08 12:00"
promoted: false
---

szTheory ecosystem snapshot as of 2026-05-08 (15 sister libs scanned for Sigra integration angles):

**First-class adapter potential:**
- **mailglass** (v1.0.0) — already declares optional `:sigra` dep at `~> 0.2` (stale). EMAIL-RAILS unlock. See SEED-005, TODO `2026-05-08-cross-repo-mailglass-sigra-constraint`.
- **threadline** (v0.5.0) — already ships `Threadline.Integrations.Sigra` (one-way capture). Reverse adapter `Sigra.Audit.Adapters.Threadline` is the unlock. See SEED-006.

**Doc cross-link only:**
- **accrue** — billing companion; SaaS starter-kit recipe (TODO C1).
- **lockspire** (v1.0.0) — embedded OAuth/OIDC provider; you-as-OAuth-provider pattern (TODO C3).
- **relyra** (v1.1.0) — SAML 2.0 SP for enterprise SSO; recipe (TODO C4).
- **rulestead** (v0.1.0) — feature flags; auth-flow gating recipe (TODO C5).
- **chimeway** (v0.1.0) — durable notifications; future recipe candidate.
- **rendro** — pure-Elixir PDF; pairs with Mailglass for invoice attachments.

**Out of scope (no real fit):**
- **lattice_stripe** (v1.1.0) — Stripe SDK alternative; Accrue is the recommended Stripe pairing for Sigra.
- **scrypath** (v0.3) — Meilisearch/Ecto search; no auth surface.
- **kiln** — agentic dark factory app, not a library.
- **oarlock** — README is a TODO stub.
- **attractor**, **chimeway** (low-priority), **park**, **rendro** (low-priority), **rindle** — out of scope.

Useful as reference if "what's adjacent to Sigra?" gets asked again — saves re-running discovery.
