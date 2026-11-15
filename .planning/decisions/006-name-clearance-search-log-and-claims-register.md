# ADR 006: Name and trademark posture: search log, not clearance

**Status:** Accepted (record). This is a search log and not a clearance. No trademark search, no look-alike search and no register search was performed, and nothing here is legal advice. Both decisions in this record are recommended defaults, owner confirmation pending.
**Date:** 2026-11-13 (lookups); the `crosswake_sigra` lookup was re-run on 2026-11-14 and is dated separately below.
**Context:** Phase 259 (v1.51 brand identity adoption), requirements BPOL-04 and BCOPY-07. The visual source is brand book v2.0 (2026-11-13), vendored read-only in `brand/`. Phase 263 writes public copy; this record states what that copy may and may not say about the name and about enumeration before any of it is written.

## What this record is and is not

This record is:

- a dated log of the name lookups that were run, with each result as observed;
- a note about one same-name Hex package, `crosswake_sigra`;
- two recorded decisions (clear-space authority and logo-use wording) that the vendored book leaves open or states twice;
- a claims register: the public claims Sigra makes, where each appears, what supports it, and whether it is proven, bounded or not proven.

This record is not:

- a clearance of the name or of the logo, in any jurisdiction;
- a trademark search, a look-alike search or a search of any trademark register;
- legal advice, or a statement that the name is free to use or free of conflict.

Lookup results are data from public registries, recorded as observed. A registry that returns nothing for a name shows only that the registry has nothing under that exact name on that date.

## Lookup table

| Registry | Query | Result | Date |
|----------|-------|--------|------|
| Hex | package `sigra` | This project's own package. Its Hex page also lists a stray 1.20.0 release that is retired but still reported as the latest stable version (see ADR 005). | 2026-11-13 |
| Hex | package `crosswake_sigra` | Exists: latest stable 0.1.3, Apache-2.0. See the next section. | 2026-11-13, re-run 2026-11-14 (same result) |
| npm | package `sigra` | 404, no such package | 2026-11-13 |
| PyPI | project `sigra` | 404, no such project | 2026-11-13 |
| RubyGems | gem `sigra` | 404, no such gem | 2026-11-13 |
| crates.io | crate `sigra` | Does not exist | 2026-11-13 |
| GitHub | repository name search for `sigra` | 279 repositories, including unrelated projects (for example a bioinformatics project named SiGra and a PHP learning-results system). The record does not claim each result was reviewed. | 2026-11-13 |

The rows dated 2026-11-13 come from the Phase 259 research session and were not repeated. Only the `crosswake_sigra` row was re-run, on 2026-11-14, through the public Hex API. The vendored book's own "Not checked" paragraph carries the same limits (no trademark register searched, no look-alike search for a square-dot wordmark); this record neither repeats nor verifies the other lookups that paragraph mentions.

## The same-name package: `crosswake_sigra`

Facts as observed on the Hex API:

- Name: `crosswake_sigra`, latest stable version 0.1.3 (releases 0.1.1 on 2026-07-03, the first release, and 0.1.3 on 2026-08-09).
- License: Apache-2.0.
- Description: "Sigra auth companion adapter for the Crosswake route-policy system."
- Downloads: 463 in total at the 2026-11-14 lookup.
- Links: its repository link is under the same GitHub owner as this repository's `source_url`.

Reading: it appears to be an own-ecosystem companion of this project, an adapter that names Sigra in its description and sits under the same owner. Ownership is to be confirmed by the maintainer: maintainer to confirm, pending maintainer confirmation. The Hex API response used does not state who owns the package beyond that repository link.

What this record does NOT conclude:

- It does not conclude that the package belongs to this project's maintainer. The shared owner is evidence, not proof.
- It does not treat the package as a third-party conflict, and it does not treat it as support for any claim about the name.
- It does not say that using "sigra" inside another package name is permitted or endorsed, or the reverse.
- The different licenses (Apache-2.0 there, MIT here) are recorded as a fact and are not assessed.

## Decision: no trademark claim

