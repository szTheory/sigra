# Phase 258: Re-anchor CISPEED proof under a fresh source scope — Pattern Map

**Mapped:** 2026-11-08  
**Files classified:** 35 planned, historical, or attempt-evidence paths  
**Tracked code analogs inspected:** 5

## Scope and Status

Plan 258-01 and Plan 258-02 are complete. Plan 258-03 is halted: its recovery08 claim was consumed after 15 GETs, with no branch update, workflow, runner use, or sample. The current summary points to a local repair in `_fresh_append_preparation_record` and a focused regression, followed by a fresh-scope check. The summary says that function used a generic `readiness_path`; the current worktree already contains an explicit Phase258 path branch at `scripts/ci/ci-repaired-comparison.py:19610-19616`. Treat that checked-in production implementation as the live reference and inspect the exact current source before any later repair.

The existing Phase258 context, plans, summaries, scope, recovery08 artifacts, and route records are historical inputs for this map. This document does not assign them as write targets. In particular, `258-03-PLAN.md` and `258-03-SUMMARY.md` are halted history and must remain byte-identical. Any later attempt needs its own approved source-bound scope and distinct output namespace.

## File Classification

| New/Modified or Attempt-Context File(s) | Role | Data Flow | Closest Tracked Analog | Status / Match |
|---|---|---|---|---|
| `scripts/ci/ci-repaired-comparison.py` | controller / service | file-I/O, request-response, batch | same file, Phase258 paths and record writer | exact role and flow |
| `scripts/ci/ci-repaired-comparison.test.py` | test | file-I/O, transform | same file, Phase258 temporary-directory and zero-write tests | exact |
| `scripts/ci/ci_metrics_security.py` | utility / validator | transform, batch | same file, `validate_phase257_preparation_policy` | role-match |
| `scripts/ci/ci_repaired_driver.py` | controller / process runner | event-driven, file-I/O | same file, `_complete` and Phase258 claim/preparation gates | exact |
| `scripts/ci/ci-repaired-driver.test.py` | test | event-driven, file-I/O | same file, zero-transport and preparation-gate tests | exact |
| `.planning/phases/258-re-anchor-cispeed-proof-under-fresh-source-scope/258-SCOPE.md`; `.planning/phases/258-re-anchor-cispeed-proof-under-fresh-source-scope/258-03-PLAN.md` | planning artifact | transform | none; phase planning files are not tracked source analogs | listed by halted plan, frozen/read-only |
| `.planning/execution/258/SOURCE-REFREEZE.json`; `.planning/execution/258/generations/phase258-recovery-08/SOURCE-REFREEZE.json` | source receipt / model | file-I/O, batch | `scripts/ci/ci-repaired-comparison.py`, Phase258 source-proof and canonical-digest helpers | role-match; receipts are terminal inputs/outputs |
| `.planning/execution/258/BUDGET-RECONCILIATION.json`; `.planning/execution/258/generations/phase258-recovery-08/BUDGET-RECONCILIATION.json` | spend ledger / model | batch, transform | `scripts/ci/ci-repaired-comparison.py`, predecessor and budget validators | role-match; preserve unknown workload as unknown |
| `.planning/execution/258/PREP-CONTRACT.json`; `.planning/execution/258/generations/phase258-recovery-08/PREP-CONTRACT.json` | config / contract | transform | `scripts/ci/ci_metrics_security.py`, phase policy validators | role-match |
| `.planning/execution/258/PREP-PROPOSAL.json`; `.planning/execution/258/generations/phase258-recovery-08/PREP-PROPOSAL.json` | proposal model | request-response, file-I/O | `scripts/ci/ci-repaired-comparison.py`, `phase258_propose` / `phase258_verify_local` | exact data flow; existing proposal remains frozen |
| `.planning/recovery/opengsd-health-20261106/phase258-local-validation-04/LOCAL-CHECKS.json`; `.planning/recovery/opengsd-health-20261106/phase258-proposal-final-01/LOCAL-PROPOSAL-VERIFICATION.json`; `.planning/recovery/opengsd-health-20261106/phase258-act-preflight-02/ACT-LOCAL-SUPPLEMENT.json` | verification receipts | batch, transform | `scripts/ci/ci-repaired-comparison.py`, independent local verification result patterns | role-match; preserve existing evidence |
| `.planning/execution/258/generations/phase258-recovery-08/PREP-APPROVAL.json` | approval record / model | request-response | `scripts/ci/ci-repaired-comparison.py`, `_phase258_validate_approval_record` | role-match; approval must bind exact proposal bytes |
| `.planning/execution/258/generations/phase258-recovery-08/PREP-AUTHORIZATION.json` | authorization record / model | request-response, file-I/O | `scripts/ci/ci-repaired-comparison.py`, `phase258_authorize` | role-match; do not write into consumed generation |
| `.planning/execution/258/generations/phase258-recovery-08/PREPARE-INVOCATION-CLAIM.json` | one-use claim / model | event-driven, file-I/O | `scripts/ci/ci-repaired-comparison.py`, `_phase258_consume_invocation_claim` | role-match; consumed claim is immutable |
| `.planning/execution/258/generations/phase258-recovery-08/PREP-LEDGER.json`; `.planning/execution/258/generations/phase258-recovery-08/COLLECTION-LEDGER.json` | append-only ledgers / models | event-driven, request-response | `scripts/ci/ci-repaired-comparison.py` and `scripts/ci/ci_repaired_driver.py` | exact flow; recovery08 ledger is terminal |
| `.planning/execution/258/generations/phase258-recovery-08/preparation/OUTER-PROCESS.json`; `.planning/execution/258/generations/phase258-recovery-08/preparation/EXECUTION.json` | process receipts / models | event-driven, file-I/O | `scripts/ci/ci-repaired-comparison.py`, `phase258_run_preparation`; `scripts/ci/ci_repaired_driver.py`, `_run_process_group` | exact |
| `.planning/execution/258/generations/phase258-recovery-08/PREP-VERIFY.json`; `.planning/execution/258/generations/phase258-recovery-08/VERIFICATION.json` | independent verification models | transform, batch | `scripts/ci/ci-repaired-comparison.py`, `phase258_verify_prepared` / `phase258_verify_measurement` | exact |
| `.planning/execution/258/generations/phase258-recovery-08/MEASUREMENT-RESULT.json` | measurement result / model | batch, transform | `scripts/ci/ci-repaired-comparison.py` and `scripts/ci/ci_repaired_driver.py`, measurement collection path | role-match |
| `.planning/execution/258/generations/phase258-recovery-08/write-ahead-preservation/phase258-gen07-before-reopen-01/PRESERVATION.json`; `.planning/execution/258/generations/phase258-recovery-08/write-ahead-preservation/post-run-route-refresh-01/PRESERVATION.json` | preservation receipts | file-I/O, batch | `scripts/ci/ci-repaired-comparison.py`, immutable JSON and digest helpers | role-match; preservation evidence is read-only |
| `.planning/recovery/opengsd-health-20261106/phase258-preparation-attempt-06-reconciliation/PREPARATION-ATTEMPT-06-RECONCILIATION.json`; `.planning/recovery/opengsd-health-20261106/phase258-preparation-attempt-07-reconciliation/PREPARATION-ATTEMPT-07-RECONCILIATION.json`; `.planning/recovery/opengsd-health-20261106/phase258-preparation-attempt-08-reconciliation/PREPARATION-ATTEMPT-08-RECONCILIATION.json` | attempt reconciliation / model | batch, transform | `scripts/ci/ci-repaired-comparison.py`, predecessor and latest-attempt reconciliation readers | role-match; all predecessor accounting remains charged |
| `.planning/execution/258/generations/phase258-recovery-07/PREP-LEDGER.json`; `.planning/execution/258/generations/phase258-recovery-07/preparation/OUTER-PROCESS.json` | predecessor attempt receipts | event-driven, request-response | `scripts/ci/ci-repaired-comparison.py`, phase verification readers | role-match; read-only historical inputs |

