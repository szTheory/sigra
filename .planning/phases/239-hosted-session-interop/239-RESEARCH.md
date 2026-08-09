# Phase 239: Hosted Session Interop - Research

**Researched:** 2026-08-08
**Domain:** Server-owned Phoenix/SIGRA session projection into the `crosswake_sigra` pure route-authority contract
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Personal-account Crosswake contract
- **D-01:** Update the `crosswake_sigra` public contract so a `SessionAuthorityLane` and its enclosing `AuthContext` can represent a personal account with `org_id: nil`. A nonblank `org_id` remains required when an organization-scoped session is actually supplied; no sentinel, default, or fabricated organization is permitted.
- **D-02:** Keep `session_ref` and `subject_ref` opaque, server-owned references. The projection supplies the lane facts Crosswake needs—including session state, assurance/authentication facts, timestamps, version, and `as_of`—without exposing a raw session token, credential, provider payload, or OAuth token.

### Server-owned authority and replay
- **D-03:** The SIGRA host must resolve and revalidate the current backend `user_sessions` record and its user before every projection/evaluation. The Crosswake evaluator is a pure consumer of supplied authority facts, not a substitute for SIGRA storage validation.
- **D-04:** Bind every projection/replay to the currently resolved `session_ref` and `subject_ref`; a missing, deleted/revoked, expired, non-active, stale-version, or subject/session-mismatched state denies. Account-switch handling must be explicit at the host adapter boundary, because released Crosswake v0.1.1 has no native account-switch denial.

### Return evidence boundary and proof
- **D-05:** OAuth callback and hosted-return data are evidence/navigation only. They cannot be used as a session reference or independently grant a Crosswake route/replay; Crosswake-facing envelopes keep only approved opaque reference fields.
- **D-06:** Add deterministic contract/evaluator proof for both valid personal (`org_id: nil`) and organization-scoped values, invalid blank organization IDs, missing/revoked/expired/version-mismatched state, account/session switch denial, and the fact that return evidence alone cannot admit access.

### the agent's Discretion
- Choose the smallest backward-compatible Crosswake type/validation change and any required release/versioning process for that companion package.
- Reuse the repository's session-fetching, expiry cleanup, logout/revocation, and deterministic test conventions; select precise internal helper and denial-code names while preserving the locked outcomes above.

### Deferred Ideas (OUT OF SCOPE)

- Runtime/boot-time auth-schema prefix override remains a separate configuration capability; the user chose not to fold it into Phase 239.
- The other 31 todo matches were keyword-only or belong to installer, auth-UI, admin, security, CI, release, or evidence lanes rather than Crosswake interop.
- Real iPhone, production OAuth, email-provider, and adopter-host proof remain Phase 240/staging launch gates.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| XW-01 | A backend-validated SIGRA personal-account session can project to `crosswake_sigra` without inventing an organization or exposing credentials/tokens. | Personal nullable-org contract, host-side fresh session/user resolution, opaque projection mapping, and secret-free assertions. |
| XW-02 | Missing, expired, revoked, or account-switched session state fails closed for Crosswake replay; return data alone never grants access. | Ordered host binding checks, Crosswake evaluator denial behavior, no-authority return envelope, and deterministic denial matrix. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system, Rail Accent assets, and Light/Dark/System support only if this phase touches an admin UI; it should not need to. 
- Any Playwright/admin UI test must use role selectors, stable hooks, LiveView readiness, and no sleeps. 
- Replace manual UAT with deterministic tests, browser automation, CI polling, and machine-readable evidence within scope. Retry a transient failure once; never waive missing evidence. 
- Do not start unrelated phases or expand scope under the automation-first rule. 
- If CI is run, use one watcher per workflow and `gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`; obey the stated rate-limit stop rules. 

## Summary

The correct boundary has two deliberately separate authorities. The generated SIGRA host receives a browser cookie token, hashes it, fetches the canonical `user_sessions` record, then fetches the owning user. A fetched `Sigra.Session` contains a hash but no raw token. The host adapter must repeat that lookup and validate time/state at every projection or replay decision; only then may it construct Crosswake data. [VERIFIED: codebase grep]

