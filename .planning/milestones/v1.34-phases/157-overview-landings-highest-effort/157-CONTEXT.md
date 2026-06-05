# Phase 157: Overview Landings (Highest Effort) - Context

**Gathered:** 2026-06-04 (assumptions mode + deep codebase analysis)
**Status:** Ready for planning

<domain>
## Phase Boundary

Redesign the two admin Overview screens — `lib/sigra/admin/live/index_live.ex` (Global
Overview) and `lib/sigra/admin/live/organization_live.ex` (Org Overview) — into deliberate
**needs-led front doors** and give them their **first committed Playwright baselines**
(`global-overview` + `org-overview` slugs ×3 projects).

This is a **visual redesign** phase (unlike Phase 156, which was behavior-preserving). These
two screens are NOT yet baselined — Phases 155/156 only import-swapped their duplicate
`defp metric_link`/`task_card` into the shared `Sigra.Admin.Components` module
(pixel-neutral). So there is nothing to "re-record": this phase CREATES the two new
checkpoint slugs.

**In scope:**
1. LAND-01 — promote the needs-review alarm above the task grid as the most prominent element.
2. LAND-02 — lead with verb-first `task_card`s; demote the `stat_link` posture strip; demote
   the capability matrix to lowest priority.
3. LAND-03 — both Overviews share one identical front-door archetype.
4. LAND-04 — render a `<.skeleton>` loading state for the overview data instead of an empty
   flash / layout jump.
5. New Playwright checkpoints `global-overview` + `org-overview` (axe-green ×3 projects);
   `admin-generated` parity lane stays green.
6. Fold the `2026-06-04-org-notice-nested-p.md` todo (nested-`<p>` axe risk in the Org notice).

**Hard constraints (locked, carried from STATE.md + 154/155/156):** No new Hex deps, no
Tailwind, no Alpine, **no `assign_async/3`**. **No new CSS classes invented**, no new
tokens/motion primitives — all styles stay inside `@layer sg-components` (the `sg-*` layer is
mature; this milestone audits *usage*). axe WCAG A/AA green across chromium + mobile + dark.
`admin-generated` installer-parity lane stays green. `page_back` stays leaf-only (contract
forbids it on Overview). The redesign composes the existing 10 shared components — it does NOT
invent new ones.
</domain>

<decisions>
## Implementation Decisions

