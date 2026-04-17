// test-only: shared deterministic credentials for Playwright specs.
//
// These values MUST NEVER be reused in any non-test environment. They
// exist purely so Playwright specs can register and log in against the
// ephemeral test/example app with a single, obviously-intentional
// literal rather than duplicating the same password across every spec
// file (which would also confuse secret scanners into flagging each
// copy independently).
//
// The matching server-side default lives in
// scripts/ci/admin-acceptance-smoke.sh (SIGRA_ADMIN_PASSWORD). If one
// changes, the other MUST change too, or the generated-host admin
// smoke will fail to log in.

export const TEST_PASSWORD = 'CorrectHorseBatteryStaple123!';
