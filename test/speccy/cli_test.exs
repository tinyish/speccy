defmodule Speccy.CLITest do
  use ExUnit.Case, async: true

  alias Speccy.CLI

  @specs "test/fixtures/specs"

  defp run(argv) do
    {output, status} = CLI.run(argv)
    {IO.iodata_to_binary(output), status}
  end

  test "check passes a clean spec, found from a path inside it" do
    assert {output, 0} = run(["check", Path.join(@specs, "tasks/screens")])
    assert output =~ ~r/^No problems in .*tasks\n$/
  end

  test "check prints each problem and a count, and exits 1" do
    assert {output, 1} = run(["check", Path.join(@specs, "broken-composition")])

    assert output =~
             "screens/Home.json /children/0/children/0 pressable-in-pressable: Something pressable is inside something pressable: button\n"

    assert output =~ ~r/\n10 problems in .*broken-composition\n$/
    assert {output, 1} = run(["check", Path.join(@specs, "invalid-json")])
    assert output =~ ~r/^\S+\.json invalid-json: /m
  end

  test "check prints a problem quoting a file's lines on one line, cut short" do
    assert {output, 1} = run(["check", Path.join(@specs, "broken-icons")])
    [line] = Regex.run(~r/^assets\/icons\/app\/trailing-lines\.svg .*$/m, output)
    assert line =~ "something after the root: <p>A trailer over several lines,"
    assert String.ends_with?(line, "…")
  end

  test "check --json prints the problems as a JSON array" do
    assert {output, 1} = run(["check", "--json", Path.join(@specs, "broken-composition")])
    problems = Jason.decode!(output)
    assert %{"file" => "screens/Home.json", "path" => "/children/4"} = Enum.at(problems, 3)
    assert "tab-outside-tablist" in Enum.map(problems, & &1["code"])
  end

  @tag :tmp_dir
  test "check without a spec, or with bad arguments, exits 2", %{tmp_dir: dir} do
    assert {"No spec found" <> _, 2} = run(["check", dir])
    assert {"No such file or folder" <> _, 2} = run(["check", Path.join(dir, "nowhere")])
    assert {"Usage" <> _, 2} = run(["check", "--colour"])
    assert {"Usage" <> _, 2} = run(["render", "Home"])
  end

  test "speccy, help and --help print the usage and exit 0" do
    for argv <- [[], ["help"], ["--help"]], do: assert({"Usage" <> _, 0} = run(argv))
  end

  test "explain with no topic gives the overview, the schemas and the topics" do
    assert {output, 0} = run(["explain"])
    assert output =~ "## The spec folder"
    assert output =~ "priv/schemas/1/screen.schema.json`"
    assert output =~ "- `states`: States and variations"
    refute output =~ "The architect's calls"
  end

  test "explain a topic prints its format.md section, with generated references" do
    assert {"## States and variations\n" <> _ = states, 0} = run(["explain", "states"])
    refute states =~ "## Icons"
    assert {devices, 0} = run(["explain", "devices"])
    assert devices =~ "| `pixel-watch-5` | 228×228 | round |"
    assert {icons, 0} = run(["explain", "icons"])
    assert icons =~ "- `material`: "
  end

  test "explain primitives, one primitive and the codes" do
    assert {primitives, 0} = run(["explain", "primitives"])
    assert length(Regex.scan(~r/^\| `[a-z-]+` \|/m, primitives)) == 25

    assert {button, 0} = run(["explain", "button"])
    [json] = Regex.run(~r/```json\n(.*)\n```/s, button, capture: :all_but_first)

    assert %{"name" => "button", "pressable" => true, "states" => %{"disabled" => _}} =
             Jason.decode!(json)

    assert {codes, 0} = run(["explain", "codes"])

    assert codes =~
             "- `pressable-in-pressable`: Something pressable is inside something pressable\n"
  end

  test "explain an unknown topic lists the topics and exits 2" do
    assert {"Unknown topic: nope\n" <> rest, 2} = run(["explain", "nope"])
    assert rest =~ "- `codes`"
  end
end
