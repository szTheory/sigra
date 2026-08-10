defmodule Sigra.Planning.Phase240AlphaOperationsRehearsalTest do
  use ExUnit.Case, async: true

  @recipe "guides/recipes/b2c-alpha.md"
  @deployment "guides/recipes/deployment.md"

  defp read!(path), do: File.read!(path)

  defp tier_section!(source, heading) do
    case Regex.run(~r/^## #{Regex.escape(heading)}\n([\s\S]*?)(?=^## |\z)/m, source) do
      [_, section] -> section
      nil -> flunk("missing exact evidence tier heading #{inspect(heading)}")
    end
  end

  defp assert_row_fields!(section, tier) do
    rows = Regex.scan(~r/^### .+?\n([\s\S]*?)(?=^### |\z)/m, section)

    assert rows != [], "#{tier} must contain structured checklist rows"

    for [_, row] <- rows, field <- ["Owner:", "Expected result:", "Must not claim:"] do
      assert String.contains?(row, field), "#{tier} checklist row is missing #{field}"
    end
  end

  test "the recipe has exactly three evidence tiers with accountable rows" do
    recipe = read!(@recipe)
    headings = ["Library CI proof", "Host pre-deploy", "Staging launch gate"]

    for heading <- headings do
      recipe |> tier_section!(heading) |> assert_row_fields!(heading)
    end

    actual =
      Regex.scan(~r/^## (?:Library CI proof|Host pre-deploy|Staging launch gate)$/m, recipe)

    assert length(actual) == 3, "the recipe must keep exactly the three D-01 evidence tiers"
  end

  test "host pre-deploy records the literal origin proxy and host-only session tuple" do
    host_pre_deploy = read!(@recipe) |> tier_section!("Host pre-deploy")

    for marker <- [
          "https://<canonical-host>",
          "Endpoint.url",
          "forwarded scheme",
          "client-IP",
          "Domain attribute: absent",
          "Secure",
          "HttpOnly",
          "SameSite=Lax",
          "clean browser"
        ] do
      assert String.contains?(host_pre_deploy, marker),
             "literal host/session tuple is missing #{inspect(marker)}"
    end
  end

  test "wiring and delivery evidence remain separate and Doctor has an honest boundary" do
    recipe = read!(@recipe)
    host_pre_deploy = tier_section!(recipe, "Host pre-deploy")
    staging = tier_section!(recipe, "Staging launch gate")

    for marker <- [
          "SECRET_KEY_BASE",
          "CLOAK_KEY",
          "GOOGLE_CLIENT_ID",
          "GOOGLE_CLIENT_SECRET",
          "mailer",
          "Vault",
          "mix sigra.doctor --quiet"
        ] do
      assert String.contains?(host_pre_deploy, marker),
             "wiring/boot evidence is missing #{inspect(marker)}"
    end

    for marker <- ["confirmation", "reset", "magic-link", "controlled recipient", "clean browser"] do
      assert String.contains?(staging, marker),
             "delivery evidence is missing #{inspect(marker)}"
    end

    for forbidden_claim <- [
          "external credential acceptance",
          "provider availability",
          "public TLS/proxy correctness",
          "transactional delivery",
          "device behavior"
        ] do
      assert String.contains?(host_pre_deploy, forbidden_claim),
             "Doctor boundary must explicitly reject #{inspect(forbidden_claim)} as proof"
    end
  end

  test "Google and device evidence are mandatory staging gates without a repository pass claim" do
    staging = read!(@recipe) |> tier_section!("Staging launch gate")

    for marker <- [
          "https://<canonical-host>/auth/google/callback",
          "real Google authorization",
          "controlled-recipient",
          "physical iPhone",
          "HTTPS hosted-browser return",
          "repository CI cannot mark this passed"
        ] do
      assert String.contains?(staging, marker),
             "staging-only evidence is missing #{inspect(marker)}"
    end
  end

  test "receipts redact sensitive values and deployment points back to the sole checklist" do
    recipe = read!(@recipe)
    deployment = read!(@deployment)

    for marker <- [
          "Redacted staging receipt",
          "Outcome:",
          "Timestamp:",
          "Environment:",
          "Configuration fingerprint:",
          "Operator sign-off:",
          "secret values",
          "token-bearing URLs",
          "mail bodies",
          "provider payloads"
        ] do
      assert String.contains?(recipe, marker),
             "redacted receipt contract is missing #{inspect(marker)}"
    end

    assert String.contains?(deployment, "b2c-alpha.md"),
           "detailed deployment mechanics must point back to the canonical B2C checklist"
  end
end
