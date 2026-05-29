# Project Research — STACK for v1.31 DEMO-SHOWCASE

**Project:** Sigra
**Milestone:** v1.31 DEMO-SHOWCASE
**Researched:** 2026-05-29
**Confidence:** HIGH (verified against hex.pm, repo source, existing Playwright infrastructure, and Ecto docs)

---

## Headline Recommendation

**Add `{:faker, "~> 0.18", only: [:dev]}` to `test/example/mix.exs` only.** No new deps in the Sigra library `mix.exs`. No new deps in the Playwright `package.json` — screenshot capture is already fully covered by existing Playwright infrastructure. Hand-roll a slim `Seeds` helper module inside `test/example/priv/repo/` for the idempotency / find-or-create pattern. Everything else — Argon2id seeding, TOTP seeding, passkey representation — follows directly from primitives already shipped.

---

## (1) Idiomatic `seeds.exs` Patterns — Faker vs Hand-Roll

### The Gap

`test/example/priv/repo/seeds.exs` is empty (confirmed in source). The goal is 4–6 named personas that an evaluator can click around without signup friction.

### Faker

`faker ~> 0.18` (latest stable `0.18.0`, last published 2024-02-29, 72M all-time downloads) provides:

- `Faker.Person.En.name/0`, `Faker.Person.En.first_name/0`, `Faker.Person.En.last_name/0`
- `Faker.Internet.email/0`, `Faker.Internet.user_name/1`
- `Faker.Company.En.name/0`

The API surface needed for this milestone is roughly 6 functions from 2 modules (`Faker.Person.En` and `Faker.Internet`). The library is pure Elixir (zero NIFs, zero compile-time build steps), and it correctly supports locale scoping.

**Verdict: add `{:faker, "~> 0.18", only: [:dev]}` to `test/example/mix.exs`.** It earns its place because:

1. Realistic names and emails ("Alice Mercer", "alice.mercer@acme.example") read dramatically better in screenshots than `user1@test.com`. This directly impacts the evaluator experience, which is the milestone goal.
2. It is a `dev`-only dep — zero impact on the library build, CI dep-off lanes, or library consumers.
3. Zero NIFs / zero build toolchain requirements (important for CI reproducibility).
4. `0.18.0` is stable/slow-moving — no risk of surprise breaking changes.

**Do NOT copy-paste faker.** The module count needed (Person.En, Internet) would expand once personas need richer data (company names, display names, job titles). Keeping the dep is cleaner than maintaining a bespoke name list.

**Do NOT add faker to the Sigra library `mix.exs`.** Seeds are not a library concern. Faker belongs in `test/example/` only.

### Idempotency Pattern — Hand-Roll, Not ex_machina

`ex_machina ~> 2.8` (last published 2024-06-25, beam-community maintained) is a factory library designed for ExUnit test setup, not seed scripts. It does not provide an idiomatic find-or-create for seeds. Adding it to `test/example/` just to write seeds would be a framework imported for a feature it doesn't own.

**Use Ecto's built-in upsert instead.** The idiomatic Elixir/Phoenix pattern for idempotent seeds (verified against bitcrowd.dev and ElixirForum posts) is:

```elixir
# In test/example/priv/repo/seeds.exs or a Seeds helper module:

# Option A — find-or-create by unique key (simplest, most readable)
def find_or_create_user(email, attrs) do
  case Example.Repo.get_by(Example.Accounts.User, email: email) do
    nil  -> Example.Accounts.register_user!(attrs)
    user -> user
  end
end

# Option B — upsert with deterministic IDs (best for relations)
Example.Repo.insert!(
  %Example.Accounts.User{id: deterministic_id("admin-persona"), ...},
  on_conflict: :replace_all,
  conflict_target: :id
)
```

For this milestone, **Option A (find-or-create) is recommended** because:
- Persona emails are the natural unique key (`admin@demo.sigra.example`, `alice@demo.sigra.example`, etc.).
- `on_conflict: :replace_all` would wipe TOTP secrets, sessions, and audit rows on every re-seed — not what a demo persona needs.
- The find-or-create pattern preserves the persona's accrued state (sessions, audit trail, org memberships) across re-seeds, which is what a "click-around demo" needs.

**Implement as a small `Example.Seeds` module** at `test/example/priv/repo/seeds_helper.ex` (or inline at the top of `seeds.exs`). Do not add `ex_machina`. The logic is ~30 lines; copy-paste wins here per the `CLAUDE.md` "copy-paste over deps when code is small and stable" rule.

