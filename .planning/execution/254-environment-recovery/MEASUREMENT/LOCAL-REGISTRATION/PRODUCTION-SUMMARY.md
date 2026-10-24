# Verified production client backport

The exact tracked client bundle (`3b7730aec7be5ff88c3c69d534abda86e762a5fa43ac0ed34272509f40351ca2`) was copied onto the isolated archived baseline app. The copied file and HTTP-served bytes matched the tracked SHA256 before and after the browser checks. Other application files came from baseline source `fb2d3faa4b25918d14415dd00a51545f0a9c6683`; this was a local diagnostic overlay, not an unchanged baseline execution.

The production bundle passed the same forced missing-primary-reply condition in WebKit (connected LongPoll within 4.032 seconds) and Chromium (3.819 seconds). Five ordinary mobile WebKit navigations also passed. The readiness timeout remained 15 seconds. `PRODUCTION-VERIFICATION.json` and the `PRODUCTION-*` reports/traces retain those results; `PRODUCTION-BINDING.json` records the exact source/served bytes.

The earlier broken baseline and incomplete callback-guard results remain saved. No hosted acceptance result, comparison allowance, frozen PR source or browser assertion was changed by these checks. This macOS development reproduction does not establish Linux acceptance or prove the original hosted initiating delay; it proves the downstream fallback failure and repair under the controlled condition.

Cleanup is complete: only the owned server on port4317 and temporary PostgreSQL container on port64317 were stopped. The isolated archive and reports remain for inspection. See `CLEANUP.json`.
