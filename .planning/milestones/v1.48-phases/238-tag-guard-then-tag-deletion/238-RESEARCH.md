# Phase 238: Tag Guard, Then Tag Deletion — Research

**Researched:** 2026-09-16
**Domain:** GitHub repository rulesets (tag target), git ref lifecycle management, repo-side contract guards
**Confidence:** HIGH on the repo-side measurements and the GitHub REST schema; MEDIUM on the plan-gating verdict (documented, not yet API-probed — D-01 still owes the observation)

---

## Summary

The phase's discussion already did most of the hard thinking; this research **confirms the
measured starting state exactly**, **resolves D-01's open question to a near-certain NO**, and
**adds one design option the discussion did not consider that materially changes the fallback
ladder**.

**D-01 is very likely to fail.** GitHub's own docs source proves that the entire
`## Metadata restrictions` section of "Available rules for rulesets" — the section that owns
`tag_name_pattern`, `branch_name_pattern` and `commit_message_pattern` — is wrapped in
`{% ifversion repo-rules-enterprise %}`, and that feature flag declares
`versions: {ghec: '*', ghes: '>3.10'}` with **no `fpt`** entry, above a comment that names
them "enterprise-only features". `szTheory/sigra` is a **User**-owned public repo with
`plan: null` (GitHub Free) — verified live. Plan for the fallback as the likely path, not the
exception.

**But the fallback does not have to be detection-only.** D-02 assumed the only server-side
alternative was a `creation` rule scoped to `refs/tags/v*`, which would block release-please.
That assumption misses `conditions.ref_name.exclude`. A `creation` rule with
`include: ["refs/tags/v*"]` **and** `exclude: ["refs/tags/v*.*.*"]` is fnmatch-scoped, is
**not** gated behind `repo-rules-enterprise`, is genuinely **server-side**, keeps
`bypass_actors: []`, leaves release-please's `v1.5.1` and `v1.5.1-rc.1` entirely out of scope,
and reproduces SC-1's literal probe verbatim (`v9.9` rejected, `v9.9.9-rulesettest` accepted).
It is weaker than the RE2 regex — `v1.2.3.4` and `v1.a.b` slip through — but it blocks the
exact recurrence class (two-component `vX.Y`) that this phase exists to stop, and it does so
on the server. This is a **Tier 2** between D-01's ruleset and D-02's hook, and it should be
planned as such.

**The recurrence is live, not hypothetical.** ADR 003 (2026-07-11) states "Milestone tagging
was stopped after `v1.35`". Two milestone tags were minted **after** that ADR was written:
`v1.47` (2026-08-04, local only) and `v1.48` (2026-08-12, **on `origin`**). The ADR amendment
D-19 prescribes must correct that sentence, not just extend it.

**Primary recommendation:** Plan 238-01 runs D-01's probe **and** a Tier-2 probe in the same
step, so one write cycle settles the whole ladder; everything downstream (the committed
snapshot, the `p19` guard's assertions, the `ci-observe` drift read, the REL-01 supersession
wording) branches off a single recorded result.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Copied verbatim from `238-CONTEXT.md` `## Implementation Decisions`. D-01 through D-19 are
binding. Rather than duplicate 200 lines here, the planner **MUST** read
`.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md` in full. The load-bearing
shape, restated for the record:

- **D-01** Feasibility probe first (`POST /rulesets` with `enforcement: "disabled"`, then
  `DELETE`). Nothing else is settled until it returns. Blocked during discussion by the
  harness permission classifier; it is an execution step.
- **D-02** If plan-gated, do **not** substitute a bare `creation` rule on `refs/tags/v*`.
  Fallback is (a) committed `pre-push` hook + (b) `on: push: tags: ['v*']` detection workflow.
  REL-01 amended as a **recorded supersession** in `.planning/REQUIREMENTS.md`.
  *(This research adds a Tier 2 that sits between D-01 and D-02 — see Architecture Patterns.)*
- **D-03** `target: "tag"`, `enforcement: "active"`, `bypass_actors: []`,
  `conditions.ref_name.include: ["refs/tags/v*"]`, `exclude: []`, exactly one rule:
  `tag_name_pattern`, `operator: "regex"`, `negate: false`, anchored `^v…$`.
- **D-04** Never a `creation` rule; never a `deletion` rule. Create via API, never the wizard.
- **D-05** `bypass_actors: []` stays empty. No implicit admin bypass.
- **D-06** Guard active first → SC-1 proof → delete the accepted scratch tag (that delete **is**
  the deletion-blocking probe) → if blocked, flip to `disabled`, delete, flip back, record the
  window.
- **D-07** Non-`v` tags out of scope. `refs/tags/v*` is fnmatch with `FNM_PATHNAME`.
- **D-08** `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`. `p18-*` reserved for
  SURF-04. Wired only via the `ci.yml` glob. Never `mix ci`. Never `release_ref_guard`.
- **D-09** PR-lane half is offline/structural against a committed snapshot at
  `.github/rulesets/tag-namespace.json`; RED via
  `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json`.
- **D-10** Assert `target`, `enforcement`, `conditions.ref_name.include`, and the rule's
  `operator`/`negate`/`pattern`. **Must NOT** assert `bypass_actors == []`.
- **D-11** Live half is a two-step `GET /rulesets` → `GET /rulesets/{id}` in `ci-observe.yml`;
  default-branch-only caveat stated plainly. Operator one-liner into `MAINTAINING.md`.
- **D-12** Committed TSV at `.planning/decisions/003-tag-delete-list.tsv` (not phase-local).
  Columns `tag`, `local`, `remote`, `class`, `pre_delete_sha`, `reason`. 39 rows.
- **D-13** Never a glob at the `git tag -d` call site. `scripts/maintainers/delete-planning-tags.sh`,
  dry-run default, `--apply` required, local → verify → remote as separate invocations.
  Script **and** `MAINTAINING.md` runbook.
- **D-14** Set-equality asserted per side, regex-derived, no count hardcoded.
- **D-15** `phase-238-*` tags held by `gsd/238-generated-auth-runtime-proof-evidence`;
  `pre_delete_sha` is the forward-feed to Phase 245.
- **D-16** `238-EVIDENCE.md` with `## BEFORE-*` / `## AFTER-*` slot grammar, `Status:` line,
  fenced producing command.
- **D-17** `238-TAG-RULESET-RECORD.md` committed **before** the ruleset is created,
  frontmatter `kind: outward-facing-settings-change-record`.
- **D-18** SC-1 RED citable by `rule_suite_id` + `rule_evaluations[]`; JSON embedded, not just
  the id; captured locally as owner inside the `time_period` window.
- **D-19** ADR 003 amended in place, dated `## Amendment — 2026-09-16 (Phase 238)`,
  `**Status:** Accepted` retained.

### Claude's Discretion

- Exact TSV column ordering and comment-header wording, the `p19` guard's internal assertion
  decomposition, and the wording of the `MAINTAINING.md` subsections.
- Whether the `pre-push` hook fallback (D-02) is also installed unconditionally as
  defence-in-depth even when the ruleset works. Recommended yes if it costs one committed
  script — it prevents at the source, which is where the recurrence lives — but it is not
  required by any success criterion, so it must not grow the phase.

### Deferred Ideas (OUT OF SCOPE)

- **A `~ALL` tag ruleset covering non-`v` junk tags** — rejected in D-07; would put
  release-please and every other tag in scope. Its own decision, its own RED proof.
- **A `milestone/` + `proof/` namespace convention enforced by a guard** — D-19 *records* the
  namespaces; mechanically enforcing them is not scoped here.
- **Amending REL-01's wording** — only if D-01's probe fails; tracked in D-02 as a recorded
  supersession, never a silent re-scope.
- All 51 `todo.match-phase` hits reviewed, **none folded** — keyword-similarity noise.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **REL-01** | "A tag-name guard rejects any non-SemVer `v*` tag — a GitHub tag ruleset (server-side) plus a paired contract test — demonstrated **RED** against a known-bad tag name. Lands **before** any deletion." | §Plan-Gating Verdict resolves whether the literal `tag_name_pattern` shape is available; §Architecture Pattern 2 supplies a **server-side** Tier-2 shape that preserves REL-01's "server-side" word even if `tag_name_pattern` is gated, reducing the supersession from "detection only" to "coarser pattern"; §Architecture Pattern 3 supplies the `p19` guard skeleton and the exact committed-snapshot bytes it asserts against. |
| **REL-02** | "The 28 non-SemVer `v1.NN` planning tags and 11 `phase-238-*` tags are deleted local and remote from a **committed explicit allowlist**, never a glob. The delete set is asserted set-equal to the allowlist, the 12 three-component SemVer release tags and `archive/*` are untouched, and `gh release list` count is unchanged with zero untagged drafts." | §Measured Starting State confirms all six counts live (28/11/12/1, remote 10/11/12/0) and the **exact** 18-tag local-only subset the remote pass must skip; §Pitfall 1 corrects the `gh release list --json draft` field name that SC-4's literal jq would crash on; §Code Examples give the regex-derived per-side keep-set assertions with no hardcoded count. |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Rejecting a non-SemVer `v*` tag at push time | **GitHub server (repository ruleset)** | Local `pre-push` hook (D-02b) | Only the server binds every actor including the owner and CI tokens; the hook is defence-in-depth at the source, never the guarantee. |
| Detecting that the guard was deleted/altered in Settings | **CI observer lane (`ci-observe.yml`, live `gh api`)** | Committed snapshot + offline `p19` guard on PR lane | A live read is the only thing that sees Settings drift; it must not sit on the PR critical path (established repo pattern). |
| Pinning the guard's *intended* shape as reviewable code | **Committed JSON snapshot (`.github/rulesets/tag-namespace.json`)** | — | The ruleset is `source_type: "Repository"` (Settings-managed); the repo has no other record of it. |
| Selecting which tags to delete | **Committed TSV allowlist (`.planning/decisions/003-tag-delete-list.tsv`)** | — | Data file is the single source of truth; the script renders it, prose renders it. Never a glob. |
| Executing deletion | **Operator script (`scripts/maintainers/delete-planning-tags.sh`), dry-run default** | `MAINTAINING.md` runbook | One-shot destructive work; value is auditability, not repetition — so a script, not a CI job. |
| Recording that it happened, permanently | **ADR 003 amendment** | `238-EVIDENCE.md` slots | The ADR outlives the phase directory (which moves at milestone close). |

