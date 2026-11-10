defmodule Speccy.Primitives.Toast do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "toast",
      about:
        "A brief message that pops up about something that just happened, with an optional action.",
      category: "feedback",
      element: "role=status (live region)",
      props: [{"text", "text"}, {"action", "text"}, {"dismissible", "bool"}],
      events: [{"action", nil}, {"close", nil}],
      states: [],
      defaults: %{"dismissible" => true},
      examples: [
        {"basic", %{"text" => "Project archived"}},
        {"with an action", %{"action" => "Undo", "text" => "Project archived"}}
      ],
      children: false,
      slot: false,
      pressable: {:prop, "action"},
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <div role="status" class="wf-surface wf-toast" style={@style} {@data}>
      <span class="wf-grow">{text(@props["text"])}</span>
      <button :if={present?(@props["action"])} type="button" class="wf-btn wf-sm">
        {text(@props["action"])}
      </button>
      <button :if={@props["dismissible"] == true} type="button" aria-label="Dismiss">×</button>
    </div>
    """
  end
end
