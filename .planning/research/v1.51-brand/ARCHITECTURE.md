# Architecture Research: v1.51 BRAND-IDENTITY-ADOPTION

**Domain:** Brand adoption inside a hybrid library + generator (Elixir/Phoenix auth, public SemVer API on Hex)
**Researched:** 2026-11-13
**Confidence:** HIGH on the blast radius (read from the repo and run where cheap); MEDIUM on runtime consequences marked [inferred]; MEDIUM on the catalog tooling (design is sound, not prototyped)

Scope: how brand book v2.0 ("Kiln", accent kept at `#C2410C`; `--sg-*` and `--sigra-auth-*` keep their names) integrates with the existing architecture. Paths are repo-relative. The brand book is referred to only as "the brand book". Its read-only reference copy is not yet in this worktree (`brand/` is untracked in the main checkout), so vendoring it is the first deliverable.

---

## 0. Bottom line (read this first)

1. **The accent does not move, so almost nothing breaks on the accent.** Every `#c2410c` pin (tests, Playwright, config defaults) survives. What breaks is everything *around* it: neutrals, the dark `brand-strong` value (`#fdba74`), the Space Grotesk logo (viewBox, `D4 Linked Rail` title, 188x54 markup), `sg-brand-mark*`, "Log in" wording, and the retired vocabulary (Rail, Ember).
2. **Brand values live in four lockstep copies today**, kept equal by hand and by tests: `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css` (byte parity, DIST-05), the explicit-toggle dark block in `test/example/priv/static/assets/css/app.css` (D-11 parity), and the golden copy under `test/fixtures/install_golden/tree/`. This is the same hand-sync failure mode the old `brandbook/tokens.css` header admits to. The seam in section 3 removes it.
3. **Three latent defects must be fixed or explicitly scheduled before the visual flip** (section 2): the shipped `sigra_admin.css` has no `.sg-brand-mark*` or explicit Light/Dark rules (they exist only in the hand-maintained example `app.css`); `scripts/ci/admin-css-conformance.sh` and `admin-token-completeness.sh` are described as merge-blocking but have no CI caller; the example's `sigra_auth.css` is a stale 13.9 KB copy of a 32 KB template with no parity gate (todo W-2).
4. **SemVer exposure is asymmetric.** Generated files (`priv/templates/**`) only reach new installs; existing hosts keep their copy. Library-owned code (`lib/sigra/admin/**`, `lib/sigra/branding*`) reaches everyone on `mix deps.update`. The dangerous case is library markup that needs new CSS classes the host's frozen generated CSS lacks. Rule: additive classes, words always rendered, version-stamped CSS.
5. **Cleanest seam:** vendor the brand book byte-identical and hash-pinned; add one small hand-written mapping file; a zero-dependency Elixir builder (built-in `JSON`, Elixir ~> 1.18) splices marker-delimited regions into the existing plain-CSS templates and copies assets; `--check` mode runs inside `mix test`. Golden fixtures stay produced by the real installer (`mix sigra.fixture.rebless_golden`), never written by the builder.
6. **Do the pipeline before the paint.** Phase 2 proves the builder by regenerating *current* values with golden diff = 0 (pin-then-unpin). Phase 3 then flips values by deleting pins, so the diff is exactly the brand change.
7. **Before-screens without baselines:** a three-tier static catalog (copy inventory, pure component render, example-app page render) emitting normalized HTML, diffable before/after, axe-checked in light and dark with the existing static-server pattern. No new PNG baselines. This is also the "replacement written first" that the open todo on cutting the Playwright machinery asks for.

---

## 1. Standard Architecture

### 1.1 Ownership lanes (what changes where)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ SOURCE (new)             brand/  vendored, byte-identical, SHA256SUMS-pinned │
│   brand.json  tokens.json  BRAND.md  assets/{logo,icon,avatar,readme,docs}  │
└───────────────┬────────────────────────────────────────────────────────────┘
                │ read by
┌───────────────▼────────────────────────────────────────────────────────────┐
│ MAPPING + BUILDER (new, dev-only, NOT shipped on Hex)                       │
│   scripts/brand/sigra-map.json    brand token -> --sg-* name, pins, pairs   │
│   test/support/brand/build.ex     Sigra.Test.BrandBuild (compiled :test)    │
│   scripts/brand/build.exs         CLI wrapper:  MIX_ENV=test mix run ...    │
└───────┬─────────────────┬──────────────────┬───────────────────────────────┘
        │ splice regions  │ copy assets      │ --check (ExUnit)
┌───────▼───────┐ ┌───────▼────────┐ ┌───────▼─────────────────────────────┐
│ HOST-OWNED    │ │ EXAMPLE MIRROR │ │ DOCS / PACKAGE SURFACES              │
│ TEMPLATES     │ │ (hand-kept)    │ │ mix.exs favicon/logo/description,    │
│ priv/templates│ │ test/example   │ │ README, guides, ExDoc head CSS       │
│ sigra.install │ │ static copies  │ │ (checked by copy-contract tests;     │
│ -> new installs│ │ + app.css     │ │  assets copied by the builder)       │
│   only        │ │                │ └──────────────────────────────────────┘
└───────┬───────┘ └────────────────┘
        │ real installer run
┌───────▼───────────────────────────────────────────────────────────────────┐
│ GOLDEN: test/fixtures/install_golden/{tree,STDOUT.txt}                      │
│ produced ONLY by `mix sigra.fixture.rebless_golden`; verified by            │
│ golden_diff_test + `rebless_golden --check` (CI hard gate)                  │
└────────────────────────────────────────────────────────────────────────────┘

