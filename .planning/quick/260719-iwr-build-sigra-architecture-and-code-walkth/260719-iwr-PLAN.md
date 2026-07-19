---
phase: 260719-iwr
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - guides/introduction/architecture.md
  - guides/introduction/code-walkthrough.md
  - mix.exs
  - README.md
  - guides/introduction/first-hour.md
  - CHANGELOG.md
  - test/sigra/architecture_guides_contract_test.exs
  - doc/llms.txt
autonomous: true
requirements: [ARCH-DOCS]
must_haves:
  truths:
    - "A senior Phoenix engineer can explain Sigra's library-owned runtime versus generated host-owned code boundary, then place installation, login/session, audit, optional-integration, and upgrade work in the correct subsystem."
    - "The architecture and walkthrough teach one current system from opposite directions: outside-in journeys first, then inside-out values moving through representative source."
    - "The guides disclose current source truth, including the generated password-login double-session seam, without presenting internal/generated code as stable public API or silently inheriting stale guide claims."
    - "All Mermaid diagrams render on generated HTML in Light and Dark modes, re-render after ExDoc navigation, and remain readable fenced source when Mermaid is unavailable or fails; EPUB receives no injected Mermaid assets."
    - "The walkthrough contains 12-18 current, parseable Elixir excerpts of 8-35 lines, with every deliberate omission marked '# ...' and no repository paths or GitHub line anchors used as its reading interface."
    - "Focused contracts fail actionably when discovery wiring, narrative order, diagram accessibility, source excerpts, source anchors, or guide cross-links drift."
  artifacts:
    - guides/introduction/architecture.md
    - guides/introduction/code-walkthrough.md
    - test/sigra/architecture_guides_contract_test.exs
    - mix.exs
    - README.md
    - guides/introduction/first-hour.md
    - CHANGELOG.md
    - doc/llms.txt
  key_links:
    - "mix.exs docs/0 lists architecture.md and code-walkthrough.md immediately after getting-started.md; the existing Introduction group classifies both extras."
    - "README.md and first-hour.md route readers to architecture.html, then code-walkthrough.html; each new guide links to the other."
    - "Architecture concepts and walkthrough labels stay byte-consistent around the ownership boundary, generated host, Sigra runtime, canonical user_sessions store, raw cookie token, hashed database token, audit co-fate, and optional integrations."
    - "Contract anchors connect walkthrough excerpts to current installer filtering, Lockout-before-password order, raw/hashed token generation and Ecto persistence, audit Multi insertion/after-commit telemetry, Plug session renewal, and Oban supervision-aware fallback source."
---

<objective>
Build the complementary Sigra architecture guide and source walkthrough defined by the user-approved documentation brief. Teach the hybrid library/generator model accurately enough that an adopter or contributor can choose the right subsystem, understand the security boundaries, and begin a productive source-reading session.

Purpose: Sigra has task-oriented guides but lacks a compact system model and a source-guided bridge into the implementation. The pair must make the repository predictable without pretending internal modules, generated output, or the reference host are stable public API.

Output: two HexDocs introduction extras, a secure/pinned Mermaid renderer, concise discovery links and changelog entry, a focused drift contract, refreshed tracked ExDoc `doc/llms.txt`, and browser/test evidence. Do not modify runtime behavior, templates, the reference host, package membership, or stale guides beyond reporting their mismatches. The user-approved documentation brief is untracked input only; never add, link, package, or commit it.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@AGENTS.md
@mix.exs
@README.md
@guides/introduction/first-hour.md
@CHANGELOG.md
@lib/sigra/install/runner.ex
@lib/sigra/config.ex
@lib/sigra/auth.ex
@lib/sigra/token.ex
@lib/sigra/session_stores/ecto.ex
@lib/sigra/audit.ex
@lib/sigra/application.ex
@lib/sigra/optional_deps.ex
@lib/sigra/audit/forwarders.ex
@priv/templates/sigra.install/core/auth.ex
@priv/templates/sigra.install/core/user_auth.ex
@test/example/lib/example/accounts.ex
@test/example/lib/example_web/controllers/session_controller.ex
@test/sigra/auth/login_and_lockout_audit_atomicity_test.exs
@test/sigra/install/golden_diff_test.exs

