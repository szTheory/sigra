# Phase 200: User Detail Elevation - Pattern Map

**Mapped:** 2026-06-25
**Files analyzed:** 14 (1 net-new LiveView + 13 modified contract/test/doc surfaces)
**Analogs found:** 14 / 14 (1 net-new surface clones an exact-role analog; no orphan files)

> No RESEARCH.md — all patterns below are extracted from the live Sigra codebase.
> This phase **restructures** a known page (`user_show_live.ex`) and **adds one net-new
> lib-owned LiveView** (`UserSessionsLive`) plus its generated-host contract propagation.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/live/user_sessions_live.ex` **(NEW)** | LiveView (per-user detail/list + destructive confirm) | request-response + event-driven (revoke) | `lib/sigra/admin/live/audit_user_live.ex` (per-user `/users/:id/X` surface) + `lib/sigra/admin/live/user_show_live.ex` (session table + confirm overlay) | **role+flow exact** (no existing file is this surface yet — clone these two) |
| `lib/sigra/admin/live/user_show_live.ex` *(modify/restructure)* | LiveView (detail) | request-response | itself (in-place recompose) | self |
| `test/example/lib/example_web/router.ex` *(modify)* | route | request-response | its own existing admin route block (`:280-286`, `:312-319`) | self |
| `priv/templates/sigra.install/admin/router_injection.ex` *(modify)* | route template | request-response | its own admin live blocks (`:35-41`, `:67-72`) | self |
| `test/fixtures/install_golden/tree/.../router.ex` *(modify)* | route fixture | request-response | its own admin live blocks (`:252-257`, `:287-288`) | self |
| `priv/templates/sigra.install/admin/sigra_admin.css` *(modify, only if new `sg-*` class)* | config/CSS | n/a | the 3-copy byte-parity set | self |
| `test/example/priv/static/assets/sigra_admin.css` *(modify, conditional)* | config/CSS | n/a | the 3-copy byte-parity set | self |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` *(modify, conditional)* | config/CSS | n/a | the 3-copy byte-parity set | self |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` *(modify — add `user-sessions` slug + helper)* | test (e2e/visual) | request-response | `user-detail` checkpoint block (`:218-231`) + `openUserDetail` helper (`:74-81`) | exact |
| `test/example/priv/playwright/tests/admin-design.spec.ts` *(modify, only if mg-9/10/11 markup changes)* | test (structural) | request-response | mg-9/10/11 assertions (`:304-306`), equivalence test (`:325`) | exact |
| `guides/reference/admin-design-contract.md` *(modify — D-08)* | doc | n/a | Detail Archetype block (`:251-286`) | self |
| `guides/reference/admin-quality-ledger.md` *(modify — D-09 ratchet + new cell)* | doc/ledger | n/a | `user-show-live` cell (`:88`), L3 row pattern (`:85-91`) | exact |
| `test/sigra/admin/glossary_test.exs` *(modify — add new LiveView to in-scope list)* | test (ExUnit) | batch | `@in_scope_files` list (`:21-30`) | exact |
| `test/example/assets/js/admin_hooks.js` | JS hook | event-driven | **NO CHANGE** (`ConfirmDialog` reused verbatim, `:376-480`) | reuse-only |

---

## Pattern Assignments

### `lib/sigra/admin/live/user_sessions_live.ex` (NEW — LiveView, request-response + revoke event)

**There is no exact analog file yet.** Clone the **module skeleton + mount/handle_params +
breadcrumbs + scope helpers** from `audit_user_live.ex` (the only other per-user
`/admin/users/:id/<thing>` lib-owned LiveView), and lift the **session table markup +
revoke/revoke-all events + confirm overlay** verbatim from `user_show_live.ex` (they move
here per D-04). Use `Sigra.Admin.Users.Actions` unchanged for the mutations.

**Module skeleton + runtime_config!** — clone from `audit_user_live.ex:1-26, :277-291`:
```elixir
defmodule Sigra.Admin.Live.UserSessionsLive do
  @moduledoc "Per-user admin session management with scope-safe revoke controls."
  use Phoenix.LiveView
  import Sigra.Admin.Components

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Actions
  alias Sigra.Admin.Users.Detail

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sigra_config, runtime_config!())   # same body as user_show_live.ex:532-545
     |> assign(:detail, nil)
     |> assign(:confirm_action, nil)
     |> assign(:return_to, nil)
     |> assign(:admin_breadcrumbs, nil)
     |> assign(:page_title, "Sessions")}
  end