LIBRARY-OWNED (reaches every adopter on deps.update): lib/sigra/admin/**,
lib/sigra/branding*.ex, lib/sigra/config.ex  ->  words + markup here are the SemVer-sensitive lane.
```

### 1.2 Component responsibilities: new vs modified vs frozen

| Component | Status | Responsibility | Notes |
|---|---|---|---|
| `brand/` (vendored book) | **NEW** | Immutable source; never hand-edited | `SHA256SUMS` + version in the lock; old `brandbook/` stays until replaced deliberately |
| `scripts/brand/sigra-map.json` | **NEW** | Hand-reviewed mapping: brand token -> `--sg-*` name, light/dark, temporary `pin`s, contrast-pair ids | The only place "tokens keep their names" is encoded |
| `Sigra.Test.BrandBuild` + `scripts/brand/build.exs` | **NEW** | Splice regions, copy assets, `--check` | Lives under `test/support` so it does not ship (see anti-pattern 3) |
| `test/sigra/brand/*_test.exs` | **NEW** | Source pin, generated-drift, frozen surface, copy contract, token contrast | Runs in plain `mix test` / `mix ci`; no new CI job |
| `test/fixtures/brand/` | **NEW** | `frozen-surface.json`, `copy-baseline.json`, catalog `before/` manifest | Ratchet baselines; only allowed to shrink (copy) or grow (frozen surface) |
| Catalog (tiers 0-2) | **NEW** | Before/after screens as normalized HTML | Section 6 |
| `priv/templates/sigra.install/admin/sigra_admin.css` | **MODIFIED** | Gains marker regions; values flip in Phase 3 | Stays plain CSS so the existing guards and parity tests keep working |
| `priv/templates/sigra.install/core/sigra_auth.css` | **MODIFIED (light)** | Compat selectors and host-default fallbacks stay frozen; only comments/markers and any new additive classes | Host-default palette is not Sigra's brand |
| `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg` | **MODIFIED (content)** | Same file names and install targets, new drawing | Names are pinned by `admin_test.exs`; keep them |
| `priv/templates/sigra.install/admin/components/admin_shell.ex` | **MODIFIED** | Typemark markup, theme switch, shell words | Host-owned after install |
| `lib/sigra/admin/components.ex`, `lib/sigra/admin/live/*.ex` | **MODIFIED (P4)** | Status mark + word, operator-job copy | Library-owned: additive markup, byte-exact goldens in `components_test.exs` |
| `lib/sigra/branding/profile.ex`, `lib/sigra/branding.ex`, `lib/sigra/config.ex` | **FROZEN** | Host-default palette, keys, validation, dark derivation | Public config surface |
| `Sigra.Branding.Contrast` | **REUSED** | WCAG maths for the token-pair test | Already in `lib/`; no new dependency |
| `mix sigra.fixture.rebless_golden` | **REUSED** | Only writer of golden fixtures | `--check` is already a CI hard gate |

---

## 2. Latent defects and constraints found (these change the plan)

| # | Finding | Evidence | Confidence | Consequence |
|---|---|---|---|---|
| L1 | Shipped admin CSS has **no `.sg-brand-mark*` rules and no explicit Light/Dark (`data-sg-admin-theme`, `data-theme`) rules**. They exist only in the example's hand-maintained `app.css` (15 and 14 hits; 0 in the template, the example copy and the golden copy). `admin_shell.ex` renders two stacked `<img>` (light and dark lockups) and a Light/Dark/System switch that set attributes nothing in the shipped CSS reads. | `grep -c` on the four files | HIGH that the rules are absent; MEDIUM [inferred] that generated hosts show both lockups and only System theming works | The one place Sigra's logo shows in a host is untested in generated hosts (`admin-theme.spec.ts` runs against the example). Move these rules into the shipped CSS (single owner) before changing the logo. |
| L2 | `scripts/ci/admin-css-conformance.sh` (no raw hex outside `:root`, no `transition: all`, no raw px) and `admin-token-completeness.sh` have **no caller** in `.github/`, `mix.exs` or `test/`. Both pass today (run during this research; "100 tokens, :root == doc"). The ExUnit twin of completeness (`admin_test.exs:473`) is the live gate. | grep + local run | HIGH | Wire both into `mix ci` (or `fast_checks`) in Phase 2 so the token flip is guarded. |
| L3 | `test/example/priv/static/assets/sigra_auth.css` is 13,867 B vs the 32,072 B template; **no parity gate exists** (todo W-2). The catalog must render from the template, not the example copy. | file sizes, `.planning/todos/pending/2026-07-28-w2-*` | HIGH | Add the parity gate first (it fails immediately, by design), then refresh the copy. |
| L4 | **8 Playwright specs and `helpers/adminFlows.ts` locate the sign-in button by text**: `#login_form button:has-text("Log in")`; demo specs assert headings "Log in to Tasklane / Meridian Health / Night Ops". The generated login already says "Sign in". | grep of `test/example/priv/playwright` | HIGH | Introduce one `loginSubmit(page)` helper in Phase 1 (test-only) so the voice change in Phase 4 is a one-line edit. |
| L5 | `dgettext("sigra", ...)` appears 340 times, **all in `priv/templates`, none in `lib/`**. msgids are lookup keys. | grep count | HIGH | Changing a template msgid ("Log in" -> "Sign in") only affects new installs (existing hosts keep their template and their `.po`). Library admin strings are plain literals, so they carry no catalog break but do change for everyone. |
| L6 | Hard structural tests: `templates_layout_test.exs` asserts **exactly 52 files** in `priv/templates/sigra.install/core/`; `design_gallery_isolation_test.exs` forbids any template path containing the substring `design`; the installer walker accepts only `{:eex, source, target}`. | test sources, `lib/sigra/install/runner.ex:75` | HIGH | No new files in `core/` without editing the count; no catalog/builder artifacts named `*design*` under `priv/templates/sigra.install`; **binary fonts cannot ship** without a new `{:copy, ...}` kind (runner, `Feature` behaviour type, idempotency tests). |
| L7 | `components_test.exs` holds **byte-exact HTML goldens** (`@notice_golden`, `@audit_row_compact_golden`, `@audit_row_full_golden`) and asserts `.sg-status-pill[data-tone]::before` ships in CSS. | `test/sigra/admin/components_test.exs:68-96,610` | HIGH | Add new components beside existing ones; do not mutate `notice`/`audit_row` markup in early slices. |
| L8 | README and nine guides are pinned to `{:sigra, "~> 1.5.0"}` by `phase_242_shift_left_contract_test.exs`; the brand book samples use `~> 1.7`; package is 1.7.2. The README/launch text also still says "Vaultr" (demo is Tasklane). | test + README | HIGH | Treat as a separate decision; do not let a README rewrite silently change the tuple. |
| L9 | PNG baselines: 27 (`admin-checkpoints`) + 84 (`admin-design`) + 4 (`demo-showcase`), gated by `snapshot-canary-guard.sh`; PR lane runs `admin-design` behavior only (`--grep-invert '@snapshot'`), snapshots run on non-PR; recapture is CI-native ubuntu only. | `.github/workflows/ci.yml:1352-1380`, prior-milestone recapture notes | MEDIUM (lane-by-lane PR behavior not fully re-read) | A token flip will drift these. Verify which lanes compare PNGs on PRs at roadmap time and pick: ride the CI-native recapture jobs, or get explicit approval to demote. Never recapture on darwin. |
| L10 | Explicit **admin dark parity**: `admin_test.exs:410-428` asserts the `@media (prefers-color-scheme: dark)` block equals the example `app.css` explicit block and that dark brand-strong is `#fdba74`; `admin-theme.spec.ts:1441` re-asserts it in a browser contrast composite. | tests | HIGH | New dark accent is Kiln Bright `#F08A55`; both assertions are rewritten to read from the source, not literals. |

---

## 3. (b) Single source of truth: tokens and copy

### 3.1 Design

**Source (vendored, immutable).** Copy the brand book into `brand/` byte-for-byte. Add `brand/SHA256SUMS` (standard `sha256sum` format) and assert it from ExUnit with `:crypto.hash(:sha256, ...)` (no dependency). A version-bump of the book is a deliberate replace-and-relock commit.

**Mapping (hand-written, reviewed, tiny).** `scripts/brand/sigra-map.json`. Iterate *arrays*, never decoded maps, so output order is deterministic.

```json
{
  "regions": {
    "admin.light-tokens": [
      { "css": "--sg-color-ink",          "pin": "#151515", "from": "color.light.soot" },
      { "css": "--sg-color-subtle",       "pin": "#f6f5f2", "from": "color.light.paper" },
      { "css": "--sg-color-brand",                          "from": "color.light.kiln" },
      { "css": "--sg-color-brand-strong",                   "from": "color.secondary.kiln-deep" }
    ],
    "admin.dark-tokens": [ { "css": "--sg-color-brand-solid", "pin": "#fdba74", "from": "color.dark.kiln-bright" } ],
    "admin.status-tokens": [ { "css": "--sg-status-locked-text-light", "from": "color.status.locked-text-light" } ]
  },
  "pairs": [ { "id": "body", "light": ["--sg-color-ink", "--sg-color-subtle"], "dark": ["--sg-color-ink", "--sg-color-subtle"] } ],
  "assets": [
    { "from": "assets/logo/sigra-lockup-light.svg", "to": "priv/templates/sigra.install/admin/sigra-logo-primary.svg" }
  ]
}
```

`pin` is the pin-then-unpin device: Phase 2 ships every entry with `pin` = today's literal (output byte-identical, proven by golden diff = 0); Phase 3 deletes pins one reviewable line at a time. Hex values are normalized to **lowercase** (the book is uppercase; the existing CSS and tests are lowercase; this avoids noise diffs). New tokens (`--sg-status-*`, `--sg-font-sans`, `--sg-font-mono`) are added, never renamed.

**Builder.** `Sigra.Test.BrandBuild` (`test/support/brand/build.ex`, compiled only under `elixirc_paths(:test)`), CLI `MIX_ENV=test mix run --no-start scripts/brand/build.exs [--check]`. JSON via the built-in `JSON` module (Elixir ~> 1.18; already used in `lib/sigra/passkeys/device_name.ex`), so **zero new dependencies**. `--check` regenerates in memory and diffs; non-zero exit on drift.

**Output form.** Marker-delimited regions spliced into existing hand-written files; the files stay plain CSS:

```css
:root {
  /* sigra:brand:begin admin.light-tokens  (generated: edit scripts/brand/sigra-map.json) */
  --sg-color-ink: #151515;
  /* sigra:brand:end admin.light-tokens */
  --sg-space-1: 0.25rem; /* hand-written tokens continue */
}
```

Two cautions: (a) the D-11 extractor regex `--sg-[\w-]+\s*:\s*[^;]+;` also matches inside comments, so marker comments must never contain `--sg-x: y;`; (b) `admin-css-conformance.sh` tracks `:root` by brace depth, so generated blocks must stay inside `:root { }`.

### 3.2 What the builder owns, and what it does not

| Target | Builder action | Why |
|---|---|---|
| `priv/templates/sigra.install/admin/sigra_admin.css` regions (`:root`, dark `@media`, and, after Phase 2, the explicit-toggle block) | splice | primary SOT for admin tokens |
| `test/example/priv/static/assets/sigra_admin.css` | byte copy of template | DIST-05 already demands byte parity |
| `test/example/priv/static/assets/css/app.css` explicit-toggle block | splice **until** Phase 2 moves it into the shipped CSS, then delete | removes the D-11 lockstep rather than automating it |
| `guides/reference/admin-token-reference.md` rows for brand-derived tokens | splice (marked region) | makes completeness hold by construction |
| Admin logo SVGs (template + example `images/` + favicon) | copy from `brand/assets/**` via the `assets` map | file names stay; brand lockup names differ and are mapped |
| `test/fixtures/install_golden/**` | **never** | produced by the real installer via `rebless_golden`; builder -> rebless -> test is the order |
| `sigra_auth.css` host-default fallbacks, `Profile`/`Config` defaults | **never** | frozen host palette; guarded by a parity test (3.3) |
| README, `mix.exs` description, guides prose | **never generated** | checked by the copy-contract test; four other tests already pin README text |
| UI strings in HEEx/`dgettext` (340+ sites) | **never generated** | enforced by the copy contract (banned terms), not templating |

### 3.3 Drift checks (layered, all inside `mix test`)

1. **Source pin:** `brand/` files hash to `SHA256SUMS`; `brand.json` `version`/`date` equal the lock.
2. **Generated drift:** `BrandBuild.check/0` equals the committed files (templates, example copies, token doc region, copied assets).
3. **Install drift:** existing `golden_diff_test` + `rebless_golden --check` prove template -> real install output.
4. **Parity tests rewritten to read the source:** DIST-05, D-11 and "ember parity" stop hard-coding `#fdba74`/`#f8a39c` etc. and compare regions to each other and to the mapping.
5. **Host-default palette parity (new, tiny):** `Profile.@defaults` == `Sigra.Config` `:branding` defaults == `sigra_auth.css` fallback literals. The values currently exist in 5+ places (profile, config schema, `@dark_color_defaults`, auth CSS, the auth-branding recipe, `branding_test.exs:295`, two example modules).
6. **Token contrast (new):** for every `pairs[*]` entry, `Sigra.Branding.Contrast.contrast_ratio/2` over the **resolved CSS token values** meets the book's `minimum` for that pair id in light and dark (body, descriptor, caption, application-copy, link, focus, artwork, button, five status words). This proves the shipped CSS, not just the book.
7. **Copy contract** (3.4) and **frozen surface** (section 4).

### 3.4 Copy: one source, two enforcement modes

| Copy kind | Source in `brand.json` | Mechanism |
|---|---|---|
| Messaging (tagline, descriptor, one-line, short description, pitch) | `tagline`, `descriptor`, `messaging.boilerplate`, `messaging.pitch` | Test asserts README opening, `mix.exs` description, and `llms.txt` pointer contain the approved strings verbatim (the existing `phase_148` pin on "Evaluating first? Start with https://hexdocs.pm/sigra/demo-showcase.html." must be kept by concatenation) |
| Banned phrases ("hosted", "bank-grade", "seamless", "robust", "compliant", "certified" ...) | `messaging.boilerplate` "Do not say" | Scan README, guides/introduction, `mix.exs` description. **Allowlist negations**: the approved text itself says "not hosted auth" and "not a compliance certificate"; a naive grep fails on the book's own sentences. `launch-pack-contract.sh` already has a `reject_text` pattern to extend |
| Vocabulary (sign in/sign-in/sign out, session, revoke, suspend, lock, delete, organization, magic link, passkey, backup codes, "your app") | `voice.terms[].avoid` | Extend the existing `test/sigra/admin/glossary_test.exs` scanner (it strips non-copy lines and carves out the branding replica) to `priv/templates/sigra.install/**` and the golden tree. **Scan copy only**: route paths (`/users/log_in`), function names (`log_in_user`), and identifiers stay |
| Ratchet | n/a | Phase 1 records today's violations in `test/fixtures/brand/copy-baseline.json`; the test fails on any **new** violation and on any baseline entry that disappears without being removed from the file; Phase 4 drives the baseline to empty |

---

## 4. (c) Whitelabel overrides and SemVer safety

### 4.1 What adopters can override today (all must keep working)

| Lane | Mechanism | Where | Status in this milestone |
|---|---|---|---|
| Config tokens | `Sigra.Config` `:branding` keys (product_name, logo_url, dark_logo_url, 7 light + 7 dark colors, support/privacy/terms URLs, email sender, theme) | `lib/sigra/config.ex`, `lib/sigra/branding/profile.ex` | **Frozen**: keys, types, validation, defaults |
| Admin-managed profile | `sigra_brand_profiles` row via `Sigra.Branding.save_global/3` and `/admin/auth-branding` | `lib/sigra/branding.ex`, migration template | Frozen |
| Runtime CSS variables | `Branding.css_variables/1` emits `--sigra-auth-{light,dark}-{accent,on-accent,bg,surface,text,muted,border}` inline on `.sigra-auth`; CSS consumes `var(--sigra-auth-light-accent, <fallback>)` | `lib/sigra/branding.ex`, `sigra_auth.css` | Names and `var(name, fallback)` shape frozen; fallback literals frozen |
| Dark derivation | `Contrast.fit_to_surface/3`, `dark_accent_source/1` | `lib/sigra/branding.ex` | Frozen (the code comment says "do not drop it") |
| Semantic classes | `sigra-auth-*` vocabulary + scoped `.btn`/`.btn-primary`/`.bg-brand` compat selectors | `sigra_auth.css`, pinned by `auth_ui_contract_test.exs` | Frozen; compat selectors must stay for pre-v1.46 hosts |
| Full control | host edits generated `sigra_auth_components.ex`, templates, CSS, `admin_shell.ex`, `sigra_admin.css` | host repo | Preserved because templates are copy-on-install, never rewritten |
| Admin typemark swap | edit generated `admin_shell.ex` | host repo | Works today; an optional first-class config for it would be new API, so defer |

### 4.2 Brand-driven decisions that follow

- **Do not change the host-default palette.** Today's defaults (`#f7f4ee`, `#171717`, `#6b6258`, `#ded8cf`, dark `#171614`/`#211f1c`/`#f4f1eb`/`#bdb5aa`) are warm-neutral near-neighbours of Paper/Soot/Chalk, not the brand. The brand book itself says auth screens wear the host's brand and "Sigra supplies the words and none of the color". Freezing them has zero SemVer cost; changing them re-skins every host that relies on defaults and reflows the pinned walkthrough excerpts. Record in the compat policy that the default accent equals Kiln by design ("no generated code has to change").
- **Sigra identity never appears on host auth/registration/2FA/email screens.** Current state already satisfies it (`sigra-auth__mark` is a neutral placeholder; product name comes from the profile). Guard it with a test: no `sigra-logo`, no Sigra typemark asset, and no literal "Sigra" in `priv/templates/sigra.install/core/*` rendered copy outside an optional plain-text footer.
- **Brand placeholder stays host-neutral.** Do not substitute the Sigra typemark for the missing-logo mark.

### 4.3 SemVer classification table (put this in `guides/reference/brand-compatibility.md`)

| Change type | Class | Rule |
|---|---|---|
| Module names, config keys, Profile struct keys, route paths, `data-testid`s (13), generated function names, installer targets (`priv/static/assets/sigra_admin.css`, `sigra_auth.css`, `images/sigra-logo-primary{,-dark}.svg`) | **Frozen** | Snapshot to `test/fixtures/brand/frozen-surface.json` in Phase 1; test asserts current set is a **superset** of the snapshot |
| `--sg-*` (100 documented `:root` tokens; 127 distinct `--sg-*` declarations file-wide), `--sigra-auth-*` (21), `sg-*` / `sigra-auth-*` classes | **Add, never rename or remove** | Legacy names with retired meaning (`--sg-logo-rail-accent`, `--sg-logo-rail-ember`, `--sg-logo-core`) keep their name; add a comment, optionally add a new alias |
| Values of admin tokens, logo drawings, shell/auth copy in `priv/templates` | **Free (new installs only)** | Existing hosts are untouched; document the compare-don't-overwrite path like `guides/introduction/upgrading-to-v1.46.md` |
| Words and markup in **library-owned** `lib/sigra/admin/**` | **Visible to all on deps.update** | Minor release, CHANGELOG "Changed", upgrade note; keep ids/`data-testid`s; adopter tests that assert English text will break and must be told |
| New library markup needing new CSS | **Skew hazard** | Additive classes only; the word is always rendered as text so an unstyled mark degrades to "word without glyph"; stamp the CSS (`/* sigra-admin-css: <n> */`) and let `mix sigra.doctor` warn when the host stamp is older than the library expects; mention in the upgrade guide |
| `dgettext` msgids | **Templates only** | Existing hosts keep their catalog; never rename msgids in `lib/` (there are none) |

### 4.4 Hex package notes

`package.files` is `lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md`: **`priv/` ships, `brand/` and `brandbook/` do not.** ExDoc currently references `brandbook/favicon.svg` at docs-build time only. README images must be absolute URLs if they are to render on the Hex page [inferred; Hex renders the packaged README without repo-relative assets]. Do not let `CHANGELOG.md` "Unreleased" collect hand notes (release-please orphaning footgun documented in the file).

---

## 5. (a) Blast-radius table

Legend: **P#** = the phase that must touch it. "Asserts" is what breaks. Everything is HIGH confidence (read from source) unless marked.

### 5.1 Brand values: hex, fonts, marks, vocabulary

| Path | Asserts / pins | P |
|---|---|---|
| `priv/templates/sigra.install/admin/sigra_admin.css` (41 KB; 40 hex literals; 100 documented `:root` tokens) | Neutrals `#151515 #686868 #f6f5f2`, dark `#171614 #1f1d1a`, brand `#c2410c`, brand-strong `#9a3412` / dark `#fdba74`, `--sg-logo-rail-accent/-ember/-core`, ok/warn/risk/info literals; **no font-family**, **no sg-brand-mark**, **no explicit-theme rules** (L1) | 2, 3 |
| `priv/templates/sigra.install/core/sigra_auth.css` (32 KB; 31 hex literals; 21 `--sigra-auth-*`) | Host-default fallbacks, risk/warn/ok literals (parity with admin by test), `.btn*` compat selectors, neutral `.sigra-auth__mark` | 2 (markers only), 4 |
| `priv/templates/sigra.install/admin/sigra-logo-primary.svg`, `-dark.svg` | Space Grotesk "D4 Linked Rail" outlined paths, `viewBox="20 220 2361 1000"`, `#c2410c` tittle, dark `#fdba74` | 3 |
| `priv/templates/sigra.install/admin/components/admin_shell.ex` | `sg-brand-mark__lockup/__image--light/--dark/__section`, 188x54, `aria-label="Sigra admin overview"`, label "Admin", theme labels, "Jump to…", "Exit to global" | 3, 4 |
| `lib/sigra/branding/profile.ex`, `lib/sigra/config.ex`, `lib/sigra/branding.ex` | Host-default palette + `#c2410c` default + dark defaults | frozen |
| `test/example/priv/static/assets/sigra_admin.css` | DIST-05 byte parity with template | 2, 3 |
| `test/example/priv/static/assets/sigra_auth.css` | **Stale (13.9 KB), ungated** (L3) | 2 |
| `test/example/priv/static/assets/css/app.css` (76 KB) | Explicit-toggle dark/light token blocks (D-11), 15 `.sg-brand-mark*` rules, Space Grotesk `@font-face`, `--font-sans` | 2 (move out), 3 |
| `test/example/priv/static/images/{sigra-logo-primary,-dark,rail-accent-mark,-dark}.svg`, `assets/fonts/space-grotesk-var.woff2`, `favicon.ico` | Old logo set, old face | 3 |
| `test/example/lib/example/demo/branding.ex` | Demo preset id `rail-accent` / "Rail Accent" (retired word), `#c2410c` | 3 |
| `test/fixtures/install_golden/tree/priv/static/{assets/sigra_admin.css, assets/sigra_auth.css, images/*.svg}` + ~60 generated `.ex` files + `STDOUT.txt` (85 files) | Byte-for-byte install output | every phase that changes templates (rebless) |

