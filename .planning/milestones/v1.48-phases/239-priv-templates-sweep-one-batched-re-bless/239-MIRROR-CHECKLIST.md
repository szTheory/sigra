# 239-03 SC-4 Mirror Checklist

One row per template edited by plan 239-02's sweep commit (`cafd9a53`). Each row carries the
template's pre-sweep union-token count and exactly one disposition: a `test/example/` counterpart
path with its mirrored line count (this plan, 239-03), `n/a — already absent` (the counterpart
already carried zero tokens before this plan touched anything), or `no counterpart (delivered by
injection)` (the template has no `{:eex, ...}` file-emission target in
`lib/sigra/install/features/*.ex` — it's spliced into an existing file by the generator, not
rendered to a new one).

> **Staleness correction — 2026-09-17, plan 239-07.** This checklist was originally frozen against
> commit `cafd9a53` (plan 239-02's sweep) and was never updated afterwards. It went stale when the
> router sweep landed in `6fa3ead2` and its prose repair in `e4e03980`: those two commits edited the
> router heredoc in `lib/sigra/install/features/core.ex`, a file this checklist omitted entirely, and
> they changed what `organizations/router_injection.ex` actually delivers into a generated app —
> which made its `no counterpart (delivered by injection)` disposition wrong. The original framing
> above is retained deliberately; the corrections are recorded below rather than written over it.
> **This checklist is accurate as of the plan-239-07 mirror commit, whose parent is `60bac0bb`.**

## Mirrored counterparts (30 files, 110 template token lines)

| Template (pre-sweep tokens) | Disposition |
|---|---|
| priv/templates/sigra.install/organizations/live/organization_members_live.ex (18) | Mirrored → `test/example/lib/example_web/live/organization_members_live.ex` (18 lines) |
| priv/templates/sigra.install/organizations/organizations.ex (12) | Mirrored → `test/example/lib/example/organizations.ex` (12 lines) |
| priv/templates/sigra.install/organizations/live/organization_settings_live.ex (11) | Mirrored → `test/example/lib/example_web/live/organization_settings_live.ex` (11 lines) |
| priv/templates/sigra.install/core/auth_fixtures.ex (8) | Mirrored → `test/example/test/support/fixtures/auth_fixtures.ex` (8 lines) |
| priv/templates/sigra.install/core/user_auth.ex (7) | Mirrored → `test/example/lib/example_web/user_auth.ex` (7 lines) |
| priv/templates/sigra.install/core/emails.ex (4) | Mirrored → `test/example/lib/example/accounts/emails.ex` (4 lines) |
| priv/templates/sigra.install/core/mfa_settings_live.ex (4) | Mirrored → `test/example/lib/example_web/live/mfa_settings_live.ex` (4 lines) |
| priv/templates/sigra.install/core/sigra_auth.css (4) | Mirrored → `test/example/priv/static/assets/sigra_auth.css` (4 lines) |
| priv/templates/sigra.install/core/auth.ex (4) — **renamed (D-21): context module** | Mirrored → `test/example/lib/example/accounts.ex` (4 lines) |
| priv/templates/sigra.install/organizations/live/organizations_live/index.ex (4) | Mirrored → `test/example/lib/example_web/live/organizations_live/index.ex` (4 lines) |
| priv/templates/sigra.install/core/audit_event.ex (3) | Mirrored → `test/example/lib/example/accounts/audit_event.ex` (3 lines) |
| priv/templates/sigra.install/core/mfa_challenge_live.ex (3) | Mirrored → `test/example/lib/example_web/live/mfa_challenge_live.ex` (3 lines) |
| priv/templates/sigra.install/core/reset_password_live.ex (3) | Mirrored → `test/example/lib/example_web/live/reset_password_live.ex` (3 lines) |
| priv/templates/sigra.install/core/reset_password_controller.ex (3) | Mirrored → `test/example/lib/example_web/controllers/reset_password_controller.ex` (3 lines) |
| priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex (3) | Mirrored → `test/example/lib/example_web/controllers/organization_switch_controller.ex` (3 lines) |
| priv/templates/sigra.install/core/scope.ex (2) | Mirrored → `test/example/lib/example/accounts/scope.ex` (2 lines) |
| priv/templates/sigra.install/organizations/live/invitation_accept_live.ex (2) | Mirrored → `test/example/lib/example_web/live/invitation_accept_live.ex` (2 lines) |
| priv/templates/sigra.install/organizations/components/org_switcher.ex (2) | Mirrored → `test/example/lib/example_web/components/org_switcher.ex` (2 lines) |
| priv/templates/sigra.install/organizations/organization.ex (2) | Mirrored → `test/example/lib/example/accounts/organization.ex` (2 lines) |
| priv/templates/sigra.install/core/registration_live.ex (1) | Mirrored → `test/example/lib/example_web/live/registration_live.ex` (1 line) |
| priv/templates/sigra.install/core/confirmation_live.ex (1) | Mirrored → `test/example/lib/example_web/live/confirmation_live.ex` (1 line) |
| priv/templates/sigra.install/core/reset_password_html.ex (1) | Mirrored → `test/example/lib/example_web/controllers/reset_password_html.ex` (1 line) |
| priv/templates/sigra.install/core/sudo_controller.ex (1) | Mirrored → `test/example/lib/example_web/controllers/auth/sudo_controller.ex` (1 line) |
| priv/templates/sigra.install/core/sudo_html.ex (1) | Mirrored → `test/example/lib/example_web/controllers/auth/sudo_html.ex` (1 line) |
| priv/templates/sigra.install/core/user.ex (1) | Mirrored → `test/example/lib/example/accounts/user.ex` (1 line) |
| priv/templates/sigra.install/core/user_token.ex (1) | Mirrored → `test/example/lib/example/accounts/user_token.ex` (1 line) |
| priv/templates/sigra.install/admin/admin_hooks.js (1) | Mirrored → `test/example/assets/js/admin_hooks.js` (1 line) |
| priv/templates/sigra.install/core/login_html.ex (1) — **renamed (D-21): renders into session_html.ex** | Mirrored → `test/example/lib/example_web/controllers/session_html.ex` (1 line) |
| priv/templates/sigra.install/organizations/live/organizations_live/new.ex (1) | Mirrored → `test/example/lib/example_web/live/organizations_live/new.ex` (1 line) |
| priv/templates/sigra.install/core/migration.exs (1) — **renamed (D-21): timestamped migration** | Mirrored → `test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs` (1 line) |

Sum of the "Mirrored counterparts" pre-sweep template token column: 110, across 30 files —
matching the SC-4 edit budget exactly.

## Already-absent counterparts (4 files, honest divergence — no edit made)

These four counterparts already carried **zero** union-token lines before this plan touched
anything, while their source templates carried non-zero counts. No edit was made — a phantom
edit here would misrepresent an already-diverged file as freshly swept. This divergence, together
with the no-counterpart rows below, **is** the FUT-01 diagnosis carried into plan 239-04 (D-25).

| Template (pre-sweep tokens) | Disposition |
|---|---|
| priv/templates/sigra.install/core/settings_live.ex (4) | n/a — already absent (`test/example/lib/example_web/live/settings_live.ex`) |
| priv/templates/sigra.install/core/error_handler.ex (1) — **renamed (D-21)** | n/a — already absent (`test/example/lib/example_web/auth_error_handler.ex`) |
| priv/templates/sigra.install/organizations/organization_invitation.ex (2) | n/a — already absent (`test/example/lib/example/accounts/organization_invitation.ex`) |
| priv/templates/sigra.install/organizations/migration.exs (13) — **renamed (D-21): timestamped migration** | n/a — already absent (`test/example/priv/repo/migrations/20260410125245_create_organizations.exs`) |

## No-counterpart templates (12 files, delivered by injection — D-22)

These templates have no `{:eex, ...}` file-emission target in `lib/sigra/install/features/*.ex` —
the generator splices their content into an existing file (or, for `sigra.upgrade/`, applies them
as an upgrade-time patch script) rather than rendering them as a standalone file. `test/example/`
therefore has no counterpart path to mirror into by construction, not by omission.

| Template | Disposition |
|---|---|
| priv/templates/sigra.install/core/mfa_challenge_controller.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/organization_invitation_email.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/mfa_challenge_html.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/mfa_settings_html.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/token_controller.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/api_token_created_email.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/router_injection.ex | **Corrected (plan 239-07)** — de-facto counterpart `test/example/lib/example_web/router.ex`. See § *Corrections (plan 239-07)* below for the five mirrored sites. |
| priv/templates/sigra.upgrade/data_migration.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.upgrade/alter_add_personal.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.upgrade/alter_add_owner_user_id.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.gen.oauth/oauth_settings_live.ex | no counterpart (delivered by injection) |

## Corrections (plan 239-07)

### C-1 — `organizations/router_injection.ex` has a de-facto counterpart after all

The original `no counterpart (delivered by injection)` disposition was **defensible but wrong**: the
template has no `{:eex, ...}` emission target, so a filename-based mapping from template to generated
file finds nothing — but the router heredoc is spliced into the generated app's `router.ex` all the
same, and `test/example/lib/example_web/router.ex` is the hand-maintained mirror of exactly that
file. A disposition derived from the emission table cannot see a splice target; a disposition derived
from *what the adopter ends up with* can.

Counterpart: `test/example/lib/example_web/router.ex`. Five sites mirrored by plan 239-07's commit,
each taking the wording already committed in
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` (the generated tree is
the wording authority — no third wording was invented):

| Example site (pre-mirror line) | Before | After (golden wording) |
|---|---|---|
| `router.ex:36` | `# Phase 17 D-06: single unscoped InvitationAcceptLive at` | `# Single unscoped InvitationAcceptLive at` |
| `router.ex:77` | `# MFA challenge (accessible with mfa_pending sessions, D-24)` | `# MFA challenge (accessible with mfa_pending sessions)` |
| `router.ex:103-106` | 4-line `# Phase 10.1.1 B9: login page is a plain controller + HEEx render, …` block | collapsed to `# Login page is a plain controller, not a LiveView.` (the golden router collapsed it; the example follows rather than guesses) |
| `router.ex:209` | `# Sigra organizations (Phase 16)` | `# Sigra organizations` |
| `router.ex:226` | `# "switch" as a slug (D-06).` | `# "switch" as a slug.` |

A sixth site was swept in the same commit as a Rule-2 deviation: `router.ex:175`
`# Dev-only routes for local UAT …` → `… for local manual testing …`. It carries `\bUAT\b`, which is
in the V2 bookkeeping definition 239-05 widened to, and it sits on a file this plan was already
editing; leaving it would have made the plan's own `V2 → 0` truth false. It has no template or golden
counterpart (example-only dev-routes block).

### C-2 — rows the frozen checklist omitted entirely

| File | Disposition |
|---|---|
| `lib/sigra/install/features/core.ex` | **Edited by this phase** (`6fa3ead2`, repaired in `e4e03980`) and absent from the original checklist. It is not a `priv/templates/` file at all — it is the generator module holding the router heredoc — which is why a templates-only enumeration missed it. Counterpart: `test/example/lib/example_web/router.ex`, converged by plan 239-07 (see C-1). Sites swept in the heredoc: the `Phase 14 Plan 03` organization-pipelines comment, `mfa_pending sessions, D-24`, and `Phase 10.1.1 B9: login page …`. |
| `test/example/lib/example_web/components/layouts.ex` | **Mirror target added by plan 239-07.** Two sites: line 9 `# Phase 16 D-27: organization switcher function component.` → `# Organization switcher function component.` (a comment), and line 52 `doc: "list of {organization, role} tuples for the current user (Phase 16 D-26)"` → `doc: "… for the current user"`. The line-52 site is **not a comment**: it is an `attr/3` `:doc` option, rendered into ExDoc output and surfaced by LSP hover, so the token was user-visible text on a documentation surface. |

## Closure batch (plans 239-05 / 239-06)

One row per template the closure batch edited, so SC-4's per-edited-file disposition rule holds for
this batch exactly as it held for the first sweep. Eight templates; six take a `test/example/`
counterpart disposition, two take a no-mirror-needed disposition, and both of the latter are asserted
by a recorded grep rather than by assertion.

| Template (closure edit) | Disposition |
|---|---|
| `priv/templates/sigra.install/core/login_html.ex` (239-05, IN-04 + `during UAT`) | Mirrored → `test/example/lib/example_web/controllers/session_html.ex` (renamed counterpart, D-21). Converged by plan 239-07; `grep -c 'during UAT'` → **0**, `grep -c "LiveView's"` → **1**, `grep -c 'SessionController.create/2'` → **1**. |
| `priv/templates/sigra.install/core/sigra_auth.css` (239-06, three comment blocks) | **No mirror needed.** `test/example/priv/static/assets/sigra_auth.css` is a different, shorter build-free file that does not contain the swept comment blocks. Asserted: `grep -c 'min-width: 0'` → **3** (live positive control, the file is real and greppable) and `grep -cE '30518012012\|30518015684\|re-litigate'` → **0** (nothing to converge). A "mirrored" claim here would be a phantom edit; the file is absent from this commit's `git diff --name-only`. |
| `priv/templates/sigra.install/core/mfa_settings_live.ex` (239-06, WR-07) | **Already converged — confirmed, not edited.** 239-06 adopted the *example's* clean wording into the template, so the example needed no change. Asserted: `diff <(sed -n '606,610p' <template>) <(sed -n '631,635p' <example>)` → identical. Absent from this commit's `git diff --name-only`. |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` (239-06, WR-03/WR-04/IN-01/IN-02) | Mirrored → `test/example/lib/example_web/live/organization_members_live.ex`. Present-tense seam paragraph and Architecture bullet adopted; `this section` pointer and stray `only.` deleted. `grep -c 'Look for the'` → **0**, `grep -c 'pending-invitations-section'` → **3**. |
| `priv/templates/sigra.install/organizations/live/organizations_live/index.ex` (239-06, WR-05) | Mirrored → `test/example/lib/example_web/live/organizations_live/index.ex`. Branch B line adopted; `grep -c 'until then'` → **0**. |
| `priv/templates/sigra.install/organizations/organization_invitation.ex` (239-06, WR-06) | **No counterpart sentence — confirmed, not edited.** `test/example/lib/example/accounts/organization_invitation.ex` is `@moduledoc false`, so the WR-06 sentence naming the library as owner of the invitation flow has nothing to converge into. Absent from this commit's `git diff --name-only`. |
| `priv/templates/sigra.install/organizations/organization_invitation_email.ex` (239-06, IN-03(a)) | **No counterpart** per D-22 (delivered by injection), restated for the closure batch. Asserted: `grep -rc 'phishing defense — prevents inviter/org spoofing' test/example/` → **0 files**, against a live control of **2** files under `test/example/` matching `phishing` — the string is genuinely absent, not the grep dead. The example's `lib/example/accounts/emails.ex` carries its own longer, differently-structured phishing rationale, which is not the IN-03(a) parenthetical and is untouched. |
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` (239-06, IN-03(b)) | Mirrored → `test/example/lib/example_web/live/invitation_accept_live.ex`. The `:mismatch` invariant note (`That absence is asserted by a test … do not add accept controls to this branch.`) converged verbatim; `grep -c 'ZERO .phx-click'` still → **1**, so the original invariant sentence survived rather than being replaced. |

## Scoping statement

Repo-wide, `test/example/` carried 476 planning-bookkeeping token lines across 94 files before
this plan. This commit deliberately swept only the **110 token lines across 30 counterpart
files** that SC-4 mandates (the direct counterparts of templates plan 239-02 edited) — leaving
the remaining ~366 token lines across the other ~64 files in `test/example/` untouched, on
purpose, for a future milestone to scope and sweep independently. `test/example/` is a
hand-maintained generated-app mirror that already drifts behind `priv/templates/` by design (see
`reference_installer_template_drift.md`); this plan's job was narrowly to keep the 30 direct
counterparts of the swept templates from contradicting the sweep, not to bring the whole
hand-maintained tree into alignment.


## Batch-3 gap-closure round (plan 239-11, 2026-09-18) — appended, not a rewrite

Appended in the style plan 239-07 established: prior rows and the plan-239-07 correction block are
byte-unchanged; this block only adds. Accurate as of parent commit `74e6a148` and the two commits
this plan adds on top of it (sweep `7eee6b00`, mirror recorded in `239-11-SUMMARY.md`).

| Template (batch-3 edit) | Disposition |
|---|---|
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` (239-11, WR-01 + WR-02/SC-1 gap 1) | **Mirrored →** `test/example/lib/example_web/live/invitation_accept_live.ex`. Two regions mirrored: the four-line `@moduledoc` WR-01 replacement (net **+2** lines, replacing 2) and the deletion of the `plan-checker` comment line (net **−1**). Counterpart line located by reading the file, not by copying the template's `:326` — it sat at `:332` before the moduledoc replacement and at `:334` after. Post-substitution diff of both changed regions: **empty**. `grep -cF 'generates no tests'` → **1**; `grep -cF 'DO NOT add an accept button here'` → **1**; `grep -cF 'Jetstream #907 / CVE-2026-1529'` → **1**. |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` (239-11, WR-03/SC-1 gap 2) | **Mirrored →** `test/example/lib/example_web/live/organization_members_live.ex`. One region mirrored: the `## Architecture` pagination bullet gains its terminator and the `v1.2 concern` sentence is deleted (net **−1** line, 1 line modified). Post-substitution diff of the changed bullet: **empty**. One residual difference in the wider `## Architecture` block — `class="modal"` vs `class="vt-modal"` — is **pre-existing demo-app `vt-*` brand drift**, reproduced identically at base `74e6a148`, outside every region this batch changed, and deliberately not reconciled here. |

### Router re-derivation — enumeration confirmed against the bytes, not inherited

A prior plan's enumeration missed a sixth router site, so both flagged sites in
`test/example/lib/example_web/router.ex` were re-read at this commit rather than carried forward:

| Site | Disposition |
|---|---|
| `:103` — `# Login page is a plain controller, not a LiveView.` | **n/a — carries no batch-3 text.** Mechanism-only; no plan vocabulary; no V3 hit. Not edited by this batch. |
| `:175-179` — the dev-only Swoosh mailbox-preview comment block | **n/a — carries no batch-3 text.** Already de-bookkept by plan 239-07 (C-1 above); no V3 hit at this commit. Not edited by this batch. |

The batch-3 edit set is therefore exactly the two counterpart files above. The router is absent from
both of this plan's commits.


## Batch-4 closure round (plan 239-14, 2026-09-18) — appended, not a rewrite

Appended in the style plan 239-11 established: prior rows and blocks are byte-unchanged; this block
only adds. Accurate as of parent commit `baa01104` and the two source commits plan 239-14 adds on top
of it (template `7592e760`, mirror recorded in `239-14-SUMMARY.md`).

Batch 4 is a **retraction**: plan 239-11's WR-01 replacement asserted `mix sigra.install` generates no
tests, which is false on the bytes (`lib/sigra/install/features/admin.ex:38-39` maps
`admin/policy_test.exs` to `test/<otp_app>/sigra_admin_policy_test.exs`). D-31 retracts it; the
corrected prose makes no claim about installer output at all.

| Template (batch-4 edit) | Disposition |
|---|---|
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` (239-14, WR-01 retraction / D-31) | **Mirrored →** `test/example/lib/example_web/live/invitation_accept_live.ex`. One region mirrored: the closing two lines of the `## Structural Jetstream #907 defense` paragraph (2 removed, 2 added; paragraph line count **8 → 8**, unchanged). Counterpart line numbers **re-derived by reading the file**, never copied from the template and never cited from plans 239-11 or 239-12, whose numbers the batch-3 re-bless `87581665` invalidated: the defense heading at `:14`, the anchor line at `:19`, the retracted clause at `:21` pre-edit, and the invariant comment at `:331`/`:334` against the template's `:325`/`:328`. Post-substitution diff of the changed region (`sed -n '16,23p'` from each tier): **empty**. `/usr/bin/grep -cF 'mix sigra.install` generates no tests'` → **0** with a live positive control `/usr/bin/grep -cF 'by construction, not by convention'` → **1** on the same file; `/usr/bin/grep -cF 'does not inherit that assertion'` → **1**; `/usr/bin/grep -cF 'DO NOT add an accept button here'` → **1**; `/usr/bin/grep -cF 'Jetstream #907 / CVE-2026-1529'` → **1**. |

No other template was edited by batch 4, so no other counterpart is in scope. The batch-4 edit set is
exactly the one counterpart file above; `test/fixtures/install_golden/`, `.github/` and
`.planning/REQUIREMENTS.md` are absent from both of plan 239-14's source commits. Full per-command
evidence is in `239-EVIDENCE.md` § `## BATCH-4-SWEEP-COMMIT`.
