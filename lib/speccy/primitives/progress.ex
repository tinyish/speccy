defmodule Speccy.Primitives.Progress do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, present?: 1]

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

  def draw(assigns) do
    p = assigns.props
    value = if is_number(p["value"]), do: p["value"] |> max(0) |> min(100)
    busy = p["indeterminate"] == true

    assigns =
      assign(assigns,
        value: value,
        busy: busy,
        fill: if(busy, do: "left: 30%; width: 40%", else: "left: 0; width: #{value || 0}%")
      )

    ~H"""
    <div class="wf-control" style={@style} {@data}>
      <div :if={present?(@props["label"])} class="wf-row">
        <span class="wf-label wf-grow">{text(@props["label"])}</span>
        <span :if={!@busy and @value} class="wf-small">{@value}%</span>
      </div>
      <div
        class="wf-track"
        role="progressbar"
        aria-label={text(@props["label"])}
        aria-valuenow={!@busy && @value}
        aria-valuemin="0"
        aria-valuemax="100"
      >
        <span class="wf-fill" style={@fill}></span>
      </div>
    </div>
    """
  end
end
