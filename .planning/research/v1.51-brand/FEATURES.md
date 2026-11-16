# Feature Research: v1.51 BRAND-IDENTITY-ADOPTION

**Domain:** Brand-identity adoption for a hybrid library + generator auth product (Elixir/Phoenix, public SemVer API, Hex package). Subsequent milestone.
**Researched:** 2026-11-13
**Confidence:** HIGH for repo-grounded findings (direct file reads; the brand book's 30 contrast ratios were independently recomputed and all match). MEDIUM for competitor precedent (official docs fetched for Clerk and Ory; search-verified for Keycloak, Auth0, Devise; LOW for Authelia, which came from mirrors and blogs). Web-sourced claims are tagged by the confidence seam: unverified search = LOW, cross-checked = MEDIUM.

"The brand book" means the signed-off v2.0 reference copy (`brand/`: `BRAND.md`, `brand.json`, `tokens.json`, `assets/`). It is not yet inside the `milestone/v1.51-brand-identity-adoption` worktree; landing it is BPOL-02 below.

---

## 1. Load-bearing repo facts (these shape every requirement)

| # | Fact (evidence) | Consequence for the milestone |
|---|-----------------|-------------------------------|
| F1 | **Visible output has three ownership lanes.** (a) Lib-owned admin copy is hard-coded English with zero Gettext calls (`lib/sigra/admin/live/*.ex`, `lib/sigra/admin/components.ex`); it reaches every adopter on `mix deps.update`. (b) Generated template copy (`priv/templates/sigra.install/**`) reaches new installs and hand-merged upgrades only; core uses `dgettext("sigra", ...)` with the English text as the msgid, yet has 67 raw-literal `put_flash` calls, and `organizations/**` has 0 `dgettext` calls. (c) Host-owned CSS and logos (`sigra_admin.css`, `sigra_auth.css`, `admin/sigra-logo-primary*.svg`) are copied once at install; neither `Sigra.Doctor` nor `mix sigra.upgrade` detects staleness. | Lib markup can outrun an adopter's old CSS. New lib markup must degrade without new CSS (the book's "word first, mark second" rule is exactly that), and CSS changes must be additive. Copy changes need a per-lane changelog, because lane (a) changes land on adopters silently. |
| F2 | **`Sigra.Branding.Profile` defaults (lib) differ from the book's neutrals.** Accent `#c2410c` equals Kiln. But background `#f7f4ee` vs Paper `#F7F3EE`, text `#171717` vs Soot `#1F1A17`, muted `#6b6258` vs `#5F554D`, border `#ded8cf` vs `#DDD3C8`, dark bg `#171614` vs Char `#17120F`, dark text `#f4f1eb` vs Chalk `#F3EEE8`. | Moving these defaults silently shifts every adopter who never pinned colors, via `deps.update`. Default to freezing them (decision in BPOL-05); adopters with explicit tokens are unaffected. |
| F3 | **Three copies of generated CSS.** `sigra_admin.css` is byte-identical across template, golden fixture and `test/example`. `test/example/priv/static/assets/sigra_auth.css` differs from the template by 903 diff lines (the known template-drift problem). | A before/after diff is meaningless until parity is restored. BGEN-01 comes before any visual edit. |
| F4 | **The book presumes capabilities the product lacks.** There is no Suspended state, no admin unlock or unsuspend action (only auto-expiring `locked_at`), and `needs_review` is `locked + deletion_scheduled` (`lib/sigra/admin.ex`). `user_show_live.ex:385` already says "unlock below" with no such control. The "seven days" Unconfirmed rule is, per the book, only a proposal. | The milestone is words and visuals only. Do not build the missing states or actions. Fix copy that over-promises. |
| F5 | **Vocabulary is already enforced, for admin only.** `test/sigra/admin/glossary_test.exs` scans 9 admin files; generated templates are explicitly out of scope there (D-08) and contain 38 "Log in/Log out" literals (templates, emails, `error_handler.ex`, `user_auth.ex`). Route paths such as `/users/log_in` and helpers such as `log_in_url` are API surface. | The book's glossary and `guides/reference/admin-glossary.md` mostly agree. Extend enforcement to templates with its own list; never touch route paths. |
| F6 | **Admin times carry no zone.** `activity_value/1` renders `%Y-%m-%d %H:%M` (`components.ex:1199`). The book requires "2:07 PM UTC" with the zone on the same line. | One shared helper is a single choke point: cheap to fix, visible everywhere. |
| F7 | **A catalog already exists.** `/admin/_design` (`test/example/lib/example_web/live/admin/design_gallery_live.ex`, 1,474 lines, static assigns, dev-only), 115 Playwright baseline PNGs (recapture is CI-native only), 4 admin screenshots in `guides/assets/`. v1.50 lessons say discount baseline machinery. | Freeze these as the "before" set by commit ref. Extend the gallery; do not adopt a new framework mid-rebrand. |
| F8 | **Package/docs surfaces.** `mix.exs` sets `favicon: "brandbook/favicon.svg"`, no `logo:`; package `files:` excludes `brand*/`; `before_closing_head_tag` injects only Mermaid CSS; the README still names the demo "Vaultr" and pins `~> 1.5.0`. The book's own ExDoc stylesheet is documented as never run in a real ExDoc build. | Hex renders the README from the package tarball, so relative image paths into `brand/` are expected to break (not yet verified). Use absolute URLs and verify in a real `mix docs` + `mix hex.build` run. |
| F9 | **SEED-010 is partly stale.** Auth core templates already use semantic `sigra-auth-*` classes (`test/sigra/install/auth_ui_contract_test.exs`). Residual daisyUI literals: about 40 matches in 5 `organizations/**` templates (`organization_members_live`, `organization_settings_live`, `organizations_live/index`, `.../new`, `org_switcher`), 17 `btn btn-primary` literals in demo pages (`test/example/lib/example_web/{controllers,live}`), and `lib/sigra/admin/components.ex:1099`. The seed's product decision (a/b/c) was de facto made: (c) a neutral token layer adopters theme. | Record that decision, then finish the residue. Do not re-open the philosophy. |
| F10 | **Token docs point at the retired book.** `guides/reference/admin-token-reference.md` maps `--sg-*` to `brandbook/tokens.json` raw names (`ember-*`); `--sg-logo-rail-*` tokens carry the retired rail metaphor. | Names stay (compat). Re-point the documentation; mark `rail` tokens deprecated in docs only. |
| F11 | **ID-collision hazard.** v1.38 shipped "brand v2 / D4 Linked Rail" and used `BRAND-` requirement IDs; book v2.0 retires that mark. | Use distinct prefixes (below) and say "book v2.0 (Kiln)" in prose. |
| F12 | **Contrast is verified and thin in one place.** All 30 pair ratios (15 ids x light/dark) recompute to the stated two decimals. Thinnest margin: status word on a selected row, light, 4.61 vs the 4.5 minimum. `Sigra.Branding.Contrast.contrast_ratio/2` already exists in lib. | A pure-Elixir contrast test against the implemented CSS values is cheap and exact; approximate "close to Kiln" tokens would fail it. |

