/**
 * Shared control primitives for the offline Node contract and opt-in Playwright controls.
 * Keep these exports dependency-free so Node 20 can execute the same implementation
 * used by the opt-in Playwright controls.
 */
const PURPOSES = new Set(['held-positive', 'broken-readiness-positive', 'forced-trace-positive', 'collision']);

export function registrationControlAccount(projectName, purpose) {
  if (!PURPOSES.has(purpose)) throw new TypeError(`Unknown registration control account purpose: ${purpose}`);
  const project = String(projectName).replace(/^admin-eval-?/, '').replace(/[^a-z0-9]+/gi, '') || 'desktop';
  return `platform-admin+sigra-253-control-${project.toLowerCase()}-${purpose}@example.test`;
}

/** @param {{page: unknown, waitForHold: Function, fill: Function, submit: Function, assertNoPostWhileHeld: Function, release: Function, waitUntilReady: Function, assertSuccess: Function, annotate?: Function}} options */
export async function runHeldRegistrationControl(options) {
  const { page } = options;
  await options.waitForHold(page);
  options.annotate?.('connection_hold_observed');
  await options.fill(page);
  options.annotate?.('fill');
  await options.assertNoPostWhileHeld(page);
  options.release();
  options.annotate?.('connection_released');
  await options.waitUntilReady(page);
  options.annotate?.('readiness_ready');
  await options.submit(page);
  options.annotate?.('submit');
  await options.assertSuccess(page);
  options.annotate?.('original_assertion');
}
