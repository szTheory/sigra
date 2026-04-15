# Phase 19: Passkey Schema + Contexts — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `19-CONTEXT.md` — this log preserves the alternatives considered
> and the research that informed each pick.

**Date:** 2026-04-15
**Phase:** 19-passkey-schema-contexts
**Mode:** Deep-research discuss (7 parallel subagents, one per gray area)
**Areas discussed:** aaguid column type, sign-count policy API shape, credential-confusion enforcement, passkey-per-user cap enforcement, encrypted vault posture, transports column typing, wax_ 0.7 spike plan shape

---

## Locked decisions carried forward (not re-discussed)

- **Sign-count default = `:warn`** — PK-08 spec, matches Apple iCloud Keychain / Google sync credentials.
- **`public_key` encrypted via Cloak vault pipeline, no new crypto infra** — phase goal.
- **`credential_id` stored plaintext (indexed for lookup), `rp_id` stored at registration** — PK-03, PK-04.
- **Hybrid lib+generator architecture** — project invariant.
- **Library struct ↔ host schema pattern** — mirrors `lib/sigra/mfa/credential.ex`.

---

## 1. `aaguid` column type

| Option | Description | Selected |
|--------|-------------|----------|
| `:binary` | Raw 16 bytes, matches wax_ return shape; zero conversion; matches ARCHITECTURE.md:249 as originally drafted | |
| `Ecto.UUID` | Postgres `uuid` column; canonical 36-char lowercase string form; human-readable in psql; matches community AAGUID registry key format | ✓ |
| `:string` | Free-form text, lowest constraint; wastes bytes | |

**User's choice:** `Ecto.UUID` (D-01). Nullable for FIDO-U2F authenticators.

**Research notes:**
- Verified `Wax.AuthenticatorData.get_aaguid/1` returns `binary() | nil` (raw 16 bytes, nil for all-zero U2F AAGUID). Source: `wax_` GitHub `lib/wax/attested_credential_data.ex` + `lib/wax/authenticator_data.ex` on 0.7.0.
- `passkeydeveloper/passkey-authenticator-aaguids` registry keys by 36-char lowercase UUID strings — e.g. `"08987058-cadc-4b81-b6e1-30de50dcbe96": {"name": "Windows Hello"}`. This is the load-bearing downstream consumer for Phase 21's nickname defaults.
- Cross-ecosystem: SimpleWebAuthn, webauthn4j, Hanko, py_webauthn all normalize to UUID-string at the boundary. Nobody stores raw bytes.
- `Ecto.UUID.cast/1` accepts both raw 16-byte binary AND 36-char string input → one-line cast at registration time.
- Side-effect: **supersedes `.planning/research/ARCHITECTURE.md:249` and `STACK.md:39`** which currently specify `:binary`. Revise during Phase 19 execution (noted in D-01 specifics).

---

## 2. Sign-count policy API shape

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Global `Application` config | `config :sigra, :passkeys, sign_count_policy: :warn`. Read via `Sigra.Passkeys.config/0` | |
| (b) Per-call NimbleOptions only | Every `authenticate/3` call passes `sign_count_policy: ...`. Zero global state, maximum flexibility | |
| (c) Per-user-record preference | Stored on users table or user_passkey row | |
| (d) `%Sigra.Config{}` default + per-call NimbleOptions override | Hybrid: lib-level default under `config.passkeys[:sign_count_policy]`, per-call escalation at high-value endpoints | ✓ |

**User's choice:** (d) (D-05). `%Sigra.Config{}` default under `config.passkeys`, per-call override via `NimbleOptions`.

**Research notes:**
- Community convention in Dashbit-adjacent libs (`nimble_pool`, `nimble_options`, `req`, `oban`, `ecto`): struct-based config validated once + per-call keyword opts merged against a per-function schema. Configure defaults once, override at call site, never mutate Application env.
- Cross-ecosystem passkey libs:
  - SimpleWebAuthn, py_webauthn, fido2-net-lib: per-call options
  - webauthn4j: instance-level pluggable `MaliciousCounterValueHandler`
  - Hanko/Clerk: tenant-level config