---

## Measured Starting State (live, 2026-09-16)

Every number below was produced by running the cited command against this repo and this
remote today. The ROADMAP's and CONTEXT's counts reproduce **exactly**.

### Tag inventory — partitions with zero unclassified tags

```bash
$ git tag | wc -l                                     # 52
$ git ls-remote --tags origin | sed 's#.*refs/tags/##' | grep -cv '\^{}'   # 33
```

| Class | Regex | Local | Remote |
|-------|-------|-------|--------|
| Three-component SemVer (keep) | `^v[0-9]+\.[0-9]+\.[0-9]+$` | **12** | **12** |
| `archive/*` (keep, local-only) | `^archive/` | **1** | **0** |
| Two-component `vX.Y` planning (delete) | `^v[0-9]+\.[0-9]+$` | **28** | **10** |
| `phase-238-generated-auth-proof-*` (delete) | `^phase-238-` | **11** | **11** |
| Unclassified | — | **0** | **0** |

`[VERIFIED: live `git tag` / `git ls-remote --tags origin`, 2026-09-16]`

**Keep-sets (D-14), regex-derived, no count hardcoded:**
- local keep = SemVer3 ∪ `archive/` = **13**
- remote keep = SemVer3 only = **12**

**Delete-set sizes:** local **39** rows executed; remote **21** rows executed (10 `vX.Y` + 11
`phase-238-*`). The TSV has **39 rows**; the remote pass is driven by `remote=yes` only.

**The 18 local-only `vX.Y` tags the remote pass MUST skip** (a `git push origin --delete` on
any of these errors):

```
v1.0  v1.6  v1.7  v1.8  v1.9  v1.10 v1.12 v1.15 v1.16 v1.17
v1.25 v1.27 v1.29 v1.30 v1.31 v1.34 v1.35 v1.47
```

**The 10 `vX.Y` tags that ARE on `origin`:** `v1.1 v1.3 v1.4 v1.5 v1.14 v1.21 v1.26 v1.28
v1.33 v1.48` — matching CONTEXT D-14 verbatim.

`[VERIFIED: `comm -23` over the two classified lists, 2026-09-16]`

### The 12 keep-set SemVer tags, and the releases they back

```bash
$ gh release list --limit 100 --json tagName --jq '.[].tagName' | sort
v0.2.1 v0.2.2 v0.2.3 v0.2.4 v0.2.5 v0.3.0 v1.0.0 v1.1.0 v1.2.0 v1.3.0 v1.4.0 v1.5.0
```

All **12** GitHub Releases are backed by three-component SemVer tags. The release tag set is
**identical** to the remote keep-set. Deletion therefore cannot untag a release — structurally,
not by count. `gh api repos/szTheory/sigra/releases --paginate --jq '[.[]|select(.draft)]|length'`
returns **0**. `[VERIFIED: live `gh release list` / `gh api .../releases`, 2026-09-16]`

### `mix.exs` `source_ref`

```elixir
      # Hex/ExDoc: before mix hex.publish, ensure git tag v#{@version} exists or "View source" on hexdocs returns 404.
      source_ref: "v#{@version}",
```
`[VERIFIED: mix.exs:207-208]` — `@version` is `1.5.0`, so `source_ref` resolves to `v1.5.0`, a
keep-set tag. The comment at `:207` already warns about exactly this failure mode. SC-4's
HexDocs half is structurally safe **before** the phase runs, and the live `curl` is
confirmation, not discovery.

### Live ruleset state

```bash
$ gh api repos/szTheory/sigra/rulesets --jq '.[]|{id,name,target,source_type,enforcement}'
{"id":14941512,"name":"main","target":"branch","source_type":"Repository","enforcement":"active"}
```
Exactly **one** ruleset. Its by-id payload:
`conditions.ref_name.include == ["~DEFAULT_BRANCH"]`, `bypass_actors == []`,
`current_user_can_bypass == "never"`, rule types
`["deletion","non_fast_forward","pull_request","required_status_checks"]`.
`[VERIFIED: live `gh api repos/szTheory/sigra/rulesets/14941512`, 2026-09-16]`

### Repo plan

```bash
$ gh api repos/szTheory/sigra --jq '{owner:.owner.login, owner_type:.owner.type, private:.private, plan:.owner.plan}'
{"owner":"szTheory","owner_type":"User","plan":null,"private":false}
```
`[VERIFIED: live `gh api repos/szTheory/sigra`, 2026-09-16]` — **User**-owned, public,
`plan: null`. This is the fact that drives the plan-gating verdict below. Note `owner_type:
"User"`: even a paid personal plan (GitHub Pro) would not make this repo "an organization on a
GitHub Enterprise plan", which is how the docs phrase the metadata-restriction entitlement.

### The recurrence is live — ADR 003 contains a factual error

ADR 003 guardrail 3 states: *"Milestone tagging was stopped after `v1.35` precisely to
eliminate the namespace collision."* Two milestone tags were minted **after** that ADR's date
(2026-07-11):

```bash
$ git log -1 --format='%H %ad %s' --date=short v1.47
14a35cbe... 2026-08-04 style: normalize v1.47 retrospective
$ git log -1 --format='%H %ad %s' --date=short v1.48
ef66ed2b... 2026-08-12 chore: remove REQUIREMENTS.md for v1.48 milestone
```
`[VERIFIED: local `git log -1` on tags v1.47 / v1.48, 2026-09-16]` — and `v1.48` is on
`origin` (present in `git ls-remote --tags origin`). **`v1.47` is local-only.**

This is the empirical proof of the phase's own premise ("cannot be re-polluted by the next
close flow"), and it means D-19's amendment must **correct** guardrail 3's claim, not merely
extend it. Recommend the amendment say: *stopped after `v1.35` by policy, but re-minted at
`v1.47` and `v1.48` because the policy was prose with no enforcement — which is what this
phase's guard replaces.*

---

## Plan-Gating Verdict (D-01's open question, resolved to a near-certain NO)

### The documentary evidence

GitHub's docs source is versioned with per-feature flags. The entire `## Metadata restrictions`
section of "Available rules for rulesets" — lines 305–330 of the content file — is wrapped:

```liquid
{% ifversion repo-rules-enterprise %}

## Metadata restrictions
…
{% endif %}
```
`[VERIFIED: github/docs `content/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets.md:305-330`, fetched raw 2026-09-16]`

The flag itself, verbatim and in full:

```yaml
# Reference: #9228
# Public beta for repository rulesets.
# Feature flag for enterprise-only features (metadata restrictions, setting rulesets at org level, ruleset insights)
versions:
  ghec: '*'
  ghes: '>3.10'
```
`[VERIFIED: github/docs `data/features/repo-rules-enterprise.yml`, fetched raw 2026-09-16]`

`fpt` (free/pro/team on dotcom) is **absent**, and the comment names the gated set
"enterprise-only features (**metadata restrictions**, …)". Corroborating, the `about-rulesets`
page renders a different sentence per plan:

> "Rulesets can also control commit metadata, such as commit messages and author email
> addresses. For more information, see [AUTOTITLE]…{% ifversion ghec %}."{% else %} in the
> {% data variables.product.prodname_ghe_cloud %} documentation.{% endif %}"

`[VERIFIED: github/docs `content/.../about-rulesets.md:54`]` — i.e. on Free the page routes the
reader to the GHEC docs, which is exactly the marker D-01 identified. The `Evaluate` enforcement
status is gated by the **same** flag, so on Free only `active` and `disabled` exist.
`[VERIFIED: github/docs `data/reusables/repositories/rulesets-about-enforcement-statuses.md`]`

**What is NOT gated** (outside every `ifversion` in the same file): `Restrict creations`,
`Restrict updates`, `Restrict deletions`, and `target: "tag"` itself. Rulesets as a feature are
explicitly available: *"Rulesets are available in public repositories with GitHub Free…"*
`[VERIFIED: github/docs `data/reusables/gated-features/repo-rules.md`]`

### What this does and does not prove

It proves GitHub **documents** `tag_name_pattern` as an enterprise-tier metadata restriction and
does not render it for Free. It does **not** prove the REST API returns `422`/`403` for it on
this repo — docs gating and API enforcement are separate systems and occasionally diverge.
`[ASSUMED]` that the probe returns an error naming the rule type.

