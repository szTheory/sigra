---
phase: 229-adoption-handoff-terminal-ratification
verified: 2026-07-27
status: passed
score: 15/15 requirements complete
---

# v1.46 Adoption Handoff Verification

## Verdict

Implementation and automated proof are complete. PROOF-03's human-acceptance clause was satisfied on 2026-07-27 (see Human Acceptance below). The phase is closed at 15/15.

## Requirement Result

| Requirement | Result | Evidence |
| --- | --- | --- |
| EXPR-01/02 | Pass | Phase 224 contract, UI-SPEC, representative generated-host evidence |
| BOOT-01/02/03 | Pass | Admin generator contracts and fresh-host grant/revoke lifecycle |
| SEC-01 | Pass | Generated impersonation-parity contract and full suite |
| AUTHUI-01/02 | Pass | Semantic-template contract and fresh-host auth browser run |
| AUTHUI-03/04 | Pass | Settings/security contracts, axe/focus/theme/reflow/browser evidence |
| AUDIT-01/02 | Pass | LiveView implementation plus preset/manual Playwright coverage |
| PROOF-01 | Pass | Fresh-host install-to-revocation acceptance smoke |
| PROOF-02 | Pass | Golden drift/idempotency, feature ownership, docs and upgrade reconciliation |
| PROOF-03 | Pass | All automated clauses pass; human visual acceptance recorded 2026-07-27 (see Human Acceptance) |

## Terminal Evidence

- Repository: 33 doctests, 3 properties, 2,438 tests, 0 failures, 12 skipped (3 excluded).
- Focused contract suite: 153 tests, 0 failures.
- Golden/idempotency: 4 tests, 0 failures; rebless check reports no drift.
- Generated host: warnings-as-errors compile, policy test, migrate, grant/check/list, browser journey, revoke/check denial, and browser denial pass.
- UI: post-interaction axe, keyboard/focus, Light/Dark/System, reduced motion, forced-colors contract, 320px/200% reflow, long-content wrapping, and 35 KB CSS budget pass.

## Human Review Scope

Review only the captured login composition in light, system-dark, and 320px/200% reflow. Security semantics, action order, contrast automation, interaction behavior, and responsive containment are already gated; the remaining judgment is visual hierarchy and taste.

## Human Acceptance (PROOF-03)

**Accepted 2026-07-27.** The three in-scope captures were assembled into a side-by-side
review page and reviewed directly by the project owner, who independently reached the
same findings ("i agree with your feedback... you were accurate and i noticed them too")
and then directed the disposition of each.

Captures reviewed — the post-CSS-specificity-correction run (17:51), not the superseded
17:49 set:

```
test/example/priv/playwright/test-results/css-specificity/
  admin-generated-generated--4f63b-ves-theme-and-reflow-states-admin-generated/
    auth-auth-login-light-admin-generated.png              (1280 × 1178)
    auth-auth-login-system-dark-admin-generated.png        (1280 × 1178)
    auth-auth-login-system-dark-320-reflow-admin-generated.png  (320 × 1718)
```

Four findings surfaced; disposition of each:

| # | Finding | Disposition |
| --- | --- | --- |
| 1 | Both the magic-link and password forms label their email field "Email", colliding once the "Other ways to sign in" disclosure is expanded | **Fixed** — quick task `260727-v15`, merged as PR #113 (`743864c0`) |
| 2 | Submit buttons appeared to read as text rather than buttons | **Not a defect** — evidence was the superseded 17:49 capture set; the current run shows the primary action taking the accent fill with outlined secondaries, which is the intended hierarchy |
| 3 | Ember box around the "Other ways to sign in" disclosure | **Not a defect** — that is the `:focus-visible` ring (`sigra_auth.css:765`); the resting rule at `:239` declares no border or background |
| 4 | Product name hyphenates mid-token ("SigraAdminSm / oke") at 320px/200% | **Deliberate accept** — the string is the acceptance harness's generated app name, not a product name, and WCAG reflow containment already passes. Recorded with full rationale and the open design question in `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md` |

The acceptance is for visual hierarchy and taste only, which is the entirety of what this
gate reserved for a human. Every other clause was already machine-gated.

