---
phase: 131-forwarder-behaviour-threadline-forwarder-library-scaffolding
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/sigra/audit.ex
  - lib/sigra/audit/forwarder.ex
  - lib/sigra/audit/forwarders.ex
  - lib/sigra/audit/forwarders/noop.ex
  - lib/sigra/audit/forwarders/threadline.ex
  - lib/sigra/config.ex
  - lib/sigra/application.ex
  - lib/sigra/workers/audit_forward.ex
  - .github/workflows/ci.yml
  - test/sigra/audit_telemetry_test.exs
  - test/sigra/audit/forwarder_test.exs
  - test/sigra/audit/forwarders/noop_test.exs
  - test/sigra/audit/forwarders/dispatch_test.exs
  - test/sigra/audit/forwarders/threadline_test.exs
  - test/sigra/config_forwarders_test.exs
  - test/sigra/workers/audit_forward_test.exs
findings:
  critical: 4
  warning: 7
  info: 5
  total: 16
status: issues_found
---

# Phase 131: Code Review Report

**Reviewed:** 2026-05-27T00:00:00Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 131 ships the `Sigra.Audit.Forwarder` behaviour, a Threadline tap, a
dispatch router with `:auto`/`:async`/`:sync` semantics, and boot-time wiring
with the D-26 fail-fast on `:async` + no-Oban. The behaviour surface, dep-off
compile gating, and telemetry auto-detach safety story are mostly sound.

