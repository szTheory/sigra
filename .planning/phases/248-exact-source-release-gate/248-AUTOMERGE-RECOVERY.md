# Phase 248 auto-merge recovery

The first Release Please candidate evaluation after Phase 248 merged was correctly
refused by the trusted auto-merge workflow (run `37869293110`). The workflow copied
the full Phase 247 readiness ledger from the default-branch checkout, but that
4.9 MB ledger was only present in the original local planning workspace and was
not committed to `main`. The failure was an unavailable evidence file; CI and the
release credential preflight had passed.

The first recovery evaluation (run `37873009573`) then verified the approved source
blobs but rejected the release candidate because its generated changelog omitted
the curated Phase 247 adopter summaries. Those user-facing notes are now added to
the versioned 1.6.0 section, and the fixture uses the same candidate wording.

The recovery keeps the original Phase 247 approval bound to candidate
`0e773d3614a242e4fbcdd34c418ecb8a307703d6`. A compact claim manifest records the
ledger digest, source CI and Hex dry-run run IDs, approved source blob IDs, and
the source-backed release-note claims. On every initial and final candidate read,
the workflow fetches those blob IDs as data at the exact Release Please PR head.
The preflight rejects any changed or missing source file, then still requires a
successful CI push run and `ci-gate` whose full SHA equals the single open
Release Please PR head. It never checks out or executes candidate PR code. The
final fresh read and `--match-head-commit` squash merge remain in place.

Local validation before submitting the recovery change:

- `bash scripts/ci/release-candidate-preflight.test.sh` — 27 passed, including the repository's real 1.6.0 changelog section.
- `bash scripts/ci/release-observer.test.sh` — 22 passed.
- `bash scripts/ci/release-receipt.test.sh` — 15 passed.
- `bash scripts/ci/release-environment-preflight.test.sh` — 9 passed.
- `bash scripts/ci/release-exact-source.test.sh` — passed.
- `bash scripts/ci/wait-for-ci-gate.test.sh` — 15 passed.
- `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs` — 10 passed.
- `actionlint -shellcheck=0` on the five release workflows and `shellcheck` on both changed helper scripts — passed.
- All seven source blob IDs equal the Git blob IDs at the approved Phase 247 candidate; the source ledger digest also matches the local Phase 247 artifact.
- Hosted CI and the next automatic release evaluation — pending.
