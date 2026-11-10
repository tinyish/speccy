defmodule Speccy.Primitives.RadioGroup do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, present?: 1, list: 1]

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

  def draw(assigns) do
    ~H"""
    <div
      role="radiogroup"
      aria-label={text(@props["label"])}
      class={["wf-control", @props["disabled"] == true && "wf-off"]}
      style={@style}
      {@data}
    >
      <span :if={present?(@props["label"])} class="wf-label">{text(@props["label"])}</span>
      <div class={if @props["orientation"] == "horizontal", do: "wf-row", else: "wf-col"}>
        <label :for={option <- list(@props["options"])} class="wf-choice">
          <input
            type="radio"
            class="wf-radio"
            checked={option == @props["value"]}
            disabled={@props["disabled"] == true}
          />
          <span>{text(option)}</span>
        </label>
      </div>
    </div>
    """
  end
end