- Sigra's existing convention: `%Sigra.Config{}` struct carries `mfa:`, `oauth:`, `password:` keyword lists. Every context function already receives `config` as its first arg (`lib/sigra/config.ex`, `lib/sigra/mfa.ex:118-636`, `lib/sigra/oauth.ex:498`).
- Testability: tests build a literal `%Sigra.Config{}` — no `Application.put_env` cleanup pollution.
- Audit event payload `%{credential_id, previous_count, presented_count, policy_applied, delta, rp_id}` stored as JSONB in audit_events, NOT denormalized onto `user_passkeys`.

---

## 3. Credential-confusion enforcement (StrongKey CVE-2025-26788 defense, PK-07)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Username-first only in Phase 19 | Pre-lookup by `{user_id, credential_id}` before calling wax_. Discoverable flow deferred to Phase 21 as a sibling function | ✓ |
| (b) Dual-mode single function | `authenticate/3` dispatches on opts — both username-first and usernameless behind one entry point | |
| (c) Split functions from day 1 | `authenticate_user/3` + `authenticate_discoverable/2` — both ship in Phase 19 | |

**User's choice:** (a) (D-07). Phase 21 will add `authenticate_discoverable/2` as a sibling function.

**Research notes:**
- **W3C WebAuthn §7.2 step 5-6**: Username-first requires `credentialId ∈ allowCredentials(user)` AND (if `userHandle` present) `userHandle == user.id`. Usernameless requires `userHandle` present, then look up credential, then verify ownership. Both paths invariant: `(credential_id, user_handle)` resolves to exactly one credential owned by exactly one user.
- **StrongKey CVE-2025-26788**: server accepted assertion where `credentialId` belonged to user A but ceremony was initiated for user B → signature verified against A's key but session created as B. Exact pattern `wax_` does NOT guard against.
- **`wax_ 0.7` shape**: `Wax.authenticate/5` takes an allow-list map of `%{credential_id => {cose_key, sign_count}}` and verifies signature against it. Does NOT enforce user ownership of the allow-list — caller's job. This is the StrongKey attack surface.
- **Other libraries**: SimpleWebAuthn, py_webauthn, webauthn4j all require the caller to pre-resolve the credential. None auto-enforce ownership.
- **PK-07 literal reading**: "verifies the returned `credential_id` matches a credential the **requested** user owns" → presupposes username-first. Option (a) is the only literal compliance.
- **Phase 21 forward-compat**: adding `authenticate_discoverable/2` as a new function is a zero-breaking-change addition. No flag overloading, no arity sprawl.

---

## 4. Passkey-per-user cap enforcement (PK-UX-04, soft cap of 10)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Library enforces | `register/3` checks `count_for_user(user) >= cap` inside `Repo.transact/2`, returns `{:error, :passkey_cap_reached, ...}` | |
| (b) LiveView enforces | Phase 21 LiveView pre-checks count; library blindly inserts | |
| (c) Both | Library is the hard guarantee; LiveView mirrors for UX (disables button at cap) | ✓ |

**User's choice:** (c) (D-06). Library is the gatekeeper; Phase 21 LiveView uses `count_for_user/1` for UX only.

**Research notes:**
- **Cross-ecosystem pattern**: WebAuthn libraries universally enforce credential caps server-side.
  - SimpleWebAuthn docs explicitly recommend RP-layer rejection (not UI)
  - Hanko: `webauthn.limits.max_credentials_per_user` enforced in core API
  - Auth0 (cap=10), Okta, Keycloak: capped at identity-provider level
- **Elixir precedent**:
  - `guardian_db`: `max_sessions_per_subject` enforced inside `Guardian.DB.Token.create/2`
  - `pow`: invitation limits sit in the context module
- **TOCTOU concern**: count-then-insert outside a transaction races. `Repo.transact/2` closes the window.
- **Misuse resistance**: Non-LiveView callers (Oban workers, custom controllers, iex) get DoS protection for free. If only LiveView enforced, one forgotten check = 10k rows possible.
- **Phase 19/Phase 21 boundary**: library as gatekeeper = security invariant owner. LiveView's `count_for_user/1` call is for button-disable UX, never for the gate.

---

## 5. Encrypted vault posture

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Keep stub + document louder | Ship passthrough stub, beef up docstrings, add `guides/passkeys.md` warning | |
| (b) Real vault default for all installs | Every fresh install emits real `Cloak.Vault` + `Encrypted.Binary`, requires `CLOAK_KEY` env | |
| (c) CI / boot smoke gate only | Keep stub but loud warnings if passkeys + stub both active | |
| (d) Feature-gated real vault + boot-check belt | Emit real vault when any of `--passkeys`/`--mfa`/`--oauth` is set; boot-check raises if stub + passkeys both active | ✓ |

