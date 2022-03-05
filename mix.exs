defmodule Glock.MixProject do
  use Mix.Project

  @name "Glock"
  @version "0.1.3"
  @repo "https://github.com/jeffgrunewald/glock"

  def project do
    [
      app: :glock,
      name: @name,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @repo,
      homepage_url: @repo,
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_file: {:no_warn, ".dialyzer/#{System.version()}.plt"}]
    ]
  end

  def application,
    do: [extra_applications: [:logger]]

  defp deps do
    [
      {:certifi, "~> 2.9", optional: true},
      {:cowlib, "~> 2.11.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev},
      {:gun, "~> 2.0.0-rc.2"},
      {:plug_cowboy, "~> 2.5", only: [:test]},
      {:ssl_verify_fun, "~> 1.1", optional: true}
    ]
  end

  defp elixirc_paths(env) when env in [:test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Jeff Grunewald"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @repo}
    ]
  end

  defp docs do
    [
      source_ref: "#{@repo}",
      source_url: @repo,
      main: @name
    ]
  end

  defp description,
    do: "Simple websocket client based on the :gun http client library"
end
