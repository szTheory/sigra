// P14 (240.3-09-PLAN.md) — mechanical enforcement for the coupled Crosswake host boundary.
//
// The guard deliberately has a JSON subject adapter so `check prohibition-enforcement` can
// prove both a content-caused red (known violation) and a clean green. Normal execution reads
// the shipped host artifacts and derives the same compact fact shape. Every source assertion
// has a marker floor; an empty parser result is a broken check, never a pass.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readRepoFile, stripJsComments } from './_lib.mjs';

const SUBJECT_ENV = 'GSD_PROHIB_SUBJECT';
const REQUIRED_FACTS = Object.freeze({
  authorityMarkerCount: 'number',
  personalOrgNil: 'boolean',
  evaluatorProjectsPersonalOrgNil: 'boolean',
  sessionMarkerCount: 'number',
  encryptedHttpOnlySession: 'boolean',
  callbackUrlIsVerifierFree: 'boolean',
  browserRejectsVerifierExposure: 'boolean',
  callbackMarkerCount: 'number',
  exactCallbackKeys: 'boolean',
  fixedRouteAndDestination: 'boolean',
  smugglingIsRejectedBeforeEvaluation: 'boolean',
});

function stripElixirComments(text) {
  return text
    .split('\n')
    .map((line) => {
      let quoted = false;
      for (let index = 0; index < line.length; index += 1) {
        if (line[index] === '"' && line[index - 1] !== '\\') quoted = !quoted;
        if (line[index] === '#' && !quoted) return line.slice(0, index);
      }
      return line;
    })
    .join('\n');
}

function count(text, pattern) {
  return [...text.matchAll(pattern)].length;
}

function parseInjectedFacts(path) {
  let facts;
  try {
    facts = JSON.parse(readRepoFile(path));
  } catch (error) {
    throw new Error(`could not parse injected Crosswake prohibition facts: ${error.message}`);
  }

  assert.ok(facts && typeof facts === 'object' && !Array.isArray(facts), 'injected facts must be an object');

  for (const [key, type] of Object.entries(REQUIRED_FACTS)) {
    assert.equal(typeof facts[key], type, `injected facts must include ${key} as a ${type}`);
  }

  return facts;
}

function deriveRepositoryFacts() {
  const endpoint = stripElixirComments(readRepoFile('test/example/lib/example_web/endpoint.ex'));
  const controller = stripElixirComments(readRepoFile('test/example/lib/example_web/controllers/crosswake_controller.ex'));
  const adapter = stripElixirComments(readRepoFile('test/example/lib/example/accounts/crosswake_session_adapter.ex'));
  const controllerTest = stripElixirComments(readRepoFile('test/example/test/example_web/controllers/crosswake_controller_test.exs'));
  const browserTest = stripJsComments(readRepoFile('test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts'));

  const callbackQuery = controller.match(/query = %{([\s\S]*?)\n\s*}/)?.[1] ?? '';

  return {
    authorityMarkerCount:
      count(adapter, /org_id:\s*nil/g) + count(controllerTest, /context\.org_id\s*==\s*nil/g),
    personalOrgNil: /org_id:\s*nil/.test(adapter),
    evaluatorProjectsPersonalOrgNil: /context\.org_id\s*==\s*nil/.test(controllerTest),
    sessionMarkerCount:
      count(endpoint, /encryption_salt:/g) + count(endpoint, /http_only:\s*true/g) + count(endpoint, /plug Plug\.Session, @session_options/g),
    encryptedHttpOnlySession: /encryption_salt:/.test(endpoint) && /http_only:\s*true/.test(endpoint),
    callbackUrlIsVerifierFree:
      /"continuation"\s*=>\s*values\.handle/.test(callbackQuery) &&
      /"state"\s*=>\s*values\.state/.test(callbackQuery) &&
      !/pkce_verifier/.test(callbackQuery),
    browserRejectsVerifierExposure:
      browserTest.includes("expect(returnUrl.toString()).not.toContain('pkce_verifier');") &&
      browserTest.includes("expect(finalUrl).not.toContain('pkce_verifier');"),
    callbackMarkerCount:
      count(controller, /def start\(/g) + count(controller, /def return\(/g) + count(controllerTest, /Map\.keys\(params\).*\["continuation", "state"\]/g),
    exactCallbackKeys:
      /@allowed_return_keys\s*\["continuation", "state"\]/.test(controller) &&
      /Map\.keys\(params\)\s*\|>\s*Enum\.sort\(\)\s*==\s*Enum\.sort\(@allowed_return_keys\)/.test(controller) &&
      /Map\.keys\(params\).*\["continuation", "state"\]/.test(controllerTest),
    fixedRouteAndDestination:
      /redirect\(to: CrosswakeContinuations\.destination\(\)\)/.test(controller) &&
      /assert route\.path\s*==\s*"\/app"/.test(controllerTest),
    smugglingIsRejectedBeforeEvaluation:
      /local AuthReturn ignores or rejects smuggled authority route and destination fields/.test(controllerTest) &&
      controllerTest.includes("refute_receive {:crosswake_evaluator_called, _, _, _}"),
  };
}

function facts() {
  const injected = process.env[SUBJECT_ENV];
  return injected ? parseInjectedFacts(injected) : deriveRepositoryFacts();
}

const subject = facts();

test('authority-integrity: personal Crosswake projection never manufactures organization authority', () => {
  assert.ok(subject.authorityMarkerCount >= 2, `authority marker floor was ${subject.authorityMarkerCount}; the parse broke, this is not a pass`);
  assert.equal(subject.personalOrgNil, true, 'personal session projection must keep org_id nil');
  assert.equal(subject.evaluatorProjectsPersonalOrgNil, true, 'the evaluated personal route must observe org_id nil');
});

test('secret-boundary: verifier transport stays encrypted HttpOnly and out of callback URLs', () => {
  assert.ok(subject.sessionMarkerCount >= 3, `session marker floor was ${subject.sessionMarkerCount}; the parse broke, this is not a pass`);
  assert.equal(subject.encryptedHttpOnlySession, true, 'the host transport must be encrypted and HttpOnly');
  assert.equal(subject.callbackUrlIsVerifierFree, true, 'the callback query must contain only opaque continuation and state');
  assert.equal(subject.browserRejectsVerifierExposure, true, 'the browser proof must reject verifier exposure in callback and final URLs');
});

test('authority-smuggling: callback input cannot choose authority, route, or destination', () => {
  assert.ok(subject.callbackMarkerCount >= 3, `callback marker floor was ${subject.callbackMarkerCount}; the parse broke, this is not a pass`);
  assert.equal(subject.exactCallbackKeys, true, 'callback input must accept exactly continuation and state');
  assert.equal(subject.fixedRouteAndDestination, true, 'route and destination must remain host-owned');
  assert.equal(subject.smugglingIsRejectedBeforeEvaluation, true, 'smuggled callback input must be rejected before evaluator invocation');
});
