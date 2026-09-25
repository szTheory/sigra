---
phase: "238"
slug: "tag-guard-then-tag-deletion"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-16"
---

# Phase 238 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `node:test` (Node 22 in CI) for prohibition guards; ExUnit via `mix ci` for the rest of the repo — not exercised by this phase's artifacts |
| **Config file** | none — `node --test` needs no config; discovery is the shell glob at `.github/workflows/ci.yml:392` |
| **Quick run command** | `node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` |
| **Full suite command** | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (mirrors the CI step exactly) |
| **RED proof command** | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (must exit non-zero, non-vacuously) |
| **Estimated runtime** | < 15 seconds for the full prohibition glob |

Live observations (ruleset create, scratch-tag reject/accept, delete probe, tag deletion, release
surface) are **one-shot and not automatable in-repo**; they are captured as evidence slots in
`238-EVIDENCE.md` with their producing commands, per the milestone's live-external-observation
standing constraint.

---

## Sampling Rate

- **After every task commit:** `node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`
- **After every plan wave:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`
- **Before pushing any commit:** `MIX_ENV=test mix ci` (repo standing constraint — never root `mix test`)
- **Before `/gsd-verify-work`:** full prohibition glob green, every evidence slot captured at the final committed head on a clean tree
- **Max feedback latency:** ~15 seconds for the guard lane

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 238-01-01 | 01 | 1 | REL-01 | T-238-01 | Repo-settings writes are operator-authorized before any ruleset call | checkpoint | human-check (decision gate) | n/a | ⬜ pending |
| 238-01-02 | 01 | 1 | REL-01 | T-238-03, T-238-04 | Revert value recorded; payloads redacted on a public repo | structural | `grep` assertions on the record + ledger slot-grammar count | ❌ W0 | ⬜ pending |
| 238-01-03 | 01 | 1 | REL-01 | T-238-01, T-238-02, T-238-05 | Probe rulesets are disabled-only and removed; tier recorded from an observed response | live | `gh api repos/szTheory/sigra/rulesets` length check + slot assertions | ❌ W0 | ⬜ pending |
| 238-02-01 | 02 | 2 | REL-01 | T-238-06..09, T-238-11 | Non-SemVer `v*` rejected server-side; guard offline and falsifiable | live + unit | `node --test … p19-tag-namespace-ruleset.test.mjs` + live/committed field diff | ❌ W0 | ⬜ pending |
| 238-02-02 | 02 | 2 | REL-01 | T-238-10 | Delete-governance answered by observation; no scratch residue | live | tag-absence checks with non-vacuity floors + enforcement re-assert | ❌ W0 | ⬜ pending |
| 238-03-01 | 03 | 3 | REL-01 | T-238-13 | Every asserted ruleset field drifts red; bypass field deliberately unasserted | unit | `node --test … p19-tag-namespace-ruleset.test.mjs` | ❌ W0 | ⬜ pending |
| 238-03-02 | 03 | 3 | REL-01 | T-238-13, T-238-14 | Guard red against the committed known-bad fixture, non-vacuously | unit RED | `GSD_PROHIB_SUBJECT=… node --test …` (must exit non-zero) | ❌ W0 | ⬜ pending |
| 238-03-03 | 03 | 3 | REL-01 | T-238-12, T-238-15..17 | Live drift caught off the gating lane, least-privilege, SHA-pinned | structural | YAML parse + job-shape assertions | ❌ W0 | ⬜ pending |
| 238-04-01 | 04 | 3 | REL-02 | T-238-18..20 | Delete set is committed data; presence flags match reality; SHAs recorded | structural | TSV header/column/class/presence/SHA assertions | ❌ W0 | ⬜ pending |
| 238-04-02 | 04 | 3 | REL-02 | T-238-21..23 | Reporting is the default; failures propagate; comparisons are non-vacuous | behavior | syntax check + no-mutation diff + zero-row abort | ❌ W0 | ⬜ pending |
| 238-04-03 | 04 | 3 | REL-02 | T-238-18, T-238-22, T-238-23 | Boundary, adjacency, idempotency, emptiness, ordering, failure propagation | behavior | scratch-clone apply runs + working-repo/origin no-mutation diff | ❌ W0 | ⬜ pending |
| 238-05-01 | 05 | 4 | REL-02 | T-238-25 | The one-way remote deletion is authorized against the live set | checkpoint | human-check (decision gate) | n/a | ⬜ pending |
| 238-05-02 | 05 | 4 | REL-02 | T-238-18, T-238-26 | Local side set-equal to its keep-set; release tags still resolve | live | sorted-set `diff` with positive control | ❌ W0 | ⬜ pending |
| 238-05-03 | 05 | 4 | REL-02 | T-238-24, T-238-27..29 | Remote side set-equal; release count and drafts unchanged; doc source tag present | live | sorted-set `diff` + REST releases enumeration + ref presence | ❌ W0 | ⬜ pending |
| 238-06-01 | 06 | 5 | REL-01, REL-02 | T-238-33, T-238-34 | Runbook renders the data file; caveats recorded | structural | `grep` assertions on MAINTAINING.md | ❌ W0 | ⬜ pending |
| 238-06-02 | 06 | 5 | REL-01, REL-02 | T-238-31 | ADR corrected, not merely extended; non-coverage stated | structural | amendment heading/content assertions | ❌ W0 | ⬜ pending |
| 238-06-03 | 06 | 5 | REL-01, REL-02 | T-238-30, T-238-32 | No silent re-scope; ledger pinned to the final clean head | structural | tier-conditional supersession check + slot-capture count + head pin | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — REL-01 (created in 238-02, completed in 238-03)
- [ ] `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` — REL-01 RED proof (238-03)
- [ ] `.github/rulesets/tag-namespace.json` — the guard's subject; **cannot exist until the ruleset does**, so it is created in 238-02 after the tier resolves
- [ ] `scripts/maintainers/delete-planning-tags.sh` — REL-02, with its own dry-run and edge-behavior proofs (238-04)
- [ ] `.planning/decisions/003-tag-delete-list.tsv` — REL-02 (238-04)
- [ ] `tag_ruleset_drift` job in `.github/workflows/ci-observe.yml` — REL-01 (238-03); **not provable in-phase**
- [ ] No framework install needed.

**Ordering hazard:** the guard's subject does not exist until the ruleset does, and the subject
reader treats a missing subject as a broken run rather than an absent violation. Committing the
guard first would redden `fast_checks` for every intervening commit. Required sequence:
probe → create ruleset → capture snapshot → write guard + fixture → prove RED.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Repo-settings write authorization | REL-01 | The harness permission classifier blocks repo-settings writes; only the operator can grant it | 238-01 task 1 checkpoint: present the scope and blast radius, record authorize or decline |
| Remote tag deletion authorization | REL-02 | One-way door; remote refs do not come back on their own | 238-05 task 1 checkpoint: present the live allowlist contents, the keep-set method and the Phase 245 coupling, record authorize or decline |
| The observer-lane drift read actually reporting | REL-01 | A `workflow_run` lane only ever executes the default-branch copy of its file, so it cannot run from a phase branch | After merge, confirm the `tag_ruleset_drift` job ran and is green on a post-merge run; recorded as a follow-up, never claimed as proven in-phase |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 238s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** {pending / approved YYYY-MM-DD}
