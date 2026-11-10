defmodule Speccy.Primitives.Slider do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1]

  def interface do
    %{
      name: "slider",
      about:
        "A handle the user drags along a track to set one number, or two handles, when range, to set a low and a high one.",
      category: "inputs",
      element: "input type=range (two role=slider handles on one track when range)",
      props: [
        {"label", "text"},
        {"range", "bool"},
        {"value", "number"},
        {"start", "number"},
        {"end", "number"},
        {"min", "number"},
        {"max", "number"},
        {"step", "number"},
        {"disabled", "bool"}
      ],
      events: [{"change", "number"}, {"changeStart", "number"}, {"changeEnd", "number"}],
      states: [{"disabled", %{about: "Can't be dragged.", props: %{"disabled" => true}}}],
      defaults: %{"disabled" => false, "max" => 100, "min" => 0, "range" => false, "step" => 1},
      examples: [
        {"basic", %{"label" => "Volume", "step" => 10, "value" => 60}},
        {"range", %{"end" => 80, "label" => "Price", "range" => true, "start" => 20}}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    p = assigns.props
    min = num(p["min"], 0)
    max = num(p["max"], 100)

    at = fn v ->
      if max > min,
        do: Float.round((num(v, min) - min) / (max - min) * 100, 2) |> max(0.0) |> min(100.0),
        else: 0.0
    end

    thumbs =
      if p["range"] == true,
        do: [{p["start"], at.(p["start"])}, {p["end"], at.(p["end"])}],
        else: [{p["value"], at.(p["value"])}]

    {from, to} =
      if p["range"] == true, do: {at.(p["start"]), at.(p["end"])}, else: {0.0, at.(p["value"])}

    assigns =
      assign(assigns,
        min: min,
        max: max,
        thumbs: thumbs,
        fill: "left: #{from}%; width: #{max(to - from, 0)}%"
      )

    ~H"""
    <div class={["wf-control", @props["disabled"] == true && "wf-off"]} style={@style} {@data}>
      <div class="wf-row">
        <span class="wf-label wf-grow">{text(@props["label"])}</span>
        <span class="wf-small">{@thumbs |> Enum.map(&text(elem(&1, 0))) |> Enum.join(" – ")}</span>
      </div>
      <div class="wf-track">
        <span class="wf-fill" style={@fill}></span>
        <span
          :for={{value, at} <- @thumbs}
          class="wf-thumb"
          role="slider"
          aria-label={text(@props["label"])}
          aria-valuenow={text(value)}
          aria-valuemin={@min}
          aria-valuemax={@max}
          style={"left: #{at}%"}
        ></span>
      </div>
    </div>
    """
  end

  defp num(v, _default) when is_number(v), do: v
  defp num(_v, default), do: default
end
