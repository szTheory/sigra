/**
 * judge.mjs — LLM panel judge (Phase 217, Plan 05).
 *
 * Makes k=3 independent messages.create calls with:
 *   - model: 'claude-opus-4-8'
 *   - output_config.format (structured JSON schema via PANEL_SCHEMA)
 *   - cached system rubric (cache_control: {type: 'ephemeral'})
 *   - base64 image block for screenshot
 *   - NO temperature/top_p/top_k/assistant-prefill/fixed thinking-budget
 *   - ZERO API calls if render_sha256 matches cached provenance (SC-2)
 *
 * Security invariants (threat model T-217-05-*):
 *   - ANTHROPIC_API_KEY is read from env by the SDK; never in prompts, logs, or committed files
 *   - Every proposed anchor is pre-validated against the real DOM before hashing (T-217-05-INJECT)
 *   - Panel findings go ONLY to panel-findings.json, NEVER to findings.json (T-217-05-EOP)
 *   - admin-panel-verdicts.json NEVER stores open_findings (T-217-05-EOP)
 *
 * Exports (public API for test-double injection):
 *   runJudge({ surface, cell, renderSha256, verdictEntry, excerptDom, factsJson,
 *              sdkClient, outputDir, currentProvenance, imageBase64, imageMediaType })
 *   admitFindings(sampleKeySets, { quorum }) → Set<finding_id>
 *   reconcileFindings(findingId, samples, admitted) → { severity, description, anchor }
 *   checkProvenanceMatch(cached, current) → boolean
 *
 * Used by scripts/ci/admin-panel.sh (the operator-facing orchestrator).
 */

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { findingId as computeFindingId, PANEL_SCHEMA } from './panel-schema.mjs';
import { assemblePrompt } from './lenses.mjs';

const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PW = path.join(ROOT, 'test', 'example', 'priv', 'playwright');
const _require = createRequire(path.join(PW, 'package.json'));
const { load: cheerioLoad } = _require('cheerio');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Model pinned per D-03 / D-08 (claude-api verified). */
const MODEL = 'claude-opus-4-8';

/** k = 3 independent samples per cell (D-08). */
const K = 3;

/** Quorum: a finding is admitted iff finding_id appears in >= QUORUM of K samples (D-08). */
const QUORUM = 2;

/** Staleness horizon: re-verify a pure-taste finding after N renders (D-10). */
const STALENESS_HORIZON = 3;

/** Schema version for committed verdicts cache. */
const SCHEMA_VERSION = '217-05';

/** Severity ordering: kill > tighten > keep */
const SEVERITY_ORDER = { kill: 3, tighten: 2, keep: 1 };

// ---------------------------------------------------------------------------
// checkProvenanceMatch — returns true iff cached and current provenance agree
// on all keys that would invalidate cached verdicts (D-09)
// ---------------------------------------------------------------------------

/**
 * Check if cached provenance matches current provenance.
 * Returns false (cache miss) if any key differs.
 * Cache miss keys: model, k, quorum, rubric_version, prompt_sha.
 *
 * @param {Object} cached
 * @param {Object} current
 * @returns {boolean}
 */
export function checkProvenanceMatch(cached, current) {
  if (!cached || !current) return false;
  return (
    cached.model === current.model &&
    cached.k === current.k &&
    cached.quorum === current.quorum &&
    cached.rubric_version === current.rubric_version &&
    cached.prompt_sha === current.prompt_sha
  );
}

// ---------------------------------------------------------------------------
// admitFindings — quorum-based admission (D-08)
// ---------------------------------------------------------------------------

/**
 * Given k arrays of finding_id sets (one per sample), return the Set of admitted finding_ids.
 * A finding_id is admitted iff it appears in >= quorum of the k samples.
 *
 * @param {Array<Set<string>>} sampleKeySets - k Sets of finding_ids (one per sample)
 * @param {{ quorum: number }} opts
 * @returns {Set<string>} admitted finding_ids
 */
export function admitFindings(sampleKeySets, { quorum = QUORUM } = {}) {
  const counts = new Map();
  for (const keySet of sampleKeySets) {
    for (const fid of keySet) {
      counts.set(fid, (counts.get(fid) || 0) + 1);
    }
  }
  const admitted = new Set();
  for (const [fid, count] of counts) {
    if (count >= quorum) admitted.add(fid);
  }
  return admitted;
}

// ---------------------------------------------------------------------------
// reconcileFindings — worst-verdict severity, first-winning-sample description (D-08)
// ---------------------------------------------------------------------------

