# Phase 260 Deferred Items

Out-of-scope discoveries logged by the plans of this phase. Each plan adds its own
section; plan 05 adds the owed pre-262 shipped-byte fixes, the 56-class CSS gap, the
Pages-workflow compare note and the SC-1 wording reconciliation.

## From plan 03 (raw inputs for the before catalog)

### 1. The generated reset-password request page returns HTTP 500 (executed evidence)

`GET /users/reset-password` on a freshly generated `--live` host answers 500:
`CaseClauseError ... nil` raised from `ResetPasswordLive.mount/3` at
`reset_password_live.ex:132` (the generated route `live "/reset-password",
ResetPasswordLive` carries no live action, so `live_action` is `nil`). The todo
`.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md`
recorded this as "read in source, not executed"; plan 03 executed it against a booted
generated host (phx_new 1.8.8 + `mix sigra.install --yes Accounts User users --no-passkeys`).

Not fixed here: plan 03 may not change `lib/` or `priv/`. How the catalog treats it:

- `scripts/ci/admin-acceptance-smoke.sh --test catalog` pins this one page as an
  expected 500, accepted only when the dev error page carries the exact signature
  (`CaseClauseError at GET /users/reset-password` and `ResetPasswordLive.mount/3`).
  The error page (local paths, stack) is never kept; `pages/reset-password.html`
  holds a one-line marker comment.
- When the template is fixed the page answers 200 and the script fails until the
  `reset-password|/users/reset-password|500` entry is changed to `200`, so the
  baseline cannot go stale silently.
- Plan 05's manifest `deferred_shipped_byte_fixes` should name this fix, and the
  `before` file for this slug is a marker, not a rendered page.

### 2. The smoke script and `tmp/db.env` disagree about which Postgres to use

With `source tmp/db.env` exported, `mix ecto.drop` and `mix ecto.create` in the generated
host follow `PGPORT` (the dockerized test Postgres), but the host's `Repo` connects to
`localhost:5432` (the generated config sets `hostname: "localhost"` and no port). The
result is `duplicate_table` on the first migrate against whichever stale
`sigra_admin_smoke_*` database exists on 5432. Plan 03's own verify command sources
`tmp/db.env`, so it fails in this environment; the target was run with the `PG*` and
`SIGRA_TEST_PG_*` variables unset instead (`env -u PGPORT -u PGHOST -u PGUSER -u PGPASSWORD
-u PGDATABASE ...`), which works because all three commands then reach 5432. Plan 05
should run the target the same way. Pre-existing script behavior, untouched.

### 3. Two generated email builders are not in the raw set

`email_change_confirmation_email/3` and `email_change_notification_email/3` end a
sentence with the new address and a period. The raw-directory address scan reads that as
a domain ending `.test.` and flags it, although the root privacy rule accepts it. They
were left out of the capture rather than loosening the scan; plan 05 may add them if it
settles the scan regex.

### 4. `unconfirmed` and `locked` tier-2 pages hold the same persona

The seeds carry one unconfirmed persona (`dave`) and it is also the locked one, so
`admin-user-show-unconfirmed` and `admin-user-show-locked` (and the sessions and audit
pairs) render the same account. The slugs are kept because the plan fixes the slug list.

## From plan 05 (the immutable before capture)

The before catalog is committed at `test/fixtures/brand/before/` (63 files, 62 catalog
files plus `MANIFEST.json`). It is write-once: the writer refuses when the manifest exists
(observed), and the manifest re-hash test fails on any changed byte. A needed correction is
a new documented capture decision, never an overwrite.

### 1. Owed pre-262 shipped-byte fixes (none is fixed here), and the re-capture rule

Source: `259-VERIFICATION.md`, "Notes for the next phase planner" item 1 and ADR 005
amendment B. These change generated output, so they are shipped-byte work that has no
phase yet. Phase 260's success criterion 5 forbids changing copy, markup or `Profile` keys
and Phase 261 is tokens and type, so neither is the home. Owed:

- the registration timing oracle (generated registration flow),
- the passkey-options oracle,
- the generated confirm fix (named in ADR 005 amendment B),
- the generated reset-request fix, now with executed evidence (item 2 of plan 03's section
  above: `GET /users/reset-password` is a real HTTP 500 on a fresh host).

**Re-capture rule.** The generated-lane before (`generated-host-pages/` and
`generated-host-emails/`) was taken from shipped bytes that still contain all four defects.
If any of these fixes lands before Phase 262 changes generated output, the generated-lane
before must be re-captured first, as a documented new capture decision with a fresh
manifest, or the Phase 262 before/after diff mixes the fix with the redesign and cannot be
reviewed as one. The manifest records the same rule in `deferred_shipped_byte_fixes`.

The baseline for `generated-host-pages/reset-password.html` is a one-line marker comment,
not a rendered page (decision recorded with plan 03 deliverable D5: the truthful before
state of a page that answers 500). It is called out in the manifest `coverage.not_covered`
text and in `deferred_shipped_byte_fixes`. Once the shipped page is fixed, `--test catalog`
fails until its pinned status in the smoke script is changed from 500 to 200, so the
baseline cannot go stale silently.

