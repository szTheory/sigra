# Phase 214: Debt & Robustness Clear - Context

**Gathered:** 2026-07-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve every tracked real-bug, robustness gap, and deferred code-review item from
previous phases (or explicitly re-triage with rationale), and make local `mix test`
output a trustworthy release signal with zero spurious non-product failures.

Scope is the six fixed items DEBT-01..DEBT-05 + HEALTH-03. This is a stabilization/
hardening lane — **no new features, no UI redesign, no net-new surfaces.** UI-adjacent
nits, config/installer features, and CI-perf work are deferred to later milestones by
`PROJECT.md` (v1.43 STABILIZE thesis).
</domain>

<decisions>
## Implementation Decisions

### DEBT-01 — Oban enqueue guard (compiled-but-unsupervised host)
- **D-01:** Fix the account-deletion enqueue to gate on live Oban supervision, not mere
  compilation — mirror the pattern the two other Oban sites already use
  (`oban_available?() and Process.whereis(Oban) != nil`). The bug is isolated to the
  single site `lib/sigra/account/deletion.ex:308`, which still uses bare
  `with true <- Sigra.OptionalDeps.oban_available?()`.
- **D-02:** Centralize the supervision check into a new `Sigra.OptionalDeps.oban_running?/0`
  SOT and call it from all three sites (`deletion.ex`, `delivery.ex:113`,
  `forwarders.ex:99`) to de-dupe the compiled-vs-supervised distinction. Use raw
  `Process.whereis(Oban)` (matches existing code); do NOT introduce `Oban.whereis/1` —
  the codebase deliberately avoids that API-surface assumption (multi-instance Oban is
  not a requirement).
- **D-03:** Note for the planner — the enqueue at `deletion.ex:207` already runs *after*
  `repo.transaction(multi)` commits and is `rescue`-wrapped (lines 326-329), so today's
  failure is a logged warning, not a poisoned transaction. The remaining defect is the
  wasted insert attempt + noisy warning on every unsupervised-host deletion; the guard
  closes that. Also confirm the async-email and token-cleanup paths stay consistent
  (they already use the correct pattern).
- **D-04:** Regression test: a host where Oban is **compiled but not supervised** (and
  `oban_jobs` absent) — assert deletion still succeeds (sessions revoked, user
  soft-deleted), nothing is inserted, and no crash. Prove the guard, per DEBT-01.

### DEBT-02 — deferred phase-209 code-review items
- **D-05:** **Retire** `scripts/ci/panel-schema-check.sh` with committed rationale rather
  than wiring it into CI. It validates *frozen v1.42 persona-JTBD planning artifacts*
  (`.planning/uat-evidence/v1.42-persona-jtbd/*.md`) — a closed, archived milestone
  deliverable whose inputs never change; a guard over frozen historical docs enforces
  nothing forward-looking, and `grep` confirms zero references in `.github/workflows/ci.yml`.
  Record the retire rationale (in-file comment + phase summary); moving/deleting the
  script is a planner call.
- **D-06:** IN-02 (`$4`-only awk column guard), IN-03 (FAIL stdout-vs-stderr), IN-04
  (CI warmup readiness loop) become **won't-fix** nits on the retired script — no work.
- **D-07:** WR-01 residual (canary-recapture premise) is already resolved; the only
  remaining piece was post-merge-only validation. Confirm-and-close, no new work.

### DEBT-03 — deferred phase-200 code-review items
- **D-08:** WR-01 (foreign-token session revocation) — **harden at the library layer.**
  In `Sigra.Auth.delete_session/3`, when `opts[:user_id]` is present, resolve the session
  and **no-op if `session.user_id` does not match** before calling the store delete.
  This protects ALL callers of the shipped API, keeps `delete_session/3`'s public
  signature unchanged, and is a zero-behaviour-change for callers that omit `user_id`
  (e.g. self-logout-by-cookie-token with no user context still works). The admin path
  (`Actions.revoke_session/4` → `revoke_session/3`) already passes a scope-checked
  `user_id: user.id`, so the guard fires there automatically.
- **D-09:** Add a **deny-path regression test**: a scoped admin cannot revoke a foreign
  user's session token (mismatched `user_id` → no-op, session survives).
