# Observed-run evidence ledger (KNOWN-BAD Phase 236 fixture)

This fixture reaches every substantive p12 check before demonstrating that a captured claim
without a Status run ID is not evidence.

## BEFORE-FLAKE-RED

Status: captured (run 35004420339)

The known RED receipt is retained for run 35004420339.

```bash
gh run view 35004420339 --repo szTheory/sigra --json jobs
```

Run 35004420339 contains the observed failed assertion.

## AFTER-P17-GUARD-OBSERVED

Status: captured (run 35034938082)

The Fast checks receipt passed for run 35034938082.

```bash
gh run view 35034938082 --repo szTheory/sigra --json jobs
```

Run 35034938082 includes the Fast checks job with conclusion success.

## AFTER-FIX-GREEN

Status: captured

The five-run GREEN claim deliberately omits its Status run ID.

```bash
gh run view 35034938082 --repo szTheory/sigra --json jobs
```

Run 35034938082 must not make a bare captured Status valid.
