defmodule Sigra.Brand.LogoContractTest do
  @moduledoc """
  BTOK-04, BTOK-07: the shipped admin lockup is the brand book's v2 lockup, and the
  shell sizes and clears it as the book requires.

  Four shipped copies (two installer templates, two example copies) sit under the
  frozen filenames `sigra-logo-primary.svg` and `sigra-logo-primary-dark.svg`. Each is
  the matching `brand/assets/logo/sigra-lockup-{light,dark}.svg` plus exactly one
  inserted `<title>sigra</title>`: strip that one string and the sha256 equals the
  book file, so the path data is the book's, never an edited copy.

  The shipped SVGs are public and every adopter's admin receives them, so a second
  group of checks keeps tool metadata, descriptions, absolute paths, live text and the
  retired suite phrases out of them.

  The shell checks read the two `admin_shell.ex` files (installer template and example)
  and the lockup rules in the template stylesheet. Every check is a pure function over
  in-memory text, so each one is shown to fire on a planted input.
  """

  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  @title "<title>sigra</title>"
  @view_box ~s(viewBox="16.0 -720.0 2305.3 935.0")

  # {shipped copy, book source}, relative to the repository root.
  @copies [
    {"priv/templates/sigra.install/admin/sigra-logo-primary.svg",
     "brand/assets/logo/sigra-lockup-light.svg"},
    {"priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg",
     "brand/assets/logo/sigra-lockup-dark.svg"},
    {"test/example/priv/static/images/sigra-logo-primary.svg",
     "brand/assets/logo/sigra-lockup-light.svg"},
    {"test/example/priv/static/images/sigra-logo-primary-dark.svg",
     "brand/assets/logo/sigra-lockup-dark.svg"}
  ]

  @shells [
    "priv/templates/sigra.install/admin/components/admin_shell.ex",
    "test/example/lib/example_web/components/admin_shell.ex"
  ]

  @template_css "priv/templates/sigra.install/admin/sigra_admin.css"
  @example_css "test/example/priv/static/assets/sigra_admin.css"
  @example_app_css "test/example/priv/static/assets/css/app.css"

  # Case-insensitive substrings no shipped logo may contain: live text, descriptions,
  # tool and font-provenance metadata. The two absolute-path prefixes are assembled from
  # parts so this guard list is not itself a hit for a home-path scan over the repository.
  @forbidden_markers [
    "<text",
    "font-family",
    "<desc",
    "<metadata",
    "generator",
    "inkscape",
    "sodipodi",
    "dc:creator",
    "opentype",
    "/" <> "Users" <> "/",
    "/" <> "home" <> "/"
  ]

  # The retired suite phrases (UI-SPEC Copywriting Contract).
  @retired_phrases ["Sigra primary logo", "Linked Rail", "Space Grotesk"]

  describe "byte parity with the brand book (BTOK-04)" do
    for {shipped, book} <- @copies do
      test "#{shipped} is #{book} plus exactly one inserted title" do
        shipped = read!(unquote(shipped))
        book = read!(unquote(book))

        assert {:ok, stripped} = strip_title(shipped)
        assert sha256(stripped) == sha256(book)
        assert byte_size(shipped) == byte_size(book) + byte_size(@title)
      end
    end

    test "the title is the first child of the root element, so the path data starts after it" do
      for {shipped, _book} <- @copies do
        assert Regex.match?(~r/\A<svg\b[^>]*><title>sigra<\/title><path\b/, read!(shipped)),
               "#{shipped}: the title must sit directly after the opening svg tag"
      end
    end

    test "the light and dark book files differ, so a swapped pair cannot pass" do
      refute sha256(read!("brand/assets/logo/sigra-lockup-light.svg")) ==
               sha256(read!("brand/assets/logo/sigra-lockup-dark.svg"))

      refute sha256(read!(elem(Enum.at(@copies, 0), 0))) ==
               sha256(read!(elem(Enum.at(@copies, 1), 0)))
    end
  end

  describe "metadata and privacy guards (T-261-07)" do
    for {shipped, _book} <- @copies do
      test "#{shipped} carries one title, the v2 viewBox, path data only and no metadata" do
        assert svg_problems(read!(unquote(shipped))) == []
      end
    end

    test "no shipped copy holds an EEx sequence the installer would evaluate" do
      for {shipped, _book} <- @copies do
        refute read!(shipped) =~ "<%", "#{shipped} contains an EEx opening sequence"
      end
    end

    test "the guard fires on a planted second title, desc, metadata, text, retired phrase and home path" do
      good = ~s(<svg #{@view_box}>#{@title}<path d="M0 0"/></svg>)
      assert svg_problems(good) == []

      assert Enum.any?(svg_problems(~s(<svg #{@view_box}>#{@title}#{@title}<path d="M0"/></svg>)))

      assert "title is not exactly one <title>sigra</title>" in svg_problems(
               ~s(<svg #{@view_box}><title>sigra</title><title>sigra</title><path d="M0"/></svg>)
             )

      assert "title is not exactly one <title>sigra</title>" in svg_problems(
               ~s(<svg #{@view_box}><title id="title">Sigra primary logo</title><path d="M0"/></svg>)
             )

      home = "/" <> "Users" <> "/someone/work/logo.svg"

      assert Enum.any?(
               svg_problems(~s(<svg #{@view_box}>#{@title}<!-- #{home} --><path d="M0"/></svg>)),
               &String.contains?(&1, "forbidden marker")
             )

      for planted <- [
            "<desc>a description</desc>",
            "<metadata></metadata>",
            ~s(<text x="0">sigra</text>),
            ~s(<g font-family="x"></g>),
            "<!-- Generator: a tool -->",
            "<!-- Linked Rail -->",
            "<!-- Space Grotesk -->"
          ] do
        assert svg_problems(~s(<svg #{@view_box}>#{@title}#{planted}<path d="M0"/></svg>)) != [],
               "the guard missed #{inspect(planted)}"
      end

      assert svg_problems(~s(<svg viewBox="20 220 2361 1000">#{@title}<path d="M0"/></svg>)) != []
      assert svg_problems(~s(<svg #{@view_box}>#{@title}</svg>)) != []
    end

    test "strip_title/1 refuses zero titles and two titles" do
      assert strip_title("<svg><path/></svg>") == {:error, 0}
      assert strip_title("<svg>#{@title}#{@title}</svg>") == {:error, 2}
      assert strip_title("<svg>#{@title}<path/></svg>") == {:ok, "<svg><path/></svg>"}
    end
  end

  describe "shell markup (BTOK-04)" do
    test "both shells size the lockup 96 by 39, keep alt empty and keep the labelled link" do
      for shell <- @shells do
        assert shell_problems(read!(shell)) == [], shell
      end
    end

    test "the template and the example render identical lockup image tags" do
      [template, example] = Enum.map(@shells, &(&1 |> read!() |> brand_imgs()))

      assert length(template) == 2
      assert template == example
    end

    test "the shell check fires on the retired dimensions, a non-empty alt and a missing label" do
      good = shell_fixture(width: "96", height: "39", alt: "")
      assert shell_problems(good) == []

      assert shell_problems(shell_fixture(width: "188", height: "54", alt: "")) != []
      assert shell_problems(shell_fixture(width: "96", height: "39", alt: "sigra")) != []

      assert shell_problems(String.replace(good, ~s(aria-label="Sigra admin overview"), "")) != []

      one_image = String.replace(good, ~r/<img.*?\/>/s, "", global: false)
      assert shell_problems(one_image) != []
    end
  end

  describe "lockup box and clearance (BTOK-04)" do
    test "the lockup box is 6rem by 2.5rem, never shrinks, carries no translateY, and the gap is 16px" do
      for path <- [@template_css, @example_css] do
        css = read!(path)

        assert lockup_css_problems(css) == [], path
        assert_declares(css, ".sg-brand-mark", "gap", "var(--sg-space-4)", path)
        assert_declares(css, ".sg-brand-mark__image", "object-fit", "contain", path)
        assert_declares(css, ".sg-brand-mark__image", "object-position", "left center", path)
      end
    end

    test "the example topbar is 4rem: 12px padding twice plus the 40px lockup" do
      css = read!(@example_app_css)
      bodies = rule_bodies(css, ".sg-admin-topbar-inner")

      assert bodies != [], "the rule vanished; the stylesheet may hold a stray comment"
      assert_declares(css, ".sg-admin-topbar-inner", "min-height", "4rem", @example_app_css)

      assert_declares(
        css,
        ".sg-admin-topbar-inner",
        "padding-block",
        "var(--sg-space-3)",
        @example_app_css
      )
    end

    test "the lockup check fires on the retired box and on a translateY" do
      good = """
      .sg-brand-mark__lockup { width: 6rem; height: 2.5rem; flex: 0 0 auto; }
      """

      assert lockup_css_problems(good) == []

      retired = ".sg-brand-mark__lockup { width: 5.25rem; height: 1.5rem; flex: 0 0 auto; }"
      assert length(lockup_css_problems(retired)) == 2

      assert lockup_css_problems(
               ".sg-brand-mark__lockup { width: 6rem; height: 2.5rem; flex: 0 0 auto; transform: translateY(-2px); }"
             ) != []

      assert lockup_css_problems(
               ".sg-brand-mark__lockup { width: 6rem; height: 2.5rem; flex: 1 1 auto; }"
             ) != []

      assert lockup_css_problems(".sg-other { width: 6rem; }") == [
               "no .sg-brand-mark__lockup rule"
             ]
    end

    test "the rule reader matches a whole selector, skips comments and sees through @layer and @media" do
      css = """
      /* .sg-brand-mark__lockup { width: 1rem } */
      @layer sg-components {
        @media (min-width: 40rem) {
          .sg-brand-mark { gap: 1rem; }
        }
        .sg-brand-mark__lockup { width: 6rem; }
        html .sg-brand-mark__lockup { width: 9rem; }
      }
      """

      assert rule_bodies(css, ".sg-brand-mark") |> Enum.flat_map(&declarations/1) ==
               [{"gap", "1rem"}]

      assert rule_bodies(css, ".sg-brand-mark__lockup") |> Enum.flat_map(&declarations/1) ==
               [{"width", "6rem"}]

      assert rule_bodies(css, ".sg-absent") == []
    end
  end

  # ---------------------------------------------------------------- SVG checks

  defp read!(relative), do: @root |> Path.join(relative) |> File.read!()

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  # Remove the one inserted title. Anything other than exactly one is an error.
  defp strip_title(svg) do
    case String.split(svg, @title) do
      [before, rest] -> {:ok, before <> rest}
      parts -> {:error, length(parts) - 1}
    end
  end

  defp svg_problems(svg) do
    lowered = String.downcase(svg)

    title_problems =
      case Regex.scan(~r/<title\b[^>]*>.*?<\/title>/s, svg) do
        [[@title]] -> []
        _ -> ["title is not exactly one <title>sigra</title>"]
      end

    view_box_problems = if String.contains?(svg, @view_box), do: [], else: ["viewBox is not v2"]
    path_problems = if String.contains?(svg, "<path"), do: [], else: ["no <path> data"]

    marker_problems =
      for marker <- @forbidden_markers,
          String.contains?(lowered, String.downcase(marker)),
          do: "forbidden marker #{inspect(marker)}"

    phrase_problems =
      for phrase <- @retired_phrases,
          String.contains?(lowered, String.downcase(phrase)),
          do: "retired phrase #{inspect(phrase)}"

    title_problems ++ view_box_problems ++ path_problems ++ marker_problems ++ phrase_problems
  end

  # ---------------------------------------------------------------- shell checks

  defp shell_problems(source) do
    imgs = brand_imgs(source)

    label =
      if String.contains?(source, ~s(aria-label="Sigra admin overview")),
        do: [],
        else: ["the brand-mark link lost aria-label=\"Sigra admin overview\""]

    count =
      if length(imgs) == 2, do: [], else: ["expected 2 lockup images, found #{length(imgs)}"]

    per_image =
      for img <- imgs,
          {name, expected} <- [{"width", "96"}, {"height", "39"}, {"alt", ""}],
          attribute(img, name) != expected,
          do: "#{name} is #{inspect(attribute(img, name))}, expected #{inspect(expected)}"

    label ++ count ++ per_image
  end

  # The two lockup <img> tags, whitespace-collapsed.
  defp brand_imgs(source) do
    ~r/<img\b[^>]*?\/>/s
    |> Regex.scan(source)
    |> List.flatten()
    |> Enum.filter(&String.contains?(&1, "sg-brand-mark__image"))
    |> Enum.map(&collapse/1)
  end

  defp attribute(tag, name) do
    case Regex.run(~r/\s#{name}="([^"]*)"/, tag, capture: :all_but_first) do
      [value] -> value
      _ -> nil
    end
  end

  defp shell_fixture(opts) do
    image = fn variant ->
      """
      <img class="sg-brand-mark__image sg-brand-mark__image--#{variant}"
        src={~p"/images/sigra-logo-primary.svg"}
        alt="#{opts[:alt]}" width="#{opts[:width]}" height="#{opts[:height]}" decoding="async" />
      """
    end

    """
    <.admin_link class="sg-brand-mark" aria-label="Sigra admin overview">
      #{image.("light")}
      #{image.("dark")}
    </.admin_link>
    """
  end

  # ---------------------------------------------------------------- CSS checks

  defp lockup_css_problems(css) do
    case rule_bodies(css, ".sg-brand-mark__lockup") do
      [] ->
        ["no .sg-brand-mark__lockup rule"]

      bodies ->
        declared = Enum.flat_map(bodies, &declarations/1)

        missing =
          for {property, value} = pair <- [
                {"width", "6rem"},
                {"height", "2.5rem"},
                {"flex", "0 0 auto"}
              ],
              pair not in declared,
              do: "#{property}: #{value} is not declared"

        shifted =
          for {"transform", value} <- declared,
              String.contains?(value, "translate"),
              do: "the lockup still declares transform: #{value}"

        missing ++ shifted
    end
  end

  defp strip_comments(css), do: Regex.replace(~r{/\*.*?\*/}s, css, " ")

  defp collapse(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  # The declaration body of every rule whose whole selector (not a comma-list member and
  # not a suffix of a longer selector) is `selector`. Rules nest inside `@layer` and
  # `@media`, so a rule starts after `{`, `}`, `;` or the start of the file.
  defp rule_bodies(css, selector) do
    pattern = ~r/(?:\A|[{};])\s*#{Regex.escape(selector)}\s*\{([^{}]*)\}/

    pattern
    |> Regex.scan(strip_comments(css), capture: :all_but_first)
    |> List.flatten()
  end

  # `assert` over a whole stylesheet would print the stylesheet on failure; name the rule instead.
  defp assert_declares(css, selector, property, value, where) do
    assert declares?(css, selector, property, value),
           "#{where}: #{selector} must declare `#{property}: #{value}`"
  end

  defp declares?(css, selector, property, value) do
    css
    |> rule_bodies(selector)
    |> Enum.any?(&({property, value} in declarations(&1)))
  end

  defp declarations(body) do
    body
    |> String.split(";")
    |> Enum.flat_map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] -> [{collapse(property), collapse(value)}]
        _ -> []
      end
    end)
  end
end
