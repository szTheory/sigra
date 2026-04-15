# Phase 19: Passkey Schema + Contexts — Research

**Researched:** 2026-04-15
**Domain:** WebAuthn / FIDO2 passkey data layer on Elixir (`wax_ ~> 0.7`) + Cloak vault promotion + hybrid lib+generator schema
**Confidence:** HIGH for wax_ API surface, HIGH for codebase patterns, HIGH for StrongKey/sign-count semantics. MEDIUM for COSE key serialization (see Open Questions — `:erlang.term_to_binary/1` vs CBOR is a call the planner must make).

## Summary

Phase 19 is pure data layer: `Sigra.Passkeys` wraps `wax_ 0.7` to turn raw FIDO2 ceremonies into storable `UserPasskey` rows, enforces two things wax_ deliberately leaves to the caller (StrongKey credential-confusion defense and sign-count monotonicity), and promotes the existing OAuth Cloak vault into core so `public_key` can be encrypted without inventing new crypto infrastructure. The phase is plug-agnostic — Phase 20 owns challenge storage and runtime config loading.

The wax_ 0.7 API is fully verified against hexdocs. Two semantic surprises worth calling out before planning:

1. `Wax.authenticate/6` takes a 6th argument (`credentials`) defaulting to `[]`; arity is 6, not 5 as the CONTEXT.md draft informally says in places. The `@spec` is firm.
2. wax_ returns the public key as a `Wax.CoseKey.t() :: %{integer() => integer() | binary()}` — an integer-keyed Elixir map, NOT PEM or raw bytes. Serialization is the caller's problem. This is the load-bearing decision not yet captured in CONTEXT.md: the phase must pick a serialization format for the encrypted `public_key` column.

The Cloak vault promotion (Plan 19-04) is well-scoped: real templates already exist at `priv/templates/sigra.gen.oauth/{vault.ex,encrypted_binary.ex}`, the supervision-tree injector exists, and the stub→real upgrade path has clear precedent. The risk isn't technical — it's making sure the feature-gate and namespace unification land cleanly in one pass.

**Primary recommendation:** Proceed as four plans per D-16 decomposition. Before Plan 19-01 Task 1 lands, the planner-inline wax_ spike (D-16) must also resolve the COSE key serialization decision — add it as a Decision-To-Make section in Plan 19-01's `<interfaces>` block.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Registration ceremony primitives (challenge → `Wax.register/3`) | Library (`Sigra.Passkeys.Registration`) | — | Security-critical crypto wrapper. Hybrid-lib invariant — never in generated code. |
| Authentication ceremony primitives (`Wax.authenticate/6`) | Library (`Sigra.Passkeys.Authentication`) | — | Same as registration. Plus StrongKey guard lives here. |
| Credential row persistence + changesets | Generated host schema (`UserPasskey`) | Library (`Sigra.Passkeys.Credential` struct) | Host owns data shape; library owns behavior. Matches `UserMFACredential` ↔ `Sigra.MFA.Credential`. |
| Sign-count policy decision | Library (`Sigra.Passkeys`) | Config (`%Sigra.Config{}.passkeys`) | Security policy = library responsibility. Config carries default + per-call override. |
| StrongKey credential-confusion guard (PK-07) | Library (`Sigra.Passkeys.authenticate/3`) | — | wax_ does not enforce user ownership of `allow_credentials`; caller must. Guard is a pure DB lookup, belongs in library context. |
| `public_key` encryption at rest | Generated `<app_module>.Encrypted.Binary` (via Cloak) | `<app_module>.Vault` | Cloak field type is schema-level; library never touches plaintext→ciphertext transform. |
| Challenge storage | **Not Phase 19** — Phase 20 `Sigra.Plug.PasskeyChallenge` | — | Phase 19 accepts challenge as explicit arg (D-09). |
| Audit event emission | Library via `Sigra.Audit.log_multi_safe/3` inside `Repo.transact/2` | Generated `AuditEvent` schema | Same pattern as `Sigra.OAuth`. |
| Vault promotion + upgrade step | Install generator (`Sigra.Install.Features.*`) + `Sigra.Upgrade` | — | Promotion is template orchestration, not runtime. |

## User Constraints (from CONTEXT.md)

### Locked Decisions (copied verbatim from `19-CONTEXT.md`)

**Schema**
- **D-01 (`aaguid` column type):** `:uuid` (Postgres `uuid` column, nullable). Cast once at registration via `Ecto.UUID.cast/1` on the raw 16 bytes returned by `Wax.AuthenticatorData.get_aaguid/1`. Nullable handles FIDO-U2F authenticators that return all-zero / `nil` AAGUID. **Supersedes** `.planning/research/ARCHITECTURE.md:249` and `.planning/research/STACK.md:39` which currently say `:binary`.
- **D-02 (`transports` column typing):** `{:array, :string}`, free-form, default `[]`. Expose `Sigra.Passkeys.known_transport?/1` helper for telemetry only, NOT for changeset validation. Sanity: `validate_length(:transports, max: 8)` + `update_change(:transports, &Enum.uniq/1)`.
- **D-03 (`UserPasskey` schema fields):** `user_id`, `credential_id :binary` (unique, unencrypted, indexed), `public_key :binary` (encrypted), `sign_count :integer`, `aaguid :uuid` (nullable), `nickname :string`, `device_hint :string`, `transports {:array, :string}`, `rp_id :string`, `last_used_at :utc_datetime_usec`, timestamps.
- **D-04 (library struct):** `Sigra.Passkeys.Credential` mirrors `Sigra.MFA.Credential` at `lib/sigra/mfa/credential.ex` field-by-field structurally.

**Configuration & API Shape**
- **D-05 (sign-count policy API shape):** `%Sigra.Config{}` default under `config.passkeys[:sign_count_policy]`, default `:warn`. Per-call NimbleOptions override. No `Application.get_env` in hot path.
- **D-06 (cap-per-user enforcement):** Library enforces inside `Repo.transact/2` (closes TOCTOU). `config.passkeys[:max_per_user]` default 10, per-call override. Returns `{:error, :passkey_cap_reached, %{count: N, cap: M}}`.
- **D-07 (credential-confusion defense, PK-07 / StrongKey CVE-2025-26788):** `authenticate/3` username-first only in Phase 19. Pre-lookup `{user_id, credential_id}` BEFORE calling `Wax.authenticate/6`. Nil → `{:error, :credential_not_owned}`. `userHandle` verified equal to `user_id` when present. Phase 21 adds `authenticate_discoverable/2` as sibling function.
- **D-08 (context API surface):** Fixed signatures — see CONTEXT.md for the full `@spec` block (locked).

