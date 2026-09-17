# Phase 239: `priv/templates/` Sweep + One Batched Re-bless — Research

**Researched:** 2026-09-17
**Measured at:** HEAD `66721b74`, `origin/main` `6b03af05` (working tree clean except `M .planning/state.json`)
**Domain:** Repo-hygiene sweep of a code-generator template corpus + golden-fixture re-bless
**Confidence:** HIGH (every number below was re-measured this session with a pasted command; no training-data claims)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

CONTEXT.md carries **25 locked decisions (D-01…D-25)**. They are authoritative and are NOT re-derived
here. This research only closes the *executable* gaps. The constraints that bind the plan most tightly:

### Locked Decisions (verbatim anchors — read `239-CONTEXT.md` in full before planning)

- **D-01** — the hard-fail token set (6 classes) applies to **all** files under `priv/templates/`.
- **D-02** — plans target the **full** token set, not SC-1's single cited `.planning/` line.
- **D-03** — deliberate exclusions: `admin/policy.ex:17` (`# TODO:`), `XXXX-XXXX` placeholders,
  `core/sigra_auth.css:156`, `core/scope.ex:22` (`UPGRADE-v1.2.md`), arity/version strings.
- **D-04** — 239 **builds no guard**; it writes the spec `p18` (Phase 241) will mechanize.
  `test/fixtures/prohibitions/` stays untouched.
- **D-05/D-06/D-07** — SC-2 is `grep -rn '\.planning/' <unpacked>/lib <unpacked>/priv` → 0 hits, and
  the scoping rationale is recorded in the SUMMARY as a positive artifact.
- **D-09/D-10/D-11** — golden fixture is a byte-for-byte tree; `--check` exit 0 = clean, 2 = drift;
  the task never stages or commits.
- **D-12** — the HEEx `~H` subset is a distinct, carefully-reviewed slice.
- **D-13** — `STDOUT.txt` can drift independently; check it separately.
- **D-16/D-17/D-18** — rationale preservation via the committed
  `237-security-comment-diff-check.sh`; the co-occurrence lines are **rewritten**, not stripped, with
  human-readable before/after in the plan.
- **D-19** — **three commits, in order**: (1) sweep `priv/templates/` only; (2) mirror
  `test/example/` counterparts only; (3) re-bless `test/fixtures/install_golden/` only.
  The mirror must **not** be in commit 3.
- **D-23** — the sweep is **path-restricted at the command level**. A repo-wide `sed` is the single
  most dangerous possible implementation.
- **D-24/D-25** — the `ci.yml:450` detector gap and FUT-01 are filed as **todos**, not fixed.

### Claude's Discretion

- Exact rewritten wording of the rationale-preserving comments (sentence survives, token goes).
- Whether the HEEx subset gets its own plan or a marked section.
- Plan count/granularity inside the three-commit topology.
- Whether the `lib/sigra/install/` manifest is read up front or only for the ambiguous renames
  (**this research already read it — see §3; no further reading needed**).

### Deferred Ideas (OUT OF SCOPE)

FUT-01 parity guard · the `ci.yml:450` detector gap · the `p18` guard (Phase 241/SURF-04) ·
whole-tarball `.planning/` cleanliness with an allowlist · the `lib/` inline-comment ratchet.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (`REQUIREMENTS.md`) | Research Support |
|----|---------------------------------|------------------|
| **SURF-01** | "Zero `.planning/` path references remain in `lib/` or `priv/templates/` — verified by grepping a **freshly generated app** and the `mix hex.build` tarball, not the source tree." | §1 (the single `.planning/` line, located), §4-SC1 (`install-smoke.sh` runnable recipe), §4-SC2 (tarball built and grepped **this session**, §1.4) |
| **SURF-03** | "`priv/templates/` carries no planning bookkeeping, landed as one sweep plus **one** batched `mix sigra.fixture.rebless_golden`, in separate commits. Only the `test/example/` counterparts of edited templates are mirrored." | §2 (authoritative 158-line edit list), §3 (authoritative mirror map), §4-SC3 (re-bless recipe + exit semantics), §5.1 (the comment-only-diff classifier trap) |
</phase_requirements>

---

## Summary

Every measured claim in CONTEXT.md is **directionally correct and materially reproducible at HEAD**,
but **three of its counts are low**, and one structural assumption baked into SC-3 is **wrong in a way
that will stop the line spuriously** unless the plan fixes it first.

The corrections, in order of blast radius:

1. **The `priv/templates/` surface is 158 token-bearing lines across 46 files, not 154/45.** The six
   per-class counts match CONTEXT *exactly* (1 / 51 / 98 / 9 / 5 / 34); the difference is entirely in
   the de-duplicated union. Acceptance criteria built on "154" will be off by four lines and one file.
2. **Only 80 of those 158 lines are `#`/`//`/`/*` comments.** 57 are `@moduledoc`/`@doc` **heredoc
   prose** lines and 4 are single-line `@doc "…"` strings — neither is a comment in any grep sense.
   SC-3's "diff contains only comment lines" test, if implemented as `^[+-]\s*#`, will flag **61
   legitimate lines** as stop-the-line events. The plan must define the classifier *before* the sweep
   plan is written, not discover it during the re-bless. This is the single highest-value finding here.
3. **The golden tree carries 139 token lines across 35 files, not 133/33** (84 tracked files under
   `tree/`, not 85 — the 85th is `STDOUT.txt`, a sibling of `tree/`, not a member).

Two hazards resolve **in the plan's favour**: `STDOUT.txt` currently contains **zero** token-set hits,
so the D-13 independent-drift risk is measured-nil (still check it — a swept line could newly *enter*
summary output, though nothing in the edit list is summary text); and `git diff origin/main -- .github/`
is currently **empty**, so the SC-5 infrastructure guard has a genuine zero baseline and any hit in it
is attributable to this phase alone.

The D-21 open question is **CONFIRMED, not refuted**, from the authoritative manifest.

**Primary recommendation:** Plan four units in D-19's three-commit topology — (0) a *classifier
definition* micro-unit that pins what "comment line" means for SC-3 and proves the classifier fires
on a synthetic non-comment line; (1) the sweep, split into plain-strip / rationale-rewrite / HEEx
subsets; (2) the per-file mirror; (3) the single batched re-bless. Never a repo-wide `sed`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Bookkeeping strip | Source templates (`priv/templates/`) | — | The generator corpus is the only writable origin of adopter-visible text |
| Generated-app assertion (SC-1) | CI script (`scripts/ci/install-smoke.sh`) | Local shell + Postgres | The only existing machinery that leaves a real generated app on disk |
| Shipped-artifact assertion (SC-2) | Build tooling (`mix hex.build --unpack`) | — | The tarball is the vehicle adopters actually download |
| Golden snapshot | Test fixture (`test/fixtures/install_golden/`) | `mix sigra.fixture.rebless_golden` | Byte-for-byte mirror; regenerated, never hand-edited |
| Example mirror | Hand-maintained app (`test/example/`) | — | Drifts by design; per-file checklist, never a blanket copy |
| Rationale preservation (SC-5b) | Committed phase artifact (`237-security-comment-diff-check.sh`) | — | Already proven RED; reused, not rewritten |
| Infrastructure invariance (SC-5a) | `git diff origin/main -- .github/` | — | Read-only; zero `.github/` edits in scope |
| Future enforcement | `scripts/ci/prohibitions/p18-*.test.mjs` | — | **Phase 241**, not here |

---

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `/Users/jon/projects/sigra/CLAUDE.md`, binding on this plan:

- **GSD Workflow Enforcement** — no direct repo edits outside a GSD workflow.
- **`mix test` requires a live Postgres** (`postgres`/`postgres`, db `sigra_test`). Preferred boot:
  `scripts/db/up.sh` → `tmp/db.env` → `direnv allow` or `source tmp/db.env`. Falls back to
  `localhost:5432` when unset. Override via `SIGRA_TEST_PG_*`, **not** libpq `PG*`.
- **The install golden tests require phx_new 1.8.8 locally** —
  `mix archive.install --force hex phx_new 1.8.8`. A different archive version produces spurious
  byte-diffs against the committed fixture. `[VERIFIED: mix archive → phx_new-1.8.8 installed]`
- **Testing:** comprehensive spec coverage, AAA style, flat, self-contained.
- **Minimal transitive deps; copy-paste over deps** where code is small and stable.
- **`mix ci`, never root `mix test`, before every push** (also Standing Constraint 3).
- **Admin UI direction** — not engaged by this phase (no admin surface is touched).

---

## §1 — Re-verified measurements at HEAD

### 1.1 `priv/templates/` corpus size

