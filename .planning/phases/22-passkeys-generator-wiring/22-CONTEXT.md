# Phase 22: `--passkeys` Generator Wiring - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 22 makes passkeys a real installer feature flag instead of a partially wired codepath.

The deliverable is strict generated-app behavior on both sides of the flag:
- default install includes the full passkey surface
- `mix sigra.install --no-passkeys` generates a compile-clean, boot-clean non-passkey app with no residual passkey routes, schemas, hooks, config, deps, or dead generated branches

This phase validates the Phase 11 feature-manifest pattern on its second consumer. It does not redesign passkey UX, challenge semantics, or lower-level WebAuthn behavior already locked in Phases 19-21.

</domain>

<decisions>
## Implementation Decisions

### Zero-passkey strictness

- **D-01:** Passkeys follow the same high-level architecture as organizations: Sigra library code always ships, generated host-app code varies by feature flag.

  `lib/sigra/passkeys*` and `lib/sigra/plug/passkey_challenge.ex` remain compiled in the dependency regardless of install flags. The flag only controls generated application artifacts. This matches Sigra's hybrid lib+generator philosophy and is the least surprising model in the Phoenix ecosystem.

- **D-02:** `--no-passkeys` is a hard omission contract, not a runtime-hide mode.

  Under `--no-passkeys`, the generated app must omit:
  - passkey routes and pipelines
  - passkey controller actions / generated wrappers
  - passkey UI on login, MFA challenge, MFA settings, signup, and confirmation follow-through
  - passkey runtime config emitted into the host app
  - `wax_` in generated host `mix.exs`
  - `@simplewebauthn/browser` in generated host `assets/package.json`
  - `passkey_hooks.js`, `passkey_browser.js`, and the `app.js` marker block
  - `user_passkeys` migration and generated `UserPasskey` schema
  - residual generated references to `Sigra.Passkeys`, `Sigra.Plug.PasskeyChallenge`, `UserPasskey`, passkey route literals, or passkey-primary helper paths

- **D-03:** Do not generate stub or no-op compatibility surfaces for disabled passkeys.

  Reject fake `UserPasskey` modules, dead passkey routes, inert helper wrappers, and placeholder hooks. Structural omission is the contract. The generated code should read like the feature choice that created it.

### Ownership boundary

- **D-04:** `Sigra.Install.Features.Passkeys` owns every whole artifact that is intrinsically passkey-only.

  This includes:
  - passkey schema and migration
  - JS assets and `app.js` wiring
  - host dependency wiring in `mix.exs` and `assets/package.json`
  - passkey router blocks / pipelines
  - any generated helper/controller module that exists solely to serve passkey routes

- **D-05:** Shared core templates remain canonical for files whose primary identity is still baseline auth, but passkey regions inside them must be explicitly gated by `passkeys?`.

  This applies to files such as:
  - `auth.ex`
  - `session_controller.ex`
  - `login_html.ex`
  - `mfa_settings_live.ex`
  - `mfa_challenge_live.ex`
  - `registration_html.ex`
  - `confirmation_controller.ex`

  The recommendation is to keep one canonical shared template with local guards and small extracted helpers where needed, rather than creating parallel template trees.

- **D-06:** Do not introduce a new repo-wide manifest override/variant subsystem in Phase 22 unless planning proves a specific file cannot be kept readable with local guards or helper extraction.

  Phase 22 is meant to prove the existing Phase 11 manifest pattern on a second feature axis, not replace it with a second abstraction. If a shared file becomes too branch-heavy, first extract a small passkey partial/helper or move that single whole target cleanly into `Features.Passkeys`. Do not generalize prematurely.

### Architecture tradeoffs

- **D-07:** Reject full-template duplication as the main strategy.

  Comparison:
  - **Pros:** simple local reasoning inside each file variant
  - **Cons:** template drift, doubled review surface, bug-fix duplication, and a worse contributor experience

  This is not how Phoenix generators typically age well.

- **D-08:** Reject runtime-only hiding as the main strategy.

  Comparison:
  - **Pros:** fewer generator branches
  - **Cons:** violates `PK-02`, leaks unused deps/routes/code into disabled installs, and turns opt-out into "present but hidden"

  Sigra's contract is omission, not mere suppression.

- **D-09:** Reject a stub compatibility layer as the default strategy.

  Comparison:
  - **Pros:** can reduce branching in shared templates
  - **Cons:** misleading generated API surface, dead code, weaker upgrade story, and more surprise when users opt out

  The clean generated app is more valuable than shaving a few conditionals from templates.

- **D-10:** Recommended architecture is feature-owned whole artifacts plus shallow-to-moderate guarded sections in shared templates.

  Why this wins:
  - matches Phoenix generator style
  - keeps the feature-manifest model understandable
  - preserves Phase 11 and Phase 18 direction instead of inventing a new generator framework
  - avoids duplicate template drift
  - keeps `--no-passkeys` structurally honest
  - scales to future optional features without forcing contributors to learn a second ownership system

