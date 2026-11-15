defmodule Sigra.Brand.CatalogTest do
  @moduledoc """
  BGEN-03 harness checks for the before/after text catalog of rendered output.

  The catalog is a set of normalized, human-reviewable text files: pure renders of
  the eight library admin LiveViews (tier 1), plus the raw tier-2 and generated-host
  dumps that other plans produce. Phase 262 diffs "after" against a committed
  "before" taken while shipped `lib/` and `priv/` were still identical to main.

  What this module protects:

    * the normalizer removes every per-render volatile (csrf tokens, phx ids,
      UUIDs, wall-clock relative text) and never rewrites an absolute timestamp,
      which is pinned at the source instead,
    * rendering the same tier-1 state twice yields byte-identical normalized text,
    * the committed "before" is protected by hash and by refuse-to-overwrite, never
      by equality with current sources (that comparison would go red in Phase 261
      by design),
    * a privacy scan over the catalog text, proven by planted leaks.

  The writer is opt-in. `SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs`
  writes the "after" catalog into the gitignored `tmp/catalog-after/`; the `before`
  value writes the committed baseline exactly once. Both go through
  `Sigra.Test.Brand.RegenGuard`, so they are refused when `CI` is `true`.

  Red-ness is proven only by the in-memory controls below. Never mutate a real
  committed catalog file to show that a guard can fail.
  """

  use ExUnit.Case, async: true

  alias Sigra.Admin.Live.UserShowLive
  alias Sigra.Test.Brand.Catalog

  @root Path.expand("../../..", __DIR__)

  # Written before any test reads the output. `setup_all` keeps the opt-in write
  # ordered ahead of the async tests; without the variable it does nothing.
  setup_all do
    Catalog.write_if_requested!()
  end

  describe "normalize/2" do
    test "csrf token inputs and meta tags lose their values" do
      html =
        ~s(<input type="hidden" name="_csrf_token" value="AbC123-secret-token"/>) <>
          ~s(<meta name="csrf-token" content="XyZ987-meta-token"/>)

      out = Catalog.normalize(html)

      refute out =~ "AbC123-secret-token"
      refute out =~ "XyZ987-meta-token"
      assert out =~ ~s(value="{{CSRF}}")
      assert out =~ ~s(content="{{CSRF}}")
    end

    test "phx request ids and the session and static signed values are replaced" do
      html =
        ~s(<div id="phx-F9abc_Def12" data-phx-session="SFMyNTY.signed.session" ) <>
          ~s(data-phx-static="SFMyNTY.signed.static"></div>)

      out = Catalog.normalize(html)

      refute out =~ "F9abc_Def12"
      refute out =~ "signed.session"
      refute out =~ "signed.static"
      assert out =~ ~s(id="phx-{{REQUEST_ID}}")
      assert out =~ ~s(data-phx-session="{{PHX_SESSION}}")
      assert out =~ ~s(data-phx-static="{{PHX_STATIC}}")
    end

    test "the asset vsn query and per-render ids lose their volatile part" do
      html =
        ~s(<link rel="stylesheet" href="/assets/sigra_admin.css?vsn=d"/>) <>
          ~s(<h2 id="mg-11-confirm-title-42">Revoke</h2>)

      out = Catalog.normalize(html)

      assert out =~ "/assets/sigra_admin.css?vsn={{VSN}}"
      assert out =~ ~s(id="mg-11-confirm-title-{{N}}")
      refute out =~ "confirm-title-42"
    end

    test "every UUID becomes a placeholder and personas get their label" do
      persona = "11111111-2222-4333-8444-555555555555"
      other = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
      html = ~s(<a href="/admin/users/#{persona}">#{persona}</a><code>#{other}</code>)

      out = Catalog.normalize(html, personas: %{persona => "locked"})

      assert out =~ ~s(href="/admin/users/{{PERSONA:locked}}")
      assert out =~ "<code>\n{{UUID}}\n</code>"
      refute out =~ persona
      refute out =~ other
    end

    test "wall-clock relative text is replaced and absolute timestamps are kept" do
      html =
        "<p>just now</p><p>5m ago</p><p>3h ago</p><p>304d ago</p>" <>
          "<p>2026-01-02 03:04</p><p>2026-05-14 08:12:00</p>"

      out = Catalog.normalize(html)

      refute out =~ "just now"
      refute out =~ ~r/\d+[mhd] ago/
      assert length(String.split(out, "{{RELATIVE}}")) == 5
      assert out =~ "2026-01-02 03:04"
      assert out =~ "2026-05-14 08:12:00"
    end

    test "whitespace runs collapse and every tag sits on its own line" do
      out = Catalog.normalize("<div>\n   <p>a   b</p>\n</div>")

      assert out == "<div>\n<p>\na b\n</p>\n</div>\n"
    end

    test "planted controls: a csrf value, a UUID and 304d ago are all gone, an absolute stamp stays" do
      leaky =
        ~s(<input name="_csrf_token" value="PLANTED-csrf-value"/>) <>
          "<code>9f8e7d6c-5b4a-4321-8fed-cba987654321</code><span>304d ago</span>"

      out = Catalog.normalize(leaky)

      refute out =~ "PLANTED-csrf-value"
      refute out =~ "9f8e7d6c-5b4a-4321-8fed-cba987654321"
      refute out =~ "304d ago"

      assert Catalog.normalize("<td>2026-01-02 03:04</td>") =~ "2026-01-02 03:04"
    end
  end

  describe "tier 1 tracer: UserShowLive locked state" do
    test "two renders of the same literal state normalize to identical bytes" do
      first = Catalog.tier1_html({UserShowLive, :locked})
      second = Catalog.tier1_html({UserShowLive, :locked})

      assert first != ""
      assert first == second
    end

    test "the baseline is non-vacuous: it carries the verbatim locked guidance and the raw render was volatile" do
      raw = Catalog.tier1_raw({UserShowLive, :locked})
      normalized = Catalog.tier1_html({UserShowLive, :locked})

      assert normalized =~ "revoke active sessions and unlock below."
      assert normalized =~ "Locked"

      # The raw render really did carry the volatiles the normalizer is claimed to remove.
      assert raw =~ ~r/name="_csrf_token" value="[^"]{8,}"/
      assert raw =~ ~r/\d+d ago/
      assert normalized =~ "{{CSRF}}"
      assert normalized =~ "{{RELATIVE}}"
    end
  end

  describe "write!/2 in after mode" do
    test "writes the tier-1 files under tier1-library-admin/ of the output directory" do
      out = tmp_dir()

      result =
        Catalog.write!(:after, env: %{"SIGRA_BRAND_CATALOG" => "after"}, out_dir: out)

      path = "tier1-library-admin/user_show_live--locked.html"

      assert path in result.files
      assert File.read!(Path.join(out, path)) == Catalog.tier1_html({UserShowLive, :locked})
    end

    test "the default output directory is the gitignored tmp/catalog-after" do
      assert Catalog.out_dir(:after) == Path.join(@root, "tmp/catalog-after")
    end

    test "is refused, and writes nothing, when CI=true is planted in the injected env" do
      out = Path.join(tmp_dir(), "never-written")

      assert_raise RuntimeError, ~r/SIGRA_BRAND_CATALOG=after.*refused when CI is set/s, fn ->
        Catalog.write!(:after,
          env: %{"SIGRA_BRAND_CATALOG" => "after", "CI" => "true"},
          out_dir: out
        )
      end

      refute File.exists?(out)
    end

    test "is refused when the environment does not request this mode" do
      out = Path.join(tmp_dir(), "never-written")

      assert_raise ArgumentError, ~r/SIGRA_BRAND_CATALOG=after/, fn ->
        Catalog.write!(:after, env: %{}, out_dir: out)
      end

      refute File.exists?(out)
    end
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "sigra_catalog_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