**Planning consequence:** treat the fallback as the **expected** path and the `tag_name_pattern`
ruleset as the upside. Do not order plans such that four tasks are blocked waiting on a probe
that will probably say no.

---

## Standard Stack

### Core (all already present — this phase adds no dependency)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gh` CLI | **2.95.0** (2026-06-17) | Every live GitHub API read/write in this phase | Already the repo's idiom in `ci-observe.yml`, `MAINTAINING.md`, and every 237 evidence slot. `[VERIFIED: `gh --version`, local]` |
| `git` | system | Tag inventory, local delete, remote delete | — |
| `node --test` (node:test) | Node 22 in CI | The `p19` guard runtime | Mandated by `_lib.mjs:11-22`: GSD's `check prohibition-enforcement` producer accepts only `check_kind: node-test` or `lint-rule`, so an ExUnit guard could never satisfy a `verification: test` prohibition. `[VERIFIED: scripts/ci/prohibitions/_lib.mjs:1-25]` |
| `jq` | CI + local | Keep-set/delete-set set-equality, release draft count | Already used throughout `ci-observe.yml`. |

**No new packages. No `mix.exs` change. No `package.json` change.** The Package Legitimacy
Audit section below is therefore empty by construction.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repository ruleset (Settings-managed) | Classic branch/tag protection | Classic tag protection exists but has **implicit admin bypass**, which defeats D-05's entire point (this phase must bind the repo owner). Rulesets have no implicit admin bypass — the live `main` ruleset reports `current_user_can_bypass: "never"` to the owner. `[VERIFIED: live by-id payload]` |
| Committed JSON snapshot + offline guard | A live `gh api` call inside `fast_checks` | Puts `gh`, a token, and transient 5xx on the pull_request critical path — the exact class of flake this milestone exists to remove. `p12`'s header states the prohibition directly. `[VERIFIED: scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:7-15]` |
| `.planning/decisions/003-tag-delete-list.tsv` | A phase-local delete list | Phase directories MOVE to `.planning/milestones/v<X.Y>-phases/` at close — the hazard `_lib.mjs`'s `archiveAwareRelPath` exists to work around. SC-5 requires ADR 003 to cite the path; a phase-local path rots into a dead link at close. `[VERIFIED: scripts/ci/prohibitions/_lib.mjs:42-48]` |

---

## Package Legitimacy Audit

**Not applicable.** This phase installs **zero** external packages. No `mix.exs` dependency, no
npm dependency, no new GitHub Action. Every tool used (`gh`, `git`, `jq`, `node --test`) is
already present and already exercised by committed CI. `[VERIFIED: phase scope per 238-CONTEXT.md; no
install step appears in any decision D-01..D-19]`

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

---

## Architecture Patterns

### System Architecture Diagram

```
                       ┌──────────────────────────────────────────────┐
  operator / CI token  │        github.com — server-side              │
        │              │                                              │
        │ git push      │   ┌────────────────────────────────────┐    │
        │ refs/tags/X ─┼──▶│  ruleset evaluation (aggregated)    │    │
        │              │   │  • main (14941512) target=branch    │    │
        │              │   │  • NEW  target=tag  ← this phase    │    │
        │              │   └───────────┬────────────────────────┘    │
        │              │        pass   │   fail → GH013, ref NOT     │
        │              │               │          created            │
        │              │               ▼          + rule_suite row   │
        │              │        refs/tags/X exists                    │
        │              └───────────────┬──────────────────────────────┘
        │                              │
        │                              │ GET /rulesets  → id
        │                              │ GET /rulesets/{id} → full shape
        │                              │ GET /rulesets/rule-suites[/{id}]
        │                              ▼
   ┌────┴──────────────┐    ┌──────────────────────────┐   ┌─────────────────────┐
   │ pre-push hook     │    │ ci-observe.yml           │   │ 238-EVIDENCE.md     │
   │ (D-02b, optional  │    │ workflow_run, non-PR,    │   │ BEFORE-*/AFTER-*    │
   │  defence-in-depth)│    │ off ci-gate DAG          │   │ slots + embedded    │
   └───────────────────┘    │ live shape ─┐            │   │ rule-suite JSON     │
                            └─────────────┼────────────┘   └─────────────────────┘
                                          │ diff
                                          ▼
                       ┌──────────────────────────────────────┐
   PR lane (offline) ─▶│ .github/rulesets/tag-namespace.json  │◀── committed snapshot
   fast_checks glob    │            ▲                         │
   ci.yml:392          │            │ subjectPath()           │
        │              └────────────┼─────────────────────────┘
        ▼                           │
   p19-tag-namespace-ruleset.test.mjs ── RED against ───▶ test/fixtures/prohibitions/
        (no gh, no token, no network)                    p19-tag-ruleset-absent-or-altered.json


   ── deletion path, one-shot, separate invocations ──

   .planning/decisions/003-tag-delete-list.tsv   (39 rows; local/remote flags; pre_delete_sha)
                      │
                      ▼
   scripts/maintainers/delete-planning-tags.sh   (dry-run default; --apply required)
        │  pass 1: local   git tag -d      (all 39)
        │  pass 2: VERIFY  git tag | regex keep-set == 13, set-equal
        │  pass 3: remote  git push origin --delete   (remote=yes rows only, 21)
        │  pass 4: VERIFY  git ls-remote --tags origin | regex keep-set == 12, set-equal
        ▼
   gh release list (12, 0 drafts) + curl HexDocs "View source" → unchanged
```

### Recommended Artifact Layout

```
.github/rulesets/tag-namespace.json              # NEW — committed verbatim live snapshot (D-09)
.github/workflows/ci-observe.yml                 # EDIT — one new job (live drift read, D-11)
scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs   # NEW — offline guard (D-08)
test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json  # NEW — known-bad (D-09)
scripts/maintainers/delete-planning-tags.sh      # NEW — dry-run-default deletion (D-13)
.planning/decisions/003-tag-delete-list.tsv      # NEW — 39-row allowlist (D-12)
.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md  # EDIT — amendment (D-19)
MAINTAINING.md                                   # EDIT — 2 subsections (D-11 live check, D-13 runbook)
.planning/phases/238-.../238-TAG-RULESET-RECORD.md   # NEW — pre-change record (D-17)
.planning/phases/238-.../238-EVIDENCE.md             # NEW — slot ledger (D-16)
.planning/REQUIREMENTS.md                        # EDIT — only if REL-01 supersession fires (D-02)
```

**`ci.yml` is NOT edited.** The glob at `ci.yml:392` picks `p19` up with zero workflow edits:

```yaml
        run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```
with the comment immediately above it: *"A bare directory arg is NOT valid here (node 22
resolves it as a module); the shell glob is load-bearing."*
`[VERIFIED: .github/workflows/ci.yml:383-393]`

---

### Pattern 1 (Tier 1 — D-01/D-03): `tag_name_pattern` regex ruleset

Use **only if** D-01's probe succeeds. Exact body for `POST /repos/szTheory/sigra/rulesets`:

```json
{
  "name": "tag-namespace",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [
    {
      "type": "tag_name_pattern",
      "parameters": {
        "name": "v-prefixed three-component SemVer only",
        "operator": "regex",
        "negate": false,
        "pattern": "^v(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?\\n?$"
      }
    }
  ]
}
```

Schema facts, all confirmed:
- `target` ∈ `{branch, tag, push}`, default `branch`. `[CITED: docs.github.com/en/rest/repos/rules]`
- `tag_name_pattern.parameters` = `{name?, negate?, operator (required), pattern (required)}`;
  `operator` ∈ `{starts_with, ends_with, contains, regex}`. `[CITED: docs.github.com/en/rest/repos/rules]`
- `negate: true` means "the rule **fails** if the pattern matches" — so D-03's `negate: false`
  ("must match") is correct. `[CITED: docs.github.com/en/rest/repos/rules]`
- Rulesets support **RE2**; **negative lookahead `?!` is not supported**.
  `[VERIFIED: github/docs `data/reusables/repositories/rulesets-commit-regex.md`]`
- The base pattern above is GitHub's **own documented** SemVer regex, quoted verbatim from that
  reusable (with a `^v` prefix added and `\n?$` substituted for `$` — see below). GitHub's own
  "Matches / Does not match" line for it reads: *"Matches: `1.2.3`, `10.20.30`,
  `1.1.2-prerelease+meta`. Does not match: `1.2`, `1.2-SNAPSHOT`."* — i.e. it rejects
  two-component versions, which is exactly the recurrence class. `[VERIFIED: same reusable]`

> **⚠ Correction to D-03.** D-03 specifies `^v…$`. GitHub's own note says otherwise:
> *"When using end-of-line anchors in regular expressions, use `\n?$` rather than `$` alone.
> The optional `\n?` matches a trailing newline that may be present in Git push/CLI flows,
> while still working for commits created via the web UI and API."*
> `[VERIFIED: github/docs `data/reusables/repositories/rulesets-metadata-restrictions-notes.md`]`
> Note GitHub's *own published SemVer example* still uses bare `$` — the note is the newer,
> more specific guidance and should win. Use `\n?$`. If the plan keeps bare `$`, the SC-1
> "accept `v9.9.9-rulesettest`" probe is the thing that would catch it, so at minimum make
> that probe's outcome load-bearing rather than assumed.

