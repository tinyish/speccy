defmodule Speccy.Primitives.List do
  @moduledoc false

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
end
