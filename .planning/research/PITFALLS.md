# Pitfalls Research

**Domain:** Seed-rich evaluator demo for a security-sensitive auth library — extending a dual-role CI fixture
**Researched:** 2026-05-29
**Confidence:** HIGH — grounded in Sigra's actual codebase, Phase 114 retro, v1.29 SUITE-INTEGRATION retro, CI yml, test/example structure, and security posture documented in PROJECT.md and CLAUDE.md

---

## Priority Note

This document is organized by severity within domain. **Security pitfalls lead** because Sigra is an auth library: a demo that weakens its own security model or leaks bad credential patterns would undermine the entire trust surface the library is trying to sell. CI-determinism pitfalls come second because the fixture role of `test/example/` must survive unchanged.

---

## Critical Pitfalls — Security

### Pitfall S-1: Seeded demo passwords that look usable and are publicly committed

**What goes wrong:**
`seeds.exs` commits credentials like `"admin123"`, `"password"`, `"Demo@1234"`, or any password that an evaluator might copy-paste into a real project or that maps to a known password list. Because `seeds.exs` runs in `MIX_ENV=dev` against the same codebase and config path an adopter would use, there is no environment gate preventing those credentials from reaching a production-adjacent clone. The Playwright specs that exercise seeded data will also embed these credentials in their source as string literals, where they persist in git history forever.

**Why it happens:**
Demo seeds prioritize "easy to log in" over "credible security posture." The person writing the seed just needs to remember the password to click through the demo. The credentials feel throwaway because they're in `test/`. But `seeds.exs` is not test code — it runs in dev, appears in `git log`, and is publicly visible on GitHub. Sigra's value proposition is auth security; a committed weak credential is a direct contradiction.

**How to avoid:**
Use a `DEMO_ADMIN_PASSWORD` environment variable with a fallback to a strong random placeholder that is printed to stdout at seed time: `System.get_env("DEMO_ADMIN_PASSWORD") || raise "Set DEMO_ADMIN_PASSWORD"`. Alternatively, generate random passwords per seed run, print them to stdout in a labeled block ("=== DEMO CREDENTIALS ==="), and never commit a hardcoded literal. Add a `.credo.exs` or module-level guard that rejects any password shorter than 12 characters passed directly to Argon2. Document in `seeds.exs` header comments exactly which credential pattern is intentional and why it does not weaken the library's security posture.

**Warning signs:**
Any password in `seeds.exs` that contains `"password"`, `"admin"`, `"demo"`, `"test"`, or `"123"` as a substring. Any Playwright spec that hardcodes a seed credential literal. Any credential that appears in both `seeds.exs` and a Playwright `page.fill()` call without going through an env var or a printed-at-runtime value.

**Phase to address:**
Seeds phase (Phase 141 or the first dedicated seed phase). The credential strategy must be decided and documented before any persona is inserted. Playwright exercises of seeded data inherit this decision in the same phase.

---

### Pitfall S-2: Demo disabling enumeration prevention or rate limiting "to make it easy to log in"

**What goes wrong:**
The evaluator wants to try logging in as multiple personas quickly. The seed script or demo config silently sets `enumeration_prevention: false` or uses a Hammer no-op backend to avoid lockout during demos. Those config values live in `dev.exs`, which is the same file used for real development. An adopter who clones and starts building from the example app inherits the weakened config. Even if the adopter doesn't use `test/example/` as a template, the documentation screenshots and README "try it locally" lane now show a demo that doesn't match production behavior — an evaluator who sees instant error messages on bad passwords (enumeration leak) or no lockout after 10 wrong guesses will draw incorrect conclusions about library behavior.

**Why it happens:**
Rate limiting and enumeration delays are friction during demos. A presenter who's demonstrating persona switching doesn't want to wait 200ms per hash or get locked out after testing the wrong-password path. The fix feels harmless because it's in `dev.exs`, not `prod.exs`.

**How to avoid:**
Never touch `enumeration_prevention` or Hammer backends in the demo path. The demo must demonstrate exactly what adopters will ship — that means showing the same timing behavior, the same non-enumerable error messages, and the same lockout UX. The "locked account" persona demonstrates lockout state without requiring the evaluator to trigger it live. If Argon2 timing is the concern, that is addressed separately (see Pitfall C-1 on seed cost). The README evaluator lane should explicitly call out that the demo uses production-grade security settings — this is a feature, not a bug.

**Warning signs:**
Any diff in `dev.exs` touching `enumeration_prevention`, `Hammer`, rate-limit config, or Argon2 parameters that is not already present in the codebase today. Any seed-setup script that modifies `Application` config at runtime to disable security checks.

**Phase to address:**
Seeds phase. Add a test-time assertion (or a `mix sigra.doctor`-style check) that dev config preserves the expected enumeration/rate-limit settings. This is a success criterion, not just a guideline.

---

### Pitfall S-3: Demo personas using real-looking PII — real email patterns, real names, real phone numbers

