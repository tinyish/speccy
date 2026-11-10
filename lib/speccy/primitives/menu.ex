defmodule Speccy.Primitives.Menu do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, list: 1]

  def interface do
    %{
      name: "menu",
      about:
        "A list of actions or choices the user opens from a button, or by right-clicking an area, and picks one from.",
      category: "overlays",
      element: "role=menu (from a button, or opened by contextmenu on the area it wraps)",
      props: [
        {"items", "text[]"},
        {"value", "text"},
        {"searchable", "bool"},
        {"open", "bool"},
        {"trigger", ["click", "contextmenu"]}
      ],
      events: [{"select", "text"}, {"close", nil}],
      states: [{"open", %{about: "Open, showing its items.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "searchable" => false, "trigger" => "click"},
      examples: [
        {"basic",
         %{"items" => ["Sort by name", "Sort by date", "Sort by size"], "value" => "Sort by date"}}
      ],
      children: true,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <div
      class={["wf-anchor", @props["trigger"] == "contextmenu" && "wf-area"]}
      style={@style}
      {@data}
    >
      <button
        :if={@props["trigger"] != "contextmenu"}
        type="button"
        class={["wf-btn wf-square", @props["open"] == true && "wf-on"]}
        aria-haspopup="menu"
        aria-expanded={to_string(@props["open"] == true)}
        aria-label="Menu"
      >
        ⋯
      </button>
      {render_slot(@inner_block)}
      <div role="menu" class="wf-popup" hidden={@props["open"] != true}>
        <div :if={@props["searchable"] == true} class="wf-option">
          <span class="wf-field wf-grow wf-muted">Search</span>
        </div>
        <div
          :for={item <- list(@props["items"])}
          role="menuitemradio"
          aria-checked={to_string(item == @props["value"])}
          class={["wf-option", item == @props["value"] && "wf-on"]}
        >
          <span class="wf-mark">{if item == @props["value"], do: "✓"}</span>{text(item)}
        </div>
      </div>
    </div>
    """
  end
end
