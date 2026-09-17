// P19 (238-02-PLAN.md, expanded by 238-03-PLAN.md task 1/2) — mechanical enforcement.
//
//   MUST assert that the live GitHub tag ruleset `tag-namespace` (a `target: "tag"` server-side
//   ruleset restricting `v*` tag creation outside a three-component release shape) is mirrored,
//   field for field, in the committed snapshot `.github/rulesets/tag-namespace.json`. The
//   ruleset itself is Settings-managed — there is no git-side record of it except this snapshot
//   — so a guard that never reads the snapshot could not tell "someone deleted the ruleset in
//   Settings" from "the ruleset never existed" or "the ruleset was quietly repointed at branches
//   instead of tags", nor could it tell "the exclusion that keeps release tags out of scope was
//   silently widened until it protected nothing".
//
// Subject: .github/rulesets/tag-namespace.json (via GSD_PROHIB_SUBJECT).
//
// STRUCTURAL AND OFFLINE BY DESIGN, mirroring p12 (`p12-run-id-provenance.test.mjs:1-20`). This
// guard does NOT call the GitHub API, use a token, or touch the network. Two reasons: (1) doing
// so would put `gh`, a token, and a transient 5xx on the pull_request critical path, and a red PR
// for a reason unrelated to the diff is exactly the tax this milestone exists to remove; (2) the
// live-vs-committed drift comparison already has a home — `ci-observe.yml`'s `tag_ruleset_drift`
// job (238-03 task 3), which carries the default `GITHUB_TOKEN` and Metadata: read is enough for
// the two-step ruleset read. This guard is the PR-lane half only: it asserts the committed
// snapshot has the right shape, not that the live object still matches it today.
//
// LANDED SHAPE, NOT THE ORIGINALLY-NAMED ONE (D-10 vs the live outcome). D-10 was written
// against a Tier-1 (`tag_name_pattern`) assumption — asserting that rule's `operator`, `negate`
// and `pattern`. 238-02's live probe found `tag_name_pattern` enterprise-gated on this Free-tier
// repo (HTTP 422) and Tier 2 (a `creation` rule plus `conditions.ref_name.exclude`) landed
// instead (238-02-SUMMARY.md "Landed tier"). Per 238-03-PLAN.md task 1's own instruction —
// "assert that tier's shape — do not write assertions for a shape that is not live" — this guard
// asserts the Tier-2 shape's actual discriminating fields. Tier 2's rule object
// (`{"type":"creation"}`) carries no `operator`/`negate`/`pattern` fields to assert; the
// structural role those three played for a `tag_name_pattern` rule is played here by three
// distinct Tier-2 fields instead, each covered by its own behavior test below:
//   - rule "operator" analogue  -> the rule's `type` field (creation vs. anything else)
//   - rule "negate" analogue    -> whether `conditions.ref_name.exclude` is present at all
//   - rule "pattern" analogue   -> the exact glob string inside `conditions.ref_name.exclude`
//
// What silently breaks if this guard is deleted: `.github/rulesets/tag-namespace.json` could be
// hand-edited to any shape — including `target: "branch"`, a disabled `enforcement`, or an
// `exclude` list widened to swallow the whole `v*` namespace — and nothing on the pull_request
// critical path would notice. The live-vs-committed drift check in `ci-observe.yml` runs only
// after merge (`workflow_run` executes the default-branch copy only, per CONTEXT D-11's honest
// caveat), so this guard is the only check that runs on every PR touching the snapshot.
//
// Non-vacuity floor and negative control follow the p17 idiom
// (`p17-no-playwright-retry-wrapper.test.mjs`, tests 1 and "negative control"): a parse that
// silently matches nothing must not report green, and the guard must be observed failing against
// a known-bad shape in the same commit it is born, or the claim that it protects anything is
// unfalsifiable.
//
// BYPASS ACTORS (D-10, unchanged from the tracer): this guard does NOT assert the bypass actor
// list. GitHub returns `bypass_actors` only to callers with write access to the ruleset, so at
// CI/anonymous permission level an empty array and a populated one are indistinguishable, and
// asserting it here would be a vacuous green. A dedicated behavior test below proves the omission
// is intentional rather than an oversight — it references that field's name only by joining two
// string literals at runtime (`['bypass', 'actors'].join('_')`), purely so this same guard file's
// own verify gate (which greps every non-comment line for the literal field name, to prove the
// CHECKER never asserts it) does not misread a behavior TEST that proves the omission as a
// checker assertion OF it. The checker function `rulesetShapeIssue` below never references that
// field, joined or otherwise — the runtime-join lives only in the test.
//
// KNOWN-BAD FIXTURE: test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json is a
// structurally valid ruleset object (clears every floor above: it is an object, carries a
// `target`, and carries a non-empty `rules` array) that carries two independent violations of
// the landed Tier-2 shape: `enforcement: "disabled"` (the guard is present but toothless) and
// `conditions.ref_name.exclude: ["refs/tags/v*"]` (identical to `include`, so the exclusion no
// longer constrains anything — every `v*` tag, including release tags, is excluded from the
// `creation` rule's scope, which is the opposite of what the exclusion exists to do). JSON
// carries no comment channel, so this paragraph is the fixture's explanatory prose.
//
// LEDGER SECONDARY ASSERTION (238-03 task 2, RESEARCH Pitfall 4): D-16 claims a malformed Phase
// 238 evidence ledger reddens `fast_checks`. At the tracer's HEAD that claim was FALSE — every
// evidence-reading guard in this directory pins Phase 230's ledger by literal path, never this
// phase's own. This guard makes the claim true: it reads `238-EVIDENCE.md` as a SECONDARY
// artifact (via `readRepoFile`, resolved through `archiveAwareRelPath` so the assertion survives
// the milestone close that moves phase directories under `.planning/milestones/`) and asserts its
// `## BEFORE-*` / `## AFTER-*` slot grammar. The ruleset snapshot above remains the ONLY
// substitutable subject in this file — the ledger assertion is never re-pointed by
// `GSD_PROHIB_SUBJECT`.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, archiveAwareRelPath, parseEvidenceSlots } from './_lib.mjs';

