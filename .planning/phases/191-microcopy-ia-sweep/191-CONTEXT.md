# Phase 191: Microcopy & IA Sweep - Context

**Gathered:** 2026-06-17 (assumptions mode + deep multi-subagent prior-art research)
**Status:** Ready for planning

<domain>
## Phase Boundary

The **COPY** phase of the v1.39 DS-COHERENCE fractal program (L0 tokens → L1 components →
L2 groups → L3 pages → L4 flows → **system-wide copy/IA ratification**). A content/copy/IA
pass over **already-built** admin UI — NOT feature construction. Scope is the **7
library-owned admin LiveViews** (`lib/sigra/admin/live/{index,organization,users_index,
user_show,branding,audit_index,audit_user}_live.ex`) + `lib/sigra/admin/components.ex`.

Delivers three requirements:
- **COPY-01** — a system-wide voice pass aligns all admin microcopy with the brand book
  (precise/honest/useful/calm/maintainer-grade); errors state *what failed + why it matters +
  the next action*.
- **COPY-02** — a GOV.UK plain-language pass yields a **committed one-term-per-concept glossary**
  with no synonym drift across pages.
- **COPY-03** — empty-state, success, and warning copy is **consistent across all admin surfaces**.

Success (ROADMAP): glossary committed; every string passes the voice + plain-language rubric;
no synonym drift; ledger raised.

**OUT of scope:** generated auth forms/emails (host-owned, v1.37 territory, under
`priv/templates/sigra.install/`); the brand book itself (it is the *source of truth* the pass
measures against, not a target); any net-new admin surface, component, token, or feature;
terminal idempotency / full baseline recapture / allowlist reset-to-empty (→ Phase 192).
</domain>

<decisions>
## Implementation Decisions

### A. Canonical vocabulary — `member` ≠ `user` is load-bearing, not drift (COPY-02)
- **D-01:** The one-term-per-concept glossary **defines both `user` and `member` as distinct
  concepts** — it does NOT unify them. `user` = the global identity / the login (uniquely a
  verified email, can belong to multiple orgs). `member` = that user's seat-plus-role inside
  **one** organization (the relationship is a *membership*). This is the universal multi-tenant
  auth model (WorkOS, GitHub, Clerk, Auth0, Slack, Linear all converge on it) and **Sigra already
  encodes it in schema** (`OrganizationMembership`, roles owner/admin/member, `member_add/remove/
  role_change` audit events). Collapsing them would destroy the ability to distinguish "**remove**
  a member from the org" (membership ends, account survives) from "**delete** a user" (identity
  destroyed). Boundary rule: **outside any org / on global+platform surfaces → "user"; inside an
  organization's surface → "member."** "account" is demoted to first-person self-service copy
  ("your account settings") only — never a person-noun in admin chrome.
- **D-02:** Canonical terms (the glossary table). Each concept gets exactly one allowed term;
  listed synonyms are **banned** in visible admin copy:

  | Concept | Canonical | Banned synonyms |
  |---|---|---|
  | Global identity (the login) | **user** | account (as person), member (on global surfaces) |
  | A user's seat in one org | **member** (rel. = *membership*) | user (in org surfaces), seat, teammate, collaborator |
  | The tenant | **organization** (spelled out) | org (allowed only in code/URL slugs/identifiers) |
  | Auth action (verb) | **sign in** / **sign out** (two words) | log in, login (verb), signin, log out, logout, sign off |
  | Auth action (modifier/noun) | **sign-in** (hyphenated, e.g. "failed sign-in") | login (noun), signin |
  | Take a member out of an org | **remove** | delete a member, revoke a member |
  | Destroy the identity | **delete** (user/account) | remove, destroy |
  | End a session / API key / sent invitation | **revoke** | delete, remove, cancel |
  | Policy block (reversible, admin-initiated) | **suspend** | deactivate, disable, ban, lock |
  | Auto-block after failed sign-ins (system, transient) | **lock / unlock** | suspend, disable, freeze |
  | Stop a pending invitation | **revoke** (sent) / **cancel** (not yet sent) | delete invitation |
  | Pending join offer | **invitation** (noun) / **invite** (verb) — states pending→expired→accepted/revoked | — |
  | Authority bundle | **role** (owner/admin/member) | permission (as synonym), access level, group |
  | Granular capability | **permission** | role, scope (in UI prose) |

  The current drift is **labels only** (e.g. `organization_live.ex:77` "Search org members";
  `users_index_live.ex` "sign in" vs ":135" "sign-in"), not the model — so edits are low-risk
  relabeling, never schema/behavior changes.

