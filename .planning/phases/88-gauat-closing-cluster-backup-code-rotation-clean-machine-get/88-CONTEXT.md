# Phase 88: GAUAT closing cluster — backup-code rotation + clean-machine getting-started + results filing & SEED-001 closure - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 88 closes the remaining human-facing GAUAT work for v1.20: backup-code regeneration witness proof (`GAUAT-07`), a clean-machine getting-started run (`GAUAT-08`), and the consolidated launch-leg result file plus `SEED-001` status update (`GAUAT-09`). It does not reopen the already-reshaped email/OAuth verification approach from Phases 86 and 87; it consumes those evidence bundles and files the final launch-leg truth.

</domain>

<decisions>
## Implementation Decisions

### Backup-code evidence shape
- **D-88-01:** `GAUAT-07` uses a hybrid evidence pack, but transcript/query truth is primary. Screenshots prove the human flow happened; persisted-state and audit proofs carry the security claim.
- **D-88-02:** The evidence directory must contain `README.md`, `transcript.log`, an explicit old-code-reuse failure artifact, an explicit audit proof artifact for `mfa.backup_codes_regenerate`, and a `screenshots/` folder with only the key user-visible checkpoints.
- **D-88-03:** The screenshot set stays minimal: sudo prompt reached, regenerate modal with TOTP input, success/new-codes-shown-once, and audit UI row visible if the UI is used as the human-facing confirmation surface.
- **D-88-04:** Do not treat screenshots as proof that old codes were invalidated. The proof must show a pre-regen code failing after regen or an equivalent query-backed verification.
- **D-88-05:** Do not over-expose raw backup codes. One tightly scoped “shown once” capture is enough; prefer redaction/cropping anywhere else.

### Clean-machine run standard
- **D-88-06:** `GAUAT-08` uses a hybrid standard: keep `scripts/ci/getting-started-contract.sh` as the mechanical floor, then add one bounded human fresh-run on a fresh Phoenix 1.8 app.
- **D-88-07:** The operator may know Phoenix, Mix, and normal Elixir tooling, but should be new to Sigra specifically. “Unfamiliar developer” does not mean novice; it means no prior Sigra-specific tribal knowledge.
- **D-88-08:** A “clean machine” means a fresh temporary Phoenix host app with the published prerequisites already installed. It does not require a theatrical pristine VM beyond the documented prereqs.
- **D-88-09:** Record `start`, `first server boot`, `first successful register/login/reset cycle`, and `end`. Treat “under 30 minutes” as a target attestation, not a brittle cliff gate.
- **D-88-10:** Evidence for `GAUAT-08` must include a timestamped transcript, exact host/prereq versions, and a short friction log. Off-script source spelunking or maintainer hints count as friction and must be written down.

### Go/no-go and seed-closure policy
- **D-88-11:** `validated` requires every `GAUAT-01..08` row to be explicitly closed with remote-verifiable CI evidence or dated human evidence on the exact release-candidate SHA/tag. Local-only green is never enough for launch truth.
- **D-88-12:** `partially-validated` is allowed only for pre-declared non-launch-critical laggards, with an explicit `reopen_trigger` naming the row, the missing proof, and what claim remains off-limits until closure.
- **D-88-13:** There must be no silent pending rows in `.planning/v1.20-GA-UAT-RESULTS.md`. Every row is `PASS`, `FAIL`, or `BLOCKED`.
- **D-88-14:** The current Phase 87 caveat is load-bearing: as of 2026-04-28, `GAUAT-03..06` are only local-pass until the SHA `367a164` GitHub Actions provenance exists and the evidence READMEs are regenerated with populated `ci_run_url`.

### Results-file structure
- **D-88-15:** `.planning/v1.20-GA-UAT-RESULTS.md` is a compact signoff index, not a second workflow spec and not a clone of `.planning/v1.4-GA-UAT.md`.
- **D-88-16:** The file structure is:
  `# Sigra v1.20 GA UAT Results`
  `## Release anchors`
  `## Scope and source-of-truth`
  `## GAUAT results`
  `## Launch-leg disposition`
  `## Follow-ups / reopen triggers` when needed.
- **D-88-17:** The `GAUAT results` table columns are: `Requirement | Outcome | Evidence | Residual / exception | Launch impact`.
- **D-88-18:** Keep outcome vocabulary to `PASS`, `FAIL`, `BLOCKED`. Evidence links should stay within two clicks of the underlying proof bundle.

### Downstream planning preference
- **D-88-19:** Downstream agents should shift decision burden left by default for this phase: synthesize a coherent recommended approach and only surface user choices when they are genuinely high-impact. Honor the repo’s existing `workflow.discuss_comprehensive_research` and `workflow.discuss_synthesize_when_user_delegates` posture.

