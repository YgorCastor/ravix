defmodule Ravix.MixProject do
  use Mix.Project

  def project do
    [
      app: :ravix,
      version: "0.0.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:poison, "~> 5.0"},
      {:castore, "~> 0.1.14"},
      {:vex, "~> 0.9.0"},
      {:mappable, "~> 0.2.4"},
      {:enum_type, "~> 1.1"},
      {:elixir_uuid, "~> 1.2"},
      {:ok, "~> 2.3"},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17.0", only: :test},
      {:fake_server, "~> 2.1", only: :test}
    ]
  end
end