const RULESET_SUBJECT = '.github/rulesets/tag-namespace.json';
const KNOWN_BAD_FIXTURE = 'test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json';
const LEDGER_PATH = '.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md';
// 238-EVIDENCE.md's own index table (the markdown table immediately under the file's title)
// declares exactly 10 `## BEFORE-*` / `## AFTER-*` slots. A parse that finds fewer than that
// either broke or the ledger was gutted — either way it is not a pass.
const DECLARED_LEDGER_SLOT_COUNT = 10;

const rawSnapshot = readSubject(RULESET_SUBJECT); // the ONE substitutable subject in this file
const snapshot = JSON.parse(rawSnapshot);

const EXPECTED_INCLUDE = 'refs/tags/v*';
const EXPECTED_EXCLUDE = 'refs/tags/v*.*.*';

/** A minimal, valid Tier-2 snapshot object, used as the base every behavior test mutates. */
function validSnapshot() {
  return {
    id: 23574716,
    name: 'tag-namespace',
    target: 'tag',
    source_type: 'Repository',
    source: 'szTheory/sigra',
    enforcement: 'active',
    conditions: {
      ref_name: {
        include: [EXPECTED_INCLUDE],
        exclude: [EXPECTED_EXCLUDE],
      },
    },
    rules: [{ type: 'creation' }],
  };
}

/**
 * Pure checker over ANY parsed ruleset-shaped object. Returns `null` when clean, or a NAMED,
 * explanatory string otherwise. Never a boolean: the message is what a reviewer reads to know
 * what a mismatch means. Deliberately does NOT reference the bypass-actor field anywhere (D-10).
 */
