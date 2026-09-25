# Project Research Summary

**Project:** Sigra — comprehensive authentication library for Elixir/Phoenix (hybrid lib+generator)
**Milestone:** v1.48 CLEAN-BASELINE — housekeeping / release-readiness (NOT a feature milestone)
**Domain:** Repository, release and CI hygiene on a mature, *published*, *public* Hex library
**Researched:** 2026-09-15
**Confidence:** HIGH (every count, version, API field and job name below was measured live against this working tree, the GitHub API, the Hex API, npm, or upstream `hexpm/hex` + `hexpm/hexpm` source at HEAD)

**Source reports:** `STACK.md` · `FEATURES.md` · `ARCHITECTURE.md` · `PITFALLS.md` (all in `.planning/research/`)

---

## Executive Summary

v1.48 is a six-workstream cleanup with one hard sequencing spine and one honesty trap. The spine: the `Generated admin Playwright smoke` flake reds `ci-gate` non-deterministically, `ci-gate` gates release-please's `gate-ci-green`, and `gate-ci-green` gates `publish-hex` — so **every** other deliverable that needs a merge (11 Dependabot PRs, the 1.5.1 release cut, 8 stale-PR closes) is taxed or blocked by one flaky assertion at `tests/admin-generated.spec.ts:428`. This is the verbatim mechanism that silently stranded releases in v1.45. The flake must be root-caused first; everything else either runs in parallel with it or waits behind it.

The honesty trap is that a cleanup milestone's natural output is a tidy diff, and every one of its metrics is a *count* — grep hits at zero, tags deleted, PR list drained. Counts are trivially satisfiable without the underlying property holding. This repo has documented precedents for exactly that failure (v1.47's Phase 233 contract test re-verified green while *blessing* the regression it was supposed to catch; the skip manifest cites a guard file that does not exist; `ci-gate` once counted `skipped` as pass). The roadmapper must require, per phase, at least one acceptance criterion that is an observation of a live external system — the GitHub API, the Hex API, a freshly generated app, a built Hex tarball — not a repo grep.

Three corrections invalidate parts of the PROJECT.md brief and must be carried into the roadmap verbatim. (1) `mix hex.retire` is **not** interactive here — `HEX_API_KEY` is already a repository secret used non-interactively in `.github/workflows/hex-publish.yml:180-187` on the identical `api:write` path; the brief's "Human-gated operator step (inherent)" framing is wrong and the retire can be a `workflow_dispatch` job. (2) Retiring `1.20.0` does **not** fix resolution and does **not** move `latest_stable_version` — verified at `hexpm/hexpm` `lib/hexpm/repository/release.ex:189-213` (no retirement filter) and `hexpm/hex` `lib/hex/registry/server.ex:236-251` + `lib/hex/solver/package_lister.ex` (resolver has no retirement awareness); Hex's own docs say "A retired package is still resolvable and usable." Per the user's settled decision the milestone keeps pinned install docs (`{:sigra, "~> 1.5"}`), records that in an ADR, cuts the pending release as **1.5.1** (not 1.21.0), and re-scopes the "adopter-resolution proof" to **retirement-visibility only**. (3) The measured bookkeeping surface is **604 lines / 771 token occurrences**, not the 171 in the brief — a 3.5–4.5x scope underestimate that will eat the milestone if taken as a zero-target.

---

## Key Findings

Ordered by how much each changes the plan. Each carries its source report and confidence.

