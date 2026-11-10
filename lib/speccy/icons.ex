defmodule Speccy.Icons do
  @moduledoc """
  Icon references (`format.md` § Icons): `<set>/<name>`, or
  `<set>/<name>:<style>`, resolved against a library speccy supports, whose
  index ships in `priv/icons/<library>.json` (built by `mix
  speccy.icons.material`), or against the spec's own sets in
  `assets/icons/<set>/`, which have names only and never take a style.
  """

  @ref ~r/^([a-z0-9_-]+)\/([a-z0-9_-]+)(?::([a-z0-9_-]+))?$/

  @libraries Map.new(["material"], fn library ->
               path = Path.expand("../../priv/icons/#{library}.json", __DIR__)
               @external_resource path
               {library, path |> File.read!() |> Jason.decode!()}
             end)

  @doc "The names of the libraries speccy supports."
  def libraries, do: Map.keys(@libraries)

  @doc "A supported library's index (`version`, `styles`, `svg` and `icons`), or nil."
  def library(name), do: @libraries[name]

  @doc "A reference's set, name and style (nil when none is written), or `:error`."
  def parse(ref) when is_binary(ref) do
    case Regex.run(@ref, ref) do
      [_, set, name] -> {:ok, {set, name, nil}}
      [_, set, name, style] -> {:ok, {set, name, style}}
      nil -> :error
    end
  end

  def parse(_), do: :error

  @doc "The spec's own sets, from a loaded spec's icons: set → its icons' names."
  def sets(icons),
    do:
      Enum.group_by(Map.keys(icons), &Path.basename(Path.dirname(&1)), &Path.basename(&1, ".svg"))

  @doc """
  Whether a spec's SVG, which is untrusted and inlined into a page, is safe:
  `:ok`, or the code and what's wrong (`format.md` § Icons). It accepts only
  what a drawn icon needs (`untrusted-input-allowlists`): UTF-8, one `svg`
  root and nothing after it, the elements, attributes and namespaces below,
  references only inside the file (`url(#…)`; no `use`, `symbol` or `href`),
  and text only in a `title` or `desc`.
  Everything else is refused: DOCTYPEs and entities (refused before parsing,
  and by the parser in any encoding, so nothing expands), comments,
  processing instructions, CDATA, `<style>`, `class`, and any `(` or `\\` in
  a geometry or presentation value other than `url(#…)` and a transform's
  functions.
  """
  def safe({:error, why}), do: {:error, :"malformed-svg", why}

  def safe(svg) do
    cond do
      !String.valid?(svg) or String.contains?(svg, <<0>>) ->
        {:error, :"malformed-svg", "it isn't UTF-8"}

      svg =~ ~r/<!(doctype|entity)/i ->
        {:error, :"unsafe-svg", "a DOCTYPE or an entity"}

      true ->
        options = [
          :disallow_entities,
          :skip_external_dtd,
          event_fun: &svg_event/3,
          event_state: {[], nil}
        ]

        case :xmerl_sax_parser.stream(svg, options) do
          {:ok, {_, {code, why}}, _} -> {:error, code, why}
          {:ok, _, rest} -> trailing(String.trim(rest))
          {:fatal_error, _, why, _, _} -> {:error, :"malformed-svg", reason(why)}
        end
    end
  end

  defp trailing(""), do: :ok
  defp trailing(rest), do: {:error, :"malformed-svg", "something after the root: #{short(rest)}"}

  @elements ~w(svg g path circle rect ellipse line polyline polygon defs title desc
               linearGradient radialGradient stop clipPath mask)
  # Free text, never read as CSS; `aria-*` too.
  @text ~w(id version role)
  # Read as geometry or CSS, so held to `url(#…)` and a transform's functions.
  @styles ~w(viewBox preserveAspectRatio d x y x1 y1 x2 y2 cx cy r rx ry fx fy fr width height points pathLength
                 fill fill-opacity fill-rule stroke stroke-width stroke-linecap stroke-linejoin
                 stroke-miterlimit stroke-dasharray stroke-dashoffset stroke-opacity opacity color
                 transform clip-path clip-rule mask display visibility vector-effect shape-rendering
                 offset stop-color stop-opacity gradientUnits gradientTransform spreadMethod
                 clipPathUnits maskUnits maskContentUnits)
  @transforms ~r/\b(matrix|translate|scale|rotate|skewX|skewY)\s*\(/
  @namespaces [{"", "http://www.w3.org/2000/svg"}]

  # The state is the open elements and the first problem found.
  defp svg_event(event, _, {open, nil}), do: {svg_open(event, open), svg_problem(event, open)}
  defp svg_event(_, _, state), do: state

  defp svg_open({:startElement, _, name, _, _}, open), do: [to_string(name) | open]
  defp svg_open({:endElement, _, _, _}, [_ | open]), do: open
  defp svg_open(_, open), do: open

  defp svg_problem({:startElement, _, name, {prefix, _}, attrs}, open) do
    cond do
      open == [] and name != ~c"svg" ->
        {:"malformed-svg", "its root isn't svg"}

      prefix != [] or to_string(name) not in @elements ->
        {:"unsafe-svg", "an element an icon doesn't need: #{short(to_string(name))}"}

      true ->
        Enum.find_value(attrs, &svg_attribute/1)
    end
  end

  defp svg_problem({:characters, text}, open) do
    if hd(open) not in ["title", "desc"] and String.trim(to_string(text)) != "",
      do: {:"unsafe-svg", "text outside a title or desc"}
  end

  defp svg_problem({:startPrefixMapping, prefix, uri}, _) do
    if {to_string(prefix), to_string(uri)} not in @namespaces,
      do: {:"unsafe-svg", "a namespace an icon doesn't need: #{short(to_string(uri))}"}
  end

  defp svg_problem(event, _) when event in [:startDocument, :endDocument], do: nil
  defp svg_problem({:endElement, _, _, _}, _), do: nil
  defp svg_problem({tag, _}, _) when tag in [:endPrefixMapping, :ignorableWhitespace], do: nil

  # Comments, processing instructions, CDATA and DTDs, which an HTML page
  # can read differently from XML.
  defp svg_problem(event, _),
    do:
      {:"unsafe-svg",
       "something an icon doesn't need: #{if is_tuple(event), do: elem(event, 0), else: event}"}

  defp svg_attribute({_, prefix, name, value}) do
    {prefix, name, value} = {to_string(prefix), to_string(name), to_string(value)}

    cond do
      prefix != "" or
          (name not in @text and name not in @styles and !String.starts_with?(name, "aria-")) ->
        {:"unsafe-svg",
         "an attribute an icon doesn't need: #{short("#{prefix}#{if prefix != "", do: ":"}#{name}")}"}

      name in @styles and
          value
          |> String.replace(~r/url\(#[\w.:-]+\)/, "")
          |> then(
            &if(name in ~w(transform gradientTransform),
              do: String.replace(&1, @transforms, ""),
              else: &1
            )
          )
          |> String.contains?(["(", "\\"]) ->
        {:"unsafe-svg", "a CSS function or escape in #{name}: #{short(value)}"}

      true ->
        nil
    end
  end

  defp reason(why) when is_list(why), do: short(List.to_string(why))
  defp reason(why), do: short(inspect(why))

  # A spec's content quoted in a message, cut short.
  defp short(text),
    do: if(String.length(text) > 60, do: String.slice(text, 0, 60) <> "…", else: text)

  @doc """
  Resolves a reference against the libraries and the spec's `sets`: its set,
  name and style, the set's first style when none is written (nil for a
  spec's set), or the code of what doesn't resolve.
  """
  def resolve(ref, sets) do
    with {:ok, {set, name, style}} <- parse(ref) do
      case {@libraries[set], sets[set]} do
        {%{"icons" => icons, "styles" => [default | _]}, _} ->
          cond do
            !icons[name] -> {:error, :"unknown-icon"}
            (style || default) not in icons[name]["styles"] -> {:error, :"unknown-icon-style"}
            true -> {:ok, {set, name, style || default}}
          end

        {nil, nil} ->
          {:error, :"unknown-icon-set"}

        {nil, names} ->
          cond do
            name not in names -> {:error, :"unknown-icon"}
            style -> {:error, :"unknown-icon-style"}
            true -> {:ok, {set, name, nil}}
          end
      end
    end
  end
end