### B. Voice rubric for COPY-01 / COPY-03 (the pass/fail standard)
- **D-03:** Ratify every admin string against a concrete, mostly-mechanical rubric (authored into
  the reference docs alongside the glossary), coherent 1:1 with the brand book's Tone-By-Context.
  **Cross-cutting plain-language gate** (all string types): active voice; second person ("you" =
  operator, "the user" = subject — never "the customer"); GOV.UK words-to-avoid banned (leverage,
  utilise, facilitate, seamless, robust, empower, "it just works", etc.); **no leaked internals**
  (no `inspect/1`, no `%Ecto.Changeset{}`, no module names, no bare error codes — maps known error
  structs to human copy); ≤ ~2 sentences; calm, no blame, no hype, no "Oops/!"; **severity-honest
  color** (red only for business-harm/destructive; routine session-expired/empty/first-use are
  neutral; warnings amber).
- **D-04:** Per-type rubrics:
  - **Error** — names what failed + why it matters + a concrete next action, rendered near its
    source, preserving operator input. **Decisive E-6 branch:** at the **auth/enumeration boundary**
    (login, reset, magic link, "does this account exist") the message MUST be **uniform/generic**
    (vagueness required, overrides specificity); for the **operator's own mistake / system fault
    inside the trusted console** be **specific** (operators are trusted engineers — vagueness just
    wastes a support investigator's time).
  - **Empty** — classify the state and match copy to it: *first-use* ("empty is expected; here's
    what will appear and what triggers it", neutral, optional CTA), *filtered no-results* (+ clear
    filters), *scope-denied* (calm boundary statement, not "forbidden"), *load-error* (→ Error
    rubric). Explain what populates the surface. Never red. No misleading CTA the persona can't act on.
  - **Success** — past tense + the durable consequence the operator can rely on + tenant/blast-radius
    scope ("Revoked across Acme Corp only."); transient toast for routine reversible saves, inline/
    persistent for security-weight outcomes. No hype.
  - **Warning / destructive confirm** — concrete risk + blast radius (one device vs all sessions; one
    user vs whole tenant) + explicit reversibility ("This can't be undone.") + verb-noun confirm
    ("Revoke all sessions", never "OK") + how to reduce risk where applicable.
- **D-05:** Register stays **maintainer-grade technical** — all operators are engineers
  (`JTBD.md:3`); do not soften to lay-consumer tone. Honor the existing `admin-design-contract.md`
  structural copy constraints (notices inline/sentence-shaped via `<.notice_link>`; errors →
  `notice tone={:risk}`; `empty_state` only for empties; scope context via `scope_ribbon`/
  `scope_copy/1`; verb-first action labels, no mystery-meat) — 191 *fills in* the D10 Microcopy /
  D9 IA axes, it does not contradict the v1.34-ratified contract.

### C. Glossary artifact + enforcement — ExUnit test, not a bash guard (COPY-02)
- **D-06:** The glossary lives at **`guides/reference/admin-glossary.md`** (sibling to
  `admin-quality-ledger.md` / `admin-fractal-scorecard.md` / `admin-design-contract.md`), as a
  **machine-parseable canonical-term + banned-aliases table** in the GOV.UK A–Z "use X not Y"
  shape, mirroring the existing `|`-delimited ledger table idiom. The voice rubric (B) is authored
  here too (or in `admin-design-contract.md` — planner discretion), extending not duplicating the
  contract.
- **D-07:** Enforcement is an **ExUnit test** (`test/sigra/admin/glossary_test.exs`), **not** a
  `scripts/ci/*.sh` guard. Rationale (research-decisive, overturned the initial bash assumption):
  the copy lives **inside `.ex`/`.heex` source**, so a test that parses source **structurally**
  (strips `attr`/`def`/`defp`/`alias`/`@`/`*_testid`/`data-*`/`class=` lines and the
  `sigra-auth--preview` carve-out *before* matching) gives a far lower false-positive rate than a
  grep guard, emits file:line + offending-term + canonical-replacement failures, runs in the normal
  `mix test` job (no extra `ci.yml` step), and — uniquely — **ships with the library so adopters who
  customize the generated/admin copy inherit the same drift guard**. Matching is word-boundary
  (`\b`), case-insensitive, with banned spelling/case variants enumerated in the glossary's third
  column (one-line edit to add a variant). **Vale was rejected** (markup-only parser — cannot isolate
  visible strings from module names in Elixir source; its FP-tolerant culture conflicts with a
  merge-blocking gate). **Bash guard `scripts/ci/admin-glossary-guard.sh` is the documented
  runner-up** if `scripts/ci/*.sh` symmetry is later judged mandatory — it would read the same
  glossary table via the `awk` idiom from `quality-ledger-monotonic.sh` and exclude the carve-out by
  line range.

### D. Scope boundary + the auth-preview carve-out (COPY-01, escalation-resolved)
- **D-08:** "All admin surfaces" = exactly the 7 admin LiveViews + `components.ex` (admin chrome).
  Generated auth forms/emails are **host-owned** (own copy lifecycle under
  `priv/templates/sigra.install/`) and OUT of scope.
- **D-09:** **Carve-out (mandatory):** `branding_live.ex` (~lines 587–610, the
  `data-sg-auth-branding-preview="login"` / `sigra-auth--preview` block, incl. `<h1>Log in</h1>`)
  renders a **facsimile of the host's generated login screen** — its "Log in" deliberately mirrors
  host-owned auth copy and **must NOT be normalized** to the admin chrome's "sign in." The glossary
  guard exempts this region. Generated-auth screens may diverge from admin chrome on the **auth verb
  only** ("sign in" is the generated default per GOV.UK/Microsoft/Stripe/GitHub, but hosts may
  override to "log in" if their brand demands it); **all noun and lifecycle-verb terms
  (user/member/organization/remove/delete/revoke/suspend/lock/role/permission) are fixed
  library-wide** — those encode behavior/security semantics, not style. 191 does not touch
  generated-auth vocabulary.

### E. Self-contained recapture — mirror Phase 183 (sequencing vs Phase 192)
- **D-10:** Editing visible copy breaks **both** literal text assertions in
  `admin-checkpoints.spec.ts` (~15 strings: `getByText('Global user operations')` :214,
  `'Global audit explorer'` :282/:316, buttons `'Revoke session'`/`'Start impersonation'`/
  `'End impersonation'`, links `'Open user'`/`'Export CSV'`, header `'Admin'`/`'Global'`, banner
  `Signed in as …`/`Impersonating …`, chips `'Failures'`/`'Impersonation'`) **and** the
  `toHaveScreenshot` baselines (8 slugs × 3 projects). **191 lands self-contained, same-diff**,
  mirroring the proven Phase 183 sequence:
  1. Edit copy in the lib-owned admin LiveViews (+ propagate to example/template only where a
     mirrored asset is actually touched — copy itself is single-source library-owned, **no
     three-surface byte-parity duty**; that rule is CSS/JS-only).
  2. Update the matching `admin-checkpoints.spec.ts` assertions + any `components_test.exs` byte
     goldens / `install_golden` fixtures in the **same diff**.
  3. Declare the affected slugs in `snapshot-allowlist` (checkpoints lane) / `snapshot-allowlist-design`
     (design lane, hyphenated-filename slugs). **Never allowlist the canaries** `impersonation-banner`
     / `board-notice`.
  4. Recapture: boot example dev server **pre-compiled on PORT=4011**, `npx playwright test
     --update-snapshots=all` across chromium/mobile/dark for the affected specs, then immediately
     `git checkout --` the canary PNGs.
  5. Run `scripts/ci/snapshot-recapture-gate.sh <slugs…>` (compare-mode 3/3 + canary guard
     `--require-all` + ExUnit goldens) → all-green = recording approved, zero human review.
  6. **Reset the allowlist back to empty** after the gate passes so `main` stays green between phases.
  Phase 192 retains its **terminal** role (full deliberate recapture + idempotency re-run + reset
  both allowlists to empty + generated-host parity); 191 does not pre-empt it.

### F. "Ledger raised" — +1 L3 row, monotonic re-score (COPY-01..03 + folded todo)
- **D-11:** Add the maintainer-pinned **`branding-live` L3 row** to
  `guides/reference/admin-quality-ledger.md` (L3 goes 6 → 7 rows), scored against the L3 page
  scorecard (GOV.UK IA, least-surprise, overlay/modal correctness, page-level a11y/responsive) with
  executable evidence links — literally satisfying ROADMAP v1.39 SC #4 ("non-archetypal pages
  explicitly scored"). Re-score existing rows on the **D9 IA / D10 Microcopy** axes against the new
  glossary + voice-rubric evidence. **Monotonic only — integers may only increase**; the merge guard
  fails on any decrease, and demotion (if ever needed) stays a deliberate first-class op. Tier
  promotions 1→2 only where a surface genuinely clears award-grade ("coherent on-brand copy") — not
  automatic from copy compliance. **No cross-cutting pseudo-row** (the ledger schema is strictly
  per-surface; D9/D10 are *columns*, not rows).

### Folded Todos
- **D-12:** Fold `2026-06-17-page04-branding-explicit-scoring.md` (maintainer-pinned
  `resolves_phase: 191`) → realized by **D-11** (the explicit `branding-live` L3 ledger row).
  Note: `2026-06-17-phase-189-review-deferred.md` (ConfirmDialog WR-01..03 + `branding_live`
  `error_message/1` leak WR-04) was already folded into Phase 190 (190 D-14); WR-04's "map known
  error structs to human copy instead of `inspect/1`" overlaps **D-03's no-leaked-internals gate** —
  the planner verifies it was actually fixed in 190 and, if not, finishes it here as a voice-pass item.

### Claude's Discretion (planner resolves — below escalation threshold)
- Exact glossary table contents beyond D-02's seed set (additional concepts surfaced during the
  string inventory), and whether the voice rubric lives in `admin-glossary.md` vs `admin-design-contract.md`.
