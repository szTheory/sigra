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
| [AFTER-RULESET-ACTIVE](#after-ruleset-active) | The live `tag-namespace` ruleset, active, matching the selected tier's shape | `gh api repos/szTheory/sigra/rulesets/{id}` | pending (238-02) |
| [AFTER-SC1-REJECT-ACCEPT](#after-sc1-reject-accept) | Reject/accept proof against the active guard | live tag push probes | pending (238-02) |
| [AFTER-DELETE-PROBE](#after-delete-probe) | Whether deleting an in-scope tag is blocked by the active guard | live delete of the accepted scratch tag | pending (238-02) |
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

Status: pending (238-02)

## AFTER-SC1-REJECT-ACCEPT

Status: pending (238-02)

## AFTER-DELETE-PROBE

Status: pending (238-02)

## AFTER-P19-RED

Status: pending (238-03)

## AFTER-LOCAL-DELETE

Status: pending (238-04)

## AFTER-REMOTE-DELETE

Status: pending (238-05)

## AFTER-RELEASE-SURFACE

Status: pending (238-06)
