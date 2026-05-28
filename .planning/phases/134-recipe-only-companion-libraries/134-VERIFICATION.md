---
phase: 134-recipe-only-companion-libraries
verified: 2026-05-28T14:38:48Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: "Initial verification. Phase passed the code-review gate (134-REVIEW.md, resolved_partial): 7 verified Sigra-side findings fixed in commit 826e5a0; 4 findings (CR-01, WR-02, WR-05, IN-01) deferred to tracked todos in .planning/todos/pending/."
deferred:
  - truth: "accrue.md log_audit/2 bridge uses a correct Sigra.Audit.log form (CR-01)"
    addressed_in: "tracked todo (not a later phase)"
    evidence: ".planning/todos/pending/2026-05-28-audit-log-config-first-api-gap.md — pre-existing library/cross-doc gap; guides/flows/audit-logging.md is also wrong; not introduced by Phase 134"
  - truth: "lockspire.md resolve_account/2 returns {:ok, user}|{:error, :not_found} (WR-02)"
    addressed_in: "tracked todo (sister-repo contract unverifiable in this tree)"
    evidence: ".planning/todos/pending/2026-05-28-phase-134-recipe-residual-findings.md — lockspire/ sister-repo not checked out; return-shape contract cannot be verified locally"
  - truth: "rulestead.md RulesteadPolicy declares @behaviour (WR-05)"
    addressed_in: "tracked todo (sister-repo contract unverifiable in this tree)"
    evidence: ".planning/todos/pending/2026-05-28-phase-134-recipe-residual-findings.md — rulestead/ sister-repo not checked out; behaviour module name/declarability cannot be verified locally"
  - truth: "recipe {:sigra, ~> 1.29} pin matches published hex version (IN-01)"
    addressed_in: "project-wide convention (not a Phase 134 defect)"
    evidence: "All six companion-lib recipes (incl. LOCKED Phase 132 threadline.md + mailglass.md) pin ~> 1.29 uniformly; @version is 0.3.0. Fixing here would break Phase 132 template consistency."
---

# Phase 134: Recipe-Only Companion Libraries Verification Report

