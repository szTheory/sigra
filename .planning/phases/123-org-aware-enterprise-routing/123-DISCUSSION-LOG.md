# Phase 123: Org-Aware Enterprise Routing - Discussion Log

**Date:** 2026-05-25
**Mode:** Discuss all + advisor-style parallel research synthesis
**Status:** Complete

## User Direction

The user requested that all gray areas be discussed in one pass and that the recommendations:
- use subagents
- compare pros/cons/tradeoffs
- reflect idiomatic Elixir/Plug/Ecto/Phoenix design for a library plus generated-host app
- learn from successful auth systems in Elixir and other ecosystems
- emphasize least surprise, good software architecture, strong DX, and user-friendly UX
- be coherent as a single recommendation set so planning can proceed without reopening the same questions
- shift these preferences left in future GSD discussions except where decisions are unusually high-impact

## Gray Areas Discussed

### 1. Entry path shape

Options considered:
- Explicit org route only
- Generic login enterprise branch only
- Both explicit org route and generic discovery entry

Decision:
- Use both, but keep the explicit org-scoped enterprise route canonical.
- Generic enterprise discovery is convenience only and must redirect into the canonical org route before starting OIDC.

Why this won:
- Best fit for Sigra’s existing URL-owned org model
- Preserves shareable deterministic org entry
- Still gives first-time enterprise users a friendly “use your work email” path
- Avoids creating a second, competing truth surface

### 2. Email-domain discovery behavior

Options considered:
- Immediate auto-routing on unique active verified match
- Auto-routing plus confirmation step
- Minimal discovery that mostly pushes users to explicit org entry

Decision:
- Auto-route only on an exact match to one active connection with a verified, uniquely owned domain.
- All other cases stop discovery and require explicit org entry.

Why this won:
- Keeps the happy path short
- Matches strong prior art for identifier-first routing
- Maintains security by treating discovery as convenience, not trust
- Avoids heuristics, suffix matching, wildcard matching, and “first match wins”

### 3. Failure and ambiguity UX

Options considered:
- Silent or soft fallback to normal login
- Fail closed with explicit error
- Fail closed with explicit enterprise retry flow

Decision:
- Fail closed and recover through an explicit enterprise org-entry retry flow.
- Never silently downgrade into normal login.
- If another auth mode is still allowed, show it only as a separate explicit choice outside the enterprise-routing path.

Why this won:
- Preserves routing and operator truth
- Avoids teaching users that enterprise login can silently become something else
- Keeps future SSO-only enforcement compatible
- Gives users a recovery path without turning failure into ambiguity

### 4. Org truth during and after login

Options considered:
- Keep org mostly hidden
- Show lightweight explicit org truth
- Build a stronger branded enterprise handoff

Decision:
- Show lightweight explicit org truth before redirect and on return/error states.
- Do not build branded enterprise theming or a hosted-IdP-style handoff in this phase.

Why this won:
- Aligns with Sigra’s existing session and audit truth
- Reassures the user about which organization is in scope
- Keeps library-versus-generated-host boundaries clean
- Avoids overbuilding the first routing wedge

## Cohesive Recommendation Set

The four decisions were intentionally locked as one coherent posture:

1. Canonical org-scoped enterprise route is the source of truth.
2. Generic enterprise discovery may exist, but only as a bounded convenience that resolves into the canonical route.
3. Domain discovery only works on exact, unique, verified, active matches.
4. Discovery ambiguity or unusable connections fail closed back into explicit enterprise org entry, not into generic login.
5. Once org context is resolved, generated-host UI should name that org lightly but clearly before redirect and on return/error.
6. Library code remains authoritative for org resolution, callback binding, session attribution, and audit attribution.

## Shift-Left Defaults Captured

These should become the default recommendation posture in future GSD discussions for similar Sigra auth-routing decisions unless the user explicitly overrides:

- Prefer canonical scoped route first, convenience discovery second.
- Prefer bounded exact-match discovery over heuristics.
- Prefer fail-closed same-mode recovery over silent downgrade.
- Prefer lightweight explicit tenant/org truth at auth boundaries.
- Reuse existing library-owned runtime truth rather than adding parallel host-owned auth logic.

## Key Footguns Recorded

- Starting OIDC directly from generic login before org is uniquely resolved
- Re-discovering org at callback time from email alone
- Matching on shared, wildcard, suffix, duplicate, pending, or disabled domains
- Treating confirmation UI as the security boundary instead of binding org/connection identity into signed state/session
- Silently dropping the user into password or magic-link login after enterprise routing fails
- Overbuilding branded enterprise UX that blurs Sigra’s library-versus-generated-host ownership

## Artifacts Used

- Local planning and milestone research under `.planning/`
- Existing Sigra OAuth, auth, org, and enterprise connection code
- Current example/generated-host login and org routing surfaces
- Prompt-library guidance under `prompts/`
- Parallel advisor research across all four gray areas

## Outcome

The discussion is complete. The decisions above were written into `123-CONTEXT.md` as locked guidance for downstream research, planning, and implementation.