Sigra makes no trademark claim for its name or its logo. No trademark symbol of either kind, and no wording that presents the name or the logo as a registered mark, appears in the documentation Sigra publishes. If the maintainers later decide to claim the name, that is a separate decision that follows a register search and a look-alike search and gets its own record.

Status: recommended default, owner confirmation pending.

Reversibility: cheap. Making a claim later is a new decision; declining to make one now closes nothing.

## Decision: clear-space authority

Label: clear-space. Status: recommended default, owner confirmation pending.

The vendored book states the logo's clear space three times, in two different ways:

| Statement | Where | Rule |
|-----------|-------|------|
| Prose, in the logo section | `brand/BRAND.md` | "2 T, twice the square's side", measured from the outermost edge of the typemark |
| Construction table row | `brand/BRAND.md` | 2 T on every side |
| `logo.clear` | `brand/brand.json` | the same 2 T sentence as the prose |
| `logo.clearSpace` | `brand/brand.json` | "one quarter of the typemark height on every side, measured from the outermost ink" |

So `brand/brand.json` disagrees with itself: its `logo.clear` key says 2 T and its `logo.clearSpace` key says a quarter of the typemark height.

Measured on 2026-11-13 in the pinned files, in one shared coordinate space (both files start at the same vertical origin):

- `brand/assets/logo/sigra-symbol-light.svg` has `viewBox="594.6 -720.0 150.0 720.0"`. The stem and the square are 150 units wide, so T = 150 units and 2 T = 300 units.
- `brand/assets/logo/sigra-lockup-light.svg` has `viewBox="16.0 -720.0 2305.3 935.0"`. The typemark is 935 units high, so one quarter of its height is 233.75 units, about 1.56 T.

The two rules differ by 66.25 units (300 against 233.75), about 0.44 T. The prose rule is the stricter one.

Recommended default: the book's prose rule of 2 T is the authority for clear space. It is stated in prose twice and once in the JSON, it is the stricter rule, and it is defined from the square, which is the one dimension every logo file shares. The quarter-height value in `logo.clearSpace` is not used as a requirement. The vendored files are pinned by `brand.sha256` and are not edited, so the disagreement stays in the pinned source and is named here rather than quietly resolved. A search of the repository outside `brand/`, `brandbook/` and planning files finds no code or template that reads either value. The retired `brandbook/` source carries older clear-space statements of its own; it is not the source for the v2.0 book and is left untouched.

Reversibility: cheap. No shipped bytes read the value; the decision changes only what later documentation may say.

## Decision: logo-use statement wording

Label: logo-use. Status: recommended default, owner confirmation pending.

The book's JSON carries a "use by others" list: Hex packages, blogs, newsletters and conference sites may use the typemark unchanged to refer to Sigra; it must not suggest that Sigra endorses another product; it must not be altered or rebuilt from its parts. The book's legal lines say the logo and the book are covered by the project's MIT license unless the repository says otherwise, and the repository's license file is the plain MIT text with no logo carve-out.

Recommended wording for a public statement (to be published by Phase 263, not by this phase):

> You may use the Sigra logo, unchanged, to refer to Sigra. Do not use it in a way that suggests Sigra endorses your product or project. Do not alter the logo or build a new one from its parts. Any other use needs the maintainers' approval.

Reconciliation with the MIT license: the license text is unchanged and keeps granting its usual rights over the files. The statement does not add license terms. It states how the maintainers ask the logo to be used when it presents Sigra's identity: unchanged, to refer to the project, with no implied endorsement, and with approval for modification. Whether the repository should carve the logo out of the MIT grant, so that the request becomes a term, is a separate owner decision that this record does not make.

Reversibility: cheap. The wording is unpublished until Phase 263, and a published statement can be reworded with a dated amendment.

## Claims register

Each row is a public claim Sigra makes or a boundary Phase 263 copy must respect. Status values:

- **proven**: an automated test asserts exactly what is claimed.
- **bounded**: proven only on the dimensions named in the Evidence column; the claim may be restated with those bounds and not more broadly.
- **not proven**: nothing asserts the claim. A known divergence is asserted to still differ, which shrinks the registry when it is fixed.
- **by design**: the documented behaviour is asserted; it is not an identity-parity claim.

### Enumeration (surface registry rows)

