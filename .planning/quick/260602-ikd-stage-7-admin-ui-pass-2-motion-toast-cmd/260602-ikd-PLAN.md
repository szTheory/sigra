---
phase: quick-260602-ikd
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/example/priv/static/assets/css/app.css
  - priv/templates/sigra.install/admin/components/admin_shell.ex
  - test/example/lib/example_web/components/admin_shell.ex
  - test/example/assets/js/admin_hooks.js
  - priv/templates/sigra.install/admin/admin_hooks.js
  - test/example/priv/static/assets/js/app.js
autonomous: true
requirements:
  - ADMIN-PASS2-STAGE7
user_setup: []

must_haves:
  truths:
    - "Pressing Cmd-K / Ctrl-K opens the command palette; Esc and click-outside close it"
    - "The palette navigates to Users, Audit, and Overview, and find-a-user free text navigates to /admin/users?q=<text>"
    - "Palette nav targets are scope-aware (org scope routes to org-scoped URLs)"
    - "Up/Down moves selection, Enter activates, focus is trapped in the open palette, ARIA dialog/listbox roles present"
    - "The Cmd-K trigger is hidden by default and revealed only by the CmdK hook on mount (graceful in hosts without the hook)"
    - "Clicking a code.sg-code id chip copies its text and shows a transient confirmation toast that auto-dismisses"
    - "Reduced-motion users still get a working palette (opacity-only; movement neutralized)"
  artifacts:
    - path: "test/example/priv/static/assets/css/app.css"
      provides: "sg-cmdk* overlay, sg-toast-region, copy affordance on code.sg-code"
      contains: "sg-cmdk"
    - path: "test/example/assets/js/admin_hooks.js"
      provides: "Plain-JS CmdK + CopyToClipboard hooks source mirror"
      contains: "SigraAdminHooks"
    - path: "priv/templates/sigra.install/admin/admin_hooks.js"
      provides: "Optional host-wiring template for the admin hooks"
      contains: "SigraAdminHooks"
    - path: "test/example/priv/static/assets/js/app.js"
      provides: "Readable-tail admin hooks block + hooks-object registration"
      contains: "SigraAdminHooks"
    - path: "test/example/lib/example_web/components/admin_shell.ex"
      provides: "Hidden-by-default Cmd-K trigger with phx-hook=CmdK + scope data attrs"
      contains: "phx-hook=\"CmdK\""
    - path: "priv/templates/sigra.install/admin/components/admin_shell.ex"
      provides: "Parity-identical shell template with the same hidden trigger"
      contains: "phx-hook=\"CmdK\""
  key_links:
    - from: "test/example/lib/example_web/components/admin_shell.ex"
      to: "CmdK hook"
      via: "phx-hook attribute + data-* nav targets"
      pattern: "phx-hook=\"CmdK\""
    - from: "test/example/priv/static/assets/js/app.js"
      to: "LiveSocket hooks registry"
      via: "(window.SigraAdminHooks||{}).CmdK reference"
      pattern: "SigraAdminHooks"
    - from: "test/example/priv/static/assets/css/app.css"
      to: "code.sg-code chips"
      via: "copy affordance + sg-cmdk overlay"
      pattern: "sg-cmdk"
---

<objective>
Stage 7 of the approved Admin-UI Pass 2 plan — the interactive accelerator layer. Add a
self-contained client-side Cmd-K command palette and click-to-copy on id chips to the
admin console, plus any remaining cheap motion that stays within the Stage-0 motion budget.

Purpose: Power-user accelerators (keyboard nav + clipboard) layered on the existing simple
base, serving novices and experts at once — the last craft layer before the Stage-8 evidence
refresh. Stage-0 tokens already deliver hover/press/collapse/tone motion; this stage adds the
keyboard/clipboard paths only.

Output: a plain-JS `CmdK` + `CopyToClipboard` hook block injected into the committed example
bundle, a hidden-until-revealed Cmd-K trigger in the parity-identical admin shell (both copies),
`sg-cmdk*` overlay CSS reusing the reserved `--sg-z-modal` and Stage-0 `sg-toast` classes, and a
shipped-but-optional `admin_hooks.js` install template.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@/Users/jon/.claude/plans/summary-this-session-reshaped-fancy-curry.md