However, **the async Oban path is broken in production**: the worker's
`resolve_config/0` calls `Keyword.fetch!(audit_opts, :repo)` but `:repo` is
not a valid key under the `:audit` config schema in `lib/sigra/config.ex` —
the host has no way to put `:repo` there without triggering
`NimbleOptions.ValidationError`. The `KeyError` raised by `fetch!` escapes
`perform/1` (which has no top-level rescue), directly violating D-17 ("perform
NEVER raises"). The test suite uses a `Process.put(:sigra_audit_forward_config, …)`
override that bypasses the broken cascade, so the bug never surfaces in CI.

Additional concerns: (1) the docs/recipes promise that Noop is "used
automatically when a forwarder module is not loaded", but
`attach_forwarders/0` doesn't actually fall through to Noop — it just skips
the attach silently, so a misconfigured forwarder + warning + no attached
handler results in zero forwarding regardless of whether Noop exists;
(2) the Threadline forwarder calls `String.to_atom/1` on
`metadata[:action]`, an unbounded atom-table growth vector since audit
actions are partially developer-controlled; (3) the worker has no
nil-guard before `repo.get(audit_schema, nil)`.

## Critical Issues

### CR-01: Worker `resolve_config/0` reads `:repo` from a schema where it does not exist — async path KeyErrors in production

**File:** `lib/sigra/workers/audit_forward.ex:144-147`
**Issue:** `resolve_config/0` runs:

```elixir
audit_opts =
  case otp_app && Application.get_env(otp_app, :sigra_config) do
    opts when is_list(opts) -> Keyword.get(opts, :audit, [])
    _ -> []
  end

%{
  repo: Keyword.fetch!(audit_opts, :repo),
  audit_schema: Keyword.fetch!(audit_opts, :audit_schema)
}
```

But the audit schema in `lib/sigra/config.ex:793-830` only declares these
keys under `:audit`: `audit_schema`, `retention_days`, `max_metadata_bytes`,
`reserved_prefixes`, `forwarders`. `:repo` is NOT permitted. A host that
passes `audit: [repo: MyApp.Repo, ...]` to `Sigra.Config.new!/1` gets
`NimbleOptions.ValidationError: unknown options [:repo]`.

That means in production: every async forwarder job calls
`Keyword.fetch!(audit_opts, :repo)` → raises `KeyError` → escapes the
function (no top-level rescue in `perform/1`) → Oban marks the job failed
and retries up to `max_attempts: 5` → all retries fail identically →
silent permanent forwarding loss.

This is masked in tests because every test uses
`Process.put(:sigra_audit_forward_config, %{repo: StubRepo, ...})`
(see `test/sigra/workers/audit_forward_test.exs:55`), which short-circuits
the broken cascade at line 131-133.

Independently, the moduledoc at line 47-49 advertises "Config lookup uses
the existing `Application.get_env(otp_app, :sigra_config)` pattern — the
single config-resolution idiom across all Sigra boot diagnostics" — but
the precedent (`lib/sigra/workers/email_delivery.ex:80-83`) reads
`Application.fetch_env!(:sigra, :repo)` from the global `:sigra` env, not
from nested `audit:` opts. The two code paths are inconsistent and the
worker chose the wrong pattern.

**Fix:** Mirror the EmailDelivery pattern AND add a top-level rescue.
Either:

```elixir
# Option A: mirror EmailDelivery — read from :sigra global env
defp resolve_config do
  case Process.get(:sigra_audit_forward_config) do
    %{} = override ->
      override

    nil ->
      %{
        repo: Application.fetch_env!(:sigra, :repo),
        audit_schema: fetch_audit_schema!()
      }
  end
end

defp fetch_audit_schema! do
  otp_app = Application.get_env(:sigra, :otp_app)

  audit_opts =
    case otp_app && Application.get_env(otp_app, :sigra_config) do
      opts when is_list(opts) -> Keyword.get(opts, :audit, [])
      _ -> []
    end

  Keyword.fetch!(audit_opts, :audit_schema)
end
```

OR Option B: add `:repo` to the audit config schema in
`lib/sigra/config.ex`. Either way, also wrap the whole `perform/1` body in
the same try/rescue that `perform_forward/5` already uses so a stray
KeyError can never bypass D-17.

### CR-02: `perform/1` violates D-17 "never raises" — config and DB calls escape the rescue

**File:** `lib/sigra/workers/audit_forward.ex:58-99`
**Issue:** D-17 (per the moduledoc, line 39-44) mandates `perform/1` NEVER
raises. But the rescue/catch lives in `perform_forward/5` only. Three
escape paths exist:

1. `resolve_config()` (line 73) — raises `KeyError` per CR-01.
2. `repo.get(audit_schema, audit_event_id)` (line 76) — raises
   `DBConnection.ConnectionError`, `Postgrex.Error`, etc., on DB failure.
   Also raises if `audit_event_id` is nil and the repo's
   `Ecto.Schema.__schema__(:primary_key)` resolution fails (some adapters
   do this).
3. The map destructure at line 73
   (`%{repo: repo, audit_schema: audit_schema} = resolve_config()`) raises
   `MatchError` if `resolve_config` ever returns a map missing those keys
   (e.g. a partial test override).

**Fix:** Wrap the entire `perform/1` body in the same try/rescue/catch the
forwarder uses, returning `{:error, reason}` from any unexpected raise.

```elixir
def perform(%Oban.Job{args: args, attempt: attempt} = _job) do
  try do
    # existing body
  rescue
    exception ->
      :telemetry.execute([:sigra, :audit, :forward, :error], %{count: 1},
        %{forwarder: :audit_forward_worker, action: args["forwarder"],
          reason: exception, kind: :error, attempt: attempt})
      {:error, Exception.message(exception)}
  catch
    :exit, reason ->
      # ...
      {:error, {:exit, reason}}
  end
end
```

### CR-03: `attach_forwarders/0` silently drops events when forwarder module is unloaded — Noop is documented but never substituted

**File:** `lib/sigra/application.ex:153-156` (also docs:
`lib/sigra/audit/forwarders/noop.ex:5-19`)
**Issue:** The Noop moduledoc at lines 5-19 promises:

> This is a fallback used when an audit forwarder is configured (e.g.
> Threadline) but its dep is not loaded.
>
> Used automatically when a configured forwarder module is not loaded at
> boot time.

But `attach_forwarders/0` does NOT substitute Noop on missing-dep — it
just guards the attach call:

```elixir
if Code.ensure_loaded?(module) do
  module.attach(forwarder_opts)
end
```

When `module` isn't loaded the branch is skipped. Nothing attached. Noop
is never invoked. The forwarder.ex moduledoc (line 17-20) makes the same
incorrect claim, and so does the Threadline moduledoc (line 17-18):
"falls through to Noop (D-23 split)".

The effect in production: a host that wrote
`forwarders: [[module: Sigra.Audit.Forwarders.Threadline, ...]]` but
forgot `:threadline` in `mix.exs` gets a startup `Logger.warning` (good),
zero attached forwarders (silent), and zero post-commit forwarding —
exactly as if no forwarder were ever configured. The Noop module is dead
code in this scenario.

This is a documentation/behaviour gap, but it changes the user mental
model: "If I see the warning, my forwarder is degraded to no-op" is
correct, but "Noop is what runs in the degraded path" is false.

**Fix:** Either substitute Noop on missing-dep (preferred per the
documented contract):

```elixir
target_module =
  if Code.ensure_loaded?(module) do
    module
  else
    Sigra.Audit.Forwarders.Noop
  end

target_module.attach(forwarder_opts)
```

OR fix the three moduledocs (Noop, Forwarder, Threadline) to drop the
"used automatically as fallback" language and clarify that Noop is only
attached when explicitly configured.

### CR-04: Telemetry handler crash on `metadata[:action]` being nil — pattern-match failure inside `call_threadline/2`

**File:** `lib/sigra/audit/forwarders/threadline.ex:257-261`
**Issue:** Inside the telemetry handler body (the auto-detach landmine
zone), `call_threadline/2` does:

```elixir
name =
  case metadata[:action] do
    a when is_atom(a) -> a
    s when is_binary(s) -> String.to_atom(s)
  end
```

The `case` has no fallback — if `metadata[:action]` is nil (which can
happen if a defensive caller emits malformed metadata, or if a future
internal call path forgets to set `:action`), this raises `CaseClauseError`.

The outer `try/rescue` at line 100 will catch it, fire
`[:sigra, :audit, :forward, :error]` and return `:ok` to telemetry — so
the auto-detach landmine is avoided thanks to the rescue. But the rescue
masks a recoverable mismatch as a thrown exception, the error telemetry
fires with `reason: %CaseClauseError{...}`, and the operator sees a
confusing "Rescued CaseClauseError" Logger.warning.

Secondary concern: `String.to_atom(s)` is called on `metadata[:action]`,
which originates from user-controlled audit event data (e.g., custom
non-Sigra-prefixed actions emitted from app code via `Audit.log/2`).
Audit actions are validated to be strings in `Sigra.Audit.Changeset` but
the action set is open-ended (`auth.login.success`, `account.delete`,
etc.). An attacker who can trigger arbitrary audit logging
(self-registration churn, brute-force login attempts where the rate
limiter writes per-attempt audit rows) can drive atom-table growth
without bound — atoms are not GC'd in Erlang and the table is capped
at ~1M, after which the VM crashes.

For Sigra-controlled action names this is bounded (the reserved-prefix
set has finite cardinality). For host-defined developer actions, the
attack surface depends on whether action names are templated with
attacker-controlled data — which Sigra explicitly cannot enforce.

**Fix:** Use `String.to_existing_atom/1` and handle the nil/unknown case
explicitly, returning a typed error from `call_threadline` rather than
letting the case raise:

```elixir
name =
  case metadata[:action] do
    a when is_atom(a) ->
      {:ok, a}

    s when is_binary(s) ->
      try do
        {:ok, String.to_existing_atom(s)}
      rescue
        ArgumentError -> {:error, :unknown_action_atom}
      end

    _ ->
      {:error, :missing_action}
  end

case name do
  {:ok, atom_name} -> # build call_opts and dispatch
  {:error, reason} -> {:error, reason}
end
```

Note: this requires upstream coordination — the action atoms need to
exist somewhere before they can be `to_existing_atom`'d. The simplest fix
is to keep `String.to_atom/1` for now and accept the atom-growth risk
since it's an opt-in path, but document the constraint in the moduledoc.
The nil/unmatched case still needs a fallback clause regardless.

## Warnings

### WR-01: `metadata[:outcome]` translation drops unknown values silently to `:ok`

**File:** `lib/sigra/audit/forwarders/threadline.ex:246-254`
**Issue:** The outcome translator maps `:success` / `"success"` /
`:failure` / `"failure"` / `:error` → `:ok` or `:error`, but the
catch-all `_ -> :ok` masks bugs. If the audit row had outcome
`"locked_out"` or any future Sigra outcome value, Threadline would
record it as `:ok` despite the underlying event being a failure.

**Fix:** Either pattern-match the known outcome set exhaustively and
return an error tuple from `call_threadline/2` on unknown outcome, or
make the default `:error` (fail-closed) rather than `:ok`:

```elixir
status =
  case metadata[:outcome] do
    s when s in [:success, "success"] -> :ok
    s when s in [:failure, "failure", :error, "error", :locked_out, "locked_out"] -> :error
    _ -> :error  # fail closed: treat unknown outcome as error in Threadline
  end
```

### WR-02: Worker's result case has no `{:ok, _}` clause — custom forwarders crash with `CaseClauseError`

**File:** `lib/sigra/workers/audit_forward.ex:165-172`
**Issue:** The worker dispatches `result = forwarder_module.handle_event(...)`
and matches:

```elixir
case result do
  :ok -> :ok
  {:error, :schema_mismatch} -> {:cancel, :schema_mismatch}
  # ... other {:error, _} clauses
  {:error, reason} -> {:error, reason}
end
```

There's no clause for `{:ok, anything}`. A custom forwarder following
the documented `handle_event/4` convention that returns `{:ok, response}`
(plausible — `Threadline.record_action/2` itself returns `{:ok, action}`)
triggers `CaseClauseError`. Caught by the rescue at line 181 → emits
forward-error telemetry with `kind: :error` and `reason:
%CaseClauseError{...}` → returns `{:error, ...}` so Oban retries.

Net effect: the job retries 5 times against a forwarder that
deterministically returns `{:ok, _}` every time, then permanently fails
— while never actually being a failure.

**Fix:** Add a tolerant `{:ok, _}` clause:

```elixir
case result do
  :ok -> :ok
  {:ok, _} -> :ok
  {:error, :schema_mismatch} -> {:cancel, :schema_mismatch}
  # ...
  {:error, reason} -> {:error, reason}
  other ->
    Logger.warning(
      "[Sigra.Workers.AuditForward] Unexpected return from #{inspect(forwarder_module)}: #{inspect(other)}"
    )
    {:error, {:unexpected_return, other}}
end
```

### WR-03: No nil-guard before `repo.get(audit_schema, audit_event_id)` — depends on adapter behaviour for nil PK

**File:** `lib/sigra/workers/audit_forward.ex:62, 76`
**Issue:** `audit_event_id = args["audit_event_id"]` returns nil if the
key is missing or explicitly set to nil in the job args. The subsequent
`repo.get(audit_schema, nil)` behaviour depends on the Ecto adapter:
Postgrex generally raises, some test stubs return nil. Either path is a
latent footgun and conflates "row not found" with "malformed job args".

**Fix:** Add an early guard:

```elixir
audit_event_id = args["audit_event_id"]

cond do
  is_nil(audit_event_id) ->
    {:cancel, :missing_audit_event_id}

  true ->
    case resolve_forwarder(forwarder_string) do
      # ...
    end
end
```

### WR-04: `:async` dispatch silently no-ops when worker module is absent — masks misconfiguration

**File:** `lib/sigra/audit/forwarders.ex:132-151`
**Issue:** `dispatch_async/3` returns `:ok` when
`Sigra.Workers.AuditForward` is not loaded:

```elixir
defp dispatch_async(forwarder_module, metadata, opts) do
  if Code.ensure_loaded?(@worker_module) do
    # enqueue
  else
    :ok  # silent no-op
  end
end
```

D-26 already covers the boot-time scenario where `:async` is configured
without Oban (raises in `attach_forwarders/0`). But a runtime call to
`dispatch/3` with `dispatch: :async` from a custom forwarder, after a
deploy that dropped `:oban`, will silently return `:ok` and drop the
event. The dispatcher moduledoc at line 124-125 acknowledges this:
"Gracefully no-ops if Sigra.Workers.AuditForward is not compiled (e.g.
Oban is not in deps). Plan 05 makes this branch fully live." Plan 05 has
landed — this comment is stale and the silent-degrade is now a bug, not
a placeholder.

