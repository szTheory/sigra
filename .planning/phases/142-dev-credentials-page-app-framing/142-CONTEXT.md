# Phase 142: dev-credentials-page-app-framing - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a dev-only credentials cheat-sheet LiveView at `/demo/credentials` plus realistic
SaaS app framing ("Vaultr") in the example app layout — so an evaluator who runs
`mix setup && mix phx.server` sees a purposeful product, not a bare Phoenix fixture.

Scope is `test/example/` ONLY (DEMO-01, DEMO-02). **Zero changes to `lib/sigra/`.** A
detailed `142-UI-SPEC.md` already locks the visual/interaction contract; this context
captures the implementation decisions that reconcile that spec with the actual code.

Out of scope: in-app per-persona explainer banner (DEMO-03, deferred), any new seeded
data (owned by Phase 141), Playwright spec (Phase 143), README/docs (Phase 144).
</domain>

<decisions>
## Implementation Decisions

### Personas Consumption Contract
- **D-01:** The "Auth Feature Demonstrated" column text is NOT read from a persona-map
  field — `Example.Demo.Personas.all/0` exposes no `:feature`/`:description`/`:role`
  field (confirmed: keys are `:email, :display_name, :password, :confirmed, :totp,
  :passkey, :locked, :scheduled_deletion, :identity_github, :org_owner, :org_member`).
  The feature copy (already locked verbatim in `142-UI-SPEC.md` copywriting table) lives
  as a hardcoded mapping joined to personas by a stable key (email local part).
- **D-02:** This same feature-text mapping is the SINGLE source for both the credentials
  page AND the seeds stdout block — they must not drift. Define it once, consume twice.
- **D-03:** The `demo-persona-row-{local}` testid value derives `{local}` by splitting
  `persona.email` on `"@"` (e.g. `admin@demo.sigra.dev` → `admin`). Do NOT use
  `display_name` (it renders "Admin (operator)").

### LiveView Structure & testid Application
- **D-04:** `ExampleWeb.Demo.CredentialsLive` must explicitly wrap its render in
  `<Layouts.app flash={@flash}>` — the `:live_view` macro in `example_web.ex` sets no
  default layout, and `Layouts.app/1` declares `flash` as `required: true`. Reference
  pattern: `organization_settings_live.ex:57-61`. `current_scope` and `user_organizations`
  may be omitted (default to `nil`/`[]`); no auth is required for this route.
- **D-05:** The persona table is HAND-ROLLED `<table>` markup using daisyUI
  `table table-zebra` classes — NOT the `<.table>` CoreComponent. `<.table>` has no
  `data-testid` passthrough on the table root or per-row `<tr>`, and the required testids
  (`demo-credentials-table`, `demo-persona-row-{local}`) force custom markup. Reuse the
  visual class vocabulary, not the component. (This refines the UI-SPEC's "reuse `<.table>`"
  directive, which is only partially achievable.)
- **D-06:** Required testids per `142-UI-SPEC.md`: `demo-credentials-table` (table root),
  `demo-persona-row-{local}` (each row), `demo-dev-only-badge` (DEV ONLY badge),
  `app-name` (header brand). All must be present in rendered HTML for Phase 143.
- **D-07:** Page must carry the `badge badge-warning badge-sm` "DEV ONLY" signal per the
  UI-SPEC (DEMO-01 contract requirement). Password cells use monospace (`<code>` /
  `font-mono`). No JS copy-to-clipboard — plain selectable text is sufficient.

### Branding / App Framing (DEMO-02)
- **D-08:** "Vaultr" branding touches exactly two files:
  - `root.html.heex:7` — `<.live_title default="Vaultr" suffix=" · Vaultr">` (replacing
    `default="Example" suffix=" · Phoenix Framework"`).
  - `layouts.ex:48-52` — replace the Phoenix version `<span>` in the brand `<a>` with the
    "Vaultr" app name text + `data-testid="app-name"`. Keep the logo `<img>` slot.
- **D-09:** `layouts.ex` hosts the SHARED `Layouts.app` rendered by every authenticated
  page. Edits are scoped to the brand span and the static nav-link `<ul>` (`:60-72`,
  currently "Website / GitHub / Get Started" → phoenixframework.org) ONLY. Do not touch
  the org-switcher / impersonation rows directly below (`:54-76`).
- **D-10:** Nav-link treatment (the one "Likely" call, agent discretion within guardrail):
  branch on `@current_scope` — render a contextual "Sign In →" affordance when
  UNAUTHENTICATED, and leave existing authenticated affordances untouched. Do NOT render a
  static "Sign In" that would show to already-logged-in users. If branching adds risk to
  the shared layout, the acceptable fallback is a minimal rebrand (replace the Phoenix-
  fixture links without adding new auth-conditional logic).

### Seeds Stdout Integration & Env-Guard Verification
- **D-11:** Print the `=== Demo Credentials ===` block from `Example.Demo.Seeds.run/0`
  (after seeding completes), NOT from `seeds.exs`. `seeds.ex:33,63` already
  `alias`es and iterates `Personas`; `seeds.exs` is a thin `MIX_ENV==:test` raise-guarded
  wrapper. Printing from `run/0` reuses in-scope persona data and the D-02 feature map.
  Stdout format per UI-SPEC: one line per persona `[persona]  email  password  (feature)`.
