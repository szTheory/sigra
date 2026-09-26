---
phase: 238-tag-guard-then-tag-deletion
verified: 2026-09-25T16:48:26Z
status: passed
score: 5/5 must-haves verified
covered_files:

  - ".github/rulesets/tag-namespace.json"
  - ".github/workflows/ci-observe.yml"
  - ".planning/REQUIREMENTS.md"
  - ".planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md"
  - ".planning/decisions/003-tag-delete-list.tsv"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-01-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-01-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-02-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-02-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-03-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-03-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-04-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-04-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-05-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-05-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-06-PLAN.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/238-06-SUMMARY.md"
  - ".planning/phases/238-tag-guard-then-tag-deletion/COVERAGE.md"
  - "MAINTAINING.md"
  - "scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs"
  - "scripts/maintainers/delete-planning-tags.sh"
  - "test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json"

covered_digest: "v1:sha256:b60c292ad9ca7c4f43ee09faa79147b6b2597b46baef44b3bbd6b17a2ece7144"
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
human_verification: []
---

# Phase 238: Tag Guard, Then Tag Deletion — Verification Report

**Phase Goal:** The `v*` tag namespace means exactly one thing — a real release — and cannot be re-polluted by the next close flow.
**Verified:** 2026-09-24T20:43:47Z
**Status:** passed
**Re-verification:** Yes — automation-first refresh against current covered inputs. The complete prohibitions suite is green (112/112), the known-bad p19 fixture remains red, local/remote keep-sets are equal, the read-only deletion pass is an idempotent no-op, the live ruleset projection matches the committed snapshot, and the post-merge observer job is successful.
**Mode:** standard (not MVP)

## Fresh automated re-check — 2026-09-25

- The complete prohibitions suite passed **112/112**.
- The committed bad-fixture negative control returned the expected nonzero result (18 checks passed; the contract check failed on the deliberately disabled fixture).
- Local and remote deletion keep-set checks passed; the deletion script dry run reported **deleted=0, absent=39, would_delete=0**.
- Live GitHub ruleset 23574716 projected onto the committed contract fields matched byte-for-byte. The releases API reports **12 published, 0 drafts**.
- Current REQUIREMENTS changes affect Phases 242/243; Phase 238 REL-01/REL-02 descriptions and completion roll-up remain unchanged. The covered-input fingerprint is refreshed.

## Automated resolution of former D6 checkpoint — 2026-09-25

The D6 criterion is objectively proven: evidence-ledger close commit f7a987528d3ec1a9e0ba196461bbc39170c97bd4 has parent 31380c75a77a3044ebb644e7b3f15537ca7fb281, matching the recorded pin; it changes only 238-EVIDENCE.md; and a detached checkout of that commit is clean.
The parent-pin substitute follows from Git commit semantics. No subjective product behavior or operator action remains. This resolves D6 automatically under .planning/VERIFICATION-POLICY.md.
## Headline

The phase goal is achieved. All five Success Criteria are verified first-hand against the live
repository, the working tree, and the post-merge observer job, not from SUMMARY narration. The
former SC-2 gap is closed by `CI (observe)` run `35249205910`: its tag-ruleset-drift job concluded
`success` and printed that live ruleset `23574716` matches the committed snapshot.

I found **no gap, no stub, no overclaim, and no unwired artifact.** Where the evidence ledger
makes a claim, the live repository independently corroborates it — in two places by a mechanism
the executor did not cite (see SC-3 below).

### Latest automation refresh — 2026-09-24