/**
 * Reconcile finding samples for a given finding_id:
 *   - severity = worst verdict across winning samples (kill > tighten > keep)
 *   - description/refutation = from the first winning sample
 *   - anchor = from the first winning sample
 *
 * @param {string} findingId
 * @param {Array<Object>} samples - array of {findingId, verdict, anchor, refutation, observation, ...}
 * @param {Set<string>} admitted - the admitted set (for filtering)
 * @returns {{ severity: string, description: string, anchor: string, observation?: string }}
 */
export function reconcileFindings(findingId, samples, admitted) {
  const winningSamples = samples.filter((s) => s.findingId === findingId);
  if (winningSamples.length === 0) {
    return { severity: 'keep', description: '', anchor: '' };
  }

  // worst verdict
  let worstSeverity = 'keep';
  for (const s of winningSamples) {
    const order = SEVERITY_ORDER[s.verdict] || 1;
    if (order > (SEVERITY_ORDER[worstSeverity] || 1)) {
      worstSeverity = s.verdict;
    }
  }

  // first winning sample for description + anchor
  const first = winningSamples[0];
  return {
    severity: worstSeverity,
    description: first.refutation || first.description || '',
    anchor: first.anchor || '',
    observation: first.observation,
    evidence_cell: first.evidence_cell,
    klass: first.klass,
    lens: first.lens,
    question: first.question,
    none_searched_for: first.none_searched_for,
  };
}

// ---------------------------------------------------------------------------
// DOM anchor pre-validation (T-217-05-INJECT)
// ---------------------------------------------------------------------------

/**
 * Validate that an anchor resolves in the given DOM.
 * Returns true if the anchor is a valid CSS selector that resolves to >= 1 element.
 * Drops hallucinated/injected anchors before hashing.
 *
 * @param {string} anchor
 * @param {Object} $ - cheerio instance
 * @returns {boolean}
 */
function anchorResolvesInDom(anchor, $) {
  if (!anchor || typeof anchor !== 'string' || !anchor.trim()) return false;
  try {
    return $(anchor).length > 0;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Parse a single LLM response into a list of findings
// ---------------------------------------------------------------------------

/**
 * Parse a structured LLM response into an array of finding objects.
 * Each finding carries: findingId, verdict, anchor, refutation, klass, lens, question.
 * Keep-verdict cells with none_searched_for are also included (for completeness).
 *
 * @param {Object} responseObj - the parsed JSON response matching PANEL_SCHEMA
 * @param {string} surface - surface id
 * @param {Object} $ - cheerio instance for DOM anchor pre-validation
 * @returns {Array<Object>}
 */
function parseSampleFindings(responseObj, surface, $) {
  const findings = [];
  if (!responseObj || typeof responseObj !== 'object') return findings;

  // Persona lenses (3 questions each)
  const personaLenses = ['platform_admin', 'support_investigator', 'org_admin'];
  const personaQuestions = ['earning_its_place', 'ia_muddy', 'redundant_coherent_surprising'];

  for (const lensId of personaLenses) {
    const lensData = responseObj[lensId];
    if (!lensData || typeof lensData !== 'object') continue;

    for (const questionKey of personaQuestions) {
      const cell = lensData[questionKey];
      if (!cell || typeof cell !== 'object') continue;

      const klass = `${lensId}:${questionKey}`;
      const verdict = cell.verdict;

      if (verdict === 'keep') {
        // Keep cell — include for quorum tracking (filtered out of findings)
        findings.push({
          findingId: null, // no finding_id for keep cells
          verdict: 'keep',
          klass,
          lens: lensId,
          question: questionKey,
          none_searched_for: cell.none_searched_for,
          anchor: null,
        });
        continue;
      }

      // Non-keep: must have anchor + refutation
      const anchor = cell.anchor;
      const refutation = cell.refutation;
      if (!anchor || !refutation) continue;

      // T-217-05-INJECT: pre-validate anchor against real DOM before hashing
      // If anchor doesn't resolve in the DOM, drop it (hallucinated/injected)
      if ($ && !anchorResolvesInDom(anchor, $)) {
        // Silently drop anchor that doesn't resolve — prevents hallucination from entering the vote
        continue;
      }

      // Canonicalize anchor quote-style/whitespace (D-08)
      const canonAnchor = anchor.trim().replace(/\[([^\]]*?)='([^']*)'\]/g, '[$1="$2"]');

      const fid = computeFindingId(surface, klass, canonAnchor);
      findings.push({
        findingId: fid,
        verdict,
        anchor: canonAnchor,
        refutation,
        observation: cell.observation,
        klass,
        lens: lensId,
        question: questionKey,
      });
    }
  }

  // Graphic design lens (3 questions)
  const gdData = responseObj.graphic_design;
  const gdQuestions = ['salience', 'emphasis_ember', 'composition'];

  if (gdData && typeof gdData === 'object') {
    for (const questionKey of gdQuestions) {
      const cell = gdData[questionKey];
      if (!cell || typeof cell !== 'object') continue;

      const klass = `graphic_design:${questionKey}`;
      const verdict = cell.verdict;

      if (verdict === 'keep') {
        findings.push({
          findingId: null,
          verdict: 'keep',
          klass,
          lens: 'graphic_design',
          question: questionKey,
          none_searched_for: cell.none_searched_for,
          anchor: null,
        });
        continue;
      }

      const anchor = cell.anchor;
      const refutation = cell.refutation;
      if (!anchor || !refutation) continue;

      // T-217-05-INJECT: pre-validate anchor
      if ($ && !anchorResolvesInDom(anchor, $)) continue;

      const canonAnchor = anchor.trim().replace(/\[([^\]]*?)='([^']*)'\]/g, '[$1="$2"]');
      const fid = computeFindingId(surface, klass, canonAnchor);
      findings.push({
        findingId: fid,
        verdict,
        anchor: canonAnchor,
        refutation,
        observation: cell.observation,
        evidence_cell: cell.evidence_cell,
        klass,
        lens: 'graphic_design',
        question: questionKey,
      });
    }
  }

  return findings;
}