function rulesetShapeIssue(obj) {
  if (obj === null || typeof obj !== 'object') {
    return 'the parsed value is not an object at all — the parse broke, this is not a pass';
  }
  if (typeof obj.target !== 'string' || obj.target.length === 0) {
    return 'the ruleset object carries no `target` field — the parse broke, this is not a pass';
  }
  const rules = Array.isArray(obj.rules) ? obj.rules : null;
  if (!rules || rules.length === 0) {
    return (
      'the ruleset object carries an empty (or missing) `rules` array — the parse broke, this ' +
      'is not a pass'
    );
  }

  if (obj.target !== 'tag') {
    return (
      `the ruleset's \`target\` is \`${obj.target}\`, not \`tag\` — this snapshot no longer ` +
      'represents a tag-namespace guard, or the guard was silently repointed at branches'
    );
  }

  if (obj.enforcement !== 'active') {
    return (
      `the ruleset's \`enforcement\` is \`${obj.enforcement}\`, not \`active\` — the ruleset is ` +
      'present but disabled, which enforces nothing'
    );
  }

  const include = obj.conditions?.ref_name?.include;
  if (!Array.isArray(include) || !include.includes(EXPECTED_INCLUDE)) {
    return (
      `the ruleset's \`conditions.ref_name.include\` is \`${JSON.stringify(include)}\`, ` +
      `expected to contain \`${EXPECTED_INCLUDE}\` — the tag namespace is no longer in scope`
    );
  }

  const exclude = obj.conditions?.ref_name?.exclude;
  if (!Array.isArray(exclude) || exclude.length !== 1 || exclude[0] !== EXPECTED_EXCLUDE) {
    return (
      `the ruleset's \`conditions.ref_name.exclude\` is \`${JSON.stringify(exclude)}\`, ` +
      `expected exactly \`["${EXPECTED_EXCLUDE}"]\` — the release-tag exclusion (the Tier-2 ` +
      'rule\'s discriminating pattern, the analogue of a `tag_name_pattern` rule\'s `pattern`/' +
      '`negate`) has drifted, either weakening or removing the scope that keeps this guard from ' +
      'blocking release-please'
    );
  }

  if (rules.length !== 1) {
    return (
      `the ruleset carries ${rules.length} rules, expected exactly 1 — an added or removed rule ` +
      'changes what is enforced'
    );
  }

  const ruleType = rules[0]?.type;
  if (ruleType === 'deletion') {
    return (
      'the ruleset carries a `deletion` rule — this guard governs tag CREATION only; a ' +
      '`deletion` rule was never part of the landed Tier-2 shape and its presence signals an ' +
      'out-of-band change to the live ruleset'
    );
  }
  if (ruleType !== 'creation') {
    return (
      `the ruleset's single rule has \`type\` \`${ruleType}\`, not \`creation\` — the landed ` +
      'Tier-2 shape\'s discriminating rule type (the Tier-2 analogue of a changed ' +
      '`tag_name_pattern` `operator`) has drifted'
    );
  }

  return null;
}

// -- Non-vacuity floors -------------------------------------------------------------------

test('floor: a non-object value produces a named message, not a silent pass', () => {
  assert.equal(
    rulesetShapeIssue(null),
    'the parsed value is not an object at all — the parse broke, this is not a pass',
  );
  assert.equal(
    rulesetShapeIssue('not an object'),
    'the parsed value is not an object at all — the parse broke, this is not a pass',
  );
});

test('floor: an object with no `target` field produces a named message', () => {
  const issue = rulesetShapeIssue({});
  assert.ok(issue !== null && issue.includes('no `target` field'), issue ?? '<null>');
});

test('floor: an object with an empty or missing `rules` array produces a named message', () => {
  const obj = validSnapshot();
  obj.rules = [];
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('empty (or missing) `rules` array'), issue ?? '<null>');
});

test('the snapshot parse produced an object with a target field at all (non-vacuity floor)', () => {
  assert.ok(
    snapshot !== null && typeof snapshot === 'object' && typeof snapshot.target === 'string' &&
      snapshot.target.length > 0,
    'the committed snapshot has no readable `target` field — the parse broke, this is not a pass',
  );
});

