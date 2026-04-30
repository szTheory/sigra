# Phase 93: M2M / service-account tokens (B2B-03) — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 93-m2m-service-account-tokens-b2b-03
**Areas discussed:** Principal & credentials shape, OAuth endpoint & TTL, Plug integration & revocation, Admin surface & audit naming

---

## Mode of discussion

Per user feedback memories (`feedback_one_shot_decisions.md`, `feedback_research_before_questions.md`, `feedback_discuss_depth.md`): research-driven one-shot. After the user explicitly invoked the preference ("research using subagents, what is pros/cons/tradeoffs of each... think deeply one-shot a perfect set of recommendations"), four parallel `gsd-phase-researcher` agents ran (one per fork) covering Elixir/Phoenix/Plug/Ecto idioms + cross-language successful libs (Devise/Doorkeeper, Spring Security, Django REST Framework, NextAuth, GitLab/GitHub regret stories, Auth0/Okta/AWS/GCP M2M defaults, GitHub Apps, Stripe, Datadog/Sentry/1Password Business audit logs, RFC 6749 / 9068, NIST SP 800-92, SOC 2 / ISO 27001). User-facing AskUserQuestion was issued ONCE for the four genuinely impactful forks; user delegated all four to research-driven synthesis ("for each of these... research using subagents... one-shot a perfect set of recommendations").

---

## Area 1: Service-account principal & credentials shape

### Sub-decision 1A — Schema: separate principal table vs synthetic users

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `service_accounts` table | Industry shape (GitHub Apps, Auth0, Okta); FK to `organizations.id`; org-scoped lifecycle | ✓ |
| Synthetic user row in `users` table | "Bot user" pattern; pollutes `User.list/0`; ambiguous `audit_events.actor_id`; GitLab regret story | |

