# Requirements: Sigra — v1.48 CLEAN-BASELINE

**Defined:** 2026-09-15
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

**Milestone thesis:** Baseline hygiene + cut a release. NOT a feature milestone. Phases continue from **236**.

**Standing guardrail for every requirement below:** acceptance must include at least one
observation of a live external system (GitHub API, Hex API, a freshly generated app, a
captured CI run). **Count-only acceptance — a grep count or `wc -l` — is rejected at review.**
This repo has three documented precedents of a green gate that verified nothing.

## v1.48 Requirements

### Green main, honestly (GREEN)

- [x] **GREEN-01**: The `Generated admin Playwright smoke` failure is reproduced as a captured RED run before any fix is written (no traces exist today — `PLAYWRIGHT_RETRIES: 1` at `ci.yml:1460` is dead and `playwright.config.ts:59` hardcodes `retries: 0`).
- [x] **GREEN-02**: The audit-filter navigation race is fixed in shipped `lib/` — `lib/sigra/admin/live/audit_index_live.ex` no longer runs a plain `<form method="get">` plus `<a href>` presets against `handle_params/3` with no `handle_event`. If root-cause fails, a **dated quarantine entry naming an owner** is recorded instead. Retry-wrapping is prohibited.
- [x] **GREEN-03**: GitHub Pages builds successfully on push — the legacy Jekyll builder no longer renders `main`'s repo root and fails on `guides/introduction/code-walkthrough.md:174`.
- [x] **GREEN-04**: `ci-gate` is proven green on the affected job across n≥20 runs via `workflow_dispatch` (not 20 full pushes), captured at the final committed HEAD on a clean tree.
- [x] **GREEN-05**: Issue #231 is closed against that evidence, and `scripts/ci/ensure-github-pages-legacy-branch.sh` no longer reports success while silently swallowing a 403.

### Release namespace + cut the release (REL)

- [x] **REL-01**: A tag-name guard rejects any non-SemVer `v*` tag — a GitHub tag ruleset (server-side) plus a paired contract test — demonstrated **RED** against a known-bad tag name. Lands **before** any deletion.
- [x] **REL-02**: The 28 non-SemVer `v1.NN` planning tags and 11 `phase-238-*` tags are deleted local and remote from a **committed explicit allowlist**, never a glob. The delete set is asserted set-equal to the allowlist, the 12 three-component SemVer release tags and `archive/*` are untouched, and `gh release list` count is unchanged with zero untagged drafts.

> **Supersession — recorded 2026-09-17 (Phase 238).** REL-01's original text above is left
> unedited and remains the record of what was asked for. What landed is narrower than its implied
> granularity, and this note — not a quiet re-scope — is how that is recorded. The trigger is the
> rule type read from the committed snapshot `.github/rulesets/tag-namespace.json`, which carries
> exactly one rule, of type `creation`.
>
> **Delivered:** a live `tag-namespace` ruleset (`target: "tag"`, `enforcement: active`,
> `bypass_actors: []`) whose single `creation` rule is scoped by
> `ref_name.include: ["refs/tags/v*"]` minus `ref_name.exclude: ["refs/tags/v*.*.*"]`, paired with
> the offline contract guard `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`,
> demonstrated RED against the committed known-bad fixture, landed before the first deletion.
> REL-01's **"server-side"** and its **paired contract test, demonstrated RED, before any
> deletion** clauses are satisfied verbatim.
>
> **Why not the literal shape:** the Tier-1 mechanism, a `tag_name_pattern` rule, was rejected by
> the live API with `HTTP 422 — Invalid rule 'tag_name_pattern'`. It is enterprise-gated on this
> Free-tier repository. That was observed by live probe, not assumed.
>
> **What it does not cover:** server-side prevention at coarser granularity than a version pattern.
> It blocks the two-component `vX.Y` recurrence class — the shape behind 28 of the 39 deleted tags
> and both post-ADR-003 regressions — and admits four-segment and non-numeric shapes
> (`v1.2.3.4`, `v1.a.b`, `v1..`, `v...`), each of which carries two dots and is therefore excluded
> from scope. It is a shape guard, not a SemVer validator. Outside the `v` prefix it governs
> nothing: the `archive/`, `milestone/` and `proof/` namespaces are out of scope entirely.
>
> **Two further locked artifacts are superseded by the same landed rule, and both are named here
> because neither may be narrowed silently:**
>
> - **Phase 238 CONTEXT D-04**, whose text is absolute — the ruleset contains no `creation` rule
>   and no `deletion` rule, ever. A `creation` rule is exactly what landed. D-04's stated objection
>   was that such a rule would block release automation's own three-component tag push; the
>   `exclude` list takes every three-segment release name out of the ruleset's scope, so that
>   objection does not apply to this shape, and the exclusion was proven live rather than assumed.
>   **D-04's second clause is untouched:** no `deletion` rule was built, so the delete-deadlock D-06
>   exists to avoid is still avoided — an in-scope tag was observed deleting successfully.
> - **ROADMAP Phase 238 SC-1**, which names the mechanism literally as an RE2 `tag_name_pattern`
>   rule. That **mechanism clause is superseded**; it is false as written. SC-1's **observable
>   outcome still holds and was observed live**: a two-component scratch name carries one dot, is
>   not covered by the three-dot-segment exclusion, stays in scope, and its creation is refused,
>   while a three-component release name is excluded and accepted. Mechanism and outcome are
>   different claims; recording the satisfied one as if it settled the superseded one is exactly
>   the quiet re-scope this note exists to prevent.
>
> The durable half of this supersession is the dated amendment in
> `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`. The two halves are one
> record, not alternatives, and both land in Phase 238's commit range.