### Deterministic IDs for Relations

Use Elixir's built-in `:crypto.hash(:sha256, key)` to derive stable binary_id seeds for persona records that need stable primary keys across re-seeds:

```elixir
# Derives a stable UUID v4-shaped ID from a known string key.
# Works with :binary_id / UUID primary keys.
defp deterministic_uuid(key) do
  <<a::48, _::4, b::12, _::2, c::62>> = :crypto.hash(:sha256, key)
  <<a::48, 4::4, b::12, 2::2, c::62>>
  |> Base.encode16(case: :lower)
  |> then(fn hex ->
    [
      binary_part(hex, 0, 8),
      binary_part(hex, 8, 4),
      binary_part(hex, 12, 4),
      binary_part(hex, 16, 4),
      binary_part(hex, 20, 12)
    ]
    |> Enum.join("-")
  end)
end
```

This produces a repeatable UUID for the same input string across re-seeds, which is important for organization memberships and invitation rows that foreign-key to persona user IDs.

---

## (2) Argon2id Hashing — Cost Parameters for Bulk Seed Inserts

### The Problem

The default Argon2id parameters (production-grade, 200–500ms per hash) make seeding 4–6 users with passwords take 1–3 seconds — acceptable for a one-time seed but worth being explicit about.

### Solution — Already Exists, Just Document It

`test/example/config/test.exs` already has:

```elixir
config :argon2_elixir, t_cost: 1, m_cost: 8
```

The `seeds.exs` runs in `MIX_ENV=dev` (via `mix setup` / `mix run priv/repo/seeds.exs`), **not** `MIX_ENV=test`. The test-only fast-hash config does not apply.

**Recommendation:** Add a `MIX_ENV=dev`-scoped config block:

```elixir
# In test/example/config/dev.exs — seeds section:
# Lower Argon2 cost for deterministic seed passwords.
# Still slower than t_cost:1 / m_cost:8 (test) but faster than production defaults.
# Demo seed passwords are public ("DemoPassword123!" printed in the README), so
# production-grade hashing on them is not a security concern.
config :argon2_elixir, t_cost: 2, m_cost: 12
```

`t_cost: 2, m_cost: 12` produces a valid Argon2id hash in ~20–50ms on a modern laptop instead of 200–500ms. Seeding 6 users then takes < 300ms total. This is the right tradeoff: significantly faster than production defaults, not trivially breakable for brute force, and clearly a dev-only override.

**Do not** use `t_cost: 1, m_cost: 8` (test-level) in dev — it would produce an obviously different hash cadence visible to performance-sensitive adopters looking at the seed script as reference code.

---

## (3) TOTP Seeding — Fully Deterministic, No Workaround Needed

### Mechanism

`NimbleTOTP.secret/0` generates a random binary. For seeded personas, use a **fixed known binary** instead:

```elixir
# Deterministic TOTP secret for the "admin persona with MFA" demo user.
# This secret is intentionally public — it is embedded in the README
# to let evaluators scan the QR code.
@admin_totp_raw_secret :crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)
```

`NimbleTOTP.verification_code(@admin_totp_raw_secret)` still produces the correct time-window code. `Sigra.Testing.generate_totp_code/1` already wraps this (confirmed in `lib/sigra/testing.ex`).

The TOTP enrollment flow in the example app stores `raw_secret` through `Sigra.MFA.confirm_enrollment/5`. For seeding, bypass the enrollment ceremony and insert directly via the `UserMfaCredential` changeset:

```elixir
Example.Repo.insert!(%Example.Accounts.UserMfaCredential{
  user_id: admin_user.id,
  type: "totp",
  encrypted_secret: @admin_totp_raw_secret,
  last_verified_step: 0,
  failed_attempts: 0,
  enabled_at: DateTime.utc_now()
}, on_conflict: :nothing, conflict_target: [:user_id, :type])
```

`cloak_ecto` encrypts `encrypted_secret` transparently on insert. No extra steps needed.

**Confidence: HIGH.** The TOTP seeding path is straightforward — NimbleTOTP is a pure computation library; the only I/O is the Ecto insert.

---

## (4) Passkeys — Cannot Be Seeded Without a Real Authenticator Ceremony. Recommended Workaround: Showcase Via Playwright CDP Fixture, Not seeds.exs

### Why Passkey Rows Cannot Be Inserted Directly Into seeds.exs

A `UserPasskey` row requires:

