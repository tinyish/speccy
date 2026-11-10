defmodule Speccy.Primitives.Image do
  @moduledoc false

  def interface do
    %{
      name: "image",
      about:
        "A picture, with a fallback (such as initials) shown when it has no source or it fails to load.",
      category: "media",
      element: "img (fallback when there is no src or it fails)",
      props: [{"src", "text"}, {"alt", "text"}, {"fallback", "text"}],
      events: [],
      states: [
        {"broken",
         %{
           about: "Has no source, or it failed to load, so it shows its fallback.",
           props: %{"src" => ""}
         }}
      ],
      defaults: %{},
      examples: [
        {"basic", %{"alt" => "Maya Chen", "fallback" => "MC", "src" => "photos/maya-chen.jpg"}}
      ],
      children: false,
      slot: false,
      pressable: false,
      aria: %{}
    }
  end
end
