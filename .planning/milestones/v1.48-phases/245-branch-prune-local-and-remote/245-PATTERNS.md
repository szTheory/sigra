# Phase 245: Branch Prune — Local and Remote - Pattern Map

**Mapped:** 2026-10-02  
**Files analyzed:** 5 pruning artifacts plus 3 coordinator diagnostic/source analogs and the observed Plan 245-28 receipt  
**Analogs found:** 4 / 5 pruning artifacts; coordinator source/test patterns found, with no tracked admission-diagnostic receipt analog

## File Classification

| Relevant file or candidate | Role | Data Flow | Closest Analog | Match Quality / status |
|---------------------------|------|-----------|----------------|------------------------|
| `.planning/phases/245-branch-prune-local-and-remote/245-GIT-REF-SNAPSHOT.md` | evidence artifact | batch capture | `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md` | role-match |
| `.planning/phases/245-branch-prune-local-and-remote/245-BRANCH-DELETE-ALLOWLIST.tsv` | config/data | batch input | `.planning/decisions/003-tag-delete-list.tsv` | role-match |
| `.planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json` | evidence artifact | request-response capture | `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json` (untracked input; not a copyable analog) | no tracked analog |
| `.planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.md` | evidence artifact | batch / live-state verification | `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` | role-match |
| `.planning/phases/245-branch-prune-local-and-remote/245-VERIFICATION.md` | verification report | batch validation | `.planning/phases/238-tag-guard-then-tag-deletion/238-VERIFICATION.md` | role-match |

### Coordinator admission diagnostic/recovery gap (Plan 245-28)

These rows map the observed blocked admission and the separately scoped diagnostic gap surfaced by the refreshed research. The Plan 245-28 recovery receipt exists; it is evidence for the single failed attempt, not authorization for another attempt. The proposed fixture cases in RESEARCH.md are future test design only and do not authorize production gate/lock mutation or ref operations.

| Relevant file or candidate | Role | Data Flow | Closest Analog | Match Quality / status |
|---------------------------|------|-----------|----------------|------------------------|
| `scripts/maintainers/repo-mutation-coordinator.sh` | utility | request-response | same file, current admission implementation | exact source path; gate-entry diagnosis |
| `scripts/maintainers/repo-mutation-coordinator.test.sh` | test | event-driven | same file, disposable coordinator contention fixtures | exact source path; existing lease/lock cases |
| `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json` | evidence artifact | batch capture | `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` plus this receipt's existing schema | role-match; receipt is untracked here |
| `.planning/phases/245-branch-prune-local-and-remote/245-28-ADMISSION-DIAGNOSTIC.json` (only if a separately authorized diagnosis defines this artifact) | evidence artifact | batch capture | `245-28-RECOVERY.json` | role-match; no such diagnostic artifact or approved filename exists |

No new production coordinator helper is implied. If an approved diagnostic later adds a deterministic fixture, keep it inside disposable repositories and extend the tracked test file above; do not alter production gate/lock state. The only observed Plan 245-28 admission outcome remains one attempt returning `coordinator_admission_gate_busy_or_stale`; the cause is unknown.

No application source change is implied by CONTEXT.md or RESEARCH.md. If planning introduces a one-shot branch-prune script, treat `scripts/maintainers/delete-planning-tags.sh` as its closest operational analog; keep it out of CI and require explicit apply mode.

## Pattern Assignments

### Coordinator admission diagnostic/recovery gap

**Observed failure (do not reinterpret):** Plan 245-28 made one authorized admission attempt. It returned `coordinator_admission_gate_busy_or_stale`; the preceding and following read-only status checks saw verified coordinator state, a free lock, zero transaction leases, and no gate directory. The receipt records unchanged HEAD and staged digest, Task 2 not started, and zero production ref operations. The cause remains unknown because process enumeration was denied and no owner/OS error was captured at the failing `mkdir`. Sources: `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json:5-16,34-63` and `245-RESEARCH.md:268-297`.

**Admission implementation:** `scripts/maintainers/repo-mutation-coordinator.sh` (tracked).

**Path resolution and gate location** (lines 49-65):

