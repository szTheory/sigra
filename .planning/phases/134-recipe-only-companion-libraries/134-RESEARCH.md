# Phase 134: Recipe-Only Companion Libraries - Research

**Researched:** 2026-05-28
**Domain:** Adopter-facing ExDoc integration recipes (docs-only) + one atomic `mix.exs` edit
**Confidence:** HIGH (every load-bearing pin verified against local checkouts this session)

## Summary

This is a **verification + validation-architecture pass**, not greenfield research. The
134-CONTEXT.md is exhaustive: 20 locked decisions (D-01..D-20), every canonical reference,
and `mix.exs` edit targets with line numbers. My job was to confirm the line-range pins the
four recipes will reference actually resolve in the current trees, and to flag discrepancies
between what CONTEXT/STACK claim and what the code says.

**Headline result:** The single most consequential pin — D-09's `Sigra.Auth.create_session/4`
at `lib/sigra/auth.ex:1284` — is **CONFIRMED correct**, and STACK.md:111's
`Sigra.Session.create_session/3` is **CONFIRMED wrong** (no such function exists). Every other
Sigra-side seam and every `mix.exs` line number in CONTEXT is **accurate with zero drift**.

**Three sister-repo discrepancies found** — all in the directions CONTEXT already half-warned
about. (1) Lockspire's `@optional_callbacks` and the `redirect_for_logout/2` callback ordering
differ slightly from CONTEXT D-06's prose. (2) Rulestead's adopter entry point is materially
mis-described in BOTH STACK.md:34 and STACK.md:112 (and partially in CONTEXT D-14): the form
`Rulestead.enabled?("flag", conn)` **does not exist** in either the README or the source. (3)
The Rulestead `Admin.Authorizer` policy callback is `can?/4`, not an `authorize`-shaped
callback — the planner must pin the host `RulesteadPolicy` to `can?/4`.

**Primary recommendation:** Plan the four recipes structurally identical to `threadline.md`
(the captured template below). Pin Relyra's session-mint to `Sigra.Auth.create_session/4`
exactly. For Rulestead, pin the **root-module `Rulestead.enabled?/2` (`flag_payload, context`)**
as the low-level contract and the **`Rulestead.Runtime.enabled?/3` (`env, flag, context`)** as
the Phoenix convenience form — and explicitly do NOT write `Rulestead.enabled?("flag", conn)`,
which is a STACK.md fabrication. Pin the `RulesteadPolicy` to the `can?/4` callback shape.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All 20 decisions D-01..D-20 in 134-CONTEXT.md are LOCKED and govern this phase. The
load-bearing subset the planner must honor verbatim:

- **D-01 (Accrue seams):** Pin BOTH `lib/sigra/organizations/callbacks.ex:17-18, 38-48`
  (`before_add_member/4` seat gating + `after_member_remove/2`) AND `lib/sigra/hooks.ex:1-103`
  (user-lifecycle registry). Recipe makes the split explicit: organizations callbacks = seat
  gating; user-lifecycle hooks = subscription cleanup on user delete.
- **D-02 (Accrue.Auth behaviour):** Host implements `Accrue.Auth` behaviour once, configured
  via `config :accrue, :auth_adapter, MyApp.Accrue.Auth`.
- **D-03/D-04 (Accrue audit/webhooks):** `log_audit/2` cross-links `lib/sigra/audit.ex` +
  `threadline.md`; Sigra `AuditEvent` stays source-of-truth. Do NOT invent Accrue webhook
  payloads — link `guides/flows/audit-logging.html`, show event-type filtering.
- **D-05/D-06 (Lockspire):** Concrete recipe that COMPLEMENTS `companion-oauth-provider.md`
  (cross-links, does not duplicate). Shows `{:lockspire, "~> 1.2"}` host-only,
  `mix lockspire.install --sigra-host`, the AccountResolver contract, the Sigra field the
  stub reads. Verify the callback list against installed `~> 1.2` (done — see Discrepancies).
- **D-07 (Lockspire scope read):** Pin `conn.assigns.current_scope.user` per
  `lib/sigra/scope.ex:18-25`.
- **D-08 (Lockspire ADR 001):** Non-goals quote the ADR 001 deferral trigger; cross-link
  `companion-oauth-provider.md`.
- **D-09 (Relyra session-mint — THE load-bearing pin):** Pin `Sigra.Auth.create_session/4`
  (`lib/sigra/auth.ex:1284`), NOT `Sigra.Session.create_session/3`.
- **D-10 (Relyra hand-off):** Pin `Relyra.start_login/3` + `Relyra.consume_response/3`
  (`lib/relyra.ex:28-29` + moduledoc 9-11). After ACS, host mints via D-09.
- **D-11 (Relyra OIDC-vs-SAML):** Inline-rephrase the matrix in adopter voice (NOT planning
  vocabulary). Cross-link the v1.27 ENT-SSO OIDC-via-Assent surface and contrast with SAML.
- **D-12 (Relyra non-goals):** SAML metadata storage, signing keys, IdP-initiated SLO,
  cert rotation stay with Relyra. `validated_against: relyra ~> 1.2`.
- **D-13 (Rulestead version caveat):** Pin `validated_against: rulestead ~> 0.1`. Surface the
  `1.0.0 narrative GA vs ~> 0.1 Hex line` mismatch as ONE neutral Prerequisites sentence.
- **D-14 (Rulestead surface — verify-at-write-time):** Resolved in Discrepancies below.
- **D-15 (Rulestead policy):** Pin `current_scope` fields to FEATURES.md:26 +
  `lib/sigra/scope.ex:16-25`; reference the `Admin.Authorizer` callback shape (resolved below);
  Non-goals: Sigra owns no flag storage/evaluator/admin UI.
- **D-16/D-17 (mix.exs atomic edit):** ONE two-block edit; add four `extras:` entries after
  `mailglass.md`, remove the four `skip_undefined_reference_warnings_on:` entries + Phase 133
  comment header. Must be atomic (no intermediate state ships).