---

## 2. Precedent: how comparable projects handle brand adoption, copy and assets

| Project | Theming / brand mechanism | Copy mechanism | Enumeration posture | Lesson for Sigra | Conf. |
|---------|---------------------------|----------------|---------------------|------------------|-------|
| **phx.gen.auth** (Phoenix 1.8.15 templates, read locally) | None: generated code is yours | Plain English literals, no Gettext; says "Log in" | `"Invalid email or password"`; magic link: "If your email is in our system, you will receive instructions for logging in shortly." | Sigra's "sign in" vocabulary is a deliberate divergence the book already flags. Keep the same non-specific error wording. | HIGH |
| **Devise** | `rails g devise:views` (owned views); locale YAML | i18n keys in locale files | `config.paranoid = true` makes recovery and confirmation answers identical; the project's own wiki says it does not stop manual enumeration and timing attacks on sign-in remain | Keyed copy plus an enumeration switch is table stakes. Be as honest about limits as Devise is (Sigra has a known duplicate-registration timing todo). | MEDIUM |
| **Clerk** | `appearance` prop (`variables` for tokens, `elements` for DOM styling, layout, base theme) | `localization` prop overrides any string; docs mark it "experimental and may change or be removed without notice"; find keys by reading the English file | n/a | Even a funded vendor does not promise copy-key stability. Sigra should promise only what a contract test pins. | MEDIUM (official doc fetched) |
| **Auth0** | Universal Login branding (logo, colors) plus custom text per prompt, screen and text key via Dashboard or `PUT /api/v2/prompts/{prompt}/custom-text/{language}` | Whole-prompt replace: the set call replaces all custom text for that prompt | Not checked | Addressable keys are standard. The replace-all trap argues against building a runtime override map now. | MEDIUM |
| **Ory Kratos** | UI nodes plus messages | Every message has a fixed 7-digit numeric `id`, default English `text` and `context`; docs state the id "will not change and can be used to translate the message or use your own message content"; some ids are reused, so context matters | Credential-failure messages have ids; exact wording not verified | The strongest precedent for a copy contract: stable identity separated from wording. In Sigra the msgid is the wording, so the contract must pin an inventory, not trust msgids. | MEDIUM (official doc fetched) |
| **Keycloak** | Theme types with `parent` inheritance; override only the keys you list | `messages_<locale>.properties` overrides | Not checked | Inherit-and-override limits upgrade work to the keys you override; even so, the 24.0 account console moved its parent theme v2 to v3 (custom themes had to migrate) and overridden templates must be diffed against the new base. Sigra is a copy-and-edit model, so it owes adopters an explicit diff note per release. | MEDIUM |
| **Authelia** | Closed set of overridable assets (`favicon.ico`, `logo.png`, locales) via a flat `asset_path`; selectable theme presets (light, dark, grey, auto per mirrored docs); no arbitrary CSS | Locale files | Not checked | A narrow validated token surface is a legitimate stance. `Sigra.Branding.Profile` already is one; do not widen it. | LOW (mirrors/blogs) |
| **Keycloakify** | Storybook stories for every login page, runnable outside a real Keycloak; docs list which pages are covered | n/a | n/a | "Every auth page in isolation, in every state" is the established before/after pattern. Sigra already has the admin half (`DesignGalleryLive`); the auth and email half is the gap. | MEDIUM |

---

## 3. Feature Landscape

Area codes: **CP** on-screen copy contract, **TH** adopter theming and whitelabel surviving a rebrand, **CT** before/after catalog, **AS** brand assets in package docs.

### Table Stakes (missing = the rebrand is unsafe or looks half-done)

