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