**Fix:** Return an explicit error so callers can observe the degradation:

```elixir
else
  {:error, :async_worker_not_compiled}
end
```

And/or emit telemetry on the silent-degrade path so operators see it.

### WR-05: D-15 "byte-for-byte" backoff test compares source string substrings — does not catch divergence in surrounding code

**File:** `test/sigra/workers/audit_forward_test.exs:106-119`
**Issue:** The test asserts both source files contain the exact backoff
expression string:

```elixir
backoff_body = "trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)"
assert String.contains?(af_source, backoff_body)
assert String.contains?(ed_source, backoff_body)
```

This passes if either file contains the substring anywhere — including
inside a doc string, a comment, or even an unrelated function. It does
NOT prove the worker's `backoff/1` callback evaluates the expression. A
maintainer that copies the line into a moduledoc and removes the actual
implementation would pass this test while breaking the contract.

**Fix:** Test the runtime behaviour instead — compute both backoffs for a
deterministic seed and assert equality, or use Erlang trace to confirm
the same function body is executed:

```elixir
test "backoff returns same values as EmailDelivery for same attempt" do
  for attempt <- 1..5 do
    :rand.seed(:exsss, {1, 2, 3})
    af = AuditForward.backoff(%Oban.Job{attempt: attempt})
    :rand.seed(:exsss, {1, 2, 3})
    ed = EmailDelivery.backoff(%Oban.Job{attempt: attempt})
    assert af == ed
  end
end
```

