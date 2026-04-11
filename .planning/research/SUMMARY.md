# Project Research Summary — Sigra v1.1 Foundations

**Project:** Sigra — Phoenix authentication library
**Domain:** Adding logical multi-tenancy (Organizations) + WebAuthn (Passkeys) to a shipped auth library (v1.0 → v1.1)
**Researched:** 2026-04-11
**Confidence:** HIGH (all four research tracks converge; remaining unknowns are bounded and enumerated)

> **Milestone scope rule:** This summary covers v1.1 Foundations only. Admin UI, impersonation, and audit views are v1.2. Every v1.1 decision has been checked for v1.2 forward-compat — flagged under "v1.2 Load-Bearing Decisions" below.

---

## Executive Summary

Sigra v1.1 is a **purely additive milestone** bolting two independent feature tracks onto a shipped auth library: logical multi-tenancy (organizations + memberships on a single DB) and WebAuthn passkeys (via `wax_`). All four research streams — stack, features, architecture, pitfalls — converge on a consistent picture and **no cross-researcher contradictions surfaced** except the backfill-default question (flagged for discuss-phase). The recommended approach: add exactly one library dep (`{:wax_, "~> 0.7"}`), reuse every v1.0 primitive (Scope, Session, Token HMAC, Cloak vault, Hammer, Audit, Oban workers, Swoosh), and introduce a subdirectory-based generator feature manifest pattern that is **load-bearing for v1.2's `--no-admin`** and must be implemented correctly the first time.

Organizations is built as row-level MT with an explicit `org_id` FK — no library (Triplex, Tenantex, Ash MT all rejected as wrong model or abandoned), no PG schema-per-tenant, no URL prefix routing in v1.1, no auto-created personal orgs. Users without an org see a "create your first organization" prompt; a backfill migration for v1.0 upgraders is opt-in via `--backfill-personal-orgs`. The single largest bug class is the cross-tenant query leak (Pitfall O-1), defended in three layers: a raising `Sigra.Organizations.Query.for_org/2` helper, a Credo custom check flagging raw `Repo.` calls in tenant-scoped contexts, and integration isolation tests. Passkeys use `wax_` for the FIDO2 ceremony, `@simplewebauthn/browser ~> 13` as the JS client (shipped via the generator template, not mix.exs), signed+encrypted Plug session for 60s challenge storage, and Cloak-encrypted `public_key` (reusing the v1.0 OAuth vault). Passkey enrollment is sudo-gated from day one; every registration emails the user (reusing the v1.0 suspicious-login shape); sign-count regression defaults to `:warn` not `:revoke` (false-positive-heavy signal).

