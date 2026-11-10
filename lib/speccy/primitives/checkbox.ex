defmodule Speccy.Primitives.Checkbox do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, present?: 1]

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

  def draw(assigns) do
    ~H"""
    <label class={["wf-choice", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <input
        type="checkbox"
        role={@props["role"] == "switch" && "switch"}
        class={[
          if(@props["role"] == "switch", do: "wf-switch", else: "wf-check"),
          @props["indeterminate"] == true && "wf-mixed",
          @props["invalid"] == true && "wf-invalid"
        ]}
        checked={@props["checked"] == true}
        disabled={@props["disabled"] == true}
        aria-checked={@props["indeterminate"] == true && "mixed"}
        aria-invalid={@props["invalid"] == true && "true"}
      />
      <span :if={present?(@props["label"]) or present?(@props["hint"])} class="wf-control">
        <span>{text(@props["label"])}</span>
        <span :if={present?(@props["hint"])} class="wf-hint">{text(@props["hint"])}</span>
      </span>
    </label>
    """
  end
end
