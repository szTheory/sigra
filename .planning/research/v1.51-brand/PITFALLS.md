# Domain Pitfalls

**Domain:** Adopting a new brand (brand book v2.0, "Kiln") into an existing, public, SemVer-governed Elixir/Phoenix auth library with a hybrid lib + generator architecture
**Milestone:** v1.51 BRAND-IDENTITY-ADOPTION
**Researched:** 2026-11-13
**Overall confidence:** HIGH for repo-specific findings (each was read in the repo or reproduced live this session; evidence is cited). MEDIUM for external-ecosystem points (Hex limits, OFL reading, browser favicon behaviour), flagged inline.

## How to read this

Phase key (the proposed plan in `.planning/MILESTONE-ARC.md`):

| Id | Phase |
|----|-------|
| **P1** | Compatibility policy + copy contract + name-clearance record (includes importing and pinning the brand book) |
| **P2** | Deterministic generated output + before-screen catalog |
| **P3** | Tokens, fonts, logo, favicon + browser contrast checks |
| **P4** | Words + layout (one operator job end to end first, then every screen; SEED-010 and SEED-003) |
| **P5** | README / HexDocs / Hex package assets; announcement and any trademark claim last |

Findings tagged **[verified]** were reproduced or read directly in this session. **[inferred]** means reasoned from code but not observed running.

---

## Critical Pitfalls

### C1: The brand book's install snippet `{:sigra, "~> 1.7"}` resolves to the retired stray 1.20.0

**What goes wrong:** The brand book's sample code, README header and Hex-page text all use a two-segment requirement. A scratch project with `{:sigra, "~> 1.7"}` run today against live Hex resolves to **sigra 1.20.0 (RETIRED)**; `~> 1.7.0` resolves to 1.7.1. [verified] Copying the brand book's snippet into README, HexDocs or the social card sends every new adopter to a package the project does not recognise. The installation guide already explains this trap (`guides/introduction/installation.md`: retirement is advisory, so use a bounded three-segment requirement).

**Why it happens:** The brand book was authored outside the repo and says itself that the stray release is a known wart it did not resolve. Brand copy is treated as "just wording" and pasted verbatim.

**How to avoid:** Never paste a version requirement from the brand book. Use the three-segment form (`~> 1.7.0`) everywhere and add one ExUnit test that greps README, `guides/`, `docs/` and `priv/templates` for `{:sigra, "~> ...` and asserts (a) three segments, (b) all equal. Note the current pins are already stale: about a dozen `~> 1.5.0` occurrences in README and guides while Hex's latest real release is 1.7.1. Decide once whether the requirement tracks the latest minor (and who bumps it each release) rather than discovering drift later.

**Warning signs:** Any two-segment `~> 1.x` in a diff; a PR that touches README install text without touching the guides; `mix deps.get` in a scratch project printing `sigra 1.20.0 RETIRED!`.

**Phase to address:** P1 (policy line plus the test), enforced again at P5 (README, Hex, HexDocs, announcement).

---

### C2: Library-owned markup updates by `mix deps.update`; host-owned CSS, logo and fonts do not (version skew)

**What goes wrong:** The admin LiveViews and components live in `lib/sigra/admin/**` and ship with the package, but `sigra_admin.css` (41 KB), `sigra_auth.css` (32 KB) and the logo SVGs are copied into the host once by the installer, which then **skips files that already exist** (`lib/sigra/install/runner.ex` "skipping ... (already exists)"). [verified] A brand pass that adds new classes or markup in lib (status marks, typemark row, tab square) reaches every adopter immediately on `deps.update`, while their CSS stays old. Result: an unstyled or half-styled admin for exactly the adopters who did the "right thing" and updated.

**Why it happens:** Brand work feels like "CSS and templates", which are generated and therefore host-owned. The lib-owned half is forgotten.

**How to avoid:**
- Treat markup as additive-only: new classes must degrade gracefully with the old stylesheet (v1.46 precedent: compatibility selectors so older generated markup keeps rendering; `guides/introduction/upgrading-to-v1.46.md`). Keep `sg-status-pill` and its `data-tone` attribute working; add the new mark beside it.
- Stamp the generated stylesheet with a version comment and have `mix sigra.doctor` warn when the stamp is older than the library's expectation.
- Add one test that renders the new lib admin components against the **previous release's** CSS (frozen golden copy) and asserts structural classes still resolve.
- Follow MAINTAINING.md rule 5: list `mix sigra.upgrade --yes` under a "Template Updates Required" header in the release notes, and write a short upgrade guide section "refresh `sigra_admin.css`".

**Warning signs:** A lib PR that introduces a new `sg-*` class without a matching legacy selector; an upgrade guide that says only "update the dependency"; example app green while a fresh-install-then-downgrade-CSS host looks broken.

**Phase to address:** P1 (policy: additive-only, doctor stamp), P2 (mechanism and test), P3/P4 (obey it).

---

### C3: "Just wording" is observable behaviour: error strings, flashes, status labels, email subjects and Gettext msgids