### 5.2 Tests

| Path | Asserts | P |
|---|---|---|
| `test/sigra/install/features/admin_test.exs` | `:39-42` logo manifest; `:299-305` `sg-brand-mark__lockup`, `width="188"`, `height="54"`, **refutes** `__word`/`__core`; `:330-345` SVGs: `viewBox="20 220 2361 1000"`, "Space Grotesk v2.0"; `:396` DIST-05; `:410-428` D-11 + `--sg-color-brand-strong: #fdba74;`; `:431-471` ember parity `#f8a39c #f5c451 #5dd1a0`; `:473` token-doc completeness | 2, 3 |
| `test/sigra/architecture_guides_contract_test.exs` | `:6,:218` `favicon: "brandbook/favicon.svg"`; `:219-226` title "Sigra D4 Linked Rail favicon mark", `#c2410c`, `#fdba74`, `prefers-color-scheme: dark`; walkthrough source anchors for `lib/sigra/config.ex` and example accounts (reflow if Config/branding excerpts change); asserts the literal `before_closing_head_tag` mermaid block in `mix.exs` | 3, 5 |
| `test/sigra/branding_test.exs`, `test/sigra/branding/contrast_test.exs` | `#c2410c` in error strings and fixtures; `:295` default bg `#f7f4ee` | frozen |
| `test/example/test/example_web/admin_shell_test.exs` | `:25-30` lockup markup/src, refutes `rail-accent`; `:74-80` "Space Grotesk v2.0" | 3 |
| `test/sigra/install/templates_layout_test.exs` | exactly 52 files in `core/` | any new core file |
| `test/sigra/install/design_gallery_isolation_test.exs` | no template path containing `design` | all |
| `test/sigra/install/auth_ui_contract_test.exs` | login strings ("Continue with a passkey", "Email me a sign-in link", "Other ways to sign in"), invitation mismatch strings, `sigra-auth*`-only class tokens in 16 templates, no `<.button` | 4 |
| `test/sigra/install/generator_passkey_primary_login_test.exs` | "Sign in with password", `dgettext("sigra", "Sign in")` | 4 |
| `test/sigra/admin/glossary_test.exs` (+ `guides/reference/admin-glossary.md`) | banned-synonym scan of 9 admin files; carve-out for the branding replica ("Log in") | 1 (extend), 4 |
| `test/sigra/admin/components_test.exs` | byte-exact goldens (L7), `data-tone` mapping, `.sg-status-pill[data-tone]::before` in CSS | 4 |
| `test/example/test/example_web/live/admin_user_filters_live_test.exs`, `admin_user_show_live_test.exs:297`, `emails_security_html_test.exs:46` ("Account Locked"), `emails_lifecycle_html_test.exs:93`, `page_controller_test`, `session_controller_test`, `credentials_live_test`, `getting_started_flow_test` | `data-tone` risk/warn, `sg-status-pill`, email subjects/words | 4 |
| `test/sigra/planning/phase_148_*`, `phase_149_*`, `phase_242_shift_left_contract_test.exs` | README "Pick your lane" and Evaluating row, mix.exs description sentence, README launch links, `~> 1.5.0` in README + 9 guides | 5 |
| 30 test files read `priv/templates/**` directly; 28 install tests assert strings | any template wording change | 4 |
| Playwright: `admin-generated.spec.ts:273` (`--sg-color-brand == #c2410c`, **survives**); `:68-173` "Sign in" heading, "Sign in with password" | generated-host smoke | 4 |
| Playwright: `admin-theme.spec.ts:80-110` lockup opacity swap + srcs; `:1419-1446` dark brand-strong `#fdba74` contrast composite | example only (L1) | 3 |
| Playwright: `admin-design.setup.ts:14`, `admin-design.spec.ts:35`, `admin-eval.spec.ts:147` (`document.fonts.check('16px "Space Grotesk"')`); `demo-showcase.spec.ts:317-329` (title/body font is **not** Space Grotesk), `:543-555` preset `rail-accent` img src; `lib/eval/probes.ts` probe 4 `ember-reserved-for` + `sg-ember` | font/vocabulary pins | 3 |
| Playwright locators on words: `#login_form button:has-text("Log in")` in `golden-path`, `ga-uat-shift-left`, `passkey-options`, `organizations` (3x), `demo-showcase` (3x), `helpers/adminFlows.ts:77`; headings "Log in to Tasklane / Meridian Health / Night Ops"; "Sign in as <name>" | L4 | 1 (indirect), 4 |
| 115 PNG baselines + `snapshot-allowlist{,-design}` + `guides/assets/*.png` (4 docs screenshots) | pixels | 3, 4, 5 (L9) |

