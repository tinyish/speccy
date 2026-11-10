defmodule Speccy.Primitives.Slider do
  @moduledoc false

  def interface do
    %{
      name: "slider",
      about:
        "A handle the user drags along a track to set one number, or two handles, when range, to set a low and a high one.",
      category: "inputs",
      element: "input type=range (two role=slider handles on one track when range)",
      props: [
        {"label", "text"},
        {"range", "bool"},
        {"value", "number"},
        {"start", "number"},
        {"end", "number"},
        {"min", "number"},
        {"max", "number"},
        {"step", "number"},
        {"disabled", "bool"}
      ],
      events: [{"change", "number"}, {"changeStart", "number"}, {"changeEnd", "number"}],
      states: [{"disabled", %{about: "Can't be dragged.", props: %{"disabled" => true}}}],
      defaults: %{"disabled" => false, "max" => 100, "min" => 0, "range" => false, "step" => 1},
      examples: [
        {"basic", %{"label" => "Volume", "step" => 10, "value" => 60}},
        {"range", %{"end" => 80, "label" => "Price", "range" => true, "start" => 20}}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