- **D-10:** IN-01 — drop the unused `@return_to` socket assign in `user_sessions_live.ex`
  (the breadcrumb already takes `return_to` as a local), OR wire the intended back/cancel
  link. Trivial cleanup; planner picks the cleaner of the two.
- **D-11:** IN-02 — promote the duplicated session-render helpers (`session_type/1`,
  `activity_value/1`, `relative_activity/1`, `pluralize/2`, `scope_copy/1`, and the
  session-table markup) into `Sigra.Admin.Components` (or a shared module) and call from
  both `UserSessionsLive` and `UserShowLive`. Kills silent-drift risk; aligns with the
  admin "same job → same component" coherence direction.

### DEBT-04 — stray Hex `1.20.0` version-ranking wart
- **D-12:** **Repo slice + runbook** (not blocking on the interactive Hex retire).
  Root cause: `1.20.0` is a real Hex release leaked from the "v1.20 GA Launch" milestone
  version; current `@version` is correctly `1.1.0` (`mix.exs:4`,
  `.release-please-manifest.json`). `1.20.0` outranks `1.1.0`, so `{:sigra, "~> 1.0"}`
  resolves to the wrong published version.
- **D-13:** In-phase automatable fixes: (a) delete the stray three-segment git tag
  `v1.20.0` (`git tag -d v1.20.0` + `git push origin :refs/tags/v1.20.0`) so it can't be
  re-parsed as a package version; (b) correct `guides/introduction/contract.md:9`, which
  still cites `1.20.0` as the "current published package truth" — set to `1.1.0`.
- **D-14:** Document the Hex-side retire as a **runbook step for Jon to run**
  (`mix hex.user key generate` → `mix hex.retire sigra 1.20.0 invalid --message "..."`;
  retire, NOT delete — past the grace window; Hex has no web retire button, local key is
  read-only). DEBT-04 is marked resolved with this manual action tracked as a runbook,
  per user decision. (Genuine external escalation — cannot be automated in-phase.)

### DEBT-05 — demo `app.css` orphaned-comment corruption
- **D-15:** **Delete** the orphaned `--sg-*` value fragments and stray `*/` comment tails
  in `test/example/priv/static/assets/css/app.css`. The `:root` block is comment-headers
  (`/* Focus */`, `/* Z-index ladder */`, etc.) whose `--sg-*` declaration *bodies* were
  removed when sg-* moved to `sigra_admin.css`; the leftover dangling values + orphaned
  `* … */` fragments are the corruption. Do NOT reconstruct them — that would duplicate
  `sigra_admin.css`. The intact, correct `--vt-*` tokens (light + dark, fully paired)
  stay untouched. Known orphan sites: lines ~28-33, ~39-43, ~46, and dark-block ~88-91.
- **D-16:** No installer-template copy exists (`find priv/templates -name app.css` returns
  nothing) — example-only fix, no drift risk.
- **D-17:** Add a cheap CI regex guard that fails if `app.css` contains a top-level `*/`
  not preceded by a matching `/*`, so the corruption cannot silently return. Verify in a
  booted browser (`getComputedStyle` / `document.styleSheets[].cssRules`) that surrounding
  rules parse — a clean-looking file is not proof the parser accepted it (that is how this
  hid originally).

### HEALTH-03 — spurious local `mix test` failures
- **D-18:** `Chimeway.Repo` startup noise — Chimeway (`{:chimeway, "~> 1.0", optional: true}`,
  `mix.exs:121`) unconditionally supervises `Chimeway.Repo` in its `Application.start/2`,
  but Sigra's test env gives it no DB config → missing-DB startup noise. Fix by either
  (a) giving `Chimeway.Repo` valid test-DB config in `config/test.exs` (cleanest if the app
  must boot), or (b) suppressing the `:chimeway` app's auto-start of its Repo in Sigra's
  test env (cleanest if the Repo is never exercised). Planner picks based on whether any
  Sigra test actually uses `Chimeway.Repo`; default to suppress-start if it is never
  exercised, config-DB if it is.
