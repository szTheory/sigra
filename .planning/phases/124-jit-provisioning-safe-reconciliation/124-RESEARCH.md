# Phase 124: JIT Provisioning & Safe Reconciliation - Research

**Researched:** 2026-05-25
**Domain:** Enterprise OIDC callback reconciliation, membership provisioning, and first-session organization truth in Elixir/Phoenix [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: lib/sigra/auth.ex]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Enterprise reconciliation resolves in this order: existing enterprise identity for the routed connection and provider subject, bounded existing-user auto-claim, then brand-new JIT user creation. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-02:** Bounded auto-claim is allowed only when enterprise callback context is already revalidated, the IdP returned a verified email, normalized email matches exactly one Sigra user, and no conflicting enterprise identity or duplicate plausible match exists. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-03:** Sigra must never silently claim an existing account by email alone when ownership is ambiguous. Any cross-principal conflict fails closed and visibly. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-04:** Enterprise identity ownership is keyed to the routed enterprise connection plus stable provider subject; email is supportive evidence, not the durable identity anchor. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-05:** Once the user principal is resolved safely, reuse existing membership if present, consume an exact pending invite if present, otherwise create a new organization membership just in time. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-06:** Exact pending invite consumption requires the same resolved organization and exact normalized email match. Invites are weaker than the authenticated enterprise identity and must not override org routing. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-07:** Default JIT-created membership role is `:member`. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-08:** Membership reconciliation must reuse the current org and invitation substrate rather than bypassing it with enterprise-specific side paths. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-09:** Fail closed on enterprise callback context mismatch, stale or unavailable routed connection, provider subject to user A plus email to user B conflict, duplicate plausible local matches, or any case that would require silent email-only account linking. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-10:** Future inactive membership states, if introduced later, must deny access rather than auto-reactivating on login. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-11:** Failure reasons should be bounded and typed for code and audit purposes, while end-user copy stays truthful and non-leaky on generic surfaces. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-12:** No enterprise callback failure path should silently downgrade into password, magic-link, or passkey login inside the same flow. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-13:** User resolution, membership reconciliation, invite consumption, and enterprise-auth audit emission must complete before the final signed-in session is created. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-14:** The first successful signed-in session row and first related audit row must already carry the resolved `active_organization_id` and enterprise connection truth. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-15:** Reconciliation must be atomic and idempotent. Use DB constraints plus transactional recovery rather than pre-check-only logic. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-16:** Reconciliation outcomes should be explicit and machine-readable, such as `existing_membership`, `invitation_consumed`, `jit_created`, and typed refusal atoms. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-17:** On safe success, honor a sanitized local `return_to` first, but only when it is compatible with the resolved organization context. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-18:** If there is no valid `return_to`, use a host-owned post-sign-in fallback destination. In the current example app, that fallback should be `/organizations`, not organization settings. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-19:** Do not show an interstitial on ordinary success. Show lightweight confirmation only when something materially changed, such as first JIT membership creation or active-org switch. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-20:** If reconciliation is ambiguous or unsafe, do not create a normal signed-in session. Route to a bounded recovery or fixup surface instead. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-21:** Prefer researched decisive recommendations and only escalate future discuss-phase questions when they materially change the security model, public contract, generated-host contract, or proof/truth claims. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- **D-22:** For enterprise auth decisions, default to exact normalized identifiers, explicit org truth, fail-closed ambiguity handling, and library-owned transactional correctness over convenience heuristics. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