- The structural source-extraction regexes in `glossary_test.exs` (which line patterns to strip).
- Sequencing of the string-inventory → edit → assertion-update → recapture waves.
- Exact L3/L4 tiers achieved per surface after the re-score (the monotonic guard is the floor).
- Whether any string edit is large enough to also touch a `components_test.exs` golden vs spec-only.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `brandbook/brand-book.md` — **current v2, the voice source of truth.** Voice System (lines
  ~183–211: 5 principles, Say/Do-Not-Say table, Tone-By-Context, ratified microcopy exemplars at
  ~245/247/249). The pass measures against this; it is never edited by 191.
- `guides/reference/admin-fractal-scorecard.md` — the fixed grading anchor; **D9 IA/least-surprise
  (line 34)** and **D10 Microcopy (line 35, refs the "v1.37 microcopy contract")** are the axes 191
  fills in. Do not author a parallel rubric.
- `guides/reference/admin-quality-ledger.md` — the machine-parseable monotonic-guard ledger; the
  new `branding-live` L3 row is appended here; existing rows re-scored (increase-only).
- `guides/reference/admin-design-contract.md` — v1.34-ratified per-component copy spec (notices
  inline via `<.notice_link>`; errors → `notice tone={:risk}`; `empty_state`; `scope_ribbon`/
  `scope_copy/1`; verb-first labels). 191 extends, never contradicts it.
