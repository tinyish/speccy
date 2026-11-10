defmodule Speccy.Primitives.Video do
  @moduledoc false

  def interface do
    %{
      name: "video",
      about: "A video the user plays and pauses.",
      category: "media",
      element: "video",
      props: [{"src", "text"}, {"playing", "bool"}],
      events: [{"play", nil}, {"pause", nil}],
      states: [{"playing", %{about: "Playing.", props: %{"playing" => true}}}],
      defaults: %{"playing" => false},
      examples: [{"basic", %{"src" => "onboarding.mp4"}}],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