### 5.3 CI scripts and workflow

| Path | Asserts | P |
|---|---|---|
| `scripts/ci/admin-css-conformance.sh` (+ `.test.sh`) | No `transition: all`, no raw hex outside `:root`, no raw px in eligible props. **No CI caller (L2).** The `.test.sh` uses `#c2410c`/`#fdba74` only as hermetic fixtures (brand-agnostic) | 2 (wire) |
| `scripts/ci/admin-token-completeness.sh` | `:root` `--sg-*` set == tokens documented in `admin-token-reference.md`. **No CI caller** | 2 (wire) |
| `scripts/ci/app-css-corruption-check.sh` (+test), `ci.yml:286` | `app.css` must not declare `--sg-*` and must not contain stray comments | 2 |
| `scripts/ci/stale-render-guard.sh` | Watches template + example copies of `sigra_admin.css` | 2 |
| `scripts/ci/snapshot-canary-guard.sh`, `quality-ledger-monotonic.sh`, `award-guard.mjs` (`fast_checks`) | Baseline/ledger movement | 3, 4 |
| `.github/workflows/ci.yml` `install_golden_contract` (~485-566) | `golden_diff_test`, idempotency, `rebless_golden --check` hard gate | every template phase |
| `.github/workflows/ci.yml` `design_gallery`, `admin_checkpoints` seams, `admin_design_recapture`, `admin_checkpoint_recapture` | PNG comparison/recapture (CI-native) | 3, 4 (L9) |
| `scripts/ci/launch-pack-contract.sh`, `getting-started-contract.sh` | README links to launch docs; reject-phrases in launch docs | 5 |
| `scripts/brand/axe-brandbook.mjs`, `outline-wordmark.mjs`, `critique-render.mjs` | axe on `brandbook/index.html`; Space Grotesk outlining; file:// screenshotter | 5 (retarget at `brand/`), 2 (reuse for catalog) |
| `scripts/panel/lenses.mjs` | LLM-panel prompt text quoting Ember/Core Rails/Space Grotesk | leave (slated for cut; do not touch in a brand PR) |

