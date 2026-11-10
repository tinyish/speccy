defmodule Speccy.Format do
  @moduledoc """
  Reads a spec's files into their decoded JSON, key order kept, and
  encodes one file the way `format.md` § Writing files says.

  A loaded spec is `%{files: %{path => json | {:error, message}}, icons:
  %{path => svg}}`, paths relative to the spec folder. A file that can't be
  read, or isn't valid JSON, is kept as `{:error, message}` so the rest
  still loads.
  """

  @globs ~w(speccy.json components/*.json screens/*.json data/*.json assets/icons/*/*.svg)

  @doc "The spec folder holding `path`: the nearest folder, at or above it, with a `speccy.json`."
  def find(path) do
    path = Path.expand(path)

    cond do
      File.regular?(Path.join(path, "speccy.json")) -> {:ok, path}
      Path.dirname(path) == path -> :error
      true -> find(Path.dirname(path))
    end
  end

  @doc "Reads every file of the spec in `dir`. The only function here that touches the disk."
  def load(dir) do
    @globs
    # Globbed relative to dir, so the folder's own name is never read as a pattern.
    |> Enum.flat_map(&:filelib.wildcard(String.to_charlist(&1), String.to_charlist(dir)))
    |> Map.new(&{to_string(&1), read(Path.join(dir, &1))})
    |> from_contents()
  end

  defp read(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, reason} -> {:error, "can't read the file: #{:file.format_error(reason)}"}
    end
  end

  @doc "A loaded spec from each file's path and content (or `{:error, message}`)."
  def from_contents(contents) do
    {icons, files} = Map.split_with(contents, fn {path, _} -> String.ends_with?(path, ".svg") end)
    %{files: Map.new(files, fn {path, content} -> {path, decode(content)} end), icons: icons}
  end

  @doc "One file's JSON, key order kept, or `{:error, message}`."
  def decode({:error, _} = error), do: error

  def decode(content) do
    case Jason.decode(content, objects: :ordered_objects) do
      {:ok, json} -> json
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  @layout ~w(layout wrap columns rows align gap lineGap padding clip)
  @place ~w(width height minWidth maxWidth minHeight maxHeight column row columnSpan rowSpan absolute x y constraints)
  @instances {:list, :instance}

  # Each kind of object: its keys in format.md's table order, and the kind of
  # the values under some of them ({:map, kind} for name → kind).
  @kinds %{
    manifest: {~w($schema format devices), %{"devices" => {:map, :device}}},
    device: {~w(about width height shape cornerRadius input safeArea orientations), %{}},
    data: {~w($schema data about fields), %{"fields" => {:map, :typed}}},
    component:
      {~w($schema component about props width height) ++
         @layout ++ ~w(children variations states),
       %{
         "props" => {:map, :typed},
         "children" => @instances,
         "variations" => {:map, :variation},
         "states" => {:map, :state}
       }},
    screen:
      {~w($schema screen about device orientation data) ++
         @layout ++ ~w(children variations states),
       %{
         "data" => {:map, :sample},
         "children" => @instances,
         "variations" => {:map, :variation},
         "states" => {:map, :state}
       }},
    typed: {~w(type about default), %{}},
    sample: {~w(type sample), %{}},
    instance:
      {~w(copy id about use props bind repeat state variation slots slot) ++
         @place ++ @layout ++ ~w(children inner),
       %{
         "repeat" => :repeat,
         "constraints" => :constraints,
         "slots" => {:map, @instances},
         "children" => @instances,
         "inner" => {:map, :instance}
       }},
    repeat: {~w(each as limit), %{}},
    constraints: {~w(horizontal vertical), %{}},
    state:
      {~w(about data children variations),
       %{"children" => @instances, "variations" => {:map, :variation}}},
    variation: {~w(about content), %{}}
  }

  @doc "Each kind of object: `{keys in format.md's order, kind of the values under some keys}`."
  def kinds, do: @kinds

  @doc "The layout keys, in format.md's order."
  def layout, do: @layout

  @doc """
  The file at `path` (relative to the spec) as 2-space JSON with a trailing
  newline: `$schema` first, each object's keys in format.md's order, unknown
  keys after them in the order they had. Raises on a path that isn't a spec
  file's, relative to the spec folder.
  """
  def encode(path, json) do
    Jason.encode!(order(json, kind(path)), pretty: true) <> "\n"
  end

  @doc "The kind of the spec file at `path`, relative to the spec folder."
  def kind("speccy.json"), do: :manifest
  def kind("components/" <> _), do: :component
  def kind("screens/" <> _), do: :screen
  def kind("data/" <> _), do: :data

  defp order(json, nil), do: json
  defp order(list, {:list, kind}) when is_list(list), do: Enum.map(list, &order(&1, kind))

  defp order(%Jason.OrderedObject{values: values}, {:map, kind}) do
    %Jason.OrderedObject{values: Enum.map(values, fn {k, v} -> {k, order(v, kind)} end)}
  end

  defp order(%Jason.OrderedObject{values: values}, kind) when is_atom(kind) do
    {keys, nested} = @kinds[kind]
    rank = fn {k, _} -> Enum.find_index(keys, &(&1 == k)) || length(keys) end

    values =
      values
      |> Enum.sort_by(rank)
      |> Enum.map(fn {k, v} -> {k, order(v, nested[k])} end)

    %Jason.OrderedObject{values: values}
  end

  defp order(json, _kind), do: json
end
