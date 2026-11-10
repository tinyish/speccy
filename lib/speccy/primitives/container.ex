defmodule Speccy.Primitives.Container do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "container",
      about:
        "A box that lays out other components. It can be pressed as a whole (a card, a nav item, a tab) and carry a role: a landmark, a tab list or tab panel, a live region.",
      category: "layout",
      element:
        "div (role from role; role=button when pressable, link when it also has href; aria-current from current, aria-selected on a tab, aria-expanded with aria-controls when it controls another container)",
      props: [
        {"pressable", "bool"},
        {"href", "text"},
        {"role",
         [
           "none",
           "navigation",
           "toolbar",
           "tablist",
           "tab",
           "tabpanel",
           "alert",
           "status",
           "group",
           "region"
         ]},
        {"current", ["none", "page", "step"]},
        {"selected", "bool"},
        {"expanded", "bool"},
        {"controls", "text"}
      ],
      events: [{"press", nil}],
      states: [],
      defaults: %{
        "current" => "none",
        "expanded" => false,
        "pressable" => false,
        "role" => "none",
        "selected" => false
      },
      examples: [
        {"card", %{"pressable" => true}},
        {"nav item, current", %{"current" => "page", "pressable" => true}},
        {"tab, selected", %{"pressable" => true, "role" => "tab", "selected" => true}},
        {"navigation", %{"role" => "navigation"}},
        {"alert", %{"role" => "alert"}}
      ],
      children: true,
      slot: true,
      pressable: {:prop, "pressable"},
      aria: %{"controls" => "controls", "current" => "current", "role" => "role"}
    }
  end

  def draw(assigns) do
    p = assigns.props
    pressable = p["pressable"] == true
    controls = present?(p["controls"])

    role =
      cond do
        is_binary(p["role"]) and p["role"] != "none" -> p["role"]
        pressable and present?(p["href"]) -> "link"
        pressable -> "button"
        true -> nil
      end

    on = p["selected"] == true or p["current"] in ~w(page step)
    assigns = assign(assigns, role: role, pressable: pressable, controls: controls, on: on)

    ~H"""
    <div
      role={@role}
      class={[@pressable && "wf-press", @on && "wf-on"]}
      aria-current={@props["current"] in ~w(page step) && @props["current"]}
      aria-selected={@role == "tab" && to_string(@props["selected"] == true)}
      aria-expanded={@controls && to_string(@props["expanded"] == true)}
      aria-controls={@controls && text(@props["controls"])}
      style={@style}
      {@data}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