### Claude's Discretion
- Exact module and function names for the reconciliation seam, as long as account resolution, membership writes, and session creation remain clearly ordered and library-owned. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- Exact audit action names and metadata key names, as long as they preserve explicit enterprise outcome truth. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- Exact host-level confirmation or recovery copy and template layout, as long as success stays low-friction and unsafe outcomes do not masquerade as a completed sign-in. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- Configurable preprovision-only mode that denies JIT membership creation for orgs that want stricter operator approval. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- Heavier post-success branded org handoff or enterprise-specific dashboard UX. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- Operator-configurable membership role mapping beyond default `:member`. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- SCIM-driven lifecycle reconciliation and deprovisioning. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- SSO-only enforcement, break-glass policy, and richer diagnostics beyond the bounded Phase 124 posture. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SSO-04 | Successful enterprise login signs the user into the correct organization and preserves Sigra's existing session and audit truth. | Reconcile org membership before `Sigra.Auth.create_session/4`, pass explicit `active_organization_id` in session metadata, and keep controller logic limited to cookie/session-token issuance. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] |
| JIT-01 | Enterprise login can provision or reconcile organization membership just in time without bypassing the existing org invariants. | Reuse `Sigra.Organizations.add_member_multi/5`, the existing membership uniqueness constraint, and the invitations subsystem instead of adding an enterprise-only membership writer. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: test/example/lib/example/accounts/organization_membership.ex] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs] |
| JIT-02 | Ambiguous enterprise identity matches fail safely instead of silently linking the wrong account. | Keep provider subject plus routed enterprise connection as the durable identity anchor, require verified normalized email for bounded auto-claim, and return typed refusal outcomes on duplicate or conflicting matches. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- The blessed path is Phoenix `1.8+` with Ecto `3.x`. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary database, with `citext` and JSONB expected on the primary path. [VERIFIED: CLAUDE.md]
- Security posture must follow OWASP-oriented defaults, with enumeration prevention already treated as a baseline invariant. [VERIFIED: CLAUDE.md]
- Keep transitive dependencies minimal; Phase 124 should prefer existing Sigra/Ecto seams over adding a new dependency. [VERIFIED: CLAUDE.md] [VERIFIED: mix.exs]
- Login and logout are expected to stay on HTTP controller paths, not move into LiveView event handlers. [VERIFIED: CLAUDE.md] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]
- Testing should stay comprehensive and flat, covering happy path, main error cases, and boundary conditions. [VERIFIED: CLAUDE.md]
- Local test execution expects PostgreSQL at `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs]
- No repo-root `AGENTS.md` exists in this workspace; only `test/example/AGENTS.md` exists under a fixture subtree and is not a repo-level instruction file. [VERIFIED: codebase grep]
- No project-local skills were found under `.claude/skills/` or `.agents/skills/`. [VERIFIED: codebase grep]

## Summary

Sigra already has the right primitives for this phase: routed enterprise callback context is validated in `Sigra.OAuth.Callback`, membership inserts are exposed as a pure `Ecto.Multi` builder in `Sigra.Organizations.add_member_multi/5`, and `Sigra.Auth.create_session/4` already supports explicit `active_organization_id` so the first persisted session and audit row can carry organization truth immediately. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/auth.ex]

The missing work is the reconciliation seam between identity lookup and session creation. The planner should treat Phase 124 as a library-owned transaction-composition phase, not a controller phase: resolve the principal, reconcile membership against existing membership or an exact pending invite, emit typed enterprise outcome truth, and only then create the normal session in the host controller. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]

The strongest implementation fit is one dedicated reconciliation module called from `Sigra.OAuth.Callback.process_callback/5` after enterprise context validation succeeds. That module should build one `Ecto.Multi` using DB constraints and transactional recovery for idempotency, because Ecto’s current guidance is to compose dependent writes in a transaction and rely on database constraints instead of pre-check-only validation for race-sensitive uniqueness. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]

**Primary recommendation:** Add a library-owned `Sigra.OAuth.EnterpriseReconciliation`-style seam that returns `{user, active_organization_id, enterprise_outcome}` before `Sigra.Auth.create_session/4`, and make the example controller honor sanitized `return_to` or `/organizations` after session issuance. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enterprise callback context validation | API / Backend | Frontend Server | The current OIDC callback safety checks already live in `Sigra.OAuth.Callback`, while the Phoenix controller only delegates and surfaces flashes. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] |
| Principal resolution by enterprise identity and verified email | API / Backend | Database / Storage | The durable anchor is provider subject plus routed connection, and the only safe auto-claim decision requires DB lookups for identity and exact local-user matches. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex] |
| Membership reuse / invite consumption / JIT creation | API / Backend | Database / Storage | Existing membership and invite invariants are encoded in Sigra library contexts and backed by DB uniqueness constraints. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/organizations/invitations.ex] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs] |
| First session row and audit truth | API / Backend | Database / Storage | `Sigra.Auth.create_session/4` already delays `session.create` audit emission until after active-org assignment, which is the correct owner for first-session truth. [VERIFIED: lib/sigra/auth.ex] |
| Post-success redirect and recovery UI | Frontend Server | API / Backend | Redirect targets, flashes, and bounded recovery pages are controller/host responsibilities, but they must consume typed results from the library. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto | `3.13.5` locked, `3.14.0` current | Transaction composition and constraint-aware failure handling for reconciliation. [VERIFIED: mix.lock] [VERIFIED: mix hex.info ecto] | The phase needs one transaction across identity, membership, invitation, and audit writes; `Ecto.Multi` and `Repo.transact/2` are the official fit. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Ecto SQL | `3.13.5` locked | Backing adapter layer for the repo and migrations that already enforce membership and invitation uniqueness. [VERIFIED: mix.lock] [VERIFIED: mix.exs] | The planner should lean on existing DB indexes and constraints rather than duplicate-app logic. [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] |
| Phoenix | `1.8.5` locked, `1.8.7` current | Controller/session/redirect surface for enterprise callback completion. [VERIFIED: mix.lock] [VERIFIED: mix hex.info phoenix] | The controller already owns cookie session renewal and redirect behavior; Phase 124 should preserve that split. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| Assent | `0.3.1` locked and current | OIDC callback/user-info/token exchange substrate already used by enterprise login. [VERIFIED: mix.lock] [VERIFIED: mix hex.info assent] | The OIDC strategy is already in place; Phase 124 is about safer post-callback reconciliation, not changing the OIDC client layer. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Organizations.add_member_multi/5` | repo HEAD | Pure membership insert builder that can be appended into a parent `Ecto.Multi`. [VERIFIED: lib/sigra/organizations.ex] | Use for JIT membership creation after principal resolution succeeds and no reusable membership or exact invite applies. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| `Sigra.Auth.create_session/4` | repo HEAD | Persists the first normal session and emits `session.create` after active-org assignment. [VERIFIED: lib/sigra/auth.ex] | Use only after reconciliation has produced explicit `active_organization_id` and enterprise outcome metadata. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| `Sigra.Organizations.Invitations` | repo HEAD | Existing invite semantics and mismatch posture for organization onboarding. [VERIFIED: lib/sigra/organizations/invitations.ex] | Extend or compose it for exact invite consumption; do not create an enterprise-only invite path. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Library-owned reconciliation Multi | Controller-owned post-callback writes | Reject this; it would split security truth across controller and library and makes first-session/audit truth harder to guarantee. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] |
| Existing org/invite substrate | Enterprise-only membership writer | Reject this; current decisions explicitly require reusing membership and invitation invariants. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| Provider-subject + routed-connection anchor | Email-only account linking | Reject this; current callback code already blocks cross-account conflicts and the phase decisions require fail-closed ambiguity handling. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |

