defmodule Speccy.Primitives.Select do
  @moduledoc false

  def interface do
    %{
      name: "select",
      about: "A field the user opens to pick one option, or several when multiple, from a list.",
      category: "selection",
      element: "select (role=listbox aria-multiselectable in a popup when multiple)",
      props: [
        {"label", "text"},
        {"hint", "text"},
        {"placeholder", "text"},
        {"options", "text[]"},
        {"multiple", "bool"},
        {"value", "text"},
        {"values", "text[]"},
        {"required", "bool"},
        {"searchable", "bool"},
        {"open", "bool"},
        {"disabled", "bool"}
      ],
      events: [{"change", "text[]"}],
      states: [
        {"open", %{about: "Open, showing its options.", props: %{"open" => true}}},
        {"disabled", %{about: "Can't be changed.", props: %{"disabled" => true}}}
      ],
      defaults: %{
        "disabled" => false,
        "multiple" => false,
        "open" => false,
        "required" => false,
        "searchable" => false
      },
      examples: [
        {"basic",
         %{
           "hint" => "Where you'll ship from",
           "label" => "Country",
           "options" => ["Chile", "Mexico", "Spain", "Portugal"],
           "placeholder" => "Choose a country",
           "required" => true,
           "value" => "Chile"
         }},
        {"multiple",
         %{
           "label" => "Countries",
           "multiple" => true,
           "options" => ["Chile", "Mexico", "Spain", "Portugal"],
           "values" => ["Chile", "Spain"]
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