### 5.4 Docs, package and instruction surfaces

| Path | Pins | P |
|---|---|---|
| `mix.exs:210` `favicon: "brandbook/favicon.svg"`; no `logo:`; `description:` string; `before_closing_head_tag` | Old favicon path; pinned head block; description pinned by phase_148 | 3 (favicon), 5 |
| `README.md`, `docs/launch/v1.0/*`, `guides/introduction/demo-showcase.md`, `llms.txt` | Header, "Vaultr", `~> 1.5.0`, launch links, pointer-only `llms.txt` contract | 5 |
| `CLAUDE.md` ("Admin UI Direction": Rail Accent, `brandbook/`), `AGENTS.md:8` | Tell agents to use the retired brand | 5, **needs owner approval** |
| `guides/reference/admin-ui-principles.md:30,37`, `admin-design-contract.md` (v1.36 addendum), `admin-graphic-design-lens.md`, `admin-token-reference.md` (rail/ember rows, dark note), `admin-fractal-scorecard.md`, `guides/recipes/auth-branding.md` | Retired vocabulary, `brandbook/tokens.*` pointers, default palette literals | 3 (token ref), 5 |
| `brandbook/**` (old) | Stays until replaced deliberately; removal also forces `architecture_guides_contract_test` `@favicon` and `axe-brandbook.mjs` retargeting | 5 (last) |

