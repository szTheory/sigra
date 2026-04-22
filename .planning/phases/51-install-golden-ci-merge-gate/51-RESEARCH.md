# Phase 51 — Technical research: install golden receipt & CI merge coupling

**Question:** What do we need to know to plan Phase 51 well?

## Source problems (from `v1.4-MILESTONE-AUDIT.md`)

1. **PHASE-50-INSTALL-GOLDEN** — `50-VERIFICATION.md` is still `status: draft` with no recorded green run of `mix ci.install_golden` / equivalent.
2. **CI-PATH-COUPLING** — `install_golden_contract` (and the sibling `installer_milestone_audit` detector) only diff-match `^priv/templates/sigra.install/` and `^lib/sigra/install/`. PRs that touch **`lib/sigra/mfa/`**, **`lib/sigra/oauth/`**, **`lib/sigra/account/`**, or **`lib/sigra/passkeys/`** (GA-relevant surfaces) can merge **without** running the installer subprocess harness, even though generated templates and install features can drift from those codepaths.
3. **GA-WAIVERS-vs-INSTALL-RECEIPT** — GA-03 / GA-04 rows in `v1.4-GA-UAT.md` cite OAuth machine tests and getting-started contracts; they do not explicitly tie **installer golden** as the subprocess receipt when reasoning about template/install drift for waived live-smoke items.

## Current wiring (verified)

| Artifact | Behavior |
|----------|----------|
| `mix.exs` → `"ci.install_golden"` | Runs `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` |
| `.github/workflows/ci.yml` → `install_golden_contract` | Same two test files as `mix test …`; PR path gate identical to `installer_milestone_audit` (lines 46–50 vs 82–86) |
| `library_tests` | Full `mix test` — includes install tests **when** the default test set loads them; heavy PRs still benefit from an explicit install-golden job when path gate skips `install_golden_contract` |
| `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` | Asserts `50-VERIFICATION.md` contains `status: draft` — **must be relaxed or updated** when a real PASS receipt lands |

## Design constraints

- **Cost:** Expanding the path regex increases how often PRs pay for `phx_new` archive + tmp scaffold work; keep the extension to **GA-adjacent lib subtrees** named in the audit, not all of `lib/sigra/`.
- **Consistency:** Both `installer_milestone_audit` and `install_golden_contract` should use the **same** `git diff … \| grep -qE` pattern so behavior cannot diverge silently.
- **Observability:** `50-VERIFICATION.md` must gain a grep-able **`PASS`** token in the results table plus wall-clock timing when green, per ROADMAP acceptance (1).

## Recommended approach

1. **Single extended regex** (documented in YAML comments + `MAINTAINING.md`) appended to the existing two prefixes, e.g. add:
   - `^lib/sigra/mfa(\.ex|/)`
   - `^lib/sigra/oauth(\.ex|/)`
   - `^lib/sigra/account(\.ex|/)`
   - `^lib/sigra/passkeys(\.ex|/)`
2. **Structural ExUnit** (new file under `test/sigra/planning/`) asserting both jobs’ detect blocks contain the same pattern string (or shared comment contract) — mirrors phase 50’s `phase_50_nyquist_docs_contract_test.exs` style.
3. **50-VERIFICATION.md** — executor records real `PASS` + duration + `git rev-parse HEAD` after a green `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden`; flip frontmatter `status: passed` when appropriate.
4. **GA waiver cross-link** — one short paragraph in `MAINTAINING.md` (installer golden section) **and/or** a footnote row in `v1.4-GA-UAT.md` pointing GA-03/GA-04 readers at **`mix ci.install_golden` / `install_golden_contract`** as the installer subprocess substitute for template drift (without re-litigating waiver decisions).

## Risks / pitfalls

- **Regex false negatives:** Files only under `lib/sigra/auth.ex` etc. would still skip the job — acceptable unless audit expands scope; document “explicit list” rationale in MAINTAINING.
- **Test brittleness:** Duplicated long regex in two workflow jobs — mitigate with ExUnit asserting both copies match.
- **50-VERIFICATION test:** Changing `status: passed` without updating `phase_50_nyquist_docs_contract_test.exs` breaks CI.

## Validation Architecture

Phase 51 validates **CI YAML structure + documentation contracts + optional merge-gate execution**, not product auth logic.

| Dimension | Strategy |
|-----------|----------|
| **Automated structure** | New `test/sigra/planning/phase_51_*_test.exs` (or extend phase 50 file with renamed test) — grep workflow jobs, assert extended path list, assert `50-VERIFICATION` contains `PASS` when `status: passed` |
| **Merge gate** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden` — run once before flipping `50-VERIFICATION` frontmatter (may use CI run URL / run id as receipt if local impractical — document honestly in Notes) |
| **Docs** | `grep -E 'PASS|mix ci.install_golden'` on `50-VERIFICATION.md`; `MAINTAINING.md` cites expanded PR path policy |

Sampling: after each task touching YAML or verification docs, run `mix test test/sigra/planning/phase_51_*` (fast) and spot-check `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` until updated.

---

## RESEARCH COMPLETE