**What goes wrong:** Several user-facing strings are public contract or are pinned by adopter-visible tests:
- `Sigra.Error.safe_message(:invalid_credentials)` returns `"Invalid email or password."`; it is documented as the enumeration-safe string (`lib/sigra/error.ex`, pinned by `test/sigra/error_test.exs`). [verified]
- Lib-owned flashes and admin copy ship via `deps.update`: `lib/sigra/plug/require_mfa_enrolled.ex:49`, `lib/sigra/admin/live/user_sessions_live.ex` ("Session revoked.", "All active sessions revoked."), status words "Locked", "Unconfirmed", "Deletion scheduled", "Confirmed" in `users_index_live.ex`, `user_show_live.ex`, `organization_live.ex`. Playwright specs and example tests already pin several ("Session revoked.", "Locked users", "Log in to Tasklane", "Log in to Example").
- Generated templates call `dgettext("sigra", ...)` 342 times with **180 unique msgids** and ship no `.po` files. [verified] Changing a msgid (for example "Log in" to "Sign in") silently discards any adopter translation that keyed on the old one, falling back to English with no error.
- The brand mandates "sign in" (two words; "sign-in" as noun). The admin glossary test (`test/sigra/admin/glossary_test.exs`) scans only nine admin files and explicitly exempts generated auth templates, which say "Log in". The brand book itself notes Phoenix's `phx.gen.auth` says "log in".

**Why it happens:** Copy changes get reviewed by readability, not as API. A bulk find/replace is cheap and looks harmless.

**How to avoid:** Classify every string in P1 into three tiers and write the tiers into the compatibility policy:
1. **Frozen contract**: error atoms, `safe_message/1` text, JSON error codes (`"invalid_credentials"`), telemetry and audit event names, `data-*` hooks, public function return shapes. Not touched by this milestone.
2. **Lib-owned UI copy** (admin, plugs): may change in a minor release, but each changed string is listed in a CHANGELOG "Copy changes" block.
3. **Generated host copy**: changes land in templates for new installs; **never rewrite an existing msgid**. Add a new msgid and leave the old one, or leave the string alone. No bulk replace of "Log in".

The copy-contract test must list tier-1 strings explicitly (an exact-match list, not a regex sweep) and carry a positive control (temporarily change one string and see the test fail). Do not extend the glossary test's marker-based line-scanning approach to generated templates; render real components and assert on output.

**Warning signs:** A diff touching `Sigra.Error`, `lib/sigra/plug/*`, or more than a handful of `dgettext` first arguments; example/Playwright tests edited to match new copy in the same PR that changed the copy; "Log in" count in `priv/templates` dropping by dozens in one commit.

**Phase to address:** P1 (tiers and contract test), P4 (apply per tier).

---

### C4: Brand voice ("say what happened, to whom, what to do") leaking account existence on public pre-auth surfaces

**What goes wrong:** The brand voice rewards specificity ("show the real address, role, time"; "say what happened to whom"). The same book says sign-in and reset must stay vague and that **only the admin may be specific**. Rewriting public copy in the new voice is the classic leak: "No account found for maya@...", "This email is already registered. Sign in instead", "We sent a link to <address>" shown only when the account exists, a lock message with a time on the login page, or an email subject that varies by account state. Existing safe copy is pinned in places: "If your email is in our system, you will receive reset instructions shortly." (`test/sigra/install/generator_reset_test.exs:43`); `Invalid email or password` (example session controller test). Registration duplicate handling was just fixed to collapse to `{:error, :email_taken}` and the generated path still has an open **timing** oracle (`.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md`); a "friendlier" registration message would stack a second oracle on the first.

**Why it happens:** A voice guide is applied uniformly. The status vocabulary (Locked, Unconfirmed, Deleting) is defined for the admin and gets reused on public screens.

**How to avoid:**
- P1 produces a **public-surface registry**: every pre-auth string (login, registration, reset, confirmation resend, magic link, MFA challenge, passkey, invitation accept, emails) marked "voice-exempt: enumeration-safe". The brand voice does not apply to these.
- One parametrised test per flow renders the response (status, body, flash, redirect, email subject and presence) for an existing and a non-existing identity and asserts they are identical. Include a positive control: a deliberately leaky string must turn it red.
- Do not touch registration or reset copy that depends on user existence before the timing-oracle todo is decided; keep this milestone copy-neutral on those paths.

**Warning signs:** Any public template string containing an interpolated email, a status word, a timestamp, or "already"; branches in a controller that choose different flash text by user state.

**Phase to address:** P1 (registry plus parity test harness), P4 (apply), with a gate at every P4 plan touching a pre-auth template.

---

### C5: Generated-output churn makes the upgrade diff unreviewable for adopters

**What goes wrong:** One brand change touches many copies. The golden fixture is 85 files (760 KB), and `sigra_admin.css` exists byte-identically in the installer template, the example app and the golden tree, while `sigra_auth.css` has **already drifted** (template 32 KB vs example 13.8 KB). [verified] If tokens (P3), markup/copy (P4) and the SEED-010 re-skin all regenerate the golden together, adopters (and reviewers) get a single diff where value changes, reordering, whitespace and new markup are indistinguishable. The installer cannot overwrite host files, so adopters hand-merge from that diff.

**Why it happens:** Each phase naturally regenerates the same fixtures; formatters and ordering changes ride along; the example app is hand-maintained and drifts from the templates (known pattern: priv/templates drifts behind test/example).

**How to avoid:**
- P2 makes generation deterministic and settles the example-vs-template relationship (generate the example CSS from the template, or add a parity test) **before** any visual change.
- One golden rebless per phase at most, using `MIX_ENV=test mix sigra.fixture.rebless_golden --check` for the delta report grouped by directory; commit mechanical changes (ordering, whitespace) separately from visual ones; change custom-property **values** before changing markup.
- Keep generated filenames stable (v1.38 precedent: logo swapped byte-for-byte, filenames unchanged).
- Install the pinned `phx_new 1.8.8` archive locally; any other version produces spurious golden diffs.
- SEED-010 needs a product decision first. The Tasklane `vt-*` classes are the demo host's brand and must not be copied into shipped templates. Default recommendation: a neutral, token-driven layer (option c in the seed), not Kiln-ifying and not `vt-*`.

