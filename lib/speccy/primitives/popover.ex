defmodule Speccy.Primitives.Popover do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "popover",
      about:
        "A small panel anchored to a control: opened by a click, with text and actions, until the user dismisses it; or, on hover or focus, a short tooltip.",
      category: "overlays",
      element: "[popover] role=dialog (non-modal); role=tooltip when trigger is hover",
      props: [
        {"title", "text"},
        {"text", "text"},
        {"open", "bool"},
        {"trigger", ["click", "hover"]}
      ],
      events: [{"close", nil}],
      states: [{"open", %{about: "Shown beside its control.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "trigger" => "click"},
      examples: [
        {"basic",
         %{"text" => "Invite your team to edit this spec with you.", "title" => "Shared specs"}}
      ],
      children: true,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <div class="wf-anchor" style={@item} {@data}>
      <button
        type="button"
        class={["wf-btn wf-square", @props["open"] == true && "wf-on"]}
        aria-expanded={@props["trigger"] != "hover" && to_string(@props["open"] == true)}
        aria-label={text(@props["title"])}
      >
        {if @props["trigger"] == "hover", do: "?", else: "ⓘ"}
      </button>
      <div
        role={if @props["trigger"] == "hover", do: "tooltip", else: "dialog"}
        aria-label={text(@props["title"])}
        class={["wf-popup wf-surface", @props["trigger"] == "hover" && "wf-tooltip"]}
        hidden={@props["open"] != true}
      >
        <span :if={present?(@props["title"])} class="wf-strong">{text(@props["title"])}</span>
        <p :if={present?(@props["text"])}>{text(@props["text"])}</p>
        <div style={@box}>{render_slot(@inner_block)}</div>
      </div>
    </div>
    """
  end
end