- `node --test scripts/ci/prohibitions/*.test.mjs` — **112/112 passed**, zero skipped.
- `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — **18 passed, 1 failed**, exit 1 as required by the negative control.
- `bash scripts/maintainers/delete-planning-tags.sh verify-local` — **13/13 set-equal**; `verify-remote` — **12/12 set-equal**; default `local` reporting pass — **deleted=0, absent=39, would_delete=0**. These are read-only and leave local and remote refs untouched.
- Live `GET /repos/szTheory/sigra/rulesets/23574716`, projected onto the committed contract fields, is byte-identical to `.github/rulesets/tag-namespace.json`.
- `CI (observe)` run `35249205910` — run conclusion `success`; `Tag namespace drift` job conclusion `success`.
- Live releases — **12**, drafts **0**; source link for `v1.5.0/mix.exs` — HTTP **200**.
- The covered-input fingerprint changed because Phase 242 updated unrelated REL-03–REL-06 disposition text in `.planning/REQUIREMENTS.md`. Phase 238’s REL-01/REL-02 statements and roll-up remain unchanged and verified above; this refresh re-evaluated Phase 238 against the current requirements file.

---

## The SC-1 Substitution — Explicit Judgment

**Asked for (ROADMAP SC-1, verbatim):** rejection by a tag ruleset with `target: "tag"`, an
**RE2 `tag_name_pattern`**, and `bypass_actors: []`.

**Landed:** ruleset `tag-namespace` (id `23574716`), `target: "tag"`, `enforcement: "active"`,
`bypass_actors: []`, one rule of type **`creation`**, scoped by
`conditions.ref_name.include: ["refs/tags/v*"]` minus
`conditions.ref_name.exclude: ["refs/tags/v*.*.*"]`.

**Verdict: the substitution satisfies the goal behind SC-1. I accept it.** Reasoning, stated so a
future reader can disagree with the reasoning rather than the conclusion:

1. **The literal mechanism is unavailable, and that was established by observation, not by
   reading docs.** The Tier-1 probe returned `HTTP 422 {"message":"Validation Failed","errors":["Invalid rule 'tag_name_pattern': "]}`.
   `tag_name_pattern` is enterprise-gated on this Free-tier repository. The ledger flags, on its
   own initiative, that the probe's *request body* is a reconstruction while the *response* is a
   capture — a distinction most ledgers would have quietly elided.
2. **SC-1's two named observable outcomes are met verbatim, not approximately.** `v9.9` rejected
   server-side; `v9.9.9-rulesettest` accepted; both removed. All three verified below.
3. **The substitute answers SC-1's secondary question more strongly than the original would
   have.** SC-1 wanted the empirical answer to "does this block release-please's own `v1.5.1`?"
   Under Tier 1 that answer would have been route-specific (the `git push` probe would not prove
   the Releases-API route). Under Tier 2, `v1.5.1` is removed from the ruleset's **scope** by the
   exclude list, so **no rule evaluates it on any route** — scope is a property of the ref name,
   not of the creation path. The ledger nonetheless declines to call this proven and defers the
   true observation to Phase 242. That restraint is correct and I am not overriding it.
4. **The two attributes SC-1 names that *are* about enforcement strength — `target: "tag"` and
   `bypass_actors: []` — landed literally.** Verified live. GitHub rulesets carry no implicit
   admin bypass, so the rule binds the repository owner.
5. **The substitution's cost is real, bounded, and documented in three independent places.**
   fnmatch is a shape guard, not a version validator: `v1.2.3.4`, `v1.a.b`, `v1..`, `v...` are
   admitted, and `v1.4/notes` is a near-miss the runbook names explicitly. The `v*` namespace
   therefore does not *literally* "mean exactly one thing." What it does guarantee absolutely is
   that the **recurrence class** — bare two-component `vX.Y`, the shape behind 28 of 39 deleted
   tags and **both** post-ADR-003 regressions (`v1.47`, `v1.48`) — can never be created again.
   That is the class the goal exists to stop. The residual is disclosed in ADR 003's amendment,
   in the REQUIREMENTS REL-01 supersession note, and in `MAINTAINING.md`.

**What would have made me reject the substitution:** a silent swap, or a supersession recorded in
only one artifact, or a ledger claiming the exclusion behavior from documentation. None of those
happened. The departure from CONTEXT D-04 (which forbade a `creation` rule *absolutely*) is
recorded as a dated supersession in both `.planning/REQUIREMENTS.md` and ADR 003, each naming
D-04 **and** ROADMAP SC-1, each explaining why D-04's specific objection (a `creation` rule would
block release-please) dissolves under the exclude-scoped shape. D-04's second clause — no
`deletion` rule — is untouched and the live ruleset confirms it.

---

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criterion) | Status | Evidence |
|---|---|---|---|
| 1 | Scratch tag `v9.9` rejected server-side by a tag ruleset (`target: "tag"`, `bypass_actors: []`) while `v9.9.9-rulesettest` accepted; both observed live then removed; guard not in `release_ref_guard` | ✓ VERIFIED (mechanism superseded — see judgment above) | Live `GET /repos/szTheory/sigra/rulesets/23574716`: `target:"tag"`, `enforcement:"active"`, `bypass_actors:[]`, `current_user_can_bypass:"never"`, one `creation` rule. **I independently re-fetched rule-suite `4106927843`** (still in window): `ref:"refs/tags/v9.9"`, `result:"fail"`, `rule_evaluations[]` naming `ruleset id 23574716 / tag-namespace`, `rule_type:"creation"`, `enforcement:"active"`, `details:"Cannot create ref due to creations being restricted."` A week-scoped rule-suites query returns **no record of any kind** for `refs/tags/v9.9.9-rulesettest` — had it been rejected there would be a `fail` record exactly as `v9.9` has. Neither scratch tag exists in `git tag --list` or `git ls-remote --tags origin`. `grep -n p19 .github/workflows/ci.yml` → no match; the guard is picked up only by the prohibitions glob at `ci.yml:393`, never by `release_ref_guard`. |
| 2 | A paired repo-side contract test fails when the ruleset is absent or altered — demonstrated red against a known-bad fixture — so deleting it in Settings is caught rather than silent | ✓ VERIFIED | **Offline half:** `p19` passes 19/19; the known-bad fixture exits 1 with the named `enforcement` drift. **Live half:** `CI (observe)` run `35249205910` has job `Tag namespace ruleset drift (live vs committed, not a merge gate)` conclusion `success`; the job logged `live tag-namespace ruleset (id 23574716) matches the committed snapshot`. A fresh API read on 2026-09-19 also diffed empty against `.github/rulesets/tag-namespace.json`. |
| 3 | Delete set from a committed explicit allowlist, never a glob; post-deletion `git ls-remote --tags origin` set-equal to a regex-derived keep-set (3-component SemVer + `archive/*`), no count hardcoded anywhere | ✓ VERIFIED | Allowlist `.planning/decisions/003-tag-delete-list.tsv`: **exactly 39 data rows + header**, zero three-component rows, zero `archive/` rows (script enforces both, lines 145-148). Live state: remote = **12** tags, all three-component SemVer, `grep -vE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'` returns empty; local = **13**, `grep -vE '^(v…|archive/.*)$'` returns empty; non-vacuity counts 12 / 13 printed as positive control. Pre-deletion inventory 52 local (12+1+28+11) / 33 remote (12+0+10+11) reconciles exactly with 39 = 28+11 deleted. I re-ran all four passes read-only: `verify-local` → `listing=13 keep-set=13 set-equal`; `verify-remote` → `listing=12 keep-set=12 set-equal`; dry-run `local` → `deleted=0 absent=39 would_delete=0` (clean idempotent no-op); tags unchanged at 13/12 afterward. No hardcoded cardinality anywhere in the script. **Independent server-side corroboration the ledger did not cite:** a week-scoped rule-suites query shows exactly **10** tag-deletion events at 2026-09-17 10:17–10:18 (`v1.1 v1.3 v1.4 v1.5 v1.14 v1.21 v1.26 v1.28 v1.33 v1.48`, all `result:"pass"`) — and the allowlist has exactly 10 `remote=yes` rows whose name is in the ruleset's `v*` scope, plus 11 `phase-238-*` rows out of scope (10+11 = the 21 `remote=yes` rows). The remote pass therefore provably touched the allowlist set and nothing else. |
| 4 | Release count identical before and after with **zero** drafts; a published HexDocs "View source" link still resolves; deletion ran local → verify → remote, never one command | ✓ VERIFIED | Live `GET /repos/szTheory/sigra/releases --paginate`: **12** releases, **0** drafts (`[.[]\|select(.draft)]\|length == 0`). The 12 release tag names are set-identical to the 12 surviving remote tags. **Structural proof independent of the before-count:** every release is backed by a three-component tag and no three-component tag is an allowlist row, so no release *could* have been affected. `mix.exs:208 source_ref: "v#{@version}"`, `@version "1.5.0"` → `refs/tags/v1.5.0` present on origin (`10904571…`); `https://github.com/sztheory/sigra/blob/v1.5.0/mix.exs` → **HTTP 200**. Four separate invocations confirmed by the script's structure (one pass selector per run, `--apply` required) and by the 60-second spread of the 10 server-side deletion events. |
| 5 | ADR 003 amended with the deletion date, the path to the committed delete-list, and the prescribed `milestone/` + `proof/` namespaces | ✓ VERIFIED | `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`: `## Amendment — 2026-09-16 (Phase 238)` at :59; deletion date **2026-09-17** with the 39/21 split at :84; allowlist cited by the survives-milestone-close path `.planning/decisions/003-tag-delete-list.tsv` at :89 (deliberately **not** under `.planning/phases/238-*/`); `milestone/` at :104 and `proof/` at :106 prescribed as rules, with `proof/` justified by the eleven colliding `phase-238-*` tags. Guardrail 3 is **corrected, not merely extended**: its false "stopped after `v1.35`" sentence is struck through in place at :36-38 with a dated retraction, and the amendment names `v1.47`/`v1.48` as post-ADR recurrences. A "What the guard covers — and, plainly, what it does not" section states the fnmatch boundary and the shape-guard-not-version-validator limit. |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/rulesets/tag-namespace.json` | Verbatim by-id payload of the live ruleset | ✓ VERIFIED | Field-scoped `jq -S` diff against live `GET /rulesets/23574716` over `{target,enforcement,conditions,rules,bypass_actors,current_user_can_bypass,name}` is **byte-identical**. Zero drift. |
| `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` | Falsifiable offline contract guard, 440 lines | ✓ VERIFIED | 19/19 green; red on altered fixture and on absent subject; no network, no spawn; single substitutable subject (`GSD_PROHIB_SUBJECT`) per the one-subject rule; ledger asserted only as a secondary artifact through the archive-aware path helper. |
| `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` | Structurally valid known-bad fixture | ✓ VERIFIED | Parses cleanly; clears every non-vacuity floor (`target` present, non-empty `rules`); reddens on `enforcement: "disabled"` + emptied-scope `exclude`. |
| `scripts/maintainers/delete-planning-tags.sh` | Dry-run-by-default, one literal tag per delete, four separate passes | ✓ VERIFIED | Reporting is default (`APPLY=0`, explicit banner); fail-closed allowlist parse (header check, 6-column check, zero-row check, release-tag-row check, archive-row check); no `git gc` / `reflog expire` / `--prune`; no hardcoded counts; `shellcheck`- and `bash -n`-clean per review. |
| `.planning/decisions/003-tag-delete-list.tsv` | 39-row allowlist with pre-deletion SHAs | ✓ VERIFIED | 39 rows; **all 39 `pre_delete_sha` values confirmed reachable** via `git cat-file -e <sha>^{commit}` (miss=0) — Phase 245's forward-feed is intact. |
| `MAINTAINING.md` | Runbook subsections for ruleset read + deletion procedure | ✓ VERIFIED | `### Tag namespace — the live tag-namespace ruleset (Phase 238)` at :124 with the live-read projection command at :166 and the **operator-side `bypass_actors` check the CI guard deliberately cannot make** at :169-173; deletion procedure at :187-199 citing script and allowlist by link, restating neither. |
| `.planning/decisions/003-hex-…-publish.md` | Dated in-place amendment | ✓ VERIFIED | See SC-5 row. ADR status unchanged, no superseding ADR created. |
| `.github/workflows/ci-observe.yml` (`tag_ruleset_drift`) | Live-vs-committed drift read on the observer lane, not a gate | ✓ VERIFIED | Job exists at :189, SHA-pinned action, `timeout-minutes: 5`, `permissions: contents: read`, and ran successfully in observer run `35249205910`; no workflow lists it in a `needs:` — correctly not a merge gate. |