- `guides/reference/admin-ui-principles.md` — operator personas (platform admin / support
  investigator / org admin), IA / least-surprise / scope-visibility doctrine.
- `lib/sigra/admin/live/{index,organization,users_index,user_show,branding,audit_index,audit_user}_live.ex`
  + `lib/sigra/admin/components.ex` — the in-scope copy. Note the `branding_live.ex:~587–610`
  `sigra-auth--preview` carve-out (D-09).
- `scripts/ci/quality-ledger-monotonic.sh` — ledger-guard parsing idiom (the model for any bash
  runner-up glossary guard); `scripts/ci/snapshot-canary-guard.sh` + the `snapshot-allowlist` /
  `snapshot-allowlist-design` manifests + `scripts/ci/snapshot-recapture-gate.sh` — the
  intended-baseline-delta mechanism (D-10).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — the literal text assertions +
  8 `toHaveScreenshot` slugs that copy edits will break (D-10); `test/sigra/admin/components_test.exs`
  — component byte-goldens.
- `prompts/Auth Domain Language — A Field Guide.md` — the **terminology glossary** (consolidated
  table ~806–845; Identity/User/Account ~28–43; Revoke/Rotate/Enroll/Provision ~254–307;
  enumeration-safe wording ~599–611) — primary input for D-01/D-02.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — JTBD / operator
  actions, canonical audit-action labels (~338–350), token-error microcopy (~190–191).
- `.planning/phases/190-flows-fixture-data-l4/190-CONTEXT.md` — D-13 deferred this system-wide
  microcopy sweep to 191; the three-surface byte-parity rule (CSS/JS-only) and ledger conventions.
