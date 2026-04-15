# Phase 19: Passkey Schema + Contexts — Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

`Sigra.Passkeys` is the credential-confusion-safe, monotonic-sign-count **data layer** around `wax_ ~> 0.7`, with Cloak-encrypted `public_key` reusing (and promoting) the existing OAuth vault — plus the generated `UserPasskey` host schema, context functions, and sign-count policy machinery.

**In Phase 19:**
- `{:wax_, "~> 0.7"}` added to `mix.exs`
- Generated `UserPasskey` Ecto schema (host app) + migration template
- `Sigra.Passkeys` context: `register/3`, `authenticate/3`, `list_for_user/1`, `rename/2`, `delete/2`, `count_for_user/1`
- Ceremony primitives in `Sigra.Passkeys.Registration` and `Sigra.Passkeys.Authentication` wrapping `wax_`
- Sign-count regression handling — three policy branches (`:warn`/`:require_reauth`/`:revoke`) with regression test per mode
- Credential-confusion defense (StrongKey CVE-2025-26788) enforced inside `authenticate/3` via `{user_id, credential_id}` pre-lookup
- Cap-per-user enforcement inside `Repo.transact/2` (Hard-DoS guard)
- Cloak vault promotion + unification (existing OAuth vault graduates into core)
- `mix sigra.upgrade` step for v1.0 hosts enabling passkeys

**NOT in Phase 19 (deferred to Phases 20/21):**
- `Sigra.Plug.PasskeyChallenge` (Phase 20, PK-06)
- Runtime config loading + rate limiter (Phase 20, PK-09/PK-10)
- `authenticate_discoverable/2` + Conditional UI autofill (Phase 21, PK-UX-08)
- JS hooks, LiveViews, POST-auth controller (Phase 21)
- Email notification on registration (Phase 21, PK-UX-02)
- Sudo gating on enrollment (Phase 21, PK-UX-01)

</domain>

<decisions>
## Implementation Decisions

### Schema

- **D-01 (`aaguid` column type):** `:uuid` (Postgres `uuid` column, nullable). Cast once at registration via `Ecto.UUID.cast/1` on the raw 16 bytes returned by `Wax.AuthenticatorData.get_aaguid/1`. Nullable handles FIDO-U2F authenticators that return all-zero / `nil` AAGUID. Rationale: every community AAGUID registry — including `passkeydeveloper/passkey-authenticator-aaguids` used in Phase 21 — keys entries by canonical 36-char lowercase UUID strings. Storing the same format means `Map.get(registry, passkey.aaguid)` works with zero conversion, and psql rows are debuggable. Matches SimpleWebAuthn, webauthn4j, Hanko. Supersedes `ARCHITECTURE.md:249` and `STACK.md:39` which currently say `:binary` — both written before the wax_ source spike.

- **D-02 (`transports` column typing):** `{:array, :string}`, free-form, default `[]`. Exposed helper `Sigra.Passkeys.known_transport?/1` for telemetry only, **not** changeset validation. Rationale: W3C WebAuthn §6.3.2 step 22 says *"treat unknown transport values as if the member were absent"*. Transports are a client-side hint for the platform picker, not a security boundary. Strict enum would lock out enrollment the day Chrome ships a new transport. Matches SimpleWebAuthn, webauthn4j, py_webauthn — nobody enforces the enum at cast-time. Changeset sanity cap: `validate_length(:transports, max: 8)` and `update_change(:transports, &Enum.uniq/1)`.

- **D-03 (`UserPasskey` schema fields):** `user_id`, `credential_id :binary` (unique, unencrypted, indexed), `public_key :binary` (encrypted via `<app_module>.Encrypted.Binary`), `sign_count :integer`, `aaguid :uuid` (nullable, D-01), `nickname :string`, `device_hint :string`, `transports {:array, :string}` (D-02), `rp_id :string`, `last_used_at :utc_datetime_usec`, `inserted_at`/`updated_at`. `rp_id` is stored at registration time per PK-04 (P-3 detection).

- **D-04 (library struct):** Follows the `Sigra.MFA.Credential` precedent at `lib/sigra/mfa/credential.ex`. `Sigra.Passkeys.Credential` is a library struct that maps to/from the generated host `UserPasskey` schema. Library owns behavior; host app owns data shape (hybrid lib+generator pattern).

### Configuration & API Shape

