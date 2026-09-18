# Phase 239: `priv/templates/` Sweep + One Batched Re-bless - Context

**Gathered:** 2026-09-17 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Nothing an adopter generates or downloads contains Sigra's internal planning bookkeeping.

In scope: a path-restricted bookkeeping sweep of **all three generators** under
`priv/templates/` (`sigra.install/`, `sigra.upgrade/`, `sigra.gen.oauth/`), the `test/example/`
mirror of **only** the counterparts of templates actually edited, and **exactly one** batched
`MIX_ENV=test mix sigra.fixture.rebless_golden` in its own separate commit. Verification is on a
**freshly generated app** and the **extracted `mix hex.build` tarball** — never on the source tree.

Explicitly NOT in scope: building the `p18` adopter-leakage guard (Phase 241 / SURF-04 owns it,
and this phase writes no guard and touches no `test/fixtures/prohibitions/`), the template↔example
parity guard (FUT-01, a todo), the `lib/` doc-range sweep (Phase 237, already complete), any
`.github/` edit, the Hex retire and 1.5.1 cut (Phase 242), and `CHANGELOG.md` (Phase 242 / REL-05).

**Depends on Phase 236** — the templates sweep perturbs `install_golden_contract` / `install_smoke`,
so it needs a trustworthy gate.
</domain>

<decisions>
## Implementation Decisions

### Sweep Token Set (the spec Phase 241's `p18` will mechanize)

- **D-01:** The hard-fail token set is applied to **all 120 files under `priv/templates/`**, across
  all three generators, and resolves to **154 token-bearing lines across 45 files** at this HEAD.
  The set is:

  | Class | Regex | Lines | Files |
  |---|---|---|---|
  | Planning path | `\.planning/` | 1 | 1 |
  | Phase reference | `[Pp]hase[ -][0-9]+` | 51 | 22 |
  | Decision id | `\bD-[0-9]{2}\b` | 98 | 39 |
  | Plan number | `\bPlan [0-9]{2}\b` | 9 | 4 |
  | GSD artifact filename | `[0-9]{3}-[A-Z0-9-]+\.md`, `[0-9]{2}-CONTEXT\.md` | 5 | 2 |
  | Requirement/criterion ids | `SC-[0-9]`, `ORG-UX-[0-9]{2}`, `GATE-0[0-9]`, `UI-SPEC`, `DX-[0-9]{2}`, `IN-[0-9]{2}`, `T-[0-9]+-[0-9]+`, bare `B[0-9]` | ~34 | — |

  Representative citations: `priv/templates/sigra.install/organizations/organizations.ex:59`
  (the one `.planning/` path), `sigra.upgrade/alter_add_owner_user_id.exs:3`,
  `sigra.install/core/user_auth.ex:32`, `sigra.install/organizations/migration.exs:16`,
  `sigra.install/core/settings_live.ex:66`, `sigra.install/core/sigra_auth.css:515,699,706,733`,
  `sigra.install/organizations/components/org_switcher.ex:14`,
  `sigra.install/core/login_html.ex:5`.

- **D-02:** The ROADMAP's SC-1 framing is **true but ~1.5% of the surface**.
  `organizations.ex:59` really is the only literal `.planning/` path under `priv/templates/`
  (verified count = 1) — but the Scope Discipline block puts **everything under `priv/templates/`**
  in the hard-fail tier, with no "incidental mention" exemption (unlike `lib/`, which gets the
  ratchet). A plan written to SC-1's literal text would strip one line and declare victory.
  **Plans must target the full 154-line set, not the one cited line.**

- **D-03:** Deliberately **excluded** from the token set, each a considered call:
  - `priv/templates/sigra.install/admin/policy.ex:17` — `# TODO:` is an intentional adopter
    instruction, not bookkeeping.
  - `XXXX-XXXX` placeholders (`core/mfa_challenge_live.ex:276`) — UI placeholder text.
  - `core/sigra_auth.css:156` — "generated before v1.46" is real adopter-facing compat prose.
  - `core/scope.ex:22` — the `UPGRADE-v1.2.md` pointer targets a **real shipped guide**; keep.
  - Elixir arity and version strings.

  Stripped, by contrast: `core/sigra_auth.css:699,733` point at `231-GAP-GATE02-SUMMARY.md` and
  `231-02-DIAGNOSIS.md`, both dead internal artifacts.

