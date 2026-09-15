# Feature Research — v1.48 CLEAN-BASELINE

**Domain:** Baseline hygiene / release-readiness posture for a public Elixir Hex library
**Researched:** 2026-09-15
**Confidence:** HIGH (Hex/hexpm behavior verified against upstream source + live API; conventions verified against six major Elixir libraries)

> **"Features" here are maintenance properties, not product capabilities.** The unit of
> delivery is *"the repo/package now has property X, proven by evidence Y."* Every row below
> is phrased so the roadmapper can turn it into a requirement with a falsifiable check.

---

## ⚠️ Three findings that change scope before anything else is planned

These were verified this session and **invalidate or redirect parts of the stated milestone
intent**. Read these before the tables.

### F1 — `mix hex.retire` does NOT fix `latest_stable_version`, and does NOT fix `~> 1.0` resolution

Verified against upstream source:

- `hexpm/hexpm` `lib/hexpm/repository/release.ex:189 latest_version/2` filters candidates on
  **prerelease** and **`has_docs`** only. Retirement is not a filter. `package_view.ex:20`
  computes `latest_stable_version` straight from that function. **Retiring `1.20.0` will not
  change `latest_stable_version`; it will still read `1.20.0`.**
- `hexpm/hex` `lib/hex/solver.ex` contains **zero** references to retirement. Retirement
  filtering lives exclusively in `lib/hex/policy/filter.ex` — i.e. it applies **only** when an
  organization has configured a Hex *dependency policy* with a retirement rule and the project
  opted into it. The default resolver **resolves retired versions normally** and merely prints
  a warning (`remote_converger.ex:11` `print_retired_warning`).
- Live check, 2026-09-15: `GET https://hex.pm/api/packages/sigra` →
  `latest_version: 1.20.0`, `latest_stable_version: 1.20.0`, `retirements: {}`.

**Consequence for the roadmap:** the stated requirement *"retire the stray Hex 1.20.0 … and a
real `{:sigra, "~> 1.0"}` adopter-resolution proof"* **cannot pass as written**. A fresh
`mix deps.get` with `{:sigra, "~> 1.0"}` will still resolve to `1.20.0` after the retire — it
will just print `Found retired packages`. The requirement must be re-scoped to what retirement
actually buys (an honest, machine-readable "do not use this" signal + a red banner on the
package page + a loud warning at `deps.get` time), and the *resolution* problem must be solved
by one of the options in **F2**.

### F2 — The only levers that actually repair `~> 1.0` resolution

| Lever | Effect on resolution | Cost | Verdict |
|---|---|---|---|
| `mix hex.retire sigra 1.20.0 invalid` | **None** by default (policy-gated only) | Interactive write-auth, reversible via `--unretire` | **Do it anyway** — it is the correct honesty signal and the documented remedy for "no longer recommend its usage". Just don't claim it fixes resolution. |
| Publish a real release **above** `1.20.0` (e.g. `1.21.0`, or `2.0.0`) | **Fixes it completely** — `~> 1.0` resolves to a real release again | Burns `1.6.0 … 1.20.0` of version space forever; a `2.0.0` implies a breaking change that didn't happen | Viable, and the only *automated* fix. Needs an explicit decision — this is a **new ADR**, not a task. |
| Keep pinned install docs (`{:sigra, "~> 1.5"}`) | Works for anyone who copies the README | Zero | **Already in place.** Adequate while there are no adopters. Should be an explicit documented decision, not an unlabelled workaround. |
| Ask hex.pm admins to unpublish out-of-window | Fixes it completely | Requires hex.pm maintainer goodwill; immutability policy says exceptions are rare (60-min / 24-hour windows) | Long-shot; worth exactly one polite issue, not a blocking dependency. |

### F3 — Unscoped and higher-impact than the retire: **HexDocs currently serves the phantom's docs**

`https://hexdocs.pm/sigra/` → 301 → `https://sigra.hexdocs.pm/` → the rendered page reports
**`v1.20.0`**. The Hex API confirms `1.20.0` has `has_docs: true`. So *every* adopter who
follows the `Documentation` link from the package page reads documentation generated from the
phantom release, not from `1.5.0`.