```bash
common_dir="$(git -C "$SIGRA_COORDINATOR_REPO" rev-parse --git-common-dir 2>/dev/null)" \
  || sigra_coordinator_set_error 'git_common_directory_unavailable' || return 1
if [[ "$common_dir" != /* ]]; then common_dir="${SIGRA_COORDINATOR_REPO}/${common_dir}"; fi
SIGRA_COORDINATOR_COMMON_DIR="$(cd "$common_dir" 2>/dev/null && pwd -P)" \
  || sigra_coordinator_set_error 'git_common_directory_unresolvable' || return 1
SIGRA_COORDINATOR_ROOT="${SIGRA_COORDINATOR_COMMON_DIR}/${SIGRA_COORDINATOR_DIR_NAME}"
SIGRA_COORDINATOR_GATE_DIR="${SIGRA_COORDINATOR_ROOT}/gate"
```

Use this to resolve and report the exact shared path in a future read-only diagnostic. Do not assume the worktree's `.git` path is the common coordinator root.

**Gate error boundary** (lines 145-157, 352-371):

```bash
sigra_coordinator_gate_enter() {
  if ! mkdir "$SIGRA_COORDINATOR_GATE_DIR" 2>/dev/null; then
    sigra_coordinator_set_error 'coordinator_admission_gate_busy_or_stale'
  fi
  SIGRA_COORDINATOR_GATE_HELD=1
  if ! printf '%s\n' "$$" > "${SIGRA_COORDINATOR_GATE_DIR}/pid"; then
```

```bash
sigra_coordinator_verify "$requested_repo" || return 1
sigra_coordinator_gate_enter || return 1
if [[ -d "$SIGRA_COORDINATOR_LOCK_DIR" ]]; then
  sigra_coordinator_gate_leave || true
  sigra_coordinator_set_error 'coordinator_busy_or_stale_lock_present'
  return 1
fi
```

The generic error is set on any nonzero `mkdir`; this code does not distinguish an existing gate from permissions, a non-directory path component, or other OS failures. The later lock/lease checks are not reached when gate entry fails. Preserve this distinction in diagnostics; do not report contention as the established cause.

**Disposable fixture pattern:** `scripts/maintainers/repo-mutation-coordinator.test.sh` (tracked), lines 154-180 and 182-207:

```bash
if bash "$COORDINATOR" run --repo "$MAIN" --operation must-not-acquire -- touch "$TEMP_DIR/must-not-run" >"$TEMP_DIR/lease-acquire.log" 2>&1; then
  fail 'coordinator acquired during an in-flight ref transaction'
fi
grep -q coordinator_ref_transactions_in_flight "$TEMP_DIR/lease-acquire.log" || fail 'in-flight lease was not reported'
[[ ! -e "$TEMP_DIR/must-not-run" ]] || fail 'command ran after rejected acquisition'
```

```bash
if bash "$COORDINATOR" run --repo "$MAIN" --operation competing-apply -- \
  touch "$TEMP_DIR/second-owner-ran" >"$TEMP_DIR/competing-owner.log" 2>&1; then
  fail 'second coordinator owner acquired while the first owner was active'
fi
grep -q coordinator_busy_or_stale_lock_present "$TEMP_DIR/competing-owner.log" \
  || fail 'second coordinator owner did not report the held common lock'
[[ ! -e "$TEMP_DIR/second-owner-ran" ]] || fail 'competing owner command ran while lock was held'
```

Reuse the isolated fixture setup, synchronized FIFO coordination, explicit expected error, and proof that a rejected admission never runs its child command. Existing cases test a held lock and transaction leases, not contention at the short-lived gate `mkdir` itself. Research's suggested gate-holder and injected-`mkdir` cases are unimplemented proposals; add them only under an independently authorized test scope. Do not retry a production admission to gather that evidence.

**Blocked receipt pattern:** `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json` (untracked in this checkout; observed context, not a tracked-code analog). Its structured fields preserve `outcome`, `failed_stage`, `admission_attempts`, exact error code/command/exit/stderr, before/after observations, unchanged staged identity, and `production_ref_operations: 0`. For any separately authorized diagnostic receipt, retain timestamped observations and command status, redact coordinator token material, and record denied process/OS evidence as unknown. Do not overwrite this recovery receipt to transform the historical failure into a retry result.

The closest tracked evidence format is `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` lines 1-36: named evidence slots with capture status and producing command. The receipt's JSON shape itself has no tracked analog. `.planning/phases/245-branch-prune-local-and-remote/245-28-PLAN.md` lines 104-107 is the plan-level safety boundary: one admission, and on failure stop without retry, gate/lock repair, or ref operations.

### `.planning/phases/245-branch-prune-local-and-remote/245-GIT-REF-SNAPSHOT.md` (evidence artifact, batch capture)

**Analog:** `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md` (tracked)

