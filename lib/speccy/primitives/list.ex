defmodule Speccy.Primitives.List do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  def interface do
    %{
      name: "list",
      about: "A column of items the user scans, selects, reorders or swipes for actions.",
      category: "data-display",
      element: "ul",
      props: [{"selectable", "bool"}, {"reorderable", "bool"}, {"selected", "bool"}],
      events: [{"select", "text"}, {"reorder", "text[]"}, {"swipe", "text"}],
      states: [
        {"selected",
         %{about: "An item is selected.", props: %{"selectable" => true, "selected" => true}}}
      ],
      defaults: %{"reorderable" => false, "selectable" => false, "selected" => false},
      examples: [],
      children: true,
      slot: true,
      pressable: {:prop, "selectable"},
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <ul
      role={@props["selectable"] == true && "listbox"}
      class={(@props["selectable"] == true and @props["selected"] == true) && "wf-picked"}
      style={@style}
      {@data}
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end
end
