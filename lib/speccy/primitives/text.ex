defmodule Speccy.Primitives.Text do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1]

  def interface do
    %{
      name: "text",
      about: "A piece of text.",
      category: "data-display",
      element: "p",
      props: [{"text", "text"}],
      events: [],
      states: [],
      defaults: %{},
      examples: [{"basic", %{"text" => "Your changes are saved automatically."}}],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <p style={@style} {@data}>{text(@props["text"])}</p>
    """
  end
end
