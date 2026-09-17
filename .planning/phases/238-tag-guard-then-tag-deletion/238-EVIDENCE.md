# Phase 238 Evidence Ledger

Observed at commit: (this file's own commit is the first commit of this ledger; every
observation below was captured live before this file was written, on a clean tree apart from
this phase's own in-progress artifacts)

A note on machine-enforcement, stated honestly per RESEARCH Pitfall 4: no committed guard reads
this ledger at HEAD today — every evidence-reading guard in `scripts/ci/prohibitions/*.test.mjs`
pins Phase 230's ledger (`.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`)
by literal path, not this one. The `## BEFORE-*` / `## AFTER-*` slot grammar below is repo
**convention**, not yet a machine-enforced contract for this specific file. Plan 238-03 makes
the claim true by having the `p19` guard assert this ledger's slot grammar as a secondary
artifact (per RESEARCH's "Recommended" resolution to Pitfall 4), which is when this note should
be revisited and, if the guard lands, corrected.

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-RULESET-STATE](#before-ruleset-state) | The live ruleset list before any write in this phase | `gh api repos/szTheory/sigra/rulesets` | captured |
| [BEFORE-TAG-INVENTORY](#before-tag-inventory) | Local and remote tag partition, four classes, zero unclassified | `git tag`, `git ls-remote --tags origin`, per-class regex counts | captured |
| [BEFORE-RULESET-FEASIBILITY-PROBE](#before-ruleset-feasibility-probe) | Tier-1 and Tier-2 probe request/response pairs, the selected tier | `gh api -X POST` / `-X DELETE` against `repos/szTheory/sigra/rulesets`, disabled enforcement, deleted same task | captured |
| [AFTER-RULESET-ACTIVE](#after-ruleset-active) | The live `tag-namespace` ruleset, active, matching the selected tier's shape | `gh api repos/szTheory/sigra/rulesets/{id}` | captured |
| [AFTER-SC1-REJECT-ACCEPT](#after-sc1-reject-accept) | Reject/accept proof against the active guard | live tag push probes | captured |
| [AFTER-DELETE-PROBE](#after-delete-probe) | Whether deleting an in-scope tag is blocked by the active guard | live delete of the accepted scratch tag | captured |
| [AFTER-P19-RED](#after-p19-red) | The `p19` offline contract guard demonstrated RED against a known-bad fixture | `node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` | pending (238-03) |
| [AFTER-LOCAL-DELETE](#after-local-delete) | Local tag deletion set-equality against the keep-set | `git tag` + regex keep-set, post-delete | pending (238-04) |
| [AFTER-REMOTE-DELETE](#after-remote-delete) | Remote tag deletion set-equality against the keep-set | `git ls-remote --tags origin` + regex keep-set, post-delete | pending (238-05) |
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

Status: pending (238-03)

## AFTER-LOCAL-DELETE

Status: pending (238-04)

## AFTER-REMOTE-DELETE

Status: pending (238-05)

## AFTER-RELEASE-SURFACE

Status: pending (238-06)
