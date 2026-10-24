## Summary

Draft evidence snapshot for the user-approved Phase 254 fixed-source rerun experiment. **Do not merge.** This branch preserves the tested candidate tree; its parent is current main so GitHub can produce a verifiable PR checkout without resolving unrelated changes into the candidate.

```text
fixed PR source → full CI attempt → retain raw artifacts → next registered attempt
```

Preparation allows one original-baseline rerun and this initial candidate CI run, with no trigger retries and a shared 60-minute/600-request limit. The 20-pair/40-invocation comparison remains unopened until source, attempt timing, native workload, caches and runner images are proven compatible. This experiment measures fixed-source reruns, not new-PR scheduling performance.

## Evidence

- **Before:** The original baseline PR cannot be recreated with its original merge tree against newer main.
  **After:** Approved use of the original workflow run and separately registered attempt numbers; raw origin, source, native reports and attempt-only costs are checked independently.
- Local verification: 48 legacy collector checks, 23 security tests, 154 hosted-origin tests, 1 replay test and 5 attempt integration tests passed. The immutable baseline archive verifies with no diagnostics.
- Candidate tree: `d0c0d243839c1c8e7120d0dc916b89deac80d24b`; tested local source: `38d83b252a55c1dd0bd8cde610ad9db19c46d723`. No hosted speedup or completed phase verification is claimed.

## Merge Danger

**Door:** two-way

Close this draft after evidence collection. It intentionally carries the complete tested snapshot, including differences from newer main that are outside this optimization; it is not a production integration branch.

**Blast Radius:** CI

Creating this PR starts the one approved candidate preparation invocation. Main and required branch rules remain unchanged.