1. A real WebAuthn COSE public key (EC P-256 or RSA, encoded via Erlang ETF per `Sigra.Passkeys.CoseKey`).
2. A `credential_id` that was issued by a real (or virtual) authenticator during the `Wax.register_passkey/2` ceremony.
3. A `sign_count` starting at 0.

The `public_key` field stores a COSE key map (`%{1 => 2, 3 => -7, -1 => 3, -2 => <<x>>, -3 => <<y>>}` for P-256) serialized with `:erlang.term_to_binary/1` and encrypted with `cloak_ecto`. You can fabricate a valid P-256 key pair using Erlang's `:crypto.generate_key(:ecdh, :prime256v1)` — this does produce a real cryptographically valid key — but `Wax` would never have seen this key during a ceremony. The passkey persona cannot be used to actually authenticate (there is no matching private key in a real authenticator) and the insert bypasses `wax_`'s ceremony verification.

**This is acceptable for a read-only demo persona** (an evaluator browses to `/users/settings/mfa` and sees "1 passkey enrolled: MacBook Pro Touch ID") but it **does not demonstrate a working passkey login flow**.

### The Right Workaround: CDP Virtual Authenticator in a Playwright Fixture Spec

The existing `passkey-login.spec.ts` already demonstrates the correct pattern (confirmed in source):

```typescript
const { authenticatorId } = await client.send("WebAuthn.addVirtualAuthenticator", {
  options: { protocol: "ctap2", transport: "internal", ... }
});
```

Playwright's Chrome DevTools Protocol virtual authenticator:
- Completes a real WebAuthn ceremony (including Wax verification).
- Works in headless Chromium (confirmed in existing CI lanes via `passkeys-hooks.spec.ts`, `passkey-options.spec.ts`, `passkey-login.spec.ts`).
- Produces a real `credential_id` and public key that Wax trusts.

**Recommendation:**

1. In `seeds.exs`: seed the "passkey persona" user with a password and confirmed account. Leave the `user_passkeys` table empty for this persona.
2. Add a `demo-showcase.spec.ts` Playwright spec that:
   a. Logs in as the passkey persona.
   b. Adds a virtual authenticator via CDP.
   c. Enrolls a passkey through the real `/users/settings/mfa/passkeys` flow.
   d. Captures a screenshot of the passkey-enrolled settings page.
3. Document in the README "try it locally" section that the passkey persona requires running the Playwright setup script once after `mix setup`.

This is the only correct and honest approach. Do not fabricate COSE key bytes in `seeds.exs` — it creates a misleading persona that looks enrolled but cannot authenticate.

### Fabricated Demo Key (Read-Only Display Only — Acceptable With Caveat)

If the roadmap decides a "pre-enrolled passkey" display persona is valuable for pure screenshot purposes (showing the passkeys list UI without interactive flows), fabricating a P-256 key is technically feasible:

```elixir
# WARNING: fabricated key — cannot be used for actual passkey authentication.
# Only use for displaying the "enrolled passkeys" list in demo screenshots.
{public_key_bin, _private_key} = :crypto.generate_key(:ecdh, :prime256v1)

cose_key = %{
  1 => 2,    # kty: EC2
  3 => -7,   # alg: ES256
  -1 => 1,   # crv: P-256
  -2 => binary_part(public_key_bin, 1, 32),   # x coordinate
  -3 => binary_part(public_key_bin, 33, 32)   # y coordinate
}

serialized = :erlang.term_to_binary(cose_key)
```

**Caveat:** Insert with `Example.Accounts.UserPasskey.create_changeset/2` and `on_conflict: :nothing`. This persona row will show up in `/users/settings/mfa` and admin pages but passkey authentication will fail. Flag this in the seeds with a comment. The Playwright demo spec approach (above) is strongly preferred.

---

## (5) Screenshot Capture — Reuse Existing Playwright Infrastructure

### No New Tools Needed

The existing Playwright setup already has everything required for README screenshots:

- `captureAdminCheckpoint/3` in `priv/playwright/helpers/adminArtifacts.ts` captures named full-page screenshots and attaches them to the Playwright HTML report.
- `page.screenshot({ path, fullPage: true })` is the underlying primitive.
- The `admin-checkpoints-chromium` project already runs a dedicated screenshot capture lane.

**Add a `demo-screenshots.spec.ts`** that reuses the same `captureAdminCheckpoint` helper. No new npm packages needed — `@playwright/test` is already pinned at `^1.48.0`.

