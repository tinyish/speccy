defmodule Mix.Tasks.Speccy.Icons.Material do
  @shortdoc "Builds Material Symbols' index into priv/icons/material.json"
  @moduledoc """
  Builds the index of Material Symbols speccy ships (`format.md` § Icons):
  every icon `google/material-design-icons` draws at the pinned commit, with
  its categories and tags from Google's icon metadata, and its styles:
  the Outlined family's fill 0 (`outlined`, the default) and fill 1
  (`filled`). The SVGs aren't in the index: `svg` holds each style's URL at
  the pinned commit, `{name}` standing for the icon.
  """

  use Mix.Task

  @repo "google/material-design-icons"
  @commit "10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7"
  @metadata "https://fonts.google.com/metadata/icons?incomplete=1&key=material_symbols"
  @family "Material Symbols Outlined"
  @path "priv/icons/material.json"

  @impl true
  def run(_args) do
    %{"tree" => tree, "truncated" => false} =
      get("https://api.github.com/repos/#{@repo}/git/trees/#{@commit}:symbols/web")

    # The metadata comes after a `)]}'` line that keeps it from running as script.
    %{"icons" => listed} = get(@metadata, &(&1 |> String.split("\n", parts: 2) |> List.last()))

    # A name's Material Symbols entry wins over its older Material Icons one.
    # Icons Google no longer lists (renamed, such as `expand_more`) are still
    # drawn at the commit, so they stay, with whatever tags they had.
    listed =
      listed
      |> Enum.sort_by(&(@family not in &1["unsupported_families"]))
      |> Map.new(&{&1["name"], &1})

    icons =
      for %{"type" => "tree", "path" => name} <- Enum.sort_by(tree, & &1["path"]) do
        # The repository draws every icon at fill 0 and fill 1.
        {name,
         %{
           categories: Enum.uniq(for c <- listed[name]["categories"] || [], do: category(c)),
           tags:
             Enum.uniq(for t <- listed[name]["tags"] || [], t = String.trim(t), t != "", do: t),
           styles: ["outlined", "filled"]
         }}
      end

    svg =
      "https://raw.githubusercontent.com/#{@repo}/#{@commit}/symbols/web/{name}/materialsymbolsoutlined/{name}"

    lines =
      Enum.map(icons, fn {name, icon} -> "    #{Jason.encode!(name)}: #{Jason.encode!(icon)}" end)

    File.mkdir_p!(Path.dirname(@path))

    File.write!(@path, """
    {
      "library": "material",
      "version": "#{@commit}",
      "styles": ["outlined", "filled"],
      "svg": {
        "outlined": "#{svg}_24px.svg",
        "filled": "#{svg}_fill1_24px.svg"
      },
      "icons": {
    #{Enum.join(lines, ",\n")}
      }
    }
    """)

    Mix.shell().info("Wrote #{@path}: #{length(icons)} icons")
  end

  # Categories in one case, the older metadata's names merged into the newer's.
  @older %{
    "action" => "actions",
    "av" => "audio&video",
    "communication" => "communicate",
    "image" => "images"
  }

  defp category(c), do: Map.get(@older, String.downcase(c), String.downcase(c))

  defp get(url, body \\ & &1) do
    case Mix.Utils.read_path(url, timeout: 120_000) do
      {:ok, content} -> content |> body.() |> Jason.decode!()
      other -> Mix.raise("Can't read #{url}: #{inspect(other)}")
    end
  end
end