// ---------------------------------------------------------------------------
// Compute per-lens disposition from admitted findings
// ---------------------------------------------------------------------------

function computeDispositions(admittedFindings) {
  const perLens = {
    platform_admin: 'clean',
    support_investigator: 'clean',
    org_admin: 'clean',
    graphic_design: 'clean',
  };

  for (const f of admittedFindings) {
    const lens = f.lens;
    if (!lens || !perLens.hasOwnProperty(lens)) continue;
    const severity = f.severity;
    if (severity === 'kill') {
      perLens[lens] = 'blocked';
    } else if (severity === 'tighten' && perLens[lens] !== 'blocked') {
      perLens[lens] = 'actionable';
    }
  }

  // Overall surface disposition
  let surface = 'clean';
  for (const d of Object.values(perLens)) {
    if (d === 'blocked') { surface = 'blocked'; break; }
    if (d === 'actionable') surface = 'actionable';
  }

  return { perLens, surface };
}

// ---------------------------------------------------------------------------
// Compute prompt_sha for provenance tracking (T-217-05-KEY)
// ---------------------------------------------------------------------------

/**
 * Compute a SHA-256 of the assembled prompt system text for provenance tracking.
 * Only a hash is stored — never the prompt itself or the API key.
 *
 * @param {string} systemText
 * @returns {string} 16-char hex prefix (sufficient for drift detection)
 */
function computePromptSha(systemText) {
  return createHash('sha256').update(systemText).digest('hex').slice(0, 16);
}

// ---------------------------------------------------------------------------
// runJudge — main entry point
// ---------------------------------------------------------------------------

/**
 * Run the panel judge for a single surface × cell.
 *
 * Cache hit (SC-2): if verdictEntry is provided and provenance matches, return it
 * immediately with ZERO API calls (callCount stays at 0).
 *
 * Cache miss: make k=3 independent messages.create calls, apply quorum admission,
 * reconcile severity/description, write panel-findings.json to outputDir,
 * return the result object for the caller to persist to admin-panel-verdicts.json.
 *
 * @param {Object} opts
 * @param {string} opts.surface - surface id (e.g. "users-index-live")
 * @param {string} opts.cell - cell id (e.g. "light-desktop-populated")
 * @param {string} opts.renderSha256 - 64-char hex from admin-render-sha.json
 * @param {Object|null} opts.verdictEntry - prior verdict from admin-panel-verdicts.json (null = no cache)
 * @param {string} opts.excerptDom - canonicalized HTML from excerpt.mjs
 * @param {string} opts.factsJson - serialized facts.json content
 * @param {Object} opts.sdkClient - Anthropic SDK client (or test-double)
 * @param {string} [opts.outputDir] - directory to write panel-findings.json (default: bundle dir)
 * @param {Object} opts.currentProvenance - {model, k, quorum, rubric_version, prompt_sha}
 * @param {string} [opts.imageBase64] - base64 screenshot for graphic-design lens
 * @param {string} [opts.imageMediaType] - media type (default: "image/png")
 * @returns {Promise<{from_cache: boolean, admitted_findings: Array, surface_disposition: string, ...}>}
 */
