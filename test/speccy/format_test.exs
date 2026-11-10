defmodule Speccy.FormatTest do
  use ExUnit.Case, async: true

  alias Speccy.Format

  @specs "test/fixtures/specs"
  @tasks Path.join(@specs, "tasks")
  @clean [@tasks, Path.join(@specs, "uploads")]

  defp keys(%Jason.OrderedObject{values: values}), do: Enum.map(values, &elem(&1, 0))
  defp at(object, key), do: object[key]

  # Every {kind of object, key} in a file's JSON.
  defp seen(_json, nil), do: []

  defp seen(%Jason.OrderedObject{values: values}, kind) when is_atom(kind) do
    {_, nested} = Format.kinds()[kind]
    for {key, value} <- values, pair <- [{kind, key} | seen(value, nested[key])], do: pair
  end

  defp seen(list, {:list, kind}) when is_list(list), do: Enum.flat_map(list, &seen(&1, kind))

  defp seen(%Jason.OrderedObject{values: values}, {:map, kind}),
    do: Enum.flat_map(values, &seen(elem(&1, 1), kind))

  defp seen(_json, _kind), do: []

  test "loads every file of a spec, key order kept, and lists its SVGs" do
    %{files: files, icons: icons} = Format.load(@tasks)

    assert files |> Map.keys() |> Enum.sort() == [
             "components/Banner.json",
             "components/EmptyState.json",
             "components/Header.json",
             "components/TaskList.json",
             "components/TaskRow.json",
             "data/Task.json",
             "screens/TaskScreen.json",
             "speccy.json"
           ]

    screen = files["screens/TaskScreen.json"]
    assert keys(screen) == ~w($schema screen about device data layout children states)
    assert keys(screen["states"]) == ~w(loading empty problem)

    assert screen |> at("states") |> at("problem") |> at("variations") |> keys() ==
             ~w(offline error)

    assert Map.keys(icons) |> Enum.sort() ==
             ~w(assets/icons/app/alert.svg assets/icons/app/offline.svg)

    assert icons["assets/icons/app/alert.svg"] =~ ~r/^<svg /
  end

  test "a file the encoder wrote encodes back to the same bytes" do
    for spec <- @clean, {path, json} <- Format.load(spec).files do
      assert Format.encode(path, json) == File.read!(Path.join(spec, path)), path
    end
  end

  test "the clean fixtures hold every kind of object and every key in format.md's tables" do
    seen =
      for spec <- @clean,
          {path, json} <- Format.load(spec).files,
          pair <- seen(json, Format.kind(path)),
          uniq: true,
          do: pair

    all = for {kind, {keys, _}} <- Format.kinds(), key <- keys, do: {kind, key}
    assert all -- seen == []
  end

  test "encode puts every kind of object's keys in format.md's order" do
    files = Format.load(Path.join(@specs, "agent-order")).files

    for {path, json} <- Map.delete(files, "components/Legacy.json") do
      assert Format.encode(path, json) == File.read!(Path.join(@tasks, path)), path
    end
  end

  test "encode keeps unknown keys after the known ones, in their order" do
    legacy = Format.load(Path.join(@specs, "agent-order")).files["components/Legacy.json"]
    encoded = Format.decode(Format.encode("components/Legacy.json", legacy))

    assert keys(encoded) == ~w($schema component about children on events)
    assert keys(hd(encoded["children"])) == ~w(id use props x-note)
  end

  test "a file that isn't valid JSON loads as an error, beside the rest" do
    files = Format.load(Path.join(@specs, "invalid-json")).files

    assert {:error, message} = files["components/Broken.json"]
    assert is_binary(message)
    assert files["components/Fine.json"]["component"] == "Fine"
    assert files["speccy.json"]["format"] == 1
  end

  test "a file that can't be read loads as an error, beside the rest" do
    files = Format.load(Path.join(@specs, "broken-files")).files

    assert {:error, "can't read the file: " <> _} = files["components/Folder.json"]
    assert files["components/Twin.json"]["component"] == "Twin"
  end

  @tag :tmp_dir
  test "a spec in a folder whose name has wildcard characters loads every file", %{tmp_dir: tmp} do
    dir = Path.join(tmp, "my [spec] {1}*?")
    File.cp_r!(@tasks, dir)

    assert Map.keys(Format.load(dir).files) == Map.keys(Format.load(@tasks).files)
    assert Map.keys(Format.load(dir).icons) == Map.keys(Format.load(@tasks).icons)
  end

  test "find gives the spec folder holding a path" do
    assert Format.find(Path.join(@tasks, "components/Banner.json")) == {:ok, Path.expand(@tasks)}
    assert Format.find(@tasks) == {:ok, Path.expand(@tasks)}
  end

  test "find gives :error with no spec at or above a path" do
    # The system's temp folder, so the walk up never passes through this repository.
    assert Format.find(System.tmp_dir!()) == :error
  end
end
