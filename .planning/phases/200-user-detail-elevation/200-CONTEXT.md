# Phase 200: User Detail Elevation - Context

**Gathered:** 2026-06-25 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Award-grade (Tier-1 → Tier-2) elevation of the generated admin **User Detail** page
(`lib/sigra/admin/live/user_show_live.ex`): a calm, scannable, JTBD-first composition that makes
primary identity, one priority alert, key actions, and bounded drill-downs immediately legible
across the full viewport/theme/state matrix.

In scope (DETAIL-01..04):
- Recompose the identity header from stacked pills + 4-fact `<dl>` + alert into one calm identity bar.
- Restructure the 9-panel stack JTBD-first with progressive disclosure and link-outs for unbounded
  sub-lists, **preserving the host-injected extra-section seam**.
- Make the session revoke / revoke-all destructive flow clearly separated and APG-confirmed.
- Prove the page award-grade across 320–1440px / light·dark·system / empty·loading·error·
  permission-denied·long-content / keyboard / reduced-motion, and ratchet the `user-show-live`
  ledger cell to Tier 2 with proxy evidence.

Out of scope (later phases): Users Index (201), Audit surfaces (202), consistency propagation to
Overviews/Branding/gallery (203), terminal ratification / allowlist reset / adversarial review (204).
This phase does **not** re-grade any cell other than `user-show-live` (and the new sessions surface
it spawns, see D-04).
</domain>

<decisions>
## Implementation Decisions

### Identity Header (DETAIL-01)
- **D-01:** Recompose the stacked header (3 `sg-status-pill`s + 4-fact `<dl class="sg-summary-facts">`
  + `<.notice>` alert at `user_show_live.ex:102-139`) into a **single calm identity bar**: primary
  identity (name/email/id) + **the existing single-priority `summary_alert/1`** (`:475-513`, already
  prioritizes locked > unconfirmed > no-MFA) + a compact key-metrics strip. **Reuse existing `sg-*`
  primitives** (`sg-page-header`, `sg-summary-facts`, `sg-status-pill`) and existing presentation
  helpers (`status_pills/1`, `mfa_value/1`, `last_activity/1`, `passkey_count/1`) — do not introduce
  a new function component unless a new identity-bar pattern is genuinely reused elsewhere.
- **D-02:** If any **new `sg-*` CSS class** is introduced, it MUST be written byte-identically into
  all three copies (see D-12) **and** the `mg-9` gallery board + `admin-design.spec.ts:304` structural
  assertion (currently expects exactly one `.sg-summary-facts`) must be updated in the same change.

### JTBD Regrouping & Link-Outs (DETAIL-02)
- **D-03:** Restructure the current sections (identity header · Sessions · Security+Identities
  `sg-detail-grid` · Organizations · Recent-audit · Danger Zone · host extra-sections · confirm overlay)
  into a deliberate **JTBD-first composition** with grouped sections and **native `<details>`/`hidden`
  progressive disclosure** (consistent with existing `field_help`/`summary_chip` `hidden` patterns) —
  **no JS-driven disclosure**.
- **D-04 (RATIFIED — generated-host contract change):** **Sessions becomes a true link-out**, not an
  inline stack. Build a new **lib-owned `Sigra.Admin.Live.UserSessionsLive`** + route
  (`/admin/users/:id/sessions`). User Detail shows a **bounded session preview/count** that links out
  to the new page. Implications that MUST be handled together:
  - The new route lands in the **installer router template** (`priv/templates/sigra.install/.../router.*`)
    **and** the example router **and** the install golden fixtures **in lockstep** — this is a
    generated-host router/LiveView contract addition (the reason this was escalated and explicitly
    chosen by the user).
  - The **per-session revoke + revoke-all destructive flow moves to the new sessions page** (reusing
    the existing `ConfirmDialog` APG hook, D-05). Default: User Detail no longer hosts the session
    confirm overlay; all session-revoke controls live on `UserSessionsLive`. (Fine-grained split —
    e.g. whether Detail keeps a single "manage sessions" CTA vs an inline revoke-all — is Claude's
    discretion within this boundary.)
  - The new surface gets its **own quality-ledger cell + Playwright checkpoint slug** (e.g.
    `user-sessions`); it should be authored award-grade from the start. Whether it is ratcheted to
    Tier 2 in this phase or left Tier 1 is a planning call, but it must not regress and must carry the
    same `sg-*`/theme/APG/contract guarantees.
