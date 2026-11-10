defmodule Speccy.Primitives.DatePicker do
  @moduledoc false

  def interface do
    %{
      name: "date-picker",
      about: "Lets the user pick a date, or a start and end date, from a calendar or by typing.",
      category: "inputs",
      element: "input type=date (with calendar popup)",
      props: [{"label", "text"}, {"value", "text[]"}, {"range", "bool"}, {"open", "bool"}],
      events: [{"change", "text[]"}],
      states: [{"open", %{about: "Its calendar is open.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "range" => false},
      examples: [{"basic", %{"label" => "Due date", "value" => ["2026-11-14"]}}],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
