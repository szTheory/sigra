defmodule ExampleWeb.Admin.DesignGalleryCatalogTest do
  @moduledoc """
  Pure-render proof for the `catalog-*` section of the dev-only design gallery
  (BGEN-08).

  `/admin/_design` is gated by `Application.compile_env(:example, :dev_routes)`,
  which only `config/dev.exs` sets, so `live(conn, "/admin/_design")` would 404
  in the test environment. The LiveView's `render/1` is a pure function of
  literal assigns (moduledoc contract: no DB, no query imports), so it is called
  directly and the result is parsed with `LazyHTML`.

  What this protects:

    * the nine `catalog-*` cards exist (auth-page, email and status-word states)
    * the status cards draw their word with the existing `sg-status-pill`, and
      `Suspended` appears only inside `catalog-status-suspended` (ADR 005
      decision 6: a catalog-only state, never a product state)
    * no `catalog-*` id is in the Playwright `COMPONENT_BOARDS`, `GROUP_BOARDS`
      or `CONFIG_BOARDS` arrays, and the arrays keep their lengths (13, 11, 4),
      so no PNG baseline or registry moves
    * the section carries no non-`.test` address and no home-directory path.
      The two path prefixes are built from fragments, so no such literal exists
      in this file; planted controls show both scans can fail.
  """

  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  @moduletag :example_app

  @spec_path Path.expand("../../../priv/playwright/tests/admin-design.spec.ts", __DIR__)

  @catalog_ids ~w(
    catalog-auth-login
    catalog-auth-error
    catalog-email-confirmation
    catalog-email-reset
    catalog-status-active
    catalog-status-unconfirmed
    catalog-status-locked
    catalog-status-deletion-scheduled
    catalog-status-suspended
  )

  @status_words %{
    "catalog-status-active" => "Active",
    "catalog-status-unconfirmed" => "Unconfirmed",
    "catalog-status-locked" => "Locked",
    "catalog-status-deletion-scheduled" => "Deletion scheduled",
    "catalog-status-suspended" => "Suspended"
  }

  @slash "/"
  @users_dir @slash <> "Users" <> @slash
  @home_dir @slash <> "home" <> @slash

  setup_all do
    html = rendered_to_string(ExampleWeb.Admin.DesignGalleryLive.render(%{__changed__: nil}))
    %{html: html, doc: LazyHTML.from_fragment(html)}
  end

  defp card(doc, id), do: LazyHTML.query(doc, "##{id}")

  defp text(nodes), do: nodes |> LazyHTML.text() |> String.replace(~r/\s+/, " ") |> String.trim()

  defp occurrences(text, word), do: length(String.split(text, word)) - 1

  defp catalog_section(doc), do: card(doc, "catalog-states")

  # Domains of every address-shaped string; a sentence-final period is not part of the domain.
  defp address_domains(text) do
    ~r/[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+)/
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim_trailing(&1, "."))
  end

  defp non_test_domains(text),
    do: Enum.reject(address_domains(text), &String.ends_with?(&1, ".test"))

  defp home_path?(text),
    do: String.contains?(text, @users_dir) or String.contains?(text, @home_dir)

  defp board_array(spec, name) do
    [_, body] = Regex.run(~r/const #{name} = \[(.*?)\]/s, spec)
    {body, Regex.scan(~r/'([^']+)'/, body, capture: :all_but_first) |> List.flatten()}
  end

  describe "the nine catalog cards" do
    test "each id is present exactly once", %{doc: doc} do
      for id <- @catalog_ids do
        assert doc |> card(id) |> Enum.count() == 1,
               "expected exactly one element with id=#{id} in the rendered gallery"
      end
    end

    test "the section sits before the autofix fixture, which stays last", %{html: html} do
      {catalog_at, _} = :binary.match(html, ~s(id="catalog-states"))
      {autofix_at, _} = :binary.match(html, ~s(id="board-autofix-seed"))

      assert catalog_at < autofix_at
      assert length(String.split(html, ~s(id="board-autofix-seed"))) == 2
    end

    test "the auth-page cards draw the neutral login default", %{doc: doc} do
      login = card(doc, "catalog-auth-login")
      login_text = text(login)

      assert login_text =~ "Sign in"
      assert login_text =~ "Email"
      assert login_text =~ "Password"
      assert login |> LazyHTML.query("input[type=email]") |> Enum.count() >= 1
      assert login |> LazyHTML.query("input[type=password]") |> Enum.count() == 1
      assert login |> LazyHTML.query("button") |> Enum.count() >= 1
      assert login |> LazyHTML.query(".sigra-auth") |> Enum.count() >= 1

      error = card(doc, "catalog-auth-error")
      assert error |> LazyHTML.query("[role=alert]") |> Enum.count() == 1
      assert error |> LazyHTML.query(".sigra-auth-status--danger") |> Enum.count() == 1
    end

    test "the email cards are static preview frames addressed to a .test address", %{doc: doc} do
      for id <- ["catalog-email-confirmation", "catalog-email-reset"] do
        email = card(doc, id)
        email_text = text(email)

        assert email_text =~ "Subject:"
        assert email_text =~ "catalog-user@example.test"
        assert email |> LazyHTML.query(".sigra-auth-email-preview") |> Enum.count() == 1
      end

      assert doc |> card("catalog-email-confirmation") |> text() =~ "Confirm your email"
      assert doc |> card("catalog-email-reset") |> text() =~ "Reset your password"
    end

    test "the section is inert: no form action and no LiveView binding", %{html: html, doc: doc} do
      section = doc |> catalog_section() |> LazyHTML.to_html()

      assert section =~ ~s(id="catalog-states")
      refute section =~ "<form"
      refute section =~ " action="
      refute section =~ "phx-"
      assert html =~ "Catalog states"
    end
  end

  describe "status words" do
    test "each card draws its word with the existing sg-status-pill", %{doc: doc} do
      for {id, word} <- @status_words do
        pills = doc |> card(id) |> LazyHTML.query(".sg-status-pill")

        assert Enum.count(pills) == 1, "#{id} must hold exactly one sg-status-pill"
        assert text(pills) == word, "#{id} must draw the word #{inspect(word)}"
      end
    end

    test "the four product states use tones the product already uses", %{doc: doc} do
      tones = %{
        "catalog-status-active" => "ok",
        "catalog-status-unconfirmed" => "warn",
        "catalog-status-locked" => "risk",
        "catalog-status-deletion-scheduled" => "warn"
      }

      for {id, tone} <- tones do
        [pill] = doc |> card(id) |> LazyHTML.query(".sg-status-pill") |> Enum.to_list()
        assert LazyHTML.attribute(pill, "data-tone") == [tone], "#{id} tone"
      end
    end

    test "Suspended appears only inside catalog-status-suspended", %{doc: doc} do
      suspended = doc |> card("catalog-status-suspended") |> text()
      assert suspended =~ "Suspended"
      assert suspended =~ "Catalog only, not a product state"

      for id <- @catalog_ids -- ["catalog-status-suspended"] do
        refute doc |> card(id) |> text() =~ "Suspended", "#{id} must not mention Suspended"
      end

      assert occurrences(text(doc), "Suspended") == occurrences(suspended, "Suspended"),
             "Suspended occurs outside its own catalog card"
    end

    test "the four product words occur only in their own status cards", %{doc: doc} do
      for {id, word} <- Map.delete(@status_words, "catalog-status-suspended") do
        for other <- Map.keys(@status_words) -- [id] do
          refute doc |> card(other) |> text() =~ word,
                 "#{other} must not contain the word of #{id}"
        end
      end
    end
  end

  describe "board registries" do
    setup do
      %{spec: File.read!(@spec_path)}
    end

    test "no catalog id is in COMPONENT_BOARDS, GROUP_BOARDS or CONFIG_BOARDS", %{spec: spec} do
      for name <- ["COMPONENT_BOARDS", "GROUP_BOARDS", "CONFIG_BOARDS"] do
        {body, entries} = board_array(spec, name)

        refute body =~ "catalog-", "#{name} must not list a catalog id"
        assert entries != [], "#{name} parsed empty: the extraction drifted (vacuous green)"
        assert Enum.all?(entries, &String.starts_with?(&1, "board-"))
      end
    end

    test "the three arrays keep their lengths (13, 11, 4)", %{spec: spec} do
      lengths =
        for name <- ["COMPONENT_BOARDS", "GROUP_BOARDS", "CONFIG_BOARDS"] do
          {_body, entries} = board_array(spec, name)
          length(entries)
        end

      assert lengths == [13, 11, 4]
    end

    test "the catalog ids are not board ids", %{html: html} do
      refute html =~ ~r/id="board-catalog/
      assert Enum.all?(@catalog_ids, &(not String.starts_with?(&1, "board-")))
    end
  end

  describe "privacy" do
    test "the catalog section carries only .test addresses and no home path", %{doc: doc} do
      section_html = doc |> catalog_section() |> LazyHTML.to_html()
      section_text = text(catalog_section(doc))

      domains = address_domains(section_html <> " " <> section_text)

      assert domains != [], "no address found in the section: the scan would be vacuous"
      assert non_test_domains(section_html <> " " <> section_text) == []
      refute home_path?(section_html)
    end

    test "positive control: the same scans do fail on planted input" do
      planted = "mail alice@example.com and bob@demo.tasklane.test."

      assert non_test_domains(planted) == ["example.com"]
      assert address_domains(planted) == ["example.com", "demo.tasklane.test"]
      assert home_path?("see " <> @users_dir <> "someone/project")
      assert home_path?("see " <> @home_dir <> "someone/project")
      refute home_path?("see " <> @slash <> "var" <> @slash <> "tmp")
    end
  end
end
