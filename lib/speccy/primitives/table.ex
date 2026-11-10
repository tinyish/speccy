defmodule Speccy.Primitives.Table do
  @moduledoc false

  def interface do
    %{
      name: "table",
      about: "Rows and columns of records the user scans, sorts and selects rows in.",
      category: "data-display",
      element: "table",
      props: [{"rows", "model[]"}, {"columns", "text[]"}, {"selectable", "bool"}],
      events: [{"select", "model[]"}],
      states: [],
      defaults: %{"selectable" => false},
      examples: [
        {"basic",
         %{
           "columns" => ["Name", "Email", "Role"],
           "rows" => [
             %{"Email" => "maya@acme.co", "Name" => "Maya Chen", "Role" => "Admin"},
             %{"Email" => "leo@acme.co", "Name" => "Leo Park", "Role" => "Editor"},
             %{"Email" => "ana@acme.co", "Name" => "Ana Ruiz", "Role" => "Viewer"}
           ],
           "selectable" => true
         }}
      ],
      children: false,
      slot: false,
      pressable: {:prop, "selectable"},
      aria: %{}
    }
  end
end
