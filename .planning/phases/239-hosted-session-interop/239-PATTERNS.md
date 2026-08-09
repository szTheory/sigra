# Phase 239: Hosted Session Interop - Pattern Map

**Mapped:** 2026-08-08  
**Files analyzed:** 8 planned files (4 external Crosswake, 4 SIGRA generated-host)  
**Analogs found:** 8 / 8

## Delivery Boundary

The nullable-personal `org_id` contract/release is **cross-repository work in `szTheory/crosswake`**. It must precede consumption here; this map identifies the external targets only and makes no edits outside this repository. The adapter belongs in `test/example`, not `lib/sigra`: the host owns its cookie, `user_sessions`, user schema, and Crosswake dependency.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `crosswake: packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex` | model / contract | transform | same file at released `e3d6cbf` | exact target |
| `crosswake: packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs` | test | transform | same file at released `e3d6cbf` | exact target |
| `crosswake: packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs` | test | request-response | same file at released `e3d6cbf` | exact target |
| `crosswake: packages/crosswake_sigra/mix.exs` | config / release | batch | package release metadata | exact role |
| `test/example/mix.exs` | config | batch | lines 31-62 | exact role |
| `test/example/lib/example/accounts/crosswake_session_adapter.ex` (new) | service / adapter | request-response | `accounts.ex:303-330`, `fetch_session.ex:99-109` | composed role match |
| `test/example/test/example/accounts/crosswake_session_adapter_test.exs` (new) | integration test | request-response | `session_invalidation_test.exs:19-79` | exact storage-backed match |
| `guides/recipes/b2c-alpha.md` | documentation / contract | transform | lines 38-48 | exact target |

## Pattern Assignments

### `crosswake: .../contracts.ex` (model / contract, transform)

**External analog:** released `packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex` at commit `e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c`.

**Construction/validation pattern** (lines 186-207, 220-264):

```elixir
def new_auth_context(attrs) when is_map(attrs) do
  attrs
  |> normalize_auth_context_attrs()
  |> build_and_validate(AuthContext, &validate_auth_context/1, :auth_context)
end

def validate_session_authority_lane(%SessionAuthorityLane{} = lane) do
  []
  |> validate_required_string(:session_ref, lane.session_ref)
  |> validate_required_string(:subject_ref, lane.subject_ref)
  |> validate_required_string(:org_id, lane.org_id)
  |> validate_authority_state(lane.state)
  |> validate_mfa_level(:assurance_level, lane.assurance_level)
  |> validate_timestamp(:as_of, lane.as_of)
  |> validate_non_negative_integer(:session_version, lane.session_version)
  |> to_validation_result()
end
```

Replace only the `org_id` required-string validation with a shared semantic validator: accept exactly `nil` or a trimmed nonblank string; reject blanks, non-strings, and sentinels. Apply it to `AuthContext`, `SessionAuthorityLane`, and any touched return-attempt record. Preserve lane-derived aliases (lines 359-370), so a personal lane derives `AuthContext.org_id: nil`.

### `crosswake: .../contracts_test.exs` (test, transform)

**External analog:** same target, lines 7-93 and 121-154.

```elixir
assert {:ok, lane} = Contracts.new_session_authority_lane(session_authority_lane_attrs())
assert {:ok, auth_context} =
         Contracts.new_auth_context(session_authority_lane: lane, as_of: "2026-06-01T00:05:00Z")

assert auth_context.actor_id == "actor_123"
assert auth_context.org_id == "org_123"
```

Add paired personal, organization, and blank cases for both lane and lane-derived context. Keep direct constructor assertions and existing evidence-authority rejection style; no credentials/tokens in fixtures.

### `crosswake: .../phase57_auth_return_boundaries_test.exs` (test, request-response)

**External analog:** same target, lines 81-117 and 210 onward.

```elixir
assert {:error, errors} =
         AuthReturn.new_envelope(
           oauth_envelope_attrs(%{access_token: "tok_secret", nonce: "raw_nonce"})
         )
```

Use public-constructor failure as proof. Extend the matrix to `session_ref`, `subject_ref`, `org_id`, authority fields, and access-grant booleans. An otherwise valid evidence-only envelope without a freshly resolved host session must deny; it is never evaluator authority.

### `test/example/mix.exs` (config, batch)

**Analog:** lines 31-62.

```elixir
defp deps do
  [
    {:sigra, path: "../..", override: true},
    {:phoenix, "~> 1.8.5"},
    {:mox, "~> 1.1", only: :test}
  ]
end
```

Add the released `crosswake_sigra` successor only after human verification of tag/Hex publication; keep it scoped to the example/proof environment when Mix allows. Do not add it to the root SIGRA runtime dependencies just to test this boundary. Update `mix.lock` normally.