- **D-05:** **Recent-audit** keeps its existing link-out via `full_audit_path/3` → `/admin/users/:id/audit`
  (existing route, `router.ex:285,318`) — preserve and elevate it. **Organizations** becomes a
  **bounded preview** + the existing per-org `pivot_path/4` link rather than an unbounded inline stack.

### APG Destructive-Confirm Dialog (DETAIL-03)
- **D-06:** **Reuse the existing APG dialog — do not build a new one.** The generic `ConfirmDialog`
  `phx-hook` (`admin_hooks.js:376-480`) already implements focus-trap, initial-focus-on-cancel, Escape,
  click-outside scrim, scroll-lock, and focus-restore; `admin-modal-interaction.spec.ts` already proves
  all 7 APG gates + axe-while-open. The revoke/revoke-all flows already route through
  `#user-session-confirm-overlay` (`user_show_live.ex:315-333`). The dialog markup moves with the
  session controls to `UserSessionsLive` (D-04); keep the overlay **un-nested and not scrim-hidden**,
  and **do not rename** the hook selectors (`.sg-confirm-dialog`, `[data-sg-confirm-cancel]`,
  `#user-session-confirm-title`) or the spec silently fails. **No `admin_hooks.js` change expected.**

### Host-Seam Preservation (DETAIL-02)
- **D-07:** **Preserve the `extra_detail_sections/1` host seam exactly.** Keep intact: (1) the
  `@callback extra_detail_sections/1` contract on `Sigra.Admin.Users.Hooks` (`hooks.ex:24`,
  defaulted `[]` in `default_hooks.ex:24`), (2) the `detail.extra_detail_sections` data path
  (`detail.ex:35`), (3) the dual atom/string `:title`/`:body` key reads, rendered as distinct
  host-visible `sg-card` sections (`user_show_live.ex:310-313`) placed **after** lib-owned sections.
  The example's no-op (`[]`) will NOT catch a regression — treat this as a semver/generated-host
  contract surface.
- **D-08:** **Update the design contract.** `guides/reference/admin-design-contract.md` Detail
  Archetype composition block (`:251-279`) must document the new composition and explicitly note the
  preserved extra-section seam (success-criterion-2 requires "design contract updated").

### Tier-2 Ratchet & Recapture Blast Radius (DETAIL-04)
- **D-09:** Ratchet the `user-show-live` ledger cell (`admin-quality-ledger.md:88`) Tier 1 → bare `2`
  (no decorators — the monotonic guard's positional `awk -F'|'` parse depends on column-4 being a single
  `[012]` integer) and expand its Evidence column to cite each applicable Tier-2 proxy from the
  Add-on block (`admin-fractal-scorecard.md:123-167`): overlay-open axe-clean + focus-trap/restore APG
  (green via `admin-modal-interaction.spec.ts`), glossary-clean (`glossary_test.exs:25` already scopes
  `user_show_live`), desktop↔mobile content-equivalence (MG-5/6, `admin-design.spec.ts:325`), plus the
  documented-as-manual proxies (no `transition: all`, density/`sg-stack--N` rhythm, target-size ≥24px).
- **D-10:** **Recapture only the affected slugs through the recapture gate** (`snapshot-recapture-gate.sh`),
  not the canary guard. Visual blast radius: the `user-detail` checkpoint slug
  (`admin-checkpoints.spec.ts:218-231`), the **new sessions-page checkpoint slug** (D-04), and the
  `mg-9`/`mg-10`/`mg-11` design-gallery boards if their markup changes (`design_gallery_live.ex:924-1094`
  + `admin-design.spec.ts:304-306`). The `impersonation-banner` checkpoint canary and `board-notice`
  design canary MUST stay byte-stable. Use the correct per-lane canary/allowlist; leave allowlists
  empty at end-of-phase (Phase 204 owns terminal reset, but 200 stays green on its own).