`258-03-SUMMARY.md`, the other existing Phase 258 summaries and context, and the active route files are protected history/state, not targets for this pattern assignment.

## Pattern Assignments

### `scripts/ci/ci-repaired-comparison.py` (controller/service, file-I/O and request-response)

**Analog:** the current module itself is tracked source and contains the Phase258-specific patterns. Its imports establish the local module convention and shared validator boundary (lines 10-38):

```python
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/ci'))
from ci_metrics_security import (
    FINITE_STAGE_LIMITS, finite_comparison_schedule,
    derive_comparison_family_costs, validate_repaired_control_metadata,
    comparison_contract_sha256, validate_comparison_schedule,
)
```

Phase-specific paths are resolved through an exact path-map check (lines 4203-4218). Keep this boundary when adding or fixing a Phase258 artifact lookup; do not fall back to a generic `readiness_path` when Phase258 uses `phase258_paths`:

```python
def _phase258_paths(policy):
    paths = (policy or {}).get('phase258_paths')
    if paths != PHASE258_PATHS:
        raise ValueError('phase258_policy_paths_missing_or_changed')
    return paths

def _phase258_read_bound(relative, expected_sha256, label):
    source = _fresh_local_path(relative, label='phase258_' + label)
    if (not re.fullmatch(r'[0-9a-f]{64}', str(expected_sha256 or ''))
            or digest(source) != expected_sha256):
        raise ValueError('phase258_' + label + '_hash_changed')
    return source
```

