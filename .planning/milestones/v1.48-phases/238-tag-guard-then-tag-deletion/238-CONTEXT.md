# Phase 238: Tag Guard, Then Tag Deletion - Context

**Gathered:** 2026-09-16 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The `v*` tag namespace means exactly one thing — a real release — and cannot be re-polluted
by the next close flow. In scope: a server-side GitHub tag ruleset proven RED first, a paired
repo-side contract test, allowlist-driven deletion of the 28 `v1.NN` planning tags and 11
`phase-238-*` proof tags (local and remote), and the ADR 003 amendment that records the
prescribed future namespaces.

Explicitly NOT in scope: branch pruning (Phase 245), the Hex `1.20.0` retire (Phase 242),
cutting release 1.5.1 (Phase 242), and any change to ruleset 14941512 (the `main` branch
ruleset) — this phase adds a **sibling** ruleset and never edits the existing one.
</domain>

<decisions>
## Implementation Decisions

### Feasibility gate (must run before anything else is built)

- **D-01:** Plan 238-01 opens with a **feasibility probe**, because `tag_name_pattern` is a
  GitHub *metadata restriction* and the current dotcom "Available rules for rulesets" page
  routes metadata rules to the **GitHub Enterprise Cloud** documentation — the standard
  GitHub Docs marker for a higher-plan-only feature. `szTheory/sigra` is a **User-owned
  public repo on GitHub Free** (`plan: null`). The probe is `POST /repos/szTheory/sigra/rulesets`
  with the D-03 body but `"enforcement": "disabled"` (a disabled ruleset enforces nothing),
  followed immediately by `DELETE /repos/szTheory/sigra/rulesets/{id}`. A `422`/`403` naming
  the rule type means plan-gated. **Nothing else in this phase may be planned as settled
  until this probe returns.** The probe could not be run during discussion — the harness
  permission classifier blocks repo-settings writes — so it is an execution step, and its
  result is recorded as an evidence slot, not assumed.

- **D-02:** **If the probe shows `tag_name_pattern` is plan-gated**, do NOT substitute a
  `creation` rule scoped to `refs/tags/v*` — that is name-scoped rather than pattern-scoped
  and would block release-please's own `v1.5.1` push outright (Phase 242 / REL-06). The
  decided fallback is a two-part shift-left guard, in this order of value:
  (a) a committed `pre-push` git hook (installed by a committed script, so it is reproducible
  rather than a local snowflake) that rejects a non-SemVer `v*` tag **at the source** — the
  GSD close flow is what mints these tags, so this is where the recurrence actually lives; and
  (b) a `on: push: tags: ['v*']` workflow that hard-fails and opens an issue when a non-SemVer
  `v*` tag lands anyway — detection for whatever bypasses the hook.
  This fallback is **detection + local prevention, not server-side prevention**, and every
  artifact must say so in those words. REL-01's text ("a GitHub tag ruleset (server-side)")
  would then be unsatisfiable as written and must be amended as a **recorded supersession**
  in `.planning/REQUIREMENTS.md`, following the TEST-01/02 precedent — never quietly re-scoped.

### Ruleset shape

- **D-03:** The ruleset is a **new, sibling** ruleset (the repo already has exactly one:
  `main`, id `14941512`, `target: "branch"`). Exact shape:
  `target: "tag"`, `enforcement: "active"`, `bypass_actors: []`,
  `conditions.ref_name.include: ["refs/tags/v*"]`, `exclude: []`, and **exactly one rule**:
  `tag_name_pattern` with `operator: "regex"`, `negate: false` (negate false = "must match";
  `negate: true` means "fails if the pattern matches"), and GitHub's own documented SemVer
  regex with a `v` prefix, anchored `^v…$`.
  The pattern is matched against the **bare tag name**, not the full ref.

- **D-04:** The ruleset contains **no `creation` rule and no `deletion` rule**, ever.
  `creation` on `refs/tags/v*` would block release-please (D-02); `deletion` would permanently
  re-create the delete-deadlock described in D-06. The UI wizard selects "Restrict deletions"
  **by default** — the API applies no defaults, so this is a reason to create the ruleset via
  API and never through the Settings wizard.