- **D-12:** SC#2's env-guard verification is NET-NEW (no existing dev-route env test exists
  — `/dev/mailbox` was never env-tested). Mirror the existing `router.ex:172-177`
  `if Application.compile_env(:example, :dev_routes)` gate structurally. Because
  `compile_env` resolves at compile time and the suite runs under `MIX_ENV=test`, the route
  is compiled OUT — so the assertion is **route-absent / 404 for `/demo/credentials`**
  (the only direction cleanly expressible in-suite; do NOT try to assert route-present from
  within the test env).

### Claude's Discretion
- Exact markup nesting, class ordering, and `<.header>` reuse for the section heading
  (UI-SPEC permits reusing the existing `<.header>` CoreComponent — that's fine; only the
  table is hand-rolled).
- Module/function naming inside `CredentialsLive`, the feature-map module location, and
  test file naming/shape.
- Whether the feature-text map lives in `CredentialsLive`, `Personas`, or a small shared
  helper — provided D-02 (single source, no drift between page and stdout) holds.

### Folded Todos
None — no pending todos matched this phase's scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/phases/142-dev-credentials-page-app-framing/142-UI-SPEC.md` — approved visual/
  interaction/copywriting/testid contract for this phase (authoritative for copy + tokens)
- `.planning/REQUIREMENTS.md` — DEMO-01, DEMO-02 acceptance criteria + Out-of-Scope table
- `.planning/ROADMAP.md` — Phase 142 goal + Success Criteria (SC#1–SC#4)
- `test/example/lib/example/demo/personas.ex` — `Personas.all/0` map shape (Phase 141)
- `test/example/lib/example/demo/seeds.ex` — `Seeds.run/0` (stdout target; aliases Personas)
- `test/example/priv/repo/seeds.exs` — thin `MIX_ENV==:test` raise-guarded wrapper
- `test/example/lib/example_web/router.ex` (`:172-177`) — `dev_routes` compile-env gate
- `test/example/lib/example_web/components/core_components.ex` (`:309-390`) — `<.header>`,
  `<.table>` (no testid passthrough — see D-05)
- `test/example/lib/example_web/components/layouts.ex` (`:44-86`) — shared `Layouts.app/1`
  (flash required; brand span `:48-52`; nav links `:60-72`)
- `test/example/lib/example_web/components/layouts/root.html.heex` (`:7`) — `<.live_title>`
- `test/example/lib/example_web/live/organization_settings_live.ex` (`:57-61`) — reference
  for invoking `<Layouts.app flash={@flash}>`
- `test/example/lib/example_web.ex` — `:live_view` macro (no default layout)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Example.Demo.Personas.all/0` — the 6-persona roster (admin/alice/bob/carol/dave/frank),
  each a map keyed `:email, :display_name, :password, :confirmed, :totp, :passkey, :locked,
  :scheduled_deletion, :identity_github, :org_owner, :org_member`. No feature/description field.
- `<.header>` CoreComponent (`core_components.ex:309`) — reusable for the section heading.
- `<.table>` CoreComponent (`core_components.ex:354-390`) — visual classes reusable, but no
  `data-testid` passthrough; hand-roll the table (D-05).
- `Layouts.app/1` (`layouts.ex:44`) — page chrome wrapper; `flash` required, `current_scope`/
  `user_organizations` optional with safe defaults.
- daisyUI class vocabulary already established across `admin_shell.ex`, `core_components.ex`,
  `layouts.ex` (`table-zebra`, `badge`, `btn`, `base-100/200/300`, `base-content`).

### Established Patterns
- Dev-only routes live inside `if Application.compile_env(:example, :dev_routes)` in
  `router.ex` (existing `/dev/mailbox` forward at `:172-177`) — compile-time gate, the
  idiom to mirror for `/demo/credentials`.
- LiveViews that want the app chrome wrap render explicitly with `<Layouts.app flash={...}>`
  (no implicit layout from the `:live_view` macro).
- `seeds.exs` raise-guards `MIX_ENV==:test` and delegates to `Seeds.run/0`; data iteration
  lives in `seeds.ex`.

### Integration Points
- `/demo/credentials` route → added inside the existing `dev_routes` `if` block, `:browser`
  pipeline, no auth.
- `CredentialsLive` → consumes `Personas.all/0` + the D-02 feature map.
- Seeds stdout → emitted from `Seeds.run/0`, same feature map.
- Branding → `root.html.heex:7` + `layouts.ex:48-52` (and scoped nav `<ul>` per D-09/D-10).
- Phase 143 (Playwright) consumes the D-06 testids — they are a downstream contract.
</code_context>

<specifics>
## Specific Ideas

- App name is "Vaultr" (locked in STATE.md + UI-SPEC).
- DEV ONLY warning badge is a DEMO-01 contract requirement, not a style preference.
- Credentials disclaimer copy: "Passwords are public-by-design demo credentials. Never use
  in production." (UI-SPEC copywriting table is authoritative for all copy.)
</specifics>

<deferred>
## Deferred Ideas

- DEMO-03 (in-app per-persona explainer banner) — Future Requirement, post-milestone polish.
- JS copy-to-clipboard widget for passwords — explicitly out (plain selectable text suffices).

### Reviewed Todos (not folded)
- `2026-05-28-phase-135-review-deferred-findings.md` — keyword false positive (Threadline
  demo polish / upstream note); unrelated to a dev credentials LiveView.
- `2026-05-29-phase-138-doctor-info-findings.md` — keyword false positive (Sigra.Doctor
  maintainability findings); unrelated.
- `2026-05-29-deprecation-since-vs-removal-version-axis.md` — keyword false positive
  (deprecation version axes); unrelated.
</deferred>
