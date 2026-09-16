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
| [BEFORE-RULESET-FEASIBILITY-PROBE](#before-ruleset-feasibility-probe) | Tier-1 and Tier-2 probe request/response pairs, the selected tier | `gh api -X POST` / `-X DELETE` against `repos/szTheory/sigra/rulesets`, disabled enforcement, deleted same task | pending |
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

Status: pending (captured by task 3, not yet run)

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
