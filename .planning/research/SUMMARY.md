# Project Research Summary

**Project:** Sigra v1.31 DEMO-SHOWCASE
**Domain:** Seed-rich evaluator demo showcase — dual-role CI fixture + click-around SaaS
**Researched:** 2026-05-29
**Confidence:** HIGH

## Executive Summary

Sigra's v1.31 goal is to close the single genuine evaluator gap identified in the v1.30 post-milestone assessment: `test/example/priv/repo/seeds.exs` is empty, and the example app is a headless CI fixture rather than a positioned showcase. The recommended approach is to extend `test/example/` directly (the nested-app-drift cost was already paid in Phase 114) with idempotent, deterministic seeds covering 6 seeded personas, a dev-only credentials cheat-sheet page, a pre-populated audit log, and README screenshots captured by reusing the existing Playwright `captureAdminCheckpoint` infrastructure. No new standalone repo, no generic seeding framework, no host-domain data beyond what makes auth states legible.

The fundamental architectural tension is that `test/example/` serves two structurally conflicting roles: (1) a headless, sandbox-isolated CI fixture where tests create and roll back their own data, and (2) a human-facing, seed-populated dev server where an evaluator clicks around a realistic SaaS. The resolution is already structurally present in the codebase — the `test` alias never calls `seeds.exs`, and the dev and test databases are separate. The only required additions are: populate `seeds.exs`, add a `Mix.env() == :test` raise-guard at the top, and establish the `@demo.sigra.dev` / `@example.test` email-domain boundary as a visual-code-review invariant.

The critical risks are all security-posture risks, not technical ones. An auth library that commits known TOTP secrets, weak seed passwords, real-looking PII, or OAuth credentials in its own demo undermines its core trust proposition. Every resolved conflict below (TOTP determinism, Faker rejection, Argon2 cost) flows from one principle: the demo must demonstrate exactly the security posture that Sigra ships to production, not a weakened approximation that happens to be convenient for a presenter.

---

## Conflict Resolutions (Binding Decisions)

### Conflict 1: Faker vs. Hand-Curated Persona Names

**Decision: Reject Faker. Use hand-curated, role-descriptive persona names with fixed email addresses.**

STACK.md recommended `{:faker, "~> 0.18", only: :dev}` for realistic screenshot names. FEATURES.md and PITFALLS.md argued against it on determinism grounds. This synthesis resolves in favor of determinism:

- The demo doubles as a CI fixture. Non-deterministic data (even with a fixed RNG seed, Faker output depends on the library version and locale) creates fragile Playwright assertions. A persona renamed from "Alice Mercer" to "Alice Mercier" across a Faker patch breaks `toContainText()` assertions silently.
- The milestone non-goal is explicit: "no generic seeding framework." Faker is a data-generation dep that serves zero purpose beyond naming personas — the "looks professional" value does not outweigh the determinism cost.
- Role-descriptive names (`admin@demo.sigra.dev`, `alice@demo.sigra.dev`) are actually better evaluator communication than realistic-but-opaque names: they make the auth state self-documenting in the UI.
- Per CLAUDE.md: "copy-paste over deps when code is small and stable." A fixed persona list is ~10 lines. Faker is a dep for 10 lines of data.

**Implementation:** Hard-code 6 persona structs in `Example.Demo.Personas` with fixed emails, passwords, display names, and auth-state metadata. No Faker dep in `test/example/mix.exs`.

### Conflict 2: Deterministic TOTP Secret vs. "Committing a Known Secret"

**Decision: A deterministic demo-only TOTP secret is ACCEPTABLE in `seeds.exs`, with explicit guardrails.**

STACK.md proposed a fixed `:crypto.hash(:sha256, "sigra-demo-admin-totp-v1")` derived secret. PITFALLS.md S-5 flagged "committing a known TOTP secret" as the worst security pitfall. These are only contradictory if the demo path can reach production. The guardrails that make it safe:

