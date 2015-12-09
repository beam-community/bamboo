defmodule Bamboo.Mixfile do
  use Mix.Project

  def project do
    [app: :bamboo,
     version: "0.1.0",
     elixir: "~> 1.1",
     compilers: compilers(Mix.env),
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Makes emails awesome",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     deps: deps]
  end

  defp compilers(:test), do: [:phoenix] ++ Mix.compilers
  defp compilers(_), do: Mix.compilers

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger, :httpoison, :poison],
      mod: {Bamboo, []}
    ]
  end

  defp package do
    [
      maintainers: ["Paul Smith"],
      licenses: ["MIT"]
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths ++ ["test/support"]
  defp elixirc_paths(_), do: elixirc_paths
  defp elixirc_paths, do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.0", only: [:test]},
      {:cowboy, "~> 1.0", only: [:test]},
      {:phoenix, "~> 1.0", only: [:test]},
      {:phoenix_html, "~> 2.2", only: [:test]},
      {:httpoison, "~> 0.7.4"},
      {:poison, "~> 1.5"}
    ]
  end
end
