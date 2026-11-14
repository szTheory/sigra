# Phase 257: Fix candidate source publication and complete the bounded CI speed proof - Pattern Map

**Mapped:** 2026-11-05  
**Files analyzed:** 3 likely code/test targets; additive evidence output path remains to be selected  
**Analogs found:** 3 / 3 tracked code/test targets

This map follows the recovery update in `257-CONTEXT.md`. The earlier research describes the publication path, but this additive plan is local-only: it must independently account for generation01 and identify exact candidate bytes before any fresh claim or hosted action.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/ci-repaired-comparison.py` | utility | transform | `scripts/ci/ci-repaired-comparison.py` (`_fresh_single_readonly_get_stop_receipt`, `_phase256_verify_source_check`) | exact |
| `scripts/ci/ci-repaired-comparison.test.py` | test | transform | `scripts/ci/ci-repaired-comparison.test.py` (`Phase257ContinuationTests`, `Phase256ScopeTests`) | exact |
| `scripts/ci/ci_metrics_security.py` | utility | transform | `scripts/ci/ci_metrics_security.py` (`validate_phase257_preparation_policy`) | role-match; use only if the recovery adds a distinct source-identity policy |
| New append-only local recovery evidence | utility | transform | `scripts/ci/ci-repaired-comparison.py` receipt readers and `scripts/ci/ci-repaired-comparison.test.py` fixtures | partial; output path/schema are not locked by current CONTEXT |

The first two files are the narrow production/test pair implied by the existing continuation tests. Add `ci_metrics_security.py` only if the plan needs a new policy schema; its current Phase257 validator intentionally pins the old candidate SHA/tree/base. The recovery output path is not specified in the updated CONTEXT. Choose a new scoped path; the existing blocked `generations/02/PREDECESSOR-RECONCILIATION.json` is already present and must remain untouched as historical evidence.

## Pattern Assignments

### `scripts/ci/ci-repaired-comparison.py` (utility, transform)

**Analog:** same tracked module; use the predecessor receipt classifier and Phase256 source verifier as separate patterns. Keep the recovery command local and read-only.

**Imports pattern** (lines 12-39): use the module's existing stdlib stack (`hashlib`, `json`, `pathlib.Path`, `subprocess`) and its existing `ci_metrics_security` import. Do not add dependencies or a second controller.

**Terminal receipt binding pattern** (`_fresh_single_readonly_get_stop_receipt`, lines 18255-18291):

```python
summary_path = _fresh_local_path(predecessors['halted_phase_summary']['path'],
    label='single_get_halted_summary')
summary_text = summary_path.read_text(encoding='utf-8')
summary_parts = summary_text.split('---', 2)
if (len(summary_parts) != 3
        or not re.search(r'(?m)^status:\s*halted\s*$', summary_parts[1])
        or proposal.get('generation_id') not in summary_text):
    return None

verification = read_json(verification_path)
verification_rows = _fresh_verify_record_chain(verification, contract)
execution_rows = [row for row in verification_rows if row.get('record_kind') == 'execution']
prep_verification_rows = [row for row in verification_rows
    if row.get('record_kind') == 'preparation_verification']
if (len(execution_rows) != 1 or len(prep_verification_rows) != 1
        or verification.get('status') != 'blocked'
        or verification.get('acceptance_samples') != 0):
    return None
```

The rest of this reader checks exact process arguments, the request ledger chain, the one completed GET, and absence of mutation/workload boundaries before reporting zero workload. Reuse that evidence-by-evidence structure, not its Phase255.1 paths, schema, expected counts, or conclusion. For generation01, any missing boundary evidence must keep `workloads` as `null`.

**Source identity pattern** (`_phase256_verify_source_check`, lines 5913-5941):

```python
receipt = read_json(source_path)
body = {key: value for key, value in receipt.items() if key != 'receipt_sha256'}
roles = receipt.get('exact_sources') or {}
if (receipt.get('schema_version') != PHASE256_SOURCE_CHECK_SCHEMA
        or receipt.get('status') != 'passed'
        or receipt.get('contract_sha256') != contract.get('contract_sha256')
        or receipt.get('receipt_sha256') != canonical_digest(body)
        or set(roles) != {'candidate', 'control'}
        or any(not isinstance(roles.get(role), dict)
            or not re.fullmatch(r'[0-9a-f]{40}', str(roles[role].get('source_sha', '')))
            for role in ('candidate', 'control'))):
    raise ValueError('phase256_source_check_invalid')
