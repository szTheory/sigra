# Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1 - Pattern Map

**Mapped:** 2026-09-20  
**Files analyzed:** 14 planned new/modified files  
**Analogs found:** 14 / 14 (all analogs below are tracked sources)

## File Classification

| New/Modified File | Role | Data flow | Closest tracked analog | Match quality |
|---|---|---|---|---|
| `.github/workflows/hex-remediate-phantom.yml` | config/workflow | event-driven + request-response | `.github/workflows/hex-publish.yml` | role-match |
| `scripts/ci/hex-remediation-verify.sh` | utility/script | request-response + transform | `scripts/ci/release-post-publish-verify.sh` | role-match |
| `scripts/ci/hex-remediation-verify.test.sh` | test | batch | `scripts/ci/wait-for-ci-gate.test.sh` | role-match |
| `scripts/ci/prohibitions/p22-hex-remediation.test.mjs` | test | transform | `scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs` | role-match |
| `test/fixtures/prohibitions/p22-hex-remediation-*.yml` | test fixture | transform | `test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml` | exact |
| `.planning/phases/242-.../242-HEX-REMEDIATION-EVIDENCE.md` | evidence artifact | request-response | `.planning/phases/241-.../241-06-EVIDENCE.md` | role-match |
| `.planning/decisions/005-hex-retirement-and-safe-install-constraints.md` | ADR | transform | `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` | exact |
| `README.md` | documentation | request-response | `guides/introduction/installation.md` | role-match |
| `guides/introduction/installation.md` | documentation | request-response | current file's three-segment rationale | exact |
| `guides/introduction/troubleshooting-install.md` | documentation | request-response | current “Symptom / Fix” sections | exact |
| `CHANGELOG.md` | documentation/config | transform | its top-level Unreleased warning + 1.5.0 section | exact |
| `mix.exs` | config/documentation index | transform | `mix.exs:184-185,206-285` | exact |
| `test/sigra/planning/phase_242_hex_remediation_contract_test.exs` | test | transform | `test/sigra/planning/phase_146_release_validation_test.exs` | exact |
| `test/fixtures/prohibitions/p22-*.{yml,json,md}` | test fixture | transform | `test/fixtures/prohibitions/p18-ratchet-r*-exceeded.tsv` | role-match |

The exact Phase-242 names for the script/fixtures/tests are planner choices; these classifications cover the required roles from CONTEXT and RESEARCH. Do not plan edits to generated `doc/` output: it is not tracked. The tracked documentation index is `mix.exs` (`docs.extras`), while `docs/`, `README.md`, and `CHANGELOG.md` are the packaged-docs surface.

## Pattern Assignments

### `.github/workflows/hex-remediate-phantom.yml` (workflow, dispatch-only mutation lane)

**Analog:** `.github/workflows/hex-publish.yml`

**Dispatch and least-privilege pattern** (lines 7-31):

```yaml
name: Hex publish (manual recovery)

on:
  workflow_dispatch:
    inputs:
      tag:
        required: true

permissions:
  contents: read

concurrency:
  group: hex-publish-${{ inputs.tag }}
  cancel-in-progress: false
```

For remediation, keep `workflow_dispatch` but expose **no package/version input**: hard-code `sigra` and `1.20.0`. Retain `contents: read`, do not add checkout/commit authority, and use a fixed concurrency group with `cancel-in-progress: false` so two writes cannot race.

**Strict shell failure and pinned setup actions** (lines 72-110):

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    ref: ${{ inputs.tag }}
    fetch-depth: 0

- uses: erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124 # v1.24.1
  with:
    version-file: .tool-versions
    version-type: strict
```

The remediation workflow need not checkout for public `curl` captures, but if it invokes the committed helper it should use the same fully pinned actions. The release action-pinning contract accepts only full lowercase SHAs with same-line version comments (`test/sigra/planning/phase_234_action_pinning_contract_test.exs:29-36,80-104`).

**Step-scoped credential pattern** (lines 177-187):

```yaml
- name: Publish to Hex
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  run: mix hex.publish --yes
```

Bind `HEX_API_KEY` only to the retire and docs-only-revert steps. Never put it in workflow/job `env`, dispatch inputs, command interpolation, evidence, uploaded public artifacts, or diagnostics. Preflight only for non-empty presence without echoing it; no `set -x`.

**Release-specific footgun:** `.github/workflows/release-please.yml:19-23` intentionally has broad release-management permissions. Do not copy them: the new workflow is a remediation reader/writer against Hex only. Also do not add a second publisher; ADR 003 says publishing is Release-Please-driven and the only recovery publisher requires explicit version/ref provenance (`.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md:27-35`).

### `scripts/ci/hex-remediation-verify.sh` (read-only public evidence and resolver verifier)

**Analog:** `scripts/ci/release-post-publish-verify.sh`

**Argument validation and bounded defaults** (lines 4-10,27-78):

```bash
PACKAGE="sigra"
VERSION=""
TAG=""
EVIDENCE_FILE="release-post-publish-evidence.json"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-36}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"

