# Feature Research: v1.31 DEMO-SHOWCASE

**Domain:** Seed-rich evaluator demo showcase for an OSS auth library (Sigra / Phoenix 1.8+)
**Researched:** 2026-05-29
**Confidence:** HIGH — grounded in codebase inspection + ecosystem survey of comparable evaluator patterns

---

## Scope

This research answers four questions for the downstream roadmap:

1. What persona set best exercises Sigra's full auth surface?
2. What is table-stakes vs differentiator in the "try it locally" doc lane?
3. What cheap-but-high-leverage demo affordances make auth features legible?
4. What are the anti-features to avoid given the milestone non-goals?

---

## Recommended Persona Roster (Concrete, Mapped to Sigra Features)

Seven personas cover every auth state Sigra ships. Six are seeded users; one is the "unauthenticated visitor" state that requires no row but should be listed in the credentials table as "just visit the app."

| # | Handle | Email | Password | Auth State Demonstrated | Sigra Features Exercised | Admin-visible state |
|---|--------|-------|----------|--------------------------|--------------------------|---------------------|
| 1 | `admin` | `admin@demo.example` | `DemoAdmin1!` | Confirmed, MFA-enrolled (TOTP), multi-org owner + member, API token holder | Password auth, TOTP MFA, backup codes, multi-org membership, org switching, API tokens, audit log (rich), admin dashboard, impersonation | Global admin view; audit trail shows all events |
| 2 | `alice` | `alice@demo.example` | `DemoAlice1!` | Confirmed, no MFA, member of one org | Password auth, email confirmation, session device labeling, settings, org membership | Normal confirmed user; standard audit trail |
| 3 | `bob` | `bob@demo.example` | `DemoBob1!` | Confirmed, TOTP MFA enrolled | MFA challenge on step-up, backup codes available | MFA enabled; no org affiliation |
| 4 | `carol` | `carol@demo.example` | `DemoCarol1!` | Confirmed, OAuth-linked (GitHub identity stored) | OAuth identity row (inserted directly — no live OAuth roundtrip needed), social login surface in settings | "GitHub" identity shown on user detail |
| 5 | `dave` | `dave@demo.example` | (none) | Locked (failed_login_attempts=5, locked_at set) | Lockout flow, admin unlock, rate limiting | Locked badge visible; unlock button present |
| 6 | `eve` | `eve@demo.example` | `DemoEve1!` | Unconfirmed (registered, confirmation email not clicked) | Unconfirmed state, re-send confirmation, restricted login | Unconfirmed badge in admin |
| 7 | `frank` | `frank@demo.example` | `DemoFrank1!` | Scheduled-deletion (deleted_at set, scheduled_deletion_at ~14 days out) | Data lifecycle: scheduled deletion, reactivation flow | Soft-deleted / scheduled-for-deletion state in admin |

**Why this roster:**

- **Admin** (persona 1) is the anchor: multi-org ownership proves organizations + memberships + org switching; MFA proves the enrollment and backup-code flows; API token proves bearer auth; the audit trail for the admin will be long (seed many audit events) so the audit explorer shows populated data immediately.
- **Alice** (persona 2) is the clean happy path: one confirmed, non-MFA user an evaluator can log in as to experience the standard flow without complexity.
- **Bob** (persona 3) isolates TOTP MFA from org membership so the evaluator can reach the MFA challenge without becoming the admin first.
- **Carol** (persona 4) demonstrates OAuth-linked identity. Because the demo runs without live OAuth provider credentials, the identity row is inserted directly into the user-identity table using Sigra's internal schemas. The settings page will show the linked GitHub identity. This is honest: it shows what a real OAuth-linked account looks like without requiring provider credentials.
- **Dave** (persona 5) demonstrates the lockout state and admin unlock flow. The admin can unlock him via the user-detail page. No password is needed because he cannot log in while locked.
- **Eve** (persona 6) demonstrates unconfirmed state. She can try to log in and see the "confirm your email" gate.
- **Frank** (persona 7) demonstrates the data lifecycle (scheduled deletion + reactivation path). The `reactivation_live.ex` page already exists in the example app and shows the deletion date. This is a rough edge most auth libraries ignore.