```bash
find priv/templates -type f | wc -l   # 120
git ls-files priv/templates | wc -l   # 119
```
`[VERIFIED: command output this session]` — confirms **D-08**: 119 tracked, the 120th being the
gitignored `priv/templates/.DS_Store`. No action.

### 1.2 Per-class token counts (the D-01 table, re-run)

Command shape used for each row (over `git ls-files priv/templates`):

```bash
grep -nE '<CLASS-REGEX>' $(git ls-files priv/templates) | wc -l
grep -lE '<CLASS-REGEX>' $(git ls-files priv/templates) | wc -l
```

| Class | Regex | CONTEXT lines | **HEAD lines** | CONTEXT files | **HEAD files** | Verdict |
|---|---|---|---|---|---|---|
| Planning path | `\.planning/` | 1 | **1** | 1 | **1** | ✅ match |
| Phase reference | `[Pp]hase[ -][0-9]+` | 51 | **51** | 22 | **22** | ✅ match |
| Decision id | `\bD-[0-9]{2}\b` | 98 | **98** | 39 | **39** | ✅ match |
| Plan number | `\bPlan [0-9]{2}\b` | 9 | **9** | 4 | **4** | ✅ match |
| GSD artifact filename | `[0-9]{3}-[A-Z0-9-]+\.md`, `[0-9]{2}-CONTEXT\.md` | 5 | **5** | 2 | **2** | ✅ match |
| Requirement/criterion ids | `SC-[0-9]`\|`ORG-UX-[0-9]{2}`\|`GATE-0[0-9]`\|`UI-SPEC`\|`DX-[0-9]{2}`\|`IN-[0-9]{2}`\|`T-[0-9]+-[0-9]+`\|`\bB[0-9]\b` | ~34 | **34** | — | **18** | ✅ match |
| **UNION (de-duplicated)** | all six OR'd | **154 / 45** | **158 / 46** | | | ⚠️ **DIVERGENCE: +4 lines, +1 file** |

`[VERIFIED: grep over git ls-files priv/templates at 66721b74]`

> **LOUD:** the per-class numbers are perfect; the **union** is not. CONTEXT's 154/45 appears to be a
> de-duplication artifact. **Plans must state 158 lines / 46 files.** Acceptance criteria and the
> SUMMARY ledger should carry the HEAD number with this note, so a reviewer sees the correction was
> deliberate rather than sloppy.

Sub-class occurrence detail for the fuzziest class (bare `B[0-9]`), so the planner can sanity-check
false positives — all three are real bookkeeping:

```
core/login_html.ex:5        Per Phase 10.1.1 D-12 / B9, the login page is a plain controller +
core/registration_live.ex:115  # D-05: deliver confirmation email (B5 repair; …)
core/user_token.ex:28       # B6 (Plan 10.1.1-03): session token helpers were REMOVED. …
```
`[VERIFIED: grep -nE '\bB[0-9]\b' over priv/templates]`

Other req-id occurrences: `UI-SPEC` ×10, `GATE-02` ×5, `T-17-10` ×2, `ORG-UX-03` ×2, `IN-06` ×2,
`IN-03` ×2, `T-8-15`, `T-16-05`, `T-14-06`, `SC-4`, `ORG-UX-{06,07,08,09}`, `IN-05`, `DX-03` ×1 each.

### 1.3 Golden tree

```bash
git ls-files test/fixtures/install_golden/tree | wc -l          # 84
grep -rnE '<UNION>' test/fixtures/install_golden/tree | wc -l   # 139 lines / 35 files
grep -nE '<UNION>' test/fixtures/install_golden/STDOUT.txt      # (no output)
grep -rn '\.planning/' test/fixtures/install_golden/            # 1 hit
```

| | CONTEXT (D-10) | **HEAD** | Verdict |
|---|---|---|---|
| Golden token lines | 133 | **139** | ⚠️ **DIVERGENCE +6** |
| Golden files touched | 33 | **35** | ⚠️ **DIVERGENCE +2** |
| `tree/` files tracked | 85 | **84** | ⚠️ (the 85th is `STDOUT.txt`, sibling of `tree/`) |
| `STDOUT.txt` token lines | "can drift independently" | **0** | ✅ measured nil today |
| `.planning/` in golden | 1 (`organizations.ex:59`) | **1**, at `tree/lib/sigra_install_golden_tmp/organizations.ex:59` | ✅ match |

`[VERIFIED: grep over test/fixtures/install_golden at 66721b74]`

**Expected re-bless diff size: ~139 changed lines across ~35 files** (plus/minus the exact rewrite
wording), *not* 133/33.

### 1.4 The `mix hex.build` tarball — built and unpacked **this session**

```bash
cp -R . <scratch>/hb && cd <scratch>/hb && mix hex.build --unpack   # → "Saved to sigra-1.5.0"
cd sigra-1.5.0
for d in lib priv docs; do echo "$d: $(grep -rn '\.planning/' $d | wc -l)"; done
grep -c '\.planning/' README.md CHANGELOG.md mix.exs
grep -rn '\.planning/' lib priv      # the SC-2 command
```

| Location | CONTEXT (D-05) | **Measured this session** |
|---|---|---|
| `lib/` | 0 | **0** ✅ |
| `priv/` | 1 | **1** ✅ |
| `docs/` | 12 | **12** ✅ |
| `README.md` | 1 | **1** ✅ |
| `CHANGELOG.md` | 19 | **19** ✅ |
| `mix.exs` | 0 | **0** ✅ |

The single `priv/` hit, verbatim:

```
priv/templates/sigra.install/organizations/organizations.ex:59:  # configured @sigra_org_config. See .planning/phases/16-org-liveviews-switcher/
```

Tarball also carries `priv/templates` = **119 files** and **158** union-token lines (identical to
source), confirming `priv/templates/` ships in full. `[VERIFIED: mix hex.build --unpack, Hex build of
version 1.5.0, run 2026-09-17]`

**D-05/D-06/D-07 are fully reproduced.** Nothing about SC-2 needs re-deriving.

### 1.5 `.github/` bookkeeping volume (D-23) and the SC-5a baseline

```bash
git diff --name-only origin/main -- .github/ | wc -l   # 0
grep -rE '^\s+name:' .github/workflows/*.yml | wc -l   # 45 (job/step names)
grep -E '^name:' .github/workflows/*.yml | wc -l       # 9 (top-level workflow names)
```

Token-line volume per `.github/` file (union regex minus the GSD-filename class):

| File | CONTEXT | **HEAD** |
|---|---|---|
| `.github/workflows/ci.yml` | 93 | **101** |
| `.github/workflows/ci-observe.yml` | 8 | **8** |
| `.github/workflows/release-please.yml` | 5 | **5** |
| `.github/ci-skip-manifest.tsv` | 8 | **8** |
| **Total** | 114 | **122** |

