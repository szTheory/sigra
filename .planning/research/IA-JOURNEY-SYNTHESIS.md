# IA / Journey / Animation Research Synthesis — v1.34 ADMIN-UI-COHERENCE

> Produced during plan-mode research (2026-06-03), pre-milestone. Cited web research
> synthesized for the admin-UI coherence pass. Consumed by the roadmapper alongside the
> 4-dimension project research. Companion to the approved kickoff brief
> `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md`.

## 1. GOV.UK "needs-led" information architecture (the front-door model)

**Core principles** ([Government Design Principles](https://www.gov.uk/guidance/government-design-principles)):
- **Start with user needs** — design around the user's *job to be done*, not the internal data model. For an auth console the needs are verbs: "lock a compromised account," "see why a login failed," "revoke a session," "prove who did what."
- **Do less** · **Do the hard work to make it simple** · **Be consistent, not uniform** (the GOV.UK formulation of principle-of-least-surprise).

**Mechanism / why it works:** GOV.UK organizes around tasks, not org structure. The failure mode it cures is the "org-chart sitemap" — nav that mirrors the provider's structure (here: DB tables Users/Sessions/MFA/Passkeys/Identities) instead of how the user thinks (verbs/situations). When you land, the next action is obvious because the page is named after the goal.

**ADOPT:** verb-first landing (Sigra's `IndexLive` H1 "What do you need to do?" is already correct — keep/harden); needs-to-noun routing (task → filtered list deep-link, already done via `?locked=true`); one primary action per page; plain operator-language labels.
**AVOID:** org-chart/table-of-contents sidebar; feature-parity homepage (everything weighted equally); naming pages after internal concepts; designing for the maximal/power case first.

## 2. Admin/operator console IA & dashboard best practices

- **Landing dashboard vs jump-to-task:** a landing overview earns its place only if it accelerates the next action. Auth-ops is incident-driven → the overview should be a **triage + launcher**, not a BI dashboard.
- **Role-aware, not forked:** one data source, scope/role re-ranks emphasis (Sigra's `admin_scope` global vs org). Avoid separate dashboards per role (divergence + least-surprise violations).
- **Progressive disclosure** ([NN/g](https://www.nngroup.com/articles/progressive-disclosure/)): show the few most-important options first; never more than 2 disclosure levels; one obvious way to progress. Apply to user-detail (identity+status+primary actions first; sessions/MFA/passkeys/OAuth/audit disclosed below) and audit (common filters visible, advanced disclosed).
- **The master-detail spine** = the unifying pattern: **Overview (triage) → List (filtered noun) → Detail (entity + actions + sub-resources)**. Every domain object rides the same spine so nav is predictable. Make it *explicitly identical* across users/audit/orgs (same header anatomy, action placement, breadcrumb, empty/loading states).
- **Nav patterns:** persistent sidebar (primary), topbar (global context: brand, scope switcher, ⌘K), command palette (power accelerator). Sigra has all three. ⌘K is the single best lever to serve novice + intermediate + power users at once — ensure it surfaces *actions + entities*, not just routes.
- **Skill-level coverage:** novice → visible sidebar IA + verb landing + confirmation friction; intermediate → breadcrumbs + linkable filtered views; power → ⌘K + keyboard + bulk + no animation on repeated keyboard actions.
- **Scannable hierarchy:** color carries state, not decoration (Sigra's `sg-status-pill[data-tone]` is the right instinct); status as the most salient triage column; consistent primary-action placement.
- **AWS console = cautionary tale:** IA mirrors service org structure; every service invents its own nav/layout (no least-surprise); optimized for the maximal enterprise case. Lesson: do not let each domain (passkeys/OAuth/MFA) grow its own bespoke screen idiom — force them onto the shared spine.

## 3. Emil Kowalski animation principles ([Great Animations](https://emilkowal.ski/ui/great-animations), [7 Tips](https://emilkowal.ski/ui/7-practical-animation-tips))

- **Fast = responsive:** UI animation under ~300ms (often less).
- **Easing:** default `ease-out` for enters/exits; **never `ease-in` for enters**; built-in CSS curves too weak → custom cubic-bezier; spring only where physical; **flat ease-out (no spring) on destructive**.
- **Animate only `transform` + `opacity`** (GPU, 60fps); never layout props.
- **Origin-aware** popovers/menus (scale from trigger via `transform-origin`); don't animate from `scale(0)` — start ≥0.9; press feedback `scale(0.96–0.99)`; interruptibility; blur as a bridge; honor `prefers-reduced-motion`.
- **When NOT to animate:** frequent keyboard-initiated actions (done dozens of times daily) — animation makes them feel slow. For Sigra: ⌘K *result filtering*, list filtering, row selection, keyboard tab switching → near-instant.

**Grounding note:** Sigra's `sg-*` token layer (`test/example/priv/static/assets/css/app.css`) **already implements this system** — `--sg-ease-out: cubic-bezier(0.23,1,0.32,1)`, sub-300ms motion scale, scale-from-0.96 enters, flat easing reserved for destructive, transform/opacity only, `prefers-reduced-motion` block. **This milestone audits motion USAGE, it does not add primitives.** Per-moment guidance: filter apply → near-instant (no re-stagger); row reveal → subtle opacity+translateY ease-out ~140–180ms; toast → ease-out ~180–220ms + undo; ⌘K open → origin-aware scale-from-0.96, results filtering un-animated; destructive confirms → flat ease-out, gravity not delight.

## 4. Design-token "brand guide" — the usage-governance layer on top of tokens

Sigra has the *foundation* (scales). Mature systems add **usage governance**: documented "same job → same component" conventions, enforced.

- **Principle of Least Astonishment** operationalized: same job → same component, every time (a "lock account" action looks/behaves identically on the list, detail, and in ⌘K).
- **Document per component:** when to use / **when NOT to use** (most-skipped, most-important), do/don't pairs, anatomy + 6 states (default/hover/focus-keyboard/active/disabled/loading), content guidelines, token references, a11y.
- **Mapping a small inventory to a large surface** (the heart of this milestone):
  1. **Job → Component mapping table** — enumerate recurring jobs (display status, primary action, destructive action, filter, navigate-to-detail, show sub-resource list, empty state, confirm danger, surface posture signal) and assign exactly one canonical component each.
  2. **Page archetypes** — document Overview / List / Detail as *compositions* of those components, so a new surface is assembled, not designed fresh.
  3. **Governance loop** — stable core + regular path for new patterns.
- **AVOID:** documenting anatomy without usage; variant sprawl; raw values bypassing tokens; per-domain bespoke layouts; no "when not to use."

## Priority order for the milestone (highest leverage first)
1. IA spine + needs-led labels (verbs not nouns) — highest leverage, lowest risk.
2. **Job→Component mapping + 3 page archetypes** — the keystone convention artifact.
3. Master-detail consistency pass — every domain LiveView conforms to archetypes.
4. ⌘K as cross-skill accelerator (actions + entities).
5. Motion-USAGE audit (no new primitives) — no-animation on keyboard-frequent actions, correct semantic easing per moment, origin-aware popovers, flat destructive.
6. Destructive-action convention — one confirmation pattern, friction proportional to reversibility (undo-toast reversible / type-to-confirm irreversible), flat easing.

## Key sources
- GOV.UK Design Principles; GDS Design System intro (gds.blog.gov.uk, 2018)
- NN/g: Progressive Disclosure; Proximity of Consequential Options
- Mantlr Stripe/Linear/Vercel premium-UI analysis; dashboard pattern research
- AWS console UX critiques (HN 24264428; Medium post-mortem)
- Emil Kowalski: Great Animations; 7 Practical Animation Tips
- Shopify Polaris governance; design-system documentation best practices; POLA/POLS
- Smashing Magazine: managing dangerous actions in UIs (2024)