- **D-04:** The full token-set table above is written into this CONTEXT verbatim **because
  Phase 241's `p18` guard mechanizes exactly this spec**. The `p18` slot is confirmed free
  (`scripts/ci/prohibitions/` holds `p01`…`p17` and `p19-tag-namespace-ruleset.test.mjs`).
  Phase 239 must leave `priv/templates/` at **zero** hits for this set, and must leave
  `test/fixtures/prohibitions/` untouched — 241 owns the known-bad fixture and the RED
  demonstration (Standing Constraint 6). **239 builds no guard.**

### SC-2 Tarball Scope (recorded deliberately — SC-2 as literally written is unsatisfiable)

- **D-05:** SC-2 is verified as `grep -rn '\.planning/' <unpacked>/lib <unpacked>/priv` → **0 hits**,
  not a whole-tarball grep. The real tarball was built and unpacked during discussion
  (`mix hex.build --unpack`, Hex 2.4.2, version 1.5.0). Measured `.planning/` hits inside it:
  `lib/` **0**, `priv/` **1** (the `organizations.ex:59` line), `docs/` **12**, `README.md` **1**,
  `CHANGELOG.md` **19**, `mix.exs` **0**.

- **D-06:** The scoping is correct because SURF-01 (`REQUIREMENTS.md:82`) scopes the *requirement*
  to "`lib/` or `priv/templates/` — **verified by** grepping a freshly generated app and the
  `mix hex.build` tarball". The tarball is the **vehicle**, not the scope. The 32 out-of-scope hits
  are deliberate maintainer prose and pinned GitHub URLs: `docs/nyquist-posture-matrix.md:11`
  explicitly states that path is *not* part of the tarball, and `CHANGELOG.md:10` deliberately
  explains the planning-milestone vs SemVer axes. `CHANGELOG.md` is additionally **Phase 242's file**
  (REL-05 folds `## Unreleased`), so touching it here is a collision.

- **D-07:** The measurement in D-05 and the scoping rationale in D-06 are **recorded as an artifact
  in the phase SUMMARY**, positively asserted — not left implicit. Standing Constraint 1 rejects
  count-only acceptance; the honest claim is "`lib/` and `priv/` are clean in the built tarball, and
  the 32 remaining references live in docs/README/CHANGELOG by design", never "the tarball is clean".

- **D-08 [informational]:** The real `files:` list is `mix.exs:184` —
  `~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)`. `.planning/` is
  **absent** from the tarball entirely; `guides/` and `test/` do not ship; `priv/templates/` ships
  in full (119 files — the 120th on disk is a gitignored `priv/templates/.DS_Store`, untracked and
  correctly excluded; `.gitignore:39`). No action on the `.DS_Store`.

### Golden Re-bless Mechanics (SC-3)

- **D-09:** `MIX_ENV=test mix sigra.fixture.rebless_golden` re-scaffolds a throwaway app and
  **replaces** `test/fixtures/install_golden/tree/` (85 files, 760K) plus `STDOUT.txt` with the new
  normalized snapshot (`lib/mix/tasks/sigra.fixture.rebless_golden.ex:92-103` — `File.rm_rf!` then
  rewrite). The fixture is a **directory tree**, a byte-for-byte committed snapshot of the generated
  app — not a tarball and not a diff file. Migration filenames are normalized to `TIMESTAMP_`
  (`test/sigra/install/golden_diff_test.exs:14-26`).

- **D-10:** Because the golden tree mirrors the generated app byte-for-byte, **every swept template
  comment lands as a mirrored comment-line change there and nothing else**. A non-comment line in
  that diff means the sweep changed generated *code* — SC-3's stop-the-line event. Expected diff
  size: **133 token lines across 33 golden files** (the golden tree carries the same leakage today,
  including `tree/lib/sigra_install_golden_tmp/organizations.ex:59`).

- **D-11:** `--check` writes to a tmp dir and runs `diff -qr` plus STDOUT equality
  (`rebless_golden.ex:60-65,115-140`), printing `OK: fixture is up-to-date (check mode).` on match
  and **`exit({:shutdown, 2})`** on drift. So **exit 0 = no drift**, exit 2 = drift. The task does
  **not** stage or commit (`rebless_golden.ex:19-20`) — the operator does, in its own commit.

- **D-12 (the live hazard):** ~15 tokens sit **inside HEEx `~H` sigils** —
  `core/settings_live.ex:66,77,107,159`, `core/mfa_challenge_live.ex:290,297`,
  `organizations/live/organization_settings_live.ex:60,69,117`. Removing a comment there can change
  rendered output, producing non-comment lines in the re-bless diff (stop-the-line) and possibly a
  Playwright/HTTP smoke regression. These must be handled as a distinct, carefully-reviewed subset.