**User's choice:** (d) (D-13/D-14/D-15). Keep in Phase 19 as Plan 19-04 (user also confirmed preference to keep in-phase rather than split to Phase 19.1).

**Research notes (with verified filesystem state):**
- **Current state (verified)**:
  - `priv/templates/sigra.install/core/encrypted.ex` is a **passthrough stub** under `<context_module>.Encrypted.Binary`. Docstring: "PASSTHROUGH STUB — REPLACE IN PRODUCTION... stores values in plaintext... do not ship this stub to production."
  - `priv/templates/sigra.gen.oauth/vault.ex` is a real `use Cloak.Vault` with AES-256-GCM under `<app_module>.Vault`
  - `priv/templates/sigra.gen.oauth/encrypted_binary.ex` is `use Cloak.Ecto.Binary, vault: <app_module>.Vault` — under different module namespace than the core stub
  - Stub is referenced by core `user_mfa_credential.ex`
  - Install generator emits it unconditionally at `lib/sigra/install/features/core.ex:232-233`
  - `mix sigra.upgrade` exists — can extend with D-14 step
  - Injector already knows how to add `{MyApp.Vault, []}` to supervision tree (`lib/sigra/install/injector.ex:381-392`) — wiring exists from OAuth path
- **Namespace unification bonus**: D-13 resolves latent bug where core emits `<context_module>.Encrypted.Binary` but OAuth emits `<app_module>.Encrypted.Binary`. Unify on `<app_module>.Encrypted.Binary`.
- **Cross-ecosystem comparison**:
  - `phx.gen.auth`, Pow, Guardian: no at-rest encryption layer — tokens are hashed, not encrypted. No "stub" concept.
  - `cloak_ecto` idiom in the wild: always-real from day one; `CLOAK_KEY` in `runtime.exs`. No established "dev stub" pattern — it's considered an anti-pattern.
  - Auth0/Clerk: fully hosted, KMS-managed, not the host's problem.
- **Phase goal interpretation**: "no new encryption infra" is literally true under option (d) — the real vault already exists at `priv/templates/sigra.gen.oauth/`, we're **promoting** it, not inventing. The fiction was claiming Sigra had a Cloak pipeline when the default install emitted a stub.
- **Upgrade contract**: v1.0 hosts with neither MFA nor OAuth (minimal install) remain non-breaking. v1.0 hosts enabling passkeys in v1.1 get a `mix sigra.upgrade` step that generates the vault. v1.0 hosts with existing OAuth rows already have the real vault (zero re-encryption).
- **User confirmed preference**: keep D-13/D-14/D-15 in Phase 19 as Plan 19-04 (vs splitting into Phase 19.1). Rationale: shipping passkeys with plaintext `public_key` is strictly worse than the scope cost of unification; phase goal requires `Sigra.Vault` to exist in core anyway.

---

## 6. `transports` column typing

| Option | Description | Selected |
|--------|-------------|----------|
| (a) `{:array, :string}` free-form | No changeset validation; store whatever wax_/browser returns | ✓ |
| (b) `{:array, :string}` + `validate_subset` allow-list | Sigra-owned hardcoded enum, reject unknown | |
| (c) `{:array, Ecto.Enum}` | DB-level strict enum, cast-time rejection | |
| (d) Custom Ecto type with soft-validate + log | Forward-compat with warning logs for unknowns | |

**User's choice:** (a) (D-02). Plus `Sigra.Passkeys.known_transport?/1` helper exposed for telemetry only.

**Research notes:**
- **WebAuthn L2 §5.8.4**: transport enum = `usb`, `nfc`, `ble`, `internal`
- **WebAuthn L3 draft**: adds `hybrid` (replaces earlier `cable`), `smart-card`. Enum has changed across spec revisions.
- **W3C WebAuthn §6.3.2 step 22**: RPs MUST *"treat unknown transport values as if the member were absent"* — ignore, don't reject. This explicitly spec-mandates permissive behavior.
- **`wax_ 0.7` behavior**: does not parse transports from authenticator data itself. Transports come from JS `PublicKeyCredential.response.getTransports()` as an array of strings. wax_ does NOT enforce the enum.
- **Failure mode analysis**: Option (c) (strict enum) → the day Chrome ships a new transport, every new passkey enrollment 500s until Sigra cuts a release. Real-world risk. Options (b) + (d) have the same class of problem at different severity levels.
- **Security analysis**: Transports are a client-side hint for the platform's authenticator picker UI. A bogus value cannot escalate privilege — it just means a slightly worse UX prompt. Not a security boundary.
- **Cross-ecosystem**: SimpleWebAuthn, webauthn4j, py_webauthn all store whatever the authenticator returned. None strict-validate.
- **Conclusion**: The simplest thing that works is correct. Expose `known_transport?/1` for host apps that want telemetry metrics on unknown transports, but never use it in validation.

