defmodule Bamboo.Mixfile do
  use Mix.Project

  @project_url "https://github.com/thoughtbot/bamboo"

  def project do
    [
      app: :bamboo,
      version: "2.4.0",
      elixir: "~> 1.6",
      source_url: @project_url,
      homepage_url: @project_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.circle": :test],
      elixirc_paths: elixirc_paths(Mix.env()),
      description:
        "Straightforward, powerful, and adapter based Elixir email library." <>
          " Works with Mandrill, Mailgun, SendGrid, SparkPost, Postmark, in-memory, and test.",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),
      xref: [exclude: [IEx]],
      dialyzer: [plt_add_apps: [:mix, :iex]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [:logger, :eex],
      mod: {Bamboo, []}
    ]
  end

  defp package do
    [
      maintainers: ["German Velasco"],
      licenses: ["MIT"],
      links: %{"GitHub" => @project_url}
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths() ++ ["test/support"]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths, do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/upgrade_to_2_0.md"
      ]
    ]
  end

  defp deps do
    [
      {:hackney, ">= 1.15.2"},
      {:jason, "~> 1.0", optional: true},
      {:mime, "~> 1.4 or ~> 2.0"},
      {:plug, "~> 1.0"},

      # Dev & test dependencies
      {:cowboy, "~> 1.0", only: [:test, :dev]},
      {:credo, ">= 0.0.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev},
      {:ex_machina, "~> 2.4", only: :test},
      {:excoveralls, "~> 0.13", only: :test},
      {:floki, "~> 0.29", only: :test},
      {:plug_cowboy, "~> 1.0", only: [:dev, :test]}
    ]
  end
end
