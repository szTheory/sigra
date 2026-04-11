# Stack Research — Sigra v1.1 Foundations (Organizations + Passkeys)

**Scope:** Incremental additions to the shipped v1.0 stack. Nothing in v1.0 needs to change.
**Researched:** 2026-04-11
**Overall confidence:** HIGH (primary claims verified on hex.pm / upstream repos; LOW/MEDIUM flags called out inline)

---

## TL;DR — What to add, what to skip

| Concern | Recommendation | Confidence |
|---|---|---|
| WebAuthn server | Add `{:wax_, "~> 0.7"}` (v0.7.0, May 18 2025) | HIGH |
| WebAuthn browser JS | Ship `@simplewebauthn/browser ~> 13` via LiveView hook (esbuild-bundled). Do NOT hand-roll. | HIGH |
| Multi-tenancy library | **None.** Build logical MT directly on Ecto with `org_id` FK + `Scope` struct. Confirmed as the current community consensus for row-level MT. | HIGH |
| Passkey public-key encryption | Reuse existing `cloak_ecto` vault via `Cloak.Ecto.Binary` on a `:binary` column. One real gotcha (below). | HIGH |
| Conditional generator templates | No library. Follow the `phx.gen.auth` + Ash `Igniter`-style pattern (EEx templates + opt-out flags). Do NOT pull in Igniter as a dep. | MEDIUM |
| Optional: `Igniter` for installer | **Skip for v1.1.** Noted as a watch item only. | LOW |

**No breaking changes to any v1.0 dependency.** All additions are additive and pair with the existing Ecto ~> 3.13 / Phoenix ~> 1.8 / cloak_ecto 1.3 surface.

---

## 1. WebAuthn / Passkeys — server library

### Recommendation: `{:wax_, "~> 0.7"}`

- **Current version:** v0.7.0, released **2025-05-18** on hex.pm. Apache-2.0, maintained by `tanguilp`.
- **Package name gotcha:** hex package and application name is `:wax_` (trailing underscore). Dep line: `{:wax_, "~> 0.7"}`; module namespace is `Wax`.
- **Elixir/OTP compatibility:** `elixir: "~> 1.12"`, no OTP floor. Runtime deps `:inets`, `:logger`, `cbor ~> 1.0`, `jason ~> 1.1`, `x509 ~> 0.8`. All compile cleanly on OTP 27 / Elixir 1.18.
- **Feature coverage:** Attestation (`none`, `packed`, `tpm`, `android-key`, `android-safetynet`, `fido-u2f`, `apple`), assertion, credential-storage callbacks. Passes the 170-case FIDO2 official test suite. Supports Ed25519, ES256, RS256, PS256 — covers every current passkey provider.
- **Why still the right call in 2026:** No new server-side WebAuthn library has emerged since v1.0 research. Alternatives `web_authn_ex` (low activity, incomplete) and `webauthn_components` 0.8.0 (wrong layer — LiveComponent UX bundle, not server primitive) remain unsuitable.

### Attention points for v1.1

- **Challenge storage:** `Wax` returns a challenge struct Sigra must persist for the duration of the ceremony. Options: ETS, DB row, signed cookie. Recommend **Plug session** (see ARCHITECTURE.md B1) — signed+encrypted, short TTL, multi-node safe.
- **RP ID runtime-configurable:** cannot be a full URL — only effective domain. Add `Sigra.Config` keys `:rp_id`, `:rp_name`, `:origins` (list), `:attestation` (`:none` default).
- **Sign counter handling:** Wax returns new sign count; Sigra must persist and enforce monotonicity. A decrease = cloned authenticator → revoke credential + audit `:passkey_clone_suspected`. Build into `Sigra.Passkeys.Authentication` from day one.
- **`aaguid` metadata:** store raw 16-byte AAGUID from registration. Do NOT map to provider names in v1.1 (defer FIDO MDS integration).

---

## 2. Passkey public-key encryption — reuse `cloak_ecto`

### Recommendation: Reuse existing v1.0 vault via `Cloak.Ecto.Binary` on a `:binary` column

- **`cloak_ecto` 1.3.0** (Apr 6 2024) is current. Slow-moving but stable.
- **Binary field type:** `Cloak.Ecto.Binary` is purpose-built. DB column type **must be `:binary`** (PostgreSQL `bytea`). Schema field uses host app's existing vault module (the generator detects it — reuses v1.0's OAuth token vault).

