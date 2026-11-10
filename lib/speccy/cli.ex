defmodule Speccy.CLI do
  @moduledoc """
  The `speccy` command (`core.md` § The command line): parses its
  arguments, calls the core once and prints. `run/1` returns what to print
  and the exit status, so tests call it without halting; `main/1` prints
  and halts.

  `explain`'s prose is `format.md` itself, embedded at compile time, one
  topic per section; the references beside it are generated from the code.
  """

  alias Speccy.{Check, Devices, Format, Icons, Primitives, Schemas, Spec}

  @usage """
  Usage:
    speccy check [<path>] [--json]   check the spec at or above <path> (default: here)
    speccy explain [<topic>]         the format, each primitive and every check code
  """

  @doc "Runs the command in `argv`, prints its output and halts with its exit status."
  def main(argv) do
    {output, status} = run(argv)
    # A closed pipe (`speccy check | head`) fails the write: exit quietly, same status,
    # with the logger off so the tty writer's crash report isn't printed either.
    :logger.set_primary_config(:level, :none)

    try do
      IO.write(if(status == 2, do: :stderr, else: :stdio), output)
    catch
      _, _ -> :ok
    end

    System.halt(status)
  end

  @doc "What the command in `argv` prints, and its exit status: 0 done, 1 problems, 2 usage."
  def run(["check" | args]) do
    case OptionParser.parse(args, strict: [json: :boolean]) do
      {opts, [], []} -> check(".", opts[:json])
      {opts, [path], []} -> check(path, opts[:json])
      _ -> {@usage, 2}
    end
  end

  def run(help) when help in [[], ["help"], ["--help"]], do: {@usage, 0}
  def run(["explain"]), do: {overview(), 0}
  def run(["explain", topic]), do: explain(topic)
  def run(_), do: {@usage, 2}

  ## check

  defp check(path, json?) do
    with true <- File.exists?(path), {:ok, dir} <- Format.find(path) do
      problems = Check.run(Spec.new(Format.load(dir)))

      {if(json?, do: [Jason.encode!(problems, pretty: true), "\n"], else: lines(problems, dir)),
       if(problems == [], do: 0, else: 1)}
    else
      false -> {"No such file or folder: #{path}\n", 2}
      :error -> {"No spec found: no speccy.json at or above #{Path.expand(path)}\n", 2}
    end
  end

  defp lines(problems, dir) do
    count =
      case length(problems) do
        0 -> "No problems"
        1 -> "1 problem"
        n -> "#{n} problems"
      end

    Enum.map(problems, fn p ->
      [
        Enum.join(Enum.reject([p.file, p.path], &(&1 == "")), " "),
        " #{p.code}: #{String.replace(p.message, ~r/\s+/, " ")}\n"
      ]
    end) ++ ["#{count} in #{dir}\n"]
  end

  ## explain

  @format_md Path.expand("../../brain/architecture/format.md", __DIR__)
  @external_resource @format_md

  [head | sections] = @format_md |> File.read!() |> String.split(~r/^## /m)
  @title head |> String.split("\n", parts: 2) |> hd()

  # Each section by its title, without a trailing "(`<file>`)".
  @sections Map.new(sections, fn section ->
              [title | _] = String.split(section, "\n", parts: 2)
              {String.replace(title, ~r/ \(.*\)$/, ""), String.trim_trailing("## " <> section)}
            end)

  @overview ["How it is defined", "What stays in code", "The spec folder"]
  # For speccy's own builders, not for whoever writes a spec.
  @builders ["The architect's calls", "Open"]
  @topics [
    {"names", "Names"},
    {"types", "Types"},
    {"devices", "Devices"},
    {"data", "Data model"},
    {"components", "Component"},
    {"screens", "Screen"},
    {"instances", "Instance"},
    {"layout", "Layout"},
    {"states", "States and variations"},
    {"icons", "Icons"},
    {"rules", "The checker's rules"},
    {"writing", "Writing files"},
    {"later", "Not in the MVP"}
  ]

  for title <- Map.keys(@sections),
      title not in (@overview ++ @builders ++ for({_, t} <- @topics, do: t)) do
    raise "format.md's section \"#{title}\" is no `speccy explain` topic"
  end

  for title <- @overview ++ for({_, t} <- @topics, do: t), !Map.has_key?(@sections, title) do
    raise "`speccy explain` maps \"#{title}\", which is no section of format.md"
  end

  defp overview do
    [
      "# #{@title |> String.trim_leading("# ")}\n\n",
      Enum.map_intersperse(@overview, "\n\n", &Map.fetch!(@sections, &1)),
      "\n\nThe schemas of format #{Schemas.format()}:\n\n",
      for(kind <- Schemas.kinds(), do: "- `#{Schemas.url(kind)}`\n"),
      "\n",
      topics()
    ]
  end

  defp topics do
    [
      "## Topics\n\n`speccy explain <topic>`, one of:\n\n",
      for({topic, title} <- @topics, do: "- `#{topic}`: #{title}\n"),
      "- `primitives`: the 25 primitives\n",
      "- `<primitive>`: one primitive's interface (`speccy explain button`)\n",
      "- `codes`: every code `speccy check` reports\n"
    ]
  end

  defp explain("primitives") do
    {[
       "# Primitives\n\n| Name | Category | About |\n| --- | --- | --- |\n",
       for(
         m <- Primitives.all(),
         i = m.interface(),
         do: "| `#{i.name}` | #{i.category} | #{i.about} |\n"
       )
     ], 0}
  end

  defp explain("codes") do
    {[
       "# Check codes\n\n",
       for({code, message} <- Check.codes(), do: "- `#{code}`: #{message}\n")
     ], 0}
  end

  defp explain(topic) do
    case {List.keyfind(@topics, topic, 0), Primitives.get(topic)} do
      {{_, title}, _} -> {[Map.fetch!(@sections, title), "\n", more(topic)], 0}
      {nil, nil} -> {["Unknown topic: #{topic}\n\n", topics()], 2}
      {nil, module} -> {primitive(module.interface()), 0}
    end
  end

  defp more("devices") do
    [
      "\n## Presets\n\n| Name | Size | Shape | Input | Orientations | About |\n| --- | --- | --- | --- | --- | --- |\n",
      for {name, d} <- Devices.all() do
        "| `#{name}` | #{d["width"]}×#{d["height"]} | #{d["shape"] || "rect"} | #{Enum.join(d["input"] || [], ", ")} | #{Enum.join(d["orientations"] || [], ", ")} | #{d["about"]} |\n"
      end
    ]
  end

  defp more("icons") do
    [
      "\n## Supported libraries\n\n",
      for name <- Icons.libraries(), lib = Icons.library(name) do
        "- `#{name}`: #{map_size(lib["icons"])} icons, styles #{Enum.map_join(lib["styles"], ", ", &"`#{&1}`")} (the first is the default), version `#{lib["version"]}`\n"
      end
    ]
  end

  defp more(_), do: []

  defp primitive(interface) do
    [
      "# #{interface.name}\n\n#{interface.about}\n\n",
      "Its interface: `props` and their types (`speccy explain types`), `defaults` (what an unset prop means), ",
      "`states` (what each sets), `events`, `children` (holds children), `slot` (can be a component's slot), ",
      "`pressable` (`{\"prop\": p}`: when `p` is set) and `examples` (sample props).\n\n",
      "```json\n",
      Jason.encode!(Primitives.json(interface), pretty: true),
      "\n```\n"
    ]
  end
end
