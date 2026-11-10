defmodule Speccy.DevicesTest do
  use ExUnit.Case, async: true

  alias Speccy.{Devices, Schemas}

  test "the presets: real devices only, each a device a spec could define" do
    names = Enum.map(Devices.all(), &elem(&1, 0))

    assert names ==
             ~w(iphone-18-pro iphone-18-pro-max pixel-11-pro galaxy-s26 ipad-pro-13 macbook-pro-14 studio-display apple-watch-series-12 pixel-watch-5 apple-tv-4k)

    root = JSV.build!(Schemas.build("manifest"))

    manifest = %{
      "$schema" => Schemas.url("manifest"),
      "format" => 1,
      "devices" => Map.new(Devices.all())
    }

    assert {:ok, _} = JSV.validate(manifest, root)
  end

  test "apple-tv-4k is a 1080p landscape screen for remote and controller, inside tvOS's safe area" do
    assert %{
             "width" => 1920,
             "height" => 1080,
             "input" => ["dpad", "gamepad", "voice"],
             "safeArea" => [60, 80]
           } =
             Devices.get("apple-tv-4k")
  end
end