| Feature | Area | Why Expected | Complexity | Notes / dependency on existing |
|---------|------|--------------|------------|--------------------------------|
| One written vocabulary and voice rubric, enforced by a test | CP | Devise and Ory both centralize copy; Sigra already has this for admin | LOW | Extend `glossary_test.exs`; reconcile the book's 18 key terms with `admin-glossary.md` |
| Enumeration-boundary responses identical across branches (sign-in failure, reset request, magic-link request, duplicate registration, resend confirmation) | CP | Devise `paranoid`, phx.gen.auth, Ory and the book all require it; the book says "keep sign-in errors vague on purpose" | MEDIUM | Existing controller tests assert pieces (`session_controller_test.exs`, `registration_live_test.exs`, `auth_test.exs:1033`); add one canonical list and branch-equivalence assertions with a positive control (a deliberately specific string must fail) |
| Copy changes are reviewable diffs | CP | Lane (a) copy ships silently on `deps.update` | LOW | Committed, sorted copy inventory per lane; changelog "Visual and copy changes" section |
| A rename table for any msgid or string that changes | CP | Adopters who translated `sigra` domain strings would otherwise lose them silently on re-merge; Keycloak's upgrade guide does the same | MEDIUM | Old msgid to new msgid, shipped in the upgrade guide; golden rebless |
| Operator errors specific, ending in a next action | CP | The book and `admin-glossary.md` agree; the admin is trusted staff | LOW | Lint empty and error states for an action |
| Public names frozen, values free: CSS custom properties, `sg-*` and `sigra-auth-*` classes, `Profile` keys, config keys, route paths, Gettext domain, DOM ids and URL params that specs use (`needs_review`) | TH | The milestone's hard constraint; Keycloak parent-theme and Clerk `variables` precedent | LOW | Add-only ratchet test on the name inventory |
| Explicit adopter Branding config renders byte-identically before and after | TH | The whole point of whitelabel; `dark_accent_source/1` already treats explicit values as authority | LOW | Fixture of 2-3 legacy profiles (explicit, partial, defaults) asserted unchanged |
| Light and dark parity with verified contrast for Sigra-owned tokens | TH | The book defines 15 pair ids x 2 themes | MEDIUM | `Sigra.Branding.Contrast` plus parse of the implemented CSS; axe in the real DOM (existing gate) |
| Documented ownership lanes (what `deps.update` changes vs what hosts must re-copy) | TH | Keycloak and Authelia both document override scope; here it is the central risk (F1) | LOW | Section in `guides/introduction/contract.md` plus the upgrade note |
| Logo light/dark slots and directional `dark_logo_url` fallback keep working | TH | Shipped in PR #238; a rebrand must not regress it | LOW | `test/sigra/branding_test.exs` stays green untouched |
| Deterministic, text-diffable rendering of every in-scope screen on realistic seeded data | CT | Storybook-style catalogs (Keycloakify) and golden fixtures are the norm; v1.50 proved pixel baselines are the wrong default | MEDIUM | Normalized rendered HTML snapshots under `test/fixtures/`; seeded personas already exist in the example app |
| "Before" captured and frozen before the first visual edit | CT | A before/after with no before is a claim | LOW | Commit ref plus manifest; reuse `/admin/_design`, 115 PNGs, `guides/assets/*.png` |
| Template, golden and example copies provably identical | CT | F3; golden diffs must be the only moving part | LOW | Parity test per asset; fix `sigra_auth.css` drift first |
| README header with light/dark logo, approved one-liner and tagline | AS | Every serious Hex package has it | LOW | `brand/assets/readme/header-snippet.html` uses `<picture>`; needs absolute URLs |
| ExDoc favicon, logo and code colors in light and dark | AS | The book ships `docs/sigra-exdoc.css` | MEDIUM | Must be verified in a real `mix docs` build (the book says it was not) |
| Licence texts and provenance for every shipped font or asset | AS | OFL 1.1 requires it | LOW | `brand/assets/fonts/OFL-*.txt`; hash manifest |

### Differentiators (where Sigra can lead; all align with Core Value: DX on the rough edges)

