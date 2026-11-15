# Phase 260: Deterministic Output, Before Catalog and PNG Park - Research

**Researched:** 2026-11-15
**Domain:** Generator determinism, template/example/golden parity, shipped-CSS defect repair, text-only "before" catalog, CI PNG-lane demotion (Elixir/Phoenix library + Playwright + GitHub Actions)
**Confidence:** HIGH on repo facts (every tagged value below was read or executed this session); MEDIUM on CI runtime consequences (read from the live workflow, not observed in a run)

## User Constraints (from CONTEXT.md)

No `260-CONTEXT.md` exists (the owner chose to continue without it). The constraints below are the locked inputs the planner must honor; they come from the owner-confirmed ADR and the roadmap, not from a discuss session.

### Locked Decisions
- **ADR 005, decision 7 (owner-confirmed 2026-11-15):** "The PNG-compare lanes are parked in a separate small pull request at the end of Phase 260: `admin_checkpoints` (27 PNGs) and `demo_showcase` (4 PNGs) move from PR-blocking to dispatch. The real sign-in and generated-host smoke, axe, golden install and behavior specs stay on the PR path. The impersonation-banner canary is never allowlisted, and no baseline is ever recaptured on darwin. Merging that pull request needs explicit owner approval and happens before Phase 261 starts." [VERIFIED: .planning/decisions/005-brand-adoption-compatibility-policy.md:134]
- **ADR 005, decision 9:** "Verify only: no builder, no new Mix task." [VERIFIED: .planning/decisions/005-brand-adoption-compatibility-policy.md:27]
- **ROADMAP success criteria 1-5 and requirements BGEN-01..08** (copied in the Phase Requirements table below).
- **Milestone gates:** one golden rebless per phase (reviewed per directory, mechanical changes in separate commits, pinned `phx_new 1.8.8`); no new workflow, receipt, ledger or hermetic fake of an external service; privacy grep (seeded `.test` addresses only); nothing pushed, merged, released or tagged without explicit owner approval; no token value, logo, copy, `Components` markup or `Profile` key changes in this phase. [VERIFIED: .planning/ROADMAP.md:39-52, 105]

### Claude's Discretion
- How the parked lanes are demoted (mechanism; see "Park PR" - two options with a recommendation).
- Catalog file layout, normalizer design, manifest format, where the generated-lane "before" comes from.
- Whether owner decision #13 (orphaned CSS guards) is "wire" or "retire": ROADMAP lists it as needed in this phase and ADR 005 explicitly does not record it ("Decisions #10 and #13 belong to later phases ... and are not recorded here"). Research recommends **wire**; it still needs the owner's explicit yes at execution time.

### Deferred Ideas (OUT OF SCOPE)
- Any token value, logo, copy, `Components` markup, `Profile` key change (Phases 261-262).
- New PNG baselines, evidence ledgers, receipts, hermetic fakes, a brand generator or new Mix task (REQUIREMENTS "Out of Scope").
- The shipped-byte fixes owed before Phase 262 (registration timing oracle, passkey-options oracle, generated confirm/reset fixes): these change generated output and have no phase yet (259-VERIFICATION.md:302). Not Phase 260 work; see Open Question 5.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BGEN-01 | Template/example/golden parity; refresh example `sigra_auth.css` (903 diff lines); parity test for every copied asset | Asset inventory and measured drift in "BGEN-01"; new byte-parity table test with planted-divergence control; completeness check so no static asset escapes the table |
| BGEN-02 | Double install byte-identical; `rebless_golden --check` clean under pinned `phx_new 1.8.8` | Only nondeterminism source is the wall-clock migration timestamp; `--check` ran clean this session (27.9 s); double-install test design |
| BGEN-03 | Before catalog, text, three tiers, seeded `.test` personas, pinned SHA, byte-identical to main, template CSS, no PNG | Tier design, volatility list, pure-render spike, finding that the example app is NOT a render of generated screens, wave-0 ordering |
| BGEN-04 | L1: `.sg-brand-mark*` and explicit Light/Dark rules into shipped `sigra_admin.css`, drop `app.css` duplicates, real generated host proof, CSS version stamp | Measured L1 scope (wider than stated), conformance-guard conflict (verified), stamp mechanism, tests to update, generated-host assertions |
| BGEN-05 | Wire `admin-css-conformance.sh` and `admin-token-completeness.sh` into `mix ci`/`fast_checks` (or retire) | Both pass today (run this session); `mix ci` is the PR gate so an alias edit needs no `ci.yml` change; L1 interplay |
| BGEN-06 | Park PR: demote PNG-compare lanes to dispatch; keep real-login/generated-host smoke, axe, golden install, behavior specs; canary never allowlisted | Live `ci.yml` read in full for these lanes; required-check mapping; guard ripple list; two mechanisms |
| BGEN-07 | Before/after text-diff report script | `diff -ru` over two directories, ExUnit wrapper with planted before/after pair, BSD-safe shell rules |
| BGEN-08 | Extend `DesignGalleryLive` with auth-page, email and status-mark states (dev-only) | Gallery structure, isolation test, board-registry coupling, what can honestly be drawn before `status_mark` exists |
</phase_requirements>

## Summary

Phase 260 is "mechanism before paint": nothing visible to a host user may change, but five things must become true and provable. The repo already has most of the machinery (the golden fixture and its `--check`, `Sigra.Test.InstallFixture`, the Phase 259 brand test suite with its `RegenGuard`, the copy inventory, `Phoenix.LiveViewTest` pure rendering, two CSS guard scripts). The work is mostly wiring, extending, and one real repair (L1). Research read the live files and ran the cheap probes; seven findings change the plan and must reach the planner before it splits work:

1. **The example app is not a render of the generated auth screens.** The example has no `SigraAuthComponents`, links `sigra_auth.css` only from `home.html.heex`, and its auth pages are Tasklane `vt-*` pages. The generated screens exist as compiled code only in a freshly generated host (golden tree = the committed source). The roadmap/architecture assumption "tier 2 renders generated auth flows through the example app" is wrong for the generated lane. See "BGEN-03".
2. **L1 is wider than the roadmap says.** 56 `sg-*` classes used by library/shell markup are defined only in the example `app.css`, not in shipped `sigra_admin.css` (measured below). Roadmap scope (brand mark + explicit Light/Dark) is the minimum; the rest needs a recorded decision. And moving the explicit-theme blocks verbatim makes `admin-css-conformance.sh` fail (raw hex outside `:root`), so L1 and L2 must be designed together.
3. **`design_gallery` `@snapshot` already does not run on pull requests**; it runs on push/schedule/dispatch, where a red snapshot step reds `ci-gate` on `main`. `admin_checkpoints` and `demo_showcase` run PNG compares on every PR today. Parking needs all three handled, and it ripples into guards that enforce the demotion enumeration (manifest, observer, `p10`, `p13`, inventory contract).
4. **`admin_checkpoints` also carries the per-checkpoint axe gate** (all three projects, including dark); `demo_showcase` carries three non-PNG behavior tests (real login locked to Tasklane, evaluator orientation, ten-minute path). Demoting whole lanes removes them from the PR path, which contradicts ADR 005's "axe and behavior specs stay". Demoting only the *comparison* keeps them. This is the central park decision (Option A vs B).
5. **`mix ci` is the PR-required library gate** (`library_tests_shard` runs `MIX_ENV=test mix ci`). Wiring the CSS guards and the new scaffold tests through the `mix.exs` alias costs zero `.github` diff.
6. **Installer nondeterminism is only the wall-clock migration timestamp** (`DateTime.utc_now()` in the runner). No template embeds random or time values. Double-install is cheap to prove.
7. **A manual `ci.yml` dispatch is only allowed from a `v*` tag or with `recapture_branch` set**, so "parked to dispatch" really means "runs on release-tag evidence dispatches and recapture dispatches".

**Primary recommendation:** Execute in this order: (W0) write the guards first (asset-parity table test red on `sigra_auth.css`, double-install test, catalog harness) and **capture the before catalog while shipped bytes are still identical to main**; (W1) BGEN-01 refresh + BGEN-02; (W2) L1 + L2 designed together, one golden rebless; (W3) BGEN-07/08; author the **park PR first as an independent branch off `main`** (it changes no shipped byte and is independent of the milestone branch), get owner merge approval, and finish with the fresh-host run and `MIX_ENV=test mix ci`. Park the PNG *comparison* (env flag, Option A) rather than whole lanes unless the owner prefers ADR-literal lane demotion.

## Architectural Responsibility Map

