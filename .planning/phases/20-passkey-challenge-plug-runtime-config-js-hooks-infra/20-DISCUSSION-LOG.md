# Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra - Discussion Log

**Date:** 2026-04-15
**Mode:** Delegated one-shot recommendations
**Status:** Completed

## Request

User asked to:

- discuss all identified gray areas
- use background subagents for efficiency
- research lessons from other libraries and idiomatic Elixir/Plug/Ecto/Phoenix patterns
- optimize for DX, coherent architecture, and project goals
- provide a one-shot recommendation set so the user would not need to make the decisions manually

## Areas Covered

1. Challenge contract
2. Runtime config posture
3. Hook API shape
4. Generator asset wiring

## Inputs Considered

### Local project context

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/19-passkey-schema-contexts/19-CONTEXT.md`
- `lib/sigra/token.ex`
- `lib/sigra/config.ex`
- `lib/sigra/passkeys.ex`
- `lib/sigra/passkeys/registration.ex`
- `lib/sigra/passkeys/authentication.ex`
- `lib/sigra/plug/rate_limit.ex`
- `lib/sigra/install/injector.ex`
- `lib/sigra/install/features/core.ex`
- `lib/sigra/install/features/passkeys.ex`
- `test/example/priv/static/assets/js/app.js`

### External references consulted

- Plug session docs
- Elixir runtime config / releases docs
- Phoenix LiveView JS interop / hooks docs
- WebAuthn spec guidance
- SimpleWebAuthn browser and custom-challenge docs
- Hammer docs

## Delegated Research Results

### 1. Challenge contract

Subagent recommendation:
- Use explicit registration/authentication session slots
- Keep challenge ownership at the Plug edge
- Do not introduce a generic challenge store yet

Adopted because:
- It matches the Phase 19 split between registration and authentication primitives
- It is the least ambiguous verification path
- It keeps Plug session concerns out of the library layer

### 2. Runtime config posture

Subagent recommendation:
- Use a mixed contract: strict validation for invariants, defaults for tunables

Adopted because:
- `rp_id` and `origin` are security-critical and must fail fast
- It fits Phoenix `runtime.exs` expectations
- It preserves Sigra's `%Sigra.Config{}` first-arg pattern

### 3. Hook API shape

Subagent recommendation:
- Generate rich Phoenix hook objects with an explicit event contract

Adopted because:
- It is the most idiomatic Phoenix LiveView seam
- It centralizes abort/error handling instead of duplicating it in every host app
- It gives Phase 21 a stable generated client contract

### 4. Generator asset wiring

Subagent recommendation:
- Use strict marker-based injection into `assets/js/app.js`
- Fall back to exact manual instructions when the marker is absent
- Reject heuristics-based rewriting

Adopted because:
- It matches Sigra's current generator philosophy
- It preserves user trust in generator edits
- It keeps the blessed Phoenix path ergonomic without guessing on custom bundlers

## Final Decision Set

The final decision set was intentionally made as one coherent architecture rather than four isolated picks:

- explicit ceremony-specific session slots
- strict runtime validation for identity-critical passkey config
- rich generated LiveView hook objects with explicit success/error/aborted outcomes
- deterministic marker-based `assets/js/app.js` injection with exact manual fallback

## Why These Decisions Fit Together

- They all prefer explicit contracts over hidden magic.
- They keep the library layer pure and the Phoenix integration at the edge.
- They improve generator trustworthiness instead of adding brittle automation.
- They optimize for Phase 21 reuse without introducing speculative abstractions early.
- They align with the project goal of a secure-by-default, Phoenix-native additive system.

## User Direction Captured

The user explicitly delegated the decision-making:

- wanted all areas covered
- wanted background subagent research
- wanted best-practice and architecture-informed recommendations
- wanted the agent to choose rather than return an interactive choice matrix

This log records that Phase 20 context was produced from delegated architectural recommendations, not from a turn-by-turn manual questionnaire.