---

## 6. (e) Before-screen catalog without growing the Playwright matrix

Direction: the project is moving admin verification toward a component catalog, and the open todo says to write the replacement before cutting anything. This is that replacement, scoped to the brand pass.

| Tier | What | Needs | Where | Deterministic by |
|---|---|---|---|---|
| **0 Copy and class inventory** | Every on-screen word and class/token usage extracted from `priv/templates/**`, `lib/sigra/admin/**` and the golden tree: HEEx text nodes, `dgettext` msgids, flash/`put_flash` strings, `action=`/`label=` attrs, `sg-*` / `sigra-auth-*` class sets | nothing (text scan) | `Sigra.Test.Catalog.Inventory` -> `test/fixtures/brand/before/copy.json` | sorted keys; line numbers dropped |
| **1 Component state catalog** | `Sigra.Admin.Components` in every state (the existing dev-only `/admin/_design` gallery already uses static literal assigns; reuse its fixtures), `sigra_auth_page` with fixture branding in light/dark/system, the five email builders from `emails.ex` | no DB, no server: `Phoenix.LiveViewTest.rendered_to_string/1` | `test/support/catalog/**`, run under `mix test` with `SIGRA_CATALOG_DIR` set | pure functions of literal assigns |
| **2 Page catalog** | Full pages for the **operator job** (Users list, user detail, sessions, per-user audit, branding preview) and the generated auth flows, rendered by the example app via `ConnCase` GET with the seeded cohort | Postgres (already required by the suite); example app | `test/example/test/example_web/catalog_test.exs` | normalize CSRF tokens, `data-phx-*`, generated ids, timestamps (fixtures use fixed `inserted_at`); reuse the normalization idea from `InstallFixture.normalize_tree` |

Fixtures: use `Example.Demo.Personas`/`Seeds` (ten personas already include locked, unconfirmed, scheduled-deletion and a zero-state user, plus org roles) so the catalog covers exactly the five brand statuses with no new seed data. Auth pages must render with the **template** `sigra_auth.css` (L3), not the stale example copy. Because the example is a hand-maintained mirror of the templates, tier 2 should carry a cheap drift assertion (extend `installer_drift_test.exs` style) and the truth remains the golden tree and the existing generated-host smoke.

Outputs and checks:

