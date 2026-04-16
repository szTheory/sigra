# Phase 22: `--passkeys` Generator Wiring - Research

**Researched:** 2026-04-16
**Domain:** Sigra installer feature-manifest wiring for passkeys
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

None captured in `22-CONTEXT.md`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-02 | Developer can disable passkeys entirely via `mix sigra.install --no-passkeys`; no passkey templates, schemas, routes, or JS hooks are generated. | Use `Features.Passkeys` for whole-artifact ownership, pass `passkeys?` through binding for shared templates, flip default to true, and add explicit omission tests plus four-way matrix coverage. [VERIFIED: REQUIREMENTS.md] |
</phase_requirements>

## Summary

Phase 22 should be planned as the second proof of the Phase 11 manifest design, not as a passkey feature redesign. The repo already has the right architectural seam: a feature list in [`lib/mix/tasks/sigra.install.ex`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex), a feature-agnostic runner in [`lib/sigra/install/runner.ex`](/Users/jon/projects/sigra/lib/sigra/install/runner.ex), and passkey-specific whole artifacts in [`lib/sigra/install/features/passkeys.ex`](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex). [VERIFIED: codebase grep] The current mismatch is that passkeys are still default-off in code, while passkey routes, controller actions, and shared UI/helpers live unguarded in Core-owned templates and router injection blocks. [VERIFIED: codebase grep]

