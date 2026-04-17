# Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 20 owns the **edge seam** between Sigra's passkey library code and the generated Phoenix host app:

- `Sigra.Plug.PasskeyChallenge` stores and verifies WebAuthn ceremony challenges in the Plug session
- runtime passkey config is loaded, validated, and normalized for RP identity and ceremony behavior
- per-user ceremony initiation is rate-limited
- `passkey_hooks.js` becomes the blessed JS boundary for LiveView/browser ceremonies
- the generator wires that hook boundary into standard Phoenix assets automatically, and falls back to exact manual instructions for custom bundlers

This phase does **not** own the full enrollment/authentication UX, controller screens, or LiveView flows. Those land in Phase 21 and must build on the seams defined here.

</domain>

<decisions>
## Implementation Decisions

### Challenge contract

- **D-01 (session storage shape):** Use **explicit ceremony-specific session slots**, not one polymorphic challenge envelope and not a generic challenge-store abstraction. The Plug layer owns two namespaced session keys:
  - registration challenge slot
  - authentication challenge slot
  Each slot stores a small common envelope with only the fields needed to verify and invalidate the ceremony.

- **D-02 (generation and verification contract):** `Sigra.Plug.PasskeyChallenge` generates the challenge with `Sigra.Token.generate/4`, purpose `"sigra-passkey-challenge"`, `max_age: 60`, stores it in the appropriate Plug session slot, verifies against the stored value on response, and never trusts `clientDataJSON` as the challenge source.

- **D-03 (deletion semantics):** Challenge records are **single-use**. On successful verify, the plug deletes the corresponding session slot immediately. Failed verification does not mint or trust a replacement value. Replay protection is part of the plug boundary, not delegated to the LiveView/controller caller.

- **D-04 (Plug/library boundary):** The Phase 19 split remains load-bearing:
  - `Sigra.Passkeys.Registration` and `Sigra.Passkeys.Authentication` stay `Plug.Conn`-free and explicit-challenge
  - `Sigra.Plug.PasskeyChallenge` is the Phoenix/Plug edge adapter that fetches, issues, verifies, and invalidates session-held challenges
  This preserves clean library isolation while keeping session concerns at the web edge.

- **D-05 (no generic store yet):** Do **not** introduce a behavior-backed challenge store abstraction in Phase 20. The roadmap explicitly locks storage to Plug session, and adding an abstraction now would add indirection without solving a current project problem.

### Runtime config posture

- **D-06 (config loading posture):** Use a **mixed runtime contract**:
  - strict validation for security-critical identity/config invariants
  - safe defaults for operator tunables
  - no `Application.get_env` lookups in ceremony hot paths
  Runtime config is resolved once, validated, normalized into `%Sigra.Config{}` / `config.passkeys`, then passed explicitly downstream.

- **D-07 (required runtime keys):** `rp_id` and `origin` are required and validated at boot or config-build time. Invalid or missing values fail loudly with precise remediation text. Sigra should not defer RP identity mistakes to ceremony runtime.

- **D-08 (validated enums and bounded tunables):**
  - `attestation` remains explicit and validated; default `:none`
  - `user_verification` remains explicit and validated against supported values
  - `timeout_ms` is bounded and normalized
  - ceremony initiation rate limit defaults to **5/min per user** and validates override shape

- **D-09 (dev/prod ergonomics):** Developer ergonomics come from **clear startup errors and documented defaults**, not from permissive silent coercion. The system should be easy to configure correctly, but misconfigured RP identity must fail fast.

- **D-10 (configuration ownership):** Runtime config loading belongs to Sigra's existing `%Sigra.Config{}` pattern, not to the hook layer, not to ad hoc endpoint config reads in controllers, and not to generator-only docs. Phase 20 should extend the established config-first posture rather than invent a passkey-specific exception.

### Hook API shape

- **D-11 (public JS seam):** `passkey_hooks.js` exports **generated rich Phoenix hook objects**, not only thin helper functions. Phase 21 templates should be able to mount a stable, batteries-included hook boundary without host apps rewriting ceremony lifecycle logic.

- **D-12 (hook set):** Generate explicit hook objects for the two ceremony roles:
  - registration hook
  - authentication hook
  Shared helpers may live behind them, but the public seam should be hook-oriented because Phoenix LiveView already treats browser integration through `phx-hook`.