```

Continue the verifier's pattern by reading the bound Git object store and recomputing commit/tree/blob identities. The captured GitHub JSON is an input fact, not a substitute for proving which local source bytes a candidate would contain.

**Proposal/path validation pattern** (`_phase257_verify_frozen_proposal`, lines 4012-4056): resolve inputs through `_fresh_local_path`, require exact canonical relative paths, recompute `contract_sha256` and `proposal_sha256`, and compare the full scope/limits instead of trusting producer status. Keep this branch separate from immutable generation01 records.

### `scripts/ci/ci-repaired-comparison.test.py` (test, transform)

**Analog:** same tracked test module; extend the existing `Phase257ContinuationTests` and source-readback regressions. Tests should use temporary fixtures/captured bytes and assert zero hosted transport.

**Existing continuation behavior** (lines 5828-5843):

```python
reconcile = getattr(module, 'phase257_reconcile_predecessor', None)
verify = getattr(module, 'phase257_verify_predecessor', None)
self.assertTrue(callable(reconcile))
self.assertTrue(callable(verify))
result = reconcile(proposal_path, diagnostic_path, output)
self.assertEqual('blocked', result['status'])
self.assertIsNone(result['spend']['generation01']['workloads'])
self.assertEqual(before, output.read_bytes())
```

The current tests define a fail-closed requirement but the named production readers are absent. Preserve the original receipt bytes and test the actual production reader against the saved generation01 records; do not turn the blocked verifier's `workloads: 0` into proof.

**Source mutation regression** (lines 3530-3553): `_phase256_verify_selected_repair_blobs` is exercised with modified Git blob bytes even after producer hashes are refreshed, and the verifier must reject them. Apply the same adversarial shape to candidate source identity: mutate bytes/commit/tree or a remote identity field, refresh the untrusted claimed digest, and require the independent verifier to reject it.

### `scripts/ci/ci_metrics_security.py` (utility, transform)

**Analog:** `validate_phase257_preparation_policy` (lines 1541-1593) requires the exact field set, fixed limits, source-binding mode, and hardcoded candidate publication identity.

```python
identity = policy.get('candidate_publication') or {}
expected_identity = {
    'remote_url': PHASE257_REMOTE_URL, 'remote_ref': PHASE257_REMOTE_REF,
    'expected_old_sha': PHASE257_EXPECTED_OLD_SHA, 'target_sha': PHASE257_TARGET_SHA,
    'target_tree_sha': PHASE257_TARGET_TREE_SHA, 'base_sha': PHASE257_BASE_SHA,
}
if identity != expected_identity:
    errors.append('phase257_preparation_policy_candidate_identity_invalid')
```

This is a useful strict-schema pattern. Do not loosen or rewrite the existing Phase257 validator to accept the current PR head implicitly. If a new candidate identity is established, bind it in a separate recovery record or explicitly versioned policy and validate its source commit, tree, parent/base, and file digest.

## Shared Patterns

### Independent receipt reconstruction

**Sources:** `scripts/ci/ci-repaired-comparison.py:18255-18451`, `scripts/ci/ci-repaired-comparison.py:5898-6035`  
**Apply to:** generation01 workload accounting and source identity.

- Resolve each input with the existing nonsymlink/root-contained path helper.
- Recompute file and canonical payload hashes from bytes.
- Join the halted summary, contract/proposal, claim, outer-process receipt, ledger, and child receipt chain by exact identities.
- Derive counts from actual request/mutation/dispatch records. Keep unproved workload/cost unknown rather than filling zero.
- Keep new recovery evidence append-only and in a new output namespace.

### Exact candidate source identity

**Sources:** `scripts/ci/ci-repaired-comparison.py:5898-6035`, `scripts/ci/ci_metrics_security.py:1541-1593`  
**Apply to:** any local candidate source proof.

- Bind repository/ref, source commit, tree, parent/base, and relevant file hashes together.
- Read source bytes from the contract-bound Git object store with the existing checked Git reader.
- Compare captured PR/run facts to the exact source identity; the live PR368 head currently differs from the generation01 target, so those facts alone cannot establish the target bytes.

### Local-only test boundary

**Source:** `scripts/ci/ci-repaired-comparison.test.py:3530-3553, 5816-5866`  
**Apply to:** all recovery tests.

Use temporary directories and patched/captured local reads. Assert no network call, mutation, claim creation, output-root creation on blocked proof, and no byte changes to halted records.

## No Analog Found

| File or behavior | Reason |
|------------------|--------|
| Phase257-specific production reconciliation of the consumed generation01 invocation | The current tracked tests require `phase257_reconcile_predecessor` and `phase257_verify_predecessor`, but these production functions are absent. The Phase255.1 `_fresh_single_readonly_get_stop_receipt` is structural guidance only; its receipt schema and “zero workload” result do not transfer to Phase257. |
| Dynamic exact-source proof for a new candidate based on the current PR368 head | Existing Phase257 policy hardcodes the old SHA/tree/base; current remote facts say PR368 still points to the old head and its source-file hash differs from the contract-pinned hash. No tracked analog changes a frozen Phase257 identity safely. Use a distinct source-bound record and keep old scope artifacts immutable. |
| Additive recovery evidence output path/schema | The updated CONTEXT does not lock a path. The existing `generations/02/PREDECESSOR-RECONCILIATION.json` is blocked historical input and is already an untracked `.planning/` artifact; do not overwrite it or either halted plan summary. |

## Metadata

**Analog search scope:** Phase257 phase artifacts, `scripts/ci/` receipt/policy/source validators and tests.  
**Files scanned:** 6 tracked CI implementation/test candidates plus the current Phase257 plan and evidence set.  
**Pattern extraction date:** 2026-11-05