**What goes wrong:**
Seed personas use `admin@acme.com`, `john.smith@techcorp.io`, or phone numbers that map to real people or real organizations. These appear in screenshot captures committed to the repo, in HTML snapshots, and in Playwright baselines. If the screenshots are published (the repo has a `playwright-github-pages.yml` CI job that publishes to GitHub Pages), the PII propagates to a public URL.

**Why it happens:**
Realistic-looking names make demos feel polished. The persona set is invented but modeled on real-world naming conventions. The people writing the seeds don't expect anyone to mistake `john.smith@techcorp.io` for a real person.

**How to avoid:**
Use obviously fictional domains: `@sigra.example`, `@example.test`, `@acme.example`. Use names that signal fiction: personas named after their auth role/state ("Alex Admin", "Ursula Unconfirmed", "Otto OAuth", "Petra Passkey", "Lena Locked") make the seed purpose self-documenting and are impossible to mistake for real users. Avoid any email pattern that resolves to a real domain. Add a CI lint that rejects any email in `seeds.exs` that doesn't end in `.example` or `.test` (RFC 2606 reserved).

**Warning signs:**
Any email in seeds that ends in `.com`, `.io`, `.org`, or any non-reserved TLD. Names that sound like real people rather than role labels. Phone numbers of any kind.

**Phase to address:**
Seeds phase. The persona naming convention should be decided in the discuss/planning stage, not corrected after screenshots are committed.

---

### Pitfall S-4: Demo-only OAuth credentials or API keys committed to the repository

**What goes wrong:**
To make the OAuth persona ("Otto OAuth") work click-through in the demo, someone adds a real Google/GitHub OAuth client ID and secret to `dev.exs` or a `.env` file that gets committed. Even as a demo-only credential scoped to `localhost:4000`, this is a committed secret. GitHub secret-scanning will flag it; security-conscious evaluators will notice; and the credential may be rotated without the repo being updated, breaking the demo silently.

**Why it happens:**
The OAuth flow genuinely requires valid credentials to complete the browser callback cycle. The person setting up the demo doesn't want to document "go get your own OAuth app" as a setup step. They add the demo creds "just for the example app."

**How to avoid:**
OAuth persona demonstration should not require a live OAuth callback. Use the existing Assent mock path or a stub identity fixture injected directly via the `user_identities` table in seeds — show that the user *has* an OAuth-linked identity without requiring the evaluator to complete an OAuth dance. If a live OAuth demo is ever required, it must use environment variables (`GOOGLE_CLIENT_ID`, `GITHUB_CLIENT_ID`) with no fallback defaults in tracked files, and the README must document that OAuth live flow requires a personal OAuth app. The `dev.exs` in the repo today already has no OAuth config — keep it that way.

**Warning signs:**
Any string beginning with `GOCSPX-`, `ghp_`, `sk-`, or any pattern matching an OAuth or API key format in `seeds.exs`, `dev.exs`, or `config.exs`. Any new entry added to `.gitignore` that suggests a committed secret was discovered after the fact.

**Phase to address:**
Seeds phase. The OAuth persona implementation strategy (stub identity vs. live callback) must be settled before any seed code is written. Stub injection is the default; live OAuth is an explicit opt-in requiring env vars only.

---

### Pitfall S-5: Demo weakening the library's security model to show "all features" simultaneously on one account

**What goes wrong:**
To demonstrate every auth feature on a single admin persona, the seed creates an account that has MFA enabled, a passkey registered, an OAuth identity, an API token, and an active session simultaneously — then the README shows how to log in with that account's known password, bypassing MFA by using a hardcoded TOTP secret embedded in seeds. The TOTP secret appears in `seeds.exs` in plaintext. Once extracted, it allows anyone with the seed file to generate valid TOTP codes forever for that account.

**Why it happens:**
A complete demo persona is more impressive than a partial one. The TOTP secret must be known to demonstrate the MFA challenge flow. It feels like demo infrastructure, not a security surface.

**How to avoid:**
TOTP secrets must be generated randomly at seed time (using `NimbleTOTP.otpauth_uri/3` with a fresh `NimbleTOTP.secret/0`) and printed to stdout for the evaluator. Never embed a known TOTP secret in tracked code. The Playwright spec can read the TOTP secret from the printed output or from a dedicated env var injected at test time — the existing `golden-path.spec.ts` already does this correctly by reading the secret from the QR-code DOM element, not from a hardcoded seed value. The demo cheat-sheet (README evaluator lane) should instruct the evaluator to run seeds first, then copy the printed TOTP setup URI into any authenticator app — not to paste a hardcoded secret.

**Warning signs:**
Any `NimbleTOTP.secret/0` call result stored as a literal string in `seeds.exs`. Any base32-encoded string that looks like a TOTP secret appearing in git history. Any Playwright spec that hardcodes a TOTP secret as a test-time constant rather than reading it from the running application.

**Phase to address:**
Seeds phase, with explicit verification during the Playwright-extension phase that TOTP codes are being generated from a runtime secret, not a committed one.

---

