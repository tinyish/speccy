defmodule Speccy.Primitives.Popover do
  @moduledoc false

  def interface do
    %{
      name: "popover",
      about:
        "A small panel anchored to a control: opened by a click, with text and actions, until the user dismisses it; or, on hover or focus, a short tooltip.",
      category: "overlays",
      element: "[popover] role=dialog (non-modal); role=tooltip when trigger is hover",
      props: [
        {"title", "text"},
        {"text", "text"},
        {"open", "bool"},
        {"trigger", ["click", "hover"]}
      ],
      events: [{"close", nil}],
      states: [{"open", %{about: "Shown beside its control.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "trigger" => "click"},
      examples: [
        {"basic",
         %{"text" => "Invite your team to edit this spec with you.", "title" => "Shared specs"}}
      ],
      children: true,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end
end