- **D-13:** `core/sigra_auth.css` is copied **verbatim** into
  `tree/priv/static/assets/sigra_auth.css`, so the CSS comment edits at
  `sigra_auth.css:515,699,706,733` drift the golden tree too. Additionally, **`STDOUT.txt` can drift
  independently of the tree** if any swept comment appears in installer summary output — check it
  separately rather than assuming the tree diff covers it.

- **D-14:** The re-bless is runnable and verifiable locally: `phx_new-1.8.8` is installed and matches
  the CI pin (`ci.yml:478,546,627,774`). `InstallFixture.setup_tmp_app/1` uses
  `mix phx.new --no-assets --no-install` (`test/support/install_fixture.ex:15-27`), so **no DB is
  needed for the re-bless itself**; Postgres is required only for the other members of the
  `ci.install_golden` alias (`mix.exs:161-163`: idempotency, vault_promotion, `upgrade_test.exs`).

### SC-1 Verification Vehicle

- **D-15:** SC-1's freshly generated app comes from **`scripts/ci/install-smoke.sh`** — it scaffolds
  `mix phx.new` + local-dep `mix sigra.install` into `${TMP_APP_DIR:-/tmp/tmp_app}` and compiles
  `--warnings-as-errors` (`scripts/ci/install-smoke.sh:1-22`). Grep it **in place**.
  - **Not** `scripts/ci/admin-acceptance-smoke.sh` — it additionally boots a server and runs
    Playwright at `PORT=4017`, far more machinery than SC-1 needs.
  - **Not** the golden fixture — that is a committed snapshot, i.e. the source tree wearing a
    disguise, and SC-1 says "never on the source tree". Grepping it instead would re-commit the
    exact "green gate that verified nothing" failure this milestone exists to close.
  - Requires Postgres at `localhost:5432` user/password `postgres` (`install-smoke.sh:23-26`),
    available via `scripts/db/up.sh` + `tmp/db.env` per CLAUDE.md.

### Rationale Preservation (SC-5, second half)

- **D-16:** The literal `# SECURITY:` marker occurs **zero** times in `priv/templates/` (verified).
  Same finding as Phase 237 repo-wide — **do not re-decide this.** SC-5 is checked with the
  already-committed, already-proven-RED regex-class script
  `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh`,
  pointed at this phase's unified diff. It fails on any **removed** line matching
  `security|CSRF|enumeration|timing|scope|impersonation` that carries **no** bookkeeping token,
  tolerates lines carrying both (the rewrite case, `:64-65`), fails closed on empty input (`:47-50`),
  and prints `examined_removed_lines=<N>` so a vacuous pass is impossible (`:16-18`).

- **D-17:** **23 of the 154 token lines** sit within ±4 lines of rationale-class text and must be
  **rewritten** (token out, sentence in) rather than stripped. The 5 same-line co-occurrences — the
  sharpest cases — are:
  - `organizations/controllers/organization_switch_controller.ex:10` — "organization ids return 404
    for enumeration prevention (D-04)"
  - `core/reset_password_controller.ex:21` — "regardless of whether the email exists (enumeration
    prevention, D-38)"
  - `organizations/router_injection.ex:1` and `organizations/live/invitation_accept_live.ex:3` —
    both "Phase 17 D-06: single unscoped…"
  - `core/scope.ex:70` — "active-organization transitions (Phase 14 D-15)"

  Plus `organizations/organization_invitation_email.ex:12` — "html_escape_string/1 (XSS defense —
  T-17-10)" — from the windowed set.

- **D-18 [informational]:** The script only inspects the diff, so a rewrite that keeps *a* sentence
  while silently dropping its meaning passes. The 23 rewrite cases therefore need human-readable
  before/after in the plan, not just a mechanical substitution.

### Commit Topology and the `test/example/` Mirror

- **D-19:** **Three commits**, in this order:
  1. **Sweep** — `priv/templates/` only (45 files). The only commit whose diff a reviewer reads
     line by line.
  2. **Mirror** — `test/example/` counterparts only, with the SC-4 per-file checklist derived
     from it.
  3. **Re-bless** — `MIX_ENV=test mix sigra.fixture.rebless_golden`, touching only
     `test/fixtures/install_golden/`, verified comment-only, then `--check` → exit 0 and
     `mix ci.install_golden` green.

  Keeping the mirror out of commit 3 is **mandatory** — the golden fixture is generated from
  `priv/templates/` alone and must not be contaminated, or a reviewer cannot tell generated drift
  from hand edits. SURF-03 (`REQUIREMENTS.md:84`) requires "one sweep plus **one** batched re-bless,
  in separate commits".

