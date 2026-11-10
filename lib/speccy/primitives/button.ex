defmodule Speccy.Primitives.Button do
  @moduledoc false

  def interface do
    %{
      name: "button",
      about:
        "A control the user presses to run an action. It can stay selected like a toggle, carry a menu of related actions, or be removed, so small buttons also cover tags, chips and badges.",
      category: "actions",
      element:
        "button (aria-pressed when selected; icon-only when it has no text, named by label; plus a menu button, aria-haspopup=menu, when it has options; plus a remove button when removable)",
      props: [
        {"text", "text"},
        {"label", "text"},
        {"leadingIcon", "icon"},
        {"trailingIcon", "icon"},
        {"size", ["sm", "md", "lg"]},
        {"selected", "bool"},
        {"disabled", "bool"},
        {"options", "text[]"},
        {"open", "bool"},
        {"removable", "bool"}
      ],
      events: [{"press", nil}, {"select", "text"}, {"remove", nil}],
      states: [
        {"selected",
         %{about: "Stays pressed, like a toggle that is on.", props: %{"selected" => true}}},
        {"disabled", %{about: "Can't be pressed.", props: %{"disabled" => true}}},
        {"open",
         %{
           about: "Its menu of related actions is open.",
           props: %{
             "open" => true,
             "options" => ["Save as draft", "Save and close", "Save a copy"]
           }
         }}
      ],
      defaults: %{
        "disabled" => false,
        "open" => false,
        "removable" => false,
        "selected" => false,
        "size" => "md"
      },
      examples: [
        {"basic", %{"text" => "Save changes"}},
        {"small", %{"size" => "sm", "text" => "Save"}},
        {"large", %{"size" => "lg", "text" => "Save changes"}},
        {"with icons",
         %{
           "leadingIcon" => "material/save",
           "text" => "Save changes",
           "trailingIcon" => "material/expand_more"
         }},
        {"icon only", %{"label" => "Favourite", "leadingIcon" => "material/favorite"}},
        {"icon only selected",
         %{"label" => "Favourite", "leadingIcon" => "material/favorite", "selected" => true}},
        {"removable tag", %{"removable" => true, "size" => "sm", "text" => "Design"}}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
