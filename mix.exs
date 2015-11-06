defmodule Bamboo.Mixfile do
  use Mix.Project

  def project do
    [app: :bamboo,
     version: "0.0.1",
     elixir: "~> 1.1",
     description: "Makes emails awesome",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cowboy, :httpoison, :poison]]
  end

  defp package do
    [
      maintainers: ["Paul Smith"],
      licenses: ["MIT"]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:plug, "~> 1.0", only: [:test]},
      {:cowboy, "~> 1.0", only: [:test]},
      {:httpoison, "~> 0.7.4"},
      {:poison, "~> 1.5"}
    ]
  end
end