- **D-18/D-19 (sequencing):** Single sequential plan, six steps. Do NOT parallelize into four
  plans.
- **D-20 (banned-phrase grep):** Pre-commit grep MUST return zero matches.

### Claude's Discretion
- Exact prose voice (within banned-phrase guardrails); mirror threadline/mailglass register.
- Per-recipe length (~100-160 lines each; planner sets per contract depth).
- Role table vs orientation paragraph (default: role table for consistency).
- Rulestead canonical surface (D-14) — resolved at write-time; see Discrepancies §3.
- Relyra OIDC-vs-SAML callout box vs prose+table (default: compact 2-row table).
- Cross-link "See also" lists per recipe.

### Deferred Ideas (OUT OF SCOPE)
- Recipe-contract test fixtures (v1.29 Future Requirement; Phase 136 may grep-assert).
- Sigra-managed billing / SAML metadata / feature-flag storage (Diminishing Returns Wall).
- `sigra_lockspire` glue Hex package (ADR 001).
- `--with-accrue` / `--with-relyra` / etc. install flags (zero `--with-*` precedent).
- Touch-up rewrite of `companion-oauth-provider.md` beyond a reciprocal "See also" back-link.
- **Library-resident adapters, `--with-*` flags, glue Hex packages** — Diminishing Returns
  Wall, REQUIREMENTS.md Out-of-Scope lines 65-73. Recipes are pure host-side wiring.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RC-03 | `guides/recipes/companion-libs/accrue.md` — `Accrue.Auth` behaviour + cross-link `lib/sigra/hooks.ex` for seat-limit gating + lifecycle | `Accrue.Auth` behaviour CONFIRMED at `accrue/lib/accrue/auth.ex:41-49` (5 req + 2 opt). Sigra seams CONFIRMED: `callbacks.ex:38-48` (`before_add_member/4`, `after_member_remove/2`), `hooks.ex:1-103` (lifecycle). |
| RC-04 | `guides/recipes/companion-libs/lockspire.md` — concrete recipe (mix.exs deps, AccountResolver stub, walkthrough) cross-linking `companion-oauth-provider.md`; respects ADR 001 | AccountResolver behaviour CONFIRMED at `lockspire/lib/lockspire/host/account_resolver.ex:1-39` (with callback-list correction — see §1). `companion-oauth-provider.md` (52 lines) read; `mix lockspire.install --sigra-host` named at its line 38. Scope read CONFIRMED at `scope.ex:18`. |
| RC-05 | `guides/recipes/companion-libs/relyra.md` — SAML 2.0 SP wiring + v1.27 ENT-SSO OIDC-vs-SAML matrix | `Relyra.start_login/3` CONFIRMED at `relyra.ex:28`; `Relyra.consume_response/3` CONFIRMED at `relyra.ex:150-152`. Session-mint `Sigra.Auth.create_session/4` CONFIRMED at `auth.ex:1284`. ENT-SSO files all exist. |
| RC-06 | `guides/recipes/companion-libs/rulestead.md` — `Rulestead.enabled?` from Sigra-protected controller + `RulesteadPolicy` from `current_scope` | `Rulestead.enabled?/2` CONFIRMED at `rulestead.ex:1189-1194` (`flag_payload, context`). Convenience form is `Rulestead.Runtime.enabled?/3`, NOT `enabled?("flag", conn)` (see §2). `Admin.Authorizer` policy callback is `can?/4` (see §3). `current_scope` fields per `scope.ex:16-25`. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Four recipe `.md` files | Docs (`guides/recipes/companion-libs/`) | — | Adopter-facing host-side wiring guides; no `lib/` code. |
| `extras:` + skip-warnings edit | Build config (`mix.exs`) | — | ExDoc registration; the only non-`guides/` edit. |
| Seat-limit gating | Host app (implements `before_add_member/4`) | Accrue (`Accrue.Auth` behaviour) | Sigra owns NO seat-limit logic; it owns the *seam*. |
| Subscription cleanup on delete | Host app (implements lifecycle hook) | Accrue | `Sigra.Hooks` fires `:on_delete`; host calls Accrue. |
| OAuth/OIDC authorization server | Lockspire (host config) | Sigra (identity source via `current_scope.user`) | ADR 001 — no glue package; host wires AccountResolver. |
| SAML 2.0 SP federation | Relyra (standalone, own install) | Sigra (mints session post-ACS) | Sigra owns only the org-scoped session it issues. |
| Feature-flag evaluation | Rulestead (host config) | Sigra (`current_scope` supplies context) | Sigra ships no opinionated authorization or flag store. |

## Verification Findings — Sister-Repo Behaviour Contracts

### Accrue — `Accrue.Auth` behaviour — ✅ CONFIRMED EXACT
**File:** `/Users/jon/projects/accrue/accrue/lib/accrue/auth.ex:41-49`

CONTEXT D-02 claim (5 required + 2 optional) is **exactly correct**:

| Callback | Arity | Status |
|----------|-------|--------|
| `current_user(conn)` | 1 | required (`auth.ex:41`) |
| `require_admin_plug()` | 0 | required (`auth.ex:42`) |
| `user_schema()` | 0 | required (`auth.ex:43`) |
| `log_audit(user, map)` | 2 | required (`auth.ex:44`) |
| `actor_id(user)` | 1 | required (`auth.ex:45`) |
| `step_up_challenge(user, map)` | 2 | optional (`@optional_callbacks` line 49) |
| `verify_step_up(user, map, map)` | 3 | optional (`@optional_callbacks` line 49) |

Config wiring confirmed: moduledoc says `config :accrue, :auth_adapter, MyApp.Auth` (`auth.ex:7`).
There is also a public `admin?/1` facade fn (`auth.ex:78`) that adapters MAY expose as a
`admin?/1` helper — the recipe may mention this but the behaviour does not require it.
`[VERIFIED: local checkout accrue/lib/accrue/auth.ex]`

### Lockspire — `AccountResolver` behaviour — ⚠️ CONFIRMED WITH ORDERING CORRECTION
**File:** `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex:1-39`