- External standards (validated, score on *behavior*): GOV.UK A–Z style guide + tone-of-voice
  (https://www.gov.uk/guidance/style-guide/a-to-z); Microsoft Style Guide "sign in/sign out"
  (https://learn.microsoft.com/en-us/style-guide/a-z-word-list-term-collections/s/sign-in-sign-out);
  NN/g error-message guidelines + scoring rubric
  (https://www.nngroup.com/articles/error-message-guidelines/,
  https://www.nngroup.com/articles/error-messages-scoring-rubric/); Shopify Polaris content
  (remove-vs-delete) (https://polaris.shopify.com/content); IBM Carbon notification + empty-state
  (https://carbondesignsystem.com/components/notification/usage/); Vale checks (the rejected option,
  for the record) (https://docs.vale.sh/checks/substitution).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **7 library-owned admin LiveViews** + `lib/sigra/admin/components.ex` — single source of all
  in-scope admin copy; routes inject fully-qualified library modules
  (`priv/templates/.../router_injection.ex:35-40`), so LiveViews are never mirrored into the host.
  Component-level copy is passed in as attrs from the LiveViews (`components.ex` itself carries
  almost no visible strings — only `applied_chip`'s "Remove filter " aria-label / "remove" sr-only).
- **Strong-surface copy already compliant** — success strings match the brand book exactly
  (`user_show_live.ex:81` "Session revoked.", `:89` "All active sessions revoked.";
  `:502` "Locked — revoke active logins and unlock below."). The work is normalizing drift, not a
  wholesale rewrite.
- **Existing guard infra to model on** — `quality-ledger-monotonic.sh` (table-parse + increase-only),
  `snapshot-canary-guard.sh` + allowlist manifests + `snapshot-recapture-gate.sh` (zero-human
  intended-delta recapture, proven by Phase 183's 21-baseline recapture).
- **Source-reading test precedent** — `test/example/test/example_web/admin_shell_test.exs` and
  similar already read source files in `mix test`; the glossary test follows the same pattern.

### Established Patterns
- Three-surface byte-parity is **CSS/JS-only** — copy edits in library-owned LiveViews carry no
  mirror obligation (190 D-06; confirmed by route-injection).
- Value-locked tokens + monotonic quality-ledger guard (merge-blocking, increase-only); tier is
  weakest-link; demotion is first-class.
- Zero-human UAT: deterministic Playwright + axe + executable guards; intended baseline deltas
  declared in an allowlist and recaptured in-phase, canaries never allowlisted.

### Integration Points
- Copy edits in `lib/sigra/admin/live/*` → cascade to `admin-checkpoints.spec.ts` assertions +
  `components_test.exs` goldens + (only if generated copy moved) `install_golden` fixtures, all
  same-diff. New glossary test attaches to `mix test`. New `branding-live` ledger row references its
  evidence spec. Glossary + voice rubric land in `guides/reference/`.
</code_context>

<specifics>
## Specific Ideas

- `member` ≠ `user` is a real, schema-backed distinction (define both); "account" only in
  first-person self-service copy; "organization" spelled out in copy, "org" only in code/slugs.
- "sign in"/"sign out" (verb, two words), "sign-in" (modifier, hyphenated) — admin chrome picks one;
  generated-auth verb may be host-overridden but defaults to "sign in".
- remove (member from org) ≠ delete (the user) ≠ revoke (session/key/sent invitation); suspend
  (policy, reversible) ≠ lock/unlock (auto, transient); role ≠ permission.
- Error copy: vague at the enumeration boundary, specific in the trusted console (decisive E-6 branch).
- Empty states classified (first-use vs filtered vs scope-denied vs load-error), never red.
- Glossary enforced by an ExUnit test that parses source + honors the `branding_live` auth-preview
  carve-out — ships the drift guard to adopters.
- Land copy + assertion updates + baseline recapture self-contained per Phase 183; 192 stays terminal.

## Maintainer interaction note
The maintainer twice declined to pick between framed forks, directing: "research deeply with
subagents, one-shot a perfect *coherent* set so I don't have to think." All forks were therefore
decided from repo + prior-art evidence (4 parallel research agents: terminology-governance tooling,
multi-tenant auth vocabulary/IA, operator microcopy rubric, prompts-corpus + repo-mechanism mining).
No undecided menus are preserved.
</specifics>

<deferred>
## Deferred Ideas

- **Generated-auth-screen copy normalization** — host-owned (v1.37 territory), own lifecycle; only
  the verb default ("sign in") is set, hosts may override. Not 191.
- **Terminal idempotency gate + full baseline recapture + allowlist reset-to-empty + generated-host
  parity** → Phase 192.
- **Bash glossary guard `scripts/ci/admin-glossary-guard.sh`** — documented runner-up to the ExUnit
  test; adopt only if `scripts/ci/*.sh` symmetry is later judged mandatory over adopter-shipped
  enforcement.

### Reviewed Todos (not folded)
- `2026-06-14-phase-186-review-deferred.md` (score 0.6) — D-11 parity-extractor refactor + minor
  cleanups; test-extractor robustness, unrelated to copy/IA. Stays in a focused test-hardening pass.
- `recapture-gate-single-lane.md` (score 0.2) — recapture-gate tooling note; not a copy deliverable.
</deferred>
