# Stack Research

**Domain:** Repository/release hygiene tooling for a mature, shipped Elixir/Phoenix Hex library (Sigra v1.5.0) — milestone **v1.48 CLEAN-BASELINE**
**Researched:** 2026-09-15
**Confidence:** HIGH (every version, API field and mechanic below was verified live against hex.pm, the GitHub API for `szTheory/sigra`, npm, and upstream source at HEAD — not from memory)

---

## Headline: the two findings that change the milestone's shape

Read these before the tables. Both contradict assumptions currently written into `PROJECT.md`.

### 1. `mix hex.retire` is **not** inherently interactive — this repo can already script it

`PROJECT.md` scopes the retire as a *"Human-gated operator step (inherent — Hex write-auth prompts interactively)"*. That is false for this repo.

- `Mix.Tasks.Hex.Retire` calls `Hex.API.Release.retire/5`, which goes through `Hex.Auth.with_api(:write, …)` — the **same** `:write` auth path as `Hex.API.Release.publish/5` (verified in `hexpm/hex@main`, `lib/hex/api/release.ex`).
- `HEX_API_KEY` satisfies that `:write` path without any prompt. This is exactly how `.github/workflows/hex-publish.yml:180-187` already publishes: `env: HEX_API_KEY: ${{ secrets.HEX_API_KEY }}` + `mix hex.publish --yes`.
- Therefore the repository **already holds an `api:write` Hex key as an Actions secret**. `mix hex.retire sigra 1.20.0 invalid --message "…"` runs unattended under that same secret.

The retire can be a `workflow_dispatch` job (operator-gated by *dispatch*, not by a TTY). Gate it on human intent if desired — but do not scope it as un-automatable, and do not plan a runbook that assumes a password prompt.

### 2. Retiring 1.20.0 will **not** fix `{:sigra, "~> 1.0"}` resolution, and will **not** move `latest_stable_version`

This is the load-bearing correction. Verified against both upstream sources at HEAD:

- **`latest_stable_version` ignores retirement.** `hexpm/hexpm@main`, `lib/hexpm/repository/release.ex:189-213` — `latest_version/2` filters only on `to_version(&1).pre == []` (pre-release) and optionally `has_docs`. There is no retirement filter. `lib/hexpm_web/views/api/package_view.ex:19-32` feeds that straight into the API field. **`latest_stable_version` will stay `1.20.0` after the retire.**
- **The resolver still selects retired versions.** `hexpm/hex@main`, `lib/hex/registry/server.ex:236-251` (`{:versions, …}`) returns every version with no retirement filter; `lib/hex/solver/package_lister.ex` sorts by `Version.prioritize/2` with no retirement awareness. Retirement is consumed *after* resolution, in `lib/hex/remote_converger.ex:556-604`, purely to print a yellow `RETIRED!` tag and a message.
- The only mechanism that actually *excludes* a version is `Hex.Policy` (Hex 2.5), and `lib/hex/policy.ex:56-63` explicitly rejects the bare `hexpm` repo — policies are `hexpm:<org>`-scoped. **Not available to a public package.**
- **Deleting 1.20.0 is impossible without hex.pm staff.** `hexpm/hexpm@main`, `lib/hexpm/repository/release.ex:155-160`: `"can only delete a release up to one hour after publication"`. `1.20.0` was inserted `2026-04-28T22:44:04Z`.

**Live API state confirming all of the above** (`curl https://hex.pm/api/packages/sigra`, 2026-09-15):

```json
{ "latest_version": "1.20.0", "latest_stable_version": "1.20.0", "retirements": {} }
```

**What the retire *does* buy, and it is worth doing:** the `retirements` map becomes `{"1.20.0": {"reason": "invalid", "message": "…"}}`, the package page shows a retired badge, every adopter's `mix deps.get` prints `sigra 1.20.0 RETIRED! …`, and Hex emits a SARIF finding (`HEX0002 / RetiredPackageInvalid`, `lib/hex/sarif.ex:26`) for supply-chain scanners. That is a real, verifiable honesty improvement — it is just **not** a resolution fix.

**Implication for the roadmap:** the milestone's stated success criterion *"a real `{:sigra, "~> 1.0"}` adopter-resolution proof"* cannot be satisfied by the retire. The planner must pick one of three, explicitly:
1. **Retire + keep the pinned install lines** (`{:sigra, "~> 1.5"}`), and re-scope the proof to "`~> 1.5` resolves to 1.5.x and `~> 1.0` warns RETIRED". Cheapest, honest, no new machinery.
2. **Retire + publish past the phantom** — cut the pending release as `1.21.0` instead of `1.5.1`, permanently reclaiming `latest_stable_version` and `~> 1.0`. Costs a discontinuity in the `1.0.0…1.5.0` series and a release-please `.release-please-manifest.json` override.
3. **Retire + open a hex.pm support request** to delete `1.20.0`. Unbounded latency, outside CI. Do not make the milestone depend on it.

The **resolution-proof harness itself needs no new tooling**: the existing `upgrade_smoke` job (`ci.yml:796`) already scaffolds a host against published Sigra. A `mix.exs` with the target requirement + `mix deps.get` + assert on the locked version in `mix.lock` is the whole proof.