### Real gotchas

1. **Encrypted columns NOT queryable.** Random IV per write. Can't `WHERE public_key = ?`. Fine for passkeys — server looks up by `credential_id`, which MUST remain unencrypted and indexed. **Migration checklist:** `credential_id` = `:binary` unencrypted + unique index. `public_key` = `:binary` encrypted.
2. **Cannot use per-user keys.** Cloak's Ecto type is module-level → vault is application-wide. Correct model for WebAuthn public keys (they aren't secrets anyway).
3. **Public keys don't strictly need encryption.** WebAuthn public keys are by definition public. Sigra encrypts anyway for (a) v1.0 precedent consistency, (b) uniform key-rotation surface, (c) defense-in-depth against log/backup leakage. **Document in PITFALLS** that this is belt-and-suspenders, not a security requirement.
4. **Key rotation works for bytea.** `mix cloak.migrate.ecto` streams rows and re-encrypts — identical behavior for `:binary` fields.

**Bottom line:** zero new dep, zero v1.0 breakage, proven pattern.

---

## 3. Multi-tenancy — no new library

### Recommendation: **Do NOT add a multi-tenancy library.** Build `org_id` FK + `Scope` struct extension directly on Ecto.

Ecosystem survey:

| Library | Status | Fit for Sigra |
|---|---|---|
| **Triplex** | PostgreSQL schema-per-tenant. Last meaningful release 2023. | Wrong model — rejected by PROJECT.md constraint. |
| **Tenantex / apartmentex** | Schema/DB-per-tenant. Abandoned since 2019. | Wrong model + dead. |
| **Ash Framework multi-tenancy** | Attribute-based in Ash resources. | Wrong ecosystem. Coupling cost >> benefit. |
| **Ecto `prefix:` option** | Built-in, schema-per-tenant. | Wrong model. |
| **Manual `org_id` FK** | No library — Ecto + query helpers. | **Correct.** |

**What "logical MT via `org_id` FK" needs, none library-shaped:**

1. Schema design — `organizations`, `organization_memberships`, `organization_invitations`. Pure Ecto.
2. Query scoping — `Sigra.Organizations.Query.for_org(query, scope)` helper + discipline. **Explicit > implicit.**
3. Scope struct extension — `:active_organization`, `:membership` fields. Zero-dep.
4. `fetch_current_scope` plug update — read `active_organization_id` from session, load org + membership. ~30 lines.
5. `Sigra.Plug.RequireMembership` — ~20 lines.
6. Audit metadata auto-attachment — one field, no new dep.
7. Invite token flow — reuses v1.0's `Sigra.Token` HMAC helper.

**Confirmed:** matches 2026 community consensus (Filip Pauco Medium Mar 2026, Alembic blog, Curiosum guide).

### Guardrails for PITFALLS.md

- **N+1 tenant leaks:** enforce via (a) query helper convention, (b) Credo custom check (~30 lines) warning on `Repo.` calls in tenant-scoped contexts without `for_org/2`, (c) integration tests asserting cross-tenant isolation.
- **Last-owner guard:** `Sigra.Organizations.remove_member/2` must check `count(owners) > 1` in the same Multi transaction as the delete.
- **Stale `active_organization_id`:** user removed from currently-active org → next request must reset scope, not 500. Handle in `fetch_current_scope`.
- **Backfill migration ordering:** "personal orgs" migration must run before any code reads `scope.active_organization`.

---

## 4. Conditional generator templates — no library

### Recommendation: Hand-roll EEx with opt-out flags. Watch Igniter; do not adopt for v1.1.

1. **`phx.gen.auth` pattern (1.8):** `Mix.Phoenix.Schema` + `eex_render/2` + opt-out flags (`--no-live`, `--binary-id`). No runtime dep — compile-time `Mix.Task` machinery. **Closest analogue for Sigra's `--no-organizations` / `--no-passkeys`.**
2. **`Igniter` (ash-project):** semantic-code-patching library with Elixir AST awareness. Would genuinely make cross-file installer patching safer. **BUT:** (a) load-bearing generator dep = philosophical shift, (b) Sigra v1.0 already ships a working installer with string-injection patches, (c) adopting mid-milestone is scope creep. **Decision: skip for v1.1, flag for v2.0 installer overhaul.**
3. **Ash's generator conventions worth stealing (pattern only):** task opts → struct → template dispatch → post-generate patches → summary output showing created/modified/skipped. v1.1 should add the "skipped" line when `--no-organizations` is passed.