- **D-19:** `Sigra.UpgradeIntegrationTest` (`test/upgrade_test.exs`, `@moduletag :upgrade`,
  `async: false`, `timeout: 600_000`) shells out to `mix phx.new` via `InstallFixture` —
  needs the pinned phx_new 1.8.8 archive + a live env DB. Green in CI (library lane
  installs the archive + runs Postgres), red locally without setup. Fix = **graceful
  preflight-skip** when its heavy prerequisites (archive / DB reachability) are absent —
  NOT a blanket `:postgres`/tag exclusion (CLAUDE.md forbids a blanket `:postgres`
  exclusion; the test must still run in CI where prereqs exist).
- **D-20:** Acceptance for HEALTH-03: a clean local `mix test` (with the standard test DB
  up per CLAUDE.md, but WITHOUT the phx_new archive / Chimeway DB) produces zero spurious
  non-product failures — "green" means green.

### Claude's Discretion
- Exact refactor shape of the `oban_running?/0` SOT helper and which module hosts it
  (D-02), the local-vs-shared module for promoted session helpers (D-11), whether to
  drop vs wire `@return_to` (D-10), and whether the app.css CI guard lives in an existing
  lint step or a new tiny script (D-17) — all implementation-level, planner's call.

### Folded Todos
These pending todos ARE the phase requirements (resolved here, then closed):
- `2026-06-24-oban-enqueue-unguarded-when-compiled-but-unsupervised.md` → DEBT-01
- `2026-07-01-phase209-code-review-deferred.md` → DEBT-02
- `2026-06-25-phase200-code-review-deferred.md` → DEBT-03
- `2026-06-21-app-css-comment-corruption-cleanup.md` → DEBT-05
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

**DEBT-01:**
- `lib/sigra/account/deletion.ex` (lines 207, 307-330 — buggy bare guard + rescue)
- `lib/sigra/delivery.ex` (lines 103-116 — correct supervision-gated pattern to mirror)
- `lib/sigra/audit/forwarders.ex` (lines 80-101 — second correct pattern)
- `lib/sigra/optional_deps.ex` (line 79 `oban_available?/0`; host for new `oban_running?/0`)
- `test/example/config/config.exs` (line 77 — `dispatch: :auto → :sync` notion)

**DEBT-02:**
- `scripts/ci/panel-schema-check.sh`
- `.github/workflows/ci.yml` (confirm no reference)
- `.planning/todos/pending/2026-07-01-phase209-code-review-deferred.md`

**DEBT-03:**
- `lib/sigra/auth.ex` (lines ~1495-1526 `delete_session/3`, ~1598-1615 `list_sessions`/`revoke_session`)
- `lib/sigra/session_stores/ecto.ex` (lines 64-72 `delete/2`)
- `lib/sigra/session_store.ex` (line ~39 `@callback delete/2`)
- `lib/sigra/admin/users/actions.ex` (lines 9-21 `revoke_session/4` — already scope-loads user)
- `lib/sigra/admin/live/user_sessions_live.ex`, `lib/sigra/admin/live/user_show_live.ex` (IN-01/IN-02)
- `lib/sigra/admin/components.ex` (IN-02 promotion target)
- `.planning/todos/pending/2026-06-25-phase200-code-review-deferred.md`

**DEBT-04:**
- `mix.exs` (line 4 `@version "1.1.0"`)
- `.release-please-manifest.json`
- `guides/introduction/contract.md` (line 9 — stale `1.20.0` "published truth")
- git tag `v1.20.0` (stray three-segment milestone tag to delete)
- Memory: `reference_milestone_tagging`, `project_sigra_state` (retire runbook)

**DEBT-05:**
- `test/example/priv/static/assets/css/app.css` (lines 6-84 sg-* orphans; 88-91 dark-block orphans)
- `.planning/todos/pending/2026-06-21-app-css-comment-corruption-cleanup.md`
- (confirmed: no `priv/templates/**/app.css` copy)

