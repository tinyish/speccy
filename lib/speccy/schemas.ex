defmodule Speccy.Schemas do
  @moduledoc """
  The JSON Schema (draft 2020-12) of each kind of spec file, built from
  `format.md`'s definition. They cover structure
  and literal syntax; references, prop types and composition are
  `Speccy.Check`'s rules. `mix speccy.schemas` writes them to
  `priv/schemas/<format>/`.
  """

  @format 1
  @kinds ~w(manifest component screen data)

  @doc "The kinds of spec file."
  def kinds, do: @kinds

  @doc "The format version these schemas describe."
  def format, do: @format

  @doc "The public URL of `kind`'s schema, which spec files name in `$schema`."
  def url(kind),
    do:
      "https://raw.githubusercontent.com/tinyish/speccy/main/priv/schemas/#{@format}/#{kind}.schema.json"

  @doc "The schema of `kind`, as JSON-able data."
  def build(kind) when kind in @kinds do
    {required, properties} = root(kind)

    schema = %{
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "$id" => url(kind),
      "title" => "speccy #{kind} file, format #{@format}",
      "type" => "object",
      "required" => ["$schema" | required],
      "additionalProperties" => false,
      "properties" => Map.put(properties, "$schema", %{"const" => url(kind)})
    }

    Map.put(schema, "$defs", Map.take(defs(), reached(refs(schema), MapSet.new())))
  end

  # The defs a schema reaches, through the defs it reaches.
  defp reached([], seen), do: MapSet.to_list(seen)

  defp reached([name | rest], seen) do
    if name in seen,
      do: reached(rest, seen),
      else: reached(refs(defs()[name]) ++ rest, MapSet.put(seen, name))
  end

  defp refs(%{"$ref" => "#/$defs/" <> name}), do: [name]
  defp refs(map) when is_map(map), do: Enum.flat_map(map, fn {_, v} -> refs(v) end)
  defp refs(list) when is_list(list), do: Enum.flat_map(list, &refs/1)
  defp refs(_), do: []

  @doc "The schema of `kind` as the file `mix speccy.schemas` writes: 2-space JSON, keys sorted."
  def encode(kind) do
    %Jason.OrderedObject{values: values} = sorted(build(kind))
    {first, rest} = Enum.split_with(values, &(elem(&1, 0) in ["$schema", "$id"]))
    Jason.encode!(%Jason.OrderedObject{values: Enum.reverse(first) ++ rest}, pretty: true) <> "\n"
  end

  @doc "Where `kind`'s schema file lives in the repository."
  def path(kind), do: Path.join(["priv/schemas", "#{@format}", "#{kind}.schema.json"])

  defp sorted(map) when is_map(map),
    do: %Jason.OrderedObject{
      values: map |> Enum.sort() |> Enum.map(fn {k, v} -> {k, sorted(v)} end)
    }

  defp sorted(list) when is_list(list), do: Enum.map(list, &sorted/1)
  defp sorted(value), do: value

  defp root("manifest") do
    {~w(format),
     %{
       "format" => %{"type" => "integer", "minimum" => 1},
       "devices" => names("deviceName", ref("device"))
     }}
  end

  defp root("data") do
    {~w(data about),
     %{
       "data" => ref("pascal"),
       "about" => ref("about"),
       "fields" => names("camel", typed(%{"about" => ref("about")}))
     }}
  end

  defp root("component") do
    {~w(component about),
     Map.merge(item(ref("componentState")), %{
       "component" => ref("pascal"),
       "props" => names("camel", typed(%{"about" => ref("about"), "default" => true})),
       "width" => ref("size"),
       "height" => ref("size")
     })}
  end

  defp root("screen") do
    {~w(screen about device),
     Map.merge(item(ref("screenState")), %{
       "screen" => ref("pascal"),
       "device" => ref("deviceName"),
       "orientation" => ref("orientation"),
       "data" =>
         names("camel", %{
           "type" => "object",
           "required" => ["type"],
           "additionalProperties" => false,
           "properties" => %{"type" => ref("dataType"), "sample" => true}
         })
     })}
  end

  # What components and screens share: about, the root's layout, its
  # children, variations and states.
  defp item(state) do
    Map.merge(layout(), %{
      "about" => ref("about"),
      "children" => list(ref("instance")),
      "variations" => names("camel", ref("variation")),
      "states" => names("camel", state)
    })
  end

  defp defs do
    %{
      "pascal" => pattern("^[A-Z][A-Za-z0-9]*$"),
      "camel" => pattern("^[a-z][A-Za-z0-9]*$"),
      "deviceName" => pattern("^[a-z0-9-]+$"),
      "path" => pattern("^[a-z][A-Za-z0-9]*(\\.[a-z][A-Za-z0-9]*)*$"),
      "contentKey" => pattern("^[a-z][A-Za-z0-9]*\\.[a-z][A-Za-z0-9]*$"),
      "use" => pattern("^([a-z][a-z0-9]*(-[a-z0-9]+)*|[A-Z][A-Za-z0-9]*)$"),
      "about" => %{"type" => "string", "minLength" => 1},
      "dataType" => %{
        "if" => %{"type" => "string"},
        "then" => pattern("^(text|bool|number|icon|text\\[\\]|[A-Z][A-Za-z0-9]*(\\[\\])?)$"),
        "else" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "minItems" => 1,
          "uniqueItems" => true
        }
      },
      "px" => %{"type" => "number", "minimum" => 0},
      "size" => %{"anyOf" => [%{"enum" => ["fill", "hug"]}, ref("px")]},
      "insets" => %{
        "anyOf" => [ref("px"), fixed_list(ref("px"), 2), fixed_list(ref("px"), 4)]
      },
      "tracks" => %{
        "anyOf" => [
          %{"type" => "integer", "minimum" => 1},
          %{
            "type" => "array",
            "minItems" => 1,
            "items" => %{"anyOf" => [ref("px"), %{"enum" => ["fill", "hug"]}]}
          }
        ]
      },
      "orientation" => %{"enum" => ["portrait", "landscape"]},
      "instance" => instance(ref("instance")),
      "stateInstance" => instance(ref("entry")),
      "entry" => %{
        "if" => %{"type" => "object", "required" => ["copy"]},
        "then" => ref("copy"),
        "else" => ref("stateInstance")
      },
      "copy" =>
        object(
          ~w(copy),
          Map.merge(settings(), %{
            "copy" => ref("camel"),
            "inner" => names("camel", object([], settings()))
          })
        ),
      "variation" =>
        object(~w(about), %{
          "about" => ref("about"),
          "content" => %{
            "type" => "object",
            "propertyNames" => ref("contentKey"),
            "additionalProperties" => %{"type" => "string"}
          }
        }),
      "componentState" => object(~w(about), state()),
      "screenState" => object(~w(about), Map.put(state(), "data", names("camel", true))),
      "device" =>
        object(~w(about width height), %{
          "about" => ref("about"),
          "width" => %{"type" => "number", "exclusiveMinimum" => 0},
          "height" => %{"type" => "number", "exclusiveMinimum" => 0},
          "shape" => %{"enum" => ["rect", "round"]},
          "cornerRadius" => %{"anyOf" => [ref("px"), fixed_list(ref("px"), 4)]},
          "input" =>
            set(%{
              "enum" => ~w(touch pointer keyboard rotary dpad gamepad voice)
            }),
          "safeArea" => ref("insets"),
          "orientations" => set(ref("orientation"))
        })
        |> Map.merge(%{
          "if" => %{"required" => ["shape"], "properties" => %{"shape" => %{"const" => "round"}}},
          "then" => %{"properties" => %{"cornerRadius" => false}}
        })
    }
  end

  defp state do
    %{
      "about" => ref("about"),
      "children" => list(ref("entry")),
      "variations" => names("camel", ref("variation"))
    }
  end

  defp instance(child) do
    object(
      ~w(id use),
      settings()
      |> Map.merge(layout())
      |> Map.merge(%{
        "id" => ref("camel"),
        "about" => ref("about"),
        "use" => ref("use"),
        "bind" => names("camel", ref("path")),
        "repeat" =>
          object(~w(each as), %{
            "each" => ref("path"),
            "as" => ref("camel"),
            "limit" => %{"type" => "integer", "minimum" => 1}
          }),
        "slots" => names("camel", list(child)),
        "slot" => ref("camel"),
        "children" => list(child)
      })
    )
  end

  # What a linked copy, or an `inner` entry, may set: props, state and
  # variation, and its place.
  defp settings do
    %{
      "props" => names("camel", true),
      "state" => ref("camel"),
      "variation" => ref("camel"),
      "width" => ref("size"),
      "height" => ref("size"),
      "minWidth" => ref("px"),
      "maxWidth" => ref("px"),
      "minHeight" => ref("px"),
      "maxHeight" => ref("px"),
      "column" => %{"type" => "integer", "minimum" => 1},
      "row" => %{"type" => "integer", "minimum" => 1},
      "columnSpan" => %{"type" => "integer", "minimum" => 1},
      "rowSpan" => %{"type" => "integer", "minimum" => 1},
      "absolute" => %{"type" => "boolean"},
      "x" => %{"type" => "number"},
      "y" => %{"type" => "number"},
      "constraints" =>
        object([], %{
          "horizontal" => %{"enum" => ~w(left right center left-right scale)},
          "vertical" => %{"enum" => ~w(top bottom center top-bottom scale)}
        })
    }
  end

  defp layout do
    %{
      "layout" => %{"enum" => ~w(row column stack grid)},
      "wrap" => %{"type" => "boolean"},
      "columns" => ref("tracks"),
      "rows" => ref("tracks"),
      "align" => %{
        "enum" => ~w(top-left top top-right left center right bottom-left bottom bottom-right)
      },
      "gap" => %{"anyOf" => [%{"type" => "number"}, %{"enum" => ~w(between around evenly)}]},
      "lineGap" => %{"type" => "number"},
      "padding" => ref("insets"),
      "clip" => %{"type" => "boolean"}
    }
  end

  # A type, or an object with it under `type`.
  defp typed(extra) do
    %{
      "if" => %{"type" => "object"},
      "then" => object(~w(type), Map.put(extra, "type", ref("dataType"))),
      "else" => ref("dataType")
    }
  end

  defp ref(name), do: %{"$ref" => "#/$defs/#{name}"}
  defp pattern(regex), do: %{"type" => "string", "pattern" => regex}
  defp list(items), do: %{"type" => "array", "items" => items}

  defp set(items),
    do: %{"type" => "array", "items" => items, "minItems" => 1, "uniqueItems" => true}

  defp fixed_list(items, n),
    do: %{"type" => "array", "items" => items, "minItems" => n, "maxItems" => n}

  defp names(name, values),
    do: %{"type" => "object", "propertyNames" => ref(name), "additionalProperties" => values}

  defp object(required, properties) do
    %{
      "type" => "object",
      "required" => required,
      "additionalProperties" => false,
      "properties" => properties
    }
  end
end