`crosswake_sigra` v0.1.1 is intentionally a pure contract/evaluator layer: it validates a lane and denies revoked, expired, non-active, or version-mismatched supplied facts, but it does not load SIGRA storage and has no native account-switch denial. Its released contract currently requires nonblank `org_id` in both `SessionAuthorityLane` and `AuthContext`, which is incompatible with the locked B2C profile. The smallest compatible change is a shared “personal-or-nonblank-org” validator used by both types: accept `nil`, reject blank/non-string values, and preserve acceptance of nonblank organization IDs. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex]

The plan must treat the Crosswake companion patch/release and the SIGRA generated-host adapter proof as an ordered cross-repository delivery. Do not copy the raw session token, token hash, provider payload, or OAuth tokens into a lane, an envelope, denial details, or test snapshots. Return envelopes are already designed to reject such fields and cannot themselves contain session/subject/org/authority claims. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex]

**Primary recommendation:** Release a backwards-compatible `crosswake_sigra` contract successor that accepts `org_id: nil`, then implement one host-owned projection/evaluation adapter which freshly resolves, validates, and binds the SIGRA session and user before invoking the pure Crosswake evaluator.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Resolve cookie credential to session and user | API / Backend | Database / Storage | Only the host may hash the raw browser token and read canonical `user_sessions` plus user state. [VERIFIED: codebase grep] |
| Validate expiry/revocation/currentness | API / Backend | Database / Storage | Storage absence and timeout cleanup are server-authoritative; Crosswake has no storage dependency. [VERIFIED: codebase grep] |
| Create fact-only authority projection | API / Backend | — | The adapter maps resolved server facts to opaque references and timestamps; no browser/client fact grants authority. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex] |
| Evaluate route policy | API / Backend | — | Crosswake evaluator is pure and transport-agnostic, consuming the host-provided `AuthContext`. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex] |
| Handle OAuth/hosted-return input | API / Backend | Browser / Client | Return data is parsed as evidence/navigation; it cannot form authority or select a session. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex] |

## Standard Stack

### Core

| Library / component | Version | Purpose | Why Standard |
|---------------------|---------|---------|--------------|
| Generated SIGRA host session seam | repository template | Fresh raw-token-to-hash lookup, canonical session/user resolution, logout deletion | It is the established host boundary and uses the persisted session store rather than invented state. [VERIFIED: codebase grep] |
| `crosswake_sigra` | 0.1.1 released 2026-07-03; release a successor for this phase | Typed `SessionAuthorityLane` / `AuthContext`, pure evaluator, return boundary | It is the named companion contract; its own package metadata states independent versioning. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/mix.exs] |
| ExUnit + Mox | ExUnit bundled; Mox 1.2.0 locked | Deterministic unit/contract proof of session-store outcomes | Existing SIGRA session tests use `Sigra.MockSessionStore` and `verify_on_exit!`; no clock sleeps or browser-only proof is needed. [VERIFIED: codebase grep] |

### Supporting

| Library / component | Version | Purpose | When to Use |
|---------------------|---------|---------|-------------|
| `Sigra.SessionStores.Ecto` | repository template | Canonical hashed-token lookup/delete against host `user_sessions` | Production generated-host adapter and its integration fixture. [VERIFIED: codebase grep] |
| `Sigra.Plug.FetchSession` | repository template | Existing timeout semantics and eager expired-session cleanup | Reuse its calculations/behavior as the semantic precedent; do not rely only on an assigned scope. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Fresh host adapter lookup | Trust a previously serialized Crosswake lane or a `current_scope` alone | Rejected: a cached lane/scope cannot prove deletion, revocation, expiry, or a changed cookie/account at replay time. [VERIFIED: codebase grep] |
| `org_id: nil` personal contract | Sentinel organization such as `"personal"` | Rejected by locked decision D-01: it manufactures authority and loses the distinction between personal and organization scope. |
| Reference-only return envelope | Include session IDs/tokens/authority claims in callback data | Rejected: released `AuthReturn` explicitly forbids these claim classes. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex] |

**Installation:** Do not add a new SIGRA runtime dependency in this repository merely to test the boundary. The Crosswake repository must release its companion successor first; a generated-host/integration fixture may then depend on that exact released range after a human verifies the Hex package publication. [ASSUMED]

## Package Legitimacy Audit

| Package | Registry | Age / publication | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-------------------|-----------|-------------|---------|-------------|
| `crosswake_sigra` | Hex | 0.1.1, 2026-07-03 | 9/7 days at research time | github.com/szTheory/crosswake | Hex registry verified; legitimacy seam does not support Hex | Human-verify the released successor before any generated-host dependency update. [ASSUMED] |

