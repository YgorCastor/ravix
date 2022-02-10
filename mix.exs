defmodule Ravix.MixProject do
  use Mix.Project

  def project do
    [
      app: :ravix,
      version: "0.0.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mint, "~> 1.4"},
      {:jason, "~> 1.3"},
      {:castore, "~> 0.1.14"},
      {:vex, "~> 0.9.0"},
      {:mappable, "~> 0.2.4"},
      {:enum_type, "~> 1.1"},
      {:elixir_uuid, "~> 1.2"},
      {:ok, "~> 2.3"},
      {:morphix, "~> 0.8.1"},
      {:timex, "~> 3.7"},
      {:tzdata, "~> 1.1"},
      {:gradient, github: "esl/gradient", only: [:dev], runtime: false},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:dev]},
      {:dialyxir, "~> 1.1.0", only: [:dev], runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17.0", only: :test},
      {:fake_server, "~> 2.1", only: :test},
      {:assertions, "~> 0.19.0", only: :test},
      {:excoveralls, "~> 0.14.4", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