- [ ] **REL-03**: Hex release `1.20.0` is retired with a message, verified by the Hex API `retirements` field containing `1.20.0`. Executed via `workflow_dispatch` under the existing `HEX_API_KEY` — **not** an interactive runbook.
- [ ] **REL-04**: `https://hexdocs.pm/sigra/` serves 1.5.x documentation rather than `Sigra v1.20.0`, via `mix hex.publish docs --revert 1.20.0` (the *docs* revert, which is unlimited in time — never the release-tarball revert, whose window closed in 2026).
- [ ] **REL-05**: An ADR records pinned install docs (`{:sigra, "~> 1.5"}`) as the deliberate resolution decision, and states plainly that retirement does **not** move `latest_stable_version` or change resolution. No artifact in this milestone may claim the retire fixed resolution.
- [ ] **REL-06**: Release **1.5.1** is cut and published to Hex from a green gate, with the `## Unreleased` CHANGELOG block folded into the release section before merge.

### Clean shipped surface (SURF)

- [x] **SURF-01**: Zero `.planning/` path references remain in `lib/` or `priv/templates/` — verified by grepping a **freshly generated app** and the `mix hex.build` tarball, not the source tree.
  - *Audit note (plan 239-09):* SURF-01 stays `[x]` while SURF-03 is unchecked because SURF-01's own wording is narrowly scoped to `.planning/` path references in `lib/` and `priv/templates/`, verified on a freshly generated app and on the built `mix hex.build` tarball — both measure zero at HEAD per the Requirements Coverage row of `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-VERIFICATION.md`, whereas SURF-03's broader "no planning bookkeeping" claim is falsified by that same report's SC-1 gap.
  - *Consistency note (plan 239-10, D-27) — SURF-01 vs. the amended SC-2:* the two texts describe the same surface, quoted here side by side rather than left to inference. Amended ROADMAP **SC-2** (Phase 239): "The `mix hex.build` **tarball**, extracted, greps clean for `.planning/` paths **under `lib/` and `priv/`** — the source tree is never the thing that is asserted." **SURF-01** (unchanged by this plan): "Zero `.planning/` path references remain in `lib/` or `priv/templates/` — verified by grepping a **freshly generated app** and the `mix hex.build` tarball, not the source tree." SURF-01 names `lib/` and `priv/templates/` as the *scope* and the tarball as the *verification vehicle*; SC-2 now names `lib/` and `priv/` as the asserted region inside that vehicle. `priv/templates/` ⊂ `priv/`, so SC-2 is the wider of the two and SURF-01 cannot pass while SC-2 fails. SURF-01's requirement sentence is byte-unchanged — it was already the narrower and correct wording, which is exactly why `239-VERIFICATION.md` rates SURF-01 satisfied while SC-2 failed.
