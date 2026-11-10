defmodule Speccy.Primitives.Link do
  @moduledoc false

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
end
