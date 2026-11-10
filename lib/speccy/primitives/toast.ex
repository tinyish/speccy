defmodule Speccy.Primitives.Toast do
  @moduledoc false

  def interface do
    %{
      name: "toast",
      about:
        "A brief message that pops up about something that just happened, with an optional action.",
      category: "feedback",
      element: "role=status (live region)",
      props: [{"text", "text"}, {"action", "text"}, {"dismissible", "bool"}],
      events: [{"action", nil}, {"close", nil}],
      states: [],
      defaults: %{"dismissible" => true},
      examples: [
        {"basic", %{"text" => "Project archived"}},
        {"with an action", %{"action" => "Undo", "text" => "Project archived"}}
      ],
      children: false,
      slot: false,
      pressable: {:prop, "action"},
      aria: %{}
    }
  end
end