`[VERIFIED: per-file grep -c over git ls-files .github at 66721b74]` — divergence is explained by
regex breadth (my class set includes `IN-`/`T-`/`SC-` which CONTEXT's `.github` tally may not have).
The *direction* of D-23 is unchanged and stronger: a repo-wide sweep would rewrite **122** lines in
load-bearing workflow YAML.

**SC-5a baseline is zero today** — `git diff --name-only origin/main -- .github/` returns nothing.
So the SC-5a assertion has a clean, attributable zero, and does **not** need a "pre-existing drift"
carve-out. `[VERIFIED: git diff --name-only origin/main -- .github/ → empty]`

### 1.6 `test/example/` volume — the scoping trap

```bash
grep -rlE '<UNION>' $(git ls-files test/example) | wc -l   # 94 files
grep -rnE '<UNION>' $(git ls-files test/example) | wc -l   # 476 lines
```

**`test/example/` repo-wide carries 476 token lines across 94 files.** The counterpart-only scope
mandated by D-19/SC-4 is **~110 lines across 31 files** (per-file table in §3.2). A plan that
"sweeps `test/example/` too" would be **4.3× over scope** and would collide with surfaces this
milestone has not cleared. `[VERIFIED: grep over git ls-files test/example]`

---

## §2 — The authoritative edit list (158 lines / 46 files)

The full `file:line:text` listing was produced this session and is reproducible with:

```bash
grep -nE '\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b' \
  $(git ls-files priv/templates)
```

**Run that command as the first action of the sweep plan and diff its output against the ledger
below.** If the counts differ, HEAD has moved and the ledger is stale.

### 2.1 Per-file distribution (46 files)

| Lines | File (under `priv/templates/`) |
|---:|---|
| 19 | `sigra.install/organizations/live/organization_members_live.ex` |
| 13 | `sigra.install/organizations/migration.exs` |
| 11 | `sigra.install/organizations/organizations.ex` |
| 11 | `sigra.install/organizations/live/organization_settings_live.ex` |
| 8 | `sigra.install/core/auth_fixtures.ex` |
| 7 | `sigra.install/core/user_auth.ex` |
| 7 | `sigra.install/core/sigra_auth.css` |
| 6 | `sigra.install/organizations/live/organizations_live/index.ex` |
| 4 | `organizations/organization_invitation_email.ex`, `core/settings_live.ex`, `core/mfa_settings_live.ex`, `core/mfa_challenge_html.ex`, `core/emails.ex`, `core/auth.ex` |
| 3 | `organizations/controllers/organization_switch_controller.ex`, `organizations/components/org_switcher.ex`, `core/token_controller.ex`, `core/reset_password_live.ex`, `core/reset_password_controller.ex`, `core/migration.exs`, `core/mfa_challenge_live.ex`, `core/audit_event.ex` |
| 2 | `organizations/router_injection.ex`, `organizations/organization_invitation.ex`, `organizations/organization.ex`, `organizations/live/invitation_accept_live.ex` |
| 1 | `sigra.upgrade/data_migration.exs`, `sigra.upgrade/alter_add_personal.exs`, `sigra.upgrade/alter_add_owner_user_id.exs`, `organizations/user_auth_on_mount_assign_user_organizations.ex`, `organizations/live/organizations_live/new.ex`, `core/user_token.ex`, `core/user.ex`, `core/sudo_html.ex`, `core/sudo_controller.ex`, `core/scope.ex`, `core/reset_password_html.ex`, `core/registration_live.ex`, `core/mfa_settings_html.ex`, `core/mfa_challenge_controller.ex`, `core/login_html.ex`, `core/error_handler.ex`, `core/confirmation_live.ex`, `core/api_token_created_email.ex`, `admin/admin_hooks.js`, `sigra.gen.oauth/oauth_settings_live.ex` |

`[VERIFIED: cut -d: -f1 union.txt | sort | uniq -c]`

Note: **`core/confirmation_live.ex`** (`:131`, `10.1 IN-06`) and
**`organizations/live/organizations_live/new.ex`** (`:8`, `D-07`) appear in the HEAD list but are not
in any CONTEXT enumeration — two of the four "extra" lines.

Generator breakdown: `sigra.install/` **43** files, `sigra.upgrade/` **3**,
`sigra.gen.oauth/` **1**. All three generators are touched, so the D-24 detector gap
(`ci.yml:450` omits `sigra.upgrade/` and `sigra.gen.oauth/`) does **not** bite this phase — the diff
also touches `sigra.install/`, so `install_golden_contract` runs.
`[VERIFIED: .github/workflows/ci.yml:450 read this session]`

### 2.2 Partition (a) — plain strip

**127 lines across 43 files.** Defined as: token-bearing lines with **no** rationale-class word
(`security|secure|CSRF|enumeration|timing|scope|impersonation|XSS|phishing|authz|attack|leak|guard|invariant|defense|prevent*`)
anywhere in a ±4-line window. These can be mechanically stripped with a path-restricted per-file edit.

### 2.3 Partition (b) — rewrite-with-rationale (the D-17 set)

**31 lines across 14 files** — CONTEXT estimated ~23. Larger, because the ±4-line window catches
neighbours CONTEXT's narrower vocabulary missed. Full list:

```
core/auth.ex:530                 # token clause so security signals are preserved (10.1 IN-03). Tokens
core/auth.ex:532                 # fresh session after reset (D-29).
core/auth_fixtures.ex:319        # non-uniform map containing only the keys the scenario needs (D-04).
core/auth_fixtures.ex:321        # locked, unconfirmed) deliberately omit :conn (D-07).
core/mfa_challenge_controller.ex:24    # Not in MFA pending state -- redirect appropriately (D-35)
core/reset_password_controller.ex:21   regardless of whether the email exists (enumeration prevention, D-38).
core/scope.ex:70                 active-organization transitions (Phase 14 D-15).
core/user_auth.ex:346            # Phase 16 D-26: assigns `@user_organizations` to the socket for the
core/user_auth.ex:512            Per D-33: auto-inserted into authenticated pipeline by generator.
organizations/controllers/organization_switch_controller.ex:6    ORG-UX-03). Body: `%{"organization_id" => id, …}`
organizations/controllers/organization_switch_controller.ex:10   organization ids return 404 for enumeration prevention (D-04).
organizations/live/invitation_accept_live.ex:20   17-UI-SPEC §Structural Invariants and enforced by plan-checker grep.
organizations/live/organization_members_live.ex:632  # …returns nil (T-16-05-03).
organizations/live/organization_members_live.ex:633  # The Plan 01 library also scopes mutations by organization_id so a foreign
organizations/live/organization_members_live.ex:637  # …on first use. For the Phase 16
organizations/live/organization_settings_live.ex:21  (D-04), not 403.
organizations/migration.exs:33   # D-01 / D-03: at-most-one-personal-org-per-user. Structural invariant AND
organizations/migration.exs:34   # insert-safety backstop for Sigra.Upgrade.Backfill (Plan 18-02). Postgres
organizations/migration.exs:73   # Partial unique index: prevent duplicate pending invites per org+email (D-12).
organizations/migration.exs:143  # D-01: MySQL/SQLite lack partial unique indexes. Application-level guard
organizations/organization_invitation_email.ex:6   # (and the phase-17 verifier) can locate the invitation-email logic
organizations/organization_invitation_email.ex:12  #     html_escape_string/1 (XSS defense — T-17-10).
organizations/organization_invitation_email.ex:14  #     (phishing defense — T-17-10 spoofing).
organizations/organizations.ex:16   (membership-before-write — T-14-06 authz choke point).
organizations/organizations.ex:62   # These call Sigra.Organizations functions added in Phase 16 Plan 01.
organizations/organizations.ex:65   @doc "Rename an organization (D-10 — inline, no password required)."
organizations/organizations.ex:75   @doc "Update an organization's slug (D-11 — requires inline password + typed confirm)."
organizations/organizations.ex:85   @doc "Soft-delete an organization (D-11 — requires inline password + typed confirm)."
organizations/organizations.ex:96   # `use Sigra.Organizations` above (Phase 16 Plan 01). Do not redeclare them
organizations/organizations.ex:99   @doc "Change a member's role with last-owner guard (D-18)."
organizations/user_auth_on_mount_assign_user_organizations.ex:6   can switch into (D-26).
```
`[VERIFIED: python3 ±4-line window scan over the 46 union files, this session]`

**Same-line co-occurrence set (10 lines)** — the sharpest cases, where the token and the rationale
live on one line and a strip destroys meaning. CONTEXT named 5 + 1; HEAD measures **10**:

| File:line | Text |
|---|---|
| `core/auth.ex:530` | `# token clause so security signals are preserved (10.1 IN-03). Tokens` |
| `core/reset_password_controller.ex:21` | `regardless of whether the email exists (enumeration prevention, D-38).` |
| `organizations/controllers/organization_switch_controller.ex:10` | `organization ids return 404 for enumeration prevention (D-04).` |
| `organizations/migration.exs:33` | `# D-01 / D-03: at-most-one-personal-org-per-user. Structural invariant AND` |
| `organizations/migration.exs:73` | `# Partial unique index: prevent duplicate pending invites per org+email (D-12).` |
| `organizations/migration.exs:143` | `# D-01: MySQL/SQLite lack partial unique indexes. Application-level guard` |
| `organizations/organization_invitation_email.ex:12` | `#     html_escape_string/1 (XSS defense — T-17-10).` |
| `organizations/organization_invitation_email.ex:14` | `#     (phishing defense — T-17-10 spoofing).` |
| `organizations/organizations.ex:16` | `(membership-before-write — T-14-06 authz choke point).` |
| `organizations/organizations.ex:99` | `@doc "Change a member's role with last-owner guard (D-18)."` |

CONTEXT's `router_injection.ex:1` and `invitation_accept_live.ex:3` ("Phase 17 D-06: single
unscoped…") are **not** in this set at HEAD — they carry no rationale-class word; they're plain
strips. `organizations.ex:99` and the three `migration.exs` lines are **new** additions.

### 2.4 Partition (c) — the HEEx subset (D-12)

**17 lines across 7 files**, not ~15. Every one is an **EEx-escaped** `<%%`/`<%%=` tag:

| File | Lines | Escaped form |
|---|---|---|
| `core/settings_live.ex` | 66, 77, 107, 159 | `<%%=` → renders `<%= # … %>` |
| `organizations/live/organization_settings_live.ex` | 60, 69, 117 | `<%%=` → renders `<%= # … %>` |
| `core/mfa_challenge_live.ex` | 290, 297 | `<%%` → renders `<% # … %>` |
| `core/mfa_settings_live.ex` | 88, 528, 561 | `<%%` |
| `core/mfa_challenge_html.ex` | 25, 128, 135 | `<%%` |
| `core/mfa_settings_html.ex` | 48 | `<%%` |
| `core/reset_password_live.ex` | 93 | `<%%` |

**Verified downstream rendering** — the generated form is present verbatim in the golden tree:

```
tree/…_web/live/settings_live.ex:66:      <%= # Force password change banner (D-58) %>
tree/…_web/live/mfa_challenge_live.ex:288:      <% # Remaining attempts hint (D-38) %>
```
`[VERIFIED: grep -rn '<%= #' and '<% #' test/fixtures/install_golden/tree]`

So the **template line number ≠ golden line number** (template `:290` → golden `:288`: the EEx
header shifts by 2). The mirror/re-bless plans must map by **content**, not line number.

Risk assessment for this subset: `<% # … %>` and `<%= # … %>` inside `~H` are compile-time comments
that emit no markup — deleting them cannot change rendered HTML. The real risk is **malformed
deletion** (removing `<%%` but leaving `%>`, or deleting a line that was actually load-bearing
markup). Mitigate by compiling: `mix compile --warnings-as-errors` in `test/example/` plus the
`install_smoke` compile step, both of which parse every `~H` sigil.

### 2.5 The syntactic-kind split — **the SC-3 trap**

| Kind | Count | Example |
|---|---:|---|
| `#` comment (Elixir) | **73** | `core/user_auth.ex:32` |
| `@moduledoc`/`@doc` **heredoc prose** (not a comment) | **57** | `core/audit_event.ex:49-51` |
| EEx-escaped HEEx comment (`<%%`/`<%%=`) | **17** | `core/settings_live.ex:66` |
| JS/CSS comment (`//`, `/*`, `*`) | **7** | `admin/admin_hooks.js:421`, `core/sigra_auth.css:514` |
| `@doc "…"` single-line string | **4** | `organizations/organizations.ex:65,75,85,99` |
| **Total** | **158** | |

`[VERIFIED: python3 per-line syntactic classification over union.txt, this session]`

> **LOUD — this is the finding most likely to derail execution.** SC-3 says the re-bless diff must
> contain "**only comment lines**". At HEAD, **only 80 of 158 (51%) are comments in any grep sense**.
> The other 78 are `@doc`/`@moduledoc` prose and EEx tags. A naïve classifier
> (`git diff … | grep -E '^[+-]' | grep -vE '^[+-]\s*(#|//|/\*|\*)'` → expect empty) **fails on 78
> legitimate lines.** The plan must define the accepted-line predicate up front. §5.1 gives one.

---

## §3 — The template → target mapping (D-21 **CONFIRMED**)

### 3.1 The authoritative manifest: where it is and how to read it

The installer's template→target manifest is **not** a data file — it is Elixir list literals in the
feature modules:

| Module | Role |
|---|---|
| `lib/sigra/install/features/core.ex` | core schemas, context, plugs, UI, migrations |
| `lib/sigra/install/features/organizations.ex` | org schemas, LiveViews, controllers, migrations, router injection |
| `lib/sigra/install/features/admin.ex` | admin surface + router injection |
| `lib/sigra/install/features/passkeys.ex` | passkey surface + router injection |
| `lib/mix/tasks/…` (oauth generator) | `sigra.gen.oauth` targets |

Entry shape (90 such entries across the four feature modules):

```elixir
{:eex, "<template path relative to priv/templates/sigra.install/>", Path.join([<target segments>])}
```

Read a mapping with:

```bash
grep -rn '"<template-relative-path>"' lib/sigra/install/features/ lib/mix/tasks/
```

Migrations use an indirection — `migration_target(binding, slot_key, basename)` at
`lib/sigra/install/features/core.ex:75-82`, which resolves to
`priv/repo/migrations/<timestamp>_<basename>.exs`, falling back to the literal `TIMESTAMP` when no
allocation map is threaded (which is how the golden fixture gets its `TIMESTAMP_` prefix).
`[VERIFIED: lib/sigra/install/features/core.ex:70-82 read this session]`

Templates delivered by **injection** (not `{:eex, …}` file emission) have no target entry and
therefore no `test/example/` counterpart by construction: `organizations/router_injection.ex`
(`organizations.ex:247-248`), `admin/admin_hooks.js`, `core/api_token_created_email.ex`,
`organizations/organization_invitation_email.ex` (documented at `organizations.ex:152`),
`organizations/user_auth_on_mount_assign_user_organizations.ex`, and all three `sigra.upgrade/*.exs`.

### 3.2 The four renamed counterparts — resolved

| Template | Manifest citation | Generated target | `test/example/` counterpart | On disk? |
|---|---|---|---|---|
| `core/login_html.ex` | `features/core.ex:286` and `:310` — `{:eex, "core/login_html.ex", Path.join(["lib", web, "controllers", "session_html.ex"])}` | `lib/<app>_web/controllers/session_html.ex` | `test/example/lib/example_web/controllers/session_html.ex` | ✅ **CONFIRMED** |
| `core/error_handler.ex` | `features/core.ex:195` | `lib/<app>_web/auth_error_handler.ex` | `test/example/lib/example_web/auth_error_handler.ex` | ✅ |
| `core/auth.ex` | `features/core.ex:191` — `Path.join(["lib", otp_app, "#{ctx}.ex"])` | `lib/<app>/<context>.ex` | `test/example/lib/example/accounts.ex` | ✅ |
| `core/migration.exs` | `features/core.ex:157` + `migration_target(:primary, "create_sigra_auth_tables.exs")` | `priv/repo/migrations/<ts>_create_sigra_auth_tables.exs` | `test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs` | ✅ |
| `organizations/migration.exs` | `features/organizations.ex:73` + `migration_target(:organizations, "create_organizations.exs")` | `priv/repo/migrations/<ts>_create_organizations.exs` | `test/example/priv/repo/migrations/20260410125245_create_organizations.exs` | ✅ |

`[VERIFIED: lib/sigra/install/features/core.ex:157,191,195,286,310; features/organizations.ex:73; file existence checked with test -f]`

> **D-21's open question is CONFIRMED, not refuted.** `core/login_html.ex` →
> `test/example/lib/example_web/controllers/session_html.ex`. The comment directly above the manifest
> entry even says so: `# login_html.ex renders into session_html.ex — always present`
> (`features/core.ex:284`). No further manifest reading is needed; the planner may take the
> discretion option "read only for the 4 ambiguous renames" as **already done**.

### 3.3 The mirror ledger (SC-4's per-file checklist, pre-computed)

Token lines in each `test/example/` counterpart at HEAD, i.e. the exact edit budget for commit 2:

| Lines | `test/example/…` | Source template |
|---:|---|---|
| 18 | `lib/example_web/live/organization_members_live.ex` | `organizations/live/organization_members_live.ex` |
| 12 | `lib/example/organizations.ex` | `organizations/organizations.ex` |
| 11 | `lib/example_web/live/organization_settings_live.ex` | `organizations/live/organization_settings_live.ex` |
| 8 | `test/support/fixtures/auth_fixtures.ex` | `core/auth_fixtures.ex` |
| 7 | `lib/example_web/user_auth.ex` | `core/user_auth.ex` |
| 4 | `lib/example/accounts/emails.ex` · `lib/example_web/live/mfa_settings_live.ex` · `priv/static/assets/sigra_auth.css` · `lib/example/accounts.ex` · `lib/example_web/live/organizations_live/index.ex` | `core/emails.ex` · `core/mfa_settings_live.ex` · `core/sigra_auth.css` · `core/auth.ex` · `organizations/live/organizations_live/index.ex` |
| 3 | `lib/example/accounts/audit_event.ex` · `lib/example_web/live/mfa_challenge_live.ex` · `lib/example_web/live/reset_password_live.ex` · `lib/example_web/controllers/reset_password_controller.ex` · `lib/example_web/controllers/organization_switch_controller.ex` | respective templates |
| 2 | `lib/example/accounts/scope.ex` · `lib/example_web/live/invitation_accept_live.ex` · `lib/example_web/components/org_switcher.ex` · `lib/example/accounts/organization.ex` | respective |
| 1 | `lib/example_web/live/registration_live.ex` · `lib/example_web/live/confirmation_live.ex` · `lib/example_web/controllers/reset_password_html.ex` · `lib/example_web/controllers/auth/sudo_controller.ex` · `lib/example_web/controllers/auth/sudo_html.ex` · `lib/example/accounts/user.ex` · `lib/example/accounts/user_token.ex` · `assets/js/admin_hooks.js` · `lib/example_web/controllers/session_html.ex` · `lib/example_web/live/organizations_live/new.ex` · `priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs` | respective |
| **0** ⚠️ | `lib/example_web/live/settings_live.ex` · `lib/example_web/auth_error_handler.ex` · `lib/example/accounts/organization_invitation.ex` · `priv/repo/migrations/20260410125245_create_organizations.exs` | `core/settings_live.ex` (4 tokens) · `core/error_handler.ex` (1) · `organizations/organization_invitation.ex` (2) · `organizations/migration.exs` (13) |

**Mirror budget: ~110 lines across 31 files.**
`[VERIFIED: per-file grep -cE over test/example counterparts]`

> The four **0-line** rows are the concrete evidence FUT-01 needs: the example has already diverged
> from the templates. `organizations/migration.exs` has **13** token lines and its example
> counterpart has **0** — a 13-line divergence in a single file. Attach this table to the FUT-01
> todo as its diagnosis (D-25).

### 3.4 Confirmed no-counterpart set (D-22)

`sigra.gen.oauth/oauth_settings_live.ex`, `core/api_token_created_email.ex`,
`core/mfa_challenge_controller.ex`, `core/mfa_challenge_html.ex`, `core/mfa_settings_html.ex`,
`core/token_controller.ex`, `organizations/organization_invitation_email.ex`,
`organizations/router_injection.ex`,
`organizations/user_auth_on_mount_assign_user_organizations.ex`, and all three `sigra.upgrade/*.exs`
— **13 edited templates with no `test/example/` target.** `[VERIFIED: manifest grep returned no
`{:eex, …}` entry for each]`

---

## §4 — Runnable verification commands (with real prerequisites)

### 4.0 Prerequisites, once per session

```bash
scripts/db/up.sh              # boots ephemeral test Postgres on a dynamic port, writes tmp/db.env
source tmp/db.env             # or: direnv allow
mix archive.install --force hex phx_new 1.8.8   # already installed at time of research
```
`[VERIFIED: CLAUDE.md §Local development prerequisites; `mix archive` shows `phx_new-1.8.8`;
`pg_isready -h localhost -p 5432` → accepting connections; `tmp/db.env` present]`

### 4.1 SC-1 — freshly generated app, grepped **in place**

```bash
GITHUB_WORKSPACE=$(pwd) TMP_APP_DIR=/tmp/sigra_239_app scripts/ci/install-smoke.sh
# then, without deleting it:
grep -rn '\.planning/' /tmp/sigra_239_app/lib /tmp/sigra_239_app/priv   # MUST be empty (exit 1)
grep -rnE '<UNION-REGEX>' /tmp/sigra_239_app/lib /tmp/sigra_239_app/priv | tee /tmp/sc1-hits.txt
wc -l < /tmp/sc1-hits.txt    # MUST be 0
```

What the script actually does, read this session
(`scripts/ci/install-smoke.sh`): asserts `mix phx.new --version` matches the **1.8.8** pin and
**exits 1** on mismatch (its D-11 comment, `:29-42`); `rm -rf "${TMP_APP_DIR}"` then
`mix phx.new --no-install --no-dashboard --database postgres`; patches `mix.exs` to add
`{:sigra, path: …}`; `mix sigra.install --yes Accounts User users`;
`mix compile --warnings-as-errors`; `mix ecto.drop/create/migrate`; injects `{:cloak_ecto, "~> 1.3"}`;
runs **`mix sigra.gen.oauth --providers google,github`**; asserts 10 generated OAuth paths + a
migration + the router marker; appends a capability-gate probe test and runs it.

Consequences for the plan:
- ✅ **Covers `sigra.install/` and `sigra.gen.oauth/`** — the generated app contains output from both.
- ⚠️ **Does NOT cover `sigra.upgrade/`** — those templates only materialize under `mix sigra.upgrade`.
  Three of the 46 edited files (`sigra.upgrade/*.exs`) are therefore **not** reachable by SC-1.
  Cover them with SC-2 (they ship in the tarball) and say so explicitly in the SUMMARY rather than
  claiming SC-1 covers the whole surface. `[VERIFIED: scripts/ci/install-smoke.sh read in full]`
- ⚠️ Requires Postgres (`PGUSER`/`PGPASSWORD`/`PGHOST` default to `postgres/postgres/localhost`,
  `:23-26`), and destroys `${TMP_APP_DIR}` at start — set `TMP_APP_DIR` away from `/tmp/tmp_app` if
  anything else uses it.
- Runtime: minutes (deps fetch + two full compiles + migrations + a test run). Budget accordingly.

### 4.2 SC-2 — the built tarball

```bash
mix hex.build --unpack           # writes ./sigra-<version>/ ; also leaves sigra-<version>.tar
cd sigra-1.5.0
grep -rn '\.planning/' lib priv  # MUST be empty
cd .. && rm -rf sigra-1.5.0 sigra-1.5.0.tar     # REPO-01: no stray tarballs left behind
git status --porcelain | grep -E 'sigra-.*\.tar' && echo "STRAY TARBALL — clean up"
```

**Do this in a scratch copy of the repo, or clean up immediately** — REPO-01 in this very milestone
was about stray `sigra-*.tar` artifacts. I ran it in a scratch copy this session.
`[VERIFIED: executed; output "Saved to sigra-1.5.0", Version 1.5.0]`

`files:` list — `mix.exs:184`: `~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)`.
`.planning/`, `guides/`, `test/` never ship. `[VERIFIED: mix.exs:184]`

### 4.3 SC-3 — the batched re-bless

```bash
# commit 3, on a clean tree with commits 1 and 2 already landed:
MIX_ENV=test mix sigra.fixture.rebless_golden           # rewrites test/fixtures/install_golden/
git diff --stat -- test/fixtures/install_golden/        # expect ~139 lines across ~35 files
git diff -- test/fixtures/install_golden/ > /tmp/239-rebless.diff
# ... run the comment-only classifier from §5.1 against /tmp/239-rebless.diff ...
git add test/fixtures/install_golden/ && git commit -m "…"
MIX_ENV=test mix sigra.fixture.rebless_golden --check   # MUST print "OK: fixture is up-to-date (check mode)." and exit 0
echo "exit=$?"
MIX_ENV=test mix ci.install_golden                      # MUST be green (needs Postgres)
```

Exit semantics, read from source: `--check` writes to a tmp dir, runs
`System.cmd("diff", ["-qr", @fixture_tree_dir, target_tree_dir])` **and** a byte equality on
`STDOUT.txt`; prints `OK: fixture is up-to-date (check mode).` and returns `:ok` on match, otherwise
prints `DRIFT DETECTED:` and calls `exit({:shutdown, 2})`.
`[VERIFIED: lib/mix/tasks/sigra.fixture.rebless_golden.ex:115-140]`
It **does not stage or commit** (`:19-20` moduledoc). `[VERIFIED]`

No DB is needed for the re-bless itself: `InstallFixture.setup_tmp_app/1` uses
`mix phx.new --no-assets --no-install` under `System.tmp_dir!/0` with `MIX_ARCHIVES`/`MIX_HOME`
isolation. `[VERIFIED: test/support/install_fixture.ex:1-40]` Postgres **is** needed for the other
members of the alias:
`mix.exs:161-163` — `"ci.install_golden": ["test test/sigra/install/features/passkeys_js_test.exs
test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs
test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs
test/upgrade_test.exs"]`. `[VERIFIED: mix.exs:161-163]`

`golden_diff_test.exs` is `@moduletag :scaffold` and `timeout: 300_000`, which is why `mix ci` runs
`test --exclude scaffold` and then calls `ci.install_golden` explicitly.
`[VERIFIED: test/sigra/install/golden_diff_test.exs:34-40; mix.exs `ci:` alias]`

The CI job to watch: **`install_golden_contract`** —
`name: Install golden + idempotency contract (subprocess harness)`, `.github/workflows/ci.yml:420-421`,
diff-gated at `:450` on
`^priv/templates/sigra\.install/|^lib/sigra/install/|^lib/sigra/mfa(\.ex|/)|^lib/sigra/oauth(\.ex|/)|^lib/sigra/account(\.ex|/)|^lib/sigra/passkeys(\.ex|/)`.
This phase's diff touches `priv/templates/sigra.install/` (43 of 46 files), so **the job runs**.
`[VERIFIED: .github/workflows/ci.yml:420,450]`

### 4.4 SC-5a — `.github/` untouched

```bash
git fetch origin main
git diff --name-only origin/main -- .github/           # expect EMPTY
git diff origin/main -- .github/ | grep -E '^[+-]\s*name:' && echo "FAIL: name: changed" || echo "OK: no name: change"
```
Baseline today: `git diff --name-only origin/main -- .github/` returns **nothing**. There are 45
indented `name:` (job/step) lines and 9 top-level workflow `name:` lines at risk.
`[VERIFIED: commands run this session]`

### 4.5 SC-5b — the rationale-preservation instrument

**Invocation signature** (read from the script's own header and body):

```bash
.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh <diff-file>
.planning/phases/.../237-security-comment-diff-check.sh -      # read diff from stdin
```

- Takes **exactly one** argument on **argv**. `-` means stdin. Wrong argument count → **exit 2**.
- Unreadable file → `FAIL: cannot read input file: …` → **exit 1**.
- **Empty content → exit 1** (`FAIL: empty diff input — refusing to report success on no input`).
  Fails **closed**, for both the `-` channel and a zero-length file.
- On success prints `examined_removed_lines=<N>` on stdout and exits **0**.
- Failure prints `FAIL: removed line(s) carry security/design rationale with no bookkeeping token:`
  plus the offending lines to **stderr**, exit **1**.
- It considers **removed** lines only (`^-`, excluding `^--- `), matches the rationale class
  `\b(security|CSRF|enumeration|timing|scope|impersonation)\b` case-insensitively, then **discards**
  lines that *also* carry `\b(D-[0-9]{2}|SC-[0-9]+|Phase [0-9]{1,3})\b|\.planning/`.

`[VERIFIED: .planning/phases/237-…/237-security-comment-diff-check.sh read in full this session]`

**Pre-computed result.** I built a synthetic worst-case diff (every one of the 158 union lines
presented as a removal) and ran the script:

```
FAIL: removed line(s) carry security/design rationale with no bookkeeping token:
-  # token clause so security signals are preserved (10.1 IN-03). Tokens
exit=1
```

Exactly **one** line in the entire corpus trips the script under a total strip:
**`priv/templates/sigra.install/core/auth.ex:530`**. It carries the word *security* and the token
`IN-03` — and `IN-[0-9]{2}` is **not** in the script's tolerance regex (which only knows `D-NN`,
`SC-N`, `Phase N`, `.planning/`). The other two rationale-class lines
(`reset_password_controller.ex:21` → `D-38`, `organization_switch_controller.ex:10` → `D-04`) are
tolerated by design.

> **Actionable:** `auth.ex:530` must be **rewritten** (keep "security signals are preserved", drop
> `10.1 IN-03`) — a plain strip fails SC-5b, and a rewrite that *keeps* `IN-03` also fails. This is
> the one line where the instrument has a real opinion. Do not "fix" the script — D-16 says do not
> rewrite it.

**Non-vacuity proof:** the script prints `examined_removed_lines=<N>`. Capture that number into the
SUMMARY and assert `N > 0`. A pass with `N=0` is impossible (empty input exits 1), but the number
must still be *recorded* — Standing Constraint 1 rejects count-free green.

---

## §5 — Failure modes a plan must guard against

### 5.1 The comment-only-diff assertion that passes vacuously — or fails spuriously

**Two failure directions, both live.**

*Spurious failure (likely):* §2.5 shows 78 of 158 lines are not `#` comments. A classifier matching
only `^[+-]\s*#` reports 78 stop-the-line events on a perfectly correct sweep.

*Vacuous pass:* `git diff -- test/fixtures/install_golden/` returning empty (because the re-bless
produced no change, or the path was wrong, or it ran before commit 1) passes any "no non-comment
lines" grep trivially.

**Recommended predicate** — assert *positively*, on a captured diff file, in this order:

```bash
DIFF=/tmp/239-rebless.diff
git diff -- test/fixtures/install_golden/ > "$DIFF"

# (1) NON-VACUITY: the diff must be non-empty and must have parsed into hunks.
CHANGED=$(grep -cE '^[+-]' "$DIFF" | tr -d ' ')
FILES=$(grep -cE '^\+\+\+ b/' "$DIFF" | tr -d ' ')
[ "$CHANGED" -ge 200 ] || { echo "FAIL: only $CHANGED changed lines — expected >=200 (~139 removals + ~139 additions)"; exit 1; }
[ "$FILES"  -ge 30 ]  || { echo "FAIL: only $FILES files in diff — expected ~35"; exit 1; }

# (2) COMMENT-ONLY: every changed line must match one of the five accepted kinds.
grep -E '^[+-]' "$DIFF" | grep -vE '^(\+\+\+|---) ' \
  | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*)' \
  | grep -vE '^[+-][[:space:]]*<%=? *#' \
  | grep -vE '^[+-][[:space:]]*@doc "' \
  | grep -vE '^[+-][[:space:]]*[^ ].*' > /tmp/239-nonconforming.txt   # <-- see note
```

The last line is the hard part: `@moduledoc` **heredoc prose** has no syntactic marker at all — it is
indistinguishable from code by regex. The honest options, in preference order:

1. **Whitelist by changed-file + line content.** Since §2 gives the exact 158 source lines and the
   golden tree is a byte mirror, compute the *expected* set of removed golden lines
   (`grep -rnE '<UNION>' test/fixtures/install_golden/tree` at pre-re-bless HEAD = 139 lines) and
   assert **removed-line set ⊆ expected set**. Any removal outside that set is the stop-the-line
   event. This is exact, non-vacuous, and needs no syntactic classification. **Recommended.**
2. **Structural check:** assert no changed line matches a code shape —
   `grep -E '^[+-].*(\bdef |\bdefp |\bdefmodule |\balias |\bimport |=|\||\{|\}|<-|->)'` applied only
   to lines that are *not* already-accepted comment kinds. Heuristic; will produce false alarms on
   prose containing backticked code.
3. **Manual review of the 35-file diff**, recorded as a checklist in the SUMMARY. Acceptable as a
   *supplement*, never as the only gate (this repo has three precedents of a green gate that verified
   nothing — Standing Constraint 1).

**Make option 1 a task with its own verification** and run it *before* the sweep, so the expected-set
snapshot is captured at pre-sweep HEAD.

### 5.2 `STDOUT.txt` independent drift (D-13)

Measured: `test/fixtures/install_golden/STDOUT.txt` contains **zero** union-token lines today.
`[VERIFIED: grep -nE '<UNION>' … → no output]` So the expected diff for it is **empty**.

Check it separately and positively:

```bash
git diff --stat -- test/fixtures/install_golden/STDOUT.txt   # expect NO output at all
```

If it *does* change, that is a genuine signal: a swept comment leaked into installer summary output,
which means the sweep touched something the installer prints. Treat as stop-the-line.

Note the `--check` mode compares `STDOUT.txt` by **byte equality**, separately from the `diff -qr`
tree compare, and reports `STDOUT.txt differs from regenerated output` on its own line — so
`--check` exit 0 does independently cover it. `[VERIFIED: rebless_golden.ex:122-140]`

### 5.3 The repo-wide `sed` (D-23)

**122 token lines live in `.github/`.** A `sed -i` without a path restriction rewrites them, and one
of the 45 indented `name:` lines becoming e.g. `Install golden + idempotency contract` → something
else silently renames a required status context, after which every PR hangs forever waiting on a
check that will never report.

Enforcement the plan should adopt:

- Every edit command in every task **names explicit files** (or is an `Edit` on a single path). No
  `grep -rl … | xargs sed -i`. No `find . -name '*.ex'`.
- Commit 1's `git diff --name-only` must be **entirely** under `priv/templates/`; commit 2's
  entirely under `test/example/`; commit 3's entirely under `test/fixtures/install_golden/`. Assert
  this mechanically per commit:
  ```bash
  git show --name-only --format= HEAD | grep -vE '^priv/templates/' && echo "FAIL: commit 1 escaped scope"
  ```
- SC-5a (§4.4) is the backstop, not the primary control.

### 5.4 Observable failure signals for `<automated>` verifications

"The command fails" is not a verification. Each command below should state the signal it produces:

| Check | Observable PASS signal | Observable FAIL signal |
|---|---|---|
| SC-1 grep | `grep` exits **1** with no stdout; ledger records `hits=0` and `app_dir=/tmp/sigra_239_app` | any `path:line:text` line printed |
| SC-2 grep | `grep -rn '\.planning/' lib priv` exits 1, zero lines; ledger records tarball version + the 32 deliberate out-of-scope hits (`docs/` 12, `README.md` 1, `CHANGELOG.md` 19) | the `organizations.ex:59` line still present |
| re-bless `--check` | literal stdout `OK: fixture is up-to-date (check mode).` and `$? = 0` | stdout `DRIFT DETECTED:` + `diff -qr` output, `$? = 2` |
| `mix ci.install_golden` | ExUnit summary line with `0 failures` | any non-zero failure count; `golden_diff_test` prints a unified diff of the first divergent file |
| comment-only diff | `changed_lines=<N≥200>`, `files=<N≥30>`, `nonconforming=0` — **all three printed** | `nonconforming>0` with the offending lines echoed |
| SC-5b script | stdout `examined_removed_lines=<N>`, `N>0`, `$? = 0` | stderr `FAIL: removed line(s) carry security/design rationale…`, `$? = 1` |
| SC-5a | `git diff --name-only origin/main -- .github/` prints nothing | any filename printed |
| scope discipline | per-commit `git show --name-only` fully inside the expected prefix | any path outside |

### 5.5 Other traps found this session

- **Line numbers shift between template and golden.** `mfa_challenge_live.ex:290` (template) is
  `:288` in the golden tree — the EEx header offsets by 2. Never map by line number; map by content.
- **`test/example/` is 4.3× the mirror scope** (476 lines / 94 files vs 110 / 31). A `grep -rl` over
  `test/example` would blow the scope silently.
- **Four counterparts have 0 tokens** while their templates have 1-13 — the mirror is *not* a
  1:1 line correspondence, so a "mirror each template edit into its counterpart" instruction will
  produce phantom edits. The plan must say "apply the edit **where the token exists in the
  counterpart**, and record `n/a — already absent` otherwise."
- **`organizations.ex:65/75/85/99` are `@doc "…"` one-liners**, i.e. *API documentation the adopter
  sees*. Rewriting them changes adopter-facing doc text — good, but it is a content change, not a
  comment strip; call it out in the plan so a reviewer expects it.
- **`organization_members_live.ex:32`** references a literal HEEx marker string
  `` `Phase 17 fills this section` ``. `grep -rn "fills this section"` finds it in the template,
  `test/example/`, and the golden tree at the *same* line 32 — but **only as prose inside the
  moduledoc**; there is no such marker in the rendered HEEx. Safe to rewrite; do not go hunting for
  a marker that does not exist. `[VERIFIED: grep -rn "fills this section"]`
- **`--check` leaks a tmp dir.** `run_check!/2` removes only `Path.dirname(target_tree_dir)`; the
  separately-allocated `STDOUT.txt` tmp base is not removed
  (`rebless_golden.ex:104-113` allocates a fresh unique base per call). Harmless; do not "fix" it
  here (Standing Constraint 4 → todo if it matters).

---

## §6 — Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| A freshly generated app for SC-1 | a bespoke `phx.new` + install script | `scripts/ci/install-smoke.sh` | Already pins phx_new 1.8.8, patches the path dep, compiles `--warnings-as-errors`, and leaves the app at `${TMP_APP_DIR}` |
| Regenerating the golden fixture | manual file copying or a hand-written diff | `MIX_ENV=test mix sigra.fixture.rebless_golden` | Handles `File.rm_rf!` + rewrite, timestamp normalization, and has an honest `--check` with exit 2 |
| Detecting golden drift | `git diff` eyeballing | `… --check` (exit 0/2) **plus** `mix ci.install_golden` | Byte-exact; covers `STDOUT.txt` separately |
| Rationale-preservation checking | a new regex script | `237-security-comment-diff-check.sh` | Committed, already proven RED, has a non-vacuity counter (D-16: do not rewrite it) |
| The shipped artifact | reasoning about `mix.exs` `files:` | `mix hex.build --unpack` | Produces the real tarball; `files:` interactions with `.gitignore` are not worth simulating |
| A leakage guard | a `p18` prohibition test | **nothing — Phase 241 owns it** (D-04) | Gating a dirty tree is red forever |
| A template↔example parity check | a new comparison script | **a todo (FUT-01)** with §3.3's table as diagnosis | Explicitly deferred by the Scope Discipline block |

**Key insight:** every instrument this phase needs already exists and has been exercised. The only
*new* artifact the plan should create is the **comment-only-diff classifier** in §5.1 — and even that
should be an in-plan phase artifact under `.planning/phases/239-…/`, not repository tooling, exactly
as 237 did with its check script.

---

## Runtime State Inventory

This is a content sweep, not a rename/refactor of identifiers. Still, the rename-class questions are
answered explicitly rather than left blank:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None** — no database, cache, or datastore keys contain the swept tokens. The swept strings are comments and doc prose only; nothing is a key, collection name, or identifier. Verified: no token line in §2 is a string literal used as a key. | none |
| Live service config | **None** — no external service (n8n, Datadog, Cloudflare) references these comment strings. | none |
| OS-registered state | **None.** | none |
| Secrets/env vars | **None** — no swept line names an env var or secret key. | none |
| Build artifacts / generated snapshots | **Two, both in-repo and both handled by the plan:** (1) `test/fixtures/install_golden/` (84 tracked tree files + `STDOUT.txt`) is a committed byte-snapshot that will carry the old text until re-blessed — that *is* commit 3; (2) `test/example/` is a hand-maintained generated-app mirror — that *is* commit 2. A third, `_build/`, recompiles automatically. | commits 2 and 3 |
| Shipped artifact | The published Hex tarball for **1.5.0 already on Hex carries the leak** — it cannot be changed. The fix reaches adopters only in **1.5.1** (Phase 242 / REL-06). | out of scope here; note it in the SUMMARY so "adopters are clean" is not overclaimed |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / OTP | everything | ✓ | Erlang/OTP 28, erts-16.4 | — |
| `mix` | all verifications | ✓ | bundled | — |
| `phx_new` archive | SC-1, SC-3 | ✓ | **1.8.8** (matches the `ci.yml` pin at `:478,546,627,774,838,891,948,1074,1447`) | none — a different version produces spurious byte-diffs |
| PostgreSQL | SC-1 (`install-smoke.sh`), `ci.install_golden`, `mix ci` | ✓ | psql 14.17 (Homebrew); `pg_isready localhost:5432` → accepting connections; `tmp/db.env` present | `scripts/db/up.sh` for an ephemeral dynamic-port instance |
| Docker | `scripts/db/up.sh` | ✓ | 29.5.2 | use the Homebrew PG on 5432 |
| `git` | SC-5a, commit topology | ✓ | 2.41.0 | — |
| `gh` | not needed this phase | ✓ | 2.95.0 | — |
| `node` | not needed this phase (no `p18`) | ✓ | v24.19.0 | — |
| `bash` | the 237 check script | ✓ | system | — |

**Missing dependencies with no fallback:** none.
`[VERIFIED: command -v / --version probes run this session]`

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18+), with `Sigra.Test.InstallFixture` subprocess harness |
| Config file | `mix.exs` `aliases/0` (`ci`, `ci.install_golden`); `test/test_helper.exs` (`ExUnit.start(exclude: [:postgres])`) |
| Quick run command | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` (no DB needed; ~1-2 min) |
| Full suite command | `mix ci` — `format --check-formatted`, `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`, `test --exclude scaffold`, `ci.install_golden`, `sigra.dep_off` |

`[VERIFIED: mix.exs `ci:` and `ci.install_golden:` aliases read this session]`

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SURF-01 | A generated app has zero `.planning/` and zero bookkeeping tokens under `lib/`+`priv/` | integration (live generated app) | `GITHUB_WORKSPACE=$(pwd) TMP_APP_DIR=/tmp/sigra_239_app scripts/ci/install-smoke.sh && grep -rn '\.planning/' /tmp/sigra_239_app/lib /tmp/sigra_239_app/priv` | ✅ `scripts/ci/install-smoke.sh` |
| SURF-01 | The built tarball is clean under `lib/`+`priv/` | integration (real artifact) | `mix hex.build --unpack && grep -rn '\.planning/' sigra-*/lib sigra-*/priv` | ✅ built-in |
| SURF-03 | `priv/templates/` has zero union-token hits | unit (grep, counted) | `grep -nE '<UNION>' $(git ls-files priv/templates) \| wc -l` → `0` | ✅ built-in |
| SURF-03 | Golden fixture matches the swept templates | contract | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` → exit 0 | ✅ `lib/mix/tasks/sigra.fixture.rebless_golden.ex` |
| SURF-03 | Installer output byte-identical to the committed golden | regression | `MIX_ENV=test mix ci.install_golden` | ✅ `test/sigra/install/golden_diff_test.exs` |
| SURF-03 | Generated app compiles clean after the HEEx subset edits | compile gate | `mix compile --warnings-as-errors` inside the generated app (already inside `install-smoke.sh`) | ✅ |
| SURF-03 | `test/example/` compiles + its suite passes after the mirror | regression | `mix ci` (includes `test/example` lane) | ✅ |
| SC-3 (comment-only) | The re-bless diff contains no code change | phase artifact | §5.1 option 1 — expected-removed-set containment, with `changed_lines` + `files` printed | ❌ **Wave 0** |
| SC-5a | `.github/` untouched | invariance | `git diff --name-only origin/main -- .github/` → empty | ✅ built-in |
| SC-5b | No rationale sentence deleted | phase artifact | `237-security-comment-diff-check.sh <this-phase-diff>` → `examined_removed_lines=N>0`, exit 0 | ✅ committed in 237 |