CONTEXT D-06 prose says "5 required (`resolve_current_account/2`, `resolve_account/2`,
`build_claims/2`, `redirect_for_login/2`, `verify_backchannel_user_code/3`) + 1 optional
(`redirect_for_logout/2`)." The **actual `@optional_callbacks` line tells a different story**:

```elixir
@optional_callbacks [redirect_for_logout: 2, verify_backchannel_user_code: 3]   # line 36
```

| Callback | Arity | ACTUAL status (per source) |
|----------|-------|----------------------------|
| `resolve_current_account(conn_or_socket, context)` | 2 | required (`account_resolver.ex:14`) |
| `resolve_account(account_reference, context)` | 2 | required (`account_resolver.ex:17`) |
| `build_claims(account, context)` | 2 | required (`account_resolver.ex:20`) |
| `redirect_for_login(conn_or_socket, context)` | 2 | required (`account_resolver.ex:23`) |
| `verify_backchannel_user_code(subject_id, user_code, context)` | 3 | **OPTIONAL** (in `@optional_callbacks` line 36) |
| `redirect_for_logout(conn_or_socket, context)` | 2 | optional (`account_resolver.ex:36`) |

**DISCREPANCY:** CONTEXT D-06 lists `verify_backchannel_user_code/3` as **required** and
`redirect_for_logout/2` as the only optional. The installed `~> 1.2` source marks **BOTH**
`verify_backchannel_user_code/3` and `redirect_for_logout/2` as optional. So the correct
breakdown is **4 required + 2 optional**, not 5 + 1.

The 4 required callbacks every Sigra host must implement: `resolve_current_account/2`,
`resolve_account/2`, `build_claims/2`, `redirect_for_login/2`. The recipe should pin the
contract by line-range reference to `account_resolver.ex:14-39` and describe it as **4
required + 2 optional** (CIBA `verify_backchannel_user_code/3` and `redirect_for_logout/2` are
opt-in; a host that does not use CIBA backchannel flows need not implement it). This is the
exact "re-verify against `~> 1.2`" call D-06 mandated. `[VERIFIED: local checkout
lockspire/lib/lockspire/host/account_resolver.ex]`

> Note for the planner: the `@callback redirect_for_logout/2` definition (line 37) appears
> *after* the `@optional_callbacks` attribute (line 36) in the source. This is valid Elixir
> but means a quick top-to-bottom skim could miss that `verify_backchannel_user_code/3` is
> optional. Pin the line range `14-39` (whole behaviour) so the recipe captures both.

### Relyra — ACS hand-off contract — ✅ CONFIRMED EXACT
**File:** `/Users/jon/projects/relyra/lib/relyra.ex`

| Function | Signature | Location | Status |
|----------|-----------|----------|--------|
| `Relyra.start_login/3` | `start_login(connection, relay_context, opts \\ [])` | `relyra.ex:28-29` (`@spec` 28, `def` 29) | ✅ |
| `Relyra.consume_response/3` | `consume_response(response_payload, request_intent_or_opts, opts \\ [])` | `relyra.ex:150-152` (`@spec` 150-151, `def` 152) | ✅ |

CONTEXT D-10 cites `relyra.ex:28-29` for `start_login/3` and moduledoc lines 9-11 — both
**exact**. CONTEXT also cites `consume_response/3` at "line 28-29" in one place and "9-11"
moduledoc in another; the canonical_refs line `relyra.ex:9-11, 28-29` is slightly imprecise
because `consume_response/3`'s **definition** is at `relyra.ex:150-152`, not 28-29 (only its
*moduledoc mention* is at line 10). **Recommendation:** the recipe should pin
`relyra.ex:28-29` for `start_login/3` and `relyra.ex:150-152` for `consume_response/3`, plus
the moduledoc `relyra.ex:6-12` as the human-readable contract summary. `consume_response/3`
returns `{:ok, map()} | {:error, Relyra.Error.t()}` (`@spec` line 150-151). The moduledoc
(line 11) describes the success value as `%Relyra.LoginResult{}` — the host reads the
authenticated subject from that result, then mints a Sigra session. `[VERIFIED: local
checkout relyra/lib/relyra.ex]`

### Rulestead — `enabled?` surface + policy callback — ⚠️ MAJOR DISCREPANCY (see §2 + §3 below)

`Rulestead.enabled?/2` **CONFIRMED** at `rulestead.ex:1189-1194`:
```elixir
@spec enabled?(map(), Context.t() | keyword() | map()) :: {:ok, boolean()} | {:error, Error.t()}
def enabled?(flag_payload, context) do ...   # line 1190
```
This is a **2-arity** `(flag_payload, context)` function returning a tagged tuple — NOT a
`(flag, conn)` boolean. `[VERIFIED: local checkout rulestead/lib/rulestead.ex]`

## Verification Findings — Sigra-Side Seams (the load-bearing pins)

### D-09 — `Sigra.Auth.create_session/4` — ✅ CONFIRMED (the most consequential pin)
**File:** `/Users/jon/projects/sigra/lib/sigra/auth.ex:1282-1284`
```elixir
@spec create_session(Sigra.Config.t(), struct(), map(), keyword()) ::
        {:ok, Sigra.Session.t()} | {:error, term()}
def create_session(config, user, metadata, opts \\ []) do   # line 1284
```
- Signature matches CONTEXT's `(config, user, metadata, opts \\ [])` **exactly**.
- `@doc since: "0.4.0"`. Internal callers at `auth.ex:1768` and `auth.ex:1927`.
- **`lib/sigra/session.ex` has NO `create_session` function.** The only `create_session`
  string in that file is a moduledoc line (`session.ex:10`) that itself references
  `Sigra.Auth.create_session/4`. `[VERIFIED: grep lib/sigra/session.ex + lib/sigra/auth.ex]`

**Confirms STACK.md:111 is WRONG.** The Relyra recipe MUST pin `Sigra.Auth.create_session/4`
(`lib/sigra/auth.ex:1284`). Writing `Sigra.Session.create_session/3` would ship an
`UndefinedFunctionError` to adopters and fail `mix docs --warnings-as-errors`.