**Phase Goal:** Publish the four recipe-only companion-lib docs (Accrue, Lockspire, Relyra, Rulestead) under `guides/recipes/companion-libs/` so the suite-narrative cross-links land on real recipes that respect the Diminishing Returns Wall (no library-resident adapters, no `--with-*` flags, no glue Hex packages).
**Verified:** 2026-05-28T14:38:48Z
**Status:** passed
**Re-verification:** No — initial verification (after code-review gate resolution)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | An adopter can read accrue.md and wire seat-limit gating + lifecycle integration via `lib/sigra/hooks.ex` against the `Accrue.Auth` behaviour, Sigra owning no seat-limit logic | ✓ VERIFIED | accrue.md present (215 lines). `before_add_member` (6×), `Accrue.Auth` (12×), `on_delete`/`lib/sigra/hooks.ex` (5×), `lib/sigra/audit.ex` (3×). "Sigra owns the **seam** … not the seat-limit logic" in body + Non-goals. Live-source confirms `before_add_member/4` (callbacks.ex:38, "Check seat limits" callbacks.ex:17), `after_member_remove/2` (callbacks.ex:47), hooks `get_hook` reads from `%Sigra.Config{}` struct (hooks.ex:93) — so the CR-02 config-first `Sigra.Config.new!(hooks:)` fix is correct. CR-05 fix confirmed: no `/Users/jon` path leak. |
| 2 | An adopter can read lockspire.md and stand up a Lockspire integration respecting ADR 001 (no `sigra_lockspire` glue package), cross-referencing companion-oauth-provider.md | ✓ VERIFIED | lockspire.md present (174 lines). `companion-oauth-provider` cross-link (3×, incl. See also). "**4 required callbacks** and **2 optional**" (RESEARCH §1 correction); "5 required" ABSENT. All 4 required callbacks named (`resolve_current_account`, `resolve_account`, `build_claims`, `redirect_for_login`); `verify_backchannel_user_code/3` + `redirect_for_logout/2` labeled optional. ADR 001 / `sigra_lockspire` quoted in Non-goals + "no `--with-lockspire` flag". `current_scope.user` scope read pinned to scope.ex:18-25. WR-03 fix confirmed: `redirect_for_login/2` URI-encodes `return_to`. |
| 3 | An adopter can read relyra.md and wire SAML 2.0 SP coverage citing the v1.27 ENT-SSO OIDC-vs-SAML matrix, making explicit Sigra does not own SAML metadata storage | ✓ VERIFIED | relyra.md present (159 lines). `Sigra.Auth.create_session/4` PRESENT (verified at auth.ex:1284); `Sigra.Session.create_session` ABSENT (the load-bearing pin — verified that function does NOT exist in session.ex). ACS hand-off pins `start_login/3`, `consume_response/3`, `%Relyra.LoginResult{}`. OIDC-vs-SAML 2-row decision table cites `enterprise_connections.ex`/`enterprise_routing.ex`/`oauth/enterprise_reconciliation.ex` (all three files exist). Non-goals enumerate SAML metadata storage / signing keys / SLO / cert rotation as Relyra-owned. No `.planning/` links. CR-03/CR-04 fixes confirmed (`UserAuth.put_user_session_token`, `MyApp.Auth.sigra_config()`); WR-01 fix (`delete_session/3` — verified at auth.ex:1496); WR-04 fix (`Sigra.SessionStores.Ecto` — verified exists; `Sigra.Session.Store` does NOT exist). |
| 4 | An adopter can read rulestead.md and gate a Sigra-protected controller on `Rulestead.enabled?` plus derive a `RulesteadPolicy` from `current_scope`, Sigra shipping no opinionated authorization | ✓ VERIFIED | rulestead.md present (203 lines). `Rulestead.Runtime.enabled?/3` + `Rulestead.enabled?/2` both cited (RESEARCH §2); fabricated `enabled?("flag", conn)` ABSENT. `RulesteadPolicy` implements `can?/4` (RESEARCH §3); `authorize/4` NOT pinned as host callback. Separate `{:rulestead_admin, "~> 0.1"}` package noted. Controller example builds context from `current_scope` (`scope.role`, `scope.user.id`, `scope.active_organization_id`). Non-goals: Sigra owns no flag storage/evaluator/admin UI + no `--with-rulestead` flag. |
| 5 | All four recipes carry uniform `validated_against:`/`last_validated:` frontmatter, "Failure modes" section, "Non-goals" section, and the "Sigra works fully standalone" banner — matching the Phase 132 template | ✓ VERIFIED | Structural-heading loop OK for all four: `## Failure modes`, `## Non-goals`, `## See also`, `> **Sigra works fully standalone.**` banner, `validated_against:` + `last_validated:` HTML-comment block + visible line. Pins correct: accrue `~> 1.2`, lockspire `~> 1.2`, relyra `~> 1.2`, rulestead `~> 0.1`. Matches threadline.md / mailglass.md LOCKED template. |

**Score:** 5/5 truths verified

### Phase Gate (must_haves truth #6)

| Gate | Result | Status |
| ---- | ------ | ------ |
| `mix docs --warnings-as-errors` | exit 0, zero warnings/errors/undefined-references | ✓ VERIFIED |
| `mix compile` (comma-trap guard) | exit 0 | ✓ VERIFIED |
| D-20 banned-phrase grep across all four recipes | zero matches | ✓ VERIFIED |

### Deferred Items

Tracked deviations accepted at the code-review gate (134-REVIEW.md, status: resolved_partial). NOT phase-blocking.

