# Phase 156: Adopt Shared Components on Baselined Screens - Context

**Gathered:** 2026-06-04 (assumptions mode + deep ecosystem/repo research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the Phase-155 keystone (`Sigra.Admin.Components`) into the admin LiveViews: every
screen imports the shared module and deletes its now-duplicated private `defp`/inline
component markup (COHR-01), and the visual coherence seams on the **5 already-baselined
screens** are reconciled (COHR-02..06). Phase 155 built the 10 components as faithful,
unwired drop-ins (proven by `render_component` byte-equality goldens); Phase 156 is the
**migration + seam-reconciliation** phase that consumes them.

**In scope:** `import Sigra.Admin.Components` + delete duplicate private defs across all
lib admin LiveViews; the 6 coherence requirements; deliberate Playwright re-records only
where an intended visual delta lands (reviewed via HTML report); keep `admin-generated`
parity lane green.

**Out of scope (later phases):** the Overview *visual redesign* (needs-led layout,
task-grid prominence) → Phase 157; the per-user audit + audit-mobile reconciliation →
Phase 158. Phase 156 may import-swap those files' duplicate component code (pixel-neutral)
but does NOT redesign their layout.

**Hard constraints (locked, carried from STATE.md + 154/155):** No new Hex deps, no
Tailwind, no Alpine, no `assign_async/3`. **No new CSS classes invented** and no
token-layer work (the `sg-*` layer is mature/Emil-Kowalski-compliant; this milestone
audits *usage*). All styles stay inside `@layer sg-components`. A baseline re-record is a
bug UNLESS it is a deliberate, HTML-report-reviewed intended delta (SC-7). `admin-generated`
parity lane stays green. axe WCAG A/AA green across chromium + mobile + dark.
</domain>

<decisions>
## Implementation Decisions

### Migration set — which screens, what work (COHR-01)
- **D-01 [Confident, verified]:** The **5 baselined screens** are driven by Playwright
  slugs, which map (verified against `router.ex:256-293` + `admin-checkpoints.spec.ts`) to:
  `global-user-index` → `UsersIndexLive` (`/admin/users`); `org-scoped-admin` →
  `UsersIndexLive` (org-scoped `/admin/organizations/:slug/users`); `user-detail` →
  `UserShowLive`; `audit-explorer` → **`AuditIndexLive`** (`/admin/audit`);
  `impersonation-banner` → the host **`admin_shell.ex`** banner. These four files (+ banner)
  get **full seam reconciliation** (COHR-02..06) and own their pixels.
  - NOTE: `index_live.ex` (Global Overview), `organization_live.ex` (Org Overview), and
    `audit_user_live.ex` (per-user audit) are **NOT baselined** — they are Phase 157/158.
    The roadmap's older "extraction-source" list (which named the Overviews) described where
    Phase 155 *extracted* components from, not the Phase 156 baselined set.
- **D-02 [Likely → locked]:** COHR-01 ("no duplicated private defs remain") is honored
  across **all** lib admin LiveViews in 156: the byte-identical `defp metric_link`/
  `defp task_card` duplicated across `index_live.ex:118` and `organization_live.ex:169` are
  **removed via pixel-neutral `import` swap** (faithful drop-ins proven by 155 goldens; those
  screens have no committed baselines, so zero re-record). Their *visual redesign* stays in
  157; `audit_user_live.ex`'s visual reconciliation stays in 158. So **156 = no duplicate
  component code anywhere + the 5 baselined screens visually coherent.**

### Baseline re-record strategy (SC-7)
- **D-03 [Confident + COHR-04 consequence]:** Deliberate, HTML-report-reviewed re-records
  are expected on up to **4 baselined slugs ×3 projects**: `user-detail` (COHR-02 header
  archetype change — see D-05), and `global-user-index`, `org-scoped-admin`, `audit-explorer`
  (COHR-04 discrete scope ribbon now appears on list/explorer screens — see D-08). The
  `impersonation-banner` slug stays byte-green unless its COHR work changes pixels.
- **D-04 [Confident]:** **No blanket "re-record to be safe."** Every change that is NOT a
  named intended delta must stay **byte-green** — notice `sg-list-row`→`sg-notice` is a
  byte-clone (`app.css:945-967` vs `971-993`); `applied_chip`/`summary_chip`/`empty_state`/
  `page_back`/`scope_ribbon` are faithful drop-ins. Re-record only after the HTML report
  confirms the delta is the intended one (the Jest-snapshot footgun 155-D-13 banned).

### Per-screen seam reconciliation
- **D-05 [Confident]:** COHR-02 — `UserShowLive`'s `sg-card`-boxed identity header
  (`user_show_live.ex:97`) converts to the open `sg-page-header` archetype (matching
  `users_index_live.ex:72` / `audit_index_live.ex:50`). This is the intended visual delta on
  `user-detail` → deliberate re-record.
- **D-06 [Confident]:** COHR-03 — leaf/detail screens use a single `<.page_back>` consuming
  `return_to`; breadcrumbs handle hierarchy; `page_back` stays leaf-only (NOT on list/Overview
  per contract L91). COHR-05 — all contextual alerts/flashes render through `<.notice>` with
  tone via `data-tone`; no ad-hoc `sg-list-row` *alert* rows remain (`sg-list-row` survives as
  a non-alert layout primitive). COHR-06 — empty states via `<.empty_state>`.

### COHR-04 — scope ribbon (researched decision)
- **D-07 [decided after ecosystem + repo research]:** Render the shared `<.scope_ribbon>` —
  the **quiet `sg-muted sg-text-sm` discrete span, no new CSS** — on **every list AND leaf
  screen**, including the list/explorer screens (`UsersIndexLive`, `AuditIndexLive`) that
  today bury scope in the `sg-page-copy` header subtitle. On those screens, add
  `<.scope_ribbon copy={scope_copy(@admin_scope)} />` as a discrete element in the header
  region (no `page_back` sibling on lists) and **remove the scope copy from the `sg-page-copy`
  subtitle**, so the scope-display job is satisfied by exactly one component everywhere.
  - **Why this won:** Both research lenses converged. Ecosystem prior-art (Stripe, AWS,
    Supabase, Linear, GitHub, LiveDashboard/Oban Web): scope belongs in a *quiet, persistent*
    element; *loud* banner/color treatment is reserved for risky states only — and Sigra's
    ribbon is the quiet form, so banner-blindness does not apply. Repo evidence mandates it:
    COHR-04 names the *component* "on every list and leaf screen"; the design contract's List
    archetype reserves a discrete ribbon slot (L184); and the milestone law is "same job →
    same component" (prose-on-lists vs span-on-leaves is exactly the divergence to kill).
    Accessible (decorative, no ARIA per contract L101), dark/light-safe (mature `sg-muted`
    token), honors the no-new-token lock.

### Notice-tone drift guard (folded todo)
- **D-08 [Likely → locked]:** COHR-05 concludes the notice-migration window, so resolve the
  `sg-notice`/`sg-list-row` tone-rule duplication **now** via **shared-selector merge**:
  `.sg-list-row[data-tone="X"], .sg-notice[data-tone="X"] { … }` — one source of truth,
  invents no class, stays inside `@layer sg-components`. `sg-list-row` keeps its non-alert
  layout uses (audit/invitation rows), so the tone block is **deduplicated, not deleted**.

### Parity lane & banner dual-maintenance
- **D-09 [Confident]:** The `admin-generated` parity lane **auto-tracks** the migration with
  no separate handling — the example host routes directly to the lib-owned
  `Sigra.Admin.Live.*` modules; there are no generated host LiveView copies to migrate in
  parallel. **Exception:** the impersonation banner is dual-maintained — any banner change
  must edit **both** `priv/templates/sigra.install/admin/components/admin_shell.ex` **and**
  `test/example/lib/example_web/components/admin_shell.ex` or the parity lane goes red
  (the installer-template-drift trap).

### Claude's Discretion
- Exact placement of `<.scope_ribbon>` within the list-screen header region; whether the
  freed `sg-page-copy` subtitle is dropped or repurposed to non-scope descriptive copy
  (a ui-phase concern).
- Scope microcopy: default to keeping the existing `scope_copy/1` strings (byte-faithful,
  least-surprising). Tightening to a short scope label ("All organizations" / org name) is
  a ui-phase discretionary refinement, not required here.
- Per-screen migration order; which screen migrates first.
- Internal modularization of the migration commits (one screen per commit recommended).

### Folded Todos
- `.planning/todos/pending/2026-06-03-sg-notice-tone-rule-duplication.md` — **folded** into
  D-08. The migration window it was waiting for (154→156) concludes here, and the CSS
  boundary that blocked it in Phase 155 permits a same-class selector merge.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- **The built module (call sites must conform to it):** `lib/sigra/admin/components.ex` — 10
  components; `scope_ribbon/1` (~L241-262) emits `<span class="sg-muted sg-text-sm">`;
  `notice/1` emits `<div class="sg-notice" data-tone={…}>`.
- **Authoritative markup spec:** `guides/reference/admin-design-contract.md` — `scope_ribbon`
  entry (L95-103: "Present on every list and leaf screen"; decorative, no ARIA; do NOT replace
  the topbar `sg-scope-pill`); `page_back` (L91: leaf-only); **page archetypes** — List
  (L169-205; ribbon slot at L184) and Detail (L209-242; back+ribbon cluster L217-219); notice
  entry (ARIA amended in 155-D-09).
- **Slug → file mapping (proves D-01):** `test/example/lib/example_web/router.ex:256-293`
  (admin route bindings); `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`
  (slug routes: `/admin/users` :175, `/admin/users/:id` :187, `/admin/organizations/:slug/users`
  :203, banner on `/organizations/:slug/members` :225-233, `/admin/audit` :247).
- **Migration targets (lib-owned LiveViews):** `lib/sigra/admin/live/users_index_live.ex`
  (`defp summary_chip` :336; inline applied-chip :168; inline empty-state :285; scope in
  `sg-page-copy` :75; `scope_copy/1` :407), `user_show_live.ex` (`sg-card` header :97; inline
  ribbon :94; `sg-list-row` notice :131), `audit_index_live.ex` (inline applied-chip :115;
  empty-state :172; scope in `sg-page-copy` :53), and (defp-removal only, pixel-neutral)
  `index_live.ex:118` + `organization_live.ex:169` (duplicate `defp metric_link`/`task_card`).
- **Banner dual-maintenance pair:** `priv/templates/sigra.install/admin/components/admin_shell.ex`
  + `test/example/lib/example_web/components/admin_shell.ex` (keep in sync; see D-09).
- **CSS (notice byte-clone + tone-merge target):** `test/example/priv/static/assets/css/app.css`
  — `.sg-list-row[data-tone]` (945-967), `.sg-notice` clone (971-993); merge selectors per D-08.
- **Keystone baselines (re-record ONLY the intended-delta slugs per D-03):**
  `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` + `…-snapshots/`.
- **Parity lane (auto-tracks; keep green):** `scripts/ci/admin-acceptance-smoke.sh` +
  `test/example/priv/playwright/tests/admin-generated.spec.ts`.
- **Prior phase contracts:** `.planning/phases/155-shared-component-foundation-keystone/155-CONTEXT.md`
  (D-06 forward-reference to this phase), `154-design-contract-sg-notice/154-CONTEXT.md`.
- **Planning sources:** `.planning/ROADMAP.md` (phase 156, COHR-01..06; 157/158 boundary),
  `.planning/REQUIREMENTS.md` (COHR-01..06, lines 27-32), `.planning/STATE.md` (locked
  constraints), `.planning/PROJECT.md` (milestone law "same job → same component"; no
  token-layer work this milestone), `.planning/METHODOLOGY.md` (decisive defaulting).
- **External prior-art (COHR-04 rationale):** Stripe test/live split, AWS account-color nav,
  Supabase/Linear/GitHub scope-in-header, NN/g banner-blindness — scope = quiet persistent
  element; loud treatment reserved for risk states (see DISCUSSION-LOG.md).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All 10 shared components already exist and are byte-faithful (155 `render_component`
  goldens). `scope_ribbon` reuses exactly `sg-muted sg-text-sm` (no new class); `notice`
  uses `sg-notice` (byte-clone of `sg-list-row`) → migration is pixel-neutral by construction.
- The example host routes admin URLs straight to `Sigra.Admin.Live.*` — one edit changes
  both the keystone baselines AND the parity lane render (no host LiveView copies).

### Established Patterns
- `core_components.ex` Phoenix-1.8 idiom: `import` (not `use`), `attr :rest, :global`,
  `attr :class`. Migration is `import Sigra.Admin.Components` + delete private defs + repoint
  call sites; composition stays in the page archetypes, never in wrapper components.
- Scope is conveyed two divergent ways today: a discrete `sg-muted sg-text-sm` span on leaf
  screens vs `sg-page-copy` header prose on list screens — D-07 converges them on one component.
- `page_back` is leaf-only; list screens have no back-nav sibling to cluster the ribbon against.

### Integration Points
- Proof gate: 155's component-equality test stays green (call-site changes don't touch the
  module). The admin-checkpoint Playwright job is gated `needs: [library_tests]`.
