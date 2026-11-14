# sigra brand

Version 2.0, November 13, 2026. This is the complete text of the brand book (`sigra-brand-book.html`), page by page, for people and AI assistants. The same rules as structured data are in `brand.json`; colors and type values in `tokens.json`; every file is explained in `assets/README.md`.

**Read this first.** Authentication for Phoenix 1.8 and later: a library of hardened primitives plus generators that put ordinary Phoenix code in your repo. Security fixes arrive with mix deps.update; the screens, routes and emails are yours to edit. The name is written Sigra in a sentence and `sigra` in the logo, the package and commands. Light is the default theme and dark is a full theme. The logo is the typemark: the word with one plain square above the i, with no shape behind it and no tagline. Every user status is a word first, with its square mark and color second. The contrast pairs have stable ids (body, descriptor, caption, application-copy, link, focus, artwork, and a button pair, and one status pair per status) in both themes.

## Brand at a glance

Phoenix auth you own and can still update.Production-minded authentication for Phoenix 1.8+

### Three rules

1. The name is Sigra in a sentence and `sigra` in the logo, the package and commands. In Elixir module names it is `Sigra`.
2. The typemark is the logo: the word with its square. Put no shape behind it, and keep the tagline and the descriptor outside it.
3. A user’s status is always written as a word. The status mark and its color support the word; they do not replace it.

### Color

**Paper** #F7F3EE **White** #FFFFFF **Soot** #1F1A17 **Kiln** #C2410C **Paper Line** #DDD3C8 **Kiln Deep** #9A3412, links

ActiveUnconfirmedLockedSuspendedDeleting

### Type

Instrument Sans for the name, headlines, reading and tables, and Red Hat Mono for addresses and code.

### Voice

Plain and specific. It says what happened, to whom and what to do about it, and it says what Sigra does not do.

## Positioning and values

**Authentication for Phoenix 1.8 and later: a library of hardened primitives plus generators that put ordinary Phoenix code in your repo. Security fixes arrive with mix deps.update; the screens, routes and emails are yours to edit.**

### Phoenix developers

Add authentication to a Phoenix app without rolling it by hand, and without hiding it from my repo.

Add `{:sigra, "~> 1.7"}`, run `mix sigra.install Accounts User users`, read the generated code in your own repository, and update the core with `mix deps.update`.

### Admins and support staff

A user says they can’t sign in. Pull up their record and see what is going on.

Look the user up by email address. Their status is written out in words, with recent sign-ins and open sessions beside it, so you can unlock them, unsuspend them, revoke a session or tell them to wait.

### Maintainers and contributors

Keep the README, docs, admin and demo looking like one project.

See where Sigra’s brand stops and the host app’s begins, and get the logo files plus the rules for code colors and docs.

**Honest**

Say what Sigra does and what it doesn’t. It is not hosted auth, not a compliance certificate, not an authorization engine.

**Plain**

Name the exact thing: the user, the session, the sign-in. Say “sign in”, not “authenticate”; say “your app”, not “the host”.

**Exact**

Show the real address, role and time, with its time zone. “Locked at 2:02 PM UTC”, not “recently”.

**Calm**

People open the admin because something is wrong with a user. Say what happened, to whom, and what to do next. Never blame, never cheer.

**Yours**

Sigra’s own name and logo appear on its own pages and in the admin. They never appear on the sign-in, registration or two-factor screens that a host app’s users see: those wear the host app’s brand.

## Messaging

### Elevator pitch

**Sigra is authentication for Phoenix: sessions, passwords, email confirmation, magic links, two-factor codes, passkeys and an optional admin, as a library plus generators. The sensitive core updates with `mix deps.update`; the screens, routes and emails are ordinary code in your repo.**

### Key messages

**Own the code.**

The generators put normal Phoenix modules in your repository, ready to read, review and customize.

**Keep it updated.**

The sensitive core, hashing, sessions, tokens and checks, stays in the library, so a fix arrives with a dependency update, not a rewrite.

**Know the boundaries.**

Sigra is not hosted auth, not a compliance certificate and not an authorization engine. The docs say so up front.

### Tagline

**Phoenix auth you own and can still update.**

Sentence case, with the period. It sits beside the logo, never in it. Under it, where the line stands alone, goes the descriptor “Production-minded authentication for Phoenix 1.8+”.

### About sigra: approved descriptions

One line: Hex, GitHub and package listings

A library of hardened primitives plus generators that put ordinary authentication code for Phoenix in your repo.

Short: README opening, talk bios

Sigra is an open-source authentication library for Phoenix 1.8 and later. A library holds the security-sensitive core, and generators write the screens, routes and emails into your own repository as normal code. Fixes arrive with `mix deps.update`; the rest is yours to edit.

Do not say

Hosted, managed, “bank-grade”, “military-grade”, unbreakable, “zero trust”, seamless, robust, compliant or certified. Sigra is a library you run inside your own app, and it does not certify anything for you.

## The idea

**Why one square above the i**

Sigra is two things in two places. The library arrives on Hex and updates with `mix deps.update`. The code it generates, the schemas, routes, screens and emails, lands in your repository as ordinary code that you read and change.

The logo draws that line. The letters are the library. The square above the i is the generated code: its own piece, set apart from the word, exactly one stem wide, and the only straight-cornered shape among the round letters. It is the part that is yours to open and change.

The symbol is that i on its own: a stem and its square. The brand uses no padlocks, shields or keys: an auth library that shows them looks like every other one, and says nothing about what is different here.

## Where the brand shows

**Full brand on Sigra’s own pages, a small part of it in the admin, none of it on your users’ screens.**