### Sampling Rate

- **Per task commit:** `mix format --check-formatted` + `mix compile --warnings-as-errors`; after
  commit 1, also the `priv/templates/` grep count; after commit 3, `--check` → exit 0.
- **Per wave merge:** `MIX_ENV=test mix ci.install_golden`.
- **Phase gate:** `mix ci` green on a clean tree at the final committed HEAD, plus SC-1 and SC-2
  live observations captured with their output pasted into the SUMMARY.

### Wave 0 Gaps

- [ ] `.planning/phases/239-…/239-comment-only-diff-check.sh` — the SC-3 classifier (§5.1). Must
      print `changed_lines`, `files`, and `nonconforming` so a vacuous pass is impossible, and must
      fail closed on empty input (mirror the 237 script's `:47-50` pattern).
- [ ] A pre-sweep snapshot of the **expected removed golden lines**:
      `grep -rnE '<UNION>' test/fixtures/install_golden/tree > 239-golden-expected.txt` (139 lines),
      captured before commit 1 and committed alongside the classifier.
- [ ] No framework install needed. No new test files needed — every assertion rides existing lanes.

---

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json`, so this section is included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | **no** (no auth logic changes) | — (the templates *implement* auth; this phase edits only comments and doc prose) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |
| V14 Configuration / Build | **yes** | The shipped artifact (`mix.exs` `files:`) and the generated-app surface are what change |

**The security-relevant risk of this phase is not a vulnerability — it is the loss of security
rationale.** Comments like "regardless of whether the email exists (enumeration prevention, D-38)"
are the only in-code record of *why* a defensive behaviour exists. Deleting them makes a future
maintainer "simplify" the behaviour away. That is precisely what SC-5b's instrument guards, and why
D-17 mandates rewrite-not-strip.

### Known Threat Patterns for this change class

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Rationale erasure → a later regression of an intentional defence | Tampering (deferred) | `237-security-comment-diff-check.sh`; the 31-line rewrite set in §2.3 with before/after in the plan |
| Unscoped `sed` rewriting a workflow `name:` → required context never reports, PRs hang | Denial of Service | Path-restricted commands (D-23) + per-commit path assertion + SC-5a |
| Re-bless silently absorbing an unintended code change | Tampering | SC-3 comment-only-diff with the expected-set containment check (§5.1 option 1) |
| Editing a `~H` sigil and changing rendered markup | Tampering | `mix compile --warnings-as-errors` in the generated app and `test/example/`; the HEEx subset reviewed distinctly (D-12) |
| Overclaiming "adopters are clean" while 1.5.0 on Hex still leaks | Repudiation | SUMMARY states the fix reaches adopters only at 1.5.1 (Phase 242) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `<% # … %>` / `<%= # … %>` inside a `~H` sigil emit no markup, so removing them cannot change rendered HTML | §2.4 | A Playwright/HTTP smoke regression in the example lane. **Mitigated, not eliminated**: the compile gates catch syntax breakage, and the golden byte-diff catches any rendered change reaching a generated file. Treat any non-comment line in the re-bless diff for these 7 files as the stop-the-line event D-12 anticipated. |
| A2 | The ±4-line window and my rationale vocabulary are the right partition boundary for "rewrite vs strip" | §2.3 | Over-inclusion is harmless (a rewrite that preserves meaning is never wrong); under-inclusion loses a sentence. The 10-line same-line set is exact and was measured, not estimated. |
| A3 | CONTEXT's 154/45, 133/33, and 85 are de-duplication/arithmetic slips rather than evidence of a HEAD change since the discussion | §1.2, §1.3 | Low: the per-class numbers match *exactly*, which would be improbable if the tree had moved. Still, the plan should re-run the §2 command as its first action. |
| A4 | The 32 out-of-scope tarball `.planning/` hits are unchanged from CONTEXT's measurement | §1.4 | None — I re-measured all six buckets this session and every one matched. |

**Nothing in this research is `[ASSUMED]` on a package, version, API, or file path.** Every path,
line number, count, and exit code above was produced by a command run in this session or by reading
the cited file.

---

## Open Questions

1. **What exactly counts as a "comment line" for SC-3?**
   - What we know: 80/158 are true comments; 57 are `@moduledoc` heredoc prose; 4 are `@doc "…"`.
   - What's unclear: whether the phase owner wants heredoc prose treated as "comment" (it is
     documentation, and the spirit of SC-3 is "no code changed") or wants a stricter rule.
   - **Recommendation:** adopt the expected-removed-set containment check (§5.1 option 1). It sidesteps
     the definitional argument entirely and is strictly more precise than any syntactic rule.