### Screenshot Spec Strategy

```typescript
// priv/playwright/tests/demo-screenshots.spec.ts
// Captures README-quality screenshots of seeded persona states.
// Runs in: chromium project (desktop 1280×720).
// Prerequisites: `mix setup` (seeds must be populated).

import { test, expect } from '@playwright/test';
import { captureAdminCheckpoint } from '../helpers/adminArtifacts';

test('demo showcase screenshots', async ({ page, request }, testInfo) => {
  // Login as admin@demo.sigra.example / DemoPassword123!
  // Navigate to key pages per persona.
  // captureAdminCheckpoint(page, testInfo, { name: "admin-dashboard", prefix: "demo" })
  // ...
});
```

Screenshots land under `playwright-report/` and can be copied into `guides/screenshots/` for the README.

**Do not add a separate screenshot tool** (e.g., `puppeteer`, `screenshot-api`, `playwright-screenshot`). The existing CDP + Playwright infrastructure is purpose-built for this.

### Playwright Version Pin

`@playwright/test ^1.48.0` is already in `package.json`. No version bump needed for screenshot capabilities — `page.screenshot({ fullPage: true })` and `testInfo.attach()` have been stable since Playwright 1.10+. Verify Playwright is current (latest as of 2026-05 is 1.50.x) when running `npm install` but no forced upgrade is needed to unlock new functionality.

---

## (6) `mix setup` / One-Command Spin-Up

### What Already Exists

`test/example/mix.exs` aliases are already correct:

```elixir
setup: ["deps.get", "ecto.setup"],
"ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
"ecto.reset": ["ecto.drop", "ecto.setup"],
```

`mix setup && mix phx.server` is already the correct one-command spin-up once `seeds.exs` is populated.

### What Needs Adding

1. **Populate `seeds.exs`.** This is the entire gap.
2. **Add `config :argon2_elixir, t_cost: 2, m_cost: 12`** to `test/example/config/dev.exs` so `mix setup` completes in < 1 second instead of 3–5 seconds.
3. **Document the spin-up sequence** in a `guides/introduction/demo-showcase.md` guide and in the README "Evaluating Sigra" section.

### Recommended README "Try It Locally" Sequence

```
git clone https://github.com/szTheory/sigra
cd sigra/test/example
mix setup          # installs deps, creates DB, migrates, seeds 6 personas
mix phx.server     # starts on http://localhost:4000
```

Optionally:
```
cd priv/playwright
npm install
npx playwright test tests/demo-screenshots.spec.ts  # generates README screenshots
```

Do not require Docker, `make`, or platform-specific tooling in the one-command path. The only prerequisite is a running Postgres at `localhost:5432` (already documented in `CLAUDE.md` and the `getting-started` guide).

---

## What Goes Into `test/example/mix.exs` for v1.31

```elixir
# NEW in v1.31 — dev-only seed support:
{:faker, "~> 0.18", only: :dev}
```

That is the entire dep delta. No changes to the root Sigra `mix.exs`.

---

## What Goes Into `test/example/config/dev.exs` for v1.31

```elixir
# Speed up Argon2 for deterministic seed inserts (dev only — seed passwords are public).
config :argon2_elixir, t_cost: 2, m_cost: 12
```

---

## What Goes into `test/example/priv/playwright/package.json` for v1.31

Nothing. All screenshot capture needed for README images is already provided by `@playwright/test ^1.48.0` and the existing `captureAdminCheckpoint` helper.

---

## Alternatives Considered

| Decision | Recommended | Alternative Rejected | Why |
|----------|-------------|----------------------|-----|
| Fake name generation | `faker ~> 0.18` in `test/example/mix.exs` | Hand-roll a persona list with hardcoded strings | Static strings are fine for fixed personas but `faker` prevents the seed file from looking like a unit test fixture. Richer display names improve screenshot quality. |
| Seed idempotency | Hand-roll find-or-create (~30 lines) | `ex_machina ~> 2.8` | ExMachina is a test-factory lib, not a seed lib. It doesn't implement find-or-create or survive re-runs idempotently in the demo-persona use case. |
| Screenshot capture | Extend existing Playwright `captureAdminCheckpoint` | New tool (puppeteer, screenshot-api, etc.) | Playwright is already present, the helper already exists, CI lanes already configured. Adding a second tool for screenshots would be redundant. |
| Passkey seeding | CDP virtual authenticator in Playwright fixture | Fabricate COSE key in seeds.exs | Fabricated keys cannot authenticate — they would deceive evaluators about passkey functionality. CDP produces real verifiable credentials. |
| Argon2 cost in dev seeds | `t_cost: 2, m_cost: 12` in `config/dev.exs` | Default production cost | Default cost makes `mix setup` take 3–5s to hash 6 passwords. This is disproportionately slow for a one-command demo spin-up. |
| Deterministic user IDs | `:crypto.hash(:sha256, key)` → UUID | Auto-generated UUIDs | Auto-generated IDs change on every re-seed, breaking organization memberships and invitation foreign keys on subsequent runs. |

