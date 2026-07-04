/**
 * lenses.mjs — 4 lens definitions + prompt assembly for the LLM panel (Phase 217, Plan 05).
 *
 * Exports:
 *   LENSES — array of 4 lens definition objects:
 *     { id, name, questions: [{key, prompt}], adversarial_instruction, evidence }
 *
 *   assemblePrompt({ surface, cell, excerptDom, factsJson }) → { system, user }
 *     system: cached rubric text (routed to a cache_control:{type:'ephemeral'} block)
 *     user:   per-cell user content (DOM excerpt + facts for persona lenses;
 *             image block + DOM for graphic-design lens)
 *
 * No API call here — pure prompt construction. Byte-stable output so a prompt_sha can be
 * computed over the assembled text.
 *
 * The 3 persona lenses (platform_admin, support_investigator, org_admin) are fed:
 *   - DOM excerpt (canonicalized HTML from excerpt.mjs, structural anchors retained)
 *   - facts.json (geometric probe facts — ground truth, never recomputed)
 *
 * The graphic_design lens is fed:
 *   - screenshot PNG as a base64 image block (fed by the caller via imageBase64 + imageMediaType)
 *   - DOM excerpt for anchor lookup only
 *
 * The NONE — searched for: token is the forced-floor signal. Every cell must either provide
 * a cited element (verdict != keep) OR this literal token (verdict == keep).
 *
 * References:
 *   guides/reference/admin-persona-jtbd-rubric.md — persona lens definitions + questions
 *   guides/reference/admin-graphic-design-lens.md — graphic design lens definitions + questions
 *   scripts/panel/panel-schema.mjs — PANEL_SCHEMA, findingId
 */

// ---------------------------------------------------------------------------
// Persona lens question definitions (verbatim from admin-persona-jtbd-rubric.md)
// ---------------------------------------------------------------------------

const PERSONA_QUESTIONS = [
  {
    key: 'earning_its_place',
    label: 'Earning its place?',
    refutation_probe:
      'Name one element on this surface that is NOT earning its place for this lens. ' +
      'If none, say so explicitly, including what you searched for.',
    none_path:
      'NONE — searched for: <description of what was reviewed, e.g. "duplicate metrics between the stat strip and the detail dl" or "elements present only for a different lens posture">',
    target_failure: 'verbosity / info-dump — elements present that are not doing a job for this lens',
  },
  {
    key: 'ia_muddy',
    label: 'Is the IA muddy?',
    refutation_probe:
      'Where does the general→specific hierarchy break for this lens, or where is the next action not obvious? ' +
      'Point to the exact element (a heading, a navigation link, a section order, a call-to-action placement).',
    none_path:
      'NONE — searched for: <description, e.g. "inverted hierarchy between the scope ribbon and the stat strip" or "primary action placement relative to secondary evidence">',
    target_failure: 'IA hierarchy — general-to-specific principle broken; next action not obvious',
  },
  {
    key: 'redundant_coherent_surprising',
    label: 'Redundant / coherent / least-surprising?',
    refutation_probe:
      'Name one place where this surface says the same thing twice, diverges from a sibling surface doing the same job, ' +
      'or would surprise the operator given what they have seen on adjacent pages.',
    none_path:
      'NONE — searched for: <description, e.g. "duplicate count between the stat strip and the filter panel" or "vocabulary drift between this surface and the audit pages">',
    target_failure: 'redundancy and coherence — same information shown twice; divergence from sibling surfaces; surprising vocabulary or layout',
  },
];

// ---------------------------------------------------------------------------
// Graphic design lens question definitions (from admin-graphic-design-lens.md)
// ---------------------------------------------------------------------------

