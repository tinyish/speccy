defmodule Speccy.Primitives.Form do
  @moduledoc false

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
end
