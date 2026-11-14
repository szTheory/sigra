# Phase 250: Close v1.49 audit gaps - Pattern Map

**Mapped:** 2026-10-10  
**Files analyzed:** 4 implementation areas (exact filenames remain plan decisions)  
**Analogs found:** 5 strong repository analogs

## File Classification

| New/Modified File or artifact group | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| Phase 247 candidate reconciliation evidence and readiness verifier/tests | utility / test / evidence | batch transform, immutable evidence validation | `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` and `.planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs` | role-match |
| Canary source, on-demand controller, narrowly allowlisted observer workflow(s) | workflow / controller / observer | event-driven, request-response, artifact I/O | `.github/workflows/release-please.yml`, `.github/workflows/release-run-observer.yml`, `scripts/ci/release-observer.sh` | role-match |
| Canary receipt/artifact validators and negative/fixture tests | utility / test | transform, event-driven, file I/O | `scripts/ci/release-receipt.sh`, `scripts/ci/release-observer.test.sh`, `test/sigra/planning/phase_248_release_observer_contract_test.exs` | exact/role-match |
| Refreshed Phase 247/248/249 verification snapshots, summaries, requirement rows, hosted canary proof, final audit | evidence / configuration | batch transform, traceability | `.planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs` and `validate-closeout.test.mjs` | role-match |

The context/research deliberately leave exact file names to planning for some new canary pieces. Keep the groups above separated by their trust/data-flow role when assigning files to plans. UI, Phoenix, Ecto, and brandbook patterns do not apply.

## Pattern Assignments

### Phase 247 candidate/readiness evidence (utility, test, evidence; batch validation)

**Analogs:** `validate-release-readiness.mjs` (lines 43-113) and `validate-closeout.mjs` (lines 908-963).

The Phase 247 validator is the closest same-phase ledger pattern: it validates required arrays and full SHAs, unique/sorted identities, explicit dispositions, then compares recorded tuples with independently observed evidence and returns structured errors (see `validate-release-readiness.mjs:43-113`). The Phase 249 closeout validator shows how to combine independent evidence validators without flattening their errors or blockers (`validate-closeout.mjs:908-963`).

**Pattern excerpt** (`validate-release-readiness.mjs:92-113`):

```js
const entry = snapshot?.source ?? {};
if (entry.trusted_main_sha !== observed?.trusted_main_sha) add('trusted_main_identity_mismatch', ...);
if (!sameSet(commitShas, observed?.commit_shas ?? [])) add('inherited_commit_population_mismatch', ...);
// Validate the complete identity population; a mismatch is an error.
return { valid: errors.length === 0, errors };
```

**Apply:** reconcile candidate SHA, readiness ledger, approval disposition, exact-head CI, dry-run receipt, and source commit/blob identity as one tuple before producing READY-01/02 evidence. Use structured blockers/errors. A proposal's later SHA or a newer-looking markdown line does not itself approve/rebind a candidate. If immutable approval and tuple linkage cannot be proven, retain an unsatisfied/blocked result. Phase 247 plan-05 work is superseded only for acceptance criteria covered by later exact-source evidence.

### Hosted canary workflows and observer (workflow/controller/observer; event-driven and artifact I/O)

**Analogs:** `.github/workflows/release-please.yml:577-674`, `.github/workflows/release-run-observer.yml:1-42`, and `scripts/ci/release-observer.sh:28-73`.

The production terminal job demonstrates `always()` receipt construction and a unique run-bound upload (`release-please.yml:577-674`). The observer workflow is default-branch trusted code with explicit read-only job permissions, checkout pinned to `main`, and a run-specific artifact name (`release-run-observer.yml:9-42`). The shell observer treats the event as a locator, re-queries the authoritative run/workflow, and checks repo, run ID, SHA, event, branch, conclusion, workflow ID/name/path, and attempt before writing a receipt (`release-observer.sh:28-73`).

**Observer identity excerpt** (`release-observer.sh:57-67`):

```bash
[[ "$API_REPOSITORY" == "$GITHUB_REPOSITORY" ]] || fail "authoritative source repository mismatch"
[[ "$API_RUN_ID" == "$EVENT_RUN_ID" ]] || fail "authoritative source run ID mismatch"
[[ "$API_SHA" == "$EVENT_SHA" ]] || fail "authoritative source SHA mismatch"
[[ "$API_BRANCH" == main ]] || fail "source run did not target main"
[[ "$API_CONCLUSION" == cancelled ]] || fail "source run was not cancelled"
[[ "$API_WORKFLOW_PATH" =~ ^\.github/workflows/release-please\.yml(@main)?$ && "$WORKFLOW_PATH" == .github/workflows/release-please.yml ]] || fail "source workflow path mismatch"
[[ "$API_WORKFLOW_ID" == "$WORKFLOW_ID" ]] || fail "source workflow ID mismatch"
```

**Apply:** controller dispatch must retain the returned exact source run IDs, cancel only its own verified canary run ID after the explicit wait stage, and retrieve artifacts by exact run ID/name. Observer must use trusted default-branch code and authoritative API re-query. A canary-specific allowlist/envelope must be narrowly separate; preserve the production Release Please identity filter as-is. Do not checkout or execute source artifacts, use a production concurrency group, use latest-run lookup, force-cancel, or permit release/tag/PR/publish actions. Canaries have no Hex credential or publishing environment.

