# Phase 237: Canonical B2C Generator Contract - Context

**Gathered:** 2026-08-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish a deterministic, fresh-Phoenix generator contract for the canonical personal-account B2C profile: email/password and magic links plus generated Google OAuth, with admin, organizations, and passkeys absent. Prove generation, migration, assets, warning-free compilation, and application boot. Browser/a11y and provider-callback behavior belong to Phase 238; real Google, email, and iPhone rehearsal remain staging launch gates.
</domain>

<decisions>
## Implementation Decisions

### Canonical installer profile
- **D-01:** The canonical command is `mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes`; it retains the installer’s standard email/password and magic-link experience.

### Google OAuth generated-host contract
- **D-02:** Add the required direct `cloak_ecto` dependency, then run `mix sigra.gen.oauth --providers google`; prove generated identity, encrypted vault, OAuth controller/routes/templates, provider configuration injection, and OAuth migration artifacts.

### Negative surface boundary
- **D-03:** Prove B2C-03 from the generated application—not only flags—by checking routes, files, dependencies/assets, and configuration for the absence of admin, organization, and passkey residue.

### Deterministic fresh-host proof
- **D-04:** The acceptance smoke scaffolds an assets-enabled Phoenix app, installs the profile, generates Google OAuth, builds assets, compiles with warnings as errors, creates/migrates Postgres, and proves a root HTTP response. It uses no provider or email credentials and does not add browser-runtime coverage.

### the agent's Discretion
- Extend the existing fresh-host script and install-contract tests in the smallest repo-consistent way, choosing precise stable absence assertions that cover the optional features’ actual ownership surfaces.
- Keep the local path dependency, dummy non-secret `CLOAK_KEY`, isolated temporary app/database handling, and bounded boot probe patterns already used by the repository.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `guides/recipes/b2c-alpha.md`
- `scripts/ci/passkeys-opt-out-smoke.sh`
- `lib/mix/tasks/sigra.install.ex`
- `lib/mix/tasks/sigra.gen.oauth.ex`
- `lib/sigra/install/features/admin.ex`
- `lib/sigra/install/features/organizations.ex`
- `lib/sigra/install/features/passkeys.ex`
- `test/sigra/install/generator_passkeys_opt_out_test.exs`
- `test/support/install_fixture.ex`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/passkeys-opt-out-smoke.sh` already scaffolds an assets-enabled Phoenix/Postgres host, patches the in-tree Sigra path dependency, runs the exact B2C opt-out leg, adds `cloak_ecto`, generates Google OAuth, builds, migrates, and probes boot.
- `test/sigra/install/generator_passkeys_opt_out_test.exs` already gives a fixture-backed no-passkeys and B2C residue contract, including compile-with-warnings-as-errors.
- `guides/recipes/b2c-alpha.md` is the supported profile documentation and explicitly separates automated proof from staging rehearsal.

### Established Patterns
- Optional installer features are enabled by default and own their complete files, injections, migrations, assets, dependencies, routes, and configuration through isolated `Sigra.Install.Feature` modules.
- The OAuth generator fails closed without `cloak_ecto` and then creates the identity, vault/encrypted type, controller, templates, migration, route/config injections, and test helper artifacts.
- Fresh-host verification is command-level and deterministic: isolated temporary app, local path dependency, controlled database, non-secret environment values, warning-free compile, asset build, migration, and bounded HTTP readiness probe.

### Integration Points
- The Phase 237 smoke lives in `scripts/ci/passkeys-opt-out-smoke.sh` and its contract test; it drives `mix sigra.install` then `mix sigra.gen.oauth` against a fresh Phoenix host.
- Phase 238 consumes precisely this generated host/profile for deterministic browser and accessibility proof, rather than duplicating the generator-boundary work here.
</code_context>

<specifics>
## Specific Ideas

- Preserve the exact B2C command and the documented order: install first, then Google OAuth generation.
- `org_id: nil` and Crosswake authority are Phase 239 concerns; do not manufacture organization behavior in this phase.
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

### Reviewed Todos (not folded)
- “Harden app.css corruption guard against mid-block orphan values” — unrelated CSS integrity work.
- Phase 234 PR/evidence follow-ups — CI evidence closeout, not B2C generator behavior.
- Schema-helper and runtime auth-prefix override — separate installer/config capabilities.
- Remaining low-score CI, release, security, and admin-UI todo matches — keyword-only matches with no Phase 237 scope connection.
</deferred>
