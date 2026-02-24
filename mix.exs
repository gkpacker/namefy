defmodule InpiChecker.MixProject do
  use Mix.Project

  def project do
    [
      app: :inpi_checker,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {InpiChecker.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:floki, "~> 0.36"},
      {:jason, "~> 1.4"},
      {:dotenvy, "~> 0.8"}
    ]
  end
end