**Passkey persona: defer or fold into admin.** Passkeys require a real browser ceremony with platform authenticator; they cannot be seeded as DB rows that the evaluator can authenticate with in a normal browser. Seed a passkey credential row on admin (with nickname "Touch ID — MacBook Pro") for visibility in the admin user-detail page, but do not list it as a clickable login path. The interactive passkey login demo belongs in the Playwright spec, not in the seeded click-around path.

**SSO/Enterprise persona: fold into admin's org.** Seed an `EnterpriseConnection` row on admin's primary organization (in a `configured` / pending-activation state) so the org settings page shows the SSO panel populated. Do not attempt an active SSO login in seeds — it requires a live OIDC provider. The visual evidence (configured connection visible in settings) is sufficient for the evaluator.

**Multi-org coverage:** Seed two organizations:
- `Acme Corp` (slug: `acme-corp`) — admin is owner, alice is member, carol is member.
- `Beta Labs` (slug: `beta-labs`) — admin is member (not owner), bob is owner.

This proves org switching (admin can switch between two orgs) and the owner vs member role distinction.

---

## Feature Landscape

### Table Stakes

Features the evaluator expects without being told to look for them. Missing any of these makes the demo feel broken or incomplete.

| Feature | Why Expected | Complexity | Dependency on Sigra Feature |
|---------|--------------|------------|----------------------------|
| One-command spin-up (`mix setup && mix phx.server`) | Every modern OSS library demo works this way; evaluators will not debug setup | LOW — `mix setup` alias exists; seeds.exs is the only missing piece | `seeds.exs` idempotent insert wired into `mix setup` |
| Credentials table in README "Evaluating" section | Standard pattern: Keycloak, SuperTokens, and every comparable tool lists demo accounts prominently | LOW — copy-paste Markdown table | None — pure docs |
| Named personas with auth state described | Without this, evaluators log in as admin, see 0 events in the audit log, and conclude the feature doesn't work | LOW — README table cells | Seeded audit events |
| `mix setup` populates DB | Evaluators will run `mix setup` by habit; empty DB = demo appears broken | LOW — one-line alias addition in mix.exs | `seeds.exs` |
| Pre-populated audit log for admin | The admin audit explorer is a headline feature; 0 rows = "nothing to see" | MEDIUM — seed 10-15 rows covering 6+ event types | `AuditEvent` schema + Sigra event type atoms |
| Screenshots in README/guide | Without screenshots, evaluator cannot judge admin UI quality before cloning | LOW — re-use existing Playwright admin-checkpoints artifacts | Playwright artifacts already in repo |
| Password printed alongside email in credentials table | Table with email-only forces evaluator to grep seeds.exs | LOW — include in README table | None |

### Differentiators

Features that elevate the demo above "it runs" into "I understand what Sigra does."

