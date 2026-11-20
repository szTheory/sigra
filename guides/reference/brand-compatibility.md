# Brand and visual compatibility

This guide states what the v1.51 brand identity adoption may and may not change in a hybrid library plus generator, and what an adopter does about it. It is a reference for adopters who want to know whether an upgrade changes what their users see, and for maintainers who need to know what a brand change is allowed to touch.

## Scope and audience

Sigra reaches an application through three channels: library code that updates with `mix deps.update`, templates generated into the host once at install, and host-owned files (stylesheets and logos) that are copied once and never refreshed. A visual or wording change travels differently through each channel, so the promise below is stated per lane.

This guide covers the compatibility promise: which names and defaults are frozen, which surfaces may only grow, who decides the identity of each surface, how releases are numbered, and how an existing host upgrades. The first shipped adoption under this policy is v1.51; the table below summarizes its changes, and the [v1.51 upgrade guide](../introduction/upgrading-to-v1.51.html) records the file-level message and token migrations. Token names are frozen; token values are a visual matter and follow the release treatment described below.

The visual source is brand book v2.0 (2026-11-13), kept read-only in `brand/` in the Sigra repository.

## Frozen list

Frozen means the name may not be removed or renamed, and a default value may not change in a way that alters what an existing host renders. Counts were measured on 2026-11-13.

| Category | Measured 2026-11-13 | How it is enforced |
|----------|---------------------|--------------------|
| `--sg-*` custom properties (names) | 100 distinct | Frozen-surface ratchet test (`test/sigra/brand/frozen_surface_test.exs`) |
| `--sigra-auth-*` custom properties (names) | 35 distinct | Frozen-surface ratchet test |
| `sg-*` classes | 112 selectors in the stylesheet; 142 distinct names in markup | Frozen-surface ratchet test |
| `sigra-auth*` classes | 66 selectors in the stylesheet | Frozen-surface ratchet test |
| `Sigra.Branding.Profile` keys and default values | 25 keys | Frozen-surface ratchet test; legacy profile byte-identity test |
| Config keys and nested option paths | 33 top-level keys, 170 option paths | Frozen-surface ratchet test |
| Route lines and verified-route helpers | 73 route-DSL lines (54 route lines, 19 scope lines) in the generated router; 54 distinct `~p` helper literals | Frozen-surface ratchet test |
| Gettext domain and msgids | one domain, `sigra`; 344 `dgettext` calls; 180 distinct msgids | Frozen-surface ratchet test; copy inventory test |
| `data-testid` values | 25 | Frozen-surface ratchet test |
| Logo filenames and installer targets | `priv/static/images/sigra-logo-primary.svg`, `priv/static/images/sigra-logo-primary-dark.svg`, `priv/static/assets/sigra_admin.css`, `priv/static/assets/sigra_auth.css` | Frozen-surface ratchet test |

Custom-property names are frozen as names. A change to a token's value is a visual change and follows the release treatment in "SemVer and changelog treatment". `Profile` keys and their default values are frozen as a pair. Every msgid is frozen unless it appears as a row in the msgid rename table; that table starts with a header and no rows, rows are added only by the release that renames a string, and the `sigra` Gettext domain, route paths and route helpers are never renamed. Wording and vocabulary are held by the lexicon test (`test/sigra/brand/copy_contract_test.exs`) and the per-lane copy inventory.

## Add-only list

These surfaces may grow. Additions pass the ratchet; removals and renames fail it.

- New custom properties, for example `--sg-font-sans` and `--sg-font-mono`, and additive status, selected-row and current-tab tokens.
- New `sg-*` and `sigra-auth-*` classes.
- New routes and new verified-route helpers.
- New msgids, including the new side of a rename-table row.
- New `data-testid` values.
- New configuration options and `Profile` keys, with defaults that keep current output.

A rename is never an addition in disguise: the old name stays frozen, and a rename-table row records the pair.

## Ownership lanes

| Lane | What lives there | How a change reaches a host | What an existing host does |
|------|------------------|-----------------------------|----------------------------|
| Library-owned | Admin LiveViews and components, `Sigra.Branding` functions, error messages | Updates with `mix deps.update` | Read the release notes; nothing to copy |
| Generated | Auth LiveViews, controllers, emails, locale files and templates emitted at install | New installs only; an existing host never receives the change on its own | Compare the new template with the local file and adopt what fits; do not overwrite customized files |
| Host-owned | Stylesheets and logo files copied into the host application | Copied once at install and never refreshed | Edit locally; re-copy only on purpose, after comparing |

## Surface map

The "Brand owner" column names who decides the visual identity once a surface ships: `Sigra` for surfaces Sigra itself presents, `host` for surfaces a host application owns, where Sigra only supplies defaults.

| Surface | Brand owner | Visual decision source |
|---------|-------------|------------------------|
| Library admin chrome | Sigra | The brand book (`brand/BRAND.md`, `brand/tokens.json`) |
| Generated auth screens | host | Neutral defaults supplied through `Sigra.Branding`; the host's own profile wins |
| Generated emails | host | The host's `Sigra.Branding` profile |
| Generated CSS and logo files | host | Copied once at install; the host edits its own copy |
| Demo host Tasklane | host | The demo's own mini-brand, separate from the Sigra book |
| ExDoc | Sigra | The brand book's documentation assets |
| Hex package page | Sigra | The brand book and the package description |
| README | Sigra | The brand book |
| `brand/` book | Sigra | `brand/BRAND.md` itself, brand book v2.0 (2026-11-13) |

