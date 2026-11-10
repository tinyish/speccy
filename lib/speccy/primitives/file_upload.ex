defmodule Speccy.Primitives.FileUpload do
  @moduledoc false

  def interface do
    %{
      name: "file-upload",
      about:
        "A drop zone the user drags files onto or browses from, listing queued files with progress.",
      category: "inputs",
      element: "input type=file (with drop zone)",
      props: [{"accept", "text"}, {"multiple", "bool"}, {"files", "text[]"}, {"disabled", "bool"}],
      events: [{"change", "text[]"}, {"remove", "text"}],
      states: [],
      defaults: %{"disabled" => false, "multiple" => false},
      examples: [
        {"basic",
         %{
           "accept" => ".pdf, .png, .jpg",
           "files" => ["brief.pdf", "hero.png", "moodboard.jpg"],
           "multiple" => true
         }}
      ],
      children: false,
      slot: false,
      pressable: true,
      aria: %{}
    }
  end
end