```
> `runtime_config!/0` is duplicated identically across every admin LiveView
> (`user_show_live.ex:532-545`, `audit_user_live.ex:277-291`) — copy it as-is, just change the
> error string. Do **not** try to extract a shared helper this phase.

**handle_params (load + breadcrumb)** — clone from `audit_user_live.ex:28-61`, but the
breadcrumb gains a final `Sessions` crumb under the user (mirror `audit_breadcrumbs/3` at
`audit_user_live.ex:310-322`, which threads `user_detail_path/3` as the parent crumb):
```elixir
def handle_params(%{"id" => user_id} = params, _uri, socket) do
  admin_scope = socket.assigns.admin_scope
  config = socket.assigns.sigra_config
  detail = Detail.load!(config, admin_scope, user_id)
  return_to = sanitize_return_to(Map.get(params, "return_to"), admin_scope, user_id)
  {:noreply,
   socket
   |> assign(:detail, detail)
   |> assign(:return_to, return_to)
   |> assign(:admin_breadcrumbs, sessions_breadcrumbs(admin_scope, detail, return_to))
   |> assign(:page_title, "#{detail.display_name || detail.user.email} sessions")}
end
```

**Revoke events + confirm dispatch** — lift verbatim from `user_show_live.ex:42-94`
(`open_revoke_session`, `open_revoke_all_sessions`, `cancel_confirm`, `confirm_action`)
and `reload_detail/2` (`:338-341`). They already call `Actions.revoke_session/4` /
`Actions.revoke_all_sessions/3` (`actions.ex:9-34`) — unchanged.

**Page-header + session table markup** — lift the Sessions card from `user_show_live.ex:141-194`.
Reuse `sg-page-header` / `sg-table-panel` / `sg-table` / `<.empty_state>`:
```heex
<section :if={@detail} class="sg-stack sg-stack--6">
  <.scope_ribbon copy={scope_copy(@admin_scope)} />
  <header class="sg-page-header">
    <p class="sg-page-kicker">User</p>
    <h1 class="sg-page-title">Sessions</h1>
    <p class="sg-page-copy">{pluralize(length(@detail.sessions), "active session")}</p>
  </header>

  <section class="sg-card sg-stack sg-stack--3">
    <div class="sg-cluster sg-cluster--between">
      <h2 class="sg-section-heading">Sessions</h2>
      <button :if={@detail.sessions != []} type="button"
        phx-click="open_revoke_all_sessions" class="sg-btn sg-btn--danger sg-btn--sm">
        Revoke all sessions
      </button>
    </div>
    <div :if={@detail.sessions != []} class="sg-table-panel"><table class="sg-table">…</table></div>
    <.empty_state :if={@detail.sessions == []} title="No active sessions">
      <p class="sg-muted sg-text-sm">This user has no active sessions in the current scope.</p>
    </.empty_state>
  </section>
```
> Copy the `<thead>`/`<tbody>` rows incl. per-row revoke trigger verbatim from
> `user_show_live.ex:158-191` (`session_type/1`, `activity_value/1`, `relative_activity/1`,
> `Base.url_encode64(session.hashed_token, …)`). Bring those private helpers along.

**Confirm overlay (APG dialog)** — lift verbatim from `user_show_live.ex:315-333`.
**Do NOT rename** the hook selectors (D-06): the id `user-session-confirm-overlay`,
`phx-hook="ConfirmDialog"`, `class="sg-confirm-overlay"` / `sg-confirm-dialog`,
`aria-labelledby="user-session-confirm-title"`, the `id="user-session-confirm-title"` node,
and `data-sg-confirm-cancel` on the cancel button. `admin-modal-interaction.spec.ts:99-170`
asserts these literal strings:
```heex
<div :if={@confirm_action} id="user-session-confirm-overlay" phx-hook="ConfirmDialog"
     class="sg-confirm-overlay" role="presentation">
  <section class="sg-confirm-dialog" role="dialog" aria-modal="true"
           aria-labelledby="user-session-confirm-title">
    <p id="user-session-confirm-title" class="sg-section-heading">{@confirm_action.title}</p>
    <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">{@confirm_action.copy}</p>
    <div class="sg-confirm-dialog__actions">
      <button type="button" phx-click="cancel_confirm" data-sg-confirm-cancel
              class="sg-btn sg-btn--ghost sg-btn--sm">{@confirm_action.cancel_label}</button>
      <button type="button" phx-click="confirm_action"
              class="sg-btn sg-btn--danger sg-btn--sm">{@confirm_action.confirm_label}</button>
    </div>
  </section>
