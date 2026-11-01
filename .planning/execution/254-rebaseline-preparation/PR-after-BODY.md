## Summary

Draft corrected candidate for the explicitly approved Phase 254 comparison amendment. **Do not merge.** The tree is exactly reviewed local source dd4e3b437, including the corrected combined-Mix assertion and change detector.

```text
fixed source → initial preparation CI → verified raw capture → separately registered reruns
```

This is a measurement snapshot parented to main, not a production integration branch. It may contain older source differences from main. The original baseline archive, failed baseline attempt2 and failed candidate PR345 remain unchanged.

## Evidence

- **Before:** The original baseline rerun failed its shallow-history comparison and ECR PostgreSQL pull; the prior candidate failed one stale workflow assertion.
  **After:** The approved baseline patch and corrected candidate have each passed6 scoped workflow tests locally. Six attempt/preparation tests passed, including once-only role binding and complete native artifact capture.
- Exact application SHA: `fb0fd9b3292dc0274b08ee03a1d9b2207546f63e`. Exact tree: `e9d39623b5f574f17413839d56aad90a20738ab1`. Base main: `09df342a82e03c3d5d40173c912b70e827f7eadc`.
- This initial CI invocation spends one of the separately approved two preparation runs. No trigger retries. Both runs share60 minutes/600 HTTP requests. No measured sample or48-hour window has started; no hosted speedup is claimed.
- Any later result must identify the explicitly amended baseline and the rerun method adopted after implementation; it does not establish new-PR scheduling performance.

## Merge Danger

**Door:** two-way

Keep this draft unchanged during evidence collection; do not merge it.

**Blast Radius:** CI

Main, required check names and branch protection remain unchanged.
