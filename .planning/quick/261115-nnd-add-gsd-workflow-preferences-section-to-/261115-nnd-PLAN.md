---
quick_id: 261115-nnd
type: quick
autonomous: true
files_modified:
  - CLAUDE.md
---

# Quick task: add "GSD Workflow Preferences" to CLAUDE.md

<objective>
Persist the owner's standing discuss and verify boilerplates in `CLAUDE.md` so every GSD subagent (they read CLAUDE.md via required_reading) applies them during `/gsd-autonomous` runs. Docs-only; no code, no `lib/` or `priv/` change.
</objective>

<context>
- `CLAUDE.md` is project-checked-in and the repo is public: no names, emails, home paths.
- Place the new section immediately BEFORE the existing `## GSD Workflow Enforcement` section (after `## Admin UI Direction`). Do not alter any other section. Do not touch the `## Developer Profile` block (managed by a generator).
- The CI/release-docs discoverability requirement is satisfied here by the section itself AND by one short pointer paragraph appended to `MAINTAINING.md` (find the existing CI / release section; add a "CI efficiency sweep" note under it, 3 to 5 lines, linking back to the CLAUDE.md section). Check first that no test pins `MAINTAINING.md` bytes: `grep -rln "MAINTAINING.md" test scripts` and read any hit that hashes or byte-compares the file. If a test pins it (e.g. a fixture copy or digest), SKIP the MAINTAINING.md edit and instead record that as a deferred follow-up in the SUMMARY; do not re-baseline pins.
</context>

<tasks>
<task type="auto">
  <name>Task 1: Add the section to CLAUDE.md (and MAINTAINING.md pointer if unpinned)</name>
  <files>CLAUDE.md, MAINTAINING.md</files>
  <action>
Insert this section into CLAUDE.md (verbatim wording, Markdown headings as shown):

## GSD Workflow Preferences

Standing owner preferences for GSD runs, including `/gsd-autonomous`. Subagents: apply these by default.

### Discuss phases

- **Fan out, then synthesize.** For each decision point, fan out subagents (context-window efficient) and keep fanning out to the point of diminishing returns, enumerating every relevant angle before synthesizing one coherent set of recommendations.
- **Breadth and depth through stakeholder-role lenses:** security, product, technical, design, devops, plus whatever domain specialties apply (Elixir/Phoenix, CSS and rendering, distributed systems, and so on). For each: pros, cons, tradeoffs, examples, patterns, anti-patterns, best practices, footguns, lessons learned.
- **Research, prefer primary sources.** Consult official docs, specs and reputable references first; look at how other products and ecosystems solved the same problem; think for yourself rather than only repeating sources.
- **Adversarial pass.** Challenge the draft recommendations before finalizing.
- **One-shot, auto-follow.** Synthesize one recommended answer per decision and follow it; do not ask the owner to pick A/B/C unless the decision is very impactful, hard to reverse or outward-facing.
- **UI/UX decisions:** weigh existing patterns, conventions, principle of least surprise and elegant, consistent design.
- **Dependencies:** another copy-paste is better than another dep. Add a dependency only when truly needed; prefer smaller, flatter dependency trees (more secure, fewer odd abstractions).
- **Cheap checks first.** Where applicable, add or run cheap consistency checks before the long test, process or suite. Find the bottleneck and the low-hanging fruit early; step back instead of banging on the same wall.

### Verify phases

- **Shift verification left and automate it.** Integration, e2e, smoke and seam tests; an automate-the-world DevOps mindset. The goal is zero human verification or UAT: hand the owner only what is absolutely necessary, and take automation as far as it gives useful feedback, no further.
- **Throwaway verification is fine.** Not everything belongs in CI; add to CI only when there is recurring value.
- **Record it so we never loop.** Once a verification is automated, record where, so it is not revisited; reduce toil.
- **CI efficiency sweep.** Whenever a CI run is in progress or has just finished, evaluate low-hanging fruit to make it faster and cheaper (iteration time, GitHub Actions minutes) without lowering quality; no pointless bottlenecks. This guidance is also referenced from the CI and release sections of `MAINTAINING.md`.

If the MAINTAINING.md edit is allowed (no byte-pin), add under its CI/release section a short "CI efficiency sweep" note that states: on every CI run, look for cheap speed and cost wins that do not reduce coverage, and see the `GSD Workflow Preferences` section of CLAUDE.md.

Do not push, open a PR, or merge. Stay on the current branch.
  </action>
  <verify>
`git diff --stat` shows only CLAUDE.md (and MAINTAINING.md if allowed) changed. `grep -n "GSD Workflow Preferences" CLAUDE.md` shows the heading once, before `## GSD Workflow Enforcement`. If MAINTAINING.md was edited, run `MIX_ENV=test mix test test/sigra/planning --exclude scaffold` (or at minimum every test file that references MAINTAINING.md) and confirm 0 failures; if any fails because of the edit, revert the MAINTAINING.md change and record it as deferred. No personal names, emails or home paths in the diff.
  </verify>
  <done>The section exists in CLAUDE.md; MAINTAINING.md pointer added or explicitly deferred with reason; tests green.</done>
</task>
</tasks>