- **D-05:** `bypass_actors: []` stays empty. Rulesets have **no implicit admin bypass** (unlike
  classic branch protection), so this also binds the repo owner — which is the point of the
  phase. It is safe for release-please: `release-please.yml:92` acts as either the
  `RELEASE_PLEASE_TOKEN` PAT or `github-actions[bot]`, and the tag it creates (`v1.5.1`, or a
  `v1.5.1-rc.1` prerelease) **matches** the D-03 pattern, so no bypass is needed. Adding any
  bypass actor weakens the guard and invalidates the RED proof — do not.

### Ordering: the delete-deadlock, resolved empirically

- **D-06:** GitHub does not document whether `tag_name_pattern` is evaluated on a *delete*
  push. If it is, the phase deadlocks on **exactly** the tags it must delete, because those
  are precisely the ones that fail the pattern. Rather than assume either way, the sequence
  below answers it as a side effect of a proof the phase already owes, and requires no
  extra cycle:

  1. Create the ruleset **`active`** (after D-01).
  2. SC-1 proof, immediately: push scratch tag `v9.9` → expect **reject**; push
     `v9.9.9-rulesettest` → expect **accept**.
  3. Delete scratch tag `v9.9.9-rulesettest`. **This delete IS the deletion-blocking probe** —
     it is a `v*` tag in scope of the ruleset. Record the outcome as its own evidence slot.
  4. If step 3 succeeded, deletion is unaffected: delete the 39 tags with enforcement left
     **active** (true guard-first, the phase title's literal reading).
     If step 3 was rejected (`GH013`), flip the ruleset to `enforcement: "disabled"`, perform
     the deletions, then flip back to `active` — and record the flip window, with the reason,
     in the evidence ledger. The guard *object* still landed before any deletion, satisfying
     REL-01's "lands before any deletion".

  Note the API/web-UI delete route (`DELETE /repos/{o}/{r}/git/refs/tags/{tag}`) is evaluated
  by rulesets too — it is **not** a workaround for a blocked `git push --delete`.
  Also note: the owner is not bypassed (D-05), so "admin just forces it" is not available.

- **D-07:** Non-`v` tags are out of the ruleset's scope entirely. `conditions.ref_name.include`
  is the scope gate, and `refs/tags/v*` is **fnmatch with `FNM_PATHNAME`**, so `*` does not
  cross `/`. Therefore `archive/local-main-pre-235-recovery`, the existing `phase-238-*` tags,
  and the future `milestone/` + `proof/` namespaces are all untouched by the rule. Consequence
  to state honestly in the ADR: this ruleset does **not** prevent a future `phase-NNN-*` junk
  tag — it only guarantees the `v*` namespace. Making it also cover junk tags would require
  a `~ALL` condition, which would put release-please and every other tag in scope; rejected.

### Contract test (SC-2)

- **D-08:** The guard ships as `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`
  — `p19` because `p01`–`p17` exist on disk and **`p18-*` is reserved for SURF-04** by
  `.planning/REQUIREMENTS.md:37`. It is wired **only** through the existing glob step at
  `.github/workflows/ci.yml:392` (`node --test … scripts/ci/prohibitions/*.test.mjs` inside
  `fast_checks`) — the glob is load-bearing and picks the file up with **zero workflow edits**.
  It is never added to `mix ci`, and it is **not** placed in `release_ref_guard`
  (`ci.yml:62`), which short-circuits on non-`workflow_dispatch` events and would never run —
  SC-1 forbids this explicitly.

- **D-09:** The PR-lane half is **offline and structural**: its subject (via `subjectPath()`,
  one substitutable artifact only, per `_lib.mjs`) is a **committed verbatim snapshot** of the
  live ruleset at `.github/rulesets/tag-namespace.json`, captured with
  `gh api repos/szTheory/sigra/rulesets/{id}`. RED is proven against a committed known-bad
  fixture at `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json`.
  No `gh`, no token, no network on the pull_request critical path — `p12`'s header states that
  prohibition directly, and this milestone exists to remove that class of flake.

- **D-10:** The contract test asserts `target == "tag"`, `enforcement == "active"`,
  `conditions.ref_name.include`, and the `tag_name_pattern` rule's `operator` / `negate` /
  `pattern`. It **must NOT assert `bypass_actors == []`**: GitHub returns `bypass_actors`
  *only* to callers with write access to the ruleset, so at CI/anonymous permission level an
  empty array and a populated one are indistinguishable — asserting it would be a vacuous
  green. The `bypass_actors` assertion moves to the operator-side check (D-11).

- **D-11:** The live half — which catches "someone deleted the ruleset in Settings while the
  committed snapshot stayed put" — is a **two-step** `GET /rulesets` → `GET /rulesets/{id}`
  read (the list endpoint returns summary fields only; `target`, `conditions` and `rules` come
  back only from the by-id call). It needs just **Metadata: read** and works with the default
  Actions `GITHUB_TOKEN` on this public repo, so it goes in `.github/workflows/ci-observe.yml`
  (`workflow_run`, non-PR, off the `ci-gate` DAG, already carries `GH_TOKEN: ${{ github.token }}`),
  diffing live-vs-committed snapshot. Honest caveat to record: `ci-observe.yml:23` notes
  `workflow_run` only ever runs the **default-branch** copy of the file, so this check cannot
  be proven working from the PR branch — it begins running only after merge. Say that plainly;
  do not claim it as proven in-phase. The `gh api … --jq` operator one-liner is added to
  `MAINTAINING.md` as a sibling of the existing §"Branch protection — enforced required checks
  (live ruleset)" (`MAINTAINING.md:100-124`), which already documents ruleset 14941512 in
  exactly this shape.

### Delete list and the destructive procedure

- **D-12:** The explicit allowlist is a committed TSV at
  `.planning/decisions/003-tag-delete-list.tsv` — beside the ADR, **not** under
  `.planning/phases/238-*/`, because phase directories MOVE to
  `.planning/milestones/v<X.Y>-phases/` at milestone close (the hazard `_lib.mjs:42-48`
  documents by name as `archiveAwareRelPath`). SC-5 requires ADR 003 to cite the delete-list
  path, and a phase-local path would rot into a dead link the moment the milestone closes.
  Format follows `.github/ci-skip-manifest.tsv` (comment header + TSV), columns:
  `tag`, `local` (yes/no), `remote` (yes/no), `class` (`planning-milestone` | `phase-proof`),
  `pre_delete_sha`, `reason`. One row per tag, 39 rows. `archive/*` is handled by **exclusion**,
  never by a row.

- **D-13:** The delete set is **never** a glob at the `git tag -d` call site — `v1.4*` matches
  both `v1.4` and `v1.4.0`, which is the exact footgun SC-3 names. Deletion runs from a
  committed script `scripts/maintainers/delete-planning-tags.sh` (dry-run by default,
  `--apply` required, local pass → verify → remote pass as **separate invocations**, never one
  command), and `MAINTAINING.md` gains a short runbook subsection pointing at it. Both the
  script and the runbook — not either alone. `scripts/maintainers/` is already the operator-script
  home (`planning-audit-hygiene.sh`).

- **D-14:** Post-deletion set-equality is asserted **per side, separately**, both regex-derived
  with **no count hardcoded anywhere**:
  - local keep-set = `^v[0-9]+\.[0-9]+\.[0-9]+$` ∪ `^archive/` → **13 tags**
  - remote keep-set = `^v[0-9]+\.[0-9]+\.[0-9]+$` only → **12 tags** (`archive/*` is local-only)

  This asymmetry is real and load-bearing: of the 28 `v1.NN` tags only **10** are on `origin`
  (`v1.1 v1.3 v1.4 v1.5 v1.14 v1.21 v1.26 v1.28 v1.33 v1.48`), all 11 `phase-238-*` are on
  `origin`, and `archive/local-main-pre-235-recovery` is **not** on `origin` at all. A shared
  keep-set expression would fail. `git push origin --delete` on a local-only tag errors — the
  script must drive the remote pass from the `remote=yes` rows only.

- **D-15:** The 11 `phase-238-*` tags are **unreachable from `origin/main`** but are held by
  branch `gsd/238-generated-auth-runtime-proof-evidence` (local and on `origin`), which
  **Phase 245 is scheduled to prune and does not list among its protected survivors**
  (`ROADMAP.md:248`). Deleting these tags is therefore safe *now* and only becomes lossy if
  245 later removes that branch. The `pre_delete_sha` column (D-12) is the forward-feed that
  closes this: it names every SHA before it stops being tag-reachable, reproducing the
  `237-GIT-OBJECT-SNAPSHOT.md` precedent. Phase 245's SC-4 (no `git gc` / `reflog expire` /
  `--prune=now` anywhere in this milestone) means nothing is actually collected in the interim.
  Also note these tags are named for an **older** phase 238 (generated-auth runtime proof,
  Aug 2026) — a collision with the phase now being planned. The TSV's `reason` column must
  make that unambiguous for anyone reading it later.