### D-01 — Accrue organizations callbacks — ✅ CONFIRMED EXACT
**File:** `/Users/jon/projects/sigra/lib/sigra/organizations/callbacks.ex`
- Callbacks-doc table row at **line 17**: `before_add_member/4 | Can abort | Check seat limits`
  — literally "Check seat limits" exactly as CONTEXT D-01 claims.
- `after_member_remove/2` table row at **line 20**, callback `@callback after_member_remove`
  at **line 47-48**.
- `@callback before_add_member(org, user, role, scope)` at **line 38-39** (4-arity, returns
  `:ok | {:error, term()}`). `[VERIFIED: local file]`

CONTEXT cites `callbacks.ex:17-18, 38-48` — the table is lines 11-21 (row 17, 20) and the two
relevant `@callback` defs are at 38-39 and 47-48, all inside the `17-18, 38-48` envelope. Pin
holds.

### D-01 — `Sigra.Hooks` user-lifecycle registry — ✅ CONFIRMED EXACT
**File:** `/Users/jon/projects/sigra/lib/sigra/hooks.ex` (103 lines total)
- Operations enumerated at `hooks.ex:45-46`: `:password_change, :email_change, :delete,
  :register`. Lookup convention at line 89: "operation `:register` looks up `:on_register`".
- So the hook function names are `on_register / on_password_change / on_email_change /
  on_delete` exactly as CONTEXT D-01 claims. File is exactly 103 lines (CONTEXT `hooks.ex:1-103`
  is exact). `[VERIFIED: local file + wc -l]`

### D-07/D-15 — `Sigra.Scope.build/3` — ✅ CONFIRMED (with field-bus nuance)
**File:** `/Users/jon/projects/sigra/lib/sigra/scope.ex:16-25`
```elixir
@spec build(scope_module :: module(), user :: struct() | map() | nil, opts :: keyword()) :: struct()
def build(scope_module, user, opts \\ []) ...   # line 18
```
The `build/3` constructor sets only four fields: `user`, `active_organization`, `membership`,
`impersonating_from` (`scope.ex:19-24`). CONTEXT D-15 says a `RulesteadPolicy` reads the full
`current_scope` field set per FEATURES.md:26 (`:user`, `:active_organization`,
`:active_organization_id`, `:membership`, `:role`, `:auth_method`, `:impersonating_from`,
`:token_id`, `:id`). **Nuance for the recipe:** the full field bus lives on the **generated
`%Scope{}` struct** in the host app (the moduledoc at `scope.ex:3-5` says the struct itself is
generated into the host app; this module only constructs via `struct/2` reflection). So the
recipe correctly pins `scope.ex:16-25` for the `build/3` shape AND cites FEATURES.md:26 for the
complete field list a policy may read — the two are not in conflict; `build/3` is the
library-side constructor, the field set is the host-generated struct surface. `[VERIFIED:
local file]`

### `mix.exs` edit targets — ✅ ALL LINE NUMBERS CONFIRMED, ZERO DRIFT
**File:** `/Users/jon/projects/sigra/mix.exs`

| CONTEXT claim | Actual line(s) | Status |
|---------------|----------------|--------|
| `extras:` entry `"...companion-libs/mailglass.md"` ~line 227 | **line 227** | ✅ EXACT |
| `skip_undefined_reference_warnings_on:` Phase 133 comment header lines 174-175 | **lines 174-175** | ✅ EXACT |
| Four skip-warnings entries lines 176-179 | **lines 176-179** | ✅ EXACT |
| `groups_for_extras:` `"Companion Libraries"` regex ~line 233 (read-only) | **line 233** | ✅ EXACT |

**Edit detail the planner must encode (D-16):**
1. **Add block:** `mix.exs:227` currently reads
   `        "guides/recipes/companion-libs/mailglass.md"` with **NO trailing comma** (it is the
   last `extras:` element before the `]` on line 228). The edit must add a trailing comma to
   line 227 AND append the four new entries:
   ```elixir
   "guides/recipes/companion-libs/accrue.md",
   "guides/recipes/companion-libs/lockspire.md",
   "guides/recipes/companion-libs/relyra.md",
   "guides/recipes/companion-libs/rulestead.md"
   ```
   (last entry `rulestead.md` has no trailing comma; closing `]` follows.)
2. **Remove block:** delete `mix.exs:174-179` — the 2-line Phase 133 comment header (174-175)
   PLUS the four entries (176-179). Note `mix.exs:173` (`mailglass.md` skip-warnings entry,
   from Phase 132) ends with a comma before the deleted block; after removal, the element
   above the closing `]` (line 180) is `"...companion-libs/mailglass.md"` on line 173 — that
   line must have its trailing comma removed to avoid a dangling comma before `]`. **Planner:
   verify the trailing-comma state of line 173 at edit time** (currently line 173 ends with
   `,`). `[VERIFIED: local file]`

> **Atomic-edit rationale (D-17) re-confirmed:** `guides/introduction/suite-integration.md`
> (Phase 133) already cross-links to all four recipes — fan-out matrix lines 76-79 and
> "Where to next" lines 137-140 reference `accrue.html`, `lockspire.html`, `relyra.html`,
> `rulestead.html`. The `skip_undefined_reference_warnings_on:` entries exist *only* to
> bridge the 133→134 window. ExDoc resolves the cross-links cleanly *only once all four files
> exist AND the suppressions are removed* — hence the add+remove must land atomically.
> `[VERIFIED: grep suite-integration.md]`

### v1.27 ENT-SSO surface (D-11) — ✅ ALL FILES EXIST
- `lib/sigra/enterprise_connections.ex` ✅
- `lib/sigra/enterprise_routing.ex` ✅
- `lib/sigra/oauth/enterprise_reconciliation.ex` ✅
- `lib/sigra/audit.ex` ✅ (Accrue `log_audit/2` bridge reference, D-03)
`[VERIFIED: ls]`