**Fix:** `mix hex.publish docs --revert 1.20.0`. Hex documents docs as explicitly *mutable*
("Documentation has no limitations on when it can be updated"), unlike the package tarball.
Removing `1.20.0`'s docs makes `latest_version(with_docs: true)` fall through to `1.5.0`, and
`hexdocs.pm/sigra` resolves to the real docs. This is **the single highest adopter-facing win
in the whole milestone**, it is one command, and it is currently **not in the milestone scope**.
It shares the same interactive-write-auth constraint as the retire, so it belongs in the *same*
gated operator runbook step.

---

## Feature Landscape

### Table Stakes — any respected Elixir/Hex library has these

Missing these makes the package look abandoned or untrustworthy to an evaluating adopter.

| # | Property | Why expected (evidence) | Complexity | Sigra status |
|---|---|---|---|---|
| TS-1 | **Tag namespace contains release versions only** | Verified across Ecto (170 `vN.N.N` + 21 prerelease, nothing else), Phoenix (153 + 23), Oban (103 + 6), Req (62 + 1), Bandit (108 `N.N.N` + 18 `-pre`), Absinthe (82 + 27). **Zero** non-release tags in any of them. A tag namespace with two meanings is a foot-gun that already fired here. | LOW (mechanical) | ❌ **41 stray tags**: 28 `vN.N` planning, 11 `phase-238-generated-auth-proof-*`, 1 `archive/…`, vs 12 real `vN.N.N` |
| TS-2 | **No publish path derived from an arbitrary tag push** | The direct cause of the phantom `1.20.0` (ADR 003). Release Please / explicit-input dispatch only. | — | ✅ **Already satisfied** (ADR 003 guardrails 1–2 in place; `hex-publish.yml` is `workflow_dispatch` with a `release_version` that must match `@version`) |
| TS-3 | **A machine-enforced guard for TS-1/TS-2** | Convention-only discipline already failed twice: `v1.47` and `v1.48` were minted *after* ADR 003 said stop. A convention without a gate is not a control. | LOW | ❌ Not present — the milestone correctly scopes a CI guard rejecting non-SemVer `v*` tags |
| TS-4 | **`latest_stable_version` on Hex is a real release** | It is the number in every "add this to your deps" snippet Hex itself generates (`dep_snippet` in `package_view.ex` uses exactly this release). | HIGH (see F1/F2 — needs a decision, not just a task) | ❌ Reads `1.20.0` |
| TS-5 | **`hexdocs.pm/<pkg>` serves the current release's docs** | The canonical documentation entry point. | LOW (one command, gated auth) | ❌ Serves `1.20.0` — see **F3** |
| TS-6 | **Known-bad releases are retired with a reason** | Hex's documented practice: "retire a package or release instead of unpublishing it … if maintainers no longer recommend its use". | LOW (interactive auth) | ❌ `retirements: {}` |
| TS-7 | **README / CHANGELOG / LICENSE / SemVer discipline** | The Elixir Library Guidelines + community convention baseline. | — | ✅ **Already satisfied** — plus `CONTRIBUTING.md`, `SECURITY.md`, `MAINTAINING.md`, `CONVENTIONS.md`, `AGENTS.md`, and a Keep-a-Changelog CHANGELOG with an explicit "Planning milestones vs Hex releases" disambiguation section (genuinely above-average) |
| TS-8 | **No internal project-management bookkeeping in `@moduledoc`/`@doc`** | Verified: `Ecto` and `Oban` have **zero** `Phase N` / bare `#NNN` refs in `lib/`. Phoenix has 2, and they are *resolvable external URLs* in `#` comments (e.g. `# See https://github.com/mtrudel/bandit/issues/582`), not doc content. The norm is: rationale that a stranger can follow, in code comments; nothing unresolvable in public docs. | MEDIUM (volume) | ❌ **470 hits in `lib/`** across 43 files; 4 dead `.planning/` paths, incl. `lib/sigra/audit.ex:5` which is line 5 of a `@moduledoc` → renders on HexDocs as a link to nowhere |
| TS-9 | **Nothing unresolvable ships into adopters' generated files** | `mix.exs` `files: ~w(lib priv docs …)` → `priv/templates` **is** in the tarball. A generated file quoting `.planning/phases/16-org-liveviews-switcher/` lands in a stranger's repo, forever, with no way to follow it. | MEDIUM | ❌ **134 hits in `priv/templates/`**, incl. `organizations/organizations.ex:59` referencing a `.planning/` path |
| TS-10 | **Default branch CI is actually green, and green means "ran"** | The mechanism that silently stranded releases in v1.45. A gate that can be red-by-flake is not a gate. | HIGH (root-cause work) | ⚠️ Partial — `ci-gate` no longer counts `skipped` as pass (v1.47), but the `Generated admin Playwright smoke` flake is live and `pages build` fails on every push |
| TS-11 | **No permanently-failing workflow on the default branch** | A permanently-red check trains maintainers to ignore red. | LOW–MEDIUM | ❌ GitHub Pages fails on every push |
| TS-12 | **`.gitignore` complete; no tracked build artifacts** | Baseline repo hygiene. | LOW | ⚠️ Mostly good, but: `doc/llms.txt` is **tracked while ignored** (verified via `git ls-files -i -c`), `.gsd/` is unignored, root holds untracked `sigra-0.1.0.tar` / `sigra-0.2.0.tar` |
| TS-13 | **Dependency PRs are drained, not accumulated** | An 8-month-old Dependabot queue reads as unmaintained to anyone browsing the PR list, regardless of actual activity. | LOW–MEDIUM | ❌ 10 open Dependabot PRs (oldest #183, `credo` 1.7.18→1.7.19); 18 open PRs total |
| TS-14 | **PR/issue queue reflects reality** | Oban has 1 open issue, Ecto 12, Bandit 11 — the well-maintained end. Phoenix 47 / Req 54 is the tolerable end for high-traffic projects. 18 open PRs on a low-traffic lib where 8 are stale internal phase/recapture branches is noise. | LOW | ❌ 8 stale phase/recapture PRs (#211, #172, #124, #174, #219, #234 …) |
| TS-15 | **Dev branches/worktrees/stashes pruned** | Not adopter-visible, but 31 remote branches is a real navigation and accidental-base-branch hazard (already bit this project — the "worktrees fork from stale origin/main" issue). | LOW | ❌ 19 local / 31 remote branches, 6 stashes, 6 worktrees |

### Differentiators — notably good practice, worth adopting

| # | Property | Value proposition | Complexity | Sigra status |
|---|---|---|---|---|
| D-1 | **Tag-shape CI guard rejecting non-SemVer `v*`** | Turns ADR 003 from a document into an enforced invariant. Most Elixir libs rely on convention; a guard is strictly better and cheap. | LOW | Scoped in milestone — keep |
| D-2 | **A distinct namespace for non-release tags** (`milestone/v1.49`, `proof/phase-238-…`) | Lets planning traceability survive without polluting the release namespace — the ADR 003 escape hatch. Prevents the "delete tags → lose all traceability" objection. | LOW | ADR 003 already prescribes this; not implemented |
| D-3 | **A written "what may appear in public docs" rule** | Converts TS-8/TS-9 from a one-time cleanup into a durable property. Rule: *external resolvable URL or self-contained prose, yes; internal phase/plan/decision IDs, no.* Enforceable with a grep in `mix ci`. | LOW (rule) + LOW (grep gate) | Not present; `CONVENTIONS.md` is the natural home |
| D-4 | **A grep gate on `lib/` + `priv/templates/` for planning-ID patterns** | Without it, the next eleven phases re-pollute the surface. This is the difference between a cleanup and a fix. | LOW | Not present |
| D-5 | **Explicit flake quarantine with an owner and an expiry** | 2025–26 consensus: retries are "a shock absorber for rare intermittency"; quarantine is "an explicit risk acceptance record". Quarantine + tracked root cause is the honest form. Keep quarantine <5% of suite. | MEDIUM | Sigra already has a `ci-skip-manifest.tsv` — the right shape — but the milestone notes it cites a parity guard that does not exist. Repairing it is a differentiator-grade win |
| D-6 | **Dependabot `groups:` + cooldown** | Reported 70–80% PR-noise reduction. Turns a recurring 10-PR backlog into one reviewable PR per ecosystem per week. This is the *durable* fix; draining the current 10 is only the one-time fix. | LOW | `.github/dependabot.yml` has 3 ecosystems, **no `groups:`** — adding groups is a one-file change with outsized payoff |
| D-7 | **Todo triage with recorded disposition** | 41 pending todos with no keep/close/defer decision is indistinguishable from 41 forgotten todos. Recording *why* each was deferred is what makes deferral honest rather than avoidance (ADR 003 already models this well for the retire). | MEDIUM (volume) | Scoped in milestone — keep |
| D-8 | **Pin install docs to a known-good range while `latest_stable_version` lies** | A zero-auth, zero-risk mitigation that already works. Elevate it from an undocumented workaround to a stated decision with a removal trigger. | LOW | Already done in practice; not documented as a decision |
| D-9 | **A supersession ADR for knowingly-unsatisfied requirements** | v1.47 closed with TEST-01/02 as dead code and a contract test that now *blesses* the regression. Writing that down as a supersession decision (rather than leaving a green test lying) is exactly the honesty posture this milestone is about. | LOW–MEDIUM | Scoped in milestone — keep |
| D-10 | **`mix hex.publish docs --revert` on bad releases** | Rarely used, high leverage. Docs are mutable where tarballs are not — the one real escape hatch from an immutable mistake. | LOW | **Not scoped — add it** (see F3) |

### Anti-Features — look tidy, cost more than they're worth

| Anti-feature | Surface appeal | Why problematic | Do instead |
|---|---|---|---|
| **Rewriting git history (BFG / `filter-repo`) to slim the 645 MB `.git`** | "Clean, small repo" | Invalidates every existing clone, fork, worktree, and open PR; breaks every commit SHA cited in CHANGELOG, ADRs, phase artifacts and GitHub Release notes — including the `compare/v1.4.0...v1.5.0` links in the published CHANGELOG *that is packaged inside the Hex tarball*. Irreversible; the gain is disk space nobody is paying for. | **The milestone's existing exclusion is correct — validated.** Keep `.git` untouched. If size ever bites, fix it at clone time (`--filter=blob:none`, shallow CI clones), not at history level. |
| **Pruning `.planning/` out of the repo** | "The shipped repo shouldn't carry project management" | `.planning/` is not shipped — `mix.exs` `files:` is `lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md`. It never reaches Hex. Deleting it destroys the traceability that makes the *other* cleanups safe (you cannot judge "is this `Phase 131` comment real rationale?" with the phases deleted). | **The milestone's existing exclusion is correct — validated.** Fix the *leak* (TS-8/TS-9), not the source. |
| **Deleting the stray tags without first checking for dependents** | "Namespace is clean" | Low risk here, but non-zero: a deleted tag breaks any `{:sigra, github: …, tag: "v1.20"}` pin and orphans any GitHub Release attached to it. Verified: sigra's 12 GitHub Releases all map to real `vN.N.N` tags, so the 41 stray tags carry **no** releases. | Do delete — but as an explicit two-step: enumerate + confirm no attached release/branch/dependent, *then* delete, and record the deleted list in the ADR so the history is recoverable. Optionally re-mint the 11 proof tags under `proof/` first (D-2). |
| **Wrapping the Playwright smoke flake in a retry** | "main goes green today" | "A retry masks the symptom … the root cause is still there and now invisible." Worse: a real race in generated auth code also passes on retry, so the retry hides a *customer-facing* bug behind a green gate. This is precisely the v1.45 failure mode restated. | Root-cause it. If it cannot be root-caused inside the milestone, **quarantine it into the non-blocking suite with an owner, a reason, and an expiry date** in `ci-skip-manifest.tsv` — an explicit, dated risk acceptance, not a silent retry. |
| **Bulk-merging all 10 Dependabot PRs on green CI without reading them** | "Queue drained" | "If teams start accepting grouped PRs purely because they are familiar … the policy can reduce scrutiny exactly where supply-chain exposure needs discipline most." Two of the queued bumps are *major* (`otplib` 12→13, `@anthropic-ai/sdk` 0.110→0.123) and one is a companion lib (`threadline` 0.7→0.9) with a real integration seam. | Split: auto-merge patch/minor on green; read majors and `threadline` individually. Then add `groups:` (D-6) so this never becomes a backlog again. |
| **Unpublishing / force-fixing `1.20.0`** | "Erase the mistake" | Hex is immutable past the 60-min/24-hr windows by design. Chasing this burns operator time on a lever that does not exist. | Retire (TS-6) + revert docs (D-10) + decide F2. Accept that `1.20.0` exists forever. |
| **Cutting `2.0.0` purely to escape `1.20.0`** | "`~> 1.0` resolves again, and we get a clean major" | A major version signals a breaking change to every adopter and to every automated tool. Using it as a numbering escape hatch is a lie in the version number — the same class of error that caused this mess. | If F2 says "publish above the phantom", prefer `1.21.0` (truthful minor) over `2.0.0`, and say why in the CHANGELOG. |
| **Deleting the `archive/local-main-pre-*-recovery` tag along with the rest** | "One sweep, all stray tags gone" | That tag is a deliberate safety anchor for a recovery event, in an already-distinct namespace (`archive/`). It is the *correct* pattern (D-2), not pollution. | Keep it. Delete only `vN.N` and — after re-minting under `proof/` if wanted — `phase-238-*`. |

---

## Dependencies

```
TS-1 delete stray tags ──requires──> TS-2/TS-3 guard in place first
      │                              (delete before guard = the guard has nothing
      │                               to prevent, and the next close flow re-mints)
      └──enhanced-by──> D-2 distinct namespace (re-mint proof tags before deleting)

TS-6 retire 1.20.0 ──shares operator step──> D-10 revert 1.20.0 docs
      │                                       (same interactive Hex write-auth;
      │                                        one runbook, one prompt session)
      └──does NOT satisfy──> TS-4 latest_stable_version  [see F1]

TS-4 latest_stable_version ──blocked-on──> an F2 decision (new ADR)
      └──mitigated-meanwhile-by──> D-8 pinned install docs

TS-8 strip lib/ bookkeeping ──must-precede──> D-4 grep gate
TS-9 strip template bookkeeping ──┘          (gate on a dirty tree = red forever)

D-4 grep gate ──must-precede──> the next milestone
      (otherwise TS-8/TS-9 are a one-shot that re-pollutes)

TS-10 honest green main ──gates──> "land the pending release" (PR #224, release 1.5.1)
      │  release-please's gate-ci-green cannot pass on an intermittently-red ci-gate
      └──requires-decision──> D-5 quarantine, IF root-cause exceeds the milestone

TS-13 drain Dependabot ──should-precede──> D-6 groups:
      (grouping an existing backlog produces one enormous unreviewable PR)

TS-13 drain Dependabot ──competes-with──> TS-10 honest green main
      (every dep PR must pass the same flaky ci-gate; draining 10 PRs through a
       flaky gate is where the milestone will actually lose its time)

TS-12 gitignore/doc/llms.txt ──independent──> everything else (do it first, it's free)
```

### Dependency notes

- **The flake is the critical path, not the tags.** TS-10 gates the release *and* taxes every
  one of the 10 Dependabot merges. It should be phased first or run in parallel from day one.
- **`doc/llms.txt` tracked-while-ignored is a genuine conflict, not a typo.** `doc/` is
  ignored because it is ex_doc output, but `llms.txt` is a deliberately published artifact
  (ex_doc 0.40+ generates it). Decide: either `!doc/llms.txt` negation in `.gitignore`, or
  move the published copy out of `doc/` (root `llms.txt` already exists — check for a duplicate).
- **Retire + docs-revert must be one operator session.** Both need interactive Hex write auth.
  Splitting them across phases doubles the human-gated steps for no benefit.

---

## Milestone scoping

### Do in v1.48 (the honest floor)

- [ ] **TS-12** — `.gitignore` `.gsd/`, resolve `doc/llms.txt`, drop stray tarballs — free, unblocks nothing but costs nothing
- [ ] **TS-10 / TS-11** — root-cause the Playwright smoke flake; fix `pages build`; prove `ci-gate` green across consecutive pushes with live-run evidence
- [ ] **TS-3 / D-1 / D-2** — tag-shape CI guard + distinct namespace, **then** TS-1 tag deletion
- [ ] **TS-6 + D-10** — one gated operator runbook: `mix hex.retire sigra 1.20.0 invalid` **and** `mix hex.publish docs --revert 1.20.0`, with pre/post API verification
- [ ] **TS-8 / TS-9 → D-3 / D-4** — strip bookkeeping from `lib/` (HexDocs-rendering first) and `priv/templates/` (adopter-shipping first), write the rule, add the grep gate
- [ ] **TS-13 → D-6** — drain the 10 dep PRs (split patch/minor vs major), then add `groups:`
- [ ] **TS-14 / TS-15** — close stale phase PRs, prune branches/worktrees/stashes
- [ ] **D-7** — triage 41 todos to keep/close/defer with recorded reasons
- [ ] **D-9** — supersession ADR for TEST-01/02; delete `ExUnitTimingFormatter`; rewrite the contract test that blesses the regression
- [ ] **D-5** — repair the skip manifest's phantom parity-guard citation + the rotted `MAINTAINING.md` leg
- [ ] Land the pending release (PR #224)

### Decide in v1.48, act later if needed

- [ ] **F2 / TS-4** — write an ADR choosing between "live with pinned docs", "publish `1.21.0`",
      or "petition hex.pm". **Do not scope a `~> 1.0` resolution *proof* until this ADR lands** —
      the current requirement as written cannot pass (F1).

### Explicitly out (validated exclusions)

- [ ] History rewriting / `.git` slimming — **confirmed anti-feature**, see table
- [ ] Pruning `.planning/` — **confirmed anti-feature**; it never ships (verified via `mix.exs` `files:`)
- [ ] Any feature, UI, or W-3/W-4 generated-auth runtime-proof work

---

## Prioritization matrix

| Item | Adopter/maintainer value | Cost | Priority |
|---|---|---|---|
| D-10 revert `1.20.0` docs | **HIGH** — fixes the actual documentation adopters read | **LOW** — one command | **P1** (currently unscoped) |
| TS-10 honest green `ci-gate` | HIGH — gates the release and every dep merge | HIGH | P1 |
| TS-9 strip adopter-shipped template refs | HIGH — permanent, lands in strangers' repos | MEDIUM | P1 |
| TS-8 strip HexDocs-rendering refs | HIGH — public credibility surface | MEDIUM | P1 |
| TS-1+TS-3 tag namespace + guard | HIGH — structurally closes ADR 003 | LOW | P1 |
| TS-6 retire `1.20.0` | MEDIUM — honesty signal, not a resolution fix | LOW (gated) | P1 |
| TS-11 fix Pages | MEDIUM — removes permanent red | LOW–MEDIUM | P1 |
| D-4 grep gate | HIGH — makes TS-8/9 durable | LOW | P1 |
| TS-13 drain deps | MEDIUM | MEDIUM (gate-taxed) | P2 |
| D-6 dependabot `groups:` | MEDIUM — durable noise fix | LOW | P2 |
| D-9 supersession ADR + dead-code delete | MEDIUM — retires dishonest debt | LOW–MEDIUM | P2 |
| D-5 skip-manifest repair | MEDIUM | MEDIUM | P2 |
| D-7 todo triage | MEDIUM | MEDIUM | P2 |
| TS-14/15 PR + branch prune | LOW–MEDIUM | LOW | P2 |
| TS-12 gitignore/artifacts | LOW | LOW | P2 (do first, it's free) |
| TS-4 `latest_stable_version` | HIGH | HIGH + irreversible | P3 — **decide** in v1.48, act later |

---

## Comparator scan (how respected Elixir libraries actually look)

| Property | Ecto | Phoenix | Oban | Req | Bandit | Sigra today |
|---|---|---|---|---|---|---|
| Tag namespace | `vN.N.N` only | `vN.N.N` only | `vN.N.N` only | `vN.N.N` only | `N.N.N` only | **3 namespaces mixed in `v*`** |
| Non-release tags | 0 | 0 | 0 | 0 | 0 | **40** |
| `Phase N` / bare `#NNN` in `lib/` | 0 | 2 (both resolvable external URLs, in `#` comments) | 0 | — | — | **470** |
| Open issues | 12 | 47 | 1 | 54 | 11 | 18 open PRs, 8 of them stale-internal |
| `dependabot.yml` | no | yes | yes | no | yes | yes, **no `groups:`** |
| Changelog | yes | yes | yes | yes | yes | yes + an unusually good SemVer-vs-milestone disambiguation |

**Read:** on *documentation and process artifacts* Sigra is at or above the ecosystem bar
(CONTRIBUTING, SECURITY, MAINTAINING, CONVENTIONS, ADRs, a disambiguating CHANGELOG). The gap
is entirely in **namespace discipline, shipped-surface cleanliness, and queue drainage** —
exactly the three things this milestone names. The thesis is well-aimed; the scope needs the
three F-corrections above.

---

## Sources

**Verified against upstream source (HIGH confidence):**
- `hexpm/hexpm` `lib/hexpm/repository/release.ex` `latest_version/2` and
  `lib/hexpm_web/views/api/package_view.ex` — proves `latest_stable_version` ignores retirement
- `hexpm/hex` `lib/hex/solver.ex` (no retirement logic), `lib/hex/policy/filter.ex`
  (retirement is policy-gated), `lib/hex/remote_converger.ex` (warning-only path)
- Live `GET https://hex.pm/api/packages/sigra`, 2026-09-15 — `latest_stable_version: 1.20.0`,
  `retirements: {}`, `1.20.0 has_docs: true`
- Live `https://hexdocs.pm/sigra/` → `https://sigra.hexdocs.pm/` reports `v1.20.0`
- `gh api repos/<org>/<repo>/tags` for ecto, phoenix, oban, req, bandit, absinthe

**Documentation (HIGH confidence):**
- [mix hex.retire — Hex v2.5](https://hexdocs.pm/hex/Mix.Tasks.Hex.Retire.html)
- [Hex.pm FAQ](https://hex.pm/docs/faq) — immutability windows; "retire instead of unpublish"
- [Hex.pm dependency policies](https://hex.pm/docs/dependency-policies) — retirement rule is policy-scoped
- [mix hex.publish — `docs --revert VERSION`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html)
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/library-guidelines.html)
- [Optimizing PR creation for Dependabot version updates — GitHub Docs](https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/optimizing-pr-creation-version-updates)

**Practice literature (MEDIUM confidence):**
- [Flaky Test Quarantine — minware](https://www.minware.com/guide/best-practices/flaky-test-quarantine)
- [CI Flaky Test Auto Quarantine Workflow — QASkills.sh](https://qaskills.sh/blog/ci-flaky-test-auto-quarantine-workflow)
- [Taming Dependabot: Grouping, Cooldowns, and Cutting PR Noise (2026)](https://dev.to/instasla/taming-dependabot-a-2026-guide-to-grouping-cooldowns-and-cutting-pr-noise-246e)
- [Prepare and release your Elixir open source package like a pro — Fresha Engineering](https://medium.com/fresha-engineering/ultimate-guide-to-preparing-and-releasing-elixir-open-source-package-like-a-pro-d64a0f86d012)

**Local (HIGH confidence):**
- `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`
- `.planning/PROJECT.md` (v1.48 milestone + current state), `CHANGELOG.md`, `mix.exs`,
  `.gitignore`, `.github/dependabot.yml`, `git tag`/`git ls-files -i -c`/`gh pr list` output

---
*Feature research for: clean-baseline posture of a public Elixir/Hex library*
*Researched: 2026-09-15*