**Evidence framing** (lines 1-5):

```markdown
# Phase 237 Plan 03 — Git Object Snapshot

Pre-prune inventory ... captured before any mutating command ran ... Recorded so the retirement ... is provably non-destructive: every SHA that existed before the prune is named here first.
```

Use the same before-mutation framing, but record complete local `for-each-ref` and live `origin` inventories separately. Include ref name, direct object ID/type, peeled object ID/type, and symref target as specified by RESEARCH; do not substitute worktree/stash inventory or remote-tracking refs for live server state. The tracked snapshot also has a deliberately explicit “SC-3 STASH HALF — DELIBERATELY UNMET (D-09)” section at lines 80-92; preserve that clarity by stating stashes are untouched and the prohibited GC/reflog operations did not run.

### `.planning/phases/245-branch-prune-local-and-remote/245-BRANCH-DELETE-ALLOWLIST.tsv` (config/data, batch input)

**Analog:** `.planning/decisions/003-tag-delete-list.tsv` (tracked); its consuming guard is `scripts/maintainers/delete-planning-tags.sh` (tracked).

**Allowlist safety pattern** (`scripts/maintainers/delete-planning-tags.sh`, lines 13-30, 121-149):

```bash
# The delete set comes ONLY from the allowlist. No glob, no wildcard, no prefix
# expansion ever reaches a delete invocation.
# Exactly ONE pass runs per invocation ... local and remote passes are separate.
[[ "$line" == "$EXPECTED_HEADER" ]] || fail "allowlist_header_missing_or_wrong"
[[ "$fields" -eq 6 ]] || fail "allowlist_row_wrong_column_count"
[[ "$row_count" -ge 1 ]] || fail "allowlist_parsed_zero_rows"
```

Use exact full branch names and separate local/remote disposition fields; freeze the list only after live inventory and PR/safety exclusions. Reject missing headers, malformed rows, empty candidate sets, duplicates, unsafe names, and candidates that overlap protected refs. The existing script is a tag tool: do not reuse its tag selectors or assume its keep regexes apply to branches.

**Local/remote separation and failed-read handling** (lines 161-168, 198-235):

```bash
git ls-remote --tags origin > "$raw" </dev/null \
  || fail "remote_listing_failed: ... (no ref was touched)"
...
git push origin --delete "$tag"
```

For any new branch operation, keep local and remote passes independent, verify remote reads before parsing, and send only one literal reviewed name to each mutation. For safety refs absent remotely, publish only at exact local identity; same-name/different-object is a stop condition. Never use `--force`, `--mirror`, or broad prune behavior.

### `.planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json` (evidence artifact, request-response capture)

**Historical input:** `243-STALE-PR-EVIDENCE.json` is untracked in this checkout (confirmed by `git ls-files`); it is context only and must not be presented as a tracked codebase analog. Its content records PR #219 as open with head `gsd/238-generated-auth-runtime-proof-evidence` and explicitly says no branches were deleted (rows 67-78, 119-130). Refresh the full head/base exclusion data at execution time with the live `gh pr list` result, then capture post-prune state. Preserve number, state, head/base names and OIDs, capture time, and query identity; treat Phase 243 values as historical comparison only.

**Readiness source:** `.planning/STATE.md` is tracked and currently says Phase 244 Plan 03 is blocked on the separate Phase 242 workflow contract todo (lines 29-37). The Phase 244 `continue.md` handoff and Plan 03 summary are untracked in this checkout; use them to understand the blocker, but do not cite them as tracked analogs. No branch deletion starts until Phase 244 completion and ref-dependent work resolution are confirmed at execution time.

### `.planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.md` (evidence artifact, batch / live-state verification)

**Analog:** `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` (tracked)

**Ledger structure** (lines 1-36):

```markdown
# Phase 238 Evidence Ledger

Observed at commit: <commit>
...
| Slot | What it is | How captured | Status |
| ... | ... | ... | captured |
```

Copy the named before/after slots and per-slot `Status: captured` plus fenced producing command convention. Suggested slots: readiness gate, local ref snapshot, live origin snapshot, safety-ref identity baseline, live PR heads+bases, frozen candidates, local deletion/readback, remote deletion/readback, object-resolution proof against the committed snapshot, post-prune PR/base integrity, and prohibited-cleanup assertion. Every slot must distinguish captured evidence from pending or failed evidence. The 238 ledger is a format precedent; its tag/ruleset facts do not transfer.