**Installation:**
```bash
# No new Mix dependencies are required for Phase 124.
```

**Version verification:** The repo already resolves `ecto 3.13.5`, `phoenix 1.8.5`, and `assent 0.3.1`; `mix hex.info` shows current releases `ecto 3.14.0` on 2026-05-19, `phoenix 1.8.7` on 2026-05-06, and `assent 0.3.1` on 2025-06-20, so Phase 124 can plan against the current locked stack without a dependency upgrade. [VERIFIED: mix.lock] [VERIFIED: mix hex.info ecto] [VERIFIED: mix hex.info phoenix] [VERIFIED: mix hex.info assent]

## Architecture Patterns

### System Architecture Diagram

```text
Enterprise entry page
  -> ExampleWeb.EnterpriseSSOController.create
  -> Sigra.OAuth.authorize_url
  -> IdP authorize + callback
  -> ExampleWeb.EnterpriseSSOController.callback
  -> Sigra.OAuth.handle_callback
  -> Sigra.OAuth.Callback.process_callback
      -> validate routed enterprise context
      -> reconcile principal
          -> existing identity for (connection, provider subject)?
          -> else exact single verified-email auto-claim?
          -> else brand-new user?
      -> reconcile org membership
          -> existing membership?
          -> else exact pending invite?
          -> else add_member_multi(:member)
      -> emit typed enterprise outcome + session metadata
  -> Sigra.Auth.create_session
      -> persist session with explicit active_organization_id
      -> emit first session.create audit row
  -> controller redirect
      -> sanitized return_to compatible with resolved org
      -> else /organizations
```

