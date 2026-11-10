defmodule Speccy.SpecTest do
  use ExUnit.Case, async: true

  alias Speccy.{Format, Spec}

  test "frames are the base, then each state, in the file's order" do
    spec = Spec.new(Format.load("test/fixtures/specs/tasks"))

    assert Spec.frames(spec, "screens/TaskScreen.json") == [
             {nil, []},
             {"loading", []},
             {"empty", []},
             {"problem", ["offline", "error"]}
           ]

    assert Spec.frames(spec, "screens/Nope.json") == []
  end
end