- **D-20:** **27 of the 45** edited templates have a `test/example/` counterpart, mapped by filename:
  `core/audit_event.ex`→`test/example/lib/example/accounts/audit_event.ex`;
  `core/auth_fixtures.ex`→`test/example/test/support/fixtures/auth_fixtures.ex`;
  `core/emails.ex`→`test/example/lib/example/accounts/emails.ex`;
  `core/{mfa_challenge_live,mfa_settings_live,registration_live,reset_password_live,settings_live}.ex`
  →`test/example/lib/example_web/live/<same>.ex`;
  `core/{reset_password_controller,reset_password_html}.ex`→`test/example/lib/example_web/controllers/<same>`;
  `core/{sudo_controller,sudo_html}.ex`→`test/example/lib/example_web/controllers/auth/<same>`;
  `core/{scope,user,user_token}.ex`→`test/example/lib/example/accounts/<same>`;
  `core/user_auth.ex`→`test/example/lib/example_web/user_auth.ex`;
  `core/sigra_auth.css`→`test/example/priv/static/assets/sigra_auth.css`;
  `admin/admin_hooks.js`→`test/example/assets/js/admin_hooks.js`;
  all 8 `organizations/**` LiveViews/components/controllers→`test/example/lib/example_web/{live,components,controllers}/<same>`;
  `organizations/organization{,_invitation}.ex`→`test/example/lib/example/accounts/<same>`;
  `organizations/organizations.ex`→`test/example/lib/example/organizations.ex`.

- **D-21:** **4 counterparts are renamed and must be mapped by hand, never by basename:**
  `core/error_handler.ex`→`test/example/lib/example_web/auth_error_handler.ex`;
  `core/auth.ex`→`test/example/lib/example/accounts.ex` (context module);
  `core/migration.exs` and `organizations/migration.exs`→`test/example/priv/repo/migrations/*`;
  `core/login_html.ex`→`test/example/lib/example_web/controllers/session_html.ex` — **this last one
  is unverified and must be confirmed before the mirror commit.** Where filename correspondence is
  ambiguous, derive the mapping from the installer's template→target manifest in `lib/sigra/install/`,
  which is authoritative.

- **D-22:** **10+ edited templates have confirmed no counterpart:**
  `sigra.gen.oauth/oauth_settings_live.ex`, `core/api_token_created_email.ex`,
  `core/mfa_challenge_controller.ex`, `core/mfa_challenge_html.ex`, `core/mfa_settings_html.ex`,
  `core/token_controller.ex`, `organizations/organization_invitation_email.ex`,
  `organizations/router_injection.ex`,
  `organizations/user_auth_on_mount_assign_user_organizations.ex`, and all three
  `sigra.upgrade/*.exs`. Several (`mfa_challenge_html.ex`, `token_controller.ex`) **do** appear in
  the golden tree, so the absence is a real `test/example/` coverage gap — precisely FUT-01's
  diagnosis. **Filed as a todo with that diagnosis attached, not fixed here** (SC-4 and the Scope
  Discipline block both say so).

### Infrastructure Untouched (SC-5, first half)

- **D-23:** The sweep is **path-restricted to `priv/templates/` (plus the mirrored `test/example/`
  paths) at the command level** — never a repo-wide `sed`. Bookkeeping tokens exist in `.github/`
  in volume: `ci.yml` 93 lines, `ci-observe.yml` 8, `release-please.yml` 5, `ci-skip-manifest.tsv` 8
  (e.g. `ci.yml:442` "Phase 51", `ci.yml:726` "Phase 230 (FAST-05 / D-07)", `ci.yml:1560`
  "GATE-03 (Phase 231 / D-02)"). A repo-wide sweep would hit all 114 and could rewrite a `name:`
  line, silently renaming a required status context — after which a PR hangs forever. SC-5's guard
  is `git diff origin/main -- .github/` showing no `name:` change.

### Found While Cleaning → Todos, Not Fixes

- **D-24:** `ci.yml:450` diff-gates `install_golden_contract` on
  `^priv/templates/sigra\.install/|^lib/sigra/install/|^lib/sigra/mfa(\.ex|/)|^lib/sigra/oauth(\.ex|/)|^lib/sigra/account(\.ex|/)|^lib/sigra/passkeys(\.ex|/)`.
  **`priv/templates/sigra.upgrade/` and `priv/templates/sigra.gen.oauth/` are absent from that
  regex** — a sweep touching only those would silently skip the gate meant to catch golden drift.
  This phase's diff *does* touch `sigra.install/`, so the job runs here. The gap itself is
  **filed as a todo** (Standing Constraint 4), noting it is adjacent to Phase 241's honest-skip work.

