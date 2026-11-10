defmodule DesktopCanvas.MixProject do
  use Mix.Project

  def project do
    [app: :desktop_canvas, version: "0.0.1", elixir: "~> 1.18", deps: deps()]
  end

  def application, do: [mod: {DesktopCanvas.Application, []}, extra_applications: [:logger]]

  defp deps do
    [
      {:desktop, github: "elixir-desktop/desktop", override: true},
      {:desktop_webview, github: "elixir-desktop/webview"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
