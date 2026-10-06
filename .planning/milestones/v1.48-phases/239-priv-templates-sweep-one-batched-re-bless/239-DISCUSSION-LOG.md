# Phase 239: `priv/templates/` Sweep + One Batched Re-bless - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-09-17
**Phase:** 239-priv-templates-sweep-one-batched-re-bless
**Mode:** assumptions
**Areas analyzed:** Sweep token set and scope; SC-2 tarball scope; Golden re-bless mechanics;
SC-1 verification vehicle; Rationale preservation; Commit topology and `test/example/` mirror

## Assumptions Presented

### A. Sweep token set and scope

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Hard-fail set spans all three generators = 154 token lines / 45 files, not the 1 line SC-1 names | Confident (counts) | `priv/templates/sigra.install/organizations/organizations.ex:59`; `sigra.upgrade/alter_add_owner_user_id.exs:3`; `sigra.install/core/user_auth.ex:32`; `organizations/migration.exs:16`; measured `grep -rcE` over `priv/templates/` |
| Boundary exclusions: `admin/policy.ex:17` `# TODO:`, `XXXX-XXXX` placeholders, `sigra_auth.css:156` v1.46 compat prose, `core/scope.ex:22` `UPGRADE-v1.2.md` (real shipped guide) | Likely | `ROADMAP.md` Scope Discipline — "everything under `priv/templates/`" hard-fail tier, no incidental exemption |

**Alternatives considered:** (1) keep the 98 `D-NN` ids and strip only phase/plan/artifact refs
(154 → ~56 lines, but leaves the largest class shipping); (2) strip everything including `TODO:`
and the v1.46 note (deletes an adopter-useful instruction and a real upgrade signal).

### B. SC-2 tarball scope

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| SC-2 verified as `grep -rn '.planning/' <unpacked>/lib <unpacked>/priv` → 0, not whole-tarball | Confident (measurements) / Likely (scoping call) | Real tarball built and unpacked (`mix hex.build --unpack`, Hex 2.4.2, v1.5.0): `lib/` 0, `priv/` 1, `docs/` 12, `README.md` 1, `CHANGELOG.md` 19, `mix.exs` 0 |
| The tarball is the vehicle, not the scope | Likely | `REQUIREMENTS.md:82` SURF-01 scopes to "`lib/` or `priv/templates/` — verified by grepping…"; `docs/nyquist-posture-matrix.md:11` says the path is not in the tarball; `CHANGELOG.md:10` is deliberate; `CHANGELOG.md` is Phase 242's file (REL-05) |
| Real `files:` list; `priv/templates/` ships in full (119 files) | Confident | `mix.exs:184`; `priv/templates/.DS_Store` gitignored at `.gitignore:39`, untracked, correctly absent |

**Alternative considered:** whole-tarball grep with a committed allowlist of the 32 deliberate
sites — more honest and gives `p18` a second fixture class, but more maintenance and it brushes
Phase 242's `CHANGELOG.md`.

### C. Golden re-bless mechanics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fixture is a byte-for-byte directory-tree snapshot (85 files / 760K); every template comment edit mirrors as a comment line and nothing else | Confident | `lib/mix/tasks/sigra.fixture.rebless_golden.ex:92-103`; `test/sigra/install/golden_diff_test.exs:14-26` |
| `--check` → exit 0 = no drift, `exit({:shutdown, 2})` = drift; task does not stage or commit | Confident | `rebless_golden.ex:19-20,60-65,115-140` |
| Expected diff = 133 token lines / 33 golden files | Confident | golden tree carries the same leakage today, incl. `tree/lib/sigra_install_golden_tmp/organizations.ex:59` |
| ~15 tokens sit inside HEEx `~H` sigils — removing one can change rendered output (stop-the-line risk) | Confident | `core/settings_live.ex:66,77,107,159`; `core/mfa_challenge_live.ex:290,297`; `organizations/live/organization_settings_live.ex:60,69,117` |
| `sigra_auth.css` copied verbatim into the golden tree; `STDOUT.txt` can drift independently | Confident | `sigra_auth.css:156,515,699,706,733` → `tree/priv/static/assets/sigra_auth.css` |
| No DB needed for the re-bless itself | Likely | `test/support/install_fixture.ex:15-27` (`--no-assets --no-install`); `mix.exs:161-163` shows DB is needed only for the alias's other members |