| # | Finding | Source | Confidence |
|---|---------|--------|------------|
| **K1** | **The retire is automatable.** `Mix.Tasks.Hex.Retire` -> `Hex.API.Release.retire/5` -> `Hex.Auth.with_api(:write, …)` — the same path `mix hex.publish --yes` already uses under `secrets.HEX_API_KEY` at `hex-publish.yml:180-187`. No TTY, no prompt. `--message` is mandatory, <=140 chars. Reversible via `--unretire`. **PROJECT.md's "inherent human gate" is wrong.** ARCHITECTURE.md's *"Interactive Hex auth — must be a runbook step, never automation"* is also wrong; it is superseded. | STACK (source at HEAD) + orchestrator verification | HIGH |
| **K2** | **The retire buys visibility, not resolution.** Post-retire, `latest_stable_version` stays `1.20.0` and `{:sigra, "~> 1.0"}` still resolves to `1.20.0` — it just prints `RETIRED!` and emits a SARIF finding (`HEX0002 / RetiredPackageInvalid`). Deletion is impossible: the 1-hour window closed 2026-04-28 (`release.ex:155-160`). Hex `Policy` filtering is `hexpm:<org>`-scoped and explicitly rejects the bare `hexpm` repo (`lib/hex/policy.ex:56-63`) — unavailable to a public package. | STACK + FEATURES (both at source HEAD); PITFALLS called it "undocumented/unknown" — **superseded** | HIGH |
| **K3** | **HexDocs currently serves the phantom.** `https://hexdocs.pm/sigra/` -> `https://sigra.hexdocs.pm/` renders **"Sigra v1.20.0 — Documentation"** (title read live by the orchestrator). Every adopter following the package page's Documentation link reads docs generated from a release that was never real. Fix: `mix hex.publish docs --revert 1.20.0`. Hex docs are explicitly **mutable** ("Documentation has no limitations on when it can be updated"), unlike tarballs. **This is the single highest adopter-facing win in the milestone, it is one command, and it is currently not in the PROJECT.md scope.** | FEATURES + orchestrator live verification | HIGH |
| **K4** | **The sweep is 3.5-4.5x the brief.** Measured grep over `Phase NN` / `D-NN` / `NNN-NN` / `.planning/`: **604 matching lines / 771 token occurrences** across `lib/` + `priv/templates/`. FEATURES breaks it down as **470 hits in `lib/` across 43 files** + **134 in `priv/templates/`**. PROJECT.md says 171. Five are dead `.planning/` paths; exactly one of those — `priv/templates/sigra.install/organizations/organizations.ex:59` — **ships into every adopter's generated project** (`mix.exs` `files:` includes `priv`). | all four reports (independently measured; consistent once "lines" vs "occurrences" is normalized) | HIGH |
| **K5** | **`PLAYWRIGHT_RETRIES: 1` at `ci.yml:1460` is dead**, and `playwright.config.ts:59` hardcodes `retries: 0`. The env var has zero other references repo-wide. Consequence: `trace: 'on-first-retry'` **never fires**, so there are **no existing trace artifacts** from the flaky runs. STACK's *"harvest the traces you already have — step one, costs nothing"* is therefore invalid. A red must be manufactured before it can be diagnosed. | ARCHITECTURE (grep-verified); contradicts STACK | HIGH |
| **K6** | **The flake has a named architectural root cause.** `lib/sigra/admin/live/audit_index_live.ex:76-128` renders the audit filter as a plain `<form method="get">` + plain `<a href>` preset links **inside a LiveView**, with zero `phx-change`/`phx-submit`/`push_patch` bindings and no `handle_event/3` (only `handle_params/3` at :25). Two competing navigation models own one URL. A LiveView re-render can replace the uncontrolled `<input name="actor">` between Playwright's `fill()` and `press("Enter")` — exactly the observed `toHaveURL` timeout on run `34996937053`. Same-SHA pass/fail flip-flop confirmed on `1afd37f0` and `158aca14`. **This is a lib-owned defect: it ships to every adopter.** Sibling todo already filed (`2026-07-18-admin-audit-impersonation-filter-not-applying.md`). | ARCHITECTURE (source + GitHub Actions API) | HIGH |
| **K7** | **`doc/llms.txt` must NOT be deleted.** Tracked-while-ignored, but with three live consumers: `test/sigra/planning/phase_148_*_test.exs:21`, `phase_149_*_test.exs:69,103`, and `scripts/ci/launch-pack-contract.sh:18`. The first two run inside `mix test` -> `mix ci` -> `library_tests_shard` -> `ci-gate`. Deleting it reds the aggregate gate. Fix = a `!doc/llms.txt` negation in `.gitignore` with a comment. | ARCHITECTURE + orchestrator verification; FEATURES left it open — **resolved** | HIGH |
| **K8** | **Glob tag deletion is the highest-blast-radius mechanical risk.** `v1.4*` matches both the planning tag `v1.4` and the release tag `v1.4.0`. Deleting a tag that backs a GitHub Release converts the Release into an **untagged draft** that vanishes from the public releases page. `mix.exs` `source_ref: "v#{@version}"` means deleting `v1.5.0` 404s every "View source" link in published HexDocs. Verified mitigating fact: **zero** GitHub Releases exist on any `v1.NN` or `phase-238-*` tag — but this must be re-asserted as a gate, not trusted. | PITFALLS (live `gh release list`) | HIGH |
| **K9** | **Pages is one API call that the default `GITHUB_TOKEN` cannot make.** Live: `{"build_type":"legacy","source":{"branch":"main","path":"/"},"status":"errored"}` — the legacy Jekyll builder renders `main`'s repo root and dies on `guides/introduction/code-walkthrough.md:174` (`Tag '{%' was not properly terminated`). `scripts/ci/ensure-github-pages-legacy-branch.sh:66-72` **already** encodes the correct `PUT` (`legacy` / `gh-pages` / `/`) but gets a **403** and logs-and-continues, so the publisher job reports green while the site stays broken. | STACK (root cause) + ARCHITECTURE (the 403 + the Jekyll crash line) | HIGH |
| **K10** | **Deleting a branch that is a PR's *base* closes the PR.** PR **#211** is based on `gsd/238-generated-auth-runtime-proof-evidence`; PR **#219** uses that same branch as its *head*. Both die in one prune. Prune exclusions must be derived from `gh pr list --json headRefName,baseRefName` in **both** directions. | PITFALLS | HIGH |
| **K11** | **Two guards in the repo are fictional or blind.** `.github/ci-skip-manifest.tsv` (header ~lines 11-19) cites `scripts/ci/prohibitions/honest-skip-parity.test.mjs` — `ls` shows only `_lib.mjs` + `p01`…`p16`; **the file does not exist**. And `phase_234_action_pinning_contract_test.exs` scans only `[release-please.yml, hex-publish.yml]` and its `action_entry/4` returns `[]` for `"./" <> _local_action`, so `.github/actions/example-playwright-boot/action.yml` (4 `uses:`) is invisible to the pin guard in **both** directions. | ARCHITECTURE + PITFALLS | HIGH |
| **K12** | **The queue is 11 Dependabot PRs, not 10.** #183, #213, #215, #216, #220, #225, #226, #227, #228, #229, #230 — of 18 open PRs total. Dependabot **branch names lie**: `dependabot/hex/hammer-7.4.1` is titled ->**7.5.0**; `dependabot/hex/oban-2.24.0` is titled ->**2.24.1**. Read merged versions from `mix.lock` / `package-lock.json`, never from the branch name. | STACK + PITFALLS (FEATURES/ARCHITECTURE prose says "10"; the enumerated list is 11) | HIGH |

---

## Reconciled Contradictions

Every disagreement found across the four reports, resolved. The roadmapper should treat the **Ruling** column as settled and not re-litigate.

| # | Contradiction | Positions | Ruling |
|---|---------------|-----------|--------|
| **C1** | **`hex.publish --revert`** — STACK's "What NOT to Use" forbids it; FEATURES recommends it as the P1 win (D-10 / F3). | STACK: *"`mix hex.publish --revert` / release deletion for 1.20.0 — one-hour window, closed 2026-04-28."* FEATURES: *"`mix hex.publish docs --revert 1.20.0` — docs are explicitly mutable."* | **Not a real contradiction — they name two different subcommands, and both are correct.** `mix hex.publish --revert VERSION` unpublishes the *release tarball* and is indeed time-boxed to the grace window (STACK is right to forbid it). `mix hex.publish docs --revert VERSION` removes only the *documentation* and has **no time limit** (FEATURES is right to recommend it). **Ruling: DO the docs revert; do NOT attempt the release revert.** Write the subcommand in full (`docs --revert`) everywhere in the roadmap so the two are never conflated again. See **OQ1** for the one genuinely open sub-question. |
| **C2** | **Is the retire interactive?** | STACK + orchestrator: non-interactive under `HEX_API_KEY`. ARCHITECTURE: *"Interactive Hex auth — must be a runbook step, never automation."* PITFALLS: needs a web-minted `api:write` key (agrees on mechanism, frames as operator step). PROJECT.md: "inherent human gate". | **STACK + orchestrator win** (source at HEAD + an existing working non-interactive call site in this repo). Plan it as a `workflow_dispatch` job gated by *dispatch intent*, not by a TTY. PITFALLS' real sub-finding survives: a **device-flow** token from `mix hex.user auth` returns `key not authorized` — which is exactly why the `HEX_API_KEY` secret path (already proven in `hex-publish.yml`) is the one to use. |
| **C3** | **Does the retire move `latest_stable_version`?** | STACK + FEATURES: definitively no (source-verified, two independent reads). PITFALLS: *"not documented anywhere — this is the milestone's genuine unknown."* | **STACK + FEATURES win.** PITFALLS reasoned from docs; the other two read `latest_version/2` at HEAD. **But keep PITFALLS' methodology:** assert `latest_stable_version == "1.20.0"` post-retire *explicitly*, as a positive criterion, so the milestone cannot accidentally claim a resolution fix it did not make. |
| **C4** | **Do usable traces already exist for the flake?** | STACK: yes — *"traces for the flaky runs already exist as artifacts; harvest them before adding instrumentation."* ARCHITECTURE: `PLAYWRIGHT_RETRIES` is dead and `retries: 0` is hardcoded. | **ARCHITECTURE wins** (see K5). `trace: 'on-first-retry'` with `retries: 0` produces nothing. **Consequence: WS1's first task is manufacturing a reproducible red** (local `--repeat-each=30`, or a temporary `trace: 'on'` / dispatch-only retry), not artifact archaeology. Delete or wire the dead env var either way — it is itself a dishonest-surface item. |
| **C5** | **Should Playwright 1.62 land during flake diagnosis?** | STACK: take PR #213 as a *diagnostic instrument* (1.62 isolated retries discriminate shared-state flakes). ARCHITECTURE + PITFALLS: the bump goes **last and alone**; merging it mid-WS1 destroys the before/after signal and risks ~115 PNG baselines via a bundled-Chromium rev change. | **ARCHITECTURE + PITFALLS win.** Isolated retries are a nice-to-have diagnostic; attribution integrity and baseline stability are load-bearing. Diagnose on 1.59.1. #213 is the **last** merge of the milestone, in its own phase, with drift measured. |
| **C6** | **Where does the tag guard live?** | STACK: a GitHub **repository ruleset** (`target: "tag"`, `tag_name_pattern`, RE2) — server-side rejection at push time. ARCHITECTURE: a `fast_checks` step or `on: push: tags` job, and *"the prohibitions harness is repo-content-only and cannot see `refs/tags`."* FEATURES: "a CI guard". | **Both, layered — and the layering matters.** A CI job fires *after* the bad ref already exists on the remote, which is precisely the ADR-003 footgun. **Primary = the ruleset** (`conditions.ref_name.include: ["refs/tags/v*"]`, `bypass_actors: []`). **Secondary = a repo-side contract test asserting the ruleset exists**, following `_lib.mjs`'s `REQUIRED_CONTEXTS` precedent, so silently deleting it in Settings is caught. ARCHITECTURE's negative finding stands: **do not put the guard in `release_ref_guard`** — that job short-circuits on every non-`workflow_dispatch` event (`ci.yml:74-77`), so a guard placed there never runs. |
| **C7** | **Keep the `archive/local-main-pre-235-recovery` tag?** | STACK lists it as an optional delete. PITFALLS + FEATURES: it is a deliberate safety anchor in an already-distinct namespace; *"a tag named `archive/*` is a keep, not a prune."* User decision #3: keep it. | **KEEP.** Settled by the user. The delete-set is exactly the 2-component `v[0-9]+\.[0-9]+` tags + `phase-238-*`. |
| **C8** | **How many 3-component SemVer tags are in the keep-set?** | STACK: **12**. PITFALLS: **13** (`v0.2.1`…`v1.5.0`, enumerated). Both report 12 GitHub Releases. FEATURES/ARCHITECTURE: 12. | **Genuinely unresolved by +/-1 — and it does not matter if the plan is written correctly.** PITFALLS also notes `v0.2.1` has a tag + Release but was never published to Hex, so "tags <-> Hex releases are 1:1" is false here. **Ruling: never hardcode the count.** Derive the keep-set by regex at execution time, assert the surviving set by *exact set comparison* against that derivation, and assert `gh release list` returns the same count before and after with **0** drafts. See **OQ2**. |
| **C9** | **Dependabot PR count: 10 or 11?** | FEATURES + ARCHITECTURE prose: 10. STACK + ARCHITECTURE's own enumerated list + PITFALLS: 11. | **11.** #183, #213, #215, #216, #220, #225, #226, #227, #228, #229, #230. |
| **C10** | **Stale worktrees: 3 or 5?** | PROJECT.md: 3. ARCHITECTURE + PITFALLS (live `git worktree list`): 6 total, 5 stale, all under `/private/tmp/`, one (`sigra-chimeway-opaque-main`) with a null HEAD `00000000`. | **6 total / 5 stale.** Brief is stale. The null-HEAD entry means `git worktree prune` (never `rm -rf` first). |
| **C11** | **Scale of the shipped-surface sweep** | PROJECT.md: 171. FEATURES: 470 (`lib/`) + 134 (`priv/templates/`) = 604. PITFALLS: 604 lines. STACK: 771 occurrences. | **604 matching lines / 771 token occurrences** (consistent: multiple tokens per line). The brief's 171 is superseded. **Biggest scope risk in the milestone — see Scope Risks §1.** |
| **C12** | **Is `credo` in `mix ci`?** | PITFALLS: *"`mix ci` is the declared parity path, so a new credo finding fails the whole gate."* STACK + ARCHITECTURE: the alias is `format / deps.get / deps.unlock / compile / test / ci.install_golden / sigra.dep_off` — **no credo leg**. | **STACK + ARCHITECTURE win** (alias read at `mix.exs:149-157`). `#183`'s risk is limited to dep resolution, not new findings failing the gate. PITFALLS' *policy* still stands and is cheap: if `mix credo --strict` surfaces findings, defer them to a todo — fixing credo findings is scope creep. |

---

## The Six Workstreams — contents, integration points, measured baselines

Post-correction. Every path, job name and count below is verified.

### WS1 — Green main, honestly  *(critical path)*

**Contains:** root-cause the `generated_admin_playwright_smoke` flake; fix the always-red `pages build`; delete/wire the dead `PLAYWRIGHT_RETRIES`; close issue #231; capture consecutive-green evidence.

| Integration point | Detail |
|---|---|
| Flaky job | `generated_admin_playwright_smoke` — `ci.yml:1401-1533`, runs on **every** event, one of 9 lanes `ci-gate` (`ci.yml:1535-1638`) requires |
| Failing spec | `test/example/priv/playwright/tests/admin-generated.spec.ts:428-461` — `expect(page).toHaveURL(/actor=…/)` times out at 15000 ms |
| Suspected defect | `lib/sigra/admin/live/audit_index_live.ex:76-128` — **lib-owned, ships to adopters** (K6) |
| Dead knob | `ci.yml:1460` `PLAYWRIGHT_RETRIES: 1` (zero other references); `playwright.config.ts:59` `retries: 0` |
| Boot harness | `scripts/ci/admin-acceptance-smoke.sh:256` — `MIX_ENV=dev`, `PHX_SERVER=true`, port 4017; dev boot => code reloader + longpoll fallback + `fs_inotify_bootstrap_error` (secondary nondeterminism) |
| Pages | repo **setting**, not a workflow: `gh api repos/szTheory/sigra/pages` -> `legacy` / `main` / `/` / `errored`; `scripts/ci/ensure-github-pages-legacy-branch.sh:66-72` already tries the correct `PUT` and 403s with the default token |
| Pages backstop | **NEW** `.nojekyll` at repo root — makes the legacy builder green even if the source stays on `main` |
| Todos closed here | `2026-07-30-admin-generated-audit-presets-actor-filter-race.md`, `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` |

**Baselines:** same-SHA flip-flop on `1afd37f0` (success 09-13 push, success 09-14 schedule, failure 09-15 schedule) and `158aca14` (alternates across 4 scheduled runs). Exactly **1 of 9** tests fails; all bash HTTP probes pass. Reference red: run `34996937053`.

**Coupling hazard:** `/admin/audit` has committed PNGs in **both** snapshot lanes (`board-audit-row-*.png`, `board-cfg-audit-*.png`, `admin-checkpoints.spec.ts` "Checkpoint 8"). Drift trips `scripts/ci/snapshot-canary-guard.sh` in `fast_checks` and requires **CI-native ubuntu** recapture (never darwin). **Prefer a behaviour-preserving fix** (add `phx-submit`/`push_patch` URL ownership without changing rendered classes/layout), or budget a recapture sub-plan.

### WS2 — Unambiguous release namespace + cut the release

**Contains (post-correction):** delete 28 `v1.NN` + 11 `phase-238-*` tags; add the tag ruleset + contract test; retire Hex `1.20.0` **non-interactively**; **revert `1.20.0`'s docs** (newly added — K3/C1); write the pinned-install-docs ADR; merge PR #224 as **1.5.1**.

| Integration point | Detail |
|---|---|
| Tag census | 28 two-component locally (**21 on `origin`** — ~7 local-only), 11 `phase-238-generated-auth-proof-*`, 12-13 three-component keep (C8), 1 `archive/*` keep |
| Reachability | **30 tags point at commits not reachable from `origin/main`** — including the real release tag **`v0.2.5`** and `archive/local-main-pre-235-recovery` |
| Guard home | GitHub ruleset `POST /repos/szTheory/sigra/rulesets`, `target: "tag"`, `tag_name_pattern` + `operator: "regex"` (RE2), `^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$`, `bypass_actors: []`. Precedent: live ruleset `14941512` (`target: "branch"`) |
| Guard NOT here | `release_ref_guard` (`ci.yml:62-105`) — short-circuits on non-`workflow_dispatch` |
| Hex retire | `mix hex.retire sigra 1.20.0 invalid --message "…"` (<=140 chars, mandatory) under `secrets.HEX_API_KEY`; mirror `hex-publish.yml`'s existing "Verify version on Hex.pm" polling step for the post-condition |
| Docs revert | `mix hex.publish docs --revert 1.20.0` — same secret, same job |
| Release | PR **#224** `chore(main): release 1.5.1`, head `release-please--branches--main`. Live check: every non-`SUCCESS` check on it is a legitimate tier-A `SKIPPED` lane. Content-ready |
| Post-publish | reuse `scripts/ci/release-post-publish-verify.sh` (already wired into both publish paths) |
| Safe by construction | `publish-hex` and `hex-publish.yml` resolve only `vX.Y.Z` refs — none of which are being deleted |

**Baselines (live, 2026-09-15):** `latest_version: "1.20.0"`, `latest_stable_version: "1.20.0"`, `retirements: {}`, 13 published releases. 12 GitHub Releases, **0 drafts**, all on 3-component tags. `hexdocs.pm/sigra` renders **v1.20.0**.

**The blocking mechanic, precisely:** merge #224 -> release-please tags `v1.5.1` -> `gate-ci-green` polls `ci-gate` on that SHA (`wait-for-ci-gate.sh --max-attempts 120`, 75-min ceiling) -> one flaky lane => exit 1 => `publish-hex` never runs => `notify-release-failure` files a `release-lane-rot` issue. **WS1's fix must be on `main` and observed green before #224 merges.**

### WS3 — Clean shipped surface

**Contains:** strip planning bookkeeping from `lib/` and `priv/templates/sigra.install/`; one batched golden re-bless; `mix docs` warning-free; prune the `skip_undefined_reference_warnings_on` list.

**Baselines:** 604 lines / 771 occurrences. `lib/` heaviest: `lib/sigra/auth.ex` (43), `lib/sigra/install/features/organizations.ex` (32), `lib/sigra/organizations.ex` (26), `lib/sigra/config.ex` (20), `lib/sigra/admin/components.ex` (18). `priv/templates/` heaviest: `organizations/live/organization_members_live.ex` (15), `organizations/migration.exs` (12), `organizations/organizations.ex` (10), `core/auth_fixtures.ex` (9). Five dead `.planning/` paths: `lib/mix/tasks/sigra.fixture.rebless_golden.ex:11,13`, `lib/sigra/audit.ex:5` (line 5 of a `@moduledoc` — renders on HexDocs), `lib/sigra/testing.ex:1274`, and **`priv/templates/sigra.install/organizations/organizations.ex:59`** (ships).

**The coupling chain:** `priv/templates/sigra.install/<file>` -> rendered by `mix sigra.install` -> `test/fixtures/install_golden/tree/<file>` (**85 files; 33 carry 117 bookkeeping hits**) -> asserted byte-for-byte by `test/sigra/install/golden_diff_test.exs` (`timeout: 300_000`, scaffolds a real app per test) -> run by `mix ci.install_golden` (`mix.exs:161`) **and** job `install_golden_contract` (`ci.yml:420`, path regex matches `^priv/templates/sigra\.install/`) -> re-blessed by `MIX_ENV=test mix sigra.fixture.rebless_golden` (`--check` exits 2 on drift).

**Two non-obvious extra consumers:** (1) `test/example/` is a hand-maintained mirror with **no parity gate** — 60 files carry the same markers and nothing fails when they diverge (todo `2026-07-28-w2-example-sigra-auth-css-stale-no-parity-gate.md`). (2) `lib/mix/tasks/sigra.fixture.rebless_golden.ex` is *itself* one of the dirty files, and `test/sigra/install/golden_diff_test.exs:29` cites a dead `.planning/` runbook.

**Hard negative scope (Pitfall 11):** `.github/`, `scripts/`, `MAINTAINING.md` and `test/` bookkeeping tokens are **out of scope** — they are load-bearing. `ci.yml:567` reads `name: Library tests  # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)`; five ruleset-required contexts exist; `honest-skip-verdict.test.sh:420-437` and several `phase_2NN_*_test.exs` grep exact strings in those files. Renaming a required context does not error — the check simply **never reports**, and PRs hang forever. Assert per WS3 phase: `git diff origin/main -- .github/ | grep -E '^\+.*name:'` is empty.

**Also in WS3:** `mix.exs` has a 9-entry `skip_undefined_reference_warnings_on` list; prune each entry by removing-and-retesting so every survivor is provably load-bearing.

### WS4 — Clean git working state

**Baselines:** 19 local / 31 remote branches; **6** stashes (`stash@{0}` literally labelled `safety: pre-release workspace snapshot 2026-08-31`); **6** worktrees (5 stale, all `/private/tmp/`, one null-HEAD); `git check-ignore .gsd/` returns nothing (unignored, untracked), same for `.planning/.gsd-ws-arg`; `doc/llms.txt` tracked-while-ignored (**KEEP** — K7); `sigra-0.1.0.tar` / `sigra-0.2.0.tar` untracked at root, already covered by `.gitignore:23`.

**Hard keep-list, asserted before any prune:** `archive/local-main-pre-235-recovery`; `ci/phase-235-16-source-complete` (**442 commits ahead of main**, holds the TEST-01/02 re-wiring that WS6's supersession is *about*); `safety/local-main-before-release-cleanup-20260831` (16 ahead / 29 behind); and every branch that is the **head or base** of an open PR (K10).

**Per user decision #4:** `.planning/` stays tracked; no history rewriting; the 645 MB `.git` is deliberately untouched. Both FEATURES and PITFALLS independently validated these exclusions as correct.

### WS5 — Drain the queue

**Baselines:** 11 Dependabot PRs (C9/K12); 18 open PRs total; 8 stale phase/recapture PRs (#211, #172, #124, #174, #219, #234, …); **41** pending todos, of which **12 are direct v1.48 inputs** that should be closed *by* their owning workstream rather than triaged separately.

**Blast-radius tiering (merge in tiers, never as a batch):**

| Tier | PRs | Perturbs |
|---|---|---|
| **A** — merge freely, one batch | #215 `actions/attest-build-provenance` 4.1.1->4.2.2, #227 `@anthropic-ai/sdk` 0.110->0.123, #228 `zod` 4.4.3->4.5.4, #220 `otplib` 12->13.5.0 | Playwright-dir npm / workflow pins only; no baseline or library-gate exposure. #215 must keep its same-line `# vX.Y.Z` comment or `phase_234_action_pinning_contract_test.exs` fails |
| **B** — individually, watch one full CI | #225 `oban` 2.23->2.24.1, #229 `hammer` 7.4.0->7.5.0, #230 `flop_phoenix` 0.26.0->0.26.3, #226 `threadline` 0.7->0.9, #183 `credo` 1.7.18->1.7.19, #216 `@axe-core/playwright` 4.11.2->4.13.0 | `mix.lock` -> `library_tests_shard` / `install_smoke` / `upgrade_smoke`. `#226` touches `library_tests_dep_off` (a required `ci-gate` lane) + `lib/sigra/audit/forwarders/threadline.ex` — and `mix.exs` carries a `hackney ~> 4.7` override comment tied to Threadline's published constraint; **dropping that override is itself a CLEAN-BASELINE win, verify against 0.9.0**. `#230` is a UI dep for admin tables (can move markup => PNGs). `#216` can add new axe rules => new reds (`p02-axe-signal-not-reduced.test.mjs` guards the assertions) |
| **C** — its own phase, **last and alone** | #213 `@playwright/test` 1.59.1 -> 1.62.1 | Every Playwright consumer: `example_playwright_shard`, `example_playwright_smoke`, `generated_admin_playwright_smoke`, both recapture jobs, `playwright-github-pages.yml`. **~115 committed PNG baselines** exposed to a bundled-Chromium rasterization change. Re-check the `fast_checks` "Playwright cache key guard" |

**Repo facts that make the drain cheap:** `allow_auto_merge: true`, `allow_squash_merge: true`, `allow_merge_commit: false`, `allow_rebase_merge: false`. `gh pr merge <n> --auto --squash` needs no new tooling. **Precondition: `ci-gate` must be trustworthy first** — auto-merge on an intermittently-red gate either blocks forever or merges on a lane that miscounted.

### WS6 — Retire v1.47's dishonest debt

| Item | Path | Verified state |
|---|---|---|
| Orphaned formatter | `test/support/ci/ex_unit_timing_formatter.ex` (+ its `_test.exs`) | `ExUnitTimingFormatter` / `SIGRA_EXUNIT_TIMING_PATH` have **zero** references in `.github/`, `scripts/`, `mix.exs`. Confirmed dead. The test lives under `test/support/` but matches `test/**/*_test.exs`, so `mix test` runs it |
| Blessing contract test | `test/sigra/planning/phase_233_library_economics_contract_test.exs` | Currently *requires* the replacement topology (`length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1`, `refute body =~ "mix test"`). It also reads `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEDIATION.json` — that dependency must be kept or retired deliberately |
| Fictional guard | `.github/ci-skip-manifest.tsv` header ~11-19 | Cites `honest-skip-parity.test.mjs`; only `_lib.mjs` + `p01`…`p16` exist |
| Rotted prose | `MAINTAINING.md:141-199` (esp. `:172-178`, `:231`) | Describes `design_gallery_snapshots` in a job it no longer lives in; cites a step `Aggregate Playwright step outcomes` that Phase 232 deleted (**0 grep hits at HEAD**) |
| Blind pin guard | `.github/actions/example-playwright-boot/action.yml` (4 `uses:`) | Invisible to `phase_234_action_pinning_contract_test.exs` in both directions (K11) |
| Adjacent known gap | `example_unit_smoke` is a ruleset-required check but **absent from `ci-gate.needs`** | `honest-skip-verdict.sh` prints this as an advisory NOTE on every run. **Out of a strict six-WS reading — recommend deferring to a todo (Scope Risks §5)** |

**House idiom, mandatory for anything NEW here** (observed across p01-p16 and the `*.test.sh` self-tests): every guard is (a) a standalone script with a hermetic self-test, (b) proven to fail **first** against a known-bad fixture under `test/fixtures/prohibitions/`, and (c) paired with an ExUnit contract test under `test/sigra/planning/`. New guards drop into `scripts/ci/prohibitions/` and are picked up by the existing glob at `ci.yml:393` with **zero workflow edits**. **A guard that has never been observed red does not count.**

---

## Reconciled Build Order

STACK, ARCHITECTURE and PITFALLS each proposed an ordering. They agree on five constraints — flake first, guard before deletion, strip before gate, drain before prune, Playwright bump last and alone — and differ only in granularity. This is the single reconciled ordering, with the dependency that *forces* each step.

```
  -- LANE 0 · start immediately, zero coupling, no shared files ---------------
   A. WS4a  free hygiene:  .gitignore `.gsd/` + `.planning/.gsd-ws-arg`,
            `!doc/llms.txt` negation, stray tarballs, `git worktree prune`,
            materialize all 6 stashes as pushed refs      [no branch prune yet]
   B. WS1b  Pages:  operator `gh api PUT` (legacy/gh-pages/) + root `.nojekyll`
            + make ensure-script fail loudly instead of log-and-continue
   C. WS3a  `lib/` sweep + `mix docs` zero-warning gate + suppression-list prune
   D. WS6a  TEST-01/02 supersession ADR + delete formatter + replacement guard
   E. WS6c  composite action brought inside the action-pinning guard

  -- SPINE · strictly sequential ---------------------------------------------
   1. WS1a  FLAKE ROOT CAUSE          forced by: ci-gate -> gate-ci-green -> publish-hex
            manufacture a RED first (K5: no traces exist) -> name the root cause
            -> fix (likely lib/.../audit_index_live.ex) -> mechanized no-retry /
            no-waitForTimeout prohibition -> delete the dead PLAYWRIGHT_RETRIES
   2. WS2a  TAG GUARD, THEN DELETION  forced by: guard-after-delete prevents nothing,
            and the next close flow re-mints. Ruleset -> verify red on a scratch
            `v9.9` -> allowlist-file deletion (local -> verify -> remote)
            MUST precede WS4b (tag reachability checked against the full branch set)
   3. WS1c  GREEN-MAIN EVIDENCE       forced by: the release cut needs a green gate
            n>=20 on the single affected job via workflow_dispatch/matrix repeat,
            NOT 20 full pushes; captured at the final committed HEAD, clean tree
   4. WS3b  TEMPLATES SWEEP + ONE RE-BLESS   forced by: byte-exact golden fixture
            sweep all templates -> ONE `mix sigra.fixture.rebless_golden` ->
            SEPARATE re-bless commit -> `--check` -> fresh-app + tarball greps
   5. WS6b  HONEST-SKIP-PARITY GUARD + MAINTAINING.md repair
            forced by: the guard asserts 3-way parity against ci.yml job ids;
            WS1a edits ci.yml. Writing it earlier pins a moving target
   6. WS2b  RETIRE + DOCS REVERT + CUT   forced by: needs WS1c's evidence
            workflow_dispatch job under HEX_API_KEY: pre-state artifact ->
            `hex.retire ... invalid --message` -> `hex.publish docs --revert 1.20.0`
            -> post-state artifact -> ADR (pinned install docs) -> merge #224 (1.5.1)
   7. WS5a  DRAIN Tier A + Tier B + close 8 stale PRs + triage remaining todos
            forced by: every bump perturbs mix.lock or the Playwright runner —
            i.e. exactly the lanes just stabilized and the inputs to the release
   8. WS5b  TIER C: #213 Playwright, ALONE       forced by: baseline attribution
   9. WS4b  BRANCH PRUNE, LAST        forced by: deleting a PR's base closes it (K10)
```

**Fully parallel from day one:** Lane 0 items A-E. **Parallel with caveats:** WS3a is parallel to WS1a *except* `lib/sigra/admin/live/audit_index_live.ex` — assign that file to **WS1**, WS3 skips it (a one-file merge conflict, not a design conflict). **Never parallel:** steps 1->3->6 (the release spine) and 7->8->9.

**Cross-workstream file collisions and their resolution:**

| File | Claimed by | Resolution |
|---|---|---|
| `lib/sigra/admin/live/audit_index_live.ex` | WS1 (fix) + WS3 (sweep) | WS1 owns it; WS3 skips |
| `.github/workflows/ci.yml` | WS1 (`PLAYWRIGHT_RETRIES`, job edits) + WS2 (optional tag step) + WS6 (parity guard reads it) | WS1 first -> WS2 additive -> WS6 last |
| `.planning/todos/pending/**` | WS5 (triage) + WS1/WS2/WS6 (each closes its own) | Each WS closes its own 12; WS5 triages the remaining ~29 |
| `tests/*-snapshots/*.png` | WS1 (if lib markup changes) + WS5b (#213) | **Never both in one PR** — drift must be attributable to one cause |

---

## Implications for the Roadmap (phases continue from **236**)

### Suggested phase decomposition

| Phase | Name | WS | Rationale (the forcing dependency) | Research flag |
|---|---|---|---|---|
| **236** | Flake root cause — reproduce, name, fix | WS1a | Gates the release *and* taxes every dep merge. Needs a manufactured RED first (K5). Owns `audit_index_live.ex` | **RESEARCH** — the fix may be a real LiveView URL-ownership redesign in shipped `lib/`; PNG-baseline exposure needs a go/no-go |
| **237** | Free hygiene batch — gitignore, worktrees, stashes, tarballs, Pages | WS4a + WS1b | Zero coupling; costs nothing; removes a permanently-red check that trains maintainers to ignore red | Skip — mechanical, though the Pages `PUT` needs an admin credential (**OQ5**) |
| **238** | Tag guard, then tag deletion | WS2a | Guard must precede deletion or it prevents nothing. Must precede branch prune | Skip — STACK gives the exact ruleset JSON; PITFALLS gives the exact gate assertions |
| **239** | `lib/` shipped-surface sweep + `mix docs` gate + suppression prune | WS3a | Parallel-safe; no golden/example coupling; the HexDocs-rendering `.planning/` link in `lib/sigra/audit.ex:5` is a live docs defect | Skip — but enforce `mix docs` zero-warning as a **gate**, not a spot check |
| **240** | `priv/templates/` sweep + ONE batched re-bless | WS3b | Byte-exact golden coupling; must be one sweep + one re-bless, separate commits | **RESEARCH** — the `test/example/` parity decision (**OQ3**) and the descope line (Scope Risks §1) both need deciding before planning |
| **241** | v1.47 debt A: TEST-01/02 supersession ADR + delete + replacement guard | WS6a | Fully independent. An ADR is what makes the replacement assertion legitimate rather than circular | Skip — Pitfall 9 specifies the fail-first protocol exactly |
| **242** | v1.47 debt B: honest-skip-parity guard + `MAINTAINING.md` repair + composite action into pin guard | WS6b + WS6c | Must follow 236's `ci.yml` edits (the guard pins ci.yml job ids) | Skip |
| **243** | Green-main evidence capture | WS1c | The release gate's precondition. n>=20 on the affected job via dispatch, not 20 full pushes | Skip — FAST-01's n=52 bundle is the reusable precedent |
| **244** | Hex retire + docs revert + pinned-install ADR + cut 1.5.1 | WS2b | Needs 243's evidence. Single `workflow_dispatch` job under `HEX_API_KEY` for both Hex mutations | **RESEARCH** — **OQ1** (does the docs revert also move `latest_stable_version`?) should be resolved by measurement inside this phase |
| **245** | Dependabot Tier A + Tier B, close 8 stale PRs | WS5a | After the cut, so the release doesn't ship deps that never ran a full green | Skip |
| **246** | Todo triage — ~29 remaining, keep/close/defer only | WS5a | Highest scope-creep risk in the milestone | Skip — but the diff must touch **only** `.planning/todos/` |
| **247** | Tier C: `@playwright/test` 1.59.1 -> 1.62.1, alone | WS5b | Baseline attribution; ~115 PNGs exposed | **RESEARCH** — drift measurement + recapture-or-defer decision (Scope Risks §2) |
| **248** | Branch prune (local + remote) | WS4b | Last: no open PR's head or base may be a candidate | Skip |

**Genuinely batchable** (do not give these their own phases): the `.gitignore` edits + worktree prune + stash materialization + stray tarballs + Pages `PUT` + `.nojekyll` -> one phase (237). Tier A Dependabot PRs -> one merge batch inside 245. WS6b + WS6c -> one phase (242).

**Deserve their own phase** (do not batch): 236 (open-ended diagnosis, lib-owned fix, PNG exposure); 240 (byte-exact fixture with a one-command "make it green" footgun); 244 (irreversible public-artifact mutation); 247 (~115-baseline blast radius); 248 (destructive, PR-coupled).

### Non-negotiable roadmap-level guardrails

1. **One live-external-observation criterion per phase.** Not a grep. WS1 -> GitHub Actions API run list + a captured red. WS2 -> Hex API pre/post JSON artifacts + `gh release list` count unchanged + `[.[]|select(.draft)]|length == 0`. WS3 -> a **freshly generated app** grepped clean + `mix hex.build` tarball grepped clean + `mix docs` warning-free. WS4 -> every pre-prune SHA still `git cat-file -e`-resolvable + 6 stash archive refs on `origin`. WS5 -> locked versions in `mix.lock`/`package-lock.json` match PR titles (branch names lie — K12). WS6 -> each guard demonstrated **RED** against a committed known-bad fixture.
2. **Ban count-only acceptance.** A workstream whose only criterion is a grep count or `wc -l` is rejected at review.
3. **Capture evidence at the final committed HEAD on a clean tree** — the SC-5 lesson; a bundle rendered at a pre-commit SHA is invalid.
4. **`mix ci`, not root `mix test`, before every push** — root `mix test` misses formatting and `test/example`.
5. **Found-while-cleaning -> a new todo file, never an in-phase fix.** One pre-authorized exception: if 236's root cause is a genuine product race in `lib/`, fixing it is in scope — a real intermittent bug in a shipped auth library outranks the cleanup. Name this exception in the roadmap so it need not be argued mid-execution.
6. **Restate the out-of-scope list verbatim in every phase brief:** W-3/W-4 generated-auth runtime proof, admin/operator-UI iteration, pruning `.planning/`, BFG/filter-repo history slimming, any new feature work.
7. **Prohibition guards belong in `scripts/ci/prohibitions/*.test.mjs`, never in `mix ci`.** `test/sigra/planning/phase_233_library_economics_contract_test.exs` *requires* the current single-owner `mix ci` topology; changing the alias re-opens v1.47's TEST-01/02 wound under the milestone that exists to close it. New `.mjs` guards are picked up by the `ci.yml:393` glob with zero workflow edits. Also: a Credo check cannot see `priv/templates/` (`.credo.exs` `files.included` is `["lib/","test/"]`, and the templates are `.heex`/`.js`/`.css`/`.md`/`.exs`) — so Credo is the wrong instrument for the leakage guard regardless.

---

## Scope Risks — where the research exceeds the approved brief

The user asked for **tight** scope. These are the places the reports propose more work than the brief authorizes, each with a recommended descope line.

1. **The sweep: 604/771 vs the brief's 171.** Driving all 771 occurrences to zero is a multi-phase project, and a blanket hard-fail guard is unshippable as a first move. **Recommended descope:** hard-fail tier = the **5 dead `.planning/` paths** + **everything under `priv/templates/`** + `@moduledoc`/`@doc` ranges in `lib/` that render on HexDocs. Everything else (inline `#` comments in `lib/`) -> a **committed baseline count with a monotonic-decrease ratchet**, following the repo's existing "Quality ledger monotonic guard" / "Quality findings monotonic guard" steps in `fast_checks`, each of which already has its own self-test. Zero is not the v1.48 target; *no new pollution and no adopter-visible pollution* is.
2. **Playwright 1.62 + a possible ~115-baseline recapture phase.** A recapture is a real phase with a human visual-review obligation, inside a milestone whose thesis is *not* UI. **Recommended descope:** phase 247 measures drift CI-native on ubuntu and merges **only if drift == 0**. If drift > 0, **defer #213 to a follow-on todo** rather than opening a recapture lane. Record the browser revisions pre/post either way.
3. **n>=20 consecutive green runs.** Twenty full CI pushes would make the proof the slowest thing in the milestone and risks pushing PR p50 back toward v1.47's pre-optimization 27.3 min (the headline win was 469 s). **Recommended descope:** prove on the **single affected job** via `workflow_dispatch` or a matrix repeat, plus the normal push history. Reuse the FAST-01 n=52 machinery; do not build a new harness.
4. **41-todo triage.** Every todo read invites a 20-minute fix; 41 x "just this one" is a second milestone. **Recommended descope:** triage yields exactly three dispositions — `keep` (with a reason), `close` (with evidence), `defer` (with a named future milestone). **Zero todos are fixed during triage.** Acceptance: the triage commit's diff touches only `.planning/todos/`. And 12 of the 41 are owned by WS1/WS2/WS6 and close as a side effect — triage only the remaining ~29.
5. **Two adjacent gaps outside a strict six-WS reading.** (a) `example_unit_smoke` is a ruleset-required check absent from `ci-gate.needs` — ARCHITECTURE itself flags it as out of scope. (b) `scripts/ci/launch-pack-contract.sh` appears to have **no workflow caller** (MEDIUM confidence) — a guard whose only consumer is a test that reads its own source, the same dishonest shape WS6 is retiring. **Recommended:** file both as todos with the diagnosis attached; do not open phases.
6. **`test/example/` 60-file mirror sweep.** ARCHITECTURE and PITFALLS both want it swept for parity; that is 60 more files with no gate to prove it worked. **Recommended descope:** mirror **only** the counterparts of templates actually edited in 240, per-file checklist, and file the missing template<->example parity guard as a todo for a future milestone. Record the decision explicitly — *nothing will fail if you get it wrong*, which is exactly why it must be written down.
7. **Dependabot `groups:` (FEATURES D-6).** Real 70-80% future-noise reduction, but it is a durable-policy change, not a drain, and it is coupled to `phase_234_dependabot_contract_test.exs`. **Recommended:** follow-on todo (see OQ6).

---

## Critical Pitfalls (top 6)

1. **Glob tag deletion eats release tags and drafts GitHub Releases.** `v1.4*` matches `v1.4` *and* `v1.4.0`. Avoid: an explicit committed allowlist file, never a glob at the `git tag -d` call site; assert zero entries match `^v[0-9]+\.[0-9]+\.[0-9]+$`; assert `comm -12 <(sort delete-list) <(gh release list --json tagName --jq '.[].tagName' | sort)` is **empty**; back up with `git for-each-ref refs/tags > tags-backup.txt` (committed); delete local -> verify -> then remote, never in one command.
2. **The retire is accepted on exit code 0.** Avoid: split **RETIRE-A** (`retirements` contains `1.20.0` with reason `invalid` — guaranteed) from **RETIRE-B** (visibility only, per the user's decision: `latest_stable_version` is *asserted to still be* `1.20.0`; `~> 1.5` resolves to 1.5.x cleanly; `~> 1.0` resolves to 1.20.0 *and prints `RETIRED!`*). Prove with `mix deps.get` in a clean `HEX_HOME=$(mktemp -d)`. **Never set `HEX_IGNORE_RETIREMENTS`** — the warning *is* the proof. **Never paste the Hex write key** into a plan, SUMMARY, evidence file or commit message; this is a public repo.
3. **Retry-wrapping or sleeping the flake.** `retries`, `waitForTimeout`, `test.slow()` — or declaring it fixed from one green run (a 15%-rate flake passes once 85% of the time). Avoid: **no fix lands without a recorded RED**; a named differential diagnosis (harness race / DB collision / product race); and a **mechanized prohibition** (`scripts/ci/prohibitions/`) so "don't retry-wrap" is a failing test rather than a plan sentence. Per the user's settled decision, the only acceptable fallback if root-cause fails is a **dated, owned quarantine entry** in `.github/ci-skip-manifest.tsv` — an explicit risk acceptance with an owner and a date.
4. **The template-edit cascade, re-blessed carelessly.** `mix sigra.fixture.rebless_golden` makes the diff go away regardless of whether the diff was intended. Avoid: the re-bless is a **separate commit**, and the phase asserts the re-bless diff contains **only comment lines** — any non-comment line is a stop-the-line event. Assert the *generated app* and the *built tarball*, not the templates.
5. **Producing a second dishonest guard in WS6.** A rewritten contract test that merely restates HEAD is a screenshot, not a guard. Avoid: **fail-first is mandatory** — every guard written or rewritten needs a committed known-bad fixture under `test/fixtures/prohibitions/` and a *demonstrated red*; a supersession is an **ADR (004)**, and the test then asserts the *replacement guarantee*, which the ADR is what makes non-circular. For the skip manifest: **write the guard, don't delete the claim** — it should initially fail against HEAD's `MAINTAINING.md`, and fixing `MAINTAINING.md:172-178,231` is the same phase.
6. **Compound reachability loss.** Tags + branches + worktrees + stashes pruned in one milestone: individually safe because something else holds the commits; together, not. Avoid: sequence **tags -> branches -> worktrees -> stashes**, never in parallel; **materialize all 6 stashes as pushed refs before any branch deletion**; `git worktree prune`, never `rm -rf` first (one entry has a null HEAD); and **no `git gc`, `git reflog expire`, or `--prune=now` anywhere in the milestone**. Also **preserve the `# SECURITY:` rule** — WS3 removes the *bookkeeping token*, keeps the *sentence*; assert no WS3 diff deletes a comment block containing `security|CSRF|enumeration|timing|scope|impersonation`.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Nothing is installed; every item is config, `gh`, `git`, or an existing dep. `mix.exs` `deps/0` is untouched. Versions verified live on npm/hex.pm; Hex mechanics verified against `hexpm/hex` + `hexpm/hexpm` at HEAD. Two internal errors found and corrected (C4 traces, C5 bump timing) |
| Features | **HIGH** | Maintenance properties benchmarked against six real Elixir libraries (Ecto, Phoenix, Oban, Req, Bandit, Absinthe) via the GitHub tags API. Hex behavior read from upstream source. The one novel, high-value find (K3 docs-revert) was independently re-verified live by the orchestrator |
| Architecture | **HIGH** | Every integration point read from `main` @ `17764671` or the live GitHub API. Two items self-flagged MEDIUM (Dependabot's `/` scan reaching `.github/actions/*/action.yml`; whether `launch-pack-contract.sh` has any caller) |
| Pitfalls | **HIGH** | Repo mechanics measured live; external mechanics (tag->draft-Release conversion, Playwright browser drift) corroborated across >=3 sources. Its one MEDIUM claim (`latest_stable_version` behavior "undocumented") is superseded by STACK/FEATURES' source reads — see C3 |

**Overall confidence: HIGH.** The four reports converge on facts and diverge only on emphasis; all twelve divergences are resolved above, with exactly one (**C8**, tag count +/-1) left open and mitigated by construction.

### Open Questions for the Roadmapper

Each has a recommended default so **nothing blocks**.

| # | Question | Recommended default |
|---|---|---|
| **OQ1** | Does `mix hex.publish docs --revert 1.20.0` *also* move `latest_stable_version`? `latest_version/2` filters on prerelease **and optionally `has_docs`** — if the API's `latest_stable_version` passes `has_docs: true`, reverting 1.20.0's docs would incidentally repair the Hex-generated dep snippet too. STACK read the filter as "optionally has_docs" without resolving which caller path the API field uses. | **Measure, never claim.** In phase 244, capture `GET /api/packages/sigra` as a committed artifact *before* and *after* the docs revert and report whichever it is. Do **not** write a roadmap requirement that depends on the favorable outcome — the stated criterion stays retirement-visibility-only per the user's decision. If it *does* move, that is a bonus finding for the CHANGELOG, not a re-scoping. |
| **OQ2** | Keep-set size: 12 or 13 three-component SemVer tags (C8)? | **Never hardcode the count.** Derive by regex at execution, assert survivors by exact set comparison against that derivation, and gate on `gh release list` count unchanged + 0 drafts. The +/-1 becomes irrelevant. |
| **OQ3** | Does WS3 sweep `test/example/`'s ~60 mirror files? | **No — mirror only the counterparts of templates actually edited**, per-file checklist, and file the missing parity guard as a todo. Record the decision explicitly in the phase SUMMARY; silence here is what caused the existing drift. |
| **OQ4** | Does a `bypass_actors: []` tag ruleset block release-please's own `v1.5.1` tag push? | **It should not** — the regex `^v[0-9]+\.[0-9]+\.[0-9]+(-...)?$` permits it. **Verify empirically in phase 238**, not at the cut: push a scratch `v9.9.9-rulesettest` (must succeed) and `v9.9` (must be rejected), then delete both. That doubles as the guard's required RED proof. |
| **OQ5** | Which credential makes the Pages `PUT`? The default `GITHUB_TOKEN` returns **403** (observed in run `30613728531`). | **The operator runs `gh api repos/szTheory/sigra/pages --method PUT` locally as repo admin**, once. Add the root `.nojekyll` as a zero-auth backstop, and change `ensure-github-pages-legacy-branch.sh` to fail loudly rather than log-and-continue on 403 — the silent continue is why the publisher job reported green while the site stayed broken. Do **not** migrate to `build_type: workflow`: it would break the deliberate orphan-commit retention model in `playwright-github-pages.yml`. |
| **OQ6** | Add Dependabot `groups:` to cut future PR volume? | **Defer to a follow-on todo.** One-file change with outsized payoff, but `phase_234_dependabot_contract_test.exs` pins the config to exactly three ecosystems and must be updated in the same change — and grouped updates report the **highest** semver level in the group, which must never be combined with blanket auto-merge. Out of the tight v1.48 scope. |
| **OQ7** | Does WS6 fix the `example_unit_smoke` / `ci-gate.needs` gap, or file it? | **File it as a todo** with the diagnosis. Honest-gate item, but outside a strict six-workstream reading, and `honest-skip-verdict.sh` already surfaces it as an advisory on every run. |
| **OQ8** | Re-mint the 11 `phase-238-*` proof tags under a `proof/` namespace before deleting (FEATURES D-2)? | **No — delete outright.** Zero GitHub Releases attach to them, and the commits are held by branches on the WS4 keep-list. Instead **amend ADR 003** with the deletion date, the path to the committed delete-list file, and the prescribed `milestone/` + `proof/` namespaces for future non-release tags — so the convention is recorded even though these refs are gone. |

---

## Sources

### Primary — live, verified 2026-09-15 (HIGH)
- `GET https://hex.pm/api/packages/sigra` — `latest_version: "1.20.0"`, `latest_stable_version: "1.20.0"`, `retirements: {}`, 13 published releases, `1.20.0 has_docs: true`
- `https://hexdocs.pm/sigra/` -> `https://sigra.hexdocs.pm/` — renders **"Sigra v1.20.0 — Documentation"**
- `hexpm/hexpm@main` — `lib/hexpm/repository/release.ex:155-160` (1-hour delete window), `:187-225` (`latest_version/2`), `lib/hexpm_web/views/api/package_view.ex:19-32`
- `hexpm/hex@main` — `lib/mix/tasks/hex.retire.ex`, `lib/hex/api/release.ex:41-61`, `lib/hex/remote_converger.ex:556-612`, `lib/hex/registry/server.ex:236-251`, `lib/hex/solver/package_lister.ex`, `lib/hex/policy.ex:56-63`, `lib/hex/sarif.ex:24-34`
- GitHub API — `repos/szTheory/sigra` (merge settings), `/pages` (`legacy`/`main`/`errored`), `/rulesets/14941512`, `gh pr list` (18 open / 11 Dependabot), `gh release list` (12, 0 drafts), Actions run `34996937053` failing log, same-SHA flip-flop on `1afd37f0` + `158aca14`
- Repo at `main` @ `17764671` — `.github/workflows/{ci,release-please,hex-publish,playwright-github-pages}.yml`, `.github/ci-skip-manifest.tsv`, `.github/dependabot.yml`, `.github/actions/example-playwright-boot/action.yml`, `scripts/ci/**`, `scripts/ci/prohibitions/{_lib.mjs,p01..p16}`, `mix.exs`, `.credo.exs`, `.gitignore`, `test/sigra/install/golden_diff_test.exs`, `test/sigra/planning/phase_{148,149,233,234}_*`, `test/example/priv/playwright/{package.json,package-lock.json,playwright.config.ts,tests/admin-generated.spec.ts}`, `lib/sigra/admin/live/audit_index_live.ex`, `git tag`/`worktree`/`stash`/`ls-remote` census
- `registry.npmjs.org/@playwright/test` — latest **1.63.0** (2026-09-04); currently locked **1.59.1**; PR #213 proposes **1.62.1**
- `mix hex.info` locally — Hex 2.5.1 / Elixir 1.19.5 / OTP 28.5

### Secondary — official documentation (HIGH)
- [`mix hex.retire`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Retire.html) — five reasons, mandatory `--message` <=140 chars, `--unretire`, and the definitive line: *"A retired package is still resolvable and usable but it will be flagged as retired… a message will be displayed to users."*
- [`mix hex.publish`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html) — `docs --revert VERSION`; docs are mutable, tarballs are not
- [Hex.pm FAQ](https://hex.pm/docs/faq) · [Dependency policies](https://hex.pm/docs/dependency-policies) · [Publishing](https://hex.pm/docs/publish)
- [GitHub Pages REST API](https://docs.github.com/en/rest/pages/pages) · [Repository rules REST API](https://docs.github.com/en/rest/repos/rules) (RE2, `target: tag`) · [Dependabot PR optimization](https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/optimizing-pr-creation-version-updates)
- [Playwright release notes](https://playwright.dev/docs/release-notes) — 1.44 `--last-failed`; 1.49 `--fail-on-flaky-tests`; 1.61 WebAuthn passkeys; 1.62 isolated retries + `Reporter.preprocess()` + perfetto; 1.63 test locks + aria snapshots in traces
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html)
- Comparator scan via `gh api repos/*/tags` — ecto, phoenix, oban, req, bandit, absinthe: **zero** non-release tags in any of them

### Tertiary — practice literature / corroborated community (MEDIUM)
- GitHub tag->draft-Release conversion: [community discussion #7008](https://github.com/orgs/community/discussions/7008), [hub#2435](https://github.com/mislav/hub/issues/2435), [scivision](https://www.scivision.dev/github-delete-release-tag/) — corroborated across three sources
- Flake quarantine practice ([minware](https://www.minware.com/guide/best-practices/flaky-test-quarantine), [QASkills.sh](https://qaskills.sh/blog/ci-flaky-test-auto-quarantine-workflow)) — informs the user's settled fallback: a **dated, owned quarantine entry** is an acceptable close if root-cause fails; retry-wrapping is rejected
- Dependabot grouping/cooldown write-ups, incl. the grouped-update "highest semver level wins" caveat
- `dependabot/fetch-metadata` **v3.1.0** (2026-04-20) — most public examples still show v2; must be SHA-pinned per `phase_234_action_pinning_contract_test.exs` if ever adopted

### Local planning artifacts (HIGH)
- `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`
- `.planning/todos/pending/` (41) — esp. `2026-07-30-admin-generated-audit-presets-actor-filter-race.md`, `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`, `2026-07-03-hex-retire-stray-1-20-0.md`, `2026-09-15-honest-skip-parity-guard-does-not-exist.md`, `2026-09-15-test-01-02-timing-machinery-orphaned.md`, `2026-09-15-composite-action-outside-supply-chain-guards.md`, `2026-07-28-w2-example-sigra-auth-css-stale-no-parity-gate.md`
- `.planning/PROJECT.md` — `## Current Milestone: v1.48 CLEAN-BASELINE` + `## Current State`; `CHANGELOG.md`; `MAINTAINING.md`

---
*Research completed: 2026-09-15*
*Ready for roadmap: yes — phases continue from 236*
