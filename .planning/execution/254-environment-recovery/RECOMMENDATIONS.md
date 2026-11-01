# Phase 254 recovery decisions

Three independent reviews covered package transport, browser/runtime compatibility, comparison validity, security, operational cost and repeat-failure risks. The shared recommendation is a small symmetric transport repair after one isolated diagnostic, with no new dependency. Keep the original acceptance thresholds and every historical outcome.

| Decision | Selected approach | Rejected alternatives and reason |
| --- | --- | --- |
| Diagnose before full CI | One bounded libflite1 transfer probe: current APT, no-cap APT, configured endpoint, official HTTPS archive | Re-running unchanged or extending the 30-minute job limit does not address steady 50 KB/s downloads |
| Package installation | Use exact locked Playwright package list; authenticated official Ubuntu HTTPS sources; bound update/download acquisition before dpkg; at most one fresh-connection acquisition retry | Browser cache does not contain system packages; skipping them loses real WebKit prerequisites. Killing dpkg and blindly retrying risks partial installation |
| Dependencies | Python/Node standard libraries and existing APT/curl/timeout only | New cache action, third-party mirror service or dependency framework adds unnecessary surface |
| Runner identity | Capture native imagedata and environment before setup, verify again at metadata publication, reject disagreement | Existing native headers and uploaded env metadata conflict; neither may be chosen because it allows comparison |
| Comparison | Preserve 20 pairs, 40 measured invocations, all-warm checks, balanced order, 48-hour window, median/p95/total-runner thresholds and all108 case identities | Fewer pairs, weaker thresholds, favorable replacements and uncounted retries do not establish the promised behavior |
| Fallback | Consider a common digest-pinned Playwright1.59.1 environment only if the smaller transport and identity checks cannot establish feasibility | Immediate container migration changes PostgreSQL networking, BEAM setup, cache identity and image-pull cost; avoid until necessary |

The failed jobs fetched indexes at about10 MB/s, then archive packages at roughly45–52 KB/s. A cap or selected mirror path is a hypothesis, not a proven cause. GitHub's runner-image issue describes similar package/index rate differences and slow backends. APT's inactivity timer does not bound transfers that keep making slow progress.

Primary sources consulted:

- [APT HTTP transport: download rate limits, timeouts and independent repository authentication](https://manpages.debian.org/bookworm/apt/apt-transport-http.1.en.html)
- [GitHub runner-image mirror issue and same-job package/index evidence](https://github.com/actions/runner-images/issues/14594)
- [GitHub runner-image update fix: inactivity versus slow-progress downloads](https://github.com/actions/runner-images/pull/14643)
- [Official runner image data format](https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/scripts/build/configure-image-data.sh)
- [GitHub image updates and deployment process](https://github.com/actions/runner-images#image-releases)
- [Playwright browser cache guidance](https://playwright.dev/docs/ci#caching-browsers)
- [Playwright Docker environment and exact-version coupling](https://playwright.dev/docs/docker)
- [GitHub branch-filtered workflow triggers](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)

The current user request authorizes the recovery work and delegated approach choices. It does not erase either closed preparation allowance or spend a measured slot. No new numbered plan is needed for package transport, metadata or local development fixes.