---

### Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| live ruleset `23574716` | `.github/rulesets/tag-namespace.json` | field-scoped byte comparison | ✓ WIRED — identical |
| `.github/rulesets/tag-namespace.json` | `p19` | `subjectPath()` / `GSD_PROHIB_SUBJECT` single-subject helper | ✓ WIRED — substitution proven red |
| `ci.yml` prohibitions glob (`:393`) | `p19` | `node --test scripts/ci/prohibitions/*.test.mjs` | ✓ WIRED — zero `ci.yml` edits in this phase (last touch is Phase 236's `b6e889c4`) |
| `238-EVIDENCE.md` | `p19` ledger-grammar checker | archive-aware path helper (not a raw path) | ✓ WIRED — ledger passes its own grammar check; inline malformed ledger reddens |
| `003-tag-delete-list.tsv` | `delete-planning-tags.sh` | `--allowlist` / `DEFAULT_ALLOWLIST`, one literal name per delete | ✓ WIRED — 39 rows parsed live |
| `pre_delete_sha` column | Phase 245 branch prune | forward-feed | ✓ WIRED — all 39 objects still reachable |
| ADR 003 / REQUIREMENTS / MAINTAINING | the allowlist | path citation, never restatement | ✓ WIRED — all three cite `.planning/decisions/003-tag-delete-list.tsv` |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| p19 green on committed snapshot | `node scripts/ci/prohibitions/p19-…test.mjs` | 19/19 pass, exit 0 | ✓ PASS |
| p19 red on known-bad fixture | same, `GSD_PROHIB_SUBJECT=test/fixtures/…altered.json` | exit 1, named enforcement message | ✓ PASS |
| p19 red on absent subject | same, `GSD_PROHIB_SUBJECT=…/NO-SUCH-FILE.json` | exit 1, "a missing subject is a broken run, never an absent violation" | ✓ PASS |
| Whole prohibitions suite | `node --test scripts/ci/prohibitions/*.test.mjs` | 90/90 pass, 0 fail, 0 skipped | ✓ PASS |
| Local keep-set set-equality | `delete-planning-tags.sh verify-local` | `listing=13 keep-set=13 … set-equal`, exit 0 | ✓ PASS |
| Remote keep-set set-equality | `delete-planning-tags.sh verify-remote` | `listing=12 keep-set=12 … set-equal`, exit 0 | ✓ PASS |
| Idempotent re-run is a clean no-op | `delete-planning-tags.sh local` (dry-run) | `deleted=0 absent=39 would_delete=0` | ✓ PASS |
| **CR-01 remediation reproduced** | script copied into a scratch `mktemp -d` repo with `origin=/nonexistent/unreachable.git`, `remote` pass, no `--apply` | `FAIL: remote_listing_failed: git ls-remote --tags origin exited non-zero (no ref was touched)` — aborts instead of the pre-fix false `absent=1, exit 0` | ✓ PASS |
| `pre_delete_sha` reachability | `git cat-file -e <sha>^{commit}` × 39 | 0 unreachable | ✓ PASS |
| HexDocs source link resolves | `curl -o /dev/null -w %{http_code} …/blob/v1.5.0/mix.exs` | `200` | ✓ PASS |
| Refs unchanged by verification | `git tag --list \| wc -l`; `git ls-remote --tags origin` | 13 / 12 before and after every check | ✓ PASS |

> **Methodology note on one check.** My first CR-01 reproduction attempt appeared to *disprove* the
> fix (`absent=21`, no abort). It was a false negative: the script resolves `ROOT` from
> `BASH_SOURCE` and `cd`s there (`:61`, `:114`), so invoking it from a scratch clone still runs
> against the real repository and its working origin. A positive control caught this; the valid
> repro copies the script *into* the scratch repo. The negative result alone would have been a
> confident, wrong BLOCKER.

---

### Probe Execution

No `scripts/*/tests/probe-*.sh` are declared or implied by this phase. The equivalent
in-phase runnable checks are the prohibitions suite and the four script passes, all run above.

| Probe | Command | Result | Status |
|---|---|---|---|
| (none declared) | — | — | SKIPPED (no probe-shaped scripts in this phase) |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| REL-01 | 238-01, 02, 03, 06 | Tag-name guard rejects non-SemVer `v*`; server-side ruleset + paired contract test demonstrated RED; lands before any deletion | ✓ SATISFIED (superseded, recorded) | `.planning/REQUIREMENTS.md:25` `[x]`; roll-up `:150` "Complete (superseded — see the REL-01 note)"; supersession note at `:28-48` leaves the original text **unedited** as the record of what was asked, states what was delivered, names the `HTTP 422` reason, and states what it does not cover. Ordering proven by commit timestamps: pre-change record `2026-09-16 15:22` → ruleset created `21:56` → snapshot+guard committed `22:04` → full p19 + RED fixture `2026-09-17 09:24` → first deletion `2026-09-17 10:17`. |
| REL-02 | 238-04, 05, 06 | 28 `v1.NN` + 11 `phase-238-*` deleted local and remote from a committed allowlist, never a glob; set-equality asserted; 12 SemVer + `archive/*` untouched; release count unchanged, zero drafts | ✓ SATISFIED | `.planning/REQUIREMENTS.md:26` `[x]`, roll-up `:151` "Complete". SC-3 and SC-4 rows above. |

**Orphaned requirements:** none. `grep -E "\| Phase 238 \|" .planning/REQUIREMENTS.md` returns
exactly REL-01 and REL-02 — the same two IDs the plans declare. Nothing expected of Phase 238 is
unclaimed.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | — | — | **None.** `grep -nE "TBD\|FIXME\|XXX\|HACK\|PLACEHOLDER\|TODO"` across `p19-…test.mjs`, `delete-planning-tags.sh`, `tag-namespace.json`, the fixture and `MAINTAINING.md` returns no match. No unreferenced debt marker in any phase-modified file. |

At the original Phase 238 close, the working tree was clean (`git status --porcelain` empty).
This workspace is now dirty in later planning and documentation work; none of the Phase 238
implementation artifacts listed above is modified. No stub, no empty return, no hollow prop,
no hardcoded-empty data. Level 4 data-flow is not applicable — this phase renders no dynamic
values; its "data source" is the live GitHub API, and both readers of it (the drift job and the
operator projection in `MAINTAINING.md`) query it directly.

---

### Code-Review Remediation — Independently Re-Checked

Every disposition in `238-REVIEW.md:308` was re-verified against source, not accepted on the
record's say-so:

| ID | Claimed | My check |
|---|---|---|
| CR-01 (critical) | Fixed | ✓ Confirmed in source at `:166-167` (`remote_listing_failed`) and `:208` (`remote_listing_empty`), **and reproduced red end-to-end** in a scratch repo. The last commit on `main` (`026dc0b9 fix(238): close the code-review gate — remote pass no longer fails open`) is this fix. |
| WR-01 | Fixed in docs | ✓ `MAINTAINING.md:149` states the script's keep-sets are deliberately narrower than the ruleset permits and names `milestone/` / `proof/`. |
| WR-02 | Deferred + todo | ✓ Todo file exists. |
| IN-01 | Deferred + todo | ✓ Todo file exists. |
| IN-02 | Fixed | ✓ Keep-set suffix class is `([-+][0-9A-Za-z.+-]+)?` — observed in the script's own live output. `v1.2.3-rc.1+build.5` is a keep-set member. |
| IN-03 | Deferred + todo | ✓ Todo file exists. Both defects are fail-closed (false-red / unlabelled-red), never false-green; successful execution is now independently recorded. |
| IN-04 | Fixed | ✓ `</dev/null` present on all three loop-body git commands (`:178`, `:189`, `:223`). |
| IN-05 | Not fixed, by decision | ✓ Reasoning accepted: git refuses such refnames, the `:174` precheck short-circuits first, and `git push --delete` has no clean `--` form — the change would be asymmetric and unprovable. Recorded rather than filed, which is the right call for a verified-unreachable finding. |

---

### Prohibition Audit (must-NOT checks)

All judgment-tier. None violated silently; the one deliberate departure is a dated, multi-artifact supersession.

| Prohibition | Status |
|---|---|
| No `deletion` rule in the ruleset | ✓ Live ruleset carries exactly one rule, type `creation` |
| `bypass_actors` empty, no entry added | ✓ Live `bypass_actors: []`, `current_user_can_bypass: "never"` |
| Guard not in `release_ref_guard`, not in `mix ci`, no `ci.yml` edit | ✓ All three confirmed |
| Guard makes no network call / process spawn | ✓ No `fetch`/`http`/`child_process`/`execSync` |
| Guard does not assert `bypass_actors` | ✓ A dedicated test asserts that altering it still returns `null` |
| No glob at a `git tag -d` / `git push --delete` call site | ✓ One literal name per invocation, read from column 1 |
| No hardcoded keep-set cardinality | ✓ Both sides regex-derived at compare time |
| No `archive/` or three-component row in the allowlist | ✓ Enforced by the script and confirmed by inspection |
| **No `git gc` / `reflog expire` / `prune` anywhere in the phase** | ✓ Absent from the script; all 39 `pre_delete_sha` objects still reachable — the operative proof. I ran none during verification. |
| No quiet re-scope of REL-01; `creation` rule obliges a dated supersession naming D-04 and ROADMAP SC-1 | ✓ Recorded in **both** `.planning/REQUIREMENTS.md:28-48` and ADR 003, each naming D-04 and SC-1, each dated 2026-09-17 |
| Must not claim the observer-lane drift read is proven in-phase | ✓ Honored — ADR, summaries and ledger all decline to claim it; this report classifies it as behavior-unverified rather than passing it |
| CONTEXT **D-04** ("no `creation` rule, ever") | ⚠️ **Departed from, deliberately and loudly.** First clause superseded with a date, in two artifacts, with the 422 evidence and the reason D-04's objection dissolves. Second clause (no `deletion` rule) untouched. This is the CONTEXT D-02 replanning path being followed, not an uncovered gap. |

---

### Evidence-Ledger Integrity

The ledger is unusually honest and I found nothing in it that the live repository contradicts.
Three things I specifically checked *because* they are where a ledger would cheat:

- It self-flags that the Tier-1 probe's **request body is reconstructed** while the response is
  captured — an admission nobody would have caught.
- It records the still-live `1.20.0` HexDocs **404** rather than omitting it, and disproves
  ownership with a positive control (`git ls-remote 'refs/tags/v1.20*'` empty;
  `grep -c '^v1\.20' allowlist` → `0`). I confirmed no `v1.20` appears in the 52-tag pre-deletion
  inventory either. The 404 is REL-04 / Phase 242's, not this phase's.
- It states reversibility **honestly**: the refs are gone from both sides and the objects survive
  by SHA only until Phase 245. I verified that claim holds right now (39/39 reachable).

Every slot's heading matches the `BEFORE-`/`AFTER-` uppercase grammar and opens with a `Status`
line — enforced mechanically by p19's ledger-grammar checker, which I ran and which is itself
negative-controlled by an inline malformed ledger.

---

### Deferred Items

None. No Success Criterion of this phase is addressed by a later phase. Two adjacent concerns are
correctly scoped **out**:

| Concern | Owner | Why not a Phase 238 gap |
|---|---|---|
| Whether the ruleset blocks release-please's `v1.5.1` push via the **Releases API** route | Phase 242 | Structurally moot under Tier 2 — `v1.5.1` is excluded from the ruleset's scope by ref name, so no rule evaluates it on any route. The ledger calls this "indicative, not proven" and defers the true observation. I agree with both halves of that sentence. |
| The stray `1.20.0` on Hex and its 404 "View source" | REL-04 / Phase 242 | Pre-existed this phase; `v1.20` never existed as a ref on this repository. Disproved above with a positive control. |

---

### Advisory

| # | Finding | Category | Note |
|---|---|---|---|
| 1 | The `v*` namespace is protected against the *recurrence class* (bare `vX.Y`), not against every malformed name. `v1.2.3.4`, `v1.a.b`, `v1..`, `v...` and `v1.4/notes` are all admitted. | architectural | Not a gap — the limit is disclosed in ADR 003, REQUIREMENTS and `MAINTAINING.md`, and closing it would require a `~ALL` condition that pulls release automation into scope (considered and rejected). Recorded so a future reader does not over-read the guard's reach. |
| 2 | The ruleset does not cover `phase-NNN-*`, `milestone/` or `proof/` tags at all (fnmatch `*` does not cross `/`, and non-`v` names are out of `include`). A future junk `phase-NNN-*` tag is still possible. | architectural | Explicitly stated in ADR 003's "what it does not cover" section. The `proof/` namespace prescription is the mitigation, and it is convention, not enforcement. |
| 3 | Three review findings deferred to `.planning/todos/pending/` (WR-02, IN-01, IN-03). | other | All three filed; IN-03 remains a fail-closed trust/noise improvement, not an unverified phase behavior. |

---

### Human Verification Required

None. D5 was resolved from the recorded successful observer-job run, and D6 was resolved by deterministic Git-history and clean-checkout evidence.

### Gaps Summary

**No gaps.** Every must-have is VERIFIED. SC-2's formerly deferred live-drift clause closed after
merge: observer run `35249205910` executed the job successfully, and a fresh live API comparison
on 2026-09-19 remained byte-equivalent over the committed contract fields.

The phase goal — *the `v*` tag namespace means exactly one thing and cannot be re-polluted by the
next close flow* — is achieved for the class of pollution that actually occurred. Thirty-nine
polluting tags are gone from both sides with every object still recoverable by SHA for Phase 245;
the twelve release tags and the one `archive/` ref are untouched; twelve releases and zero drafts
stand; and a server-side rule with no bypass now rejects the exact shape the GSD close flow used
to mint, proven live and still citable by rule-suite id.

---

_Verified: 2026-09-19T15:05:00Z_
_Verifier: Codex (automation-first refresh)_