**Warning signs:** A golden diff over a few hundred lines; a PR that both reorders CSS and changes values; example app tests edited to chase template changes.

**Phase to address:** P2 (determinism, example/template parity, decision on SEED-010), P3/P4 (one rebless each, reviewed per directory).

---

### C6: The 115 Playwright PNG baselines gate PRs; a visual change turns `ci-gate` red and the canary rule makes it un-mergeable

**What goes wrong:** As read in `.github/workflows/ci.yml`: `ci-gate` needs `example_playwright_smoke`, which aggregates all five Playwright shards. The `admin_checkpoints` shard runs `admin-checkpoints.spec.ts` (27 PNGs, chromium/mobile/dark) with no `@snapshot` filter on pull requests, and `demo_showcase` carries 4 more; the 84 `design_gallery` PNGs compare on push/schedule. [verified by reading; not observed in a run] `scripts/ci/snapshot-canary-guard.sh` (in `fast_checks`) fails any baseline change not listed in the allowlist **and** forbids modifying the `impersonation-banner` canary under any circumstances; a typeface swap changes every glyph, so the canary will modify. Recapture jobs are non-PR only, ubuntu amd64 only (never recapture on darwin), and open bot PRs with write permissions. This is the same deadlock shape as the earlier canary-merge deadlock recorded in the planning history, and a red `ci-gate` on main is the failure v1.48 CLEAN-BASELINE existed to remove.

**Why it happens:** The baselines encode the old brand pixel for pixel. The milestone also says "prefer a catalog over growing the Playwright matrix" without sequencing how the old lanes stop blocking.

**How to avoid:**
- Decide in P1 and execute at the end of P2 (before any P3 visual change): **park, do not recapture**. One small, deliberate PR demotes the PNG-compare lanes (admin_checkpoints, demo_showcase, design_gallery `@snapshot`) to manual/dispatch, leaving the independent protections untouched (real-login and generated-host smoke, the axe gate, golden install fixtures, behaviour specs). The P2 catalog is the "replacement first" that the existing todo (`2026-11-13-cut-ui-process-machinery-on-main.md`) demands.
- Do not add new capture/allowlist/canary/ledger machinery. If any PNG set is kept, recapture **once**, CI-native, in one batch after P4, never per phase.
- Wait on `document.fonts.ready` in any surviving screenshot test; `font-display: swap` otherwise produces nondeterministic baselines.

**Warning signs:** A P3 PR red on `Example Playwright shard (admin_checkpoints)`; anyone proposing to add `impersonation-banner` to the allowlist; a plan titled "recapture baselines" appearing in P3.

**Phase to address:** P1 (decision), P2 (park PR, catalog), P3 (must not start before the park PR merges).

---

### C7: Re-growing the evidence machinery the last milestone just cut

**What goes wrong:** The plan names several small, reasonable things: hash-pinned brand book, copy-contract test, before-screen catalog, contrast checks, name-clearance record. v1.50's failure mode was turning each into a controller, receipt chain and hermetic fake (about 97% of 157k added lines were single-use evidence; zero comparable samples). The existing tree still has `scripts/ci/*.sh` with `.test.sh` twins, panel/eval/autofix scripts, evidence workflows (`fast-01-*`, `green-04-evidence`, `terminal-ratification-evidence`, release-receipt canaries) and quality-ledger monotonic guards that may fire on touched files.

**Why it happens:** "Prove it" gets answered with a new artifact each time; fakes pass while the live thing differs (v1.50 lessons 4, 9, 10).

**How to avoid (budget rules for the roadmap):**
- Hash pin = one checksum file plus one ExUnit test over the files tests actually consume (tokens/brand JSON, logo, favicon, fonts), normalised for line endings. No per-phase receipts, no hash-bound VERIFICATION files.
- Catalog output is a dev route or mix task that renders real components; artifacts are CI-uploaded or gitignored, never committed PNGs; no compare, no allowlist.
- No new workflow file and no new `scripts/ci/*.sh` unless it gates a shipped invariant, and then with a parity test against the production job.
- Verify the real thing once: fresh `phx_new 1.8.8` app, `mix sigra.install`, boot, real login, look at it, rather than another fake.
- Stop rule: a check that is not green after two attempts means change the failed prerequisite, not add a controller (lesson 2). Count verified outcomes (merged PRs), not plans with a SUMMARY.
- Plan ceiling: five phases, each ending in a merged PR; nothing pushed, merged, released or tagged without explicit approval (milestone constraint).

**Warning signs:** `git diff --stat .github scripts` growing; a plan whose deliverable is a "receipt", "ledger" or "attestation"; a fixture standing in for GitHub, Hex or a browser.

**Phase to address:** every phase; planned budget set in P1.

---

### C8: Putting Sigra's brand on the host app's users, against the brand book's own central rule

