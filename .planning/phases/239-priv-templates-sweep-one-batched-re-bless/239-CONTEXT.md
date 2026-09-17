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