### 2. The 56-class shipped-CSS gap

Library and shell markup emits 56 `sg-*` classes that are defined only in the example
`app.css` (plus 3 defined nowhere). Plans 07 and 09 handle it as a measured, shrink-only
baseline (`test/fixtures/brand/css-undefined-classes.txt`): the set may not grow, and
plan 09 removes exactly the classes it moves into the shipped `sigra_admin.css`. The rest
is not moved in this phase (it would be a 700-line shipped-byte change and a much larger
golden diff). Recorded here because the before catalog is text and carries no CSS: it
cannot show the gap, and its manifest pins the shipped CSS and logo sha256 values instead.

### 3. `playwright-github-pages.yml` PNG compare is left as it is

The research recommended adding the park flag to that workflow. The plans decline it (RESEARCH
Open Question 4): with default-on compare an unset switch compares, so the workflow keeps
comparing with no edit, it is not a required context and not in `ci-gate`, and leaving it
alone keeps the park PR a `ci.yml`-only change. Accepted cost: that workflow reports drift
after Phase 261 until the baselines are recaptured; documented in MAINTAINING.md (plan 01)
and the park PR body (plan 04).

### 4. ROADMAP SC-1 wording: "full HTML as a CI artifact" is produced by no plan

SC-1's parenthetical asks for the full HTML as a CI artifact. No plan produces it, on
purpose (RESEARCH Open Question 7): the committed, normalized text is the durable review
artifact (a CI artifact expires after 7 to 14 days, so it cannot be the baseline Phase 262
diffs against), and producing one would need a workflow edit the process budget forbids.
The catalog is 62 normalized files, about 660 KB on disk, under the 3 MB stop limit. Plan
11 restates the departure; the ROADMAP text itself is not edited here.

### 5. Two generated email builders are still not in the before

Carried from plan 03 item 3: `email_change_confirmation_email/3` and
`email_change_notification_email/3` are not captured (a sentence ends with the address and
a period, which the raw-directory address scan reads as a non-`.test` domain). Adding them
would need a script change and a re-capture, and the before is immutable, so they are not
captured. If Phase 262 changes either email, that change has no before to diff against:
record the gap in the Phase 262 report or open a documented new capture decision that adds
only those two files.

### 6. What the manifest honestly does not claim

Authenticated generated screens are baselined by the golden install tree only. Admin theme
is client-side, so Light, Dark and System share server HTML (contrast and axe belong to
Phase 261 BTOK-03). Generated anonymous auth pages carry a server-side `data-theme` taken
from the branding profile; only the default-profile value (`system`) is captured. The
tier-2 branding page's sender field and the generated emails' sender were overridden to a
seeded `.test` address for the capture; the shipped default sender is not part of the
captured bytes. `unconfirmed` and `locked` tier-2 pages hold the same persona (plan 03
item 4). The capture session activity stamp is the only exact-value replacement in the
pipeline.

## From plan 06 (asset parity and double install)

### 1. `MAINTAINING.md` and a prohibition fixture still say the golden alias runs two files

`MAINTAINING.md` (the "That alias runs `golden_diff_test.exs` and `idempotency_test.exs` only"
sentence) and its quoted copy in `test/fixtures/prohibitions/p07-honest-skip-line-citation.md`
were already stale before this plan: `ci.install_golden` listed six files, and with
`double_install_test.exs` it lists seven. Not edited here (the fixture is byte-pinned by a
prohibition test, and MAINTAINING.md belongs to plans 01 and 11). Plan 11 may restate the sentence
together with the fixture, or leave both and let the alias in `mix.exs` stay the source of truth.

### 2. The path-gated `install_golden_contract` CI job does not run the double-install proof