- **D-05 (sign-count policy API shape):** `%Sigra.Config{}` default under `config.passkeys[:sign_count_policy]`, default `:warn`. Per-call NimbleOptions override via `authenticate(config, user, params, sign_count_policy: :require_reauth)`. No `Application.get_env` in the hot path. Matches `config.mfa` / `config.oauth` convention exactly (`lib/sigra/config.ex`, `lib/sigra/mfa.ex:118-636`, `lib/sigra/oauth.ex:498`). Testability: tests build a `%Sigra.Config{}` literal — zero `Application.put_env` cleanup.

- **D-06 (cap-per-user enforcement):** Library enforces inside `Repo.transact/2` (closes TOCTOU race between count and insert). Config shape matches D-05: `config.passkeys[:max_per_user]`, default 10, per-call override. Returns `{:error, :passkey_cap_reached, %{count: N, cap: M}}`. Phase 21 LiveView calls `Sigra.Passkeys.count_for_user/1` purely to disable the "Add passkey" button at the cap — never the gatekeeper. Matches Hanko, `guardian_db`, Auth0. Non-LiveView callers (Oban workers, custom controllers, iex) get the same DoS protection for free.

- **D-07 (credential-confusion defense — PK-07 / StrongKey CVE-2025-26788):** `Sigra.Passkeys.authenticate/3` is **username-first only** in Phase 19. Before calling `Wax.authenticate/5`, the library does `Repo.get_by(UserPasskey, user_id: user_id, credential_id: cred_id)`. If nil → `{:error, :credential_not_owned}` — this is the StrongKey guard firing. The `userHandle` in the assertion response is additionally verified to equal `user_id` when present (WebAuthn §7.2 step 6.3.2). `wax_` itself does not enforce user ownership — it only checks the signature against a passed allow-list — so the caller (us) owns this invariant. Phase 21 will add `Sigra.Passkeys.authenticate_discoverable/2` as a **sibling function** (not a flag, not an arity overload) — no breaking change. Matches SimpleWebAuthn, py_webauthn, webauthn4j (all of which push credential resolution to the caller).

- **D-08 (context API surface, locked for Phase 19):**
  ```elixir
  @spec register(Config.t(), User.t(), attestation :: map(), keyword()) ::
          {:ok, Credential.t()}
          | {:error, :passkey_cap_reached, %{count: non_neg_integer(), cap: pos_integer()}}
          | {:error, Ecto.Changeset.t()}
          | {:error, atom()}
  def register(config, user, attestation, opts \\ [])

  @spec authenticate(Config.t(), User.t(), assertion :: map(), keyword()) ::
          {:ok, Credential.t()}
          | {:error, :credential_not_owned}          # StrongKey guard fired
          | {:error, :sign_count_regression}         # when policy = :require_reauth or :revoke
          | {:error, atom()}
  def authenticate(config, user, assertion, opts \\ [])

  @spec list_for_user(Config.t(), User.t()) :: [Credential.t()]
  @spec count_for_user(Config.t(), User.t()) :: non_neg_integer()
  @spec rename(Config.t(), Credential.t() | id :: term(), new_nickname :: String.t()) ::
          {:ok, Credential.t()} | {:error, Ecto.Changeset.t() | :not_found}
  @spec delete(Config.t(), User.t(), credential_id :: binary()) ::
          {:ok, Credential.t()} | {:error, :not_found}
  ```
  `config` is the first argument on every function — same as `Sigra.MFA`, `Sigra.OAuth`, `Sigra.Token`.

### Security / Invariants

- **D-09 (challenge storage — locked, not Phase 19):** Phase 19 writes the registration and authentication **primitives** but does NOT own challenge storage — that's Phase 20's `Sigra.Plug.PasskeyChallenge`. Phase 19's `Sigra.Passkeys.Registration.new_challenge/2` and `verify/4` accept the challenge as an explicit argument (the caller owns lookup/storage). This keeps Phase 19 plug-agnostic and testable without Plug.Conn.

- **D-10 (audit event payload on sign-count regression):** Emit `:passkey_sign_count_regression` audit event via `Sigra.Audit.log_multi_safe/3` inside the same `Ecto.Multi` as the sign-count update. Payload (JSONB): `%{credential_id, previous_count, presented_count, policy_applied, delta, rp_id}`. Data is NOT denormalized onto `user_passkeys` — Phase 21's banner queries the audit table by `credential_id`.

