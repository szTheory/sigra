# API Coverage — Phase 241

> Full coverage by default. The phase's external integration is its fixed-scope GitHub REST API receipt collector for final-head CI evidence.

| capability | decision | reason |
|---|---|---|
| GitHub REST API rate-limit preflight | INTEGRATE | Read core quota/reset before collection and fail closed at the documented threshold. |
| GitHub Actions workflow run identity and conclusion | INTEGRATE | Validate repository, frozen SHA, pull_request event, completion, success, and run URL. |
| GitHub Actions paginated job inventory | INTEGRATE | Exhaust pages and validate totals, identities, completion, and unique job IDs. |
| Required contributor CI job and step outcomes | INTEGRATE | Verify the unique library owner, contributor gate step, and library aggregator. |
| Required fast-check job and prohibition step outcomes | INTEGRATE | Verify the unique fast-check job and prohibition guard step. |
| GitHub pull-request evidence comment | INTEGRATE | Optional `--comment` publishes the machine-readable receipt to the selected PR. |