1. **The `Mix.env() == :test` raise-guard** at the top of `seeds.exs` ensures seeds cannot run outside `MIX_ENV=dev`. The secret can only reach the dev database.
2. **The example app uses a passthrough `Cloak.Ecto` type** (`Example.Accounts.Encrypted.Binary`) that stores secrets as raw binaries with no actual encryption. This is already documented in the example app source as "a production app MUST replace this." The example app is explicitly, visibly not production-ready.
3. **Demo credentials are public by design.** The README evaluator lane prints them. A known TOTP secret in a demo whose entire purpose is "evaluators can log in and click around" is semantically equivalent to the printed password — it is fixture data, not a secret.
4. **The secret is clearly labeled** in source: `# Demo-only TOTP secret — intentionally deterministic. Never use in production.`

The PITFALLS.md warning applies to a scenario where a production-adjacent codebase committed a TOTP secret. That scenario does not apply here. The guardrail is the `Mix.env()` check and the passthrough crypto type, not abstaining from determinism.

**Implementation:** Store a module-attribute constant in `Example.Demo.Personas` derived via `:crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)`. Include it in the `admin` and `bob` persona definitions. `on_conflict: :nothing` on the MFA credential insert ensures re-seeds preserve the evaluator's accumulated TOTP state.

---

## Key Findings

### Recommended Stack

The dep delta for v1.31 is minimal by design. No new deps in the Sigra library `mix.exs`. No new npm packages. No new standalone repos. The only meaningful stack decisions are:

- **No Faker** — rejected (see Conflict 1 above). Fixed persona structs in source.
- **Argon2 dev cost** — `t_cost: 2, m_cost: 12` in `test/example/config/dev.exs`. Not `t_cost: 1, m_cost: 8` (that is the test-env override, not appropriate for a seed path that is reference code for adopters). `t_cost: 2, m_cost: 12` produces ~20-50ms per hash in dev, making 6 persona seeds complete in under 300ms while remaining a credible security posture. FEATURES.md's suggestion to keep default production cost is rejected on pragmatic grounds — `mix setup` taking 3-5 seconds for pure password hashing is unnecessary friction for a one-command spin-up. SECURITY CAVEAT: do not lower below `t_cost: 2, m_cost: 12` in dev; do not copy this override to `config/prod.exs`; the comment in `dev.exs` must be explicit.
- **Existing Playwright** — no new screenshot tools. `captureAdminCheckpoint/3` already exists in `priv/playwright/helpers/adminArtifacts.ts`. The `admin-checkpoints-chromium` project already runs a dedicated lane. Add `demo-screenshots.spec.ts` that reuses the existing helper.
- **`@playwright/test ^1.48.0`** — already in `package.json`, no version bump needed.
- **`:crypto.hash/2` + UUID stamping** — for deterministic primary key generation in persona-keyed seed rows where stable cross-references matter.

**Core technologies (unchanged from Sigra library):**
- `argon2_elixir ~> 4.1` — password hashing, used in seed path at `t_cost: 2, m_cost: 12` dev override
- `nimble_totp ~> 1.0` — TOTP primitive, used for deterministic demo secret derivation
- `ecto ~> 3.13` — `Repo.insert!/2` with `on_conflict:` — idempotency mechanism for all seed upserts
- `@playwright/test ^1.48.0` — existing infrastructure, reused for screenshot capture and demo-persona spec

### Expected Features

**Must have (v1.31 cannot ship without these):**
- `seeds.exs` idempotent, deterministic, covering all 6 seeded personas
- `Mix.env() == :test` raise-guard at top of `seeds.exs`
- `mix setup` alias already triggers `mix run priv/repo/seeds.exs` — no alias change needed, just populate the file
- README "Evaluating" section with credentials table, one-command spin-up, prerequisites block (Elixir 1.18+, Postgres, Docker one-liner)
- Pre-populated audit log: 15 rows minimum, 6+ event types, tied to admin persona, spread over deterministic past-30-days timestamps
- Seeded organizations: Acme Corp (admin=owner, alice=member, carol=member) + Beta Labs (admin=member, bob=owner)
- Seeded pending invitation row (to `invited@demo.sigra.dev`)
- At least 2 screenshots in README/guide (admin user index, admin user detail) — re-use existing Playwright checkpoint artifacts