| # | Item | Disposition | Evidence |
| --- | ---- | ----------- | -------- |
| 1 | CR-01: accrue.md `log_audit/2` bridge calls `Sigra.Audit.log(map)` — does not match `Sigra.Audit.log/2 (action, opts)` (verified at audit.ex:55) | Tracked todo | `2026-05-28-audit-log-config-first-api-gap.md` — pre-existing library/cross-doc gap; `guides/flows/audit-logging.md:93` is also wrong; not introduced by this phase. Not scheduled into Phase 135/136. |
| 2 | WR-02: lockspire.md `resolve_account/2` returns bare user/`nil` | Tracked todo | `2026-05-28-phase-134-recipe-residual-findings.md` — `lockspire/` sister-repo not checked out; return-shape contract unverifiable locally. |
| 3 | WR-05: rulestead.md `RulesteadPolicy` lacks `@behaviour` declaration | Tracked todo | same residual-findings todo — `rulestead/` sister-repo not checked out; behaviour module name unverifiable locally. |
| 4 | IN-01: recipes pin `{:sigra, "~> 1.29"}` vs published `@version 0.3.0` | Project-wide convention | All six companion-lib recipes (incl. LOCKED Phase 132 siblings) pin `~> 1.29` uniformly; fixing here breaks template consistency. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `guides/recipes/companion-libs/accrue.md` | RC-03 Accrue recipe; contains `before_add_member` | ✓ VERIFIED | 215 lines, substantive, LOCKED template, `before_add_member` present, autolinks resolve (mix docs exit 0) |
| `guides/recipes/companion-libs/lockspire.md` | RC-04 Lockspire recipe; contains `companion-oauth-provider` | ✓ VERIFIED | 174 lines, substantive, cross-link present, autolinks resolve |
| `guides/recipes/companion-libs/relyra.md` | RC-05 Relyra SAML SP recipe; contains `Sigra.Auth.create_session/4` | ✓ VERIFIED | 159 lines, substantive, load-bearing pin present + verified against source |
| `guides/recipes/companion-libs/rulestead.md` | RC-06 Rulestead recipe; contains `RulesteadPolicy` | ✓ VERIFIED | 203 lines, substantive, `RulesteadPolicy`/`can?/4` present |
| `mix.exs` | ExDoc extras: 4 recipes registered + 4 Phase 133 skip-warnings removed | ✓ VERIFIED | All four in `extras:` (lines 222-225); only threadline/mailglass remain in skip-warnings; each new file appears exactly once; `groups_for_extras:` "Companion Libraries" regex intact (line 231); `mix compile` exit 0 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| relyra.md | `lib/sigra/auth.ex:1284` `Sigra.Auth.create_session/4` | session-mint pin (NOT `Sigra.Session.create_session/3`) | ✓ WIRED | `create_session/4` present in recipe AND verified at auth.ex:1284; `Sigra.Session.create_session` absent in recipe AND confirmed non-existent in session.ex |
| lockspire.md | `guides/recipes/companion-oauth-provider.md` | cross-link `../companion-oauth-provider.html` | ✓ WIRED | 3 occurrences incl. See also; resolves under `mix docs --warnings-as-errors` |
| rulestead.md | host policy `can?/4` | `RulesteadPolicy` callback pin (NOT `authorize/4`) | ✓ WIRED | `can?/4` present, `authorize/4` not pinned as host callback |
| `mix.exs extras:` | four new companion-libs recipe files | ExDoc registration | ✓ WIRED | All four registered after mailglass.md (lines 222-225); `mailglass.md` extras line given trailing comma; rulestead.md last with none |

### Data-Flow Trace (Level 4)

N/A — docs-only phase. Recipes render static prose/code-snippets; no dynamic data source. The "data flow" equivalent is autolink resolution + line-range pin accuracy, covered by the `mix docs --warnings-as-errors` gate (exit 0) and direct live-source cross-checks above.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Docs build resolves all cross-links | `mix docs --warnings-as-errors` | exit 0, zero warnings | ✓ PASS |
| mix.exs edit syntactically sound | `mix compile` | exit 0 | ✓ PASS |
| No marketing voice | D-20 grep (4 files) | zero matches | ✓ PASS |
| Load-bearing pin exists in source | `grep "def create_session" lib/sigra/auth.ex` | line 1284 | ✓ PASS |
| Anti-pin absent in source | `grep "def create_session" lib/sigra/session.ex` | none | ✓ PASS |

### Probe Execution