**Security / Invariants**
- **D-09 (challenge storage):** NOT Phase 19. `Sigra.Passkeys.Registration.new_challenge/2` and `verify/4` accept challenge as explicit argument. Plug-agnostic for testability.
- **D-10 (sign-count regression audit payload):** Emit `:passkey_sign_count_regression` via `Sigra.Audit.log_multi_safe/3` inside same `Ecto.Multi` as sign-count update. Payload (JSONB): `%{credential_id, previous_count, presented_count, policy_applied, delta, rp_id}`. NOT denormalized onto `user_passkeys`.
- **D-11 (`rp_id` storage):** Set from `config.passkeys[:rp_id]` at registration. Never from client input. Advisory check at authenticate (log but don't block — P-3 is "detect + document", not "enforce").
- **D-12 (Ecto.Multi atomicity):** `register/3` = `Repo.transact/2` wrapping count query → cap check → UserPasskey insert → audit insert. Audit failure rolls back transaction. No email side effects in Phase 19.

**Encrypted Vault Promotion (Plan 19-04)**
- **D-13 (vault posture):** Promote existing OAuth `Cloak.Vault` into core as `<app_module>.Vault`. Unify `<context_module>.Encrypted.Binary` stub and `<app_module>.Encrypted.Binary` real onto single `<app_module>.Encrypted.Binary`. Feature-gated: real vault when ANY of `--passkeys` / `--mfa` / `--oauth`.
- **D-14 (`mix sigra.upgrade` step):** Detect stub + sensitive feature → write `vault.ex`, rewrite `encrypted.ex` → `use Cloak.Ecto.Binary`, inject `{MyApp.Vault, []}` via existing injector, print `CLOAK_KEY` generation banner.
- **D-15 (boot-check guard):** Raise at boot if `<app_module>.Encrypted.Binary` resolves to passthrough stub AND `config.passkeys.enabled?` is true.

**Spike / API Verification**
- **D-16 (wax_ 0.7 API spike shape):** Planner resolves wax_ 0.7 API inline during Plan 19-01 authoring and embeds verified API into the plan's `<interfaces>` block. Plan 19-01 Task 1 includes 10-line round-trip smoke assertion.

### Claude's Discretion
- Exact NimbleOptions schema shapes for `@register_opts_schema` / `@authenticate_opts_schema`.
- Ordering of migration fields (subject to `user_id` indexed + `credential_id` unique).
- Helper function visibility (`@doc false` vs internal aliases).
- Test fixture shape (reuse wax_ test vectors or generate own).
- Sign-count policy test location (`test/sigra/passkeys_test.exs` vs dedicated file).
- Count query style (`Repo.aggregate(:count)` vs manual `select count(*)`).

### Deferred Ideas (OUT OF SCOPE for Phase 19)
- Discoverable / usernameless / Conditional UI → Phase 21 sibling `authenticate_discoverable/2`.
- Per-user ceremony rate limiter → Phase 20 (PK-10).
- Runtime config loading (`rp_id`, `origin`, `attestation`, `user_verification`, `timeout_ms`) → Phase 20 (PK-09). Phase 19 reads these from `config.passkeys` but does not own the lifecycle.
- Registration email notification → Phase 21 (PK-UX-02).
- Sudo gating on enrollment → Phase 21 (PK-UX-01).
- `:attestation` enum + default → Phase 20.
- Strict transport enum → rejected permanently (spec-mandated permissive).
- Standalone Plan 19-00 spike plan → rejected in favor of D-16.
- Phase 19.1 vault-promotion split → rejected; kept as Plan 19-04.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-01 | Developer can add passkeys via `mix sigra.install --passkeys`. Adds `{:wax_, "~> 0.7"}` to mix.exs. | Verified wax_ 0.7.0 is current (May 2025) and Elixir 1.18/OTP 27 compatible. Installation pattern mirrors Plan 11-01's feature manifest. |
| PK-03 | Generates `UserPasskey` schema with all required fields including Cloak-encrypted `public_key`. | Schema template pattern verified in `priv/templates/sigra.install/core/user_mfa_credential.ex`. Cloak field pattern verified in `encrypted_binary.ex`. |
| PK-04 | Stores `rp_id` at registration for later rotation detection. | wax_ accepts `rp_id` as an option to `new_registration_challenge/1`. D-11 locks the write-at-registration source. |
| PK-05 | Exposes `Sigra.Passkeys` context with `register/3`, `authenticate/3`, `list_for_user/1`, `rename/2`, `delete/2`. Primitives in `Sigra.Passkeys.{Registration,Authentication}` wrapping wax_. | D-08 locks exact signatures. wax_ ceremony verified: `Wax.new_registration_challenge/1` → `Wax.register/3`, `Wax.new_authentication_challenge/1` → `Wax.authenticate/6`. |
| PK-07 | Verifies returned `credential_id` belongs to requested user — StrongKey CVE-2025-26788 defense. | D-07 pre-lookup by `{user_id, credential_id}` before calling wax_. Verified wax_ does NOT enforce ownership of `allow_credentials` — caller's invariant. |
| PK-08 | Enforces sign-count monotonicity with `:warn` default, plus `:require_reauth` / `:revoke` modes. | wax_ returns `sign_count` on `Wax.AuthenticatorData.t()` but deliberately does NOT enforce regressions — caller owns the policy. D-05 locks the three-mode NimbleOptions shape. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `wax_` | `~> 0.7` (0.7.0, May 18 2025) | WebAuthn / FIDO2 RP implementation | `[CITED: hex.pm/packages/wax_]` Only maintained Elixir WebAuthn library. Passes official WebAuthn test suite. Already chosen in STACK.md. Naming oddity: package is `wax_` (trailing underscore) due to name collision on hex. |
| `cloak_ecto` | `~> 1.3` (1.3.0) | Ecto field encryption at rest | `[VERIFIED: priv/templates/sigra.gen.oauth/*]` Already a transitive dependency via existing OAuth vault template; no new dep introduced. Phase 19 promotes existing templates. |
| `nimble_options` | `~> 1.1` | Per-call opts validation | `[VERIFIED: lib/sigra/config.ex, lib/sigra/organizations.ex:234, lib/sigra/upgrade/backfill.ex:76]` Dashbit convention, already pervasive across Sigra. |

### Supporting (already in deps)
| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `ecto_sql` | `~> 3.13` | `Repo.transact/2`, `:uuid` type, JSONB | `[VERIFIED]` D-06/D-12 rely on `Repo.transact/2` (Ecto 3.13+). Already in use across phases 13-18. |
| `jason` | existing | JSONB encoding of audit metadata | `[VERIFIED]` Already used by `Sigra.Audit`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `wax_` | `web_authn_lite` | Less feature-complete, no attestation verification. Rejected in STACK.md. |
| `cloak_ecto` | Raw `:crypto` AES-GCM | Loses key-rotation plumbing. cloak_ecto exists for exactly this case. |

### Installation
```elixir
# mix.exs
defp deps do
  [
    # ... existing ...
    {:wax_, "~> 0.7"}
  ]
end
```

**Version verification (required per research protocol):**
- wax_ 0.7.0 published May 18 2025 — `[CITED: hex.pm/packages/wax_]`.
- cloak_ecto 1.3.0 published Apr 2024 — already in use via OAuth vault template.
- Planner should run `mix hex.info wax_` before Plan 19-01 Task 1 to confirm no 0.7.x patch has shipped in the intervening month.

## Architecture Patterns

### System Architecture Diagram

```
Registration flow (Phase 19 scope = boxes marked [19]):

  Browser                  Plug layer (Phase 20)         Library (Phase 19)                   Repo
     │                            │                            │                              │
     │  GET /passkeys/new         │                            │                              │
     │ ─────────────────────────► │                            │                              │
     │                            │  Sigra.Passkeys.           │                              │
     │                            │  Registration.             │                              │
     │                            │  new_challenge(config,     │                              │
     │                            │     user)       [19]       │                              │
     │                            │ ─────────────────────────► │                              │
     │                            │                            │  Wax.new_registration_       │
     │                            │                            │  challenge/1                 │
     │                            │                            │  → %Wax.Challenge{}          │
     │                            │ ◄───────────────────────── │                              │
     │                            │  (plug stores in session,  │                              │
     │                            │   Phase 20)                │                              │
     │                            │                            │                              │
     │  POST attestation          │                            │                              │
     │ ─────────────────────────► │                            │                              │
     │                            │  Sigra.Passkeys.           │                              │
     │                            │  register(config, user,    │                              │
     │                            │    attestation, opts)      │                              │
     │                            │                     [19]   │                              │
     │                            │ ─────────────────────────► │                              │
     │                            │                            │ Repo.transact begin          │
     │                            │                            │ ┌──────────────────────────► │ count_for_user
     │                            │                            │ ◄──────────────────────────  │
     │                            │                            │ │ enforce cap (D-06)          │
     │                            │                            │ │ Wax.register/3              │
     │                            │                            │ │   → {AuthData, Attestation} │
     │                            │                            │ │ extract: credential_id,     │
     │                            │                            │ │  cose_key, aaguid, sign_cnt │
     │                            │                            │ │ serialize cose_key          │
     │                            │                            │ │ cast aaguid via Ecto.UUID   │
     │                            │                            │ │ insert UserPasskey ───────► │
     │                            │                            │ │ log_multi_safe audit event  │
     │                            │                            │ │    "passkey.register.*"     │
     │                            │                            │ └─ Repo.transact commit       │
     │                            │ ◄───────────────────────── │                              │
     │                            │                            │                              │

Authentication flow (StrongKey guard is load-bearing at step ★):

  Browser           Plug layer (Phase 20)         Library (Phase 19)                    Repo
     │                     │                            │                                │
     │  POST assertion     │                            │                                │
     │ ──────────────────► │                            │                                │
     │                     │  Sigra.Passkeys.           │                                │
     │                     │  authenticate(config,      │                                │
     │                     │    user, assertion, opts)  │                                │
     │                     │ ─────────────────────────► │                                │
     │                     │                            │ ★ Repo.get_by(UserPasskey,     │
     │                     │                            │    user_id:, credential_id:)   │
     │                     │                            │ ───────────────────────────►   │
     │                     │                            │ ◄─── row or nil ──────────     │
     │                     │                            │ if nil: return                 │
     │                     │                            │   {:error, :credential_not_    │
     │                     │                            │    owned}  ← StrongKey defense │
     │                     │                            │ if present: decrypt pubkey,    │
     │                     │                            │   deserialize COSE, verify     │
     │                     │                            │   userHandle == user_id,       │
     │                     │                            │   build allow_credentials=     │
     │                     │                            │   [{cred_id, cose_key}]        │
     │                     │                            │ Wax.authenticate/6             │
     │                     │                            │   → {:ok, auth_data}           │
     │                     │                            │ sign-count policy (D-05):      │
     │                     │                            │   if auth_data.sign_count <=   │
     │                     │                            │      stored.sign_count:        │
     │                     │                            │     apply policy               │
     │                     │                            │ Repo.transact begin            │
     │                     │                            │ ┌─ update sign_count ────────► │
     │                     │                            │ │ update last_used_at          │
     │                     │                            │ │ if regression: log_multi_    │
     │                     │                            │ │   safe(:passkey_sign_count_  │
     │                     │                            │ │   regression, D-10 payload)  │
     │                     │                            │ └─ commit                      │
```

The diagram is the primary use case — follow the arrows to trace from HTTP entry (Phase 20) through the Phase 19 library context into wax_, into the DB, and back. The StrongKey guard at ★ is the single most important flow-level invariant in the phase.

### Recommended Project Structure

```
lib/sigra/
├── passkeys.ex                         # Sigra.Passkeys — public context (D-08)
└── passkeys/
    ├── credential.ex                   # Sigra.Passkeys.Credential library struct (D-04)
    ├── registration.ex                 # Registration ceremony primitives wrapping wax_
    ├── authentication.ex               # Authentication ceremony + StrongKey guard
    ├── sign_count_policy.ex            # D-05 policy machine (:warn / :require_reauth / :revoke)
    └── cose_key.ex                     # COSE key serialization (see Open Questions)

priv/templates/sigra.install/
├── passkeys/                           # NEW feature dir — mirrors organizations/ shape
│   ├── user_passkey.ex                 # Host Ecto schema (D-03)
│   ├── create_user_passkeys.exs        # Migration template
│   └── passkey_fixtures.ex             # Phase 23 dependency — may live in core/
└── core/
    ├── vault.ex                        # NEW — promoted from sigra.gen.oauth/ (D-13)
    └── encrypted_binary.ex             # NEW — promoted from sigra.gen.oauth/ (D-13)

lib/sigra/install/features/
└── passkeys.ex                         # Sigra.Install.Features.Passkeys (mirrors organizations.ex)

test/sigra/
├── passkeys_test.exs                   # Context module happy + error paths
└── passkeys/
    ├── registration_test.exs
    ├── authentication_test.exs         # INCL. StrongKey guard regression test
    └── sign_count_policy_test.exs      # One regression scenario per mode (PK-08)
```

### Pattern 1: Library struct ↔ Generated schema (hybrid lib+generator)

**What:** Library owns a plain struct (`Sigra.Passkeys.Credential`) with `from_schema/1` + `to_params/1`. Host app owns a generated Ecto schema (`UserPasskey`) that the library never references by module name.

**When to use:** Every persistent domain object in Sigra — this is the invariant.

**Example (verbatim from `lib/sigra/mfa/credential.ex`):**
```elixir
# Source: lib/sigra/mfa/credential.ex (project codebase)
defmodule Sigra.MFA.Credential do
  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          encrypted_secret: binary() | nil,
          failed_attempts: non_neg_integer(),
          # ...
        }

  defstruct [:id, :user_id, :encrypted_secret, failed_attempts: 0, ...]

  @credential_fields [:id, :user_id, :encrypted_secret, :failed_attempts, ...]

  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    fields =
      @credential_fields
      |> Enum.reduce([], fn field, acc ->
        case Map.fetch(schema, field) do
          {:ok, value} -> [{field, value} | acc]
          :error -> acc
        end
      end)

    struct(__MODULE__, fields)
  end

  @spec to_params(t()) :: map()
  def to_params(%__MODULE__{} = credential) do
    credential
    |> Map.from_struct()
    |> Map.drop([:id, :inserted_at, :updated_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
```

Mirror this exactly for `Sigra.Passkeys.Credential`. Fields per D-03.

### Pattern 2: `config` as first arg + NimbleOptions per-call override

**What:** Every public context function takes `%Sigra.Config{}` as arg 1, plus a trailing `opts \\ []` that is validated against a module-attribute NimbleOptions schema. The config carries the default; the per-call opts can override for that single invocation.

**When to use:** Every public function on `Sigra.Passkeys`.

**Example (from `lib/sigra/organizations.ex:234`):**
```elixir
# Source: lib/sigra/organizations.ex (project codebase)
@org_config_schema [
  # keys...
]

def some_function(%Sigra.Config{} = config, user, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @org_config_schema)
  # ... use config.organizations as default, validated as override ...
end
```

For Phase 19:
```elixir
@authenticate_opts_schema [
  sign_count_policy: [type: {:in, [:warn, :require_reauth, :revoke]}, required: false],
  max_per_user: [type: :pos_integer, required: false]
]
```

### Pattern 3: Atomic Multi with audit via `log_multi_safe/3`

**What:** When a write needs an audit event, emit via `Sigra.Audit.log_multi_safe/3` inside the same `Repo.transact/2` / `Ecto.Multi`. Pass the derived `mfa_audit_opts`-style keyword list including `:audit_schema` from `config.audit`.

**Example (from `lib/sigra/mfa.ex` helper pattern + `lib/sigra/audit.ex:219`):**
```elixir
# Source: lib/sigra/audit.ex (project codebase)
@spec log_multi_safe(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
def log_multi_safe(%Ecto.Multi{} = multi, action, opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> multi
    _ -> do_log_multi(multi, action, opts, allow_reserved?: true)
  end
end
```

For Phase 19, build a `passkey_audit_opts/1` helper shaped like `mfa_audit_opts/1` in `lib/sigra/mfa.ex:45`:

```elixir
defp passkey_audit_opts(%Sigra.Config{} = config) do
  audit_config = Map.get(config, :audit, [])

  [
    repo: config.repo,
    audit_schema: Keyword.get(audit_config, :audit_schema)
  ]
end
```

Audit actions to reserve under the `passkey.` prefix (matches existing `oauth.`, `mfa.` prefixes in `lib/sigra/config.ex:543`):
- `passkey.register.success`
- `passkey.register.failure`
- `passkey.authenticate.success`
- `passkey.authenticate.failure`
- `passkey.sign_count_regression`
- `passkey.delete`
- `passkey.rename`

The `reserved_prefixes` default in `lib/sigra/config.ex:543` must be updated to include `"passkey."`.

### Anti-Patterns to Avoid

- **Calling wax_ from generated host code.** The host `UserPasskey` schema module must never `alias Wax` or reference `Wax.*`. All wax_ calls live behind `Sigra.Passkeys.{Registration,Authentication}`. This is the hybrid-lib invariant — breaking it means generated code starts needing security updates via `mix deps.update`, defeating the entire architecture.

- **Storing the COSE key map via `inspect/1` or Elixir term format without explicit decision.** The planner must pick a format and document it (see Open Questions).

- **Using `allow_credentials` from `Wax.new_authentication_challenge/1` as the StrongKey defense.** That's what StrongKey did wrong. The defense MUST be a Repo lookup scoped to `{user_id, credential_id}` BEFORE wax_ is called. The allow_credentials wax_ uses is a cryptographic narrowing, not an authorization boundary.

- **Checking sign-count regression in `Wax.authenticate/6`.** It doesn't. Don't assume it does. Post-wax_ comparison against the stored row is mandatory.

- **Encrypting `credential_id`.** It must be unencrypted and indexed — it's the lookup key for both StrongKey guard and `delete/2`. The only encrypted field is `public_key`.

- **Storing `aaguid` as `:binary`.** Superseded by D-01 to `:uuid`. `ARCHITECTURE.md:249` and `STACK.md:39` need to be updated in the same commit as the schema template lands.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebAuthn attestation verification | Custom CBOR parser + attestation format branching | `Wax.register/3` | 170+ test vectors, 5+ attestation formats, trust chain verification — months of work. |
| WebAuthn signature verification | Manual ECDSA/RSA verify over `authenticatorData ‖ clientDataHash` | `Wax.authenticate/6` | Subtle signature-base-string bugs are silent-auth-bypass class. |
| AAGUID parsing | `<<b1::8, b2::8, ...>>` bit syntax | `Wax.AuthenticatorData.get_aaguid/1` + `Ecto.UUID.cast/1` | Handles the all-zero nil case for FIDO-U2F. |
| At-rest field encryption | Raw `:crypto.crypto_one_time_aead/6` | `<app_module>.Encrypted.Binary` (cloak_ecto via promoted vault) | Key rotation, multi-cipher support, integrated with Ecto `cast/dump/load`. |
| Audit event persistence | Raw `Ecto.Multi.insert/4` calls | `Sigra.Audit.log_multi_safe/3` | Reserved-prefix bypass, schema-nil no-op for hostless mode, telemetry on failure. |
| Config validation | `Keyword.fetch!/2` + manual type checks | `NimbleOptions.validate!/2` | Generates `@moduledoc` automatically, matches rest of Sigra. |
| COSE key serialization | Jason-encoded pseudo-JSON of integer keys | `:erlang.term_to_binary/1` (Erlang term format) | See Open Questions — Jason cannot encode integer keys. ETF is the path-of-least-resistance but must be explicitly locked by planner. |

**Key insight:** Almost every edge case in passkey implementation is a silent-auth-bypass class bug. `wax_` is the single best-reviewed piece of code in the Elixir WebAuthn ecosystem. The phase's value-add is the boring boundary logic around wax_, not any re-implementation.

## Common Pitfalls

### Pitfall 1: Sign-count false positives on resident-key / synced authenticators (P-4)

**What goes wrong:** Apple iCloud Keychain, Google Password Manager, and most TPM-backed resident-key authenticators return `sign_count = 0` on every assertion. Strict monotonic check (`presented > stored`) rejects every authentication after the first. Support floods ensue.

**Why it happens:** W3C WebAuthn §6.1.1 explicitly permits zero sign counts. Early tutorials conflated "monotonic" with "must increase on every use".

**How to avoid:** D-05 locks `:warn` as the default. The policy machine must include the spec-compliant "skip check when stored == 0 AND presented == 0" carve-out from PITFALLS.md P-4.426:
```
if stored_sign_count == 0 and presented_sign_count == 0, do: :ok
if presented_sign_count > stored_sign_count, do: :ok
else apply policy (warn / require_reauth / revoke)
```

**Warning signs:** Test fixture with sign_count=5 stored, 5 presented (legitimate phantom regression for a sync'd credential). Test coverage: explicit zero-zero case + explicit decreasing-nonzero case.

### Pitfall 2: Credential-confusion bypass — StrongKey CVE-2025-26788 (P-6)

**What goes wrong:** Attacker initiates login flow as user B, but the browser returns an assertion signed by a credential owned by user A. Server verifies signature against A's public key (succeeds — A really does own the credential), then creates a session for B (because that's who the flow was for). Attacker is now user B without owning any of B's credentials.

**Why it happens:** `Wax.authenticate/6` takes `credentials :: [{credential_id, cose_key}]` and verifies the signature against whatever key matches. It is perfectly happy to verify user A's credential's signature — that's a correct cryptographic operation. The mistake is passing user A's credential into a flow initiated for user B.

**How to avoid:** D-07. `Repo.get_by(UserPasskey, user_id: user_id, credential_id: cred_id)` BEFORE constructing the `credentials` argument for wax_. If the row doesn't exist → `{:error, :credential_not_owned}`, stop. Additionally: when `userHandle` is present in the assertion response, verify it equals `user_id` (W3C WebAuthn §7.2 step 6.3.2).

**Warning signs:** Any version of `authenticate` that does `Repo.get_by(UserPasskey, credential_id: ...)` without `user_id` in the lookup. Any version that builds `credentials` from a query that returns rows across user boundaries. Any version that skips the `userHandle` check.

**Regression test (mandatory for PK-07 coverage):**
1. Create user A with passkey P_A (credential_id = `<<"alpha"...>>`).
2. Create user B.
3. Call `Sigra.Passkeys.authenticate(config, user_b, assertion_for_P_A, opts)`.
4. Assert `{:error, :credential_not_owned}`.
5. Assert no `Wax.authenticate/6` call was made (verify via telemetry or a wax_ test-double).

### Pitfall 3: RP ID rotation desync (P-3)

**What goes wrong:** Host app moves from `app.example.com` to `example.com` (or vice versa). Existing passkeys were bound to the old RP ID hash. Authentication silently fails for every existing user.

**How to avoid:** D-11 — store `rp_id` on every row at registration time. On authenticate, advisory-log if the row's `rp_id` doesn't match `config.passkeys[:rp_id]`. Phase 19 does not block; this is detect-and-document. Phase 20+ may add explicit migration tools. The detection is the deliverable.

### Pitfall 4: TOCTOU race on passkey cap enforcement

**What goes wrong:** Two concurrent requests both see `count_for_user == 9` and both insert, resulting in 11 credentials.

**How to avoid:** D-06. The count query and insert live inside the same `Repo.transact/2`. Postgres serializable isolation isn't required — the logical ordering is enforced by having both operations in one transaction, and the UNIQUE(user_id, credential_id) index catches the remaining edge case (duplicate credential_id collisions).

### Pitfall 5: COSE key serialization drift

**What goes wrong:** The phase encrypts the public key using Jason, silently converting integer COSE keys to string JSON keys, then later `authenticate/3` deserializes into a map with string keys that wax_ refuses.

**How to avoid:** Lock one serialization format (see Open Questions). `:erlang.term_to_binary/1` + `:erlang.binary_to_term(bin, [:safe])` on load is the path-of-least-resistance and preserves integer keys exactly. Documented + tested roundtrip is mandatory.

### Pitfall 6: Plaintext `public_key` shipping as a migration side effect

**What goes wrong:** D-13/D-14/D-15 landing in the same plan as the schema means a subtle ordering bug could result in the schema using the passthrough stub (plaintext) on fresh `--passkeys` installs.

**How to avoid:** D-15 boot-check. Plus Plan 19-04 must include an integration test that compiles a fresh `--passkeys` app and asserts that `<app_module>.Encrypted.Binary` resolves to the real Cloak module (not the stub).

## Code Examples

Verified patterns:

### wax_ registration call

```elixir
# Source: hexdocs.pm/wax_/Wax.html
@spec new_registration_challenge(opts) :: Wax.Challenge.t()
# opts includes: origin (required), rp_id, user_verification, timeout,
#   attestation, trusted_attestation_types, verify_trust_root,
#   acceptable_authenticator_statuses, android_key_allow_software_enforcement

@spec register(binary(), Wax.ClientData.raw_string(), Wax.Challenge.t()) ::
  {:ok, {Wax.AuthenticatorData.t(), Wax.Attestation.result()}}
  | {:error, Exception.t()}

# Usage inside Sigra.Passkeys.Registration.verify/4:
challenge = Wax.new_registration_challenge(
  origin: config.passkeys[:origin],
  rp_id: config.passkeys[:rp_id],
  user_verification: config.passkeys[:user_verification],
  attestation: config.passkeys[:attestation],  # default :none per PK-09/Phase 20
  timeout: config.passkeys[:timeout_ms]
)

# Note: challenge is passed back to the client as part of PublicKeyCredentialCreationOptions.
# Caller (Phase 20 plug) stores %Wax.Challenge{} in session for verification step.

# After client response:
{:ok, {auth_data, attestation_result}} =
  Wax.register(attestation_object_bin, client_data_json_raw, challenge)

# Extract storage fields:
acd = auth_data.attested_credential_data
credential_id = acd.credential_id            # Wax.CredentialId.t() :: binary()
cose_key       = acd.credential_public_key   # Wax.CoseKey.t() :: %{integer() => ...}
raw_aaguid     = acd.aaguid                  # binary() 16 bytes
sign_count     = auth_data.sign_count        # non_neg_integer()

# D-01 cast:
{:ok, aaguid_uuid} = Ecto.UUID.cast(raw_aaguid)

# D-13 encrypted field will serialize cose_key_bin via <app_module>.Encrypted.Binary:
cose_key_bin = :erlang.term_to_binary(cose_key)  # see Open Questions
```

### wax_ authentication call

```elixir
# Source: hexdocs.pm/wax_/Wax.html
@spec authenticate(
  Wax.CredentialId.t(),
  binary(),             # authenticator data
  binary(),             # signature
  Wax.ClientData.raw_string(),
  Wax.Challenge.t(),
  [{Wax.AuthenticatorData.credential_id(), Wax.CoseKey.t()}]
) :: {:ok, Wax.AuthenticatorData.t()} | {:error, Exception.t()}

def authenticate(credential_id, auth_data_bin, sig, client_data_json_raw, challenge, credentials \\ [])

# Usage inside Sigra.Passkeys.Authentication.verify/5:
# STEP 1 (StrongKey guard — D-07 — BEFORE touching wax_):
case Repo.get_by(UserPasskey, user_id: user.id, credential_id: credential_id) do
  nil -> {:error, :credential_not_owned}
  %UserPasskey{} = row ->
    # STEP 2: userHandle check (if present in response)
    if user_handle && user_handle != user.id, do: return {:error, :credential_not_owned}

    # STEP 3: decrypt + deserialize
    cose_key = :erlang.binary_to_term(row.public_key, [:safe])

    # STEP 4: build allow_credentials (single element for username-first)
    credentials = [{row.credential_id, cose_key}]

    # STEP 5: call wax_
    case Wax.authenticate(credential_id, auth_data_bin, sig, client_data_json_raw, challenge, credentials) do
      {:ok, auth_data} -> handle_sign_count(row, auth_data, config, opts)
      {:error, _} = err -> err
    end
end
```

### Sign-count policy branch

```elixir
# D-05 policy machine (skeleton — planner decides module structure)
defp apply_sign_count_policy(stored, presented, policy) do
  cond do
    stored == 0 and presented == 0 -> :ok              # P-4 zero-zero carve-out
    presented > stored              -> :ok              # normal monotonic increase
    true                            -> {:regression, policy}
  end
end

defp handle_regression({:regression, :warn}, ctx),          do: {:ok, :warned, audit_payload(ctx)}
defp handle_regression({:regression, :require_reauth}, ctx), do: {:error, :sign_count_regression}
defp handle_regression({:regression, :revoke}, ctx),         do: {:error, :sign_count_regression}
                                                             # plus: delete row in same Multi
```

### Vault + Encrypted.Binary templates (already exist — D-13 promotes)

```elixir
# Source: priv/templates/sigra.gen.oauth/vault.ex (verbatim, to be relocated)
defmodule <%= app_module %>.Vault do
  use Cloak.Vault, otp_app: <%= inspect(otp_app) %>

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: decode_env!("CLOAK_KEY"),
          iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var), do: var |> System.fetch_env!() |> Base.decode64!()
end

# Source: priv/templates/sigra.gen.oauth/encrypted_binary.ex (verbatim)
defmodule <%= app_module %>.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: <%= app_module %>.Vault
end
```

### Vault child-spec injector (already exists — D-14 reuses)

```elixir
# Source: lib/sigra/install/injector.ex:381-409 (project codebase)
@spec inject_vault_child(String.t(), String.t()) ::
        {:ok, String.t()} | {:already_injected, String.t()}
def inject_vault_child(file_contents, app_module) do
  vault_module = "#{app_module}.Vault"

  if String.contains?(file_contents, @vault_marker) do
    {:already_injected, file_contents}
  else
    case Regex.run(~r/children\s*=\s*\[/m, file_contents, return: :index) do
      [{pos, len}] ->
        insert_at = pos + len
        vault_child = "\n      {#{vault_module}, []},"
        {before, rest} = String.split_at(file_contents, insert_at)
        {:ok, before <> vault_child <> rest}

      _ ->
        {:ok, file_contents <> "\n# Add #{vault_module} to your application supervision tree:\n"}
    end
  end
end
```

### Config schema addition (for Plan 19-02)

```elixir
# Source: lib/sigra/config.ex (existing mfa/oauth pattern — add passkeys: slot)
passkeys: [
  type: :keyword_list,
  default: [],
  doc: "Passkey (WebAuthn) options.",
  keys: [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable passkey support. Default: true."
    ],
    sign_count_policy: [
      type: {:in, [:warn, :require_reauth, :revoke]},
      default: :warn,
      doc: "Sign-count regression policy. Default: :warn (P-4; matches Apple iCloud sync)."
    ],
    max_per_user: [
      type: :pos_integer,
      default: 10,
      doc: "Soft cap on passkeys per user. Default: 10."
    ],
    # Phase 20 owns the runtime config for rp_id, origin, attestation, user_verification,
    # timeout_ms. Phase 19 reads them but does not yet validate — Phase 19 tests pass
    # them in via literal config.
    rp_id: [type: {:or, [:string, nil]}, default: nil, doc: "RP ID. Phase 20."],
    origin: [type: {:or, [:string, nil]}, default: nil, doc: "RP origin. Phase 20."],
    attestation: [type: {:in, [:none, :indirect, :direct]}, default: :none, doc: "Phase 20."],
    user_verification: [type: {:in, [:preferred, :required, :discouraged]}, default: :preferred, doc: "Phase 20."],
    timeout_ms: [type: :pos_integer, default: 60_000, doc: "Phase 20."]
  ]
]
```

Also add `"passkey."` to the `reserved_prefixes` default in the `:audit` slot at `lib/sigra/config.ex:543`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AAGUID stored as `:binary` (raw 16 bytes) | AAGUID stored as `:uuid` (Postgres `uuid`) | D-01 (2026-04-15) | Matches community AAGUID registry key format for Phase 21; makes psql rows debuggable. Supersedes ARCHITECTURE.md:249, STACK.md:39. |
| Passkey core = stub `Encrypted.Binary` | Real Cloak vault feature-gated into core | D-13 (2026-04-15) | Eliminates "ship plaintext public_key on fresh install" risk. |
| `authenticate/3` dispatches on opts for usernameless | Username-first only in Phase 19; `authenticate_discoverable/2` sibling in Phase 21 | D-07 (2026-04-15) | Zero-breaking-change forward compat; literal PK-07 compliance; matches SimpleWebAuthn / py_webauthn / webauthn4j. |
| Sign-count strict reject | `:warn` default, three-mode policy | D-05 (2026-04-15) | Matches Apple iCloud / Google sync passkeys that legitimately return 0. Operational incident avoidance. |

**Deprecated/outdated:**
- Strict transport enum validation — `W3C WebAuthn §6.3.2 step 22` says treat unknowns as absent. D-02 follows spec.
- `Wax.Challenge` constructed directly by host apps — library owns it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:erlang.term_to_binary/1` round-trips Elixir integer-keyed maps exactly through the encrypted field cycle with no key-type drift | Code Examples (COSE serialization) | `[ASSUMED]` If wrong, authentication signature verification returns `{:error, :invalid_signature}` on every passkey — complete phase failure. MITIGATION: Plan 19-01 Task 1 smoke test MUST include a `register → authenticate` roundtrip against a real wax_ test vector. The smoke test validates this assumption empirically. |
| A2 | wax_ 0.7 has not shipped a 0.7.x patch release between May 2025 and April 2026 | Standard Stack | `[ASSUMED]` Verified 0.7.0 published 2025-05-18; did not fetch full version history. Low impact — any patch release will be API-compatible. Planner should run `mix hex.info wax_` as a 10-second first step. |
| A3 | `Ecto.UUID.cast/1` accepts a raw 16-byte binary AND produces a canonical 36-char lowercase string | Schema (D-01) | `[CITED: hexdocs.pm/ecto/Ecto.UUID.html]` Actually documented behavior — upgrading from `[ASSUMED]` to `[CITED]`. D-01 discussion log confirms this was verified. No risk. |
| A4 | `Sigra.Audit.log_multi_safe/3` accepts a `:metadata` opt that becomes the JSONB payload | Patterns — audit integration | `[ASSUMED]` Not yet verified by reading `build_attrs/4`. Planner should grep `lib/sigra/audit.ex` for the metadata key name before writing the audit call in Plan 19-03. Risk: payload key could be `:data`, `:meta`, or something else; compile-time error catches it. |
| A5 | `reserved_prefixes` enforcement can be bypassed for library-internal calls via `log_multi_safe/3` with `allow_reserved?: true` | Patterns — audit integration | `[VERIFIED: lib/sigra/audit.ex:224]` — `do_log_multi(multi, action, opts, allow_reserved?: true)` is exactly how `log_multi_safe/3` is implemented. Upgrading to VERIFIED. |
| A6 | Postgres `uuid` column can be NULL without a workaround | Schema (D-01) | `[CITED: PostgreSQL 15 docs]` Standard NULL semantics. No risk. |
| A7 | The existing `Sigra.Install.Features.Organizations` file shape is a sufficient template for `Sigra.Install.Features.Passkeys` | Project Structure | `[VERIFIED: lib/sigra/install/features/organizations.ex exists]` File exists; planner should read its shape before Plan 19-04 to confirm mirror-ability. |

## Open Questions

1. **COSE key serialization format.** The decision is not yet locked in CONTEXT.md.
   - What we know: `Wax.CoseKey.t() :: %{integer() => integer() | binary()}`. Integer keys disqualify `Jason.encode/2` (which silently stringifies). Options: (a) `:erlang.term_to_binary/1`, (b) `cbor_erlang` hex package, (c) manual COSE binary encode.
   - What's unclear: The planner has not committed to one. Downstream Plan 19-01 Task 1 smoke test behavior depends on this choice.
   - **Recommendation:** Lock on `:erlang.term_to_binary/1` + `:erlang.binary_to_term(bin, [:safe])`. Rationale: (1) zero new deps, (2) round-trips Elixir maps with integer keys exactly, (3) the encrypted column stores opaque bytes anyway so human-readability of the plaintext is irrelevant, (4) matches how `Sigra.MFA` stores TOTP raw secret binaries. The `[:safe]` decode flag prevents atom-creation DoS. Document the decision in Plan 19-01's `<interfaces>` block as D-17. **If the planner disagrees**, CBOR is the only other defensible choice — but it adds a transitive dep for zero practical benefit in this phase.

2. **Where does the audit payload land in `log_multi_safe/3`?** The key name (`:metadata` vs `:data` vs `:meta`) is not verified in this research pass. Trivial to resolve by reading `lib/sigra/audit/changeset.ex` for the field mapping. Planner should verify before writing the audit call.

3. **Does Plan 19-04 vault promotion need a data migration for existing MFA rows under the stub?** D-14 says "expected: zero rows for fresh passkey adopters, but migration is safe even when non-empty." The planner must confirm: on a v1.0 host with `--mfa` + `encrypted_secret` written via stub (plaintext), does the promotion correctly re-encrypt? Or does the cutover require `mix cloak.migrate.ecto`? The research pass did not verify cloak_ecto's migrate-from-plaintext story end-to-end. Plan 19-04 must include an integration test that seeds MFA rows under the stub, runs the upgrade, and asserts `:crypto`-unreadable ciphertext afterward.

4. **`credential_id` column size.** W3C WebAuthn says credential IDs are ≤ 1023 bytes. Postgres `bytea` has no practical size limit. MySQL/SQLite generators need to pick a column size. Phase 19 targets PG as blessed path, but if the MySQL/SQLite adapter templates are touched, `VARBINARY(1023)` is the spec-safe limit.

5. **Should `Sigra.Passkeys.known_transport?/1` be public or `@doc false`?** D-02 says "exposed for telemetry." Public is the right call — host apps may want the function for their own dashboards. Recommend public with `@doc since: "0.7.0"`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL ≥ 12 | `:uuid` column, JSONB audit, `citext` user email | ✓ (project constraint) | Project-enforced | — |
| Erlang/OTP ≥ 27 | `:crypto` (for Cloak) + wax_ crypto primitives | ✓ (project constraint) | Sigra requires OTP 27 | — |
| Elixir ≥ 1.18 | Existing Sigra baseline | ✓ | Project baseline | — |
| `wax_` 0.7 | Phase 19 itself | NEW (to be added) | 0.7.0 (May 2025) | — |
| `cloak_ecto` 1.3 | Vault + Encrypted.Binary (existing OAuth path) | ✓ (transitive via OAuth gen templates) | 1.3.0 | — |
| `CLOAK_KEY` env var | Plan 19-04 vault promotion | Runtime concern (host app) | — | `mix sigra.upgrade` prints generation banner; dev/test uses fixture key. |
| `mix hex.info wax_` connectivity | Plan 19-01 planner spike | Planner's responsibility | — | Fall through to cached hexdocs if hex.pm is unreachable. |

**Missing dependencies with no fallback:** None. Phase is purely in-tree code + library additions.

**Missing dependencies with fallback:** `CLOAK_KEY` at first boot — Plan 19-04 must print the generation command (`32 |> :crypto.strong_rand_bytes() |> Base.encode64()`) prominently in the upgrade task output.

## Validation Architecture

Sigra's config has `workflow.nyquist_validation` enabled by default. This section is the handoff to the downstream VALIDATION.md generator.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir ~> 1.18) with Ecto SQL Sandbox |
| Config file | `test/test_helper.exs` (existing), `config/test.exs` (existing) |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/passkeys_test.exs test/sigra/passkeys/` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| Prereq | Live Postgres at `localhost:5432` with `postgres`/`postgres` creds (per CLAUDE.md — no `:postgres` exclusion tag) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-01 | wax_ dep is declared + mix compiles | smoke | `mix deps.get && mix compile --warnings-as-errors` | ❌ Wave 0 |
| PK-03 | `UserPasskey` schema has all D-03 fields with correct types + indexes | unit | `mix test test/sigra/install/features/passkeys_test.exs -x` | ❌ Wave 0 |
| PK-03 | `public_key` round-trips through `<app_module>.Encrypted.Binary` | integration | `mix test test/sigra/passkeys/encrypted_roundtrip_test.exs -x` | ❌ Wave 0 |
| PK-04 | `register/3` writes `config.passkeys[:rp_id]` into the row | unit | `mix test test/sigra/passkeys_test.exs -x --only rp_id_at_registration` | ❌ Wave 0 |
| PK-05 | `Sigra.Passkeys.{register,authenticate,list_for_user,rename,delete,count_for_user}/*` exist with correct arity | unit | `mix test test/sigra/passkeys_test.exs -x` | ❌ Wave 0 |
| PK-05 | `Wax.register/3` → `Wax.authenticate/6` round-trip against a real test vector | integration | `mix test test/sigra/passkeys/wax_roundtrip_test.exs -x` | ❌ Wave 0 |
| PK-07 | StrongKey guard rejects cross-user credential presentation | unit | `mix test test/sigra/passkeys/authentication_test.exs -x --only strongkey_guard` | ❌ Wave 0 |
| PK-07 | `userHandle` mismatch rejected | unit | `mix test test/sigra/passkeys/authentication_test.exs -x --only user_handle_mismatch` | ❌ Wave 0 |
| PK-08 | `:warn` mode logs + inserts audit event + allows login | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs -x --only warn_mode` | ❌ Wave 0 |
| PK-08 | `:require_reauth` mode returns `{:error, :sign_count_regression}` | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs -x --only require_reauth_mode` | ❌ Wave 0 |
| PK-08 | `:revoke` mode deletes credential + returns error | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs -x --only revoke_mode` | ❌ Wave 0 |
| PK-08 | Zero-zero case: stored=0 && presented=0 is NOT a regression | unit | `mix test test/sigra/passkeys/sign_count_policy_test.exs -x --only zero_zero` | ❌ Wave 0 |
| D-06 | TOCTOU cap enforcement — concurrent register rejected at N+1 | integration | `mix test test/sigra/passkeys_test.exs -x --only cap_concurrent` | ❌ Wave 0 |
| D-13 | Fresh `--passkeys` install resolves `<app_module>.Encrypted.Binary` to real Cloak module (NOT stub) | integration | `mix test test/sigra/install/vault_promotion_test.exs -x` | ❌ Wave 0 |
| D-14 | `mix sigra.upgrade` promotes stub → real vault idempotently | integration | `mix test test/upgrade_test.exs -x --only vault_promotion` | ❌ Wave 0 |
| D-15 | Boot raises when stub + passkeys enabled | unit | `mix test test/sigra/application_test.exs -x --only boot_check_vault_stub` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/passkeys/ test/sigra/passkeys_test.exs --warnings-as-errors` (seconds)
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --warnings-as-errors` (~minute)
- **Phase gate:** Full suite + `mix credo --strict` + `mix dialyzer` green before `/gsd-verify-work`

### Wave 0 Gaps
Every test file above is new to Phase 19. Planner must include in Wave 0 of the appropriate plan:

- [ ] `test/sigra/passkeys_test.exs` — context module happy+error paths (PK-05)
- [ ] `test/sigra/passkeys/registration_test.exs` — registration ceremony unit tests
- [ ] `test/sigra/passkeys/authentication_test.exs` — authentication + StrongKey guard + userHandle check (PK-07)
- [ ] `test/sigra/passkeys/sign_count_policy_test.exs` — one regression scenario per mode (PK-08) + zero-zero carve-out + normal monotonic
- [ ] `test/sigra/passkeys/wax_roundtrip_test.exs` — 10-line register→authenticate smoke test against wax_ fixtures (D-16 Task-1 hedge)
- [ ] `test/sigra/passkeys/encrypted_roundtrip_test.exs` — `public_key` serializes → encrypts → decrypts → deserializes → wax_ accepts (covers A1 in Assumptions Log)
- [ ] `test/sigra/install/features/passkeys_test.exs` — schema/migration template rendering
- [ ] `test/sigra/install/vault_promotion_test.exs` — D-13 fresh-install vault resolution
- [ ] `test/sigra/application_test.exs` (extend existing if present) — D-15 boot-check raise
- [ ] `test/upgrade_test.exs` extension — D-14 `mix sigra.upgrade` vault-promotion path
- [ ] `test/support/passkey_fixtures.ex` — shared wax_ test-vector fixtures (credential_id, cose_key map, sign_count, aaguid)
- [ ] Framework install: **none required** — ExUnit + Ecto SQL Sandbox already configured.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | wax_ 0.7 for WebAuthn RP ceremony; StrongKey guard (D-07) for ownership assertion |
| V3 Session Management | partial | Challenge lifetime owned by Phase 20 (Plug session, 60s TTL). Phase 19 contributes a challenge that Phase 20 stores. |
| V4 Access Control | yes | `Sigra.Passkeys.delete/2` / `rename/2` must scope by user — planner must include negative-path test (cross-user delete attempt returns `{:error, :not_found}`, not `{:error, :forbidden}`, to avoid enumeration) |
| V5 Input Validation | yes | NimbleOptions on all public surfaces; Ecto changesets on `UserPasskey`; `validate_length(:transports, max: 8)` |
| V6 Cryptography | yes | cloak_ecto (AES-256-GCM) for `public_key` at rest; `:crypto.strong_rand_bytes/1` already used by `Wax.new_registration_challenge/1` for challenge bytes; never hand-roll |
| V8 Data Protection | yes | Encrypted `public_key` at rest; plaintext `credential_id` is not PII (random binary); `aaguid` is device-type metadata, not PII |
| V10 Malicious Code | — | No dynamic code generation in phase |
| V14 Configuration | yes | D-15 boot-check guard on stub+passkeys combo; runtime `CLOAK_KEY` requirement documented |

### Known Threat Patterns for WebAuthn / FIDO2 on Elixir

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| StrongKey credential confusion (CVE-2025-26788) | Spoofing / Elevation of Privilege | D-07 pre-lookup `{user_id, credential_id}` BEFORE `Wax.authenticate/6` + `userHandle` equality check (WebAuthn §7.2 step 6.3.2) |
| Sign-count false positive (P-4) | Denial of Service (self-inflicted) | D-05 `:warn` default + zero-zero carve-out + three-mode NimbleOptions |
| Challenge replay (P-1) | Spoofing | DEFERRED to Phase 20 — challenge storage/TTL lives in `Sigra.Plug.PasskeyChallenge`. Phase 19 accepts challenge as explicit arg, never trusts clientDataJSON (D-09) |
| Credential hard-DoS (unbounded rows) | Denial of Service | D-06 cap-per-user inside `Repo.transact/2` |
| Plaintext `public_key` leak on minimal install | Information Disclosure | D-13 feature-gated real vault + D-15 boot-check |
| RP ID rotation silent breakage (P-3) | Availability | D-11 store `rp_id` at registration, advisory-log mismatch at authenticate |
| Cross-user `delete/2` enumeration | Information Disclosure | Scope `delete/2` lookup by `{user_id, credential_id}`, return `:not_found` on cross-user (not `:forbidden`) |
| Atom DoS via `binary_to_term/1` on COSE key deserialize | Denial of Service | Use `:erlang.binary_to_term(bin, [:safe])` — the `[:safe]` flag rejects atom creation |

## Project Constraints (from CLAUDE.md)

All directives from the project CLAUDE.md that the planner MUST honor:

- **Blessed framework:** Phoenix 1.8+ / Ecto 3.13+ as primary target. `Repo.transact/2` is the transactional primitive (not deprecated `Repo.transaction/2`).
- **Primary DB:** PostgreSQL. Phase 19 targets PG exclusively for the D-01 `:uuid` column decision — MySQL/SQLite adapters can use `:binary_id` fallback if the template is reused, but that is out of scope for Phase 19 unless the planner explicitly opts in.
- **Security:** OWASP standards. Argon2id default (not relevant here — passkeys bypass passwords). All tokens HMAC-protected (relevant for Phase 20 challenge tokens, not Phase 19). Enumeration prevention by default (relevant for `delete/2`, `rename/2` cross-user paths).
- **Dependencies:** Minimal transitive deps. `wax_` is the single new dep. Copy-paste over deps when code is small and stable — but wax_ is not small enough to vendor.
- **LiveView:** Supported but optional. Login/logout via HTTP POST. Phase 19 is below the LiveView layer entirely.
- **Testing:** Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained.
- **GSD enforcement:** All code changes must be made through a GSD phase workflow — this research feeds the planner.

## Sources

### Primary (HIGH confidence)
- `[VERIFIED: hexdocs.pm/wax_/Wax.html]` — `Wax.new_registration_challenge/1`, `Wax.register/3`, `Wax.new_authentication_challenge/1`, `Wax.authenticate/6` signatures. Option list. Return tuple shapes.
- `[VERIFIED: hexdocs.pm/wax_/Wax.Challenge.html]` — `%Wax.Challenge{}` fields list (17 fields including `allow_credentials`, `rp_id`, `origin`, `attestation`, `user_verification`, `type`, `bytes`).
- `[VERIFIED: hexdocs.pm/wax_/Wax.AuthenticatorData.html]` — `get_aaguid/1 :: binary() | nil`; `sign_count: non_neg_integer`; attested_credential_data link.
- `[VERIFIED: hexdocs.pm/wax_/Wax.AttestedCredentialData.html]` — `credential_id :: Wax.CredentialId.t()`, `credential_public_key :: Wax.CoseKey.t()`, `aaguid :: binary()`.
- `[VERIFIED: hexdocs.pm/wax_/Wax.CoseKey.html]` — `Wax.CoseKey.t() :: map()` with integer keys.
- `[VERIFIED: github.com/tanguilp/wax/blob/master/lib/wax.ex]` — `authenticate/6` arg order, allow_credentials semantics, explicit confirmation that sign-count regression is NOT enforced by wax_.
- `[VERIFIED: priv/templates/sigra.gen.oauth/vault.ex]` — existing real Cloak vault template (D-13 source material).
- `[VERIFIED: priv/templates/sigra.gen.oauth/encrypted_binary.ex]` — existing Cloak.Ecto.Binary wrapper.
- `[VERIFIED: priv/templates/sigra.install/core/encrypted.ex]` — passthrough stub (D-13 target of promotion).
- `[VERIFIED: priv/templates/sigra.install/core/user_mfa_credential.ex]` — host schema shape precedent.
- `[VERIFIED: lib/sigra/mfa/credential.ex]` — library struct shape precedent for `Sigra.Passkeys.Credential` (D-04).
- `[VERIFIED: lib/sigra/config.ex:380-550]` — `%Sigra.Config{}` NimbleOptions schema + `mfa:` / `oauth:` / `audit:` slot patterns.
- `[VERIFIED: lib/sigra/audit.ex:219-237]` — `log_multi_safe/3` implementation + `allow_reserved?: true` flag.
- `[VERIFIED: lib/sigra/oauth.ex:89,162,169,177,184,193,312,391]` — `Sigra.Audit.log_safe/3` scope-based call pattern.
- `[VERIFIED: lib/sigra/install/injector.ex:380-410]` — `inject_vault_child/2` supervision tree injector (reused for D-14).
- `[VERIFIED: lib/sigra/mfa.ex:45-53]` — `mfa_audit_opts/1` helper shape (mirror as `passkey_audit_opts/1`).
- `[VERIFIED: lib/sigra/install/features/core.ex:220-240]` — install feature emission pattern + encrypted.ex stub emission at line 232-233 (D-13 target).
- `[CITED: .planning/research/PITFALLS.md §P-4]` — sign-count regression guidance, zero-zero carve-out rationale.
- `[CITED: .planning/research/PITFALLS.md §P-6]` — StrongKey CVE-2025-26788 exact attack pattern.
- `[CITED: .planning/phases/19-passkey-schema-contexts/19-CONTEXT.md]` — all locked decisions D-01 through D-16.

### Secondary (MEDIUM confidence)
- `[CITED: w3.org/TR/webauthn-2/#sctn-verifying-assertion]` — §7.2 step 6.3.2 userHandle equality requirement.
- `[CITED: w3.org/TR/webauthn-2/#sctn-authenticator-data]` — §6.1.1 sign count format + constant-zero permissibility.
- `[CITED: securing.pl/en/cve-2025-26788]` — StrongKey CVE writeup.
- `[CITED: hex.pm/packages/wax_]` — wax_ 0.7.0 published 2025-05-18 (HIGH confidence on the version string; MEDIUM on "no later patch" — planner should `mix hex.info wax_` before Plan 19-01).

### Tertiary (LOW confidence / assumption)
- A1 in Assumptions Log: `:erlang.term_to_binary/1` round-trip preserves integer-keyed COSE maps exactly → **mandatory smoke test in Plan 19-01 Task 1 validates empirically**.

## Metadata

**Confidence breakdown:**
- wax_ 0.7 API surface: HIGH — all signatures verified via hexdocs + github source
- Schema design (D-01 through D-04): HIGH — community conventions cross-referenced with existing Sigra precedent
- StrongKey defense (D-07): HIGH — W3C spec + CVE writeup + wax_ source confirm caller-owns-ownership
- Sign-count policy (D-05, D-10): HIGH — PITFALLS.md P-4 guidance matches W3C issue tracker + Apple iCloud behavior
- Cloak vault promotion (D-13/D-14/D-15): MEDIUM-HIGH — templates exist, injector exists, upgrade scaffolding exists. The lone gap is the re-encryption path for pre-existing stub-written MFA rows (Open Question 3)
- COSE key serialization: MEDIUM — ETF assumption is sound but must be validated by smoke test
- Audit payload key name: LOW — not verified in this pass (Open Question 2)

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (30 days — wax_ and cloak_ecto are both slow-moving stable libraries; Sigra patterns change only via phase commits)
