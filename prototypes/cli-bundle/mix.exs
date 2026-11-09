defmodule Speccy.MixProject do
  use Mix.Project

  def project do
    [
      app: :speccy,
      version: "0.0.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [name: "Speccy", name_long: "speccy", identifier: "dev.speccy.spike"],
      releases: [
        speccy: [steps: [:assemble, &writable/1, &Desktop.Deployment.generate_installer/1]]
      ]
    ]
  end

  def application, do: [mod: {Speccy.Application, []}, extra_applications: [:logger]]

  # Homebrew's erts files are read-only, which stops the installer's ad-hoc codesign.
  defp writable(release) do
    {_, 0} = System.cmd("chmod", ["-R", "u+w", release.path])
    release
  end

  defp deps do
    [
      {:desktop, github: "elixir-desktop/desktop", override: true},
      {:desktop_webview, github: "elixir-desktop/webview"},
      {:desktop_deployment, github: "elixir-desktop/deployment", runtime: false},
      {:phoenix, "~> 1.8"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