N/A — no `scripts/*/tests/probe-*.sh` declared or implied by this docs phase. The phase gate is `mix docs --warnings-as-errors` (run above, exit 0).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| RC-03 | 134-01-PLAN | accrue.md references `Accrue.Auth` + cross-links `lib/sigra/hooks.ex` for seat-limit gating + lifecycle | ✓ SATISFIED | accrue.md present; `Accrue.Auth` + `before_add_member/4` + `on_delete` hook + audit bridge all present and source-verified |
| RC-04 | 134-01-PLAN | lockspire.md concrete recipe + cross-links companion-oauth-provider + respects ADR 001 | ✓ SATISFIED | lockspire.md present; AccountResolver stub (4 req + 2 opt), `mix lockspire.install --sigra-host`, cross-link, ADR 001 in Non-goals |
| RC-05 | 134-01-PLAN | relyra.md SAML 2.0 SP wiring + cites v1.27 ENT-SSO OIDC-vs-SAML matrix | ✓ SATISFIED | relyra.md present; OIDC-vs-SAML table cites three ENT-SSO surface files (all exist); session-mint pinned + verified |
| RC-06 | 134-01-PLAN | rulestead.md demonstrates `Rulestead.enabled?` from Sigra-protected controller + `RulesteadPolicy` from `current_scope` | ✓ SATISFIED | rulestead.md present; `Rulestead.Runtime.enabled?/3` controller example builds context from `current_scope`; `RulesteadPolicy can?/4` |

All four phase requirement IDs (RC-03, RC-04, RC-05, RC-06) declared in PLAN frontmatter, all map to Phase 134 in REQUIREMENTS.md traceability table (lines 89-92). No orphaned requirements; no IDs unaccounted for.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| accrue.md | 81 | `Sigra.Audit.log(map)` does not match `log/2 (action, opts)` (CR-01) | ⚠️ Warning | Adopter copy-paste of `log_audit/2` would raise `UndefinedFunctionError`. DEFERRED (pre-existing cross-doc gap, tracked todo). Does NOT autolink-fail `mix docs` because the call is inside a fenced code block, not a `Module.fun/arity` reference. |
| lockspire.md | 148 | string `# TODO:` in failure-mode prose | ℹ️ Info | Descriptive ("the generator leaves `# TODO:` markers") — not a debt marker in the recipe. Not load-bearing. |

No `TBD`/`FIXME`/`XXX` debt markers in any of the four recipes. No banned phrases. No `return null`/empty-impl stubs (docs phase).

### Human Verification Required

None. All five success criteria are verifiable via grep + live-source cross-checks + the `mix docs --warnings-as-errors` autolink gate (the same gate Phase 136 PROOF-01 re-runs at milestone close). This is a docs-only phase with no runtime behavior, visual surface, or external-service integration to manually exercise. The recipe content correctness is bounded by line-range pins against the live Sigra source (present in tree) — those were verified directly; sister-repo-dependent contracts (WR-02, WR-05) are explicitly deferred as unverifiable in this tree, not punted to a human.

### Gaps Summary

No phase-blocking gaps. All five ROADMAP success criteria are observably true in the codebase; all four artifacts exist, are substantive, and are wired; the blocking `mix docs --warnings-as-errors` gate exits 0; the D-20 banned-phrase grep returns zero; and all three RESEARCH corrections (Relyra session-mint pin, Lockspire 4+2 AccountResolver, Rulestead `Runtime.enabled?/3` + `can?/4`) are correctly encoded and cross-checked against live source.

Four findings remain DEFERRED via the code-review gate to tracked todos (CR-01, WR-02, WR-05, IN-01). Disconfirmation pass assessment:
- **CR-01** is a real, source-verifiable correctness defect in adopter copy-paste code, BUT it is a pre-existing library/cross-doc gap (the canonical `guides/flows/audit-logging.md` is also wrong) that predates and is not unique to this phase. Accepted as a tracked deviation; not a Phase 134 regression.
- **WR-02, WR-05** depend on `lockspire/` and `rulestead/` sister-repo source contracts that are NOT checked out in this tree; the callback names/arities were confirmed in 134-RESEARCH.md but return-shape/behaviour-declarability cannot be verified locally. Correctly deferred — verifying them would require the absent checkouts.
- **IN-01** is a uniform project-wide version-convention issue across all six companion-lib recipes (including the LOCKED Phase 132 siblings); not a phase-134 defect.

These deferrals are documented, tracked in `.planning/todos/pending/`, and do not undermine the phase goal (the four recipes exist, respect the Diminishing Returns Wall, and the suite-narrative cross-links resolve). Recommend closing CR-01 (the only locally-verifiable defect) before milestone GA via the preferred library fix in its tracked todo.

---

_Verified: 2026-05-28T14:38:48Z_
_Verifier: Claude (gsd-verifier)_