**Should have (high value, low risk):**
- Passkey credential row seeded for admin persona (visible in admin user-detail) with `on_conflict: :nothing`
- API token row seeded for admin persona (shows `sigra_sk_` prefix surface)
- `EnterpriseConnection` row on Acme Corp in `configured`/pending-activation state
- Frank's scheduled-deletion state (`deleted_at` + `scheduled_deletion_at` set, `reactivation_live.ex` already exists)
- Dev-only `/demo/credentials` route (LiveView) showing persona table — guarded by `Application.compile_env(:example, :dev_routes)`
- `/dev/mailbox` mention in README evaluator lane
- Realistic app domain name in layout (e.g., "Vaultr — SaaS Auth Demo")

**Defer:**
- In-app persona banner overlay (medium complexity, best as follow-on)
- Playwright seeds-smoke spec exercising each persona (valuable, adds CI confidence, defer if phase is crowded)
- OAuth identity row for Carol (requires confirming exact `user_identities` schema shape before committing insert pattern)

### Final Persona Roster (6 seeded)

The four researchers proposed 4-6 (arc), 6 (STACK), and 7 (FEATURES). This synthesis converges on 6 seeded personas. FEATURES' "Eve" (unconfirmed) is handled via README guidance rather than a seeded row:

| # | Handle | Email | Auth State | Sigra Features Demonstrated |
|---|--------|-------|------------|------------------------------|
| 1 | admin | `admin@demo.sigra.dev` | Confirmed, TOTP MFA enrolled, multi-org owner+member, API token, passkey display row | Password auth, TOTP challenge, multi-org + org-switching, API bearer tokens, admin dashboard, rich audit trail |
| 2 | alice | `alice@demo.sigra.dev` | Confirmed, no MFA, member of Acme Corp | Standard confirmed user, session device labeling, org membership |
| 3 | bob | `bob@demo.sigra.dev` | Confirmed, TOTP MFA enrolled, owner of Beta Labs | MFA challenge on step-up, org ownership |
| 4 | carol | `carol@demo.sigra.dev` | Confirmed, OAuth identity row (GitHub, seeded directly) | OAuth-linked identity surface in settings and admin detail |
| 5 | dave | `dave@demo.sigra.dev` | Locked (`failed_login_attempts=5`, `locked_at` set), no password | Lockout state, admin unlock flow, rate limiting visibility |
| 6 | frank | `frank@demo.sigra.dev` | Confirmed, scheduled-deletion (`deleted_at` + `scheduled_deletion_at` set) | Data lifecycle: scheduled deletion + reactivation path |

Carol's OAuth row is a direct `user_identities` insert (no live OAuth roundtrip). Dave has no usable password. "Eve" (unconfirmed user) is handled via README guidance ("try registering without confirming your email to see the confirmation gate") rather than a seeded persona.

### Architecture Approach

The architecture is already structurally correct and requires minimal change. The dual-role conflict (CI fixture vs. evaluator showcase) is resolved by the pre-existing separation of `example_dev` and `example_test` databases, the `test` alias that never calls `seeds.exs`, and the new `Mix.env() == :test` guard added to `seeds.exs`. The new files are `Example.Demo.Seeds` (idempotent upsert orchestrator), `Example.Demo.Personas` (pure data module, source of truth for all persona definitions), and `DemoCredentialsLive` (dev-only LiveView for the `/demo/credentials` cheat-sheet route).

**Major components:**
1. `Example.Demo.Personas` (`lib/example/demo/personas.ex`) — pure data module; persona structs with fixed emails, display names, TOTP secrets, org affiliations, and auth states; no deps on anything else; single source of truth for both `seeds.ex` and `DemoCredentialsLive`
2. `Example.Demo.Seeds` (`lib/example/demo/seeds.ex`) — idempotent upsert orchestrator; seeds through `Example.Accounts` context API for user creation (fires audit events); patches `confirmed_at`/`locked_at`/`deleted_at` via direct `Repo.update!` for fields the context API does not expose; uses `on_conflict:` on all inserts
3. `priv/repo/seeds.exs` (modified) — adds `Mix.env() == :test` guard + calls `Example.Demo.Seeds.run/0`
4. `DemoCredentialsLive` (`lib/example_web/live/demo_credentials_live.ex`) — dev-only LiveView at `/demo/credentials`; reads persona list from `Personas` module (no DB query); guarded by `Application.compile_env(:example, :dev_routes)`
5. `demo-screenshots.spec.ts` (new Playwright spec) — reuses `captureAdminCheckpoint/3`; runs in dedicated `demo-showcase` Playwright project; captures populated admin pages for README
6. `test/example/README.md` — "Try it locally" evaluator lane with prerequisites block, credentials table, and rough-edge persona callouts

