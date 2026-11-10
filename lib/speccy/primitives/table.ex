defmodule Speccy.Primitives.Table do
  @moduledoc false

  use Phoenix.Component

  @debug_heex_annotations false
  @debug_attributes false

  import Speccy.Draw, only: [text: 1, list: 1]

  def interface do
    %{
      name: "table",
      about: "Rows and columns of records the user scans, sorts and selects rows in.",
      category: "data-display",
      element: "table",
      props: [{"rows", "model[]"}, {"columns", "text[]"}, {"selectable", "bool"}],
      events: [{"select", "model[]"}],
      states: [],
      defaults: %{"selectable" => false},
      examples: [
        {"basic",
         %{
           "columns" => ["Name", "Email", "Role"],
           "rows" => [
             %{"Email" => "maya@acme.co", "Name" => "Maya Chen", "Role" => "Admin"},
             %{"Email" => "leo@acme.co", "Name" => "Leo Park", "Role" => "Editor"},
             %{"Email" => "ana@acme.co", "Name" => "Ana Ruiz", "Role" => "Viewer"}
           ],
           "selectable" => true
         }}
      ],
      children: false,
      slot: false,
      pressable: {:prop, "selectable"},
      aria: %{}
    }
  end

  def draw(assigns) do
    p = assigns.props
    # Rows with nothing to show yet draw as three blank ones.
    rows = if "rows" in assigns.unknown, do: [:blank, :blank, :blank], else: list(p["rows"])
    columns = list(p["columns"])

    columns =
      if columns == [],
        do: rows |> Enum.find(%{}, &is_map/1) |> Map.keys() |> Enum.sort(),
        else: columns

    assigns = assign(assigns, rows: rows, columns: columns)

    ~H"""
    <table class="wf-table" style={@style} {@data}>
      <thead>
        <tr>
          <th :if={@props["selectable"] == true}>
            <input type="checkbox" class="wf-check" aria-label="Select all" />
          </th>
          <th :for={column <- @columns}>{text(column)}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={row <- @rows}>
          <td :if={@props["selectable"] == true}>
            <input type="checkbox" class="wf-check" aria-label="Select row" />
          </td>
          <td :for={column <- @columns}>
            <span :if={row == :blank} class="wf-blank"></span>
            {if is_map(row), do: text(row[column])}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end
end
