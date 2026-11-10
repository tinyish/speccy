defmodule Mix.Tasks.Speccy.Schemas do
  @shortdoc "Writes the spec files' JSON Schemas to priv/schemas/"
  @moduledoc "Writes each kind of spec file's JSON Schema, as `Speccy.Schemas` builds it, to `priv/schemas/<format>/`."

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("compile")

    for kind <- Speccy.Schemas.kinds(), path = Speccy.Schemas.path(kind) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, Speccy.Schemas.encode(kind))
      Mix.shell().info("Wrote #{path}")
    end
  end
end