Evidence for every row below is `test/fixtures/brand/public-surfaces.json` and `test/example/test/example_web/enumeration_parity_test.exs`, run in the example host.

| Claim | Where it appears | Evidence | Status |
|-------|------------------|----------|--------|
| Sign-in shows one message for an existing and an unknown address | README "Enumeration" row; `guides/flows/login-and-logout.md` with its scope paragraph | `password-signin`: status, redirect, flash and body for one failed attempt, fresh state | bounded |
| A magic-link request answers the same for an existing and an unknown address | README "Enumeration" row | `magic-link-request`: status, redirect, flash and body for one request, fresh state; delivery, timing and the rate limit not compared | bounded |
| A wrong authenticator code and a wrong backup code get the same outcome | No published page; recorded to bound any later claim | `mfa-challenge`: outcome, redirect and flash including the remaining-attempts count; identity is the code kind, not account existence, so this row is counted separately from the account-existence surfaces and cannot stand in for them | bounded |
| A password reset request shows one message for an existing and an unknown address | README "Enumeration" row, which names reset requests among the tested cases at a single attempt in the example application and lists the generated code among what is not compared; `guides/flows/password-reset.md` scope paragraph, which bounds the comparison to the example application at a single attempt and tells the reader to check the request page in their own application | `password-reset-request`: status, redirect, flash and body for one reset request submitted through the LiveView form, fresh state; delivery, timing and the rate limit not compared; run in the example host only, the generated reset page is not compared | bounded |
| An anonymous confirmation resend ignores a visitor-supplied email | No published page | `confirmation-resend`: status, redirect, flash, body and confirmation tokens created for an anonymous resend event carrying an existing versus an unknown email; the handler takes its target from the session, so this shows a visitor-supplied email is ignored, not that an email-keyed resend form exists; signed-in resends, timing and rate limits not compared; run in the example host only, so this is example-host evidence and says nothing about a generated host; counted separately from the account-existence surfaces, because it proves a payload email is ignored, not that an existing and an unknown address answer alike | bounded |
| A duplicate registration looks like a new one | `guides/flows/registration.md` scope paragraph; README lists registration as not covered | `registration`: asserted to differ on body and flash, and a timing difference is tracked by todo | not proven (divergence asserted) |
| Passkey sign-in options do not reveal whether an address has an account | README lists passkey sign-in as not covered; no page claims it safe | `passkey-signin-options`: asserted to differ in its JSON keys; a real existence oracle with a filed todo; must not be cited as a safety proof | not proven (divergence asserted) |
| Repeated failed sign-ins look the same for an existing and an unknown address | `guides/flows/login-and-logout.md` scope paragraph; README lists repeated attempts as not covered | `password-signin-repeat-attempts`: asserted at library level, an existing account becomes locked and an unknown address never does; masked at the example controller | not proven (divergence asserted) |
| An invitation link reveals nothing about whether the invitee has an account | No published page claims identity parity for it | `invitation-accept`: the link is a capability, and the same signup branch is shown either way | by design |
| Enterprise SSO discovery reveals nothing about whether an address has an account | No published page; an earlier unknown-address promise on the enterprise branch was removed from the introduction guides | `enterprise-sso-discovery`: the answer is per email domain, identical for a registered and an unregistered address on one domain | by design |
| Magic-link requests are throttled the same for existing and unknown addresses | README lists rate limits as not covered | `magic-link-rate-limit`: nothing compared, the example host passes no limiter, and the library applies its limiter to existing users only | not proven |
| Password reset requests are throttled the same for existing and unknown addresses | `guides/flows/password-reset.md` rate-limit sentence, kept conditional; README lists rate limits as not covered | `password-reset-rate-limit`: nothing compared, for the same reason; the guide's configuration block also does not match the config schema, and the generated context passes no limiter (see the phase deferred items file in `.planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/`) | not proven |
| Library module documentation states enumeration safety | `lib/sigra/lockout.ex`, `lib/sigra/error.ex` and `lib/sigra/auth.ex` documentation, published on HexDocs | `lib-moduledoc-claims`: prose, no probe; the over-claims are tracked by the todo `.planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md` and cannot be edited in this phase because it carries zero library bytes | not proven |