### Flag ergonomics

- **D-11:** `mix sigra.install` enables passkeys by default. `--no-passkeys` is the real behavioral switch. `--passkeys` remains accepted as an explicit redundant affirmation of the default.

  This is already the project-level product contract and is idiomatic Phoenix CLI behavior for default-on booleans.

- **D-12:** Help text, examples, and install summary must make the default explicit.

  Required posture:
  - help text documents `--passkeys` / `--no-passkeys` with `(default: true)`
  - examples prefer the no-flag happy path plus explicit opt-out examples
  - install summary always says either `Passkeys: enabled (default)` or `Passkeys: disabled via --no-passkeys`

  Tradeoff call:
  - documenting both flags is better DX than only mentioning `--no-passkeys`
  - default-off requiring `--passkeys` is rejected as inconsistent with Sigra's milestone stance
  - interactive choice prompts are rejected as bad CI ergonomics and unlike Phoenix tooling

### Dependency and injection posture

- **D-13:** Host dependency edits follow the same trust posture as Phase 20 `app.js` wiring: deterministic blessed-path edits first, exact manual instructions second, never silent partial success.

  Support standard Phoenix `mix.exs`, `assets/package.json`, and `assets/js/app.js`. If the host shape is non-standard, print exact manual add-lines and record them in the installer report.

### Verification posture

- **D-14:** Phase 22 needs a four-way install matrix and explicit omission assertions, not just unit tests around `enabled?/1`.

  Required combinations:
  - default install
  - `--no-passkeys`
  - `--no-organizations`
  - `--no-organizations --no-passkeys`

- **D-15:** All four combinations must install, compile, and boot.

  This is the minimum regression lock for X-1 style partial-apply leaks across the two optional axes.

- **D-16:** The `--no-passkeys` combinations must additionally prove omission directly through artifact-absence assertions.

  Authoritative checks should verify absence of:
  - passkey routes
  - passkey files/assets/migrations
  - `wax_` and `@simplewebauthn/browser`
  - generated config blocks
  - residual passkey strings or route literals in shared generated modules

- **D-17:** Keep expensive smoke layers single-path unless they are proving a Phase 22-specific omission risk.

  Coherent CI depth:
  - **All 4 combinations:** install + compile + boot
  - **`--no-passkeys` combinations:** explicit omission assertions and a small HTTP smoke because route/template leakage often appears only after boot
  - **Default fully enabled path:** remains the broader HTTP smoke path
  - **Browser smoke / Playwright:** remains single-path and passkey-enabled only; browser ceremony tests are about passkey behavior, not omission wiring

  This gives strong signal without turning every feature combination into a slow E2E tax.

### Ecosystem guidance

- **D-18:** The most relevant lessons from adjacent ecosystems all point in the same direction.

  What to learn:
  - **Phoenix `phx.gen.auth` / Phoenix generators:** visible generated code plus local conditionals beat hidden DSL magic
  - **Rodauth:** feature-per-boundary thinking is good; heavy framework indirection is less aligned with Sigra's Phoenix-first DX
  - **Better Auth:** cohesive optional-feature packaging is good; Sigra should copy the coherence, not the JS-runtime-heavy posture
  - **django-allauth / GitHub passkey UX:** optional WebAuthn should remain a coherent feature surface with clear fallback posture, not scattered baseline-session code
  - **Laravel/Jetstream style feature flags:** explicit, reviewable feature packaging is good DX; surprises come from hidden defaults or scattered ownership

### the agent's Discretion

- Exact helper extraction inside shared templates, provided the shared template remains readable.
- Exact injection anchors for `mix.exs`, `assets/package.json`, and router wiring, provided edits stay deterministic and reviewable.
- Exact naming of any passkey-only generated helper/controller module, provided ownership remains obvious.
- Whether a specific shared file should stay guarded in Core or move wholesale into `Features.Passkeys`, provided that decision is justified by readability rather than abstraction enthusiasm.

</decisions>

<specifics>
## Specific Ideas

- Treat Phase 22 as the passkey mirror of Phase 18, but with broader omission boundaries because passkeys reach backend deps, frontend assets, router wiring, and shared auth UI.
- The generated app should make `--no-passkeys` obvious in code review: fewer files, fewer routes, fewer deps, fewer config entries.
- Keep the happy path strong: default install should still feel batteries-included on standard Phoenix layout, with no manual dependency or router wiring on the blessed path.
- Prefer a small number of explicit `passkeys?` branches in canonical shared templates over duplicate template trees or a new repo-wide override engine.
- If planning finds one or two files have become mostly passkey code, move those whole targets cleanly into `Features.Passkeys` rather than creating a general feature-variant architecture.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project and prior-phase decisions
- `.planning/ROADMAP.md` — Phase 22 goal, success criteria, and its relationship to Phases 11, 18, 20, and 21
- `.planning/PROJECT.md` — hybrid lib+generator philosophy and passkeys default-on product stance
- `.planning/REQUIREMENTS.md` — `PK-01`, `PK-02`, `GEN-03`, `GEN-06`
- `.planning/STATE.md` — current sequencing and recent locked decisions
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` — feature-manifest contract and X-1 isolation goals
- `.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md` — closest prior art for default-on optional feature omission and matrix testing
- `.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-CONTEXT.md` — locked `app.js` marker/manual-action posture
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-CONTEXT.md` — locked passkey UX/controller boundaries that now need clean gating