| Feature | Value Proposition | Complexity | Dependency on Sigra Feature |
|---------|-------------------|------------|----------------------------|
| Pre-seeded audit history with realistic variety | The audit explorer is most impressive when it shows logins, failed attempts, MFA enrollments, org invitations, password resets. 10-15 rows covering 6-8 event types is the minimum for the explorer to feel useful | MEDIUM — know event type atoms; insert directly | `AuditEvent` schema + Sigra audit event type constants |
| Seeded pending invitation row (to `invited@demo.example`) | The invitation flow is hard to reach without a complete demo; a pre-seeded row shows the invitation management UI populated | LOW — one DB insert | `OrganizationInvitation` schema |
| Passkey credential row visible in admin for admin persona | Shows WebAuthn surface without requiring hardware authenticator | LOW — one `UserPasskey` insert with friendly nickname | `UserPasskey` schema |
| API token row visible in admin for admin persona | Shows bearer token surface without requiring evaluator to generate one first; shows `sigra_sk_` prefix | LOW — one row insert | API token schema |
| EnterpriseConnection row on Acme Corp (configured state) | Shows SSO panel in org settings without requiring live OIDC provider | LOW — one row insert | `EnterpriseConnection` schema |
| Frank's scheduled-deletion state with reactivation path | Shows data lifecycle (a rough edge most auth libraries do not have at all) | LOW — set `deleted_at` + `scheduled_deletion_at` on frank | `User` deletion fields + `reactivation_live.ex` (already exists) |
| In-app persona explainer banner (dev only) | Turns click-around browsing into guided evaluation: "You are logged in as Dave (locked user)" | MEDIUM — dev-only LiveView component or flash overlay | Dev-env conditional (`Mix.env() == :dev`) |
| `/demo` cheat-sheet route (dev only) | A `/demo` Phoenix route shows the full persona table with one-click login links — Auth0's "1-click auto-login demo user" pattern | MEDIUM — one controller/LiveView + template, dev-only pipeline scope | None |
| Playwright seeds-smoke spec | Proves seeds are idempotent and correct on every CI run; logs in as each persona and asserts expected auth state is visible | MEDIUM — ~80-100 lines of Playwright | All seeded personas |
| Realistic app domain name in layout | "Campfire — Team Projects" or "Vaultr" gives narrative context that makes auth states feel purposeful | LOW — rename in layout template | None |
| `/dev/mailbox` mention in README | Magic link and confirmation email flows are otherwise invisible without a real inbox; Swoosh mailbox preview is already wired | VERY LOW — one sentence in README | None |

### Anti-Features

Features to explicitly exclude, with rationale tied to milestone non-goals.

| Anti-Feature | Why It Seems Good | Why to Avoid | What to Do Instead |
|--------------|-------------------|--------------|-------------------|
| Generic seeding framework (ex_machina, Faker) | Looks professional; produces varied data | Milestone non-goal bars a generic framework; Faker data is non-deterministic unless seeded with a fixed integer, making Playwright assertions fragile; adds deps | Hard-coded deterministic data: fixed emails, fixed names, fixed timestamps. No `System.unique_integer`. |
| Separate standalone demo repo | Reduces drift between demo and library | Phase 114 already paid the nested-app drift cost; separate repo doubles maintenance surface; demo and library can diverge silently | Extend `test/example/` — the architectural decision is settled |
| Live OAuth provider credentials in seeds | Makes the OAuth demo click-through-able | Requires real GitHub/Google secrets in dev config; creates rotating-credential maintenance burden; breaks offline CI | Insert the identity row directly — shows the feature shape without live credentials |
| Seeding host-app domain data (projects, tasks, documents) | Makes the app feel like a "real" SaaS | Explicit milestone non-goal: no host-domain data beyond what makes auth legible | Persona descriptions and org names provide sufficient narrative context |
| Marketing site or landing page copy | Makes Sigra look polished | Out of scope; the demo is inside `test/example/`, not a hosted product | README "Evaluating" section is the conversion surface |
| Passkey interactive login as a seeded click-around path | Shows passkey end-to-end | Requires platform authenticator; non-portable across machines; confuses evaluators without biometrics enrolled | Seed the passkey row for visibility; defer interactive passkey login to the existing Playwright spec |
| Over-seeded audit log (100+ rows) | More data looks more impressive | Slows `mix setup`; forces the audit explorer into pagination mode, which can confuse an evaluator | 10-15 rows covering 6-8 event types — quality of variety over quantity |
| Lowered Argon2id work factor in seeds | Speeds up `mix setup` | Undermines the "real security posture" message; ~1.4 seconds for 7 hashes is acceptable | Keep default work factor |

---

## Feature Dependencies