### Sigra’s own

**README, Hex page, HexDocs, demo, social card**

People deciding whether to use it.

**What shows.** The typemark, the colors, both themes, code colors, the tagline and descriptor.

### In the generated admin

**The admin, at a path the host app chooses**

Admins and support staff of the host app.

**What shows.** The typemark in the top row, the status marks and words, the square on the current tab and the type. A host app may replace the typemark with its own.

### In other people’s writing

**Blog posts, talks, newsletters, other READMEs**

People writing about Sigra.

**What shows.** The typemark, unchanged, under the rules in this book. Nothing added.

The sign-in, registration, two-factor and email screens that a host app’s users see carry the host app’s name, logo and colors, which the host sets with `Sigra.Branding`. Sigra may be named in a plain-text footer, if the host chooses.

## Logo: on light, the default theme

**One color.** Soot on Paper. One color is the same drawing in a single color: the square takes the color of the letters. Soot on light, Chalk on dark. Nothing else is redrawn.

**The symbol.** The dotted i alone, for avatars, app icons and stickers. Where the name needs to show, use the typemark instead.

**Drawn for small sizes.** The favicon is drawn for exactly 16 and 32 px, so every edge lands on the pixel grid. Below 16 px, do not use the symbol.

**Light is the default theme.** The logo has a version for each theme. On light, the letters are Soot and the square is Kiln. On dark, the letters are Chalk and the square is Kiln Bright, which is lighter so that it reads on Char. Use the version made for the background; do not make one by inverting the colors of the other.

## Logo: on dark

**One color.** Chalk on Char. One color is the same drawing in a single color: the square takes the color of the letters. Soot on light, Chalk on dark. Nothing else is redrawn.

**The symbol.** The dotted i alone, for avatars, app icons and stickers. Where the name needs to show, use the typemark instead.

**Drawn for small sizes.** The favicon is drawn for exactly 16 and 32 px, so every edge lands on the pixel grid. Below 16 px, do not use the symbol.

**Dark is a full theme.** The logo has a version for each theme. On light, the letters are Soot and the square is Kiln. On dark, the letters are Chalk and the square is Kiln Bright, which is lighter so that it reads on Char. Use the version made for the background; do not make one by inverting the colors of the other.

## Logo: construction

Instrument Sans Bold supplies the letters; the stem, the spacing and the square are drawn for this logo, and the whole word is outlined, so the logo needs no font to display.

**Built from one unit.**

T is the width of the i’s stem. It is the only measurement; every other distance is a share of it.

| Part | Measure |
| --- | --- |
| **The square** | 1 T on each side, the same as the stem it sits above. |
| **Space between letters** | Tuned by eye on the logo at display size, then checked by measure. Across the height of the x the average open gap is 0.7 T between i and g and between g and r, and 0.9 T between s and i and between r and a, where the s’s terminal and the r’s arm read tighter than they measure. The font’s own spacing let the r’s arm touch the a. The drawing, not a formula, is the authority. |
| **Space from the square to the stem** | 0.4 T. A vertical gap looks larger than a horizontal one of the same size, so it is drawn smaller than the space between letters. |
| **Clear space** | 2 T on every side, measured from the outermost edge of the typemark. |

### The symbol

The symbol is the i alone: the stem and its square, with the same measures. The favicon and the avatar are drawn on the pixel grid, not scaled down.

## Symbol and favicon

**The symbol, drawn for small sizes.**

The symbol alone is the dotted i, for avatars, app icons and stickers. The favicon is drawn for exactly 16 and 32 px, so every edge lands on the pixel grid. Below 16 px, do not use the symbol.

The 16 px favicon is a stem 4 px wide, a square of 4 by 4 px and a gap of 2 px; the 32 px one is 8, 8 by 8 and 3. Every edge is a whole pixel. At 16 px the mark is small: it can read as a speck, or as an exclamation mark turned upside down. No one has tested it with readers. The browser tab follows the theme: `favicon.svg` draws the stem in Soot and the square in Kiln on a light device, and in Chalk and Kiln Bright on a dark one. The `.ico` is the light drawing only, because an ICO can’t change with the theme.

The browser tab at true size: the 16 px icon beside a plain page title.

No shape behind it: the typemark sits directly on the page background. The one exception is the avatar, a 512 px square with the symbol on Paper or Char, because social sites need an opaque square.

## Clear space and minimum size

Keep clear space on every side equal to 2 T, twice the square’s side, measured from the outermost edge of the typemark. Nothing enters it: no text, edge or other logo.

### On screenshots and photographs

- Place the typemark on a calm area at least as wide as the typemark and its clear space.
- Use the light drawing on a light area and the dark drawing on a dark one. If neither reads well, move the logo.
- Do not put a shape or a shadow behind it to make it read.

### Minimum size

|   | Screen | Print |
| --- | --- | --- |
| **Typemark** | 96 px wide | 25 mm wide |
| **The symbol, drawn for its size** | 16 px wide | Not specified |

On screen, the typemark is never narrower than 96 px and the symbol never narrower than 16 px. In print, the typemark is never narrower than 25 mm.

### Color

The square is never green, blue or red, and it is never recolored to match a host app. Square-dot wordmarks are common. This logo relies on its drawing, the Kiln color and the word beside it to be told apart; that is a design judgment, not a legal one. Do not use the square alone as a bullet, a badge or a pattern.

### Retired

The earlier mark is retired: the word set in Space Grotesk with an extended g that ran under the i, and a standalone mark of an L and a square. The extended g read as an underline, and the L and square read as a letter J.

## Logo: misuse