- **D-25:** FUT-01 (template↔example parity guard) is filed as a todo with the D-22 coverage-gap
  list attached as its diagnosis. Explicitly not built here.

- **D-26 [user decision, gap-closure planning, 2026-09-17]:** SC-3 and SURF-03 are **amended** with a
  one-clause carve-out: **one batched re-bless per batch of template edits**, rather than exactly one
  for the phase. Rationale: the gap closure (plans 239-05 … 239-08) lands a second batch of template
  edits, and a second batch of template edits cannot reach the golden fixture without a second
  batched re-bless — the alternative is a golden tree that no longer matches a freshly generated app,
  which is the failure SC-3 exists to prevent. The property SC-3 actually protects is preserved
  unchanged: each re-bless is a single batched run, confined to `test/fixtures/install_golden/`, its
  diff proven comment-only by a classifier demonstrated falsifiable first, in its own commit with
  nothing else in it. What changes is only the phase-level count.

  Three options were put to the developer — amend the criteria, rewrite history so one re-bless
  commit remains, or proceed and record the deviation in `239-EVIDENCE.md` only. The developer chose
  **amend**. Recording a deviation from a locked criterion in a downstream artifact does not amend
  the criterion: a re-verifier applying SC-3 literally at final HEAD would see two re-bless commits
  and could legitimately fail the phase a second time, after the full closure cost is spent. The
  `239-EVIDENCE.md` record is kept as well — the amendment makes the criterion match reality, the
  ledger keeps the audit trail. Both, not either.

  Reversibility: **one-way-ish**. Amending a locked requirement changes the phase's contract and a
  later reader reasons from the amended text. No `checkpoint:decision` is emitted for it — the
  developer has already made this call, and re-asking an answered question at execution time would
  stop the run for nothing.

  Implemented by plan 239-08 Task 4 in `.planning/ROADMAP.md` (Phase 239, Success Criterion 3) and
  `.planning/REQUIREMENTS.md` (SURF-03).

### Gap-Closure Round 2 Decisions (plans 239-09 … 239-13)

- **D-27 [user decision, gap-closure planning, 2026-09-18]:** SC-2 (and nothing else) is **amended**
  to name `lib/` and `priv/` as the scope it asserts inside the extracted `mix hex.build` tarball.
  The developer's choice is to **narrow the claim and route the surface**, not to clean it here.

  Measurement behind it: `mix.exs:184` packages
  `~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)`. `lib/` and `priv/` carry
  **0** `.planning/` references at HEAD; `docs/`, `README.md` and `CHANGELOG.md` carry **58
  occurrences across 32 lines in 6 files** (`CHANGELOG.md` 43/19, `docs/uat-ci-coverage.md` 7/6,
  `docs/ga-evidence.md` 3/3, `docs/nyquist-posture-matrix.md` 3/2, `docs/audit-semantics.md` 1/1,
  `README.md` 1/1). Those 58 are **deliberate**: real provenance links and maintainer prose — D-06
  already argued this, and D-27 promotes that rationale from a discussion note into the criterion's
  own text, so a re-verifier applying SC-2 literally at final HEAD reads the scoping instead of
  re-deriving it.

  Alternatives considered and **not taken**: (a) *strip `.planning/` paths out of the packaged
  docs* — deletes real provenance links, and `CHANGELOG.md` is Phase 242's file (REL-05), so the
  edit collides; (b) *drop `docs` from the Hex `files:` list* — removes documentation adopters
  legitimately read in order to make a grep count fall, which is a worse artifact for a better
  number.

  A narrowing that silently deletes a finding is the same defect as a green gate that verified
  nothing, so the narrowing is only legitimate because the finding keeps **two** owners: SURF-04's
  requirement text now names the packaged-docs surface, and
  `.planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md`
  carries the measured per-file breakdown.

  Reversibility: **costly**. Amending a locked criterion changes the phase's contract and a later
  reader reasons from the amended text. Not one-way: the note states the original claim and what
  changed, so the pre-amendment criterion is reconstructable from the criterion itself. No
  `checkpoint:decision` is emitted, following the D-26 precedent — the developer made this call
  during gap-closure planning.

  Implemented by plan 239-10 Task 1 in `.planning/ROADMAP.md` (Phase 239, Success Criterion 2) and
  `.planning/REQUIREMENTS.md` (the SURF-01 consistency note and the SURF-04 packaged-docs clause).