<interfaces>
<!-- Ground truth extracted from the codebase — executor should NOT re-explore. -->

# The committed bundle is HAND-MAINTAINED, NO build step. test/example/priv/static/assets/js/app.js
# is 539 lines: line 87 begins the minified LiveView vendor IIFE (NEVER edit), the readable
# passkey block ends with the `// Sigra passkeys:end` marker (~line 515), then the
# `// LiveSocket initializer` IIFE (lines 517-532). The initializer ends:
#
#   var passkeyRuntime = window.SigraPasskeyRuntime || {};
#   var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
#     longPollFallbackMs: 2500,
#     hooks: {
#       PasskeyRegister: passkeyRuntime.PasskeyRegister,
#       PasskeyAuthenticate: passkeyRuntime.PasskeyAuthenticate
#     },
#     params: { _csrf_token: csrfToken }
#   });
#   liveSocket.connect();
#   window.liveSocket = liveSocket;
#
# INJECTION CONTRACT (the ONLY safe edit):
#   (a) Insert a READABLE plain-JS IIFE block (NO `import`/ESM — won't run unbundled) AFTER the
#       `// Sigra passkeys:end` marker and BEFORE `// LiveSocket initializer`. It must define
#       window.SigraAdminHooks = { CmdK, CopyToClipboard }.
#   (b) Add two entries to the existing `hooks:` object:
#         CmdK: (window.SigraAdminHooks||{}).CmdK,
#         CopyToClipboard: (window.SigraAdminHooks||{}).CopyToClipboard
#   NEVER touch line 87's minified vendor. `node --check` must pass after editing.

# passkey_hooks.js (test/example/assets/js/) uses ES `import` and `export` — that is the BUILT
# source pattern. The new admin_hooks.js MUST be plain JS with NO imports/exports (the example
# mirror) so the same source can be pasted into the unbundled app.js readable tail.

# LiveView hook shape (from the vendor + passkey usage): a hook is an object with lifecycle
# methods (mounted, destroyed, ...) where `this.el` is the bound DOM element. CmdK binds to a
# container element carrying phx-hook="CmdK". No this.pushEvent needed — Cmd-K is fully
# client-side (window.location navigation), so the hook never round-trips the server.

# admin_shell.ex (test/example/lib/example_web/components/) — `def admin_shell(assigns)`:
#   - Root element: <section class="sg-admin-shell" data-scope={scope_mode(@admin_scope)}> (line 16)
#     data-scope is "global" | "organization" (asserted by admin_shell_test.exs — do not alter).
#   - Topbar inner cluster lives at lines 18-34 (brand mark + scope switcher + "Exit to global").
#   - Scope-aware URL helpers already exist as private fns:
#       users_link/1   -> /admin/users  OR /admin/organizations/<slug>/users
#       audit_link/1   -> /admin/audit  OR /admin/organizations/<slug>/audit
#       overview_link/1-> /admin        OR /admin/organizations/<slug>
#     Use these to stamp data-* nav targets onto the trigger so the hook is scope-correct
#     without any client-side scope logic.

# admin_shell_test.exs asserts (must stay green): "Admin", "Global"/org name, "Users",
# href="/admin/users", "Audit", href="/admin/audit", "What do you need to do?",
# data-scope="global"|"organization", "Org · <name>", sidebar order, bottom-nav order,
# impersonation chrome. Adding NEW hidden markup is additive and must not disturb these.

# CSS (test/example/priv/static/assets/css/app.css) — Stage-0 primitives to REUSE, not recreate:
#   --sg-z-modal: 50           (line 143, reserved for THIS palette)
#   --sg-z-toast: 60           (line 144)
#   .sg-toast-region           (line 1249, fixed top-right, pointer-events:none, z-toast)
#   .sg-toast / .sg-toast--enter / .sg-toast--leave + @keyframes (lines 1260-1286)
#   .sg-code                   (line 1002 — the id chip; add cursor/title affordance)
#   Motion tokens: --sg-motion-pop:180ms, --sg-ease-out (lines 118/123), --sg-transition-enter.
#   Reduced-motion block (lines 1335-1345) is the ONLY !important — it clamps animation-duration
#   and restricts transition-property to color/bg/border/shadow/opacity/fill/stroke (drops
#   transform). The palette enter MUST therefore use opacity (+ optional transform scale 0.96→1)
#   so reduced-motion degrades to an instant-but-functional fade. NEVER scale(0); NEVER
#   transition:all; animate transform/opacity only.