✕Don’t stretch, squeeze or rotate the typemark.

✕Don’t recolor the square or the letters, or make the square green, blue or red.

✕Don’t put a tile, badge or any other shape behind the typemark.

✕Don’t add the tagline, the descriptor or any text to the typemark.

✕Don’t move the square, round it into a circle, or add a second one.

✕Don’t use the dark drawing on a light page, or the light drawing on a dark one.

## Color: light, the default

**Paper**

#F7F3EE RGB 247 243 238

The default background, in the book, the docs and the admin.

About 60% of a light screen.

**White**

#FFFFFF RGB 255 255 255

The detail panel, form fields and the table surface.

About 22% of a light screen.

**Soot**

#1F1A17 RGB 31 26 23

Text, and the letters in the logo on light.

About 9% of a light screen.

**Kiln**

#C2410C RGB 194 65 12

The square in the logo, the one main button per screen, the square on the current tab and the edge rule on the selected row.

About 5% of a light screen.

**Paper Line**

#DDD3C8 RGB 221 211 200

Dividing lines. Never the only edge of a control.

About 4% of a light screen.

**Muted Soot**

#5F554D

Secondary text on Paper and White.

**Kiln Deep**

#9A3412

Links, the focus ring and the current tab on light. It is darker than Kiln so that small text passes on Paper and White.

**Sunken Paper**

#EFE9E1

The ground of a table header, on light.

**Selected Paper**

#EADFD2

The ground of the selected row, on light. Darker than Paper so the row is plainly picked out.

**Control Edge**

#857569

The border of an input or a button on light (4.0:1 on Paper). Dark uses #8B7D72.

## Color: dark

**Char**

#17120F RGB 23 18 15

The dark background.

About 60% of a dark screen.

**Char Surface**

#221B17 RGB 34 27 23

The detail panel, form fields and the table surface on Char.

About 22% of a dark screen.

**Chalk**

#F3EEE8 RGB 243 238 232

Text, and the letters in the logo on dark.

About 9% of a dark screen.

**Kiln Bright**

#F08A55 RGB 240 138 85

The square in the logo on dark, links, the focus ring, the one main button per screen, the square on the current tab and the edge rule on the selected row.

About 5% of a dark screen.

**Char Line**

#3A2F28 RGB 58 47 40

Dividing lines on dark.

About 4% of a dark screen.

**Muted Chalk**

#B8ABA0

Secondary text on Char and Char Surface.

**Control Edge**

#8B7D72

The border of an input or a button on dark.

**Sunken Char**

#120E0C

The ground of code blocks and of a table header on dark.

**Selected Char**

#33281F

The ground of the selected row on dark. Lighter than Char so the row is plainly picked out.

## Color: user statuses

**Five statuses, each a word, a mark and a color.**

A user’s status is always written as a word. The status mark and its color support the word; they do not replace it.

**The symbol**The dotted i of the logo, alone.

**The status mark**One square in the state a user is in: a check, a dashed frame, a bar, two bars, or a quarter filled.

In a list row the mark is 20 px tall and in a detail view 24 px. It is drawn larger on this page to show its shape. The smallest size drawn in this book is 14 px, and it has not been tested smaller. Shape separates the five without color: a fill, a dashed frame or a plain frame, then a glyph. Three of the five, Unconfirmed, Locked and Deleting, are the ones that need an admin, so they share one yellow ochre; none is red.

## Color: contrast pairs

| Role | Where it is used | Light | Dark | Minimum |
| --- | --- | --- | --- | --- |
| **Body text** | README, docs, the admin and this book. | Aa15.60:1 | Aa16.11:1 | 4.5:1 |
| **Descriptor and secondary text** | The descriptor beside the logo, and metadata under a title. | Aa6.57:1 | Aa8.29:1 | 4.5:1 |
| **Caption and table metadata** | Captions, times and column heads. | Aa7.26:1 | Aa7.57:1 | 4.5:1 |
| **Copy inside an application** | Text on a panel in the admin or README. | Aa17.24:1 | Aa14.72:1 | 4.5:1 |
| **Link, focus ring and current tab** | Links, the focus ring and the current tab. | Aa7.31:1 | Aa6.85:1 | 4.5:1 |
| **Focus ring on the page** | The 2 px ring on a focused control, against the page. | 6.61:1 | 7.50:1 | 3:1 |
| **Logo square** | The Kiln square against the page, as a shape. | 4.69:1 | 7.50:1 | 3:1 |
| **Main button** | The label on the one Kiln button per screen. | Aa5.18:1 | Aa7.50:1 | 4.5:1 |
| **Secondary text on a selected row** | Addresses and notes on the selected row of a list. | Aa5.52:1 | Aa6.40:1 | 4.5:1 |
| **Status word on a selected row** | The status word of the selected row, in the ochre. | Aa4.61:1 | Aa7.47:1 | 4.5:1 |
| **Status word: Active** | The word “Active” in a table row. | Aa6.52:1 | Aa8.76:1 | 4.5:1 |
| **Status word: Unconfirmed** | The word “Unconfirmed”. | Aa6.06:1 | Aa8.84:1 | 4.5:1 |
| **Status word: Locked** | The word “Locked”. | Aa6.06:1 | Aa8.84:1 | 4.5:1 |
| **Status word: Suspended** | The word “Suspended”, in Muted Soot. | Aa7.26:1 | Aa7.57:1 | 4.5:1 |
| **Status word: Deleting** | The word “Deleting”. | Aa6.06:1 | Aa8.84:1 | 4.5:1 |

### About these ratios