- **D-28 [gap-closure planning, 2026-09-18]:** The twice-widened bookkeeping definition (V3) is
  implemented in this closure as a **measurement instrument only** — defined, demonstrated RED on all
  three tiers (`priv/templates/`, the SC-4 `test/example/` counterparts, the golden tree), recorded
  in `239-EVIDENCE.md` § `## VOCABULARY-LEDGER`, and **wired into nothing**
  (`grep -rn '239-v3-vocabulary-check' mix.exs .github scripts/ | wc -l` → 0). Phase 241's SURF-04
  `p18` guard inherits it as its spec through
  `.planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md`, which plan
  239-09 amended in place from V2 to V3.

  Alternatives **not taken**: (a) *build the guard here* — forbidden by Standing Constraint 5 and
  D-04 (Phase 239 builds no guard; Phase 241 owns the known-bad fixture and the RED demonstration);
  (b) *do not widen at all, and instead restate SC-1 as "clean under the V2 identifier regex"* —
  rejected, because it leaves intact the exact mechanism that hid the two residual sentences, so the
  next vocabulary-class leak ships under a green measurement precisely as these two did. Restating
  the criterion without widening the instrument buys honesty about the past at the cost of the
  future.

  Reversibility: **costly**. V3 is the instrument every later acceptance criterion in this closure is
  measured against; reverting means re-deriving plans 239-11 … 239-13's measurements. Mitigated by
  the keep/drop record in § `## VOCABULARY-LEDGER` (c).

  Implemented by plan 239-09; SC-1 amended to name it by plan 239-10 Task 2; consumed by plans
  239-11, 239-12 and 239-13.

- **D-29 [gap-closure planning, 2026-09-18]:** Bound the D-26 residue with an **evidence obligation**,
  not a restored count. D-26 amended SC-3 and SURF-03 from "exactly **one** batched re-bless for the
  phase" to "**one batched re-bless per batch of template edits**". `239-VERIFICATION.md` names the
  weakening exactly: *"one per batch is unbounded where exactly one was countable — nothing now caps
  the number of re-bless commits a future phase can justify."*

  D-29's rule: **every re-bless batch must be justified by name in `239-EVIDENCE.md` before that
  batch's re-bless runs** — which template edits compose the batch, and why they could not have been
  folded into the previous batch. The count stays auditable even though it is no longer fixed. The
  durable home is `239-EVIDENCE.md` § `## BATCH-JUSTIFICATION`.

  D-29 does **not** re-amend SC-3's prose and does **not** re-amend SURF-03's prose. It adds an
  obligation recorded as a decision. Those criteria also carry the comment-only, commit-isolation,
  `--check`-exit-0 and mirror clauses, and re-opening their text puts those clauses back in play.

  *Reading hazard, recorded here so a later reader is not misled:* SURF-03's D-26 amendment justifies
  itself with the clause "because the gap closure lands a **second** batch of template edits". After
  batch 3 lands, that rationale clause under-describes the batch count. The clause describes the
  **occasion** of the amendment, not a cap — the amended rule is "one batched re-bless per batch",
  which is unbounded by construction, and that unboundedness is exactly why D-29 exists. The word is
  deliberately **not** corrected in SURF-03's or SC-3's prose: correcting a rationale word is
  cosmetic, and the edit would re-open clauses that are not.

  Alternatives considered and **not taken**: (a) *restore a hard per-phase count* — rejected, it
  re-creates the D-26 impasse the developer already resolved, and a hard count is what forces either
  a golden tree that no longer matches a freshly generated app or a history rewrite; (b) *accept the
  unboundedness silently* — rejected, that is the "documented deviation instead of an amendment"
  shape D-26 itself already refused.

  Reversibility: **reversible**. The obligation is a section in an evidence file; dropping it costs
  nothing already committed.

  Implemented by plan 239-10 Task 2 (the `## BATCH-JUSTIFICATION` section and the retrospective
  batch-1/batch-2 rows); **discharged for batch 3 by plan 239-12**, which fills the batch-3 slot
  before its re-bless runs.