### LAND-04 — async/skeleton mechanism (the central decision)
- **D-01 [Likely → locked]:** Satisfy LAND-04 with a **`connected?(socket)`-gated deferred
  load**, NOT `assign_async/3` (banned) and NOT `Task`/`send(self)` + `handle_info`. On the
  disconnected/first-HTTP mount, assign `loading: true` with no query data and render
  `<.skeleton>` shapes for the data regions (posture strip; Org roster + pending invitations).
  On the connected mount, run the real queries inline (`Query.summary_counts/2`; Org also
  `Detail.member_roster/2` + `Detail.pending_invitations/2`) and assign data with
  `loading: false`. Exactly two render states (skeleton → data), no extra render frame.
  - **Why:** The queries are genuine multi-round-trip DB aggregates
    (`lib/sigra/admin/users/query.ex:159-167` issues 6+ `repo.aggregate`;
    `lib/sigra/admin/organizations/detail.ex:59-99` adds two joined `repo.all`), so a skeleton
    is defensible, not gratuitous. The `connected?`-gate idiom is already in-repo
    (`test/example/lib/example_web/live/confirmation_live.ex:103`). Running the query inline on
    the connected mount keeps `mount/3` the single load site. The design contract anticipates
    this exact phase concern (`guides/reference/admin-design-contract.md:125`: "Consider
    `aria-busy=\"true\"` on the containing section during load (Phase 157 concern)").
  - **Hard-fail boundary:** Keeping the synchronous load and only flashing skeleton in a
    first-paint window violates the contract's "Do NOT use skeleton for content available
    synchronously" rule and makes LAND-04 a reviewable no-op (the skeleton would never show).
- **D-02 [Likely → locked]:** Add `aria-busy="true"` to the skeleton's containing `<section>`
  while `loading`. Gate the LAND-01 alarm's live-region role (opt-in via `:rest` per 155-D-08)
  on this deferred arrival — the alarm count is now genuinely post-load-dynamic, so a
  `role="status"` opt-in is valid here, but do NOT add an always-on live-region role to
  load-present markup (inert per WAI-ARIA APG; risks duplicate announcements on re-render —
  the exact failure `notice/1`'s doc warns against).

### LAND-01 — loud alarm, composed from existing classes only
- **D-03 [Likely → locked]:** Build the "loud" alarm by composing the existing `<.notice>`
  component — **no new CSS class**. Promote it to the FIRST child inside `sg-stack sg-stack--6`,
  ABOVE the `task_card` grid. `tone={:risk}` + count headline + deep-link
  (`<a href="/admin/users?locked=true">`; Org: `users_path(@admin_scope) <> "?locked=true"`)
  when `needs_review > 0`; `tone={:ok}` "All clear" when `0`. Prominence comes from **position
  (top of stack) + the existing `sg-notice[data-tone="risk"]` treatment** (inset risk bar +
  risk-soft fill, `app.css:960-967,972-978`), not from new styling. Delete the old
  `sg-status-pill`-in-`sg-posture-strip` alarm block (`index_live.ex:60-65`,
  `organization_live.ex:86-94`); the deep-link targets already exist in both files.
  - **Hard-fail boundary:** If a reviewer judges a repositioned `sg-notice` as "not loud
    enough" and demands a new emphatic class (e.g. `sg-alarm`), that collides with the
    no-new-CSS-class lock — **escalate to a milestone lock exception, do not invent the class.**

### LAND-02/03 — identical front-door archetype, demoted strips
- **D-04 [locked]:** Reorder BOTH Overviews to one identical front-door archetype:
  (1) `sg-page-header` → (2) **alarm `<.notice>`** → (3) **`task_card` grid (primary content)**
  → (4) demoted `stat_link` posture strip (`sg-posture-strip`, whose CSS intent is already
  "demoted metrics: secondary surface, sits below the jobs" — `app.css:1172`) → (5) capability
  matrix lowest priority (Global only). Global keeps 3 task cards, Org keeps 2 — **count
  differs, archetype identical** (LAND-03 explicitly allows differing task counts). The
  `sg-status-pill` inside each posture strip's `sg-posture-strip__risk` anchor is removed (the
  alarm absorbs that role); the strip keeps only the `stat_link` cluster.
- **D-05 [user decision — escalated & confirmed 2026-06-04]:** **Org keeps its live Members
  roster + Pending invitations as a clearly-demoted "scoped detail" tail section BELOW the
  shared front-door archetype.** LAND-03 archetype parity = identical *front-door rhythm*
  (header → alarm → task cards → posture strip), NOT forbidding scope-specific content. Org's
  extra real tenant data is preserved (pending invitations have no other home screen). This is
  the least-surprising, operator-respecting reading. The shared archetype portion (items 1-4
  of D-04) must be byte-coherent across both screens; Org's tail is the only structural
  divergence. Update the contract's Overview Archetype section with a one-line Org-variant note
  ("Org appends a demoted scoped-detail tail: members + pending invitations").

### Playwright checkpoints + folded nested-`<p>` todo
- **D-06 [Likely → locked]:** Add two NEW slugs `global-overview` + `org-overview` to the
  existing single authenticated journey in `admin-checkpoints.spec.ts`, each via the
  established `captureAndVerify(...)` + `assertCheckpointScreenshot(...)` two-call pattern
  (`:171-208`), producing 6 new committed PNGs (2 slugs × 3 projects). Because D-01 defers the
  load, the screenshot wait MUST go beyond `waitForLiveViewReady`'s `.phx-connected` check
  (`:40-44`) and **additionally wait for real loaded data to be visible (NOT the skeleton
  frame)** — e.g. assert a `stat_link` value is visible — or the baseline freezes a skeleton
  and every subsequent run diffs (perpetual flake). Confirm the `org-overview` route renders
  the redesigned `OrganizationLive`, not the "org landing stub" the spec comment references
  (`admin-checkpoints.spec.ts:202`).
- **D-07 [Confident]:** Fold the `2026-06-04-org-notice-nested-p.md` todo via its resolution
  #1 — keep all `<.notice>` slot content **inline** (single message / inline `<span>`s), never
  block `<p>`s. This is naturally resolved because the LAND-02 redesign removes the entire Org
  "Scoped attention" card whose `<.notice>` at `organization_live.ex:73-78` passed two block
  `<p>` children into `notice/1`'s own `<p class="sg-text-sm">` wrapper
  (`components.ex:303-304`), producing invalid `<p><p>…</p></p>`. The alarm's new top-of-page
  `<.notice>` carries single inline content, so the fix is structural, not a patch. Hard-fail
  boundary: any surviving `<.notice>` with block `<p>` children fails axe on the new
  `org-overview` checkpoint.

### Claude's Discretion
- Exact skeleton shapes/count per region (match the loaded content's footprint to avoid layout
  jump — that is the LAND-04 intent).
- Alarm headline microcopy and count phrasing (within tone + deep-link requirements).
- Exact placement/markup of Org's demoted scoped-detail tail (members + invitations) below the
  shared archetype, as long as it reads as clearly secondary to the front door.
- Per-screen commit ordering; whether the two redesigns land in one or two commits.
- Exact Playwright wait selector that proves "loaded, not skeleton."

### Folded Todos
- `.planning/todos/pending/2026-06-04-org-notice-nested-p.md` — **folded** into D-07 (the Org
  redesign rewrites the offending call site; axe-green is a phase requirement).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- **Redesign targets (lib-owned LiveViews):** `lib/sigra/admin/live/index_live.ex` (Global
  Overview — sync load in `mount/3` @12-21; render @25; alarm pill @60-65; stat_link strip
  @68-89; capability matrix @102-108) and `lib/sigra/admin/live/organization_live.ex` (Org
  Overview — sync load in `mount/3` @14-27; render @31; nested-`<p>` notice @73-78; alarm pill
  @86-94; stat_link strip @97-113; **Members roster @125-141 + Pending invitations @143-162 —
  KEEP as demoted tail per D-05**; `users_path`/`audit_path`/`needs_review` helpers @191-201).
- **Shared component module (compose these; do NOT invent):** `lib/sigra/admin/components.ex` —
  `skeleton/1` (`<div class="sg-skeleton">`), `notice/1` (@~297-305: wraps slot in
  `<p class="sg-text-sm">` — source of the nested-`<p>` trap; live-region role opt-in via
  `:rest` @274-276), `task_card/1`, `stat_link/1`.
- **Authoritative markup spec:** `guides/reference/admin-design-contract.md` — Overview
  Archetype (@135-167; needs a one-line Org-variant note per D-05); `skeleton` entry (@~117-129:
  "Do NOT use for content available synchronously"; `aria-busy` Phase-157 concern @125); `notice`
  entry (ARIA amended in 155-D-09); `task_card` (@~38-52); `page_back` leaf-only (@91).
- **Data sources (cost informs D-01 skeleton):** `lib/sigra/admin/users/query.ex:159-167`
  (`summary_counts/2`, 6+ `repo.aggregate`); `lib/sigra/admin/organizations/detail.ex:59-99`
  (`member_roster/2`, `pending_invitations/2`, joined `repo.all`).
- **`connected?`-gate precedent:** `test/example/lib/example_web/live/confirmation_live.ex:103`.
- **CSS (boundary — compose, do not add classes):** `test/example/priv/static/assets/css/app.css`
  — `.sg-skeleton` + shimmer (1421-1443), `prefers-reduced-motion` universal rule (1463-1473),
  `.sg-notice[data-tone]` (960-978), `.sg-posture-strip` ("demoted metrics… below the jobs"
  comment @1172), `.sg-status-pill`, `.sg-page-header`, `.sg-capability`, `@layer` order (line 15).
- **Playwright checkpoints (add 2 NEW slugs; do NOT re-record existing 5):**
  `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (journey + `captureAndVerify`/
  `assertCheckpointScreenshot` pattern @171-208; `waitForLiveViewReady`/`.phx-connected` @40-44;
  axe ×3 @112-145; "org landing stub" comment @202) + `...-snapshots/`.
- **Parity lane (auto-tracks; keep green):** `scripts/ci/admin-acceptance-smoke.sh` +
  `test/example/priv/playwright/tests/admin-generated.spec.ts` (route/markup probes; CSS-agnostic).
- **Prior phase contracts:** `.planning/phases/156-adopt-shared-components-on-baselined-screens/156-CONTEXT.md`
  (D-01 names these two screens as NOT baselined → 157), `155-.../155-CONTEXT.md` (D-08 notice
  ARIA opt-in), `154-.../154-CONTEXT.md` (design contract + sg-notice origin).
- **Planning sources:** `.planning/ROADMAP.md` (phase 157, LAND-01..04, SC 1-5),
  `.planning/REQUIREMENTS.md` (LAND-01..04 lines 20-23), `.planning/STATE.md` (locked
  constraints), `.planning/PROJECT.md` (milestone law "same job → same component"; no
  token-layer work), `.planning/METHODOLOGY.md` (decisive defaulting; escalation threshold).
- **Folded todo:** `.planning/todos/pending/2026-06-04-org-notice-nested-p.md` (nested-`<p>`,
  WR-01 from 156-REVIEW.md).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All 10 shared components already exist (`lib/sigra/admin/components.ex`) and are byte-faithful
  (155 `render_component` goldens). The redesign COMPOSES `skeleton`, `notice`, `task_card`,
  `stat_link` — no new components, no new CSS classes.
- The `connected?`-gate deferred-load idiom is already in the repo
  (`confirmation_live.ex:103`), so D-01 is an in-house pattern, not a novel import.
- Deep-link targets for the alarm (`/admin/users?locked=true`, org `users_path` + `?locked=true`)
  already exist in both Overview files.
- The `.sg-skeleton` shimmer is `prefers-reduced-motion`-safe via the universal rule
  (`app.css:1463-1473`) — no extra motion handling needed.

### Established Patterns
- The example host routes admin URLs straight to `Sigra.Admin.Live.*` — one edit changes both
  the keystone render AND the parity lane render (no host LiveView copies to dual-maintain).
  (The impersonation banner is the only dual-maintained admin file — not touched here.)
- `core_components.ex` Phoenix-1.8 idiom: `attr :rest, :global`, `attr :class`; composition
  stays in the page/archetype, never in wrapper components.
- `sg-posture-strip` CSS already encodes the "demoted, below the jobs" intent — the reorder
  realizes what the token layer already assumes.

### Integration Points
- D-01's two-state render (skeleton → data) makes the Playwright wait condition load-bearing
  (D-06): the spec must wait for loaded data, not `.phx-connected` alone.
- New baselines plug into the existing `admin-checkpoints.spec.ts` journey + the
  `needs: [library_tests]`-gated Playwright job.
- The nested-`<p>` fix (D-07) is realized by the redesign removing the offending call site, not
  by a separate patch.
</code_context>

<specifics>
## Specific Ideas

- The alarm's "loud" is **position + existing tone treatment**, never a new class — if that
  reads as insufficient, escalate a lock exception rather than inventing `sg-alarm`.
- Skeleton shapes must match the loaded content's footprint so there is genuinely no layout
  jump (the explicit LAND-04 intent), not generic blocks.
- Keep ALL `<.notice>` slot content inline — block `<p>` children re-create the nested-`<p>`
  axe failure the phase is folding in.
- Org's preserved members/invitations tail must read as clearly secondary to the needs-led
  front door (demoted, below the shared archetype) — it is scoped detail, not a second hero.
</specifics>

<deferred>
## Deferred Ideas

- Loud, color/role-coded distinct treatment for the Global super-admin scope (token-layer
  work) → future milestone (carried from 156 deferred).
- Audit mobile + per-user audit reconciliation → Phase 158.
- Cross-journey coherence sweep + seed enrichment → Phase 159.

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-06-03-sg-notice-tone-rule-duplication.md` — already folded/
  resolved in Phase 156 (D-08 shared-selector merge). No action in 157.
</deferred>