## Critical Pitfalls — CI Determinism

### Pitfall C-1: Argon2id hashing at full cost in seeds makes CI time budgets explode

**What goes wrong:**
`seeds.exs` creates 5-6 persona users, each requiring a full Argon2id hash. In production and dev, Argon2id is intentionally configured at ~200-500ms per hash (OWASP recommendation). 6 personas at 300ms = 1.8 seconds of pure hashing. If the Playwright CI job runs seeds before booting the app (or re-seeds on each run), and CI is running this on an underpowered GitHub Actions runner, this blows up. Worse, the `example_http_smoke` and `example_playwright_smoke` jobs today run in `MIX_ENV=dev`, not `MIX_ENV=test`. The `config :argon2_elixir, t_cost: 1, m_cost: 8` override only exists in `test.exs` — it does NOT apply to `MIX_ENV=dev`. Seeds in dev pay full Argon2 cost.

**Why it happens:**
The `t_cost: 1, m_cost: 8` override in `test.exs` is well-known and correctly applied to ExUnit tests. But `seeds.exs` runs via `mix run priv/repo/seeds.exs` or `mix setup`, which is a `dev` operation — and the example app's `dev.exs` has no Argon2 cost reduction. The person writing seeds knows about the test config override but doesn't realize it doesn't cover the seed path.

**How to avoid:**
Two options, both valid; one must be chosen and documented:
Option A — fast-hash seeds via Mix env awareness: add `Application.put_env(:argon2_elixir, :t_cost, 1); Application.put_env(:argon2_elixir, :m_cost, 8)` at the top of `seeds.exs`, with a comment explaining why. This is the lowest-friction fix.
Option B — generate hashed password once per run and reuse it across all personas (all personas share one pre-hashed password, distinct per seed run). This reduces hashing to one operation regardless of persona count.
In both cases, add a `mix setup` step to the CI seed job that is explicitly timed, with a CI budget ceiling documented in a comment.

**Warning signs:**
CI Playwright job wall-clock time increases by more than 3 seconds after seeds are added. Any Argon2 timing log appearing in `mix run priv/repo/seeds.exs` output showing >100ms per hash in dev.

**Phase to address:**
Seeds phase. The hash-cost strategy for seeds must be in the requirements, not discovered post-implementation when CI slows.

---

### Pitfall C-2: Seeds making ExUnit tests non-deterministic by polluting the test database

**What goes wrong:**
The example app's ExUnit tests (`example_unit_smoke` CI job) run with `MIX_ENV=test` using `Ecto.Adapters.SQL.Sandbox`. The test database is separate from the dev database. Seeds run against the dev database. This sounds safe — but the moment someone adds a CI step that runs `mix ecto.seed` (or `mix setup`) inside a test-env CI job, seeded rows leak into the test database and cause test failures when fixtures try to create rows that violate unique constraints (e.g., persona email `admin@sigra.example` already exists).

**Why it happens:**
A developer runs `mix setup` locally to populate the dev DB, then runs `mix test` — this works fine because they're different databases. But a CI author refactoring the setup job runs `mix ecto.seed` before `mix test` in the same pipeline step, or forgets to scope it to `MIX_ENV=dev`, and the test sandbox gets contaminated.

**How to avoid:**
Seeds must never run in the `example_unit_smoke` CI job. The `seeds.exs` file should assert at its top that `Mix.env() == :dev`, raising a clear error if invoked in test: `if Mix.env() != :dev, do: raise "seeds.exs must only run in MIX_ENV=dev"`. The CI yml must have no `mix run priv/repo/seeds.exs` or `mix setup` in any step that sets `MIX_ENV: test`. Document this constraint in a comment in `ci.yml` at the seeds step.

**Warning signs:**
Any `mix setup` or `mix ecto.seed` call in a CI job that also sets `MIX_ENV: test`. Test failures on `users` unique-index violations in the `example_unit_smoke` CI job after the seeds phase lands. Any `seeds.exs` line that calls `Example.Repo.insert!` without an environment guard.

**Phase to address:**
Seeds phase. The env guard belongs in `seeds.exs` itself, not just in CI config — defense-in-depth.

---

### Pitfall C-3: Playwright specs coupling to seeded persona data that changes across seed runs

**What goes wrong:**
Playwright specs are extended to exercise seeded data. A spec navigates to `/admin/users` and asserts `expect(page).toContainText("Alex Admin")`. Later, someone renames the admin persona to "Admin User" for a better README screenshot. The Playwright spec now fails on CI. Because the spec was added in the same phase as the seed, the coupling isn't obvious — it looks like a flaky test rather than a seed-data contract violation.

**Why it happens:**
Playwright specs are written to test what the developer sees on their screen at the time. The demo persona names are visible and concrete. Asserting on them feels natural and stable — they're seed data that doesn't change between test runs. Until someone changes the seed.

