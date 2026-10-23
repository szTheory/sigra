"""Join actual operator receipts to evidence before the canary's independent check.

Pure function: never changes a ledger, budget, stopped attempt or verifier.
"""
import copy


def merge_operator_receipts(evidence, ledger, receipts):
    transactions = ledger.get('transactions', [])
    by_sequence = {tx['sequence']: tx for tx in transactions}
    if len(by_sequence) != len(transactions):
        raise ValueError('duplicate ledger sequence')
    combined = {}
    for receipt in [*evidence.get('transport_receipts', []), *receipts]:
        seq = receipt.get('sequence')
        tx = by_sequence.get(seq)
        if tx is None:
            raise ValueError('receipt has no measured transaction')
        if (receipt.get('schema_version') != 'sigra.phase253.http-receipt/v1'
                or receipt.get('allocation_sha256') != ledger.get('allocation_sha256')):
            raise ValueError('receipt allocation or schema mismatch')
        # Every field actually retained by transport must equal its ledger value.
        for key, value in receipt.items():
            if key in tx and value != tx[key]:
                raise ValueError('receipt differs from measured transaction: ' + key)
        for key in ('sequence', 'window_id', 'source_sha256', 'method', 'url', 'actual_status',
                    'response_sha256', 'response_body_base64'):
            if key not in receipt or receipt[key] != tx.get(key):
                raise ValueError('receipt identity or response missing: ' + key)
        if seq in combined and combined[seq] != receipt:
            raise ValueError('conflicting receipts for one sequence')
        combined[seq] = receipt
    if set(combined) != set(by_sequence):
        raise ValueError('retained response receipts are incomplete')
    result = copy.deepcopy(evidence)
    result['transport_receipts'] = [combined[seq] for seq in sorted(combined)]
    return result
