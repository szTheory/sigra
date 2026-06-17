# Phase 190: Flows & Fixture Data (L4) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-17
**Phase:** 190-flows-fixture-data-l4
**Mode:** assumptions (+ deep multi-agent research at user request)
**Areas analyzed:** Ledger shape & spec organization; Persona→flow mapping & DATA-01 fixture;
Fixture parity scope; Keyboard/reduced-motion/theme test strategy; Return-context continuity;
Investigator posture (UI/UX + doctrine); Microcopy/brand voice.

## Assumptions Presented

### Ledger shape & spec organization (FLOW-01..03, DATA-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| L4 = 3 ledger rows (one per persona flow), not per-requirement | Likely | ledger one-row-per-surface (L1=13/L2=11/L3=6) `admin-quality-ledger.md:36-66`; monotonic guard `^\| [a-z]` |
| New dedicated flow spec(s) on chromium behavior lane, not checkpoints/feature specs | Likely | `playwright.config.ts:88-145`; 189 dedicated `admin-modal-interaction.spec.ts` (189 D-13) |

### Persona→flow mapping & DATA-01
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| DATA-01 satisfied by existing `Example.Demo.Seeds.run/0`; zero/minimal enrichment | Likely | `personas.ex:51-180`, `seeds.ex:223-631` seed states + audit narratives |
| investigator = admin persona in investigation posture (no new user) | Likely (contested) | analyzer flagged; resolved by doctrine research below |
| happy=alice / error=dave+permission-denied / boundary=frank·grace+invites+empty | Likely | seeded states + `demo-showcase`/`admin-coherence-sweep` already log in as these |

### Fixture parity scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Seed enrichment example-only; no priv/templates change; no mirror duty | Confident | `seeds.ex:1-20` MIX_ENV guard; parity rule governs CSS/JS only; DATA-01 wording "demo seed data" |

### Keyboard / reduced-motion / theme (FLOW-02, FLOW-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Test authoring over existing behavior; no net-new CSS/JS | Likely | reduced-motion guard `sigra_admin.css:1467`; theme hook `admin_hooks.js:25,54-83`; `admin-theme.spec.ts:396-485` |

### Return-context continuity (FLOW-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Assert existing continuity (URL scope, breadcrumb, banner), not new plumbing | Likely | `impersonation.spec.ts:130-143`; 189 D-09; deferred to 190 in `189-CONTEXT.md:185` |

## Corrections Made

No assumptions were *overturned*. The user (Jon) requested deep multi-agent research across all
decision areas before locking — pros/cons/tradeoffs, idiomatic Elixir/Phoenix, cross-ecosystem
prior-art lessons, DX, and a UI/UX + user-psychology + creative-direction lens, mining the repo
`prompts/` and v2 brand book. Three parallel research agents were spawned (local doctrine mining;
ecosystem/prior-art for flow-test architecture + seed fixtures + a11y + theme + ledger; UI/UX +
user-psychology for the investigator persona, continuity, keyboard, theme, microcopy).

### Investigator posture — the one genuinely contested call
- **Codebase analyzer assumption:** support investigator = the admin persona in investigation
  posture; no new seeded user.
- **Ecosystem UI/UX research finding:** best-in-class identity products (Auth0/Okta/Clerk/WorkOS/
  Stripe) model the investigator as a **distinct least-privilege read-only role**, with impersonation
  as a separate RBAC-gated break-glass capability (mandatory reason, non-dismissable banner,
  auto-expiry, dual-log actor-vs-subject `act` claim, subject notification).
