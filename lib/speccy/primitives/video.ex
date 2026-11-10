defmodule Speccy.Primitives.Video do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1]

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

  def draw(assigns) do
    ~H"""
    <div
      role="img"
      aria-label={text(@props["src"])}
      class="wf-media wf-video"
      style={@style}
      {@data}
    >
      <span class="wf-play" aria-hidden="true">
        {if @props["playing"] == true, do: "❚❚", else: "▶︎"}
      </span>
      <span>{text(@props["src"])}</span>
    </div>
    """
  end
end
