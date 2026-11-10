defmodule Speccy.Primitives.Divider do
  @moduledoc false

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
end