### `test/example/lib/example/accounts/crosswake_session_adapter.ex` (new service/adapter, request-response)

**Primary analog:** `test/example/lib/example/accounts.ex:303-330`.

```elixir
def get_user_and_session_by_token(raw_token) when is_binary(raw_token) do
  with {:ok, raw_bytes} <- Base.url_decode64(raw_token, padding: false) do
    hashed = Sigra.Token.hash_token(raw_bytes)
    config = sigra_config()
    store = Keyword.fetch!(config.session, :store)

    case store.fetch(hashed, store_opts) do
      {:ok, session} ->
        case Repo.get(User, session.user_id) do
          nil -> nil
          user -> {user, session}
        end
      {:error, :not_found} -> nil
    end
  else
    _ -> nil
  end
end
```

**Fresh-expiry/fail-closed precedent:** `lib/sigra/plug/fetch_session.ex:99-109,151-162`.

```elixir
case session_store.fetch(token, opts) do
  {:ok, session} ->
    if session_valid?(session, session_config) do
      {:ok, session}
    else
      session_store.delete(session.hashed_token, opts)
      :skip
    end
  {:error, _reason} -> :skip
end
```

Every projection/replay must: resolve current `{user, session}` from raw cookie; validate state/expiry; compare expected opaque session/subject/version bindings; construct lane/context; call the pure evaluator. Lookup, validation, or binding failure returns a safe host denial **before** evaluator invocation. Never project raw token, `session.token`, `hashed_token`, provider payload, or OAuth token. Fetched-token semantics are explicit in `lib/sigra/session.ex:23-27,55-85`. Use fixed/injected time; B2C always projects `org_id: nil` and never hydrates `active_organization_id`.

### `test/example/test/example/accounts/crosswake_session_adapter_test.exs` (integration test, request-response)

**Primary analog:** `test/example/test/example/accounts/session_invalidation_test.exs:19-79`.

```elixir
use ExampleWeb.ConnCase, async: false

import Example.AccountsFixtures
import Ecto.Query

alias Example.Accounts
alias Example.Accounts.UserSession
alias Example.Repo
```

Use real Ecto rows and public adapter calls. Cover valid personal projection, valid organization contract value, missing/deleted/revoked row, idle/absolute expiry, stale version, session mismatch, account switch, and evidence-only return without a current session. Assert no token/hash/identifier leaks and evaluator non-invocation for host binding failures. The session fixture pattern is `test/example/test/support/fixtures/auth_fixtures.ex:42-72`: random raw bytes only produce a stored hash.

### `guides/recipes/b2c-alpha.md` (documentation / contract, transform)

**Analog:** lines 38-48.

```markdown
For this profile use `org_id: nil`: it means a personal account, not a
fabricated organization. Keep `session_ref` and `subject_ref` opaque and
server-owned.
```

Change only if the published companion API/range needs consumer instructions. Preserve no-token, evidence-only, fail-closed language.

## Shared Patterns

### Canonical session resolution

**Sources:** `test/example/lib/example/accounts.ex:303-330`; `lib/sigra/session_stores/ecto.ex:43-53,190-204`.

Decode cookie then hash for lookup; fetched records contain the hash but no raw token. Resolve the host user after session lookup.

### Fail closed before pure evaluation

**Sources:** `lib/sigra/plug/fetch_session.ex:99-109,151-162`; released Crosswake `evaluator.ex:23-65,70-124`.

Missing/invalid data is `:skip`/safe denial. The evaluator checks supplied facts only, so adapter binding checks must precede it. Logout/revocation follows `lib/sigra/auth.ex:1540-1571,1602-1634`.

### Evidence cannot become authority

**Source:** released Crosswake `auth_return.ex:279-307,343-358,614-633`.

`AuthReturn.new_envelope/1` rejects session, subject, org, authority, and token claims. It cannot select a session or grant a route/replay.

### Deterministic proof

**Sources:** `test/sigra/plug/fetch_session_test.exs:1-42,126-163`; `test/example/test/example/accounts/session_invalidation_test.exs:19-79`.

Use fixed times, real Ecto rows for storage effects, and Mox only for invocation/non-invocation seams. No sleeps, provider credentials, or browser-only proof.

## No Analog Found

None. The adapter is a new composition, with direct analogs for every responsibility.

## Metadata

**Analog search scope:** `test/example`, `lib/sigra`, `priv/templates/sigra.install`, `test/sigra`, `guides`, released Crosswake at `e3d6cbf`.  
**Files scanned:** 16 local and 6 external companion files.  
**Pattern extraction date:** 2026-08-08.