```
Idempotent seeds.exs
    ├──requires──> All seeded schemas exist and are migrated
    │                  (User, Organization, OrganizationMembership,
    │                   OrganizationInvitation, UserMFACredential,
    │                   UserBackupCode, UserPasskey, AuditEvent,
    │                   UserSession, EnterpriseConnection)
    └──requires──> Argon2id hashing available (argon2_elixir NIF compiled)
                   (admin/alice/bob/eve/frank need hashed_password rows)

mix setup spin-up
    └──requires──> seeds.exs complete + `mix setup` alias wired in mix.exs

README credentials table
    └──requires──> seeds.exs finalized (emails + passwords must match)

Pre-populated audit log (differentiator)
    └──requires──> AuditEvent schema + Sigra audit event type atoms
                   (event types must match shipped constants)

Credentials cheat-sheet /demo route (differentiator)
    └──requires──> seeds.exs complete (personas must exist in DB)

In-app persona banner (differentiator)
    └──requires──> seeds.exs complete
                   (dev-env-only; no prod concern)

Playwright seeds-smoke spec (differentiator)
    └──requires──> seeds.exs complete + well-known emails/passwords

README screenshots
    └──requires──> Playwright checkpoint artifacts (already exist)
                   + seeds populated so screenshots show non-empty UI
```

---

## Demo Affordances: Cheap-but-High-Leverage Analysis

Ranked by (evaluator impact) / (implementation cost). Items marked HIGH/VERY LOW are the first-day wins.

| Affordance | Evaluator Impact | Implementation Cost | Notes |
|-----------|-----------------|---------------------|-------|
| Credentials table in README | HIGH | VERY LOW | Do this first; unblocks all evaluation paths |
| `mix setup` wires seeds | HIGH | VERY LOW | One-line alias addition in mix.exs |
| Pre-populated audit log (15 rows, 6+ types) | HIGH | LOW | Audit explorer is the most impressive admin feature; empty = invisible |
| `/dev/mailbox` mention in README | MEDIUM | VERY LOW | Magic link / confirmation flows become legible with one sentence |
| Seeded pending invitation row | MEDIUM | VERY LOW | One DB insert; invitation management UI goes from empty to populated |
| Passkey row visible in admin | MEDIUM | VERY LOW | One insert; shows WebAuthn surface without hardware |
| API token row visible in admin | MEDIUM | VERY LOW | One insert; shows bearer token surface |
| EnterpriseConnection row on Acme Corp | MEDIUM | VERY LOW | One insert; shows SSO panel |
| Frank scheduled-deletion state | MEDIUM | LOW | Sets two timestamp fields; reactivation_live.ex already exists |
| README screenshots (re-use existing Playwright artifacts) | HIGH | LOW | Playwright admin-checkpoints artifacts already committed; add to guide |
| Realistic app domain name | MEDIUM | LOW | Layout rename; makes demo feel purposeful |
| In-app persona banner | HIGH | MEDIUM | Highest-impact differentiator; worth a dedicated phase segment |
| `/demo` cheat-sheet route | HIGH | MEDIUM | Dev-only; one controller + template; 80% of value is the README table though |
| Playwright seeds-smoke spec | HIGH (CI) | MEDIUM | Proves idempotency; can follow seeds.exs in same phase or follow-on phase |

---

## MVP Definition for This Milestone

### Must-Have (v1.31 cannot ship without these)

- `seeds.exs` idempotent, deterministic, covering all 7 persona states (including locked, unconfirmed, MFA-enrolled, multi-org, scheduled-deletion)
- `mix setup` alias triggers `mix run priv/repo/seeds.exs`
- README "Evaluating" section with credentials table + one-command spin-up instructions
- Pre-populated audit log (15 rows minimum, 6+ event types, tied to admin persona)
- Seeded organizations (Acme Corp + Beta Labs) with memberships
- Seeded pending invitation row
- At least 2 screenshots in README/guide (admin user index, admin user detail) — re-use existing Playwright artifacts

### Should-Have (adds significant evaluator value, low risk)