- [x] **SURF-02**: No planning bookkeeping remains in `@moduledoc`/`@doc` ranges that render on HexDocs (starting with `lib/sigra/audit.ex:5`), and `mix docs` is warning-free **as a gate**, with the `skip_undefined_reference_warnings_on` list pruned to what is still needed.
- [x] **SURF-03**: `priv/templates/` carries no planning bookkeeping, landed as one sweep plus **one batched re-bless per batch of template edits** (`mix sigra.fixture.rebless_golden`), in separate commits — amended from "**one** batched" per D-26, because the gap closure lands a second batch of template edits; each run stays single, fixture-scoped, comment-only and alone in its commit. Only the `test/example/` counterparts of edited templates are mirrored.
- [ ] **SURF-04**: A `scripts/ci/prohibitions/p18-*.test.mjs` guard blocks new adopter-visible leakage — hard-fail on `.planning/` paths, all of `priv/templates/`, and HexDocs-rendering doc ranges; a **monotonic-decrease ratchet** on remaining inline `lib/` comments. Zero is explicitly not the v1.48 target. Never added to `mix ci`. **Packaged-docs surface (added by plan 239-10 per D-27):** `mix.exs`'s Hex `files:` list (`mix.exs:184` — `~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)`) packages `docs/`, `README.md` and `CHANGELOG.md`, so those files sit inside the artifact an adopter downloads; the SURF-04 ratchet covers that packaged-docs surface alongside the inline `lib/` comment ratchet it already covers. Measured at Phase 239's close: **58** `.planning/` occurrences across 32 lines in 6 files. Routed here by Phase 239's SC-2 amendment — see `.planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md`.

### Clean git working state (REPO)

- [x] **REPO-01**: `git status` is clean on a fresh checkout — `.gsd/` and GSD scratch files are gitignored, and the stray `sigra-*.tar` tarballs and tracked `.log`/screenshot artifacts are resolved.
- [x] **REPO-02**: The `doc/llms.txt` tracked-while-ignored conflict is resolved by a `!doc/llms.txt` **negation**, not deletion — its three live consumers (`phase_148_*`, `phase_149_*`, `scripts/ci/launch-pack-contract.sh`) keep passing under `mix ci`.
- [x] **REPO-03**: All 6 stashes are materialized as pushed refs and the 5 stale worktrees removed **before** any branch deletion. No `git gc` runs anywhere in this milestone.
- [ ] **REPO-04**: Stale local and remote branches are pruned, with every pre-prune SHA still `git cat-file -e`-resolvable, the documented safety refs kept (`ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-*`), and no open PR's head or base branch deleted.

### Drain the queue (QUEUE)