Ratios are WCAG 2.2 contrast, computed from the hex values. A pair that passes here says nothing about a whole product built with it. Kiln on Paper is 4.7:1: enough for the square and the button label. Links use Kiln Deep, which passes on every surface. Paper Line and Char Line only divide space.

### Never

- **Kiln** as small text on Char (use Kiln Bright)
- **Paper Line** as the only edge of a control (use Control Edge)
- **a status color** as the only way to tell a status

## Type

Regular (400), SemiBold (600) and Bold (700).

The wordmark, headlines, body text, the admin, tables, buttons and labels. One family does all of it, so the logo and the page look like the same hand.

The wordmark is Instrument Sans Bold with its spacing redrawn, so the name and the page share letterforms. Its single-story g and a, flat stems and square-cut terminals sit well beside a square. The arrow characters are in the subset; Red Hat Mono has none, so code never uses them.

Regular (400) and Medium (500).

Anything copied or compared: email addresses in a detail view, commands, tokens, code.

A slashed zero (turn on `font-feature-settings: "zero"`) and distinct l, I and 1 let a token or address be read aloud and copied correctly.

Both families are SIL Open Font License 1.1, from Google Fonts. The license texts are in the assets fonts folder. Red Hat Mono has no arrow characters (U+2190 and U+2192): write “to” or draw the arrow.

## Type: the hierarchy

- Display: Instrument Sans 700, 56 px on 59 px, tracking -0.02em. Use: Covers, slides and social cards. One line, two at most.
- Heading: Instrument Sans 700, 28 px on 34 px, tracking -0.015em. Use: Page titles and section heads in docs and the admin.
- Body: Instrument Sans 400, 16 px on 25 px, tracking 0. Use: README, docs and paragraphs in the admin. 62 to 72 characters a line.
- Dense text: Instrument Sans 400, 13 px on 18 px, tracking 0. Use: Lists of users in the admin. Always with tabular numerals.
- Label: Instrument Sans 600, 12 px on 14 px, tracking 0.02em. Use: Column heads and small labels. Sentence case, never capitals.
- Code: Red Hat Mono 400, 13 px on 20 px, tracking 0. Use: Addresses in a detail view, commands, tokens. Clicking one copies it.

## Type: in a dense list

13 px Instrument Sans with tabular numerals for times and words; addresses in 13 px Red Hat Mono. The times line up by digit, and each status is the mark and its word.

### Made for lists people read closely

- Figures in a column use tabular numerals (`font-variant-numeric: tabular-nums`) so digits stack.
- Every address, token and command is set in Red Hat Mono with the slashed zero on, so it can be compared by eye. Instrument Sans never sets one.
- Clicking an address or a command copies it and shows a short “Copied to clipboard” message. The text itself never moves or changes.
- Headlines are sentence case, and no type is lighter than 400 or smaller than 12 px.
- Code ligatures are off (`font-variant-ligatures: none`), so `|>` and `->` stay as typed.

## Voice: the tone dial

**Plain and specific. It says what happened, to whom and what to do about it, and it says what Sigra does not do.**

- The admin: errors and empty states: 0 of 4 toward lively. “No users match the active filters. Clear all filters.”
- Docs and README: 1 of 4 toward lively. “Run the installer, then read the code it wrote.”
- Release notes: 1 of 4 toward lively. “Locked users now show when they unlock.”
- Talks and social posts: 2 of 4 toward lively. “Auth you can read, in your own repo. Here is what the generators write.”

The voice never changes; the tone shifts with where the words appear. Sigra stays plain everywhere and gets only a little looser in a talk or a post. It is never loose in the admin, because people open it when something is wrong with a user.

## Voice: this, not that

- Say: “Revoke this session for maya.chen@tasklane.test? This signs them out of that browser or device.” Not: “Are you sure you want to proceed?”
- Say: “These users are locked out after failed sign-in attempts. Review the user before unlocking.” Not: “Accounts frozen due to suspicious activity.”
- Say: “Could not save auth branding. Check the values and try again.” Not: “Oops! Something went wrong.”
- Say: “All active sessions revoked.” Not: “Success! You’re all set!”
- Say: “Sigra is not hosted auth. Your users stay in your database.” Not: “Enterprise-grade identity, fully managed.”
- Say: “Fixes arrive with mix deps.update. The code in your repo is yours.” Not: “Auth you can keep patching after install.”
- Say: “Sign in to Tasklane.” Not: “Log in to your account.”

### Write for the people reading

- **Write for support staff who don’t read code.** Name the person’s email address and the thing that happened before any module or error code.
- **Say what they can do next.** Every empty and error state in the admin ends with something the person can do.
- **Spell out the time zone.** Write “2:07 PM UTC”, never a bare time, with the zone on the same line as the time.
- **Keep sign-in errors vague on purpose.** The sign-in and password-reset screens give the same answer whether or not the account exists, so a stranger cannot find out who has one. The admin, which only trusted staff see, is specific.

## How to write our name

**sigra**

Sigra in a sentence, `sigra` in the logo, the package, commands and file names, and `Sigra` where an Elixir module name needs it. Reword a sentence that starts with the lowercase form.

### Not like this

- ~~SIGRA, SiGra~~: one word, one capital at most
- ~~Sig-ra, Sigra.io~~: one word, no suffix
- ~~Sigra Auth, Sigra Cloud~~: Sigra is a library, not a service
- ~~the Sigra platform~~: Sigra is a library

### Describing it

Call it “authentication for Phoenix”, or “a library plus generators”. Say “your app” where this book’s source documents say “the host”. Call the people who use the admin “admins” and the people who sign in “users”.

## Key terms: who and what

**The words sigra depends on.**