### CSS / Template Lockstep
- **D-11:** `user_show_live.ex` (and the new `UserSessionsLive`) are **lib-owned** — but any new/changed
  `sg-*` CSS must be written **byte-identically** into all three currently-identical copies:
  `priv/templates/sigra.install/admin/sigra_admin.css`,
  `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — or the install golden-diff
  test fails and generated hosts get an unstyled page (the 184→185 regression class).
- **D-12:** The **new admin route (D-04)** must likewise be propagated to the installer router template
  + example router + golden install fixtures together; a route added only to the example will pass the
  example's own Playwright run but fail generated-host acceptance smoke / golden-diff.

### Claude's Discretion
- Exact JTBD grouping order and which sections collapse behind `<details>` vs stay open by default.
- Whether User Detail keeps a lightweight "revoke all sessions" affordance or defers all session
  management entirely to `UserSessionsLive` (default: defer entirely for a calm detail page).
- Whether `UserSessionsLive` is ratcheted to Tier 2 this phase or authored Tier-1-clean and ratcheted
  later (must not regress either way).
- Exact bounded-preview row caps for Sessions preview / Organizations preview.
- Precise identity-bar metric selection and microcopy (must stay glossary-clean).
- New checkpoint/board slug names for the sessions surface.

### Folded Todos
- None folded. Matched todos (CI parallelization, PAGE-04 branding scoring, Phase-199 INFO hardening,
  token-reference guard, installer/DX/Oban items) are all out-of-scope for this UI elevation — see Deferred.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `lib/sigra/admin/live/user_show_live.ex` — page under restructuring; identity header (`:102-139`),
  Sessions table + revoke triggers (`:141-194`), Security/Identities `sg-detail-grid` (`:196-226`),
  Organizations (`:228-253`), Recent-audit link-out (`:255-273`), Danger Zone (`:275-308`),
  extra-section seam (`:310-313`), confirm overlay (`:315-333`), helpers (`:420-530`).
- `lib/sigra/admin/users/detail.ex` — data loader; `extra_detail_sections` path (`:35`), audit preview
  shape (`:12,:61-102`), session/org/security data.
- `lib/sigra/admin/users/hooks.ex` + `lib/sigra/admin/users/default_hooks.ex` — the host-seam
  `@callback extra_detail_sections/1` contract that MUST be preserved (D-07).
- `test/example/lib/example_web/router.ex` (`:284-318`) — existing link-out routes (`/admin/users/:id/audit`,
  org pivot); confirms NO admin per-user sessions route exists yet (D-04 adds one).
- `priv/templates/sigra.install/` — installer templates; the new sessions route + any CSS must land here
  in lockstep with example + golden fixtures (D-11, D-12).
- `test/example/assets/js/admin_hooks.js` (`:376-480`) — generic `ConfirmDialog` APG hook (reuse, no edit).
- `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts` — 7 APG gates + axe-while-open;
  selectors that must not be renamed.
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (`:218-231`, canary `:268`) — `user-detail`
  checkpoint slug + `impersonation-banner` canary; new sessions slug added here.
- `test/example/priv/playwright/tests/admin-design.spec.ts` (`:304-306`, `:325`) — `mg-9/10/11` structural
  assertions + the content-equivalence proxy test.
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` (`:924-1094`) — gallery boards `mg-9/10/11`.
- `guides/reference/admin-design-contract.md` (`:251-289`) — Detail Archetype block to update (D-08).
- `guides/reference/admin-ui-principles.md` — binding IA/motion rules (progressive reveal `:23`,
  same-job-same-component `:29`, no `transition: all` `:47`).
- `guides/reference/admin-fractal-scorecard.md` (`:123-167`) — Tier-2 proxy definitions.
- `guides/reference/admin-quality-ledger.md` (`:33-54`, cell `:88`) — Tier-2 assertion convention +
  the `user-show-live` cell to ratchet (D-09).
- `scripts/ci/snapshot-recapture-gate.sh` + `scripts/ci/snapshot-canary-guard.sh` — recapture routing (D-10).
- `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`,
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — the three byte-identical CSS
  copies that must move in lockstep (D-11).
