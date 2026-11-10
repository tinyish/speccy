defmodule Speccy.Check.Schema do
  @moduledoc """
  Runs a file's JSON Schema (`Speccy.Schemas`, with JSV) and turns each
  failure into a problem with a stable code.
  """

  alias Speccy.{Format, Schemas}

  @roots Map.new(Schemas.kinds(), &{&1, JSV.build!(Schemas.build(&1))})

  @doc "The problems in the file at `path`, its JSON decoded to plain maps."
  def problems(path, json) do
    case JSV.validate(json, @roots[Atom.to_string(Format.kind(path))]) do
      {:ok, _} ->
        []

      {:error, error} ->
        # Level 10 keeps the errors that say why, not the ones pointing deeper.
        error |> JSV.normalize_error(min_error_level: 10) |> Map.fetch!(:details) |> leaves(path)
    end
  end

  # Skips the `if` of an if/then/else, whose failure only picks the branch.
  defp leaves(units, file) do
    for unit <- units,
        not String.ends_with?(unit.evaluationPath, "/if"),
        error <- Map.get(unit, :errors, []),
        problem <- leaf(error, unit, file),
        do: problem
  end

  defp leaf(%{details: details}, _unit, file), do: leaves(details, file)

  defp leaf(%{kind: :required, ctx: %{missing: missing}}, unit, file),
    do: for(key <- missing, do: problem(:"missing-key", file, unit, key, key))

  defp leaf(%{kind: kind, ctx: %{property: key}}, unit, file)
       when kind in [:additionalProperties, :properties] do
    # A key the object takes, but not beside another (`centerX` beside `left`).
    case Regex.run(~r{/dependentSchemas/(\w+)$}, unit.schemaLocation, capture: :all_but_first) do
      [beside] -> [problem(:"bad-value", file, unit, key, "#{key} beside #{beside}")]
      nil -> [problem(:"unknown-key", file, unit, key, key)]
    end
  end

  defp leaf(%{kind: kind, message: message}, unit, file) do
    def_name = Regex.run(~r{.*/\$defs/(\w+)}, unit.schemaLocation, capture: :all_but_first)

    code =
      cond do
        unit.instanceLocation == "#/$schema" -> :"wrong-schema"
        def_name == ["dataType"] -> :"unknown-type"
        kind == :pattern -> :"bad-name"
        true -> :"bad-value"
      end

    [problem(code, file, unit, nil, message)]
  end

  # At the object for a key it lacks or shouldn't have, the path names the key.
  defp problem(code, file, unit, key, detail) do
    at = unit.instanceLocation |> String.trim_leading("#") |> String.split("/", trim: true)
    Speccy.Check.problem(code, file, Enum.map(at, &unescape/1) ++ List.wrap(key), detail)
  end

  defp unescape(segment), do: segment |> String.replace("~1", "/") |> String.replace("~0", "~")
end