if [[ -z "$VERSION" || -z "$TAG" ]]; then
  echo "--version and --tag are required" >&2
  exit 2
fi
```

Use fixed defaults/literals for package and phantom version, explicit options only for safe output paths/test overrides, and `set -euo pipefail`. Reject invalid invocation before network work.

**Sanitized JSON receipt and bounded propagation** (lines 80-118):

```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -fsS "$HEX_RELEASE_URL" -o "$TMP_DIR/hex-release.json" &&
    grep -q "\"version\"[[:space:]]*:[[:space:]]*\"${VERSION}\"" "$TMP_DIR/hex-release.json"; then
    break
  fi
  if [[ "$attempt" -eq "$MAX_ATTEMPTS" ]]; then
    write_evidence "failed" "hex_release_not_visible"
    exit 1
  fi
  sleep "$WAIT_SECONDS"
done
```

Copy the bounded/fail-closed style, but project a public allowlist with `jq` rather than retain raw response files: `name`, `latest_version`, `latest_stable_version`, `retirements`, and selected release `{version, has_docs}`. Capture `BEFORE`, `AFTER_RETIRE`, and `AFTER_DOCS_REVERT` as separate slots; then separately record root HexDocs HTTP/title/source observation. Never imply API/default-doc behavior from a mutation.

**Fresh consumer proof:** make one temporary project and fresh `HEX_HOME`/`MIX_HOME` per case, run with `env -u HEX_IGNORE_RETIREMENTS`, assert lock selection and warning facts, then write only those facts. A lockfile/cache from the repository is not evidence of consumer resolution.

### Structural workflow guard and known-bad fixtures (test, transform)

**Analogs:** `scripts/ci/prohibitions/_lib.mjs`; `test/sigra/planning/phase_234_action_pinning_contract_test.exs`; `test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml`

**Subject injection + non-vacuity** (`scripts/ci/prohibitions/_lib.mjs:32-37,70-77`):

```javascript
export function subjectPath(defaultRelPath) {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected && injected.length > 0) return resolve(injected);
  return resolve(REPO_ROOT, archiveAwareRelPath(defaultRelPath));
}

export function readSubject(defaultRelPath) {
  const p = subjectPath(defaultRelPath);
  if (!existsSync(p)) {
    throw new Error(`subject not found at ${p} — a missing subject is a broken run, never an absent violation`);
  }
  return readFileSync(p, 'utf8');
}
```

Use one substitutable workflow subject and force failure when parsing finds no jobs/steps or a required boundary. Strip YAML comments before semantic token checks (`_lib.mjs:115-145`). Test both green source and independently targeted bad fixtures: a broadened dispatch input, permissions beyond `contents: read`, secret outside exactly two mutation steps, mutable action pin, `mix hex.publish --revert` (package), raw API output, and absent required causal slot.

**Structural ExUnit assertions** (`test/sigra/planning/phase_146_release_validation_test.exs:34-70`):

```elixir
release_please = read!(".github/workflows/release-please.yml")
hex_publish = read!(".github/workflows/hex-publish.yml")

for workflow <- [release_please, hex_publish] do
  assert workflow =~ "mix docs --warnings-as-errors"
  assert workflow =~ "mix hex.build --unpack --output sigra-hex-inspect"
  assert workflow =~ "scripts/ci/release-post-publish-verify.sh"
end
```

Follow this test's `root/0` + `read!/1` helpers and assert meaningful complete contracts, not bare grep/count checks. For fragile YAML shape parsing, use `jobBlock()` from `_lib.mjs:87-112` and exact job scopes.

**Known-bad direction:** fixtures must demonstrably make the guard red. The pinning contract tests a real fixture and asserts its line-specific diagnostic (`phase_234_action_pinning_contract_test.exs:164-184`); Phase 241 evidence records a RED fixture first, then real-tree GREEN (`241-06-EVIDENCE.md:9-21`).

### `.planning/phases/242-.../242-HEX-REMEDIATION-EVIDENCE.md` (evidence artifact)

**Analog:** `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-06-EVIDENCE.md`

**Evidence organization** (lines 5-21,23-45):

```markdown
## Deliberately distinct instruments