### Sanitized receipt contract and fixtures (utility/test; JSON transform and file I/O)

**Analogs:** `scripts/ci/release-receipt.sh:24-99,117-157`, `scripts/ci/release-receipt.test.sh`, and `scripts/ci/release-observer.test.sh`.

The shared builder validates object/schema shape, credential-like key absence, source/run identity, timestamps, finite verdict/stage combinations, and cross-field consistency before atomically persisting a projection (`release-receipt.sh:24-99,117-157`). Existing shell fixtures construct run/API responses and assert rejection for identity mismatches; extend in that style rather than testing only a happy-path JSON sample.

**Sanitization excerpt** (`release-receipt.sh:26-36`):

```bash
# Diagnostic text is deliberately an enum-like code rather than arbitrary logs.
def safe_diag: type == "string" and test("^[a-z][a-z0-9_]{1,63}$");
def no_credential_keys:
  [.. | objects | keys[]? | select(test("(token|secret|credential|api.?key)"; "i"))] | length == 0;
```

**Apply:** reuse the sanitized builder/validator contract for both hosted outcomes. Canary markers and artifact names must be unmistakable, unique by run/attempt, and rejected by the production receipt identity path. Test malformed/missing fields, wrong workflow/ref/event/SHA/run attempt, cross-run artifact retrieval, credential-like keys, unauthorized cancellation targets, and production rejection of canary receipts. Keep local fixtures as local-contract proof; only retrieved hosted artifacts prove event delivery/retention/retrieval. Exclude credential values and raw logs from evidence.

### Verification refresh, requirement traceability, and accepted-loss handling (evidence/tests; batch reconciliation)

**Analog:** `.planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs:39-51,908-963` and `validate-closeout.test.mjs:83-129,321-350`.

Phase 249 pins its accepted-loss exception to exact path/status/hash/source-head, user authorization, and an audit record (`validate-closeout.mjs:39-51`); its test verifies both the exact accepted record and fail-closed behavior if identity or authorization changes (`validate-closeout.test.mjs:321-350`). Its final acceptance validator aggregates main proof, public identity, inventory, preservation, and dispositions and retains blocked state and accepted losses in output (`validate-closeout.mjs:908-963`).

**Apply:** refreshed verification snapshots record capture time and exact source/evidence refs, commits, workflow runs/attempts, artifacts, and outcomes evaluated. Preserve stale report history when useful, never transplant a later artifact into an older evidence identity, and leave unresolved proof blocked. Refresh each owner phase first; only then synchronize that owner's summary requirement frontmatter and `REQUIREMENTS.md`. Preserve ownership: READY-01/02 remain Phase 247, AUTO-01/02 Phase 248, REL-01/02 Phase 249. The final strict milestone audit runs last and must reconcile all three passing owner reports, requirement rows, summaries, and zero orphan/contradiction results before claiming 9/9.

The Phase 249 evidence establishes two further invariants: package-source SHA and final protected-main SHA are separate identities; the historical `.planning/HANDOFF.json` loss is `accepted-loss`, not recovered or preserved bytes. Keep both distinctions in Phase 249's refreshed record.

## Shared Patterns

### Exact identity and fail-closed evidence
**Sources:** `scripts/ci/release-observer.sh:28-73`; `validate-release-readiness.mjs:43-113`; `validate-closeout.mjs:908-963`.

Use full commit SHAs, exact workflow/run IDs and attempts, event/ref, immutable refs/artifact identity, timestamps, and explicit dispositions. A missing or mismatched input is a structured blocker; do not infer a pass from recency or a version/tag string.

### Least privilege and untrusted artifact boundary
**Sources:** `.github/workflows/release-run-observer.yml:9-42`; `test/sigra/planning/phase_248_release_observer_contract_test.exs:17-39`.

Use job-scoped minimum Actions permissions, pinned actions, default-branch observer code, and no secrets in source workflows. Treat artifacts as JSON data, never executable input. Preserve the production observer's source identity filters.

### Machine-readable, secret-free proof
**Sources:** `scripts/ci/release-receipt.sh:26-36,126-155`; `validate-closeout.mjs:908-963`.

Persist only schema-validated projections and proof metadata; reject credential-shaped keys. Distinguish local fixture results from hosted proof. Use unique source/run/attempt-bound artifact identities and retrieve by exact run ID.

## No Analog Found

| File/artifact | Role | Data Flow | Reason |
|---|---|---|---|
| New canary workflow/controller filenames and hosted proof JSON | workflow/config/evidence | event-driven, artifact I/O | No existing hosted no-publish dual failure/cancellation canary exists. Reuse the production receipt and trusted observer contracts without broadening production source identity. |
| Canonical refreshed Phase 247/248/249 verification snapshots | evidence | batch snapshot | Existing reports are stale or incomplete; reuse exact-identity and blocker conventions, but there is no current Phase 250 snapshot analog. |

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/ci/`, `test/sigra/planning/`, and Phase 247-249 planning validators/evidence.  
**Files scanned:** 5 principal tracked code/test analogs plus existing phase evidence patterns.  
**Pattern extraction date:** 2026-10-10. All named implementation analogs are git-tracked; no ignored runtime mirror paths are referenced.