### D. SC-1 verification vehicle

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| SC-1's fresh app comes from `scripts/ci/install-smoke.sh`, grepped in place — not `admin-acceptance-smoke.sh`, not the golden fixture | Confident | `install-smoke.sh:1-22,23-26`; `admin-acceptance-smoke.sh:1-40` (boots server + Playwright at `PORT=4017`) |
| `ci.yml:450` change-detector omits `priv/templates/sigra.upgrade/` and `sigra.gen.oauth/` — a real skip hazard; todo, not an in-phase fix | Confident | `.github/workflows/ci.yml:450`; Standing Constraint 4 |

### E. Rationale preservation

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `# SECURITY:` occurs zero times in `priv/templates/`; reuse 237's proven-RED regex-class script | Confident | `grep -rn "SECURITY:" priv/templates/` → 0; `237-CONTEXT.md` D-04; `237-security-comment-diff-check.sh:16-18,24-26,47-50,64-65` |
| 23 of 154 lines need rewrite (token out, sentence in); 5 same-line co-occurrences | Confident | `organization_switch_controller.ex:10`; `reset_password_controller.ex:21`; `router_injection.ex:1`; `invitation_accept_live.ex:3`; `scope.ex:70`; plus `organization_invitation_email.ex:12` |

### F. Commit topology, mirror set, Phase 241 handoff

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Three commits: sweep → mirror → re-bless; mirror must not share the re-bless commit | Confident | `REQUIREMENTS.md:84` SURF-03 ("one sweep plus one batched re-bless, in separate commits"); `rebless_golden.ex:19-20` |
| 27 of 45 edited templates have a `test/example/` counterpart by filename | Confident | mapping enumerated in CONTEXT D-20 |
| 4 counterparts renamed and need hand-mapping; `login_html.ex`→`session_html.ex` unverified | Likely | `error_handler.ex`→`auth_error_handler.ex`; `core/auth.ex`→`accounts.ex`; the two migrations |
| 10+ have no counterpart — a real coverage gap = FUT-01's diagnosis, filed as a todo | Confident | several (`mfa_challenge_html.ex`, `token_controller.ex`) do appear in the golden tree |
| Sweep must be path-restricted at the command level; `.github/` carries 114 tokens a repo-wide sed would hit | Confident | `ci.yml` 93 lines (`:442`, `:726`, `:1560`), `ci-observe.yml` 8, `release-please.yml` 5, `ci-skip-manifest.tsv` 8 |
| `p18` slot is free; 239 builds no guard and leaves `test/fixtures/prohibitions/` untouched | Confident | `scripts/ci/prohibitions/` holds `p01`…`p17` and `p19-tag-namespace-ruleset.test.mjs` |

## Stale / Incomplete ROADMAP Claims Identified

1. **SC-1's framing is true but ~1.5% of the surface.** One literal `.planning/` path exists
   (verified count = 1), but Scope Discipline puts all of `priv/templates/` in the hard-fail tier
   = 154 lines / 45 files. A plan written to SC-1's literal text would strip one line and declare
   victory.
2. **SC-2 as literally written is unsatisfiable** without invading Phase 242's `CHANGELOG.md`.
   32 further `.planning/` references live in `docs/` (12), `README.md` (1), `CHANGELOG.md` (19),
   all outside SURF-01's scope and all deliberate.
3. **SC-5's `# SECURITY:` marker does not exist in `priv/templates/`** (count = 0) — exactly as
   Phase 237 already found repo-wide. Reuse 237's instrument; do not re-decide.
4. **Skip hazard adjacent to SC-3:** `ci.yml:450` omits two of the three generator directories.
5. `priv/templates/.DS_Store` exists on disk, is gitignored, untracked, correctly absent from the
   tarball (119 shipped vs 120 on disk). No action.

## Corrections Made

No corrections — all assumptions confirmed. Two escalation-threshold calls were surfaced explicitly
(the sweep's token breadth in Area A, and SC-2's scoping in Area B), each with its rejected
alternative presented; the user took the recommended set as-is.

## External Research

None performed. Every question was answerable from the repository, the built tarball, and the
installed toolchain (`phx_new-1.8.8`, Hex 2.4.2, Elixir 1.19.5, OTP 28.5).
