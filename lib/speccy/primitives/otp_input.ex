defmodule Speccy.Primitives.OtpInput do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "otp-input",
      about: "Boxes the user types a short verification code into, one digit each.",
      category: "inputs",
      element: "input autocomplete=one-time-code (one box per digit)",
      props: [
        {"label", "text"},
        {"hint", "text"},
        {"length", "number"},
        {"value", "text"},
        {"disabled", "bool"}
      ],
      events: [{"change", "text"}, {"complete", "text"}],
      states: [{"disabled", %{about: "Can't be typed into.", props: %{"disabled" => true}}}],
      defaults: %{"disabled" => false, "length" => 6},
      examples: [
        {"basic",
         %{
           "hint" => "We sent a 6-digit code to your phone.",
           "label" => "Verification code",
           "value" => "4821"
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    p = assigns.props
    # Within reason: a spec's number is drawn, not trusted.
    length = if is_number(p["length"]), do: p["length"] |> trunc() |> max(1) |> min(12), else: 6
    value = text(p["value"])
    assigns = assign(assigns, digits: for(i <- 0..(length - 1), do: String.at(value, i)))

    ~H"""
    <div class={["wf-control", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <span :if={present?(@props["label"])} class="wf-label">{text(@props["label"])}</span>
      <div class="wf-row" role="group" aria-label={text(@props["label"])}>
        <input
          :for={{digit, i} <- Enum.with_index(@digits)}
          class="wf-digit"
          inputmode="numeric"
          maxlength="1"
          autocomplete={i == 0 && "one-time-code"}
          value={digit}
          disabled={@props["disabled"] == true}
        />
      </div>
      <span :if={present?(@props["hint"])} class="wf-hint">{text(@props["hint"])}</span>
    </div>
    """
  end
end
