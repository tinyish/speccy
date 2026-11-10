defmodule Speccy.Primitives.Input do
  @moduledoc false

  def interface do
    %{
      name: "input",
      about: "A field the user types a value into, on one line or, when multiline, several.",
      category: "inputs",
      element: "input (textarea when multiline)",
      props: [
        {"type", ["text", "password", "number", "date", "time", "color"]},
        {"multiline", "bool"},
        {"label", "text"},
        {"hint", "text"},
        {"placeholder", "text"},
        {"value", "text"},
        {"required", "bool"},
        {"invalid", "bool"},
        {"disabled", "bool"}
      ],
      events: [{"change", "text"}],
      states: [
        {"invalid",
         %{
           about: "Its value is wrong or missing, and the hint says why.",
           props: %{"hint" => "Enter your full name.", "invalid" => true, "value" => ""}
         }},
        {"disabled", %{about: "Can't be typed into.", props: %{"disabled" => true}}}
      ],
      defaults: %{
        "disabled" => false,
        "invalid" => false,
        "multiline" => false,
        "required" => false,
        "type" => "text"
      },
      examples: [
        {"basic",
         %{
           "hint" => "As it appears on your ID.",
           "label" => "Full name",
           "placeholder" => "e.g. Ada Lovelace",
           "required" => true,
           "value" => "Ada Lovelace"
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