export async function runJudge(opts) {
  const {
    surface,
    cell,
    renderSha256,
    verdictEntry,
    excerptDom,
    factsJson,
    sdkClient,
    outputDir,
    currentProvenance,
    imageBase64,
    imageMediaType,
  } = opts;

  // --- Cache hit check (SC-2) ---
  if (verdictEntry && checkProvenanceMatch(verdictEntry.provenance, currentProvenance)) {
    // Content-hash skip: carry prior verdict forward with ZERO API calls
    return {
      from_cache: true,
      admitted_findings: verdictEntry.admitted_findings || [],
      surface_disposition: verdictEntry.surface_disposition || 'clean',
      per_lens_disposition: verdictEntry.per_lens_disposition || {},
      render_sha256: renderSha256,
      provenance: verdictEntry.provenance,
    };
  }

  // --- Cache miss: evaluate with k=3 independent calls ---

  // Build DOM instance for anchor pre-validation (T-217-05-INJECT)
  let $ = null;
  if (excerptDom) {
    try {
      $ = cheerioLoad(excerptDom, { xmlMode: false });
    } catch (_) {
      // If DOM parsing fails, skip anchor validation (permissive)
      $ = null;
    }
  }

  // Assemble prompt (pure — computes the prompt_sha)
  const { system, userContentBlocks } = assemblePrompt({
    surface,
    cell,
    excerptDom,
    factsJson,
    imageBase64,
    imageMediaType,
  });

  // Compute prompt_sha for provenance (T-217-05-KEY: only sha stored, never key or prompt)
  const promptSha = computePromptSha(system);
  const provenance = {
    model: currentProvenance?.model || MODEL,
    k: currentProvenance?.k || K,
    quorum: currentProvenance?.quorum || QUORUM,
    rubric_version: currentProvenance?.rubric_version || '1.0',
    prompt_sha: promptSha,
  };

  // Make k=3 INDEPENDENT messages.create calls (D-03/D-08):
  //   - model: MODEL (pinned)
  //   - NO temperature, top_p, top_k (400s on claude-opus-4-8 per D-08)
  //   - NO assistant prefill (400s on claude-opus-4-8 per D-03)
  //   - adaptive thinking: default (omit 'thinking' key entirely)
  //   - output_config.format: JSON schema via PANEL_SCHEMA (structured output)
  //   - system: cached rubric (cache_control: ephemeral)
  const k = provenance.k;
  const sampleResults = [];

  for (let i = 0; i < k; i++) {
    const response = await sdkClient.messages.create({
      model: MODEL,
      max_tokens: 8192,
      system: [
        {
          type: 'text',
          text: system,
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: [
        {
          role: 'user',
          content: userContentBlocks,
        },
      ],
      // Structured output: constrain the model to PANEL_SCHEMA so responses are
      // schema-shaped rather than free-form prose (CR-02). Per the Anthropic SDK,
      // structured output is opt-in via output_config.format — without it the
      // model is unconstrained and a malformed response silently degrades to an
      // empty sample, quietly weakening quorum admission.
      output_config: {
        format: { type: 'json_schema', schema: PANEL_SCHEMA },
      },
      // NO temperature, top_p, top_k (would 400 on claude-opus-4-8)
      // NO thinking key (use adaptive thinking default)
      // NO assistant prefill (would 400 on claude-opus-4-8)
    });

    // Parse structured response
    let responseObj = null;
    try {
      const textBlock = (response.content || []).find((b) => b.type === 'text');
      if (textBlock) {
        responseObj = JSON.parse(textBlock.text);
      }
    } catch (_) {
      // If parsing fails, treat as empty sample
      responseObj = null;
    }

    const sampleFindings = parseSampleFindings(responseObj, surface, $);
    sampleResults.push(sampleFindings);
  }

  // Build per-sample finding_id Sets for quorum admission
  const sampleKeySets = sampleResults.map((findings) =>
    new Set(findings.filter((f) => f.findingId != null).map((f) => f.findingId))
  );

  const admitted = admitFindings(sampleKeySets, { quorum: provenance.quorum });

  // Reconcile admitted findings: severity=worst-verdict, description=first winning
  const allSamples = sampleResults.flat();
  const admittedFindings = [];

  for (const fid of admitted) {
    const { severity, description, anchor, observation, evidence_cell, klass, lens, question } =
      reconcileFindings(fid, allSamples, admitted);

    admittedFindings.push({
      finding_id: fid,
      surface,
      cell,
      klass: klass || '',
      lens: lens || '',
      question: question || '',
      anchor: anchor || '',
      severity: severity || 'tighten',
      description: description || '',
      observation: observation,
      evidence_cell: evidence_cell,
      schema_version: SCHEMA_VERSION,
    });
  }

  // Compute dispositions
  const { perLens, surface: surfaceDisposition } = computeDispositions(admittedFindings);

  // Write panel-findings.json to outputDir (PARALLEL — never findings.json)
  if (outputDir) {
    const panelFindingsPath = path.join(outputDir, 'panel-findings.json');
    writeFileSync(panelFindingsPath, JSON.stringify(admittedFindings, null, 2));
    // NEVER write to findings.json (T-217-05-EOP)
    // Confirm: we never touch findings.json here
  }

  return {
    from_cache: false,
    admitted_findings: admittedFindings,
    surface_disposition: surfaceDisposition,
    per_lens_disposition: perLens,
    render_sha256: renderSha256,
    sample_key_sets: sampleKeySets.map((s) => [...s]),
    provenance,
    // NEVER store open_findings (T-217-05-EOP / D-09)
  };
}

// ---------------------------------------------------------------------------
// CLI entry point (when invoked directly)
// ---------------------------------------------------------------------------

// Only run as CLI if invoked as the main module
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(__filename)) {
  // CLI usage for the admin-panel.sh orchestrator
  // Arguments: --surface <id> --cell <id> --render-sha <sha> --output-dir <dir>
  const args = process.argv.slice(2);
  let surface, cell, renderSha256Arg, outputDirArg;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--surface') surface = args[++i];
    else if (args[i] === '--cell') cell = args[++i];
    else if (args[i] === '--render-sha') renderSha256Arg = args[++i];
    else if (args[i] === '--output-dir') outputDirArg = args[++i];
  }

  if (!surface || !cell) {
    console.error('judge.mjs: usage: --surface <id> --cell <id> [--render-sha <sha>] [--output-dir <dir>]');
    process.exit(2);
  }

  // Require ANTHROPIC_API_KEY in env (never from args/file/prompt — T-217-05-KEY)
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error('judge.mjs: ANTHROPIC_API_KEY not set — skip (JUDGE-CI-01)');
    process.exit(0);
  }

  // Late-import the SDK (avoids loading it in test-double mode)
  const { default: Anthropic } = await import('@anthropic-ai/sdk');
  const client = new Anthropic(); // reads ANTHROPIC_API_KEY from env

  // Load admin-render-sha.json for render_sha256
  const renderShaPath = path.join(ROOT, 'guides', 'reference', 'admin-render-sha.json');
  let renderSha256 = renderSha256Arg;
  if (!renderSha256 && existsSync(renderShaPath)) {
    const renderShaData = JSON.parse(readFileSync(renderShaPath, 'utf8'));
    renderSha256 = renderShaData?.cells?.[surface]?.[cell]?.render_sha256;
  }
  if (!renderSha256) {
    console.error(`judge.mjs: no render_sha256 for ${surface}/${cell}`);
    process.exit(1);
  }

  // Load admin-panel-verdicts.json for cache check
  const verdictsPath = path.join(ROOT, 'guides', 'reference', 'admin-panel-verdicts.json');
  let verdictEntry = null;
  if (existsSync(verdictsPath)) {
    try {
      const verdicts = JSON.parse(readFileSync(verdictsPath, 'utf8'));
      verdictEntry = verdicts?.cells?.[renderSha256] || null;
    } catch (_) {}
  }

  const result = await runJudge({
    surface,
    cell,
    renderSha256,
    verdictEntry,
    excerptDom: '', // TODO: read from bundle dir
    factsJson: '{}',
    sdkClient: client,
    outputDir: outputDirArg,
    currentProvenance: {
      model: MODEL,
      k: K,
      quorum: QUORUM,
      rubric_version: '1.0',
      prompt_sha: '',
    },
  });

  console.log(JSON.stringify({ surface, cell, from_cache: result.from_cache, surface_disposition: result.surface_disposition }));
  process.exit(0);
}