| Term | What it means here | Instead of |
| --- | --- | --- |
| **User** | The identity record, on screens outside any organization. The admin glossary is the source for this and the next rows. | ~~account (as a person)~~, ~~customer~~, ~~end user~~ |
| **Member** | A user’s seat with a role inside one organization. The relationship is a membership. | ~~seat~~, ~~teammate~~, ~~collaborator~~ |
| **Organization** | Spelled out in anything a person reads. “org” is for code and URLs only. | ~~org~~, ~~workspace~~, ~~tenant~~ |
| **Sign in, sign out** | The verbs, two words. As a noun or modifier it is hyphenated: sign-in page, failed sign-in attempt. | ~~log in~~, ~~login~~, ~~log out~~, ~~logout~~ |
| **Session** | One signed-in browser or device. Sessions, never logins. | ~~logins~~ |
| **Revoke** | End a live session, API key or sent invitation. | ~~delete~~, ~~cancel~~ |
| **Suspend** | An admin blocks a user on purpose. Reversible: the admin unsuspends. | ~~ban~~, ~~disable~~, ~~deactivate~~ |
| **Lock** | Sigra blocks a user after repeated failed sign-in attempts. It clears by itself, or an admin unlocks it. | ~~freeze~~, ~~suspend~~ |
| **Delete** | Permanently destroy the user and their data. Taking a member out of an organization is “remove”. | ~~destroy~~, ~~remove (for the user)~~ |

## Key terms: actions and setup

| Term | What it means here | Instead of |
| --- | --- | --- |
| **Role and permission** | A role is a bundle of authority (owner, admin, member). A permission is one capability within it. | ~~access level~~, ~~group~~, ~~scope~~ |
| **Effective user** | In an audit log, the user an admin was acting as while impersonating. The actor is the admin. | ~~target~~, ~~victim~~, ~~subject~~ |
| **Confirm it’s you again** | What a screen says when it asks a signed-in user to prove who they are before a sensitive step. The code calls this sudo mode; screens do not. This wording is a recommendation, not found in the product today. | ~~sudo mode~~, ~~re-authenticate~~, ~~step-up~~ |
| **Backup codes** | Single-use codes for when the authenticator app is not available. The product’s own word; providers vary, and this book did not check them. | ~~recovery codes (unchecked)~~ |
| **Magic link** | A one-time sign-in link sent by email. | ~~passwordless link~~, ~~login link~~ |
| **Passkey** | A sign-in credential kept on the user’s device, not a password. Technically WebAuthn. | ~~WebAuthn (in screens)~~, ~~security key~~ |
| **Generated code** | The schemas, routes, screens and emails `mix sigra.install` writes into your repo. They are yours. | ~~scaffold~~, ~~boilerplate~~ |
| **Your app** | The Phoenix app that uses Sigra. In the contract and technical docs it is “the host”, glossed once. | ~~host~~, ~~parent app~~, ~~consumer~~ |

These are only the words the brand depends on. “Locked” and “Unconfirmed” appear in the generated admin today; “Suspended” is defined in its glossary; “Deleting” is this book’s word for a user scheduled for deletion, since the admin shows a line “Deletion: Active”. The phrase “sign in” is the admin glossary’s decision and is enforced by a test; Phoenix’s own `phx.gen.auth` documentation says “log in”. Mix, ExDoc, HexDocs, LiveView, Ecto, Oban and Swoosh are written as proper names, and `mix` appears only as a command.

## Imagery: the real screen

**Show the real screen.**

Sigra’s pictures show the product at work, with its real words: a sign-in page in a host app’s own brand, one user’s audit log, the Users list and a command. They need no stock photography and no symbols of security.

The product pictures in this book are drawings of the layout this book proposes, with invented data. They are not screenshots of the current product.

### Never

- Padlocks, shields and keys
- Fingerprints and faces
- Hooded figures
- Binary rain and glowing grids
- The Phoenix flame or bird
- Stock people at laptops
- Blur and frosted panels
- Neon “secured” badges

Sigra helps people add authentication they can read, and find what is going on with a user. Pictures of padlocks and shields suggest it is a vault you cannot open, which is the opposite of the product. The Phoenix flame and the Elixir drop belong to other projects.

## Imagery: code colors

**Three hues for code, kept apart from the status colors.**

| Role | Light | Dark | Colors |
| --- | --- | --- | --- |
| **Text** | #1F1A17 | #F3EEE8 | Names, functions, modules and punctuation. |
| **Comment** | #6B6057 | #A99C91 | Comments, in a neutral gray-brown. |
| **Keyword** | #9A3412 | #F4A27C | def, do, end, fn, SELECT, in the orange of the links. |
| **String** | #2C5F9E | #7FB0E8 | Strings, in blue. |
| **Atom** | #1F6A8A | #6FC0E0 | Atoms, keys and numbers, in a cyan blue. |
| **Code background** | #EFE8DE | #120E0C | Behind every code block. |

- Code uses three hues, orange, blue and a cyan blue, and two neutrals. It has no green or yellow. Checked in every build: no code color is the same as a status color, and none is within 30 CIELAB units of the Active green or the ochre. The two blues are about 20 units apart: close, and told apart by position in the code more than by color.
- Syntax colors are for code blocks only. Inline code in a sentence is plain Red Hat Mono on a light chip, in every medium.
- ExDoc and HexDocs color their own code. The stylesheet in the assets docs folder sets these colors on ExDoc’s token classes. It has not been run in a real ExDoc build.
- GitHub highlights the code in a README itself, and Sigra does not control those colors.
- Show code that matches the current release, not pseudo-code.

