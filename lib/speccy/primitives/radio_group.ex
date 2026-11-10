defmodule Speccy.Primitives.RadioGroup do
  @moduledoc false

  def interface do
    %{
      name: "radio-group",
      about:
        "A set of options the user picks exactly one of, as radios or a row of joined buttons.",
      category: "selection",
      element: "role=radiogroup of input type=radio (or of buttons, as a segmented control)",
      props: [
        {"label", "text"},
        {"options", "text[]"},
        {"value", "text"},
        {"orientation", ["vertical", "horizontal"]},
        {"disabled", "bool"}
      ],
      events: [{"change", "text"}],
      states: [{"disabled", %{about: "Can't be changed.", props: %{"disabled" => true}}}],
      defaults: %{"disabled" => false, "orientation" => "vertical"},
      examples: [
        {"basic",
         %{
           "label" => "Delivery",
           "options" => ["Standard", "Express", "Pickup"],
           "value" => "Express"
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
