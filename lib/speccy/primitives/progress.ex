defmodule Speccy.Primitives.Progress do
  @moduledoc false

  def interface do
    %{
      name: "progress",
      about: "Shows how far along a task is, or that something is loading when it can't say.",
      category: "feedback",
      element: "progress",
      props: [{"label", "text"}, {"value", "number"}, {"indeterminate", "bool"}],
      events: [],
      states: [
        {"indeterminate",
         %{about: "Loading, with no way to say how far along.", props: %{"indeterminate" => true}}}
      ],
      defaults: %{"indeterminate" => false},
      examples: [{"basic", %{"label" => "Uploading files", "value" => 60}}],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end
end
