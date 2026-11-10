defmodule Speccy.Primitives.Text do
  @moduledoc false

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
end
