# Architecture Research — v1.48 CLEAN-BASELINE Integration Map

**Domain:** Housekeeping / release-readiness on a mature shipped Elixir library (hybrid lib+generator, Phoenix 1.8+)
**Researched:** 2026-09-15
**Confidence:** HIGH (every integration point below was read from the repo at `main` @ `17764671`, or read live from the GitHub API; the two items marked MEDIUM are called out inline)

> Scope note: this is **not** an ecosystem/greenfield architecture study. The auth subsystems are settled and deliberately not re-researched. This document answers: *how do the six v1.48 cleanup workstreams attach to the existing CI / release / generator architecture, what is new vs modified, and in what order must they land?*

---

## Standard Architecture (the parts v1.48 touches)

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  TAG / RELEASE NAMESPACE                                                     │
│   28 non-SemVer v1.NN tags  +  11 phase-238-* tags  +  12 real vX.Y.Z tags   │
│   (one flat refs/tags namespace — ADR-003 footgun)                           │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ consumed by
┌───────────────▼──────────────────────────────────────────────────────────────┐
│  RELEASE LANE  (.github/workflows/release-please.yml)                         │
│   release-please ──► gate-ci-green ──► publish-hex ──► notify-release-failure │
│                         │  polls ci-gate on the release SHA                   │
│   manual recovery: .github/workflows/hex-publish.yml (workflow_dispatch)      │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ hard dependency
┌───────────────▼──────────────────────────────────────────────────────────────┐
│  CI AGGREGATE  (.github/workflows/ci.yml — 2194 lines, 20 jobs)               │
│   release_ref_guard ─► changes ─► { 9 required lanes } ─► ci-gate ─► rot      │
│   required lanes: install_golden_contract, library_tests(+_shard),            │
│     library_tests_dep_off, install_smoke, upgrade_smoke, example_http_smoke,  │
│     example_playwright_smoke, generated_admin_playwright_smoke, fast_checks   │
│   honesty layer: .github/ci-skip-manifest.tsv + scripts/ci/honest-skip-       │
│     verdict.sh + scripts/ci/prohibitions/p01..p16.test.mjs (in fast_checks)   │
└───────┬──────────────────────────────────┬───────────────────────────────────┘
        │                                  │
