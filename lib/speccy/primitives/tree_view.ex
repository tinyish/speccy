defmodule Speccy.Primitives.TreeView do
  @moduledoc false

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
end
