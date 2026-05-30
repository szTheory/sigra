---
phase: 141
slug: seed-data-layer
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-30
---

# Phase 141 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Phase 141 adds an idempotent demo-seed data layer to the bundled example app
(`test/example/`). All threats were authored at plan time across the four
PLAN.md `<threat_model>` blocks and independently verified against the
implementation by `gsd-security-auditor` (verify-mitigations mode — no new
threats scanned, no files modified).

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| seed/dev DB → admin UI render | Seeded identity/audit rows cross into the library admin surface; a malformed row would crash or silently fail to render. | Demo persona rows (public-by-design) |
| schema field contract → library query | `list_identities/3` queries fixed columns; a field-name mismatch is a compile/runtime failure, not a leak. | Schema field names |
| dev config → hashing cost | The Argon2 cost override defines how strongly seeded passwords are hashed; an over-lowered cost would model a weak posture to adopters. | Argon2 t_cost / m_cost |
| seed data module → committed source | Persona passwords + deterministic TOTP secret are public-by-design demo data; risk is leakage into a non-dev path or being read as a production recommendation. | Demo passwords, demo TOTP secret |
| email domain → CI fixture | `@demo.sigra.dev` (seeded) vs `@example.test` (golden-path) segregation keeps `mix test` deterministic. | Persona email domains |
| seeds.exs entry → DB | The `Mix.env() == :test` raise-guard is the gate; it must fire before any DB connection in MIX_ENV=test. | DB write access |
| dev seed run → CI fixture DB | `example_dev` and `example_test` are separate DBs; the guard prevents the dev seed path from writing to the test DB even if mistakenly invoked. | DB connection target |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-141-01 | Tampering | user_identities migration to wrong DB | mitigate | Migration uses `create_if_not_exists`, run only via dev `ecto.migrate`; `example_dev` (dev.exs:8) vs `example_test` (test.exs:12) already separate. | closed |
| T-141-02 | Information disclosure | encrypted_access/refresh_token columns | accept | `Example.Accounts.Encrypted` (encrypted.ex:1–31) is a documented passthrough `Ecto.Type` (no encryption, "production app MUST replace"); seeded identity (seeds.ex:330–337) stores only provider/uid/email — no real token. Public-by-design demo data. | closed |
| T-141-03 | Tampering | npm/pip/cargo installs | mitigate | Git diff over the phase commit range shows zero changes to `mix.exs`/`mix.lock`. No package installs. | closed |
| T-141-04 | Tampering | Argon2 dev cost leaking to prod | mitigate | Override `t_cost: 2, m_cost: 12` lives ONLY in dev.exs:99 with no-copy-to-prod comment (95–98); prod.exs has no argon2 line; test.exs:47 unchanged at `t_cost: 1, m_cost: 8`. | closed |
| T-141-05 | Spoofing/Repudiation | weak seed passwords read as recommendation | mitigate | All six personas (personas.ex:42,55,68,81,94,107) use 12+ char mixed case+digit+symbol passwords satisfying `Sigra.PasswordPolicy.validate/1`; never `password`/`admin`/`demo123`; documented public-by-design (personas.ex:11–14). | closed |
| T-141-06 | Information disclosure | deterministic demo TOTP secret | accept | `@demo_totp_secret` (personas.ex:17–18) carries verbatim `# Demo-only — intentionally deterministic. Never use in production.` label; behind the test-env guard + passthrough Cloak type. | closed |
| T-141-07 | Tampering | email-domain contamination of CI fixture | mitigate | `rg @example.test lib/example/demo/` → no matches; all 8 persona emails use `@demo.sigra.dev`. Segregation invariant holds. | closed |
| T-141-08 | Tampering | seed run against the test/CI DB | mitigate | `Example.Demo.Seeds.run` reached only via seeds.exs, which raises in MIX_ENV=test (seeds.exs:16–19) before any DB access; `test` mix alias (mix.exs:85) never calls seeds.exs. Two-layer defense. | closed |
| T-141-09 | Repudiation | audit rows not tied to right user | mitigate | Audit query contract (query.ex:32) matches `effective_user_id`; seeds.ex:408 sets `effective_user_id: admin.id` on every audit row, so the trail is correctly attributable in the admin UI. | closed |
| T-141-10 | Spoofing | fabricated passkey/TOTP/OIDC presented as real auth | accept | Passkey row commented "display-only; will not authenticate" (seeds.ex:276) with fabricated `:crypto.hash` binaries; TOTP uses labeled demo secret; OIDC `encrypted_client_secret: "demo-secret-not-real"` (seeds.ex:317). Public-by-design behind dev guard. | closed |
| T-141-11 | Tampering | non-idempotent audit inserts corrupting re-runs | mitigate | Count-threshold guard `admin_tied_count < 15` (seeds.ex:375–384) makes a second run a no-op; batch wrapped in `Repo.transaction` (seeds.ex:391) for all-or-nothing integrity. | closed |
| T-141-12 | Tampering | seeds.exs contaminating CI fixture DB | mitigate | `Mix.env() == :test` raise-guard is the first executable statement (seeds.exs:16–19), before `Example.Demo.Seeds.run()` (seeds.exs:21); `test` alias (mix.exs:85) unchanged. | closed |
| T-141-13 | Information disclosure | demo secrets/passwords surfacing in non-dev env | mitigate | Dev guard confines run to dev (T-141-12); dev-only Argon2 cost (T-141-04); demo TOTP label present; registration uses real `Sigra.Crypto.hash_password` (user.ex:77) → `$argon2id$` hashing. | closed |
| T-141-14 | Denial of service / corruption | non-idempotent re-run breaking CI/setup | mitigate | All upserts use `on_conflict: :nothing` on unique indexes (seeds.ex:213,268,289,337) or check-then-insert (seeds.ex:181,225,301); audit count-guarded. Idempotent by construction; seed-twice exits 0 with stable counts. | closed |
| T-141-SC | Tampering | npm/pip/cargo installs (supply chain) | accept | No new packages introduced this phase (empty `mix.exs`/`mix.lock` diff); existing deps pinned in test/example/mix.exs:41–72. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-141-01 | T-141-02 | Passthrough (non-encrypting) Cloak type for token columns is intentional in the demo app and clearly documented as "production app MUST replace"; seeded data stores no real tokens. | gsd-security-auditor | 2026-05-30 |
| AR-141-02 | T-141-06 | Deterministic demo TOTP secret is public-by-design fixture data, behind the test-env raise-guard and carrying a verbatim "Never use in production" label. | gsd-security-auditor | 2026-05-30 |
| AR-141-03 | T-141-10 | Fabricated passkey/TOTP/OIDC credentials are display-only demo data (commented as non-authenticating); never presented as real credentials. | gsd-security-auditor | 2026-05-30 |
| AR-141-04 | T-141-SC | No new third-party packages introduced; existing deps already pinned. Supply-chain delta is nil for this phase. | gsd-security-auditor | 2026-05-30 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-30 | 15 | 15 | 0 | gsd-security-auditor (verify-mitigations mode) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-30