**Key patterns:**
- **Upsert-by-natural-key idempotency:** `on_conflict: {:replace, [...specific fields...]}` on email for users; `on_conflict: :nothing` for association rows (MFA credentials, org memberships, passkey display row)
- **Do not use hard-coded UUIDs** — let Postgres generate primary keys; key all upserts on natural keys (email, slug); fetch generated IDs after upsert for cross-referencing
- **Seed through context API first** — `Accounts.register_user/1` fires audit events; patch non-API-exposed fields via direct `Repo.update!` afterward
- **`@demo.sigra.dev` domain is reserved** for seeded personas; golden-path Playwright specs use `@example.test` domain; enforced at code review
- **Playwright project partition** — `demo-showcase.spec.ts` in a dedicated Playwright project, excluded from `chromium`/`mobile`/golden-path runs; never coupled to the `mix test` lane

### Critical Pitfalls

1. **Seeds running in the test environment (CI contamination)** — `Mix.env() == :test` raise-guard in `seeds.exs` is the primary defense; `test` alias in `mix.exs` never calls `seeds.exs` (already true, do not change); test DB is `example_test` (separate from `example_dev`). Two-layer defense-in-depth. This is the highest-severity risk because silent contamination corrupts CI reliability invisibly.

2. **Committing weak passwords** — Sigra is an auth library; every committed credential pattern is read as a recommendation by adopters. Passwords must be strong (`DemoAdmin1!` format: 12+ chars, mixed case, digit, symbol), must satisfy `Sigra.PasswordPolicy.validate/1`, and must be documented as public-by-design in the README. Never use `"password"`, `"admin"`, `"demo123"` patterns.

3. **Non-idempotent seeds causing CI re-run failures** — Every `Repo.insert!` in `seeds.exs` must have `on_conflict:` handling. Run seeds twice locally as a success criterion gate.

4. **Argon2 dev cost gap** — `test.exs` has `t_cost: 1, m_cost: 8` but this does NOT apply to `MIX_ENV=dev` seed runs. Add `config :argon2_elixir, t_cost: 2, m_cost: 12` to `test/example/config/dev.exs`. Do NOT use `t_cost: 1, m_cost: 8` in dev (looks wrong to security-conscious adopters reading seed code). Do NOT copy the override to any non-dev config.

5. **Playwright demo spec coupled to persona display names** — `toContainText("Alice Admin")` breaks when persona names change. Use `data-testid` attributes on auth-state indicators. Structural assertions survive persona renaming.

6. **Passkey seeding: fabricated COSE keys are misleading** — A `UserPasskey` row with a fabricated P-256 key shows "1 passkey enrolled" but fails authentication. Only use the fabricated key for admin's display-only row (clearly commented). Interactive passkey demo belongs in the Playwright CDP virtual-authenticator spec.

---

## Implications for Roadmap

Firm ordering rule from all four research files: **seeds before Playwright before screenshots before README**. Seeds own the full security posture; everything downstream is presentation.

### Phase 1: Seed Data Layer

**Rationale:** Everything else depends on seeds being correct and idempotent. This phase establishes the security posture for the entire milestone. It is the highest-risk phase (all security pitfalls live here) and must be verified before any other work begins.

**Delivers:**
- `Example.Demo.Personas` module with 6 persona structs (deterministic, role-descriptive names, fixed emails in `@demo.sigra.dev` domain, deterministic TOTP secrets as module attributes)
- `Example.Demo.Seeds` module (idempotent upsert orchestrator, seeds through context API, patches fields via direct Repo where context API does not expose them)
- Populated `priv/repo/seeds.exs` with `Mix.env() == :test` guard
- `test/example/config/dev.exs` Argon2 cost override (`t_cost: 2, m_cost: 12`)
- All 6 persona rows + 2 org rows + org memberships + pending invitation row + MFA credentials for admin and bob + API token row for admin + passkey display row for admin + `EnterpriseConnection` row for Acme Corp + Frank's scheduled-deletion timestamps + 15 pre-seeded audit events for admin

**Addresses:** All must-have features from FEATURES.md; all security pitfalls (S-1 through S-5); CI-determinism pitfalls C-2 and C-4

