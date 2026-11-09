defmodule Speccy.CLI do
  # Run by the launcher through the release's `eval`: no application is started.
  def main(["check" | rest]) do
    dir = Path.expand(List.first(rest) || ".")
    files = Path.wildcard(Path.join(dir, "**/*.json"))

    bad =
      for f <- files, match?({:error, _}, Jason.decode(File.read!(f), objects: :ordered_objects)),
          do: Path.relative_to(f, dir)

    Enum.each(bad, &IO.puts("#{&1}: invalid-json"))
    IO.puts("#{length(files)} files, #{length(bad)} problems")
    System.halt(if bad == [], do: 0, else: 1)
  end

  def main(args) do
    IO.puts(:stderr, "usage: speccy check [dir] | speccy open [dir] (got #{inspect(args)})")
    System.halt(2)
  end
end
