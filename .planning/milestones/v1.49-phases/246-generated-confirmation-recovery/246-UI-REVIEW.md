# Phase 246 — UI Review

**Audited:** 2026-10-07  
**Baseline:** Abstract 6-pillar standards; generated-auth shell context from Phase 174 and `guides/recipes/auth-branding.md`. No Phase 246 UI-SPEC exists.  
**Screenshots:** Not captured. The only configured port that responded was `localhost:8080`, which served the Traefik dashboard; all three Playwright capture attempts failed because `npx` could not write to the user npm cache (`EPERM`). Audit is code-based.  
**Interaction captures:** off (the `workflow.ui_interaction_capture` setting is absent; default is off)

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Main confirmation copy is localized and specific; the resend control reads as a question rather than an action. |
| 2. Visuals | 2/4 | The main form has a clear focal point, but success/error feedback is a small, unfilled chip; rendered hierarchy could not be checked. |
| 3. Color | 3/4 | Theme and brand tokens are present; feedback uses semantic text colors without the available state backgrounds. |
| 4. Typography | 2/4 | The confirmation surface mixes more than four text sizes and three weights, with the result message at 0.8rem. |
| 5. Spacing | 2/4 | The CSS defines a spacing scale, while active form, status, and notice styles use several off-scale values. |
| 6. Experience Design | 3/4 | Link/code states and retry are covered; the code-page resend button has no pending/disabled state. |

**Overall: 15/24**

**Human review:** No manual UAT is required by the Phase 246 contract (D-09). A human visual sign-off is still advisable because the configured server was unrelated and no target screenshots were captured; the exact-source CI browser run proves the interaction path, not visual composition.

## Top 3 Priority Fixes

1. **Make confirmation outcomes read as prominent notices** — users can miss a successful or failed submission when the message is a small inline chip — use the existing success/danger soft backgrounds and a full-width padded treatment while retaining `role="status"` and `role="alert"`.
2. **Clarify and disable resend while it is running** — the question-style label does not say what will happen and repeat clicks can issue duplicate resend events — use a localized “Send a new confirmation code” action and `phx-disable-with` text such as “Sending…”.
3. **Use the auth spacing and type scales on this form** — off-scale paddings and a tiny status size weaken consistency and feedback hierarchy — map input/status spacing and message typography to the existing tokens, then review light and dark generated-host captures.

## Detailed Findings

### Pillar 1: Copywriting (3/4)

- **WARNING — Resend action is ambiguous.** The signed-in code page exposes a button labeled “Didn't receive a code?” (`confirmation_live.ex:83-86`). It identifies a problem, but not the action that follows. Use a localized imperative label such as “Send a new confirmation code,” with the question as helper copy if useful.
- **WARNING — Optional footer labels are English literals.** “Support,” “Privacy,” and “Terms” bypass gettext in the shared shell (`sigra_auth_components.ex:61-67`). When a host configures those links for another locale, their labels stay English. Route them through the `sigra` gettext domain.
- Confirmation, sign-in guidance, success, invalid-code, and rate-limit messages use `dgettext("sigra", ...)` (`confirmation_live.ex:25-28, 103-114, 149-167, 205-242`). The form uses “Confirm email,” a concrete task label, and has no generic “Submit” or “OK” copy.

### Pillar 2: Visuals (2/4)

- **WARNING — Result feedback lacks visual weight.** The shared shell inserts success/error copy before the form, but `.sigra-auth-status` is `width: fit-content`, `min-height: 1.75rem`, and `font-size: 0.8rem`; its state modifiers change text color only (`sigra_auth_components.ex:52-57`, `sigra_auth.css:278-288, 360-362`). This is a low-profile badge for the most important post-submit outcome. Use the existing notice treatment with roomier padding and a full-width layout while preserving the live-region semantics.
- The form is a centered, single-column flow inside a branded panel, and its primary action is full width (`confirmation_live.ex:20-35, 60-80`; `sigra_auth.css:139-151, 170-173, 384`). That gives the first screen a clear task focus. The target host was not captured at any viewport, so alignment, wrapping, and actual visual balance remain unverified.

### Pillar 3: Color (3/4)

