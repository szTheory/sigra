# Phase 248 Code Review Fix Report

## Fixed Issues

### CR-01: Manual dispatch inputs are interpolated into shell source

Passed manual tag and version inputs into shell steps through environment variables and quoted the shell references. A contract test checks every `run:` body for direct `${{ inputs.tag }}` or `${{ inputs.release_version }}` interpolation.

Validation: the Phase 248 release-gate ExUnit contract tests passed; `actionlint` and ShellCheck passed for the changed workflows and scripts.

### CR-03: Failed gate receipts can claim the release run as the CI run

The CI poller now emits structured failure JSON with the actual observed CI run ID and URL, or null identity fields when no CI run was observed. The Release Please workflow carries those values into receipts without substituting the Release Please run. The receipt validator allows null identity only for a failed CI-gate stage; a passing gate still requires a real run identity.

Validation: poller tests passed (15/15), receipt tests passed (15/15), Phase 248 release-gate and observer contract tests passed (13/13), `actionlint` and ShellCheck passed.

## Regression Gate Repairs

Updated the older release-lane assertions to match the workflow's read-only global permissions and job-scoped issue write access, and adjusted the Phase 146 trigger assertion for the existing Release Please branch. Refreshed the generated-host golden files for the current confirmation LiveView, feedback component, and optional-scope confirmation routes. The route injection now removes whitespace-only lines so generated router output stays clean.

The full suite ran 2,655 tests and reported two Phase 235 failures because its nested `sandbox-exec` subprocess could not start inside the restricted runner. Rerunning those exact two tests outside that parent sandbox passed (2/2); the golden diff passed separately (2/2).
