defmodule Speccy.Primitives.TreeView do
  @moduledoc false

  use Phoenix.Component

  import Speccy.Draw, only: [text: 1, list: 1]

  def interface do
    %{
      name: "tree-view",
      about:
        "A nested list the user expands and collapses to browse and pick items, like folders.",
      category: "navigation",
      element: "role=tree",
      props: [{"items", "model[]"}, {"value", "model"}, {"expanded", "model[]"}],
      events: [{"select", "model"}, {"toggle", "model"}],
      states: [],
      defaults: %{},
      examples: [
        {"basic",
         %{
           "expanded" => [%{"label" => "src"}, %{"label" => "docs"}],
           "items" => [
             %{
               "children" => [
                 %{"children" => [%{"label" => "Button.tsx"}], "label" => "components"},
                 %{"label" => "index.ts"}
               ],
               "label" => "src"
             },
             %{
               "children" => [%{"label" => "guide.md"}, %{"label" => "faq.md"}],
               "label" => "docs"
             },
             %{"label" => "package.json"}
           ],
           "value" => %{"label" => "index.ts"}
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end

  def draw(assigns) do
    ~H"""
    <ul role="tree" class="wf-tree" style={@style} {@data}>
      <.branch
        items={list(@props["items"])}
        value={@props["value"]}
        expanded={list(@props["expanded"])}
      />
    </ul>
    """
  end

  defp branch(assigns) do
    ~H"""
    <li
      :for={item <- Enum.filter(@items, &is_map/1)}
      role="treeitem"
      aria-expanded={list(item["children"]) != [] && to_string(open?(item, @expanded))}
      aria-selected={to_string(matches?(item, @value))}
    >
      <div class={["wf-option", matches?(item, @value) && "wf-on"]}>
        <span class="wf-mark">
          {if list(item["children"]) != [], do: if(open?(item, @expanded), do: "▾", else: "▸")}
        </span>
        {text(item["label"])}
      </div>
      <ul :if={list(item["children"]) != [] and open?(item, @expanded)} role="group">
        <.branch items={list(item["children"])} value={@value} expanded={@expanded} />
      </ul>
    </li>
    """
  end

  defp open?(item, expanded), do: Enum.any?(expanded, &matches?(item, &1))

  # An item matches a model when it has each of the model's fields.
  defp matches?(item, %{} = model) when map_size(model) > 0,
    do: Enum.all?(model, fn {k, v} -> item[k] == v end)

  defp matches?(_item, _model), do: false
end