Phoenix’s own `mix phx.gen.auth` docs still describe generated auth code as something developers customize afterward, and LiveView’s current JS interop docs still center hooks plus explicit `hooks: ...` registration in `LiveSocket`. [CITED: https://hexdocs.pm/phoenix/1.8.5/Mix.Tasks.Phx.Gen.Auth.html] [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] That supports the locked Phase 22 direction: keep canonical shared templates, gate local passkey regions with `passkeys?`, and move only truly passkey-only files or router blocks into `Features.Passkeys`. [VERIFIED: 22-CONTEXT.md]

The planning wrinkle is verification. The current CI matrix only covers `""` and `--no-organizations`, and it scaffolds apps with `--no-assets`, which is enough for compile/boot proof but not enough to prove package-manager omission in `assets/package.json`. [VERIFIED: .github/workflows/ci.yml] Phase 22 therefore needs two test layers: a four-way compile/boot matrix on the existing no-assets harness, plus at least one assets-enabled omission harness for the `--no-passkeys` path to prove `assets/js/*` absence and `@simplewebauthn/browser` omission. [VERIFIED: codebase grep]

**Primary recommendation:** Make passkeys default-on, keep the Phase 11 manifest intact, wire passkey-only artifacts into `Features.Passkeys`, thread `passkeys?` through shared Core templates, and prove omission with a two-layer test strategy. [VERIFIED: 22-CONTEXT.md] [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Installer flag parsing and defaulting | Mix task / generator | — | `Mix.Tasks.Sigra.Install` owns `@switches` and `@default_opts`, and currently sets `passkeys: false`; Phase 22 must flip the default here. [VERIFIED: codebase grep] |
| Whole passkey artifact generation | Generator feature layer | — | `Sigra.Install.Features.Passkeys` already owns passkey schema, migration, JS assets, and `app.js` injection; this is the right tier for passkey-only files. [VERIFIED: codebase grep] |
| Shared auth template passkey gating | Generator Core templates | — | `auth.ex`, `session_controller.ex`, `login_html.ex`, `mfa_*`, `registration_html.ex`, and `confirmation_controller.ex` are still Core-owned and contain passkey logic that must be locally guarded with `passkeys?`. [VERIFIED: codebase grep] |
| Router passkey routes/pipelines | Generator injection layer | Browser / controller at runtime | Passkey POST routes are emitted inside the Core router injection block today, so Phase 22 must either gate those lines or move them into a Passkeys-owned router injection fragment. [VERIFIED: codebase grep] |
| Runtime passkey library code | Library backend | Browser / controller | Locked decisions keep `Sigra.Passkeys*` and `Sigra.Plug.PasskeyChallenge` always compiled; `--no-passkeys` changes generated host code only. [VERIFIED: 22-CONTEXT.md] |
| Browser WebAuthn ceremony behavior | Generated host JS | Controller / LiveView | Phase 20 and 21 already established `passkey_hooks.js`, `passkey_browser.js`, controller completion routes, and hook lifecycle semantics. [VERIFIED: 20-CONTEXT.md] [VERIFIED: 21-CONTEXT.md] |
| Dependency presence/absence (`wax_`, `@simplewebauthn/browser`) | Generator feature layer | Package managers | Phase 22 success requires these to be added only on passkey-enabled installs and omitted entirely on `--no-passkeys`. [VERIFIED: 22-CONTEXT.md] |

## Project Constraints (from CLAUDE.md)

- Read `CLAUDE.md` and follow it as a project authority. [VERIFIED: CLAUDE.md]
- Use Phoenix 1.8 conventions, including `Layouts.app` wrappers and `current_scope` correctness for LiveViews. [VERIFIED: CLAUDE.md]
- Use `mix precommit` when implementation is done. [VERIFIED: CLAUDE.md]
- Prefer the already-included `Req` library for HTTP requests; do not introduce `HTTPoison`, `Tesla`, or `:httpc` for this work. [VERIFIED: CLAUDE.md]
- Local and CI test runs expect a live Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md]
- Project skills directories are absent in this repo, so there are no extra project skill conventions to honor. [VERIFIED: CLAUDE.md] [VERIFIED: codebase grep]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix generator pattern | Phoenix 1.8.5, updated Mar 05 2026 [VERIFIED: hex.pm phoenix] | Baseline installer and generated-auth style | Phoenix still treats auth generation as visible code that developers customize, which matches Sigra’s feature-manifest approach. [CITED: https://hexdocs.pm/phoenix/1.8.5/Mix.Tasks.Phx.Gen.Auth.html] |
| `wax_` | 0.7.0, updated May 18 2025 [VERIFIED: hex.pm wax_] | Server-side WebAuthn / passkey runtime | Phase 22 must keep library runtime passkey support on the enabled path and omit host references on the disabled path without changing the runtime dependency’s role. [VERIFIED: REQUIREMENTS.md] [VERIFIED: 22-CONTEXT.md] |
| `@simplewebauthn/browser` | 13.3.0, published Mar 10 2026 [VERIFIED: npm registry] | Browser ceremony helper for host apps | The official browser docs still center `startRegistration()`, `startAuthentication()`, and conditional UI helpers for browser support/autofill checks. [CITED: https://simplewebauthn.dev/docs/packages/browser] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix LiveView JS hooks | 1.1.28 docs version [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] | Hook lifecycle and `LiveSocket` registration | Use for generated passkey hooks and teardown semantics on enabled installs only. [VERIFIED: 20-CONTEXT.md] |
| Plug session API | Plug 1.19.1 docs version [CITED: https://hexdocs.pm/plug/Plug.Conn.html] | `put_session/3` and `delete_session/2` semantics | Relevant because passkey routes and controller actions must disappear cleanly when passkeys are disabled. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Local `passkeys?` guards in canonical templates | Duplicate passkey-enabled and passkey-disabled template trees | Rejected because Phoenix generator practice and locked phase decisions both favor visible generated code with local conditionals over drift-prone duplication. [CITED: https://hexdocs.pm/phoenix/1.8.5/Mix.Tasks.Phx.Gen.Auth.html] [VERIFIED: 22-CONTEXT.md] |
| Passkeys feature-owned whole artifacts plus guarded Core regions | New variant/override subsystem | Rejected in this phase because it would replace the Phase 11 manifest instead of proving it on a second consumer. [VERIFIED: 22-CONTEXT.md] |
| Deterministic edits plus explicit manual instructions | Heuristic rewrites of custom asset entrypoints or package files | Rejected because Phase 20 already locked deterministic blessed-path edits first and exact instructions second. [VERIFIED: 20-CONTEXT.md] |

**Installation:**
```bash
# passkey-enabled generated host app
mix deps.get
npm install @simplewebauthn/browser@^13.3.0
```

**Version verification:** [VERIFIED: npm registry] [VERIFIED: hex.pm wax_] [VERIFIED: hex.pm phoenix]

## Architecture Patterns

### System Architecture Diagram

```text
mix sigra.install [flags]
        |
        v
Mix.Tasks.Sigra.Install
  - parses --passkeys / --no-passkeys
  - builds binding with passkeys?
        |
        v
Sigra.Install.Runner
  - filters enabled features
  - walks files, migrations, injections
        |
        +--> Features.Core
        |     - always enabled
        |     - emits canonical auth templates
        |     - gates passkey regions with passkeys?
        |
        +--> Features.Passkeys
              - enabled only when passkeys=true
              - emits schema/migration/assets/dependency wiring/router fragments
        |
        v
Generated Phoenix host app
  - enabled path: routes + controller hooks + assets + deps
  - disabled path: compile-clean app with zero passkey artifacts
        |
        v
Verification
  - 4-way compile/boot matrix
  - no-passkeys omission assertions
  - asset-aware smoke for package/app.js proofs
```

### Recommended Project Structure

```text
lib/
├── mix/tasks/sigra.install.ex           # flag defaults, binding, feature registry
├── sigra/install/runner.ex              # feature-agnostic walker
├── sigra/install/features/core.ex       # canonical shared templates + gated regions
└── sigra/install/features/passkeys.ex   # passkey-only files, migrations, injections, deps

priv/templates/sigra.install/
├── core/                               # shared auth templates with local passkeys? guards
└── passkeys/                           # whole-artifact ownership for passkey-only files

test/
├── sigra/install/                      # feature + generator contract tests
├── support/install_fixture.ex          # tmp Phoenix app harness
└── scripts/ci/                         # matrix and smoke entrypoints
```

### Pattern 1: Default-On Boolean Feature Flag
**What:** Keep `--passkeys` accepted, but make default installs passkey-enabled and use `--no-passkeys` as the real omission switch. [VERIFIED: 22-CONTEXT.md]  
**When to use:** For user-facing optional features that are product-default-on and need explicit opt-out. [VERIFIED: 22-CONTEXT.md]  
**Example:**
```elixir
# Source: local code pattern in lib/mix/tasks/sigra.install.ex
@switches [passkeys: :boolean]
@default_opts [passkeys: true]

binding = [
  passkeys?: Keyword.get(opts, :passkeys, true),
  opts: opts
]
```

### Pattern 2: Whole Artifact Ownership in Feature Module
**What:** Passkey-only files belong to `Features.Passkeys.files/1`, `migrations/1`, and `injections/1`. [VERIFIED: 22-CONTEXT.md] [VERIFIED: codebase grep]  
**When to use:** For files whose primary identity disappears completely on `--no-passkeys`. [VERIFIED: 22-CONTEXT.md]  
**Example:**
```elixir
# Source: local pattern in lib/sigra/install/features/passkeys.ex
def enabled?(opts), do: Keyword.get(opts, :passkeys, true)

def files(binding) do
  [
    {:eex, "passkeys/user_passkey.ex", "..."},
    {:eex, "passkeys/passkey_browser.js", "..."},
    {:eex, "passkeys/passkey_hooks.js", "..."}
  ]
end
```

### Pattern 3: Shallow Guarding in Shared Templates
**What:** Core templates stay canonical, but passkey-only regions are wrapped in `passkeys?` guards. [VERIFIED: 22-CONTEXT.md]  
**When to use:** For `auth.ex`, `session_controller.ex`, `login_html.ex`, `mfa_settings_live.ex`, `mfa_challenge_live.ex`, `registration_html.ex`, and `confirmation_controller.ex`. [VERIFIED: 22-CONTEXT.md] [VERIFIED: codebase grep]  
**Example:**
```eex
<%= if passkeys? do %>
  alias <%= context_module %>.UserPasskey

  def passkeys_for_user(user) do
    Sigra.Passkeys.list_for_user(sigra_config(), user, user_passkey_schema: UserPasskey)
  end
<% end %>
```

### Anti-Patterns to Avoid

- **Feature-special casing in the runner or mix task:** `Runner` and the phase-11 additive invariant require feature-agnostic walking; only the `@features` list should name Passkeys directly. [VERIFIED: codebase grep]
- **Runtime-hide only:** Leaving routes, controller actions, or deps in place and hiding UI violates PK-02 and the locked omission contract. [VERIFIED: REQUIREMENTS.md] [VERIFIED: 22-CONTEXT.md]
- **No-assets-only verification:** The current no-assets matrix cannot prove `assets/package.json` behavior, so it is insufficient on its own for Phase 22. [VERIFIED: .github/workflows/ci.yml]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Feature dispatch | A second manifest/variant framework | Existing `Sigra.Install.Feature` + `Runner` | Phase 11 already proved the seam; Phase 22 is supposed to validate it again, not replace it. [VERIFIED: 11-CONTEXT.md] [VERIFIED: 22-CONTEXT.md] |
| JS hook lifecycle | Custom DOM observer framework | Phoenix LiveView hooks | Official LiveView docs still provide `mounted`, `destroyed`, and `disconnected` as the supported interop lifecycle. [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] |
| Browser WebAuthn client | Ad hoc ceremony packaging decisions | `@simplewebauthn/browser` | Official docs still provide the standard browser-side registration, authentication, and autofill helpers. [CITED: https://simplewebauthn.dev/docs/packages/browser] |
| Session mutation semantics | Custom session abstraction for this phase | `Plug.Conn.put_session/3` and `delete_session/2` | Plug documents the standard session mutation API and Sigra already uses it in generated controllers. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: codebase grep] |

**Key insight:** The dangerous complexity here is not WebAuthn crypto; it is generator partial-apply drift across whole files, shared templates, routes, deps, and asset wiring. The repo already has standard primitives for each of those concerns. [VERIFIED: codebase grep] [VERIFIED: 22-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Default Flag Drift
**What goes wrong:** Code still treats passkeys as opt-in even though the product contract is default-on. [VERIFIED: codebase grep]  
**Why it happens:** `@default_opts` and `Features.Passkeys.enabled?/1` currently default to `false`. [VERIFIED: codebase grep]  
**How to avoid:** Flip both to default `true`, pass `passkeys?` into the binding, and add tests that `mix sigra.install` with no passkey flag emits passkey artifacts. [VERIFIED: 22-CONTEXT.md]  
**Warning signs:** A default install lacks `user_passkeys` migration or passkey routes. [VERIFIED: 22-CONTEXT.md]

### Pitfall 2: Core Leakage on `--no-passkeys`
**What goes wrong:** Shared templates still reference `Sigra.Passkeys`, `UserPasskey`, or passkey-only routes when the feature is disabled. [VERIFIED: 22-CONTEXT.md] [VERIFIED: codebase grep]  
**Why it happens:** Core templates currently contain many passkey helpers and UI branches with no `passkeys?` guard. [VERIFIED: codebase grep]  
**How to avoid:** Gate passkey-only regions locally and keep omission assertions that grep for residual strings in generated output. [VERIFIED: 22-CONTEXT.md]  
**Warning signs:** `mix compile` fails on missing modules or route helpers in `--no-passkeys` apps. [VERIFIED: 22-CONTEXT.md]

### Pitfall 3: Router Ownership Confusion
**What goes wrong:** Passkey routes remain in the Core router injection even when passkeys are disabled. [VERIFIED: codebase grep]  
**Why it happens:** The current router injection block in `Features.Core` emits all passkey POST routes unconditionally. [VERIFIED: codebase grep]  
**How to avoid:** Either wrap those blocks in `if passkeys?` inside Core’s injection builder or move passkey-only route fragments into `Features.Passkeys`. [VERIFIED: 22-CONTEXT.md]  
**Warning signs:** Generated routers on `--no-passkeys` still contain `/log_in/passkey`, `/mfa/passkey`, or `/settings/mfa/passkeys`. [VERIFIED: 22-CONTEXT.md]

### Pitfall 4: Asset/Dependency Blind Spot
**What goes wrong:** The matrix goes green while `assets/package.json`, `assets/js/app.js`, or JS helper files are wrong because the harness used `--no-assets`. [VERIFIED: .github/workflows/ci.yml]  
**Why it happens:** Current install-matrix jobs scaffold no-assets Phoenix apps. [VERIFIED: .github/workflows/ci.yml]  
**How to avoid:** Keep the no-assets matrix for compile/boot speed, but add an assets-enabled omission test for `--no-passkeys` and an enabled-path assets test for default install. [VERIFIED: codebase grep]  
**Warning signs:** CI never reads `assets/package.json`, but the phase claims package-level omission coverage. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources and local code:

### LiveSocket Hook Registration
```javascript
// Source: https://hexdocs.pm/phoenix_live_view/js-interop.html
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})
liveSocket.connect()
```

### LiveView Hook Lifecycle
```javascript
// Source: https://hexdocs.pm/phoenix_live_view/js-interop.html
let Hooks = {}
Hooks.PasskeyAuthenticate = {
  mounted() {},
  destroyed() {},
  disconnected() {},
}
```

### SimpleWebAuthn Browser Flow
```javascript
// Source: https://simplewebauthn.dev/docs/packages/browser
import { startAuthentication } from '@simplewebauthn/browser'

const credential = await startAuthentication({
  optionsJSON,
  useBrowserAutofill: true,
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Passkeys opt-in in local code | Passkeys default-on by roadmap and context | Locked before Phase 22 planning [VERIFIED: ROADMAP.md] | Phase 22 must reconcile implementation with product contract. [VERIFIED: codebase grep] |
| Single org-axis matrix | Four-way org x passkeys matrix | Required by Phase 22 success criteria [VERIFIED: ROADMAP.md] | CI must cover both optional axes together to catch partial-apply regressions. [VERIFIED: 22-CONTEXT.md] |
| Hand-rolled browser helper in templates | Requirement-level package presence/absence for `@simplewebauthn/browser` | PK-01 and Phase 22 success criteria [VERIFIED: REQUIREMENTS.md] [VERIFIED: ROADMAP.md] | Planner must decide whether Phase 22 introduces package wiring only, or also aligns template imports with that package in the same owned scope. [VERIFIED: codebase grep] |

**Deprecated/outdated:**

- `passkeys: false` as the installer default is outdated relative to the roadmap, requirements, and phase context. [VERIFIED: codebase grep] [VERIFIED: ROADMAP.md] [VERIFIED: REQUIREMENTS.md]
- The current two-entry install matrix is outdated for this phase because it does not include either no-passkeys combination. [VERIFIED: .github/workflows/ci.yml]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The router block may remain readable with local `passkeys?` guards instead of moving to a passkey-only injection fragment. | Open Questions | Low-to-medium; planning might underestimate template complexity and need an extra refactor step. |

## Open Questions

1. **Should Phase 22 also switch generated browser code to import `@simplewebauthn/browser` instead of the current hand-rolled helper?**
   - What we know: The success criteria explicitly require `@simplewebauthn/browser` presence/absence handling, and current templates do not import it today. [VERIFIED: ROADMAP.md] [VERIFIED: codebase grep]
   - What's unclear: Whether package wiring alone is enough for PK-01 continuity, or whether the generated JS must be refactored in the same phase to consume the package. [VERIFIED: codebase grep]
   - Recommendation: Treat package wiring and import-site alignment as Phase 22 planning scope unless prior implementation artifacts prove another phase already satisfied PK-01 in generated output. [VERIFIED: REQUIREMENTS.md]

2. **Where should passkey router routes live after the refactor?**
   - What we know: Locked context allows either local guards in Core or moving whole passkey-only targets into `Features.Passkeys`, as long as readability drives the call. [VERIFIED: 22-CONTEXT.md]
   - What's unclear: Whether the router block stays readable with local guards once dependency wiring and package edits are added. [ASSUMED]
   - Recommendation: Decide during planning after a small route-block inventory; prefer local guards first, then move a discrete passkey fragment if Core gets noisy. [VERIFIED: 22-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Installer, tests, CI scripts | ✓ | Mix 1.19.5 [VERIFIED: local shell] | — |
| Node.js | JS hook/runtime tests and assets-enabled smoke | ✓ | v22.14.0 [VERIFIED: local shell] | — |
| `npm` | `@simplewebauthn/browser` version verification and asset deps | ✓ | 11.1.0 [VERIFIED: local shell] | — |
| Docker | Local disposable Postgres option from project docs | ✓ | 29.3.1 [VERIFIED: local shell] | Existing local Postgres on 5432 [VERIFIED: CLAUDE.md] |
| Postgres | Full test suite and smoke harness | Unknown in-session runtime, but required [VERIFIED: CLAUDE.md] | — | Use provided Docker one-liner from `CLAUDE.md` [VERIFIED: CLAUDE.md] |

**Missing dependencies with no fallback:**
- None identified from tool probing. [VERIFIED: local shell]

**Missing dependencies with fallback:**
- Live local Postgres was not probed directly here, but `CLAUDE.md` provides a Docker fallback and CI service shape. [VERIFIED: CLAUDE.md] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix project tests [VERIFIED: codebase grep] |
| Config file | `mix.exs` aliases and standard ExUnit setup; no separate `pytest`-style config [VERIFIED: codebase grep] |
| Quick run command | `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs -x` [VERIFIED: codebase grep] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-02 | `--no-passkeys` omits passkey files/routes/helpers/deps and still compiles | integration + generator | `mix test test/sigra/install/generator_passkeys_opt_out_test.exs -x` | ❌ Wave 0 |
| PK-02 | Four-way org x passkeys install matrix compiles and boots | CI smoke | `.github/workflows/ci.yml` `install_matrix` extension | ❌ Wave 0 |
| PK-02 | Assets-enabled no-passkeys install omits JS files and `@simplewebauthn/browser` | smoke + omission | `scripts/ci/passkeys-opt-out-smoke.sh` | ❌ Wave 0 |
| PK-02 | Default install still emits passkey artifacts after default flip | generator regression | `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs -x` | ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/generator_passkeys_foundation_test.exs -x` [VERIFIED: codebase grep]
- **Per wave merge:** `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs -x` [VERIFIED: codebase grep]
- **Phase gate:** Full suite green plus CI matrix green before `/gsd-verify-work`. [VERIFIED: .planning/config.json] [VERIFIED: .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] `test/sigra/install/generator_passkeys_opt_out_test.exs` — proves `--no-passkeys` omission across generated files, routes, helpers, migrations, and grep checks. [VERIFIED: codebase grep]
- [ ] `scripts/ci/passkeys-opt-out-smoke.sh` — assets-enabled omission harness for `assets/js/*` and `assets/package.json`. [VERIFIED: codebase grep]
- [ ] `.github/workflows/ci.yml` install-matrix expansion to `""`, `--no-passkeys`, `--no-organizations`, `--no-organizations --no-passkeys`. [VERIFIED: .github/workflows/ci.yml]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Omit passkey auth surfaces entirely on `--no-passkeys`; keep enabled-path auth routes explicit and controller-owned. [VERIFIED: 22-CONTEXT.md] [VERIFIED: 21-CONTEXT.md] |
| V3 Session Management | yes | Passkey controller paths rely on standard Plug session mutation APIs and must disappear entirely when disabled. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: codebase grep] |
| V4 Access Control | yes | Passkey delete/enrollment routes stay in sudo/authenticated scopes only when the feature is enabled. [VERIFIED: 21-CONTEXT.md] [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Existing generated controller and auth wrappers handle passkey response decoding and should be omitted, not stubbed, on disabled installs. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | Keep `wax_` for enabled installs and avoid custom cryptographic substitutions. [VERIFIED: REQUIREMENTS.md] [VERIFIED: hex.pm wax_] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Partial-apply route leak | Elevation of Privilege | Four-way matrix plus omission assertions for disabled installs. [VERIFIED: 22-CONTEXT.md] |
| Dead dependency / dead code drift | Tampering | Feature-owned dependency wiring and explicit absence checks for `wax_` and `@simplewebauthn/browser`. [VERIFIED: 22-CONTEXT.md] |
| Session mutation surface left reachable after opt-out | Elevation of Privilege | Omit passkey controller actions and routes entirely, rather than hiding UI. [VERIFIED: 22-CONTEXT.md] |
| Silent asset rewrite failure | Tampering | Deterministic edits first, exact manual instructions second, never silent partial success. [VERIFIED: 20-CONTEXT.md] [VERIFIED: 22-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- [VERIFIED: 22-CONTEXT.md] - locked passkey omission contract, ownership rules, and verification posture
- [VERIFIED: 11-CONTEXT.md] - manifest contract and purely additive invariant
- [VERIFIED: .planning/ROADMAP.md] - Phase 22 goal, success criteria, and dependency chain
- [VERIFIED: .planning/REQUIREMENTS.md] - PK-02 and related generator requirements
- [VERIFIED: CLAUDE.md] - project constraints and local test prerequisites
- [VERIFIED: codebase grep] - current defaults, template ownership, router injection, CI matrix shape, and missing assets/package wiring
- [VERIFIED: npm registry] - `@simplewebauthn/browser` current version `13.3.0` and publish date `2026-03-10`
- [VERIFIED: hex.pm phoenix](https://hex.pm/packages/phoenix) - Phoenix `1.8.5`, updated `2026-03-05`
- [VERIFIED: hex.pm wax_](https://hex.pm/packages/wax_) - `wax_` `0.7.0`, updated `2025-05-18`

### Secondary (MEDIUM confidence)

- [CITED: https://hexdocs.pm/phoenix/1.8.5/Mix.Tasks.Phx.Gen.Auth.html] - Phoenix generator posture and generated-code customization model
- [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] - LiveSocket hook registration and hook lifecycle
- [CITED: https://simplewebauthn.dev/docs/packages/browser] - browser methods and conditional UI helpers
- [CITED: https://hexdocs.pm/plug/Plug.Conn.html] - standard Plug session mutation API

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions and patterns were verified against npm/Hex and official docs. [VERIFIED: npm registry] [VERIFIED: hex.pm phoenix] [VERIFIED: hex.pm wax_]
- Architecture: HIGH - the repo’s current feature manifest, core template ownership, and CI harness shape are all directly inspectable. [VERIFIED: codebase grep]
- Pitfalls: HIGH - every major pitfall is grounded in current code plus locked phase context. [VERIFIED: codebase grep] [VERIFIED: 22-CONTEXT.md]

**Research date:** 2026-04-16
**Valid until:** 2026-05-16