### `.planning/phases/245-branch-prune-local-and-remote/245-VERIFICATION.md` (verification report, batch validation)

**Analog:** `.planning/phases/238-tag-guard-then-tag-deletion/238-VERIFICATION.md` (tracked)

**Requirement mapping and spot-check pattern** (lines 146-189):

```markdown
### Required Artifacts
| Artifact | Expected | Status | Details |
...
### Behavioral Spot-Checks
| Behavior | Command | Result | Status |
```

Map REPO-04 to direct evidence: committed non-empty snapshot; exact reviewed allowlist; each recorded direct/peeled SHA passes `git cat-file -e`; required safety refs retain type and object identity; no open PR head or base overlaps deletion candidates; all open PRs and base refs pass postchecks; local and remote outcomes match expected sets; explicit milestone-wide no-GC/reflog-expiry/`--prune=now` statement. A zero-failure count over an empty/missing snapshot is not a pass. Phase 238's row 187 demonstrates explicit per-SHA reachability checking and row 189 checks refs remain unchanged during read-only checks.

## Shared Patterns

### Coordinator admission diagnostics

**Sources:** tracked `scripts/maintainers/repo-mutation-coordinator.sh` lines 49-65, 145-157, 352-371; tracked `scripts/maintainers/repo-mutation-coordinator.test.sh` lines 154-207.  
**Apply to:** only a separately authorized future disposable-fixture diagnosis and its evidence artifact.

- Record the common-dir-derived root, exact gate path, and read-only path observations.
- Distinguish the gate error from later lock and transaction-lease errors. The gate error alone does not prove that the path existed.
- In fixture tests, synchronize the contender and gate holder; assert the child command does not run on rejection and isolate all state in the disposable common directory.
- Preserve Plan 245-28's one-attempt/no-retry/no-repair boundary. This map authorizes neither another production coordinator admission nor any production ref operation.

### Fail-closed destructive Git work

**Source:** `scripts/maintainers/delete-planning-tags.sh` (tracked), lines 7-30, 121-149, 161-168, 198-235.  
**Apply to:** Any Phase 245 operation script or destructive plan actions.

- Report-only by default; mutation requires an explicit apply step.
- Validate a committed, non-empty, literal-name allowlist before mutation.
- Local and remote mutation/readback are separate passes.
- Failed remote enumeration is an error, never an empty inventory.
- Capture and compare ref type and full object identity; stop on collisions.

### Evidence provenance

**Source:** tracked `237-GIT-OBJECT-SNAPSHOT.md` lines 1-5 and tracked `238-EVIDENCE.md` lines 1-36.  
**Apply to:** Snapshot, live-state captures, execution evidence, verification.

Commit the pre-prune baseline before deletion and point postchecks at that committed artifact. For live GitHub state, store the producing command, timestamp, and exact output or normalized machine-readable response. Historical Phase 243 PR data is not an execution-time exclusion list.

### Object recoverability and stash boundary

**Source:** `237-GIT-OBJECT-SNAPSHOT.md` lines 80-112; `.planning/phases/238-tag-guard-then-tag-deletion/238-VERIFICATION.md` row 187.  
**Apply to:** Post-prune evidence and phase summary.

Check each SHA recorded in the committed pre-prune inventory with `git cat-file -e`, including annotated-tag object IDs and peeled targets. Leave stashes untouched. State explicitly in the phase summary that no `git gc`, `git reflog expire`, or `--prune=now` ran anywhere in the milestone.

## No Tracked Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `245-OPEN-PR-STATE.json` | evidence artifact | request-response capture | Phase 243's closest PR-state capture is untracked in this checkout; generate fresh evidence with the live `gh` query and use tracked evidence-ledger conventions for its provenance. |
| `245-28-ADMISSION-DIAGNOSTIC.json` (candidate only; filename unapproved) | evidence artifact | batch capture | No committed diagnostic of a gate-entry `mkdir` failure exists; use receipt field discipline and tracked evidence-ledger conventions only if a new artifact is authorized. |

## Metadata

**Analog search scope:** `scripts/maintainers/`, `.planning/phases/237-*`, `.planning/phases/238-*`, `.planning/phases/243-*`, `.planning/phases/244-*`, `.planning/phases/245-*`, `.planning/STATE.md`  
**Tracked analogs scanned:** 6 (including coordinator source and fixture test); the Plan 245-28 recovery receipt and Phase 243 PR evidence are untracked and cited only as observed context, not tracked copyable analogs.  
**Pattern extraction date:** 2026-10-02