---

### Pattern 2 (Tier 2 — **NEW, not in CONTEXT**): fnmatch-excluded `creation` rule

**This is the research finding that changes the fallback ladder.** D-02 rejects "a `creation`
rule scoped to `refs/tags/v*`" because it "is name-scoped rather than pattern-scoped and would
block release-please's own `v1.5.1` push outright." That is true of `include` alone — but
`conditions.ref_name` also carries an **`exclude`** list, and both sides are fnmatch.

```json
{
  "name": "tag-namespace",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*"],
      "exclude": ["refs/tags/v*.*.*"]
    }
  },
  "rules": [ { "type": "creation" } ]
}
```

Why this works:

| Fact | Evidence |
|------|----------|
| `Restrict creations` is **not** behind `repo-rules-enterprise` — it is the first `## ` section of the file, before any `ifversion` | `[VERIFIED: github/docs available-rules-for-rulesets.md:25-27` vs first `ifversion` at `:43]` |
| Its semantics: *"If selected, only users with bypass permissions can create branches or tags whose name matches the pattern you specify."* With `bypass_actors: []`, **nobody**. | `[VERIFIED: same file, `## Restrict creations`]` |
| `exclude` genuinely subtracts from `include`: *"you could include the default branch, include any branches matching the pattern `*feature*`, and then specifically exclude a branch matching the pattern `not-a-feature`."* | `[VERIFIED: github/docs `data/reusables/repositories/rulesets-target-branches.md`]` |
| fnmatch uses `File::FNM_PATHNAME`, so `*` does not cross `/` — but **`.` is an ordinary literal**, so `v*.*.*` is a valid three-dot-segment pattern | `[VERIFIED: github/docs `data/reusables/repositories/about-fnmatch.md`]` |

Behaviour, per SC-1's own probe tags:

| Tag | In `include`? | In `exclude`? | In ruleset scope? | Outcome |
|-----|---------------|---------------|-------------------|---------|
| `v9.9` | yes | **no** (`v*.*.*` needs two dots) | yes | **REJECTED** — `GH013 … Cannot create ref due to creations being restricted` |
| `v9.9.9-rulesettest` | yes | **yes** | no | **ACCEPTED** |
| `v1.5.1` (release-please) | yes | **yes** | no | **ACCEPTED** — D-02's objection dissolves |
| `v1.5.1-rc.1` | yes | **yes** | no | **ACCEPTED** |
| `v1.48`, `v1.5`, `v1.33` (delete-set) | yes | no | yes | creation blocked; **deletion unaffected** |
| `archive/*`, `phase-238-*`, future `milestone/`/`proof/` | no | — | no | untouched (D-07 holds unchanged) |

Three further consequences worth planning around:

1. **D-06's delete-deadlock cannot occur under Tier 2.** `deletion` is a *separate* rule type
   (`## Restrict deletions` — *"only users with bypass permissions can delete…"*), and this
   ruleset contains no `deletion` rule. A `creation` rule does not govern deletes. D-06's
   step-3 probe still runs (it is free), but its answer is structurally known in advance, and
   the `enforcement: "disabled"` flip window should not be planned as the likely branch.
2. **It is genuinely server-side.** REL-01's word "server-side" survives. The supersession D-02
   prescribes shrinks from *"detection + local prevention, not server-side prevention"* to
   *"server-side prevention at coarser granularity than a SemVer regex"* — a much smaller
   amendment, and one that keeps SC-1's two live observations literally satisfiable.
3. **State the weakness honestly, in these words.** `v*.*.*` admits `v1.2.3.4`, `v1.a.b`,
   `v1..`, `v...`. It is a *shape* guard, not a SemVer validator. It blocks the recurrence
   class (two-component `vX.Y`, which is 28 of the 39 tags being deleted and both of the
   post-ADR-003 regressions) and nothing more. The ADR amendment must say so.

`[VERIFIED: docs semantics above]` / `[ASSUMED: that POST /rulesets accepts this exact body on
this Free-tier repo — same probe class as D-01 and must be observed, not assumed]`

**Recommendation for plan 238-01:** issue **both** probes in the same task —
Tier 1 body with `enforcement: "disabled"` then `DELETE`, and Tier 2 body with
`enforcement: "disabled"` then `DELETE`. One write cycle, two recorded evidence slots, and the
whole downstream ladder resolves at once instead of serially.

---

### Pattern 3 (Tier 3 — D-02, unchanged): shift-left hook + detection workflow

Only if **both** probes fail. Note the repo has **no** hooks infrastructure today:
`git config core.hooksPath` is unset and `.git/hooks/` contains only `.sample` files
`[VERIFIED: local `git config core.hooksPath` (empty) and `ls .git/hooks/`]` — so D-02a's
"installed by a committed script" is genuinely new infrastructure, not a modification. Budget
for it accordingly; this is the most expensive tier, not the cheapest.

For the detection half, note ADR 003 guardrail 2 forbids `on: push: tags: 'v*'` **publish**
triggers. A *detection-only* workflow on the same trigger is not a publish path, but the ADR
amendment should say so explicitly or a future reader will read it as a regression.
`[VERIFIED: .planning/decisions/003-…md, guardrail 2]`

---

### Pattern 4 (D-08/D-09/D-10): the `p19` offline contract guard

Slot availability confirmed: `p01`–`p17` exist on disk, `p18-*` is reserved for SURF-04 by
`REQUIREMENTS.md`, so **`p19` is the correct next number**.
`[VERIFIED: `ls scripts/ci/prohibitions/` → p01..p17 + _lib.mjs; .planning/REQUIREMENTS.md SURF-04]`

Fixture directory holds 14 committed known-bad files (`p01`–`p13`, `p17`); `p17` is the most
recent pairing and the closest structural model. `[VERIFIED: `ls test/fixtures/prohibitions/`]`

The `_lib.mjs` contract the guard inherits:
- `subjectPath(defaultRelPath)` honours `GSD_PROHIB_SUBJECT`; **exactly one** substitutable
  artifact per guard — secondary artifacts read from their real locations via `readRepoFile`.
  `[VERIFIED: scripts/ci/prohibitions/_lib.mjs:33-38, and the p17 header restating it]`
- `readSubject` throws on a missing subject: *"a missing subject is a broken run, never an
  absent violation"*. `[VERIFIED: _lib.mjs:73-80]`
- Non-vacuity floors are mandatory. `p17` demonstrates the idiom with two explicit floor tests
  plus a fifth "negative control" test that runs the pure checker against an inline bad fixture
  — a second, cheaper RED proof alongside the committed-fixture one.
  `[VERIFIED: scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs, tests 1, 2, 5]`

**D-10 is correct and the reason is now documented verbatim:**

> "Note: To prevent leaking sensitive information, the `bypass_actors` property is only
> returned if the user making the API request has write access to the ruleset."
> `[CITED: docs.github.com/en/rest/repos/rules]`

Live confirmation of the asymmetry that D-11's two-step read depends on:

```bash
$ gh api repos/szTheory/sigra/rulesets --jq '.[0]|keys'
["_links","created_at","enforcement","id","name","node_id","source","source_type","target","updated_at"]
$ gh api repos/szTheory/sigra/rulesets/14941512 --jq 'keys'
["_links","bypass_actors","conditions","created_at","current_user_can_bypass","enforcement",
 "id","name","node_id","rules","source","source_type","target","updated_at"]
```
`[VERIFIED: live `gh api`, 2026-09-16]`

> **⚠ Small correction to D-11.** D-11 says *"`target`, `conditions` and `rules` come back only
> from the by-id call."* `target` **is** present on the list endpoint (see the key list above).
> Only `conditions`, `rules`, `bypass_actors` and `current_user_can_bypass` are by-id-only. The
> two-step read is still required — just for three fields, not four. This matters because
> `target` is one of the four things D-10 asks the guard to assert, and the observer can
> therefore short-circuit an obviously-wrong ruleset from the cheap call.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Selecting tags to delete | Any glob, `grep -E`, or `git tag -l 'v1.4*'` at the call site | The committed 39-row TSV, read row-by-row | `v1.4*` matches **both** `v1.4` and `v1.4.0` — both exist in this repo today, and `v1.4.0` backs a GitHub Release. This is not hypothetical; it is the literal footgun SC-3 names. `[VERIFIED: both tags present in `git tag`; `v1.4.0` in `gh release list`]` |
| Parsing the evidence ledger | A bespoke section parser | `parseEvidenceSlots` from `_lib.mjs` | Already generic across `.planning/phases/*/*-EVIDENCE.md`; `SLOT_HEADING_RE` is `/^##\s+((?:BEFORE\|AFTER)-[A-Z0-9-]+)\s*$/`. `[VERIFIED: _lib.mjs:254-262]` |
| Counting keep-set tags | A hardcoded `== 13` / `== 12` | Regex-derived set comparison (`comm`/`jq`/sorted diff) | D-14 forbids a hardcoded count; a count also passes when the *wrong* 13 tags survive. Assert **set equality**, not cardinality. |
| Reading the live ruleset from the PR lane | A `gh api` call inside `fast_checks` | Committed snapshot + `ci-observe.yml` | See §Alternatives Considered. |
| Wiring `p19` into CI | Any `ci.yml` edit | Nothing — the existing glob | A `ci.yml` edit risks the "renamed required context never reports" hazard the milestone repeatedly flags. |
| Recording the pre-change ruleset state | Prose description | Verbatim `gh api` JSON in `238-TAG-RULESET-RECORD.md` | 237's `237-PAGES-SETTING-RECORD.md` sets the precedent: revert by recorded value, never reconstruction. `[VERIFIED: 237-PAGES-SETTING-RECORD.md:1-20]` |

