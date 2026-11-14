defmodule Sigra.Brand.FrozenSurfaceTest do
  @moduledoc """
  Add-only ratchet over the names a host application may already depend on
  (BPOL-03).

  A committed baseline (`test/fixtures/brand/frozen-surface.json`) lists, per
  category, the frozen names measured from their sources of truth. The ratchet
  asserts `baseline SUBSET-OF current` for every category: additions pass
  silently, a removal fails naming the category and the removed name.

  The baseline can only grow. The opt-in extension path writes the union of the
  committed baseline and the current extraction after passing it through
  `extend_only/2`, which refuses a proposal that would drop any committed name.
  Nothing here evaluates repo content: extraction is regex or
  `Code.string_to_quoted/1`, and fixtures are read with `JSON.decode!/1`.
  """

  use ExUnit.Case, async: true

  alias Sigra.Branding
  alias Sigra.Branding.Profile
  alias Sigra.Install.Features.Admin
  alias Sigra.Install.Features.Core

  @root Path.expand("../../..", __DIR__)
  @baseline_path Path.join(@root, "test/fixtures/brand/frozen-surface.json")
  @schema_version "sigra.brand-frozen-surface/v1"
  @extend_env "SIGRA_BRAND_BASELINE"
  @extend_command "SIGRA_BRAND_BASELINE=extend mix test test/sigra/brand/frozen_surface_test.exs"

  @admin_css "priv/templates/sigra.install/admin/sigra_admin.css"
  @auth_css "priv/templates/sigra.install/core/sigra_auth.css"
  @config_source "lib/sigra/config.ex"
  @router_glob "test/fixtures/install_golden/tree/lib/*_web/router.ex"

  # Roots scanned for markup, helpers and test ids. Directories are walked with
  # a wildcard; binaries (svg, png) and non-UTF-8 files are skipped.
  @admin_markup_roots ["lib/sigra/admin/**/*", "priv/templates/sigra.install/admin/**/*"]
  @template_roots ["priv/templates/sigra.install/**/*"]
  @testid_roots ["lib/sigra/**/*", "priv/templates/sigra.install/**/*"]

  # Categories this module knows how to extract. The committed baseline must
  # carry exactly these keys; a baseline key without an extractor (or an
  # extractor without a baseline key) fails loudly instead of skipping a check.
  @categories ~w(
    config_option_paths
    css_classes_sg
    css_classes_sigra_auth
    css_custom_properties_sg
    css_custom_properties_sigra_auth
    data_testids
    gettext_domains
    installer_targets
    profile_defaults
    routes
    verified_route_helpers
  )

  # Written once through the opt-in path, before any test reads the baseline.
  # Running in `setup_all` (not in a test) keeps the write ordered ahead of the
  # async tests that read the file.
  setup_all do
    if System.get_env(@extend_env) == "extend", do: extend_baseline!()
    :ok
  end

  describe "comparator (pure)" do
    test "a removal is reported by name" do
      baseline = ["--sg-a", "--sg-b", "--sg-c"]
      current = ["--sg-a", "--sg-c"]

      assert missing(baseline, current) == ["--sg-b"]
    end

    test "an addition stays green" do
      baseline = ["--sg-a", "--sg-b"]
      current = ["--sg-a", "--sg-b", "--sg-new"]

      assert missing(baseline, current) == []
    end

    test "identical sets and an empty baseline report nothing" do
      assert missing(["x"], ["x"]) == []
      assert missing([], ["x"]) == []
    end

    test "several removals come back sorted and distinct" do
      assert missing(["c", "a", "b", "a"], ["b"]) == ["a", "c"]
    end
  end

  describe "extend-only guard (pure)" do
    test "accepts a proposal that is a superset of the committed baseline" do
      committed = %{"cat" => ["a", "b"]}
      proposed = %{"cat" => ["a", "b", "c"], "new_cat" => ["z"]}

      assert extend_only(committed, proposed) == :ok
    end

    test "accepts an identical proposal" do
      committed = %{"cat" => ["a", "b"]}

      assert extend_only(committed, committed) == :ok
    end

    test "refuses a proposal that drops a committed name" do
      committed = %{"cat" => ["a", "b"]}
      proposed = %{"cat" => ["a"]}

      assert extend_only(committed, proposed) == {:error, [{"cat", "b"}]}
    end

    test "refuses a proposal that drops a whole category" do
      committed = %{"cat" => ["a"], "other" => ["x", "y"]}
      proposed = %{"cat" => ["a"]}

      assert extend_only(committed, proposed) == {:error, [{"other", "x"}, {"other", "y"}]}
    end

    test "union never shrinks and is what the extension path would write" do
      committed = %{"cat" => ["a", "b"], "kept" => ["k"]}
      current = %{"cat" => ["b", "c"]}

      merged = union(committed, current)

      assert merged == %{"cat" => ["a", "b", "c"], "kept" => ["k"]}
      assert extend_only(committed, merged) == :ok
    end

    test "pretty/1 keeps every array element on its own line" do
      out = pretty(%{"schema_version" => "v", "categories" => %{"c" => ["a", "b"]}})

      assert out ==
               """
               {
                 "categories": {
                   "c": [
                     "a",
                     "b"
                   ]
                 },
                 "schema_version": "v"
               }
               """
    end
  end

  describe "extractors (planted text)" do
    test "class extraction keeps class names and drops interpolation fragments" do
      text =
        ~S|<div class="sg-card sg-card--x other" data-x="sg-not-a-class" class={["sg-metric-#{kind}", @class]}>|

      assert markup_classes(text, "sg-") == ["sg-card", "sg-card--x"]
    end

    test "selector extraction drops the leading dot and ignores custom properties" do
      css = ".sg-btn { color: var(--sg-color-ink); } .sg-btn--ghost:hover { }"

      assert css_selectors(css, "sg-") == ["sg-btn", "sg-btn--ghost"]
    end

    test "route extraction trims, normalizes the app alias and keeps only route DSL lines" do
      text = """
      defmodule DemoAppWeb.Router do
        scope "/users", DemoAppWeb do
          # live "/commented", Nope
          live "/mfa", MFAChallengeLive
          post "/x", DemoAppWeb.Admin.XController, :create
          pipe_through :browser
        end
      end
      """

      assert route_lines(text) == [
               ~s(live "/mfa", MFAChallengeLive),
               ~s(post "/x", HostWeb.Admin.XController, :create),
               ~s(scope "/users", HostWeb do)
             ]
    end

    test "test id extraction covers attribute, argument and quoted-prefix forms" do
      line =
        ~s|<p data-testid="plain" data-testid={if @a, do: "admin-x", else: @y} login_testid="other-y">|

      assert testids(line) |> Enum.sort() == ["admin-x", "other-y", "plain"]
      assert testids(~s|<p class="admin-not-an-id">|) == []
    end

    test "config option paths come from the parsed AST and are never evaluated" do
      source = """
      @schema [
        a: [type: :keyword_list, default: System.halt(1), keys: [b: [type: :atom], c: [keys: [d: []]]]],
        e: [type: :pos_integer, default: 90 * 24 * 60 * 60]
      ]
      """

      {:ok, ast} = Code.string_to_quoted(source)

      assert ast |> schema_keyword() |> option_paths([]) |> Enum.sort() ==
               ["a", "a.b", "a.c", "a.c.d", "e"]
    end
  end

  describe "ratchet" do
    test "the baseline file exists, carries the schema version and the known categories" do
      baseline = read_baseline!()

      assert baseline["schema_version"] == @schema_version
      assert baseline["categories"] |> Map.keys() |> Enum.sort() == Enum.sort(@categories)
    end

    for category <- @categories do
      test "#{category}: baseline is a subset of the current surface" do
        category = unquote(category)
        baseline = baseline_names!(category)
        current = extract(category)

        removed = missing(baseline, current)

        assert removed == [], removal_message(category, removed)
      end

      test "#{category}: baseline and current surface are both non-empty" do
        category = unquote(category)

        assert baseline_names!(category) != [],
               "baseline category #{category} is empty (vacuous green)"

        assert extract(category) != [],
               "extractor for #{category} found nothing: its source path moved or the pattern drifted"
      end
    end

    test "every default value of Sigra.Branding.Profile is frozen verbatim" do
      frozen = baseline_names!("profile_defaults")

      expected = [
        accent_color: "#c2410c",
        accent_foreground: "#ffffff",
        background_color: "#f7f4ee",
        surface_color: "#ffffff",
        text_color: "#171717",
        muted_color: "#6b6258",
        border_color: "#ded8cf",
        product_name: "Your app",
        logo_alt: "Application logo",
        email_from_name: "Your app",
        theme: :system,
        logo_url: nil,
        dark_logo_url: nil,
        dark_accent_color: nil,
        dark_accent_foreground: nil,
        dark_background_color: nil,
        dark_surface_color: nil,
        dark_text_color: nil,
        dark_muted_color: nil,
        dark_border_color: nil,
        support_url: nil,
        privacy_url: nil,
        terms_url: nil,
        email_from_address: nil,
        email_reply_to: nil
      ]

      defaults = Profile.defaults()
      assert map_size(defaults) == length(expected)

      for {key, value} <- expected do
        assert Map.fetch!(defaults, key) == value,
               "Profile default #{key} changed from #{inspect(value)}"

        assert encode_default(key, value) in frozen,
               "baseline does not freeze #{encode_default(key, value)}"
      end
    end

    test "a changed default is a removal of the old string" do
      frozen = ["accent_color=\"#c2410c\""]
      changed = [encode_default(:accent_color, "#000000")]

      assert missing(frozen, changed) == ["accent_color=\"#c2410c\""]
    end
  end

  # -- extraction ------------------------------------------------------------

  defp extract("profile_defaults") do
    Profile.defaults()
    |> Enum.map(fn {key, value} -> encode_default(key, value) end)
    |> Enum.sort()
  end

  defp extract("css_custom_properties_sg") do
    @admin_css
    |> read_repo!()
    |> scan(~r/--sg-[a-z0-9-]+/)
  end

  defp extract("css_custom_properties_sigra_auth") do
    declared = @auth_css |> read_repo!() |> scan(~r/--sigra-auth-[a-z0-9-]+/)
    emitted = Profile.default() |> Branding.css_variables() |> scan(~r/--sigra-auth-[a-z0-9-]+/)

    Enum.sort(Enum.uniq(declared ++ emitted))
  end

  defp extract("css_classes_sg") do
    selectors = @admin_css |> read_repo!() |> css_selectors("sg-")
    markup = @admin_markup_roots |> repo_texts() |> Enum.flat_map(&markup_classes(&1, "sg-"))

    Enum.sort(Enum.uniq(selectors ++ markup))
  end

  defp extract("css_classes_sigra_auth") do
    selectors = @auth_css |> read_repo!() |> css_selectors("sigra-auth")
    markup = @template_roots |> repo_texts() |> Enum.flat_map(&markup_classes(&1, "sigra-auth"))

    Enum.sort(Enum.uniq(selectors ++ markup))
  end

  # Never evaluated: Code.string_to_quoted/1 only parses. The @schema attribute is
  # a keyword list of option specs; entries carrying a `keys:` list nest further.
  defp extract("config_option_paths") do
    {:ok, ast} = @config_source |> read_repo!() |> Code.string_to_quoted()

    ast
    |> schema_keyword()
    |> option_paths([])
    |> Enum.sort()
  end

  defp extract("routes") do
    path =
      case Path.wildcard(Path.join(@root, @router_glob)) do
        [single] ->
          single

        other ->
          flunk("expected exactly one golden router for #{@router_glob}, got #{inspect(other)}")
      end

    path |> File.read!() |> route_lines()
  end

  defp extract("verified_route_helpers") do
    @template_roots
    |> repo_texts()
    |> Enum.flat_map(&capture_all(&1, ~r/~p"([^"]*)"/))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Only the domain is frozen, never the msgids: ADR 005 allows targeted msgid
  # renames through a rename table.
  defp extract("gettext_domains") do
    @template_roots
    |> repo_texts()
    |> Enum.flat_map(&capture_all(&1, ~r/dgettext\(\s*"([^"]+)"/))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract("data_testids") do
    @testid_roots
    |> repo_texts()
    |> Enum.flat_map(&testids/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # The installer manifest is the source of truth for where logos and the two
  # stylesheets land in a host app. Called through the public files/1 callback;
  # template directories are never read.
  defp extract("installer_targets") do
    binding = installer_binding()

    targets =
      for module <- [Admin, Core],
          {:eex, source, target} <- module.files(binding),
          installer_asset?(target),
          uniq: true,
          do: "#{source} -> #{target}"

    Enum.sort(targets)
  end

  defp encode_default(key, value), do: "#{key}=" <> inspect(value)

  # -- extraction helpers ----------------------------------------------------

  defp scan(text, regex) do
    regex
    |> Regex.scan(text)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp capture_all(text, regex) do
    regex |> Regex.scan(text) |> Enum.map(fn [_whole, captured] -> captured end)
  end

  # `.sg-name` / `.sigra-auth-name` selectors; the leading dot is dropped so a
  # class has the same spelling in CSS and in markup.
  defp css_selectors(css, prefix) do
    capture_all(css, ~r/\.(#{Regex.escape(prefix)}[A-Za-z0-9_-]*)/)
  end

  # Class names inside `class="..."` and `class={...}` attributes. Tokens ending
  # in a hyphen are interpolation fragments (for example `sg-metric-` before a
  # `\#{...}`), not class names, and are dropped.
  defp markup_classes(text, prefix) do
    token = ~r/(?<![A-Za-z0-9_-])#{Regex.escape(prefix)}[A-Za-z0-9_-]*/

    ~r/class=(?:"([^"]*)"|\{(.*?)\})/s
    |> Regex.scan(text)
    |> Enum.flat_map(fn [_whole | groups] -> groups end)
    |> Enum.flat_map(&Regex.scan(token, &1))
    |> Enum.map(&hd/1)
    |> Enum.reject(&String.ends_with?(&1, "-"))
  end

  # Lines that mention `testid` yield: data-testid="..." values, *_testid="..."
  # argument values, and any quoted string beginning `admin-` or `mfa-` (this
  # covers `data-testid={if @active, do: "admin-auth-preview"}` forms).
  defp testids(text) do
    text
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "testid"))
    |> Enum.flat_map(fn line ->
      capture_all(line, ~r/data-testid="([^"]+)"/) ++
        capture_all(line, ~r/_testid="([^"]+)"/) ++
        capture_all(line, ~r/"((?:admin|mfa)-[^"]*)"/)
    end)
  end

  defp schema_keyword(ast) do
    {_ast, schema} =
      Macro.prewalk(ast, nil, fn
        {:@, _meta, [{:schema, _, [keyword]}]} = node, nil when is_list(keyword) ->
          {node, keyword}

        node, acc ->
          {node, acc}
      end)

    schema || flunk("no @schema keyword list found in #{@config_source}")
  end

  defp option_paths(keyword, prefix) do
    Enum.flat_map(keyword, fn
      {key, opts} when is_atom(key) and is_list(opts) ->
        path = prefix ++ [key]
        nested = if is_list(opts[:keys]), do: option_paths(opts[:keys], path), else: []
        [Enum.join(path, ".") | nested]

      _other ->
        []
    end)
  end

  # Trimmed router DSL lines (live/get/post/put/patch/delete/forward and
  # `scope "..."`) with the generated app's web module replaced by a neutral
  # token, so the baseline does not depend on the fixture's temporary app name.
  defp route_lines(text) do
    web_module =
      case Regex.run(~r/defmodule\s+([\w.]+?)\.Router\b/, text) do
        [_whole, module] -> module
        nil -> flunk("golden router has no Router module")
      end

    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&route_line?/1)
    |> Enum.map(&String.replace(&1, web_module, "HostWeb"))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp route_line?(line) do
    Regex.match?(~r/^(?:live|get|post|put|patch|delete|forward)\s/, line) or
      Regex.match?(~r/^scope\s+"/, line)
  end

  defp installer_asset?(target) do
    String.ends_with?(target, ".svg") or String.ends_with?(target, "sigra_admin.css") or
      String.ends_with?(target, "sigra_auth.css")
  end

  defp installer_binding do
    [
      otp_app: :my_app,
      app_module: "MyApp",
      app_name: "MyApp",
      web_module: "MyAppWeb",
      context_module: "MyApp.Accounts",
      context_alias: "Accounts",
      schema_module: "MyApp.Accounts.User",
      schema_alias: "User",
      table_name: "users",
      repo_module: "MyApp.Repo",
      from_email: "noreply@example.com",
      log_in_url: "/users/log_in",
      reset_password_url: "http://localhost:4000/users/reset-password",
      settings_url: "http://localhost:4000/users/settings",
      binary_id: true,
      adapter: :postgres,
      opts: [live: true, api: false, jwt: false, binary_id: true]
    ]
  end

  # -- repo reading ----------------------------------------------------------

  defp read_repo!(relative), do: @root |> Path.join(relative) |> File.read!()

  # Text of every UTF-8 regular file under the given wildcards, sorted by path.
  defp repo_texts(globs) do
    globs
    |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1), match_dot: true))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(&String.ends_with?(&1, [".svg", ".png"]))
    |> Enum.map(&File.read!/1)
    |> Enum.filter(&String.valid?/1)
  end

  # -- comparator and guard (pure) ------------------------------------------

  defp missing(baseline, current) do
    baseline
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(current))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  # Returns :ok when `proposed` contains every committed name of every committed
  # category, otherwise {:error, [{category, name}]} listing what would vanish.
  defp extend_only(committed, proposed) do
    removed =
      for {category, names} <- Enum.sort(committed),
          name <- missing(names, Map.get(proposed, category, [])),
          do: {category, name}

    if removed == [], do: :ok, else: {:error, removed}
  end

  defp union(committed, current) do
    committed
    |> Map.merge(current, fn _category, old, new -> old ++ new end)
    |> Map.new(fn {category, names} -> {category, names |> Enum.uniq() |> Enum.sort()} end)
  end

  # -- baseline I/O ----------------------------------------------------------

  defp read_baseline! do
    unless File.regular?(@baseline_path) do
      flunk("""
      Frozen-surface baseline is missing: #{Path.relative_to(@baseline_path, @root)}

      Create the initial baseline (extend-only) with:

        #{@extend_command}
      """)
    end

    @baseline_path |> File.read!() |> JSON.decode!()
  end

  defp baseline_names!(category) do
    baseline = read_baseline!()

    case get_in(baseline, ["categories", category]) do
      names when is_list(names) -> names
      _ -> flunk("baseline has no category #{category}; extend it with: #{@extend_command}")
    end
  end

  defp extend_baseline! do
    committed =
      if File.regular?(@baseline_path) do
        @baseline_path |> File.read!() |> JSON.decode!() |> Map.get("categories", %{})
      else
        %{}
      end

    current = Map.new(@categories, fn category -> {category, extract(category)} end)
    proposed = union(committed, current)

    case extend_only(committed, proposed) do
      :ok ->
        File.mkdir_p!(Path.dirname(@baseline_path))

        File.write!(
          @baseline_path,
          pretty(%{"schema_version" => @schema_version, "categories" => proposed})
        )

      {:error, removed} ->
        raise "refusing to shrink the frozen-surface baseline; would drop: #{inspect(removed)}"
    end
  end

  defp removal_message(category, removed) do
    """
    Frozen surface removed in category #{category}:

      #{Enum.join(removed, "\n  ")}

    A removal is a compatibility break; additions pass. Restore the name (the
    surface is add-only). If a new name was added on purpose, extend the
    baseline (extend-only, it can never shrink) with:

      #{@extend_command}
    """
  end

  # -- serialization ---------------------------------------------------------
  #
  # The stdlib JSON module only emits compact single-line JSON, which would turn
  # every added name into a whole-file diff. This small recipe emits sorted
  # object keys, two-space indent, one object key per line as `"key": value`,
  # one array element per line and scalar leaves via JSON.encode!/1.

  defp pretty(term), do: pretty(term, 0) <> "\n"

  defp pretty(map, _level) when is_map(map) and map_size(map) == 0, do: "{}"

  defp pretty(map, level) when is_map(map) do
    pad = String.duplicate("  ", level + 1)

    body =
      map
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join(",\n", fn {key, value} ->
        pad <> JSON.encode!(to_string(key)) <> ": " <> pretty(value, level + 1)
      end)

    "{\n" <> body <> "\n" <> String.duplicate("  ", level) <> "}"
  end

  defp pretty([], _level), do: "[]"

  defp pretty(list, level) when is_list(list) do
    pad = String.duplicate("  ", level + 1)
    body = Enum.map_join(list, ",\n", fn element -> pad <> pretty(element, level + 1) end)

    "[\n" <> body <> "\n" <> String.duplicate("  ", level) <> "]"
  end

  defp pretty(scalar, _level), do: JSON.encode!(scalar)
end
