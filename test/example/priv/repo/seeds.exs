# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Example.Repo.insert!(%Example.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# D-03: Two-layer defense against CI fixture contamination.
# Layer 1 (this guard): raises immediately in MIX_ENV=test, before any DB access.
# Layer 2: the `test` mix alias in mix.exs never calls this file.
if Mix.env() == :test do
  raise "seeds.exs must not run in MIX_ENV=test — it would contaminate the " <>
          "sandboxed CI fixture DB. Run with MIX_ENV=dev."
end

Example.Demo.Seeds.run()