- Banner COHR work must touch the template + example copy together (installer parity).
- The tone-merge (D-08) is a CSS-only edit in `app.css` inside `@layer sg-components`.
</code_context>

<specifics>
## Specific Ideas

- `<.scope_ribbon>` is the QUIET form (muted span), not a loud banner — this is what makes
  "ribbon on every screen" coherent rather than noisy. The loud/color treatment idea is
  reserved for the genuinely risky Global scope and deferred (token work out of scope).
- Migrate one screen per commit; assert byte-green per screen before moving on; re-record an
  intended-delta slug only after reviewing its HTML report.
- Confirm whether call sites pass `tone` as string vs atom before locking notice goldens
  (carried from 155-specifics) so `data-tone` bytes match.
</specifics>

<deferred>
## Deferred Ideas

- **Loud, color/role-coded distinct treatment for the Global super-admin scope** (the
  genuinely risky "can touch everything" state, analogous to Stripe test-mode / AWS prod
  color) — strongest enhancement from the ecosystem research, but it needs token-layer/CSS
  work that PROJECT.md locks out of this milestone. Impersonation already has its dedicated
  banner. → future milestone.
- Scope microcopy tightening to a short scope label (vs the current descriptive
  `scope_copy/1` sentence) → ui-phase discretionary / future polish.
- Overview needs-led redesign → Phase 157. Per-user audit + audit-mobile → Phase 158.

### Reviewed Todos (not folded)
- None. The one matched todo (sg-notice tone duplication) was folded into D-08.
</deferred>