# mix.exs ⏎ {:sigra, "~> 1.7"} ⏎ ⏎ # lib/tasklane_web/router.ex ⏎ scope "/", TasklaneWeb do ⏎ pipe_through [:browser, :require_authenticated] ⏎ ⏎ live "/projects", ProjectLive.Index, :index ⏎ end

# mix.exs ⏎ {:sigra, "~> 1.7"} ⏎ ⏎ # lib/tasklane_web/router.ex ⏎ scope "/", TasklaneWeb do ⏎ pipe_through [:browser, :require_authenticated] ⏎ ⏎ live "/projects", ProjectLive.Index, :index ⏎ end

SELECT email, confirmed_at ⏎ FROM users ⏎ WHERE confirmed_at IS NULL ⏎ ORDER BY inserted_at;

## Graphic elements

**Two graphic elements: the status mark and the square.**

Sigra has two graphic elements, both made from the logo’s square. They are not interface components: buttons, tabs and inputs are drawn by the product.

- **The status mark.** One square in the state a user is in, always with its word beside it. Active is filled with a check. Unconfirmed is a dashed frame with a small square inside. Locked is filled with a bar, a closed gate. Suspended is a frame with two bars. Deleting is a frame with a quarter filled, a countdown. Shape separates the five without color: frame, fill or dashes, then the glyph. In a list row it is 20 px tall and in a detail view 24 px. The smallest size drawn in this book is 14 px; it has not been tested smaller.
- **The square.** The logo’s square, at 8 px, sits before the name of the current tab, one at a time. It is Kiln on light and Kiln Bright on dark. It appears nowhere else in a screen. The selected row is marked another way: a 2 px Kiln rule on its left edge and a sunken ground, so the square never sits beside a status mark.

A status is never shown by the mark alone: its word always comes with it. The mark never decorates a page. The square is never a bullet, a badge or a loading shape.

## Themes: light, dark and system

**Light is the default. Dark is complete. System follows the device.**

### Light, the default

Paper behind White rows, Soot text, Kiln Deep links and one Kiln button. Every text and background pair is contrast-checked.

### Dark

Char behind Char Surface rows, Chalk text, Kiln Bright links and button. The status marks and words use lighter tones of the same colors, and the logo’s square is lighter so that it reads on Char.

### System

The page follows the device’s setting from the moment it loads, and the logo uses the drawing for whichever theme is showing. Choosing a theme applies it at once, with no confirm button.

## Applications: the Users list

The generated admin’s Users list. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### It answers one question

Who can sign in, and who can’t? The list opens with “Needs an admin”: locked, unconfirmed for more than seven days, and scheduled for deletion, each with one plain sentence. Everyone else is below, one line each.

### The status is a square in a state

Each row shows one square: filled with a check, dashed, filled with a bar, in a frame with two bars, or in a frame with a quarter filled. The word is always beside it.

### What stays plain

No sidebar, no cards, no tinted pills, no counters dressed as statistics. The counts are filters, and there is no red anywhere. One button, “Invite user”, is Kiln. The selected row has a 2 px Kiln rule on its left edge and a ground a little darker than the page.

### Hidden on purpose

User ids are not on the list. The email address is the name a person recognizes.

## Applications: the Users list, dark

The same screen in dark. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### Same layout, same words

Only the colors change. Each status word keeps its meaning and is at least 4.5:1 against Char Surface (see the contrast pairs page).

### Char, not black

The background is a warm dark brown. Kiln Bright is the one orange; the ochre of the three admin statuses is yellower and lighter, so the two do not blur.

### The selected row

Lighter than the ground, never darker, with a 2 px Kiln Bright rule on its left edge.

## Applications: the audit log

One user’s audit log. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### Plain sentences first

Each row says what happened in a sentence. The product’s event name sits under it in Red Hat Mono, for people who search logs. The row that explains the lock is marked like a selected row.

### Actor and effective user

When an admin impersonates a user, the actor is the admin and the effective user is the person they were acting as. Both are always shown, in separate columns, so nobody reads an admin’s action as the user’s.

### A blank effective user

Nobody was being impersonated, so the cell is empty rather than saying “None”, which would read as missing data.

### Every time has a zone

UTC is written after each time, on the same line. A narrow column never drops it.

## Applications: a sign-in page in the host app’s brand

On a light host app. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

On a dark host app, with the same generated markup. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### It is the host’s page

The people who see it are the host app’s users. It carries the host’s name, logo and colors, which the host sets with `Sigra.Branding`. Nothing on it is Sigra’s brand.

### Sigra, if at all, in the footer

A host app may add “Authentication by Sigra” as plain text. No logo, no color.

### A vague error, on purpose

The message is the same whether or not the account exists, so a stranger cannot find out who has one. Its color is the host app’s own error treatment, red here: Sigra supplies the words and none of the color. The admin, which only trusted staff see, is specific.

### Words from the glossary

“Sign in”, two words. The page title is “Sign in to Tasklane”.

## Applications: a host app’s email

Sign-in link, light email.

Sign-in link, dark email.

Password reset, light email.

Password reset, dark email.

### What these are

A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### It is the host’s email

The people who receive it are the host app’s users. The email keeps the host’s name, colors and voice, and comes from the host’s From address.

### Sigra, if at all, in the footer

A host app may add “Authentication by Sigra” in the footer, as plain text. Nothing else of Sigra appears.

### Never in the subject or the sender

The sender name and the subject line are the host’s. The email never says “Sigra” before the footer.

### The action, then the safe default

Each names the action in its title and on its button, and each ends with what happens if the reader ignores it: nothing.

