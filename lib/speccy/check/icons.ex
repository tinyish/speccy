defmodule Speccy.Check.Icons do
  @moduledoc """
  The icon rules (`format.md` § The checker's rules): every icon reference
  resolves to an icon and a style its set has, and the spec's own sets are
  well named, aren't named after a supported library, and hold only safe
  SVGs (`Speccy.Icons.safe/1`).
  """

  import Speccy.Check, only: [problem: 4]
  alias Speccy.Icons

  @doc "The problems with the spec's own sets and SVGs."
  def run(icons, sets) do
    for(
      {path, svg} <- icons,
      {:error, code, why} <- [Icons.safe(svg)],
      do: problem(code, path, [], why)
    ) ++
      for(
        {set, names} <- sets,
        name <- [set | names],
        !Regex.match?(~r/^[a-z0-9_-]+$/, name),
        do:
          problem(
            :"bad-name",
            "assets/icons/#{set}#{if name != set, do: "/#{name}.svg"}",
            [],
            name
          )
      ) ++
      for(
        set <- Icons.libraries(),
        Map.has_key?(sets, set),
        do: problem(:"icon-set-is-library", "assets/icons/#{set}", [], set)
      )
  end

  @doc "Every icon reference in a value `v` at `at` that fits its type `t`, resolved."
  def values(spec, file, v, t, at) do
    for {p, ref} <- refs(v, t, spec),
        {:error, code} <- [Icons.resolve(ref, spec.icons)],
        do: problem(code, file, at ++ p, ref)
  end

  defp refs(v, "icon", _), do: [{[], v}]

  defp refs(v, t, spec) when is_binary(t) do
    cond do
      String.ends_with?(t, "[]") ->
        for {x, i} <- Enum.with_index(v),
            {p, ref} <- refs(x, String.trim_trailing(t, "[]"), spec),
            do: {[i | p], ref}

      fields = spec.models[t] ->
        for {f, x} <- v, x != nil, {p, ref} <- refs(x, fields[f], spec), do: {[f | p], ref}

      true ->
        []
    end
  end

  defp refs(_, _, _), do: []
end