Verified implementation facts the executor must preserve in prose:
- `Sigra.Install.Runner.run/3` filters feature modules by `enabled?/1`, allocates/overlays migration timestamps, creates only absent generated files, applies idempotent injections, and returns a report. The generated files become host-owned; `mix sigra.upgrade` is bounded and does not regenerate arbitrary custom host code.
- `%Sigra.Config{}` carries the host Repo, user/session/audit schemas, scope and organization modules, mail modules, policy callbacks, and optional feature settings into generic runtime operations.
- `Sigra.Auth.authenticate/3` with config normalizes the email, fetches a user, checks lockout before password verification, follows a constant-work password verification path for unknown users, applies enterprise policy, co-transacts successful lockout/hash work with configured audit insertion, then creates a standard or `:mfa_pending` session.
- The generated host `authenticate_user/2` currently collapses `{:ok, user, %{session: ...}}` to `{:ok, user}`. The generated controller then calls `UserAuth.log_in_user/3`, which calls `generate_user_session_token/2` and creates another session. Document this as current implementation drift; do not fix or bless it as a contract.
- `Sigra.SessionStores.Ecto.create/3` persists the SHA-256 hash, returns the Base64url raw token to the host, and generated lookup decodes the raw token before hashing it. Generated `UserAuth` renews/clears the Plug session before storing that raw token and a LiveView socket id.
- Audit atomicity is operation-specific: `log_multi_safe/3` appends configured audit insertion to caller-owned `Ecto.Multi`; callers emit audit telemetry only after commit. Standalone failure audits preserve evidence without pretending to co-fate with failed business state.
- Organizations/scope are authorization context, not merely presentation: session state can carry an active organization and host scope hydration decides the request identity context.
- `Sigra.Application` starts an empty supervisor and performs one-shot diagnostics, forwarder attachment, and vault validation; Sigra owns no long-lived runtime children. Optional dependency behavior is intentional and differs: auto Oban delivery/forwarding can fall back sync, explicit async without supervised Oban fails, absent/no configured Hammer limiter is a no-op, Assent/Joken feature calls fail actionably, EQRCode can return no QR, Threadline is optional, and passkey encryption with a stub vault fails boot.
- The reference host proves integration behavior but is not public API. Existing `guides/flows/login-and-logout.md` still says sessions use `auth.user_tokens`; current canonical session code uses `auth.user_sessions`. Report that mismatch; do not carry it into the new guides.
- `mix docs --warnings-as-errors` succeeds at baseline but rewrites tracked `doc/llms.txt`. Regenerate and include the intentional new-guide entries/content; do not accept unrelated generated churn.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author the outside-in architecture and inside-out code journey</name>
  <files>guides/introduction/architecture.md, guides/introduction/code-walkthrough.md</files>
  <action>
Create `architecture.md` with exactly this essential heading order (wording may be polished but the concepts/order must remain testable): opening boundary promise; `Sigra in one picture`; `Vocabulary for the trip`; `Journey 1: Installation creates an ownership boundary`; `Journey 2: A login becomes durable identity and session state`; `Security is the architecture`; `Cross-cutting mechanics`; `Module atlas`; `Code-reading routes`; `Changing Sigra safely`; `Where to go next`.

Use four Mermaid fences as relationship compression, not decoration:
1. The unnumbered one-picture map: Phoenix host -> generated host modules -> Sigra runtime -> Repo/auth tables, with external mail/OAuth/background integrations on the edge.
2. Installer ownership: Mix task inputs and feature modules -> generic Runner -> host-owned files/migrations/injections, plus bounded future upgrades.
3. Password login sequence: request params -> generated controller/context -> `Sigra.Auth` lockout/crypto/policy/audit/session -> current discarded metadata seam -> generated `UserAuth` second session -> renewed Plug session/cookie -> later hashed lookup/scope hydration.
4. Durable state/trust: user, hashed session, active organization/membership/scope, audit event, MFA/session type; distinguish credentials and raw browser token from stored hashes.

Every Mermaid fence must put its diagram declaration (`flowchart`, `sequenceDiagram`, or equivalent) first, followed immediately by meaningful `accTitle:` and `accDescr:` directives. Keep diagrams compact at HexDocs width, with descriptive node labels and no unexplained abbreviations. Use 4-8 small Elixir blocks only where a value/config/transaction shape is clearer than prose. Define generated host, runtime core, reference host, session, scope, audit co-fate, and optional integration before relying on those terms. Explain dependencies in ownership terms. Link outward to current task guides for instructions, but do not use the stale login guide as proof of session storage.