**Packages removed due to [SLOP] verdict:** none — the provided legitimacy seam supports only npm, PyPI, and crates, so it cannot emit a valid Hex verdict.

**Packages flagged as suspicious [SUS]:** none from the supported legitimacy check. The low download count is not a safety verdict; use an explicit `checkpoint:human-verify` for the Crosswake release tag/Hex publication before consuming it. [ASSUMED]

## Architecture Patterns

### System Architecture Diagram

```text
Browser cookie / callback evidence
          |
          v
Generated SIGRA host adapter
  |-- hash cookie token -> fetch current user_sessions row -> fetch current user
  |-- validate presence + active/expiry + subject/session binding + version
  |       | failure
  |       +------------------------------------> deny (no Crosswake evaluation)
  |
  | success
  v
Fact-only projection: SessionAuthorityLane + AuthContext
  - opaque session_ref / subject_ref; org_id nil or nonblank
  - state, assurance, timestamps, version, as_of
          |
          v
Pure crosswake_sigra evaluator
  |-- lane state/expiry/version/policy checks
  |       | failure ----------------------------> safe denial code/details
  |       ` success ----------------------------> allow route/replay
  |
Return envelope --------------------------------> evidence/navigation only;
                                                    never an authority input
```

### Recommended Project Structure

```text
# Crosswake companion repository (release prerequisite)
packages/crosswake_sigra/
├── lib/crosswake/companions/sigra/contracts.ex  # nullable-personal org validator
└── test/crosswake/companions/sigra/             # contract/evaluator/return proofs

# SIGRA generated-host proof seam (exact path to choose by existing fixture conventions)
test/example/
├── lib/example/.../crosswake_session_adapter.ex # host-only resolution/projection adapter
└── test/.../crosswake_session_adapter_test.exs  # deterministic replay/binding tests
```

### Pattern 1: Resolve → validate → bind → project → evaluate

**What:** Make a single host adapter the only route to Crosswake evaluation. It must resolve the live session and user first; calculate timestamps/expiry from that record; require the resolved session and subject references to equal any replay binding; construct contracts; then call the evaluator.

**When to use:** Every Crosswake route/replay decision for the B2C generated host, including a return continuation.

**Example:**

```elixir
# Source: SIGRA generated auth seam + Crosswake contracts/evaluator (URLs in Sources)
with {user, session} <- Accounts.get_user_and_session_by_token(raw_cookie_token),
     :ok <- validate_active_session(session, now),
     :ok <- match_replay_binding(session.id, user.id, expected_session_ref, expected_subject_ref),
     {:ok, lane} <- Contracts.new_session_authority_lane(%{
       session_ref: opaque_session_ref(session.id),
       subject_ref: opaque_subject_ref(user.id),
       org_id: nil,
       state: :active,
       assurance_level: :password,
       authn_methods: [:password],
       authenticated_at: iso(session.inserted_at),
       last_seen_at: iso(session.last_active_at),
       idle_expires_at: idle_expiry(session),
       absolute_expires_at: absolute_expiry(session),
       session_version: session_version(session),
       as_of: iso(now)
     }),
     {:ok, context} <- Contracts.new_auth_context(session_authority_lane: lane) do
  Evaluator.evaluate_route_auth(route, context, expected_session_version: session_version(session))
else
  _ -> {:deny, :session_binding_or_authority_invalid}