- **D-30 [gap-closure planning, 2026-09-18]:** *Copied verbatim in substance from `239-EVIDENCE.md`
  § `## VOCABULARY-LEDGER` (k), where plan 239-09 states it, into the block plans 239-11 … 239-13
  read for authority. A decision recorded only in EVIDENCE is not readable from here.*

  **Statement.** The instrument's detection **width** and the criterion's asserted **surface** are
  separate concerns. V3 stays maximally wide and is never narrowed, tuned, or hand-fitted so that the
  current tree happens to pass it. What plans 239-11, 239-12 and 239-13 assert is
  `hits_outside_allowlist = 0` — never `hits = 0` — over a tier file list and a per-line triage
  allowlist that were **both committed before the RED demonstration ran**
  (`.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-allowlist.tsv`), with the
  raw `hits=` total printed alongside on every run. The `example` tier is asserted **only** over
  SC-4's mirrored-counterpart surface; the unswept remainder of `test/example/` is a measured, named,
  routed number this phase does not claim to clean — **482 V3-matching lines across 157 files** (over
  344 scanned files), owned by **Phase 241 SURF-04** via
  `.planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md`.

  **Rationale.** A literal `hits = 0` criterion was arithmetically unreachable at this base: V2 alone
  returns **1** hit in `priv/templates/` (an SVG `path d=` coordinate false positive that cannot be
  edited without changing a brand mark's geometry) and **390** across `test/example/`; under V3 the
  example remainder is **482**. A plan asserting `hits = 0` would either halt on its first verify or
  be "resolved" under time pressure by hand-fitting the instrument — so the phase could never have
  sealed, and the pressure to seal it would have landed on the instrument.

  **Alternatives not taken.** (a) *Narrow V3 until the tree passes* — reinstates exactly the blind
  spot the widening exists to remove, and is the V1→V2 failure repeating a third time. (b) *Sweep
  `test/example/` repo-wide* — 4.3× over the SC-4 scope (`239-RESEARCH.md` § 1.6) and incompatible
  with D-19's commit topology. (c) *Silently drop the false positive from the reported count* —
  indistinguishable from the defect under repair; the hit is reported, marked `[ALLOWLISTED]` inline,
  and still counted in `hits=`.

  Reversibility: **costly** (same basis as D-28 — every later acceptance criterion in this closure is
  measured against it).

  Implemented by plan 239-09; consumed by plans 239-11, 239-12 and 239-13.

### Claude's Discretion

- The exact rewritten wording of the 23 D-17 rationale-preserving comments, so long as the sentence
  survives and the token goes.
- Whether the D-12 HEEx-sigil subset is handled in its own plan or as a marked section of the sweep
  plan, so long as it is reviewed distinctly.
- Plan count and granularity within the D-19 three-commit topology.
- Whether the D-21 authoritative mapping is read from `lib/sigra/install/` up front or only for the
  4 ambiguous renames.

### Folded Todos

None. No pending todo carries `resolves_phase: 239`.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — `### Phase 239` (5 success criteria), plus the **Standing Constraints**
  (1-7) and **Scope Discipline** blocks under `# v1.48 CLEAN-BASELINE (active)`
- `.planning/REQUIREMENTS.md` — SURF-01 (`:82`), SURF-03 (`:84`), and the **Out of Scope** table
  (binding)
- `.planning/METHODOLOGY.md` — Decisive Defaulting, Escalation Threshold, Prompt And Prior-Art
  Weighting
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-CONTEXT.md` — D-04,
  the rationale-preservation precedent this phase reuses
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh`
  — the SC-5 instrument (already proven RED; do not rewrite)
- `priv/templates/sigra.install/`, `priv/templates/sigra.upgrade/`,
  `priv/templates/sigra.gen.oauth/` — the swept surface (45 token-bearing files)
- `priv/templates/sigra.install/organizations/organizations.ex` — `:59` (the one `.planning/` path),
  `:60`, `:62`
- `lib/mix/tasks/sigra.fixture.rebless_golden.ex` — `:19-20`, `:60-65`, `:92-103`, `:115-140`
- `test/fixtures/install_golden/` — `STDOUT.txt` + `tree/` (85 files, the re-bless target)
- `test/sigra/install/golden_diff_test.exs` — `:14-26` (timestamp normalization)
- `test/support/install_fixture.ex` — `:15-27` (`--no-assets --no-install`, no DB)
- `scripts/ci/install-smoke.sh` — `:1-22`, `:23-26` (the SC-1 vehicle)
- `mix.exs` — `:161-163` (`ci.install_golden` alias), `:184` (the Hex `files:` list)
- `.github/workflows/ci.yml` — `:450` (the D-24 change-detector gap), `:478,546,627,774` (phx_new
  1.8.8 pin). **Read-only: no `.github/` edit is in scope.**
- `CLAUDE.md` — local Postgres prerequisites and the phx_new 1.8.8 archive requirement
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`scripts/ci/install-smoke.sh`** — the smallest existing machinery producing a real generated app
  on disk and leaving it there. Reusing it honours the "build no new harness" discipline.
- **`mix sigra.fixture.rebless_golden`** — already has a `--check` mode with honest exit codes
  (0 = clean, 2 = drift) and does not auto-commit, which is exactly what SC-3's separate-commit
  requirement needs.
- **`237-security-comment-diff-check.sh`** — a committed, already-proven-RED rationale-preservation
  instrument with a non-vacuity counter. Point it at a new diff; do not re-derive it.
- **`mix hex.build --unpack`** — the SC-2 vehicle; produces the real shipped artifact locally.

### Established Patterns

- **The golden fixture is a byte-for-byte snapshot**, not a diff — which is *why* SC-3's
  "comment-only diff" test is meaningful: template comment in, golden comment out, one-to-one.
- **`test/example/` is hand-maintained and drifts behind `priv/templates/`** (the standing
  installer-template-drift lesson). Hence the per-file checklist rather than a blanket mirror, and
  hence FUT-01.
- **Guards live in `scripts/ci/prohibitions/*.test.mjs`, never in `mix ci`** (Standing Constraint 5).
  Phase 239 writes none; it writes the *spec* that `p18` will mechanize.
- **`mix ci`, never root `mix test`**, before every push (Standing Constraint 3).

### Integration Points

- `priv/templates/sigra.install/` → `install_golden_contract` (diff-gated at `ci.yml:450`) →
  `ci-gate`. This phase's diff triggers that job; Phase 236's fix is what makes its verdict
  trustworthy (the 236 → 239 dependency).
- `priv/templates/` → the `mix hex.build` tarball (via `mix.exs:184` `files:`) → what adopters
  actually download.
- `priv/templates/` → `test/example/` (hand-mirrored) → the example lane's Playwright and ExUnit
  coverage.
- Phase 239's token set → Phase 241's `p18` guard (the 239 → 241 dependency: gating a dirty tree is
  red forever).

</code_context>

<specifics>
## Specific Ideas

- **The ROADMAP's SC-1 undercounts by ~65×.** Plans must target 154 lines / 45 files, not the single
  cited `organizations.ex:59`. This is stated up front so it is not argued mid-execution.
- **SC-2 is scoped, and the scoping is written down as an artifact** (D-05/D-06/D-07). The honest
  claim is "`lib/` and `priv/` are clean in the built tarball"; the 32 remaining docs/README/CHANGELOG
  references are deliberate and enumerated.
- **A non-comment line in the re-bless diff is a stop-the-line event**, not a judgment call — the
  task makes drift disappear regardless of whether the drift was intended.
- **Evidence at the final committed HEAD on a clean tree** (Standing Constraint 2).
- **Count-only acceptance is rejected at review** (Standing Constraint 1) — SC-1 and SC-2 are live
  observations against a generated app and an unpacked tarball.
- The sweep command is path-restricted; a repo-wide `sed` is the single most dangerous possible
  implementation of this phase (D-23).
</specifics>

<deferred>
## Deferred Ideas

- **FUT-01: template↔example parity guard** — filed as a todo with the D-22 coverage-gap list
  attached. Explicitly a future milestone, per the Scope Discipline block.
- **`ci.yml:450` change-detector omits `sigra.upgrade/` and `sigra.gen.oauth/`** (D-24) — a new
  todo with the diagnosis attached; adjacent to Phase 241's honest-skip work, not fixed here.
- **The `p18` adopter-leakage guard** — Phase 241 / SURF-04. 239 supplies the token-set spec only.
- **Whole-tarball `.planning/` cleanliness with a committed allowlist of the 32 deliberate sites** —
  a coherent stricter posture, considered and not taken (D-05/D-06): it brushes Phase 242's
  `CHANGELOG.md` and deletes real provenance links. Worth revisiting once 242 has cut 1.5.1.
- **`lib/` inline-comment bookkeeping** — the monotonic-decrease ratchet, Phase 241's business. Zero
  is explicitly not the v1.48 target.

### Reviewed Todos (not folded)

No pending todo carries `resolves_phase: 239`. The `todo.match-phase` matches
(`2026-06-20-playwright-parallelization-per-shard-db.md`,
`2026-07-10-canary-recapture-lane-excludes-canary.md`,
`2026-07-10-installer-context-impersonation-guard-gap.md`,
`2026-07-28-admin-eval-render-burns-17m-per-pr-*.md`,
`2026-07-28-w5-export-auth-data-deny-path-orphaned.md`,
`2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`, and the rest) all scored
on generic keywords (`priv`, `templates`, `phase`, `ci`) and are owned by Phases 241/243 or later.
Phase 243 (QUEUE-04) owns full todo triage. Leave pending.
</deferred>
