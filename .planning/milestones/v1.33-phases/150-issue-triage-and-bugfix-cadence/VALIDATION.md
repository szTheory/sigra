## Phase 150 Verification Strategy

### Goal-Backward Verification
**Goal:** Establish a repeatable process for monitoring adopter feedback, diagnosing friction, and patching bugs.

To achieve this goal, the following must be true:
1. **Maintainers have a documented, repeatable cadence for issue triage and bug prioritization.**
   - Verified by: `MAINTAINING.md` contains a specific triage section detailing labels (`bug`, `friction`, `enhancement`) and priorities (`P0` to `P3`), along with a communication posture rule.
2. **The zero-bug state (no open high-priority bugs) is verified and documented.**
   - Verified by: The `150-VERIFICATION.md` document clearly states the findings from `gh issue list` and `.planning/todos/pending/`.
3. **Adopters are explicitly instructed to use `mix sigra.upgrade` for template patches.**
   - Verified by: `CHANGELOG.md` unreleased section includes the template update block pattern, and `MAINTAINING.md` codifies the rule to include it when templates change.

### Verification Steps
Run the following after execution:
1. Read `MAINTAINING.md` to ensure the new triage section exists and accurately reflects the rules.
2. Read `CHANGELOG.md` to ensure the `Template Updates Required` header and instructions exist in the Unreleased section.
3. Ensure `.github/ISSUE_TEMPLATE/bug_report.md` requires minimum evidence for bugs.
4. Read `150-VERIFICATION.md` to confirm the bug state verification was completed.