The diagram above follows the existing separation between library-owned auth truth and host-owned redirect/copy surfaces. [VERIFIED: lib/sigra/oauth.ex] [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]

### Recommended Project Structure
```text
lib/
├── sigra/
│   ├── oauth/
│   │   ├── callback.ex
│   │   └── enterprise_reconciliation.ex
│   ├── organizations.ex
│   └── organizations/
│       └── invitations.ex
test/
├── sigra/
│   └── oauth/
│       ├── enterprise_callback_test.exs
│       └── enterprise_reconciliation_test.exs
test/example/test/
├── example_web/controllers/
│   └── enterprise_sso_controller_test.exs
└── example_web/integration/
    └── enterprise_sso_reconciliation_flow_test.exs
```

Add a new reconciliation module only if it remains library-owned and narrow. Reusing `callback.ex` is acceptable for wiring, but planner tasks should keep the actual decision tree factored out for testability. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex]

### Pattern 1: Reconcile Before Session Issuance
**What:** Resolve user, identity ownership, membership outcome, and enterprise audit metadata before calling `Sigra.Auth.create_session/4`. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/auth.ex]

**When to use:** Every successful enterprise callback path. [VERIFIED: .planning/REQUIREMENTS.md]

**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
# Source: lib/sigra/auth.ex
with {:ok, result} <- EnterpriseReconciliation.reconcile(config, provider, user_info, token, enterprise_context),
     {:ok, session} <- Sigra.Auth.create_session(config, result.user, result.session_metadata, []) do
  {:ok, result.outcome, result.user, session}
end
```

### Pattern 2: Compose Pure Multi Builders
**What:** Use `Ecto.Multi.append/2`, `Ecto.Multi.merge/2`, and `run/3` to compose identity work, invite consumption, and membership creation without side effects before the transaction starts. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [VERIFIED: lib/sigra/organizations.ex]

**When to use:** When a branch needs a previously resolved user or organization to decide which org write path applies. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
# Source: lib/sigra/organizations.ex
Ecto.Multi.new()
|> Ecto.Multi.run(:resolved_user, fn _repo, _changes -> resolve_user(...) end)
|> Ecto.Multi.merge(fn %{resolved_user: user} ->
  reconcile_membership_multi(config, org, user, normalized_email)
end)
|> config.repo.transact()
```

### Pattern 3: Let the Database Own Idempotency
**What:** Use unique indexes and `unique_constraint/3` as the source of truth for identity and membership deduplication, then map those failures to typed refusal or recovery outcomes. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] [VERIFIED: priv/templates/sigra.gen.oauth/oauth_migration.exs] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs]