- `test/sigra/admin/glossary_test.exs` (`:25`) — glossary-clean proxy already scoped to `user_show_live`.
- `.planning/phases/199-foundation-tier-2-scorecard-stress-fixtures/199-CONTEXT.md` — Tier-2 instrument +
  stress-fixture decisions this phase consumes (≥25-event `admin` persona, list-scale users).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `summary_alert/1` (`user_show_live.ex:475-513`) is **already single-priority** — it directly satisfies
  the "one priority alert" requirement; no new prioritization logic needed.
- The generic `ConfirmDialog` hook (`admin_hooks.js:376-480`) is explicitly built to work across surfaces
  ("Works generically for both user_show_live and branding_live") — reuse it for session revoke on the
  new sessions page.
- Existing presentation helpers (`status_pills/1`, `mfa_value/1`, `last_activity/1`, `passkey_count/1`,
  `full_audit_path/3`, `pivot_path/4`) carry the data the new identity bar + link-outs need.
- `sg-page-header`, `sg-summary-facts`, `sg-status-pill`, `sg-detail-grid`, `sg-card`, `sg-stack--N`
  primitives already exist in the design system and contract.

### Established Patterns
- Quality-ledger column-4 = single `[012]` integer (no decorators) — the monotonic guard's positional
  `awk -F'|'` parse depends on it; flipping to `2` is "free" numerically but must stay un-decorated.
- Snapshot lanes use a canary slug (`impersonation-banner` checkpoints / `board-notice` design) + per-slug
  allowlist; recapture goes through `snapshot-recapture-gate.sh`, canary stays byte-stable.
- Admin CSS ships from installer template → generated host as `sigra_admin.css`; the three copies are
  byte-parity-gated (golden-diff). Known drift hazard: the template copy lags the example unless
  hand-propagated.
- Host seams are read-only, data-oriented callbacks (`extra_detail_sections/1`); generated hosts depend
  on their exact shape — the example's no-op default won't catch a break.

### Integration Points
- New `UserSessionsLive` route connects: installer router template ↔ example router ↔ golden fixtures ↔
  a new checkpoint slug ↔ (optionally) a new ledger cell.
- Identity-bar / grid / confirm markup connects to `mg-9/10/11` gallery boards + their `admin-design.spec.ts`
  structural assertions.
- Tier-2 evidence connects scorecard ↔ ledger ↔ monotonic guard ↔ `admin-modal-interaction.spec.ts` /
  `admin-checkpoints.spec.ts` / `admin-design.spec.ts` / `glossary_test.exs`.
</code_context>

<specifics>
## Specific Ideas

- "Calm bar, orient in under 2 seconds" is the north star for the identity header — primary identity +
  exactly one alert + a thin metrics strip; resist re-stacking facts.
- Sessions-as-its-own-page (D-04) is the *strongest* read of DETAIL-03's "clearly separated" — the
  destructive flow gets a dedicated surface rather than a panel buried in a 9-stack. The user explicitly
  accepted the generated-host router contract cost to get this separation.
- Progressive disclosure must be native (`<details>`/`hidden`) — no JS — to stay reduced-motion-safe and
  axe-clean.
</specifics>

<deferred>
## Deferred Ideas

- Users Index elevation — Phase 201.
- Audit surfaces elevation — Phase 202.
- Consistency propagation (Overviews, Branding workbench, `/admin/_design` gallery) — Phase 203.
- Terminal allowlist reset + adversarial milestone review + Tier-2 cell locking — Phase 204.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db` (CI speed) — out of scope; CI infra, not page UI.
- `2026-06-17-page04-branding-explicit-scoring` (score Branding customizer in L3 ledger) — belongs to
  Branding propagation (Phase 203), not User Detail.
- `2026-06-25-phase199-code-review-info-hardening` (fixture/self-test hardening) — Phase 199 follow-on,
  separate from this UI elevation.
- `2026-06-18-token-reference-completeness-ci-guard`, `2026-06-20-mix-sigra-migrate-schema-helper`,
  `2026-06-20-runtime-auth-prefix-override`, `2026-06-19-uat-demo-dx-polish-nits`,
  `2026-06-21-app-css-comment-corruption-cleanup`, `2026-06-24-oban-enqueue-unguarded...`,
  `2026-06-22-white-label-auth-email-theming` — low relevance (CI/installer/DX/CSS/Oban/email),
  out of phase scope.
</deferred>
</content>
</invoke>
