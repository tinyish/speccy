defmodule Speccy.Primitives.OtpInput do
  @moduledoc false

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
end