- **D-13 (event contract):** Hooks must always return explicit outcomes to the server side:
  - success
  - error
  - aborted
  No silent failures, swallowed browser exceptions, or host-app-specific ad hoc event naming as the default path.

- **D-14 (lifecycle cleanup):** Hook teardown must cancel in-flight ceremonies on `destroyed` and `disconnected`, using the browser/library abort mechanism rather than leaving stale browser state alive across LiveView navigation or reconnect churn.

- **D-15 (data flow posture):** Hooks consume server-provided ceremony options, invoke the browser WebAuthn API, and push normalized results back to LiveView/controller endpoints. The host app should not have to assemble raw browser payload plumbing itself on the blessed path.

### Generator asset wiring

- **D-16 (standard-path injection posture):** Use **strict marker-based injection** into `assets/js/app.js` for the standard Phoenix asset layout. This matches Sigra's existing generator architecture: deterministic, idempotent, and easy to test.

- **D-17 (custom layout fallback):** If the marker comment is absent, Sigra still writes `passkey_hooks.js` but **does not attempt heuristic rewrites** of custom Vite/Webpack/esbuild entrypoints. Instead it prints exact manual instructions with the precise import and hook-registration lines to add. No silent partial success.

- **D-18 (no heuristics):** Do **not** scan likely files like `main.js`, `app.ts`, or bundler-specific entrypoints and guess where to inject. That would trade small DX gains for brittle edits and reduced user trust in generator output.

- **D-19 (phase-21 readiness):** The generated import/registration contract must be stable enough that Phase 21 can assume a standard hook name and registration shape in generated templates, while still offering manual instructions when a host app is off the blessed asset path.

### Cross-cutting architecture

- **D-20 (single architectural stance across all four areas):** Phase 20 should be **opinionated at the edges, explicit in contracts, and conservative about hidden magic**:
  - explicit session slots instead of generic abstraction
  - explicit runtime config validation instead of permissive lazy reads
  - explicit hook objects instead of app-owned ceremony glue
  - explicit marker-based generator wiring instead of heuristics
  This is the most coherent path with Sigra's project goals: secure-by-default, generator-trustworthy, Phoenix-native, and ready for additive Phase 21 UX work.

### the agent's Discretion

- Exact internal module names for session helper utilities and hook helper functions
- Exact session envelope field names, so long as they remain ceremony-specific and minimal
- Exact client event names and payload keys, so long as success/error/aborted are all represented explicitly and documented
- Exact marker-comment wording in `assets/js/app.js`, so long as injection remains deterministic and idempotent
- Exact timeout bounds and error-message phrasing, so long as config validation remains strict for identity fields and clear for tunables

</decisions>

<specifics>
## Specific Ideas

- Treat `Sigra.Plug.PasskeyChallenge` as the **web-edge adapter** for the Phase 19 ceremony primitives, not as a new passkey brain.
- Keep the session envelope intentionally small: ceremony kind is implied by the slot; store only what verification and replay invalidation need.
- The JS contract should feel like a normal Phoenix LiveView integration, not like embedding a third-party mini-framework into host apps.
- The generator should optimize for the trusted Phoenix happy path and be honest when a project is outside that path.
- The overall posture for this phase is: **strict invariants, minimal hidden magic, good defaults where safe**.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 20 internal (authoritative)
- `.planning/ROADMAP.md` §Phase 20 — goal, spike requirement, success criteria, and locked behaviors for session-only challenge storage, 60s TTL, rate limiting, and `assets/js/app.js` injection/fallback.
- `.planning/REQUIREMENTS.md` — passkey requirements and generator requirement `GEN-06`; use as the acceptance-criteria source for config, rate-limit, and wiring behavior.
- `.planning/PROJECT.md` — project-level passkey and generator scope; reinforces the hybrid lib+generator posture and the Phoenix blessed-path constraint.
- `.planning/STATE.md` — confirms Phase 20 is the current focus and sits in the passkey track after Phase 19.

### Prior phase carry-forward
- `.planning/phases/19-passkey-schema-contexts/19-CONTEXT.md` — load-bearing Phase 19 decisions:
  - challenge stays caller-owned and Plug-free at the library layer
  - `config.passkeys` contract already exists
  - sign-count and credential-confusion defenses are already owned in library code