### Evidence and the ADR amendment

- **D-16:** Live observations (SC-1's reject/accept probe, SC-3's set-equality, SC-4's release
  counts, D-06's delete probe, D-01's feasibility result) are recorded in
  `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` using the
  `## BEFORE-*` / `## AFTER-*` slot grammar, each slot with a `Status:` line and a real fenced
  producing command. This is a **machine-enforced format contract**, not a style preference:
  `_lib.mjs:257-262` (`SLOT_HEADING_RE`, `parseEvidenceSlots`) is generic across every
  `.planning/phases/*/*-EVIDENCE.md`, and `p12` hard-fails a captured slot lacking a run id or
  fenced command — a malformed ledger reddens `fast_checks` for the whole repo.

- **D-17:** A pre-change settings record `238-TAG-RULESET-RECORD.md` is committed **before**
  the ruleset is created, with YAML frontmatter `kind: outward-facing-settings-change-record`,
  following `237-PAGES-SETTING-RECORD.md` exactly — so a revert is by recorded value rather
  than reconstruction. It records the pre-change `gh api repos/szTheory/sigra/rulesets`
  payload (currently: exactly one ruleset, `main` / `14941512`).

- **D-18:** SC-1's RED proof is citable **by id**, not by screenshot: after the rejected `v9.9`
  push, capture the `rule_suite_id` from `GET /repos/{o}/{r}/rulesets/rule-suites` plus the
  matching `rule_evaluations[]` entry (`rule_type: "tag_name_pattern"`, `result: "fail"`, and
  its `details` string). Constraint: rule-suites requires **Administration: read**, which an
  Actions `GITHUB_TOKEN` cannot be granted (there is no `administration:` key in a workflow
  `permissions:` block) — so this capture runs **locally as the owner**, and must happen inside
  the `time_period` window (default `day`, max `month`). **Embed the fetched JSON in the
  evidence file, not just the id**, since the window expires.