const GRAPHIC_DESIGN_QUESTIONS = [
  {
    key: 'salience',
    label: 'Does the eye land on the wrong thing first?',
    class_key: 'graphic_design:salience',
    named_pillar: 'hierarchy/salience',
    refutation_probe:
      'Name one element in this PNG that draws the eye MORE than the primary action or the key status signal. ' +
      'If none, say so explicitly, including what you searched for.',
    none_path:
      'NONE — searched for: <description of what was reviewed, e.g. "decorative elements competing with the primary CTA" or "secondary status chips dominating the KPI strip">',
    target_failure:
      'Perceived first-fixation dominance of the wrong element — the eye lands on a secondary or decorative element before the primary action or key status signal.',
    citation:
      'admin-ui-principles.md §Information Architecture — "make the next action obvious"; brandbook/brand-book.md §Design Principles — "Proof over mood"',
  },
  {
    key: 'emphasis_ember',
    label: 'Is emphasis (especially ember) earning its meaning, or decorating?',
    class_key: 'graphic_design:emphasis_ember',
    named_pillars: 'restraint + ember-as-boundary',
    refutation_probe:
      'Name one place in this PNG where ember is applied decoratively (not at an ownership boundary, CTA, or selection state), ' +
      'OR name one meaning-bearing element that is under-emphasized (should carry ember or heavier weight and does not). ' +
      'If neither, say so explicitly, including what you searched for.',
    none_path:
      'NONE — searched for: <description, e.g. "decorative ember on section headings" or "under-emphasized primary CTA on the dark-theme screenshot">',
    target_failure:
      'Semantic drift of the ember accent — used decoratively where no ownership boundary, primary action, or selection state exists; OR under-emphasis of meaning-bearing elements.',
    brand_values:
      'Light theme: #c2410c (CSS token --sigra-accent). Dark theme: #fdba74 (CSS token --sigra-accent-strong in dark mode). Space Grotesk weight conventions (wght=700). Core Rails visual identity: the rail-block mark + linked g-tail lockup.',
    citation:
      'brandbook/brand-book.md §Color — "Ember is for Sigra identity, primary CTAs, selected states, and ownership-boundary highlights. Do not use accent color for every icon or heading. Dark mode must use the lightened accent-strong token (#fdba74)"; admin-ui-principles.md §Brand Application — "Ember accent is for Sigra identity, primary actions, selected states, and ownership-boundary emphasis. Do not use it for every heading or icon"',
  },
  {
    key: 'composition',
    label: 'Does grouping / type hierarchy / balance read coherently in BOTH themes?',
    class_key: 'graphic_design:composition',
    named_pillars: 'consistency + typographic coherence + dark/light emphasis parity + composition/balance',
    refutation_probe:
      'Name one place where gestalt grouping, type-hierarchy descent, or visual balance breaks on the rendered PNGs — in either or both themes. ' +
      'If none, say so explicitly for each theme, including what you searched for.',
    none_path:
      'NONE — searched for: <description, e.g. "type-hierarchy inversion on the dark screenshot" or "gestalt grouping failures between the stat strip and the task cards">',
    target_failure:
      'Compositional breakdown — gestalt grouping that reads as unintentional, type-hierarchy descent that is ambiguous or inverted, visual balance that tips uncomfortably, or emphasis that works in one theme but not the other.',
    screenshot_requirement:
      'This question requires BOTH light-theme AND dark-theme screenshot.png. Must cite which theme(s) the finding was observed on: evidence_cell: light | dark | both.',
    citation:
      'admin-ui-principles.md §Design System — "8px visual rhythm; same job means same component"; §Theme And Motion — "Admin supports Light, Dark, and System"; brandbook/brand-book.md §Layout — "8px visual rhythm; prefer full-width bands and constrained inner content"',
  },
];

// ---------------------------------------------------------------------------
// Persona lenses (3 — from admin-persona-jtbd-rubric.md)
// ---------------------------------------------------------------------------

const PERSONA_LENSES = [
  {
    id: 'platform_admin',
    name: 'Platform Admin',
    persona: 'admin@demo.tasklane.test',
    entry_point: '/admin',
    posture: 'triage',
    primary_intent:
      '"What needs attention now? Where do I go next?" — scans overview KPIs, drills into task cards, pivots to org scope.',
    ledger_cell: 'flow-platform-admin',
    questions: PERSONA_QUESTIONS,
    evidence: 'dom_and_facts', // fed DOM excerpt + facts.json
  },
  {
    id: 'support_investigator',
    name: 'Support Investigator',
    persona: 'admin@demo.tasklane.test acting on a target (dave, frank, grace, carol)',
    entry_point: '/admin/users/:id',
    posture: 'investigate',
    primary_intent:
      '"Find → audit → impersonate → return with banner" — full investigator JTBD flow with scope continuity.',
    ledger_cell: 'flow-support-investigator',
    questions: PERSONA_QUESTIONS,
    evidence: 'dom_and_facts',
  },
  {
    id: 'org_admin',
    name: 'Org Admin',
    persona: 'morgan@demo.tasklane.test (org_admin: :acme, non-platform)',
    entry_point: '/admin/organizations/:slug',
    posture: 'bound',
    primary_intent:
      '"Tenant-only; clean 403 on overreach" — org member posture, no global scope, expects a refusal at every out-of-bound path.',
    ledger_cell: 'flow-org-admin',
    questions: PERSONA_QUESTIONS,
    evidence: 'dom_and_facts',
  },
];

// ---------------------------------------------------------------------------
// Graphic design lens (1 — from admin-graphic-design-lens.md)
// ---------------------------------------------------------------------------