## DISCREPANCIES (highest-value findings)

### §1 — Lockspire callback count: 4 required + 2 optional, NOT 5 + 1
**Where CONTEXT says it:** D-06 + canonical_refs line ("5 required + 1 optional").
**What the source says:** `account_resolver.ex:36` lists BOTH `redirect_for_logout: 2` AND
`verify_backchannel_user_code: 3` in `@optional_callbacks`. So 4 required + 2 optional.
**Planner action:** Write the recipe describing **4 required** (`resolve_current_account/2`,
`resolve_account/2`, `build_claims/2`, `redirect_for_login/2`) + **2 optional**
(`verify_backchannel_user_code/3` for CIBA, `redirect_for_logout/2`). Pin by line-range
`lib/lockspire/host/account_resolver.ex:14-39`. Confidence: HIGH.

### §2 — Rulestead `enabled?("flag", conn)` DOES NOT EXIST (STACK.md fabrication)
**Where it's claimed:** STACK.md:34 (`Rulestead.enabled?("flag", conn)`), STACK.md:112 ("Show
`Rulestead.enabled?` from a Sigra-protected controller"), CONTEXT D-14 references the README
form `Rulestead.enabled?("flag", conn)` at "line ~111".
**What the source + README actually say:**
- **No `Rulestead.enabled?("flag", conn)` exists anywhere** in `rulestead.ex` or `README.md`
  (grep returns only `Rulestead.Runtime.enabled?(...)`).
- The root-module low-level contract is `Rulestead.enabled?/2` = `(flag_payload, context)`
  returning `{:ok, boolean()} | {:error, Error.t()}` (`rulestead.ex:1189-1194`). It takes a
  **flag payload map**, not a string flag key, and a `%Rulestead.Context{}` (or keyword/map),
  not a `conn`.
- The Phoenix/snapshot convenience form in the README is
  **`Rulestead.Runtime.enabled?("production", "checkout_v2", context)`** — a **3-arity**
  `(environment_key, flag_key, context)` returning `{:ok, boolean()}` (README:84-85). This is
  the form that takes a string flag key, but it takes `context` (often
  `conn.assigns[:rulestead_context]` per README:82), NOT `conn` directly.
- README **line 111** is `rulestead_admin "/admin/flags", policy: MyApp.RulesteadPolicy` — the
  admin mount, NOT an `enabled?` example. CONTEXT D-14's "README convenience example
  `Rulestead.enabled?("flag", conn)` at line ~111" conflates two different README locations
  and invents a non-existent signature.

**Planner action (resolves D-14):** The recipe must be honest about Rulestead's layering:
1. **Canonical adopter entry point for a Sigra-protected controller:**
   `Rulestead.Runtime.enabled?(environment_key, flag_key, context)` (README:84-85) — pin this
   as the convenience form, building `context` from `conn.assigns` (the recipe shows deriving
   a `%Rulestead.Context{}` from `current_scope` — see §3 / D-15).