// -- Behavior: the committed snapshot itself -----------------------------------------------

test('the committed snapshot produces null (every asserted field matches the landed Tier-2 shape)', () => {
  const issue = rulesetShapeIssue(snapshot);
  assert.equal(issue, null, issue ?? '');
});

// -- Behavior: each field's drift produces a named message ---------------------------------

test('a snapshot whose target is not the tag target produces a named message', () => {
  const obj = validSnapshot();
  obj.target = 'branch';
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('`target`'), issue ?? '<null>');
});

test('a snapshot whose enforcement value is not active produces a named message', () => {
  const obj = validSnapshot();
  obj.enforcement = 'disabled';
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('`enforcement`'), issue ?? '<null>');
});

test('a snapshot whose include conditions no longer scope refs/tags/v* produces a named message', () => {
  const obj = validSnapshot();
  obj.conditions.ref_name.include = ['refs/heads/*'];
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('conditions.ref_name.include'), issue ?? '<null>');
});

test(
  "a snapshot whose single rule has a changed type (Tier-2's analogue of a changed operator) " +
    'produces a named message',
  () => {
    const obj = validSnapshot();
    obj.rules[0].type = 'update';
    const issue = rulesetShapeIssue(obj);
    assert.ok(issue !== null && issue.includes('not `creation`'), issue ?? '<null>');
  },
);

test(
  "a snapshot whose exclude conditions were emptied (Tier-2's analogue of a flipped negate " +
    'value) produces a named message',
  () => {
    const obj = validSnapshot();
    obj.conditions.ref_name.exclude = [];
    const issue = rulesetShapeIssue(obj);
    assert.ok(issue !== null && issue.includes('conditions.ref_name.exclude'), issue ?? '<null>');
  },
);

test(
  "a snapshot whose exclude glob value changed (Tier-2's analogue of a changed pattern) " +
    'produces a named message',
  () => {
    const obj = validSnapshot();
    obj.conditions.ref_name.exclude = ['refs/tags/v*.*'];
    const issue = rulesetShapeIssue(obj);
    assert.ok(issue !== null && issue.includes('conditions.ref_name.exclude'), issue ?? '<null>');
  },
);

test('a snapshot with an empty rules array produces a named message', () => {
  const obj = validSnapshot();
  obj.rules = [];
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('empty (or missing) `rules` array'), issue ?? '<null>');
});

test('a snapshot carrying a deletion rule produces a named message', () => {
  const obj = validSnapshot();
  obj.rules = [{ type: 'deletion' }];
  const issue = rulesetShapeIssue(obj);
  assert.ok(issue !== null && issue.includes('`deletion` rule'), issue ?? '<null>');
});

test(
  'altering the bypass actor list (referenced only by a runtime-joined name, so this behavior ' +
    "test itself never trips the guard file's own bypass-field textual gate) still produces " +
    'null, because that field is deliberately not asserted',
  () => {
    const obj = validSnapshot();
    const omittedFieldName = ['bypass', 'actors'].join('_');
    obj[omittedFieldName] = ['someone-with-write-access'];
    const issue = rulesetShapeIssue(obj);
    assert.equal(issue, null, issue ?? '');
  },
);

// -- Negative control and known-bad fixture --------------------------------------------------

test('negative control: an inline object carrying the branch target fails the guard', () => {
  const badObject = { target: 'branch', name: 'tag-namespace', enforcement: 'active', rules: [{ type: 'creation' }] };
  const issue = rulesetShapeIssue(badObject);
  assert.ok(
    issue !== null,
    'an object carrying the wrong target must fail the guard — a guard that only passes on the ' +
      'real snapshot is not falsifiable',
  );
});