2. **Should `sigra.upgrade/` templates be verified at all, given SC-1 cannot reach them?**
   - What we know: 3 of 46 edited files are `sigra.upgrade/*.exs`; `install-smoke.sh` never runs
     `mix sigra.upgrade`; they *do* ship in the tarball.
   - **Recommendation:** verify them via SC-2 (tarball grep covers `priv/` in full) and state the
     SC-1 coverage boundary explicitly in the SUMMARY. Do **not** build an upgrade-smoke harness
     (Standing Constraint: build no new harness).

3. **Does the `test/example/` mirror need its own compile/test run before commit 3?**
   - What we know: `mix ci` runs the example lane, but commit 3 must be pushed together with 1 and 2.
   - **Recommendation:** run `mix ci` once after commit 2 and once after commit 3; capture both.

---

## Sources

### Primary (HIGH confidence) — files read this session

- `.planning/phases/239-…/239-CONTEXT.md` (full) — the 25 locked decisions
- `.planning/ROADMAP.md:1-90, 175-190` — Standing Constraints 1-7, Scope Discipline, Phase 239 SC 1-5
- `.planning/REQUIREMENTS.md` — SURF-01, SURF-03
- `.planning/config.json` — `workflow.nyquist_validation: true`
- `lib/sigra/install/features/core.ex:70-82, 155-200, 270-316` — the manifest and `migration_target/3`
- `lib/sigra/install/features/organizations.ex:70-80, 152, 247-248`
- `lib/mix/tasks/sigra.fixture.rebless_golden.ex:1-145` — `--check` semantics, `File.rm_rf!` rewrite
- `test/support/install_fixture.ex:1-40` — `--no-assets --no-install`, no DB
- `test/sigra/install/golden_diff_test.exs:1-40` — `:scaffold` tag, timestamp normalization
- `scripts/ci/install-smoke.sh` (full) — the SC-1 vehicle
- `.planning/phases/237-…/237-security-comment-diff-check.sh` (full) — the SC-5b instrument
- `.github/workflows/ci.yml:418-425, 440-460, 719-730` — job ids, names, the D-24 detector
- `mix.exs:120-190` — `ci`/`ci.install_golden` aliases, `files:` at `:184`
- `CLAUDE.md` — local Postgres and phx_new prerequisites

