# Adopter and Maintainer Release DX: Sigra 1.5.1

**Scope:** What Phoenix auth-library adopters need to decide whether and how to install or upgrade a patch release. This is release-scope research, not release authorization.

## Decision

The live Release Please PR #224 proposes `1.6.0`, and the package diff since `1.5.0` spans 77 runtime/template/docs files. I recommend completing that candidate rather than constructing a patch backport. If confirmed, update install examples to `{:sigra, "~> 1.6.0"}`; the currently documented `~> 1.5.0` excludes 1.6.0. Give adopters one decision path: read the versioned HexDocs changelog, check whether an upgrade action is listed, then run `mix deps.update sigra` and relevant host-application checks. If the user instead retains 1.5.1, the milestone needs a separate patch-only source selection and should keep `~> 1.5.0`. State plainly that the stray `1.20.0` remains visible in package history and that neither release line alone changes that ranking signal. The October 5 v1.48 closeout and October 6 Hex package API read report `1.20.0` as retired while `latest_stable_version` and `latest_version` still report `1.20.0`. Do not claim a resolver correction.

The maintainer's release machinery and internal safety record should stay behind the scenes. Adopters need an accurate changelog, compatibility statement, actionable upgrade steps (or an explicit “no action required”), and consistent package/docs links; they should not have to understand Release Please, CI receipts, tag namespace rules, or the old publish incident to install a valid supported release.

## JTBD and decision path