test('the committed known-bad fixture also fails the guard (secondary artifact, not the subject)', () => {
  // Read via readRepoFile, never readSubject — only ONE artifact is substitutable per _lib.mjs's
  // one-subject rule, and that is RULESET_SUBJECT above.
  const fixtureRaw = readRepoFile(KNOWN_BAD_FIXTURE);
  const fixtureObj = JSON.parse(fixtureRaw);
  const issue = rulesetShapeIssue(fixtureObj);
  assert.ok(
    issue !== null,
    `the committed known-bad fixture at ${KNOWN_BAD_FIXTURE} must fail the guard`,
  );
  // The fixture must fail on the SHAPE checker (enforcement / exclude drift), never on a floor —
  // a floor failure would mean the fixture is malformed JSON standing in for a real violation.
  assert.ok(
    !issue.includes('the parse broke'),
    `the known-bad fixture failed on a non-vacuity floor instead of a shape drift: ${issue}`,
  );
});

// -- Ledger secondary artifact (238-03 task 2, RESEARCH Pitfall 4) --------------------------

/**
 * Pure checker over the FULL TEXT of a Phase 238-style evidence ledger. Returns `null` when
 * every `## BEFORE-*` / `## AFTER-*` slot's grammar is clean, or a NAMED, explanatory string
 * otherwise. This is a SECONDARY artifact check — the ledger is never the substitutable subject.
 */
function ledgerGrammarIssue(text) {
  let slots;
  try {
    slots = parseEvidenceSlots(text);
  } catch (err) {
    return `the ledger parse broke: ${err.message} — this is not a pass`;
  }

  if (slots.length < DECLARED_LEDGER_SLOT_COUNT) {
    return (
      `the ledger parsed to ${slots.length} slot(s), fewer than the ` +
      `${DECLARED_LEDGER_SLOT_COUNT} the phase's own index table declares — the parse broke, ` +
      'this is not a pass'
    );
  }

  for (const s of slots) {
    if (!/^(BEFORE|AFTER)-[A-Z0-9-]+$/.test(s.name)) {
      return (
        `slot heading \`${s.name}\` does not match the recognised uppercase BEFORE-*/AFTER-* ` +
        'grammar'
      );
    }

    let idx = 0;
    while (idx < s.body.length && s.body[idx].trim() === '') idx += 1;
    const firstLine = s.body[idx] ?? '';
    if (!/^Status:\s*\S/.test(firstLine)) {
      return (
        `slot ${s.name}'s body does not open with a \`Status:\` line at column one (first ` +
        `non-blank line is \`${firstLine}\`)`
      );
    }

    const statusValue = firstLine.replace(/^Status:\s*/, '');
    if (!/^(captured|pending)\b/.test(statusValue)) {
      return (
        `slot ${s.name} has Status \`${statusValue}\`, which begins with neither recognised ` +
        'prefix `captured` nor `pending`'
      );
    }

    if (statusValue.startsWith('captured') && s.fenced.length === 0) {
      return (
        `slot ${s.name} is captured but carries no fenced producing command — a captured claim ` +
        'with no reproducible command is not evidence'
      );
    }
  }

  return null;
}

test('floor: an evidence ledger that parses to zero slots produces a named message, not a pass', () => {
  const issue = ledgerGrammarIssue('# Empty ledger\n\nNo slot headings anywhere in this file.\n');
  assert.ok(issue !== null && issue.includes('the parse broke'), issue ?? '<null>');
});

test('negative control: an inline malformed ledger fails the ledger grammar checker', () => {
  const malformedLedger = [
    '# Fake ledger',
    '',
    '## BEFORE-FOO',
    '',
    'no status line here, just prose.',
    '',
    '## AFTER-BAR',
    '',
    'Status: unknown-value',
    '',
    'no fence either.',
    '',
  ].join('\n');
  const issue = ledgerGrammarIssue(malformedLedger);
  assert.ok(
    issue !== null,
    'a ledger whose first slot opens with prose instead of a `Status:` line must fail the grammar check',
  );
});

test('the Phase 238 evidence ledger (read via the archive-aware path, as a secondary artifact) passes its own grammar check', () => {
  const ledgerText = readRepoFile(archiveAwareRelPath(LEDGER_PATH));
  const issue = ledgerGrammarIssue(ledgerText);
  assert.equal(issue, null, issue ?? '');
});
