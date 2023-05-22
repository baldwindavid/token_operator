defmodule TokenOperator.MixProject do
  use Mix.Project

  def project do
    [
      app: :token_operator,
      version: "0.3.0",
      description: "Simple library to make consistent keyword list-based APIs",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      maintainers: ["David Baldwin"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/baldwindavid/token_operator"},
      files: ~w(mix.exs README.md lib)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