</div>
```

**Scope-aware path/breadcrumb helpers** — clone the `%Scope{}`-clause pattern from
`audit_user_live.ex:293-372` (`sanitize_return_to/3`, `default_return_to/2`,
`overview_path/1`, `user_detail_path/3`, `with_return_to/2`, `index_path/2`). The new
surface's own `index_path/2` is `/admin/users/:id/sessions` (global) vs
`/admin/organizations/:slug/users/:id/sessions` (org) — same shape as the audit `index_path/2`
at `audit_user_live.ex:368-372`.

---

### `lib/sigra/admin/live/user_show_live.ex` (modify — LiveView, request-response)

**Analog:** itself (in-place restructure to JTBD-first per UI-SPEC "Page Composition Contract").

- **Identity bar (D-01):** recompose `:102-139` (3 status pills + 4-fact `<dl>` + notice). Reuse
  the existing helpers unchanged — `status_pills/1` (`:435-444`), `mfa_value/1` (`:463-469`),
  `last_activity/1` (`:483-493`), `passkey_count/1` (`:478-479`), `summary_alert/1` (`:497-513`,
  **already single-priority** locked>unconfirmed>no-MFA — plug in as-is). Do not add a new
  function component unless reused elsewhere (D-01).
- **Sessions → bounded preview + link-out (D-04):** replace the full Sessions card (`:141-194`)
  with a bounded preview (max ~3 rows, display-only, no revoke buttons) + a `Manage sessions`
  link to `/admin/users/:id/sessions`. **Remove** `open_revoke_session` / `open_revoke_all_sessions`
  handlers and the confirm overlay from this file (they move to `UserSessionsLive`).
- **Organizations → bounded preview (D-05):** cap `:228-253` to a preview + existing
  `pivot_path/4` (`:379-387`) "View all" link.
- **Recent audit (D-05):** preserve the existing `full_audit_path/3` link-out (`:264-266`,
  `:394-401`) unchanged.
- **Host seam (D-07):** keep `extra_detail_sections` rendering at `:310-313` EXACTLY (dual
  atom/string `:title`/`:body` reads), positioned AFTER lib sections, BEFORE Danger Zone.
- **Glossary:** all new copy must match the UI-SPEC "Copywriting Contract" verbatim (the
  `glossary_test.exs` guard already scopes this file).

---

### `test/example/lib/example_web/router.ex` + installer template + golden fixture (modify — route, LOCKSTEP D-12)

**Analog:** the existing per-user audit route, which appears in **both** scope blocks of **all
three** files and is the exact precedent for adding a per-user sessions route.

**Example router** — `router.ex:280-286` (global) + `:312-319` (org). Add `sessions` right
after the `:show` / `audit` lines in each `live_session`:
```elixir
# global block (after router.ex:285)
live "/admin/users/:id/sessions", Elixir.Sigra.Admin.Live.UserSessionsLive, :show
# org block (after router.ex:318)
live "/users/:id/sessions", Elixir.Sigra.Admin.Live.UserSessionsLive, :show
```

**Installer template** — `priv/templates/sigra.install/admin/router_injection.ex:35-41`
(global) + `:67-72` (org). Add the identical `live` lines in the same two `live_session`
blocks (note: this file uses `<%= web_module %>` / `<%= app_module %>` EEx — the new `live`
lines have no interpolation, so paste them as-is).

**Golden fixture** — `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex`
global block ends at `:257` (`AuditUserLive`), org block at `:288`. Add the same two `live`
lines there. **All three must change in the same commit** or `golden_diff_test` fails and
generated-host acceptance smoke breaks (D-12 / SEED-004).

---

### `*/sigra_admin.css` (modify — CONDITIONAL, only if a new `sg-*` class is introduced, D-11)

**Analog:** the 3-copy byte-parity set (currently identical — md5 `9b281962…`, 1484 lines each):
- `priv/templates/sigra.install/admin/sigra_admin.css`
- `test/example/priv/static/assets/sigra_admin.css`
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`