## Applications: README, docs, Hex and terminal

The README header: the typemark, the line and the descriptor as plain text. The three badges are the usual third-party Hex, docs and license badges, not Sigra’s drawing.

The Hex package page header. Hex draws the page and its box; the text is the brand’s.

A HexDocs page. ExDoc draws the navigation; the brand sets the type and code colors.

A terminal: commands only, in Red Hat Mono on Char.

A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

## Applications: link preview

The link preview, 1280 by 640 px, shown at half size: the one full-bleed dark canvas, because a preview has no page behind it. A drawing of the layout this book proposes, with invented data. It is not the product’s current screen.

### One canvas

The typemark, the line and the descriptor on Char. The line is set in Instrument Sans and sits beside the logo, never inside it.

### Nothing else

No screenshot, no padlock, no gradient: the square on the i is the only warm shape on the canvas.

## Brand assets: which file to use

| You need | Use (in assets/) |
| --- | --- |
| Logo on a light background | `logo/sigra-lockup-light.svg` `logo/sigra-symbol-light.svg` `logo/sigra-lockup-light-2048.png` |
| Logo on a dark background | `logo/sigra-lockup-dark.svg` `logo/sigra-symbol-dark.svg` `logo/sigra-lockup-dark-2048.png` |
| One color: print and single-color jobs | `logo/sigra-lockup-mono-ink.svg` `logo/sigra-lockup-mono-bone.svg` `logo/sigra-symbol-mono-ink.svg` `logo/sigra-symbol-mono-bone.svg` |
| Favicon (the symbol, drawn for 16 and 32 px) | `icon/favicon.svg` `icon/favicon.ico` `icon/favicon-32-light.png` `icon/favicon-16-light.png` |
| Avatar (a 512 px square, the one logo with a plate) | `avatar/sigra-avatar-light.svg` `avatar/sigra-avatar-dark.svg` `avatar/sigra-avatar-512-light.png` `avatar/sigra-avatar-512-dark.png` |
| README header | `readme/sigra-header-light.svg` `readme/sigra-header-dark.svg` `readme/header-snippet.html` |
| Link preview and social card | `social/sigra-social-card-1280x640.png` |
| Docs: code colors for ExDoc | `docs/sigra-exdoc.css` |
| Fonts | `fonts/web/fonts.css` `fonts/variable/InstrumentSans[wdth,wght].ttf` `fonts/variable/RedHatMono[wght].ttf` `fonts/OFL-InstrumentSans.txt` `fonts/OFL-RedHatMono.txt` |

## Contact, approval and legal

**Who to ask, and what’s ours.**

### Contact and approval

- Questions about the brand and requests to use it: the Sigra maintainers, through the project’s issue tracker.
- Approval: the maintainers approve any use that changes the logo or colors; unchanged use under these rules needs no approval.

### Use by others

- Hex packages, blogs, newsletters and conference sites may use the typemark unchanged to refer to Sigra.
- Do not use it to suggest that Sigra endorses or certifies another product.
- Do not alter the logo, or build a new logo from the square or the i.

### Legal

- Sigra is released under the MIT license. The logo and this brand book are covered by the same license unless the repository says otherwise.
- No trademark registration is claimed in this book, and none was searched. Use ™, not ®, only if the maintainers decide to claim the name.
- Fonts are SIL Open Font License 1.1; their license texts ship in the assets folder.

### Revision history

**Version 2.0**, November 13, 2026. This edition replaces the earlier brand book. The logo is now the word sigra with one square above the i, in Kiln on Paper, drawn from one unit; the symbol is that dotted i alone. It keeps the name, the orange accent and the honest-boundary voice, and adds a construction page, five user statuses drawn as squares, a sign-in page and an email in a host app’s own brand, an audit log, and the ExDoc code colors. It retires the L-shaped rail mark, the extended g, Space Grotesk as a suite face and the word rail.

## Considered and not needed

**Mascot**

Considered, not proposed. A library trusted for being exact and plain gains nothing from a character.

**Patterns and textures**

The status mark and the square are the only graphic devices. A pattern would compete with a dense list, where the words are the picture.

**Stock photography**

There is no honest photograph of “a session”. Real product pictures say it better.

**A second typeface for the logo**

The wordmark and the headlines are both set in Instrument Sans, so no other display face is needed.

**Brand-colored tables**

In a dense list the words should carry the color. Rows stay on White or Char Surface; the status mark carries the only hue.

**Logo animation and sound**

Not defined in this edition. The brand has no motion or sound rules yet; see To review.

## Retired

**What version 2.0 replaces.**

