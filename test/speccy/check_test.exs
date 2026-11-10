defmodule Speccy.CheckTest do
  use ExUnit.Case, async: true

  alias Speccy.{Check, Format}

  @specs "test/fixtures/specs"

  defp check(name), do: Check.run(Format.load(Path.join(@specs, name)))
  defp found(name), do: Enum.map(check(name), &{&1.code, &1.file, &1.path})

  # Every problem each broken fixture holds, as {code, file, path}.
  @broken %{
    "broken-files" => [
      {:"name-mismatch", "components/Banner.json", "/component"},
      {:"invalid-json", "components/Broken.json", ""},
      {:"duplicate-key", "components/Echo.json", "/props/label"},
      {:"invalid-json", "components/Folder.json", ""},
      {:"duplicate-name", "components/Twin.json", "/component"},
      {:"duplicate-name", "data/Twin.json", "/data"},
      {:"unknown-orientation", "screens/Board.json", "/orientation"},
      {:"unknown-device", "screens/Wall.json", "/device"},
      {:"device-is-preset", "speccy.json", "/devices/iphone-18-pro"},
      {:"unknown-format", "speccy.json", "/format"}
    ],
    # The manifest fails its schema, so the screen on its device isn't checked
    # against it.
    "broken-schema" => [
      {:"wrong-schema", "components/Bad.json", "/$schema"},
      {:"missing-key", "components/Bad.json", "/about"},
      {:"bad-name", "components/Bad.json", "/children/0/id"},
      {:"bad-name", "components/Bad.json", "/children/0/use"},
      {:"bad-value", "components/Bad.json", "/children/0/width"},
      {:"unknown-key", "components/Bad.json", "/colour"},
      {:"missing-key", "components/Bad.json", "/component"},
      {:"unknown-type", "components/Bad.json", "/props/x"},
      {:"missing-key", "speccy.json", "/devices/wall/height"}
    ],
    # A screen and a data model are no component to use, and a component or a
    # screen no type.
    "broken-refs" => [
      {:"unknown-type", "components/Row.json", "/props/home"},
      {:"prop-type", "components/Row.json", "/props/note/default"},
      {:"unknown-type", "components/Row.json", "/props/owner"},
      {:"unknown-use", "screens/Board.json", "/children/0/use"},
      {:"unknown-prop", "screens/Board.json", "/children/1/props/colour"},
      {:"prop-type", "screens/Board.json", "/children/1/props/text"},
      {:"unknown-state", "screens/Board.json", "/children/2/state"},
      {:"bound-state-type", "screens/Board.json", "/children/3/children/0/bind/state"},
      {:"unknown-slot", "screens/Board.json", "/children/3/children/0/slots/body"},
      {:"unknown-variation", "screens/Board.json", "/children/3/children/0/variation"},
      {:"bound-and-literal", "screens/Board.json", "/children/4/bind/text"},
      {:"duplicate-id", "screens/Board.json", "/children/5"},
      {:"bind-type", "screens/Board.json", "/children/5/bind/checked"},
      {:"bind-unresolved", "screens/Board.json", "/children/6/bind/text"},
      {:"repeat-unresolved", "screens/Board.json", "/children/7/children/0/repeat/each"},
      {:"repeat-not-list", "screens/Board.json", "/children/8/children/0/repeat/each"},
      {:"unknown-use", "screens/Board.json", "/children/9/use"},
      {:"unknown-use", "screens/Board.json", "/children/10/use"},
      {:"unknown-use", "screens/Board.json", "/children/11/use"},
      {:"bind-unresolved", "screens/Board.json", "/children/12/bind/text"},
      {:"repeat-unresolved", "screens/Board.json", "/children/13/children/0/repeat/each"},
      {:"unknown-type", "screens/Board.json", "/data/t/type"},
      {:"sample-type", "screens/Board.json", "/data/tasks/sample"},
      {:"unknown-copy", "screens/Board.json", "/states/broken/children/0/copy"},
      {:"inner-unresolved", "screens/Board.json", "/states/broken/children/1/inner/nope"},
      {:"unknown-data", "screens/Board.json", "/states/broken/data/missing"},
      {:"content-unresolved", "screens/Board.json",
       "/states/broken/variations/odd/content/ghost.text"}
    ],
    "broken-layout" => [
      {:"component-cycle", "components/Ping.json", "/children/0/use"},
      {:"component-cycle", "components/Pong.json", "/children/0/use"},
      {:"slot-misplaced", "components/Pong.json", "/children/1/slot"},
      {:"slot-misplaced", "components/Sheet.json", "/children/0/slot"},
      {:"layout-on-leaf", "screens/Layout.json", "/children/0/layout"},
      {:"children-on-leaf", "screens/Layout.json", "/children/1/children"},
      {:"outside-tracks", "screens/Layout.json", "/children/2/children/0/column"},
      {:"wrap-not-flow", "screens/Layout.json", "/children/2/wrap"},
      {:"grid-placement-off-grid", "screens/Layout.json", "/children/3/children/0/column"},
      {:"grid-field-off-grid", "screens/Layout.json", "/children/3/columns"},
      {:"position-without-absolute", "screens/Layout.json", "/children/4/x"},
      {:"slot-misplaced", "screens/Layout.json", "/children/5/slot"}
    ],
    # Its /children/2, a menu holding a link, is fine: a menu isn't pressable.
    # TabItem's `panel` defaults to a panel Overview has and Home hasn't.
    "broken-composition" => [
      {:"pressable-in-pressable", "screens/Home.json", "/children/0/children/0"},
      {:"pressable-in-pressable", "screens/Home.json", "/children/1/children/0"},
      {:"pressable-in-pressable", "screens/Home.json", "/children/3/children/0"},
      {:"tab-outside-tablist", "screens/Home.json", "/children/4"},
      {:"controls-unresolved", "screens/Home.json", "/children/5"},
      {:"tab-outside-tablist", "screens/Home.json", "/children/5"},
      {:"tabpanel-without-tab", "screens/Home.json", "/children/6"},
      {:"controls-unresolved", "screens/Home.json", "/children/7/props/controls"},
      {:"current-not-pressable", "screens/Home.json", "/children/8"},
      # Frame's holder is in a pressable shell in its base, though not in its
      # `flat` state.
      {:"pressable-in-pressable", "screens/Home.json", "/children/9/slots/body/0"},
      {:"pressable-in-pressable", "screens/Home.json", "/children/9/slots/body/1"},
      # Spot passes its props to its box: set by an instance, `current` lands
      # on what can't be pressed, and `role` makes a tab outside a tablist.
      {:"current-not-pressable", "screens/Home.json", "/children/11"},
      {:"tab-outside-tablist", "screens/Home.json", "/children/12"},
      # Its tile, fine in the base, is pressable in `hover`, and so is its
      # face, through `inner`: faults the copy brings are reported in the
      # state, at the copy or at the part's `inner` entry. Its copy of card
      # adds nothing: the base reports its parts' faults.
      {:"pressable-in-pressable", "screens/Home.json", "/states/hover/children/0"},
      {:"pressable-in-pressable", "screens/Home.json", "/states/hover/children/0/inner/face"},
      {:"tab-outside-tablist", "screens/Home.json", "/states/hover/children/0/inner/face"},
      {:"controls-unresolved", "screens/Home.json",
       "/states/hover/children/0/inner/face/props/controls"}
    ],
    # Thirty components deep: a prop passed all the way down makes the last
    # one's box pressable, and the chain sits in a pressable card. Then a
    # tree six deep and four wide, a button in each leaf, in a pressable card.
    "deep-nesting" => [
      {:"pressable-in-pressable", "screens/Deep.json", "/children/0"},
      {:"pressable-in-pressable", "screens/Deep.json", "/children/1/children/0"},
      {:"pressable-in-pressable", "screens/Deep.json", "/children/2/children/0"}
    ],
    # Card and Board name icons that don't resolve; app's SVGs are unsafe or
    # malformed one way each (bomb.svg is a billion-laughs entity bomb, which
    # must be refused before it expands), and `material` is a library's name.
    # use-bomb.svg nests `use` 10 wide and 10 deep. logo.svg uses most of
    # what an icon may, and is fine.
    "broken-icons" => [
      {:"bad-name", "assets/icons/app/Logo2.svg", ""},
      {:"unsafe-svg", "assets/icons/app/animate.svg", ""},
      {:"unsafe-svg", "assets/icons/app/bomb.svg", ""},
      {:"unsafe-svg", "assets/icons/app/cdata.svg", ""},
      {:"unsafe-svg", "assets/icons/app/class.svg", ""},
      {:"unsafe-svg", "assets/icons/app/comment.svg", ""},
      {:"unsafe-svg", "assets/icons/app/escape.svg", ""},
      {:"unsafe-svg", "assets/icons/app/event.svg", ""},
      {:"unsafe-svg", "assets/icons/app/foreign.svg", ""},
      {:"unsafe-svg", "assets/icons/app/image-set.svg", ""},
      {:"unsafe-svg", "assets/icons/app/image.svg", ""},
      {:"unsafe-svg", "assets/icons/app/img.svg", ""},
      {:"unsafe-svg", "assets/icons/app/import.svg", ""},
      {:"unsafe-svg", "assets/icons/app/instruction.svg", ""},
      {:"malformed-svg", "assets/icons/app/malformed.svg", ""},
      {:"unsafe-svg", "assets/icons/app/meta.svg", ""},
      {:"malformed-svg", "assets/icons/app/page.svg", ""},
      {:"unsafe-svg", "assets/icons/app/paint.svg", ""},
      {:"unsafe-svg", "assets/icons/app/script.svg", ""},
      {:"unsafe-svg", "assets/icons/app/table.svg", ""},
      {:"malformed-svg", "assets/icons/app/trailing-img.svg", ""},
      {:"malformed-svg", "assets/icons/app/trailing-lines.svg", ""},
      {:"malformed-svg", "assets/icons/app/trailing-script.svg", ""},
      {:"unsafe-svg", "assets/icons/app/use-bomb.svg", ""},
      {:"unsafe-svg", "assets/icons/app/use.svg", ""},
      {:"malformed-svg", "assets/icons/app/utf16.svg", ""},
      {:"icon-set-is-library", "assets/icons/material", ""},
      {:"unknown-icon-style", "components/Card.json", "/children/0/props/icon"},
      {:"unknown-icon-style", "components/Card.json", "/children/1/props/icon"},
      {:"unknown-icon-set", "components/Card.json", "/children/2/props/icon"},
      {:"unknown-icon", "components/Card.json", "/children/3/props/leadingIcon"},
      {:"unknown-icon", "components/Card.json", "/props/glyph/default"},
      {:"unknown-icon-set", "components/Card.json", "/variations/loud/content/rounded.icon"},
      {:"unknown-icon", "screens/Board.json", "/data/items/sample/1/kind"},
      {:"unknown-icon-style", "screens/Board.json", "/states/odd/data/items/0/kind"}
    ],
    # A manifest that isn't JSON says nothing about the screen's device.
    "broken-manifest" => [
      {:"invalid-json", "speccy.json", ""}
    ]
  }

  test "the clean fixtures report nothing, a tabs component used alone among them" do
    assert check("tasks") == []
    assert check("uploads") == []
  end

  for {name, expected} <- @broken do
    test "#{name} reports each of its faults, and nothing else" do
      assert found(unquote(name)) == unquote(Macro.escape(expected))
    end
  end

  test "every code is in one list with its message, kebab-case, and triggered by a fixture" do
    codes = Keyword.keys(Check.codes())

    assert codes == Enum.uniq(codes)

    for {code, message} <- Check.codes(),
        do: assert(Atom.to_string(code) =~ ~r/^[a-z]+(-[a-z]+)*$/ and message != "")

    assert codes -- for({_, list} <- @broken, {code, _, _} <- list, do: code) == []
  end

  test "a problem carries its code, file, path and a message" do
    assert [
             %{
               code: :"unknown-device",
               file: "screens/Wall.json",
               path: "/device",
               message: message
             }
           ] =
             Enum.filter(check("broken-files"), &(&1.code == :"unknown-device"))

    assert message =~ "phone"
  end

  test "a button inside a pressable card is flagged, directly and through a component" do
    problems = check("broken-composition")

    assert %{path: "/children/0/children/0"} =
             Enum.find(
               problems,
               &(&1.code == :"pressable-in-pressable" and &1.message =~ "button")
             )

    assert %{path: "/children/1/children/0", message: message} =
             Enum.find(
               problems,
               &(&1.code == :"pressable-in-pressable" and &1.message =~ "Offer")
             )

    assert message =~ "inside Offer"
  end

  test "a `controls` default naming no id is reported where its component is used" do
    assert %{message: message} =
             Enum.find(
               check("broken-composition"),
               &(&1.code == :"controls-unresolved" and &1.path == "/children/5")
             )

    assert message =~ "overview, inside TabItem, at /props/panel/default"
  end

  test "a fault a state's copy brings names the part's base path" do
    assert %{message: message} =
             Enum.find(
               check("broken-composition"),
               &(&1.code == :"pressable-in-pressable" and &1.path == "/states/hover/children/0")
             )

    assert message =~ "inside tile, at /children/10/children/1"
  end
end