### WR-06: Application boot-time `attach_forwarders/0` re-attaches on every boot, has no idempotency guard

**File:** `lib/sigra/application.ex:123-160`
**Issue:** `:telemetry.attach/4` (used by `Threadline.attach/1` line 83)
returns `{:error, :already_exists}` if the handler ID is already attached.
But `attach_forwarders/0` ignores the return value:

```elixir
if Code.ensure_loaded?(module) do
  module.attach(forwarder_opts)
end
```

In normal OTP application lifecycle this fires once. But in dev when
`recompile()` triggers Application restart, or in test setups where
Application.start is invoked manually, the second attach silently fails
with `{:error, :already_exists}` and the boot returns `:ok` with no
indication that the new opts (e.g., a config change) didn't take effect.

The handler_id derivation `{__MODULE__, Keyword.get(opts, :id, :default)}`
in Threadline.attach (line 81) does provide isolation across forwarders,
but doesn't help when the same `:id` is re-attached with different opts.

**Fix:** Detach-then-attach for idempotency, or surface the
`{:error, :already_exists}` for visibility:

```elixir
defp attach_one(module, forwarder_opts) do
  handler_id = {module, Keyword.get(forwarder_opts, :id, :default)}
  _ = :telemetry.detach(handler_id)  # idempotent
  module.attach(forwarder_opts)
end
```