2. **Low-level contract:** `Rulestead.enabled?/2` = `(flag_payload, context)`
   (`rulestead.ex:1189-1194`) — cite as the explicit payload-first contract the Runtime form
   wraps (README:88-89 confirms "The explicit contract remains flag payload +
   `%Rulestead.Context{}`").
3. **DO NOT write `Rulestead.enabled?("flag", conn)`** — it is a fabrication and would mislead
   adopters (and, if autolinked, risk a `mix docs` warning). Pin both real line ranges so the
   recipe is honest about the layering exactly as D-14 directs. Confidence: HIGH.

### §3 — Rulestead policy callback is `can?/4`, NOT an `authorize`-shaped callback
**Where CONTEXT points:** D-15 says "Reference the Rulestead `Admin.Authorizer` contract
(`rulestead/lib/rulestead/admin/authorizer.ex`) for the policy callback shape."
**What the source says:** `Admin.Authorizer` is `@moduledoc false` (internal, line 3) and its
public functions are `authorize/4`, `authorize_governed_action/4`, etc. — but those are the
**library's internal gate**, not the host policy contract. The actual **host-supplied policy
callback** is invoked at `authorizer.ex:149`:
```elixir
policy -> policy.can?(actor, action, resource, environment_key)
```
plus optional `policy_flag` callbacks `change_request_required?/4` and `allow_self_approval?/4`
(`authorizer.ex:227-244`, looked up via `function_exported?(policy, callback, 4)`).
**The host `MyApp.RulesteadPolicy` implements `can?/4`** = `(actor, action, resource,
environment_key) :: boolean()`, configured via `config :rulestead, :admin_policy,
MyApp.RulesteadPolicy` (`authorizer.ex:177-178`), and mounted via
`rulestead_admin "/admin/flags", policy: MyApp.RulesteadPolicy` (README:111).
**Actor shape:** `can?/4` receives a normalized actor map `%{id, display, roles}` where
`roles` is a list of `:viewer | :editor | :admin` (`authorizer.ex:294-348`). The recipe's
`RulesteadPolicy` derives `roles` from `current_scope.role` (FEATURES.md:26).
**Planner action:** Pin the host policy contract to **`can?/4`** (`authorizer.ex:146-150` for
the call site; `authorizer.ex:294-308` for the actor normalization shape). Optionally mention
the governance flag callbacks. Do NOT pin the internal `authorize/4` as the host contract.
Confidence: HIGH.

> Note: `Admin.Authorizer` lives in the runtime `rulestead` package but `rulestead_admin` (the
> mounted UI) is a **separate Hex package** (`{:rulestead_admin, "~> 0.1"}`, README:97-98).
> The recipe's admin-mount example needs BOTH `{:rulestead, "~> 0.1"}` and
> `{:rulestead_admin, "~> 0.1"}` — D-13 pins `validated_against: rulestead ~> 0.1`; the recipe
> should note the admin UI requires the companion `rulestead_admin` package too.

### §4 — Rulestead version: `~> 0.1` confirmed installable; `1.0.0` is narrative-only
README:43, 97 both ship `{:rulestead, "~> 0.1"}`. STACK.md:34-36 documents the `1.0.0
narrative GA vs 0.1.x Hex line` mismatch. D-13's "ONE neutral Prerequisites sentence" stands —
no change needed. Confidence: HIGH.

## Phase 132 Template Shape (the EXACT structure to mirror)

From `threadline.md` (158 lines) + `mailglass.md` (130 lines), the LOCKED template is:

1. **Line 1-2:** HTML comments — `<!-- validated_against: <lib> ~> <ver> -->` then
   `<!-- last_validated: <YYYY-MM-DD> -->`.
2. **Line 3:** `# Recipe: Sigra + <Lib> (<one-line purpose>)`.
3. **(blank line 4)**
4. **Line 5:** visible `Validated against: \`<lib> ~> <ver>\` as of <YYYY-MM-DD>`.
5. **(blank line 6)**
6. **Line 7:** the banner blockquote — EXACT form:
   `> **Sigra works fully standalone.** <Lib> is an optional integration; Sigra ships without it, and removing the entry below returns Sigra to standalone operation with no further changes.`
   (CONTEXT generalizes to "removing the *wiring* below" for multi-step recipes — both
   threadline and mailglass use "the entry below"; match per-recipe phrasing to whether the
   integration is one config entry or a multi-step wiring.)
7. **`## What this is`** — a 2-row (or more) role table: `| Role | Library | Responsibility |`.
8. **`## Prerequisites`** — bulleted; "Sigra <X> must be green first" framing.
9. **`## \`mix.exs\` snippet`** — fenced `elixir` `defp deps do` block. For host-only deps
   (accrue/lockspire/relyra/rulestead) state **"Host app only — Sigra does not add <Lib> as a
   dependency"** (mailglass.md:30 precedent).
10. **(per-recipe middle sections)** — config block / walkthrough / contract-pin prose. Contract
    pinned **by line-range reference**, NOT by copying sister-lib code (D-07). e.g. threadline:
    "Sigra invokes `Threadline.record_action/2` per `lib/sigra/audit/forwarders/threadline.ex:290-307`".
11. **`## Failure modes`** — numbered `### N. <failure>` subsections. REQUIRED.
12. **`## Non-goals`** — bulleted; "**no `--with-<lib>` install flag**" framing. REQUIRED.
13. **`## See also`** — bulleted `[Title](relative.html)` cross-links to flows + sibling
    recipes + `../introduction/suite-integration.html`. (threadline also adds a `### Custom
    forwarders` trailing subsection — optional per recipe.)

**Cross-link form:** sibling recipes use `./<name>.html` (e.g. `./mailglass.html`); flows use
`../flows/<name>.html`; suite narrative `../introduction/suite-integration.html`;
companion-oauth-provider is `../companion-oauth-provider.html` (one dir up from
`companion-libs/`). `[VERIFIED: threadline.md, mailglass.md, companion-oauth-provider.md]`

**`companion-oauth-provider.md` (52 lines)** is structurally LIGHTER (architectural, not a
recipe-template instance — no validated_against block, no banner, no Failure modes). It names
`mix lockspire.install --sigra-host` (line 38) and the AccountResolver seam. The new
`lockspire.md` cross-links to it (`../companion-oauth-provider.html`) and does NOT duplicate
its architecture-level framing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recipe section structure | A bespoke layout per recipe | Copy `threadline.md` section order exactly | Phase 136 PROOF-01 may grep-assert banner/Failure modes/Non-goals headings; uniform structure passes the deferred contract fixture. |
| Sister-lib API description | Paraphrasing from memory | Pin by line-range to the local checkout | D-07; keeps the recipe honest when a sister lib revs its API. STACK.md already drifted (§2, §3) — paraphrase-from-memory is exactly the failure mode. |
| Session minting (Relyra) | A custom session helper | `Sigra.Auth.create_session/4` (`auth.ex:1284`) | Exists, audited, org-scope-aware. |
| Seat-limit gate (Accrue) | Sigra-side seat logic | Host `before_add_member/4` callback | Sigra owns NO seat-limit logic (D-01). |
| Lockspire glue | `sigra_lockspire` package | Host config + AccountResolver stub | ADR 001. |

## Common Pitfalls

### Pitfall 1: Pinning `Sigra.Session.create_session/3` (from STACK.md:111)
**What goes wrong:** Adopters copy a recipe referencing a non-existent function → runtime
`UndefinedFunctionError`; `mix docs --warnings-as-errors` may also flag the autolink.
**Avoid:** Pin `Sigra.Auth.create_session/4` (`auth.ex:1284`) per D-09. (THE load-bearing pin.)

### Pitfall 2: Writing `Rulestead.enabled?("flag", conn)` (from STACK.md:34/112)
**What goes wrong:** That signature does not exist; the real forms are `Rulestead.enabled?/2`
(payload, context) and `Rulestead.Runtime.enabled?/3` (env, flag, context). A copy-paste
adopter hits an arity/argument error.
**Avoid:** Pin `Rulestead.Runtime.enabled?/3` as the convenience form + `Rulestead.enabled?/2`
as the low-level contract (§2).

### Pitfall 3: Describing Lockspire as "5 required + 1 optional"
**What goes wrong:** A host might over-implement `verify_backchannel_user_code/3` thinking it
is mandatory (it is CIBA-only and optional in `~> 1.2`).
**Avoid:** Describe as 4 required + 2 optional (§1).

### Pitfall 4: Splitting the `mix.exs` add+remove across commits
**What goes wrong:** Any intermediate state where the recipes exist but suppressions are still
present (or vice versa) opens a `mix docs --warnings-as-errors` failure window because the
Phase 133 suite narrative already cross-links the four `.html` targets.
**Avoid:** One atomic two-block edit (D-16/D-17).

### Pitfall 5: Trailing-comma breakage in `mix.exs`
**What goes wrong:** The `extras:` `mailglass.md` line (227) has no trailing comma; the
skip-warnings `mailglass.md` line (173) DOES. Editing without adjusting commas yields a syntax
error → `mix compile`/`mix docs` fails.
**Avoid:** Add comma to line 227 when appending; remove the now-dangling comma from line 173
after deleting 174-179.

### Pitfall 6: A banned phrase slips into prose
**What goes wrong:** "seamlessly," "just works," "production-ready out of the box," "the
recommended way" fails the D-20 grep gate.
**Avoid:** Run the D-20 grep pre-commit; review section drafts against the banned list.

## Runtime State Inventory

This is a docs-only phase (four new `.md` files + one `mix.exs` config edit). It renames
nothing and migrates no data.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no schema, migration, or datastore touched. | None |
| Live service config | None — `mix.exs` is build config, not runtime/service config. | None |
| OS-registered state | None. | None |
| Secrets/env vars | None. | None |
| Build artifacts | ExDoc HTML output (`doc/`) regenerates on `mix docs`; not committed. | None — regenerated by the gate. |

**Nothing found in any category** — verified by scope (docs + one `mix.exs` `extras:`/skip
list edit; no `lib/` runtime code, no schema, no service config).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix docs` (ex_doc) | The phase verification gate (`mix docs --warnings-as-errors`) | Assumed ✓ (ex_doc `~> 0.40` in mix.exs per CLAUDE.md) | ~> 0.40 | none — blocking if absent |
| `rg` (ripgrep) | D-20 banned-phrase grep | Assumed ✓ (used in prior phases' gates) | — | `grep -riE` equivalent |
| Local sister-repo checkouts | Verifying line-range pins | ✓ all four present + verified this session | — | — |

**Missing dependencies with no fallback:** none confirmed missing. The planner should encode a
Wave-0/setup check that `mix docs` is runnable (the v1.28 PROOF-01 near-miss was a content
warning, not a missing-tool problem). `rg` has a `grep -riE` fallback for the banned-phrase
guard. `[ASSUMED]` for ex_doc/rg presence — not probed this session because the working tree's
prior phases (132, 133) ran the same gates successfully.

## Validation Architecture

> nyquist_validation is enabled (no `workflow.nyquist_validation: false` in config). This is a
> docs-only phase, so the validation surface is deterministic shell checks, not a test suite.

### "Validated" definition (concrete acceptance criteria)
A Phase 134 deliverable is **validated** when ALL of the following are true:
1. `mix docs --warnings-as-errors` exits 0 (no undefined-reference warnings, no broken
   autolinks) AFTER the four recipes exist AND the four `skip_undefined_reference_warnings_on:`
   entries + their Phase 133 comment header are removed.
2. The D-20 banned-phrase grep returns **zero matches** across all four files.
3. Each of the four recipes carries the required structural sections (banner, validated_against
   block, Failure modes, Non-goals, See also).
4. The `mix.exs` two-block edit is present and the file compiles (`mix compile` clean).

### "Test" Framework (validation harness)
| Property | Value |
|----------|-------|
| Framework | Shell assertions (no ExUnit test for docs); `mix docs` + `rg`/`grep`. The deferred recipe-contract ExUnit fixture is OUT OF SCOPE (Phase 136 may add it). |
| Config file | `mix.exs` `docs/0` (the `skip_undefined_reference_warnings_on:` + `extras:` lists). |
| Quick run command | `rg -i "seamlessly\|just works\|production-ready out of the box\|the recommended way" guides/recipes/companion-libs/{accrue,lockspire,relyra,rulestead}.md` |
| Full suite command | `mix docs --warnings-as-errors` |

### Phase Requirements → Validation Map
| Req ID | Behavior | Check Type | Automated Command | Exists? |
|--------|----------|-----------|-------------------|---------|
| RC-03 | `accrue.md` exists with required sections + valid autolinks | smoke + docs | `test -f guides/recipes/companion-libs/accrue.md && mix docs --warnings-as-errors` | ❌ Wave 0 (file created in step 1) |
| RC-04 | `lockspire.md` exists, cross-links `companion-oauth-provider.html` | smoke + docs | `test -f guides/recipes/companion-libs/lockspire.md && mix docs --warnings-as-errors` | ❌ Wave 0 (step 2) |
| RC-05 | `relyra.md` exists, pins `Sigra.Auth.create_session/4` | smoke + docs | `test -f guides/recipes/companion-libs/relyra.md && mix docs --warnings-as-errors` | ❌ Wave 0 (step 3) |
| RC-06 | `rulestead.md` exists, pins real `enabled?` surface | smoke + docs | `test -f guides/recipes/companion-libs/rulestead.md && mix docs --warnings-as-errors` | ❌ Wave 0 (step 4) |
| RC-03..06 | No banned phrases in any recipe | grep guard | D-20 command (above), MUST return zero matches | ❌ Wave 0 (step 6) |
| (D-16) | `mix.exs` atomic edit applied + compiles | smoke | `mix compile --warnings-as-errors` (or `mix compile`) | ❌ Wave 0 (step 5) |

### Per-recipe structural assertions (encode as acceptance criteria; Phase 136 may grep-assert)
For each of the four files, the planner's acceptance criteria should assert presence of:
- Line 1-2: `validated_against:` + `last_validated:` HTML comments.
- Line 5: visible `Validated against: \`<lib> ~> <ver>\` as of <date>` line.
- Line 7: the `> **Sigra works fully standalone.**` banner blockquote.
- A `## Failure modes` heading.
- A `## Non-goals` heading.
- A `## See also` heading.
- Correct `validated_against:` pins: `accrue ~> 1.2`, `lockspire ~> 1.2`, `relyra ~> 1.2`,
  `rulestead ~> 0.1`.

Suggested heading-presence check (per file):
```bash
for f in accrue lockspire relyra rulestead; do
  p="guides/recipes/companion-libs/$f.md"
  grep -q "^## Failure modes" "$p" && grep -q "^## Non-goals" "$p" \
    && grep -q "^> \*\*Sigra works fully standalone\.\*\*" "$p" \
    && grep -q "validated_against:" "$p" || echo "FAIL: $f missing required section"
done
```

### Sampling Rate
- **Per task (each recipe drafted):** the per-file heading-presence check above + the D-20
  banned-phrase grep scoped to that file.
- **Per `mix.exs` edit (step 5):** `mix compile` clean (catches comma breakage).
- **Phase gate (step 6 / pre-commit):** `mix docs --warnings-as-errors` exit 0 + D-20 grep
  across all four files zero matches. This is the gate Phase 136 PROOF-01 re-runs at close.

### Wave 0 Gaps
- [ ] `guides/recipes/companion-libs/accrue.md` — covers RC-03 (does not yet exist)
- [ ] `guides/recipes/companion-libs/lockspire.md` — covers RC-04 (does not yet exist)
- [ ] `guides/recipes/companion-libs/relyra.md` — covers RC-05 (does not yet exist)
- [ ] `guides/recipes/companion-libs/rulestead.md` — covers RC-06 (does not yet exist)
- [ ] `mix.exs` two-block edit (D-16) — not yet applied
- No new test-framework install needed (docs-only; shell-check validation).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ex_doc `~> 0.40` and `rg` are present on the execution machine | Environment Availability | LOW — both used successfully in Phases 132/133; `rg` has a `grep -riE` fallback. |
| A2 | The installed Lockspire `~> 1.2` Hex package matches the local checkout's `account_resolver.ex` surface (4 req + 2 opt) | §1 | LOW-MEDIUM — recipe pins by line-range to the local checkout; if Hex `~> 1.2` differs, `validated_against` still scopes the claim. Sister-repo local checkout is the authority CONTEXT directed me to use. |
| A3 | Relyra `consume_response/3` returns a subject the host reads off `%Relyra.LoginResult{}` (per moduledoc line 11) | Relyra finding | LOW — moduledoc states it; the recipe pins the moduledoc, not an invented field path. |

All other claims in this research are `[VERIFIED: local checkout/file]` against files read this
session.

## Open Questions (RESOLVED)

1. **RESOLVED — Relyra `LoginResult` field for the authenticated subject**
   - What we know: `consume_response/3` returns `{:ok, map()}`; moduledoc says the success
     value is a `%Relyra.LoginResult{}`.
   - What's unclear: the exact field name the host reads to get the subject/email for
     `Sigra.Auth.create_session/4`'s `user` arg.
   - Recommendation: the recipe should pin the moduledoc (`relyra.ex:6-12`) and describe the
     hand-off at the contract level ("read the authenticated subject from the
     `%Relyra.LoginResult{}` Relyra returns, look up/create your Sigra user, then
     `Sigra.Auth.create_session/4`") rather than inventing a `result.subject` field. If a
     precise field is wanted, the planner can have the executor read `Relyra.LoginResult`
     during step 3 — it is a cheap local-checkout read, not external research.

2. **RESOLVED — Whether `rulestead_admin` package belongs in the recipe's primary `mix.exs` snippet**
   - What we know: the runtime `rulestead` package provides `enabled?`; the mounted admin needs
     the separate `rulestead_admin` package.
   - Recommendation: show `{:rulestead, "~> 0.1"}` as the core dep; show `{:rulestead_admin,
     "~> 0.1"}` only in the (optional) admin-mount subsection, mirroring README:91-101. D-13's
     `validated_against` pins the runtime `rulestead ~> 0.1`.

## Sources

### Primary (HIGH confidence — verified this session)
- `/Users/jon/projects/accrue/accrue/lib/accrue/auth.ex:1-90` — `Accrue.Auth` behaviour
- `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex:1-39` — AccountResolver
- `/Users/jon/projects/relyra/lib/relyra.ex:1-160` — `start_login/3`, `consume_response/3`
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead.ex:1180-1219` — `enabled?/2`
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex:1-374` — `can?/4`
- `/Users/jon/projects/rulestead/README.md:30-160` — `Runtime.enabled?/3`, `~> 0.1`, admin mount
- `/Users/jon/projects/sigra/lib/sigra/auth.ex:1270-1314` — `create_session/4`
- `/Users/jon/projects/sigra/lib/sigra/session.ex` (grep) — NO `create_session`
- `/Users/jon/projects/sigra/lib/sigra/organizations/callbacks.ex:1-49` — Accrue seams
- `/Users/jon/projects/sigra/lib/sigra/hooks.ex:1-103` — lifecycle registry
- `/Users/jon/projects/sigra/lib/sigra/scope.ex:1-35` — `Scope.build/3`
- `/Users/jon/projects/sigra/mix.exs:155-244` — `docs/0` (extras, skip-warnings, groups)
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/threadline.md` (full, 159 lines)
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/mailglass.md:1-35`
- `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md` (full, 52 lines)
- `/Users/jon/projects/sigra/guides/introduction/suite-integration.md` (grep, lines 76-79, 137-140)

### Secondary (planning artifacts — context, not re-derived)
- `/Users/jon/projects/sigra/.planning/phases/134-recipe-only-companion-libraries/134-CONTEXT.md`
- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` (RC-03..06, Out-of-Scope)
- `/Users/jon/projects/sigra/.planning/research/STACK.md:28-134` — **NOTE: lines 34, 111, 112
  contain the discrepancies documented above.**

## Metadata

**Confidence breakdown:**
- Sigra-side seams: HIGH — every pin read directly; `create_session/4` and the `mix.exs` line
  numbers confirmed exact.
- Sister-repo contracts: HIGH — all four read from local checkouts; three discrepancies vs
  STACK/CONTEXT documented with corrected line ranges.
- Template shape: HIGH — captured verbatim from the two Phase 132 canary recipes.
- Validation architecture: HIGH — deterministic shell gates, no ambiguity.

**Research date:** 2026-05-28
**Valid until:** ~2026-06-28 for the Sigra-side pins (stable internal API); sister-repo line
ranges valid until the next companion-lib release that touches the cited modules — the
`validated_against:` pins scope this risk by design.
