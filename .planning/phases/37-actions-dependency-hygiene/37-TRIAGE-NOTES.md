# CI-01 triage — Dependabot / workflow Actions PRs

**Recorded:** 2026-04-17

Open pull requests authored by Dependabot that touch first-party `actions/*` upgrades (999.2 scope):

| PR | Title | Branch | Supersedes with Phase 37 manual pins? |
|----|-------|--------|----------------------------------------|
| #4 | ci: bump actions/checkout from 4.3.1 to 6.0.2 | `dependabot/github_actions/actions/checkout-6.0.2` | **Yes** — Phase 37 Plan 01 pins `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd` (# v6.0.2) across workflows. Close or comment when manual bump merges. |
| #3 | ci: bump actions/upload-artifact from 4.4.3 to 7.0.1 | `dependabot/github_actions/actions/upload-artifact-7.0.1` | **Superseded on different major** — Plan 01 intentionally lands **upload-artifact v6.0.0** (`b7c566a772e6b6bfb58ed0dc250532a479d7789f`) per research, not v7. Close with rationale when manual bump merges. |
| #1 | ci: bump actions/setup-node from 4.0.4 to 6.3.0 | `dependabot/github_actions/actions/setup-node-6.3.0` | **Yes** — Plan 01 pins `actions/setup-node@2028fbc5c25fe9cf00d9f06a71cc4710d4507903` (# v6.0.0). Close or comment when manual bump merges. |

No additional open Dependabot workflow PRs were listed by `gh pr list --search "dependabot" --state open` beyond the above on this date.