end
```

The mapping above is illustrative: names and exact session-version source remain an implementation choice, but its order and no-token property are locked. [ASSUMED]

### Pattern 2: Personal scope is a semantic union, not a string convention

**What:** Define one shared validator that accepts exactly `nil` or a trimmed nonblank string. Use it for `SessionAuthorityLane` and `AuthContext`, including lane-derived aliases. Keep the organization form unchanged.

**When to use:** All Crosswake contracts that represent personal-versus-organization scope. If an `AuthReturn.AttemptRecord` participates in the personal replay path, apply the same semantic rule there as well; released v0.1.1 currently requires a string there. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex]

### Pattern 3: Explicit account-switch denial at the adapter

**What:** Compare the request/replay’s approved opaque bindings with the freshly resolved session and user. A valid different account/session is still a denial, not a new authority context.

**When to use:** Any continuation or replay which carries an expected session/subject/version reference.

### Anti-Patterns to Avoid

- **Using `conn.assigns.current_scope` as proof:** it is request-derived convenience state, not a fresh storage revalidation; resolve the current canonical session/user at the adapter. [VERIFIED: codebase grep]
- **Projecting raw token or `hashed_token`:** neither is an approved Crosswake-facing authority reference; use host-defined opaque references only. [VERIFIED: codebase grep]
- **Treating evaluator allow as a storage validity proof:** the evaluator only checks facts supplied to it. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex]
- **Returning a generic signed callback that selects a session:** callback data may locate/describe a server attempt only and cannot carry `session_ref`, `subject_ref`, org, or authority data. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session token hashing/storage lookup | A parallel Crosswake session table or token parser | Generated host `get_user_and_session_by_token/1` / `Sigra.SessionStore` semantics | Canonical store already hashes the raw token and ties it to its user. [VERIFIED: codebase grep] |
| Route-policy denial evaluation | Host-specific branching for every auth posture | `crosswake_sigra` evaluator | It centralizes known lane-state, expiry, version, remembered, cached, assurance, and freshness checks. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex] |
| Callback token/credential filtering | An allowlist duplicated by the generated host | `Crosswake.Companions.Sigra.AuthReturn.new_envelope/1` | The companion already rejects authority and sensitive credential/token fields. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex] |
| Time-based proof | `Process.sleep/1` or real clock waits | Fixed `as_of`/timestamps and Mox-configured session records | Deterministic time values exercise expiry without flaky waits. [VERIFIED: codebase grep] |

**Key insight:** The new code is a narrow adapter, not a second auth system. It composes the existing canonical SIGRA resolution with the existing pure Crosswake policy evaluation while preserving a hard information boundary.

## Common Pitfalls

### Pitfall 1: Changing only `SessionAuthorityLane.org_id`

**What goes wrong:** A personal lane can be created but `new_auth_context/1` still rejects its lane-derived `org_id: nil`; a later AuthReturn record may fail similarly if it is used in the same personal flow.

**Why it happens:** v0.1.1 validates `org_id` independently in several contracts. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex]

**How to avoid:** Introduce a shared nullable-personal/nonblank-org validator and add paired personal/organization/blank tests for every touched contract.

**Warning signs:** Lane construction passes while `AuthContext` construction fails, or a personal replay uses an organization sentinel.

### Pitfall 2: Reusing stale authority after logout, expiry, or switch

**What goes wrong:** A previously valid serialized lane allows a replay after its SIGRA row was deleted, expired, or replaced by a different account cookie.

**Why it happens:** Crosswake has no persistence access; its evaluator only sees the facts it receives. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex]

**How to avoid:** Always read the current session and user, then compare expected opaque session/subject/version bindings before constructing a lane.

**Warning signs:** A test can call the evaluator directly with an old active lane after deleting the backing record and still obtain allow.

### Pitfall 3: Letting callback evidence become authority by convenience

**What goes wrong:** A return object supplies a token, session reference, user identity, org, or `access_granted` flag which bypasses current session resolution.

**Why it happens:** Callback data is available at the routing boundary, whereas server-state lookup costs an extra deliberate call.

**How to avoid:** Build the envelope through the companion constructor; deny unsupported/forbidden fields and prove that an otherwise valid envelope with no fresh host session cannot allow.

**Warning signs:** Any public envelope/denial detail contains `session_ref`, `subject_ref`, raw OAuth fields, provider payloads, or authority booleans. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex]

### Pitfall 4: Adding an evaluator-only account-switch test

**What goes wrong:** The test proves no switch behavior because released Crosswake does not know the host’s current cookie/user identity.

**How to avoid:** Put switch proof at the host adapter seam: expected binding for A + newly resolved session/user B must deny before evaluator invocation; assert the evaluator was not given B as a substitute authority.

## Code Examples

Verified patterns from the repository and companion source:

### Canonical SIGRA resolution

```elixir
# Source: priv/templates/sigra.install/core/auth.ex
with {:ok, raw_bytes} <- Base.url_decode64(raw_token, padding: false) do
  hashed = Sigra.Token.hash_token(raw_bytes)

  case store.fetch(hashed, store_opts) do
    {:ok, session} ->
      case Repo.get(User, session.user_id) do
        nil -> nil
        user -> {user, session}
      end

    {:error, :not_found} -> nil
  end