- **WARNING — Success/error treatment has no state surface.** The shell's state classes only switch the text color (`sigra_auth.css:360-362`). The stylesheet already defines success/danger background and border treatments under `.sigra-auth-notice--success` and `.sigra-auth-notice--danger` (`sigra_auth.css:252-275`), but this feedback does not use them. Apply those existing semantic tokens to make outcomes easier to scan; keep message wording so meaning is not conveyed by color alone.
- The auth shell uses CSS variables for accent, background, surface, text, and muted colors and has explicit light, dark, and system branches (`sigra_auth.css:4-27, 61-108`). Accent usage stays tied to controls, links, and the brand mark. Since the target page could not be rendered, the actual 60/30/10 visual balance and contrast after host branding are unverified.

### Pillar 4: Typography (2/4)

- **WARNING — The confirmation surface has a broad type scale for a single-form screen.** Relevant styles include the 0.8rem status, 0.95rem brand/action text, 1.05rem code entry, inherited body copy, and a 1.55–2rem heading (`sigra_auth.css:287, 338, 482-483, 542, 863-864`). Label, status, and action weights use 650, 700, and 750 (`sigra_auth.css:243, 288, 715, 864`). The hierarchy is understandable, but this exceeds the abstract compact-scale target of four sizes and two weights; consolidate around fewer roles, and raise outcome text from 0.8rem.

### Pillar 5: Spacing (2/4)

- **WARNING — Active form spacing does not consistently use the declared scale.** The stylesheet defines `--sigra-auth-space-1` through `--sigra-auth-space-6` (`sigra_auth.css:23-27`), but the confirmation surface also uses `0.65rem` status padding, `0.7rem 0.85rem` input padding, `0.9rem 1rem` notice padding, and custom `clamp()` panel padding (`sigra_auth.css:121, 143-144, 255, 285, 730`). Map the form controls and feedback to the existing scale; retain responsive outer padding where it serves the viewport.

### Pillar 6: Experience Design (3/4)

- **WARNING — Code-page resend has no in-flight state.** Link/code submission buttons and the expired-link resend button provide `phx-disable-with` text (`confirmation_live.ex:32-34, 78-80, 125-127`), but the normal code-page resend button has no such state (`confirmation_live.ex:83-86`). Add a sending label/disabled state so repeated clicks do not dispatch duplicate requests and the user can see progress.
- The component handles the token-confirm, confirmed, code-entry, already-confirmed, sign-in-required, expired, invalid-code, and rate-limited states, while retaining the entered code for retry (`confirmation_live.ex:22-128, 149-253`). Success and errors render through status/alert live regions (`sigra_auth_components.ex:52-57`).
- Automated verification is strong for the targeted flow. Exact-source GitHub CI [run 37676348766](https://github.com/szTheory/sigra/actions/runs/37676348766) passed for `90ec16f72a71d33224c0816ad77762e2e7262c76`; its required jobs, all five example Playwright shards, and admin-eval succeeded. The generated-host Chromium scenario passed one real spaced-code paste, invalid feedback, retry, and success path (`generated-confirmation.spec.ts:65-107`). The CI record notes one retry after an existing admin LiveView readiness timeout; the final browser job passed. This is interaction evidence, not a screenshot of the confirmation UI.
- **Human UAT is not needed** under D-09; automated acceptance is the phase contract. Visual composition remains a separate review limitation because no target screenshot was available.

## Files Audited

- `priv/templates/sigra.install/core/confirmation_live.ex`
- `priv/templates/sigra.install/core/sigra_auth_components.ex`
- `priv/templates/sigra.install/core/sigra_auth.css`
- `test/example/priv/playwright/tests/generated-confirmation.spec.ts`
- `test/sigra/install/auth_ui_contract_test.exs`
- `.planning/phases/246-generated-confirmation-recovery/246-01-PLAN.md`, `246-02-PLAN.md`, `246-03-PLAN.md`
- `.planning/phases/246-generated-confirmation-recovery/246-01-SUMMARY.md`, `246-02-SUMMARY.md`, `246-03-SUMMARY.md`, `246-CONTEXT.md`, `246-CI-EVIDENCE.json`
- `.planning/milestones/v1.37-phases/174-generated-auth-shell-light-dark-system-css/174-SUMMARY.md`
- `guides/recipes/auth-branding.md`
- `AGENTS.md`, `test/example/AGENTS.md`

## Recommendation Count

- Priority fixes: 3
- Minor recommendations: 2 (localize optional footer labels; inspect branded light/dark generated-host rendering when a target host is available)
