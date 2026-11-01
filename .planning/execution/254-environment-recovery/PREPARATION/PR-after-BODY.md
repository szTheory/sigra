## Summary

Draft fixed-source Phase254 after snapshot. **Do not merge.** The same verified package transport and runner identity repair is applied to both comparison conditions.

```text
exact locked browser packages → bounded signed HTTPS download → no-download installation → unchanged browser tests
```

## Evidence

- **Before:** baseline run40035528418 lost two jobs to30-minute package download limits; prior image header/environment values conflicted.
  **After:** isolated hosted probe40041742541 passed; all download paths agreed and native image/environment agreed. A disposable amd64 Ubuntu24.04 container downloaded210MB in42s and installed the complete locked Chromium/WebKit package set in47s, with no retry. These are diagnostics, not measured speedup samples.
-10 package installer tests,6 runner identity tests,11 collector protocol tests,30 preparation/workflow checks and6 live workflow assertions passed. Source trees under the complete Playwright directory remain unchanged.
-This initial real-PR invocation spends one of two separately bounded recovery verification runs authorized by the user's unblocking instruction;0 trigger retries,60minutes/600totalHTTPrequests shared. Prior four preparation outcomes and budgets remain intact. No measured sample or48-hour window has started.
-Exact application SHA: `c074333db2658cb0726a9ee23535e4c43a9f8c64`; tree:`f29a2e812352d4d8bc1b2bd3d162799f2f02b9ff`; current base:`09df342a82e03c3d5d40173c912b70e827f7eadc`. This is a snapshot of a comparison condition, not a production integration branch.

## Merge Danger

**Door:** two-way

Do not merge or update this draft during collection.

**Blast Radius:** CI

Main, branch protection, required check names, browser cases and acceptance thresholds remain unchanged.
