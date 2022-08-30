defmodule Ravix.MixProject do
  use Mix.Project

  def project do
    [
      app: :ravix,
      version: "0.6.3",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
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
      ],
      source_url: "https://github.com/YgorCastor/ravix",
      homepage_url: "https://github.com/YgorCastor/ravix",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Ravix, []},
      env: [],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:castore, "~> 0.1"},
      {:elixir_uuid, "~> 1.2"},
      {:finch, "~> 0.13"},
      {:inflex, "~> 2.1"},
      {:jason, "~> 1.3"},
      {:jaxon, "~> 2.0"},
      {:hackney, "~> 1.18"},
      {:mappable, "~> 0.2"},
      {:morphix, "~> 0.8"},
      {:ok, "~> 2.3"},
      {:retry, "~> 0.16"},
      {:tesla, "~> 1.4"},
      {:timex, "~> 3.7"},
      {:tzdata, "~> 1.1"},
      {:gradient, github: "esl/gradient", only: [:dev, :test], runtime: false},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:dev]},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:bypass, "~> 2.1", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17", only: :test},
      {:assertions, "~> 0.19", only: :test},
      {:excoveralls, "~> 0.14", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:version_tasks, "~> 0.12", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "An Elixir driver for RavenDB"
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/YgorCastor/ravix"},
      sponsor: "ycastor.eth"
    ]
  end
end