### the agent's Discretion
- Exact filenames for the backup-code audit/query artifacts (`audit-query.txt` vs `audit-row.json`) as long as the proof is explicit and reviewer-friendly.
- Whether the `GAUAT-08` transcript is pure shell output or wrapped with a small README summary, as long as timestamps, versions, and friction are easy to inspect.
- Whether `.planning/v1.20-GA-UAT-RESULTS.md` includes one or two evidence links per row, as long as it remains concise and within the two-click rule.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap
- `.planning/ROADMAP.md` — Phase 88 goal, dependency shape, success criteria, and next-phase relationship
- `.planning/REQUIREMENTS.md` — `GAUAT-07`, `GAUAT-08`, `GAUAT-09`
- `.planning/PROJECT.md` — v1.20 trust-surface framing and launch goal
- `.planning/STATE.md` — current phase-87 provenance caveat and v1.20 sequencing

### Prior-phase context and verification
- `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` — locked reshape for `GAUAT-01/02`, evidence conventions, and residual policy
- `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-CONTEXT.md` — locked reshape for `GAUAT-03..06`, evidence conventions, and adopter-side real-credential posture
- `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md` — current `local_pass_pending_ci_provenance` caveat; load-bearing for `D-88-14`
- `.planning/phases/59-uat-ga-narrative-alignment/59-CONTEXT.md` — machine-vs-human honesty and pointer discipline

### Evidence and seed surfaces
- `.planning/uat-evidence/v1.20/INDEX.md` — current v1.20 evidence bundle index and naming conventions
- `.planning/v1.4-GA-UAT.md` — prior canonical GA result matrix shape; useful as contrast, not a template to copy wholesale
- `.planning/uat-evidence/v1.4/INDEX.md` — prior evidence-index conventions
- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` — seed status semantics and supersession target
- `docs/uat-ci-coverage.md` — authoritative CI-substitute vs residual policy for SEED-001 rows

### Code and script touch points
- `test/example/test/example_web/smoke/backup_code_rotation_test.exs` — machine proof precedent for old-code invalidation
- `lib/sigra/mfa.ex` — authoritative backup-code regeneration and audit semantics
- `test/sigra/mfa_audit_atomicity_test.exs` — audit-row and rollback semantics for MFA flows
- `test/example/lib/example/accounts.ex` — example-app regen entrypoint
- `guides/introduction/getting-started.md` — walkthrough being witnessed in `GAUAT-08`
- `scripts/ci/getting-started-contract.sh` — mechanical floor for `GAUAT-08`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/example/test/example_web/smoke/backup_code_rotation_test.exs`: already proves old-code invalidation after regeneration; can guide the human evidence sequence for `GAUAT-07`
- `scripts/ci/getting-started-contract.sh`: already enforces link and command integrity for `getting-started.md`
- `.planning/uat-evidence/v1.20/*/README.md`: existing bundle README/frontmatter shape to reuse for new evidence directories

### Established Patterns
- v1.20 evidence favors text-first READMEs, machine-readable manifests, and small hero artifacts instead of large media dumps
- The project separates stable CI-policy truth (`docs/uat-ci-coverage.md`) from milestone outcome truth (`*-GA-UAT*.md`)
- Verification records are explicit about provenance gaps rather than smoothing them over

### Integration Points
- `.planning/v1.20-GA-UAT-RESULTS.md` will consume rows from the existing `email-phase-04`, `email-phase-08`, `oauth-gen`, `oauth-google`, `oauth-link`, and `oauth-email-match` evidence bundles
- `SEED-001` frontmatter update depends on the final result-file disposition
- Phase 89 launch posture depends directly on the truth filed here

</code_context>

<specifics>
## Specific Ideas

- The backup-code proof pack should feel like “human witness plus query-backed security truth,” not a screenshot gallery.
- The getting-started witness should test real doc clarity for a competent Phoenix developer, not stage a novice-usability performance.
- Phase 88 should prefer concise, auditable docs over broad matrices or prose-heavy status narratives.

</specifics>

<deferred>
## Deferred Ideas

- Fully automated end-to-end backup-code regeneration with DB/audit proof in Playwright would be a future tightening step, but it is not required to close Phase 88.
- A heavier onboarding-study artifact (full recording, third-party operator, repeated runs) is a later DX research lane, not v1.20 launch scope.

</deferred>

---

*Phase: 88-gauat-closing-cluster-backup-code-rotation-clean-machine-get*
*Context gathered: 2026-04-28*
