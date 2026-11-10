defmodule Speccy.Devices do
  @moduledoc """
  speccy's device presets (`format.md` § Devices), each a real device, with
  the fields a spec's own devices have. Sizes are logical pixels (points,
  dp), in the device's first orientation. The presets are refreshed with
  speccy's releases.
  """

  @presets [
    {"iphone-18-pro",
     %{
       "about" => "Apple iPhone 18 Pro.",
       "width" => 402,
       "height" => 874,
       "cornerRadius" => 62,
       "input" => ["touch"],
       "safeArea" => [62, 0, 34, 0],
       "orientations" => ["portrait", "landscape"]
     }},
    {"iphone-18-pro-max",
     %{
       "about" => "Apple iPhone 18 Pro Max.",
       "width" => 440,
       "height" => 956,
       "cornerRadius" => 62,
       "input" => ["touch"],
       "safeArea" => [62, 0, 34, 0],
       "orientations" => ["portrait", "landscape"]
     }},
    {"pixel-11-pro",
     %{
       "about" => "Google Pixel 11 Pro.",
       "width" => 412,
       "height" => 915,
       "cornerRadius" => 40,
       "input" => ["touch"],
       "safeArea" => [32, 0, 24, 0],
       "orientations" => ["portrait", "landscape"]
     }},
    {"galaxy-s26",
     %{
       "about" => "Samsung Galaxy S26.",
       "width" => 360,
       "height" => 780,
       "cornerRadius" => 36,
       "input" => ["touch"],
       "safeArea" => [32, 0, 24, 0],
       "orientations" => ["portrait", "landscape"]
     }},
    {"ipad-pro-13",
     %{
       "about" => "Apple iPad Pro 13-inch (M5).",
       "width" => 1032,
       "height" => 1376,
       "cornerRadius" => 18,
       "input" => ["touch", "pointer", "keyboard"],
       "safeArea" => [24, 0, 20, 0],
       "orientations" => ["portrait", "landscape"]
     }},
    {"macbook-pro-14",
     %{
       "about" => "Apple MacBook Pro 14-inch (M6), at its default scaled resolution.",
       "width" => 1512,
       "height" => 982,
       "cornerRadius" => [10, 10, 0, 0],
       "input" => ["pointer", "keyboard"],
       "safeArea" => [32, 0, 0, 0],
       "orientations" => ["landscape"]
     }},
    {"studio-display",
     %{
       "about" => "Apple Studio Display, 27-inch 5K, at its default scaled resolution.",
       "width" => 2560,
       "height" => 1440,
       "input" => ["pointer", "keyboard"],
       "orientations" => ["landscape"]
     }},
    {"apple-watch-series-12",
     %{
       "about" => "Apple Watch Series 12, 46 mm.",
       "width" => 208,
       "height" => 248,
       "cornerRadius" => 45,
       "input" => ["touch", "rotary"],
       "orientations" => ["portrait"]
     }},
    {"pixel-watch-5",
     %{
       "about" => "Google Pixel Watch 5, 45 mm: a round Wear OS watch.",
       "width" => 228,
       "height" => 228,
       "shape" => "round",
       "input" => ["touch", "rotary"],
       "orientations" => ["portrait"]
     }},
    {"apple-tv-4k",
     %{
       "about" =>
         "Apple TV 4K, on a TV: tvOS lays out at 1080p, inside a safe area for overscan.",
       "width" => 1920,
       "height" => 1080,
       "input" => ["dpad", "gamepad", "voice"],
       "safeArea" => [60, 80],
       "orientations" => ["landscape"]
     }}
  ]

  @doc "Every preset as `{name, device}`, in order."
  def all, do: @presets

  @doc "The preset called `name`, or nil."
  def get(name), do: List.keyfind(@presets, name, 0) |> then(&(&1 && elem(&1, 1)))
end