The doc-range hard fail and R1 cover the same HexDocs-rendering surface but answer different questions.

## Doc-range fixture RED and real-tree GREEN

Captured RED: non-zero as required ...

Captured GREEN: ...
```

Make the artifact a fixed-schema, committed receipt: metadata (`captured_at`, source URLs, workflow run URL/SHA), then `BEFORE`, `AFTER_RETIRE`, `AFTER_DOCS_REVERT`, `HEXDOCS_ROOT`, `RESOLVER_BROAD`, and `RESOLVER_SAFE`. Each observed slot says what was fetched/projected, not what the planner expects. Include reproducible non-secret commands and actual results; never copy raw headers, request details, environment, token-like strings, or protected workflow logs.

### `.planning/decisions/005-hex-retirement-and-safe-install-constraints.md` (ADR)

**Analog:** `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md`

**Header and decision structure** (lines 1-31):

```markdown
# ADR 004: TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology

**Status:** Accepted
**Date:** 2026-09-19
**Context:** Phase 241 ...

## The problem

## Decision

## Replacement guarantee
```

Use ADR number **005**, not 004. Record the safe `{:sigra, "~> 1.5.0"}` constraint, retirement's advisory/non-resolver effect, immutable package vs independently reversible docs, and the *measured* docs-revert result. Preserve ADR 003's ownership boundary rather than amending it. If a current actionable record makes the obsolete “retirement fixes latest” claim, correct it with dated, explicit prose; do not rewrite historical evidence.

### Adopter docs: `README.md`, `guides/introduction/installation.md`, `guides/introduction/troubleshooting-install.md` (documentation, request-response)

**Analogs:** `README.md:73-79`; `guides/introduction/installation.md:18-40`; `guides/introduction/troubleshooting-install.md:35-46`

**Copy/paste install line and explanatory boundary** (`guides/introduction/installation.md:18-40`):

```markdown
## Add the dependency

Add `:sigra` to `deps/0` in `mix.exs`:

    {:sigra, "~> 1.4.0"}

The three-segment requirement is deliberate. An erroneous `1.20.0` was published to
Hex ... a two-segment `~> 1.4` would still admit it.
```

Replace relevant source occurrences with the required `{:sigra, "~> 1.5.0"}` and update the explanation to the 1.5 line. Retain concise consumer language: retirement warns but does not make a broad requirement unresolvable; do not expose remediation implementation in normal install prose. Search tracked documentation sources before release so old two-segment `{:sigra, "~> 1.5"}` does not survive.

**Troubleshooting layout** (`guides/introduction/troubleshooting-install.md:35-46`):

```markdown
## Upgrading between Sigra versions

**Symptom:** You are on an older **`{:sigra, ...}`** line and want a safe bump.

**Fix:**

1. Read **`CHANGELOG.md`** ...
2. Use the planning-milestone upgrade pages ...
```

Use the same Symptom/Fix framing only if an install/recovery clarification belongs there. Do not add `.planning/` operational proof links to `README.md` or other packaged docs.

### `CHANGELOG.md` and `mix.exs` (release metadata and docs index)

**Analogs:** `CHANGELOG.md:12-22`; `mix.exs:184-185,206-285`

**Manual Unreleased fold contract**:

```markdown
## Unreleased

<!--
MAINTAINER WARNING — Release Please inserts each generated version section BELOW this
block, never into it. Anything written here must be folded by hand into the new version
section while the Release PR is still open.
-->

## [1.5.0](https://github.com/szTheory/sigra/compare/v1.4.0...v1.5.0) (2026-08-31)
```

Fold the hand-written material into 1.5.1 before release PR #224 merges. Preserve the warning block and Release Please ownership; do not leave corrective release notes under Unreleased.

**Packaged/docs-index boundary**:

```elixir
files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
...
source_ref: "v#{@version}",
...
extras: [
  "README.md",
  "CHANGELOG.md",
  "guides/introduction/installation.md",
  "guides/introduction/troubleshooting-install.md",
]
```

`mix.exs:184-185` defines package contents; `mix.exs:206-285` defines HexDocs indexing. Refresh the tracked documentation index/version-generated material that is truly source-controlled, but never commit ignored generated `doc/` output. Keep `source_ref: "v#{@version}"` unchanged: Release Please's checks require it (`.github/workflows/release-please.yml:208-210`).

## Shared Patterns

### Trusted release provenance

**Source:** `.github/workflows/release-please.yml:96-134,179-210`

```yaml
gate-ci-green:
  needs: release-please
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  permissions:
    actions: write
    contents: read