**How to avoid:**
Playwright specs that exercise seeded data should assert on stable structural properties, not persona display names or email addresses. Use `data-testid` attributes on key demo elements (the admin user list, the locked-account badge, the MFA-enabled indicator) rather than text content. When text assertions are necessary, use role labels that are locked to the auth state (e.g., assert "Locked" status badge exists, not that "Lena Locked" appears in a specific table row). The persona names should be defined in a single constant in `seeds.exs` and also exported to a JSON fixture file that Playwright reads — so a name change requires a single-source update, not a grep-across-two-files.

**Warning signs:**
Any Playwright `toContainText()` or `getByText()` call whose argument matches a persona name or email from seeds. Any spec that would silently pass if the seeded data were absent (i.e., it asserts on something that could also exist from a freshly-registered test user).

**Phase to address:**
Playwright-extension phase (the phase that extends golden-path to exercise seeded data). This is distinct from the seeds phase — the coupling risk only materializes when Playwright is extended, so the prevention belongs in that phase's success criteria.

---

### Pitfall C-4: Non-idempotent seeds causing CI setup failures on re-runs

**What goes wrong:**
The CI Playwright job does not start with a fresh database — it runs `mix ecto.create && mix ecto.migrate` then boots the server, and seeds would need to be run as an additional step. If seeds are not idempotent, a re-run of a failed CI job (or a local developer who ran seeds before and runs them again) causes `Ecto.ConstraintError` on the second run. The demo breaks, the developer thinks something is wrong with their setup, and debugging takes longer than the seeds took to write.

**Why it happens:**
`seeds.exs` uses `Repo.insert!` for convenience. The first run works. The second run fails on the unique index on `email`. The developer just never ran seeds twice locally before pushing.

**How to avoid:**
Use `Repo.insert` with `on_conflict: :nothing, conflict_target: :email` for every persona upsert. Or use a `get_or_create` pattern: `Repo.get_by(User, email: email) || Repo.insert!(%User{...})`. The idempotency contract should be stated explicitly in `seeds.exs` header comments: "Running this script multiple times is safe. Existing personas are skipped." The README evaluator lane should document that `mix setup` (which includes seeds) is re-runnable.

