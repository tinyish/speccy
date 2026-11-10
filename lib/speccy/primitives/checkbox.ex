defmodule Speccy.Primitives.Checkbox do
  @moduledoc false

  def interface do
    %{
      name: "checkbox",
      about: "A box the user ticks, or a switch they flip, to turn one option on or off.",
      category: "selection",
      element: "input type=checkbox (role=switch when role is switch)",
      props: [
        {"role", ["checkbox", "switch"]},
        {"label", "text"},
        {"hint", "text"},
        {"checked", "bool"},
        {"indeterminate", "bool"},
        {"invalid", "bool"},
        {"disabled", "bool"}
      ],
      events: [{"change", "bool"}],
      states: [
        {"checked", %{about: "Ticked, or switched on.", props: %{"checked" => true}}},
        {"indeterminate",
         %{
           about: "Partly ticked: some of the options it stands for are on.",
           props: %{"indeterminate" => true}
         }},
        {"invalid",
         %{about: "Its value is wrong, and the hint says why.", props: %{"invalid" => true}}},
        {"disabled", %{about: "Can't be changed.", props: %{"disabled" => true}}}
      ],
      defaults: %{
        "checked" => false,
        "disabled" => false,
        "indeterminate" => false,
        "invalid" => false,
        "role" => "checkbox"
      },
      examples: [
        {"basic", %{"hint" => "Stay signed in on this device", "label" => "Remember me"}},
        {"switch", %{"label" => "Notifications", "role" => "switch"}}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{"role" => "role"}
    }
  end
end