publish-hex:
  needs: [release-please, gate-ci-green]
  if: ${{ needs.release-please.outputs.release_created == 'true' }}
  permissions:
    contents: read
```

Apply to 1.5.1 only: release output SHA must receive the existing exact-SHA green gate before the existing publish job. Do not substitute remediation-workflow success for this requirement.

### Public evidence / secret boundary

**Sources:** `scripts/ci/release-post-publish-verify.sh:83-101`; `.github/workflows/hex-publish.yml:177-187`

```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
```

```yaml
env:
  HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
```

Keep sensitive runtime data in temporary files and publish only intentionally projected public facts. The evidence schema should itself reject raw dumps/token-shaped content. Never use shell trace mode around protected steps.

### Fail-closed verification and fixtures

**Sources:** `scripts/ci/wait-for-ci-gate.sh:26-35,111-113`; `scripts/ci/prohibitions/_lib.mjs:70-77`

```bash
[[ -n "$RUNS_JSON" ]] || fail "gh run list returned empty output -- the parse broke, this is not a pass"
echo "$RUNS_JSON" | jq -e 'type == "array"' >/dev/null 2>&1 \
  || fail "run list payload is not a JSON array -- the parse broke, this is not a pass"
```

Missing input, empty parse results, absent public evidence, or a non-proven mutation must fail—not render a green no-op. Include known-bad fixtures with expected specific diagnostics.

### Packaged-docs ratchet

**Source:** `scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs:90-117,133-135`

```javascript
const stdout = execFileSync('git', ['ls-files', 'docs', 'README.md', 'CHANGELOG.md'], {
  cwd: REPO_ROOT,
  encoding: 'utf8',
});
...
assert.ok(measured <= baseline, `P18 RATCHET REGRESSION ${counter}: ...`);
```

Phase 242's CHANGELOG fold is expected to decrease R3. Keep the counters independent, do not widen the scan to guides, and do not use an R3 decrease to permit any unrelated release/docs regression.

## No Analog Found

| File/capability | Role | Data flow | Planning direction |
|---|---|---|---|
| Hex-specific retire + docs-only-revert command sequence | workflow/script | event-driven | No existing implementation (correctly): compose it from the manual publisher's trust boundary and the research-approved official Hex commands. |
| Three-boundary Hex API + root-docs receipt | evidence capture | request-response | No exact repository analog: preserve the existing bounded, fail-closed JSON-receipt style while adding fixed required slots. |
| Fresh retired-versus-safe resolver proof | integration script | batch | No existing analog: create isolated homes/projects and assert lock plus warning facts; do not generalize from a repository lockfile. |

## Release Footguns to Carry into Plans

- `HEX_API_KEY` is protected external authority. Its exact client/OTP behavior is an intentional live checkpoint; fail closed without an interactive fallback and never echo it.
- `mix hex.publish docs --revert 1.20.0` is the only allowed revert. A package-tarball `mix hex.publish --revert` is out of scope and must be structurally rejected.
- Retirement is advisory. A broad fresh resolver may still select `1.20.0`; do not claim it restores `latest_stable_version` or makes the version unavailable without an observed receipt.
- Third-party workflow actions require immutable full-SHA pins plus same-line semantic version comments. New workflow files may need inclusion in the release-critical pin contract's explicit universe if the contract's scope is broadened.
- The remediation workflow must not acquire repository write authority or commit evidence. Commit sanitized evidence separately after reviewing only public projections.
- Release 1.5.1 remains Release Please-owned: exact SHA gate, tag/version/manifest checks, package inspection, and tagged HexDocs source-link verifier are all required.
- `docs/`, `README.md`, and `CHANGELOG.md` ship in the Hex tarball; `guides/` are rendered as ExDoc extras but not tarball files. Generated `doc/` files are ignored and must not be treated as source/index edits.

## Metadata

**Analog search scope:** `.github/workflows`, `scripts/ci`, `scripts/ci/prohibitions`, `test/sigra/planning`, `test/fixtures/prohibitions`, `.planning/decisions`, Phase 241 artifacts, release/docs sources  
**Files scanned:** 19 tracked analogs plus Phase 242 context/research  
**Pattern extraction date:** 2026-09-20