- **D-11 (`rp_id` storage per PK-04 / P-3 defense):** `user_passkeys.rp_id` is set from `config.passkeys[:rp_id]` at registration time. Never taken from client input. Read at authenticate time as an advisory check (log if mismatch but don't block — P-3 is "detect and document" not "enforce").

- **D-12 (Ecto.Multi atomicity for register):** `Sigra.Passkeys.register/3` body: `Repo.transact/2` wrapping (1) count query, (2) cap check, (3) UserPasskey insert, (4) audit event insert. If audit insert fails → whole transaction rolls back. No email side-effects in Phase 19 (those are Phase 21's `Sigra.Passkeys.Notifications` using Oban).

### Encrypted Vault Promotion

- **D-13 (encrypted vault posture — IN SCOPE for Phase 19):** Promote the existing OAuth `Cloak.Vault` into core as `<app_module>.Vault`. Unify the two encrypted-binary namespaces (`<context_module>.Encrypted.Binary` stub vs `<app_module>.Encrypted.Binary` real) onto a single `<app_module>.Encrypted.Binary`. Feature-gated: emit the real vault when ANY of `--passkeys`/`--mfa`/`--oauth` is set; keep the stub only for truly minimal installs. Rationale: the phase goal literally says "reuses the existing `Sigra.Vault` Cloak pipeline — no new encryption infra", and that's only true once `Sigra.Vault` exists in core. This is **promotion, not invention** — the real vault template already exists at `priv/templates/sigra.gen.oauth/vault.ex`. Shipping passkeys with a plaintext stub for `public_key` would be silently worse than any scope cost of this unification.

- **D-14 (upgrade path — `mix sigra.upgrade` extension):** Detect stub + sensitive feature, write `vault.ex`, rewrite `encrypted.ex` → `use Cloak.Ecto.Binary`, inject `{MyApp.Vault, []}` via existing injector (`lib/sigra/install/injector.ex:381-392`), print a `CLOAK_KEY` generation banner. For hosts with existing MFA/OAuth rows under the OAuth real vault: no re-encryption needed (same namespace). For hosts with pre-existing MFA rows under the stub: generate a `mix cloak.migrate.ecto`-style data migration (expected: zero rows for fresh passkey adopters, but migration is safe even when non-empty).

- **D-15 (boot-check guard):** `Sigra.Application` (or the generated host `Auth` supervisor) checks at boot: if `<app_module>.Encrypted.Binary` resolves to the passthrough stub module AND `config.passkeys.enabled?` is true → `raise` with remediation steps. Belt-and-suspenders behind D-13/D-14 — the upgrade path closes the gap, the boot-check prevents regressions.

### Spike / API verification

- **D-16 (wax_ 0.7 API spike shape):** Planner agent resolves `wax_ 0.7` API shape inline during Plan 19-01 authoring (Context7 + hexdocs fetch), embeds verified `Wax.register/3`, `Wax.authenticate/5`, `%Wax.Challenge{}` field list, and attestation enum values into the plan's `<interfaces>` block. Executor builds against a verified contract. **Plus** Plan 19-01 Task 1 includes a 10-line round-trip smoke assertion (`register → authenticate` against wax_ test vectors) to catch semantic surprises static signature checks miss. No standalone Plan 19-00 — matches Sigra's 11-01/13-01 convention of baking verified interfaces into PLAN.md at authoring time.

### Claude's Discretion

- Exact NimbleOptions schema shapes for `@register_opts_schema` / `@authenticate_opts_schema` — planner decides minimal fields per call site.
- Ordering of fields inside the `UserPasskey` migration (as long as indexes land on `user_id` + unique `credential_id`).
- Helper function visibility (`@doc false` vs internal-only aliases) inside `Sigra.Passkeys.Registration` / `Sigra.Passkeys.Authentication`.
- Test fixture shape — executor can reuse `Wax` test vectors from the wax_ repo or generate its own.
- Whether sign-count policy tests live in `test/sigra/passkeys_test.exs` or in a dedicated `test/sigra/passkeys/sign_count_policy_test.exs`.
- Whether the cap-per-user check inside `Repo.transact/2` uses `Repo.aggregate(:count)` or a `select count(*)` query (both work, planner picks the idiomatic one).

### Folded Todos

(None — `/gsd-tools todo match-phase 19` returned zero matches.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 19 internal (authoritative)
- `.planning/ROADMAP.md` §Phase 19 — goal, requirements (PK-01/PK-03/PK-04/PK-05/PK-07/PK-08), pitfalls addressed (P-4, P-6), success criteria.
- `.planning/REQUIREMENTS.md` — full PK-## requirement definitions (lines 83-107).
- `.planning/PROJECT.md` — v1.1 Foundations milestone scope, project invariants (hybrid lib+generator, blessed-path Phoenix/Ecto/Postgres, security-critical-in-lib).

### Research artifacts (read before planning)
- `.planning/research/PITFALLS.md` — Part 2 (Passkeys):
  - §P-1 (challenge replay / OneUptime CVE) — not Phase 19 but relevant context for `Sigra.Passkeys.Registration.new_challenge/2` signature (challenge is caller-owned)
  - §P-3 (RP ID rotation) — D-11 stores `rp_id` per PK-04
  - §P-4 (sign-count regression — false positives AND false negatives) — D-05 locks `:warn` default
  - §P-6 (StrongKey CVE-2025-26788 credential-confusion bypass) — D-07 is the defense
  - §P-7 (attestation default) — default `:none` (set in Phase 20 config loading, not Phase 19)
- `.planning/research/ARCHITECTURE.md` — Part B (Passkeys):
  - §B1 (challenge storage — Plug session, Phase 20)
  - §B3 (credentials schema + ceremony trace) — **NOTE:** line 249 says `aaguid :binary`, SUPERSEDED by D-01 (`:uuid`). Revise during Phase 19 execution.
  - §B4 (challenge plug placement — Phase 20)
  - §B5 (POST-auth controller — Phase 21)
- `.planning/research/STACK.md` — `wax_ ~> 0.7` dependency rationale. **NOTE:** line 39 "store raw 16-byte AAGUID", SUPERSEDED by D-01. Revise during Phase 19 execution.
- `.planning/research/FEATURES.md` — passkey feature flag surface.
- `.planning/research/SUMMARY.md` — spike flags (wax_ 0.7 verify — addressed by D-16).

### External specs / CVEs / community sources
- **W3C WebAuthn Level 2** — https://www.w3.org/TR/webauthn-2/
  - §6.1 (authenticator data format)
  - §6.5.2 (attested credential data)
  - §7.2 (verification of authentication assertion) — load-bearing for D-07
  - §5.8.4 (AuthenticatorTransport enum) + §6.3.2 step 22 (treat unknown transports as absent) — load-bearing for D-02
- **W3C WebAuthn Level 3 draft** — https://www.w3.org/TR/webauthn-3/ — transport enum additions (`hybrid` replacing `cable`, `smart-card`)
- **StrongKey CVE-2025-26788** — https://www.securing.pl/en/cve-2025-26788-passkey-authentication-bypass-in-strongkey-fido-server/ — the exact credential-confusion bug D-07 defends against
- **wax_ 0.7 hexdocs** — https://hexdocs.pm/wax_/ — API surface to verify during Plan 19-01 planner-inline spike (D-16); specifically `Wax.register/3`, `Wax.authenticate/5`, `%Wax.Challenge{}`, `Wax.AuthenticatorData.get_aaguid/1`, attestation options enum
- **wax_ GitHub** — https://github.com/tanguilp/wax — source of truth if hexdocs diverges
- **passkeydeveloper/passkey-authenticator-aaguids** — https://github.com/passkeydeveloper/passkey-authenticator-aaguids — community AAGUID→friendly-name registry, keyed by 36-char lowercase UUID strings. Load-bearing for D-01 (column type) and Phase 21's nickname defaults.
- **cloak_ecto 1.3 docs** — https://hexdocs.pm/cloak_ecto/readme.html — key rotation (`:retired` ciphers + `mix cloak.migrate.ecto`). Load-bearing for D-14 upgrade path.
- **SimpleWebAuthn `verifyAuthenticationResponse`** — https://simplewebauthn.dev/docs/packages/server#2b-verify-authentication-response — reference implementation for credential-confusion guard pattern (caller pre-resolves credential).
- **NimbleOptions docs** — https://hexdocs.pm/nimble_options/NimbleOptions.html — schema validation for D-05/D-06 per-call opts.

### Codebase pattern files (precedent to mirror)
- `lib/sigra/mfa/credential.ex` — library-struct ↔ host-schema pattern (D-04). **Closest analog — mirror this structure for `Sigra.Passkeys.Credential`.**
- `lib/sigra/mfa.ex` — `config.mfa` NimbleOptions pattern (D-05/D-06).
- `lib/sigra/oauth.ex` — `config.oauth` NimbleOptions pattern + `Sigra.Audit.log_multi_safe/3` usage (D-12). Line 498 for the config pattern.
- `lib/sigra/config.ex` — `%Sigra.Config{}` struct + NimbleOptions validation + `new!/1`. **Add `passkeys:` keyword slot here during Plan 19-02.**
- `lib/sigra/token.ex` — HMAC token signing (referenced by Phase 20, not Phase 19, but good for context).
- `lib/sigra/install/features/core.ex` — install feature emission pattern (lines 232-233 emit `encrypted.ex` stub — load-bearing for D-13 template feature-gating).
- `lib/sigra/install/injector.ex` — supervision tree injector (lines 381-392 already know how to inject `{MyApp.Vault, []}` — reuse for D-14).
- `priv/templates/sigra.install/core/encrypted.ex` — current stub (D-13 replaces this under feature gate).
- `priv/templates/sigra.gen.oauth/vault.ex` — existing real Cloak vault template (D-13 promotes this to core).
- `priv/templates/sigra.gen.oauth/encrypted_binary.ex` — existing real `Cloak.Ecto.Binary` (D-13 unifies namespace with core).
- `lib/mix/tasks/sigra.upgrade.ex` — upgrade task (D-14 adds a step here).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`%Sigra.Config{}` struct** (`lib/sigra/config.ex`) — already accepts per-feature keyword sub-lists (`mfa:`, `oauth:`, `password:`). Phase 19 adds `passkeys:` slot with NimbleOptions validation at `new!/1`.
- **`Sigra.MFA.Credential` library struct** (`lib/sigra/mfa/credential.ex`, 118 lines) — exact structural precedent for `Sigra.Passkeys.Credential`. Library struct mapping to/from generated host Ecto schema. Mirror field-by-field.
- **`Sigra.Audit.log_multi_safe/3`** — atomic audit-event insertion inside `Ecto.Multi`. Used by `Sigra.OAuth.create_session/4`. D-12 reuses for `register/3` and D-10's sign-count regression event.
- **Real Cloak vault templates** at `priv/templates/sigra.gen.oauth/{vault.ex,encrypted_binary.ex}` — D-13 promotes these into `priv/templates/sigra.install/core/` under a feature gate.
- **Vault supervision-tree injector** (`lib/sigra/install/injector.ex:381-392`) — D-14 reuses this exact code path for the feature-gated vault emission.
- **`mix sigra.upgrade` task scaffolding** (`lib/mix/tasks/sigra.upgrade.ex`) + Phase 25's new `next_migration_timestamp/2` scan-and-bump generator — D-14 adds a vault-promotion migration step using this.
- **`NimbleOptions` throughout Sigra** — every context function already takes `opts` and validates against a module attribute schema. D-05/D-06 follow this exact convention.

### Established Patterns
- **Hybrid lib+generator:** Library owns security-critical code (context functions, crypto, token signing). Host app owns data shape (schemas, LiveViews, routes). Generated schemas reference library behaviours. Phase 19 sticks to this rigidly.
- **`config` as first argument:** Every public context function takes `%Sigra.Config{}` as its first arg. No hidden global state. No `Application.get_env` in the hot path.
- **`Repo.transact/2` (Ecto 3.13+) for atomic invariants:** Used in Phase 15 (audit), Phase 13 (organizations). D-06/D-12 follow the pattern.
- **`<app_module>.Encrypted.Binary` namespace for encrypted fields** — already established by the OAuth generator. D-13 unifies everything under this single namespace (retires the legacy `<context_module>.Encrypted.Binary`).
- **Audit event payloads as JSONB:** Never denormalized onto schema rows. D-10 follows this.
- **Feature-gated templates:** Phase 11's Feature behaviour (`lib/sigra/install/features/core.ex`) already gates template emission by opt-in. D-13 extends this to the vault under `--passkeys | --mfa | --oauth`.

### Integration Points
- **`Sigra.Config.new!/1`** — add `passkeys:` NimbleOptions schema slot (D-05/D-06).
- **`Sigra.Passkeys` new module at `lib/sigra/passkeys.ex`** — context functions (D-08).
- **`Sigra.Passkeys.Credential` new struct at `lib/sigra/passkeys/credential.ex`** — mirror of `Sigra.MFA.Credential`.
- **`Sigra.Passkeys.Registration` / `Sigra.Passkeys.Authentication`** — ceremony primitives wrapping `wax_`.
- **Generated host `UserPasskey` schema template** at `priv/templates/sigra.install/passkeys/user_passkey.ex` (new feature subdirectory — Phase 11's feature system pattern).
- **Generated host migration template** at `priv/templates/sigra.install/passkeys/create_user_passkeys.exs` (uses Phase 25's `next_migration_timestamp/2`).
- **`Sigra.Install.Features.Passkeys`** new feature module at `lib/sigra/install/features/passkeys.ex` — mirrors `Sigra.Install.Features.Organizations` from Phase 13.
- **Vault template promotion** at `priv/templates/sigra.install/core/vault.ex` + `encrypted_binary.ex` (D-13).

</code_context>

<specifics>
## Specific Ideas

- **Mirror `lib/sigra/mfa/credential.ex` exactly** for `Sigra.Passkeys.Credential` struct shape — same docstring pattern, same `from_schema/1` convention, same field naming style.
- **Planner-inline spike (D-16)**: planner agent MUST run Context7 against `wax_ 0.7` during Plan 19-01 authoring and embed the resolved API into the `<interfaces>` XML block. Not optional.
- **Revise `ARCHITECTURE.md:249` and `STACK.md:39`** during Phase 19 execution — both currently say `aaguid :binary`. This is a documented supersession under D-01, not drift. Update in the same commit as the schema template lands.
- **`Sigra.Passkeys.Registration.new_challenge/2` and `verify/4` must be Plug.Conn-free** — they accept challenge as an explicit argument so Phase 19 tests run without Plug. Phase 20's `Sigra.Plug.PasskeyChallenge` is the caller that owns session storage.
- **Audit event payload is JSONB everywhere** — never denormalize onto `user_passkeys` for Phase 21 banner lookup. Phase 21 queries the audit table by `credential_id`.
- **Sign-count regression test per mode**: `test/sigra/passkeys/sign_count_policy_test.exs` (or inline) must have one regression scenario for each of `:warn`, `:require_reauth`, `:revoke` — all three modes are load-bearing per PK-08.
- **Phase 19 plan shape**: decomposes into 4 plans, not 2 — the vault promotion (D-13/D-14/D-15) is big enough to deserve its own plan (Plan 19-04) without splitting off into Phase 19.1:
  - **Plan 19-01**: schema + migration + wax_ smoke test
  - **Plan 19-02**: `Sigra.Passkeys` context (register/authenticate/list/rename/delete/count) + `%Sigra.Config{}` passkeys slot + cap enforcement + StrongKey guard
  - **Plan 19-03**: sign-count policy branch handling + regression test per mode + audit event payload shape
  - **Plan 19-04**: Cloak vault promotion + unification + boot-check + `mix sigra.upgrade` hook + `guides/encryption.md`

</specifics>

<deferred>
## Deferred Ideas

- **Discoverable / usernameless / Conditional UI flow** → Phase 21 adds `Sigra.Passkeys.authenticate_discoverable/2` as a sibling function. Not Phase 19 scope (PK-UX-08).
- **Rate limiter per-user passkey ceremony** → Phase 20, PK-10.
- **Runtime config loading (`rp_id`, `rp_name`, `origin`, `attestation`, `user_verification`, `timeout_ms`)** → Phase 20, PK-09. Phase 19 reads these from `config.passkeys` but doesn't own the full config loading lifecycle.
- **Email notification on registration** → Phase 21, PK-UX-02 (reuses Phase 4 suspicious-login email shape).
- **Sudo gating on enrollment** → Phase 21, PK-UX-01.
- **`:attestation` enum + default** → Phase 20 owns the config loading; Phase 19 doesn't hardcode.
- **Webhook / Oban-async notification flows** → Phase 21.
- **Usernameless-primary login (passkey-as-primary without email)** → Phase 21+, PK-UX-06 (already flagged as opt-in behind `:passkey_primary_enabled`).
- **Strict transport enum** → (deferred permanently). WebAuthn spec instructs RPs to ignore unknown transports — D-02 follows the spec.
- **Standalone Plan 19-00 spike plan** → rejected in favor of D-16 (planner-inline + Task-1 smoke test). Matches Sigra's 11-01/13-01 convention.
- **Phase 19.1 split for vault promotion** → rejected. Keeping D-13/D-14/D-15 in Phase 19 as Plan 19-04. Rationale: shipping passkeys with plaintext `public_key` is strictly worse than any scope cost of unification; phase goal literally requires `Sigra.Vault` to exist in core.

### Reviewed Todos (not folded)
None — `/gsd-tools todo match-phase 19` returned zero matches.

</deferred>

---

*Phase: 19-passkey-schema-contexts*
*Context gathered: 2026-04-15*