- **Sigra doctrine finding (decisive):** `admin-ui-principles.md:11` names "support investigator"
  as a persona but with **no separate authz tier** — entry-point/need-distinguished; the seed has no
  investigator user; the scorecard's canonical L4 flow is `login → overview → user detail →
  impersonation → audit review → sign-out`; impersonation is already a shipped, audited lib feature.
- **Resolution:** Phase 190 keeps the doctrine posture (admin-in-investigation-posture, no new role) —
  it is a grading/test-authoring phase over built UI, and a net-new least-privilege RBAC role would
  change the security model (out of L4 scope, escalation-worthy under METHODOLOGY). The distinct
  least-privilege role + break-glass hardening is captured as a **deferred future authz/security
  milestone** (CONTEXT `<deferred>`), preserving the strongest prior-art lesson without scope creep.

### Research refinements folded into decisions (not corrections, sharpenings)
- Spec organization: prior-art favors **per-persona spec files** (file-level parallelism, blast-radius)
  over one mega-spec with describe-blocks → CONTEXT D-09 (default per-persona, planner may consolidate).
- Ledger: flows as a **weakest-link `min()` rollup** of constituent pages + flow-only criteria;
  forward-biased not forward-locked, demotion first-class → CONTEXT D-08.
- a11y: `toBeFocused()` auto-retry; assert focus-return + containment invariant; focus-visible only
  after Tab; reduced-motion at **context level** asserting the collapsed *effect*; theme via
  **attribute + localStorage** (never computed color), covering nav + reload + system-flip + no-flash
  via initial-state assertion + static head-script-not-async check → CONTEXT D-10.
- Seed: seed **terminal states directly**, relative timestamps, idempotent, env-guarded → CONTEXT D-05.
- Continuity: URL-encoded scope restored **as one coherent set**; persistent scope/impersonation
  banner; breadcrumb back-to-filtered-list → CONTEXT D-12.
- Microcopy: assert ratified brand strings; severity-honest color; status-not-blame; name both
  parties; empty≠broken; uniform-at-auth-boundary; glossary deferred to 191 → CONTEXT D-13.

## Todos Cross-Referenced (4 matched)
- **Folded:** `2026-06-17-phase-189-review-deferred.md` (WR-01..04 — ConfirmDialog focus/keyboard
  hardening + branding error mapping) → CONTEXT D-14, coherent with FLOW-02/FLOW-01.
- **Reviewed, not folded:** `2026-06-17-page04-branding-explicit-scoring.md` (pinned `resolves_phase:
  191`); `2026-06-14-phase-186-review-deferred.md` (test-extractor refactor, focused pass).

## External Research
- WAI-ARIA APG Dialog (Modal) pattern — focus-in / contain / return-to-trigger
  (https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/).
- WCAG 2.4.7 focus-visible, 2.4.11 focus-not-obscured, 2.1.2 no-keyboard-trap, 2.3.3 animation /
  `prefers-reduced-motion` (https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html).
- `prefers-color-scheme` no-flash bootstrap + `color-scheme` meta (https://web.dev/articles/color-scheme).
- Playwright: file-level parallelism + per-role storageState + web-first assertions
  (https://playwright.dev/docs/best-practices, /docs/auth); `reducedMotion` context-level
  (playwright#31328); `emulateMedia({colorScheme})` (https://playwright.dev/docs/emulation).
- Idempotent Ecto seeds (https://bitcrowd.dev/idempotent-seeds-in-elixir/); Supabase/Stripe
  deterministic seeding + test clocks (https://supabase.com/docs/guides/local-development/seeding-your-database,
  https://docs.stripe.com/sandboxes).
- Investigator/impersonation prior-art: Okta/Auth0 read-only vs help-desk tiers
  (https://help.okta.com/en-us/content/topics/security/administrators-admin-comparison.htm,
  https://auth0.com/docs/get-started/manage-dashboard-access/feature-access-by-role); RFC 8693 `act`
  claim; OWASP impersonation risk (CD-SEC-02); GitHub Enterprise impersonation transparency.
- Ledger/scorecard prior-art: EightShapes design-system measurement, Chromatic baseline acceptance,
  SonarSource clean-as-you-code, Goodhart's-law / SRE error-budget framing.
- Continuity UX: NN/g breadcrumbs / spatial memory / recognition-over-recall; Baymard applied-filters
  & persisted queries.