## Consumed brand subset

The `brand/` directory holds the whole book. Tests and surfaces read part of it; the rest is reference-only. The manifest `brand.sha256` pins the whole tracked tree, so editing any vendored byte means re-vendoring the book and re-locking the manifest, never hand-editing a file under `brand/`.

| Consumer | Paths under `brand/` | Used for |
|----------|----------------------|----------|
| Tests | `brand.json`, `tokens.json` | Vocabulary and lexicon source, token names and values, version and date checks |
| Token and type work | `tokens.json`, `BRAND.md`, `assets/fonts/web/` (two woff2 files and `fonts.css`), `assets/fonts/OFL-InstrumentSans.txt`, `assets/fonts/OFL-RedHatMono.txt` | Token values, typefaces served from local files and their licence texts |
| Logo and favicon work | `assets/logo/`, `assets/icon/` | The v2 lockup and symbol, favicon sizes |
| Public surfaces | `assets/readme/`, `assets/social/`, `assets/docs/sigra-exdoc.css` | README header, link-preview card, ExDoc styling |
| Reference only | `sigra-brand-book.pdf`, `sigra-one-page.pdf`, `preview/*.jpg`, `assets/fonts/static/*.ttf`, `assets/fonts/variable/*.ttf`, `assets/avatar/`, the HTML pages | Not read by any test or shipped surface |

## SemVer and changelog treatment

Visual and copy changes ship in a minor release.

- Allowed commit types: `feat`, `fix` and `docs`.
- No `!` marker on any commit, and no BREAKING footer: every frozen name stays, so no documented API is removed.
- The release notes group these changes under a "Visual and copy changes" section.
- Nothing is hand-added under CHANGELOG "Unreleased". The release tooling owns that block, and a hand-written note there ships inside the released package.

Install-pin facts, checked on 2026-11-17 against Hex:

- Hex lists 1.7.1 as the newest non-retired Sigra release; 1.7.2 is not published, and the stray 1.20.0 release is retired.
- A two-segment requirement such as `~> 1.7` can still select 1.20.0 because Hex retirement is advisory.
- The documented snippets use `~> 1.7.1`, which bounds resolution to `>= 1.7.1 and < 1.8.0`. Pull-request CI checks that this requirement selects a non-retired release in an isolated scratch project.
- The install-snippet contract enforces a three-segment shape and equality across every occurrence; it also keeps planted controls to prove the checks can fail.

## Upgrade notes

Sigra's generated files belong to the host application. A brand change is therefore additive and opt-in for generated and host-owned files: update the library normally, then choose which generated files to adopt. Do not use `--force` over customized files.

### 1. Upgrade the dependency first

In a dedicated branch with a database backup:

    mix deps.update sigra
    mix compile --warnings-as-errors
    mix test

Use the package version and release notes in `CHANGELOG.md` as the SemVer source of truth.

### 2. Library-owned surfaces update automatically

Admin screens, `Sigra.Branding` functions and error messages arrive with the dependency update. Open the admin in Light, Dark and System after upgrading and read the release notes for anything that changed.

### 3. Generated files: compare rather than overwrite

Generated files are never rewritten automatically. For a customized app, compare rather than overwrite:

1. Generate a disposable fresh Phoenix host using the same Sigra flags.
2. Diff its generated stylesheets, templates and locale files against the host.
3. Adopt changes file by file, keeping host-specific product decisions.
4. Exercise Light, Dark and System, keyboard focus and a narrow viewport before merging.

The generated files that can change are the stylesheets, the logo files, the auth and email templates, and locale msgids. The table at the end of this section records the changes in v1.51; later releases add their own rows.

### 4. Host-owned files

Stylesheets and logos copied into the host at install are yours. Nothing refreshes them. If a release changes the default stylesheet or logo, copy the new version only after comparing it with your edits.

### 5. Visual and copy changes

The v1.51 adoption changes the library's documentation identity, the default admin assets, and generated authentication wording. Existing host files are not overwritten. The [v1.51 upgrade guide](../introduction/upgrading-to-v1.51.html) contains the complete message-ID and token-value tables.

| Change | Lane | Files | Action |
|--------|------|-------|--------|
| Admin theme values and lockups | Host-owned | `priv/static/assets/sigra_admin.css`; `priv/static/images/sigra-logo-primary.svg` and `sigra-logo-primary-dark.svg` | Compare the new generated assets with local edits, then selectively copy them. The installer does not refresh host-owned files; font tokens continue to inherit the host typeface. |
| Authentication and email wording | Generated | `priv/templates/sigra.install/core/` | New installs receive the updated templates. Existing apps should compare a fresh install and adopt changes file by file; see the upgrade guide's message-ID table. |
| README, HexDocs and package identity | Library-owned | `README.md`, `docs/assets/`, `mix.exs` | Update the dependency and review the release notes; no host files need to be copied. |