### Pattern for conditional templates

**Load-bearing because v1.2 needs the same pattern for `--no-admin`.** See ARCHITECTURE.md C1 for full design — recommends subdirectory convention + small feature manifest module per feature (`Sigra.Install.Features.Organizations`, etc.) implementing a shared behaviour.

**No new dep.** `nimble_options` (already in v1.0) covers flag parsing/docs.

---

## 5. JS hooks for WebAuthn ceremonies

### Recommendation: Bundle `@simplewebauthn/browser ~> 13`. Do NOT hand-roll.

| Dimension | SimpleWebAuthn/browser | Vanilla ~30 lines |
|---|---|---|
| Raw code | ~5 lines (`startRegistration()` / `startAuthentication()`) | ~30-60 lines |
| Error handling | Named error codes, passkey-aware | You write these; miss edge cases |
| Base64url encoding | Handled | You debug off-by-one bugs |
| Browser compat | Handled (conditional mediation, transports, hints) | Safari-vs-Chrome quirks yourself |
| Size | ~8 KB minified | 0 KB, higher maintenance |
| Maintenance | Active (MasterKale), TS-first | Sigra owns bug reports |

The "~30 lines vanilla JS" estimate is misleading — it becomes 100+ lines with base64url encoding both ways, `PublicKeyCredential.toJSON()` fallback, conditional mediation, error translation. SimpleWebAuthn exists specifically because everyone hand-rolling 30 lines ends up rewriting them.

### Integration approach

1. Add `@simplewebauthn/browser` to **generator template** `assets/package.json`, not library mix.exs.
2. `passkey_hooks.js` exports two LiveView hooks: `PasskeyRegistration`, `PasskeyAuthentication`.
3. Each listens for `phx:passkey:start-*` with Wax-generated options, calls `startRegistration()` / `startAuthentication()`, pushes `passkey:response` back.
4. LiveView receives and calls `Sigra.Passkeys.Registration.verify/2` → `Wax.register/2`.
5. Server-side `Sigra.Passkeys.WaxJson` bridges Wax (raw WebAuthn bytes) ↔ SimpleWebAuthn (base64url strings). ~40 lines — the **one real integration cost**.

**Version to pin:** `^13.0.0` in generator template.

**Alternative fallback:** hand-roll base64url plumbing inline, skip SimpleWebAuthn. Estimated +2 days + ongoing bug maintenance. Not recommended but viable if integration sideways.

---

## Integration map with existing v1.0 stack

| v1.0 component | v1.1 reuse |
|---|---|
| `Sigra.Scope` struct | Extended with `:active_organization`, `:membership`. No break if new fields default `nil`. |
| `Sigra.Token` HMAC helper | New context: `:organization_invite`. Zero code change. |
| `Sigra.Audit` | `log/3` enriched with `organization_id` from scope. Additive. |
| `cloak_ecto` vault | Reused for `UserPasskey.public_key`. No new vault. |
| `fetch_current_scope` plug | Extended to load active org — one extra query, gated on `current_user` being present. |
| `Hammer` | New rate limit key: `"passkey_ceremony:#{user_id}"` (5/min) to prevent flood DoS. |
| `Oban` | Optional `Sigra.Workers.PasskeyChallengeCleanup` worker. Inline fallback if Oban absent. |
| `NimbleOptions` | New config groups: `:organizations`, `:passkeys` (rp_id, rp_name, origins, attestation, challenge_ttl). |
| `mix sigra.install` | Extended with `--no-organizations` / `--no-passkeys` flags + conditional template dispatch. First load-bearing use. |

**No v1.0 dependency needs to be bumped for v1.1.** `wax_ ~> 0.7` is the only mix.exs addition.

---

## What NOT to add

