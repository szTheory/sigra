# Phase 238 Evidence Ledger

Observed at commit: (this file's own commit is the first commit of this ledger; every
observation below was captured live before this file was written, on a clean tree apart from
this phase's own in-progress artifacts)

A note on machine-enforcement, corrected per RESEARCH Pitfall 4's own resolution: this note
previously stated that no committed guard reads this ledger. That is now FALSE, and this is the
correction. `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (238-03 task 1/2) reads
this file — via `readRepoFile(archiveAwareRelPath(...))`, as a SECONDARY artifact, never the
substitutable subject — and asserts: the parse finds at least the 10 slots the table below
declares; every slot heading matches the recognised uppercase `BEFORE-*`/`AFTER-*` grammar; every
slot body opens with a `Status:` line at column one whose value begins with `captured` or
`pending`; and every `captured` slot carries a fenced producing command. A malformed
`238-EVIDENCE.md` now reddens `fast_checks` for the whole repo, exactly as `p12` does for
`230-EVIDENCE.md`. The `## BEFORE-*` / `## AFTER-*` slot grammar below is machine-enforced for
this file, not merely repo convention.

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-RULESET-STATE](#before-ruleset-state) | The live ruleset list before any write in this phase | `gh api repos/szTheory/sigra/rulesets` | captured |
| [BEFORE-TAG-INVENTORY](#before-tag-inventory) | Local and remote tag partition, four classes, zero unclassified | `git tag`, `git ls-remote --tags origin`, per-class regex counts | captured |
| [BEFORE-RULESET-FEASIBILITY-PROBE](#before-ruleset-feasibility-probe) | Tier-1 and Tier-2 probe request/response pairs, the selected tier | `gh api -X POST` / `-X DELETE` against `repos/szTheory/sigra/rulesets`, disabled enforcement, deleted same task | captured |
| [AFTER-RULESET-ACTIVE](#after-ruleset-active) | The live `tag-namespace` ruleset, active, matching the selected tier's shape | `gh api repos/szTheory/sigra/rulesets/{id}` | captured |
| [AFTER-SC1-REJECT-ACCEPT](#after-sc1-reject-accept) | Reject/accept proof against the active guard | live tag push probes | captured |
| [AFTER-DELETE-PROBE](#after-delete-probe) | Whether deleting an in-scope tag is blocked by the active guard | live delete of the accepted scratch tag | captured |
| [AFTER-P19-RED](#after-p19-red) | The `p19` offline contract guard demonstrated RED against a known-bad fixture | `node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` | pending (238-03) |
| [AFTER-LOCAL-DELETE](#after-local-delete) | Local tag deletion set-equality against the keep-set | `git tag` + regex keep-set, post-delete | captured (238-05) |
| [AFTER-REMOTE-DELETE](#after-remote-delete) | Remote tag deletion set-equality against the keep-set | `git ls-remote --tags origin` + regex keep-set, post-delete | captured (238-05) |
| [AFTER-RELEASE-SURFACE](#after-release-surface) | `gh release list` count unchanged, zero drafts, HexDocs source_ref still resolves | `gh api .../releases`, `curl` HexDocs | pending (238-06) |

---

## BEFORE-RULESET-STATE

Status: captured

```bash
$ gh api repos/szTheory/sigra/rulesets
[{"id":14941512,"name":"main","target":"branch","source_type":"Repository","source":"szTheory/sigra","enforcement":"active","node_id":"RRS_lACqUmVwb3NpdG9yec5H-MzEzgDj_Ug","_links":{"self":{"href":"https://api.github.com/repos/szTheory/sigra/rulesets/14941512"},"html":{"href":"https://github.com/szTheory/sigra/rules/14941512"}},"created_at":"2026-04-10T22:16:26.406-04:00","updated_at":"2026-04-10T22:18:58.086-04:00"}]
```

Exactly one ruleset, id `14941512`, `target: "branch"`. This is the pre-change value recorded
verbatim (with the by-id payload) in `238-TAG-RULESET-RECORD.md`.

## BEFORE-TAG-INVENTORY

Status: captured

```bash
$ git tag | sort > /tmp/local-tags.txt
$ git ls-remote --tags origin | sed 's#.*refs/tags/##' | grep -v '\^{}' | sort > /tmp/remote-tags.txt
$ wc -l < /tmp/local-tags.txt
52
$ wc -l < /tmp/remote-tags.txt
33
```

Per-class partition, both sides, using the four class regexes named in this plan (the release
expression carries an optional prerelease/build suffix per D-05's note that release automation
may mint a release-candidate tag — this is the same keep expression 238-04 and 238-05 must use):

```bash
$ grep -cE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$' /tmp/local-tags.txt   # three-component SemVer (keep)
12
$ grep -cE '^archive/' /tmp/local-tags.txt                                        # archive (keep, local-only)
1
$ grep -cE '^v[0-9]+\.[0-9]+$' /tmp/local-tags.txt                                # two-component vX.Y planning (delete)
28
$ grep -cE '^phase-238-' /tmp/local-tags.txt                                      # phase-238-* proof tags (delete)
11
```

```bash
$ grep -cE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$' /tmp/remote-tags.txt
12
$ grep -cE '^archive/' /tmp/remote-tags.txt
0
$ grep -cE '^v[0-9]+\.[0-9]+$' /tmp/remote-tags.txt
10
$ grep -cE '^phase-238-' /tmp/remote-tags.txt
11
```

Every tag on both sides is accounted for — nothing unclassified:

```bash
$ grep -vE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$|^archive/|^v[0-9]+\.[0-9]+$|^phase-238-' /tmp/local-tags.txt
# (no output)
$ grep -vE '^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$|^archive/|^v[0-9]+\.[0-9]+$|^phase-238-' /tmp/remote-tags.txt
# (no output)
```

Local: 12 + 1 + 28 + 11 = 52, matches `wc -l`. Remote: 12 + 0 + 10 + 11 = 33, matches `wc -l`.
Both totals reproduce `238-RESEARCH.md`'s Measured Starting State exactly.

## BEFORE-RULESET-FEASIBILITY-PROBE

Status: captured

Both probes were issued against `POST /repos/szTheory/sigra/rulesets` with `enforcement: "disabled"`
(a disabled ruleset enforces nothing), and each created ruleset was deleted in the same cycle.
Neither probe body carries a `deletion` rule. Both carry an empty `bypass_actors` list.

### Probe A — Tier 1 (`tag_name_pattern`)

Request body — **reconstructed, not captured.** The probe was issued in an earlier execution
session whose scratch body file was not durable, so the JSON below is the Pattern 1 shape from
`238-RESEARCH.md` as the probe was specified, not a byte-capture of what was sent. The *response*
below IS the observed response. Flagged explicitly because this ledger's credibility rests on the
distinction.

Shape (Pattern 1 from `238-RESEARCH.md`, `target: "tag"`, one `tag_name_pattern` rule,
`operator: "regex"`, `negate: false`, GitHub's own published SemVer regex prefixed with `^v` and
terminated with an optional-newline end anchor per RESEARCH Pitfall 2):

```json
{
  "name": "tag-namespace-probe-tier1",
  "target": "tag",
  "enforcement": "disabled",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "tag_name_pattern",
      "parameters": {
        "operator": "regex",
        "pattern": "^v(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?(?:\\n)?$",
        "negate": false,
        "name": "semver-v-prefixed"
      }
    }
  ]
}
```

Response (verbatim):

```
HTTP 422 Validation Failed
```
```json
{"message":"Validation Failed","errors":["Invalid rule 'tag_name_pattern': "]}
```

**Outcome: REJECTED.** No ruleset was created. Nothing to delete. This confirms the Plan-Gating
Verdict's near-certain NO: `tag_name_pattern` is enterprise-gated on this Free-tier repo, and the
API enforces the same gate the docs describe (RESEARCH's "What this does and does not prove"
caveat — docs gating and API enforcement, previously unconfirmed to align, are now observed to
align).

### Probe B — Tier 2 (`creation` rule + `ref_name.exclude`)

Request body (Pattern 2 shape from `238-RESEARCH.md` — a shape CONTEXT did not consider):

```json
{
  "name": "tag-namespace-probe",
  "target": "tag",
  "enforcement": "disabled",
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

Round-tripped response (verbatim, by-id payload after acceptance):

```json
{"id":23564973,"name":"tag-namespace-probe","target":"tag","source_type":"Repository","source":"szTheory/sigra","enforcement":"disabled","conditions":{"ref_name":{"exclude":["refs/tags/v*.*.*"],"include":["refs/tags/v*"]}},"rules":[{"type":"creation"}],"node_id":"RRS_lACqUmVwb3NpdG9yec5H-MzEzgFnkq0","created_at":"2026-09-16T16:49:28.627-04:00","updated_at":"2026-09-16T16:49:28.644-04:00","bypass_actors":[],"current_user_can_bypass":"never","_links":{"self":{"href":"https://api.github.com/repos/szTheory/sigra/rulesets/23564973"},"html":{"href":"https://github.com/szTheory/sigra/rules/23564973"}}}
```

**Outcome: ACCEPTED.** The round-trip preserved `bypass_actors: []` and reports
`"current_user_can_bypass": "never"` — direct evidence for the Pattern 2 claim that with an empty
bypass list the creation restriction binds every actor including the repo owner (D-05's point).

Delete confirmation:

```
$ gh api -X DELETE repos/szTheory/sigra/rulesets/23564973
(204, no body)
```

### Post-probe live state, verified

```
$ gh api repos/szTheory/sigra/rulesets --jq '.[] | "\(.id) \(.name) \(.target) \(.enforcement)"'
14941512 main branch active
$ gh api repos/szTheory/sigra/rulesets --jq 'length'
1
```

Exactly one ruleset remains — `14941512`, untouched. No probe ruleset survives.

### Tier selection

Tier selected: Tier 2 — Probe A rejected (HTTP 422, `Invalid rule 'tag_name_pattern'`), Probe B
accepted (round-tripped by-id payload above, `id: 23564973`, since deleted). REL-01's
"server-side" wording survives; the supersession 238-06 records narrows from "detection only, not
server-side prevention" to "server-side prevention at coarser granularity than a SemVer regex".
The weakness, stated honestly per RESEARCH's "three further consequences" (consequence 3): `v*.*.*`
admits `v1.2.3.4`, `v1.a.b`, `v1..`, `v...` — it is a *shape* guard, not a SemVer validator. It
blocks the recurrence class (two-component `vX.Y`, the pattern behind 28 of the 39 tags being
deleted and both post-ADR-003 regressions) and nothing more.

Departs from: (1) CONTEXT D-04's absolute "no `creation` rule, ever" clause — the landed ruleset
contains exactly one `creation` rule. This is safe because D-04's stated objection was that a
`creation` rule would block release-please's own tag creation (e.g. `v1.5.1`); the `ref_name.exclude`
list of `refs/tags/v*.*.*` takes a three-component release tag out of the ruleset's scope entirely,
so the objection the clause existed to prevent does not apply to this shape. See 238-06 task 3 for
the dated supersession record. (2) ROADMAP SC-1's named mechanism, which specifies a name-pattern
rule (i.e. Tier 1's `tag_name_pattern`) rather than a `creation`+`exclude` shape — this is safe
because SC-1's observable outcome (a two-component scratch tag name is rejected, a three-component
release tag is accepted) still holds under Tier 2: a two-component name carries exactly one dot and
is therefore not excluded by `v*.*.*`, so it remains in scope and is rejected by the `creation`
rule; a three-component release tag carries two dots and is excluded, so it is accepted. See 238-06
task 3 for the dated supersession record.

Tier-3 disposition: not applicable — Tier 2 was accepted. Tier 3 (D-02's pre-push hook and tag-push
detection workflow) remains a named, accepted replanning trigger of this plan set that did not
fire; no Tier-3 infrastructure was built or is needed.

## AFTER-RULESET-ACTIVE

Status: captured

The live `tag-namespace` ruleset was created by the operator via `POST /repos/szTheory/sigra/rulesets`
(the harness permission classifier blocks a `gh api -X POST` against rulesets for this executor;
see 238-02-PLAN.md's `<already_done_by_operator>` note). This executor's task 1 step 1 is therefore
a read-back and validation of the live object, not a creation.

```bash
$ gh api repos/szTheory/sigra/rulesets/23574716
{"id":23574716,"name":"tag-namespace","target":"tag","source_type":"Repository","source":"szTheory/sigra","enforcement":"active","conditions":{"ref_name":{"exclude":["refs/tags/v*.*.*"],"include":["refs/tags/v*"]}},"rules":[{"type":"creation"}],"node_id":"RRS_lACqUmVwb3NpdG9yec5H-MzEzgFnuLw","created_at":"2026-09-16T21:56:28.810-04:00","updated_at":"2026-09-16T21:56:28.834-04:00","bypass_actors":[],"current_user_can_bypass":"never","_links":{"self":{"href":"https://api.github.com/repos/szTheory/sigra/rulesets/23574716"},"html":{"href":"https://github.com/szTheory/sigra/rules/23574716"}}}
```

Validated: `target: "tag"` (yes), `enforcement: "active"` (yes), `bypass_actors: []` (yes, empty),
`rules: [{"type":"creation"}]` — exactly one rule, no rule of type `deletion` present. This is the
Tier-2 shape selected in 238-01: `conditions.ref_name.include: ["refs/tags/v*"]`,
`conditions.ref_name.exclude: ["refs/tags/v*.*.*"]`, one `creation` rule.

Departs from: the landed ruleset carries exactly one `creation` rule. This departs from two locked
source artifacts, both recorded here because this is the plan where the rule actually lands (task 1
restates 238-01's tier record per this plan's own obligation):

1. **CONTEXT D-04** — D-04 states absolutely that the ruleset contains no `creation` rule and no
   `deletion` rule, ever. This IS a `creation` rule, which D-04 forbade. Reason this is safe: D-04's
   stated objection was that a `creation` rule would block release-please's own tag creation (e.g.
   `v1.5.1`); the `ref_name.exclude` list of `refs/tags/v*.*.*` takes any three-component release
   tag out of the ruleset's scope entirely, so the objection D-04 existed to prevent does not apply
   to this shape. See 238-06 task 3 for the dated supersession record.
2. **ROADMAP SC-1's named mechanism** — SC-1 names a name-pattern rule (Tier 1's
   `tag_name_pattern`) as the mechanism, not a `creation`+`exclude` shape. This departs from the
   named mechanism. Reason this is safe: SC-1's observable outcome still holds under Tier 2 — a
   two-component scratch tag name (`vX.Y`) carries exactly one dot and is therefore not excluded by
   `v*.*.*`, so it remains in the ruleset's scope and is rejected by the `creation` rule; a
   three-component release tag carries two dots and is excluded, so it is accepted. See 238-06 task
   3 for the dated supersession record.

## AFTER-SC1-REJECT-ACCEPT

Status: captured

**A3 (238-RESEARCH Assumptions Log) is now PROVEN, not assumed: `conditions.ref_name.exclude`
does take precedence over `include` on this live ruleset.** The accept probe below was NOT
rejected — `v9.9.9-rulesettest` is in `include` (`refs/tags/v*`) but also in `exclude`
(`refs/tags/v*.*.*`), and it was accepted. Had exclude lost to include, this push would have been
rejected too, which would have been phase-stopping (it would mean release-please's `v1.5.1` push
is also blocked under Tier 2). It was not — exclude wins.

### Reject probe: `v9.9` (in `include`, NOT in `exclude` — one dot, in scope)

```bash
$ git tag v9.9 HEAD && git push origin v9.9
remote: error: GH013: Repository rule violations found for refs/tags/v9.9.
remote: Review all repository rules at https://github.com/szTheory/sigra/rules?ref=refs%2Ftags%2Fv9.9
remote:
remote: - Cannot create ref due to creations being restricted.
remote:
To https://github.com/szTheory/sigra.git
 ! [remote rejected]   v9.9 -> v9.9 (push declined due to repository rule violations)
error: failed to push some refs to 'https://github.com/szTheory/sigra.git'
```

Outcome: **REJECTED**, as expected.

### Accept probe: `v9.9.9-rulesettest` (in `include` AND in `exclude` — two dots, out of scope)

```bash
$ git tag v9.9.9-rulesettest HEAD && git push origin v9.9.9-rulesettest
To https://github.com/szTheory/sigra.git
 * [new tag]           v9.9.9-rulesettest -> v9.9.9-rulesettest
```

Outcome: **ACCEPTED**, as expected. A3 verdict: **exclude wins over include** — confirmed live.

Route caveat (RESEARCH Pitfall 3): this probe exercises the `git push` route only. release-please
creates its release tag via the Releases API, a different route. Under Tier 2 this route
distinction is moot for the exclusion question — `v1.5.1` (two dots) is excluded from the
ruleset's scope entirely regardless of which route creates it, so no rule evaluates it either way.
This observation is **indicative**, not proof, that the Releases-API route behaves identically;
Phase 242 is the true observation for that route. The word used here is indicative, not proven.

### Rule-suite citation (D-18) — embedded JSON, not just an id

Fetched inside the `rule-suites` query window (`time_period=day`), locally as the owner
(rule-suites requires Administration: read, which an Actions `GITHUB_TOKEN` cannot be granted):

```bash
$ SUITE=$(gh api 'repos/szTheory/sigra/rulesets/rule-suites?time_period=day&ref=refs/tags/v9.9' \
    --jq '[.[]|select(.result=="fail")][0].id')
$ echo "$SUITE"
4106927843
$ gh api "repos/szTheory/sigra/rulesets/rule-suites/$SUITE"
{"id":4106927843,"actor_id":28652,"actor_name":"szTheory","before_sha":"0000000000000000000000000000000000000000","after_sha":"ba8a7b61b9b8d799c207575573cfdd5309cb4ce1","ref":"refs/tags/v9.9","repository_id":1207487684,"repository_name":"sigra","pushed_at":"2026-09-16T22:00:44-04:00","result":"fail","rule_evaluations":[{"rule_source":{"type":"secret_scanning"},"enforcement":"active","result":"pass","rule_type":"secret_scanning"},{"rule_source":{"type":"ruleset","id":23574716,"name":"tag-namespace"},"enforcement":"active","result":"fail","rule_type":"creation","details":"Cannot create ref due to creations being restricted."}]}
```

Citable by `rule_suite_id: 4106927843`, `rule_evaluations[]` entry naming `ruleset id: 23574716`
(`tag-namespace`), `rule_type: "creation"`, `result: "fail"`, `details: "Cannot create ref due to
creations being restricted."` — the JSON above is the record; the id alone is not enough because
the query window (default `day`) expires. `actor_name: "szTheory"` names the public repo owner;
no credential material is present, nothing scrubbed beyond that (none present).

## AFTER-DELETE-PROBE

Status: captured

D-06's delete-deadlock question: does the live `tag-namespace` ruleset govern ref *deletion*, not
just creation? Answered by deleting `v9.9.9-rulesettest` from origin — a tag inside the ruleset's
include scope, so the delete attempt is itself the probe.

```bash
$ git push origin --delete v9.9.9-rulesettest
To https://github.com/szTheory/sigra.git
 - [deleted]           v9.9.9-rulesettest
```

Exit 0, no rejection. **Verdict: deletion is unaffected by this ruleset.** This is an
**observation**, not an inference — the delete was actually attempted and actually succeeded; it
was not assumed from the ruleset's rule types. Under Tier 2 the answer was structurally knowable
in advance (the ruleset contains exactly one rule, of type `creation`; `deletion` is a
[documented separate rule type](https://docs.github.com/en/rest/repos/rules) this ruleset does not
carry), but per the plan's instruction the observation is recorded rather than the inference, and
this line states plainly which one is being recorded: the observation.

No enforcement flip was needed. Live enforcement value confirmed still `active` immediately after
the delete:

```bash
$ gh api repos/szTheory/sigra/rulesets/23574716 --jq '.enforcement'
active
```

**Consequence for 238-05:** 238-05 can run its remote deletion pass with enforcement left
`active` throughout — true guard-first in the literal sense the phase title reads. No flip window
is required, so there is no window to open or close.

### Scratch tag cleanup (the only two refs this plan removes)

```bash
$ git tag -d v9.9.9-rulesettest
Deleted tag 'v9.9.9-rulesettest' (was ba8a7b61)
$ git tag -d v9.9
Deleted tag 'v9.9' (was ba8a7b61)
```

Post-cleanup counts, read directly from the remote (never reconciled from local refs):

```bash
$ git tag | wc -l
52
$ git ls-remote --tags origin | sed 's#.*refs/tags/##' | grep -cv '\^{}'
33
```

Both counts match `BEFORE-TAG-INVENTORY` exactly (52 local, 33 remote). Neither `v9.9` nor
`v9.9.9-rulesettest` appears in `git tag` or `git ls-remote --tags origin`. No other ref was
touched — the 18 local-only `v1.NN` tags, `archive/local-main-pre-235-recovery`, and all
`phase-238-*` tags are untouched, left for 238-04/238-05's allowlist-driven deletion.

## AFTER-P19-RED

Status: captured

The `p19` offline contract guard (`scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`),
proven RED via the fail-first protocol: its single substitutable subject
(`GSD_PROHIB_SUBJECT`) pointed at the committed known-bad fixture
`test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json`.

### Substituted-subject run (RED)

```bash
$ GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json \
    node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
TAP version 13
# Subtest: floor: a non-object value produces a named message, not a silent pass
ok 1 - floor: a non-object value produces a named message, not a silent pass
# Subtest: floor: an object with no `target` field produces a named message
ok 2 - floor: an object with no `target` field produces a named message
# Subtest: floor: an object with an empty or missing `rules` array produces a named message
ok 3 - floor: an object with an empty or missing `rules` array produces a named message
# Subtest: the snapshot parse produced an object with a target field at all (non-vacuity floor)
ok 4 - the snapshot parse produced an object with a target field at all (non-vacuity floor)
# Subtest: the committed snapshot produces null (every asserted field matches the landed Tier-2 shape)
not ok 5 - the committed snapshot produces null (every asserted field matches the landed Tier-2 shape)
  ---
  duration_ms: 0.347458
  type: 'test'
  location: 'scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs:231:1'
  failureType: 'testCodeFailure'
  error: |-
    the ruleset's `enforcement` is `disabled`, not `active` — the ruleset is present but disabled, which enforces nothing
    + actual - expected

    + "the ruleset's `enforcement` is `disabled`, not `active` — the ruleset is present but disabled, which enforces nothing"
    - null

  code: 'ERR_ASSERTION'
  name: 'AssertionError'
  expected: ~
  actual: "the ruleset's `enforcement` is `disabled`, not `active` — the ruleset is present but disabled, which enforces nothing"
  operator: 'strictEqual'
  ...
# (tests 6-19 continue, all `ok` — this is the one test that substitutes the fixture)
1..19
# tests 19
# pass 18
# fail 1
```

Exit code: 1. `grep -c "not ok"` = 1 — exactly the substituted test failed, and its `error` names a
drifted FIELD (`enforcement`, `disabled` vs `active`) — the shape checker, not a broken-parse
floor. (The fixture also carries a second violation, `conditions.ref_name.exclude:
["refs/tags/v*"]` no longer constraining the namespace; the pure checker returns on the first
issue found, so this run surfaces `enforcement` first — both violations are independently
reachable by mutating either field alone in the guard's own behavior tests, see task 1's `test(238-03)` commit.)

### Unsubstituted run (GREEN — the committed snapshot, both directions recorded)

```bash
$ node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
TAP version 13
# ... (19 subtests, all ok)
1..19
# tests 19
# suites 0
# pass 19
# fail 0
# cancelled 0
# skipped 0
# todo 0
```

Exit code: 0, 19/19 pass. Both directions confirm the same claim from opposite sides: the guard
is falsifiable (RED against the known-bad fixture) and correct against the real, committed
snapshot (GREEN unsubstituted).

## AFTER-LOCAL-DELETE

Status: captured

The local deletion pass and its separate verification. Two invocations, never chained. Run by the
operator on a clean tree at committed head `32a09c75`, with the Tier-2 ruleset already live and
`p19` green — the guard landed before the first delete, as SC-2 requires.

Absolute paths in the captured output below are rewritten to repository-relative form
(`.planning/decisions/003-tag-delete-list.tsv`); this repository is public and home-directory
prefixes are not committed. Nothing else is altered.

### Pass 1 — local apply

```bash
$ bash scripts/maintainers/delete-planning-tags.sh local --apply
delete-planning-tags: pass=local apply=1 allowlist=.planning/decisions/003-tag-delete-list.tsv rows=39
  deleted phase-238-generated-auth-proof-68c9d632
  deleted phase-238-generated-auth-proof-85cc3086
  deleted phase-238-generated-auth-proof-325b3cfa
  deleted phase-238-generated-auth-proof-526a1184
  deleted phase-238-generated-auth-proof-655e402d
  deleted phase-238-generated-auth-proof-ad1611d2
  deleted phase-238-generated-auth-proof-c7e1171d
  deleted phase-238-generated-auth-proof-c94add15
  deleted phase-238-generated-auth-proof-d96e35ba
  deleted phase-238-generated-auth-proof-e28499f8
  deleted phase-238-generated-auth-proof-f824423f
  deleted v1.0
  deleted v1.1
  deleted v1.3
  deleted v1.4
  deleted v1.5
  deleted v1.6
  deleted v1.7
  deleted v1.8
  deleted v1.9
  deleted v1.10
  deleted v1.12
  deleted v1.14
  deleted v1.15
  deleted v1.16
  deleted v1.17
  deleted v1.21
  deleted v1.25
  deleted v1.26
  deleted v1.27
  deleted v1.28
  deleted v1.29
  deleted v1.30
  deleted v1.31
  deleted v1.33
  deleted v1.34
  deleted v1.35
  deleted v1.47
  deleted v1.48
delete-planning-tags: local pass done — deleted=39 absent=0 would_delete=0
```

`deleted=39 absent=0` — every allowlist row was present and removed; no row was silently a no-op,
and no ref outside the allowlist was passed to a delete invocation.

### Pass 2 — local verification (separate invocation)

```bash
$ bash scripts/maintainers/delete-planning-tags.sh verify-local
delete-planning-tags: pass=verify-local apply=0 allowlist=.planning/decisions/003-tag-delete-list.tsv rows=39
delete-planning-tags: REPORTING ONLY — no ref will be touched (pass --apply to mutate)
delete-planning-tags: local listing=13 keep-set=13 (keep expression: ^(v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?|archive/.*)$)
delete-planning-tags: local set-equal to its regex-derived keep-set
```

Both operands derive from that one expression at compare time; no cardinality is written into the
assertion. The `([-+][0-9A-Za-z.-]+)?` group is load-bearing — it admits the prerelease shape D-05
contemplates, so a release candidate minted by the release automation mid-window is a keep-set
member rather than a drift failure.

### Independently observed surviving local set

```bash
$ git tag
archive/local-main-pre-235-recovery
v0.2.1
v0.2.2
v0.2.3
v0.2.4
v0.2.5
v0.3.0
v1.0.0
v1.1.0
v1.2.0
v1.3.0
v1.4.0
v1.5.0
```

52 → 13. **`v1.0` is deleted and `v1.0.0` is intact**, as are `v1.1`/`v1.1.0`, `v1.3`/`v1.3.0`,
`v1.4`/`v1.4.0`, `v1.5`/`v1.5.0`. This is the prefix-collision hazard REL-02 exists to prevent,
observed on the real repository rather than only in the 238-04 scratch clone. It holds because
every delete invocation took one literal name from an allowlist row; no glob was ever expanded.

## AFTER-REMOTE-DELETE

Status: captured

The remote deletion pass and its separate verification — the one-way act of this phase. Two further
invocations, run after AFTER-LOCAL-DELETE completed, never chained with it or with each other.

Paths in the captured output are rewritten to repository-relative form, as above.

### Pass 3 — remote apply

```bash
$ bash scripts/maintainers/delete-planning-tags.sh remote --apply
  ... (21 rows, tail shown)
  deleted v1.21 (origin)
  deleted v1.26 (origin)
  deleted v1.28 (origin)
  deleted v1.33 (origin)
  deleted v1.48 (origin)
delete-planning-tags: remote pass done — deleted=21 absent=0 would_delete=0
```

`deleted=21` matches exactly the rows flagged `remote=yes` in the allowlist — the 11 `phase-proof`
tags plus `v1.1 v1.3 v1.4 v1.5 v1.14 v1.21 v1.26 v1.28 v1.33 v1.48`. The 18 local-only rows were
never passed to a remote delete invocation, which matters because `git push origin --delete` on a
local-only tag errors and would have aborted the pass.

### Pass 4 — remote verification (separate invocation)

```bash
$ bash scripts/maintainers/delete-planning-tags.sh verify-remote
delete-planning-tags: pass=verify-remote apply=0 allowlist=.planning/decisions/003-tag-delete-list.tsv rows=39
delete-planning-tags: REPORTING ONLY — no ref will be touched (pass --apply to mutate)
delete-planning-tags: remote listing=12 keep-set=12 (keep expression: ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$)
delete-planning-tags: remote set-equal to its regex-derived keep-set
```

33 → 12. The remote expression deliberately differs from the local one: it omits the `archive/`
alternative, because that namespace is local-only. Asserting the local expression against the
remote would have been vacuously satisfiable in the wrong direction.

### Release surface, read before and after from the REST releases route

The count comes from `GET /repos/:owner/:repo/releases`, not from `gh release list` — the list
command has no draft field to read, and inventing one would have produced a confident false zero.

```bash
$ gh api repos/szTheory/sigra/releases --paginate --jq '.[] | "\(.tag_name)\t\(.draft)"'
```

| | Before deletion | After deletion |
|---|---|---|
| Published releases | 12 | 12 |
| Drafts | 0 | 0 |
| Tag list | `v1.5.0 v1.4.0 v1.3.0 v1.2.0 v1.1.0 v1.0.0 v0.3.0 v0.2.5 v0.2.4 v0.2.3 v0.2.2 v0.2.1` | identical |

A line-by-line `diff` of the two captures is empty. **Not one of the 39 allowlist rows backed a
release** — every published release is a three-component tag, and no three-component tag is an
allowlist row. That was asserted against the live route before the first delete, not inferred from
the allowlist's own description of itself.

### Published source link still resolves

```bash
$ git ls-remote --tags origin 'refs/tags/v1.4.0'
cfc5e6b88e1e95403c488fc518fd6f5469a9b015	refs/tags/v1.4.0

$ curl -s -o /dev/null -w "%{http_code}" https://github.com/szTheory/sigra/tree/v1.4.0
200
```

The tag HexDocs' `source_ref` points adopters at still resolves on the remote and still serves a
browsable tree. No tag backing a release or a documentation source reference was touched.

### Reversibility, stated honestly

The 39 deleted refs are gone from both sides. The objects remain reachable **by SHA only**, via the
`pre_delete_sha` column of `.planning/decisions/003-tag-delete-list.tsv`, which is the forward-feed
Phase 245 consumes before it prunes the branch holding the `phase-proof` tags. Until 245 runs, no
garbage collection, reflog expiry or prune may run in this repository — that step, not this one, is
what would make the deletion truly irreversible. No such command was run at any point in this phase.

## AFTER-RELEASE-SURFACE

Status: pending (238-06)