This requires the dispatcher to expose `handler_id` derivation as a
helper so callers don't recompute it inconsistently.

### WR-07: `forwarders` validator returns the input list unchanged instead of normalized entries

**File:** `lib/sigra/config.ex:954-983`
**Issue:** `validate_forwarders/1` returns `{:ok, list}` (the original
input) even after validating defaults like `:dispatch` defaulting to
`:auto` and `:id` defaulting to `:default`. These defaults are only
"observed" inline in the cond clauses (`Keyword.get(entry, :dispatch,
:auto)`), but never injected into the returned data. Downstream consumers
that read `Keyword.fetch!(entry, :dispatch)` will fail; consumers that
use `Keyword.get(entry, :dispatch, :auto)` work by accident because they
re-supply the default.

This is a maintenance landmine: any new consumer that assumes
"validation already normalized this" will silently break.

**Fix:** Normalize and return the canonicalized list:

```elixir
def validate_forwarders(list) when is_list(list) do
  Enum.reduce_while(list, {:ok, []}, fn entry, {:ok, acc} ->
    cond do
      # ... existing validation
      true ->
        normalized =
          entry
          |> Keyword.put_new(:dispatch, :auto)
          |> Keyword.put_new(:id, :default)
        {:cont, {:ok, acc ++ [normalized]}}
    end
  end)
end
```

## Info

### IN-01: Dead `_occurred_at_iso` binding in worker — extracted from args, never used

