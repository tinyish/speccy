defmodule Speccy.Primitives.Divider do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, present?: 1]

  def interface do
    %{
      name: "divider",
      about: "A line separating content, with an optional label.",
      category: "layout",
      element: "hr",
      props: [{"text", "text"}],
      events: [],
      states: [],
      defaults: %{},
      examples: [{"labelled", %{"text" => "Or"}}],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <hr :if={!present?(@props["text"])} class="wf-divider" style={@style} {@data} />
    <div
      :if={present?(@props["text"])}
      role="separator"
      class="wf-divider-text"
      style={@style}
      {@data}
    >
      {text(@props["text"])}
    </div>
    """
  end
end
