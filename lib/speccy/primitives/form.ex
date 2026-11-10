defmodule Speccy.Primitives.Form do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  def interface do
    %{
      name: "form",
      about: "Groups inputs the user fills in and submits together.",
      category: "inputs",
      element: "form",
      props: [],
      events: [{"submit", nil}],
      states: [],
      defaults: %{},
      examples: [],
      children: true,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <form style={@style} {@data}>{render_slot(@inner_block)}</form>
    """
  end
end
