defmodule Sigra.Brand.CopyContractTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Copy contract (BCOPY-02): brand-book wording must not creep back into shipped
  copy.

  Three scopes, each with its own rules (`Sigra.Test.Brand.CopyScan`):

    * `lexicon` - `README.md`, `guides/introduction/*.md`, `guides/flows/*.md`.
      Lexicon only: the book's "Do not say" words, read from the pinned
      `brand/brand.json`.
    * `admin` - the nine admin chrome files the glossary guard watches plus the
      shipped admin templates. Banned terms (the glossary terms, the book's
      phrase-level avoid-words, "admin (operator)") and the lexicon.
    * `generated` - `priv/templates/sigra.install/**` and
      `priv/templates/sigra.gen.oauth/**`. "log in", "log out",
      "login", "logout", "signin" and "admin (operator)" are banned as COPY
      (string literals, HEEx text and user-visible attribute values such as
      `aria-label`, `aria-description`, `title`, `placeholder`, `label`, `alt`,
      `action`, `data-confirm` and `phx-disable-with`), never as identifiers, route
      paths or telemetry atoms. The lexicon applies to the same copy segments.

  A hit's `kind` is `lexicon` for a Do-not-say word in any scope and
  `banned_term` for a scope term. A hit is the matched text, so no line numbers
  are involved. The committed baseline `test/fixtures/brand/copy-baseline.json`
  holds the hits that exist today, reviewed once (the repo's own negations such
  as "a hosted identity product" in a "when to leave" list, and legacy
  wording such as "Log in" in generated flashes that Phases 262-263 rewrite).
  It is shrink-only:

    * a hit that is not in the baseline fails: fix the copy, never baseline a
      new violation;
    * a baseline entry with no matching hit fails: remove that entry by hand in
      a reviewed commit.

  Initialization is opt-in and only fills scopes that are not yet listed in the
  baseline's `initialized_scopes` (a scope with zero hits still counts):

      SIGRA_BRAND_COPY_BASELINE=init mix test test/sigra/brand/copy_contract_test.exs

  ## Brand-book avoid-words intentionally not banned

  The `admin` scope derives its phrase-level terms from `voice.terms[].avoid`.
  These ordinary-English words are left out because banning them would bury the
  baseline in noise: `delete`, `cancel` (verbs on every destructive action),
  `disable` ("Disable two-factor" is correct copy), `group`, `scope` (generic
  nouns; "scope" also names OAuth scopes), `target`, `subject` (an HTML
  attribute and an email field), `suspend` (canonical in another row), `host`,
  `consumer` (technical words), and every entry with a parenthetical qualifier
  such as "account (as a person)" or "recovery codes (unchecked)", which a regex
  cannot honour.

  `test/sigra/admin/glossary_test.exs` is a separate, older guard and is not
  touched by this one.
  """

  alias Sigra.Test.Brand.CopyScan

  setup_all do
    if CopyScan.init_requested?(), do: CopyScan.init_baseline!()
    :ok
  end

  describe "lexicon_words/0" do
    test "reads the ten Do-not-say terms from the pinned brand book" do
      assert CopyScan.lexicon_words() ==
               [
                 "hosted",
                 "managed",
                 "bank-grade",
                 "military-grade",
                 "unbreakable",
                 "zero trust",
                 "seamless",
                 "robust",
                 "compliant",
                 "certified"
               ]
    end
  end

  describe "scan_lines/3 over scope :lexicon (planted terms, no file I/O)" do
    test "flags a lexicon word in prose" do
      hits = CopyScan.scan_lines(:lexicon, "README.md", ["Sigra is a hosted service"])

      assert [%{scope: "lexicon", kind: "lexicon", file: "README.md", line: line}] = hits
      assert line == "Sigra is a hosted service"
    end

    test "returns nothing for prose without a lexicon word" do
      assert CopyScan.scan_lines(:lexicon, "README.md", ["nothing here"]) == []
    end

    test "matches case-insensitively and keeps the original case in the hit" do
      assert [%{line: "A Seamless flow"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["A   Seamless  flow"])
    end

    test "matches whole words only" do
      assert CopyScan.scan_lines(:lexicon, "x.md", ["the managed_by column", "unmanaged hosts"]) ==
               []
    end

    test "matches multi-word and hyphenated phrases whichever separator is used" do
      lines = ["a zero trust network", "a zero-trust network", "bank grade", "Bank-Grade crypto"]

      assert length(CopyScan.scan_lines(:lexicon, "x.md", lines)) == 4
    end

    test "ignores words inside fenced code blocks and HTML comments" do
      lines = [
        "Plain prose.",
        "```bash",
        "mix hosted.install --managed",
        "```",
        "<!-- a robust note -->",
        "<!--",
        "  seamless",
        "-->",
        "~~~",
        "certified",
        "~~~"
      ]

      assert CopyScan.scan_lines(:lexicon, "x.md", lines) == []
    end

    test "still scans prose after a fenced block closes" do
      lines = ["```", "hosted", "```", "after the fence: robust"]

      assert [%{line: "after the fence: robust"}] = CopyScan.scan_lines(:lexicon, "x.md", lines)
    end

    test "yields at most one hit per line even with two lexicon words" do
      assert [_one] = CopyScan.scan_lines(:lexicon, "x.md", ["hosted and managed"])
    end
  end

  describe "normalize/1" do
    test "trims and collapses whitespace, and carries no line number" do
      assert CopyScan.normalize("  a \t b\n c  ") == "a b c"
    end
  end

  describe "diff_baseline/2 (planted hits and entries)" do
    @hit %{scope: "lexicon", kind: "lexicon", file: "README.md", line: "a hosted thing"}

    test "equal hits and entries produce no difference" do
      assert CopyScan.diff_baseline([@hit], [@hit]) == [new: [], stale: []]
    end

    test "a hit with no baseline entry is new" do
      assert [new: [@hit], stale: []] = CopyScan.diff_baseline([@hit], [])
    end

    test "a baseline entry with no hit is stale" do
      assert [new: [], stale: [@hit]] = CopyScan.diff_baseline([], [@hit])
    end

    test "a second occurrence of an already baselined line is new" do
      assert [new: [@hit], stale: []] = CopyScan.diff_baseline([@hit, @hit], [@hit])
    end

    test "an entry baselined twice is stale once when only one hit remains" do
      assert [new: [], stale: [@hit]] = CopyScan.diff_baseline([@hit], [@hit, @hit])
    end

    test "kind and scope are part of the identity" do
      other = %{@hit | kind: "banned_term"}

      assert [new: [^other], stale: [@hit]] = CopyScan.diff_baseline([other], [@hit])
    end
  end

  describe "init_baseline/3 (opt-in, never rewrites an initialized scope)" do
    @existing %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "kept"}

    test "fills only scopes that are not initialized and records them" do
      scanned = fn
        :lexicon -> [%{@existing | line: "SHOULD NOT BE ADDED"}]
        :admin -> [%{@existing | scope: "admin", line: "added"}]
      end

      result =
        CopyScan.init_baseline(
          %{initialized_scopes: ["lexicon"], entries: [@existing]},
          [:lexicon, :admin],
          scanned
        )

      assert result.initialized_scopes == ["lexicon", "admin"]
      assert result.entries == [@existing, %{@existing | scope: "admin", line: "added"}]
    end

    test "a scope with zero hits still becomes initialized" do
      result =
        CopyScan.init_baseline(
          %{initialized_scopes: [], entries: []},
          [:generated],
          fn :generated ->
            []
          end
        )

      assert result == %{initialized_scopes: ["generated"], entries: []}
    end

    test "an initialized scope is never shrunk or re-scanned" do
      result =
        CopyScan.init_baseline(
          %{initialized_scopes: ["lexicon"], entries: [@existing]},
          [:lexicon],
          fn _scope -> flunk("an initialized scope must not be scanned") end
        )

      assert result == %{initialized_scopes: ["lexicon"], entries: [@existing]}
    end
  end

  describe "render_baseline/2 (deterministic, line-oriented)" do
    test "writes one entry per line, one scope per line, with sorted keys" do
      entries = [
        %{scope: "lexicon", kind: "lexicon", file: "b.md", line: "second \"quoted\""},
        %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "first"}
      ]

      lines = CopyScan.render_baseline(["lexicon"], entries) |> String.split("\n")

      assert "    {\"file\": \"a.md\", \"kind\": \"lexicon\", \"line\": \"first\", \"scope\": \"lexicon\"}," in lines

      assert Enum.count(lines, &String.starts_with?(&1, "    {\"file\"")) == 2
      assert "    \"lexicon\"" in lines
      assert "  \"schema_version\": \"sigra.brand-copy-baseline/v1\"" in lines
    end

    test "is the same text however the input is ordered, and round-trips through JSON" do
      a = %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "x"}
      b = %{scope: "admin", kind: "banned_term", file: "b.ex", line: "y"}

      assert CopyScan.render_baseline(["lexicon", "admin"], [a, b]) ==
               CopyScan.render_baseline(["admin", "lexicon"], [b, a])

      decoded = CopyScan.render_baseline(["lexicon"], [a]) |> JSON.decode!()
      assert decoded["initialized_scopes"] == ["lexicon"]

      assert decoded["entries"] == [
               %{"file" => "a.md", "kind" => "lexicon", "line" => "x", "scope" => "lexicon"}
             ]
    end

    test "an empty scope renders as an empty array and the file ends with a newline" do
      text = CopyScan.render_baseline(["generated"], [])

      assert text =~ "\"entries\": [],"
      assert String.ends_with?(text, "}\n")
    end
  end

  describe "scan_lines/3 over scope :generated (planted terms, no file I/O)" do
    @generated_file "priv/templates/sigra.install/core/example.ex"

    defp generated(lines), do: CopyScan.scan_lines(:generated, @generated_file, lines)

    test "flags a banned term in a flash string literal" do
      assert [%{scope: "generated", kind: "banned_term", file: @generated_file, line: line}] =
               generated([~s'    |> put_flash(:error, "You must log in to access this page.")'])

      assert line == "You must log in to access this page."
    end

    test "joins adjacent string literals before checking copy on one line and across lines" do
      for lines <- [
            [~s'copy = "Please log " <> "in to continue"'],
            [~s'copy = "Please log " <>', ~s'  "in to continue"']
          ] do
        assert [%{kind: "banned_term", line: "Please log in to continue"}] = generated(lines)
      end
    end

    test "flags every banned spelling when it is copy" do
      for phrase <- ["Log in", "log out", "Login", "logout", "signin", "admin (operator)"] do
        assert [%{kind: "banned_term"}] =
                 generated([~s'put_flash(:info, "Please #{phrase} now")']),
               "expected #{inspect(phrase)} to be flagged as copy"
      end
    end

    test "flags HEEx text and dgettext msgids" do
      lines = [
        ~s'~H"""',
        ~s'<.link navigate={~p"/users/log_in"}>',
        ~s'  {dgettext("sigra", "Log in")}',
        ~s'</.link>',
        ~s'<p>Back to log in</p>',
        ~s'"""'
      ]

      assert Enum.map(generated(lines), & &1.line) == ["Log in", "Back to log in"]
    end

    test "flags the copy attributes and nothing else on a tag" do
      for attr <- [
            "aria-label",
            "aria-description",
            "title",
            "placeholder",
            "label",
            "alt",
            "action",
            "data-confirm",
            "phx-disable-with"
          ] do
        assert [%{line: "Log in here"}] =
                 generated([~s'~H"""', ~s'<input #{attr}="Log in here" />', ~s'"""']),
               "expected #{attr} to be scanned"
      end

      markup = [
        ~s'~H"""',
        ~s'<input class="login log in" id="log in" name="login" data-testid="log in" phx-click="log out" />',
        ~s'"""'
      ]

      assert generated(markup) == []
    end

    test "does not flag identifiers, route paths, atoms, comments or docs" do
      lines = [
        ~s'  @moduledoc "Log in and log out helpers."',
        ~s'  @doc """',
        ~s'  Log in the user, then redirect to the login page.',
        ~s'  """',
        ~s'  # Log in the user, or log out.',
        ~s'  def log_in_user(conn, user) do',
        ~s'    redirect(conn, to: ~p"/users/log_in")',
        ~s'    redirect(conn, to: "/users/log_in")',
        ~s'    :telemetry.execute([:sigra, :auth, :logout, :stop], %{}, %{})',
        ~s'    [:sigra, :auth, :logout, :stop],',
        ~s'    assign(socket, :mode, "login")',
        ~s'    login_form = to_form(%{}, as: "login_form")',
        ~s'    socket = assign(socket, :signin, true)',
        ~s'    Routes.session_path(conn, :login)',
        ~s'~H"""',
        ~s'<.link navigate={~p"/users/log_in"} phx-click={JS.push("login")}>x</.link>',
        ~s'<form id="login_form" action="/users/log_in" method="post"></form>',
        ~s'"""'
      ]

      assert generated(lines) == []
    end

    test "flags the lexicon in copy, and not in identifiers" do
      assert [%{kind: "lexicon", line: "A seamless experience."}] =
               generated([~s'put_flash(:info, "A seamless experience.")'])

      assert generated(["def seamless(conn), do: hosted_domain(conn)"]) == []
    end

    test "a segment with both a banned term and a lexicon word yields one hit of each kind" do
      hits = generated([~s'put_flash(:info, "A seamless way to log in")'])

      assert hits |> Enum.map(& &1.kind) |> Enum.sort() == ["banned_term", "lexicon"]
    end

    test "installer EEx tags are removed and runtime EEx tags are kept" do
      lines = [
        ~s'<%= if @feature do %>',
        ~s'  put_flash(:info, "Please log in <%= @suffix %> again")',
        ~s'<% end %>',
        ~s'~H"""',
        ~s'<%%= dgettext("sigra", "Log out of all devices") %>',
        ~s'<%% :new -> %>',
        ~s'"""'
      ]

      assert Enum.map(generated(lines), & &1.line) == [
               "Please log in again",
               "Log out of all devices"
             ]
    end

    test "email heredocs are scanned, interpolations contribute only their literals" do
      lines = [
        ~s'html = """',
        ~s'<p style="color: red; font-family: \#{@font_family};">Log in to continue</p>',
        ~s'\#{cta_button(dgettext("sigra", "Log in with %{provider}", provider: name), log_in_url)}',
        ~s'"""'
      ]

      assert Enum.map(generated(lines), & &1.line) == [
               "Log in to continue",
               "Log in with %{provider}"
             ]
    end
  end

  describe "scan_lines/3 over scope :admin (planted terms, no file I/O)" do
    @admin_file "lib/sigra/admin/live/example_live.ex"

    defp admin(lines), do: CopyScan.scan_lines(:admin, @admin_file, lines)

    test "flags a glossary term in HEEx text, as the glossary guard does" do
      lines = [~s'~H"""', ~s'<h2 class="sg-heading">Login preview</h2>', ~s'"""']

      assert [%{scope: "admin", kind: "banned_term", line: "Login preview"}] = admin(lines)
    end

    test "flags a glossary term inside an action attribute value" do
      lines = [~s'~H"""', ~s'<.empty_state action="Review logins" />', ~s'"""']

      assert [%{line: "Review logins"}] = admin(lines)
    end

    test "every glossary term is still caught" do
      for phrase <- [
            "log in",
            "log out",
            "logout",
            "signin",
            "sign off",
            "login",
            "logins",
            "org",
            "teammate",
            "teammates",
            "collaborator",
            "seat"
          ] do
        assert [%{kind: "banned_term"}] = admin([~s'put_flash(:info, "Say #{phrase} here")']),
               "expected #{inspect(phrase)} to be flagged"
      end
    end

    test "flags the book's phrase-level avoid-words and 'admin (operator)'" do
      for phrase <- [
            "end user",
            "workspace",
            "tenant",
            "scaffold",
            "parent app",
            "sudo mode",
            "access level",
            "Admin (operator)"
          ] do
        assert [%{kind: "banned_term"}] = admin([~s'put_flash(:info, "The #{phrase} sees this")']),
               "expected #{inspect(phrase)} to be flagged"
      end
    end

    test "does not ban the ordinary-English avoid-words the moduledoc excludes" do
      for phrase <- ~w(delete cancel disable group scope target subject suspend host consumer) do
        assert admin([~s'put_flash(:info, "Please #{phrase} the thing")']) == [],
               "#{inspect(phrase)} must not be banned"
      end
    end

    test "a hyphen in a derived phrase is literal" do
      assert [%{line: "Complete the step-up check"}] =
               admin([~s'put_flash(:info, "Complete the step-up check")'])

      assert admin([~s'put_flash(:info, "Please step up and review")']) == []
    end

    test "flags the lexicon in admin copy" do
      lines = [~s'~H"""', ~s'<p>A robust, seamless admin.</p>', ~s'"""']

      assert [%{scope: "admin", kind: "lexicon", line: "A robust, seamless admin."}] =
               admin(lines)
    end

    test "does not flag identifiers, test ids or comments" do
      lines = [
        ~s'  # Log in preview, a robust note',
        ~s'  def login_preview(assigns), do: assigns',
        ~s'  attr :login_testid, :string, default: "admin-auth-branding-light-login-preview"',
        ~s'  def hosted(conn), do: conn',
        ~s'~H"""',
        ~s'<section data-testid="login-preview" data-sg-auth-branding-preview="login" class="sigra-login">',
        ~s'  <%!-- Login preview, hosted --%>',
        ~s'</section>',
        ~s'"""'
      ]

      assert admin(lines) == []
    end

    test "exempts the auth-replica preview block but still scans the heading above it" do
      lines = [
        ~s'~H"""',
        ~s'<section>',
        ~s'  <h2>Login preview</h2>',
        ~s'  <div',
        ~s'    class="sigra-auth sigra-auth--preview"',
        ~s'    data-theme={@theme}',
        ~s'  >',
        ~s'    <div class="sigra-auth__panel">',
        ~s'      <h1>Log in</h1>',
        ~s'      <p>A seamless sign-in.</p>',
        ~s'    </div>',
        ~s'  </div>',
        ~s'  <h2>Email preview</h2>',
        ~s'</section>',
        ~s'"""'
      ]

      assert Enum.map(admin(lines), & &1.line) == ["Login preview"]
    end

    test "the carve-out is admin-only: the same block is scanned under :generated" do
      lines = [
        ~s'~H"""',
        ~s'<div class="sigra-auth sigra-auth--preview">',
        ~s'  <h1>Log in</h1>',
        ~s'</div>',
        ~s'"""'
      ]

      assert [%{line: "Log in"}] = generated(lines)
      assert admin(lines) == []
    end
  end

  describe "hard-wrapped phrases (a phrase split across a line break is still a hit)" do
    test "Markdown: a lexicon phrase wrapped across lines is flagged with the lines it spans" do
      lines = ["Our approach is not zero", "trust and not bank-", "grade either."]

      hits = CopyScan.scan_lines(:lexicon, "x.md", lines)

      assert Enum.all?(hits, &(&1.scope == "lexicon" and &1.kind == "lexicon"))

      assert hits |> Enum.map(& &1.line) |> Enum.sort() ==
               [
                 "Our approach is not zero trust and not bank-",
                 "trust and not bank- grade either."
               ]
    end

    test "Markdown: a list item and a block quote join their own continuation lines" do
      assert [%{line: "A zero trust model"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["- A zero", "  trust model"])

      assert [%{line: "a bank- grade lock"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["> a bank-", "> grade lock"])
    end

    test "Markdown: a wrapped phrase in a second list item, wrapped after a first item, is flagged" do
      lines = ["- First item", "- A zero", "  trust model"]

      assert [%{line: "A zero trust model"}] = CopyScan.scan_lines(:lexicon, "x.md", lines)
    end

    test "Markdown: lines that are separate blocks are never joined" do
      for lines <- [
            ["zero", "", "trust"],
            ["# Zero", "trust model"],
            ["zero", "# trust"],
            ["| zero |", "| trust |"],
            ["- zero", "- trust"],
            ["zero", "---", "trust"],
            ["<p>zero</p>", "trust"],
            ["zero", "```", "code", "```", "trust"]
          ] do
        assert CopyScan.scan_lines(:lexicon, "x.md", lines) == [],
               "#{inspect(lines)} must not be joined into one phrase"
      end
    end

    test "Markdown: a phrase inside one line is still one hit, with or without a line after it" do
      assert [%{line: "a zero trust network"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["a zero trust network"])

      assert [%{line: "a zero trust network"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["a zero trust network", "and more text"])
    end

    test "HEEx: a banned phrase wrapped inside one element is flagged as one segment text" do
      lines = [~s'~H"""', ~s'<p>', ~s'  Please log', ~s'  in to continue', ~s'</p>', ~s'"""']

      assert [%{kind: "banned_term", line: "Please log in to continue"}] = generated(lines)
      assert [%{kind: "banned_term", line: "Please log in to continue"}] = admin(lines)
    end

    test "HEEx: a lexicon phrase wrapped with a hyphen is flagged" do
      lines = [~s'~H"""', ~s'<p>Not bank-', ~s'grade at all.</p>', ~s'"""']

      assert [%{kind: "lexicon", line: "Not bank- grade at all."}] = generated(lines)
    end

    test "HEEx: the per-line segments are unchanged by wrapping" do
      lines = [~s'~H"""', ~s'<p>', ~s'  Please log', ~s'  in to continue', ~s'</p>', ~s'"""']

      assert CopyScan.copy_segments(:generated, @generated_file, lines) ==
               ["Please log", "in to continue"]
    end

    test "HEEx: a following line that opens with a tag or an expression is a separate node" do
      for body <- [
            [~s'<h1>Please log</h1>', ~s'<p>in to continue</p>'],
            [~s'<p>Please log', ~s'{@name} in</p>']
          ] do
        assert generated([~s'~H"""' | body] ++ [~s'"""']) == [],
               "#{inspect(body)} must not be joined into one phrase"
      end
    end

    test "HEEx: a phrase inside one line is one hit, however the next line reads" do
      lines = [~s'~H"""', ~s'<p>Please log in', ~s'to continue</p>', ~s'"""']

      assert [%{line: "Please log in"}] = generated(lines)
    end

    test "heredoc text: a phrase wrapped across the lines of an email body is flagged" do
      lines = [~s'html = """', ~s'Please log', ~s'in to continue', ~s'"""']

      assert [%{kind: "banned_term", line: "Please log in to continue"}] = generated(lines)
    end

    test "admin: a phrase-level avoid-word wrapped across lines is flagged" do
      lines = [~s'~H"""', ~s'<p>the end', ~s'user sees this</p>', ~s'"""']

      assert [%{kind: "banned_term", line: "the end user sees this"}] = admin(lines)
    end
  end

  describe "scanner blind spots stay closed (planted sources)" do
    test "a keyword that merely ends in doc is copy, a doc: option is not, on one line or the next" do
      assert [%{line: "Please log in now"}] =
               generated([~s'opts = [my_doc: "Please log in now"]'])

      assert [%{line: "Please log in now"}] =
               generated([~s'opts = [undoc: "Please log in now"]'])

      for source <- [
            [~s'  attr :x, :string, doc: "Please log in now"'],
            [~s'  attr :x, :string,', ~s'    doc: "Please log in now"'],
            [~s'  attr :x, :string,', ~s'    doc:', ~s'      "Please log in now"']
          ] do
        assert generated(source) == [], "#{inspect(source)} documents a component, it is not copy"
      end
    end

    test "a single-quoted copy attribute value is copy, any other single-quoted value is not" do
      for attr <- [
            "aria-label",
            "aria-description",
            "title",
            "placeholder",
            "label",
            "alt",
            "action",
            "data-confirm",
            "phx-disable-with"
          ] do
        assert [%{line: "Log in here"}] =
                 generated([~s'~H"""', ~s'<a #{attr}=\'Log in here\'>x</a>', ~s'"""']),
               "expected single-quoted #{attr} to be scanned"
      end

      markup = [
        ~s'~H"""',
        ~s'<a class=\'login log in\' id=\'log in\' data-x=\'log out\'>x</a>',
        ~s'"""'
      ]

      assert generated(markup) == []
    end

    test "an unterminated single-quoted attribute value raises naming the file" do
      assert_raise ArgumentError,
                   ~r/example\.ex: unterminated single-quoted attribute value/,
                   fn ->
                     CopyScan.copy_segments(:generated, @generated_file, [
                       ~s'~H"""',
                       ~s'<a title=\'x>',
                       ~s'"""'
                     ])
                   end
    end

    test "~H with any delimiter is markup, not a skipped sigil" do
      # `/` and `<` are left out: Elixir ends the sigil at the first `/` or `>`, which
      # markup always contains, so such a sigil cannot hold a tag.
      for {open, close} <- [{"(", ")"}, {"[", "]"}, {"{", "}"}, {"|", "|"}] do
        source = [~s'~H#{open}<p>Please log in now</p>#{close}']

        assert [%{kind: "banned_term", line: "Please log in now"}] = generated(source),
               "~H#{open}...#{close} was not scanned"
      end

      assert [%{line: "Please log in now"}] =
               generated([~s'~H\'\'\'', ~s'<p>Please log in now</p>', ~s'\'\'\''])

      assert [%{line: "Please log in now"}] =
               generated([~s'~H(', ~s'  <p>Please log in now</p>', ~s')'])
    end

    test "a ~H body with another delimiter ends at the first closing delimiter, and later code is scanned" do
      lines = [~s'x = ~H(<p>Fine</p>)', ~s'put_flash(:info, "Please log in now")']

      assert [%{line: "Please log in now"}] = generated(lines)
    end

    test "an unterminated ~H with another delimiter raises naming the file" do
      assert_raise ArgumentError, ~r/example\.ex: unterminated sigil/, fn ->
        CopyScan.copy_segments(:generated, @generated_file, [~s'~H(<p>never closed</p>'])
      end
    end

    test "a character literal is not a comment or a string" do
      for char <- ["?#", ~s'?"', "?\\n", "?a"] do
        assert [%{line: "Please log in"}] =
                 generated([~s'x = #{char}; put_flash(:info, "Please log in")']),
               "#{char} hid the copy after it"
      end

      assert generated([~s'x = 1 # put_flash(:info, "Please log in")']) == []
    end

    test "a ? at the end of an identifier is not a character literal" do
      assert [%{line: "Please log in"}] =
               generated([~s'if ready? do put_flash(:info, "Please log in") end'])
    end

    test "a preview marker on any element but a <div> raises instead of exempting its parent" do
      lines = [
        ~s'~H"""',
        ~s'<div class="outer"><h2>Login preview</h2>',
        ~s'<section class="sigra-auth sigra-auth--preview"><p>x</p></section>',
        ~s'<p>Org settings</p></div>',
        ~s'"""'
      ]

      error = assert_raise ArgumentError, fn -> admin(lines) end

      assert error.message =~ "example_live.ex:"
      assert error.message =~ "<section>, not a <div>"
    end

    test "a preview marker on a <div> is still exempt, and the text around it is still scanned" do
      lines = [
        ~s'~H"""',
        ~s'<div class="outer"><h2>Login preview</h2>',
        ~s'<div class="sigra-auth sigra-auth--preview"><p>Log in</p></div>',
        ~s'<p>Org settings</p></div>',
        ~s'"""'
      ]

      assert Enum.map(admin(lines), & &1.line) == ["Login preview", "Org settings"]
    end
  end

  describe "copy_segments/3 (extraction rules)" do
    test "returns the text nodes, expression literals and copy attributes of a ~H body in order" do
      lines = [
        ~s'~H"""',
        ~s'<.header>',
        ~s'  {dgettext("sigra", "Email confirmed")}',
        ~s'  <:subtitle>Your email has been confirmed.</:subtitle>',
        ~s'</.header>',
        ~s'<input placeholder="Email address" class="x" data-confirm="Are you sure?" />',
        ~s'<p :if={@locked}>{if @locked, do: "Locked", else: "Active"}</p>',
        ~s'"""'
      ]

      assert CopyScan.copy_segments(:generated, @generated_file, lines) ==
               [
                 "Email confirmed",
                 "Your email has been confirmed.",
                 "Email address",
                 "Are you sure?",
                 "Locked",
                 "Active"
               ]
    end

    test "string literals need a letter and a space or a capital to count as copy" do
      lines = [
        ~s'a = "login"',
        ~s'b = "Login"',
        ~s'c = "log in"',
        ~s'd = "/users/log_in"',
        ~s'e = "https://example.test/log in"',
        ~s'f = "12 34"'
      ]

      assert CopyScan.copy_segments(:generated, @generated_file, lines) == ["Login", "log in"]
    end

    test "a raised segment keeps its interpolation out of the text" do
      lines = [~s'put_flash(:info, "Hello \#{user.name}, log in")']

      assert CopyScan.copy_segments(:generated, @generated_file, lines) == ["Hello , log in"]
    end

    test "an unterminated string raises naming the file instead of being skipped" do
      assert_raise ArgumentError, ~r/example\.ex: unterminated string literal/, fn ->
        CopyScan.copy_segments(:generated, @generated_file, [~s'put_flash(:info, "never closed)'])
      end
    end

    test "an unterminated tag and an unterminated heredoc raise naming the file" do
      assert_raise ArgumentError, ~r/example\.ex: unterminated tag/, fn ->
        CopyScan.copy_segments(:generated, @generated_file, [
          ~s'~H"""',
          ~s'<input placeholder="x"',
          ~s'"""'
        ])
      end

      assert_raise ArgumentError, ~r/example\.ex: unterminated heredoc/, fn ->
        CopyScan.copy_segments(:generated, @generated_file, [~s'x = """', "text"])
      end
    end
  end

  describe "scope file lists (non-vacuous)" do
    test "the admin scope is the nine glossary files plus the shipped admin templates" do
      files = CopyScan.files_for(:admin)

      for file <- [
            "lib/sigra/admin/components.ex",
            "lib/sigra/admin/live/branding_live.ex",
            "lib/sigra/admin/live/user_show_live.ex",
            "priv/templates/sigra.install/admin/components/admin_shell.ex"
          ] do
        assert file in files
      end

      assert Enum.count(files, &String.starts_with?(&1, "lib/sigra/admin/")) == 9
      assert Enum.any?(files, &String.starts_with?(&1, "priv/templates/sigra.install/admin/"))
      assert Enum.all?(files, &(Path.extname(&1) in [".ex", ".eex", ".heex"]))
    end

    test "the generated scope is every code template and no CSS or SVG" do
      files = CopyScan.files_for(:generated)

      assert length(files) >= 50
      assert "priv/templates/sigra.install/core/emails.ex" in files
      assert "priv/templates/sigra.install/core/user_auth.ex" in files
      assert "priv/templates/sigra.gen.oauth/oauth_controller.ex" in files

      assert Enum.all?(files, fn file ->
               String.starts_with?(file, "priv/templates/sigra.install/") or
                 String.starts_with?(file, "priv/templates/sigra.gen.oauth/")
             end)

      assert Enum.all?(files, &(Path.extname(&1) in [".ex", ".eex", ".heex"]))
    end

    test "upgrade templates are deliberately outside the generated-copy scope" do
      files = CopyScan.files_for(:generated)

      upgrade_files =
        Path.wildcard("priv/templates/sigra.upgrade/**/*") |> Enum.filter(&File.regular?/1)

      assert upgrade_files != []
      refute Enum.any?(files, &String.starts_with?(&1, "priv/templates/sigra.upgrade/"))

      for path <- upgrade_files do
        source = File.read!(path)

        refute source =~ ~r/~H\b|dgettext\(|put_flash\(/,
               "#{path} must remain migration code without user-facing copy forms"
      end
    end

    test "the code scopes extract real copy from real files" do
      lines = "priv/templates/sigra.install/core/emails.ex" |> File.read!() |> String.split("\n")

      segments =
        CopyScan.copy_segments(:generated, "priv/templates/sigra.install/core/emails.ex", lines)

      assert length(segments) > 20
      assert "Log in to %{app_name}" in segments
    end
  end

  describe "committed baseline (shrink-only)" do
    test "the baseline file is exactly what the renderer would write" do
      %{initialized_scopes: scopes, entries: entries} = CopyScan.load_baseline()

      assert File.read!(CopyScan.baseline_path()) == CopyScan.render_baseline(scopes, entries),
             "copy-baseline.json is not in rendered form; it is generated, not hand-formatted"
    end

    test "every scope the scanner implements is initialized" do
      %{initialized_scopes: initialized} = CopyScan.load_baseline()

      missing =
        for scope <- CopyScan.scopes(), Atom.to_string(scope) not in initialized, do: scope

      assert missing == [],
             "scopes not initialized in the baseline: #{inspect(missing)}. Initialize once with:\n  #{CopyScan.init_command()}"
    end
  end

  describe "real scan of scope :lexicon (README + top guides)" do
    test "non-vacuous: the file list is real and the baseline has entries" do
      files = CopyScan.files_for(:lexicon)

      assert "README.md" in files
      assert "guides/introduction/contract.md" in files
      assert Enum.any?(files, &String.starts_with?(&1, "guides/flows/"))

      for file <- [
            "guides/introduction/first-hour.md",
            "guides/introduction/getting-started.md",
            "guides/introduction/installation.md"
          ] do
        assert file in files, "primary guide missing from the lexicon source list: #{file}"
      end

      %{entries: entries} = CopyScan.load_baseline()
      assert Enum.count(entries, &(&1.scope == "lexicon")) >= 1
    end

    test "hits equal the committed baseline exactly (no new, no stale)" do
      assert_scope_matches_baseline(:lexicon)
    end
  end

  describe "real scan of scope :admin (admin chrome and admin templates)" do
    test "hits equal the committed baseline exactly (no new, no stale)" do
      assert_scope_matches_baseline(:admin)
    end
  end

  describe "real scan of scope :generated (installer templates)" do
    test "hits equal the committed baseline exactly (no new, no stale)" do
      assert_scope_matches_baseline(:generated)
    end

    test "identifiers and routes are never baselined" do
      %{entries: entries} = CopyScan.load_baseline()

      offenders =
        Enum.filter(entries, fn entry ->
          String.contains?(entry.line, ["log_in_user", "/users/log_in", "[:sigra", "login_form"])
        end)

      assert offenders == []
    end
  end

  defp assert_scope_matches_baseline(scope) do
    name = Atom.to_string(scope)
    %{entries: entries} = CopyScan.load_baseline()
    baselined = Enum.filter(entries, &(&1.scope == name))

    [new: new, stale: stale] = CopyScan.diff_baseline(CopyScan.scan(scope), baselined)

    new_report =
      Enum.map_join(new, "\n", fn hit ->
        "new banned term in #{hit.file}: #{hit.line} - fix the copy, do not baseline new violations"
      end)

    stale_report =
      Enum.map_join(stale, "\n", fn entry ->
        "baseline entry no longer matches any hit - remove this entry (shrink-only): " <>
          "#{entry.scope}/#{entry.kind} #{entry.file}: #{entry.line}"
      end)

    report = [new_report, stale_report] |> Enum.reject(&(&1 == "")) |> Enum.join("\n")

    assert new == [] and stale == [], report
  end
end
