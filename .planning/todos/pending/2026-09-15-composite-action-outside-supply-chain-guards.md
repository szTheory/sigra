---
created: 2026-09-15
source: v1.47 CI-EFFICIENCY milestone audit (re-audit at close)
severity: medium
requirements: [DX-01, DX-02, PW-02]
audit_acknowledged: v1.47
resolves_phase: 241
---

# Phase 232's composite action sits outside both Phase 234 supply-chain guards

`.github/actions/example-playwright-boot/action.yml` pins four third-party actions by SHA
(`:49` setup-beam, `:55` setup-node, `:63` and `:111` actions/cache). Neither guard reaches
them:

- **DX-01 pin guard** scopes itself to two files —
  `phase_234_action_pinning_contract_test.exs:4-8`
  `@release_workflows = [release-please.yml, hex-publish.yml]`. The four pins in the
  composite action (and every pin in `ci.yml`) are unguarded.
- **DX-02 Dependabot** declares `github-actions` at `directory: "/"` only, which does not
  reach `.github/actions/**/action.yml`; `phase_234_dependabot_contract_test.exs:15-16`
  locks the config to exactly three entries, so adding coverage requires editing the test.

Net: the composite action Phase 232 created will silently rot. Add a
`github-actions` Dependabot entry for `/.github/actions/example-playwright-boot` and widen
the pin guard's file set.