# Parity gate (HARD): sed 's/<%= web_module %>/ExampleWeb/g' <template> | diff - <example>
# must be byte-clean. Currently CLEAN. Every shell edit goes in BOTH files identically (the
# example uses literal ExampleWeb where the template uses <%= web_module %>; in this shell the
# new trigger markup contains no web_module token, so the two edits are byte-identical).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: sg-cmdk overlay CSS + copy affordance (no JS yet)</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
    In the @layer sg-components block (alongside the existing FLASH/TOAST and SKELETON
    sections near lines 1245-1316), add a new `sg-cmdk*` (BEM) section for the command palette
    overlay. Define:
      - `.sg-cmdk` — the fixed full-viewport overlay: position:fixed; inset:0;
        z-index: var(--sg-z-modal); a dim scrim background via color-mix on --sg-color-ink;
        display:flex with top-ish vertical alignment + centered horizontally; pointer-events
        managed so the scrim catches click-outside.
      - `.sg-cmdk__dialog` — the centered panel: --sg-color-panel background, --sg-elev-3
        shadow, --sg-radius-md, max-width ~36rem, width calc(100vw - gutter). Entrance:
        opacity 0→1 AND transform scale(0.96)→1 over var(--sg-motion-pop) (180ms,
        ≤180ms budget) var(--sg-ease-out) — implement as a keyframed `.sg-cmdk--enter`
        animation (mirror the sg-toast--enter pattern) so the reduced-motion duration clamp
        neutralizes it to a static end state. Animate ONLY opacity + transform. NEVER scale(0)
        (start 0.96). NEVER transition:all.
      - `.sg-cmdk__input` — the free-text find-a-user field styled with existing input tokens.
      - `.sg-cmdk__list` / `.sg-cmdk__item` — the command rows; `.sg-cmdk__item.is-active` (or
        `[aria-selected="true"]`) gets a brand-tinted background for the keyboard-highlighted
        row. NO transition on the active-row highlight (keyboard/high-frequency path is
        instant per the Emil Kowalski motion budget — zero motion on the nav itself).
      - `.sg-cmdk__trigger` — the topbar trigger element styled as a small ghost affordance,
        but set to `display: none` by default (hidden until the hook reveals it). The hook adds
        a class (e.g. `.sg-cmdk__trigger.is-ready`) or sets inline display to reveal — define
        `.sg-cmdk__trigger.is-ready { display: <inline-flex/whatever fits the topbar> }`.
    Also add a copy affordance to the existing `.sg-code` rule (line ~1002): when inside the
    admin shell, give it `cursor: pointer` to signal clickability (scope it as
    `.sg-admin-shell code.sg-code` or add a dedicated `.sg-code--copyable` — choose the
    narrower scope to avoid affecting non-copyable code elsewhere; the title attribute is set
    in JS/markup, CSS only provides cursor + a subtle hover tint using --sg-transition-tone).
    Every value references an existing token. Do NOT add a new !important. Do NOT recreate the
    toast region/classes — they already exist and will be reused by Task 3.
  </action>
  <verify>
    <automated>grep -n 'sg-cmdk' test/example/priv/static/assets/css/app.css | grep -v '^#' && grep -c 'sg-cmdk__dialog\|sg-cmdk__list\|sg-cmdk__trigger' test/example/priv/static/assets/css/app.css</automated>
  </verify>
  <done>sg-cmdk overlay/dialog/input/list/item/trigger rules exist using --sg-z-modal and
  Stage-0 motion tokens; trigger is display:none by default with an .is-ready reveal rule;
  .sg-code (admin-scoped) gains a copy cursor affordance; no new !important; only
  transform/opacity animated.</done>
</task>

