defmodule Sigra.Brand.LegacyProfilesTest do
  @moduledoc """
  Byte-identity guard for hosts that configured only a `Sigra.Branding.Profile`
  (BPOL-03).

  Three profile shapes are rendered through the public `Sigra.Branding`
  functions and compared with `==` against outputs committed in
  `test/fixtures/brand/legacy-profiles.json`:

    * `explicit` sets every color, both logos and every other profile field,
    * `partial` sets only `product_name` and `accent_color`,
    * `defaults` is `Profile.default()`.

  The expected values were generated once from the behaviour at the time the
  fixture was committed and are never recomputed here. Only pure functions are
  covered: preview HTML and admin copy are deliberately not frozen, because a
  later phase rewords the branding workbench.

  The fixture is written only through the opt-in path
  (`SIGRA_BRAND_LEGACY=write`) and only when the file does not exist yet.
  """

  use ExUnit.Case, async: true

  alias Sigra.Branding
  alias Sigra.Branding.Profile

  @root Path.expand("../../..", __DIR__)
  @fixture_path Path.join(@root, "test/fixtures/brand/legacy-profiles.json")
  @schema_version "sigra.brand-legacy-profiles/v1"
  @write_env "SIGRA_BRAND_LEGACY"
  @shapes ~w(defaults explicit partial)
  @functions ~w(color_tokens css_variables dark_accent_source email_logo logo to_map)

  # Written once, before any test reads the fixture. `setup_all` keeps the write
  # ordered ahead of the async tests; an existing file is never overwritten.
  setup_all do
    if System.get_env(@write_env) == "write" and not File.exists?(@fixture_path) do
      File.mkdir_p!(Path.dirname(@fixture_path))

      File.write!(
        @fixture_path,
        pretty(%{
          "schema_version" => @schema_version,
          "profiles" => Map.new(@shapes, fn shape -> {shape, observe(profile(shape))} end)
        })
      )
    end

    :ok
  end

  describe "committed expected outputs" do
    test "the fixture carries the schema version and exactly the three shapes" do
      fixture = read_fixture!()

      assert fixture["schema_version"] == @schema_version
      assert fixture["profiles"] |> Map.keys() |> Enum.sort() == @shapes
    end

    test "every shape commits every observed function and a non-empty CSS string" do
      for shape <- @shapes do
        expected = expected!(shape)

        assert expected |> Map.keys() |> Enum.sort() == @functions,
               "shape #{shape} does not commit exactly #{inspect(@functions)}"

        assert is_binary(expected["css_variables"]) and expected["css_variables"] != "",
               "shape #{shape} has an empty committed CSS string (vacuous green)"
      end
    end

    for shape <- @shapes, function <- @functions do
      test "#{shape}: #{function} renders identically to the committed output" do
        shape = unquote(shape)
        function = unquote(function)

        expected = expected!(shape)[function]
        actual = shape |> profile() |> observe() |> Map.fetch!(function)

        differences = diff(expected, actual)

        assert differences == [],
               """
               Legacy Branding output changed for shape #{shape}, function #{function}:

               #{format_differences(differences)}

               A host that configured only a Branding profile must see identical
               output. This fixture is never regenerated to make a change pass.
               """
      end
    end
  end

  describe "positive control" do
    test "a one-character change to a committed CSS string is detected" do
      expected = expected!("explicit")["css_variables"]
      <<_first, rest::binary>> = expected
      tampered = <<?~, rest::binary>>

      refute tampered == expected
      assert [{"", ^expected, ^tampered}] = diff(expected, tampered)
    end

    test "identical data reports no difference" do
      expected = expected!("explicit")

      assert diff(expected, expected) == []
    end

    test "a changed nested value and an added key are both reported by path" do
      expected = %{"color_tokens" => %{"light" => %{"accent_color" => "#c2410c"}}}

      changed = %{"color_tokens" => %{"light" => %{"accent_color" => "#c2410d"}}}
      added = %{"color_tokens" => %{"light" => %{"accent_color" => "#c2410c", "x" => "y"}}}

      assert diff(expected, changed) == [
               {"color_tokens.light.accent_color", "#c2410c", "#c2410d"}
             ]

      assert diff(expected, added) == [{"color_tokens.light.x", :absent, "y"}]
    end
  end

  # -- shapes ----------------------------------------------------------------

  # Light colors, dark colors, both logos and every other field are fixed values
  # so the committed output cannot depend on defaults leaking in.
  defp profile("explicit") do
    Profile.new!(
      product_name: "Acme Auth",
      logo_url: "/images/acme-logo.svg",
      logo_alt: "Acme logo",
      dark_logo_url: "/images/acme-logo-dark.svg",
      accent_color: "#0f766e",
      accent_foreground: "#ffffff",
      background_color: "#f8fafc",
      surface_color: "#ffffff",
      text_color: "#0f172a",
      muted_color: "#475569",
      border_color: "#cbd5e1",
      dark_accent_color: "#5eead4",
      dark_accent_foreground: "#042f2e",
      dark_background_color: "#08111f",
      dark_surface_color: "#0f1b2d",
      dark_text_color: "#e2e8f0",
      dark_muted_color: "#94a3b8",
      dark_border_color: "#334155",
      support_url: "https://example.test/support",
      privacy_url: "https://example.test/privacy",
      terms_url: "https://example.test/terms",
      email_from_name: "Acme Auth",
      email_from_address: "auth@example.test",
      email_reply_to: "help@example.test",
      theme: :dark
    )
  end

  defp profile("partial"), do: Profile.new!(product_name: "Acme Auth", accent_color: "#0f766e")
  defp profile("defaults"), do: Profile.default()

  # -- observation -----------------------------------------------------------

  # Every function whose output is frozen, converted to JSON-safe data.
  defp observe(%Profile{} = profile) do
    json_safe(%{
      "css_variables" => Branding.css_variables(profile),
      "color_tokens" => %{
        "light" => Branding.color_tokens(profile, :light),
        "dark" => Branding.color_tokens(profile, :dark)
      },
      "logo" => %{
        "light" => Branding.logo(profile, :light),
        "dark" => Branding.logo(profile, :dark)
      },
      "email_logo" => Branding.email_logo(profile),
      "dark_accent_source" => Branding.dark_accent_source(profile),
      "to_map" => Profile.to_map(profile)
    })
  end

  # Documented conversion to JSON-safe data: atom keys become strings, atom
  # values become their name (nil and booleans stay as-is), tuples become
  # two-or-more element lists, and strings (including the CSS output) are kept
  # verbatim so equality is byte equality.
  defp json_safe(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} -> {to_string(key), json_safe(value)} end)
  end

  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> json_safe()
  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(nil), do: nil
  defp json_safe(boolean) when is_boolean(boolean), do: boolean
  defp json_safe(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp json_safe(other), do: other

  # -- comparison (pure) -----------------------------------------------------

  # Returns [{path, expected, actual}] for every leaf that differs; [] when the
  # two values are identical. A key present on one side only is reported with
  # `:absent` standing in for the missing value.
  defp diff(expected, actual), do: walk(expected, actual, [])

  defp walk(%{} = expected, %{} = actual, path) do
    (Map.keys(expected) ++ Map.keys(actual))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn key ->
      walk(Map.get(expected, key, :absent), Map.get(actual, key, :absent), path ++ [key])
    end)
  end

  defp walk(expected, actual, path) when is_list(expected) and is_list(actual) do
    if length(expected) == length(actual) do
      expected
      |> Enum.zip(actual)
      |> Enum.with_index()
      |> Enum.flat_map(fn {{e, a}, index} -> walk(e, a, path ++ [Integer.to_string(index)]) end)
    else
      [{Enum.join(path, "."), expected, actual}]
    end
  end

  defp walk(same, same, _path), do: []
  defp walk(expected, actual, path), do: [{Enum.join(path, "."), expected, actual}]

  defp format_differences(differences) do
    Enum.map_join(differences, "\n", fn {path, expected, actual} ->
      "  #{path}\n    expected: #{inspect(expected)}\n    actual:   #{inspect(actual)}"
    end)
  end

  # -- fixture I/O -----------------------------------------------------------

  defp read_fixture! do
    unless File.regular?(@fixture_path) do
      flunk("""
      Legacy profile fixture is missing: #{Path.relative_to(@fixture_path, @root)}

      Write it once from current behaviour (it is never overwritten) with:

        SIGRA_BRAND_LEGACY=write mix test test/sigra/brand/legacy_profiles_test.exs
      """)
    end

    @fixture_path |> File.read!() |> JSON.decode!()
  end

  defp expected!(shape) do
    case get_in(read_fixture!(), ["profiles", shape]) do
      %{} = expected -> expected
      _ -> flunk("fixture has no profile shape #{shape}")
    end
  end

  # -- serialization ---------------------------------------------------------
  #
  # The stdlib JSON module only emits compact single-line JSON. This small recipe
  # (the same one the frozen-surface baseline uses) emits sorted object keys,
  # two-space indent, one object key per line as `"key": value`, one array
  # element per line and scalar leaves via JSON.encode!/1.

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