**Rationale:** GitLab forum thread (#361993, #383882) documents years of patches for the bot-user-rows path. GitHub deliberately migrated AWAY from machine-users to GitHub Apps. Industry-unanimous (GitHub Apps, Auth0 M2M, Okta Service Apps).

### Sub-decision 1B — Credential format: OAuth-native vs PAT-style

| Option | Description | Selected |
|--------|-------------|----------|
| `client_id` + `client_secret` pair (RFC 6749) | OAuth-native; supports Basic auth + form fields; standard SDKs work | ✓ |
| Single PAT-style bearer | Forces non-standard auth mechanism on `/oauth/token` | |

**Rationale:** RFC 6749 §4.4 + §2.3.1 mandate `client_id` + `client_secret` for `client_credentials` grant. Non-conformance breaks every OAuth client SDK adopters might use.

### Sub-decision 1C — `scope.user` shape: nil + service_account_id vs synthetic User

| Option | Description | Selected |
|--------|-------------|----------|
| `scope.user = nil` + new `scope.service_account_id` (tagged-union via `:actor_type`) | Spring Security / Devise+Doorkeeper / GitHub Apps; loud failures (`KeyError` at call sites); compiler-friendly | ✓ |
| Synthetic `%User{}` struct in `scope.user` | Legacy code "works"; but `scope.user.email == nil` silent bugs; GitLab regret | |

**Rationale:** Research consensus: synthetic-user is the documented anti-pattern. Sigra's value prop ("great DX on the rough edges") cuts toward loud failures. Compiler/Dialyzer point at every site that needs the actor_type branch; the nil path is bounded migration cost vs unbounded silent-nil bugs.

### Sub-decision 1D — Credentials lifecycle: single per SA vs separate join table

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `service_account_credentials` join table (multi-credential per SA) | AWS/GCP/Okta unanimous; supports zero-downtime rotation (mint new → deploy → revoke old); one-time schema cost | ✓ |
| Single credential per SA (PAT shape) | Simpler one-table schema; rotation = revoke + recreate (destructive, breaks live consumers) | |

**Rationale:** Migration from "SA = credential" to "SA + credentials" later is a destructive token-epoch reshuffle. Every B2B adopter shipping into a security review hits zero-downtime rotation as a blocker. v1.21 ships the schema correctly; UI polish defers to v1.3+. Doorkeeper (Ruby) issue #1675 documents the exact pain of NOT having this from day one.

---

## Area 2: OAuth `/oauth/token` endpoint & coexistence

### Sub-decision 2A — Endpoint path

| Option | Description | Selected |
|--------|-------------|----------|
| New RFC 6749-shaped `/oauth/token` controller | Canonical RFC path; SDK-friendly; clean separation from existing `/api/auth/token` | ✓ |
| Extend `/api/auth/token` with `grant_type` dispatch | Conflates Sigra-specific email+password JWT with RFC 6749; breaks adopter contract | |

**Rationale:** ROADMAP explicitly says `POST /oauth/token`. Existing `/api/auth/token` is Sigra-shaped (not RFC-conformant); conflation breaks both contracts.

### Sub-decision 2B — Refresh tokens for client_credentials

| Option | Description | Selected |
|--------|-------------|----------|
| No refresh tokens (RFC 6749 §4.4.3 conformance) | Auth0/Okta/AWS/Google all conform; SHOULD NOT issue per spec; client re-POSTs to /oauth/token when JWT expires | ✓ |
| Issue refresh tokens for SA | Spec violation; muddles SA mental model | |

**Rationale:** RFC 6749 §4.4.3 SHOULD NOT. Industry-unanimous conformance.

### Sub-decision 2C — JWT TTL default

| Option | Description | Selected |
|--------|-------------|----------|
| 3600s (1h) with separate `:client_credentials_access_ttl` config | Industry-unanimous (Auth0, Okta, GCP, GitHub, AWS STS all 1h default); halves round-trips vs 900s; 4× lower audit volume | ✓ |
| 900s (15min) match user JWT default | Surprises B2B integrators; no security upside given epoch claim makes revocation atomic regardless | |
| 86400s (24h) Auth0-style permissive | Unusual for security-forward lib; weakens posture without DX upside | |

**Rationale:** 5/6 major M2M platforms default to 3600s. Sigra's per-SA `token_epoch` claim makes the longer TTL safe for revocation (atomic O(1), independent of TTL). Audit volume math favors 1h: 24k rows/day at 1000 SAs vs 96k at 15min.

### Sub-decision 2D — `grant_type` dispatch from day one

| Option | Description | Selected |
|--------|-------------|----------|
| Dispatch on `grant_type`; client_credentials only in v1.21; others return `unsupported_grant_type` | Future-proof; zero v1.21 cost; unlocks `password` grant migration later | ✓ |
| Hardcode client_credentials only | Saves one `case` clause now; forces breaking-change refactor when adding grants | |

**Rationale:** One `case` clause for free; keeps Sigra's RFC 6749 surface honest from day one.

---

## Area 3: Plug integration, scope hydration, revocation

### Sub-decision 3A — FetchBearer fork point

| Option | Description | Selected |
|--------|-------------|----------|
| Fork inside `FetchBearer.do_fetch/2` JWT branch on `claims["actor_type"]` | Single auth entry point honored; one new code path; no parallel pipeline | ✓ |
| New `Sigra.Plug.FetchServiceAccountBearer` plug | Explicitly forbidden by ROADMAP SC #5 | |

**Rationale:** ROADMAP locked.

### Sub-decision 3B — Scope hydration for SA `active_organization`

| Option | Description | Selected |
|--------|-------------|----------|
| Populate directly in FetchBearer from `claims["org_id"]`; skip `Scope.Hydration.hydrate/3` | Hydration is user-membership-shaped; SA has no membership; coupling SA into hydration is leaky | ✓ |
| Extend `Scope.Hydration` with SA branches | Adds actor_type awareness to a user-shaped seam | |

**Rationale:** Cleaner separation; one new code path in FetchBearer vs spreading SA-awareness across hydration.

### Sub-decision 3C — Revocation mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Per-SA `token_epoch` field + per-credential `revoked_at` lookup | Mirrors user epoch pattern; atomic O(1) SA-level revocation; per-credential granularity via revoked_at | ✓ |
| Per-credential `token_epoch` field | Over-engineered; revoked_at lookup is sufficient (credential row loaded anyway) | |
| Pure `revoked_at` lookup (no epoch) | Loses atomic O(1) revocation symmetry with user pattern; no upside | |

**Rationale:** Symmetric with `users.token_epoch`; one column cost; per-credential `revoked_at` provides credential-level granularity without per-credential epoch complexity.

### Sub-decision 3D — `RequireMembership` short-circuit

| Option | Description | Selected |
|--------|-------------|----------|
| Top-of-function guard skips membership check when `actor_type == :service_account` | SA's `organization_id` IS the implicit membership; no synthetic row | ✓ |
| Synthesize fake `%OrganizationMembership{}` for SA requests | Pollutes membership query path with synthetic rows | |

**Rationale:** Mirrors Phase 91 D-91-07's pre-declared `RequireOrgMfa` pattern. Zero membership-query pollution.

### Sub-decision 3E — `scope.role` for SA

| Option | Description | Selected |
|--------|-------------|----------|
| Populate from optional `service_accounts.role :string null` column | Phase 92 RBAC seam reuse; hosts can use existing `can?/3` policies for SAs (e.g., `:ci_bot` role) | ✓ |
| Always nil | Forces hosts to duplicate role logic in actor_type branches; loses Phase 92 reuse | |

**Rationale:** Phase 92's RBAC recipe extends naturally; B2B adopters who want "the CI bot has the deployer role" get it for one nullable column.

### Sub-decision 3F — `RequireOrgMfa` short-circuit (locked from Phase 91 D-91-07)

| Option | Description | Selected |
|--------|-------------|----------|
| Implement Phase 91's pre-declared SA short-circuit | Locked; Phase 93 implements the 3-line guard | ✓ |

**Rationale:** Phase 91 D-91-07 pre-declared this. No discussion needed.

---

## Area 4: Admin surface, sudo, generator wiring, audit naming

### Sub-decision 4A — Admin LiveView placement

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `/organizations/:slug/service-accounts` LiveView | Mirrors `/members` precedent; settings page already crowded post-Phase 91 | ✓ |
| Nest under `/organizations/:slug/settings` | Crowds the settings page (General + Slug + Security + Danger Zone + Service Accounts) | |

**Rationale:** Settings page real-estate is already tight; SAs merit their own surface.

### Sub-decision 4B — Sudo gating

| Option | Description | Selected |
|--------|-------------|----------|
| Sudo on create AND revoke (both SA and credential) | Class-level operations warrant friction; B2B blast-radius justifies | ✓ |
| Sudo on create only (match user PAT pattern) | Revoke is the higher-blast-radius action here (breaks all live consumers) | |

**Rationale:** SA revoke immediately breaks all live consumers (epoch bump). That's the stronger side of the protection ladder.

### Sub-decision 4C — Generator gating

| Option | Description | Selected |
|--------|-------------|----------|
| Both `--organizations` AND `--jwt` required | SA without orgs is meaningless; SA without JWT path is impossible | ✓ |
| New `--service-accounts` opt-in flag | Adopters opt into a feature whose dependencies are already opted-in | |

**Rationale:** Minimum surface; dependencies already declared via existing flags.

### Sub-decision 4D — Audit token issuance

| Option | Description | Selected |
|--------|-------------|----------|
| Audit `service_account.token_issued` per successful issuance | Industry-unanimous (GitHub, Auth0, AWS, Stripe, Datadog, 1Password); SOC 2 evidence requirement; D-27 not violated (issuance ≠ verify hot-path) | ✓ |
| No success audit (mirror D-27 verbatim) | Compliance-incomplete; "show me when SA-X was exchanged" can't be answered | |

**Rationale:** B2B-trust framing of v1.21 wants production-honest audit. D-27 stays for verifies; new D-93-20 documents the asymmetry. Storage cost trivial (~650 MB/year at 1000 SAs with 90-day retention).

### Sub-decision 4E — Audit verb canonicalization

| Option | Description | Selected |
|--------|-------------|----------|
| Present-tense (`service_account.create`, `service_account.revoke`); surgical ROADMAP edit | Matches `lib/sigra/organizations.ex` precedent; mirrors Phase 91 D-91-12 maneuver | ✓ |
| Honor ROADMAP past-tense wording (`service_account.created`, `.revoked`) | Inconsistent with org-action verbs; would surprise audit-query writers | |

**Rationale:** Codebase consistency wins; Phase 91 D-91-12 set precedent for this exact maneuver.

---

## Claude's Discretion (delegated to planner)

- Exact NimbleOptions schema field names (`:client_credentials_access_ttl` vs alternatives).
- Exact `client_id` byte count (16 vs 24 vs 32 base64url chars after the `sigra_sa_` prefix).
- Whether to add `aud` (audience) claim per RFC 9068 — symmetry with user JWTs vs RFC 9068 conformance.
- Stable error atom names (`:service_account_aborted` etc.).
- LiveView component composition for SA detail / credentials sub-panel.
- Whether SA detail is a route or a modal.
- Whether the recipe lives at `m2m-service-accounts.md` vs `client-credentials.md`.
- Whether `Sigra.Scope.user_id/1` helper lives on the library `Sigra.Scope` or generated host scope module.
- Whether `Sigra.ServiceAccounts` is top-level or `Sigra.Organizations.ServiceAccounts` (lean: top-level).
- Whether `/oauth/token` route lives in core router_injection or organizations router_injection (lean: core).

## Deferred Ideas

(Captured in CONTEXT.md `<deferred>`. Highlights:)

- Other RFC 6749 grant types (`password`, `authorization_code`, etc.) — future v1.x phases.
- Migrating `/api/auth/token` under `/oauth/token grant_type=password` — future evaluation.
- Multi-credential UI polish (rotation reminders, expiration warnings) — v1.3+.
- SA-to-SA delegation / impersonation — out of v1.21 scope.
- PKCE / proof-of-possession for SA — RFC 8705 mTLS-bound tokens upgrade path if demand.
- `aud` claim per RFC 9068 — separate "JWT spec compliance" follow-up phase if needed.
- Per-credential `token_epoch` field — over-engineered for v1.21.
- Webhooks for SA lifecycle events — v1.22 webhooks milestone.
- SA-authenticated LiveView (websocket bearer auth) — separate phase if demand.
- GitHub-style fine-grained token expiration policies — future adoption cue.