end
```

### Deterministic expired-session expectation

```elixir
# Source: test/sigra/plug/fetch_session_test.exs
Sigra.MockSessionStore
|> expect(:fetch, fn _token, _opts -> {:ok, expired_session} end)
|> expect(:delete, fn _token, _opts -> :ok end)

conn = FetchSession.call(conn, opts)
assert conn.assigns[:current_scope] == nil
```

### Personal scope acceptance test shape

```elixir
# Source: Crosswake Contracts test conventions; required new coverage
assert {:ok, lane} = Contracts.new_session_authority_lane(valid_lane(org_id: nil))
assert {:ok, context} = Contracts.new_auth_context(session_authority_lane: lane)
assert context.org_id == nil

assert {:ok, _} = Contracts.new_session_authority_lane(valid_lane(org_id: "org_123"))
assert {:error, errors} = Contracts.new_session_authority_lane(valid_lane(org_id: "  "))
assert {:org_id, :required} in errors
```

The final error tuple above should match the release’s established validator shape; exact naming is discretionary. [ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `crosswake_sigra` requires a nonblank org for all lanes/contexts | Personal accounts must be modeled explicitly as `org_id: nil`, while org sessions retain a nonblank ID | This phase | Removes fabricated scope without weakening organization validation. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex] |
| Rely on the evaluator’s supplied lane facts alone | Host resolves current session/user then gives the evaluator fresh, bound facts | This phase | Makes revocation and account switching fail closed at the only tier able to observe them. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex] |

**Deprecated/outdated:** A personal “default organization” sentinel is prohibited by D-01 and must not be introduced.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The generated-host/integration proof should consume a newly released Hex successor rather than a Git path dependency. | Standard Stack / Package Legitimacy | Planning could choose the wrong release handoff or test topology. |
| A2 | The host session’s version source/helper name is not established in this repository and must be selected during implementation. | Architecture Patterns | An incomplete binding could fail to detect stale replay. |
| A3 | A personal `AuthReturn.AttemptRecord` needs nullable `org_id` only if Phase 239 uses that record in the personal replay path. | Architecture Patterns | A latent contract mismatch could appear after implementation. |
| A4 | The illustrative contract error tuple may differ from the final shared validator’s exact API. | Code Examples | Tests could overfit an uncommitted error-name choice. |

## Open Questions

1. **What is the canonical durable source of `session_version` in the SIGRA generated host?**
   - What we know: Crosswake checks a supplied integer `expected_session_version`, while SIGRA’s current `Session` struct exposes no version field. [VERIFIED: codebase grep]
   - What's unclear: Whether version is derived from session identity/lifecycle, added to host persistence, or supplied by an existing Crosswake host record.
   - Recommendation: Resolve before implementation; use a server-owned monotonic/value-stable source and add an explicit changed-version denial test. Do not substitute a client-provided integer. [ASSUMED]

2. **Does the B2C adapter actually create a Crosswake `AuthReturn.AttemptRecord`?**
   - What we know: its current server-owned record requires a nonblank org and bindings; the public envelope excludes authority data. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex]
   - What's unclear: whether this phase needs full hosted-return persistence or only proof of the envelope boundary.
   - Recommendation: Keep the envelope-only proof in scope. If an attempt record is exercised, extend its org rule consistently and prove it; otherwise do not add unused persistence. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | contract and generated-host tests | ✓ | Mix 1.19.5 / OTP 28 | — |
| Docker | existing SIGRA test PostgreSQL service | ✓ | 29.5.2 | local PostgreSQL if configured |
| PostgreSQL client/service | full `mix test` database-backed suite | client ✓; local service unavailable | psql 14.17; `pg_isready` no response | Docker Compose / CI service |
| Crosswake companion release checkout | companion contract patch and release proof | ✗ in this workspace | released Hex 0.1.1 inspected | perform the ordered change in the Crosswake repository |

**Missing dependencies with no fallback:** none for planning; the companion repository/maintainer release step is an external delivery dependency, not a local tool installation.

**Missing dependencies with fallback:** local PostgreSQL service is absent; use the existing Docker/CI service for full SIGRA suite runs.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (bundled with Elixir) + Mox 1.2.0 lockfile |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/sigra/plug/fetch_session_test.exs` |
| Full suite command | `mix test` (requires PostgreSQL at localhost:5432 or the CI/Docker service) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| XW-01 | Personal `nil` org lane/context accepts; organization value accepts; blank rejects; no raw credentials/tokens leave the projection | Crosswake contract unit + generated-host integration | `mix test packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs` and generated-host focused test | ❌ Wave 0 / companion successor |
| XW-02 | Missing, expired, revoked, version mismatch, subject/session switch deny before/at evaluation | Host adapter unit/integration + Crosswake evaluator unit | focused adapter test plus `mix test .../step_up_test.exs` as applicable | ❌ Wave 0 |
| XW-02 | Evidence-only callback cannot create authority or admit a route | Crosswake AuthReturn contract/evaluator integration | `mix test packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs` plus new personal-host proof | existing boundary proof; ❌ personal-host proof |