`_fresh_append_preparation_record` already has the needed Phase258 case (lines 19610-19616): it selects the canonical verification output from the policy, checks its schema and source identity, then appends a canonical-digest-linked record (lines 19629-19677).

```python
elif _phase258_policy(contract) is not None:
    paths = _phase258_paths(policy)
    verification_path = _fresh_local_path(paths.get('verification_path'),
        label='phase258_verification', required=False)
```

The same function builds a record ID from the payload digest, links the previous record, and recomputes the containing receipt digest before an atomic replacement (lines 19629-19677):

```python
rows = _fresh_verify_record_chain(verification, contract)
stable_payload = copy.deepcopy(payload)
body = {'record_kind': kind, 'scope_sha256': policy['scope_sha256'],
    'contract_sha256': contract['contract_sha256'],
    'source_identity_sha256': canonical_digest(contract.get('orchestration_source_sha256') or {}),
    'payload': stable_payload, 'payload_sha256': canonical_digest(stable_payload),
    'status': status, 'previous_record_sha256': rows[-1]['record_sha256'] if rows else None}
record = {**body, 'record_id': record_id}
record['record_sha256'] = canonical_digest(record)
verification['records'].append(record)
atomic_write_json(verification_path, verification, replace=True)
```

**Authority and error pattern:** `phase258_authorize` validates the exact approval against the local proposal before writing authorization (starts at line 5974); `phase258_run_preparation` checks authorization and claim, creates the outer receipt, consumes the claim, stores `claim_after_sha256`, then catches and sanitizes child errors (starts at line 6123). Preserve this order and the 2,700-second limit. CLI commands are registered and dispatched explicitly in the Phase258 blocks at lines 30200-30213 and 30519-30544.

### `scripts/ci/ci_metrics_security.py` (utility/validator, transform and batch)

**Analog:** `validate_phase257_preparation_policy` is the closest tracked scope validator (lines 1627-1697). Copy its exact schema, field-set, path-map, limits, hash-format, and zero-authority validation style for any changed Phase258 policy. Return error identifiers rather than silently normalizing changed policy fields.

```python
def validate_phase257_preparation_policy(policy: dict) -> list[str]:
    if (not isinstance(policy, dict)
            or policy.get('schema_version') != 'sigra.phase257.preparation-policy/v1'
            or policy.get('scope_mode') != PHASE257_PREPARATION_SCOPE_MODE
            or policy.get('status') not in ('ready_for_consent', 'blocked')):
        return ['phase257_preparation_policy_schema_invalid']
    errors = []
    if policy.get('phase257_paths') != PHASE257_PATHS:
        errors.append('phase257_preparation_policy_paths_invalid')
    if policy.get('limits') != PHASE257_LIMITS:
        errors.append('phase257_preparation_policy_limits_invalid')
    if (policy.get('acceptance_samples') != 0 or policy.get('window_renewals') != 0
            or policy.get('authority') != {'readiness': False, 'full_preparation': False,
                'cache_write': False, 'measurement': False, 'window_renewal': False}):
        errors.append('phase257_preparation_policy_authority_invalid')
```

### `scripts/ci/ci_repaired_driver.py` (controller/process runner, event-driven)

**Analog:** `_phase258_require_claim` and `_phase258_require_preparation_passed` (lines 520-582) establish the pre-I/O gate; `_complete` rechecks it before cache work, authorization, or transport (lines 1600-1645).