- **D-19:** ADR 003 is amended **in place** with a dated `## Amendment — 2026-09-16 (Phase 238)`
  section (there is no superseding-ADR precedent in `.planning/decisions/` — only 001, 002, 003
  exist and none is amended), keeping `**Status:** Accepted`. It extends guardrail 3
  (`003-…:36`, "Do not mint milestone `vX.Y` git tags") with: the deletion date, the path to
  `003-tag-delete-list.tsv`, the prescribed `milestone/` and `proof/` namespaces for future
  non-release tags, and — per D-07 — a plain statement of what the ruleset does **not** cover.

### Claude's Discretion

- Exact TSV column ordering and comment-header wording, the `p19` guard's internal assertion
  decomposition, and the wording of the `MAINTAINING.md` subsections.
- Whether the `pre-push` hook fallback (D-02) is also installed unconditionally as
  defence-in-depth even when the ruleset works. Recommended yes if it costs one committed
  script — it prevents at the source, which is where the recurrence lives — but it is not
  required by any success criterion, so it must not grow the phase.

### Folded Todos

None. All 51 `todo.match-phase` hits were keyword-similarity noise (`ci`/`release`/`docs` area
matches on words like "phase", "source", "push", "guard") with no bearing on tag namespace
work. See `<deferred>`.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — "### Phase 238" (5 Success Criteria, authoritative) and
  "### Phase 245" lines 240-251 (the branch-prune coupling behind D-15)