const GRAPHIC_DESIGN_LENS = {
  id: 'graphic_design',
  name: 'Graphic Design',
  questions: GRAPHIC_DESIGN_QUESTIONS,
  evidence: 'screenshot', // fed base64 screenshot + DOM for anchoring only
  seven_pillars: [
    'hierarchy/salience — Primary actions and key status signals must dominate attention; secondary elements recede',
    'restraint — Accent color and visual weight are spent only where they carry meaning',
    'ember-as-boundary — Ember (#c2410c light / #fdba74 dark) marks Sigra identity, primary actions, selected states, and ownership-boundary highlights — it is a semantic signal, not decoration',
    'consistency — Same job → same component; identical patterns across sibling surfaces',
    'typographic coherence — Type hierarchy is legible, unambiguous, and consistent with Space Grotesk weight conventions',
    'dark/light emphasis parity — Emphasis signals (weight, color contrast, size) land with equal clarity in both light and dark themes',
    'composition/balance — Gestalt grouping, whitespace rhythm, and visual weight are distributed so the layout reads as an intentional whole',
  ],
};

// ---------------------------------------------------------------------------
// All 4 lenses in order
// ---------------------------------------------------------------------------

/**
 * All 4 panel lenses: 3 persona lenses + 1 graphic-design lens.
 * @type {Array<Object>}
 */
export const LENSES = [...PERSONA_LENSES, GRAPHIC_DESIGN_LENS];

// ---------------------------------------------------------------------------
// Standing rubric instruction (shared across all lenses)
// ---------------------------------------------------------------------------

const STANDING_INSTRUCTION = `
STANDING RUBRIC INSTRUCTION — MANDATORY:

For each (lens × question) cell, find the STRONGEST CASE AGAINST this surface for this lens.
Do NOT anchor on what looks fine. Start by assuming something is wrong and search for evidence.

A verdict of "keep" with zero findings is valid ONLY after you have:
  (a) actively tried to find a fault for this (lens × question) cell, AND
  (b) stated what you searched for in the NONE — searched for: <what> token.

FORCED-FINDING FLOOR: every (lens × question) cell in your output holds EITHER:
  - A cited element with a concrete DOM/section anchor (data-testid, sg-* BEM class, role, aria-label,
    semantic CSS class), a refutation (one-line description of the failure), and an observation, OR
  - The literal token "NONE — searched for: <what>" where <what> is a description of the
    specific hypothesis that was tested and found not to hold.

A cell is NEVER left blank.
A cell is NEVER filled with a vague positive ("looks good", "no issues found") without the
explicit "NONE — searched for:" token.

Every finding must cite a CONCRETE DOM/SECTION ANCHOR. Vibe-level assertions ("the page feels
cluttered") without a cited element fail the forced-finding floor and must be replaced with a
specific, locatable reference.

Verdict scale: keep | tighten | kill
  - keep: Element earns its place for this lens; no change warranted.
  - tighten: Element has a purpose but is verbose, poorly placed, or partially muddy; worth editing.
  - kill: Element does not earn its place, or actively harms the flow through confusion, redundancy, or hierarchy violation.

Disposition rollup rule: worst verdict across all lenses for an element = the final disposition.
A kill from any single lens is a kill for the element regardless of keep verdicts from others.
`.trim();

// ---------------------------------------------------------------------------
// System rubric text (cached — routed to cache_control:{type:'ephemeral'})
// ---------------------------------------------------------------------------

