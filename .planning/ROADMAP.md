# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Active milestone — **v1.48 CLEAN-BASELINE** (Phases 236-245). Roadmap created 2026-09-15; 27/27 requirements mapped. Next: plan Phase 236.

## Milestones

- 🚧 **v1.48 CLEAN-BASELINE** — Phases 236-245 (active, roadmap created 2026-09-15) · 27/27 requirements mapped
- ⚠️ **v1.47 CI-EFFICIENCY** — Phases 230-235 (shipped 2026-09-15 · `override_closeout`, 21/24 requirements, TEST-01/TEST-02 unsatisfied, 46 artifacts acknowledged) · full detail in milestones/v1.47-ROADMAP.md
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (shipped 2026-07-27 · `override_closeout`, 15/15 requirements, 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (shipped 2026-07-11 · `override_closeout`, Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md
- ✅ **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (shipped 2026-07-10) · full detail in milestones/v1.44-ROADMAP.md
- ✅ **v1.43 STABILIZE** — Phases 213-215 (shipped 2026-07-03) · full detail in milestones/v1.43-ROADMAP.md
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

---

# v1.48 CLEAN-BASELINE (active)

**Goal:** Get `main` honestly green, the repo and release namespace unambiguous, the shipped code free of planning artifacts, and a release cut — so Sigra sits in a quiet, ready posture where the next milestone can start whenever we choose.

**Thesis:** Baseline hygiene + cut a release. Explicitly NOT a feature or UI milestone. Source of truth for phase contents is `.planning/REQUIREMENTS.md` (27 requirements) and `.planning/research/SUMMARY.md` (reconciled, HIGH confidence, measured live 2026-09-15).

**The spine, in one sentence:** the `Generated admin Playwright smoke` flake reds `ci-gate`, `ci-gate` gates release-please's `gate-ci-green`, and `gate-ci-green` gates `publish-hex` — so one flaky assertion taxes or blocks every merge in the milestone. It is fixed first; everything else runs in parallel with it or waits behind it.

## Standing Constraints (bind every phase below — not repeated per phase)

1. **One live-external observation per phase.** Every phase has at least one success criterion that observes a live external system — the GitHub Actions/API, the Hex API, a freshly generated app, a built `mix hex.build` tarball, or a captured CI run. **Count-only acceptance — a grep count or `wc -l` — is rejected at review.** This repo has three documented precedents of a green gate that verified nothing.
2. **Evidence is captured at the final committed HEAD on a clean tree.** A bundle rendered at a pre-commit SHA is invalid (the SC-5 lesson).
3. **`mix ci`, never root `mix test`, before every push.** Root `mix test` misses formatting and `test/example`.
4. **Found-while-cleaning → a new todo file, never an in-phase fix.** Exactly **one** pre-authorized exception, granted here so it is not argued mid-execution: **if Phase 236's root cause is a genuine product race in `lib/`, fixing it is in scope** — a real intermittent bug in a shipped auth library outranks the cleanup.
5. **New prohibition guards go in `scripts/ci/prohibitions/*.test.mjs`, never into `mix ci`.** The `ci.yml:393` glob picks them up with zero workflow edits. `test/sigra/planning/phase_233_library_economics_contract_test.exs` *requires* the current single-owner `mix ci` topology; changing that alias re-opens the exact v1.47 wound this milestone exists to close. (Credo is also the wrong instrument — `.credo.exs` cannot see `priv/templates/`.)
6. **A guard that has never been observed RED does not count.** Every guard written or rewritten needs a committed known-bad fixture under `test/fixtures/prohibitions/` and a demonstrated red, before it is accepted.
7. **The Out of Scope table in `REQUIREMENTS.md` binds every phase** — including: no W-3/W-4 generated-auth runtime proof, no admin/operator-UI iteration, no pruning `.planning/` from the repo, no BFG/filter-repo history slimming, no `mix ci` topology change, no PNG baseline-recapture lane, no new feature work.

## Scope Discipline (the descope lines — binding)

- **Bookkeeping sweep: ratchet, not zero.** The measured surface is 604 lines / 771 occurrences, not the brief's 171. Hard-fail tier = the 5 dead `.planning/` paths + everything under `priv/templates/` + `@moduledoc`/`@doc` ranges that render on HexDocs. Everything else (inline `#` comments in `lib/`) is a committed baseline under a **monotonic-decrease ratchet**. Zero is explicitly not the v1.48 target.
- **Playwright #213: drift == 0 or defer.** Measure CI-native on ubuntu; merge only on zero drift across the ~115 committed PNGs, otherwise defer to a todo with browser revisions recorded pre/post. **No recapture lane opens in this milestone.**
- **Green evidence: n≥20 via `workflow_dispatch` on the single affected job**, not 20 full pushes. Reuse the FAST-01 n=52 machinery; build no new harness.
- **Triage fixes nothing.** Todos resolve to exactly keep / close / defer with a reason. Zero todos are fixed during triage; the triage commit's diff touches only `.planning/todos/`.
- **`test/example/`: mirror only the counterparts of templates actually edited**, per-file checklist; the missing template↔example parity guard is a future-milestone todo (FUT-01). Record the decision explicitly — nothing fails if it is wrong, which is exactly why it must be written down.
- **Two adjacent gaps become todos, not phases:** `example_unit_smoke` missing from `ci-gate.needs` (FUT-03) and `scripts/ci/launch-pack-contract.sh` having no workflow caller (FUT-04). File with the diagnosis attached.

## Ordering and Parallelism

**Fully parallel from day one:** Phases **236**, **237**, **238** — no shared files. (One collision, pre-resolved: `lib/sigra/admin/live/audit_index_live.ex` belongs to **236**; the Phase 237 `lib/` doc sweep skips it.)

**Forced sequence (each with the dependency that forces it):**

- **238 tag guard → 238 tag deletion** — a guard added after deletion prevents nothing, and the next close flow re-mints.
- **236 → 239** — the templates sweep perturbs `install_golden_contract` / `install_smoke`; it needs a trustworthy gate.
- **236 + 237 → 240** — the green-main evidence needs the flake fix on `main` and Pages green before issue #231 can be closed against it.
- **239 → 241** — the shipped-surface strip must precede the leakage gate; gating a dirty tree is red forever.
- **236 → 241** — the honest-skip-parity guard pins `ci.yml` job ids; writing it before 236's `ci.yml` edits pins a moving target.
- **238 + 239 + 240 → 242** — the release cut needs a green gate, a namespace that cannot be re-polluted, and a clean shipped surface.
- **242 → 243** — drain after the cut, so the release does not ship deps that never ran a full green.
- **243 → 244** — Playwright 1.62 lands last and alone, or baseline drift is unattributable.
- **243 + 244 → 245** — the branch prune is last: PR #211/#219's *base* branch is a prune candidate, and deleting a PR's base closes the PR.

## Phases

- [x] **Phase 236: Flake Root Cause — Reproduce, Name, Fix** - Manufacture a RED, name the root cause, fix it in shipped `lib/` (not a retry wrapper), and mechanize the prohibition (completed 2026-09-15)
- [x] **Phase 237: Clean Working Tree, Green Pages, Clean `lib/` Docs Surface** - The zero-coupling Lane-0 batch: gitignore, stashes, worktrees, stray artifacts, the Pages fix, and the HexDocs-rendering doc strip (completed 2026-09-16)
- [x] **Phase 238: Tag Guard, Then Tag Deletion** - A server-side ruleset proven RED first, then allowlist-driven deletion of the 28 `v1.NN` + 11 `phase-238-*` tags (completed 2026-09-17)
- [ ] **Phase 239: `priv/templates/` Sweep + One Batched Re-bless** - Strip adopter-shipped bookkeeping, verified on a freshly generated app and the built tarball — never on the source tree
- [ ] **Phase 240: Green-Main Evidence + Honest Pages Script** - n≥20 dispatch-proven green on the affected job at final HEAD, a script that fails loudly on 403, and issue #231 closed against that evidence
- [ ] **Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard** - Four guards made real or removed, each demonstrated RED against a committed known-bad fixture
- [ ] **Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1** - The irreversible public-artifact phase: retire `1.20.0`, revert its docs, record what retirement does *not* do, publish 1.5.1
- [ ] **Phase 243: Drain the Queue — Dependabot Tiers A/B, Stale PRs, Todo Triage** - Merge on locked versions (branch names lie), close 8 stale PRs with reasons, triage every todo without fixing one
- [ ] **Phase 244: `@playwright/test` 1.59.1 → 1.62.1, Alone** - Measure CI-native drift across ~115 PNGs; merge only at zero drift, otherwise defer with the measurement attached
- [ ] **Phase 245: Branch Prune — Local and Remote** - Destructive and PR-coupled, so it goes last, with every pre-prune SHA still resolvable afterward

## Phase Details

### Phase 236: Flake Root Cause — Reproduce, Name, Fix

**Goal**: `main`'s aggregate gate stops flipping red on an unchanged SHA — because the `Generated admin Playwright smoke` failure has a named, fixed cause, not because it was retried into silence.
**Depends on**: Nothing (first phase; runs in parallel with 237 and 238)
**Requirements**: GREEN-01, GREEN-02
**Success Criteria** (what must be TRUE):

  1. A **captured RED** exists for `expect(page).toHaveURL(...)` at `test/example/priv/playwright/tests/admin-generated.spec.ts:428`, manufactured deliberately (local `--repeat-each`, or a dispatch-only `trace: 'on'` run) — because `playwright.config.ts:59` hardcodes `retries: 0`, so no trace artifact exists today and none can be harvested. The reproduction is recorded with its run id or local artifact path, and no fix is accepted without it.
  2. A written differential diagnosis names the cause as harness race, DB collision, or product race. If it is the product race, `/admin/audit` has exactly **one** owner of its URL: a person driving the audit filter in a generated app sees the filter apply and the URL update, with no plain `<form method="get">` / `<a href>` competing against `handle_params/3` in `lib/sigra/admin/live/audit_index_live.ex` — and the fix is behaviour-preserving in rendered classes/layout, so `scripts/ci/snapshot-canary-guard.sh` stays green (no PNG recapture opens; see the standing constraints).
  3. The affected job, dispatched repeatedly against the fix, passes every repeat, and the Criterion-1 reproduction no longer reproduces — both observed from the GitHub Actions API run list, not from reading YAML.
  4. Adding a retry wrapper (`retries`, `waitForTimeout`, `test.slow()`) **fails** a `scripts/ci/prohibitions/*.test.mjs` guard, demonstrated RED against a committed known-bad fixture; and the dead `PLAYWRIGHT_RETRIES: 1` at `ci.yml:1460` is either wired to `playwright.config.ts` or deleted (it is itself a dishonest surface).
  5. If root cause genuinely fails, the only accepted close is a **dated quarantine entry naming an owner** in `.github/ci-skip-manifest.tsv` — an explicit, attributed risk acceptance. Retry-wrapping is never that fallback.

**Plans**: 4 plans

Plans:
**Wave 1**

- [x] 236-01-PLAN.md — Manufacture the RED (tracer), write the differential diagnosis, and take the D-05 branch call *(wave 1)*

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 236-02-PLAN.md — Make `audit_index_live.ex` the sole owner of its URL: six `<.link patch>` anchors, `phx-submit`, one whitelisting `handle_event` → `push_patch` *(wave 2)*
- [x] 236-03-PLAN.md — The `p17` retry-wrapper guard + committed known-bad fixture, delete `PLAYWRIGHT_RETRIES`, correct STACK.md, renumber SURF-04 to `p18` *(wave 2)*

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 236-04-PLAN.md — SC-3 evidence at n=5 sequential PR runs, the AFTER-FIX-GREEN ledger slot, and the named deferrals *(wave 3)*

### Phase 237: Clean Working Tree, Green Pages, Clean `lib/` Docs Surface

**Goal**: A maintainer who clones Sigra fresh sees a clean `git status`, a Pages check that is green because the site builds, and HexDocs pages that carry no internal planning bookkeeping.
**Depends on**: Nothing (runs in parallel with 236 and 238; skips `lib/sigra/admin/live/audit_index_live.ex`, which 236 owns)
**Requirements**: GREEN-03, REPO-01, REPO-02, SURF-02, REPO-03
**Success Criteria** (what must be TRUE):

  1. A fresh `git clone` of `origin/main` reports a clean `git status` with no untracked `.gsd/`, `.planning/.gsd-ws-arg`, `sigra-*.tar`, `.log` or screenshot artifacts — and `doc/llms.txt` is still **tracked** via a `!doc/llms.txt` negation (never deleted), with its three live consumers (`phase_148_*`, `phase_149_*`, `scripts/ci/launch-pack-contract.sh`) passing under `mix ci`.
  2. `gh api repos/szTheory/sigra/pages` reports a built (not `errored`) state and the published Pages URL serves a page — observed live against the GitHub API after the operator `PUT` plus the root `.nojekyll` backstop, with `guides/introduction/code-walkthrough.md:174` no longer crashing the legacy Jekyll builder.
  3. `git worktree list` shows only the live worktree (reached via `git worktree prune`, never `rm -rf` first — one entry has a null HEAD), all 6 stashes exist as **pushed refs on `origin`** and are `git cat-file -e`-resolvable, and `git stash list` is empty. No `git gc`, `git reflog expire`, or `--prune=now` runs anywhere.
  4. Nothing rendered on HexDocs carries planning bookkeeping: `@moduledoc`/`@doc` ranges in `lib/` are clean starting with `lib/sigra/audit.ex:5` (a dead `.planning/` link currently live in published docs), and `mix docs` runs **warning-free as a gate**, with every surviving `skip_undefined_reference_warnings_on` entry proven load-bearing by remove-and-retest.
  5. No `# SECURITY:`-class rationale is lost: the phase diff deletes no comment block matching `security|CSRF|enumeration|timing|scope|impersonation` — the bookkeeping token goes, the sentence stays.

**Plans**: 6 plans

Plans:

- [x] 237-01-PLAN.md — reachable ignore negation, ignored agent scratch dir, regenerated docs index, clean fresh clone (REPO-01, REPO-02)
- [x] 237-02-PLAN.md — record prior Pages config, repoint publish source, two live observations; de-fang the Liquid-crashing guide line (GREEN-03)
- [x] 237-03-PLAN.md — sanitized worktree snapshot, prune 6 worktrees to 1; all 6 stashes left local and untouched, SC-3's stash half recorded deliberately unmet per D-09 (REPO-03)
- [x] 237-04-PLAN.md — regex-class rationale-preservation check proven RED, then the 4 named dead planning references removed from `lib/` doc attributes (SURF-02)
- [x] 237-05-PLAN.md — 3 dead guide links removed, suppression list earned down 9 -> 7, false comment corrected (SURF-02)
- [x] 237-06-PLAN.md — evidence ledger at final committed HEAD, ratchet baseline, 2 required todos, `mix ci` gate (all five requirements)

### Phase 238: Tag Guard, Then Tag Deletion

**Goal**: The `v*` tag namespace means exactly one thing — a real release — and cannot be re-polluted by the next close flow.
**Depends on**: Nothing (runs in parallel with 236 and 237); must precede Phase 245
**Requirements**: REL-01, REL-02
**Success Criteria** (what must be TRUE):

  1. Pushing a scratch tag `v9.9` is **rejected server-side** by a GitHub tag ruleset (`target: "tag"`, RE2 `tag_name_pattern`, `bypass_actors: []`), while `v9.9.9-rulesettest` is accepted — both observed live against the repo, then both removed. This doubles as the guard's required RED proof and as the empirical answer to whether the ruleset blocks release-please's own `v1.5.1` push. The guard is **not** placed in `release_ref_guard`, which short-circuits on non-`workflow_dispatch` events and would never run.
  2. A paired repo-side contract test fails when the ruleset is absent or altered — demonstrated red by querying a known-bad ruleset fixture — so deleting it in Settings is caught rather than silent.
  3. The delete set comes from a **committed explicit allowlist file**, never a glob at the `git tag -d` call site (`v1.4*` matches both `v1.4` and `v1.4.0`). Post-deletion, `git ls-remote --tags origin` is asserted **set-equal** to a regex-derived keep-set — three-component SemVer plus `archive/*` — with no count hardcoded anywhere.
  4. `gh release list` returns the same release count before and after with **zero** drafts (`[.[]|select(.draft)]|length == 0`), and a published HexDocs "View source" link still resolves — proving no tag backing a GitHub Release or `mix.exs` `source_ref` was touched. Deletion runs local → verify → remote, never in one command.
  5. ADR 003 is amended with the deletion date, the path to the committed delete-list, and the prescribed `milestone/` + `proof/` namespaces for future non-release tags.

**Plans:** 6/6 plans complete

Plans:
**Wave 1**

- [x] 238-01-PLAN.md — Authorize repo-settings writes, commit the pre-change ruleset record, and settle the Tier-1/Tier-2/Tier-3 ladder in one probe cycle

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 238-02-PLAN.md — Tracer: ruleset live and active, `v9.9` rejected / `v9.9.9-rulesettest` accepted, snapshot committed, guard born falsifiable, delete-governance probed

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 238-03-PLAN.md — Full `p19` contract assertions, committed known-bad fixture, recorded RED proof, ledger grammar enforced, live drift read on the observer lane
- [x] 238-04-PLAN.md — Committed 39-row delete allowlist with pre-deletion SHAs, and the dry-run-by-default deletion script with its edge behaviors proven on a scratch clone

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 238-05-PLAN.md — Execute deletion behind a one-way-door checkpoint: local pass, verify, remote pass, verify, and an untouched release surface

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 238-06-PLAN.md — Maintainer runbook subsections, ADR 003 amendment correcting guardrail 3, any REL-01 supersession, and the ledger closed at the final head

### Phase 239: `priv/templates/` Sweep + One Batched Re-bless

**Goal**: Nothing an adopter generates or downloads contains Sigra's internal planning bookkeeping.
**Depends on**: Phase 236 (the golden/install lanes need a trustworthy gate)
**Requirements**: SURF-01, SURF-03
**Success Criteria** (what must be TRUE):

  1. A **freshly generated app** (`mix phx.new` + `mix sigra.install`) greps clean for `.planning/` paths and planning bookkeeping — including `priv/templates/sigra.install/organizations/organizations.ex:59`, the one dead `.planning/` path that ships into every adopter's project today.
  2. The `mix hex.build` **tarball**, extracted, greps clean for `.planning/` paths — the source tree is never the thing that is asserted.
  3. The re-bless is exactly **one** batched `MIX_ENV=test mix sigra.fixture.rebless_golden` in its own separate commit, whose diff contains **only comment lines** — any non-comment line is a stop-the-line event, because the task makes drift disappear regardless of whether the drift was intended. Afterward `--check` exits 0 and `mix ci.install_golden` plus the `install_golden_contract` job are green.
  4. Only the `test/example/` counterparts of templates actually edited are mirrored, recorded as an explicit per-file checklist in the phase SUMMARY, and the absent template↔example parity guard is filed as a todo (FUT-01) rather than built here.
  5. Load-bearing infrastructure is provably untouched: `git diff origin/main -- .github/` shows no `name:` change (a renamed required context never reports and PRs hang forever), and no `# SECURITY:`-class comment sentence is deleted.

**Plans**: TBD

### Phase 240: Green-Main Evidence + Honest Pages Script

**Goal**: "main is green" is a measured claim backed by run ids, and the scripts that report green can no longer report green while failing.
**Depends on**: Phase 236 (the fix must be on `main`), Phase 237 (Pages fixed)
**Requirements**: GREEN-04, GREEN-05
**Success Criteria** (what must be TRUE):

  1. `ci-gate`'s previously-flaky lane is green across **n≥20** runs triggered by `workflow_dispatch` (or a matrix repeat) on the single affected job — not 20 full pushes — with every run id listed from the GitHub Actions API, captured at the **final committed HEAD on a clean tree**.
  2. Across that same window, `ci-gate` on `main` shows no red attributable to the flake, and the aggregate gate's verdict is readable from the API run list rather than asserted in prose.
  3. `scripts/ci/ensure-github-pages-legacy-branch.sh` **fails loudly** on a 403 instead of logging and continuing — demonstrated red against a stubbed/denied API response — so the publisher job can no longer report success while the site stays broken.
  4. Issue **#231** is closed with a comment citing those run ids and the live Pages state, verified closed via `gh issue view 231`; the two owning todos (`2026-07-30-admin-generated-audit-presets-actor-filter-race.md`, `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`) are closed with the same evidence.

**Plans**: TBD

### Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard

**Goal**: Every guard in the repo that currently asserts nothing either asserts something real or is gone — and new adopter-visible leakage cannot land.
**Depends on**: Phase 236 (`ci.yml` job ids settled), Phase 239 (the surface must be clean before it is gated)
**Requirements**: DEBT-01, DEBT-02, DEBT-03, DEBT-04, SURF-04
**Success Criteria** (what must be TRUE):

  1. An ADR records the TEST-01/02 supersession by the single-owner `mix ci` design; `Sigra.CI.ExUnitTimingFormatter` and its test are deleted, `mix ci` is green, and the alias topology is unchanged (`phase_233_library_economics_contract_test.exs` still passes — the alias is never edited).
  2. The replacement for `phase_233_library_economics_contract_test.exs` is demonstrated **RED against a committed known-bad fixture** before acceptance, so it asserts the replacement *guarantee* the ADR names rather than re-stating HEAD. Its dependency on `.planning/phases/235-.../235-FAST-01-REMEDIATION.json` is either kept deliberately or retired deliberately — recorded either way.
  3. Either `scripts/ci/prohibitions/honest-skip-parity.test.mjs` exists and is observed **failing against HEAD's `MAINTAINING.md`** before `:172-178,231` are corrected to the actual shard topology (write the guard, don't delete the claim) — or the false citation is removed from `.github/ci-skip-manifest.tsv`. The manifest never cites a file that does not exist.
  4. `.github/actions/example-playwright-boot/action.yml` is visible to the action-pinning guard **in both directions**: unpinning one of its four `uses:` makes the guard fail, and re-pinning makes it pass — both demonstrated, closing the `action_entry/4` blind spot for local `"./"` actions.
  5. `scripts/ci/prohibitions/p18-*.test.mjs` hard-fails a fixture containing a `.planning/` path, a `priv/templates/` bookkeeping token, and a HexDocs-rendering doc-range token; the remaining inline `lib/` comment count is a committed baseline under a **monotonic-decrease ratchet** (raising it fails; zero is not the target); and the guard is picked up by the `ci.yml:393` glob with **zero workflow edits and no `mix ci` change**.

**Plans**: TBD

### Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1

**Goal**: An adopter landing on Sigra's Hex page reads current documentation, is warned about the phantom `1.20.0`, and can install a real release — and the project's own record states plainly what the retire did and did not fix.
**Depends on**: Phase 240 (green-gate evidence), Phase 238 (namespace guard in place before release-please tags `v1.5.1`), Phase 239 (the tarball ships clean)
**Requirements**: REL-03, REL-04, REL-05, REL-06
**Success Criteria** (what must be TRUE):

  1. `GET https://hex.pm/api/packages/sigra` is captured as **committed pre/post artifacts**, and the post artifact's `retirements` field contains `1.20.0` with reason `invalid` — executed by a `workflow_dispatch` job under the existing `secrets.HEX_API_KEY` (the same non-interactive `api:write` path `hex-publish.yml:180-187` already uses), **not** an interactive operator runbook. The write key is never pasted into any plan, evidence file, or commit message — this is a public repo.
  2. The milestone states the truth about resolution, positively asserted: `latest_stable_version` is **still `1.20.0`** post-retire, and in a clean `HEX_HOME` a `{:sigra, "~> 1.0"}` `mix deps.get` resolves `1.20.0` while printing `RETIRED!`, and `{:sigra, "~> 1.5"}` resolves 1.5.x cleanly. `HEX_IGNORE_RETIREMENTS` is never set — the warning *is* the proof. No artifact in this milestone claims the retire fixed resolution.
  3. `https://hexdocs.pm/sigra/` serves **1.5.x** documentation instead of "Sigra v1.20.0" — title read live after `mix hex.publish docs --revert 1.20.0` (the *docs* revert, which has no time limit; the release-tarball revert's window closed in 2026-04 and is never attempted). Whether the docs revert also moves `latest_stable_version` is **measured** from the pre/post artifacts and reported, never assumed.
  4. An ADR records pinned install docs (`{:sigra, "~> 1.5"}`) as the deliberate resolution decision and states that retirement moves neither `latest_stable_version` nor resolution.
  5. `sigra 1.5.1` is listed on the Hex API as a published release, cut from a gate observed green, with the `## Unreleased` CHANGELOG block folded into the release section **before** PR #224 merges, and `scripts/ci/release-post-publish-verify.sh` passing on the publish path.

**Plans**: TBD

### Phase 243: Drain the Queue — Dependabot Tiers A/B, Stale PRs, Todo Triage

**Goal**: The open-PR and todo backlog reflects live work only, with every merged bump's real version verified and nothing quietly fixed along the way.
**Depends on**: Phase 242 (drain after the cut, so the release ships nothing that never ran a full green)
**Requirements**: QUEUE-01, QUEUE-03, QUEUE-04
**Success Criteria** (what must be TRUE):

  1. For every merged Dependabot PR, the **locked** version read from `mix.lock` / `package-lock.json` after merge matches the PR **title**, not the branch name — branch names lie (`dependabot/hex/hammer-7.4.1` is really →7.5.0; `oban-2.24.0` is really →2.24.1). Tier A (`attest-build-provenance`, `@anthropic-ai/sdk`, `zod`, `otplib`) merges as one batch; Tier B (`oban`, `hammer`, `flop_phoenix`, `threadline`, `credo`, `@axe-core/playwright`) merges individually.
  2. After each Tier B merge, `ci-gate` is observed green on `main` from the Actions API before the next one starts — with `library_tests_dep_off` specifically green for `#226` (Threadline), and the `hackney ~> 4.7` override re-verified against 0.9.0 and either dropped (a CLEAN-BASELINE win) or kept with a recorded reason. `#215` keeps its same-line `# vX.Y.Z` pin comment so the action-pinning contract test still passes. New Credo findings, if any, become todos — not fixes.
  3. All 8 stale phase/recapture PRs are closed **with a stated reason each**, verified via `gh pr list --state closed`, and **no branch is deleted here** — PR #211/#219's base is a Phase 245 prune candidate.
  4. Every pending todo carries exactly one disposition — keep (with a reason), close (with evidence), or defer (with a named future milestone) — and the triage commit's diff touches **only** `.planning/todos/`. **Zero todos are fixed during triage.** The ~12 owned by earlier phases close as a side effect of those phases, not here.
  5. `FUT-01`…`FUT-05` plus the two adjacent gaps (`example_unit_smoke` absent from `ci-gate.needs`; `launch-pack-contract.sh` with no workflow caller) exist as todo files with their diagnosis attached, and Dependabot `groups:` is filed rather than implemented.

**Plans**: TBD

### Phase 244: `@playwright/test` 1.59.1 → 1.62.1, Alone

**Goal**: The Playwright bump either lands with provably zero visual consequence, or is deferred with a measurement — never merged on hope, and never dragging a recapture obligation into a non-UI milestone.
**Depends on**: Phase 243 (last and alone, so any baseline drift is attributable to exactly one cause)
**Requirements**: QUEUE-02
**Success Criteria** (what must be TRUE):

  1. The bundled browser revisions are recorded **pre and post** (chromium build from the Playwright browsers manifest) as a committed artifact, regardless of the merge decision.
  2. Baseline drift across the ~115 committed PNGs is measured **CI-native on ubuntu** (never darwin), with the measuring run id recorded and the `fast_checks` Playwright cache-key guard re-checked against the new version.
  3. PR #213 is merged **only if measured drift is exactly zero**; otherwise it is closed/deferred to a todo carrying the measurement, and **no recapture lane is opened** — visible either way in `gh pr view 213`.
  4. Whichever branch is taken, `ci-gate` is observed green on `main` afterward across every Playwright consumer (`example_playwright_shard`, `example_playwright_smoke`, `generated_admin_playwright_smoke`), and no PNG baseline is committed in the same change as any other cause.

**Plans**: TBD

### Phase 245: Branch Prune — Local and Remote

**Goal**: The branch list shows only live work and deliberate safety anchors, with nothing lost — the compound-reachability risk closed last, once everything that depends on a ref is already resolved.
**Depends on**: Phase 243 (stale PRs closed first), Phase 244; and Phases 237/238 (stashes materialized, worktrees pruned, tags settled) must already be done
**Requirements**: REPO-04
**Success Criteria** (what must be TRUE):

  1. A pre-prune `git for-each-ref` snapshot is committed, and after the prune **every** SHA recorded in it is still `git cat-file -e`-resolvable — proven by re-running the check against the committed snapshot, not asserted.
  2. The documented safety refs survive on `origin`: `ci/phase-235-16-source-complete` (442 commits ahead of `main`, holding the TEST-01/02 re-wiring), `safety/local-main-before-release-cleanup-*`, and `archive/local-main-pre-235-recovery`.
  3. The exclusion set is derived from `gh pr list --json headRefName,baseRefName` in **both** directions, and after the prune `gh pr list` shows every open PR still open with an intact base — no PR was closed as a side effect of a deleted base branch.
  4. No `git gc`, `git reflog expire`, or `--prune=now` ran anywhere in this milestone, recorded explicitly in the phase SUMMARY.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 236. Flake Root Cause | 4/4 | Complete    | 2026-09-15 |
| 237. Clean Working Tree + Pages + `lib/` Docs | 6/6 | Complete    | 2026-09-16 |
| 238. Tag Guard, Then Tag Deletion | 6/6 | Complete    | 2026-09-17 |
| 239. `priv/templates/` Sweep + Re-bless | 0/? | Not started | - |
| 240. Green-Main Evidence + Honest Pages Script | 0/? | Not started | - |
| 241. Debt Retirement + Leakage Guard | 0/? | Not started | - |
| 242. Hex Retire + Docs Revert + Cut 1.5.1 | 0/? | Not started | - |
| 243. Queue Drain + Todo Triage | 0/? | Not started | - |
| 244. `@playwright/test` Bump, Alone | 0/? | Not started | - |
| 245. Branch Prune | 0/? | Not started | - |

## Requirement Coverage

| Phase | Requirements |
|-------|--------------|
| 236 | GREEN-01, GREEN-02 |
| 237 | GREEN-03, REPO-01, REPO-02, REPO-03, SURF-02 |
| 238 | REL-01, REL-02 |
| 239 | SURF-01, SURF-03 |
| 240 | GREEN-04, GREEN-05 |
| 241 | DEBT-01, DEBT-02, DEBT-03, DEBT-04, SURF-04 |
| 242 | REL-03, REL-04, REL-05, REL-06 |
| 243 | QUEUE-01, QUEUE-03, QUEUE-04 |
| 244 | QUEUE-02 |
| 245 | REPO-04 |

**27 of 27 v1.48 requirements mapped; no requirement appears in more than one phase.**

---

## Shipped Milestone Detail

<details>
<summary>⚠️ v1.47 CI-EFFICIENCY (Phases 230-235) — SHIPPED 2026-09-15 (`override_closeout` · 21/24 requirements · TEST-01/TEST-02 unsatisfied · 46 artifacts acknowledged) · full detail in milestones/v1.47-ROADMAP.md</summary>

- [x] **Phase 230: Tier-1 Critical-Path Reclamation** — `@snapshot` grep-invert split, `admin_eval_render` demoted off PR, workflow-level concurrency, docs-only classifier, SHA-pinned browser cache, per-job timeouts (FAST-02..FAST-07) — completed 2026-07-29
- [x] **Phase 231: Gate Honesty + Nightly Revival** — nightly revived from 0-pass/9-fail, fail-closed honest-skip verdict, `admin_eval_render` hard signal restored, `wait-for-ci-gate.sh` extraction + label self-heal (GATE-01..GATE-04, DX-05) — completed 2026-07-31
- [x] **Phase 232: Playwright Economics** — authenticate once then shard: shared `example-playwright-boot` composite action across four consumers, five concurrent matrix seams converging on the unchanged protected context (PW-01/02/03) — completed 2026-07-31
- [x] **Phase 233: Library Suite Economics** — timing receipts, cost-balanced partition, dedicated scaffold receiver (TEST-01/02/03) — completed 2026-07-31 · **later superseded by Phase 234's single-owner topology; see below**
- [x] **Phase 234: Hygiene, Supply Chain, Contributor DX** — SHA-pinned release workflows with mutation coverage, weekly Dependabot across Actions/Mix/npm, machine-checked spec ownership, `mix ci` contributor parity (DX-01..DX-04, DX-06) — completed 2026-08-02
- [x] **Phase 235: Terminal Ratification — Measured, Not Read** — sealed, signed, source-complete 52-run population closing FAST-01 at p50 469s, plus the fail-closed 93-row GATE-05 ownership ledger (FAST-01, GATE-05) — completed 2026-09-09

**Headline outcome: PR wall-clock p50 27.3m → 469s (7m49s)**, n=52 authenticated runs — inside the <720s target and ~3.5x faster than baseline. Nightly went from 0-pass/9-fail to an honest mix.

**Closed as `override_closeout` with two unsatisfied requirements.** TEST-01 and TEST-02 are satisfied only on paper: `ExUnitTimingFormatter` and `SIGRA_EXUNIT_TIMING_PATH` have zero references in `.github/`, `scripts/`, or `mix.exs` at HEAD. Phase 234-01 removed the wiring and the re-wiring commits live on the parked 235.1 branch. The Phase 233 contract test was rewritten to *require* the replacement single-owner topology, so the guard blesses the regression rather than detecting it — which is why Phase 233 re-verified green. The milestone's performance goal was met by that replacement design, so the requirements were accepted as debt rather than re-litigated at close. Full diagnosis in `todos/pending/2026-09-15-test-01-02-timing-machinery-orphaned.md`; five audit-surfaced findings filed alongside it.

</details>

<details>
<summary>✅ v1.46 ADOPTER-EXPERIENCE (Phases 224-229) — SHIPPED 2026-07-27 (`override_closeout` · 15/15 requirements · 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md</summary>

- [x] **Phase 224: Experience Contract + Representative Slice** — JTBD/surface/state contract + UI-SPEC, extended generated-host review substrate, four representative states, ratified baseline comprehension + creative direction (EXPR-01/02) — completed 2026-07-19
- [x] **Phase 225: Secure First-Admin + Generated-Host Security Parity** — host-owned persisted-grant seam + `mix sigra.admin.{grant,revoke,list,check}`, customized policies never overwritten, all 10 impersonation-sensitive operations closed (BOOT-01/02/03, SEC-01) — completed 2026-07-19
- [x] **Phase 226: Auth Entry + Recovery** — semantic `sigra-auth-*` primitives across login, registration, confirmation, reset, reactivation, sudo, invitation acceptance (AUTHUI-01/02) — completed 2026-07-19
- [x] **Phase 227: Account Security Coherence** — settings, MFA, backup codes, passkeys, sessions, destructive flows; theme/a11y/latency ratified (AUTHUI-03/04) — completed 2026-07-19
- [x] **Phase 228: Admin Audit Precision + Boundary Pass** — duplicate filter state repaired, Failures/Impersonation as shareable GET presets, labeled Active-filters region (AUDIT-01/02) — completed 2026-07-19
- [x] **Phase 229: Adoption Handoff + Terminal Ratification** — fresh-host install→revocation smoke, golden drift/idempotency, docs reconciliation, human visual acceptance of the login composition (PROOF-01/02/03) — completed 2026-07-27

**Closed with 8 deferred audit findings.** W-3 is the substantive one: generated auth has browser coverage on exactly one surface (login, no-passkeys), so ~1,100 lines of template change are verified almost entirely by source-string assertion. W-1 (a half-fixed two-branch label collision) is the concrete evidence of what that costs. All eight carry full diagnosis in `todos/pending/2026-07-28-w{1..8}-*`.

</details>

<details>
<summary>⚠️ v1.45 RELEASE-CURRENCY (Phases 221-223) — SHIPPED 2026-07-11 (`override_closeout` · Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md</summary>

- [x] **Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt** — `<.button type>` upgrade-smoke fix + `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin (PUB-01), v1.2.0 + v1.3.0 published to Hex (PUB-02/03), generated-host debt paid (SHIP-01/02/03); PUB-04 retire deferred at phase close (5/5) — completed 2026-07-10
- [x] **Phase 222: Release-Lane Hardening (No Silent Rot)** — durable resolver stray-exclusion, shared loud-signal find-or-create issue notifier on red-`main`/publish-failure, `dry_run=true` publish-path proof + MAINTAINING runbook (HARD-01/02) (3/3) — completed 2026-07-11
- [~] **Phase 223: Get Current on Hex + Terminal Currency Proof** — ⏸️ **DEFERRED 2026-07-11.** Pre-retire snapshot captured (223-01 Task 1). The stray `1.20.0` retire (operator/interactive Hex write step, PUB-04) was deferred indefinitely by Jon (no adopters); PUB-05 (adopter resolution) + PROOF-01 (currency trust bundle) are carried/unproven because they're unsatisfiable while `latest_stable_version=1.20.0` outranks `1.3.0`. Non-blocking (CI gate green regardless). Root cause: ADR 003. Resume `/gsd-execute-phase 223` after the retire lands.

</details>

<details>
<summary>✅ v1.44 ADMIN-UX-RATCHET (Phases 216-220) — SHIPPED 2026-07-10 · full detail in milestones/v1.44-ROADMAP.md</summary>

- [x] **Phase 216: Harness Foundation + Award Gradient** — render substrate, evidence-integrity + stale-render guards, deterministic visual probes, award sub-score ledger extension + verify-then-climb, end-to-end on 2 pilot surfaces (9/9) — completed 2026-07-04
- [x] **Phase 217: Adversarial Panel + Auto-Fix Safety Rails** — 4-lens LLM panel (3 persona/JTBD + 1 graphic-design), k=3 consensus, settled-findings suppression, findings-count-monotonic guard, fix queue, safe-class auto-apply with per-fix auto-revert (8/8) — completed 2026-07-04
- [x] **Phase 218: Elevation Wave + Nit Cleanup** — full loop across all 8 admin surfaces + L1/L2 component fractal; verify-then-climb each; fold in UI-01 (demo-DX nits) + UI-02 (Tasklane rebrand residuals); batched reviewable PR (10/10) — completed 2026-07-09
- [x] **Phase 219: Baseline Recapture + Canary Reconciliation** — ~115 PNG baselines recaptured in-CI (ubuntu), allowlists reset to empty steady-state, snapshot-canary + generated-host parity green (5/5) — completed 2026-07-09
- [x] **Phase 220: Terminal Ratification** — award sub-score cells locked forward under monotonic guard, harness runbook committed, milestone shipped via terminal PR #73 (`c0595e09`) gated on 5 required CI checks; LLM panel advisory/off-CI throughout (4/4) — completed 2026-07-10

</details>

<details>
<summary>✅ v1.43 STABILIZE (Phases 213-215) — SHIPPED 2026-07-03 · full detail in milestones/v1.43-ROADMAP.md</summary>

- [x] **Phase 213: Latest-Phoenix Compatibility** — generated-host compile fix vs phx.new ≥1.8.8, golden fixture reblessed, all 11 archive pins → 1.8.8 + `--check` drift-detector (2/2) — completed 2026-07-02
- [x] **Phase 214: Debt & Robustness Clear** — Oban enqueue guard, `delete_session/3` IDOR guard, app.css corruption cleanup + CI guard, Chimeway.Repo + conditional `:upgrade` skip, retired panel-schema-check.sh + deleted stray v1.20.0 tag (5/5) — completed 2026-07-03
- [x] **Phase 215: Terminal Ratification** — library green (2404/0) + example green (323/0) recorded signals, ledger reconciled, 5 required CI checks green on merged PR #67 (4/4) — completed 2026-07-03

</details>

<details>
<summary>✅ v1.42 ADMIN-DS-ELEVATION (Phases 205-212) — SHIPPED 2026-07-02 · full detail in milestones/v1.42-ROADMAP.md</summary>

- [x] **Phase 205: Foundation** — Adversarial persona/JTBD rubric, real-configuration `board-cfg-*` gallery, IA diagnostic, stress fixtures (4/4) — completed 2026-06-28
- [x] **Phase 206: L1 Component Elevation Wave A** — 8 highest-reuse L1 components to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 207: L1 Component Elevation Wave B + L0 Token Layer** — remaining 5 L1 components + token layer to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 208: L2 Meta-Component Group Elevation** — all 11 MG groups (MG-1…MG-11) to Tier-2 (208-03/GROUP-02 folded into 210-02) (3/3) — completed 2026-07-01
- [x] **Phase 208.1: v1.42 CI-Gate Remediation (INSERTED)** — fix ~15 never-CI-validated admin Playwright failures blocking the backlog ship (4/4) — completed 2026-07-01
- [x] **Phase 209: Judgment-Level Page Pass** — adversarial persona panel over all 8 pages; remediations under the monotonic guard (6/6) — completed 2026-07-01
- [x] **Phase 210: Remaining Cell Elevation** — user-sessions page + 3 persona flows to Tier-2 (2/2) — completed 2026-07-01
- [x] **Phase 211: Terminal Ratification** — every ledger cell reads 2, baselines recaptured, generated-host parity proven (5/5) — completed 2026-07-01
- [x] **Phase 212: v1.42 Integration Merge (INSERTED)** — canary reconciliation + gate persona flows + un-skip generated-host smoke; PR #63 merged to origin/main (4/4) — completed 2026-07-02

</details>

<details>
<summary>✅ v1.41 ADMIN-UX-ELEVATION (Phases 199-204) — SHIPPED 2026-06-27 · full detail in milestones/v1.41-ROADMAP.md</summary>

- [x] **Phase 199: Foundation** — Tier-2 scorecard & stress fixtures — completed 2026-06-25
- [x] **Phase 200: User Detail Elevation** — completed 2026-06-26
- [x] **Phase 201: Users Index Elevation** — completed 2026-06-26
- [x] **Phase 202: Audit Surfaces Elevation** — completed 2026-06-26
- [x] **Phase 203: Consistency Propagation** — completed 2026-06-26
- [x] **Phase 204: Terminal Ratification** — completed 2026-06-27

</details>

Earlier milestones (v1.33–v1.40) are archived under `milestones/`.
