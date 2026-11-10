defmodule Speccy.Primitives.Select do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1, list: 1]

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

  def draw(assigns) do
    p = assigns.props
    multiple = p["multiple"] == true
    chosen = if multiple, do: list(p["values"]), else: list(p["value"])
    assigns = assign(assigns, multiple: multiple, chosen: chosen)

    ~H"""
    <div class={["wf-control", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <span :if={present?(@props["label"])} class="wf-label">
        {text(@props["label"])}<span :if={@props["required"] == true} aria-hidden="true"> *</span>
      </span>
      <div class="wf-anchor">
        <div
          class="wf-field"
          role="combobox"
          aria-label={text(@props["label"])}
          aria-haspopup="listbox"
          aria-expanded={to_string(@props["open"] == true)}
          aria-required={@props["required"] == true && "true"}
        >
          <span :if={@chosen == []} class="wf-grow wf-muted">{text(@props["placeholder"])}</span>
          <span :if={@chosen != [] and !@multiple} class="wf-grow">{text(hd(@chosen))}</span>
          <span :if={@chosen != [] and @multiple} class="wf-grow wf-row">
            <span :for={value <- @chosen} class="wf-chip">{text(value)}</span>
          </span>
          <span aria-hidden="true">▾</span>
        </div>
        <div
          role="listbox"
          class="wf-popup"
          aria-multiselectable={@multiple && "true"}
          hidden={@props["open"] != true}
        >
          <div :if={@props["searchable"] == true} class="wf-option">
            <span class="wf-field wf-grow wf-muted">Search</span>
          </div>
          <div
            :for={option <- list(@props["options"])}
            role="option"
            aria-selected={to_string(option in @chosen)}
            class={["wf-option", option in @chosen && "wf-on"]}
          >
            <span class="wf-mark">{if option in @chosen, do: "✓"}</span>{text(option)}
          </div>
        </div>
      </div>
      <span :if={present?(@props["hint"])} class="wf-hint">{text(@props["hint"])}</span>
    </div>
    """
  end
end