function buildSystemRubric() {
  const personaSection = PERSONA_LENSES.map((lens) => {
    const qLines = lens.questions.map((q) => `
  ### ${lens.name}: ${q.label}
  Target failure: ${q.target_failure}
  Refutation probe: ${q.refutation_probe}
  NONE path example: ${q.none_path}`).join('\n');

    return `## Lens: ${lens.name} (id: ${lens.id})
Entry point: ${lens.entry_point}
Posture: ${lens.posture}
Primary intent: ${lens.primary_intent}
${qLines}`;
  }).join('\n\n');

  const pillarLines = GRAPHIC_DESIGN_LENS.seven_pillars.map((p) => `  - ${p}`).join('\n');
  const gdQLines = GRAPHIC_DESIGN_LENS.questions.map((q) => `
  ### Graphic Design: ${q.label} (class: ${q.class_key})
  Named pillar(s): ${q.named_pillars || q.named_pillar}
  Target failure: ${q.target_failure}
  Refutation probe: ${q.refutation_probe}
  NONE path example: ${q.none_path}
  ${q.brand_values ? 'Brand values (cite these): ' + q.brand_values : ''}
  ${q.screenshot_requirement ? 'Screenshot requirement: ' + q.screenshot_requirement : ''}
  Citation: ${q.citation}`).join('\n');

  return `# Sigra Admin Panel — 4-Lens Quality Rubric

You are an adversarial quality judge evaluating a Sigra admin UI surface.
You must evaluate the surface using ALL 4 LENSES below in a single response.

${STANDING_INSTRUCTION}

---

## Output Format (REQUIRED)

Your response must be valid JSON matching this structure (4 lenses × 3 questions = 12 cells):

{
  "platform_admin": {
    "earning_its_place": { "verdict": "keep|tighten|kill", "anchor": "...", "refutation": "..." } OR { "verdict": "keep", "none_searched_for": "NONE — searched for: ..." },
    "ia_muddy": { ... },
    "redundant_coherent_surprising": { ... }
  },
  "support_investigator": { ... },
  "org_admin": { ... },
  "graphic_design": {
    "salience": { "verdict": "keep|tighten|kill", "anchor": "...", "refutation": "...", "observation": "...", "evidence_cell": "light|dark|both" } OR { "verdict": "keep", "none_searched_for": "NONE — searched for: ..." },
    "emphasis_ember": { ... },
    "composition": { ... }
  }
}

For non-keep verdicts: anchor (CSS selector from data-testid/sg-* vocabulary) + refutation (one-line failure description) are REQUIRED.
For keep verdicts: none_searched_for is REQUIRED (the literal "NONE — searched for: <what>" token).

---

## The 3 Persona Lenses (DOM + Facts evidence)

${personaSection}

---

## The Graphic Design Lens (Screenshot evidence)

Seven Named Sigra Pillars (every graphic-design finding must name one):
${pillarLines}

${gdQLines}

---

Remember: You are evaluating a SINGLE surface × cell rendered snapshot. The DOM excerpt and facts.json
are the ground truth for the persona lenses. The screenshot is the evidence for the graphic-design lens.
Do NOT contradict facts.json. Do NOT invent elements not present in the DOM.
Every anchor must resolve in the provided DOM (cheerio selector syntax: data-testid, .sg-*, [role=], etc).`.trim();
}

// Cache the system rubric text (pure constant — computed once)
const SYSTEM_RUBRIC = buildSystemRubric();

// ---------------------------------------------------------------------------
// Public API: assemblePrompt
// ---------------------------------------------------------------------------

/**
 * Assemble the system rubric + per-cell user content for a panel evaluation.
 *
 * The system rubric is a constant (cacheable via cache_control:{type:'ephemeral'}).
 * The user content is assembled per-cell and includes the surface id, cell id,
 * DOM excerpt, facts, and (for graphic-design Q3) base64 screenshot.
 *
 * @param {Object} opts
 * @param {string} opts.surface        - Surface id (e.g. "users-index-live")
 * @param {string} opts.cell           - Cell id (e.g. "light-desktop-populated")
 * @param {string} opts.excerptDom     - Canonicalized HTML from excerpt.mjs
 * @param {string} opts.factsJson      - Serialized facts.json content (string)
 * @param {string} [opts.imageBase64]  - Base64-encoded PNG for graphic-design lens (optional)
 * @param {string} [opts.imageMediaType] - Media type of screenshot (default: "image/png")
 * @returns {{ system: string, user: string, userContentBlocks: Array }}
 *
 * userContentBlocks: the Anthropic SDK-ready content array for the user turn.
 *   For text-only: [{ type: 'text', text: '...' }]
 *   For screenshot cells: [{ type: 'image', source: { type: 'base64', ... } }, { type: 'text', text: '...' }]
 */
export function assemblePrompt({ surface, cell, excerptDom, factsJson, imageBase64, imageMediaType }) {
  const mediaType = imageMediaType || 'image/png';

  const textContent = `Surface: ${surface}
Cell: ${cell}

--- DOM EXCERPT (canonical HTML — structural anchors retained) ---
${excerptDom || '(no DOM excerpt provided)'}

--- FACTS.JSON (ground truth from deterministic probes — do not contradict) ---
${factsJson || '{}'}

--- INSTRUCTIONS ---
Evaluate the surface above using ALL 4 lenses. Return a single valid JSON object with all 12 cells filled.
For the graphic-design lens, evaluate the screenshot image above (if provided).
For the persona lenses, evaluate the DOM excerpt and facts.json.
Every cell must be filled — either a finding (verdict != keep) or a NONE — searched for: token.`;

  // Build content blocks array (Anthropic SDK format)
  const userContentBlocks = [];

  // If a screenshot is available, include it as an image block (for graphic-design lens)
  if (imageBase64) {
    userContentBlocks.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: mediaType,
        data: imageBase64,
      },
    });
  }

  // Add the text content block
  userContentBlocks.push({
    type: 'text',
    text: textContent,
  });

  return {
    system: SYSTEM_RUBRIC,
    user: textContent,
    userContentBlocks,
  };
}