---

## Common Pitfalls

### Pitfall 1: SC-4's literal jq crashes on this `gh` version

**What goes wrong:** ROADMAP SC-4 prescribes `[.[]|select(.draft)]|length == 0`. Run against
`gh release list --json …`, that is an **error**, not a zero:

```bash
$ gh release list --limit 100 --json draft --jq '[.[]|select(.draft)]|length'
Unknown JSON field: "draft"
Available fields:
  createdAt  isDraft  isImmutable  isLatest  isPrerelease  name  publishedAt  tagName
```
`[VERIFIED: live, gh 2.95.0, 2026-09-16]`

**Why it happens:** `gh release list --json` exposes GraphQL-derived camelCase field names
(`isDraft`); the REST payload uses `draft`. SC-4's jq is REST-shaped.

**How to avoid:** Either use the REST route, where SC-4's expression is correct verbatim —

```bash
$ gh api repos/szTheory/sigra/releases --paginate --jq '[.[]|select(.draft)]|length'
0
```
— or use `gh release list --json isDraft --jq '[.[]|select(.isDraft)]|length'`. **Prefer the
REST route**: it keeps SC-4's literal text satisfiable and is not coupled to the `gh` version.
Note `gh release list` also **hides drafts from non-authors** in some views, which is a second
reason the REST enumeration is the honest oracle.

**Warning sign:** a "0" in an evidence slot that was actually a swallowed error. The slot must
carry the fenced command, and the command must be the REST one.

---

### Pitfall 2: `$` vs `\n?$` in the RE2 pattern (Tier 1 only)

**What goes wrong:** a bare `$` anchor can fail to match a tag name carrying a trailing newline
from a Git push/CLI flow, so a *valid* `v1.5.1` gets rejected — breaking release-please.

**Why it happens:** GitHub's rule evaluation sees the raw value; the CLI and web/API paths
differ. GitHub's own published SemVer example still uses bare `$`, which makes this easy to
copy wrong.

**How to avoid:** `\n?$`, per GitHub's explicit note. `[VERIFIED: rulesets-metadata-restrictions-notes.md]`

**Warning sign:** the SC-1 `v9.9.9-rulesettest` push is **rejected** when it should be accepted.
That probe is the detector — do not treat its success as a formality.

---

### Pitfall 3: assuming the SC-1 probe also proves release-please is safe

**What goes wrong:** SC-1 pushes a tag over **git**. release-please creates its tag as a side
effect of `POST /repos/{o}/{r}/releases` (the Releases API), a different route.

**Why it happens:** the phase's SC-1 text asserts the probe "doubles as … the empirical answer
to whether the ruleset blocks release-please's own `v1.5.1` push". It answers it for the git
route only.