**Avoids:** Faker dep; committed TOTP secrets without clear demo-only labels; `Repo.insert!` without `on_conflict:`; email domains outside `.example`/`.test`; hard-coded UUID primary keys

**Success gate before proceeding:** `mix run priv/repo/seeds.exs && mix run priv/repo/seeds.exs` (run twice) completes without errors. `MIX_ENV=test mix run priv/repo/seeds.exs` raises with a clear error message.

**Research flag:** Confirm exact `user_identities` schema field names before Carol OAuth insert. Confirm `EnterpriseConnection` schema shape before Acme Corp SSO insert. Verify `Sigra.Testing.setup_totp/2` is available in `MIX_ENV=dev`.

### Phase 2: Dev Credentials Page and App Framing

**Rationale:** Once seeds are correct, the dev-only credentials cheat-sheet LiveView gives evaluators a self-service credential table in the browser. App framing (domain name in layout) is updated so the demo feels like a purposeful SaaS rather than a test fixture. Low-risk, high-evaluator-impact, no external dependencies.

**Delivers:**
- `DemoCredentialsLive` at `/demo/credentials` (dev-only, `Application.compile_env(:example, :dev_routes)` guard)
- Router addition for the `/demo` scope (same guard already used by Plug.Debugger and LiveDashboard)
- Realistic app name in layout (e.g., "Vaultr" — signals SaaS context without claiming to be a real product)
- `IO.puts` summary credentials block to stdout at end of seed run

**Avoids:** Accidentally adding the `/demo/credentials` route to any non-dev pipeline scope

### Phase 3: Playwright Demo Spec and Screenshots

**Rationale:** With seeds correct and the dev server populated, Playwright can exercise seeded personas and capture README-quality screenshots. This phase adds a `demo-showcase.spec.ts` in a dedicated Playwright project partition. Screenshots feed Phase 4.

**Delivers:**
- `demo-showcase.spec.ts` — logs in as seeded personas, asserts auth-state-specific behavior using `data-testid` or structural DOM checks (no persona name text assertions)
- `demo-screenshots.spec.ts` — captures admin user index, admin user detail, MFA settings page, org settings page, Frank's scheduled-deletion state; reuses `captureAdminCheckpoint`
- New `demo-showcase` Playwright project in `playwright.config.ts` — excluded from `chromium` and `mobile` project runs

**Avoids:** `toContainText(personaName)` assertions; adding demo specs to golden-path project; `toHaveScreenshot()` visual regression baselines for demo flows

**Research flag:** No deeper research needed — Playwright project-partition pattern and CDP virtual-authenticator pattern are already established in the codebase.

### Phase 4: README Evaluator Lane and Documentation

**Rationale:** Last phase because it depends on screenshots (Phase 3) and verified credentials (Phase 1). The README is the conversion surface.

**Delivers:**
- `test/example/README.md` "Evaluating Sigra" section with prerequisites block, credentials table, rough-edge persona callouts, 2+ screenshots, `/dev/mailbox` and `/demo/credentials` route mentions
- `guides/introduction/demo-showcase.md` guide (detailed walkthrough)

**Avoids:** README that starts with `mix setup` without a prerequisites block; credentials hidden behind terminal output without a persistent location; happy-path-only README that omits rough-edge personas

### Phase Ordering Rationale

Seeds are Phase 1 because they own the security posture and are a hard dependency for all other phases. The credentials page and framing are Phase 2 because they are low-risk and high-evaluator-impact, but only make sense once seeds are known-good. Playwright is Phase 3 because it exercises seeded data. README is Phase 4 because it embeds Phase 3's screenshots and references Phase 1's exact credential strings.

### Research Flags

Phases needing attention during planning:
- **Phase 1 (Seeds):** Confirm `user_identities` schema field names before Carol OAuth insert. Confirm `EnterpriseConnection` schema shape. Verify `Sigra.Testing.setup_totp/2` dev availability.

