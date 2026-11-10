# The liveview-canvas spike's modules, compiled unchanged from its script: every
# `defmodule` in it, without its Mix.install, config and boot.
defmodule DesktopCanvas.Spike do
  path = Path.expand("../../liveview-canvas/canvas.exs", __DIR__)
  @external_resource path
  {:__block__, _, exprs} = Code.string_to_quoted!(File.read!(path), file: path)
  for {:defmodule, _, _} = mod <- exprs, do: Code.eval_quoted(mod, [], file: path)
end