- `.planning/REQUIREMENTS.md:25-26` (REL-01, REL-02) and `:37` (SURF-04 — `p18-*` is reserved;
  "Never added to `mix ci`")
- `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` — especially
  guardrail 3 at line 36, the clause D-19 amends
- `scripts/ci/prohibitions/_lib.mjs` — lines 11-22 (fail-first protocol, node:test mandate),
  33-38 (`subjectPath`, one substitutable artifact), 42-48 (`archiveAwareRelPath` rot hazard
  behind D-12), 257-262 (`SLOT_HEADING_RE` / `parseEvidenceSlots` behind D-16)
- `scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:1-20` — why guards are offline
  (D-09) and the evidence-ledger assertions the 238 ledger must satisfy
- `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs:1-30` — the most recent
  guard; the model for header prose, fixture pairing and comment-stripping discipline
- `.github/workflows/ci.yml:383-393` — the only CI entry point for prohibition guards
  (`fast_checks`; the shell glob is load-bearing); `:62` `release_ref_guard` (SC-1 forbids
  placing the guard here)
- `.github/workflows/ci-observe.yml:1-31, 45-53` — the non-gate observer lane and its
  default-branch-only caveat (D-11)
- `.github/workflows/release-please.yml:88-92` — the tag-creating actor behind D-05
- `.github/ci-skip-manifest.tsv:1-20` — committed-manifest format; "prose renders the data
  file, not a second source of truth"
