# Phase 232 — API Coverage Declaration

No external API integration: the phase's only API surface is the GitHub Actions REST API read through
the already-adopted `gh` CLI (`gh run view --json jobs`, `gh pr checks`, `gh api …/rulesets/14941512`)
by committed in-repo instruments — CI tooling this repository already consumes, not a new third-party
integration. Everything else the phase touches is workflow YAML, a local composite action, Playwright
runner configuration, bash/node guards, and ExUnit contract tests.

Detector: `api-coverage.cjs --json` returned `detected: true` on a single signal — the phrase
"the Actions API" inside the step-metrics instrument's own `--job` flag documentation. Re-read against
the phase scope, that is the tooling case above, so no coverage matrix is fabricated.