Phases with standard patterns (no deep research needed):
- **Phase 2:** Phoenix `Application.compile_env` router guard is the established pattern for dev-only routes.
- **Phase 3:** CDP virtual-authenticator and `captureAdminCheckpoint` patterns already exist in the codebase.
- **Phase 4:** Documentation phase; no technical unknowns.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All decisions verified against hex.pm, repo source, and existing CI infrastructure. Faker rejection is well-supported by all three other research files. |
| Features | HIGH | Persona roster grounded in existing `auth_fixtures.ex` test scenarios; schema fields verified against live `user.ex` source. Carol OAuth insert flagged for schema confirmation before Phase 1. |
| Architecture | HIGH | Dual-role isolation architecture is already present in the codebase; additions are new files within `test/example/`. Playwright project-partition pattern is established. |
| Pitfalls | HIGH | All pitfalls grounded in codebase inspection, Phase 114 retro, and v1.29 retro. Argon2 dev cost gap verified by direct inspection of `test.exs` vs `dev.exs`. |

**Overall confidence:** HIGH

### Gaps to Address

- **Carol OAuth insert schema:** Confirm `user_identities` table field names against `test/example/lib/example/accounts/` before writing the Carol OAuth persona insert. If the schema does not exist in the example app, defer Carol's OAuth row.
- **`Sigra.Testing.setup_totp/2` in dev:** Confirm this function is available outside `MIX_ENV=test`. If it is test-only, seed MFA credentials via direct `Repo.insert!` on `UserMfaCredential`.
- **Passkey display row changeset:** Confirm `Example.Accounts.UserPasskey.create_changeset/2` API and that `on_conflict: :nothing` is supported without triggering Wax ceremony validation. If it fires Wax validation, skip the display row and note it as deferred.

---

## Sources

### Primary (HIGH confidence)

- `test/example/mix.exs` — aliases, deps, confirmed seeds.exs execution path (repo-verified 2026-05-29)
- `test/example/priv/repo/seeds.exs` — confirmed empty (repo-verified 2026-05-29)
- `test/example/config/test.exs` — `t_cost: 1, m_cost: 8` present; `example_test` DB name (repo-verified 2026-05-29)
- `test/example/config/dev.exs` — absence of Argon2 cost override; `example_dev` DB name (repo-verified 2026-05-29)
- `test/example/lib/example/accounts/user.ex` — auth-state fields (`confirmed_at`, `locked_at`, `deleted_at`, `scheduled_deletion_at`) (repo-verified)
- `test/example/lib/example/accounts/encrypted.ex` — passthrough Cloak type; confirms encryption is no-op in example app (repo-verified)
- `test/example/priv/playwright/playwright.config.ts` — Playwright project partition pattern, screenshot infrastructure (repo-verified)
- `test/example/priv/playwright/helpers/adminArtifacts.ts` — `captureAdminCheckpoint` helper (repo-verified)
- `test/example/priv/playwright/tests/passkey-login.spec.ts` — CDP virtual authenticator pattern (repo-verified)
- `test/example/priv/playwright/tests/golden-path.spec.ts` — TOTP secret read from DOM at runtime, `@example.test` domain convention (repo-verified)
- `lib/sigra/testing.ex` — `generate_totp_code/1` confirmed present (repo-verified)
- `lib/sigra/passkeys/cose_key.ex` — COSE key serialization via ETF + cloak_ecto (repo-verified)
- `.planning/MILESTONE-ARC.md` — DEMO-SHOWCASE scope, non-goals, Phase 114 drift lesson (authoritative)
- `hex.pm/packages/faker` — v0.18.0, Feb 2024, 72M downloads, pure Elixir (verified 2026-05-29; rejected for this milestone)

### Secondary (MEDIUM confidence)

- [bitcrowd.dev/idempotent-seeds-in-elixir](https://bitcrowd.dev/idempotent-seeds-in-elixir/) — upsert with deterministic IDs pattern (community blog; patterns verified against Ecto docs)
- [elixirforum.com/t/patterns-for-making-seeds-idempotent](https://elixirforum.com/t/patterns-for-making-seeds-idempotent/58299) — find-or-create community consensus
- `.planning/threads/adoption-evidence-and-demo-showcase.md` — adoption verdict, genuine gap analysis (internal planning doc)

### Tertiary (LOW confidence)

- Auth0 "1-click auto-login demo user" pattern — informed `/demo/credentials` cheat-sheet route suggestion
- SuperTokens demo pattern — informed "persona table is better than single generic account" conclusion

---

*Research completed: 2026-05-29*
*Ready for roadmap: yes*