---

## 7. wax_ 0.7 API verification spike plan shape

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Standalone Plan 19-00: spike | 2-task plan: Context7 query → wax_ API notes doc + smoke test. Gates all later plans | |
| (b) Spike as Task 1 of Plan 19-01 (schema) | Inline as first task of schema plan | (partial) |
| (c) Skip the spike, code against assumed shape | Rely on Rule 1 executor deviations if wax_ differs | |
| (d) Planner resolves inline during PLAN.md authoring | Planner agent runs Context7 while writing Plan 19-01, embeds verified API in `<interfaces>` block | ✓ |

**User's choice:** (d) + micro-safety from (b) (D-16). Planner resolves API inline during Plan 19-01 authoring; Task 1 of Plan 19-01 includes a 10-line round-trip smoke assertion.

**Research notes:**
- **Sigra's existing convention (verified)**: Plans 11-01 and 13-01 bake verified external interfaces into the `<interfaces>` XML block at plan-write time — Ecto migration DSL, Feature behaviour callbacks, `String.myers_difference/2` signatures — rather than running standalone spikes.
  - `.planning/phases/11-generator-feature-system/11-01-PLAN.md`
  - `.planning/phases/13-organizations-schemas-context/13-01-PLAN.md`
  - `.planning/phases/13-organizations-schemas-context/13-RESEARCH.md` (no upfront-spike pattern found)
- **Standalone 19-00 precedent**: reserved in Sigra history for artifacts that become regression barriers for later commits (Plan 11-01's golden-diff harness). The wax_ API check is a one-time verification, not a regression barrier — doesn't fit that shape.
- **Blast radius analysis**: If wax_ 0.7 diverges from ARCHITECTURE.md assumption, concretely breaks:
  1. Schema column types (aaguid, credential_id encoding, public_key blob vs COSE map)
  2. Function arity / return shape (register/3 vs /4, authenticate/5 vs /6, tuple order)
  3. `%Wax.Challenge{}` field names
  4. Attestation options enum naming
  - Rework is localized to Plan 19-01 + 19-02, roughly 2-3 files per plan. Not catastrophic.
- **Wave parallelization cost**: Plan 19-02 depends on schema existing anyway, so serializing 19-01 first is not a cost.
- **Why (d) + (b) hedge wins**: Static signature check (planner inline) catches arity/field-name surprises. Round-trip smoke test (Task 1) catches semantic surprises — behavior wax_ exposes at runtime that the signature doesn't reveal. Combined coverage at near-zero ceremony cost.

---

## Claude's Discretion

Explicit "planner decides" items captured in `19-CONTEXT.md` §Decisions > Claude's Discretion:
- Exact NimbleOptions schemas for `@register_opts_schema` / `@authenticate_opts_schema`
- Ordering of migration fields (constraints: `user_id` indexed, `credential_id` unique)
- Helper function visibility
- Test fixture shape
- Sign-count policy test file location
- Count query style (Repo.aggregate vs manual select)

---

## Deferred Ideas

All captured in `19-CONTEXT.md` §Deferred. Notable:
- Discoverable flow → Phase 21 sibling function `authenticate_discoverable/2`
- Rate limiter → Phase 20, PK-10
- Runtime config loading → Phase 20, PK-09
- Email notification → Phase 21, PK-UX-02
- Sudo gating → Phase 21, PK-UX-01
- Strict transport enum → rejected permanently (spec-mandated permissive)
- Standalone Plan 19-00 → rejected in favor of D-16
- Phase 19.1 vault-promotion split → rejected; kept as Plan 19-04

---

*End of discussion log. See `19-CONTEXT.md` for the locked decision set fed to planning and research agents.*