---

## What Stays Explicitly OUT of the Stack

Per milestone non-goals (`PROJECT.md`, `MILESTONE-ARC.md`):

- **No generic seeding framework** (ExMachina, `plant`, `seed_factory`). The persona set is fixed; a framework adds complexity for no gain.
- **No separate demo repo.** Extend `test/example/` directly. Phase 114 already paid the nested-app drift cost.
- **No marketing site / component library.** Seeds must not pull in frontend build tooling.
- **No seeding of host-app domain data** beyond what makes auth/account features legible (the single "Saas Inc." organization per the admin persona is the limit).
- **No `Argon2.hash_pwd_salt/2` called with `t_cost: 1, m_cost: 8` (test-level) in dev.** Use `t_cost: 2, m_cost: 12` — it's clearly a dev override, not a test override, and doesn't create "why is dev hashing so fast?" confusion for adopters reading the seed code.
- **No COSE key fabrication as a primary passkey persona story.** Fabricated keys are misleading. Use CDP-enrolled credentials for any interactive passkey demo; fabricated keys are only acceptable for pure-display personas flagged with a comment.
- **No changes to the Sigra library `mix.exs`** — faker and any other seed-only deps belong in `test/example/mix.exs` under `only: :dev`.

---

## Sources

- `test/example/mix.exs` — existing aliases + deps (HIGH confidence, repo-verified 2026-05-29)
- `test/example/priv/repo/seeds.exs` — confirmed empty (HIGH confidence, repo-verified 2026-05-29)
- `test/example/priv/playwright/playwright.config.ts` — screenshot infrastructure, CDP passkey tests (HIGH confidence, repo-verified 2026-05-29)
- `test/example/priv/playwright/helpers/adminArtifacts.ts` — `captureAdminCheckpoint` helper (HIGH confidence, repo-verified 2026-05-29)
- `test/example/priv/playwright/tests/passkey-login.spec.ts` — CDP virtual authenticator pattern (HIGH confidence, repo-verified 2026-05-29)
- `lib/sigra/passkeys/cose_key.ex` — COSE key serialization via ETF + cloak_ecto (HIGH confidence, repo-verified)
- `lib/sigra/mfa.ex`, `lib/sigra/testing.ex` — NimbleTOTP secret generation + `generate_totp_code/1` (HIGH confidence, repo-verified)
- `lib/sigra/crypto.ex`, `lib/sigra/hashers/argon2.ex` — Argon2id wrapper, configurable via `:argon2_elixir` app env (HIGH confidence, repo-verified)
- `test/example/config/test.exs` — confirms `t_cost: 1, m_cost: 8` is test-env-only (HIGH confidence, repo-verified)
- [hex.pm/packages/faker](https://hex.pm/packages/faker) — v0.18.0, Feb 2024, 72M downloads, pure Elixir (HIGH confidence, verified 2026-05-29)
- [hex.pm/packages/ex_machina](https://hex.pm/packages/ex_machina) — v2.8.0, Jun 2024, beam-community (HIGH confidence, verified 2026-05-29; rejected for this use case)
- [bitcrowd.dev/idempotent-seeds-in-elixir](https://bitcrowd.dev/idempotent-seeds-in-elixir/) — upsert with deterministic IDs pattern (MEDIUM confidence, community blog post, patterns verified against Ecto docs)
- [elixirforum.com/t/patterns-for-making-seeds-idempotent](https://elixirforum.com/t/patterns-for-making-seeds-idempotent/58299) — find-or-create community consensus (MEDIUM confidence, multiple responders agree)
- [playwright.dev/docs/screenshots](https://playwright.dev/docs/screenshots) — `page.screenshot` API stable since 1.x (HIGH confidence, official docs)

---
*Stack research for: Sigra v1.31 DEMO-SHOWCASE (seed-rich evaluator demo showcase)*
*Researched: 2026-05-29*
