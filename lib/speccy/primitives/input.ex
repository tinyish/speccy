defmodule Speccy.Primitives.Input do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, present?: 1]

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

  def draw(assigns) do
    ~H"""
    <div class={["wf-control", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <span :if={present?(@props["label"])} class="wf-label">
        {text(@props["label"])}<span :if={@props["required"] == true} aria-hidden="true"> *</span>
      </span>
      <textarea
        :if={@props["multiline"] == true}
        class={["wf-field", @props["invalid"] == true && "wf-invalid"]}
        aria-label={text(@props["label"])}
        placeholder={text(@props["placeholder"])}
        required={@props["required"] == true}
        disabled={@props["disabled"] == true}
        aria-invalid={@props["invalid"] == true && "true"}
      >{text(@props["value"])}</textarea>
      <div
        :if={@props["multiline"] != true}
        class={["wf-field", @props["invalid"] == true && "wf-invalid"]}
      >
        <input
          type={
            if @props["type"] in ~w(text password number date time color),
              do: @props["type"],
              else: "text"
          }
          aria-label={text(@props["label"])}
          value={text(@props["value"])}
          placeholder={text(@props["placeholder"])}
          required={@props["required"] == true}
          disabled={@props["disabled"] == true}
          aria-invalid={@props["invalid"] == true && "true"}
        />
      </div>
      <span :if={present?(@props["hint"])} class="wf-hint">{text(@props["hint"])}</span>
    </div>
    """
  end
end