**HEALTH-03:**
- `deps/chimeway/lib/chimeway/application.ex` (unconditional `Chimeway.Repo` child)
- `deps/chimeway/lib/chimeway/repo.ex`
- `config/test.exs` (no Chimeway.Repo config — add or suppress start)
- `mix.exs` (line 121 `{:chimeway, "~> 1.0", optional: true}`)
- `test/upgrade_test.exs` (`Sigra.UpgradeIntegrationTest`, `@moduletag :upgrade`, InstallFixture)
- `test/test_helper.exs` (no exclusions today)
- `.github/workflows/ci.yml` (lines ~258-269 — library lane installs phx_new 1.8.8 + Postgres)
- `CLAUDE.md` (Local development prerequisites — no `:postgres` tag exclusion by design)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Correct Oban supervision-gate pattern already exists** at `lib/sigra/delivery.ex:113`
  and `lib/sigra/audit/forwarders.ex:99` (`oban_available?() and Process.whereis(Oban) != nil`,
  with explanatory comments) — DEBT-01 replicates/centralizes this, does not invent it.
- **`Sigra.Admin.Components`** is the established home for shared admin render helpers —
  the DEBT-03 IN-02 promotion target.
- **`Actions.revoke_session/4`** already scope-loads the user via
  `Detail.load_user!(config, admin_scope, user_id)` and passes `user_id: user.id` down —
  the DEBT-03 library-layer guard fires on the admin path with no call-site change.

### Established Patterns
- Optional-dep gating lives behind `Sigra.OptionalDeps` — a natural SOT for the new
  `oban_running?/0` helper.
- `--vt-*` (demo) vs `--sg-*` (admin design system) CSS token namespaces are split across
  `app.css` (vt-*) and `sigra_admin.css` (sg-*); the app.css corruption is orphaned sg-*
  leftovers from that split (memory: `reference_example_css_split`).
- CLAUDE.md: `mix test` requires a live test Postgres; there is deliberately NO `:postgres`
  tag exclusion — so HEALTH-03 fixes must gate on *specific heavy prereqs*, not blanket-skip DB.

### Integration Points
- DEBT-01 guard change is library code shipped to hosts via `mix deps.update` — keep it
  behaviour-preserving for supervised-Oban hosts.
- DEBT-03 D-08 hardens the shipped `Sigra.Auth.delete_session/3` public API — must remain
  signature-compatible and a no-op when `user_id` is omitted.
- DEBT-05 touches only `test/example` (build-free demo), not the installer template.
</code_context>

<specifics>
## Specific Ideas

- **DEBT-03 WR-01 → library-layer hardening** (user decision): guard inside
  `Sigra.Auth.delete_session/3`, protecting all callers, not just the admin Actions path.
- **DEBT-04 → repo slice + runbook** (user decision): fix the git tag + `contract.md` in
  this phase; document `mix hex.retire sigra 1.20.0` as a manual runbook for Jon; do NOT
  block the phase on the interactive Hex retire.
</specifics>

<deferred>
## Deferred Ideas

Explicitly deferred by `PROJECT.md` (v1.43 STABILIZE thesis) to later milestones —
matched by todo cross-reference but intentionally NOT folded into Phase 214:

- **Playwright per-shard DB isolation / parallelization** (`2026-06-20-playwright-parallelization-per-shard-db.md`)
  — CI-perf, SEED-005 MILESTONE-ARC CI-PERF. Next milestone or later.
- **UAT demo-DX polish nits** (`2026-06-19-uat-demo-dx-polish-nits.md`) — UI-adjacent,
  rolls into the following admin/operator UI cleanup milestone.
- **`mix sigra.migrate_schema` helper** (`2026-06-20-mix-sigra-migrate-schema-helper.md`)
  — installer feature; waits for a thesis-driven feature milestone.
- **Runtime/boot-time auth-prefix override** (`2026-06-20-runtime-auth-prefix-override.md`)
  — config feature; deferred with the other config/installer features.
- **Vaultr/Tasklane authed-rebrand residuals** (`2026-06-22-vaultr-authed-rebrand-residuals.md`)
  — UI-adjacent demo nit; next UI milestone.
- **White-label auth/email theming** (`2026-06-22-white-label-auth-email-theming.md`)
  — feature; deferred.

### Reviewed Todos (not folded)
All six above were reviewed and excluded per PROJECT.md's explicit deferral list; the
DEBT/HEALTH-scoped todos (oban, phase-209, phase-200, app.css) WERE folded (see Folded Todos).
</deferred>