**How to avoid:** Under **Tier 2**, this is moot — `v1.5.1` is excluded from the ruleset's
scope entirely, so no route is evaluated. Under **Tier 1**, say plainly in the evidence slot
that the git-route probe is *indicative*, and note that Phase 242 is the true observation. Do
not write "proven" where "indicative" is accurate. Corroborating field evidence that
ruleset-scoped tag pushes from CI tokens are **not** implicitly bypassed:
[oras-project/oras-go#1411 — "main release workflow cannot push tags; needs RELEASE_PAT to
bypass tag ruleset"] `[CITED: github.com/oras-project/oras-go/issues/1411]`.

**Warning sign:** Phase 242 (`242 depends on 238`) discovering at release time that `v1.5.1`
cannot be created. The blast radius of getting this wrong is a blocked release, so keep
`bypass_actors: []` **and** verify the exclusion, rather than relaxing the guard.

---

### Pitfall 4: D-16 overstates `p12`'s reach — a malformed `238-EVIDENCE.md` will NOT red `fast_checks`

**What goes wrong:** D-16 states that `_lib.mjs`'s parser "is generic across every
`.planning/phases/*/*-EVIDENCE.md`, and `p12` hard-fails a captured slot lacking a run id or
fenced command — a malformed ledger reddens `fast_checks` for the whole repo." The **parser**
is generic; the **guards** are not. Every evidence-reading guard pins Phase 230's ledger:

```
p01:19  p03:18  p08:21  p11:29  p12:26  p13:18
  const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
```
`[VERIFIED: grep over scripts/ci/prohibitions/*.test.mjs, 2026-09-16]`

**Why it matters:** the planner must not rely on `p12` to enforce `238-EVIDENCE.md`'s format.
Nothing mechanically checks it. The format discipline is still correct (it is the repo's
convention and future guards may generalize), but it is **convention-enforced, not
machine-enforced**, and any plan or SUMMARY claiming otherwise would be a dishonest-gate
instance in a milestone dedicated to removing those.

**How to avoid:** either state the limitation plainly in the phase artifacts, or — if the
planner wants the claim to be true — have `p19` additionally assert the 238 ledger's slot
grammar via `readRepoFile` (as a *secondary* artifact; the substitutable subject stays the
ruleset snapshot, per `_lib.mjs`'s one-subject rule). The second option costs ~10 lines and
converts a false claim into a true one. **Recommended.**

**Useful accident:** `parseEvidenceSlots` extracts "run ids" as `\b(\d{8,12})\b`. A
`rule_suite_id` is 10 digits (e.g. `4090653841`), so D-18's captured id satisfies that shape
naturally.

---

### Pitfall 5: `Evaluate` enforcement is not available on this repo

**What goes wrong:** a plan reaches for `enforcement: "evaluate"` to test the ruleset without
enforcing it.

**Why it happens:** it is the obvious tool and it is prominently documented.

**How to avoid:** `evaluate` (and the "Rule Insights" page behind it) is gated by the same
`repo-rules-enterprise` flag as metadata restrictions. `[VERIFIED: github/docs
`data/reusables/repositories/rulesets-about-enforcement-statuses.md`]` On Free, only `active`
and `disabled` exist — which is exactly why D-01's probe uses `disabled` and why D-06's fallback
uses a `disabled` flip window.

---

### Pitfall 6: the remote delete pass errors on any local-only tag

**What goes wrong:** `git push origin --delete v1.47` fails — `v1.47` never reached `origin`.

**Why it happens:** 18 of the 28 `vX.Y` tags are local-only (list in §Measured Starting State).

**How to avoid:** drive pass 3 from `remote=yes` rows only (D-14 already says this). Do **not**
paper over it with `|| true` — that would also swallow a genuine ruleset rejection.

**Warning sign:** a script that reports success on a run where every remote delete silently
no-op'd.

---

### Pitfall 7: rule-suite evidence expires

**What goes wrong:** the `rule_suite_id` captured for SC-1's RED is recorded, and by the time
anyone re-reads the ledger the API returns nothing.

**Why it happens:** `GET /rulesets/rule-suites` takes a `time_period` (default `day`, max
`month`) and requires **Administration: read** — a permission an Actions `GITHUB_TOKEN` cannot
be granted (no `administration:` key exists in a workflow `permissions:` block).

**How to avoid:** D-18 is right — capture locally as the owner and **embed the fetched JSON**.
Verified working today from the local `gh` auth:

```bash
$ gh api repos/szTheory/sigra/rulesets/rule-suites/4090653841 \
    --jq '{id,result,ref,rule_evaluations:[.rule_evaluations[]|{rule_type,result,details}]}'
{"id":4090653841,"result":"pass","ref":"refs/heads/main",
 "rule_evaluations":[{"rule_type":"required_status_checks","result":"pass","details":null}, …]}
```
`[VERIFIED: live `gh api`, 2026-09-16]` — note the **list** endpoint returns only
`{id, actor_*, before_sha, after_sha, ref, pushed_at, result}`; `rule_evaluations[]` is
**by-id only**, the same asymmetry as `/rulesets`.

---

## Code Examples

### Pre-change record capture (D-17), run before any write

```bash
gh api repos/szTheory/sigra/rulesets > /tmp/rulesets-before.json
for id in $(jq -r '.[].id' /tmp/rulesets-before.json); do
  gh api "repos/szTheory/sigra/rulesets/$id"
done | jq -s '.' > /tmp/rulesets-before-full.json
# embed BOTH payloads verbatim in 238-TAG-RULESET-RECORD.md
```

### D-01 + Tier-2 feasibility probes, one cycle (plan 238-01)

```bash
probe() {  # $1 = label, $2 = path to body json
  id=$(gh api -X POST repos/szTheory/sigra/rulesets --input "$2" --jq '.id' 2>&1) || {
    echo "$1: REJECTED -> $id"; return 1; }
  echo "$1: ACCEPTED id=$id"
  gh api "repos/szTheory/sigra/rulesets/$id"          # capture the round-tripped shape
  gh api -X DELETE "repos/szTheory/sigra/rulesets/$id"
}
# both bodies carry "enforcement": "disabled" — a disabled ruleset enforces nothing
probe tier1-tag_name_pattern /tmp/tier1-disabled.json
probe tier2-creation-excluded /tmp/tier2-disabled.json
```

### SC-1 live proof (after the chosen ruleset is `active`)

```bash
git tag v9.9 HEAD && git push origin v9.9                 # expect GH013 rejection
git tag v9.9.9-rulesettest HEAD && git push origin v9.9.9-rulesettest   # expect accept
# capture the RED by id, inside the time_period window:
SUITE=$(gh api 'repos/szTheory/sigra/rulesets/rule-suites?time_period=day&ref=refs/tags/v9.9' \
          --jq '[.[]|select(.result=="fail")][0].id')
gh api "repos/szTheory/sigra/rulesets/rule-suites/$SUITE"   # embed this JSON in the ledger
# then remove both scratch tags — the delete of the ACCEPTED one is D-06's probe:
git push origin --delete v9.9.9-rulesettest && git tag -d v9.9.9-rulesettest
git tag -d v9.9
```

### Per-side set-equality, regex-derived, no hardcoded count (D-14 / SC-3)

```bash
# LOCAL
git tag | sort > /tmp/local-after.txt
git tag | grep -E '^(v[0-9]+\.[0-9]+\.[0-9]+|archive/.*)$' | sort > /tmp/local-keep.txt
diff /tmp/local-after.txt /tmp/local-keep.txt \
  && echo "LOCAL set-equal to keep-set" || { echo "LOCAL DRIFT"; exit 1; }

# REMOTE  (archive/* is local-only — a shared expression would fail; D-14)
git ls-remote --tags origin | sed 's#.*refs/tags/##' | grep -v '\^{}' | sort > /tmp/remote-after.txt
grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' /tmp/remote-after.txt | sort > /tmp/remote-keep.txt
diff /tmp/remote-after.txt /tmp/remote-keep.txt \
  && echo "REMOTE set-equal to keep-set" || { echo "REMOTE DRIFT"; exit 1; }
```

**Positive control, mandatory.** A `diff` of two files derived from the same command is green
when *both* are empty. Assert a non-vacuity floor first (`[ -s /tmp/local-keep.txt ]` and a
line count > 10), in the `_lib.mjs` idiom: *"the parse broke, this is not a pass."*

### D-11 live drift read (new `ci-observe.yml` job)

```yaml
  tag_ruleset_drift:
    name: Tag namespace ruleset drift (live vs committed, not a merge gate)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: ${{ github.event.workflow_run.event != 'pull_request' }}
    permissions:
      contents: read
    env:
      GH_TOKEN: ${{ github.token }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Two-step read, then diff against the committed snapshot
        run: |
          set -euo pipefail
          ID=$(gh api "repos/${GITHUB_REPOSITORY}/rulesets" \
                 --jq '[.[]|select(.name=="tag-namespace")][0].id')
          [ -n "$ID" ] && [ "$ID" != "null" ] || { echo "::error::tag-namespace ruleset ABSENT"; exit 1; }
          gh api "repos/${GITHUB_REPOSITORY}/rulesets/${ID}" > live.json
          # compare only the fields D-10 names; bypass_actors is invisible at this token level
          jq -S '{target,enforcement,conditions,rules}' live.json > live-norm.json
          jq -S '{target,enforcement,conditions,rules}' .github/rulesets/tag-namespace.json > want-norm.json
          diff -u want-norm.json live-norm.json || { echo "::error::live ruleset DRIFTED from committed snapshot"; exit 1; }
```

Notes: both existing `ci-observe` jobs set `permissions: {contents: read, actions: read}` and
`GH_TOKEN: ${{ github.token }}`. The rulesets endpoint needs only **Metadata: read**, which
`contents: read` implies; `actions: read` is not needed here. `[VERIFIED: .github/workflows/ci-observe.yml:45-53; live payload readable with a repo-scoped token]`

**The caveat D-11 demands, verbatim from the file itself:**
> "NOTE: `workflow_run` only ever runs the copy of this file on the DEFAULT BRANCH. It
> therefore does nothing until it merges"
`[VERIFIED: .github/workflows/ci-observe.yml:23-25]`
State plainly in the SUMMARY that this half **cannot be proven in-phase**.

### TSV format (D-12), following `.github/ci-skip-manifest.tsv`

The precedent is a `#`-comment header block followed by a **tab-separated header row**, then
data rows — e.g. `tier<TAB>kind<TAB>id<TAB>parent_job_id<TAB>display_name<TAB>gate_level<TAB>gate<TAB>observer`.
`[VERIFIED: .github/ci-skip-manifest.tsv, header + first data rows]` Its header prose contains
the line worth reusing: *"Prose is now a RENDERER of this file, not a second source of truth."*

```
# .planning/decisions/003-tag-delete-list.tsv  — companion to ADR 003
# (comment header: why, when, who, and the exclusion rule for archive/*)
tag	local	remote	class	pre_delete_sha	reason
v1.0	yes	no	planning-milestone	<sha>	GSD milestone close-out tag; not a package version (ADR 003)
v1.48	yes	yes	planning-milestone	<sha>	minted 2026-08-12, AFTER ADR 003 — the recurrence this phase guards
phase-238-generated-auth-proof-325b3cfa	yes	yes	phase-proof	<sha>	proof tag from the EARLIER phase 238 (generated-auth runtime proof, Aug 2026) — name collision with the phase now being planned
```

`pre_delete_sha` capture (D-15's forward-feed to Phase 245):
```bash
git for-each-ref --format='%(refname:strip=2)%09%(objectname)%09%(*objectname)' refs/tags
```
(`%(*objectname)` dereferences annotated tags; `phase-238-*` and the `vX.Y` tags should be
checked for which kind they are before assuming `%(objectname)` is the commit.)

### `.planning/decisions/` is safe for a `.tsv`

```bash
$ grep -rn "planning/decisions" scripts test .github    # (no output)
```
`[VERIFIED: live grep, 2026-09-16]` — nothing in CI, scripts, or tests enumerates that directory
or assumes `*.md`, so adding a `.tsv` beside the ADRs breaks nothing.

---

## Runtime State Inventory

This is a **destructive ref-mutation** phase, so the inventory applies. Every category answered
explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | **None.** No database, no datastore holds a tag name. Verified: the delete-set strings appear nowhere in a persistence layer; the only "storage" is git's own ref namespace and GitHub's copy of it. | none |
| **Live service config** | **Two, both on GitHub, neither in git.** (1) Ruleset `14941512` (`source_type: "Repository"` = Settings-managed, not committed as code) — untouched by this phase but is the reason the *new* ruleset also has no git-side record, hence D-09's committed snapshot. (2) The new `tag-namespace` ruleset itself, once created. | D-17 pre-change record; D-09 committed snapshot; D-11 live drift read |
| **OS-registered state** | **None.** No Task Scheduler / launchd / pm2 entry references a tag. Verified: no hooks infrastructure exists either — `git config core.hooksPath` is unset and `.git/hooks/` holds only `.sample` files. *(Consequence: D-02a's hook is new infrastructure, not an edit.)* | none — unless Tier 3 fires |
| **Secrets / env vars** | **None touched.** `HEX_API_KEY` and `RELEASE_PLEASE_TOKEN` exist but neither encodes a tag name. `release-please.yml:92` reads `${{ secrets.RELEASE_PLEASE_TOKEN \|\| github.token }}` — relevant to D-05's actor question, but no key changes. | none |
| **Build artifacts / installed packages** | **One indirect, structurally safe.** `mix.exs:208` `source_ref: "v#{@version}"` → `v1.5.0`, which is in the keep-set. **Already-published HexDocs for 1.20.0 and earlier point at tags that were already absent** — unchanged by this phase. No egg-info/compiled-artifact analogue in Elixir here. | none — SC-4's `curl` is confirmation |
| **Ref-reachability (phase-specific 6th)** | The 11 `phase-238-*` tags are held by **two** local branches (`gsd/238-generated-auth-runtime-proof-evidence`, `gsd-reviewfix/247-29317`) and by `origin/gsd/238-generated-auth-runtime-proof-evidence` @ `78e08d09…`. `[VERIFIED: `git branch -a --contains`, `git ls-remote origin`]` Phase 245 lists that branch among its **prune candidates**, not its protected survivors. | `pre_delete_sha` column (D-12) is the forward-feed; Phase 245 SC-4 (no `git gc`/`reflog expire`/`--prune=now`) means nothing is collected in the interim |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Classic tag protection rules (`/repos/{o}/{r}/tags/protection`) | Repository **rulesets** (`/repos/{o}/{r}/rulesets`, `target: "tag"`) | Rulesets GA'd 2023; classic tag protection deprecated | Rulesets have **no implicit admin bypass**, layer additively, are readable by anyone with read access, and support enforcement-status toggling without deletion. `[CITED: docs.github.com about-rulesets]` |
| A guard that reads the live API on every PR | Committed snapshot + offline structural guard on PR, live read on a non-gate observer lane | Phase 230/231 in this repo | Removes `gh`/token/5xx from the pull_request critical path. `[VERIFIED: p12 header; ci-observe.yml header]` |
| Prose as the source of truth for a machine-checkable set | Committed data file; prose renders it | Phase 230 (`ci-skip-manifest.tsv`) | *"Prose is now a RENDERER of this file, not a second source of truth."* `[VERIFIED: .github/ci-skip-manifest.tsv header]` |

**Deprecated / not to reach for:**
- `enforcement: "evaluate"` and "Rule Insights" — enterprise-gated, unavailable here.
- Negative lookahead `?!` in a ruleset regex — RE2, unsupported.
- `DELETE /repos/{o}/{r}/git/refs/tags/{tag}` as a workaround for a blocked `git push --delete`
  — the API route is ruleset-evaluated too. `[ASSUMED — CONTEXT D-06 asserts this; GitHub does
  not document the delete-evaluation path either way, which is precisely why D-06 makes it an
  empirical probe. Do not state it as fact in any artifact.]`

---

## Project Constraints (from CLAUDE.md)

| Directive | Bearing on this phase |
|-----------|----------------------|
| **GSD Workflow Enforcement** — "Before using Edit, Write, or other file-changing tools, start work through a GSD command"; "Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it." | All Phase 238 file edits flow through `/gsd-execute-phase`. The destructive `git tag -d` / `git push --delete` steps are **repo-state mutations, not file edits**, and additionally need explicit operator authorization — the dry-run-default script (D-13) is the mechanism that keeps the default safe. |
| **`mix ci`, never root `mix test`, before every push** (also milestone standing constraint 3) | This phase touches no Elixir, but its commits still push through `mix ci`. The `p19` guard runs under the `ci.yml` glob, **not** `mix ci` (D-08, SURF-04, and milestone standing constraint 5 all forbid adding it). |
| **Local dev prerequisites** — `mix test` needs Dockerized Postgres via `scripts/db/up.sh` + `direnv`; golden tests need `phx_new 1.8.8` archive | Required for a green `mix ci` before pushing this phase's commits, even though no phase artifact touches Elixir. |
| **Public repo** (and memory: "sigra is public; no adopter PII") | The `238-EVIDENCE.md` embedded JSON must be scrubbed: no tokens, no `HEX_API_KEY`, no home-directory paths (the 237 worktree snapshot set that precedent). `rule_suite` payloads carry `actor_name`/`actor_id` — that is the repo owner and is already public. |
| **Testing: AAA style, flat, self-contained** | The `p19` guard follows the `p17` idiom (pure checker function + explicit non-vacuity floors + a negative-control test), which is the node:test expression of the same discipline. |
| **Minimal transitive deps** | Satisfied trivially — zero new dependencies. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI, authenticated | D-01 probe, SC-1, D-11, D-17, D-18, SC-4 | ✓ | 2.95.0 | — |
| `gh` auth with **repo-admin** scope on `szTheory/sigra` | `POST`/`DELETE /rulesets`, `GET /rule-suites` | ✓ (rule-suites read succeeded live, which requires Administration: read) | — | — |
| `git` push access to `origin` | SC-1 scratch tags, remote delete pass | ✓ | system | — |
| `jq` | set-equality, JSON normalization | ✓ | system + CI | — |
| Node 22 + `node --test` | `p19` | ✓ in CI (`fast_checks`) | — | — |
| Dockerized Postgres (`scripts/db/up.sh`) | `mix ci` before pushing | assumed available per CLAUDE.md | — | CI runs it regardless |
| `phx_new 1.8.8` archive | `mix ci` golden diff | assumed available per CLAUDE.md | 1.8.8 | CI pin is authoritative |
| **Harness permission to write repo settings** | D-01/Tier-2 probes, ruleset create | **✗ blocked during discussion** | — | **None.** This is the phase's one hard prerequisite. |

**Missing dependencies with no fallback:**
- **Repo-settings write authorization.** `238-CONTEXT.md` D-01 records that the probe "could not
  be run during discussion — the harness permission classifier blocks repo-settings writes".
  Everything from D-01 through D-06 is gated on this. The planner should make plan 238-01's
  first task an explicit operator-authorization checkpoint, so the phase does not discover the
  block mid-wave. All **read** calls (`GET /rulesets`, `GET /rulesets/{id}`,
  `GET /rule-suites`, `gh release list`) were exercised successfully during this research and
  are not blocked.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `node:test` (Node 22) for prohibition guards; ExUnit (`mix ci`) for the rest of the repo — **not used by this phase** |
| Config file | none — `node --test` needs no config; discovery is the `ci.yml:392` shell glob |
| Quick run command | `node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` |
| Full suite command | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (mirrors CI exactly) |
| RED proof command | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (must fail non-vacuously) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-01 | A non-SemVer `v*` tag is rejected server-side | live observation (not automatable in-repo) | `git push origin v9.9` → expect GH013, captured by `rule_suite_id` | ❌ Wave 0 (live, one-shot) |
| REL-01 | A SemVer `v*` tag is accepted | live observation | `git push origin v9.9.9-rulesettest` → expect success | ❌ Wave 0 (live, one-shot) |
| REL-01 | The committed snapshot has the required shape; an absent/altered ruleset fails | unit (offline, standing) | `node --test … p19-tag-namespace-ruleset.test.mjs` | ❌ Wave 0 |
| REL-01 | The guard is falsifiable | unit RED | `GSD_PROHIB_SUBJECT=…p19-tag-ruleset-absent-or-altered.json node --test …` | ❌ Wave 0 (fixture) |
| REL-01 | Live Settings drift is caught post-merge | integration (observer, post-merge only) | `ci-observe.yml` job `tag_ruleset_drift` | ❌ Wave 0 — **cannot be proven in-phase** (default-branch-only) |
| REL-02 | Delete set comes from the committed TSV, never a glob | unit (structural) | fold into `p19` as a secondary assertion, or a dry-run diff of script output vs TSV | ❌ Wave 0 |
| REL-02 | Post-deletion local set == regex keep-set | live assertion | `diff <(git tag\|sort) <(git tag\|grep -E '…'\|sort)` | ❌ Wave 0 (in script) |
| REL-02 | Post-deletion remote set == regex keep-set | live assertion | `diff` over `git ls-remote --tags origin` | ❌ Wave 0 (in script) |
| REL-02 | Release count unchanged, zero drafts | live assertion | `gh api repos/szTheory/sigra/releases --paginate --jq 'length'` and `'[.[]\|select(.draft)]\|length'` | ❌ Wave 0 (in script) |
| REL-02 | HexDocs "View source" resolves | live assertion | `curl -sSI` on a `hexdocs.pm/sigra/…` source link | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (fast, offline)
- **Per wave merge:** `MIX_ENV=test mix ci` (repo standing constraint 3) + the prohibition glob
- **Phase gate:** full `mix ci` green + all `238-EVIDENCE.md` slots `captured` at the final
  committed HEAD on a clean tree (milestone standing constraint 2)

### Wave 0 Gaps

- [ ] `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — REL-01
- [ ] `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` — REL-01 RED proof
- [ ] `.github/rulesets/tag-namespace.json` — the guard's subject; **cannot be written until the
      ruleset exists**, so it is created *after* D-01/Tier-2 resolves, not before
- [ ] `scripts/maintainers/delete-planning-tags.sh` — REL-02, with its own dry-run self-check
- [ ] `.planning/decisions/003-tag-delete-list.tsv` — REL-02
- [ ] `ci-observe.yml` job `tag_ruleset_drift` — REL-01 (unprovable in-phase; say so)
- [ ] No framework install needed.

**Ordering hazard for the planner:** `p19`'s subject is the committed snapshot, which does not
exist until the ruleset is created. A plan that writes `p19` before 238-01 resolves would have
`readSubject` throw *"subject not found … a missing subject is a broken run, never an absent
violation"* — which is the correct behavior but reds `fast_checks` for every intervening commit.
Sequence: probe → create ruleset → capture snapshot → write guard + fixture → prove RED.

---

## Security Domain

`security_enforcement` is not disabled in `.planning/config.json`, so this section is included.
This phase writes no application code; the relevant surface is **repository access control and
supply-chain integrity of the release namespace**.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no auth code changes |
| V3 Session Management | no | — |
| **V4 Access Control** | **yes** | Repository ruleset with `bypass_actors: []` — the control **is** the deliverable. No implicit admin bypass (confirmed: `current_user_can_bypass: "never"` on the existing ruleset). |
| **V5 Input Validation** | **yes** | The tag name is the input; the RE2 pattern (Tier 1) or the fnmatch exclusion (Tier 2) is the validator. RE2 is linear-time by construction — no ReDoS surface. |
| V6 Cryptography | no | no crypto |
| **V14 Configuration** | **yes** | The guard is *Settings* configuration with no git-side record; D-09's committed snapshot + D-11's live drift read are the configuration-drift control. |

### Known Threat Patterns for this phase's stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Release-namespace confusion — a `vX.Y` tag re-interpreted as package version `X.Y.0` (the ADR 003 footgun that produced phantom Hex `1.20.0`) | Spoofing | Server-side namespace guard (this phase) + ADR 003 guardrails 1–2 (publish never derives version from a tag) |
| Silent guard removal — the ruleset deleted in Settings, no diff, no signal | Tampering / Repudiation | D-11 live drift read on every post-merge run + the committed snapshot as the reference value |
| Over-broad glob deletion destroying a release-backing tag (`v1.4*` → `v1.4.0`) | Denial of Service (adopter-facing: HexDocs 404) | Committed explicit allowlist (D-12/D-13) + regex-derived per-side set-equality (D-14) + release-count/drafts assertion (SC-4) |
| Weakening the guard by adding a bypass actor to unblock a stuck push | Elevation of Privilege | D-05: `bypass_actors: []` is load-bearing; D-10 deliberately does **not** assert it in the CI guard because the assertion would be vacuous at CI token level — the assertion belongs to the operator check in `MAINTAINING.md` |
| Leaking a write credential into a public evidence file | Information Disclosure | Repo is public; embedded JSON is scrubbed before commit (237 precedent) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `POST /rulesets` with a `tag_name_pattern` rule returns `422`/`403` on this Free-tier User-owned repo. Docs-versioning evidence is strong (`repo-rules-enterprise` excludes `fpt`) but docs gating ≠ API enforcement. | Plan-Gating Verdict | **Low.** If the API accepts it, the phase gets the *better* Tier-1 outcome and no supersession is needed. D-01's probe settles it either way; this assumption only shapes plan ordering. |
| A2 | `POST /rulesets` **accepts** the Tier-2 body (`creation` rule + `ref_name.exclude`) on this repo. Every constituent piece is documented as non-enterprise, but the composition is not something I could observe without a write. | Architecture Pattern 2 | **Medium.** If rejected, the ladder falls to D-02's Tier 3 exactly as the CONTEXT already plans — no work is lost, but plan 238-01 must probe Tier 2 in the same cycle or the discovery costs a wave. |
| A3 | fnmatch `exclude` takes precedence over `include` in `conditions.ref_name` (i.e. a ref matching both is out of scope). Documented by example, not by an explicit precedence statement. | Architecture Pattern 2 | **Medium.** If precedence ran the other way, Tier 2 would block `v1.5.1` and break Phase 242's release. **Mitigation: the SC-1 `v9.9.9-rulesettest` accept-probe tests exactly this** — make its outcome an explicit gate, not a formality. |
| A4 | A `creation`-only ruleset does not restrict ref **deletion** (deletion is governed solely by the separate `deletion` rule type). | Architecture Pattern 2, Pitfall notes | **Low.** D-06's step-3 probe answers it empirically at zero extra cost, and the `disabled`-flip fallback already exists. |
| A5 | The rulesets endpoint is readable by the default Actions `GITHUB_TOKEN` with only `permissions: contents: read` on this public repo (D-11's premise). Verified readable with a local repo-scoped token, not with an Actions token. | Code Examples (ci-observe job) | **Low–Medium.** If it needs more, add `permissions: {contents: read, metadata: read}` — but note this half is unprovable until merged anyway, so the first real signal is post-merge. Plan for a follow-up todo if it 403s. |
| A6 | `DELETE /repos/{o}/{r}/git/refs/tags/{tag}` is ruleset-evaluated (CONTEXT D-06's note). GitHub documents neither direction. | State of the Art | **Low.** Only matters in the D-06-blocked branch, where the `disabled` flip is the answer regardless. Do not state it as fact in any artifact. |
| A7 | `phase-238-*` tags are lightweight (not annotated), so `%(objectname)` is the commit sha for `pre_delete_sha`. Not checked. | Code Examples (TSV) | **Low.** `git for-each-ref` with both `%(objectname)` and `%(*objectname)` captures either case; use both columns or verify first. |

---

## Open Questions

1. **Does `POST /rulesets` accept `tag_name_pattern` on GitHub Free?**
   - **What we know:** GitHub's docs source gates the entire metadata-restriction family behind
     `repo-rules-enterprise` (`ghec` + `ghes >3.10`, no `fpt`), and the flag's own comment calls
     them "enterprise-only". This repo is User-owned, public, `plan: null`.
   - **What's unclear:** whether API enforcement matches docs gating.
   - **Recommendation:** run D-01's probe as planned; **plan for the NO**.

2. **Does `POST /rulesets` accept the Tier-2 `creation` + `exclude` composition?**
   - **What we know:** `Restrict creations`, `target: "tag"`, and `ref_name.exclude` are each
     documented as generally available; the docs give an include-then-exclude example.
   - **What's unclear:** the composition, live, on this repo.
   - **Recommendation:** probe it in the **same** cycle as D-01. This is the single highest-value
     change to the phase plan that this research suggests.

3. **Is the ruleset evaluated on a tag *delete* push?**
   - **What we know:** undocumented either way; D-06 makes it empirical.
   - **What's unclear:** —
   - **Recommendation:** D-06's sequence is correct and costs nothing extra. Under Tier 2 the
     answer is structurally "no" (no `deletion` rule), which is a reason to prefer Tier 2 beyond
     its plan availability.

4. **Should `p19` also assert the 238 evidence ledger's slot grammar?**
   - **What we know:** no guard reads any ledger but Phase 230's; D-16's premise that a malformed
     238 ledger reds `fast_checks` is **false at HEAD**.
   - **What's unclear:** whether the phase wants to make the claim true or narrow it.
   - **Recommendation:** make it true — ~10 lines, secondary artifact via `readRepoFile`, keeps
     the ledger honest and fixes a claim that would otherwise be a dishonest-gate instance in the
     milestone dedicated to removing them.

5. **Should D-19's amendment correct ADR 003's "stopped after `v1.35`" sentence?**
   - **What we know:** `v1.47` (2026-08-04) and `v1.48` (2026-08-12, on `origin`) were minted
     after the ADR was written on 2026-07-11.
   - **What's unclear:** nothing.
   - **Recommendation:** yes — correct it, do not merely extend guardrail 3. An ADR that states
     a false fact about the very recurrence this phase guards is worse than no ADR.

---

## Sources

### Primary (HIGH confidence)

- **Live repo, 2026-09-16:** `git tag`, `git ls-remote --tags origin`, `git log -1` on
  `v1.35`/`v1.47`/`v1.48`, `git branch -a --contains`, `git config core.hooksPath`,
  `ls .git/hooks/`
- **Live GitHub API, 2026-09-16:** `gh api repos/szTheory/sigra`,
  `…/rulesets`, `…/rulesets/14941512`, `…/rulesets/rule-suites`,
  `…/rulesets/rule-suites/4090653841`, `…/releases --paginate`, `gh release list`
- **github/docs source (raw), 2026-09-16:**
  `content/.../managing-rulesets/available-rules-for-rulesets.md`,
  `content/.../managing-rulesets/about-rulesets.md`,
  `content/.../managing-rulesets/creating-rulesets-for-a-repository.md`,
  `data/features/repo-rules-enterprise.yml`,
  `data/reusables/gated-features/repo-rules.md`,
  `data/reusables/repositories/rulesets-commit-regex.md`,
  `data/reusables/repositories/rulesets-metadata-restrictions-notes.md`,
  `data/reusables/repositories/rulesets-about-enforcement-statuses.md`,
  `data/reusables/repositories/rulesets-target-branches.md`,
  `data/reusables/repositories/about-fnmatch.md`
- **This repo, read this session:** `mix.exs:200-215`, `.planning/decisions/003-…md`,
  `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `scripts/ci/prohibitions/_lib.mjs`,
  `scripts/ci/prohibitions/p12-…mjs`, `scripts/ci/prohibitions/p17-…mjs`,
  `.github/workflows/ci.yml:50-80, 375-400`, `.github/workflows/ci-observe.yml`,
  `.github/workflows/release-please.yml:85-100`, `.github/ci-skip-manifest.tsv`,
  `MAINTAINING.md:90-135`, `237-EVIDENCE.md`, `237-PAGES-SETTING-RECORD.md`,
  `.planning/config.json`

### Secondary (MEDIUM confidence)

- [docs.github.com/en/rest/repos/rules](https://docs.github.com/en/rest/repos/rules) — rule type
  enum, `target` values, `tag_name_pattern.parameters`, `bypass_actors` visibility note

### Tertiary (LOW confidence)

- [github.com/oras-project/oras-go#1411](https://github.com/oras-project/oras-go/issues/1411) —
  field corroboration that CI-token tag pushes are ruleset-evaluated with no implicit bypass
- Community discussions on `GH013 Repository rule violations found` — corroborate the error
  string `Cannot create ref due to creations being restricted` for a `creation` rule

---

## Metadata

**Confidence breakdown:**
- Measured starting state (tags, releases, `source_ref`, ruleset, plan): **HIGH** — every number
  reproduced live today; ROADMAP/CONTEXT counts match exactly.
- Ruleset REST schema and rule semantics: **HIGH** — official REST reference plus docs source.
- Plan-gating verdict: **MEDIUM-HIGH** — docs source is unambiguous; the API has not been
  probed (harness-blocked during discussion, and this research does not perform repo-settings
  writes).
- Tier-2 `creation`+`exclude` design: **MEDIUM** — every constituent documented, composition
  unobserved. Must be probed, not assumed.
- Repo-side integration points (`ci.yml` glob, `_lib.mjs` contract, fixture pattern, TSV format,
  `.planning/decisions/` safety): **HIGH** — read at HEAD this session.
- Pitfalls 1 and 4: **HIGH** — both reproduced/greped live; both are corrections to text that
  currently exists in the ROADMAP and CONTEXT.

**Research date:** 2026-09-16
**Valid until:** 2026-10-16 (30 days) for the repo-side facts; **7 days** for the GitHub
plan-gating verdict — ruleset feature availability moves, and a single successful D-01 probe
supersedes this entire section.