┌───────▼───────────────────────┐  ┌───────▼───────────────────────────────────┐
│ GENERATOR TRUTH CHAIN         │  │ RUNTIME PROOF CHAIN                        │
│  priv/templates/sigra.install/│  │  scripts/ci/admin-acceptance-smoke.sh      │
│        │ rendered by installer│  │     phx.new 1.8.8 ─► mix sigra.install     │
│        ▼                      │  │     ─► seed ─► boot MIX_ENV=dev :4017      │
│  test/fixtures/install_golden/│  │     ─► bash HTTP probes                    │
│   (85 files, byte-asserted)   │  │     ─► npx playwright admin-generated.spec │
│        ▲ re-blessed by        │  │           (project `admin-generated`)      │
│  mix sigra.fixture.rebless_   │  │  lib/sigra/admin/live/*.ex  (lib-owned UI) │
│      golden [--check]         │  │        ▲ PNG baselines: admin-design       │
│  test/example/ (hand-kept     │  │          + admin-checkpoints (CI-native    │
│      mirror, NO parity gate)  │  │          recapture jobs)                   │
└───────────────────────────────┘  └────────────────────────────────────────────┘
```

### Component Responsibilities (v1.48-relevant only)

| Component | Exact path / job name | Owns | v1.48 relevance |
|---|---|---|---|
| Aggregate gate | job `ci-gate` (`ci.yml:1535`) | Fails if any of 9 required lanes is neither `success` nor `skipped` | The single choke point between a flake and a stranded release |
| Flaky lane | job `generated_admin_playwright_smoke` (`ci.yml:1401`) | Generated-host parity: scaffolds a fresh app and runs `tests/admin-generated.spec.ts` | WS1 root cause |
| Release gate | job `gate-ci-green` (`release-please.yml`) → `scripts/ci/wait-for-ci-gate.sh --max-attempts 120` | Polls `ci-gate` on the release SHA for up to 60 min | Converts a WS1 flake into a failed release |
| Tag ref guard | job `Release ref guard` / id `release_ref_guard` (`ci.yml:62`) | **Only** validates that a `workflow_dispatch` release-evidence run was dispatched from `refs/tags/v*` | WS2's natural home is *adjacent to*, not inside, this job — see WS2 |
| Golden fixture | `test/fixtures/install_golden/` (85 files) asserted by `test/sigra/install/golden_diff_test.exs` | Byte-for-byte installer output | WS3's hard coupling |
| Re-bless | `lib/mix/tasks/sigra.fixture.rebless_golden.ex` (`MIX_ENV=test mix sigra.fixture.rebless_golden`, `--check` in CI) | Regenerates fixture + prints delta | WS3's batching mechanism |
| Honesty data | `.github/ci-skip-manifest.tsv` | Enumerates legitimate skips; consumed by `honest-skip-verdict.sh` and `ci-demotion-observer.sh` | WS6: header cites a guard that does not exist |
| Guard harness | `scripts/ci/prohibitions/*.test.mjs` (p01–p16), run by `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` at `ci.yml:393` inside `fast_checks` | Machine-checkable prohibitions with fail-first fixtures | Where a **new** tag-namespace guard and a **new** honest-skip-parity guard belong |
| Contributor parity | `mix ci` alias (`mix.exs:149-157`), run once as `MIX_ENV=test mix ci` in `library_tests_shard` | Sole full-suite owner | WS5 dependency bumps land here first |

---

## Workstream Integration Maps

### WS1 — Green main, honestly

**Root cause (verified live, not inferred).**

Same-SHA flip-flop proves flake, not regression: SHA `1afd37f0` = `success` (push 09-13, schedule 09-14) and `failure` (schedule 09-15). SHA `158aca14` alternates across four scheduled runs.

Run `34996937053` (push, `4a4e6c38`) failed with:

```
✘ 7 [admin-generated] › tests/admin-generated.spec.ts:428:5 ›
  generated audit presets expose one effective filter value and visible applied state (17.1s)
  expect(page).toHaveURL failed
  Expected: /(?:\?|&)actor=00000000-0000-0000-0000-000000000001(?:&|$)/
  Received: "http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure"
  19 × unexpected value  (Timeout 15000ms)
```

Exactly one test out of nine fails; the other eight and all bash HTTP probes pass. There is an already-filed diagnosis: `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` (observed independently on run `30509363963`). **Note the todo describes the assertion as `click("Apply filters")`; the spec at HEAD uses `actorFilter.press("Enter")` — so the interaction was already changed once and the race survived it.** That is evidence the defect is on the page, not in the click strategy.

Architectural seam (read from `lib/sigra/admin/live/audit_index_live.ex`): the audit filter UI is a **plain `<form method="get" action={index_path(...)}>` with plain `<a href>` preset links, rendered inside a LiveView**. There are no `phx-change` / `phx-submit` / `push_patch` bindings on the filter form at all (`grep` for `handle_event` in that file returns nothing — only `handle_params/3` at line 25). So filter state lives in two competing navigation models on one page: browser-native full GET navigations vs LiveView's `handle_params` + DOM patch. A LiveView re-render can replace the uncontrolled `<input name="actor">` (whose `value` is server-rendered from `@current_params`) between Playwright's `fill()` and its `press("Enter")`, discarding the typed value and leaving the URL pinned to the prior preset — precisely the observed symptom.

| Item | Path / job | New or Modified | Notes |
|---|---|---|---|
| Flaky spec | `test/example/priv/playwright/tests/admin-generated.spec.ts:428-461` | MODIFIED | The test itself may need a deterministic wait on applied-state, not a URL poll |
| Underlying page | `lib/sigra/admin/live/audit_index_live.ex:76-128` | MODIFIED (if fixed properly) | **lib-owned ⇒ ships to every adopter**; sibling defect `2026-07-18-admin-audit-impersonation-filter-not-applying.md` is the same URL-truth mechanism |
| Dead retry knob | `ci.yml:1460` `PLAYWRIGHT_RETRIES: 1` | MODIFIED (delete or wire) | **`PLAYWRIGHT_RETRIES` is referenced nowhere else in the repo**; `playwright.config.ts:59` hardcodes `retries: 0`. The job advertises a retry it does not have — a dishonest-surface item in its own right, and it is why a single flaky assertion reds the whole gate |
| Dev-mode boot | `scripts/ci/admin-acceptance-smoke.sh:256` (`MIX_ENV=dev`, `PHX_SERVER=true`, port 4017) | MODIFIED (optional) | Dev boot ⇒ code reloader + longpoll fallback (config comment at `playwright.config.ts:60-67`); logs show `fs_inotify_bootstrap_error`. A secondary nondeterminism source |
| Pages failure | GitHub Pages **repo setting**, not a workflow | MODIFIED (operator) | Live API: `gh api repos/szTheory/sigra/pages` → `{"build_type":"legacy","source":{"branch":"main","path":"/"},"status":"errored"}`. The legacy Jekyll builder renders `main`'s repo root and dies on `guides/introduction/code-walkthrough.md:174` (`Tag '{%' was not properly terminated`), with warnings on `MAINTAINING.md` GitHub-Actions `${{ }}` expressions |
| Pages self-heal | `scripts/ci/ensure-github-pages-legacy-branch.sh:66-72` | MODIFIED | Already tries the `PUT`; the default `GITHUB_TOKEN` gets 403 and the script logs-and-continues, so the publisher job reports green while the site stays broken. Todo `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` has the full receipt |
| Pages zero-auth backstop | `.nojekyll` at repo root | **NEW** | Makes `pages-build-deployment` green even if the source stays on `main`. Complements (does not replace) the operator repoint |

**Independence:** WS1's Pages half is fully parallel with everything else (no shared file). WS1's flake half is the blocking prerequisite for WS2's release cut.

**Coupling hazard to plan for:** if the fix touches `lib/sigra/admin/live/audit_index_live.ex` markup, `/admin/audit` has committed PNG baselines in **both** snapshot lanes — `tests/admin-design.spec.ts-snapshots/board-audit-row-*.png`, `board-cfg-audit-*.png` and `admin-checkpoints.spec.ts` "Checkpoint 8: Audit explorer". Drift there trips `scripts/ci/snapshot-canary-guard.sh` inside `fast_checks` and requires an **amd64/ubuntu CI-native recapture** via the `admin_design_recapture` / `admin_checkpoint_recapture` jobs (never a darwin local recapture). A spec-only fix avoids that entirely. **Prefer the behaviour-preserving fix (add `phx-submit`/`push_patch` ownership without changing rendered classes/layout), or accept a recapture sub-plan.**

---

### WS2 — Release namespace + cut the release

Verified counts at HEAD: `git tag -l 'v*' | grep -vE '^v[0-9]+\.[0-9]+\.[0-9]+$'` → **28** locally (`v1.0 v1.1 v1.3 v1.4 v1.5 v1.6 v1.7 v1.8 v1.9 v1.10 v1.12 v1.14 v1.15 v1.16 v1.17 v1.21 v1.25 v1.26 v1.27 v1.28 v1.29 v1.30 v1.31 v1.33 v1.34 v1.35 v1.47 v1.48`), **21** on `origin` — so ~7 exist only locally. Plus 11 `phase-238-generated-auth-proof-*`. Real releases: `v0.2.1…v0.3.0, v1.0.0…v1.5.0` (12).

| Item | Path / job | New or Modified | Notes |
|---|---|---|---|
| Tag deletion | `refs/tags/**` local + `origin` | MODIFIED (destructive) | Local and remote sets differ — delete both, and note `v1.47`/`v1.48` were cut *after* the convention said stop |
| Tag guard | `scripts/ci/prohibitions/p17-*.test.mjs` **or** a `fast_checks` step | **NEW** | Two candidate homes, and they are not equivalent: (a) the prohibitions harness (`ci.yml:393`) is repo-content-only and cannot see `refs/tags` — it can only guard the *documented convention*; (b) a real tag-namespace guard must enumerate refs, so it belongs as a `fast_checks` step (`bash scripts/ci/tag-namespace-guard.sh`) with `fetch-depth: 0` + `--tags`, or as a `on: push: tags: ['v*']` job. **Do not put it in `release_ref_guard`** — that job's `if` short-circuits on every non-`workflow_dispatch` event (`ci.yml:74-77`), so a guard placed there never runs on push/PR |
| Contract test | `test/sigra/planning/phase_2NN_*_test.exs` | **NEW** | House idiom: every guard gets a paired contract test asserting the guard exists and fails closed |
| Hex retire | `mix hex.retire sigra 1.20.0 invalid` | MODIFIED (operator, human-gated) | Todo `2026-07-03-hex-retire-stray-1-20-0.md`. Interactive Hex auth — must be a runbook step, never automation |
| Release cut | PR **#224** `chore(main): release 1.5.1`, head `release-please--branches--main` | MODIFIED (merge) | Live check: every non-`SUCCESS` check on #224 is a legitimate `SKIPPED` tier-A lane (`Install matrix`, `Upgrade smoke`, `Passkeys *`, `Nightly probe`, both recapture jobs, `Admin eval render`, `Notify on red ci-gate`). Content-wise it is ready |
| Post-cut verification | `scripts/ci/release-post-publish-verify.sh` (already wired into both publish paths) | unchanged | Reuse for the `{:sigra, "~> 1.0"}` adopter-resolution proof rather than inventing a new script |

**The blocking mechanic, stated precisely:** merging #224 → `release-please` creates tag `v1.5.1` → `gate-ci-green` polls `ci-gate` **on the push-to-main run for that SHA** → `generated_admin_playwright_smoke` is one of the nine lanes `ci-gate` requires → one flaky assertion ⇒ `gate-ci-green` exits 1 ⇒ `publish-hex` never runs ⇒ `notify-release-failure` opens a `release-lane-rot` issue. This is the exact v1.45 stranding mechanism. **WS1 flake fix must be on `main` and observed green before #224 merges.**

**Also worth knowing:** the tag deletion is safe with respect to publishing — `publish-hex` checks out `needs.release-please.outputs.tag_name` and `hex-publish.yml` resolves `git rev-list -n 1 v<version>`; both only ever reference `vX.Y.Z` tags, none of which are being deleted.

---

### WS3 — Clean shipped surface

Verified counts (`grep -rE "Phase [0-9]+|D-[0-9]{2}|[0-9]{3}-[0-9]{2}|\.planning/"`):

- `lib/`: heaviest files are `lib/sigra/auth.ex` (43), `lib/sigra/install/features/organizations.ex` (32), `lib/sigra/organizations.ex` (26), `lib/sigra/config.ex` (20), `lib/sigra/admin/components.ex` (18).
- `priv/templates/sigra.install/`: heaviest are `organizations/live/organization_members_live.ex` (15), `organizations/migration.exs` (12), `organizations/organizations.ex` (10), `core/auth_fixtures.ex` (9).
- The five dead `.planning/` paths: `lib/mix/tasks/sigra.fixture.rebless_golden.ex:11,13`, `lib/sigra/audit.ex:5`, `lib/sigra/testing.ex:1274`, and — the one that ships — **`priv/templates/sigra.install/organizations/organizations.ex:59`**.

**The coupling chain, concretely:**

```
priv/templates/sigra.install/<file>        (edit a comment)
        │ rendered by mix sigra.install
        ▼
test/fixtures/install_golden/tree/<file>   33 fixture files carry 117 bookkeeping hits
        │ asserted byte-for-byte by
        ▼
test/sigra/install/golden_diff_test.exs    (@moduletag :golden, :scaffold, :integration)
        │ run by
        ├─ mix ci.install_golden  (mix.exs:161)  — the `mix ci` alias leg
        └─ job install_golden_contract (ci.yml:420) — PR-gated on a path regex that
             matches ^priv/templates/sigra\.install/ , so template edits DO trigger it
        │ re-blessed by
        ▼
MIX_ENV=test mix sigra.fixture.rebless_golden      (writes the fixture; --check is the
                                                    CI drift-detector, exits 2 on drift)
```

Two further, non-obvious consumers of the same template text:

1. **`test/example/` is a hand-maintained mirror with no parity gate.** 60 files under `test/example/lib` + `test/example/test` carry the same bookkeeping markers. Nothing fails when the template and the example diverge — see todo `2026-07-28-w2-example-sigra-auth-css-stale-no-parity-gate.md`. So a template-only sweep silently leaves the example stale; the sweep must explicitly include `test/example/**` or explicitly record the decision not to.
2. The self-referential one: **`lib/mix/tasks/sigra.fixture.rebless_golden.ex` is itself one of the files being cleaned**, and its `@moduledoc` cites two dead `.planning/` paths while rendering on HexDocs. Likewise `test/sigra/install/golden_diff_test.exs:29` cites a dead `.planning/` regeneration runbook.

| Item | Path | New or Modified |
|---|---|---|
| Library comment sweep | ~25 files under `lib/` | MODIFIED |
| Template comment sweep | ~25 files under `priv/templates/sigra.install/` | MODIFIED |
| Golden fixture | `test/fixtures/install_golden/` (33 files / 117 hits) | MODIFIED — **machine-regenerated, never hand-edited** |
| Example mirror | ~60 files under `test/example/` | MODIFIED (decision required) |
| Runbook doc | replacement for the dead `.planning/` regeneration citation | **NEW** (a `MAINTAINING.md` section or `docs/` page) |

**Sequencing rule inside WS3:** sweep **all** template files in one change, then run `MIX_ENV=test mix sigra.fixture.rebless_golden` **once**, then commit fixture + templates together. A per-file rhythm means N re-blesses of an 85-file tree and N reviews of a mechanical diff. `--check` is the verification, run afterwards.

**Do not touch:** the `# D-NN` annotations inside `.github/workflows/ci.yml`, `.github/ci-skip-manifest.tsv` and `scripts/ci/**` are **load-bearing** — `honest-skip-verdict.test.sh:420-437` and several `phase_2NN_*_test.exs` contract tests grep for exact strings in those files. WS3 is scoped to `lib/` and `priv/templates/` for a reason; keep it there.

---

### WS4 — Clean git working state

Verified at HEAD: 19 local branches, 31 remote branches, **6** stashes, **6** worktrees (5 stale, all under `/private/tmp/` — two `sigra-chimeway-*`, three `sigra-plan3{5,6}.*`; one has a null OID `00000000`, i.e. its checkout is gone).

| Item | Path | New or Modified | Coupling |
|---|---|---|---|
| Worktree prune | `/private/tmp/sigra-*` (5) | MODIFIED | none |
| Stash drop | 6 stashes, oldest on `chore/phase-88-uat-evidence` | MODIFIED | none |
| Branch prune | 19 local / 31 remote | MODIFIED | **Couples to WS5** — do not delete a branch that backs an open PR (`#234`, `#219`, `#174`, `#124` are human-authored) |
| `.gitignore` | `.gitignore` | MODIFIED | `git check-ignore .gsd/` returns **nothing** — `.gsd/` is untracked-and-unignored today, along with `.planning/.gsd-ws-arg` |
| **`doc/llms.txt`** | tracked while `/doc/` is ignored (`.gitignore:11`) | **KEEP — do not delete** | ⚠️ It has three live consumers: `test/sigra/planning/phase_148_*_test.exs:21` and `phase_149_*_test.exs:69,103` read it via `read!("doc/llms.txt")`, and `scripts/ci/launch-pack-contract.sh:18` resolves it. Those tests run inside `mix test` ⇒ `mix ci` ⇒ `library_tests_shard` ⇒ `ci-gate`. Deleting the file reds the aggregate gate. The honest resolution is a `!doc/llms.txt` negation in `.gitignore` making the exception explicit, **not** removal |
| Orphaned script | `scripts/ci/launch-pack-contract.sh` | MODIFIED (flag only) | MEDIUM confidence: a repo-wide grep finds **no workflow that invokes it** — only `phase_149_*_test.exs:118-132` asserts on its *text*. A guard whose only caller is a test that reads its source is the same dishonest shape WS6 is retiring; worth triaging, but it is not blocking |
| Stray root artifacts | `sigra-0.1.0.tar`, `sigra-0.2.0.tar` | MODIFIED | Already covered by `.gitignore:23` (`sigra-*.tar`) and untracked — worktree hygiene only |

**Independence:** WS4 is the most parallel-safe workstream, with the two caveats above (branch-vs-PR, and `doc/llms.txt`).

---

### WS5 — Drain the queue

Live PR list: **10 Dependabot PRs** — `#230 flop_phoenix 0.26.0→0.26.3`, `#229 hammer 7.4.0→7.5.0`, `#228 zod 4.4.3→4.5.4`, `#227 @anthropic-ai/sdk 0.110.0→0.123.0`, `#226 threadline 0.7.0→0.9.0`, `#225 oban 2.23.0→2.24.1`, `#220 otplib 12.0.1→13.5.0`, `#216 @axe-core/playwright 4.11.2→4.13.0`, `#215 actions/attest-build-provenance 4.1.1→4.2.2`, `#213 @playwright/test 1.59.1→1.62.1`, `#183 credo 1.7.18→1.7.19`. Human PRs: `#234`, `#224` (the release), `#219`, `#211`, `#174`, `#172`, `#124`. Pending todos: **41** in `.planning/todos/pending/`.

Blast-radius map (which lane each bump perturbs — this is the ordering-relevant part):

| PR | Perturbs | Why it matters to v1.48 |
|---|---|---|
| `#213 @playwright/test 1.59→1.62` | `example_playwright_shard`, `example_playwright_smoke`, **`generated_admin_playwright_smoke`**, both recapture jobs, `playwright-github-pages.yml` | **Highest risk.** A minor Playwright bump can shift rendering and invalidate the committed PNG baselines under `tests/*-snapshots/`, and it changes the very runner whose flake WS1 is characterizing. Merging it mid-WS1 destroys the before/after signal |
| `#216 @axe-core/playwright 4.11→4.13` | a11y assertions in the design-gallery seam (`p02-axe-signal-not-reduced.test.mjs` guards against weakening them) | New axe rules can introduce new violations = new reds |
| `#220 otplib`, `#228 zod`, `#227 @anthropic-ai/sdk` | Playwright-dir npm only (eval/panel helpers) | Low risk, no baseline exposure |
| `#183 credo 1.7.18→1.7.19` | `mix ci` (`format --check-formatted` / `compile --warnings-as-errors` legs) → `library_tests_shard` | MEDIUM confidence: `credo` is a dev dep; whether a `mix credo` leg exists in `mix ci` — it does **not**, the alias is format/deps/compile/test/install_golden/dep_off. So the risk is limited to dep resolution |
| `#226 threadline 0.7→0.9` | **`library_tests_dep_off`** (the "Threadline absent" lane) + `lib/sigra/audit/forwarders/threadline.ex` | Touches an optional-dep lane that is one of the nine required `ci-gate` lanes |
| `#225 oban`, `#229 hammer`, `#230 flop_phoenix` | `mix.lock` → `library_tests_shard`, `install_smoke`, `upgrade_smoke` | `flop_phoenix` is a UI dep for admin tables — a version bump can move rendered markup and hence PNG baselines |
| `#215 actions/attest-build-provenance` | `.github/workflows/**` | Interacts with WS6's supply-chain guard: the pin format must keep its same-line `# vX.Y.Z` comment or `phase_234_action_pinning_contract_test.exs` fails |

**Todos:** 12 of the 41 pending todos are direct v1.48 inputs and should be closed *by* the milestone rather than triaged separately — notably `2026-07-30-admin-generated-audit-presets-actor-filter-race.md` (WS1), `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` (WS1), `2026-07-03-hex-retire-stray-1-20-0.md` (WS2), `2026-09-15-honest-skip-parity-guard-does-not-exist.md` (WS6), `2026-09-15-composite-action-outside-supply-chain-guards.md` (WS6), `2026-09-15-test-01-02-timing-machinery-orphaned.md` (WS6), `2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` (WS6-adjacent, see below).

---

### WS6 — Retire v1.47's dishonest debt

| Item | Exact path | New or Modified | Verified state |
|---|---|---|---|
| Orphaned formatter | `test/support/ci/ex_unit_timing_formatter.ex` | MODIFIED (delete) | Repo-wide grep: the **only** references to `ExUnitTimingFormatter` / `SIGRA_EXUNIT_TIMING_PATH` are the module itself and its own test. Zero references in `.github/`, `scripts/`, `mix.exs`. Confirmed dead |
| Its test | `test/support/ci/ex_unit_timing_formatter_test.exs` | MODIFIED (delete) | Lives under `test/support/` but matches `test/**/*_test.exs`, so `mix test` does execute it |
| Blessing contract test | `test/sigra/planning/phase_233_library_economics_contract_test.exs` | MODIFIED (rewrite) | It currently *requires* the replacement topology (`assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1`, `refute body =~ "mix test"`), i.e. it asserts the regression is correct. Note it also depends on `Sigra.Test.PlanningPaths.phase_file("235-terminal-ratification-measured-not-read", "235-FAST-01-REMEDIATION.json")` — a `.planning/` read, so rewriting it must keep or retire that dependency deliberately |
| Fictional guard citation | `.github/ci-skip-manifest.tsv` header (lines ~11-19) | MODIFIED | It names `scripts/ci/prohibitions/honest-skip-parity.test.mjs` as a three-way `manifest ⇔ ci.yml ⇔ MAINTAINING.md` parity guard. `ls scripts/ci/prohibitions/` = `_lib.mjs` + `p01`…`p16` only. **That file does not exist.** Two honest exits: write it (as `p17-honest-skip-parity.test.mjs`, matching the `ci.yml:393` glob so it is automatically picked up) or delete the claim |
| Rotted prose leg | `MAINTAINING.md:141-199` ("Honest-skip set after Phase 230") | MODIFIED | The manifest header calls this prose "a RENDERER of this file, not a second source of truth" — but with no parity guard, nothing enforces that, so it is a second source of truth today |
| Composite action outside guards | `.github/actions/example-playwright-boot/action.yml` (4 `uses:` — `erlef/setup-beam`, `actions/setup-node`, `actions/cache` ×2) | MODIFIED (extend guard) | `phase_234_action_pinning_contract_test.exs` scans only `@release_workflows = [release-please.yml, hex-publish.yml]`, and `action_entry/4` explicitly returns `[]` for `"./" <> _local_action`. So the composite is invisible to the pin guard in **both** directions: its own pins are unchecked, and its call sites are skipped |
| Dependabot coverage | `.github/dependabot.yml` | MODIFIED (verify) | MEDIUM confidence: the `github-actions` ecosystem is registered at `directory: "/"`; whether Dependabot's `/` scan reaches `.github/actions/*/action.yml` (as opposed to `.github/workflows/**` + a root `action.yml`) should be verified live against a bump, not assumed. `phase_234_dependabot_contract_test.exs` pins the config to exactly three ecosystems, so any change there is guarded |
| Known adjacent gap | `example_unit_smoke` is a ruleset-required check but is **absent from `ci-gate.needs`** | MODIFIED (optional) | `honest-skip-verdict.sh` itself prints this as an advisory NOTE on every run. Filed as `2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`. In scope for "honest gate", out of scope for a strict reading of the six workstreams — flag it to the roadmapper |

**House idiom to follow for anything NEW here** (observed across p01–p16 and the `*.test.sh` self-tests wired into `fast_checks`): every guard is (a) a standalone script with a hermetic self-test, (b) proven to fail **first** against a known-bad fixture under `test/fixtures/prohibitions/`, and (c) paired with an ExUnit contract test under `test/sigra/planning/`. A new guard that has never been observed red does not count.

---

## Dependency Graph and Build Order

```
                    ┌──────────────────────────────┐
                    │ WS1a  flake root cause + fix │  ← BLOCKS the release cut
                    │  (+ dead PLAYWRIGHT_RETRIES) │
                    └───────────────┬──────────────┘
                                    │ must be green across
                                    │ ≥2 consecutive main pushes
                    ┌───────────────▼──────────────┐
                    │ WS2  tag prune + tag guard   │
                    │      + merge PR #224         │
                    │      + operator Hex retire   │
                    └───────────────┬──────────────┘
                                    │ release cut lands
                    ┌───────────────▼──────────────┐
                    │ WS5  Dependabot drain        │  ← held until AFTER the cut
                    │      (Playwright bump last)  │
                    └──────────────────────────────┘

  fully parallel from day one, no shared files with the chain above:
    WS1b  GitHub Pages (repo setting + .nojekyll + ensure-script honesty)
    WS3   shipped-surface sweep + ONE batched golden re-bless
    WS4   git working state  (minus the PR-backed branches → after WS5)
    WS6   v1.47 debt retirement
```

**Ordering rationale, claim by claim:**

1. **WS1a strictly first.** `ci-gate` gates `gate-ci-green` gates `publish-hex`. Any release cut attempted while the flake lives has a per-run coin-flip chance of stranding — and the stranding is *silent to the merger*, surfacing only as a `release-lane-rot` issue. This is the v1.45 mechanism verbatim.
2. **Evidence before fix.** The flake's own diagnosis must be captured *before* any Playwright bump (`#213`) lands, or the before/after signal is contaminated by a new browser build.
3. **WS2 tag prune can start in parallel with WS1a**, but the **merge of #224 cannot**. Splitting WS2 into (tag hygiene + guard) and (cut the release) lets the roadmapper parallelize the cheap half.
4. **WS5 after WS2.** Every Dependabot bump perturbs `mix.lock` or the Playwright runner — i.e. exactly the lanes being stabilized and exactly the inputs to the release artifact. Merging them before the cut means the release ships deps that never ran through a full green nightly. Merge order within WS5: GitHub-Actions and pure-npm-tooling bumps first (`#215`, `#227`, `#228`, `#220`), then Elixir deps (`#225`, `#229`, `#230`, `#226`, `#183`), then `#216` axe, then `#213` Playwright **last and alone** so a baseline recapture (if triggered) is attributable.
5. **WS3 batches its re-bless once.** 33 fixture files / 117 hits. Sweep all of `priv/templates/sigra.install/` → one `mix sigra.fixture.rebless_golden` → verify with `--check`. Also decide the `test/example/**` parity question explicitly, because nothing will fail if you get it wrong.
6. **WS3 is parallel-safe against WS1/WS2** — it touches `lib/` + `priv/templates/` + `test/fixtures/`, none of which the flake fix or the tag work touches — **unless** WS1 fixes the flake in `lib/sigra/admin/live/audit_index_live.ex`, which is also a WS3 sweep target. That is a one-file merge conflict, not a design conflict; assign the file to one workstream.
7. **WS4's branch prune goes after WS5**, because PR-backed branches must survive until their PRs close. Worktrees, stashes, `.gitignore` and the `doc/llms.txt` negation can go immediately.
8. **WS6 is fully parallel.** It touches `test/support/ci/**`, `test/sigra/planning/phase_233_*`, `.github/ci-skip-manifest.tsv`, `MAINTAINING.md`, `.github/actions/**` and `test/sigra/planning/phase_234_action_pinning_*` — zero overlap with WS1–WS5, except that a **new `p17-honest-skip-parity.test.mjs` will assert `manifest ⇔ ci.yml ⇔ MAINTAINING.md`**, so if WS1 edits `ci.yml` job names or `if:` gates, that guard must be written after (or re-run against) WS1's final `ci.yml`. Sequence WS6's parity guard *after* WS1a's `ci.yml` edits settle.

**Which workstreams can run fully in parallel:** WS1b (Pages), WS3 (shipped surface), WS6 (v1.47 debt) — all three from day one. WS4 is parallel except its branch prune. WS2's tag half is parallel; WS2's cut is not. WS5 is the only workstream that must wait for two others.

---

## Anti-Patterns to Avoid in This Milestone

### Anti-Pattern 1: Retry-wrapping the flake
**What people do:** set `retries: 1` (or wire the already-dead `PLAYWRIGHT_RETRIES: 1`) and call `ci-gate` green.
**Why it's wrong:** the milestone's own thesis is "green main, *honestly*". The todo records the failure as "sticky-within-run — both attempt and retry hit the identical timeout", so a retry would not even mask it reliably. And the underlying defect is in `lib/`, i.e. it ships to adopters.
**Do this instead:** fix the URL-truth ownership on the audit filter form, or make the assertion wait on a deterministic applied-state signal. Delete the dead `PLAYWRIGHT_RETRIES` env either way.

### Anti-Pattern 2: Hand-editing `test/fixtures/install_golden/`
**What people do:** sed the bookkeeping comments out of the fixture tree alongside the templates.
**Why it's wrong:** `mix sigra.fixture.rebless_golden --check` runs as a hard gate in `install_golden_contract` and re-derives the tree from the pinned `phx_new 1.8.8` archive. A hand-edited fixture that happens to match is luck; one that does not is a red gate with a 20-file diff.
**Do this instead:** edit templates only; regenerate once; review the delta report the task prints.

### Anti-Pattern 3: Deleting `doc/llms.txt` because `/doc/` is gitignored
**What people do:** treat the tracked-while-ignored file as an accident and remove it.
**Why it's wrong:** three live consumers read it (`phase_148_*_test.exs`, `phase_149_*_test.exs`, `scripts/ci/launch-pack-contract.sh`), and two of them run inside `mix ci` → `library_tests_shard` → `ci-gate`.
**Do this instead:** make the exception explicit with a `!doc/llms.txt` negation and a comment saying why.

### Anti-Pattern 4: Putting the tag guard in `release_ref_guard`
**What people do:** the job is named "Release ref guard", so the tag guard looks like it belongs there.
**Why it's wrong:** that job returns `exit 0` immediately unless `github.event_name == 'workflow_dispatch'` (`ci.yml:74-77`). A guard placed there is invisible on push and PR — a guard that never runs, which is the exact class of defect v1.48 is retiring.
**Do this instead:** a `fast_checks` step (with `fetch-depth: 0` and `--tags`) and/or a dedicated `on: push: tags` job, plus a paired contract test.

### Anti-Pattern 5: Writing the missing honest-skip-parity guard before `ci.yml` settles
**What people do:** close the manifest's fictional citation first because it is cheap.
**Why it's wrong:** the guard asserts three-way parity against `ci.yml`'s job ids, display names and gate expressions. WS1 edits `ci.yml`. You would be pinning a moving target and then re-blessing the guard.
**Do this instead:** land WS1's `ci.yml` edits, then write `p17`.

---

## Integration Points Summary

### Cross-workstream file collisions

| File | Claimed by | Resolution |
|---|---|---|
| `lib/sigra/admin/live/audit_index_live.ex` | WS1 (flake fix) + WS3 (comment sweep) | Assign to WS1; WS3 skips it |
| `.github/workflows/ci.yml` | WS1 (`PLAYWRIGHT_RETRIES`, possible job edits) + WS2 (tag guard step) + WS6 (parity guard reads it) | WS1 first, WS2 additive step, WS6 last |
| `.planning/todos/pending/**` | WS5 (triage) + WS1/WS2/WS6 (each closes its own) | Let each workstream resolve its own todos; WS5 triages the remainder |
| `tests/*-snapshots/*.png` | WS1 (if lib markup changes) + WS5 (`#213` Playwright bump) | Never both in the same PR — baseline drift must be attributable to one cause |

### External / operator-gated steps (cannot be automated)

| Step | Why | Owner |
|---|---|---|
| `mix hex.retire sigra 1.20.0 invalid` | Hex write-auth prompts interactively | szTheory |
| Settings → Pages → Branch = `gh-pages` / | Default `GITHUB_TOKEN` gets 403 on the Pages API `PUT` (observed in run `30613728531`) | szTheory (repo admin) |
| `git push --delete origin <tag>` ×21 | Destructive on a public repo | szTheory |

---

## Sources

All findings below were read directly from the repository at `main` @ `17764671` or fetched live from the GitHub / Hex APIs on 2026-09-15. Confidence **HIGH** unless noted.

- `.github/workflows/ci.yml` — job inventory, `ci-gate` needs list (`:1535-1638`), `generated_admin_playwright_smoke` (`:1401-1533`), `release_ref_guard` (`:62-105`), `fast_checks` (`:160-419`), `install_golden_contract` (`:420-505`)
- `.github/workflows/release-please.yml` — `release-please` → `gate-ci-green` → `publish-hex` → `notify-release-failure`
- `.github/workflows/hex-publish.yml` — manual recovery path and its `v<version>` provenance check
- `.github/workflows/playwright-github-pages.yml`, `scripts/ci/ensure-github-pages-legacy-branch.sh`
- `.github/ci-skip-manifest.tsv` (header lines 11-19 cite the nonexistent guard)
- `scripts/ci/prohibitions/` — `ls` confirms `_lib.mjs` + `p01`…`p16`, no `honest-skip-parity.test.mjs`
- `scripts/ci/admin-acceptance-smoke.sh`, `scripts/ci/honest-skip-verdict.sh`, `scripts/ci/wait-for-ci-gate.sh`
- `test/sigra/install/golden_diff_test.exs`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `test/fixtures/install_golden/`
- `test/sigra/planning/phase_233_library_economics_contract_test.exs`, `phase_234_action_pinning_contract_test.exs`, `phase_234_dependabot_contract_test.exs`, `phase_148_*`, `phase_149_*`
- `test/example/priv/playwright/playwright.config.ts` (`retries: 0` at `:59`), `tests/admin-generated.spec.ts` (`:428-461`)
- `lib/sigra/admin/live/audit_index_live.ex` (`:76-128` filter form; no `handle_event`)
- `mix.exs:144-174` (the `ci` / `ci.install_golden` aliases)
- GitHub Actions API: run `34996937053` failing log (the exact `toHaveURL` assertion), runs `34929531476`, `34990229412`, `34738257820`, `34673395374`; same-SHA pass/fail flip-flop on `1afd37f0` and `158aca14`
- GitHub API `repos/szTheory/sigra/pages` → `{"build_type":"legacy","source":{"branch":"main","path":"/"},"status":"errored"}`
- `gh pr list` (18 open), `gh pr view 224` (all non-SUCCESS checks are legitimate tier-A skips)
- `git tag -l`, `git ls-remote --tags origin`, `git worktree list`, `git stash list`, `git check-ignore`
- `.planning/todos/pending/` (41 items), especially `2026-07-30-admin-generated-audit-presets-actor-filter-race.md` and `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
- `.planning/PROJECT.md` — `## Current Milestone: v1.48 CLEAN-BASELINE`, `## Current State`

**MEDIUM confidence (flagged for verification during the milestone):** (1) whether Dependabot's `github-actions` `/` scan reaches `.github/actions/*/action.yml`; (2) whether `scripts/ci/launch-pack-contract.sh` has any caller outside its own contract test.

---
*Architecture research for: Sigra v1.48 CLEAN-BASELINE — cleanup-workstream integration map*
*Researched: 2026-09-15*