### Sampling Rate

- **Per task commit:** focused ExUnit file(s) for the edited adapter/contract.
- **Per wave merge:** Crosswake companion suite and SIGRA focused suite.
- **Phase gate:** both repositories’ relevant full suites green; no manual UAT substitute.

### Wave 0 Gaps

- [ ] Crosswake contract test cases for personal `nil`, organization nonblank, and blank `org_id` for every touched contract.
- [ ] Generated-host adapter test proving fresh session/user resolution and no raw token/hash/provider field in the lane/context/denial output.
- [ ] Deterministic replay matrix: missing, revoked/deleted, idle expired, absolute expired, stale version, subject mismatch, session mismatch, account switch, and evidence-only return.
- [ ] Explicit test that account switch denies before the evaluator can be treated as the authority source.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Canonical server-side session/user lookup before projection. [VERIFIED: codebase grep] |
| V3 Session Management | yes | Hash-only persistence, expiry cleanup, server deletion/revocation, opaque references. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Pure evaluator plus host-side binding/deny-before-evaluate boundary. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex] |
| V5 Input Validation | yes | Strict nullable-personal/nonblank-org contract validation and envelope allowlist. [CITED: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex] |
| V6 Cryptography | yes | Reuse `Sigra.Token` hashing and existing return mechanisms; do not design a new token/crypto primitive. [VERIFIED: codebase grep] |

### Known Threat Patterns for this boundary

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay after session deletion/revocation | Elevation of Privilege | Fresh server lookup; absence/revocation denies; never trust serialized lane. |
| Account/session switch during return | Spoofing | Compare expected opaque session/subject/version with freshly resolved values and deny mismatch before evaluation. |
| Fabricated org authority | Elevation of Privilege | `nil` means personal; require a nonblank org only for organization scope; no sentinels. |
| Credential/token leakage through projection or denial | Information Disclosure | Opaque refs only; reject sensitive envelope fields; assert output/snapshots contain no raw secret fields. |
| Authority smuggling in callback data | Tampering | Build/validate reference-only `AuthReturn.Envelope`; require host-side current session validation for any route allow. |

## Sources

### Primary (MEDIUM confidence)

- [Crosswake contracts at pinned release](https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex) — lane/context validation and evidence authority rejection.
- [Crosswake evaluator at pinned release](https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex) — pure evaluation and explicit denial cases.
- [Crosswake AuthReturn at pinned release](https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex) — envelope/attempt contracts and forbidden fields.
- [Crosswake companion package metadata](https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/mix.exs) and [changelog](https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/CHANGELOG.md) — release 0.1.1 and independent versioning.

### Primary (repository verified)

- `priv/templates/sigra.install/core/auth.ex` — canonical raw-token hash, storage lookup, and user lookup.
- `lib/sigra/session.ex`, `lib/sigra/session_stores/ecto.ex` — raw token is creation-only; persistent records use hashed tokens.
- `lib/sigra/plug/fetch_session.ex`, `test/sigra/plug/fetch_session_test.exs` — fail-closed missing/expired behavior and deterministic Mox conventions.
- `guides/recipes/b2c-alpha.md` — canonical B2C personal-session/Crosswake boundary.

### Tertiary (LOW confidence)

- None beyond assumptions explicitly listed above.

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — current companion source and current local SIGRA seams were inspected; the successor release does not yet exist.
- Architecture: MEDIUM — host/evaluator responsibility split is directly evidenced, but exact adapter location and session-version source remain open.
- Pitfalls: MEDIUM — derived from code paths and missing capability boundary, with deterministic tests identified.

**Research date:** 2026-08-08
**Valid until:** 2026-08-15 (fast-moving cross-repository release dependency)