**When to use:** Every branch that can race with another enterprise callback or invite acceptance. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/constraints-and-upserts.html
changeset
|> Ecto.Changeset.unique_constraint([:user_id, :organization_id])
```

### Anti-Patterns to Avoid
- **Session first, membership later:** This violates D-13 and D-14 because `Sigra.Auth.create_session/4` emits `session.create` after active-org assignment; creating the session before reconciliation would make the first audit/session row wrong. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/auth.ex]
- **Email-only silent linking:** Current enterprise decisions and current OAuth conflict posture both reject this. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex]
- **Enterprise-specific membership side path:** The planner should not create a separate write path that ignores `organization_memberships` or invitation semantics. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/organizations/invitations.ex]
- **Running example tests without `--include example_app`:** They default to excluded and will report zero failures while exercising nothing. [VERIFIED: test/example/test/test_helper.exs] [VERIFIED: command output]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-step transaction orchestration | Manual nested transaction branches | `Ecto.Multi` + `Repo.transact/2` | This is the official Ecto pattern for dependent writes and explicit rollback surfaces. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Membership dedupe | In-memory “check then insert” guard | Existing membership unique index and `unique_constraint/3` | Ecto’s guidance is to let the DB enforce uniqueness because concurrent validations can race. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs] |
| Enterprise invite semantics | New enterprise-only invite table or direct stamp fields | Extend/reuse `Sigra.Organizations.Invitations` and its exact-match semantics | The phase explicitly requires invite reuse, not bypass. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/organizations/invitations.ex] |
| First-session org assignment | Controller-side session patch-up | `Sigra.Auth.create_session/4` with explicit `active_organization_id` metadata | That path already owns first-session audit truth. [VERIFIED: lib/sigra/auth.ex] |
| OIDC callback/session state | Custom callback client | Existing Assent + `Sigra.OAuth` authorize/callback flow | This phase is downstream of OIDC exchange, not a client rewrite. [VERIFIED: lib/sigra/oauth.ex] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |

**Key insight:** Phase 124 is mostly about composing existing trusted primitives in the right order; the main risk is bypassing them, not lacking them. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/auth.ex]

## Common Pitfalls

### Pitfall 1: Auto-Claiming Against a Soft-Deleted or Non-Normalized User Row
**What goes wrong:** A bounded auto-claim branch uses a raw email lookup and can accidentally consider rows that should be ignored or compare on an unnormalized identifier. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: test/example/lib/example/accounts/user.ex]

**Why it happens:** The current generic OAuth callback path does `repo.get_by(user_schema, email: email)` directly, while the example user schema includes `deleted_at` and normalizes email in changesets rather than in query defaults. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: test/example/lib/example/accounts/user.ex]

**How to avoid:** Make enterprise auto-claim use exact normalized email and explicitly exclude non-eligible rows in the reconciliation query. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

**Warning signs:** A duplicate or deleted user record still satisfies the auto-claim lookup, or tests only cover happy-path exact matches. [VERIFIED: lib/sigra/oauth/callback.ex]

### Pitfall 2: Using Pre-Checks Without Constraint-Aware Recovery
**What goes wrong:** Two near-simultaneous enterprise callbacks can both “see no membership” and both try to insert. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs]

**Why it happens:** Application validations are not sufficient for concurrent uniqueness decisions. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]

**How to avoid:** Let the membership and identity unique indexes reject duplicates and translate those failures inside the same reconciliation transaction. [VERIFIED: priv/templates/sigra.gen.oauth/oauth_migration.exs] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs]

**Warning signs:** The design relies on `if existing == nil do insert` without a matching DB uniqueness branch. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]

### Pitfall 3: Continuing Work After a Failed DB Step Inside One Transaction
**What goes wrong:** After a constraint failure, later DB operations in the same transaction can raise because the transaction is already aborted. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**Why it happens:** `Repo.transact/2` aborts the transaction after a failed operation such as a unique-constraint violation. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**How to avoid:** Encode the reconciliation as `Ecto.Multi` steps or early `{:error, reason}` branches instead of rescuing inside a transaction and then continuing to issue writes. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**Warning signs:** Transaction code tries a second insert/update after matching on `{:error, changeset}` from a failed insert. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

### Pitfall 4: Leaving Redirect Truth in the Old Enterprise Success Path
**What goes wrong:** A correct reconciliation still lands the user on organization settings because the controller retains its current hardcoded redirect. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

**Why it happens:** The example controller currently redirects success to `"/organizations/:slug/settings"` and does not yet consult `user_return_to` or a Phase-124-compatible fallback. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex]

**How to avoid:** Add a sanitized org-compatible `return_to` check, then fall back to `/organizations` in the example app. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

**Warning signs:** Controller tests only assert “session exists” and never assert the final redirect target after reconciliation outcomes. [VERIFIED: test/example/test/example_web/controllers/enterprise_sso_controller_test.exs]

## Code Examples

Verified patterns from official sources and the current codebase:

### Compose Dependent Writes with `Ecto.Multi.merge/2`
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.run(:resolved_user, fn _repo, _changes ->
    resolve_enterprise_user(...)
  end)
  |> Ecto.Multi.merge(fn %{resolved_user: user} ->
    reconcile_membership_multi(config, org, user, normalized_email)
  end)

config.repo.transact(multi)
```