<task type="auto">
  <name>Task 2: Hidden Cmd-K trigger in BOTH shell files (parity-identical)</name>
  <files>priv/templates/sigra.install/admin/components/admin_shell.ex, test/example/lib/example_web/components/admin_shell.ex</files>
  <action>
    Add a hidden-by-default Cmd-K trigger to the topbar inner cluster (inside the
    `.sg-admin-topbar-inner` div, lines 18-34, e.g. just before the "Exit to global" link or
    next to the scope switcher). The trigger is a single container element that:
      - carries `phx-hook="CmdK"` and a stable `id` (required by LiveView for hooks, e.g.
        id="admin-cmdk"),
      - has class `sg-cmdk__trigger` (CSS keeps it display:none until the hook adds .is-ready),
      - is a real <button type="button"> with accessible label (aria-label="Open command
        palette" / visible "Search… ⌘K" hint text), so when revealed it is clickable AND
        keyboard reachable,
      - stamps SCOPE-AWARE nav targets as data-* attributes read from the existing private
        helpers so the hook needs zero scope logic:
          data-users-href={users_link(@admin_scope)}
          data-audit-href={audit_link(@admin_scope)}
          data-overview-href={overview_link(@admin_scope)}
          data-overview-label={scope_label(@admin_scope)}
        (overview_link/users_link/audit_link/scope_label already exist as private fns in this
        module — reuse them; do not duplicate routing logic in JS.)
    The find-a-user free-text Enter target is /admin/users?q=<text>; the hook composes it from
    data-users-href (append ?q=). Keep markup minimal and identical in both files — it contains
    NO <%= web_module %> token, so the template and example copies are byte-identical.
    Do NOT alter any existing asserted markup (data-scope, links, headings, bottom-nav order).
    After editing BOTH files, the parity diff MUST be byte-clean.
  </action>
  <verify>
    <automated>sed 's/<%= web_module %>/ExampleWeb/g' priv/templates/sigra.install/admin/components/admin_shell.ex | diff - test/example/lib/example_web/components/admin_shell.ex && grep -c 'phx-hook="CmdK"' test/example/lib/example_web/components/admin_shell.ex</automated>
  </verify>
  <done>Both shell files contain an identical hidden `sg-cmdk__trigger` button with
  phx-hook="CmdK", a stable id, an aria-label, and data-users-href/data-audit-href/
  data-overview-href/data-overview-label populated from the existing scope helpers; parity
  diff is byte-clean; no existing asserted markup changed.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Plain-JS admin hooks source + template (CmdK + CopyToClipboard)</name>
  <files>test/example/assets/js/admin_hooks.js, priv/templates/sigra.install/admin/admin_hooks.js</files>
  <action>
    Write a PLAIN-JS source file (NO `import`/`export`/ESM — it must run unbundled when pasted
    into app.js) at test/example/assets/js/admin_hooks.js that defines two LiveView hooks and
    assigns window.SigraAdminHooks = { CmdK, CopyToClipboard }. Wrap in an IIFE.

    CmdK hook (bound via this.el = the hidden trigger button):
      - mounted(): REVEAL the trigger (add class "is-ready" so hosts without the hook never see
        a dead button). Read scope-aware nav targets from this.el.dataset
        (usersHref/auditHref/overviewHref/overviewLabel). Build a static command list:
          "Go to Users" -> usersHref, "Go to Audit" -> auditHref,
          "Go to <overviewLabel> overview" -> overviewHref.
        Bind a document-level keydown handler: ⌘K (metaKey+"k") / Ctrl-K (ctrlKey+"k")
        toggles open (preventDefault). Clicking the trigger also opens.
      - open(): create the overlay DOM (role="dialog" aria-modal="true" aria-label="Command
        palette" on .sg-cmdk__dialog; the list as role="listbox", items role="option"). Include
        a free-text input (.sg-cmdk__input, type="text", aria-label="Find a user or jump to a
        page"). Append .sg-cmdk--enter for the entrance animation. Move focus into the input
        (focus trap: keep Tab/Shift+Tab cycling within the dialog). Render the static command
        items + (optionally) filter them as the user types.
      - keyboard within open palette: ArrowDown/ArrowUp move the active selection
        (aria-selected + .is-active class, NO animation), Enter activates the active command OR,
        if the input has free text and no command is highlighted, navigate to
        usersHref + (usersHref.includes("?") ? "&" : "?") + "q=" + encodeURIComponent(text)
        (the find-a-user accelerator — reuses the existing users search; no new endpoint).
        Esc closes; click on the scrim (outside .sg-cmdk__dialog) closes; restore focus to the
        trigger on close.
      - navigation uses window.location.assign(href) — fully client-side, NO server round-trip,
        NO motion on the nav path.
      - destroyed()/disconnected(): remove the document keydown listener and any open overlay.

    CopyToClipboard hook: implement as a DELEGATED behavior so NO per-LiveView markup is needed.
    Simplest form: in the SigraAdminHooks IIFE, attach a single delegated click listener that
    matches `.sg-admin-shell code.sg-code` (gate to the admin shell to avoid global side
    effects). On click: navigator.clipboard.writeText(el.textContent.trim()); also set the
    element's title="Click to copy" on first hover/mount if not present. Then show a transient
    confirmation toast: ensure a `.sg-toast-region` exists in the DOM (create+append one to
    <body> if absent), append a `.sg-toast.sg-toast--enter` element reading e.g. "Copied",
    auto-dismiss after ~2s by swapping to `.sg-toast--leave` then removing. Reuse the Stage-0
    sg-toast classes (do not invent new toast CSS). Handle the clipboard promise rejection
    gracefully (no throw). This delegated listener can live inside the CopyToClipboard hook's
    behavior OR be installed once when SigraAdminHooks is defined — either is acceptable as long
    as it requires NO library-LiveView edits and binds only within .sg-admin-shell.

    ARIA/focus details: the dialog labelled and focus-trapped; the listbox/option roles wired
    to the keyboard selection; reduced-motion is honored automatically by the CSS (opacity-only
    end state) — do not add JS that forces movement.

    Then create priv/templates/sigra.install/admin/admin_hooks.js as the host-wiring template:
    the SAME plain-JS content (so hosts can paste it into their bundle), with a top-of-file
    comment documenting that wiring is OPTIONAL this stage — hosts add the two hooks to their
    LiveSocket `hooks:` map exactly as the example bundle does. Do NOT modify the installer
    (mix task / installer manifest) this stage; the template ships as documented-optional.
    Keep the two files content-identical (the template has no web_module substitution needs).
  </action>
  <verify>
    <automated>node --check test/example/assets/js/admin_hooks.js && node --check priv/templates/sigra.install/admin/admin_hooks.js && diff test/example/assets/js/admin_hooks.js priv/templates/sigra.install/admin/admin_hooks.js && grep -c 'SigraAdminHooks\|CmdK\|CopyToClipboard' test/example/assets/js/admin_hooks.js</automated>
  </verify>
  <done>admin_hooks.js (example source) is valid plain JS (node --check passes), uses NO
  import/export, defines window.SigraAdminHooks={CmdK,CopyToClipboard}; CmdK reveals the
  trigger, opens an ARIA dialog/listbox with focus trap, ⌘K/Ctrl-K/Esc/click-out/arrows/Enter,
  scope-aware nav + find-a-user; CopyToClipboard copies .sg-admin-shell code.sg-code with a
  transient sg-toast confirmation and no library-LiveView edits; the install template is an
  identical copy documented as optional host wiring.</done>
</task>

<task type="auto">
  <name>Task 4: Wire admin hooks into the committed bundle (readable-tail injection)</name>
  <files>test/example/priv/static/assets/js/app.js</files>
  <action>
    Inject the admin hooks into the HAND-MAINTAINED bundle following the strict INJECTION
    CONTRACT (see <interfaces>). Two surgical edits ONLY — never touch the minified vendor
    (line 87):
      (a) Insert the FULL plain-JS admin hooks block (the exact content of
          test/example/assets/js/admin_hooks.js from Task 3) AFTER the `// Sigra passkeys:end`
          marker (~line 515) and BEFORE the `// LiveSocket initializer` comment (~line 517).
          Bracket it with `// Sigra admin hooks:start` / `// Sigra admin hooks:end` markers
          mirroring the passkey block convention, so it stays maintainable. The block must
          assign window.SigraAdminHooks = { CmdK, CopyToClipboard } and use NO import/export.
      (b) In the existing LiveSocket initializer `hooks:` object (lines 524-527), add two
          entries alongside the passkey hooks:
            CmdK: (window.SigraAdminHooks || {}).CmdK,
            CopyToClipboard: (window.SigraAdminHooks || {}).CopyToClipboard
    Preserve the existing PasskeyRegister/PasskeyAuthenticate entries and the
    longPollFallbackMs/params lines verbatim. Keep the readable formatting consistent with the
    surrounding tail. Do NOT reformat or re-minify anything. After editing, `node --check` MUST
    pass (HARD GATE) and the bundle must still boot (orchestrator restarts + smoke-tests that
    the app boots and Cmd-K opens). Because the injected content is the same source validated in
    Task 3, the risk surface is the placement + the two hooks-object lines.
  </action>
  <verify>
    <automated>node --check test/example/priv/static/assets/js/app.js && grep -c 'SigraAdminHooks' test/example/priv/static/assets/js/app.js && grep -c 'CmdK: (window.SigraAdminHooks' test/example/priv/static/assets/js/app.js && grep -c 'PasskeyRegister: passkeyRuntime' test/example/priv/static/assets/js/app.js</automated>
  </verify>
  <done>app.js passes node --check; contains the bracketed admin-hooks block defining
  window.SigraAdminHooks before the LiveSocket initializer; the hooks: object references
  CmdK and CopyToClipboard via (window.SigraAdminHooks||{}); the original passkey hook entries
  and vendor portion are untouched.</done>
</task>

</tasks>

<verification>
HARD GATES (all must pass before the stage is done):
1. `node --check test/example/priv/static/assets/js/app.js` passes (bundle still valid).
2. `node --check test/example/assets/js/admin_hooks.js` and
   `node --check priv/templates/sigra.install/admin/admin_hooks.js` pass; the two are identical.
3. Shell parity: `sed 's/<%= web_module %>/ExampleWeb/g'
   priv/templates/sigra.install/admin/components/admin_shell.ex | diff -
   test/example/lib/example_web/components/admin_shell.ex` is byte-clean.
4. Admin ExUnit green:
   `cd test/example && PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres mix test
   test/example_web/admin_shell_test.exs test/example_web/live/admin_*_live_test.exs`
5. `cd test/example && mix compile --warnings-as-errors` clean.
6. Orchestrator restarts the example server and smoke-tests: the app boots and ⌘K opens the
   palette; clicking a code.sg-code chip copies + shows a toast.

CSS/motion discipline: animate only transform/opacity; no new !important; no transition on the
keyboard-highlight/nav path; reduced-motion users still get a working (opacity-only) palette.
</verification>

<success_criteria>
- ⌘K / Ctrl-K opens the palette; Esc and click-outside close it; focus returns to the trigger.
- Palette navigates to Users / Audit / Overview (scope-aware) and find-a-user free text
  navigates to /admin/users?q=<text> (org-scoped when in org scope).
- Up/Down move selection, Enter activates, focus trapped, ARIA dialog/listbox roles present.
- Trigger is hidden by default and revealed only by the CmdK hook (graceful in hosts lacking it).
- Click-to-copy on code.sg-code chips with a transient confirmation toast (Stage-0 sg-toast),
  no library-LiveView edits.
- node --check passes on the bundle and both hook files; shell parity byte-clean; admin ExUnit
  green; warnings-as-errors clean.
- admin_hooks.js shipped as a documented-optional install template (no installer changes).
</success_criteria>

<flags>
- The bundle is hand-edited with no build step; `node --check` + the orchestrator boot/Cmd-K
  smoke test are the safety net. Task ordering isolates the bundle edit (Task 4) so a
  node-check/boot failure is contained and the validated source already exists (Task 3).
- The Cmd-K hook is EXAMPLE-ONLY for now; the host template ships at
  priv/templates/sigra.install/admin/admin_hooks.js but installer wiring is documented as a
  follow-on (no mix-task/installer change this stage).
- Baselines will shift for Stage 8: the Cmd-K trigger is hidden until JS reveals it, so headless
  MCP/screenshot runs may or may not show it — note for the Stage-8 baseline regeneration.
- Scope C (optional flash→sg-toast restyle and animated "More filters" collapse) is DEFERRED
  unless it stays trivially clean within budget after Tasks 1-4 land; the bulk of motion is
  already delivered by Stage-0 tokens. If deferred, record it in the SUMMARY.
</flags>

<output>
Create `.planning/quick/260602-ikd-stage-7-admin-ui-pass-2-motion-toast-cmd/260602-ikd-SUMMARY.md` when done.
</output>