### Commands run (HIGH confidence — outputs pasted above)

`git rev-parse HEAD` · `git ls-files` · per-class and union `grep -nE` over `priv/templates`,
`test/fixtures/install_golden`, `test/example`, `.github` · `mix hex.build --unpack` in a scratch copy
· `bash 237-security-comment-diff-check.sh <synthetic full-strip diff>` · `git diff --name-only
origin/main -- .github/` · `mix archive` · `pg_isready` · tool `--version` probes

### Secondary / Tertiary

None. No web search was needed or performed — every question in the brief was answerable from the
repository.

---

## Metadata

**Confidence breakdown:**

- Measured counts: **HIGH** — every number re-run this session, command shown.
- The D-21 mapping: **HIGH** — read from the authoritative manifest with a file:line citation.
- SC-5b behaviour under this phase's diff: **HIGH** — the script was *executed* against a synthetic
  worst-case diff and its output pasted.
- The SC-3 classifier trap: **HIGH** — derived from a per-line syntactic classification of all 158 lines.
- HEEx rendering safety (A1): **MEDIUM** — reasoned from EEx/HEEx semantics plus the golden-tree
  evidence that the rendered form is a `<% # %>` comment; not proven by a render diff.

**Research date:** 2026-09-17
**Valid until:** any commit touching `priv/templates/`, `test/example/`, or
`test/fixtures/install_golden/`. Re-run the §2 command before planning if HEAD has moved past
`66721b74`.