- The word rail: the old logo’s name (“Linked Rail”), the rail accent and the host-rail metaphor. Rails is the rival Ruby framework to Phoenix readers.
- The L-shaped standalone mark, the extended g and the subtitle cut that ran into it. Also considered and not used: a pair of brackets around the square as the symbol (too close to the Adobe Brackets icon and to code-editor icons).
- Space Grotesk as the wordmark face and the rule that seven libraries share it.
- The rule that Sigra uses system font stacks only, for its own pages.
- The color name Ember (it is also a web framework). The color stays, as Kiln.
- The berry and pink direction, which was explored and not chosen.
- A square with one corner cut at 45 degrees as the dot of the i. It was drawn and dropped: it reads as a dog-eared page, the usual file icon, most of all at favicon size, and a cut corner is not a shape anyone can own. The plain square stays.
- The warm amber (#855300 on light, #E3B25C on dark) for the three statuses that need an admin. It sat too close to Kiln. The statuses now use a yellow ochre, #7A5F00 and #D6B957.
- “Auth you can keep patching after install.” as the lead line.

## To review: choices

**Choices made in this edition that are easy to change**

1. **The name is written Sigra in a sentence and sigra in the logo.** The product’s README, Hex page and docs already capitalize it; this book keeps that and writes `sigra` for the logo, the package and commands. Reword any sentence that would start with the lowercase form.
2. **The lead line is “Phoenix auth you own and can still update.”** It replaces “Auth you can keep patching after install.”, where “patching” can mean applying security fixes or hand-hacking the code, and “after install” is vague. The line has not been tested on a reader. It is written for Phoenix developers; the descriptor stays “Production-minded authentication for Phoenix 1.8+”.
3. **The accent is the product’s existing orange, under a new name.** Kiln is `#C2410C`, the value already in the generated admin and auth CSS, the tests and the example app, so no generated code has to change. It is Tailwind’s orange-700, and it is a darker neighbor of Phoenix’s own orange-red. The old color name is dropped because Ember is also a web framework.
4. **The logo is redrawn, not only recolored.** The old typemark was stock Space Grotesk with an extended g. The new one keeps the idea that was ownable, a square on the i, and draws it as a plain square, one stem wide and set 0.4 T above the stem. A square with one corner cut was drawn and dropped: it read as a dog-eared page, the standard file icon, especially at favicon size. A plain square is common, so what makes it this logo is the system under it: one stem wide, a measured gap, optical spacing, and Kiln. An honest read of the result: a stock grotesque with a square above the i. Whether that is distinct enough is a taste call for the owner, not something a check can settle.
5. **The symbol is the dotted i, and a lone i can read as an information icon.** The standalone mark is the stem and its square. On its own, at small sizes, the i with a dot is also the shape of the “info” icon, so the favicon and the avatar are drawn on the pixel grid and the typemark, not the symbol, is used wherever the name needs to show. An earlier idea, a pair of brackets around the square, is retired: it looked like the Adobe Brackets icon and every code-editor icon. A trademark and look-alike search has not been run for either.
6. **The statuses use one color for three of five.** Unconfirmed, Locked and Deleting are the states that need an admin, so they share one yellow ochre (#7A5F00 on light, #D6B957 on dark); the shape of the mark and the word separate them. Active is green. Suspended is a muted gray, drawn as a frame with two bars. None is red: red is kept for business harm and destructive actions, and none of the five is that. “Seven days” for Unconfirmed is this book’s proposal; “Deleting” is this book’s word.
7. **The accent and the statuses are kept apart on purpose.** Kiln is orange. The ochre is about 39 degrees of hue away from it on light and on dark, and every build fails if the gap is under 30: a first amber sat 25 degrees away and read as one muddy family beside Kiln. The ochre is a proposal: the generated admin has no status colors of its own to match. The selected row is marked with a Kiln rule on its left edge and a darker ground, not with the logo’s square, so the square never sits next to a status mark.

## To review: open risks

**Risks and things not done**

1. **The admin glossary is followed, and Phoenix says “log in”.** The glossary enforces “sign in” with a test. Phoenix’s `phx.gen.auth` documentation says “log in”. An app that mixes the two shows both; the book keeps the glossary and flags the mix. The admin still labels people “Admin (operator)” in places; the book says “Admin”.
2. **Adopting the new logo is a coordinated change in the product.** The old accent, the `--sg-*` token names and the old favicon are written into generated CSS, four tests, a Playwright check and the admin screenshots. This book does not change any of them. The brand files land in a `brand/` folder beside `brandbook/`, and the maintainers choose when to switch the favicon, the logo markup and the screenshots.
3. **One family sets the whole page.** Instrument Sans is the wordmark, the headings and the interface; Red Hat Mono is the code. Instrument Sans is a widely used face, so the logo’s distinctness comes from its drawing, not its letters. The generated admin lives in other people’s apps and may keep a system font stack: that is the maintainers’ call, since a web font is a dependency.
4. **A same-name service exists in an adjacent field.** sigra.app is a Swedish free e-signing service that uses BankID. sigra.io is a litigation-verification company, sigra.com is a Colombian supplier, and a German App Store app is called SIGRA. The name was kept. Nothing here is clearance, and it matters most if the product is marketed in Swedish or to identity buyers.
5. **The favicon is the dotted i on the pixel grid, and nobody has looked at it at 16 to 24 px.** A stem of 4 and 8 px and a square of 4 and 8 px land on whole pixels. At 24 px and below the mark can read as an information icon.
6. **The ExDoc stylesheet is not verified and the demo app has two names.** The stylesheet was written from ExDoc’s class names, not run in a build. The README and the launch announcement still name the demo app Vaultr; it is Tasklane in the code and in this book. Hex also lists a release 1.20.0 that the project does not recognize, and the README pins `~> 1.5.0`; the samples here use `~> 1.7`.

**Not checked:** The name was kept and not cleared: lookups of Hex, npm, PyPI, crates.io, RubyGems, GitHub, the US, UK, German and Swedish App Stores and eight domain extensions found no conflict in Elixir, and no trademark register was searched. The logo was drawn and checked on size sheets from 16 to 110 px, in light, dark and one color. No person has looked at it at 16 to 24 px. No trademark or look-alike search was run for a square-dot wordmark or a dotted i. The lead line was not tested on readers. The industry word check came from one source, the Phoenix `phx.gen.auth` documentation, and the wording of backup codes was not compared with other providers. The generated sign-in, two-factor and email screens were not viewed running; only the demo screenshots of the admin were. Print colors are not specified. The book was checked offline in Chrome at 1440 and 390 px; Safari and Firefox were not.