Create `code-walkthrough.md` as the deeper, non-repetitive companion. Open with a link back to `architecture.html`, the value route the reader will hold in mind, and an explicit warning that generated modules, reference-host examples, private functions, and internal modules are shown to explain implementation and are not promised public API.

Include 15 representative `elixir` fences (within the required 12-18 range), each 8-35 lines after editing and parseable by `Code.string_to_quoted/1`. Copy current source, remove incidental branches, and mark every deliberate cut `# ...`; never invent glue. Cover, in this order:
1. installer feature selection and binding/Runner transfer;
2. Runner enabled-feature/migration/report walk;
3. `%Sigra.Config{}` construction and host callback seam;
4. generated host `sigra_config/0` wiring;
5. generated SessionController password boundary;
6. generated `authenticate_user/2` result collapse;
7. config authentication normalization and lockout-before-password verification;
8. successful login `Ecto.Multi` plus audit/after-commit telemetry;
9. MFA/session-type choice and the first `create_session` result;
10. generated `UserAuth.log_in_user/3` and the currently second session creation;
11. `Sigra.SessionStores.Ecto.create/3` raw/hashed token split;
12. generated Plug session renewal/token storage;
13. generated raw-token decode/hash/fetch and scope hydration boundary;
14. `Sigra.Audit.log_multi_safe/3` / committed telemetry ownership;
15. optional Oban-supervision-aware dispatch plus short representative atomicity/generator test assertions in the surrounding section. If the tests need a separate fence to stay clear, split to 16 rather than compressing unrelated code.

Introduce the architectural point around every excerpt. End with concrete reading routes (module sequence + question answered) for install, password/session, MFA, OAuth reconciliation, account lifecycle, and audit/forwarding. Use documented module/function references that ExDoc can autolink and tell readers to use module-page View Source. Do not publish strings matching source repository paths (`lib/`, `priv/templates/`, `test/example/`, `test/sigra/`), GitHub `/blob/` links, or `#L123` anchors anywhere in either guide. Cross-link `architecture.html` and `code-walkthrough.html`.
  </action>
  <verify>
    <automated>test -f guides/introduction/architecture.md &amp;&amp; test -f guides/introduction/code-walkthrough.md &amp;&amp; test "$(rg -c '^```mermaid$' guides/introduction/architecture.md)" = "4" &amp;&amp; test "$(rg -c '^```elixir$' guides/introduction/code-walkthrough.md)" -ge 12 &amp;&amp; test "$(rg -c '^```elixir$' guides/introduction/code-walkthrough.md)" -le 18 &amp;&amp; ! rg -n '(lib/|priv/templates/|test/example/|test/sigra/|github[^ )]*/blob/|#L[0-9]+)' guides/introduction/architecture.md guides/introduction/code-walkthrough.md</automated>
  </verify>
  <done>The paired guides tell one current, boundary-first system story; architecture has all 11 ordered concepts and four accessible diagrams; walkthrough has 12-18 parseable, bounded real excerpts, clearly discloses the duplicate-session seam and internal-code warning, provides actionable module reading routes, and exposes no repository-path reading interface.</done>
</task>

<task type="auto">
  <name>Task 2: Wire discovery and a pinned, strict, fallback-safe Mermaid renderer</name>
  <files>mix.exs, README.md, guides/introduction/first-hour.md, CHANGELOG.md, doc/llms.txt</files>
  <action>
In `docs/0`, list `guides/introduction/architecture.md` and `guides/introduction/code-walkthrough.md` immediately after `guides/introduction/getting-started.md`. Keep the existing Introduction regex and HTML/Markdown formatter configuration.

Add private ExDoc callback functions in the Mix project and configure `before_closing_head_tag: &amp;before_closing_head_tag/1` plus `before_closing_body_tag: &amp;before_closing_body_tag/1`:
- HTML head: load exactly `https://cdn.jsdelivr.net/npm/mermaid@11.16.0/dist/mermaid.min.js` with `defer`, `crossorigin="anonymous"`, and a SHA-384 `integrity` computed from that exact response. No floating package URL.
- EPUB head/body clauses return `""`.
- HTML body: install one idempotent `exdoc:loaded` listener. On each event, select only unrendered `pre > code.mermaid` blocks, keep the original `pre` visible while rendering, initialize Mermaid with `startOnLoad: false`, `securityLevel: "strict"`, `suppressErrorRendering: true`, and a contrast-stable theme, render into a sibling container with a unique id, apply returned bind functions, mark success, and only then hide the original `pre`. On missing Mermaid or any render rejection, remove any pending marker and leave the original fenced code visible. Avoid duplicate diagrams/listeners across ExDoc client navigation.