### Policy and source

| Claim | Where it appears | Evidence | Status |
|-------|------------------|----------|--------|
| Every documented dependency snippet is one three-segment `~> X.Y.Z` requirement and all are equal | README, `guides/`, `docs/`, installer templates | `test/sigra/brand/install_snippet_test.exs`: shape and equality only, never the value; the value bump belongs to Phase 263 | proven |
| `brand/` is the pinned brand book v2.0, unmodified | `brand.sha256`, `.gitattributes`, `guides/reference/brand-compatibility.md` | `brand.sha256` (72 files) and `test/sigra/brand/source_pin_test.exs`, which turns red on any added, removed or changed file | proven |
| The vendored `brand/` tree carries no personal data | `brand.sha256` provenance | `test/sigra/brand/source_pin_test.exs` scans home paths, addresses and file metadata on every run; personal names are checked at the Phase 259 gate with a value derived at run time and recorded in that plan's summary, and are not re-checked by a test | bounded |
| Frozen host-visible names can be added to but not removed or renamed | ADR 005; `guides/reference/brand-compatibility.md` | `test/sigra/brand/frozen_surface_test.exs` and `test/sigra/brand/legacy_profiles_test.exs`: the categories listed in `test/fixtures/brand/frozen-surface.json` only; message ids are not an add-only category; a change to one shows up as a changed row in the copy inventory below | bounded |
| Shipped copy was inventoried per ownership lane | `test/fixtures/brand/copy-inventory/` | `test/sigra/brand/copy_inventory_test.exs`: exact equality with a fresh extraction; some copy forms are not extracted (raw string literals in installer templates, HEEx attribute copy, browser-side script copy) | bounded |
| Published prose and shipped copy avoid the book's "Do not say" words and the retired vocabulary | README, `guides/introduction/`, `guides/flows/`, admin sources, installer templates | `test/sigra/brand/copy_contract_test.exs` against the shrink-only `test/fixtures/brand/copy-baseline.json`; `guides/reference/`, `guides/recipes/` and library module documentation are not scanned | bounded |
| Sigra makes no trademark claim | This record; the vendored book's legal lines | `test/sigra/brand/name_clearance_test.exs` scans this record only; the vendored book mentions both mark symbols in a sentence about when to use them, and that text is pinned and not edited here | bounded |
| No other package named `sigra` exists on npm, PyPI, RubyGems or crates.io | No published page | The lookup table above, 2026-11-13; trademark, look-alike and register searches were not run | bounded |

### Limitations

- The parity tests run in the example host, a hand-maintained copy of the generated host that already differs from the generated templates. As of 2026-11-15 the example host has been repaired for the two flows it could not complete (the reset request and the confirmation resend), but a generated host may still differ: the generated reset request page is tracked as a defect. Only the install smoke proves a generated host. A parity row says nothing about a generated host that has been edited.
- A parity row proves one request for an existing identity and one for an unknown identity, on the dimensions listed. It says nothing about timing, repeated attempts, locked or unconfirmed accounts, or delivery.
- The library's own module documentation over-claims in places and stays that way in the shipped API documentation, because this phase carries zero library bytes. The todo above tracks it. A green parity claim for the passkey options endpoint, for registration, or for either rate limit needs a later fix in `priv/templates` or `lib` plus a golden-fixture rebless, which this phase deliberately does not do: divergences are registered and asserted, not made green.
- Phase 263 public copy, including the README, the Hex package page and ExDoc, may restate a row only with its bounds. It may not assert enumeration safety for a surface whose registry state is not `parity`, and it may not assert clearance of the name.

## Revisit triggers

Revisit this record if a third party starts using the name in a conflicting way, if the maintainer confirms or denies ownership of `crosswake_sigra`, if a trademark search is commissioned or the maintainers decide to claim the name, if the vendored book is re-locked with changed clear-space or logo-use text, if Phase 263 publishes a logo-use statement that differs from the wording above, or if a registry row changes state (a fix lands and a divergence row is retired or becomes parity). Amendments are dated and made in place, in the style of ADR 003; this record is not silently rewritten.
