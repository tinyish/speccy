defmodule Speccy.Primitives.DatePicker do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, present?: 1, list: 1]

  def interface do
    %{
      name: "date-picker",
      about: "Lets the user pick a date, or a start and end date, from a calendar or by typing.",
      category: "inputs",
      element: "input type=date (with calendar popup)",
      props: [{"label", "text"}, {"value", "text[]"}, {"range", "bool"}, {"open", "bool"}],
      events: [{"change", "text[]"}],
      states: [{"open", %{about: "Its calendar is open.", props: %{"open" => true}}}],
      defaults: %{"open" => false, "range" => false},
      examples: [{"basic", %{"label" => "Due date", "value" => ["2026-11-14"]}}],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    value = list(assigns.props["value"])
    assigns = assign(assigns, value: Enum.map(value, &text/1), month: month(value))

    ~H"""
    <div class="wf-control" style={@style} {@data}>
      <span :if={present?(@props["label"])} class="wf-label">{text(@props["label"])}</span>
      <div class="wf-anchor">
        <div
          class="wf-field"
          role="combobox"
          aria-label={text(@props["label"])}
          aria-haspopup="dialog"
          aria-expanded={to_string(@props["open"] == true)}
        >
          <span :if={@value != []} class="wf-grow">{Enum.join(@value, " – ")}</span>
          <span :if={@value == []} class="wf-grow wf-muted">
            {if @props["range"] == true, do: "YYYY-MM-DD – YYYY-MM-DD", else: "YYYY-MM-DD"}
          </span>
          <span aria-hidden="true">▦</span>
        </div>
        <div role="dialog" class="wf-popup" hidden={@props["open"] != true}>
          <div class="wf-month">
            <span class="wf-strong">{@month.title}</span>
            <span :for={_ <- List.duplicate(nil, @month.offset)}></span>
            <span :for={day <- 1..@month.days} class={day in @month.on && "wf-on"}>{day}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # The month of the first date, with the days the value covers in it.
  defp month(value) do
    case Enum.map(value, &(is_binary(&1) && Date.from_iso8601(&1))) do
      [{:ok, first} | rest] ->
        start = Date.beginning_of_month(first)
        last = List.last([first | for({:ok, d} <- rest, do: d)])

        %{
          title: Calendar.strftime(first, "%B %Y"),
          offset: Date.day_of_week(start) - 1,
          days: Date.days_in_month(first),
          on:
            for(
              d <- Date.range(first, Enum.max([first, last], Date)),
              d.month == first.month and d.year == first.year,
              do: d.day
            )
        }

      _ ->
        %{title: "", offset: 0, days: 30, on: []}
    end
  end
end
