---
phase: 15-audit-integration
plan: 02
type: execute
wave: 2
depends_on:
  - 15-01
files_modified:
  - lib/sigra/auth.ex
  - lib/sigra/mfa.ex
  - lib/sigra/account.ex
  - lib/sigra/oauth.ex
  - lib/sigra/api_token.ex
  - lib/sigra/plug/load_active_organization.ex
  - lib/sigra/workers.ex
  - lib/sigra/workers/account_deletion.ex
  - lib/sigra/credo/no_log_safe2_in_lib.ex
  - lib/sigra/testing.ex
  - .credo.exs
  - test/sigra/workers/behaviour_test.exs
  - test/sigra/workers/account_deletion_test.exs
  - test/sigra/credo/no_log_safe2_in_lib_test.exs
  - test/sigra/testing/assert_audit_logged_test.exs
files_reviewed_unchanged:
  # Category 3 sites that correctly remain at nil scope per D-26 — re-read and
  # classified by Task 1 but require no source edits.
  - lib/sigra/lockout.ex
  - lib/sigra/suspicious_login.ex
autonomous: true
requirements:
  - AUD-02
  - AUD-03
  - AUD-04
  - AUD-05

deviations:
  - id: D-31-refinement
    decision: D-31
    original: "assert_audit_logged(repo, fields)"
    revised: "assert_audit_logged(expected :: map(), opts :: keyword())"
    rationale: "RESEARCH.md §5 surfaced the existing `assert_audit_event/2` at lib/sigra/testing.ex:1150 with signature `(map, keyword)` requiring `:repo` + `:audit_schema` in opts. D-31 predated that discovery. A `(repo, fields)` shim would need to synthesize opts via magic (process dict / module attribute), which is worse DX and violates 'thin wrapper per REQ DX-02'. The spirit of D-31 is preserved (thin alias); the signature is the implementation detail."

must_haves:
  truths:
    - "session.create audit fires AFTER select_active_organization so the first login audit carries the real organization_id"
    - "Post-auth audit sites in lib/sigra/** pass a real Sigra.Scope, not nil"
    - "Pre-auth sites with a resolved user pass Sigra.Scope.build(scope_module, user, active_organization: nil) and also set target_id: user.id"
    - "Failed-login with unknown email passes nil scope and nil target_id (IP + User-Agent only, per OWASP ASVS V7.1)"
    - "Sigra.Workers behaviour exists as a pure @callback contract that compiles without Oban"
    - "Sigra.Workers.new/3 fails fast when args are missing organization_id or actor_id keys"
    - "Sigra.Workers.AccountDeletion is refactored as the reference implementation and emits account.deletion_executed with reconstructed scope"
    - "Sigra.Credo.NoLogSafe2InLib custom check fires on arity-2 Sigra.Audit.log_safe calls in lib/sigra/** and stays silent on the shim + tests"
    - "Sigra.Testing.assert_audit_logged/2 wraps the existing assert_audit_event helper with a (map, keyword) signature"
  artifacts:
    - path: "lib/sigra/workers.ex"
      provides: "Sigra.Workers behaviour + new/3 enqueue validator + perform-time Map.fetch!"
      contains: "@callback perform(scope"
    - path: "lib/sigra/workers/account_deletion.ex"
      provides: "Reference implementation of Sigra.Workers behaviour"
      contains: "@behaviour Sigra.Workers"
    - path: "lib/sigra/credo/no_log_safe2_in_lib.ex"
      provides: "Custom Credo check banning arity-2 log_safe in lib/sigra/**"
      contains: "use Credo.Check"
    - path: ".credo.exs"
      provides: "Credo config registering NoLogSafe2InLib"
      contains: "Sigra.Credo.NoLogSafe2InLib"
    - path: "lib/sigra/testing.ex"
      provides: "assert_audit_logged/2 helper"
      contains: "def assert_audit_logged"
  key_links:
    - from: "lib/sigra/auth.ex (login path)"
      to: "Sigra.Audit.log_safe/3 with real scope"
      via: "session.create + auth.login.success fire AFTER select_active_organization"
      pattern: "Audit\\.log_safe.*session.create.*scope"
    - from: "lib/sigra/workers/account_deletion.ex"
      to: "Sigra.Scope.build/3"
      via: "perform/1 reconstructs scope via Module.safe_concat on stringified args"
      pattern: "Sigra\\.Scope\\.build"
---

<objective>
Replace the placeholder `nil` scopes introduced in Plan 15-01 with real scopes at Category 1/2/3 call sites, reorder the `session.create` audit to fire after org selection, introduce the `Sigra.Workers` behaviour with `AccountDeletion` as the reference implementation, add the custom Credo check that prevents regression, and add `assert_audit_logged/2` to `Sigra.Testing`.

Purpose: Plan 15-01 left the codebase mechanically uniform but semantically flat — every site logs with `nil` scope. This plan puts the real scope at sites that have it, reorders the audit emission that caused the "first login audit has no org" bug, introduces the worker contract that makes v1.2 audits work in background jobs, and ships the Credo check that structurally prevents drift. Per D-25, this is the semantic-enrichment plan and runs strictly after 15-01.

Output: Enriched call sites, reordered login audit, Sigra.Workers behaviour + reference worker, Credo check + registration, and the new testing helper.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/15-audit-integration/15-CONTEXT.md
@.planning/phases/15-audit-integration/15-RESEARCH.md
@.planning/phases/15-audit-integration/15-VALIDATION.md
@.planning/phases/15-audit-integration/15-01-SUMMARY.md

@lib/sigra/audit.ex
@lib/sigra/scope.ex
@lib/sigra/auth.ex
@lib/sigra/workers/account_deletion.ex
@lib/sigra/testing.ex

<interfaces>
<!-- Contracts established by Plan 15-01 that this plan consumes directly. -->

From Plan 15-01 — Sigra.Audit public API:

```elixir
def log_safe(action, scope, opts) when is_binary(action) and is_list(opts)
# scope is duck-typed on %{user, active_organization, impersonating_from}
# nil scope allowed; caller-supplied opts win merge
```

From Plan 15-01 — Sigra.Scope.build/3:

```elixir
Sigra.Scope.build(scope_module, user, opts)
#   opts: [active_organization: org, membership: m]
#   impersonating_from is always nil in v1.1
```

From Phase 13 / Phase 14 — host Scope struct fields:
`:user, :active_organization, :membership, :impersonating_from`

Existing `Sigra.Testing.assert_audit_event/2` (confirmed at lib/sigra/testing.ex:1150):

```elixir
@spec assert_audit_event(map(), keyword()) :: true
def assert_audit_event(expected, opts) when is_map(expected) and is_list(opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  position = Keyword.get(opts, :position, 0)
  # ...reads latest row and matches expected map...
end
```