**Warning signs:**
Any `Repo.insert!` call in `seeds.exs` without an upsert qualifier or existence check. Any CI job that drops and recreates the dev database before seeding (drops the first run's data, which is correct, but documents that the CI assumption is "always fresh" — a fragile assumption for local dev).

**Phase to address:**
Seeds phase. Idempotency is a hard requirement, not an optimization. It must appear in the success criteria.

---

## Moderate Pitfalls — Maintenance Drift

### Pitfall M-1: Seeds going stale as auth features evolve — the silent demo rot problem

**What goes wrong:**
Phase 141 seeds create a `user_identities` row for the OAuth persona using the v1.29 schema shape. In a future milestone, the `user_identities` table gains a new non-nullable column. The migration adds it with a default, so existing rows are fine. But seeds still don't set it, so the OAuth persona looks subtly wrong in the UI (empty field, missing badge). No test fails — seeds run without error because the DB default fills the gap. The demo now misrepresents the OAuth flow in a way that evaluators see but tests don't catch.

**Why it happens:**
Seeds are not schema-tracked the way migrations are. There is no compile-time coupling between a seeds persona struct and the schema fields it should populate. The schema can evolve without touching `seeds.exs`, and the drift is invisible until someone manually walks the demo.

**How to avoid:**
Add a `mix test` suite (or fold into the existing `example_unit_smoke` lane) that runs the seed logic in a transaction, rolls it back, and asserts that each persona has the expected fields populated: MFA-enabled persona has `mfa_enabled: true`, locked persona has `locked_at` non-nil, OAuth persona has at least one `user_identity`, passkey persona has at least one `user_passkey`. These assertions are structural (is the relationship present?), not content-specific (what's the passkey credential blob?). This gives seeds a contract test that fails when schema evolution breaks persona completeness.

**Warning signs:**
Any migration adding a non-nullable column to a table seeded by `seeds.exs` without a corresponding `seeds.exs` update. Any new Sigra feature that adds a user-visible status flag (e.g., `sso_only_at`, `deletion_scheduled_at`) where the demo persona set doesn't include a persona demonstrating that state.

**Phase to address:**
Seeds phase (write the contract test alongside the seeds). Every future migration phase that touches seeded tables should include seeds-contract update as a success criterion.

---

### Pitfall M-2: Screenshots rotting — committed PNG baselines that diverge from the running app

**What goes wrong:**
The README evaluator lane includes screenshots. Playwright generates snapshot baselines at `*-snapshots/`. These are committed to the repo. When the UI changes (a LiveView template is updated, a CSS class moves a button, Phoenix 1.8's dark mode is added), the screenshot baselines no longer match the running app. The README shows a stale UI. Playwright's visual regression tests start failing in CI on unrelated PRs, and the fix requires a full re-capture pass.

**Why it happens:**
The existing Playwright config already has visual regression infrastructure (`toHaveScreenshot` with `pathTemplate`). Adding a few "evaluator showcase" screenshots feels natural. But screenshot baselines are notoriously brittle — OS, browser engine version, font rendering, and even locale can cause pixel-level differences. The existing config already acknowledges this by omitting OS suffixes from snapshot paths to reduce per-platform churn.

**How to avoid:**
Two distinct categories: (a) **README screenshots** — these are manually curated PNG files committed to `docs/` or `priv/static/images/`, not Playwright visual regression baselines. They're updated intentionally, not automatically. The README uses these. (b) **Playwright structural assertions** — these use `toBeVisible()`, `toContainText()`, structural DOM checks, and `data-testid` attributes, not `toHaveScreenshot()`. Visual regression baselines for the demo should only be added if the checkpoint lane is specifically extended to cover demo states, and they should follow the existing `admin-checkpoints` discipline (explicitly named project, reviewer artifact, `retain-on-failure` video).

**Warning signs:**
Any `toHaveScreenshot()` call in new Playwright specs that exercises seeded demo data without being scoped to a dedicated checkpoint project. Any committed PNG in `*-snapshots/` directories from a newly added spec that will be re-run on every CI pass.

**Phase to address:**
Playwright-extension phase. The distinction between "README screenshots" (static, manually updated) and "Playwright baselines" (automated, fragile) should be in the phase plan.

---

### Pitfall M-3: Nested-app drift — the Phase 114 lesson repeating itself

**What goes wrong:**
Phase 114 (EMAIL-RAILS milestone) already paid the cost of nested-app drift: the example app drifted from the Sigra library's contract because changes to the library's generated templates or config patterns were not reflected in `test/example/`. The drift was caught only at milestone audit. The v1.29 retro explicitly documents "Extend `test/example/` over new top-level `examples/`" as a reaffirmed decision. Adding a rich seeds layer and a README showcase lane creates new drift surfaces: the seeds persona set, the README screenshots, the Playwright fixture data.

**Why it happens:**
`test/example/` is a separate Mix project with its own `mix.exs`, `mix.lock`, and dependency pins. Library changes don't automatically propagate. When a milestone evolves the library schema (new migration), updates the installer templates, or adds a new auth state, the example app must be manually updated. Under time pressure, "I'll update the example app in the next phase" becomes a tracked debt that sometimes doesn't get paid.

**How to avoid:**
Every phase that touches Sigra library schema or installer templates must include an explicit `test/example/` update as a success criterion — not as a nice-to-have. The v1.29 pattern of running all CI lanes against `test/example/` after library changes (the `example_unit_smoke` and `example_playwright_smoke` jobs) is already the enforcement mechanism. The new risk is seeds: add a CI check that `seeds.exs` runs without errors after every migration (this is a step in the `example_http_smoke` or `example_playwright_smoke` job, immediately after `mix ecto.migrate`).

**Warning signs:**
Any library migration that adds a required field to a table without a corresponding `seeds.exs` update. Any new Sigra config key that `test/example/config/config.exs` doesn't define. A CI seeds step that is added but not gated on `mix ecto.migrate` completing successfully first.

**Phase to address:**
Seeds phase (establish the CI seeds step). Every subsequent phase that modifies the Sigra library schema or installer templates owns the `test/example/` update.

---

## Moderate Pitfalls — DX / Evaluator Experience

### Pitfall D-1: A demo that's impressive but doesn't exercise the rough edges — the "happy path only" demo trap

**What goes wrong:**
The demo spin-up shows registration, login, and MFA enrollment — the same flows covered by the existing `golden-path.spec.ts`. The evaluator persona set includes an "admin" and a "regular user" but not a "locked account" or "unconfirmed user." The README evaluator lane walks through the happy path only. An evaluator wondering "what happens when MFA fails?" or "how does account lockout look?" has no way to discover it from the demo. They conclude Sigra handles the basics but the rough edges are undocumented — the opposite of Sigra's core value proposition.

**Why it happens:**
Demo authors optimize for "impressive first impression." Failure states require setup (triggering lockout, leaving email unconfirmed, failing MFA). They feel awkward to show. The happy path is cleaner and faster.

**How to avoid:**
The persona set must include at minimum: (1) a locked account (demonstrates lockout state and admin unlock flow), (2) an unconfirmed user (demonstrates the confirmation-required gate), (3) an MFA-enrolled user (demonstrates challenge flow, not just enrollment), and (4) a user with a scheduled account deletion pending. The README evaluator lane must include a section for "What to try next" that links to each rough-edge persona and explains what to look for. The admin persona must have a multi-org membership so the org-switcher is visible. If any of these are missing at demo launch, the demo fails its own stated goal.

**Warning signs:**
A persona set where all accounts are in a "normal" authenticated state (confirmed, unlocked, MFA not enrolled or not challenged). A README that only shows the register→login flow. An evaluator who has read the README but cannot find where to see account lockout behavior without triggering it themselves.

**Phase to address:**
Seeds phase (persona requirements are part of the seed design). README phase (the evaluator lane must explicitly call out rough-edge personas).

---

### Pitfall D-2: Missing credentials cheat-sheet — evaluator types the wrong password and hits Argon2 timing repeatedly

**What goes wrong:**
Seeds are seeded, the app is running, the evaluator opens the README and navigates to `/users/log_in`. They don't know the password because seeds generated it randomly (or env-var-gated). They try a few guesses, hit Argon2's 300ms timing on each attempt, get locked out after 5 tries (rate limiter), and conclude "the demo doesn't work." The `locked_at` state on their test session now matches the "Lena Locked" persona — confusingly. They give up.

**Why it happens:**
The credentials are printed to stdout when seeds run, but the evaluator didn't notice or scrolled past the output. The README doesn't tell them where to find the credentials. The cheat-sheet is not co-located with the login form in the UI.

**How to avoid:**
After seeds run, print a clearly formatted credentials block to stdout and write it to a `.gitignored` file (e.g., `priv/repo/demo_credentials.txt`) that persists across the server session. Wire the dev landing page or a `/dev/demo` route that reads and displays this file in the browser. The README evaluator lane must say explicitly: "After `mix setup`, your credentials are in `priv/repo/demo_credentials.txt`." Do not require the evaluator to hunt through terminal output.

**Warning signs:**
A README evaluator lane that says "run `mix setup && mix phx.server`" but does not tell the evaluator where to find the generated passwords. Any seed run that prints credentials only to stdout without persisting them to a local file.

**Phase to address:**
Seeds phase. The credential-persistence mechanism must be part of the seeds implementation, not a documentation afterthought.

---

### Pitfall D-3: Spin-up that isn't actually one command on a clean machine

**What goes wrong:**
The README says "`mix setup && mix phx.server` → fully populated, clickable SaaS." In practice, on a fresh clone: (1) Postgres must be running locally, (2) the `DEMO_ADMIN_PASSWORD` env var must be set if that pattern is chosen, (3) Elixir/OTP version must match `.tool-versions`. None of these are `mix setup`. The evaluator gets a cryptic error because their Docker Postgres isn't running, or because they're on Elixir 1.16.

**Why it happens:**
"One command" is aspirational. The developer writing the README runs seeds dozens of times on their configured machine and loses track of what prerequisites exist. The `mix setup` alias in `mix.exs` runs `mix deps.get && mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs`, but it doesn't validate that Postgres is running first. The error from `Ecto.Adapters.PostgreSQL.Connection` is not obviously a "Postgres not running" error to a first-time evaluator.

**How to avoid:**
Add a pre-flight check in `seeds.exs` (or in a `mix setup` alias step) that pings Postgres and prints a friendly error if it's not available: "Cannot connect to PostgreSQL. Start a container with: docker run -d --name sigra-demo-postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:16-alpine". The CLAUDE.md already has this pattern for the test suite. The README evaluator lane must include: (1) prerequisites (Elixir 1.18+, Postgres), (2) Docker one-liner for Postgres, (3) the actual one-command setup, (4) expected output (what a successful seed run looks like). Verify the README steps work from a fresh `git clone` on a machine without prior Sigra deps cached — the existing install-smoke infrastructure is the model for this kind of clean-machine verification.

**Warning signs:**
A README evaluator lane that starts with `mix setup` without a prerequisites block. Any `seeds.exs` that raises `DBConnection.ConnectionError` without a human-readable message about Postgres. A "one command" README that requires more than one command plus prerequisites to actually work.

**Phase to address:**
README/evaluator-lane phase (whichever phase writes the "try it locally" documentation). The pre-flight check belongs in that phase.

---

## Minor Pitfalls — Scope Creep

### Pitfall SC-1: Generic seeding framework creep — building `Sigra.Seeds` instead of `seeds.exs`

**What goes wrong:**
Seeds are written, then someone notes they could be useful for other projects and proposes extracting a `Sigra.TestFixtures.Seeder` module or a `mix sigra.seed` task. The implementation grows from 80 lines to 300. The new module needs its own tests. The milestone scope doubles. The evaluator-facing value (a populated demo app) is unchanged.

**Why it happens:**
Engineers see patterns and want to abstract them. Seeding auth personas has real reuse potential. The extraction feels like good library hygiene. But the MILESTONE-ARC.md non-goals are explicit: "no generic seeding framework." The value is in the populated `test/example/`, not in a reusable seed API.

**How to avoid:**
Strictly scope seeds to `test/example/priv/repo/seeds.exs`. No new library module, no new Mix task beyond a `mix example.seed` alias in the example app's `mix.exs`. If reuse patterns emerge, document them in a comment in `seeds.exs` ("see SEED pattern doc") and defer extraction to a future milestone with a concrete adopter trigger. Any PR that adds a `lib/sigra/seeds*` module should be rejected at review.

**Warning signs:**
Any new file in `lib/sigra/` with "seed", "fixture", or "demo" in its name. Any new `mix` task in the library's `mix.exs` that isn't `mix run priv/repo/seeds.exs`. A seeds PR diff that touches library files (`lib/`) rather than only example-app files (`test/example/`).

**Phase to address:**
All phases. This is a scope-creep guardrail, not a phase-specific concern. It should be in the milestone non-goals and in the requirements document.

---

### Pitfall SC-2: Separate demo repo — re-opening the Phase 114 nested-app decision

**What goes wrong:**
Someone proposes "it would be cleaner to have a standalone `sigra_demo` repo so evaluators can clone just the demo without cloning the whole library." The proposal sounds reasonable. But Phase 114 already paid the cost of understanding why this creates drift. A separate repo has its own dep pins, its own CI, its own maintenance surface. When Sigra releases v1.32 with a new migration, the `sigra_demo` repo is now stale. The evaluator cloning the demo sees v1.31 behavior against a Sigra v1.32 backend and reports bugs that don't exist.

**Why it happens:**
Standalone repos feel professionally polished. "Clone this one repo and run it" is a cleaner pitch than "clone sigra and navigate to test/example". The Phase 114 lesson is not visible without reading the retro.

**How to avoid:**
The MILESTONE-ARC.md non-goal is explicit and grounded in real history: "not a separate standalone demo repo." The decision is already made. If someone proposes a separate repo, the answer is "Phase 114 paid this cost; see MILESTONE-ARC.md." The evaluator UX is addressed by making `mix setup && mix phx.server` work from the `test/example/` directory with clear README instructions pointing there.

**Warning signs:**
Any new repository created under `szTheory/` with "demo", "example", "starter", or "showcase" in its name. Any PR that creates a `standalone-demo/` or `examples/` directory at the Sigra repo root.

**Phase to address:**
All phases. This is a permanent non-goal documented in MILESTONE-ARC.md.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded seed passwords | Easy dev setup | Security anti-pattern in an auth library repo; leaks bad credential patterns to git history | Never |
| Single combined seed file > 200 lines | Simple to write once | Hard to maintain; persona additions require understanding full file | Only if personas are stable; extract to per-persona modules if > 5 personas |
| Seeds that use `Repo.insert!` without idempotency | Fast to write | Breaks on re-run; CI re-runs fail without full DB drop | Never for a re-runnable demo |
| Screenshots committed as Playwright baselines | Automated capture | Brittle; fails on minor UI changes; requires full re-capture pass | Only for explicitly curated checkpoint lane, not demo flows |
| Playwright specs asserting on persona names | Readable tests | Breaks when persona names change; seeds and specs become a coupled system | Never; use data-testid or structural assertions instead |
| README screenshots showing happy-path only | Fast to produce | Misrepresents library's rough-edge handling; evaluator misses the differentiation | Never for Sigra; rough-edge personas are the product |
| Skipping seeds env guard | Fewer lines in seeds.exs | Seeds can be invoked in test env; contaminates test DB on CI misconfiguration | Never |

---

## "Looks Done But Isn't" Checklist

- [ ] **Seeds**: Idempotency — does `mix run priv/repo/seeds.exs && mix run priv/repo/seeds.exs` succeed without constraint errors?
- [ ] **Seeds**: Argon2 cost — does the seeds step complete in under 5 seconds total in `MIX_ENV=dev` CI?
- [ ] **Seeds**: Env guard — does `seeds.exs` refuse to run in `MIX_ENV=test` with a clear error?
- [ ] **Seeds**: Credentials — are demo passwords generated at runtime (not committed literals), and persisted to a `.gitignored` file?
- [ ] **Seeds**: TOTP secrets — are all TOTP secrets generated at seed time via `NimbleTOTP.secret/0`, never committed as string literals?
- [ ] **Seeds**: Email domains — do all seed emails end in `.example` or `.test`?
- [ ] **Personas**: Rough-edge coverage — are locked, unconfirmed, MFA-enrolled (challengeable), and OAuth-linked personas all present?
- [ ] **Playwright**: Seeded-data specs — do all assertions use `data-testid` or structural checks, not hardcoded persona name strings?
- [ ] **Playwright**: No visual regressions added for demo states without a dedicated checkpoint project scoping
- [ ] **README**: Prerequisites block present (Elixir version, Postgres, Docker one-liner)?
- [ ] **README**: Credentials cheat-sheet — does the evaluator lane tell the evaluator exactly where to find the printed passwords?
- [ ] **README**: Rough-edge callouts — does the evaluator lane explicitly mention the locked, unconfirmed, and MFA-enrolled personas?
- [ ] **CI**: No `mix setup` or seeds step in any CI job with `MIX_ENV: test`
- [ ] **CI**: Seeds step is present in the `example_playwright_smoke` job (or a dedicated job) and runs after `mix ecto.migrate`
- [ ] **Security**: No OAuth client IDs, API keys, or TOTP secrets in tracked files
- [ ] **Scope**: No new files in `lib/sigra/` touching seeds/fixtures/demo

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| S-1: Committed weak passwords | Seeds phase (141+) | CI lint: no password literals matching known weak patterns; no `"password"` in seeds.exs git diff |
| S-2: Demo disabling enumeration/rate-limiting | Seeds phase | Assertion: `dev.exs` diff contains no changes to enumeration_prevention, Hammer config, or Argon2 parameters |
| S-3: Real-looking PII in seed personas | Seeds phase | CI lint or code review: all seed emails end in `.example` or `.test`; names use role labels |
| S-4: OAuth credentials committed | Seeds phase | GitHub secret-scanning + CI diff check: no OAuth key patterns in tracked files; `dev.exs` OAuth config stays absent |
| S-5: TOTP secret committed | Seeds phase | Assertion: `seeds.exs` calls `NimbleTOTP.secret/0` at runtime; no base32 literal matching TOTP pattern in git |
| C-1: Argon2 cost blowing CI time | Seeds phase | CI timing: seeds step completes under 5s; Argon2 `t_cost`/`m_cost` override applied at seed runtime |
| C-2: Seeds contaminating test DB | Seeds phase | Env guard in `seeds.exs`; CI audit: no seed step in test-env jobs; `example_unit_smoke` passes after seeds land |
| C-3: Playwright coupling to persona names | Playwright-extension phase | PR review: no `toContainText(personaName)` in demo-data specs; `data-testid` used for auth-state assertions |
| C-4: Non-idempotent seeds | Seeds phase | CI or local: run seeds twice in sequence; assert second run completes without constraint errors |
| M-1: Seeds going stale | Seeds phase + every future migration phase | Seeds-contract ExUnit suite: asserts persona completeness post-seed; migration phase success criteria include seeds update |
| M-2: Screenshot rot | Playwright-extension phase | No new `toHaveScreenshot()` calls for demo flows outside checkpoint lane; README PNGs are static/manually-updated |
| M-3: Nested-app drift | Every phase touching schema/templates | `example_unit_smoke` + `example_playwright_smoke` CI gates remain green; seeds step added to CI runs after `mix ecto.migrate` |
| D-1: Happy-path-only demo | Seeds phase + README phase | Persona checklist: locked, unconfirmed, MFA-enrolled, OAuth-linked, deletion-pending all present |
| D-2: Missing credentials cheat-sheet | Seeds phase | `demo_credentials.txt` exists, is `.gitignored`, README references it explicitly |
| D-3: Spin-up not actually one command | README/evaluator-lane phase | Fresh-clone smoke test (model: existing install-smoke infrastructure); prerequisites block present in README |
| SC-1: Generic seeding framework creep | All phases | No new files in `lib/sigra/` touching seeds/fixtures; diff scoped to `test/example/` only |
| SC-2: Separate demo repo | All phases | No new repos created; MILESTONE-ARC.md non-goal is the standing decision |

---

## Sources

- `/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md` — Phase 114 drift lesson, Demo Showcase non-goals, Diminishing Returns Wall (HIGH confidence, primary)
- `/Users/jon/projects/sigra/.planning/RETROSPECTIVE.md` — v1.29 recipe config drift, v1.28 release-docs-gate-late pattern (HIGH confidence)
- `/Users/jon/projects/sigra/.planning/PROJECT.md` — OWASP constraints, enumeration prevention, Argon2id requirement, security posture (HIGH confidence)
- `/Users/jon/projects/sigra/CLAUDE.md` — Argon2id default, enumeration prevention by default, Hammer rate limiting, security constraints (HIGH confidence)
- `/Users/jon/projects/sigra/test/example/config/test.exs` — `t_cost: 1, m_cost: 8` test override; confirms override does NOT exist in dev.exs (HIGH confidence — direct inspection)
- `/Users/jon/projects/sigra/test/example/config/dev.exs` — absence of Argon2 cost override in dev; dev `secret_key_base` pattern (HIGH confidence)
- `/Users/jon/projects/sigra/.github/workflows/ci.yml` — `example_http_smoke` and `example_playwright_smoke` jobs boot in `MIX_ENV: dev` without seeds step; `example_unit_smoke` in `MIX_ENV: test` (HIGH confidence — direct inspection)
- `/Users/jon/projects/sigra/test/example/priv/playwright/playwright.config.ts` — serial workers, `toHaveScreenshot` pathTemplate, checkpoint lane structure (HIGH confidence)
- `/Users/jon/projects/sigra/test/example/priv/playwright/tests/golden-path.spec.ts` — TOTP secret read from DOM at runtime, not hardcoded; model for correct pattern (HIGH confidence — direct inspection)
- `/Users/jon/projects/sigra/test/example/test/example/fixtures_test.exs` — existing fixture scenarios (locked, unconfirmed, MFA states) as reference for persona set (HIGH confidence)
- `/Users/jon/projects/sigra/.planning/threads/adoption-evidence-and-demo-showcase.md` — Demo Showcase scope, overbuild guardrails, Phase 114 decision reaffirmation (HIGH confidence)

---
*Pitfalls research for: Seed-rich evaluator demo on a dual-role auth library CI fixture (v1.31 DEMO-SHOWCASE)*
*Researched: 2026-05-29*