If (and only if) the identity bar needs a genuinely new reused class, it must be written
**byte-identically** into all three (golden-diff gate; the 184→185 unstyled-admin regression
class). Prefer reusing existing primitives (`sg-page-header`, `sg-summary-facts`,
`sg-status-pill`, `sg-detail-grid`, `sg-card`, `sg-stack--N`) so **no CSS change is needed**.

---

### `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (modify — add `user-sessions` slug)

**Analog:** the `user-detail` checkpoint block (`:218-231`) + the `openUserDetail` helper (`:74-81`).

New checkpoint pattern (clone the two-call capture+assert structure):
```ts
// navigate to the new sessions page (add a helper mirroring openUserDetail:74-81)
await page.goto(`/admin/users/${userId}/sessions`);
await waitForLiveViewReady(page);
await expect(page.getByRole('button', { name: 'Revoke all sessions' })).toBeVisible();
await captureAndVerify(page, testInfo, 'user-sessions');
await assertCheckpointScreenshot(page, testInfo, 'user-sessions');
```
> `user-detail` checkpoint assertions (`:223-226`) will need updating: `Revoke session` no
> longer lives on the detail page (D-04 moves it to the new surface). The
> `impersonation-banner` canary (`:268`) MUST stay byte-stable (D-10).

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (modify — CONDITIONAL)

**Analog:** mg-9/10/11 structural assertions (`:304-306`) + content-equivalence test (`:325-333`).
Only touch if the identity-bar/grid/confirm markup change alters the `mg-9`/`mg-10`/`mg-11`
gallery boards (`design_gallery_live.ex:924-1094`). Per D-02, if a new `sg-summary-facts`-class
arrangement is introduced, the `#board-mg-9 .sg-summary-facts` count assertion (`:304`,
currently `1`) and the gallery board markup move together.

---

### `guides/reference/admin-design-contract.md` (modify — D-08)

**Analog:** the Detail Archetype block (`:251-286`). Replace the "Current component composition"
diagram (`:257-279`) with the JTBD-first composition from UI-SPEC, and add an explicit Note that
the `extra_detail_sections/1` host seam is preserved (rendered after lib sections, before Danger
Zone). Success-criterion-2 requires "design contract updated."

---

### `guides/reference/admin-quality-ledger.md` (modify — D-09 ratchet + new cell)

**Analog:** the `user-show-live` L3 cell (`:88`) and the L3 row format (`:85-91`).

1. **Ratchet column 4 from `1` → bare `2`** on the `user-show-live` row (`:88`). **No decorators**
   — the monotonic guard's `awk -F'|'` parse requires column-4 = single `[012]` (ledger doc
   `:36-39`). Expand its Evidence column to cite each applicable Tier-2 proxy (template at
   ledger `:44-51`; proxy definitions at `admin-fractal-scorecard.md:132-165`):
   axe-while-open + 7 APG gates (`admin-modal-interaction.spec.ts`), content-equivalence
   (`admin-design.spec.ts:325`), glossary-clean (`glossary_test.exs`), and the
   documented-as-manual proxies (no `transition: all`, `sg-stack--N` rhythm, target-size ≥24px).