Signature is `(map, keyword)` — NOT `(repo, fields)`. `assert_audit_logged/2`
in this plan MUST match that shape (see D-31 deviation in frontmatter and
Task 3 action text).

New Sigra.Workers contract (THIS plan):

```elixir
defmodule Sigra.Workers do
  @callback perform(scope :: term() | nil, args :: map()) ::
              :ok | {:ok, term()} | {:error, term()} | {:snooze, pos_integer()}

  @spec new(module(), map(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def new(worker, args, opts \\ [])
  # Fails fast with ArgumentError if args is missing :organization_id or :actor_id keys
  # (nil values permitted; only absent keys fail)
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: session.create reorder + semantic enrichment sweep (Categories 1, 2, 3)</name>
  <files>
    lib/sigra/auth.ex,
    lib/sigra/mfa.ex,
    lib/sigra/account.ex,
    lib/sigra/oauth.ex,
    lib/sigra/api_token.ex,
    lib/sigra/plug/load_active_organization.ex
  </files>
  <read_first>
    - lib/sigra/auth.ex lines 900-1200 (session.create emission site + maybe_assign_active_organization)
    - lib/sigra/audit.ex (confirm log_safe/3 from 15-01)
    - lib/sigra/scope.ex (confirm build/3 from 15-01)
    - lib/sigra/lockout.ex (confirm Category 3 classification — 1 nil-scope call site, no edits)
    - lib/sigra/suspicious_login.ex (confirm Category 3 classification — 1 nil-scope call site, no edits)
    - .planning/phases/15-audit-integration/15-CONTEXT.md D-26, D-27, D-28, D-29
    - .planning/phases/15-audit-integration/15-RESEARCH.md (auth.ex reorder specifics)
    - Each of the 6 target files (see every nil-placeholder site you touch)
  </read_first>
  <behavior>
    - First audit of a successful login (session.create + auth.login.success) carries a real organization_id when the user has an active org
    - Post-auth sites (everywhere scope is already in lexical scope) pass that scope instead of nil
    - Pre-auth sites with a resolved user (password_reset_request matching email, magic_link_request matching email, api.token_verify.failure with resolved user) pass a user-only scope via Sigra.Scope.build(scope_module, user, active_organization: nil) AND set target_id: user.id
    - Failed-login with unknown email passes nil scope AND nil target_id — only IP + User-Agent in metadata (no email hash per D-29, OWASP ASVS V7.1)
    - effective_user_id is derived by scope_fields/1 from scope.user — never manually asserted
    - Plug/load_active_organization.ex stays with its existing scope (already had one — just verify the migration from 15-01 kept it consistent)
    - lockout.ex and suspicious_login.ex call sites remain at nil scope (Category 3 — see classification in action §6)
  </behavior>
  <action>
    **STEP 0 (MANDATORY before any edit — do NOT rely on "approximate" line numbers).**

    Line numbers drift between the time this plan was written and the time it runs. Before editing `lib/sigra/auth.ex`, re-locate the structural anchors via grep and record the real line numbers in your working notes:

    ```
    grep -n 'session.create\|maybe_assign_active_organization\|auth.login.success' lib/sigra/auth.ex
    ```

    The structural anchor is the function name `maybe_assign_active_organization/6`, NOT any line number. The `session.create` audit emission moves from inside `create_session/4` (or wherever the grep locates it) to INSIDE `maybe_assign_active_organization/6`, right before the `{:ok, updated_session}` return (or equivalent success return path). If the function arity or name has changed since this plan was written, adapt to the current shape — the invariant is "session.create fires after scope synthesis with the real org."

    **1. Reorder `session.create` audit emission in `lib/sigra/auth.ex`** (D-27).

    Today (per RESEARCH.md, to be re-confirmed in STEP 0): `session.create` fires inside `create_session/4` BEFORE `maybe_assign_active_organization/6` runs. That means the first audit of the login has `organization_id: nil` even when the user has an active org — the v1.2 impersonation anchor bug.

    Move the `session.create` audit emission (and the `auth.login.success` emission if it is co-located) so it fires INSIDE `maybe_assign_active_organization/6` after the scope has been synthesized — immediately before the function's success return. The exact shape is:

    ```elixir
    # Old location (inside create_session/4, pre-org-selection) — DELETE the
    # Audit.log_safe call there.

    # New location: inside maybe_assign_active_organization/6, right before
    # the success return ({:ok, updated_session} or equivalent), emit:
    Sigra.Audit.log_safe("session.create", scope,
      repo: repo,
      audit_schema: audit_schema,
      metadata: %{session_id: session.id, ip: ip, user_agent: ua}
    )
    ```

    Where `scope` is the synthesized `%Scope{user: user, active_organization: org, membership: m, impersonating_from: nil}` that `maybe_assign_active_organization` produced. If that function currently returns only a session, thread the scope back out so the caller can emit the audit with it — but prefer keeping the emission INSIDE the function so the ordering is visually enforced and not re-orderable by a future refactor of the caller.

    Use `Sigra.Scope.build(scope_module, user, active_organization: org, membership: membership)` to build the scope in line where synthesis happens today. `scope_module` comes from the existing opts the function already takes.

    This is an INTENTIONAL BEHAVIOR CHANGE — document it via a CHANGELOG entry in Plan 15-03.

    **2. Semantic enrichment — Category 1 (post-auth, scope already in lexical scope):**

    For every remaining `Audit.log_safe(action, nil, opts)` site in `lib/sigra/auth.ex`, `mfa.ex`, `account.ex`, `oauth.ex`, `api_token.ex`, `plug/load_active_organization.ex` where a `%Scope{}` or equivalent is already lexically available, replace `nil` with that variable. Typical variable names: `scope`, `current_scope`. Read each call site's surrounding ~20 lines to confirm the scope is in lexical scope.

    **3. Category 2 (pre-auth, resolved user — D-28):**

    For each of these specific site patterns, construct a user-only scope AND set `target_id`:

    a. `password_reset_request` with matching email found (in `lib/sigra/account.ex` — locate via `grep -n "password_reset.*request" lib/sigra/account.ex`): change to
    ```elixir
    scope = Sigra.Scope.build(scope_module, user, active_organization: nil)
    Sigra.Audit.log_safe("account.password_reset_request", scope,
      repo: repo,
      audit_schema: audit_schema,
      target_id: user.id,
      metadata: %{email: user.email}
    )
    ```

    b. `magic_link_request` with matching email found (in `lib/sigra/account.ex`): same shape with action `"account.magic_link_request"`.

    c. `api.token_verify.failure` with resolved user (in `lib/sigra/api_token.ex`): same shape — scope from `Sigra.Scope.build(scope_module, user, active_organization: nil)` and `target_id: user.id`.

    **4. Category 3 (truly anonymous / unknown-email sites — D-26, D-29):**

    Leave scope as `nil`. Additionally explicitly set `target_id: nil` in opts (do not rely on absence). Sites:
    - `security.invalid_credentials` (failed login with unknown email) in `lib/sigra/auth.ex`
    - `password_reset_request` with email NOT matching a user
    - `magic_link_request` with email NOT matching a user

    For `security.invalid_credentials` specifically, metadata MUST contain only IP + User-Agent:
    ```elixir
    Sigra.Audit.log_safe("security.invalid_credentials", nil,
      repo: repo,
      audit_schema: audit_schema,
      target_id: nil,
      metadata: %{ip: ip, user_agent: ua}
    )
    ```
    No email, no email hash, no attempted-email string (D-29 — explicitly reject keyed HMAC as a design choice).

    **5. `lib/sigra/plug/load_active_organization.ex`:** verify the existing single `log_safe` call (the `organization.active_auto_reassigned` audit from Phase 14 D-14) now uses its real scope, not nil. It already had a scope in lexical context before Plan 15-01's mechanical sweep, so this is a semantic restoration.

    **6. `lib/sigra/lockout.ex` and `lib/sigra/suspicious_login.ex` — explicit Category 3 classification (no source edits):**

    Each of these files has 1 call site that was swept to `nil` scope in Plan 15-01. They fire in lockout / suspicious-login detection paths invoked from the post-auth-failure flow where the subject identity is either unknown (failed-login path) or deliberately not trusted (locked-account path). Per D-26, they are **Category 3** and correctly carry `target_id: user.id` when the user is resolvable (lockout always has a user id because lockout rows are keyed by user; suspicious_login has a user id when the login attempt successfully authenticated but tripped a heuristic) plus `nil` scope. **No semantic enrichment needed — leave them at `nil` scope.** Read both files during Task 1 to confirm they match this classification; if either has a real scope already in lexical context (unexpected), flag it in the SUMMARY and enrich. Otherwise these files are in the `files_reviewed_unchanged` frontmatter list on purpose.

    **Count expectation after this task:** of the 79 sites, approximately the majority (Categories 1, 2, 3) should no longer be `nil` — but the exact count is site-dependent. The acceptance criteria below target classes of sites, not absolute counts.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors && mix test --stale</automated>
  </verify>
  <done>
    session.create audit fires after org assignment; post-auth sites pass real scope; pre-auth sites with resolved user use Sigra.Scope.build + target_id; unknown-email failed-login sites stay nil with explicit target_id: nil and only IP+UA metadata; lockout.ex and suspicious_login.ex stay at nil scope per Category 3 classification.
  </done>
  <acceptance_criteria>
    - `grep -c "Sigra.Scope.build" lib/sigra/auth.ex` returns at least `1` (login scope synthesis site)
    - `grep -c "Sigra.Scope.build" lib/sigra/account.ex` returns at least `2` (password_reset_request + magic_link_request resolved-user paths)
    - `grep -c "Sigra.Scope.build" lib/sigra/api_token.ex` returns at least `1` (token_verify.failure with resolved user)
    - `grep -rc "Audit\\.log_safe([^,]*, nil," lib/sigra/ | awk -F: '{s+=$2} END {print s}'` returns less than `30` (majority of sites now pass a real scope; nil remains only for Category 3 truly-anonymous sites)
    - `grep -A3 "security.invalid_credentials" lib/sigra/auth.ex | grep -c "target_id: nil"` returns at least `1`
    - `grep -A5 "security.invalid_credentials" lib/sigra/auth.ex | grep -E "email:|email_hash" | wc -l` returns `0` (D-29: no email in failed-login metadata)
    - `grep -c "session.create" lib/sigra/auth.ex` returns at least `1`
    - **Reorder is structurally verified** (not by line number): `grep -A 30 'def maybe_assign_active_organization' lib/sigra/auth.ex | grep -c 'Audit.log_safe.*session.create'` returns `1` — the session.create emission is lexically inside `maybe_assign_active_organization/6`
    - `grep -A3 "Audit.log_safe" lib/sigra/lockout.ex | grep -c ", nil,"` returns at least `1` (Category 3 stays nil)
    - `grep -A3 "Audit.log_safe" lib/sigra/suspicious_login.ex | grep -c ", nil,"` returns at least `1` (Category 3 stays nil)
    - `mix compile --warnings-as-errors` exits 0
    - `mix test --stale` exits 0
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Sigra.Workers behaviour + new/3 validator + AccountDeletion reference refactor + tests</name>
  <files>
    lib/sigra/workers.ex,
    lib/sigra/workers/account_deletion.ex,
    test/sigra/workers/behaviour_test.exs,
    test/sigra/workers/account_deletion_test.exs
  </files>
  <read_first>
    - lib/sigra/workers/account_deletion.ex (existing full file — 84 lines, Oban-guarded at top)
    - lib/sigra/account/deletion.ex (where `schedule/3` lives — check if it currently enqueues the worker, and if not, confirm the enqueue site in host-app generated code or tests)
    - lib/sigra/workers/audit_cleanup.ex, token_cleanup.ex, email_delivery.ex (confirm these stay untouched per D-22)
    - lib/sigra/scope.ex (build/3 from 15-01)
    - lib/sigra/audit.ex (log_safe/3 from 15-01)
    - .planning/phases/15-audit-integration/15-CONTEXT.md D-18, D-19, D-20, D-21, D-22, D-23, D-24
  </read_first>
  <behavior>
    - Sigra.Workers module compiles with zero references to Oban at module level (D-18)
    - @callback perform(scope :: term() | nil, args :: map()) contract is declared
    - Sigra.Workers.new/3 raises ArgumentError if args is missing "organization_id" or "actor_id" keys (absent keys, not nil values). The check is over STRINGIFIED keys because Oban args are JSON-serialized.
    - Sigra.Workers.new/3 does NOT require "audit_schema" to be universally present — audit_schema is a worker-specific concern and belongs to the individual worker's arg list, not the behaviour contract (keeps the behaviour generic for future non-auditing workers that still need tenant context)
    - AccountDeletion implements @behaviour Sigra.Workers
    - AccountDeletion args include "audit_schema" (stringified) so the reconstructed perform/2 can emit account.deletion_executed audit
    - AccountDeletion.perform/1 (the Oban Worker callback) reconstructs a minimal scope via Sigra.Scope.build/3 using Module.safe_concat on stringified args, then delegates to perform/2 (the Sigra.Workers callback)
    - AccountDeletion emits account.deletion_executed audit via Sigra.Audit.log_safe/3 with the reconstructed scope
    - Hand-built jobs missing required args fail loudly with KeyError at perform time (belt + suspenders per D-20)
    - Any site in lib/ that enqueues AccountDeletion passes "audit_schema" alongside the other stringified module args; if no such site exists in lib/ today (worker is enqueued by generated app code only), this is a no-op for lib/ but MUST be reflected in the generator template updates in Plan 15-03
  </behavior>
  <action>
    **1. Create `lib/sigra/workers.ex`** — pure behaviour module, zero Oban references at module level:

    ```elixir
    defmodule Sigra.Workers do
      @moduledoc """
      Behaviour contract for Sigra-aware Oban workers that require tenant context.

      Workers implementing this behaviour:
      1. Accept stringified `"organization_id"` and `"actor_id"` args (nil values OK, absent keys NOT OK)
      2. Reconstruct a minimal `%Scope{}` in `perform/1` via `Sigra.Scope.build/3`
      3. Emit audits through `Sigra.Audit.log_safe/3` with the reconstructed scope

      ## Worker scopes are audit-only

      Host apps MUST NOT pass a worker-reconstructed scope to authorization
      functions. Worker scopes carry only `user.id` and `active_organization.id` —
      no request, no session, no membership. They exist solely so that
      `Sigra.Audit.log_safe/3` picks up the right IDs without a separate call shape.

      ## Not every worker needs this

      `Sigra.Workers.AuditCleanup`, `TokenCleanup`, and `EmailDelivery` are
      genuinely tenant-agnostic and deliberately do NOT implement this behaviour.
      Use it when and only when the worker emits tenant-relevant audits.

      ## v1.2 notes

      When impersonation ships in v1.2, workers enqueued by an impersonator will
      receive `"impersonating_from"` as an additional stringified arg, and
      `perform/1` will thread it through `Sigra.Scope.build/3` — a purely additive
      change. The current callback shape does NOT need to change.
      """

      @callback perform(scope :: term() | nil, args :: map()) ::
                  :ok | {:ok, term()} | {:error, term()} | {:snooze, pos_integer()}

      # Stringified keys — Oban serializes args via JSON so all keys become strings
      # by the time perform/1 runs. The behaviour validates the SAME stringified
      # keys at enqueue time so new/3 and fetch_arg!/2 agree.
      @required_keys ["organization_id", "actor_id"]

      @doc """
      Enqueue a job with fail-fast validation that required tenant keys are present.

      Nil values are allowed (pre-auth / system jobs); absent keys raise.

      `audit_schema` is intentionally NOT in the required-keys list — it is a
      worker-specific concern. Workers that emit audits add `"audit_schema"` to
      their own arg list and validate it in their own `perform/1`.
      """
      def new(worker, args, opts \\ []) when is_atom(worker) and is_map(args) do
        missing = Enum.reject(@required_keys, &Map.has_key?(args, &1))

        if missing != [] do
          raise ArgumentError,
                "Sigra.Workers.new/3: missing required args #{inspect(missing)}. " <>
                  "Every Sigra-aware worker must receive #{inspect(@required_keys)} " <>
                  "(nil values are permitted, absent keys are not)."
        end

        apply(worker, :new, [args, opts])
      end

      @doc """
      Fetches a required arg or raises KeyError. Call from inside `perform/1`
      before reconstructing scope. Belt + suspenders beyond `new/3` validation.
      """
      def fetch_arg!(args, key) when is_map(args) and is_binary(key) do
        Map.fetch!(args, key)
      end
    end
    ```

    **2. Refactor `lib/sigra/workers/account_deletion.ex`** to implement the behaviour (D-22, D-24):

    a. Add `@behaviour Sigra.Workers` inside the existing `if Code.ensure_loaded?(Oban.Worker) do` block.

    b. Expand args. Current args (from the existing file, lines 10-23): `"user_id"`, `"strategy"`, `"repo"`, `"user_schema"`, plus optional `"user_token_schema"`, `"session_store"`, `"identity_schema"`, `"api_token_schema"`, `"mfa_credential_schema"`, `"backup_code_schema"`.

    The args MUST now additionally include **8 new required keys** for the behaviour + audit emission:
    - `"organization_id"` (may be nil) — required by Sigra.Workers behaviour
    - `"actor_id"` (may be nil) — required by Sigra.Workers behaviour
    - `"scope_module"` (stringified module, e.g. `"Elixir.MyApp.Auth.Scope"`)
    - `"organization_schema"` (stringified module, may be nil string)
    - `"audit_schema"` (stringified module, e.g. `"Elixir.MyApp.AuditEvent"`) — **required for account.deletion_executed audit emission**

    Update the moduledoc `## Job Args` section to document all the new keys.

    Locate the enqueue site. Grep for `AccountDeletion` across `lib/`:
    ```
    grep -rn "AccountDeletion" lib/
    ```
    If no in-lib enqueue site exists (the worker is enqueued only from generated host-app code or from tests), document this in the Plan 15-02 SUMMARY under "AccountDeletion enqueue audit" and ensure Plan 15-03 updates the generator template (`priv/templates/sigra.install/**`) to pass the new args. If an in-lib enqueue site DOES exist (e.g. `lib/sigra/account/deletion.ex` or a context function), update it to pass the new args via `Sigra.Workers.new(Sigra.Workers.AccountDeletion, args, opts)`.

    c. Rewrite the Oban `perform/1` callback (the one that takes `%Oban.Job{args: args}`) to reconstruct scope, keep the existing deletion flow, and delegate audit emission to `perform/2`:

    ```elixir
    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      repo = Module.safe_concat([Sigra.Workers.fetch_arg!(args, "repo")])
      user_schema = Module.safe_concat([Sigra.Workers.fetch_arg!(args, "user_schema")])
      scope_module = Module.safe_concat([Sigra.Workers.fetch_arg!(args, "scope_module")])

      organization_schema =
        case Map.fetch!(args, "organization_schema") do
          nil -> nil
          mod -> Module.safe_concat([mod])
        end

      user_id = Sigra.Workers.fetch_arg!(args, "user_id")
      organization_id = Sigra.Workers.fetch_arg!(args, "organization_id")
      _actor_id = Sigra.Workers.fetch_arg!(args, "actor_id")
      _audit_schema_string = Sigra.Workers.fetch_arg!(args, "audit_schema")  # validated early, resolved inside perform/2

      user = repo.get(user_schema, user_id)

      active_org =
        case {organization_schema, organization_id} do
          {nil, _} -> nil
          {_, nil} -> nil
          {mod, id} -> repo.get(mod, id)
        end

      scope = Sigra.Scope.build(scope_module, user, active_organization: active_org)

      perform(scope, args)
    end
    ```

    d. Add the `@impl Sigra.Workers` clause `perform(scope, args)` that runs the existing deletion logic and emits the audit with the reconstructed scope:

    ```elixir
    @impl Sigra.Workers
    def perform(scope, args) do
      repo = Module.safe_concat([Map.fetch!(args, "repo")])
      user_schema = Module.safe_concat([Map.fetch!(args, "user_schema")])
      audit_schema = Module.safe_concat([Map.fetch!(args, "audit_schema")])
      user_id = Map.fetch!(args, "user_id")
      strategy = String.to_existing_atom(Map.fetch!(args, "strategy"))

      case repo.get(user_schema, user_id) do
        nil ->
          {:ok, :user_not_found}

        user ->
          if Sigra.Account.Deletion.scheduled?(user) do
            opts = [
              config: %{deletion: %{strategy: strategy}},
              changeset_fn: &default_changeset_fn/2,
              token_query_fn: &default_token_query_fn/2
            ]

            opts =
              opts
              |> maybe_add_opt(:user_token_schema, args["user_token_schema"])
              |> maybe_add_opt(:session_store, args["session_store"])
              |> maybe_add_opt(:identity_schema, args["identity_schema"])
              |> maybe_add_opt(:api_token_schema, args["api_token_schema"])
              |> maybe_add_opt(:mfa_credential_schema, args["mfa_credential_schema"])
              |> maybe_add_opt(:backup_code_schema, args["backup_code_schema"])

            case Sigra.Account.Deletion.execute(repo, user, opts) do
              {:ok, _strategy} ->
                Sigra.Audit.log_safe("account.deletion_executed", scope,
                  repo: repo,
                  audit_schema: audit_schema,
                  target_id: user_id,
                  metadata: %{deleted_user_id: user_id, strategy: to_string(strategy)}
                )

                :ok

              {:error, reason} ->
                {:error, reason}
            end
          else
            {:ok, :not_scheduled}
          end
      end
    end
    ```

    Note: the existing `perform/1` body (current lines 33-67 of account_deletion.ex) is MOVED into `perform/2` — do not leave a duplicate.

    **3. Create `test/sigra/workers/behaviour_test.exs`** covering:
    - `Sigra.Workers.new/3` raises `ArgumentError` with message containing `"organization_id"` when args is missing `"organization_id"`
    - `Sigra.Workers.new/3` raises `ArgumentError` with message containing `"actor_id"` when args is missing `"actor_id"`
    - `Sigra.Workers.new/3` accepts `%{"organization_id" => nil, "actor_id" => nil}` without raising (nil values OK, absent keys not OK)
    - `Sigra.Workers.new/3` does NOT raise when `"audit_schema"` is absent (audit_schema is worker-specific, not behaviour-contract)
    - `Sigra.Workers.fetch_arg!/2` raises `KeyError` on absent key
    - `Sigra.Workers.fetch_arg!/2` returns `nil` when key is present with nil value (nil is a valid value)

    Use a `TestWorker` stub inside the test file that `@behaviour Sigra.Workers`s and has a minimal `perform/2` returning `:ok`. Skip the Oban-Worker `new/2` call path (stub `apply/3` expectation or use a mock; alternatively, guard the call-through with `Code.ensure_loaded?/1` in the test so the test runs without Oban as a hard dep).

    **4. Update `test/sigra/workers/account_deletion_test.exs`** (existing file) to:
    - Add a test that builds a job with the new args shape (including `"audit_schema"`, `"organization_id"`, `"actor_id"`, `"scope_module"`, `"organization_schema"`) and asserts `AccountDeletion.perform(%Oban.Job{args: args})` emits `account.deletion_executed` with the reconstructed scope. Use `assert_audit_logged/2` from Task 3 below, or inline `Repo.one` assertion on the test audit schema.
    - Add a test that a hand-built job missing `"audit_schema"` fails with `KeyError` at `perform/1` time (belt + suspenders for the worker-specific required key)
    - Add a test that a hand-built job missing `"organization_id"` fails with `KeyError` at `perform/1` time (belt + suspenders for the behaviour-contract required keys)
  </action>
  <verify>
    <automated>mix test test/sigra/workers/behaviour_test.exs test/sigra/workers/account_deletion_test.exs && mix compile --warnings-as-errors</automated>
  </verify>
  <done>
    Sigra.Workers behaviour exists and compiles without Oban; new/3 fails fast on missing "organization_id" / "actor_id"; AccountDeletion implements the behaviour, carries "audit_schema" in its args list, and emits its audit with reconstructed scope; all new tests pass.
  </done>
  <acceptance_criteria>
    - `test -f lib/sigra/workers.ex` succeeds
    - `grep -c "@callback perform(scope" lib/sigra/workers.ex` returns `1`
    - `grep -c "Oban" lib/sigra/workers.ex` returns `0` (D-18: no Oban reference at module level)
    - `grep -c "def new(worker, args, opts" lib/sigra/workers.ex` returns `1`
    - `grep -c "raise ArgumentError" lib/sigra/workers.ex` returns at least `1`
    - `grep -c '@required_keys \\["organization_id", "actor_id"\\]' lib/sigra/workers.ex` returns `1` (audit_schema NOT in behaviour-contract required keys)
    - `grep -c "@behaviour Sigra.Workers" lib/sigra/workers/account_deletion.ex` returns `1`
    - `grep -c "Sigra.Scope.build" lib/sigra/workers/account_deletion.ex` returns at least `1`
    - `grep -c "Sigra.Audit.log_safe" lib/sigra/workers/account_deletion.ex` returns at least `1`
    - `grep -c "Module.safe_concat" lib/sigra/workers/account_deletion.ex` returns at least `3`
    - **`grep -c '"audit_schema"' lib/sigra/workers/account_deletion.ex` returns at least `2`** (once in perform/1 for fetch, once in perform/2 for resolution) — this is the BLOCKER 2 fix
    - **Documented moduledoc includes "audit_schema" as a required arg:** `grep -A 20 '## Job Args' lib/sigra/workers/account_deletion.ex | grep -c '"audit_schema"'` returns at least `1`
    - `grep -c "@behaviour Sigra.Workers" lib/sigra/workers/audit_cleanup.ex` returns `0` (D-22: stays untouched)
    - `grep -c "@behaviour Sigra.Workers" lib/sigra/workers/token_cleanup.ex` returns `0`
    - `grep -c "@behaviour Sigra.Workers" lib/sigra/workers/email_delivery.ex` returns `0`
    - `mix test test/sigra/workers/behaviour_test.exs` exits 0
    - `mix test test/sigra/workers/account_deletion_test.exs` exits 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Sigra.Credo.NoLogSafe2InLib custom check + .credo.exs registration + assert_audit_logged/2 helper</name>
  <files>
    lib/sigra/credo/no_log_safe2_in_lib.ex,
    .credo.exs,
    lib/sigra/testing.ex,
    test/sigra/credo/no_log_safe2_in_lib_test.exs,
    test/sigra/testing/assert_audit_logged_test.exs
  </files>
  <read_first>
    - **lib/sigra/testing.ex lines 1100-1202 (the existing `assert_audit_event/2` at line 1150 — CONFIRMED signature is `(expected :: map(), opts :: keyword())` requiring `:repo` + `:audit_schema` in opts)**
    - .credo.exs if it exists; otherwise see `mix credo gen.config` output for the default shape
    - Credo custom-check documentation in hexdocs.pm/credo (Credo.Check behaviour)
    - .planning/phases/15-audit-integration/15-CONTEXT.md D-30, D-31
    - .planning/phases/15-audit-integration/15-02-semantic-workers-credo-PLAN.md frontmatter `deviations` field (the D-31 refinement)
  </read_first>
  <behavior>
    - Running `mix credo --strict` on a file containing `Sigra.Audit.log_safe(action, opts)` (arity 2) inside lib/sigra/** emits an error from NoLogSafe2InLib
    - The check stays silent on:
      * The shim definition itself (`def log_safe(action, opts)`) in lib/sigra/audit.ex
      * Any file under test/**
      * Host-app generated code (not lib/sigra/**)
    - Running `mix credo --strict` on the current codebase (post-sweep) exits 0
    - `Sigra.Testing.assert_audit_logged/2` is a thin alias for `assert_audit_event/2` with signature `(map, keyword)` — NOT `(repo, fields)`. See D-31 deviation note.
    - Calling `assert_audit_logged/2` with a non-map first arg raises `FunctionClauseError` (guard enforcement, not runtime type check)
  </behavior>
  <action>
    **1. Create `lib/sigra/credo/no_log_safe2_in_lib.ex`**:

    ```elixir
    defmodule Sigra.Credo.NoLogSafe2InLib do
      @moduledoc """
      Forbids arity-2 `Sigra.Audit.log_safe/2` calls in `lib/sigra/**`.

      Arity-2 is a shim that passes `nil` scope. Library code MUST use the
      3-arity form so that the scope is visible at every call site, even
      when it is explicitly `nil`. This prevents drift under future phases.

      Allowed locations:
      - The shim definition itself in `lib/sigra/audit.ex`
      - Anywhere under `test/**`
      - Host-app generated code outside `lib/sigra/**`
      """

      use Credo.Check,
        base_priority: :high,
        category: :warning,
        explanations: [
          check: """
          Use `Sigra.Audit.log_safe/3` with an explicit scope argument (or `nil`)
          instead of `Sigra.Audit.log_safe/2`.

              # Bad
              Sigra.Audit.log_safe("auth.login.success", repo: repo, ...)

              # Good
              Sigra.Audit.log_safe("auth.login.success", scope, repo: repo, ...)

              # Also good (pre-auth or truly anonymous)
              Sigra.Audit.log_safe("security.invalid_credentials", nil, repo: repo, ...)
          """
        ]

      @impl Credo.Check
      def run(%SourceFile{} = source_file, params \\ []) do
        issue_meta = IssueMeta.for(source_file, params)
        path = source_file.filename

        cond do
          String.contains?(path, "/test/") -> []
          String.ends_with?(path, "lib/sigra/audit.ex") -> []
          not String.contains?(path, "lib/sigra/") -> []
          true -> Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
        end
      end

      defp traverse({{:., _, [{:__aliases__, _, alias_parts}, :log_safe]}, meta, args} = ast, issues, issue_meta)
           when length(args) == 2 do
        if alias_parts in [[:Sigra, :Audit], [:Audit]] do
          {ast, [issue_for(issue_meta, meta[:line] || 0) | issues]}
        else
          {ast, issues}
        end
      end

      defp traverse(ast, issues, _issue_meta), do: {ast, issues}

      defp issue_for(issue_meta, line_no) do
        format_issue(
          issue_meta,
          message: "Use Sigra.Audit.log_safe/3 (with explicit scope) in library code, not /2",
          line_no: line_no
        )
      end
    end
    ```

    **2. Create or update `.credo.exs`** at the repo root. If the file does not exist, bootstrap it by running `mix credo gen.config` and then editing; otherwise add the custom check to the existing `:checks` keyword list under `:extra`. Minimum viable `.credo.exs`:

    ```elixir
    %{
      configs: [
        %{
          name: "default",
          files: %{
            included: ["lib/", "test/", "priv/templates/"],
            excluded: []
          },
          strict: true,
          color: true,
          checks: %{
            extra: [
              {Sigra.Credo.NoLogSafe2InLib, []}
            ]
          }
        }
      ]
    }
    ```

    If `.credo.exs` already exists, preserve the existing config and insert `{Sigra.Credo.NoLogSafe2InLib, []}` into the `:extra` or `:enabled` checks list.

    **3. Create `test/sigra/credo/no_log_safe2_in_lib_test.exs`** using `Credo.Test.Case`:

    ```elixir
    defmodule Sigra.Credo.NoLogSafe2InLibTest do
      use Credo.Test.Case

      alias Sigra.Credo.NoLogSafe2InLib

      test "fires on arity-2 Sigra.Audit.log_safe in lib/sigra/**" do
        """
        defmodule Sample do
          def do_it do
            Sigra.Audit.log_safe("sample.event", repo: MyRepo, audit_schema: MySchema, metadata: %{})
          end
        end
        """
        |> to_source_file("lib/sigra/sample.ex")
        |> run_check(NoLogSafe2InLib)
        |> assert_issue()
      end

      test "fires on arity-2 aliased Audit.log_safe in lib/sigra/**" do
        """
        defmodule Sample do
          alias Sigra.Audit
          def do_it do
            Audit.log_safe("sample.event", repo: MyRepo, audit_schema: MySchema, metadata: %{})
          end
        end
        """
        |> to_source_file("lib/sigra/sample.ex")
        |> run_check(NoLogSafe2InLib)
        |> assert_issue()
      end

      test "stays silent on arity-3 form" do
        """
        defmodule Sample do
          def do_it do
            Sigra.Audit.log_safe("sample.event", nil, repo: MyRepo, audit_schema: MySchema, metadata: %{})
          end
        end
        """
        |> to_source_file("lib/sigra/sample.ex")
        |> run_check(NoLogSafe2InLib)
        |> refute_issues()
      end

      test "stays silent on lib/sigra/audit.ex (shim)" do
        """
        defmodule Sigra.Audit do
          def log_safe(action, opts), do: log_safe(action, nil, opts)
        end
        """
        |> to_source_file("lib/sigra/audit.ex")
        |> run_check(NoLogSafe2InLib)
        |> refute_issues()
      end

      test "stays silent on test/ files" do
        """
        defmodule SampleTest do
          def do_it do
            Sigra.Audit.log_safe("test.event", repo: TestRepo, audit_schema: TestSchema, metadata: %{})
          end
        end
        """
        |> to_source_file("test/sigra/sample_test.exs")
        |> run_check(NoLogSafe2InLib)
        |> refute_issues()
      end
    end
    ```

    **4. Add `assert_audit_logged/2` to `lib/sigra/testing.ex`** (D-31 refinement — see deviation note in frontmatter and below).

    Locate the existing `assert_audit_event/2` function via `grep -n "def assert_audit_event" lib/sigra/testing.ex` (confirmed at line 1150 at time of writing). The existing helper has signature:

    ```elixir
    @spec assert_audit_event(map(), keyword()) :: true
    def assert_audit_event(expected, opts) when is_map(expected) and is_list(opts)
    ```

    where `opts` requires `:repo` and `:audit_schema`. Add a thin wrapper DIRECTLY ABOVE OR BELOW `assert_audit_event/2` in `lib/sigra/testing.ex` with a MATCHING `(map, keyword)` shape — NOT `(repo, keyword)`:

    ```elixir
    @doc """
    Asserts that the latest audit event matches the given field expectations.

    Thin alias for `assert_audit_event/2` with a name aligned to REQ DX-02
    (`assert_audit_logged_for_org/2` family naming). Takes a map of expected
    fields and a keyword options list. See `assert_audit_event/2` for the
    full option list (`:repo`, `:audit_schema`, `:position`).

    ## Examples

        assert_audit_logged(
          %{
            action: "auth.login.success",
            actor_id: user.id,
            effective_user_id: user.id,
            organization_id: org.id
          },
          repo: MyApp.Repo,
          audit_schema: MyApp.AuditEvent
        )

    ## Signature note

    This helper intentionally takes `(map, keyword)` — NOT `(repo, fields)`. See
    the `deviations` field in `.planning/phases/15-audit-integration/15-02-semantic-workers-credo-PLAN.md`
    for the D-31 refinement rationale.
    """
    @doc since: "0.11.0"
    @spec assert_audit_logged(map(), keyword()) :: true
    def assert_audit_logged(expected, opts) when is_map(expected) and is_list(opts) do
      assert_audit_event(expected, opts)
    end
    ```

    **DEVIATION FROM D-31 (intentional, driven by RESEARCH.md §5 + `lib/sigra/testing.ex:1150` survey):**

    CONTEXT.md D-31 specifies `assert_audit_logged(repo, fields)`. That signature was written before `assert_audit_event/2` at `lib/sigra/testing.ex:1150` was surveyed. The existing helper uses `(map, keyword)` and requires `:repo` + `:audit_schema` in opts (see the confirmed source excerpt in the `<read_first>` section of this task). The *spirit* of D-31 is "a thin helper per REQ DX-02 that wraps the existing row-read assertion" — the signature is an implementation detail.

    A `(repo, fields)` shim would either need to synthesize the options map via magic (process dict / module attribute stashing `:audit_schema`) which is worse DX, OR re-query the audit schema itself which duplicates the existing implementation — violating "thin wrapper" from REQ DX-02.

    Executor MUST NOT "fix" this back to `(repo, fields)`. The D-31 refinement is recorded in this plan's frontmatter `deviations` field and MUST be flagged in the Plan 15-02 SUMMARY under a `## Deviations from CONTEXT.md` section.

    **5. Create `test/sigra/testing/assert_audit_logged_test.exs`** covering the happy path, the mismatch path, and the shape guard:

    ```elixir
    defmodule Sigra.Testing.AssertAuditLoggedTest do
      use ExUnit.Case, async: true

      import Sigra.Testing, only: [assert_audit_logged: 2]

      alias Sigra.TestRepo
      alias AuditTestEvent

      setup do
        # Insert a canonical audit row to assert against.
        {:ok, event} =
          TestRepo.insert(%AuditTestEvent{
            action: "test.event",
            actor_id: Ecto.UUID.generate(),
            organization_id: Ecto.UUID.generate(),
            effective_user_id: Ecto.UUID.generate(),
            metadata: %{}
          })

        {:ok, event: event}
      end

      test "passes when latest row matches given map fields", %{event: event} do
        assert assert_audit_logged(
                 %{action: "test.event", actor_id: event.actor_id},
                 repo: TestRepo,
                 audit_schema: AuditTestEvent
               ) == true
      end

      test "fails with a clear ExUnit.AssertionError when a field does not match" do
        assert_raise ExUnit.AssertionError, ~r/Expected action/, fn ->
          assert_audit_logged(
            %{action: "other.event"},
            repo: TestRepo,
            audit_schema: AuditTestEvent
          )
        end
      end

      test "raises FunctionClauseError when first arg is not a map" do
        assert_raise FunctionClauseError, fn ->
          # keyword list is NOT a map — guard (is_map(expected)) must reject it
          assert_audit_logged(
            [action: "test.event"],
            repo: TestRepo,
            audit_schema: AuditTestEvent
          )
        end
      end

      test "raises KeyError when opts is missing :audit_schema" do
        # Delegates to assert_audit_event/2 which does Keyword.fetch!(opts, :audit_schema)
        assert_raise KeyError, fn ->
          assert_audit_logged(%{action: "test.event"}, repo: TestRepo)
        end
      end
    end
    ```

    If `Sigra.TestRepo` or `AuditTestEvent` is not the correct test-repo / test-schema name in this project, substitute the names used elsewhere in `test/sigra/audit/**` (Plan 15-01 Wave 0 extended `test/support/audit_test_event.ex`). The substance — four tests covering happy path, mismatch, guard, and opts validation — is load-bearing.

    **6. Final CI check:** run `mix credo --strict` on the whole codebase. Post-sweep, it MUST exit 0 — any arity-2 call remaining in `lib/sigra/**` (other than the shim at `lib/sigra/audit.ex`) is a bug introduced by Plan 15-02 and must be fixed before closing this task.
  </action>
  <verify>
    <automated>mix test test/sigra/credo/no_log_safe2_in_lib_test.exs test/sigra/testing/assert_audit_logged_test.exs && mix credo --strict</automated>
  </verify>
  <done>
    NoLogSafe2InLib check exists, fires on bad calls, stays silent on allowed sites; .credo.exs registers it; assert_audit_logged/2 is a thin `(map, keyword)` alias for assert_audit_event/2 (D-31 refinement documented); `mix credo --strict` on the full codebase exits 0; the test file covers happy path + mismatch + guard + opts validation.
  </done>
  <acceptance_criteria>
    - `test -f lib/sigra/credo/no_log_safe2_in_lib.ex` succeeds
    - `grep -c "use Credo.Check" lib/sigra/credo/no_log_safe2_in_lib.ex` returns `1`
    - `grep -c ":log_safe" lib/sigra/credo/no_log_safe2_in_lib.ex` returns at least `1`
    - `grep -c "length(args) == 2" lib/sigra/credo/no_log_safe2_in_lib.ex` returns `1`
    - `test -f .credo.exs` succeeds
    - `grep -c "Sigra.Credo.NoLogSafe2InLib" .credo.exs` returns `1`
    - `grep -c "def assert_audit_logged" lib/sigra/testing.ex` returns `1`
    - **Signature is `(map, keyword)`:** `grep -A1 "def assert_audit_logged" lib/sigra/testing.ex | grep -c "is_map(expected) and is_list(opts)"` returns `1`
    - `grep -A3 "def assert_audit_logged" lib/sigra/testing.ex | grep -c "assert_audit_event(expected, opts)"` returns `1` (wraps, does not reimplement)
    - **Runtime test passes (BLOCKER 1 fix — replaces the weak grep-based check):** `mix test test/sigra/testing/assert_audit_logged_test.exs` exits 0
    - **Test file asserts FunctionClauseError on non-map arg:** `grep -c "FunctionClauseError" test/sigra/testing/assert_audit_logged_test.exs` returns at least `1`
    - **Test file asserts KeyError on missing :audit_schema:** `grep -c "KeyError" test/sigra/testing/assert_audit_logged_test.exs` returns at least `1`
    - `mix test test/sigra/credo/no_log_safe2_in_lib_test.exs` exits 0
    - `mix credo --strict` exits 0
    - Full codebase scan: `grep -rE "(Sigra\\.)?Audit\\.log_safe\\(\"[^\"]*\",\\s*(\\[|repo:|audit_schema:)" lib/sigra/ --include="*.ex" | grep -v "lib/sigra/audit.ex" | wc -l` returns `0` (no arity-2 call outside the shim)
  </acceptance_criteria>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Login audit emission | The first audit of a login is the v1.2 impersonation anchor — it must carry the real org id |
| Worker -> audit path | Background jobs run outside request context; reconstructed scope must not leak to authz |
| Failed-login audit | Untrusted email input must never be asserted as the authenticated principal (OWASP ASVS V7.1) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-15-01 | Repudiation | `session.create` emission in `lib/sigra/auth.ex` | mitigate | Reorder `session.create` + `auth.login.success` to fire AFTER `maybe_assign_active_organization/6` so the first audit of the login carries the real `organization_id` (D-27). Located via grep anchors, not line numbers. CHANGELOG entry in Plan 15-03. |
| T-15-02 | Information Disclosure | `Sigra.Workers` behaviour + `AccountDeletion` | mitigate | `Sigra.Workers.new/3` raises `ArgumentError` on missing `organization_id` / `actor_id` keys (fail-fast); `perform/1` also `Map.fetch!`es the keys (belt + suspenders per D-20). Worker scopes are audit-only — documented in moduledoc with "MUST NOT pass to authz" loud warning (D-21). AccountDeletion additionally requires `audit_schema` in its worker-specific arg list. |
| T-15-04 | Repudiation | Failed-login audit at `security.invalid_credentials` | mitigate | Unknown-email failed-login passes `nil` scope AND `target_id: nil`; metadata contains only IP + User-Agent — no email, no email hash (D-29). Matches OWASP ASVS V7.1 ("do not record actor as claimed identity the system just rejected"). |
| T-15-06 | Tampering | `Sigra.Credo.NoLogSafe2InLib` | mitigate | Ships alongside the sweep so "one idiom in lib/" is enforced structurally, not by convention. Without the check, future phases will erode the invariant — D-30 is explicit that the check is load-bearing. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` green
- `mix test` green (full suite)
- `mix credo --strict` exits 0
- `session.create` emission in `lib/sigra/auth.ex` is structurally inside `maybe_assign_active_organization/6` (verified via grep anchor, not line number)
- `Sigra.Workers` compiles without Oban (`mix compile` succeeds even when Oban is not a runtime dep — verify via `grep -c "Oban" lib/sigra/workers.ex` returns `0`)
- `Sigra.Workers.AccountDeletion.perform/1` emits `account.deletion_executed` with reconstructed scope (test asserts via `assert_audit_logged/2` with the `(map, keyword)` shape)
- AccountDeletion job args include `"audit_schema"` (grep verified in lib + the enqueue-site grep in action §2.b)
- Custom Credo check fires on a synthetic bad file and stays silent on the shim + test files (Credo.Test.Case coverage)
- `assert_audit_logged/2` is a `(map, keyword)` alias for `assert_audit_event/2` — runtime test in `test/sigra/testing/assert_audit_logged_test.exs` covers happy path, mismatch, FunctionClauseError guard, and missing-opts KeyError
</verification>

<success_criteria>
All `must_haves.truths` hold; `session.create` ordering bug is fixed; Sigra.Workers behaviour is live with AccountDeletion as the reference (args include `"audit_schema"`); custom Credo check is registered and green on the codebase; `assert_audit_logged/2` is available to Plan 15-03 and downstream phases with its documented `(map, keyword)` signature; Category 3 classification for `lockout.ex` and `suspicious_login.ex` is verified. Codebase is semantically clean and ready for the install-path wiring in Plan 15-03.
</success_criteria>

<output>
After completion, create `.planning/phases/15-audit-integration/15-02-SUMMARY.md` including:
- The session.create reorder (before/after grep anchors + real line numbers at time of execution)
- The list of Category 1/2/3 sites semantically enriched
- Explicit note that `lockout.ex` and `suspicious_login.ex` were reviewed and remain at `nil` scope per Category 3
- The Sigra.Workers contract (required keys: `"organization_id"`, `"actor_id"` — NOT `"audit_schema"`)
- The AccountDeletion refactor diff summary, including the new `"audit_schema"` arg
- The Credo check registration
- **A `## Deviations from CONTEXT.md` section** recording the D-31 refinement (`assert_audit_logged/2` signature changed from `(repo, fields)` to `(map, keyword)` to match the existing `assert_audit_event/2` at `lib/sigra/testing.ex:1150`)
- Flag the `session.create` reorder and the unknown-filter-key raise as CHANGELOG items for Plan 15-03
</output>