---

## Recommended Stack

Nothing below adds a runtime dependency to `lib/`. `mix.exs` `deps/0` is untouched by this milestone.

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **git** (plain) | any | Delete 28 `v1.NN` planning tags, 11 `phase-238-*` proof tags, 1 `archive/*` tag — local + remote | A one-shot `git tag -d` / `git push --delete origin` loop. **No tooling needed.** Verified tag census: 28 match `^v[0-9]+\.[0-9]+$`, 12 match `^v[0-9]+\.[0-9]+\.[0-9]+$` (**keep all 12** — `mix.exs` `source_ref: "v#{@version}"` makes HexDocs "View source" 404 without them), 11 `phase-238-*`, 1 `archive/local-main-pre-235-recovery`. The 2-part/3-part split is a clean discriminator: `v1.5` (planning) vs `v1.5.0` (release) |
| **GitHub repository ruleset**, `target: "tag"`, rule `tag_name_pattern` | GitHub REST `/repos/{o}/{r}/rulesets` (GA) | Structurally reject any future non-SemVer `v*` tag push | **Server-side rejection at push time**, which a CI job structurally cannot do — a workflow guard runs *after* the tag already exists on the remote, which is precisely the ADR-003 footgun. Rulesets are free on public repos; `szTheory/sigra` is public. Metadata rules support **RE2** regex via `operator: "regex"`. Repo already runs ruleset `14941512` (`target: "branch"`, `~DEFAULT_BRANCH`) so the pattern and the `gh api` idiom are established |
| **`mix hex.retire` via `HEX_API_KEY`** | Hex **2.5.1** (installed locally; `2.5.2-dev` on main) | Retire `sigra 1.20.0` | Same `:write` auth path as the already-working `mix hex.publish --yes`. `--message` is **mandatory** (`Mix.raise("Missing required flag --message")`), max 140 chars. Reversible via `mix hex.retire sigra 1.20.0 --unretire` |
| **`node --test` + `scripts/ci/prohibitions/*.test.mjs`** | Node 20 (pinned in `ci.yml:407,1439`) | Planning-artifact leakage guard over `lib/` + `priv/templates/` | **Extend the existing harness — do not add a Credo check.** See the decision note below |
| **`@playwright/test`** | **1.62.1** (take open Dependabot PR #213), or 1.63.0 (latest, released 2026-09-04). Currently locked **1.59.1** | Root-cause the `Generated admin Playwright smoke` flake | 1.62 adds **isolated retries** (`retries: {mode: 'isolated'}`) — reruns retries serially in a single worker at the end of the run, which *discriminates* a parallelism/shared-state flake from a genuine one instead of papering over it. 1.62 also adds `Reporter.preprocess()` and a `perfetto` reporter. 1.63 adds aria/screen snapshots in traces |
| **GitHub Pages REST API** (`PUT /repos/{o}/{r}/pages`) | GA | Stop the always-red `pages build and deployment` | **One `gh api` call.** Root cause confirmed live: `{"status":"errored","build_type":"legacy","source":{"branch":"main","path":"/"}}` — the legacy Jekyll builder is pointed at `main`, so it re-runs (and fails) on every push. The correct target is `gh-pages` `/` |
| **`dependabot/fetch-metadata`** | **v3.1.0** (2026-04-20) — *not* the v2 that most blog posts show | Classify Dependabot PR update-type for conditional auto-merge | Only needed if auto-merge is wanted as *standing policy*. For draining the existing 11 PRs, `gh pr merge --auto --squash` alone is sufficient — `allow_auto_merge: true` and `allow_squash_merge: true` are already set on the repo |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `credo` | `~> 1.7` (1.7.19 pending in PR #183) | Elixir static analysis | Already a dep. Do **not** grow it for this milestone — see "What NOT to Use" |
| `ex_doc` | `~> 0.40` | HexDocs build | Already a dep. The leakage cleanup is judged by `mix docs` output; no config change needed |
| `cheerio` | `^1.2.0` | HTML assertions in existing self-tests | Already in `test/example/priv/playwright/package.json`; `fast_checks` already `npm ci`s it (`ci.yml`, "Install Playwright subproject deps") |
| `jq` | preinstalled on `ubuntu-latest` | JSON in the Pages/ruleset shell steps | Already a hard requirement of `scripts/ci/ensure-github-pages-legacy-branch.sh` |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `gh` CLI | Ruleset creation, Pages reconfiguration, PR draining, tag deletion | Already the repo's idiom (`scripts/ci/ensure-github-pages-legacy-branch.sh` uses `gh api` exclusively) |
| `mix ci` alias | Local mirror of the PR-fast gate | Add nothing here. The leakage guard belongs in `fast_checks`' `node --test` step, not in `mix ci` — `mix ci` is a **single-owner topology** guarded by `test/sigra/planning/phase_233_library_economics_contract_test.exs`; touching it re-opens v1.47's TEST-01/02 wound |
| `npx playwright test --repeat-each=N --workers=1 --retries=0` | Local flake reproduction | The standard flake-hunting invocation. Pair with `--last-failed` (1.44+) |
| `npx playwright show-trace` | Post-mortem of a CI flake | `playwright.config.ts:81` already sets `trace: 'on-first-retry'`, and the smoke job already sets `PLAYWRIGHT_RETRIES: 1` (`ci.yml:1460`) — **traces for the flaky runs already exist as artifacts**. Harvest them before adding instrumentation |
| `--fail-on-flaky-tests` (1.49+) | Make a recovered-on-retry run red | Use *temporarily*, during diagnosis, to force the flake to surface. Do **not** land it as steady state while `PLAYWRIGHT_RETRIES: 1` is in place |

---

## Installation

Nothing is installed. Every item is a configuration change, a `gh`/`git` invocation, or an existing dependency.

```bash
# 1. Tag namespace — plain git, no tooling
git tag -l | grep -E '^v[0-9]+\.[0-9]+$'            # the 28 planning tags (2-part)
git tag -l 'phase-238-*'                             # the 11 proof tags
# delete local + remote (batch the remote push; 40 refs in one call)
git tag -l | grep -E '^v[0-9]+\.[0-9]+$|^phase-238-' | xargs -n50 git tag -d
git tag -l ...                                       # (capture list BEFORE deleting, then:)
git push --delete origin <refs...>

# 2. Structural guard — GitHub tag ruleset (RE2)
gh api repos/szTheory/sigra/rulesets --method POST --input - <<'JSON'
{
  "name": "semver-release-tags-only",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [
    { "type": "tag_name_pattern",
      "parameters": { "name": "SemVer release tags only",
                      "operator": "regex",
                      "negate": false,
                      "pattern": "^v[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" } }
  ]
}
JSON

# 3. Hex retire — non-interactive, under the EXISTING HEX_API_KEY secret
HEX_API_KEY=*** mix hex.retire sigra 1.20.0 invalid \
  --message "Published in error; not a real Sigra release. Use ~> 1.5."
# verify (see Verification Contract below)
curl -s https://hex.pm/api/packages/sigra | jq '.retirements'

# 4. Leakage guard — extend the EXISTING harness, zero new deps
#    new file: scripts/ci/prohibitions/p17-no-planning-bookkeeping-in-shipped.test.mjs
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs

# 5. GitHub Pages — one call; the repo's own script already encodes this policy
gh api repos/szTheory/sigra/pages --method PUT --input - <<'JSON'
{ "build_type": "legacy", "source": { "branch": "gh-pages", "path": "/" } }
JSON

# 6. Dependabot drain — no tooling; auto-merge is already enabled on the repo
gh pr merge 183 --auto --squash   # ... per PR, once ci-gate is trustworthy
```

---

## Per-area decisions, with the rationale a planner needs

### Area 1 — Tag namespace hygiene

**Tool: plain `git` + one GitHub tag ruleset. No CI job.**

Why a ruleset over a `fast_checks` guard: a workflow guard fires on `push: tags:` *after* the ref is created on the remote. Every planning tag in the current mess would still have landed, and the operator would then be doing the same cleanup with extra steps. A `tag_name_pattern` ruleset causes `git push origin v1.49` to be **rejected by the server**. That is what "structurally closing ADR-003" means.

Hard requirements the planner must encode:
- Scope `conditions.ref_name.include` to `refs/tags/v*` only. A `~ALL` scope would break `archive/*`-style tags and anything release-please or a future lane creates outside the `v` namespace.
- `bypass_actors: []`. A bypass for repo admins re-creates the footgun, since the operator *is* the admin who cut `v1.47`/`v1.48`.
- **Keep all 12 three-part tags.** `mix.exs:docs/0` sets `source_ref: "v#{@version}"`; deleting `v1.5.0` 404s every "View source" link on hexdocs.pm/sigra.
- Add a `fast_checks` *contract* test (`test/sigra/planning/…` or a `p17`-style guard) asserting the ruleset exists — not as the enforcement mechanism, but so that silently deleting the ruleset in Settings is caught. The `REQUIRED_CONTEXTS` constant in `scripts/ci/prohibitions/_lib.mjs` is the precedent for pinning GitHub-side config from the repo.

### Area 2 — Hex release hygiene

**Tool: `mix hex.retire` under the existing `HEX_API_KEY` secret. Hex 2.5.1.**

Mechanics, all verified at source HEAD:
- Syntax: `mix hex.retire PACKAGE VERSION REASON --message "…"`. Reasons: `renamed | deprecated | security | invalid | other`. `--message` is **required** (task raises otherwise), ≤140 chars.
- Auth: `Hex.Auth.with_api(:write, …)` → satisfied by `HEX_API_KEY`. No prompt, no local-password decryption.
- Reversible: `mix hex.retire sigra 1.20.0 --unretire`.

**Verification contract** (make this a scripted post-condition, mirroring `hex-publish.yml`'s existing "Verify version on Hex.pm" polling step):

| Check | Endpoint / field | Expected after retire |
|---|---|---|
| Retirement recorded | `GET /api/packages/sigra` → `.retirements["1.20.0"]` | `{"reason":"invalid","message":"…"}` (currently `{}`) |
| Release-level record | `GET /api/packages/sigra/releases/1.20.0` → `.retirement` | non-null |
| Latest pointer | `.latest_stable_version` | **still `1.20.0`** — assert this *explicitly* so the milestone cannot claim a resolution fix it did not make |
| Adopter behaviour | `mix deps.get` in a scratch host with `{:sigra, "~> 1.0"}` | resolves **1.20.0**, prints `RETIRED!` + message |
| Adopter behaviour | same, with `{:sigra, "~> 1.5"}` | resolves 1.5.x cleanly |

Do **not** plan a `hex.pm` release deletion as an in-milestone step; the one-hour window closed on 2026-04-28.

### Area 3 — Planning-artifact leakage guard

**Tool: a new `scripts/ci/prohibitions/p17-*.test.mjs`. Not a Credo check.**

The repo *does* already write custom Credo checks (`lib/sigra/credo/no_log_safe2_in_lib.ex`, `no_unscoped_org_query_in_lib.ex`, wired via `.credo.exs` `requires:` + `checks.extra`), so this was a genuine fork. Reject Credo here for four concrete reasons:

1. **Credo cannot see `priv/templates/`.** `.credo.exs` `files.included` is `["lib/", "test/"]`, and Credo's source analysis is AST-based over Elixir source. The `.heex`, `.js`, `.css`, `.md` and `.exs` migration templates under `priv/templates/sigra.install/` — the surface that *ships into every adopter's project* — are structurally out of reach. One of the five dead `.planning/` paths (`priv/templates/sigra.install/organizations/organizations.ex:59`) lives exactly there.
2. **The violations are in `@moduledoc` prose and comments**, not code. Three of the five are doc-string content (`lib/sigra/audit.ex:5`, `lib/sigra/testing.ex:1274`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex:11,13`). A text/regex guard is the honest instrument; a Credo AST check would be doing string matching inside an AST traversal for no benefit.
3. **Wrong gate.** Credo is not in the `mix ci` alias (`format / deps.get / deps.unlock / compile / test / ci.install_golden / sigra.dep_off`). Adding a Credo check means also wiring Credo into the required lane — a `mix ci` topology change, which is exactly what `phase_233_library_economics_contract_test.exs` guards and what v1.47's TEST-01/02 debt is about. Don't reopen it.
4. **The prohibition harness is purpose-built for this.** `_lib.mjs` gives `subjectPath()` / `GSD_PROHIB_SUBJECT` fail-first injection, `readRepoFile`, and comment stripping; GSD's `check prohibition-enforcement` proves each guard red-against-a-bad-fixture and green-against-clean before accepting it. It already runs in `fast_checks` via `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (`ci.yml`, step "Phase 230 prohibition guards"), so wiring cost is **zero** — drop the file in the directory.

Design requirements for `p17`, following the house idiom:
- Walk `lib/**` and `priv/templates/**` over **all** file extensions, not just `.ex`.
- Two severity tiers. **Hard-fail:** any `.planning/` path (currently 5, all dead links). **Tiered:** `Phase \d{1,3}`, `D-\d{2}`, `\d{3}-\d{2}` — currently **771 matches**, so a blanket hard-fail is unshippable as a first move. Either (a) land an allowlist/baseline snapshot and ratchet, or (b) hard-fail only on `priv/templates/` + the `@moduledoc`/`@doc` ranges that render on HexDocs, and warn elsewhere.
- **Non-vacuity floor** — mandatory in this harness. A grep that matches nothing must throw, not pass. See `_lib.mjs`'s "the parse broke, this is not a pass" convention and `p14`'s `assert.ok(occurrences.length >= 2, …)` negative control.
- **Negative control** — assert that genuine design-rationale comments survive, so a future "fix" that guts the moduledocs does not read as green.
- **Complements, does not replace,** `hex-publish.yml`'s existing packaged-artifact check (`if [ -e sigra-hex-inspect/.planning ]`). That is directory-presence at release time; `p17` is content-level on every PR.

### Area 4 — Playwright flake root-causing

**Tool: Playwright 1.62.1 (+ artifacts you already have). No new library.**

Current state: `@playwright/test` locked at **1.59.1**; latest **1.63.0**; Dependabot PR **#213** already proposes 1.59.1 → 1.62.1. `playwright.config.ts` sets `retries: 0`, `trace: 'on-first-retry'`, `reporter: [['list'], ['html', {open: 'never'}]]`. `generated_admin_playwright_smoke` (`ci.yml:1401`) runs on **every** event with `PLAYWRIGHT_RETRIES: 1`.

Diagnosis order — cheapest first, and the first two need **nothing new**:
1. **Harvest the traces that already exist.** `trace: 'on-first-retry'` + `PLAYWRIGHT_RETRIES: 1` means every intermittent red already produced a trace zip for the failing attempt. `npx playwright show-trace` on the archived artifact from a known-red run is step one. Do not add instrumentation before reading what is already captured.
2. **Local repro:** `npx playwright test <spec> --repeat-each=20 --workers=1 --retries=0 --reporter=line`, then `--workers=4` to see whether parallelism is the discriminator.
3. **Take PR #213 (→1.62.1)** and use **isolated retries** (`retries: { mode: 'isolated' }`). This reruns retries serially at the end of the run in a single worker — a flake that dies under isolated retry but survives under in-place retry is a cross-test/shared-resource interference flake, which is a *diagnosis*, not a mask. 1.62 also lands `Reporter.preprocess()` (custom filtering) and a `perfetto` reporter for timing analysis; 1.63 adds **test locks** for shared-resource contention and aria/screen snapshots in traces, which are the two most likely shapes for a Postgres-backed generated-host smoke.
4. **`--fail-on-flaky-tests`** (1.49+, with `fullConfig.failOnFlakyTests` so reporters can explain the exit) — use *during* diagnosis to convert a recovered-on-retry run into a hard red. Do **not** land it as steady state alongside `PLAYWRIGHT_RETRIES: 1`; it would turn every flake into a gate red before the root cause is fixed.
5. **Blob reporter + `merge-reports`** — only if flake *rate* across shards needs measuring. The repo already shards (`example_playwright_shard`), so this is the correct aggregation primitive if a rate is needed; skip it if a single trace explains the failure.

Explicit non-goal, stated in `PROJECT.md` and worth re-stating: the fix is a **root cause**, not a retry-wrap. `PLAYWRIGHT_RETRIES: 1` is already the retry-wrap; if it stays, it must be a deliberate, recorded decision rather than the fix.

### Area 5 — GitHub Pages

**Tool: one `gh api PUT`. No new workflow, and specifically *not* `actions/configure-pages` + `actions/deploy-pages`.**

Root cause, confirmed live:

```json
GET /repos/szTheory/sigra/pages
{"status":"errored","build_type":"legacy","source":{"branch":"main","path":"/"}}
```

`build_type: legacy` + `source.branch: main` means GitHub's managed Jekyll builder runs on every push to `main` (the `pages-build-deployment` runs that appear with `event: dynamic` and `conclusion: failure`). It fails because `main` is an Elixir library repo, not a Jekyll site.

The repo **already has the correct policy encoded** in `scripts/ci/ensure-github-pages-legacy-branch.sh` — it PUTs `build_type: legacy` / `gh-pages` / `/`. It has simply never run against a *mis*configured site, because it only executes inside `playwright-github-pages.yml`'s `publish` job, which is gated on a narrow `paths:` push filter plus a daily cron. So:

- **Fix:** run the PUT once (or dispatch `playwright-github-pages.yml` manually, which calls the script).
- **Prevent recurrence:** the script is already idempotent and already skips when `build_type == "workflow"`. Consider hoisting the PUT to run *before* the site assembly rather than only after a successful `gh-pages` push, so a mis-set source self-heals even on a run whose publish step fails.
- Ensure `gh-pages` carries a `.nojekyll` file so the legacy builder serves the Playwright HTML reports verbatim (Playwright report assets live under `_`-prefixed-ish paths that Jekyll can eat).

**Do not migrate to `actions/deploy-pages` (Actions-sourced Pages).** The publisher deliberately force-pushes a single orphan commit to `gh-pages` to keep binary history bounded (documented at the top of `playwright-github-pages.yml`). Switching to `build_type: workflow` would mean re-architecting that retention model, and the existing script would then correctly refuse to touch the config — a much larger change for a bug that is one API call.

### Area 6 — Dependabot PR draining

**Tool: `gh pr merge --auto --squash`. Optionally `dependabot/fetch-metadata@v3.1.0` if standing policy is wanted.**

Verified repo state: `allow_auto_merge: true`, `allow_squash_merge: true`, `allow_merge_commit: false`, `allow_rebase_merge: false`. **11 open Dependabot PRs** (#183, #213, #215, #216, #220, #225, #226, #227, #228, #229, #230) of 18 total open.

- **For this milestone's drain:** `gh pr merge <n> --auto --squash` per PR. No workflow needed. **Precondition:** `ci-gate` must be trustworthy first — auto-merge on an intermittently-red gate either blocks forever or, worse, merges on a lane that counted a skip as a pass. Sequence Area 4 *before* Area 6.
- **Triage by risk, not by semver alone.** Three of the eleven are not mechanical: **#213** `@playwright/test` 1.59.1→1.62.1 (minor, but it is the browser harness the whole gate rests on — and it is *wanted* for Area 4, so merge it deliberately, with its own evidence); **#220** `otplib` 12.0.1→**13**.5.0 (major, touches TOTP test fixtures); **#226** `threadline` 0.7.0→0.9.0 (0.x minor = breaking by convention, and `mix.exs` carries a `hackney ~> 4.7` override comment tied specifically to Threadline's published constraint — **re-evaluate whether that override can be dropped**, which is itself a CLEAN-BASELINE win).
- **If standing auto-merge is wanted:** add `.github/workflows/dependabot-auto-merge.yml` gated on `github.actor == 'dependabot[bot]'`, using `dependabot/fetch-metadata@v3.1.0` (pinned to SHA — the repo pins every action to a full SHA with a `# vX.Y.Z` trailing comment, and `test/sigra/planning/phase_234_action_pinning_contract_test.exs` enforces it) and merging only on `version-update:semver-patch` / `semver-minor`. **Caveat:** for *grouped* updates the reported `update-type` is the **highest** semver level in the group, so grouping + auto-merge can silently widen scope. Note the repo's `.github/dependabot.yml` currently has **no `groups:` key** — three ecosystems (`github-actions` /, `mix` /, `npm` /test/example/priv/playwright), all weekly, ungrouped. Adding `groups:` would cut PR volume but must not be combined with blanket auto-merge without the highest-level caveat encoded.
- Existing contract test `test/sigra/planning/phase_234_dependabot_contract_test.exs` guards `.github/dependabot.yml` — any `groups:` addition must update it in the same change.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| GitHub tag ruleset (`tag_name_pattern`) | A `fast_checks` / `push: tags:` workflow guard | Only as a *belt-and-braces* observer. It cannot prevent the tag from existing on the remote, which is the whole defect. Acceptable as a secondary alarm if the ruleset ever gets deleted |
| GitHub tag ruleset | Classic "protected tags" (branch-protection-era tag rules) | Superseded by rulesets; no regex support, no `target: tag` metadata rules |
| `scripts/ci/prohibitions/p17-*.test.mjs` | A custom Credo check (`Sigra.Credo.NoPlanningArtifactsInLib`) | Only if the check ever needs **AST** context (e.g. "only inside `@moduledoc`"). Even then, Credo cannot reach `priv/templates/`, so it would need the mjs guard alongside it — two mechanisms for one rule |
| `scripts/ci/prohibitions/p17-*.test.mjs` | An ExUnit test under `test/sigra/planning/` | Legitimate and idiomatic here — that directory is full of `File.read!` + `Regex` contract tests. Choose it **only if** the guard does not need to satisfy a GSD `verification: test` prohibition; `_lib.mjs`'s header documents that `prohibition-enforcement` accepts only `node-test` / `lint-rule`, so an ExUnit guard would re-derive `human_needed` |
| Retire 1.20.0 + keep pinned install lines | Cut the pending release as **1.21.0** | Choose this if reclaiming `latest_stable_version` and `~> 1.0` matters more than a contiguous `1.0.0…1.5.x` series. It is the **only** in-repo action that actually fixes resolution |
| Retire 1.20.0 | Ask hex.pm support to delete the release | Worth filing in parallel; never make the milestone's exit gate depend on a third party |
| Playwright 1.62.1 (Dependabot PR #213) | Playwright 1.63.0 (latest) | Take 1.63.0 if **test locks** (shared-resource contention — plausible for a Postgres-backed generated-host smoke) turn out to be the needed primitive. Costs a hand-authored bump instead of accepting the queued PR |
| `gh api PUT /pages` → `gh-pages` | `actions/configure-pages` + `actions/deploy-pages` (`build_type: workflow`) | Only if the orphan-commit/7-day-prune retention model in `playwright-github-pages.yml` is being redesigned anyway. Out of scope here |
| `gh pr merge --auto --squash` | `dependabot/fetch-metadata@v3.1.0` auto-merge workflow | Adopt only *after* `ci-gate` is proven green across consecutive pushes, and only with the grouped-update highest-semver caveat encoded |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Any new entry in `mix.exs` `deps/0`** | Hard project constraint: minimal transitive deps; this is a hygiene milestone, not a feature milestone. Every item above is config, `gh`, `git`, or an existing dep | Nothing |
| **Changing the `mix ci` alias topology** | `test/sigra/planning/phase_233_library_economics_contract_test.exs` *requires* the current single-owner topology. Touching it re-opens v1.47's TEST-01/02 debt under a milestone whose whole point is retiring dishonest debt | Wire new guards into `fast_checks`' existing `node --test … prohibitions/*.test.mjs` step |
| **A custom Credo check for planning-artifact leakage** | Cannot see `priv/templates/` (the adopter-facing surface); Credo is not in the required gate; the violations are prose, not AST | `scripts/ci/prohibitions/p17-*.test.mjs` |
| **A CI-job-only tag guard as the sole mechanism** | Runs after the tag is already on the remote — it re-documents ADR-003 rather than closing it | Server-side tag ruleset |
| **Deleting any 3-part `vX.Y.Z` tag** | `mix.exs` `source_ref: "v#{@version}"` — every HexDocs "View source" link on every published version 404s | Delete only 2-part `v\d+\.\d+`, `phase-238-*`, and (optionally) `archive/*` |
| **`bypass_actors` on the tag ruleset** | The operator who cut `v1.47`/`v1.48` *is* the repo admin. A bypass reinstates the footgun | `bypass_actors: []` |
| **Claiming the Hex retire fixes `~> 1.0` resolution** | Verified false at both hexpm and hex source HEAD. Writing it into a SUMMARY would be exactly the dishonest-green pattern this milestone exists to remove | Assert `latest_stable_version` is *still* `1.20.0` post-retire, and pick one of the three documented options |
| **`mix hex.publish --revert` / release deletion for 1.20.0** | One-hour window; closed 2026-04-28 (`hexpm/hexpm`, `release.ex:155-160`) | Retire + (optionally) publish past it |
| **Blanket auto-merge before `ci-gate` is trustworthy** | `ci-gate` is intermittently red *and* has historically counted skips as pass. Auto-merge on that gate is the failure mode from v1.45, automated | Sequence Area 4 before Area 6 |
| **`--fail-on-flaky-tests` as steady state (yet)** | With `PLAYWRIGHT_RETRIES: 1` still set, it converts every unfixed flake into a gate red | Use temporarily during diagnosis; land it only after the root cause is fixed and retries are reconsidered |
| **`actions/*` pinned to a floating tag** | `test/sigra/planning/phase_234_action_pinning_contract_test.exs` enforces full-SHA pins with a `# vX.Y.Z` comment | Pin `dependabot/fetch-metadata` to its v3.1.0 SHA if added |
| **Migrating Pages to `build_type: workflow`** | Breaks the deliberate orphan-commit retention design; the repo's own script would then correctly refuse to manage the config | One `PUT` to `legacy` / `gh-pages` / `/` |

---

## Stack Patterns by Variant

**If the milestone commits to a real `~> 1.0` resolution fix:**
- Publish the pending release as **1.21.0**, not 1.5.1.
- Override `.release-please-manifest.json` + `version` in `mix.exs` and let release-please tag `v1.21.0`.
- Prove it in `upgrade_smoke`: scratch host with `{:sigra, "~> 1.0"}` → `mix deps.get` → assert `mix.lock` pins `1.21.0`.

**If the milestone accepts the phantom and only improves honesty (cheaper, recommended default):**
- Retire 1.20.0; keep documented install lines pinned at `{:sigra, "~> 1.5"}`.
- Re-word the requirement from "resolution proof" to "retirement-visibility proof": assert `.retirements["1.20.0"]` is populated **and** that `latest_stable_version` is knowingly still `1.20.0`.
- File the reclaim as a tracked follow-on.

**If the 771 bookkeeping matches cannot be driven to zero in one phase:**
- Hard-fail tier: the 5 `.planning/` paths + everything under `priv/templates/`.
- Ratchet tier: a committed baseline count with a monotonic-decrease guard. The repo already has this exact pattern — see `fast_checks` steps "Quality ledger monotonic guard" and "Quality findings monotonic guard", each with its own self-test.

**If the Playwright flake turns out to be Postgres/shared-state:**
- Take 1.63.0 for **test locks** rather than 1.62.1.
- Otherwise 1.62.1 (isolated retries) via Dependabot PR #213 is sufficient.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Hex 2.5.1 | Elixir 1.19.5 / OTP 28.5 (`.tool-versions`) | Verified locally: `mix hex.info` → `Hex: 2.5.1, Elixir: 1.19.5, OTP: 28.5`. `hex.retire` semantics unchanged since 0.17 |
| `@playwright/test` 1.62.1 / 1.63.0 | Node 20 (pinned in `ci.yml`) | Currently locked 1.59.1. CI installs browsers via `npx playwright install --with-deps chromium webkit`; a version bump invalidates the browser cache — the "Playwright cache key guard" step in `fast_checks` exists for exactly this and must be re-checked on bump |
| `dependabot/fetch-metadata` v3.1.0 | `actions/checkout` v7, `gh` CLI on `ubuntu-latest` | Most public examples still show **v2**; v3.1.0 (2026-04-20) is current. Must be SHA-pinned per `phase_234_action_pinning_contract_test.exs` |
| GitHub rulesets (`target: "tag"`) | Public repos, no plan requirement | `szTheory/sigra` is public. Metadata rules use **RE2** (no backreferences, no lookaround) |
| GitHub Pages `legacy` / `gh-pages` | `playwright-github-pages.yml` orphan-commit publisher | `scripts/ci/ensure-github-pages-legacy-branch.sh` already encodes this and self-skips when `build_type == "workflow"` |
| `node --test` (Node 20) | `scripts/ci/prohibitions/*.test.mjs` | Existing invocation: `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` in `fast_checks`. A new `p17` file is picked up by the glob with no workflow edit |
| `threadline` 0.9.0 (PR #226) | `mix.exs` `hackney ~> 4.7` dev/test override | The override comment says to remove it *"once Threadline's published constraint accepts Hackney 4"* — verify against 0.9.0 before merging; dropping it is a CLEAN-BASELINE win |

---

## Integration Points (for the planner — exact anchors)

| Change | Exact location | Cost |
|---|---|---|
| Leakage guard | new `scripts/ci/prohibitions/p17-no-planning-bookkeeping-in-shipped.test.mjs`; picked up by the existing `ci.yml` `fast_checks` step **"Phase 230 prohibition guards"** (`node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`) | **Zero workflow edits** |
| Ruleset-exists contract | new guard or `test/sigra/planning/…`; follow `_lib.mjs`'s `REQUIRED_CONTEXTS` precedent for pinning GitHub-side config | 1 file |
| Hex retire | new `workflow_dispatch` job (or a step in `hex-publish.yml`) using `secrets.HEX_API_KEY`; mirror the existing **"Verify version on Hex.pm"** polling step for the post-condition | 1 job |
| Pages fix | one `gh api PUT`; optionally hoist the `ensure-github-pages-legacy-branch.sh` call earlier in `playwright-github-pages.yml`'s `publish` job | 1 call + ≤1 line |
| Playwright bump | merge PR **#213**; re-check `fast_checks` **"Playwright cache key guard"**; config change in `test/example/priv/playwright/playwright.config.ts` (`retries: {mode: 'isolated'}`) | 1 PR + 1 config line |
| Dependabot | `gh pr merge --auto --squash` per PR; if `groups:` is added to `.github/dependabot.yml`, update `test/sigra/planning/phase_234_dependabot_contract_test.exs` in the same change | 0–2 files |
| Tag cleanup | plain `git`; no repo files change | 0 files |

**Jobs that must NOT be touched:** `library_tests` (name is byte-identical to required context in ruleset 14941512 — `ci.yml:567` says DO NOT EDIT), and the other four `REQUIRED_CONTEXTS` names in `_lib.mjs`.

---

## Sources

- `https://hex.pm/api/packages/sigra` — live, 2026-09-15: `latest_stable_version: "1.20.0"`, `retirements: {}`, 13 releases (HIGH, verified)
- `hexpm/hexpm@main`, `lib/hexpm/repository/release.ex:155-160, 187-225`; `lib/hexpm_web/views/api/package_view.ex:19-32` — `latest_stable_version` ignores retirement; 1-hour delete window (HIGH, source at HEAD)
- `hexpm/hex@main`, `lib/mix/tasks/hex.retire.ex`; `lib/hex/api/release.ex:41-61`; `lib/hex/remote_converger.ex:556-612`; `lib/hex/registry/server.ex:236-251`; `lib/hex/solver/package_lister.ex`; `lib/hex/policy.ex:56-63`; `lib/hex/sarif.ex:24-34` — retire auth path, retirement is warn-only in resolution, policies are org-scoped (HIGH, source at HEAD)
- `https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html` — Hex v2.5.1 docs: syntax, five reasons, required `--message` ≤140 chars, `--organization`, `--unretire` (HIGH)
- `https://hex.pm/docs/publish` + `hexpm/hex` issue #547 / v0.18.0 release notes — `HEX_API_KEY` exists precisely to avoid `mix hex.user auth` prompts; `--yes` for CI; `mix hex.user key generate --permission api:write` (HIGH)
- Local `mix hex.info` — Hex 2.5.1 / Elixir 1.19.5 / OTP 28.5 (HIGH, verified)
- `https://registry.npmjs.org/@playwright/test` — latest **1.63.0**, published 2026-09-04; 1.59.0…1.63.0 series (HIGH, verified)
- `https://playwright.dev/docs/release-notes` — 1.62 isolated retries + `Reporter.preprocess()` + perfetto reporter; 1.63 test locks + aria/screen snapshots in traces; 1.49 `--fail-on-flaky-tests` + `fullConfig.failOnFlakyTests`; 1.44 `--last-failed`; 1.42+ blob reporter (HIGH)
- `GET /repos/szTheory/sigra/pages` — live: `{"status":"errored","build_type":"legacy","source":{"branch":"main","path":"/"}}` (HIGH, verified)
- `https://docs.github.com/en/rest/pages/pages` — `PUT /repos/{o}/{r}/pages`: `build_type` legacy|workflow, `source.branch`, `source.path` (`/` or `/docs`), admin/maintainer or Pages-settings permission (HIGH)
- `https://docs.github.com/en/rest/repos/rules` + rulesets docs — metadata restrictions accept **RE2** regex when "Must match a given regex pattern" is selected; `target: tag` supported (MEDIUM-HIGH — rule shape corroborated against the live shape of ruleset 14941512)
- `GET /repos/szTheory/sigra/rulesets/14941512` — live JSON shape for `name`/`target`/`enforcement`/`conditions.ref_name`/`bypass_actors`/`rules[].type` (HIGH, verified)
- `GET /repos/dependabot/fetch-metadata/releases/latest` — **v3.1.0**, 2026-04-20 (HIGH, verified)
- `GET /repos/szTheory/sigra` — `allow_auto_merge: true`, `allow_squash_merge: true`, merge/rebase disabled (HIGH, verified)
- `gh pr list` — 18 open PRs, 11 from Dependabot: #183, #213, #215, #216, #220, #225, #226, #227, #228, #229, #230 (HIGH, verified)
- Repo, local: `git tag -l` census (28× `^v\d+\.\d+$`, 12× `^v\d+\.\d+\.\d+$`, 11× `phase-238-*`, 1× `archive/*`); `grep -rn '\.planning/' lib priv/templates` → 5 hits; bookkeeping-token grep → 771 hits; `mix.exs`; `.credo.exs`; `.github/dependabot.yml`; `.github/workflows/{ci,hex-publish,playwright-github-pages}.yml`; `scripts/ci/prohibitions/{_lib.mjs,p14-*.test.mjs}`; `scripts/ci/ensure-github-pages-legacy-branch.sh`; `test/example/priv/playwright/{package.json,package-lock.json,playwright.config.ts}`; `.tool-versions` (HIGH, verified)
- Dependabot auto-merge patterns (`dependabot/fetch-metadata` + `gh pr merge --auto`), incl. the grouped-update "highest semver level wins" caveat — community write-ups, corroborated across several independent sources (MEDIUM)

---
*Stack research for: repository/release hygiene tooling, Sigra v1.48 CLEAN-BASELINE*
*Researched: 2026-09-15*