`.github/workflows/ci.yml` (`install_golden_contract`, step "Run install golden + idempotency
tests") runs `golden_diff_test.exs` and `idempotency_test.exs` by explicit path. The new
`double_install_test.exs` runs in the `Library tests shard` through `mix ci` (which runs
`ci.install_golden`), not in that job. Left alone: the process budget forbids a workflow edit in
this plan, and the job's other step already runs `rebless_golden --check`.

### 3. Template `.json` snippets are outside the BGEN-01 table

The table covers the `.css`, `.svg` and `.js` files the requirement names (8). The two `.json`
files under `priv/templates/sigra.install/passkeys/` (`package.json`,
`package_json_injection.json`) are injected or merged into a host `package.json`, have no
copied counterpart, and are not classified. If a future template adds a copied `.json` asset,
extend `@asset_extensions` in `asset_parity_test.exs` and give it a row.

### 4. The example `sigra_auth.css` refresh changes what the example home page can render

`test/example/lib/example_web/controllers/page_html/home.html.heex` links `sigra_auth.css` and
renders a `sigra-auth sigra-auth--preview` block, so the refreshed stylesheet (32,072 bytes, 66
classes, was 13,867 bytes, 11 classes) can move pixels on that page. The example suite is green
(419 tests, 0 failures) but it asserts no pixels. No PNG was recaptured locally; PNG comparison
is parked on the PR path by plan 01 and plan 04's park PR, and the recapture jobs remain the way
to refresh baselines.

## From plan 08 (catalog diff report and gallery catalog section)

### 1. The shipped default dark palette draws accent text below WCAG AA

`priv/templates/sigra.install/core/sigra_auth.css` sets the dark-theme accent default to
`#c2410c` in both the `[data-theme="dark"]` block and the `prefers-color-scheme: dark` block for
`[data-theme="system"]`, while the dark surface is `#211f1c`. Measured by axe: 3.17:1 for the
link text ("Create an account") and for the bold disclosure summary ("Other ways to sign in"),
against the 4.5:1 AA minimum. It surfaced because the page-wide axe test in `admin-design-dark`
failed (3 nodes, all `color-contrast`) when the new gallery section first drew the auth preview at
`data-theme="system"`; the chromium and mobile projects passed. The example copy of the stylesheet
is byte-identical to the template (`cmp`), so a generated host on the default profile in a
dark-colour-scheme browser draws the same colour pair (measured on the example, read in the
template for generated hosts).

Not fixed here: this plan may not change `priv/` or any token value, and the contrast fix is
Phase 261 token work (BTOK-03). How the catalog treats it: the four `catalog-*` auth and email
previews are pinned to `data-theme="light"` with a comment in `design_gallery_live.ex` naming the
reason; once the dark palette passes AA the pin can move back to `system`.

### 2. A local run of the gallery PR-path specs needs a seeded dev database

Two gallery behavior tests (`MG-5 and MG-6 desktop and mobile representations are
content-equivalent`, `filter form submits via real GET submission and returns filtered results`)
fail on a migrated but unseeded dev database with "admin users first Open user link is missing
href" (6 failures across the three design projects). With `mix run priv/repo/seeds.exs` all 42
non-`@snapshot` tests pass in the three projects. Not a defect of this plan; recorded for plan 11
Task 3, which re-runs the whole non-`@snapshot` gallery spec and must seed first.

## From plan 09 (the L1 move into the shipped `sigra_admin.css`)

### 1. App.css rules keyed on `data-theme` that were not moved

After the move, no rule keyed on `data-sg-admin-theme` or on the admin shell's `data-theme` is
left in the example `app.css`. The remaining `data-theme` rules are demo-only (`vt-*` and
`data-demo-*` surfaces), not admin shell rules, and stay in the example: lines for
`[data-demo-brand-surface|auth-preview|email-preview][data-theme=dark|system]` (about 731 to 780)
and `.vt-auth` / `.vt-brand-lab` `[data-theme=...]` (about 1200 to 1214).

### 2. The explicit Dark theme in a generated host still has no shell surface rule

In a real generated host (booted by `admin-acceptance-smoke.sh --test chrome`, screenshots written
unasserted to the Playwright output directory as `admin-light.png`, `admin-dark.png` and
`admin-system-dark.png`) the explicit Dark attribute now re-resolves the `--sg-*` values on
`.sg-admin-shell`, swaps the lockups and keeps the theme switch colours, as the computed-style
assertions prove. It does not look dark: the shipped stylesheet has no `.sg-admin-shell { background;
color; min-height }` rule (the base shell surface lives only in the example `app.css`, one of the
49 gap classes still in the baseline), so the page background and the body text keep the `:root`
values (light ink on a light page) while panels and cards pick up the dark panel colour. The
screenshot shows dark panels under dark text. The plan scope (OQ2) is the roadmap minimum, so this
is recorded, not fixed. Candidate owner: Phase 261 (tokens and type) or the first phase that moves
more of the 49 remaining classes; the shrink-only baseline will fail until each moved class is
removed from it.

### 3. Layering side effect on the example's mobile theme switch

The moved `.sg-theme-switch__button` base rule used to be unlayered in the example `app.css`, so it
beat the shipped small-screen override in `@layer sg-overrides` (`min-width: 2rem`,
`padding-inline: var(--sg-space-2)` at 640 px and below), which therefore never applied in the example.
Both rules are now in the shipped layers and, by cascade-layer order (not measured), the override
wins as designed: at 640 px and below the example's theme switch segments should be narrower than before (min-height and the touch target stay above
the 24 px floor). Visible only as a pixel change; no assertion covers it and PNG compare is parked.

### 4. `mix sigra.fixture.rebless_golden --help` is a writer invocation

The task parses its arguments with `OptionParser.parse(argv, strict: [check: :boolean])`, so an
unknown switch such as `--help` is dropped and the task runs as the WRITER (it rewrites the tree).
Plan 09 ran it once by mistake with no `MIX_ENV=test` and its output discarded. Inferred, not
observed: it stopped at `ensure_test_support_loaded!` (the fixture module is not compiled in
`:dev`) before any write. The evidence is that the golden files' modification times are those of
the intended rebless (the writer removes and rewrites the whole tree, so a run would have moved
every one), `git status` was clean and `--check` stayed clean afterwards. A task that rewrites a committed
fixture on an unknown switch is a footgun; rejecting unknown switches or adding a real `--help`
would be a small follow-up (not done here; `lib/` is out of scope for this plan).
