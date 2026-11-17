# Upgrading to v1.51

This release brings the approved Sigra identity to its public documentation and generated auth copy. It does not change routes, helpers, configuration keys, or authentication behavior. The documented package requirement remains `{:sigra, "~> 1.7.1"}`.

Before changing an existing app, update Sigra in a branch and keep a copy of your current custom files. The [brand and visual compatibility guide](../reference/brand-compatibility.html) explains the ownership boundaries in more detail.

## Before you start

1. Read the release notes for the version you are installing.
2. Update the dependency with `mix deps.update sigra`, then compile and run your app's tests.
3. Compare any generated or copied files with a fresh install. Do not overwrite local changes just to take the new defaults.

The README and HexDocs change with the library release. Generated templates and host-owned files have different update paths, shown below.

## Ownership lanes

| Lane | What changes in v1.51 | How your app receives it | What you do |
|---|---|---|---|
| Library-owned | README, HexDocs, package assets, and library-owned documentation | With the dependency update | Review the release notes; no files need to be copied. |
| Generated | Auth messages and generated templates | New installs receive the updated files; existing apps are not rewritten | Compare with a fresh install and adopt changes one file at a time. |
| Host-owned | Admin stylesheets and logo files copied into your app | The installed copy stays as it is | Recopy only after comparing the new values and artwork with your local edits. |

## Generated auth message changes

These generated strings adopt the approved “sign in” wording and remove Sigra's name from a host-owned account-deletion notice. Routes, helpers, function names, form names, the `sigra` Gettext domain, and auth behavior stay the same. Existing apps receive no generated changes automatically.

| Template | Surface | Old msgid | New msgid |
|---|---|---|---|
| `core/registration_live.ex` | Existing-account link | `Log in` | `Sign in` |
| `core/registration_html.ex` | Existing-account link | `Log in` | `Sign in` |
| `core/confirmation_live.ex` | Confirmed, already-confirmed, and sign-in-required links | `Log in` | `Sign in` |
| `core/confirmation_live.ex` | Already-confirmed subtitle | `Your email was already confirmed. You can log in below.` | `Your email was already confirmed. You can sign in below.` |
| `core/confirmation_html.ex` | Already-confirmed subtitle | `Your email was already confirmed. You can log in below.` | `Your email was already confirmed. You can sign in below.` |
| `core/confirmation_html.ex` | Already-confirmed link | `Log in` | `Sign in` |
| `core/reset_password_live.ex` | Return link | `Back to log in` | `Back to sign in` |
| `core/reset_password_html.ex` | Return link | `Back to log in` | `Back to sign in` |
| `core/emails.ex` | HTML and plain-text OAuth reset CTAs | `Log in with %{provider}` | `Sign in with %{provider}` |
| `core/settings_live.ex` | Account deletion strategy notice | `Schedule account deletion according to your configured deletion strategy. After the grace period expires, Sigra finalizes the account lifecycle according to that strategy.` | `Schedule account deletion according to your configured deletion strategy. After the grace period expires, the selected strategy is applied to your account.` |

To adopt these in an existing app, generate into a disposable Phoenix app with the same `mix sigra.install` options, compare the generated files with yours, and merge only the changes that fit your app. Keep customizations and existing route names.

## Admin token value changes

The `--sg-*` token names remain frozen; this table records value changes and additions only. `kept` means the old value stays unchanged, `inherited` means the old dark theme inherited the light value, `none` means the token did not exist, and `n/a` means there is no dark-theme value. For kept values, retain the value already in your copied stylesheet.