**Adopter job (inference from the repository's auth-library positioning and JTBD prompt):** “I already use or am evaluating Sigra. Help me decide whether this patch safely fixes something I care about, which version line to request, and what I must do in my host app without unexpectedly changing generated code, schema, or auth behavior.” For auth software, a patch note that conceals a security or host-app action is more costly than an overly terse implementation note.

| Adopter asks | Signal that should answer it | Sigra source of truth |
|---|---|---|
| What is Sigra and does it fit my app? | Short library boundary and supported Phoenix/Elixir baseline | [README](../../../README.md), [installation guide](../../../guides/introduction/installation.md), package description |
| Can I use this patch on my current line? | SemVer version plus compatibility statement | `CHANGELOG.md`, versioned HexDocs changelog, package version metadata |
| What do I change? | Dependency requirement and exact update command | `{:sigra, "~> 1.5.0"}` and `mix deps.update sigra`; retain/review `mix.lock` |
| Is a migration or generated-host edit required? | Explicit upgrade section or “No migration/host changes required” | Release notes, then [Getting Started](../../../guides/introduction/getting-started.md) or relevant upgrade guide |
| Can I verify what I installed? | Versioned package docs and source link for same release | HexDocs and source tag for the selected release version |

The audience divides into existing adopters who need upgrade impact and evaluators who need a trustworthy install signal. The README already routes greenfield users through Installation → Getting Started and keeps maintainer evidence separate. Preserve that distinction: the release announcement/changelog can link outward for maintainers, but should not require a reader to traverse project planning artifacts.

## Observed repository facts

- The checked-in baseline currently has `@version "1.5.0"`; Release Please's manifest and latest changelog release are also `1.5.0` (see [mix.exs](../../../mix.exs), `.release-please-manifest.json`, and [CHANGELOG.md](../../../CHANGELOG.md)). This is the research baseline, not evidence that 1.5.1 has shipped.
- The README's first integration snippet and the Installation/Getting Started/First hour guides use `{:sigra, "~> 1.5.0"}`. Installation explains the three-segment requirement: the erroneous `1.20.0` sorts above the real 1.5.x line; `~> 1.5.0` is bounded below `1.6.0`. These are useful adopter facts, though the caution should remain brief and link to deeper explanation if it begins to dominate installation.
- `mix.exs` includes `README.md` and `CHANGELOG.md` in the Hex package. ExDoc includes installation/getting-started guides and the changelog, sets its main page to `demo-showcase`, and sets `source_ref: "v#{@version}"`; the source comment warns that the matching tag is needed for “View source” links.
- `.github/workflows/release-please.yml` uses Release Please to make a reviewed release PR. After merge, it gates on CI at the release SHA, checks version/tag/manifest/docs-source alignment, runs library tests, builds docs with warnings as errors, unpacks and inspects the Hex artifact, dry-runs and publishes, then verifies package and HexDocs evidence. This is maintainer machinery; it is not an adopter checklist.
- The changelog has a manual fold warning under `Unreleased`: Release Please inserts the generated section below it, and anything left there can ship as visibly unreleased text in the immutable package. The current `1.5.0` release contains useful adopter-facing Added/Changed/Upgrade notes, but also a long generated commit-detail list. Keep the concise impact sections as the primary scan path; let commit details remain secondary.
- [v1.48 Phase 242's September 22 safety closeout](../../milestones/v1.48-phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md) accurately records its evidence boundary at that date and says future publication needs a separately scoped phase and fresh authorization. The user's explicit selection starts that separately scoped 1.5.1 work. Moving to the discovered 1.6.0 Release Please PR is a material version change and needs confirmation; after target and scope are confirmed, don't ask for the same authorization again.
- A fresh read of the [Hex package API](https://hex.pm/api/packages/sigra) on 2026-10-06 reports `retirements["1.20.0"]` with reason `invalid`, but both `latest_stable_version` and `latest_version` remain `1.20.0`. The [versions page](https://hex.pm/packages/sigra/versions) still lists `1.20.0` first; retired releases remain visible. Thus current evidence confirms retirement and the continuing ranking problem. Neither 1.5.1 nor 1.6.0 alone is a resolver repair. Treat these public observations as time-bound and recheck during the selected release.
- The current `~> 1.5.0` examples do not admit `1.6.0`. If PR #224 remains the selected release, update the package README and guides to the bounded 1.6 line; recheck that constraint in the unpacked Hex artifact.

## Sourced ecosystem facts

- Hex says requirements define the acceptable versions; for unlocked dependencies its resolver tries the latest versions that satisfy the full dependency set. Mix/Hex also keeps locked versions in `mix.lock`; `mix deps.update` is the command that asks to update a dependency. Thus a published `1.5.1` does not silently change an existing lockfile, and the existing `~> 1.5.0` requirement remains appropriate for a patch. [Hex usage](https://hex.pm/docs/usage)
- Hex says retired releases remain resolvable and fetchable, with a warning and retired status. Retirement is not a deletion or a resolver repair. The package page may still show the retired release prominently; do not promise that publishing `1.5.1` moves `latest_stable_version` to `1.5.1` without checking the live registry metadata. [Hex retirement task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html), [Hex FAQ](https://hex.pm/docs/faq), [Sigra package versions](https://hex.pm/packages/sigra/versions)
- Hex publishes package docs automatically with a package. It recommends running `mix docs` locally and cautions that automated publishing can hide warnings; its publishing guide describes a one-hour correction/revert window for an existing release version. This supports validating package contents and rendered docs before publication, then checking the public versioned docs afterward. [Hex publishing](https://hex.pm/docs/publish), [Hex `mix hex.publish` task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html)
- HexDocs supports both `<package>.hexdocs.pm` and `<package>.hexdocs.pm/<version>`; the bare root is a convenience latest-version entry point, not a durable link to a particular release. Prefer explicit version links in a release announcement or support thread. [HexDocs home](https://hexdocs.pm/)
- Ecto's official changelog gives each SemVer release a concise version heading and groups changes as Enhancements and Bug fixes. It calls out minimum Elixir versions and potentially breaking changes when relevant. Plug uses compact per-version Bug fixes/Security/Enhancements sections and states its support policy. These offer good scan patterns for adopters. [Ecto changelog](https://github.com/elixir-ecto/ecto/blob/master/CHANGELOG.md), [Plug changelog](https://github.com/elixir-plug/plug/blob/main/CHANGELOG.md), [Plug supported versions](https://github.com/elixir-plug/plug#supported-versions)

## Adopter experience if 1.6.0 is confirmed

1. **Release note:** Start with the adopter-visible changes. Use short `Bug fixes`, `Features`, and `Security` sections only when they describe package behavior; the current 1.6.0 generator labels internal measurement/remediation tooling as features, which must not be presented as adopter functionality. Add a compatibility line and a no-action statement only after verifying those claims against the package diff. Link to an upgrade guide for any generated-host action.
2. **Install/update:** For 1.6.0, use `{:sigra, "~> 1.6.0"}`. Existing apps should run `mix deps.update sigra`, review/commit `mix.lock`, and run their host tests; fresh apps follow Installation → Getting Started. Use `~> 1.5.0` only for a separately selected 1.5.x patch line.
3. **Version/doc links:** Use version-specific HexDocs, e.g. `/sigra/1.6.0/` for 1.6.0. Keep GitHub as the editable changelog/source/tag/history location. Ensure `mix.exs`, Release Please manifest, changelog, tag, package metadata, source ref, and dependency examples agree.
4. **Version-history note:** If mention is needed to explain why the bounded requirement exists, say only that old `1.20.0` metadata remains visible and `~> 1.5.0` confines the intended install to the supported line; direct resolution depends on the requirement and lockfile. Do not frame the patch as fixing `latest_stable_version`, retirement, existing lockfiles, or the Hex landing page absent live verification.
5. **No internal burden:** Keep release-process details, exception logs, authorization, and evidence bundle in maintainer-facing GitHub material. The adopter-facing page should answer install, compatibility, migration/action, and where to ask for support.

## Verification boundary

**Automate:** version agreement across `mix.exs`/manifest/changelog/tag; correct `Unreleased` fold; docs build and version-specific links; packaged README/changelog/guides; dependency examples match the selected line (`~> 1.6.0` for 1.6.x); release SHA tests and dry-run; package and versioned HexDocs presence after publish. Automated checks can also capture Hex's latest-stable metadata without claiming the release fixes it.

**Human/editorial judgment:** whether the patch's prose accurately describes the shipped auth/security impact; whether a migration or generated-host action is truly unnecessary; whether a compatibility statement matches supported consumer configurations; and whether the release note is understandable to an adopter who does not know Sigra's internal workflow. Automation can check presence and alignment, not prove these claims from formatted release text alone.

## Good practices and footguns

| Practice | Why it helps | Footgun to guard against |
|---|---|---|
| Treat release PR notes as reviewed draft prose | Generated commits optimize traceability, not adopter comprehension | Planning IDs, duplicate generated entries, CI work, or internal terms presented as features |
| Explain patch impact and action directly | Security-library users need to know whether to update and run migrations | “Bug fixes” without saying whether host code/schema changes |
| Use bounded `~> 1.5.0` and explicit update instruction | It stays within the 1.5 line while allowing patch upgrades | Saying `mix deps.get` updates an already locked dependency |
| Keep versioned docs and source link aligned | Package users can verify docs/source for the version installed | Bare HexDocs root may point somewhere else; stale `source_ref` can make source links fail |
| Preserve clear distinction between package releases and planning milestones | Existing project docs already explain these as separate version axes | Calling planning milestone v1.49 the installable package version |
| State what `1.20.0` does and does not mean | Prevents “latest” badge from being mistaken for recommended line | Assuming retirement removes/resets a release or changes an existing lockfile |

## Confidence and gaps

- **High:** Repository statements directly inspected in checked-in files; Hex's published usage, retirement, docs, and publishing behavior cross-checked across official pages.
- **Medium:** The proposed concise note structure and audience JTBD are recommendations inferred from the project's prompt, README routes, and Ecto/Plug examples.
- **Gap:** This scope does not establish the actual contents or compatibility of the future `1.5.1` release. The candidate diff and release notes must supply the true user-visible fix and upgrade action. Public Hex metadata should be observed again during the selected release workflow; this research does not validate a resolver outcome.

## Sources

- Repository: [README](../../../README.md), [Installation](../../../guides/introduction/installation.md), [Getting Started](../../../guides/introduction/getting-started.md), [First hour](../../../guides/introduction/first-hour.md), [CHANGELOG](../../../CHANGELOG.md), [mix.exs](../../../mix.exs), [release workflow](../../../.github/workflows/release-please.yml).
- Repository prompts informing audience language: `prompts/elixir-opensource-libs-best-practices-deep-research.md`; `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`; `prompts/Auth Domain Language — A Field Guide.md`. These are project-authored planning inputs, not independent proof of user behavior.
- Repository release state: [v1.48 Phase 242 closeout](../../milestones/v1.48-phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md), [v1.48 requirements archive](../../milestones/v1.48-REQUIREMENTS.md), [retirement follow-up](../../todos/pending/2026-07-03-hex-retire-stray-1-20-0.md), and the [live Hex package API](https://hex.pm/api/packages/sigra) checked 2026-10-06.
- External primary sources: [Hex usage](https://hex.pm/docs/usage), [Hex publishing](https://hex.pm/docs/publish), [`mix hex.retire`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html), [Hex FAQ](https://hex.pm/docs/faq), [HexDocs](https://hexdocs.pm/), [Sigra Hex versions](https://hex.pm/packages/sigra/versions), [Ecto changelog](https://github.com/elixir-ecto/ecto/blob/master/CHANGELOG.md), [Plug changelog](https://github.com/elixir-plug/plug/blob/main/CHANGELOG.md).