Add only small renderer CSS if browser inspection shows it is required for overflow/contrast; keep it within the injected HTML hook rather than creating a general site asset. It must be readable at HexDocs width and under both `body.dark` and the light theme.

Add one concise README topic-map row linking Architecture and Code walkthrough. In the first-hour reading map, keep the green-loop route first, then add a clear optional `Understand or extend Sigra` route from architecture to walkthrough; do not make internal reading a prerequisite for installation. Add one Unreleased/Documentation bullet describing the adopter/maintainer learning path. Do not change package `files:`: guides remain ExDoc inputs under the repository's existing packaging/docs publication model.

Run `mix docs --warnings-as-errors` after the guide/test work is complete. Retain the deliberate `doc/llms.txt` update that adds the new guides, but inspect its diff and reject unrelated generated churn.
  </action>
  <verify>
    <automated>rg -n 'guides/introduction/(architecture|code-walkthrough)\.md' mix.exs README.md &amp;&amp; rg -n '(architecture|code-walkthrough)\.html' guides/introduction/first-hour.md guides/introduction/architecture.md guides/introduction/code-walkthrough.md &amp;&amp; rg -n 'mermaid@11\.16\.0|securityLevel: "strict"|exdoc:loaded|before_closing_head_tag|before_closing_body_tag' mix.exs &amp;&amp; mix docs --warnings-as-errors</automated>
  </verify>
  <done>Both guides are ordered Introduction extras and discoverable without disturbing the first-hour happy path; changelog and tracked llms output acknowledge them; HTML uses an exact integrity-pinned strict Mermaid hook that supports ExDoc navigation and failure fallback, while EPUB gets nothing and package membership is unchanged.</done>
</task>

<task type="auto">
  <name>Task 3: Add maintainability contracts and complete test/package/browser evidence</name>
  <files>test/sigra/architecture_guides_contract_test.exs</files>
  <action>
Add one async ExUnit module with narrow file-reading helpers rather than freezing prose wholesale. Tests must:
- assert both files exist, appear as explicit `mix.exs` extras in architecture-then-walkthrough order adjacent to getting-started, are linked from README/first-hour, and cross-link each other;
- find the essential architecture headings in order by increasing byte index;
- extract exactly four Mermaid fences and require `accTitle:` plus `accDescr:` in each;
- extract all walkthrough `elixir` fences, assert count 12-18, assert every block is 8-35 lines, and parse each with `Code.string_to_quoted/1`, reporting the block number and parse error;
- reject repository path fragments, GitHub blob links, and line anchors in both published guides;
- assert the Mix hook contains the exact 11.16.0 URL, a non-placeholder SHA-384 integrity value, strict/startOnLoad/suppressErrorRendering settings, `exdoc:loaded`, success-before-hide behavior, fallback catch behavior, and empty EPUB clauses;
- define a compact explicit anchor table. For each anchor, assert a stable architectural line appears in current source and a corresponding excerpt line appears in the walkthrough, with actionable failure text. Cover: Runner enabled filtering; `Sigra.Lockout.check(user, lockout_opts)` before `Crypto.verify_with_upgrade`; `Sigra.Token.generate_hashed_token()` in Ecto session create; generated `configure_session(renew: true)` plus `clear_session()`; `Audit.log_multi_safe` with `Audit.emit_telemetry_from_changes`; and `Sigra.OptionalDeps.oban_running?()` supervision-aware forwarding. Add a separate explicit assertion for the generated host result-collapse line and the later `generate_user_session_token` call so the documented double-session seam cannot silently disappear.