### Local code to inspect
- `lib/mix/tasks/sigra.install.ex` — current passkeys default/flag behavior must be corrected
- `lib/sigra/install/feature.ex` — installer feature ownership contract
- `lib/sigra/install/runner.ex` — current feature walker and any narrowly scoped changes needed for clean ownership
- `lib/sigra/install/injection.ex` — deterministic injection/manual-action posture to reuse
- `lib/sigra/install/features/core.ex` — current core-owned passkey routes and shared file ownership
- `lib/sigra/install/features/passkeys.ex` — current passkeys feature owner for schema/migration/assets, likely expanded in this phase
- `priv/templates/sigra.install/core/auth.ex`
- `priv/templates/sigra.install/core/session_controller.ex`
- `priv/templates/sigra.install/core/login_html.ex`
- `priv/templates/sigra.install/core/mfa_settings_live.ex`
- `priv/templates/sigra.install/core/mfa_challenge_live.ex`
- `priv/templates/sigra.install/core/registration_html.ex`
- `priv/templates/sigra.install/core/confirmation_controller.ex`
- `priv/templates/sigra.install/passkeys/user_passkey.ex`
- `priv/templates/sigra.install/passkeys/create_user_passkeys.exs`
- `priv/templates/sigra.install/passkeys/passkey_browser.js`
- `priv/templates/sigra.install/passkeys/passkey_hooks.js`
- `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js`
- `test/sigra/install/features/passkeys_test.exs`
- `test/sigra/install/features/passkeys_js_test.exs`
- `test/sigra/install/features/coverage_test.exs`
- `test/sigra/install/generator_passkeys_foundation_test.exs`
- `test/sigra/install/generator_passkey_management_test.exs`

### Ecosystem references
- Phoenix generator/auth docs:
  - `https://hexdocs.pm/phoenix/mix_phx_gen_auth.html`
  - `https://hexdocs.pm/phoenix/1.8.0-rc.3/Mix.Tasks.Phx.Gen.Auth.html`
- Pow customization docs:
  - `https://hexdocs.pm/pow/readme.html`
- Better Auth plugin guidance:
  - `https://better-auth.com/docs/concepts/plugins`
  - `https://better-auth.com/docs/plugins/passkey`
- django-allauth WebAuthn docs:
  - `https://docs.allauth.org/en/dev/mfa/webauthn.html`
- passkeys.dev guidance:
  - `https://passkeys.dev/docs/use-cases/bootstrapping/`
  - `https://passkeys.dev/docs/use-cases/reauth/`
- GitHub passkey management precedent:
  - `https://docs.github.com/en/enterprise-cloud@latest/authentication/authenticating-with-a-passkey/managing-your-passkeys`
- Playwright best-practice guidance for keeping E2E focused:
  - `https://playwright.dev/docs/best-practices`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Install.Features.Passkeys` already owns the passkey schema, migration, and JS assets; this is the right place to expand passkey-only ownership.
- `Sigra.Install.Injection` already has the right trust posture: deterministic edits first, manual instructions second.
- `Sigra.Install.Features.Organizations` is local proof that a default-on feature with strict opt-out can work cleanly in this codebase.

### Established Patterns
- Feature modules own whole generated artifacts and their injections.
- Core is mandatory and should only carry guarded sections for shared auth files, not dead optional-feature scaffolding.
- Manual fallback instructions are acceptable only when Sigra cannot safely edit a host-owned file; silent partial success is not acceptable.

### Integration Points
- Move passkey route/dependency/asset ownership into `Features.Passkeys`.
- Gate residual passkey branches inside shared core templates so `--no-passkeys` degrades to the pre-passkey shape.
- Add omission-focused assertions to the generator smoke harness for the `--no-passkeys` legs.

</code_context>

<deferred>
## Deferred Ideas

- A generic feature-variant or same-target override engine for every future overlap case is out of scope unless planning proves Phase 22 cannot stay readable without it.
- Richer reorganization of generated auth modules into per-feature subcontexts is out of scope unless it is necessary to satisfy the omission contract cleanly.

</deferred>

---

*Phase: 22-passkeys-generator-wiring*
*Context gathered: 2026-04-15*