### Reuse Existing Membership Builder Instead of Direct Inserts
```elixir
# Source: lib/sigra/organizations.ex
Sigra.Organizations.add_member_multi(
  org_config,
  scope,
  organization,
  {:changes_key, :resolved_user},
  :member
)
```

### Create the First Session with Explicit Organization Truth
```elixir
# Source: lib/sigra/auth.ex
Sigra.Auth.create_session(config, user, %{
  type: :remember_me,
  auth_method: :oauth,
  provider: :oidc,
  active_organization_id: organization.id,
  enterprise_connection_id: connection.id,
  enterprise_routing_source: routing_source
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Email-match prompt for every existing local account | Enterprise-only bounded auto-claim when callback context is revalidated, email is verified, and the normalized match is unique. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] | Phase 124 decisions on 2026-05-25. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] | Low-friction enterprise login without silent takeover. [VERIFIED: .planning/REQUIREMENTS.md] |
| Fix org scope after login | Write `active_organization_id` into the first successful session metadata before `session.create` audit emission. [VERIFIED: lib/sigra/auth.ex] | Already present in current `Sigra.Auth.create_session/4`. [VERIFIED: lib/sigra/auth.ex] | Phase 124 should plug into this path rather than invent a second one. [VERIFIED: lib/sigra/auth.ex] |
| Pre-check then insert | DB constraints plus transactional failure handling. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] | Current Ecto guidance. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] | Safer idempotency under concurrent enterprise callbacks. [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] |
| Controller/business-logic mixing | Thin controller + library-owned reconciliation and audit truth. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: lib/sigra/auth.ex] | Current Sigra architecture. [VERIFIED: CLAUDE.md] [VERIFIED: lib/sigra/auth.ex] | Keeps generated-host code legible while preserving security patchability. [VERIFIED: CLAUDE.md] |

**Deprecated/outdated:**
- Silent email-only linking for enterprise login is out of bounds for this phase. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- A hardcoded enterprise success redirect to organization settings is outdated for the planned Phase 124 UX posture. [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex] [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|

All claims in this research were verified or cited during this session. [VERIFIED: this document]

## Open Questions (RESOLVED)

1. **What exact generated-host recovery surface should typed reconciliation refusals use?**
   - Resolution: use the existing org-scoped enterprise entry surface as the bounded recovery path, with typed refusal outcomes returning to the organization-aware enterprise controller flow rather than creating a separate recovery page. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]
   - Why: this keeps unsafe outcomes inside the same enterprise mode per D-12 and D-20, avoids a misleading post-success surface, and lets the generated host show truthful low-leak flash copy on a route the user already trusts. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
   - Planning implication: Plan `124-03` should update the example app so typed refusal codes route back through the org-scoped enterprise entry or retry surface, assert no `:user_token` is created, and reserve `/organizations` for safe success fallback only. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-03-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Root and example test execution | ✓ | `1.19.5` | — [VERIFIED: command output] |
| Mix | Root and example test execution | ✓ | `1.19.5` | — [VERIFIED: command output] |
| PostgreSQL on `localhost:5432` | Local tests and example app tests | ✓ | `14.17` client; `pg_isready` reports accepting connections | Use the documented Docker one-liner if the local server disappears. [VERIFIED: command output] [VERIFIED: CLAUDE.md] |
| Docker | Disposable Postgres fallback | ✓ | `29.4.1` | — [VERIFIED: command output] |
| Live OIDC provider | Manual exploratory testing only | Not required | — | Mocks already cover callback and controller tests. [VERIFIED: test/sigra/oauth/enterprise_callback_test.exs] [VERIFIED: test/example/test/example_web/controllers/enterprise_sso_controller_test.exs] |

**Missing dependencies with no fallback:**
- None for planning or automated local validation. [VERIFIED: command output]

**Missing dependencies with fallback:**
- None at research time. [VERIFIED: command output]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit in both the root library and the example Phoenix subproject. [VERIFIED: test/test_helper.exs] [VERIFIED: test/example/test/test_helper.exs] |
| Config file | `test/test_helper.exs` and `test/example/test/test_helper.exs`; no separate `ex_unit.exs` or `pytest`-style config file. [VERIFIED: test/test_helper.exs] [VERIFIED: test/example/test/test_helper.exs] |
| Quick run command | `mix test test/sigra/oauth/enterprise_callback_test.exs` [VERIFIED: command output] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` and `cd test/example && MIX_ENV=test mix test --include example_app` [VERIFIED: CLAUDE.md] [VERIFIED: test/example/test/test_helper.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SSO-04 | Successful enterprise login creates a session with the resolved org and lands in the correct post-sign-in surface. [VERIFIED: .planning/REQUIREMENTS.md] | controller + integration | `cd test/example && mix test --include example_app test/example_web/controllers/enterprise_sso_controller_test.exs` [VERIFIED: command output] | ✅ existing, but redirect expectation must change for Phase 124. [VERIFIED: test/example/test/example_web/controllers/enterprise_sso_controller_test.exs] |
| JIT-01 | Reuse existing membership, consume exact pending invite, or create a new membership with the current org substrate. [VERIFIED: .planning/REQUIREMENTS.md] | library integration | `mix test test/sigra/oauth/enterprise_reconciliation_test.exs` | ❌ Wave 0 |
| JIT-02 | Ambiguous enterprise identity matches fail with no normal session and a typed refusal outcome. [VERIFIED: .planning/REQUIREMENTS.md] | library + controller | `mix test test/sigra/oauth/enterprise_reconciliation_test.exs` and `cd test/example && mix test --include example_app test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/oauth/enterprise_callback_test.exs` plus any new reconciliation-focused root test file. [VERIFIED: command output]
- **Per wave merge:** `cd test/example && mix test --include example_app test/example_web/controllers/enterprise_sso_controller_test.exs test/example_web/integration/enterprise_sso_routing_flow_test.exs` plus all new enterprise reconciliation example tests. [VERIFIED: command output]
- **Phase gate:** Run both the root suite and the example-app suite before `/gsd-verify-work`. [VERIFIED: CLAUDE.md] [VERIFIED: test/example/test/test_helper.exs]

### Wave 0 Gaps
- [ ] `test/sigra/oauth/enterprise_reconciliation_test.exs` — covers exact existing-identity membership reuse, exact invite consumption, first-time JIT membership creation, duplicate-match refusal, and idempotent replay. [VERIFIED: codebase grep]
- [ ] `test/example/test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs` — proves `return_to` compatibility, `/organizations` fallback, and no session on unsafe outcomes. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- [ ] Update `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` — replace the current organization-settings redirect expectation with the Phase-124 redirect contract. [VERIFIED: test/example/test/example_web/controllers/enterprise_sso_controller_test.exs] [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md]
- [ ] Ensure all example-app commands include `--include example_app`. [VERIFIED: test/example/test/test_helper.exs] [VERIFIED: command output]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Provider subject plus routed connection anchor, verified-email bounded auto-claim only, and no session on ambiguous outcomes. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| V3 Session Management | yes | `Sigra.Auth.create_session/4` writes explicit `active_organization_id` before `session.create` audit emission. [VERIFIED: lib/sigra/auth.ex] |
| V4 Access Control | yes | Membership reconciliation must reuse the existing org/membership substrate and deny future inactive states by default. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| V5 Input Validation | yes | Exact normalized identifier matching and DB-backed uniqueness constraints. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] |
| V6 Cryptography | yes | Existing HMAC-signed OAuth state and secure session/token flows remain in place; Phase 124 should not replace them. [VERIFIED: lib/sigra/oauth.ex] |