- `MAINTAINING.md:100-124` — the existing live-ruleset documentation pattern D-11 mirrors
- `mix.exs:207-208` — `source_ref: "v#{@version}"`, the HexDocs "View source" constraint in SC-4
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-PAGES-SETTING-RECORD.md:1-50`
  — pre-change settings-record convention (D-17)
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md:1-24`
  — pre-mutation ref inventory convention (the delete-list's ancestor, D-12/D-15)
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-EVIDENCE.md:1-20`
  — evidence-ledger slot model (D-16)
- GitHub REST "Repository rules": https://docs.github.com/en/rest/repos/rules — `bypass_actors`
  visibility rule (D-10), list-vs-by-id field asymmetry (D-11), rule-type semantics (D-04)
- GitHub REST "Rule suites": https://docs.github.com/en/rest/repos/rule-suites — D-18
- GitHub "Available rules for rulesets" + "About rulesets" — the metadata-restriction plan
  gating behind D-01
</canonical_refs>

<code_context>
## Existing Code Insights

### Verified starting state (measured 2026-09-16, not assumed)

- **Tag namespace partitions with zero unclassified tags.** Local 52 = 12 three-component
  SemVer + 1 `archive/*` + 28 `v1.NN` + 11 `phase-238-*`. Remote 33 = 12 + 0 + 10 + 11.
  The ROADMAP's counts (28 and 11) are exact.
- **Deletion cannot untag a release.** All 12 GitHub Releases are backed by three-component
  SemVer tags; a scan for releases on non-SemVer tags returns NONE. `gh release list` = 12,
  drafts = 0 — so SC-4's before/after is a clean `12 == 12` / `0 drafts`.
- **HexDocs "View source" is structurally safe.** `mix.exs:208` pins
  `source_ref: "v#{@version}"` → `v1.5.0`, a keep-set tag. `mix.exs:207` already carries a
  comment warning about exactly this failure mode.
- **One existing ruleset only**: `main`, id `14941512`, `target: "branch"`,
  `source_type: "Repository"` (Settings-managed, not committed as code), rules `deletion`,
  `non_fast_forward`, `pull_request`, `required_status_checks`. This phase does not touch it.
- **Repo plan**: User-owned public, `plan: null` (GitHub Free) — the fact that drives D-01.

### Reusable Assets

- `scripts/ci/prohibitions/_lib.mjs` — `subjectPath`/`readSubject` substitution, the
  `GSD_PROHIB_SUBJECT` fail-first protocol, and `parseEvidenceSlots`. New guards inherit all of it.
- `test/fixtures/prohibitions/` — 14 committed known-bad fixtures (`p01`–`p13`, `p17`);
  `p17` is the most recent and the closest model for a new pairing.
- `scripts/maintainers/planning-audit-hygiene.sh` — establishes the operator-script home.
- `.github/workflows/ci-observe.yml` — an existing off-gate lane with `GH_TOKEN` already wired.

### Established Patterns

- **Guards are offline on the PR path.** No `gh`, no token, no network in `fast_checks`
  prohibitions; live reads live in `ci-observe`.
- **Committed data file + prose renderer.** `ci-skip-manifest.tsv` and `MAINTAINING.md`
  demonstrate that prose documents a committed file rather than duplicating it.
- **Mutations get a pre-change record.** Outward-facing settings changes commit their
  pre-change value first, so revert is by recorded value.
- **Evidence ledgers are machine-parsed**, not narrative.

### Integration Points

- `ci.yml:392`'s glob — `p19` needs no workflow edit to start running.
- `ci-observe.yml` — one new step for the live drift read.
- `MAINTAINING.md` — two new subsections (live tag ruleset; delete-tags runbook).
- `.planning/decisions/` — ADR 003 amendment + the new delete-list TSV.
- **Phase 245** consumes D-12's `pre_delete_sha` column; **Phase 242** depends on D-05 being
  right about release-please.
</code_context>

<specifics>
## Specific Ideas

- The SC-1 scratch-tag proof does double duty by design (D-06): deleting the *accepted*
  scratch tag `v9.9.9-rulesettest` is itself the deletion-blocking probe, so the phase learns
  whether deletes are blocked without spending a separate cycle on it.
- Operator bias recorded for this phase: prefer automation and shifting left, **but only
  where the value recurs**. Applied as — the `p19` offline guard (runs every PR, forever) and
  the `ci-observe` drift read (runs every push to main, forever) are both worth building; the
  one-shot deletion is a dry-run-default committed script rather than a CI job, because it
  executes once and its value is auditability, not repetition.
</specifics>

<deferred>
## Deferred Ideas

- **A `~ALL` tag ruleset covering non-`v` junk tags** (e.g. a future `phase-NNN-*` class) —
  rejected for this phase in D-07 because it would put release-please and every other tag in
  scope. If wanted later, it is its own decision with its own RED proof.
- **A `milestone/` + `proof/` namespace convention enforced by a guard** — D-19 *records* the
  prescribed namespaces in ADR 003; mechanically enforcing them is not scoped here.
- **Amending REL-01's wording** — only becomes necessary if D-01's probe fails; tracked in
  D-02 as a recorded supersession rather than a silent re-scope.

### Reviewed Todos (not folded)

All 51 `todo.match-phase` hits reviewed and **none folded**. The matcher scored on generic
keyword overlap ("phase", "source", "push", "guard", "release") and area tags (`ci`,
`release`), not on tag-namespace relevance. The two highest-signal-looking ones are explicitly
other phases' work: `2026-07-03-hex-retire-stray-1-20-0.md` is **Phase 242** (REL-03), and
`2026-07-10-upgrade-smoke-button-type-hex-publish.md` is release-lane work already resolved.
No pending todo concerns the `v*` tag namespace.
</deferred>
