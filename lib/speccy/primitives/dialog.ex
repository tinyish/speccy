defmodule Speccy.Primitives.Dialog do
  @moduledoc false

  def interface do
    %{
      name: "dialog",
      about:
        "A window over the page, centred or sliding in from an edge, that asks the user to read, decide or fill something in; modal ones block the page behind a backdrop.",
      category: "overlays",
      element:
        "dialog (modal, with a backdrop) or a non-modal panel; on an edge unless placement is center",
      props: [
        {"open", "bool"},
        {"title", "text"},
        {"text", "text"},
        {"placement", ["center", "left", "right", "bottom"]},
        {"modal", "bool"}
      ],
      events: [{"close", nil}],
      states: [{"open", %{about: "Shown over the page.", props: %{"open" => true}}}],
      defaults: %{"modal" => true, "open" => false, "placement" => "center"},
      examples: [
        {"basic",
         %{
           "text" => "This removes the project and its specs for everyone. You can't undo it.",
           "title" => "Delete project?"
         }}
      ],
      children: true,
      slot: true,
      pressable: false,
      aria: %{}
    }
  end
end
