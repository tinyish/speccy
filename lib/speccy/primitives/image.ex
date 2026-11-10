defmodule Speccy.Primitives.Image do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "image",
      about:
        "A picture, with a fallback (such as initials) shown when it has no source or it fails to load.",
      category: "media",
      element: "img (fallback when there is no src or it fails)",
      props: [{"src", "text"}, {"alt", "text"}, {"fallback", "text"}],
      events: [],
      states: [
        {"broken",
         %{
           about: "Has no source, or it failed to load, so it shows its fallback.",
           props: %{"src" => ""}
         }}
      ],
      defaults: %{},
      examples: [
        {"basic", %{"alt" => "Maya Chen", "fallback" => "MC", "src" => "photos/maya-chen.jpg"}}
      ],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <div
      role="img"
      aria-label={text(@props["alt"])}
      class={["wf-media", !present?(@props["src"]) && "wf-fallback"]}
      title={text(@props["src"])}
      style={@style}
      {@data}
    >
      {if present?(@props["src"]), do: text(@props["alt"]), else: text(@props["fallback"])}
    </div>
    """
  end
end
