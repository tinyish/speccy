defmodule Speccy.Primitives.Menu do
  @moduledoc false

  def interface do
    %{
      name: "menu",
      about:
        "A list of actions or choices the user opens from a button, or by right-clicking an area, and picks one from.",
      category: "overlays",
      element: "role=menu (from a button, or opened by contextmenu on the area it wraps)",
      props: [
        {"items", "text[]"},
        {"value", "text"},
        {"searchable", "bool"},
        {"open", "bool"},
        {"trigger", ["click", "contextmenu"]}
      ],
      events: [{"select", "text"}, {"close", nil}],
      states: [{"open", %{about: "Open, showing its items.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "searchable" => false, "trigger" => "click"},
      examples: [
        {"basic",
         %{"items" => ["Sort by name", "Sort by date", "Sort by size"], "value" => "Sort by date"}}
      ],
      children: true,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end
end