```python
def _phase258_require_claim(module, contract, stage, invocation_id, *, thorough=False):
    if (_phase258_policy(module, contract) is None
            or stage not in ('prep-readiness', STAGES[0], STAGES[1])):
        return
    require = getattr(module, '_phase258_require_invocation_claim', None)
    if not callable(require):
        raise ValueError('phase258_driver_invocation_claim_checker_missing')
    if stage == STAGES[1]:
        require(contract, stage, invocation_id, thorough=thorough)
    else:
        require(contract, stage, invocation_id)
```

The comparison stage checks the canonical `PREP-VERIFY.json`, its hash, and all three independent pass statuses before collection. Keep this gate ahead of `_verify_shared_cache_merges`, `authorization_record`, and `AcquisitionTransport`.

### Tests: zero-I/O ordering and receipt bindings

**Analog:** `scripts/ci/ci-repaired-comparison.test.py:5569-5648` tests the claim digest in the launching receipt and rejects absent or altered digests. `:5912-5928` uses a supplied clock in the readiness verifier. `scripts/ci/ci-repaired-driver.test.py:794-827` asserts a missing Phase258 claim stops before cache, authorization, controller, or transport calls.

```python
self.assertEqual(module.digest(claim_path), outer.get('claim_after_sha256'))
for bad_digest in (None, '0' * 64):
    tampered = {**outer, 'claim_after_sha256': bad_digest}
    with self.assertRaisesRegex(ValueError, 'phase258_wrapper_handoff_binding_invalid'):
        module._phase258_require_wrapper_handoff(contract,
            paths['proposal_path'], paths['authorization_path'],
            str(root / module.PHASE258_GENERATION_ROOT
                / 'preparation/EXECUTION.json'))
```

The driver test uses a transport that raises if called and confirms the controller was never created:

```python
with self.assertRaisesRegex(ValueError, 'phase258_invocation_claim_required_before_io'):
    driver._controller_get(comparison, contract, root / 'ledger.json',
        'prep-full-workload', family, NeverTransport(),
        comparison.API_BASE + '/rate_limit', '2026-11-06T14:00:00Z')
controller.assert_not_called()
```

Use temporary directories, patched clocks and mocked child/transport boundaries. Assert the intended rejection happens before any ledger write or external call. Do not substitute tests for the fixed 20-pair/40-family production verification.

## Shared Patterns

### Canonical Phase258 paths and contained reads

**Source:** `scripts/ci/ci-repaired-comparison.py:4203-4218`  
**Apply to:** all proposal, verification, authorization, claim, ledger, and result files. Use `_phase258_paths(policy)` and `_fresh_local_path`; bind expected file bytes with SHA-256 and reject symlinks or path changes before reading.

### Hash-linked append-only evidence

**Source:** `scripts/ci/ci-repaired-comparison.py:19629-19677`  
**Apply to:** preparation verification, execution status, and reconciliation rows. Compute the payload digest and record ID, chain the previous record digest, and recompute the enclosing verification digest before atomic replacement.

### Claim before I/O; independent pass before measurement

**Source:** `scripts/ci/ci_repaired_driver.py:520-582,1600-1645`  
**Apply to:** preparation collection and all measurement paths. Validate the exact Phase258 claim before transport; require canonical `PREP-VERIFY.json` with passed record, verification, and execution statuses before measurement.

### Stable local regression pattern

**Source:** `scripts/ci/ci-repaired-driver.test.py:794-827`; `scripts/ci/ci-repaired-comparison.test.py:5569-5648`  
**Apply to:** fixes around wrapper handoff, path selection, clocks, and fail-closed guards. Use temporary files and mocks, then assert no transport/child call or output write on invalid input.

## No Tracked Analog Found

There is no close tracked source analog for writing Phase-scoped planning documents such as `258-SCOPE.md` or `258-03-PLAN.md`. These files are already present and explicitly frozen by the task, so no edit is assigned. For machine-readable receipt files, use the tracked production writers and validators above; the `.planning/execution/` and `.planning/recovery/` receipts themselves are not used as analog source paths.

## Metadata

**Analog search scope:** `scripts/ci/` production controllers, validators, and regression tests; Phase 258 plan and attempt summaries.  
**Tracked analog gate:** all five named code analogs were confirmed by `git ls-files`.  
**Pattern extraction date:** 2026-11-08