| Feature | Area | Value Proposition | Complexity | Notes |
|---------|------|-------------------|------------|-------|
| Hash-pinned brand book with a drift test | AS/TH | Brand rules become a checked dependency, not a PDF | LOW | sha256 manifest of `BRAND.md`, `brand.json`, `tokens.json`, each asset |
| Copy contract keyed by ownership lane | CP | Copy stability promised only where tested (Ory's idea, adapted to msgid-as-text) | LOW-MED | Lane (a) admin literals, (b) templates, (c) emails |
| "Honest limits" rule: no doc or test claims more than is proven | CP | The book's first value is Honest; matches the open timing-oracle todo | LOW | Wording review of "enumeration-safe" claims |
| Status as word-first component with five shapes distinguishable without color | CP/TH | Accessibility plus graceful degradation (works with old host CSS) | MEDIUM | New `status_mark` in `components.ex`, inline SVG, `data-status`; Suspended drawn but unwired |
| Exact time with zone from one helper | CP | Support staff read times aloud; the book's "Exact" value | LOW | Replace `activity_value/1` output; narrow-column test |
| Pure-Elixir contrast test sourced from `brand.json` pair ids, run against implemented CSS | TH | Zero-browser, exact, fails on token drift | LOW | Reuses `Sigra.Branding.Contrast.contrast_ratio/2` |
| Brand-lane assertion: Sigra's name and logo never appear on host-user screens or emails | TH | Enforces the book's "Yours" value; no other auth library states this | LOW | Refute test over the before/after catalog |
| Before/after text-diff report (wording changes highlighted per screen) | CT | Replaces human PNG review; fits "zero-human UAT" | MEDIUM | Script over normalized HTML snapshots |
| Gallery extended to generated auth pages and emails | CT | Closes the "generated auth has browser coverage on ONE surface" gap from the v1.46 audit | MEDIUM | `DesignGalleryLive` is admin-only today |
| Doctor check for stale generated CSS or logo | TH | Closes F1's silent-staleness hole for every future UI change | MEDIUM | Version marker comment plus `Sigra.Doctor` check |
| Name-clearance record | AS | States exactly what was and was not checked | LOW | Documentation, built from the book's "Not checked" paragraph |

### Anti-Features (commonly requested, problematic here)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Runtime copy map or admin-managed copy in `Profile` | Clerk and Auth0 offer string overrides | SEED-003 forbids it until its triggers fire; Clerk marks it experimental; Auth0's set-call replaces everything; adds public API | Gettext plus generated templates (current model) |
| Renaming tokens, classes, modules, config keys or routes to the new brand ("rail" to "kiln") | Naming consistency | Breaks adopter overrides, specs and bookmarks; violates the milestone constraint | Frozen names; deprecate `--sg-logo-rail-*` in docs only |
| Sigra logo, name or footer on host-user screens or emails | Brand exposure | Contradicts the book's "Yours" value and whitelabel promise | A plain-text "Authentication by Sigra" footer recipe the host adds by editing its own template; no new `Profile` field |
| Silently moving `Profile` defaults to the book's neutrals | "Match the book" | Shifts every default-token adopter on `deps.update` (F2) | Freeze, document, revisit under an explicit opt-in |
| Growing the Playwright baseline matrix or hand-recapturing PNGs on darwin | Familiar verification | v1.50: valid pairs 0; baselines are CI-native only; 115 PNGs go stale on any token change | Text snapshots, existing gallery, one deliberate CI-native recapture or retirement |
| Adopting Storybook or another catalog framework now | "Storybook-style" is the stated direction | A new dependency in the middle of a rebrand; `DesignGalleryLive` already exists | Extend the gallery; decide the framework under MILESTONE-ARC item 3 |
| Shipping web-font binaries into every adopter repo by default | The book specifies Instrument Sans and Red Hat Mono | Dependency, licence-file and size burden in other people's repos; the book itself calls it the maintainers' call | New additive `--sg-font-sans`/`--sg-font-mono` tokens defaulting to a system stack, an opt-in snippet, fonts loaded on Sigra-owned surfaces only |
| Building Suspended, unlock, unsuspend or the 7-day Unconfirmed rule to match the book | The book's job statement lists them | New features and a `needs_review` semantic change; breaks "words and visuals only" | Render only existing states; file a seed; correct "unlock below" copy to the truth |
| Terminology sweep over all ~40 guides | Consistency | Large churn, low value, lots of historical text | Lexicon lint (Do-not-say list) over README and guides; vocabulary pass on primary-path guides only |
| Dark transactional email redesign | The book draws dark emails | Mail-client support is inconsistent; `auth-branding.md` already specifies email as light-only | Light email copy pass; defer dark |
| LLM-judge voice panel | "Automated voice review" | v1.50 cut the adversarial panel machinery as inefficient | Deterministic regex lint plus the committed copy inventory |
| Trademark symbol or registration claim; "certified", "compliant", "bank-grade" claims; announcement before clearance record | Launch polish | The book says none was searched; "Do not say" list | Clearance record now; announcement last; no symbol |
| Re-skinning the Tasklane demo host app with Sigra's brand | "Demo should look like Sigra" | Tasklane is the host-brand exemplar (the book uses it for the host sign-in and email drawings) | Brand only Sigra-owned chrome (admin shell, demo bar, README) |

---

## 4. Feature Dependencies

```
BPOL-01/05 (policy + decisions) ──> everything below
BPOL-02 (brand/ landed + hash pin) ──> BTOK-01/02/04/05, BPUB-*
BPOL-03 (frozen-names ratchet) ──> BTOK-01, BOPS-02, BAUTH-01   (additive-only guard)
BCOPY-01..04 (vocabulary, lint, enumeration, inventory) ──> BOPS-04/05, BAUTH-03/04

BGEN-01 (CSS parity) ──> BGEN-02 (determinism) ──> BGEN-03/04 (frozen "before")
                                                       └──> [first visual edit allowed: BTOK-01]
BGEN-05 (gallery: auth, email, status mark) ──> BOPS-02, BTOK-03
BTOK-01 (token values) ──> BTOK-02 (pairs) ──> BTOK-03 (axe) ──> BGEN-08 (recapture or retire baselines)

BTOK-01 + BOPS-02 + BCOPY-* ──> BOPS-01 (operator slice) ──> BOPS-06 (all admin) 
BTOK-01 + BCOPY-* ──> BAUTH-01..04 (auth + email; parallel to BOPS-06)
BAUTH-03 (msgid renames) ──> BREL-01 (rename table in upgrade note)
BTOK-04/05 (logo, favicon) ──> BPUB-01/02
BOPS + BAUTH done ──> BPUB-04 (screenshots) ──> BREL-02 (announcement, last)

Conflicts:
BTOK-09 (move Profile defaults) ──conflicts──> BPOL-03 (frozen defaults)
BGEN-07 (Storybook-style framework) ──conflicts──> BGEN-05 (extend gallery) if done in this milestone
BOPS-09 (suspend/unlock features) ──conflicts──> BPOL-01 (words and visuals only)
```

### Dependency notes

- **BGEN-01 before everything visual.** Without byte parity between template, golden and example CSS, a golden diff mixes brand edits with pre-existing drift.
- **BPOL-03 before BTOK-01.** The ratchet is what lets 100+ token values change while names cannot.
- **BOPS-02 must degrade without new host CSS** (F1): inline-SVG mark plus the word, `data-status` for hosts that want to style it.
- **BAUTH-03 feeds BREL-01.** The rename table can only be written once the strings are final.
- **BGEN-08 follows BTOK-01.** Any token value change turns the CI-native `design_gallery` baselines red; plan the recapture-or-retire step instead of discovering it in CI.

---

## 5. The "one operator job end to end first" slice

### Recommendation: "Find a user who can't sign in and see why"

The book names this job verbatim as the admin persona's job ("A user says they can't sign in. Pull up their record and see what is going on"). In the repo it is the Support-investigator lens (`guides/reference/admin-persona-jtbd-rubric.md`, ledger cell `flow-support-investigator`).

**Slice boundary (3 LiveViews plus shared helpers):**

| Step | Screen | File (lines) | Brand elements it exercises |
|------|--------|--------------|-----------------------------|
| 1. Find by email | Users list | `lib/sigra/admin/live/users_index_live.ex` (645) | status word and mark, needs-review triage label, empty and filtered-empty copy |
| 2. See why | User detail | `lib/sigra/admin/live/user_show_live.ex` (412) | status headline, summary alert, UTC time, sessions preview, honest "unlock" copy |
| 3. Act | Sessions + revoke | `lib/sigra/admin/live/user_sessions_live.ex` (305) | destructive confirm that names the user and the consequence, success copy |
| Shared | Helpers and shell | `components.ex` (`activity_value/1`, `notice`, `empty_state`, status pill) and generated `admin/components/admin_shell.ex` | typemark swap, theme tokens, selected-row rule |

Next job after the slice (wave 2): per-user audit (`audit_user_live.ex`, 425 lines), because the book's actor / effective-user columns and plain-sentence rows are a layout change, not a wording change.

### Why this job and not the others

| Candidate | Brand novelty covered | Existing "before" evidence | State model exists? | Size | Verdict |
|-----------|----------------------|---------------------------|---------------------|------|---------|
| **Find a user who can't sign in** | Status word + mark, triage label, UTC, specific operator errors, destructive confirm | `flow-support-investigator` spec, `admin-user-list/detail` screenshots in `guides/assets/`, gallery boards | Yes: `confirmed_at`, `locked_at`, `deleted_at` give Active, Unconfirmed, Locked, Deleting | ~1,360 lines + helpers | **Pick** |
| Investigate an audit event | Actor vs effective user, sentence rows, UTC | Audit specs and screenshot | Yes | 756 lines + `audit/*` query code; layout-heavy | Second |
| Review risky users from overview | Triage label only | Overview spec | Yes | 129 lines | Too thin: covered as a by-product of the pick |
| Customize auth branding (`branding_live.ex`) | Host-brand lane, "Sign-in preview" | Branding live tests | Yes | 646 lines | Wave 2: adopter-facing, but the book says Sigra's brand must not appear on what it previews |
| Revoke one session | Destructive confirm only | Sessions spec | Yes | 305 lines | Subset of the pick |

### What the slice proves (acceptance for BOPS-01)

1. Word + mark appears in list and detail for Active, Unconfirmed, Locked, Deleting; shapes differ without color; no new host CSS required.
2. Every time on the three screens carries its zone on the same line.
3. Revoke confirm names the user's email and the consequence; every empty and error state ends with an action.
4. Glossary/lexicon lint and enumeration-contract tests green; copy inventory diff reviewed.
5. Before/after normalized-HTML diff for the three screens reviewed in both themes; contrast-pair and axe checks green; golden and example CSS parity green.
6. It reveals the real cost of the other screens before Phase 4 fans out (gate for BOPS-06 and BAUTH).

### Do not include

Suspended state, unlock or unsuspend actions, the 7-day Unconfirmed rule (changes `needs_review` and `Query.summary_stats`), user-id hiding rework. Where the book assumes them, correct the copy to what the product does (F4).

---

## 6. MECE requirement categories (sized for 5 phases)

**MECE rule:** each requirement belongs to exactly one category, decided by (artifact owner x activity). Policy and tests with no visible change: BPOL, BCOPY. Harness: BGEN. Visual primitives: BTOK. Per-surface application split by audience: BOPS (operators) and BAUTH (end users and email). Surfaces outside the running app: BPUB (artifacts) and BREL (narrative and claims). Prefixes are distinct from earlier milestones (`BRAND-`, `AUTHUI-`, `DOC-`, `UX-` are taken).

Priority: **M** must-have, **S** should-have (cut first), **D** defer. Complexity: L/M/H.

### BPOL: Compatibility policy, pinning, clearance (Phase 1)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BPOL-01 | Compatibility policy (ADR + section in `guides/introduction/contract.md`): frozen list (F-names in table stakes), changeable list, ownership-lane table, SemVer treatment of copy and visual changes | M | L | `contract.md` |
| BPOL-02 | `brand/` reference copy lands in the repo with a sha256 manifest and a drift test; `brandbook/` untouched | M | L | none |
| BPOL-03 | Add-only ratchet test: CSS custom-property names, `sg-*`/`sigra-auth-*` classes, `Profile` keys and defaults, Gettext domain, route helpers | M | L | existing CSS, `Profile` |
| BPOL-04 | Name-clearance record (what the book did and did not check; no trademark claim; decision log) | M | L | brand "Not checked" text |
| BPOL-05 | Decision records: `Profile` defaults (recommend freeze), fonts in generated admin (recommend tokens + opt-in), SemVer level (recommend minor with a "Visual and copy changes" section), msgid renames (recommend rename table) | M | L | BPOL-01 |
| BPOL-06 | Upgrade-note skeleton: which lane auto-updates, what hosts re-copy | S | L | BREL-01 |
| BPOL-07 | Docs-only deprecation notes for `--sg-logo-rail-*` | D | L | none |

### BCOPY: Copy contract (Phase 1; applied in Phase 4)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BCOPY-01 | Reconciled vocabulary table: book key terms x `admin-glossary.md`, with explicit rulings on "Admin (operator)", "Review accounts" vs "Review users" (`components.ex:532`), "Deletion scheduled" vs "Deleting", "Confirmed" vs "Active", "Confirm it's you again" (recommendation, not shipped) | M | L | `admin-glossary.md` |
| BCOPY-02 | Drift test extended: new banned terms and the book's Do-not-say lexicon over the 9 admin files, over generated templates (own list: "log in/out" banned there), and lexicon-only over README and top guides | M | M | `glossary_test.exs` |
| BCOPY-03 | Enumeration-boundary contract: one canonical list; branch-equivalence assertions (existing vs unknown email) with a positive control; copy rewrites cannot change these strings without editing the test | M | M | existing controller and LiveView tests |
| BCOPY-04 | Committed copy inventory per ownership lane (sorted strings), so every copy change is a reviewable diff | M | L | BPOL-01 |
| BCOPY-05 | Honest-claims pass: docs and tests do not claim enumeration safety beyond what is proven (timing todo cited) | S | L | `2026-11-13-duplicate-registration-timing-oracle.md` |
| BCOPY-06 | Admin-managed copy, locale-aware routing, RTL, per-organization wording | D | H | SEED-003 triggers unmet |

### BGEN: Deterministic output and before-screen catalog (Phase 2)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BGEN-01 | Template and example asset parity: fix `sigra_auth.css` drift (903 diff lines) and add a parity test for every copied asset | M | L | F3 |
| BGEN-02 | Determinism: double install is byte-identical; `mix sigra.fixture.rebless_golden --check` green under pinned `phx_new` 1.8.8; brand diffs reviewable by directory group | M | M | `golden_diff_test.exs`, rebless task |
| BGEN-03 | Before catalog, text: normalized rendered-HTML snapshots for each in-scope screen x state x theme on seeded personas, including generated auth pages and emails | M | M | example seeds, EMAIL-RAILS previews |
| BGEN-04 | Before catalog, visual: freeze `/admin/_design`, the 115 baselines and `guides/assets/*.png` by commit ref; no darwin recapture | M | L | F7 |
| BGEN-05 | Extend `DesignGalleryLive` with auth-page, email and status-mark states (dev-only); no new framework | M | M | BGEN-03 |
| BGEN-06 | Before/after text-diff report script | S | M | BGEN-03 |
| BGEN-07 | Storybook-style catalog framework; cutting old UI-process jobs on main | D | H | MILESTONE-ARC item 3 |
| BGEN-08 | Baseline disposition after token change: one deliberate CI-native recapture or explicit retirement; never hand-edit PNGs | M | M | BTOK-01 |

### BTOK: Tokens, fonts, logo, favicon (Phase 3)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BTOK-01 | Token value migration table (old to new, light and dark) from `brand/tokens.json`, applied to `sigra_admin.css` and `sigra_auth.css` templates; names unchanged; goldens updated | M | M | BPOL-03, BGEN-04 |
| BTOK-02 | Contrast-pair test: 30 pairs from `brand.json` `contrastPairs`, computed with `Sigra.Branding.Contrast` against the implemented CSS values | M | L | BTOK-01 |
| BTOK-03 | Real-DOM contrast and a11y (existing axe gate) over the catalog in light and dark | M | M | BGEN-05 |
| BTOK-04 | Logo: v2 lockup light and dark replace the rail SVGs under the same filenames (`admin/sigra-logo-primary{,-dark}.svg`); fix `admin_shell.ex` labels; remove stray rail files from the example | M | L | BPOL-02 |
| BTOK-05 | Favicon: ExDoc and example use the book's `icon/` files; a 16/32 px render hash check (book: never viewed at 16 to 24 px) | M | L | BPOL-02 |
| BTOK-06 | Fonts per BPOL-05: additive `--sg-font-sans`/`--sg-font-mono` tokens with system default; Sigra-owned surfaces load Instrument Sans and Red Hat Mono; OFL texts wherever binaries ship | M | L | BPOL-05 |
| BTOK-07 | Additive status, selected-row and current-tab tokens | S | M | BOPS-02 |
| BTOK-08 | Rewrite `admin-token-reference.md` against `brand/tokens.json` names | S | L | BTOK-01 |
| BTOK-09 | Doctor check for stale generated CSS or logo (version marker) | S | M | F1 |
| BTOK-10 | Move `Profile` defaults to the book's neutrals | D | M | BPOL-05 (default: freeze) |

### BOPS: Admin and operator UI (Phase 4, waves 1 and 2)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BOPS-01 | Operator slice: "find a user who can't sign in and see why" (section 5) | M | H | BTOK-01, BOPS-02..05, BGEN-05 |
| BOPS-02 | `status_mark` component plus one-status-per-user precedence from existing columns (Deleting, Locked, Unconfirmed, Active); Suspended drawn in the catalog, unwired | M | M | BPOL-03 |
| BOPS-03 | Single time helper rendering "2:07 PM UTC" style with zone on the same line | M | L | `components.ex:1199` |
| BOPS-04 | Destructive-confirm, empty and error copy per rubric; correct "unlock below" to the truth | M | L | BCOPY-01..03 |
| BOPS-05 | Label rulings applied ("Admin" not "Admin (operator)"; users not accounts; status words) | M | L | BCOPY-01 |
| BOPS-06 | Remaining admin screens: overview, audit index and per-user, organizations, branding workbench ("Sign-in preview"), shell; each with a before/after catalog entry | M | H | BOPS-01 gate |
| BOPS-07 | Selected-row 2 px rule and current-tab square (additive CSS) | S | M | BTOK-07 |
| BOPS-08 | "Needs an admin" lead panel with the unconfirmed-over-seven-days rule | D | M | changes `needs_review` |
| BOPS-09 | Suspend, unsuspend and admin unlock actions plus a Suspended state | D | H | new feature, own milestone |

### BAUTH: Auth pages and emails (Phase 4, wave 3; SEED-010 and SEED-003)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BAUTH-01 | SEED-010 residue: `organizations/**` (5 files) and `org_switcher` to `sigra-auth-*` semantic classes; demo pages (17 literals); `components.ex:1099`; extend `@modern_auth_templates`; record the a/b/c decision | M | M | `auth_ui_contract_test.exs` |
| BAUTH-02 | Brand-lane test: no Sigra name or logo in rendered auth screens and emails; footer recipe documented | M | L | BGEN-03 |
| BAUTH-03 | "Sign in" vocabulary across templates and emails (38 literals, `error_handler.ex`, `user_auth.ex`); route paths untouched; rename table; golden rebless | M | M | BCOPY-02, BPOL-05 |
| BAUTH-04 | SEED-003 audit and ratchet: inventory raw user-facing literals (67 core flashes, 0 `dgettext` in `organizations/**`), allowlist that may only shrink | M | M | BCOPY-04 |
| BAUTH-05 | Wrap core raw literals in `dgettext("sigra", ...)`; generate the `.pot` and document `mix gettext.extract`/`merge` and locale setup | S | M | BAUTH-04 |
| BAUTH-06 | Email copy pass: action first, then what happens if ignored; snapshots | S | M | BGEN-03 |
| BAUTH-07 | Organization-template i18n, dark email redesign, admin-managed copy, RTL, `<.button type>` forward-compat (SEED-004) | D | H | separate seeds |

### BPUB: README, HexDocs, Hex assets (Phase 5)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BPUB-01 | README header (`<picture>` light and dark), tagline, descriptor, approved one-liner; demo name Vaultr to Tasklane; absolute asset URLs; lexicon lint passes | M | L | BTOK-04, BCOPY-02 |
| BPUB-02 | ExDoc: favicon path, `logo:` (verify rendered size), `sigra-exdoc.css` through the head hook with light and dark; verified in a real `mix docs` build | M | M | BTOK-05 |
| BPUB-03 | Hex package `description` and links use approved text; confirm Hex has no logo field; `files:` unchanged unless ExDoc needs it | M | L | `mix.exs` |
| BPUB-04 | Brand assets and refreshed screenshots wired through `assets: %{"guides/assets" => "assets"}`; social card referenced; GitHub social preview is a manual repo setting (single operator step) | M | L | BOPS, BAUTH done |
| BPUB-05 | Vocabulary pass on primary-path guides (getting-started, installation, demo-showcase, `auth-branding.md`, `login-and-logout.md`) | S | L | BCOPY-02 |
| BPUB-06 | Full guide sweep and historical launch docs | D | M | none |

### BREL: Release narrative and claims (Phase 5, last)

| ID | Requirement | Pri | Cx | Depends on |
|----|-------------|-----|----|-----------|
| BREL-01 | Upgrade guide: lane table, msgid rename table, token value table; conventional-commit scopes so release-please writes the changelog | M | L | BAUTH-03, BTOK-01 |
| BREL-02 | Announcement draft, written last; approved descriptions only; passes the lexicon lint; no trademark symbol | M | L | everything |
| BREL-03 | Trademark claim, look-alike and register search | D | M | external search; not this milestone |

**Totals:** 37 must-have (BPOL 5, BCOPY 4, BGEN 6, BTOK 6, BOPS 6, BAUTH 4, BPUB 4, BREL 2; most are Low), 10 should-have, 9 defer. Must-haves by phase: P1 9, P2 5, P3 7, P4 10, P5 6.

### Phase map

| Phase | Categories | Gate to leave the phase |
|-------|-----------|--------------------------|
| 1. Policy and copy contract | BPOL, BCOPY | Ratchet, hash pin, lint and enumeration tests green on unchanged output; five decisions recorded |
| 2. Deterministic output and before catalog | BGEN-01..06 | Parity and determinism green; "before" frozen by commit ref |
| 3. Tokens, fonts, logo, favicon | BTOK, BGEN-08 | 30 pairs and axe green both themes; baseline disposition decided; one human sign-off on logo distinctness and 16 to 24 px favicon legibility (the book calls these taste calls) |
| 4. Words and layout | BOPS, BAUTH | Wave 1 slice accepted before waves 2 and 3 start; copy inventory and golden diffs reviewed |
| 5. Public surfaces, announcement last | BPUB, BREL | Real `mix docs` and `mix hex.build` render verified; announcement only after clearance record |

**Phase 4 has 10 of the 37 must-haves but both High-complexity items and the widest file footprint** (8 admin LiveViews, `components.ex`, about 25 generated templates and their golden copies). Keep the wave gate. If capacity is short, cut S items first (BAUTH-05/06, BOPS-07), not the slice; do not pull BAUTH-03 out, because "sign in" is the book's most visible rule.

---

## 7. MVP Definition

### Launch with (v1.51)

- [ ] Policy, ratchet, hash pin, clearance record, five decisions (BPOL-01..05): everything else depends on them
- [ ] Copy contract with enumeration-boundary tests and committed inventory (BCOPY-01..04)
- [ ] Parity, determinism, frozen before-catalog, gallery extension (BGEN-01..05, 08)
- [ ] Token values, contrast pairs, axe, logo, favicon, font decision (BTOK-01..06)
- [ ] Operator slice, then all admin screens (BOPS-01..06)
- [ ] Auth residue, brand-lane test, "sign in" vocabulary, raw-literal ratchet (BAUTH-01..04)
- [ ] README, ExDoc, Hex metadata, assets (BPUB-01..04) and upgrade note plus announcement (BREL-01..02)

### Add after validation (v1.51.x or next milestone)

- [ ] Doctor stale-asset check (BTOK-09): trigger is the next lib markup change that needs new CSS
- [ ] Wrap all raw literals and generate the `.pot` (BAUTH-05): trigger is an adopter asking for a locale
- [ ] Before/after diff report as a standing tool (BGEN-06)
- [ ] Selected-row rule (BOPS-07)

### Future consideration

- [ ] Suspend, unsuspend, unlock, "Needs an admin" panel (BOPS-08/09): new product capability
- [ ] Storybook-style framework and cutting old UI-process jobs (BGEN-07)
- [ ] Admin-managed copy, RTL, per-organization wording, dark email (BCOPY-06, BAUTH-07)
- [ ] `Profile` default move (BTOK-10); trademark claim (BREL-03)

## 8. Feature Prioritization Matrix

| Category | User value | Cost | Priority |
|----------|------------|------|----------|
| BPOL policy, ratchet, pin | HIGH (protects adopters) | LOW | P1 |
| BCOPY enumeration contract and lint | HIGH (security and voice) | MEDIUM | P1 |
| BGEN parity and before catalog | HIGH (makes the rest verifiable) | MEDIUM | P1 |
| BTOK values, pairs, logo, favicon | HIGH (visible identity) | MEDIUM | P1 |
| BOPS slice then breadth | HIGH (operator trust) | HIGH | P1 |
| BAUTH vocabulary and residue | MEDIUM-HIGH | MEDIUM | P1 |
| BPUB README and ExDoc | MEDIUM (evaluators) | LOW-MEDIUM | P1 |
| BREL announcement | MEDIUM | LOW | P1 (last) |
| Doctor stale-asset check, `.pot` generation, diff report | MEDIUM | MEDIUM | P2 |
| Everything marked D | LOW now | HIGH | P3 |

## 9. Decisions to ratify in Phase 1 (recommendations)

1. **`Profile` defaults:** freeze (F2); adopters with pinned tokens are untouched; revisit only behind an explicit opt-in.
2. **Fonts in generated admin:** tokens plus opt-in snippet, system stack default; Sigra-owned surfaces load the book's fonts.
3. **SemVer:** minor release with a "Visual and copy changes" section, because lane (a) copy and markup change for existing adopters.
4. **Msgid changes:** ship a rename table; never rename route paths, helpers or the `sigra` domain.
5. **Suspended and unlock:** out of scope; correct copy that implies they exist.

## 10. Open gaps (MEDIUM or LOW confidence)

- ExDoc `logo:` rendering constraints and whether Hex renders `<picture>` and external image URLs the way GitHub does were not verified; BPUB-02 and BPUB-01 must prove it in a real build.
- The book's ExDoc stylesheet, favicon at 16 to 24 px, Safari and Firefox rendering, and the generated auth and email screens were never viewed running by the book's authors; Phase 3 and 5 own that evidence.
- Authelia and Devise key-level details came from secondary sources; they inform pattern choice only, not any requirement's acceptance.
- Whether CI-native baseline recapture is still required on `main` depends on the open todo to cut UI-process machinery; BGEN-08 must read live CI state at planning time.

## Sources

- Repo files read: `.planning/PROJECT.md`, `.planning/MILESTONE-ARC.md`, `.planning/seeds/SEED-010-auth-pages-daisyui-unbranding.md`, `.planning/seeds/SEED-003-auth-copy-locale-hardening.md`, `.planning/seeds/SEED-004-phx-new-button-forward-compat.md`, `.planning/notes/2026-11-13-v1.50-closeout-lessons-and-cuts.md`, `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md`, `guides/introduction/contract.md`, `guides/recipes/auth-branding.md`, `guides/reference/admin-glossary.md`, `guides/reference/admin-token-reference.md`, `guides/reference/admin-persona-jtbd-rubric.md`, `lib/sigra/branding/profile.ex`, `lib/sigra/branding/contrast.ex`, `lib/sigra/admin/**`, `priv/templates/sigra.install/**`, `test/sigra/admin/glossary_test.exs`, `test/sigra/install/auth_ui_contract_test.exs`, `mix.exs`, `README.md` (HIGH)
- Brand book reference copy: `brand/BRAND.md`, `brand/brand.json`, `brand/tokens.json`, `brand/assets/**`; 30 contrast ratios recomputed independently (HIGH)
- Phoenix 1.8.15 `priv/templates/phx.gen.auth/` (read from the local dependency) (HIGH)
- [Clerk localization prop](https://clerk.com/docs/guides/customizing-clerk/localization.md) and [appearance prop overview](https://clerk.com/docs/react/guides/customizing-clerk/appearance-prop/overview) (MEDIUM)
- [Ory Kratos UI messages](https://www.ory.com/docs/kratos/concepts/ui-user-interface) (MEDIUM)
- [Auth0 text customization](https://auth0.com/docs/universal-login/text-customization) (MEDIUM)
- [Keycloak themes (Red Hat build, 26.2)](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.2/html/server_developer_guide/themes) and [Keycloak 24.0 upgrading guide](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/24.0/html-single/upgrading_guide/) (MEDIUM)
- [Devise paranoid-mode wiki](https://github.com/plataformatec/devise/wiki/How-To:-Using-paranoid-mode,-avoid-user-enumeration-on-registerable) (MEDIUM)
- [Authelia server configuration](https://authelia.com/configuration/miscellaneous/server/) plus mirrored docs (LOW)
- [Keycloakify docs](https://docs.keycloakify.dev) (MEDIUM)
- [phoenix_storybook on HexDocs](https://hexdocs.pm/phoenix_storybook/PhoenixStorybook.html) (LOW: version not confirmed against hex.pm; only relevant to the deferred BGEN-07)

---
*Feature research for: brand-identity adoption, Sigra v1.51*
*Researched: 2026-11-13*
