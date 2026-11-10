defmodule Speccy.Primitives.Icon do
  @moduledoc false

  use Phoenix.Component

  alias Speccy.Draw

  def interface do
    %{
      name: "icon",
      about:
        "One glyph, decorative unless it has a label, which names it for assistive tech. It is not pressable: a pressable icon is an icon-only button.",
      category: "media",
      element: "svg (aria-hidden; role=img named by label when it has one)",
      props: [{"icon", "icon"}, {"label", "text"}],
      events: [],
      states: [],
      defaults: %{},
      examples: [
        {"basic", %{"icon" => "material/star"}},
        {"labelled", %{"icon" => "material/warning", "label" => "Warning"}},
        {"filled", %{"icon" => "material/star:filled"}}
      ],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <Draw.icon
      ref={@props["icon"]}
      icons={@icons}
      label={@props["label"]}
      style={@style}
      data={@data}
    />
    """
  end
end
