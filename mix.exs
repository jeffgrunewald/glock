defmodule Glock.MixProject do
  use Mix.Project

  @github "https://github.com/jeffgrunewald/glock"

  def project do
    [
      app: :glock,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      dialyzer: [plt_file: {:no_warn, ".dialyzer/#{System.version()}.plt"}]
    ]
  end

  def application,
    do: [extra_applications: [:logger]]

  defp deps do
    [
      {:cowlib, "~> 2.8.0", override: true},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21.0", only: :dev},
      {:gun, github: "ninenines/gun", tag: "2.0.0-pre.1"}
    ]
  end

  defp package do
    [
      maintainers: ["Jeff Grunewald"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @github}
    ]
  end

  defp docs do
    [
      source_url: @github,
      extras: ["README.md"],
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}"
    ]
  end

  defp description,
    do: "Simple websocket client based on the :gun http client library"
end