- Passkey row seeded for admin (visible in admin user detail)
- API token row seeded for admin
- EnterpriseConnection row on Acme Corp (configured / pending-activation state)
- Frank scheduled-deletion state
- `/dev/mailbox` note in README
- Realistic app domain name in layout

### Defer (higher complexity or uncertain dependencies)

- In-app persona banner (medium complexity; best as a follow-on phase)
- `/demo` cheat-sheet route (README table covers 80% of the value; defer if phase is crowded)
- Playwright seeds-smoke spec (valuable for CI; can be the milestone's final phase)
- OAuth identity row for Carol (requires confirming exact `user_identities` schema shape in example app before committing to the insert pattern)

---

## Implementation Notes for Roadmap

### seeds.exs idempotency strategy

Use `on_conflict: :nothing` with deterministic UUIDs (hardcoded `Ecto.UUID.cast!` strings per persona) or `Repo.insert_or_update` with email as the unique key. This ensures `mix setup` is re-runnable without errors or duplicate rows.

Structure the seed file as:
1. Local `defp` helper functions (not a framework)
2. Organizations block (Acme Corp, Beta Labs)
3. Users block (7 personas in order)
4. Relationships block (memberships, invitation, MFA credentials, passkey row, API token row, audit events, EnterpriseConnection)
5. `IO.puts` a summary credentials table to stdout so the developer sees accounts after seeding

### Audit event seeding

`AuditEvent` schema fields: `user_id`, `action`, `ip`, `metadata`, `inserted_at`. Seed rows with deterministic `inserted_at` timestamps spread over the past 30 days so the explorer shows a realistic timeline. Use `Ecto.Changeset.change/2` directly — no need to invoke the full Sigra audit pipeline for seed rows. Event types to cover: `user.registered`, `user.confirmed`, `session.login`, `session.logout`, `mfa.enrolled`, `mfa.backup_codes.generated`, `org.member.invited`, `api_token.created`.

### Argon2id in seeds.exs

Hashing 7 passwords at default Argon2id settings (~200ms each) takes ~1.4 seconds total — acceptable. Do not lower the work factor; it undermines the security-posture message.

### Password policy compliance

All demo passwords must pass `Sigra.PasswordPolicy.validate/1`. The format `DemoAlice1!` (12 chars, upper + lower + digit + symbol) satisfies typical policies. Verify against the live policy before committing to the exact strings in the credentials table.

---

## Sources

- Codebase: `test/example/priv/repo/seeds.exs` (empty baseline confirmed — HIGH confidence)
- Codebase: `test/example/test/support/fixtures/auth_fixtures.ex` (7 existing test scenarios; persona roster derived from these — HIGH confidence)
- Codebase: `test/example/lib/example/accounts/user.ex` (auth-state fields: `confirmed_at`, `locked_at`, `failed_login_attempts`, `deleted_at`, `scheduled_deletion_at` — HIGH confidence)
- Codebase: `test/example/priv/playwright/tests/golden-path.spec.ts` (existing E2E patterns to extend — HIGH confidence)
- Codebase: `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (existing screenshot artifacts to re-use — HIGH confidence)
- `.planning/threads/adoption-evidence-and-demo-showcase.md` (adoption verdict + genuine gap analysis — HIGH confidence)
- `.planning/MILESTONE-ARC.md` (non-goals: no separate repo, no generic seeding framework, no host-domain data — HIGH confidence)
- SuperTokens demo: single `demo@example.com` / `abcd1234` credential pattern — informed the "persona table is better than a single generic account" conclusion (MEDIUM confidence)
- Auth0 community "1-click auto-login demo user" pattern — informed the `/demo` cheat-sheet route suggestion (LOW confidence — community post, not official doc)
- Phoenix seed guides (hexdocs.pm/phoenix seeding data) — background context on idempotent seeding approaches (MEDIUM confidence)

---

*Feature research for: v1.31 DEMO-SHOWCASE (Sigra auth library evaluator demo)*
*Researched: 2026-05-29*