- [ ] **QUEUE-01**: Dependabot PRs are merged in tiers on a proven-green gate, with the **locked** versions in `mix.lock` / `package-lock.json` verified against PR titles — branch names are stale and lie (`hammer-7.4.1` is really →7.5.0; `oban-2.24.0` is really →2.24.1).
- [ ] **QUEUE-02**: `@playwright/test` (#213) is handled **alone and last**; merged only if CI-native baseline drift measures zero across the ~115 committed PNGs, otherwise deferred to a todo with browser revisions recorded pre/post. No recapture lane is opened in this milestone.
- [ ] **QUEUE-03**: The 8 stale phase/recapture PRs are closed with a stated reason each, **before** any branch prune (PR #211/#219's base is a prune candidate).
- [ ] **QUEUE-04**: Every pending todo is triaged to exactly one of keep / close / defer with a reason; the triage commit's diff touches **only** `.planning/todos/`. Zero todos are fixed during triage.

### Retire v1.47's dishonest debt (DEBT)

- [x] **DEBT-01**: TEST-01/02 supersession by the single-owner `mix ci` design is recorded as an ADR, and the orphaned `Sigra.CI.ExUnitTimingFormatter` plus its test are deleted.
- [x] **DEBT-02**: `test/sigra/planning/phase_233_library_economics_contract_test.exs` no longer asserts the regression is correct; its replacement is demonstrated **RED** against a committed known-bad fixture before being accepted.
- [x] **DEBT-03**: `.github/ci-skip-manifest.tsv` no longer cites the nonexistent `scripts/ci/prohibitions/honest-skip-parity.test.mjs` — either the guard is written and enforces manifest ↔ `ci.yml` ↔ `MAINTAINING.md` parity, or the false claim is removed. `MAINTAINING.md:172-178,231` is corrected to describe the actual HEAD shard topology.
- [x] **DEBT-04**: `.github/actions/example-playwright-boot/action.yml` is covered by the action-pinning supply-chain guard (`action_entry/4` currently returns `[]` for local `"./"` actions, making it invisible in both directions).

## Deferred to a Future Milestone

### Generated-auth runtime proof (the intended next milestone)

- **AUTHUI-W3**: Generated auth has browser coverage on exactly one surface (login, `--no-passkeys`); 13 other surfaces rest on source-string assertions.
- **AUTHUI-W4**: No axe run touches any `sigra-auth-*` surface.

### Carried forward

- **FUT-01**: Template ↔ `test/example/` parity guard (the drift is structurally undetectable today).
- **FUT-02**: Dependabot `groups:` policy (a durable-policy change, not a drain).
- **FUT-03**: `example_unit_smoke` is a ruleset-required check absent from `ci-gate.needs`.
- **FUT-04**: `scripts/ci/launch-pack-contract.sh` appears to have no workflow caller — the same dishonest shape DEBT-03 retires.
- **FUT-05**: Reclaiming `latest_stable_version` from the phantom `1.20.0` (would require publishing above it, or a hex.pm admin deletion).

## Out of Scope

| Feature | Reason |
|---------|--------|
| Publishing `1.21.0` to outrank the phantom | Permanently burns the 1.6–1.20 version range for a cosmetic resolution win; pinned install docs already work. Decided 2026-09-15. |
| `mix hex.publish --revert` (the release-tarball revert) | The 1-hour unpublish window closed in 2026-04. Only the *docs* revert is available. |
| History rewriting (BFG / filter-repo) for the 645M `.git` | Would break every commit SHA cited in `CHANGELOG.md`, which is packaged **inside the Hex tarball** — irreversible, for zero adopter value. |
| Pruning `.planning/` out of the repo | It never ships (`mix.exs` `files:` excludes it), and it is the traceability needed to judge which `Phase NN` comments are real rationale. |
| Retry-wrapping the Playwright flake | Would hide a probable real generated-auth race behind green — the v1.45 failure mode restated. |
| Driving all 771 bookkeeping occurrences to zero | Multi-phase project. v1.48's target is *no new pollution and no adopter-visible pollution*, via a ratchet. |
| Opening a PNG baseline-recapture lane | Carries a human visual-review obligation inside a milestone whose thesis is explicitly not UI. |
| Migrating Pages to `actions/deploy-pages` | Would break the deliberate orphan-commit / 7-day-prune retention model. |
| Adding Credo checks, or any `mix ci` topology change | `phase_233_*_contract_test.exs` guards the alias; changing it re-opens the exact v1.47 wound this milestone closes. Credo also cannot see `priv/templates/`. |
| Admin/operator-UI iteration, new auth features | Post-1.0 posture: polish is not the default roadmap. |

## Traceability

Every v1.48 requirement is mapped to exactly one phase. Phase details and success
criteria live in `.planning/ROADMAP.md` under `# v1.48 CLEAN-BASELINE (active)`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| GREEN-01 | Phase 236 | Complete |
| GREEN-02 | Phase 236 | Complete |
| GREEN-03 | Phase 237 | Complete |
| GREEN-04 | Phase 240 | Complete |
| GREEN-05 | Phase 240 | Complete |
| REL-01 | Phase 238 | Complete (superseded — see the REL-01 note) |
| REL-02 | Phase 238 | Complete |
| REL-03 | Phase 242 | Pending |
| REL-04 | Phase 242 | Pending |
| REL-05 | Phase 242 | Pending |
| REL-06 | Phase 242 | Pending |
| SURF-01 | Phase 239 | Complete |
| SURF-02 | Phase 237 | Complete |
| SURF-03 | Phase 239 | Complete |
| SURF-04 | Phase 241 | Pending |
| REPO-01 | Phase 237 | Complete |
| REPO-02 | Phase 237 | Complete |
| REPO-03 | Phase 237 | Complete |
| REPO-04 | Phase 245 | Pending |
| QUEUE-01 | Phase 243 | Pending |
| QUEUE-02 | Phase 244 | Pending |
| QUEUE-03 | Phase 243 | Pending |
| QUEUE-04 | Phase 243 | Pending |
| DEBT-01 | Phase 241 | Complete |
| DEBT-02 | Phase 241 | Complete |
| DEBT-03 | Phase 241 | Complete |
| DEBT-04 | Phase 241 | Complete |

**Coverage:**

- v1.48 requirements: 27 total
- Mapped to phases: 27 ✓
- Unmapped: 0
- Duplicated across phases: 0

**Phase roll-up:** 236 (GREEN-01/02) · 237 (GREEN-03, REPO-01/02/03, SURF-02) · 238 (REL-01/02) ·
239 (SURF-01/03) · 240 (GREEN-04/05) · 241 (DEBT-01/02/03/04, SURF-04) · 242 (REL-03/04/05/06) ·
243 (QUEUE-01/03/04) · 244 (QUEUE-02) · 245 (REPO-04)

---
*Requirements defined: 2026-09-15 · Traceability populated at roadmap creation 2026-09-15*