Verification sequence (source `tmp/db.env` before DB-backed tests; boot with `scripts/db/up.sh` only if needed):
1. `mix test test/sigra/architecture_guides_contract_test.exs`.
2. `mix format --check-formatted` (the formatter covers Elixir/tests, not Markdown).
3. `mix docs --warnings-as-errors` and inspect generated `doc/architecture.html`, `doc/code-walkthrough.html`, and `doc/llms.txt` diff.
4. `mix test` at repository root. Do not run `mix ci` because its dep-off alias intentionally rewrites dependency state and no templates changed; do not run golden/example gates because this task changes neither templates nor reference-host code.
5. Use `mktemp -d` and `mix hex.build --unpack --output <temp>/sigra.tar`, then confirm the unpacked package contains no `.planning`, `test`, or internal request material. Do not claim the new Markdown guides are package files because existing package membership intentionally excludes `guides/`.
6. With the `agent-browser` skill, open both local `file:///.../doc/*.html` pages using `--allow-file-access` in a named session. Snapshot/cold-read top to bottom, inspect code width and all four rendered diagrams, follow both cross-links, then repeat screenshots with light and dark color schemes. Verify a navigation event does not duplicate diagrams. Finally simulate Mermaid unavailability or a render failure in the page and confirm the original `pre > code.mermaid` remains visible. Close the browser session.

If cold reading or screenshots reveal undefined terms, inconsistent labels, diagram overflow/contrast, or generic filler, revise the guide/hook and repeat the narrow contract, docs build, and affected browser checks. Preserve every unrelated worktree change. Do not push, publish, release, or broaden into fixing the disclosed double-session/stale-guide issues.
  </action>
  <verify>
    <automated>source tmp/db.env &amp;&amp; mix test test/sigra/architecture_guides_contract_test.exs &amp;&amp; mix format --check-formatted &amp;&amp; mix docs --warnings-as-errors &amp;&amp; mix test</automated>
  </verify>
  <done>Contracts pass with actionable drift checks; formatting/docs/full root tests pass; the temporary Hex package excludes internal request/planning/test material; generated architecture and walkthrough pages pass cold reading, light/dark, navigation, cross-link, diagram, code-width, and fallback browser checks; worktree diff is limited to declared documentation/test/planning artifacts.</done>
</task>

</tasks>

<verification>
Required automated evidence:
- The user-approved documentation brief remains ignored and untracked, and is absent from both `git status --short` and package contents.
- `source tmp/db.env &amp;&amp; mix test test/sigra/architecture_guides_contract_test.exs` passes.
- `mix format --check-formatted` passes.
- `mix docs --warnings-as-errors` passes, with both generated HTML pages present and only intentional `doc/llms.txt` drift retained.
- `source tmp/db.env &amp;&amp; mix test` passes.
- Temporary `mix hex.build --unpack` succeeds and contains no internal request material, `.planning`, or tests.

Required browser evidence:
- Both local pages state their purpose in the first screen and define terms before use.
- Four architecture diagrams render once, match prose, fit HexDocs width, and remain legible in Light and Dark modes.
- ExDoc navigation renders the destination diagrams without duplication; both guide cross-links work.
- Walkthrough excerpts remain readable at HexDocs width.
- Mermaid missing/failure simulation preserves the original readable code fence.

Final diff/status audit:
- Expected product/documentation paths only: the two new guides, `mix.exs`, README, first-hour, changelog, contract test, and intentional `doc/llms.txt` regeneration.
- GSD PLAN/SUMMARY/VERIFICATION/STATE artifacts are handled by the workflow's own commits.
- No runtime, template, fixture, reference-host, package-membership, lockfile, image, internal-request, or unrelated file changes.
</verification>

<success_criteria>
- A reader can state the library/generated-host ownership boundary and trace installation plus durable login/session state through the correct modules.
- The guide pair is accurate to current source/tests, explicitly flags the generated double-session seam, and does not repeat the stale `user_tokens` session claim.
- Both pages are discoverable HexDocs Introduction extras with secure, pinned, accessible, navigation-safe Mermaid rendering and readable fallback.
- 12-18 walkthrough excerpts parse and stay bounded; source drift, brittle links/paths, missing discovery wiring, and diagram accessibility regressions are guarded by focused ExUnit tests.
- Narrow contract, formatting, docs warnings-as-errors, full root tests, package inspection, and local light/dark/fallback browser review all have recorded passing evidence or an explicit, truthful blocker.
</success_criteria>

<output>
Create `.planning/quick/260719-iwr-build-sigra-architecture-and-code-walkth/260719-iwr-SUMMARY.md` and `260719-iwr-VERIFICATION.md` when implementation and independent verification are complete.
</output>
