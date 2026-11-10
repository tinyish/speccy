defmodule Speccy.Primitives.Link do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1]
  alias Speccy.Draw

  def interface do
    %{
      name: "link",
      about: "Text or a badge the user follows to another page or site.",
      category: "navigation",
      element: "a",
      props: [{"text", "text"}, {"to", "text"}],
      events: [{"press", nil}],
      states: [],
      defaults: %{},
      examples: [{"basic", %{"text" => "Read the docs", "to" => "/docs"}}],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <a
      class="wf-link"
      href={Draw.href(@props["to"])}
      title={text(@props["to"])}
      style={@style}
      {@data}
    >
      {text(@props["text"])}
    </a>
    """
  end
end