Phase 260 is not a web-tier feature; the tiers that matter are the ownership lanes from ADR 005 plus CI.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin brand-mark and explicit theme CSS (L1) | Host-owned CSS file copied once from the installer template | Library-owned markup (`lib/sigra/admin/**`) and generated shell (`admin_shell.ex`) that emit the classes | The classes are emitted by the generated shell; the rules must ship in the same generated stylesheet or hosts render both logos and ignore the theme switch |
| Template/example/golden parity | Test suite (ExUnit) | Installer templates, hand-maintained example, golden tree | The example is a hand-kept mirror; only a test can keep three byte copies equal (ADR 005: verify, don't generate) |
| Deterministic install | Installer runner (`Sigra.Install.Runner`) | `InstallFixture` normalizer | Runner owns timestamps; fixture normalizes what the installer does not own (phx.new salts) |
| Before catalog tier 0/1 (copy/class inventory, pure render) | Test suite (root and example) | Library components, `Sigra.Test.Brand.CopyInventory` | Pure functions of literal assigns; no browser |
| Before catalog generated-lane pages and emails | A freshly generated host (scaffold + boot) | Golden tree + copy inventory as the committed baseline | Only a generated host compiles the generated screens |
| PNG-compare demotion | CI workflow (`ci.yml`) | Playwright specs, `MAINTAINING.md`, ci-skip manifest guards | Demotion is a CI policy; guards enforce its enumeration |
| CSS guards in `mix ci` | Mix alias (`mix.exs`) | `scripts/ci/*.sh` | `mix ci` is already the PR gate |

## Standard Stack

No new dependencies (REQUIREMENTS: "Net-new dependencies: none"). Everything below already exists.

### Core
| Tool | Version | Purpose | Why standard here |
|------|---------|---------|-------------------|
| ExUnit + `Phoenix.LiveViewTest` (`render_component`, `rendered_to_string`) | LiveView 1.2.12 locked at root, 1.1.28 in example | Tier-1 pure render, parity and contract tests | Precedent: `test/sigra/admin/components_test.exs` uses `render_component` with literal assigns [VERIFIED: components_test.exs:141] |
| `Sigra.Test.InstallFixture` | in-repo | Scaffold fresh Phoenix host, run installer, normalize tree/stdout | The only generated-host harness; used by golden, idempotency, upgrade tests [VERIFIED: test/support/install_fixture.ex] |
| `mix sigra.fixture.rebless_golden` | in-repo | Only writer of golden fixtures; `--check` = drift detector | [VERIFIED: lib/mix/tasks/sigra.fixture.rebless_golden.ex:15-17] |
| `Sigra.Test.Brand.RegenGuard` | in-repo (Phase 259) | Refuses fixture writers under `CI=true` | Every opt-in writer in the brand suite must go through it [VERIFIED: test/support/brand/regen_guard.ex:1-25] |
| `Sigra.Test.Brand.CopyInventory` | in-repo (Phase 259) | Tier-0 copy inventory per lane (`library.tsv`, `generated.tsv`, `host.tsv`) | Already committed; do not rebuild [VERIFIED: test/fixtures/brand/copy-inventory/] |
| Playwright `@playwright/test` + `@axe-core/playwright` | 1.59.1 (cache key `playwright-chromium-1.59.1-v3`), axe ^4.13.0 | Existing behavior/axe specs, generated-host smoke | [VERIFIED: ci.yml:1255; package.json:12-13] |
| `diff -ru`, `shasum -a 256`, `cmp -s` | BSD and GNU | Before/after report, manifests, byte compare | Present on darwin and ubuntu; avoid GNU-only flags |
| `lazy_html` | 0.1.11 (example, explicit); transitive at root | Optional HTML parsing for the normalizer | Already locked [VERIFIED: test/example/mix.lock:30] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Regex normalizer (Elixir) | `canonicalize.ts` parse5 allowlist (Phase 216) | canonicalize drops `id` and most attrs and outputs a sha; good for hashing, wrong for a human-reviewable text diff. Do not reuse it for the catalog. |
| Commit normalized HTML | Upload as CI artifact (ROADMAP SC-1 parenthetical) | Artifacts expire (7-14 day retention in `ci.yml`), so a CI artifact cannot be the durable "before" that Phase 262 diffs against; also needs a `.github` edit. Commit text (~1 MB, same order as the 748 KB golden tree). |

**Installation:** none. **Version verification:** `elixir 1.19.5 / OTP 28.5` (`.tool-versions`), `phx_new-1.8.8` archive installed locally [VERIFIED: `mix archive`, `.tool-versions`]; local `node` is v26.10.0 while CI pins node `20` (ci.yml `setup-node` `node-version: '20'`): keep any new `.mjs` script on features both support.

## Package Legitimacy Audit

No external package is installed or added by this phase, so the legitimacy gate is not applicable. Packages named above (`lazy_html`, Playwright, axe) are already locked in the repo; nothing was discovered via web search or added to a manifest.

**Packages removed due to [SLOP] verdict:** none. **Packages flagged [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```
                    SHIPPED SOURCES (must stay byte-identical to main until W2)
 priv/templates/sigra.install/**   lib/sigra/admin/**   test/example/lib/** (mirror)
        |                                   |                    |
        | EEx via installer                 | render/1 pure      | ConnCase GET + seeded personas
        v                                   v                    v
  [Generated host]  <--- golden tree ---  TIER 1 (pure render)   TIER 2 (page render, example)
  (phx_new 1.8.8 +      test/fixtures/    root/example ExUnit    needs Postgres
   sigra.install)       install_golden    literal assigns
        |  rebless --check        \             \                   /
        |  double-install test     \             \                 /
        v                           v             v               v
   determinism proof            normalizer: csrf, phx-*, uuid->persona, relative time, ?vsn=
                                        |
                                        v
              test/fixtures/brand/before/**  (+ MANIFEST: pinned main sha, tree hashes,
                                              CSS sha256s, per-file sha256, coverage note)
                                        |
        W2: L1 repair changes shipped CSS ----> AFTER capture (tmp, gitignored) ----> BGEN-07 diff report

 PR path today:  ci-gate.needs -> example_playwright_smoke ("Example Playwright smoke (full lifecycle)",
                 ruleset-required) -> aggregates example_playwright_shard (5 matrix seams)
                 admin_checkpoints: PNG compare on PR   demo_showcase: PNG compare on PR
                 design_gallery: PR runs --grep-invert '@snapshot'; push/schedule run @snapshot
 Park PR:        separate branch off main -> ci.yml (+ specs) -> owner approval -> merge -> Phase 261 may start
```

### Recommended Project Structure
```
test/support/brand/catalog.ex            # tier 0/1 helpers, normalizer, writer (via RegenGuard)
test/sigra/brand/catalog_test.exs        # determinism, normalizer unit tests, manifest hash, privacy
test/sigra/install/asset_parity_test.exs # BGEN-01 table
test/sigra/install/double_install_test.exs  # BGEN-02 (:scaffold; add to ci.install_golden alias)
test/example/test/example_web/catalog_test.exs  # tier 2 (:example_app)
test/fixtures/brand/before/              # committed normalized HTML + MANIFEST.json  (-text in .gitattributes)
scripts/brand/catalog-diff.sh            # BGEN-07 (+ ExUnit wrapper test)
```

### Pattern 1: Pin-by-tree-hash, not only by commit
**What:** The manifest records `git rev-parse origin/main` (4cf5829ea at research time), `git rev-parse HEAD:lib`, `HEAD:priv`, and per-CSS-file sha256, and the capture command refuses to run unless `git diff --quiet origin/main -- lib priv` succeeds. **When:** every "before" capture. **Why:** "byte-identical to main" becomes a checkable precondition instead of a claim. Verified true now: `git diff --stat origin/main...HEAD -- lib priv` is empty (origin/main == merge-base == 4cf5829ea). [VERIFIED: git, this session]

### Pattern 2: Writers are maintainer actions, never CI
**What:** Capture is an opt-in writer routed through `RegenGuard.requested?/3` (refused when `CI=true`); the CI-resident tests are (a) determinism (render twice, compare), (b) normalizer unit tests with planted volatile inputs, (c) manifest integrity (re-hash committed files), (d) privacy scan. **Why:** a CI test that re-renders and compares to the committed "before" would be red the moment Phase 261 lands, so the "before" can only be protected by hash, not by equality with sources. `RegenGuardTest` fails when a file reads the environment directly, so use the guard. [VERIFIED: test/sigra/brand/regen_guard_test.exs:1-12]
**Immutability:** "before" mode refuses to overwrite when `before/MANIFEST.json` exists; "after" writes under the gitignored `/tmp/`. [VERIFIED: .gitignore:30 `/tmp/`]

### Pattern 3: Pure render of a library LiveView (verified spike)
```elixir
# Source: executed this session via MIX_ENV=test mix run --no-start (scratch script, not committed)
assigns = %{__changed__: nil, detail: detail, admin_scope: scope, current_scope: %{}, return_to: "/admin/users"}
html = Phoenix.LiveViewTest.rendered_to_string(Sigra.Admin.Live.UserShowLive.render(assigns))
```
Result: 5,196 bytes for a locked/unconfirmed user, containing the verbatim copy `Locked — revoke active sessions and unlock below.` (the copy Phase 262 must correct). Two volatile spots confirmed: a `_csrf_token` hidden input (random `Phoenix.Controller.get_csrf_token()`) and `304d ago` (wall-clock relative text).

### Anti-Patterns to Avoid
- **An always-green capture test:** a test that runs the writer and then compares with the file it just wrote (the Phase 259 `RegenGuard` rationale).
- **Normalizing absolute timestamps in the catalog:** it would hide BOPS-03's "zone on the same line" change. Pin data (`inserted_at`, `last_active_at`) to constants instead; only the wall-clock-relative strings are normalized.
- **A catalog test that asserts equality with current sources** (red after Phase 261 by design).
- **Naming anything under `priv/templates/sigra.install/` with the substring `design`** (isolation test, D-04). [VERIFIED: test/sigra/install/design_gallery_isolation_test.exs:26-31]

## Per-Requirement Findings

### BGEN-01: parity of every copied asset

Measured this session (`cmp`/`diff`):

| Asset | template == golden | template == example | Note |
|---|---|---|---|
| `admin/sigra_admin.css` (41,394 B) | yes | yes | Existing test: DIST-05 `admin_test.exs:396-407` |
| `core/sigra_auth.css` (32,072 B) | yes | **no, example is 13,867 B, 903 diff lines** | No parity test exists |
| `admin/sigra-logo-primary.svg`, `-dark.svg` | yes | yes | No parity test |
| `passkeys/passkey_hooks.js` | n/a (golden tracks `lib`, `priv/repo/migrations`, `priv/static`, `config`, `test/support` only) | yes | No parity test |
| `admin/admin_hooks.js` | n/a | **no, 72 diff lines**: example is a documented superset (demo `code.vt-code--copy` chips and password fill) | `installer_drift_test.exs` guards this with regex marker pairs |
| `passkeys/passkey_browser.js` | n/a | **no, 156 diff lines**: template imports from `@simplewebauthn/browser`, example inlines its own base64url helpers | no byte test |

Example drift detail: the stale example `sigra_auth.css` defines 11 `sigra-auth*` classes and 24 `--sigra-auth-*` tokens; the template defines 66 classes and 35 tokens; nothing is in the example but not the template. Only `home.html.heex` links it. [VERIFIED: grep/comm this session; test/example/lib/example_web/controllers/page_html/home.html.heex:2]

**Recommendation:** one new fast ExUnit file (no Postgres, async) holding a declared table `{template, example | nil, golden | nil, relation}` with `relation in [:byte_identical, {:documented_divergence, reason}]`:
- byte-identical: `sigra_admin.css` (move DIST-05 into it or leave it), `sigra_auth.css` (red until refreshed; this is the intended first failing control), both logos, `passkey_hooks.js`;
- documented divergence: `admin_hooks.js`, `passkey_browser.js`, with the reason string and a shrink-only guard (for example: every non-comment template line still present in the example for `admin_hooks.js`, which already has marker tests).
- completeness: enumerate every `.css/.svg/.js` under `priv/templates/sigra.install/**` and fail on any file not in the table (the same "unknown type raises" pattern as `@unextracted_template_exts` in `CopyInventory`). [VERIFIED: test/support/brand/copy_inventory.ex:78-82]
- positive control: the comparison is a pure function (`parity(a, b)`), unit-tested with a planted one-byte difference that must report mismatch.
- template == golden for static assets is currently only proven by the slow golden test; the table adds a fast guard.

Refresh step: `cp priv/templates/sigra.install/core/sigra_auth.css test/example/priv/static/assets/sigra_auth.css`. The example pages that link it use almost none of its classes, so visual blast radius in the example is small, but confirm in CI (see PNG-neutrality pitfall).

### BGEN-02: determinism

- `mix sigra.fixture.rebless_golden --check` run this session under phx_new 1.8.8: `OK: fixture is up-to-date (check mode).`, 27.9 s wall, working tree unchanged. [VERIFIED: ran `source tmp/db.env; MIX_ENV=test mix sigra.fixture.rebless_golden --check`]
- Only nondeterminism source in the installer: `base_time = Keyword.get(opts, :base_time, DateTime.utc_now())` (runner.ex:54) feeding `Calendar.strftime("%Y%m%d%H%M%S")` (migration_timestamps.ex:50). Grep of `lib/sigra/install`, `lib/mix/tasks/sigra.install.ex`, `sigra.upgrade.ex` for `strong_rand_bytes|utc_now|system_time|:rand|shuffle|unique_integer|make_ref` finds only those; a grep of `priv/templates` for time/random inside `<%= %>` finds nothing. [VERIFIED: grep]
- The fixture normalizer already replaces migration filename timestamps with `TIMESTAMP` and the three phx.new salts (`signing_salt`, `secret_key_base`, `live_view: [signing_salt:]`) in `config/*.exs`. The salts come from `mix phx.new`, not the installer. [VERIFIED: install_fixture.ex normalize_content_for_golden]
- Existing `idempotency_test.exs` proves *same app, run twice* writes nothing new. It does not prove *two fresh installs are byte-identical*, which is what BGEN-02 states.

**Recommendation:** `double_install_test.exs` (`@moduletag :scaffold`, timeout like its siblings): two `InstallFixture.setup_tmp_app/0` runs, assert `normalize_tree` equal and `normalize_stdout` equal, plus a **raw** leg asserting the only differing paths are migration filenames and `config/*.exs` salt lines (this is the claim "nothing else varies"). Positive control: a pure `compare_trees/2` unit-tested with a planted one-byte change. Add the file to the `ci.install_golden` alias list, which is an explicit file list and runs the scaffold-tagged files (`test --exclude scaffold` skips them). [VERIFIED: mix.exs:149-157, 161-163] The CI `install_golden_contract` job also runs `rebless_golden --check` (ci.yml:559-566), gated to installer-path diffs on PRs and unconditional on non-PR events; the `mix ci` alias does **not** include `--check`, so a maintainer should run it explicitly in the verification step.

### BGEN-03: before catalog

**Scope reality check (verified):**
- Library admin LiveViews: `audit_index_live`, `audit_user_live`, `branding_live`, `index_live`, `organization_live`, `user_sessions_live`, `user_show_live`, `users_index_live` (8). Their `render/1` is a `~H` over `@detail`/`@admin_scope`/`@current_scope`, pure except `get_csrf_token()` and `relative_activity/1`. [VERIFIED: ls lib/sigra/admin/live; user_show_live.ex:41-340]
- `relative_activity/1`: `diff = DateTime.diff(DateTime.utc_now(), at, :second)` and outputs `"just now"`, `"#{div(diff, 60)}m ago"`, `"#{div(diff, 3600)}h ago"`, `"#{div(diff, 86_400)}d ago"`. [VERIFIED: lib/sigra/admin/components.ex:1206-1218]
- Seeded personas: `Example.Demo.Personas` (ten, `@demo.tasklane.test`; locked, unconfirmed, scheduled deletion, zero-state, org roles) and `Example.Demo.Seeds.run/0` runs inside the sandbox in `seeds_test.exs`. Seeds comment: "D-19 determinism: all values are static string literals — no randomness", `@seed_reference_ts` pins audit `occurred_at`, but user ids are database UUIDs and `inserted_at` is wall clock. [VERIFIED: personas.ex, seeds.ex:173, 829]
- Generated emails live in `priv/templates/sigra.install/core/emails.ex`: `confirmation_email/3`, `reset_password_email/2`, `magic_link_email/2`, `suspicious_login_email/2`, plus `api_token_created_email.ex` and the organization invitation email. [VERIFIED: grep]

**Finding: the example is not the generated lane.** `grep` for `sigra_auth_page|SigraAuthComponents|sigra-auth` in `test/example/lib` finds only `page_html/home.html.heex` and `demo/branding.ex`; the golden tree has `sigra_auth_components.ex`, the example has none. A tier-2 render of the example's login page is the Tasklane `vt-*` page, not what a host user of a generated host sees. Therefore:
- **Library lane (admin):** tier 1 (pure `render/1` with literal assigns, no DB, no browser) is the honest "before" for state coverage; tier 2 (ConnCase `get` through the example, full document incl. generated-shell mirror) adds layout composition. Both are fine; the example's admin shell is a hand mirror, so record it as such in the manifest.
- **Generated lane (auth screens, emails):** baseline = (1) golden tree (already committed, CI-enforced), (2) `generated.tsv` copy inventory (already committed), (3) rendered HTML captured from **one freshly generated host** at the pinned SHA. Recommended capture vehicle: a `--test catalog` target in `scripts/ci/admin-acceptance-smoke.sh` (it already scaffolds, boots, and `curl`s; it is a monolithic script, not sourceable functions) or a sibling script that duplicates its scaffold block. Anonymous pages (login, register, reset, magic link, confirm resend) by HTTP GET; emails by a one-off `mix run -e` in the host calling the generated builders. The coverage statement in the manifest must say which generated screens are baselined by markup only (golden tree) and which by rendered HTML, "because a clean inventory diff proves nothing about copy in a form that is not covered" (the Phase 259 TSV header convention). If the owner will not accept the cost, the fallback (G-B) is golden tree + inventory only for authenticated generated screens, stated openly.

**Normalizer (volatility list, all verified in repo precedent or this session):**
`<meta name="csrf-token" content>` and `_csrf_token` inputs; `id="phx-…"`; `data-phx-session`, `data-phx-static` (and `data-phx-main`/parent ids); `request_id` values; `?vsn=` query on assets; per-render ids like `mg-11-confirm-title-*`; user UUIDs (map to persona label after seeding); relative text matching `just now` / `\d+[mhd] ago`; echoed emails. Reuse the rule shape of `normalize_text/2` in `enumeration_parity_test.exs`:
```elixir
# Source: test/example/test/example_web/enumeration_parity_test.exs:1351-1375 (normalize_text/2, verbatim shape)
|> then(&Regex.replace(~r/(name="_?csrf[-_]token"[^>]*?(?:value|content)=")[^"]*"/, &1, "\\1{{CSRF}}\""))
|> then(&Regex.replace(~r/(\bid="phx-)[A-Za-z0-9_-]+"/, &1, "\\1{{REQUEST_ID}}\""))
|> then(&Regex.replace(~r/(data-phx-(?:session|static)=")[^"]*"/, &1, "\\1{{REQUEST_ID}}\""))
```
Add whitespace canonicalization (collapse runs, break between tags) so component reflow does not produce noisy diffs.

**Theme dimension (honest limit):** admin theme is client-side (`data-sg-admin-theme` set by an inline script from `localStorage`), so server-rendered admin HTML is identical across Light/Dark/System. Only generated auth pages take a server-side `data-theme`. State this in the manifest; dark-mode proof is the browser axe/contrast pass in Phase 261 (BTOK-03), not this text catalog. [VERIFIED: priv/templates/sigra.install/admin/components/admin_shell.ex:24-42]

**Manifest (`before/MANIFEST.json`):** pinned `origin/main` sha, `lib`/`priv` tree hashes, capture command, SHA-256 of `sigra_admin.css`, `sigra_auth.css` and the two logos at capture time, per-file sha256, coverage statement, provenance line "brand book v2.0 (2026-11-13)", persona list (`.test` only). Enforce by a root test that re-hashes the committed files (the `brand.sha256`/`source_pin_test.exs` pattern) and runs a privacy scan (no non-`.test` email, no home path, no `secret_key_base`, no real token). Add `test/fixtures/brand/before/** -text` to `.gitattributes` like `brand/** -text` so newlines never change bytes. [VERIFIED: .gitattributes `brand/** -text linguist-vendored`]

**Size:** estimate ~40-120 files, around 1 MB, comparable to the golden tree (84 files, 748 KB). [ASSUMED: estimate; measure after the first capture]

**Known pre-capture caveat:** the Phase 259 branch already changed example-host code relative to `main` (`confirmation_live.ex`, `reset_password_live.ex`, `router.ex` under `test/example/lib`, test-only support) [VERIFIED: `git diff --stat origin/main...HEAD -- test/example ':!test/example/test'`]. Define "byte-identical to main" as `lib/` and `priv/` only, and list those three example files in the manifest.

### BGEN-04: L1 repair (brand mark, explicit Light/Dark, version stamp)

**Verified state:**

| File | `sg-brand-mark` | `data-sg-admin-theme` | `data-theme` |
|---|---|---|---|
| template `sigra_admin.css` (1,484 lines) | 0 | 0 | 0 |
| example `assets/sigra_admin.css` | 0 | 0 | 0 |
| golden `tree/priv/static/assets/sigra_admin.css` | 0 | 0 | 0 |
| example `assets/css/app.css` (2,936 lines) | 15 | 14 | 30 |

The generated shell emits `sg-brand-mark`, `sg-brand-mark__image--light/--dark`, `sg-theme-switch`, `data-sg-admin-theme*`. [VERIFIED: admin_shell.ex:24-72, 77-114] In `app.css` the explicit blocks start at `.sg-admin-shell[data-theme="light"], html[data-sg-admin-theme="light"] .sg-admin-shell {` (line ~1570) and the dark twin (~1609); brand mark rules ~1807-1870; theme switch ~1952-2010.

**Scope is wider than the roadmap.** Classes used in `lib/sigra/admin/**` and `priv/templates/sigra.install/admin/**` markup: 157; missing from shipped CSS: 59; of those, **56 are defined only in the example `app.css`** (for example `sg-admin-main`, `sg-admin-sidebar`, `sg-page-header`, `sg-input`, `sg-field`, `sg-tabs`, `sg-breadcrumb`, `sg-toolbar`, `sg-scope-switch*`, `sg-select`, `sg-color-field*`, `sg-branding-*`, `sg-impersonation*`, `sg-bottom-nav*`) and 3 are defined nowhere (`sg-branding-editor`, `sg-cluster--2`, `sg-stack--4`). The shipped stylesheet's own header says generated screens carry Tailwind/DaisyUI utility classes "as a fallback for host apps that compile Tailwind", which is why generated-host smoke passes today; phx_new 1.8.8 hosts compile Tailwind, so most layout survives there. The brand mark and theme switch have no such fallback in the shell markup. [VERIFIED: grep/comm; sigra_admin.css:3-5] Effect on a generated host (both logos stacked; Light/Dark switch inert) is [ASSUMED: inferred, not yet looked at in a running generated host; the fresh-host run must confirm it before and after].

**Recommendation (decision needed, see Open Question 2):** repair the roadmap minimum (brand-mark rules, explicit Light/Dark token blocks, theme-switch rules, since the shell cannot work without them) and **turn the remaining 56-class gap into a measured, shrink-only baseline** (a test that computes "classes used by shell/lib markup but undefined in shipped CSS" and fails when the set grows) rather than silently moving 700+ lines. That keeps one reviewable golden rebless and records the debt honestly.

**Conformance conflict (verified by running the guard on the real rules):** copying the explicit blocks verbatim into a scratch file and running `admin-css-conformance.sh` gives `CHECK 2 ... FAIL: raw hex color outside :root found` on every `--sg-color-*: #...` line and on `background: #fdba74; color: #151515;` in the theme-switch active rule (CHECK 1 and CHECK 3 pass). The guard only treats a line matching `/:root[[:space:]]*\{/` as a token-definition scope (admin-css-conformance.sh:126 for CHECK 2, :207 for CHECK 3). [VERIFIED: scripts/ci/admin-css-conformance.sh:84-130; ran on an excerpt of app.css lines 1570-1648, 1807-1880, 1952-2010] Resolve before wiring BGEN-05: extend the guard (and its `.test.sh`, with a planted failing case) to accept explicit-theme token blocks (`html[data-sg-admin-theme=...]`, `.sg-admin-shell[data-theme=...]`) as scopes where only `--sg-*` declarations and `color-scheme` appear, and replace the hex in the theme-switch rule with tokens. The duplicate-values-in-two-places shape (media-query dark block plus explicit block) stays, guarded by the existing D-11 parity test pointed at the single shipped file.

**Tests/artifacts that must change together (all verified to exist):**
- `admin_test.exs:409-428` (D-11): read the explicit dark block from the shipped CSS instead of `app.css`; add the light twin. It pins `"--sg-color-brand-strong: #fdba74;"` (stays valid until Phase 261).
- `admin_test.exs:396-407` (DIST-05): byte parity template == example: re-sync the example copy after the template edit.
- Golden: `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`: **the phase's single rebless**, expected diff = additive rules + stamp comment only; review per directory; mechanical changes in a separate commit.
- `app.css`: delete the moved blocks only (the corruption guard `app-css-corruption-check.sh` scans `:root` blocks of `app.css` for orphaned value fragments, run it after the edit). Cascade caveat: `sigra_admin.css` declares `@layer sg-base, sg-components, sg-overrides;` while `app.css` rules are unlayered and therefore win; moving rules into the layered file changes precedence in the example. [VERIFIED: sigra_admin.css:15; layered file structure at lines 217, 230, 1431]
- Frozen-surface ratchet: new `sg-brand-mark*` classes are additions; "baseline SUBSET-OF current" passes without running the extend writer. [VERIFIED: test/sigra/brand/frozen_surface_test.exs:8-13]
- Generated-host proof: `admin-generated.spec.ts` has no brand-mark or Light/Dark assertions today (grep). Add Playwright behavior assertions (computed style, not PNG) run by `admin-acceptance-smoke.sh --test chrome`: in light the dark lockup is `display: none` and vice versa; setting `html[data-sg-admin-theme="dark"]` changes the resolved `--sg-color-panel`. Pattern: the file already reads `--sg-color-brand` via `getPropertyValue` (admin-generated.spec.ts:270).

**CSS version stamp:** none exists today (grep for `css-version|css_version|sigra-admin-css` finds nothing in `lib`, `priv`, `test/sigra`, `scripts`). Recommend a first-line comment `/* sigra-admin-css: N */` where N is an integer "CSS contract level" (not the package version, so it does not churn each release), no `<%` inside (the file is EEx-rendered). Test: stamp present and equal in template, example and golden. Phase 262 (BOPS-06) wires `mix sigra.doctor` against a library constant; Phase 260 ships only the stamp. [VERIFIED: grep this session; sigra.doctor.ex has no CSS check]

### BGEN-05: orphaned CSS guards (L2)

- Both scripts and both `.test.sh` twins pass today: `admin-css-conformance: PASS`, `admin-token-completeness: PASS — 100 tokens, :root == doc`, test twins 10/0 and 8/0. [VERIFIED: ran this session]
- No caller exists in `.github/`, `mix.exs` or `test/` (ARCHITECTURE L2; re-confirmed by the alias read).
- `mix ci` today: `"format --check-formatted", "deps.get --check-locked", "deps.unlock --check-unused", "compile --warnings-as-errors", "test --exclude scaffold", "ci.install_golden", "sigra.dep_off"`. [VERIFIED: mix.exs:149-157]
- `library_tests_shard` runs `MIX_ENV=test mix ci` (ci.yml:620), and `library_tests` is a ruleset-required name. [VERIFIED: ci.yml:615-633; live ruleset]

**Recommendation: wire, via the alias.** Add `"cmd bash scripts/ci/admin-css-conformance.sh"` and `"cmd bash scripts/ci/admin-token-completeness.sh"` (and optionally the two `.test.sh`) to `ci` using the same `cmd bash` shape as `sigra.dep_off`. Zero `.github` diff, runs on every PR, fits ADR 004 ("single owner mix ci"). Retiring is a worse trade: the token-completeness check has a partial ExUnit twin (`admin_test.exs:473`, one direction only) but nothing else covers raw hex, raw px or `transition: all` in shipped CSS, and Phase 261's token flip needs exactly those guards. Order: extend the conformance guard for the explicit-theme shape in the same plan as L1, then wire.

### BGEN-06: park PR

**Live `ci.yml` facts (read this session):**

| Lane | Trigger today | Where PNG compare happens |
|---|---|---|
| `admin_checkpoints` seam (matrix leg of `example_playwright_shard`) | every event incl. `pull_request` (`Run admin checkpoints`, ci.yml:1330-1342, no event predicate) | `toHaveScreenshot` in `assertCheckpointScreenshot` (admin-checkpoints.spec.ts:158-161), preceded by an axe scan with `.disableRules(['target-size'])` (lines 120-141); one test, three projects (chromium, mobile, dark) |
| `demo_showcase` seam | every event (ci.yml:1406-1416) | `assertDemoScreenshot` (demo-showcase.spec.ts:149) called 5 times inside **one** of four tests; the other three are real-login and evaluator behavior tests |
| `design_gallery` seam | PR runs `--grep-invert '@snapshot'`; push/schedule/dispatch run `@snapshot` then the invert half | step `design_gallery_snapshots`, 28 `@snapshot` tests x 3 projects |

Verbatim gates: `if: ${{ !cancelled() && needs.changes.outputs.docs_only != 'true' && matrix.seam == 'design_gallery' && github.event_name == 'pull_request' }}` (ci.yml:1353) and `... && github.event_name != 'pull_request' }}` (ci.yml:1369). [VERIFIED: ci.yml]

**Required-check mapping:** live ruleset 14941512 requires exactly `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)` [VERIFIED: `gh api repos/szTheory/sigra/rulesets/14941512` this session]. `example_playwright_smoke` has `needs: [release_ref_guard, changes, example_playwright_shard]`, `if: always()` and fails when `[ "$SHARDS" != "success" ]` (ci.yml:1442-1459), so any red PNG compare in any matrix leg reds the required check. `ci-gate` needs: `changes, install_golden_contract, library_tests, library_tests_dep_off, install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke, generated_admin_playwright_smoke, fast_checks` (ci.yml:1618-1628). The matrix job names `Example Playwright shard (…)` are not ruleset contexts, so changing what runs inside a leg cannot strand a required context; **never rename** the five job names.

**Constraint on mechanism (cited):** the `matrix` context is not available at `jobs.<job_id>.if` (only `github, needs, vars, inputs`); a leg can only be skipped at step level. [CITED: docs.github.com/en/actions/reference/workflows-and-actions/contexts]

**Dispatch reality:** `release_ref_guard` allows a manual `workflow_dispatch` only from `refs/tags/v*`, with `recapture_branch` set, or the phase-244/246 special cases (ci.yml:124-135). So "dispatch" compare = release-tag evidence runs and recapture dispatches. Also `playwright-github-pages.yml` runs `admin-checkpoints.spec.ts` in compare mode on push to `main` (when `test/example/priv/playwright/**` changes), nightly and dispatch; it is not required and not in `ci-gate`, but will go red after Phase 261 unless it is also handled. [VERIFIED: playwright-github-pages.yml:16-30, 142-148]

**Option A (recommended): park the comparison, keep the lanes.** A shared flag `SIGRA_PNG_COMPARE` (set to `'1'` only on `workflow_dispatch` and in the two recapture jobs; unset elsewhere). In `assertCheckpointScreenshot` and `assertDemoScreenshot`, gate only the `toHaveScreenshot` call (axe, page walks and the three demo behavior tests keep running on PR); in the 28 `@snapshot` tests, `test.skip(!compare, reason)` so Playwright reports them skipped instead of silently green. Effects: no `if:` predicate changes, so `ci-skip-manifest.tsv`, `p10`, the observer's `assert >= 2` floor, `p13`, `phase_234` inventory events and MAINTAINING Tier-B rows stay untouched; ADR 005's "axe and behavior specs stay on the PR path" is preserved including the per-checkpoint dark axe. Cost: three spec edits plus `env:` lines in the Playwright steps/jobs, a short MAINTAINING paragraph, and a small contract test that pins the env default off on PR/push and on in dispatch/recapture. Risk: a skipped compare is not visible to the honest-skip manifest, so document it in `ci.yml`, MAINTAINING and the test.

**Option B (ADR-literal): demote whole steps** with `github.event_name == 'workflow_dispatch'` predicates. Ripple, all verified to exist: give the steps `id:`s; add `.github/ci-skip-manifest.tsv` rows (the existing `design_gallery_snapshots` row is tier B `assert`, and the observer fails if the assert set drops below two: `if [[ "$ASSERT_COUNT" -lt 2 ]]` at ci-demotion-observer.sh:87 and its `.test.sh` Test D, `p13` floor `asserted.length >= 2`); `p10` row-vs-`if:` string equality; `test/example/priv/playwright/spec-ownership.json` events (`["pull_request","push"]` for `admin-checkpoints` and `demo-showcase`, validated by `phase_234_playwright_inventory_contract_test.exs`); `phase_230_design_gallery_split_test.exs` (pins the `design_gallery_snapshots` `if:` shape); `MAINTAINING.md` Tier-B prose (already stale: it still places `design_gallery_snapshots` inside `example_playwright_smoke`). Loses the checkpoint axe gate and three demo behavior tests on PR. `--grep-invert` is not usable for `admin_checkpoints` because its single test cannot be split: a run that matches zero tests fails by default (`--pass-with-no-tests` exists to override; [CITED: playwright.dev/docs/test-cli, behavior implied by the flag description]).

**Both options must also:** set `SIGRA_PNG_COMPARE=1` (or equivalent) in `admin_design_recapture` and `admin_checkpoint_recapture` (they run `--update-snapshots`, which writes nothing if the compare call never executes: a silent false negative, same family as the memory note "negative results need positive controls"); decide `playwright-github-pages.yml` (recommend: leave compare off there, one `env:` line); leave `snapshot-canary-guard.sh` in `fast_checks` untouched (canary never allowlisted); recapture jobs only open PRs on `workflow_dispatch` (ci.yml:1821).

**Minimal diff budget (proposal for the plan's stated budget):** `.github/workflows/ci.yml` (≈6-10 lines of `env:`), optionally `playwright-github-pages.yml` (1 line), three spec files, one contract test, one `MAINTAINING.md` paragraph. No new workflow.

**Ordering/risk:** author this PR **first**. Phase 260's own CSS work (BGEN-01 refresh, BGEN-04 deletions from unlayered `app.css`) can change rendered pixels in the example, and any such drift reds the required `Example Playwright smoke` check on its PR while darwin recapture is forbidden. The park PR changes no shipped byte and is independent of the milestone branch (which is 132 commits ahead of `main`), so it can merge ahead. ADR 005 says "at the end of Phase 260"; ROADMAP SC-4 only requires "merged ... before Phase 261 starts". Moving the authoring earlier satisfies both; record a dated ADR note if the owner agrees. [ASSUMED: owner acceptance of the earlier order]

### BGEN-07: before/after diff report

`scripts/brand/` already holds `axe-brandbook.mjs`, `critique-render.mjs`, `outline-wordmark.mjs`. Add `scripts/brand/catalog-diff.sh <before_dir> <after_dir>`: `diff -ru` per file plus a summary (changed/added/removed counts). Exercise it from an ExUnit test with planted before/after temp dirs (identical dirs exit 0 with "no differences"; one changed line is reported; a removed file is reported) so it runs under `mix ci` with no `ci.yml` edit. Shell rules (project lessons): no `wc -l | grep -qx "0"` (BSD `wc` pads with spaces; use `test -z "$(…)"` or `[ "$n" -eq 0 ]`), no GNU-only `diff --strip-trailing-cr`, quote globs (zsh), no `sed -i` without a suffix argument, use `shasum -a 256`.

### BGEN-08: `DesignGalleryLive` extension (dev-only)

- File: `test/example/lib/example_web/live/admin/design_gallery_live.ex` (1,474 lines of static literal assigns, route gated by `Application.compile_env(:example, :dev_routes)` at router.ex:187-209). [VERIFIED]
- `admin-design.spec.ts` asserts `COMPONENT_BOARDS` has length 13 and loops `[...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]` for `@snapshot` PNG tests (admin-design.spec.ts:~250-275), and `phase_230_design_gallery_split_test.exs:56` pins the loop's source shape. Put new states in a separate section with ids that are **not** in those arrays (for example `catalog-*`) so no baseline or registry changes; the page-wide axe test (untagged, on PR) then covers them for free.
- Honest scope: `status_mark` does not exist until BOPS-02 (Phase 262), and "Components markup" must not change here. Draw status states with the existing `sg-status-pill` and the five product words (Active, Unconfirmed, Locked, "Deletion scheduled"; Suspended drawn in the catalog only per ADR decision 6); auth-page and email states render the host-owned neutral defaults. [VERIFIED: ADR 005:128]
- Test: an example `LiveViewTest` that mounts `/admin/_design` (dev route, so compile-env gated) and asserts the new section ids and the Suspended word appear; keep `design_gallery_isolation_test.exs` green.

## Wave Ordering (the flagged constraint)

| Wave | Content | Why here |
|---|---|---|
| 0 | New guard tests written first: asset-parity table (red on `sigra_auth.css` by design), double-install test, catalog harness + normalizer + determinism/privacy/manifest tests, then **capture the before catalog** (tier 0/1/2, generated-lane per the chosen vehicle) | Shipped `lib/`+`priv/` still equal `main` here (verified). Anything that changes shipped CSS must come after capture so the manifest's CSS hashes are the true "before". Note: text snapshots exclude CSS, so L1 would not change the HTML snapshots; the ordering still matters for the recorded hashes and for the generated-lane golden baseline. |
| 1 | BGEN-01 example `sigra_auth.css` refresh; BGEN-02 determinism proof | Example-only/test-only; changes no shipped byte |
| 2 | BGEN-04 L1 + BGEN-05 guard extension and wiring, designed together; golden rebless **once** (additive diff, separate mechanical commit); stamp; generated-host Playwright assertions | The only wave that changes shipped bytes |
| 3 | BGEN-07 report script; BGEN-08 gallery | Consume the catalog; small |
| Park PR | Independent branch off `main`; start immediately, merge on owner approval, gate for Phase 261 | See BGEN-06 ordering |
| Close | `scripts/ci/admin-acceptance-smoke.sh --test all` plus looking at the admin in Light/Dark/System; `MIX_ENV=test mix ci`; `rebless_golden --check`; privacy grep with planted-failure control; `git diff --stat -- lib priv` shows only the L1 CSS template change | Fresh-host proof gate |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Golden writing/diffing | A second fixture writer | `mix sigra.fixture.rebless_golden [--check]` | Single writer with a delta report grouped by directory |
| Opt-in fixture writers | Raw `System.get_env` in tests | `Sigra.Test.Brand.RegenGuard.requested?/3` | `RegenGuardTest` fails on direct reads |
| Copy/class inventory | A new scanner | `Sigra.Test.Brand.CopyInventory` + committed TSVs | Already per-lane, sorted, line-number free |
| Fresh generated host | A new scaffolder | `Sigra.Test.InstallFixture`, `admin-acceptance-smoke.sh` | Pinned to phx_new 1.8.8, already normalizes |
| HTML volatility rules | New regexes from scratch | The `normalize_text/2` rule shape in `enumeration_parity_test.exs`; the volatile attr list in `canonicalize.ts` (reference only) | Already reviewed and tested in Phase 259 |
| Text diff | A custom differ | `diff -ru` | Portable, reviewable |
| Hash manifests | A new format | `shasum -a 256 -c` style like `brand.sha256` | Same pattern as Phase 259 |
| Pixel compare for the catalog | A new compare/allowlist/canary | Nothing: text only | Milestone rule: no new PNG baselines or ledgers |
| CSS guards | A second checker | Extend `admin-css-conformance.sh` | Existing guard plus `.test.sh` twin |

**Key insight:** every guard here already exists in some form; the risk in this phase is adding a *second* mechanism that disagrees with the first (a second skip enumeration, a second normalizer, a second fixture writer).

## Common Pitfalls

### Pitfall 1: Park edits that the demotion guards reject
**What goes wrong:** adding `github.event_name == 'workflow_dispatch'` predicates turns `p10`, the observer floor, `p13`, the inventory contract and `phase_230_design_gallery_split_test` red in unrelated-looking places. **Why:** they enforce that every demotion is enumerated and that `design_gallery_snapshots` stays a tier-B `assert` row. **Avoid:** choose Option A, or budget the full ripple list under Option B. **Detect:** `node --test scripts/ci/prohibitions/*.test.mjs`, `bash scripts/ci/ci-demotion-observer.test.sh`, `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs`.

### Pitfall 2: Recapture jobs silently stop recapturing
**What goes wrong:** with the compare call gated, `--update-snapshots` runs write nothing and the job is green. **Avoid:** set the flag in both recapture jobs and prove with a positive control (a dispatch run, or a local run that deliberately flips the flag and shows the compare executes).

### Pitfall 3: L1 verbatim move fails the guard you are about to wire
Already reproduced (see BGEN-04). Do the guard extension and L1 in one plan; plant a failing hex in the guard's `.test.sh`.

### Pitfall 4: Treating the example as the generated lane
**What goes wrong:** a catalog of the example's login page is a catalog of Tasklane, not of what hosts get. **Avoid:** label every catalog file with its lane in the manifest; baseline generated screens from a generated host or the golden tree.

### Pitfall 5: Hiding BOPS-03 by over-normalizing
Normalizing all timestamps would make the Phase 262 time-zone change invisible. Pin data to constants; normalize only `just now|\d+[mhd] ago`.

### Pitfall 6: A "before" test that cannot fail or cannot stay green
Equality-with-sources goes red in Phase 261; a writer-then-compare test can never fail. Protect "before" by manifest hash and refuse-to-overwrite.

### Pitfall 7: Cascade-layer precedence on the move
Unlayered `app.css` beats layered `sigra_admin.css`; moving rules can change which declaration wins in the example, shifting pixels and any PNG still compared. Another reason to park first.

### Pitfall 8: Explicit file lists in the `ci` alias
`ci.install_golden` is an explicit list; a new scaffold-tagged test is skipped by `test --exclude scaffold` and never runs unless listed. Verify with a deliberately failing assertion once (positive control), not by absence of failure.

### Pitfall 9: `mix ci` is not the whole gate
`mix ci` does not run `test/example` (CI runs `mix test --include example_app` in `example_unit_smoke`), nor `rebless_golden --check`. Run both explicitly before pushing. Memory note: root `mix test` also misses formatting; `.formatter.exs` covers `test/{sigra,support,mix}` and `test/example/{lib,config,test,priv}` so new test and support files must be formatted.

### Pitfall 10: Local environment drift
Local Node is v26.10.0 vs CI node 20; local Postgres is the Dockerized one on a dynamic port (`source tmp/db.env`, `SIGRA_TEST_PG_*` and `PG*`). Playwright baselines are ubuntu-native: running with compare on, locally on darwin, will fail by design; never `--update-snapshots` locally.

### Pitfall 11: Boundaries of "byte-identical to main"
Phase 259 changed three example-host files and test code vs `main`; the owed pre-262 generated-host fixes (registration/passkey oracles, confirm/reset) will change generated output after capture and will pollute the Phase 262 before/after diff unless re-baselined. Record this in the manifest and Open Question 5.

## Code Examples

### CSS guard acceptance (what to extend)
```bash
# Source: scripts/ci/admin-css-conformance.sh:126-128 (current scope rule, verbatim)
if (line ~ /:root[[:space:]]*\{/) {
  in_root = 1
  root_entry_depth = brace_depth + 1
```
Extend so a rule block whose selector matches `html[data-sg-admin-theme="..."]` or `.sg-admin-shell[data-theme="..."]` and whose body is only `--sg-*` declarations plus `color-scheme` is also a protected scope; add a planted raw-hex-in-a-normal-rule case to `admin-css-conformance.test.sh` so the guard is proven red once.

### `mix ci` alias wiring
```elixir
# Source: mix.exs:149-157 (current), extend with the existing cmd-bash idiom (mix.exs:168)
ci: [
  "format --check-formatted", "deps.get --check-locked", "deps.unlock --check-unused",
  "compile --warnings-as-errors", "test --exclude scaffold", "ci.install_golden",
  "sigra.dep_off"
  # + "cmd bash scripts/ci/admin-css-conformance.sh", "cmd bash scripts/ci/admin-token-completeness.sh"
]
```

### Compare flag (Option A shape)
```ts
// Source: pattern; sites are assertCheckpointScreenshot (admin-checkpoints.spec.ts:158) and
// assertDemoScreenshot (demo-showcase.spec.ts:149)
const pngCompare = process.env.SIGRA_PNG_COMPARE === '1';
await assertNoAxeViolations(page, `axe:${slug}`);           // always runs
if (pngCompare) await expect(page).toHaveScreenshot(`${slug}.png`, { /* unchanged tolerances */ });
```
```yaml
# ci.yml step env, dispatch only (expression stays out of run: bodies, per the house ASVS V5 rule)
env:
  SIGRA_PNG_COMPARE: ${{ github.event_name == 'workflow_dispatch' && '1' || '0' }}
```

## State of the Art

| Old approach | Current approach | Impact |
|--------------|------------------|--------|
| Four hand-synced brand-value copies (template, example, example `app.css`, golden) | Byte-parity tests plus one shipped owner for L1 rules (verify, not generate) | Removes the lockstep failure mode without a builder |
| PNG baselines gating every PR | Text catalog now; PNG compare parked to dispatch | Visual changes can merge; review artifact is a text diff |
| Prose-only demotion list | `ci-skip-manifest.tsv` enumerated and parity-guarded | A new demotion must be enumerated (Option B) or avoided (Option A) |

**Deprecated/outdated:** `MAINTAINING.md` Tier-B prose still describes `design_gallery_snapshots` as inside `example_playwright_smoke` and an "Aggregate Playwright step outcomes" loop; the live aggregator is the shard matrix. [VERIFIED: MAINTAINING.md:263-272 vs ci.yml:1438-1464]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | In a generated host both logos stack and the theme switch is inert (inferred from absent CSS rules; Tailwind fallback covers layout but not these) | BGEN-04 | L1 severity/behavior-fix changelog wording; resolve with a before/after look in a real generated host |
| A2 | The example `sigra_auth.css` refresh and L1 deletions are or are not PNG-neutral in CI | Wave Ordering, park | If drift, the required `Example Playwright smoke` check reds on those PRs; mitigated by authoring the park PR first |
| A3 | Owner accepts authoring/merging the park PR before the rest of Phase 260 (ADR says "at the end") | BGEN-06 | Needs an owner yes and a dated ADR note, otherwise Phase 260 PRs may hit the PNG lanes |
| A4 | Owner prefers comparison-level parking (Option A) over lane-level (Option B) | BGEN-06 | Option B ripple list applies if not |
| A5 | Catalog size about 1 MB | BGEN-03 | Commit-vs-artifact decision changes if much larger |
| A6 | `playwright test` with zero matched tests exits non-zero by default (implied by `--pass-with-no-tests` description) | BGEN-06 | Only affects Option B variants using `--grep-invert` |
| A7 | Generated-lane page capture via a `--test catalog` target (or sibling script) is acceptable cost | BGEN-03 | If rejected, fall back to golden tree + inventory for authenticated generated screens and say so in the manifest |
| A8 | Decision #13 (wire the CSS guards) is the owner's choice at execution | BGEN-05 | If "retire", raw hex/px/`transition: all` go unguarded for Phase 261 |

## Open Questions

1. **How is the generated-lane "before" rendered?** What we know: the example is not a render of generated screens; a generated host can be scaffolded and booted by existing scripts. Unclear: owner appetite for a capture target in the required-lane smoke script vs a sibling script. Recommendation: `--test catalog` in `admin-acceptance-smoke.sh` for anonymous auth pages and emails; golden tree + inventory for the rest; state coverage in the manifest.
2. **L1 scope:** roadmap minimum plus a measured shrink-only baseline for the 56-class gap (recommended), or move the whole gap (about 700+ lines, bigger golden diff)? Needs an owner call because it changes what generated hosts receive.
3. **Park mechanism and timing:** Option A (compare-level, keeps axe and behavior) vs Option B (lane-level, ADR-literal); author first or last. Needs the owner's explicit approval for the PR merge regardless.
4. **`playwright-github-pages.yml` compare:** leave compare on (red nightly after 261) or add the flag (recommended).
5. **Pre-262 shipped-byte fixes (oracles, confirm/reset):** if they land after the "before" capture, re-capture the generated-lane "before" first or accept their diff as known noise in Phase 262. Unscheduled per 259-VERIFICATION.md:302.
6. **Process budget numbers:** the plan must state a `git diff --stat .github scripts` budget; proposal: park PR touches `ci.yml` (+ at most one other workflow line), BGEN-05 touches one script plus its test, BGEN-07 adds one script, no new workflow.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / OTP | everything | yes | 1.19.5 / OTP 28.5 (`.tool-versions`) | none needed |
| `phx_new` archive | golden, double-install, smoke | yes | 1.8.8 | `mix archive.install --force hex phx_new 1.8.8` |
| Postgres (Docker, dynamic port) | `mix test`, example tests | yes | container up; `tmp/db.env` present | `scripts/db/up.sh` |
| Docker | test PG | yes | 29.5.2 | none |
| Node / npm | Playwright, `.mjs` scripts | yes (v26.10.0 local; CI uses 20) | 26.10.0 / 11.19.1 | keep scripts portable |
| Playwright deps and browsers | generated-host smoke, spec edits | present locally (browsers cached) | 1.59.1 pinned in CI | `npm ci` in `test/example/priv/playwright`, `npx playwright install chromium webkit` |
| `gh` (authenticated) | ruleset/run reads, park PR | yes | 2.101.0 | none |
| `direnv` | auto-load `tmp/db.env` | yes | 2.36.0 | `source tmp/db.env` |
| Network (hex.pm) | `deps.get` in scaffolds | yes (rebless ran) | n/a | none |

**Missing dependencies with no fallback:** none. **Missing with fallback:** none.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5); `node --test` for prohibitions; Bash `.test.sh` twins; Playwright for browser behavior |
| Config file | `mix.exs` (`aliases`, `test_load_filters`), `test/test_helper.exs`, `test/example/test/test_helper.exs` (`exclude: [:example_app]`), `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `source tmp/db.env && mix test test/sigra/brand test/sigra/install/asset_parity_test.exs test/sigra/install/features/admin_test.exs` |
| Full suite command | `source tmp/db.env && MIX_ENV=test mix ci` then `cd test/example && MIX_ENV=test mix test --include example_app` then `MIX_ENV=test mix sigra.fixture.rebless_golden --check` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BGEN-01 | Every copied asset byte-identical or documented divergence; no unclassified asset; planted mismatch is reported | unit | `mix test test/sigra/install/asset_parity_test.exs` | no, Wave 0 |
| BGEN-01 | Example `sigra_auth.css` == template (red before refresh) | unit | same file | no, Wave 0 |
| BGEN-02 | Two fresh installs equal after normalization; raw differences confined to timestamps/salts | integration (:scaffold) | `mix test test/sigra/install/double_install_test.exs` | no, Wave 0 (add to `ci.install_golden`) |
| BGEN-02 | Golden fixture matches installer under pinned phx_new | integration | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | yes (clean, 27.9 s) |
| BGEN-03 | Normalizer strips csrf/phx ids/uuids/relative time; two renders equal; manifest hashes match committed files; privacy scan clean; planted leak fails once | unit | `mix test test/sigra/brand/catalog_test.exs` | no, Wave 0 |
| BGEN-03 | Tier-2 pages render for seeded personas deterministically | integration (:example_app) | `cd test/example && mix test --include example_app test/example_web/catalog_test.exs` | no, Wave 0 |
| BGEN-04 | Brand-mark + explicit theme rules + stamp present in template/example/golden; D-11 parity reads shipped file | unit | `mix test test/sigra/install/features/admin_test.exs` | yes (edit) |
| BGEN-04 | In a real generated host lockup swaps and explicit theme applies | browser behavior | `GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test chrome` | assertions to add to `admin-generated.spec.ts` |
| BGEN-04 | Golden additive diff only | integration | `mix test test/sigra/install/golden_diff_test.exs` + `--check` | yes |
| BGEN-05 | Conformance passes on the real file and fails on a planted hex in a normal rule and on an unmatched explicit block | script self-test | `bash scripts/ci/admin-css-conformance.test.sh && bash scripts/ci/admin-css-conformance.sh && bash scripts/ci/admin-token-completeness.sh` | yes (extend) |
| BGEN-05 | Wired into the gate | contract | `mix ci` shows both guards; grep of `mix.exs` alias in a tiny ExUnit contract | no, Wave 0 |
| BGEN-06 | PR/push path does not compare PNGs; dispatch and both recapture jobs do; canary unallowlisted | contract (reads `ci.yml`/specs) | `mix test test/sigra/planning/phase_260_png_park_contract_test.exs` | no, Wave 0 |
| BGEN-06 | Enumeration guards still green | script/contract | `node --test scripts/ci/prohibitions/*.test.mjs`; `bash scripts/ci/ci-demotion-observer.test.sh`; `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | yes |
| BGEN-07 | Identical dirs report none; planted change/removal reported | script via ExUnit | `mix test test/sigra/brand/catalog_diff_test.exs` | no, Wave 0 |
| BGEN-08 | New gallery sections render, include the Suspended word, stay out of board registries; isolation test green | integration | `cd test/example && mix test --include example_app` + `mix test test/sigra/install/design_gallery_isolation_test.exs` | no, Wave 0 |

Positive controls required (the repo's own lesson): the parity table (planted byte), the conformance guard (planted hex), the compare flag (a run where the flag is on and a perturbed expectation fails), the privacy scan (planted home path), `ci.install_golden` listing (a deliberately failing assertion once), the catalog normalizer (planted csrf/uuid/relative time). Do not trust "no output"; confirm each guard fires once.

### Sampling Rate
- **Per task commit:** the quick run command (under 30 s without scaffolds).
- **Per wave merge:** `MIX_ENV=test mix ci` plus the example suite plus `rebless_golden --check`.
- **Phase gate:** all of the above green, `scripts/ci/admin-acceptance-smoke.sh --test all` green and the admin looked at in Light/Dark/System, privacy grep (with planted control), `git diff --stat -- lib priv` equals only the intended L1 CSS template change, `git diff --stat .github scripts` within the stated budget.

### Wave 0 Gaps
- [ ] `test/sigra/install/asset_parity_test.exs`
- [ ] `test/sigra/install/double_install_test.exs` (+ alias entry)
- [ ] `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`, `test/example/test/example_web/catalog_test.exs`
- [ ] `test/fixtures/brand/before/` + `MANIFEST.json` + `.gitattributes -text` line
- [ ] `test/sigra/planning/phase_260_png_park_contract_test.exs`
- [ ] `scripts/brand/catalog-diff.sh` + `test/sigra/brand/catalog_diff_test.exs`
- [ ] Playwright assertions in `admin-generated.spec.ts` (generated-host L1 proof)
- Framework install: none.

## Security Domain

`security_enforcement` is not set to false in `.planning/config.json`; included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2/V3 Authentication, Session | no (no auth logic changes) | n/a; enumeration parity suite from Phase 259 stays green and is not touched |
| V4 Access Control | no | n/a |
| V5 Input Validation | yes (CI) | GitHub context values reach shell only through `env:` maps, never inlined in `run:` (house rule, ci.yml `changes` job comment); keep the same for any new `env:` line |
| V6 Cryptography | no | none added; secrets in catalog must be stripped |
| V10 Malicious Code / V14 Config | yes | no new dependency; pinned action SHAs unchanged; no new `permissions:` (workflow default `contents: read`); recapture jobs keep their job-level `contents: write` untouched |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Signed LiveView/CSRF tokens committed in catalog HTML | Information disclosure | Normalize `data-phx-session|static`, `csrf-token`, `_csrf_token`; privacy scan test over `before/**` |
| Personal data in a public repo (names, emails, home paths, authoring origin) | Information disclosure | Seeded `@demo.tasklane.test` only; pushed-diff grep with a planted-failure control; provenance "brand book v2.0 (2026-11-13)" |
| Workflow expression injection via a new `env:`/`if:` | Tampering | Only `github.event_name` (a fixed enum) is used; pass via `env:`; never interpolate branch names |
| Fixture writer turns a failing contract green | Tampering | `RegenGuard` refuses writers under `CI=true` |
| Park PR hides a real regression (compare off on PR) | Repudiation | Keep axe/behavior on PR (Option A), loud log line, dispatch/recapture compare, MAINTAINING documentation, contract test |

## Sources

### Primary (HIGH confidence): read or executed this session
- `.github/workflows/ci.yml` (read: triggers/concurrency, `release_ref_guard`, `changes`, `fast_checks`, `install_golden_contract`, `library_tests_shard`/`library_tests`, `example_unit_smoke`, `example_playwright_shard`/`_smoke`, `generated_admin_playwright_smoke`, `ci-gate`, both recapture jobs; the install_smoke/upgrade/matrix/http-smoke jobs were not read), `.github/ci-skip-manifest.tsv`, `.github/rulesets/tag-namespace.json`, live ruleset via `gh api` (required checks), `.github/workflows/playwright-github-pages.yml`
- `scripts/ci/ci-demotion-observer.sh`, `scripts/ci/prohibitions/p10|p13|p16|p06`, `scripts/ci/admin-css-conformance.sh`, `admin-token-completeness.sh`, `app-css-corruption-check.sh`, `admin-acceptance-smoke.sh`
- `mix.exs`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `test/support/install_fixture.ex`, `lib/sigra/install/runner.ex`, `migration_timestamps.ex`
- `test/sigra/install/golden_diff_test.exs`, `idempotency_test.exs`, `features/admin_test.exs`, `templates/installer_drift_test.exs`, `brand/*`, `test/support/brand/*`
- `priv/templates/sigra.install/admin/**`, `core/**`, `test/example/priv/static/assets/css/app.css`, `sigra_admin.css`, `sigra_auth.css`, `design_gallery_live.ex`, `personas.ex`, `seeds.ex`, Playwright config/specs/`spec-ownership.json`
- `.planning/decisions/005-*.md`, ROADMAP, REQUIREMENTS, research/v1.51-brand/{SUMMARY,ARCHITECTURE,PITFALLS}.md, 259 deferred-items and VERIFICATION
- Executed: `rebless_golden --check` (clean), both CSS guards and their `.test.sh` twins (pass), conformance guard on an L1 excerpt (fails CHECK 2), a tier-1 LiveView render spike, asset `cmp`/`diff`/class `comm` measurements, `gh api` ruleset query

### Secondary (MEDIUM confidence)
- docs.github.com contexts reference: `jobs.<job_id>.if` offers `github, needs, vars, inputs`; `matrix` only at step level [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts]
- playwright.dev test-cli: `--pass-with-no-tests`, `--grep-invert`, `--update-snapshots` semantics [CITED: https://playwright.dev/docs/test-cli]

### Tertiary (LOW confidence)
- Catalog size and PNG-neutrality estimates (A2, A5): not measured.

## Project Constraints (from CLAUDE.md)

- `mix test` needs a live Postgres (`postgres`/`postgres`, `sigra_test`); load `source tmp/db.env`; no `:postgres` exclusion; CI and plain 5432 fall back automatically.
- `MIX_ENV=test mix ci` is the local gate; install golden tests need the pinned `phx_new 1.8.8` archive (a different local version produces spurious golden diffs).
- Admin UI work follows `guides/reference/admin-ui-principles.md` and `admin-design-contract.md`; preserve the `sg-*` cascade-layer/BEM system, use the `brand/` book, support Light/Dark/System, keep browser tests deterministic; `--sg-*` token names stay, values move in Phase 261.
- Hybrid architecture: security-critical code in the library, customizable code generated; minimal transitive deps; copy-paste over deps when small.
- Testing: comprehensive coverage, AAA style, flat, self-contained.
- GSD workflow enforcement: file changes go through a GSD command; no direct repo edits outside a workflow without the owner's explicit bypass.
- Project memory rules that bind this phase: the repo is public (no personal names, emails, home paths or authoring origin in any committed file, memory or PR text); squash merges; nothing pushed/merged/released/tagged without explicit owner approval; negative results need positive controls; BSD `wc`/`grep -qx` and zsh glob pitfalls on darwin; never recapture PNG baselines on darwin; run scripts yourself and take approvals as plain chat replies; zero-human UAT where defensible (the single human gate in this milestone is Phase 261's logo/favicon sign-off, not here).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, nothing new; all tools exist and were exercised.
- Architecture / catalog design: MEDIUM-HIGH: tier 1 purity spiked and verified; tier 2 and generated-lane capture designed from verified precedents, not prototyped.
- Park PR: MEDIUM: workflow read in full, guard ripple traced by reading, not by editing and running; CI behavior on a real PR not observed.
- Pitfalls: HIGH for the ones reproduced (conformance conflict, class gap, example-vs-generated), MEDIUM for PNG neutrality.

**Research date:** 2026-11-15
**Valid until:** 2026-12-15 for repo facts (the workflow and guards change often: re-read `ci.yml` and `.github/ci-skip-manifest.tsv` immediately before writing the park PR); 7 days for anything that depends on `origin/main` moving (pinned sha 4cf5829ea).