### Local code patterns to mirror
- `lib/sigra/token.ex` — signed-token generation/verification primitive used for challenge issuance and expiry semantics.
- `lib/sigra/config.ex` — `%Sigra.Config{}` schema and validation precedent; Phase 20 should extend this pattern rather than bypass it.
- `lib/sigra/passkeys/registration.ex` — explicit-challenge registration primitive from Phase 19; Phase 20 must preserve this contract.
- `lib/sigra/passkeys/authentication.ex` — explicit-challenge authentication primitive from Phase 19; Phase 20 plugs adapt around this.
- `lib/sigra/passkeys.ex` — public passkey context shape and config-first API precedent.
- `lib/sigra/plug/rate_limit.ex` — Sigra's existing rate-limit plug design; Phase 20 should mirror its Plug ergonomics while changing the key shape to per-user ceremony initiation.
- `lib/sigra/install/injector.ex` — current idempotent marker-based injection machinery; Phase 20 asset wiring should follow this architecture.
- `lib/sigra/install/features/core.ex` — standard feature/injection pattern and blessed-path generator posture.
- `lib/sigra/install/features/passkeys.ex` — existing passkeys feature owner that Phase 20 will extend.
- `test/example/priv/static/assets/js/app.js` — current generated JS entrypoint shape that Phase 20's marker-based injection targets.

### Official docs / external standards
- `https://hexdocs.pm/plug/Plug.Conn.html` — `fetch_session/2`, `put_session/3`, `delete_session/2`, and session configuration semantics for the Plug edge.
- `https://hexdocs.pm/elixir/main/config-and-releases.html` — runtime config posture for releases; informs strict-vs-defaulted passkey config decisions.
- `https://hexdocs.pm/phoenix_live_view/js-interop.html` — Phoenix LiveView hook lifecycle and browser interop contract.
- `https://simplewebauthn.dev/docs/packages/browser` — browser ceremony surface and error/abort behaviors that inform `passkey_hooks.js`.
- `https://simplewebauthn.dev/docs/advanced/server/custom-challenges` — server-side challenge storage/verification guidance consistent with session-backed challenge ownership.
- `https://www.w3.org/TR/webauthn-3/` — WebAuthn challenge handling and verification model; informs replay resistance and server-side challenge trust boundaries.
- `https://hexdocs.pm/hammer/7.1.0/readme.html` — Hammer rate-limit model for the per-user ceremony throttle.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Token`** already provides the signed-token primitive Phase 20 needs for 60-second passkey challenges.
- **`Sigra.Config`** already centralizes validated auth configuration; passkey runtime loading should extend it.
- **`Sigra.Plug.RateLimit`** already demonstrates Sigra's style for Plug-based throttling and telemetry.
- **`Sigra.Install.Injector`** already provides the marker-based injection architecture the asset wiring should reuse.
- **`Sigra.Install.Features.Passkeys`** is the correct feature owner for passkey-specific generated files and post-install instructions.

### Established Patterns
- **Config-first APIs:** public Sigra surfaces take `%Sigra.Config{}` first and avoid ambient config reads in hot code paths.
- **Hybrid lib + generator split:** security-critical logic lives in library modules; generated host files provide Phoenix integration and app-owned seams.
- **Conservative generator trust model:** Sigra favors deterministic, marker-based writes over clever heuristics.
- **Plug concerns at the edge:** session and request lifecycle concerns belong in plugs/controllers/LiveViews, not in core credential primitives.

### Integration Points
- `Sigra.Plug.PasskeyChallenge` will sit between the generated Phoenix app and the Phase 19 primitives.
- Passkey runtime validation should attach to config construction / host runtime configuration, not ad hoc caller code.
- The rate-limit implementation should integrate with Sigra's existing Plug and telemetry posture while using a user-scoped ceremony key.
- `passkey_hooks.js` and `assets/js/app.js` injection become the Phase 20 asset seam that Phase 21 templates depend on.

</code_context>

<deferred>
## Deferred Ideas

- Generic behavior-backed challenge store (ETS/Redis/distributed adapters) — out of scope unless a later phase introduces a real non-session requirement.
- Heuristics-based bundler entrypoint rewriting beyond `assets/js/app.js` marker detection — explicitly rejected for this phase.
- Fully app-owned custom hook contract as the default path — leave as an escape hatch, not the blessed Sigra architecture.
- Full passkey UX flows, templates, emails, and route/controller/liveview surfaces — Phase 21.

</deferred>

---

*Phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra*
*Context gathered: 2026-04-15*
