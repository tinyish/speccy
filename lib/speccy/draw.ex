defmodule Speccy.Draw do
  @moduledoc """
  A resolved frame (`Speccy.Resolve.frame/4`) drawn as HTML: each
  primitive by its module's `draw/1`, styled only by `wireframe.css`, its
  layout and size by `Speccy.Layout`. Pure.

  A primitive's `draw/1` gets `props` (as drawn), `unknown` (bound props
  with nothing to show, whose `props` value is only the default), `icons`,
  `style` (its `Layout.item` and, when it holds children, `Layout.box`),
  `item` and `box` apart, for one whose children sit inside it, `data`
  (`data-file` and `data-chain`) and its children, rendered, as the
  `inner_block`. It puts `data`, and `style` or `item`, on its outermost
  element.
  """

  use Phoenix.Component

  # Drawn HTML is read as it is (`speccy render`), so no dev-only debug markup;
  # each primitive's module sets the same.
  @debug_heex_annotations false
  @debug_attributes false

  alias Speccy.{Icons, Layout, Primitives}

  @css_path Path.expand("primitives/wireframe.css", __DIR__)
  @external_resource @css_path
  @css File.read!(@css_path)

  @doc "`wireframe.css`, read at compile time."
  def css, do: @css

  @doc """
  A frame: `tree` its resolved root, `icons` reference → SVG, `size`
  `{width, height}` for a screen's device, or nil to hug.
  """
  attr :tree, :map, required: true
  attr :icons, :map, default: %{}
  attr :size, :any, default: nil

  def frame(assigns) do
    ~H"""
    <div
      class={["wf", @size && "wf-sized"]}
      inert
      style={join([root_size(@tree.place, @size), box(@tree)])}
      {data(@tree)}
    >
      <span :if={@tree.kind == :error} class="wf-error">{@tree.code}</span>
      <.drawn :for={child <- @tree.children} node={child} parent={@tree.layout} icons={@icons} />
    </div>
    """
  end

  defp root_size(_place, {w, h}), do: "width: #{w}px; height: #{h}px"

  defp root_size(place, nil) do
    join([
      if(is_number(place["width"]), do: "width: #{place["width"]}px", else: "width: max-content"),
      is_number(place["height"]) && "height: #{place["height"]}px"
    ])
  end

  defp drawn(%{node: %{kind: :primitive} = node} = assigns) do
    module = Primitives.get(node.use)
    item = Layout.item(node.place, assigns.parent)
    box = if module.interface().children, do: box(node), else: ""

    assigns =
      assign(assigns,
        module: module,
        item: item,
        box: box,
        style: join([item, box])
      )

    ~H"""
    <.primitive
      module={@module}
      props={@node.props}
      unknown={@node.unknown}
      icons={@icons}
      style={@style}
      item={@item}
      box={@box}
      data={data(@node)}
    >
      <.drawn :for={child <- @node.children} node={child} parent={@node.layout} icons={@icons} />
    </.primitive>
    """
  end

  defp drawn(%{node: %{kind: :component} = node} = assigns) do
    assigns = assign(assigns, style: join([Layout.item(node.place, assigns.parent), box(node)]))

    ~H"""
    <div style={@style} {data(@node)}>
      <.drawn :for={child <- @node.children} node={child} parent={@node.layout} icons={@icons} />
    </div>
    """
  end

  defp drawn(%{node: node} = assigns) do
    assigns = assign(assigns, style: Layout.item(node.place, assigns.parent))

    ~H"""
    <div class="wf-error" style={@style} {data(@node)}>{@node.code}</div>
    """
  end

  defp primitive(assigns), do: assigns.module.draw(assigns)

  # What holds an absolute child is what it is placed in, unless it is
  # placed itself.
  defp box(node) do
    join([
      Layout.box(node.layout),
      (node.place["absolute"] != true and
         Enum.any?(node.children, &(&1.place["absolute"] == true))) &&
        "position: relative"
    ])
  end

  # Where a node is written, for the canvas's gestures: the file on show
  # and the chain of ids to it.
  defp data(node) do
    %{
      "data-file" => hd(node.origin).file,
      "data-chain" => node.origin |> Enum.map(& &1.id) |> Enum.reject(&is_nil/1) |> Enum.join("/")
    }
  end

  @doc """
  An icon: its SVG from `icons`, inlined, or a box with its name when it
  isn't there. Decorative unless it has a `label`.
  """
  attr :ref, :any, required: true
  attr :icons, :map, required: true
  attr :label, :any, default: nil
  attr :style, :string, default: nil
  attr :data, :map, default: %{}

  def icon(assigns) do
    label = if present?(assigns.label), do: text(assigns.label)
    svg = is_binary(assigns.ref) && assigns.icons[assigns.ref]
    assigns = assign(assigns, svg: svg, label: label, name: name(assigns.ref))

    ~H"""
    <span
      class={["wf-glyph", !@svg && "wf-missing"]}
      role={@label && "img"}
      aria-label={@label}
      aria-hidden={!@label && "true"}
      title={!@svg && text(@ref)}
      style={@style}
      {@data}
    >
      {if @svg, do: Phoenix.HTML.raw(@svg), else: @name}
    </span>
    """
  end

  defp name(ref) do
    case Icons.parse(ref) do
      {:ok, {_set, name, _style}} -> name
      :error -> "?"
    end
  end

  @doc """
  A value as text to show: a prop is any JSON a spec holds, and drawing
  never raises on it (`resolve-is-total`).
  """
  def text(v) when is_binary(v), do: v
  def text(v) when is_number(v) or is_boolean(v), do: to_string(v)
  def text(_), do: ""

  @doc "Whether a prop has something to show."
  def present?(v), do: v not in [nil, false, "", []]

  @doc "A prop as a list, whatever it holds."
  def list(v) when is_list(v), do: v
  def list(v), do: if(present?(v), do: [v], else: [])

  @doc "A link's or a pressable's `href`: only a path or a web address, never a script."
  def href(to) when is_binary(to) do
    if to =~ ~r{^(/(?!/)|#|https?://)}i, do: to
  end

  def href(_), do: nil

  # CSS declarations joined, the false and empty ones left out.
  defp join(decls), do: decls |> Enum.filter(&(is_binary(&1) and &1 != "")) |> Enum.join("; ")
end