**What goes wrong:** The brand book is explicit: Sigra's name and logo appear on its own pages and in the admin; **sign-in, registration, two-factor and email screens wear the host's brand**, and "Authentication by Sigra" may appear only as opt-in plain text in a footer. The milestone goal text says "admin/auth UI", which is easy to read as "stamp Kiln on auth". Concrete leak points already in the repo:
- The passkey relying-party name defaults to the literal `"Sigra"` (`priv/templates/sigra.install/core/session_controller.ex:348`), shown in the OS passkey dialog to the host's users.
- `Sigra.Branding.Profile.defaults/0` is public and carries accent `#c2410c`, background `#f7f4ee`, text `#171717`; `sigra_auth.css` sets its own font stack and a radial-gradient accent wash. Silently moving these to brand-book values changes every adopter who never configured branding.
- The admin CSS currently sets **no** `font-family` at all (it inherits the host's). Adopting Instrument Sans in `sg-*` is the first time the admin would impose a typeface inside someone else's app (the brand book itself calls this the maintainers' call because a web font is a dependency).

**How to avoid:** P1 writes a **surface map** (surface to brand owner: Sigra or host). Freeze `Profile.defaults/0` values (additive new keys only). Make the admin typeface an opt-in token (`--sg-font-sans`, default inheriting host) rather than a hard-coded family. Change the passkey default RP name to the resolved product name. Add a tiny lint that flags a literal "Sigra" in user-facing default strings under `priv/templates/sigra.install/core` (allowlist: the opt-in footer). Never default-on an attribution footer.

**Warning signs:** Kiln-coloured primary buttons or the typemark appearing in the example app's host-facing auth pages; `@defaults` map in `profile.ex` in a diff; a font-family declaration landing on `.sigra-auth` or `.sg-root`.

**Phase to address:** P1 (surface map), P3 (tokens/fonts as opt-in), P4 (SEED-010 apply).

---

### C9: Dark-mode and contrast regressions the brand book's pair table does not cover

**What goes wrong:** I recomputed the brand book's stated ratios; the table is accurate (for example Kiln Deep on Paper 6.61:1, Kiln Bright on Char 7.50:1). [verified] The gaps are in what is *not* in the table:
- **White text on Kiln Bright is 2.48:1 (fail).** The dark button label must be Char (7.50:1). The existing token `--sg-color-on-brand` is `#ffffff` in both themes, and `Sigra.Branding.Contrast.readable_foreground/1` chooses pure black or white, not Char.
- The margin on "status word on a selected row" in light is **4.61:1 against a 4.5:1 minimum**; any tint change to Selected Paper or the ochre breaks it. Non-text pairs (focus ring, control edge 4.01:1 on Paper, status marks) need the 3:1 rule.
- Hover, pressed, disabled and placeholder states are not in the table; the current auth CSS derives hover with `color-mix(in oklab, accent 94%, white)`.
- axe's `color-contrast` rule reports gradients, pseudo-elements and opacity as "incomplete", and does not test non-text contrast, so "axe green" is not "contrast verified". `sigra_auth.css` uses a radial-gradient background.
- Host dark accents derived by `Sigra.Branding.Contrast` are fitted to the old dark surface (`#1f1d1a`-family); moving surfaces to Char Surface (`#221B17`) shifts derived results.
- The brand's "no red anywhere" for statuses collides with current `data-tone="risk"` on Locked; the admin glossary reserves red for destructive/business harm.

**How to avoid:** One deterministic browser test (no PNGs) that reads resolved custom properties via `getComputedStyle` for each stable pair id in the brand JSON, in light, dark and system, including hover/focus/disabled states, and asserts the minimum. Add a positive control (a deliberately bad colour must fail). Keep axe as the independent guard but do not count it as contrast proof. Add dark `--sg-color-on-brand` explicitly. Keep `data-tone` names; change only the values behind them. Do not alter `Sigra.Branding.Contrast` semantics in this milestone.

**Warning signs:** A single `--sg-color-on-brand: #fff` shared by both themes; contrast verified only by eye or by axe; dark selected-row text hovering at the minimum.

**Phase to address:** P3.

---

### C10: Fonts: licensing conditions, serving, subsetting and package weight

**What goes wrong:** Both families are SIL OFL 1.1 and neither licence header declares a Reserved Font Name [verified in the shipped licence texts], so bundling and subsetting are allowed. Conditions still bite:
- OFL clause 2 requires **each copy** to carry the copyright notice and licence text. Fonts copied into an adopter's repo by the generator, and into the Hex tarball, need the two `OFL-*.txt` files beside them. The woff2 files are compressed, so do not rely on embedded metadata. [OFL text read; MEDIUM on legal interpretation, not legal advice]
- Hex size is not the threat: current payload is about 2.9 MB uncompressed and Hex documents at least 8 MB compressed / 64 MB uncompressed (newer hex_core appears to allow 16/128 MiB; unverified). [MEDIUM] The risk is `files: ~w(lib priv docs ...)` shipping whatever lands in `priv/` or `docs/`: the reference `brand/` tree is 3.4 MB (a 1.3 MB PDF, 320 KB HTML, ~900 KB static TTFs, ~260 KB variable TTFs). Ship only the two woff2 files (~37 KB) plus licences.
- The shipped `fonts.css` uses relative `url('sans.woff2')`, which resolves relative to the CSS file's location (`/assets/...`) in a host, not `/fonts/`. [inferred] Phoenix's default `static_paths` include `fonts`, so serve there with absolute URLs.
- Latin subset only: other scripts fall back, which collides with SEED-003 locale work. `font-display: swap` causes layout shift and flaky screenshots. Red Hat Mono has no arrow glyphs; generated auth uses `&rarr;` 12 times (in the sans, which has them).
- Never load from a Google Fonts CDN (CSP `font-src`, GDPR exposure, offline demos).

**How to avoid:** Generator emits `priv/static/fonts/{sans,mono}.woff2` plus both licence files; CSS references absolute `/fonts/...`; stack ends in the system fallback with `size-adjust` tuned if feasible; admin font stays opt-in (C8). Verify the tarball with `mix hex.build --unpack` and check its file list and size delta in the P3 gate.

**Warning signs:** Any `fonts.googleapis.com`; `brand/` or `*.ttf` appearing in the unpacked tarball; no OFL file next to generated fonts.

**Phase to address:** P3 (assets, serving), P5 (tarball check, HexDocs).

---

### C11: Naming, trademark and "first/only" claims made too early (or implied by "clearance")

**What goes wrong:** The brand book is candid: no trademark register was searched; the name was "kept, not cleared"; the logo is "a stock grotesque with a square above the i"; no one has viewed the favicon at 16-24 px; the lead line was tested on no readers; Safari and Firefox were not checked; the ExDoc stylesheet has never run in a real ExDoc build. Repo-specific additions:
- A same-name Hex package exists today: `crosswake_sigra` ("Sigra auth companion adapter for the Crosswake route-policy system"). [verified via Hex search] The book's "no conflict in Elixir" lookup missed it; confirm ownership and record it.
- The book lists same-name non-Elixir uses, one of them a Swedish e-signing service using BankID (identity-adjacent), which matters if the product is marketed in Swedish or to identity buyers.
- The book says the logo is MIT-licensed "unless the repo says otherwise" while also saying "do not alter the logo"; MIT permits alteration. Needs a maintainer decision and an explicit logo-use statement; do not resolve by assertion.
- The brand JSON and BRAND.md disagree on clear space ("one quarter of the typemark height" versus "2 T"). A contract test generated from the JSON would encode the wrong one.
- "Hardened primitives" is in the approved description; keep it only if `SECURITY.md` supports it. README currently asserts "Pow does not support Phoenix 1.8+" (stale-risk competitor claim; not verified here). [LOW]

**How to avoid:** P1's name-clearance record is titled **"search log, not clearance"** and lists what was and was not searched, including `crosswake_sigra`. A short **claims register** (claim, source, verified/unverified) gates P5 copy. No ™, ®, "cleared", "available", "unique", "first", "only" or "best" in any public text until the maintainer decides and (for ™) takes advice. Resolve the clear-space and logo-licence conflicts in P1 by choosing an authority file and noting the decision. Run a real `mix docs` build in light and dark before claiming HexDocs styling.

**Warning signs:** ™ in a README header; "cleared" anywhere; an announcement draft written before the P5 gate.

**Phase to address:** P1 (record, claims register, authority decisions), P5 (gate).

---

### C12: Privacy: personal names, home paths and the brand book's authoring project leaking into a public repo

**What goes wrong:** v1.50's planning receipts leaked home-directory paths and a personal name into about 3,500 tracked files; the CI guard is still only a pending todo (`2026-11-13-ci-guard-for-personal-name-and-home-paths.md`), so nothing automated protects this milestone. New leak vectors here: importing `brand/` (HTML, PDF, JSON, a provenance note), before-screen catalog artifacts, screenshots from a dev database or per-branch dev hostnames, commit messages and PR bodies, planning docs that name the brand book's origin or contain absolute source paths, and hash-pin "provenance" lines.

**How to avoid:**
- Import only files tests and docs consume; scan each imported file (including SVG/PDF metadata) before commit for home paths, the maintainer's name and the authoring project's name. Refer to it only as "the brand book, v2.0".
- Provenance text is "brand book v2.0 (2026-11-13)", never a filesystem path.
- Catalog and fixtures use seeded `.test` addresses only; never a dev DB; no committed browser screenshots with chrome or URL bars.
- Either land the CI guard (shrink-only baseline plus a planted-failure test) first, or run an explicit grep of the **pushed diff, including binaries,** at each phase gate. Never rewrite pushed history without an explicit decision (pushes to main are ruleset-blocked).

**Warning signs:** A PR that adds PNG/PDF/JSON files without a scan line in the description; a home-directory path (macOS or Linux style) in any diff; the authoring project's name in a doc, commit or alt text.

**Phase to address:** P1 (import and scan, optionally the guard), re-checked at every phase gate.

---

### C13: Phase-ordering traps

**What goes wrong / how to avoid:**
- **Visual change before the baseline decision.** P3 before the P2 park PR = red `ci-gate` (C6). Order: P2 catalog, then park PR, then P3.
- **"Before" screens captured too late.** Capture from a pinned `main` SHA at the start of P2, before any visual commit; otherwise the before/after is polluted.
- **Copy change after golden churn.** If P4 rewrites strings after P3 regenerated the golden, you re-bless twice and re-review everything. P1 settles the copy contract and tiers; P4 applies it mechanically in one pass per surface.
- **Operator job first, then every screen.** Do one job end to end (for example "find why a user cannot sign in": Users list, detail, sessions, audit) through all of C2/C3/C9 before fanning out; the brand book's layouts are drawings of a proposal, "not the product's current screen", and its own list says generated sign-in, two-factor and email screens were never viewed running.
- **Announcement before assets are published.** README header images referenced by relative path break on hex.pm and HexDocs; use pinned absolute URLs (tag or SHA, not `main`) or ExDoc `assets`. ExDoc "View source" requires the `v#{@version}` tag to exist. [inferred] No tag, push, merge or release without approval.
- **Release mechanics.** Release Please derives the version from conventional commits: a stray `!` or `BREAKING CHANGE:` footer on a brand PR proposes 2.0.0. CHANGELOG text written under "Unreleased" ships inside the tarball unless folded into the release section by hand (warning already in `CHANGELOG.md`).
- **Stale agent instructions.** `CLAUDE.md` and `AGENTS.md` still say "use the Rail Accent brand assets from `brandbook/`", and `guides/reference/admin-*` cite `brandbook/`. Executors will follow them to the retired logo. Update these in P1. `test/sigra/architecture_guides_contract_test.exs` pins `favicon: "brandbook/favicon.svg"` and `#c2410c`; `mix.exs` ExDoc config does too. `brandbook/` stays until replaced deliberately, so mark it retired in a README pointer and move the pins in P5.
- **Name collision in planning.** "Brand v2" already means the v1.38 Linked Rail logo; call this one "brand book v2.0 (Kiln)" in all artifacts.

**Phase to address:** P1 (ordering and instructions), P2 (capture pin), P5 (publication and release mechanics).

---

### C14: Brand vocabulary that the product cannot produce (scope creep disguised as copy)

**What goes wrong:** The book's five statuses are Active, Unconfirmed, Locked, Suspended, Deleting. Product reality: there is **no suspended state** in lib or the generated schema (grep for `suspend` finds only worker modules), the current labels are "Confirmed" and "Deletion scheduled" (a reversible grace period; "Deleting" reads as in-progress and irreversible, misleading an operator), the "Needs an admin" grouping and "unconfirmed for more than seven days" are the book's **proposals** (it says so), and "Admin (operator)" is flagged by the book as a label to change. Shipping the new vocabulary requires data-model and query work the milestone does not scope, and each label is pinned by tests.

**How to avoid:** P1 produces a vocabulary map: brand term, product state it truthfully maps to, decision (adopt label / keep label / defer feature / reject). Render only statuses the model can produce; do not ship "Suspended" UI. Keep "Deletion scheduled" unless the maintainer decides otherwise with the operator consequence written down. New mark markup is additive (C2).

**Warning signs:** A migration or new query appearing in a "brand" PR; a status chip with no backing field.

**Phase to address:** P1 (map and decision), P4 (apply).

---

## Moderate Pitfalls

| # | Pitfall | Prevention | Phase |
|---|---------|------------|-------|
| M1 | **SEED-003 balloons** into admin-managed copy, RTL and per-org wording (a feature, not brand work). `Sigra.Branding.Profile` says not to add copy fields without revisiting the seed. | Bound it to: audit msgid coverage in generated templates, document the `gettext.extract`/`merge` workflow, add a locale setup note. No runtime copy map. | P4 |
| M2 | **Existing guards fire on new tokens.** `scripts/ci/admin-css-conformance.sh` (no raw hex outside `:root`, no raw px in token contexts), `admin-token-completeness.sh` (every `--sg-*` documented in `guides/reference/admin-token-reference.md`), `app-css-corruption-check.sh`. | Budget the doc rows; add tokens, never literals. Decide up front which of these stay (they protect shipped CSS) versus which belong to the cut UI-process lane. | P3 |
| M3 | **Retired vocabulary inside public token names** (`--sg-logo-rail-accent`, `--sg-logo-rail-ember`, `--sg-logo-core`). | Keep names (compat policy), add new names as the documented ones with old as aliases; never leave "rail"/"Ember" in prose docs. | P3 |
| M4 | **Example app drift.** Example auth CSS differs from the template; the example is hand-maintained. | Generate or parity-test (P2); fix before judging "before" screens. | P2 |
| M5 | **Favicon edge cases.** The ICO is light-only; the SVG theme swap follows the device preference, not the app's theme toggle; Safari/Firefox untested by the book; 16 px unviewed and may read as an information icon. | Test in real browsers in P3; keep both ICO and SVG; do not claim dark-tab support until observed. [MEDIUM] | P3 |
| M6 | **Stale demo name** "Vaultr" remains in README, `docs/launch/v1.0/announcement.md`, `scripts/uat/up.sh` and in a comment inside the shipped `sigra_admin.css`. | Fix the shipped CSS comment in P3 (it ships), docs in P5. | P3, P5 |
| M7 | **ExDoc stylesheet never run in a real build.** Class names were written from memory of ExDoc's markup. | Run `mix docs --warnings-as-errors`, open light and dark, fix selectors against the real DOM. | P5 |
| M8 | **Typemark minimum is 96 px wide** and the symbol 16 px; the admin top row and HexDocs sidebar sizes are set by other CSS. | Check rendered widths in the catalog; do not scale below minimum. | P3 |
| M9 | **Hash pin brittleness.** Whole-tree hash over binaries including a PDF; line-ending normalisation; hash receipts that bind other files. | Hash only consumed files, mark binaries `-text` in `.gitattributes`, no receipts (C7). Pick one authority between BRAND.md and the JSON. | P1 |
| M10 | **Time-zone rule** ("2:07 PM UTC") and tabular numerals change date formatting; tests regex on current formats. | Make format a single helper; update pins in the same commit. | P4 |
| M11 | **Daisy-style class in lib.** `lib/sigra/admin/components.ex:1099` still emits `btn btn-primary` ("Send magic link"). | Fix with SEED-010 under the additive rule (C2). | P4 |

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Recapture all 115 PNGs to get green | One merge | Perpetuates the cut machinery and the canary deadlock; ubuntu-only churn | Never per phase; at most once, CI-native, batched, if the catalog is not ready |
| Bulk "Log in" to "Sign in" replace | Brand-consistent in minutes | Dead translations, adopter test breaks, email subject drift | Never; targeted per tier (C3) |
| Hard-coded brand hex in templates | Fast | Fails conformance guard; defeats token overrides | Never |
| Keep both `brandbook/` and `brand/` | No big-bang deletion | Two sources of truth, stale agent instructions | Temporarily, with a retirement pointer and rewired pins; delete in a later deliberate PR |
| Copy brand book snippets verbatim | Saves editing | Phantom-version install (C1), wrong claims | Never |
| Per-phase hash receipts | Feels rigorous | v1.50 sprawl | Never |
| Reuse the example app as proof | Already there | Drifts from templates (M4) | Only after parity test |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Hex resolver | Two-segment requirement with a retired 1.20.0 present | Three-segment `~> 1.7.0`; verify in a scratch project before publishing docs |
| Hex tarball | `files:` includes all of `priv` and `docs` | Unpack and list; only woff2 + OFL + logos |
| Installer | Assuming re-running refreshes CSS | It skips existing files; document and add doctor stamp (C2) |
| Gettext | Editing msgids | Add, never rewrite; no `.po` shipped, adopters own theirs |
| Phoenix static serving | CSS-relative font URLs | Absolute `/fonts/...`; `static_paths` already allow `fonts` |
| Host CSP | Remote font CDN | Self-host only |
| Release Please | Brand commit with `!` or BREAKING footer; notes under Unreleased | Plain `feat`/`fix`/`docs`; fold notes by hand |
| `phx_new` archive | Local version differs from pin | Install 1.8.8 before golden work |
| ExDoc | Styling written without a build | Real `mix docs` in both themes |
| GitHub README vs hex.pm/HexDocs | Relative image paths and `<picture>` dark switch | Pinned absolute URLs; accept that dark switching is GitHub-only |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Web font swap | Layout shift in admin tables; flaky screenshots | `font-display` choice, fallback metrics, wait on `fonts.ready` | First load on cold cache |
| Larger CSS | 41 KB + 32 KB already; tokens and states grow it | Add tokens, not duplicates; keep layers | Gradual; watch the golden delta |
| Playwright PNG lanes on every PR | Long critical path; red on any visual change | Park lanes (C6) | First visual commit |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Specific copy on pre-auth pages | Account enumeration | Public-surface registry plus parity test (C4) |
| Changing `Sigra.Error.safe_message/1` | Weakens a documented enumeration contract; breaks adopter asserts | Frozen tier (C3) |
| Default passkey RP name "Sigra" | End users see the library's name; later rename breaks nothing but confuses | Default to product name (C8) |
| Remote fonts or analytics in generated pages | Referrer leakage, CSP breakage | Self-host, no third-party requests |
| Seeded or dev data in catalog | PII in a public repo | Seeded `.test` data only (C12) |
| Status colour as only cue | Accessibility and misreads | Word first, mark second, per brand rule; test with colour stripped |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| "Deleting" for a scheduled, reversible deletion | Operator thinks it is irreversible or running | Keep "Deletion scheduled" or add explicit sentence (C14) |
| Dark main button with white label | 2.48:1, unreadable | Char label on Kiln Bright (C9) |
| Brand layouts shipped as if verified | Real data (long emails, empty states) breaks them | Build one job against realistic fixtures first (C13) |
| Tab square plus status mark side by side | Visual collision the book says to avoid | Selected row uses the rule, tab uses the square |
| Admin imposing a typeface in a host app | Mismatch with host; bigger payload | Opt-in token, inherit by default (C8) |

## "Looks Done But Isn't" Checklist

- [ ] **Install snippet:** every `{:sigra, ...}` is three-segment; a scratch `mix deps.get` resolves a non-retired release.
- [ ] **Skew:** new lib admin markup renders acceptably against the previous release's `sigra_admin.css`.
- [ ] **Fresh host:** `phx_new 1.8.8` + `mix sigra.install` + boot + real login + admin in light, dark and system.
- [ ] **Golden:** `MIX_ENV=test mix sigra.fixture.rebless_golden --check` clean; delta reviewed per directory; filenames unchanged.
- [ ] **Local gate:** `MIX_ENV=test mix ci` green (root `mix test` alone misses formatting and `test/example`).
- [ ] **Enumeration parity:** every pre-auth flow identical for existing and non-existing identities; positive control shown red once.
- [ ] **Contrast:** computed-style test covers every stable pair id, both themes, plus hover/focus/disabled; axe not counted as contrast proof.
- [ ] **Tarball:** `mix hex.build --unpack` shows woff2 + OFL + logos, no `brand/`, no TTFs; size delta recorded.
- [ ] **PII scan:** grep of the pushed diff including binaries and SVG/PDF metadata: no home paths, no maintainer name, no authoring-project name.
- [ ] **Claims:** no ™/®, "cleared", "first/only/best"; every public claim in the register has a source.
- [ ] **Process budget:** no new workflow; `scripts/ci` additions justified; no receipts.
- [ ] **Docs build:** `mix docs --warnings-as-errors` passes and the result was looked at in both themes.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Phantom-version snippet published (C1) | LOW | Patch README/guides; Hex page text refreshes on next publish; note in CHANGELOG |
| Skew shipped (C2) | MEDIUM | Patch release restoring legacy selectors; upgrade note; doctor warning |
| Copy contract broken (C3) | MEDIUM | Revert string tier in a patch; restore msgid; add the missing contract test |
| Enumeration leak (C4) | HIGH | Security patch; treat as vulnerability per `SECURITY.md`; add parity test |
| PNG deadlock (C6) | MEDIUM | Land the park PR; do not allowlist the canary |
| PII pushed (C12) | HIGH | Public history; needs an explicit maintainer decision on rewrite (ruleset blocks force-push); prevention is the only cheap path |
| Over-process regrowth (C7) | MEDIUM | Stop, delete the artifact, change the failed prerequisite |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| C1 phantom 1.20.0 | P1, P5 | Snippet test; scratch resolve |
| C2 lib/host skew | P1, P2 | Old-CSS render test; doctor stamp |
| C3 wording as API | P1, P4 | Tiered contract test with positive control |
| C4 enumeration via voice | P1, P4 | Existing-vs-missing parity test |
| C5 generated churn | P2, P3, P4 | `rebless_golden --check`; one rebless per phase |
| C6 PNG gate and canary | P1, P2 | Park PR merged before P3; `ci-gate` green on a token PR |
| C7 over-process | All | Diff-stat budget on `.github`/`scripts`; merged PRs counted |
| C8 Sigra brand on host users | P1, P3, P4 | Surface map; "Sigra" literal lint; defaults unchanged |
| C9 contrast and dark | P3 | Computed-style pair test, both themes |
| C10 fonts | P3, P5 | Tarball listing; OFL files present; no CDN |
| C11 claims and trademark | P1, P5 | Claims register; "search log, not clearance" |
| C12 privacy | P1 and every gate | Pushed-diff grep incl. binaries |
| C13 ordering | P1, P2, P5 | Park PR before P3; before-screens pinned SHA |
| C14 vocabulary vs data | P1, P4 | Vocabulary map; no UI without backing state |

## Ranked Top 10

Ranked by likelihood times blast radius times how hard it is to undo.

| Rank | Pitfall | Why it ranks here | Phase |
|------|---------|-------------------|-------|
| 1 | **C1** Brand book snippet `~> 1.7` resolves to retired 1.20.0 | Reproduced live; adopter-facing; copy-paste from the source material; trivially preventable with a test | P1, P5 |
| 2 | **C6** PNG baselines plus canary rule make any visual change un-mergeable | Certain at first P3 commit; blocks all merges; has bitten before | P1, P2 |
| 3 | **C2** Lib markup updates, host CSS does not | Silent breakage for adopters who update; installer skips existing files | P1, P2 |
| 4 | **C3** "Just wording" as public API (errors, flashes, msgids, labels) | SemVer and translation damage that tests will not show | P1, P4 |
| 5 | **C12** PII and authoring-project leakage into a public repo | Hard to undo; last milestone leaked thousands of files; guard still a todo | P1, every gate |
| 6 | **C8** Sigra brand on the host's users (RP name, defaults, fonts, attribution) | Violates the brand book's own central rule; adopter-visible defaults | P1, P3, P4 |
| 7 | **C4** Enumeration leak through brand voice | Security regression disguised as copy; stacks on open timing oracle | P1, P4 |
| 8 | **C5** Unreviewable generated-output diff | Likely if phases regenerate together; adopters hand-merge | P2 |
| 9 | **C7** Re-growing evidence machinery | Directly repeats v1.50; kills the milestone by volume | All |
| 10 | **C9** Dark/contrast traps (white label on Kiln Bright 2.48:1, 4.61:1 margin, axe blind spots) | Concrete, reproducible, P3-contained | P3 |

Next in line (tracked, not top 10): C11 claims/trademark, C13 ordering, C14 vocabulary vs data model, C10 fonts.

## Sources

- Live Hex check, 2026-11-13: Hex API for `sigra` (releases, retirement of 1.20.0 with reason `invalid`) and a scratch-project `mix deps.get` for `~> 1.7` (resolved 1.20.0 RETIRED) and `~> 1.7.0` (resolved 1.7.1) [HIGH]
- Hex package search showing `crosswake_sigra` [HIGH]
- Hex publish limits: [mix hex.publish docs (v2.5.1)](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) state 8 MB compressed / 64 MB uncompressed; newer hex_core changes suggest 16/128 MiB, unverified [MEDIUM]
- Repo files read: `.planning/PROJECT.md`, `.planning/MILESTONE-ARC.md`, `.planning/notes/2026-11-13-v1.50-closeout-lessons-and-cuts.md`, `.planning/todos/pending/2026-11-13-*.md`, `.planning/seeds/SEED-003-*`, `SEED-010-*`, `.github/workflows/ci.yml`, `scripts/ci/snapshot-canary-guard.sh`, `scripts/ci/admin-css-conformance.sh`, `lib/sigra/error.ex`, `lib/sigra/branding/profile.ex`, `lib/sigra/branding/contrast.ex`, `lib/sigra/install/runner.ex`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `priv/templates/sigra.install/**`, `test/fixtures/install_golden/**`, `test/sigra/admin/glossary_test.exs`, `test/sigra/architecture_guides_contract_test.exs`, `guides/introduction/installation.md`, `guides/introduction/contract.md`, `guides/introduction/upgrading-to-v1.46.md`, `guides/reference/admin-token-reference.md`, `MAINTAINING.md`, `CHANGELOG.md`, `mix.exs`, `release-please-config.json`, `CLAUDE.md`, `AGENTS.md` [HIGH]
- Brand book v2.0 reference copy (`brand/`): `BRAND.md`, `brand.json`, `assets/README.md`, font licence texts; contrast ratios recomputed independently from the stated hex values [HIGH for ratios; the legal readings are MEDIUM and are not legal advice]

---
*Pitfalls research for: brand adoption in a SemVer-governed Elixir/Phoenix auth library with a hybrid lib + generator architecture*
*Researched: 2026-11-13*
