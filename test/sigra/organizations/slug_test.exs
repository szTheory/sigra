defmodule Sigra.Organizations.SlugTest do
  use ExUnit.Case, async: true

  alias Sigra.Organizations.Slug

  # Inline test schema for changeset validation
  defmodule SlugTestSchema do
    use Ecto.Schema

    schema "test" do
      field :slug, :string
    end
  end

  defp changeset(slug) do
    Ecto.Changeset.change(%SlugTestSchema{}, %{slug: slug})
  end

  defp default_config do
    %{
      reserved_slugs: Slug.default_reserved_slugs(),
      additional_reserved_slugs: []
    }
  end

  describe "generate/1 (Phase 16 Plan 03 alias for generate_slug/1)" do
    @tag :phase16
    test "returns the same result as generate_slug/1 for a typical name" do
      assert Slug.generate("Acme Corp!") == "acme-corp"
    end

    @tag :phase16
    test "returns empty string for input that is all non-alphanumeric" do
      assert Slug.generate("!!!") == ""
    end

    @tag :phase16
    test "returns empty string for empty input" do
      assert Slug.generate("") == ""
    end

    @tag :phase16
    test "is pure: returns same slug even for a reserved name (validation is separate)" do
      assert Slug.generate("Admin") == "admin"
    end
  end

  describe "generate_slug/1" do
    test "converts name with special chars to slug" do
      assert Slug.generate_slug("Acme Corp!") == "acme-corp"
    end

    test "collapses whitespace to single hyphen" do
      assert Slug.generate_slug("  My   Org  ") == "my-org"
    end

    test "passes through simple lowercase name" do
      assert Slug.generate_slug("hello") == "hello"
    end

    test "collapses consecutive hyphens" do
      assert Slug.generate_slug("foo--bar") == "foo-bar"
    end

    test "returns nil for nil input" do
      assert Slug.generate_slug(nil) == nil
    end

    test "trims leading and trailing hyphens" do
      assert Slug.generate_slug("-leading-") == "leading"
    end

    test "converts numbers-starting name" do
      assert Slug.generate_slug("123-start") == "123-start"
    end
  end

  describe "validate_slug/2 with valid slugs" do
    test "accepts valid slug with hyphen" do
      cs = changeset("acme-corp") |> Slug.validate_slug(default_config())
      assert cs.valid?
    end

    test "accepts slug with trailing numbers" do
      cs = changeset("my-org-123") |> Slug.validate_slug(default_config())
      assert cs.valid?
    end

    test "accepts minimum length slug" do
      cs = changeset("abc") |> Slug.validate_slug(default_config())
      assert cs.valid?
    end
  end

  describe "validate_slug/2 with invalid format" do
    test "rejects uppercase letters" do
      cs = changeset("Acme") |> Slug.validate_slug(default_config())
      refute cs.valid?
    end

    test "rejects slug starting with number" do
      cs = changeset("1abc") |> Slug.validate_slug(default_config())
      refute cs.valid?
    end

    test "rejects slug shorter than 3 chars" do
      cs = changeset("ab") |> Slug.validate_slug(default_config())
      refute cs.valid?
    end

    test "rejects slug longer than 63 chars" do
      long_slug = "a" <> String.duplicate("b", 62) <> "c"
      cs = changeset(long_slug) |> Slug.validate_slug(default_config())
      refute cs.valid?
    end

    test "rejects slug with spaces" do
      cs = changeset("has space") |> Slug.validate_slug(default_config())
      refute cs.valid?
    end

    test "rejects slug with underscores" do
      cs = changeset("has_underscore") |> Slug.validate_slug(default_config())
      refute cs.valid?
    end
  end

  describe "validate_slug/2 reserved words" do
    @default_reserved ~w(
      admin api app auth billing blog cdn dashboard docs help
      login logout new oauth register settings signup static
      status support system webhooks www
    )

    for reserved <- @default_reserved do
      test "rejects reserved slug: #{reserved}" do
        cs = changeset(unquote(reserved)) |> Slug.validate_slug(default_config())
        refute cs.valid?
        assert {"is reserved and cannot be used", _} = cs.errors[:slug]
      end
    end
  end

  describe "validate_slug/2 with custom config" do
    test "rejects additional_reserved_slugs from config" do
      config = Map.put(default_config(), :additional_reserved_slugs, ["custom-reserved"])
      cs = changeset("custom-reserved") |> Slug.validate_slug(config)
      refute cs.valid?
      assert {"is reserved and cannot be used", _} = cs.errors[:slug]
    end

    test "custom slug_length rejects too-short slug" do
      config = Map.put(default_config(), :slug_length, {5, 10})
      cs = changeset("abcd") |> Slug.validate_slug(config)
      refute cs.valid?
    end

    test "custom slug_length accepts slug at minimum" do
      config = Map.put(default_config(), :slug_length, {5, 10})
      cs = changeset("abcde") |> Slug.validate_slug(config)
      assert cs.valid?
    end
  end
end