**File:** `lib/sigra/workers/audit_forward.ex:63`
**Issue:** `_occurred_at_iso = args["occurred_at"]` is read but
discarded. The moduledoc at line 17 says it's "for tracing (not used to
load the row)" — but the variable is also not emitted in any telemetry
metadata or log line. It's pure dead code. Either use it (emit in error
telemetry as `args_occurred_at` for cross-reference) or drop the read
and the doc bullet.

**Fix:** Drop the line and the moduledoc reference, or pipe it into the
error telemetry:

```elixir
:telemetry.execute([:sigra, :audit, :forward, :error], %{count: 1},
  %{..., args_occurred_at: args["occurred_at"]})
```

### IN-02: `audit.ex:55` accepts `opts` keyword without `opts` typespec — `@spec log` typed as `opts()` but `opts()` is `keyword()` — no value

**File:** `lib/sigra/audit.ex:37, 54`
**Issue:** `@type opts :: keyword()` is just an alias for `keyword()`.
The aliasing buys nothing — a user reading `@spec log(String.t(), opts())`
must still consult the type to learn it's `keyword()`. Better to inline
`keyword()` directly OR add a richer t() with documented option keys
(`@type opts :: [audit_schema: module(), repo: Ecto.Repo.t(), ...]`).

**Fix:** Either inline `keyword()` in all specs, or expand the type
alias to enumerate the documented options.

### IN-03: Threadline forwarder's `build_actor_ref(_, _)` swallows construction errors silently

**File:** `lib/sigra/audit/forwarders/threadline.ex:285-299`
**Issue:** Both `build_actor_ref` clauses pattern-match on the
`Threadline.Semantics.ActorRef.new/1` and `.new/2` return tuple and fall
through to `nil` on any non-`{:ok, _}` shape. The catch-all `_ -> nil`
masks bugs (mistyped actor_id, future Threadline schema change). No
telemetry, no log. The caller (`add_actor_opt/2`) treats nil as
"omit :actor key", which Threadline then rejects with `{:error,
:missing_actor}` → mapped by the dispatcher case (line 276) to
`{:error, :missing_actor}` → cancelled non-retryably by the worker (line
168).

The cascade ultimately produces a typed cancellation, but with no
diagnostic about WHY the actor_ref couldn't be built. An operator
investigating "why are all my audit events being cancelled with
`:schema_mismatch`?" has no breadcrumb back to the actor_ref construction
failure.

**Fix:** Emit a `[:sigra, :audit, :forward, :error]` telemetry event on
the fallback or include the construction failure reason in the returned
error tuple.

### IN-04: Test `audit_telemetry_test.exs` defines a StubRepo with autogenerate hack — production parity comment is helpful but consider extracting

**File:** `test/sigra/audit_telemetry_test.exs:17-41`
**Issue:** The `StubRepo.ensure_autogenerated_id` workaround duplicates
the same hack from `audit_observability_test.exs`. The comment at
line 18-25 explains why, but extracting a shared `Sigra.Test.StubRepo`
would let multiple tests share one tested-once implementation and avoid
divergence (e.g., if the schema starts autogenerating other fields).

**Fix:** Extract `Sigra.Test.StubRepo` under `test/support/` with the
autogenerate hook, and use it from both telemetry tests.

### IN-05: CI `library_tests_dep_off` lane uses `mix deps.unlock threadline` + `deps.clean --build` — fragile if a future dep transitively requires threadline

**File:** `.github/workflows/ci.yml:205-212`
**Issue:** The dep-off lane assumes `:threadline` has no reverse deps
in Sigra's tree. If a future contributor adds a lib that transitively
requires Threadline, `mix deps.unlock threadline` will silently fail to
remove it from `_build/`, and the test will compile with Threadline
loaded — defeating the lane's purpose. There's no assertion confirming
Threadline is actually absent before the test run.

**Fix:** Add an explicit assertion after deps.clean:

```yaml
- name: Verify Threadline is absent
  run: |
    if mix run -e 'IO.puts(Code.ensure_loaded?(Threadline))' | grep -q true; then
      echo "FAIL: Threadline is still loaded in dep-off lane"
      exit 1
    fi
```

---

_Reviewed: 2026-05-27T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
