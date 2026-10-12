# Phase 246: Generated Confirmation Recovery - Discussion Log (Assumptions Mode)

> **Audit trail only.** Decisions are captured in CONTEXT.md — this log preserves the research and alternatives.

**Date:** 2026-10-06
**Phase:** 246-Generated Confirmation Recovery
**Mode:** assumptions
**Areas analyzed:** confirmation access/session policy; token-link state change; code paste and account binding; visible feedback/accessibility; automated evidence

## User Direction

The user asked for comprehensive, decision-focused research across the applicable engineering, security, Phoenix/Elixir, adopter-DX, and UX lenses, then asked that the strongest recommendations be followed without handing routine choices back. These recommendations preserve the previously accepted phase requirements. One security limitation remains explicit in CONTEXT.md because this phase's anonymous-link requirement does not eliminate account pre-hijacking.

## Codebase Assumptions Presented

### Confirmation access/session contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Link confirmation supports anonymous and signed-in visitors; code/resend require the signed-in current account and missing scope gets clear guidance. | Confident | .planning/ROADMAP.md; .planning/REQUIREMENTS.md; .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md; priv/templates/sigra.install/core/confirmation_live.ex; priv/templates/sigra.install/core/user_auth.ex |

### Token link state change
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Opening a link should render a confirmation page; an explicit submit performs the mutation without creating or switching a session. | Likely | Current token mutation runs in handle_params; RFC 9110 safe-method semantics; Microsoft Safe Links; django-allauth POST confirmation form and configurable GET confirmation |

### Code paste and account binding
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Accept the exact spaced value shown in the email, normalize allowed whitespace server-side, validate six ASCII digits, and bind lookup to the current user before update. | Confident | priv/templates/sigra.install/core/emails.ex; confirmation_live.ex; priv/templates/sigra.install/core/auth.ex; lib/sigra/auth.ex; user_token.ex; SEED-011 and the phase-matched todo |

### Feedback and accessibility
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Render shared generated auth flashes with visible localized success/error feedback and non-disruptive accessible announcements using existing styles. | Confident | priv/templates/sigra.install/core/sigra_auth_components.ex; sigra_auth.css; Phoenix LiveView docs; WCAG 2.2 status-message guidance |

### Regression proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Combine focused LiveView/integration tests with one fresh-host real-browser paste path; keep the recurring check narrow and required in CI. | Confident | scripts/ci/install-smoke.sh; test/sigra/install/generator_email_test.exs; .planning/METHODOLOGY.md; Phoenix.LiveViewTest |

## Research Synthesis

Five GSD advisor research passes covered Phoenix route/session policy, code paste and account binding, feedback and verification seams, established auth prior art, and email link-scanner behavior; a separate assumptions analyzer inspected the codebase and project prompts. Findings converged on the decisions recorded in CONTEXT.md. Additional broad framework comparisons would not change these phase decisions.

## Corrections

No correction turn was requested: the user explicitly delegated recommendation-first decisions for this discussion. The repo methodology supports auto-resolving implementation defaults when evidence converges; the account-pre-hijacking limitation is recorded as a residual product risk, not treated as resolved by this phase.

## Folded Todo

- .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md (score 0.9; explicitly marked resolves_phase: 246) — folded. Other loose keyword matches were not treated as phase scope.
