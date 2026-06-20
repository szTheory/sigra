# Maintaining Sigra

This document is for **maintainers** who cut Hex releases and GitHub releases. **Drive-by contributors** should start with [`CONTRIBUTING.md`](CONTRIBUTING.md) for tests, CI expectations, and review norms.

Hex releases exercise the library and templates — they do **not** validate an adopter’s production TLS termination, reverse proxy, session cookies, or mail delivery. Point application teams at the **[production checklist in the deployment recipe](guides/recipes/deployment.md#production-checklist-read-first)** before they go live.

On your **first public Hex release**, follow **`Release automation`** for the mechanical ship path; when you are ready to coordinate evidence and optional comms around that ship, use **`First public launch (announcement checklist)`** later in this file.

## Issue Triage & Bugfix Cadence

1. **Monitor:** Check GitHub issues (`gh issue list`) weekly.
2. **Categorize:** Label issues as `bug` (core logic), `friction` (DX/documentation), or `enhancement` (feature request).
3. **Prioritize:** Address `bug` and `friction` items in the next patch release. Defer `enhancement` items. Reference the severity classes (P0-P3) from `docs/release-runbook-v1-0.md`.
4. **Communication Posture:** Keep updates factual and version-specific. State impact, workaround status, and next decision checkpoint. Avoid implying unsupported guarantees beyond documented release evidence.
5. **Template Updates:** Whenever generator templates are touched, the maintainer MUST list `mix sigra.upgrade --yes` under a "Template Updates Required" header in `CHANGELOG.md`.

## Milestone cadence and pause (v1.11+)

GSD milestones (**`/gsd-new-milestone`**, **`.planning/REQUIREMENTS.md`**, phased **`.planning/ROADMAP.md`**) are for **coordinated tranches** that move **North Star** outcomes in **`.planning/PROJECT.md`**. They are **not** required for every Hex publish.

**Pause full milestone cycles** (ship **patch/minor** via **`CHANGELOG.md` + tag + Hex** only) when all of the following are true:

1. **No P0/P1** adoption or security items remain from maintainer triage (issues, dogfood runs, README vs guides consistency).
2. The next candidate milestone would mostly duplicate **docs-only polish** without a new **trust signal** (merge-blocking CI change, honest scope boundary, or materially new integrator path) — same “diminishing returns” bar used for **v1.8** adopter polish.
3. **Hex releases** can carry fixes with conventional commits and **`CHANGELOG.md`** entries without remapping **REQ-IDs**.

**Resume `/gsd-new-milestone`** when an **event** warrants a scoped tranche, for example: public launch prep + **SEED-001** human matrix; compliance or customer evidence forcing **SEED-002** batches; **ADR 001** revisit for **`sigra_lockspire`** / Lockspire glue; or a **documented adoption gap** that does not fit a single patch.

## v1.12 trust bundle (audit + UAT evidence)

**v1.12** packages the **bounded SEED-002 audit closure** narrative, the **eight-row GA·UAT outcome index**, and the **machine vs residual** CI catalog into a small set of stable links. Do **not** fork the eight-row matrix into **Hex-facing** guides — treat **[`docs/uat-ci-coverage.md`](docs/uat-ci-coverage.md)** as the catalog and **[`v1.12-UAT-EVIDENCE.md` on `main`](https://github.com/sztheory/sigra/blob/main/.planning/v1.12-UAT-EVIDENCE.md)** as the milestone outcome index.

**Release ritual:** when cutting a **minor** or **major**, confirm **`CHANGELOG.md`**, **`guides/introduction/upgrading-to-v1.12.md`**, and the two URLs above still agree (no renamed paths, no duplicated tables).

## Installer golden CI contract (phase 50)

The installer subprocess harness (`mix phx.new` + generated app) is expensive; do not rely on “it passed locally once.” Run the scoped merge gate the same way CI does:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden
```

That alias runs **`test/sigra/install/golden_diff_test.exs`** and **`test/sigra/install/idempotency_test.exs`** only. **`golden_diff_test.exs`** sets **`@moduletag timeout: 300_000`** (five-minute module budget) because archive install + scaffold work can exceed the default ExUnit timeout.

GitHub Actions runs the same two paths on every push to **`main`** and on PRs that touch installer paths, via the **`install_golden_contract`** job in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

### PR paths that run install_golden_contract (phase 51)

PR diffs that touch any of the following path classes run both **`install_golden_contract`** and **`installer_milestone_audit`** (same diff rule in CI):

- **`priv/templates/sigra.install/`**
- **`lib/sigra/install/`**
- **`lib/sigra/mfa`** (top-level **`mfa.ex`** or **`mfa/`** subtree)
- **`lib/sigra/oauth`**
- **`lib/sigra/account`**
- **`lib/sigra/passkeys`**

Waived **GA-03** / **GA-04** rows in **`.planning/v1.4-GA-UAT.md`** document OAuth mock and getting-started CI substitutes; those waivers do **not** replace **`mix ci.install_golden`** / **`install_golden_contract`** for **`priv/templates/sigra.install/`** template drift — see **`.planning/phases/50-nyquist-ci-gate-hygiene/50-VERIFICATION.md`** for how installer attestation is defined (CI on **`main`**, not a pasted markdown row).

### Troubleshooting slow or hung local `mix ci.install_golden`

The harness shells out to **`mix deps.get`** inside a generated tmp Phoenix app (`Sigra.Test.InstallFixture`). Long stalls are almost always **Hex / registry network I/O**, not Sigra compile errors. Prefer running the same work in CI (**`install_golden_contract`**) or use a warm local Hex cache and stable network. For Hex client tuning, see your installed Hex version’s docs (`mix help hex.config`); there is no separate Sigra knob beyond normal Mix/Hex environment.

## Nyquist policy (phases 41-44)

This section is the **maintainer front door** for how **Nyquist-style** evidence is read across GA phases **41-backup-codes** through **44-mfa-account-api**. It states what the posture matrix **does** guarantee (honest disposition + repo-relative evidence pointers + reopen triggers) and what it **does not** (it does not replace each phase’s **`*-VALIDATION.md`** / **`*-VERIFICATION.md`** as the source of **`nyquist_compliant:`** and waiver text).

**Canonical detail** — full table, paths, and **v1.5** `ref:` block — lives in **[`.planning/nyquist-phases-41-44-matrix.md`](https://github.com/szTheory/sigra/blob/main/.planning/nyquist-phases-41-44-matrix.md)** on GitHub (not shipped in the Hex package tarball). A short HexDocs-facing overview is **[`docs/nyquist-posture-matrix.md`](docs/nyquist-posture-matrix.md)**. If this **`MAINTAINING.md`** summary ever disagrees with the **`.planning/`** matrix file, **the matrix file wins**.

**Reopen (installer-class drift):** when **`priv/templates/sigra.install/`** or **`lib/sigra/install/`** change, re-run the same scoped gate CI uses: **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden`**. Phase-specific scoped tests remain defined in each phase’s **`41-backup-codes`** / **`44-mfa-account-api`** **`*-VERIFICATION.md`** files (see the matrix).

## GitHub Actions repository settings (runbook)

These are **repository** (or org) settings on GitHub, not files in this repo. A maintainer with **admin** access must apply them once so **Release Please** can open and update release PRs using the default `GITHUB_TOKEN`.

**Where:** [Repository → Settings → Actions → General](https://github.com/szTheory/sigra/settings/actions) (replace `szTheory/sigra` if you forked).

### Workflow permissions (required for Release Please)

Under **Workflow permissions**:

1. Select **Read and write permissions** so workflows can push release branches and update files as needed.
2. Enable **Allow GitHub Actions to create and approve pull requests**. Without this, Release Please fails with: *GitHub Actions is not permitted to create or approve pull requests* — even when `.github/workflows/release-please.yml` sets `permissions: pull-requests: write`.

The workflow already requests `contents: write`, `issues: write`, and `pull-requests: write` in YAML; the UI above must allow PR creation for that to take effect.

### Which actions may run

Pick the **least privilege** your org policy allows while still running third-party actions (`googleapis/release-please-action`, `actions/*`, `erlef/setup-beam`, etc.):

- **Allow all actions and reusable workflows** — simplest default for this repo.
- **Allow szTheory, and select non-szTheory…** — fine if org policy requires an allowlist; ensure every external action you use is permitted.

**Allow szTheory actions only** is only viable if every action is defined inside the `szTheory` org (usually not true here).

### Fork pull request workflows

Unrelated to Release Please on `main`. A common balance is **Require approval for first-time contributors**; stricter orgs use **Require approval for all external contributors**.

### Branch protection — enforced required checks (live ruleset)

Branch protection for `main` is enforced via **ruleset 14941512** (`enforcement: active`), not
legacy branch protection rules. The five enforced required checks are the **job `name:` strings**
that GitHub collects as status contexts when each CI job runs:

1. `Library tests`
2. `Example unit smoke (ExUnit + ConnTest)`
3. `Install smoke (fresh phx.new + sigra.install)`
4. `Example HTTP smoke (boot + curl critical routes)`
5. `Example Playwright smoke (full lifecycle)`

**`ci-gate` is NOT an enforced required check.** It is an internal aggregator job that gates the
rest of the DAG; it does not appear in ruleset 14941512’s `required_status_checks`. Do not rename
or remove the five job `name:` strings above — doing so removes the context GitHub needs to
enforce the rule.

To verify the live list at any time: `gh api repos/szTheory/sigra/rulesets/14941512 --jq ‘.rules[] | select(.type==”required_status_checks”) | .parameters.required_status_checks[].context’`

> **Note on install golden (shift-left):** The `install_golden_contract` job is gated on the
> PR diff touching installer paths and is not in the live ruleset’s required checks.
> It is a path-scoped quality gate, not a merge-blocking required check — it flows into
> `ci-gate` (the internal aggregator). The docs below explain its path triggers.

### CI cadence — PR-fast vs nightly/main-broad (Phase 196)

The `main` CI file (`.github/workflows/ci.yml`) follows a **two-tier cadence** introduced in Phase 196:

**PR-fast gate (runs on every PR and push):**
- The 5 required lanes (Library tests, Example unit smoke, Install smoke, Example HTTP smoke, Example Playwright smoke)
- `install_golden_contract` (path-gated on installer changes)
- `library_tests_dep_off` (Threadline dep-off guard)

**Nightly / main / dispatch-broad coverage (runs on `schedule:`, `push: main`, `workflow_dispatch` — skipped on PRs):**
- `install_matrix` (four flag-combination installs)
- `upgrade_smoke` (published → local upgrade path)
- `passkeys_manual_fallback_smoke` and `passkeys_opt_out_smoke`
- `generated_admin_playwright_smoke` (generated-host admin behavior ~60 min)
- `nightly_probe` (forced-failure self-test; see runbook below)

The nightly schedule runs at `cron: '30 4 * * *'` (04:30 UTC daily).

#### Accepted residuals (D-07 honest-truth disclosure)

Two coverage areas moved to nightly are accepted residuals and must never be silently treated as "covered on PRs":

1. **`upgrade_smoke` whole upgrade path** — the published-package → local-candidate upgrade path has **no per-PR behavioral proxy**. It runs on `push: main` and release dispatch (so every merge to main is covered before release), but not on individual PRs. This is accepted as release-boundary coverage; any regression surfaces before a Hex publish.

2. **Generated-host template parity** — `generated_admin_playwright_smoke` (the full generated-host admin Playwright run) is fully moved to nightly. Admin _behavior_ is proxied on PRs by `example_playwright_smoke`'s admin specs (a required lane). However, the **template-parity** check (installer-emitted shell vs library admin) becomes nightly-only. This residual is explicitly backstopped by **DIST-06 `scripts/ci/admin-acceptance-smoke.sh`** (`RUN_PARITY`) — the acceptance smoke script that scaffolds a fresh `phx.new + sigra.install` and runs the full Playwright suite against the generated host. This automation is the proxy for template-parity regressions between nightly runs.

These two residuals are deliberate, disclosed tradeoffs that shorten PR wall-clock time without silently stranding correctness-critical coverage. They are documented here, not as a footnote, because any maintainer touching the move list must understand what is and is not covered on PRs.

#### Squash-merge `[skip ci]` footgun (merge hygiene)

GitHub honors a `[skip ci]` token found **anywhere** in a commit message, and a
**squash** merge concatenates *every* commit message in the PR into the squash
commit body. So if any single commit in the branch quotes or mentions `[skip ci]`
(even in prose — e.g. describing the `admin_design_recapture` auto-PR, whose own
commit uses `[skip ci]`), the squash-merge commit inherits it and **the entire
push-to-main CI run is silently skipped** — including `admin_design_recapture`.

Observed 2026-06-20 merging v1.40 (PR #58): the push-to-main CI run produced **zero**
runs (`gh api .../actions/workflows/ci.yml/runs` had no entry for the merge SHA), so
the recapture job never fired.

**When squash-merging a multi-commit PR, scrub the squash commit body of any
`[skip ci]` / `[ci skip]` token before confirming the merge** (edit the squash
message in the merge dialog, or `gh pr merge --squash` then verify
`git log -1 --format=%B origin/main | grep -i 'skip ci'` is empty). If a merge
already skipped CI, trigger a fresh push-to-main (a follow-up clean-message PR
merge) or wait for the nightly `schedule` run, which is immune (the token only
affects `push`/`pull_request` head commits). Tracked as the
`recapture-pr-skip-ci-pending-trap` finding in the SEED-005 audit.

#### Forced-failure probe runbook (D-14)

The `nightly_probe` job contains a `force_fail_probe`-guarded `exit 1` step that lets you verify the nightly lane actually reports failure when something is broken.

**Red the nightly probe (proves nightly lane detects failures):**

```bash
gh workflow run "CI" -f force_fail_probe=true
```

The `nightly_probe` job will report red in the Actions UI independently of all other jobs. This exercises the nightly trigger path without touching real smoke jobs.

**Normal run (default `force_fail_probe=false` — probe stays green):**

```bash
gh workflow run "CI"
```

Or simply: push to `main` or wait for the 04:30 UTC schedule — `force_fail_probe` defaults to `false` and the probe step is skipped.

`nightly_probe` is **not** in `ci-gate.needs` and is not a required check, so a red probe does not block PRs — it is a standalone operational self-test.

### Artifact, log, and cache retention

Retention controls cost and history only; **no impact** on Release Please or Hex publish mechanics.

#### Actions `deps`+`_build` cache keys (CACHE-01)

All 11 `deps`+`_build` cache blocks in `.github/workflows/ci.yml` bind the resolved toolchain
identity so a stale `_build` is never reused across an incompatible OTP/Elixir/MIX_ENV combo.
The cache key shape per namespace is:

```
${{ runner.os }}-<namespace>-otp<OTP>-elixir<ELIXIR>-<MIX_ENV>-<lockfile-hash>-v1
```

where `<OTP>` and `<ELIXIR>` are the values resolved by `erlef/setup-beam`
(`steps.setup.outputs.otp-version` / `steps.setup.outputs.elixir-version`), and
`<lockfile-hash>` is the `hashFiles(...)` of the relevant lockfile(s) for that lane.
The four cache namespaces (`-library-`, `-library-dep-off-`, `-example-`, `-example-dev-`)
are preserved so lanes cannot cross-contaminate.

**How to bust the cache manually:** Bump the trailing `-v1` buster segment (e.g. to `-v2`) on
all 11 deps+`_build` cache keys. This forces a new key namespace so every lane gets a fresh
cold miss on the next run and rebuilds `_build` from scratch. The `-v1` segment is the documented
bust handle — increment it globally and commit when you need a forced rebuild (e.g. after an
OTP upgrade that the key hash alone would not catch, or after suspected cache corruption).

> **Forward-looking note (D-06):** A future Dialyzer/PLT lane MUST get its own separate PLT
> cache key — never share it with the `deps`+`_build` cache. Merging PLT artifacts into the
> deps cache would invalidate the deps cache on every Dialyzer run, defeating the caching benefit.

The 4 `-hex-registry-` cache blocks (caching `~/.hex`, not `_build`) are intentionally outside
this scheme — they carry no stale-artifact correctness risk and already have `restore-keys`.

### Verify Release Please after changing settings

From a machine with `gh` authenticated to this repo:

```bash
gh workflow run "Release Please" --ref main
gh run list --workflow "Release Please" --limit 1
gh run watch "$(gh run list --workflow 'Release Please' --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```

**Success signals**

- The **Release Please** job finishes **without** the error: *GitHub Actions is not permitted to create or approve pull requests*.
- A pull request may appear titled like a Release Please release (inspect open PRs targeting `main`; Release Please often uses a working branch such as `release-please--branches--main`).

**If it still fails with that permission error**, the repository (or **organization**) Actions policy still blocks PR creation by `GITHUB_TOKEN` — re-check the two **Workflow permissions** bullets above and any **organization-level** Actions overrides.

### If the org forbids “Actions may create PRs”

Do **not** enable **Allow GitHub Actions to create and approve pull requests**. Instead add a fine-grained **PAT** as the **`RELEASE_PLEASE_TOKEN`** secret (contents + pull-requests write, and any scopes Release Please needs for your branch rules). The workflow uses `token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}` — see **Release automation** below.

## Sigra 1.0 release path

The selected release path is a direct Hex `1.0.0` cut from `main`, not a public RC train by default. RCs are a fallback only if hardening finds a concrete blocker that needs external validation.

For this one-time major release, `release-please-config.json` carries `"release-as": "1.0.0"` in `packages["."]`. `.release-please-manifest.json` remains the last shipped `0.3.0` until the Release Please release PR records the new release, and `mix.exs` `@version` changes inside that Release Please release PR.

After the 1.0 release PR merges and the release is cut, remove or update the `"release-as": "1.0.0"` override before normal conventional-commit SemVer resumes.

Phase 146 canonical runbook: `docs/release-runbook-v1-0.md`.
It is the single source for the release gate matrix, dry-run/package inspection, publish recovery branches, post-publish checks, and first-14-day hotfix policy.
Keep this file as the maintainer entry-point index and do not duplicate the full matrix here.

## Release automation (default)

Sigra follows the same pattern as sibling libraries (**Release Please** + **Hex on merge**):

1. **Conventional commits on `main`** — Release Please reads history and opens/updates a **Release PR** that bumps `mix.exs` / `CHANGELOG.md` (see [release-please](https://github.com/googleapis/release-please) and config in `release-please-config.json`).
2. **Merge the Release PR** when you are ready to ship. On merge, **`.github/workflows/release-please.yml`** creates the **GitHub Release** and **`v<version>` tag**, then runs **Postgres-backed `mix test`**, **`mix hex.publish --yes`** with **`HEX_API_KEY`**, and polls **hex.pm** until the new version is visible.
3. **Secrets** — configure **`HEX_API_KEY`** under **GitHub → Settings → Secrets and variables → Actions**. If you cannot enable **Allow GitHub Actions to create and approve pull requests** (org policy), add a fine-grained PAT as **`RELEASE_PLEASE_TOKEN`** with `contents` + `pull-requests` write (and scopes required by your branch rules); the workflow uses `RELEASE_PLEASE_TOKEN` when set, otherwise `github.token`. If the UI *is* enabled but you still see token errors, check org-level Actions policies overriding the repo.
4. **Released version anchor** — `.release-please-manifest.json` records the last shipped version for Release Please. After an exceptional manual publish, bump that file in the same commit as `mix.exs` so automation stays aligned.
5. **Changelog shape** — Release Please’s `elixir` release type expects to own `CHANGELOG.md` entries for automated releases. The first Release PR may normalize headings; resolve merge conflicts in favor of a single coherent history, then keep using **conventional commits** on `main`.

**Recovery / one-off publish:** **Actions → Hex publish (manual recovery)** — supply the **tag or SHA** and the **expected `@version`** string; it runs the same compile + test + dry-run + publish path without Release Please.

## First public launch (announcement checklist)

Relative links in this file are for **in-repo navigation and HexDocs-packaged paths only**. Evidence that lives **outside** the Hex tarball (anything under **`.planning/`** on GitHub) must use **pinned tag** URLs matching the published **`mix.exs` `@version`** / `docs` `source_ref` — never `main` blob URLs, which break reproducibility when someone copies a link during a launch thread.

### Assignment

The **Release captain** opens **one** tracking issue (or equivalent single surface) for the launch run and keeps a **Roster** table for **this run only** — typical columns: **Role**, **Person / handle (off-repo)**, **Notes**. Checklist rows below reference **roles** (for example **Comms DRI**, **Security / evidence reviewer**); assign real people in the roster, not inline `@github-handle` strings in `MAINTAINING.md` (staleness and accidental pings under load).

### Ship (artifact truth)

| Step | Owner | What to verify |
|------|-------|----------------|
| Default ship path | Release captain | Follow [Release automation (default)](#release-automation-default) end-to-end; use [Manual release checklist (emergency or pre-automation)](#manual-release-checklist-emergency-or-pre-automation) only if you are outside Release Please. |
| Installer + merge gate | Security / evidence reviewer | Confirm [Installer golden CI contract (phase 50)](#installer-golden-ci-contract-phase-50) expectations; verify the 5 live required checks in [ruleset 14941512](https://api.github.com/repos/szTheory/sigra/rulesets/14941512) (`gh api repos/szTheory/sigra/rulesets/14941512`) are present — see [Branch protection — enforced required checks (live ruleset)](#branch-protection--enforced-required-checks-live-ruleset). |
| GA matrix honesty | Security / evidence reviewer | Read Executed vs Waived in [v1.4 GA / UAT matrix (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/v1.4-GA-UAT.md) — human **GA-02..GA-05** rows may remain **waived** for v1.4; do **not** imply those humans re-ran for a forum post. |
| Milestone closure narrative | Security / evidence reviewer | [v1.4 milestone requirements (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/milestones/v1.4-REQUIREMENTS.md) for what “closed” meant for that cut. |
| CI substitution semantics | Security / evidence reviewer | Packaged doc: [docs/uat-ci-coverage.md](docs/uat-ci-coverage.md). |
| Integrator-facing GA hub | Comms DRI (see roster) | Packaged doc: [docs/ga-evidence.md](docs/ga-evidence.md); repo entry point [README.md](README.md) (see **Production readiness & GA evidence** there) — link only, do not paste matrix bodies into launch threads. |

### Announce (attention budget — optional by default)

These rows widen concurrent skeptics; treat every channel below as **optional** unless the roster explicitly commits bandwidth. Prefer accurate **CHANGELOG** + upgrade notes + links to **Ship** evidence over performative hype.

| Channel | Owner | Notes |
|---------|-------|-------|
| Elixir Forum | Comms DRI | **Optional** — shorter factual thread beats a manifesto; link **Ship** artifacts instead of re-stating them. |
| Slack / Discord | Comms DRI | **Optional** — good for existing communities; avoid implying universal GA pass for consumer deployments. |
| Blog or long-form | Comms DRI | **Optional** — skip if a tight forum post plus docs is enough. |
| HN or similar | Comms DRI | **Optional** — only if you can reserve careful, non-heated reply time. |
| Short social posts | Comms DRI | **Optional** — one-line pointers to Hex + docs beat slogan contests. |

**Do not** in public copy: security-theater phrasing, comparative trash-talk of other libraries, implied warranty or “we certify your deployment,” or getting drawn into heated realtime debate — precision over slogans.

## Manual release checklist (emergency or pre-automation)

Use only when not using the Release PR flow. Adjust version strings to match `mix.exs`.

1. Confirm `mix.exs` `@version` matches the release you intend to ship.
2. Update `CHANGELOG.md` with everything notable since the last tag.
3. Run the library test suite against Postgres (same bar as CI):

   ```bash
   PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
   ```

4. Ensure `git status` is clean (or only contains intentional release files).
5. Commit the version bump and changelog if they are not already on the release branch.
6. Create an annotated or lightweight tag after the version bump lands:

   ```bash
   git tag v0.2.0
   ```

   (Replace `0.2.0` with the actual `@version`.)

7. Push the tag (and branch, if applicable):

   ```bash
   git push origin main
   git push origin v0.2.0
   ```

8. Publish to Hex from a trusted machine with `HEX_API_KEY` configured, or run **Actions → Hex publish (manual recovery)**. Non-interactive automation should use `mix hex.publish --yes` as documented in [Hex publish](https://hex.pm/docs/publish).

9. Open **GitHub → Releases** if you still need a release entry not created by Release Please.
10. Verify the [Hex version badge](https://hex.pm/packages/sigra) reflects the new version and that [HexDocs](https://hexdocs.pm/sigra) `source_ref` matches the tag you published (`mix.exs` `docs/0` uses `source_ref: "v#{@version}"`).
11. After publish, smoke-check a fresh `mix deps.get` consumer app or the example app pinned to the new requirement range.

## Semver for Sigra (pre-1.0)

This section is historical pre-1.0 policy. For the selected major release decision, follow [Sigra 1.0 release path](#sigra-132-release-path).

Hex and Mix treat `0.x` minors as potentially breaking. Use **`0.y.z` patches** only for doc-only fixes, internal-only changes, or releases that do **not** add new **supported public** `lib/` API since the last published version.

Use a **`0.y` minor bump** when you ship **new supported public** modules or functions on Hex since the last publish. In particular: if the last Hex publish was **`0.1.0`** without `Sigra.Audit.Assertions`, a release that includes that module (or any comparable new supported public `lib/` surface) must be at least **`0.2.0`**. Do **not** jump to **`1.0.0`** unless the project explicitly decides to declare API stability with coordinated messaging.

Atomic release hygiene: keep **`mix.exs` `@version`**, **`CHANGELOG.md`**, the **`v<version>`** tag, Hex publish, and the GitHub Release aligned in one tight commit series (or a documented sequence), not scattered across unrelated merges.

## OptionalDeps single source of truth (Phase 137)

`lib/sigra/optional_deps.ex` (`Sigra.OptionalDeps`) is the canonical module for runtime optional-dep checks. All runtime optional-dep guards delegate to it via per-dep `available?/0` predicates. To add or audit an optional dependency, edit `lib/sigra/optional_deps.ex` — do not scatter new `Code.ensure_loaded?` guards across call sites.

The "single source of truth" claim applies to **runtime guards only**. The narrow documented exceptions that are out of scope: compile-time `defmodule` wrappers that must resolve at compile time, dynamic host-schema atom checks, boot-warning `cond` blocks, and the doctor task's dynamic-forwarder check. These are not Phase 137 gaps; they are inherent to their respective roles and are not convertible to runtime delegates.

## Recipe-contract fixture (Phase 139)

`test/sigra/recipes/companion_lib_contract_test.exs` is a **maintainer-internal** merge-blocking drift guard, NOT a Hex-facing recipe or adopter-facing test. It is a CI contract assertion that runs in the standard `mix test` suite.

Every companion-lib recipe under `guides/recipes/companion-libs/` must carry five required markers: a `## Failure modes` section, a `## Non-goals` section, a "Sigra works fully standalone" banner, `validated_against:` frontmatter, and `last_validated:` frontmatter. The fixture asserts that all six recipes carry all five markers and will fail the test suite if any marker drifts or a new recipe is added without them.

## Deprecation removal timeline

Two live deprecated functions have committed removal schedules:

- **`Sigra.MFA.Trust.cookie_opts/0`** — already raises at runtime (no-return stub). The raising stub will be deleted entirely in `0.4.0`. Migration: use `cookie_opts/1` with `%Sigra.Config{}` so `cookie_domain` is honored.
- **`Sigra.Account.audit_forced_password_change/2`** — still works (soft-deprecated). Removed in `0.5.0`. Migration: use `clear_password_change_requirement/3` when `:audit_schema` is configured.

Removal process: each removal-target version will carry a CHANGELOG entry and the function body will be deleted (not just the annotation). Removal targets are expressed as Hex SemVer `0.x` minors, consistent with the pre-1.0 policy above.

### Dual version axes — why HexDocs renders "since 0.9.0 / removal 0.5.0" (intentional)

Sigra carries **two coexisting version axes**, and a deprecated function's rendered HexDocs header can therefore show a removal target *numerically lower* than its `@doc since:` value. This is a known, accepted convention — not a bug:

- **Hex-published SemVer axis** — what `mix.exs` `@version` tracks (currently `0.x`). **Removal targets** (`0.4.0`, `0.5.0`) are chosen on this axis and are correctly *future* relative to the published version.
- **Internal milestone/planning axis** — the `@doc since:` annotations across `lib/` are keyed to the milestone numbering (which runs ahead, e.g. `0.6.0`, `0.9.0`, up to `0.11.0`), **not** the Hex release axis.

Because the two axes share a `0.x` shape, ExDoc renders both numbers in one header (`cookie_opts/0`: since 0.6.0, removal 0.4.0; `audit_forced_password_change/2`: since 0.9.0, removal 0.5.0), producing an apparent inversion. The **removal targets are authoritative and correct** (Hex axis); the `since:` values are milestone-axis labels. Fully reconciling this would mean re-keying every `@doc since:` in the library onto the Hex SemVer axis — a deliberate, separate, library-wide change tracked in `.planning/todos/pending/2026-05-29-deprecation-since-vs-removal-version-axis.md`, not a milestone-close edit. Until that lands, read "removal in X" as the Hex-axis commitment and treat `since:` as informational. (Cosmetic: ExDoc also appends a trailing period, rendering `0.5.0..` / `0.4.0..` — harmless.)

## Planning hygiene (without gsd-tools JSON)

Reliance on **`gsd-tools audit-open --json`** is **deprecated** for this repository. The upstream helper has been unreliable; Sigra maintainers should use **grep-driven** checks over `.planning/phases/` instead.

Examples you can run from the repo root:

```bash
# Phase directories missing a *-VERIFICATION.md artifact
find .planning/phases -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  compgen -G "$dir"/*-VERIFICATION.md >/dev/null || echo "missing VERIFICATION: $dir"
done
```

```bash
# PLAN files that explicitly opt out of Nyquist compliance (spot-check)
rg -l '^nyquist_compliant: false' .planning/phases --glob '*-PLAN.md' || true
```

Optional helper (bash only, no Node): `scripts/maintainers/planning-audit-hygiene.sh`.

For full release mechanics and secret handling, see [Hex publish](https://hex.pm/docs/publish).

## Optional GitHub Environment for Hex

For extra guardrails, configure a GitHub **Environment** (e.g. **`hex`**) with **required reviewers** and attach it to the **`publish-hex`** job in **`.github/workflows/release-please.yml`** and/or **`hex-publish.yml`** so publish steps need an explicit approval. This is optional; the default workflow uses repository secrets only.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/release-please.yml` | push to **`main`**, `workflow_dispatch` | Release PR + tag + GitHub Release + **Hex publish** when a release is created |
| `.github/workflows/hex-publish.yml` | **`workflow_dispatch`** only | **Manual recovery** publish from a chosen tag/SHA + version string |

Configure **`HEX_API_KEY`** (and optionally **`RELEASE_PLEASE_TOKEN`**) under **Settings → Secrets and variables → Actions**. Never add those secrets to `ci.yml` or unrelated jobs.