2. **Add a new L3 cell** for the sessions surface (e.g. `user-sessions`), authored clean, citing
   its new checkpoint slug + (since it owns the confirm dialog) the modal-interaction spec.
   Whether it lands Tier 1 or 2 this phase is a planning call (Claude's discretion) — it must not
   regress either way.

---

### `test/sigra/admin/glossary_test.exs` (modify — add new LiveView to scope)

**Analog:** the `@in_scope_files` list (`:21-30`). Add
`"lib/sigra/admin/live/user_sessions_live.ex"` so the new surface inherits the synonym-drift
guard. Note the header comment "exactly the 7 admin LiveViews" (`:11`) — update the count to 8.

---

## Shared Patterns

### Scope-safe per-user LiveView skeleton
**Source:** `lib/sigra/admin/live/audit_user_live.ex:1-61, :277-372`
**Apply to:** `UserSessionsLive`
Every lib-owned admin LiveView: `use Phoenix.LiveView`, `import Sigra.Admin.Components`,
`alias Sigra.Admin.Scope`/`Detail`; `mount/3` seeds `:sigra_config` via the duplicated
`runtime_config!/0`; `handle_params/3` calls `Detail.load!/3` then assigns
`detail`/`return_to`/`admin_breadcrumbs`/`page_title`; scope-aware path helpers are
`%Scope{mode: :organization, organization_slug: slug}` vs catch-all clause pairs.

### Reused APG confirm dialog (no JS change)
**Source:** `test/example/assets/js/admin_hooks.js:376-480` (`ConfirmDialog`) + overlay markup
`user_show_live.ex:315-333`; selectors gated by `admin-modal-interaction.spec.ts:99-170`
**Apply to:** `UserSessionsLive` (the dialog moves here)
The hook is explicitly generic ("Cancel renders first in both LiveViews", `admin_hooks.js:389`).
Reuse verbatim. **Forbidden:** renaming `user-session-confirm-overlay`,
`#user-session-confirm-title`, `.sg-confirm-dialog`, `[data-sg-confirm-cancel]`, or `ConfirmDialog`.

### Scope-aware session mutations
**Source:** `lib/sigra/admin/users/actions.ex:9-34` + `lib/sigra/admin/users/detail.ex:14-59`
**Apply to:** `UserSessionsLive` revoke handlers
`Actions.revoke_session/4` and `revoke_all_sessions/3` already re-load the user scope-safely via
`Detail.load_user!/3` and emit audit. Call them unchanged; reload state via the
`reload_detail/2` pattern (`user_show_live.ex:338-341`).

### `sg-*` cascade-layer / BEM design system (no Tailwind)
**Source:** the 3-copy `sigra_admin.css` + UI-SPEC token tables
**Apply to:** all rendered markup
Layout/spacing/color/motion come from `--sg-*` tokens only. Outer page rhythm is
`sg-stack sg-stack--6`; cards are `sg-card sg-stack sg-stack--3`; never `transition: all`.
Any new class → byte-identical across all three CSS copies (D-11).

### Host-seam preservation (semver contract)
**Source:** `hooks.ex:24` (`@callback extra_detail_sections/1`), `default_hooks.ex:24` (`[]`
default), `detail.ex:35` (data path), `user_show_live.ex:310-313` (render)
**Apply to:** `user_show_live.ex` restructure
The example's no-op `[]` will NOT catch a break — treat the callback signature, data path, and
dual atom/string `:title`/`:body` render position as a frozen generated-host contract (D-07).

### Generated-host route lockstep
**Source:** the per-user audit route present in all three router files
(`router.ex:285,318`; `router_injection.ex:40,71`; golden `router.ex:257,288`)
**Apply to:** the new `/admin/users/:id/sessions` route (D-12)
Example + installer template + golden fixture move in the same commit, in both the
`:admin_global` and `:admin_organization` `live_session` blocks.

### Snapshot recapture routing
**Source:** `scripts/ci/snapshot-recapture-gate.sh` (slug-arg routing) + `snapshot-canary-guard.sh`
(`CANARY="impersonation-banner"`, design `--canary board-notice`)
**Apply to:** recapturing `user-detail`, new `user-sessions`, and (if changed) `mg-9/10/11`
Recapture only the changed slugs through `snapshot-recapture-gate.sh <slug>...`; leave the
canaries byte-stable; leave allowlists empty at end-of-phase (D-10).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/sigra/admin/live/user_sessions_live.ex` | LiveView | request-response + revoke event | **Net-new surface** — no `/admin/users/:id/sessions` LiveView exists. Closest structural clone: `audit_user_live.ex` (per-user `/users/:id/X` skeleton) + `user_show_live.ex:141-194,:315-333` (session table + APG confirm move here verbatim). Authored award-grade from the start (D-04). |
| `user-sessions` checkpoint slug + (optional) `user-sessions` ledger cell | test/doc | n/a | No existing slug/cell for this surface. Clone the `user-detail` checkpoint block (`admin-checkpoints.spec.ts:218-231`) and the `user-show-live` L3 ledger row (`admin-quality-ledger.md:88`). |

---

## Metadata

**Analog search scope:** `lib/sigra/admin/live/`, `lib/sigra/admin/users/`,
`test/example/lib/example_web/router.ex`, `priv/templates/sigra.install/admin/`,
`test/fixtures/install_golden/tree/`, `test/example/priv/playwright/tests/`,
`test/example/assets/js/`, `guides/reference/`, `test/sigra/admin/`, `scripts/ci/`
**Files scanned:** ~22 read/grepped (7 admin LiveViews enumerated; 3 routers; 3 CSS copies
md5-verified identical; 4 Playwright specs; 3 reference docs; glossary test; confirm hook;
actions + detail + hooks loaders)
**Pattern extraction date:** 2026-06-25