| Avoid | Why |
|---|---|
| `webauthn_components` | Wrong layer — LiveComponent UX bundle. Sigra needs the server primitive to drive its own LiveViews. |
| `Triplex` / `Tenantex` / `apartmentex` | Schema-per-tenant. Rejected by PROJECT.md. Also abandoned. |
| `Ash` / `Ash.Multitenancy` | Wrong framework ecosystem. Coupling cost >> benefit. |
| `Igniter` | Tempting for installer quality; scope creep for v1.1. Revisit in v2.0. |
| Custom WebAuthn reimplementation | FIDO2 spec is a minefield. `wax_` passes the official test suite; rolling our own is strictly worse. |
| Vanilla JS for navigator.credentials | Underestimates base64url + error surface. |
| Separate vault for passkeys | Two keys, two rotations, two env vars. Reuse OAuth vault. |

---

## Version compatibility matrix (additions only)

| Package | Version | Compatible with | Notes |
|---|---|---|---|
| wax_ | ~> 0.7 (0.7.0, May 2025) | Elixir ~> 1.12, OTP 22+ | Runtime deps clean on OTP 27 |
| @simplewebauthn/browser | ^13.0.0 | Modern evergreen browsers | Generator-only, not mix.exs |
| cloak_ecto | ~> 1.3 (already installed) | Ecto ~> 3.0 | Binary field via `Cloak.Ecto.Binary` |

---

## Confidence Assessment

| Area | Level | Reason |
|---|---|---|
| `wax_` version + compat | HIGH | hex.pm verified, mix.exs verified on GH |
| Multi-tenancy: no lib needed | HIGH | Ecosystem survey confirms row-level MT is hand-rolled |
| `cloak_ecto` binary pattern | HIGH | Source verified, semantics confirmed |
| SimpleWebAuthn for browser | HIGH | Official docs + Phoenix+SimpleWebAuthn blog precedent |
| Igniter non-adoption | MEDIUM | Right for v1.1; long-term depends on installer trajectory |
| Wax↔SimpleWebAuthn JSON bridging | MEDIUM | 40-line estimate not verified against working spike |

---

## Open questions to resolve during Phase 1 spikes

1. **Challenge storage: Plug session vs DB vs ETS?** Plug session recommended but worth confirming no cookie size issues at 60s TTL.
2. **Wax↔SimpleWebAuthn JSON encoder** — throwaway spike in phase 9 to verify 40-line bridge estimate.
3. **Credo custom check for tenant-scope discipline** — prototype before committing; if >300 lines, fall back to integration-test enforcement.
4. **Conditional template rendering** — validate subdir pattern against `phx.gen.auth`'s actual renderer in Phoenix 1.8.5.

---

## Sources

- [hex.pm/packages/wax_](https://hex.pm/packages/wax_) — v0.7.0, May 18 2025 (HIGH)
- [github.com/tanguilp/wax mix.exs](https://github.com/tanguilp/wax/blob/master/mix.exs) (HIGH)
- [hex.pm/packages/cloak_ecto](https://hex.pm/packages/cloak_ecto) — v1.3.0, Apr 2024 (HIGH)
- [hexdocs.pm/cloak_ecto/Cloak.Ecto.Binary](https://hexdocs.pm/cloak_ecto/Cloak.Ecto.Binary.html) (HIGH)
- [hex.pm/packages/webauthn_components](https://hex.pm/packages/webauthn_components) — v0.8.0 (context only; not recommended) (HIGH)
- [simplewebauthn.dev/docs/packages/browser](https://simplewebauthn.dev/docs/packages/browser/) (HIGH)
- [github.com/MasterKale/SimpleWebAuthn](https://github.com/MasterKale/SimpleWebAuthn) (HIGH)
- [tech.jkbx.live — Passkeys in Phoenix using SimpleWebAuthn](https://tech.jkbx.live/passkeys-in-phoenix-using-simplewebauthn/) (MEDIUM)
- [elixirforum — Implementing multi-tenancy in Phoenix 1.8](https://elixirforum.com/t/implementing-multi-tenancy-in-phoenix-1-8-single-vs-multi-organization-approaches/70301) (MEDIUM)
- [medium.com — Multi-Tenant Application Design with Elixir+Phoenix (Mar 2026)](https://medium.com/@ffpauco/multi-tenant-application-design-with-elixir-phoenix-266074514b4a) (MEDIUM)
- [curiosum.com/blog/multitenancy-in-elixir](https://www.curiosum.com/blog/multitenancy-in-elixir) (MEDIUM)
- [github.com/ateliware/triplex](https://github.com/ateliware/triplex) (HIGH — not recommended)
