# Phase 156: Adopt Shared Components on Baselined Screens - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-04
**Phase:** 156-adopt-shared-components-on-baselined-screens
**Mode:** assumptions (+ deep ecosystem/repo research on the one escalated fork)
**Areas analyzed:** Migration set & 5-vs-6 split; baseline re-record strategy; per-screen
seam reconciliation; parity lane & banner dual-maintenance; notice-tone drift guard; COHR-04
scope ribbon (escalated, researched).

## Assumptions Presented

### Migration set (COHR-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Baselined screens = UsersIndexLive (×2 slugs), UserShowLive, AuditIndexLive, admin_shell banner — NOT the Overviews/per-user-audit | Confident (verified) | `router.ex:256-293`; `admin-checkpoints.spec.ts` slug routes |
| Remove duplicate `defp metric_link`/`task_card` from both Overviews in 156 (pixel-neutral import swap); defer their visual redesign to 157 | Likely → locked | `index_live.ex:118` / `organization_live.ex:169` byte-identical dupes; COHR-01 wording "no dupes remain"; ROADMAP 157 boundary |

### Re-record strategy (SC-7)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Only `user-detail` carries an intended delta from COHR-02 (header archetype); all else byte-green | Confident | `user_show_live.ex:97` lone `sg-card` header; notice byte-clone `app.css:945-967`/`971-993`; 155 goldens |
| No blanket re-record; re-record only after HTML-report review | Confident | 155-D-13 anti-snapshot-footgun rule |

### Parity lane & banner
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `admin-generated` lane auto-tracks (example routes to lib modules; no host LiveView copies) | Confident | `router.ex` binds `Sigra.Admin.Live.*`; no `ExampleWeb.Admin.*` LiveViews exist |
| Impersonation banner is dual-maintained (template + example copy) | Confident | `priv/templates/.../admin_shell.ex` + `test/example/.../admin_shell.ex` |

### Notice-tone drift guard (folded todo)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resolve via shared-selector merge now (no new class; dedupe not delete) | Likely → locked | todo `2026-06-03-sg-notice-tone-rule-duplication.md`; `app.css` tone blocks; sg-list-row keeps non-alert uses |

### COHR-04 scope ribbon (escalated — Unclear)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Whether list screens need a discrete ribbon (visual delta + re-records) or header prose suffices | Unclear → escalated → researched & decided | `users_index_live.ex:75` / `audit_index_live.ex:53` scope in `sg-page-copy`; leaf screens use discrete span |

## Corrections Made

The user delegated the one escalated fork (COHR-04) back with an explicit instruction to
**research deeply and decide** — not to choose from a menu. Two parallel research agents were
spawned (ecosystem prior-art via web; repo design-contract/brand/prompts/vision).

### COHR-04 — Decision: discrete `<.scope_ribbon>` everywhere, in its quiet form
- **What was decided:** Render the shared `<.scope_ribbon>` (quiet `sg-muted sg-text-sm`
  span, no new CSS) on every list AND leaf screen; on list screens add it as a discrete
  header-region element and drop scope from the `sg-page-copy` subtitle. Accept deliberate
  re-records on the 3 list/explorer baselined slugs.
- **Why (both lenses converged):**
  - *Ecosystem:* Stripe (account scope = quiet header element; colored banner reserved for
    test-mode), AWS (account-color tint on existing nav for prod-vs-dev), Supabase/Linear/
    GitHub (scope in persistent header/breadcrumb root), LiveDashboard/Oban Web (selector-as-
    display). Dominant convention = quiet persistent scope element; loud treatment reserved
    for risky states. NN/g banner-blindness only bites a loud always-on stripe — Sigra's
    ribbon is the quiet form, so it doesn't apply. The agent's own conclusion: COHR-04 is
    satisfied by promoting the existing muted pill to a shared component rendered everywhere,
    NOT a new full-width banner.
  - *Repo:* COHR-04 names the `<.scope_ribbon>` *component* "on every list and leaf screen"
    (REQUIREMENTS L30 / ROADMAP L96); design-contract List archetype reserves a discrete
    ribbon slot (L184) and declares it "present on every list and leaf screen" (L99); the
    milestone's governing law is "same job → same component" (contract L3 / PROJECT L37) —
    list-prose vs leaf-span is exactly the divergence to eliminate; SC-7 blesses deliberate
    visual deltas + re-records. Reuses mature `sg-muted` token → honors the no-new-CSS lock.
- **Deferred enhancement (captured, not decided away):** a louder color/role-coded treatment
  for the Global super-admin scope (the genuinely risky state) — strongest ecosystem idea,
  but needs token-layer work locked out of this milestone; impersonation already has a banner.

## External Research

- **Scope-indicator prior art:** Stripe test/live mode split (https://www.temperstack.com/learn/stripe/switch-test-live-mode/);
  AWS account color (https://aws.amazon.com/blogs/aws/customize-your-aws-management-console-experience-with-visual-settings-including-account-color-region-and-service-visibility/);
  Supabase top-bar scope; Linear workspace switcher; GitHub org-context-in-breadcrumb (and its
  documented failure mode, desktop#17252); M365 multi-tenant banner; Avo/ActiveAdmin (host-
  owned scope); env-color-bar convention; NN/g banner blindness
  (https://www.nngroup.com/articles/banner-blindness-old-and-new-findings/); W3C breadcrumb APG;
  MDN status role. **Net:** scope = quiet persistent header element; loud/color = risk states only.
- **Repo grounding:** design-contract scope_ribbon L95-103 + List/Detail archetypes L169-242;
  `components.ex` scope_ribbon reuses `sg-muted sg-text-sm`; PROJECT.md milestone law + no-token-
  layer lock; prompts/ subdir had no bearing on scope indicators.
