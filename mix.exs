defmodule Bamboo.Mixfile do
  use Mix.Project

  @project_url "https://github.com/paulcsmith/bamboo"

  def project do
    [app: :bamboo,
     version: "0.4.2",
     elixir: "~> 1.2",
     source_url: @project_url,
     homepage_url: @project_url,
     compilers: compilers(Mix.env),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.circle": :test],
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Straightforward, composable, and adapter based Elixir email library " <>
     "for people that love piping. Adapters for Mandrill, Sendgrid, Sparkpost, in-memory, and test.",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     docs: [main: "readme", extras: ["README.md"]],
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
      licenses: ["MIT"],
      links: %{"GitHub" => @project_url}
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths ++ ["test/support"]
  defp elixirc_paths(_), do: elixirc_paths
  defp elixirc_paths, do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:ex_machina, "~> 1.0.0-beta.0", github: "thoughtbot/ex_machina", only: [:test]},
      {:cowboy, "~> 1.0", only: [:test, :dev]},
      {:phoenix, "~> 1.1", only: :test},
      {:phoenix_html, "~> 2.2", only: :test},
      {:excoveralls, "~> 0.4", only: :test},
      {:floki, "~> 0.8", only: :test},
      {:ex_doc, "~> 0.9", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:httpoison, "~> 0.8"},
      {:poison, ">= 1.5.0"},
    ]
  end
end