- Normalized HTML per state plus an `index.html` that loads the real CSS and toggles theme via the same attributes the shell uses (`data-sg-admin-theme`, `data-theme`). Commit only the **manifest and copy inventory** for `before/`; keep full HTML as a CI artifact (or commit it if the size is acceptable: ~40 files). After Phase 4 the review artifact is a text diff of `before` vs `after`.
- Visual pass: reuse `scripts/brand/critique-render.mjs` (file:// headless screenshotter, uses the existing Playwright install) for an **uncommitted** contact sheet.
- Browser contrast: clone the `axe-brandbook.mjs` pattern (short-lived static server + `@axe-core/playwright`, wcag2a/2aa) over `index.html` in light and dark. No baselines, no snapshot allowlists.
- Capture the `before/` set at the start of Phase 2, at the commit where generated output is still byte-identical to main.

Cost: Tier 0 is minutes; Tier 1 is a few hundred lines; Tier 2 reuses test infrastructure that already seeds and logs in. Nothing here touches `.github/` or the PNG lanes.

---

## 7. (d) Suggested build order (five phases)

Phase numbers are assigned by the roadmapper (likely 259-263). Dependency chain: **P1 -> P2 -> P3 -> P4 -> P5**, with P3 and the catalog's "before" capture both depending on P2.

### Phase 1: Policy, pinned source, contracts (docs and tests only)

- **Delivers:** `brand/` vendored byte-identical + `SHA256SUMS`; `guides/reference/brand-compatibility.md` (section 4.3); `test/sigra/brand/{source_pin,frozen_surface,copy_contract}_test.exs` with ratchet baselines; name-clearance record as a decision (`.planning/decisions/005-*`; the book states the name is not cleared); test-only `loginSubmit` helper replacing `button:has-text("Log in")` across the 8 specs (L4).
- **May touch:** `brand/**` (add), `test/sigra/brand/**`, `test/fixtures/brand/**`, `guides/reference/brand-compatibility.md`, `mix.exs` `extras`/`groups_for_extras` only, `.planning/**`, `test/example/priv/playwright/helpers` and spec selectors (indirection only).
- **Must not touch:** `lib/`, `priv/templates/**`, golden, any CSS/SVG, README, `mix.exs` description/favicon, `CLAUDE.md`/`AGENTS.md`.
- **Exit:** `mix test` green; zero shipped-byte diff (`git diff --stat -- lib priv` empty).
- **Avoids:** hand-sync drift, unreviewed copy regressions, SemVer slips.
- **Research flag:** none (standard).

### Phase 2: Deterministic pipeline and before-catalog (no brand change)

- **Delivers:** `scripts/brand/sigra-map.json` (all entries **pinned** to current values), `Sigra.Test.BrandBuild`, marker regions, `generated_drift_test`; wiring of `admin-css-conformance.sh` + `admin-token-completeness.sh` into `mix ci`/`fast_checks` (L2); W-2 parity gate + example `sigra_auth.css` refresh (L3); L1 fix: move `.sg-brand-mark*` and explicit-theme blocks into shipped `sigra_admin.css`, delete the `app.css` copies and the D-11 lockstep; host-default-palette parity test; catalog tiers 0-2 and the committed `before/` manifest.
- **Two commits, two gates:** (a) markers + builder, **golden diff = 0 and DIST-05 unchanged**; (b) ownership move, golden reblessed with an **additive-only** diff (new rules), reviewed as such.
- **May touch:** `scripts/brand/**`, `test/support/**`, template CSS (markers, additive rules), example static copies, `app.css` (deletions of moved blocks only), `mix.exs` aliases, `ci.yml` (add steps only), `guides/reference/admin-token-reference.md` (marked region).
- **Must not touch:** any token **value**, any logo, any copy, `Sigra.Admin.Components` markup, `Profile`/`Config`.
- **Exit:** `build.exs --check` clean; `MIX_ENV=test mix sigra.fixture.rebless_golden --check` clean; generated-host spec asserts lockup swap and explicit theme in a **generated** host.
- **Risk:** moving explicit-theme rules is a behavior fix for generated hosts; call it out in the changelog. PNG lanes may drift on the example refresh (L9).
- **Research flag:** moderate (catalog tier-2 normalization, one spike).

### Phase 3: Tokens, type, logo, favicon (light and dark) with contrast checks

- **Delivers:** unpin map entries (neutrals, Kiln Deep, Kiln Bright dark accent, Paper/Char surfaces); add `--sg-status-*` (five words, light/dark) and `--sg-font-sans`/`--sg-font-mono` (stacks only); new logo SVGs under the **same file names**; `admin_shell.ex` typemark markup; favicon (`mix.exs`, `architecture_guides_contract_test` rewritten against `brand/assets/icon/favicon.svg`); token-contrast test; axe on catalog; rewrite D-11/ember-parity/logo/shell/theme/font assertions to read from the source; rename demo preset `rail-accent`; update `admin-token-reference.md` logo-token rows (names kept).
- **May touch:** mapping, generated regions, template/example/golden CSS and SVG, listed tests, `mix.exs` favicon, `admin_shell.ex`, example static assets, demo preset.
- **Must not touch:** `Profile`/`Config`/`Branding` defaults, `--sigra-auth-*`, `sigra_auth.css` fallback literals, `lib/sigra/admin/**` markup, any `data-testid`/id, token **names**.
- **Fonts decision gate:** ship tokens + system fallback stack only (the book itself accepts a system stack for the generated admin because a web font is a dependency). Shipping Instrument Sans/Red Hat Mono woff2 (36 KB total in the book's subsets) needs a `{:copy, ...}` installer kind (L6) and is a separate explicit decision.
- **Exit:** every contrast pair passes in light and dark; catalog axe clean; golden reblessed; PNG lanes handled per L9 decision.
- **Research flag:** yes: favicon legibility at 16-24 px (the book says no one has looked), baseline-lane handling.

### Phase 4: Words and layout (one operator job end to end, then everything)

- **4a: Operator job** ("a user says they cannot sign in"): Users list led by "Needs an admin" (locked, unconfirmed > 7 days, deleting) -> user detail status in words -> sessions -> per-user audit (time zones written out, blank effective-user cell). New `status_mark` component **beside** the existing pill markup; `sg-status-pill` stays for non-status uses; CSS stamped; doctor warning for older host CSS.
- **4b: Every other admin screen** (overview, audit index, organization, branding page): promote the admin copy contract from ratchet to strict.
- **4c: Generated auth + emails:** "Log in" -> "Sign in" (templates, flash strings, emails; **not** routes or function names); SEED-003 `dgettext` coverage audit; SEED-010 residual (the `organizations/**` templates are still daisyUI: about 26 `btn` class uses across 5 files incl. `org_switcher.ex`; decide convert vs leave as host-owned Tailwind screens); update the glossary carve-out; rebless golden; update the example mirror.
- **May touch:** `lib/sigra/admin/**` (additive markup), `priv/templates/**` copy, `sigra_admin.css`/`sigra_auth.css` additive classes, tests listed in 5.2, golden, example mirror.
- **Must not touch:** frozen surface (section 4.3), msgids in `lib/`, route paths, existing `components_test` goldens (add new ones; re-bless old ones only in the slice that intentionally changes them).
- **Exit per slice:** catalog `after` diff reviewed against `before`; copy baseline shrinks; golden + install tests green; CHANGELOG/upgrade note for 4a/4b (library-owned lane).
- **Research flag:** yes, largest phase. Check LiveView `render/1` purity for tier-1 catalog of lib LiveViews; decide the status-mark delivery (inline SVG in HEEx vs CSS mask; CSP-safe, `forced-colors` safe).

### Phase 5: Public surfaces, announcement and any trademark claim last

- **Delivers:** README header (picture element with light/dark SVG) and approved copy; `mix.exs` description (one-line text + the pinned "Evaluating first?" sentence), `logo:` if ExDoc accepts the SVG at a legible size; ExDoc code-color CSS from the book appended to the head block without disturbing the asserted mermaid block; verified `mix docs --warnings-as-errors` (the book says its ExDoc stylesheet was never run in a real build); Hex package check via the existing dry-run script; demo name fixed (Vaultr -> Tasklane) in README/launch docs; `guides/introduction/upgrading-to-v1.NN.md`; instruction surfaces (`CLAUDE.md`, `AGENTS.md`, admin guides) updated **with owner approval**; docs screenshots regenerated from the demo; deliberate `brandbook/` retirement last (rewrite `@favicon` test path, retarget `axe-brandbook.mjs`).
- **Never in the same PR as P1-P4:** any push, merge, release, tag; any trademark symbol (the book: use TM only if the maintainers decide to claim the name).
- **May touch:** README, `mix.exs` docs/description, guides, `docs/launch`, `llms.txt` pointer text (keep pointer-only), instruction files (approved).
- **Research flag:** moderate (ExDoc `logo:`/CSS behavior, Hex description length via `mix hex.build`).

---

## 8. Patterns to follow

**Pin-then-unpin.** Introduce the mechanism with current values pinned so the proof is "diff = 0", then change values by deleting pins. Same idea the Phase 11 golden barrier used for the generator refactor.

**One owner per concern.** Delete the example-only copies of shipped behavior instead of syncing them (L1). Example-only code stays example-only (`/admin/_design` is already isolated by `design_gallery_isolation_test`).

**Additive markup, word first.** The brand's own rule ("a status is always a word first") doubles as the CSS-skew mitigation: an unstyled new mark still leaves a correct word.

**Ratchet baselines.** Copy violations only shrink; frozen surface only grows. Both are JSON checked into `test/fixtures/brand/` and read by ordinary ExUnit tests.

---

## 9. Anti-patterns

1. **Render-time EEx tokens in the CSS template** (`<%= tokens %>`). Breaks the two guard scripts and the byte-parity tests that read the template as plain CSS, and hides diffs. Generate ahead of time instead.
2. **Hand-syncing the four CSS copies again.** This is the exact failure the old `brandbook/tokens.css` header documents.
3. **Shipping the builder as a Mix task in `lib/`.** `mix sigra.fixture.rebless_golden` already ships to adopters today (it lives in `lib/mix/tasks`); do not repeat that. Keep builder code under `test/support`.
4. **Writing golden fixtures from the builder.** Golden must come from a real install run; builder output feeds the template, the installer feeds golden.
5. **Mutating `audit_row`/`notice` markup or token names in Phase 3.** Breaks byte-exact goldens and the SemVer rule for no visual gain at that stage.
6. **Naive banned-word scanning.** Fails on the brand's own sentences ("not hosted auth"). Allowlist negations; scan copy lines, not identifiers or URLs.
7. **Changing the host-default palette to "match the brand".** Re-skins hosts relying on defaults; contradicts the book's "wear the host's brand".
8. **Local darwin baseline recapture, or growing the PNG matrix to get before/after.** Both contradict recorded lessons; use the catalog.
9. **Fonts via the installer without a binary-safe file kind.** EEx-rendering a woff2 corrupts it; adding the kind is its own gated change.
10. **Treating the brand's contrast table as proof about the product.** Its own text says a passing pair says nothing about a built product; test resolved CSS tokens and run axe on rendered screens.
11. **Generating from decoded JSON map order.** Use the mapping arrays; sort anything else; normalize hex case.

---

## 10. Integration points

### 10.1 Internal boundaries

| Boundary | Communication | Notes |
|---|---|---|
| `brand/` -> `BrandBuild` | file read, `JSON.decode!` | read-only; hash-checked first |
| `BrandBuild` -> templates/example/docs | in-place splice and copy | idempotent; `--check` for CI |
| templates -> installer -> golden | real `mix sigra.install` run | only `rebless_golden` writes golden |
| `Sigra.Admin.Components`/LiveViews (library) -> `sigra_admin.css` (host-owned) | CSS class names | the skew boundary: additive only, stamp + doctor |
| `Sigra.Branding` -> `sigra_auth.css` | inline `--sigra-auth-*` variables | frozen contract |
| `Sigra.Branding.Contrast` -> token-contrast test | function calls | already in `lib/` |
| catalog -> example app / components | static fixtures, `ConnCase`, `rendered_to_string` | CI artifact; no PNG baselines |

### 10.2 External surfaces

| Surface | Integration | Gotcha |
|---|---|---|
| Hex package page | `description`, packaged README | description pinned by phase_148; README rendered without repo-relative assets [inferred] |
| HexDocs (ExDoc ~> 0.40) | `favicon:`, `logo:`, `before_closing_head_tag` | head block is asserted by a contract test; book's ExDoc CSS unverified |
| GitHub repo | README header, social card (repo setting, outside the repo) | social card upload is a manual step |
| CI | `install_golden_contract`, PNG lanes, `fast_checks` | steps added, none removed |

---

## 11. Decisions the owner should make (flag at roadmap time)

1. **PNG baseline lanes during P3/P4:** ride CI-native recapture vs explicit approval to demote while the catalog proves the work (L9). Default: ride, do not cut in a brand PR.
2. **Fonts in the generated admin:** tokens + system fallback only (default) vs a new binary `{:copy, ...}` installer kind.
3. **Host-default palette:** freeze (default, recommended) vs re-theme.
4. **`organizations/**` templates (daisyUI):** convert to `sigra-auth-*` or leave as host-owned Tailwind screens (SEED-010 residual).
5. **README `~> 1.5.0` pin** vs the book's `~> 1.7`: separate decision; the pin is test-enforced.
6. **Instruction files** (`CLAUDE.md`, `AGENTS.md`) naming the retired brand: updating them needs approval.
7. **Wire the two orphaned CSS guards into CI** (recommended) or retire them.

---

## 12. Sources

- Repo, read and (where cheap) executed: `priv/templates/sigra.install/**`, `lib/sigra/{branding.ex,branding/*.ex,config.ex,admin/**,install/**,doctor.ex}`, `mix.exs`, `test/sigra/{install,admin,planning,templates,branding}/**`, `test/sigra/architecture_guides_contract_test.exs`, `test/fixtures/install_golden/**`, `test/example/**`, `scripts/ci/admin-css-conformance.sh`, `scripts/ci/admin-token-completeness.sh` (both run; both pass), `scripts/brand/*`, `.github/workflows/ci.yml`, `guides/**` (HIGH).
- `.planning/PROJECT.md` (Current Milestone), `.planning/notes/2026-11-13-v1.50-closeout-lessons-and-cuts.md`, seeds SEED-003 and SEED-010, todos W-2, W-7, `cut-ui-process-machinery-on-main`, `white-label-auth-email-theming`, `asymmetric-dark-token-fallback`, `branding-profile-has-no-dark-logo-url` (HIGH).
- The brand book (read-only reference copy): `BRAND.md`, `brand.json` (voice terms, contrast pairs, status words, messaging, assets map, "to review" risks), `tokens.json` (DTCG), `assets/README.md`, `assets/docs/sigra-exdoc.css`, `assets/fonts/web/fonts.css` (HIGH for contents; its own flagged gaps: name not cleared, ExDoc CSS unverified, favicon unviewed at 16-24 px, generated screens never viewed running).
- Items marked [inferred] are conclusions from absence of rules or from packaging behavior, not from a browser or Hex run; verify in the phase that depends on them.

---
*Architecture research for: v1.51 BRAND-IDENTITY-ADOPTION*
*Researched: 2026-11-13*