| Token | Old light | New light | Old dark | New dark |
|---|---|---|---|---|
| `--sg-weight-regular` | `450` | `400` | n/a | n/a |
| `--sg-weight-medium` | `600` | kept | n/a | n/a |
| `--sg-weight-semibold` | `700` | kept | n/a | n/a |
| `--sg-weight-bold` | `800` | `700` | n/a | n/a |
| `--sg-color-ink` | `#151515` | `#1F1A17` | `#f4f1eb` | `#F3EEE8` |
| `--sg-color-muted` | `#686868` | `#5F554D` | `#bdb5aa` | `#B8ABA0` |
| `--sg-color-subtle` | `#f6f5f2` | `#F7F3EE` | `#171614` | `#17120F` |
| `--sg-color-panel` | `#ffffff` | kept | `#1f1d1a` | `#221B17` |
| `--sg-color-panel-alt` | `#fbfaf7` | kept | `#25221e` | kept |
| `--sg-color-line` | `rgba(21, 21, 21, 0.1)` | `#DDD3C8` | `rgba(255, 255, 255, 0.1)` | `#3A2F28` |
| `--sg-color-line-strong` | `rgba(21, 21, 21, 0.16)` | kept | `rgba(255, 255, 255, 0.16)` | kept |
| `--sg-color-brand` | `#c2410c` | kept | inherited | `#F08A55` |
| `--sg-color-brand-strong` | `#9a3412` | kept | `#fdba74` | `#F08A55` |
| `--sg-color-brand-solid` | `#9a3412` | kept | `#fdba74` | `#F08A55` |
| `--sg-color-brand-fill-hover` | `#c74712` | kept | `#c74712` | `#F4A27C` |
| `--sg-color-brand-fill-active` | `#9a3412` | kept | `#9a3412` | `#E07A45` |
| `--sg-color-brand-soft` | `#fff0e8` | kept | `rgba(243, 90, 16, 0.16)` | kept |
| `--sg-color-on-brand` | `#ffffff` | kept | inherited | `#17120F` |
| `--sg-color-on-brand-solid` | `#ffffff` | kept | `#151515` | `#17120F` |
| `--sg-logo-rail-accent` | `#fdba74` | kept | inherited | kept |
| `--sg-logo-rail-ember` | `#c2410c` | kept | `#f97316` | `#F08A55` |
| `--sg-logo-core` | `#9a3412` | `#1F1A17` | `#f4f1eb` | `#F3EEE8` |
| `--sg-color-risk` | `#b42318` | kept | `#f8a39c` | kept |
| `--sg-color-risk-soft` | `#fff1f0` | kept | `rgba(248, 113, 113, 0.16)` | kept |
| `--sg-color-warn` | `#a15c00` | kept | `#f5c451` | kept |
| `--sg-color-warn-soft` | `#fff7e6` | kept | `rgba(245, 196, 81, 0.16)` | kept |
| `--sg-color-ok` | `#176b43` | kept | `#5dd1a0` | kept |
| `--sg-color-ok-soft` | `#ecfdf3` | kept | `rgba(52, 211, 153, 0.16)` | kept |
| `--sg-color-info` | `#1d4ed8` | kept | `#9db8f5` | kept |
| `--sg-color-info-soft` | `#eef2ff` | kept | `rgba(120, 150, 245, 0.16)` | kept |
| `--sg-focus-ring` | `0 0 0 3px color-mix(in oklab, var(--sg-color-brand) 35%, transparent)` | `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` | inherited | `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` |
| `--sg-focus-ring-offset` | `2px` | kept | inherited | kept |
| `--sg-status-active` | none | `#1D6B3C` | none | `#86C99B` |
| `--sg-status-unconfirmed` | none | `#7A5F00` | none | `#D6B957` |
| `--sg-status-locked` | none | `#7A5F00` | none | `#D6B957` |
| `--sg-status-deleting` | none | `#7A5F00` | none | `#D6B957` |
| `--sg-status-suspended` | none | `#5F554D` | none | `#B8ABA0` |
| `--sg-color-selected` | none | `#EADFD2` | none | `#33281F` |
| `--sg-color-selected-edge` | none | `#C2410C` | none | `#F08A55` |
| `--sg-color-current-tab` | none | `#9A3412` | none | `#F08A55` |
| `--sg-color-sunken` | none | `#EFE9E1` | none | `#120E0C` |
| `--sg-color-control-edge` | none | `#857569` | none | `#8B7D72` |
| `--sg-font-sans` | none | `inherit` | none | n/a |
| `--sg-font-mono` | none | `ui-monospace, 'SF Mono', Consolas, monospace` | none | n/a |

Copy the updated stylesheet only after comparing its changes with your local edits. Review Light, Dark, and System themes and check that focus remains visible.

## Release notes

The brand and copy changes are intended for a minor release. Frozen names remain unchanged, so do not use a `!` marker or a `BREAKING CHANGE` footer in commit messages. Use conventional commit types such as `docs`, `fix`, and `feat`; release tooling owns the `Unreleased` section of `CHANGELOG.md`.