Key risks are well-understood and mitigable: (1) **cross-tenant leakage** (O-1, O-11) — layered prevention; (2) **invite hijack** (O-2, Jetstream #907 / CVE-2026-1529 class) — email-bound HMAC tokens with current-user email assertion; (3) **WebAuthn challenge replay** (P-1, OneUptime CVE) — server-stored challenge in Plug session, never from `clientDataJSON`; (4) **stolen-session passkey enrollment** (P-2) — `Sigra.Plug.RequireSudo` gate + email notification; (5) **generator partial-apply** (X-1) — feature manifest + subdirectory convention + combinatorial CI smoke test. Every critical pitfall traces to a concrete CVE / post-mortem / GitHub issue. **The organizations and passkeys tracks are independent and parallelizable after two foundation phases (generator feature system + scope/session extension) land.**

---

## Key Findings

### Recommended Stack Additions (from STACK.md)

**New mix.exs dep (exactly one):**
- **`{:wax_, "~> 0.7"}` (v0.7.0, May 2025)** — only maintained WebAuthn RP library for Elixir; passes all 170 official FIDO2 test suite tests. Package name has a trailing underscore. Covers ES256/RS256/PS256/Ed25519. Clean on OTP 27 / Elixir 1.18.

**New JS dep (generator template only, not mix.exs):**
- **`@simplewebauthn/browser ~> 13`** — MasterKale, ~8 KB, handles base64url + AbortController + conditional mediation + error translation. "~30 lines vanilla JS" is a trap.

**Reused v1.0 stack (zero version bumps):**
- `cloak_ecto ~> 1.3` — reused for `UserPasskey.public_key` via `Cloak.Ecto.Binary` on `:binary` (bytea). Reuses OAuth-token vault. Known-unqueryable — lookups go by `credential_id` (unencrypted + indexed).
- `Sigra.Token` HMAC helper — new context `:organization_invite`, zero code change.
- `Hammer` — new keys: `"passkey_ceremony:#{user_id}"` (5/min), per-user invitation creation (20/day).
- `Oban` (optional) — new workers: `PasskeyChallengeCleanup`, membership-change session cleanup.
- `NimbleOptions` — new config groups `:organizations`, `:passkeys` (rp_id, rp_name, origins, attestation, challenge_ttl).
- `Swoosh` — new `organization_invitation_email.ex`; existing emails grow optional `opts[:organization]`.

**Explicitly NOT adopted:** no MT library (Triplex/Tenantex/Ash MT); no `webauthn_components` (wrong layer); no `Igniter` (scope creep — revisit v2.0); no custom WebAuthn reimplementation.

### Consolidated Feature Table Stakes / Differentiators / Anti-Features (from FEATURES.md)

**Must have — Table Stakes:**

*Organizations:* `Organization` (name + unique slug + JSONB settings + soft-delete), `OrganizationMembership` (owner/admin/member enum), `OrganizationInvitation` (HMAC token, hashed, 7d default expiry, accepted_at, revoked_at); `Sigra.Organizations` context + `Sigra.Plug.RequireMembership`; Scope struct + `user_sessions.active_organization_id` column; invite-by-email with email-locked acceptance; login handles 0/1/2+ org cases gracefully; `OrganizationSwitcherLive`/`OrganizationSettingsLive`/`OrganizationMembersLive`/`InvitationAcceptLive`; last-owner guard enforced **server-side inside an Ecto.Multi**; audit log auto-attaches `organization_id` (real column, not JSONB); `--no-organizations` opt-out; opt-in backfill migration.

*Passkeys:* `UserPasskey` schema (Cloak-encrypted public key, unique `credential_id`, `sign_count`, `aaguid`, `nickname`, `transports`, `last_used_at`, **`rp_id`** for domain-rename safety); `Sigra.Passkeys`/`Registration`/`Authentication` contexts + `Sigra.Plug.PasskeyChallenge`; passkey-as-2FA (default, integrated into `MfaSettingsLive`); passkey-as-primary (opt-in, email-first); `PasskeyEnrollmentLive`/`PasskeyAuthenticationLive` + `passkey_hooks.js`; runtime RP ID / origin / RP name config (compile-time baking forbidden); attestation `:none`, UV `:preferred` defaults; multiple passkeys per user (soft cap 10), rename, delete (sudo-gated); AAGUID friendly-name bundle; Conditional UI / autofill (feature-detected); duplicate-device detection; email notification on registration; `--no-passkeys` opt-out.

*Cross-cutting:* generator feature-manifest subdirectory pattern (first use — load-bearing for v1.2); testing helpers `create_organization/1`, `add_membership/3`, `log_in_user_with_org/3`, `register_passkey/2`, `authenticate_with_passkey/2`.

**Should have — Differentiators:** no auto-created personal org (deliberate Jetstream-mistake avoidance); invite token query-param → register-into-org frictionless flow; resume last-active org on login; email-locked invite acceptance; AAGUID-derived friendly device names; sync-credential transparency badges ("Synced to iCloud/Google/Windows"); unified MFA settings page (TOTP + passkeys + backup codes on one screen — Clerk pattern).

**Anti-features — explicitly NOT in v1.1:** auto-created "personal team" on signup; PostgreSQL-schema-per-tenant; full RBAC/permissions engine; "accept invitation as any logged-in user"; unbounded invite lifetime; passkey with no recovery fallback; attestation `:direct` default; `userVerification: required` default; admin cross-org management UI (v1.2); admin impersonation (v1.2).

### Integration + Build Order (from ARCHITECTURE.md)

Consolidated dependency-respecting phase structure (13 phases, two parallelizable tracks):

| # | Phase | Depends on | Addresses pitfalls | Track |
|---|-------|------------|--------------------|-------|
| 1 | **Generator feature system** (subdirs + behaviour + `Features.Core` move) | — | X-1, X-3 | Foundation |
| 2 | **Scope + session column extension** (`:active_organization`, `:membership`, reserved `:impersonating_from`; `user_sessions.active_organization_id`) | 1 | O-5, O-6 | Foundation |
| 3 | **Organizations schemas + context** (`Query.for_org/2`, soft-delete FK design, reserved slug list) | 2 | O-1, O-4, O-9, O-10 | Org track |
| 4 | **Org plugs + scope hydration** (`LoadActiveOrganization`, `RequireMembership`, `on_mount`) | 2, 3 | O-5, O-6 | Org track |
| 5 | **Audit integration** (`metadata_from_scope`, `organization_id` real column, reserved `effective_user_id`, worker arg pattern) | 4 | O-7 (IMP+), O-11 | Org track |
| 6 | **Org LiveViews + switcher** | 3, 4, 5 | O-5 | Org track |
| 7 | **Invitation flow + email template** | 6 | O-2, O-3 | Org track |
| 8 | **Backfill migration + `--organizations` generator wiring** | 7 | O-8, X-2 | Org track |
| 9 | **Passkey schema + `Sigra.Passkeys.*` contexts** | 1 (parallel with 3+) | P-1, P-4, P-6, P-7 | Passkey track |
| 10 | **`PasskeyChallenge` plug + runtime config + JS hooks infra** | 9 | P-1, P-3, P-8 | Passkey track |
| 11 | **Passkey LiveViews + POST-auth controller** | 10 | P-2, P-5, P-9 | Passkey track |
| 12 | **`--passkeys` generator wiring** | 11, 1 | X-1, X-3 | Passkey track |
| 13 | **Docs + CI smoke extension + upgrade guide** | 8, 12 | P-3, P-10, P-11, X-4 | Cross-cut |

**Parallelization:** Phases 9–11 (passkey) run in parallel with 3–7 (org) after phases 1 + 2. Phases 8 and 12 are serialization points before phase 13.

### Watch Out For — Top 10 Pitfalls (from PITFALLS.md)

| # | Pitfall | Severity | v1.2 impact | Prevention |
|---|---------|----------|-------------|------------|
| 1 | **O-1: Missing `organization_id` filter → cross-tenant leak** | CRITICAL | IMP+ | 3-layer: raising `for_org/2` + Credo custom check + integration isolation tests |
| 2 | **O-2: Invite token redeemable by wrong logged-in user** (Jetstream #907, Keycloak CVE-2026-1529) | CRITICAL | IMP+ | Email-bound HMAC token + `current_user.email == invitation.email` assertion (citext) + mismatch page, no accept button |
| 3 | **O-4: Last-owner lockout + admin-deletes-owner escalation** | CRITICAL | IMP+ | Server-side role gate + last-owner count **inside the same `Ecto.Multi`** + explicit `transfer_ownership` flow |
| 4 | **P-1: Server accepts client-supplied challenge → WebAuthn replay** (OneUptime GHSA-gjjc-pcwp-c74m) | CRITICAL | — | Server-generated + server-stored (Plug session) + server-verified; delete on verify; 60s TTL |
| 5 | **P-2: Passkey enrollment without re-auth → stolen-session perma-takeover** | CRITICAL | IMP+ | Gate `PasskeyEnrollmentLive` with `Sigra.Plug.RequireSudo`; email notification; audit event |
| 6 | **O-7: Audit misattribution under impersonation (IMP+)** | MED v1.1 / CRIT v1.2 | **IMP+ core** | Add `effective_user_id` + `organization_id` as **real columns** in v1.1 migration; single assembly via `metadata_from_scope/2` |
| 7 | **X-1: Generator partial-apply on first conditional templates** | HIGH | IMP+ | Subdir feature manifest + idempotent writes + pre-flight `Mix.Phoenix.check_*` + combinatorial CI smoke matrix |
| 8 | **O-10: Organization deletion cascade wipes audit log** | HIGH | IMP+ | Soft-delete default; `audit_events.organization_id → on_delete: :nilify_all` + metadata copy of org name/slug |
| 9 | **O-11: Background worker runs without tenant context** | HIGH | IMP+ | `Sigra.Workers` behaviour; every worker `args` carries `organization_id` + `actor_id`; `perform/1` reconstructs scope |
| 10 | **P-3: RP ID / origin rotation kills all existing passkeys** | HIGH operational | — | Runtime config only; `NimbleOptions` boot validation; store `rp_id` on `UserPasskey`; document rename playbook |

**Honourable mentions:** O-3 invite replay (hashed storage + inside Multi), O-5 cross-org session confusion (server session authoritative), O-9 slug squatting (hardcoded reserved list including `admin`), P-4 sign-count false positives (`:warn` default), P-5 passkey-sole-factor lockout (mandatory fallback at enrollment), P-6 StrongKey credential-confusion (CVE-2025-26788 — verify returned credential_id belongs to requested user), P-8 JS hook abort/timeout (SimpleWebAuthn + `AbortController` in `destroyed()`), X-2 migration ordering (strictly ordered timestamps, idempotent batches), X-4 v1.0→v1.1 upgrade crashes (nil-guarded template accessors + upgrade test fixture).

---

## v1.2 Load-Bearing Decisions (Forward-Compat)

Every item below is **chosen in v1.1 specifically to unblock v1.2** and must be implemented correctly the first time. Missing any one forces an expensive retrofit in v1.2.

| Decision | Why it's load-bearing |
|---|---|
| **`%Scope{impersonating_from: nil}` reserved field** | v1.2 `Sigra.Plug.Impersonate` populates it; pattern matches stay additive |
| **`audit_events.organization_id` as a real indexed column** (not JSONB) | v1.2 per-org audit views need index-friendly filtering |
| **`audit_events.effective_user_id` column added in v1.1** (populated identically to `user_id`) | v1.2: `user_id` = impersonator, `effective_user_id` = target; v1.2 divergence is additive only |
| **`metadata_from_scope/2` as single audit assembly point** with reserved comment block | v1.2 changes only the helper, not call sites |
| **Subdirectory + feature manifest generator pattern** (`Sigra.Install.Feature` behaviour + `Features.{Core, Organizations, Passkeys}`) | v1.2's `--no-admin` = add `Features.Admin` + `admin/` subdir. No rework. |
| **`admin` in hardcoded reserved slug list** | Prevents `/admin` route conflict when v1.2 admin dashboard lands |
| **Session-only active-org storage** (no `/orgs/:slug/...` in v1.1) | v1.2 admin UI introduces `/admin/*` as separate scope with zero disruption |
| **Oban `Sigra.Workers` behaviour: args carry `organization_id` + `actor_id`** | v1.2 worker audit writes need full scope reconstruction |
| **Passkey enrollment in v1.2 "locked-down ops" list** | v1.2 impersonation must not allow impersonator to enroll their own passkey as target user |
| **`user_sessions.active_organization_id` as single source of truth** (not cookie, not URL) | v1.2 impersonation also per-session; co-locates cleanly |
| **Soft-delete orgs + `audit_events.organization_id → :nilify_all`** | v1.2 audit feed must survive org deletion for SOC2/GDPR |
| **`UserPasskey.rp_id` stored at registration** | v1.2+ admin UI distinguishes credentials across RP ID eras |

---

## Implications for Roadmap

### Suggested Phase Structure (13 phases)

1. **Generator Feature System** — load-bearing for v1.2 `--no-admin`; mechanical refactor moving v1.0 flat templates into `core/` subdir.
2. **Scope + Session Foundation** — `%Scope{}` gets `:active_organization`, `:membership`, reserved `:impersonating_from`; `user_sessions.active_organization_id`.
3. **Organizations Schemas + Context** (org track begins) — `Query.for_org/2` raising helper, last-owner guard in Multi, reserved slugs, soft-delete + cascade.
4. **Org Plugs + Scope Hydration** — `LoadActiveOrganization`, `RequireMembership`, stale-pointer handling.
5. **Audit Integration** — `organization_id` + `effective_user_id` real columns, `metadata_from_scope/2`, `Sigra.Workers` behaviour.
6. **Org LiveViews + Switcher** — dropdown in header, LiveComponent posting to plain controller.
7. **Invitation Flow + Email** — email-locked acceptance, HMAC token, single-use + expiry + revoke.
8. **Backfill Migration + `--organizations` Generator Wiring** (serialization point) — opt-in, idempotent, batched, adapter-branched.
9. **Passkey Schema + Contexts** (passkey track, parallel to 3-7) — `wax_` dep, Cloak-encrypted public key, sign-count policy, credential-confusion prevention.
10. **Passkey Challenge Plug + JS Hooks Infra** — Plug session challenge, runtime RP ID config, SimpleWebAuthn bridge.
11. **Passkey LiveViews + POST-Auth Controller** — sudo-gated enrollment, email notification, duplicate-device detection, conditional UI.
12. **`--passkeys` Generator Wiring** (serialization point) — validates feature manifest pattern on a second feature.
13. **Docs + CI Smoke Extension + Upgrade Guide** — combinatorial matrix, `test/upgrade_test.exs` fixture, honest threat model, RP-ID rename playbook.

**Ordering rationale:** phases 1+2 are foundation (sequential); phases 3-8 (org) and 9-11 (passkey) run in parallel; phases 8 and 12 are serialization points; phase 13 gates the release with the upgrade test. Hazard-dense phases front-loaded (phase 3 last-owner/cascade, phase 5 IMP+ audit, phase 7 invite hijack, phase 9 challenge replay, phase 11 sudo gate) — each ships pitfall mitigations as phase requirements, not follow-ups.

### Research Flags

- **Phase 1:** MEDIUM — validate subdir pattern against `phx.gen.auth` 1.8.5 renderer before template move.
- **Phase 3:** MEDIUM — time-boxed Credo custom check prototype (1 day); fall back to integration-test-only if >300 lines.
- **Phase 9:** MEDIUM — two kickoff spikes: (a) verify `Wax.Challenge` struct + `aaguid` return type in `wax_ 0.7`, (b) validate `WaxJson` bridge end-to-end against SimpleWebAuthn vectors.
- **Phase 10:** MEDIUM — Plug session cookie size sanity check (60s TTL, <4KB ceiling) + `app.js` injection target detection.

Phases with standard patterns (no deep research): 2, 4, 6, 7, 11, 12.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | hex.pm + upstream verified; MEDIUM only on 40-line `WaxJson` bridge estimate and Igniter non-adoption |
| Features | HIGH | Clerk/Auth0/WorkOS/GitHub/Better Auth/Jetstream/FIDO Alliance/web.dev/Chrome team all verified |
| Architecture | HIGH | Grounded in direct read of v1.0 code; MEDIUM only on `Wax.Challenge` struct + `aaguid` return type in `wax_ 0.7` (spike in phase 9) |
| Pitfalls | HIGH | Every pitfall cites concrete CVE / GitHub advisory / post-mortem / spec clause |

**Overall: HIGH** — four research tracks converge with **no contradictions** except the backfill-default question (open question #1 below).

### Gaps to Address

- Phase 9 kickoff spike (30 min): verify Wax 0.7 struct shapes.
- Phase 9 kickoff spike (2-4 hours): validate `WaxJson` bridge end-to-end.
- Phase 3 kickoff spike (1 day time-boxed): Credo tenant-scope check prototype.
- Phase 1 kickoff spike: validate subdir pattern against `phx.gen.auth` 1.8.5 renderer.
- Phase 10 spike: Plug session cookie size sanity check.
- v1.0 → v1.1 upgrade test (`test/upgrade_test.exs`): required deliverable before phase 13 sign-off.

---

## Open Questions for `/gsd-discuss-phase` (resolve before phase planning)

1. **Backfill default: auto-create personal orgs or require explicit creation?** (ARCHITECTURE A7 vs FEATURES A.3 + PITFALLS O-8 — **the one cross-track contradiction**). Recommended resolution: no auto-creation on signup; opt-in backfill for v1.0 upgraders only via `--backfill-personal-orgs`.
2. **Passkey-as-primary in v1.1: MVP, opt-in, or deferred?** Recommend opt-in (`:passkey_primary_enabled` config) with enforced fallback requirement.
3. **Usernameless / discoverable-credential flow in v1.1 or later?** Recommend shipping Conditional UI / autofill (feature-detected) in v1.1; defer fully usernameless resident-key flow.
4. **Challenge storage: Plug session vs DB vs ETS — cookie size OK at 60s TTL?** Recommend Plug session pending phase-9 empirical validation.
5. **Credo custom tenant-scope check — prototype, ship, or defer?** Time-box spike in phase 3; ship if ≤300 lines.
6. **`audit_events.organization_id`: NOT NULL or nullable?** Recommend nullable (library-emitted events outside org context need it); document "org-less" events explicitly.
7. **`aaguid` column type: `:binary` 16 bytes or UUID string?** Spike-verify `wax_ 0.7` return shape at phase 9 kickoff.
8. **JS hook injection: assume Phoenix 1.8 default `assets/js/app.js` or detect?** Recommend: only inject if marker present; otherwise print manual instructions. No silent failure.
9. **Sign-count regression default policy: `:warn`, `:require_reauth`, or `:revoke`?** Recommend `:warn` default (ImperialViolet/Apple iCloud constant-zero consensus); configurable via NimbleOptions.
10. **Last-active-org resume on login: per-user or per-session?** Recommend per-session (`user_sessions.active_organization_id`); last-active comes from most recent non-nil session row.
11. **Invite token TTL configurable floor/ceiling?** Default 7d (consensus), configurable via NimbleOptions, document "longer TTL = phishing window," recommend against >30d.
12. **Which passkey ceremony ships first — registration or authentication?** Registration first (required to test authentication), matches dependency order.

---

## Sources

**Primary (HIGH):** hex.pm (`wax_` v0.7.0, `cloak_ecto` v1.3.0); tanguilp/wax mix.exs; simplewebauthn.dev; MasterKale/SimpleWebAuthn; Clerk / Auth0 / WorkOS / Better Auth / Jetstream / GitHub / Bitwarden docs; FIDO Alliance + web.dev + Chrome team passkey guides; W3C WebAuthn Level 2 spec §5.4/§7.2/§13.4.3; OWASP Multi-Tenant Security Cheat Sheet; NIST SP 800-63B; CVEs: Jetstream #907, Keycloak CVE-2026-1529, OneUptime GHSA-gjjc-pcwp-c74m, StrongKey CVE-2025-26788, CVE-2024-9956, DEF CON 33 "Passkey Pwned" (SquareX labs); grounded v1.0 source reads at `lib/sigra/{session,audit,token}.ex`, `lib/sigra/plug/{fetch_session,require_sudo}.ex`, `lib/mix/tasks/sigra.install.ex`, `test/example/lib/example_web/{user_auth,router}.ex`, `test/example/lib/example_web/components/layouts.ex`, `test/example/lib/example/accounts/scope.ex`, `priv/templates/sigra.install/` (44 files).

**Secondary (MEDIUM):** Filip Pauco "Multi-Tenant Application Design with Elixir+Phoenix" (Mar 2026); Curiosum multi-tenancy guide; Alembic blog; Elixir Forum MT threads; InstaTunnel "Multi-Tenant Leakage" post-mortem (Jan 2026); Borabastab "Six Shades of Multi-Tenant Mayhem" (May 2025); Islam Ghandar admin-delete-owner bounty write-up; Rojan Rijal Luminate privilege escalation; Vishal Barot "Invitation Hijacking"; Corbado passkey guides; Ory troubleshooting docs; Authsignal/Mojoauth/Askleo passkey recovery articles; ImperialViolet "Signature counters" (Adam Langley, Aug 2023); tech.jkbx.live "Passkeys in Phoenix using SimpleWebAuthn".

**Internal:** `.planning/PROJECT.md`, `.planning/v1.2-DIRECTION.md`, `.planning/research/{STACK,FEATURES,ARCHITECTURE,PITFALLS}.md`, `prompts/Building the gold-standard Elixir:Phoenix authentication library.md`.