### Known Threat Patterns for This Stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Email-collision account takeover | Elevation of Privilege | Require routed callback context, verified normalized email, exact single match, and provider-subject conflict checks. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: lib/sigra/oauth/callback.ex] |
| Wrong-org session issuance | Spoofing | Carry explicit `active_organization_id` in session metadata before the normal session is persisted. [VERIFIED: lib/sigra/auth.ex] |
| Duplicate membership or identity rows under concurrent callbacks | Tampering | Use DB unique indexes plus transactional recovery instead of validation-only logic. [VERIFIED: priv/templates/sigra.gen.oauth/oauth_migration.exs] [VERIFIED: test/example/priv/repo/migrations/20260410125245_create_organizations.exs] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html] |
| Unsafe fallback from enterprise flow into another auth mode | Repudiation / Elevation of Privilege | Return typed failure outcomes and bounded recovery surfaces; never silently downgrade within the same callback flow. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] |
| Open redirect or org-incompatible redirect | Tampering | Reuse local `return_to` discipline only after checking compatibility with the resolved org, otherwise fall back to a host-owned safe path. [VERIFIED: .planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex] |

## Sources

### Primary (HIGH confidence)
- [https://hexdocs.pm/ecto/Ecto.Multi.html](https://hexdocs.pm/ecto/Ecto.Multi.html) - official transaction-composition guidance and `append/2` / `merge/2` behavior.
- [https://hexdocs.pm/ecto/Ecto.Repo.html](https://hexdocs.pm/ecto/Ecto.Repo.html) - official `Repo.transact/2` behavior and aborted-transaction semantics.
- [https://hexdocs.pm/ecto/constraints-and-upserts.html](https://hexdocs.pm/ecto/constraints-and-upserts.html) - official uniqueness/constraint guidance for concurrent writes.
- [https://hexdocs.pm/assent/Assent.Strategy.OIDC.html](https://hexdocs.pm/assent/Assent.Strategy.OIDC.html) - official OIDC strategy behavior and config surface.
- `mix.exs`, `mix.lock`, `mix hex.info ecto`, `mix hex.info phoenix`, `mix hex.info assent` - current locked versions and current available releases. [VERIFIED: mix.exs] [VERIFIED: mix.lock] [VERIFIED: command output]
- `lib/sigra/oauth.ex`, `lib/sigra/oauth/callback.ex`, `lib/sigra/auth.ex`, `lib/sigra/organizations.ex`, `lib/sigra/organizations/invitations.ex` - existing implementation seams. [VERIFIED: codebase read]
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex`, `test/example/lib/example_web/user_auth.ex` - current redirect/session behavior in the host example app. [VERIFIED: codebase read]
- `test/example/priv/repo/migrations/20260410125245_create_organizations.exs`, `priv/templates/sigra.gen.oauth/oauth_migration.exs` - membership and identity uniqueness constraints. [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- `.planning/phases/124-jit-provisioning-safe-reconciliation/124-CONTEXT.md` - locked phase decisions and scoped UX/security posture. [VERIFIED: codebase read]
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `CLAUDE.md` - phase requirements, milestone posture, and repo constraints. [VERIFIED: codebase read]

### Tertiary (LOW confidence)
- None. [VERIFIED: this document]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - this phase stays on the repo’s current Ecto/Phoenix/Assent stack and needs no new dependency decision. [VERIFIED: mix.exs] [VERIFIED: mix.lock]
- Architecture: HIGH - the existing library/controller/session seams are explicit in code and align with the locked phase decisions. [VERIFIED: lib/sigra/oauth/callback.ex] [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/controllers/enterprise_sso_controller.ex]
- Pitfalls: HIGH - the main failure modes are directly visible in current code and are reinforced by official Ecto transaction/constraint guidance. [VERIFIED: lib/sigra/oauth/callback.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/constraints-and-upserts.html]

**Research date:** 2026-05-25
**Valid until:** 2026-06-24 for repo-grounded implementation seams; re-check package current-release metadata after that date. [VERIFIED: mix hex.info ecto] [VERIFIED: mix hex.info phoenix] [VERIFIED: mix hex.info assent]
