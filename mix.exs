defmodule Schemix.MixProject do
  use Mix.Project

  def project do
    [
      app: :schemix,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Schema definition and validation library for Elixir",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Schemix.Application, []}
    ]
  end

  defp deps do
    [
      # For JSON handling
      {:jason, "~> 1.4"},
      # For documentation
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "schemix",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/LiboShen/schemix"}
    ]
  end
end